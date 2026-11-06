with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with GNAT.OS_Lib;
with AI_Amplifier.MLP;
with AI_Amplifier.Traces.Demo;

--  The checker, the four recorded traces, the page wrapper, and
--  the native caller. The caller tests use a stand-in for curl.
--  They do not open a network connection.
procedure Traces_Test
  with SPARK_Mode => Off
is
   package M renames AI_Amplifier.MLP;
   package T renames AI_Amplifier.Traces;
   package D renames AI_Amplifier.Traces.Demo;
   use type T.Verdict_Kind;
   use type T.Reason_Kind;
   use type T.Proposal;
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

   function Near (Left, Right, Tol : Float) return Boolean is
     (abs (Left - Right) <= Tol);

   procedure Check_One
     (Index   : Natural;
      Name    : String;
      Good_V  : T.Verdict_Kind;
      Good_R  : T.Reason_Kind;
      Bad_V   : T.Verdict_Kind;
      Bad_R   : T.Reason_Kind)
   is
      Which                          : T.Proposal;
      OK                             : Boolean;
      Verdict                        : T.Verdict_Kind;
      Reason                         : T.Reason_Kind;
      Before, After                  : Float;
      Was_X, Now_X                   : Boolean;
      Line                           : String (1 .. T.Max_Line);
      Last                           : Natural;
   begin
      T.Trace_Name (Index, Line, Last);
      if Text_Of (Line, Last) /= Name then
         Fail ("name " & Name);
      end if;
      if T.Wrong_At (Index) /= T.Step_Count (Index)
        or else T.Step_Count (Index) < 2
      then
         Fail ("wrong at " & Name);
      end if;
      T.Step_Line (Index, T.Wrong_At (Index), Line, Last);
      if Ada.Strings.Fixed.Count (Text_Of (Line, Last), "Wrong turn:") /= 1
      then
         Fail ("wrong line " & Name);
      end if;
      T.State_Line (Index, Line, Last);
      if Ada.Strings.Fixed.Count (Text_Of (Line, Last), "xor missed") /= 1
        or else Ada.Strings.Fixed.Count
          (Text_Of (Line, Last), "weights valid") /= 1
      then
         Fail ("state " & Name & " " & Text_Of (Line, Last));
      end if;
      T.Judge
        (Index, 0, Verdict, Reason, Before, After, Was_X, Now_X, OK);
      if not OK or else Was_X or else Verdict /= T.No_Better
        or else Reason /= T.Not_A_Step
        or else not Near (Before, After, 0.0)
      then
         Fail ("not a step " & Name);
      end if;
      T.Known_Good (Index, Which, OK);
      if not OK then
         Fail ("known missing " & Name);
         return;
      end if;
      T.Judge
        (Index, T.Proposal_Code (Which), Verdict, Reason,
         Before, After, Was_X, Now_X, OK);
      if not OK or else Was_X or else not Now_X
        or else Verdict /= Good_V or else Reason /= Good_R
        or else After >= T.Loss_Max or else After >= Before
      then
         Fail ("good " & Name);
      end if;
      T.Report_Line (Index, T.Proposal_Code (Which), Line, Last);
      if Ada.Strings.Fixed.Count (Text_Of (Line, Last), "fixes-it") /= 1
        or else Ada.Strings.Fixed.Count
          (Text_Of (Line, Last), "xor-returned") /= 1
      then
         Fail ("good sentence " & Name);
      end if;
      T.Stored_Bad (Index, Which, OK);
      T.Judge
        (Index, T.Proposal_Code (Which), Verdict, Reason,
         Before, After, Was_X, Now_X, OK);
      if not OK or else Now_X or else Verdict /= Bad_V or else Reason /= Bad_R
      then
         Fail ("bad " & Name);
      end if;
   end Check_One;

   procedure Check_Rules is
      Verdict : T.Verdict_Kind;
      Reason  : T.Reason_Kind;
      Before  : Float;
      After   : Float;
      Was_X   : Boolean;
      Now_X   : Boolean;
      OK      : Boolean;
      Which   : T.Proposal;
      Model   : M.Net;
      Broken  : M.Net;
      Refused : Boolean;
      Word    : String (1 .. T.Max_Name);
      Last    : Natural;
      Prompt  : String (1 .. T.Max_Prompt);
      JSON    : String (1 .. T.Max_JSON);
      Back    : String (1 .. T.Max_Prompt);
   begin
      if T.Verdict_Code (T.Fixes_It) /= 1
        or else T.Verdict_Code (T.No_Better) /= 2
        or else T.Verdict_Code (T.Makes_It_Worse) /= 3
        or else T.Reason_Code (T.XOR_Returned) /= 1
        or else T.Reason_Code (T.XOR_Still_Missed) /= 2
        or else T.Reason_Code (T.XOR_Left) /= 3
        or else T.Reason_Code (T.Loss_Rose) /= 4
        or else T.Reason_Code (T.Loss_Did_Not_Fall) /= 5
        or else T.Reason_Code (T.Weights_Invalid) /= 6
        or else T.Reason_Code (T.Not_A_Step) /= 7
      then
         Fail ("codes");
      end if;
      Check_One
        (1, "rate-diverges", T.Fixes_It, T.XOR_Returned,
         T.Makes_It_Worse, T.Loss_Rose);
      Check_One
        (2, "padded-shape", T.Fixes_It, T.XOR_Returned,
         T.No_Better, T.Loss_Did_Not_Fall);
      Check_One
        (3, "silenced-and", T.Fixes_It, T.XOR_Returned,
         T.Makes_It_Worse, T.Loss_Rose);
      Check_One
        (4, "stopped-early", T.Fixes_It, T.XOR_Returned,
         T.Makes_It_Worse, T.Loss_Rose);

      T.Judge
        (1, 0, Verdict, Reason, Before, After, Was_X, Now_X, OK);
      if Before < 1.5 or else Before > 2.0 then
         Fail ("diverge loss");
      end if;
      T.Judge
        (4, T.Proposal_Code (T.Train_8), Verdict, Reason,
         Before, After, Was_X, Now_X, OK);
      if not OK or else Verdict /= T.No_Better
        or else Reason /= T.XOR_Still_Missed
        or else not (After + T.Loss_Epsilon < Before)
      then
         Fail ("early short train");
      end if;
      T.Judge
        (1, T.Proposal_Code (T.Revert_Edit), Verdict, Reason,
         Before, After, Was_X, Now_X, OK);
      if not OK or else Now_X or else Verdict /= T.No_Better
        or else Reason /= T.XOR_Still_Missed
      then
         Fail ("revert does not finish xor");
      end if;
      T.Judge
        (2, T.Proposal_Code (T.Train_200), Verdict, Reason,
         Before, After, Was_X, Now_X, OK);
      if not Near (Before, 0.693147, 0.001)
        or else not Near (After, Before, T.Loss_Epsilon)
      then
         Fail ("zero net moved");
      end if;
      T.Judge
        (4, T.Proposal_Code (T.Rate_5_Train_10), Verdict, Reason,
         Before, After, Was_X, Now_X, OK);
      if After < 4.0 or else Reason /= T.Loss_Rose then
         Fail ("early high rate");
      end if;

      T.Judge (0, 1, Verdict, Reason, Before, After, Was_X, Now_X, OK);
      if OK then
         Fail ("trace 0");
      end if;
      T.Judge (9, 1, Verdict, Reason, Before, After, Was_X, Now_X, OK);
      if OK then
         Fail ("trace 9");
      end if;
      T.Step_Line (1, 9, Word, Last);
      if Last /= 0 then
         Fail ("step past end");
      end if;

      Model := M.Hand_XOR;
      T.Refuse_Broken_Shape (Model, Refused);
      if not Refused or else Model.W1.Data (1, 1) /= M.Hand_Or_Weight then
         Fail ("shape refusal");
      end if;
      if M.Predict
        (Model, M.Make_Dataset (M.XOR_Points).Item (2).X) <= 0.8
      then
         Fail ("shape kept the hand net");
      end if;

      Model := M.Hand_XOR;
      Broken := Model;
      Broken.W1.Data (1, 1) := 1001.0;
      T.Judge_Pair (Model, Broken, Verdict, Reason);
      if Verdict /= T.Makes_It_Worse or else Reason /= T.Weights_Invalid then
         Fail ("weight over the limit");
      end if;
      T.Judge_Pair (Broken, Broken, Verdict, Reason);
      if Verdict /= T.No_Better or else Reason /= T.Weights_Invalid then
         Fail ("weight stayed invalid");
      end if;
      Broken.W1.Data (1, 1) := 1.0e20;
      T.Judge_Pair (Model, Broken, Verdict, Reason);
      if Verdict /= T.Makes_It_Worse or else Reason /= T.Weights_Invalid then
         Fail ("huge weight");
      end if;
      M.Apply_Preset (Model, M.Flip_Hidden_1);
      T.Judge_Pair (M.Hand_XOR, Model, Verdict, Reason);
      if Verdict /= T.Makes_It_Worse or else Reason /= T.XOR_Left then
         Fail ("xor left");
      end if;

      T.Parse_Proposal ("  train-200  ", Which, OK);
      if not OK or else Which /= T.Train_200 then
         Fail ("parse trim");
      end if;
      T.Parse_Proposal ("train-200.", Which, OK);
      if OK then
         Fail ("parse period");
      end if;
      T.Parse_Proposal ("please train-200", Which, OK);
      if OK then
         Fail ("parse sentence");
      end if;
      T.Proposal_From_Code (0, Which, OK);
      if OK then
         Fail ("code 0");
      end if;
      T.Proposal_From_Code (1, Which, OK);
      if not OK or else Which /= T.Rate_1_Train_200
        or else T.Proposal_Code (Which) /= 1
      then
         Fail ("code 1");
      end if;

      T.Prompt_For (1, Prompt, Last, OK);
      if not OK
        or else Ada.Strings.Fixed.Count
          (Text_Of (Prompt, Last), "rate-diverges") /= 1
        or else Ada.Strings.Fixed.Count
          (Text_Of (Prompt, Last), "fixes-it") /= 0
        or else Ada.Strings.Fixed.Count
          (Text_Of (Prompt, Last), "known-good") /= 0
        or else Ada.Strings.Fixed.Count
          (Text_Of (Prompt, Last), "rate-1-train-200") /= 1
        or else Ada.Strings.Fixed.Count
          (Text_Of (Prompt, Last), "load-bad-shape") /= 1
      then
         Fail ("prompt");
      end if;
      T.Request_JSON
        ("test-model", Text_Of (Prompt, Last), JSON, Last, OK);
      if not OK
        or else Ada.Strings.Fixed.Count (Text_Of (JSON, Last), """") < 4
      then
         Fail ("json");
      end if;
      T.Assistant_Text
        ("{""choices"":[{""message"":{""content"":""hand-xor""}}]}",
         Back, Last, OK);
      T.Parse_Proposal (Text_Of (Back, Last), Which, OK);
      if not OK or else Which /= T.Hand_Net then
         Fail ("assistant text");
      end if;
      T.Assistant_Text ("{""nope"":1}", Back, Last, OK);
      if OK then
         Fail ("assistant missing");
      end if;

      D.Select_Trace (1);
      if D.Step_Count /= 3 or else D.Wrong_Mark (3) /= 1
        or else D.Wrong_Mark (2) /= 0 or else D.Verdict /= 0
      then
         Fail ("demo select");
      end if;
      if D.Name_Byte (1) /= Character'Pos ('r') or else D.Name_Byte (0) /= 0
      then
         Fail ("demo name");
      end if;
      D.Propose (T.Proposal_Code (T.Invert_Out));
      if D.Verdict /= 3 or else D.Reason /= 4 then
         Fail ("demo bad verdict");
      end if;
      D.Propose (1);
      if D.Verdict /= 1 or else D.Reason /= 1 then
         Fail ("demo good verdict");
      end if;
      declare
         Kept : constant Integer := D.Verdict;
      begin
         D.Select_Trace (0);
         D.Select_Trace (9);
         if D.Verdict /= Kept then
            Fail ("demo bad select");
         end if;
      end;
      D.Propose (99);
      if D.Verdict /= 2 or else D.Reason /= 7 then
         Fail ("demo unknown code");
      end if;
      if D.Menu_Count /= 10 or else D.Menu_Length (1) < 1
        or else D.Menu_Byte (1, 0) /= 0
      then
         Fail ("demo menu");
      end if;
      if D.Line_Byte (1, 0) /= 0 or else D.Good_Length < 1
        or else D.State_Length < 1
      then
         Fail ("demo bytes");
      end if;
   end Check_Rules;

   Script : constant String := "/tmp/aaa-tr-fake-curl";
   Log    : constant String := "/tmp/aaa-tr-curl-log";
   Reply  : constant String := "/tmp/aaa-tr-fake-reply";

   procedure Write_File (Name, Text : String) is
      File : IO.File_Type;
   begin
      IO.Create (File, IO.Out_File, Name);
      IO.Put (File, Text);
      IO.Close (File);
   end Write_File;

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
      Out_Path : constant String := "/tmp/aaa-tr-cli-out";
      List     : GNAT.OS_Lib.Argument_List (Args'Range);
      OK       : Boolean;
      Raw      : Integer;
   begin
      Last := 0;
      for I in Args'Range loop
         List (I) := new String'(Args (I).all);
      end loop;
      GNAT.OS_Lib.Spawn
        ("bin/traces_cli", List, Out_Path, OK, Raw, Err_To_Out => True);
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
      Ask1  : GNAT.OS_Lib.Argument_List :=
        (new String'("--ask"), new String'("1"));
      Ask9  : GNAT.OS_Lib.Argument_List :=
        (new String'("--ask"), new String'("9"));
      Prompt : GNAT.OS_Lib.Argument_List :=
        (new String'("--print-prompt"), new String'("3"));
      Code  : Integer;
      Buf   : String (1 .. 12_000);
      Last  : Natural;
      Key   : constant String := "secret-token-xyz";
   begin
      if not Ada.Directories.Exists ("bin/traces_cli") then
         Fail ("traces_cli was not built");
         return;
      end if;
      Write_File
        (Script,
         "#!/bin/sh" & Character'Val (10)
         & "log=/tmp/aaa-tr-curl-log" & Character'Val (10)
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
         & "if [ -n ""$hdr"" ]; then" & Character'Val (10)
         & "  mode=$(stat -c %a ""$hdr"")" & Character'Val (10)
         & "  echo mode-$mode >> ""$log""" & Character'Val (10)
         & "  if grep -q secret-token-xyz ""$hdr""; then"
         & Character'Val (10)
         & "    echo saw-key >> ""$log""; fi" & Character'Val (10)
         & "fi" & Character'Val (10)
         & "if [ -n ""$out"" ]; then cat /tmp/aaa-tr-fake-reply > ""$out""; fi"
         & Character'Val (10)
         & "exit ${AAA_TR_CURL_EXIT:-0}" & Character'Val (10));
      GNAT.OS_Lib.Set_Executable (Script);

      Run_Cli (Empty, Code, Buf, Last);
      if Code /= 0
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "trace rate-diverges") = 0
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "verdict fixes-it") < 4
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "bad-verdict makes-it-worse") < 3
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "bad-verdict no-better") < 1
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "no request was sent") /= 0
      then
         Fail ("replay cli " & Integer'Image (Code));
      end if;

      Clear ("TRACES_LLM_KEY");
      Clear ("TRACES_LLM_URL");
      Clear ("TRACES_LLM_MODEL");
      Set ("TRACES_LLM_CURL", Script);
      Reset_Log;
      Run_Cli (Ask1, Code, Buf, Last);
      if Code /= 2
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "no request was sent") = 0
        or else Ada.Directories.Exists (Log)
      then
         Fail ("ask without a key");
      end if;

      Set ("TRACES_LLM_KEY", Key);
      Reset_Log;
      Run_Cli (Ask1, Code, Buf, Last);
      if Code /= 2
        or else Ada.Strings.Fixed.Count (Buf (1 .. Last), Key) /= 0
        or else Ada.Directories.Exists (Log)
      then
         Fail ("ask without a url leaked or called");
      end if;

      Set ("TRACES_LLM_URL", "http://127.0.0.1:9/nowhere");
      Set ("TRACES_LLM_MODEL", "test-model");
      Run_Cli (Ask9, Code, Buf, Last);
      if Code /= 2
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "no request was sent") = 0
        or else Ada.Directories.Exists (Log)
      then
         Fail ("ask too big");
      end if;

      Clear ("TRACES_LLM_KEY");
      Clear ("TRACES_LLM_URL");
      Clear ("TRACES_LLM_MODEL");
      Clear ("TRACES_LLM_CURL");
      Run_Cli (Prompt, Code, Buf, Last);
      if Code /= 0
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "silenced-and") = 0
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "revert-edit") = 0
        or else Ada.Strings.Fixed.Count (Buf (1 .. Last), "fixes-it") /= 0
        or else Ada.Strings.Fixed.Count (Buf (1 .. Last), "Bearer") /= 0
      then
         Fail ("print prompt");
      end if;

      Set ("TRACES_LLM_CURL", Script);
      Set ("TRACES_LLM_KEY", Key);
      Set ("TRACES_LLM_URL", "http://127.0.0.1:9/nowhere");
      Set ("TRACES_LLM_MODEL", "test-model");
      Set ("AAA_TR_CURL_EXIT", "0");
      Write_File
        (Reply,
         "{""choices"":[{""message"":{""content"":""invert-output""}}]}");
      Reset_Log;
      Run_Cli (Ask1, Code, Buf, Last);
      declare
         Seen : constant String := Read_File (Log);
      begin
         if Code /= 0
           or else Ada.Strings.Fixed.Count (Buf (1 .. Last), Key) /= 0
           or else Ada.Strings.Fixed.Count
             (Buf (1 .. Last), "verdict makes-it-worse") = 0
           or else Ada.Strings.Fixed.Count
             (Buf (1 .. Last), "reason loss-rose") = 0
           or else Ada.Strings.Fixed.Count (Seen, "invoked") /= 1
           or else Ada.Strings.Fixed.Count (Seen, "saw-key") /= 1
           or else Ada.Strings.Fixed.Count (Seen, "mode-600") /= 1
           or else Ada.Strings.Fixed.Count (Seen, "key-in-argv") /= 0
         then
            Fail ("live stand-in " & Integer'Image (Code));
         end if;
      end;

      Write_File
        (Reply,
         "{""choices"":[{""message"":{""content"":""rate-1-train-200""}}]}");
      Reset_Log;
      Run_Cli (Ask1, Code, Buf, Last);
      if Code /= 0
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "verdict fixes-it") = 0
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "reason xor-returned") = 0
      then
         Fail ("live good step");
      end if;

      Write_File
        (Reply,
         "{""choices"":[{""message"":{""content"":""try something else""}}]}");
      Reset_Log;
      Run_Cli (Ask1, Code, Buf, Last);
      if Code /= 1
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "reason not-a-step") = 0
        or else Ada.Strings.Fixed.Count (Read_File (Log), "invoked") /= 1
      then
         Fail ("live unreadable");
      end if;

      Set ("AAA_TR_CURL_EXIT", "7");
      Reset_Log;
      Run_Cli (Ask1, Code, Buf, Last);
      if Code /= 3
        or else Ada.Strings.Fixed.Count
          (Buf (1 .. Last), "the request failed") = 0
        or else Ada.Strings.Fixed.Count (Buf (1 .. Last), Key) /= 0
      then
         Fail ("curl failure");
      end if;

      Clear ("TRACES_LLM_KEY");
      Clear ("TRACES_LLM_URL");
      Clear ("TRACES_LLM_MODEL");
      Clear ("TRACES_LLM_CURL");
      Clear ("AAA_TR_CURL_EXIT");
      for A of Ask1 loop
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
      IO.Put_Line ("traces ok");
   else
      IO.Put_Line ("traces failed" & Natural'Image (Failures));
      Ada.Command_Line.Set_Exit_Status (1);
   end if;
end Traces_Test;
