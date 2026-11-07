with Ada.Command_Line;
with Ada.Text_IO;
with AI_Amplifier.Audit;

--  Native only. build.sh does not compile this into the page.
--  With no arguments it audits the built-in benchmark. With one
--  argument it audits that task file. The report is the same
--  lines the page shows. A score that still includes a flagged
--  task is printed and marked not accepted.
procedure Audit_Cli
  with SPARK_Mode => Off
is
   package A renames AI_Amplifier.Audit;
   package IO renames Ada.Text_IO;

   Max_File : constant := 16_000;

   procedure Put_Buf (Buf : String; Last : Natural) is
   begin
      if Last >= 1 then
         IO.Put_Line (Buf (Buf'First .. Buf'First + Last - 1));
      end if;
   end Put_Buf;

   procedure Report (Text : String) is
      Bank : A.Set;
      OK   : Boolean;
      Note : String (1 .. A.Max_Note);
      NLast : Natural;
      Line : String (1 .. A.Max_Line);
      Last : Natural;
   begin
      A.Load (Text, Bank, OK, Note, NLast);
      if not OK then
         IO.Put_Line ("The task file did not load.");
         Put_Buf (Note, NLast);
         Ada.Command_Line.Set_Exit_Status (1);
         return;
      end if;
      A.Examine (Bank);
      for I in 1 .. Bank.Count loop
         A.Line_For (Bank, I, Line, Last);
         Put_Buf (Line, Last);
      end loop;
      A.Score_Line (Bank, False, Line, Last);
      Put_Buf (Line, Last);
      A.Score_Line (Bank, True, Line, Last);
      Put_Buf (Line, Last);
   end Report;

   function Read_File (Name : String; Text : out String; Last : out Natural)
     return Boolean
   is
      File : IO.File_Type;
   begin
      Last := 0;
      Text := (others => ' ');
      begin
         IO.Open (File, IO.In_File, Name);
      exception
         when IO.Name_Error | IO.Use_Error | IO.Status_Error =>
            return False;
      end;
      begin
         while not IO.End_Of_File (File) loop
            declare
               Line : constant String := IO.Get_Line (File);
            begin
               if Last > 0 then
                  if Last >= Text'Last then
                     IO.Close (File);
                     return False;
                  end if;
                  Last := Last + 1;
                  Text (Last) := Character'Val (10);
               end if;
               if Line'Length > Text'Last - Last then
                  IO.Close (File);
                  return False;
               end if;
               Text (Last + 1 .. Last + Line'Length) := Line;
               Last := Last + Line'Length;
            end;
         end loop;
         IO.Close (File);
      exception
         when IO.End_Error | IO.Device_Error
            | IO.Status_Error | IO.Use_Error =>
            if IO.Is_Open (File) then
               IO.Close (File);
            end if;
            return False;
      end;
      return True;
   end Read_File;

begin
   if Ada.Command_Line.Argument_Count = 0 then
      declare
         Bank : A.Set;
         OK   : Boolean;
         Note : String (1 .. A.Max_Note);
         NLast : Natural;
         Line : String (1 .. A.Max_Line);
         Last : Natural;
      begin
         A.Load_Benchmark (Bank, OK, Note, NLast);
         if not OK then
            IO.Put_Line ("The task file did not load.");
            Put_Buf (Note, NLast);
            Ada.Command_Line.Set_Exit_Status (1);
            return;
         end if;
         A.Examine (Bank);
         for I in 1 .. Bank.Count loop
            A.Line_For (Bank, I, Line, Last);
            Put_Buf (Line, Last);
         end loop;
         A.Score_Line (Bank, False, Line, Last);
         Put_Buf (Line, Last);
         A.Score_Line (Bank, True, Line, Last);
         Put_Buf (Line, Last);
      end;
   elsif Ada.Command_Line.Argument_Count = 1 then
      declare
         Buf  : String (1 .. Max_File);
         Last : Natural;
      begin
         if not Read_File (Ada.Command_Line.Argument (1), Buf, Last) then
            IO.Put_Line ("The task file did not load.");
            Ada.Command_Line.Set_Exit_Status (1);
            return;
         end if;
         if Last = 0 then
            Report ("");
         else
            Report (Buf (1 .. Last));
         end if;
      end;
   else
      IO.Put_Line ("usage: audit_cli [task-file]");
      Ada.Command_Line.Set_Exit_Status (1);
   end if;
end Audit_Cli;
