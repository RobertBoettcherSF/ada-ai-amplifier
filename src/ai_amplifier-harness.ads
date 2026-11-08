--  One fixed solver, four harnesses, one task set.
--
--  Plain Ada (SPARK_Mode off). Nothing here is proved. The
--  solver is a tiny deterministic procedure with a fixed list
--  of mistakes. It is not a language model, and the size of
--  the score gap is not a claim about one. docs/HARNESS.md
--  is that account.
--
--  The tasks are small Fibonacci chains, checked with
--  AI_Amplifier.Recurse, and the four wrong-turn repairs,
--  checked with AI_Amplifier.Traces. The seed is the MLP
--  seed. Every harness sees that same seed and those same
--  tasks. Model_Propose does not take a harness. A harness
--  only chooses the attempt, the note, and whether a reply
--  is kept.
--
--  one-shot keeps the first reply.
--  retry asks again, up to Retry_Tries, when the reply does
--  not even parse. A reply that parses is kept, including a
--  wrong one.
--  checked runs the item 9 or item 11 checker on each step
--  and sends that checker's word back. A failed step is not
--  kept.
--  budgeted is that same check with Budget_Cap model calls.
package AI_Amplifier.Harness
  with SPARK_Mode => Off
is

   pragma Assertion_Policy (Pre => Check, Post => Check);

   --  The MLP init seed. No harness has a second one.
   Seed : constant := 20261104;

   Task_Count    : constant := 8;
   Harness_Count : constant := 4;

   --  fib-3, the task the page opens on. The four walks
   --  diverge there.
   Showcase : constant := 2;

   Retry_Tries  : constant := 3;
   Checked_Cap  : constant := 12;
   Budget_Cap   : constant := 3;
   Attempt_Cap  : constant := 4;

   Max_Line : constant := 180;
   Max_Text : constant := 800;
   Max_Note : constant := 32;
   Max_Call : constant := 12;
   Max_Name : constant := 24;
   Max_Quote : constant := 48;

   type Harness_Name is (One_Shot, Retry, Checked, Budgeted);

   --  Whole is one complete reply. One_Step is the next blob
   --  or the next menu token. The state fields matter for a
   --  Fibonacci step. A whole reply ignores them.
   type Ask_Kind is (One_Step, Whole);

   type Call is record
      Attempt    : Positive := 1;
      Note       : String (1 .. Max_Note) := (others => ' ');
      Note_Len   : Natural := 0;
      Ask        : Ask_Kind := Whole;
      Fib_Index  : Natural := 0;
      Minus_One  : Natural := 0;
      Curr_Value : Natural := 0;
      Accepted   : Boolean := False;
      Word       : String (1 .. Max_Note) := (others => ' ');
      Word_Len   : Natural := 0;
      Quote      : String (1 .. Max_Quote) := (others => ' ');
      Quote_Len  : Natural := 0;
   end record;

   type Call_List is array (1 .. Max_Call) of Call;

   type Run is record
      Solved : Boolean := False;
      Steps  : Natural := 0;
      Wrong  : Natural := 0;
      Calls  : Natural := 0;
      Item   : Call_List;
   end record;

   type Row is record
      Solved : Natural := 0;
      Steps  : Natural := 0;
      Wrong  : Natural := 0;
   end record;

   type Table is array (Harness_Name) of Row;

   function Harness_Code (Which : Harness_Name) return Integer;

   procedure Harness_Word
     (Which : Harness_Name;
      Text  : out String;
      Last  : out Natural);

   procedure Task_Name
     (Index : Natural;
      Text  : out String;
      Last  : out Natural);

   function Is_Fib (Index : Natural) return Boolean;

   --  F(Index) for a Fibonacci task, else 0. The recurrence
   --  is the one Recurse checks. This is not a second rule.
   function Expected_Answer (Index : Natural) return Natural;

   --  The solver. Which harness is asking is not an argument.
   --  The same arguments are the same text. Last is 0 when
   --  Index is not a task or Text is too short.
   procedure Model_Propose
     (Index      : Natural;
      Attempt    : Positive;
      Note       : String;
      Ask        : Ask_Kind;
      Fib_Index  : Natural;
      Minus_One  : Natural;
      Curr_Value : Natural;
      Text       : out String;
      Last       : out Natural);

   --  The item 9 or item 11 checker, on one proposed step.
   --  OK is True only when that checker accepts it. A
   --  known-wrong step is not accepted. Note is the checker
   --  word either way. Note_Last is 0 when Index is not a
   --  task.
   procedure Checker_Accepts
     (Index      : Natural;
      Fib_Index  : Natural;
      Minus_One  : Natural;
      Curr_Value : Natural;
      Text       : String;
      OK         : out Boolean;
      Note       : out String;
      Note_Last  : out Natural);

   procedure Run_One
     (Which : Harness_Name;
      Index : Natural;
      Item  : out Run);

   procedure Run_Table (Item : out Table);

   procedure Cell
     (Which : Harness_Name;
      Row   : Table;
      Col   : Natural;
      Text  : out String;
      Last  : out Natural);

   procedure Log_Line
     (Item  : Run;
      Index : Natural;
      Text  : out String;
      Last  : out Natural);

   procedure Result_Line
     (Item : Run;
      Text : out String;
      Last : out Natural);

   procedure Stat_Line
     (Text : out String;
      Last : out Natural);

   --  The prompt a live caller would send for one step.
   --  Note is the checker word from the previous reply, or
   --  empty on the first call. OK is False when Index is
   --  not a task or Text is too short. The page does not
   --  call this.
   procedure Prompt_For
     (Index      : Natural;
      Fib_Index  : Natural;
      Minus_One  : Natural;
      Curr_Value : Natural;
      Note       : String;
      Text       : out String;
      Last       : out Natural;
      OK         : out Boolean);

end AI_Amplifier.Harness;
