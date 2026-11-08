with AI_Amplifier.Recurse;
with AI_Amplifier.Traces;

package body AI_Amplifier.Harness
  with SPARK_Mode => Off
is

   package R renames AI_Amplifier.Recurse;
   package T renames AI_Amplifier.Traces;
   use type R.Check_Name;
   use type T.Reason_Kind;
   use type T.Verdict_Kind;

   LF : constant Character := Character'Val (10);

   function Harness_Code (Which : Harness_Name) return Integer is
   begin
      case Which is
         when One_Shot =>
            return 1;
         when Retry =>
            return 2;
         when Checked =>
            return 3;
         when Budgeted =>
            return 4;
      end case;
   end Harness_Code;

   procedure Add
     (Buf  : in out String;
      Last : in out Natural;
      Item : String;
      OK   : in out Boolean)
   is
   begin
      if not OK or else Item'Length = 0 then
         return;
      end if;
      if Last > Buf'Last
        or else Item'Length > Buf'Last - Last
      then
         OK := False;
         return;
      end if;
      Buf (Last + 1 .. Last + Item'Length) := Item;
      Last := Last + Item'Length;
   end Add;

   procedure Put_Nat
     (Buf   : in out String;
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
      Add (Buf, Last, Digs (Top .. Digs'Last), OK);
   end Put_Nat;

   --  Character by character. A slice compare pulls in memcmp,
   --  and this wasm link does not have that symbol.
   function Same (Left, Right : String) return Boolean is
      Offset : Natural;
   begin
      if Left'Length /= Right'Length then
         return False;
      end if;
      for I in Left'Range loop
         Offset := Right'First + (I - Left'First);
         if Left (I) /= Right (Offset) then
            return False;
         end if;
      end loop;
      return True;
   end Same;

   procedure Put_Word
     (Text : out String;
      Last : out Natural;
      Item : String)
   is
      OK : Boolean := True;
   begin
      Last := 0;
      if Text'Length = 0 then
         return;
      end if;
      Add (Text, Last, Item, OK);
      if not OK then
         Last := 0;
      end if;
   end Put_Word;

   procedure Harness_Word
     (Which : Harness_Name;
      Text  : out String;
      Last  : out Natural)
   is
   begin
      case Which is
         when One_Shot =>
            Put_Word (Text, Last, "one-shot");
         when Retry =>
            Put_Word (Text, Last, "retry");
         when Checked =>
            Put_Word (Text, Last, "checked");
         when Budgeted =>
            Put_Word (Text, Last, "budgeted");
      end case;
   end Harness_Word;

   procedure Task_Name
     (Index : Natural;
      Text  : out String;
      Last  : out Natural)
   is
   begin
      case Index is
         when 1 =>
            Put_Word (Text, Last, "fib-1");
         when 2 =>
            Put_Word (Text, Last, "fib-3");
         when 3 =>
            Put_Word (Text, Last, "fib-4");
         when 4 =>
            Put_Word (Text, Last, "fib-6");
         when 5 =>
            Put_Word (Text, Last, "rate-diverges");
         when 6 =>
            Put_Word (Text, Last, "padded-shape");
         when 7 =>
            Put_Word (Text, Last, "silenced-and");
         when 8 =>
            Put_Word (Text, Last, "stopped-early");
         when others =>
            Last := 0;
      end case;
   end Task_Name;

   function Is_Fib (Index : Natural) return Boolean is
     (Index in 1 .. 4);

   function Fib_Target (Index : Natural) return Natural is
   begin
      case Index is
         when 1 =>
            return 1;
         when 2 =>
            return 3;
         when 3 =>
            return 4;
         when 4 =>
            return 6;
         when others =>
            return 0;
      end case;
   end Fib_Target;

   function Trace_Index (Index : Natural) return Natural is
   begin
      if Index in 5 .. 8 then
         return Index - 4;
      end if;
      return 0;
   end Trace_Index;

   function Expected_Answer (Index : Natural) return Natural is
      Target : constant Natural := Fib_Target (Index);
      A      : Natural := 0;
      B      : Natural := 1;
   begin
      if Target = 0 then
         return 0;
      end if;
      for Step in 2 .. Target loop
         declare
            Sum : constant Natural := A + B;
         begin
            A := B;
            B := Sum;
         end;
      end loop;
      return B;
   end Expected_Answer;

   function Contains (Note : String; Word : String) return Boolean is
      Need : constant Natural := Word'Length;
   begin
      if Need = 0 or else Note'Length < Need then
         return False;
      end if;
      for I in Note'First .. Note'Last - Need + 1 loop
         if Same (Note (I .. I + Need - 1), Word) then
            return True;
         end if;
      end loop;
      return False;
   end Contains;

   function Trace_Feedback (Note : String) return Boolean is
     (Contains (Note, "makes-it-worse")
      or else Contains (Note, "no-better")
      or else Contains (Note, "not-a-step"));

   procedure Proposal_Text
     (Which : T.Proposal;
      Text  : out String;
      Last  : out Natural)
   is
      Buf : String (1 .. T.Max_Name);
   begin
      T.Proposal_Word (Which, Buf, Last);
      if Last < 1 or else Last > Text'Length then
         Last := 0;
         return;
      end if;
      Text (Text'First .. Text'First + Last - 1) := Buf (1 .. Last);
   end Proposal_Text;

   procedure Menu_Bad
     (Index : Natural;
      Text  : out String;
      Last  : out Natural)
   is
      Which : T.Proposal;
      OK    : Boolean;
   begin
      T.Stored_Bad (Trace_Index (Index), Which, OK);
      if not OK then
         Last := 0;
         return;
      end if;
      Proposal_Text (Which, Text, Last);
   end Menu_Bad;

   procedure Menu_Good
     (Index : Natural;
      Text  : out String;
      Last  : out Natural)
   is
      Which : T.Proposal;
      OK    : Boolean;
   begin
      T.Known_Good (Trace_Index (Index), Which, OK);
      if not OK then
         Last := 0;
         return;
      end if;
      Proposal_Text (Which, Text, Last);
   end Menu_Good;

   procedure Append_Blob
     (Buf     : in out String;
      Last    : in out Natural;
      Index_W : String;
      Minus   : Natural;
      Curr    : Natural;
      OK      : in out Boolean)
   is
   begin
      Add (Buf, Last, "index ", OK);
      Add (Buf, Last, Index_W, OK);
      Add (Buf, Last, (1 => LF) & "minus-one ", OK);
      Put_Nat (Buf, Last, Minus, OK);
      Add (Buf, Last, (1 => LF) & "current ", OK);
      Put_Nat (Buf, Last, Curr, OK);
      Add (Buf, Last, (1 => LF), OK);
   end Append_Blob;

   procedure Correct_Next
     (From : R.State;
      To   : out R.State)
   is
   begin
      To :=
        (Fib_Index => From.Fib_Index - 1,
         Minus_One => From.Curr_Value,
         Curr_Value => From.Minus_One + From.Curr_Value);
   end Correct_Next;

   --  The planted mistake, if this step has one. None means
   --  the solver emits the step the checker wants.
   type Slip is (None, Garble, Stall, Bad_Sum);

   function Fib_Slip
     (Index   : Natural;
      Attempt : Positive;
      Note    : String;
      From    : R.State) return Slip
   is
   begin
      if Index = 2 and then From.Fib_Index = 2 then
         if Contains (Note, "bad-parse") or else Attempt > 1 then
            return None;
         end if;
         return Garble;
      end if;
      if Index = 3 and then From.Fib_Index = 4 then
         if Contains (Note, "not-toward-base") then
            return None;
         end if;
         return Stall;
      end if;
      if Index = 4 and then From.Fib_Index = 4 then
         if Contains (Note, "bad-arithmetic") then
            return None;
         end if;
         return Bad_Sum;
      end if;
      return None;
   end Fib_Slip;

   procedure Emit_Step
     (Index   : Natural;
      Attempt : Positive;
      Note    : String;
      From    : R.State;
      Text    : out String;
      Last    : out Natural)
   is
      Next : R.State;
      OK   : Boolean := True;
      Kind : Slip;
   begin
      Last := 0;
      if From.Fib_Index = 0
        or else From.Minus_One > Natural'Last - From.Curr_Value
      then
         return;
      end if;
      Correct_Next (From, Next);
      Kind := Fib_Slip (Index, Attempt, Note, From);
      case Kind is
         when None =>
            declare
               Img : String (1 .. 12);
               ILast : Natural := 0;
            begin
               Put_Nat (Img, ILast, Next.Fib_Index, OK);
               if ILast > 0 then
                  Append_Blob
                    (Text, Last, Img (1 .. ILast),
                     Next.Minus_One, Next.Curr_Value, OK);
               end if;
            end;
         when Garble =>
            Append_Blob
              (Text, Last, "two",
               Next.Minus_One, Next.Curr_Value, OK);
         when Stall =>
            declare
               Img : String (1 .. 12);
               ILast : Natural := 0;
            begin
               Put_Nat (Img, ILast, From.Fib_Index, OK);
               if ILast > 0 then
                  Append_Blob
                    (Text, Last, Img (1 .. ILast),
                     Next.Minus_One, Next.Curr_Value, OK);
               end if;
            end;
         when Bad_Sum =>
            declare
               Img : String (1 .. 12);
               ILast : Natural := 0;
               Bad : constant Natural := Next.Curr_Value + 1;
            begin
               Put_Nat (Img, ILast, Next.Fib_Index, OK);
               if ILast > 0 then
                  Append_Blob
                    (Text, Last, Img (1 .. ILast),
                     Next.Minus_One, Bad, OK);
               end if;
            end;
      end case;
      if not OK then
         Last := 0;
      end if;
   end Emit_Step;

   procedure Emit_Chain
     (Index   : Natural;
      Attempt : Positive;
      Note    : String;
      Text    : out String;
      Last    : out Natural)
   is
      From : R.State;
      Next : R.State;
      OK   : Boolean;
      Kind : Slip;
   begin
      Last := 0;
      R.Make_Opening (Fib_Target (Index), From, OK);
      if not OK then
         return;
      end if;
      declare
         Img : String (1 .. 12);
         ILast : Natural := 0;
      begin
         Put_Nat (Img, ILast, From.Fib_Index, OK);
         if ILast > 0 then
            Append_Blob
              (Text, Last, Img (1 .. ILast),
               From.Minus_One, From.Curr_Value, OK);
         end if;
      end;
      while OK and then From.Fib_Index > 0 loop
         Kind := Fib_Slip (Index, Attempt, Note, From);
         Add (Text, Last, "---" & (1 => LF), OK);
         if Kind = None then
            Correct_Next (From, Next);
            declare
               Img : String (1 .. 12);
               ILast : Natural := 0;
            begin
               Put_Nat (Img, ILast, Next.Fib_Index, OK);
               if ILast > 0 then
                  Append_Blob
                    (Text, Last, Img (1 .. ILast),
                     Next.Minus_One, Next.Curr_Value, OK);
               end if;
            end;
            From := Next;
         else
            declare
               Step : String (1 .. 80);
               SLast : Natural;
            begin
               Emit_Step
                 (Index, Attempt, Note, From, Step, SLast);
               if SLast < 1 then
                  OK := False;
               else
                  Add (Text, Last, Step (1 .. SLast), OK);
               end if;
            end;
            exit;
         end if;
      end loop;
      if not OK then
         Last := 0;
      end if;
   end Emit_Chain;

   procedure Emit_Trace
     (Index   : Natural;
      Attempt : Positive;
      Note    : String;
      Text    : out String;
      Last    : out Natural)
   is
   begin
      if Trace_Feedback (Note) then
         Menu_Good (Index, Text, Last);
         return;
      end if;
      if Index = 7 and then Attempt = 1 then
         Put_Word (Text, Last, "flip the hidden");
         return;
      end if;
      Menu_Bad (Index, Text, Last);
   end Emit_Trace;

   procedure Model_Propose
     (Index      : Natural;
      Attempt    : Positive;
      Note       : String;
      Ask        : Ask_Kind;
      Fib_Index  : Natural;
      Minus_One  : Natural;
      Curr_Value : Natural;
      Text       : out String;
      Last       : out Natural)
   is
   begin
      Last := 0;
      if Index < 1 or else Index > Task_Count then
         return;
      end if;
      if Is_Fib (Index) then
         if Ask = Whole then
            Emit_Chain (Index, Attempt, Note, Text, Last);
         else
            declare
               From : constant R.State :=
                 (Fib_Index => Fib_Index,
                  Minus_One => Minus_One,
                  Curr_Value => Curr_Value);
            begin
               Emit_Step (Index, Attempt, Note, From, Text, Last);
            end;
         end if;
      else
         Emit_Trace (Index, Attempt, Note, Text, Last);
      end if;
   end Model_Propose;

   procedure Kind_Text
     (Kind : R.Check_Name;
      Text : out String;
      Last : out Natural)
   is
      Buf : String (1 .. R.Max_Name);
   begin
      R.Kind_Word (Kind, Buf, Last);
      if Last < 1 or else Last > Text'Length then
         Last := 0;
         return;
      end if;
      Text (Text'First .. Text'First + Last - 1) := Buf (1 .. Last);
   end Kind_Text;

   procedure Verdict_Text
     (Kind : T.Verdict_Kind;
      Why  : T.Reason_Kind;
      Text : out String;
      Last : out Natural)
   is
      Buf : String (1 .. T.Max_Name);
   begin
      if Why = T.Not_A_Step then
         T.Reason_Word (Why, Buf, Last);
      else
         T.Verdict_Word (Kind, Buf, Last);
      end if;
      if Last < 1 or else Last > Text'Length then
         Last := 0;
         return;
      end if;
      Text (Text'First .. Text'First + Last - 1) := Buf (1 .. Last);
   end Verdict_Text;

   procedure Checker_Accepts
     (Index      : Natural;
      Fib_Index  : Natural;
      Minus_One  : Natural;
      Curr_Value : Natural;
      Text       : String;
      OK         : out Boolean;
      Note       : out String;
      Note_Last  : out Natural)
   is
   begin
      OK := False;
      Note_Last := 0;
      if Index < 1 or else Index > Task_Count then
         return;
      end if;
      if Is_Fib (Index) then
         declare
            From : constant R.State :=
              (Fib_Index => Fib_Index,
               Minus_One => Minus_One,
               Curr_Value => Curr_Value);
            Next : R.State;
            Parsed : Boolean;
            Kind : R.Check_Name;
         begin
            R.Parse_State (Text, Next, Parsed);
            if not Parsed then
               Kind_Text (R.Bad_Parse, Note, Note_Last);
               return;
            end if;
            R.Check_Step (From, Next, Kind);
            Kind_Text (Kind, Note, Note_Last);
            OK := Kind = R.Accepted or else Kind = R.Reached_Base;
         end;
      else
         declare
            Which : T.Proposal;
            Parsed : Boolean;
            Verdict : T.Verdict_Kind;
            Reason : T.Reason_Kind;
            Before_L : Float;
            After_L : Float;
            Before_X : Boolean;
            After_X : Boolean;
            Judge_OK : Boolean;
         begin
            T.Parse_Proposal (Text, Which, Parsed);
            if not Parsed then
               Verdict_Text
                 (T.No_Better, T.Not_A_Step, Note, Note_Last);
               return;
            end if;
            T.Judge
              (Trace_Index (Index), T.Proposal_Code (Which),
               Verdict, Reason, Before_L, After_L,
               Before_X, After_X, Judge_OK);
            if not Judge_OK then
               Verdict_Text
                 (T.No_Better, T.Not_A_Step, Note, Note_Last);
               return;
            end if;
            Verdict_Text (Verdict, Reason, Note, Note_Last);
            OK := Verdict = T.Fixes_It;
         end;
      end if;
   end Checker_Accepts;

   procedure Store
     (Into    : in out String;
      Last    : out Natural;
      Item    : String)
   is
      N : Natural;
   begin
      Last := 0;
      if Item'Length = 0 then
         return;
      end if;
      N := Item'Length;
      if N > Into'Length then
         N := Into'Length;
      end if;
      Into (Into'First .. Into'First + N - 1) :=
        Item (Item'First .. Item'First + N - 1);
      Last := N;
   end Store;

   procedure Quote_Of
     (Text : String;
      Buf  : out String;
      Last : out Natural)
   is
      Start : Natural := Text'First;
      Line_S : Natural;
      Line_L : Natural;
      Best_S : Natural := 0;
      Best_L : Natural := 0;
      Saw : Boolean := False;
   begin
      Last := 0;
      if Text'Length = 0 then
         Store (Buf, Last, "empty");
         return;
      end if;
      while Start <= Text'Last loop
         Line_S := Start;
         Line_L := Start - 1;
         while Start <= Text'Last and then Text (Start) /= LF loop
            Line_L := Start;
            Start := Start + 1;
         end loop;
         if Start <= Text'Last and then Text (Start) = LF then
            Start := Start + 1;
         end if;
         if Line_L >= Line_S
           and then Line_L - Line_S + 1 >= 6
           and then Same (Text (Line_S .. Line_S + 5), "index ")
         then
            Best_S := Line_S;
            Best_L := Line_L;
            Saw := True;
            if Same (Text (Line_S .. Line_L), "index two") then
               exit;
            end if;
         end if;
      end loop;
      if not Saw then
         Line_L := Text'First - 1;
         Start := Text'First;
         while Start <= Text'Last and then Text (Start) /= LF loop
            Line_L := Start;
            Start := Start + 1;
         end loop;
         if Line_L < Text'First then
            Store (Buf, Last, "empty");
         else
            Store (Buf, Last, Text (Text'First .. Line_L));
         end if;
         return;
      end if;
      Store (Buf, Last, Text (Best_S .. Best_L));
   end Quote_Of;

   procedure Fill_Call
     (Slot       : in out Call;
      Attempt    : Positive;
      Note       : String;
      Ask        : Ask_Kind;
      Fib_Index  : Natural;
      Minus_One  : Natural;
      Curr_Value : Natural;
      Accepted   : Boolean;
      Word       : String;
      Source     : String)
   is
   begin
      Slot.Attempt := Attempt;
      Store (Slot.Note, Slot.Note_Len, Note);
      Slot.Ask := Ask;
      Slot.Fib_Index := Fib_Index;
      Slot.Minus_One := Minus_One;
      Slot.Curr_Value := Curr_Value;
      Slot.Accepted := Accepted;
      Store (Slot.Word, Slot.Word_Len, Word);
      Quote_Of (Source, Slot.Quote, Slot.Quote_Len);
   end Fill_Call;

   procedure Chain_Word
     (Text : String;
      Word : out String;
      Last : out Natural;
      Readable : out Boolean;
      Solved_N : Natural;
      Solved : out Boolean)
   is
      View : R.Replay;
   begin
      R.Check_Chain (Text, View);
      Kind_Text (View.Stop, Word, Last);
      Readable :=
        View.Stop /= R.Bad_Parse
        and then View.Stop /= R.Bad_Opening
        and then View.Stop /= R.Too_Long;
      Solved :=
        View.Stop = R.Reached_Base
        and then View.Answer = Solved_N;
   end Chain_Word;

   procedure Run_Answer
     (Which : Harness_Name;
      Index : Natural;
      Item  : out Run)
   is
      Limit : constant Positive :=
        (if Which = One_Shot then 1 else Retry_Tries);
      Attempt : Positive := 1;
      Note : String (1 .. Max_Note) := (others => ' ');
      Note_Len : Natural := 0;
      Text : String (1 .. Max_Text);
      Last : Natural;
      Word : String (1 .. Max_Note);
      WLast : Natural;
      Readable : Boolean;
      Solved : Boolean;
      Keep : Boolean;
   begin
      Item := (Solved => False, Steps => 0, Wrong => 0,
               Calls => 0, Item => (others => <>));
      loop
         exit when Item.Calls >= Max_Call or else Attempt > Limit;
         Item.Calls := Item.Calls + 1;
         Model_Propose
           (Index, Attempt,
            (if Note_Len = 0 then ""
             else Note (1 .. Note_Len)),
            Whole, 0, 0, 0, Text, Last);
         if Is_Fib (Index) then
            Chain_Word
              (Text (1 .. Last), Word, WLast, Readable,
               Expected_Answer (Index), Solved);
         else
            declare
               OK : Boolean;
               NLast : Natural;
            begin
               Checker_Accepts
                 (Index, 0, 0, 0, Text (1 .. Last),
                  OK, Word, NLast);
               WLast := NLast;
               --  A menu token that the checker rejects still
               --  parsed. not-a-step did not parse.
               if WLast > 0
                 and then not Same (Word (1 .. WLast), "not-a-step")
               then
                  Readable := True;
               else
                  Readable := False;
               end if;
               Solved := OK;
            end;
         end if;
         Keep := Which = One_Shot or else Readable;
         Fill_Call
           (Item.Item (Item.Calls), Attempt,
            (if Note_Len = 0 then "" else Note (1 .. Note_Len)),
            Whole, 0, 0, 0, Keep,
            (if WLast = 0 then "" else Word (1 .. WLast)),
            (if Last = 0 then "" else Text (1 .. Last)));
         if Keep then
            Item.Solved := Solved;
            if not Solved then
               Item.Wrong := 1;
            end if;
            exit;
         end if;
         Attempt := Attempt + 1;
         Store (Note, Note_Len, "again");
      end loop;
      Item.Steps := Item.Calls;
   end Run_Answer;

   procedure Run_Fib
     (Cap   : Natural;
      Index : Natural;
      Item  : out Run)
   is
      From : R.State;
      Open : Boolean;
      Attempt : Positive := 1;
      Note : String (1 .. Max_Note) := (others => ' ');
      Note_Len : Natural := 0;
      Text : String (1 .. Max_Text);
      Last : Natural;
      Word : String (1 .. Max_Note);
      WLast : Natural;
      OK : Boolean;
   begin
      Item := (Solved => False, Steps => 0, Wrong => 0,
               Calls => 0, Item => (others => <>));
      R.Make_Opening (Fib_Target (Index), From, Open);
      if not Open then
         return;
      end if;
      while From.Fib_Index > 0
        and then Item.Calls < Cap
        and then Item.Calls < Max_Call
        and then Attempt <= Attempt_Cap
      loop
         Item.Calls := Item.Calls + 1;
         Model_Propose
           (Index, Attempt,
            (if Note_Len = 0 then "" else Note (1 .. Note_Len)),
            One_Step, From.Fib_Index, From.Minus_One,
            From.Curr_Value, Text, Last);
         Checker_Accepts
           (Index, From.Fib_Index, From.Minus_One, From.Curr_Value,
            (if Last = 0 then "" else Text (1 .. Last)),
            OK, Word, WLast);
         Fill_Call
           (Item.Item (Item.Calls), Attempt,
            (if Note_Len = 0 then "" else Note (1 .. Note_Len)),
            One_Step, From.Fib_Index, From.Minus_One,
            From.Curr_Value, OK,
            (if WLast = 0 then "" else Word (1 .. WLast)),
            (if Last = 0 then "" else Text (1 .. Last)));
         if OK then
            declare
               Next : R.State;
               Parsed : Boolean;
            begin
               R.Parse_State
                 (Text (1 .. Last), Next, Parsed);
               if not Parsed then
                  Item.Item (Item.Calls).Accepted := False;
                  exit;
               end if;
               if Next.Fib_Index = 0 then
                  Item.Solved :=
                    Next.Minus_One = Expected_Answer (Index);
                  exit;
               end if;
               From := Next;
               Attempt := 1;
               Note_Len := 0;
            end;
         else
            Attempt := Attempt + 1;
            if WLast > 0 then
               Store (Note, Note_Len, Word (1 .. WLast));
            end if;
         end if;
      end loop;
      Item.Steps := Item.Calls;
   end Run_Fib;

   procedure Run_Trace
     (Cap   : Natural;
      Index : Natural;
      Item  : out Run)
   is
      Attempt : Positive := 1;
      Note : String (1 .. Max_Note) := (others => ' ');
      Note_Len : Natural := 0;
      Text : String (1 .. Max_Text);
      Last : Natural;
      Word : String (1 .. Max_Note);
      WLast : Natural;
      OK : Boolean;
   begin
      Item := (Solved => False, Steps => 0, Wrong => 0,
               Calls => 0, Item => (others => <>));
      while not Item.Solved
        and then Item.Calls < Cap
        and then Item.Calls < Max_Call
        and then Attempt <= Attempt_Cap
      loop
         Item.Calls := Item.Calls + 1;
         Model_Propose
           (Index, Attempt,
            (if Note_Len = 0 then "" else Note (1 .. Note_Len)),
            One_Step, 0, 0, 0, Text, Last);
         Checker_Accepts
           (Index, 0, 0, 0,
            (if Last = 0 then "" else Text (1 .. Last)),
            OK, Word, WLast);
         Fill_Call
           (Item.Item (Item.Calls), Attempt,
            (if Note_Len = 0 then "" else Note (1 .. Note_Len)),
            One_Step, 0, 0, 0, OK,
            (if WLast = 0 then "" else Word (1 .. WLast)),
            (if Last = 0 then "" else Text (1 .. Last)));
         if OK then
            Item.Solved := True;
         else
            Attempt := Attempt + 1;
            if WLast > 0 then
               Store (Note, Note_Len, Word (1 .. WLast));
            end if;
         end if;
      end loop;
      Item.Steps := Item.Calls;
   end Run_Trace;

   procedure Run_One
     (Which : Harness_Name;
      Index : Natural;
      Item  : out Run)
   is
      Cap : Natural;
   begin
      Item := (Solved => False, Steps => 0, Wrong => 0,
               Calls => 0, Item => (others => <>));
      if Index < 1 or else Index > Task_Count then
         return;
      end if;
      case Which is
         when One_Shot | Retry =>
            Run_Answer (Which, Index, Item);
         when Checked | Budgeted =>
            if Which = Budgeted then
               Cap := Budget_Cap;
            else
               Cap := Checked_Cap;
            end if;
            if Is_Fib (Index) then
               Run_Fib (Cap, Index, Item);
            else
               Run_Trace (Cap, Index, Item);
            end if;
      end case;
   end Run_One;

   procedure Run_Table (Item : out Table) is
      One : Run;
   begin
      Item := (others => (0, 0, 0));
      for Which in Harness_Name loop
         for Index in 1 .. Task_Count loop
            Run_One (Which, Index, One);
            if One.Solved then
               Item (Which).Solved := Item (Which).Solved + 1;
            end if;
            Item (Which).Steps := Item (Which).Steps + One.Steps;
            Item (Which).Wrong := Item (Which).Wrong + One.Wrong;
         end loop;
      end loop;
   end Run_Table;

   procedure Cell
     (Which : Harness_Name;
      Row   : Table;
      Col   : Natural;
      Text  : out String;
      Last  : out Natural)
   is
      OK : Boolean := True;
   begin
      Last := 0;
      case Col is
         when 1 =>
            Harness_Word (Which, Text, Last);
         when 2 =>
            Put_Nat (Text, Last, Row (Which).Solved, OK);
            Add (Text, Last, " of ", OK);
            Put_Nat (Text, Last, Task_Count, OK);
            if not OK then
               Last := 0;
            end if;
         when 3 =>
            Put_Nat (Text, Last, Row (Which).Steps, OK);
            if not OK then
               Last := 0;
            end if;
         when 4 =>
            Put_Nat (Text, Last, Row (Which).Wrong, OK);
            if not OK then
               Last := 0;
            end if;
         when others =>
            Last := 0;
      end case;
   end Cell;

   procedure Log_Line
     (Item  : Run;
      Index : Natural;
      Text  : out String;
      Last  : out Natural)
   is
      OK : Boolean := True;
      Slot : Call;
   begin
      Last := 0;
      if Index < 1 or else Index > Item.Calls then
         return;
      end if;
      Slot := Item.Item (Index);
      Add (Text, Last, "call ", OK);
      Put_Nat (Text, Last, Index, OK);
      Add (Text, Last, "  attempt ", OK);
      Put_Nat (Text, Last, Slot.Attempt, OK);
      Add (Text, Last, "  note ", OK);
      if Slot.Note_Len = 0 then
         Add (Text, Last, "none", OK);
      else
         Add (Text, Last, Slot.Note (1 .. Slot.Note_Len), OK);
      end if;
      if Slot.Accepted then
         Add (Text, Last, "  accepted  ", OK);
      else
         Add (Text, Last, "  rejected  ", OK);
      end if;
      if Slot.Word_Len > 0
        and then Same (Slot.Word (1 .. Slot.Word_Len), "accepted")
      then
         --  The checker word for a step that is not yet the
         --  base. "accepted" would repeat the harness word.
         Add (Text, Last, "step", OK);
      elsif Slot.Word_Len > 0 then
         Add (Text, Last, Slot.Word (1 .. Slot.Word_Len), OK);
      end if;
      Add (Text, Last, "  ", OK);
      if Slot.Quote_Len > 0 then
         Add (Text, Last, Slot.Quote (1 .. Slot.Quote_Len), OK);
      end if;
      if not OK then
         Last := 0;
      end if;
   end Log_Line;

   procedure Result_Line
     (Item : Run;
      Text : out String;
      Last : out Natural)
   is
      OK : Boolean := True;
   begin
      Last := 0;
      if Item.Solved then
         Add (Text, Last, "solved", OK);
      else
         Add (Text, Last, "not solved", OK);
      end if;
      Add (Text, Last, "  steps ", OK);
      Put_Nat (Text, Last, Item.Steps, OK);
      Add (Text, Last, "  wrong ", OK);
      Put_Nat (Text, Last, Item.Wrong, OK);
      if not OK then
         Last := 0;
      end if;
   end Result_Line;

   procedure Stat_Line
     (Text : out String;
      Last : out Natural)
   is
      OK : Boolean := True;
   begin
      Last := 0;
      Add (Text, Last, "Seed ", OK);
      Put_Nat (Text, Last, Seed, OK);
      Add (Text, Last, ". ", OK);
      Put_Nat (Text, Last, Task_Count, OK);
      Add (Text, Last,
           " tasks. The model is the same in every row.", OK);
      if not OK then
         Last := 0;
      end if;
   end Stat_Line;

   procedure Prompt_For
     (Index      : Natural;
      Fib_Index  : Natural;
      Minus_One  : Natural;
      Curr_Value : Natural;
      Note       : String;
      Text       : out String;
      Last       : out Natural;
      OK         : out Boolean)
   is
   begin
      Last := 0;
      OK := False;
      if Index < 1 or else Index > Task_Count then
         return;
      end if;
      if Is_Fib (Index) then
         declare
            From : constant R.State :=
              (Fib_Index => Fib_Index,
               Minus_One => Minus_One,
               Curr_Value => Curr_Value);
            Base : String (1 .. R.Max_Prompt);
            BLast : Natural;
            BOK : Boolean;
         begin
            R.Prompt_For (From, Base, BLast, BOK);
            if not BOK or else BLast < 1 then
               return;
            end if;
            OK := True;
            Add (Text, Last, Base (1 .. BLast), OK);
         end;
      else
         declare
            Base : String (1 .. T.Max_Prompt);
            BLast : Natural;
            BOK : Boolean;
         begin
            T.Prompt_For (Trace_Index (Index), Base, BLast, BOK);
            if not BOK or else BLast < 1 then
               return;
            end if;
            OK := True;
            Add (Text, Last, Base (1 .. BLast), OK);
         end;
      end if;
      if Note'Length > 0 and then OK then
         Add (Text, Last, (1 => LF) & "The checker said: ", OK);
         Add (Text, Last, Note, OK);
         Add (Text, Last, ". Reply with the next step only.", OK);
      end if;
      if not OK then
         Last := 0;
      end if;
   end Prompt_For;

end AI_Amplifier.Harness;
