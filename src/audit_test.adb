with Ada.Command_Line;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with GNAT.OS_Lib;
with AI_Amplifier.Audit.Demo;
with AI_Amplifier.Audit.Manifest;

--  The auditor, the planted defects, a second file with the same
--  five breaks under other ids, the page wrapper, and audit_cli.
--  The manifest is the list of planted tasks. The auditor does
--  not read it. A clean task that gets a flag fails this test,
--  and so does a planted task the auditor misses.
procedure Audit_Test
  with SPARK_Mode => Off
is
   package A renames AI_Amplifier.Audit;
   package D renames AI_Amplifier.Audit.Demo;
   package IO renames Ada.Text_IO;

   Failures : Natural := 0;

   procedure Fail (Message : String) is
   begin
      IO.Put_Line ("FAIL " & Message);
      Failures := Failures + 1;
   end Fail;

   function Text_Of (Buf : String; Last : Natural) return String is
   begin
      if Last < 1 then
         return "";
      end if;
      return Buf (Buf'First .. Buf'First + Last - 1);
   end Text_Of;

   procedure Rule_Of
     (Slot : A.Item;
      Word : out String;
      Last : out Natural;
      Count : out Natural)
   is
   begin
      Count := Slot.Flag_Count;
      Last := 0;
      Word := (others => ' ');
      if Count = 1 then
         A.Rule_Word (Slot.Flags (1), Word, Last);
      end if;
   end Rule_Of;

   function Find (Bank : A.Set; Id : String) return Natural is
   begin
      for I in 1 .. Bank.Count loop
         if Text_Of (Bank.Slot (I).Id, Bank.Slot (I).Id_Last) = Id then
            return I;
         end if;
      end loop;
      return 0;
   end Find;

   procedure Load_Text
     (Text : String;
      Bank : out A.Set)
   is
      OK    : Boolean;
      Note  : String (1 .. A.Max_Note);
      NLast : Natural;
   begin
      A.Load (Text, Bank, OK, Note, NLast);
      if not OK then
         Fail ("load " & Text_Of (Note, NLast));
         return;
      end if;
      A.Examine (Bank);
   end Load_Text;

   procedure Check_One_Flag (Bank : A.Set; Id, Rule : String) is
      Index : constant Natural := Find (Bank, Id);
      Word  : String (1 .. 32);
      Last  : Natural;
      Count : Natural;
   begin
      if Index = 0 then
         Fail ("missing " & Id);
         return;
      end if;
      Rule_Of (Bank.Slot (Index), Word, Last, Count);
      if Count /= 1 or else Text_Of (Word, Last) /= Rule then
         Fail (Id & " flags" & Natural'Image (Count)
           & " " & Text_Of (Word, Last));
      end if;
   end Check_One_Flag;

   procedure Check_Clean (Bank : A.Set; Id : String) is
      Index : constant Natural := Find (Bank, Id);
   begin
      if Index = 0 then
         Fail ("missing " & Id);
         return;
      end if;
      if Bank.Slot (Index).Flag_Count /= 0
        or else not Bank.Slot (Index).Solvable
        or else Text_Of
          (Bank.Slot (Index).True_Answer, Bank.Slot (Index).True_Last)
          /= Text_Of
            (Bank.Slot (Index).Expected, Bank.Slot (Index).Expected_Last)
      then
         Fail ("clean " & Id);
      end if;
   end Check_Clean;

   procedure Check_Benchmark is
      Bank  : A.Set;
      Hits  : Natural;
      Total : Natural;
      Accepted : Boolean;
      Line  : String (1 .. A.Max_Line);
      Last  : Natural;
      Index : Natural;
      Seen  : array (1 .. A.Max_Tasks) of Boolean := (others => False);
      Manifest : constant String :=
        AI_Amplifier.Audit.Manifest.Text;
      From  : Natural := Manifest'First;
   begin
      declare
         OK    : Boolean;
         Note  : String (1 .. A.Max_Note);
         NLast : Natural;
      begin
         A.Load_Benchmark (Bank, OK, Note, NLast);
         if not OK then
            Fail ("benchmark " & Text_Of (Note, NLast));
            return;
         end if;
         A.Score (Bank, False, Hits, Total, Accepted);
         if Accepted or else Hits /= 0 or else Total /= 0 then
            Fail ("score before examine");
         end if;
         A.Examine (Bank);
      end;
      if Bank.Count /= 20 then
         Fail ("count" & Natural'Image (Bank.Count));
      end if;
      while From <= Manifest'Last loop
         declare
            Stop  : Natural := From;
            Space : Natural := 0;
            Id    : String (1 .. 40);
            Rule  : String (1 .. 40);
            Id_Last, Rule_Last : Natural := 0;
         begin
            while Stop <= Manifest'Last
              and then Manifest (Stop) /= Character'Val (10)
            loop
               if Manifest (Stop) = ' ' and then Space = 0 then
                  Space := Stop;
               end if;
               Stop := Stop + 1;
            end loop;
            if Space > From and then Stop > Space + 1 then
               Id_Last := Space - From;
               Id (1 .. Id_Last) := Manifest (From .. Space - 1);
               Rule_Last := Stop - Space - 1;
               Rule (1 .. Rule_Last) :=
                 Manifest (Space + 1 .. Stop - 1);
               Check_One_Flag (Bank, Id (1 .. Id_Last), Rule (1 .. Rule_Last));
               Index := Find (Bank, Id (1 .. Id_Last));
               if Index /= 0 then
                  Seen (Index) := True;
               end if;
            elsif Stop > From then
               Fail ("manifest line");
            end if;
            if Stop <= Manifest'Last
              and then Manifest (Stop) = Character'Val (10)
            then
               From := Stop + 1;
            else
               From := Stop;
            end if;
         end;
      end loop;
      for I in 1 .. Bank.Count loop
         if not Seen (I) then
            if Bank.Slot (I).Flag_Count /= 0 then
               Fail ("clean flagged "
                 & Text_Of (Bank.Slot (I).Id, Bank.Slot (I).Id_Last));
            elsif not Bank.Slot (I).Solvable
              or else Text_Of
                (Bank.Slot (I).True_Answer, Bank.Slot (I).True_Last)
                /= Text_Of
                  (Bank.Slot (I).Expected, Bank.Slot (I).Expected_Last)
            then
               Fail ("clean mismatch "
                 & Text_Of (Bank.Slot (I).Id, Bank.Slot (I).Id_Last));
            end if;
         end if;
      end loop;
      if A.Flagged (Bank) /= 5 then
         Fail ("flagged" & Natural'Image (A.Flagged (Bank)));
      end if;
      Index := Find (Bank, "fib-6");
      if Index = 0
        or else Text_Of
          (Bank.Slot (Index).True_Answer, Bank.Slot (Index).True_Last) /= "8"
      then
         Fail ("fib-6 recomputed");
      end if;
      Index := Find (Bank, "fib-20");
      if Index = 0
        or else Text_Of
          (Bank.Slot (Index).True_Answer, Bank.Slot (Index).True_Last)
          /= "6765"
      then
         Fail ("fib-20 recomputed");
      end if;
      Index := Find (Bank, "fib-5-wrong");
      if Index = 0
        or else not Bank.Slot (Index).Solvable
        or else Text_Of
          (Bank.Slot (Index).True_Answer, Bank.Slot (Index).True_Last) /= "5"
        or else Text_Of
          (Bank.Slot (Index).Expected, Bank.Slot (Index).Expected_Last) /= "9"
      then
         Fail ("fib-5 true answer");
      end if;
      Index := Find (Bank, "fib-21");
      if Index = 0 or else Bank.Slot (Index).Solvable then
         Fail ("fib-21 solvable");
      end if;
      Index := Find (Bank, "xor-00");
      if Index = 0
        or else Text_Of
          (Bank.Slot (Index).True_Answer, Bank.Slot (Index).True_Last) /= "0"
      then
         Fail ("xor-00");
      end if;
      Index := Find (Bank, "xor-11");
      if Index = 0
        or else Text_Of
          (Bank.Slot (Index).True_Answer, Bank.Slot (Index).True_Last) /= "0"
      then
         Fail ("xor-11");
      end if;
      Index := Find (Bank, "weight-over");
      if Index = 0
        or else Text_Of
          (Bank.Slot (Index).True_Answer, Bank.Slot (Index).True_Last)
          /= "bad-value"
      then
         Fail ("weight-over");
      end if;
      Index := Find (Bank, "weight-bad-shape");
      if Index = 0
        or else Text_Of
          (Bank.Slot (Index).True_Answer, Bank.Slot (Index).True_Last)
          /= "bad-shape"
      then
         Fail ("weight-bad-shape");
      end if;
      Index := Find (Bank, "weight-any");
      if Index = 0
        or else not Bank.Slot (Index).Grade_Any
        or else Text_Of
          (Bank.Slot (Index).True_Answer, Bank.Slot (Index).True_Last)
          /= "loaded"
      then
         Fail ("weight-any recomputed");
      end if;
      Index := Find (Bank, "fib-stop-bad");
      if Index = 0
        or else Text_Of
          (Bank.Slot (Index).True_Answer, Bank.Slot (Index).True_Last)
          /= "bad-arithmetic"
      then
         Fail ("fib-stop");
      end if;
      A.Score (Bank, False, Hits, Total, Accepted);
      if Accepted or else Hits /= 14 or else Total /= 20 then
         Fail ("full score" & Natural'Image (Hits) & Natural'Image (Total));
      end if;
      A.Score_Line (Bank, False, Line, Last);
      if Text_Of (Line, Last)
        /= "Full set: 14 of 20. Not accepted: audit-flagged."
      then
         Fail ("full line " & Text_Of (Line, Last));
      end if;
      A.Score (Bank, True, Hits, Total, Accepted);
      if not Accepted or else Hits /= 9 or else Total /= 15 then
         Fail ("clean score" & Natural'Image (Hits) & Natural'Image (Total));
      end if;
      A.Score_Line (Bank, True, Line, Last);
      if Text_Of (Line, Last) /= "Cleaned set: 9 of 15. Accepted." then
         Fail ("clean line " & Text_Of (Line, Last));
      end if;
      A.Line_For (Bank, Find (Bank, "xor-00"), Line, Last);
      if Text_Of (Line, Last) /= "xor-00  pass" then
         Fail ("pass line " & Text_Of (Line, Last));
      end if;
      A.Line_For (Bank, Find (Bank, "fib-4-leaked"), Line, Last);
      if Text_Of (Line, Last) /= "fib-4-leaked  flag  answer-leaked" then
         Fail ("leak line " & Text_Of (Line, Last));
      end if;
   end Check_Benchmark;

   Fixture : constant String :=
     "task clean-a" & Character'Val (10)
     & "kind xor-label" & Character'Val (10)
     & "prompt Label for inputs 0 0 only." & Character'Val (10)
     & "input 0 0" & Character'Val (10)
     & "expected 0" & Character'Val (10)
     & "grade exact" & Character'Val (10)
     & "sample 0" & Character'Val (10)
     & "end" & Character'Val (10)
     & "task clean-b" & Character'Val (10)
     & "kind fib-answer" & Character'Val (10)
     & "prompt Answer for index 2 alone." & Character'Val (10)
     & "input 2" & Character'Val (10)
     & "expected 1" & Character'Val (10)
     & "grade exact" & Character'Val (10)
     & "sample 1" & Character'Val (10)
     & "end" & Character'Val (10)
     & "task bad-key" & Character'Val (10)
     & "kind fib-answer" & Character'Val (10)
     & "prompt Answer for index 3 alone." & Character'Val (10)
     & "input 3" & Character'Val (10)
     & "expected 9" & Character'Val (10)
     & "grade exact" & Character'Val (10)
     & "sample 9" & Character'Val (10)
     & "end" & Character'Val (10)
     & "task no-way" & Character'Val (10)
     & "kind fib-answer" & Character'Val (10)
     & "prompt Answer for index 30 alone." & Character'Val (10)
     & "input 30" & Character'Val (10)
     & "expected 0" & Character'Val (10)
     & "grade exact" & Character'Val (10)
     & "sample 0" & Character'Val (10)
     & "end" & Character'Val (10)
     & "task copy-a" & Character'Val (10)
     & "kind xor-label" & Character'Val (10)
     & "prompt Same point as clean-a, inputs 0 0." & Character'Val (10)
     & "input 0 0" & Character'Val (10)
     & "expected 0" & Character'Val (10)
     & "grade exact" & Character'Val (10)
     & "sample 0" & Character'Val (10)
     & "end" & Character'Val (10)
     & "task wide-open" & Character'Val (10)
     & "kind xor-count" & Character'Val (10)
     & "prompt How many XOR points, answered loosely." & Character'Val (10)
     & "input" & Character'Val (10)
     & "expected 4" & Character'Val (10)
     & "grade any" & Character'Val (10)
     & "sample nope" & Character'Val (10)
     & "end" & Character'Val (10)
     & "task spilled" & Character'Val (10)
     & "kind fib-answer" & Character'Val (10)
     & "prompt The answer is 13. Answer for index 7." & Character'Val (10)
     & "input 7" & Character'Val (10)
     & "expected 13" & Character'Val (10)
     & "grade exact" & Character'Val (10)
     & "sample 13" & Character'Val (10)
     & "end" & Character'Val (10);

   procedure Check_Fixture is
      Bank : A.Set;
      Hits, Total : Natural;
      Accepted : Boolean;
   begin
      Load_Text (Fixture, Bank);
      if Bank.Count /= 7 then
         Fail ("fixture count");
         return;
      end if;
      Check_Clean (Bank, "clean-a");
      Check_Clean (Bank, "clean-b");
      Check_One_Flag (Bank, "bad-key", "wrong-expected");
      Check_One_Flag (Bank, "no-way", "unsolvable");
      Check_One_Flag (Bank, "copy-a", "duplicate");
      Check_One_Flag (Bank, "wide-open", "accept-anything");
      Check_One_Flag (Bank, "spilled", "answer-leaked");
      if A.Flagged (Bank) /= 5 then
         Fail ("fixture flags");
      end if;
      A.Score (Bank, False, Hits, Total, Accepted);
      if Accepted then
         Fail ("fixture full accepted");
      end if;
      A.Score (Bank, True, Hits, Total, Accepted);
      if not Accepted or else Total /= 2 or else Hits /= 2 then
         Fail ("fixture cleaned");
      end if;
   end Check_Fixture;

   procedure Check_Plain is
      Bank : A.Set;
      Hits, Total : Natural;
      Accepted : Boolean;
      Text : constant String :=
        "task only-one" & Character'Val (10)
        & "kind xor-label" & Character'Val (10)
        & "prompt Label for inputs 1 1 here." & Character'Val (10)
        & "input 1 1" & Character'Val (10)
        & "expected 0" & Character'Val (10)
        & "grade exact" & Character'Val (10)
        & "sample 0" & Character'Val (10)
        & "end" & Character'Val (10);
   begin
      Load_Text (Text, Bank);
      Check_Clean (Bank, "only-one");
      A.Score (Bank, False, Hits, Total, Accepted);
      if not Accepted or else Hits /= 1 or else Total /= 1 then
         Fail ("plain full");
      end if;
      A.Score (Bank, True, Hits, Total, Accepted);
      if not Accepted or else Hits /= 1 or else Total /= 1 then
         Fail ("plain cleaned");
      end if;
   end Check_Plain;

   function Read_File (Name : String) return String is
      File : Ada.Streams.Stream_IO.File_Type;
      Buf  : String (1 .. 12_000);
      Item : Ada.Streams.Stream_Element_Array (1 .. 1);
      Got  : Ada.Streams.Stream_Element_Offset;
      Last : Natural := 0;
   begin
      if not Ada.Directories.Exists (Name) then
         return "";
      end if;
      Ada.Streams.Stream_IO.Open
        (File, Ada.Streams.Stream_IO.In_File, Name);
      loop
         exit when Last = Buf'Last;
         Ada.Streams.Stream_IO.Read (File, Item, Got);
         exit when Integer (Got) < 1;
         Last := Last + 1;
         Buf (Last) := Character'Val (Integer (Item (1)));
      end loop;
      Ada.Streams.Stream_IO.Close (File);
      return Buf (Buf'First .. Last);
   end Read_File;

   function Exit_Of (Code : Integer) return Integer is
   begin
      if Code >= 256 then
         return Code / 256;
      end if;
      return Code;
   end Exit_Of;

   procedure Run_Cli
     (Args : GNAT.OS_Lib.Argument_List;
      Code : out Integer;
      Text : out String;
      Last : out Natural)
   is
      Out_Path : constant String := "/tmp/aaa-audit-cli-out";
      List     : GNAT.OS_Lib.Argument_List (Args'Range);
      OK       : Boolean;
      Raw      : Integer;
   begin
      Last := 0;
      for I in Args'Range loop
         List (I) := new String'(Args (I).all);
      end loop;
      GNAT.OS_Lib.Spawn
        ("bin/audit_cli", List, Out_Path, OK, Raw, Err_To_Out => True);
      for I in List'Range loop
         GNAT.OS_Lib.Free (List (I));
      end loop;
      if not OK then
         Code := -1;
         return;
      end if;
      Code := Exit_Of (Raw);
      declare
         Got : constant String := Read_File (Out_Path);
      begin
         if Got'Length > Text'Length then
            Text (Text'First .. Text'Last) :=
              Got (Got'First .. Got'First + Text'Length - 1);
            Last := Text'Last;
         elsif Got'Length > 0 then
            Text (Text'First .. Text'First + Got'Length - 1) := Got;
            Last := Text'First + Got'Length - 1;
         end if;
      end;
   end Run_Cli;

   function Demo_Text
     (Len  : Integer;
      Kind : Character;
      Row  : Integer) return String
   is
      Buf : String (1 .. 200) := (others => ' ');
      N   : Integer;
   begin
      if Len < 1 or else Len > Buf'Length then
         return "";
      end if;
      for I in 1 .. Len loop
         if Kind = 'F' then
            N := D.Full_Byte (I);
         elsif Kind = 'C' then
            N := D.Clean_Byte (I);
         elsif Kind = 'S' then
            N := D.Stat_Byte (I);
         else
            N := D.Line_Byte (Row, I);
         end if;
         Buf (I) := Character'Val (N);
      end loop;
      return Buf (1 .. Len);
   end Demo_Text;

   procedure Check_Demo is
      Passed : Boolean := False;
      Flags  : Natural := 0;
   begin
      if D.Task_Count /= 0 then
         Fail ("demo before run");
      end if;
      D.Run;
      if D.Task_Count /= 20 or else D.Flagged_Count /= 5 then
         Fail ("demo count");
      end if;
      if D.Mark (0) /= 0 or else D.Line_Byte (1, 0) /= 0 then
         Fail ("demo clamp");
      end if;
      if Demo_Text (D.Full_Length, 'F', 0)
        /= "Full set: 14 of 20. Not accepted: audit-flagged."
      then
         Fail ("demo full");
      end if;
      if Demo_Text (D.Clean_Length, 'C', 0)
        /= "Cleaned set: 9 of 15. Accepted."
      then
         Fail ("demo clean");
      end if;
      if Demo_Text (D.Stat_Length, 'S', 0)
        /= "20 tasks. 5 flagged before scoring."
      then
         Fail ("demo stat");
      end if;
      for I in 1 .. D.Task_Count loop
         declare
            Got : constant String :=
              Demo_Text (D.Line_Length (I), 'L', I);
         begin
            if D.Mark (I) = 0 then
               Passed := True;
               if Ada.Strings.Fixed.Count (Got, "  pass") /= 1 then
                  Fail ("demo pass " & Got);
               end if;
            else
               Flags := Flags + 1;
               if D.Mark (I) /= 1
                 or else Ada.Strings.Fixed.Count (Got, "  flag  ") /= 1
               then
                  Fail ("demo flag " & Got);
               end if;
            end if;
         end;
      end loop;
      if not Passed or else Flags /= 5 then
         Fail ("demo marks");
      end if;
   end Check_Demo;

   procedure Check_Cli is
      Empty : GNAT.OS_Lib.Argument_List (1 .. 0);
      Missing : GNAT.OS_Lib.Argument_List :=
        (1 => new String'("/tmp/aaa-audit-missing.txt"));
      File_Arg : GNAT.OS_Lib.Argument_List :=
        (1 => new String'("/tmp/aaa-audit-fixture.txt"));
      Code : Integer;
      Buf  : String (1 .. 12_000);
      Last : Natural;
      File : IO.File_Type;
   begin
      Run_Cli (Empty, Code, Buf, Last);
      if Code /= 0
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last), "wrong-expected") /= 1
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last), "unsolvable") /= 1
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last), "duplicate") /= 1
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last), "accept-anything") /= 1
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last), "answer-leaked") /= 1
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last),
           "Full set: 14 of 20. Not accepted: audit-flagged.") /= 1
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last), "Cleaned set: 9 of 15. Accepted.") /= 1
      then
         Fail ("cli benchmark " & Text_Of (Buf, Last));
      end if;
      IO.Create (File, IO.Out_File, "/tmp/aaa-audit-fixture.txt");
      IO.Put (File, Fixture);
      IO.Close (File);
      Run_Cli (File_Arg, Code, Buf, Last);
      if Code /= 0
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last), "bad-key  flag  wrong-expected") /= 1
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last), "no-way  flag  unsolvable") /= 1
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last), "copy-a  flag  duplicate") /= 1
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last), "wide-open  flag  accept-anything") /= 1
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last), "spilled  flag  answer-leaked") /= 1
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last), "clean-a  pass") /= 1
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last), "Not accepted: audit-flagged.") /= 1
      then
         Fail ("cli fixture");
      end if;
      Run_Cli (Missing, Code, Buf, Last);
      if Code /= 1
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last), "did not load") /= 1
      then
         Fail ("cli missing");
      end if;
      GNAT.OS_Lib.Free (Missing (1));
      GNAT.OS_Lib.Free (File_Arg (1));
   end Check_Cli;

begin
   Check_Benchmark;
   Check_Fixture;
   Check_Plain;
   Check_Demo;
   Check_Cli;
   if Failures = 0 then
      IO.Put_Line ("audit ok");
   else
      IO.Put_Line ("audit failed" & Natural'Image (Failures));
      Ada.Command_Line.Set_Exit_Status (1);
   end if;
end Audit_Test;
