--  Locked statements for the live page.
--
--  Plain Ada (SPARK_Mode off). Nothing here is proved. The
--  statements live in specs/. tools/bake-locked.py runs them
--  and writes the body build.sh compiles into the module.
--  The body in this directory is the placeholder the native
--  project typechecks. JavaScript reads these bytes and draws.
--  An index outside the report reads as 0.
package AI_Amplifier.Locked
  with SPARK_Mode => Off
is

   function Count return Integer
     with Export, Convention => C, External_Name => "aa_lk_count";

   function Item_Number (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_lk_item";

   function Name_Length (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_lk_name_len";

   function Name_Byte (Index, Pos : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_lk_name_byte";

   function Text_Length (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_lk_text_len";

   function Text_Byte (Index, Pos : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_lk_text_byte";

   function Fingerprint_Length (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_lk_fp_len";

   function Fingerprint_Byte (Index, Pos : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_lk_fp_byte";

   function Status_Length (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_lk_status_len";

   function Status_Byte (Index, Pos : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_lk_status_byte";

   function Stat_Length return Integer
     with Export, Convention => C, External_Name => "aa_lk_stat_len";

   function Stat_Byte (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_lk_stat_byte";

end AI_Amplifier.Locked;
