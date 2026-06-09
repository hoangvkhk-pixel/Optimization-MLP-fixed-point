@echo off
setlocal
set "NEW20_OBJECTIVE=q_g_per_ton_km"
set "NEW20_MISSION_L_KM=3000"
set "NEW20_MAX_CY=0.6"
set "NEW20_FIXED_H=500"
set "NEW20_USE_DIRECT_K=1"
set "AERO_260K_RAW_LABEL=data\aero_labeled_v2_plus_targeted_q5k_plus_cx20k_plus_split30k_plus_targeted30k.csv"
set "AERO_260K_KHEAD_LABEL=data\aero_labeled_v2_260k_khead.csv"
set "AERO_HARD40K_LHS=data\aero_lhs_targeted_hard40k_v2.csv"
set "AERO_HARD40K_LABEL=data\aero_labeled_targeted_hard40k_v2.csv"
set "AERO_300K_KHEAD_LABEL=data\aero_labeled_v2_300k_hard40k_khead.csv"
set "AERO_NORMAL_LABEL=data\aero_labeled_v2_normal_300k_hard40k_khead.csv"
set "AERO_DUCK_LABEL=data\aero_labeled_v2_duck_300k_hard40k_khead.csv"
set "AERO_COMMON_PREP=data\prepared_aero_v2_common_300k_hard40k_khead"
set "AERO_NORMAL_PREP=data\prepared_aero_v2_normal_300k_hard40k_khead"
set "AERO_DUCK_PREP=data\prepared_aero_v2_duck_300k_hard40k_khead"
set "AERO_MODEL_DIR_COMMON=models\aero_mlp_original12_common_qkhead_300k_hard40k"
set "AERO_MODEL_DIR_NORMAL=models\aero_mlp_original12_normal_qkhead_300k_hard40k"
set "AERO_MODEL_DIR_DUCK=models\aero_mlp_original12_duck_qkhead_300k_hard40k"
set "MLP_OUTDIR=gen_qkhead_split_300k_hard40k_cy06"
set "BRANCH_INIT_DIR=init_h500"
set "BRANCH_N_PER_BRANCH=140"
set "AERO_EPOCHS=400"
set "TRAIN_BATCH_SIZE=256"
call "%~dp0_env.bat"
if errorlevel 1 goto :err
cd /d "%PROJECT_ROOT%"

if not exist "%AERO_260K_KHEAD_LABEL%" (
  echo [HARD40K-0/8] Build missing 260k K-head base
  if not exist "%AERO_260K_RAW_LABEL%" (
    %PYTHON_EXE% src\merge_aero_labeled_v2.py --base data\aero_labeled_v2_plus_targeted_q5k_plus_cx20k_plus_split30k.csv --extra data\aero_labeled_targeted_split30k_v2.csv --out %AERO_260K_RAW_LABEL%
    if errorlevel 1 goto :err
  )
  %PYTHON_EXE% src\make_khead_aero_labels_v2.py --input %AERO_260K_RAW_LABEL% --out %AERO_260K_KHEAD_LABEL%
  if errorlevel 1 goto :err
)

echo [HARD40K-1/8] Generate hard 40k aero cases
%PYTHON_EXE% src\generate_aero_lhs_targeted_hard40k_v2.py --out %AERO_HARD40K_LHS%
if errorlevel 1 goto :err

echo [HARD40K-2/8] Label hard 40k aero cases with AVL
%PYTHON_EXE% src\label_aero_avl_v2.py --infile %AERO_HARD40K_LHS% --out %AERO_HARD40K_LABEL% --workers %AERO_WORKERS%
if errorlevel 1 goto :err

echo [HARD40K-3/8] Merge 260k K-head base with hard 40k
%PYTHON_EXE% src\merge_aero_labeled_v2.py --base %AERO_260K_KHEAD_LABEL% --extra %AERO_HARD40K_LABEL% --out %AERO_300K_KHEAD_LABEL%
if errorlevel 1 goto :err

echo [HARD40K-4/8] Split 300k hard dataset into normal and duck
%PYTHON_EXE% src\split_aero_labeled_normal_duck_v2.py --input %AERO_300K_KHEAD_LABEL% --normal-out %AERO_NORMAL_LABEL% --duck-out %AERO_DUCK_LABEL%
if errorlevel 1 goto :err

echo [HARD40K-5/8] Prepare common, normal, duck train arrays
%PYTHON_EXE% src\prepare_aero_trainset_v2.py --input %AERO_300K_KHEAD_LABEL% --outdir %AERO_COMMON_PREP%
if errorlevel 1 goto :err
%PYTHON_EXE% src\prepare_aero_trainset_v2.py --input %AERO_NORMAL_LABEL% --outdir %AERO_NORMAL_PREP%
if errorlevel 1 goto :err
%PYTHON_EXE% src\prepare_aero_trainset_v2.py --input %AERO_DUCK_LABEL% --outdir %AERO_DUCK_PREP%
if errorlevel 1 goto :err

echo [HARD40K-6/8] Train common, normal, duck K-head models
%PYTHON_EXE% src\train_aero_mlp_v2.py --data-dir %AERO_COMMON_PREP% --outdir %AERO_MODEL_DIR_COMMON% --epochs %AERO_EPOCHS% --batch-size %TRAIN_BATCH_SIZE% --cx-weight 3.0 --k-weight 2.5 --early-stop-patience 50 --lr-patience 15 --promote-variant best_combo
if errorlevel 1 goto :err
%PYTHON_EXE% src\train_aero_mlp_v2.py --data-dir %AERO_NORMAL_PREP% --outdir %AERO_MODEL_DIR_NORMAL% --epochs %AERO_EPOCHS% --batch-size %TRAIN_BATCH_SIZE% --cx-weight 3.0 --k-weight 2.0 --early-stop-patience 50 --lr-patience 15 --promote-variant best_combo
if errorlevel 1 goto :err
%PYTHON_EXE% src\train_aero_mlp_v2.py --data-dir %AERO_DUCK_PREP% --outdir %AERO_MODEL_DIR_DUCK% --epochs %AERO_EPOCHS% --batch-size %TRAIN_BATCH_SIZE% --cx-weight 4.0 --k-weight 3.0 --early-stop-patience 50 --lr-patience 15 --promote-variant best_combo
if errorlevel 1 goto :err

echo [HARD40K-7/8] Ensure shared initial population exists
if not exist "%BRANCH_INIT_DIR%\manifest.csv" (
  %PYTHON_EXE% src\generate_branch_initial_populations_v2.py --n-per-branch %BRANCH_N_PER_BRANCH% --outdir %BRANCH_INIT_DIR%
  if errorlevel 1 goto :err
)

echo [HARD40K-8/8] Optimize with newly trained split normal/duck models
set "NEW20_MODEL_DIR_NORMAL=%AERO_MODEL_DIR_NORMAL%"
set "NEW20_MODEL_DIR_DUCK=%AERO_MODEL_DIR_DUCK%"
%PYTHON_EXE% src\run_12branches_new20.py --backend mlp --outdir %MLP_OUTDIR% --model-dir %AERO_MODEL_DIR_NORMAL% --cores %OPT_CORES% --init-dir %BRANCH_INIT_DIR% --n-per-branch %BRANCH_N_PER_BRANCH%
if errorlevel 1 goto :err

echo DONE.
exit /b 0

:err
echo FAILED at step above.
exit /b 1
