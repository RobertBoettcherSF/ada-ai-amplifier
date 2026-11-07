--  Audit a small benchmark before any score is accepted.
--
--  Plain Ada (SPARK_Mode off). Nothing here is proved. The tasks
--  ask about this repository's own XOR labels, Fibonacci checker,
--  and weight-file reader. The auditor recomputes those answers
--  by calling that code. It does not trust the expected field.
--
--  Five rules, each named when it fires:
--    wrong-expected    the recomputed answer is not the expected text
--    unsolvable        this code has no answer for the input
--    duplicate         an earlier task has the same kind and input
--    accept-anything   the grader accepts a probe that is not the key
--    answer-leaked     the expected token sits in the prompt and is
--                      not one of the input tokens
--  A task can carry more than one flag. Scoring the set that still
--  contains a flag is refused. Dropping the flagged tasks is the
--  cleaned score, and that one is accepted.
--
--  The planted list is not in this unit. The native test holds it.
--  docs/BENCHMARK_AUDIT.md says what this does not catch.
package AI_Amplifier.Audit
  with SPARK_Mode => Off
is

   pragma Assertion_Policy (Pre => Check, Post => Check);

   Max_Tasks  : constant := 32;
   Max_Id     : constant := 24;
   Max_Kind   : constant := 16;
   Max_Prompt : constant := 160;
   Max_Input  : constant := 48;
   Max_Answer : constant := 24;
   Max_Line   : constant := 160;
   Max_Note   : constant := 80;
   Max_Flags  : constant := 4;

   type Rule_Name is
     (None,
      Wrong_Expected,
      Unsolvable,
      Duplicate,
      Accept_Anything,
      Answer_Leaked);

   type Flag_List is array (1 .. Max_Flags) of Rule_Name;

   type Item is record
      Id           : String (1 .. Max_Id) := (others => ' ');
      Id_Last      : Natural := 0;
      Kind         : String (1 .. Max_Kind) := (others => ' ');
      Kind_Last    : Natural := 0;
      Prompt       : String (1 .. Max_Prompt) := (others => ' ');
      Prompt_Last  : Natural := 0;
      Input        : String (1 .. Max_Input) := (others => ' ');
      Input_Last   : Natural := 0;
      Expected     : String (1 .. Max_Answer) := (others => ' ');
      Expected_Last : Natural := 0;
      Sample       : String (1 .. Max_Answer) := (others => ' ');
      Sample_Last  : Natural := 0;
      True_Answer  : String (1 .. Max_Answer) := (others => ' ');
      True_Last    : Natural := 0;
      Grade_Any    : Boolean := False;
      Solvable     : Boolean := False;
      Flag_Count   : Natural := 0;
      Flags        : Flag_List := (others => None);
   end record;

   type Item_Array is array (1 .. Max_Tasks) of Item;

   type Set is record
      Count    : Natural := 0;
      Examined : Boolean := False;
      Slot     : Item_Array;
   end record;

   --  OK is False when the text is not a task file. Note then says
   --  why. Bank is empty in that case. Examine has not been run.
   procedure Load
     (Text      : String;
      Bank      : out Set;
      OK        : out Boolean;
      Note      : out String;
      Note_Last : out Natural);

   --  The benchmark compiled into this unit. Same parser as Load.
   procedure Load_Benchmark
     (Bank      : out Set;
      OK        : out Boolean;
      Note      : out String;
      Note_Last : out Natural);

   --  Recompute every answer, then flag. Does not read Sample.
   --  Call this before Score. A second call replaces the flags.
   procedure Examine (Bank : in out Set);

   --  Hits count Sample against the task's own grader.
   --  Accepted is False when Examine has not been run, and when
   --  Drop_Flagged is False while any task is flagged. The hit
   --  tally is still filled in that second case, so a caller can
   --  show the skew. It is not an accepted score.
   --  Drop_Flagged skips flagged tasks. That tally is accepted
   --  once Examine has run.
   procedure Score
     (Bank         : Set;
      Drop_Flagged : Boolean;
      Hits         : out Natural;
      Total        : out Natural;
      Accepted     : out Boolean);

   procedure Rule_Word
     (Rule : Rule_Name;
      Text : out String;
      Last : out Natural);

   --  "id  pass" or "id  flag  rule". Last is 0 when Index is
   --  not a task or Text is too short. Examine first.
   procedure Line_For
     (Bank  : Set;
      Index : Natural;
      Text  : out String;
      Last  : out Natural);

   --  "Full set: N of M. ..." or "Cleaned set: ...".
   --  The refusal word is audit-flagged, or not-examined.
   procedure Score_Line
     (Bank         : Set;
      Drop_Flagged : Boolean;
      Text         : out String;
      Last         : out Natural);

   function Flagged (Bank : Set) return Natural;

end AI_Amplifier.Audit;
