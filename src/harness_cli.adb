with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with GNAT.OS_Lib;
with AI_Amplifier.Harness;
with AI_Amplifier.Recurse;
with AI_Amplifier.Traces;

--  Native only. build.sh does not compile this into the page.
--  With no arguments it prints the harness table. It does
--  not open a socket. --ask NAME runs the checked harness
--  with a live model in place of the Ada solver, and only
--  when HARNESS_LLM_URL, HARNESS_LLM_KEY, and
--  HARNESS_LLM_MODEL are set. The key is written to a mode
--  0600 file for curl and is not placed on the command line.
--  The page does not run this program.
procedure Harness_Cli
  with SPARK_Mode => Off
is
   package H renames AI_Amplifier.Harness;
   package R renames AI_Amplifier.Recurse;
   package T renames AI_Amplifier.Traces;
   package Env renames Ada.Environment_Variables;
   package IO renames Ada.Text_IO;
   use type Ada.Streams.Stream_Element_Offset;
   use type GNAT.OS_Lib.String_Access;

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

   --  Spawn does not search PATH. A bare name such as curl is
   --  turned into the executable Locate_Exec_On_Path finds.
   --  A path that already contains a slash is left as it is.
   function Resolved_Program (Name : String) return String is
      Found : GNAT.OS_Lib.String_Access;
   begin
      if Ada.Strings.Fixed.Index (Name, "/") = 0 then
         Found := GNAT.OS_Lib.Locate_Exec_On_Path (Name);
         if Found /= null then
            declare
               Text : constant String := Found.all;
            begin
               GNAT.OS_Lib.Free (Found);
               return Text;
            end;
         end if;
      end if;
      return Name;
   end Resolved_Program;

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

   procedure Put_Buf (Buf : String; Last : Natural) is
   begin
      if Last >= 1 then
         IO.Put_Line (Buf (Buf'First .. Buf'First + Last - 1));
      end if;
   end Put_Buf;

   procedure Show_Table is
      Bank : H.Table;
      Line : String (1 .. H.Max_Line);
      Last : Natural;
      One  : H.Run;
   begin
      H.Stat_Line (Line, Last);
      Put_Buf (Line, Last);
      Put_Line ("harness  solve rate  steps  wrong accepted");
      H.Run_Table (Bank);
      for Which in H.Harness_Name loop
         H.Cell (Which, Bank, 1, Line, Last);
         IO.Put (Line (1 .. Last));
         IO.Put ("  ");
         H.Cell (Which, Bank, 2, Line, Last);
         IO.Put (Line (1 .. Last));
         IO.Put ("  ");
         H.Cell (Which, Bank, 3, Line, Last);
         IO.Put (Line (1 .. Last));
         IO.Put ("  ");
         H.Cell (Which, Bank, 4, Line, Last);
         IO.Put_Line (Line (1 .. Last));
      end loop;
      IO.New_Line;
      H.Task_Name (H.Showcase, Line, Last);
      Put_Line ("task " & Line (1 .. Last));
      for Which in H.Harness_Name loop
         H.Run_One (Which, H.Showcase, One);
         H.Harness_Word (Which, Line, Last);
         IO.Put_Line (Line (1 .. Last));
         H.Result_Line (One, Line, Last);
         Put_Buf (Line, Last);
         for N in 1 .. One.Calls loop
            H.Log_Line (One, N, Line, Last);
            Put_Buf (Line, Last);
         end loop;
      end loop;
   end Show_Table;

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

   function Find_Task (Name : String) return Natural is
      Text : String (1 .. H.Max_Name);
      Last : Natural;
   begin
      for Index in 1 .. H.Task_Count loop
         H.Task_Name (Index, Text, Last);
         if Last >= 1 and then Text (1 .. Last) = Name then
            return Index;
         end if;
      end loop;
      return 0;
   end Find_Task;

   procedure Print_Prompt (Index : Natural) is
      Text : String (1 .. 4_000);
      Last : Natural;
      OK   : Boolean;
      Fib   : Natural := 0;
      Minus : constant Natural := 0;
      Curr  : constant Natural := 1;
   begin
      if Index = 1 then
         Fib := 1;
      elsif Index = 2 then
         Fib := 3;
      elsif Index = 3 then
         Fib := 4;
      elsif Index = 4 then
         Fib := 6;
      end if;
      H.Prompt_For
        (Index, Fib, Minus, Curr, "", Text, Last, OK);
      if not OK then
         Refuse ("the prompt did not fit");
         return;
      end if;
      IO.Put (Text (1 .. Last));
   end Print_Prompt;

   procedure Ask (Index : Natural) is
      URL : constant String := Env_Or_Empty ("HARNESS_LLM_URL");
      Key : constant String := Env_Or_Empty ("HARNESS_LLM_KEY");
      Model : constant String := Env_Or_Empty ("HARNESS_LLM_MODEL");
      Curl : constant String :=
        Resolved_Program
          (if Env.Exists ("HARNESS_LLM_CURL")
             and then Trimmed (Env.Value ("HARNESS_LLM_CURL"))'Length > 0
           then Trimmed (Env.Value ("HARNESS_LLM_CURL"))
           else "curl");
      Name : String (1 .. H.Max_Name);
      NLast : Natural;
      Fib : Natural := 0;
      Minus : Natural := 0;
      Curr : Natural := 1;
      Attempt : Positive := 1;
      Note : String (1 .. H.Max_Note) := (others => ' ');
      Note_Len : Natural := 0;
      Calls : Natural := 0;
      Stem : constant String := "/tmp/aaa-hn-" & Pid_Text;
   begin
      H.Task_Name (Index, Name, NLast);
      Put_Line ("ask " & Name (1 .. NLast));
      Put_Line ("harness checked");
      Put_Line ("live model");
      if H.Is_Fib (Index) then
         if Index = 1 then
            Fib := 1;
         elsif Index = 2 then
            Fib := 3;
         elsif Index = 3 then
            Fib := 4;
         else
            Fib := 6;
         end if;
      end if;
      if Key'Length = 0 then
         Refuse ("HARNESS_LLM_KEY is not set");
         return;
      end if;
      if not Single_Line (Key) then
         Refuse ("HARNESS_LLM_KEY is not a single line");
         return;
      end if;
      if not Web_URL (URL) then
         Refuse ("HARNESS_LLM_URL is not an http address");
         return;
      end if;
      if not Model_OK (Model) then
         Refuse ("HARNESS_LLM_MODEL is not set");
         return;
      end if;
      while Calls < H.Checked_Cap and then Attempt <= H.Attempt_Cap loop
         declare
            Prompt : String (1 .. 4_000);
            PLast : Natural;
            POK : Boolean;
            Payload : String (1 .. T.Max_JSON);
            BLast : Natural;
            BOK : Boolean;
            Hdr : constant String := Stem & ".hdr";
            Req : constant String := Stem & ".json";
            Outp : constant String := Stem & ".out";
            Reply : String (1 .. 8_000);
            RLast : Natural;
            ROK : Boolean;
            Step : String (1 .. 4_000);
            SLast : Natural;
            SOK : Boolean;
            Word : String (1 .. H.Max_Note);
            WLast : Natural;
            Keep : Boolean;
            Header : constant String :=
              "Authorization: Bearer " & Key & LF
              & "Content-Type: application/json" & LF;
            Wrote : Boolean;
            Mode : Arg_Array (1 .. 2);
            Call : Arg_Array (1 .. 12);
            Code : Integer;
            Sent : constant String :=
              (if Note_Len = 0 then "" else Note (1 .. Note_Len));
         begin
            H.Prompt_For
              (Index, Fib, Minus, Curr, Sent, Prompt, PLast, POK);
            if not POK then
               Refuse ("the prompt did not fit");
               return;
            end if;
            T.Request_JSON
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
            IO.Put ("call");
            IO.Put (Natural'Image (Calls));
            if Code /= 0 then
               Delete (Outp);
               IO.New_Line;
               Put_Line ("the request failed");
               Ada.Command_Line.Set_Exit_Status (3);
               return;
            end if;
            Read_Text (Outp, Reply, RLast, ROK);
            Delete (Outp);
            if not ROK or else RLast < 1 then
               IO.Put_Line ("  rejected  bad-parse");
               Attempt := Attempt + 1;
               Note (1 .. 9) := "bad-parse";
               Note_Len := 9;
            else
               T.Assistant_Text
                 (Reply (1 .. RLast), Step, SLast, SOK);
               if not SOK then
                  IO.Put_Line ("  rejected  bad-parse");
                  Attempt := Attempt + 1;
                  Note (1 .. 9) := "bad-parse";
                  Note_Len := 9;
               else
                  H.Checker_Accepts
                    (Index, Fib, Minus, Curr,
                     Step (1 .. SLast), Keep, Word, WLast);
                  if Keep then
                     IO.Put_Line ("  accepted");
                     if H.Is_Fib (Index) then
                        declare
                           Next : R.State;
                           Parsed : Boolean;
                        begin
                           R.Parse_State
                             (Step (1 .. SLast), Next, Parsed);
                           if not Parsed or else Next.Fib_Index = 0
                           then
                              Put_Line ("solved");
                              return;
                           end if;
                           Fib := Next.Fib_Index;
                           Minus := Next.Minus_One;
                           Curr := Next.Curr_Value;
                           Attempt := 1;
                           Note_Len := 0;
                        end;
                     else
                        Put_Line ("solved");
                        return;
                     end if;
                  else
                     IO.Put ("  rejected  ");
                     if WLast > 0 then
                        IO.Put_Line (Word (1 .. WLast));
                        Note_Len := WLast;
                        Note (1 .. WLast) := Word (1 .. WLast);
                     else
                        IO.New_Line;
                        Note_Len := 0;
                     end if;
                     Attempt := Attempt + 1;
                  end if;
               end if;
            end if;
         end;
      end loop;
      Put_Line ("not solved");
      Ada.Command_Line.Set_Exit_Status (1);
   end Ask;

begin
   if Ada.Command_Line.Argument_Count = 0 then
      Show_Table;
      return;
   end if;
   if Ada.Command_Line.Argument_Count = 2 then
      declare
         Flag : constant String := Ada.Command_Line.Argument (1);
         Name : constant String := Ada.Command_Line.Argument (2);
         Index : constant Natural := Find_Task (Name);
      begin
         if Index = 0 then
            Refuse ("usage: harness_cli [--print-prompt NAME | --ask NAME]");
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
   Refuse ("usage: harness_cli [--print-prompt NAME | --ask NAME]");
end Harness_Cli;
