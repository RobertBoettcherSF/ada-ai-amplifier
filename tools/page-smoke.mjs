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
  assert(items.length === 20, "backlog length " + items.length);
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
  assert(items[9].includes("Training-speed harness") && items[9].includes("done"), items[9]);
  assert(items[10].includes("Wrong-turn traces") && items[10].includes("done"), items[10]);
  assert(!items[10].includes("planned"), items[10]);
  assert(items[11].includes("Benchmark audit") && items[11].includes("done"), items[11]);
  assert(!items[11].includes("planned"), items[11]);
  assert(items[12].includes("Reward-hacking demo") && items[12].includes("done"), items[12]);
  assert(!items[12].includes("planned"), items[12]);
  assert(items[13].includes("Same model, different harness") && items[13].includes("done"), items[13]);
  assert(!items[13].includes("planned"), items[13]);
  assert(items[14].includes("Checked steps, not just answers") && items[14].includes("done"), items[14]);
  assert(!items[14].includes("planned"), items[14]);
  assert(items[15].includes("Locked statements") && items[15].includes("done"), items[15]);
  assert(items[15].includes("formal-math") && items[15].includes("Apache-2.0"), items[15]);
  assert(!items[15].includes("README update"), items[15]);
  assert(items[16].includes("independent checker") && items[16].includes("done"), items[16]);
  assert(items[16].includes("formal-math") && items[16].includes("Apache-2.0"), items[16]);
  assert(items[17].includes("Checking status") && items[17].includes("done"), items[17]);
  assert(items[17].includes("openai/math") && items[17].includes("Apache-2.0"), items[17]);
  assert(items[17].includes("Ideas inspired by"), items[17]);
  assert(items[18].includes("Reasoning summary") && items[18].includes("done"), items[18]);
  assert(!items[18].includes("planned"), items[18]);
  assert(items[18].includes("openai/math") && items[18].includes("Apache-2.0"), items[18]);
  assert(items[19].includes("README update after items 1–19") && items[19].includes("done"), items[19]);
  const status16 = await page.$eval("#backlog li:nth-child(16) .st", (el) => el.textContent.trim());
  assert(status16 === "done", status16);
  const status20 = await page.$eval("#backlog li:nth-child(20) .st", (el) => el.textContent.trim());
  assert(status20 === "done", status20);
  const proof = await page.$$eval("#proof tbody tr", (els) => els.map((el) => el.innerText.replace(/\s+/g, " ").trim()));
  assert(proof.length === 26, "proof rows " + proof.length);
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
  assert(statusOf("Training speed") === "not proved", "speed " + statusOf("Training speed"));
  assert(statusOf("Tokenizer") === "not proved", "bpe " + statusOf("Tokenizer"));
  assert(statusOf("Attention") === "not proved", "attn " + statusOf("Attention"));
  assert(statusOf("Recursive prompts") === "rule proved", "recurse proof " + statusOf("Recursive prompts"));
  assert(statusOf("Wrong turns") === "rule proved", "turns proof " + statusOf("Wrong turns"));
  assert(statusOf("Benchmark audit") === "rule proved", "audit proof " + statusOf("Benchmark audit"));
  assert(statusOf("Reward hacking") === "rule proved", "reward proof " + statusOf("Reward hacking"));
  assert(statusOf("Harness comparison") === "not proved", "harness proof " + statusOf("Harness comparison"));
  assert(statusOf("Checked steps") === "rule proved", "steps proof " + statusOf("Checked steps"));
  assert(statusOf("Locked statements") === "rule proved", "locked proof " + statusOf("Locked statements"));
  assert(statusOf("Second checker") === "rule proved", "recheck proof " + statusOf("Second checker"));
  assert(statusOf("Checking status") === "rule proved", "status proof " + statusOf("Checking status"));
  assert(statusOf("Reasoning summary") === "rule proved", "summary proof " + statusOf("Reasoning summary"));
  const hrefs = await page.$$eval("#links a", (els) => els.map((a) => a.href));
  assert(hrefs.some((h) => h === "https://github.com/RobertBoettcherSF/ada-ai-amplifier"), "repo link " + hrefs);
  assert(hrefs.some((h) => h.includes("/docs/HOWTO.md")), "howto link " + hrefs);
  assert(hrefs.some((h) => h.includes("/docs/WEIGHT_SPACE.md")), "weights link " + hrefs);
  assert(hrefs.some((h) => h.includes("/docs/RECURSIVE_PROMPTS.md")), "recurse link " + hrefs);
  assert(hrefs.some((h) => h.includes("/docs/TRAINING_SPEED.md")), "speed link " + hrefs);
  assert(hrefs.some((h) => h.includes("/docs/WRONG_TURNS.md")), "turns link " + hrefs);
  assert(hrefs.some((h) => h.includes("/docs/BENCHMARK_AUDIT.md")), "audit link " + hrefs);
  assert(hrefs.some((h) => h.includes("/docs/REWARD_HACKING.md")), "reward link " + hrefs);
  assert(hrefs.some((h) => h.includes("/docs/HARNESS.md")), "harness link " + hrefs);
  assert(hrefs.some((h) => h.includes("/docs/CHECKED_STEPS.md")), "steps link " + hrefs);
  assert(hrefs.some((h) => h.includes("/docs/LOCKED_STATEMENTS.md")), "locked link " + hrefs);
  assert(hrefs.some((h) => h.includes("/docs/SECOND_CHECKER.md")), "recheck link " + hrefs);
  assert(hrefs.some((h) => h.includes("/docs/CHECKING_STATUS.md")), "status link " + hrefs);
  assert(hrefs.some((h) => h.includes("/docs/REASONING_SUMMARY.md")), "summary link " + hrefs);
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1);
  assert(overflow, "desktop main overflows");
  const numbered = await page.$$eval("#backlog .n", (els) => els.map((el) => el.textContent.trim()));
  assert(numbered.join(" ") === "1. 2. 3. 4. 5. 6. 7. 8. 9. 10. 11. 12. 13. 14. 15. 16. 17. 18. 19. 20.", "backlog numbers " + numbered);
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
  await page.evaluate(() => document.getElementById("turns").scrollIntoView({ block: "center" }));
  const turnSteps = await page.$eval("#turnsteps", (el) => el.textContent);
  assert(turnSteps.includes("Wrong turn:"), "turn steps " + turnSteps);
  const turnGood = await page.$eval("#turngood", (el) => el.textContent);
  assert(turnGood.includes("fixes-it") && turnGood.includes("xor-returned"), turnGood);
  const turnState = await page.$eval("#turnstat", (el) => el.textContent);
  assert(turnState.includes("xor missed") && turnState.includes("weights valid"), turnState);
  const turnH = await page.$eval("#turn-go-1", (el) => el.getBoundingClientRect().height);
  assert(turnH >= 44, "turn height " + turnH);
  await page.click("#turn-go-9");
  await page.waitForFunction(() => document.getElementById("turnreport").textContent.includes("makes-it-worse"), { timeout: 20000 });
  const turnBad = await page.$eval("#turnreport", (el) => el.textContent);
  assert(turnBad.includes("loss-rose"), turnBad);
  await page.click("#turn-go-1");
  await page.waitForFunction(() => document.getElementById("turnreport").textContent.includes("fixes-it"), { timeout: 20000 });
  const turnFix = await page.$eval("#turnreport", (el) => el.textContent);
  assert(turnFix.includes("xor-returned"), turnFix);
  await page.click("#turn-pick-2");
  await page.waitForFunction(() => document.getElementById("turnsteps").textContent.includes("shape 2 4 1"), { timeout: 20000 });
  const turnShape = await page.$eval("#turngood", (el) => el.textContent);
  assert(turnShape.includes("fixes-it"), turnShape);
  await page.screenshot({ path: resolve(shotDir, "turns.png") });
  await page.evaluate(() => document.getElementById("audit").scrollIntoView({ block: "center" }));
  const auditStat = await page.$eval("#auditstat", (el) => el.textContent);
  assert(auditStat.includes("20 tasks") && auditStat.includes("5 flagged"), auditStat);
  const auditRows = await page.$$eval("#auditlist li", (els) => els.map((el) => el.textContent));
  assert(auditRows.length === 20, "audit rows " + auditRows.length);
  assert(auditRows.some((r) => r.includes("xor-00") && r.includes("pass")), "audit pass " + auditRows[0]);
  for (const rule of ["wrong-expected", "unsolvable", "duplicate", "accept-anything", "answer-leaked"]) {
    assert(auditRows.some((r) => r.includes("flag") && r.includes(rule)), "audit " + rule);
  }
  const auditFull = await page.$eval("#auditfull", (el) => el.textContent);
  const auditClean = await page.$eval("#auditclean", (el) => el.textContent);
  assert(auditFull.includes("14 of 20") && auditFull.includes("Not accepted"), auditFull);
  assert(auditClean.includes("9 of 15") && auditClean.includes("Accepted"), auditClean);
  assert(!auditClean.includes("Not accepted"), auditClean);
  const auditErr = await page.$eval("#auditerr", (el) => el.hidden);
  assert(auditErr, "audit error visible");
  await page.screenshot({ path: resolve(shotDir, "audit.png") });

  await page.evaluate(() => document.getElementById("reward").scrollIntoView({ block: "center" }));
  const rewardStat = await page.$eval("#rewardstat", (el) => el.textContent);
  assert(rewardStat.includes("5 submissions") && rewardStat.includes("1 passes"), rewardStat);
  assert(rewardStat.includes("20261104") && rewardStat.includes("120 steps"), rewardStat);
  const rewardRows = await page.$$eval("#rewardtable tbody tr", (els) => els.map((el) => el.textContent));
  assert(rewardRows.length === 5, "reward rows " + rewardRows.length);
  assert(rewardRows[0].includes("honest-trained") && rewardRows[0].includes("counts") && rewardRows[0].includes("none"), rewardRows[0]);
  assert(rewardRows[1].includes("hard-coded-loss") && rewardRows[1].includes("reported-loss") && rewardRows[1].includes("rejected"), rewardRows[1]);
  assert(rewardRows[2].includes("constant-half") && rewardRows[2].includes("rejected"), rewardRows[2]);
  assert(rewardRows[3].includes("memorized-two") && rewardRows[3].includes("two-of-four") && rewardRows[3].includes("0.50"), rewardRows[3]);
  assert(rewardRows[4].includes("right-stamp") && rewardRows[4].includes("right-stamp") && rewardRows[4].includes("rejected"), rewardRows[4]);
  const rewardTally = await page.$eval("#rewardtally", (el) => el.textContent);
  assert(rewardTally.includes("1 of 5") && rewardTally.includes("Only the real check counts"), rewardTally);
  const flawedEnd = await page.$eval("#rewardflawedend", (el) => el.textContent);
  const realEnd = await page.$eval("#rewardrealend", (el) => el.textContent);
  assert(flawedEnd.includes("Real check fails."), flawedEnd);
  assert(realEnd.includes("Real 1.00") && realEnd.includes("Real check passes."), realEnd);
  const reward = await page.evaluate(() => window.__reward);
  assert(reward.steps === 121, "reward steps " + reward.steps);
  assert(reward.flawedProxy[reward.flawedProxy.length - 1] > reward.flawedProxy[0] + 0.25, "proxy rise");
  assert(reward.flawedHolds.every((v) => v === 0), "flawed search passed");
  assert(reward.realScore[reward.realScore.length - 1] === 1, "real end score");
  assert(reward.realHolds[reward.realHolds.length - 1] === 1, "real search hold");
  assert(reward.realHolds[0] === 0, "real search already passed");
  const rewardErr = await page.$eval("#rewarderr", (el) => el.hidden);
  assert(rewardErr, "reward error visible");
  await page.screenshot({ path: resolve(shotDir, "reward.png") });
  await page.evaluate(() => document.getElementById("harness").scrollIntoView({ block: "center" }));
  const harnessStat = await page.$eval("#harnessstat", (el) => el.textContent);
  assert(harnessStat.includes("20261104") && harnessStat.includes("8 tasks"), harnessStat);
  const harnessRows = await page.$$eval("#harnesstable tbody tr", (els) => els.map((el) => el.textContent.replace(/\s+/g, " ").trim()));
  assert(harnessRows.length === 4, "harness rows " + harnessRows.length);
  assert(harnessRows[0].includes("one-shot") && harnessRows[0].includes("1 of 8") && harnessRows[0].includes("7"), harnessRows[0]);
  assert(harnessRows[1].includes("retry") && harnessRows[1].includes("2 of 8") && harnessRows[1].includes("6"), harnessRows[1]);
  assert(harnessRows[2].includes("checked") && harnessRows[2].includes("8 of 8") && harnessRows[2].includes("0"), harnessRows[2]);
  assert(harnessRows[3].includes("budgeted") && harnessRows[3].includes("5 of 8") && harnessRows[3].includes("0"), harnessRows[3]);
  const harnessTask = await page.$eval("#harnesstask", (el) => el.options[el.selectedIndex].textContent);
  assert(harnessTask === "fib-3", harnessTask);
  const harnessWalk = await page.evaluate(() => window.__harnessWalk);
  assert(harnessWalk.length === 4, "walk " + harnessWalk.length);
  assert(harnessWalk[0].lines.some((line) => line.includes("index two") && line.includes("accepted")), "one-shot walk");
  assert(harnessWalk[1].result.includes("solved") && harnessWalk[1].lines.some((line) => line.includes("rejected")), "retry walk");
  assert(harnessWalk[2].solved === 1 && harnessWalk[2].lines.some((line) => line.includes("rejected") && line.includes("bad-parse")), "checked walk");
  assert(harnessWalk[2].lines.every((line) => !line.includes("  accepted  bad-") && !line.includes("  accepted  not-toward-base")), "checked kept a bad step");
  assert(harnessWalk[3].result.includes("not solved") && harnessWalk[3].solved === 0, "budget walk " + harnessWalk[3].result);
  await page.select("#harnesstask", "1");
  await page.waitForFunction(() => window.__harnessWalk && window.__harnessWalk[0].solved === 1);
  const fib1 = await page.evaluate(() => window.__harnessWalk.map((item) => item.result).join(" | "));
  assert(fib1.includes("solved") && !fib1.includes("not solved"), fib1);
  await page.select("#harnesstask", "2");
  const harnessErr = await page.$eval("#harnesserr", (el) => el.hidden);
  assert(harnessErr, "harness error visible");
  const stepsStat = await page.$eval("#stepsstat", (el) => el.textContent);
  assert(stepsStat.includes("12 solutions") && stepsStat.includes("Answer-only passes 11") && stepsStat.includes("Steps pass 4"), stepsStat);
  assert(stepsStat.includes("Only the steps count"), stepsStat);
  const stepRows = await page.$$eval("#stepstable tbody tr", (els) => els.map((el) => el.textContent.replace(/\s+/g, " ").trim()));
  assert(stepRows.length === 12, "step rows " + stepRows.length);
  assert(stepRows[0].includes("xor-00-right") && stepRows[0].includes("pass") && !stepRows[0].includes("fail"), stepRows[0]);
  assert(stepRows[1].includes("xor-10-cancel") && stepRows[1].includes("pass") && stepRows[1].includes("fail"), stepRows[1]);
  assert(stepRows[4].includes("xor-01-wrong") && stepRows[4].includes("fail"), stepRows[4]);
  const stepsOpen = await page.evaluate(() => window.__steps);
  assert(stepsOpen.which === 2 && stepsOpen.bad === 2 && stepsOpen.rule === "bad-value", JSON.stringify(stepsOpen));
  assert(stepsOpen.lines[1].includes("step h1") && stepsOpen.lines[1].includes("bad-value"), stepsOpen.lines[1]);
  await page.click("#stepsbody tr:nth-child(11) button");
  await page.waitForFunction(() => window.__steps && window.__steps.which === 11 && window.__steps.bad === 0);
  const sumRule = await page.$eval("#steprule", (el) => el.textContent);
  assert(sumRule.includes("Every step holds"), sumRule);
  await page.click("#stepsbody tr:nth-child(4) button");
  await page.waitForFunction(() => window.__steps && window.__steps.rule === "guessed-first");
  const guessLine = await page.$eval("#steplist li.halt", (el) => el.textContent);
  assert(guessLine.includes("answer 0") && guessLine.includes("guessed-first"), guessLine);
  const stepsErr = await page.$eval("#stepserr", (el) => el.hidden);
  assert(stepsErr, "steps error visible");
  const summaryStat = await page.$eval("#summarystat", (el) => el.textContent);
  assert(summaryStat.includes("8 problems") && summaryStat.includes("Summaries flagged 5"), summaryStat);
  assert(summaryStat.includes("3 of those sit on a wrong step"), summaryStat);
  assert(summaryStat.includes("2 are flagged while every checked step is correct"), summaryStat);
  const summaryRows = await page.$$eval("#summarytable tbody tr", (els) => els.map((el) => el.textContent.replace(/\s+/g, " ").trim()));
  assert(summaryRows.length === 8, "summary rows " + summaryRows.length);
  assert(summaryRows[1].includes("xor-smooth") && summaryRows[1].includes("smoother-story"), summaryRows[1]);
  const summaryOpen = await page.evaluate(() => window.__summaryDetail);
  assert(summaryOpen.which === 2 && summaryOpen.flag === "smoother-story", JSON.stringify(summaryOpen));
  assert(summaryOpen.sentences[0].mark === 1, "smooth sentence " + summaryOpen.sentences[0].text);
  assert(summaryOpen.stepLines.some((line) => line.mark === 1 && line.text.includes("checked-wrong") && line.text.includes("step h1 ")), JSON.stringify(summaryOpen.stepLines));
  await page.click("#summarybody tr:nth-child(4) button");
  await page.waitForFunction(() => window.__summaryDetail && window.__summaryDetail.which === 4 && window.__summaryDetail.flag === "phantom-step");
  const phantom = await page.evaluate(() => window.__summaryDetail);
  assert(phantom.stepLines.every((line) => line.mark !== 1), "phantom steps " + JSON.stringify(phantom.stepLines));
  assert(phantom.sentences[1].mark === 1 && phantom.sentences[1].text.includes("no such step"), phantom.sentences[1].text);
  await page.click("#summarybody tr:nth-child(7) button");
  await page.waitForFunction(() => window.__summaryDetail && window.__summaryDetail.flag === "none" && window.__summaryDetail.which === 7);
  const note = await page.evaluate(() => window.__summaryDetail);
  assert(note.stepLines.some((line) => line.mark === 2 && line.text.includes("not-checkable")), JSON.stringify(note.stepLines));
  const summaryErr = await page.$eval("#summaryerr", (el) => el.hidden);
  assert(summaryErr, "summary error visible");
  const lockedStat = await page.$eval("#lockedstat", (el) => el.textContent);
  assert(lockedStat.includes("19 of 19 statements passed"), lockedStat);
  assert(lockedStat.includes("cannot tell whether a spec is the right one"), lockedStat);
  const lockedRows = await page.evaluate(() => window.__locked);
  assert(lockedRows.length === 19, "locked rows " + lockedRows.length);
  assert(lockedRows.every((row) => row.status === "pass" && /^[0-9a-f]{64}$/.test(row.fp)), "locked row");
  assert(lockedRows[2].text.includes("14.0") && lockedRows[2].item === 3, lockedRows[2].name);
  assert(lockedRows[0].text.includes("118"), lockedRows[0].text.slice(0, 80));
  assert(lockedRows[15].item === 16 && lockedRows[15].text.includes("item 16 pass"), lockedRows[15].name);
  assert(lockedRows[16].item === 17 && lockedRows[16].text.includes("item 17 pass"), lockedRows[16].name);
  assert(lockedRows[17].item === 18 && lockedRows[17].text.includes("item 18 pass"), lockedRows[17].name);
  assert(lockedRows[18].item === 19 && lockedRows[18].text.includes("item 19 pass"), lockedRows[18].name);
  const recheckStat = await page.$eval("#recheckstat", (el) => el.textContent);
  assert(recheckStat.includes("agree on every case"), recheckStat);
  assert(recheckStat.includes("does not prove either checker right"), recheckStat);
  assert(recheckStat.includes("Both were written in this project"), recheckStat);
  const recheck = await page.evaluate(() => window.__recheck);
  assert(recheck.length === 3, "recheck rows " + recheck.length);
  assert(recheck[0].item === 11 && recheck[0].agree === 44 && recheck[0].total === 44, JSON.stringify(recheck[0]));
  assert(recheck[1].item === 12 && recheck[1].agree === 22 && recheck[1].total === 22, JSON.stringify(recheck[1]));
  assert(recheck[2].item === 15 && recheck[2].agree === 12 && recheck[2].total === 12, JSON.stringify(recheck[2]));
  const recheckCells = await page.$$eval("#rechecktable tbody tr", (els) => els.map((el) => el.textContent.replace(/\s+/g, " ").trim()));
  assert(recheckCells[0].includes("Wrong turns") && recheckCells[0].includes("44 of 44"), recheckCells[0]);
  assert(recheckCells[1].includes("Benchmark audit") && recheckCells[1].includes("22 of 22"), recheckCells[1]);
  assert(recheckCells[2].includes("Checked steps") && recheckCells[2].includes("12 of 12"), recheckCells[2]);
  const recheckErr = await page.$eval("#recheckmiss", (el) => el.textContent.trim());
  assert(recheckErr === "", "recheck disagree " + recheckErr);
  const statusStat = await page.$eval("#statusstat", (el) => el.textContent);
  assert(statusStat.includes("proved 12 of 19, tested 7, unchecked 0"), statusStat);
  assert(statusStat.includes("Tested is not proved"), statusStat);
  const status = await page.evaluate(() => window.__status);
  assert(status.rows.length === 19, "status rows " + status.rows.length);
  assert(status.summary === "proved 12 of 19, tested 7, unchecked 0", status.summary);
  assert(status.rows[0].item === 1 && status.rows[0].label === "proved" && status.rows[0].evidence.includes("checks 14"), JSON.stringify(status.rows[0]));
  assert(status.rows[2].item === 3 && status.rows[2].label === "proved" && status.rows[2].evidence.includes("414") && status.rows[2].evidence.includes("unproved 0"), status.rows[2].evidence);
  assert(status.rows[3].item === 4 && status.rows[3].label === "tested" && status.rows[3].evidence.includes("mlp_test"), status.rows[3].evidence);
  assert(status.rows[6].item === 7 && status.rows[6].label === "proved" && status.rows[6].evidence.includes("unproved 0") && status.rows[6].evidence.includes("proof/item_07.out"), status.rows[6].evidence);
  assert(status.rows[8].label === "proved" && status.rows[8].evidence.includes("live-ask unchecked"), status.rows[8].evidence);
  assert(status.rows[10].evidence.includes("TRACES_LLM_KEY"), status.rows[10].evidence);
  assert(status.rows[13].evidence.includes("HARNESS_LLM_KEY"), status.rows[13].evidence);
  assert(status.rows[12].item === 13 && status.rows[12].label === "proved" && status.rows[12].evidence.includes("proved for the accept/reject gate") && status.rows[12].evidence.includes("not proved:"), status.rows[12].evidence);
  assert(status.rows[14].item === 15 && status.rows[14].label === "proved" && status.rows[14].evidence.includes("proved for the step-grade rule"), status.rows[14].evidence);
  assert(status.rows[15].item === 16 && status.rows[15].label === "proved" && status.rows[15].evidence.includes("proved for the lock-compare rule"), status.rows[15].evidence);
  assert(status.rows[16].item === 17 && status.rows[16].label === "proved" && status.rows[16].evidence.includes("44 of 44") && status.rows[16].evidence.includes("proved for the agreement count"), status.rows[16].evidence);
  assert(status.rows[17].item === 18 && status.rows[17].label === "proved" && status.rows[17].evidence.includes("proved for the label rule") && status.rows[17].evidence.includes("not in this run"), status.rows[17].evidence);
  assert(status.rows[18].item === 19 && status.rows[18].label === "proved" && status.rows[18].evidence.includes("summary 22") && status.rows[18].evidence.includes("unproved 0"), status.rows[18].evidence);
  const statusCells = await page.$$eval("#statustable tbody tr", (els) => els.map((el) => el.textContent.replace(/\s+/g, " ").trim()));
  assert(statusCells.length === 19, "status cells " + statusCells.length);
  assert(statusCells[6].includes("proved") && statusCells[6].includes("unproved 0"), statusCells[6]);
  await page.evaluate(() => document.getElementById("status").scrollIntoView({ block: "center" }));
  await page.screenshot({ path: resolve(shotDir, "status.png") });
  await page.evaluate(() => document.getElementById("recheck").scrollIntoView({ block: "center" }));
  await page.screenshot({ path: resolve(shotDir, "recheck.png") });
  const lockedErr = await page.$eval("#lockederr", (el) => el.hidden);
  assert(lockedErr, "locked error visible");
  await page.evaluate(() => document.getElementById("locked").scrollIntoView({ block: "center" }));
  await page.screenshot({ path: resolve(shotDir, "locked.png") });
  await page.evaluate(() => document.getElementById("steps").scrollIntoView({ block: "center" }));
  await page.screenshot({ path: resolve(shotDir, "steps.png") });
  await page.screenshot({ path: resolve(shotDir, "harness.png") });
  const speedH = await page.$eval("#speed-base", (el) => el.getBoundingClientRect().height);
  assert(speedH >= 44, "speed height " + speedH);
  const speedBlurb = await page.$eval("#speedstat", (el) => el.textContent);
  assert(speedBlurb.includes("Yardstick") && speedBlurb.includes("95"), speedBlurb);
  await page.click("#speed-base");
  await page.waitForFunction(() => document.getElementById("speedstat").textContent.includes("Counted"), { timeout: 20000 });
  const speedBase = await page.$eval("#speedstat", (el) => el.textContent);
  assert(speedBase.includes("baseline") && speedBase.includes("passed"), speedBase);
  assert(!speedBase.includes("does not count"), speedBase);
  const baseUs = Number((/(\d+) microseconds of wasm wall time/).exec(speedBase)[1]);
  assert(baseUs > 0, "base us " + speedBase);
  await page.click("#speed-fast");
  await page.waitForFunction(() => document.getElementById("speedstat").textContent.includes("faster variant"), { timeout: 20000 });
  const speedFast = await page.$eval("#speedstat", (el) => el.textContent);
  assert(speedFast.includes("in place") && speedFast.includes("times the baseline"), speedFast);
  const fastUs = Number((/(\d+) microseconds of wasm wall time/).exec(speedFast)[1]);
  assert(fastUs > 0 && fastUs < baseUs, "fast us " + fastUs + " base " + baseUs);
  await page.evaluate(() => document.getElementById("speed").scrollIntoView({ block: "center" }));
  await page.screenshot({ path: resolve(shotDir, "speed.png") });

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
  await phonePage.evaluate(() => document.getElementById("turns").scrollIntoView({ block: "center" }));
  const phoneTurn = await phonePage.$eval("#turnsteps", (el) => el.textContent);
  assert(phoneTurn.includes("Wrong turn:"), "phone turn " + phoneTurn);
  await phonePage.evaluate(() => document.getElementById("audit").scrollIntoView({ block: "center" }));
  const phoneAudit = await phonePage.$eval("#auditlist", (el) => el.textContent);
  assert(phoneAudit.includes("answer-leaked"), "phone audit " + phoneAudit);
  assert(phoneAudit.includes("wrong-expected"), "phone audit flag");
  await phonePage.evaluate(() => document.getElementById("reward").scrollIntoView({ block: "center" }));
  const phoneReward = await phonePage.$eval("#rewardtable", (el) => el.textContent);
  assert(phoneReward.includes("reported-loss"), "phone reward " + phoneReward);
  assert(phoneReward.includes("two-of-four"), "phone reward gap");
  const phoneRewardEnd = await phonePage.$eval("#rewardrealend", (el) => el.textContent);
  assert(phoneRewardEnd.includes("passes"), "phone reward end " + phoneRewardEnd);
  await phonePage.evaluate(() => document.getElementById("harness").scrollIntoView({ block: "center" }));
  const phoneHarness = await phonePage.$eval("#harnesstable", (el) => el.textContent);
  assert(phoneHarness.includes("one-shot") && phoneHarness.includes("8 of 8"), "phone harness " + phoneHarness);
  const phoneHarnessTask = await phonePage.$eval("#harnesstask", (el) => el.getBoundingClientRect().height);
  assert(phoneHarnessTask >= 44, "phone harness select " + phoneHarnessTask);
  const phoneAuditFull = await phonePage.$eval("#auditfull", (el) => el.textContent);
  assert(phoneAuditFull.includes("Not accepted"), phoneAuditFull);
  const phoneTurnH = await phonePage.$eval("#turn-go-5", (el) => el.getBoundingClientRect().height);
  assert(phoneTurnH >= 44, "phone turn height " + phoneTurnH);
  const phoneTurnOverflow = await phonePage.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1);
  assert(phoneTurnOverflow, "phone turn overflows");
  const phoneRecOverflow = await phonePage.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1);
  assert(phoneRecOverflow, "phone rec overflows");
  await phonePage.evaluate(() => document.getElementById("mlp").scrollIntoView({ block: "center" }));
  const phoneHand = await phonePage.$eval("#w-hand", (el) => el.getBoundingClientRect().height);
  assert(phoneHand >= 44, "phone hand height " + phoneHand);
  const phoneSpeed = await phonePage.$eval("#speed-fast", (el) => el.getBoundingClientRect().height);
  assert(phoneSpeed >= 44, "phone speed height " + phoneSpeed);
  const phoneBlurb = await phonePage.$eval("#speedstat", (el) => el.textContent);
  assert(phoneBlurb.includes("Yardstick"), phoneBlurb);
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
  assert(await badPage.$eval("#speederr", (el) => !el.hidden && el.textContent.includes("cannot time")), "speed down");
  assert(await badPage.$eval("#speed-base", (el) => el.disabled), "speed still enabled");
  assert(await badPage.$eval("#attnerr", (el) => !el.hidden && el.textContent.includes("cannot tokenize")), "attn down");
  assert(await badPage.$eval("#attntext", (el) => el.disabled), "attn text still enabled");
  assert(await badPage.$eval("#recerr", (el) => !el.hidden && el.textContent.includes("cannot check a chain")), "recurse down");
  assert(await badPage.$eval("#turnerr", (el) => !el.hidden && el.textContent.includes("cannot check a next step")), "turns down");
  assert(await badPage.$eval("#auditerr", (el) => !el.hidden && el.textContent.includes("cannot audit")), "audit down");
  assert(await badPage.$eval("#rewarderr", (el) => !el.hidden && el.textContent.includes("cannot score")), "reward down");
  assert(await badPage.$eval("#harnesserr", (el) => !el.hidden && el.textContent.includes("cannot run the harnesses")), "harness down");
  assert(await badPage.$eval("#stepserr", (el) => !el.hidden && el.textContent.includes("cannot check the steps")), "steps down");
  assert(await badPage.$eval("#summaryerr", (el) => !el.hidden && el.textContent.includes("cannot compare a summary")), "summary down");
  assert(await badPage.$eval("#lockederr", (el) => !el.hidden && el.textContent.includes("cannot show the locked statements")), "locked down");
  assert(badErrors.length === 0, "nowasm errors " + badErrors);

  const html = readFileSync(resolve(root, "site/index.html"), "utf8");
  assert(!html.includes("__WASM_BASE64__"), "placeholder left in the page");
  assert(html.includes("id=\"ver\">" + stamp + "<"), "built badge");
  console.log("page ok", stamp, "lit", lit, "moved", moved);
} finally {
  await browser.close();
}
