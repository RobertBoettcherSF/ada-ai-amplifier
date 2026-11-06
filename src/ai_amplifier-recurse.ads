--  Recursive state blobs, checked in Ada.
--
--  Plain Ada (SPARK_Mode off). Nothing here is proved. A failed
--  blob is a result, not an exception: the page module must not
--  trap on a bad recording.
--
--  The idea of a prompt that calls itself is described in
--  docs/RECURSIVE_PROMPTS.md. The linked repository has no
--  license. This unit does not copy its source or its wording.
--
--  One blob is three lines:
--    index <number>
--    minus-one <number>
--    current <number>
--  Blank lines, and lines whose first visible character is '#',
--  are ignored. A chain is blobs separated by a line '---'.
--
--  The opening blob is the seed for F(index):
--    index is the target, from 0 to Max_Index
--    minus-one is 0, which is F(0)
--    current is 1, which is F(1)
--  Each later blob has to be the next step toward index 0:
--    index becomes the previous index minus 1
--    minus-one becomes the previous current
--    current becomes the previous minus-one plus the previous
--      current
--  At index 0 the chain stops. The answer is minus-one, which is
--  F(target) when every step was the rule above. current is then
--  F(target + 1), except when the target was already 0: no step
--  runs, and current stays the unused seed 1.
--
--  The first failed check stops the chain. Order for a blob after
--  the opening: parse, then "already at the base", then "index
--  moved one step toward 0", then the two-value recurrence.
package AI_Amplifier.Recurse
  with SPARK_Mode => Off
is

   pragma Assertion_Policy (Pre => Check, Post => Check);

   --  F(20) is 6765 and F(21) is 10946, both under Max_Value.
   --  A component past Max_Value does not parse.
   Max_Index : constant := 20;
   Max_Value : constant := 20_000;

   --  A chain longer than this is refused before it is parsed.
   Max_Chain : constant := 4_000;

   --  One blob, including a short comment. A longer blob is an
   --  unreadable step.
   Max_Blob : constant := 480;

   --  States kept from one replay, including the opening.
   Max_Shown : constant := 24;

   Max_Prompt : constant := 700;
   Max_JSON   : constant := 1_600;
   Max_Note   : constant := 200;
   Max_Line   : constant := 80;
   Max_Name   : constant := 32;

   --  How many chains are recorded in this unit.
   Recorded : constant := 4;

   type State is record
      Fib_Index  : Natural := 0;
      Minus_One  : Natural := 0;
      Curr_Value : Natural := 0;
   end record;

   --  Accepted is a single step that is not yet the base case.
   --  It is not a reason for a whole chain to stop.
   type Check_Name is
     (Reached_Base,
      Bad_Parse,
      Bad_Opening,
      Not_Toward_Base,
      Bad_Arithmetic,
      Past_Base,
      Too_Long,
      Unfinished,
      Accepted);

   --  Mark is 0 for a step that was accepted, 1 for the base
   --  case, and 2 when this slot is where the chain stopped.
   type Slot is record
      Parsed     : Boolean := False;
      Fib_Index  : Natural := 0;
      Minus_One  : Natural := 0;
      Curr_Value : Natural := 0;
      Mark       : Natural := 2;
   end record;

   type Slot_Array is array (1 .. Max_Shown) of Slot;

   type Replay is record
      Stop     : Check_Name := Bad_Parse;
      Stop_At  : Natural := 0;
      Accepted : Natural := 0;
      Answer   : Natural := 0;
      Count    : Natural := 0;
      Item     : Slot_Array;
   end record;

   --  OK is False when the blob is not exactly the three fields,
   --  a number is missing, a field is repeated, or a number is
   --  outside 0 .. Max_Value. Item is then all zeroes.
   procedure Parse_State
     (Blob : String;
      Item : out State;
      OK   : out Boolean);

   --  Previous is a state that already parsed. Proposed is the
   --  next one. This does not look at text.
   procedure Check_Step
     (Previous : State;
      Proposed : State;
      Kind     : out Check_Name);

   --  OK is False when Index is above Max_Index. Otherwise Item
   --  is the opening seed for that index.
   procedure Make_Opening
     (Index : Natural;
      Item  : out State;
      OK    : out Boolean);

   procedure Check_Chain
     (Text   : String;
      Result : out Replay);

   --  Writes the chain the rules produce for Index. OK is False
   --  when Index is above Max_Index or Text is too short. Last
   --  is 0 in that case. Text is 1-based; Last is the last
   --  character written.
   procedure Correct_Chain
     (Index : Natural;
      Text  : out String;
      Last  : out Natural;
      OK    : out Boolean);

   function Chain_Count return Natural;

   procedure Chain_Name
     (Index : Natural;
      Text  : out String;
      Last  : out Natural);

   procedure Chain_Body
     (Index : Natural;
      Text  : out String;
      Last  : out Natural);

   procedure Replay_Recorded
     (Index  : Natural;
      Result : out Replay;
      OK     : out Boolean);

   --  Hyphenated word: reached-base, bad-parse, and the rest.
   --  Last is 0 when Text is too short. Text is 1-based.
   procedure Kind_Word
     (Kind : Check_Name;
      Text : out String;
      Last : out Natural);

   procedure Describe
     (Result : Replay;
      Text   : out String;
      Last   : out Natural);

   --  One visible line for a stored state. An unparsed slot is
   --  the line "unreadable  halt". Last is 0 when Index is not
   --  one of the stored states or Text is too short.
   procedure Step_Line
     (Result : Replay;
      Index  : Natural;
      Text   : out String;
      Last   : out Natural);

   procedure Prompt_For
     (From : State;
      Text : out String;
      Last : out Natural;
      OK   : out Boolean);

   --  OpenAI-shaped chat body. Model and Prompt are escaped.
   --  Temperature is 0. OK is False when the body does not fit.
   procedure Request_JSON
     (Model  : String;
      Prompt : String;
      Text   : out String;
      Last   : out Natural;
      OK     : out Boolean);

   --  The first JSON string after the field name content.
   --  Known escapes are quotes, backslash, slash, and the
   --  three single-letter controls. Anything else fails.
   procedure Assistant_Text
     (Reply : String;
      Text  : out String;
      Last  : out Natural;
      OK    : out Boolean);

   --  Page and CLI share these numbers so a stop is not a
   --  renamed enum position.
   function Stop_Code (Kind : Check_Name) return Integer;

end AI_Amplifier.Recurse;
