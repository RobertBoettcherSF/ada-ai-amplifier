// Instantiates the wasm module and checks the exported stamp against
// version.txt. No imports: the module is linked --no-entry.
import { readFileSync } from "node:fs";

const root = new URL("..", import.meta.url);
const expected = readFileSync(new URL("version.txt", root), "utf8").trim();
const buf = readFileSync(new URL("obj/wasm/ai_amplifier.wasm", root));
if (buf[0] !== 0 || buf[1] !== 0x61 || buf[2] !== 0x73 || buf[3] !== 0x6d) {
  console.error("wasm magic missing");
  process.exit(1);
}
const { instance } = await WebAssembly.instantiate(buf, {});
const length = instance.exports.aa_version_length();
if (length !== expected.length) {
  console.error("aa_version_length", length, "expected", expected.length);
  process.exit(1);
}
let got = "";
for (let i = 1; i <= length; i += 1) {
  got += String.fromCharCode(instance.exports.aa_version_byte(i));
}
if (got !== expected) {
  console.error("stamp bytes", JSON.stringify(got));
  process.exit(1);
}
const first = instance.exports.aa_version_byte(0);
const last = instance.exports.aa_version_byte(length + 9);
const below = instance.exports.aa_version_byte(-4);
if (first !== expected.charCodeAt(0)
    || below !== expected.charCodeAt(0)
    || last !== expected.charCodeAt(expected.length - 1)) {
  console.error("clamp", first, below, last);
  process.exit(1);
}
console.log("wasm ok", got);
