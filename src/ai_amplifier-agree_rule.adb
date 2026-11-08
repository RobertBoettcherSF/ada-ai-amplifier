package body AI_Amplifier.Agree_Rule
  with SPARK_Mode
is

   procedure Count_Case
     (Same  : Boolean;
      Agree : in out Natural;
      Total : in out Natural)
   is
   begin
      Total := Total + 1;
      if Same then
         Agree := Agree + 1;
      end if;
   end Count_Case;

   function Pair_Holds (Agree, Total : Natural) return Boolean is
   begin
      if Agree = Total and then Total > 0 then
         return True;
      end if;
      return False;
   end Pair_Holds;

   function All_Hold
     (Agree_1, Total_1 : Natural;
      Agree_2, Total_2 : Natural;
      Agree_3, Total_3 : Natural) return Boolean
   is
   begin
      if Pair_Holds (Agree_1, Total_1)
        and then Pair_Holds (Agree_2, Total_2)
        and then Pair_Holds (Agree_3, Total_3)
      then
         return True;
      end if;
      return False;
   end All_Hold;

end AI_Amplifier.Agree_Rule;
