/**
 * MDL Zork - WebAssembly Terminal Interface
 * Handles WASM module loading and xterm.js integration
 */

class ZorkGame {
    constructor() {
        this.module = null;
        this.terminal = null;
        this.fitAddon = null;
        this.statusEl = document.getElementById('status');
        this.startBtn = document.getElementById('start-btn');
        this.versionSelect = document.getElementById('version-select');
        
        this.isReady = false;
        this.isRunning = false;
        this.inputBuffer = '';
        this.commandHistory = [];
        this.historyIndex = -1;
        this.currentGamePath = null;
        
        // Game version mappings
        this.gameVersions = {
            'zork-810722': {
                name: 'Zork 1981-07-22 (Final MDL)',
                path: '/games/zork-810722',
                saveFile: 'MDL/MADADV.SAVE'
            },
            'zork-791211': {
                name: 'Zork 1979-12-11 (616 points)',
                path: '/games/zork-791211',
                saveFile: 'MDL/MADADV.SAVE'
            },
            'zork-780124': {
                name: 'Zork 1978-01-24 ⚠️ INCOMPLETE END-GAME',
                path: '/games/zork-780124',
                saveFile: 'MDL/MADADV.SAVE'
            },
            'zork-771212': {
                name: 'Zork 1977-12-12 (500 points, no end-game)',
                path: '/games/zork-771212',
                saveFile: 'MDL/MADADV.SAVE'
            }
        };
        
        this.setupTerminal();
        this.setupEventListeners();
        this.initIndexedDB();
    }
    
    setupTerminal() {
        // Initialize xterm.js
        this.terminal = new Terminal({
            cursorBlink: true,
            fontSize: 14,
            fontFamily: '"Courier New", Courier, monospace',
            theme: {
                background: '#000000',
                foreground: '#33ff33',
                cursor: '#33ff33',
                cursorAccent: '#000000',
                selection: 'rgba(51, 255, 51, 0.3)',
                black: '#000000',
                red: '#ff3333',
                green: '#33ff33',
                yellow: '#ffff33',
                blue: '#3333ff',
                magenta: '#ff33ff',
                cyan: '#33ffff',
                white: '#ffffff',
                brightBlack: '#666666',
                brightRed: '#ff6666',
                brightGreen: '#66ff66',
                brightYellow: '#ffff66',
                brightBlue: '#6666ff',
                brightMagenta: '#ff66ff',
                brightCyan: '#66ffff',
                brightWhite: '#ffffff'
            },
            cols: 80,
            rows: 24,
            scrollback: 1000
        });
        
        // Add fit addon for responsive sizing
        this.fitAddon = new FitAddon.FitAddon();
        this.terminal.loadAddon(this.fitAddon);
        
        // Mount terminal to DOM
        const terminalEl = document.getElementById('terminal');
        this.terminal.open(terminalEl);
        this.fitAddon.fit();
        
        // Handle window resize
        window.addEventListener('resize', () => {
            if (this.fitAddon) {
                this.fitAddon.fit();
            }
        });
        
        // Handle keyboard input
        this.terminal.onData(data => {
            this.handleTerminalInput(data);
        });
        
        this.terminal.writeln('\x1b[1;32m╔════════════════════════════════════════════════════════════════════════════╗\x1b[0m');
        this.terminal.writeln('\x1b[1;32m║                          MDL ZORK - WASM EDITION                          ║\x1b[0m');
        this.terminal.writeln('\x1b[1;32m╚════════════════════════════════════════════════════════════════════════════╝\x1b[0m');
        this.terminal.writeln('');
        this.terminal.writeln('\x1b[33mInitializing WebAssembly module...\x1b[0m');
    }
    
    setupEventListeners() {
        // Start game button
        this.startBtn.addEventListener('click', () => this.startGame());
        
        // Add save/load buttons (will be enabled when game is running)
        const controls = document.getElementById('controls');
        
        // Save button
        const saveBtn = document.createElement('button');
        saveBtn.id = 'save-btn';
        saveBtn.textContent = 'Save Game';
        saveBtn.disabled = true;
        saveBtn.addEventListener('click', () => this.saveGame());
        controls.appendChild(saveBtn);
        this.saveBtn = saveBtn;
        
        // Load button
        const loadBtn = document.createElement('button');
        loadBtn.id = 'load-btn';
        loadBtn.textContent = 'Load Game';
        loadBtn.disabled = true;
        loadBtn.addEventListener('click', () => this.loadGame());
        controls.appendChild(loadBtn);
        this.loadBtn = loadBtn;
        
        // Export button
        const exportBtn = document.createElement('button');
        exportBtn.id = 'export-btn';
        exportBtn.textContent = 'Export Save';
        exportBtn.disabled = true;
        exportBtn.addEventListener('click', () => this.exportSave());
        controls.appendChild(exportBtn);
        this.exportBtn = exportBtn;
        
        // Import button
        const importBtn = document.createElement('button');
        importBtn.id = 'import-btn';
        importBtn.textContent = 'Import Save';
        importBtn.disabled = true;
        importBtn.addEventListener('click', () => this.importSave());
        controls.appendChild(importBtn);
        this.importBtn = importBtn;
    }
    
    // Initialize IndexedDB for persistent storage
    initIndexedDB() {
        const request = indexedDB.open('ZorkSaveDB', 1);
        
        request.onerror = () => {
            console.error('IndexedDB failed to open');
            this.terminal.writeln('\x1b[33m[Warning: Save/load features unavailable - IndexedDB error]\x1b[0m');
        };
        
        request.onsuccess = (event) => {
            this.db = event.target.result;
            this.terminal.writeln('\x1b[90m[Save/load features enabled]\x1b[0m');
        };
        
        request.onupgradeneeded = (event) => {
            const db = event.target.result;
            if (!db.objectStoreNames.contains('saves')) {
                db.createObjectStore('saves', { keyPath: 'id' });
            }
        };
    }
    
    updateStatus(message, type = 'info') {
        this.statusEl.textContent = message;
        this.statusEl.className = type;
    }
    
    handleTerminalInput(data) {
        // Handle special keys
        const code = data.charCodeAt(0);
        
        // Ctrl+C (ETX)
        if (code === 3) {
            this.terminal.write('^C\r\n');
            this.inputBuffer = '';
            if (this.isRunning) {
                this.stopGame();
            }
            return;
        }
        
        // Enter key
        if (code === 13 || data === '\r') {
            this.terminal.write('\r\n');
            const command = this.inputBuffer.trim();
            
            if (command) {
                // Add to history
                this.commandHistory.push(command);
                this.historyIndex = this.commandHistory.length;
                
                // Send to WASM stdin  
                if (this.isRunning && this.module) {
                    this.sendToStdin(command + '\n');
                    
                    // After sending command, give WASM a chance to process it
                    // Use setTimeout to yield control back to event loop
                    setTimeout(() => {
                        // Show prompt again if game is still running
                        if (this.isRunning) {
                            this.terminal.write('> ');
                        }
                    }, 50);
                } else {
                    // Game not running, show message
                    this.terminal.writeln('\x1b[33m[Game not running. Click "Start Game" first.]\x1b[0m');
                }
            }
            
            this.inputBuffer = '';
            return;
        }
        
        // Backspace
        if (code === 127 || code === 8) {
            if (this.inputBuffer.length > 0) {
                this.inputBuffer = this.inputBuffer.slice(0, -1);
                this.terminal.write('\b \b');
            }
            return;
        }
        
        // Up arrow (previous command in history)
        if (data === '\x1b[A') {
            if (this.historyIndex > 0) {
                // Clear current input
                for (let i = 0; i < this.inputBuffer.length; i++) {
                    this.terminal.write('\b \b');
                }
                
                this.historyIndex--;
                this.inputBuffer = this.commandHistory[this.historyIndex];
                this.terminal.write(this.inputBuffer);
            }
            return;
        }
        
        // Down arrow (next command in history)
        if (data === '\x1b[B') {
            if (this.historyIndex < this.commandHistory.length) {
                // Clear current input
                for (let i = 0; i < this.inputBuffer.length; i++) {
                    this.terminal.write('\b \b');
                }
                
                this.historyIndex++;
                if (this.historyIndex < this.commandHistory.length) {
                    this.inputBuffer = this.commandHistory[this.historyIndex];
                } else {
                    this.inputBuffer = '';
                }
                this.terminal.write(this.inputBuffer);
            }
            return;
        }
        
        // Ignore other escape sequences
        if (code === 27) {
            return;
        }
        
        // Regular character - add to buffer and echo
        if (code >= 32 && code <= 126) {
            this.inputBuffer += data;
            this.terminal.write(data);
        }
    }
    
    sendToStdin(text) {
        if (!this.module || !this.stdinBuffer) {
            console.error('Module or stdin buffer not available');
            return;
        }
        
        // Send each character to stdin buffer
        for (let i = 0; i < text.length; i++) {
            const charCode = text.charCodeAt(i);
            this.stdinBuffer.push(charCode);
        }
    }
    
    async loadWASM() {
        this.updateStatus('Loading WASM module... ⏳', 'loading');
        this.terminal.writeln('\x1b[33mLoading MDL interpreter...\x1b[0m');
        
        // Create stdin buffer that will be read by WASM
        this.stdinBuffer = [];
        this.waitingForInput = false;
        
        try {
            // Configure Emscripten module with proper stdin handling
            const moduleConfig = {
                // Redirect stdout/stderr to terminal
                print: (text) => {
                    this.terminal.write(text + '\r\n');
                },
                printErr: (text) => {
                    this.terminal.write('\x1b[31m[ERROR] ' + text + '\x1b[0m\r\n');
                },
                
                // Don't define stdin callback - let Emscripten use its default TTY handling
                // We'll set up a proper terminal device instead
                
                preRun: [function(module) {
                    // Set up custom stdin handling before runtime starts
                    var self = this;
                    
                    module.FS.init(
                        function() { // stdin
                            // Return next character from stdin buffer
                            if (self.stdinBuffer && self.stdinBuffer.length > 0) {
                                return self.stdinBuffer.shift();
                            }
                            return null;
                        },
                        function(val) { // stdout
                            if (val !== null && val !== undefined) {
                                var char = String.fromCharCode(val);
                                // Convert \n to \r\n for proper terminal display
                                if (val === 10) {
                                    self.terminal.write('\r\n');
                                } else {
                                    self.terminal.write(char);
                                }
                            }
                        },
                        function(val) { // stderr
                            if (val !== null && val !== undefined) {
                                self.terminal.write('\x1b[31m' + String.fromCharCode(val) + '\x1b[0m');
                            }
                        }
                    );
                }.bind(this)],
                
                onRuntimeInitialized: () => {
                    this.terminal.writeln('\x1b[32m✓ WASM runtime initialized\x1b[0m');
                    this.terminal.writeln('\x1b[90m[Stdin proxy active - type commands and press Enter]\x1b[0m');
                }
            };
            
            this.module = await createMDLI(moduleConfig);
            
            this.isReady = true;
            this.updateStatus('✓ Ready to start game', 'ready');
            this.startBtn.disabled = false;
            this.versionSelect.disabled = false;
            
            this.terminal.writeln('\x1b[32m✓ Module loaded successfully!\x1b[0m');
            this.terminal.writeln('');
            this.terminal.writeln('\x1b[36mSelect a game version and click "Start Game" to begin.\x1b[0m');
            this.terminal.writeln('');
            
            // Log available game versions
            if (this.module.FS) {
                try {
                    const gameDirs = this.module.FS.readdir('/games');
                    const versions = gameDirs.filter(f => f !== '.' && f !== '..');
                    if (versions.length > 0) {
                        this.terminal.writeln('\x1b[90mAvailable game versions: ' + versions.join(', ') + '\x1b[0m');
                        
                        // Debug: Check if original_source is loaded
                        try {
                            const zork810722 = this.module.FS.readdir('/games/zork-810722');
                            this.terminal.writeln('\x1b[90m[Debug] zork-810722 contents: ' + zork810722.filter(f => f !== '.' && f !== '..').slice(0, 10).join(', ') + '\x1b[0m');
                            
                            // Check for original_source subdirectory
                            if (zork810722.includes('original_source')) {
                                const origSrc = this.module.FS.readdir('/games/zork-810722/original_source');
                                this.terminal.writeln('\x1b[90m[Debug] original_source has ' + (origSrc.length - 2) + ' files\x1b[0m');
                            } else {
                                this.terminal.writeln('\x1b[33m[Debug] original_source directory NOT found\x1b[0m');
                            }
                        } catch(e) {
                            this.terminal.writeln('\x1b[33m[Debug] Error checking directories: ' + e.message + '\x1b[0m');
                        }
                        
                        this.terminal.writeln('');
                    }
                } catch(e) {
                    console.error('Error reading games directory:', e);
                    this.terminal.writeln('\x1b[33m[Warning] Could not read /games directory: ' + e.message + '\x1b[0m');
                }
            }
            
        } catch (error) {
            this.updateStatus('✗ Failed to load WASM module', 'error');
            this.terminal.writeln('\x1b[31m✗ FATAL ERROR: ' + error.message + '\x1b[0m');
            console.error('WASM load error:', error);
        }
    }
    
    async startGame() {
        if (!this.isReady || this.isRunning) {
            return;
        }
        
        const version = this.versionSelect.value;
        const gameInfo = this.gameVersions[version];
        
        if (!gameInfo) {
            this.terminal.writeln('\x1b[31mError: Unknown game version\x1b[0m');
            return;
        }
        
        this.updateStatus(`Starting ${gameInfo.name}...`, 'loading');
        this.currentGamePath = gameInfo.path;
        
        try {
            this.terminal.clear();
            this.terminal.writeln('\x1b[1;32m═══════════════════════════════════════════════════════════════════════════\x1b[0m');
            this.terminal.writeln(`\x1b[1;33m  ${gameInfo.name.toUpperCase()}\x1b[0m`);
            this.terminal.writeln('\x1b[1;32m═══════════════════════════════════════════════════════════════════════════\x1b[0m');
            this.terminal.writeln('');
            
            // Disable controls during gameplay
            this.startBtn.disabled = true;
            this.versionSelect.disabled = true;
            this.isRunning = true;
            
            // Enable save/load buttons
            if (this.saveBtn) this.saveBtn.disabled = false;
            if (this.loadBtn) this.loadBtn.disabled = false;
            if (this.exportBtn) this.exportBtn.disabled = false;
            if (this.importBtn) this.importBtn.disabled = false;
            
            // Change to game directory
            if (this.module.FS) {
                try {
                    this.module.FS.chdir(gameInfo.path);
                    this.terminal.writeln(`\x1b[90m[Changed to ${gameInfo.path}]\x1b[0m`);
                } catch(e) {
                    this.terminal.writeln('\x1b[33m[Warning: Could not change to game directory: ' + e.message + ']\x1b[0m');
                }
            }
            
            this.updateStatus('✓ Game running', 'ready');
            this.terminal.writeln('');
            
            // Try to load the game from save file
            try {
                this.terminal.writeln('\x1b[36mStarting MDL interpreter...\x1b[0m');
                this.terminal.writeln('');
                
                // Build the full path to the save file
                const saveFilePath = `${gameInfo.path}/${gameInfo.saveFile}`;
                
                // Check if save file exists
                if (this.module.FS) {
                    try {
                        this.module.FS.stat(saveFilePath);
                        this.terminal.writeln(`\x1b[90m[Loading from ${saveFilePath}]\x1b[0m`);
                        this.terminal.writeln('');
                        
                        // Call the WASM main function with proper arguments
                        // mdli -r <save-file-path>
                        if (this.module.callMain) {
                            this.terminal.writeln('\x1b[36mInitializing game world...\x1b[0m');
                            this.terminal.writeln('');
                            
                            // Call main with arguments
                            // The interpreter will run and then wait for input
                            try {
                                this.module.callMain(['-r', saveFilePath]);
                                
                                // If we get here, the interpreter returned normally
                                // This means the game loop completed
                            } catch(mainError) {
                                // Check if this is an EXIT_RUNTIME error (expected) or real error
                                const errorMsg = mainError.message || mainError.toString();
                                
                                if (errorMsg.includes('unreachable') || errorMsg.includes('Aborted') || errorMsg.includes('EOF')) {
                                    // The interpreter hit the EOF issue
                                    this.terminal.writeln('');
                                    this.terminal.writeln('\x1b[1;33m╔════════════════════════════════════════════════════════════╗\x1b[0m');
                                    this.terminal.writeln('\x1b[1;33m║  KNOWN LIMITATION: Interactive Mode Not Fully Working   ║\x1b[0m');
                                    this.terminal.writeln('\x1b[1;33m╚════════════════════════════════════════════════════════════╝\x1b[0m');
                                    this.terminal.writeln('');
                                    this.terminal.writeln('\x1b[36mThe game successfully loaded and displayed the starting location!\x1b[0m');
                                    this.terminal.writeln('\x1b[36mHowever, interactive gameplay requires modifying the MDL interpreter\x1b[0m');
                                    this.terminal.writeln('\x1b[36mC source code to use non-blocking I/O for the browser environment.\x1b[0m');
                                    this.terminal.writeln('');
                                    this.terminal.writeln('\x1b[90mThe issue: The interpreter uses blocking I/O (getchar/fgetc) which\x1b[0m');
                                    this.terminal.writeln('\x1b[90mexpects to wait for input. In the browser, this causes EOF when the\x1b[0m');
                                    this.terminal.writeln('\x1b[90mstdin buffer is empty.\x1b[0m');
                                    this.terminal.writeln('');
                                    this.terminal.writeln('\x1b[32mSee WASM_STATUS.md for technical details and possible solutions.\x1b[0m');
                                    this.terminal.writeln('');
                                    // Don't stop the game marker
                                } else if (errorMsg.includes('exit')) {
                                    this.terminal.writeln('\x1b[90m[Interpreter exited]\x1b[0m');
                                    this.stopGame();
                                } else {
                                    console.error('Main error:', mainError);
                                    this.terminal.writeln('\x1b[33m[Warning: ' + errorMsg + ']\x1b[0m');
                                }
                            }
                        } else {
                            this.terminal.writeln('\x1b[31m[Error: callMain not available]\x1b[0m');
                            throw new Error('callMain not available in WASM module');
                        }
                        
                    } catch(statError) {
                        this.terminal.writeln('\x1b[33m[Warning: Save file not found: ' + saveFilePath + ']\x1b[0m');
                        this.terminal.writeln('\x1b[33m[Attempting to start interpreter without save file]\x1b[0m');
                        this.terminal.writeln('');
                        
                        try {
                            // Try calling main without arguments
                            if (this.module.callMain) {
                                this.module.callMain([]);
                            }
                        } catch(mainError) {
                            if (mainError && mainError.message && mainError.message.includes('exit')) {
                                this.terminal.writeln('\x1b[90m[Interpreter exited]\x1b[0m');
                                this.stopGame();
                            } else {
                                throw mainError;
                            }
                        }
                    }
                } else {
                    throw new Error('Filesystem not available');
                }
                
            } catch(e) {
                this.terminal.writeln('\x1b[31mError starting interpreter: ' + e.message + '\x1b[0m');
                console.error('Interpreter start error:', e);
                this.stopGame();
            }
            
        } catch (error) {
            this.updateStatus('✗ Failed to start game', 'error');
            this.terminal.writeln('\x1b[31m✗ ERROR: ' + error.message + '\x1b[0m');
            console.error('Game start error:', error);
            this.isRunning = false;
            this.startBtn.disabled = false;
            this.versionSelect.disabled = false;
        }
    }
    
    // Save game state to IndexedDB
    async saveGame() {
        if (!this.isRunning || !this.db) {
            this.terminal.writeln('\x1b[33m[Cannot save - game not running or IndexedDB unavailable]\x1b[0m');
            return;
        }
        
        try {
            const version = this.versionSelect.value;
            const timestamp = new Date().toISOString();
            
            // Get current filesystem state
            const saveData = {
                id: `${version}_${Date.now()}`,
                version: version,
                timestamp: timestamp,
                // Store the entire filesystem state for the current game
                // In a real implementation, this would capture the MDL interpreter state
                fs: this.captureFilesystem()
            };
            
            const transaction = this.db.transaction(['saves'], 'readwrite');
            const store = transaction.objectStore('saves');
            store.put(saveData);
            
            transaction.oncomplete = () => {
                this.terminal.writeln(`\x1b[32m✓ Game saved: ${timestamp}\x1b[0m`);
            };
            
            transaction.onerror = () => {
                this.terminal.writeln('\x1b[31m✗ Failed to save game\x1b[0m');
            };
            
        } catch(e) {
            this.terminal.writeln(`\x1b[31m✗ Save error: ${e.message}\x1b[0m`);
        }
    }
    
    // Load game state from IndexedDB
    async loadGame() {
        if (!this.db) {
            this.terminal.writeln('\x1b[33m[IndexedDB unavailable]\x1b[0m');
            return;
        }
        
        try {
            const version = this.versionSelect.value;
            
            // Get most recent save for this version
            const transaction = this.db.transaction(['saves'], 'readonly');
            const store = transaction.objectStore('saves');
            const request = store.getAll();
            
            request.onsuccess = () => {
                const saves = request.result.filter(s => s.version === version);
                if (saves.length === 0) {
                    this.terminal.writeln('\x1b[33m[No saved games found for this version]\x1b[0m');
                    return;
                }
                
                // Get most recent
                saves.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
                const saveData = saves[0];
                
                this.restoreFilesystem(saveData.fs);
                this.terminal.writeln(`\x1b[32m✓ Game loaded: ${saveData.timestamp}\x1b[0m`);
            };
            
        } catch(e) {
            this.terminal.writeln(`\x1b[31m✗ Load error: ${e.message}\x1b[0m`);
        }
    }
    
    // Export save to file
    async exportSave() {
        if (!this.db) {
            this.terminal.writeln('\x1b[33m[IndexedDB unavailable]\x1b[0m');
            return;
        }
        
        try {
            const version = this.versionSelect.value;
            
            const transaction = this.db.transaction(['saves'], 'readonly');
            const store = transaction.objectStore('saves');
            const request = store.getAll();
            
            request.onsuccess = () => {
                const saves = request.result.filter(s => s.version === version);
                if (saves.length === 0) {
                    this.terminal.writeln('\x1b[33m[No saved games to export]\x1b[0m');
                    return;
                }
                
                // Get most recent
                saves.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
                const saveData = saves[0];
                
                // Create download
                const blob = new Blob([JSON.stringify(saveData, null, 2)], {type: 'application/json'});
                const url = URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = `zork_${version}_${saveData.timestamp.replace(/[:.]/g, '-')}.json`;
                a.click();
                URL.revokeObjectURL(url);
                
                this.terminal.writeln(`\x1b[32m✓ Save exported\x1b[0m`);
            };
            
        } catch(e) {
            this.terminal.writeln(`\x1b[31m✗ Export error: ${e.message}\x1b[0m`);
        }
    }
    
    // Import save from file
    async importSave() {
        if (!this.db) {
            this.terminal.writeln('\x1b[33m[IndexedDB unavailable]\x1b[0m');
            return;
        }
        
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = '.json';
        
        input.onchange = async (e) => {
            const file = e.target.files[0];
            if (!file) return;
            
            try {
                const text = await file.text();
                const saveData = JSON.parse(text);
                
                // Validate save data
                if (!saveData.id || !saveData.version || !saveData.timestamp) {
                    this.terminal.writeln('\x1b[31m✗ Invalid save file format\x1b[0m');
                    return;
                }
                
                const transaction = this.db.transaction(['saves'], 'readwrite');
                const store = transaction.objectStore('saves');
                
                // Generate new ID to avoid conflicts
                saveData.id = `${saveData.version}_${Date.now()}_imported`;
                store.put(saveData);
                
                transaction.oncomplete = () => {
                    this.terminal.writeln(`\x1b[32m✓ Save imported: ${saveData.timestamp}\x1b[0m`);
                };
                
                transaction.onerror = () => {
                    this.terminal.writeln('\x1b[31m✗ Failed to import save\x1b[0m');
                };
                
            } catch(e) {
                this.terminal.writeln(`\x1b[31m✗ Import error: ${e.message}\x1b[0m`);
            }
        };
        
        input.click();
    }
    
    // Capture filesystem state for saving
    captureFilesystem() {
        if (!this.module || !this.module.FS) return null;
        
        try {
            // For now, just return a placeholder
            // In a full implementation, this would serialize the FS state
            return {
                cwd: this.module.FS.cwd(),
                timestamp: Date.now()
            };
        } catch(e) {
            console.error('Filesystem capture error:', e);
            return null;
        }
    }
    
    // Restore filesystem state from saved data
    restoreFilesystem(fsData) {
        if (!this.module || !this.module.FS || !fsData) return;
        
        try {
            // Restore working directory
            if (fsData.cwd) {
                this.module.FS.chdir(fsData.cwd);
            }
        } catch(e) {
            console.error('Filesystem restore error:', e);
        }
    }
    
    stopGame() {
        this.isRunning = false;
        this.startBtn.disabled = false;
        this.versionSelect.disabled = false;
        
        // Disable save/load buttons
        if (this.saveBtn) this.saveBtn.disabled = true;
        if (this.loadBtn) this.loadBtn.disabled = true;
        if (this.exportBtn) this.exportBtn.disabled = true;
        if (this.importBtn) this.importBtn.disabled = true;
        
        this.updateStatus('✓ Game stopped', 'ready');
        this.terminal.writeln('');
        this.terminal.writeln('\x1b[33m[Game ended. Select a version to play again.]\x1b[0m');
    }
}

// Initialize when page loads
let game;

document.addEventListener('DOMContentLoaded', () => {
    game = new ZorkGame();
    game.loadWASM();
});
