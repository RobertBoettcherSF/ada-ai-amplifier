package body AI_Amplifier.Lock_Rule
  with SPARK_Mode
is

   function Digits_Match (Left, Right : Hex) return Boolean is
      Same : Boolean := True;
   begin
      for I in Hex_Index loop
         if Left (I) /= Right (I) then
            Same := False;
         end if;
         pragma Loop_Invariant
           (Same =
              (for all J in Hex_Index'First .. I => Left (J) = Right (J)));
      end loop;
      return Same;
   end Digits_Match;

   function All_Match (Flags : Flag_List; Count : Natural) return Boolean is
      Held : Boolean := Count > 0;
   begin
      for I in Spec_Index loop
         if I <= Count and then not Flags (I) then
            Held := False;
         end if;
         pragma Loop_Invariant
           (Held =
              (Count > 0
               and then
                 (for all J in Spec_Index'First .. I =>
                    (if J <= Count then Flags (J) else True))));
      end loop;
      return Held;
   end All_Match;

end AI_Amplifier.Lock_Rule;
