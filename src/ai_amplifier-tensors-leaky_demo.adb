package body AI_Amplifier.Tensors.Leaky_Demo
  with SPARK_Mode => Off
is

   --  The starting point the page shows before anyone edits a box.
   --  (-2, 0, 3) at slope 0.01 is (-0.02, 0, 3).
   V : Vector (3) := (Length => 3, Data => (-2.0, 0.0, 3.0));

   Y : Vector (3) := (Length => 3, Data => (0.0, 0.0, 0.0));

   function In_Shape (Index, Bound : Integer) return Boolean is
     (Index >= 1 and then Index <= Bound);

   procedure Set_Input (Index : Integer; Value : Float) is
   begin
      if In_Shape (Index, V.Length) then
         V.Data (Index) := Value;
      end if;
   end Set_Input;

   function Get_Input (Index : Integer) return Float is
   begin
      if not In_Shape (Index, V.Length) then
         return 0.0;
      end if;
      return V.Data (Index);
   end Get_Input;

   procedure Run is
   begin
      Y := Leaky_ReLU (V, Negative_Slope);
   end Run;

   function Output (Index : Integer) return Float is
   begin
      if not In_Shape (Index, Y.Length) then
         return 0.0;
      end if;
      return Y.Data (Index);
   end Output;

   function Slope return Float is (Negative_Slope);

end AI_Amplifier.Tensors.Leaky_Demo;
