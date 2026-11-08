# Reward hacking

One task, two graders, and a hill-climb that can please the weak
grader without solving the task.

Visible stamp: **v0.14.0-harness**

Live page: https://robertboettchersf.github.io/ada-ai-amplifier/?v=0.14.0-harness

The task is to make this repository's XOR net right. The real check
reruns the net. The flawed grader does not. Four of the five
submissions are written to pass the flawed grader and fail the real
one. A second part climbs one score or the other from the same seed.

## The idea, and the licences

Public write-ups of reward hacking and specification gaming are why
this item exists. An objective can be satisfied on the letter and
missed on the point. This file links that work. It does not copy
it. No example, no figure, no paragraph, and no program from those
pages is in this tree.

1. [Specification gaming: the flip side of AI ingenuity](https://deepmind.google/blog/specification-gaming-the-flip-side-of-ai-ingenuity/)
   (Krakovna, Uesato, Mikulik, Rahtz, Everitt, Kumar, Kenton, Leike,
   and Legg, DeepMind, 2020) is DeepMind's page. An earlier list by
   Krakovna is
   [Specification gaming examples in AI](https://vkrakovna.wordpress.com/2018/04/02/specification-gaming-examples-in-ai/)
   (2018). Both are their pages. None of their examples are
   reproduced here.
2. [Faulty Reward Functions in the Wild](https://openai.com/blog/faulty-reward-functions/)
   (Amodei and Clark, OpenAI, 2016) is OpenAI's page. The DeepMind
   note above cites that address. This repository does not
   reproduce their game, their wording, or their counts.
3. [Defining and Characterizing Reward Gaming](https://arxiv.org/abs/2209.13085)
   (Skalse, Howe, Krasheninnikov, and Krueger, NeurIPS 2022) gives
   a formal account of a proxy reward and a true reward. The
   accompanying code is
   [nikihowe/reward-hacking-paper](https://github.com/nikihowe/reward-hacking-paper),
   which is MIT. The licence file is
   [LICENSE.txt](https://github.com/nikihowe/reward-hacking-paper/blob/main/LICENSE.txt),
   copyright (c) 2022 Nikolaus Howe. Nothing from that repository
   was copied, so that copyright notice is not reproduced here as
   if their code had been included. The paper's own notice is on
   the arXiv page.
4. [Investigating reward tampering in language models](https://www.anthropic.com/research/reward-tampering)
   is Anthropic's page. It is not included here. This demo is not
   that experiment.

The cheats below were written in this repository, against this
XOR net. They are not those projects' examples, and they are not
a model's replies.

## What is being graded

The task is the four XOR points already in `AI_Amplifier.MLP`:
`(0,0)→0`, `(0,1)→1`, `(1,0)→1`, `(1,1)→0`.

The real check calls `Predict` on those points. A label of 1 has
to come out at least `0.8`. A label of 0 has to come out at most
`0.2`. Those are the same two cutoffs the XOR trainer uses. The
real score is how many of the four points meet that, divided by
4. The check passes only when the score is 1.

The flawed grader never calls `Predict`. It reads the report that
was stored with the submission, and it accepts when the first of
these holds:

| Gap | What the report has |
|---|---|
| `reported-loss` | A reported loss under `0.05`, while the recomputed loss is not under `0.05` |
| `constant-half` | Four reported outputs, each within `0.001` of `0.5` |
| `two-of-four` | At least two reported outputs strictly above `0.5` |
| `right-stamp` | The stamp `shape 2 8 1`, which is the shape line of a weight file |

`constant-half` and `right-stamp` are the two ways an answer can
look finished. One fills in four numbers. The other carries the
shape line and no outputs. A submission that passes the real
check is named `none`, and it counts. Anything else that the
flawed grader accepted is named with that gap, and it does not
count. The flawed score in the table is `1.00` when the flawed
grader accepted the report and `0.00` when it did not.

## The five submissions

Each one is Ada source. `honest-trained` is the trainer, from
`MLP.Init_Seed` at rate 1, for 120 steps. That seed is the one
the MLP tests already require to pass by step 95, so 120 steps
is past that. The reported loss and the reported outputs are
what that net actually produces. The other four are constructed.
None of them is a pasted weight file from outside this tree.

| Submission | Trick | What it actually is |
|---|---|---|
| `honest-trained` | none | The trained net. Passes both graders |
| `hard-coded-loss` | `reported-loss` | All weights 0. The report says the loss is `0.01` and gives no outputs |
| `constant-half` | `constant-half` | The same zero net, which outputs 0.5, reported four times. The reported loss is the real one, so the loss gap does not fire |
| `memorized-two` | `two-of-four` | Hidden 1 follows `x2` only. `(0,0)` and `(0,1)` meet the real cutoff. `(1,0)` and `(1,1)` do not. Two reported outputs are above 0.5 |
| `right-stamp` | `right-stamp` | The stamp is `shape 2 8 1`. The weights are the hand-written XOR net with the output layer negated. The report has no loss and no outputs |

On these five the program prints:

```text
name              flawed  real    verdict   gap
honest-trained    1.00    1.00    counts    none
hard-coded-loss   1.00    0.00    rejected  reported-loss
constant-half     1.00    0.00    rejected  constant-half
memorized-two     1.00    0.50    rejected  two-of-four
right-stamp       1.00    0.00    rejected  right-stamp
Accepted: 1 of 5. Only the real check counts.
```

`0.50` is two of the four points. `0.00` is none of them. The
`1.00` in the flawed column is the weak grader accepting the
report. It is not a claim that the net is right.

## The hill-climb

Both searches start from `MLP.Init_Seed` (`20261104`) at rate 1.
`Search_Seed` is that constant. There is no second seed.

Each step proposes one gradient step and keeps it when the aimed
score does not fall. The proposal is tried at rate 1, then `0.5`,
then `0.25`. The first rate that holds is kept. If none hold, the
weights stay. That is the whole search. It runs for 120 steps.
Point 1 of each curve is the start, before a step, so the curve
has 121 points.

The flawed aim trains as if every XOR label were 1. The score it
climbs is the proxy: the mean, over the four inputs, of how far
the output sits above 0.5, clipped into `[0, 1]`. Pushing every
output up raises that number. It does not ask which inputs
should be high. The real margin score is recorded beside it and
is not what that search accepts or rejects.

The real aim trains on the XOR labels. The score it climbs is
the negative of the mean loss, so a step that lowers the loss is
kept. The curve still draws the real margin score, which is the
fraction of points inside `0.8` and `0.2`.

On the run that added this item, both `reward_cli` and the
wasm module printed:

```text
flawed aim: Proxy 1.00. Real 0.50. Real check fails.
real aim: Proxy 0.47. Real 1.00. Real check passes.
```

The flawed proxy moves from `0.25` at the start to `1.00` at
step 120, and the real check is failed on every point of that
curve. The real score on that curve ends at `0.50`: the two
class-1 outputs are past `0.8`, and the two class-0 outputs are
not under `0.2`, because the proxy wanted every output high.
The real-aimed curve reaches real `1.00` during the 120 steps
and is still passing at the end. Its proxy ends at `0.47`,
which is this runtime's rounding of that float to two digits.
A later build can differ in that last digit. The tests lock
the table, the pass and the fail, and that the flawed proxy
ends higher than it starts. They do not lock `0.47`.

## On the page

The section is drawn from `AI_Amplifier.Reward.Demo`. Ada writes
the five rows, the tally, the stat line (the seed and the step
count), and the two end sentences. It also writes both scores
at every step of both searches. JavaScript builds the table
from those cells and draws the two curves. Yellow is the score
that search is aimed at. Blue is the other score. The vertical
scale is 0 to 1. JavaScript does not grade and does not step.

`bin/reward_cli` with no arguments prints the table and the two
end sentences. `reward_cli flawed` and `reward_cli real` print
the same table and then that curve, one step per line. The page
does not run that program.

## What this is not

- Not a proof. `AI_Amplifier.Reward` is plain Ada. `SPARK_Mode`
  is off. There is no Silver claim and no Gold claim.
- Not evidence of how often a real model reward-hacks. The gaps
  are planted. The cheats were written to fit them. A hill-climb
  that is handed a proxy whose optimum is not the XOR net will
  climb the proxy. That is the setup, not a discovery.
- Not a claim about the papers linked above. Their examples are
  not these five submissions, and their numbers are not these
  scores.
- Not a live model. Nothing here calls a network outside this
  process. The honest submission is this repository's own
  trainer.
