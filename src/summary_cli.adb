with Ada.Command_Line;
with Ada.Text_IO;
with AI_Amplifier.Summary;
with AI_Amplifier.Summary_Rules;

--  Native only. build.sh does not compile this into the page.
--  It prints the eight summaries beside the checked steps.
--  A summary that did not load exits 1.
procedure Summary_Cli
  with SPARK_Mode => Off
is
   package U renames AI_Amplifier.Summary;
   package IO renames Ada.Text_IO;
   use type AI_Amplifier.Summary_Rules.Step_Mark;

   procedure Put_Buf (Buf : String; Last : Natural) is
   begin
      if Last >= 1 then
         IO.Put_Line (Buf (Buf'First .. Buf'First + Last - 1));
      end if;
   end Put_Buf;

   procedure Put_One (Index : Positive) is
      Buf  : String (1 .. U.Max_Line);
      Last : Natural;
   begin
      U.Problem_Name (Index, Buf, Last);
      IO.Put ("problem ");
      Put_Buf (Buf, Last);
      U.Flag_Word (Index, Buf, Last);
      IO.Put ("flag ");
      Put_Buf (Buf, Last);
      IO.Put_Line ("summary");
      for J in 1 .. U.Sentence_Count (Index) loop
         if U.Sentence_Mark (Index, J) = 1 then
            IO.Put ("* ");
         else
            IO.Put ("  ");
         end if;
         U.Sentence (Index, J, Buf, Last);
         Put_Buf (Buf, Last);
      end loop;
      IO.Put_Line ("steps");
      for J in 1 .. U.Step_Count (Index) loop
         if U.Step_Kind (Index, J) = AI_Amplifier.Summary_Rules.Wrong then
            IO.Put ("! ");
         elsif U.Step_Kind (Index, J) = AI_Amplifier.Summary_Rules.Unchecked
         then
            IO.Put ("? ");
         else
            IO.Put ("  ");
         end if;
         U.Step_Line (Index, J, Buf, Last);
         Put_Buf (Buf, Last);
      end loop;
   end Put_One;
begin
   U.Load;
   if not U.Ready then
      IO.Put_Line (IO.Standard_Error, "summary did not load");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;
   IO.Put_Line ("name flag");
   for I in 1 .. U.Problem_Count loop
      declare
         Name : String (1 .. U.Max_Name);
         Flag : String (1 .. U.Max_Line);
         NLast, FLast : Natural;
      begin
         U.Problem_Name (I, Name, NLast);
         U.Flag_Word (I, Flag, FLast);
         if NLast >= 1 then
            IO.Put (Name (1 .. NLast));
         end if;
         IO.Put (" ");
         if FLast >= 1 then
            IO.Put (Flag (1 .. FLast));
         end if;
         IO.New_Line;
      end;
   end loop;
   declare
      Stat : String (1 .. U.Max_Line);
      Last : Natural;
   begin
      U.Stat_Line (Stat, Last);
      Put_Buf (Stat, Last);
   end;
   for I in 1 .. U.Problem_Count loop
      IO.New_Line;
      Put_One (I);
   end loop;
end Summary_Cli;
