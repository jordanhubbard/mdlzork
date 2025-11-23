/**
 * MDL Zork - WebAssembly Interface
 * Handles WASM module loading and game interaction
 */

class ZorkGame {
    constructor() {
        this.module = null;
        this.terminalEl = document.getElementById('terminal');
        this.inputEl = document.getElementById('command-input');
        this.statusEl = document.getElementById('status');
        this.sendBtn = document.getElementById('send-btn');
        this.startBtn = document.getElementById('start-btn');
        this.versionSelect = document.getElementById('version-select');
        
        this.isReady = false;
        this.isRunning = false;
        
        this.setupEventListeners();
    }
    
    setupEventListeners() {
        // Send button
        this.sendBtn.addEventListener('click', () => this.sendCommand());
        
        // Enter key to send
        this.inputEl.addEventListener('keypress', (e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                this.sendCommand();
            }
        });
        
        // Start game button
        this.startBtn.addEventListener('click', () => this.startGame());
    }
    
    updateStatus(message, type = 'info') {
        this.statusEl.textContent = message;
        this.statusEl.className = type;
    }
    
    print(text) {
        this.terminalEl.textContent += text;
        this.terminalEl.scrollTop = this.terminalEl.scrollHeight;
    }
    
    println(text) {
        this.print(text + '\n');
    }
    
    clearTerminal() {
        this.terminalEl.textContent = '';
    }
    
    async loadWASM() {
        this.updateStatus('Loading WASM module... ⏳', 'loading');
        
        try {
            this.module = await createMDLI({
                print: (text) => this.print(text),
                printErr: (text) => {
                    this.print('[ERROR] ' + text + '\n');
                },
                onRuntimeInitialized: () => {
                    this.println('[System] WASM runtime initialized');
                }
            });
            
            this.isReady = true;
            this.updateStatus('✓ Ready to start game', 'ready');
            this.startBtn.disabled = false;
            this.versionSelect.disabled = false;
            
            this.println('[System] MDL Zork WASM Module loaded successfully!');
            this.println('[System] Select a game version and click Start Game.');
            this.println('');
            
            // Log available game files
            if (this.module.FS) {
                try {
                    const files = this.module.FS.readdir('/game');
                    this.println('[System] Available files: ' + files.filter(f => f !== '.' && f !== '..').join(', '));
                    this.println('');
                } catch(e) {
                    console.error('Error reading game directory:', e);
                }
            }
            
        } catch (error) {
            this.updateStatus('✗ Failed to load WASM module', 'error');
            this.println('[FATAL ERROR] ' + error.message);
            console.error('WASM load error:', error);
        }
    }
    
    async startGame() {
        if (!this.isReady || this.isRunning) {
            return;
        }
        
        const version = this.versionSelect.value;
        this.updateStatus(`Starting ${version}...`, 'loading');
        this.clearTerminal();
        
        try {
            // Enable input
            this.inputEl.disabled = false;
            this.sendBtn.disabled = false;
            this.startBtn.disabled = true;
            this.versionSelect.disabled = true;
            this.isRunning = true;
            
            this.println('='.repeat(60));
            this.println(`  MDL ZORK - ${version.toUpperCase()}`);
            this.println('='.repeat(60));
            this.println('');
            
            // Change to game directory
            if (this.module.FS) {
                try {
                    this.module.FS.chdir('/game');
                    this.println('[System] Changed to game directory');
                } catch(e) {
                    this.println('[Warning] Could not change to game directory: ' + e.message);
                }
            }
            
            // Call main function
            // Note: The actual game execution will need proper TTY setup
            // For now, we're just setting up the environment
            this.updateStatus('✓ Game running', 'ready');
            this.println('[System] Game initialized. Type commands below:');
            this.println('');
            
            // Focus input
            this.inputEl.focus();
            
        } catch (error) {
            this.updateStatus('✗ Failed to start game', 'error');
            this.println('[ERROR] ' + error.message);
            console.error('Game start error:', error);
            this.isRunning = false;
            this.startBtn.disabled = false;
            this.versionSelect.disabled = false;
        }
    }
    
    sendCommand() {
        if (!this.isRunning) {
            return;
        }
        
        const command = this.inputEl.value.trim();
        if (!command) {
            return;
        }
        
        // Echo command
        this.println('> ' + command);
        
        // Clear input
        this.inputEl.value = '';
        
        // TODO: Send command to WASM stdin
        // For now, just echo back
        this.println('[Echo] You entered: ' + command);
        
        // Handle quit
        if (command.toLowerCase() === 'quit' || command.toLowerCase() === 'q') {
            this.stopGame();
        }
    }
    
    stopGame() {
        this.isRunning = false;
        this.inputEl.disabled = true;
        this.sendBtn.disabled = true;
        this.startBtn.disabled = false;
        this.versionSelect.disabled = false;
        this.updateStatus('✓ Game stopped', 'ready');
        this.println('');
        this.println('[System] Game ended. Select a version to play again.');
    }
}

// Initialize when page loads
let game;

document.addEventListener('DOMContentLoaded', () => {
    game = new ZorkGame();
    game.loadWASM();
});
