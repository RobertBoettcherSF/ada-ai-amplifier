--  How one stand-in reply is classified.
--
--  SPARK. This unit does not build a request, parse JSON,
--  or open a socket. Those rules stay in the plain Ada
--  callers. A call that did not come back is a timeout.
--  A body that does not yield the assistant text is a
--  broken format. A parsed reply the checker rejects is
--  a wrong answer. Only the other case is accepted.
--  Real_Model_Checked is false: this rule never records
--  a call to a real model.
package AI_Amplifier.Ask_Rule
  with SPARK_Mode
is

   type Outcome is (Accepted, Wrong_Answer, Broken_Format, Timed_Out);

   function Classify
     (Call_OK, Parsed_OK, Checker_OK : Boolean) return Outcome
     with Post =>
       (if not Call_OK then
          Classify'Result = Timed_Out
        elsif not Parsed_OK then
          Classify'Result = Broken_Format
        elsif not Checker_OK then
          Classify'Result = Wrong_Answer
        else
          Classify'Result = Accepted);

   function Reports_Failure (Item : Outcome) return Boolean
     with Post => Reports_Failure'Result = (Item /= Accepted);

   --  The stand-in check covers the mode only when a good
   --  reply was accepted and each of the three failures
   --  was reported.
   function Standin_Covers
     (Good, Wrong, Broken, Timeout : Boolean) return Boolean
     with Post =>
       Standin_Covers'Result =
         (Good and then Wrong and then Broken and then Timeout);

   function Real_Model_Checked return Boolean
     with Post => Real_Model_Checked'Result = False;

end AI_Amplifier.Ask_Rule;
