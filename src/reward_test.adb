with Ada.Command_Line;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with GNAT.OS_Lib;
with AI_Amplifier.MLP;
with AI_Amplifier.Reward.Demo;

--  The two graders, the four cheats, the honest net, both
--  searches, the page wrapper, and reward_cli. Every cheat has
--  to fail the real check. The honest submission has to pass
--  both graders. The flawed search has to raise its proxy
--  without ever passing the real check. The real search has to
--  end on a pass.
procedure Reward_Test
  with SPARK_Mode => Off
is
   package R renames AI_Amplifier.Reward;
   package M renames AI_Amplifier.MLP;
   package D renames AI_Amplifier.Reward.Demo;
   use type R.Gap_Name;
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

   function Name_Of (Item : R.Submission) return String is
   begin
      return Text_Of (Item.Name, Item.Name_Last);
   end Name_Of;

   procedure Check_Bank is
      Bank : R.Set;
      Data : constant M.Sample_List := M.Make_Dataset (M.XOR_Points);
      Line : String (1 .. R.Max_Line);
      Last : Natural;
      Hits : Natural;
   begin
      R.Build (Bank);
      if Bank.Count /= 5 then
         Fail ("count");
         return;
      end if;
      if Name_Of (Bank.Slot (1)) /= "honest-trained"
        or else Name_Of (Bank.Slot (2)) /= "hard-coded-loss"
        or else Name_Of (Bank.Slot (3)) /= "constant-half"
        or else Name_Of (Bank.Slot (4)) /= "memorized-two"
        or else Name_Of (Bank.Slot (5)) /= "right-stamp"
      then
         Fail ("names");
      end if;

      if not Bank.Slot (1).Counts
        or else Bank.Slot (1).Gap /= R.None
        or else Bank.Slot (1).Flawed /= 1.0
        or else Bank.Slot (1).Real_Score /= 1.0
        or else not R.Real_Pass (Bank.Slot (1).Model)
        or else Bank.Slot (1).Reported_Loss >= R.Low_Loss
      then
         Fail ("honest");
      end if;

      if Bank.Slot (2).Counts
        or else Bank.Slot (2).Gap /= R.Reported_Loss
        or else Bank.Slot (2).Flawed /= 1.0
        or else Bank.Slot (2).Real_Score /= 0.0
        or else Bank.Slot (2).Reported_Loss /= R.Fake_Loss
        or else M.Mean_Loss (Bank.Slot (2).Model, Data) < R.Low_Loss
        or else Bank.Slot (2).Reported_Count /= 0
      then
         Fail ("hard-coded");
      end if;

      if Bank.Slot (3).Counts
        or else Bank.Slot (3).Gap /= R.Constant_Half
        or else Bank.Slot (3).Flawed /= 1.0
        or else Bank.Slot (3).Real_Score /= 0.0
        or else Bank.Slot (3).Reported_Count /= 4
      then
         Fail ("constant");
      end if;
      for I in 1 .. Data.Count loop
         if abs (Bank.Slot (3).Reported (I) - 0.5) > R.Half_Band
           or else abs (M.Predict (Bank.Slot (3).Model, Data.Item (I).X)
                        - 0.5) > 1.0e-3
         then
            Fail ("constant output");
         end if;
      end loop;

      Hits := 0;
      for I in 1 .. Data.Count loop
         declare
            Y : constant Float :=
              M.Predict (Bank.Slot (4).Model, Data.Item (I).X);
         begin
            if Data.Item (I).Label >= 0.5 then
               if Y >= R.High_Output then
                  Hits := Hits + 1;
               end if;
            elsif Y <= R.Low_Output then
               Hits := Hits + 1;
            end if;
         end;
      end loop;
      if Bank.Slot (4).Counts
        or else Bank.Slot (4).Gap /= R.Two_Of_Four
        or else Bank.Slot (4).Flawed /= 1.0
        or else Bank.Slot (4).Real_Score /= 0.5
        or else Hits /= 2
        or else Bank.Slot (4).Reported_Count /= 4
      then
         Fail ("memorized");
      end if;

      if Bank.Slot (5).Counts
        or else Bank.Slot (5).Gap /= R.Right_Stamp
        or else Bank.Slot (5).Flawed /= 1.0
        or else Bank.Slot (5).Real_Score /= 0.0
        or else Bank.Slot (5).Has_Loss
        or else Bank.Slot (5).Reported_Count /= 0
        or else Text_Of (Bank.Slot (5).Stamp, Bank.Slot (5).Stamp_Last)
                /= R.Shape_Stamp
        or else R.Real_Pass (Bank.Slot (5).Model)
      then
         Fail ("stamp");
      end if;

      for I in 2 .. Bank.Count loop
         if Bank.Slot (I).Counts or else R.Real_Pass (Bank.Slot (I).Model)
         then
            Fail ("cheat passed");
         end if;
      end loop;

      R.Tally_Line (Bank, Line, Last);
      if Text_Of (Line, Last)
        /= "Accepted: 1 of 5. Only the real check counts."
      then
         Fail ("tally " & Text_Of (Line, Last));
      end if;
      R.Stat_Line (Bank, Line, Last);
      if Ada.Strings.Fixed.Count (Text_Of (Line, Last), "20261104") /= 1
        or else Ada.Strings.Fixed.Count (Text_Of (Line, Last), "120 steps")
                /= 1
      then
         Fail ("stat " & Text_Of (Line, Last));
      end if;
      R.Line_For (Bank, 2, Line, Last);
      if Ada.Strings.Fixed.Count (Text_Of (Line, Last), "reported-loss")
        /= 1
        or else Ada.Strings.Fixed.Count (Text_Of (Line, Last), "rejected")
                /= 1
      then
         Fail ("line " & Text_Of (Line, Last));
      end if;
   end Check_Bank;

   procedure Check_Search is
      Flawed : R.Trace;
      Real   : R.Trace;
      Again  : R.Trace;
      Line   : String (1 .. R.Max_Line);
      Last   : Natural;
   begin
      R.Search (R.Flawed_Aim, Flawed);
      R.Search (R.Real_Aim, Real);
      R.Search (R.Flawed_Aim, Again);
      if Flawed.Points /= R.Max_Points or else Real.Points /= R.Max_Points
      then
         Fail ("points");
         return;
      end if;
      if Flawed.Proxy (Flawed.Points) < Flawed.Proxy (1) + 0.25 then
         Fail ("proxy did not rise");
      end if;
      for I in 1 .. Flawed.Points loop
         if Flawed.Passed (I) or else Flawed.Real_Score (I) >= 1.0 then
            Fail ("flawed search passed");
         end if;
         if Again.Proxy (I) /= Flawed.Proxy (I)
           or else Again.Real_Score (I) /= Flawed.Real_Score (I)
           or else Again.Passed (I) /= Flawed.Passed (I)
         then
            Fail ("not deterministic");
         end if;
      end loop;
      if not Real.Passed (Real.Points)
        or else Real.Real_Score (Real.Points) /= 1.0
        or else Real.Real_Score (1) >= 1.0
      then
         R.End_Line (Real, Line, Last);
         Fail ("real search " & Text_Of (Line, Last));
      end if;
      R.End_Line (Flawed, Line, Last);
      if Ada.Strings.Fixed.Count (Text_Of (Line, Last), "Real check fails.")
        /= 1
      then
         Fail ("flawed end " & Text_Of (Line, Last));
      end if;
      R.End_Line (Real, Line, Last);
      if Ada.Strings.Fixed.Count (Text_Of (Line, Last), "Real check passes.")
        /= 1
        or else Ada.Strings.Fixed.Count (Text_Of (Line, Last), "Real 1.00")
                /= 1
      then
         Fail ("real end " & Text_Of (Line, Last));
      end if;
   end Check_Search;

   function Demo_Text
     (Len  : Integer;
      Kind : Character;
      Row  : Integer;
      Col  : Integer := 0) return String
   is
      Buf : String (1 .. 200);
      N   : Natural := 0;
      B   : Integer;
   begin
      if Len < 0 or else Len > Buf'Length then
         return "";
      end if;
      for I in 1 .. Len loop
         if Kind = 'C' then
            B := D.Col_Byte (Row, Col, I);
         elsif Kind = 'T' then
            B := D.Tally_Byte (I);
         elsif Kind = 'S' then
            B := D.Stat_Byte (I);
         elsif Kind = 'F' then
            B := D.Flawed_End_Byte (I);
         else
            B := D.Real_End_Byte (I);
         end if;
         N := N + 1;
         Buf (N) := Character'Val (B);
      end loop;
      return Buf (1 .. N);
   end Demo_Text;

   procedure Check_Demo is
      Bank : R.Set;
      Line : String (1 .. R.Max_Line);
      Last : Natural;
   begin
      D.Run;
      if D.Submission_Count /= 5 or else D.Column_Count /= 5 then
         Fail ("demo count");
         return;
      end if;
      if D.Col_Length (-1, 1) /= 0 or else D.Col_Byte (1, 1, 0) /= 0
        or else D.Mark (0) /= 0 or else D.Flawed_Proxy (0) /= 0.0
        or else D.Real_Holds (10_000) /= 0
      then
         Fail ("demo clamp");
      end if;
      R.Build (Bank);
      if D.Mark (1) /= 1 or else D.Mark (2) /= 0 then
         Fail ("demo mark");
      end if;
      for I in 1 .. 5 loop
         declare
            Word  : String (1 .. 16);
            WLast : Natural;
         begin
            R.Gap_Word (Bank.Slot (I).Gap, Word, WLast);
            if Demo_Text (D.Col_Length (I, 5), 'C', I, 5)
              /= Text_Of (Word, WLast)
              or else Demo_Text (D.Col_Length (I, 2), 'C', I, 2)
                      /= R.Score_Text (Bank.Slot (I).Flawed)
              or else Demo_Text (D.Col_Length (I, 3), 'C', I, 3)
                      /= R.Score_Text (Bank.Slot (I).Real_Score)
            then
               Fail ("demo cell");
            end if;
         end;
      end loop;
      R.Tally_Line (Bank, Line, Last);
      if Demo_Text (D.Tally_Length, 'T', 0) /= Text_Of (Line, Last) then
         Fail ("demo tally");
      end if;
      if D.Step_Count /= R.Max_Points then
         Fail ("demo steps");
      end if;
      if D.Flawed_Holds (D.Step_Count) /= 0
        or else D.Flawed_Proxy (D.Step_Count)
                <= D.Flawed_Proxy (1)
      then
         Fail ("demo flawed curve");
      end if;
      if D.Real_Holds (D.Step_Count) /= 1
        or else D.Real_At (D.Step_Count) /= 1.0
      then
         Fail ("demo real curve");
      end if;
      if Ada.Strings.Fixed.Count
           (Demo_Text (D.Flawed_End_Length, 'F', 0), "fails.") /= 1
        or else Ada.Strings.Fixed.Count
           (Demo_Text (D.Real_End_Length, 'R', 0), "passes.") /= 1
      then
         Fail ("demo ends");
      end if;
   end Check_Demo;

   function Exit_Of (Code : Integer) return Integer is
   begin
      if Code >= 256 then
         return Code / 256;
      end if;
      return Code;
   end Exit_Of;

   function Read_File (Name : String) return String is
      File : Ada.Streams.Stream_IO.File_Type;
      Raw  : Ada.Streams.Stream_Element_Array (1 .. 80_000);
      Last : Ada.Streams.Stream_Element_Offset;
      Buf  : String (1 .. 80_000);
      N    : Natural := 0;
   begin
      Ada.Streams.Stream_IO.Open
        (File, Ada.Streams.Stream_IO.In_File, Name);
      Ada.Streams.Stream_IO.Read (File, Raw, Last);
      Ada.Streams.Stream_IO.Close (File);
      for I in 1 .. Last loop
         N := N + 1;
         Buf (N) := Character'Val (Raw (I));
      end loop;
      return Buf (1 .. N);
   end Read_File;

   procedure Run_Cli
     (Args : GNAT.OS_Lib.Argument_List;
      Code : out Integer;
      Text : out String;
      Last : out Natural)
   is
      Out_Path : constant String := "/tmp/aaa-reward-cli-out";
      List     : GNAT.OS_Lib.Argument_List (Args'Range);
      OK       : Boolean;
      Raw      : Integer;
   begin
      Last := 0;
      for I in Args'Range loop
         List (I) := new String'(Args (I).all);
      end loop;
      GNAT.OS_Lib.Spawn
        ("bin/reward_cli", List, Out_Path, OK, Raw, Err_To_Out => True);
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
      Empty : GNAT.OS_Lib.Argument_List (1 .. 0);
      Flawed_Arg : GNAT.OS_Lib.Argument_List :=
        (1 => new String'("flawed"));
      Real_Arg : GNAT.OS_Lib.Argument_List :=
        (1 => new String'("real"));
      Bad_Arg : GNAT.OS_Lib.Argument_List :=
        (1 => new String'("nope"));
      Code : Integer;
      Buf  : String (1 .. 40_000);
      Last : Natural;
   begin
      Run_Cli (Empty, Code, Buf, Last);
      if Code /= 0
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last), "reported-loss") /= 1
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last), "constant-half") /= 2
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last), "two-of-four") /= 1
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last), "right-stamp") /= 2
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last), "honest-trained") /= 1
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last),
           "Accepted: 1 of 5. Only the real check counts.") /= 1
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last), "Real check fails.") /= 1
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last), "Real check passes.") /= 1
      then
         Fail ("cli " & Text_Of (Buf, Last));
      end if;
      Run_Cli (Flawed_Arg, Code, Buf, Last);
      if Code /= 0
        or else Ada.Strings.Fixed.Count (Text_Of (Buf, Last), "step 0") /= 1
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last), "fails") < 2
      then
         Fail ("cli flawed");
      end if;
      Run_Cli (Real_Arg, Code, Buf, Last);
      if Code /= 0
        or else Ada.Strings.Fixed.Count
          (Text_Of (Buf, Last), "Real check passes.") /= 1
      then
         Fail ("cli real");
      end if;
      Run_Cli (Bad_Arg, Code, Buf, Last);
      if Code /= 1
        or else Ada.Strings.Fixed.Count (Text_Of (Buf, Last), "usage:") /= 1
      then
         Fail ("cli usage");
      end if;
      GNAT.OS_Lib.Free (Flawed_Arg (1));
      GNAT.OS_Lib.Free (Real_Arg (1));
      GNAT.OS_Lib.Free (Bad_Arg (1));
   end Check_Cli;

begin
   Check_Bank;
   Check_Search;
   Check_Demo;
   Check_Cli;
   if Failures = 0 then
      IO.Put_Line ("reward ok");
      Ada.Command_Line.Set_Exit_Status (0);
   else
      IO.Put_Line ("reward failed");
      Ada.Command_Line.Set_Exit_Status (1);
   end if;
end Reward_Test;
