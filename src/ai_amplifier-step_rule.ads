--  The step-grade rule used by AI_Amplifier.Steps.
--
--  SPARK. The posts are the decisions Grade applies after
--  a line has already been read. Recomputing a value is not
--  in this unit. Results are enumerations and a Boolean,
--  not slices: the wasm link has no secondary stack.
package AI_Amplifier.Step_Rule
  with SPARK_Mode
is

   type Order_Name is (In_Order, Earlier_Step, Guessed_Answer, Skipped_Middle);

   type Answer_Name is
     (Answer_Held, Answer_Guessed, Answer_Skipped, Answer_Wrong);

   --  Code is the step just read. Next_Code is the one this
   --  solution still owes. Need is the last required step.
   function Order_Of
     (Code, Next_Code, Need : Natural) return Order_Name
     with Pre => Code >= 1 and then Next_Code >= 1 and then Need >= 1,
          Post =>
            (if Code < Next_Code then
               Order_Of'Result = Earlier_Step
             elsif Code > Next_Code then
               (if Code = Need then
                  Order_Of'Result = Guessed_Answer
                else
                  Order_Of'Result = Skipped_Middle)
             else
               Order_Of'Result = In_Order);

   --  Known is false until the problem line parsed.
   --  Fib uses Seen = Index. Any other problem uses
   --  Next_Code > Need.
   function Steps_Complete
     (Known, Fib                    : Boolean;
      Seen, Index, Next_Code, Need : Natural) return Boolean
     with Post =>
       (if Fib then
          Steps_Complete'Result = (Known and then Seen = Index)
        else
          Steps_Complete'Result = (Known and then Next_Code > Need));

   --  Done is false when a required step is still missing.
   --  Later is true when another step line follows this answer.
   function Answer_Fault
     (Done, Later, Answer_OK : Boolean) return Answer_Name
     with Post =>
       (if not Done then
          (if Later then
             Answer_Fault'Result = Answer_Guessed
           else
             Answer_Fault'Result = Answer_Skipped)
        elsif not Answer_OK then
          Answer_Fault'Result = Answer_Wrong
        else
          Answer_Fault'Result = Answer_Held);

   --  The step grade passes only when no row was blamed,
   --  the answer passed, and every required step was seen.
   function Step_Grade_Passes
     (Bad_At      : Natural;
      Answer_Pass : Boolean;
      Steps_Done  : Boolean) return Boolean
     with Post =>
       Step_Grade_Passes'Result =
         (Bad_At = 0 and then Answer_Pass and then Steps_Done);

end AI_Amplifier.Step_Rule;
