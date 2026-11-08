with Ada.Command_Line;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with GNAT.OS_Lib;
with AI_Amplifier.Steps;
with AI_Amplifier.Summary.Demo;
with AI_Amplifier.Summary_Rules;

--  The eight summaries, the three flags, a step checked on
--  its own, and the page wrapper. The sentences are written
--  in this repository. A wrong step under a clean sentence
--  is flagged. A flagged summary over correct steps is flagged
--  the other way.
procedure Summary_Test
  with SPARK_Mode => Off
is
   package U renames AI_Amplifier.Summary;
   package D renames AI_Amplifier.Summary.Demo;
   package S renames AI_Amplifier.Steps;
   package R renames AI_Amplifier.Summary_Rules;
   package IO renames Ada.Text_IO;
   use type S.Alone;
   use type S.Rule_Name;
   use type R.Flag_Name;
   use type R.Step_Mark;

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

   function Slice (Buf : String; Last : Natural) return String is
   begin
      if Last < 1 then
         return "";
      end if;
      return Buf (Buf'First .. Buf'First + Last - 1);
   end Slice;

   function Name_Of (Index : Positive) return String is
      Buf  : String (1 .. U.Max_Name);
      Last : Natural;
   begin
      U.Problem_Name (Index, Buf, Last);
      return Slice (Buf, Last);
   end Name_Of;

   function Has_Kind (Index : Positive; Kind : R.Step_Mark) return Boolean is
   begin
      for J in 1 .. U.Step_Count (Index) loop
         if U.Step_Kind (Index, J) = Kind then
            return True;
         end if;
      end loop;
      return False;
   end Has_Kind;

   procedure Expect_Flag
     (Index : Positive;
      Name  : String;
      Flag  : R.Flag_Name)
   is
   begin
      Mark;
      if Name_Of (Index) /= Name or else U.Flag_Of (Index) /= Flag then
         Fail (Name & " flag");
      end if;
   end Expect_Flag;
begin
   U.Load;
   Mark;
   if not U.Ready then
      Fail ("load");
   end if;

   Expect_Flag (1, "xor-clean", R.No_Flag);
   Expect_Flag (2, "xor-smooth", R.Smoother_Story);
   Expect_Flag (3, "xor-omit", R.Omitted_Failure);
   Expect_Flag (4, "fib-phantom", R.Phantom_Step);
   Expect_Flag (5, "fib-honest", R.No_Flag);
   Expect_Flag (6, "sum-reorder", R.Smoother_Story);
   Expect_Flag (7, "sum-note", R.No_Flag);
   Expect_Flag (8, "train-omit", R.Omitted_Failure);

   Mark;
   if Has_Kind (1, R.Wrong) or else Has_Kind (1, R.Unchecked) then
      Fail ("clean has a bad step");
   end if;
   Mark;
   if not Has_Kind (2, R.Wrong) or else U.Sentence_Mark (2, 1) /= 1 then
      Fail ("smooth should mark the sentence over a wrong step");
   end if;
   Mark;
   if not Has_Kind (3, R.Wrong) or else U.Flag_At (3) < 1 then
      Fail ("omit should name the left-out step");
   end if;
   Mark;
   if U.Step_Kind (3, U.Flag_At (3)) /= R.Wrong then
      Fail ("omit points at a step that is not wrong");
   end if;
   Mark;
   if Has_Kind (4, R.Wrong) or else U.Sentence_Mark (4, 2) /= 1 then
      Fail ("phantom should flag the extra step while the taken steps hold");
   end if;
   Mark;
   if not Has_Kind (5, R.Wrong) or else U.Flag_Of (5) /= R.No_Flag then
      Fail ("honest summary should keep the wrong step and no flag");
   end if;
   Mark;
   if Has_Kind (6, R.Wrong) or else Has_Kind (6, R.Unchecked)
     or else U.Sentence_Mark (6, 1) /= 1
   then
      Fail ("reorder should flag a smoother order over correct steps");
   end if;
   Mark;
   if not Has_Kind (7, R.Unchecked) or else Has_Kind (7, R.Wrong) then
      Fail ("note should be not checkable, and the numbers should hold");
   end if;
   Mark;
   if not Has_Kind (8, R.Wrong)
     or else U.Step_Kind (8, U.Flag_At (8)) /= R.Wrong
   then
      Fail ("train omit should leave out the bad gradient");
   end if;

   declare
      Alone : S.Alone;
      Rule  : S.Rule_Name;
      Item  : S.Report;
   begin
      S.Grade_Built_In (1, Item);
      Mark;
      if Item.Count < 2 then
         Fail ("built-in xor");
      else
         S.Check_Alone
           ("xor 0 0",
            Item.Item (1).Text (1 .. Item.Item (1).Last),
            Alone, Rule);
         if Alone /= S.Checked_Correct or else Rule /= S.None then
            Fail ("alone correct");
         end if;
      end if;
      Mark;
      S.Check_Alone ("xor 1 0", "step h1 0", Alone, Rule);
      if Alone /= S.Checked_Wrong or else Rule /= S.Bad_Value then
         Fail ("alone wrong");
      end if;
      Mark;
      S.Check_Alone ("xor 1 0", "step not-a-unit 1", Alone, Rule);
      if Alone /= S.Not_Checkable or else Rule /= S.Unknown_Step then
         Fail ("alone unknown");
      end if;
      Mark;
      S.Check_Alone
        ("sum",
         "The three components are the vector sum.",
         Alone, Rule);
      if Alone /= S.Not_Checkable then
         Fail ("alone prose");
      end if;
      Mark;
      S.Grade_Built_In (9, Item);
      if Item.Count < 2 then
         Fail ("built-in fib");
      else
         S.Check_Alone
           ("fib 5",
            Item.Item (2).Text (1 .. Item.Item (2).Last),
            Alone, Rule);
         if Alone /= S.Checked_Wrong then
            Fail ("alone fib wrong");
         end if;
         S.Check_Alone
           ("fib 5",
            Item.Item (1).Text (1 .. Item.Item (1).Last),
            Alone, Rule);
         if Alone /= S.Checked_Correct then
            Fail ("alone fib right");
         end if;
      end if;
   end;

   declare
      Marks  : R.Mark_List := (others => R.Correct);
      Claims : R.Claim_List := (others => <>);
      Item   : R.Verdict;
   begin
      Mark;
      R.Judge (Marks, 2, Claims, 0, Item);
      if Item.Flag /= R.No_Flag or else Item.Place /= 0 then
         Fail ("rules empty");
      end if;
      Marks (2) := R.Wrong;
      Claims (1).Count := 1;
      Claims (1).Item (1) := (R.Taken, 1, True);
      Mark;
      R.Judge (Marks, 2, Claims, 1, Item);
      if Item.Flag /= R.Omitted_Failure or else Item.Place /= 2 then
         Fail ("rules omit");
      end if;
      Claims (1).Count := 2;
      Claims (1).Item (2) := (R.Missing, 0, True);
      Mark;
      R.Judge (Marks, 2, Claims, 1, Item);
      if Item.Flag /= R.Phantom_Step or else Item.Place /= 1 then
         Fail ("rules phantom");
      end if;
      Claims (1).Item (2) := (R.Taken, 2, True);
      Mark;
      R.Judge (Marks, 2, Claims, 1, Item);
      if Item.Flag /= R.Smoother_Story or else Item.Place /= 1 then
         Fail ("rules smooth");
      end if;
      Claims (1).Item (2).Affirm := False;
      Marks := (others => R.Correct);
      Claims (1).Item (1) := (R.Taken, 2, True);
      Claims (1).Item (2) := (R.Taken, 1, True);
      Mark;
      R.Judge (Marks, 2, Claims, 1, Item);
      if Item.Flag /= R.Smoother_Story then
         Fail ("rules order");
      end if;
   end;

   D.Run;
   Mark;
   if D.Count /= 8 or else D.Which /= U.Showcase then
      Fail ("demo count");
   end if;
   declare
      Buf  : String (1 .. U.Max_Line) := (others => ' ');
      Last : Natural := 0;
   begin
      for I in 1 .. D.Name_Length (2) loop
         Last := Last + 1;
         Buf (Last) := Character'Val (D.Name_Byte (2, I));
      end loop;
      Mark;
      if Slice (Buf, Last) /= "xor-smooth" then
         Fail ("demo name");
      end if;
      Last := 0;
      for I in 1 .. D.Flag_Length (2) loop
         Last := Last + 1;
         Buf (Last) := Character'Val (D.Flag_Byte (2, I));
      end loop;
      Mark;
      if Slice (Buf, Last) /= "smoother-story" then
         Fail ("demo flag");
      end if;
      Mark;
      if D.Sentence_Mark (2, 1) /= 1 or else D.Step_Count (2) < 1 then
         Fail ("demo mark");
      end if;
      Mark;
      if D.Name_Byte (0, 1) /= 0 or else D.Step_Byte (2, 0, 1) /= 0 then
         Fail ("demo clamp");
      end if;
      D.Select_One (4);
      Mark;
      if D.Which /= 4 or else D.Sentence_Mark (4, 2) /= 1 then
         Fail ("demo select");
      end if;
      D.Select_One (0);
      Mark;
      if D.Which /= 4 then
         Fail ("demo select clamp");
      end if;
   end;

   declare
      use GNAT.OS_Lib;
      Out_Path : constant String := "obj/gen/summary-cli.txt";
      Empty    : Argument_List (1 .. 0);
      OK       : Boolean;
      Raw      : Integer;
   begin
      Spawn ("bin/summary_cli", Empty, Out_Path, OK, Raw, Err_To_Out => True);
      Mark;
      if not OK or else Raw /= 0 then
         Fail ("cli status");
      else
         declare
            File : IO.File_Type;
            Line : String (1 .. 400);
            Last : Natural;
            Text : String (1 .. 12_000) := (others => ' ');
            Used : Natural := 0;
         begin
            IO.Open (File, IO.In_File, Out_Path);
            while not IO.End_Of_File (File) loop
               IO.Get_Line (File, Line, Last);
               if Used + Last + 1 <= Text'Last then
                  Text (Used + 1 .. Used + Last) := Line (1 .. Last);
                  Used := Used + Last + 1;
                  Text (Used) := Character'Val (10);
               end if;
            end loop;
            IO.Close (File);
            if Ada.Strings.Fixed.Count
              (Text (1 .. Used), "xor-smooth smoother-story") /= 1
              or else Ada.Strings.Fixed.Count
                (Text (1 .. Used), "phantom-step") < 1
              or else Ada.Strings.Fixed.Count
                (Text (1 .. Used), "omitted-failure") < 1
              or else Ada.Strings.Fixed.Count
                (Text (1 .. Used), "checked-wrong") < 1
              or else Ada.Strings.Fixed.Count
                (Text (1 .. Used), "not-checkable") < 1
              or else Ada.Strings.Fixed.Count
                (Text (1 .. Used),
                 "every checked step is correct.") /= 1
            then
               Fail ("cli body");
            end if;
         end;
      end if;
   end;

   if Failures = 0 then
      IO.Put_Line ("cases summary_test" & Cases'Image);
      IO.Put_Line ("summary ok");
   else
      IO.Put_Line ("summary failures" & Failures'Image);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Summary_Test;
