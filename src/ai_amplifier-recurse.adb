with AI_Amplifier.Chain_Rule;

package body AI_Amplifier.Recurse
  with SPARK_Mode => Off
is

   LF  : constant Character := Character'Val (10);
   CR  : constant Character := Character'Val (13);
   Tab : constant Character := Character'Val (9);

   function Chain_Count return Natural is (Recorded);

   function Stop_Code (Kind : Check_Name) return Integer is
   begin
      case Kind is
         when Reached_Base =>
            return 0;
         when Bad_Parse =>
            return 1;
         when Bad_Opening =>
            return 2;
         when Not_Toward_Base =>
            return 3;
         when Bad_Arithmetic =>
            return 4;
         when Past_Base =>
            return 5;
         when Too_Long =>
            return 6;
         when Unfinished =>
            return 7;
         when Accepted =>
            return 8;
      end case;
   end Stop_Code;

   procedure Append
     (Dest : in out String;
      Last : in out Natural;
      Item : String;
      OK   : in out Boolean)
   is
   begin
      if not OK or else Item'Length = 0 then
         return;
      end if;
      if Last > Dest'Last
        or else Item'Length > Dest'Last - Last
      then
         OK := False;
         return;
      end if;
      Dest (Last + 1 .. Last + Item'Length) := Item;
      Last := Last + Item'Length;
   end Append;

   procedure Put_Natural
     (Dest  : in out String;
      Last  : in out Natural;
      Value : Natural;
      OK    : in out Boolean)
   is
      Digs : String (1 .. 12) := (others => '0');
      N    : Natural := Value;
      Top  : Natural := Digs'Last + 1;
   begin
      if not OK then
         return;
      end if;
      loop
         Top := Top - 1;
         Digs (Top) :=
           Character'Val (Character'Pos ('0') + N mod 10);
         N := N / 10;
         exit when N = 0;
      end loop;
      Append (Dest, Last, Digs (Top .. Digs'Last), OK);
   end Put_Natural;

   procedure Next_Line
     (Text  : String;
      Pos   : in out Natural;
      First : out Natural;
      Last  : out Natural;
      Got   : out Boolean)
   is
      I : Natural;
   begin
      Got := False;
      First := 1;
      Last := 0;
      if Pos < Text'First or else Pos > Text'Last then
         return;
      end if;
      I := Pos;
      while I <= Text'Last and then Text (I) /= LF loop
         I := I + 1;
      end loop;
      First := Pos;
      if I > Pos and then Text (I - 1) = CR then
         if I - 1 = Pos then
            Last := First - 1;
         else
            Last := I - 2;
         end if;
      elsif I = Pos then
         Last := First - 1;
      else
         Last := I - 1;
      end if;
      if I <= Text'Last and then Text (I) = LF then
         Pos := I + 1;
      else
         Pos := Text'Last + 1;
      end if;
      Got := True;
   end Next_Line;

   --  Character by character. A slice compare pulls in memcmp,
   --  and this wasm link does not have that symbol.
   function Equal_At
     (Text  : String;
      First : Natural;
      Key   : String) return Boolean
   is
      Offset : Natural;
   begin
      if Key'Length = 0 or else First < Text'First then
         return False;
      end if;
      if First > Text'Last
        or else Text'Last - First < Key'Length - 1
      then
         return False;
      end if;
      for J in Key'Range loop
         Offset := First + (J - Key'First);
         if Text (Offset) /= Key (J) then
            return False;
         end if;
      end loop;
      return True;
   end Equal_At;

   function Skip_Space
     (Text  : String;
      First : Natural;
      Last  : Natural) return Natural
   is
      I : Natural := First;
   begin
      if Last < First then
         return First;
      end if;
      while I <= Last
        and then (Text (I) = ' ' or else Text (I) = Tab)
      loop
         I := I + 1;
      end loop;
      return I;
   end Skip_Space;

   function Blank_Range
     (Text  : String;
      First : Natural;
      Last  : Natural) return Boolean
   is
   begin
      if Last < First then
         return True;
      end if;
      return Skip_Space (Text, First, Last) > Last;
   end Blank_Range;

   function Comment_Range
     (Text  : String;
      First : Natural;
      Last  : Natural) return Boolean
   is
      I : Natural;
   begin
      if Last < First then
         return False;
      end if;
      I := Skip_Space (Text, First, Last);
      return I <= Last and then Text (I) = '#';
   end Comment_Range;

   function Separator_Range
     (Text  : String;
      First : Natural;
      Last  : Natural) return Boolean
   is
      I : Natural;
   begin
      if Last < First then
         return False;
      end if;
      I := Skip_Space (Text, First, Last);
      if Last - I + 1 < 3 then
         return False;
      end if;
      if not Equal_At (Text, I, "---") then
         return False;
      end if;
      return Blank_Range (Text, I + 3, Last);
   end Separator_Range;

   procedure Parse_Number
     (Text  : String;
      From  : in out Natural;
      Limit : Natural;
      Value : out Natural;
      OK    : out Boolean)
   is
      Acc   : Natural := 0;
      Digit : Natural;
      Seen  : Boolean := False;
   begin
      Value := 0;
      OK := False;
      if From < Text'First or else From > Text'Last then
         return;
      end if;
      while From <= Text'Last
        and then Text (From) in '0' .. '9'
      loop
         Seen := True;
         Digit :=
           Character'Pos (Text (From)) - Character'Pos ('0');
         if Acc > (Limit - Digit) / 10 then
            return;
         end if;
         Acc := Acc * 10 + Digit;
         From := From + 1;
      end loop;
      if Seen then
         Value := Acc;
         OK := True;
      end if;
   end Parse_Number;

   procedure Match_Key
     (Text  : String;
      First : Natural;
      Last  : Natural;
      Key   : String;
      Value : out Natural;
      Match : out Boolean;
      Well  : out Boolean)
   is
      I    : Natural;
      Num  : Natural;
      Good : Boolean;
   begin
      Value := 0;
      Match := False;
      Well := False;
      if Last < First then
         return;
      end if;
      I := Skip_Space (Text, First, Last);
      if I > Last or else Last - I + 1 < Key'Length then
         return;
      end if;
      if not Equal_At (Text, I, Key) then
         return;
      end if;
      Match := True;
      I := I + Key'Length;
      if I > Last
        or else (Text (I) /= ' ' and then Text (I) /= Tab)
      then
         return;
      end if;
      I := Skip_Space (Text, I, Last);
      Parse_Number (Text, I, Max_Value, Num, Good);
      if not Good or else not Blank_Range (Text, I, Last) then
         return;
      end if;
      Value := Num;
      Well := True;
   end Match_Key;

   procedure Parse_State
     (Blob : String;
      Item : out State;
      OK   : out Boolean)
   is
      Pos                            : Natural := Blob'First;
      First, Last                    : Natural;
      Got                            : Boolean;
      Saw_I, Saw_M, Saw_C            : Boolean := False;
      Index_V, Minus_V, Current_V    : Natural := 0;
      Value                          : Natural;
      Match, Well                    : Boolean;
   begin
      Item := (0, 0, 0);
      OK := False;
      if Blob'Length = 0 then
         return;
      end if;
      loop
         Next_Line (Blob, Pos, First, Last, Got);
         exit when not Got;
         if not Blank_Range (Blob, First, Last)
           and then not Comment_Range (Blob, First, Last)
         then
            Match_Key
              (Blob, First, Last, "index", Value, Match, Well);
            if Match then
               if not Well or else Saw_I then
                  return;
               end if;
               Saw_I := True;
               Index_V := Value;
            else
               Match_Key
                 (Blob, First, Last, "minus-one",
                  Value, Match, Well);
               if Match then
                  if not Well or else Saw_M then
                     return;
                  end if;
                  Saw_M := True;
                  Minus_V := Value;
               else
                  Match_Key
                    (Blob, First, Last, "current",
                     Value, Match, Well);
                  if not Match or else not Well or else Saw_C then
                     return;
                  end if;
                  Saw_C := True;
                  Current_V := Value;
               end if;
            end if;
         end if;
      end loop;
      if Saw_I and then Saw_M and then Saw_C then
         Item := (Index_V, Minus_V, Current_V);
         OK := True;
      end if;
   end Parse_State;

   procedure Check_Step
     (Previous : State;
      Proposed : State;
      Kind     : out Check_Name)
   is
      function To_Rule (Item : State) return Chain_Rule.State is
        (Fib_Index  => Item.Fib_Index,
         Minus_One  => Item.Minus_One,
         Curr_Value => Item.Curr_Value);
   begin
      --  The proved rule and this package share one bound.
      pragma Assert (Max_Value = Chain_Rule.Max_Value);
      if Previous.Minus_One > Chain_Rule.Max_Value
        or else Previous.Curr_Value > Chain_Rule.Max_Value
        or else Proposed.Minus_One > Chain_Rule.Max_Value
        or else Proposed.Curr_Value > Chain_Rule.Max_Value
      then
         Kind := Bad_Arithmetic;
         return;
      end if;
      case Chain_Rule.Classify (To_Rule (Previous), To_Rule (Proposed)) is
         when Chain_Rule.Past_Base =>
            Kind := Past_Base;
         when Chain_Rule.Not_Toward_Base =>
            Kind := Not_Toward_Base;
         when Chain_Rule.Bad_Arithmetic =>
            Kind := Bad_Arithmetic;
         when Chain_Rule.Reached_Base =>
            Kind := Reached_Base;
         when Chain_Rule.Accepted =>
            Kind := Accepted;
      end case;
   end Check_Step;

   procedure Make_Opening
     (Index : Natural;
      Item  : out State;
      OK    : out Boolean)
   is
   begin
      Item := (0, 0, 0);
      OK := Index <= Max_Index;
      if OK then
         Item := (Fib_Index => Index, Minus_One => 0, Curr_Value => 1);
      end if;
   end Make_Opening;

   function Opening_OK (Item : State) return Boolean is
     (Item.Fib_Index <= Max_Index
      and then Item.Minus_One = 0
      and then Item.Curr_Value = 1);

   procedure Store
     (Result : in out Replay;
      Item   : State;
      Parsed : Boolean;
      Mark   : Natural)
   is
   begin
      Result.Count := Result.Count + 1;
      Result.Item (Result.Count) :=
        (Parsed => Parsed,
         Fib_Index => Item.Fib_Index,
         Minus_One => Item.Minus_One,
         Curr_Value => Item.Curr_Value,
         Mark => Mark);
   end Store;

   procedure Take_Blob
     (Text     : String;
      Pos      : in out Natural;
      Blob     : out String;
      Last     : out Natural;
      Overflow : out Boolean;
      Got      : out Boolean)
   is
      First, Line_Last : Natural;
      Line_Got         : Boolean;
      Fit              : Boolean := True;
      Cursor           : Natural := 0;
   begin
      Last := 0;
      Overflow := False;
      Got := Pos >= Text'First and then Pos <= Text'Last;
      if not Got then
         return;
      end if;
      loop
         Next_Line (Text, Pos, First, Line_Last, Line_Got);
         exit when not Line_Got;
         if Separator_Range (Text, First, Line_Last) then
            exit;
         end if;
         if Line_Last >= First then
            if Fit
              and then Line_Last - First + 1 <= Blob'Last - Cursor
            then
               Blob (Cursor + 1 .. Cursor + (Line_Last - First + 1)) :=
                 Text (First .. Line_Last);
               Cursor := Cursor + (Line_Last - First + 1);
            else
               Fit := False;
            end if;
         end if;
         if Fit and then 1 <= Blob'Last - Cursor then
            Cursor := Cursor + 1;
            Blob (Cursor) := LF;
         else
            Fit := False;
         end if;
      end loop;
      Last := Cursor;
      Overflow := not Fit;
   end Take_Blob;

   procedure Check_Chain
     (Text   : String;
      Result : out Replay)
   is
      Pos       : Natural := Text'First;
      Blob      : String (1 .. Max_Blob);
      BLast     : Natural;
      Overflow  : Boolean;
      Got       : Boolean;
      Seen      : Boolean := False;
      Have_Prev : Boolean := False;
      Previous  : State := (0, 0, 0);
      Item      : State;
      Parsed    : Boolean;
      Kind      : Check_Name;
   begin
      Result :=
        (Stop => Bad_Parse,
         Stop_At => 0,
         Accepted => 0,
         Answer => 0,
         Count => 0,
         Item => (others => <>));
      if Text'Length > Max_Chain then
         Result.Stop := Too_Long;
         Result.Stop_At := 0;
         return;
      end if;
      if Text'Length = 0 then
         return;
      end if;
      loop
         Take_Blob (Text, Pos, Blob, BLast, Overflow, Got);
         exit when not Got;
         Seen := True;
         if Result.Count = Max_Shown then
            Result.Stop := Too_Long;
            Result.Stop_At := Result.Count;
            exit;
         end if;
         if Overflow or else BLast = 0 then
            Store (Result, (0, 0, 0), False, 2);
            Result.Stop := Bad_Parse;
            Result.Stop_At := Result.Count;
            exit;
         end if;
         Parse_State (Blob (1 .. BLast), Item, Parsed);
         if not Parsed then
            Store (Result, (0, 0, 0), False, 2);
            Result.Stop := Bad_Parse;
            Result.Stop_At := Result.Count;
            exit;
         end if;
         if not Have_Prev then
            Have_Prev := True;
            Previous := Item;
            if not Opening_OK (Item) then
               Store (Result, Item, True, 2);
               Result.Stop := Bad_Opening;
               Result.Stop_At := Result.Count;
               exit;
            end if;
            if Item.Fib_Index = 0 then
               Store (Result, Item, True, 1);
               Result.Stop := Reached_Base;
               Result.Answer := Item.Minus_One;
               Result.Stop_At := Result.Count;
            else
               Store (Result, Item, True, 0);
               Result.Stop := Unfinished;
               Result.Stop_At := Result.Count;
            end if;
         else
            Check_Step (Previous, Item, Kind);
            case Kind is
               when Accepted =>
                  Store (Result, Item, True, 0);
                  Previous := Item;
                  Result.Accepted := Result.Accepted + 1;
                  Result.Stop := Unfinished;
                  Result.Stop_At := Result.Count;
               when Reached_Base =>
                  Store (Result, Item, True, 1);
                  Previous := Item;
                  Result.Accepted := Result.Accepted + 1;
                  Result.Stop := Reached_Base;
                  Result.Answer := Item.Minus_One;
                  Result.Stop_At := Result.Count;
               when others =>
                  Store (Result, Item, True, 2);
                  Result.Stop := Kind;
                  Result.Stop_At := Result.Count;
                  exit;
            end case;
         end if;
      end loop;
      if not Seen then
         Result.Stop := Bad_Parse;
         Result.Stop_At := 0;
         Result.Count := 0;
      end if;
   end Check_Chain;

   procedure Append_State
     (Item : State;
      Text : in out String;
      Last : in out Natural;
      OK   : in out Boolean)
   is
   begin
      Append (Text, Last, "index ", OK);
      Put_Natural (Text, Last, Item.Fib_Index, OK);
      Append (Text, Last, (1 => LF) & "minus-one ", OK);
      Put_Natural (Text, Last, Item.Minus_One, OK);
      Append (Text, Last, (1 => LF) & "current ", OK);
      Put_Natural (Text, Last, Item.Curr_Value, OK);
      Append (Text, Last, (1 => LF), OK);
   end Append_State;

   procedure Correct_Chain
     (Index : Natural;
      Text  : out String;
      Last  : out Natural;
      OK    : out Boolean)
   is
      Item : State;
      Next : State;
      Kind : Check_Name;
   begin
      Last := 0;
      OK := False;
      Make_Opening (Index, Item, OK);
      if not OK then
         return;
      end if;
      Append_State (Item, Text, Last, OK);
      while OK and then Item.Fib_Index > 0 loop
         Next :=
           (Fib_Index => Item.Fib_Index - 1,
            Minus_One => Item.Curr_Value,
            Curr_Value => Item.Minus_One + Item.Curr_Value);
         Check_Step (Item, Next, Kind);
         if Kind /= Accepted and then Kind /= Reached_Base then
            OK := False;
            Last := 0;
            return;
         end if;
         Append (Text, Last, "---" & (1 => LF), OK);
         Append_State (Next, Text, Last, OK);
         Item := Next;
      end loop;
      if not OK then
         Last := 0;
      end if;
   end Correct_Chain;

   procedure Copy_Name
     (Source : String;
      Text   : out String;
      Last   : out Natural)
   is
      Fit : Boolean := True;
   begin
      Last := 0;
      Append (Text, Last, Source, Fit);
      if not Fit then
         Last := 0;
      end if;
   end Copy_Name;

   procedure Chain_Name
     (Index : Natural;
      Text  : out String;
      Last  : out Natural)
   is
   begin
      Last := 0;
      case Index is
         when 1 =>
            Copy_Name ("fib-6-complete", Text, Last);
         when 2 =>
            Copy_Name ("fib-6-bad-sum", Text, Last);
         when 3 =>
            Copy_Name ("fib-4-stalled", Text, Last);
         when 4 =>
            Copy_Name ("fib-3-garbled", Text, Last);
         when others =>
            null;
      end case;
   end Chain_Name;

   procedure Chain_Body
     (Index : Natural;
      Text  : out String;
      Last  : out Natural)
   is
      OK : Boolean := True;
   begin
      Last := 0;
      case Index is
         when 1 =>
            --  Written out, not produced by Correct_Chain, so a
            --  drift in the generator is visible to the test.
            Append
              (Text, Last,
               "index 6" & LF
               & "minus-one 0" & LF
               & "current 1" & LF
               & "---" & LF
               & "index 5" & LF
               & "minus-one 1" & LF
               & "current 1" & LF
               & "---" & LF
               & "index 4" & LF
               & "minus-one 1" & LF
               & "current 2" & LF
               & "---" & LF
               & "index 3" & LF
               & "minus-one 2" & LF
               & "current 3" & LF
               & "---" & LF
               & "index 2" & LF
               & "minus-one 3" & LF
               & "current 5" & LF
               & "---" & LF
               & "index 1" & LF
               & "minus-one 5" & LF
               & "current 8" & LF
               & "---" & LF
               & "index 0" & LF
               & "minus-one 8" & LF
               & "current 13" & LF,
               OK);
            if not OK then
               Last := 0;
            end if;
         when 2 =>
            --  Same walk as fib-6 until the step that should
            --  carry current 3. The written current is 4.
            Append
              (Text, Last,
               "index 6" & LF
               & "minus-one 0" & LF
               & "current 1" & LF
               & "---" & LF
               & "index 5" & LF
               & "minus-one 1" & LF
               & "current 1" & LF
               & "---" & LF
               & "index 4" & LF
               & "minus-one 1" & LF
               & "current 2" & LF
               & "---" & LF
               & "index 3" & LF
               & "minus-one 2" & LF
               & "current 4" & LF,
               OK);
            if not OK then
               Last := 0;
            end if;
         when 3 =>
            --  The values are the successor pair. The index
            --  stays 4, so the chain is not closer to 0.
            Append
              (Text, Last,
               "index 4" & LF
               & "minus-one 0" & LF
               & "current 1" & LF
               & "---" & LF
               & "index 4" & LF
               & "minus-one 1" & LF
               & "current 1" & LF,
               OK);
            if not OK then
               Last := 0;
            end if;
         when 4 =>
            Append
              (Text, Last,
               "index 3" & LF
               & "minus-one 0" & LF
               & "current 1" & LF
               & "---" & LF
               & "index 2" & LF
               & "minus-one 1" & LF
               & "current 1" & LF
               & "---" & LF
               & "index two" & LF
               & "minus-one 1" & LF
               & "current 2" & LF,
               OK);
            if not OK then
               Last := 0;
            end if;
         when others =>
            null;
      end case;
   end Chain_Body;

   procedure Replay_Recorded
     (Index  : Natural;
      Result : out Replay;
      OK     : out Boolean)
   is
      Body_Text : String (1 .. Max_Chain);
      BLast     : Natural;
   begin
      Result :=
        (Stop => Bad_Parse,
         Stop_At => 0,
         Accepted => 0,
         Answer => 0,
         Count => 0,
         Item => (others => <>));
      OK := Index in 1 .. Recorded;
      if not OK then
         return;
      end if;
      Chain_Body (Index, Body_Text, BLast);
      if BLast = 0 then
         OK := False;
         return;
      end if;
      Check_Chain (Body_Text (1 .. BLast), Result);
   end Replay_Recorded;

   procedure Kind_Word
     (Kind : Check_Name;
      Text : out String;
      Last : out Natural)
   is
   begin
      case Kind is
         when Reached_Base =>
            Copy_Name ("reached-base", Text, Last);
         when Bad_Parse =>
            Copy_Name ("bad-parse", Text, Last);
         when Bad_Opening =>
            Copy_Name ("bad-opening", Text, Last);
         when Not_Toward_Base =>
            Copy_Name ("not-toward-base", Text, Last);
         when Bad_Arithmetic =>
            Copy_Name ("bad-arithmetic", Text, Last);
         when Past_Base =>
            Copy_Name ("past-base", Text, Last);
         when Too_Long =>
            Copy_Name ("too-long", Text, Last);
         when Unfinished =>
            Copy_Name ("unfinished", Text, Last);
         when Accepted =>
            Copy_Name ("accepted", Text, Last);
      end case;
   end Kind_Word;

   procedure Sentence
     (Kind : Check_Name;
      Text : out String;
      Last : out Natural)
   is
   begin
      case Kind is
         when Bad_Parse =>
            Copy_Name ("bad parse", Text, Last);
         when Bad_Opening =>
            Copy_Name ("bad opening", Text, Last);
         when Not_Toward_Base =>
            Copy_Name ("not toward base", Text, Last);
         when Bad_Arithmetic =>
            Copy_Name ("bad arithmetic", Text, Last);
         when Past_Base =>
            Copy_Name ("past base", Text, Last);
         when Too_Long =>
            Copy_Name ("too long", Text, Last);
         when others =>
            Last := 0;
      end case;
   end Sentence;

   procedure Describe
     (Result : Replay;
      Text   : out String;
      Last   : out Natural)
   is
      OK    : Boolean := True;
      Words : String (1 .. 40);
      WLast : Natural;
   begin
      Last := 0;
      case Result.Stop is
         when Reached_Base =>
            Append
              (Text, Last,
               "Reached the base case. minus-one is ", OK);
            Put_Natural (Text, Last, Result.Answer, OK);
            Append (Text, Last, " after ", OK);
            Put_Natural (Text, Last, Result.Accepted, OK);
            Append (Text, Last, " accepted steps.", OK);
         when Unfinished =>
            Append (Text, Last, "Stopped at state ", OK);
            Put_Natural (Text, Last, Result.Stop_At, OK);
            Append
              (Text, Last,
               ". The chain ended before the base case.", OK);
         when Too_Long =>
            if Result.Stop_At = 0 then
               Append
                 (Text, Last,
                  "Stopped before the first state. "
                  & "The check that failed is too long.",
                  OK);
            else
               Append (Text, Last, "Stopped at state ", OK);
               Put_Natural (Text, Last, Result.Stop_At, OK);
               Append
                 (Text, Last,
                  ". The check that failed is too long.", OK);
            end if;
         when Accepted =>
            Append (Text, Last, "The chain is still open.", OK);
         when others =>
            Sentence (Result.Stop, Words, WLast);
            Append (Text, Last, "Stopped at state ", OK);
            Put_Natural (Text, Last, Result.Stop_At, OK);
            Append
              (Text, Last, ". The check that failed is ", OK);
            if WLast >= 1 then
               Append (Text, Last, Words (1 .. WLast), OK);
            end if;
            Append (Text, Last, ".", OK);
      end case;
      if not OK then
         Last := 0;
      end if;
   end Describe;

   procedure Step_Line
     (Result : Replay;
      Index  : Natural;
      Text   : out String;
      Last   : out Natural)
   is
      OK   : Boolean := True;
      One  : Slot;
   begin
      Last := 0;
      if Index < 1 or else Index > Result.Count then
         return;
      end if;
      One := Result.Item (Index);
      if not One.Parsed then
         Append (Text, Last, "unreadable  halt", OK);
      else
         Append (Text, Last, "index ", OK);
         Put_Natural (Text, Last, One.Fib_Index, OK);
         Append (Text, Last, "  minus-one ", OK);
         Put_Natural (Text, Last, One.Minus_One, OK);
         Append (Text, Last, "  current ", OK);
         Put_Natural (Text, Last, One.Curr_Value, OK);
         Append (Text, Last, "  ", OK);
         if One.Mark = 0 then
            Append (Text, Last, "ok", OK);
         elsif One.Mark = 1 then
            Append (Text, Last, "base", OK);
         else
            Append (Text, Last, "halt", OK);
         end if;
      end if;
      if not OK then
         Last := 0;
      end if;
   end Step_Line;

   procedure Prompt_For
     (From : State;
      Text : out String;
      Last : out Natural;
      OK   : out Boolean)
   is
   begin
      Last := 0;
      OK := True;
      Append
        (Text, Last,
         "Continue this Fibonacci state one step toward"
         & " the base case." & LF
         & "The base case is index 0. Reply with exactly"
         & " three lines and nothing else:" & LF
         & "index <number>" & LF
         & "minus-one <number>" & LF
         & "current <number>" & LF
         & "index must be one less than it is now." & LF
         & "minus-one must become the current value." & LF
         & "current must become the sum of minus-one"
         & " and current." & LF
         & "Do not reply with a further step when index"
         & " is already 0." & LF
         & LF
         & "State:" & LF,
         OK);
      Append_State (From, Text, Last, OK);
      if not OK then
         Last := 0;
      end if;
   end Prompt_For;

   procedure Append_JSON_String
     (Source : String;
      Dest   : in out String;
      Last   : in out Natural;
      OK     : in out Boolean)
   is
      Hex : constant String := "0123456789abcdef";
      Code : Natural;
   begin
      Append (Dest, Last, """", OK);
      for C of Source loop
         exit when not OK;
         if C = '"' then
            Append (Dest, Last, "\""", OK);
         elsif C = '\' then
            Append (Dest, Last, "\\", OK);
         elsif C = LF then
            Append (Dest, Last, "\n", OK);
         elsif C = CR then
            Append (Dest, Last, "\r", OK);
         elsif C = Tab then
            Append (Dest, Last, "\t", OK);
         elsif Character'Pos (C) < 32
           or else Character'Pos (C) > 126
         then
            Code := Character'Pos (C);
            Append (Dest, Last, "\u00", OK);
            Append
              (Dest, Last,
               Hex (Hex'First + Code / 16)
               & Hex (Hex'First + Code mod 16),
               OK);
         else
            Append (Dest, Last, (1 => C), OK);
         end if;
      end loop;
      Append (Dest, Last, """", OK);
   end Append_JSON_String;

   procedure Request_JSON
     (Model  : String;
      Prompt : String;
      Text   : out String;
      Last   : out Natural;
      OK     : out Boolean)
   is
   begin
      Last := 0;
      OK := True;
      Append (Text, Last, "{""model"":", OK);
      Append_JSON_String (Model, Text, Last, OK);
      Append
        (Text, Last,
         ",""temperature"":0,""messages"":[{""role"":""user"""
         & ",""content"":",
         OK);
      Append_JSON_String (Prompt, Text, Last, OK);
      Append (Text, Last, "}]}", OK);
      if not OK then
         Last := 0;
      end if;
   end Request_JSON;

   function Hex_Value (C : Character) return Integer is
   begin
      if C in '0' .. '9' then
         return Character'Pos (C) - Character'Pos ('0');
      elsif C in 'a' .. 'f' then
         return Character'Pos (C) - Character'Pos ('a') + 10;
      elsif C in 'A' .. 'F' then
         return Character'Pos (C) - Character'Pos ('A') + 10;
      else
         return -1;
      end if;
   end Hex_Value;

   procedure Assistant_Text
     (Reply : String;
      Text  : out String;
      Last  : out Natural;
      OK    : out Boolean)
   is
      Key    : constant String := """content""";
      Scan   : Natural := Reply'First;
      I      : Natural;
      Found  : Boolean := False;
      Code   : Integer;
      Fit    : Boolean := True;
   begin
      Last := 0;
      OK := False;
      while Scan + Key'Length - 1 <= Reply'Last loop
         if Equal_At (Reply, Scan, Key) then
            Found := True;
            Scan := Scan + Key'Length;
            exit;
         end if;
         Scan := Scan + 1;
      end loop;
      if not Found then
         return;
      end if;
      while Scan <= Reply'Last
        and then (Reply (Scan) = ' ' or else Reply (Scan) = Tab
                  or else Reply (Scan) = LF or else Reply (Scan) = CR)
      loop
         Scan := Scan + 1;
      end loop;
      if Scan > Reply'Last or else Reply (Scan) /= ':' then
         return;
      end if;
      Scan := Scan + 1;
      while Scan <= Reply'Last
        and then (Reply (Scan) = ' ' or else Reply (Scan) = Tab
                  or else Reply (Scan) = LF or else Reply (Scan) = CR)
      loop
         Scan := Scan + 1;
      end loop;
      if Scan > Reply'Last or else Reply (Scan) /= '"' then
         return;
      end if;
      Scan := Scan + 1;
      while Scan <= Reply'Last loop
         if Reply (Scan) = '"' then
            OK := Fit;
            if not OK then
               Last := 0;
            end if;
            return;
         elsif Reply (Scan) = '\' then
            if Scan = Reply'Last then
               return;
            end if;
            Scan := Scan + 1;
            if Reply (Scan) = '"' or else Reply (Scan) = '\'
              or else Reply (Scan) = '/'
            then
               Append (Text, Last, (1 => Reply (Scan)), Fit);
            elsif Reply (Scan) = 'n' then
               Append (Text, Last, (1 => LF), Fit);
            elsif Reply (Scan) = 'r' then
               Append (Text, Last, (1 => CR), Fit);
            elsif Reply (Scan) = 't' then
               Append (Text, Last, (1 => Tab), Fit);
            elsif Reply (Scan) = 'u' then
               if Scan + 4 > Reply'Last then
                  return;
               end if;
               Code := 0;
               for K in 1 .. 4 loop
                  Scan := Scan + 1;
                  if Hex_Value (Reply (Scan)) < 0 then
                     return;
                  end if;
                  Code := Code * 16 + Hex_Value (Reply (Scan));
               end loop;
               if Code > 255 then
                  return;
               end if;
               Append
                 (Text, Last,
                  (1 => Character'Val (Code)), Fit);
            else
               return;
            end if;
         elsif Character'Pos (Reply (Scan)) < 32 then
            return;
         else
            Append (Text, Last, (1 => Reply (Scan)), Fit);
         end if;
         if not Fit then
            return;
         end if;
         I := Scan + 1;
         Scan := I;
      end loop;
   end Assistant_Text;

end AI_Amplifier.Recurse;
