# Emscripten Wrapper Script

## Problem

Previously, `make run` required users to manually activate the Emscripten environment before building:

```bash
make wasm-deps
source emsdk/emsdk_env.sh  # Manual step required
make run
```

This exposed the Emscripten dependency to the host environment and wasn't truly self-contained.

## Solution

Created `scripts/with-emsdk.sh` - a wrapper script that automatically sources the Emscripten environment before running build commands.

### How It Works

1. **Installation**: `make wasm-deps` installs Emscripten SDK to local `emsdk/` directory (one-time, ~10-15 minutes)
2. **Automatic Activation**: `make run` uses the wrapper script to automatically source `emsdk/emsdk_env.sh`
3. **Build**: The build runs with Emscripten environment active
4. **Serve**: Test server starts to serve the built files

### Usage

Now it's truly self-contained:

```bash
make run  # Everything happens automatically!
```

Or step-by-step:

```bash
make build  # Installs Emscripten if needed, builds WASM
make wasm-serve  # Serves the built files
```

### Technical Details

The wrapper script (`scripts/with-emsdk.sh`):
- Checks if Emscripten SDK is installed
- Sources `emsdk/emsdk_env.sh` in the same shell as the build command
- Executes the provided command with all arguments
- Returns appropriate error codes

### Files Changed

- **scripts/with-emsdk.sh** (new): Wrapper script to activate Emscripten
- **Makefile**: Updated `wasm-build` target to use wrapper
- **BUILD_INSTRUCTIONS.md**: Removed manual sourcing steps
- **README_WASM.md**: Updated quick start guide

### Benefits

1. ✅ No manual environment setup required
2. ✅ Emscripten confined to build environment
3. ✅ `make run` is fully self-contained
4. ✅ User's shell environment stays clean
5. ✅ Easier for CI/CD integration

### Backwards Compatibility

Users who have manually sourced Emscripten will not be affected - the build will still work. However, manual sourcing is no longer necessary or documented.
