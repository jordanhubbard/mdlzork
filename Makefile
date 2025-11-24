# Top-level Makefile for MDL Zork Web Launcher
.PHONY: all clean clean-all venv deps interpreter run build run-native build-native run-native-server wasm-deps wasm-build wasm-serve wasm-all package package-native package-wasm clean-releases help check-submodules check-deps install-deps mdlzork_771212 mdlzork_780124 mdlzork_791211 mdlzork_810722

# Local test server port
SERVER_PORT := 8000

# Interpreter paths
CONFUSION_DIR := confusion-mdl
CONFUSION_INTERPRETER := $(CONFUSION_DIR)/mdli

# ============================================================================
# Submodule Management
# ============================================================================

# Check if submodules are initialized, initialize if necessary
check-submodules:
	@if [ ! -f "$(CONFUSION_DIR)/Makefile" ]; then \
		echo "⚠️  Submodules not initialized. Running 'git submodule update --init --recursive'..."; \
		git submodule update --init --recursive; \
		echo "✅ Submodules initialized"; \
	fi

# Check if required dependencies are installed
check-deps:
	@echo "Checking build dependencies..."
	@MISSING_DEPS=0; \
	if ! command -v gcc >/dev/null 2>&1 && ! command -v clang >/dev/null 2>&1; then \
		echo "❌ C compiler not found (gcc or clang required)"; \
		MISSING_DEPS=1; \
	fi; \
	if ! command -v make >/dev/null 2>&1; then \
		echo "❌ make not found"; \
		MISSING_DEPS=1; \
	fi; \
	GC_FOUND=0; \
	if command -v pkg-config >/dev/null 2>&1; then \
		if pkg-config --exists bdw-gc 2>/dev/null; then \
			GC_FOUND=1; \
		fi; \
	fi; \
	if [ $$GC_FOUND -eq 0 ]; then \
		if [ "$$(uname)" = "Darwin" ]; then \
			if [ -f /opt/homebrew/lib/libgc.dylib ] || [ -f /usr/local/lib/libgc.dylib ]; then \
				GC_FOUND=1; \
			fi; \
		elif [ "$$(uname)" = "Linux" ]; then \
			if [ -f /usr/include/gc/gc.h ] || [ -f /usr/local/include/gc/gc.h ]; then \
				GC_FOUND=1; \
			fi; \
		fi; \
	fi; \
	if [ $$GC_FOUND -eq 0 ]; then \
		echo "❌ Boehm GC library (bdw-gc) not found"; \
		MISSING_DEPS=1; \
	fi; \
	if [ $$MISSING_DEPS -eq 1 ]; then \
		echo ""; \
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
		echo "Missing dependencies detected!"; \
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
		echo ""; \
		echo "Quick install:"; \
		echo "  make install-deps"; \
		echo ""; \
		echo "Or install manually:"; \
		echo ""; \
		if [ "$$(uname)" = "Darwin" ]; then \
			echo "macOS (Homebrew):"; \
			echo "  brew install bdw-gc"; \
		elif [ "$$(uname)" = "Linux" ]; then \
			if command -v apt-get >/dev/null 2>&1; then \
				echo "Debian/Ubuntu:"; \
				echo "  sudo apt-get update"; \
				echo "  sudo apt-get install build-essential libgc-dev"; \
			elif command -v yum >/dev/null 2>&1; then \
				echo "RedHat/CentOS:"; \
				echo "  sudo yum groupinstall 'Development Tools'"; \
				echo "  sudo yum install gc-devel"; \
			elif command -v dnf >/dev/null 2>&1; then \
				echo "Fedora:"; \
				echo "  sudo dnf groupinstall 'Development Tools'"; \
				echo "  sudo dnf install gc-devel"; \
			elif command -v pacman >/dev/null 2>&1; then \
				echo "Arch Linux:"; \
				echo "  sudo pacman -S base-devel gc"; \
			else \
				echo "Linux:"; \
				echo "  Install build-essential/gcc, make, and bdw-gc (Boehm GC) for your distribution"; \
			fi; \
		else \
			echo "Please install: gcc/clang, make, and bdw-gc (Boehm GC)"; \
		fi; \
		echo ""; \
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
		exit 1; \
	fi
	@echo "✅ All build dependencies found"

# Install required dependencies for the current platform
install-deps:
	@echo "Installing build dependencies..."
	@if [ "$$(uname)" = "Darwin" ]; then \
		echo "macOS detected - using Homebrew"; \
		if ! command -v brew >/dev/null 2>&1; then \
			echo "❌ Homebrew not found. Please install from https://brew.sh"; \
			exit 1; \
		fi; \
		echo "Installing bdw-gc..."; \
		brew install bdw-gc; \
		echo "✅ Dependencies installed successfully"; \
	elif [ "$$(uname)" = "Linux" ]; then \
		if command -v apt-get >/dev/null 2>&1; then \
			echo "Debian/Ubuntu detected - using apt-get"; \
			echo "Installing build-essential and libgc-dev..."; \
			sudo apt-get update && sudo apt-get install -y build-essential libgc-dev pkg-config; \
			echo "✅ Dependencies installed successfully"; \
		elif command -v yum >/dev/null 2>&1; then \
			echo "RedHat/CentOS detected - using yum"; \
			echo "Installing Development Tools and gc-devel..."; \
			sudo yum groupinstall -y 'Development Tools' && sudo yum install -y gc-devel; \
			echo "✅ Dependencies installed successfully"; \
		elif command -v dnf >/dev/null 2>&1; then \
			echo "Fedora detected - using dnf"; \
			echo "Installing Development Tools and gc-devel..."; \
			sudo dnf groupinstall -y 'Development Tools' && sudo dnf install -y gc-devel; \
			echo "✅ Dependencies installed successfully"; \
		elif command -v pacman >/dev/null 2>&1; then \
			echo "Arch Linux detected - using pacman"; \
			echo "Installing base-devel and gc..."; \
			sudo pacman -S --noconfirm base-devel gc; \
			echo "✅ Dependencies installed successfully"; \
		else \
			echo "❌ Unknown Linux distribution"; \
			echo "Please manually install: gcc, make, and bdw-gc (Boehm GC)"; \
			exit 1; \
		fi; \
	else \
		echo "❌ Unsupported operating system: $$(uname)"; \
		echo "Please manually install: gcc/clang, make, and bdw-gc (Boehm GC)"; \
		exit 1; \
	fi

# WASM paths
EMSDK_DIR := emsdk
EMSDK_ACTIVATE := $(EMSDK_DIR)/emsdk_env.sh
WASM_BUILD_DIR := wasm-build
WASM_INTERPRETER := $(CONFUSION_DIR)/mdli.js

# Default target - build WASM
all: build

# ============================================================================
# High-Level Targets (Recommended)
# ============================================================================

# Build browser-ready WASM application
build: wasm-build
	@echo ""
	@echo "✅ WASM build complete!"
	@echo ""
	@echo "Files generated:"
	@echo "  - $(CONFUSION_DIR)/mdli.js"
	@echo "  - $(CONFUSION_DIR)/mdli.wasm"  
	@echo "  - $(CONFUSION_DIR)/mdli.data"
	@echo ""
	@echo "To test: make serve-wasm"
	@echo "Then open: http://localhost:8000/index.html"

# Run application (serve WASM in browser)
run: serve-wasm

# Build native interpreter (CLI or server use)
build-native: interpreter
	@echo ""
	@echo "✅ Native interpreter built!"
	@echo ""
	@echo "Usage options:"
	@echo "  CLI: cd mdlzork_810722 && ../confusion-mdl/mdli -r SAVEFILE/ZORK.SAVE"
	@echo "  Server: make run-native-server"

# Run native CLI version (compiled executable)
# Usage: make run-native <game-name> [save-file]
# Example: make run-native mdlzork_810722
# Example: make run-native mdlzork_810722 SAVEFILE/ZORK.SAVE
run-native: interpreter
	@if [ -z "$(filter-out $@,$(MAKECMDGOALS))" ]; then \
		echo ""; \
		echo "Usage: make run-native <game-name> [save-file]"; \
		echo ""; \
		echo "Available games:"; \
		echo "  - mdlzork_771212"; \
		echo "  - mdlzork_780124"; \
		echo "  - mdlzork_791211"; \
		echo "  - mdlzork_810722"; \
		echo ""; \
		echo "Examples:"; \
		echo "  make run-native mdlzork_810722"; \
		echo "  make run-native mdlzork_810722 MDL/MADADV.SAVE"; \
		echo ""; \
		echo "Note: Save file is REQUIRED to bootstrap the game."; \
		echo "  - If SAVEFILE contains exactly one file, it will be auto-selected."; \
		echo "  - If SAVEFILE contains multiple files, you must specify one explicitly."; \
		echo "  - Otherwise, falls back to MDL/MADADV.SAVE or MTRZORK/ZORK.SAVE"; \
		exit 1; \
	fi
	@GAME_NAME=$(word 2,$(MAKECMDGOALS)); \
	SAVE_FILE=$(word 3,$(MAKECMDGOALS)); \
	if [ ! -d "$$GAME_NAME" ]; then \
		echo "Error: Game directory '$$GAME_NAME' not found"; \
		echo "Available games: mdlzork_771212 mdlzork_780124 mdlzork_791211 mdlzork_810722"; \
		exit 1; \
	fi; \
	cd "$$GAME_NAME" && \
	if [ -n "$$SAVE_FILE" ]; then \
		../confusion-mdl/mdli -r "$$SAVE_FILE"; \
	else \
		SAVEFILE_COUNT=0; \
		if [ -d "SAVEFILE" ]; then \
			SAVEFILE_COUNT=$$(ls -1 "SAVEFILE" 2>/dev/null | wc -l | tr -d ' '); \
		fi; \
		if [ "$$SAVEFILE_COUNT" -eq 1 ]; then \
			AUTO_SAVE=$$(ls -1 "SAVEFILE" | head -1); \
			echo "Auto-selecting save file: SAVEFILE/$$AUTO_SAVE"; \
			../confusion-mdl/mdli -r "SAVEFILE/$$AUTO_SAVE"; \
		elif [ "$$SAVEFILE_COUNT" -gt 1 ]; then \
			echo "Error: Multiple save files found in SAVEFILE directory:"; \
			ls -1 "SAVEFILE" | sed 's/^/  - SAVEFILE\//'; \
			echo ""; \
			echo "Please specify which save file to use:"; \
			echo "  make run-native $$GAME_NAME SAVEFILE/<filename>"; \
			exit 1; \
		elif [ -f "MDL/MADADV.SAVE" ]; then \
			echo "Using MDL/MADADV.SAVE (no SAVEFILE directory found)"; \
			../confusion-mdl/mdli -r "MDL/MADADV.SAVE"; \
		elif [ -f "MTRZORK/ZORK.SAVE" ]; then \
			echo "Using MTRZORK/ZORK.SAVE"; \
			../confusion-mdl/mdli -r "MTRZORK/ZORK.SAVE"; \
		else \
			echo "Error: No save file found. Tried SAVEFILE directory, MDL/MADADV.SAVE, MTRZORK/ZORK.SAVE"; \
			exit 1; \
		fi; \
	fi


# Legacy Flask server removed - use WASM version instead
run-native-server:
	@echo "❌ Flask server has been removed"
	@echo ""
	@echo "The Flask-based server is no longer available."
	@echo "Please use the WASM version instead:"
	@echo ""
	@echo "  make run       # Serve WASM version"
	@echo ""
	@exit 1

# Build the MDL interpreter
interpreter: check-submodules check-deps $(CONFUSION_INTERPRETER)

$(CONFUSION_INTERPRETER): check-submodules check-deps
	@echo "Building MDL interpreter..."
	@# Patch Makefile to use pkg-config for GC (Linux/macOS compatibility)
	@if ! grep -q "pkg-config" $(CONFUSION_DIR)/Makefile; then \
		echo "Patching confusion-mdl Makefile for pkg-config support..."; \
		sed -i.bak 's|^LIBS = -lgc -lgccpp|GC_CFLAGS := $$(shell pkg-config --cflags bdw-gc 2>/dev/null \|\| echo "-I/opt/homebrew/include")\nGC_LIBS := $$(shell pkg-config --libs bdw-gc 2>/dev/null \|\| echo "-L/opt/homebrew/lib -lgc")\nLIBS = $$(GC_LIBS) -lgccpp|' $(CONFUSION_DIR)/Makefile; \
		sed -i.bak 's|^CFLAGS = \(.*\)|CFLAGS = \1 $$(GC_CFLAGS)|' $(CONFUSION_DIR)/Makefile; \
		sed -i.bak 's|^CXXFLAGS = \(.*\)|CXXFLAGS = \1 $$(GC_CFLAGS)|' $(CONFUSION_DIR)/Makefile; \
	fi
	$(MAKE) -C $(CONFUSION_DIR)

# Run the web server (legacy - use run-native for explicit native server)
# Note: 'run' now defaults to WASM version - use 'run-native' for server version

# Clean build artifacts and temporary files
clean:
	@echo "Cleaning build artifacts..."
	find . -type f -name ".DS_Store" -not -path "./emsdk/*" -delete 2>/dev/null || true
	find . -type f -name "*.log" -not -path "./emsdk/*" -delete 2>/dev/null || true
	find . -type f -name "*.backup" -not -path "./emsdk/*" -delete 2>/dev/null || true
	find . -type f -name "*.bak" -not -path "./emsdk/*" -delete 2>/dev/null || true
	find . -type f -name "*.wasm.o" -not -path "./emsdk/*" -delete 2>/dev/null || true
	find web -type f -name "*.cpp" -delete 2>/dev/null || true
	find web -type f -name "*.o" -delete 2>/dev/null || true
	$(MAKE) -C $(CONFUSION_DIR) -f Makefile.wasm clean-wasm 2>/dev/null || true
	@echo "✅ Clean complete"

# Clean everything including compiled interpreter
clean-all: clean clean-wasm
	$(MAKE) -C $(CONFUSION_DIR) clean
	find . -type f -name "*.o" -delete
	find . -type f -name "*.a" -delete
	find . -type f -name "*.so" -delete
	find . -type f -name "*.dylib" -delete

# ============================================================================
# WASM Build Targets
# ============================================================================

# Install Emscripten SDK if not present
wasm-deps: $(EMSDK_ACTIVATE)

$(EMSDK_DIR):
	@echo "Installing Emscripten SDK..."
	@echo "This may take 10-15 minutes on first run..."
	git clone https://github.com/emscripten-core/emsdk.git $(EMSDK_DIR)

$(EMSDK_ACTIVATE): $(EMSDK_DIR)
	@echo "Setting up Emscripten SDK..."
	cd $(EMSDK_DIR) && ./emsdk install latest
	cd $(EMSDK_DIR) && ./emsdk activate latest
	@echo "✅ Emscripten SDK installed and activated"
	@echo ""
	@echo "⚠️  IMPORTANT: Run 'source $(EMSDK_ACTIVATE)' in your shell before building"
	@echo "   Or use: eval \$$(make wasm-env)"

# Export Emscripten environment variables
wasm-env:
	@echo "export PATH=\"$$(pwd)/$(EMSDK_DIR)/upstream/emscripten:$$PATH\""
	@echo "export EMSDK=\"$$(pwd)/$(EMSDK_DIR)\""
	@echo "export EM_CONFIG=\"$$(pwd)/$(EMSDK_DIR)/.emscripten\""

# Check if Emscripten is available
check-emscripten:
	@if ! command -v emcc >/dev/null 2>&1; then \
		echo "❌ Emscripten not found in PATH"; \
		echo ""; \
		echo "Please run:"; \
		echo "  source $(EMSDK_ACTIVATE)"; \
		echo ""; \
		echo "Or:"; \
		echo "  eval \$$(make wasm-env)"; \
		exit 1; \
	fi
	@echo "✅ Emscripten found: $$(emcc --version | head -1)"

# Build WASM version
wasm-build: check-submodules wasm-deps
	@echo "Building WASM interpreter..."
	@echo "Sourcing Emscripten environment..."
	@GAME_DIRS=""; \
	for game in mdlzork_771212 mdlzork_780124 mdlzork_791211 mdlzork_810722; do \
		if [ -d "$$game" ]; then \
			GAME_DIRS="$$GAME_DIRS ../$$game"; \
		fi; \
	done; \
	if [ -f $(EMSDK_ACTIVATE) ]; then \
		bash -c 'cd $(EMSDK_DIR) && . ./emsdk_env.sh && cd - > /dev/null && $(MAKE) -C $(CONFUSION_DIR) -f Makefile.wasm GAME_DIRS="'"$$GAME_DIRS"'"'; \
	else \
		echo "❌ Emscripten not installed. Run 'make wasm-deps' first."; \
		exit 1; \
	fi
	@echo "Copying WASM files to build directory..."
	@mkdir -p $(WASM_BUILD_DIR)
	@cp $(CONFUSION_DIR)/mdli.js $(CONFUSION_DIR)/mdli.wasm $(WASM_BUILD_DIR)/ 2>/dev/null || true
	@cp $(CONFUSION_DIR)/test_wasm.html $(WASM_BUILD_DIR)/
	@if [ -f $(CONFUSION_DIR)/mdli.data ]; then \
		cp $(CONFUSION_DIR)/mdli.data $(WASM_BUILD_DIR)/; \
	fi
	@echo "✅ WASM files copied to $(WASM_BUILD_DIR)/"

# Alias for wasm-build
wasm-all: wasm-build

# Serve WASM build for testing
wasm-serve: wasm-build
	@echo ""
	@echo "Starting web server for WASM build..."
	@echo "  📡 Server: http://localhost:8000"
	@echo "  📄 Main UI: http://localhost:8000/web/"
	@echo "  🧪 Test page: http://localhost:8000/web/test-simple.html"
	@echo ""
	@echo "Press Ctrl+C to stop server"
	@echo ""
	python3 -m http.server 8000

# Alias
serve-wasm: wasm-serve

# Clean WASM build artifacts
clean-wasm:
	rm -rf $(WASM_BUILD_DIR)
	$(MAKE) -C $(CONFUSION_DIR) -f Makefile.wasm clean-wasm 2>/dev/null || true
	find $(CONFUSION_DIR) -name "*.wasm.o" -delete 2>/dev/null || true
	find $(CONFUSION_DIR) -name "*.wasm" -delete 2>/dev/null || true
	find $(CONFUSION_DIR) -name "mdli.js" -delete 2>/dev/null || true
	find $(CONFUSION_DIR) -name "mdli.data" -delete 2>/dev/null || true

# ============================================================================
# Release Packaging Targets
# ============================================================================

# Release directory structure
RELEASE_DIR := releases
NATIVE_RELEASE_DIR := $(RELEASE_DIR)/native
WASM_RELEASE_DIR := $(RELEASE_DIR)/wasm
VERSION := $(shell git describe --tags --always 2>/dev/null || echo "dev")

# Package native release (interpreter + game files)
package-native: build-native
	@echo "Packaging native release..."
	@mkdir -p $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)
	@echo "Copying interpreter..."
	@cp $(CONFUSION_INTERPRETER) $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/mdli
	@chmod +x $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/mdli
	@echo "Copying game files..."
	@cp -r mdlzork_771212 $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/ 2>/dev/null || true
	@cp -r mdlzork_780124 $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/ 2>/dev/null || true
	@cp -r mdlzork_791211 $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/ 2>/dev/null || true
	@cp -r mdlzork_810722 $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/ 2>/dev/null || true
	@echo "Creating launcher scripts..."
	@echo '#!/bin/bash' > $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/play-zork-810722.sh
	@echo 'cd mdlzork_810722' >> $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/play-zork-810722.sh
	@echo '../mdli -r SAVEFILE/ZORK.SAVE 2>/dev/null || ../mdli -r MDL/MADADV.SAVE 2>/dev/null || ../mdli' >> $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/play-zork-810722.sh
	@chmod +x $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/play-zork-810722.sh
	@echo "MDL Zork Native Release" > $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "======================" >> $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "" >> $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "This release includes:" >> $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "- MDL interpreter (mdli)" >> $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "- Multiple Zork game versions" >> $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "" >> $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "To play:" >> $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "  cd mdlzork_810722" >> $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "  ../mdli -r SAVEFILE/ZORK.SAVE" >> $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "" >> $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "Or use the launcher script:" >> $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "  ./play-zork-810722.sh" >> $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "" >> $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "Game Versions:" >> $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "- mdlzork_771212: Zork 1977-12-12 (500 points)" >> $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "- mdlzork_780124: Zork 1978-01-24 (with end-game)" >> $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "- mdlzork_791211: Zork 1979-12-11 (616 points)" >> $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "- mdlzork_810722: Zork 1981-07-22 (Final MDL)" >> $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "✅ Native release packaged: $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/"
	@echo ""
	@echo "To create archive:"
	@echo "  cd $(RELEASE_DIR) && tar -czf mdlzork-$(VERSION)-native.tar.gz mdlzork-$(VERSION)/"

# Package WASM release (browser-ready application)
package-wasm: wasm-build
	@echo "Packaging WASM release..."
	@mkdir -p $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)
	@echo "Copying WASM files..."
	@cp $(CONFUSION_DIR)/mdli.js $(CONFUSION_DIR)/mdli.wasm $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/ 2>/dev/null || true
	@if [ -f $(CONFUSION_DIR)/mdli.data ]; then \
		cp $(CONFUSION_DIR)/mdli.data $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/; \
	fi
	@echo "Copying HTML interface..."
	@cp $(CONFUSION_DIR)/test_wasm.html $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/index.html
	@echo "Creating README..."
	@echo "MDL Zork WASM Release (Browser Application)" > $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "==========================================" >> $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "" >> $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "This release runs entirely in your web browser - no server needed!" >> $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "" >> $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "To use:" >> $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "1. Serve these files with any web server:" >> $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "   python3 -m http.server 8000" >> $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "   (or use any static file hosting)" >> $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "" >> $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "2. Open in browser:" >> $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "   http://localhost:8000/index.html" >> $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "" >> $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "Files included:" >> $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "- mdli.js: JavaScript wrapper" >> $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "- mdli.wasm: WebAssembly interpreter" >> $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "- mdli.data: Preloaded game files (if present)" >> $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "- index.html: Web interface" >> $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "" >> $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "Works offline once loaded!" >> $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/README.txt
	@echo "✅ WASM release packaged: $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/"
	@echo ""
	@echo "To create archive:"
	@echo "  cd $(RELEASE_DIR) && tar -czf mdlzork-$(VERSION)-wasm.tar.gz mdlzork-$(VERSION)/"
	@echo ""
	@echo "Or zip:"
	@echo "  cd $(RELEASE_DIR) && zip -r mdlzork-$(VERSION)-wasm.zip mdlzork-$(VERSION)/"

# Package both releases
package: package-native package-wasm
	@echo ""
	@echo "✅ All releases packaged!"
	@echo ""
	@echo "Native release: $(NATIVE_RELEASE_DIR)/mdlzork-$(VERSION)/"
	@echo "WASM release: $(WASM_RELEASE_DIR)/mdlzork-$(VERSION)/"
	@echo ""
	@echo "Create archives:"
	@echo "  cd $(RELEASE_DIR)"
	@echo "  tar -czf mdlzork-$(VERSION)-native.tar.gz mdlzork-$(VERSION)/"
	@echo "  tar -czf mdlzork-$(VERSION)-wasm.tar.gz mdlzork-$(VERSION)/"

# Clean release artifacts
clean-releases:
	rm -rf $(RELEASE_DIR)

# Help target
help:
	@echo "MDL Zork Build System"
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "High-Level Targets (Recommended):"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  make build        - Build browser-ready WASM application (default)"
	@echo "  make run          - Run WASM application in browser"
	@echo ""
	@echo "  make build-native      - Build native interpreter (CLI or server use)"
	@echo "  make run-native        - Run native CLI version (interactive)"
	@echo "  make run-native-server - Run native web launcher server"
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "WASM Build Targets (Browser Application):"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  make wasm-deps    - Install Emscripten SDK (first time only, ~10-15 min)"
	@echo "  make wasm-build    - Build WASM version"
	@echo "  make wasm-all      - Build WASM (alias for wasm-build)"
	@echo "  make wasm-serve    - Build WASM and start test server"
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Native Build Targets (Server Application):"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  make              - Build native interpreter and install Python deps"
	@echo "  make interpreter  - Build native MDL interpreter only"
	@echo "  make deps         - Install Python dependencies"
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Release Packaging Targets:"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  make package-native - Package native release (interpreter + games)"
	@echo "  make package-wasm   - Package WASM release (browser-ready)"
	@echo "  make package        - Package both native and WASM releases"
	@echo "  make clean-releases - Clean release artifacts"
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Clean Targets:"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  make clean        - Clean Python artifacts"
	@echo "  make clean-wasm   - Clean WASM build artifacts"
	@echo "  make clean-all    - Clean everything"
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Quick Start (Browser Application):"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  1. make build          # Builds WASM (installs Emscripten if needed)"
	@echo "  2. make run            # Start test server and open in browser"
	@echo ""
	@echo "Quick Start (Native CLI Application):"
	@echo "  1. make build-native  # Build native interpreter"
	@echo "  2. make run-native    # Run CLI version (interactive)"
	@echo ""
	@echo "Quick Start (Native Server Application):"
	@echo "  1. make build-native      # Build native interpreter"
	@echo "  2. make run-native-server # Start web server on port 5001"
	@echo ""
	@echo "Quick Start (Release Packaging):"
	@echo "  1. make package-native  # Package native release"
	@echo "  2. make package-wasm    # Package WASM release"
	@echo "  3. make package         # Package both"
