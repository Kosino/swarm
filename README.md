# SWARM

Biomechanical hive builder (Apis + Mycelium). Build #1: mycelium seed → hyphae → anchors.

```bash
npm install
npm run dev      # http://localhost:5173
npm run build    # dist/
```

Stack: Vite + TypeScript + HTML5 canvas. Params: `src/mycelium/config.ts`.
Docs: `docs/gdd.md`, `docs/zadani/`.

## Godot (Build #7–#8)

Mycelium + Apis isometric 0–10 min live in `godot/`.

```bash
# Play (Godot 4.3+)
godot --path godot
godot --path godot -- --rod=apis

# Headless acceptance (12 seeds each)
godot --headless --path godot --script res://mycelium/headless.gd
godot --headless --path godot --script res://apis/headless.gd
```

Web export: `/godot/` (Mycelium) and `/godot/?rod=apis`. Windows CI artifact: `swarm-windows`.

