--  Vectors, matrices, and the kernels under them.
--
--  This unit is SPARK. Levels, in short (the README table is the
--  full list):
--
--  Silver. Dot, Mat_Vec, Mat_Mat. No run-time error. Each numeric
--  result lies in [-Acc_Bound, Acc_Bound]. The proof does not say
--  the value equals the mathematical product.
--  Gold. Add, Scale, Transpose, ReLU, Leaky_ReLU. The Post is the
--  component rule.
--  Silver. Sigmoid, Tanh, Softmax. Each result component lies in
--  the range in the Post, and the arithmetic does not overflow.
--  The series is not proved equal to the real exponential.
--
--  Summand_Bound is 1.0E18. The float value of that literal is a
--  little under 1.0E18. Its real square is a little over the float
--  value of 1.0E36, so Product_Bound is 2.0E36, which is above that
--  square. Max_Extent is 32. Acc_Slack is 2, so the loop invariant
--  allows I * 2 * Product_Bound. That slack is why a Float rounding
--  ulp does not fail the check. 32 * 2 * 2.0E36 is 1.28E38.
--  Acc_Bound is 2.0E38: above that product, and below Float'Last
--  (about 3.4E38). The precondition is what keeps a sum of products
--  from overflowing. The MLP, the attention block, and the page
--  demos stay far inside it.
--
--  Logit_Bound is 1.0E38. Softmax subtracts two components. Twice
--  that bound is about 2.0E38, still below Float'Last, so the
--  subtraction cannot overflow. The large-logit test uses 1.0E20.
--
--  A softmax sum adds at most Max_Extent exponentials, each at most
--  Exp_Ceiling (4.0E36). The running bound uses Acc_Slack, so it is
--  32 * 2 * 4.0E36 = 2.56E38. A tight Step * Exp_Ceiling comparison
--  is one ulp short in Float after several additions. Softmax_Sum_Bound
--  is 3.0E38: above 2.56E38, and below Float'Last.
--
--  Elements are Float (IEEE binary32 on this GNAT). A shape is a
--  discriminant: Vector.Length, or Matrix.Rows and Matrix.Cols.
--  Components live at 1 .. that bound. A larger discriminant fails
--  the range check on Extent. Length 0 is a value, not a mismatch.
--
--  Where two shapes must agree, the precondition says so, and the
--  body also assigns one array onto the other's index range. That
--  assignment is a length check. With the assertion policy here,
--  the precondition is checked first (Assertion_Error).
--
--  MLP, the tokenizer, attention, the splash, and the page wrappers
--  are plain Ada (SPARK_Mode off). They are not part of this proof.
package AI_Amplifier.Tensors
  with SPARK_Mode
is

   pragma Assertion_Policy (Pre => Check, Post => Check);

   Max_Extent : constant := 32;

   subtype Extent is Natural range 0 .. Max_Extent;

   --  See the package comment for why these are the values they are.
   Summand_Bound     : constant Float := 1.0E18;
   Product_Bound     : constant Float := 2.0E36;
   Acc_Slack         : constant Float := 2.0;
   Acc_Bound         : constant Float := 2.0E38;
   Logit_Bound       : constant Float := 1.0E38;
   Exp_Ceiling       : constant Float := 4.0E36;
   Softmax_Sum_Bound : constant Float := 3.0E38;

   type Element_Array is array (Positive range <>) of Float;

   type Element_Grid is
     array (Positive range <>, Positive range <>) of Float;

   type Vector (Length : Extent := 0) is record
      Data : Element_Array (1 .. Length);
   end record;

   type Matrix (Rows, Cols : Extent := 0) is record
      Data : Element_Grid (1 .. Rows, 1 .. Cols);
   end record;

   function Within_Bound (V : Vector; Bound : Float) return Boolean is
     (for all I in 1 .. V.Length => abs V.Data (I) <= Bound);

   function Within_Bound (A : Matrix; Bound : Float) return Boolean is
     (for all R in 1 .. A.Rows =>
        (for all C in 1 .. A.Cols => abs A.Data (R, C) <= Bound));

   function Dot (Left, Right : Vector) return Float
     with Pre  => Left.Length = Right.Length
       and then Within_Bound (Left, Summand_Bound)
       and then Within_Bound (Right, Summand_Bound),
          Post => abs Dot'Result <= Acc_Bound;

   function Mat_Vec (A : Matrix; V : Vector) return Vector
     with Pre  => A.Cols = V.Length
       and then Within_Bound (A, Summand_Bound)
       and then Within_Bound (V, Summand_Bound),
          Post => Mat_Vec'Result.Length = A.Rows
            and then (for all I in 1 .. A.Rows =>
              abs Mat_Vec'Result.Data (I) <= Acc_Bound);

   function Mat_Mat (Left, Right : Matrix) return Matrix
     with Pre  => Left.Cols = Right.Rows
       and then Within_Bound (Left, Summand_Bound)
       and then Within_Bound (Right, Summand_Bound),
          Post => Mat_Mat'Result.Rows = Left.Rows
            and then Mat_Mat'Result.Cols = Right.Cols
            and then (for all R in 1 .. Left.Rows =>
              (for all C in 1 .. Right.Cols =>
                 abs Mat_Mat'Result.Data (R, C) <= Acc_Bound));

   function Add (Left, Right : Vector) return Vector
     with Pre  => Left.Length = Right.Length
       and then Within_Bound (Left, Summand_Bound)
       and then Within_Bound (Right, Summand_Bound),
          Post => Add'Result.Length = Left.Length
            and then (for all I in 1 .. Left.Length =>
              Add'Result.Data (I) = Left.Data (I) + Right.Data (I));

   function Add (Left, Right : Matrix) return Matrix
     with Pre  => Left.Rows = Right.Rows
       and then Left.Cols = Right.Cols
       and then Within_Bound (Left, Summand_Bound)
       and then Within_Bound (Right, Summand_Bound),
          Post => Add'Result.Rows = Left.Rows
            and then Add'Result.Cols = Left.Cols
            and then (for all R in 1 .. Left.Rows =>
              (for all C in 1 .. Left.Cols =>
                 Add'Result.Data (R, C) =
                   Left.Data (R, C) + Right.Data (R, C)));

   function Scale (V : Vector; Factor : Float) return Vector
     with Pre  => Within_Bound (V, Summand_Bound)
       and then abs Factor <= Summand_Bound,
          Post => Scale'Result.Length = V.Length
            and then (for all I in 1 .. V.Length =>
              Scale'Result.Data (I) = V.Data (I) * Factor);

   function Scale (A : Matrix; Factor : Float) return Matrix
     with Pre  => Within_Bound (A, Summand_Bound)
       and then abs Factor <= Summand_Bound,
          Post => Scale'Result.Rows = A.Rows
            and then Scale'Result.Cols = A.Cols
            and then (for all R in 1 .. A.Rows =>
              (for all C in 1 .. A.Cols =>
                 Scale'Result.Data (R, C) = A.Data (R, C) * Factor));

   function Transpose (A : Matrix) return Matrix
     with Post => Transpose'Result.Rows = A.Cols
       and then Transpose'Result.Cols = A.Rows
       and then (for all R in 1 .. A.Rows =>
         (for all C in 1 .. A.Cols =>
            Transpose'Result.Data (C, R) = A.Data (R, C)));

   function ReLU (V : Vector) return Vector
     with Post => ReLU'Result.Length = V.Length
       and then (for all I in 1 .. V.Length =>
         ReLU'Result.Data (I) =
           (if V.Data (I) > 0.0 then V.Data (I) else 0.0));

   --  The page uses this slope. 0 is ReLU. 1 copies the vector.
   --  A slope outside [0.0, 1.0] is rejected by Leaky_ReLU's Pre.
   Negative_Slope : constant Float := 0.01;

   --  A positive component passes through. Any other component is
   --  multiplied by Slope. An empty vector stays empty. The Post is
   --  that rule. It is the Gold contract for this kernel.
   function Leaky_ReLU (V : Vector; Slope : Float) return Vector
     with Pre  => Slope >= 0.0 and then Slope <= 1.0,
          Post => Leaky_ReLU'Result.Length = V.Length
            and then (for all I in 1 .. V.Length =>
              Leaky_ReLU'Result.Data (I) =
                (if V.Data (I) > 0.0 then V.Data (I)
                 else Slope * V.Data (I)));

   function Sigmoid (V : Vector) return Vector
     with Post => Sigmoid'Result.Length = V.Length
       and then (for all I in 1 .. V.Length =>
         Sigmoid'Result.Data (I) >= 0.0
           and then Sigmoid'Result.Data (I) <= 1.0);

   function Tanh (V : Vector) return Vector
     with Post => Tanh'Result.Length = V.Length
       and then (for all I in 1 .. V.Length =>
         Tanh'Result.Data (I) >= -1.0
           and then Tanh'Result.Data (I) <= 1.0);

   --  Subtracts the largest component before the exponential, so a
   --  large logit does not overflow the series. The Pre keeps the
   --  subtraction itself inside Float. An empty vector stays empty:
   --  there is nothing to divide by. Each result component lies in
   --  [0.0, 1.0]. That range is the Silver contract. It is not a
   --  claim that the value equals the real softmax.
   function Softmax (V : Vector) return Vector
     with Pre  => Within_Bound (V, Logit_Bound),
          Post => Softmax'Result.Length = V.Length
            and then (for all I in 1 .. V.Length =>
              Softmax'Result.Data (I) >= 0.0
                and then Softmax'Result.Data (I) <= 1.0);

end AI_Amplifier.Tensors;
