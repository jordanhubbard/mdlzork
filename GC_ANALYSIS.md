# Garbage Collection Analysis: Do We Need Boehm GC for WASM?

## The Key Question

**Can we avoid Boehm GC since JavaScript already has garbage collection?**

## Short Answer

**No, but we have better alternatives than Boehm GC.**

## Why JavaScript GC Doesn't Help

### WASM Memory Model

```
┌─────────────────────────────────────┐
│  JavaScript Runtime                  │
│  ┌───────────────────────────────┐   │
│  │ JavaScript Heap (JS GC)      │   │
│  │ - JS objects                 │   │
│  │ - Managed by V8/SpiderMonkey │   │
│  └───────────────────────────────┘   │
│                                       │
│  ┌───────────────────────────────┐   │
│  │ WASM Linear Memory            │   │
│  │ - MDL objects (lists, atoms) │   │
│  │ - NOT managed by JS GC        │   │
│  │ - Separate memory space       │   │
│  └───────────────────────────────┘   │
└─────────────────────────────────────┘
```

**Critical Point**: JavaScript's GC **cannot see into WASM's linear memory**. WASM memory is a separate, opaque byte array from JavaScript's perspective.

### Why MDL Needs GC

MDL is a garbage-collected language. The interpreter creates objects with:
- **Circular references**: Lists can reference themselves
- **Complex lifetimes**: Objects live until no longer referenced
- **Dynamic allocation**: Objects created during game execution

Example:
```cpp
// MDL code: <SET FOO <LIST 1 2 3>>
mdl_value_t *list = mdl_new_list(...);
// Later: FOO goes out of scope
// Without GC: memory leak!
```

## Options (Ranked by Feasibility)

### Option 1: Simple Manual Management + Accept Leaks ⭐ **RECOMMENDED**

**Approach**: Replace `GC_MALLOC` with `malloc`, accept memory leaks

**Pros**:
- ✅ Simplest implementation
- ✅ No GC code needed
- ✅ Fast (no GC overhead)
- ✅ For a browser game session, leaks are acceptable (user refreshes page)

**Cons**:
- ❌ Memory leaks (but acceptable for single session)
- ❌ Won't work for long-running sessions

**Implementation**:
```cpp
#ifdef __EMSCRIPTEN__
    #define GC_MALLOC malloc
    #define GC_REALLOC realloc
    #define GC_FREE free
    #define GC_MALLOC_ATOMIC malloc
    #define GC_INIT() 
    #define GC_gcollect() // no-op
    #define GC_gc_no 0
#else
    #include <gc/gc.h>
#endif
```

**Effort**: **1-2 days** (just find/replace)

**Verdict**: ✅ **Best for MVP/POC**

---

### Option 2: Emscripten's Built-in GC Support

**Approach**: Use Emscripten's GC features (if available)

**Research Needed**: Check if Emscripten has GC support

**Status**: ⚠️ **Needs investigation**

Emscripten may have:
- Reference counting
- Simple mark-and-sweep
- Integration with JavaScript GC

**Effort**: **1 week** (if it exists)

---

### Option 3: Simple Reference Counting

**Approach**: Implement basic ref counting for MDL objects

**Pros**:
- ✅ Handles most cases
- ✅ No leaks
- ✅ Simpler than full GC

**Cons**:
- ❌ Doesn't handle circular references
- ❌ More complex than Option 1
- ❌ Need to track refs manually

**Effort**: **1-2 weeks**

**Verdict**: ⚠️ **Possible but complex**

---

### Option 4: Simple Mark-and-Sweep GC

**Approach**: Implement minimal GC ourselves

**Pros**:
- ✅ Handles circular refs
- ✅ No leaks
- ✅ Full control

**Cons**:
- ❌ Significant implementation effort
- ❌ Need to scan all objects
- ❌ More complex

**Effort**: **2-3 weeks**

**Verdict**: ⚠️ **Overkill for MVP**

---

### Option 5: Port Boehm GC to WASM

**Approach**: Make Boehm GC work in WASM

**Pros**:
- ✅ Preserves existing code
- ✅ Proven GC algorithm

**Cons**:
- ❌ Complex porting effort
- ❌ Boehm GC relies on stack scanning (may not work in WASM)
- ❌ Large codebase

**Effort**: **3-4 weeks**

**Verdict**: ❌ **Not recommended**

---

## Memory Leak Analysis

### How Bad Would Leaks Be?

**Typical Zork Game Session**:
- Game loads: ~5-10 MB
- During play: ~10-50 MB (depending on actions)
- Save file: ~100-500 KB

**Leak Rate** (estimated):
- ~1-5 MB per hour of gameplay
- For a 2-hour session: ~2-10 MB leaked

**Browser Context**:
- Modern browsers: 2-4 GB RAM typical
- User closes tab: All memory freed
- Acceptable for single session

**Conclusion**: ✅ **Leaks are acceptable for browser use case**

---

## Recommended Approach

### Phase 1: MVP (Week 1)
**Use Option 1**: Simple malloc replacement
- Fastest to implement
- Gets WASM working quickly
- Acceptable for proof of concept

### Phase 2: Production (If Needed)
**Consider Option 2 or 3** if:
- Users report memory issues
- Need long-running sessions
- Want to support mobile devices

---

## Code Changes Required

### Minimal Changes (Option 1)

**1. Create `gc_stub.h`**:
```cpp
#ifndef GC_STUB_H
#define GC_STUB_H

#ifdef __EMSCRIPTEN__
    // WASM: Use standard malloc
    #include <stdlib.h>
    #define GC_MALLOC malloc
    #define GC_REALLOC realloc
    #define GC_FREE free
    #define GC_MALLOC_ATOMIC malloc
    #define GC_MALLOC_IGNORE_OFF_PAGE malloc
    #define GC_INIT() 
    #define GC_gcollect() 
    #define GC_gc_no 0
    typedef int GC_word;
#else
    // Native: Use Boehm GC
    #include <gc/gc.h>
    #include <gc/gc_allocator.h>
    #include <gc/gc_cpp.h>
#endif

#endif
```

**2. Replace includes**:
```cpp
// Old:
#include <gc/gc.h>

// New:
#include "gc_stub.h"
```

**3. Update Makefile**:
```makefile
# Remove GC library linking for WASM
ifdef WASM
    LIBS = 
else
    LIBS = -lgc -lgccpp
endif
```

---

## Testing Strategy

### Memory Leak Test
1. Load game in browser
2. Play for 1 hour
3. Check memory usage (Chrome DevTools)
4. Verify acceptable growth

### Performance Test
1. Compare malloc vs GC performance
2. Measure game responsiveness
3. Check for GC-related pauses

---

## Conclusion

**Answer**: We don't need Boehm GC, but we can't rely on JavaScript GC either.

**Best Approach**: 
1. **Start with Option 1** (malloc replacement)
2. **Accept leaks** for MVP
3. **Upgrade later** if needed (ref counting or simple GC)

**Effort Reduction**: From 1-2 weeks (GC port) → **1-2 days** (malloc replacement)

**Risk**: Low - leaks are acceptable for browser game sessions
