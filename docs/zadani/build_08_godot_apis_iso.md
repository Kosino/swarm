# Build č. 8 · Godot 4 · Apis v izometrii (0–10 min)
Cíl: stejná architektura jako Mycelium v `godot/` — Apis 0–10 min, grey iso placeholdery, headless parity s webem.

## Technika
- GDScript ve `godot/apis/`, parametry z `src/apis/config.ts`.
- Demo F1, gesta se snapem (feromonový tah), headless 12 seedů.
- Web export `/godot/?rod=apis`, Windows CI artefakt.
- Iso art `art_drop/apis_iso_v1.tgz` napojit do stejného PR až dorazí.

## Akceptace
- Mediány ±15 s vs web: 0:34 / 1:16 / 2:07 / 3:22 / 4:34 / 5:46 / 7:07 / 8:14 / 9:17 / 9:55
- Žádná mezera >90 s; 60 fps při 150 dělnicích.
