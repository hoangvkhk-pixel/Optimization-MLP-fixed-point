@echo off
setlocal
set "NEW20_OBJECTIVE=q_g_per_ton_km"
set "NEW20_MISSION_L_KM=3000"
set "NEW20_MAX_CY=0.6"
set "NEW20_FIXED_H=500"
set "NEW20_USE_DIRECT_K=1"
set "AERO_BASE_LABEL=data\aero_labeled_v2_plus_targeted_q5k_plus_cx20k_plus_split30k.csv"
set "AERO_TARGETED_LHS=data\aero_lhs_targeted_split30k_v2.csv"
set "AERO_TARGETED_LABEL=data\aero_labeled_targeted_split30k_v2.csv"
set "AERO_MERGED_LABEL=data\aero_labeled_v2_plus_targeted_q5k_plus_cx20k_plus_split30k_plus_targeted30k.csv"
set "AERO_KHEAD_LABEL=data\aero_labeled_v2_260k_khead.csv"
set "AERO_NORMAL_LABEL=data\aero_labeled_v2_normal_260k_khead.csv"
set "AERO_DUCK_LABEL=data\aero_labeled_v2_duck_260k_khead.csv"
set "AERO_COMMON_PREP=data\prepared_aero_v2_common_260k_khead"
set "AERO_NORMAL_PREP=data\prepared_aero_v2_normal_260k_khead"
set "AERO_DUCK_PREP=data\prepared_aero_v2_duck_260k_khead"
set "AERO_MODEL_DIR_COMMON=models\aero_mlp_original12_common_qkhead_260k"
set "AERO_MODEL_DIR_NORMAL=models\aero_mlp_original12_normal_qkhead_260k"
set "AERO_MODEL_DIR_DUCK=models\aero_mlp_original12_duck_qkhead_260k"
set "AERO_EPOCHS=400"
set "TRAIN_BATCH_SIZE=256"
if not defined NEW20_START_STEP set "NEW20_START_STEP=1"
call "%~dp0_env.bat"
if errorlevel 1 goto :err
cd /d "%PROJECT_ROOT%"

if "%NEW20_START_STEP%"=="9" goto :step9
if "%NEW20_START_STEP%"=="8" goto :step8
if "%NEW20_START_STEP%"=="7" goto :step7
if "%NEW20_START_STEP%"=="6" goto :step6
if "%NEW20_START_STEP%"=="5" goto :step5
if "%NEW20_START_STEP%"=="4" goto :step4
if "%NEW20_START_STEP%"=="3" goto :step3
if "%NEW20_START_STEP%"=="2" goto :step2

:step1
echo [Q-KHEAD-1/9] Generate targeted 30k aero cases for 260k retrain
%PYTHON_EXE% src\generate_aero_lhs_targeted_split30k_v2.py --out %AERO_TARGETED_LHS%
if errorlevel 1 goto :err

:step2
echo [Q-KHEAD-2/9] Label targeted 30k aero cases with AVL
%PYTHON_EXE% src\label_aero_avl_v2.py --infile %AERO_TARGETED_LHS% --out %AERO_TARGETED_LABEL% --workers %AERO_WORKERS%
if errorlevel 1 goto :err

:step3
echo [Q-KHEAD-3/9] Merge 230k base labels with new targeted 30k
%PYTHON_EXE% src\merge_aero_labeled_v2.py --base %AERO_BASE_LABEL% --extra %AERO_TARGETED_LABEL% --out %AERO_MERGED_LABEL%
if errorlevel 1 goto :err

:step4
echo [Q-KHEAD-4/9] Build K-head labels from merged 260k AVL-labeled aero data
%PYTHON_EXE% src\make_khead_aero_labels_v2.py --input %AERO_MERGED_LABEL% --out %AERO_KHEAD_LABEL%
if errorlevel 1 goto :err

:step5
echo [Q-KHEAD-5/9] Split K-head labels into normal and duck
%PYTHON_EXE% src\split_aero_labeled_normal_duck_v2.py --input %AERO_KHEAD_LABEL% --normal-out %AERO_NORMAL_LABEL% --duck-out %AERO_DUCK_LABEL%
if errorlevel 1 goto :err

:step6
echo [Q-KHEAD-6/9] Prepare common, normal, duck train/val/test arrays
%PYTHON_EXE% src\prepare_aero_trainset_v2.py --input %AERO_KHEAD_LABEL% --outdir %AERO_COMMON_PREP%
if errorlevel 1 goto :err
%PYTHON_EXE% src\prepare_aero_trainset_v2.py --input %AERO_NORMAL_LABEL% --outdir %AERO_NORMAL_PREP%
if errorlevel 1 goto :err
%PYTHON_EXE% src\prepare_aero_trainset_v2.py --input %AERO_DUCK_LABEL% --outdir %AERO_DUCK_PREP%
if errorlevel 1 goto :err

:step7
echo [Q-KHEAD-7/9] Train common, normal, duck K-head aero models
%PYTHON_EXE% src\train_aero_mlp_v2.py --data-dir %AERO_COMMON_PREP% --outdir %AERO_MODEL_DIR_COMMON% --epochs %AERO_EPOCHS% --batch-size %TRAIN_BATCH_SIZE% --cx-weight 3.0 --k-weight 2.5 --early-stop-patience 50 --lr-patience 15 --promote-variant best_combo
if errorlevel 1 goto :err
%PYTHON_EXE% src\train_aero_mlp_v2.py --data-dir %AERO_NORMAL_PREP% --outdir %AERO_MODEL_DIR_NORMAL% --epochs %AERO_EPOCHS% --batch-size %TRAIN_BATCH_SIZE% --cx-weight 3.0 --k-weight 2.0 --early-stop-patience 50 --lr-patience 15 --promote-variant best_combo
if errorlevel 1 goto :err
%PYTHON_EXE% src\train_aero_mlp_v2.py --data-dir %AERO_DUCK_PREP% --outdir %AERO_MODEL_DIR_DUCK% --epochs %AERO_EPOCHS% --batch-size %TRAIN_BATCH_SIZE% --cx-weight 4.0 --k-weight 3.0 --early-stop-patience 50 --lr-patience 15 --promote-variant best_combo
if errorlevel 1 goto :err

:step8
echo [Q-KHEAD-8/9] Benchmark 3 checkpoint variants for common model and promote winner
set "NEW20_MODEL_DIR=%AERO_MODEL_DIR_COMMON%"
set "NEW20_MODEL_DIR_NORMAL="
set "NEW20_MODEL_DIR_DUCK="
%PYTHON_EXE% src\benchmark_single_model_variants_v2.py
if errorlevel 1 goto :err

:step9
echo [Q-KHEAD-9/9] Benchmark 3 checkpoint variants for split normal/duck models and promote winner
set "NEW20_MODEL_DIR_NORMAL=%AERO_MODEL_DIR_NORMAL%"
set "NEW20_MODEL_DIR_DUCK=%AERO_MODEL_DIR_DUCK%"
%PYTHON_EXE% src\benchmark_split_model_variants_v2.py
if errorlevel 1 goto :err

echo DONE.
exit /b 0

:err
echo FAILED at step above.
exit /b 1
