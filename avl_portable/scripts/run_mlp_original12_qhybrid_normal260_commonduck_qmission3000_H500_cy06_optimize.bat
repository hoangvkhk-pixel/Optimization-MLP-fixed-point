@echo off
setlocal
set "NEW20_OBJECTIVE=q_g_per_ton_km"
set "NEW20_MISSION_L_KM=3000"
set "NEW20_MAX_CY=0.6"
set "NEW20_FIXED_H=500"
set "NEW20_USE_DIRECT_K=1"
set "AERO_MODEL_DIR_NORMAL=models\aero_mlp_original12_normal_qkhead_260k"
set "AERO_MODEL_DIR_DUCK=models\aero_mlp_original12_common_qkhead_260k"
set "MLP_OUTDIR=gen_qhybrid_normal260_commonduck_cy06"
set "BRANCH_INIT_DIR=init_h500"
set "BRANCH_N_PER_BRANCH=140"
call "%~dp0_env.bat"
if errorlevel 1 goto :err
cd /d "%PROJECT_ROOT%"

if not exist "%BRANCH_INIT_DIR%\manifest.csv" (
  %PYTHON_EXE% src\generate_branch_initial_populations_v2.py --n-per-branch %BRANCH_N_PER_BRANCH% --outdir %BRANCH_INIT_DIR%
  if errorlevel 1 goto :err
)

echo [Q-HYBRID-260-OPT] normal branches use normal260k; duck branches use common260k
set "NEW20_MODEL_DIR_NORMAL=%AERO_MODEL_DIR_NORMAL%"
set "NEW20_MODEL_DIR_DUCK=%AERO_MODEL_DIR_DUCK%"
%PYTHON_EXE% src\run_12branches_new20.py --backend mlp --outdir %MLP_OUTDIR% --model-dir %AERO_MODEL_DIR_NORMAL% --cores %OPT_CORES% --init-dir %BRANCH_INIT_DIR% --n-per-branch %BRANCH_N_PER_BRANCH%
if errorlevel 1 goto :err

echo DONE.
exit /b 0

:err
echo FAILED at step above.
exit /b 1
