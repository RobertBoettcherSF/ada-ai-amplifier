with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with GNAT.OS_Lib;
with AI_Amplifier.Recurse.Demo;

--  The checker, the recorded chains, the page wrapper, and the
--  native caller. The caller tests use a stand-in for curl. They
--  do not open a network connection.
procedure Recurse_Test
  with SPARK_Mode => Off
is
   package R renames AI_Amplifier.Recurse;
   use type R.Check_Name;
   package D renames AI_Amplifier.Recurse.Demo;
   package IO renames Ada.Text_IO;

   Failures : Natural := 0;
   Cases    : Natural := 0;

   procedure Mark is
   begin
      Cases := Cases + 1;
   end Mark;

   procedure Fail (Message : String) is
   begin
      IO.Put_Line ("FAIL " & Message);
      Failures := Failures + 1;
   end Fail;

   function Text_Of
     (Buf  : String;
      Last : Natural) return String
   is
   begin
      if Last < 1 then
         return "";
      end if;
      return Buf (Buf'First .. Buf'First + Last - 1);
   end Text_Of;

   procedure Expect (Name, Got, Want : String) is
   begin
      Mark;
      if Got /= Want then
         Fail (Name & " got [" & Got & "] want [" & Want & "]");
      end if;
   end Expect;

   function Fib (N : Natural) return Natural is
      A, B, Next : Natural;
   begin
      if N = 0 then
         return 0;
      end if;
      A := 0;
      B := 1;
      for Unused in 2 .. N loop
         Next := A + B;
         A := B;
         B := Next;
      end loop;
      return B;
   end Fib;

   procedure Expect_Stop
     (Name   : String;
      Result : R.Replay;
      Kind   : R.Check_Name;
      Place  : Natural;
      Steps  : Natural;
      Answer : Natural)
   is
   begin
      Mark;
      if Result.Stop /= Kind then
         Fail (Name & " stop");
      end if;
      if Result.Stop_At /= Place
        or else Result.Accepted /= Steps
        or else Result.Answer /= Answer
      then
         Fail (Name & " place");
      end if;
   end Expect_Stop;

   procedure Check_Rules is
      Result          : R.Replay;
      Item, Proposed  : R.State;
      OK              : Boolean;
      Kind            : R.Check_Name;
      Chain           : String (1 .. R.Max_Chain);
      Body_Text       : String (1 .. R.Max_Chain);
      Last, Body_Last : Natural;
      Note            : String (1 .. R.Max_Note);
      Line            : String (1 .. R.Max_Line);
      JSON            : String (1 .. R.Max_JSON);
      Reply           : String (1 .. 400);
      Known           : constant array (0 .. 20) of Natural :=
        (0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55,
         89, 144, 233, 377, 610, 987, 1597, 2584, 4181, 6765);
   begin
      if Fib (6) /= 8 or else Fib (10) /= 55 or else Fib (20) /= 6765
      then
         Fail ("fib oracle");
      end if;
      for N in Known'Range loop
         if Fib (N) /= Known (N) then
            Fail ("fib table");
         end if;
         R.Correct_Chain (N, Chain, Last, OK);
         if not OK then
            Fail ("correct chain");
         else
            R.Check_Chain (Chain (1 .. Last), Result);
            Expect_Stop
              ("F" & Natural'Image (N), Result, R.Reached_Base,
               N + 1, N, Known (N));
            if N > 0
              and then Result.Item (Result.Count).Curr_Value
                /= Known (N) + Known (N - 1)
            then
               Fail ("successor");
            end if;
         end if;
      end loop;

      R.Correct_Chain (R.Max_Index + 1, Chain, Last, OK);
      if OK or else Last /= 0 then
         Fail ("index cap");
      end if;

      R.Chain_Body (1, Body_Text, Body_Last);
      R.Correct_Chain (6, Chain, Last, OK);
      if not OK or else Body_Text (1 .. Body_Last) /= Chain (1 .. Last)
      then
         Fail ("recorded fib-6 drifted from the generator");
      end if;
      R.Replay_Recorded (1, Result, OK);
      Expect_Stop ("recorded 6", Result, R.Reached_Base, 7, 6, 8);
      R.Describe (Result, Note, Last);
      Expect
        ("note 6", Text_Of (Note, Last),
         "Reached the base case. minus-one is 8 after 6 accepted steps.");
      R.Step_Line (Result, 1, Line, Last);
      Expect
        ("line 1", Text_Of (Line, Last),
         "index 6  minus-one 0  current 1  ok");
      R.Step_Line (Result, 7, Line, Last);
      Expect
        ("line 7", Text_Of (Line, Last),
         "index 0  minus-one 8  current 13  base");

      R.Replay_Recorded (2, Result, OK);
      Expect_Stop ("bad sum", Result, R.Bad_Arithmetic, 4, 2, 0);
      if Result.Item (4).Curr_Value /= 4
        or else Result.Item (4).Fib_Index /= 3
      then
         Fail ("bad sum values");
      end if;
      R.Describe (Result, Note, Last);
      Expect
        ("note sum", Text_Of (Note, Last),
         "Stopped at state 4. The check that failed is bad arithmetic.");

      R.Replay_Recorded (3, Result, OK);
      Expect_Stop ("stall", Result, R.Not_Toward_Base, 2, 0, 0);
      R.Describe (Result, Note, Last);
      Expect
        ("note stall", Text_Of (Note, Last),
         "Stopped at state 2. The check that failed is not toward base.");

      R.Replay_Recorded (4, Result, OK);
      Expect_Stop ("garbled", Result, R.Bad_Parse, 3, 1, 0);
      if Result.Item (3).Parsed then
         Fail ("garbled parsed");
      end if;
      R.Step_Line (Result, 3, Line, Last);
      Expect ("garbled line", Text_Of (Line, Last), "unreadable  halt");

      R.Check_Chain ("", Result);
      Expect_Stop ("empty", Result, R.Bad_Parse, 0, 0, 0);

      R.Check_Chain
        ("index 4" & Character'Val (10)
         & "minus-one 1" & Character'Val (10)
         & "current 1" & Character'Val (10),
         Result);
      Expect_Stop ("opening", Result, R.Bad_Opening, 1, 0, 0);

      R.Check_Chain
        ("index 2" & Character'Val (10)
         & "# kept" & Character'Val (10)
         & "minus-one 0" & Character'Val (10)
         & "current 1" & Character'Val (10)
         & "---" & Character'Val (10)
         & "index 1" & Character'Val (10)
         & "minus-one 1" & Character'Val (10)
         & "current 1" & Character'Val (10)
         & "---" & Character'Val (10)
         & "index 0" & Character'Val (10)
         & "minus-one 1" & Character'Val (10)
         & "current 2" & Character'Val (10)
         & "---" & Character'Val (10)
         & "index 0" & Character'Val (10)
         & "minus-one 1" & Character'Val (10)
         & "current 2" & Character'Val (10),
         Result);
      Expect_Stop ("past", Result, R.Past_Base, 4, 2, 1);

      R.Check_Chain
        ("index 4" & Character'Val (10)
         & "minus-one 0" & Character'Val (10)
         & "current 1" & Character'Val (10),
         Result);
      Expect_Stop ("short", Result, R.Unfinished, 1, 0, 0);

      declare
         Huge : constant String (1 .. R.Max_Chain + 1) :=
           (others => 'x');
      begin
         R.Check_Chain (Huge, Result);
      end;
      Expect_Stop ("huge", Result, R.Too_Long, 0, 0, 0);

      R.Make_Opening (1, Item, OK);
      Proposed := (Fib_Index => 0, Minus_One => 1, Curr_Value => 1);
      R.Check_Step (Item, Proposed, Kind);
      if Kind /= R.Reached_Base then
         Fail ("one step");
      end if;
      Proposed.Curr_Value := 9;
      R.Check_Step (Item, Proposed, Kind);
      if Kind /= R.Bad_Arithmetic then
         Fail ("wrong sum first");
      end if;
      Proposed := (Fib_Index => 1, Minus_One => 1, Curr_Value => 1);
      R.Check_Step (Item, Proposed, Kind);
      if Kind /= R.Not_Toward_Base then
         Fail ("progress before arithmetic");
      end if;

      R.Parse_State ("index 1" & Character'Val (10)
        & "index 1" & Character'Val (10)
        & "minus-one 0" & Character'Val (10)
        & "current 1", Item, OK);
      if OK then
         Fail ("duplicate field");
      end if;
      R.Parse_State ("index -1" & Character'Val (10)
        & "minus-one 0" & Character'Val (10)
        & "current 1", Item, OK);
      if OK then
         Fail ("sign");
      end if;
      R.Parse_State ("index 1" & Character'Val (10)
        & "minus-one 0" & Character'Val (10)
        & "current 20001", Item, OK);
      if OK then
         Fail ("range");
      end if;

      R.Request_JSON
        ("a""b", "x\y" & Character'Val (10) & "z", JSON, Last, OK);
      if not OK
        or else JSON (1 .. Last)'Length < 10
        or else JSON (1) /= '{'
        or else JSON (Last) /= '}'
      then
         Fail ("json shape");
      end if;
      if Ada.Strings.Fixed.Count
           (JSON (1 .. Last), """model"":""a\""b""") = 0
        or else Ada.Strings.Fixed.Count
           (JSON (1 .. Last), "x\\y\nz") = 0
        or else Ada.Strings.Fixed.Count
           (JSON (1 .. Last), """temperature"":0") = 0
      then
         Fail ("json escape");
      end if;

      declare
         Sample : constant String :=
           "{""choices"":[{""message"":{""content"":"
           & """index 0\nminus-one 1\ncurrent 1""}}]}";
      begin
         R.Assistant_Text (Sample, Reply, Last, OK);
         if not OK then
            Fail ("content missing");
         else
            Expect
              ("content", Text_Of (Reply, Last),
               "index 0" & Character'Val (10)
               & "minus-one 1" & Character'Val (10)
               & "current 1");
         end if;
      end;
      R.Assistant_Text ("{""choices"":[]}", Reply, Last, OK);
      if OK then
         Fail ("empty choices");
      end if;

      if D.Chain_Count /= 4 or else D.Max_Index /= 20 then
         Fail ("demo census");
      end if;
      if D.Answer /= 8 or else D.Accepted_Steps /= 6
        or else D.Stop_Kind /= 0
      then
         Fail ("demo chain 1");
      end if;
      D.Select_Chain (0);
      if D.Answer /= 8 then
         Fail ("demo ignored a bad index");
      end if;
      D.Select_Chain (2);
      if D.Stop_Kind /= 4 or else D.Stop_At /= 4
        or else D.State_Current (4) /= 4
      then
         Fail ("demo bad sum");
      end if;
      D.Select_Chain (3);
      if D.Stop_Kind /= 3 or else D.State_Index (2) /= 4 then
         Fail ("demo stall");
      end if;
      D.Select_Chain (4);
      if D.Stop_Kind /= 1 or else D.Parsed (3) /= 0
        or else D.Line_Byte (3, 1) /= Character'Pos ('u')
      then
         Fail ("demo garbled");
      end if;
      if D.Line_Byte (3, 0) /= 0 or else D.Name_Byte (0) /= 0 then
         Fail ("demo clamp");
      end if;
      D.Select_Chain (99);
      if D.Stop_Kind /= 1 then
         Fail ("demo kept the garbled chain");
      end if;
   end Check_Rules;

   Script : constant String := "/tmp/aaa-rec-fake-curl";
   Log    : constant String := "/tmp/aaa-rec-curl-log";
   Reply  : constant String := "/tmp/aaa-rec-fake-reply";

   procedure Write_File (Name, Text : String) is
      File : IO.File_Type;
   begin
      IO.Create (File, IO.Out_File, Name);
      IO.Put (File, Text);
      IO.Close (File);
   end Write_File;

   function Read_File (Name : String) return String is
      File : Ada.Streams.Stream_IO.File_Type;
      Buf  : String (1 .. 8_000);
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

   procedure Reset_Log is
   begin
      if Ada.Directories.Exists (Log) then
         Ada.Directories.Delete_File (Log);
      end if;
   end Reset_Log;

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
      Out_Path : constant String := "/tmp/aaa-rec-cli-out";
      List     : GNAT.OS_Lib.Argument_List (Args'Range);
      OK       : Boolean;
      Raw      : Integer;
   begin
      Last := 0;
      for I in Args'Range loop
         List (I) := new String'(Args (I).all);
      end loop;
      GNAT.OS_Lib.Spawn
        ("bin/recurse_cli", List, Out_Path, OK, Raw, Err_To_Out => True);
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

   procedure Check_Cli is
      use Ada.Environment_Variables;
      Empty : GNAT.OS_Lib.Argument_List (1 .. 0);
      Ask2  : GNAT.OS_Lib.Argument_List :=
        (new String'("--ask"), new String'("2"));
      Ask0  : GNAT.OS_Lib.Argument_List :=
        (new String'("--ask"), new String'("0"));
      Ask9  : GNAT.OS_Lib.Argument_List :=
        (new String'("--ask"), new String'("99"));
      Prompt : GNAT.OS_Lib.Argument_List :=
        (new String'("--print-prompt"), new String'("6"));
      Code  : Integer;
      Buf   : String (1 .. 8_000);
      Last  : Natural;
      Key   : constant String := "secret-token-xyz";
   begin
      if not Ada.Directories.Exists ("bin/recurse_cli") then
         Fail ("recurse_cli was not built");
         return;
      end if;
      Write_File
        (Script,
         "#!/bin/sh" & Character'Val (10)
         & "log=/tmp/aaa-rec-curl-log" & Character'Val (10)
         & "echo invoked >> ""$log""" & Character'Val (10)
         & "prev=" & Character'Val (10)
         & "out=" & Character'Val (10)
         & "hdr=" & Character'Val (10)
         & "for a in ""$@""; do" & Character'Val (10)
         & "  if [ ""$prev"" = --output ]; then out=$a; fi"
         & Character'Val (10)
         & "  if [ ""$prev"" = --header ]; then hdr=$a; fi"
         & Character'Val (10)
         & "  case ""$a"" in" & Character'Val (10)
         & "    *secret-token-xyz*) echo key-in-argv >> ""$log"" ;;"
         & Character'Val (10)
         & "  esac" & Character'Val (10)
         & "  prev=$a" & Character'Val (10)
         & "done" & Character'Val (10)
         & "hdr=${hdr#@}" & Character'Val (10)
         & "if [ -n ""$hdr"" ] && grep -q secret-token-xyz ""$hdr"";"
         & " then echo saw-key >> ""$log""; fi" & Character'Val (10)
         & "n=$(grep -c invoked ""$log"")" & Character'Val (10)
         & "if [ -n ""$out"" ]; then" & Character'Val (10)
         & "  if [ ""$n"" -eq 1 ]; then" & Character'Val (10)
         & "    cat /tmp/aaa-rec-fake-reply > ""$out""" & Character'Val (10)
         & "  else" & Character'Val (10)
         & "    cat /tmp/aaa-rec-fake-reply2 > ""$out""" & Character'Val (10)
         & "  fi" & Character'Val (10)
         & "fi" & Character'Val (10)
         & "exit ${AAA_CURL_EXIT:-0}" & Character'Val (10));
      GNAT.OS_Lib.Set_Executable (Script);

      Run_Cli (Empty, Code, Buf, Last);
      if Code /= 0
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "chain fib-6-complete") = 0
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "stop reached-base") = 0
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "answer 8") = 0
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "stop bad-arithmetic") = 0
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "stop not-toward-base") = 0
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "stop bad-parse") = 0
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "no request was sent") /= 0
      then
         Fail ("replay cli " & Integer'Image (Code));
      end if;

      Clear ("RECURSE_LLM_KEY");
      Clear ("RECURSE_LLM_URL");
      Clear ("RECURSE_LLM_MODEL");
      Set ("RECURSE_LLM_CURL", Script);
      Reset_Log;
      Run_Cli (Ask2, Code, Buf, Last);
      if Code /= 2
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "no request was sent") = 0
        or else Ada.Directories.Exists (Log)
      then
         Fail ("ask without a key");
      end if;

      Set ("RECURSE_LLM_KEY", Key);
      Reset_Log;
      Run_Cli (Ask2, Code, Buf, Last);
      if Code /= 2
        or else Ada.Strings.Fixed.Count (Buf (1 .. Last), Key) /= 0
        or else Ada.Directories.Exists (Log)
      then
         Fail ("ask without a url leaked or called");
      end if;

      Set ("RECURSE_LLM_URL", "http://127.0.0.1:9/nowhere");
      Set ("RECURSE_LLM_MODEL", "test-model");
      Reset_Log;
      Run_Cli (Ask0, Code, Buf, Last);
      if Code /= 0
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "stop reached-base") = 0
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "no request was sent") = 0
        or else Ada.Directories.Exists (Log)
      then
         Fail ("ask zero");
      end if;

      Run_Cli (Ask9, Code, Buf, Last);
      if Code /= 2
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "no request was sent") = 0
        or else Ada.Directories.Exists (Log)
      then
         Fail ("ask too big");
      end if;

      Clear ("RECURSE_LLM_KEY");
      Clear ("RECURSE_LLM_URL");
      Clear ("RECURSE_LLM_MODEL");
      Clear ("RECURSE_LLM_CURL");
      Run_Cli (Prompt, Code, Buf, Last);
      if Code /= 0
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "index 6") = 0
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "minus-one 0") = 0
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "current 1") = 0
        or else Ada.Strings.Fixed.Count (Buf (1 .. Last), "http://") /= 0
        or else Ada.Strings.Fixed.Count (Buf (1 .. Last), "Bearer") /= 0
      then
         Fail ("print prompt");
      end if;

      Set ("RECURSE_LLM_CURL", Script);
      Set ("RECURSE_LLM_KEY", Key);
      Set ("RECURSE_LLM_URL", "http://127.0.0.1:9/nowhere");
      Set ("RECURSE_LLM_MODEL", "test-model");
      Set ("AAA_CURL_EXIT", "0");
      Write_File
        (Reply,
         "{""choices"":[{""message"":{""content"":"
         & """index 1\nminus-one 1\ncurrent 1""}}]}");
      Write_File
        ("/tmp/aaa-rec-fake-reply2",
         "{""choices"":[{""message"":{""content"":"
         & """index 0\nminus-one 1\ncurrent 2""}}]}");
      Reset_Log;
      Run_Cli (Ask2, Code, Buf, Last);
      declare
         Seen : constant String := Read_File (Log);
      begin
         if Code /= 0
           or else Ada.Strings.Fixed.Count (Buf (1 .. Last), Key) /= 0
           or else Ada.Strings.Fixed.Count
             (Buf (1 .. Last), "stop reached-base") = 0
           or else Ada.Strings.Fixed.Count (Buf (1 .. Last), "answer 1") = 0
           or else Ada.Strings.Fixed.Count (Buf (1 .. Last), "steps 2") = 0
           or else Ada.Strings.Fixed.Count (Seen, "invoked") /= 2
           or else Ada.Strings.Fixed.Count (Seen, "saw-key") /= 2
           or else Ada.Strings.Fixed.Count (Seen, "key-in-argv") /= 0
         then
            Fail ("live stand-in " & Integer'Image (Code));
         end if;
      end;

      Write_File
        (Reply,
         "{""choices"":[{""message"":{""content"":"
         & """index 1\nminus-one 1\ncurrent 9""}}]}");
      Reset_Log;
      Run_Cli (Ask2, Code, Buf, Last);
      if Code /= 1
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "stop bad-arithmetic") = 0
        or else Ada.Strings.Fixed.Count (Read_File (Log), "invoked") /= 1
      then
         Fail ("live bad arithmetic");
      end if;

      Set ("AAA_CURL_EXIT", "7");
      Reset_Log;
      Run_Cli (Ask2, Code, Buf, Last);
      if Code /= 3
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "the request failed") = 0
        or else Ada.Strings.Fixed.Count (Buf (1 .. Last), Key) /= 0
      then
         Fail ("curl failure");
      end if;

      Clear ("RECURSE_LLM_KEY");
      Clear ("RECURSE_LLM_URL");
      Clear ("RECURSE_LLM_MODEL");
      Clear ("RECURSE_LLM_CURL");
      Clear ("AAA_CURL_EXIT");
      for A of Ask2 loop
         GNAT.OS_Lib.Free (A);
      end loop;
      for A of Ask0 loop
         GNAT.OS_Lib.Free (A);
      end loop;
      for A of Ask9 loop
         GNAT.OS_Lib.Free (A);
      end loop;
      for A of Prompt loop
         GNAT.OS_Lib.Free (A);
      end loop;
   end Check_Cli;

begin
   Check_Rules;
   Check_Cli;
   if Failures = 0 then
      IO.Put_Line ("cases recurse_test" & Cases'Image);
      IO.Put_Line ("recurse ok");
   else
      IO.Put_Line ("recurse failed" & Natural'Image (Failures));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Recurse_Test;
