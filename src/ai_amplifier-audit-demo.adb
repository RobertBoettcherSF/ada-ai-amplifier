package body AI_Amplifier.Audit.Demo
  with SPARK_Mode => Off
is

   Bank : Set;
   Ready : Boolean := False;
   Lines : array (1 .. Max_Tasks) of String (1 .. Max_Line) :=
     (others => (others => ' '));
   Line_Last : array (1 .. Max_Tasks) of Natural := (others => 0);
   Stat      : String (1 .. Max_Line) := (others => ' ');
   Stat_Last : Natural := 0;
   Full      : String (1 .. Max_Line) := (others => ' ');
   Full_Last : Natural := 0;
   Clean     : String (1 .. Max_Line) := (others => ' ');
   Clean_Last : Natural := 0;

   function Byte_At (Text : String; Last, Index : Integer) return Integer is
   begin
      if Index < 1 or else Index > Last or else Index > Text'Length then
         return 0;
      end if;
      return Character'Pos (Text (Text'First + Index - 1));
   end Byte_At;

   procedure Put
     (Dest : in out String;
      Last : in out Natural;
      Item : String;
      OK   : in out Boolean)
   is
   begin
      if not OK or else Item'Length = 0 then
         return;
      end if;
      if Last > Dest'Last or else Item'Length > Dest'Last - Last then
         OK := False;
         return;
      end if;
      Dest (Last + 1 .. Last + Item'Length) := Item;
      Last := Last + Item'Length;
   end Put;

   procedure Put_Natural
     (Dest  : in out String;
      Last  : in out Natural;
      Value : Natural;
      OK    : in out Boolean)
   is
      Digs : String (1 .. 12) := (others => '0');
      N    : Natural := Value;
      Top  : Natural := Digs'Last + 1;
   begin
      if not OK then
         return;
      end if;
      loop
         Top := Top - 1;
         Digs (Top) :=
           Character'Val (Character'Pos ('0') + N mod 10);
         N := N / 10;
         exit when N = 0;
      end loop;
      Put (Dest, Last, Digs (Top .. Digs'Last), OK);
   end Put_Natural;

   procedure Run is
      OK   : Boolean;
      Note : String (1 .. Max_Note);
      NLast : Natural;
      Fit  : Boolean := True;
   begin
      Line_Last := (others => 0);
      Stat_Last := 0;
      Full_Last := 0;
      Clean_Last := 0;
      Ready := False;
      Load_Benchmark (Bank, OK, Note, NLast);
      if not OK then
         Stat_Last := 0;
         Put (Stat, Stat_Last, "The task file did not load.", Fit);
         return;
      end if;
      Examine (Bank);
      for I in 1 .. Bank.Count loop
         Line_For (Bank, I, Lines (I), Line_Last (I));
      end loop;
      Score_Line (Bank, False, Full, Full_Last);
      Score_Line (Bank, True, Clean, Clean_Last);
      Fit := True;
      Put_Natural (Stat, Stat_Last, Bank.Count, Fit);
      Put (Stat, Stat_Last, " tasks. ", Fit);
      Put_Natural (Stat, Stat_Last, Flagged (Bank), Fit);
      Put (Stat, Stat_Last, " flagged before scoring.", Fit);
      if Fit then
         Ready := True;
      else
         Stat_Last := 0;
      end if;
   end Run;

   function Task_Count return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Integer (Bank.Count);
   end Task_Count;

   function Flagged_Count return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Integer (Flagged (Bank));
   end Flagged_Count;

   function Mark (Index : Integer) return Integer is
   begin
      if not Ready or else Index < 1 or else Index > Integer (Bank.Count) then
         return 0;
      end if;
      if Bank.Slot (Index).Flag_Count > 0 then
         return 1;
      end if;
      return 0;
   end Mark;

   function Line_Length (Index : Integer) return Integer is
   begin
      if not Ready or else Index < 1 or else Index > Integer (Bank.Count) then
         return 0;
      end if;
      return Integer (Line_Last (Index));
   end Line_Length;

   function Line_Byte (Index, Pos : Integer) return Integer is
   begin
      if not Ready or else Index < 1 or else Index > Integer (Bank.Count) then
         return 0;
      end if;
      return Byte_At (Lines (Index), Line_Last (Index), Pos);
   end Line_Byte;

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

   function Full_Length return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Full_Last;
   end Full_Length;

   function Full_Byte (Index : Integer) return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Byte_At (Full, Full_Last, Index);
   end Full_Byte;

   function Clean_Length return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Clean_Last;
   end Clean_Length;

   function Clean_Byte (Index : Integer) return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Byte_At (Clean, Clean_Last, Index);
   end Clean_Byte;

end AI_Amplifier.Audit.Demo;
