# SWARM

Biomechanical hive builder (Apis + Mycelium). Build #1: mycelium seed → hyphae → anchors.

```bash
npm install
npm run dev      # http://localhost:5173
npm run build    # dist/
```

Stack: Vite + TypeScript + HTML5 canvas. Params: `src/mycelium/config.ts`.
Docs: `docs/gdd.md`, `docs/zadani/`.

## Godot (Build #7–#10 MVP)

Mycelium + Apis isometric 0–15 min + main menu, sound, autosave. Tag `v0.1.0-mvp`.

```bash
# Play (Godot 4.3+) — menu, or skip with --rod=
godot --path godot
godot --path godot -- --rod=apis
godot --path godot -- --rod=mycelium --start=10

# Headless acceptance 0–15 (12 seeds each)
godot --headless --path godot --script res://mycelium/headless.gd
godot --headless --path godot --script res://apis/headless.gd
```

- Web entry: `/godot/` (menu). Direct rods: `/godot/?rod=apis` / `?rod=mycelium`. Canvas sketch stays at `/`.
- Windows: CI artifact `swarm-windows` + GitHub Release zip on `v*` tags.
- Esc → menu (autosave). Continue icon on choose screen when a run is saved.
- Apis iso atlas (`apis_iso_v1`) not in drop yet — grey placeholders remain until next art PR.

