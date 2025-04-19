# Top-level Makefile for MDL Zork Web Launcher
.PHONY: all clean clean-all venv deps interpreter run

# Python virtual environment
VENV := venv
PYTHON := $(VENV)/bin/python
PIP := $(VENV)/bin/pip
SERVER_PORT := 5001

# Interpreter paths
CONFUSION_DIR := confusion_patched
CONFUSION_INTERPRETER := $(CONFUSION_DIR)/mdli

all: interpreter deps

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
	$(MAKE) -C $(CONFUSION_DIR)

# Run the web server
run: all
	@echo "Starting Zork Web Launcher on port $(SERVER_PORT)..."
	@echo "Visit http://localhost:$(SERVER_PORT) in your browser"
	$(PYTHON) zork_launcher.py

# Clean Python-related files
clean:
	rm -rf $(VENV)
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.pyo" -delete
	find . -type f -name "*.pyd" -delete
	find . -type f -name ".DS_Store" -delete
	find . -type d -name "*.egg-info" -exec rm -rf {} +
	find . -type f -name "*.egg" -delete
	find . -type f -name "*.log" -delete

# Clean everything including compiled interpreter
clean-all: clean
	$(MAKE) -C $(CONFUSION_DIR) clean
	find . -type f -name "*.o" -delete
	find . -type f -name "*.a" -delete
	find . -type f -name "*.so" -delete
	find . -type f -name "*.dylib" -delete
