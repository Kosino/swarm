import { defineConfig } from "vite";

export default defineConfig({
  // Relative base so the same build works at repo root and in PR preview subfolders.
  base: "./",
  root: ".",
  publicDir: "public",
  build: {
    outDir: "dist",
    target: "es2022",
  },
});
