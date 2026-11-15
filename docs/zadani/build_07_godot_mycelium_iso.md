# Build č. 7 · Godot 4 · Mycelium v izometrii (0–10 min)
Cíl: hra má vypadat jako budovatelská strategie, ne jako webová hračka. Mechaniky, tempo a parametry jsou ověřené ve webových buildech 1–6 a ty jsou zdrojem pravdy (src/mycelium/config.ts, docs/zadani/).

## Technika
- Godot 4.x (stabilní), GDScript, projekt ve složce `godot/` v repu Kosino/swarm. Web v `src/` zůstává jako skicák.
- Izometrický svět (2:1), TileMapLayer pro půdu, Y-sort pro objekty, kamera s posunem, zoomem kolečkem a plynulým oddálením při velké kotvě.
- Parametry v jednom souboru `godot/mycelium/config.gd`, převzaté z config.ts.
- Export presety pro Windows, macOS a Web. CI v GitHub Actions sestaví Web export, nasadí ho na Pages jako `/godot/` a pro PR jako náhled, a přiloží Windows build jako artefakt.

## Obsah
- Celých 0–10 min Mycelia podle scénářů 0–5 a 5–10 včetně gest s magnetickým snapem z buildu 6.
- Demo vrstva (?demo / přepínač F1): čas, rychlost 1×/2×/4×/8×, toasty wow, řádek „Dál: …“. Diegetické navádění zůstane vždy.
- Dokud nedorazí izometrický art, použij šedé izometrické tvary a top-down art v2 jen jako texturu na dlaždicích.

## Akceptace
- Headless simulace (godot --headless) na 12 seedech dá stejné mediány jako web (±15 s), žádná mezera nad 90 s.
- 60 fps při 1000+ segmentech a 150 dělnících.
- Web export se načte v náhledu PR a Windows build se spustí.
