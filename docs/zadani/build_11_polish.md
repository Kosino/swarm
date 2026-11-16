# Build 11 – polish podle konceptu (Godot)

Reference: koncept_pokrocila_overview.png (0. vs 15. minuta), Visuals-mvp.
Art: mycelium_iso_v2.tgz, apis_iso_v2.tgz (3 stupně terénu, sítě/feromon ve 3 intenzitách, stavby ve 3 stadiích rozestavěná→dorostlá→zářivá, jednotky s nákladem, FX sekvence aditivní 8 fps).
Cíl: progres čitelný ve světě bez panelů.
- Terén se proměňuje od sítě/úlu ven (pustá→prorostlá→živá / divoká→osetá→živá), plynulé přechody.
- Tloušťka/záře hyf a feromonu podle provozu/stáří.
- Stavby nejdřív rozestavěné (dělníci s nákladem viditelně nosí), pak dorostlé, při wow zářivé.
- FX kapky/spóry/pyl na pulz a wow.
- Kamera: jemný zoom-out s růstem, ať je ve 15. min vidět celé dílo.
Akceptace: mediány ±15 s proti v0.1.0, mezery ≤90 s, 60 fps, Web /godot/ + Windows; po merge release v0.2.0-polish.
