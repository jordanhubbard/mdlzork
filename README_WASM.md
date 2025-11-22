# Building Browser-Ready Zork (WASM)

This project can now be built to run entirely in a web browser using WebAssembly!

## Quick Start

```bash
# 1. Build everything (installs Emscripten automatically)
make build

# 2. Test in browser
make run
# Then open: http://localhost:8000/test_wasm.html
```

That's it! The build system handles Emscripten installation and activation automatically. The application will run entirely in the browser - no server needed after the initial build.

## What Gets Built

- `wasm-build/mdli.js` - JavaScript wrapper (~100-500 KB)
- `wasm-build/mdli.wasm` - WebAssembly binary (~500 KB - 2 MB)
- `wasm-build/mdli.data` - Preloaded game files (if available)
- `wasm-build/test_wasm.html` - Test page

## Make Targets

### WASM Build Targets

- `make build` - Build WASM version (installs Emscripten if needed)
- `make run` - Build WASM and start test server
- `make wasm-deps` - Install Emscripten SDK manually (optional)
- `make wasm-build` - Build WASM version only
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

### "Emscripten SDK not found"
Run `make wasm-deps` to install Emscripten. The build system handles activation automatically.

### "Game files not found"
The build will work without game files, but you won't be able to load games. Make sure `mdlzork_810722/patched_confusion` exists.

### "Python not found" (for test server)
Install Python 3, or serve files manually with any web server.

### Build errors
- Verify `scripts/with-emsdk.sh` exists and is executable
- Check that Emscripten SDK is installed in `emsdk/` directory
- Run `make clean-wasm && make build` to rebuild from scratch

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
