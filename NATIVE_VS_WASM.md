# Native vs WASM Build Modes

## Overview

This project now supports two distinct modes:

1. **Native Mode** - For users with SSH/local terminal access
2. **WASM Mode** - For browser-based distribution (no server needed)

## Native Mode (`build-native` / `run-native`)

### What It Does

**`make build-native`**:
- Builds the native MDL interpreter (`confusion-mdl/mdli`)
- Creates a standalone executable (~430K)
- No Python dependencies needed for CLI use

**`make run-native`**:
- **CLI Mode** (default): Interactive game selection and direct terminal play
- Runs the interpreter directly in your terminal
- Perfect for SSH/local terminal use

**`make run-native-server`**:
- **Server Mode**: Runs Flask web server (`zork_launcher.py`)
- Provides web interface on port 5001
- Requires Python dependencies

### Use Cases

✅ **CLI Mode** (`run-native`):
- Users with SSH access
- Local terminal users
- Simple, direct gameplay
- No web server needed

✅ **Server Mode** (`run-native-server`):
- Users who want web interface but have server access
- Multi-user scenarios
- When you want the web UI but can run a server

### CLI Usage Example

```bash
# Build
make build-native

# Run (interactive)
make run-native

# Or manually:
cd mdlzork_810722/patched_confusion
../confusion-mdl/mdli -r SAVEFILE/ZORK.SAVE
```

## WASM Mode (`build` / `run`)

### What It Does

**`make build`**:
- Compiles interpreter to WebAssembly
- Creates browser-ready files (`mdli.js`, `mdli.wasm`)
- Preloads game files into virtual file system
- Output: `wasm-build/` directory

**`make run`**:
- Serves WASM application via web server
- Opens in browser automatically
- Runs entirely client-side (no server needed after initial load)

### Use Cases

✅ **WASM Mode**:
- Users without SSH access
- Browser-only distribution
- Offline-capable after initial load
- Easy distribution (just copy files to web server)
- No server dependencies for end users

### Usage Example

```bash
# Build
make build

# Run
make run
# Opens: http://localhost:8000/wasm-build/test_wasm.html
```

## Release Packaging

### Native Release (`make package-native`)

**Contents**:
- Native interpreter (`mdli`)
- All game files (mdlzork_*)
- Launcher scripts
- README

**Distribution**:
- Platform-specific (macOS ARM/Intel, Linux x86_64)
- Users need terminal/SSH access
- Self-contained (no dependencies)

**Archive**: `mdlzork-<version>-native.tar.gz`

### WASM Release (`make package-wasm`)

**Contents**:
- `mdli.js` (JavaScript wrapper)
- `mdli.wasm` (WebAssembly binary)
- `mdli.data` (Preloaded game files)
- `index.html` (Web interface)
- README

**Distribution**:
- Platform-independent (runs in any browser)
- Users just need a web browser
- Can be hosted on any static file server

**Archive**: `mdlzork-<version>-wasm.tar.gz` or `.zip`

## Comparison

| Feature | Native (CLI) | Native (Server) | WASM |
|---------|-------------|-----------------|------|
| **User Access** | SSH/Terminal | SSH + Browser | Browser only |
| **Server Required** | ❌ No | ✅ Yes | ❌ No (after build) |
| **Distribution** | Platform-specific | Platform-specific | Universal |
| **Dependencies** | None | Python + Flask | None (for users) |
| **Offline** | ✅ Yes | ❌ No | ✅ Yes (after load) |
| **Best For** | Developers, SSH users | Multi-user servers | End users, web hosting |

## Recommendations

### For Development/Testing
- Use **Native CLI** (`make build-native` + `make run-native`)
- Fastest iteration
- Direct terminal access

### For Cloud Server Deployment
- Use **Native Server** (`make build-native` + `make run-native-server`)
- Web interface for multiple users
- Server-side execution

### For End-User Distribution
- Use **WASM** (`make build` + `make package-wasm`)
- No server needed
- Works on any platform
- Easy to host (static files)

## Release Workflow

```bash
# 1. Build both versions
make build-native
make build

# 2. Package releases
make package

# 3. Create archives
cd releases
tar -czf mdlzork-<version>-native.tar.gz native/mdlzork-<version>/
tar -czf mdlzork-<version>-wasm.tar.gz wasm/mdlzork-<version>/

# 4. Distribute
# - Native: Upload to GitHub Releases, users download and extract
# - WASM: Upload to static hosting (GitHub Pages, Netlify, etc.)
```

## Summary

- **Native CLI** (`run-native`): Simple terminal play for SSH users ✅
- **Native Server** (`run-native-server`): Web interface for server deployments ✅
- **WASM** (`run`): Browser-only distribution for end users ✅
- **Release Packaging**: Both modes can be packaged for distribution ✅

The Makefile now provides clear separation between these modes and release packaging for both!
