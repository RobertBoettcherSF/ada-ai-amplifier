# Contributing

The tensor kernels are SPARK. The rest of the logic is plain Ada.
JavaScript only draws, and writes the feedback and crash files.
`docs/HOWTO.md` is the install path and the map of `src/`. This file
is the house rules for a change.

They follow the owner's How-To: a visible stamp, plan then Go, one
item, honesty, a pre-push list, and F9. This project publishes with
GitHub Pages from `main`, not with a secret gist.

## One item

1. Post a numbered plan for one backlog item.
2. Wait for Go.
3. Build that item.
4. Report what landed, what the checks did, and what is still open.
5. Stop. Do not start the next item in the same change.

Items 1 through 7 are done. Item 7 is the SPARK proof of the tensor
kernels. CI runs `./prove.sh` (GNATprove level 2). If a change touches
a proved unit, `./prove.sh` must still pass and `proof/gnatprove.out`
is part of that change. Do not regenerate it as a side effect of a
change that does not touch a proved unit. There is no `pragma Annotate`
and no `pragma Assume`.

## Visible stamp

The yellow badge is on every screen, including when JavaScript is off.
It is `position: fixed` at the bottom right, and it is omitted when
printing.

These four are the same text:

| Place | Text |
|---|---|
| `AI_Amplifier.Version.Version_Text` | `v0.7.0-spark` on this tree |
| `web/template.html`, the `#ver` badge | the same, so it shows with JavaScript off |
| `version.txt` | the same, one line |
| `alire.toml` `version` | the same without the leading `v` |

`./tools/check-version.sh` compares the first three against `bin/hello`.

Bump the stamp when the page, or the Ada a visitor runs, would differ.
Do not reuse a stamp. Pages deploys from `main` only, so the bump lands
with the change that deploys. The link you send is

`https://robertboettchersf.github.io/ada-ai-amplifier/?v=0.7.0-spark`

with `?v=` set to the stamp without the leading `v`. Before you say
that stamp is live, fetch the page and `version.txt` and see the text
in both. A screenshot of the new page shows the new badge. If a browser
keeps the previous file, the new query is the refresh.

## Honesty

Say what is checked when the program runs, and what a prover has not
seen.

- `Pre` and `Post` on the kernels are ordinary Ada contracts. `-gnata`
  and `Assertion_Policy` check them when the program runs. On
  `AI_Amplifier.Tensors` they are also proved, at the level in the
  proof status table (Silver or Gold). The splash, the MLP, the
  tokenizer, and attention are not proved.
- Silver is absence of run-time error. Gold is the component rule.
  Sigmoid, tanh, and softmax are Silver: the result lies in range.
  The series is not the real function.
- The WebAssembly module has no imports. A failed check traps it. The
  native tests are where a bad shape or a bad slope raises.
- `Float` results are approximate. Name the tolerance the test uses.
- The splash is a drawing. The attention weights are a seed. Eight
  hidden units do not solve the spirals.
- JavaScript copies numbers and paints. Where it adds up values it
  already read (the attention sentence under the heatmap), say so, as
  the README does.

## Pre-push

1. **Was it already there?** Splash, tensor demo, leaky ReLU, training,
   tokens and attention, F9, the crash report, the badge, the How-To
   link.
2. **Is it still there?** `node tools/page-smoke.mjs` walks those, on a
   desktop viewport and a phone-sized viewport.
3. **Does the new behaviour work?** Native tests (`tensors ok`,
   `mlp ok`, `attention ok`), then `./build.sh` (the wasm smoke), then
   the page smoke. `./tools/howto-steps.sh` is that path in one file,
   after Alire, Node 22, Chrome, and `./tools/howto-packages.sh`.
4. **Does the stamp match?** `./tools/check-version.sh`.
5. **Do the docs name the numbers the code uses?** The How-To quotes
   `tools/howto-packages.sh` and `tools/howto-steps.sh`.
   `python3 tools/check-howto-quote.py` fails if a quote drifts.
6. **If a proved unit changed,** `./prove.sh` passes and
   `proof/gnatprove.out` matches that run. No `pragma Annotate`. No
   `pragma Assume`.

## F9

Feedback, or the Feedback button, asks for a short note and writes
`feedback-*.json`. An empty note is refused. The file carries:

- `appVersion`, the badge
- the browser, the language, the screen, whether the page is standalone
- `phase` (`splash` or `main`), frames per second, the Ada splash step
- the MLP epoch and loss when the module is loaded
- the recent UI events (a ring of 200) and how many were dropped
- the note

On a phone that can share files, the page offers the share sheet.
Otherwise it downloads. A crash report (`crash-report-*.json`) is the
other file: the previous visit did not end cleanly, or the module
trapped. Read `appVersion` first. The note is about that build.

When a report arrives, treat it as a description of what happened.
The useful reply is a fix or a question, not a lecture.

## Reviews

A pull request says which item it is, which stamp it uses, and what is
not proved. CI is green before merge. The owner merges.
