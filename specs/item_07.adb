--  Item 7. The bounds the tensor proof uses, and the
--  component rules tensors_test checks for Add, Scale,
--  ReLU, and Transpose. This file does not run GNATprove.
--  The tensor proof for this item is proof/item_07.out.
with Ada.Text_IO;
with AI_Amplifier.Tensors;

procedure Item_07
  with SPARK_Mode => Off
is
   package T renames AI_Amplifier.Tensors;

   function V3 (A, B, C : Float) return T.Vector is
     (Length => 3, Data => (A, B, C));

   Summed : constant T.Vector :=
     T.Add (V3 (1.0, 2.0, 3.0), V3 (3.0, 4.0, 5.0));
   Scaled : constant T.Vector := T.Scale (V3 (1.0, -2.0, 3.0), 2.0);
   Relu   : constant T.Vector := T.ReLU (V3 (-1.0, 0.0, 2.5));
   A      : constant T.Matrix :=
     (Rows => 2, Cols => 3, Data => ((1.0, 2.0, 3.0), (4.0, 5.0, 6.0)));
   B      : constant T.Matrix := T.Transpose (A);
   Zero   : constant T.Vector := T.Sigmoid (V3 (0.0, 40.0, -40.0));
   Third  : constant Float := 1.0 / 3.0;
   Soft   : constant T.Vector := T.Softmax (V3 (0.0, 0.0, 0.0));

   function Near (Got, Want : Float) return Boolean is
      Diff : Float := Got - Want;
   begin
      if Diff < 0.0 then
         Diff := -Diff;
      end if;
      return Diff <= 0.000_05;
   end Near;
   One : constant Float := 1.0E18;
   Two : constant Float := 2.0E36;
   Acc : constant Float := 2.0E38;
   Log : constant Float := 1.0E38;
begin
   pragma Assert (T.Max_Extent = 32);
   pragma Assert (T.Summand_Bound = One);
   pragma Assert (T.Product_Bound = Two);
   pragma Assert (T.Acc_Bound = Acc);
   pragma Assert (T.Logit_Bound = Log);
   pragma Assert (Summed.Data (1) = 4.0);
   pragma Assert (Summed.Data (2) = 6.0);
   pragma Assert (Summed.Data (3) = 8.0);
   pragma Assert (Scaled.Data (1) = 2.0);
   pragma Assert (Scaled.Data (2) = -4.0);
   pragma Assert (Scaled.Data (3) = 6.0);
   pragma Assert (Relu.Data (1) = 0.0);
   pragma Assert (Relu.Data (2) = 0.0);
   pragma Assert (Relu.Data (3) = 2.5);
   pragma Assert (B.Rows = 3 and then B.Cols = 2);
   pragma Assert (B.Data (1, 1) = 1.0);
   pragma Assert (B.Data (1, 2) = 4.0);
   pragma Assert (B.Data (3, 1) = 3.0);
   pragma Assert (B.Data (3, 2) = 6.0);
   pragma Assert (Near (Zero.Data (1), 0.5));
   pragma Assert (Near (Zero.Data (2), 1.0));
   pragma Assert (Near (Zero.Data (3), 0.0));
   pragma Assert (Near (Soft.Data (1), Third));
   pragma Assert (Near (Soft.Data (3), Third));
   Ada.Text_IO.Put_Line ("item 07 pass");
end Item_07;
