--  A second checker for the verdicts of items 11, 12, and 15.
--
--  Plain Ada (SPARK_Mode off). Agreement is not a proof
--  of either checker. The agreement count is
--  AI_Amplifier.Agree_Rule, called by the comparison
--  program. This unit does not with AI_Amplifier.Traces, AI_Amplifier.Audit,
--  or AI_Amplifier.Steps. It does not call their graders. The
--  comparison program runs a case through one of those units
--  and through this one, and it fails when the verdict, the
--  reason, or the first bad step differs.
--
--  The arithmetic this unit trusts is its own: a hand-written
--  XOR forward pass, one gradient step of that net, a Fibonacci
--  walk, and a vector sum. The trace replay drives
--  AI_Amplifier.MLP, which is the trainer under test, and then
--  applies this unit's own verdict rules. docs/SECOND_CHECKER.md
--  is the account of what an agreement does not prove.
package AI_Amplifier.Recheck
  with SPARK_Mode => Off
is

   pragma Assertion_Policy (Pre => Check, Post => Check);

   Trace_Count    : constant := 4;
   Menu_Count     : constant := 10;
   Task_Count     : constant := 20;
   Solution_Count : constant := 12;

   --  Words are copied into the caller's buffer. Last is 0 when
   --  the buffer is too short. A returned slice is not used: this
   --  tree's wasm link has no secondary stack.
   procedure Trace_Name
     (Index : Natural;
      Text  : out String;
      Last  : out Natural);

   --  Code 0 is not a step. Codes 1 .. Menu_Count are the menu,
   --  in the same order the wrong-turn page lists. Bad is 0:
   --  a trace verdict is about one next step, not a row number.
   --  OK is False when Index is not a recorded trace.
   procedure Judge_Trace
     (Index   : Natural;
      Code    : Integer;
      Verdict : out String;
      V_Last  : out Natural;
      Reason  : out String;
      R_Last  : out Natural;
      Bad     : out Natural;
      OK      : out Boolean);

   procedure Task_Id
     (Index : Natural;
      Text  : out String;
      Last  : out Natural);

   --  Verdict is pass or flag. Reason is none, or the first rule.
   --  Bad is 0. The rule is not a step number.
   procedure Judge_Task
     (Index   : Natural;
      Verdict : out String;
      V_Last  : out Natural;
      Reason  : out String;
      R_Last  : out Natural;
      Bad     : out Natural;
      OK      : out Boolean);

   --  Drop_Flagged False is the full set. True drops flagged
   --  tasks. Verdict is accepted or not-accepted. Reason is the
   --  score sentence. Bad is 0.
   procedure Judge_Score
     (Drop_Flagged : Boolean;
      Verdict      : out String;
      V_Last       : out Natural;
      Reason       : out String;
      R_Last       : out Natural;
      Bad          : out Natural;
      OK           : out Boolean);

   --  Verdict is the step grade, pass or fail. Reason is the
   --  rule, or none. Bad is the first bad row, or 0. Answer is
   --  the answer-only grade.
   procedure Grade_Text
     (Text    : String;
      Verdict : out String;
      V_Last  : out Natural;
      Reason  : out String;
      R_Last  : out Natural;
      Bad     : out Natural;
      Answer  : out String;
      A_Last  : out Natural);

end AI_Amplifier.Recheck;
