with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with GNAT.OS_Lib;
with AI_Amplifier.Recurse;

--  Native only. build.sh does not compile this into the page.
--  With no arguments it replays the recorded chains and does
--  not open a socket. --ask calls a chat endpoint only when
--  RECURSE_LLM_URL, RECURSE_LLM_KEY, and RECURSE_LLM_MODEL are
--  all set. The key is written to a mode 0600 file for curl
--  and is not placed on the command line.
procedure Recurse_Cli
  with SPARK_Mode => Off
is
   package R renames AI_Amplifier.Recurse;
   use type R.Check_Name;
   use type Ada.Streams.Stream_Element_Offset;
   package Env renames Ada.Environment_Variables;
   package IO renames Ada.Text_IO;

   LF : constant Character := Character'Val (10);
   CR : constant Character := Character'Val (13);

   procedure Put_Line (Item : String) is
   begin
      IO.Put_Line (Item);
   end Put_Line;

   function Trimmed (Value : String) return String is
   begin
      return Ada.Strings.Fixed.Trim (Value, Ada.Strings.Both);
   end Trimmed;

   function Env_Or_Empty (Name : String) return String is
   begin
      if Env.Exists (Name) then
         return Trimmed (Env.Value (Name));
      end if;
      return "";
   end Env_Or_Empty;

   function Pid_Text return String is
      Raw : constant String :=
        Integer'Image (GNAT.OS_Lib.Pid_To_Integer
          (GNAT.OS_Lib.Current_Process_Id));
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Left);
   end Pid_Text;

   function All_Digits (Value : String) return Boolean is
   begin
      if Value'Length = 0 then
         return False;
      end if;
      for C of Value loop
         if C not in '0' .. '9' then
            return False;
         end if;
      end loop;
      return True;
   end All_Digits;

   procedure Parse_Index
     (Value : String;
      Index : out Natural;
      OK    : out Boolean)
   is
      Acc : Natural := 0;
   begin
      Index := 0;
      OK := False;
      if not All_Digits (Value) or else Value'Length > 6 then
         return;
      end if;
      for C of Value loop
         declare
            Digit : constant Natural :=
              Character'Pos (C) - Character'Pos ('0');
         begin
            if Acc > (R.Max_Index - Digit) / 10 then
               return;
            end if;
            Acc := Acc * 10 + Digit;
         end;
      end loop;
      Index := Acc;
      OK := True;
   end Parse_Index;

   function Single_Line (Value : String) return Boolean is
   begin
      if Value'Length = 0 or else Value'Length > 400 then
         return False;
      end if;
      for C of Value loop
         if C = LF or else C = CR or else Character'Pos (C) = 0 then
            return False;
         end if;
      end loop;
      return True;
   end Single_Line;

   function Web_URL (Value : String) return Boolean is
   begin
      if Value'Length < 8 or else Value'Length > 500 then
         return False;
      end if;
      for C of Value loop
         if Character'Pos (C) <= 32 or else Character'Pos (C) > 126
         then
            return False;
         end if;
      end loop;
      return Value (Value'First .. Value'First + 7) = "https://"
        or else
          (Value'Length >= 7
           and then Value (Value'First .. Value'First + 6) = "http://");
   end Web_URL;

   function Model_OK (Value : String) return Boolean is
   begin
      if Value'Length = 0 or else Value'Length > 80 then
         return False;
      end if;
      for C of Value loop
         if Character'Pos (C) < 33 or else Character'Pos (C) > 126
           or else C = '"' or else C = '\'
         then
            return False;
         end if;
      end loop;
      return True;
   end Model_OK;

   procedure Show_Word (Kind : R.Check_Name) is
      Text : String (1 .. R.Max_Name);
      Last : Natural;
   begin
      R.Kind_Word (Kind, Text, Last);
      if Last >= 1 then
         IO.Put (Text (1 .. Last));
      end if;
   end Show_Word;

   procedure Show_Replay is
      Result : R.Replay;
      OK     : Boolean;
      Name   : String (1 .. R.Max_Name);
      Note   : String (1 .. R.Max_Note);
      Line   : String (1 .. R.Max_Line);
      Last   : Natural;
   begin
      for I in 1 .. R.Chain_Count loop
         R.Chain_Name (I, Name, Last);
         Put_Line ("chain " & Name (1 .. Last));
         R.Replay_Recorded (I, Result, OK);
         IO.Put ("stop ");
         Show_Word (Result.Stop);
         IO.New_Line;
         Put_Line ("answer" & Natural'Image (Result.Answer));
         Put_Line ("steps" & Natural'Image (Result.Accepted));
         R.Describe (Result, Note, Last);
         if Last >= 1 then
            Put_Line ("note " & Note (1 .. Last));
         end if;
         for S in 1 .. Result.Count loop
            R.Step_Line (Result, S, Line, Last);
            if Last >= 1 then
               Put_Line ("state " & Line (1 .. Last));
            end if;
         end loop;
         IO.New_Line;
      end loop;
   end Show_Replay;

   procedure Refuse (Reason : String) is
   begin
      Put_Line (Reason);
      Put_Line ("no request was sent");
      Ada.Command_Line.Set_Exit_Status (2);
   end Refuse;

   type Arg_Array is
     array (Positive range <>) of GNAT.OS_Lib.String_Access;

   procedure Free_Args (Args : in out Arg_Array) is
   begin
      for A of Args loop
         GNAT.OS_Lib.Free (A);
      end loop;
   end Free_Args;

   function Run
     (Program : String;
      Args    : in out Arg_Array) return Integer
   is
      List : GNAT.OS_Lib.Argument_List (Args'Range);
      Code : Integer;
   begin
      for I in Args'Range loop
         List (I) := Args (I);
      end loop;
      Code := GNAT.OS_Lib.Spawn (Program, List);
      for I in Args'Range loop
         Args (I) := List (I);
      end loop;
      return Code;
   end Run;

   procedure Delete (Name : String) is
   begin
      if Ada.Directories.Exists (Name) then
         Ada.Directories.Delete_File (Name);
      end if;
   end Delete;

   procedure Write_Text (Name : String; Text : String; OK : out Boolean) is
      File : IO.File_Type;
   begin
      begin
         IO.Create (File, IO.Out_File, Name);
         IO.Put (File, Text);
         IO.Close (File);
         OK := True;
      exception
         when others =>
            if IO.Is_Open (File) then
               IO.Close (File);
            end if;
            OK := False;
      end;
   end Write_Text;

   procedure Read_Text
     (Name : String;
      Buf  : out String;
      Last : out Natural;
      OK   : out Boolean)
   is
      File : Ada.Streams.Stream_IO.File_Type;
      Item : Ada.Streams.Stream_Element_Array (1 .. 1);
      Got  : Ada.Streams.Stream_Element_Offset;
   begin
      Last := 0;
      OK := False;
      begin
         Ada.Streams.Stream_IO.Open
           (File, Ada.Streams.Stream_IO.In_File, Name);
         while Last < Buf'Last loop
            Ada.Streams.Stream_IO.Read (File, Item, Got);
            exit when Got < 1;
            Last := Last + 1;
            Buf (Last) := Character'Val (Natural (Item (1)));
         end loop;
         Ada.Streams.Stream_IO.Close (File);
         OK := True;
      exception
         when others =>
            if Ada.Streams.Stream_IO.Is_Open (File) then
               Ada.Streams.Stream_IO.Close (File);
            end if;
            OK := False;
      end;
   end Read_Text;

   procedure Print_State (Item : R.State; Tail : String) is
      Line : String (1 .. R.Max_Line);
      Last : Natural := 0;
      View : R.Replay;
   begin
      View.Count := 1;
      View.Item (1) :=
        (Parsed => True,
         Fib_Index => Item.Fib_Index,
         Minus_One => Item.Minus_One,
         Curr_Value => Item.Curr_Value,
         Mark => 0);
      if Tail = "base" then
         View.Item (1).Mark := 1;
      elsif Tail = "halt" then
         View.Item (1).Mark := 2;
      end if;
      R.Step_Line (View, 1, Line, Last);
      if Last >= 1 then
         Put_Line ("state " & Line (1 .. Last));
      end if;
   end Print_State;

   procedure Ask (Index : Natural) is
      Current : R.State;
      Open_OK : Boolean;
      URL     : constant String := Env_Or_Empty ("RECURSE_LLM_URL");
      Key     : constant String := Env_Or_Empty ("RECURSE_LLM_KEY");
      Model   : constant String := Env_Or_Empty ("RECURSE_LLM_MODEL");
      Curl    : constant String :=
        (if Env.Exists ("RECURSE_LLM_CURL")
           and then Trimmed (Env.Value ("RECURSE_LLM_CURL"))'Length > 0
         then Trimmed (Env.Value ("RECURSE_LLM_CURL"))
         else "curl");
      Calls   : Natural := 0;
      Stem    : constant String := "/tmp/aaa-rec-" & Pid_Text;
   begin
      R.Make_Opening (Index, Current, Open_OK);
      if not Open_OK then
         Refuse ("index is above the maximum");
         return;
      end if;
      Put_Line ("ask" & Natural'Image (Index));
      if Current.Fib_Index = 0 then
         Print_State (Current, "base");
      else
         Print_State (Current, "ok");
      end if;
      if Current.Fib_Index = 0 then
         Put_Line ("stop reached-base");
         Put_Line ("answer 0");
         Put_Line ("steps 0");
         Put_Line ("no request was sent");
         return;
      end if;
      if Key'Length = 0 then
         Refuse ("RECURSE_LLM_KEY is not set");
         return;
      end if;
      if not Single_Line (Key) then
         Refuse ("RECURSE_LLM_KEY is not a single line");
         return;
      end if;
      if not Web_URL (URL) then
         Refuse ("RECURSE_LLM_URL is not an http address");
         return;
      end if;
      if not Model_OK (Model) then
         Refuse ("RECURSE_LLM_MODEL is not set");
         return;
      end if;

      loop
         declare
            Prompt : String (1 .. R.Max_Prompt);
            PLast  : Natural;
            POK    : Boolean;
            Payload : String (1 .. R.Max_JSON);
            BLast  : Natural;
            BOK    : Boolean;
            Hdr    : constant String := Stem & ".hdr";
            Req    : constant String := Stem & ".json";
            Outp   : constant String := Stem & ".out";
            Reply  : String (1 .. 4_000);
            RLast  : Natural;
            ROK    : Boolean;
            Text   : String (1 .. 2_000);
            TLast  : Natural;
            TOK    : Boolean;
            Next   : R.State;
            Parsed : Boolean;
            Kind   : R.Check_Name;
            Header : constant String :=
              "Authorization: Bearer " & Key & LF
              & "Content-Type: application/json" & LF;
            Wrote  : Boolean;
            Mode   : Arg_Array (1 .. 2);
            Call   : Arg_Array (1 .. 12);
            Code   : Integer;
         begin
            if Calls >= R.Max_Index then
               Put_Line ("stop too-long");
               Put_Line ("answer 0");
               Put_Line ("steps" & Natural'Image (Calls));
               Ada.Command_Line.Set_Exit_Status (1);
               return;
            end if;
            R.Prompt_For (Current, Prompt, PLast, POK);
            if not POK then
               Refuse ("the prompt did not fit");
               return;
            end if;
            R.Request_JSON
              (Model, Prompt (1 .. PLast), Payload, BLast, BOK);
            if not BOK then
               Refuse ("the request body did not fit");
               return;
            end if;
            Write_Text (Hdr, Header, Wrote);
            if not Wrote then
               Delete (Hdr);
               Refuse ("the key file could not be written");
               return;
            end if;
            Mode (1) := new String'("600");
            Mode (2) := new String'(Hdr);
            Code := Run ("/bin/chmod", Mode);
            Free_Args (Mode);
            if Code /= 0 then
               Delete (Hdr);
               Refuse ("the key file could not be locked down");
               return;
            end if;
            Write_Text (Req, Payload (1 .. BLast), Wrote);
            if not Wrote then
               Delete (Hdr);
               Delete (Req);
               Refuse ("the request file could not be written");
               return;
            end if;
            Call (1) := new String'("--silent");
            Call (2) := new String'("--show-error");
            Call (3) := new String'("--max-time");
            Call (4) := new String'("30");
            Call (5) := new String'("--request");
            Call (6) := new String'("POST");
            Call (7) := new String'("--header");
            Call (8) := new String'("@" & Hdr);
            Call (9) := new String'("--data-binary");
            Call (10) := new String'("@" & Req);
            Call (11) := new String'("--output");
            Call (12) := new String'(Outp);
            --  The address is a separate argument, added below,
            --  so it is not passed through a shell.
            declare
               Full : Arg_Array (1 .. 13);
            begin
               for I in Call'Range loop
                  Full (I) := Call (I);
               end loop;
               Full (13) := new String'(URL);
               Code := Run (Curl, Full);
               for I in Call'Range loop
                  Call (I) := Full (I);
               end loop;
               GNAT.OS_Lib.Free (Full (13));
            end;
            Free_Args (Call);
            Delete (Hdr);
            Delete (Req);
            Calls := Calls + 1;
            Put_Line ("request" & Natural'Image (Calls));
            if Code /= 0 then
               Delete (Outp);
               Put_Line ("the request failed");
               Ada.Command_Line.Set_Exit_Status (3);
               return;
            end if;
            Read_Text (Outp, Reply, RLast, ROK);
            Delete (Outp);
            if not ROK or else RLast < 1 then
               Put_Line ("state unreadable  halt");
               Put_Line ("stop bad-parse");
               Put_Line ("answer 0");
               Put_Line ("steps" & Natural'Image (Calls - 1));
               Ada.Command_Line.Set_Exit_Status (1);
               return;
            end if;
            R.Assistant_Text (Reply (1 .. RLast), Text, TLast, TOK);
            if not TOK then
               Put_Line ("state unreadable  halt");
               Put_Line ("stop bad-parse");
               Put_Line ("answer 0");
               Put_Line ("steps" & Natural'Image (Calls - 1));
               Ada.Command_Line.Set_Exit_Status (1);
               return;
            end if;
            R.Parse_State (Text (1 .. TLast), Next, Parsed);
            if not Parsed then
               Put_Line ("state unreadable  halt");
               Put_Line ("stop bad-parse");
               Put_Line ("answer 0");
               Put_Line ("steps" & Natural'Image (Calls - 1));
               Ada.Command_Line.Set_Exit_Status (1);
               return;
            end if;
            R.Check_Step (Current, Next, Kind);
            if Kind = R.Accepted then
               Print_State (Next, "ok");
               Current := Next;
            elsif Kind = R.Reached_Base then
               Print_State (Next, "base");
               Put_Line ("stop reached-base");
               Put_Line ("answer" & Natural'Image (Next.Minus_One));
               Put_Line ("steps" & Natural'Image (Calls));
               return;
            else
               Print_State (Next, "halt");
               IO.Put ("stop ");
               Show_Word (Kind);
               IO.New_Line;
               Put_Line ("answer 0");
               Put_Line ("steps" & Natural'Image (Calls - 1));
               Ada.Command_Line.Set_Exit_Status (1);
               return;
            end if;
         end;
      end loop;
   end Ask;

   procedure Print_Prompt (Index : Natural) is
      Item : R.State;
      OK   : Boolean;
      Text : String (1 .. R.Max_Prompt);
      Last : Natural;
   begin
      R.Make_Opening (Index, Item, OK);
      if not OK then
         Refuse ("index is above the maximum");
         return;
      end if;
      R.Prompt_For (Item, Text, Last, OK);
      if not OK then
         Refuse ("the prompt did not fit");
         return;
      end if;
      IO.Put (Text (1 .. Last));
   end Print_Prompt;

begin
   if Ada.Command_Line.Argument_Count = 0 then
      Show_Replay;
      return;
   end if;
   if Ada.Command_Line.Argument_Count = 2 then
      declare
         Flag  : constant String := Ada.Command_Line.Argument (1);
         Index : Natural;
         OK    : Boolean;
      begin
         Parse_Index (Ada.Command_Line.Argument (2), Index, OK);
         if not OK then
            Refuse ("usage: recurse_cli [--print-prompt N | --ask N]");
            return;
         end if;
         if Flag = "--print-prompt" then
            Print_Prompt (Index);
            return;
         elsif Flag = "--ask" then
            Ask (Index);
            return;
         end if;
      end;
   end if;
   Refuse ("usage: recurse_cli [--print-prompt N | --ask N]");
end Recurse_Cli;
