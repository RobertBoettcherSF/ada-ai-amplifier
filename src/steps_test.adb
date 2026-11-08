with Ada.Command_Line;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with GNAT.OS_Lib;
with AI_Amplifier.MLP;
with AI_Amplifier.Steps.Demo;
with AI_Amplifier.Steps.Manifest;
with AI_Amplifier.Tensors;

--  The twelve solutions, the planted list, a file the checker
--  has not seen, the page wrapper, and steps_cli. The checker
--  does not read the manifest. A correct solution is accepted.
--  A planted flaw fails at the row the manifest names.
procedure Steps_Test
  with SPARK_Mode => Off
is
   package S renames AI_Amplifier.Steps;
   package D renames AI_Amplifier.Steps.Demo;
   package M renames AI_Amplifier.MLP;
   package T renames AI_Amplifier.Tensors;
   package IO renames Ada.Text_IO;
   use type S.Mark;

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

   procedure Show (Item : S.Report) is
      Word : String (1 .. S.Max_Note);
      Last : Natural;
   begin
      IO.Put ("  ");
      IO.Put (Slice (Item.Name, Item.Name_Last));
      IO.Put (" answer ");
      S.Mark_Word (Item.Answer_Grade, Word, Last);
      IO.Put (Slice (Word, Last));
      IO.Put (" steps ");
      S.Mark_Word (Item.Step_Grade, Word, Last);
      IO.Put (Slice (Word, Last));
      IO.Put (" bad ");
      IO.Put (Natural'Image (Item.Bad_At));
      IO.Put (" ");
      S.Rule_Word (Item.Rule, Word, Last);
      IO.Put_Line (Slice (Word, Last));
      for I in 1 .. Item.Count loop
         IO.Put ("   ");
         IO.Put (Natural'Image (I));
         IO.Put (" ");
         IO.Put (Slice (Item.Item (I).Text, Item.Item (I).Last));
         if not Item.Item (I).OK then
            IO.Put ("  ");
            S.Rule_Word (Item.Item (I).Rule, Word, Last);
            IO.Put (Slice (Word, Last));
         end if;
         IO.New_Line;
      end loop;
   end Show;

   function Word_At
     (Text  : String;
      Index : Positive) return String
   is
      Seen : Natural := 0;
      I    : Natural := Text'First;
      A, B : Natural;
   begin
      while I <= Text'Last loop
         while I <= Text'Last and then Text (I) = ' ' loop
            I := I + 1;
         end loop;
         exit when I > Text'Last or else Text (I) = Character'Val (10);
         A := I;
         while I <= Text'Last
           and then Text (I) /= ' '
           and then Text (I) /= Character'Val (10)
         loop
            I := I + 1;
         end loop;
         B := I - 1;
         Seen := Seen + 1;
         if Seen = Index then
            return Text (A .. B);
         end if;
      end loop;
      return "";
   end Word_At;

   procedure Check_Manifest is
      Rest  : Natural := S.Manifest.Text'First;
      Lines : Natural := 0;
      Item  : S.Report;
      Word  : String (1 .. S.Max_Note);
      Last  : Natural;
      Name  : String (1 .. S.Max_Name);
      NLast : Natural;
   begin
      while Rest <= S.Manifest.Text'Last loop
         declare
            First : constant Natural := Rest;
            Stop  : Natural := Rest - 1;
            Line  : Natural;
         begin
            while Rest <= S.Manifest.Text'Last
              and then S.Manifest.Text (Rest) /= Character'Val (10)
            loop
               Stop := Rest;
               Rest := Rest + 1;
            end loop;
            if Rest <= S.Manifest.Text'Last then
               Rest := Rest + 1;
            end if;
            if Stop < First then
               goto Continue;
            end if;
            Lines := Lines + 1;
            if Lines > S.Solution_Count then
               Fail ("manifest longer than the bank");
               return;
            end if;
            Line := Lines;
            declare
               Row   : constant String := S.Manifest.Text (First .. Stop);
               Who   : constant String := Word_At (Row, 1);
               Flaw  : constant String := Word_At (Row, 2);
               Where    : constant String := Word_At (Row, 3);
               Rule  : constant String := Word_At (Row, 4);
               Place : Natural;
            begin
               S.Grade_Built_In (Line, Item);
               NLast := Item.Name_Last;
               if NLast > Name'Length then
                  Fail ("name too long");
                  goto Continue;
               end if;
               Name (1 .. NLast) := Item.Name (1 .. NLast);
               if NLast /= Who'Length or else Name (1 .. NLast) /= Who then
                  Fail ("name " & Who);
                  Show (Item);
               end if;
               S.Rule_Word (Item.Rule, Word, Last);
               Place := 0;
               if Where'Length > 0 then
                  Place := Natural'Value (Where);
               end if;
               if Place /= Item.Bad_At
                 or else Last /= Rule'Length
                 or else Word (1 .. Last) /= Rule
               then
                  Fail ("row " & Who);
                  Show (Item);
               end if;
               if Flaw = "none" then
                  if Item.Answer_Grade /= S.Pass
                    or else Item.Step_Grade /= S.Pass
                    or else Item.Bad_At /= 0
                  then
                     Fail ("accepted " & Who);
                     Show (Item);
                  end if;
               elsif Flaw = "wrong" then
                  if Item.Answer_Grade /= S.Fail
                    or else Item.Step_Grade /= S.Fail
                  then
                     Fail ("wrong answer " & Who);
                     Show (Item);
                  end if;
               else
                  if Item.Answer_Grade /= S.Pass
                    or else Item.Step_Grade /= S.Fail
                  then
                     Fail ("flaw " & Who);
                     Show (Item);
                  end if;
               end if;
            end;
            <<Continue>>
         end;
      end loop;
      if Lines /= S.Solution_Count then
         Fail ("manifest lines");
      end if;
   end Check_Manifest;

   procedure Check_Library is
      Value : Natural;
      OK    : Boolean;
      Net   : M.Net;
      X     : T.Vector (2);
      Y     : Float;
   begin
      S.Fib_Answer (0, Value, OK);
      if not OK or else Value /= 0 then
         Fail ("F(0)");
      end if;
      S.Fib_Answer (1, Value, OK);
      if not OK or else Value /= 1 then
         Fail ("F(1)");
      end if;
      S.Fib_Answer (2, Value, OK);
      if not OK or else Value /= 1 then
         Fail ("F(2)");
      end if;
      S.Fib_Answer (3, Value, OK);
      if not OK or else Value /= 2 then
         Fail ("F(3)");
      end if;
      S.Fib_Answer (4, Value, OK);
      if not OK or else Value /= 3 then
         Fail ("F(4)");
      end if;
      S.Fib_Answer (5, Value, OK);
      if not OK or else Value /= 5 then
         Fail ("F(5)");
      end if;
      S.Fib_Answer (6, Value, OK);
      if not OK or else Value /= 8 then
         Fail ("F(6)");
      end if;
      S.Fib_Answer (13, Value, OK);
      if OK then
         Fail ("fib past the limit");
      end if;
      Net := M.Hand_XOR;
      X := (Length => 2, Data => (0.0, 0.0));
      Y := M.Predict (Net, X);
      if Y >= 0.5 then
         Fail ("xor 0 0 class");
      end if;
      X := (Length => 2, Data => (0.0, 1.0));
      Y := M.Predict (Net, X);
      if Y < 0.5 then
         Fail ("xor 0 1 class");
      end if;
      X := (Length => 2, Data => (1.0, 0.0));
      Y := M.Predict (Net, X);
      if Y < 0.5 then
         Fail ("xor 1 0 class");
      end if;
      X := (Length => 2, Data => (1.0, 1.0));
      Y := M.Predict (Net, X);
      if Y >= 0.5 then
         Fail ("xor 1 1 class");
      end if;
   end Check_Library;

   procedure Check_File is
      Good : constant String :=
        "name user-fib" & Character'Val (10)
        & "problem fib 3" & Character'Val (10)
        & "step 2 1 1" & Character'Val (10)
        & "step 1 1 2" & Character'Val (10)
        & "step 0 2 3" & Character'Val (10)
        & "answer 2" & Character'Val (10);
      Skip : constant String :=
        "problem fib 3" & Character'Val (10)
        & "step 2 1 1" & Character'Val (10)
        & "step 0 2 3" & Character'Val (10)
        & "answer 2" & Character'Val (10);
      Bad  : constant String :=
        "problem fib 3" & Character'Val (10)
        & "step 2 1 1" & Character'Val (10)
        & "step 1 1 2" & Character'Val (10)
        & "step 0 2 3" & Character'Val (10)
        & "answer 9" & Character'Val (10);
      Item : S.Report;
      Word : String (1 .. 32);
      Last : Natural;
   begin
      S.Grade (Good, Item);
      if Item.Answer_Grade /= S.Pass or else Item.Step_Grade /= S.Pass then
         Fail ("user fib 3");
         Show (Item);
      end if;
      S.Grade (Skip, Item);
      S.Rule_Word (Item.Rule, Word, Last);
      if Item.Answer_Grade /= S.Pass
        or else Item.Step_Grade /= S.Fail
        or else Item.Bad_At /= 2
        or else Word (1 .. Last) /= "not-toward-base"
      then
         Fail ("user skip");
         Show (Item);
      end if;
      S.Grade (Bad, Item);
      S.Rule_Word (Item.Rule, Word, Last);
      if Item.Answer_Grade /= S.Fail
        or else Item.Step_Grade /= S.Fail
        or else Word (1 .. Last) /= "wrong-answer"
      then
         Fail ("user wrong answer");
         Show (Item);
      end if;
   end Check_File;

   function Demo_Text (Len : Integer; Kind : Character; Row : Integer)
     return String
   is
      Buf : String (1 .. 200) := (others => ' ');
      N   : Integer;
   begin
      if Len < 1 or else Len > Buf'Length then
         return "";
      end if;
      for I in 1 .. Len loop
         if Kind = 'N' then
            N := D.Name_Byte (Row, I);
         elsif Kind = 'A' then
            N := D.Answer_Byte (Row, I);
         elsif Kind = 'S' then
            N := D.Steps_Byte (Row, I);
         elsif Kind = 'R' then
            N := D.Row_Byte (Row, I);
         elsif Kind = 'U' then
            N := D.Rule_Byte (I);
         else
            N := D.Stat_Byte (I);
         end if;
         Buf (I) := Character'Val (N);
      end loop;
      return Buf (1 .. Len);
   end Demo_Text;

   procedure Check_Demo is
   begin
      if D.Solution_Count /= 0 then
         Fail ("demo before run");
      end if;
      D.Run;
      declare
         Stat : constant String := Demo_Text (D.Stat_Length, 'T', 1);
      begin
         if D.Solution_Count /= S.Solution_Count then
            Fail ("demo count");
         end if;
         if D.Which /= S.Showcase then
            Fail ("demo which");
         end if;
         if Demo_Text (D.Name_Length (1), 'N', 1) /= "xor-00-right" then
            Fail ("demo name");
         end if;
         if Demo_Text (D.Answer_Length (1), 'A', 1) /= "pass"
           or else Demo_Text (D.Steps_Length (1), 'S', 1) /= "pass"
         then
            Fail ("demo right grades");
         end if;
         if Demo_Text (D.Answer_Length (2), 'A', 2) /= "pass"
           or else Demo_Text (D.Steps_Length (2), 'S', 2) /= "fail"
         then
            Fail ("demo cancel grades");
         end if;
         if Demo_Text (D.Answer_Length (5), 'A', 5) /= "fail" then
            Fail ("demo wrong grade");
         end if;
         if D.Bad_At /= 2
           or else Demo_Text (D.Rule_Length, 'U', 1) /= "bad-value"
         then
            Fail ("demo bad step");
         end if;
         if D.Row_Length (2) < 8
           or else Demo_Text (D.Row_Length (2), 'R', 2) (1 .. 8) /= "step h1 "
         then
            Fail ("demo h1 row " & Demo_Text (D.Row_Length (2), 'R', 2));
         end if;
         if Stat'Length < 20
           or else Stat (Stat'First .. Stat'First + 12) /= "12 solutions."
           or else Ada.Strings.Fixed.Count (Stat, "Only the steps count.") /= 1
         then
            Fail ("demo stat " & Stat);
         end if;
      end;
      D.Select_One (0);
      if D.Which /= S.Showcase then
         Fail ("demo select clamp");
      end if;
      D.Select_One (11);
      if D.Bad_At /= 0
        or else Demo_Text (D.Steps_Length (11), 'S', 11) /= "pass"
      then
         Fail ("demo sum");
      end if;
      if D.Name_Byte (0, 1) /= 0 or else D.Row_Byte (99, 1) /= 0 then
         Fail ("demo clamp");
      end if;
   end Check_Demo;

   function Exit_Of (Code : Integer) return Integer is
   begin
      if Code >= 256 then
         return Code / 256;
      end if;
      return Code;
   end Exit_Of;

   function Read_Out (Name : String) return String is
      File : IO.File_Type;
      Buf  : String (1 .. 8_000);
      Last : Natural := 0;
      Line : String (1 .. 400);
      Len  : Natural;
   begin
      IO.Open (File, IO.In_File, Name);
      while not IO.End_Of_File (File) loop
         IO.Get_Line (File, Line, Len);
         if Last > 0 then
            Last := Last + 1;
            Buf (Last) := Character'Val (10);
         end if;
         if Len > Buf'Last - Last then
            IO.Close (File);
            return Buf (1 .. Last);
         end if;
         Buf (Last + 1 .. Last + Len) := Line (1 .. Len);
         Last := Last + Len;
      end loop;
      IO.Close (File);
      return Buf (1 .. Last);
   exception
      when others =>
         if IO.Is_Open (File) then
            IO.Close (File);
         end if;
         return "";
   end Read_Out;

   procedure Check_Cli is
      Out_Path : constant String := "/tmp/aaa-steps-cli-out";
      File_Path : constant String := "/tmp/aaa-steps-user.txt";
      Empty : GNAT.OS_Lib.Argument_List (1 .. 0);
      Args  : GNAT.OS_Lib.Argument_List (1 .. 1);
      OK    : Boolean;
      Raw   : Integer;
      Text  : String (1 .. 8_000);
      Last  : Natural;
      File  : IO.File_Type;
   begin
      GNAT.OS_Lib.Spawn
        ("bin/steps_cli", Empty, Out_Path, OK, Raw, Err_To_Out => True);
      if not OK or else Exit_Of (Raw) /= 0 then
         Fail ("cli table status");
         return;
      end if;
      declare
         Got : constant String := Read_Out (Out_Path);
      begin
         if Got'Length = 0
           or else Got'Length > Text'Length
         then
            Fail ("cli table empty");
         else
            Text (1 .. Got'Length) := Got;
            Last := Got'Length;
            if Text (1 .. 4) /= "name"
              or else Last < 40
            then
               Fail ("cli header");
            end if;
         end if;
         if Ada.Strings.Fixed.Count (Got, "xor-00-right") /= 1
           or else Ada.Strings.Fixed.Count (Got, "sum-guess") /= 1
           or else Ada.Strings.Fixed.Count (Got, "Only the steps count.") /= 1
         then
            Fail ("cli table body");
            IO.Put_Line (Got);
         end if;
      end;
      IO.Create (File, IO.Out_File, File_Path);
      IO.Put_Line (File, "problem fib 3");
      IO.Put_Line (File, "step 2 1 1");
      IO.Put_Line (File, "step 0 2 3");
      IO.Put_Line (File, "answer 2");
      IO.Close (File);
      Args (1) := new String'(File_Path);
      GNAT.OS_Lib.Spawn
        ("bin/steps_cli", Args, Out_Path, OK, Raw, Err_To_Out => True);
      GNAT.OS_Lib.Free (Args (1));
      if not OK or else Exit_Of (Raw) /= 1 then
         Fail ("cli file status");
      end if;
      declare
         Got : constant String := Read_Out (Out_Path);
      begin
         if Ada.Strings.Fixed.Count (Got, "not-toward-base") < 1
           or else Ada.Strings.Fixed.Count (Got, "answer pass") /= 1
           or else Ada.Strings.Fixed.Count (Got, "steps fail") /= 1
         then
            Fail ("cli file body");
            IO.Put_Line (Got);
         end if;
      end;
   end Check_Cli;

begin
   Check_Library;
   Check_Manifest;
   Check_File;
   Check_Demo;
   Check_Cli;
   if Failures = 0 then
      IO.Put_Line ("steps ok");
   else
      IO.Put_Line ("steps FAIL" & Natural'Image (Failures));
      Ada.Command_Line.Set_Exit_Status (1);
   end if;
end Steps_Test;
