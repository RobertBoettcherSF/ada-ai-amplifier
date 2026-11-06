with AI_Amplifier.MLP;

--  Recorded wrong turns of this repository's XOR trainer, and a
--  checker for the step that comes next.
--
--  Plain Ada (SPARK_Mode off). Nothing here is proved. A proposal
--  is run on AI_Amplifier.MLP and then judged. A bad proposal is a
--  verdict, not an exception: the page module must not trap on a
--  menu code it does not know.
--
--  The four traces were written in this repository. They are not a
--  copy of anyone else's session, and they are not a test of
--  research taste. docs/WRONG_TURNS.md is that account.
--
--  Each trace is a short list of actions ending in one wrong turn.
--  The checker rebuilds the net up to that turn, applies one step
--  from a fixed menu, and compares the two states. The rules are
--  the ones the XOR test already uses, plus the weight limit:
--    mean loss under Loss_Max (0.05)
--    class 1 at least 0.8, class 0 at most 0.2
--    every weight finite and inside +/- Weight_Limit
--  A loss counts as lower or higher only when the gap exceeds
--  Loss_Epsilon. The verdict is fixes-it, no-better, or
--  makes-it-worse, and the reason names the rule that decided.
package AI_Amplifier.Traces
  with SPARK_Mode => Off
is

   pragma Assertion_Policy (Pre => Check, Post => Check);

   Loss_Max     : constant := 0.05;
   High_Min     : constant := 0.8;
   Low_Max      : constant := 0.2;
   Loss_Epsilon : constant := 0.000_1;

   --  How many traces are recorded, and how many next steps the
   --  menu offers. Both are fixed. A code outside 1 .. that count
   --  is not a step.
   Trace_Count : constant := 4;
   Menu_Count  : constant := 10;

   Max_Steps  : constant := 4;
   Max_Line   : constant := 180;
   Max_Name   : constant := 24;
   Max_Note   : constant := 320;
   Max_Prompt : constant := 2_000;
   Max_JSON   : constant := 4_000;

   type Verdict_Kind is (Fixes_It, No_Better, Makes_It_Worse);

   type Reason_Kind is
     (XOR_Returned,
      XOR_Still_Missed,
      XOR_Left,
      Loss_Rose,
      Loss_Did_Not_Fall,
      Weights_Invalid,
      Not_A_Step);

   --  The menu, in the order Proposal_Code returns.
   --  A train step uses the rate the net already has, unless the
   --  name says it sets a rate first.
   type Proposal is
     (Rate_1_Train_200,
      Rate_5_Train_10,
      Train_200,
      Train_8,
      Hand_Net,
      Revert_Edit,
      Silence_And,
      Flip_Or,
      Invert_Out,
      Load_Bad_Shape);

   --  1 .. Menu_Count, in declaration order. The page and the
   --  native caller share these numbers.
   function Proposal_Code (Which : Proposal) return Integer;

   procedure Proposal_From_Code
     (Code  : Integer;
      Which : out Proposal;
      OK    : out Boolean);

   --  Hyphenated token a model is asked to reply with.
   --  Last is 0 when Text is too short.
   procedure Proposal_Word
     (Which : Proposal;
      Text  : out String;
      Last  : out Natural);

   --  The label the page button shows.
   procedure Proposal_Label
     (Which : Proposal;
      Text  : out String;
      Last  : out Natural);

   function Verdict_Code (Kind : Verdict_Kind) return Integer;

   function Reason_Code (Kind : Reason_Kind) return Integer;

   procedure Verdict_Word
     (Kind : Verdict_Kind;
      Text : out String;
      Last : out Natural);

   procedure Reason_Word
     (Kind : Reason_Kind;
      Text : out String;
      Last : out Natural);

   procedure Trace_Name
     (Index : Natural;
      Text  : out String;
      Last  : out Natural);

   --  How many lines the trace shows, including the wrong turn.
   --  Zero when Index is not a recorded trace.
   function Step_Count (Index : Natural) return Natural;

   --  The wrong turn is the last line. Zero when Index is bad.
   function Wrong_At (Index : Natural) return Natural;

   --  One line of the trace, 1-based. Last is 0 when the index
   --  is not a stored line or Text is too short.
   procedure Step_Line
     (Index : Natural;
      Step  : Natural;
      Text  : out String;
      Last  : out Natural);

   --  The menu entry stored as the repair, and one stored step
   --  that does not repair it. OK is False when Index is bad.
   procedure Known_Good
     (Index : Natural;
      Which : out Proposal;
      OK    : out Boolean);

   procedure Stored_Bad
     (Index : Natural;
      Which : out Proposal;
      OK    : out Boolean);

   --  The same comparison Judge uses, on two nets the caller
   --  already built. A weight outside +/- Weight_Limit, or a
   --  non-finite weight, is weights-invalid and is not passed
   --  to the loss.
   procedure Judge_Pair
     (Before  : MLP.Net;
      After   : MLP.Net;
      Verdict : out Verdict_Kind;
      Reason  : out Reason_Kind);

   --  Rebuild the trace, apply Which, and judge. OK is False
   --  when Index is not a recorded trace. A code the menu does
   --  not have is still OK: the verdict is no-better and the
   --  reason is not-a-step, and the trainer is not run.
   procedure Judge
     (Index       : Natural;
      Code        : Integer;
      Verdict     : out Verdict_Kind;
      Reason      : out Reason_Kind;
      Before_Loss : out Float;
      After_Loss  : out Float;
      Before_XOR  : out Boolean;
      After_XOR   : out Boolean;
      OK          : out Boolean);

   --  The sentence the page shows for the state at the wrong
   --  turn, and for a proposal. Last is 0 when Index is bad
   --  or Text is too short.
   procedure State_Line
     (Index : Natural;
      Text  : out String;
      Last  : out Natural);

   procedure Report_Line
     (Index : Natural;
      Code  : Integer;
      Text  : out String;
      Last  : out Natural);

   --  The prompt for one trace. It lists the menu and does not
   --  name a preferred step. OK is False when Index is bad or
   --  Text is too short.
   procedure Prompt_For
     (Index : Natural;
      Text  : out String;
      Last  : out Natural;
      OK    : out Boolean);

   procedure Request_JSON
     (Model  : String;
      Prompt : String;
      Text   : out String;
      Last   : out Natural;
      OK     : out Boolean);

   --  The first JSON string after the field name content.
   procedure Assistant_Text
     (Reply : String;
      Text  : out String;
      Last  : out Natural;
      OK    : out Boolean);

   --  A menu token, with spaces at either end ignored. Anything
   --  else, including a sentence that merely contains a token,
   --  is not a step.
   procedure Parse_Proposal
     (Text  : String;
      Which : out Proposal;
      OK    : out Boolean);

   --  The shape line 2 4 1, loaded through Read_Weights.
   --  Refused is True only when that call reports Bad_Shape
   --  and leaves Model unchanged. The trace uses this load.
   procedure Refuse_Broken_Shape
     (Model   : in out MLP.Net;
      Refused : out Boolean);

end AI_Amplifier.Traces;
