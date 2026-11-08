# ada-ai-amplifier

Readable AI building blocks in Ada. The tensor kernels are SPARK.
The rest of the logic is plain Ada. JavaScript only draws, and writes
the feedback and crash files.
The splash on the live page is a small picture of a network: Ada moves
the points, and the page plots them.

Visible stamp: **v0.13.0-reward**

The same text is `AI_Amplifier.Version.Version_Text`, the yellow badge in
`web/template.html`, `version.txt`, and the line printed by `bin/hello`.
The Alire crate version is `0.13.0-reward` (the stamp without the leading
`v`, because Alire versions are semver).

**Live page:** https://robertboettchersf.github.io/ada-ai-amplifier/?v=0.13.0-reward

**Guide:** [docs/HOWTO.md](docs/HOWTO.md). The page links there. It is the install path, a walkthrough that adds leaky ReLU, and the code tour.

`.github/workflows/pages.yml` builds `site/` and deploys it with GitHub
Actions. The query is the cache bust. `version.txt` is published next to
the page.

## Goal

A small library a person can read from the spec down: tensors and the math
under them, a tiny trainable MLP, a byte-level BPE tokenizer, and one
transformer attention block. The parts that run in the browser are compiled
from that Ada to WebAssembly and embedded in one HTML file.

Item 3 is the tensor kernels and a 3 by 3 demo on the page. Item 7
is the proof of those kernels. Item 4 is a real network on those kernels: eight tanh units, one
sigmoid output, trained by gradient descent. Item 5 is a byte-level
BPE tokenizer and one causal attention block, forward only. The splash
is still a drawing. It is not trained. The attention weights are a
seed, not a fit. Item 6 is the contributor guide, and the leaky ReLU
kernel that guide adds. Item 7 proves the tensor kernels. The
network, the tokenizer, and attention stay plain Ada. Item 8 writes
that network's weights as text, loads a hand-written XOR net that was
never trained, and edits one weight at a time on the page.
[docs/WEIGHT_SPACE.md](docs/WEIGHT_SPACE.md) says what that does and
does not show. Item 9 checks a Fibonacci state blob that stands in
for a prompt calling itself. The page replays recorded chains. It
does not call a model. [docs/RECURSIVE_PROMPTS.md](docs/RECURSIVE_PROMPTS.md)
is that account. Item 10 is a training-speed harness for the XOR
trainer: a slow baseline, one tighter variant, and a clock that
counts only when the loss and the four answers still pass.
[docs/TRAINING_SPEED.md](docs/TRAINING_SPEED.md) is that account.
Item 11 records four wrong turns of that same trainer. Ada runs a
proposed next step and judges it: the loss, the four XOR answers,
and whether the weights are still valid.
[docs/WRONG_TURNS.md](docs/WRONG_TURNS.md) is that account. The page
does not call a model. Item 12 is a twenty-task benchmark about
this repository's own XOR labels, Fibonacci checker, and weight
files. Five tasks are broken on purpose. Ada audits every task
before it will accept a score.
[docs/BENCHMARK_AUDIT.md](docs/BENCHMARK_AUDIT.md) is that account.
Item 13 scores one XOR task with two graders. The flawed grader
trusts a low reported loss, or two outputs above 0.5, or an answer
that only looks finished. The real check reruns the net and requires
every XOR output inside 0.8 and 0.2. Four written cheats pass the
flawed grader and fail the real one. A hill-climb from the trainer's
seed climbs either score.
[docs/REWARD_HACKING.md](docs/REWARD_HACKING.md) is that account.
Items 14 through 16 are planned and not started.

## Why plain Ada

1. **Strong typing.** Ranks, index ranges, and token ids can be types in the
   source, so a mix-up is a compile error.
2. **Range checks.** A bad index fails at the line that made it. The native
   build leaves checks on. The WebAssembly build does too (`-gnata`, and
   `-gnatp` is not used).
3. **SPARK, on the tensor kernels.** `AI_Amplifier.Tensors` and
   `AI_Amplifier.Version` are `SPARK_Mode`. CI runs GNATprove at level 2
   (`./prove.sh`). The splash, the page wrappers, the MLP, the tokenizer,
   and attention are `SPARK_Mode => Off` on purpose.
4. **No hidden library dependencies.** `alire.toml` depends on no other
   crate. GNAT, GNATprove, AdaWebPack, and `wasm-ld` are build tools. They
   are not linked into the library as a third-party ML stack.

## Using the page

| Control | What it does |
|---|---|
| Tap the splash, or Enter | Leaves the splash and shows this project |
| Tensor demo | Nine matrix boxes, three vector boxes, Compute. Ada returns the product and its softmax |
| Leaky ReLU | Three boxes and Apply. Ada keeps a positive number and multiplies any other by the slope it reports |
| Train | Runs gradient descent on the small network. Stop is the same button |
| Dataset | XOR, two circles, or two spirals. Changing it resets the weights and keeps the learning rate |
| Learning rate | The step size Ada uses. The page control runs from 0.01 to 2. Lower and raise are the minus and plus buttons |
| Reset | Restores the seeded weights for the current dataset |
| Weights | Slider and number for every weight. Ada stores the value and redraws the boundary |
| Reset to trained | Puts back the last training step, or the seeded start if training has not run |
| Hand-written XOR | Loads weights that solve XOR with no training step. Hidden 1 is OR, hidden 2 is AND |
| Run baseline | Times the straightforward XOR trainer. Ada reports steps, time, and whether the check passed |
| Run faster variant | Times the same updates with the in-place step. Ada compares it with the baseline on this page |
| Download / Upload | Ada writes the weight text, and Ada checks a file before it replaces the net |
| Flip, Silence, Invert | Three fixed edits. Each one changes weights and does not train |
| Text box | Sends the text to Ada as UTF-8 bytes. Ada splits it with byte-level BPE and runs one causal attention block. The page paints the pieces and the heatmap |
| Recorded chains | Ada replays four saved Fibonacci blobs and stops at the first failed check. The page does not call a model |
| Wrong turns | Pick a recorded trace and a next step. Ada runs that step on the XOR trainer and reports whether it fixes the net |
| Benchmark audit | Ada flags each task, then scores the same samples on the full set and on the set with flagged tasks removed |
| Reward hacking | Ada scores five XOR submissions with a flawed grader and the real check, then draws two hill-climb curves |
| Feedback, or F9 | Asks for a short note, then writes `feedback-*.json` (version, browser, screen, the recent UI events, and the note). On a phone that can share files, it offers the share sheet |
| Crash report | If the previous visit did not end cleanly, or the module traps, a panel offers `crash-report-*.json` |
| Yellow badge | The stamp, on every screen, including when JavaScript is off |

If the WebAssembly module does not load, the page says so in words. It does
not stay blank. Continue still opens the text below the splash.

The badge is `position: fixed` at the bottom right, above the splash. It is
omitted when printing.

## Layout

| Path | What it is |
|---|---|
| `src/ai_amplifier.ads` | Library root. Empty on purpose |
| `src/ai_amplifier-version.ads/.adb` | Stamp, plus `aa_version_length` and `aa_version_byte` |
| `src/ai_amplifier-splash.ads/.adb` | Splash graph. Plain Ada (`SPARK_Mode => Off`). Exports `aa_splash_reset`, `aa_splash_tick`, `aa_step`, `aa_count`, `aa_get` |
| `src/ai_amplifier-tensors.ads/.adb` | `Vector`, `Matrix`, and the kernels. SPARK. `Max_Extent` is 32. Levels are in the proof status table |
| `src/ai_amplifier-tensors-demo.ads/.adb` | The page's 3 by 3 panel. Calls `Mat_Vec` and `Softmax` |
| `src/ai_amplifier-tensors-leaky_demo.ads/.adb` | The page's length-3 leaky ReLU. Calls `Leaky_ReLU` at `Negative_Slope` |
| `src/ai_amplifier-mlp.ads/.adb` | The 2–8–1 network. Init, loss, backprop, gradient descent, the weight text, the hand-written XOR net. Plain Ada |
| `src/ai_amplifier-mlp-demo.ads/.adb` | The page's copy of that network. Dataset, rate, steps, grid, loss curve, the weight workbench |
| `src/ai_amplifier-mlp-speed.ads/.adb` | The XOR training-speed harness. Baseline, faster variant, and the accept or reject |
| `docs/WEIGHT_SPACE.md` | What the weight text shows, and what it does not claim |
| `docs/TRAINING_SPEED.md` | The speed harness, the recorded times, and what it does not claim |
| `src/ai_amplifier-bpe.ads/.adb` | Byte-level BPE. Learns merges from one excerpt. Encode and Decode |
| `src/ai_amplifier-attention.ads/.adb` | One causal self-attention block. Embeddings, Q/K/V, mask, residual, layer norm |
| `src/ai_amplifier-attention-demo.ads/.adb` | The page's buffer. Bytes in, token pieces and weights out |
| `src/ai_amplifier-recurse.ads/.adb` | The Fibonacci state blob and the step checker. Plain Ada |
| `src/ai_amplifier-recurse-demo.ads/.adb` | The page's four recorded chains |
| `docs/RECURSIVE_PROMPTS.md` | What those chains show, and what they do not claim |
| `src/recurse_test.adb` | Native tests. The rules, the four chains, the page wrapper, and a stand-in for the model caller |
| `src/recurse_cli.adb` | Native program. Replays the chains. Calls a model only when the user sets a key, a URL, and a model name |
| `src/ai_amplifier-traces.ads/.adb` | Four recorded wrong turns of the XOR trainer, and the next-step checker. Plain Ada |
| `src/ai_amplifier-traces-demo.ads/.adb` | The page's trace, menu, and verdict |
| `docs/WRONG_TURNS.md` | What those traces show, and what they do not claim |
| `src/ai_amplifier-audit.ads/.adb` | The benchmark auditor. Recomputes answers, flags five kinds of defect, and refuses a score that still includes a flag. Plain Ada |
| `src/ai_amplifier-audit-demo.ads/.adb` | The page's audit report and the two score lines |
| `src/ai_amplifier-audit-manifest.ads` | The planted task ids and rules. The auditor does not with this unit |
| `docs/BENCHMARK_AUDIT.md` | What the audit shows, and what it does not claim |
| `src/audit_test.adb` | Native tests. The planted list, a second file with the same breaks, the page wrapper, and `audit_cli` |
| `src/audit_cli.adb` | Native program. Audits the built-in file, or a task file given on the command line |
| `src/ai_amplifier-reward.ads/.adb` | Two graders for the XOR task, five submissions, and the hill-climb. Plain Ada |
| `src/ai_amplifier-reward-demo.ads/.adb` | The page's table and the two search curves |
| `docs/REWARD_HACKING.md` | What that demo shows, and what it does not claim |
| `src/reward_test.adb` | Native tests. Every cheat fails the real check. The honest net passes both. Both searches |
| `src/reward_cli.adb` | Native program. Prints the table and runs either search |
| `src/traces_test.adb` | Native tests. The rules, the four traces, the page wrapper, and a stand-in for the model caller |
| `src/traces_cli.adb` | Native program. Replays the traces. Calls a model only when the user sets a key, a URL, and a model name |
| `src/hello.adb` | Native program. Prints the stamp. Also calls the splash so the native build compiles it |
| `src/tensors_test.adb` | Native tests. Known values, empty shapes, large logits, mismatches |
| `src/mlp_test.adb` | Native tests. XOR, the circles, a central-difference gradient check, the weight text, the hand-written net |
| `src/attention_test.adb` | Native tests. BPE round trip, the hand-computed attention pass, the mask |
| `web/template.html` | Page source. `build.sh` replaces `__WASM_BASE64__` |
| `site/index.html` | Built page, gitignored. GitHub Pages publishes the `site/` directory |
| `version.txt` | The same stamp, one line |
| `build.sh` | AdaWebPack 24 to `obj/wasm/ai_amplifier.wasm`, smoke, then `site/index.html` |
| `prove.sh` | GNATprove level 2 on the SPARK units. Writes `proof/`. CI runs it |
| `tools/get-toolchain.sh` | Downloads the wasm compiler into `toolchain/` (gitignored) |
| `tools/wasm-smoke.mjs` | Node: stamp, no wasm imports, splash numbers, product and softmax, leaky ReLU, XOR training, the weight text, BPE round trip, attention rows, the wrong-turn checker, the benchmark audit, the reward table and both searches |
| `tools/page-smoke.mjs` | Headless Chrome: splash, the tensor panel, leaky ReLU, the training panel, the weight workbench, the speed panel, the token panel, the recorded chains, the wrong-turn panel, the benchmark audit, the reward table and curves, Enter, tap, F9, crash panel, failed module |
| `tools/howto-steps.sh` | The commands in the How-To. CI job `how-to steps` runs this file |
| `docs/HOWTO.md` | Newcomer guide |
| `CONTRIBUTING.md` | Stamp, one item at a time, honesty, the pre-push list, F9 |
| `tools/wasm-checks.c` | Wasm-only. A failed check traps. Not linked into the native build |
| `proof/gnatprove.out` | Level 2 proof log for the root, the version unit, and the tensors. No `pragma Annotate`, no `pragma Assume` |

`config/` and `alire/` are generated by Alire and gitignored.

## Build the native program

Tools used here: Alire 2.1.1, `gnat_native` 16.1.0, `gprbuild` 26.0.1.

```sh
alr -n toolchain --select gnat_native=16.1.0 gprbuild=26.0.1
alr -n build
./bin/hello
./tools/check-version.sh
```

`alr build` uses Alire's development profile (warnings and GNAT style checks
on). Expected line:

```text
ada-ai-amplifier v0.13.0-reward
```

Then:

```sh
./bin/tensors_test
./bin/mlp_test
./bin/attention_test
./bin/recurse_test
./bin/traces_test
./bin/audit_test
./bin/audit_cli
./bin/reward_test
./bin/reward_cli
```

Expected lines:

```text
tensors ok
mlp ok
attention ok
recurse ok
traces ok
audit ok
reward ok
```

`audit_cli` prints the twenty lines and the two score sentences.
The full-set sentence says the score is not accepted.
`reward_cli` prints the five submissions and the two search
sentences. Only the real check counts.

## Proof status

CI runs `./prove.sh`. That is GNATprove from the `gnatprove=16.1.0`
crate (tool id `FSF 16.1.0` in `proof/version.txt`). The project file
passes `--level=2`, `--timeout=120`, `--report=all`, and
`--checks-as-errors=on`. Level 2 selects the provers. The timeout is
120 seconds because level 2's own few-second timeout stopped three
checks on the CI runner that had already proved on a faster machine.
An unproved check fails the run. There is no `pragma Annotate` and
no `pragma Assume`.

```sh
alr -n install gnatprove=16.1.0
export PATH="$HOME/.alire/bin:$PATH"
./prove.sh
```

`./prove.sh` installs that crate if `gnatprove` is not already on
`PATH`, then copies `proof/gnatprove.out`.

Proved units: the empty root `AI_Amplifier`, `AI_Amplifier.Version`,
and `AI_Amplifier.Tensors` (the kernels and the small helpers in that
body). `hello.adb`, the test procedures, `AI_Amplifier.Splash`,
the tensor demo children, `AI_Amplifier.MLP` and its demo,
`AI_Amplifier.BPE`, `AI_Amplifier.Attention` and its demo, and
`AI_Amplifier.Recurse` and its demo, and `AI_Amplifier.Traces`
and its demo, and `AI_Amplifier.Audit`, its demo, and its manifest,
and `AI_Amplifier.Reward` and its demo,
are `SPARK_Mode => Off`. `recurse_cli.adb`,
`traces_cli.adb`, `audit_cli.adb`, `reward_test.adb`,
and `reward_cli.adb` are too. GNATprove lists them and proves nothing
in them.

| Kernel | Level | What is proved |
|---|---|---|
| `Dot` | Silver | No run-time error. The result lies in `[-Acc_Bound, Acc_Bound]`. The value is not proved equal to the mathematical dot product |
| `Mat_Vec` | Silver | No run-time error. Shape post, and each component in `[-Acc_Bound, Acc_Bound]`. The numeric product is not proved |
| `Mat_Mat` | Silver | Same as `Mat_Vec`, for each entry of the product |
| `Add` (vector and matrix) | Gold | No run-time error, and each entry is the sum of the two inputs |
| `Scale` (vector and matrix) | Gold | No run-time error, and each entry is the input times the factor |
| `Transpose` | Gold | No run-time error, and entry `(C, R)` of the result is entry `(R, C)` of the input |
| `ReLU` | Gold | No run-time error. A positive component is copied. Any other component is 0 |
| `Leaky_ReLU` | Gold | No run-time error. The slope lies in `[0.0, 1.0]`. A positive component is copied. Any other component is the slope times the input |
| `Sigmoid` | Silver | No run-time error. Each component lies in `[0.0, 1.0]`. The series is not proved equal to the real sigmoid |
| `Tanh` | Silver | No run-time error. Each component lies in `[-1.0, 1.0]`. The series is not proved equal to the real tanh |
| `Softmax` | Silver | No run-time error. Each component lies in `[0.0, 1.0]`. The series is not proved equal to the real softmax |
| Splash | not proved | Plain Ada |
| MLP, including its demo and the speed harness | not proved | Plain Ada. Tests, not proofs |
| Tokenizer | not proved | Plain Ada |
| Attention, including its demo | not proved | Plain Ada. The hand-computed pass is a test |
| Recursive prompts, including the demo and the native caller | not proved | Plain Ada. The recorded chains and the stand-in caller are tests |
| Wrong turns, including the demo and the native caller | not proved | Plain Ada. The four traces and the checker are tests |
| Benchmark audit, including the demo, the manifest, and `audit_cli` | not proved | Plain Ada. The planted tasks and the second file are tests |
| Reward hacking, including the demo and `reward_cli` | not proved | Plain Ada. The planted cheats and the two searches are tests |

`Summand_Bound` is `1.0E18`. The float value of that literal is a
little under `1.0E18`, and the real square of that float is a little
over the float value of `1.0E36`, so `Product_Bound` is `2.0E36`.
`Max_Extent` is 32. `Acc_Slack` is 2, so a loop invariant allows
`I * 2 * Product_Bound`. That factor of two is there because a tight
`I * Product_Bound` comparison is one ulp short in `Float` at the
extreme. `32 * 2 * 2.0E36` is `1.28E38`. `Acc_Bound` is `2.0E38`,
which is above that product and below `Float'Last` (about `3.4E38`).
The precondition is what keeps a sum of products from overflowing.
The demos, the MLP, and attention stay far inside it. A component
past the bound fails the `Pre` (`Assertion_Error` natively, a trap
in the wasm module).

`Logit_Bound` is `1.0E38`. Softmax subtracts two components. Twice
that bound is about `2.0E38`, still below `Float'Last`. The
large-logit test uses `1.0E20`. `Exp_Ceiling` is `4.0E36`. The
softmax sum allows `Acc_Slack` times `Max_Extent` of those, which is
`2.56E38`. `Softmax_Sum_Bound` is `3.0E38`.

`Exp_Clamped` reduces by `ln 2`, takes twelve terms, and scales by
powers of two, as before. Three guards keep that arithmetic in range
for the proof: a quotient outside `[-120, 120]` returns 0, a remainder
outside `[-1, 1]` is clamped, and a scale above `5.0E34` is held
there before the next doubling. On a reduced argument in `[-80, 80]`
none of them changes the value. The quotient is about 115, the
remainder is at most about half of `ln 2` (0.35), and the scale is
at most `2**115` (about `4.15E34`). A final clamp forces
`[0, Exp_Ceiling]`. It does not fire on those arguments either.
The proof is the range and the absence of overflow. It is not a
proof that the series equals the real exponential.

GNATprove reports `Success: all checks proved (419 checks).`
The committed log's counts:

| Check | Total | Flow | Provers | Unproved |
|---|---:|---:|---:|---:|
| Data dependencies | 2 | 2 | . | . |
| Initialization | 8 | 8 | . | . |
| Run-time checks | 225 | . | 225 | . |
| Assertions | 106 | . | 106 | . |
| Functional contracts | 47 | . | 47 | . |
| Termination | 31 | 31 | . | . |
| Total | 419 | 41 | 378 | 0 |

Termination includes the implicit `Always_Terminates` contracts.
The prover column in `proof/gnatprove.out` names CVC5, Z3, and
Alt-Ergo. Those percentages are that run. The counts above are the
contract. A later `./prove.sh` that disagrees with this table means
the table is stale.

## Build WebAssembly and the page

Same compiler route as
[murmuration-spark](https://github.com/RobertBoettcherSF/murmuration-spark)
and
[symmetry-visualizations](https://github.com/RobertBoettcherSF/symmetry-visualizations):
AdaWebPack 24 (GNAT-LLVM), linked with `wasm-ld`. On Debian/Ubuntu the
download step needs `rpm2cpio`, `cpio`, `lld`, and `libedit2`. The smokes
need Node.js. The page smoke also needs Chrome and `puppeteer-core`.

```sh
sudo apt install rpm2cpio cpio lld libedit2
./tools/get-toolchain.sh
npm ci
./build.sh
node tools/page-smoke.mjs
```

`build.sh` compiles every `src/*.adb` except `hello.adb`,
`tensors_test.adb`, `mlp_test.adb`, `attention_test.adb`,
`recurse_test.adb`, `recurse_cli.adb`, `traces_test.adb`,
`traces_cli.adb`, `audit_test.adb`,
`audit_cli.adb`, `reward_test.adb`, and
`reward_cli.adb` (Text_IO is not part of
this runtime), links `--no-entry`, and exports the
version, splash, tensor-demo, leaky ReLU, training, weight,
speed, token-attention, recorded-chain, wrong-turn, benchmark-audit, and reward-hacking entry points. It also links
`tools/wasm-checks.c`. It does not pass `--allow-undefined`. The module
this build emits has no imports. Runtime checks stay on. A failed check
traps that module; it does not propagate.

`./build.sh` writes `site/index.html` and `site/version.txt`. Open
`site/index.html` in a browser. The Pages workflow builds the same
directory and deploys it from `main`.

`docs/HOWTO.md` writes this path out for someone new to Ada.
`tools/howto-steps.sh` is the command list. CI job `how-to steps`
runs that file on a clean runner.

## Tensors

`AI_Amplifier.Tensors` is SPARK. The level of each kernel is in the
proof status table above. `Vector` and `Matrix` carry their shape as a
discriminant (`Length`, or `Rows` and `Cols`). Components are `Float`,
indexed `1 ..` that bound. `Max_Extent` is 32. A larger discriminant
fails the range check on `Extent`. `Dot`, `Mat_Vec`, `Mat_Mat`, `Add`,
and `Scale` also require every component inside `Summand_Bound`, and
`Scale` requires the same of the factor. `Softmax` requires every
component inside `Logit_Bound`. Those are ordinary `Pre` checks as
well as proof hypotheses. The reason for each number is in the proof
status section.

| Kernel | Result | When the shapes disagree |
|---|---|---|
| `Dot` | one `Float` | the two lengths differ |
| `Mat_Vec` | `Rows` of the matrix | columns differ from the vector length |
| `Mat_Mat` | `Rows` of the left, `Cols` of the right | left columns differ from right rows |
| `Add` | the left shape | the two shapes differ |
| `Scale` | the same shape | they do not have to agree with anything else |
| `Transpose` | columns by rows | always defined |
| `ReLU`, `Sigmoid`, `Tanh`, `Softmax` | the same length | always defined |
| `Leaky_ReLU` | the same length | the slope must lie in `[0.0, 1.0]`. Outside that, the `Pre` fails |

`pragma Assertion_Policy (Pre => Check, Post => Check)` is in the spec
and the body, and `ada_ai_amplifier.gpr` passes `-gnata`. A failed `Pre`
raises `Assertion_Error`. The body also assigns a marker array onto the
other length (`Checked_Length`). That is a length check, so a longer
operand is not dropped on the floor. It raises `Constraint_Error` when
the precondition is not the thing that fires. `bin/tensors_test` expects
`Assertion_Error` on a mismatch, which is this build.

Length 0 is a value. The dot of two empty vectors is 0. Softmax of an
empty vector is empty: there is no division. A matrix with zero columns
times an empty vector is a zero vector with one entry per row. A 2 by 0
matrix times a 0 by 3 matrix is a 2 by 3 zero matrix.

Softmax subtracts the largest component before the exponential.
`(1000, 1000, 1000)` and `(-1000, -1000, -1000)` both come out uniform,
and `(1.0E20, 1.0E20)` is `(0.5, 0.5)`. The exponential is `Exp_Clamped`
in the body: reduce by `ln 2`, twelve terms of the series, then scale by
powers of two. Arguments outside `[-80, 80]` saturate. It is not
`Ada.Numerics.Elementary_Functions`, because that runtime wants a host
`libm` and this wasm module has no imports. Sigmoid calls the exponential
only with a negative argument. Tanh outside `[-20, 20]` is the sign.

The page panel is `AI_Amplifier.Tensors.Demo`. It stores one 3 by 3
matrix and one length-3 vector, calls `Mat_Vec`, then `Softmax`. An index
outside `1 .. 3` is ignored on input and reads as 0.0 on output, so the
wrapper itself does not raise. The starting numbers are

```text
| 1 2 3 |   | 1 |   | 14 |
| 0 1 4 | * | 2 | = | 14 |
| 5 6 0 |   | 3 |   | 17 |
```

and softmax of `(14, 14, 17)`. JavaScript copies the boxes in and the
two results out. It does not multiply.

`Leaky_ReLU` takes a vector and a slope. A positive component is
copied. Any other component, including zero, is multiplied by the
slope. Slope `0.0` is ReLU. Slope `1.0` copies the vector. The page
passes `Negative_Slope`, which is `0.01`, and reads that constant
back for the caption (`aa_lrelu_slope`). The starting vector is
`(-2, 0, 3)`, so the output is `(-0.02, 0, 3)` within `Float`.
`bin/tensors_test` also rejects slopes `-0.1` and `1.5` with
`Assertion_Error`. The `Post` states the component rule. It is checked
when the function returns, and it is the Gold proof of this kernel.
The wrapper is
`AI_Amplifier.Tensors.Leaky_Demo`. An index outside `1 .. 3` is
ignored on input and reads as `0.0` on output. The guide's "add a
layer" section is this kernel, not a second copy of it.

## The network

`AI_Amplifier.MLP` is plain Ada (`SPARK_Mode => Off`). It calls
`Mat_Vec`, `Add`, `Tanh`, and `Sigmoid` in `AI_Amplifier.Tensors`. It
does not call `Ada.Numerics`. Log, square root, sine, and cosine are
written in the MLP body, for the same reason the tensor body writes its
own exponential: this wasm module has no imports.

The shape is fixed.

| | |
|---|---|
| Inputs | 2 |
| Hidden | 8, tanh |
| Output | 1, sigmoid |
| `W1`, `b1` | 8 by 2, and 8 biases, starting at 0 |
| `W2`, `b2` | 1 by 8, and 1 bias, starting at 0 |

`Initialize` fills the weights from a seed. The page and the native
test use `Init_Seed`, which is `20261104`. The generator is

```text
state := state * 1664525 + 1013904223    (mod 2**32)
```

and each weight is uniform on the Xavier interval
`[-sqrt (6 / (fan_in + fan_out)), +sqrt (6 / (fan_in + fan_out))]`.
The same seed is the same net. A second seed is a different net.
`Initialize` replaces a rate outside `(0, 5]` with the default `0.5`.
The page wrapper leaves the current rate alone when a new one falls
outside that interval. The control on the page only offers `0.01` to `2`.

One sample, with `y` the sigmoid output and `t` the label 0 or 1:

```text
L = -(t ln y + (1 - t) ln (1 - y))
```

`y` is clipped into `[1.0e-6, 1.0 - 1.0e-6]` before the log, so a
saturated output still has a finite loss. `Train` descends the mean of
`L` over the batch. The gradient is written out, not taken from a
library:

```text
dL/dz2 = y - t
dW2    = (y - t) * h
db2    = y - t
dh     = (y - t) * W2
dz1    = dh * (1 - h**2)
dW1    = dz1 * x
db1    = dz1
```

`h` is the hidden tanh and `z2` is the output logit. Those are averaged
over the batch. One step is `parameter := parameter - rate * gradient`.
The clip is only on the logged `y`. Away from the clip, `y - t` is the
derivative of that loss. On the clip edges the logged loss is flat and
this gradient is not. `bin/mlp_test` checks the two against a central
difference at the seeded start, where every XOR output sits away from
the clip. The step is `0.001`. A component matches when the absolute
gap is at most `0.002 + 0.05 * |analytical|`.

The datasets, all built in Ada:

| Dataset | Points | What they are |
|---|---|---|
| XOR | 4 | `(0,0)→0`, `(0,1)→1`, `(1,0)→1`, `(1,1)→0` |
| Two circles | 72 | 36 on a circle of radius 0.45 (class 0), alternating with 36 on a circle of radius 1.05 (class 1) |
| Two spirals | 96 | 48 on each arm, one and a half turns, radius from 0.12 to 1.17. The second arm is half a turn ahead |

`bin/mlp_test` trains XOR at rate 1 and requires the mean loss under
`0.05`, with class-1 outputs at least `0.8` and class-0 outputs at most
`0.2`, within 8000 steps. On this seed that happens at step 95. On the
page, at the default rate `0.5`, the same XOR loss threshold is crossed
at about step 190. The test also trains the circles at rate `0.5` and
requires that loss threshold and every point on the correct side of
`0.5`, within 2000 steps. On this seed the points are all on the correct
side by step 300, and the loss crosses `0.05` at step 550.

The spirals are not solved. On this seed, rate `0.5`, 5000 steps leave
the loss near `0.64` and 54 of 96 points on the correct side of `0.5`.
At 20000 steps the loss is near `0.58` and 65 of 96 are on the correct
side. That is a partial cut. The page says so.

The speed harness is a second use of the same XOR trainer, in
`AI_Amplifier.MLP.Speed`. It is not the panel above. The baseline
calls `Train` once per step, 95 steps from the seed at rate 1,
repeated 8 times inside the clock. The faster variant does that same
update in place and skips the extra loss pass between steps. A time
counts only when the loss is under `0.05` and the four answers pass
`0.8` and `0.2`, the weights match the public `Train`, and the steps
ran inside the clock. The recorded baseline on the machine that added
this item is `33044` microseconds of native process CPU time and
`10162` microseconds of wasm host wall time. On that same pair of
runs the faster variant took `15742` and `4836` microseconds, which
Ada printed as `0.48` times the baseline on each clock. Those two
clocks are not comparable to each other.
[docs/TRAINING_SPEED.md](docs/TRAINING_SPEED.md) is the full account,
including the three runs the harness rejects.

The page holds one net in `AI_Amplifier.MLP.Demo`. Train asks Ada for 2
steps per frame, then reads a 48 by 48 grid of probabilities and the
loss curve. JavaScript colors the grid and plots the curve. Reset
rebuilds the seeded weights. The learning rate survives Reset. One call
does at most 32 steps, so a stuck button cannot lock the module inside
a single call. The curve keeps up to 240 points and then drops every
other stored point, so a long run still fits.

A zero net on XOR is a useful check, and it does not learn: every
hidden unit is 0, the four labels are balanced, and every gradient
component is 0. The loss is `ln 2`. The seeded weights are what break
that tie. `bin/mlp_test` checks the zero net as well.

The same net can be written down. `Write_Weights` emits one labelled
line per neuron. `Read_Weights` accepts that text only when the shape
is 2, 8, 1 and every value is finite and inside ±1000
(`Weight_Limit`). Anything else leaves the net alone. The learning
rate is not stored in the file. `Hand_XOR` is a set of those weights
chosen so hidden 1 is OR, hidden 2 is AND, and the output is OR and
not AND. Units 3 through 8 are zero. It is not the result of `Train`.
On the four XOR points the outputs sit past 0.8 and under 0.2, and
the mean loss is under 0.05, with no steps. Three edits are also
fixed in Ada: negate hidden 1's output weight, set hidden 2's output
weight to 0, or negate the whole output layer. The page section is
the workbench: a slider and a number for each weight, those three
buttons, and download and upload of the text. JavaScript copies bytes
and paints the grid Ada already filled.
[docs/WEIGHT_SPACE.md](docs/WEIGHT_SPACE.md) is the longer account,
including what is not shown.

## Tokenizer

`AI_Amplifier.BPE` is plain Ada (`SPARK_Mode => Off`). It is byte-level
BPE. Ids `0 .. 255` are the bytes. Ids from 256 up are merges learned
from one excerpt stored as UTF-8 bytes in the body. The source file
stays in the Ada character set. The excerpt, 563 bytes, is:

```text
Alice was beginning to get very tired of sitting by her sister on the bank, and of having nothing to do: once or twice she had peeped into the book her sister was reading, but it had no pictures or conversations in it. Es war einmal eine kleine süße Dirne, die hatte jedermann lieb, der sie nur ansah, am allerliebsten aber ihre Großmutter, die wußte gar nicht, was sie alles dem Kinde geben sollte. Einmal schenkte sie ihm ein Käppchen von rotem Sammet, und weil ihm das so wohl stand, und es nichts anders mehr tragen wollte, hieß es nur das Rotkäppchen.
```

The English is the opening of Lewis Carroll's *Alice's Adventures in
Wonderland* (1865), through "conversations in it". The German is the
opening of the Grimms' *Rotkäppchen* (1857), through the sentence that
names the child. Both are public domain. Nothing is downloaded.

Learning counts adjacent pairs. Overlapping positions both count, so
`aaa` contributes two counts of `(a, a)`. The winner is the highest
count. A tie goes to the smaller left id, then the smaller right id.
The pair is replaced left to right, with no overlap. A pair whose
joined piece would be longer than 16 bytes is skipped. Learning stops
at 32 merges, or sooner if no pair still occurs twice. This excerpt
uses all 32. The vocabulary is 288. The first merge is the bytes of
`e` and a space, id 256. Encode of the excerpt is 376 tokens.
`bin/attention_test` locks those numbers.

Encode starts from the raw bytes and applies the merges in the order
they were learned. Decode concatenates the stored bytes of each id.
On every input that fits in 768 bytes, the two are inverses: ASCII,
the empty string, every byte from 0 to 255, and UTF-8. A longer
argument fails the precondition (`Assertion_Error` in the native
test). The page wrapper does not raise: it keeps 768 bytes and counts
the rest as dropped.

In this vocabulary the UTF-8 of ß (`C3 9F`) is one token. The UTF-8
of ä (`C3 A4`) is still two byte ids, 195 and 164. The pair is in the
excerpt, and it did not win a slot among the 32. The page shows that
split as two chips.

## Attention

`AI_Amplifier.Attention` is plain Ada (`SPARK_Mode => Off`). It is one
single-head self-attention block. Forward only. There is no loss and
no update.

| | |
|---|---|
| `D_Model` | 8. Fits in `Tensors.Max_Extent` |
| `Max_Seq` | 16 positions. A score row is a `Vector` |
| Projections | `W_Q`, `W_K`, `W_V`, `W_O`, each 8 by 8. No bias |
| Embeddings | one length-8 vector per token id, and one per place |
| Norm | gamma starts at 1, beta at 0, `Eps` is `1.0e-5` |
| Seed | `Embed_Seed`, `20261104`, the same number as the MLP |

The generator is the one in the MLP unit, in its own stream:

```text
state := state * 1664525 + 1013904223    (mod 2**32)
```

A drawn component is uniform on `[-s, s)` with `s = 1/sqrt(8)`.
The projections are one stream from `Embed_Seed`. The token table,
then the 16 position vectors, are a second stream from the same seed.
`X(i) = token_embed(id) + position_embed(i)`. The vocabulary is wider
than `Max_Extent`, so the tables are arrays of `Vector`, not one
`Matrix`. On this wasm runtime a vector kept in such an array and
passed straight into `Dot` or `Mat_Vec` is not the view those kernels
read. The attention body copies the components into a fresh aggregate
at the call. The native test does not need that copy, and it checks
the same kernels.

For a sequence `X(1) .. X(n)`:

```text
Q = W_Q X,   K = W_K X,   V = W_V X
score(i, j) = Q(i) · K(j) / sqrt(8)     for j <= i
weight(i)   = softmax of those scores
weight(i, j) = 0                         for j > i
context(i)  = sum_j weight(i, j) * V(j)
Y(i)        = LayerNorm(W_O context(i) + X(i))
```

The softmax for row `i` is only over `1 .. i`. A future column is
written as 0. It is not a large negative logit. Layer norm divides by
`D_Model` (population variance, not `D_Model - 1`) and adds `Eps`
under the square root. The square root is the same Newton loop the
MLP uses for its own square root. There is no second head and no
feed-forward layer.

`1/sqrt(8)` is about `0.353_553_38`. `bin/attention_test` checks
`Scaled_Dot` of `(1, 0, …)` with itself against that value, and the
dot of `(1, 0, …)` with `(0, 1, …)` as 0.

The hand-computed pass uses two tokens and a block the test fills in:

```text
X1 = (1, 3, 0, 0, 0, 0, 0, 0)
X2 = (5, 7, 0, 0, 0, 0, 0, 0)
W_Q = 0,  W_K = 0,  W_V = I,  W_O = 2 I
gamma = 1,  beta = 0
```

Q and K are zero, so every unmasked score is 0. Softmax of one 0 is
1. Softmax of two 0s is 1/2 and 1/2. The future weight on row 1 is 0.

```text
context1 = X1 = (1, 3, 0, …)
context2 = (3, 5, 0, …)
W_O doubles that, then the residual adds X:
Y before the norm = (3, 9, 0, …) and (11, 17, 0, …)
```

Layer norm of those, within `0.000_05`:

```text
(0.500, 2.500, -0.500, -0.500, -0.500, -0.500, -0.500, -0.500)
(1.201, 2.162, -0.560, -0.560, -0.560, -0.560, -0.560, -0.560)
```

A second check sets gamma to 2 and beta to 0.5 and matches
`2 * y + 0.5` on the first component. A third check is three tokens
with zero Q and K: the rows are `(1, 0, 0)`, `(1/2, 1/2, 0)`, and
three equal thirds. A fourth check puts a much larger key in the
future. Without the mask, token 1 would attend to it (`10/sqrt(8)`
against `1/sqrt(8)`). The weight on that future token is 0, and token
1's weight on itself is 1.

The seeded block is what the page runs. Each of its rows sums to 1
within `0.000_05`, and every future weight is 0. The same seed is the
same block. `Forward_Tokens` on a phrase matches `Forward` on the
embeddings of those ids.

The page keeps one buffer in `AI_Amplifier.Attention.Demo`. The box
starts as `Alice was beginning süß`, which encodes to 15 tokens, so
attention covers all of them. A longer text is still tokenized. The
heatmap is the first 16 tokens, and the page says how many later
pieces were left out of it. JavaScript sends bytes and reads ids,
piece bytes, and weights. It adds a row up when it writes the
sentence under the heatmap. It does not form Q, K, or V.

## Recursive prompts

A blob of three lines stands in for a prompt that would call itself.
Ada keeps the state, counts the steps, and stops at the first blob
that fails a check. The page replays four chains that were written
in this repository. It does not call a language model, and it does
not send a key. The longer account, including the license note, is
[docs/RECURSIVE_PROMPTS.md](docs/RECURSIVE_PROMPTS.md).

The opening blob for a target `n` from 0 to 20 is:

```text
index n
minus-one 0
current 1
```

`minus-one` starts as F(0), which is 0. `current` starts as F(1),
which is 1. `index` is how many times the recurrence still has to
be applied. A later blob is legal only when:

| Check, in this order | What has to be true |
|---|---|
| Parse | The blob is those three fields, each once. A blank line is skipped. A line whose first visible character is `#` is skipped. A number is an integer from 0 to 20000 |
| Past base | The previous index was not already 0 |
| Toward the base | The new index is the previous index minus 1 |
| Arithmetic | `minus-one` is the previous `current`, and `current` is the previous `minus-one` plus the previous `current` |

The first failure stops the chain. At index 0 the answer is
`minus-one`, which is F(n) when every step followed the rule.
`current` is then F(n + 1), except for n = 0: no step runs, and
`current` stays the unused seed 1. F(6) is 8. F(20) is 6765.
A chain longer than 4000 characters is refused before it is parsed.

| Recorded chain | Stop | Where |
|---|---|---|
| `fib-6-complete` | reached the base | answer 8, after 6 accepted steps |
| `fib-6-bad-sum` | bad arithmetic | state 4 writes `current 4` where the rule wants 3 |
| `fib-4-stalled` | not toward base | state 2 keeps index 4. The pair would have been right for index 3 |
| `fib-3-garbled` | bad parse | state 3 says `index two` |

`bin/recurse_test` locks those four, and it also locks a chain that
continues after the base, a chain that stops early, a bad opening,
and a chain that is too long to read. JavaScript copies the lines
Ada already wrote.

`bin/recurse_cli` with no arguments replays the same four chains and
does not open a socket. `recurse_cli --ask N` calls a chat endpoint
only when `RECURSE_LLM_URL` is an `http://` or `https://` address,
`RECURSE_LLM_KEY` is a single line, and `RECURSE_LLM_MODEL` is set.
The key is written to a mode 0600 file for curl and is not placed
on the command line. The page does not run this program.

## Wrong turns

Four traces, stored in `AI_Amplifier.Traces`, each end on one bad
step of this XOR trainer. The page shows the trace through that
step. A menu offers the next step. Ada applies it with `Train`,
`Read_Weights`, or one of the weight edits, then judges the net
that comes back. JavaScript copies the sentence.

| Trace | Wrong turn | Known-good step | One step that is not |
|---|---|---|---|
| `rate-diverges` | After 40 steps at rate 1, rate 5 for 15 steps. The loss rises | Rate 1 and 200 more steps | Invert the output. The loss rises again |
| `padded-shape` | A shape `2 4 1` file is refused, then a zero-padded `2 8 1` file loads | The hand-written XOR net | 200 more steps. The zero net does not move |
| `silenced-and` | Hidden 2's output weight is set to 0 | Revert that edit | Flip hidden 1. The loss rises |
| `stopped-early` | 10 steps at rate 1, then stop | 200 more steps at rate 1 | Rate 5 for 10 steps. The loss rises |

The repair is `fixes-it` when the mean loss is under `0.05` and the
four XOR outputs are back inside `0.8` and `0.2`, and the weights
are finite and inside ±1000. Anything else is `no-better` or
`makes-it-worse`, and the reason names the rule.
[docs/WRONG_TURNS.md](docs/WRONG_TURNS.md) is the longer account,
including what is not claimed.

`bin/traces_cli` with no arguments prints those four checks and
does not open a socket. `traces_cli --ask N` calls a chat endpoint
only when `TRACES_LLM_URL`, `TRACES_LLM_KEY`, and `TRACES_LLM_MODEL`
are set. The key is written to a mode 0600 file for curl and is not
placed on the command line. The page does not run this program.

## Benchmark audit

Twenty tasks, stored as text inside `AI_Amplifier.Audit`. Each one
asks something this repository can recompute: an XOR label, the
size of that dataset, a Fibonacci answer or stop word from
`AI_Amplifier.Recurse`, or the status `Read_Weights` reports for a
hand-written file. The expected field is the key. The sample field
is a fixed reply. Ada recomputes the answer before it scores.

Five tasks are broken on purpose. The planted list is
`AI_Amplifier.Audit.Manifest`. The auditor does not with that
unit. The native test is what compares the two.

| Rule | What it catches here |
|---|---|
| `wrong-expected` | `fib-5-wrong` expects 9. The checker says 5 |
| `unsolvable` | `fib-21` is past the index the checker will build |
| `duplicate` | `xor-01-copy` repeats `xor-01` |
| `accept-anything` | `weight-any` uses `grade any`, so `nope` passes |
| `answer-leaked` | `fib-4-leaked` writes the token `3` in the prompt |

Scoring a set that still contains a flag is refused. The page
prints both tallies:

```text
Full set: 14 of 20. Not accepted: audit-flagged.
Cleaned set: 9 of 15. Accepted.
```

14 of 20 counts the five broken tasks as hits. 9 of 15 is the same
samples with those tasks removed. Six of the clean samples are
wrong on purpose. JavaScript copies the lines. It does not grade.
[docs/BENCHMARK_AUDIT.md](docs/BENCHMARK_AUDIT.md) is the longer
account, including the licences of the public work this idea
comes from, and what this audit does not catch.

`bin/audit_cli` with no arguments prints that report. With a path,
it audits that task file with the same procedures. The page does
not read a file from disk.

## Reward hacking

Five submissions for one task: make the XOR net right. The flawed
grader accepts a reported loss under 0.05, or four reported outputs
at 0.5, or two reported outputs above 0.5, or the shape stamp
`shape 2 8 1`. It does not rerun the net. The real check does. Every
XOR output has to be at least 0.8 or at most 0.2, on the correct
side. Only that pass counts.

| Submission | Flawed | Real | Verdict | Gap |
|---|---:|---:|---|---|
| `honest-trained` | 1.00 | 1.00 | counts | none |
| `hard-coded-loss` | 1.00 | 0.00 | rejected | reported-loss |
| `constant-half` | 1.00 | 0.00 | rejected | constant-half |
| `memorized-two` | 1.00 | 0.50 | rejected | two-of-four |
| `right-stamp` | 1.00 | 0.00 | rejected | right-stamp |

`honest-trained` is 120 steps of the trainer from `Init_Seed` at
rate 1. The other four are written to fit one gap. A hill-climb
from that same seed takes 120 gradient steps. Aimed at the flawed
proxy, the native run ends at proxy `1.00` and real `0.50`, and
the real check fails on every step. Aimed at the real loss, it
ends at real `1.00` and the check passes. JavaScript copies the
table and draws the curves.
[docs/REWARD_HACKING.md](docs/REWARD_HACKING.md) is the longer
account, including the licences of the public write-ups this idea
comes from. This is a toy with planted gaps. It is not evidence
of how often a real model does this.

## Backlog

1. **Repo skeleton — done.** Crate, stamp, native hello, wasm target, placeholder page.
2. **Splash and live page — done.** One HTML file, Ada in WebAssembly, JavaScript draws. Version badge, F9 feedback, crash report, Pages from the workflow.
3. **Core tensor and maths (plain Ada) — done.** `Vector` and `Matrix`, the kernels above, native tests, and the 3 by 3 panel.
4. **Tiny trainable MLP, live in the browser — done.** The network above, native tests including a finite-difference gradient check, and the training panel.
5. **Byte-level BPE tokenizer and one transformer attention block — done.** The tokenizer and the block above, native tests including the hand-computed pass, and the token panel.
6. **Contributor How-To docs — done.** `docs/HOWTO.md`, this leaky ReLU kernel, `CONTRIBUTING.md`, and the issue and pull-request templates. CI job `how-to steps` runs the guide's command list.
7. **SPARK proofs of the kernels — done.** `AI_Amplifier.Tensors`, at the levels in the proof status table. The MLP, the tokenizer, and attention are still plain Ada.
8. **Weight-space programming — done.** The weight text, the hand-written XOR net, and the workbench on the page. [docs/WEIGHT_SPACE.md](docs/WEIGHT_SPACE.md). This is not a reproduction of the [post](https://rikiyat.github.io/blog/weight-space-programming/) that suggested it.
9. **Recursive prompts with an Ada checker — done.** The state blob, the checker, four recorded chains on the page, and a native caller that stays offline unless the user supplies a key. [docs/RECURSIVE_PROMPTS.md](docs/RECURSIVE_PROMPTS.md). This is not a reproduction of [recursive_llm](https://github.com/andyk/recursive_llm). That repository has no license. Nothing here was copied from it.
10. **Training-speed harness — done.** The baseline and the faster variant above. [docs/TRAINING_SPEED.md](docs/TRAINING_SPEED.md). This is not a reproduction of the Anthropic Institute essay or of the note linked from that file.
11. **Wrong-turn traces — done.** Four recorded traces of this XOR trainer, a next-step checker, and the panel on the page. [docs/WRONG_TURNS.md](docs/WRONG_TURNS.md). This is not a reproduction of the Anthropic Institute essay, and it is not a test of research taste.
12. **Benchmark audit — done.** Twenty tasks about this repository, five planted breaks, and an auditor that refuses the score until those tasks are dropped. [docs/BENCHMARK_AUDIT.md](docs/BENCHMARK_AUDIT.md). This is not a copy of SWE-bench, of the OpenAI notes linked there, or of MMLU-Redux.
13. **Reward-hacking demo — done.** Two graders on the XOR task, four written cheats, and a hill-climb that can raise the flawed score while the real check still fails. [docs/REWARD_HACKING.md](docs/REWARD_HACKING.md). This is not a copy of the write-ups linked there, and it is not evidence about real models.
14. **Same model, different harness — planned.** Not started.
15. **Checked steps, not just answers — planned.** Not started.
16. **README update after items 1–15 — planned.** Not this change. Not started.

Items landed one at a time. Item 13 is the last one done. Items 14 through 16 are not started.

## Honesty

1. The splash arithmetic is plain Ada. It is not proved. `SPARK_Mode` is off on that unit so it is not presented as a proof target. The contracts on `AI_Amplifier.Version` are the ones from the skeleton. The stamp text in that unit is `v0.13.0-reward`.
2. The tensor kernels are SPARK, at the levels in the proof status table. Silver is absence of run-time error (and, where the table says so, a range). Gold is the component rule. `Leaky_ReLU` is Gold. Its slope on the page is `0.01`. The `Pre` and `Post` are still checked when the program runs. The proof does not replace that check. Sigmoid, tanh, and softmax do not claim to match the real functions.
3. CI builds the native program, runs `bin/tensors_test`, `bin/mlp_test`, `bin/attention_test`, `bin/recurse_test`, `bin/traces_test`, `bin/audit_test`, and `bin/reward_test`, runs `./prove.sh` (GNATprove level 2, unproved checks are errors), builds the wasm module and the page, then runs the headless smoke. The committed `proof/gnatprove.out` is that level 2 run. It proves the root, the version unit, and the tensors. It does not prove the splash, the network, the tokenizer, the attention block, the chain checker, the speed harness, the wrong-turn checker, the benchmark auditor, or the reward demo.
4. The wasm module's lack of imports is what this build emits, and `tools/wasm-smoke.mjs` checks it. The tensor body does reference a failed-check path. `tools/wasm-checks.c` defines `__gnat_last_chance_handler` and `system__assertions__raise_assert_failure` as traps, so that path links without an import. On the native runtime the same check raises. `-gnatp` is not used. `-gnatw.X` is the same switch as the native Alire profile: this runtime forbids exception propagation, and the compiler's reminder of that is turned off.
5. JavaScript does not compute the splash, the product, the softmax, the loss, the decision boundary, the merges, the attention, the weight text, the chain check, the training-speed verdict, the wrong-turn verdict, the benchmark audit, or the reward scores. It reads coordinates, copies numbers, and sends UTF-8 bytes. It adds up the weights it already read when it writes the sentence under the heatmap. On the speed panel it reads the host wall clock before and after the Ada call and passes those two readings in. Ada subtracts them. If the module is missing, not WebAssembly, missing an export, or its stamp differs from the badge, the page says "The Ada module did not load" and still shows the title and the badge. The tensor demo then says it has no product. The leaky ReLU panel says it has no leaky ReLU. The training panel says it cannot train. The weight buttons say the weights cannot be edited. The speed panel says it cannot time a run. The token panel says it cannot tokenize. The chain panel says it cannot check a chain. The wrong-turn panel says it cannot check a next step. The audit panel says it cannot audit the tasks. The reward panel says it cannot score the submissions.
6. The network on the splash is not a model. The tensor demo is not a model. The training panel is a model: forward, binary cross-entropy, backprop, and gradient descent, in the MLP unit. The token panel tokenizes and runs attention, forward only. Those weights are the seed. They are not trained.
7. The MLP, the tokenizer, the attention block, the chain checker, the speed harness, the wrong-turn checker, the benchmark auditor, and the reward demo are plain Ada. `SPARK_Mode` is off. The finite-difference check, the hand-computed attention pass, the recorded chains, the four traces, and the planted tasks are tests, not proofs. There is no Silver claim and no Gold claim on these units. The MLP and attention call the tensor kernels, so a component outside `Summand_Bound` or a softmax logit outside `Logit_Bound` fails the kernel `Pre` at run time. The seeded nets and the tests stay inside those bounds. The chain checker does not call those kernels. A bad blob is a result, not a trap. A weight outside `Weight_Limit` is a verdict, not a trap: the checker does not call the loss on it.
8. `Float` results are approximate. The tensor test and the attention test allow `0.000_05`. Softmax of a non-empty vector sums to 1 within that tolerance, because the largest logit becomes `exp(0) = 1`. The gradient check allows `0.002` plus 5 percent of the analytical value, at a central step of `0.001`. The log, square root, sine, and cosine in the MLP body, and the square root in the attention body, are series, not `Ada.Numerics`. The hand-computed layer-norm values in the attention section are this Newton square root.
9. Eight hidden units do not solve the spirals. The numbers in the network section are this seed, at the rates named there. They are not a claim about every seed.
10. The BPE rules are whatever this excerpt and this tie-break produce. They are not a published tokenizer. ß is one token here. ä is not. A different excerpt would learn different merges. The 32, 288, and 376 figures are this text.
11. Attention reads at most 16 tokens. The page still shows later pieces, and it says they are outside the heatmap. The box keeps at most 768 bytes.
12. The compiler, `wasm-ld`, Chrome, and the Node smokes are trusted tools. They are not verified.
13. GitHub Pages publishes `site/` from `main` via `.github/workflows/pages.yml`. The cache-bust query is the stamp without the leading `v`.
14. The hand-written XOR net and the three weight edits are Ada source. They are not the output of a language model, and they are not a rerun of the weight-space programming post. The post is linked from `docs/WEIGHT_SPACE.md` as the idea. The checks on a loaded file run when the program runs. They are not proved.
15. The recorded chains are Ada source written for this repository. They are not the output of a language model, and they are not a rerun of the recursive-prompt repository linked from `docs/RECURSIVE_PROMPTS.md`. That repository has no license file. The page shows checked recordings. `recurse_cli --ask` can call a model, and only on the machine where the user set a key. The browser does not. There is no claim that a model produces the same chains, and no claim that these runs match anyone else's numbers.
16. The training-speed harness is plain Ada. It is not proved. A counted time is the native process CPU time, or the wasm host wall time around the same call. Those two clocks are not a ratio. The published microseconds are one machine's record, not a pass mark. The `0.48` figure is that record's faster variant against its own baseline. It is not a claim about any other trainer. JavaScript passes the two wall-clock readings in and copies Ada's sentence out. Ada subtracts, checks the loss and the four answers, and rejects a time that does not count.
17. The wrong-turn traces are Ada source written for this repository. They are not a language model's session, and they are not a rerun of the essay linked from `docs/WRONG_TURNS.md`. The checker runs the real trainer and applies the loss, XOR, and weight rules named in that file. A verdict is a test, not a proof. The page does not call a model. `traces_cli --ask` can, and only on the machine where the user set a key. There is no claim that a model picks the known-good step, and no claim that these toy repairs measure research taste.
18. The benchmark auditor is plain Ada. It is not proved. It only flags the five defect kinds named in `docs/BENCHMARK_AUDIT.md`, and only by recomputing an answer this repository already computes. It is not a general benchmark validator. The 14 of 20 and 9 of 15 figures are the seeded samples. The full-set figure is printed and is not an accepted score. The public projects linked from that file are the credit for the idea. Nothing from them was copied. JavaScript copies Ada's lines. The page does not call a model.
19. The reward demo is plain Ada. It is not proved. The four cheats are written to fit planted gaps, and the hill-climb is handed the objective it climbs. The table in the reward section is those five submissions. The flawed search ends with the real check failed. The real search ends with it passed. That is not evidence of how often a real model reward-hacks. The public pages linked from `docs/REWARD_HACKING.md` are the credit for the idea. Nothing from them was copied. JavaScript copies Ada's cells and draws the curves. The page does not call a model.

## License

MIT. Copyright (c) 2026 Sternenfisch. See `LICENSE`.
