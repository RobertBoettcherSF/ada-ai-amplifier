package body AI_Amplifier.Tensors
  with SPARK_Mode => Off
is

   pragma Assertion_Policy (Pre => Check, Post => Check);

   --  exp(X), clamped. Outside [-80, 80] the real value underflows to
   --  0 or overflows Float, so those ends return 0 and a finite stand-in.
   --  Softmax only calls this at or below 0 (it subtracts the max).
   --  Sigmoid only calls it at or below 0 as well.
   --  This is not Ada.Numerics.Elementary_Functions: that runtime asks
   --  the wasm host for libm, and this module links with no imports.
   function Exp_Clamped (X : Float) return Float is
      Ln2   : constant Float := 0.693_147_2;
      Limit : constant Float := 80.0;
      Reduced : Float;
      Remainder : Float;
      Term : Float;
      Sum  : Float;
      N    : Integer;
   begin
      if X <= -Limit then
         return 0.0;
      elsif X >= Limit then
         Reduced := Limit;
      else
         Reduced := X;
      end if;

      --  X = N*ln(2) + R, with R near 0, then exp(X) = 2**N * exp(R).
      N := Integer (Reduced / Ln2);
      Remainder := Reduced - Float (N) * Ln2;
      Term := 1.0;
      Sum := 1.0;
      for K in 1 .. 12 loop
         Term := Term * Remainder / Float (K);
         Sum := Sum + Term;
      end loop;

      --  2**N by multiplying. The ** operator needs a runtime unit
      --  this wasm RTS does not ship.
      declare
         Scale : Float := 1.0;
      begin
         if N >= 0 then
            for I in 1 .. N loop
               Scale := Scale * 2.0;
            end loop;
         else
            for I in 1 .. -N loop
               Scale := Scale * 0.5;
            end loop;
         end if;
         return Sum * Scale;
      end;
   end Exp_Clamped;

   function Sigmoid_Of (X : Float) return Float is
      E : Float;
   begin
      --  The negative side keeps the exponential argument <= 0.
      if X >= 0.0 then
         E := Exp_Clamped (-X);
         return 1.0 / (1.0 + E);
      else
         E := Exp_Clamped (X);
         return E / (1.0 + E);
      end if;
   end Sigmoid_Of;

   function Tanh_Of (X : Float) return Float is
   begin
      if X > 20.0 then
         return 1.0;
      elsif X < -20.0 then
         return -1.0;
      else
         return 2.0 * Sigmoid_Of (2.0 * X) - 1.0;
      end if;
   end Tanh_Of;

   function ReLU_Of (X : Float) return Float is
   begin
      if X > 0.0 then
         return X;
      else
         return 0.0;
      end if;
   end ReLU_Of;

   --  Length check in both directions. Indexing only the shorter side
   --  would ignore a longer operand. Assigning one array onto the
   --  other's bounds raises Constraint_Error either way.
   function Checked_Length (Wanted, Given : Extent) return Extent is
      Pattern : constant Element_Array (1 .. Given) := (others => 0.0);
      Fitted  : constant Element_Array (1 .. Wanted) := Pattern;
   begin
      return Fitted'Length;
   end Checked_Length;

   function Zero_Vector (N : Extent) return Vector is
      (Length => N, Data => (others => 0.0));

   function Zero_Matrix (R, C : Extent) return Matrix is
      (Rows => R, Cols => C, Data => (others => (others => 0.0)));

   function Dot (Left, Right : Vector) return Float is
      Shared : constant Extent :=
        Checked_Length (Left.Length, Right.Length);
      Acc : Float := 0.0;
   begin
      for I in 1 .. Shared loop
         Acc := Acc + Left.Data (I) * Right.Data (I);
      end loop;
      return Acc;
   end Dot;

   function Mat_Vec (A : Matrix; V : Vector) return Vector is
      Shared : constant Extent := Checked_Length (A.Cols, V.Length);
      Result : Vector := Zero_Vector (A.Rows);
   begin
      for R in 1 .. Result.Length loop
         declare
            Acc : Float := 0.0;
         begin
            for C in 1 .. Shared loop
               Acc := Acc + A.Data (R, C) * V.Data (C);
            end loop;
            Result.Data (R) := Acc;
         end;
      end loop;
      return Result;
   end Mat_Vec;

   function Mat_Mat (Left, Right : Matrix) return Matrix is
      Shared : constant Extent :=
        Checked_Length (Left.Cols, Right.Rows);
      Result : Matrix := Zero_Matrix (Left.Rows, Right.Cols);
   begin
      for R in 1 .. Result.Rows loop
         for C in 1 .. Result.Cols loop
            declare
               Acc : Float := 0.0;
            begin
               for K in 1 .. Shared loop
                  Acc := Acc + Left.Data (R, K) * Right.Data (K, C);
               end loop;
               Result.Data (R, C) := Acc;
            end;
         end loop;
      end loop;
      return Result;
   end Mat_Mat;

   function Add (Left, Right : Vector) return Vector is
      Shared : constant Extent :=
        Checked_Length (Left.Length, Right.Length);
      Result : Vector := Zero_Vector (Shared);
   begin
      for I in 1 .. Shared loop
         Result.Data (I) := Left.Data (I) + Right.Data (I);
      end loop;
      return Result;
   end Add;

   function Add (Left, Right : Matrix) return Matrix is
      Shared_Rows : constant Extent :=
        Checked_Length (Left.Rows, Right.Rows);
      Shared_Cols : constant Extent :=
        Checked_Length (Left.Cols, Right.Cols);
      Result : Matrix := Zero_Matrix (Shared_Rows, Shared_Cols);
   begin
      for R in 1 .. Shared_Rows loop
         for C in 1 .. Shared_Cols loop
            Result.Data (R, C) := Left.Data (R, C) + Right.Data (R, C);
         end loop;
      end loop;
      return Result;
   end Add;

   function Scale (V : Vector; Factor : Float) return Vector is
      Result : Vector := Zero_Vector (V.Length);
   begin
      for I in 1 .. Result.Length loop
         Result.Data (I) := V.Data (I) * Factor;
      end loop;
      return Result;
   end Scale;

   function Scale (A : Matrix; Factor : Float) return Matrix is
      Result : Matrix := Zero_Matrix (A.Rows, A.Cols);
   begin
      for R in 1 .. Result.Rows loop
         for C in 1 .. Result.Cols loop
            Result.Data (R, C) := A.Data (R, C) * Factor;
         end loop;
      end loop;
      return Result;
   end Scale;

   function Transpose (A : Matrix) return Matrix is
      Result : Matrix := Zero_Matrix (A.Cols, A.Rows);
   begin
      for R in 1 .. A.Rows loop
         for C in 1 .. A.Cols loop
            Result.Data (C, R) := A.Data (R, C);
         end loop;
      end loop;
      return Result;
   end Transpose;

   function ReLU (V : Vector) return Vector is
      Result : Vector := Zero_Vector (V.Length);
   begin
      for I in 1 .. Result.Length loop
         Result.Data (I) := ReLU_Of (V.Data (I));
      end loop;
      return Result;
   end ReLU;

   function Sigmoid (V : Vector) return Vector is
      Result : Vector := Zero_Vector (V.Length);
   begin
      for I in 1 .. Result.Length loop
         Result.Data (I) := Sigmoid_Of (V.Data (I));
      end loop;
      return Result;
   end Sigmoid;

   function Tanh (V : Vector) return Vector is
      Result : Vector := Zero_Vector (V.Length);
   begin
      for I in 1 .. Result.Length loop
         Result.Data (I) := Tanh_Of (V.Data (I));
      end loop;
      return Result;
   end Tanh;

   function Softmax (V : Vector) return Vector is
      Result : Vector := Zero_Vector (V.Length);
      Peak   : Float;
      Sum    : Float := 0.0;
      Lifted : Element_Array (1 .. V.Length) := (others => 0.0);
   begin
      if V.Length = 0 then
         return Result;
      end if;

      Peak := V.Data (1);
      for I in 2 .. V.Length loop
         if V.Data (I) > Peak then
            Peak := V.Data (I);
         end if;
      end loop;

      for I in 1 .. V.Length loop
         Lifted (I) := Exp_Clamped (V.Data (I) - Peak);
         Sum := Sum + Lifted (I);
      end loop;

      --  The peak maps to exp(0) = 1, so Sum is at least 1.
      for I in 1 .. V.Length loop
         Result.Data (I) := Lifted (I) / Sum;
      end loop;
      return Result;
   end Softmax;

end AI_Amplifier.Tensors;
