--  Item 2. The splash hello already checks: 6 nodes, and
--  node 1 sits at x = 180. The picture also has 8 edges and
--  56 points. A bad index reads as 0. One tick advances the
--  frame from 0 to 1.
with Ada.Text_IO;
with AI_Amplifier.Splash;

procedure Item_02
  with SPARK_Mode => Off
is
   package S renames AI_Amplifier.Splash;
begin
   S.Reset;
   pragma Assert (S.Frame = 0);
   pragma Assert (S.Count (0) = 6);
   pragma Assert (S.Count (1) = 8);
   pragma Assert (S.Count (2) = 56);
   pragma Assert (S.Count (3) = 0);
   pragma Assert (S.Get (0, 1, 0) = 180);
   pragma Assert (S.Get (0, 0, 0) = 0);
   pragma Assert (S.Get (9, 1, 0) = 0);
   S.Tick;
   pragma Assert (S.Frame = 1);
   Ada.Text_IO.Put_Line ("item 02 pass");
end Item_02;
