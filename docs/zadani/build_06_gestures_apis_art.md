# Build č. 6: gesta + Apis art v1

Navazuje na build #5 (PR #9). Jedno PR proti `main`.

## A) Gesta
- **Zakroužení (Mycelium):** uzavření když konec tahu ≤~60 px od startu **nebo** ≥80 % úhlu kolem tvaru. Zásah: střed uvnitř polygonu **nebo** polygon pokrývá ≥50 % obrysu. Stroke smooth+resample; živá stopa; highlight chyceného tvaru.
- **Spojení (connect):** magnetický snap ~40 px (× DPR, větší na touch) k nejbližší platné hyfě/zárodku/úlu/květu. Cíl se rozsvítí; puštění dokončí. Feromonová stopa auto-dokončí při konci ≤~60 px od cíle.
- Neúspěch: měkká vizuální miss zpětná vazba (nikdy tichý fail).
- `npm run sim:gestures` — šum ruky (jitter ~10 px, undershoot 15 %), cíl úspěšnosti ≥95 %.

## B) Apis art v1
Atlas `public/art/atlas_apis_v1.{png,json}` (jádro, komory prázdná/stavba/plná, dělnice 32, květiny A/B/C, zlatý strom, louka a/b/c seamless). Stejný vzor jako Mycelium v2.

## Acceptance
- Mediany WOW 0–10 obou Rodů beze změn (pás build #5).
- Gesture noise success ≥95 %.
- 60 fps.
- PR preview funguje.
