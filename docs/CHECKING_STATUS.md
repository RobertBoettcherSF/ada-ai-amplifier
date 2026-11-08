# Checking status

Items 1 through 17, each with one label. The label is computed
from this build. The page and the README copy that text.

Visible stamp: **v0.19.1-proofs**

Live page: https://robertboettchersf.github.io/ada-ai-amplifier/?v=0.19.1-proofs

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
| proved | That item's own `proof/item_NN.out` exists, its summary unproved count is 0, and the named unit's proved checks are above 0 |
| tested | That did not happen, and the item's test program passed with a positive case count, and its locked spec passed. The row says why it is not a proof |
| unchecked | Neither of those. The evidence says what it would take |

A tested label is not a proof. A proved label is only the units
named in that row, from that row's own run. The summary is
`proved 6 of 17, tested 11, unchecked 0`.

## What the numbers are

`bin/status_cli` reads four build products and the spec sources:

| Input | What it contributes |
|---|---|
| `proof/item_NN.out` | That item's own GNATprove run: the summary total, the flow count, the prover count, the unproved count, and the named unit's proved checks |
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
are a separate number in the same row. Item 16's cases are
the seventeen specs for items 1–17, and `check-locked` has to
print `locked ok`. `specs/item_16.adb` is that item's spec.

Each proved row names its own file. Item 1's run is
`proof/item_01.out`: summary 18, and
`ai_amplifier-version` has 14 proved checks. Items 3 and 7
each run `ai_amplifier-tensors` alone. Both summaries are 414,
of which the tensor detail lines sum to 378 and the flow
column is 36. The counts match because the unit is the same.
They are not one shared run, and they do not include the
version unit. Item 9's step rule is summary 6, with 3 proved
checks. Item 11's verdict rule is summary 15, with 11 proved
checks. Item 12's score gate is summary 2, with 1 proved
check. A unit whose detail lines sum to 0 checks is not proved.

The page wrappers are not in item 3's run. The row says so.
The proved label is the tensor unit.

## What stays unchecked

Items 9 and 11 are proved for the step rule and the verdict
rule. Item 14 is tested. Each of those rows says the live
`--ask` mode is unchecked. That mode needs a key, a URL, and
a model name. CI does not call a live model. A proved or
tested label does not cover that command.

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
item 3 proved. Removing `proof/item_03.out`, or appending
`unproved` to `proof/item_07.out`, has to drop that proved
label. `specs/item_18.adb` locks the seventeen labels, the
summary, and the three agreement pairs.

`build.sh` embeds `obj/gen/STATUS.out` in the page and writes
`site/STATUS.txt`. JavaScript copies the lines into the table.
It does not decide a label. If the report was not written, the
panel says so.

## This build

proved 6 of 17, tested 11, unchecked 0.

| Item | Label | Evidence |
|---|---|---|
| 1 Repo skeleton | proved | gnatprove proof/item_01.out summary 18 flow 4 provers 14 unproved 0; unit ai_amplifier-version 3/3 checks 14; spec item_01 pass asserts 5; check-version ok |
| 2 Splash and live page | tested | item_02 cases 9 spec pass; not proved: the splash is a drawing and is not a proof target |
| 3 Core tensor and maths | proved | gnatprove proof/item_03.out summary 414 flow 36 provers 378 unproved 0; unit ai_amplifier-tensors 30/30 checks 378; not in this run: ai_amplifier-tensors-demo, ai_amplifier-tensors-leaky_demo; spec item_03 pass asserts 15 |
| 4 Tiny trainable MLP | tested | mlp_test cases 185 spec item_04 pass asserts 19; not proved: gradient descent on float weights is not a proof target |
| 5 Tokenizer and attention | tested | attention_test cases 48 spec item_05 pass asserts 20; not proved: the tokenizer and the attention block are not a proof target |
| 6 How-To and leaky ReLU | tested | item_06 cases 17 spec pass; tensors_test cases 67; not proved: the how-to is a document and the leaky demo is not analyzed |
| 7 SPARK proofs of the kernels | proved | gnatprove proof/item_07.out summary 414 flow 36 provers 378 unproved 0; unit ai_amplifier-tensors 30/30 checks 378; spec item_07 pass asserts 24 |
| 8 Weight-space programming | tested | mlp_test cases 185 spec item_08 pass asserts 27; not proved: weight-file checks run with the program and are not proved |
| 9 Recursive prompts | proved | gnatprove proof/item_09.out summary 6 flow 3 provers 3 unproved 0; unit ai_amplifier-chain_rule 3/3 checks 3; recurse_test cases 37 spec item_09 pass asserts 15; live-ask unchecked: recurse_cli --ask needs RECURSE_LLM_URL, RECURSE_LLM_KEY, and RECURSE_LLM_MODEL; CI does not call a live model |
| 10 Training-speed harness | tested | mlp_test cases 185 spec item_10 pass asserts 18; not proved: a measured training time is not a proof |
| 11 Wrong-turn traces | proved | gnatprove proof/item_11.out summary 15 flow 4 provers 11 unproved 0; unit ai_amplifier-trace_rule 4/4 checks 11; traces_test cases 4 spec item_11 pass asserts 22; live-ask unchecked: traces_cli --ask needs TRACES_LLM_URL, TRACES_LLM_KEY, and TRACES_LLM_MODEL; CI does not call a live model |
| 12 Benchmark audit | proved | gnatprove proof/item_12.out summary 2 flow 1 provers 1 unproved 0; unit ai_amplifier-audit_rule 2/2 checks 1; audit_test cases 13 spec item_12 pass asserts 11 |
| 13 Reward hacking | tested | reward_test cases 9 spec item_13 pass asserts 43; not proved: the two graders score float nets and are not proved |
| 14 Harness comparison | tested | harness_test cases 406 spec item_14 pass asserts 19; live-ask unchecked: harness_cli --ask needs HARNESS_LLM_URL, HARNESS_LLM_KEY, and HARNESS_LLM_MODEL; CI does not call a live model; not proved: the harness schedule is not a proof target |
| 15 Checked steps | tested | steps_test cases 16 spec item_15 pass asserts 10; not proved: a step grade recomputes values and is not a proof |
| 16 Locked statements | tested | check-locked cases 17 spec item_16 pass asserts 14; not proved: a fingerprint detects an edit and does not prove the spec |
| 17 Second checker | tested | recheck_test agree 44 of 44, 22 of 22, 12 of 12 spec item_17 pass asserts 18; not proved: agreement of two checkers is not a proof of either |
| 19 Reasoning summary | proved | gnatprove proof/item_19.out summary 22 flow 7 provers 15 unproved 0; unit ai_amplifier-summary_rules 6/6 checks 15; summary_test cases 36 spec item_19 pass asserts 22; not in this run: ai_amplifier-summary |
## What is proved

Nothing in this item is proved. `AI_Amplifier.Status` is plain
Ada. `SPARK_Mode` is off. It does not decide a label from a
shared project total. Each proved item has its own log.
This change does not add an Assume pragma or an Annotate
pragma.

The labels describe only the checks this repository runs. They
do not describe anyone else's proof, and they do not describe a
live model. A fingerprint, an agreement, and a passing test are
still tests.

Item 19 is a row after those seventeen. It is not inside the
summary `proved 6 of 17, tested 11, unchecked 0`. The row is
proved for `ai_amplifier-summary_rules`: `proof/item_19.out`
is summary 22, 15 checks on that unit, unproved 0. The
summaries and the step checker are not in that run.
