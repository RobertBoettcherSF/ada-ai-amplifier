// Instantiates the wasm module, checks the stamp, and checks that the
// splash graph is the one the page draws. No imports: the module is
// linked --no-entry, without the exception runtime.
import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";

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
const need = ["aa_splash_reset", "aa_splash_tick", "aa_step", "aa_count", "aa_get",
  "aa_set_m", "aa_get_m", "aa_set_v", "aa_get_v", "aa_tensor_run", "aa_product", "aa_softmax",
  "aa_lrelu_set", "aa_lrelu_in", "aa_lrelu_run", "aa_lrelu_out", "aa_lrelu_slope"];
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

function near(got, want, tol) {
  return Math.abs(got - want) <= tol;
}
const matrix = [1, 2, 3, 0, 1, 4, 5, 6, 0];
for (let i = 0; i < matrix.length; i += 1) {
  const g = exp.aa_get_m(Math.floor(i / 3) + 1, (i % 3) + 1);
  if (g !== matrix[i]) fail("matrix " + i + " " + g);
}
if (exp.aa_get_v(1) !== 1 || exp.aa_get_v(2) !== 2 || exp.aa_get_v(3) !== 3) {
  fail("vector " + [exp.aa_get_v(1), exp.aa_get_v(2), exp.aa_get_v(3)]);
}
if (exp.aa_get_m(0, 1) !== 0 || exp.aa_get_v(4) !== 0 || exp.aa_product(0) !== 0) {
  fail("tensor clamp");
}
exp.aa_tensor_run();
if (exp.aa_product(1) !== 14 || exp.aa_product(2) !== 14 || exp.aa_product(3) !== 17) {
  fail("product " + [exp.aa_product(1), exp.aa_product(2), exp.aa_product(3)]);
}
const s1 = exp.aa_softmax(1);
const s2 = exp.aa_softmax(2);
const s3 = exp.aa_softmax(3);
if (!near(s1, 0.0452785, 2e-4) || !near(s2, s1, 1e-6) || !near(s3, 0.909443, 2e-4)) {
  fail("softmax " + [s1, s2, s3]);
}
if (!near(s1 + s2 + s3, 1, 1e-5)) fail("softmax sum " + (s1 + s2 + s3));
exp.aa_set_v(3, 0);
exp.aa_tensor_run();
if (exp.aa_product(1) !== 5 || exp.aa_product(2) !== 2 || exp.aa_product(3) !== 17) {
  fail("edited product " + [exp.aa_product(1), exp.aa_product(2), exp.aa_product(3)]);
}
const id = [1, 0, 0, 0, 1, 0, 0, 0, 1];
for (let i = 0; i < id.length; i += 1) {
  exp.aa_set_m(Math.floor(i / 3) + 1, (i % 3) + 1, id[i]);
}
exp.aa_set_v(1, 1000);
exp.aa_set_v(2, 1000);
exp.aa_set_v(3, 1000);
exp.aa_tensor_run();
if (exp.aa_product(1) !== 1000 || exp.aa_product(2) !== 1000 || exp.aa_product(3) !== 1000) {
  fail("identity " + [exp.aa_product(1), exp.aa_product(2), exp.aa_product(3)]);
}
const h1 = exp.aa_softmax(1);
const h2 = exp.aa_softmax(2);
const h3 = exp.aa_softmax(3);
if (!near(h1, 1 / 3, 1e-5) || !near(h2, 1 / 3, 1e-5) || !near(h3, 1 / 3, 1e-5)) {
  fail("large softmax " + [h1, h2, h3]);
}

const slope = exp.aa_lrelu_slope();
if (!near(slope, 0.01, 1e-6)) fail("lrelu slope " + slope);
if (exp.aa_lrelu_in(1) !== -2 || exp.aa_lrelu_in(2) !== 0 || exp.aa_lrelu_in(3) !== 3) {
  fail("lrelu in " + [exp.aa_lrelu_in(1), exp.aa_lrelu_in(2), exp.aa_lrelu_in(3)]);
}
if (exp.aa_lrelu_in(0) !== 0 || exp.aa_lrelu_out(4) !== 0) fail("lrelu clamp");
exp.aa_lrelu_run();
if (!near(exp.aa_lrelu_out(1), slope * -2, 1e-6) || exp.aa_lrelu_out(2) !== 0 || exp.aa_lrelu_out(3) !== 3) {
  fail("lrelu out " + [exp.aa_lrelu_out(1), exp.aa_lrelu_out(2), exp.aa_lrelu_out(3)]);
}
exp.aa_lrelu_set(1, 4);
exp.aa_lrelu_set(0, 9);
exp.aa_lrelu_run();
if (exp.aa_lrelu_out(1) !== 4 || exp.aa_lrelu_in(1) !== 4) fail("lrelu edited");

const mlpNeed = ["aa_mlp_reset", "aa_mlp_set_rate", "aa_mlp_rate", "aa_mlp_train", "aa_mlp_epoch", "aa_mlp_loss", "aa_mlp_predict", "aa_mlp_count", "aa_mlp_x", "aa_mlp_y", "aa_mlp_label", "aa_mlp_lo", "aa_mlp_hi", "aa_mlp_grid_n", "aa_mlp_fill", "aa_mlp_cell", "aa_mlp_curve_n", "aa_mlp_curve", "aa_mlp_kind"];
for (const name of mlpNeed) {
  if (typeof exp[name] !== "function") fail("missing export " + name);
}
exp.aa_mlp_reset(0);
exp.aa_mlp_set_rate(1);
if (exp.aa_mlp_kind() !== 0 || exp.aa_mlp_count() !== 4 || exp.aa_mlp_epoch() !== 0) {
  fail("mlp reset " + [exp.aa_mlp_kind(), exp.aa_mlp_count(), exp.aa_mlp_epoch()]);
}
const labels = [0, 1, 1, 0];
for (let i = 0; i < 4; i += 1) {
  if (exp.aa_mlp_label(i + 1) !== labels[i]) fail("mlp label " + i);
}
let loss = exp.aa_mlp_loss();
if (!(loss > 0.2 && loss < 1.5)) fail("mlp init loss " + loss);
if (exp.aa_mlp_curve_n() < 1 || !near(exp.aa_mlp_curve(1), loss, 1e-5)) fail("mlp curve");
for (let n = 0; n < 20 && loss >= 0.05; n += 1) loss = exp.aa_mlp_train(32);
if (loss >= 0.05) fail("mlp xor loss " + loss);
const outs = [];
for (let i = 1; i <= 4; i += 1) outs.push(exp.aa_mlp_predict(exp.aa_mlp_x(i), exp.aa_mlp_y(i)));
if (!(outs[0] < 0.2 && outs[1] > 0.8 && outs[2] > 0.8 && outs[3] < 0.2)) {
  fail("mlp xor outs " + outs);
}
exp.aa_mlp_fill();
if (exp.aa_mlp_grid_n() !== 48) fail("grid " + exp.aa_mlp_grid_n());
const lo = exp.aa_mlp_lo();
const hi = exp.aa_mlp_hi();
const span = (hi - lo) / 48;
if (!near(exp.aa_mlp_cell(1, 1), exp.aa_mlp_predict(lo + 0.5 * span, hi - 0.5 * span), 1e-5)) {
  fail("grid corner");
}
if (exp.aa_mlp_cell(0, 1) !== 0 || exp.aa_mlp_x(0) !== 0 || exp.aa_mlp_curve(0) !== 0) {
  fail("mlp clamp");
}
exp.aa_mlp_set_rate(0);
if (!near(exp.aa_mlp_rate(), 1, 1e-5)) fail("rate 0 stuck " + exp.aa_mlp_rate());
exp.aa_mlp_set_rate(0.25);
if (!near(exp.aa_mlp_rate(), 0.25, 1e-6)) fail("rate " + exp.aa_mlp_rate());
const epoch = exp.aa_mlp_epoch();
exp.aa_mlp_train(1000);
if (exp.aa_mlp_epoch() !== epoch + 32) fail("step cap " + exp.aa_mlp_epoch());
exp.aa_mlp_reset(1);
if (exp.aa_mlp_kind() !== 1 || exp.aa_mlp_count() !== 72 || exp.aa_mlp_epoch() !== 0) fail("circles");
if (!near(exp.aa_mlp_rate(), 0.25, 1e-6)) fail("rate not kept");
exp.aa_mlp_reset(2);
if (exp.aa_mlp_kind() !== 2 || exp.aa_mlp_count() !== 96) fail("spirals");
exp.aa_mlp_reset(9);
if (exp.aa_mlp_kind() !== 0 || exp.aa_mlp_count() !== 4) fail("unknown dataset");

const wNeed = ["aa_w_limit", "aa_w_span", "aa_w_count", "aa_w_get", "aa_w_set", "aa_w_name_len", "aa_w_name_byte", "aa_w_len", "aa_w_byte", "aa_w_clear", "aa_w_push", "aa_w_load", "aa_w_hand", "aa_w_trained", "aa_w_preset", "aa_w_note_len", "aa_w_note_byte"];
for (const name of wNeed) {
  if (typeof exp[name] !== "function") fail("missing export " + name);
}
if (exp.aa_w_count() !== 33 || exp.aa_w_limit() !== 1000 || exp.aa_w_span() !== 12) {
  fail("weight census " + [exp.aa_w_count(), exp.aa_w_limit(), exp.aa_w_span()]);
}
if (exp.aa_w_get(0) !== 0 || exp.aa_w_name_len(0) !== 0 || exp.aa_w_name_byte(1, 0) !== 0) {
  fail("weight clamp");
}
let hname = "";
for (let i = 1; i <= exp.aa_w_name_len(1); i += 1) hname += String.fromCharCode(exp.aa_w_name_byte(1, i));
if (hname !== "h1.x1") fail("weight name " + hname);
exp.aa_w_hand();
const hand = [];
for (let i = 1; i <= 4; i += 1) hand.push(exp.aa_mlp_predict(exp.aa_mlp_x(i), exp.aa_mlp_y(i)));
if (!(hand[0] < 0.2 && hand[1] > 0.8 && hand[2] > 0.8 && hand[3] < 0.2)) fail("hand xor " + hand);
if (exp.aa_mlp_epoch() !== 0) fail("hand epoch " + exp.aa_mlp_epoch());
const kept = exp.aa_w_get(1);
if (exp.aa_w_set(1, 1001) !== 1 || exp.aa_w_get(1) !== kept) fail("weight limit");
if (exp.aa_w_set(1, 1.5) !== 0 || !near(exp.aa_w_get(1), 1.5, 1e-6)) fail("weight set");
exp.aa_w_trained();
if (near(exp.aa_w_get(1), 1.5, 1e-6)) fail("trained did not restore");
const wn = exp.aa_w_len();
if (wn < 50 || exp.aa_w_byte(0) !== 0) fail("export " + wn);
let wtext = "";
for (let i = 1; i <= wn; i += 1) wtext += String.fromCharCode(exp.aa_w_byte(i));
if (!wtext.includes("shape 2 8 1") || !wtext.includes("hidden 1")) fail("weight text");
exp.aa_w_set(1, 0);
exp.aa_w_clear();
exp.aa_w_push(300);
for (let i = 0; i < wtext.length; i += 1) exp.aa_w_push(wtext.charCodeAt(i));
if (exp.aa_w_load() !== 0) fail("reload " + exp.aa_w_load());
exp.aa_w_clear();
const badShape = "ada-ai-amplifier weights 1\nshape 2 4 1\n";
for (let i = 0; i < badShape.length; i += 1) exp.aa_w_push(badShape.charCodeAt(i));
if (exp.aa_w_load() !== 1) fail("bad shape " + exp.aa_w_load());
exp.aa_w_hand();
const before = exp.aa_mlp_predict(0, 1);
exp.aa_w_preset(1);
if (!(before > 0.8) || !(exp.aa_mlp_predict(0, 1) < 0.2)) fail("flip preset");

const attnNeed = ["aa_bpe_clear", "aa_bpe_push", "aa_bpe_corpus", "aa_attn_run", "aa_attn_tokens", "aa_attn_id", "aa_attn_piece_len", "aa_attn_piece_byte", "aa_attn_vocab", "aa_attn_merges", "aa_attn_used", "aa_attn_weight", "aa_attn_dropped", "aa_attn_bytes"];
for (const name of attnNeed) {
  if (typeof exp[name] !== "function") fail("missing export " + name);
}
if (exp.aa_bpe_corpus() !== 563 || exp.aa_attn_merges() !== 32 || exp.aa_attn_vocab() !== 288) {
  fail("bpe census " + [exp.aa_bpe_corpus(), exp.aa_attn_merges(), exp.aa_attn_vocab()]);
}
exp.aa_bpe_clear();
if (exp.aa_attn_run() !== 0 || exp.aa_attn_tokens() !== 0 || exp.aa_attn_used() !== 0) {
  fail("attn empty");
}
if (exp.aa_attn_id(1) !== 0 || exp.aa_attn_weight(1, 1) !== 0 || exp.aa_attn_piece_byte(1, 1) !== 0) {
  fail("attn clamp");
}
function pushText(text) {
  exp.aa_bpe_clear();
  const bytes = new TextEncoder().encode(text);
  for (const b of bytes) exp.aa_bpe_push(b);
  return exp.aa_attn_run();
}
function pulledBytes() {
  const out = [];
  const n = exp.aa_attn_tokens();
  for (let i = 1; i <= n; i += 1) {
    const len = exp.aa_attn_piece_len(i);
    for (let j = 1; j <= len; j += 1) out.push(exp.aa_attn_piece_byte(i, j) & 255);
  }
  return out;
}
function sameBytes(text) {
  const want = Array.from(new TextEncoder().encode(text));
  const gotBytes = pulledBytes();
  if (want.length !== gotBytes.length) return false;
  for (let i = 0; i < want.length; i += 1) if (want[i] !== gotBytes[i]) return false;
  return true;
}
if (pushText("hi") < 1 || !sameBytes("hi")) fail("wasm hi");
if (pushText("") !== 0) fail("wasm blank");
if (pushText("äß") < 2 || !sameBytes("äß")) fail("wasm umlauts");
exp.aa_bpe_clear();
exp.aa_bpe_push(0xc3);
exp.aa_bpe_push(0x9f);
if (exp.aa_attn_run() !== 1) fail("wasm eszett count " + exp.aa_attn_tokens());
if ((exp.aa_attn_piece_byte(1, 1) & 255) !== 0xc3 || (exp.aa_attn_piece_byte(1, 2) & 255) !== 0x9f) {
  fail("wasm eszett bytes");
}
exp.aa_bpe_clear();
exp.aa_bpe_push(0xc3);
exp.aa_bpe_push(0xa4);
if (exp.aa_attn_run() !== 2 || exp.aa_attn_id(1) !== 0xc3 || exp.aa_attn_id(2) !== 0xa4) {
  fail("wasm a-umlaut " + [exp.aa_attn_tokens(), exp.aa_attn_id(1), exp.aa_attn_id(2)]);
}
const nAttn = pushText("Alice was beginning süß");
if (nAttn !== 15 || exp.aa_attn_used() !== 15) fail("wasm phrase " + nAttn + " " + exp.aa_attn_used());
if (!sameBytes("Alice was beginning süß")) fail("wasm phrase bytes");
for (let i = 1; i <= 15; i += 1) {
  let sum = 0;
  for (let j = 1; j <= 15; j += 1) {
    const w = exp.aa_attn_weight(i, j);
    if (j > i && w !== 0) fail("wasm future " + i + " " + j);
    sum += w;
  }
  if (Math.abs(sum - 1) > 1e-4) fail("wasm row " + i + " " + sum);
}
if (exp.aa_attn_weight(1, 2) !== 0) fail("wasm mask");
exp.aa_bpe_clear();
exp.aa_bpe_push(-1);
exp.aa_bpe_push(256);
exp.aa_bpe_push(65);
if (exp.aa_attn_bytes() !== 1 || exp.aa_attn_run() !== 1 || exp.aa_attn_id(1) !== 65) {
  fail("wasm push filter");
}
exp.aa_bpe_clear();
for (let i = 0; i < 771; i += 1) exp.aa_bpe_push(97);
if (exp.aa_attn_bytes() !== 768 || exp.aa_attn_dropped() !== 3) {
  fail("wasm dropped " + exp.aa_attn_bytes() + " " + exp.aa_attn_dropped());
}
const longN = exp.aa_attn_run();
if (longN < 1 || exp.aa_attn_used() > 16 || exp.aa_attn_used() < 1) fail("wasm long " + longN);

const recNeed = ["aa_rec_chains", "aa_rec_max_index", "aa_rec_select", "aa_rec_name_len", "aa_rec_name_byte", "aa_rec_states", "aa_rec_line_len", "aa_rec_line_byte", "aa_rec_mark", "aa_rec_parsed", "aa_rec_index", "aa_rec_minus", "aa_rec_current", "aa_rec_stop", "aa_rec_stop_len", "aa_rec_stop_byte", "aa_rec_stop_at", "aa_rec_accepted", "aa_rec_answer", "aa_rec_note_len", "aa_rec_note_byte"];
for (const name of recNeed) {
  if (typeof exp[name] !== "function") fail("missing export " + name);
}
function recText(lenFn, byteFn) {
  const n = lenFn();
  let s = "";
  for (let i = 1; i <= n; i += 1) s += String.fromCharCode(byteFn(i) & 255);
  return s;
}
if (exp.aa_rec_chains() !== 4 || exp.aa_rec_max_index() !== 20) {
  fail("wasm rec census " + exp.aa_rec_chains() + " " + exp.aa_rec_max_index());
}
//  This link has no binder, so the demo's elaboration block does
//  not run. The page selects a chain before it reads one.
exp.aa_rec_select(1);
if (exp.aa_rec_answer() !== 8 || exp.aa_rec_accepted() !== 6 || exp.aa_rec_stop() !== 0) {
  fail("wasm rec chain 1 " + [exp.aa_rec_answer(), exp.aa_rec_accepted(), exp.aa_rec_stop()]);
}
const recBefore = exp.aa_rec_answer();
exp.aa_rec_select(0);
exp.aa_rec_select(9);
if (exp.aa_rec_answer() !== recBefore) fail("wasm rec bad select");
if (exp.aa_rec_states() !== 7 || exp.aa_rec_index(7) !== 0 || exp.aa_rec_minus(7) !== 8 || exp.aa_rec_current(7) !== 13) {
  fail("wasm rec fib6 " + [exp.aa_rec_states(), exp.aa_rec_index(7), exp.aa_rec_minus(7), exp.aa_rec_current(7)]);
}
if (exp.aa_rec_mark(7) !== 1 || exp.aa_rec_parsed(7) !== 1) fail("wasm rec base mark");
if (recText(() => exp.aa_rec_name_len(), (i) => exp.aa_rec_name_byte(i)) !== "fib-6-complete") {
  fail("wasm rec name");
}
const note = recText(() => exp.aa_rec_note_len(), (i) => exp.aa_rec_note_byte(i));
if (!note.includes("minus-one is 8 after 6 accepted steps")) fail("wasm rec note " + note);
if (exp.aa_rec_line_byte(1, 0) !== 0 || exp.aa_rec_name_byte(0) !== 0 || exp.aa_rec_index(0) !== 0) {
  fail("wasm rec clamp");
}
exp.aa_rec_select(2);
if (exp.aa_rec_stop() !== 4 || exp.aa_rec_stop_at() !== 4 || exp.aa_rec_current(4) !== 4 || exp.aa_rec_accepted() !== 2) {
  fail("wasm rec sum");
}
exp.aa_rec_select(3);
if (exp.aa_rec_stop() !== 3 || exp.aa_rec_index(2) !== 4) fail("wasm rec stall");
exp.aa_rec_select(4);
if (exp.aa_rec_stop() !== 1 || exp.aa_rec_parsed(3) !== 0) fail("wasm rec garbled");
const halt = recText(() => exp.aa_rec_line_len(3), (i) => exp.aa_rec_line_byte(3, i));
if (halt !== "unreadable  halt") fail("wasm rec halt line " + halt);
const speedNeed = ["aa_speed_prepare", "aa_speed_execute", "aa_speed_finish", "aa_speed_steps", "aa_speed_repeats", "aa_speed_us", "aa_speed_loss", "aa_speed_answer", "aa_speed_counted", "aa_speed_reason", "aa_speed_published_steps", "aa_speed_published_native_us", "aa_speed_published_wasm_us", "aa_speed_len", "aa_speed_byte", "aa_speed_describe"];
for (const name of speedNeed) {
  if (typeof exp[name] !== "function") fail("missing " + name);
}
function speedText() {
  let s = "";
  const n = exp.aa_speed_len();
  for (let i = 1; i <= n; i += 1) s += String.fromCharCode(exp.aa_speed_byte(i));
  return s;
}
function runSpeed(kind) {
  exp.aa_speed_prepare(kind);
  const t0 = performance.now();
  exp.aa_speed_execute();
  const t1 = performance.now();
  exp.aa_speed_finish(t0, t1);
  return speedText();
}
if (exp.aa_speed_published_steps() !== 95 || exp.aa_speed_repeats() !== 8) {
  fail("yardstick " + exp.aa_speed_published_steps() + " " + exp.aa_speed_repeats());
}
if (exp.aa_speed_answer(0) !== 0 || exp.aa_speed_byte(0) !== 0) fail("speed clamp");
const speedBase = runSpeed(1);
const speedBaseUs = exp.aa_speed_us();
if (exp.aa_speed_counted() !== 1 || speedBaseUs <= 0 || exp.aa_speed_loss() >= 0.05) {
  fail("speed base " + speedBase);
}
const speedOut = [];
for (let i = 1; i <= 4; i += 1) speedOut.push(exp.aa_speed_answer(i));
if (!(speedOut[1] >= 0.8 && speedOut[2] >= 0.8 && speedOut[0] <= 0.2 && speedOut[3] <= 0.2)) {
  fail("speed answers " + speedOut);
}
const speedFast = runSpeed(2);
const speedFastUs = exp.aa_speed_us();
if (exp.aa_speed_counted() !== 1 || speedFastUs <= 0 || speedFastUs >= speedBaseUs) {
  fail("speed fast " + speedFastUs + " base " + speedBaseUs + " " + speedFast);
}
if (!speedFast.includes("times the baseline")) fail("speed ratio " + speedFast);
const speedOutside = runSpeed(3);
if (exp.aa_speed_counted() !== 0 || exp.aa_speed_reason() !== 3 || exp.aa_speed_us() !== 0) {
  fail("speed outside " + speedOutside);
}
if (!speedOutside.includes("does not count") || exp.aa_speed_loss() >= 0.05) {
  fail("speed outside answers " + speedOutside);
}
const speedSkip = runSpeed(4);
if (exp.aa_speed_reason() !== 4 || !speedSkip.includes("does not count")) {
  fail("speed skip " + speedSkip);
}
const speedEasier = runSpeed(5);
if (exp.aa_speed_reason() !== 5 || !speedEasier.includes("does not count")) {
  fail("speed easier " + speedEasier);
}
exp.aa_speed_prepare(9);
exp.aa_speed_execute();
exp.aa_speed_finish(1, 1);
if (exp.aa_speed_reason() !== 7) fail("speed unknown " + speedText());
exp.aa_speed_prepare(1);
exp.aa_speed_execute();
exp.aa_speed_finish(5, 5);
if (exp.aa_speed_reason() !== 6) fail("speed clock " + speedText());
exp.aa_speed_describe();
if (!speedText().includes("95")) fail("speed blurb " + speedText());
console.log("speed wasm baseline_us", speedBaseUs, "faster_us", speedFastUs);
const trNeed = ["aa_tr_count", "aa_tr_select", "aa_tr_name_len", "aa_tr_name_byte", "aa_tr_steps", "aa_tr_line_len", "aa_tr_line_byte", "aa_tr_wrong", "aa_tr_menu", "aa_tr_menu_len", "aa_tr_menu_byte", "aa_tr_propose", "aa_tr_verdict", "aa_tr_reason", "aa_tr_reason_len", "aa_tr_reason_byte", "aa_tr_report_len", "aa_tr_report_byte", "aa_tr_good_len", "aa_tr_good_byte", "aa_tr_state_len", "aa_tr_state_byte"];
for (const name of trNeed) {
  if (typeof exp[name] !== "function") fail("missing export " + name);
}
function trText(lenFn, byteFn) {
  const n = lenFn();
  let s = "";
  for (let i = 1; i <= n; i += 1) s += String.fromCharCode(byteFn(i));
  return s;
}
if (exp.aa_tr_count() !== 4 || exp.aa_tr_menu() !== 10) {
  fail("wasm tr census " + exp.aa_tr_count() + " " + exp.aa_tr_menu());
}
exp.aa_tr_select(1);
if (exp.aa_tr_steps() !== 3 || exp.aa_tr_wrong(3) !== 1 || exp.aa_tr_wrong(1) !== 0) {
  fail("wasm tr shape " + [exp.aa_tr_steps(), exp.aa_tr_wrong(3)]);
}
const trState = trText(() => exp.aa_tr_state_len(), (i) => exp.aa_tr_state_byte(i));
if (!trState.includes("xor missed")) fail("wasm tr state " + trState);
const trGood = trText(() => exp.aa_tr_good_len(), (i) => exp.aa_tr_good_byte(i));
if (!trGood.includes("fixes-it") || !trGood.includes("xor-returned")) fail("wasm tr good " + trGood);
exp.aa_tr_propose(9);
if (exp.aa_tr_verdict() !== 3 || exp.aa_tr_reason() !== 4) {
  fail("wasm tr invert " + [exp.aa_tr_verdict(), exp.aa_tr_reason()]);
}
const trBad = trText(() => exp.aa_tr_report_len(), (i) => exp.aa_tr_report_byte(i));
if (!trBad.includes("makes-it-worse") || !trBad.includes("loss-rose")) fail("wasm tr bad " + trBad);
exp.aa_tr_propose(1);
if (exp.aa_tr_verdict() !== 1 || exp.aa_tr_reason() !== 1) {
  fail("wasm tr fix " + [exp.aa_tr_verdict(), exp.aa_tr_reason()]);
}
exp.aa_tr_propose(0);
if (exp.aa_tr_verdict() !== 2 || exp.aa_tr_reason() !== 7) fail("wasm tr code 0");
const trKept = exp.aa_tr_verdict();
exp.aa_tr_select(0);
if (exp.aa_tr_verdict() !== trKept) fail("wasm tr bad select");
exp.aa_tr_select(2);
exp.aa_tr_propose(3);
if (exp.aa_tr_verdict() !== 2 || exp.aa_tr_reason() !== 5) {
  fail("wasm tr zeros " + [exp.aa_tr_verdict(), exp.aa_tr_reason()]);
}
if (exp.aa_tr_line_byte(1, 0) !== 0 || exp.aa_tr_name_byte(0) !== 0) fail("wasm tr clamp");
const auNeed = ["aa_au_run", "aa_au_count", "aa_au_flagged", "aa_au_mark", "aa_au_line_len", "aa_au_line_byte", "aa_au_stat_len", "aa_au_stat_byte", "aa_au_full_len", "aa_au_full_byte", "aa_au_clean_len", "aa_au_clean_byte"];
for (const name of auNeed) {
  if (typeof exp[name] !== "function") fail("missing export " + name);
}
function auText(len, byte) {
  const n = len();
  let s = "";
  for (let i = 1; i <= n; i += 1) s += String.fromCharCode(byte(i) & 255);
  return s;
}
exp.aa_au_run();
if (exp.aa_au_count() !== 20 || exp.aa_au_flagged() !== 5) {
  fail("wasm audit census " + exp.aa_au_count() + " " + exp.aa_au_flagged());
}
if (exp.aa_au_mark(0) !== 0 || exp.aa_au_line_byte(1, 0) !== 0) fail("wasm audit clamp");
const auFull = auText(() => exp.aa_au_full_len(), (i) => exp.aa_au_full_byte(i));
const auClean = auText(() => exp.aa_au_clean_len(), (i) => exp.aa_au_clean_byte(i));
const auStat = auText(() => exp.aa_au_stat_len(), (i) => exp.aa_au_stat_byte(i));
if (auFull !== "Full set: 14 of 20. Not accepted: audit-flagged.") fail("wasm audit full " + auFull);
if (auClean !== "Cleaned set: 9 of 15. Accepted.") fail("wasm audit clean " + auClean);
if (auStat !== "20 tasks. 5 flagged before scoring.") fail("wasm audit stat " + auStat);
const auRules = ["wrong-expected", "unsolvable", "duplicate", "accept-anything", "answer-leaked"];
let auPass = 0;
let auFlag = 0;
for (let i = 1; i <= 20; i += 1) {
  const line = auText(() => exp.aa_au_line_len(i), (p) => exp.aa_au_line_byte(i, p));
  if (exp.aa_au_mark(i) === 0) {
    auPass += 1;
    if (!line.includes("  pass")) fail("wasm audit pass " + line);
  } else {
    auFlag += 1;
    if (exp.aa_au_mark(i) !== 1 || !line.includes("  flag  ")) fail("wasm audit flag " + line);
  }
}
if (auPass !== 15 || auFlag !== 5) fail("wasm audit marks " + auPass + " " + auFlag);
const auJoined = Array.from({length: 20}, (_, k) => auText(() => exp.aa_au_line_len(k + 1), (p) => exp.aa_au_line_byte(k + 1, p))).join("\n");
for (const rule of auRules) {
  if (!auJoined.includes(rule)) fail("wasm audit missing " + rule);
}
const rwNeed = ["aa_rw_run", "aa_rw_count", "aa_rw_cols", "aa_rw_col_len", "aa_rw_col_byte", "aa_rw_mark", "aa_rw_tally_len", "aa_rw_tally_byte", "aa_rw_stat_len", "aa_rw_stat_byte", "aa_rw_steps", "aa_rw_flawed_proxy", "aa_rw_flawed_real", "aa_rw_flawed_holds", "aa_rw_real_proxy", "aa_rw_real_score", "aa_rw_real_holds", "aa_rw_flawed_end_len", "aa_rw_flawed_end_byte", "aa_rw_real_end_len", "aa_rw_real_end_byte"];
for (const name of rwNeed) {
  if (typeof exp[name] !== "function") fail("missing export " + name);
}
function rwText(len, byte) {
  const n = len();
  let s = "";
  for (let i = 1; i <= n; i += 1) s += String.fromCharCode(byte(i) & 255);
  return s;
}
exp.aa_rw_run();
if (exp.aa_rw_count() !== 5 || exp.aa_rw_cols() !== 5 || exp.aa_rw_steps() !== 121) {
  fail("wasm reward census " + exp.aa_rw_count() + " " + exp.aa_rw_cols() + " " + exp.aa_rw_steps());
}
if (exp.aa_rw_col_byte(0, 0, 1) !== 0 || exp.aa_rw_mark(0) !== 0 || exp.aa_rw_flawed_proxy(0) !== 0) {
  fail("wasm reward clamp");
}
const rwGaps = ["none", "reported-loss", "constant-half", "two-of-four", "right-stamp"];
const rwReals = ["1.00", "0.00", "0.00", "0.50", "0.00"];
for (let i = 1; i <= 5; i += 1) {
  const gap = rwText(() => exp.aa_rw_col_len(i, 5), (p) => exp.aa_rw_col_byte(i, 5, p));
  const real = rwText(() => exp.aa_rw_col_len(i, 3), (p) => exp.aa_rw_col_byte(i, 3, p));
  const flawed = rwText(() => exp.aa_rw_col_len(i, 2), (p) => exp.aa_rw_col_byte(i, 2, p));
  if (gap !== rwGaps[i - 1] || real !== rwReals[i - 1] || flawed !== "1.00") {
    fail("wasm reward row " + i + " " + flawed + " " + real + " " + gap);
  }
  if (exp.aa_rw_mark(i) !== (i === 1 ? 1 : 0)) fail("wasm reward mark " + i);
}
const rwTally = rwText(() => exp.aa_rw_tally_len(), (i) => exp.aa_rw_tally_byte(i));
const rwFlawedEnd = rwText(() => exp.aa_rw_flawed_end_len(), (i) => exp.aa_rw_flawed_end_byte(i));
const rwRealEnd = rwText(() => exp.aa_rw_real_end_len(), (i) => exp.aa_rw_real_end_byte(i));
if (rwTally !== "Accepted: 1 of 5. Only the real check counts.") fail("wasm reward tally " + rwTally);
if (!rwFlawedEnd.includes("Real check fails.")) fail("wasm reward flawed end " + rwFlawedEnd);
if (!rwRealEnd.includes("Real 1.00") || !rwRealEnd.includes("Real check passes.")) {
  fail("wasm reward real end " + rwRealEnd);
}
const rwSteps = exp.aa_rw_steps();
if (exp.aa_rw_flawed_proxy(rwSteps) <= exp.aa_rw_flawed_proxy(1) + 0.25) fail("wasm reward proxy");
for (let i = 1; i <= rwSteps; i += 1) {
  if (exp.aa_rw_flawed_holds(i) !== 0) fail("wasm reward flawed passed " + i);
}
if (exp.aa_rw_real_score(rwSteps) !== 1 || exp.aa_rw_real_holds(rwSteps) !== 1 || exp.aa_rw_real_holds(1) !== 0) {
  fail("wasm reward real curve");
}
const hnNeed = ["aa_hn_run", "aa_hn_harnesses", "aa_hn_tasks", "aa_hn_cols", "aa_hn_cell_len", "aa_hn_cell_byte", "aa_hn_task_len", "aa_hn_task_byte", "aa_hn_select", "aa_hn_logs", "aa_hn_log_len", "aa_hn_log_byte", "aa_hn_solved", "aa_hn_result_len", "aa_hn_result_byte", "aa_hn_stat_len", "aa_hn_stat_byte"];
for (const name of hnNeed) {
  if (typeof exp[name] !== "function") fail("missing export " + name);
}
if (exp.aa_hn_harnesses() !== 0 || exp.aa_hn_cell_byte(1, 1, 1) !== 0) fail("wasm harness before run");
exp.aa_hn_run();
if (exp.aa_hn_harnesses() !== 4 || exp.aa_hn_tasks() !== 8 || exp.aa_hn_cols() !== 4) {
  fail("wasm harness census");
}
const hnRate = ["1 of 8", "2 of 8", "8 of 8", "5 of 8"];
const hnSteps = ["8", "10", "25", "18"];
const hnWrong = ["7", "6", "0", "0"];
for (let r = 1; r <= 4; r += 1) {
  const rate = rwText(() => exp.aa_hn_cell_len(r, 2), (i) => exp.aa_hn_cell_byte(r, 2, i));
  const steps = rwText(() => exp.aa_hn_cell_len(r, 3), (i) => exp.aa_hn_cell_byte(r, 3, i));
  const wrong = rwText(() => exp.aa_hn_cell_len(r, 4), (i) => exp.aa_hn_cell_byte(r, 4, i));
  if (rate !== hnRate[r - 1] || steps !== hnSteps[r - 1] || wrong !== hnWrong[r - 1]) {
    fail("wasm harness row " + r + " " + rate + " " + steps + " " + wrong);
  }
}
if (exp.aa_hn_cell_len(0, 0) !== 0 || exp.aa_hn_cell_byte(1, 1, 0) !== 0) fail("wasm harness clamp");
const hnStat = rwText(() => exp.aa_hn_stat_len(), (i) => exp.aa_hn_stat_byte(i));
if (!hnStat.includes("20261104")) fail("wasm harness stat " + hnStat);
if (exp.aa_hn_solved(1) !== 0 || exp.aa_hn_solved(3) !== 1) fail("wasm harness showcase");
let sawGarble = false;
for (let i = 1; i <= exp.aa_hn_logs(1); i += 1) {
  const line = rwText(() => exp.aa_hn_log_len(1, i), (p) => exp.aa_hn_log_byte(1, i, p));
  if (line.includes("index two") && line.includes("accepted")) sawGarble = true;
}
if (!sawGarble) fail("wasm harness one-shot");
for (let i = 1; i <= exp.aa_hn_logs(3); i += 1) {
  const line = rwText(() => exp.aa_hn_log_len(3, i), (p) => exp.aa_hn_log_byte(3, i, p));
  if (line.includes("  accepted  bad-") || line.includes("  accepted  not-toward-base")) {
    fail("wasm harness checked kept " + line);
  }
}
exp.aa_hn_select(0);
if (exp.aa_hn_solved(3) !== 1) fail("wasm harness select");
const stNeed = ["aa_st_run", "aa_st_count", "aa_st_name_len", "aa_st_name_byte", "aa_st_answer_len", "aa_st_answer_byte", "aa_st_steps_len", "aa_st_steps_byte", "aa_st_select", "aa_st_which", "aa_st_rows", "aa_st_row_len", "aa_st_row_byte", "aa_st_bad", "aa_st_rule_len", "aa_st_rule_byte", "aa_st_stat_len", "aa_st_stat_byte"];
for (const name of stNeed) {
  if (typeof exp[name] !== "function") fail("missing export " + name);
}
if (exp.aa_st_count() !== 0 || exp.aa_st_name_byte(1, 1) !== 0) fail("wasm steps before run");
exp.aa_st_run();
if (exp.aa_st_count() !== 12 || exp.aa_st_which() !== 2) fail("wasm steps census");
const stAnswer = ["pass", "pass", "pass", "pass", "fail", "pass", "pass", "pass", "pass", "pass", "pass", "pass"];
const stSteps = ["pass", "fail", "fail", "fail", "fail", "pass", "fail", "pass", "fail", "fail", "pass", "fail"];
for (let i = 1; i <= 12; i += 1) {
  const answer = rwText(() => exp.aa_st_answer_len(i), (p) => exp.aa_st_answer_byte(i, p));
  const steps = rwText(() => exp.aa_st_steps_len(i), (p) => exp.aa_st_steps_byte(i, p));
  if (answer !== stAnswer[i - 1] || steps !== stSteps[i - 1]) {
    fail("wasm steps row " + i + " " + answer + " " + steps);
  }
}
if (exp.aa_st_bad() !== 2) fail("wasm steps bad " + exp.aa_st_bad());
const stRule = rwText(() => exp.aa_st_rule_len(), (p) => exp.aa_st_rule_byte(p));
if (stRule !== "bad-value") fail("wasm steps rule " + stRule);
const stRow = rwText(() => exp.aa_st_row_len(2), (p) => exp.aa_st_row_byte(2, p));
if (!stRow.startsWith("step h1 ")) fail("wasm steps h1 " + stRow);
const stStat = rwText(() => exp.aa_st_stat_len(), (p) => exp.aa_st_stat_byte(p));
if (!stStat.includes("Answer-only passes 11") || !stStat.includes("Steps pass 4")) fail("wasm steps stat " + stStat);
exp.aa_st_select(0);
if (exp.aa_st_which() !== 2) fail("wasm steps select clamp");
exp.aa_st_select(11);
if (exp.aa_st_bad() !== 0 || exp.aa_st_which() !== 11) fail("wasm steps sum");
if (exp.aa_st_row_len(0) !== 0 || exp.aa_st_name_byte(1, 0) !== 0) fail("wasm steps clamp");
const lkNeed = ["aa_lk_count", "aa_lk_item", "aa_lk_name_len", "aa_lk_name_byte", "aa_lk_text_len", "aa_lk_text_byte", "aa_lk_fp_len", "aa_lk_fp_byte", "aa_lk_status_len", "aa_lk_status_byte", "aa_lk_stat_len", "aa_lk_stat_byte"];
for (const name of lkNeed) {
  if (typeof exp[name] !== "function") fail("missing export " + name);
}
if (exp.aa_lk_count() !== 16) fail("wasm locked count " + exp.aa_lk_count());
if (exp.aa_lk_item(0) !== 0 || exp.aa_lk_name_byte(1, 0) !== 0 || exp.aa_lk_text_byte(17, 1) !== 0) {
  fail("wasm locked clamp");
}
if (exp.aa_lk_item(16) !== 17) fail("wasm locked item 17 " + exp.aa_lk_item(16));
for (let i = 1; i <= 15; i += 1) {
  const status = rwText(() => exp.aa_lk_status_len(i), (p) => exp.aa_lk_status_byte(i, p));
  const fp = rwText(() => exp.aa_lk_fp_len(i), (p) => exp.aa_lk_fp_byte(i, p));
  const text = rwText(() => exp.aa_lk_text_len(i), (p) => exp.aa_lk_text_byte(i, p));
  if (status !== "pass") fail("wasm locked status " + i + " " + status);
  if (!/^[0-9a-f]{64}$/.test(fp)) fail("wasm locked fp " + i + " " + fp);
  const file = "specs/item_" + String(i).padStart(2, "0") + ".adb";
  const digest = createHash("sha256").update(readFileSync(new URL(file, root))).digest("hex");
  if (fp !== digest) fail("wasm locked fp mismatch " + file);
  if (!text.includes("item " + String(i).padStart(2, "0") + " pass")) {
    fail("wasm locked text " + i);
  }
}
const lkStat = rwText(() => exp.aa_lk_stat_len(), (p) => exp.aa_lk_stat_byte(p));
const item17 = rwText(() => exp.aa_lk_text_len(16), (p) => exp.aa_lk_text_byte(16, p));
const item17fp = rwText(() => exp.aa_lk_fp_len(16), (p) => exp.aa_lk_fp_byte(16, p));
const item17hash = createHash("sha256").update(readFileSync(new URL("specs/item_17.adb", root))).digest("hex");
if (!item17.includes("item 17 pass") || item17fp !== item17hash) fail("wasm locked item 17");
if (!lkStat.includes("16 of 16 statements passed") || !lkStat.includes("cannot tell whether a spec is the right one")) {
  fail("wasm locked stat " + lkStat);
}
console.log("wasm ok", got);
