--  Native compare for tools/check-locked.py.
--  Hashing stays in that script. This program applies
--  AI_Amplifier.Lock_Rule and exits 0 on a match, 1 when
--  the digits differ, and 2 when the arguments are unusable.
--  It is not linked into the wasm module.
with Ada.Command_Line;
with AI_Amplifier.Lock_Rule;

procedure Lock_Match
  with SPARK_Mode => Off
is
   package R renames AI_Amplifier.Lock_Rule;

   function Load (Text : String; Into : out R.Hex) return Boolean is
      Cursor : Natural;
   begin
      Into := (others => ' ');
      if Text'Length /= R.Hex_Length then
         return False;
      end if;
      Cursor := Text'First;
      for I in R.Hex_Index loop
         Into (I) := Text (Cursor);
         if Cursor < Text'Last then
            Cursor := Cursor + 1;
         end if;
      end loop;
      return True;
   end Load;

   procedure Two_Digests is
      Left, Right : R.Hex;
   begin
      if Ada.Command_Line.Argument_Count /= 2 then
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
      if not Load (Ada.Command_Line.Argument (1), Left)
        or else not Load (Ada.Command_Line.Argument (2), Right)
      then
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
      if R.Digits_Match (Left, Right) then
         Ada.Command_Line.Set_Exit_Status (0);
      else
         Ada.Command_Line.Set_Exit_Status (1);
      end if;
   end Two_Digests;

   procedure The_Set is
      Flags : R.Flag_List := (others => False);
      Count : constant Natural := Ada.Command_Line.Argument_Count - 1;
      Arg   : Character;
   begin
      if Count < 1 or else Count > R.Max_Specs then
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
      for I in 1 .. Count loop
         declare
            Text : constant String := Ada.Command_Line.Argument (I + 1);
         begin
            if Text'Length /= 1 then
               Ada.Command_Line.Set_Exit_Status (2);
               return;
            end if;
            Arg := Text (Text'First);
            if Arg = '1' then
               Flags (I) := True;
            elsif Arg = '0' then
               Flags (I) := False;
            else
               Ada.Command_Line.Set_Exit_Status (2);
               return;
            end if;
         end;
      end loop;
      if R.All_Match (Flags, Count) then
         Ada.Command_Line.Set_Exit_Status (0);
      else
         Ada.Command_Line.Set_Exit_Status (1);
      end if;
   end The_Set;
begin
   if Ada.Command_Line.Argument_Count >= 1
     and then Ada.Command_Line.Argument (1) = "--all"
   then
      The_Set;
   else
      Two_Digests;
   end if;
end Lock_Match;
