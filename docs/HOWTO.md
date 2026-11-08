# How-To

A walkthrough for someone new to this repository, and possibly new to
Ada. The logic lives in Ada. JavaScript only draws. The live page is one
HTML file with that Ada compiled to WebAssembly inside it.

Visible stamp: **v0.22.0-askcheck**

Live page: https://robertboettchersf.github.io/ada-ai-amplifier/?v=0.22.0-askcheck

The yellow badge, `version.txt`, and `AI_Amplifier.Version.Version_Text`
are that same text. The query on the link is the cache bust (the stamp
without the leading `v`).

This guide is the install path, then a real kernel added end to end
(leaky ReLU), then a map of `src/`. The kernel in the guide is the
kernel in the library. There is no second copy to keep in step.

Item 7 proved the tensor kernels. The table is in section 8. CI job
`native, wasm, page` runs GNATprove at level 2 with a 120 second
timeout, via `./prove.sh`.
The how-to job below does not prove a second time.

## What you are building

From a clean Ubuntu machine you will:

1. Install Alire 2.1.1 and select the GNAT toolchain this repo uses.
2. Let `tools/get-toolchain.sh` download AdaWebPack 24 (the WebAssembly
   compiler). That script is the AdaWebPack install. There is no
   separate package.
3. Build the native programs and run the tests.
4. Build the WebAssembly module and the page, and open the page.

CI job `how-to steps` does this on a clean GitHub-hosted runner. The
command lists below are the scripts that job runs. A check fails the
job if a fence and its script differ.

## 1. Alire

Alire fetches the Ada compiler. This repo uses Alire 2.1.1,
`gnat_native` 16.1.0, and `gprbuild` 26.0.1.

```sh
curl -fsSL -o /tmp/alr.zip -L https://github.com/alire-project/alire/releases/download/v2.1.1/alr-2.1.1-bin-x86_64-linux.zip
mkdir -p "$HOME/.local"
unzip -o -q /tmp/alr.zip -d "$HOME/.local/alire-2.1.1"
export PATH="$HOME/.local/alire-2.1.1/bin:$PATH"
alr version
```

`alr version` should report 2.1.1. The CI job installs that same Alire
with `alire-project/setup-alire@v5` and selects
`gnat_native=16.1.0 gprbuild=26.0.1`. The script in section 4 selects
that toolchain again, so a local run and the runner do the same thing.

## 2. Node.js 22

The smokes are Node programs. `tools/page-smoke.mjs` needs
`puppeteer-core` from `npm ci`. CI installs Node 22 with
`actions/setup-node@v4`. On a machine:

```sh
curl -fsSL -o /tmp/node.tar.xz https://nodejs.org/dist/v22.23.4/node-v22.23.4-linux-x64.tar.xz
tar -xJf /tmp/node.tar.xz -C "$HOME/.local"
export PATH="$HOME/.local/node-v22.23.4-linux-x64/bin:$PATH"
node -v
npm -v
```

`node -v` should report `v22.23.4`.

## 3. Packages, AdaWebPack's libraries, and Chrome

AdaWebPack's download step needs `rpm2cpio`, `cpio`, `lld`, and
`libedit2`. The page smoke needs Google Chrome. These lines are
`tools/howto-packages.sh`.

<!-- quote:tools/howto-packages.sh -->
```sh
#!/bin/sh
# Packages named in docs/HOWTO.md. The CI job "how-to steps" runs this
# before tools/howto-steps.sh. The guide quotes this file.
set -e
sudo DEBIAN_FRONTEND=noninteractive apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  rpm2cpio cpio lld libedit2
wget -q -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y /tmp/chrome.deb
```

Run it from the repository root:

```sh
./tools/howto-packages.sh
```

## 4. Build, test, and open the page

`tools/howto-steps.sh` is the rest of the path. Run it from anywhere;
it changes to the repository root itself. Read it once so the names
mean something:

| Line | What it does |
|---|---|
| `alr -n toolchain --select …` | Puts GNAT 16.1.0 and gprbuild 26.0.1 on the Alire toolchain |
| `./tools/get-toolchain.sh` | Downloads AdaWebPack 24 into `toolchain/` (gitignored). Later runs see the compiler and return |
| `alr -n build` | Native build. Warnings and checks are on, including `-gnata`, so `Pre` and `Post` run |
| `./bin/hello` | Prints `ada-ai-amplifier v0.22.0-askcheck` |
| `./tools/check-version.sh` | That line, `version.txt`, and the badge in `web/template.html` must be the same stamp |
| `./bin/tensors_test` | Prints `tensors ok` |
| `./bin/mlp_test` | Prints `mlp ok` |
| `./bin/attention_test` | Prints `attention ok` |
| `./bin/recurse_test` | Prints `recurse ok` |
| `./bin/recurse_cli` | Replays the recorded chains. It does not call a model |
| `./bin/traces_test` | Prints `traces ok` |
| `./bin/traces_cli` | Replays the wrong-turn traces. It does not call a model |
| `./bin/audit_test` | Prints `audit ok` |
| `./bin/audit_cli` | Audits the built-in benchmark. The full-set score is not accepted |
| `./bin/reward_test` | Prints `reward ok` |
| `./bin/reward_cli` | Scores the five XOR submissions and prints both searches |
| `./bin/harness_test` | Prints `harness ok` |
| `./bin/harness_cli` | Prints the four harness rows. It does not call a model |
| `./bin/steps_test` | Prints `steps ok` |
| `./bin/steps_cli` | Prints the twelve step grades. A file whose steps fail exits 1 |
| `./bin/summary_test` | Prints `summary ok` |
| `./bin/summary_cli` | Prints the eight summaries beside the checked steps |
| `./bin/recheck_test` | Compares the two checkers. It prints `recheck ok` when every case agrees |
| `npm ci` | Installs `puppeteer-core` from the lockfile |
| `./build.sh` | Checks `STATUS`, runs the locked specs, compiles the library to WebAssembly, runs `tools/wasm-smoke.mjs`, writes `site/index.html`, `site/version.txt`, and `site/STATUS.txt` |
| `node tools/page-smoke.mjs` | Opens that page in headless Chrome: splash, tensor demo, leaky ReLU, training, the speed panel, tokens, recorded chains, wrong turns, the benchmark audit, the reward table, the harness table, the checked-steps table, the locked statements, the second checker, the checking-status table, F9, crash report, a failed module |

Then open `site/index.html` in a browser yourself. The badge reads
`v0.22.0-askcheck`. Leaky ReLU shows slope `0.01` and the output
`-0.02`, `0`, `3`. Compute still shows the product `14`, `14`, `17`.

The file, which CI runs as `./tools/howto-steps.sh`:

<!-- quote:tools/howto-steps.sh -->
```sh
#!/bin/sh
# Newcomer path. docs/HOWTO.md quotes this file.
# CI job "how-to steps" runs it on a clean Ubuntu runner after
# tools/howto-packages.sh, with Node 22 and Alire 2.1.1 on PATH.
set -e
cd "$(dirname "$0")/.."
alr -n toolchain --select gnat_native=16.1.0 gprbuild=26.0.1
./tools/get-toolchain.sh
alr -n build
./bin/hello
./tools/check-version.sh
./bin/tensors_test
./bin/mlp_test
./bin/attention_test
./bin/recurse_test
./bin/recurse_cli
./bin/traces_test
./bin/traces_cli
./bin/audit_test
./bin/audit_cli
./bin/reward_test
./bin/reward_cli
./bin/harness_test
./bin/harness_cli
./bin/steps_test
./bin/steps_cli
./bin/summary_test
./bin/summary_cli
./bin/recheck_test
npm ci
./build.sh
node tools/page-smoke.mjs
printf 'Open site/index.html in a browser. The badge should read %s.\n' "$(tr -d '\n' < version.txt)"
```

`build.sh` leaves runtime checks on. It does not pass `-gnatp`, and it
does not pass `--allow-undefined`. Before the wasm compile it runs
the locked specs and writes the body the page exports. It also
writes the second-checker report the page draws. The
module has no imports. A failed
check traps that module. The native test is where a bad slope or a bad
shape raises `Assertion_Error`.

`config/` and `alire/` are generated and gitignored. You do not commit
them.

## 5. Add a layer

Leaky ReLU is the worked example. It is already merged, so this section
is a reading order, not a patch to retype.

The rule, in `AI_Amplifier.Tensors`:

- The slope has to lie in `[0.0, 1.0]`. That is the `Pre`. A slope of
  `-0.1` or `1.5` raises `Assertion_Error` before the function looks at
  the vector.
- The result has the same length as the input. That is part of the
  `Post`.
- A positive component is copied. Any other component, including zero,
  is multiplied by the slope. That is the rest of the `Post`, checked
  when the function returns.
- Slope `0.0` is ReLU. Slope `1.0` copies the vector. The page uses
  `Negative_Slope`, which is `0.01`.
- An empty vector stays empty. There is nothing to multiply.

`0.01 * -2.0` is the first output. In `Float` that product is the value
the test expects. The page rounds it to six digits and shows `-0.02`.

Six places, in the order a change touches them:

1. **Spec.** `src/ai_amplifier-tensors.ads`, function `Leaky_ReLU` and
   the constant `Negative_Slope`. The package is SPARK. The `Post` is
   the Gold component rule: proved, and still checked when the
   function returns. `pragma Assertion_Policy (Pre => Check, Post => Check)`
   is what makes the contracts run. The project file also passes
   `-gnata`.
2. **Body.** `src/ai_amplifier-tensors.adb`, `Leaky_Of` and
   `Leaky_ReLU`. The body does the same split the `Post` describes, so
   the check agrees with the code. It does not call
   `Ada.Numerics`. This WebAssembly runtime has no `libm`.
3. **Test.** `src/tensors_test.adb`. Known values at slopes `0.01`,
   `0.0`, and `1.0`. Empty length. `Assertion_Error` on `-0.1` and
   `1.5`. Then the page wrapper: starting output, a bad index reads as
   `0.0`, and storing `4.0` in the first box comes back as `4.0`.
4. **Page wrapper.** `src/ai_amplifier-tensors-leaky_demo.ads` and
   `.adb`, package `AI_Amplifier.Tensors.Leaky_Demo`. It keeps one
   length-3 vector, starting at `(-2, 0, 3)`, calls `Leaky_ReLU` with
   `Negative_Slope`, and exports `aa_lrelu_set`, `aa_lrelu_in`,
   `aa_lrelu_run`, `aa_lrelu_out`, and `aa_lrelu_slope`. An index
   outside `1 .. 3` is ignored on the way in and reads as `0.0` on the
   way out, so a text box cannot raise. `aa_lrelu_slope` returns the
   Ada constant. The caption on the page is that return value, not a
   second number typed into the HTML.
5. **Link.** `build.sh` lists those five exports. Without that list,
   `--strip-all` drops them. `tools/wasm-smoke.mjs` and the `need`
   array in `web/template.html` name the same five. A missing export
   fails the smoke, and the page says the module did not load.
6. **Control.** The Leaky ReLU section in `web/template.html`. Three
   boxes, Apply, the slope, three outputs. JavaScript copies numbers
   in and copies numbers out. It does not multiply.

`bin/tensors_test` prints `tensors ok` when all of that holds.
`tools/wasm-smoke.mjs` checks the same starting vector inside the
module. `tools/page-smoke.mjs` checks the boxes.

A shape mismatch elsewhere is the same idea with a `Pre` on two
lengths. `Dot` requires equal lengths. The body also assigns one array
onto the other's bounds (`Checked_Length`), so a longer operand is not
silently dropped if assertions are ignored. `bin/tensors_test` expects
`Assertion_Error` for a short dot, which is what this build raises.
`Max_Extent` is 32. A larger length fails the range check on `Extent`
and raises `Constraint_Error`.

## 6. Code tour

Start at the top of `src/` and read down. Each unit says, in its own
header comment, whether it is in SPARK.

| Unit | File | What it does |
|---|---|---|
| `AI_Amplifier` | `src/ai_amplifier.ads` | Empty root. Child units are the library |
| `AI_Amplifier.Version` | `src/ai_amplifier-version.ads/.adb` | The stamp. Still `SPARK_Mode`. Exports `aa_version_length` and `aa_version_byte`. An index past either end returns the nearer end byte |
| `AI_Amplifier.Splash` | `src/ai_amplifier-splash.ads/.adb` | The drawing on the black screen. Coordinates `0 .. 1000`. Not a model, and not trained |
| `AI_Amplifier.Tensors` | `src/ai_amplifier-tensors.ads/.adb` | `Vector`, `Matrix`, and the kernels. SPARK. The level of each one is in section 8 |
| `AI_Amplifier.Tensors.Demo` | `src/ai_amplifier-tensors-demo.ads/.adb` | The 3 by 3 panel. Calls `Mat_Vec`, then `Softmax` |
| `AI_Amplifier.Tensors.Leaky_Demo` | `src/ai_amplifier-tensors-leaky_demo.ads/.adb` | The length-3 leaky ReLU panel |
| `AI_Amplifier.MLP` | `src/ai_amplifier-mlp.ads/.adb` | The 2–8–1 network. Seeded init, binary cross-entropy, backprop, gradient descent, the weight text, the hand-written XOR net |
| `AI_Amplifier.MLP.Demo` | `src/ai_amplifier-mlp-demo.ads/.adb` | The page's copy: dataset, rate, at most 32 steps per call, a 48 by 48 grid, the loss curve, the weight workbench |
| `AI_Amplifier.MLP.Speed` | `src/ai_amplifier-mlp-speed.ads/.adb` | The XOR training-speed harness. Baseline and faster variant, the step count, and the accept or reject. Plain Ada |
| `AI_Amplifier.BPE` | `src/ai_amplifier-bpe.ads/.adb` | Byte-level byte-pair encoding on one built-in excerpt. Encode and decode |
| `AI_Amplifier.Attention` | `src/ai_amplifier-attention.ads/.adb` | One causal self-attention block, forward only. The weights are a seed |
| `AI_Amplifier.Attention.Demo` | `src/ai_amplifier-attention-demo.ads/.adb` | The page's text buffer. Bytes in, token pieces and weights out |
| `AI_Amplifier.Recurse` | `src/ai_amplifier-recurse.ads/.adb` | The Fibonacci state blob and the checker. Plain Ada |
| `AI_Amplifier.Recurse.Demo` | `src/ai_amplifier-recurse-demo.ads/.adb` | The page's recorded chains. No network |
| `AI_Amplifier.Traces` | `src/ai_amplifier-traces.ads/.adb` | Four wrong turns of the XOR trainer, and the next-step checker. Plain Ada |
| `AI_Amplifier.Traces.Demo` | `src/ai_amplifier-traces-demo.ads/.adb` | The page's trace and verdict. No network |
| `AI_Amplifier.Audit` | `src/ai_amplifier-audit.ads/.adb` | The benchmark auditor. Recomputes, flags, then scores. Plain Ada |
| `AI_Amplifier.Audit.Demo` | `src/ai_amplifier-audit-demo.ads/.adb` | The page's audit report. No network |
| `AI_Amplifier.Audit.Manifest` | `src/ai_amplifier-audit-manifest.ads` | Planted ids and rules. The auditor does not read it |
| `AI_Amplifier.Reward` | `src/ai_amplifier-reward.ads/.adb` | Two graders for the XOR task, five submissions, and the hill-climb. Plain Ada |
| `AI_Amplifier.Reward.Demo` | `src/ai_amplifier-reward-demo.ads/.adb` | The page's table and the two search curves |
| `AI_Amplifier.Harness` | `src/ai_amplifier-harness.ads/.adb` | One fixed solver and four harnesses. Plain Ada |
| `AI_Amplifier.Harness.Demo` | `src/ai_amplifier-harness-demo.ads/.adb` | The page's score table and one task's four walks. No network |
| `AI_Amplifier.Steps` | `src/ai_amplifier-steps.ads/.adb` | Twelve solutions and the two grades. Plain Ada |
| `AI_Amplifier.Steps.Demo` | `src/ai_amplifier-steps-demo.ads/.adb` | The page's table and the selected solution's steps |
| `AI_Amplifier.Steps.Manifest` | `src/ai_amplifier-steps-manifest.ads` | Planted flaws. The checker does not read it |
| `AI_Amplifier.Locked` | `src/ai_amplifier-locked.ads/.adb` | The page's locked statements. The wasm body is generated from the spec run |
| `AI_Amplifier.Recheck` | `src/ai_amplifier-recheck.ads/.adb` | The second checker for items 11, 12, and 15. Plain Ada. It does not call the first checkers |
| `Hello` | `src/hello.adb` | Prints the stamp. Native only |
| `Recurse_Cli` | `src/recurse_cli.adb` | Replays the chains. Calls a model only when the user sets a key, a URL, and a model name. Native only |
| `Traces_Cli` | `src/traces_cli.adb` | Replays the wrong-turn traces. Calls a model only when the user sets a key, a URL, and a model name. Native only |
| `Audit_Cli` | `src/audit_cli.adb` | Audits the built-in benchmark, or one task file. Native only |
| `Reward_Cli` | `src/reward_cli.adb` | Prints the submission table and runs either search. Native only |
| `Harness_Cli` | `src/harness_cli.adb` | Prints the harness table. Calls a model only when the user sets a key, a URL, and a model name. Native only |
| `Steps_Cli` | `src/steps_cli.adb` | Prints the step table, or grades one solution file. Native only |
| `Summary_Cli` | `src/summary_cli.adb` | Prints the eight summaries beside the checked steps. Native only |
| `Tensors_Test`, `MLP_Test`, `Attention_Test`, `Recurse_Test`, `Traces_Test`, `Audit_Test`, `Reward_Test`, `Harness_Test`, `Steps_Test`, `Summary_Test` | `src/tensors_test.adb`, `src/mlp_test.adb`, `src/attention_test.adb`, `src/recurse_test.adb`, `src/traces_test.adb`, `src/audit_test.adb`, `src/reward_test.adb`, `src/harness_test.adb`, `src/steps_test.adb`, `src/summary_test.adb` | Native tests. They use `Ada.Text_IO`, so `build.sh` does not compile them into the module |

`Vector` and `Matrix` carry their shape as a discriminant (`Length`, or
`Rows` and `Cols`). Components are `Float`, indexed `1 ..` that bound.
A mix-up of two lengths is a failed `Pre`, not a wrong answer. The
README tables say which kernel requires which agreement.

The page wrappers are the place a bad index is swallowed. The kernels
under them still check shapes. On the native runtime a failed `Pre`
raises. On the WebAssembly runtime the same check traps the module,
because that runtime cannot propagate an exception.
`tools/wasm-checks.c` supplies the two symbols the trap calls, and the
link has no imports.

JavaScript does not compute the splash, the product, the softmax, the
leaky ReLU, the loss, the decision boundary, the weight text, the
merges, the attention, the chain check, the training-speed verdict,
or the wrong-turn verdict, or the reward scores, or the harness table,
or the step grades, or the summary comparison, or the locked statements, or the second-checker
agreement. The comparison is a file this build writes.
It reads coordinates, copies numbers, and sends UTF-8 bytes. On the
speed panel it passes in two host wall-clock readings. Ada subtracts them.
It adds up attention weights it already read, when it writes the
sentence under the heatmap. That sum is named in the README honesty
list. If the module is missing, not WebAssembly, missing an export, or
its stamp differs from the badge, the page says "The Ada module did
not load" and still shows the title and the badge.

The numbers behind the panels are in the README: the 3 by 3 product,
the network's seed and datasets, the BPE excerpt, the hand-computed
attention pass. This tour is the map. That file is the specification.

## 7. House rules

These are adapted from the owner's How-To (visible stamp, plan then Go,
one item, honesty, a pre-push list, F9). `CONTRIBUTING.md` is the same
rules as a checklist. The gist-and-githack parts of that How-To do not
apply here: this page is GitHub Pages, and the repository is public.

**Visible stamp.** The badge is on every screen, including when
JavaScript is off, and it is omitted when printing. Bump it when the
page or the library a visitor runs would differ. Do not reuse a stamp.
Put the same text in `Version_Text`, `version.txt`, the badge, and the
Alire version without the leading `v`. Pages deploys from `main`.
Before telling anyone a stamp is live, fetch the page and
`version.txt` and see that text. The link you send carries `?v=` set
to the stamp without the `v`. A screenshot of the new page shows the
new badge.

**Plan, then Go, then one item.** Post a numbered plan for one change.
Wait for Go. Build that item. Report, and stop. Items 1 through 20 are
done. Item 15 is the checked-steps demo. Item 16 is the locked
statements: a fixed spec per finished item, and a CI gate that fails
if a spec's fingerprint changes without `specs/LOCK`, or if
`pragma Assume` or `pragma Annotate` appear. Item 17 is a second Ada
checker, written separately, for the verdicts of items 11, 12, and
15. CI fails if the two checkers disagree. Item 18 labels
items 1–19 proved, tested, or unchecked, from the build logs.
The summary is proved 12 of 19, tested 7, unchecked 0. Item 18
is proved for the label rule. Reading the logs is not proved.
CI fails if `STATUS` is not that report, and
it fails if a built item is missing from `STATUS`. Tested is not
proved. Item 19 is the reasoning summary set against the
checked steps. Item 20 is this repository's README: one line per
item, with the label from `STATUS`. Item 21 proved five small
rules. Item 22 checks the three `--ask` commands against a
stand-in model. No real model is called. Items 23 and 24
are still planned. Ideas inspired by the
Challenge/Solution split, the comparator, and the independent kernel
check in [formal-math](https://github.com/anthropics/formal-math)
(Apache-2.0), and by results at different stages of verification
and reasoning summaries in
[openai/math](https://github.com/openai/math) (Apache-2.0).
Items 16, 17, 18, and 19 are
independent reimplementations. No code was copied. The links are
not an endorsement, and Anthropic and OpenAI are not involved in
this repository.

**Honesty.** Say what is checked at run time and what a prover has
seen. On the tensor kernels, Silver means no run-time error and Gold
means the component rule. Sigmoid, tanh, and softmax are Silver: the
result lies in range, and the series is not the real function. The
splash, the MLP, the tokenizer, attention, the reward demo,
the harness comparison, the step checker, and the second checker are not proved.
The Fibonacci step rule, the next-step verdict, and the audit score
gate are proved in their own runs. The parsers and the live callers are not. `Pre`
and `Post` are still ordinary Ada contracts, checked when the program
runs. `Float` results are approximate; the tests name the tolerance.
The spirals are not solved. The attention weights are a seed.

**Pre-push.** Was the previous behaviour still there (splash, tensor
demo, leaky ReLU, training, tokens, recorded chains, wrong turns, the benchmark audit, the reward table, the harness table, the checked-steps table, the locked statements, the second checker, F9, crash report, badge)? Does the
new behaviour work? `./tools/howto-steps.sh` is the long check, after
the packages and the compilers are installed. `./tools/check-version.sh`
is the stamp check. Docs that name a number should name the number the
code uses.

**F9.** Feedback, or the Feedback button, asks for a short note and
writes `feedback-*.json`. The file has the stamp, the browser, the
screen, and the recent UI events, plus the note. An empty note is
refused. A crash report is separate: the previous visit did not end
cleanly, or the module trapped. Read the stamp in the file first. It
tells you which build the note is about.

## 8. Proof status

`./prove.sh` runs GNATprove at level 2, timeout 120 seconds. CI job `native, wasm, page`
does that. The how-to steps above do not. An unproved check
fails the run. There is no `pragma Annotate` and no `pragma Assume`.
The logs are `proof/item_NN.out`, one run per proved item. The same table is on the live page.

| Kernel | Level |
|---|---|
| Dot | Silver |
| Mat-vec | Silver |
| Mat-mat | Silver |
| Add | Gold |
| Scale | Gold |
| Transpose | Gold |
| ReLU | Gold |
| Leaky ReLU | Gold |
| Sigmoid | Silver |
| Tanh | Silver |
| Softmax | Silver |
| Splash | not proved |
| MLP | not proved |
| Training speed | not proved |
| Tokenizer | not proved |
| Attention | not proved |
| Recursive prompts | rule proved |
| Wrong turns | rule proved |
| Benchmark audit | rule proved |
| Reward hacking | rule proved |
| Harness comparison | not proved |
| Checked steps | rule proved |
| Locked statements | rule proved |
| Second checker | rule proved |
| Checking status | rule proved |
| Reasoning summary | rule proved |

Silver on dot and the two products means no run-time error, and the
numeric result lies in `[-Acc_Bound, Acc_Bound]`. It does not mean the
value was proved equal to the mathematical product. Silver on sigmoid,
tanh, and softmax means each component lies in range (`[0, 1]`,
`[-1, 1]`, and `[0, 1]`) and the arithmetic does not overflow. The
series is not proved equal to the real function. Gold means the `Post`
states the component rule and the prover discharged it.

The bounds that make the sums safe are `Summand_Bound` (`1.0E18`),
`Product_Bound` (`2.0E36`), `Acc_Bound` (`2.0E38`), and `Logit_Bound`
(`1.0E38`). The README says why each one is that number. A component
outside the bound fails the `Pre`.

The splash, the page wrappers, the MLP, the tokenizer, attention,
the chain checker, the wrong-turn checker, the benchmark
auditor, the reward demo, the harness comparison, the step checker, and the second checker are plain Ada. Their tests are tests. The weight
text and the hand-written XOR net live in the MLP unit, so they are
tests too. `docs/WEIGHT_SPACE.md` is that account.
`docs/RECURSIVE_PROMPTS.md` is the account of the recorded chains.
`docs/WRONG_TURNS.md` is the account of the four trainer traces.
`docs/BENCHMARK_AUDIT.md` is the account of the benchmark auditor.
`docs/REWARD_HACKING.md` is the account of the two graders.
`docs/HARNESS.md` is the account of the four harnesses.
`docs/CHECKED_STEPS.md` is the account of the two grades.
`docs/SECOND_CHECKER.md` is the account of the agreement.
`docs/CHECKING_STATUS.md` is the account of the labels.
`docs/REASONING_SUMMARY.md` is the account of the summaries.
The flag rules in `AI_Amplifier.Summary_Rules` are a separate
proof of 22 checks. That proof does not cover the summaries
or the step checker. The flag rules are proved. The summaries
are not.
`AI_Amplifier.Version` is SPARK,
with the contracts from the skeleton. The stamp there is
`v0.22.0-askcheck`.
