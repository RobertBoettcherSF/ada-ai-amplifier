package body AI_Amplifier.Tensors
  with SPARK_Mode
is

   pragma Assertion_Policy (Pre => Check, Post => Check);

   --  Twelve terms of the series, each of magnitude at most 1, plus
   --  the leading 1. The loop invariant is abs Sum <= 1 + K, and K
   --  ends at 12, so the sum is at most 13.
   Series_Bound : constant Float := 13.0;

   --  2**115 is about 4.15E34. The scale guard sits above that, so it
   --  does not fire for a reduced argument in [-80, 80] (the quotient
   --  by ln 2 is about 115). 2**116 is about 8.3E34, under Scale_Limit.
   Scale_Guard : constant Float := 5.0E34;
   Scale_Limit : constant Float := 1.0E35;

   --  80 / ln 2 is about 115.4. A quotient outside [-120, 120] cannot
   --  happen for a reduced argument in [-80, 80]. The guard returns a
   --  finite stand-in so the rest of the function has a bound.
   Quotient_Limit : constant Float := 120.0;

   function Bounded_Mul (L, R : Float) return Float
     with Pre  => abs L <= Summand_Bound and then abs R <= Summand_Bound,
          Post => Bounded_Mul'Result = L * R
            and then abs Bounded_Mul'Result <= Product_Bound
   is
   begin
      return L * R;
   end Bounded_Mul;

   function Bounded_Add (L, R : Float) return Float
     with Pre  => abs L <= Summand_Bound and then abs R <= Summand_Bound,
          Post => Bounded_Add'Result = L + R
   is
   begin
      return L + R;
   end Bounded_Add;

   --  Step counts components already stored in the sum, including
   --  Part. Part is one exponential, so it lies in [0, Exp_Ceiling].
   --  The bound is what keeps the softmax denominator inside Float.
   function Sum_Step (Total, Part : Float; Step : Positive) return Float
     with Pre  => Step <= Max_Extent
       and then Part >= 0.0
       and then Part <= Exp_Ceiling
       and then Total >= 0.0
       and then Total
         <= Float (Step - 1) * (Acc_Slack * Exp_Ceiling),
          Post => Sum_Step'Result = Total + Part
            and then Sum_Step'Result
              <= Float (Step) * (Acc_Slack * Exp_Ceiling)
   is
   begin
      return Total + Part;
   end Sum_Step;

   --  Steps counts how many products have been added, including this
   --  one. The slack factor in the bound is Acc_Slack (see the spec).
   function Acc_Step (Acc, Term : Float; Steps : Positive) return Float
     with Pre  => Steps <= Max_Extent
       and then abs Term <= Product_Bound
       and then abs Acc
         <= Float (Steps - 1) * (Acc_Slack * Product_Bound),
          Post => Acc_Step'Result = Acc + Term
            and then abs Acc_Step'Result
              <= Float (Steps) * (Acc_Slack * Product_Bound)
   is
   begin
      return Acc + Term;
   end Acc_Step;

   function Exp_Series (Remainder : Float) return Float
     with Pre  => Remainder >= -1.0 and then Remainder <= 1.0,
          Post => abs Exp_Series'Result <= Series_Bound
   is
      Term : Float := 1.0;
      Sum  : Float := 1.0;
   begin
      for K in 1 .. 12 loop
         Term := Term * Remainder / Float (K);
         Sum := Sum + Term;
         pragma Loop_Invariant (abs Term <= 1.0);
         pragma Loop_Invariant (abs Sum <= 1.0 + Float (K));
      end loop;
      return Sum;
   end Exp_Series;

   function Pow2_Scale (N : Integer) return Float
     with Pre  => N in -120 .. 120,
          Post => Pow2_Scale'Result >= 0.0
            and then Pow2_Scale'Result <= Scale_Limit
   is
      Scale : Float := 1.0;
   begin
      if N > 0 then
         for I in 1 .. N loop
            if Scale > Scale_Guard then
               Scale := Scale_Guard;
            end if;
            Scale := Scale * 2.0;
            pragma Loop_Invariant
              (Scale >= 1.0 and then Scale <= Scale_Limit);
         end loop;
      elsif N < 0 then
         for I in 1 .. -N loop
            Scale := Scale * 0.5;
            pragma Loop_Invariant
              (Scale >= 0.0 and then Scale <= 1.0);
         end loop;
      end if;
      return Scale;
   end Pow2_Scale;

   --  exp(X), clamped. Outside [-80, 80] the real value underflows to
   --  0 or overflows Float, so those ends return 0 and a finite
   --  stand-in. Softmax calls this at or below 0 (it subtracts the
   --  max). Sigmoid calls it on an argument whose magnitude is below
   --  80, or not at all.
   --
   --  This is not Ada.Numerics.Elementary_Functions: that runtime asks
   --  the wasm host for libm, and this module links with no imports.
   --
   --  Three guards keep the proof inside a range: the quotient, the
   --  remainder, and the scale. On a reduced argument in [-80, 80]
   --  none of them changes the value. The quotient is about 115, the
   --  remainder is at most about half of ln 2 (0.35), and the scale
   --  is at most 2**115. A final clamp forces the Silver range. It
   --  does not fire for those arguments either: the series times the
   --  scale stays far under Exp_Ceiling. The proof shows the range
   --  and the absence of overflow. It does not show that the series
   --  equals the real exponential.
   function Exp_Clamped (X : Float) return Float
     with Post => Exp_Clamped'Result >= 0.0
       and then Exp_Clamped'Result <= Exp_Ceiling
   is
      Ln2   : constant Float := 0.693_147_2;
      Limit : constant Float := 80.0;
      Reduced : Float;
   begin
      if X <= -Limit then
         return 0.0;
      elsif X >= Limit then
         Reduced := Limit;
      else
         Reduced := X;
      end if;

      declare
         Quotient : constant Float := Reduced / Ln2;
         N : Integer;
         Remainder : Float;
         Raw : Float;
      begin
         if Quotient < -Quotient_Limit or else Quotient > Quotient_Limit
         then
            return 0.0;
         end if;

         N := Integer (Quotient);
         Remainder := Reduced - Float (N) * Ln2;
         if Remainder > 1.0 then
            Remainder := 1.0;
         elsif Remainder < -1.0 then
            Remainder := -1.0;
         end if;

         Raw := Exp_Series (Remainder) * Pow2_Scale (N);
         if Raw < 0.0 then
            return 0.0;
         elsif Raw > Exp_Ceiling then
            return Exp_Ceiling;
         else
            return Raw;
         end if;
      end;
   end Exp_Clamped;

   function Sigmoid_Of (X : Float) return Float
     with Post => Sigmoid_Of'Result >= 0.0
       and then Sigmoid_Of'Result <= 1.0
   is
      E : Float;
   begin
      --  At and beyond 80 the exponential underflows to 0, so the
      --  result is exactly 0 or 1. The inner branch only negates a
      --  value whose magnitude is below 80.
      if X >= 80.0 then
         return 1.0;
      elsif X <= -80.0 then
         return 0.0;
      elsif X >= 0.0 then
         E := Exp_Clamped (-X);
         return 1.0 / (1.0 + E);
      else
         E := Exp_Clamped (X);
         return E / (1.0 + E);
      end if;
   end Sigmoid_Of;

   function Tanh_Of (X : Float) return Float
     with Post => Tanh_Of'Result >= -1.0
       and then Tanh_Of'Result <= 1.0
   is
      S : Float;
   begin
      --  Outside [-20, 20] the result is the sign. The boundary
      --  itself uses the formula, same as before this proof.
      if X > 20.0 then
         return 1.0;
      elsif X < -20.0 then
         return -1.0;
      end if;
      S := Sigmoid_Of (2.0 * X);
      return 2.0 * S - 1.0;
   end Tanh_Of;

   function ReLU_Of (X : Float) return Float
     with Post => ReLU_Of'Result = (if X > 0.0 then X else 0.0)
   is
   begin
      if X > 0.0 then
         return X;
      else
         return 0.0;
      end if;
   end ReLU_Of;

   --  Same split as the Post on Leaky_ReLU. Zero takes the slope
   --  branch, and the slope times zero is zero.
   function Leaky_Of (X, Slope : Float) return Float
     with Pre  => Slope >= 0.0 and then Slope <= 1.0,
          Post => Leaky_Of'Result =
            (if X > 0.0 then X else Slope * X)
   is
   begin
      if X > 0.0 then
         return X;
      else
         return Slope * X;
      end if;
   end Leaky_Of;

   --  Length check in both directions. Indexing only the shorter side
   --  would ignore a longer operand. Assigning one array onto the
   --  other's bounds raises Constraint_Error either way.
   function Checked_Length (Wanted, Given : Extent) return Extent
     with Pre  => Wanted = Given,
          Post => Checked_Length'Result = Wanted
   is
      Pattern : constant Element_Array (1 .. Given) := (others => 0.0);
      Fitted  : constant Element_Array (1 .. Wanted) := Pattern;
   begin
      return Fitted'Length;
   end Checked_Length;

   function Zero_Vector (N : Extent) return Vector is
     (Length => N, Data => (others => 0.0))
     with Post => Zero_Vector'Result.Length = N
       and then (for all I in 1 .. N =>
         Zero_Vector'Result.Data (I) = 0.0);

   function Zero_Matrix (R, C : Extent) return Matrix is
     (Rows => R, Cols => C, Data => (others => (others => 0.0)))
     with Post => Zero_Matrix'Result.Rows = R
       and then Zero_Matrix'Result.Cols = C;

   function Dot (Left, Right : Vector) return Float is
      Shared : constant Extent :=
        Checked_Length (Left.Length, Right.Length);
      Acc : Float := 0.0;
   begin
      for I in 1 .. Shared loop
         Acc := Acc_Step
           (Acc, Bounded_Mul (Left.Data (I), Right.Data (I)), I);
         pragma Loop_Invariant
           (abs Acc <= Float (I) * (Acc_Slack * Product_Bound));
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
               Acc := Acc_Step
                 (Acc, Bounded_Mul (A.Data (R, C), V.Data (C)), C);
               pragma Loop_Invariant
                 (abs Acc <= Float (C) * (Acc_Slack * Product_Bound));
            end loop;
            Result.Data (R) := Acc;
         end;
         pragma Loop_Invariant (Result.Length = A.Rows);
         pragma Loop_Invariant
           (for all I in 1 .. R => abs Result.Data (I) <= Acc_Bound);
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
                  Acc := Acc_Step
                    (Acc,
                     Bounded_Mul (Left.Data (R, K), Right.Data (K, C)),
                     K);
                  pragma Loop_Invariant
                    (abs Acc <= Float (K) * (Acc_Slack * Product_Bound));
               end loop;
               Result.Data (R, C) := Acc;
            end;
            pragma Loop_Invariant
              (for all J in 1 .. C =>
                 abs Result.Data (R, J) <= Acc_Bound);
         end loop;
         pragma Loop_Invariant (Result.Rows = Left.Rows);
         pragma Loop_Invariant (Result.Cols = Right.Cols);
         pragma Loop_Invariant
           (for all I in 1 .. R =>
             (for all J in 1 .. Result.Cols =>
                abs Result.Data (I, J) <= Acc_Bound));
      end loop;
      return Result;
   end Mat_Mat;

   function Add (Left, Right : Vector) return Vector is
      Shared : constant Extent :=
        Checked_Length (Left.Length, Right.Length);
      Result : Vector := Zero_Vector (Shared);
   begin
      for I in 1 .. Shared loop
         Result.Data (I) :=
           Bounded_Add (Left.Data (I), Right.Data (I));
         pragma Loop_Invariant (Result.Length = Shared);
         pragma Loop_Invariant
           (for all J in 1 .. I =>
              Result.Data (J) = Left.Data (J) + Right.Data (J));
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
            Result.Data (R, C) :=
              Bounded_Add (Left.Data (R, C), Right.Data (R, C));
            pragma Loop_Invariant
              (for all J in 1 .. C =>
                 Result.Data (R, J) =
                   Left.Data (R, J) + Right.Data (R, J));
         end loop;
         pragma Loop_Invariant (Result.Rows = Shared_Rows);
         pragma Loop_Invariant (Result.Cols = Shared_Cols);
         pragma Loop_Invariant
           (for all I in 1 .. R =>
             (for all J in 1 .. Shared_Cols =>
                Result.Data (I, J) =
                  Left.Data (I, J) + Right.Data (I, J)));
      end loop;
      return Result;
   end Add;

   function Scale (V : Vector; Factor : Float) return Vector is
      Result : Vector := Zero_Vector (V.Length);
   begin
      for I in 1 .. Result.Length loop
         Result.Data (I) := Bounded_Mul (V.Data (I), Factor);
         pragma Loop_Invariant (Result.Length = V.Length);
         pragma Loop_Invariant
           (for all J in 1 .. I =>
              Result.Data (J) = V.Data (J) * Factor);
      end loop;
      return Result;
   end Scale;

   function Scale (A : Matrix; Factor : Float) return Matrix is
      Result : Matrix := Zero_Matrix (A.Rows, A.Cols);
   begin
      for R in 1 .. Result.Rows loop
         for C in 1 .. Result.Cols loop
            Result.Data (R, C) := Bounded_Mul (A.Data (R, C), Factor);
            pragma Loop_Invariant
              (for all J in 1 .. C =>
                 Result.Data (R, J) = A.Data (R, J) * Factor);
         end loop;
         pragma Loop_Invariant (Result.Rows = A.Rows);
         pragma Loop_Invariant (Result.Cols = A.Cols);
         pragma Loop_Invariant
           (for all I in 1 .. R =>
             (for all J in 1 .. A.Cols =>
                Result.Data (I, J) = A.Data (I, J) * Factor));
      end loop;
      return Result;
   end Scale;

   function Transpose (A : Matrix) return Matrix is
      Result : Matrix := Zero_Matrix (A.Cols, A.Rows);
   begin
      for R in 1 .. A.Rows loop
         for C in 1 .. A.Cols loop
            Result.Data (C, R) := A.Data (R, C);
            pragma Loop_Invariant
              (for all K in 1 .. C =>
                 Result.Data (K, R) = A.Data (R, K));
         end loop;
         pragma Loop_Invariant (Result.Rows = A.Cols);
         pragma Loop_Invariant (Result.Cols = A.Rows);
         pragma Loop_Invariant
           (for all I in 1 .. R =>
             (for all J in 1 .. A.Cols =>
                Result.Data (J, I) = A.Data (I, J)));
      end loop;
      return Result;
   end Transpose;

   function ReLU (V : Vector) return Vector is
      Result : Vector := Zero_Vector (V.Length);
   begin
      for I in 1 .. Result.Length loop
         Result.Data (I) := ReLU_Of (V.Data (I));
         pragma Loop_Invariant (Result.Length = V.Length);
         pragma Loop_Invariant
           (for all J in 1 .. I =>
              Result.Data (J) =
                (if V.Data (J) > 0.0 then V.Data (J) else 0.0));
      end loop;
      return Result;
   end ReLU;

   function Leaky_ReLU (V : Vector; Slope : Float) return Vector is
      Result : Vector := Zero_Vector (V.Length);
   begin
      for I in 1 .. Result.Length loop
         Result.Data (I) := Leaky_Of (V.Data (I), Slope);
         pragma Loop_Invariant (Result.Length = V.Length);
         pragma Loop_Invariant
           (for all J in 1 .. I =>
              Result.Data (J) =
                (if V.Data (J) > 0.0 then V.Data (J)
                 else Slope * V.Data (J)));
      end loop;
      return Result;
   end Leaky_ReLU;

   function Sigmoid (V : Vector) return Vector is
      Result : Vector := Zero_Vector (V.Length);
   begin
      for I in 1 .. Result.Length loop
         Result.Data (I) := Sigmoid_Of (V.Data (I));
         pragma Loop_Invariant (Result.Length = V.Length);
         pragma Loop_Invariant
           (for all J in 1 .. I =>
              Result.Data (J) >= 0.0 and then Result.Data (J) <= 1.0);
      end loop;
      return Result;
   end Sigmoid;

   function Tanh (V : Vector) return Vector is
      Result : Vector := Zero_Vector (V.Length);
   begin
      for I in 1 .. Result.Length loop
         Result.Data (I) := Tanh_Of (V.Data (I));
         pragma Loop_Invariant (Result.Length = V.Length);
         pragma Loop_Invariant
           (for all J in 1 .. I =>
              Result.Data (J) >= -1.0 and then Result.Data (J) <= 1.0);
      end loop;
      return Result;
   end Tanh;

   function Softmax (V : Vector) return Vector is
      Result : Vector := Zero_Vector (V.Length);
      Peak   : Float;
      Peak_At : Positive := 1;
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
            Peak_At := I;
         end if;
         pragma Loop_Invariant (Peak_At in 1 .. I);
         pragma Loop_Invariant (Peak = V.Data (Peak_At));
         pragma Loop_Invariant (abs Peak <= Logit_Bound);
         pragma Loop_Invariant
           (for all J in 1 .. I => V.Data (J) <= Peak);
      end loop;

      for I in 1 .. V.Length loop
         if I = Peak_At then
            --  exp(0) is 1. The series returns 1 there as well.
            --  Writing 1 makes the sum at least 1, so the division
            --  below is not a division by zero.
            Lifted (I) := 1.0;
         else
            Lifted (I) := Exp_Clamped (V.Data (I) - Peak);
         end if;
         Sum := Sum_Step (Sum, Lifted (I), I);
         pragma Loop_Invariant (Peak_At in 1 .. V.Length);
         pragma Loop_Invariant (Peak = V.Data (Peak_At));
         pragma Loop_Invariant (Sum >= 0.0);
         pragma Loop_Invariant
           (for all J in 1 .. I =>
              Lifted (J) >= 0.0 and then Lifted (J) <= Sum);
         pragma Loop_Invariant (if I >= Peak_At then Sum >= 1.0);
         pragma Loop_Invariant
           (Sum <= Float (I) * (Acc_Slack * Exp_Ceiling));
      end loop;

      for I in 1 .. V.Length loop
         Result.Data (I) := Lifted (I) / Sum;
         pragma Loop_Invariant (Sum >= 1.0);
         pragma Loop_Invariant
           (for all J in 1 .. V.Length =>
              Lifted (J) >= 0.0 and then Lifted (J) <= Sum);
         pragma Loop_Invariant
           (for all J in 1 .. I =>
              Result.Data (J) >= 0.0 and then Result.Data (J) <= 1.0);
      end loop;
      return Result;
   end Softmax;

begin
   pragma Assert
     (Float (Max_Extent) * (Acc_Slack * Product_Bound) <= Acc_Bound);
   pragma Assert (Acc_Bound < Float'Last);
   pragma Assert (2.0 * Logit_Bound < Float'Last);
   pragma Assert
     (Float (Max_Extent) * (Acc_Slack * Exp_Ceiling) <= Softmax_Sum_Bound);
   pragma Assert (Softmax_Sum_Bound < Float'Last);
   pragma Assert (Series_Bound * Scale_Limit <= Exp_Ceiling);
end AI_Amplifier.Tensors;
