--  A tiny trainable network on AI_Amplifier.Tensors.
--
--  Plain Ada (SPARK_Mode off). Nothing here is proved. The Pre on the
--  batch routines is an ordinary Ada contract, checked when the program
--  runs, the same way as the tensor kernels.
--
--  Shape, fixed so the page and the native test talk about one net:
--    2 inputs
--    8 hidden units, tanh
--    1 output, sigmoid
--  W1 is 8 by 2, b1 has 8 components, W2 is 1 by 8, b2 has 1.
--  Initialize fills the weights from one seed (Init_Seed unless the
--  caller passes another). The generator is the Numerical Recipes LCG
--    state := state * 1664525 + 1013904223   (mod 2**32)
--  and each weight is uniform on the Xavier interval
--    [-sqrt (6 / (fan_in + fan_out)), +sqrt (6 / (fan_in + fan_out))].
--  Biases start at 0. The same seed is the same net.
--
--  For one sample, with y the sigmoid output and t the label 0 or 1:
--    L = -(t ln y + (1 - t) ln (1 - y))
--  y is clipped into [1.0e-6, 1.0 - 1.0e-6] before the log, so a
--  saturated output still has a finite loss. The number Train descends
--  is the mean of L over the batch.
--
--  The gradient is hand-written, not a library autodiff. With
--  z2 the output logit and h the hidden tanh:
--    dL/dz2        = y - t
--    dL/dW2        = (y - t) * h
--    dL/db2        = y - t
--    dL/dh         = (y - t) * W2
--    dL/dz1        = dL/dh * (1 - h**2)
--    dL/dW1        = dL/dz1 * x
--    dL/db1        = dL/dz1
--  Each of those is averaged over the batch. One Step then does
--    parameter := parameter - Rate * gradient.
--  The clip is only on the logged y. Away from the clip edges, y - t
--  is the derivative of that loss. On the edges the logged loss is
--  flat and this gradient is not. The native test checks the two
--  against a central difference at the seeded start, where every
--  output sits far from the clip.
--
--  Log, square root, sine, and cosine used below are written in this
--  unit. Ada.Numerics is not linked: that runtime wants a host libm,
--  and the wasm module has no imports.
with AI_Amplifier.Tensors;

package AI_Amplifier.MLP
  with SPARK_Mode => Off
is

   pragma Assertion_Policy (Pre => Check, Post => Check);

   Inputs  : constant := 2;
   Hidden  : constant := 8;
   Outputs : constant := 1;

   --  2026-11-04, written as a number so a second build can say the
   --  same seed. Not a secret and not tuned per sample.
   Init_Seed    : constant := 2_026_1104;
   Default_Rate : constant := 0.5;

   --  Accepted rates are (0, 5]. Anything else is replaced by
   --  Default_Rate inside Initialize, and ignored by the page wrapper
   --  when it only wants to change the rate.
   Rate_Max : constant := 5.0;

   type Dataset_Kind is (XOR_Points, Two_Circles, Two_Spirals);

   type Sample is record
      X     : Tensors.Vector (Inputs);
      Label : Float;
   end record;

   --  Fixed capacity so a dataset is a constrained object. The wasm
   --  build can copy one without a secondary stack. Count is how many
   --  of Item are live, from the front.
   Max_Samples : constant := 128;

   subtype Count_Range is Natural range 0 .. Max_Samples;

   type Sample_Array is array (Positive range 1 .. Max_Samples) of Sample;

   type Sample_List is record
      Count : Count_Range := 0;
      Item  : Sample_Array;
   end record;

   type Net is record
      W1   : Tensors.Matrix (Hidden, Inputs);
      B1   : Tensors.Vector (Hidden);
      W2   : Tensors.Matrix (Outputs, Hidden);
      B2   : Tensors.Vector (Outputs);
      Rate : Float;
   end record;

   type Gradient is record
      W1 : Tensors.Matrix (Hidden, Inputs);
      B1 : Tensors.Vector (Hidden);
      W2 : Tensors.Matrix (Outputs, Hidden);
      B2 : Tensors.Vector (Outputs);
   end record;

   procedure Initialize
     (Model : out Net;
      Seed  : Natural := Init_Seed;
      Rate  : Float   := Default_Rate);

   function Predict (Model : Net; X : Tensors.Vector) return Float
     with Pre => X.Length = Inputs;

   function Mean_Loss (Model : Net; Data : Sample_List) return Float
     with Pre => Data.Count > 0;

   procedure Backprop
     (Model : Net;
      Data  : Sample_List;
      G     : out Gradient;
      Loss  : out Float)
     with Pre => Data.Count > 0;

   procedure Step (Model : in out Net; G : Gradient);

   --  Steps of Step. Loss is the mean after the last step.
   procedure Train
     (Model : in out Net;
      Data  : Sample_List;
      Steps : Positive;
      Loss  : out Float)
     with Pre => Data.Count > 0;

   function Make_Dataset (Kind : Dataset_Kind) return Sample_List;

   --  The box the page paints. Points of that dataset lie inside it.
   procedure View_Box
     (Kind : Dataset_Kind;
      Low  : out Float;
      High : out Float);

   --  A weight a text file or the page may store. Read_Weights refuses
   --  a non-finite value and a value outside [-Weight_Limit, Weight_Limit],
   --  and leaves the net unchanged. The bound is far inside the tensor
   --  Summand_Bound. It is wide enough for the hand-written XOR net and
   --  for gradient descent on the three datasets.
   Weight_Limit : constant := 1000.0;

   --  The slider on the page spans [-Slider_Span, Slider_Span]. The
   --  number field may still send any finite value inside Weight_Limit.
   Slider_Span : constant := 12.0;

   --  One labelled line per neuron, plus a header and a shape line.
   --  The writer ends every line with LF. A reader skips a blank line
   --  and a line whose first non-space character is '#'.
   --
   --    ada-ai-amplifier weights 1
   --    shape 2 8 1
   --    hidden 1 x1 <f> x2 <f> bias <f>
   --    ...
   --    hidden 8 x1 <f> x2 <f> bias <f>
   --    output 1 h1 <f> ... h8 <f> bias <f>
   --
   --  Hidden lines come in order, 1 then 2 and so on. A number is a
   --  plain decimal, with an optional exponent. At most 15 significant
   --  digits. The learning rate is not in the file.
   Max_Weight_Text : constant := 8192;

   type Weight_Chars is array (1 .. Max_Weight_Text) of Character;

   type Load_Status is (Loaded, Bad_Shape, Bad_Value, Bad_Syntax);

   --  XOR written by hand. Initialize is not called. Train is not
   --  called. The eight hidden units are tanh, and the output is a
   --  sigmoid, the same as every other net in this package.
   --
   --  Hidden 1 is OR. Its logit is 6 x1 + 6 x2 - 3, so tanh is near
   --  -1 at (0, 0) and near +1 when either input is 1.
   --  Hidden 2 is AND. The same input weights and bias -9, so tanh is
   --  near +1 only at (1, 1).
   --  The output logit is 6 h1 - 6 h2 - 6. That is "OR and not AND":
   --  high on (0, 1) and (1, 0), low on (0, 0) and (1, 1).
   --  Hidden units 3 through 8 are silent. Their input weights, their
   --  biases, and their output weights are all 0, so they do not move
   --  the decision.
   Hand_Or_Weight  : constant := 6.0;
   Hand_Or_Bias    : constant := -3.0;
   Hand_And_Weight : constant := 6.0;
   Hand_And_Bias   : constant := -9.0;
   Hand_Out_Or     : constant := 6.0;
   Hand_Out_And    : constant := -6.0;
   Hand_Out_Bias   : constant := -6.0;

   function Hand_XOR return Net;

   --  Three deliberate edits. Each one changes weights and nothing
   --  else. Flip negates hidden 1's output weight. Silence sets
   --  hidden 2's output weight to 0. Invert negates every output
   --  weight and the output bias, which swaps the two classes
   --  because sigmoid (-z) = 1 - sigmoid (z).
   type Preset_Kind is (Flip_Hidden_1, Silence_Hidden_2, Invert_Output);

   procedure Apply_Preset (Model : in out Net; Kind : Preset_Kind);

   procedure Write_Weights
     (Model : Net;
      Text  : out Weight_Chars;
      Count : out Natural);

   --  On anything other than Loaded, Model is unchanged, including
   --  its learning rate. On Loaded, the weights are replaced and the
   --  learning rate is kept.
   procedure Read_Weights
     (Model  : in out Net;
      Text   : Weight_Chars;
      Count  : Natural;
      Status : out Load_Status)
     with Pre => Count <= Max_Weight_Text;

end AI_Amplifier.MLP;
