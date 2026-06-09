@echo off
call "%~dp0_env.bat"
if errorlevel 1 goto :err
cd /d "%PROJECT_ROOT%"

if not exist "avl_optimize_portable\src_avl_full\avl.exe" (
  echo [ERROR] Missing avl_optimize_portable\src_avl_full\avl.exe
  exit /b 1
)

echo [1/3] avl.exe present
echo [2/3] python = %PYTHON_EXE%
echo [3/3] project root = %PROJECT_ROOT%
call avl_optimize_portable\scripts\smoke_avl_exe.bat
if errorlevel 1 goto :err

echo BUNDLE OK.
exit /b 0

:err
echo BUNDLE CHECK FAILED.
exit /b 1
