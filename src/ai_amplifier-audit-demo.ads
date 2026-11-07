--  The live page's benchmark audit.
--
--  Plain Ada, like AI_Amplifier.Audit. JavaScript asks for the
--  report and copies the lines. It does not recompute an answer
--  and it does not decide whether a score is accepted.
--  A bad index reads as zero, so the wrapper does not raise.
package AI_Amplifier.Audit.Demo
  with SPARK_Mode => Off
is

   procedure Run
     with Export, Convention => C, External_Name => "aa_au_run";

   function Task_Count return Integer
     with Export, Convention => C, External_Name => "aa_au_count";

   function Flagged_Count return Integer
     with Export, Convention => C, External_Name => "aa_au_flagged";

   --  1 when the task is flagged, otherwise 0.
   function Mark (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_au_mark";

   function Line_Length (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_au_line_len";

   function Line_Byte (Index, Pos : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_au_line_byte";

   function Stat_Length return Integer
     with Export, Convention => C, External_Name => "aa_au_stat_len";

   function Stat_Byte (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_au_stat_byte";

   function Full_Length return Integer
     with Export, Convention => C, External_Name => "aa_au_full_len";

   function Full_Byte (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_au_full_byte";

   function Clean_Length return Integer
     with Export, Convention => C, External_Name => "aa_au_clean_len";

   function Clean_Byte (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_au_clean_byte";

end AI_Amplifier.Audit.Demo;
