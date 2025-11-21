# Release Packaging Guide

## Overview

This project supports two release types:
1. **Native Release** - CLI interpreter + game files (for SSH/local use)
2. **WASM Release** - Browser-ready application (runs entirely in browser)

## Quick Start

### Package Native Release
```bash
make package-native
```

Creates: `releases/native/mdlzork-<version>/`
- Contains: `mdli` interpreter + all game files + launcher scripts

### Package WASM Release
```bash
make package-wasm
```

Creates: `releases/wasm/mdlzork-<version>/`
- Contains: `mdli.js`, `mdli.wasm`, `mdli.data`, `index.html`

### Package Both
```bash
make package
```

## Native Release Structure

```
mdlzork-<version>/
├── mdli                    # MDL interpreter executable
├── play-zork-810722.sh    # Launcher script
├── README.txt             # Usage instructions
├── mdlzork_771212/        # Zork 1977-12-12
├── mdlzork_780124/        # Zork 1978-01-24
├── mdlzork_791211/        # Zork 1979-12-11
└── mdlzork_810722/        # Zork 1981-07-22
```

### Usage

**Option 1: Use launcher script**
```bash
./play-zork-810722.sh
```

**Option 2: Manual CLI**
```bash
cd mdlzork_810722/patched_confusion
../mdli -r SAVEFILE/ZORK.SAVE
```

## WASM Release Structure

```
mdlzork-<version>/
├── index.html             # Web interface
├── mdli.js                # JavaScript wrapper
├── mdli.wasm              # WebAssembly binary
├── mdli.data              # Preloaded game files
└── README.txt             # Usage instructions
```

### Usage

1. Serve files with any web server:
   ```bash
   python3 -m http.server 8000
   ```

2. Open in browser:
   ```
   http://localhost:8000/index.html
   ```

Works offline once loaded!

## Creating Distribution Archives

### Native Release
```bash
cd releases
tar -czf mdlzork-<version>-native.tar.gz mdlzork-<version>/
```

### WASM Release
```bash
cd releases
tar -czf mdlzork-<version>-wasm.tar.gz mdlzork-<version>/
# Or zip:
zip -r mdlzork-<version>-wasm.zip mdlzork-<version>/
```

## Version Detection

The version is automatically detected from git:
- Uses `git describe --tags --always` if available
- Falls back to "dev" if not in a git repo

## What Gets Included

### Native Release Includes:
- ✅ MDL interpreter (`mdli`)
- ✅ All game versions (mdlzork_*)
- ✅ Launcher scripts
- ✅ README with instructions

### WASM Release Includes:
- ✅ JavaScript wrapper (`mdli.js`)
- ✅ WebAssembly binary (`mdli.wasm`)
- ✅ Preloaded game files (`mdli.data` - if available)
- ✅ HTML interface (`index.html`)
- ✅ README with instructions

## Distribution

### For Native Release:
Users need:
- A Unix-like system (macOS, Linux)
- Terminal/SSH access
- No other dependencies (interpreter is self-contained)

### For WASM Release:
Users need:
- A modern web browser (Chrome, Firefox, Safari, Edge)
- A web server (or static hosting)
- No other dependencies

## Cleanup

```bash
make clean-releases  # Remove all release artifacts
```

## Notes

- Native release is platform-specific (macOS ARM/Intel, Linux x86_64, etc.)
- WASM release is platform-independent (runs in any browser)
- Game files are included in both releases
- WASM release bundles games into `mdli.data` for offline use
