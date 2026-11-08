--  Item 6. Leaky ReLU at slope 0.01 on (-2, 0, 3), the
--  page wrapper's starting output, and Assertion_Error
--  for slopes -0.1 and 1.5. tensors_test checks these.
with Ada.Assertions;
with Ada.Text_IO;
with AI_Amplifier.Tensors;
with AI_Amplifier.Tensors.Leaky_Demo;

procedure Item_06
  with SPARK_Mode => Off
is
   package T renames AI_Amplifier.Tensors;
   package D renames AI_Amplifier.Tensors.Leaky_Demo;

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

   Inp : constant T.Vector := V3 (-2.0, 0.0, 3.0);
   R   : constant T.Vector := T.Leaky_ReLU (Inp, T.Negative_Slope);

   procedure Rejects (Slope : Float) is
      Raised : Boolean := False;
   begin
      begin
         declare
            Bad : constant T.Vector :=
              T.Leaky_ReLU (V3 (-1.0, 0.0, 1.0), Slope);
         begin
            pragma Assert (Bad.Length = 3);
            Raised := False;
         end;
      exception
         when Ada.Assertions.Assertion_Error =>
            Raised := True;
      end;
      pragma Assert (Raised);
   end Rejects;
begin
   pragma Assert (Near (T.Negative_Slope, 0.01));
   pragma Assert (R.Length = 3);
   pragma Assert (Near (R.Data (1), T.Negative_Slope * (-2.0)));
   pragma Assert (R.Data (2) = 0.0);
   pragma Assert (R.Data (3) = 3.0);
   pragma Assert (T.Leaky_ReLU (Inp, 0.0).Data (1) = 0.0);
   pragma Assert (T.Leaky_ReLU (Inp, 0.0).Data (3) = 3.0);
   pragma Assert (T.Leaky_ReLU (Inp, 1.0).Data (1) = -2.0);
   pragma Assert (T.Leaky_ReLU (Inp, 1.0).Data (3) = 3.0);
   Rejects (-0.1);
   Rejects (1.5);
   D.Run;
   pragma Assert (D.Slope = T.Negative_Slope);
   pragma Assert (Near (D.Output (1), T.Negative_Slope * (-2.0)));
   pragma Assert (D.Output (2) = 0.0);
   pragma Assert (D.Output (3) = 3.0);
   pragma Assert (D.Output (0) = 0.0);
   pragma Assert (D.Output (4) = 0.0);
   Ada.Text_IO.Put_Line ("item 06 pass");
end Item_06;
