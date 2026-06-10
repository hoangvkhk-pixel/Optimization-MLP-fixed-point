from __future__ import annotations

import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd


REPO_ROOT = Path(__file__).resolve().parent
WORKSPACE_ROOT = REPO_ROOT.parent
MLP_PROJECT_ROOT = WORKSPACE_ROOT / "OptimizationNewMLP_original12_qmission_fixedpoint_mlp10_experimental_portable"
AVL_PROJECT_ROOT = WORKSPACE_ROOT / "OptimizationNewMLP_original12_qmission_fixedpoint_avl10_experimental_portable"
MLP_SRC = MLP_PROJECT_ROOT / "src"
AVL_SRC = MLP_PROJECT_ROOT / "avl_optimize_portable" / "src_avl_full"

for p in (MLP_SRC, AVL_SRC):
    if str(p) not in sys.path:
        sys.path.insert(0, str(p))

import AeroCoeff_AVL as ac  # type: ignore  # noqa: E402

from branch_geometry_v2 import build_geom_from_row  # type: ignore  # noqa: E402
from new20_sizing_eval import FREECAD_COLS, geometry_freecad_outputs  # type: ignore  # noqa: E402
from original12_branching import BRANCHES  # type: ignore  # noqa: E402
from problem_v2_spec import INPUT_COLS_V2  # type: ignore  # noqa: E402


OUT_ROOT = REPO_ROOT / "topview_fixedpoint_partial_20260610"
OUT_BRANCH = OUT_ROOT / "top_view_by_branch"
MLP_SUMMARY_CSV = MLP_PROJECT_ROOT / "analysis_best_cases_qmission_summary.csv"
AVL_GEN_ROOT = AVL_PROJECT_ROOT / "gen_avl_fixedpoint_qmission3000_H500_cy06"


def freecad_from_case(row: dict[str, float]) -> dict[str, float]:
    f_geo, a_geo, _, fuse_geo, scheme_fuse = build_geom_from_row(row, ac)
    vals = geometry_freecad_outputs(
        row,
        f_geo,
        a_geo,
        ac.input_lift_surface_data(0, 15, 2, 0, 90, 0, 0, float(row["a_x_loc"])),
        fuse_geo,
        scheme_fuse,
    )
    return {col: float(vals[i]) for i, col in enumerate(FREECAD_COLS)}


def normalize_to_origin(g: dict[str, float]) -> dict[str, float]:
    out = dict(g)
    x0 = float(out["f_x_loc_root_chord"])
    for key in [
        "f_x_loc_root_chord",
        "f_x_loc_tip_chord",
        "a_x_loc_root_chord",
        "a_x_loc_tip_chord",
        "v_x_loc_root_chord",
        "v_x_loc_tip_chord",
        "fuse_x_loc",
    ]:
        out[key] = float(out[key]) - x0
    return out


def surface_polygon(g: dict[str, float], prefix: str) -> np.ndarray:
    xr = float(g[f"{prefix}_x_loc_root_chord"])
    yr = float(g[f"{prefix}_y_loc_root_chord"])
    xt = float(g[f"{prefix}_x_loc_tip_chord"])
    yt = float(g[f"{prefix}_y_loc_tip_chord"])
    cr = float(g[f"{prefix}_root_chord"])
    ct = float(g[f"{prefix}_tip_chord"])
    right = [(xr, yr), (xt, yt), (xt + ct, yt), (xr + cr, yr)]
    left = [(xr + cr, -yr), (xt + ct, -yt), (xt, -yt), (xr, -yr)]
    return np.asarray(right + left, dtype=float)


def fuselage_polygons(g: dict[str, float]) -> list[np.ndarray]:
    d = float(g["fuse_diameter"])
    nose = float(g["nose_f_aspect"]) * d
    center = float(g["center_f_aspect"]) * d
    tail = float(g["tail_f_aspect"]) * d
    x0 = float(g["fuse_x_loc"])
    x1 = x0 + nose
    x2_nominal = x1 + center
    x3_nominal = x2_nominal + tail
    surface_rear = max(float(surface_polygon(g, "f")[:, 0].max()), float(surface_polygon(g, "a")[:, 0].max()))
    x3 = max(x3_nominal, surface_rear + 0.15 * d)
    x2 = x3 - tail
    half = 0.5 * d
    n_fuse = int(round(float(g["n_fuse"])))
    distance = float(g["distance_two_fuse"])
    centers = [0.0] if n_fuse != 2 else [-0.5 * distance, 0.5 * distance]
    polys = []
    for yc in centers:
        polys.append(
            np.asarray(
                [(x0, yc), (x1, yc + half), (x2, yc + half), (x3, yc), (x2, yc - half), (x1, yc - half)],
                dtype=float,
            )
        )
    return polys


def vertical_tail_polygons(g: dict[str, float]) -> list[np.ndarray]:
    if float(g["n_vertical"]) <= 0 or float(g["v_root_chord"]) <= 0 or float(g["v_tip_chord"]) <= 0:
        return []
    xr = float(g["v_x_loc_root_chord"])
    yr = float(g["v_y_loc_root_chord"])
    xt = float(g["v_x_loc_tip_chord"])
    yt = float(g["v_y_loc_tip_chord"])
    cr = float(g["v_root_chord"])
    ct = float(g["v_tip_chord"])
    width = max(0.08 * cr, 0.04)
    n_vertical = max(1, int(round(float(g["n_vertical"]))))
    centers = [-0.5 * float(g["distance_two_fuse"]), 0.5 * float(g["distance_two_fuse"])] if n_vertical == 2 else [yr]
    polys = []
    for yc in centers:
        y_root = yc
        y_tip = yc + yt
        polys.append(
            np.asarray([(xr, y_root - width), (xt, y_tip - width), (xt + ct, y_tip + width), (xr + cr, y_root + width)], dtype=float)
        )
    return polys


def all_points(g: dict[str, float]) -> np.ndarray:
    parts = [surface_polygon(g, "f"), surface_polygon(g, "a")]
    parts.extend(fuselage_polygons(g))
    parts.extend(vertical_tail_polygons(g))
    return np.vstack(parts)


def transform(poly: np.ndarray, dx: float, dy: float = 0.0) -> np.ndarray:
    out = poly.copy()
    out[:, 0] += dx
    out[:, 1] += dy
    return out


def mac_for_case(case: dict[str, float]) -> float:
    f_geo, a_geo, _, _, _ = build_geom_from_row(case, ac)
    ref_geo = f_geo if f_geo[6] >= a_geo[6] else a_geo
    return float(ac.ref_dim_lift_surface(ref_geo))


def draw_aircraft(ax: plt.Axes, g: dict[str, float], color: str, label: str, dx: float, dy: float = 0.0) -> None:
    for prefix in ("f", "a"):
        poly = transform(surface_polygon(g, prefix), dx, dy)
        ax.fill(poly[:, 0], poly[:, 1], facecolor=color, edgecolor=color, alpha=0.16, linewidth=1.0)
        ax.plot(*poly.T, color=color, linewidth=1.4)
    for poly0 in fuselage_polygons(g):
        poly = transform(poly0, dx, dy)
        ax.fill(poly[:, 0], poly[:, 1], facecolor=color, edgecolor=color, alpha=0.12, linewidth=1.0)
        ax.plot(*poly.T, color=color, linewidth=1.2)
    for poly0 in vertical_tail_polygons(g):
        poly = transform(poly0, dx, dy)
        ax.fill(poly[:, 0], poly[:, 1], facecolor=color, edgecolor=color, alpha=0.10, linewidth=1.0)
        ax.plot(*poly.T, color=color, linewidth=1.0)
    ax.scatter([dx], [dy], s=20, marker="+", color="black", linewidth=1.0, zorder=9)
    pts = transform(all_points(g), dx, dy)
    x_mid = 0.5 * float(pts[:, 0].min() + pts[:, 0].max())
    y_bottom = float(pts[:, 1].min())
    ax.text(x_mid, y_bottom - 0.30, label, color=color, fontsize=14, ha="center", va="top", fontweight="bold")


def draw_placeholder(ax: plt.Axes, label: str, dx_center: float, width: float, height: float) -> None:
    x0 = dx_center - 0.5 * width
    y0 = -0.5 * height
    ax.add_patch(plt.Rectangle((x0, y0), width, height, fill=False, edgecolor="#999999", linewidth=1.2, linestyle="--"))
    ax.text(dx_center, 0.0, label, color="#666666", fontsize=16, ha="center", va="center", fontweight="bold")


def stat_line(prefix: str, q: float, cy: float, K: float, mtow: float, V: float, S: float, dihedral: float) -> str:
    p0 = mtow / max(S, 1e-12)
    return f"{prefix}: q={q:.2f}, cy={cy:.3f}, K={K:.2f}, mtow={mtow:.0f}, p0={p0:.2f}, V={V:.2f}, S={S:.1f}, dihedral={dihedral:.2f}"


def load_mlp_cases() -> dict[str, pd.Series]:
    df = pd.read_csv(MLP_SUMMARY_CSV)
    return {str(r["branch"]): r for _, r in df.iterrows()}


def load_avl_cases() -> dict[str, pd.Series]:
    rows: dict[str, pd.Series] = {}
    for branch_dir in AVL_GEN_ROOT.iterdir():
        if not branch_dir.is_dir():
            continue
        branch = branch_dir.name
        gens = sorted(int(p.stem.rsplit("_", 1)[-1]) for p in branch_dir.glob("info_aircraft_*.xlsx"))
        if not gens:
            continue
        gen = gens[-1]
        info = pd.read_excel(branch_dir / f"info_aircraft_{gen}.xlsx")
        px = pd.read_excel(branch_dir / f"Px_{gen}.xlsx")
        for col in info.columns:
            info[col] = pd.to_numeric(info[col], errors="coerce")
        for col in px.columns:
            px[col] = pd.to_numeric(px[col], errors="coerce")
        idx = info["q_g_per_ton_km"].astype(float).idxmin()
        rec = px.loc[idx].copy()
        for key in ["q_g_per_ton_km", "mtow_out", "cx", "cy", "K", "center_mass", "alpha_bal", "delta_bal"]:
            if key in info.columns:
                rec[key] = float(info.loc[idx, key])
        rec["generation"] = gen
        rec["row_index_0based"] = int(idx)
        rows[branch] = rec
    return rows


def render_branch(branch: str, mlp_row: pd.Series, avl_row: pd.Series | None, out_path: Path) -> dict[str, float | str | bool]:
    mlp_case = {name: float(mlp_row[name]) for name in INPUT_COLS_V2}
    mlp_g = normalize_to_origin(freecad_from_case(mlp_case))
    mlp_pts = all_points(mlp_g)

    avl_available = avl_row is not None
    if avl_available:
        avl_case = {name: float(avl_row[name]) for name in INPUT_COLS_V2}
        avl_g = normalize_to_origin(freecad_from_case(avl_case))
        avl_pts = all_points(avl_g)
        avl_width = float(avl_pts[:, 0].max() - avl_pts[:, 0].min())
        avl_span = float(np.ptp(avl_pts[:, 1]))
    else:
        avl_case = None
        avl_g = None
        avl_pts = None
        avl_width = float(mlp_pts[:, 0].max() - mlp_pts[:, 0].min())
        avl_span = float(np.ptp(mlp_pts[:, 1]))

    mlp_width = float(mlp_pts[:, 0].max() - mlp_pts[:, 0].min())
    mlp_span = float(np.ptp(mlp_pts[:, 1]))
    span = max(avl_span, mlp_span, 1.0)
    gap = max(0.35 * (avl_width + mlp_width), 1.0 * span)
    avl_dx_center = -0.5 * gap
    mlp_dx = 0.5 * gap + 0.5 * mlp_width - float(mlp_pts[:, 0].max())

    fig, ax = plt.subplots(figsize=(14, 8))
    fig.patch.set_facecolor("white")
    ax.set_facecolor("white")
    dy_aircraft = -0.55

    if avl_available and avl_g is not None and avl_pts is not None and avl_case is not None:
        avl_dx = -0.5 * gap - 0.5 * avl_width - float(avl_pts[:, 0].min())
        draw_aircraft(ax, avl_g, "#1f77b4", "AVL", avl_dx, dy_aircraft)
        ax.scatter(
            [avl_dx + float(avl_row["center_mass"]) * mac_for_case(avl_case)],
            [dy_aircraft],
            s=70,
            marker="o",
            color="red",
            edgecolor="white",
            linewidth=0.8,
            zorder=8,
        )
        avl_stat = stat_line(
            "AVL",
            float(avl_row["q_g_per_ton_km"]),
            float(avl_row["cy"]),
            float(avl_row["K"]),
            float(avl_row["mtow_out"]),
            float(avl_row["V"]),
            float(avl_row["S_ref"]),
            float(avl_row["a_dihedral_mag"]),
        )
    else:
        draw_placeholder(ax, "AVL pending", avl_dx_center, max(avl_width * 1.05, 12.0), max(span * 0.80, 6.5))
        avl_stat = "AVL: pending"

    draw_aircraft(ax, mlp_g, "#ff7f0e", "MLP", mlp_dx, dy_aircraft)
    ax.scatter(
        [mlp_dx + float(mlp_row["center_mass"]) * mac_for_case(mlp_case)],
        [dy_aircraft],
        s=70,
        marker="o",
        color="red",
        edgecolor="white",
        linewidth=0.8,
        zorder=8,
    )
    mlp_stat = stat_line(
        "MLP",
        float(mlp_row["q_g_per_ton_km"]),
        float(mlp_row["cy"]),
        float(mlp_row["K"]),
        float(mlp_row["mtow_out"]),
        float(mlp_row["V"]),
        float(mlp_row["S_ref"]),
        float(mlp_row["a_dihedral_mag"]),
    )

    fig.suptitle(branch, fontsize=24, y=0.965)
    fig.text(0.08, 0.86, avl_stat, fontsize=15)
    fig.text(0.08, 0.82, mlp_stat, fontsize=15)

    if avl_available and avl_pts is not None:
        pts = np.vstack([transform(avl_pts, avl_dx, dy_aircraft), transform(mlp_pts, mlp_dx, dy_aircraft)])
    else:
        pts = np.vstack(
            [
                np.asarray(
                    [
                        [avl_dx_center - max(avl_width * 0.525, 6.0), -0.5 * max(span * 0.80, 6.5)],
                        [avl_dx_center + max(avl_width * 0.525, 6.0), 0.5 * max(span * 0.80, 6.5)],
                    ]
                ),
                transform(mlp_pts, mlp_dx, dy_aircraft),
            ]
        )

    pad_x = max(0.08 * np.ptp(pts[:, 0]), 0.6)
    pad_y = max(0.12 * np.ptp(pts[:, 1]), 0.6)
    ax.set_xlim(float(pts[:, 0].min() - pad_x), float(pts[:, 0].max() + pad_x))
    ax.set_ylim(float(pts[:, 1].min() - pad_y), float(pts[:, 1].max() + pad_y + 1.15))
    ax.set_aspect("equal", adjustable="box")
    ax.axis("off")
    fig.tight_layout(rect=[0, 0.03, 1, 0.90])
    fig.savefig(out_path, dpi=180)
    plt.close(fig)

    row: dict[str, float | str | bool] = {
        "branch": branch,
        "avl_available": avl_available,
        "q_mlp": float(mlp_row["q_g_per_ton_km"]),
        "mtow_mlp": float(mlp_row["mtow_out"]),
        "S_ref_mlp": float(mlp_row["S_ref"]),
        "p0_mlp": float(mlp_row["mtow_out"]) / max(float(mlp_row["S_ref"]), 1e-12),
        "dihedral_mlp": float(mlp_row["a_dihedral_mag"]),
        "image": str(out_path.relative_to(OUT_ROOT)),
    }
    if avl_available and avl_row is not None:
        row.update(
            {
                "q_avl": float(avl_row["q_g_per_ton_km"]),
                "mtow_avl": float(avl_row["mtow_out"]),
                "S_ref_avl": float(avl_row["S_ref"]),
                "p0_avl": float(avl_row["mtow_out"]) / max(float(avl_row["S_ref"]), 1e-12),
                "dihedral_avl": float(avl_row["a_dihedral_mag"]),
            }
        )
    return row


def make_grid(image_paths: list[Path], out_path: Path) -> None:
    fig, axes = plt.subplots(4, 3, figsize=(18, 30))
    fig.suptitle("Fixed-point topview | partial AVL coverage", fontsize=20, y=0.995, x=0.01, ha="left")
    for ax, img_path in zip(axes.flat, image_paths):
        ax.imshow(plt.imread(img_path))
        ax.set_title(img_path.stem.replace("_topview_fixedpoint_partial", ""), fontsize=12)
        ax.axis("off")
    for ax in axes.flat[len(image_paths) :]:
        ax.axis("off")
    fig.tight_layout(rect=[0, 0, 1, 0.987])
    fig.savefig(out_path, dpi=170)
    plt.close(fig)


def write_readme(summary_df: pd.DataFrame) -> None:
    avl_done = int(summary_df["avl_available"].sum())
    text = (
        "# Fixed-point topview partial gallery\n\n"
        f"- Generated: 2026-06-10\n"
        f"- Total branches: {len(summary_df)}\n"
        f"- Branches with AVL panel: {avl_done}\n"
        f"- Branches with AVL pending: {len(summary_df) - avl_done}\n\n"
        "Contents:\n"
        "- `topview_grid.png`: full 12-branch grid\n"
        "- `topview_summary.csv`: branch status and basic metrics\n"
        "- `top_view_by_branch/*.png`: one figure per branch\n"
    )
    (OUT_ROOT / "README.md").write_text(text, encoding="utf-8")


def main() -> None:
    OUT_BRANCH.mkdir(parents=True, exist_ok=True)
    mlp_map = load_mlp_cases()
    avl_map = load_avl_cases()
    summary_rows = []
    images = []
    for spec in BRANCHES:
        branch = spec.name
        if branch not in mlp_map:
            raise KeyError(f"Missing MLP best case for branch {branch}")
        out_path = OUT_BRANCH / f"{branch}_topview_fixedpoint_partial.png"
        summary_rows.append(render_branch(branch, mlp_map[branch], avl_map.get(branch), out_path))
        images.append(out_path)

    summary_df = pd.DataFrame(summary_rows)
    summary_df.to_csv(OUT_ROOT / "topview_summary.csv", index=False)
    make_grid(images, OUT_ROOT / "topview_grid.png")
    write_readme(summary_df)
    print(f"Wrote {OUT_ROOT}")


if __name__ == "__main__":
    main()
