--  Vectors, matrices, and the small kernels under them.
--
--  Plain Ada on purpose (SPARK_Mode off). The contracts below are
--  ordinary Pre and Post, checked at run time. They are not a proof.
--  SPARK proofs of these kernels are a later backlog item.
--  AI_Amplifier.Version stays in SPARK; this unit does not.
--
--  Elements are Float (IEEE binary32 on this GNAT). A shape is a
--  discriminant, so it travels with the value:
--    Vector.Length
--    Matrix.Rows, Matrix.Cols
--  The components live at 1 .. that bound. Max_Extent is 32. A larger
--  discriminant fails the range check on Extent. Length 0 is a value
--  (an empty vector, or a matrix with a zero side), not a mismatch.
--
--  Where two shapes must agree, the precondition says so, and the body
--  also assigns one array onto the other's index range. That assignment
--  is a length check: too short and too long both raise, so a spare
--  component is not silently dropped. With the assertion policy in this
--  unit, the precondition is checked first (Assertion_Error). The length
--  check is what remains if that policy is ignored (Constraint_Error).
package AI_Amplifier.Tensors
  with SPARK_Mode => Off
is

   pragma Assertion_Policy (Pre => Check, Post => Check);

   Max_Extent : constant := 32;

   subtype Extent is Natural range 0 .. Max_Extent;

   type Element_Array is array (Positive range <>) of Float;

   type Element_Grid is
     array (Positive range <>, Positive range <>) of Float;

   type Vector (Length : Extent := 0) is record
      Data : Element_Array (1 .. Length);
   end record;

   type Matrix (Rows, Cols : Extent := 0) is record
      Data : Element_Grid (1 .. Rows, 1 .. Cols);
   end record;

   function Dot (Left, Right : Vector) return Float
     with Pre => Left.Length = Right.Length;

   function Mat_Vec (A : Matrix; V : Vector) return Vector
     with Pre  => A.Cols = V.Length,
          Post => Mat_Vec'Result.Length = A.Rows;

   function Mat_Mat (Left, Right : Matrix) return Matrix
     with Pre  => Left.Cols = Right.Rows,
          Post => Mat_Mat'Result.Rows = Left.Rows
            and then Mat_Mat'Result.Cols = Right.Cols;

   function Add (Left, Right : Vector) return Vector
     with Pre  => Left.Length = Right.Length,
          Post => Add'Result.Length = Left.Length;

   function Add (Left, Right : Matrix) return Matrix
     with Pre  => Left.Rows = Right.Rows and then Left.Cols = Right.Cols,
          Post => Add'Result.Rows = Left.Rows
            and then Add'Result.Cols = Left.Cols;

   function Scale (V : Vector; Factor : Float) return Vector
     with Post => Scale'Result.Length = V.Length;

   function Scale (A : Matrix; Factor : Float) return Matrix
     with Post => Scale'Result.Rows = A.Rows
       and then Scale'Result.Cols = A.Cols;

   function Transpose (A : Matrix) return Matrix
     with Post => Transpose'Result.Rows = A.Cols
       and then Transpose'Result.Cols = A.Rows;

   function ReLU (V : Vector) return Vector
     with Post => ReLU'Result.Length = V.Length;

   function Sigmoid (V : Vector) return Vector
     with Post => Sigmoid'Result.Length = V.Length;

   function Tanh (V : Vector) return Vector
     with Post => Tanh'Result.Length = V.Length;

   --  Subtracts the largest component before the exponential, so a
   --  large logit does not overflow. An empty vector stays empty:
   --  there is nothing to divide by.
   function Softmax (V : Vector) return Vector
     with Post => Softmax'Result.Length = V.Length;

end AI_Amplifier.Tensors;
