--  Placeholder body. The page does not run this copy.
--  tools/bake-locked.py writes obj/gen/ai_amplifier-locked.adb
--  after the specs pass, and build.sh compiles that file.
--  These functions return 0 so the unit typechecks here.
package body AI_Amplifier.Locked
  with SPARK_Mode => Off
is

   function Count return Integer is (0);

   function Item_Number (Index : Integer) return Integer is
   begin
      if Index < 1 then
         return 0;
      end if;
      return 0;
   end Item_Number;

   function Name_Length (Index : Integer) return Integer is
   begin
      if Index < 1 then
         return 0;
      end if;
      return 0;
   end Name_Length;

   function Name_Byte (Index, Pos : Integer) return Integer is
   begin
      if Index < 1 or else Pos < 1 then
         return 0;
      end if;
      return 0;
   end Name_Byte;

   function Text_Length (Index : Integer) return Integer is
   begin
      if Index < 1 then
         return 0;
      end if;
      return 0;
   end Text_Length;

   function Text_Byte (Index, Pos : Integer) return Integer is
   begin
      if Index < 1 or else Pos < 1 then
         return 0;
      end if;
      return 0;
   end Text_Byte;

   function Fingerprint_Length (Index : Integer) return Integer is
   begin
      if Index < 1 then
         return 0;
      end if;
      return 0;
   end Fingerprint_Length;

   function Fingerprint_Byte (Index, Pos : Integer) return Integer is
   begin
      if Index < 1 or else Pos < 1 then
         return 0;
      end if;
      return 0;
   end Fingerprint_Byte;

   function Status_Length (Index : Integer) return Integer is
   begin
      if Index < 1 then
         return 0;
      end if;
      return 0;
   end Status_Length;

   function Status_Byte (Index, Pos : Integer) return Integer is
   begin
      if Index < 1 or else Pos < 1 then
         return 0;
      end if;
      return 0;
   end Status_Byte;

   function Stat_Length return Integer is (0);

   function Stat_Byte (Index : Integer) return Integer is
   begin
      if Index < 1 then
         return 0;
      end if;
      return 0;
   end Stat_Byte;

end AI_Amplifier.Locked;
