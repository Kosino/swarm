import { DUM_DUR, DUM_FREQ, DUM_FREQ_BIG } from "./config";

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

/** Single muffled synthetic “dum” — deeper for the big anchor. */
export function playDum(big = false): void {
  const ac = audio();
  if (!ac) return;
  if (ac.state === "suspended") void ac.resume();

  const t0 = ac.currentTime;
  const freq = big ? DUM_FREQ_BIG : DUM_FREQ;
  const osc = ac.createOscillator();
  const gain = ac.createGain();
  const filter = ac.createBiquadFilter();

  osc.type = "sine";
  osc.frequency.setValueAtTime(freq, t0);
  osc.frequency.exponentialRampToValueAtTime(freq * 0.45, t0 + DUM_DUR);

  filter.type = "lowpass";
  filter.frequency.setValueAtTime(420, t0);
  filter.Q.setValueAtTime(0.7, t0);

  gain.gain.setValueAtTime(0.0001, t0);
  gain.gain.exponentialRampToValueAtTime(big ? 0.22 : 0.14, t0 + 0.018);
  gain.gain.exponentialRampToValueAtTime(0.0001, t0 + DUM_DUR);

  osc.connect(filter);
  filter.connect(gain);
  gain.connect(ac.destination);
  osc.start(t0);
  osc.stop(t0 + DUM_DUR + 0.02);
}
