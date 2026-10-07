@echo off
rem Build the development disk (build\elite.dsk). Needs lwasm, ToolShed decb and Python.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File mk.ps1 %*
