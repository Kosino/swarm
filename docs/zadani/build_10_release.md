# Build 10 – MVP release (Godot)

Navazuje na main po buildu 9 (menu + Věk 3, oba Rody 0–15).

- Art: zapoj `art_drop/apis_iso_v1.tgz` (pokud chybí, placeholdery; další PR) místo šedých Apis placeholderů.
- Zvuk: minimální ambient pro každý Rod + krátké zvuky gest a wow momentů (procedurální/CC0, bez textu), hlasitost v menu.
- Ukládání: autosave každou minutu + při odchodu do menu; v menu „pokračovat" (ikona, bez textové zdi).
- Ladění tempa: drž mediány ±15 s, žádná mezera >90 s; opravit vše, co rozbíjí čitelnost (jednotky, stopa).
- Release: tag `v0.1.0-mvp`, GitHub Release s Windows zipem; hlavní Pages `/godot/` jako vstupní bod (web skicák nech na `/`).

Akceptace: headless sim oba Rody 0–15, 60 fps, Web + Windows, release vytvořen.
