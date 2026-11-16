# Build 19 – Mycelium mid-game / Age-3 content depth
Zdroj: GDD §3 (uzly, plodnice, rozklad), §7 scénář Invaze roztočů; scenar_10-15.md; art `pro_v3` + `mycelium_iso_v2`.
Zrcadlo Buildu 17 (Apis). Navazuje na main po Build 15 (#19) + Build 17 (#20) + Build 18 (#22). Nezávislé na otevřených Buildech 14/16 (#21/#23).

## Cíl
- Více druhů uzlů / „budov“ u Mycelia v late mid-game / Věku 3 (ne jen jednotné plodnice a zárodky).
- Jedna mid-game událost dle GDD: **Invaze roztočů**.
- Art jen z existujících spriteů (`myc2_plodnice_*`, `myc2_zarodek_*`, `myc2_kotva_*`, `myc2_overlay_zare`, `myc_pro_brouk_infikovany`). Bez nové generace.
- Mediány wow ±15 s vůči v0.1.0, mezery ≤90 s, headless CI zelené. Merge dělá Honza.

## Budovy (role na uzlu)
| Role | Česky | Vzhled | Kdy |
|---|---|---|---|
| `fruit` | Plodnice | `myc2_plodnice_*` | výchozí fruit matter |
| `sporangium` | Výtrusnice | plodnice_zariva + `myc2_overlay_zare` | po výtrusném dešti / mid-game |
| `germ` | Zárodek | `myc2_zarodek_*` | výchozí vzdálený uzel |
| `nursery` | Líheň | zarodek_zariva + overlay | u hlavní plodnice / po purge |
| `depot` | Zásobárna živin | `myc2_kotva_zariva` + overlay | lit patch / germ po rozkladu živin |

## Událost Invaze roztočů
- Auto po náznaku cizí sítě (`WOW_MITES = 625`, ~10:25). Roztoči-drony sedí na hyfách, okolí šedne, provoz zpomalí.
- Hráč: zakrouží hnízdo roztočů → purge, živiny tečou do zásobáren, líhně se posílí.
- Pak stávající Age-3 wow beze změny: karanténa 11:10 → kostra 12:25 → obří plodnice 13:40 → Seeds 14:40 → konec 15:00.
- Invaze roztočů **není** median gate (neposouvá targets).

## Akceptace
- Headless Mycelium + Apis `ok`, mediány beze změny (±15 s), late gap ≤90 s.
- Snapshot `roleCounts` ukazuje nursery/depot/sporangium v Age 3.
- PR „Build 19 Mycelium mid-game depth“; **neslučovat**.
