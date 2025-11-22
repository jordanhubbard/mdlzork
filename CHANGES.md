# Recent Changes

## Self-Contained Build System (2025-11-22)

### Problem
`make run` was not fully self-contained - it required users to manually activate the Emscripten environment:

```bash
# OLD WAY - Required manual steps
make wasm-deps
source emsdk/emsdk_env.sh  # ← Manual step exposed dependency to host
make run
```

### Solution
Created a wrapper script that automatically handles Emscripten environment activation.

### New Usage

```bash
# NEW WAY - Fully automatic
make run
```

That's it! The build system now:
1. Installs Emscripten SDK automatically if needed (first time only)
2. Activates the environment internally via wrapper script
3. Builds the WASM application
4. Starts the test server

### Dependency Chain

```
make run
  └─→ wasm-serve
       └─→ wasm-build
            ├─→ wasm-deps (installs Emscripten if needed)
            └─→ scripts/with-emsdk.sh (activates environment)
                 └─→ make -C confusion-mdl -f Makefile.wasm
```

### Files Added/Modified

**New Files:**
- `scripts/with-emsdk.sh` - Wrapper to activate Emscripten environment
- `EMSCRIPTEN_WRAPPER.md` - Technical documentation
- `CHANGES.md` - This file

**Modified Files:**
- `Makefile` - Updated `wasm-build` to use wrapper, removed manual sourcing instructions
- `BUILD_INSTRUCTIONS.md` - Simplified quick start
- `README_WASM.md` - Updated documentation

### Benefits

✅ **Self-Contained**: No manual environment setup required  
✅ **Clean Environment**: Emscripten confined to build process  
✅ **User-Friendly**: Single command to build and run  
✅ **CI/CD Ready**: No shell-specific sourcing needed  
✅ **Backwards Compatible**: Existing workflows still work  

### Technical Details

The wrapper script (`scripts/with-emsdk.sh`):
- Checks for Emscripten SDK installation
- Sources `emsdk/emsdk_env.sh` in the same shell as the build
- Passes through all command arguments
- Provides clear error messages if Emscripten is not installed

### Migration

No migration needed! If you were using the old workflow:
```bash
source emsdk/emsdk_env.sh
make run
```

You can now simply use:
```bash
make run
```

The manual sourcing step is no longer necessary or documented.
