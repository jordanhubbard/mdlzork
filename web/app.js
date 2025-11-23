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
        
        this.setupTerminal();
        this.setupEventListeners();
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
        if (!this.module || !this.module.TTY || !this.module.TTY.default) {
            console.error('TTY not available');
            return;
        }
        
        // Send each character to stdin
        for (let i = 0; i < text.length; i++) {
            const charCode = text.charCodeAt(i);
            if (this.module.TTY.default.input) {
                this.module.TTY.default.input.push(charCode);
            }
        }
    }
    
    async loadWASM() {
        this.updateStatus('Loading WASM module... ⏳', 'loading');
        this.terminal.writeln('\x1b[33mLoading MDL interpreter...\x1b[0m');
        
        try {
            // Configure Emscripten module
            const moduleConfig = {
                // Redirect stdout/stderr to terminal
                print: (text) => {
                    this.terminal.write(text + '\r\n');
                },
                printErr: (text) => {
                    this.terminal.write('\x1b[31m[ERROR] ' + text + '\x1b[0m\r\n');
                },
                
                // Set up stdin
                stdin: () => {
                    // This is called by WASM when it needs input
                    // We'll handle this through TTY instead
                    return null;
                },
                
                onRuntimeInitialized: () => {
                    this.terminal.writeln('\x1b[32m✓ WASM runtime initialized\x1b[0m');
                    
                    // Override TTY output to use our terminal
                    if (this.module.TTY && this.module.TTY.default) {
                        const originalPut_char = this.module.TTY.default.put_char;
                        this.module.TTY.default.put_char = (tty, val) => {
                            if (val !== null && val !== undefined) {
                                const char = String.fromCharCode(val);
                                this.terminal.write(char);
                            }
                            if (originalPut_char) {
                                originalPut_char.call(this.module.TTY.default, tty, val);
                            }
                        };
                        
                        // Initialize stdin buffer
                        if (!this.module.TTY.default.input) {
                            this.module.TTY.default.input = [];
                        }
                    }
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
            
            // Log available game files
            if (this.module.FS) {
                try {
                    const files = this.module.FS.readdir('/game');
                    const gameFiles = files.filter(f => f !== '.' && f !== '..');
                    if (gameFiles.length > 0) {
                        this.terminal.writeln('\x1b[90mAvailable game files: ' + gameFiles.join(', ') + '\x1b[0m');
                        this.terminal.writeln('');
                    }
                } catch(e) {
                    console.error('Error reading game directory:', e);
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
        this.updateStatus(`Starting ${version}...`, 'loading');
        
        try {
            this.terminal.clear();
            this.terminal.writeln('\x1b[1;32m═══════════════════════════════════════════════════════════════════════════\x1b[0m');
            this.terminal.writeln(`\x1b[1;33m  ${version.toUpperCase()}\x1b[0m`);
            this.terminal.writeln('\x1b[1;32m═══════════════════════════════════════════════════════════════════════════\x1b[0m');
            this.terminal.writeln('');
            
            // Disable controls during gameplay
            this.startBtn.disabled = true;
            this.versionSelect.disabled = true;
            this.isRunning = true;
            
            // Change to game directory
            if (this.module.FS) {
                try {
                    this.module.FS.chdir('/game');
                    this.terminal.writeln('\x1b[90m[Changed to game directory]\x1b[0m');
                } catch(e) {
                    this.terminal.writeln('\x1b[33m[Warning: Could not change to game directory: ' + e.message + ']\x1b[0m');
                }
            }
            
            this.updateStatus('✓ Game running', 'ready');
            this.terminal.writeln('');
            
            // Call the WASM main function
            // Note: This will block, so we need to handle it properly
            try {
                this.terminal.writeln('\x1b[36mStarting MDL interpreter...\x1b[0m');
                this.terminal.writeln('');
                
                // Call main in a way that doesn't block
                setTimeout(() => {
                    try {
                        if (this.module.callMain) {
                            this.module.callMain([]);
                        }
                    } catch(e) {
                        this.terminal.writeln('\x1b[31mError running game: ' + e.message + '\x1b[0m');
                        console.error('Game execution error:', e);
                    }
                }, 0);
                
            } catch(e) {
                this.terminal.writeln('\x1b[31mError starting interpreter: ' + e.message + '\x1b[0m');
                console.error('Interpreter start error:', e);
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
    
    stopGame() {
        this.isRunning = false;
        this.startBtn.disabled = false;
        this.versionSelect.disabled = false;
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
