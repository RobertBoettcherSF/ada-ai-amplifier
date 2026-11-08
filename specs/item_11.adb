--  Item 11. The four wrong-turn traces. The known-good
--  step is fixes-it and xor-returned. The stored bad step
--  is the verdict traces_test names for that trace.
with Ada.Text_IO;
with AI_Amplifier.Traces;

procedure Item_11
  with SPARK_Mode => Off
is
   package T renames AI_Amplifier.Traces;
   use type T.Verdict_Kind;
   use type T.Reason_Kind;

   procedure Expect_Name (Index : Natural; Name : String) is
      Line : String (1 .. T.Max_Name);
      Last : Natural;
   begin
      T.Trace_Name (Index, Line, Last);
      pragma Assert (Last = Name'Length);
      pragma Assert (Line (1 .. Last) = Name);
   end Expect_Name;

   procedure Expect_Pair
     (Index : Natural;
      Good_V : T.Verdict_Kind;
      Good_R : T.Reason_Kind;
      Bad_V  : T.Verdict_Kind;
      Bad_R  : T.Reason_Kind)
   is
      Which                          : T.Proposal;
      OK                             : Boolean;
      Verdict                        : T.Verdict_Kind;
      Reason                         : T.Reason_Kind;
      Before, After                  : Float;
      Was_X, Now_X                   : Boolean;
   begin
      T.Judge
        (Index, 0, Verdict, Reason, Before, After, Was_X, Now_X, OK);
      pragma Assert (OK);
      pragma Assert (Verdict = T.No_Better);
      pragma Assert (Reason = T.Not_A_Step);
      T.Known_Good (Index, Which, OK);
      pragma Assert (OK);
      T.Judge
        (Index, T.Proposal_Code (Which), Verdict, Reason,
         Before, After, Was_X, Now_X, OK);
      pragma Assert (OK);
      pragma Assert (Now_X);
      pragma Assert (Verdict = Good_V);
      pragma Assert (Reason = Good_R);
      pragma Assert (After < T.Loss_Max);
      T.Stored_Bad (Index, Which, OK);
      pragma Assert (OK);
      T.Judge
        (Index, T.Proposal_Code (Which), Verdict, Reason,
         Before, After, Was_X, Now_X, OK);
      pragma Assert (OK);
      pragma Assert (Verdict = Bad_V);
      pragma Assert (Reason = Bad_R);
   end Expect_Pair;
begin
   pragma Assert (T.Trace_Count = 4);
   pragma Assert (T.Loss_Max = 0.05);
   pragma Assert (T.High_Min = 0.8);
   pragma Assert (T.Low_Max = 0.2);
   pragma Assert (T.Verdict_Code (T.Fixes_It) = 1);
   pragma Assert (T.Verdict_Code (T.No_Better) = 2);
   pragma Assert (T.Verdict_Code (T.Makes_It_Worse) = 3);
   Expect_Name (1, "rate-diverges");
   Expect_Name (2, "padded-shape");
   Expect_Name (3, "silenced-and");
   Expect_Name (4, "stopped-early");
   Expect_Pair
     (1, T.Fixes_It, T.XOR_Returned, T.Makes_It_Worse, T.Loss_Rose);
   Expect_Pair
     (2, T.Fixes_It, T.XOR_Returned, T.No_Better, T.Loss_Did_Not_Fall);
   Expect_Pair
     (3, T.Fixes_It, T.XOR_Returned, T.Makes_It_Worse, T.Loss_Rose);
   Expect_Pair
     (4, T.Fixes_It, T.XOR_Returned, T.Makes_It_Worse, T.Loss_Rose);
   Ada.Text_IO.Put_Line ("item 11 pass");
end Item_11;
