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

/** Single muffled synthetic “dum” — deeper for big anchor; softer for mid-wow. */
export function playDum(big = false, soft = false): void {
  const ac = audio();
  if (!ac) return;
  if (ac.state === "suspended") void ac.resume();

  const t0 = ac.currentTime;
  const freq = big ? DUM_FREQ_BIG : soft ? DUM_FREQ * 0.92 : DUM_FREQ;
  const osc = ac.createOscillator();
  const gain = ac.createGain();
  const filter = ac.createBiquadFilter();

  osc.type = "sine";
  osc.frequency.setValueAtTime(freq, t0);
  osc.frequency.exponentialRampToValueAtTime(freq * 0.45, t0 + DUM_DUR);

  filter.type = "lowpass";
  filter.frequency.setValueAtTime(soft ? 360 : 420, t0);
  filter.Q.setValueAtTime(0.7, t0);

  const peak = big ? 0.22 : soft ? 0.09 : 0.14;
  gain.gain.setValueAtTime(0.0001, t0);
  gain.gain.exponentialRampToValueAtTime(peak, t0 + 0.018);
  gain.gain.exponentialRampToValueAtTime(0.0001, t0 + DUM_DUR);

  osc.connect(filter);
  filter.connect(gain);
  gain.connect(ac.destination);
  osc.start(t0);
  osc.stop(t0 + DUM_DUR + 0.02);
}

/** Soft midgame one-shots — bubble/crack, puff, rain hush, heartbeat, dissonant hiss. */
export function playSoft(
  kind: "bubble" | "puff" | "rain" | "beat" | "hiss",
): void {
  const ac = audio();
  if (!ac) return;
  if (ac.state === "suspended") void ac.resume();
  const t0 = ac.currentTime;
  const osc = ac.createOscillator();
  const gain = ac.createGain();
  const filter = ac.createBiquadFilter();
  filter.type = "lowpass";
  filter.Q.setValueAtTime(0.6, t0);

  let freq = 90;
  let dur = 0.35;
  let peak = 0.07;
  let type: OscillatorType = "sine";
  if (kind === "bubble") {
    freq = 140;
    dur = 0.42;
    peak = 0.08;
    type = "sine";
    filter.frequency.setValueAtTime(480, t0);
  } else if (kind === "puff") {
    freq = 70;
    dur = 0.28;
    peak = 0.06;
    type = "triangle";
    filter.frequency.setValueAtTime(320, t0);
  } else if (kind === "rain") {
    freq = 220;
    dur = 0.55;
    peak = 0.045;
    type = "triangle";
    filter.frequency.setValueAtTime(900, t0);
  } else if (kind === "beat") {
    freq = 58;
    dur = 0.5;
    peak = 0.1;
    type = "sine";
    filter.frequency.setValueAtTime(280, t0);
  } else {
    freq = 310;
    dur = 0.22;
    peak = 0.05;
    type = "sawtooth";
    filter.frequency.setValueAtTime(700, t0);
  }

  osc.type = type;
  osc.frequency.setValueAtTime(freq, t0);
  osc.frequency.exponentialRampToValueAtTime(Math.max(30, freq * 0.55), t0 + dur);
  gain.gain.setValueAtTime(0.0001, t0);
  gain.gain.exponentialRampToValueAtTime(peak, t0 + 0.02);
  gain.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
  osc.connect(filter);
  filter.connect(gain);
  gain.connect(ac.destination);
  osc.start(t0);
  osc.stop(t0 + dur + 0.02);
}
