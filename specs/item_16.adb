--  Item 16. An index outside the locked report reads as 0.
--  The native body is the placeholder: Count is 0 until
--  tools/bake-locked.py writes the page body. A fingerprint
--  is not a proof that the statement is the right one.
with Ada.Text_IO;
with AI_Amplifier.Locked;

procedure Item_16
  with SPARK_Mode => Off
is
   package L renames AI_Amplifier.Locked;
begin
   pragma Assert (L.Count = 0);
   pragma Assert (L.Item_Number (0) = 0);
   pragma Assert (L.Item_Number (-1) = 0);
   pragma Assert (L.Name_Length (0) = 0);
   pragma Assert (L.Name_Byte (0, 1) = 0);
   pragma Assert (L.Name_Byte (1, 0) = 0);
   pragma Assert (L.Text_Length (0) = 0);
   pragma Assert (L.Text_Byte (0, 1) = 0);
   pragma Assert (L.Fingerprint_Length (0) = 0);
   pragma Assert (L.Fingerprint_Byte (1, 0) = 0);
   pragma Assert (L.Status_Length (0) = 0);
   pragma Assert (L.Status_Byte (0, 1) = 0);
   pragma Assert (L.Stat_Length = 0);
   pragma Assert (L.Stat_Byte (0) = 0);
   Ada.Text_IO.Put_Line ("item 16 pass");
end Item_16;
