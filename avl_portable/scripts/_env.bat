@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "PROJECT_ROOT=%%~fI"
for %%I in ("%SCRIPT_DIR%..") do set "PROJECT_ROOT_SHORT=%%~sI"

if "%PYTHON_EXE%"=="" if exist "C:\ProgramData\Miniconda3\envs\vsppytools\python.exe" set "PYTHON_EXE=C:\ProgramData\Miniconda3\envs\vsppytools\python.exe"
if "%PYTHON_EXE%"=="" if exist "C:\ProgramData\Miniconda3\python.exe" set "PYTHON_EXE=C:\ProgramData\Miniconda3\python.exe"

if "%PYTHON_EXE%"=="" (
  where python >nul 2>nul
  if not errorlevel 1 (
    set "PYTHON_EXE=python"
  )
)

if "%PYTHON_EXE%"=="" (
  where py >nul 2>nul
  if not errorlevel 1 (
    set "PYTHON_EXE=py -3"
  )
)

if "%PYTHON_EXE%"=="" (
  echo [ERROR] Python was not found. Set PYTHON_EXE to a valid python.exe path.
  exit /b 1
)

if "%BALANCE_WORKERS%"=="" set "BALANCE_WORKERS=10"
if "%OPT_CORES%"=="" set "OPT_CORES=10"
if "%AERO_WORKERS%"=="" set "AERO_WORKERS=%OPT_CORES%"
if "%LHS_SAMPLES%"=="" set "LHS_SAMPLES=500"
if "%AERO_TOTAL_SAMPLES%"=="" set "AERO_TOTAL_SAMPLES=100000"
if "%AERO_CASES_PER_BRANCH%"=="" set "AERO_CASES_PER_BRANCH=10000"
if "%AERO_FULL_FRACTION%"=="" set "AERO_FULL_FRACTION=0.70"
if "%BRANCH_N_PER_BRANCH%"=="" set "BRANCH_N_PER_BRANCH=140"
if "%BRANCH_INIT_DIR%"=="" set "BRANCH_INIT_DIR=shared_branch_initial_populations_original12_mtow_np140"
if "%AERO_LHS_PATH%"=="" set "AERO_LHS_PATH=data\aero_lhs_v2.csv"
if "%AERO_LABEL_PATH%"=="" set "AERO_LABEL_PATH=data\aero_labeled_v2.csv"
if "%AERO_PREP_DIR%"=="" set "AERO_PREP_DIR=data\prepared_aero_v2"
if "%AERO_MODEL_DIR%"=="" set "AERO_MODEL_DIR=models\aero_mlp_original12_mtow"
if "%MLP_OUTDIR%"=="" set "MLP_OUTDIR=gen_mlp_new20_12branches_original12_mtow_np140"
if "%AVL_OUTDIR%"=="" set "AVL_OUTDIR=gen_avl_new20_12branches_original12_mtow_np140"
if "%TRIM_ALPHA_VALUES%"=="" set "TRIM_ALPHA_VALUES=-5,5"
if "%TRIM_DELTA_VALUES%"=="" set "TRIM_DELTA_VALUES=-5,5"
if "%TRIM_TOL%"=="" set "TRIM_TOL=1e-4"
if "%TRIM_MAX_ITER%"=="" set "TRIM_MAX_ITER=1"
if "%BALANCE_EPOCHS%"=="" set "BALANCE_EPOCHS=200"
if "%AERO_EPOCHS%"=="" set "AERO_EPOCHS=200"
if "%TRAIN_BATCH_SIZE%"=="" set "TRAIN_BATCH_SIZE=256"
if "%BALANCE_ALPHA_SPAN%"=="" set "BALANCE_ALPHA_SPAN=5"
if "%AVL_SRC%"=="" set "AVL_SRC=%PROJECT_ROOT%\avl_optimize_portable\src_avl_full"
if "%AUTO_FULL_ROOT%"=="" set "AUTO_FULL_ROOT=%PROJECT_ROOT_SHORT%\runs"
if "%OMP_NUM_THREADS%"=="" set "OMP_NUM_THREADS=%OPT_CORES%"
if "%OPENBLAS_NUM_THREADS%"=="" set "OPENBLAS_NUM_THREADS=%OPT_CORES%"
if "%MKL_NUM_THREADS%"=="" set "MKL_NUM_THREADS=%OPT_CORES%"
if "%NUMEXPR_NUM_THREADS%"=="" set "NUMEXPR_NUM_THREADS=%OPT_CORES%"
if "%TF_NUM_INTRAOP_THREADS%"=="" set "TF_NUM_INTRAOP_THREADS=%OPT_CORES%"
if "%TF_NUM_INTEROP_THREADS%"=="" set "TF_NUM_INTEROP_THREADS=1"

endlocal & (
  set "PROJECT_ROOT=%PROJECT_ROOT%"
  set "PROJECT_ROOT_SHORT=%PROJECT_ROOT_SHORT%"
  set "PYTHON_EXE=%PYTHON_EXE%"
  set "BALANCE_WORKERS=%BALANCE_WORKERS%"
  set "OPT_CORES=%OPT_CORES%"
  set "AERO_WORKERS=%AERO_WORKERS%"
  set "LHS_SAMPLES=%LHS_SAMPLES%"
  set "AERO_TOTAL_SAMPLES=%AERO_TOTAL_SAMPLES%"
  set "AERO_FULL_FRACTION=%AERO_FULL_FRACTION%"
  set "AERO_CASES_PER_BRANCH=%AERO_CASES_PER_BRANCH%"
  set "BRANCH_N_PER_BRANCH=%BRANCH_N_PER_BRANCH%"
  set "BRANCH_INIT_DIR=%BRANCH_INIT_DIR%"
  set "AERO_LHS_PATH=%AERO_LHS_PATH%"
  set "AERO_LABEL_PATH=%AERO_LABEL_PATH%"
  set "AERO_PREP_DIR=%AERO_PREP_DIR%"
  set "AERO_MODEL_DIR=%AERO_MODEL_DIR%"
  set "MLP_OUTDIR=%MLP_OUTDIR%"
  set "AVL_OUTDIR=%AVL_OUTDIR%"
  set "TRIM_ALPHA_VALUES=%TRIM_ALPHA_VALUES%"
  set "TRIM_DELTA_VALUES=%TRIM_DELTA_VALUES%"
  set "TRIM_TOL=%TRIM_TOL%"
  set "TRIM_MAX_ITER=%TRIM_MAX_ITER%"
  set "BALANCE_EPOCHS=%BALANCE_EPOCHS%"
  set "AERO_EPOCHS=%AERO_EPOCHS%"
  set "TRAIN_BATCH_SIZE=%TRAIN_BATCH_SIZE%"
  set "BALANCE_ALPHA_SPAN=%BALANCE_ALPHA_SPAN%"
  set "AVL_SRC=%AVL_SRC%"
  set "AUTO_FULL_ROOT=%AUTO_FULL_ROOT%"
  set "OMP_NUM_THREADS=%OMP_NUM_THREADS%"
  set "OPENBLAS_NUM_THREADS=%OPENBLAS_NUM_THREADS%"
  set "MKL_NUM_THREADS=%MKL_NUM_THREADS%"
  set "NUMEXPR_NUM_THREADS=%NUMEXPR_NUM_THREADS%"
  set "TF_NUM_INTRAOP_THREADS=%TF_NUM_INTRAOP_THREADS%"
  set "TF_NUM_INTEROP_THREADS=%TF_NUM_INTEROP_THREADS%"
)
exit /b 0
