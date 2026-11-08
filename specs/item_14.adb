--  Item 14. One solver, four harnesses, seed 20261104.
--  The table harness_test checks: 1 of 8, 2 of 8, 8 of 8,
--  5 of 8, with step counts 8, 10, 25, 18 and wrong
--  answers kept 7, 6, 0, 0. Fibonacci answers are 1, 2, 3, 8.
with Ada.Text_IO;
with AI_Amplifier.Harness;

procedure Item_14
  with SPARK_Mode => Off
is
   package H renames AI_Amplifier.Harness;

   Bank : H.Table;
begin
   pragma Assert (H.Seed = 20261104);
   pragma Assert (H.Task_Count = 8);
   pragma Assert (H.Harness_Count = 4);
   pragma Assert (H.Expected_Answer (1) = 1);
   pragma Assert (H.Expected_Answer (2) = 2);
   pragma Assert (H.Expected_Answer (3) = 3);
   pragma Assert (H.Expected_Answer (4) = 8);
   H.Run_Table (Bank);
   pragma Assert (Bank (H.One_Shot).Solved = 1);
   pragma Assert (Bank (H.One_Shot).Steps = 8);
   pragma Assert (Bank (H.One_Shot).Wrong = 7);
   pragma Assert (Bank (H.Retry).Solved = 2);
   pragma Assert (Bank (H.Retry).Steps = 10);
   pragma Assert (Bank (H.Retry).Wrong = 6);
   pragma Assert (Bank (H.Checked).Solved = 8);
   pragma Assert (Bank (H.Checked).Steps = 25);
   pragma Assert (Bank (H.Checked).Wrong = 0);
   pragma Assert (Bank (H.Budgeted).Solved = 5);
   pragma Assert (Bank (H.Budgeted).Steps = 18);
   pragma Assert (Bank (H.Budgeted).Wrong = 0);
   Ada.Text_IO.Put_Line ("item 14 pass");
end Item_14;
