# rm-node-modules

A tiny CLI to find and delete `node_modules` folders under a directory tree.

Why? `node_modules` often grows large and lingers across monorepos, sandboxes, and archived projects. When you want to reclaim disk space or reset dependencies, `rm-node-modules` sweeps through a parent directory and removes all `node_modules` folders — starting from the top-most ones first.

### Key features

- Top-down deletion order (parents before children)
- Dry-run with size estimation
- Confirm-before-delete (or `-y` to skip)

### Installation

Option A: use the script directly

```bash
chmod +x rm-node-modules/bin/rm-node-modules.sh
./rm-node-modules/bin/rm-node-modules.sh --help
```

Option B: add to your PATH

```bash
# Example: add a shell alias
alias rm-node-modules="/absolute/path/to/rm-node-modules/bin/rm-node-modules.sh"

# Or symlink into a directory on PATH
ln -s \
  /absolute/path/to/rm-node-modules/bin/rm-node-modules.sh \
  /usr/local/bin/rm-node-modules
```

### Usage

```bash
rm-node-modules [options] [root]
```

If `root` is omitted, it defaults to the current directory.

#### Common examples

```bash
# Show what would be deleted (sizes too), but do nothing
rm-node-modules --dry-run ~/code

# Delete without prompting
rm-node-modules -y ~/code

# Run from current directory
rm-node-modules -y
```

### CLI

```text
rm-node-modules - find and delete node_modules directories (top-down)

Usage:
  rm-node-modules [options] [root]

Options:
  -y, --yes                 Proceed without interactive confirmation
      --dry-run             Show what would be removed and sizes; make no changes
      --debug               Print additional debug output
  -h, --help                Show help

Notes:
- Deletion order is top-down to ensure parent node_modules are removed first.
- Size estimation uses `du -sk` for POSIX/macOS compatibility and is approximate.
```

### Top-down order (why it matters)

If a parent folder contains multiple nested projects, deleting the parent `node_modules` first avoids redundant work and accurately reports what gets removed at higher levels.

### Exit codes

- `0` success (or nothing to do)
- `1` invalid usage or unexpected error

### Testing

This repo includes an integration test script that sets up a temporary directory tree with multiple nested `node_modules` folders, runs `rm-node-modules` in various modes, and verifies behavior.

```bash
./rm-node-modules/bin/rm-node-modules_test.sh
```

### License

MIT
