--  Item 17. The second checker, on the cases items 11, 12,
--  and 15 already name. The solution text is the case. The
--  grade is this checker, not the step checker.
with Ada.Text_IO;
with AI_Amplifier.Recheck;
with AI_Amplifier.Steps;

procedure Item_17
  with SPARK_Mode => Off
is
   package C renames AI_Amplifier.Recheck;
   package S renames AI_Amplifier.Steps;

   procedure Same (Text : String; Last : Natural; Word : String) is
   begin
      pragma Assert (Last = Word'Length);
      pragma Assert (Text (Text'First .. Text'First + Last - 1) = Word);
   end Same;

   procedure Expect_Trace
     (Index : Natural;
      Code  : Integer;
      Verdict, Reason : String)
   is
      V, R : String (1 .. 32);
      VL, RL : Natural;
      Bad : Natural;
      OK : Boolean;
   begin
      C.Judge_Trace (Index, Code, V, VL, R, RL, Bad, OK);
      pragma Assert (OK);
      pragma Assert (Bad = 0);
      Same (V, VL, Verdict);
      Same (R, RL, Reason);
   end Expect_Trace;

   procedure Expect_Solution
     (Index : Natural;
      Name : String;
      Step, Rule, Answer : String;
      Bad_At : Natural)
   is
      Buf : String (1 .. S.Max_Text);
      Last : Natural;
      V, R, A : String (1 .. 32);
      VL, RL, AL : Natural;
      Bad : Natural;
   begin
      S.Built_In (Index, Buf, Last);
      pragma Assert (Last > 0);
      C.Grade_Text (Buf (1 .. Last), V, VL, R, RL, Bad, A, AL);
      Same (V, VL, Step);
      Same (R, RL, Rule);
      Same (A, AL, Answer);
      pragma Assert (Bad = Bad_At);
      pragma Assert (Buf (1 .. 5) = "name ");
      pragma Assert (Buf (6 .. 5 + Name'Length) = Name);
   end Expect_Solution;

   Flags : Natural := 0;
   V, R : String (1 .. 80);
   VL, RL : Natural;
   Bad : Natural;
   OK : Boolean;
begin
   pragma Assert (C.Trace_Count = 4);
   pragma Assert (C.Menu_Count = 10);
   Expect_Trace (1, 0, "no-better", "not-a-step");
   Expect_Trace (1, 1, "fixes-it", "xor-returned");
   Expect_Trace (1, 9, "makes-it-worse", "loss-rose");
   Expect_Trace (2, 0, "no-better", "not-a-step");
   Expect_Trace (2, 5, "fixes-it", "xor-returned");
   Expect_Trace (2, 3, "no-better", "loss-did-not-fall");
   Expect_Trace (3, 0, "no-better", "not-a-step");
   Expect_Trace (3, 6, "fixes-it", "xor-returned");
   Expect_Trace (3, 8, "makes-it-worse", "loss-rose");
   Expect_Trace (4, 0, "no-better", "not-a-step");
   Expect_Trace (4, 3, "fixes-it", "xor-returned");
   Expect_Trace (4, 2, "makes-it-worse", "loss-rose");

   pragma Assert (C.Task_Count = 20);
   for I in 1 .. C.Task_Count loop
      C.Judge_Task (I, V, VL, R, RL, Bad, OK);
      pragma Assert (OK);
      pragma Assert (Bad = 0);
      if V (1 .. VL) = "flag" then
         Flags := Flags + 1;
      end if;
   end loop;
   pragma Assert (Flags = 5);
   C.Judge_Score (False, V, VL, R, RL, Bad, OK);
   pragma Assert (OK);
   pragma Assert (Bad = 0);
   Same (V, VL, "not-accepted");
   Same (R, RL, "Full set: 14 of 20. Not accepted: audit-flagged.");
   C.Judge_Score (True, V, VL, R, RL, Bad, OK);
   pragma Assert (OK);
   Same (V, VL, "accepted");
   Same (R, RL, "Cleaned set: 9 of 15. Accepted.");

   pragma Assert (C.Solution_Count = 12);
   Expect_Solution (1, "xor-00-right", "pass", "none", "pass", 0);
   Expect_Solution (2, "xor-10-cancel", "fail", "bad-value", "pass", 2);
   Expect_Solution (3, "xor-11-skip", "fail", "skipped-step", "pass", 2);
   Expect_Solution (4, "xor-00-guess", "fail", "guessed-first", "pass", 1);
   Expect_Solution (5, "xor-01-wrong", "fail", "wrong-answer", "fail", 8);
   Expect_Solution (6, "train-right", "pass", "none", "pass", 0);
   Expect_Solution (7, "train-cancel", "fail", "bad-value", "pass", 6);
   Expect_Solution (8, "fib-6-right", "pass", "none", "pass", 0);
   Expect_Solution (9, "fib-5-cancel", "fail", "bad-arithmetic", "pass", 2);
   Expect_Solution (10, "fib-4-skip", "fail", "not-toward-base", "pass", 2);
   Expect_Solution (11, "sum-right", "pass", "none", "pass", 0);
   Expect_Solution (12, "sum-guess", "fail", "guessed-first", "pass", 1);
   Ada.Text_IO.Put_Line ("item 17 pass");
end Item_17;
