# Recursive prompts

The idea, and what this repository actually shows.

Visible stamp: **v0.21.0-moreproofs**

Live page: https://robertboettchersf.github.io/ada-ai-amplifier/?v=0.21.0-moreproofs

## The idea

A prompt can carry a small state and ask for that same prompt again,
with the state moved one step closer to a case that needs no further
call. The chain is the list of those states. Something has to decide
when a step is wrong, or the chain will keep a bad value and treat
it as the next truth.

[recursive_llm](https://github.com/andyk/recursive_llm) is a public
repository about that idea: ordinary language as the program, and a
language model as the thing that takes the step. GitHub reports its
license as null. The repository has no license file. This project
does not copy it. The Ada, the recorded chains, the wording of the
optional caller, and this note were written here. There are no files,
prompt texts, videos, or screenshots from that repository in this
tree.

This repository does not repeat that project's runs, and it does not
claim the same results. The page does not host a language model.

## What the page shows

Four chains are stored in `AI_Amplifier.Recurse`. The page asks Ada
to replay each one and then copies the lines Ada returns. A good run
and three halted runs are on the screen together.

The problem is Fibonacci. F(0) is 0, F(1) is 1, and each later value
is the sum of the two before it. The opening blob for a target n is:

```text
index n
minus-one 0
current 1
```

`index` counts the steps still to take. It moves toward 0. At 0 the
chain stops, and the answer is `minus-one`. That field is F(n) when
every step was the rule below. `current` is then F(n + 1). When n is
already 0, no step runs, the answer is 0, and `current` stays 1.

A blob after the opening is checked in this order:

1. **Parse.** Three fields, each once: `index`, `minus-one`,
   `current`. A blank line is ignored. A line whose first visible
   character is `#` is ignored. Each number is an integer from 0 to
   20000, which is `Max_Value`. Anything else is `bad parse`.
2. **Past base.** If the previous index was already 0, the extra
   blob is `past base`.
3. **Toward the base.** The new index has to be exactly one less.
   Otherwise the check is `not toward base`, even when the two
   running values happen to be the next pair.
4. **Arithmetic.** `minus-one` has to be the previous `current`.
   `current` has to be the previous `minus-one` plus the previous
   `current`. Otherwise the check is `bad arithmetic`.

The first failed check stops the chain. Ada names that check. The
opening itself has to be the seed above, with `index` at most 20
(`Max_Index`). A different opening is `bad opening`. A chain that
ends while `index` is still above 0 is unfinished, not a success.
A text longer than 4000 characters (`Max_Chain`) is `too long`
before any line is parsed.

`fib-6-complete` is the rule applied six times. The last blob is
`index 0`, `minus-one 8`, `current 13`. The answer is 8, which is
F(6). That text is written out in the source. `Correct_Chain` builds
the same text from the rule, and `bin/recurse_test` requires the two
to match, so a drift in either one fails the test. The same test
checks F(0) through F(20) against a table. F(20) is 6765.

`fib-6-bad-sum` follows the rule until the blob that should carry
`current 3`. The recorded value is 4. Ada stops there and reports
bad arithmetic. The earlier blobs stay accepted.

`fib-4-stalled` writes the successor pair and leaves the index at 4.
Ada reports not toward base. It does not go on to praise the pair.

`fib-3-garbled` is readable for two blobs. The third says
`index two`. Ada reports bad parse and does not treat the zeroes of
an unread number as a real state.

## What a native run can add

`bin/recurse_cli` with no arguments prints the four replays and
does not open a socket. `recurse_cli --print-prompt N` prints the
text Ada would send for the opening state of N. That text was
written here.

`recurse_cli --ask N` takes one step at a time from a chat endpoint,
then hands the reply to the same checker. It sends a request only
when all three of these are set:

| Variable | What it has to be |
|---|---|
| `RECURSE_LLM_URL` | An `http://` or `https://` address, with no spaces |
| `RECURSE_LLM_KEY` | One line, at most 400 characters, with no newline |
| `RECURSE_LLM_MODEL` | A short model name, with no quotes |

The key is written to a temporary file, that file is set to mode
0600, and curl reads it as a header file. The key is not a curl
argument, and the program does not print it. The file is removed
before the reply is parsed. If any of the three is missing, or the
index is already 0, the program says that no request was sent.

The reply has to be an OpenAI-shaped chat response whose `content`
string is the next blob. A missing string, a blob that does not
parse, or a blob that fails a check stops the chain. A failed curl
stops it too. The page never runs this program. The browser does
not see the key and does not talk to an endpoint.

`bin/recurse_test` covers that caller with a local stand-in for
curl. The stand-in records whether it was started, whether the key
appeared on its command line, and whether the key was in the header
file. The test does not contact a model.

## What this is not

- Not a proof. `AI_Amplifier.Recurse` is plain Ada. `SPARK_Mode` is
  off. There is no Silver claim and no Gold claim.
- Not a live model in the browser. The chains on the page were
  typed into the source.
- Not a claim that a model would emit these blobs, or that these
  numbers match a published run.
- Not a copy of the unlicensed repository linked above.
