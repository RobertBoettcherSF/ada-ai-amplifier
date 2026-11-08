--  The Fibonacci step rule used by AI_Amplifier.Recurse.
--
--  SPARK. The post is the decision Check_Step applies. Parsing,
--  the recorded chains, and a live model are not in this unit.
--  A returned value is an enumeration, not a slice: the wasm
--  link has no secondary stack.
package AI_Amplifier.Chain_Rule
  with SPARK_Mode
is

   --  F(20) is 6765. A component past this is not a step.
   Max_Value : constant := 20_000;

   type State is record
      Fib_Index  : Natural := 0;
      Minus_One  : Natural := 0;
      Curr_Value : Natural := 0;
   end record;

   type Kind is
     (Past_Base,
      Not_Toward_Base,
      Bad_Arithmetic,
      Reached_Base,
      Accepted);

   function In_Range (Item : State) return Boolean is
     (Item.Minus_One <= Max_Value
      and then Item.Curr_Value <= Max_Value);

   function Classify (Previous, Proposed : State) return Kind
     with Pre => In_Range (Previous) and then In_Range (Proposed),
          Post =>
            (if Previous.Fib_Index = 0 then
               Classify'Result = Past_Base
             elsif Proposed.Fib_Index /= Previous.Fib_Index - 1 then
               Classify'Result = Not_Toward_Base
             elsif Previous.Minus_One > Max_Value - Previous.Curr_Value then
               Classify'Result = Bad_Arithmetic
             elsif Proposed.Minus_One /= Previous.Curr_Value
               or else Proposed.Curr_Value /=
                 Previous.Minus_One + Previous.Curr_Value
             then
               Classify'Result = Bad_Arithmetic
             elsif Proposed.Fib_Index = 0 then
               Classify'Result = Reached_Base
             else
               Classify'Result = Accepted);

end AI_Amplifier.Chain_Rule;
