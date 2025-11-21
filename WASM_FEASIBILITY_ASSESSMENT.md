# WebAssembly (WASM) Compilation Feasibility Assessment

## Executive Summary

**Overall Difficulty: MODERATE to HIGH**

Compiling Confusion to WebAssembly is **feasible** but will require significant effort. The main challenges are:
1. Boehm garbage collector integration
2. File system emulation for game files and save/restore
3. Terminal/console I/O redirection
4. Some POSIX system call emulation

**Estimated Effort**: **1-2 weeks for a working prototype**, 1-2 months for a polished solution.

**Update**: GC challenge simplified - can use malloc/free instead of porting GC (see GC_ANALYSIS.md)

---

## Technical Analysis

### 1. Garbage Collector (GC) - **SIMPLIFIED APPROACH** ⭐

**Current State:**
- Confusion uses Boehm-Demers-Weiser conservative GC (`libgc`)
- GC is deeply integrated throughout the codebase
- Used for all dynamic memory allocation

**Key Insight**: JavaScript's GC **cannot** manage WASM memory. WASM has separate linear memory.

**Simplified Solution** (Recommended): **Replace GC with malloc/free**
- Accept memory leaks for browser game sessions (user refreshes page)
- Replace `GC_MALLOC` → `malloc`, `GC_FREE` → `free`
- Stub GC-specific functions (`GC_gc_no`, `GC_gcollect()`)
- **Effort**: **1-2 days** (just find/replace with header file)

**Why This Works**:
- Browser game sessions are short-lived
- Memory leaks (~1-5 MB/hour) are acceptable
- Much simpler than porting GC
- Can upgrade later if needed

**Implementation**: See `gc_stub.h` for drop-in replacement header

**Recommendation**: ✅ **Use malloc replacement** - simplest and fastest

---

### 2. File System Operations - **MODERATE CHALLENGE**

**Current Usage:**
- `fopen()`, `fread()`, `fwrite()`, `fclose()` for:
  - Loading game files (`.mud` files)
  - Save/restore functionality (`.SAVE` files)
  - Reading from stdin (user input)
  - Writing to stdout/stderr (game output)

**WASM Solutions:**
- Emscripten provides a virtual file system (FS)
- Can preload files at compile time or load dynamically
- Save files can use IndexedDB for persistence

**Implementation Strategy:**
1. Preload all `.mud` files into Emscripten FS at startup
2. Use `--preload-file` or `--embed-file` emcc flags
3. Implement save/restore using IndexedDB via Emscripten's FS API
4. Redirect stdin/stdout to JavaScript console/terminal emulator

**Effort**: Medium (1 week)

---

### 3. Terminal/Console I/O - **LOW-MODERATE CHALLENGE**

**Current Usage:**
- `stdin`, `stdout`, `stderr` FILE pointers
- `isatty()`, `fileno()` for terminal detection
- `getopt()` for command-line parsing

**WASM Solutions:**
- Emscripten can redirect stdio to JavaScript
- Use `Module.print()` and `Module.printErr()` for output
- Use `Module.stdin` or custom input handlers for input
- Terminal emulator libraries (e.g., xterm.js) can provide UI

**Implementation:**
```javascript
// Redirect stdout to browser console/terminal
Module.print = function(text) {
    // Send to xterm.js or custom terminal UI
    terminal.write(text);
};

// Handle input
function sendInput(text) {
    // Write to stdin buffer
    Module.ccall('process_input', null, ['string'], [text]);
}
```

**Effort**: Low-Medium (3-5 days)

---

### 4. POSIX System Calls - **LOW CHALLENGE**

**Current Usage:**
- `getopt()` - command-line parsing (can be replaced)
- `getrusage()` - CPU time (can be stubbed or emulated)
- `getppid()` - process ID (can be stubbed)
- `sys/stat.h` - file stats (Emscripten FS supports this)
- `sys/time.h` - time functions (JavaScript Date API)

**WASM Solutions:**
- Most POSIX calls are already emulated by Emscripten
- Missing ones can be stubbed or implemented via JavaScript

**Effort**: Low (2-3 days)

---

### 5. C++ Standard Library - **LOW CHALLENGE**

**Current Usage:**
- `<vector>`, `<map>`, `<set>`, `<string>` - All supported
- `<ext/hash_set>` - Deprecated, but Emscripten supports it
- Standard C library functions - All supported

**Status**: ✅ Fully compatible

---

## Implementation Roadmap

### Phase 1: Basic Compilation (Days 1-2)
1. Set up Emscripten build environment
2. Create WASM-specific Makefile
3. Replace Boehm GC with malloc/free using `gc_stub.h`
4. Get basic compilation working

**Deliverable**: Code compiles to WASM (may not run yet)

**Time Saved**: Reduced from 1 week to 1-2 days by avoiding GC port

### Phase 2: File System Integration (Week 2)
1. Implement virtual file system setup
2. Preload game files (`.mud` files)
3. Implement save/restore using IndexedDB
4. Test file I/O operations

**Deliverable**: File operations work in WASM

### Phase 3: I/O and Terminal (Week 3)
1. Redirect stdout/stderr to JavaScript
2. Implement stdin input handling
3. Create basic terminal UI (or integrate xterm.js)
4. Test interactive gameplay

**Deliverable**: Can play game in browser

### Phase 4: Polish and Optimization (Week 4+)
1. Optimize WASM binary size
2. Improve UI/UX
3. Add file picker for game selection
4. Performance tuning
5. Error handling and edge cases

**Deliverable**: Production-ready browser-based game

---

## Code Changes Required

### High-Impact Changes

1. **GC Replacement** (`confusion-mdl/`)
   - Replace `GC_MALLOC` → `malloc` or Emscripten GC
   - Replace `GC_gc_no` → custom counter or stub
   - Replace `GC_gcollect()` → Emscripten GC calls
   - Files affected: `macros.cpp`, `mdl_assoc.cpp`, `mdl_strbuf.c`, `mdl_read.cpp`

2. **File System** (`mdli.cpp`, `mdl_binary_io.cpp`)
   - Wrap file operations with Emscripten FS API
   - Implement IndexedDB persistence for saves
   - Preload game files at startup

3. **Main Entry Point** (`mdli.cpp`)
   - Replace `main()` with Emscripten-compatible entry
   - Initialize virtual file system
   - Set up JavaScript bindings

### Medium-Impact Changes

4. **System Calls** (`macros.cpp`)
   - Stub `getrusage()` for TIME function
   - Stub `getppid()` for LOGOUT function
   - Replace `getopt()` with simpler argument parsing

5. **Terminal Detection** (`mdl_read.cpp`, `mdl_output.cpp`)
   - Stub `isatty()` to return appropriate values
   - Ensure stdin/stdout work with Emscripten

### Low-Impact Changes

6. **Build System** (`Makefile`)
   - Create `Makefile.wasm` with Emscripten compiler flags
   - Add file preloading configuration
   - Optimize for size (`-Oz`)

---

## Example Emscripten Build Configuration

```makefile
# Makefile.wasm
EMCC = emcc
EMCC_FLAGS = -O2 -s WASM=1 -s EXPORTED_RUNTIME_METHODS='["ccall","cwrap"]' \
             -s ALLOW_MEMORY_GROWTH=1 -s MODULARIZE=1 \
             --preload-file mdlzork_810722/patched_confusion@/game \
             -s EXPORT_NAME="createModule"

mdli.js: $(OBJS)
	$(EMCC) $(CXXFLAGS) -o $@ $^ $(EMCC_FLAGS)
```

---

## Browser Integration Example

```html
<!DOCTYPE html>
<html>
<head>
    <script src="mdli.js"></script>
    <script src="xterm.js"></script>
</head>
<body>
    <div id="terminal"></div>
    <script>
        const terminal = new Terminal();
        terminal.open(document.getElementById('terminal'));
        
        const Module = createModule({
            print: (text) => terminal.write(text),
            printErr: (text) => terminal.write(text),
            onRuntimeInitialized: () => {
                // Initialize game
                Module.ccall('mdl_toplevel', null, ['number'], [null]);
            }
        });
        
        terminal.onData((data) => {
            // Send input to WASM module
            Module.ccall('process_input', null, ['string'], [data]);
        });
    </script>
</body>
</html>
```

---

## Potential Issues and Mitigations

### Issue 1: GC Performance
**Problem**: Emscripten GC may be slower than Boehm GC
**Mitigation**: Profile and optimize, consider manual memory management for hot paths

### Issue 2: File Size
**Problem**: WASM binary + game files may be large
**Mitigation**: 
- Compress game files
- Use `-Oz` optimization
- Lazy-load game files
- Consider splitting into multiple WASM modules

### Issue 3: Browser Compatibility
**Problem**: Older browsers may not support WASM
**Mitigation**: Provide fallback to server-based version

### Issue 4: Save File Persistence
**Problem**: IndexedDB may have size limits
**Mitigation**: Compress save files, use localStorage for small saves

---

## Success Criteria

✅ **Minimum Viable Product:**
- Code compiles to WASM
- Can load and run a Zork game
- Basic input/output works
- Can save/restore game state

✅ **Production Ready:**
- All Zork versions work
- Smooth performance
- Good UI/UX
- Save files persist across sessions
- Works on major browsers

---

## Alternative Approaches

### Option 1: Full WASM Port (Recommended)
- **Pros**: Fully client-side, no server needed, works offline
- **Cons**: More complex, larger download size
- **Effort**: 2-4 weeks

### Option 2: Hybrid Approach
- Keep server for file serving
- Compile only interpreter to WASM
- **Pros**: Smaller WASM, simpler file handling
- **Cons**: Still needs server
- **Effort**: 1-2 weeks

### Option 3: JavaScript Rewrite
- Rewrite interpreter in JavaScript/TypeScript
- **Pros**: Native browser support, easier debugging
- **Cons**: Much more work, may be slower
- **Effort**: 3-6 months (not recommended)

---

## Recommendations

1. **Start with a proof-of-concept** (1 week)
   - Get basic compilation working
   - Test with simplest game file
   - Validate approach

2. **Use Emscripten GC** (not Boehm GC port)
   - Faster to implement
   - Better WASM integration
   - Can optimize later if needed

3. **Leverage existing tools**
   - Use xterm.js for terminal UI
   - Use Emscripten's FS API for files
   - Use IndexedDB for persistence

4. **Incremental development**
   - Get one game version working first
   - Then expand to all versions
   - Polish UI last

---

## Conclusion

**Feasibility: ✅ YES**

Compiling Confusion to WASM is **definitely feasible** and would provide a great user experience. The main challenges are manageable with Emscripten's tooling. The biggest risk is GC integration, but this can be solved with moderate effort.

**Recommended Next Steps:**
1. Set up Emscripten development environment
2. Create a proof-of-concept build
3. Test GC replacement approach
4. If successful, proceed with full implementation

**Estimated Timeline**: 2-4 weeks for MVP, 1-2 months for production-ready version.
