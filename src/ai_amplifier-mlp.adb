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

   function Hand_XOR return Net is
      Model : Net;
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

      --  Hidden 1: OR. Fires when either input is 1.
      Model.W1.Data (1, 1) := Hand_Or_Weight;
      Model.W1.Data (1, 2) := Hand_Or_Weight;
      Model.B1.Data (1) := Hand_Or_Bias;

      --  Hidden 2: AND. Fires only when both inputs are 1.
      Model.W1.Data (2, 1) := Hand_And_Weight;
      Model.W1.Data (2, 2) := Hand_And_Weight;
      Model.B1.Data (2) := Hand_And_Bias;

      --  Hidden 3 .. 8 stay 0. They are present so the shape matches
      --  the trained net, and they do not vote.

      --  Output: OR and not AND.
      Model.W2.Data (1, 1) := Hand_Out_Or;
      Model.W2.Data (1, 2) := Hand_Out_And;
      Model.B2.Data (1) := Hand_Out_Bias;
      Model.Rate := Default_Rate;
      return Model;
   end Hand_XOR;

   procedure Apply_Preset (Model : in out Net; Kind : Preset_Kind) is
   begin
      case Kind is
         when Flip_Hidden_1 =>
            Model.W2.Data (1, 1) := -Model.W2.Data (1, 1);
         when Silence_Hidden_2 =>
            Model.W2.Data (1, 2) := 0.0;
         when Invert_Output =>
            for C in 1 .. Hidden loop
               Model.W2.Data (1, C) := -Model.W2.Data (1, C);
            end loop;
            Model.B2.Data (1) := -Model.B2.Data (1);
      end case;
   end Apply_Preset;

   procedure Write_Weights
     (Model : Net;
      Text  : out Weight_Chars;
      Count : out Natural)
   is
      Len : Natural := 0;

      procedure Add (C : Character) is
      begin
         if Len < Max_Weight_Text then
            Len := Len + 1;
            Text (Len) := C;
         end if;
      end Add;

      procedure Add (S : String) is
      begin
         for C of S loop
            Add (C);
         end loop;
      end Add;

      procedure Add_Digit (N : Integer) is
      begin
         Add (Character'Val (Character'Pos ('0') + N));
      end Add_Digit;

      --  Eight digits after the decimal. Enough that a value inside
      --  Weight_Limit round-trips well inside the test tolerance.
      procedure Add_Fixed (X : Float) is
         Neg    : constant Boolean := X < 0.0;
         A      : Long_Float;
         Scaled : Long_Long_Integer;
         Whole  : Long_Long_Integer;
         Frac   : Long_Long_Integer;
         W      : Long_Long_Integer;
         Digs   : array (1 .. 16) of Integer := (others => 0);
         N      : Natural := 0;
         Pow    : Long_Long_Integer;
         Dig    : Integer;
      begin
         if Neg then
            A := Long_Float (-X);
         else
            A := Long_Float (X);
         end if;
         if A >= 1.0E9 then
            Add ("1000000000.00000000");
            return;
         end if;
         Scaled := Long_Long_Integer (A * 100_000_000.0 + 0.5);
         Whole := Scaled / 100_000_000;
         Frac := Scaled mod 100_000_000;
         if Neg and then Scaled /= 0 then
            Add ('-');
         end if;
         W := Whole;
         if W = 0 then
            Add ('0');
         else
            while W > 0 and then N < Digs'Last loop
               N := N + 1;
               Digs (N) := Integer (W mod 10);
               W := W / 10;
            end loop;
            for I in reverse 1 .. N loop
               Add (Character'Val (Character'Pos ('0') + Digs (I)));
            end loop;
         end if;
         Add ('.');
         Pow := 10_000_000;
         for I in 1 .. 8 loop
            Dig := Integer (Frac / Pow);
            Add (Character'Val (Character'Pos ('0') + Dig));
            Frac := Frac mod Pow;
            Pow := Pow / 10;
         end loop;
      end Add_Fixed;

   begin
      Text := (others => ' ');
      Add ("ada-ai-amplifier weights 1");
      Add (Character'Val (10));
      Add ("shape ");
      Add_Digit (Inputs);
      Add (' ');
      Add_Digit (Hidden);
      Add (' ');
      Add_Digit (Outputs);
      Add (Character'Val (10));
      for R in 1 .. Hidden loop
         Add ("hidden ");
         Add_Digit (R);
         Add (" x1 ");
         Add_Fixed (Model.W1.Data (R, 1));
         Add (" x2 ");
         Add_Fixed (Model.W1.Data (R, 2));
         Add (" bias ");
         Add_Fixed (Model.B1.Data (R));
         Add (Character'Val (10));
      end loop;
      Add ("output ");
      Add_Digit (Outputs);
      for C in 1 .. Hidden loop
         Add (" h");
         Add_Digit (C);
         Add (' ');
         Add_Fixed (Model.W2.Data (1, C));
      end loop;
      Add (" bias ");
      Add_Fixed (Model.B2.Data (1));
      Add (Character'Val (10));
      Count := Len;
   end Write_Weights;

   procedure Read_Weights
     (Model  : in out Net;
      Text   : Weight_Chars;
      Count  : Natural;
      Status : out Load_Status)
   is
      type Number_Kind is (Ok, Syntax, Out_Of_Range);

      Draft : Net;
      From  : Natural := 1;
      Step  : Natural := 0;

      procedure Fail (Which : Load_Status) is
      begin
         Status := Which;
         Step := 99;
      end Fail;

      procedure Parse_Number
        (Slice : String;
         Value : out Float;
         Kind  : out Number_Kind)
      is
         I        : Natural := Slice'First;
         Sign     : Long_Float := 1.0;
         Mant     : Long_Float := 0.0;
         Scale    : Integer := 0;
         Figures  : Natural := 0;
         Saw      : Boolean := False;
         Seen_Dot : Boolean := False;
         Exp_Sign : Integer := 1;
         Exp      : Integer := 0;
         Exp_Saw  : Boolean := False;
         D        : Integer;
         Result   : Long_Float;
      begin
         Value := 0.0;
         Kind := Syntax;
         if I > Slice'Last then
            return;
         end if;
         if Slice (I) = '+' or else Slice (I) = '-' then
            if Slice (I) = '-' then
               Sign := -1.0;
            end if;
            I := I + 1;
         end if;
         while I <= Slice'Last
           and then Slice (I) in '0' .. '9'
         loop
            Saw := True;
            D := Character'Pos (Slice (I)) - Character'Pos ('0');
            if Figures = 15 then
               return;
            end if;
            Mant := Mant * 10.0 + Long_Float (D);
            Figures := Figures + 1;
            if Seen_Dot then
               Scale := Scale - 1;
            end if;
            I := I + 1;
         end loop;
         if I <= Slice'Last and then Slice (I) = '.' then
            if Seen_Dot then
               return;
            end if;
            Seen_Dot := True;
            I := I + 1;
            while I <= Slice'Last
              and then Slice (I) in '0' .. '9'
            loop
               Saw := True;
               D := Character'Pos (Slice (I)) - Character'Pos ('0');
               if Figures = 15 then
                  return;
               end if;
               Mant := Mant * 10.0 + Long_Float (D);
               Figures := Figures + 1;
               Scale := Scale - 1;
               I := I + 1;
            end loop;
         end if;
         if not Saw then
            return;
         end if;
         if I <= Slice'Last
           and then (Slice (I) = 'e' or else Slice (I) = 'E')
         then
            I := I + 1;
            if I <= Slice'Last
              and then (Slice (I) = '+' or else Slice (I) = '-')
            then
               if Slice (I) = '-' then
                  Exp_Sign := -1;
               end if;
               I := I + 1;
            end if;
            if I > Slice'Last or else Slice (I) not in '0' .. '9' then
               return;
            end if;
            while I <= Slice'Last
              and then Slice (I) in '0' .. '9'
            loop
               Exp_Saw := True;
               D := Character'Pos (Slice (I)) - Character'Pos ('0');
               if Exp < 1000 then
                  Exp := Exp * 10 + D;
               end if;
               I := I + 1;
            end loop;
            if not Exp_Saw then
               return;
            end if;
            Scale := Scale + Exp_Sign * Exp;
         end if;
         if I <= Slice'Last then
            return;
         end if;

         Result := Sign * Mant;
         if Scale > 24 then
            if Mant /= 0.0 then
               Kind := Out_Of_Range;
               return;
            end if;
         elsif Scale < -40 then
            Result := 0.0;
         elsif Scale > 0 then
            for K in 1 .. Scale loop
               if abs Result > 1.0E6 then
                  Kind := Out_Of_Range;
                  return;
               end if;
               Result := Result * 10.0;
            end loop;
         elsif Scale < 0 then
            for K in 1 .. -Scale loop
               Result := Result / 10.0;
            end loop;
         end if;

         if Result /= Result
           or else Result > Long_Float (Weight_Limit)
           or else Result < -Long_Float (Weight_Limit)
         then
            Kind := Out_Of_Range;
            return;
         end if;
         Value := Float (Result);
         if Value /= Value or else abs Value > Weight_Limit then
            Kind := Out_Of_Range;
            return;
         end if;
         Kind := Ok;
      end Parse_Number;

      procedure Take_Line
        (Line     : out String;
         Last     : out Natural;
         Too_Long : out Boolean;
         Got      : out Boolean)
      is
         N : Natural := 0;
      begin
         Last := 0;
         Too_Long := False;
         Got := False;
         Line := (others => ' ');
         if From > Count then
            return;
         end if;
         Got := True;
         while From <= Count and then Text (From) /= Character'Val (10) loop
            if Text (From) /= Character'Val (13) then
               if N >= Line'Last then
                  Too_Long := True;
               else
                  N := N + 1;
                  Line (N) := Text (From);
               end if;
            end if;
            From := From + 1;
         end loop;
         if From <= Count and then Text (From) = Character'Val (10) then
            From := From + 1;
         end if;
         Last := N;
      end Take_Line;

      function Blank (Line : String; Last : Natural) return Boolean is
      begin
         for I in 1 .. Last loop
            if Line (I) /= ' ' then
               return False;
            end if;
         end loop;
         return True;
      end Blank;

      function Comment (Line : String; Last : Natural) return Boolean is
      begin
         for I in 1 .. Last loop
            if Line (I) /= ' ' then
               return Line (I) = '#';
            end if;
         end loop;
         return False;
      end Comment;

      procedure Next_Token
        (Line  : String;
         Last  : Natural;
         Pos    : in out Natural;
         First : out Natural;
         Stop  : out Natural;
         Found : out Boolean)
      is
      begin
         Found := False;
         First := 1;
         Stop := 0;
         while Pos <= Last and then Line (Pos) = ' ' loop
            Pos := Pos + 1;
         end loop;
         if Pos > Last then
            return;
         end if;
         First := Pos;
         while Pos <= Last and then Line (Pos) /= ' ' loop
            Pos := Pos + 1;
         end loop;
         Stop := Pos - 1;
         Found := True;
      end Next_Token;

      function Same
        (Line : String; First, Stop : Natural; Want : String)
         return Boolean
      is
      begin
         if Want'Length /= Stop - First + 1 then
            return False;
         end if;
         for I in Want'Range loop
            if Line (First + (I - Want'First)) /= Want (I) then
               return False;
            end if;
         end loop;
         return True;
      end Same;

      function Is_Index
        (Line : String; First, Stop : Natural; N : Integer)
         return Boolean
      is
      begin
         return Stop = First
           and then N in 0 .. 9
           and then Line (First) =
             Character'Val (Character'Pos ('0') + N);
      end Is_Index;

      procedure Want_Word
        (Line  : String;
         Last  : Natural;
         Pos    : in out Natural;
         Want  : String;
         Good  : in out Boolean)
      is
         First : Natural;
         Stop  : Natural;
         Found : Boolean;
      begin
         if not Good then
            return;
         end if;
         Next_Token (Line, Last, Pos, First, Stop, Found);
         if not Found or else not Same (Line, First, Stop, Want) then
            Good := False;
         end if;
      end Want_Word;

      procedure Want_Index
        (Line  : String;
         Last  : Natural;
         Pos    : in out Natural;
         N     : Integer;
         Good  : in out Boolean;
         Shape : in out Boolean)
      is
         First : Natural;
         Stop  : Natural;
         Found : Boolean;
      begin
         if not Good then
            return;
         end if;
         Next_Token (Line, Last, Pos, First, Stop, Found);
         if not Found then
            Good := False;
         elsif not Is_Index (Line, First, Stop, N) then
            Good := False;
            Shape := True;
         end if;
      end Want_Index;

      procedure Want_Number
        (Line  : String;
         Last  : Natural;
         Pos    : in out Natural;
         Value : out Float;
         Good  : in out Boolean;
         Range_Bad : in out Boolean)
      is
         First : Natural;
         Stop  : Natural;
         Found : Boolean;
         Kind  : Number_Kind;
      begin
         Value := 0.0;
         if not Good then
            return;
         end if;
         Next_Token (Line, Last, Pos, First, Stop, Found);
         if not Found then
            Good := False;
            return;
         end if;
         Parse_Number (Line (First .. Stop), Value, Kind);
         case Kind is
            when Ok =>
               null;
            when Syntax =>
               Good := False;
            when Out_Of_Range =>
               Good := False;
               Range_Bad := True;
         end case;
      end Want_Number;

      function No_More
        (Line : String; Last : Natural; Pos : Natural) return Boolean
      is
         First : Natural;
         Stop  : Natural;
         Found : Boolean;
         Cursor : Natural := Pos;
      begin
         Next_Token (Line, Last, Cursor, First, Stop, Found);
         return not Found;
      end No_More;

   begin
      Draft.W1 :=
        (Rows => Hidden,
         Cols => Inputs,
         Data => (others => (others => 0.0)));
      Draft.B1 := (Length => Hidden, Data => (others => 0.0));
      Draft.W2 :=
        (Rows => Outputs,
         Cols => Hidden,
         Data => (others => (others => 0.0)));
      Draft.B2 := (Length => Outputs, Data => (others => 0.0));
      Draft.Rate := Model.Rate;
      Status := Bad_Syntax;

      while Step < 99 loop
         declare
            Line      : String (1 .. 400);
            Last      : Natural;
            Too_Long  : Boolean;
            Got       : Boolean;
            Pos        : Natural;
            Good      : Boolean;
            Shape_Bad : Boolean;
            Range_Bad : Boolean;
            Value     : Float;
         begin
            Take_Line (Line, Last, Too_Long, Got);
            exit when not Got;
            if Too_Long then
               Fail (Bad_Syntax);
            elsif Blank (Line, Last) or else Comment (Line, Last) then
               null;
            else
               Pos := 1;
               Good := True;
               Shape_Bad := False;
               Range_Bad := False;
               if Step = 0 then
                  Want_Word (Line, Last, Pos, "ada-ai-amplifier", Good);
                  Want_Word (Line, Last, Pos, "weights", Good);
                  Want_Word (Line, Last, Pos, "1", Good);
                  if Good and then No_More (Line, Last, Pos) then
                     Step := 1;
                  else
                     Fail (Bad_Syntax);
                  end if;
               elsif Step = 1 then
                  Want_Word (Line, Last, Pos, "shape", Good);
                  Want_Index (Line, Last, Pos, Inputs, Good, Shape_Bad);
                  Want_Index (Line, Last, Pos, Hidden, Good, Shape_Bad);
                  Want_Index (Line, Last, Pos, Outputs, Good, Shape_Bad);
                  if not Good then
                     if Shape_Bad then
                        Fail (Bad_Shape);
                     else
                        Fail (Bad_Syntax);
                     end if;
                  elsif not No_More (Line, Last, Pos) then
                     Fail (Bad_Syntax);
                  else
                     Step := 2;
                  end if;
               elsif Step < 2 + Hidden then
                  Want_Word (Line, Last, Pos, "hidden", Good);
                  Want_Index
                    (Line, Last, Pos, Step - 1, Good, Shape_Bad);
                  Want_Word (Line, Last, Pos, "x1", Good);
                  Want_Number
                    (Line, Last, Pos, Value, Good, Range_Bad);
                  if Good then
                     Draft.W1.Data (Step - 1, 1) := Value;
                  end if;
                  Want_Word (Line, Last, Pos, "x2", Good);
                  Want_Number
                    (Line, Last, Pos, Value, Good, Range_Bad);
                  if Good then
                     Draft.W1.Data (Step - 1, 2) := Value;
                  end if;
                  Want_Word (Line, Last, Pos, "bias", Good);
                  Want_Number
                    (Line, Last, Pos, Value, Good, Range_Bad);
                  if Good then
                     Draft.B1.Data (Step - 1) := Value;
                  end if;
                  if not Good then
                     if Range_Bad then
                        Fail (Bad_Value);
                     elsif Shape_Bad then
                        Fail (Bad_Shape);
                     else
                        Fail (Bad_Syntax);
                     end if;
                  elsif not No_More (Line, Last, Pos) then
                     Fail (Bad_Syntax);
                  else
                     Step := Step + 1;
                  end if;
               elsif Step = 2 + Hidden then
                  Want_Word (Line, Last, Pos, "output", Good);
                  Want_Index (Line, Last, Pos, Outputs, Good, Shape_Bad);
                  for C in 1 .. Hidden loop
                     Want_Word
                       (Line, Last, Pos,
                        (1 => 'h',
                         2 => Character'Val (Character'Pos ('0') + C)),
                        Good);
                     Want_Number
                       (Line, Last, Pos, Value, Good, Range_Bad);
                     if Good then
                        Draft.W2.Data (1, C) := Value;
                     end if;
                  end loop;
                  Want_Word (Line, Last, Pos, "bias", Good);
                  Want_Number
                    (Line, Last, Pos, Value, Good, Range_Bad);
                  if Good then
                     Draft.B2.Data (1) := Value;
                  end if;
                  if not Good then
                     if Range_Bad then
                        Fail (Bad_Value);
                     elsif Shape_Bad then
                        Fail (Bad_Shape);
                     else
                        Fail (Bad_Syntax);
                     end if;
                  elsif not No_More (Line, Last, Pos) then
                     Fail (Bad_Syntax);
                  else
                     Step := Step + 1;
                  end if;
               else
                  Fail (Bad_Syntax);
               end if;
            end if;
         end;
      end loop;

      if Status = Bad_Syntax and then Step = 2 + Hidden + 1 then
         Model := Draft;
         Status := Loaded;
      elsif Status = Bad_Syntax then
         null;
      end if;
   end Read_Weights;

end AI_Amplifier.MLP;
