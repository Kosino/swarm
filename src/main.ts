import { startMycelium } from "./mycelium";
import { startApis } from "./apis";
import { START5_T as MYC_START5 } from "./mycelium/config";
import { START5_T as APIS_START5 } from "./apis/config";
import { createDemoControls } from "./core";

const canvas = document.getElementById("game");
if (!(canvas instanceof HTMLCanvasElement)) {
  throw new Error("Missing #game canvas");
}

const params = new URLSearchParams(location.search);
const rod = (params.get("rod") ?? "mycelium").toLowerCase();
const startParam = params.get("start");
const startAt =
  startParam === "5" || startParam === "5:00" ? (rod === "apis" ? APIS_START5 : MYC_START5) : undefined;

const demo = createDemoControls(document.body);

if (rod === "apis") {
  document.title = "SWARM — Apis";
  startApis(canvas, startAt, demo);
} else {
  document.title = "SWARM — Mycelium";
  startMycelium(canvas, startAt, demo);
}
