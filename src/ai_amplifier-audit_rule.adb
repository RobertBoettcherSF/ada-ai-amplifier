package body AI_Amplifier.Audit_Rule
  with SPARK_Mode
is

   function Score_Accepted
     (Examined      : Boolean;
      Drop_Flagged  : Boolean;
      Flagged_Count : Natural) return Boolean
   is
   begin
      if not Examined then
         return False;
      end if;
      if not Drop_Flagged and then Flagged_Count > 0 then
         return False;
      end if;
      return True;
   end Score_Accepted;

end AI_Amplifier.Audit_Rule;
