with Ada.Command_Line;
with Ada.Text_IO;
with AI_Amplifier.Audit;
with AI_Amplifier.Recheck;
with AI_Amplifier.Steps;
with AI_Amplifier.Traces;

--  Run every recorded case from items 11, 12, and 15 through
--  the original checker and through AI_Amplifier.Recheck.
--  A disagreement in the verdict, the reason, or the first
--  bad step is a failed line. The line names the case and
--  both answers.
procedure Recheck_Test
  with SPARK_Mode => Off
is
   package T renames AI_Amplifier.Traces;
   package A renames AI_Amplifier.Audit;
   package S renames AI_Amplifier.Steps;
   package C renames AI_Amplifier.Recheck;

   Failures : Natural := 0;
   Agree_11 : Natural := 0;
   Total_11 : Natural := 0;
   Agree_12 : Natural := 0;
   Total_12 : Natural := 0;
   Agree_15 : Natural := 0;
   Total_15 : Natural := 0;

   function Same (Left, Right : String) return Boolean is
   begin
      if Left'Length /= Right'Length then
         return False;
      end if;
      for I in Left'Range loop
         if Left (I) /= Right (Right'First + (I - Left'First)) then
            return False;
         end if;
      end loop;
      return True;
   end Same;

   procedure Add
     (Dest : in out String;
      Last : in out Natural;
      Item : String)
   is
   begin
      for C of Item loop
         if Last < Dest'Last then
            Last := Last + 1;
            Dest (Last) := C;
         end if;
      end loop;
   end Add;

   procedure Add_Nat
     (Dest  : in out String;
      Last  : in out Natural;
      Value : Natural)
   is
      Digs : String (1 .. 12) := (others => '0');
      N    : Natural := Value;
      Top  : Natural := Digs'Last + 1;
   begin
      loop
         Top := Top - 1;
         Digs (Top) := Character'Val (Character'Pos ('0') + N mod 10);
         N := N / 10;
         exit when N = 0;
      end loop;
      Add (Dest, Last, Digs (Top .. Digs'Last));
   end Add_Nat;

   procedure Answer_Line
     (Verdict, Reason : String;
      Bad             : Natural;
      Answer          : String;
      Text            : out String;
      Last            : out Natural)
   is
   begin
      Text := (others => ' ');
      Last := 0;
      Add (Text, Last, "verdict ");
      Add (Text, Last, Verdict);
      Add (Text, Last, " reason ");
      Add (Text, Last, Reason);
      Add (Text, Last, " bad ");
      Add_Nat (Text, Last, Bad);
      if Answer'Length > 0 then
         Add (Text, Last, " answer ");
         Add (Text, Last, Answer);
      end if;
   end Answer_Line;

   procedure Check
     (Item, Side : String;
      Left, Right : String;
      Agree, Total : in out Natural)
   is
   begin
      Total := Total + 1;
      if Same (Left, Right) then
         Agree := Agree + 1;
         return;
      end if;
      Failures := Failures + 1;
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "disagree " & Item);
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Side & " " & Left);
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "recheck " & Right);
   end Check;

   procedure Traces is
      Name : String (1 .. T.Max_Name);
      N_Last : Natural;
      V : T.Verdict_Kind;
      R : T.Reason_Kind;
      Before, After : Float;
      Was_X, Now_X, OK : Boolean;
      Word, Why : String (1 .. 32);
      W_Last, H_Last : Natural;
      CV, CR : String (1 .. 32);
      CV_Last, CR_Last : Natural;
      Bad : Natural;
      C_OK : Boolean;
      Left, Right : String (1 .. 160);
      L_Last, R_Last : Natural;
      Id : String (1 .. 64);
      Id_Last : Natural;
   begin
      for Index in 1 .. T.Trace_Count loop
         T.Trace_Name (Index, Name, N_Last);
         for Code in 0 .. T.Menu_Count loop
            T.Judge
              (Index, Code, V, R, Before, After, Was_X, Now_X, OK);
            T.Verdict_Word (V, Word, W_Last);
            T.Reason_Word (R, Why, H_Last);
            Answer_Line
              (Word (1 .. W_Last), Why (1 .. H_Last), 0, "", Left, L_Last);
            C.Judge_Trace
              (Index, Code, CV, CV_Last, CR, CR_Last, Bad, C_OK);
            Answer_Line
              (CV (1 .. CV_Last), CR (1 .. CR_Last), Bad, "", Right, R_Last);
            Id := (others => ' ');
            Id_Last := 0;
            Add (Id, Id_Last, "11/");
            if N_Last > 0 then
               Add (Id, Id_Last, Name (1 .. N_Last));
            end if;
            Add (Id, Id_Last, "/");
            Add_Nat (Id, Id_Last, Code);
            Check
              (Id (1 .. Id_Last), "traces",
               Left (1 .. L_Last), Right (1 .. R_Last),
               Agree_11, Total_11);
         end loop;
      end loop;
   end Traces;

   procedure Audits is
      Bank : A.Set;
      OK : Boolean;
      Note : String (1 .. A.Max_Note);
      Note_Last : Natural;
      Id : String (1 .. A.Max_Id);
      Id_Last : Natural;
      Rule : String (1 .. 32);
      Rule_Last : Natural;
      CV, CR : String (1 .. 80);
      CV_Last, CR_Last : Natural;
      Bad : Natural;
      C_OK : Boolean;
      Left, Right : String (1 .. 160);
      L_Last, R_Last : Natural;
      Case_Id : String (1 .. 48);
      Case_Last : Natural;
      Hits, Total : Natural;
      Accepted : Boolean;
      Line : String (1 .. A.Max_Line);
      Line_Last : Natural;
   begin
      A.Load_Benchmark (Bank, OK, Note, Note_Last);
      if not OK then
         Check ("12/load", "audit", "verdict fail", "verdict pass",
                Agree_12, Total_12);
         return;
      end if;
      A.Examine (Bank);
      for I in 1 .. Bank.Count loop
         Case_Id := (others => ' ');
         Case_Last := 0;
         Add (Case_Id, Case_Last, "12/");
         Add
           (Case_Id, Case_Last,
            Bank.Slot (I).Id (1 .. Bank.Slot (I).Id_Last));
         Left := (others => ' ');
         L_Last := 0;
         Add (Left, L_Last, "verdict ");
         if Bank.Slot (I).Flag_Count = 0 then
            Add (Left, L_Last, "pass reason none");
         else
            Add (Left, L_Last, "flag reason ");
            A.Rule_Word (Bank.Slot (I).Flags (1), Rule, Rule_Last);
            if Rule_Last > 0 then
               Add (Left, L_Last, Rule (1 .. Rule_Last));
            end if;
         end if;
         Add (Left, L_Last, " bad 0");
         C.Judge_Task (I, CV, CV_Last, CR, CR_Last, Bad, C_OK);
         Answer_Line
           (CV (1 .. CV_Last), CR (1 .. CR_Last), Bad, "", Right, R_Last);
         C.Task_Id (I, Id, Id_Last);
         if not C_OK
           or else Id_Last /= Bank.Slot (I).Id_Last
           or else not Same
             (Id (1 .. Id_Last),
              Bank.Slot (I).Id (1 .. Bank.Slot (I).Id_Last))
         then
            Check
              (Case_Id (1 .. Case_Last), "audit",
               "id " & Bank.Slot (I).Id (1 .. Bank.Slot (I).Id_Last),
               "id " & Id (1 .. Id_Last),
               Agree_12, Total_12);
         else
            Check
              (Case_Id (1 .. Case_Last), "audit",
               Left (1 .. L_Last), Right (1 .. R_Last),
               Agree_12, Total_12);
         end if;
      end loop;
      for Drop in Boolean loop
         A.Score (Bank, Drop, Hits, Total, Accepted);
         A.Score_Line (Bank, Drop, Line, Line_Last);
         Left := (others => ' ');
         L_Last := 0;
         Add (Left, L_Last, "verdict ");
         if Accepted then
            Add (Left, L_Last, "accepted");
         else
            Add (Left, L_Last, "not-accepted");
         end if;
         Add (Left, L_Last, " reason ");
         if Line_Last > 0 then
            Add (Left, L_Last, Line (1 .. Line_Last));
         end if;
         Add (Left, L_Last, " bad 0");
         C.Judge_Score (Drop, CV, CV_Last, CR, CR_Last, Bad, C_OK);
         Answer_Line
           (CV (1 .. CV_Last), CR (1 .. CR_Last), Bad, "", Right, R_Last);
         Case_Id := (others => ' ');
         Case_Last := 0;
         if Drop then
            Add (Case_Id, Case_Last, "12/cleaned");
         else
            Add (Case_Id, Case_Last, "12/full");
         end if;
         Check
           (Case_Id (1 .. Case_Last), "audit",
            Left (1 .. L_Last), Right (1 .. R_Last),
            Agree_12, Total_12);
      end loop;
   end Audits;

   procedure Solutions is
      Buf : String (1 .. S.Max_Text);
      Last : Natural;
      Item : S.Report;
      V_Word, R_Word, A_Word : String (1 .. 24);
      VW, RW, AW : Natural;
      CV, CR, CA : String (1 .. 32);
      CV_Last, CR_Last, CA_Last : Natural;
      Bad : Natural;
      Left, Right : String (1 .. 160);
      L_Last, R_Last : Natural;
      Case_Id : String (1 .. 40);
      Case_Last : Natural;
   begin
      for I in 1 .. S.Solution_Count loop
         S.Built_In (I, Buf, Last);
         if Last < 1 then
            S.Grade ("", Item);
         else
            S.Grade (Buf (1 .. Last), Item);
         end if;
         S.Mark_Word (Item.Step_Grade, V_Word, VW);
         S.Rule_Word (Item.Rule, R_Word, RW);
         S.Mark_Word (Item.Answer_Grade, A_Word, AW);
         Answer_Line
           (V_Word (1 .. VW), R_Word (1 .. RW), Item.Bad_At,
            A_Word (1 .. AW), Left, L_Last);
         if Last < 1 then
            C.Grade_Text ("", CV, CV_Last, CR, CR_Last, Bad, CA, CA_Last);
         else
            C.Grade_Text
              (Buf (1 .. Last), CV, CV_Last, CR, CR_Last, Bad, CA, CA_Last);
         end if;
         Answer_Line
           (CV (1 .. CV_Last), CR (1 .. CR_Last), Bad,
            CA (1 .. CA_Last), Right, R_Last);
         Case_Id := (others => ' ');
         Case_Last := 0;
         Add (Case_Id, Case_Last, "15/");
         if Item.Name_Last > 0 then
            Add (Case_Id, Case_Last, Item.Name (1 .. Item.Name_Last));
         end if;
         Check
           (Case_Id (1 .. Case_Last), "steps",
            Left (1 .. L_Last), Right (1 .. R_Last),
            Agree_15, Total_15);
      end loop;
   end Solutions;

   procedure Write_Report (Path : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line
        (File, "pair 11" & Agree_11'Image & Total_11'Image);
      Ada.Text_IO.Put_Line
        (File, "pair 12" & Agree_12'Image & Total_12'Image);
      Ada.Text_IO.Put_Line
        (File, "pair 15" & Agree_15'Image & Total_15'Image);
      Ada.Text_IO.Close (File);
   end Write_Report;

begin
   Traces;
   Audits;
   Solutions;
   if Ada.Command_Line.Argument_Count >= 1 then
      Write_Report (Ada.Command_Line.Argument (1));
   end if;
   if Failures /= 0 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "recheck disagreements" & Failures'Image);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;
   Ada.Text_IO.Put_Line ("recheck ok");
end Recheck_Test;
