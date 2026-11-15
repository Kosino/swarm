import { startMycelium } from "./mycelium";

const canvas = document.getElementById("game");
if (!(canvas instanceof HTMLCanvasElement)) {
  throw new Error("Missing #game canvas");
}

startMycelium(canvas);
