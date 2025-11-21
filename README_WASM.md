# Building Browser-Ready Zork (WASM)

This project can now be built to run entirely in a web browser using WebAssembly!

## Quick Start

```bash
# 1. Install dependencies (one-time, takes ~10-15 minutes)
make wasm-deps

# 2. Activate Emscripten environment
source emsdk/emsdk_env.sh

# 3. Build WASM version
make wasm-all

# 4. Test in browser
make wasm-serve
# Then open: http://localhost:8000/wasm-build/test_wasm.html
```

That's it! The application will run entirely in the browser - no server needed after the initial build.

## What Gets Built

- `wasm-build/mdli.js` - JavaScript wrapper (~100-500 KB)
- `wasm-build/mdli.wasm` - WebAssembly binary (~500 KB - 2 MB)
- `wasm-build/mdli.data` - Preloaded game files (if available)
- `wasm-build/test_wasm.html` - Test page

## Make Targets

### WASM Build Targets

- `make wasm-deps` - Install Emscripten SDK (first time only, ~10-15 min)
- `make wasm-build` - Build WASM version (requires Emscripten activated)
- `make wasm-all` - Install deps and build WASM
- `make wasm-serve` - Build WASM and start test server
- `make wasm-env` - Show commands to activate Emscripten
- `make clean-wasm` - Clean WASM build artifacts

### Native Build Targets (still available)

- `make` - Build native interpreter
- `make interpreter` - Build native MDL interpreter
- `make run` - Run web launcher server

## Requirements

- **Git** - For cloning Emscripten SDK
- **Python 3** - For serving test files (usually pre-installed)
- **Make** - Build system (usually pre-installed)
- **C++ Compiler** - For building (handled by Emscripten)

No other dependencies needed! The Makefile handles everything.

## How It Works

1. **GC Replacement**: Uses `malloc`/`free` instead of Boehm GC (see `GC_ANALYSIS.md`)
2. **File System**: Game files preloaded into Emscripten's virtual file system
3. **Memory**: Accepts memory leaks for browser sessions (user closes tab = cleanup)
4. **I/O**: stdout/stderr redirected to browser console/terminal

## Troubleshooting

### "Emscripten not found"
```bash
source emsdk/emsdk_env.sh
# Then try again
```

### "Game files not found"
The build will work without game files, but you won't be able to load games. Make sure `mdlzork_810722/patched_confusion` exists.

### "Python not found" (for wasm-serve)
Install Python 3, or serve files manually with any web server.

### Build errors
Check that you've activated Emscripten:
```bash
source emsdk/emsdk_env.sh
emcc --version  # Should show version
```

## Next Steps

Once the basic build works:
1. Test interpreter initialization
2. Add input handling (stdin redirection)
3. Test game loading
4. Implement save/restore (IndexedDB)
5. Polish UI (integrate xterm.js)

## Files Created

- `wasm-build/` - Output directory for browser-ready files
- `emsdk/` - Emscripten SDK (installed by `make wasm-deps`)
- See `WASM_POC_SUMMARY.md` for complete file list

## Distribution

To distribute the browser application:
1. Build with `make wasm-all`
2. Copy `wasm-build/` directory to web server
3. Serve via any static file server
4. Users can play directly in browser - no installation needed!

## See Also

- `BUILD_WASM.md` - Detailed build instructions
- `GC_ANALYSIS.md` - Why we don't need Boehm GC
- `WASM_FEASIBILITY_ASSESSMENT.md` - Technical analysis
- `WASM_POC_SUMMARY.md` - What was created
