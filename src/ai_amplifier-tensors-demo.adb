package body AI_Amplifier.Tensors.Demo
  with SPARK_Mode => Off
is

   --  The starting point the page shows before anyone edits a box.
   --    | 1 2 3 |   | 1 |   | 14 |
   --    | 0 1 4 | * | 2 | = | 14 |
   --    | 5 6 0 |   | 3 |   | 17 |
   --  Softmax is then applied to (14, 14, 17).
   A : Matrix (3, 3) :=
     (Rows => 3,
      Cols => 3,
      Data => ((1.0, 2.0, 3.0), (0.0, 1.0, 4.0), (5.0, 6.0, 0.0)));

   V : Vector (3) := (Length => 3, Data => (1.0, 2.0, 3.0));

   Y : Vector (3) := (Length => 3, Data => (0.0, 0.0, 0.0));

   P : Vector (3) := (Length => 3, Data => (0.0, 0.0, 0.0));

   function In_Shape (Index, Bound : Integer) return Boolean is
     (Index >= 1 and then Index <= Bound);

   procedure Set_Matrix (Row, Col : Integer; Value : Float) is
   begin
      if In_Shape (Row, A.Rows) and then In_Shape (Col, A.Cols) then
         A.Data (Row, Col) := Value;
      end if;
   end Set_Matrix;

   function Get_Matrix (Row, Col : Integer) return Float is
   begin
      if not In_Shape (Row, A.Rows) or else not In_Shape (Col, A.Cols) then
         return 0.0;
      end if;
      return A.Data (Row, Col);
   end Get_Matrix;

   procedure Set_Vector (Index : Integer; Value : Float) is
   begin
      if In_Shape (Index, V.Length) then
         V.Data (Index) := Value;
      end if;
   end Set_Vector;

   function Get_Vector (Index : Integer) return Float is
   begin
      if not In_Shape (Index, V.Length) then
         return 0.0;
      end if;
      return V.Data (Index);
   end Get_Vector;

   procedure Run is
   begin
      Y := Mat_Vec (A, V);
      P := Softmax (Y);
   end Run;

   function Product (Index : Integer) return Float is
   begin
      if not In_Shape (Index, Y.Length) then
         return 0.0;
      end if;
      return Y.Data (Index);
   end Product;

   function Chance (Index : Integer) return Float is
   begin
      if not In_Shape (Index, P.Length) then
         return 0.0;
      end if;
      return P.Data (Index);
   end Chance;

end AI_Amplifier.Tensors.Demo;
