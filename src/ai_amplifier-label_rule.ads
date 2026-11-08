--  The label rule used by AI_Amplifier.Status.
--
--  SPARK. Reading a log is not in this unit. Proved needs
--  the item's own log, a positive check count, and an
--  unproved count of 0. Tested needs the program check
--  when that log is absent. Otherwise the label is
--  unchecked. The result is an enumeration or a Boolean,
--  not a slice.
package AI_Amplifier.Label_Rule
  with SPARK_Mode
is

   type Kind is (Proved, Tested, Unchecked);

   function Unit_Counts
     (Saw_Proof, Saw_Bad             : Boolean;
      Analyzed, Unit_Total, Checks : Natural) return Boolean
     with Post =>
       Unit_Counts'Result =
         (Saw_Proof
          and then not Saw_Bad
          and then Analyzed > 0
          and then Analyzed = Unit_Total
          and then Checks > 0);

   function Own_Log
     (Present, Seen, Bad : Boolean;
      Unproved, Total    : Natural;
      Unit_OK            : Boolean) return Boolean
     with Post =>
       Own_Log'Result =
         (Present
          and then Seen
          and then Unproved = 0
          and then Total > 0
          and then not Bad
          and then Unit_OK);

   function From_Flags (Log_OK, Ran_OK : Boolean) return Kind
     with Post =>
       (if Log_OK then
          From_Flags'Result = Proved
        elsif Ran_OK then
          From_Flags'Result = Tested
        else
          From_Flags'Result = Unchecked);

end AI_Amplifier.Label_Rule;
