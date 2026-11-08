--  Item 3. The tensor test's known product, the 2 by 2
--  product, the dot, and the page's 3 by 3 panel.
--  Tolerance is 0.000_05, the same gap tensors_test allows
--  when a Float is not an integer.
with Ada.Text_IO;
with AI_Amplifier.Tensors;
with AI_Amplifier.Tensors.Demo;

procedure Item_03
  with SPARK_Mode => Off
is
   package T renames AI_Amplifier.Tensors;
   package D renames AI_Amplifier.Tensors.Demo;

   function V3 (A, B, C : Float) return T.Vector is
     (Length => 3, Data => (A, B, C));

   function Near (Got, Want : Float) return Boolean is
      Diff : Float := Got - Want;
   begin
      if Diff < 0.0 then
         Diff := -Diff;
      end if;
      return Diff <= 0.000_05;
   end Near;

   A : constant T.Matrix :=
     (Rows => 3,
      Cols => 3,
      Data => ((1.0, 2.0, 3.0), (0.0, 1.0, 4.0), (5.0, 6.0, 0.0)));
   Y : constant T.Vector := T.Mat_Vec (A, V3 (1.0, 2.0, 3.0));
   L : constant T.Matrix :=
     (Rows => 2, Cols => 2, Data => ((1.0, 2.0), (3.0, 4.0)));
   R : constant T.Matrix :=
     (Rows => 2, Cols => 2, Data => ((5.0, 6.0), (7.0, 8.0)));
   P : constant T.Matrix := T.Mat_Mat (L, R);
   Soft : constant T.Vector := T.Softmax (V3 (14.0, 14.0, 17.0));
begin
   pragma Assert (T.Dot (V3 (1.0, 2.0, 3.0), V3 (4.0, 5.0, 6.0)) = 32.0);
   pragma Assert (Y.Length = 3);
   pragma Assert (Y.Data (1) = 14.0);
   pragma Assert (Y.Data (2) = 14.0);
   pragma Assert (Y.Data (3) = 17.0);
   pragma Assert (P.Data (1, 1) = 19.0);
   pragma Assert (P.Data (1, 2) = 22.0);
   pragma Assert (P.Data (2, 1) = 43.0);
   pragma Assert (P.Data (2, 2) = 50.0);
   D.Run;
   pragma Assert (D.Product (1) = 14.0);
   pragma Assert (D.Product (2) = 14.0);
   pragma Assert (D.Product (3) = 17.0);
   pragma Assert (D.Product (0) = 0.0);
   pragma Assert (Near (D.Chance (1), Soft.Data (1)));
   pragma Assert (Near (D.Chance (3), Soft.Data (3)));
   Ada.Text_IO.Put_Line ("item 03 pass");
end Item_03;
