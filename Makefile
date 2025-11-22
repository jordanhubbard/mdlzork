# Top-level Makefile for MDL Zork Web Launcher
.PHONY: all clean clean-all venv deps interpreter run build run-native build-native run-native-server wasm-deps wasm-build wasm-serve wasm-all package package-native package-wasm clean-releases help mdlzork_771212 mdlzork_780124 mdlzork_791211 mdlzork_810722

# Python virtual environment
VENV := venv
PYTHON := $(VENV)/bin/python
PIP := $(VENV)/bin/pip
SERVER_PORT := 5001

# Interpreter paths
CONFUSION_DIR := confusion-mdl
CONFUSION_INTERPRETER := $(CONFUSION_DIR)/mdli

# WASM paths
EMSDK_DIR := emsdk
EMSDK_ACTIVATE := $(EMSDK_DIR)/emsdk_env.sh
WASM_BUILD_DIR := wasm-build
WASM_INTERPRETER := $(CONFUSION_DIR)/mdli.js

# Default target (backward compatibility)
all: interpreter deps

# ============================================================================
# High-Level Targets (Recommended)
# ============================================================================

# Build browser-ready WASM application (default)
build: build-native
	@echo ""
	@echo "⚠️  Note: WASM build not yet implemented"
	@echo "✅ Native interpreter built instead"
	@echo ""
	@echo "To run: make run-native"

# Run application (defaults to native server for now)
run: run-native-server

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
			../confusion-mdl/mdli -r "MDL/MADADV.SAVE"; \
		elif [ -f "MTRZORK/ZORK.SAVE" ]; then \
			../confusion-mdl/mdli -r "MTRZORK/ZORK.SAVE"; \
		else \
			echo "Error: No save file found. Tried SAVEFILE directory, MDL/MADADV.SAVE, MTRZORK/ZORK.SAVE"; \
			exit 1; \
		fi; \
	fi


# Run native web server version (requires Python deps)
run-native-server: interpreter deps
	@echo "Starting Zork Web Launcher on port $(SERVER_PORT)..."
	@echo "Visit http://localhost:$(SERVER_PORT) in your browser"
	$(PYTHON) zork_launcher.py

# WASM build target - builds browser-ready application
wasm-all:
	@echo ""
	@echo "⚠️  WASM build not yet implemented"
	@echo ""
	@echo "The WASM build infrastructure (Makefile.wasm, gc_stub.h, etc.)"
	@echo "needs to be created in the confusion-mdl directory."
	@echo ""
	@echo "For now, use native builds:"
	@echo "  make build-native       # Build native interpreter"
	@echo "  make run-native         # Run CLI version"
	@echo "  make run-native-server  # Run web server version"
	@echo ""
	@exit 1

# Set up Python virtual environment
$(VENV)/bin/activate:
	python3 -m venv $(VENV)

venv: $(VENV)/bin/activate

# Install Python dependencies
deps: venv
	$(PIP) install -r requirements.txt

# Build the MDL interpreter
interpreter: $(CONFUSION_INTERPRETER)

$(CONFUSION_INTERPRETER):
	@echo "Building MDL interpreter..."
	@if [ ! -f /opt/homebrew/lib/libgc.dylib ]; then \
		echo "Installing Boehm GC via Homebrew..."; \
		brew install bdw-gc; \
	fi
	@# Patch Makefile to use pkg-config for GC
	@if ! grep -q "pkg-config" $(CONFUSION_DIR)/Makefile; then \
		echo "Patching confusion-mdl Makefile for pkg-config support..."; \
		sed -i.bak 's|^LIBS = -lgc -lgccpp|GC_CFLAGS := $$(shell pkg-config --cflags bdw-gc 2>/dev/null \|\| echo "-I/opt/homebrew/include")\nGC_LIBS := $$(shell pkg-config --libs bdw-gc 2>/dev/null \|\| echo "-L/opt/homebrew/lib -lgc")\nLIBS = $$(GC_LIBS) -lgccpp|' $(CONFUSION_DIR)/Makefile; \
		sed -i.bak 's|^CFLAGS = \(.*\)|CFLAGS = \1 $$(GC_CFLAGS)|' $(CONFUSION_DIR)/Makefile; \
		sed -i.bak 's|^CXXFLAGS = \(.*\)|CXXFLAGS = \1 $$(GC_CFLAGS)|' $(CONFUSION_DIR)/Makefile; \
	fi
	$(MAKE) -C $(CONFUSION_DIR)

# Run the web server (legacy - use run-native for explicit native server)
# Note: 'run' now defaults to WASM version - use 'run-native' for server version

# Clean Python-related files
clean:
	rm -rf $(VENV)
	find . -type d -name "__pycache__" -not -path "./emsdk/*" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -not -path "./emsdk/*" -delete 2>/dev/null || true
	find . -type f -name "*.pyo" -not -path "./emsdk/*" -delete 2>/dev/null || true
	find . -type f -name "*.pyd" -not -path "./emsdk/*" -delete 2>/dev/null || true
	find . -type f -name ".DS_Store" -not -path "./emsdk/*" -delete 2>/dev/null || true
	find . -type d -name "*.egg-info" -not -path "./emsdk/*" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.egg" -not -path "./emsdk/*" -delete 2>/dev/null || true
	find . -type f -name "*.log" -not -path "./emsdk/*" -delete 2>/dev/null || true

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



# Build WASM version (not yet implemented)
wasm-build:
	@echo "⚠️  WASM build not implemented yet"
	@echo ""
	@echo "To implement WASM support, you need to:"
	@echo "  1. Create confusion-mdl/Makefile.wasm with Emscripten build rules"
	@echo "  2. Create confusion-mdl/gc_stub.h to replace Boehm GC"
	@echo "  3. Configure Emscripten flags for browser compatibility"
	@echo ""
	@echo "The wrapper script (scripts/with-emsdk.sh) is ready to use when you create Makefile.wasm"
	@echo ""
	@exit 1

# Serve WASM build for testing
wasm-serve:
	@echo "⚠️  WASM build not implemented yet"
	@echo ""
	@echo "Use native server instead:"
	@echo "  make run-native-server"
	@echo ""
	@exit 1

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
