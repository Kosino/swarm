import { fmtGameTime, type WowEvent } from "./guidance";

export type DemoSpeed = 1 | 2 | 4 | 8;

export type DemoControls = {
  demo: boolean;
  speed: DemoSpeed;
  paused: boolean;
  setSpeed: (s: DemoSpeed) => void;
  togglePause: () => void;
  /** Notify a new wow (deduped by id). */
  pushWow: (ev: WowEvent) => void;
  /** Update clock + bottom guide line each frame. */
  tick: (gameTime: number, guideLabel: string | null) => void;
  destroy: () => void;
};

/** PR/Pages preview → demo ON by default; final/local OFF unless ?demo=1. */
export function resolveDemoMode(params: URLSearchParams = new URLSearchParams(location.search)): boolean {
  const d = params.get("demo");
  if (d === "1" || d === "true") return true;
  if (d === "0" || d === "false") return false;
  const path = location.pathname;
  const host = location.hostname;
  if (path.includes("/pr-preview/") || host.endsWith("github.io")) return true;
  return false;
}

export function createDemoControls(root: HTMLElement): DemoControls {
  const demo = resolveDemoMode();
  let speed: DemoSpeed = 1;
  let paused = false;
  const seen = new Set<string>();
  const wowList: WowEvent[] = [];

  // Always create lightweight controller; HUD only when demo
  let hud: HTMLElement | null = null;
  let clockEl: HTMLElement | null = null;
  let guideEl: HTMLElement | null = null;
  let wowListEl: HTMLElement | null = null;
  let toastEl: HTMLElement | null = null;
  let toastTimer = 0;
  let speedBtns: HTMLButtonElement[] = [];

  const syncSpeedBtns = () => {
    for (const b of speedBtns) {
      const s = Number(b.dataset.speed) as DemoSpeed;
      b.classList.toggle("on", s === speed && !paused);
    }
  };

  if (demo) {
    hud = document.createElement("div");
    hud.id = "demo-hud";
    hud.innerHTML = `
      <div class="demo-top">
        <div class="demo-clock" id="demo-clock">0:00</div>
        <div class="demo-speeds" id="demo-speeds">
          <button type="button" data-speed="1">1×</button>
          <button type="button" data-speed="2">2×</button>
          <button type="button" data-speed="4">4×</button>
          <button type="button" data-speed="8">8×</button>
        </div>
        <ul class="demo-wows" id="demo-wows"></ul>
      </div>
      <div class="demo-toast" id="demo-toast" hidden></div>
      <div class="demo-guide" id="demo-guide"></div>
    `;
    root.appendChild(hud);
    clockEl = hud.querySelector("#demo-clock");
    guideEl = hud.querySelector("#demo-guide");
    wowListEl = hud.querySelector("#demo-wows");
    toastEl = hud.querySelector("#demo-toast");
    speedBtns = [...hud.querySelectorAll<HTMLButtonElement>("#demo-speeds button")];
    for (const b of speedBtns) {
      b.addEventListener("click", () => {
        paused = false;
        speed = Number(b.dataset.speed) as DemoSpeed;
        syncSpeedBtns();
      });
    }
    syncSpeedBtns();
  }

  const onKey = (e: KeyboardEvent) => {
    if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return;
    if (e.code === "Space") {
      e.preventDefault();
      paused = !paused;
      syncSpeedBtns();
      return;
    }
    if (e.key === "1") {
      speed = 1;
      paused = false;
      syncSpeedBtns();
    } else if (e.key === "2") {
      speed = 2;
      paused = false;
      syncSpeedBtns();
    } else if (e.key === "3") {
      speed = 4;
      paused = false;
      syncSpeedBtns();
    } else if (e.key === "4") {
      speed = 8;
      paused = false;
      syncSpeedBtns();
    }
  };
  // Keys always work (useful even without HUD for testing with ?demo=1)
  if (demo) window.addEventListener("keydown", onKey);

  return {
    get demo() {
      return demo;
    },
    get speed() {
      return speed;
    },
    get paused() {
      return paused;
    },
    setSpeed(s) {
      speed = s;
      paused = false;
      syncSpeedBtns();
    },
    togglePause() {
      paused = !paused;
      syncSpeedBtns();
    },
    pushWow(ev) {
      if (!demo || seen.has(ev.id)) return;
      seen.add(ev.id);
      wowList.push(ev);
      if (wowListEl) {
        const li = document.createElement("li");
        li.textContent = `${ev.label} · ${fmtGameTime(ev.time)}`;
        wowListEl.appendChild(li);
      }
      if (toastEl) {
        toastEl.hidden = false;
        toastEl.textContent = `WOW · ${ev.label} · ${fmtGameTime(ev.time)}`;
        toastTimer = performance.now() + 3000;
      }
    },
    tick(gameTime, guideLabel) {
      if (!demo) return;
      if (clockEl) clockEl.textContent = fmtGameTime(gameTime);
      if (guideEl) guideEl.textContent = guideLabel ?? "";
      if (toastEl && toastTimer && performance.now() > toastTimer) {
        toastEl.hidden = true;
        toastTimer = 0;
      }
    },
    destroy() {
      if (demo) window.removeEventListener("keydown", onKey);
      hud?.remove();
    },
  };
}
