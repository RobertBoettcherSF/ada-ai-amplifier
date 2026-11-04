# ada-ai-amplifier

Readable AI building blocks in plain Ada. The logic lives in Ada.
JavaScript only draws, and writes the feedback and crash files.
The splash on the live page is a small picture of a network: Ada moves
the points, and the page plots them.

Visible stamp: **v0.4.0-mlp**

The same text is `AI_Amplifier.Version.Version_Text`, the yellow badge in
`web/template.html`, `version.txt`, and the line printed by `bin/hello`.
The Alire crate version is `0.4.0-mlp` (the stamp without the leading
`v`, because Alire versions are semver).

**Live page:** https://robertboettchersf.github.io/ada-ai-amplifier/?v=0.4.0-mlp

`.github/workflows/pages.yml` builds `site/` and deploys it with GitHub
Actions. The query is the cache bust. `version.txt` is published next to
the page.

## Goal

A small library a person can read from the spec down: tensors and the math
under them, a tiny trainable MLP, a byte-level BPE tokenizer, and one
transformer attention block. The parts that run in the browser are compiled
from that Ada to WebAssembly and embedded in one HTML file.

Item 3 is the tensor kernels, in plain Ada, and a 3 by 3 demo on the
page. Item 4 is a real network on those kernels: eight tanh units, one
sigmoid output, trained by gradient descent. The splash is still a
drawing. It is not trained. SPARK proofs of the kernels are the last
backlog item.

## Why plain Ada

1. **Strong typing.** Ranks, index ranges, and token ids can be types in the
   source, so a mix-up is a compile error.
2. **Range checks.** A bad index fails at the line that made it. The native
   build leaves checks on. The WebAssembly build does too (`-gnata`, and
   `-gnatp` is not used).
3. **SPARK, later.** The version unit is still marked `SPARK_Mode`, with the
   contracts from the skeleton. CI does not run GNATprove. `prove.sh` is
   still there for a later item.
4. **No hidden library dependencies.** `alire.toml` depends on no other
   crate. GNAT, GNATprove, AdaWebPack, and `wasm-ld` are build tools. They
   are not linked into the library as a third-party ML stack.

## Using the page

| Control | What it does |
|---|---|
| Tap the splash, or Enter | Leaves the splash and shows this project |
| Tensor demo | Nine matrix boxes, three vector boxes, Compute. Ada returns the product and its softmax |
| Train | Runs gradient descent on the small network. Stop is the same button |
| Dataset | XOR, two circles, or two spirals. Changing it resets the weights and keeps the learning rate |
| Learning rate | The step size Ada uses. The page control runs from 0.01 to 2. Lower and raise are the minus and plus buttons |
| Reset | Restores the seeded weights for the current dataset |
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
| `src/ai_amplifier-tensors.ads/.adb` | `Vector`, `Matrix`, and the kernels. Plain Ada. `Max_Extent` is 32 |
| `src/ai_amplifier-tensors-demo.ads/.adb` | The page's 3 by 3 panel. Calls `Mat_Vec` and `Softmax` |
| `src/ai_amplifier-mlp.ads/.adb` | The 2–8–1 network. Init, loss, backprop, gradient descent. Plain Ada |
| `src/ai_amplifier-mlp-demo.ads/.adb` | The page's copy of that network. Dataset, rate, steps, grid, loss curve |
| `src/hello.adb` | Native program. Prints the stamp. Also calls the splash so the native build compiles it |
| `src/tensors_test.adb` | Native tests. Known values, empty shapes, large logits, mismatches |
| `src/mlp_test.adb` | Native tests. XOR, the circles, a central-difference gradient check |
| `web/template.html` | Page source. `build.sh` replaces `__WASM_BASE64__` |
| `site/index.html` | Built page, gitignored. GitHub Pages publishes the `site/` directory |
| `version.txt` | The same stamp, one line |
| `build.sh` | AdaWebPack 24 to `obj/wasm/ai_amplifier.wasm`, smoke, then `site/index.html` |
| `prove.sh` | `gnatprove --mode=flow`, writes `proof/`. Not run by CI |
| `tools/get-toolchain.sh` | Downloads the wasm compiler into `toolchain/` (gitignored) |
| `tools/wasm-smoke.mjs` | Node: stamp, no wasm imports, splash numbers, product and softmax, XOR training |
| `tools/page-smoke.mjs` | Headless Chrome: splash, the tensor panel, the training panel, Enter, tap, F9, crash panel, failed module |
| `tools/wasm-checks.c` | Wasm-only. A failed check traps. Not linked into the native build |
| `proof/gnatprove.out` | Flow summary from the skeleton. It does not include the splash or the tensors |

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
ada-ai-amplifier v0.4.0-mlp
```

Then:

```sh
./bin/tensors_test
./bin/mlp_test
```

Expected lines:

```text
tensors ok
mlp ok
```

## Flow analysis

Not part of CI. When you want it:

```sh
alr -n install gnatprove          # FSF 16.1.0 for the skeleton run
export PATH="$HOME/.alire/bin:$PATH"
./prove.sh
```

`ada_ai_amplifier.gpr` passes `--mode=flow`. `./prove.sh` passes it again.
Provers are not run. `hello.adb`, `tensors_test.adb`, `mlp_test.adb`,
`AI_Amplifier.Splash`, `AI_Amplifier.Tensors` (and its demo child), and
`AI_Amplifier.MLP` (and its demo child) are outside SPARK.

The committed `proof/gnatprove.out` is the skeleton run (version unit and
empty root only). Running `./prove.sh` now rewrites `proof/` and will mention
the splash and the tensor units as not in SPARK. That file was not
regenerated for this item.

GNATprove's own summary line on that skeleton run:

```text
Success: all checks proved (5 checks).
```

Those five are all in the Flow column of `proof/gnatprove.out`:

| Check | Total | Flow | Provers |
|---|---:|---:|---:|
| Data dependencies | 2 | 2 | . |
| Initialization | 1 | 1 | . |
| Termination | 2 | 2 | . |
| Run-time checks | . | . | . |
| Functional contracts | . | . | . |
| Total | 5 | 5 | . |

The two termination rows are the implicit `Always_Terminates` on
`Version_Length` and `Version_Byte`, discharged during flow analysis.
The report says "proof skipped for this unit (only flow analysis was
requested)" on each unit. Tool id in `proof/version.txt`: `FSF 16.1.0`.

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
`tensors_test.adb`, and `mlp_test.adb` (Text_IO is not part of this
runtime), links `--no-entry`, and exports the version, splash,
tensor-demo, and training entry points. It also links
`tools/wasm-checks.c`. It does not pass `--allow-undefined`. The module
this build emits has no imports. Runtime checks stay on. A failed check
traps that module; it does not propagate.

`./build.sh` writes `site/index.html` and `site/version.txt`. Open
`site/index.html` in a browser. The Pages workflow builds the same
directory and deploys it from `main`.

## Tensors

`AI_Amplifier.Tensors` is plain Ada (`SPARK_Mode => Off`). `Vector` and
`Matrix` carry their shape as a discriminant (`Length`, or `Rows` and
`Cols`). Components are `Float`, indexed `1 ..` that bound. `Max_Extent`
is 32. A larger discriminant fails the range check on `Extent`.

| Kernel | Result | When the shapes disagree |
|---|---|---|
| `Dot` | one `Float` | the two lengths differ |
| `Mat_Vec` | `Rows` of the matrix | columns differ from the vector length |
| `Mat_Mat` | `Rows` of the left, `Cols` of the right | left columns differ from right rows |
| `Add` | the left shape | the two shapes differ |
| `Scale` | the same shape | they do not have to agree with anything else |
| `Transpose` | columns by rows | always defined |
| `ReLU`, `Sigmoid`, `Tanh`, `Softmax` | the same length | always defined |

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

## Backlog

1. **Repo skeleton — done.** Crate, stamp, native hello, wasm target, placeholder page.
2. **Splash and live page — done.** One HTML file, Ada in WebAssembly, JavaScript draws. Version badge, F9 feedback, crash report, Pages from the workflow.
3. **Core tensor and maths (plain Ada) — done.** `Vector` and `Matrix`, the kernels above, native tests, and the 3 by 3 panel.
4. **Tiny trainable MLP, live in the browser — done.** The network above, native tests including a finite-difference gradient check, and the training panel.
5. **Byte-level BPE tokenizer and one transformer attention block — not started.**
6. **Contributor How-To docs — not started.**
7. **SPARK proofs of the kernels — not started.** This stays last.

Items land one at a time. Item 5 has not been started.

## Honesty

1. The splash arithmetic is plain Ada. It is not proved. `SPARK_Mode` is off on that unit so it is not presented as a proof target. The `SPARK_Mode` and contracts on `AI_Amplifier.Version` are unchanged.
2. The tensor kernels are plain Ada too. `SPARK_Mode` is off. The `Pre` and `Post` are ordinary Ada contracts, checked when the program runs. They were not submitted to a prover. There is no Silver claim and no Gold claim.
3. CI builds the native program, runs `bin/tensors_test`, builds the wasm module and the page, then runs the headless smoke. CI does not run GNATprove. `prove.sh` remains. The committed `proof/gnatprove.out` is the skeleton flow run described above, not a proof of the splash or of the kernels.
4. The wasm module's lack of imports is what this build emits, and `tools/wasm-smoke.mjs` checks it. The tensor body does reference a failed-check path. `tools/wasm-checks.c` defines `__gnat_last_chance_handler` and `system__assertions__raise_assert_failure` as traps, so that path links without an import. On the native runtime the same check raises. `-gnatp` is not used. `-gnatw.X` is the same switch as the native Alire profile: this runtime forbids exception propagation, and the compiler's reminder of that is turned off.
5. JavaScript does not compute the splash, the product, the softmax, the loss, or the decision boundary. It reads coordinates and copies numbers out of the module. If the module is missing, not WebAssembly, missing an export, or its stamp differs from the badge, the page says "The Ada module did not load" and still shows the title and the badge. The tensor demo then says it has no product. The training panel says it cannot train.
6. The network on the splash is not a model. The tensor demo is not a model. The training panel is a model: forward, binary cross-entropy, backprop, and gradient descent, in the MLP unit. It does not tokenize, and it does not run attention.
7. The MLP is plain Ada. `SPARK_Mode` is off. The finite-difference check is a test, not a proof. There is no Silver claim and no Gold claim on these kernels.
8. `Float` results are approximate. The tensor test allows `0.000_05`. Softmax of a non-empty vector sums to 1 within that tolerance, because the largest logit becomes `exp(0) = 1`. The gradient check allows `0.002` plus 5 percent of the analytical value, at a central step of `0.001`. The log, square root, sine, and cosine in the MLP body are series, not `Ada.Numerics`.
9. Eight hidden units do not solve the spirals. The numbers in the network section are this seed, at the rates named there. They are not a claim about every seed.
10. The compiler, `wasm-ld`, Chrome, and the Node smokes are trusted tools. They are not verified.
11. GitHub Pages publishes `site/` from `main` via `.github/workflows/pages.yml`. The cache-bust query is the stamp without the leading `v`.

## License

MIT. Copyright (c) 2026 Sternenfisch. See `LICENSE`.
