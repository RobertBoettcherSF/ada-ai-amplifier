# Same model, different harness

One fixed solver, four harnesses, eight tasks, one seed.
The solver does not change. The harness does. The score moves.

Visible stamp: **v0.19.1-proofs**

Live page: https://robertboettchersf.github.io/ada-ai-amplifier/?v=0.19.1-proofs

## The idea, and the licences

Public write-ups say that the software around a model can move
a score as much as a change of model. This file links that work.
It does not copy it. No sentence, no figure, no count, and no
program from those pages is in this tree.

1. [Effective harnesses for long-running agents](https://www.anthropic.com/research/effective-harnesses-for-long-running-agents)
   is Anthropic's page. A second note on the same subject is
   [Harness design for long-running apps](https://www.anthropic.com/research/harness-design-long-running-apps).
   Both are their pages. Neither grants a licence to copy the
   text. Nothing from them is included here.
2. [Stop Comparing LLM Agents Without Disclosing the Harness](https://arxiv.org/abs/2605.23950)
   (Zhang, Wang, Ge, Xu, Hamm, and Reddy, 2026) is the arXiv
   record `2605.23950`. The record does not name a licence that
   permits copying the paper into this tree. The authors hold
   the copyright. The paper's own notice is on the arXiv page.
   Nothing from it is included here.

The solver below was written in this repository. It is a few
dozen lines with a fixed list of mistakes. It is not one of
those systems, and it is not a language model.

## What this does and does not show

The four rows below use the same procedure, `Model_Propose`.
A harness is not an argument of that procedure. The same task,
the same attempt, the same note, and the same state are the
same text, whichever harness is about to read it.

The score still changes, because the harness decides what note
to send and which reply to keep.

That is a change of score. It is not a measurement of how large
the change is for a real model. The solver here is tiny, its
mistakes are planted, and it has no weights. A gap in this
table is not a gap on a frontier model.

## The tasks

Eight tasks. The seed on every row is `20261104`, the same
number the MLP uses. Nothing in the solver draws from it.
The seed is here so a second run cannot quietly use another one.

Four tasks are Fibonacci chains. The checker is
`AI_Amplifier.Recurse`, the same one as the recorded chains.
The answer is F(n) when the chain reaches index 0.

| Task | What the solver does on the first try |
|---|---|
| `fib-1` | The one correct step. F(1) is 1 |
| `fib-3` | On the step that leaves index 2, it writes `index two` |
| `fib-4` | On the step that leaves index 4, it keeps index 4. The pair is the one the rule wanted for index 3 |
| `fib-6` | On the step that leaves index 4, it writes `current 4` where the rule wants 3. F(6) is 8 |

`index two` is the garble from the recorded chain
`fib-3-garbled`. The stall is the shape of `fib-4-stalled`.
The `current 4` is the step in `fib-6-bad-sum`. The chains
themselves are built here. They are not those recordings
pasted in.

A note of `bad-parse` clears the garble. So does a later
attempt. A note of `again` does not clear the stall or the
bad sum. `not-toward-base` clears the stall.
`bad-arithmetic` clears the bad sum.

Four tasks are the wrong-turn repairs. The checker is
`AI_Amplifier.Traces`. A repair counts only when that
checker says `fixes-it`.

| Task | First reply | Reply after a checker word |
|---|---|---|
| `rate-diverges` | `invert-output` | `rate-1-train-200` |
| `padded-shape` | `train-200` | `hand-xor` |
| `silenced-and` | `flip the hidden`, which is not a menu token. The next try that only hears `again` is `flip-or` | `revert-edit` |
| `stopped-early` | `rate-5-train-10` | `train-200` |

The checker words that clear a trace are `makes-it-worse`,
`no-better`, and `not-a-step`. The word `again` does not.

## The four harnesses

| Harness | What it keeps |
|---|---|
| `one-shot` | The first reply. It does not ask again |
| `retry` | The first reply that parses, and at most `Retry_Tries` (3) asks. A reply that parses is kept even when the checker would reject it. The note between asks is `again` |
| `checked` | A step only when the item 9 or item 11 checker accepts it. The note sent back is that checker's word. The call cap is `Checked_Cap` (12). One step is abandoned after `Attempt_Cap` (4) failed tries, and that step is still not kept |
| `budgeted` | The same check as `checked`, with `Budget_Cap` (3) model calls for the whole task |

A step is one call to the solver. `wrong accepted` counts a
kept reply that the checker does not accept. The checked
harness and the budgeted harness add nothing to that column.
A task can still be unfinished. Budgeted `fib-3` is: the
garble is rejected, the correction is kept, and the cap
arrives before index 0.

On this seed and these eight tasks the program prints:

```text
harness    solve rate    steps    wrong accepted
one-shot   1 of 8        8        7
retry      2 of 8        10       6
checked    8 of 8        25       0
budgeted   5 of 8        18       0
```

`1 of 8` is `fib-1` only. `2 of 8` is `fib-1` and `fib-3`:
retry drops `index two` because it does not parse, then
keeps the correct chain. It still keeps the stall, the bad
sum, and the wrong menu tokens, because those parse.
`8 of 8` is every task. `5 of 8` is `fib-1` and the four
repairs. `fib-3`, `fib-4`, and `fib-6` need more than three
calls once a mistake has to be corrected and the walk has
to finish.

The page opens on `fib-3`. The four walks there are:

| Harness | What the lines show |
|---|---|
| one-shot | One call. It keeps `index two`. Not solved. One wrong answer kept |
| retry | The garble is rejected. The second call is kept and the chain reaches the base |
| checked | The step out of index 3 is kept. `index two` is rejected. The checker word comes back. The walk reaches the base in four calls |
| budgeted | The same three calls as the start of the checked walk, then the cap. Index is still 1. Not solved. Nothing wrong was kept |

JavaScript copies those lines. It does not decide.

## The native program

`bin/harness_cli` with no arguments prints the table and the
`fib-3` walks. It does not open a socket.

`harness_cli --print-prompt NAME` prints the prompt for that
task and does not send it.

`harness_cli --ask NAME` runs the checked harness and takes
each step from a chat endpoint, in place of `Model_Propose`.
It sends a request only when `HARNESS_LLM_URL` is an `http://`
or `https://` address, `HARNESS_LLM_KEY` is a single line, and
`HARNESS_LLM_MODEL` is set. The key is written to a mode 0600
file for curl and is not placed on the command line. If any
of the three is missing, the program says no request was sent
and does not fall back to the Ada solver. The page does not
run this program, and the page does not call a model.

## What is not proved

This unit is plain Ada. `SPARK_Mode` is off. There is no
`pragma Annotate` and no `pragma Assume`. The tests check
the table, that the same arguments produce the same text
under every harness name, and that a known-wrong step is
not kept by the checked harness. Those are tests. They are
not a proof.
