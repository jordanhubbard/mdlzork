# MDL Zork - Original Mainframe Zork Collection

Play the original mainframe Zork games written in MDL (MIT Design Language) from 1977-1981, compiled to WebAssembly and running entirely in your browser as a Progressive Web App.

🎮 **Play Online**: https://jordanhubbard.github.io/mdlzork/web/ _(auto-deployed from master)_

## ✨ Features

- 🌐 **Runs Entirely in Browser** - No server required after initial load
- 📱 **Progressive Web App** - Install on desktop or mobile
- 💾 **Save/Load with IndexedDB** - Persistent saves across sessions
- 📤 **Export/Import Saves** - Share saves between devices
- 🎮 **4 Game Versions** - Play Zork from 1977 to 1981
- ⚡ **Offline Support** - Play without internet after first load
- 🖥️ **Retro Terminal** - Authentic green-on-black aesthetic with xterm.js

## Quick Start

### Play Online (Easiest)

Visit **https://jordanhubbard.github.io/mdlzork/web/** to play immediately - no installation required!

### Build and Run Locally

```bash
# Build WASM and start local server
make run

# Then open: http://localhost:8000/
```

The app will automatically cache itself for offline use.

### Native Terminal Build (Advanced)

For running in a native terminal (no browser):

```bash
# Build native interpreter
make build-native

# Run specific game version
make run-native mdlzork_810722
```

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

### WASM Build (Progressive Web App)

```bash
make build          # Build WASM (auto-installs Emscripten)
make run            # Build and serve on localhost:8000
make wasm-deps      # Install Emscripten SDK manually
make clean-wasm     # Clean WASM artifacts
```

**Requirements:**
- Git (for Emscripten SDK)
- Python 3 (for local test server only)
- Make
- ~500 MB disk space for Emscripten

**Output:**
- `confusion-mdl/mdli.js` (203KB) - Emscripten glue code
- `confusion-mdl/mdli.wasm` (2.0MB) - Compiled interpreter  
- `confusion-mdl/mdli.data` (16MB) - All 4 game versions

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

## Playing the Games

### In Browser (Recommended)

1. Visit https://jordanhubbard.github.io/mdlzork/web/ OR
2. Run locally: `make run` → open http://localhost:8000/
3. Select game version (1977-1981)
4. Click "Start Game"
5. Type commands in the terminal

**Game Controls:**
- Type commands and press Enter
- Up/Down arrows for command history
- Ctrl+C to interrupt
- Save/Load buttons to manage progress
- Export/Import to share saves

### Terminal (Native CLI)

```bash
cd mdlzork_810722
../confusion-mdl/mdli -r SAVEFILE/ZORK.SAVE
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
├── .github/workflows/    # CI/CD for auto-deployment
│   ├── deploy-wasm.yml   # Deploy to GitHub Pages
│   └── test-build.yml    # PR build validation
├── web/                  # Progressive Web App
│   ├── index.html        # Main UI
│   ├── app.js            # Game logic + WASM integration
│   ├── style.css         # Retro terminal styling
│   ├── sw.js             # Service Worker (offline support)
│   ├── manifest.json     # PWA manifest
│   ├── icon.svg          # App icon
│   └── offline.html      # Offline fallback page
├── confusion-mdl/        # MDL interpreter (submodule)
│   ├── Makefile          # Native build
│   ├── Makefile.wasm     # WASM build
│   ├── gc_stub.h/cpp     # GC replacement for WASM
│   └── wasm_config.h     # WASM configuration
├── emsdk/                # Emscripten SDK (auto-installed)
├── mdlzork_771212/       # Zork 1977-12-12 (500 points)
├── mdlzork_780124/       # Zork 1978-01-24 (with end-game)
├── mdlzork_791211/       # Zork 1979-12-11 (616 points)
├── mdlzork_810722/       # Zork 1981-07-22 (final MDL)
├── dungeon_3_2b/         # Fortran version
├── zork_285/             # ZIL version (June 1977)
├── Makefile              # Build system
└── PLAN.md               # Migration plan documentation
```

## Architecture

### WASM Build Pipeline
1. **C/C++ Source** (confusion-mdl/) → Emscripten → **WASM**
2. **GC Replacement**: Boehm GC → malloc/free stub (gc_stub.h)
3. **Game Files**: 4 versions preloaded into 16MB .data file
4. **Web App**: xterm.js terminal + IndexedDB saves + Service Worker

### Deployment
- **GitHub Actions** auto-builds on every push
- **Emscripten SDK** cached for fast CI builds
- **GitHub Pages** serves static site
- **Service Worker** caches 18MB for offline use

## Documentation

- **PLAN.md** - Complete migration plan (Flask → WASM PWA)
- **Individual game directories** - Game-specific READMEs

## Troubleshooting

### Build Issues

**"Emscripten SDK not found"**
```bash
make wasm-deps  # Installs Emscripten (~500MB, 10-15 min)
```

**"Game files not found"**
```bash
git submodule update --init --recursive
```

**Native build: "libgc not found"**
```bash
# macOS
brew install bdw-gc

# Linux
sudo apt-get install libgc-dev
```

### Runtime Issues

**PWA won't install**
- Must be served over HTTPS (GitHub Pages) or localhost
- Check browser console for manifest errors

**Service Worker not registering**
- Clear site data and reload
- Check browser supports Service Workers

**Save/Load not working**
- IndexedDB must be enabled in browser
- Check browser storage settings

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
