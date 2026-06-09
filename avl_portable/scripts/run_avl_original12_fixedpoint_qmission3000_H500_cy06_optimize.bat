@echo off
setlocal
set "NEW20_OBJECTIVE=q_g_per_ton_km"
set "NEW20_MISSION_L_KM=3000"
set "NEW20_MAX_CY=0.6"
set "NEW20_FIXED_H=500"
set "NEW20_FIXEDPOINT=1"
set "NEW20_FP_RELAX=0.5"
set "NEW20_FP_MAX_ITER=10"
set "NEW20_FP_TOL_ABS=1.0"
set "NEW20_FP_TOL_REL=0.001"
set "NEW20_FP_VERBOSE=1"
set "OPT_CORES=10"
set "AVL_OUTDIR=gen_avl_fixedpoint_qmission3000_H500_cy06"
set "BRANCH_INIT_DIR=init_h500"
set "BRANCH_N_PER_BRANCH=140"
set "LOG_FILE=logs\optimize_fixedpoint_avl10.log"
call "%~dp0_env.bat"
if errorlevel 1 goto :err
cd /d "%PROJECT_ROOT%"
if not exist "logs" mkdir "logs"

echo [FIXEDPOINT-AVL] Log: %LOG_FILE%
echo [FIXEDPOINT-AVL] Start > "%LOG_FILE%"
echo PROJECT_ROOT=%PROJECT_ROOT%>> "%LOG_FILE%"
echo OPT_CORES=%OPT_CORES%>> "%LOG_FILE%"
echo NEW20_FP_MAX_ITER=%NEW20_FP_MAX_ITER%>> "%LOG_FILE%"
echo NEW20_FP_RELAX=%NEW20_FP_RELAX%>> "%LOG_FILE%"

if not exist "%BRANCH_INIT_DIR%\manifest.csv" (
  %PYTHON_EXE% src\generate_branch_initial_populations_v2.py --n-per-branch %BRANCH_N_PER_BRANCH% --outdir %BRANCH_INIT_DIR% >> "%LOG_FILE%" 2>&1
  if errorlevel 1 goto :err
)

%PYTHON_EXE% src\run_12branches_new20.py --backend avl --outdir %AVL_OUTDIR% --cores %OPT_CORES% --init-dir %BRANCH_INIT_DIR% --n-per-branch %BRANCH_N_PER_BRANCH% >> "%LOG_FILE%" 2>&1
if errorlevel 1 goto :err

echo DONE.
exit /b 0

:err
echo FAILED at step above. See %LOG_FILE%
exit /b 1
