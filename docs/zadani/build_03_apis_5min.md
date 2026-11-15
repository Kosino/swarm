# Build č. 3: Apis do 5. minuty (šedé tvary + 1 zvuk)
Nový modul src/apis/ vedle src/mycelium/, sdílené jádro (smyčka, kamera, vstupy). Scénář: docs/zadani/scenar_apis_0-5.md (závazný). 2D shora, žádné UI, panely ani čísla. Výběr Rodu zatím přes URL parametr (?rod=apis / ?rod=mycelium), žádné menu.

## Rozsah
1. Teplá světlá planeta: louka (světlé pozadí), 8–12 květin (kroužky) v různé vzdálenosti, zlatý strom (velká vzdálená cílová květina).
2. Jádro (královna) uprostřed + malý roj (8–12 teček kolem jádra). Roj nese vosk: jeho jas = jediná zásoba. Stavba komory roj ztlumí, nektar ho rozzáří. Bez dostatku jasu nejde stavět (komora se jen neobjeví, krátké „zachvění“ roje).
3. Stavba: klik na volný hex sousedící s úlem = komora (růstová animace 0,6–1 s). Každá komora vylíhne 1 dělnici.
4. Odkázání: tah od úlu ke květině = jednorázové nastavení dráhy; dělnice pak samy létají tam a zpět, dráha jemně září. Nektar při návratu zalije plástev jantarem a pulz běží do jádra.
5. Prstenec: uzavřený prstenec 6 komor kolem jádra = úl „povyroste o patro“ (vizuální zvětšení + pulz).
6. Živý provoz (~3:40): louka kolem aktivních drah rozkvete (květiny přibývají), dělnice proudí.
7. Velký let (~4:40): dosah tahu roste s velikostí úlu, zlatý strom na dosah cca od 4:30; odkázání na něj = let celého roje + plynulé oddálení kamery.
8. Zvuk: jediný tlumený syntetizovaný bzukot/„dum“ při návratu s nektarem (Web Audio), hlubší při prstenci a velkém letu.

## Hotovo, když
- Simulace s jednoduchým botem (staví k jádru, odkazuje na nejbližší květinu): první dělnice ~0:35, první nektar ~1:20, prstenec ~2:15, živý provoz ~3:40, velký let dosažitelný do 5:00.
- 60 fps při 200 dělnicích. Parametry v src/apis/config.ts.

## Výstup
PR + max. 5 řádků s naměřenými časy. Mimo rozsah: sprity, UI, metriky, ukládání.
