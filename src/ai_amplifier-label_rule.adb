package body AI_Amplifier.Label_Rule
  with SPARK_Mode
is

   function Unit_Counts
     (Saw_Proof, Saw_Bad             : Boolean;
      Analyzed, Unit_Total, Checks : Natural) return Boolean
   is
   begin
      if Saw_Proof
        and then not Saw_Bad
        and then Analyzed > 0
        and then Analyzed = Unit_Total
        and then Checks > 0
      then
         return True;
      end if;
      return False;
   end Unit_Counts;

   function Own_Log
     (Present, Seen, Bad : Boolean;
      Unproved, Total    : Natural;
      Unit_OK            : Boolean) return Boolean
   is
   begin
      if Present
        and then Seen
        and then Unproved = 0
        and then Total > 0
        and then not Bad
        and then Unit_OK
      then
         return True;
      end if;
      return False;
   end Own_Log;

   function From_Flags (Log_OK, Ran_OK : Boolean) return Kind is
   begin
      if Log_OK then
         return Proved;
      elsif Ran_OK then
         return Tested;
      else
         return Unchecked;
      end if;
   end From_Flags;

end AI_Amplifier.Label_Rule;
