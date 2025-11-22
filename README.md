# MDL Zork - Original Mainframe Zork Collection

Play the original mainframe Zork games written in MDL (MIT Design Language) from 1977-1981. This repository includes multiple versions of the game and a modernized build system that supports both native terminal play and browser-based WASM builds.

## Quick Start

### Play in Browser (WASM - Recommended for End Users)

```bash
# Build and run in browser (installs Emscripten automatically)
make run

# Then open: http://localhost:8000/test_wasm.html
```

The WASM build runs entirely in your browser - no server needed after initial build!

### Play in Terminal (Native)

```bash
# Build native interpreter and run
make build-native
make run-native
```

Interactive game selection with direct terminal play.

## Game Versions

### MDL Zork 1977-12-12
The earliest known version. A 500-point game fully playable to completion. Reconstructed with files from later versions to fill in missing pieces (notably the "melee" file). No end-game - you win when you reach 500 points.

### MDL Zork 1978-01-24
Enhanced version with parser improvements and an added end-game. The end-game is incomplete - the final puzzle with the dungeon master cannot be solved.

### MDL Zork 1979-12-11
A 616-point version with a 100-point end-game that is nearly identical to the 1981 version.

### MDL Zork 1981-07-22
The definitive mainframe Zork. Almost identical to the 1979 version with three small bugfixes and another issue of the US NEWS & DUNGEON REPORT. This is Bob Supnik's 2003 release, the basis for many later versions, patched by Matthew Russotto to work in Confusion.

### Dungeon 3.2b
Fortran version by Bob Supnik that closely follows the 1981 MDL version.

### Zork 285
ZIL version of the very first Zork from June 14, 1977.

### PDP-10 ITS Binaries
Recovered binary files that work with MDL in the [PDP-10 ITS emulator](https://github.com/PDP-10/its).

## Build System

This project includes a comprehensive Makefile that handles everything automatically.

### WASM Build (Browser Application)

```bash
make build          # Build WASM version (installs Emscripten if needed)
make run            # Build and serve test page
make wasm-deps      # Install Emscripten SDK manually (optional)
make clean-wasm     # Clean WASM build artifacts
```

**Requirements:**
- Git (for Emscripten SDK)
- Python 3 (for test server)
- Make
- ~500 MB disk space

**Output:** `wasm-build/` directory with browser-ready files

### Native Build (Terminal Application)

```bash
make build-native        # Build native interpreter
make run-native          # Interactive CLI game launcher
make run-native-server   # Run web server (Flask-based)
make clean-native        # Clean native artifacts
```

**Requirements:**
- C++ compiler (gcc/clang)
- Python 3 (for server mode only)
- Boehm GC library (auto-installed on macOS)

**Output:** `confusion-mdl/mdli` executable

### Release Packaging

```bash
make package         # Package both native and WASM releases
make package-native  # Package native release only
make package-wasm    # Package WASM release only
```

Creates distribution-ready archives in `releases/` directory.

## Playing the Games

### Browser (WASM)

1. Build: `make build`
2. Serve: `make wasm-serve` or use any web server
3. Open `test_wasm.html` in browser
4. Game runs entirely client-side (works offline after initial load)

### Terminal (Native CLI)

```bash
# Interactive launcher
make run-native

# Or manually:
cd mdlzork_810722/patched_confusion
../../confusion-mdl/mdli -r SAVEFILE/ZORK.SAVE
```

### Web Interface (Native Server)

```bash
make run-native-server
# Visit: http://localhost:5001
```

## Manual MDL Usage

If you want to work with the raw MDL files:

```bash
cd mdlzork_810722/patched_confusion
../../confusion-mdl/mdli
```

Then in the MDL interpreter:
```lisp
<FLOAD "run.mud">     ; Load and compile game from source
```

Or to restore a save file:
```lisp
<RESTORE "<SAVEFILE>ZORK.SAVE">
```

To start directly from a save file:
```bash
../../confusion-mdl/mdli -r SAVEFILE/ZORK.SAVE
```

## Project Structure

```
mdlzork/
├── Makefile              # Build system (handles everything!)
├── confusion-mdl/        # MDL interpreter (submodule)
│   ├── Makefile          # Native build
│   ├── Makefile.wasm     # WASM build
│   └── gc_stub.h         # GC replacement for WASM
├── scripts/
│   └── with-emsdk.sh     # Emscripten environment wrapper
├── wasm-build/           # WASM output (created by build)
├── releases/             # Packaged releases (created by package)
├── emsdk/                # Emscripten SDK (installed by wasm-deps)
├── mdlzork_771212/       # Zork 1977-12-12
├── mdlzork_780124/       # Zork 1978-01-24
├── mdlzork_791211/       # Zork 1979-12-11
├── mdlzork_810722/       # Zork 1981-07-22 (recommended)
├── dungeon_3_2b/         # Fortran version
└── zork_285/             # ZIL version
```

## Documentation

- **BUILD_INSTRUCTIONS.md** - Detailed build instructions
- **README_WASM.md** - WASM build documentation
- **NATIVE_VS_WASM.md** - Comparison of build modes
- **RELEASE_PACKAGING.md** - Release packaging guide
- **EMSCRIPTEN_WRAPPER.md** - Technical details on Emscripten wrapper
- **CHANGES.md** - Recent changes and improvements

## Troubleshooting

### WASM Build Issues

**"Emscripten SDK not found"**
- Run `make wasm-deps` to install Emscripten
- The build system handles activation automatically

**"Game files not found"**
- Ensure git submodules are initialized: `git submodule update --init`

### Native Build Issues

**"libgc not found"**
- macOS: `brew install bdw-gc` (or let Makefile do it)
- Linux: `sudo apt-get install libgc-dev`

**Python errors**
- Ensure Python 3 is installed: `python3 --version`
- Run `make deps` to install Python dependencies

## Make Targets Reference

### Main Targets
- `make` - Default: build native interpreter + install deps
- `make build` - Build WASM version
- `make run` - Build WASM and start test server
- `make help` - Show all available targets

### Native Targets
- `make build-native` - Build native interpreter
- `make run-native` - Run interactive CLI launcher
- `make run-native-server` - Run web server
- `make clean-native` - Clean native artifacts

### WASM Targets
- `make wasm-deps` - Install Emscripten SDK
- `make wasm-build` - Build WASM version
- `make wasm-serve` - Serve WASM build
- `make clean-wasm` - Clean WASM artifacts

### Release Targets
- `make package` - Package both releases
- `make package-native` - Package native release
- `make package-wasm` - Package WASM release
- `make clean-releases` - Clean release artifacts

### Cleanup
- `make clean` - Clean Python artifacts
- `make clean-all` - Clean everything

## Credits

**Original Zork Authors:**
- Tim Anderson
- Marc Blank
- Bruce Daniels
- Dave Lebling

**MDL Interpreter:**
- Matthew Russotto - [Confusion](http://www.russotto.net/git/mrussotto/confusion)
- Original at [IF-Archive](http://www.ifarchive.org/indexes/if-archive/programming/mdl/interpreters/confusion/)
- Benjamin Slade's [patched version](https://gitlab.com/emacsomancer/confusion-mdl)

**Additional Resources:**
- Benjamin Slade's [blog post](https://babbagefiles.xyz/zork-confusion/) on compiling Confusion
- Jeff Claar's [C++ adaptation](https://bitbucket.org/jclaar3/zork/src/master/) (carefully made from 810722 MDL source)

## License

See individual game directories for licensing information. The MDL interpreter (Confusion) and game sources have their own respective licenses.
