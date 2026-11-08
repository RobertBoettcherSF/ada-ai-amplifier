--  The live page's harness table.
--
--  Plain Ada, like AI_Amplifier.Harness. JavaScript asks for
--  the four rows and for one task's walk, and copies them.
--  It does not choose a step, and it does not call a model.
--  A bad index reads as zero, so the wrapper does not raise.
package AI_Amplifier.Harness.Demo
  with SPARK_Mode => Off
is

   procedure Run
     with Export, Convention => C, External_Name => "aa_hn_run";

   function Count_Harnesses return Integer
     with Export, Convention => C, External_Name => "aa_hn_harnesses";

   function Count_Tasks return Integer
     with Export, Convention => C, External_Name => "aa_hn_tasks";

   function Column_Count return Integer
     with Export, Convention => C, External_Name => "aa_hn_cols";

   function Cell_Length (Row, Col : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_hn_cell_len";

   function Cell_Byte (Row, Col, Pos : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_hn_cell_byte";

   function Task_Length (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_hn_task_len";

   function Task_Byte (Index, Pos : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_hn_task_byte";

   procedure Select_Task (Index : Integer)
     with Export, Convention => C, External_Name => "aa_hn_select";

   function Log_Count (Harness : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_hn_logs";

   function Log_Length (Harness, Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_hn_log_len";

   function Log_Byte (Harness, Index, Pos : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_hn_log_byte";

   function Solved (Harness : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_hn_solved";

   function Result_Length (Harness : Integer) return Integer
     with Export, Convention => C,
          External_Name => "aa_hn_result_len";

   function Result_Byte (Harness, Pos : Integer) return Integer
     with Export, Convention => C,
          External_Name => "aa_hn_result_byte";

   function Stat_Length return Integer
     with Export, Convention => C, External_Name => "aa_hn_stat_len";

   function Stat_Byte (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_hn_stat_byte";

end AI_Amplifier.Harness.Demo;
