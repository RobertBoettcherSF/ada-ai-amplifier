--  The live page's summary panel.
--
--  Plain Ada. JavaScript asks for the sentences and the
--  checked steps and copies them. It does not compare them.
--  A bad index reads as zero, so the wrapper does not raise.
package AI_Amplifier.Summary.Demo
  with SPARK_Mode => Off
is

   procedure Run
     with Export, Convention => C, External_Name => "aa_su_run";

   function Count return Integer
     with Export, Convention => C, External_Name => "aa_su_count";

   procedure Select_One (Index : Integer)
     with Export, Convention => C, External_Name => "aa_su_select";

   function Which return Integer
     with Export, Convention => C, External_Name => "aa_su_which";

   function Name_Length (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_su_name_len";

   function Name_Byte (Index, Pos : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_su_name_byte";

   function Flag_Length (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_su_flag_len";

   function Flag_Byte (Index, Pos : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_su_flag_byte";

   function Sentence_Count (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_su_sent_count";

   function Sentence_Length (Index, Which : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_su_sent_len";

   function Sentence_Byte (Index, Which, Pos : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_su_sent_byte";

   function Sentence_Mark (Index, Which : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_su_sent_mark";

   function Step_Count (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_su_step_count";

   function Step_Length (Index, Which : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_su_step_len";

   function Step_Byte (Index, Which, Pos : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_su_step_byte";

   function Step_Mark (Index, Which : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_su_step_mark";

   function Stat_Length return Integer
     with Export, Convention => C, External_Name => "aa_su_stat_len";

   function Stat_Byte (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_su_stat_byte";

end AI_Amplifier.Summary.Demo;
