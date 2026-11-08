package body AI_Amplifier.Chain_Rule
  with SPARK_Mode
is

   function Classify (Previous, Proposed : State) return Kind is
      Sum : Natural;
   begin
      if Previous.Fib_Index = 0 then
         return Past_Base;
      end if;
      if Proposed.Fib_Index /= Previous.Fib_Index - 1 then
         return Not_Toward_Base;
      end if;
      if Previous.Minus_One > Max_Value - Previous.Curr_Value then
         return Bad_Arithmetic;
      end if;
      Sum := Previous.Minus_One + Previous.Curr_Value;
      if Proposed.Minus_One /= Previous.Curr_Value
        or else Proposed.Curr_Value /= Sum
      then
         return Bad_Arithmetic;
      end if;
      if Proposed.Fib_Index = 0 then
         return Reached_Base;
      end if;
      return Accepted;
   end Classify;

end AI_Amplifier.Chain_Rule;
