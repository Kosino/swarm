# SWARM

Biomechanical hive builder (Apis + Mycelium). Build #1: mycelium seed → hyphae → anchors.

```bash
npm install
npm run dev      # http://localhost:5173
npm run build    # dist/
```

Stack: Vite + TypeScript + HTML5 canvas. Params: `src/mycelium/config.ts`.
Docs: `docs/gdd.md`, `docs/zadani/`.

## Godot (Build #7)

Mycelium isometric 0–10 min lives in `godot/`.

```bash
# Play (Godot 4.3+)
godot --path godot

# Headless acceptance (12 seeds)
godot --headless --path godot --script res://mycelium/headless.gd
```

Web export deploys to GitHub Pages at `/godot/`. Windows build is a CI artifact (`swarm-mycelium-windows`).

