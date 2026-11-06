package body AI_Amplifier.Traces.Demo
  with SPARK_Mode => Off
is

   Selected   : Natural := 0;
   Shown      : Natural := 0;
   Wrong      : Natural := 0;
   Name_Text  : String (1 .. Max_Name) := (others => ' ');
   Name_Len   : Natural := 0;
   Lines      : array (1 .. Max_Steps) of String (1 .. Max_Line) :=
     (others => (others => ' '));
   Line_Len   : array (1 .. Max_Steps) of Natural := (others => 0);
   State_Text : String (1 .. Max_Note) := (others => ' ');
   State_Len  : Natural := 0;
   Good_Text  : String (1 .. Max_Note) := (others => ' ');
   Good_Len   : Natural := 0;
   Report     : String (1 .. Max_Note) := (others => ' ');
   Report_Len : Natural := 0;
   Reason_Text : String (1 .. Max_Name) := (others => ' ');
   Reason_Len  : Natural := 0;
   Verdict_Now : Integer := 0;
   Reason_Now  : Integer := 0;

   function Byte_At (Text : String; Last, Index : Integer) return Integer is
   begin
      if Index < 1 or else Index > Last or else Index > Text'Length then
         return 0;
      end if;
      return Character'Pos (Text (Text'First + Index - 1));
   end Byte_At;

   procedure Select_Trace (Index : Integer) is
      Which : Proposal;
      OK    : Boolean;
      Code  : Integer;
   begin
      if Index < 1 or else Index > Traces.Trace_Count then
         return;
      end if;
      Selected := Natural (Index);
      Shown := Step_Count (Selected);
      Wrong := Wrong_At (Selected);
      Trace_Name (Selected, Name_Text, Name_Len);
      Line_Len := (others => 0);
      for S in 1 .. Shown loop
         Step_Line (Selected, S, Lines (S), Line_Len (S));
      end loop;
      State_Line (Selected, State_Text, State_Len);
      Known_Good (Selected, Which, OK);
      if OK then
         Code := Proposal_Code (Which);
         Report_Line (Selected, Code, Good_Text, Good_Len);
      else
         Good_Len := 0;
      end if;
      Report_Len := 0;
      Reason_Len := 0;
      Verdict_Now := 0;
      Reason_Now := 0;
   end Select_Trace;

   procedure Propose (Code : Integer) is
      Kind   : Verdict_Kind;
      Why    : Reason_Kind;
      Before : Float;
      After  : Float;
      Was_X  : Boolean;
      Now_X  : Boolean;
      OK     : Boolean;
   begin
      if Selected < 1 then
         Verdict_Now := Verdict_Code (No_Better);
         Reason_Now := Reason_Code (Not_A_Step);
         Reason_Word (Not_A_Step, Reason_Text, Reason_Len);
         Report_Len := 0;
         return;
      end if;
      Judge
        (Selected, Code, Kind, Why, Before, After, Was_X, Now_X, OK);
      if not OK then
         Verdict_Now := 0;
         Reason_Now := 0;
         return;
      end if;
      Verdict_Now := Verdict_Code (Kind);
      Reason_Now := Reason_Code (Why);
      Reason_Word (Why, Reason_Text, Reason_Len);
      Report_Line (Selected, Code, Report, Report_Len);
   end Propose;

   function Trace_Count return Integer is (Traces.Trace_Count);

   function Name_Length return Integer is (Name_Len);

   function Name_Byte (Index : Integer) return Integer is
     (Byte_At (Name_Text, Name_Len, Index));

   function Step_Count return Integer is (Shown);

   function Line_Length (Index : Integer) return Integer is
   begin
      if Index < 1 or else Index > Shown then
         return 0;
      end if;
      return Line_Len (Index);
   end Line_Length;

   function Line_Byte (Index, Pos : Integer) return Integer is
   begin
      if Index < 1 or else Index > Shown then
         return 0;
      end if;
      return Byte_At (Lines (Index), Line_Len (Index), Pos);
   end Line_Byte;

   function Wrong_Mark (Index : Integer) return Integer is
   begin
      if Index >= 1 and then Index = Wrong and then Index <= Shown then
         return 1;
      end if;
      return 0;
   end Wrong_Mark;

   function Menu_Count return Integer is (Traces.Menu_Count);

   function Menu_Length (Code : Integer) return Integer is
      Which : Proposal;
      OK    : Boolean;
      Text  : String (1 .. Max_Line);
      Last  : Natural;
   begin
      Proposal_From_Code (Code, Which, OK);
      if not OK then
         return 0;
      end if;
      Proposal_Label (Which, Text, Last);
      return Last;
   end Menu_Length;

   function Menu_Byte (Code, Pos : Integer) return Integer is
      Which : Proposal;
      OK    : Boolean;
      Text  : String (1 .. Max_Line);
      Last  : Natural;
   begin
      Proposal_From_Code (Code, Which, OK);
      if not OK then
         return 0;
      end if;
      Proposal_Label (Which, Text, Last);
      return Byte_At (Text, Last, Pos);
   end Menu_Byte;

   function Verdict return Integer is (Verdict_Now);

   function Reason return Integer is (Reason_Now);

   function Reason_Length return Integer is (Reason_Len);

   function Reason_Byte (Index : Integer) return Integer is
     (Byte_At (Reason_Text, Reason_Len, Index));

   function Report_Length return Integer is (Report_Len);

   function Report_Byte (Index : Integer) return Integer is
     (Byte_At (Report, Report_Len, Index));

   function Good_Length return Integer is (Good_Len);

   function Good_Byte (Index : Integer) return Integer is
     (Byte_At (Good_Text, Good_Len, Index));

   function State_Length return Integer is (State_Len);

   function State_Byte (Index : Integer) return Integer is
     (Byte_At (State_Text, State_Len, Index));

end AI_Amplifier.Traces.Demo;
