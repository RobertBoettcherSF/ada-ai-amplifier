# Weight-space programming

The idea, and what this repository actually shows.

Visible stamp: **v0.24.0-readme**

Live page: https://robertboettchersf.github.io/ada-ai-amplifier/?v=0.24.0-readme

## The idea

[Sparks of Weight-Space Programming](https://rikiyat.github.io/blog/weight-space-programming/)
(Takehi, Teoh, Zhang, Khattab, 2 November 2026) reports that a frontier
language model can read a network's weights as text and write new
weights as text. No gradient step. In the post, the model names which
game a policy was trained on, patches a stuck controller, and writes
small game-playing networks from scratch.

That is a claim about a language model. This repository does not
repeat the experiments, and it does not claim the same results. There
is no language model here. Nothing on the page was written by one.
The numbers below are the 2–8–1 network this project already trains.

What the page does show is the part a person can check by hand: the
weights are a readable text file, a person can type a network that
solves XOR without training, and a small edit to one weight moves the
decision boundary.

## The text

`AI_Amplifier.MLP.Write_Weights` writes the current net. One labelled
line per neuron, plus a header and a shape line:

```text
ada-ai-amplifier weights 1
shape 2 8 1
hidden 1 x1 6.00000000 x2 6.00000000 bias -3.00000000
hidden 2 x1 6.00000000 x2 6.00000000 bias -9.00000000
...
output 1 h1 6.00000000 h2 -6.00000000 h3 0.00000000 h4 0.00000000 h5 0.00000000 h6 0.00000000 h7 0.00000000 h8 0.00000000 bias -6.00000000
```

`Read_Weights` checks that text before it touches the net.

| Check | Result | What stays |
|---|---|---|
| Header, labels, and the neuron order | `Bad_Syntax` | the previous weights |
| `shape` is not `2 8 1`, or a neuron index is not the next one | `Bad_Shape` | the previous weights |
| A value is not finite, or its absolute value is above `1000` | `Bad_Value` | the previous weights |

`1000` is `Weight_Limit`. It is far inside the tensor `Summand_Bound`.
A blank line is skipped. A line whose first non-space character is
`#` is a comment and is skipped. The learning rate is not in the file,
and a successful load keeps the rate that was already set. A number
may be a plain decimal or use an exponent, with at most 15 significant
digits. The writer uses eight digits after the decimal.

The page does not parse this text. It pushes bytes into Ada and reads
bytes back. `bin/mlp_test` checks the round trip, a bad shape, a value
past the limit, a comment, and a truncated file.

## The hand-written XOR net

`Hand_XOR` sets the weights in source. `Initialize` is not called.
`Train` is not called. The units are the same tanh hidden layer and
sigmoid output as the trained net. Hidden units 3 through 8 are
present so the shape matches, and every weight on them is 0.

| Unit | Weights | What it computes |
|---|---|---|
| Hidden 1 | `6 x1 + 6 x2 - 3` | OR. Near −1 at (0, 0), near +1 if either input is 1 |
| Hidden 2 | `6 x1 + 6 x2 - 9` | AND. Near +1 only at (1, 1) |
| Output | `6 h1 - 6 h2 - 6` | OR and not AND, then a sigmoid |

On the four XOR points the sigmoid outputs sit past 0.8 for class 1
and under 0.2 for class 0. The mean loss is under 0.05. That is the
same bar the trained net has to clear, reached here with no steps.
`bin/mlp_test` checks all four inputs, and it checks that units 3
through 8 are silent.

## Three edits

Each edit changes weights and then stops. There is no training step
inside them. On the hand-written net the effect is easy to see. On a
trained net the same edit still runs; the boundary moves by whatever
that one change does to those particular weights.

| Button | What Ada changes | On the hand-written XOR net |
|---|---|---|
| Flip hidden 1 | Negate hidden 1's output weight | (0, 0) goes high and the two single-1 corners go low |
| Silence hidden 2 | Set hidden 2's output weight to 0 | The AND gate stops voting. (1, 1) rises to about 0.5, and the single-1 corners are no longer sure |
| Invert output | Negate every output weight and the output bias | The two classes trade places, because sigmoid(−z) = 1 − sigmoid(z) |

If the weight being flipped or silenced is already 0, Ada says so and
the boundary does not move. The sentence under the buttons is that
note. It is written in Ada. The page copies it.

The workbench also has a slider and a number for every weight. Ada
stores a finite value inside ±1000 and recomputes the loss and the
48 by 48 grid. A value outside that is refused, and the previous
weight stays. The slider spans ±12, which is `Slider_Span`. A number
inside the limit but outside the slider is still stored; the slider
sits at the end of its track.

Reset to trained copies back the weights from the last training step
on the current dataset. If no step has run since the dataset was
chosen, that copy is the seeded start, and the note says so. The
Reset button above the plot is different: it always rebuilds the seed.

## What this is not

- Not a reproduction of the post. No game policies, no diffusion
  model, no language-model weights, and no measured scores from that
  page.
- Not a language model reading or writing these weights. The
  hand-written net and the three edits are ordinary Ada in
  `AI_Amplifier.MLP`.
- Not a proof. `AI_Amplifier.MLP` and `AI_Amplifier.MLP.Demo` stay
  `SPARK_Mode => Off`. The speed harness is the same. The checks above run when the program runs.
  A failed check in the WebAssembly module traps that module. The
  native test is where a bad file returns a status instead.
- Not a change to the tensor proofs. Item 7 is untouched.
