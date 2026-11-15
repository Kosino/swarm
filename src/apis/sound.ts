import { DUM_DUR, DUM_FREQ, DUM_FREQ_DEEP } from "./config";

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
