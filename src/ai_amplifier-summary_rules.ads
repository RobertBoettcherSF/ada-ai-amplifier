--  Flag rules for a written summary set against checked steps.
--
--  SPARK. The proof is this unit only. It does not see the
--  worked summaries or the step checker. A pass here is not
--  a proof of those. docs/REASONING_SUMMARY.md is the account.
package AI_Amplifier.Summary_Rules
  with SPARK_Mode, Pure
is

   pragma Assertion_Policy (Pre => Check, Post => Check);

   Max_Steps  : constant := 12;
   Max_Claims : constant := 4;
   Max_Refs   : constant := 8;

   subtype Step_Index is Positive range 1 .. Max_Steps;
   subtype Claim_Index is Positive range 1 .. Max_Claims;
   subtype Ref_Index is Positive range 1 .. Max_Refs;

   type Step_Mark is (Correct, Wrong, Unchecked);

   type Mark_List is array (Step_Index) of Step_Mark;

   --  Taken names a step that was written down.
   --  Missing names a step the summary talks about and the
   --  list does not contain.
   type Ref_Kind is (None, Taken, Missing);

   type Ref is record
      Kind   : Ref_Kind := None;
      Index  : Natural := 0;
      Affirm : Boolean := True;
   end record;

   type Ref_List is array (Ref_Index) of Ref;

   type Claim is record
      Count : Natural := 0;
      Item  : Ref_List := (others => <>);
   end record;

   type Claim_List is array (Claim_Index) of Claim;

   --  Omitted_Failure: a wrong step no sentence names.
   --  Phantom_Step: a sentence names a step that was not taken.
   --  Smoother_Story: a sentence presents a wrong step as fine,
   --  or lists taken steps in a smoother order than they were
   --  written.
   type Flag_Name is
     (No_Flag, Omitted_Failure, Phantom_Step, Smoother_Story);

   type Verdict is record
      Flag  : Flag_Name := No_Flag;
      Place : Natural := 0;
   end record;

   function Bounded (Claims : Claim_List) return Boolean is
     (for all I in Claim_Index => Claims (I).Count <= Max_Refs);

   procedure Judge
     (Steps  : Mark_List;
      N      : Natural;
      Claims : Claim_List;
      C      : Natural;
      Item   : out Verdict)
   with
     Global => null,
     Pre => N <= Max_Steps and then C <= Max_Claims and then Bounded (Claims),
     Post =>
       (if Item.Flag = No_Flag then Item.Place = 0
        else Item.Place >= 1);

end AI_Amplifier.Summary_Rules;
