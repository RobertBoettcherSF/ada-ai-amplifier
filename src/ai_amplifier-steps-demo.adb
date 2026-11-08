package body AI_Amplifier.Steps.Demo
  with SPARK_Mode => Off
is

   Bank   : array (1 .. AI_Amplifier.Steps.Solution_Count) of Report;
   Ready  : Boolean := False;
   Chosen : Natural := Showcase;
   Stat   : String (1 .. Max_Note) := (others => ' ');
   Stat_Last : Natural := 0;
   Rule   : String (1 .. Max_Note) := (others => ' ');
   Rule_Last : Natural := 0;
   Ans      : array (1 .. AI_Amplifier.Steps.Solution_Count)
     of String (1 .. 8) := (others => (others => ' '));
   Ans_Last : array (1 .. AI_Amplifier.Steps.Solution_Count) of Natural :=
     (others => 0);
   Stp      : array (1 .. AI_Amplifier.Steps.Solution_Count)
     of String (1 .. 8) := (others => (others => ' '));
   Stp_Last : array (1 .. AI_Amplifier.Steps.Solution_Count) of Natural :=
     (others => 0);

   function Byte_At (Text : String; Last, Index : Integer) return Integer is
   begin
      if Index < 1 or else Index > Last or else Index > Text'Length then
         return 0;
      end if;
      return Character'Pos (Text (Text'First + Index - 1));
   end Byte_At;

   function Live (Index : Integer) return Boolean is
     (Ready
      and then Index >= 1
      and then Index <= AI_Amplifier.Steps.Solution_Count);

   procedure Run is
      Word  : String (1 .. 8);
      WLast : Natural;
   begin
      Ready := False;
      Stat_Last := 0;
      Rule_Last := 0;
      Ans_Last := (others => 0);
      Stp_Last := (others => 0);
      for I in 1 .. AI_Amplifier.Steps.Solution_Count loop
         Grade_Built_In (I, Bank (I));
         Mark_Word (Bank (I).Answer_Grade, Word, WLast);
         if WLast >= 1 and then WLast <= Ans (I)'Length then
            Ans (I) (1 .. WLast) := Word (1 .. WLast);
            Ans_Last (I) := WLast;
         end if;
         Mark_Word (Bank (I).Step_Grade, Word, WLast);
         if WLast >= 1 and then WLast <= Stp (I)'Length then
            Stp (I) (1 .. WLast) := Word (1 .. WLast);
            Stp_Last (I) := WLast;
         end if;
      end loop;
      Stat_Line (Stat, Stat_Last);
      if Chosen < 1 or else Chosen > Solution_Count then
         Chosen := Showcase;
      end if;
      Rule_Word (Bank (Chosen).Rule, Rule, Rule_Last);
      if Stat_Last > 0 and then Bank (1).Name_Last > 0 then
         Ready := True;
      end if;
   end Run;

   function Solution_Count return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return AI_Amplifier.Steps.Solution_Count;
   end Solution_Count;

   function Name_Length (Index : Integer) return Integer is
   begin
      if not Live (Index) then
         return 0;
      end if;
      return Bank (Index).Name_Last;
   end Name_Length;

   function Name_Byte (Index, Pos : Integer) return Integer is
   begin
      if not Live (Index) then
         return 0;
      end if;
      return Byte_At (Bank (Index).Name, Bank (Index).Name_Last, Pos);
   end Name_Byte;

   function Answer_Length (Index : Integer) return Integer is
   begin
      if not Live (Index) then
         return 0;
      end if;
      return Ans_Last (Index);
   end Answer_Length;

   function Answer_Byte (Index, Pos : Integer) return Integer is
   begin
      if not Live (Index) then
         return 0;
      end if;
      return Byte_At (Ans (Index), Ans_Last (Index), Pos);
   end Answer_Byte;

   function Steps_Length (Index : Integer) return Integer is
   begin
      if not Live (Index) then
         return 0;
      end if;
      return Stp_Last (Index);
   end Steps_Length;

   function Steps_Byte (Index, Pos : Integer) return Integer is
   begin
      if not Live (Index) then
         return 0;
      end if;
      return Byte_At (Stp (Index), Stp_Last (Index), Pos);
   end Steps_Byte;

   procedure Select_One (Index : Integer) is
   begin
      if not Ready
        or else Index < 1
        or else Index > AI_Amplifier.Steps.Solution_Count
      then
         return;
      end if;
      Chosen := Index;
      Rule_Word (Bank (Chosen).Rule, Rule, Rule_Last);
   end Select_One;

   function Which return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Chosen;
   end Which;

   function Row_Count return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Bank (Chosen).Count;
   end Row_Count;

   function Row_Length (Index : Integer) return Integer is
   begin
      if not Ready
        or else Index < 1
        or else Index > Bank (Chosen).Count
      then
         return 0;
      end if;
      return Bank (Chosen).Item (Index).Last;
   end Row_Length;

   function Row_Byte (Index, Pos : Integer) return Integer is
   begin
      if not Ready
        or else Index < 1
        or else Index > Bank (Chosen).Count
      then
         return 0;
      end if;
      return Byte_At
        (Bank (Chosen).Item (Index).Text,
         Bank (Chosen).Item (Index).Last,
         Pos);
   end Row_Byte;

   function Bad_At return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Bank (Chosen).Bad_At;
   end Bad_At;

   function Rule_Length return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Rule_Last;
   end Rule_Length;

   function Rule_Byte (Index : Integer) return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Byte_At (Rule, Rule_Last, Index);
   end Rule_Byte;

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

end AI_Amplifier.Steps.Demo;
