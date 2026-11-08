with Ada.Command_Line;
with Ada.Execution_Time;
with Ada.Real_Time;
with Ada.Text_IO;
with AI_Amplifier.MLP.Demo;
with AI_Amplifier.MLP.Speed;
with AI_Amplifier.Tensors;

--  The network against its own definition.
--  A zero net on XOR has loss ln 2 and a zero gradient (the labels
--  are balanced and the hidden layer is silent). A seeded net's
--  backprop matches a central difference. Training that seed on XOR
--  at rate 1 has to drive the mean loss under 0.05 and push the four
--  outputs past 0.8 and 0.2. The two circles, at the page's default
--  rate, have to separate as well. The page wrapper is checked
--  against the same steps.
procedure MLP_Test
  with SPARK_Mode => Off
is
   package M renames AI_Amplifier.MLP;
   package D renames AI_Amplifier.MLP.Demo;
   package S renames AI_Amplifier.MLP.Speed;
   package T renames AI_Amplifier.Tensors;
   use type M.Load_Status;

   Failures : Natural := 0;
   Cases    : Natural := 0;

   procedure Mark is
   begin
      Cases := Cases + 1;
   end Mark;

   procedure Fail (Message : String) is
   begin
      Ada.Text_IO.Put_Line ("FAIL " & Message);
      Failures := Failures + 1;
   end Fail;

   function Near (Got, Want, Tol : Float) return Boolean is
      Diff : Float := Got - Want;
   begin
      if Diff < 0.0 then
         Diff := -Diff;
      end if;
      return Diff <= Tol;
   end Near;

   procedure Expect (Name : String; Got, Want : Float) is
   begin
      Mark;
      if not Near (Got, Want, 0.000_05) then
         Fail (Name & " got " & Float'Image (Got)
           & " want " & Float'Image (Want));
      end if;
   end Expect;

   function Input (A, B : Float) return T.Vector is
     (Length => 2, Data => (A, B));

   function Separated (Model : M.Net; Data : M.Sample_List)
     return Boolean
   is
      Y : Float;
   begin
      for I in 1 .. Data.Count loop
         Y := M.Predict (Model, Data.Item (I).X);
         if Data.Item (I).Label >= 0.5 then
            if Y <= 0.5 then
               return False;
            end if;
         elsif Y >= 0.5 then
            return False;
         end if;
      end loop;
      return True;
   end Separated;

   --  XOR is small enough to ask for a gap, not only the 0.5 cut.
   function Margin (Model : M.Net; Data : M.Sample_List) return Boolean is
      Y : Float;
   begin
      for I in 1 .. Data.Count loop
         Y := M.Predict (Model, Data.Item (I).X);
         if Data.Item (I).Label >= 0.5 then
            if Y < 0.8 then
               return False;
            end if;
         elsif Y > 0.2 then
            return False;
         end if;
      end loop;
      return True;
   end Margin;

   procedure Expect_Grad (Name : String; Got, Want : Float) is
      Diff : Float := Got - Want;
      Mag  : Float := Want;
      Tol  : Float;
   begin
      Mark;
      if Diff < 0.0 then
         Diff := -Diff;
      end if;
      if Mag < 0.0 then
         Mag := -Mag;
      end if;
      --  Absolute floor plus a small fraction. A sign error or a
      --  missing factor of two is well outside this.
      Tol := 0.002 + 0.05 * Mag;
      if Diff > Tol then
         Fail (Name & " num " & Float'Image (Got)
           & " backprop " & Float'Image (Want));
      end if;
   end Expect_Grad;

   procedure Check_Finite_Difference
     (Model : M.Net;
      Data  : M.Sample_List;
      G     : M.Gradient)
   is
      Eps     : constant Float := 0.001;
      Plus    : M.Net;
      Minus   : M.Net;
      Numeric : Float;
      Strong  : Natural := 0;
   begin
      for R in 1 .. M.Hidden loop
         for C in 1 .. M.Inputs loop
            Plus := Model;
            Minus := Model;
            Plus.W1.Data (R, C) := Plus.W1.Data (R, C) + Eps;
            Minus.W1.Data (R, C) := Minus.W1.Data (R, C) - Eps;
            Numeric :=
              (M.Mean_Loss (Plus, Data) - M.Mean_Loss (Minus, Data))
              / (2.0 * Eps);
            Expect_Grad ("W1", Numeric, G.W1.Data (R, C));
            if G.W1.Data (R, C) > 0.02
              or else G.W1.Data (R, C) < -0.02
            then
               Strong := Strong + 1;
            end if;
         end loop;
         Plus := Model;
         Minus := Model;
         Plus.B1.Data (R) := Plus.B1.Data (R) + Eps;
         Minus.B1.Data (R) := Minus.B1.Data (R) - Eps;
         Numeric :=
           (M.Mean_Loss (Plus, Data) - M.Mean_Loss (Minus, Data))
           / (2.0 * Eps);
         Expect_Grad ("B1", Numeric, G.B1.Data (R));

         Plus := Model;
         Minus := Model;
         Plus.W2.Data (1, R) := Plus.W2.Data (1, R) + Eps;
         Minus.W2.Data (1, R) := Minus.W2.Data (1, R) - Eps;
         Numeric :=
           (M.Mean_Loss (Plus, Data) - M.Mean_Loss (Minus, Data))
           / (2.0 * Eps);
         Expect_Grad ("W2", Numeric, G.W2.Data (1, R));
         if G.W2.Data (1, R) > 0.02 or else G.W2.Data (1, R) < -0.02
         then
            Strong := Strong + 1;
         end if;
      end loop;

      Plus := Model;
      Minus := Model;
      Plus.B2.Data (1) := Plus.B2.Data (1) + Eps;
      Minus.B2.Data (1) := Minus.B2.Data (1) - Eps;
      Numeric :=
        (M.Mean_Loss (Plus, Data) - M.Mean_Loss (Minus, Data))
        / (2.0 * Eps);
      Expect_Grad ("B2", Numeric, G.B2.Data (1));
      if Strong = 0 then
         Fail ("finite difference saw only tiny gradients");
      end if;
   end Check_Finite_Difference;

   procedure Expect_Zero_Weights (Name : String; G : M.Gradient) is
   begin
      Mark;
      for R in 1 .. M.Hidden loop
         for C in 1 .. M.Inputs loop
            if not Near (G.W1.Data (R, C), 0.0, 0.000_001) then
               Fail (Name & " W1");
            end if;
         end loop;
         if not Near (G.B1.Data (R), 0.0, 0.000_001) then
            Fail (Name & " B1");
         end if;
         if not Near (G.W2.Data (1, R), 0.0, 0.000_001) then
            Fail (Name & " W2");
         end if;
      end loop;
   end Expect_Zero_Weights;

begin
   declare
      A : M.Net;
      B : M.Net;
      C : M.Net;
      Same : Boolean := True;
      Differs : Boolean := False;
   begin
      M.Initialize (A, M.Init_Seed, M.Default_Rate);
      M.Initialize (B, M.Init_Seed, M.Default_Rate);
      M.Initialize (C, M.Init_Seed + 1, M.Default_Rate);
      for R in 1 .. M.Hidden loop
         for Col in 1 .. M.Inputs loop
            if A.W1.Data (R, Col) /= B.W1.Data (R, Col) then
               Same := False;
            end if;
            if A.W1.Data (R, Col) /= C.W1.Data (R, Col) then
               Differs := True;
            end if;
         end loop;
         if A.W2.Data (1, R) /= B.W2.Data (1, R) then
            Same := False;
         end if;
         if A.B1.Data (R) /= 0.0 or else A.B2.Data (1) /= 0.0 then
            Fail ("bias did not start at 0");
         end if;
      end loop;
      if not Same then
         Fail ("same seed produced different weights");
      end if;
      if not Differs then
         Fail ("a different seed matched every W1 weight");
      end if;
      if not Near (A.Rate, M.Default_Rate, 0.0) then
         Fail ("default rate");
      end if;
      M.Initialize (A, M.Init_Seed, 0.0);
      if not Near (A.Rate, M.Default_Rate, 0.0) then
         Fail ("rate 0 was kept");
      end if;
      M.Initialize (A, M.Init_Seed, 9.0);
      if not Near (A.Rate, M.Default_Rate, 0.0) then
         Fail ("rate 9 was kept");
      end if;
   end;

   declare
      Model : M.Net;
      X     : constant T.Vector := Input (0.2, -0.4);
      Z1    : T.Vector (M.Hidden);
      H     : T.Vector (M.Hidden);
      Z2    : T.Vector (M.Outputs);
      Y     : T.Vector (M.Outputs);
   begin
      M.Initialize (Model, M.Init_Seed, 0.5);
      for R in 1 .. M.Hidden loop
         Model.W1.Data (R, 1) := Float (R) * 0.05;
         Model.W1.Data (R, 2) := -Float (R) * 0.03;
         Model.B1.Data (R) := Float (R - 4) * 0.1;
         Model.W2.Data (1, R) := Float (5 - R) * 0.07;
      end loop;
      Model.B2.Data (1) := 0.3;
      Z1 := T.Add (T.Mat_Vec (Model.W1, X), Model.B1);
      H := T.Tanh (Z1);
      Z2 := T.Add (T.Mat_Vec (Model.W2, H), Model.B2);
      Y := T.Sigmoid (Z2);
      Expect ("forward", M.Predict (Model, X), Y.Data (1));
   end;

   declare
      Model : M.Net;
      Data  : M.Sample_List;
      G     : M.Gradient;
      Loss  : Float;
   begin
      M.Initialize (Model, M.Init_Seed, 0.5);
      Model.W1 :=
        (Rows => M.Hidden,
         Cols => M.Inputs,
         Data => (others => (others => 0.0)));
      Model.B1 := (Length => M.Hidden, Data => (others => 0.0));
      Model.W2 :=
        (Rows => M.Outputs,
         Cols => M.Hidden,
         Data => (others => (others => 0.0)));
      Model.B2 := (Length => M.Outputs, Data => (others => 0.0));
      Data := M.Make_Dataset (M.XOR_Points);
      M.Backprop (Model, Data, G, Loss);
      --  ln 2. Sigmoid(0) is 1/2, and both labels cost -ln(1/2).
      Expect ("zero loss", Loss, 0.693_147);
      Expect ("zero mean", M.Mean_Loss (Model, Data), Loss);
      Expect_Zero_Weights ("balanced xor", G);
      Expect ("balanced db2", G.B2.Data (1), 0.0);

      Data.Count := 1;
      Data.Item (1) := (X => Input (0.0, 0.0), Label => 1.0);
      M.Backprop (Model, Data, G, Loss);
      Expect ("one loss", Loss, 0.693_147);
      Expect ("one db2", G.B2.Data (1), -0.5);
      Expect_Zero_Weights ("one sample", G);
   end;

   declare
      Model : M.Net;
      Data  : constant M.Sample_List := M.Make_Dataset (M.XOR_Points);
      G     : M.Gradient;
      Loss  : Float;
      Y     : Float;
   begin
      M.Initialize (Model, M.Init_Seed, 1.0);
      M.Backprop (Model, Data, G, Loss);
      Expect ("seeded mean", M.Mean_Loss (Model, Data), Loss);
      for I in 1 .. Data.Count loop
         Y := M.Predict (Model, Data.Item (I).X);
         if Y <= 0.05 or else Y >= 0.95 then
            Fail ("seeded output sits on the loss clip");
         end if;
      end loop;
      Check_Finite_Difference (Model, Data, G);

      declare
         Moved : M.Net := Model;
      begin
         M.Step (Moved, G);
         for R in 1 .. M.Hidden loop
            for C in 1 .. M.Inputs loop
               Expect
                 ("step W1",
                  Moved.W1.Data (R, C),
                  Model.W1.Data (R, C) - Model.Rate * G.W1.Data (R, C));
            end loop;
            Expect
              ("step B1",
               Moved.B1.Data (R),
               Model.B1.Data (R) - Model.Rate * G.B1.Data (R));
            Expect
              ("step W2",
               Moved.W2.Data (1, R),
               Model.W2.Data (1, R) - Model.Rate * G.W2.Data (1, R));
         end loop;
         Expect
           ("step B2",
            Moved.B2.Data (1),
            Model.B2.Data (1) - Model.Rate * G.B2.Data (1));
      end;
   end;

   declare
      Model : M.Net;
      Data  : constant M.Sample_List := M.Make_Dataset (M.XOR_Points);
      Loss  : Float;
      Took  : Natural := 0;
   begin
      M.Initialize (Model, M.Init_Seed, 1.0);
      Loss := M.Mean_Loss (Model, Data);
      for I in 1 .. 8000 loop
         M.Train (Model, Data, 1, Loss);
         Took := I;
         exit when Loss < 0.05 and then Margin (Model, Data);
      end loop;
      if Loss >= 0.05 or else not Margin (Model, Data) then
         Fail ("xor did not train, loss " & Float'Image (Loss)
           & " steps" & Natural'Image (Took));
         for I in 1 .. Data.Count loop
            Fail ("xor out " & Float'Image
              (M.Predict (Model, Data.Item (I).X)));
         end loop;
      end if;
   end;

   declare
      Model : M.Net;
      Data  : constant M.Sample_List :=
        M.Make_Dataset (M.Two_Circles);
      Loss  : Float;
      Took  : Natural := 0;
   begin
      --  Same default rate as the page. 2000 is a loose cap: this seed
      --  separates the circles well before that.
      M.Initialize (Model, M.Init_Seed, M.Default_Rate);
      Loss := M.Mean_Loss (Model, Data);
      for I in 1 .. 2000 loop
         M.Train (Model, Data, 1, Loss);
         Took := I;
         exit when Loss < 0.05 and then Separated (Model, Data);
      end loop;
      if Loss >= 0.05 or else not Separated (Model, Data) then
         Fail ("circles did not separate, loss " & Float'Image (Loss)
           & " steps" & Natural'Image (Took));
      end if;
   end;

   declare
      Circles : constant M.Sample_List :=
        M.Make_Dataset (M.Two_Circles);
      Spirals : constant M.Sample_List :=
        M.Make_Dataset (M.Two_Spirals);
      R2 : Float;
   begin
      if Circles.Count /= 72 then
         Fail ("circle count");
      end if;
      --  Make_Circles alternates inner (class 0) and outer (class 1).
      for I in 1 .. Circles.Count loop
         R2 := Circles.Item (I).X.Data (1) ** 2
           + Circles.Item (I).X.Data (2) ** 2;
         if I mod 2 = 1 then
            if Circles.Item (I).Label /= 0.0
              or else not Near (R2, 0.2025, 0.001)
            then
               Fail ("inner circle");
            end if;
         elsif Circles.Item (I).Label /= 1.0
           or else not Near (R2, 1.1025, 0.001)
         then
            Fail ("outer circle");
         end if;
      end loop;
      if Spirals.Count /= 96 then
         Fail ("spiral count");
      end if;
      for I in 1 .. 48 loop
         declare
            A : constant M.Sample := Spirals.Item (2 * I - 1);
            B : constant M.Sample := Spirals.Item (2 * I);
         begin
            if A.Label /= 0.0 or else B.Label /= 1.0 then
               Fail ("spiral label");
            end if;
            Expect ("spiral x", A.X.Data (1), -B.X.Data (1));
            Expect ("spiral y", A.X.Data (2), -B.X.Data (2));
         end;
      end loop;
      Expect
        ("spiral start",
         Spirals.Item (1).X.Data (1) ** 2
           + Spirals.Item (1).X.Data (2) ** 2,
         0.0144);
      Expect
        ("spiral end",
         Spirals.Item (95).X.Data (1) ** 2
           + Spirals.Item (95).X.Data (2) ** 2,
         1.3689);
   end;

   declare
      Model : M.Net;
      Data  : M.Sample_List;
      Loss  : Float;
   begin
      for Kind in M.Dataset_Kind loop
         Data := M.Make_Dataset (Kind);
         M.Initialize (Model, M.Init_Seed, M.Default_Rate);
         M.Train (Model, Data, 100, Loss);
         if Loss < 0.0 or else Loss > 2.0 then
            Fail ("loss left (0, 2) after 100 steps");
         end if;
      end loop;
   end;

   declare
      Mine : M.Net;
      Data : constant M.Sample_List := M.Make_Dataset (M.XOR_Points);
      Loss : Float;
      Low  : Float;
      High : Float;
      Span : Float;
      X    : Float;
      Y    : Float;
      Before : Integer;
   begin
      D.Reset (0);
      if D.Kind_Code /= 0 or else D.Sample_Count /= 4
        or else D.Step_Count /= 0
      then
         Fail ("demo reset xor");
      end if;
      M.Initialize (Mine, M.Init_Seed, D.Learning_Rate);
      for I in 1 .. 4 loop
         Expect
           ("demo predict",
            D.Predict_At (D.Sample_X (I), D.Sample_Y (I)),
            M.Predict (Mine, Data.Item (I).X));
         if D.Sample_Label (I) /= Data.Item (I).Label then
            Fail ("demo label");
         end if;
      end loop;
      if not Near (D.Current_Loss, M.Mean_Loss (Mine, Data), 0.000_05)
      then
         Fail ("demo initial loss");
      end if;
      if D.Curve_Count < 1
        or else not Near (D.Curve_At (1), D.Current_Loss, 0.000_05)
      then
         Fail ("demo curve tip");
      end if;

      D.Set_Learning_Rate (0.25);
      if not Near (D.Learning_Rate, 0.25, 0.0) then
         Fail ("set rate");
      end if;
      D.Set_Learning_Rate (0.0);
      D.Set_Learning_Rate (-1.0);
      D.Set_Learning_Rate (9.0);
      if not Near (D.Learning_Rate, 0.25, 0.0) then
         Fail ("bad rate was stored");
      end if;
      D.Reset (0);
      if not Near (D.Learning_Rate, 0.25, 0.0) or else D.Step_Count /= 0
      then
         Fail ("reset did not keep the rate");
      end if;

      M.Initialize (Mine, M.Init_Seed, 0.25);
      for I in 1 .. 10 loop
         M.Train (Mine, Data, 1, Loss);
      end loop;
      Loss := D.Run_Steps (10);
      if D.Step_Count /= 10
        or else not Near (Loss, M.Mean_Loss (Mine, Data), 0.000_05)
      then
         Fail ("demo 10 steps");
      end if;
      for I in 1 .. 4 loop
         Expect
           ("demo after",
            D.Predict_At (D.Sample_X (I), D.Sample_Y (I)),
            M.Predict (Mine, Data.Item (I).X));
      end loop;

      Before := D.Step_Count;
      if not Near (D.Run_Steps (0), D.Current_Loss, 0.0)
        or else not Near (D.Run_Steps (-3), D.Current_Loss, 0.0)
        or else D.Step_Count /= Before
      then
         Fail ("zero steps moved the epoch");
      end if;
      Loss := D.Run_Steps (1000);
      if D.Step_Count /= Before + D.Step_Cap
        or else not Near (Loss, D.Current_Loss, 0.0)
      then
         Fail ("step cap");
      end if;

      if D.Sample_X (0) /= 0.0 or else D.Sample_X (5) /= 0.0
        or else D.Sample_Y (-1) /= 0.0 or else D.Sample_Label (9) /= 0.0
        or else D.Cell (0, 1) /= 0.0 or else D.Cell (1, 0) /= 0.0
        or else D.Curve_At (0) /= 0.0 or else D.Curve_At (10_000) /= 0.0
      then
         Fail ("demo index did not read as 0");
      end if;

      D.Fill_Grid;
      if D.Grid_N /= D.Grid_Side then
         Fail ("grid side");
      end if;
      Low := D.View_Low;
      High := D.View_High;
      Span := (High - Low) / Float (D.Grid_Side);
      X := Low + 0.5 * Span;
      Y := High - 0.5 * Span;
      Expect ("grid corner", D.Cell (1, 1), D.Predict_At (X, Y));
      X := Low + (Float (D.Grid_Side) - 0.5) * Span;
      Y := High - (Float (D.Grid_Side) - 0.5) * Span;
      Expect
        ("grid far",
         D.Cell (D.Grid_Side, D.Grid_Side),
         D.Predict_At (X, Y));

      D.Reset (1);
      if D.Kind_Code /= 1 or else D.Sample_Count /= 72 then
         Fail ("demo circles");
      end if;
      D.Reset (2);
      if D.Kind_Code /= 2 or else D.Sample_Count /= 96 then
         Fail ("demo spirals");
      end if;
      D.Reset (9);
      if D.Kind_Code /= 0 or else D.Sample_Count /= 4 then
         Fail ("demo unknown kind");
      end if;
      M.View_Box (M.XOR_Points, Low, High);
      if not Near (D.View_Low, Low, 0.0)
        or else not Near (D.View_High, High, 0.0)
      then
         Fail ("demo view");
      end if;
   end;

   declare
      function Note_Text return String is
         S : String (1 .. D.Note_Length);
      begin
         for I in S'Range loop
            S (I) := Character'Val (D.Note_Byte (I));
         end loop;
         return S;
      end Note_Text;

      function Contains (Hay, Needle : String) return Boolean is
      begin
         if Needle'Length = 0 or else Needle'Length > Hay'Length then
            return False;
         end if;
         for I in Hay'First .. Hay'Last - Needle'Length + 1 loop
            if Hay (I .. I + Needle'Length - 1) = Needle then
               return True;
            end if;
         end loop;
         return False;
      end Contains;

      procedure Load_String
        (Model  : in out M.Net;
         Source : String;
         Status : out M.Load_Status)
      is
         Buf : M.Weight_Chars := (others => ' ');
      begin
         for I in Source'Range loop
            Buf (I - Source'First + 1) := Source (I);
         end loop;
         M.Read_Weights (Model, Buf, Source'Length, Status);
      end Load_String;

      function As_String
        (Buf : M.Weight_Chars; Count : Natural) return String
      is
         S : String (1 .. Count);
      begin
         for I in 1 .. Count loop
            S (I) := Buf (I);
         end loop;
         return S;
      end As_String;

      procedure Expect_Margin (Name : String; Model : M.Net) is
         Data : constant M.Sample_List := M.Make_Dataset (M.XOR_Points);
      begin
         Mark;
         if not Margin (Model, Data) then
            Fail (Name & " does not separate XOR");
            for I in 1 .. Data.Count loop
               Ada.Text_IO.Put_Line
                 ("  " & Float'Image (M.Predict (Model, Data.Item (I).X)));
            end loop;
         end if;
      end Expect_Margin;
   begin
      declare
         Hand : constant M.Net := M.Hand_XOR;
         Data : constant M.Sample_List := M.Make_Dataset (M.XOR_Points);
         Loss : Float;
      begin
         if Hand.W1.Data (1, 1) /= M.Hand_Or_Weight
           or else Hand.W1.Data (1, 2) /= M.Hand_Or_Weight
           or else Hand.B1.Data (1) /= M.Hand_Or_Bias
           or else Hand.W1.Data (2, 1) /= M.Hand_And_Weight
           or else Hand.B1.Data (2) /= M.Hand_And_Bias
           or else Hand.W2.Data (1, 1) /= M.Hand_Out_Or
           or else Hand.W2.Data (1, 2) /= M.Hand_Out_And
           or else Hand.B2.Data (1) /= M.Hand_Out_Bias
         then
            Fail ("hand weights are not the written gates");
         end if;
         for R in 3 .. M.Hidden loop
            if Hand.W1.Data (R, 1) /= 0.0
              or else Hand.W1.Data (R, 2) /= 0.0
              or else Hand.B1.Data (R) /= 0.0
              or else Hand.W2.Data (1, R) /= 0.0
            then
               Fail ("hand unit is not silent");
            end if;
         end loop;
         Expect_Margin ("hand xor", Hand);
         Loss := M.Mean_Loss (Hand, Data);
         if Loss >= 0.05 then
            Fail ("hand loss " & Float'Image (Loss));
         end if;
         for I in 1 .. 4 loop
            declare
               Y : constant Float :=
                 M.Predict (Hand, Data.Item (I).X);
            begin
               if Data.Item (I).Label >= 0.5 then
                  if Y < 0.8 then
                     Fail ("hand class 1");
                  end if;
               elsif Y > 0.2 then
                  Fail ("hand class 0");
               end if;
            end;
         end loop;

         declare
            Flipped  : M.Net := Hand;
            Silenced : M.Net := Hand;
            Inverted : M.Net := Hand;
            Y        : Float;
         begin
            M.Apply_Preset (Flipped, M.Flip_Hidden_1);
            Y := M.Predict (Flipped, Data.Item (1).X);
            if Y < 0.8 then
               Fail ("flip should raise (0,0)");
            end if;
            Y := M.Predict (Flipped, Data.Item (2).X);
            if Y > 0.2 then
               Fail ("flip should drop (0,1)");
            end if;
            Y := M.Predict (Flipped, Data.Item (3).X);
            if Y > 0.2 then
               Fail ("flip should drop (1,0)");
            end if;

            M.Apply_Preset (Silenced, M.Silence_Hidden_2);
            Y := M.Predict (Silenced, Data.Item (1).X);
            if Y > 0.2 then
               Fail ("silence moved (0,0)");
            end if;
            Y := M.Predict (Silenced, Data.Item (2).X);
            if Y > 0.8 then
               Fail ("silence left (0,1) sure");
            end if;
            Y := M.Predict (Silenced, Data.Item (4).X);
            if Y < 0.4 then
               Fail ("silence left (1,1) low");
            end if;

            M.Apply_Preset (Inverted, M.Invert_Output);
            for I in 1 .. Data.Count loop
               Y := M.Predict (Inverted, Data.Item (I).X);
               if Data.Item (I).Label >= 0.5 then
                  if Y > 0.2 then
                     Fail ("invert class 1");
                  end if;
               elsif Y < 0.8 then
                  Fail ("invert class 0");
               end if;
            end loop;
         end;
      end;

      declare
         Model  : M.Net := M.Hand_XOR;
         Other  : M.Net;
         Text       : M.Weight_Chars;
         Count      : Natural;
         Hand_Count : Natural;
         Status     : M.Load_Status;
         Source     : String (1 .. M.Max_Weight_Text);
         Rate   : constant Float := 0.25;
      begin
         Model.Rate := Rate;
         M.Write_Weights (Model, Text, Count);
         if Count < 40 or else Count > M.Max_Weight_Text then
            Fail ("weight text length");
         end if;
         Hand_Count := Count;
         Source (1 .. Hand_Count) := As_String (Text, Hand_Count);
         if not Contains (Source (1 .. Hand_Count), "shape 2 8 1")
           or else not Contains (Source (1 .. Hand_Count), "hidden 1")
           or else not Contains (Source (1 .. Hand_Count), "output 1")
         then
            Fail ("weight text labels");
         end if;
         M.Initialize (Other, M.Init_Seed, 1.0);
         Load_String (Other, Source (1 .. Hand_Count), Status);
         if Status /= M.Loaded then
            Fail ("round trip status");
         end if;
         if Other.Rate /= 1.0 then
            Fail ("load changed the rate");
         end if;
         for R in 1 .. M.Hidden loop
            for C in 1 .. M.Inputs loop
               if not Near
                 (Other.W1.Data (R, C), Model.W1.Data (R, C), 0.000_001)
               then
                  Fail ("round trip W1");
               end if;
            end loop;
            if not Near (Other.B1.Data (R), Model.B1.Data (R), 0.000_001)
              or else not Near
                (Other.W2.Data (1, R), Model.W2.Data (1, R), 0.000_001)
            then
               Fail ("round trip hidden");
            end if;
         end loop;
         if not Near (Other.B2.Data (1), Model.B2.Data (1), 0.000_001) then
            Fail ("round trip bias");
         end if;
         Expect_Margin ("reloaded hand", Other);

         M.Initialize (Other, M.Init_Seed, M.Default_Rate);
         M.Write_Weights (Other, Text, Count);
         declare
            Seeded : M.Net;
         begin
            M.Initialize (Seeded, M.Init_Seed, M.Default_Rate);
            Load_String
              (Seeded, As_String (Text, Count), Status);
            if Status /= M.Loaded then
               Fail ("seeded round trip");
            end if;
            for R in 1 .. M.Hidden loop
               for C in 1 .. M.Inputs loop
                  if not Near
                    (Seeded.W1.Data (R, C),
                     Other.W1.Data (R, C),
                     0.000_001)
                  then
                     Fail ("seeded W1");
                  end if;
               end loop;
            end loop;
         end;

         declare
            Kept  : constant Float := Other.W1.Data (1, 1);
            Bad   : String := As_String (Text, Count);
            Place : Natural;
         begin
            Place := 0;
            for I in Bad'Range loop
               if I <= Bad'Last - 10
                 and then Bad (I .. I + 10) = "shape 2 8 1"
               then
                  Place := I;
               end if;
            end loop;
            if Place = 0 then
               Fail ("shape line missing");
            else
               Bad (Place + 8) := '7';
            end if;
            Load_String (Other, Bad, Status);
            if Status /= M.Bad_Shape or else Other.W1.Data (1, 1) /= Kept
            then
               Fail ("bad shape was applied");
            end if;

            Bad := As_String (Text, Count);
            Place := 0;
            for I in Bad'Range loop
               if I + 10 <= Bad'Last
                 and then Bad (I .. I + 10) = "hidden 1 x1"
               then
                  Place := I + 12;
               end if;
            end loop;
            if Place = 0 then
               Fail ("hidden line missing");
            else
               Bad (Place .. Place + 3) := "1001";
            end if;
            Load_String (Other, Bad, Status);
            if Status /= M.Bad_Value or else Other.W1.Data (1, 1) /= Kept
            then
               Fail ("bad value was applied");
            end if;
         end;

         Load_String (Other, "not weights" & Character'Val (10), Status);
         if Status /= M.Bad_Syntax then
            Fail ("syntax");
         end if;
         Load_String
           (Other,
            "# a note" & Character'Val (10)
            & Character'Val (10)
            & Source (1 .. Hand_Count),
            Status);
         if Status /= M.Loaded then
            Fail ("comment was rejected");
         end if;
         Load_String
           (Other,
            Source (1 .. Hand_Count) & "extra" & Character'Val (10),
            Status);
         if Status /= M.Bad_Syntax then
            Fail ("extra line");
         end if;
         Load_String
           (Other,
            "ada-ai-amplifier weights 1" & Character'Val (10),
            Status);
         if Status /= M.Bad_Syntax then
            Fail ("truncated file");
         end if;
      end;

      declare
         Saved_Y : Float;
         Epoch   : Integer;
         Code    : Integer;
         N       : Integer;
         Bytes   : array (1 .. M.Max_Weight_Text) of Integer;
      begin
         D.Reset (0);
         if D.Weight_Count /= 33 then
            Fail ("param count");
         end if;
         if D.Name_Length (1) /= 5
           or else D.Name_Byte (1, 1) /= Character'Pos ('h')
           or else D.Name_Byte (1, 6) /= 0
           or else D.Name_Length (33) /= 3
           or else D.Name_Length (0) /= 0
         then
            Fail ("weight names");
         end if;
         if D.Set_Weight (1, 1.25) /= 0
           or else not Near (D.Weight_At (1), 1.25, 0.0)
         then
            Fail ("set weight");
         end if;
         if not Contains (Note_Text, "h1.x1") then
            Fail ("set note");
         end if;
         if D.Set_Weight (1, 1001.0) /= 1
           or else not Near (D.Weight_At (1), 1.25, 0.0)
         then
            Fail ("rejected weight");
         end if;
         if D.Set_Weight (0, 1.0) /= 2 or else D.Weight_At (0) /= 0.0
           or else D.Set_Weight (99, 1.0) /= 2
         then
            Fail ("bad weight index");
         end if;
         if not Near (D.Learning_Rate, 0.25, 0.0) then
            Fail ("rate before hand");
         end if;

         D.Load_Hand;
         if D.Kind_Code /= 0 or else D.Step_Count /= 0
           or else D.Sample_Count /= 4
         then
            Fail ("hand demo");
         end if;
         if not Near (D.Learning_Rate, 0.25, 0.0) then
            Fail ("hand kept the rate");
         end if;
         if not Contains (Note_Text, "hand-written") then
            Fail ("hand note");
         end if;
         if not Near (D.Weight_At (1), M.Hand_Or_Weight, 0.0)
           or else not Near (D.Weight_At (2), M.Hand_Or_Weight, 0.0)
           or else not Near (D.Weight_At (3), M.Hand_Or_Bias, 0.0)
           or else not Near (D.Weight_At (6), M.Hand_And_Bias, 0.0)
           or else D.Name_Length (3) /= 4
           or else D.Name_Byte (3, 4) /= Character'Pos ('b')
         then
            Fail ("hand fields are not grouped per unit");
         end if;
         for I in 1 .. 4 loop
            declare
               Y : constant Float :=
                 D.Predict_At (D.Sample_X (I), D.Sample_Y (I));
            begin
               if D.Sample_Label (I) >= 0.5 then
                  if Y < 0.8 then
                     Fail ("demo hand class 1");
                  end if;
               elsif Y > 0.2 then
                  Fail ("demo hand class 0");
               end if;
            end;
         end loop;

         N := D.Export_Length;
         if N < 40 then
            Fail ("export length");
         end if;
         for I in 1 .. N loop
            Bytes (I) := D.Export_Byte (I);
         end loop;
         if D.Export_Byte (0) /= 0 or else D.Export_Byte (N + 1) /= 0 then
            Fail ("export clamp");
         end if;
         Code := D.Set_Weight (1, 0.0);
         if Code /= 0 then
            Fail ("zero a weight");
         end if;
         D.Import_Clear;
         D.Import_Push (300);
         D.Import_Push (-1);
         for I in 1 .. N loop
            D.Import_Push (Bytes (I));
         end loop;
         if D.Import_Load /= 0 then
            Fail ("reload file " & Note_Text);
         end if;
         if not Near (D.Weight_At (1), M.Hand_Or_Weight, 0.000_001) then
            Fail ("reload value");
         end if;
         if D.Step_Count /= 0 then
            Fail ("reload epoch");
         end if;

         D.Import_Clear;
         declare
            Bad : constant String :=
              "ada-ai-amplifier weights 1" & Character'Val (10)
              & "shape 2 4 1" & Character'Val (10);
         begin
            for I in Bad'Range loop
               D.Import_Push (Character'Pos (Bad (I)));
            end loop;
         end;
         if D.Import_Load /= 1
           or else not Near (D.Weight_At (1), M.Hand_Or_Weight, 0.000_001)
         then
            Fail ("demo bad shape");
         end if;

         D.Reset (0);
         if D.Run_Steps (4) < 0.0 then
            Fail ("steps");
         end if;
         Epoch := D.Step_Count;
         Saved_Y := D.Predict_At (0.0, 1.0);
         D.Load_Hand;
         if Near (D.Predict_At (0.0, 1.0), Saved_Y, 0.000_01) then
            Fail ("hand matched the trained point");
         end if;
         D.Restore_Trained;
         if D.Step_Count /= Epoch
           or else not Near (D.Predict_At (0.0, 1.0), Saved_Y, 0.000_01)
         then
            Fail ("restore trained");
         end if;
         if not Contains (Note_Text, "training step") then
            Fail ("restore note");
         end if;

         D.Load_Hand;
         D.Preset (1);
         if D.Predict_At (0.0, 1.0) > 0.2 then
            Fail ("demo flip");
         end if;
         if not Contains (Note_Text, "Flipped hidden 1") then
            Fail ("flip note");
         end if;
         D.Load_Hand;
         D.Preset (2);
         if D.Predict_At (1.0, 1.0) < 0.4 then
            Fail ("demo silence");
         end if;
         if not Contains (Note_Text, "Silenced hidden 2") then
            Fail ("silence note");
         end if;
         D.Load_Hand;
         D.Preset (3);
         if D.Predict_At (0.0, 1.0) > 0.2
           or else D.Predict_At (0.0, 0.0) < 0.8
         then
            Fail ("demo invert");
         end if;
         if not Contains (Note_Text, "trade places") then
            Fail ("invert note");
         end if;
         D.Preset (9);
         if not Contains (Note_Text, "not one of the three") then
            Fail ("unknown preset");
         end if;
         if D.Note_Byte (0) /= 0 then
            Fail ("note clamp");
         end if;
      end;
   end;

   declare
      function Report_Text return String is
         Buffer : String (1 .. 1200) := (others => ' ');
         N      : constant Integer := S.Report_Length;
      begin
         for I in 1 .. N loop
            Buffer (I) := Character'Val (S.Report_Byte (I));
         end loop;
         return Buffer (1 .. N);
      end Report_Text;

      function Cpu_Us
        (Start : Ada.Execution_Time.CPU_Time) return Integer
      is
         use type Ada.Execution_Time.CPU_Time;
         Span : constant Ada.Real_Time.Time_Span :=
           Ada.Execution_Time.Clock - Start;
         Dur  : constant Duration :=
           Ada.Real_Time.To_Duration (Span);
         Us   : Float;
      begin
         Us := Float (Dur) * 1_000_000.0;
         if Us <= 0.0 then
            return 0;
         elsif Us >= 1.0e9 then
            return 1_000_000_000;
         else
            return Integer (Us);
         end if;
      end Cpu_Us;

      function Has (Hay, Needle : String) return Boolean is
      begin
         if Needle'Length = 0 or else Needle'Length > Hay'Length then
            return False;
         end if;
         for I in Hay'First .. Hay'Last - Needle'Length + 1 loop
            if Hay (I .. I + Needle'Length - 1) = Needle then
               return True;
            end if;
         end loop;
         return False;
      end Has;

      procedure Time_Run (Code : Integer; Name : String) is
         Start : Ada.Execution_Time.CPU_Time;
         Us    : Integer;
      begin
         S.Prepare (Code);
         Start := Ada.Execution_Time.Clock;
         S.Execute;
         Us := Cpu_Us (Start);
         S.Note_Cpu_Microseconds (Us);
         Ada.Text_IO.Put_Line
           ("speed " & Name
            & " steps" & Integer'Image (S.Step_Count)
            & " repeats" & Integer'Image (S.Repeat_Count)
            & " us" & Integer'Image (S.Microseconds)
            & " loss " & Float'Image (S.Loss)
            & " counted" & Integer'Image (S.Counted)
            & " reason" & Integer'Image (S.Reason_Code));
         Ada.Text_IO.Put_Line (Report_Text);
      end Time_Run;

      Baseline_Us : Integer := 0;
      Faster_Us   : Integer := 0;
   begin
      declare
         Model : M.Net;
         Data  : constant M.Sample_List :=
           M.Make_Dataset (M.XOR_Points);
         Loss  : Float;
         Took  : Natural := 0;
      begin
         M.Initialize (Model, M.Init_Seed, S.Rate);
         for I in 1 .. 8000 loop
            M.Train (Model, Data, 1, Loss);
            Took := I;
            exit when Loss < S.Loss_Max and then Margin (Model, Data);
         end loop;
         if Took /= S.Published_Steps
           or else Loss >= S.Loss_Max
           or else not Margin (Model, Data)
         then
            Fail ("yardstick steps" & Natural'Image (Took)
              & " loss " & Float'Image (Loss));
         end if;
      end;

      Time_Run (1, "baseline");
      if S.Counted /= 1 or else S.Reason_Code /= 1 then
         Fail ("baseline not counted, reason"
           & Integer'Image (S.Reason_Code));
      elsif S.Microseconds <= 0 then
         Fail ("baseline clock");
      else
         Baseline_Us := S.Microseconds;
         if S.Loss >= S.Loss_Max then
            Fail ("baseline loss");
         end if;
         for I in 1 .. 4 loop
            if S.Answer (I) <= 0.0 then
               Fail ("baseline answer");
            end if;
         end loop;
      end if;

      Time_Run (2, "faster");
      if S.Counted /= 1 or else S.Reason_Code /= 1 then
         Fail ("faster not counted, reason"
           & Integer'Image (S.Reason_Code));
      elsif not Has (Report_Text, "times the baseline")
        or else not Has (Report_Text, "33044")
        or else not Has (Report_Text, "10162")
      then
         Fail ("faster ratio text");
      else
         Faster_Us := S.Microseconds;
         if Faster_Us <= 0 or else Faster_Us >= Baseline_Us then
            Fail ("faster us" & Integer'Image (Faster_Us)
              & " baseline" & Integer'Image (Baseline_Us));
         end if;
         if not (S.Loss < S.Loss_Max) then
            Fail ("faster loss");
         end if;
      end if;
      --  The published microseconds are one machine's record.
      --  This bound only catches a clock that barely moves, or a
      --  run that is not the timed section. It is not a match.
      if Baseline_Us < S.Published_Native / 40
        or else Baseline_Us / 40 > S.Published_Native
      then
         Fail ("baseline us far from the record"
           & Integer'Image (Baseline_Us));
      end if;
      Ada.Text_IO.Put_Line
        ("speed ratio faster/baseline"
         & Integer'Image (Faster_Us)
         & " /" & Integer'Image (Baseline_Us));

      Time_Run (3, "outside");
      if S.Counted /= 0 or else S.Reason_Code /= 3
        or else S.Microseconds /= 0
        or else S.Loss >= S.Loss_Max
        or else S.Answer (2) < S.High_Min
        or else S.Answer (1) > S.Low_Max
      then
         Fail ("outside reason" & Integer'Image (S.Reason_Code)
           & " loss " & Float'Image (S.Loss));
      end if;
      if not Has (Report_Text, "does not count") then
         Fail ("outside text");
      end if;

      Time_Run (4, "skipped");
      if S.Counted /= 0 or else S.Reason_Code /= 4 then
         Fail ("skipped reason" & Integer'Image (S.Reason_Code));
      end if;

      Time_Run (5, "easier");
      if S.Counted /= 0 or else S.Reason_Code /= 5 then
         Fail ("easier reason" & Integer'Image (S.Reason_Code));
      end if;

      Time_Run (9, "unknown");
      if S.Counted /= 0 or else S.Reason_Code /= 7 then
         Fail ("unknown reason" & Integer'Image (S.Reason_Code));
      end if;

      S.Prepare (1);
      S.Execute;
      S.Note_Cpu_Microseconds (0);
      if S.Counted /= 0 or else S.Reason_Code /= 6 then
         Fail ("clock reason" & Integer'Image (S.Reason_Code));
      end if;

      if S.Answer (0) /= 0.0 or else S.Report_Byte (0) /= 0 then
         Fail ("speed clamp");
      end if;
      if S.Published_Step_Count /= S.Published_Steps
        or else S.Repeat_Count /= S.Repeats
      then
         Fail ("published exports");
      end if;
   end;

   if Failures = 0 then
      Ada.Text_IO.Put_Line ("cases mlp_test" & Cases'Image);
      Ada.Text_IO.Put_Line ("mlp ok");
   else
      Ada.Text_IO.Put_Line ("mlp failed" & Natural'Image (Failures));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end MLP_Test;
