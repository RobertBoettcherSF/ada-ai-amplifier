package body AI_Amplifier.Ask_Rule
  with SPARK_Mode
is

   function Classify
     (Call_OK, Parsed_OK, Checker_OK : Boolean) return Outcome
   is
   begin
      if not Call_OK then
         return Timed_Out;
      elsif not Parsed_OK then
         return Broken_Format;
      elsif not Checker_OK then
         return Wrong_Answer;
      else
         return Accepted;
      end if;
   end Classify;

   function Reports_Failure (Item : Outcome) return Boolean is
   begin
      if Item = Accepted then
         return False;
      end if;
      return True;
   end Reports_Failure;

   function Standin_Covers
     (Good, Wrong, Broken, Timeout : Boolean) return Boolean
   is
   begin
      if Good and then Wrong and then Broken and then Timeout then
         return True;
      end if;
      return False;
   end Standin_Covers;

   function Real_Model_Checked return Boolean is
   begin
      return False;
   end Real_Model_Checked;

end AI_Amplifier.Ask_Rule;
