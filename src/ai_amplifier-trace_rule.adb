package body AI_Amplifier.Trace_Rule
  with SPARK_Mode
is

   procedure Decide
     (Before  : Facts;
      After   : Facts;
      Verdict : out Verdict_Kind;
      Reason  : out Reason_Kind)
   is
   begin
      if not After.Weights_OK then
         if Before.Weights_OK then
            Verdict := Makes_It_Worse;
         else
            Verdict := No_Better;
         end if;
         Reason := Weights_Invalid;
         return;
      end if;
      if not After.Loss_Finite then
         Verdict := Makes_It_Worse;
         Reason := Loss_Rose;
         return;
      end if;
      if Solved (After) and then not Solved (Before) then
         Verdict := Fixes_It;
         Reason := XOR_Returned;
         return;
      end if;
      if Before.XOR_OK and then not After.XOR_OK then
         Verdict := Makes_It_Worse;
         Reason := XOR_Left;
         return;
      end if;
      if Before.Loss_Finite
        and then After.Loss > Before.Loss + Loss_Epsilon
      then
         Verdict := Makes_It_Worse;
         Reason := Loss_Rose;
         return;
      end if;
      if not Solved (After) then
         Verdict := No_Better;
         if not After.XOR_OK
           and then Before.Loss_Finite
           and then After.Loss + Loss_Epsilon < Before.Loss
         then
            Reason := XOR_Still_Missed;
         else
            Reason := Loss_Did_Not_Fall;
         end if;
         return;
      end if;
      Verdict := No_Better;
      Reason := Loss_Did_Not_Fall;
   end Decide;

end AI_Amplifier.Trace_Rule;
