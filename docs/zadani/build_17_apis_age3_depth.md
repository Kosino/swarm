# Build 17 – Apis Age-3 content depth
Zdroj: GDD §3 (dílny, líhně), §7 scénář Sucho; scenar_10-15.md; art `pro_v3` + `apis_iso_v2`.
Navazuje na main po Build 13 / v0.3.1. Nezávislé na Buildech 14–16.

## Cíl
- Více druhů budov u Apis v late mid-game / Věku 3 (ne jen jednotné plástve).
- Jedna mid-game událost dle GDD: **Sucho**.
- Art jen z existujících spriteů (`apis2_plast_*`, `apis2_kamen_*`, `apis2_overlay_med`, `apis_pro_kukla`). Bez nové generace.
- Mediány wow ±15 s vůči v0.1.0, mezery ≤90 s, headless CI zelené. Merge dělá Honza.

## Budovy (role na komoře)
| Role | Česky | Vzhled | Kdy |
|---|---|---|---|
| `comb` | Plást | `apis2_plast_*` | výchozí |
| `nursery` | Líheň | plast + `apis_pro_kukla` overlay | u jádra od floor2 / royal |
| `honey` | Medárna | vysoký stack + `apis2_overlay_med` | mid ring / dew relief |
| `workshop` | Dílna | `apis2_kamen_*` + mosaz | po brass (šrot z mašiny) |

## Událost Sucho
- Auto po soumraku (`WOW_DROUGHT = 625`, ~10:25). Louky vadnou, provoz zpomalí.
- Hráč: feromonová stopa k druhé louce → rosa (`dew`), medárna se posílí.
- Pak stávající Age-3 wow beze změny: zimní chomáč 11:10 → mosaz 12:25 → královská buňka 13:40 → Seeds 14:40 → konec 15:00.
- Sucho **není** median gate (neposouvá targets).

## Akceptace
- Headless Apis + Mycelium `ok`, mediány beze změny (±15 s), late gap ≤90 s.
- Snapshot `roleCounts` ukazuje nursery/honey/workshop v Age 3.
- PR „Build 17 Apis Age-3 depth“; **neslučovat**.
