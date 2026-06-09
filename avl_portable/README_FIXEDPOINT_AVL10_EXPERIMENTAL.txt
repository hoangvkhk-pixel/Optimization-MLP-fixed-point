EXPERIMENTAL FIXED-POINT AVL PORTABLE

Run:
  run_avl_original12_fixedpoint_qmission3000_H500_cy06_optimize.bat

Settings:
  backend = AVL
  cores = 10
  objective = q_g_per_ton_km
  H = 500
  cy_max = 0.6
  fixed-point = on
  fp_relax = 0.5
  fp_max_iter = 10
  fp_tol_abs = 1.0 kg
  fp_tol_rel = 0.001

Output:
  gen_avl_fixedpoint_qmission3000_H500_cy06

Log:
  logs\optimize_fixedpoint_avl10.log

Note:
  This is an experimental fixed-point optimizer build. Use AVL recheck logic as the source of truth for final analysis.
