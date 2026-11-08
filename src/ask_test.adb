with Ada.Command_Line;
with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with AI_Amplifier.Ask_Rule;
with AI_Amplifier.Recurse;
with AI_Amplifier.Traces;

--  Reads the files tools/check-ask.sh saved from the local
--  stand-in. The request and reply rules live in the plain
--  Ada callers. AI_Amplifier.Ask_Rule only classifies the
--  outcome. This program does not open a socket.
procedure Ask_Test
  with SPARK_Mode => Off
is
   package R renames AI_Amplifier.Recurse;
   package T renames AI_Amplifier.Traces;
   package Rule renames AI_Amplifier.Ask_Rule;
   use type Rule.Outcome;
   package IO renames Ada.Text_IO;

   Max_File : constant := 48_000;
   LF       : constant Character := Character'Val (10);

   Cases  : Natural := 0;
   Failed : Boolean := False;

   procedure Fail (Text : String) is
   begin
      IO.Put_Line (IO.Standard_Error, "fail " & Text);
      Failed := True;
   end Fail;

   procedure Pass is
   begin
      Cases := Cases + 1;
   end Pass;

   function Load (Name : String) return String is
      File : Ada.Streams.Stream_IO.File_Type;
      Buf  : String (1 .. Max_File);
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
   end Load;

   function Has (Text, Piece : String) return Boolean is
     (Ada.Strings.Fixed.Index (Text, Piece) > 0);

   function Has_Line (Text, Line : String) return Boolean is
      Pos : Natural := Text'First;
   begin
      if Text'Length = 0 then
         return False;
      end if;
      while Pos <= Text'Last loop
         declare
            First : constant Natural := Pos;
            Last  : Natural := Pos - 1;
         begin
            while Pos <= Text'Last and then Text (Pos) /= LF loop
               Last := Pos;
               Pos := Pos + 1;
            end loop;
            if Pos <= Text'Last and then Text (Pos) = LF then
               Pos := Pos + 1;
            end if;
            if Last >= First and then Text (First .. Last) = Line then
               return True;
            end if;
         end;
      end loop;
      return False;
   end Has_Line;

   function Exit_Code (Text : String) return Integer is
      Acc   : Integer := 0;
      Saw   : Boolean := False;
      Digit : Integer;
   begin
      for C of Text loop
         if C in '0' .. '9' then
            Digit := Character'Pos (C) - Character'Pos ('0');
            Acc := Acc * 10 + Digit;
            Saw := True;
         elsif Saw then
            exit;
         end if;
      end loop;
      if not Saw then
         return -1;
      end if;
      return Acc;
   end Exit_Code;

   procedure Check_Requests
     (Text   : String;
      Path   : String;
      Marker : String)
   is
      Pos     : Natural := Text'First;
      Count   : Natural := 0;
      Bad     : Boolean := False;
      Slot    : Natural := 0;
      Post    : Boolean := False;
      Auth    : Boolean := False;
      Type_OK : Boolean := False;
   begin
      if Text'Length = 0 then
         Fail ("no request " & Path);
         return;
      end if;
      while Pos <= Text'Last loop
         declare
            First : constant Natural := Pos;
            Last  : Natural := Pos - 1;
         begin
            while Pos <= Text'Last and then Text (Pos) /= LF loop
               Last := Pos;
               Pos := Pos + 1;
            end loop;
            if Pos <= Text'Last and then Text (Pos) = LF then
               Pos := Pos + 1;
            end if;
            if Last < First then
               null;
            else
               declare
                  Line : constant String := Text (First .. Last);
               begin
                  if Line'Length > 8
                    and then Line (Line'First .. Line'First + 7) = "request "
                  then
                     if Slot in 1 .. 3 then
                        Bad := True;
                     end if;
                     Post := Line = "request POST " & Path;
                     Auth := False;
                     Type_OK := False;
                     Slot := 1;
                  elsif Slot = 1 then
                     Auth := Line = "authorization: Bearer standin-key";
                     Slot := 2;
                  elsif Slot = 2 then
                     Type_OK := Has (Line, "application/json");
                     Slot := 3;
                  elsif Slot = 3 then
                     if not (Post and then Auth and then Type_OK
                             and then Has (Line, """model"":""standin""")
                             and then Has (Line, """temperature"":0")
                             and then Has (Line, """role"":""user""")
                             and then Has (Line, """messages""")
                             and then Has (Line, Marker)
                             and then not Has (Line, "standin-key"))
                     then
                        Bad := True;
                     end if;
                     Count := Count + 1;
                     Slot := 0;
                  end if;
               end;
            end if;
         end;
      end loop;
      if Slot in 1 .. 3 then
         Bad := True;
      end if;
      if Bad or else Count < 1 then
         Fail ("request " & Path);
      else
         Pass;
      end if;
   end Check_Requests;

   procedure Expect (OK : Boolean; Name : String) is
   begin
      if OK then
         Pass;
      else
         Fail (Name);
      end if;
   end Expect;

   Dir : constant String :=
     (if Ada.Command_Line.Argument_Count >= 1
      then Ada.Command_Line.Argument (1)
      else "obj/gen/ask");

   function File (Name : String) return String is
     (Load (Dir & "/" & Name));

   Recurse_Good   : constant String :=
     "{""choices"": [{""message"": {""role"": ""assistant"", "
     & """content"": ""index 0\nminus-one 1\ncurrent 1\n""}}]}";
   Traces_Good    : constant String :=
     "{""choices"": [{""message"": {""role"": ""assistant"", "
     & """content"": ""rate-1-train-200""}}]}";
   Broken_Body    : constant String :=
     "{""choices"": [{""message"": {""role"": ""assistant""}}]}";
   Recurse_State  : constant String :=
     "index 0" & LF & "minus-one 1" & LF & "current 1" & LF;
begin
   declare
      Reply : String (1 .. 200);
      Last  : Natural;
      OK    : Boolean;
   begin
      R.Assistant_Text (Recurse_Good, Reply, Last, OK);
      Expect
        (OK and then Last >= 1 and then Reply (1 .. Last) = Recurse_State,
         "recurse reply text");
      T.Assistant_Text (Traces_Good, Reply, Last, OK);
      Expect
        (OK and then Last >= 1
         and then Reply (1 .. Last) = "rate-1-train-200",
         "traces reply text");
      R.Assistant_Text (Broken_Body, Reply, Last, OK);
      Expect (not OK, "recurse broken text");
      T.Assistant_Text (Broken_Body, Reply, Last, OK);
      Expect (not OK, "traces broken text");
   end;

   Expect
     (Rule.Classify (True, True, True) = Rule.Accepted
      and then not Rule.Reports_Failure (Rule.Accepted),
      "classify accepted");
   Expect
     (Rule.Classify (True, True, False) = Rule.Wrong_Answer
      and then Rule.Reports_Failure (Rule.Wrong_Answer),
      "classify wrong");
   Expect
     (Rule.Classify (True, False, False) = Rule.Broken_Format
      and then Rule.Reports_Failure (Rule.Broken_Format),
      "classify broken");
   Expect
     (Rule.Classify (False, False, False) = Rule.Timed_Out
      and then Rule.Reports_Failure (Rule.Timed_Out),
      "classify timeout");
   Expect (not Rule.Real_Model_Checked, "no real model");

   declare
      Good_R : Boolean := False;
      Wrong_R : Boolean := False;
      Broken_R : Boolean := False;
      Timeout_R : Boolean := False;
      Good_T : Boolean := False;
      Wrong_T : Boolean := False;
      Broken_T : Boolean := False;
      Timeout_T : Boolean := False;
      Good_H : Boolean := False;
      Wrong_H : Boolean := False;
      Broken_H : Boolean := False;
      Timeout_H : Boolean := False;
      Http : constant String := File ("good-recurse.http");
      Cli  : constant String := File ("good-recurse.cli");
      Code : constant Integer := Exit_Code (File ("good-recurse.exit"));
   begin
      Check_Requests
        (Http, "/good/recurse",
         "index 1\nminus-one 0\ncurrent 1");
      Good_R :=
        Code = 0
        and then Has (Cli, "stop reached-base")
        and then Has (Cli, "answer 1")
        and then not Has (Cli, "the request failed")
        and then not Has (Cli, "bad-parse")
        and then not Has (Cli, "bad-arithmetic");
      Expect (Good_R, "recurse good");
      Check_Requests
        (File ("wrong-recurse.http"), "/wrong/recurse",
         "index 1\nminus-one 0\ncurrent 1");
      declare
         Text : constant String := File ("wrong-recurse.cli");
      begin
         Wrong_R :=
           Exit_Code (File ("wrong-recurse.exit")) = 1
           and then Has (Text, "stop bad-arithmetic")
           and then not Has (Text, "stop reached-base")
           and then not Has (Text, "the request failed");
         Expect (Wrong_R, "recurse wrong");
      end;
      Check_Requests
        (File ("broken-recurse.http"), "/broken/recurse",
         "index 1\nminus-one 0\ncurrent 1");
      declare
         Text : constant String := File ("broken-recurse.cli");
      begin
         Broken_R :=
           Exit_Code (File ("broken-recurse.exit")) = 1
           and then Has (Text, "stop bad-parse")
           and then not Has (Text, "stop reached-base");
         Expect (Broken_R, "recurse broken");
      end;
      Check_Requests
        (File ("timeout-recurse.http"), "/timeout/recurse",
         "index 1\nminus-one 0\ncurrent 1");
      declare
         Text : constant String := File ("timeout-recurse.cli");
      begin
         Timeout_R :=
           Exit_Code (File ("timeout-recurse.exit")) = 3
           and then Has (Text, "the request failed")
           and then not Has (Text, "stop reached-base");
         Expect (Timeout_R, "recurse timeout");
      end;
      Expect
        (Rule.Standin_Covers (Good_R, Wrong_R, Broken_R, Timeout_R),
         "recurse covers");

      Check_Requests
        (File ("good-traces.http"), "/good/traces", "Trace rate-diverges");
      declare
         Text : constant String := File ("good-traces.cli");
      begin
         Good_T :=
           Exit_Code (File ("good-traces.exit")) = 0
           and then Has (Text, "proposal rate-1-train-200")
           and then Has (Text, "verdict fixes-it")
           and then Has (Text, "reason xor-returned")
           and then not Has (Text, "the request failed");
         Expect (Good_T, "traces good");
      end;
      Check_Requests
        (File ("wrong-traces.http"), "/wrong/traces", "Trace rate-diverges");
      declare
         Text : constant String := File ("wrong-traces.cli");
      begin
         Wrong_T :=
           Has (Text, "proposal invert-output")
           and then
             (Has (Text, "verdict makes-it-worse")
              or else Has (Text, "verdict no-better"))
           and then not Has (Text, "verdict fixes-it")
           and then not Has (Text, "the request failed");
         Expect (Wrong_T, "traces wrong");
      end;
      Check_Requests
        (File ("broken-traces.http"), "/broken/traces",
         "Trace rate-diverges");
      declare
         Text : constant String := File ("broken-traces.cli");
      begin
         Broken_T :=
           Exit_Code (File ("broken-traces.exit")) = 1
           and then Has (Text, "proposal unreadable")
           and then Has (Text, "reason not-a-step")
           and then not Has (Text, "verdict fixes-it");
         Expect (Broken_T, "traces broken");
      end;
      Check_Requests
        (File ("timeout-traces.http"), "/timeout/traces",
         "Trace rate-diverges");
      declare
         Text : constant String := File ("timeout-traces.cli");
      begin
         Timeout_T :=
           Exit_Code (File ("timeout-traces.exit")) = 3
           and then Has (Text, "the request failed")
           and then not Has (Text, "verdict fixes-it");
         Expect (Timeout_T, "traces timeout");
      end;
      Expect
        (Rule.Standin_Covers (Good_T, Wrong_T, Broken_T, Timeout_T),
         "traces covers");

      Check_Requests
        (File ("good-harness.http"), "/good/harness",
         "Trace rate-diverges");
      declare
         Text : constant String := File ("good-harness.cli");
      begin
         Good_H :=
           Exit_Code (File ("good-harness.exit")) = 0
           and then Has (Text, "accepted")
           and then Has_Line (Text, "solved")
           and then not Has (Text, "not solved")
           and then not Has (Text, "the request failed");
         Expect (Good_H, "harness good");
      end;
      Check_Requests
        (File ("wrong-harness.http"), "/wrong/harness",
         "Trace rate-diverges");
      declare
         Text : constant String := File ("wrong-harness.cli");
      begin
         Wrong_H :=
           Exit_Code (File ("wrong-harness.exit")) = 1
           and then Has (Text, "not solved")
           and then Has (Text, "rejected")
           and then not Has_Line (Text, "solved")
           and then not Has (Text, "the request failed");
         Expect (Wrong_H, "harness wrong");
      end;
      Check_Requests
        (File ("broken-harness.http"), "/broken/harness",
         "Trace rate-diverges");
      declare
         Text : constant String := File ("broken-harness.cli");
      begin
         Broken_H :=
           Exit_Code (File ("broken-harness.exit")) = 1
           and then Has (Text, "bad-parse")
           and then Has (Text, "not solved")
           and then not Has_Line (Text, "solved");
         Expect (Broken_H, "harness broken");
      end;
      Check_Requests
        (File ("timeout-harness.http"), "/timeout/harness",
         "Trace rate-diverges");
      declare
         Text : constant String := File ("timeout-harness.cli");
      begin
         Timeout_H :=
           Exit_Code (File ("timeout-harness.exit")) = 3
           and then Has (Text, "the request failed")
           and then not Has_Line (Text, "solved");
         Expect (Timeout_H, "harness timeout");
      end;
      Expect
        (Rule.Standin_Covers (Good_H, Wrong_H, Broken_H, Timeout_H),
         "harness covers");
   end;

   if Failed then
      IO.Put_Line (IO.Standard_Error, "ask not ok");
      Ada.Command_Line.Set_Exit_Status (1);
      return;
   end if;
   IO.Put_Line ("ask-standin ok cases" & Natural'Image (Cases));
   IO.Put_Line ("cases ask_standin" & Natural'Image (Cases));
   IO.Put_Line ("ask ok");
end Ask_Test;
