# SWARM

Biomechanical hive builder (Apis + Mycelium). Build #1: mycelium seed → hyphae → anchors.

```bash
npm install
npm run dev      # http://localhost:5173
npm run build    # dist/
```

Stack: Vite + TypeScript + HTML5 canvas. Params: `src/mycelium/config.ts`.
Docs: `docs/gdd.md`, `docs/zadani/`.

## Godot (Build #7–#9)

Mycelium + Apis isometric 0–15 min + main menu (Rod choice) in `godot/`.

```bash
# Play (Godot 4.3+) — menu, or skip with --rod=
godot --path godot
godot --path godot -- --rod=apis
godot --path godot -- --rod=mycelium --start=10

# Headless acceptance 0–15 (12 seeds each)
godot --headless --path godot --script res://mycelium/headless.gd
godot --headless --path godot --script res://apis/headless.gd
```

Web export: `/godot/` (menu) and `/godot/?rod=apis` / `?rod=mycelium`. Windows CI artifact: `swarm-windows`.

