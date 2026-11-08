# Wrong turns

Four recorded mistakes on the XOR trainer this repository already
has, and an Ada checker for the step that comes next. The traces
were written here. They are not someone else's session.

Visible stamp: **v0.16.0-locked**

Live page: https://robertboettchersf.github.io/ada-ai-amplifier/?v=0.16.0-locked

## The idea, and the caveat

The Anthropic Institute's essay
[When AI builds itself](https://www.anthropic.com/institute/recursive-self-improvement)
describes a study of research sessions. A model saw the work from
before a researcher took a detour, and was asked what it would do
next. A separate model, shown how the session turned out, judged
that suggestion against the human's. The public note is
[this post](https://x.com/AnthropicAI/status/2062568870872003021).

The essay says the 129 moments were picked because the human's
choice had room for improvement. On that set, Opus 4.5 beat the
human choice 51% of the time and Mythos Preview 64%. Footnote 8
is the check on that setup. Its wording, from the essay:

> As a check on judge bias, we ran the same test on a separate set of 127 moments where the human’s next move was already strong (as opposed to the original set, where the human’s direction had room for improvement). There, the models’ suggestions were judged better only about 20% of the time.

This repository does not rerun that study. It does not use those
sessions, that judge, or that result. Nothing here is a measure of
research taste. The four traces below are toy states of the 2–8–1
network `AI_Amplifier.MLP` already trains. Each one has a wrong
turn with a measurable repair. A language model is not required,
and the page never calls one.

## What the checker measures

`AI_Amplifier.Traces` rebuilds the trace on the real trainer, applies
one step from a fixed menu, and compares the net before that step
with the net after it. The rules are the ones the XOR test already
uses, plus the weight limit:

| Rule | What has to be true |
|---|---|
| Loss | Mean binary cross-entropy under `0.05` (`Loss_Max`) |
| XOR | Class 1 at least `0.8`, class 0 at most `0.2` |
| Weights | Every value finite and inside ±`1000` (`Weight_Limit`) |

A loss counts as lower or higher only when the gap exceeds
`Loss_Epsilon`, which is `0.0001`. The checker does not call the
loss when a weight is outside the limit, so a huge weight is a
verdict and not a trap.

| Verdict | When |
|---|---|
| `fixes-it` | The net was not solved, and after the step the loss and the four XOR outputs pass, and the weights are valid. The reason is `xor-returned` |
| `makes-it-worse` | A valid net became invalid (`weights-invalid`), the XOR outputs left the range (`xor-left`), or the loss rose (`loss-rose`) |
| `no-better` | The net is still unsolved. The reason is `xor-still-missed` when the loss did fall, and `loss-did-not-fall` when it did not. A menu code that is not a step is `not-a-step` |

The order is the one in `Decide`. The first matching rule is the
reason the page shows.

## The four traces

Each line is an action on the seeded XOR net, or on the
hand-written XOR net. The last line is the wrong turn. The
known-good step is one menu entry that the checker marks
`fixes-it`. The other column is one stored step that does not.
Another menu entry can also fix a trace. The checker reports
that when it happens. It does not require the click to be the
stored repair.

| Trace | What the wrong turn leaves | Known-good step | A step that is not a repair |
|---|---|---|---|
| `rate-diverges` | 40 steps at rate 1, then rate 5 for 15 steps. On this build the loss is about 1.77 and XOR is missed | `rate-1-train-200`. Rate goes back to 1 and training runs 200 steps. XOR returns | `invert-output`. The loss rises. `makes-it-worse`, `loss-rose` |
| `padded-shape` | The hand-written net is loaded. A file with shape `2 4 1` is refused and the net stays. Then a `2 8 1` file of zeros loads. The loss stays at about `ln 2` (0.693) because every gradient is 0 | `hand-xor`. The hand-written net comes back | `train-200`. The loss does not move. `no-better`, `loss-did-not-fall` |
| `silenced-and` | Hidden 2's output weight, the AND unit, is set to 0. XOR breaks. The loss is about 0.53 | `revert-edit`. That weight is put back | `flip-or`. Hidden 1's output weight is negated. The loss rises |
| `stopped-early` | 10 steps at rate 1, then stop. The loss is about 0.69 and XOR is missed | `train-200`. 200 more steps at rate 1. XOR returns | `rate-5-train-10`. The loss rises |

Reverting the rate spike puts back the net from step 40. The loss
falls and XOR is still missed, so that step is `no-better` with
reason `xor-still-missed`. Eight more steps on the early trace
lower the loss a little and do not solve XOR, so the reason is
the same. A lower loss is not, by itself, a fix.

The menu is ten names: `rate-1-train-200`, `rate-5-train-10`,
`train-200`, `train-8`, `hand-xor`, `revert-edit`, `silence-and`,
`flip-or`, `invert-output`, `load-bad-shape`. The page buttons
use the short labels. The tokens are what a model is asked to
reply with.

## On the page

Pick a trace. Ada lists the steps through the wrong turn and the
loss at that point. Pick a next step. Ada runs it and writes the
verdict next to the known-good step's verdict. JavaScript copies
those sentences. It does not train, and it does not decide.

## What a native run can add

`bin/traces_cli` with no arguments prints the four repairs and the
four stored failures. It does not open a socket.
`traces_cli --print-prompt N` prints the text Ada would send for
trace N. That text names the trace and the menu. It does not say
which step is the repair.

`traces_cli --ask N` sends that text once, then hands the reply to
the same checker. It sends a request only when all three of these
are set:

| Variable | What it has to be |
|---|---|
| `TRACES_LLM_URL` | An `http://` or `https://` address, with no spaces |
| `TRACES_LLM_KEY` | One line, at most 400 characters, with no newline |
| `TRACES_LLM_MODEL` | A short model name, with no quotes |

The key is written to a temporary file, that file is set to mode
0600, and curl reads it as a header file. The key is not a curl
argument, and the program does not print it. The file is removed
before the reply is parsed. If any of the three is missing, the
program says that no request was sent.

The reply has to be an OpenAI-shaped chat response whose `content`
string is one menu name. A missing string, or any other text, is
`not-a-step`. A failed curl stops there too. The page never runs
this program. The browser does not see the key and does not talk
to an endpoint.

`bin/traces_test` covers that caller with a local stand-in for
curl. The stand-in records whether it was started, whether the key
appeared on its command line, whether the key was in the header
file, and whether that file's mode was 600. The test does not
contact a model.

## What this is not

- Not a proof. `AI_Amplifier.Traces` is plain Ada. `SPARK_Mode` is
  off. There is no Silver claim and no Gold claim.
- Not a test of research taste. The repairs are thresholds on a
  four-point XOR net.
- Not a live model in the browser. The traces were typed into the
  source.
- Not a claim that a model would pick the known-good step, or that
  these numbers match the essay's 51%, 64%, or about 20%.
- Not a copy of that essay's sessions, prompts, or figures.
