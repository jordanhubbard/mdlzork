# MDL Zork - Static GitHub Pages PWA Implementation Plan

## Executive Summary

Transform mdlzork from a server-dependent Flask application into a fully static Progressive Web App (PWA) hosted on GitHub Pages. This will allow users to play Zork entirely in their browser without running any local server, with offline capability and installability.

## Current State vs Target State

### Current Architecture
- Native MDL interpreter compiled with GCC + Boehm GC
- Flask + SocketIO server proxying terminal I/O
- WebSocket-based browser communication
- Requires: Python, Flask, local server running

### Target Architecture
- WASM MDL interpreter compiled with Emscripten
- Static HTML/JavaScript interface
- File System API for game saves
- Direct browser execution, no server needed
- Hosted on GitHub Pages with automatic CI/CD deployment

## Key Technical Challenges

1. **Memory Management**: Replace Boehm GC with custom allocator for WASM
2. **File I/O**: Emscripten's virtual filesystem (MEMFS/IDBFS) for game data
3. **Terminal Emulation**: Browser-based terminal using xterm.js or similar
4. **Build Pipeline**: Emscripten compilation in GitHub Actions
5. **CORS/Headers**: Proper configuration for WASM loading and potential threading

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│           GitHub Pages (Static Host)            │
├─────────────────────────────────────────────────┤
│                                                 │
│  index.html                                     │
│  ├── xterm.js (Terminal UI)                    │
│  ├── mdli.js (Emscripten glue code)           │
│  └── mdli.wasm (Compiled MDL interpreter)      │
│                                                 │
│  manifest.json (PWA manifest)                   │
│  sw.js (Service Worker for offline)            │
│                                                 │
│  game-data/                                     │
│  ├── mdlzork_771212/                           │
│  ├── mdlzork_780124/                           │
│  ├── mdlzork_791211/                           │
│  └── mdlzork_810722/                           │
│                                                 │
└─────────────────────────────────────────────────┘
         ▲
         │ Deployed via GitHub Actions
         │
┌────────┴─────────────────────────────────────────┐
│  .github/workflows/deploy-wasm.yml              │
│  - Install Emscripten                            │
│  - Compile mdli to WASM                          │
│  - Bundle with game files                        │
│  - Deploy to gh-pages branch                     │
└──────────────────────────────────────────────────┘
```

---

## Implementation Milestones

### Milestone 1: WASM Build Foundation
**Goal**: Get MDL interpreter compiling to WebAssembly without dependencies

**Files to Create/Modify**:
- `confusion-mdl/Makefile.wasm`
- `confusion-mdl/gc_stub.h`
- `confusion-mdl/wasm_config.h`

**Steps**:

1.1. **Create GC Stub Header**
   - File: `confusion-mdl/gc_stub.h`
   - Replace Boehm GC calls with simple malloc/free
   - Initial implementation: no actual garbage collection (rely on WASM memory management)
   - Add placeholder for future mark-and-sweep if needed
   ```c
   // Key functions to stub:
   // GC_malloc, GC_malloc_atomic, GC_realloc, GC_free
   // GC_init, GC_gcollect
   ```

1.2. **Create WASM-specific Configuration**
   - File: `confusion-mdl/wasm_config.h`
   - Define WASM-specific settings (stack size, memory limits)
   - Disable features unsupported in WASM (signals, fork, etc.)
   - Configure Emscripten filesystem paths

1.3. **Create WASM Makefile**
   - File: `confusion-mdl/Makefile.wasm`
   - Compiler: `emcc` instead of `gcc`
   - Flags:
     - `-s WASM=1` - Enable WebAssembly
     - `-s ALLOW_MEMORY_GROWTH=1` - Dynamic memory
     - `-s MODULARIZE=1 -s EXPORT_NAME='createMDLI'` - Module export
     - `-s EXPORTED_FUNCTIONS='["_main", "_mdl_eval", ...]'` - Export key functions
     - `-s EXPORTED_RUNTIME_METHODS='["FS", "callMain", "TTY"]'` - Filesystem API
     - `-s FORCE_FILESYSTEM=1` - Enable filesystem
     - `--preload-file ../mdlzork_810722@/game` - Embed game files
   - Link against gc_stub instead of libgc
   - Output: `mdli.js`, `mdli.wasm`, `mdli.data`

1.4. **Test Basic Compilation**
   ```bash
   cd confusion-mdl
   make -f Makefile.wasm clean
   make -f Makefile.wasm
   # Should produce: mdli.js, mdli.wasm
   ```

**Validation**:
- [ ] WASM files compile without errors
- [ ] Output files exist: `mdli.js`, `mdli.wasm`
- [ ] File sizes reasonable (< 5MB for wasm, < 500KB for js)
- [ ] No Boehm GC references in compiled output

**Expected Issues & Solutions**:
- **Issue**: Missing C++ standard library functions
  - **Solution**: Add `-s USE_BOOST_HEADERS=1` or include emscripten ports
- **Issue**: Undefined symbols related to GC
  - **Solution**: Verify all GC_* calls are stubbed in gc_stub.h
- **Issue**: File I/O fails
  - **Solution**: Ensure FORCE_FILESYSTEM and preload-file are set

---

### Milestone 2: Minimal Web Interface
**Goal**: Create basic HTML page that loads and initializes WASM module

**Files to Create**:
- `web/index.html`
- `web/style.css`
- `web/app.js`
- `web/test-simple.html` (minimal test page)

**Steps**:

2.1. **Create Minimal Test Page**
   - File: `web/test-simple.html`
   - Load emscripten-generated `mdli.js`
   - Display load status
   - Log WASM module initialization
   - Test basic function calls
   ```html
   <script src="../confusion-mdl/mdli.js"></script>
   <script>
     createMDLI().then(Module => {
       console.log('WASM loaded:', Module);
       // Test calling main()
     });
   </script>
   ```

2.2. **Create Basic UI Structure**
   - File: `web/index.html`
   - Header with game version selector
   - Terminal display area (div for now, xterm.js later)
   - Input field for commands
   - Status bar (loading, ready, error)

2.3. **Create Core JavaScript Logic**
   - File: `web/app.js`
   - Module loading and initialization
   - Set up Emscripten FS to mount game directories
   - Create stdin/stdout handlers
   - Route user input to WASM stdin
   - Display WASM stdout to terminal div

2.4. **Add Basic Styling**
   - File: `web/style.css`
   - Retro terminal appearance (green on black)
   - Monospace font
   - Responsive layout
   - Loading spinner

**Testing**:
   ```bash
   # Build WASM
   cd confusion-mdl && make -f Makefile.wasm
   
   # Serve locally
   cd ..
   python3 -m http.server 8000
   
   # Open browser to localhost:8000/web/test-simple.html
   # Check console for successful WASM load
   
   # Open browser to localhost:8000/web/index.html
   # Verify UI displays
   ```

**Validation**:
- [ ] WASM module loads without errors
- [ ] Can call Module.callMain() successfully
- [ ] Stdin/stdout proxying works
- [ ] Can select game version
- [ ] Basic text I/O functions

**Expected Issues & Solutions**:
- **Issue**: CORS errors loading .wasm file
  - **Solution**: Use http.server with proper MIME types
- **Issue**: Module not exported correctly
  - **Solution**: Check Makefile.wasm has `-s MODULARIZE=1`
- **Issue**: Game files not found
  - **Solution**: Verify --preload-file path in Makefile.wasm

---

### Milestone 3: Terminal Integration
**Goal**: Professional terminal emulation with full ANSI support

**Files to Create/Modify**:
- `web/index.html` (add xterm.js)
- `web/app.js` (integrate terminal)
- `package.json` (for xterm.js via CDN or npm)

**Steps**:

3.1. **Integrate xterm.js**
   - Add xterm.js from CDN to index.html
   - Or use npm: `npm install xterm xterm-addon-fit`
   - Initialize terminal in app.js
   - Configure terminal size, scrollback

3.2. **Set Up Emscripten TTY**
   - Configure Emscripten's TTY module to use xterm.js
   - Override stdin: read from xterm input
   - Override stdout: write to xterm display
   - Override stderr: write to xterm with color
   - Handle special keys (Ctrl+C, arrows, etc.)

3.3. **Implement Command History**
   - Add xterm-addon-search for in-terminal search
   - Store command history in localStorage
   - Up/Down arrow for history navigation
   - Tab completion for common commands (optional)

3.4. **Handle Terminal Resize**
   - Use xterm-addon-fit
   - Update WASM tty size on window resize
   - Ensure game output wraps correctly

**Testing**:
   ```bash
   # Build and serve
   make -C confusion-mdl -f Makefile.wasm
   python3 -m http.server 8000 --directory web
   
   # Test:
   # 1. Type commands, verify they appear in terminal
   # 2. Verify game output displays correctly
   # 3. Test Ctrl+C, backspace, arrow keys
   # 4. Resize browser window, check terminal adapts
   # 5. Test command history (up/down arrows)
   ```

**Validation**:
- [ ] Terminal displays properly
- [ ] Input echoes correctly
- [ ] Game output appears without artifacts
- [ ] Resize works smoothly
- [ ] Command history functional

---

### Milestone 4: Game Data Management
**Goal**: Properly package and load multiple game versions

**Files to Create/Modify**:
- `confusion-mdl/Makefile.wasm` (update preload)
- `web/app.js` (game version switching)
- `scripts/prepare-game-data.sh`

**Steps**:

4.1. **Create Game Data Preparation Script**
   - File: `scripts/prepare-game-data.sh`
   - Copy essential files from each mdlzork_* directory
   - Remove unnecessary files (docs, originals)
   - Create directory structure for Emscripten
   - Generate metadata.json with game info

4.2. **Update WASM Build to Preload All Games**
   - Modify Makefile.wasm
   - Use multiple `--preload-file` flags:
     ```makefile
     --preload-file ../game-data/mdlzork_771212@/games/mdlzork_771212 \
     --preload-file ../game-data/mdlzork_780124@/games/mdlzork_780124 \
     # etc...
     ```
   - Or generate single .data file with all games

4.3. **Implement Game Version Selector**
   - UI dropdown with all versions
   - Display game metadata (points, year, description)
   - On selection:
     - Reset WASM instance (or restart)
     - Change working directory in Emscripten FS
     - Load appropriate save file
     - Display game info in terminal

4.4. **Handle Save Files**
   - Implement IDBFS for persistent saves
   - Mount /saves to IndexedDB
   - Auto-save on SAVE command
   - Load saved games on startup
   - Export/import save files feature

**Testing**:
   ```bash
   # Prepare game data
   ./scripts/prepare-game-data.sh
   
   # Build with all games
   make -C confusion-mdl -f Makefile.wasm clean
   make -C confusion-mdl -f Makefile.wasm
   
   # Verify mdli.data contains all games
   ls -lh confusion-mdl/mdli.data
   
   # Test in browser:
   # 1. Select different game versions
   # 2. Verify correct game loads
   # 3. Make progress in game, save
   # 4. Refresh page, load save
   # 5. Export save, import in new browser
   ```

**Validation**:
- [ ] All game versions accessible
- [ ] Switching versions works smoothly
- [ ] Saves persist across sessions
- [ ] Export/import saves functional
- [ ] .data file size < 10MB

---

### Milestone 5: PWA Features
**Goal**: Make app installable and work offline

**Files to Create**:
- `web/manifest.json`
- `web/sw.js` (service worker)
- `web/icons/` (app icons)
- `web/offline.html`

**Steps**:

5.1. **Create Web App Manifest**
   - File: `web/manifest.json`
   - App name, description, theme colors
   - Icons (192x192, 512x512)
   - Start URL, display mode (standalone)
   - Orientation (portrait/landscape/any)

5.2. **Generate App Icons**
   - Create icon at 512x512 (SVG or PNG)
   - Theme: Retro adventure game aesthetic
   - Generate sizes: 192x192, 512x512, 180x180 (iOS)
   - Add maskable icon variant

5.3. **Implement Service Worker**
   - File: `web/sw.js`
   - Cache strategy: Cache-first for static assets
   - Network-first for game data (allow updates)
   - Offline fallback page
   - Version management for cache updates
   ```javascript
   const CACHE_NAME = 'mdlzork-v1';
   const urlsToCache = [
     '/',
     '/index.html',
     '/style.css',
     '/app.js',
     '/mdli.js',
     '/mdli.wasm',
     '/mdli.data'
   ];
   ```

5.4. **Register Service Worker**
   - In index.html or app.js
   - Check for service worker support
   - Register sw.js
   - Handle updates (prompt user to refresh)
   - Show install prompt on desktop

5.5. **Add Offline Support**
   - Detect offline state
   - Show offline indicator
   - Queue commands if needed
   - Display cached games
   - Create offline.html for fallback

**Testing**:
   ```bash
   # Build and serve
   make -C confusion-mdl -f Makefile.wasm
   python3 -m http.server 8000 --directory web
   
   # Test:
   # 1. Open Chrome DevTools > Application
   # 2. Verify manifest loads correctly
   # 3. Check service worker registers
   # 4. Test offline mode (DevTools > Network > Offline)
   # 5. Install app (should see install prompt)
   # 6. Launch installed app
   # 7. Verify works offline after installation
   ```

**Validation**:
- [ ] Manifest valid in Lighthouse
- [ ] Service worker caches all assets
- [ ] App works offline
- [ ] Install prompt appears
- [ ] Installed app launches correctly
- [ ] PWA score > 90 in Lighthouse

---

### Milestone 6: GitHub Actions CI/CD
**Goal**: Automated build and deployment to GitHub Pages

**Files to Create**:
- `.github/workflows/deploy-wasm.yml`
- `.github/workflows/test-build.yml`
- `scripts/build-for-pages.sh`

**Steps**:

6.1. **Create Build Script**
   - File: `scripts/build-for-pages.sh`
   - Install Emscripten SDK
   - Prepare game data
   - Build WASM with Makefile.wasm
   - Copy files to dist/ directory
   - Structure for GitHub Pages:
     ```
     dist/
     ├── index.html
     ├── style.css
     ├── app.js
     ├── manifest.json
     ├── sw.js
     ├── icons/
     ├── mdli.js
     ├── mdli.wasm
     └── mdli.data
     ```

6.2. **Create Test Workflow**
   - File: `.github/workflows/test-build.yml`
   - Trigger: on pull request
   - Steps:
     1. Checkout code
     2. Cache Emscripten SDK
     3. Run build script
     4. Verify output files exist
     5. Check file sizes
     6. Run basic tests (optional)

6.3. **Create Deployment Workflow**
   - File: `.github/workflows/deploy-wasm.yml`
   - Trigger: on push to main/master
   - Steps:
     1. Checkout code
     2. Cache Emscripten SDK
     3. Run build script
     4. Deploy to gh-pages branch
   - Use `peaceiris/actions-gh-pages@v3`
   - Configure custom domain if desired

6.4. **Configure GitHub Pages**
   - Enable GitHub Pages in repository settings
   - Source: gh-pages branch
   - Optional: Add custom domain
   - Set up HTTPS (automatic with GitHub Pages)

6.5. **Add Build Status Badge**
   - Update README.md with build badge
   - Add link to live demo
   - Update documentation for new workflow

**Testing**:
   ```bash
   # Test build script locally
   ./scripts/build-for-pages.sh
   ls -la dist/
   
   # Serve dist locally
   python3 -m http.server 8000 --directory dist
   # Verify everything works
   
   # Push to GitHub
   git add .github/ scripts/
   git commit -m "Add CI/CD for GitHub Pages"
   git push
   
   # Monitor GitHub Actions
   # Check gh-pages branch created
   # Visit https://<username>.github.io/<repo>/
   ```

**Validation**:
- [ ] Build workflow succeeds
- [ ] gh-pages branch created with correct files
- [ ] GitHub Pages site accessible
- [ ] All assets load correctly
- [ ] PWA installable from live site
- [ ] No console errors on live site

---

### Milestone 7: Cleanup & Migration
**Goal**: Remove old Flask code, update documentation, finalize

**Files to Modify/Remove**:
- `Makefile` (update WASM targets)
- `README.md` (complete rewrite of Quick Start)
- Remove `zork_launcher.py`
- Remove `templates/`
- Remove Flask from `requirements.txt`
- Update all documentation files

**Steps**:

7.1. **Update Main Makefile**
   - Replace stub WASM targets with real implementation
   - Add targets:
     - `make build-wasm` → calls Makefile.wasm
     - `make serve-wasm` → serves web/ locally
     - `make deploy-wasm` → triggers GitHub Actions deploy
     - `make build-all` → builds both native and WASM
   - Update help text

7.2. **Remove Flask Dependencies**
   - Delete `zork_launcher.py`
   - Delete `templates/` directory
   - Update `requirements.txt` (remove Flask, SocketIO)
   - Keep Python for local test server only

7.3. **Update README.md**
   - New Quick Start:
     ```markdown
     ## Quick Start
     
     ### Play Online
     Visit https://<user>.github.io/mdlzork/
     
     ### Build Locally
     ```bash
     make build-wasm
     make serve-wasm
     # Open http://localhost:8000
     ```
   - Update architecture description
   - Update all references to WASM
   - Remove server-based instructions

7.4. **Update Other Documentation**
   - Create `docs/WASM.md` - detailed WASM build docs
   - Create `docs/PWA.md` - PWA features docs
   - Create `docs/DEVELOPMENT.md` - contributor guide
   - Update build instructions
   - Add troubleshooting section

7.5. **Create Migration Guide**
   - File: `MIGRATION.md`
   - For users of old Flask version
   - Explain changes
   - How to migrate saved games (if applicable)
   - Backward compatibility notes

**Testing**:
   ```bash
   # Test fresh clone experience
   cd /tmp
   git clone <repo>
   cd mdlzork
   
   # Follow README quick start
   # Should work without any issues
   
   # Verify:
   # - No Flask references in docs
   # - make help shows correct targets
   # - All documentation links work
   # - Build succeeds
   ```

**Validation**:
- [ ] No Flask code remains
- [ ] README accurate and complete
- [ ] All make targets work
- [ ] Documentation consistent
- [ ] Fresh clone → successful build
- [ ] Live site fully functional

---

### Milestone 8: Testing & Polish
**Goal**: Comprehensive testing, performance optimization, bug fixes

**Steps**:

8.1. **Browser Compatibility Testing**
   - Test on Chrome (desktop & mobile)
   - Test on Firefox (desktop & mobile)
   - Test on Safari (desktop & iOS)
   - Test on Edge
   - Document any issues and workarounds

8.2. **Performance Optimization**
   - Analyze bundle sizes
   - Enable compression in service worker
   - Optimize game data loading
   - Lazy-load non-critical resources
   - Profile WASM performance
   - Optimize memory usage

8.3. **Accessibility Testing**
   - Keyboard navigation
   - Screen reader support
   - ARIA labels
   - Color contrast
   - Font size adjustments
   - Run Lighthouse accessibility audit

8.4. **User Experience Polish**
   - Loading indicators
   - Error messages (user-friendly)
   - Smooth transitions
   - Mobile responsiveness
   - Touch controls
   - Help/tutorial section

8.5. **Security & Privacy**
   - Content Security Policy headers
   - No tracking or analytics (or make optional)
   - Secure save file handling
   - Check for XSS vulnerabilities

8.6. **Create Test Suite**
   - Unit tests for JavaScript functions
   - E2E tests (Playwright/Puppeteer)
   - Test game loading
   - Test save/load functionality
   - Test version switching

**Testing Matrix**:
   ```
   Browser     | Desktop | Mobile | PWA Install | Offline
   ------------|---------|--------|-------------|--------
   Chrome      |    ✓    |   ✓    |      ✓      |   ✓
   Firefox     |    ✓    |   ✓    |      ✓      |   ✓
   Safari      |    ✓    |   ✓    |      ✓      |   ✓
   Edge        |    ✓    |   N/A  |      ✓      |   ✓
   ```

**Validation**:
- [ ] All browsers work correctly
- [ ] Lighthouse score > 90 (all categories)
- [ ] No console errors/warnings
- [ ] Smooth user experience
- [ ] All tests pass
- [ ] Security headers configured

---

## Rollback Strategy

If issues arise at any milestone:

1. **Keep Native Build**: Never remove working native build until WASM is proven
2. **Feature Flags**: Use URL parameters to enable/test new features
3. **Git Branches**: Develop on feature branch, merge only when validated
4. **Version Tags**: Tag each milestone for easy rollback
5. **Staged Deployment**: Deploy to test subdomain before main site

## Success Criteria

The project will be considered successfully migrated when:

1. ✅ WASM build produces working interpreter
2. ✅ Static site runs without any server dependencies
3. ✅ All game versions playable in browser
4. ✅ PWA installable and works offline
5. ✅ Deployed and accessible via GitHub Pages
6. ✅ CI/CD automatically deploys updates
7. ✅ Documentation complete and accurate
8. ✅ Native build still available as fallback
9. ✅ No Flask or server code remains
10. ✅ Lighthouse PWA score > 90

## Resource Requirements

**Time Estimate**: 30-50 hours development time
- Milestone 1: 6-8 hours
- Milestone 2: 4-6 hours
- Milestone 3: 3-4 hours
- Milestone 4: 5-7 hours
- Milestone 5: 4-6 hours
- Milestone 6: 3-4 hours
- Milestone 7: 2-3 hours
- Milestone 8: 3-5 hours

**Skills Required**:
- C/C++ compilation and debugging
- WebAssembly / Emscripten
- JavaScript (ES6+)
- HTML5 APIs (Service Workers, IndexedDB)
- GitHub Actions
- PWA development

**Tools Needed**:
- Emscripten SDK (auto-installed by Makefile)
- Node.js (optional, for package management)
- Modern browser with DevTools
- GitHub account with Pages enabled

## Future Enhancements (Post-MVP)

1. **Multiplayer**: WebRTC for shared game sessions
2. **Cloud Saves**: Optional cloud sync via GitHub Gists or Firebase
3. **Themes**: Multiple terminal color schemes
4. **Sound**: Optional audio effects
5. **Mobile Optimizations**: Virtual keyboard, swipe gestures
6. **Speedrun Mode**: Timer and leaderboard
7. **Walkthrough Integration**: Hint system
8. **Game Editor**: Modify game files in browser
9. **Analytics**: Optional, privacy-respecting usage stats
10. **Localization**: Translate to other languages

## References & Resources

- [Emscripten Documentation](https://emscripten.org/docs/)
- [xterm.js Documentation](https://xtermjs.org/)
- [PWA Documentation](https://web.dev/progressive-web-apps/)
- [GitHub Pages Documentation](https://docs.github.com/en/pages)
- [Service Workers API](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)
- [IndexedDB API](https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API)

---

## Appendix A: Key Code Snippets

### gc_stub.h skeleton
```c
#ifndef GC_STUB_H
#define GC_STUB_H

#include <stdlib.h>
#include <string.h>

#define GC_MALLOC(n) malloc(n)
#define GC_MALLOC_ATOMIC(n) malloc(n)
#define GC_REALLOC(p, n) realloc(p, n)
#define GC_FREE(p) free(p)
#define GC_INIT() ((void)0)
#define GC_gcollect() ((void)0)

// TODO: Implement proper mark-and-sweep if memory issues arise
#endif
```

### Makefile.wasm skeleton
```makefile
CC = emcc
CFLAGS = -O3 -DGC_STUB -I.
LDFLAGS = -s WASM=1 \
          -s ALLOW_MEMORY_GROWTH=1 \
          -s MODULARIZE=1 \
          -s EXPORT_NAME='createMDLI' \
          -s FORCE_FILESYSTEM=1 \
          --preload-file ../game-data@/

mdli.js: mdli.o ...
	$(CC) $(LDFLAGS) -o $@ $^
```

### Service Worker skeleton
```javascript
const CACHE_NAME = 'mdlzork-v1';
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => 
      cache.addAll(['/index.html', '/mdli.wasm', ...])
    )
  );
});
```

## Appendix B: File Structure (Final State)

```
mdlzork/
├── .github/
│   └── workflows/
│       ├── deploy-wasm.yml
│       └── test-build.yml
├── confusion-mdl/         # MDL interpreter (submodule)
│   ├── Makefile           # Native build
│   ├── Makefile.wasm      # WASM build
│   ├── gc_stub.h          # GC replacement
│   └── ...
├── game-data/             # Prepared game files
│   ├── mdlzork_771212/
│   ├── mdlzork_780124/
│   ├── mdlzork_791211/
│   └── mdlzork_810722/
├── web/                   # Static site source
│   ├── index.html
│   ├── style.css
│   ├── app.js
│   ├── manifest.json
│   ├── sw.js
│   └── icons/
├── scripts/
│   ├── build-for-pages.sh
│   └── prepare-game-data.sh
├── docs/
│   ├── WASM.md
│   ├── PWA.md
│   └── DEVELOPMENT.md
├── Makefile               # Updated with real WASM targets
├── README.md              # Updated for static site
├── PLAN.md                # This file
└── MIGRATION.md           # Migration guide
```
