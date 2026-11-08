with AI_Amplifier.Summary_Rules;

package body AI_Amplifier.Summary.Demo
  with SPARK_Mode => Off
is

   package Parent renames AI_Amplifier.Summary;

   Ready : Boolean := False;
   Chosen : Natural := Showcase;

   Names : array (1 .. Problem_Count) of String (1 .. Max_Name) :=
     (others => (others => ' '));
   Name_Last : array (1 .. Problem_Count) of Natural := (others => 0);
   Flags : array (1 .. Problem_Count) of String (1 .. Max_Name) :=
     (others => (others => ' '));
   Flag_Last : array (1 .. Problem_Count) of Natural := (others => 0);

   Max_Sent : constant := Summary_Rules.Max_Claims;
   Max_Steps : constant := Summary_Rules.Max_Steps;

   Sents : array (1 .. Problem_Count, 1 .. Max_Sent)
     of String (1 .. Max_Line) :=
     (others => (others => (others => ' ')));
   Sent_Last : array (1 .. Problem_Count, 1 .. Max_Sent) of Natural :=
     (others => (others => 0));
   Sent_Mark : array (1 .. Problem_Count, 1 .. Max_Sent) of Natural :=
     (others => (others => 0));
   Sent_N : array (1 .. Problem_Count) of Natural := (others => 0);

   Steps_Text : array (1 .. Problem_Count, 1 .. Max_Steps)
     of String (1 .. Max_Line) :=
     (others => (others => (others => ' ')));
   Step_Last : array (1 .. Problem_Count, 1 .. Max_Steps) of Natural :=
     (others => (others => 0));
   Step_Code : array (1 .. Problem_Count, 1 .. Max_Steps) of Natural :=
     (others => (others => 0));
   Step_N : array (1 .. Problem_Count) of Natural := (others => 0);

   Stat : String (1 .. Max_Line) := (others => ' ');
   Stat_Last : Natural := 0;

   function Byte_At (Text : String; Last, Index : Integer) return Integer is
   begin
      if Index < 1 or else Index > Last or else Index > Text'Length then
         return 0;
      end if;
      return Character'Pos (Text (Text'First + Index - 1));
   end Byte_At;

   function Live (Index : Integer) return Boolean is
     (Ready and then Index >= 1 and then Index <= Problem_Count);

   procedure Run is
      Buf  : String (1 .. Max_Line);
      Last : Natural;
   begin
      Ready := False;
      Parent.Load;
      if not Parent.Ready then
         return;
      end if;
      for I in 1 .. Problem_Count loop
         Parent.Problem_Name (I, Buf, Last);
         Names (I) := (others => ' ');
         Name_Last (I) := 0;
         if Last >= 1 and then Last <= Max_Name then
            Names (I) (1 .. Last) := Buf (1 .. Last);
            Name_Last (I) := Last;
         end if;
         Parent.Flag_Word (I, Buf, Last);
         Flags (I) := (others => ' ');
         Flag_Last (I) := 0;
         if Last >= 1 and then Last <= Max_Name then
            Flags (I) (1 .. Last) := Buf (1 .. Last);
            Flag_Last (I) := Last;
         end if;
         Sent_N (I) := Parent.Sentence_Count (I);
         for J in 1 .. Max_Sent loop
            Sents (I, J) := (others => ' ');
            Sent_Last (I, J) := 0;
            Sent_Mark (I, J) := 0;
            if J <= Sent_N (I) then
               Parent.Sentence (I, J, Buf, Last);
               if Last >= 1 and then Last <= Max_Line then
                  Sents (I, J) (1 .. Last) := Buf (1 .. Last);
                  Sent_Last (I, J) := Last;
               end if;
               Sent_Mark (I, J) := Parent.Sentence_Mark (I, J);
            end if;
         end loop;
         Step_N (I) := Parent.Step_Count (I);
         for J in 1 .. Max_Steps loop
            Steps_Text (I, J) := (others => ' ');
            Step_Last (I, J) := 0;
            Step_Code (I, J) := 0;
            if J <= Step_N (I) then
               Parent.Step_Line (I, J, Buf, Last);
               if Last >= 1 and then Last <= Max_Line then
                  Steps_Text (I, J) (1 .. Last) := Buf (1 .. Last);
                  Step_Last (I, J) := Last;
               end if;
               case Parent.Step_Kind (I, J) is
                  when Summary_Rules.Correct =>
                     Step_Code (I, J) := 0;
                  when Summary_Rules.Wrong =>
                     Step_Code (I, J) := 1;
                  when Summary_Rules.Unchecked =>
                     Step_Code (I, J) := 2;
               end case;
            end if;
         end loop;
      end loop;
      Parent.Stat_Line (Stat, Stat_Last);
      if Chosen < 1 or else Chosen > Problem_Count then
         Chosen := Showcase;
      end if;
      if Name_Last (1) > 0 and then Stat_Last > 0 then
         Ready := True;
      end if;
   end Run;

   function Count return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Problem_Count;
   end Count;

   procedure Select_One (Index : Integer) is
   begin
      if not Ready then
         return;
      end if;
      if Index >= 1 and then Index <= Problem_Count then
         Chosen := Index;
      end if;
   end Select_One;

   function Which return Integer is
   begin
      if not Ready then
         return 0;
      end if;
      return Chosen;
   end Which;

   function Name_Length (Index : Integer) return Integer is
   begin
      if not Live (Index) then
         return 0;
      end if;
      return Name_Last (Index);
   end Name_Length;

   function Name_Byte (Index, Pos : Integer) return Integer is
   begin
      if not Live (Index) then
         return 0;
      end if;
      return Byte_At (Names (Index), Name_Last (Index), Pos);
   end Name_Byte;

   function Flag_Length (Index : Integer) return Integer is
   begin
      if not Live (Index) then
         return 0;
      end if;
      return Flag_Last (Index);
   end Flag_Length;

   function Flag_Byte (Index, Pos : Integer) return Integer is
   begin
      if not Live (Index) then
         return 0;
      end if;
      return Byte_At (Flags (Index), Flag_Last (Index), Pos);
   end Flag_Byte;

   function Sentence_Count (Index : Integer) return Integer is
   begin
      if not Live (Index) then
         return 0;
      end if;
      return Sent_N (Index);
   end Sentence_Count;

   function Sentence_Length (Index, Which : Integer) return Integer is
   begin
      if not Live (Index) or else Which < 1 or else Which > Sent_N (Index) then
         return 0;
      end if;
      return Sent_Last (Index, Which);
   end Sentence_Length;

   function Sentence_Byte (Index, Which, Pos : Integer) return Integer is
   begin
      if not Live (Index) or else Which < 1 or else Which > Sent_N (Index) then
         return 0;
      end if;
      return Byte_At (Sents (Index, Which), Sent_Last (Index, Which), Pos);
   end Sentence_Byte;

   function Sentence_Mark (Index, Which : Integer) return Integer is
   begin
      if not Live (Index) or else Which < 1 or else Which > Sent_N (Index) then
         return 0;
      end if;
      return Sent_Mark (Index, Which);
   end Sentence_Mark;

   function Step_Count (Index : Integer) return Integer is
   begin
      if not Live (Index) then
         return 0;
      end if;
      return Step_N (Index);
   end Step_Count;

   function Step_Length (Index, Which : Integer) return Integer is
   begin
      if not Live (Index) or else Which < 1 or else Which > Step_N (Index) then
         return 0;
      end if;
      return Step_Last (Index, Which);
   end Step_Length;

   function Step_Byte (Index, Which, Pos : Integer) return Integer is
   begin
      if not Live (Index) or else Which < 1 or else Which > Step_N (Index) then
         return 0;
      end if;
      return Byte_At
        (Steps_Text (Index, Which), Step_Last (Index, Which), Pos);
   end Step_Byte;

   function Step_Mark (Index, Which : Integer) return Integer is
   begin
      if not Live (Index) or else Which < 1 or else Which > Step_N (Index) then
         return 0;
      end if;
      return Step_Code (Index, Which);
   end Step_Mark;

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

end AI_Amplifier.Summary.Demo;
