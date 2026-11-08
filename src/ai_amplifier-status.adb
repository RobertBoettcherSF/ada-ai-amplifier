with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Text_IO;

package body AI_Amplifier.Status
  with SPARK_Mode => Off
is

   Max_Units : constant := 16;
   Name_Max  : constant := 48;
   Line_Max  : constant := 400;
   Ev_Max    : constant := 800;
   Item_Last : constant := 17;

   type Name_Text is record
      Text : String (1 .. Name_Max) := (others => ' ');
      Last : Natural := 0;
   end record;

   type Unit_Rec is record
      Used      : Boolean := False;
      Nam       : Name_Text;
      Analyzed  : Natural := 0;
      Total     : Natural := 0;
      Checks    : Natural := 0;
      Saw_Proof : Boolean := False;
      Saw_Bad   : Boolean := False;
   end record;

   type Test_Id is
     (T_Version, T_Tensors, T_Mlp, T_Attention, T_Recurse,
      T_Traces, T_Audit, T_Reward, T_Harness, T_Steps,
      T_Recheck, T_Locked);

   type Test_Rec is record
      OK        : Boolean := False;
      Cases     : Natural := 0;
      Has_Cases : Boolean := False;
   end record;

   type Ev is record
      Text : String (1 .. Ev_Max) := (others => ' ');
      Last : Natural := 0;
   end record;

   type Unit_List is array (1 .. Max_Units) of Unit_Rec;

   type Proof_Rec is record
      Present  : Boolean := False;
      Total    : Natural := 0;
      Flow     : Natural := 0;
      Provers  : Natural := 0;
      Unproved : Natural := 0;
      Seen     : Boolean := False;
      Bad      : Boolean := False;
      Units    : Unit_List;
      NUnits   : Natural := 0;
   end record;

   Proofs : array (1 .. Item_Last) of Proof_Rec;
   Tests  : array (Test_Id) of Test_Rec;
   Passed : array (1 .. 17) of Boolean := (others => False);
   Asserts : array (1 .. 17) of Natural := (others => 0);
   Pair_A : array (1 .. 3) of Natural := (others => 0);
   Pair_T : array (1 .. 3) of Natural := (others => 0);
   Pair_On : array (1 .. 3) of Boolean := (others => False);
   Files_Ok : Boolean := False;
   Why      : Ev;

   function Trim (N : Natural) return String is
      Img : constant String := Natural'Image (N);
   begin
      return Img (Img'First + 1 .. Img'Last);
   end Trim;

   function Word (S : String; Index : Positive) return String is
      N     : Natural := 0;
      I     : Natural := S'First;
      Start : Natural;
   begin
      while I <= S'Last loop
         while I <= S'Last and then S (I) = ' ' loop
            I := I + 1;
         end loop;
         exit when I > S'Last;
         N := N + 1;
         Start := I;
         while I <= S'Last and then S (I) /= ' ' loop
            I := I + 1;
         end loop;
         if N = Index then
            return S (Start .. I - 1);
         end if;
      end loop;
      return "";
   end Word;

   function To_Nat (S : String) return Natural is
   begin
      if S'Length = 0 then
         return 0;
      end if;
      return Natural'Value (S);
   exception
      when Constraint_Error =>
         return 0;
   end To_Nat;

   function Starts (S, Prefix : String) return Boolean is
     (S'Length >= Prefix'Length
      and then S (S'First .. S'First + Prefix'Length - 1) = Prefix);

   procedure Clear (E : in out Ev) is
   begin
      E.Last := 0;
   end Clear;

   procedure Add (E : in out Ev; S : String) is
   begin
      if S'Length = 0 then
         return;
      end if;
      if E.Last + S'Length > E.Text'Last then
         return;
      end if;
      E.Text (E.Last + 1 .. E.Last + S'Length) := S;
      E.Last := E.Last + S'Length;
   end Add;

   procedure Add_Nat (E : in out Ev; N : Natural) is
   begin
      Add (E, Trim (N));
   end Add_Nat;

   procedure Set_Name (Into : in out Name_Text; S : String) is
   begin
      Into.Last := 0;
      if S'Length = 0 then
         return;
      end if;
      Into.Last := Natural'Min (S'Length, Name_Max);
      Into.Text (1 .. Into.Last) := S (S'First .. S'First + Into.Last - 1);
   end Set_Name;

   function Name_Is (Item : Name_Text; S : String) return Boolean is
     (Item.Last = S'Length
      and then Item.Text (1 .. Item.Last) = S);

   function Find (Item : Positive; Nam : String) return Natural is
   begin
      for I in 1 .. Proofs (Item).NUnits loop
         if Name_Is (Proofs (Item).Units (I).Nam, Nam) then
            return I;
         end if;
      end loop;
      return 0;
   end Find;

   function Unit_Proved (Item : Positive; Nam : String) return Boolean is
      I : constant Natural := Find (Item, Nam);
   begin
      if I = 0 then
         return False;
      end if;
      return Proofs (Item).Units (I).Saw_Proof
        and then not Proofs (Item).Units (I).Saw_Bad
        and then Proofs (Item).Units (I).Analyzed > 0
        and then Proofs (Item).Units (I).Analyzed =
          Proofs (Item).Units (I).Total
        and then Proofs (Item).Units (I).Checks > 0;
   end Unit_Proved;

   function Own_Proof (Item : Positive; Nam : String) return Boolean is
     (Proofs (Item).Present
      and then Proofs (Item).Seen
      and then Proofs (Item).Unproved = 0
      and then Proofs (Item).Total > 0
      and then not Proofs (Item).Bad
      and then Unit_Proved (Item, Nam));

   procedure Add_Unit (E : in out Ev; Item : Positive; Nam : String) is
      I : constant Natural := Find (Item, Nam);
   begin
      Add (E, Nam);
      Add (E, " ");
      if I = 0 then
         Add (E, "missing");
         return;
      end if;
      Add_Nat (E, Proofs (Item).Units (I).Analyzed);
      Add (E, "/");
      Add_Nat (E, Proofs (Item).Units (I).Total);
      Add (E, " checks ");
      Add_Nat (E, Proofs (Item).Units (I).Checks);
   end Add_Unit;

   procedure Read_Line
     (File : in out Ada.Text_IO.File_Type;
      Buf  : out String;
      Last : out Natural)
   is
      C : Character;
   begin
      Last := 0;
      Buf := (others => ' ');
      if Ada.Text_IO.End_Of_File (File) then
         return;
      end if;
      while not Ada.Text_IO.End_Of_Line (File) loop
         Ada.Text_IO.Get (File, C);
         if Last < Buf'Last then
            Last := Last + 1;
            Buf (Last) := C;
         end if;
      end loop;
      if not Ada.Text_IO.End_Of_File (File) then
         Ada.Text_IO.Skip_Line (File);
      end if;
   end Read_Line;

   function Slice (Buf : String; Last : Natural) return String is
      F : Natural := 1;
      L : Natural := Last;
   begin
      while F <= L and then (Buf (F) = ' ' or else Buf (F) = ASCII.CR) loop
         F := F + 1;
      end loop;
      while L >= F and then (Buf (L) = ' ' or else Buf (L) = ASCII.CR) loop
         L := L - 1;
      end loop;
      if F > L then
         return "";
      end if;
      return Buf (F .. L);
   end Slice;

   function Nth_Int (Line : String; Index : Positive) return Natural is
      Seen : Natural := 0;
      I    : Natural := Line'First;
      S    : Natural;
   begin
      while I <= Line'Last loop
         while I <= Line'Last
           and then (Line (I) < '0' or else Line (I) > '9')
         loop
            I := I + 1;
         end loop;
         exit when I > Line'Last;
         S := I;
         while I <= Line'Last
           and then Line (I) >= '0' and then Line (I) <= '9'
         loop
            I := I + 1;
         end loop;
         Seen := Seen + 1;
         if Seen = Index then
            return To_Nat (Line (S .. I - 1));
         end if;
      end loop;
      return 0;
   end Nth_Int;

   function Int_Count (Line : String) return Natural is
      Seen : Natural := 0;
      I    : Natural := Line'First;
   begin
      while I <= Line'Last loop
         while I <= Line'Last
           and then (Line (I) < '0' or else Line (I) > '9')
         loop
            I := I + 1;
         end loop;
         exit when I > Line'Last;
         Seen := Seen + 1;
         while I <= Line'Last
           and then Line (I) >= '0' and then Line (I) <= '9'
         loop
            I := I + 1;
         end loop;
      end loop;
      return Seen;
   end Int_Count;

   procedure Parse_Proved (Line : String; Checks : in out Natural) is
      Mark : constant String := "and proved (";
      Pos  : constant Natural :=
        Ada.Strings.Fixed.Index (Line, Mark);
      Rest : Natural;
   begin
      if Pos = 0 then
         return;
      end if;
      Rest := Pos + Mark'Length;
      Checks := Checks + Nth_Int (Line (Rest .. Line'Last), 1);
   end Parse_Proved;

   procedure Read_Prove (Item : Positive; Path : String) is
      File : Ada.Text_IO.File_Type;
      Buf  : String (1 .. Line_Max);
      Last : Natural;
      Line : String (1 .. Line_Max);
      LLast : Natural;
      Cur  : Natural := 0;
   begin
      Proofs (Item).Present := True;
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Read_Line (File, Buf, Last);
         declare
            Raw : constant String := Slice (Buf, Last);
         begin
            LLast := Raw'Length;
            if LLast > 0 then
               Line (1 .. LLast) := Raw;
            end if;
            if LLast = 0 then
               null;
            elsif Starts (Line (1 .. LLast), "Total")
              and then Int_Count (Line (1 .. LLast)) >= 4
            then
               Proofs (Item).Total := Nth_Int (Line (1 .. LLast), 1);
               Proofs (Item).Flow := Nth_Int (Line (1 .. LLast), 2);
               Proofs (Item).Provers := Nth_Int (Line (1 .. LLast), 4);
               if Int_Count (Line (1 .. LLast)) >= 6 then
                  Proofs (Item).Unproved := Nth_Int (Line (1 .. LLast), 6);
               else
                  Proofs (Item).Unproved := 0;
               end if;
               Proofs (Item).Seen := True;
            elsif LLast > 8
              and then Starts (Line (1 .. LLast), "in unit ")
            then
               declare
                  Rest  : constant String := Line (9 .. LLast);
                  Comma : constant Natural :=
                    Ada.Strings.Fixed.Index (Rest, ",");
                  NLast : Natural := 0;
               begin
                  if Comma > Rest'First
                    and then Proofs (Item).NUnits < Max_Units
                  then
                     NLast := Natural'Min
                       (Comma - Rest'First, Name_Max);
                     Proofs (Item).NUnits := Proofs (Item).NUnits + 1;
                     Cur := Proofs (Item).NUnits;
                     Proofs (Item).Units (Cur).Used := True;
                     Set_Name
                       (Proofs (Item).Units (Cur).Nam,
                        Rest (Rest'First .. Rest'First + NLast - 1));
                     Proofs (Item).Units (Cur).Analyzed := Nth_Int (Rest, 1);
                     Proofs (Item).Units (Cur).Total := Nth_Int (Rest, 2);
                  else
                     Cur := 0;
                  end if;
               end;
            elsif Cur /= 0 then
               if Ada.Strings.Fixed.Index
                 (Line (1 .. LLast), "and proved (") > 0
               then
                  Proofs (Item).Units (Cur).Saw_Proof := True;
                  Parse_Proved
                    (Line (1 .. LLast), Proofs (Item).Units (Cur).Checks);
               end if;
               if Ada.Strings.Fixed.Index
                 (Line (1 .. LLast), "unproved") > 0
               then
                  Proofs (Item).Units (Cur).Saw_Bad := True;
                  Proofs (Item).Bad := True;
               end if;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);
   end Read_Prove;

   function Test_Of_Ok (Line : String) return Test_Id is
   begin
      if Line = "check-version ok" then
         return T_Version;
      elsif Line = "tensors ok" then
         return T_Tensors;
      elsif Line = "mlp ok" then
         return T_Mlp;
      elsif Line = "attention ok" then
         return T_Attention;
      elsif Line = "recurse ok" then
         return T_Recurse;
      elsif Line = "traces ok" then
         return T_Traces;
      elsif Line = "audit ok" then
         return T_Audit;
      elsif Line = "reward ok" then
         return T_Reward;
      elsif Line = "harness ok" then
         return T_Harness;
      elsif Line = "steps ok" then
         return T_Steps;
      elsif Line = "recheck ok" then
         return T_Recheck;
      else
         return T_Locked;
      end if;
   end Test_Of_Ok;

   function Known_Ok (Line : String) return Boolean is
     (Line = "check-version ok" or else Line = "tensors ok"
      or else Line = "mlp ok" or else Line = "attention ok"
      or else Line = "recurse ok" or else Line = "traces ok"
      or else Line = "audit ok" or else Line = "reward ok"
      or else Line = "harness ok" or else Line = "steps ok"
      or else Line = "recheck ok" or else Line = "locked ok");

   function Test_Of_Cases (Token : String) return Test_Id is
   begin
      if Token = "tensors_test" then
         return T_Tensors;
      elsif Token = "mlp_test" then
         return T_Mlp;
      elsif Token = "attention_test" then
         return T_Attention;
      elsif Token = "recurse_test" then
         return T_Recurse;
      elsif Token = "traces_test" then
         return T_Traces;
      elsif Token = "audit_test" then
         return T_Audit;
      elsif Token = "reward_test" then
         return T_Reward;
      elsif Token = "harness_test" then
         return T_Harness;
      elsif Token = "steps_test" then
         return T_Steps;
      elsif Token = "recheck_test" then
         return T_Recheck;
      else
         return T_Version;
      end if;
   end Test_Of_Cases;

   procedure Read_Tests (Path : String) is
      File : Ada.Text_IO.File_Type;
      Buf  : String (1 .. Line_Max);
      Last : Natural;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Read_Line (File, Buf, Last);
         declare
            Line : constant String := Slice (Buf, Last);
         begin
            if Line = "locked ok" then
               Tests (T_Locked).OK := True;
            elsif Known_Ok (Line) then
               Tests (Test_Of_Ok (Line)).OK := True;
            elsif Starts (Line, "cases ") then
               declare
                  Token : constant String := Word (Line, 2);
                  Count : constant Natural := To_Nat (Word (Line, 3));
                  Id    : Test_Id;
               begin
                  if Token'Length > 0
                    and then Token /= "check-version"
                  then
                     Id := Test_Of_Cases (Token);
                     if Token = "tensors_test"
                       or else Token = "mlp_test"
                       or else Token = "attention_test"
                       or else Token = "recurse_test"
                       or else Token = "traces_test"
                       or else Token = "audit_test"
                       or else Token = "reward_test"
                       or else Token = "harness_test"
                       or else Token = "steps_test"
                       or else Token = "recheck_test"
                     then
                        Tests (Id).Cases := Count;
                        Tests (Id).Has_Cases := True;
                     end if;
                  end if;
               end;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);
   end Read_Tests;

   procedure Read_Specs (Path : String) is
      File : Ada.Text_IO.File_Type;
      Buf  : String (1 .. Line_Max);
      Last : Natural;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Read_Line (File, Buf, Last);
         declare
            Line : constant String := Slice (Buf, Last);
            Num  : Natural;
         begin
            if Starts (Line, "item ") and then Word (Line, 3) = "pass" then
               Num := To_Nat (Word (Line, 2));
               if Num in 1 .. 17 then
                  Passed (Num) := True;
               end if;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);
   end Read_Specs;

   procedure Read_Recheck (Path : String) is
      File : Ada.Text_IO.File_Type;
      Buf  : String (1 .. Line_Max);
      Last : Natural;
      Slot : Natural := 0;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Read_Line (File, Buf, Last);
         declare
            Line : constant String := Slice (Buf, Last);
         begin
            if Word (Line, 1) = "pair" and then Slot < 3 then
               Slot := Slot + 1;
               Pair_A (Slot) := To_Nat (Word (Line, 3));
               Pair_T (Slot) := To_Nat (Word (Line, 4));
               Pair_On (Slot) := Word (Line, 2)'Length > 0;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);
   end Read_Recheck;

   function Two (N : Positive) return String is
      Digs : constant String := Trim (N);
   begin
      if N < 10 then
         return "0" & Digs;
      end if;
      return Digs;
   end Two;

   procedure Count_Asserts (Dir : String; Number : Positive) is
      Path : constant String :=
        Dir & "/item_" & Two (Number) & ".adb";
      File : Ada.Text_IO.File_Type;
      Buf  : String (1 .. Line_Max);
      Last : Natural;
   begin
      if not Ada.Directories.Exists (Path) then
         return;
      end if;
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Read_Line (File, Buf, Last);
         declare
            Line : constant String := Slice (Buf, Last);
         begin
            if Line'Length > 0
              and then not Starts (Line, "--")
              and then Ada.Strings.Fixed.Index (Line, "pragma Assert") > 0
            then
               Asserts (Number) := Asserts (Number) + 1;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);
   end Count_Asserts;

   procedure Add_Run_Head (E : in out Ev; Item : Positive) is
   begin
      Add (E, "gnatprove proof/item_");
      Add (E, Two (Item));
      Add (E, ".out summary ");
      Add_Nat (E, Proofs (Item).Total);
      Add (E, " flow ");
      Add_Nat (E, Proofs (Item).Flow);
      Add (E, " provers ");
      Add_Nat (E, Proofs (Item).Provers);
      Add (E, " unproved ");
      Add_Nat (E, Proofs (Item).Unproved);
      Add (E, "; unit ");
   end Add_Run_Head;

   procedure Add_Why (E : in out Ev; Reason : String) is
   begin
      Add (E, "; not proved: ");
      Add (E, Reason);
   end Add_Why;

   function Run_Ok (Id : Test_Id) return Boolean is
     (Tests (Id).OK
      and then Tests (Id).Has_Cases
      and then Tests (Id).Cases > 0);

   procedure Add_Run (E : in out Ev; Token : String; Id : Test_Id) is
   begin
      Add (E, Token);
      Add (E, " cases ");
      Add_Nat (E, Tests (Id).Cases);
   end Add_Run;

   procedure Add_Spec (E : in out Ev; Number : Positive) is
   begin
      Add (E, "spec item_");
      Add (E, Two (Number));
      if Passed (Number) then
         Add (E, " pass asserts ");
         Add_Nat (E, Asserts (Number));
      else
         Add (E, " did not pass");
      end if;
   end Add_Spec;

   function Spec_Ok (Number : Positive) return Boolean is
     (Passed (Number) and then Asserts (Number) > 0);

   procedure Add_Ask (E : in out Ev; Which : Positive) is
   begin
      Add (E, "; live-ask unchecked: ");
      if Which = 9 then
         Add (E, "recurse_cli --ask");
         Add (E, " needs RECURSE_LLM_URL, RECURSE_LLM_KEY,");
         Add (E, " and RECURSE_LLM_MODEL");
      elsif Which = 11 then
         Add (E, "traces_cli --ask");
         Add (E, " needs TRACES_LLM_URL, TRACES_LLM_KEY,");
         Add (E, " and TRACES_LLM_MODEL");
      else
         Add (E, "harness_cli --ask");
         Add (E, " needs HARNESS_LLM_URL, HARNESS_LLM_KEY,");
         Add (E, " and HARNESS_LLM_MODEL");
      end if;
      Add (E, "; CI does not call a live model");
   end Add_Ask;

   function Agree_Ok return Boolean is
     (Pair_On (1) and then Pair_On (2) and then Pair_On (3)
      and then Pair_A (1) = Pair_T (1) and then Pair_T (1) > 0
      and then Pair_A (2) = Pair_T (2) and then Pair_T (2) > 0
      and then Pair_A (3) = Pair_T (3) and then Pair_T (3) > 0);

   procedure Add_Agree (E : in out Ev) is
   begin
      Add (E, "recheck_test agree ");
      Add_Nat (E, Pair_A (1));
      Add (E, " of ");
      Add_Nat (E, Pair_T (1));
      Add (E, ", ");
      Add_Nat (E, Pair_A (2));
      Add (E, " of ");
      Add_Nat (E, Pair_T (2));
      Add (E, ", ");
      Add_Nat (E, Pair_A (3));
      Add (E, " of ");
      Add_Nat (E, Pair_T (3));
   end Add_Agree;

   function Locked_Specs_Ok return Boolean is
   begin
      for I in 1 .. Item_Last loop
         if not Spec_Ok (I) then
            return False;
         end if;
      end loop;
      return True;
   end Locked_Specs_Ok;

   function Locked_Spec_Count return Natural is
      N : Natural := 0;
   begin
      for I in 1 .. Item_Last loop
         if Passed (I) then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Locked_Spec_Count;

   procedure Classify (Number : Positive; K : out Kind; E : in out Ev) is
   begin
      Clear (E);
      K := Unchecked;
      if not Files_Ok then
         Add (E, Why.Text (1 .. Why.Last));
         return;
      end if;
      case Number is
         when 1 =>
            if Own_Proof (1, "ai_amplifier-version")
              and then Spec_Ok (1)
              and then Tests (T_Version).OK
            then
               K := Proved;
               Add_Run_Head (E, 1);
               Add_Unit (E, 1, "ai_amplifier-version");
               Add (E, "; ");
               Add_Spec (E, 1);
               Add (E, "; check-version ok");
            else
               Add (E, "would take proof/item_01.out proving");
               Add (E, " ai_amplifier-version with checks above 0");
               Add (E, " and unproved 0");
            end if;
         when 3 =>
            if Own_Proof (3, "ai_amplifier-tensors") and then Spec_Ok (3) then
               K := Proved;
               Add_Run_Head (E, 3);
               Add_Unit (E, 3, "ai_amplifier-tensors");
               Add (E, "; not in this run:");
               Add (E, " ai_amplifier-tensors-demo,");
               Add (E, " ai_amplifier-tensors-leaky_demo; ");
               Add_Spec (E, 3);
            else
               Add (E, "would take proof/item_03.out proving");
               Add (E, " ai_amplifier-tensors with checks above 0");
               Add (E, " and unproved 0");
            end if;
         when 7 =>
            if Own_Proof (7, "ai_amplifier-tensors") and then Spec_Ok (7) then
               K := Proved;
               Add_Run_Head (E, 7);
               Add_Unit (E, 7, "ai_amplifier-tensors");
               Add (E, "; ");
               Add_Spec (E, 7);
            else
               Add (E, "would take proof/item_07.out proving");
               Add (E, " ai_amplifier-tensors with checks above 0");
               Add (E, " and unproved 0");
            end if;
         when 2 =>
            if Spec_Ok (2) then
               K := Tested;
               Add (E, "item_02 cases ");
               Add_Nat (E, Asserts (2));
               Add (E, " spec pass");
               Add_Why (E, "the splash is a drawing");
               Add (E, " and is not a proof target");
            else
               Add (E, "would take item_02 printing");
               Add (E, " item 02 pass");
            end if;
         when 4 =>
            if Run_Ok (T_Mlp) and then Spec_Ok (4) then
               K := Tested;
               Add_Run (E, "mlp_test", T_Mlp);
               Add (E, " ");
               Add_Spec (E, 4);
               Add_Why (E, "gradient descent on float weights");
               Add (E, " is not a proof target");
            else
               Add (E, "would take mlp_test printing mlp ok");
               Add (E, " and a positive case count,");
               Add (E, " and spec item_04 pass");
            end if;
         when 5 =>
            if Run_Ok (T_Attention) and then Spec_Ok (5) then
               K := Tested;
               Add_Run (E, "attention_test", T_Attention);
               Add (E, " ");
               Add_Spec (E, 5);
               Add_Why (E, "the tokenizer and the attention block");
               Add (E, " are not a proof target");
            else
               Add (E, "would take attention_test printing");
               Add (E, " attention ok and a positive case count,");
               Add (E, " and spec item_05 pass");
            end if;
         when 6 =>
            if Run_Ok (T_Tensors) and then Spec_Ok (6) then
               K := Tested;
               Add (E, "item_06 cases ");
               Add_Nat (E, Asserts (6));
               Add (E, " spec pass; ");
               Add_Run (E, "tensors_test", T_Tensors);
               Add_Why (E, "the how-to is a document");
               Add (E, " and the leaky demo is not analyzed");
            else
               Add (E, "would take spec item_06 pass");
               Add (E, " and tensors_test printing tensors ok");
            end if;
         when 8 =>
            if Run_Ok (T_Mlp) and then Spec_Ok (8) then
               K := Tested;
               Add_Run (E, "mlp_test", T_Mlp);
               Add (E, " ");
               Add_Spec (E, 8);
               Add_Why (E, "weight-file checks run with the program");
               Add (E, " and are not proved");
            else
               Add (E, "would take mlp_test printing mlp ok");
               Add (E, " and spec item_08 pass");
            end if;
         when 9 =>
            if Own_Proof (9, "ai_amplifier-chain_rule")
              and then Run_Ok (T_Recurse)
              and then Spec_Ok (9)
            then
               K := Proved;
               Add_Run_Head (E, 9);
               Add_Unit (E, 9, "ai_amplifier-chain_rule");
               Add (E, "; ");
               Add_Run (E, "recurse_test", T_Recurse);
               Add (E, " ");
               Add_Spec (E, 9);
               Add_Ask (E, 9);
            elsif Run_Ok (T_Recurse) and then Spec_Ok (9) then
               K := Tested;
               Add_Run (E, "recurse_test", T_Recurse);
               Add (E, " ");
               Add_Spec (E, 9);
               Add_Ask (E, 9);
               Add_Why (E, "the step rule proof file");
               Add (E, " is missing or unproved");
            else
               Add (E, "would take recurse_test printing");
               Add (E, " recurse ok and spec item_09 pass.");
               Add (E, " A live model still needs a key");
            end if;
         when 10 =>
            if Run_Ok (T_Mlp) and then Spec_Ok (10) then
               K := Tested;
               Add_Run (E, "mlp_test", T_Mlp);
               Add (E, " ");
               Add_Spec (E, 10);
               Add_Why (E, "a measured training time is not a proof");
            else
               Add (E, "would take mlp_test printing mlp ok");
               Add (E, " and spec item_10 pass");
            end if;
         when 11 =>
            if Own_Proof (11, "ai_amplifier-trace_rule")
              and then Run_Ok (T_Traces)
              and then Spec_Ok (11)
            then
               K := Proved;
               Add_Run_Head (E, 11);
               Add_Unit (E, 11, "ai_amplifier-trace_rule");
               Add (E, "; ");
               Add_Run (E, "traces_test", T_Traces);
               Add (E, " ");
               Add_Spec (E, 11);
               Add_Ask (E, 11);
            elsif Run_Ok (T_Traces) and then Spec_Ok (11) then
               K := Tested;
               Add_Run (E, "traces_test", T_Traces);
               Add (E, " ");
               Add_Spec (E, 11);
               Add_Ask (E, 11);
               Add_Why (E, "the verdict rule proof file");
               Add (E, " is missing or unproved");
            else
               Add (E, "would take traces_test printing");
               Add (E, " traces ok and spec item_11 pass.");
               Add (E, " A live model still needs a key");
            end if;
         when 12 =>
            if Own_Proof (12, "ai_amplifier-audit_rule")
              and then Run_Ok (T_Audit)
              and then Spec_Ok (12)
            then
               K := Proved;
               Add_Run_Head (E, 12);
               Add_Unit (E, 12, "ai_amplifier-audit_rule");
               Add (E, "; ");
               Add_Run (E, "audit_test", T_Audit);
               Add (E, " ");
               Add_Spec (E, 12);
            elsif Run_Ok (T_Audit) and then Spec_Ok (12) then
               K := Tested;
               Add_Run (E, "audit_test", T_Audit);
               Add (E, " ");
               Add_Spec (E, 12);
               Add_Why (E, "the score rule proof file");
               Add (E, " is missing or unproved");
            else
               Add (E, "would take audit_test printing audit ok");
               Add (E, " and spec item_12 pass");
            end if;
         when 13 =>
            if Run_Ok (T_Reward) and then Spec_Ok (13) then
               K := Tested;
               Add_Run (E, "reward_test", T_Reward);
               Add (E, " ");
               Add_Spec (E, 13);
               Add_Why (E, "the two graders score float nets");
               Add (E, " and are not proved");
            else
               Add (E, "would take reward_test printing reward ok");
               Add (E, " and spec item_13 pass");
            end if;
         when 14 =>
            if Run_Ok (T_Harness) and then Spec_Ok (14) then
               K := Tested;
               Add_Run (E, "harness_test", T_Harness);
               Add (E, " ");
               Add_Spec (E, 14);
               Add_Ask (E, 14);
               Add_Why (E, "the harness schedule is not a proof target");
            else
               Add (E, "would take harness_test printing");
               Add (E, " harness ok and spec item_14 pass.");
               Add (E, " A live model still needs a key");
            end if;
         when 15 =>
            if Run_Ok (T_Steps) and then Spec_Ok (15) then
               K := Tested;
               Add_Run (E, "steps_test", T_Steps);
               Add (E, " ");
               Add_Spec (E, 15);
               Add_Why (E, "a step grade recomputes values");
               Add (E, " and is not a proof");
            else
               Add (E, "would take steps_test printing steps ok");
               Add (E, " and spec item_15 pass");
            end if;
         when 16 =>
            if Tests (T_Locked).OK
              and then Locked_Specs_Ok
              and then Spec_Ok (16)
            then
               K := Tested;
               Add (E, "check-locked cases ");
               Add_Nat (E, Locked_Spec_Count);
               Add (E, " ");
               Add_Spec (E, 16);
               Add_Why (E, "a fingerprint detects an edit");
               Add (E, " and does not prove the spec");
            else
               Add (E, "would take check-locked printing");
               Add (E, " locked ok, and specs item_01");
               Add (E, " through item_17 passing");
            end if;
         when 17 =>
            if Tests (T_Recheck).OK and then Agree_Ok and then Spec_Ok (17)
            then
               K := Tested;
               Add_Agree (E);
               Add (E, " ");
               Add_Spec (E, 17);
               Add_Why
                 (E, "agreement of two checkers is not a proof of either");
            else
               Add (E, "would take recheck_test printing");
               Add (E, " recheck ok, the three pairs agreeing,");
               Add (E, " and spec item_17 pass");
            end if;
         when others =>
            Add (E, "would take an item in 1 .. 17");
      end case;
   end Classify;

   procedure Reset is
   begin
      Proofs := (others => <>);
      Tests := (others => <>);
      Passed := (others => False);
      Asserts := (others => 0);
      Pair_A := (others => 0);
      Pair_T := (others => 0);
      Pair_On := (others => False);
      Files_Ok := False;
      Clear (Why);
   end Reset;

   function Open_Ok (Path : String) return Boolean is
     (Ada.Directories.Exists (Path));

   procedure Load
     (Prove_Dir    : String;
      Tests_Path   : String;
      Specs_Path   : String;
      Recheck_Path : String;
      Spec_Dir     : String)
   is
   begin
      Reset;
      if not Ada.Directories.Exists (Prove_Dir) then
         Add (Why, "would take ");
         Add (Why, Prove_Dir);
         return;
      end if;
      if not Open_Ok (Tests_Path) then
         Add (Why, "would take ");
         Add (Why, Tests_Path);
         return;
      end if;
      if not Open_Ok (Specs_Path) then
         Add (Why, "would take ");
         Add (Why, Specs_Path);
         return;
      end if;
      if not Open_Ok (Recheck_Path) then
         Add (Why, "would take ");
         Add (Why, Recheck_Path);
         return;
      end if;
      if not Ada.Directories.Exists (Spec_Dir) then
         Add (Why, "would take ");
         Add (Why, Spec_Dir);
         return;
      end if;
      for N in 1 .. Item_Last loop
         declare
            Path : constant String :=
              Prove_Dir & "/item_" & Two (N) & ".out";
         begin
            if Open_Ok (Path) then
               Read_Prove (N, Path);
            end if;
         end;
      end loop;
      Read_Tests (Tests_Path);
      Read_Specs (Specs_Path);
      Read_Recheck (Recheck_Path);
      for N in 1 .. Item_Last loop
         Count_Asserts (Spec_Dir, N);
      end loop;
      Files_Ok := True;
   end Load;

   function Ready return Boolean is (Files_Ok);

   function Item_Label (Number : Positive) return Kind is
      K : Kind;
      E : Ev;
   begin
      if Number not in 1 .. 17 then
         return Unchecked;
      end if;
      Classify (Number, K, E);
      return K;
   end Item_Label;

   function Item_Evidence (Number : Positive) return String is
      K : Kind;
      E : Ev;
   begin
      if Number not in 1 .. 17 then
         return "would take an item in 1 .. 17";
      end if;
      Classify (Number, K, E);
      if E.Last = 0 then
         return "";
      end if;
      return E.Text (1 .. E.Last);
   end Item_Evidence;

   function Kind_Word (K : Kind) return String is
   begin
      case K is
         when Proved =>
            return "proved";
         when Tested =>
            return "tested";
         when Unchecked =>
            return "unchecked";
      end case;
   end Kind_Word;

   function Summary return String is
      P, T, U : Natural := 0;
   begin
      for N in 1 .. 17 loop
         case Item_Label (N) is
            when Proved =>
               P := P + 1;
            when Tested =>
               T := T + 1;
            when Unchecked =>
               U := U + 1;
         end case;
      end loop;
      return "proved " & Trim (P) & " of 17, tested "
        & Trim (T) & ", unchecked " & Trim (U);
   end Summary;

   procedure Put_Report is
   begin
      for N in 1 .. 17 loop
         Ada.Text_IO.Put ("item ");
         Ada.Text_IO.Put (Two (N));
         Ada.Text_IO.Put (" ");
         Ada.Text_IO.Put (Kind_Word (Item_Label (N)));
         Ada.Text_IO.Put (" ");
         Ada.Text_IO.Put_Line (Item_Evidence (N));
      end loop;
      Ada.Text_IO.Put ("summary ");
      Ada.Text_IO.Put_Line (Summary);
   end Put_Report;

end AI_Amplifier.Status;
