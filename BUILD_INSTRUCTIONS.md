# Complete Build Instructions

## Browser-Ready Application (WASM) - **RECOMMENDED**

Build a version that runs entirely in the browser - no server needed!

### Quick Start

```bash
# 1. Install Emscripten (one-time, ~10-15 minutes)
make wasm-deps

# 2. Activate Emscripten
source emsdk/emsdk_env.sh

# 3. Build everything
make wasm-all

# 4. Test in browser
make wasm-serve
# Open: http://localhost:8000/wasm-build/test_wasm.html
```

### What You Get

- ✅ Fully self-contained browser application
- ✅ No server required after build
- ✅ Works offline
- ✅ Can be hosted on any static file server
- ✅ No installation needed for end users

### Distribution

After building, copy the `wasm-build/` directory to any web server. Users can play directly in their browser!

---

## Native Server Application

For the original server-based version:

```bash
# Build native interpreter
make interpreter

# Install Python dependencies
make deps

# Run web server
make run
# Visit: http://localhost:5001
```

---

## All Make Targets

### WASM Build (Browser)
- `make wasm-deps` - Install Emscripten SDK (first time)
- `make wasm-build` - Build WASM version
- `make wasm-all` - Install deps + build
- `make wasm-serve` - Build + start test server
- `make wasm-env` - Show Emscripten activation commands
- `make clean-wasm` - Clean WASM artifacts

### Native Build (Server)
- `make` - Build interpreter + install Python deps
- `make interpreter` - Build native MDL interpreter
- `make deps` - Install Python dependencies
- `make run` - Start web launcher server
- `make clean` - Clean Python artifacts
- `make clean-all` - Clean everything

### Help
- `make help` - Show all available targets

---

## Requirements

### For WASM Build
- Git (for Emscripten SDK)
- Python 3 (for test server)
- Make
- ~500 MB disk space (for Emscripten)

### For Native Build
- C++ compiler (gcc/clang)
- Python 3
- Boehm GC library (installed automatically on macOS)

---

## Troubleshooting

### WASM Build Issues

**"Emscripten not found"**
```bash
source emsdk/emsdk_env.sh
# Verify:
emcc --version
```

**"Game files not found"**
- Build will work but games won't load
- Ensure `mdlzork_810722/patched_confusion` exists

**Build errors**
- Make sure Emscripten is activated: `source emsdk/emsdk_env.sh`
- Check that `gc_stub.h` exists in `confusion-mdl/`

### Native Build Issues

**"libgc not found"**
- macOS: `brew install bdw-gc` (or let Makefile do it)
- Linux: `sudo apt-get install libgc-dev`

**Python errors**
- Ensure Python 3 is installed: `python3 --version`
- Create venv: `make venv`

---

## File Structure

```
mdlzork/
├── Makefile              # Main build file (handles everything!)
├── confusion-mdl/        # MDL interpreter submodule
│   ├── Makefile          # Native build
│   ├── Makefile.wasm     # WASM build
│   └── gc_stub.h         # GC replacement for WASM
├── wasm-build/           # WASM output (created by build)
│   ├── mdli.js           # JavaScript wrapper
│   ├── mdli.wasm         # WebAssembly binary
│   └── test_wasm.html    # Test page
├── emsdk/                # Emscripten SDK (installed by wasm-deps)
└── mdlzork_*/           # Game files
```

---

## Next Steps

Once WASM build works:
1. Test interpreter initialization
2. Add input handling
3. Test game loading
4. Implement save/restore
5. Polish UI

See `README_WASM.md` for more details.
