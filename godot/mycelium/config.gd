## Build #1–#5 mycelium params — 1:1 with src/mycelium/config.ts
class_name MyceliumConfig
extends RefCounted

const W := 1000
const H := 640
const SPEED := 10.0
const STEP := 7.0
const MAXTIPS := 20
const BRANCH_P := 0.005
const SENSE := 70.0
const GUIDE_R := 150.0
const SEED_CLEAR := 200.0

const FUSION_R := 8.0
const FUSION_MIN_T := 120.0
const FUSION_COOLDOWN := 0.35
const HOLD_S := 0.6
const HOLD_R := 150.0
const HOLD_SPEED_MUL := 2.4
const HOLD_BRANCH_MUL := 3.5
const HOLD_STEER := 1.8
const WORKER_MIN_SEGS := 1500
const WORKER_DELAY := 78.0
const MAX_WORKERS := 150
const WORKER_SPAWN_RATE := 0.75
const WORKER_SPEED := 55.0
const BIG_APPEAR_T := 235.0
const BIG_R := 32.0
const BIG_EDGE := 48.0
## Presentational zoom — colony ~60% of frame; mechanics/timing unchanged.
const CAM_ZOOM_IN := 2.15
const CAM_ZOOM_OUT := 1.35
const CAM_ZOOM_DUR := 2.8
const DUM_FREQ := 108.0
const DUM_FREQ_BIG := 52.0
const DUM_DUR := 0.28

const START5_T := 280.0
const ENC_MIN_LEN := 140.0
const ENC_CLOSE_R := 36.0
const ENC_MIN_PTS := 10
const MATTER_R_MACHINE := 28.0
const MATTER_R_BEETLE := 36.0
const MATTER_SLIDE_R := 1.15
const WOW_DECAY := 345.0
const WOW_FRUIT := 420.0
const WOW_SPORE := 495.0
const WOW_JOIN := 560.0
const WOW_HINT := 600.0
## Mid-game mite invasion (GDD „Invaze roztočů“) — between hint and quarantine; not a median gate.
const WOW_MITES := 625.0
## Age 3 / minutes 10–15 (Build #9)
const WOW_QUARANTINE := 670.0
const WOW_SKELETON := 745.0
const WOW_GIANT := 820.0
const WOW_SEEDS := 880.0
const WOW_END := 900.0
const START10_T := 600.0
const SPORE_GERMS := 4
const JOIN_PULSE_PERIOD := 1.85
const HINT_DUR := 3.2
const INFECT_R := 48.0
const SKELETON_R := 58.0
const GIANT_FRUIT_R := 72.0
const HOLD_AGE3_S := 0.55
const MITE_NEST_R := 36.0
## Age-3 building roles (visual specialization; timing unchanged).
const ROLE_FRUIT := "fruit"
const ROLE_SPORANGIUM := "sporangium"
const ROLE_GERM := "germ"
const ROLE_NURSERY := "nursery"
const ROLE_DEPOT := "depot"
const ROLE_ANCHOR := "anchor"

const SOIL_TILE := 64
const IDLE_GHOST_S := 8.0
const MAX_GHOST_PERFORMS := 2
