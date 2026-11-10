# Checking status

Items 1 through 19, each with one label. The label is computed
from this build. The page and the README copy that text.

Visible stamp: **v0.24.0-readme**

Live page: https://robertboettchersf.github.io/ada-ai-amplifier/?v=0.24.0-readme

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
named in that row, from that row's own run. The summary counts
items 1 through 19. On this tree it is
`proved 12 of 19, tested 7, unchecked 0`.

## What the numbers are

`bin/status_cli` reads four build products and the spec sources:

| Input | What it contributes |
|---|---|
| `proof/item_NN.out` | That item's own GNATprove run: the summary total, the flow count, the prover count, the unproved count, and the named unit's proved checks |
| `obj/gen/tests.out` | `tensors ok`, `mlp ok`, and the other program lines, plus `cases <program> <count>` |
| `obj/gen/specs.out` | `item NN pass` for the specs that loop runs: items 1–17 and 19. Item 18's program reads that file, so its own pass line is not an input |
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

## The stand-in, and what stays unchecked

Items 9 and 11 are proved for the step rule and the verdict
rule. Item 14 is tested. Each of those rows says `--ask` was
tested against a stand-in model. The stand-in runs on the CI
machine, returns fixed chat replies, and needs no network and
no real key. The three commands are pointed at it with
`RECURSE_LLM_URL`, `RECURSE_LLM_KEY`, and `RECURSE_LLM_MODEL`,
and the same three names for traces and for the harness.
`ask_standin` records 36 cases: a reply the checker accepts,
a wrong answer, a broken body, and a timeout, for each command.
A missing `ask-standin ok` line puts the old unchecked wording
back. It does not change the proved label.

No real model is called. Real-model behaviour stays unchecked.
A proved or tested label does not cover a real model.

There is no unchecked item among 1–19 on this tree. The summary's
0 is that count. It is not a claim that a real model was run.

## The file CI checks

`tools/check-status.sh` runs the programs, writes the logs, and
runs `status_cli`. The stdout has to match `STATUS` byte for
byte. `tools/check-built-status.py` fails if an `item_NN.adb`
main in `ada_ai_amplifier.gpr` has no `item NN` row in `STATUS`.
A throwaway copy of the test log with `mlp ok` removed
has to label items 4, 8, and 10 unchecked, and it has to leave
item 3 proved. Removing the `ask-standin ok` line has to put
`live-ask unchecked` back on items 9, 11, and 14, and it has
to leave those labels proved, proved, and tested. Removing
`proof/item_09.out` has to drop item 9's proved label even
when the stand-in line is still there. Removing `proof/item_03.out`, or appending
`unproved` to `proof/item_07.out`, has to drop that proved
label. A throwaway `proof/item_18.out` that names
`ai_amplifier-status` and not `ai_amplifier-label_rule` has
to leave item 18 tested. Appending `unproved` to the real
label-rule log has to put the tested label back.
`specs/item_18.adb` locks
the labels, the summary, and the three agreement pairs.

`build.sh` embeds `obj/gen/STATUS.out` in the page and writes
`site/STATUS.txt`. JavaScript copies the lines into the table.
It does not decide a label. If the report was not written, the
panel says so.

## This build

proved 12 of 19, tested 7, unchecked 0.

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
| 9 Recursive prompts | proved | gnatprove proof/item_09.out summary 6 flow 3 provers 3 unproved 0; unit ai_amplifier-chain_rule 3/3 checks 3; recurse_test cases 37 spec item_09 pass asserts 15; tested against a stand-in model: recurse_cli --ask used RECURSE_LLM_URL, RECURSE_LLM_KEY, and RECURSE_LLM_MODEL; ask_standin cases 36; no real model is called; real-model behaviour stays unchecked |
| 10 Training-speed harness | tested | mlp_test cases 185 spec item_10 pass asserts 18; not proved: a measured training time is not a proof |
| 11 Wrong-turn traces | proved | gnatprove proof/item_11.out summary 15 flow 4 provers 11 unproved 0; unit ai_amplifier-trace_rule 4/4 checks 11; traces_test cases 4 spec item_11 pass asserts 22; tested against a stand-in model: traces_cli --ask used TRACES_LLM_URL, TRACES_LLM_KEY, and TRACES_LLM_MODEL; ask_standin cases 36; no real model is called; real-model behaviour stays unchecked |
| 12 Benchmark audit | proved | gnatprove proof/item_12.out summary 2 flow 1 provers 1 unproved 0; unit ai_amplifier-audit_rule 2/2 checks 1; audit_test cases 13 spec item_12 pass asserts 11 |
| 13 Reward hacking | proved | gnatprove proof/item_13.out summary 4 flow 2 provers 2 unproved 0; unit ai_amplifier-reward_rule 3/3 checks 2; proved for the accept/reject gate; reward_test cases 9 spec item_13 pass asserts 43; not proved: the two graders score float nets and are not proved |
| 14 Harness comparison | tested | harness_test cases 406 spec item_14 pass asserts 19; tested against a stand-in model: harness_cli --ask used HARNESS_LLM_URL, HARNESS_LLM_KEY, and HARNESS_LLM_MODEL; ask_standin cases 36; no real model is called; real-model behaviour stays unchecked; not proved: the harness schedule is not a proof target |
| 15 Checked steps | proved | gnatprove proof/item_15.out summary 8 flow 4 provers 4 unproved 0; unit ai_amplifier-step_rule 5/5 checks 4; proved for the step-grade rule; steps_test cases 16 spec item_15 pass asserts 10; not proved: a step grade recomputes values and is not a proof |
| 16 Locked statements | proved | gnatprove proof/item_16.out summary 11 flow 2 provers 9 unproved 0; unit ai_amplifier-lock_rule 3/3 checks 9; proved for the lock-compare rule; check-locked cases 17 spec item_16 pass asserts 14; not proved: a fingerprint detects an edit and does not prove the spec |
| 17 Second checker | proved | gnatprove proof/item_17.out summary 9 flow 2 provers 7 unproved 0; unit ai_amplifier-agree_rule 4/4 checks 7; proved for the agreement count; recheck_test agree 44 of 44, 22 of 22, 12 of 12 spec item_17 pass asserts 18; not proved: agreement of two checkers is not a proof of either |
| 18 Checking status | proved | gnatprove proof/item_18.out summary 6 flow 3 provers 3 unproved 0; unit ai_amplifier-label_rule 4/4 checks 3; proved for the label rule; spec item_18 asserts 57; not in this run: ai_amplifier-status; not proved: AI_Amplifier.Status is plain Ada and is not a proof target |
| 19 Reasoning summary | proved | gnatprove proof/item_19.out summary 22 flow 7 provers 15 unproved 0; unit ai_amplifier-summary_rules 6/6 checks 15; summary_test cases 36 spec item_19 pass asserts 22; not in this run: ai_amplifier-summary |

## What is proved

`AI_Amplifier.Label_Rule` is proved for the label rule:
`proof/item_18.out` is summary 6, 3 checks on that unit,
unproved 0. Proved needs that item's own log, a positive
check count, and an unproved count of 0. `AI_Amplifier.Status`
is plain Ada. `SPARK_Mode` is off. It reads the logs and is
not in that run. It does not decide a label from a shared
project total. Each proved item has its own log.
This change does not add an Assume pragma or an Annotate
pragma.

The labels describe only the checks this repository runs. They
do not describe anyone else's proof, and they do not describe a
live model. A fingerprint, an agreement, and a passing test are
still tests.

The summary `proved 12 of 19, tested 7, unchecked 0` counts
items 1 through 19. Item 18 is proved for the label rule.
Reading the logs is not proved. Item 19 is proved for
`ai_amplifier-summary_rules`: `proof/item_19.out` is summary
22, 15 checks on that unit, unproved 0. The summaries and the
step checker are not in that run.
