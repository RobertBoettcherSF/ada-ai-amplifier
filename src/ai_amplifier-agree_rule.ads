--  Counting agreements between two checkers.
--
--  SPARK. Comparing the two lines is not in this unit.
--  A pair holds when the agree count equals the total and
--  the total is positive. That is not a proof that either
--  checker is right. The result is a Boolean or a count
--  written through out parameters, not a slice.
package AI_Amplifier.Agree_Rule
  with SPARK_Mode
is

   procedure Count_Case
     (Same  : Boolean;
      Agree : in out Natural;
      Total : in out Natural)
     with Pre => Agree <= Total and then Total < Natural'Last,
          Post =>
            Total = Total'Old + 1
            and then Agree <= Total
            and then (if Same then Agree = Agree'Old + 1
                      else Agree = Agree'Old);

   function Pair_Holds (Agree, Total : Natural) return Boolean
     with Post =>
       Pair_Holds'Result = (Agree = Total and then Total > 0);

   function All_Hold
     (Agree_1, Total_1 : Natural;
      Agree_2, Total_2 : Natural;
      Agree_3, Total_3 : Natural) return Boolean
     with Post =>
       All_Hold'Result =
         (Pair_Holds (Agree_1, Total_1)
          and then Pair_Holds (Agree_2, Total_2)
          and then Pair_Holds (Agree_3, Total_3));

end AI_Amplifier.Agree_Rule;
