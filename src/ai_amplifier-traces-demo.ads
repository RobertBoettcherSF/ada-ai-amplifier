--  The live page's wrong-turn panel.
--
--  Plain Ada, like AI_Amplifier.Traces. JavaScript asks for a
--  trace, then reads lines Ada already wrote. A click sends a
--  menu code. Ada runs that step on the trainer and writes the
--  verdict. JavaScript does not train and does not judge.
--  A bad index is ignored or reads as zero, so the wrapper
--  does not raise.
--
--  This unit does not open a network connection. The page that
--  calls it cannot supply a key.
package AI_Amplifier.Traces.Demo
  with SPARK_Mode => Off
is

   function Trace_Count return Integer
     with Export, Convention => C, External_Name => "aa_tr_count";

   procedure Select_Trace (Index : Integer)
     with Export, Convention => C, External_Name => "aa_tr_select";

   function Name_Length return Integer
     with Export, Convention => C, External_Name => "aa_tr_name_len";

   function Name_Byte (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_tr_name_byte";

   function Step_Count return Integer
     with Export, Convention => C, External_Name => "aa_tr_steps";

   function Line_Length (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_tr_line_len";

   function Line_Byte (Index, Pos : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_tr_line_byte";

   --  1 when this line is the wrong turn, otherwise 0.
   function Wrong_Mark (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_tr_wrong";

   function Menu_Count return Integer
     with Export, Convention => C, External_Name => "aa_tr_menu";

   function Menu_Length (Code : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_tr_menu_len";

   function Menu_Byte (Code, Pos : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_tr_menu_byte";

   procedure Propose (Code : Integer)
     with Export, Convention => C, External_Name => "aa_tr_propose";

   --  0 when no step has been run. Otherwise Verdict_Code.
   function Verdict return Integer
     with Export, Convention => C, External_Name => "aa_tr_verdict";

   function Reason return Integer
     with Export, Convention => C, External_Name => "aa_tr_reason";

   function Reason_Length return Integer
     with Export, Convention => C, External_Name => "aa_tr_reason_len";

   function Reason_Byte (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_tr_reason_byte";

   function Report_Length return Integer
     with Export, Convention => C, External_Name => "aa_tr_report_len";

   function Report_Byte (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_tr_report_byte";

   function Good_Length return Integer
     with Export, Convention => C, External_Name => "aa_tr_good_len";

   function Good_Byte (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_tr_good_byte";

   function State_Length return Integer
     with Export, Convention => C, External_Name => "aa_tr_state_len";

   function State_Byte (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_tr_state_byte";

end AI_Amplifier.Traces.Demo;
