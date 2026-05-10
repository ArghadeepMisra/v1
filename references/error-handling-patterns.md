# Error Handling Patterns

Quick reference for consistent error handling across the stack. Use alongside the `debugging-and-error-recovery` and `context-engineering` skills.

## Table of Contents

- [The Three Patterns](#the-three-patterns)
- [Decision Tree](#decision-tree)
- [Examples by Scenario](#examples-by-scenario)
- [Anti-Patterns](#anti-patterns)
- [Language-Specific Examples](#language-specific-examples)
- [Code Review Checklist](#code-review-checklist)

## The Three Patterns

### Pattern A: Fail Fast (Fatal Errors)

**When to use:**
- Fatal errors that prevent the operation from completing its core purpose
- User input validation failures (invalid arguments, malformed data)
- Critical preconditions not met (missing database, corrupted state)
- Unrecoverable system errors (filesystem failures, permission denied)

**Characteristics:**
- Writes `Error:` prefix to stderr (or equivalent logging)
- Returns non-zero exit code immediately
- Operation makes no further progress
- Should be transactional where possible (don't leave partial state)

**Examples:**

```typescript
// API: Invalid user input
if (!result.success) {
  return res.status(422).json({
    error: { code: 'VALIDATION_ERROR', message: 'Invalid task data' }
  });
}

// CLI: Missing required file
if (!fs.existsSync(configPath)) {
  console.error(`Error: Config file not found at ${configPath}`);
  process.exit(1);
}

// Go: Database operation failure
if err := store.CreateIssue(ctx, issue); err != nil {
  fmt.Fprintf(os.Stderr, "Error: %v\n", err)
  os.Exit(1)
}
```

---

### Pattern B: Warn and Continue (Non-Fatal Errors)

**When to use:**
- Optional operations that enhance functionality but aren't required
- Metadata operations (config updates, analytics, logging)
- Cleanup operations (removing temp files, closing resources)
- Auxiliary features (cache warming, secondary index updates)

**Characteristics:**
- Writes `Warning:` prefix to stderr/logs
- Includes context about what failed
- Operation continues execution
- Core functionality still works

**Examples:**

```typescript
// Optional: Analytics flush
if (analyticsEnabled) {
  analytics.flush().catch(err => {
    console.warn(`Warning: failed to flush analytics: ${err.message}`);
    // Non-fatal - continue anyway
  });
}

// Auxiliary: Git hooks installation
if err := installGitHooks(); err != nil {
  fmt.Fprintf(os.Stderr, "Warning: failed to install git hooks: %v\n", err)
  fmt.Fprintf(os.Stderr, "You can try again with: bd doctor --fix\n")
}

// Metadata: Version tracking
if err := store.SetMetadata(ctx, "app_version", version); err != nil {
  fmt.Fprintf(os.Stderr, "Warning: failed to store version metadata: %v\n", err)
}
```

---

### Pattern C: Silent Ignore (Cleanup / Best-Effort)

**When to use:**
- Resource cleanup where failure doesn't matter (closing files, removing temps)
- Idempotent operations in error paths (already logging primary error)
- Best-effort operations with no user-visible impact
- Defer/cleanup statements

**Characteristics:**
- No output to user
- Typically in `defer`, `finally`, or error paths
- Operation failure has no material impact
- Primary error already reported elsewhere

**Examples:**

```typescript
// TypeScript: Cleanup in finally
let tempFile: FileHandle;
try {
  tempFile = await fs.open(tempPath, 'w');
  await tempFile.write(data);
} catch (err) {
  console.error(`Error: failed to write temp file: ${err}`);
  throw err;
} finally {
  // Pattern C: best effort cleanup
  await tempFile?.close().catch(() => {});
  await fs.unlink(tempPath).catch(() => {});
}

// Go: Defer cleanup
defer func() {
  _ = tempFile.Close()
  if writeErr != nil {
    _ = os.Remove(tempPath)
  }
}()

// Python: Context manager cleanup
with open(temp_path, 'w') as f:
    f.write(data)
# File auto-closes; any close error is silently ignored
```

## Decision Tree

```
Did an error occur?
├─ NO  → Continue normally
│
└─ YES → Ask:
         │
         ├─ Is this a fatal error that prevents
         │  the operation's core purpose?
         │
         │  YES → Pattern A: Fail Fast
         │        • Write "Error: ..." to stderr/logs
         │        • Provide actionable hint if possible
         │        • Return non-zero exit code / throw
         │
         ├─ Is this an optional/auxiliary operation
         │  where the core work can still succeed?
         │
         │  YES → Pattern B: Warn and Continue
         │        • Write "Warning: ..." to stderr/logs
         │        • Explain what failed
         │        • Continue execution
         │
         └─ Is this a cleanup/best-effort operation
            where failure doesn't matter?

            YES → Pattern C: Silent Ignore
                  • Use catch-and-ignore / _ = operation()
                  • No user output
                  • Typically in defer/finally/error paths
```

## Examples by Scenario

### User Input Validation → Pattern A (Fail Fast)

```typescript
// All languages: Validate at boundary, fail immediately
function createTask(input: CreateTaskInput): Task {
  if (!input.title || input.title.trim() === '') {
    throw new ValidationError('Title is required');
  }
  if (input.title.length > 200) {
    throw new ValidationError('Title must be under 200 characters');
  }
  // ... proceed with creation
}
```

### Creating Auxiliary Config Files → Pattern B (Warn)

```typescript
// Non-critical file creation
async function ensureConfigDir(): Promise<void> {
  try {
    await fs.mkdir(configDir, { recursive: true });
  } catch (err) {
    console.warn(`Warning: failed to create config directory: ${err.message}`);
    // Continue - the app can still run without persistent config
  }
}
```

### Database Transaction Failures → Pattern A (Fail Fast)

```typescript
// Critical operation
async function transferFunds(from: string, to: string, amount: number): Promise<void> {
  const tx = await db.beginTransaction();
  try {
    await tx.debit(from, amount);
    await tx.credit(to, amount);
    await tx.commit();
  } catch (err) {
    await tx.rollback(); // Always rollback on failure
    console.error(`Error: transfer failed: ${err.message}`);
    throw new TransferError('Failed to complete transfer');
  }
}
```

### Optional Metadata Updates → Pattern B (Warn)

```typescript
// Tracking metadata that enhances but isn't required
async function trackLastSync(hash: string): Promise<void> {
  try {
    await cache.set('last_sync_hash', hash);
  } catch (err) {
    console.warn(`Warning: failed to update sync metadata: ${err.message}`);
    // Non-fatal - next sync will do a full check instead of incremental
  }
}
```

### Resource Cleanup → Pattern C (Ignore)

```typescript
// In error paths, cleanup is best-effort
async function processUpload(filePath: string): Promise<void> {
  let tempDir: string | null = null;
  try {
    tempDir = await fs.mkdtemp('/tmp/upload-');
    await extractArchive(filePath, tempDir);
    await validateContents(tempDir);
    await moveToStorage(tempDir);
  } catch (err) {
    console.error(`Error: upload processing failed: ${err.message}`);
    throw err;
  } finally {
    // Pattern C: cleanup is best effort
    if (tempDir) {
      await fs.rm(tempDir, { recursive: true }).catch(() => {});
    }
  }
}
```

## Anti-Patterns

### Don't mix patterns inconsistently

```typescript
// BAD: Same type of operation handled differently
try {
  await createConfigYaml(dir);
} catch (err) {
  console.warn(`Warning: ${err.message}`); // Warns
}
try {
  await createReadme(dir);
} catch (err) {
  console.error(`Error: ${err.message}`);
  process.exit(1); // Exits - inconsistent!
}

// GOOD: Consistent pattern for similar operations
try {
  await createConfigYaml(dir);
} catch (err) {
  console.warn(`Warning: failed to create config.yaml: ${err.message}`);
}
try {
  await createReadme(dir);
} catch (err) {
  console.warn(`Warning: failed to create README.md: ${err.message}`);
}
```

### Don't silently ignore critical errors

```typescript
// BAD: Critical operation ignored
_ = store.CreateIssue(ctx, issue);  // If this fails, we don't know!

// GOOD: Fail fast on critical errors
if err := store.CreateIssue(ctx, issue); err != nil {
  fmt.Fprintf(os.Stderr, "Error: %v\n", err)
  os.Exit(1)
}
```

### Don't fail on auxiliary operations

```typescript
// BAD: Exiting when optional feature fails is too aggressive
if err := installGitHooks(); err != nil {
  console.error(`Error: ${err.message}`);
  process.exit(1);
}

// GOOD: Warn and suggest fix
if err := installGitHooks(); err != nil {
  console.warn(`⚠ Failed to install git hooks: ${err.message}`);
  console.warn(`You can try again with: bd doctor --fix`);
}
```

### Don't swallow errors without logging

```typescript
// BAD: Error swallowed, no indication of failure
try {
  await sendNotification(user);
} catch (err) {
  // Silent ignore - user never knows notification failed
}

// GOOD: Log the failure even if non-fatal
try {
  await sendNotification(user);
} catch (err) {
  console.warn(`Warning: failed to send notification to ${user.id}: ${err.message}`);
}
```

## Language-Specific Examples

### TypeScript / JavaScript

```typescript
// Pattern A: Fail fast
function validateInput(data: unknown): asserts data is UserInput {
  if (!data || typeof data !== 'object') {
    throw new ValidationError('Expected object');
  }
}

// Pattern B: Warn and continue
async function logMetrics(metrics: Metrics): Promise<void> {
  try {
    await metricsClient.send(metrics);
  } catch (err) {
    console.warn(`Warning: metrics upload failed: ${err}`);
  }
}

// Pattern C: Silent cleanup
async function withTempFile<T>(fn: (path: string) => Promise<T>): Promise<T> {
  const tmp = await fs.mkdtemp('/tmp/app-');
  try {
    return await fn(tmp);
  } finally {
    await fs.rm(tmp, { recursive: true }).catch(() => {});
  }
}
```

### Go

```go
// Pattern A: Fatal error
if err := store.CreateIssue(ctx, issue); err != nil {
    fmt.Fprintf(os.Stderr, "Error: %v\n", err)
    os.Exit(1)
}

// Pattern B: Warning
if err := createConfigYaml(dir, false); err != nil {
    fmt.Fprintf(os.Stderr, "Warning: failed to create config.yaml: %v\n", err)
}

// Pattern C: Silent cleanup
defer func() {
    _ = tempFile.Close()
    _ = os.Remove(tempPath)
}()
```

### Python

```python
# Pattern A: Fail fast
def create_task(title: str) -> Task:
    if not title or not title.strip():
        raise ValueError("Title is required")
    # ... proceed

# Pattern B: Warn and continue
import logging
logger = logging.getLogger(__name__)

try:
    cache.set('last_sync', timestamp)
except Exception as e:
    logger.warning(f"Failed to update sync metadata: {e}")

# Pattern C: Silent cleanup
import tempfile, shutil

def process_file(path: str) -> None:
    tmp_dir = tempfile.mkdtemp()
    try:
        # ... work in tmp_dir
        pass
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)  # Pattern C
```

## Code Review Checklist

- [ ] Fatal errors use Pattern A with descriptive error message
- [ ] Optional operations use Pattern B with "Warning:" prefix
- [ ] Cleanup operations use Pattern C (silent)
- [ ] Similar operations use consistent patterns
- [ ] Error messages provide actionable hints when possible
- [ ] No critical errors are silently ignored
- [ ] No auxiliary failures cause hard exits
- [ ] Transactions are rolled back before error exit
- [ ] Resource cleanup is in `finally` / `defer` blocks
