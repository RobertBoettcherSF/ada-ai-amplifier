--  Checked steps, not just answers.
--
--  Plain Ada (SPARK_Mode off). Nothing here is proved. The
--  twelve solutions are written in this unit. Four of them
--  follow the code. The other eight are planted so the final
--  answer can be right while a step is not. The manifest in
--  the child unit names which. This package does not with
--  that child.
--
--  A solution is a few lines: a problem, one step per line,
--  and an answer. The answer-only grade looks at the answer.
--  The step grade is pass only when every step matches a
--  value this repository already computes, in order. The
--  page and steps_cli both call Grade.
--
--  The problems are the hand-written XOR forward pass, one
--  gradient step of that net, a Fibonacci chain checked with
--  AI_Amplifier.Recurse, and one vector Add. docs/CHECKED_STEPS.md
--  is the account of what this does not show.
package AI_Amplifier.Steps
  with SPARK_Mode => Off
is

   pragma Assertion_Policy (Pre => Check, Post => Check);

   Solution_Count : constant := 12;

   --  The page opens on xor-10-cancel, where two hidden
   --  values are wrong and the class is still right.
   Showcase : constant := 2;

   Max_Name   : constant := 16;
   Max_Line   : constant := 96;
   Max_Steps  : constant := 16;
   Max_Text   : constant := 2_400;
   Max_Note   : constant := 96;
   Tol        : constant := 0.000_05;

   --  A user file may ask for Fibonacci up to this index.
   --  F(12) is 144. The chain fits in Max_Steps.
   Fib_Limit : constant := 12;

   type Rule_Name is
     (None,
      Bad_Parse,
      Unknown_Problem,
      Unknown_Step,
      Bad_Value,
      Skipped_Step,
      Guessed_First,
      Wrong_Answer,
      Out_Of_Order,
      Bad_Arithmetic,
      Not_Toward_Base);

   type Mark is (Pass, Fail);

   type Row is record
      Text : String (1 .. Max_Line) := (others => ' ');
      Last : Natural := 0;
      OK   : Boolean := True;
      Rule : Rule_Name := None;
   end record;

   type Row_List is array (1 .. Max_Steps) of Row;

   type Report is record
      Name         : String (1 .. Max_Name) := (others => ' ');
      Name_Last    : Natural := 0;
      Answer_Grade : Mark := Fail;
      Step_Grade   : Mark := Fail;
      Bad_At       : Natural := 0;
      Rule         : Rule_Name := None;
      Count        : Natural := 0;
      Item         : Row_List;
   end record;

   --  Text is one solution. A blank line, and a line whose
   --  first visible character is '#', is ignored. Last on a
   --  row is 0 when the line was empty. Bad_At is the first
   --  row that breaks a rule, or 0 when every row holds.
   procedure Grade (Text : String; Item : out Report);

   --  The built-in solution. Last is 0 when Index is outside
   --  1 .. Solution_Count or Text is too short.
   procedure Built_In
     (Index : Natural;
      Text  : out String;
      Last  : out Natural);

   procedure Grade_Built_In (Index : Natural; Item : out Report);

   procedure Rule_Word
     (Rule : Rule_Name;
      Text : out String;
      Last : out Natural);

   procedure Mark_Word
     (Item : Mark;
      Text : out String;
      Last : out Natural);

   procedure Header_Line (Text : out String; Last : out Natural);

   procedure Line_For
     (Item : Report;
      Text : out String;
      Last : out Natural);

   procedure Stat_Line (Text : out String; Last : out Natural);

   --  The answer Recurse's rule produces for Index. OK is
   --  False when Index is above Fib_Limit. This walks
   --  Check_Step. It is not a second recurrence.
   procedure Fib_Answer
     (Index  : Natural;
      Value  : out Natural;
      OK     : out Boolean);

end AI_Amplifier.Steps;
