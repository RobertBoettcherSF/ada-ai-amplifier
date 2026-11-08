package body AI_Amplifier.Reward.Demo
  with SPARK_Mode => Off
is

   Max_Cell : constant := 32;
   Columns  : constant := 5;

   subtype Cell_Text is String (1 .. Max_Cell);

   Bank   : Set;
   Ready  : Boolean := False;
   Flawed : Trace;
   Real   : Trace;
   Cells  : array (0 .. Max_Submissions, 1 .. Columns) of Cell_Text :=
     (others => (others => (others => ' ')));
   Cell_Last : array (0 .. Max_Submissions, 1 .. Columns) of Natural :=
     (others => (others => 0));
   Tally      : String (1 .. Max_Line) := (others => ' ');
   Tally_Last : Natural := 0;
   Stat       : String (1 .. Max_Line) := (others => ' ');
   Stat_Last  : Natural := 0;
   Flawed_End : String (1 .. Max_Line) := (others => ' ');
   Flawed_End_Last : Natural := 0;
   Real_End   : String (1 .. Max_Line) := (others => ' ');
   Real_End_Last : Natural := 0;

   function Byte_At (Text : String; Last, Index : Integer) return Integer is
   begin
      if Index < 1 or else Index > Last or else Index > Text'Length then
         return 0;
      end if;
      return Character'Pos (Text (Text'First + Index - 1));
   end Byte_At;

   procedure Set_Cell (Row, Col : Natural; Item : String) is
   begin
      if Row > Max_Submissions or else Col < 1 or else Col > Columns then
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
      Word  : String (1 .. 16);
      WLast : Natural;
   begin
      Cell_Last := (others => (others => 0));
      Tally_Last := 0;
      Stat_Last := 0;
      Flawed_End_Last := 0;
      Real_End_Last := 0;
      Ready := False;
      Build (Bank);
      Set_Cell (0, 1, "name");
      Set_Cell (0, 2, "flawed");
      Set_Cell (0, 3, "real");
      Set_Cell (0, 4, "verdict");
      Set_Cell (0, 5, "gap");
      for I in 1 .. Bank.Count loop
         if Bank.Slot (I).Name_Last > 0 then
            Set_Cell (I, 1, Bank.Slot (I).Name (1 .. Bank.Slot (I).Name_Last));
         end if;
         Set_Cell (I, 2, Score_Text (Bank.Slot (I).Flawed));
         Set_Cell (I, 3, Score_Text (Bank.Slot (I).Real_Score));
         if Bank.Slot (I).Counts then
            Set_Cell (I, 4, "counts");
         else
            Set_Cell (I, 4, "rejected");
         end if;
         Gap_Word (Bank.Slot (I).Gap, Word, WLast);
         if WLast > 0 then
            Set_Cell (I, 5, Word (1 .. WLast));
         end if;
      end loop;
      Tally_Line (Bank, Tally, Tally_Last);
      Stat_Line (Bank, Stat, Stat_Last);
      Search (Flawed_Aim, Flawed);
      Search (Real_Aim, Real);
      End_Line (Flawed, Flawed_End, Flawed_End_Last);
      End_Line (Real, Real_End, Real_End_Last);
      if Bank.Count = AI_Amplifier.Reward.Submission_Count
        and then Tally_Last > 0
        and then Stat_Last > 0
        and then Flawed.Points = Max_Points
        and then Real.Points = Max_Points
        and then Flawed_End_Last > 0
        and then Real_End_Last > 0
      then
         Ready := True;
      end if;
   end Run;

   function Submission_Count return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Integer (Bank.Count);
   end Submission_Count;

   function Column_Count return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Columns;
   end Column_Count;

   function Col_Length (Index, Col : Integer) return Integer is
   begin
      if not Ready or else Index < 0 or else Index > Integer (Bank.Count)
        or else Col < 1 or else Col > Columns
      then
         return 0;
      end if;
      return Cell_Last (Index, Col);
   end Col_Length;

   function Col_Byte (Index, Col, Pos : Integer) return Integer is
   begin
      if not Ready or else Index < 0 or else Index > Integer (Bank.Count)
        or else Col < 1 or else Col > Columns
      then
         return 0;
      end if;
      if Pos < 1 or else Pos > Cell_Last (Index, Col) then
         return 0;
      end if;
      return Character'Pos (Cells (Index, Col) (Pos));
   end Col_Byte;

   function Mark (Index : Integer) return Integer is
   begin
      if not Ready or else Index < 1 or else Index > Integer (Bank.Count) then
         return 0;
      end if;
      if Bank.Slot (Index).Counts then
         return 1;
      end if;
      return 0;
   end Mark;

   function Tally_Length return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Tally_Last;
   end Tally_Length;

   function Tally_Byte (Index : Integer) return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Byte_At (Tally, Tally_Last, Index);
   end Tally_Byte;

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

   function Step_Count return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Flawed.Points;
   end Step_Count;

   function Flawed_Proxy (Step : Integer) return Float is
   begin
      if not Ready or else Step < 1 or else Step > Flawed.Points then
         return 0.0;
      end if;
      return Flawed.Proxy (Step);
   end Flawed_Proxy;

   function Flawed_Real (Step : Integer) return Float is
   begin
      if not Ready or else Step < 1 or else Step > Flawed.Points then
         return 0.0;
      end if;
      return Flawed.Real_Score (Step);
   end Flawed_Real;

   function Flawed_Holds (Step : Integer) return Integer is
   begin
      if not Ready or else Step < 1 or else Step > Flawed.Points then
         return 0;
      end if;
      if Flawed.Passed (Step) then
         return 1;
      end if;
      return 0;
   end Flawed_Holds;

   function Real_Proxy (Step : Integer) return Float is
   begin
      if not Ready or else Step < 1 or else Step > Real.Points then
         return 0.0;
      end if;
      return Real.Proxy (Step);
   end Real_Proxy;

   function Real_At (Step : Integer) return Float is
   begin
      if not Ready or else Step < 1 or else Step > Real.Points then
         return 0.0;
      end if;
      return Real.Real_Score (Step);
   end Real_At;

   function Real_Holds (Step : Integer) return Integer is
   begin
      if not Ready or else Step < 1 or else Step > Real.Points then
         return 0;
      end if;
      if Real.Passed (Step) then
         return 1;
      end if;
      return 0;
   end Real_Holds;

   function Flawed_End_Length return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Flawed_End_Last;
   end Flawed_End_Length;

   function Flawed_End_Byte (Index : Integer) return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Byte_At (Flawed_End, Flawed_End_Last, Index);
   end Flawed_End_Byte;

   function Real_End_Length return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Real_End_Last;
   end Real_End_Length;

   function Real_End_Byte (Index : Integer) return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Byte_At (Real_End, Real_End_Last, Index);
   end Real_End_Byte;

end AI_Amplifier.Reward.Demo;
