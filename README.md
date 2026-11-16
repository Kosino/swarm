# SWARM

Biomechanical hive builder (Apis + Mycelium). Build #1: mycelium seed → hyphae → anchors.

```bash
npm install
npm run dev      # http://localhost:5173
npm run build    # dist/
```

Stack: Vite + TypeScript + HTML5 canvas. Params: `src/mycelium/config.ts`.
Docs: `docs/gdd.md`, `docs/zadani/`.

## Godot (Build #7–#11 polish)

Mycelium + Apis isometric 0–15 min + main menu, sound, autosave. Live art: iso v2 (terrain / network / building stages, carrying units, additive FX). Tag `v0.1.0-mvp`; polish ships as PR before `v0.2.0-polish`.

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
- Menu gear: graphics quality / resolution / fullscreen. `H` / `?`: keybind help.
- Art: `godot/art/mycelium_iso_v2/`, `godot/art/apis_iso_v2/` (v1 packs kept as reference).

