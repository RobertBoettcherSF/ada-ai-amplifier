// Instantiates the wasm module, checks the stamp, and checks that the
// splash graph is the one the page draws. No imports: the module is
// linked --no-entry, without the exception runtime.
import { readFileSync } from "node:fs";

const root = new URL("..", import.meta.url);
const expected = readFileSync(new URL("version.txt", root), "utf8").trim();
const buf = readFileSync(new URL("obj/wasm/ai_amplifier.wasm", root));
if (buf[0] !== 0 || buf[1] !== 0x61 || buf[2] !== 0x73 || buf[3] !== 0x6d) {
  console.error("wasm magic missing");
  process.exit(1);
}
const imports = WebAssembly.Module.imports(new WebAssembly.Module(buf));
if (imports.length !== 0) {
  console.error("unexpected imports", imports);
  process.exit(1);
}
const { instance } = await WebAssembly.instantiate(buf, {});
const exp = instance.exports;
const length = exp.aa_version_length();
if (length !== expected.length) {
  console.error("aa_version_length", length, "expected", expected.length);
  process.exit(1);
}
let got = "";
for (let i = 1; i <= length; i += 1) {
  got += String.fromCharCode(exp.aa_version_byte(i));
}
if (got !== expected) {
  console.error("stamp bytes", JSON.stringify(got));
  process.exit(1);
}
const first = exp.aa_version_byte(0);
const last = exp.aa_version_byte(length + 9);
const below = exp.aa_version_byte(-4);
if (first !== expected.charCodeAt(0)
    || below !== expected.charCodeAt(0)
    || last !== expected.charCodeAt(expected.length - 1)) {
  console.error("clamp", first, below, last);
  process.exit(1);
}

function fail(msg) {
  console.error(msg);
  process.exit(1);
}
const need = ["aa_splash_reset", "aa_splash_tick", "aa_step", "aa_count", "aa_get"];
for (const name of need) {
  if (typeof exp[name] !== "function") fail("missing export " + name);
}

const nodes = [
  [180, 300],
  [180, 520],
  [180, 740],
  [500, 380],
  [500, 660],
  [840, 520],
];
const edges = [
  [1, 4], [1, 5], [2, 4], [2, 5], [3, 4], [3, 5], [4, 6], [5, 6],
];

exp.aa_splash_reset();
if (exp.aa_step() !== 0) fail("step after reset " + exp.aa_step());
if (exp.aa_count(0) !== 6 || exp.aa_count(1) !== 8 || exp.aa_count(2) !== 56) {
  fail("counts " + [exp.aa_count(0), exp.aa_count(1), exp.aa_count(2)]);
}
if (exp.aa_count(-1) !== 0 || exp.aa_count(9) !== 0) fail("count clamp");
if (exp.aa_get(0, 0, 0) !== 0 || exp.aa_get(0, 7, 1) !== 0
    || exp.aa_get(2, 57, 0) !== 0 || exp.aa_get(2, -3, 0) !== 0
    || exp.aa_get(4, 1, 0) !== 0) {
  fail("get clamp");
}
for (let i = 0; i < nodes.length; i += 1) {
  const x = exp.aa_get(0, i + 1, 0);
  const y = exp.aa_get(0, i + 1, 1);
  if (x !== nodes[i][0] || y !== nodes[i][1]) fail("node " + (i + 1) + " " + x + "," + y);
}
for (let i = 0; i < edges.length; i += 1) {
  const a = edges[i][0];
  const b = edges[i][1];
  const e = i + 1;
  if (exp.aa_get(1, e, 0) !== nodes[a - 1][0]
      || exp.aa_get(1, e, 1) !== nodes[a - 1][1]
      || exp.aa_get(1, e, 2) !== nodes[b - 1][0]
      || exp.aa_get(1, e, 3) !== nodes[b - 1][1]) {
    fail("edge " + e);
  }
  const w = exp.aa_get(1, e, 4);
  if (w < 50 || w > 250) fail("weight " + e + " " + w);
}
if (exp.aa_get(1, 1, 4) !== 96) fail("weight0 " + exp.aa_get(1, 1, 4));
if (exp.aa_get(0, 1, 2) !== 255) fail("pulse0 " + exp.aa_get(0, 1, 2));
if (exp.aa_get(2, 1, 0) !== 191 || exp.aa_get(2, 1, 1) !== 302) {
  fail("bead0 " + exp.aa_get(2, 1, 0) + "," + exp.aa_get(2, 1, 1));
}
if (exp.aa_get(2, 1, 2) !== 255 || exp.aa_get(2, 1, 3) !== 3) fail("bead style");
if (exp.aa_get(2, 2, 2) !== 110 || exp.aa_get(2, 2, 3) !== 2) fail("trail style");
if (exp.aa_get(2, 33, 0) !== 61 || exp.aa_get(2, 33, 1) !== 93) {
  fail("mote0 " + exp.aa_get(2, 33, 0) + "," + exp.aa_get(2, 33, 1));
}

const x0 = exp.aa_get(2, 1, 0);
const y0 = exp.aa_get(2, 1, 1);
for (let n = 0; n < 80; n += 1) exp.aa_splash_tick();
if (exp.aa_step() !== 80) fail("step " + exp.aa_step());
if (exp.aa_get(0, 1, 2) !== 70) fail("pulse80 " + exp.aa_get(0, 1, 2));
if (exp.aa_get(2, 1, 0) === x0 && exp.aa_get(2, 1, 1) === y0) fail("bead did not move");
for (let i = 1; i <= 56; i += 1) {
  const x = exp.aa_get(2, i, 0);
  const y = exp.aa_get(2, i, 1);
  const b = exp.aa_get(2, i, 2);
  const s = exp.aa_get(2, i, 3);
  if (x < 0 || x > 1000 || y < 0 || y > 1000 || b < 0 || b > 255 || (s !== 2 && s !== 3)) {
    fail("point " + i + " " + [x, y, b, s]);
  }
}
for (let i = 0; i < nodes.length; i += 1) {
  if (exp.aa_get(0, i + 1, 0) !== nodes[i][0]) fail("node drifted");
}
console.log("wasm ok", got);
