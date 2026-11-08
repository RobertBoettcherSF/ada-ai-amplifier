# Checking status

Items 1 through 17, each with one label. The label is computed
from this build. The page and the README copy that text.

Visible stamp: **v0.19.0-summary**

Live page: https://robertboettchersf.github.io/ada-ai-amplifier/?v=0.18.0-status

## The idea, and the licence

[openai/math](https://github.com/openai/math) labels results by
how far verification has gone. The repository is Apache-2.0.
That licence would allow a copy if the notice were kept. This
tree does not contain one. No file, no table, and no sentence
from that repository is here. The link is the credit for
labelling a result by its verification stage. `STATUS` and
`AI_Amplifier.Status` are a new program about this repository's
own items.

## The three labels

| Label | When the program prints it |
|---|---|
| proved | GNATprove analyzed that item's units, every analyzed subprogram was proved, and the summary's unproved column is 0 |
| tested | That did not happen, and the item's test program passed with a positive case count, and its locked spec passed |
| unchecked | Neither of those. The evidence says what it would take |

A tested label is not a proof. A proved label is only the units
named in that row. The summary is `proved 3 of 17, tested 14,
unchecked 0`.

## What the numbers are

`bin/status_cli` reads four build products and the spec sources:

| Input | What it contributes |
|---|---|
| `proof/gnatprove.out` | The summary total, the flow count, the prover count, and each unit's analyzed fraction and proved checks |
| `obj/gen/tests.out` | `tensors ok`, `mlp ok`, and the other program lines, plus `cases <program> <count>` |
| `obj/gen/specs.out` | `item NN pass` for items 1–15 and 17 |
| `obj/gen/recheck-report.txt` | The three agreement pairs from item 17 |
| `specs/item_NN.adb` | How many `pragma Assert` lines that passing spec contains |

The case count is how many checks that program recorded on
this run. It is not a count of source lines. Items 4, 8, and
10 share `mlp_test`, so they show the same case count. Item 6
counts the asserts in `item_06` and also requires `tensors_test`,
because the leaky ReLU checks live in that program. Item 11's
`traces_test` records the four traces. The locked spec's asserts
are a separate number in the same row. Item 16 has no
`item_16.adb`. Its cases are the sixteen specs for items 1–15
and 17, and `check-locked` has to print `locked ok`.

The detail lines under `ai_amplifier-tensors` sum to 378 proved
checks. The summary total is 419, which is those 378 plus 41
flow checks. Both numbers are read from the log. They are one
run. Items 3 and 7 both name that run. Item 1's units are
proved with 0 checks in the detail lines. The 419 are not the
stamp.

The page wrappers `ai_amplifier-tensors-demo` and
`ai_amplifier-tensors-leaky_demo` are 0 of 0 analyzed. Item 3's
row says they are not proved. The proved label is the kernels.

## What stays unchecked

Items 9, 11, and 14 are tested for the recorded checks and the
stand-in caller. Each row also says the live `--ask` mode is
unchecked. That mode needs a key, a URL, and a model name.
CI does not call a live model. A tested label does not cover
that command.

| Item | Command | What it would take |
|---|---|---|
| 9 | `recurse_cli --ask` | `RECURSE_LLM_URL`, `RECURSE_LLM_KEY`, `RECURSE_LLM_MODEL` |
| 11 | `traces_cli --ask` | `TRACES_LLM_URL`, `TRACES_LLM_KEY`, `TRACES_LLM_MODEL` |
| 14 | `harness_cli --ask` | `HARNESS_LLM_URL`, `HARNESS_LLM_KEY`, `HARNESS_LLM_MODEL` |

There is no unchecked item among 1–17 on this tree. The summary's
0 is that count. It is not a claim that a live model was run.

## The file CI checks

`tools/check-status.sh` runs the programs, writes the logs, and
runs `status_cli`. The stdout has to match `STATUS` byte for
byte. A throwaway copy of the test log with `mlp ok` removed
has to label items 4, 8, and 10 unchecked, and it has to leave
item 3 proved. `specs/item_18.adb` locks the seventeen labels,
the summary, the 419 checks, and the three agreement pairs.

`build.sh` embeds `obj/gen/STATUS.out` in the page and writes
`site/STATUS.txt`. JavaScript copies the lines into the table.
It does not decide a label. If the report was not written, the
panel says so.

## This build

proved 3 of 17, tested 14, unchecked 0.

| Item | Label | Evidence |
|---|---|---|
| 1 Repo skeleton | proved | gnatprove ai_amplifier 1/1 checks 0, ai_amplifier-version 3/3 checks 0; spec item_01 pass asserts 5; check-version ok |
| 2 Splash and live page | tested | item_02 cases 9 spec pass |
| 3 Core tensor and maths | proved | gnatprove ai_amplifier-tensors 30/30 checks 378; summary 419 flow 41 provers 378 unproved 0; not proved ai_amplifier-tensors-demo 0/0, ai_amplifier-tensors-leaky_demo 0/0; spec item_03 pass asserts 15 |
| 4 Tiny trainable MLP | tested | mlp_test cases 185 spec item_04 pass asserts 19 |
| 5 Tokenizer and attention | tested | attention_test cases 48 spec item_05 pass asserts 20 |
| 6 How-To and leaky ReLU | tested | item_06 cases 17 spec pass; tensors_test cases 67 |
| 7 SPARK proofs of the kernels | proved | gnatprove summary 419 flow 41 provers 378 unproved 0; units ai_amplifier 1/1 checks 0, ai_amplifier-tensors 30/30 checks 378, ai_amplifier-version 3/3 checks 0; spec item_07 pass asserts 24 |
| 8 Weight-space programming | tested | mlp_test cases 185 spec item_08 pass asserts 27 |
| 9 Recursive prompts | tested | recurse_test cases 37 spec item_09 pass asserts 15; live-ask unchecked: recurse_cli --ask needs RECURSE_LLM_URL, RECURSE_LLM_KEY, and RECURSE_LLM_MODEL; CI does not call a live model |
| 10 Training-speed harness | tested | mlp_test cases 185 spec item_10 pass asserts 18 |
| 11 Wrong-turn traces | tested | traces_test cases 4 spec item_11 pass asserts 22; live-ask unchecked: traces_cli --ask needs TRACES_LLM_URL, TRACES_LLM_KEY, and TRACES_LLM_MODEL; CI does not call a live model |
| 12 Benchmark audit | tested | audit_test cases 13 spec item_12 pass asserts 11 |
| 13 Reward hacking | tested | reward_test cases 9 spec item_13 pass asserts 43 |
| 14 Harness comparison | tested | harness_test cases 406 spec item_14 pass asserts 19; live-ask unchecked: harness_cli --ask needs HARNESS_LLM_URL, HARNESS_LLM_KEY, and HARNESS_LLM_MODEL; CI does not call a live model |
| 15 Checked steps | tested | steps_test cases 16 spec item_15 pass asserts 10 |
| 16 Locked statements | tested | check-locked cases 16 spec pass; no item_16.adb |
| 17 Second checker | tested | recheck_test agree 44 of 44, 22 of 22, 12 of 12 spec item_17 pass asserts 18 |
| 19 Reasoning summary | tested | summary_test cases 36 spec item_19 pass asserts 22 |

## What is proved

Nothing in this item is proved. `AI_Amplifier.Status` is plain
Ada. `SPARK_Mode` is off. There is no new proof. GNATprove
level 2 still proves 419 checks on the root, the version unit,
and the tensors. This change does not add an Assume pragma or
an Annotate pragma.

The labels describe only the checks this repository runs. They
do not describe anyone else's proof, and they do not describe a
live model. A fingerprint, an agreement, and a passing test are
still tests.

Item 19 is a row after those seventeen. It is not inside the
summary `proved 3 of 17, tested 14, unchecked 0`. Its label is
tested when `summary_test` passes and `item_19` passes. The
flag rules are a separate proof of 22 checks in
`proof/summary_rules.out`. That proof does not cover the
summaries or the step checker, so the row is not proved.
