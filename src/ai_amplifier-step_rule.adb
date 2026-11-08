package body AI_Amplifier.Step_Rule
  with SPARK_Mode
is

   function Order_Of (Code, Next_Code, Need : Natural) return Order_Name is
   begin
      if Code < Next_Code then
         return Earlier_Step;
      elsif Code > Next_Code then
         if Code = Need then
            return Guessed_Answer;
         else
            return Skipped_Middle;
         end if;
      else
         return In_Order;
      end if;
   end Order_Of;

   function Steps_Complete
     (Known, Fib                    : Boolean;
      Seen, Index, Next_Code, Need : Natural) return Boolean
   is
   begin
      if Fib then
         return Known and then Seen = Index;
      else
         return Known and then Next_Code > Need;
      end if;
   end Steps_Complete;

   function Answer_Fault
     (Done, Later, Answer_OK : Boolean) return Answer_Name
   is
   begin
      if not Done then
         if Later then
            return Answer_Guessed;
         else
            return Answer_Skipped;
         end if;
      elsif not Answer_OK then
         return Answer_Wrong;
      else
         return Answer_Held;
      end if;
   end Answer_Fault;

   function Step_Grade_Passes
     (Bad_At      : Natural;
      Answer_Pass : Boolean;
      Steps_Done  : Boolean) return Boolean
   is
   begin
      if Bad_At = 0 and then Answer_Pass and then Steps_Done then
         return True;
      end if;
      return False;
   end Step_Grade_Passes;

end AI_Amplifier.Step_Rule;
