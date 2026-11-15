# Build č. 2: Mycelium do 5. minuty (šedé tvary + 1 zvuk)
Navazuje na build č. 1 (src/mycelium/, PR #1). Scénář: docs/zadani/scenar_mycelium_0-5.md. 2D shora, žádné UI, panely ani čísla.

## Rozsah
1. Fúze smyček (anastomóza): když se dvě hyfy potkají (do ~8 px), spojí se, spoj krátce pulzne a úsek zesílí. Cíl: první fúze kolem 2:30.
2. Podržení: podržení myši/prstu na místě 0,6 s = hyfy v okolí ~150 px tam zrychleně zahustí síť (měkké vedení, žádný ukazatel).
3. Cvrkot dělníků: od první plodnosti sítě (cca 3:40, nebo po 3 kotvách) se líhnou malé tečky-dělníci u zárodku a pobíhají po hyfách mezi kotvami a zárodkem; počet roste s hustotou sítě (max ~150). Plynulé.
4. Velká kotva: jedna vzdálenější větší skvrna; po zakotvení silný pulz celou sítí a plynulé mírné oddálení kamery (cca 4:45).
5. Zvuk: jediný tlumený „dum“ při kotvě (Web Audio, syntetizovaný, žádné soubory), velká kotva hlubší.

## Mimo rozsah
Grafika/sprity, UI, metriky, ukládání, Apis.

## Hotovo, když
- V simulaci bez hráče: první fúze 2:00–3:00, dělníci do 4:00, velká kotva dosažitelná do 5:00 s vedením.
- 60 fps při 1 000+ segmentech a 150 dělnících.
- Parametry nových mechanik v config.ts.

## Výstup
PR + max. 5 řádků. Cílené úpravy, žádné přepisování build 1 logiky.
