# WASM Proof of Concept - Quick Start Guide

## Prerequisites

1. Install Emscripten SDK:
```bash
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk
./emsdk install latest
./emsdk activate latest
source ./emsdk_env.sh
```

2. Verify installation:
```bash
emcc --version
```

## Quick Test Build

### Step 1: Create a minimal test

Create `test_wasm.cpp`:
```cpp
#include <stdio.h>
#include <emscripten.h>

extern "C" {
    EMSCRIPTEN_KEEPALIVE
    int test_function() {
        printf("Hello from WASM!\n");
        return 42;
    }
}
```

### Step 2: Compile to WASM

```bash
emcc test_wasm.cpp -o test.html -s WASM=1 -s EXPORTED_FUNCTIONS='["_test_function"]'
```

### Step 3: Test in browser

Open `test.html` in a browser and check console.

## Confusion-Specific Challenges

### Challenge 1: GC Replacement

**Current code:**
```cpp
#include <gc/gc.h>
void* ptr = GC_MALLOC(size);
```

**WASM replacement options:**

**Option A: Use Emscripten malloc**
```cpp
#ifdef __EMSCRIPTEN__
    #define GC_MALLOC malloc
    #define GC_REALLOC realloc
    #define GC_FREE free
    #define GC_INIT() 
    #define GC_gcollect()
    #define GC_gc_no 0
#else
    #include <gc/gc.h>
#endif
```

**Option B: Create GC wrapper**
```cpp
// gc_wrapper.h
#ifdef __EMSCRIPTEN__
    void* gc_malloc(size_t size);
    void gc_init();
    void gc_collect();
#else
    #include <gc/gc.h>
    #define gc_malloc GC_MALLOC
    #define gc_init GC_INIT
    #define gc_collect GC_gcollect
#endif
```

### Challenge 2: File System

**Preload game files:**
```bash
emcc ... --preload-file game_dir@/game ...
```

**Access in code:**
```cpp
FILE* f = fopen("/game/run.mud", "r");
```

**Save to IndexedDB:**
```javascript
// In JavaScript
FS.mkdir('/saves');
FS.mount(IDBFS, {}, '/saves');
FS.syncfs(true, function(err) {
    // Files synced
});
```

### Challenge 3: I/O Redirection

**JavaScript side:**
```javascript
const Module = createModule({
    print: function(text) {
        // Send to terminal UI
        terminal.write(text);
    },
    printErr: function(text) {
        console.error(text);
    },
    stdin: function() {
        // Return input character
        return inputBuffer.shift() || null;
    }
});
```

## Minimal Working Example

### 1. Modified mdli.cpp (WASM version)

```cpp
#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif

int main(int argc, char *argv[]) {
    #ifdef __EMSCRIPTEN__
        // Initialize virtual file system
        EM_ASM(
            FS.mkdir('/game');
            FS.mount(IDBFS, {}, '/saves');
        );
    #endif
    
    GC_INIT();
    mdl_interp_init();
    
    FILE* restorefile = NULL;
    if (argc > 2 && strcmp(argv[1], "-r") == 0) {
        restorefile = fopen(argv[2], "rb");
    }
    
    mdl_toplevel(restorefile);
    return 0;
}
```

### 2. HTML wrapper

```html
<!DOCTYPE html>
<html>
<head>
    <title>Zork WASM</title>
    <script src="https://cdn.jsdelivr.net/npm/xterm@5.3.0/lib/xterm.js"></script>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/xterm@5.3.0/css/xterm.css" />
</head>
<body>
    <div id="terminal"></div>
    <script src="mdli.js"></script>
    <script>
        const terminal = new Terminal();
        terminal.open(document.getElementById('terminal'));
        
        const Module = createModule({
            print: (text) => terminal.write(text),
            printErr: (text) => terminal.write(text),
            onRuntimeInitialized: () => {
                terminal.write('Initializing Zork...\r\n');
                Module.ccall('main', 'number', ['number', 'number'], 
                    [2, Module.stringToNewUTF8('-r'), Module.stringToNewUTF8('/game/SAVEFILE/ZORK.SAVE')]);
            }
        });
        
        terminal.onData((data) => {
            // Handle input - would need to implement stdin buffer
            Module.ccall('send_input', null, ['string'], [data]);
        });
    </script>
</body>
</html>
```

## Testing Checklist

- [ ] Code compiles without errors
- [ ] WASM module loads in browser
- [ ] File system is accessible
- [ ] Game files can be read
- [ ] Output appears in terminal
- [ ] Input can be sent to interpreter
- [ ] Save/restore works
- [ ] Performance is acceptable

## Next Steps

1. Start with minimal test (hello world)
2. Add file system support
3. Add I/O redirection
4. Test with one game file
5. Expand to full functionality

## Resources

- [Emscripten Documentation](https://emscripten.org/docs/getting_started/index.html)
- [Emscripten File System API](https://emscripten.org/docs/api_reference/Filesystem-API.html)
- [xterm.js Documentation](https://xtermjs.org/docs/)
