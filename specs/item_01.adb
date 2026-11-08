--  Item 1. The stamp starts with v, and an index outside the
--  text returns the nearer end byte. Those are the numbers
--  AI_Amplifier.Version exports. tools/check-version.sh is
--  what checks the badge, version.txt, and hello agree.
with Ada.Text_IO;
with AI_Amplifier.Version;

procedure Item_01
  with SPARK_Mode => Off
is
   package V renames AI_Amplifier.Version;
   Last : constant Integer := V.Version_Length;
begin
   pragma Assert (Last = V.Version_Text'Length);
   pragma Assert (V.Version_Byte (1) = 118);
   pragma Assert
     (V.Version_Byte (1) =
        Character'Pos (V.Version_Text (V.Version_Text'First)));
   pragma Assert (V.Version_Byte (0) = V.Version_Byte (1));
   pragma Assert (V.Version_Byte (Last + 1) = V.Version_Byte (Last));
   Ada.Text_IO.Put_Line ("item 01 pass");
end Item_01;
