import {
  BZZ_DUR,
  BZZ_FREQ,
  CHIME_DUR,
  CHIME_FREQ,
  DUM_DUR,
  DUM_FREQ,
  DUM_FREQ_DEEP,
} from "./config";

type AC = typeof AudioContext;
let ctx: AudioContext | null = null;

function audio(): AudioContext | null {
  const g = globalThis as typeof globalThis & { webkitAudioContext?: AC };
  const ACImpl: AC | undefined =
    typeof AudioContext !== "undefined" ? AudioContext : g.webkitAudioContext;
  if (!ACImpl) return null;
  if (!ctx) ctx = new ACImpl();
  return ctx;
}

/** Single muffled buzz/dum — deeper for ring close or big flight. */
export function playDum(deep = false): void {
  const ac = audio();
  if (!ac) return;
  if (ac.state === "suspended") void ac.resume();

  const t0 = ac.currentTime;
  const freq = deep ? DUM_FREQ_DEEP : DUM_FREQ;
  const osc = ac.createOscillator();
  const gain = ac.createGain();
  const filter = ac.createBiquadFilter();

  osc.type = "sine";
  osc.frequency.setValueAtTime(freq, t0);
  osc.frequency.exponentialRampToValueAtTime(freq * 0.5, t0 + DUM_DUR);

  filter.type = "lowpass";
  filter.frequency.setValueAtTime(380, t0);
  filter.Q.setValueAtTime(0.65, t0);

  gain.gain.setValueAtTime(0.0001, t0);
  gain.gain.exponentialRampToValueAtTime(deep ? 0.2 : 0.12, t0 + 0.02);
  gain.gain.exponentialRampToValueAtTime(0.0001, t0 + DUM_DUR);

  osc.connect(filter);
  filter.connect(gain);
  gain.connect(ac.destination);
  osc.start(t0);
  osc.stop(t0 + DUM_DUR + 0.02);
}

/** Quiet short bzz on wax shortage tremor. */
export function playBzz(): void {
  const ac = audio();
  if (!ac) return;
  if (ac.state === "suspended") void ac.resume();

  const t0 = ac.currentTime;
  const osc = ac.createOscillator();
  const gain = ac.createGain();
  const filter = ac.createBiquadFilter();

  osc.type = "triangle";
  osc.frequency.setValueAtTime(BZZ_FREQ, t0);
  osc.frequency.exponentialRampToValueAtTime(BZZ_FREQ * 0.7, t0 + BZZ_DUR);

  filter.type = "bandpass";
  filter.frequency.setValueAtTime(280, t0);
  filter.Q.setValueAtTime(1.2, t0);

  gain.gain.setValueAtTime(0.0001, t0);
  gain.gain.exponentialRampToValueAtTime(0.045, t0 + 0.012);
  gain.gain.exponentialRampToValueAtTime(0.0001, t0 + BZZ_DUR);

  osc.connect(filter);
  filter.connect(gain);
  gain.connect(ac.destination);
  osc.start(t0);
  osc.stop(t0 + BZZ_DUR + 0.02);
}

/** Soft distant chime when the golden tree starts attracting. */
export function playChime(): void {
  const ac = audio();
  if (!ac) return;
  if (ac.state === "suspended") void ac.resume();

  const t0 = ac.currentTime;
  const osc = ac.createOscillator();
  const gain = ac.createGain();
  const filter = ac.createBiquadFilter();

  osc.type = "sine";
  osc.frequency.setValueAtTime(CHIME_FREQ, t0);
  osc.frequency.exponentialRampToValueAtTime(CHIME_FREQ * 1.15, t0 + CHIME_DUR * 0.4);
  osc.frequency.exponentialRampToValueAtTime(CHIME_FREQ * 0.85, t0 + CHIME_DUR);

  filter.type = "lowpass";
  filter.frequency.setValueAtTime(1400, t0);
  filter.Q.setValueAtTime(0.5, t0);

  gain.gain.setValueAtTime(0.0001, t0);
  gain.gain.exponentialRampToValueAtTime(0.06, t0 + 0.03);
  gain.gain.exponentialRampToValueAtTime(0.0001, t0 + CHIME_DUR);

  osc.connect(filter);
  filter.connect(gain);
  gain.connect(ac.destination);
  osc.start(t0);
  osc.stop(t0 + CHIME_DUR + 0.02);
}

/** Soft midgame one-shots — chamber open, copper, dual buzz, chord, cold wind. */
export function playSoft(
  kind: "open" | "copper" | "dual" | "chord" | "wind",
): void {
  const ac = audio();
  if (!ac) return;
  if (ac.state === "suspended") void ac.resume();
  const t0 = ac.currentTime;

  const tone = (freq: number, dur: number, peak: number, type: OscillatorType, lp: number) => {
    const osc = ac.createOscillator();
    const gain = ac.createGain();
    const filter = ac.createBiquadFilter();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, t0);
    osc.frequency.exponentialRampToValueAtTime(Math.max(40, freq * 0.7), t0 + dur);
    filter.type = "lowpass";
    filter.frequency.setValueAtTime(lp, t0);
    filter.Q.setValueAtTime(0.55, t0);
    gain.gain.setValueAtTime(0.0001, t0);
    gain.gain.exponentialRampToValueAtTime(peak, t0 + 0.025);
    gain.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    osc.connect(filter);
    filter.connect(gain);
    gain.connect(ac.destination);
    osc.start(t0);
    osc.stop(t0 + dur + 0.02);
  };

  if (kind === "open") {
    tone(180, 0.32, 0.06, "sine", 600);
  } else if (kind === "copper") {
    tone(96, 0.45, 0.09, "triangle", 420);
  } else if (kind === "dual") {
    tone(160, 0.4, 0.05, "triangle", 500);
    tone(210, 0.4, 0.04, "sine", 700);
  } else if (kind === "chord") {
    tone(110, 0.55, 0.07, "sine", 400);
    tone(165, 0.55, 0.05, "sine", 500);
    tone(220, 0.55, 0.04, "sine", 600);
  } else {
    tone(55, 0.6, 0.055, "sawtooth", 280);
  }
}
