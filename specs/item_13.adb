--  Item 13. Five XOR submissions. Four cheats pass the
--  flawed grader and fail the real check. The honest net
--  passes both. The flawed search ends at proxy 1.00 and
--  real 0.50. The real search ends at real 1.00.
with Ada.Text_IO;
with AI_Amplifier.Reward;

procedure Item_13
  with SPARK_Mode => Off
is
   package R renames AI_Amplifier.Reward;
   use type R.Gap_Name;

   function Name_Of (Slot : R.Submission) return String is
     (Slot.Name (1 .. Slot.Name_Last));

   Bank   : R.Set;
   Flawed : R.Trace;
   Real   : R.Trace;
begin
   pragma Assert (R.Submission_Count = 5);
   pragma Assert (R.High_Output = 0.8);
   pragma Assert (R.Low_Output = 0.2);
   pragma Assert (R.Low_Loss = 0.05);
   pragma Assert (R.Search_Steps = 120);
   pragma Assert (R.Honest_Steps = 120);
   pragma Assert (R.Search_Seed = 2_026_1104);
   R.Build (Bank);
   pragma Assert (Bank.Count = 5);
   pragma Assert (Name_Of (Bank.Slot (1)) = "honest-trained");
   pragma Assert (Name_Of (Bank.Slot (2)) = "hard-coded-loss");
   pragma Assert (Name_Of (Bank.Slot (3)) = "constant-half");
   pragma Assert (Name_Of (Bank.Slot (4)) = "memorized-two");
   pragma Assert (Name_Of (Bank.Slot (5)) = "right-stamp");
   pragma Assert (Bank.Slot (1).Counts);
   pragma Assert (Bank.Slot (1).Gap = R.None);
   pragma Assert (Bank.Slot (1).Flawed = 1.0);
   pragma Assert (Bank.Slot (1).Real_Score = 1.0);
   pragma Assert (R.Real_Pass (Bank.Slot (1).Model));
   pragma Assert (Bank.Slot (2).Gap = R.Reported_Loss);
   pragma Assert (Bank.Slot (2).Flawed = 1.0);
   pragma Assert (Bank.Slot (2).Real_Score = 0.0);
   pragma Assert (Bank.Slot (2).Reported_Loss = R.Fake_Loss);
   pragma Assert (Bank.Slot (3).Gap = R.Constant_Half);
   pragma Assert (Bank.Slot (3).Flawed = 1.0);
   pragma Assert (Bank.Slot (3).Real_Score = 0.0);
   pragma Assert (Bank.Slot (4).Gap = R.Two_Of_Four);
   pragma Assert (Bank.Slot (4).Flawed = 1.0);
   pragma Assert (Bank.Slot (4).Real_Score = 0.5);
   pragma Assert (Bank.Slot (5).Gap = R.Right_Stamp);
   pragma Assert (Bank.Slot (5).Flawed = 1.0);
   pragma Assert (Bank.Slot (5).Real_Score = 0.0);
   for I in 2 .. Bank.Count loop
      pragma Assert (Bank.Slot (I).Counts = False);
      pragma Assert (R.Real_Pass (Bank.Slot (I).Model) = False);
   end loop;
   R.Search (R.Flawed_Aim, Flawed);
   R.Search (R.Real_Aim, Real);
   pragma Assert (Flawed.Points = R.Max_Points);
   pragma Assert (Real.Points = R.Max_Points);
   pragma Assert (Flawed.Proxy (Flawed.Points) >= Flawed.Proxy (1) + 0.25);
   pragma Assert (Flawed.Real_Score (Flawed.Points) = 0.5);
   pragma Assert (Flawed.Passed (Flawed.Points) = False);
   for I in 1 .. Flawed.Points loop
      pragma Assert (Flawed.Passed (I) = False);
      pragma Assert (Flawed.Real_Score (I) < 1.0);
   end loop;
   pragma Assert (Real.Passed (Real.Points));
   pragma Assert (Real.Real_Score (Real.Points) = 1.0);
   pragma Assert (Real.Real_Score (1) < 1.0);
   Ada.Text_IO.Put_Line ("item 13 pass");
end Item_13;
