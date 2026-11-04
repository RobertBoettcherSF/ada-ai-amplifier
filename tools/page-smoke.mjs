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
  assert(items.length === 7, "backlog length " + items.length);
  assert(items[1].includes("Splash and live page") && items[1].includes("done"), items[1]);
  assert(items[2].includes("Core tensor and maths") && items[2].includes("done"), items[2]);
  assert(items[3].includes("Tiny trainable MLP") && items[3].includes("done"), items[3]);
  assert(items[4].includes("Byte-level BPE") && items[4].includes("not started"), items[4]);
  assert(items[5].includes("Contributor How-To") && items[5].includes("not started"), items[5]);
  assert(items[6].includes("SPARK proofs of the kernels") && items[6].includes("not started"), items[6]);
  const hrefs = await page.$$eval("#links a", (els) => els.map((a) => a.href));
  assert(hrefs.some((h) => h === "https://github.com/RobertBoettcherSF/ada-ai-amplifier"), "repo link " + hrefs);
  assert(hrefs.some((h) => h.includes("README.md#using-the-page")), "howto link " + hrefs);
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1);
  assert(overflow, "desktop main overflows");
  const numbered = await page.$$eval("#backlog .n", (els) => els.map((el) => el.textContent.trim()));
  assert(numbered.join(" ") === "1. 2. 3. 4. 5. 6. 7.", "backlog numbers " + numbered);
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

  await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
  const covered = await page.evaluate(() => {
    const link = document.querySelector("#links a[href*='using-the-page']").getBoundingClientRect();
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
  const phoneTrain = await phonePage.$eval("#train", (el) => el.getBoundingClientRect().height);
  assert(phoneTrain >= 44, "phone train height " + phoneTrain);
  const phoneFont = await phonePage.$eval("#rate", (el) => parseFloat(getComputedStyle(el).fontSize));
  assert(phoneFont >= 16, "phone rate font " + phoneFont);
  await phonePage.evaluate(() => document.getElementById("mlp").scrollIntoView({ block: "center" }));
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
    const link = document.querySelector("#links a[href*='using-the-page']").getBoundingClientRect();
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
  assert(await badPage.$eval("#mlperr", (el) => !el.hidden && el.textContent.includes("cannot train")), "mlp down");
  assert(await badPage.$eval("#train", (el) => el.disabled), "train still enabled");
  assert(badErrors.length === 0, "nowasm errors " + badErrors);

  const html = readFileSync(resolve(root, "site/index.html"), "utf8");
  assert(!html.includes("__WASM_BASE64__"), "placeholder left in the page");
  assert(html.includes("id=\"ver\">" + stamp + "<"), "built badge");
  console.log("page ok", stamp, "lit", lit, "moved", moved);
} finally {
  await browser.close();
}
