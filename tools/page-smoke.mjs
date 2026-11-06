// Headless check: the built page loads the Ada module, the splash paints
// and moves, Enter and a tap both leave it, F9 writes a feedback file,
// a failed module is a visible error, and a dirty previous session offers
// a crash report. Desktop and a phone-sized viewport.
import { mkdirSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import puppeteer from "puppeteer-core";

const root = resolve(import.meta.dirname, "..");
const pageUrl = pathToFileURL(resolve(root, "site/index.html")).href;
const stamp = readFileSync(resolve(root, "version.txt"), "utf8").trim();
const shotDir = resolve(root, process.env.SHOT_DIR || "screenshots");
mkdirSync(shotDir, { recursive: true });

function chromePath() {
  if (process.env.CHROME_PATH) return process.env.CHROME_PATH;
  for (const p of ["/usr/bin/google-chrome", "/usr/bin/google-chrome-stable", "/usr/bin/chromium"]) {
    try {
      readFileSync(p);
      return p;
    } catch {
      /* next */
    }
  }
  throw new Error("Chrome not found; set CHROME_PATH");
}

const errors = [];
function fail(msg) {
  console.error("FAIL", msg);
  if (errors.length) console.error(errors.join("\n"));
  process.exit(1);
}
function assert(cond, msg) {
  if (!cond) fail(msg);
}

async function litCount(page) {
  return page.evaluate(() => {
    const c = document.getElementById("view");
    if (!c || c.width < 8 || c.height < 8) return 0;
    const d = c.getContext("2d").getImageData(0, 0, c.width, c.height).data;
    let n = 0;
    for (let i = 0; i < d.length; i += 16) {
      if (d[i] + d[i + 1] + d[i + 2] > 40) n += 1;
    }
    return n;
  });
}

function watch(page) {
  page.on("pageerror", (e) => errors.push("pageerror " + e.message));
  page.on("console", (msg) => {
    if (msg.type() === "error") errors.push("console " + msg.text());
  });
}

const browser = await puppeteer.launch({
  executablePath: chromePath(),
  headless: true,
  args: ["--no-sandbox", "--disable-dev-shm-usage"],
});

try {
  const desktop = await browser.createBrowserContext();
  const page = await desktop.newPage();
  watch(page);
  await page.setViewport({ width: 1280, height: 800, deviceScaleFactor: 1 });
  await page.goto(pageUrl, { waitUntil: "load", timeout: 20000 });
  await page.waitForFunction(() => window.__adaReady === true, { timeout: 8000 });
  const lit = await litCount(page);
  assert(lit > 30, "splash lit pixels " + lit);
  await page.waitForFunction(() => {
    const c = document.getElementById("view");
    const d = c.getContext("2d").getImageData(0, 0, c.width, c.height).data;
    window.__prev = d;
    return true;
  });
  await new Promise((r) => setTimeout(r, 400));
  const moved = await page.evaluate(() => {
    const c = document.getElementById("view");
    const d = c.getContext("2d").getImageData(0, 0, c.width, c.height).data;
    const o = window.__prev;
    let n = 0;
    for (let i = 0; i < d.length; i += 16) {
      if (Math.abs(d[i] + d[i + 1] + d[i + 2] - o[i] - o[i + 1] - o[i + 2]) > 30) n += 1;
    }
    return n;
  });
  assert(moved > 5, "splash did not move " + moved);
  const splashTitle = await page.$eval("#splash h1", (el) => el.textContent.trim());
  const badge = await page.$eval("#ver", (el) => el.textContent.trim());
  const hint = await page.$eval("#hint", (el) => el.textContent.trim());
  assert(splashTitle === "ada-ai-amplifier", "title " + splashTitle);
  assert(badge === stamp, "badge " + badge);
  assert(hint === "Tap or Enter", "hint " + hint);
  assert(await page.$eval("#splash", (el) => !el.hidden), "splash hidden too early");
  await page.screenshot({ path: resolve(shotDir, "splash.png") });

  await page.keyboard.press("F9");
  await page.waitForSelector("#fb:not([hidden])");
  assert(await page.$eval("#splash", (el) => !el.hidden), "F9 skipped the splash");
  await page.click("#fbsend");
  assert(await page.$eval("#fberr", (el) => !el.hidden), "empty feedback was accepted");
  await page.type("#fbtext", "splash moved");
  await page.click("#fbsend");
  await page.waitForFunction(() => window.__lastDownload && window.__lastDownload.text.includes("splash moved"));
  const feedback = await page.evaluate(() => window.__lastDownload);
  assert(feedback.name.startsWith("feedback-"), "feedback name " + feedback.name);
  const body = JSON.parse(feedback.text);
  assert(body.type === "ada-ai-amplifier-feedback", "feedback type");
  assert(body.appVersion === stamp, "feedback version");
  assert(body.phase === "splash", "feedback phase " + body.phase);
  assert(body.feedback === "splash moved", "feedback text");
  assert(Array.isArray(body.eventLog) && body.eventLog.length > 0, "event log");

  await page.keyboard.press("Enter");
  await page.waitForFunction(() => document.getElementById("splash").hidden);
  const about = await page.$eval("#about", (el) => el.textContent);
  assert(about.includes("Ada computes every position"), "about");
  const items = await page.$$eval("#backlog li", (els) => els.map((el) => el.textContent.replace(/\s+/g, " ").trim()));
  assert(items.length === 16, "backlog length " + items.length);
  assert(items[1].includes("Splash and live page") && items[1].includes("done"), items[1]);
  assert(items[2].includes("Core tensor and maths") && items[2].includes("done"), items[2]);
  assert(items[3].includes("Tiny trainable MLP") && items[3].includes("done"), items[3]);
  assert(items[4].includes("Byte-level BPE") && items[4].includes("done"), items[4]);
  assert(items[5].includes("Contributor How-To") && items[5].includes("done"), items[5]);
  assert(items[6].includes("SPARK proofs of the kernels") && items[6].includes("done"), items[6]);
  assert(!items[6].includes("not started"), items[6]);
  assert(items[7].includes("Weight-space programming") && items[7].includes("done"), items[7]);
  assert(items[8].includes("Recursive prompts") && items[8].includes("done"), items[8]);
  assert(!items[8].includes("planned"), items[8]);
  assert(items[9].includes("Training-speed harness") && items[9].includes("planned"), items[9]);
  assert(items[10].includes("Wrong-turn traces") && items[10].includes("planned"), items[10]);
  assert(items[11].includes("Benchmark audit") && items[11].includes("planned"), items[11]);
  assert(items[12].includes("Reward-hacking demo") && items[12].includes("planned"), items[12]);
  assert(items[13].includes("Same model, different harness") && items[13].includes("planned"), items[13]);
  assert(items[14].includes("Checked steps, not just answers") && items[14].includes("planned"), items[14]);
  assert(items[15].includes("README update after items 1–15") && items[15].includes("planned"), items[15]);
  assert(!items[15].includes("done"), items[15]);
  const proof = await page.$$eval("#proof tbody tr", (els) => els.map((el) => el.innerText.replace(/\s+/g, " ").trim()));
  assert(proof.length === 16, "proof rows " + proof.length);
  const statusOf = (name) => {
    const row = proof.find((r) => r.slice(0, name.length) === name && (r.length === name.length || r[name.length] === " "));
    return row ? row.slice(name.length).trim() : "";
  };
  assert(statusOf("Dot") === "Silver", "dot " + statusOf("Dot"));
  assert(statusOf("Mat-vec") === "Silver", "matvec " + statusOf("Mat-vec"));
  assert(statusOf("Mat-mat") === "Silver", "matmat " + statusOf("Mat-mat"));
  assert(statusOf("Add") === "Gold", "add " + statusOf("Add"));
  assert(statusOf("Scale") === "Gold", "scale " + statusOf("Scale"));
  assert(statusOf("Transpose") === "Gold", "transpose " + statusOf("Transpose"));
  assert(statusOf("ReLU") === "Gold", "relu " + statusOf("ReLU"));
  assert(statusOf("Leaky ReLU") === "Gold", "leaky " + statusOf("Leaky ReLU"));
  assert(statusOf("Sigmoid") === "Silver", "sigmoid " + statusOf("Sigmoid"));
  assert(statusOf("Tanh") === "Silver", "tanh " + statusOf("Tanh"));
  assert(statusOf("Softmax") === "Silver", "softmax " + statusOf("Softmax"));
  assert(statusOf("Splash") === "not proved", "splash " + statusOf("Splash"));
  assert(statusOf("MLP") === "not proved", "mlp " + statusOf("MLP"));
  assert(statusOf("Tokenizer") === "not proved", "bpe " + statusOf("Tokenizer"));
  assert(statusOf("Attention") === "not proved", "attn " + statusOf("Attention"));
  assert(statusOf("Recursive prompts") === "not proved", "recurse proof " + statusOf("Recursive prompts"));
  const hrefs = await page.$$eval("#links a", (els) => els.map((a) => a.href));
  assert(hrefs.some((h) => h === "https://github.com/RobertBoettcherSF/ada-ai-amplifier"), "repo link " + hrefs);
  assert(hrefs.some((h) => h.includes("/docs/HOWTO.md")), "howto link " + hrefs);
  assert(hrefs.some((h) => h.includes("/docs/WEIGHT_SPACE.md")), "weights link " + hrefs);
  assert(hrefs.some((h) => h.includes("/docs/RECURSIVE_PROMPTS.md")), "recurse link " + hrefs);
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1);
  assert(overflow, "desktop main overflows");
  const numbered = await page.$$eval("#backlog .n", (els) => els.map((el) => el.textContent.trim()));
  assert(numbered.join(" ") === "1. 2. 3. 4. 5. 6. 7. 8. 9. 10. 11. 12. 13. 14. 15. 16.", "backlog numbers " + numbered);
  const product = await page.$$eval("#y1, #y2, #y3", (els) => els.map((el) => el.textContent.trim()));
  assert(product.join(",") === "14,14,17", "product " + product);
  const soft = await page.$$eval("#s1, #s2, #s3", (els) => els.map((el) => Number(el.textContent)));
  assert(Math.abs(soft[0] - 0.0452785) < 2e-4 && Math.abs(soft[2] - 0.909443) < 2e-4, "softmax " + soft);
  await page.$eval("#v3", (el) => { el.value = "0"; });
  await page.click("#compute");
  const edited = await page.$$eval("#y1, #y2, #y3", (els) => els.map((el) => el.textContent.trim()));
  assert(edited.join(",") === "5,2,17", "edited product " + edited);
  await page.$eval("#v3", (el) => { el.value = "nope"; });
  await page.click("#compute");
  assert(await page.$eval("#demoerr", (el) => !el.hidden && el.textContent.includes("finite number")), "bad input");
  await page.$eval("#v3", (el) => { el.value = "3"; });
  await page.click("#compute");
  const restored = await page.$eval("#y1", (el) => el.textContent.trim());
  assert(restored === "14", "restored " + restored);

  const lrelu = await page.$$eval("#lo1, #lo2, #lo3", (els) => els.map((el) => Number(el.textContent)));
  const lslope = await page.$eval("#lrslope", (el) => Number(el.textContent));
  assert(Math.abs(lslope - 0.01) < 1e-6, "lrelu slope " + lslope);
  assert(Math.abs(lrelu[0] - lslope * -2) < 1e-5 && lrelu[1] === 0 && lrelu[2] === 3, "lrelu " + lrelu);
  const lreluH = await page.$eval("#lrelu-apply", (el) => el.getBoundingClientRect().height);
  assert(lreluH >= 44, "lrelu height " + lreluH);
  await page.$eval("#lr1", (el) => { el.value = "1.5"; });
  await page.click("#lrelu-apply");
  const lreluEdited = await page.$eval("#lo1", (el) => el.textContent.trim());
  assert(lreluEdited === "1.5", "lrelu edited " + lreluEdited);
  await page.$eval("#lr1", (el) => { el.value = "nope"; });
  await page.click("#lrelu-apply");
  assert(await page.$eval("#lreluerr", (el) => !el.hidden && el.textContent.includes("finite number")), "lrelu bad input");
  await page.$eval("#lr1", (el) => { el.value = "-2"; });
  await page.click("#lrelu-apply");
  const lreluBack = await page.$eval("#lo1", (el) => Number(el.textContent));
  assert(Math.abs(lreluBack - lslope * -2) < 1e-5, "lrelu restored " + lreluBack);
  await page.evaluate(() => document.getElementById("lrelu").scrollIntoView({ block: "center" }));
  await page.screenshot({ path: resolve(shotDir, "leaky.png") });

  const mlpInit = await page.$eval("#mlpstat", (el) => el.textContent);
  assert(mlpInit.startsWith("step 0"), "mlp init " + mlpInit);
  assert(await page.$eval("#mlpout", (el) => el.textContent.includes("points 4")), "mlp points");
  const trainH = await page.$eval("#train", (el) => el.getBoundingClientRect().height);
  assert(trainH >= 44, "train height " + trainH);
  await page.click("#train");
  await page.waitForFunction(() => {
    const stat = document.getElementById("mlpstat").textContent;
    const out = document.getElementById("mlpout").textContent;
    const loss = /loss ([0-9.]+)/.exec(stat);
    return loss && Number(loss[1]) < 0.05 && out.includes("4/4");
  }, { timeout: 20000 });
  const spread = await page.evaluate(() => {
    const c = document.getElementById("boundary");
    const d = c.getContext("2d").getImageData(0, 0, c.width, c.height).data;
    let min = 255;
    let max = 0;
    for (let i = 0; i < d.length; i += 16) {
      if (d[i] < min) min = d[i];
      if (d[i] > max) max = d[i];
    }
    return max - min;
  });
  assert(spread > 40, "boundary spread " + spread);
  const curveLit = await page.evaluate(() => {
    const c = document.getElementById("losscurve");
    const d = c.getContext("2d").getImageData(0, 0, c.width, c.height).data;
    let n = 0;
    for (let i = 0; i < d.length; i += 4) {
      if (d[i] > 180 && d[i + 1] > 140) n += 1;
    }
    return n;
  });
  assert(curveLit > 8, "loss curve " + curveLit);
  await page.click("#train");
  assert(await page.$eval("#train", (el) => el.textContent.trim() === "Train"), "train did not stop");
  await page.click("#rate-down");
  const lowered = await page.$eval("#mlpstat", (el) => el.textContent);
  assert(lowered.includes("rate 0.45"), "rate " + lowered);
  await page.click("#set-circles");
  await page.waitForFunction(() => document.getElementById("mlpstat").textContent.startsWith("step 0"));
  assert(await page.$eval("#mlpout", (el) => el.textContent.includes("points 72")), "circles");
  await page.click("#set-spirals");
  assert(await page.$eval("#mlpout", (el) => el.textContent.includes("points 96")), "spirals");
  await page.click("#reset");
  assert(await page.$eval("#mlpstat", (el) => el.textContent.startsWith("step 0")), "spiral reset");
  await page.click("#set-xor");
  assert(await page.$eval("#mlpout", (el) => el.textContent.includes("points 4")), "back to xor");

  await page.click("#w-hand");
  await page.waitForFunction(() => document.getElementById("mlpout").textContent.includes("4/4"));
  assert(await page.$eval("#mlpstat", (el) => el.textContent.startsWith("step 0")), "hand epoch");
  const handNote = await page.$eval("#wnote", (el) => el.textContent);
  assert(handNote.includes("hand-written"), handNote);
  const handH = await page.$eval("#w-hand", (el) => el.getBoundingClientRect().height);
  assert(handH >= 44, "hand height " + handH);
  const handSpread = await page.evaluate(() => {
    const c = document.getElementById("boundary");
    const d = c.getContext("2d").getImageData(0, 0, c.width, c.height).data;
    let min = 255;
    let max = 0;
    for (let i = 0; i < d.length; i += 16) {
      if (d[i] < min) min = d[i];
      if (d[i] > max) max = d[i];
    }
    return max - min;
  });
  assert(handSpread > 40, "hand boundary " + handSpread);
  await page.evaluate(() => document.getElementById("weights").scrollIntoView({ block: "center" }));
  await page.screenshot({ path: resolve(shotDir, "weights.png") });
  await page.click("#w-flip");
  await page.waitForFunction(() => !document.getElementById("mlpout").textContent.includes("4/4"));
  const flipNote = await page.$eval("#wnote", (el) => el.textContent);
  assert(flipNote.includes("Flipped hidden 1"), flipNote);
  await page.click("#w-hand");
  await page.waitForFunction(() => document.getElementById("mlpout").textContent.includes("4/4"));
  await page.click("#w-silence");
  const silenceNote = await page.$eval("#wnote", (el) => el.textContent);
  assert(silenceNote.includes("Silenced hidden 2"), silenceNote);
  assert(!(await page.$eval("#mlpout", (el) => el.textContent.includes("4/4"))), "silence still perfect");
  await page.click("#w-hand");
  await page.waitForFunction(() => document.getElementById("mlpout").textContent.includes("4/4"));
  await page.click("#w-invert");
  const invertNote = await page.$eval("#wnote", (el) => el.textContent);
  assert(invertNote.includes("trade places"), invertNote);
  assert(await page.$eval("#mlpout", (el) => el.textContent.includes("0/4")), "invert classes");
  await page.click("#w-trained");
  await page.waitForFunction(() => document.getElementById("mlpstat").textContent.startsWith("step 0"));
  const trainedNote = await page.$eval("#wnote", (el) => el.textContent);
  assert(trainedNote.includes("seeded"), trainedNote);
  await page.click("#w-down");
  await page.waitForFunction(() => window.__lastDownload && window.__lastDownload.name.startsWith("weights-"));
  const wfile = await page.evaluate(() => window.__lastDownload);
  assert(wfile.text.includes("shape 2 8 1") && wfile.text.includes("hidden 1"), "download text");
  assert(wfile.text.includes("ada-ai-amplifier weights 1"), "download header");
  const beforeLoss = await page.evaluate(() => window.__mlp.loss);
  await page.evaluate(() => {
    const slider = document.getElementById("ws1");
    slider.value = "12";
    slider.dispatchEvent(new Event("input", { bubbles: true }));
  });
  await page.waitForFunction((prev) => window.__mlp.loss !== prev, {}, beforeLoss);
  const shown = await page.$eval("#wn1", (el) => Number(el.value));
  assert(Math.abs(shown - 12) < 1e-4, "slider value " + shown);
  const good = wfile.text;
  await page.evaluate((body) => {
    const file = new File([body], "weights.txt", { type: "text/plain" });
    const input = document.getElementById("w-file");
    const dt = new DataTransfer();
    dt.items.add(file);
    input.files = dt.files;
    input.dispatchEvent(new Event("change", { bubbles: true }));
  }, good);
  await page.waitForFunction(() => document.getElementById("wnote").textContent.includes("Loaded the weights"));
  const restoredW = await page.$eval("#wn1", (el) => Number(el.value));
  assert(Math.abs(restoredW - 12) > 0.5, "upload did not replace " + restoredW);
  await page.evaluate(() => {
    const file = new File(["ada-ai-amplifier weights 1\nshape 2 4 1\n"], "bad.txt", { type: "text/plain" });
    const input = document.getElementById("w-file");
    const dt = new DataTransfer();
    dt.items.add(file);
    input.files = dt.files;
    input.dispatchEvent(new Event("change", { bubbles: true }));
  });
  await page.waitForFunction(() => !document.getElementById("werr").hidden);
  const werr = await page.$eval("#werr", (el) => el.textContent);
  assert(werr.includes("shape"), werr);
  const afterReject = await page.$eval("#wn1", (el) => Number(el.value));
  assert(Math.abs(afterReject - restoredW) < 1e-4, "reject changed a weight");

  await page.evaluate(() => document.getElementById("attn").scrollIntoView({ block: "center" }));
  const attnStat = await page.$eval("#attnstat", (el) => el.textContent);
  assert(attnStat.includes("32 merges"), "attn stat " + attnStat);
  assert(attnStat.includes("vocabulary 288"), "attn vocab " + attnStat);
  assert(attnStat.includes("attention on all 15"), "attn all " + attnStat);
  const attnInfo = await page.evaluate(() => window.__attn);
  assert(attnInfo.tokens === 15 && attnInfo.used === 15, "attn counts " + attnInfo.tokens + " " + attnInfo.used);
  const chipText = await page.$eval("#tokens", (el) => el.textContent);
  assert(chipText.includes("ß"), "eszett chip " + chipText);
  assert(chipText.includes("c3"), "split umlaut " + chipText);
  assert(chipText.includes("284"), "merged id " + chipText);
  const round = await page.evaluate(() => {
    const want = Array.from(new TextEncoder().encode(document.getElementById("attntext").value));
    const got = window.__attn.bytes;
    if (want.length !== got.length) return "len " + want.length + " " + got.length;
    for (let i = 0; i < want.length; i += 1) if (want[i] !== got[i]) return "byte " + i;
    return "ok";
  });
  assert(round === "ok", "attn round trip " + round);
  const causal = await page.evaluate(() => {
    const w = window.__attn.weights;
    for (let i = 0; i < w.length; i += 1) {
      let sum = 0;
      for (let j = 0; j < w.length; j += 1) {
        sum += w[i][j];
        if (j > i && w[i][j] !== 0) return "future " + i + " " + j;
      }
      if (Math.abs(sum - 1) > 1e-4) return "sum " + i + " " + sum;
    }
    return "ok";
  });
  assert(causal === "ok", "attn causal " + causal);
  const heatSpread = await page.evaluate(() => {
    const c = document.getElementById("heat");
    const d = c.getContext("2d").getImageData(0, 0, c.width, c.height).data;
    let min = 255;
    let max = 0;
    for (let i = 0; i < d.length; i += 16) {
      if (d[i] < min) min = d[i];
      if (d[i] > max) max = d[i];
    }
    return max - min;
  });
  assert(heatSpread > 40, "heat spread " + heatSpread);
  const attnFont = await page.$eval("#attntext", (el) => parseFloat(getComputedStyle(el).fontSize));
  assert(attnFont >= 16, "attn font " + attnFont);
  await page.click("#attntext");
  await page.evaluate(() => {
    const el = document.getElementById("attntext");
    el.focus();
    el.select();
  });
  await page.keyboard.press("Backspace");
  await page.keyboard.type("hi äß");
  await page.waitForFunction(() => window.__attn && window.__attn.bytes.length >= 2);
  const typed = await page.evaluate(() => {
    const want = Array.from(new TextEncoder().encode("hi äß"));
    const got = window.__attn.bytes;
    if (want.length !== got.length) return "len " + want.length + " " + got.length + " text " + document.getElementById("attntext").value;
    for (let i = 0; i < want.length; i += 1) if (want[i] !== got[i]) return "byte " + i;
    let sum = 0;
    const row = window.__attn.weights[0];
    for (let j = 0; j < row.length; j += 1) sum += row[j];
    if (Math.abs(sum - 1) > 1e-4) return "sum " + sum;
    if (window.__attn.weights[0][window.__attn.used - 1] !== 0 && window.__attn.used > 1) return "future";
    return "ok";
  });
  assert(typed === "ok", "typed attn " + typed);
  await page.click("#tokens .tok");
  const pressed = await page.$eval("#tokens .tok", (el) => el.getAttribute("aria-pressed"));
  assert(pressed === "true", "token press " + pressed);

  await page.evaluate(() => document.getElementById("recurse").scrollIntoView({ block: "center" }));
  const recStat = await page.$eval("#recstat", (el) => el.textContent);
  assert(recStat.includes("4 recorded chains"), "rec stat " + recStat);
  assert(recStat.includes("at most 20"), "rec max " + recStat);
  const rec = await page.evaluate(() => window.__rec);
  assert(rec && rec.length === 4, "rec count");
  const recGood = rec.find((c) => c.name === "fib-6-complete");
  const recBad = rec.find((c) => c.name === "fib-6-bad-sum");
  const stall = rec.find((c) => c.name === "fib-4-stalled");
  const garbled = rec.find((c) => c.name === "fib-3-garbled");
  assert(recGood && recGood.kind === 0 && recGood.answer === 8 && recGood.stepsOk === 6, "rec good " + JSON.stringify(recGood));
  assert(recGood.note.includes("Reached the base case"), "rec note " + recGood.note);
  assert(recGood.states.length === 7 && recGood.states[6].index === 0 && recGood.states[6].minus === 8 && recGood.states[6].current === 13, "rec last");
  assert(recGood.states[6].line.includes("base"), "rec base line " + recGood.states[6].line);
  assert(recBad && recBad.kind === 4 && recBad.stopAt === 4 && recBad.stepsOk === 2, "rec bad " + JSON.stringify(recBad));
  assert(recBad.note.includes("bad arithmetic"), "rec arith " + recBad.note);
  assert(recBad.states[3].current === 4 && recBad.states[3].mark === 2, "rec bad step");
  assert(stall && stall.kind === 3 && stall.states[1].index === 4, "rec stall");
  assert(stall.note.includes("not toward base"), "rec toward " + stall.note);
  assert(garbled && garbled.kind === 1 && garbled.states[2].parsed === 0, "rec garbled");
  assert(garbled.states[2].line === "unreadable  halt", "rec line " + garbled.states[2].line);
  const recText = await page.$eval("#reclist", (el) => el.textContent);
  assert(recText.includes("Reached the base case"), "rec visible good");
  assert(recText.includes("bad arithmetic"), "rec visible halt");
  assert(recText.includes("not toward base"), "rec visible stall");
  await page.screenshot({ path: resolve(shotDir, "recurse.png") });

  await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
  const covered = await page.evaluate(() => {
    const link = document.querySelector("#links a[href*='docs/HOWTO.md']").getBoundingClientRect();
    const btn = document.getElementById("fbbtn").getBoundingClientRect();
    const ver = document.getElementById("ver").getBoundingClientRect();
    return link.bottom > btn.top || link.bottom > ver.top || link.top < 0;
  });
  assert(!covered, "how-to link sits under the fixed controls");
  await page.screenshot({ path: resolve(shotDir, "main.png"), fullPage: true });
  assert(errors.length === 0, "desktop errors");

  const crashCtx = await browser.createBrowserContext();
  const crashPage = await crashCtx.newPage();
  const crashErrors = [];
  crashPage.on("pageerror", (e) => crashErrors.push(e.message));
  await crashPage.evaluateOnNewDocument(() => localStorage.setItem("aaa.clean", "0"));
  await crashPage.goto(pageUrl, { waitUntil: "load" });
  await crashPage.waitForSelector("#crash:not([hidden])");
  await crashPage.click("#crashdl");
  await crashPage.waitForFunction(() => window.__lastDownload && window.__lastDownload.name.startsWith("crash-report-"));
  const crashFile = JSON.parse(await crashPage.evaluate(() => window.__lastDownload.text));
  assert(crashFile.type === "ada-ai-amplifier-crash", "crash type");
  assert(crashFile.appVersion === stamp, "crash version");
  assert(Array.isArray(crashFile.eventsThisVisit), "crash log");
  assert(crashErrors.length === 0, "crash page errors " + crashErrors);

  const phone = await browser.createBrowserContext();
  const phonePage = await phone.newPage();
  const phoneErrors = [];
  phonePage.on("pageerror", (e) => phoneErrors.push(e.message));
  await phonePage.setUserAgent("Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.5 Mobile/15E148 Safari/604.1");
  await phonePage.setViewport({ width: 390, height: 844, isMobile: true, hasTouch: true, deviceScaleFactor: 1 });
  await phonePage.goto(pageUrl, { waitUntil: "load" });
  await phonePage.waitForFunction(() => window.__adaReady === true, { timeout: 8000 });
  assert(await litCount(phonePage) > 20, "phone splash dark");
  await phonePage.screenshot({ path: resolve(shotDir, "phone-splash.png") });
  const box = await phonePage.$eval("#splash canvas", (el) => {
    const r = el.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  });
  await phonePage.touchscreen.tap(box.x, box.y);
  await phonePage.waitForFunction(() => document.getElementById("splash").hidden);
  const phoneProduct = await phonePage.$eval("#y1", (el) => el.textContent.trim());
  assert(phoneProduct === "14", "phone product " + phoneProduct);
  const phoneLrelu = await phonePage.$eval("#lrelu-apply", (el) => el.getBoundingClientRect().height);
  assert(phoneLrelu >= 44, "phone lrelu height " + phoneLrelu);
  const phoneLreluFont = await phonePage.$eval("#lr1", (el) => parseFloat(getComputedStyle(el).fontSize));
  assert(phoneLreluFont >= 16, "phone lrelu font " + phoneLreluFont);
  const phoneLreluOut = await phonePage.$eval("#lo3", (el) => el.textContent.trim());
  assert(phoneLreluOut === "3", "phone lrelu " + phoneLreluOut);
  const phoneTrain = await phonePage.$eval("#train", (el) => el.getBoundingClientRect().height);
  assert(phoneTrain >= 44, "phone train height " + phoneTrain);
  const phoneFont = await phonePage.$eval("#rate", (el) => parseFloat(getComputedStyle(el).fontSize));
  assert(phoneFont >= 16, "phone rate font " + phoneFont);
  const phoneAttnFont = await phonePage.$eval("#attntext", (el) => parseFloat(getComputedStyle(el).fontSize));
  assert(phoneAttnFont >= 16, "phone attn font " + phoneAttnFont);
  await phonePage.evaluate(() => document.getElementById("attn").scrollIntoView({ block: "center" }));
  const phoneAttn = await phonePage.$eval("#attnstat", (el) => el.textContent);
  assert(phoneAttn.includes("32 merges"), "phone attn " + phoneAttn);
  const phoneChip = await phonePage.$eval(".tok", (el) => el.getBoundingClientRect().height);
  assert(phoneChip >= 44, "phone token height " + phoneChip);
  await phonePage.tap("#tokens .tok");
  const phoneRead = await phonePage.$eval("#attnread", (el) => el.textContent);
  assert(phoneRead.includes("attends to"), "phone readout " + phoneRead);
  await phonePage.evaluate(() => document.getElementById("recurse").scrollIntoView({ block: "center" }));
  const phoneRec = await phonePage.$eval("#reclist", (el) => el.textContent);
  assert(phoneRec.includes("Reached the base case"), "phone rec good");
  assert(phoneRec.includes("bad arithmetic"), "phone rec halt");
  const phoneRecOverflow = await phonePage.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1);
  assert(phoneRecOverflow, "phone rec overflows");
  await phonePage.evaluate(() => document.getElementById("mlp").scrollIntoView({ block: "center" }));
  const phoneHand = await phonePage.$eval("#w-hand", (el) => el.getBoundingClientRect().height);
  assert(phoneHand >= 44, "phone hand height " + phoneHand);
  await phonePage.tap("#train");
  await phonePage.waitForFunction(() => {
    const m = /step (\d+)/.exec(document.getElementById("mlpstat").textContent);
    return m && Number(m[1]) > 8;
  }, { timeout: 8000 });
  const phoneSpread = await phonePage.evaluate(() => {
    const c = document.getElementById("boundary");
    return c.width > 40 && c.height > 40;
  });
  assert(phoneSpread, "phone boundary canvas");
  const phoneOverflow = await phonePage.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1);
  assert(phoneOverflow, "phone main overflows");
  await phonePage.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
  const phoneCovered = await phonePage.evaluate(() => {
    const link = document.querySelector("#links a[href*='docs/HOWTO.md']").getBoundingClientRect();
    const btn = document.getElementById("fbbtn").getBoundingClientRect();
    const ver = document.getElementById("ver").getBoundingClientRect();
    return link.bottom > btn.top || link.bottom > ver.top;
  });
  assert(!phoneCovered, "phone how-to link sits under the fixed controls");
  await phonePage.tap("#fbbtn");
  await phonePage.waitForSelector("#fb:not([hidden])");
  await phonePage.type("#fbtext", "phone ok");
  await phonePage.tap("#fbsend");
  await phonePage.waitForFunction(() => window.__lastDownload && window.__lastDownload.text.includes("phone ok"));
  await phonePage.screenshot({ path: resolve(shotDir, "phone-main.png"), fullPage: true });
  assert(phoneErrors.length === 0, "phone errors " + phoneErrors);

  const bad = await browser.createBrowserContext();
  const badPage = await bad.newPage();
  const badErrors = [];
  badPage.on("pageerror", (e) => badErrors.push(e.message));
  await badPage.setViewport({ width: 1280, height: 800 });
  await badPage.goto(pageUrl + "?nowasm=1", { waitUntil: "load" });
  await badPage.waitForSelector("#wasmerr:not([hidden])");
  const errText = await badPage.$eval("#wasmerr", (el) => el.textContent);
  assert(errText.includes("The Ada module did not load"), errText);
  assert(await badPage.$eval("#splash h1", (el) => el.textContent.includes("ada-ai-amplifier")), "error page title");
  const badBadge = await badPage.$eval("#ver", (el) => el.textContent.trim());
  assert(badBadge === stamp, "error page badge " + badBadge);
  await badPage.click("#cont");
  await badPage.waitForFunction(() => document.getElementById("splash").hidden);
  assert(await badPage.$eval("#banner", (el) => !el.hidden && el.textContent.includes("did not load")), "banner");
  assert(await badPage.$eval("#demoerr", (el) => !el.hidden && el.textContent.includes("no product")), "demo down");
  assert(await badPage.$eval("#compute", (el) => el.disabled), "compute still enabled");
  assert(await badPage.$eval("#lreluerr", (el) => !el.hidden && el.textContent.includes("no leaky ReLU")), "lrelu down");
  assert(await badPage.$eval("#lrelu-apply", (el) => el.disabled), "lrelu still enabled");
  assert(await badPage.$eval("#mlperr", (el) => !el.hidden && el.textContent.includes("cannot train")), "mlp down");
  assert(await badPage.$eval("#train", (el) => el.disabled), "train still enabled");
  assert(await badPage.$eval("#w-hand", (el) => el.disabled), "weights still enabled");
  assert(await badPage.$eval("#werr", (el) => !el.hidden && el.textContent.includes("cannot")), "weights down");
  assert(await badPage.$eval("#attnerr", (el) => !el.hidden && el.textContent.includes("cannot tokenize")), "attn down");
  assert(await badPage.$eval("#attntext", (el) => el.disabled), "attn text still enabled");
  assert(await badPage.$eval("#recerr", (el) => !el.hidden && el.textContent.includes("cannot check a chain")), "recurse down");
  assert(badErrors.length === 0, "nowasm errors " + badErrors);

  const html = readFileSync(resolve(root, "site/index.html"), "utf8");
  assert(!html.includes("__WASM_BASE64__"), "placeholder left in the page");
  assert(html.includes("id=\"ver\">" + stamp + "<"), "built badge");
  console.log("page ok", stamp, "lit", lit, "moved", moved);
} finally {
  await browser.close();
}
