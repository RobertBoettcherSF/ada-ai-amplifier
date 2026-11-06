## Item

Which backlog item this is. One item.

## Stamp

`v…` in the badge, `version.txt`, and `AI_Amplifier.Version.Version_Text`.
Alire's version is that text without the leading `v`.

## What a visitor can do now

## Honesty

What is checked when the program runs, and what is not proved.
CI runs GNATprove at level 2 on the SPARK units. Say if this change
touches a proved kernel, and which level that kernel is.

## Pre-push

- [ ] Previous behaviour is still there (splash, tensor demo, leaky ReLU, training, tokens, F9, crash report, badge, How-To link)
- [ ] `./bin/tensors_test`, `./bin/mlp_test`, `./bin/attention_test`, and `./bin/recurse_test` print `ok`
- [ ] `./build.sh` and `node tools/page-smoke.mjs` pass
- [ ] `./tools/check-version.sh` passes
- [ ] `python3 tools/check-howto-quote.py` passes if the guide or its scripts changed
- [ ] Docs that name a number name the number the code uses

## Live page

After merge, the Pages URL with `?v=` set to this stamp. Leave this
blank on the pull request; fill it when you confirm the deploy.
