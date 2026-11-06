--  The live page's recorded chains.
--
--  Plain Ada, like AI_Amplifier.Recurse. JavaScript asks for a
--  chain, then reads lines and the verdict Ada already wrote.
--  It does not parse a blob and it does not add the running
--  values. A bad index is ignored or reads as zero, so the
--  wrapper does not raise.
--
--  This unit does not open a network connection. The page that
--  calls it cannot supply a key.
package AI_Amplifier.Recurse.Demo
  with SPARK_Mode => Off
is

   function Chain_Count return Integer
     with Export, Convention => C, External_Name => "aa_rec_chains";

   function Max_Index return Integer
     with Export, Convention => C, External_Name => "aa_rec_max_index";

   procedure Select_Chain (Index : Integer)
     with Export, Convention => C, External_Name => "aa_rec_select";

   function Name_Length return Integer
     with Export, Convention => C, External_Name => "aa_rec_name_len";

   function Name_Byte (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_rec_name_byte";

   function State_Count return Integer
     with Export, Convention => C, External_Name => "aa_rec_states";

   function Line_Length (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_rec_line_len";

   function Line_Byte (Index, Pos : Integer) return Integer
     with Export, Convention => C,
          External_Name => "aa_rec_line_byte";

   --  0 accepted, 1 base, 2 halt. An unused index reads as 0.
   function Mark (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_rec_mark";

   function Parsed (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_rec_parsed";

   function State_Index (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_rec_index";

   function State_Minus (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_rec_minus";

   function State_Current (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_rec_current";

   function Stop_Kind return Integer
     with Export, Convention => C, External_Name => "aa_rec_stop";

   function Stop_Length return Integer
     with Export, Convention => C, External_Name => "aa_rec_stop_len";

   function Stop_Byte (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_rec_stop_byte";

   function Stop_At return Integer
     with Export, Convention => C, External_Name => "aa_rec_stop_at";

   function Accepted_Steps return Integer
     with Export, Convention => C, External_Name => "aa_rec_accepted";

   function Answer return Integer
     with Export, Convention => C, External_Name => "aa_rec_answer";

   function Note_Length return Integer
     with Export, Convention => C, External_Name => "aa_rec_note_len";

   function Note_Byte (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_rec_note_byte";

end AI_Amplifier.Recurse.Demo;
