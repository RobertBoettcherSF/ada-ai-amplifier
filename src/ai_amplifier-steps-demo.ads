--  The live page's checked-steps demo.
--
--  Plain Ada, like AI_Amplifier.Steps. JavaScript asks for the
--  table and for one solution's lines and copies them. It does
--  not grade. A bad index reads as zero, so the wrapper does
--  not raise.
package AI_Amplifier.Steps.Demo
  with SPARK_Mode => Off
is

   procedure Run
     with Export, Convention => C, External_Name => "aa_st_run";

   function Solution_Count return Integer
     with Export, Convention => C, External_Name => "aa_st_count";

   function Name_Length (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_st_name_len";

   function Name_Byte (Index, Pos : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_st_name_byte";

   function Answer_Length (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_st_answer_len";

   function Answer_Byte (Index, Pos : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_st_answer_byte";

   function Steps_Length (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_st_steps_len";

   function Steps_Byte (Index, Pos : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_st_steps_byte";

   procedure Select_One (Index : Integer)
     with Export, Convention => C, External_Name => "aa_st_select";

   function Which return Integer
     with Export, Convention => C, External_Name => "aa_st_which";

   function Row_Count return Integer
     with Export, Convention => C, External_Name => "aa_st_rows";

   function Row_Length (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_st_row_len";

   function Row_Byte (Index, Pos : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_st_row_byte";

   --  The first bad row, or 0 when every row holds.
   function Bad_At return Integer
     with Export, Convention => C, External_Name => "aa_st_bad";

   function Rule_Length return Integer
     with Export, Convention => C, External_Name => "aa_st_rule_len";

   function Rule_Byte (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_st_rule_byte";

   function Stat_Length return Integer
     with Export, Convention => C, External_Name => "aa_st_stat_len";

   function Stat_Byte (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_st_stat_byte";

end AI_Amplifier.Steps.Demo;
