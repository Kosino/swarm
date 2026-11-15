import { startMycelium } from "./mycelium";
import { startApis } from "./apis";

const canvas = document.getElementById("game");
if (!(canvas instanceof HTMLCanvasElement)) {
  throw new Error("Missing #game canvas");
}

const params = new URLSearchParams(location.search);
const rod = (params.get("rod") ?? "mycelium").toLowerCase();

if (rod === "apis") {
  document.title = "SWARM — Apis";
  startApis(canvas);
} else {
  document.title = "SWARM — Mycelium";
  startMycelium(canvas);
}
