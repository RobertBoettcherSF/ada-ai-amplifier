# Training speed

A yardstick for the XOR trainer this repository already has.
The numbers below are that trainer. They are not a reproduction of
anyone else's result.

Visible stamp: **v0.12.0-audit**

Live page: https://robertboettchersf.github.io/ada-ai-amplifier/?v=0.12.0-audit

## What this is, and what it is not

The Anthropic Institute's essay
[When AI builds itself](https://www.anthropic.com/institute/recursive-self-improvement)
describes an internal task in which a model is asked to make a small
trainer faster while the same correctness checks still pass.
[This note](https://x.com/i/status/2062568869240476050) is the public
discussion of that work. One failure mode that was thrown out was a
run that did the work outside the timed function and left the timed
function with almost nothing to do.

This repository does not rerun that task. It does not use that
trainer, that hardware, or that result. Nothing here is a claim about
a language model. The harness is plain Ada around the 2–8–1 network
`AI_Amplifier.MLP` already trains.

## The problem that is timed

The problem is fixed in `AI_Amplifier.MLP.Speed`.

| | |
|---|---|
| Network | 2 inputs, 8 tanh units, 1 sigmoid output |
| Seed | `Init_Seed` (`20261104`) |
| Rate | `1.0`, the rate the native XOR test uses |
| Batch | the four XOR points |
| Steps | `Published_Steps`, which is 95 |
| Repeats | 8 full solves from the seed, inside one clock |
| Loss | mean binary cross-entropy under `0.05` |
| Answers | class 1 at least `0.8`, class 0 at most `0.2` |

95 is the first step at which `Train` from that seed, at that rate,
passes the loss and the four answers. `bin/mlp_test` runs that loop
again and requires the same count. The repeats are there so a clock
has a duration to read. Both variants repeat the same 95 steps.
The yardstick is the step count of one solve, not 95 times 8.

On this seed the loss after 95 steps is `0.049831`, and the four
outputs, in dataset order `(0,0)`, `(0,1)`, `(1,0)`, `(1,1)`, are
`0.021495`, `0.951682`, `0.945371`, `0.069367`. Those figures are the
arithmetic. They do not depend on the clock.

## The two trainers

The baseline is a loop of `Train` for one step. That is the call the
XOR test makes. `Train` for one step runs backprop, applies `Step`,
and computes the mean loss again. `Step` builds temporary matrices
with `Scale` and `Add`. The loss `Train` returns is added into a sum
the report prints, so that extra pass stays part of the timed work.
On the recorded run that sum was `283.11`. It is not the final loss.

The faster variant calls the same `Backprop` and then writes
`parameter := parameter - rate * gradient` into the existing weights.
It does not build those temporary matrices, and it does not recompute
the loss between steps. The loss it mentions from `Backprop` is the
loss before the last update. The loss the check uses is the mean
after the last step, same as the baseline.

The weights have to match a public `Train` of 95 steps. On this
build the gap is zero, so the in-place update is the same arithmetic
as `Step`, not a different method that happens to clear `0.05`.

## When the time counts

`Execute` is the timed section. `Prepare` builds the XOR batch and
the reference net first, and that reference is not the timed result.
`Finish` runs after the clock. It is the check, not the training.

A run counts only when all of these hold:

1. The loss and the four XOR answers pass the checks above.
2. The weights match the reference trajectory.
3. The gradient steps were taken while the clock was running, and
   there are `8 * 95` of them.
4. The clock advanced.

Otherwise Ada says the timing does not count, and the microsecond
export is 0. The three deliberate failures, all checked by
`bin/mlp_test` and `tools/wasm-smoke.mjs`:

| Code | What it does | Why it does not count |
|---|---|---|
| Outside | Runs the baseline steps before the clock. The timed section is empty | The steps ran while the clock was stopped. The answers would have passed. The short time is rejected |
| Skipped | One step per repeat | 8 steps are not 760 |
| Easier | The same 760 steps on the single point `(0,0) → 0` | The weights are not the XOR trajectory. The largest gap on this build is `2.411069` |

A zero duration on a run that otherwise passed is rejected as well.
The clock did not advance, so there is no time to publish.

## The clocks

This wasm runtime has no clock, and the module has no imports, so
Ada cannot read one inside the module.

The native test takes process CPU time with `Ada.Execution_Time`
around `Execute`, and passes the microseconds to
`Note_Cpu_Microseconds`. That is CPU time, not wall time.

The page reads the host wall clock with `performance.now` immediately
before and after `Execute`, and passes the two readings to `Finish`.
Ada subtracts them. JavaScript does not train, does not apply the
check, and does not decide whether the run counts. The readings are
wall time around a synchronous call. They are not process CPU time,
and they are not comparable to the native figure.

## The recorded run

These two baseline figures are compiled into
`Published_Native_Us` and `Published_Wasm_Us`. They are the run taken
when this item was added, on the machine that added it (GNAT 16.1.0,
AdaWebPack 24, Node 22). A later run, including CI and a browser,
will not match them. The page prints the run it just did next to
that record. The record is not a pass mark.

| Clock | Baseline | Faster variant | What Ada printed |
|---|---:|---:|---|
| Native process CPU | 33044 µs | 15742 µs | 0.48 times the baseline |
| Wasm host wall, under Node | 10162 µs | 4836 µs | 0.48 times the baseline |

Both lines are 95 steps, repeated 8 times, loss `0.049831`, answers
passing, weights matching. `0.48` means the faster variant took a
little under half as long on that run. It is the extra loss pass and
the temporary matrices, not a different algorithm.

Dividing the native microseconds by the wasm microseconds is not a
speedup. They are different clocks on different compilers. The native
build is the Alire development profile. The wasm build is `-O2`.

## On the page

Run baseline, then Run faster variant. The sentence under the buttons
is Ada's report: steps, repeats, microseconds, loss, the four
answers, whether the time counts, the published record, and, for the
faster variant, how it compared with the baseline just run on that
same clock. The training panel above is a different net. This harness
does not change it.

## What is not proved

`AI_Amplifier.MLP.Speed` is plain Ada (`SPARK_Mode => Off`). The
checks run when the program runs. A failed check in the WebAssembly
module traps that module. There is no Silver claim and no Gold claim.
The tensor kernels it calls keep the levels they already had. This
item does not add a proof, a `pragma Annotate`, or a `pragma Assume`.
