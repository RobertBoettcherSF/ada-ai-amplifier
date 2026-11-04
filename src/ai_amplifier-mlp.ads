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

end AI_Amplifier.MLP;
