package body AI_Amplifier.MLP
  with SPARK_Mode => Off
is

   pragma Assertion_Policy (Pre => Check, Post => Check);

   package T renames AI_Amplifier.Tensors;

   Pi     : constant Float := 3.141_592_74;
   Ln2    : constant Float := 0.693_147_2;
   Clip_Lo : constant Float := 1.0e-6;

   type Word is mod 2 ** 32;

   function Sqrt_Of (X : Float) return Float is
      G : Float;
   begin
      if X <= 0.0 then
         return 0.0;
      end if;
      G := X;
      for K in 1 .. 10 loop
         G := 0.5 * (G + X / G);
      end loop;
      return G;
   end Sqrt_Of;

   --  ln(X) for X > 0. A non-positive argument returns ln of the clip,
   --  which is as far as the loss is allowed to look.
   function Log_Clamped (X : Float) return Float is
      Y    : Float;
      U    : Float;
      U2   : Float;
      Term : Float;
      Sum  : Float;
      E    : Integer := 0;
   begin
      if X <= Clip_Lo then
         Y := Clip_Lo;
      elsif X > 1.0e6 then
         Y := 1.0e6;
      else
         Y := X;
      end if;

      while Y >= 2.0 and then E < 40 loop
         Y := Y * 0.5;
         E := E + 1;
      end loop;
      while Y < 1.0 and then E > -40 loop
         Y := Y * 2.0;
         E := E - 1;
      end loop;

      --  Y is in [1, 2). u = (Y-1)/(Y+1) is in [0, 1/3].
      U := (Y - 1.0) / (Y + 1.0);
      U2 := U * U;
      Term := U;
      Sum := U;
      for K in 1 .. 8 loop
         Term := Term * U2;
         Sum := Sum + Term / Float (2 * K + 1);
      end loop;
      return 2.0 * Sum + Float (E) * Ln2;
   end Log_Clamped;

   function Clip_Unit (P : Float) return Float is
   begin
      if P < Clip_Lo then
         return Clip_Lo;
      elsif P > 1.0 - Clip_Lo then
         return 1.0 - Clip_Lo;
      else
         return P;
      end if;
   end Clip_Unit;

   function Cross_Entropy (Y, Target : Float) return Float is
      P : constant Float := Clip_Unit (Y);
      A : Float;
      B : Float;
   begin
      A := Target * Log_Clamped (P);
      B := (1.0 - Target) * Log_Clamped (1.0 - P);
      return -(A + B);
   end Cross_Entropy;

   function Sin_Series (X : Float) return Float is
      X2   : constant Float := X * X;
      Term : Float := X;
      Sum  : Float := X;
   begin
      for K in 1 .. 7 loop
         Term := -Term * X2 / Float ((2 * K) * (2 * K + 1));
         Sum := Sum + Term;
      end loop;
      return Sum;
   end Sin_Series;

   function Cos_Series (X : Float) return Float is
      X2   : constant Float := X * X;
      Term : Float := 1.0;
      Sum  : Float := 1.0;
   begin
      for K in 1 .. 7 loop
         Term := -Term * X2 / Float ((2 * K - 1) * (2 * K));
         Sum := Sum + Term;
      end loop;
      return Sum;
   end Cos_Series;

   --  Angle is folded into [-pi/2, pi/2] and the series is evaluated
   --  there. Dataset angles stay within a few turns, so the fold is
   --  short. The guard stops a non-finite angle from spinning.
   procedure Sin_Cos
     (Angle         : Float;
      Sine, Cosine  : out Float)
   is
      A      : Float := Angle;
      Turn   : constant Float := 2.0 * Pi;
      Half   : constant Float := Pi / 2.0;
      Sign_C : Float := 1.0;
      Guard  : Integer := 0;
   begin
      while A > Pi and then Guard < 16 loop
         A := A - Turn;
         Guard := Guard + 1;
      end loop;
      Guard := 0;
      while A < -Pi and then Guard < 16 loop
         A := A + Turn;
         Guard := Guard + 1;
      end loop;

      if A > Half then
         A := Pi - A;
         Sign_C := -1.0;
      elsif A < -Half then
         A := -Pi - A;
         Sign_C := -1.0;
      end if;

      Sine := Sin_Series (A);
      Cosine := Sign_C * Cos_Series (A);
   end Sin_Cos;

   function Next_Unit (State : in out Word) return Float is
   begin
      State := State * 1664525 + 1013904223;
      --  Top 24 bits, so the result is in [0, 1) and exact in Float.
      return Float (State / 256) / 16_777_216.0;
   end Next_Unit;

   function Zero_Sample return Sample is
     (X => (Length => Inputs, Data => (0.0, 0.0)), Label => 0.0);

   function At_Point (Xin, Yin, Wanted : Float) return Sample is
     (X => (Length => Inputs, Data => (Xin, Yin)), Label => Wanted);

   type Pass is record
      H : T.Vector (Hidden);
      Y : Float;
   end record;

   function Forward (Model : Net; X : T.Vector) return Pass is
      Z1 : constant T.Vector :=
        T.Add (T.Mat_Vec (Model.W1, X), Model.B1);
      H  : constant T.Vector := T.Tanh (Z1);
      Z2 : constant T.Vector :=
        T.Add (T.Mat_Vec (Model.W2, H), Model.B2);
      Y  : constant T.Vector := T.Sigmoid (Z2);
   begin
      return (H => H, Y => Y.Data (1));
   end Forward;

   function Accept_Rate (Rate : Float) return Float is
   begin
      if Rate > 0.0 and then Rate <= Rate_Max then
         return Rate;
      else
         return Default_Rate;
      end if;
   end Accept_Rate;

   procedure Initialize
     (Model : out Net;
      Seed  : Natural := Init_Seed;
      Rate  : Float   := Default_Rate)
   is
      State : Word := Word (Seed);
      Lim1  : constant Float :=
        Sqrt_Of (6.0 / Float (Inputs + Hidden));
      Lim2  : constant Float :=
        Sqrt_Of (6.0 / Float (Hidden + Outputs));
      Draw  : Float;
   begin
      Model.W1 :=
        (Rows => Hidden,
         Cols => Inputs,
         Data => (others => (others => 0.0)));
      Model.B1 := (Length => Hidden, Data => (others => 0.0));
      Model.W2 :=
        (Rows => Outputs,
         Cols => Hidden,
         Data => (others => (others => 0.0)));
      Model.B2 := (Length => Outputs, Data => (others => 0.0));

      for R in 1 .. Hidden loop
         for C in 1 .. Inputs loop
            Draw := Next_Unit (State) * 2.0 - 1.0;
            Model.W1.Data (R, C) := Draw * Lim1;
         end loop;
      end loop;
      for C in 1 .. Hidden loop
         Draw := Next_Unit (State) * 2.0 - 1.0;
         Model.W2.Data (1, C) := Draw * Lim2;
      end loop;
      Model.Rate := Accept_Rate (Rate);
   end Initialize;

   function Predict (Model : Net; X : T.Vector) return Float is
     (Forward (Model, X).Y);

   function Sample_Loss (Model : Net; Point : Sample) return Float is
     (Cross_Entropy (Forward (Model, Point.X).Y, Point.Label));

   function Mean_Loss (Model : Net; Data : Sample_List) return Float is
      Sum : Float := 0.0;
   begin
      for I in 1 .. Data.Count loop
         Sum := Sum + Sample_Loss (Model, Data.Item (I));
      end loop;
      return Sum / Float (Data.Count);
   end Mean_Loss;

   function Zero_Gradient return Gradient is
     (W1 =>
        (Rows => Hidden,
         Cols => Inputs,
         Data => (others => (others => 0.0))),
      B1 => (Length => Hidden, Data => (others => 0.0)),
      W2 =>
        (Rows => Outputs,
         Cols => Hidden,
         Data => (others => (others => 0.0))),
      B2 => (Length => Outputs, Data => (others => 0.0)));

   procedure Backprop
     (Model : Net;
      Data  : Sample_List;
      G     : out Gradient;
      Loss  : out Float)
   is
      Sum : Float := 0.0;
   begin
      G := Zero_Gradient;
      for I in 1 .. Data.Count loop
         declare
            Point : Sample renames Data.Item (I);
            Seen  : constant Pass := Forward (Model, Point.X);
            D2    : constant Float := Seen.Y - Point.Label;
            DZ    : Float;
         begin
            Sum := Sum + Cross_Entropy (Seen.Y, Point.Label);
            G.B2.Data (1) := G.B2.Data (1) + D2;
            for U in 1 .. Hidden loop
               G.W2.Data (1, U) :=
                 G.W2.Data (1, U) + D2 * Seen.H.Data (U);
               DZ := D2 * Model.W2.Data (1, U)
                 * (1.0 - Seen.H.Data (U) * Seen.H.Data (U));
               G.B1.Data (U) := G.B1.Data (U) + DZ;
               for C in 1 .. Inputs loop
                  G.W1.Data (U, C) :=
                    G.W1.Data (U, C) + DZ * Point.X.Data (C);
               end loop;
            end loop;
         end;
      end loop;

      declare
         Inv : constant Float := 1.0 / Float (Data.Count);
      begin
         Loss := Sum * Inv;
         G.W1 := T.Scale (G.W1, Inv);
         G.B1 := T.Scale (G.B1, Inv);
         G.W2 := T.Scale (G.W2, Inv);
         G.B2 := T.Scale (G.B2, Inv);
      end;
   end Backprop;

   procedure Step (Model : in out Net; G : Gradient) is
      Shift : constant Float := -Model.Rate;
   begin
      Model.W1 := T.Add (Model.W1, T.Scale (G.W1, Shift));
      Model.B1 := T.Add (Model.B1, T.Scale (G.B1, Shift));
      Model.W2 := T.Add (Model.W2, T.Scale (G.W2, Shift));
      Model.B2 := T.Add (Model.B2, T.Scale (G.B2, Shift));
   end Step;

   procedure Train
     (Model : in out Net;
      Data  : Sample_List;
      Steps : Positive;
      Loss  : out Float)
   is
      G : Gradient;
      Unused : Float;
   begin
      for I in 1 .. Steps loop
         Backprop (Model, Data, G, Unused);
         Step (Model, G);
      end loop;
      --  After the step, so the number is the loss the next gradient
      --  would see. Backprop's own Loss is the value before the step.
      Loss := Mean_Loss (Model, Data);
   end Train;

   procedure Put
     (Data         : in out Sample_List;
      X, Y, Label  : Float)
   is
   begin
      if Data.Count < Max_Samples then
         Data.Count := Data.Count + 1;
         Data.Item (Data.Count) := At_Point (X, Y, Label);
      end if;
   end Put;

   function Make_XOR return Sample_List is
      Data : Sample_List;
   begin
      Data.Item := (others => Zero_Sample);
      --  The four corners of the unit square. Classic XOR.
      Put (Data, 0.0, 0.0, 0.0);
      Put (Data, 0.0, 1.0, 1.0);
      Put (Data, 1.0, 0.0, 1.0);
      Put (Data, 1.0, 1.0, 0.0);
      return Data;
   end Make_XOR;

   --  Two concentric circles, 36 points each, no jitter.
   --  Inner radius 0.45 is class 0. Outer radius 1.05 is class 1.
   function Make_Circles return Sample_List is
      Per   : constant := 36;
      Data  : Sample_List;
      Angle : Float;
      Sine  : Float;
      Cosine : Float;
   begin
      Data.Item := (others => Zero_Sample);
      for I in 1 .. Per loop
         Angle := 2.0 * Pi * Float (I - 1) / Float (Per);
         Sin_Cos (Angle, Sine, Cosine);
         Put (Data, 0.45 * Cosine, 0.45 * Sine, 0.0);
         Put (Data, 1.05 * Cosine, 1.05 * Sine, 1.0);
      end loop;
      return Data;
   end Make_Circles;

   --  Two spirals, one and a half turns, 48 points on each arm.
   --  Radius runs from 0.12 to 1.17. The second arm is half a turn
   --  ahead, so it sits opposite the first at the same radius.
   function Make_Spirals return Sample_List is
      Per    : constant := 48;
      Data   : Sample_List;
      T      : Float;
      Radius : Float;
      Angle  : Float;
      Sine   : Float;
      Cosine : Float;
   begin
      Data.Item := (others => Zero_Sample);
      for I in 1 .. Per loop
         T := Float (I - 1) / Float (Per - 1);
         Radius := 0.12 + 1.05 * T;
         Angle := T * 3.0 * Pi;
         Sin_Cos (Angle, Sine, Cosine);
         Put (Data, Radius * Cosine, Radius * Sine, 0.0);
         Sin_Cos (Angle + Pi, Sine, Cosine);
         Put (Data, Radius * Cosine, Radius * Sine, 1.0);
      end loop;
      return Data;
   end Make_Spirals;

   function Make_Dataset (Kind : Dataset_Kind) return Sample_List is
   begin
      case Kind is
         when XOR_Points =>
            return Make_XOR;
         when Two_Circles =>
            return Make_Circles;
         when Two_Spirals =>
            return Make_Spirals;
      end case;
   end Make_Dataset;

   procedure View_Box
     (Kind : Dataset_Kind;
      Low  : out Float;
      High : out Float)
   is
   begin
      case Kind is
         when XOR_Points =>
            Low := -0.35;
            High := 1.35;
         when Two_Circles | Two_Spirals =>
            Low := -1.35;
            High := 1.35;
      end case;
   end View_Box;

end AI_Amplifier.MLP;
