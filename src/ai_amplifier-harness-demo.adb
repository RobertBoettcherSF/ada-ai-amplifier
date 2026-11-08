package body AI_Amplifier.Harness.Demo
  with SPARK_Mode => Off
is

   Max_Cell : constant := 24;

   subtype Cell_Text is String (1 .. Max_Cell);
   subtype Line_Text is String (1 .. Max_Line);

   function To_Name (Index : Integer) return Harness_Name is
   begin
      case Index is
         when 1 =>
            return One_Shot;
         when 2 =>
            return Retry;
         when 3 =>
            return Checked;
         when others =>
            return Budgeted;
      end case;
   end To_Name;

   Ready : Boolean := False;
   Pick  : Natural := Showcase;
   Cells : array (0 .. Harness_Count, 1 .. 4) of Cell_Text :=
     (others => (others => (others => ' ')));
   Cell_Last : array (0 .. Harness_Count, 1 .. 4) of Natural :=
     (others => (others => 0));
   Names : array (1 .. Task_Count) of Cell_Text :=
     (others => (others => ' '));
   Name_Last : array (1 .. Task_Count) of Natural := (others => 0);
   Logs : array
     (1 .. Task_Count, Harness_Name, 1 .. Max_Call) of Line_Text :=
     (others => (others => (others => (others => ' '))));
   Log_Last : array
     (1 .. Task_Count, Harness_Name, 1 .. Max_Call) of Natural :=
     (others => (others => (others => 0)));
   Counts : array (1 .. Task_Count, Harness_Name) of Natural :=
     (others => (others => 0));
   Hits : array (1 .. Task_Count, Harness_Name) of Boolean :=
     (others => (others => False));
   Results : array (1 .. Task_Count, Harness_Name) of Line_Text :=
     (others => (others => (others => ' ')));
   Result_Last : array (1 .. Task_Count, Harness_Name) of Natural :=
     (others => (others => 0));
   Stat : Line_Text := (others => ' ');
   Stat_Last : Natural := 0;

   function Byte_At (Text : String; Last, Index : Integer) return Integer is
   begin
      if Index < 1 or else Index > Last or else Index > Text'Length then
         return 0;
      end if;
      return Character'Pos (Text (Text'First + Index - 1));
   end Byte_At;

   procedure Set_Cell (Row, Col : Natural; Item : String) is
   begin
      if Row > Harness_Count or else Col < 1 or else Col > 4 then
         return;
      end if;
      Cell_Last (Row, Col) := 0;
      if Item'Length = 0 or else Item'Length > Max_Cell then
         return;
      end if;
      Cells (Row, Col) (1 .. Item'Length) := Item;
      Cell_Last (Row, Col) := Item'Length;
   end Set_Cell;

   procedure Run is
      Bank : Table := (others => (0, 0, 0));
      Walk : Harness.Run;
      Line : String (1 .. Max_Line);
      Last : Natural;
   begin
      Cell_Last := (others => (others => 0));
      Name_Last := (others => 0);
      Log_Last := (others => (others => (others => 0)));
      Counts := (others => (others => 0));
      Hits := (others => (others => False));
      Result_Last := (others => (others => 0));
      Stat_Last := 0;
      Ready := False;
      Pick := Showcase;
      Set_Cell (0, 1, "harness");
      Set_Cell (0, 2, "solve rate");
      Set_Cell (0, 3, "steps");
      Set_Cell (0, 4, "wrong accepted");
      for Index in 1 .. Task_Count loop
         Task_Name (Index, Line, Last);
         if Last > 0 and then Last <= Max_Cell then
            Names (Index) (1 .. Last) := Line (1 .. Last);
            Name_Last (Index) := Last;
         end if;
         for Which in Harness_Name loop
            Run_One (Which, Index, Walk);
            if Walk.Solved then
               Bank (Which).Solved := Bank (Which).Solved + 1;
            end if;
            Bank (Which).Steps := Bank (Which).Steps + Walk.Steps;
            Bank (Which).Wrong := Bank (Which).Wrong + Walk.Wrong;
            Counts (Index, Which) := Walk.Calls;
            Hits (Index, Which) := Walk.Solved;
            Result_Line (Walk, Line, Last);
            if Last > 0 then
               Results (Index, Which) (1 .. Last) := Line (1 .. Last);
               Result_Last (Index, Which) := Last;
            end if;
            for N in 1 .. Walk.Calls loop
               Log_Line (Walk, N, Line, Last);
               if Last > 0 then
                  Logs (Index, Which, N) (1 .. Last) := Line (1 .. Last);
                  Log_Last (Index, Which, N) := Last;
               end if;
            end loop;
         end loop;
      end loop;
      for Which in Harness_Name loop
         declare
            Row : constant Natural := Natural (Harness_Code (Which));
            Word : String (1 .. Max_Name);
            WLast : Natural;
         begin
            for Col in 1 .. 4 loop
               Cell (Which, Bank, Col, Word, WLast);
               if WLast > 0 then
                  Set_Cell (Row, Col, Word (1 .. WLast));
               end if;
            end loop;
         end;
      end loop;
      Stat_Line (Stat, Stat_Last);
      Ready := True;
   end Run;

   function Count_Harnesses return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Harness_Count;
   end Count_Harnesses;

   function Count_Tasks return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Task_Count;
   end Count_Tasks;

   function Column_Count return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return 4;
   end Column_Count;

   function Cell_Length (Row, Col : Integer) return Integer is
   begin
      if not Ready or else Row < 0 or else Row > Harness_Count
        or else Col < 1 or else Col > 4
      then
         return 0;
      end if;
      return Cell_Last (Row, Col);
   end Cell_Length;

   function Cell_Byte (Row, Col, Pos : Integer) return Integer is
   begin
      if Cell_Length (Row, Col) = 0 then
         return 0;
      end if;
      return Byte_At (Cells (Row, Col), Cell_Last (Row, Col), Pos);
   end Cell_Byte;

   function Task_Length (Index : Integer) return Integer is
   begin
      if not Ready or else Index < 1 or else Index > Task_Count then
         return 0;
      end if;
      return Name_Last (Index);
   end Task_Length;

   function Task_Byte (Index, Pos : Integer) return Integer is
   begin
      if Task_Length (Index) = 0 then
         return 0;
      end if;
      return Byte_At (Names (Index), Name_Last (Index), Pos);
   end Task_Byte;

   procedure Select_Task (Index : Integer) is
   begin
      if not Ready or else Index < 1 or else Index > Task_Count then
         return;
      end if;
      Pick := Index;
   end Select_Task;

   function Shown (Harness : Integer) return Boolean is
     (Ready
      and then Harness in 1 .. Harness_Count
      and then Pick in 1 .. Task_Count);

   function Log_Count (Harness : Integer) return Integer is
   begin
      if not Shown (Harness) then
         return 0;
      end if;
      return Counts (Pick, To_Name (Harness));
   end Log_Count;

   function Log_Length (Harness, Index : Integer) return Integer is
   begin
      if not Shown (Harness)
        or else Index < 1
        or else Index > Counts (Pick, To_Name (Harness))
      then
         return 0;
      end if;
      return Log_Last (Pick, To_Name (Harness), Index);
   end Log_Length;

   function Log_Byte (Harness, Index, Pos : Integer) return Integer is
   begin
      if Log_Length (Harness, Index) = 0 then
         return 0;
      end if;
      return Byte_At
        (Logs (Pick, To_Name (Harness), Index),
         Log_Last (Pick, To_Name (Harness), Index), Pos);
   end Log_Byte;

   function Solved (Harness : Integer) return Integer is
   begin
      if not Shown (Harness) then
         return 0;
      end if;
      if Hits (Pick, To_Name (Harness)) then
         return 1;
      end if;
      return 0;
   end Solved;

   function Result_Length (Harness : Integer) return Integer is
   begin
      if not Shown (Harness) then
         return 0;
      end if;
      return Result_Last (Pick, To_Name (Harness));
   end Result_Length;

   function Result_Byte (Harness, Pos : Integer) return Integer is
   begin
      if Result_Length (Harness) = 0 then
         return 0;
      end if;
      return Byte_At
        (Results (Pick, To_Name (Harness)),
         Result_Last (Pick, To_Name (Harness)), Pos);
   end Result_Byte;

   function Stat_Length return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Stat_Last;
   end Stat_Length;

   function Stat_Byte (Index : Integer) return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Byte_At (Stat, Stat_Last, Index);
   end Stat_Byte;

end AI_Amplifier.Harness.Demo;
