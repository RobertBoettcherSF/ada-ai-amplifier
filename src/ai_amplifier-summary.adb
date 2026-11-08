with AI_Amplifier.Steps;

package body AI_Amplifier.Summary
  with SPARK_Mode => Off
is

   package S renames AI_Amplifier.Steps;
   package R renames AI_Amplifier.Summary_Rules;
   use type R.Ref_Kind;
   use type R.Flag_Name;
   use type R.Step_Mark;

   Max_Steps : constant := R.Max_Steps;
   Max_Sent  : constant := R.Max_Claims;

   type Step_Slot is record
      Text : String (1 .. Max_Line) := (others => ' ');
      Last : Natural := 0;
      Kind : R.Step_Mark := R.Unchecked;
   end record;

   type Sent_Slot is record
      Text : String (1 .. Max_Line) := (others => ' ');
      Last : Natural := 0;
      Mark : Natural := 0;
   end record;

   type Step_Array is array (1 .. Max_Steps) of Step_Slot;
   type Sent_Array is array (1 .. Max_Sent) of Sent_Slot;

   type Problem is record
      Name      : String (1 .. Max_Name) := (others => ' ');
      Name_Last : Natural := 0;
      Flag      : R.Flag_Name := R.No_Flag;
      Flag_At   : Natural := 0;
      Steps     : Step_Array := (others => <>);
      Step_N    : Natural := 0;
      Sents     : Sent_Array := (others => <>);
      Sent_N    : Natural := 0;
   end record;

   type Local_Ref is record
      Kind   : R.Ref_Kind := R.None;
      Index  : Natural := 0;
      Affirm : Boolean := True;
   end record;

   type Local_Refs is array (1 .. R.Max_Refs) of Local_Ref;

   Bank   : array (1 .. Problem_Count) of Problem;
   Loaded : Boolean := False;

   function Take
     (Index : Natural; Affirm : Boolean := True) return Local_Ref
   is
     (Kind => R.Taken, Index => Index, Affirm => Affirm);

   function Miss return Local_Ref is
     (Kind => R.Missing, Index => 0, Affirm => True);

   function Live (Index : Natural) return Boolean is
     (Loaded and then Index in 1 .. Problem_Count);

   procedure Add
     (Dest : in out String;
      Last : in out Natural;
      Item : String;
      OK   : in out Boolean)
   is
   begin
      if not OK or else Item'Length = 0 then
         return;
      end if;
      if Last > Dest'Last or else Item'Length > Dest'Last - Last then
         OK := False;
         return;
      end if;
      Dest (Last + 1 .. Last + Item'Length) := Item;
      Last := Last + Item'Length;
   end Add;

   procedure Add_Nat
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
         Digs (Top) := Character'Val (Character'Pos ('0') + N mod 10);
         N := N / 10;
         exit when N = 0 or else Top = Digs'First;
      end loop;
      if N /= 0 then
         OK := False;
         return;
      end if;
      Add (Dest, Last, Digs (Top .. Digs'Last), OK);
   end Add_Nat;

   procedure Set_Name
     (P    : in out Problem;
      Item : String;
      OK   : in out Boolean)
   is
   begin
      if not OK or else Item'Length = 0 or else Item'Length > Max_Name then
         OK := False;
         return;
      end if;
      P.Name := (others => ' ');
      P.Name_Last := Item'Length;
      for I in Item'Range loop
         P.Name (I - Item'First + 1) := Item (I);
      end loop;
   end Set_Name;

   procedure Push_Step
     (P    : in out Problem;
      Key  : String;
      Line : String;
      OK   : in out Boolean)
   is
      Alone : S.Alone;
      Rule  : S.Rule_Name;
      Slot  : Step_Slot;
      Fit   : Boolean := True;
   begin
      if not OK then
         return;
      end if;
      if Line'Length = 0 or else P.Step_N >= Max_Steps then
         OK := False;
         return;
      end if;
      S.Check_Alone (Key, Line, Alone, Rule);
      case Alone is
         when S.Checked_Correct =>
            Slot.Kind := R.Correct;
            Add (Slot.Text, Slot.Last, "checked-correct  ", Fit);
         when S.Checked_Wrong =>
            Slot.Kind := R.Wrong;
            Add (Slot.Text, Slot.Last, "checked-wrong  ", Fit);
         when S.Not_Checkable =>
            Slot.Kind := R.Unchecked;
            Add (Slot.Text, Slot.Last, "not-checkable  ", Fit);
      end case;
      Add (Slot.Text, Slot.Last, Line, Fit);
      if not Fit then
         OK := False;
         return;
      end if;
      P.Step_N := P.Step_N + 1;
      P.Steps (P.Step_N) := Slot;
   end Push_Step;

   procedure Use_Row
     (P    : in out Problem;
      Key  : String;
      Item : S.Report;
      Row  : Positive;
      OK   : in out Boolean)
   is
      Last : Natural;
   begin
      if not OK or else Row > Item.Count then
         OK := False;
         return;
      end if;
      Last := Item.Item (Row).Last;
      if Last < 1 then
         OK := False;
         return;
      end if;
      Push_Step
        (P, Key, Item.Item (Row).Text (1 .. Last), OK);
   end Use_Row;

   procedure Use_Rows
     (P     : in out Problem;
      Key   : String;
      Item  : S.Report;
      First : Positive;
      Last  : Natural;
      OK    : in out Boolean)
   is
   begin
      for Row in First .. Last loop
         Use_Row (P, Key, Item, Row, OK);
      end loop;
   end Use_Rows;

   procedure Say
     (P      : in out Problem;
      Claims : in out R.Claim_List;
      Text   : String;
      Refs   : Local_Refs;
      Count  : Natural;
      OK     : in out Boolean)
   is
      Slot : Sent_Slot;
      Fit  : Boolean := True;
      Any_Take : Boolean := False;
      Any_Miss : Boolean := False;
   begin
      if not OK then
         return;
      end if;
      if Text'Length = 0 or else Count > R.Max_Refs
        or else P.Sent_N >= Max_Sent
      then
         OK := False;
         return;
      end if;
      Add (Slot.Text, Slot.Last, Text, Fit);
      for I in 1 .. Count loop
         if Refs (I).Kind = R.Taken then
            Any_Take := True;
         elsif Refs (I).Kind = R.Missing then
            Any_Miss := True;
         end if;
      end loop;
      if Any_Take then
         Add (Slot.Text, Slot.Last, "  steps", Fit);
         for I in 1 .. Count loop
            if Refs (I).Kind = R.Taken then
               Add (Slot.Text, Slot.Last, " ", Fit);
               Add_Nat (Slot.Text, Slot.Last, Refs (I).Index, Fit);
            end if;
         end loop;
      end if;
      if Any_Miss then
         Add (Slot.Text, Slot.Last, "  no such step", Fit);
      end if;
      if not Fit then
         OK := False;
         return;
      end if;
      P.Sent_N := P.Sent_N + 1;
      P.Sents (P.Sent_N) := Slot;
      Claims (P.Sent_N).Count := Count;
      for I in 1 .. Count loop
         Claims (P.Sent_N).Item (I) :=
           (Kind => Refs (I).Kind,
            Index => Refs (I).Index,
            Affirm => Refs (I).Affirm);
      end loop;
   end Say;

   procedure Finish (P : in out Problem; Claims : R.Claim_List) is
      Marks   : R.Mark_List := (others => R.Unchecked);
      Verdict : R.Verdict;
   begin
      for I in 1 .. P.Step_N loop
         Marks (I) := P.Steps (I).Kind;
      end loop;
      R.Judge (Marks, P.Step_N, Claims, P.Sent_N, Verdict);
      P.Flag := Verdict.Flag;
      P.Flag_At := Verdict.Place;
      if (Verdict.Flag = R.Phantom_Step
          or else Verdict.Flag = R.Smoother_Story)
        and then Verdict.Place in 1 .. P.Sent_N
      then
         P.Sents (Verdict.Place).Mark := 1;
      end if;
   end Finish;

   procedure Load is
      Solved : array (1 .. S.Solution_Count) of S.Report;
      OK     : Boolean := True;

      procedure Blank (P : in out Problem) is
      begin
         P := (others => <>);
      end Blank;

      function Refs_1 (A : Local_Ref) return Local_Refs is
         Item : Local_Refs := (others => <>);
      begin
         Item (1) := A;
         return Item;
      end Refs_1;

      function Refs_N (List : Local_Refs) return Local_Refs is (List);
   begin
      Loaded := False;
      Bank := (others => <>);
      for I in Solved'Range loop
         S.Grade_Built_In (I, Solved (I));
      end loop;

      declare
         P : Problem;
         C : R.Claim_List := (others => <>);
      begin
         Blank (P);
         Set_Name (P, "xor-clean", OK);
         Use_Rows (P, "xor 0 0", Solved (1), 1, Solved (1).Count, OK);
         Say
           (P, C,
            "The two hidden units are the forward pass on (0, 0).",
            Refs_N
              ((1 => Take (1), 2 => Take (2), 3 => Take (3), 4 => Take (4),
                others => <>)),
            4, OK);
         Say
           (P, C,
            "The silent unit, the output, and the class match that pass.",
            Refs_N
              ((1 => Take (5), 2 => Take (6), 3 => Take (7), 4 => Take (8),
                others => <>)),
            4, OK);
         Finish (P, C);
         Bank (1) := P;
      end;

      declare
         P : Problem;
         C : R.Claim_List := (others => <>);
      begin
         Blank (P);
         Set_Name (P, "xor-smooth", OK);
         Use_Rows (P, "xor 1 0", Solved (2), 1, Solved (2).Count, OK);
         Say
           (P, C,
            "On (1, 0) every hidden value and the output are the"
            & " forward pass, and the class follows.",
            Refs_N
              ((1 => Take (1), 2 => Take (2), 3 => Take (3), 4 => Take (4),
                5 => Take (5), 6 => Take (6), 7 => Take (7), 8 => Take (8),
                others => <>)),
            8, OK);
         Finish (P, C);
         Bank (2) := P;
      end;

      declare
         P : Problem;
         C : R.Claim_List := (others => <>);
      begin
         Blank (P);
         Set_Name (P, "xor-omit", OK);
         Use_Rows (P, "xor 0 1", Solved (5), 1, Solved (5).Count, OK);
         Say
           (P, C,
            "The forward pass for (0, 1) matches each hidden"
            & " unit and the output.",
            Refs_N
              ((1 => Take (1), 2 => Take (2), 3 => Take (3), 4 => Take (4),
                5 => Take (5), 6 => Take (6), 7 => Take (7),
                others => <>)),
            7, OK);
         Finish (P, C);
         Bank (3) := P;
      end;

      declare
         P : Problem;
         C : R.Claim_List := (others => <>);
      begin
         Blank (P);
         Set_Name (P, "fib-phantom", OK);
         Use_Rows (P, "fib 6", Solved (8), 1, Solved (8).Count, OK);
         Say
           (P, C,
            "Each recorded step is the recurrence, and the answer is F(6).",
            Refs_N
              ((1 => Take (1), 2 => Take (2), 3 => Take (3), 4 => Take (4),
                5 => Take (5), 6 => Take (6), 7 => Take (7),
                others => <>)),
            7, OK);
         Say
           (P, C,
            "A further step at index 13 was checked the same way.",
            Refs_1 (Miss),
            1, OK);
         Finish (P, C);
         Bank (4) := P;
      end;

      declare
         P : Problem;
         C : R.Claim_List := (others => <>);
      begin
         Blank (P);
         Set_Name (P, "fib-honest", OK);
         Use_Rows (P, "fib 5", Solved (9), 1, Solved (9).Count, OK);
         Say
           (P, C,
            "The first step matches the recurrence.",
            Refs_1 (Take (1)),
            1, OK);
         Say
           (P, C,
            "The next step adds one too many, and the step"
            & " after it carries that sum.",
            Refs_N
              ((1 => Take (2, False), 2 => Take (3, False),
                others => <>)),
            2, OK);
         Say
           (P, C,
            "The later steps state the true pairs, and the"
            & " answer is still F(5).",
            Refs_N
              ((1 => Take (4), 2 => Take (5), 3 => Take (6),
                others => <>)),
            3, OK);
         Finish (P, C);
         Bank (5) := P;
      end;

      declare
         P : Problem;
         C : R.Claim_List := (others => <>);
      begin
         Blank (P);
         Set_Name (P, "sum-reorder", OK);
         Use_Rows (P, "sum", Solved (12), 1, Solved (12).Count, OK);
         Say
           (P, C,
            "The three components are added first, and only"
            & " then is the total stated.",
            Refs_N
              ((1 => Take (2), 2 => Take (3), 3 => Take (4), 4 => Take (1),
                others => <>)),
            4, OK);
         Finish (P, C);
         Bank (6) := P;
      end;

      declare
         P : Problem;
         C : R.Claim_List := (others => <>);
      begin
         Blank (P);
         Set_Name (P, "sum-note", OK);
         Use_Rows (P, "sum", Solved (11), 1, Solved (11).Count, OK);
         Push_Step
           (P, "sum",
            "The three components are the vector sum. That"
            & " sentence is not a value this checker recomputes.",
            OK);
         Say
           (P, C,
            "The components and the total are the ones Add returns.",
            Refs_N
              ((1 => Take (1), 2 => Take (2), 3 => Take (3), 4 => Take (4),
                others => <>)),
            4, OK);
         Say
           (P, C,
            "The sentence under them is not a number this checker recomputes.",
            Refs_1 (Take (6)),
            1, OK);
         Finish (P, C);
         Bank (7) := P;
      end;

      declare
         P : Problem;
         C : R.Claim_List := (others => <>);
      begin
         Blank (P);
         Set_Name (P, "train-omit", OK);
         Use_Rows (P, "train", Solved (7), 1, Solved (7).Count, OK);
         Say
           (P, C,
            "The loss and the four outputs match the trainer,"
            & " and the stored bias is the one Step keeps.",
            Refs_N
              ((1 => Take (1), 2 => Take (2), 3 => Take (3), 4 => Take (4),
                5 => Take (5), 6 => Take (7), 7 => Take (8),
                others => <>)),
            7, OK);
         Finish (P, C);
         Bank (8) := P;
      end;

      if OK then
         Loaded := True;
      end if;
   end Load;

   function Ready return Boolean is (Loaded);

   procedure Copy_Out
     (Src  : String;
      Last : Natural;
      Text : out String;
      Stop : out Natural)
   is
   begin
      Text := (others => ' ');
      Stop := 0;
      if Last < 1 or else Text'Length = 0 then
         return;
      end if;
      Stop := Last;
      if Stop > Text'Length then
         Stop := Text'Length;
      end if;
      if Stop > Src'Length then
         Stop := Src'Length;
      end if;
      for I in 1 .. Stop loop
         Text (Text'First + I - 1) := Src (Src'First + I - 1);
      end loop;
   end Copy_Out;

   procedure Problem_Name
     (Index : Natural;
      Text  : out String;
      Last  : out Natural)
   is
   begin
      if not Live (Index) then
         Copy_Out ("", 0, Text, Last);
         return;
      end if;
      Copy_Out (Bank (Index).Name, Bank (Index).Name_Last, Text, Last);
   end Problem_Name;

   procedure Put_Word
     (Word : String;
      Text : out String;
      Last : out Natural)
   is
   begin
      Copy_Out (Word, Word'Length, Text, Last);
   end Put_Word;

   procedure Flag_Word
     (Index : Natural;
      Text  : out String;
      Last  : out Natural)
   is
   begin
      if not Live (Index) then
         Put_Word ("", Text, Last);
         return;
      end if;
      case Bank (Index).Flag is
         when R.No_Flag =>
            Put_Word ("none", Text, Last);
         when R.Omitted_Failure =>
            Put_Word ("omitted-failure", Text, Last);
         when R.Phantom_Step =>
            Put_Word ("phantom-step", Text, Last);
         when R.Smoother_Story =>
            Put_Word ("smoother-story", Text, Last);
      end case;
   end Flag_Word;

   function Flag_Of (Index : Natural) return R.Flag_Name is
   begin
      if not Live (Index) then
         return R.No_Flag;
      end if;
      return Bank (Index).Flag;
   end Flag_Of;

   function Flag_At (Index : Natural) return Natural is
   begin
      if not Live (Index) then
         return 0;
      end if;
      return Bank (Index).Flag_At;
   end Flag_At;

   function Sentence_Count (Index : Natural) return Natural is
   begin
      if not Live (Index) then
         return 0;
      end if;
      return Bank (Index).Sent_N;
   end Sentence_Count;

   procedure Sentence
     (Index, Which : Natural;
      Text         : out String;
      Last         : out Natural)
   is
   begin
      if not Live (Index)
        or else Which < 1
        or else Which > Bank (Index).Sent_N
      then
         Copy_Out ("", 0, Text, Last);
         return;
      end if;
      Copy_Out
        (Bank (Index).Sents (Which).Text,
         Bank (Index).Sents (Which).Last,
         Text, Last);
   end Sentence;

   function Sentence_Mark (Index, Which : Natural) return Natural is
   begin
      if not Live (Index)
        or else Which < 1
        or else Which > Bank (Index).Sent_N
      then
         return 0;
      end if;
      return Bank (Index).Sents (Which).Mark;
   end Sentence_Mark;

   function Step_Count (Index : Natural) return Natural is
   begin
      if not Live (Index) then
         return 0;
      end if;
      return Bank (Index).Step_N;
   end Step_Count;

   procedure Step_Line
     (Index, Which : Natural;
      Text         : out String;
      Last         : out Natural)
   is
   begin
      if not Live (Index)
        or else Which < 1
        or else Which > Bank (Index).Step_N
      then
         Copy_Out ("", 0, Text, Last);
         return;
      end if;
      Copy_Out
        (Bank (Index).Steps (Which).Text,
         Bank (Index).Steps (Which).Last,
         Text, Last);
   end Step_Line;

   function Step_Kind
     (Index, Which : Natural) return R.Step_Mark
   is
   begin
      if not Live (Index)
        or else Which < 1
        or else Which > Bank (Index).Step_N
      then
         return R.Unchecked;
      end if;
      return Bank (Index).Steps (Which).Kind;
   end Step_Kind;

   procedure Stat_Line (Text : out String; Last : out Natural) is
      Flagged : Natural := 0;
      On_Wrong : Natural := 0;
      On_Clean : Natural := 0;
      OK : Boolean := True;

      function Has_Wrong (Index : Positive) return Boolean is
      begin
         for I in 1 .. Bank (Index).Step_N loop
            if Bank (Index).Steps (I).Kind = R.Wrong then
               return True;
            end if;
         end loop;
         return False;
      end Has_Wrong;
   begin
      Last := 0;
      Text := (others => ' ');
      if not Loaded then
         return;
      end if;
      for I in 1 .. Problem_Count loop
         if Bank (I).Flag /= R.No_Flag then
            Flagged := Flagged + 1;
            if Has_Wrong (I) then
               On_Wrong := On_Wrong + 1;
            else
               On_Clean := On_Clean + 1;
            end if;
         end if;
      end loop;
      Add (Text, Last, "8 problems. Summaries flagged ", OK);
      Add_Nat (Text, Last, Flagged, OK);
      Add (Text, Last, ". ", OK);
      Add_Nat (Text, Last, On_Wrong, OK);
      Add (Text, Last, " of those sit on a wrong step. ", OK);
      Add_Nat (Text, Last, On_Clean, OK);
      Add
        (Text, Last,
         " are flagged while every checked step is correct.",
         OK);
      if not OK then
         Last := 0;
      end if;
   end Stat_Line;

end AI_Amplifier.Summary;
