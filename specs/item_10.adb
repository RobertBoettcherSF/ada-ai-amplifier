--  Item 10. The XOR speed yardstick: 95 steps, 8 repeats,
--  loss under 0.05, class bounds 0.8 and 0.2, and the
--  recorded clocks 33044 and 10162. A counted baseline
--  passes. Code 4, the short run, does not.
with Ada.Text_IO;
with AI_Amplifier.MLP.Speed;

procedure Item_10
  with SPARK_Mode => Off
is
   package S renames AI_Amplifier.MLP.Speed;
begin
   pragma Assert (S.Published_Steps = 95);
   pragma Assert (S.Repeats = 8);
   pragma Assert (S.Loss_Max = 0.05);
   pragma Assert (S.High_Min = 0.8);
   pragma Assert (S.Low_Max = 0.2);
   pragma Assert (S.Rate = 1.0);
   pragma Assert (S.Published_Native_Us = 33_044);
   pragma Assert (S.Published_Wasm_Us = 10_162);
   S.Prepare (1);
   S.Execute;
   S.Note_Cpu_Microseconds (1);
   pragma Assert (S.Counted = 1);
   pragma Assert (S.Reason_Code = 1);
   pragma Assert (S.Step_Count = 95);
   pragma Assert (S.Repeat_Count = 8);
   pragma Assert (S.Loss < 0.05);
   pragma Assert (S.Answer (1) <= 0.2);
   pragma Assert (S.Answer (2) >= 0.8);
   pragma Assert (S.Answer (4) <= 0.2);
   S.Prepare (4);
   S.Execute;
   S.Note_Cpu_Microseconds (1);
   pragma Assert (S.Counted = 0);
   pragma Assert (S.Reason_Code = 4);
   Ada.Text_IO.Put_Line ("item 10 pass");
end Item_10;
