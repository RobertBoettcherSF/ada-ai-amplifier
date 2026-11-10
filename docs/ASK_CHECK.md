# Ask check

Items 9, 11, and 14 can call a chat endpoint from the native
programs. CI does not call a real model. It runs those three
commands against a stand-in on the same machine.

Visible stamp: **v0.24.0-readme**

Live page: https://robertboettchersf.github.io/ada-ai-amplifier/?v=0.24.0-readme

## What the stand-in is

`tools/standin_model.py` listens on `127.0.0.1`. It speaks the
same JSON shape the callers already parse: a `choices` array,
a `message`, and a `content` string. It does not open a
connection of its own, and it does not check a key. The
callers still require a URL, a one-line key, and a model
name, so the test sets those to a local address, the dummy
text `standin-key`, and the model name `standin`.

`tools/check-ask.sh` starts that process and runs:

| Command | Settings |
|---|---|
| `recurse_cli --ask 1` | `RECURSE_LLM_URL`, `RECURSE_LLM_KEY`, `RECURSE_LLM_MODEL` |
| `traces_cli --ask 1` | `TRACES_LLM_URL`, `TRACES_LLM_KEY`, `TRACES_LLM_MODEL` |
| `harness_cli --ask rate-diverges` | `HARNESS_LLM_URL`, `HARNESS_LLM_KEY`, `HARNESS_LLM_MODEL` |

Each run uses curl. GNAT's `Spawn` does not search `PATH`, so
the three programs resolve the name `curl` to a full path
before they start it. A path that already contains a slash,
which is what the older tests pass in `*_LLM_CURL`, is left
alone.

The good replies are fixed text. For Fibonacci index 1 the
content is the base-case blob, and the program stops at
`reached-base` with answer 1. For the first wrong-turn trace
the content is `rate-1-train-200`, and the verdict is
`fixes-it`. The harness task `rate-diverges` is that same
repair, and the checked harness prints `solved`.

## The three failures

Each command is also given a reply that should not be
accepted.

| Mode | What comes back | What the program has to say |
|---|---|---|
| wrong | A well-formed reply the checker rejects | `bad-arithmetic`, a verdict other than `fixes-it`, or `not solved` |
| broken | A JSON body with no assistant content string | `bad-parse`, `not-a-step`, or `not solved` |
| timeout | The handler records the request and then waits | `the request failed`, and curl's 30 second limit |

`bin/ask_test` reads the recorded requests and the program
output. A request counts only when it is `POST`, the path is
the one that was set, the header is `Authorization: Bearer
standin-key`, the type is JSON, and the body names the model
`standin`, temperature 0, and a user message that contains
the prompt. The key must not appear in the body. The test
prints `ask-standin ok cases 36`.

## What is proved

`AI_Amplifier.Ask_Rule` classifies one exchange. No call is a
timeout. A body that does not yield the assistant text is a
broken format. A parsed reply the checker rejects is a wrong
answer. Only the remaining case is accepted. `Standin_Covers`
is true only when all four of those outcomes were seen.
`Real_Model_Checked` is false. `proof/ask_rule.out` is that
run: summary 8, flow 4, provers 4, unproved 0, with 4 prover
checks on `ai_amplifier-ask_rule`. The request text and the
reply scan stay in `AI_Amplifier.Recurse` and
`AI_Amplifier.Traces`. Those units are plain Ada. This check
does not prove them, and it does not prove that a real model
would send the same bytes.

The proved label on items 9 and 11 is still the step rule and
the verdict rule. Item 14 stays tested. A stand-in log does
not satisfy the proved rule. Removing `proof/item_09.out`
drops that proved label even when `ask-standin ok` is present.
Removing the `ask-standin ok` line puts `live-ask unchecked`
back, and the summary stays proved 12 of 19, tested 7,
unchecked 0.
