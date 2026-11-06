package body AI_Amplifier.Recurse.Demo
  with SPARK_Mode => Off
is

   Name_Text : String (1 .. Max_Name) := (others => ' ');
   Name_Len  : Natural := 0;
   Stop_Text : String (1 .. Max_Name) := (others => ' ');
   Stop_Len  : Natural := 0;
   Note_Text : String (1 .. Max_Note) := (others => ' ');
   Note_Len  : Natural := 0;
   Lines     : array (1 .. Max_Shown) of String (1 .. Max_Line) :=
     (others => (others => ' '));
   Line_Len  : array (1 .. Max_Shown) of Natural := (others => 0);
   Shown     : Replay;

   procedure Clear is
   begin
      Name_Len := 0;
      Stop_Len := 0;
      Note_Len := 0;
      Line_Len := (others => 0);
      Shown :=
        (Stop => Bad_Parse,
         Stop_At => 0,
         Accepted => 0,
         Answer => 0,
         Count => 0,
         Item => (others => <>));
   end Clear;

   procedure Select_Chain (Index : Integer) is
      Which : Natural;
      OK    : Boolean;
      Last  : Natural;
   begin
      if Index < 1 or else Index > Recorded then
         return;
      end if;
      Which := Natural (Index);
      Clear;
      Chain_Name (Which, Name_Text, Name_Len);
      Replay_Recorded (Which, Shown, OK);
      if not OK then
         Note_Len := 0;
         return;
      end if;
      Kind_Word (Shown.Stop, Stop_Text, Stop_Len);
      Describe (Shown, Note_Text, Note_Len);
      for S in 1 .. Shown.Count loop
         Step_Line (Shown, S, Lines (S), Last);
         Line_Len (S) := Last;
      end loop;
   end Select_Chain;

   function Chain_Count return Integer is (Recorded);

   function Max_Index return Integer is (Recurse.Max_Index);

   function Name_Length return Integer is (Name_Len);

   function Name_Byte (Index : Integer) return Integer is
   begin
      if Index < 1 or else Index > Name_Len then
         return 0;
      end if;
      return Character'Pos (Name_Text (Index));
   end Name_Byte;

   function State_Count return Integer is (Shown.Count);

   function Live (Index : Integer) return Boolean is
     (Index >= 1 and then Index <= Shown.Count);

   function Line_Length (Index : Integer) return Integer is
   begin
      if not Live (Index) then
         return 0;
      end if;
      return Line_Len (Index);
   end Line_Length;

   function Line_Byte (Index, Pos : Integer) return Integer is
   begin
      if not Live (Index) then
         return 0;
      end if;
      if Pos < 1 or else Pos > Line_Len (Index) then
         return 0;
      end if;
      return Character'Pos (Lines (Index) (Pos));
   end Line_Byte;

   function Mark (Index : Integer) return Integer is
   begin
      if not Live (Index) then
         return 0;
      end if;
      return Shown.Item (Index).Mark;
   end Mark;

   function Parsed (Index : Integer) return Integer is
   begin
      if not Live (Index) or else not Shown.Item (Index).Parsed then
         return 0;
      end if;
      return 1;
   end Parsed;

   function State_Index (Index : Integer) return Integer is
   begin
      if not Live (Index) or else not Shown.Item (Index).Parsed then
         return 0;
      end if;
      return Shown.Item (Index).Fib_Index;
   end State_Index;

   function State_Minus (Index : Integer) return Integer is
   begin
      if not Live (Index) or else not Shown.Item (Index).Parsed then
         return 0;
      end if;
      return Shown.Item (Index).Minus_One;
   end State_Minus;

   function State_Current (Index : Integer) return Integer is
   begin
      if not Live (Index) or else not Shown.Item (Index).Parsed then
         return 0;
      end if;
      return Shown.Item (Index).Curr_Value;
   end State_Current;

   function Stop_Kind return Integer is (Stop_Code (Shown.Stop));

   function Stop_Length return Integer is (Stop_Len);

   function Stop_Byte (Index : Integer) return Integer is
   begin
      if Index < 1 or else Index > Stop_Len then
         return 0;
      end if;
      return Character'Pos (Stop_Text (Index));
   end Stop_Byte;

   function Stop_At return Integer is (Shown.Stop_At);

   function Accepted_Steps return Integer is (Shown.Accepted);

   function Answer return Integer is (Shown.Answer);

   function Note_Length return Integer is (Note_Len);

   function Note_Byte (Index : Integer) return Integer is
   begin
      if Index < 1 or else Index > Note_Len then
         return 0;
      end if;
      return Character'Pos (Note_Text (Index));
   end Note_Byte;

begin
   --  The native binder runs this. The wasm link has no binder,
   --  so the page calls Select_Chain before it reads a chain.
   Select_Chain (1);
end AI_Amplifier.Recurse.Demo;
