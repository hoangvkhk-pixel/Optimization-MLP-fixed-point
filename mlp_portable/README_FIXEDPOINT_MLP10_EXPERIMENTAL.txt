EXPERIMENTAL FIXED-POINT MLP PORTABLE

Run:
  run_mlp_original12_fixedpoint_split300k_qmission3000_H500_cy06_optimize.bat

Settings:
  backend = MLP split normal/duck
  normal model = aero_mlp_original12_normal_qkhead_300k_hard40k
  duck model = aero_mlp_original12_duck_qkhead_300k_hard40k
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
  gen_mlp_fixedpoint_split300k_qmission3000_H500_cy06

Log:
  logs\optimize_fixedpoint_mlp10.log

Note:
  This is an experimental fixed-point optimizer build. Recheck the final best candidates with AVL after the MLP run.
