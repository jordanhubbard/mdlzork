#!/usr/bin/env python3

import os
import sys
import subprocess
from pathlib import Path
from flask import Flask, render_template, request, jsonify
from flask_socketio import SocketIO, emit
import pty
import select
import termios
import struct
import fcntl
import threading

app = Flask(__name__)
socketio = SocketIO(app)

VERSIONS = {
    "Zork 1977-12-12 (500 points)": "mdlzork_771212/patched_confusion",
    "Zork 1978-01-24 (with end-game)": "mdlzork_780124/patched_confusion",
    "Zork 1979-12-11 (616 points)": "mdlzork_791211/patched_confusion",
    "Zork 1981-07-22 (Final MDL)": "mdlzork_810722/patched_confusion",
    "Dungeon 3.2b (Fortran)": "dungeon_3_2b"
}

active_game = None

def read_from_fd(fd):
    try:
        data = os.read(fd, 1024).decode()
        return data
    except (OSError, UnicodeDecodeError):
        return ""

@app.route('/')
def index():
    return render_template('index.html', versions=VERSIONS.keys())

@socketio.on('connect')
def handle_connect():
    emit('status', {'data': 'Connected'})

@socketio.on('disconnect')
def handle_disconnect():
    global active_game
    if active_game:
        try:
            os.kill(active_game['pid'], 9)
        except:
            pass
        active_game = None

@socketio.on('input')
def handle_input(data):
    global active_game
    if active_game and 'fd' in active_game:
        os.write(active_game['fd'], (data['input'] + '\n').encode())

@socketio.on('start_game')
def start_game(data):
    global active_game
    
    if active_game:
        try:
            os.kill(active_game['pid'], 9)
        except:
            pass
        active_game = None

    version = data.get('version')
    if version not in VERSIONS:
        emit('error', {'data': 'Invalid version selected'})
        return

    version_path = VERSIONS[version]
    base_dir = Path(__file__).parent
    game_dir = base_dir / version_path

    master_fd, slave_fd = pty.openpty()
    
    # Set terminal size
    term_size = struct.pack('HHHH', 24, 80, 0, 0)
    fcntl.ioctl(slave_fd, termios.TIOCSWINSZ, term_size)

    if "dungeon" in version_path.lower():
        dungeon_path = game_dir / "src" / "dungeon"
        if not dungeon_path.exists():
            emit('error', {'data': 'Dungeon executable not found. Please compile the Fortran version first:\n\n'
                                 '1. cd dungeon_3_2b/src\n'
                                 '2. make'})
            return
        cmd = [str(dungeon_path)]
        cwd = str(game_dir)
    else:
        confusion_path = base_dir / "confusion_patched" / "mdli"
        if not confusion_path.exists():
            emit('error', {'data': 'MDL interpreter (confusion) not found. To build it:\n\n'
                                 '1. cd confusion_patched\n'
                                 '2. make\n\n'
                                 'If you encounter build errors, you may need to:\n'
                                 '1. Install development tools (Xcode command line tools)\n'
                                 '2. Install required libraries (e.g., libgc)\n'
                                 'Please check the README or build instructions for more details.'})
            return
        cmd = [str(confusion_path), "-r", "SAVEFILE/ZORK.SAVE"]
        cwd = str(game_dir)

    pid = os.fork()
    if pid == 0:  # Child process
        os.close(master_fd)
        os.dup2(slave_fd, 0)
        os.dup2(slave_fd, 1)
        os.dup2(slave_fd, 2)
        os.chdir(cwd)
        os.execv(cmd[0], cmd)
    else:  # Parent process
        os.close(slave_fd)
        active_game = {'pid': pid, 'fd': master_fd}
        
        def read_output():
            while True:
                r, _, _ = select.select([master_fd], [], [], 0.1)
                if master_fd in r:
                    data = read_from_fd(master_fd)
                    if data:
                        socketio.emit('output', {'data': data})
                    else:
                        break

        thread = threading.Thread(target=read_output)
        thread.daemon = True
        thread.start()

if __name__ == "__main__":
    socketio.run(app, debug=True)
