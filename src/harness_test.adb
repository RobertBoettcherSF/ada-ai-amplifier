with Ada.Command_Line;
with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Text_IO;
with GNAT.OS_Lib;
with AI_Amplifier.Harness.Demo;

--  The fixed solver, the four harnesses, the page wrapper,
--  and harness_cli. The solver's text does not depend on
--  which harness asks. The checked harness does not keep a
--  step the item 9 or item 11 checker rejects.
procedure Harness_Test
  with SPARK_Mode => Off
is
   package H renames AI_Amplifier.Harness;
   package D renames AI_Amplifier.Harness.Demo;
   use type H.Harness_Name;
   package IO renames Ada.Text_IO;

   Failures : Natural := 0;

   procedure Fail (Message : String) is
   begin
      IO.Put_Line ("FAIL " & Message);
      Failures := Failures + 1;
   end Fail;

   function Slice (Buf : String; Last : Natural) return String is
   begin
      if Last < 1 then
         return "";
      end if;
      return Buf (Buf'First .. Buf'First + Last - 1);
   end Slice;

   function Has_Line (Text : String; Quote : String) return Boolean is
      Start : Natural := Text'First;
      First : Natural;
      Last  : Natural;
   begin
      if Quote'Length = 0 then
         return False;
      end if;
      while Start <= Text'Last loop
         First := Start;
         Last := Start - 1;
         while Start <= Text'Last
           and then Text (Start) /= Character'Val (10)
         loop
            Last := Start;
            Start := Start + 1;
         end loop;
         if Start <= Text'Last then
            Start := Start + 1;
         end if;
         if Last >= First and then Text (First .. Last) = Quote then
            return True;
         end if;
      end loop;
      return False;
   end Has_Line;

   procedure Same_Text
     (Index, Attempt : Natural;
      Note           : String;
      Ask            : H.Ask_Kind;
      Fib, Minus, Curr : Natural)
   is
      First : String (1 .. H.Max_Text);
      Again : String (1 .. H.Max_Text);
      FLast : Natural;
      ALast : Natural;
   begin
      for Which in H.Harness_Name loop
         H.Model_Propose
           (Index, Positive (Attempt), Note, Ask,
            Fib, Minus, Curr, Again, ALast);
         if Which = H.One_Shot then
            First (1 .. ALast) := Again (1 .. ALast);
            FLast := ALast;
         elsif Slice (Again, ALast) /= Slice (First, FLast) then
            Fail ("model changed with the harness");
         end if;
      end loop;
      H.Model_Propose
        (Index, Positive (Attempt), Note, Ask,
         Fib, Minus, Curr, Again, ALast);
      if Slice (Again, ALast) /= Slice (First, FLast) then
         Fail ("model changed on a second call");
      end if;
   end Same_Text;

   procedure Check_Identity is
      procedure Both (Note : String) is
      begin
         for Index in 1 .. H.Task_Count loop
            for Attempt in 1 .. 3 loop
               Same_Text
                 (Index, Attempt, Note, H.Whole, 0, 0, 0);
               Same_Text
                 (Index, Attempt, Note, H.One_Step, 4, 1, 2);
            end loop;
         end loop;
      end Both;
   begin
      Both ("");
      Both ("again");
      Both ("bad-parse");
      Both ("not-toward-base");
      Both ("bad-arithmetic");
      Both ("makes-it-worse");
      Both ("no-better");
      Both ("not-a-step");
   end Check_Identity;

   procedure Check_Logged (Which : H.Harness_Name; Index : Natural) is
      One  : H.Run;
      Text : String (1 .. H.Max_Text);
      Last : Natural;
      OK   : Boolean;
      Word : String (1 .. H.Max_Note);
      WLast : Natural;
   begin
      H.Run_One (Which, Index, One);
      if Which in H.Checked .. H.Budgeted and then One.Wrong /= 0 then
         Fail ("checked kept a bad step");
      end if;
      for N in 1 .. One.Calls loop
         declare
            Slot : constant H.Call := One.Item (N);
         begin
            if Slot.Note_Len = 0 then
               H.Model_Propose
                 (Index, Slot.Attempt, "", Slot.Ask,
                  Slot.Fib_Index, Slot.Minus_One, Slot.Curr_Value,
                  Text, Last);
            else
               H.Model_Propose
                 (Index, Slot.Attempt,
                  Slot.Note (1 .. Slot.Note_Len), Slot.Ask,
                  Slot.Fib_Index, Slot.Minus_One, Slot.Curr_Value,
                  Text, Last);
            end if;
            if Slot.Quote_Len > 0
              and then not Has_Line
                (Slice (Text, Last),
                 Slot.Quote (1 .. Slot.Quote_Len))
            then
               Fail ("logged quote is not the model text");
            end if;
            if Which in H.Checked .. H.Budgeted then
               H.Checker_Accepts
                 (Index, Slot.Fib_Index, Slot.Minus_One,
                  Slot.Curr_Value, Slice (Text, Last),
                  OK, Word, WLast);
               if OK /= Slot.Accepted then
                  Fail ("checked accept disagreed with the checker");
               end if;
               if Slot.Accepted and then not OK then
                  Fail ("accepted a rejected step");
               end if;
            end if;
         end;
      end loop;
   end Check_Logged;

   procedure Expect_Reject
     (Index, Fib, Minus, Curr : Natural;
      Text : String;
      Why  : String)
   is
      OK : Boolean;
      Note : String (1 .. H.Max_Note);
      Last : Natural;
   begin
      H.Checker_Accepts
        (Index, Fib, Minus, Curr, Text, OK, Note, Last);
      if OK then
         Fail ("accepted a known-wrong step " & Why);
      end if;
   end Expect_Reject;

   procedure Expect_Keep
     (Index : Natural;
      Text  : String;
      Why   : String)
   is
      OK : Boolean;
      Note : String (1 .. H.Max_Note);
      Last : Natural;
   begin
      H.Checker_Accepts
        (Index, 0, 0, 0, Text, OK, Note, Last);
      if not OK then
         Fail ("rejected the known repair " & Why);
      end if;
   end Expect_Keep;

   procedure Check_Known_Wrong is
      OK : Boolean;
      Note : String (1 .. H.Max_Note);
      Last : Natural;
      Text : String (1 .. H.Max_Text);
      TLast : Natural;
   begin
      Expect_Reject
        (2, 2, 1, 1,
         "index two" & Character'Val (10)
         & "minus-one 1" & Character'Val (10)
         & "current 2" & Character'Val (10),
         "garble");
      Expect_Reject
        (3, 4, 0, 1,
         "index 4" & Character'Val (10)
         & "minus-one 1" & Character'Val (10)
         & "current 1" & Character'Val (10),
         "stall");
      Expect_Reject
        (4, 4, 1, 2,
         "index 3" & Character'Val (10)
         & "minus-one 2" & Character'Val (10)
         & "current 4" & Character'Val (10),
         "bad sum");
      Expect_Reject (5, 0, 0, 0, "invert-output", "invert");
      Expect_Reject (6, 0, 0, 0, "train-200", "padded");
      Expect_Reject (7, 0, 0, 0, "flip-or", "flip");
      Expect_Reject (7, 0, 0, 0, "flip the hidden", "garbage");
      Expect_Reject (8, 0, 0, 0, "rate-5-train-10", "rate 5");
      Expect_Keep (5, "rate-1-train-200", "rate");
      Expect_Keep (6, "hand-xor", "hand");
      Expect_Keep (7, "revert-edit", "revert");
      Expect_Keep (8, "train-200", "stopped");
      H.Checker_Accepts
        (1, 1, 0, 1,
         "index 0" & Character'Val (10)
         & "minus-one 1" & Character'Val (10)
         & "current 1" & Character'Val (10),
         OK, Note, Last);
      if not OK then
         Fail ("fib-1 base");
      end if;
      H.Model_Propose
        (4, 1, "", H.One_Step, 4, 1, 2, Text, TLast);
      H.Checker_Accepts
        (4, 4, 1, 2, Slice (Text, TLast), OK, Note, Last);
      if OK or else Slice (Note, Last) /= "bad-arithmetic" then
         Fail ("fib-6 first step");
      end if;
      H.Model_Propose
        (4, 2, "bad-arithmetic", H.One_Step, 4, 1, 2, Text, TLast);
      H.Checker_Accepts
        (4, 4, 1, 2, Slice (Text, TLast), OK, Note, Last);
      if not OK then
         Fail ("fib-6 did not take the checker word");
      end if;
      H.Model_Propose
        (4, 2, "again", H.One_Step, 4, 1, 2, Text, TLast);
      H.Checker_Accepts
        (4, 4, 1, 2, Slice (Text, TLast), OK, Note, Last);
      if OK then
         Fail ("again cleared the bad sum");
      end if;
   end Check_Known_Wrong;

   procedure Expect_Run
     (Which : H.Harness_Name;
      Index : Natural;
      Solved : Boolean;
      Steps, Wrong : Natural;
      Why : String)
   is
      One : H.Run;
   begin
      H.Run_One (Which, Index, One);
      if One.Solved /= Solved
        or else One.Steps /= Steps
        or else One.Wrong /= Wrong
      then
         Fail (Why);
      end if;
   end Expect_Run;

   procedure Check_Scores is
      Bank : H.Table;
      Line : String (1 .. H.Max_Line);
      Last : Natural;
      Want_S : constant array (H.Harness_Name) of Natural :=
        (H.One_Shot => 1, H.Retry => 2,
         H.Checked => 8, H.Budgeted => 5);
      Want_N : constant array (H.Harness_Name) of Natural :=
        (H.One_Shot => 8, H.Retry => 10,
         H.Checked => 25, H.Budgeted => 18);
      Want_W : constant array (H.Harness_Name) of Natural :=
        (H.One_Shot => 7, H.Retry => 6,
         H.Checked => 0, H.Budgeted => 0);
   begin
      if H.Expected_Answer (1) /= 1
        or else H.Expected_Answer (2) /= 2
        or else H.Expected_Answer (3) /= 3
        or else H.Expected_Answer (4) /= 8
      then
         Fail ("fib answers");
      end if;
      H.Run_Table (Bank);
      for Which in H.Harness_Name loop
         if Bank (Which).Solved /= Want_S (Which)
           or else Bank (Which).Steps /= Want_N (Which)
           or else Bank (Which).Wrong /= Want_W (Which)
         then
            Fail ("table");
         end if;
      end loop;
      H.Cell (H.Checked, Bank, 2, Line, Last);
      if Slice (Line, Last) /= "8 of 8" then
         Fail ("solve rate");
      end if;
      H.Cell (H.Checked, Bank, 4, Line, Last);
      if Slice (Line, Last) /= "0" then
         Fail ("wrong cell");
      end if;
      Expect_Run (H.One_Shot, 1, True, 1, 0, "one fib-1");
      Expect_Run (H.One_Shot, 2, False, 1, 1, "one fib-3");
      Expect_Run (H.Retry, 2, True, 2, 0, "retry fib-3");
      Expect_Run (H.Retry, 3, False, 1, 1, "retry fib-4");
      Expect_Run (H.Checked, 2, True, 4, 0, "checked fib-3");
      Expect_Run (H.Budgeted, 2, False, 3, 0, "budget fib-3");
      Expect_Run (H.Budgeted, 1, True, 1, 0, "budget fib-1");
      Expect_Run (H.Checked, 5, True, 2, 0, "checked rate");
      Expect_Run (H.One_Shot, 7, False, 1, 1, "one silenced");
      Expect_Run (H.Retry, 7, False, 2, 1, "retry silenced");
      for Index in 1 .. H.Task_Count loop
         for Which in H.Harness_Name loop
            Check_Logged (Which, Index);
         end loop;
      end loop;
   end Check_Scores;

   function Read_Cell (Row, Col : Integer) return String is
      N : constant Integer := D.Cell_Length (Row, Col);
      Buf : String (1 .. 80);
   begin
      if N < 1 or else N > Buf'Length then
         return "";
      end if;
      for I in 1 .. N loop
         Buf (I) := Character'Val (D.Cell_Byte (Row, Col, I));
      end loop;
      return Buf (1 .. N);
   end Read_Cell;

   function Read_Stat return String is
      N : constant Integer := D.Stat_Length;
      Buf : String (1 .. 200);
   begin
      if N < 1 or else N > Buf'Length then
         return "";
      end if;
      for I in 1 .. N loop
         Buf (I) := Character'Val (D.Stat_Byte (I));
      end loop;
      return Buf (1 .. N);
   end Read_Stat;

   function Read_Log (Harness, Index : Integer) return String is
      N : constant Integer := D.Log_Length (Harness, Index);
      Buf : String (1 .. H.Max_Line);
   begin
      if N < 1 or else N > Buf'Length then
         return "";
      end if;
      for I in 1 .. N loop
         Buf (I) := Character'Val (D.Log_Byte (Harness, Index, I));
      end loop;
      return Buf (1 .. N);
   end Read_Log;

   function Index (Hay, Needle : String) return Natural is
   begin
      if Needle'Length = 0 or else Hay'Length < Needle'Length then
         return 0;
      end if;
      for I in Hay'First .. Hay'Last - Needle'Length + 1 loop
         if Hay (I .. I + Needle'Length - 1) = Needle then
            return I;
         end if;
      end loop;
      return 0;
   end Index;

   procedure Check_Demo is
      Saw : Boolean := False;
   begin
      if D.Count_Harnesses /= 0 then
         Fail ("demo ran early");
      end if;
      D.Run;
      if D.Count_Harnesses /= 4 or else D.Count_Tasks /= 8
        or else D.Column_Count /= 4
      then
         Fail ("demo census");
      end if;
      if Read_Cell (1, 2) /= "1 of 8"
        or else Read_Cell (2, 2) /= "2 of 8"
        or else Read_Cell (3, 2) /= "8 of 8"
        or else Read_Cell (4, 2) /= "5 of 8"
        or else Read_Cell (3, 4) /= "0"
        or else Read_Cell (4, 4) /= "0"
        or else Read_Cell (0, 1) /= "harness"
      then
         Fail ("demo cells");
      end if;
      if D.Cell_Length (9, 1) /= 0 or else D.Cell_Byte (1, 1, 0) /= 0
        or else D.Task_Length (0) /= 0
      then
         Fail ("demo clamp");
      end if;
      if Read_Stat /=
        "Seed 20261104. 8 tasks. The model is the same in every row."
      then
         Fail ("demo stat");
      end if;
      if D.Solved (1) /= 0 or else D.Solved (2) /= 1
        or else D.Solved (3) /= 1 or else D.Solved (4) /= 0
      then
         Fail ("showcase solved");
      end if;
      for N in 1 .. D.Log_Count (1) loop
         declare
            Line : constant String := Read_Log (1, N);
         begin
            if Line'Length < 4
              or else Line (Line'First .. Line'First + 3) /= "call"
            then
               Fail ("log");
            end if;
            if Index (Line, "index two") > 0 then
               Saw := True;
            end if;
         end;
      end loop;
      if not Saw then
         Fail ("one-shot did not show index two");
      end if;
      D.Select_Task (0);
      if D.Solved (2) /= 1 then
         Fail ("select ignored");
      end if;
      D.Select_Task (1);
      if D.Solved (1) /= 1 or else D.Solved (4) /= 1 then
         Fail ("fib-1 walk");
      end if;
      if D.Log_Count (0) /= 0 or else D.Log_Byte (1, 1, 0) /= 0 then
         Fail ("log clamp");
      end if;
   end Check_Demo;

   function Read_File (Name : String) return String is
      File : Ada.Streams.Stream_IO.File_Type;
      Buf  : String (1 .. 20_000);
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
      return Buf (1 .. Last);
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
      Out_Path : constant String := "/tmp/aaa-harness-cli-out";
      List     : GNAT.OS_Lib.Argument_List (Args'Range);
      OK       : Boolean;
      Raw      : Integer;
   begin
      Last := 0;
      for I in Args'Range loop
         List (I) := new String'(Args (I).all);
      end loop;
      GNAT.OS_Lib.Spawn
        ("bin/harness_cli", List, Out_Path, OK, Raw, Err_To_Out => True);
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
            Last := Text'Length;
         else
            Last := Got'Length;
         end if;
         if Last > 0 then
            Text (Text'First .. Text'First + Last - 1) :=
              Got (Got'First .. Got'First + Last - 1);
         end if;
      end;
   end Run_Cli;

   procedure Check_Cli is
      None : GNAT.OS_Lib.Argument_List (1 .. 0);
      Ask  : GNAT.OS_Lib.Argument_List :=
        (1 => new String'("--ask"), 2 => new String'("fib-1"));
      Prompt : GNAT.OS_Lib.Argument_List :=
        (1 => new String'("--print-prompt"),
         2 => new String'("fib-3"));
      Code : Integer;
      Text : String (1 .. 20_000);
      Last : Natural;
      Outp : String (1 .. 20_000);
   begin
      Run_Cli (None, Code, Text, Last);
      Outp (1 .. Last) := Text (1 .. Last);
      if Code /= 0
        or else Index (Outp (1 .. Last), "1 of 8") = 0
        or else Index (Outp (1 .. Last), "2 of 8") = 0
        or else Index (Outp (1 .. Last), "8 of 8") = 0
        or else Index (Outp (1 .. Last), "5 of 8") = 0
        or else Index (Outp (1 .. Last), "1 of 8  8  7") = 0
        or else Index (Outp (1 .. Last), "8 of 8  25  0") = 0
        or else Index (Outp (1 .. Last), "20261104") = 0
        or else Index (Outp (1 .. Last), "index two") = 0
      then
         Fail ("cli table");
      end if;
      Run_Cli (Ask, Code, Text, Last);
      if Code /= 2
        or else Index (Text (1 .. Last), "no request was sent") = 0
      then
         Fail ("cli ask");
      end if;
      Run_Cli (Prompt, Code, Text, Last);
      if Code /= 0
        or else Index (Text (1 .. Last), "index") = 0
        or else Index (Text (1 .. Last), "no request was sent") > 0
      then
         Fail ("cli prompt");
      end if;
      GNAT.OS_Lib.Free (Ask (1));
      GNAT.OS_Lib.Free (Ask (2));
      GNAT.OS_Lib.Free (Prompt (1));
      GNAT.OS_Lib.Free (Prompt (2));
   end Check_Cli;

begin
   Check_Identity;
   Check_Known_Wrong;
   Check_Scores;
   Check_Demo;
   Check_Cli;
   if Failures = 0 then
      IO.Put_Line ("harness ok");
   else
      IO.Put_Line ("harness failed");
      Ada.Command_Line.Set_Exit_Status (1);
   end if;
end Harness_Test;
