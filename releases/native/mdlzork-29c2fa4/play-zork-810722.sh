#!/bin/bash
cd mdlzork_810722/patched_confusion
../mdli -r SAVEFILE/ZORK.SAVE 2>/dev/null || ../mdli -r MDL/MADADV.SAVE 2>/dev/null || ../mdli
