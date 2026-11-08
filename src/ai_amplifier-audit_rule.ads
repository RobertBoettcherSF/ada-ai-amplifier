--  When a benchmark score is accepted.
--
--  SPARK. The post is the gate Score applies after the flags
--  are already counted. Finding a flag is not in this unit.
--  The result is a Boolean, not a slice.
package AI_Amplifier.Audit_Rule
  with SPARK_Mode
is

   function Score_Accepted
     (Examined      : Boolean;
      Drop_Flagged  : Boolean;
      Flagged_Count : Natural) return Boolean
     with Post =>
       Score_Accepted'Result =
         (Examined
          and then (Drop_Flagged or else Flagged_Count = 0));

end AI_Amplifier.Audit_Rule;
