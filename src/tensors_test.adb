with Ada.Assertions;
with Ada.Command_Line;
with Ada.Text_IO;
with AI_Amplifier.Tensors.Demo;

--  Known values, empty shapes, large softmax logits, and mismatches.
--  A mismatch must raise. It must not return a partial product.
procedure Tensors_Test
  with SPARK_Mode => Off
is
   package T renames AI_Amplifier.Tensors;

   Failures : Natural := 0;

   procedure Fail (Message : String) is
   begin
      Ada.Text_IO.Put_Line ("FAIL " & Message);
      Failures := Failures + 1;
   end Fail;

   function Near (Got, Want : Float) return Boolean is
      Diff : Float := Got - Want;
   begin
      if Diff < 0.0 then
         Diff := -Diff;
      end if;
      return Diff <= 0.000_05;
   end Near;

   procedure Expect (Name : String; Got, Want : Float) is
   begin
      if not Near (Got, Want) then
         Fail (Name & " got " & Float'Image (Got)
           & " want " & Float'Image (Want));
      end if;
   end Expect;

   procedure Raised_Assertion (Name : String; Raised : Boolean) is
   begin
      if not Raised then
         Fail (Name & " did not raise Assertion_Error");
      end if;
   end Raised_Assertion;

   function V3 (A, B, C : Float) return T.Vector is
      (Length => 3, Data => (A, B, C));

begin
   declare
      D : constant Float := T.Dot (V3 (1.0, 2.0, 3.0), V3 (4.0, 5.0, 6.0));
   begin
      Expect ("dot", D, 32.0);
   end;

   declare
      Empty : constant T.Vector := (Length => 0, Data => (others => 0.0));
   begin
      Expect ("empty dot", T.Dot (Empty, Empty), 0.0);
      if T.Add (Empty, Empty).Length /= 0 then
         Fail ("empty add length");
      end if;
      if T.Scale (Empty, 5.0).Length /= 0 then
         Fail ("empty scale length");
      end if;
      if T.ReLU (Empty).Length /= 0
        or else T.Sigmoid (Empty).Length /= 0
        or else T.Tanh (Empty).Length /= 0
        or else T.Softmax (Empty).Length /= 0
      then
         Fail ("empty activation length");
      end if;
   end;

   declare
      A : constant T.Matrix :=
        (Rows => 3,
         Cols => 3,
         Data => ((1.0, 2.0, 3.0), (0.0, 1.0, 4.0), (5.0, 6.0, 0.0)));
      Y : constant T.Vector := T.Mat_Vec (A, V3 (1.0, 2.0, 3.0));
   begin
      if Y.Length /= 3 then
         Fail ("mat-vec length");
      else
         Expect ("mat-vec 1", Y.Data (1), 14.0);
         Expect ("mat-vec 2", Y.Data (2), 14.0);
         Expect ("mat-vec 3", Y.Data (3), 17.0);
      end if;
   end;

   declare
      Wide : constant T.Matrix :=
        (Rows => 2, Cols => 0, Data => (others => (others => 0.0)));
      Empty : constant T.Vector := (Length => 0, Data => (others => 0.0));
      Y : constant T.Vector := T.Mat_Vec (Wide, Empty);
   begin
      if Y.Length /= 2 then
         Fail ("zero-column mat-vec length");
      else
         Expect ("zero-column 1", Y.Data (1), 0.0);
         Expect ("zero-column 2", Y.Data (2), 0.0);
      end if;
   end;

   declare
      L : constant T.Matrix :=
        (Rows => 2, Cols => 2, Data => ((1.0, 2.0), (3.0, 4.0)));
      R : constant T.Matrix :=
        (Rows => 2, Cols => 2, Data => ((5.0, 6.0), (7.0, 8.0)));
      P : constant T.Matrix := T.Mat_Mat (L, R);
   begin
      if P.Rows /= 2 or else P.Cols /= 2 then
         Fail ("mat-mat shape");
      else
         Expect ("mat-mat 11", P.Data (1, 1), 19.0);
         Expect ("mat-mat 12", P.Data (1, 2), 22.0);
         Expect ("mat-mat 21", P.Data (2, 1), 43.0);
         Expect ("mat-mat 22", P.Data (2, 2), 50.0);
      end if;
   end;

   declare
      Left_Z : constant T.Matrix :=
        (Rows => 2, Cols => 0, Data => (others => (others => 0.0)));
      Right_Z : constant T.Matrix :=
        (Rows => 0, Cols => 3, Data => (others => (others => 0.0)));
      P : constant T.Matrix := T.Mat_Mat (Left_Z, Right_Z);
   begin
      if P.Rows /= 2 or else P.Cols /= 3 then
         Fail ("empty mat-mat shape");
      else
         Expect ("empty mat-mat", P.Data (1, 1), 0.0);
         Expect ("empty mat-mat last", P.Data (2, 3), 0.0);
      end if;
   end;

   declare
      S : constant T.Vector :=
        T.Add (V3 (1.0, 2.0, 3.0), V3 (3.0, 4.0, 5.0));
      Scaled : constant T.Vector := T.Scale (V3 (1.0, -2.0, 3.0), 2.0);
   begin
      Expect ("add 1", S.Data (1), 4.0);
      Expect ("add 3", S.Data (3), 8.0);
      Expect ("scale 1", Scaled.Data (1), 2.0);
      Expect ("scale 2", Scaled.Data (2), -4.0);
   end;

   declare
      A : constant T.Matrix :=
        (Rows => 2, Cols => 3, Data => ((1.0, 2.0, 3.0), (4.0, 5.0, 6.0)));
      B : constant T.Matrix := T.Transpose (A);
      Scaled : constant T.Matrix := T.Scale (A, 0.5);
   begin
      if B.Rows /= 3 or else B.Cols /= 2 then
         Fail ("transpose shape");
      else
         Expect ("transpose 11", B.Data (1, 1), 1.0);
         Expect ("transpose 12", B.Data (1, 2), 4.0);
         Expect ("transpose 31", B.Data (3, 1), 3.0);
         Expect ("transpose 32", B.Data (3, 2), 6.0);
      end if;
      Expect ("scale matrix", Scaled.Data (2, 3), 3.0);
   end;

   declare
      R : constant T.Vector := T.ReLU (V3 (-1.0, 0.0, 2.5));
      G : constant T.Vector := T.Sigmoid (V3 (0.0, 40.0, -40.0));
      H : constant T.Vector := T.Tanh (V3 (0.0, 20.0, -20.0));
   begin
      Expect ("relu", R.Data (1), 0.0);
      Expect ("relu zero", R.Data (2), 0.0);
      Expect ("relu pos", R.Data (3), 2.5);
      Expect ("sigmoid zero", G.Data (1), 0.5);
      Expect ("sigmoid large", G.Data (2), 1.0);
      Expect ("sigmoid neg", G.Data (3), 0.0);
      Expect ("tanh zero", H.Data (1), 0.0);
      Expect ("tanh large", H.Data (2), 1.0);
      Expect ("tanh neg", H.Data (3), -1.0);
   end;

   declare
      --  1 / (1 + e**(-1)), about 0.73105857863.
      G : constant T.Vector := T.Sigmoid ((Length => 1, Data => (1 => 1.0)));
   begin
      Expect ("sigmoid one", G.Data (1), 0.731_059);
   end;

   declare
      Third : constant Float := 1.0 / 3.0;
      Uniform : constant T.Vector := T.Softmax (V3 (0.0, 0.0, 0.0));
      High : constant T.Vector := T.Softmax (V3 (1000.0, 1000.0, 1000.0));
      Low : constant T.Vector := T.Softmax (V3 (-1000.0, -1000.0, -1000.0));
      Huge : constant T.Vector :=
        T.Softmax ((Length => 2, Data => (1.0E20, 1.0E20)));
      Peak : constant T.Vector := T.Softmax (V3 (1000.0, 0.0, -1000.0));
      Sum : Float := 0.0;
   begin
      Expect ("softmax 0", Uniform.Data (1), Third);
      Expect ("softmax 0 last", Uniform.Data (3), Third);
      Expect ("softmax 1000", High.Data (2), Third);
      Expect ("softmax -1000", Low.Data (1), Third);
      Expect ("softmax 1e20", Huge.Data (1), 0.5);
      Expect ("softmax 1e20 b", Huge.Data (2), 0.5);
      Expect ("softmax peak", Peak.Data (1), 1.0);
      Expect ("softmax off", Peak.Data (2), 0.0);
      Expect ("softmax far", Peak.Data (3), 0.0);
      for I in 1 .. Uniform.Length loop
         Sum := Sum + Uniform.Data (I);
      end loop;
      Expect ("softmax sums to 1", Sum, 1.0);
   end;

   declare
      --  Max_Extent + 1, computed so it is not a static expression.
      --  A static out-of-range discriminant is illegal at compile time
      --  and would not reach this run-time range check.
      function Past_Bound return Integer is
         N : Integer := 1;
      begin
         N := T.Max_Extent;
         return N + N / N;
      end Past_Bound;

      L : T.Extent;
      Unused : T.Vector (0);
   begin
      L := T.Extent (Past_Bound);
      Unused := (Length => L, Data => (others => 0.0));
      Fail ("extent" & Integer'Image (Unused.Length) & " did not raise");
   exception
      when Constraint_Error =>
         null;
   end;

   declare
      Short : constant T.Vector := (Length => 2, Data => (1.0, 2.0));
      Long  : constant T.Vector := V3 (1.0, 2.0, 3.0);
      Raised : Boolean := False;
      D : Float;
   begin
      begin
         D := T.Dot (Short, Long);
         Fail ("dot short returned " & Float'Image (D));
      exception
         when Ada.Assertions.Assertion_Error =>
            Raised := True;
      end;
      Raised_Assertion ("dot short", Raised);
      Raised := False;
      begin
         D := T.Dot (Long, Short);
         Fail ("dot long returned " & Float'Image (D));
      exception
         when Ada.Assertions.Assertion_Error =>
            Raised := True;
      end;
      Raised_Assertion ("dot long", Raised);
   end;

   declare
      A : constant T.Matrix :=
        (Rows => 2, Cols => 2, Data => ((1.0, 2.0), (3.0, 4.0)));
      Raised : Boolean := False;
      Y : T.Vector (2);
   begin
      Y := T.Mat_Vec (A, V3 (1.0, 2.0, 3.0));
      Fail ("mat-vec returned " & Float'Image (Y.Data (1)));
   exception
      when Ada.Assertions.Assertion_Error =>
         Raised := True;
         Raised_Assertion ("mat-vec", Raised);
   end;

   declare
      L : constant T.Matrix :=
        (Rows => 2, Cols => 2, Data => ((1.0, 0.0), (0.0, 1.0)));
      R : constant T.Matrix :=
        (Rows => 3,
         Cols => 1,
         Data => ((1 => 1.0), (1 => 2.0), (1 => 3.0)));
      P : T.Matrix (2, 1);
   begin
      P := T.Mat_Mat (L, R);
      Fail ("mat-mat returned " & Float'Image (P.Data (1, 1)));
   exception
      when Ada.Assertions.Assertion_Error =>
         null;
   end;

   declare
      A : constant T.Matrix :=
        (Rows => 1, Cols => 2, Data => (1 => (1.0, 2.0)));
      B : constant T.Matrix :=
        (Rows => 1, Cols => 1, Data => (1 => (1 => 9.0)));
      S : T.Matrix (1, 2);
      W : T.Vector (3);
   begin
      S := T.Add (A, B);
      Fail ("add matrix returned " & Float'Image (S.Data (1, 1)));
   exception
      when Ada.Assertions.Assertion_Error =>
         begin
            W := T.Add
              (V3 (1.0, 2.0, 3.0), (Length => 1, Data => (1 => 4.0)));
            Fail ("add vector returned " & Float'Image (W.Data (1)));
         exception
            when Ada.Assertions.Assertion_Error =>
               null;
         end;
   end;

   AI_Amplifier.Tensors.Demo.Run;
   Expect ("demo y1", AI_Amplifier.Tensors.Demo.Product (1), 14.0);
   Expect ("demo y2", AI_Amplifier.Tensors.Demo.Product (2), 14.0);
   Expect ("demo y3", AI_Amplifier.Tensors.Demo.Product (3), 17.0);
   if AI_Amplifier.Tensors.Demo.Product (0) /= 0.0
     or else AI_Amplifier.Tensors.Demo.Product (4) /= 0.0
     or else AI_Amplifier.Tensors.Demo.Get_Matrix (0, 1) /= 0.0
   then
      Fail ("demo index did not read as 0");
   end if;

   declare
      S : constant T.Vector :=
        T.Softmax (V3 (14.0, 14.0, 17.0));
   begin
      Expect ("demo softmax",
        AI_Amplifier.Tensors.Demo.Chance (1), S.Data (1));
      Expect ("demo softmax 3",
        AI_Amplifier.Tensors.Demo.Chance (3), S.Data (3));
   end;

   if Failures = 0 then
      Ada.Text_IO.Put_Line ("tensors ok");
   else
      Ada.Text_IO.Put_Line ("tensors failed" & Natural'Image (Failures));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Tensors_Test;
