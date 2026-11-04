with Ada.Command_Line;
with Ada.Text_IO;
with AI_Amplifier.MLP.Demo;
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
   package T renames AI_Amplifier.Tensors;

   Failures : Natural := 0;

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

   if Failures = 0 then
      Ada.Text_IO.Put_Line ("mlp ok");
   else
      Ada.Text_IO.Put_Line ("mlp failed" & Natural'Image (Failures));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end MLP_Test;
