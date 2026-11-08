with Ada.Command_Line;
with Ada.Text_IO;
with AI_Amplifier.Steps;

--  Native only. build.sh does not compile this into the page.
--  With no arguments it prints the twelve solutions, the same
--  words the page shows. With one argument it grades that
--  solution file. A solution whose steps fail exits 1. The
--  answer-only grade is printed either way.
procedure Steps_Cli
  with SPARK_Mode => Off
is
   package S renames AI_Amplifier.Steps;
   package IO renames Ada.Text_IO;
   use type S.Mark;

   procedure Put_Buf (Buf : String; Last : Natural) is
   begin
      if Last >= 1 then
         IO.Put_Line (Buf (Buf'First .. Buf'First + Last - 1));
      end if;
   end Put_Buf;

   procedure Put_Table is
      Line : String (1 .. S.Max_Line);
      Last : Natural;
      Item : S.Report;
   begin
      S.Header_Line (Line, Last);
      Put_Buf (Line, Last);
      for I in 1 .. S.Solution_Count loop
         S.Grade_Built_In (I, Item);
         S.Line_For (Item, Line, Last);
         Put_Buf (Line, Last);
      end loop;
      S.Stat_Line (Line, Last);
      Put_Buf (Line, Last);
   end Put_Table;

   procedure Put_Report (Item : S.Report) is
      Word : String (1 .. S.Max_Note);
      Last : Natural;
   begin
      IO.Put ("answer ");
      S.Mark_Word (Item.Answer_Grade, Word, Last);
      Put_Buf (Word, Last);
      IO.Put ("steps ");
      S.Mark_Word (Item.Step_Grade, Word, Last);
      Put_Buf (Word, Last);
      S.Rule_Word (Item.Rule, Word, Last);
      IO.Put ("rule ");
      Put_Buf (Word, Last);
      for I in 1 .. Item.Count loop
         declare
            Img : constant String := Natural'Image (I);
         begin
            if Img'Length > 0 and then Img (Img'First) = ' ' then
               IO.Put (Img (Img'First + 1 .. Img'Last));
            else
               IO.Put (Img);
            end if;
         end;
         IO.Put ("  ");
         if Item.Item (I).Last >= 1 then
            IO.Put
              (Item.Item (I).Text (1 .. Item.Item (I).Last));
         end if;
         if I = Item.Bad_At then
            IO.Put ("  ");
            S.Rule_Word (Item.Item (I).Rule, Word, Last);
            IO.Put (Word (1 .. Last));
         end if;
         IO.New_Line;
      end loop;
   end Put_Report;

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
      Put_Table;
   elsif Ada.Command_Line.Argument_Count = 1 then
      declare
         Buf  : String (1 .. 8_000);
         Last : Natural;
         Item : S.Report;
      begin
         if not Read_File (Ada.Command_Line.Argument (1), Buf, Last) then
            IO.Put_Line ("The solution file did not load.");
            Ada.Command_Line.Set_Exit_Status (1);
            return;
         end if;
         if Last = 0 then
            S.Grade ("", Item);
         else
            S.Grade (Buf (1 .. Last), Item);
         end if;
         Put_Report (Item);
         if Item.Step_Grade /= S.Pass then
            Ada.Command_Line.Set_Exit_Status (1);
         end if;
      end;
   else
      IO.Put_Line ("usage: steps_cli [solution-file]");
      Ada.Command_Line.Set_Exit_Status (1);
   end if;
end Steps_Cli;
