--  The live page's reward-hacking demo.
--
--  Plain Ada, like AI_Amplifier.Reward. JavaScript asks for the
--  table and the two curves and copies them. It does not grade,
--  and it does not step the search. A bad index reads as zero,
--  so the wrapper does not raise.
package AI_Amplifier.Reward.Demo
  with SPARK_Mode => Off
is

   procedure Run
     with Export, Convention => C, External_Name => "aa_rw_run";

   function Submission_Count return Integer
     with Export, Convention => C, External_Name => "aa_rw_count";

   function Column_Count return Integer
     with Export, Convention => C, External_Name => "aa_rw_cols";

   function Col_Length (Index, Col : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_rw_col_len";

   function Col_Byte (Index, Col, Pos : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_rw_col_byte";

   --  1 when that submission passes the real check.
   function Mark (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_rw_mark";

   function Tally_Length return Integer
     with Export, Convention => C, External_Name => "aa_rw_tally_len";

   function Tally_Byte (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_rw_tally_byte";

   function Stat_Length return Integer
     with Export, Convention => C, External_Name => "aa_rw_stat_len";

   function Stat_Byte (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_rw_stat_byte";

   function Step_Count return Integer
     with Export, Convention => C, External_Name => "aa_rw_steps";

   function Flawed_Proxy (Step : Integer) return Float
     with Export, Convention => C, External_Name => "aa_rw_flawed_proxy";

   function Flawed_Real (Step : Integer) return Float
     with Export, Convention => C, External_Name => "aa_rw_flawed_real";

   function Flawed_Holds (Step : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_rw_flawed_holds";

   function Real_Proxy (Step : Integer) return Float
     with Export, Convention => C, External_Name => "aa_rw_real_proxy";

   function Real_At (Step : Integer) return Float
     with Export, Convention => C, External_Name => "aa_rw_real_score";

   function Real_Holds (Step : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_rw_real_holds";

   function Flawed_End_Length return Integer
     with Export, Convention => C,
          External_Name => "aa_rw_flawed_end_len";

   function Flawed_End_Byte (Index : Integer) return Integer
     with Export, Convention => C,
          External_Name => "aa_rw_flawed_end_byte";

   function Real_End_Length return Integer
     with Export, Convention => C,
          External_Name => "aa_rw_real_end_len";

   function Real_End_Byte (Index : Integer) return Integer
     with Export, Convention => C,
          External_Name => "aa_rw_real_end_byte";

end AI_Amplifier.Reward.Demo;
