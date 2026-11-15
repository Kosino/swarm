# SWARM
**Game Design Document · zdroj pravdy**
Verze: 0.4 (zdroj pravdy; reference: reference/projekt_hmyzi_hra_SWARM_full.md, visuals-mvp/) · Založeno: 15. 11. 2026
Stav sekcí: ✅ schváleno · 🟡 návrh · ❓ otevřená otázka

---

## 1. Vize (🟡)
Budovatelská strategie, kde hráč řídí biomechanický úl. Včely (**Apis**) jsou napůl hmyz, napůl stroj: chitin s mosaznými klouby, křídla s žilkováním jako tištěné spoje, med jako palivo i stavební pojivo. Druhým Rodem je **Mycelium**, hustá síť hyf s vlastními jednotkami. Apis a Mycelium jsou dva oddělené hratelné Rody, každý na své výrazně odlišné planetě.

**Jedna věta:** „Postav živý stroj z včel a hub a přežij sezóny v rozpadajícím se světě.“

**Pilíře:**
1. **Živá stavba:** budovy rostou, stárnou a dají se opravit nebo zrecyklovat.
2. **Dva Rody, dvě fantasy:** Apis staví centralizovaný úl, Mycelium prorůstá sítí.
3. **Roj místo jednotek:** hráč nedává příkazy jednotlivcům, nastavuje priority a feromonové signály.
4. **Biomechanická krása:** čitelná, detailní 2D grafika s mechanickými detaily.

## 2. Fantasy a svět (🟡)
- Svět po kolapsu, kde přírodu a stroje už nejde oddělit. Rozpadlé lidské stroje jsou zdrojem kovu.
- **Apis:** královna jako „jádro“ (procesor + líheň), kasty: dělnice, sběračky, stavitelky, strážkyně, opravářky.
- **Mycelium:** samostatný Rod, síť hyf s hyfálními dělníky, kteří se po síti pohybují (cvrkot). Rozvádí živiny a rozkládá odpad na suroviny.
- **Hrozby:** sezóny (zima, sucho), parazité (roztoči-drony), rez, konkurenční roje, plísňová infekce sítě.
- ❓ Tón: spíš idylický a kontemplativní, nebo drsný survival?

## 3. Core loop (🟡)
1. **Sběr:** sběračky nosí nektar, pyl, kovový šrot a vodu.
2. **Zpracování:** úl vyrábí med (energie), vosk (stavba), olej (mechanika); mycelium rozkládá odpad na živiny.
3. **Stavba a růst:** nové plástve (hex grid), dílny, líhně; mycelium propojuje vzdálené uzly.
4. **Expanze:** nové květinové louky a ložiska šrotu, kolonizace pomocí myceliových výběžků.
5. **Přežití sezóny:** zásoby, obrana, opravy.
6. **Evoluce:** mezi sezónami nové kasty, mutace a technologie.

Meta loop: kampaň po sezónách / scénáře s cíli; ❓ roguelite prvky mezi běhy?

## 4. Klíčové systémy (🟡)
- **Hex grid úlu** (povrch) + **síťový graf mycelia** (podzemí).
- **Feromony:** hráč maluje zóny priority (sběr, stavba, obrana, ústup).
- **Suroviny:** nektar, pyl, med, vosk, šrot, olej, voda, živiny.
- **Údržba:** budovy i jedinci se opotřebovávají; opravářky a mycelium je recyklují.
- **Teplota a vlhkost** úlu jako globální stav.

## 5. Engine a technika (❓ k rozhodnutí)
Doporučení: **Godot 4** (2D, zdarma, dobrá práce s tile mapami a velkým počtem jednotek přes MultiMesh/servers, export na PC i web).
Alternativy: Unity (silné ekosystémy, licenční nejistota), vlastní engine v TS/WebGL (prototyp v prohlížeči).
Cílová platforma: ❓ PC (Steam) / web / mobil.

## 6. UI/UX (🟡)
- Minimum panelů, hlavní ovládání přes feromonové štětce a radiální menu.
- Přepínání vrstev povrch / podzemí jednou klávesou, nebo průřezový pohled.
- Přehled kolonie: zásoby, populace podle kast, zdraví sítě.
- Vizuální jazyk UI: plástve, mosaz, žilkování křídel.

## 7. Scénáře (🟡)
1. **První jaro:** tutoriál, založení úlu, první mycelium.
2. **Sucho:** voda vzácná, mycelium jako jediný zdroj vlhkosti.
3. **Rezavá zima:** přežít chlad a korozi.
4. **Invaze roztočů:** obrana a karanténa sítě.
5. **Dva úly:** propojení dvou kolonií jedním myceliem.

## 8. Art a hybridní sprite pipeline (🟡)
Cíl: konzistentní 2D sprity s mechanickým detailem při rozumné ceně.
1. **Koncept:** AI generování moodboardů a variant (tým Grafik).
2. **Base mesh:** jednoduchý 3D model (Blender) pro každou kastu/budovu.
3. **Render:** z 3D do sprite sheetů (8 směrů nebo izometrie, animace letu a práce).
4. **Paint-over:** ruční nebo AI dotažení detailů a palety, sjednocení stylu.
5. **Export:** atlasy + normal mapy pro 2D osvětlení v enginu.
❓ Pohled: izometrie, nebo boční průřez úlem?

## 9. Plán a tým botů (🟡)
- Fáze 0: schválení vize, tónu, enginu a pohledu.
- Fáze 1: šedý prototyp core loopu (sběr, med, stavba plástve).
- Fáze 2: mycelium vrstva a feromony.
- Fáze 3: art pipeline a první scénář.
Specializovaní boti (navrhnu až po schválení): Systems Designer, Art Pipeline, Prototyp/Engine, Narativ a scénáře.

## 10. Rozhodovací log
| Datum | Rozhodnutí | Stav |
|---|---|---|
| 15. 11. 2026 | Založen GDD v0.1 | 🟡 |
| 15. 11. 2026 | Vývoj výhradně v Grok Builderu (2D canvas web), tým: Builder Engineer, Svět & UX, Art Pipeline; tokenová disciplína | ✅ |
| 15. 11. 2026 | MVP = Apis + Mycelium, early game bez metrik 10–15 min | ✅ |
| 15. 11. 2026 | Rozhodnutí Honzy: název SWARM; prvních 15 min bez panelů a MU/S, Korpus HUD až v mid-game; kód staví na Mycelium buildu 1 (repo Kosino/swarm), Korpus slice jen reference; 2D shora pro early game, izometrie později; Seeds jen náznak na konci Věku 3; schválené koncepty Visuals-mvp jsou závazná vizuální reference | ✅ |
| 15. 11. 2026 | Dělníci na hyfách (cvrkot) od cca 3:40 schváleni; podržení + fúze smyček do buildu č. 2; zvuk až od buildu č. 2 | ✅ |
| 15. 11. 2026 | Apis build č. 3 (0–5 min): vosk=jas roje, komory+líhnutí, odkázání na květiny, prstenec, živý provoz, velký let ke zlatému stromu; výběr Rodu `?rod=apis\|mycelium` | ✅ |


---

## 21. MVP a early game (✅ směr od Honzy)
- Rody v MVP: Apis (superorganismus, včelstvo) a Mycelium (hustá síť hyf).
- Prvních 10–15 minut: žádné panely, metriky, vzorce ani MU/S. Stav se čte z obrazu, pohybu a zvuku.
- **Mycelium:** zasít malinký zárodek, tenké hyfy se plazí a kotví, síť se zahušťuje, cvrkot dělníků na hyfách. Magie je v prorůstání.
- **Apis:** začít s malým rojem a postavit úl. Hráč staví komory, vylíhnuté dělnice jednorázově odkáže na květiny pro nektar. Magie je v budování centralizované struktury s jednotkami uvnitř; úl roste po krůčkách, tempem vyvážený s Myceliem.
- **Planety:** Apis teplá, otevřená, květiny. Mycelium vlhká, stinná, prorůstající.
- Wow moment nejpozději každých 60–90 s. Metriky se odemykají až po 10–15 min, postupně a volitelně.
- Pořadí buildů: (1) Mycelium 0–2 min, (2) Mycelium 0–5 min, (3) Apis 0–2 min, (4) Apis 0–5 min, (5) planety v grafice + milníky do 10 min.
- Scénář Mycelium 0–5: docs/zadani/scenar_mycelium_0-5.md
- Scénář Apis 0–5: docs/zadani/scenar_apis_0-5.md
