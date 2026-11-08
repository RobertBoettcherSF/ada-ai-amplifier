with AI_Amplifier.MLP;

package body AI_Amplifier.Recheck
  with SPARK_Mode => Off
is

   package M renames AI_Amplifier.MLP;
   use type M.Load_Status;

   LF : constant Character := Character'Val (10);

   --  The reason word for a step that brings XOR back. The
   --  comparison self-test edits this one constant.
   Fix_Reason : constant String := "xor-returned";

   Tol       : constant Float := 0.000_05;
   Fib_Limit : constant := 12;
   Max_Value : constant := 20_000;
   Loss_Max  : constant Float := 0.05;
   High_Min  : constant Float := 0.8;
   Low_Max   : constant Float := 0.2;
   Loss_Eps  : constant Float := 0.000_1;
   Or_W      : constant Float := 6.0;
   Or_B      : constant Float := -3.0;
   And_W     : constant Float := 6.0;
   And_B     : constant Float := -9.0;
   Out_Or    : constant Float := 6.0;
   Out_And   : constant Float := -6.0;
   Out_B     : constant Float := -6.0;
   Step_Rate : constant Float := 0.5;

   procedure Put_Word
     (Text : out String;
      Last : out Natural;
      Word : String)
   is
      N : Natural := 0;
   begin
      Text := (others => ' ');
      Last := 0;
      if Word'Length = 0 or else Word'Length > Text'Length then
         return;
      end if;
      for C of Word loop
         N := N + 1;
         Text (Text'First + N - 1) := C;
      end loop;
      Last := N;
   end Put_Word;

   procedure Add
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
      for C of Item loop
         Last := Last + 1;
         Dest (Last) := C;
      end loop;
   end Add;

   procedure Add_Nat
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
         Digs (Top) := Character'Val (Character'Pos ('0') + N mod 10);
         N := N / 10;
         exit when N = 0 or else Top = Digs'First;
      end loop;
      if N /= 0 then
         OK := False;
         return;
      end if;
      Add (Dest, Last, Digs (Top .. Digs'Last), OK);
   end Add_Nat;

   function Same
     (Text       : String;
      From, Stop : Natural;
      Key        : String) return Boolean
   is
      Pos : Natural;
   begin
      if Key'Length = 0 or else From < Text'First or else Stop < From then
         return False;
      end if;
      if Stop > Text'Last or else Stop - From /= Key'Length - 1 then
         return False;
      end if;
      for J in Key'Range loop
         Pos := From + (J - Key'First);
         if Text (Pos) /= Key (J) then
            return False;
         end if;
      end loop;
      return True;
   end Same;

   function Same_All (Left, Right : String) return Boolean is
   begin
      if Left'Length = 0 then
         return Right'Length = 0;
      end if;
      return Same (Left, Left'First, Left'Last, Right);
   end Same_All;

   function Blank
     (Text       : String;
      From, Stop : Natural) return Boolean
   is
   begin
      if Stop < From then
         return True;
      end if;
      if From < Text'First or else Stop > Text'Last then
         return False;
      end if;
      for I in From .. Stop loop
         if Text (I) /= ' ' and then Text (I) /= Character'Val (9) then
            return False;
         end if;
      end loop;
      return True;
   end Blank;

   procedure Skip_Space
     (Text       : String;
      From, Stop : Natural;
      Next       : out Natural)
   is
      I : Natural := From;
   begin
      if From < Text'First then
         Next := From;
         return;
      end if;
      while I <= Stop and then I <= Text'Last
        and then (Text (I) = ' ' or else Text (I) = Character'Val (9))
      loop
         I := I + 1;
      end loop;
      Next := I;
   end Skip_Space;

   procedure Take_Word
     (Text           : String;
      From, Stop     : Natural;
      Word_A, Word_B : out Natural;
      Next           : out Natural)
   is
      I : Natural;
   begin
      Skip_Space (Text, From, Stop, I);
      Word_A := I;
      while I <= Stop and then I <= Text'Last
        and then Text (I) /= ' ' and then Text (I) /= Character'Val (9)
      loop
         I := I + 1;
      end loop;
      Word_B := I - 1;
      Next := I;
   end Take_Word;

   function Close (Left, Right : Float) return Boolean is
     (abs (Left - Right) <= Tol);

   function Exp_F (X : Float) return Float is
      Ln2  : constant Long_Float := 0.693_147_180_559_945_3;
      Z    : Long_Float := Long_Float (X);
      N    : Integer;
      R    : Long_Float;
      Term : Long_Float;
      Sum  : Long_Float;
   begin
      if X < -40.0 then
         return 0.0;
      end if;
      if Z > 40.0 then
         Z := 40.0;
      end if;
      if Z >= 0.0 then
         N := Integer (Z / Ln2 + 0.5);
      else
         N := Integer (Z / Ln2 - 0.5);
      end if;
      R := Z - Long_Float (N) * Ln2;
      Term := 1.0;
      Sum := 1.0;
      for K in 1 .. 18 loop
         Term := Term * R / Long_Float (K);
         Sum := Sum + Term;
      end loop;
      if N > 0 then
         for I in 1 .. N loop
            Sum := Sum * 2.0;
         end loop;
      elsif N < 0 then
         for I in 1 .. -N loop
            Sum := Sum * 0.5;
         end loop;
      end if;
      if Sum <= 0.0 then
         return 0.0;
      end if;
      return Float (Sum);
   end Exp_F;

   function Sigmoid_F (X : Float) return Float is
      E : Float;
   begin
      if X >= 20.0 then
         return 1.0;
      elsif X <= -20.0 then
         return 0.0;
      elsif X >= 0.0 then
         E := Exp_F (-X);
         return 1.0 / (1.0 + E);
      else
         E := Exp_F (X);
         return E / (1.0 + E);
      end if;
   end Sigmoid_F;

   function Tanh_F (X : Float) return Float is
   begin
      if X > 20.0 then
         return 1.0;
      elsif X < -20.0 then
         return -1.0;
      end if;
      return 2.0 * Sigmoid_F (2.0 * X) - 1.0;
   end Tanh_F;

   function Log_F (X : Float) return Float is
      Ln2  : constant Long_Float := 0.693_147_180_559_945_3;
      Y    : Long_Float;
      E    : Integer := 0;
      U    : Long_Float;
      U2   : Long_Float;
      Term : Long_Float;
      Sum  : Long_Float;
   begin
      if X <= 1.0e-6 then
         Y := 1.0e-6;
      elsif X > 1.0e6 then
         Y := 1.0e6;
      else
         Y := Long_Float (X);
      end if;
      while Y >= 2.0 and then E < 40 loop
         Y := Y * 0.5;
         E := E + 1;
      end loop;
      while Y < 1.0 and then E > -40 loop
         Y := Y * 2.0;
         E := E - 1;
      end loop;
      U := (Y - 1.0) / (Y + 1.0);
      U2 := U * U;
      Term := U;
      Sum := U;
      for K in 1 .. 14 loop
         Term := Term * U2;
         Sum := Sum + Term / Long_Float (2 * K + 1);
      end loop;
      return Float (2.0 * Sum + Long_Float (E) * Ln2);
   end Log_F;

   function Clip_P (P : Float) return Float is
   begin
      if P < 1.0e-6 then
         return 1.0e-6;
      elsif P > 1.0 - 1.0e-6 then
         return 1.0 - 1.0e-6;
      else
         return P;
      end if;
   end Clip_P;

   function Entropy (Y, Target : Float) return Float is
      P : constant Float := Clip_P (Y);
   begin
      return -(Target * Log_F (P) + (1.0 - Target) * Log_F (1.0 - P));
   end Entropy;

   type Forward is record
      H1_Logit : Float;
      H1       : Float;
      H2_Logit : Float;
      H2       : Float;
      Silent   : Float;
      Out_Log  : Float;
      Y        : Float;
   end record;

   function Forward_Of (X1, X2 : Float) return Forward is
      Z1 : constant Float := Or_W * X1 + Or_W * X2 + Or_B;
      Z2 : constant Float := And_W * X1 + And_W * X2 + And_B;
      H1 : constant Float := Tanh_F (Z1);
      H2 : constant Float := Tanh_F (Z2);
      Lg : constant Float := Out_Or * H1 + Out_And * H2 + Out_B;
   begin
      return
        (H1_Logit => Z1,
         H1       => H1,
         H2_Logit => Z2,
         H2       => H2,
         Silent   => Tanh_F (0.0),
         Out_Log  => Lg,
         Y        => Sigmoid_F (Lg));
   end Forward_Of;

   function Class_Of (Y : Float) return Integer is
   begin
      if Y >= 0.5 then
         return 1;
      end if;
      return 0;
   end Class_Of;

   type Point4 is array (1 .. 4) of Float;

   procedure Train_Numbers
     (Loss, Y00, Y01, Y10, Y11, Grad, Bias : out Float)
   is
      P    : array (1 .. 4) of Forward;
      T    : constant Point4 := (0.0, 1.0, 1.0, 0.0);
      X1   : constant Point4 := (0.0, 0.0, 1.0, 1.0);
      X2   : constant Point4 := (0.0, 1.0, 0.0, 1.0);
      Sum  : Float := 0.0;
      Dsum : Float := 0.0;
   begin
      for I in 1 .. 4 loop
         P (I) := Forward_Of (X1 (I), X2 (I));
         Sum := Sum + Entropy (P (I).Y, T (I));
         Dsum := Dsum + (P (I).Y - T (I));
      end loop;
      Loss := Sum / 4.0;
      Y00 := P (1).Y;
      Y01 := P (2).Y;
      Y10 := P (3).Y;
      Y11 := P (4).Y;
      Grad := Dsum / 4.0;
      Bias := Out_B - Step_Rate * Grad;
   end Train_Numbers;

   type State is record
      Idx   : Natural;
      Minus : Natural;
      Curr  : Natural;
   end record;

   type Chain is array (0 .. Fib_Limit) of State;

   type Step_Kind is
     (Accepted, Reached_Base, Not_Toward, Bad_Arith, Past_Base);

   function Check_Fib (Prev, Proposed : State) return Step_Kind is
      Sum : Natural;
   begin
      if Prev.Idx = 0 then
         return Past_Base;
      end if;
      if Proposed.Idx /= Prev.Idx - 1 then
         return Not_Toward;
      end if;
      if Prev.Minus > Max_Value - Prev.Curr then
         return Bad_Arith;
      end if;
      Sum := Prev.Minus + Prev.Curr;
      if Proposed.Minus /= Prev.Curr or else Proposed.Curr /= Sum then
         return Bad_Arith;
      end if;
      if Proposed.Idx = 0 then
         return Reached_Base;
      end if;
      return Accepted;
   end Check_Fib;

   procedure Build_Fib
     (Index : Natural;
      Item  : out Chain;
      OK    : out Boolean)
   is
   begin
      Item := (others => (0, 0, 0));
      OK := Index <= Fib_Limit;
      if not OK then
         return;
      end if;
      Item (0) := (Idx => Index, Minus => 0, Curr => 1);
      for K in 1 .. Index loop
         declare
            Next : constant State :=
              (Idx   => Item (K - 1).Idx - 1,
               Minus => Item (K - 1).Curr,
               Curr  => Item (K - 1).Minus + Item (K - 1).Curr);
            Want : Step_Kind;
         begin
            if K = Index then
               Want := Reached_Base;
            else
               Want := Accepted;
            end if;
            if Check_Fib (Item (K - 1), Next) /= Want then
               OK := False;
               return;
            end if;
            Item (K) := Next;
         end;
      end loop;
   end Build_Fib;

   function Fib_Value (Index : Natural) return Natural is
      Minus : Natural := 0;
      Curr  : Natural := 1;
      Next  : Natural;
   begin
      if Index = 0 then
         return 0;
      end if;
      for K in 2 .. Index loop
         Next := Minus + Curr;
         Minus := Curr;
         Curr := Next;
      end loop;
      return Curr;
   end Fib_Value;

   function Component_OK (X : Float) return Boolean is
     (X = X and then X <= M.Weight_Limit and then X >= -M.Weight_Limit);

   function Weights_OK (Model : M.Net) return Boolean is
   begin
      for R in 1 .. M.Hidden loop
         for C in 1 .. M.Inputs loop
            if not Component_OK (Model.W1.Data (R, C)) then
               return False;
            end if;
         end loop;
         if not Component_OK (Model.B1.Data (R))
           or else not Component_OK (Model.W2.Data (1, R))
         then
            return False;
         end if;
      end loop;
      return Component_OK (Model.B2.Data (1));
   end Weights_OK;

   procedure Train_N (Model : in out M.Net; Steps : Positive) is
      Data : constant M.Sample_List := M.Make_Dataset (M.XOR_Points);
      Loss : Float;
   begin
      M.Train (Model, Data, Steps, Loss);
   end Train_N;

   procedure Refuse_Shape (Model : in out M.Net) is
      Copy   : constant M.Net := Model;
      Buf    : M.Weight_Chars := (others => ' ');
      Text   : constant String :=
        "ada-ai-amplifier weights 1" & LF & "shape 2 4 1" & LF;
      Status : M.Load_Status;
      N      : Natural := 0;
   begin
      for C of Text loop
         N := N + 1;
         Buf (N) := C;
      end loop;
      M.Read_Weights (Model, Buf, N, Status);
      if Status /= M.Loaded then
         Model := Copy;
      end if;
   end Refuse_Shape;

   procedure Load_Zeros (Model : in out M.Net) is
      Blank  : M.Net := Model;
      Buf    : M.Weight_Chars := (others => ' ');
      Count  : Natural;
      Status : M.Load_Status;
   begin
      Blank.W1.Data := (others => (others => 0.0));
      Blank.B1.Data := (others => 0.0);
      Blank.W2.Data := (others => (others => 0.0));
      Blank.B2.Data := (others => 0.0);
      M.Write_Weights (Blank, Buf, Count);
      M.Read_Weights (Model, Buf, Count, Status);
   end Load_Zeros;

   procedure Silence (Model : in out M.Net) is
   begin
      Model.W2.Data (1, 2) := 0.0;
   end Silence;

   procedure Flip (Model : in out M.Net) is
   begin
      Model.W2.Data (1, 1) := -Model.W2.Data (1, 1);
   end Flip;

   procedure Invert (Model : in out M.Net) is
   begin
      for C in 1 .. M.Hidden loop
         Model.W2.Data (1, C) := -Model.W2.Data (1, C);
      end loop;
      Model.B2.Data (1) := -Model.B2.Data (1);
   end Invert;

   type Picture is record
      Model    : M.Net;
      Loss     : Float := 0.0;
      XOR_OK   : Boolean := False;
      W_OK     : Boolean := False;
      Loss_OK  : Boolean := False;
   end record;

   procedure Measure (Item : in out Picture) is
      Data : constant M.Sample_List := M.Make_Dataset (M.XOR_Points);
      Y    : Float;
   begin
      Item.W_OK := Weights_OK (Item.Model);
      Item.XOR_OK := False;
      Item.Loss_OK := False;
      Item.Loss := 0.0;
      if not Item.W_OK then
         return;
      end if;
      Item.Loss := M.Mean_Loss (Item.Model, Data);
      if Item.Loss /= Item.Loss
        or else Item.Loss > 1.0e6
        or else Item.Loss < 0.0
      then
         return;
      end if;
      Item.Loss_OK := True;
      Item.XOR_OK := True;
      for I in 1 .. Data.Count loop
         Y := M.Predict (Item.Model, Data.Item (I).X);
         if Y /= Y then
            Item.XOR_OK := False;
         elsif Data.Item (I).Label >= 0.5 then
            if Y < High_Min then
               Item.XOR_OK := False;
            end if;
         elsif Y > Low_Max then
            Item.XOR_OK := False;
         end if;
      end loop;
   end Measure;

   function Solved (Item : Picture) return Boolean is
     (Item.W_OK and then Item.Loss_OK and then Item.XOR_OK
      and then Item.Loss < Loss_Max);

   procedure Decide
     (Before, After : Picture;
      Verdict       : out String;
      V_Last        : out Natural;
      Reason        : out String;
      R_Last        : out Natural)
   is
   begin
      if not After.W_OK then
         if Before.W_OK then
            Put_Word (Verdict, V_Last, "makes-it-worse");
         else
            Put_Word (Verdict, V_Last, "no-better");
         end if;
         Put_Word (Reason, R_Last, "weights-invalid");
         return;
      end if;
      if not After.Loss_OK then
         Put_Word (Verdict, V_Last, "makes-it-worse");
         Put_Word (Reason, R_Last, "loss-rose");
         return;
      end if;
      if Solved (After) and then not Solved (Before) then
         Put_Word (Verdict, V_Last, "fixes-it");
         Put_Word (Reason, R_Last, Fix_Reason);
         return;
      end if;
      if Before.XOR_OK and then not After.XOR_OK then
         Put_Word (Verdict, V_Last, "makes-it-worse");
         Put_Word (Reason, R_Last, "xor-left");
         return;
      end if;
      if Before.Loss_OK and then After.Loss > Before.Loss + Loss_Eps then
         Put_Word (Verdict, V_Last, "makes-it-worse");
         Put_Word (Reason, R_Last, "loss-rose");
         return;
      end if;
      if not Solved (After) then
         Put_Word (Verdict, V_Last, "no-better");
         if not After.XOR_OK and then Before.Loss_OK
           and then After.Loss + Loss_Eps < Before.Loss
         then
            Put_Word (Reason, R_Last, "xor-still-missed");
         else
            Put_Word (Reason, R_Last, "loss-did-not-fall");
         end if;
         return;
      end if;
      Put_Word (Verdict, V_Last, "no-better");
      Put_Word (Reason, R_Last, "loss-did-not-fall");
   end Decide;

   procedure Replay
     (Index : Positive;
      Now   : out Picture;
      Saved : out Picture)
   is
   begin
      M.Initialize (Now.Model, M.Init_Seed, 1.0);
      Measure (Now);
      Saved := Now;
      case Index is
         when 1 =>
            M.Initialize (Now.Model, M.Init_Seed, 1.0);
            Train_N (Now.Model, 40);
            Measure (Now);
            Saved := Now;
            Now.Model.Rate := 5.0;
            Train_N (Now.Model, 15);
            Measure (Now);
         when 2 =>
            Now.Model := M.Hand_XOR;
            Measure (Now);
            Refuse_Shape (Now.Model);
            Measure (Now);
            Saved := Now;
            Load_Zeros (Now.Model);
            Measure (Now);
         when 3 =>
            Now.Model := M.Hand_XOR;
            Measure (Now);
            Saved := Now;
            Silence (Now.Model);
            Measure (Now);
         when others =>
            M.Initialize (Now.Model, M.Init_Seed, 1.0);
            Measure (Now);
            Saved := Now;
            Train_N (Now.Model, 10);
            Measure (Now);
      end case;
   end Replay;

   procedure Apply_Code
     (Code  : Integer;
      Saved : Picture;
      Work  : in out Picture;
      Known : out Boolean)
   is
   begin
      Known := True;
      case Code is
         when 1 =>
            Work.Model.Rate := 1.0;
            Train_N (Work.Model, 200);
         when 2 =>
            Work.Model.Rate := 5.0;
            Train_N (Work.Model, 10);
         when 3 =>
            Train_N (Work.Model, 200);
         when 4 =>
            Train_N (Work.Model, 8);
         when 5 =>
            Work.Model := M.Hand_XOR;
         when 6 =>
            Work.Model := Saved.Model;
         when 7 =>
            Silence (Work.Model);
         when 8 =>
            Flip (Work.Model);
         when 9 =>
            Invert (Work.Model);
         when 10 =>
            Refuse_Shape (Work.Model);
         when others =>
            Known := False;
      end case;
   end Apply_Code;

   procedure Trace_Name
     (Index : Natural;
      Text  : out String;
      Last  : out Natural)
   is
   begin
      case Index is
         when 1 =>
            Put_Word (Text, Last, "rate-diverges");
         when 2 =>
            Put_Word (Text, Last, "padded-shape");
         when 3 =>
            Put_Word (Text, Last, "silenced-and");
         when 4 =>
            Put_Word (Text, Last, "stopped-early");
         when others =>
            Put_Word (Text, Last, "");
      end case;
   end Trace_Name;

   procedure Judge_Trace
     (Index   : Natural;
      Code    : Integer;
      Verdict : out String;
      V_Last  : out Natural;
      Reason  : out String;
      R_Last  : out Natural;
      Bad     : out Natural;
      OK      : out Boolean)
   is
      Now, Saved, Work : Picture;
      Known            : Boolean;
   begin
      Bad := 0;
      Put_Word (Verdict, V_Last, "no-better");
      Put_Word (Reason, R_Last, "not-a-step");
      OK := Index in 1 .. Trace_Count;
      if not OK then
         return;
      end if;
      Replay (Index, Now, Saved);
      Work := Now;
      Apply_Code (Code, Saved, Work, Known);
      if not Known then
         return;
      end if;
      Measure (Work);
      Decide (Now, Work, Verdict, V_Last, Reason, R_Last);
   end Judge_Trace;

   Max_Id     : constant := 24;
   Max_Kind   : constant := 16;
   Max_Prompt : constant := 160;
   Max_Field  : constant := 48;
   Max_Answer : constant := 24;

   type Rule_Id is
     (No_Rule, Dup_Rule, No_Answer, Wrong_Key, Leaked, Accepts_All);

   type Task_Rec is record
      Id        : String (1 .. Max_Id) := (others => ' ');
      Id_Last   : Natural := 0;
      Kind      : String (1 .. Max_Kind) := (others => ' ');
      Kind_Last : Natural := 0;
      Prompt    : String (1 .. Max_Prompt) := (others => ' ');
      Prompt_Last : Natural := 0;
      Input     : String (1 .. Max_Field) := (others => ' ');
      Input_Last : Natural := 0;
      Expected  : String (1 .. Max_Answer) := (others => ' ');
      Expected_Last : Natural := 0;
      Sample    : String (1 .. Max_Answer) := (others => ' ');
      Sample_Last : Natural := 0;
      Grade_Any : Boolean := False;
      Solvable  : Boolean := False;
      Truth     : String (1 .. Max_Answer) := (others => ' ');
      Truth_Last : Natural := 0;
      Rule      : Rule_Id := No_Rule;
   end record;

   type Task_List is array (1 .. Task_Count) of Task_Rec;

   type Bank is record
      Count : Natural := 0;
      Slot  : Task_List;
   end record;

   procedure Fill_Bench (Text : out String; Last : out Natural) is
      OK : Boolean := True;
   begin
      Text := (others => ' ');
      Last := 0;
      Add (Text, Last, "# Tasks about this repository. The planted list is elsewhere." & LF, OK);
      Add (Text, Last, "task xor-00" & LF, OK);
      Add (Text, Last, "kind xor-label" & LF, OK);
      Add (Text, Last, "prompt XOR label of the point with inputs 0 0." & LF, OK);
      Add (Text, Last, "input 0 0" & LF, OK);
      Add (Text, Last, "expected 0" & LF, OK);
      Add (Text, Last, "grade exact" & LF, OK);
      Add (Text, Last, "sample 0" & LF, OK);
      Add (Text, Last, "end" & LF, OK);
      Add (Text, Last, "task xor-01" & LF, OK);
      Add (Text, Last, "kind xor-label" & LF, OK);
      Add (Text, Last, "prompt XOR label of the point with inputs 0 1." & LF, OK);
      Add (Text, Last, "input 0 1" & LF, OK);
      Add (Text, Last, "expected 1" & LF, OK);
      Add (Text, Last, "grade exact" & LF, OK);
      Add (Text, Last, "sample 1" & LF, OK);
      Add (Text, Last, "end" & LF, OK);
      Add (Text, Last, "task xor-10" & LF, OK);
      Add (Text, Last, "kind xor-label" & LF, OK);
      Add (Text, Last, "prompt XOR label of the point with inputs 1 0." & LF, OK);
      Add (Text, Last, "input 1 0" & LF, OK);
      Add (Text, Last, "expected 1" & LF, OK);
      Add (Text, Last, "grade exact" & LF, OK);
      Add (Text, Last, "sample 0" & LF, OK);
      Add (Text, Last, "end" & LF, OK);
      Add (Text, Last, "task xor-11" & LF, OK);
      Add (Text, Last, "kind xor-label" & LF, OK);
      Add (Text, Last, "prompt XOR label of the point with inputs 1 1." & LF, OK);
      Add (Text, Last, "input 1 1" & LF, OK);
      Add (Text, Last, "expected 0" & LF, OK);
      Add (Text, Last, "grade exact" & LF, OK);
      Add (Text, Last, "sample 1" & LF, OK);
      Add (Text, Last, "end" & LF, OK);
      Add (Text, Last, "task xor-count" & LF, OK);
      Add (Text, Last, "kind xor-count" & LF, OK);
      Add (Text, Last, "prompt How many points does the XOR dataset hold." & LF, OK);
      Add (Text, Last, "input" & LF, OK);
      Add (Text, Last, "expected 4" & LF, OK);
      Add (Text, Last, "grade exact" & LF, OK);
      Add (Text, Last, "sample 4" & LF, OK);
      Add (Text, Last, "end" & LF, OK);
      Add (Text, Last, "task weight-roundtrip" & LF, OK);
      Add (Text, Last, "kind weight-status" & LF, OK);
      Add (Text, Last, "prompt Status after reading the hand-written XOR file back." & LF, OK);
      Add (Text, Last, "input roundtrip" & LF, OK);
      Add (Text, Last, "expected loaded" & LF, OK);
      Add (Text, Last, "grade exact" & LF, OK);
      Add (Text, Last, "sample loaded" & LF, OK);
      Add (Text, Last, "end" & LF, OK);
      Add (Text, Last, "task weight-shape-ok" & LF, OK);
      Add (Text, Last, "kind weight-status" & LF, OK);
      Add (Text, Last, "prompt Status of a file whose shape line names 2 8 1." & LF, OK);
      Add (Text, Last, "input shape 2 8 1" & LF, OK);
      Add (Text, Last, "expected loaded" & LF, OK);
      Add (Text, Last, "grade exact" & LF, OK);
      Add (Text, Last, "sample loaded" & LF, OK);
      Add (Text, Last, "end" & LF, OK);
      Add (Text, Last, "task weight-limit" & LF, OK);
      Add (Text, Last, "kind weight-status" & LF, OK);
      Add (Text, Last, "prompt Status when hidden 1 x1 is set to 1000." & LF, OK);
      Add (Text, Last, "input value 1000" & LF, OK);
      Add (Text, Last, "expected loaded" & LF, OK);
      Add (Text, Last, "grade exact" & LF, OK);
      Add (Text, Last, "sample bad-value" & LF, OK);
      Add (Text, Last, "end" & LF, OK);
      Add (Text, Last, "task weight-over" & LF, OK);
      Add (Text, Last, "kind weight-status" & LF, OK);
      Add (Text, Last, "prompt Status when hidden 1 x1 is set to 1001." & LF, OK);
      Add (Text, Last, "input value 1001" & LF, OK);
      Add (Text, Last, "expected bad-value" & LF, OK);
      Add (Text, Last, "grade exact" & LF, OK);
      Add (Text, Last, "sample bad-value" & LF, OK);
      Add (Text, Last, "end" & LF, OK);
      Add (Text, Last, "task weight-bad-shape" & LF, OK);
      Add (Text, Last, "kind weight-status" & LF, OK);
      Add (Text, Last, "prompt Status of a file whose shape line names 2 4 1." & LF, OK);
      Add (Text, Last, "input shape 2 4 1" & LF, OK);
      Add (Text, Last, "expected bad-shape" & LF, OK);
      Add (Text, Last, "grade exact" & LF, OK);
      Add (Text, Last, "sample bad-shape" & LF, OK);
      Add (Text, Last, "end" & LF, OK);
      Add (Text, Last, "task fib-0" & LF, OK);
      Add (Text, Last, "kind fib-answer" & LF, OK);
      Add (Text, Last, "prompt Answer the checker reports for opening index 0." & LF, OK);
      Add (Text, Last, "input 0" & LF, OK);
      Add (Text, Last, "expected 0" & LF, OK);
      Add (Text, Last, "grade exact" & LF, OK);
      Add (Text, Last, "sample 1" & LF, OK);
      Add (Text, Last, "end" & LF, OK);
      Add (Text, Last, "task fib-1" & LF, OK);
      Add (Text, Last, "kind fib-answer" & LF, OK);
      Add (Text, Last, "prompt Answer the checker reports for opening index 1." & LF, OK);
      Add (Text, Last, "input 1" & LF, OK);
      Add (Text, Last, "expected 1" & LF, OK);
      Add (Text, Last, "grade exact" & LF, OK);
      Add (Text, Last, "sample 0" & LF, OK);
      Add (Text, Last, "end" & LF, OK);
      Add (Text, Last, "task fib-6" & LF, OK);
      Add (Text, Last, "kind fib-answer" & LF, OK);
      Add (Text, Last, "prompt Answer the checker reports for opening index 6." & LF, OK);
      Add (Text, Last, "input 6" & LF, OK);
      Add (Text, Last, "expected 8" & LF, OK);
      Add (Text, Last, "grade exact" & LF, OK);
      Add (Text, Last, "sample 8" & LF, OK);
      Add (Text, Last, "end" & LF, OK);
      Add (Text, Last, "task fib-20" & LF, OK);
      Add (Text, Last, "kind fib-answer" & LF, OK);
      Add (Text, Last, "prompt Answer the checker reports for opening index 20." & LF, OK);
      Add (Text, Last, "input 20" & LF, OK);
      Add (Text, Last, "expected 6765" & LF, OK);
      Add (Text, Last, "grade exact" & LF, OK);
      Add (Text, Last, "sample 6765" & LF, OK);
      Add (Text, Last, "end" & LF, OK);
      Add (Text, Last, "task fib-stop-bad" & LF, OK);
      Add (Text, Last, "kind fib-stop" & LF, OK);
      Add (Text, Last, "prompt Stop word of the recorded chain fib-6-bad-sum." & LF, OK);
      Add (Text, Last, "input fib-6-bad-sum" & LF, OK);
      Add (Text, Last, "expected bad-arithmetic" & LF, OK);
      Add (Text, Last, "grade exact" & LF, OK);
      Add (Text, Last, "sample reached-base" & LF, OK);
      Add (Text, Last, "end" & LF, OK);
      Add (Text, Last, "task fib-5-wrong" & LF, OK);
      Add (Text, Last, "kind fib-answer" & LF, OK);
      Add (Text, Last, "prompt Answer the checker reports for opening index 5." & LF, OK);
      Add (Text, Last, "input 5" & LF, OK);
      Add (Text, Last, "expected 9" & LF, OK);
      Add (Text, Last, "grade exact" & LF, OK);
      Add (Text, Last, "sample 9" & LF, OK);
      Add (Text, Last, "end" & LF, OK);
      Add (Text, Last, "task fib-21" & LF, OK);
      Add (Text, Last, "kind fib-answer" & LF, OK);
      Add (Text, Last, "prompt Answer the checker reports for opening index 21." & LF, OK);
      Add (Text, Last, "input 21" & LF, OK);
      Add (Text, Last, "expected 10946" & LF, OK);
      Add (Text, Last, "grade exact" & LF, OK);
      Add (Text, Last, "sample 10946" & LF, OK);
      Add (Text, Last, "end" & LF, OK);
      Add (Text, Last, "task xor-01-copy" & LF, OK);
      Add (Text, Last, "kind xor-label" & LF, OK);
      Add (Text, Last, "prompt Label requested again for inputs 0 1." & LF, OK);
      Add (Text, Last, "input 0 1" & LF, OK);
      Add (Text, Last, "expected 1" & LF, OK);
      Add (Text, Last, "grade exact" & LF, OK);
      Add (Text, Last, "sample 1" & LF, OK);
      Add (Text, Last, "end" & LF, OK);
      Add (Text, Last, "task weight-any" & LF, OK);
      Add (Text, Last, "kind weight-status" & LF, OK);
      Add (Text, Last, "prompt Status when hidden 1 x1 is set to 0." & LF, OK);
      Add (Text, Last, "input value 0" & LF, OK);
      Add (Text, Last, "expected loaded" & LF, OK);
      Add (Text, Last, "grade any" & LF, OK);
      Add (Text, Last, "sample nope" & LF, OK);
      Add (Text, Last, "end" & LF, OK);
      Add (Text, Last, "task fib-4-leaked" & LF, OK);
      Add (Text, Last, "kind fib-answer" & LF, OK);
      Add (Text, Last, "prompt The answer is 3. Answer the checker reports for opening index 4." & LF, OK);
      Add (Text, Last, "input 4" & LF, OK);
      Add (Text, Last, "expected 3" & LF, OK);
      Add (Text, Last, "grade exact" & LF, OK);
      Add (Text, Last, "sample 3" & LF, OK);
      Add (Text, Last, "end" & LF, OK);
      if not OK then
         Last := 0;
      end if;
   end Fill_Bench;

   function Token_Char (C : Character) return Boolean is
     (C in '0' .. '9' or else C in 'a' .. 'z'
      or else C in 'A' .. 'Z' or else C = '-');

   function Has_Token (Text : String; Token : String) return Boolean is
      I, First : Natural;
   begin
      if Token'Length = 0 or else Text'Length = 0 then
         return False;
      end if;
      I := Text'First;
      while I <= Text'Last loop
         while I <= Text'Last and then not Token_Char (Text (I)) loop
            I := I + 1;
         end loop;
         exit when I > Text'Last;
         First := I;
         while I <= Text'Last and then Token_Char (Text (I)) loop
            I := I + 1;
         end loop;
         if Same (Text, First, I - 1, Token) then
            return True;
         end if;
      end loop;
      return False;
   end Has_Token;

   procedure Store
     (Word : String;
      Dest : out String;
      Last : out Natural;
      OK   : out Boolean)
   is
   begin
      Dest := (others => ' ');
      Last := 0;
      OK := Word'Length <= Dest'Length;
      if not OK then
         return;
      end if;
      for C of Word loop
         Last := Last + 1;
         Dest (Last) := C;
      end loop;
   end Store;

   procedure Parse_Digits
     (Token : String;
      Value : out Natural;
      OK    : out Boolean)
   is
      Acc : Natural := 0;
   begin
      Value := 0;
      OK := False;
      if Token'Length = 0 or else Token'Length > 7 then
         return;
      end if;
      for C of Token loop
         if C not in '0' .. '9' then
            return;
         end if;
         Acc := Acc * 10 + (Character'Pos (C) - Character'Pos ('0'));
      end loop;
      Value := Acc;
      OK := True;
   end Parse_Digits;

   procedure Answer_Nat
     (Value : Natural;
      Dest  : out String;
      Last  : out Natural)
   is
      OK : Boolean := True;
   begin
      Dest := (others => ' ');
      Last := 0;
      Add_Nat (Dest, Last, Value, OK);
      if not OK then
         Last := 0;
      end if;
   end Answer_Nat;

   procedure Recompute
     (Kind, Input : String;
      Answer      : out String;
      Last        : out Natural;
      Solvable    : out Boolean)
   is
      procedure Clear is
      begin
         Answer := (others => ' ');
         Last := 0;
         Solvable := False;
      end Clear;

      procedure Yes (Word : String) is
         Fit : Boolean;
      begin
         Store (Word, Answer, Last, Fit);
         Solvable := Fit and then Last > 0;
         if not Solvable then
            Last := 0;
         end if;
      end Yes;
   begin
      Clear;
      if Same_All (Kind, "xor-label") then
         declare
            From, A, B, N1, N2 : Natural;
            D1, D2 : Natural;
            OK1, OK2, Found : Boolean;
         begin
            From := Input'First;
            Take_Word (Input, From, Input'Last, A, B, N1);
            if B < A then
               return;
            end if;
            Parse_Digits (Input (A .. B), D1, OK1);
            Take_Word (Input, N1, Input'Last, A, B, N2);
            if not OK1 or else B < A then
               return;
            end if;
            Parse_Digits (Input (A .. B), D2, OK2);
            Take_Word (Input, N2, Input'Last, A, B, N1);
            Found := B >= A;
            if not OK2 or else Found then
               return;
            end if;
            if (D1 /= 0 and then D1 /= 1)
              or else (D2 /= 0 and then D2 /= 1)
            then
               return;
            end if;
            if D1 = D2 then
               Yes ("0");
            else
               Yes ("1");
            end if;
         end;
      elsif Same_All (Kind, "xor-count") then
         if Input'Length /= 0 then
            return;
         end if;
         Yes ("4");
      elsif Same_All (Kind, "fib-answer") then
         declare
            From, A, B, Next : Natural;
            Index : Natural;
            OKN : Boolean;
            Extra : Boolean;
         begin
            From := Input'First;
            Take_Word (Input, From, Input'Last, A, B, Next);
            if B < A then
               return;
            end if;
            Parse_Digits (Input (A .. B), Index, OKN);
            Take_Word (Input, Next, Input'Last, A, B, Next);
            Extra := B >= A;
            if not OKN or else Extra or else Index > 20 then
               return;
            end if;
            Answer_Nat (Fib_Value (Index), Answer, Last);
            Solvable := Last > 0;
         end;
      elsif Same_All (Kind, "fib-stop") then
         if not Same_All (Input, "fib-6-bad-sum") then
            return;
         end if;
         declare
            type Trip is record
               Idx, Minus, Curr : Natural;
            end record;
            Walk : constant array (1 .. 4) of Trip :=
              ((6, 0, 1), (5, 1, 1), (4, 1, 2), (3, 2, 4));
            Kind : Step_Kind;
         begin
            for I in 2 .. 4 loop
               Kind :=
                 Check_Fib
                   ((Idx => Walk (I - 1).Idx,
                     Minus => Walk (I - 1).Minus,
                     Curr => Walk (I - 1).Curr),
                    (Idx => Walk (I).Idx,
                     Minus => Walk (I).Minus,
                     Curr => Walk (I).Curr));
               if Kind = Bad_Arith then
                  Yes ("bad-arithmetic");
                  return;
               elsif Kind = Not_Toward or else Kind = Past_Base then
                  Yes ("not-toward-base");
                  return;
               elsif Kind /= Accepted and then Kind /= Reached_Base then
                  Yes ("bad-parse");
                  return;
               end if;
            end loop;
            Yes ("reached-base");
         end;
      elsif Same_All (Kind, "weight-status") then
         declare
            From, A, B, Next : Natural;
            N1, N2, N3 : Natural;
            OK1, OK2, OK3 : Boolean;
            Whole : Float;
            Frac : Float;
            Scale : Float;
            Neg : Boolean;
            Seen : Boolean;
         begin
            if Same_All (Input, "roundtrip") then
               Yes ("loaded");
               return;
            end if;
            From := Input'First;
            Take_Word (Input, From, Input'Last, A, B, Next);
            if B < A then
               return;
            end if;
            if Same (Input, A, B, "shape") then
               Take_Word (Input, Next, Input'Last, A, B, Next);
               if B < A then
                  return;
               end if;
               Parse_Digits (Input (A .. B), N1, OK1);
               Take_Word (Input, Next, Input'Last, A, B, Next);
               if B < A then
                  return;
               end if;
               Parse_Digits (Input (A .. B), N2, OK2);
               Take_Word (Input, Next, Input'Last, A, B, Next);
               if B < A then
                  return;
               end if;
               Parse_Digits (Input (A .. B), N3, OK3);
               Take_Word (Input, Next, Input'Last, A, B, Next);
               if not OK1 or else not OK2 or else not OK3 or else B >= A then
                  return;
               end if;
               if N1 = 2 and then N2 = 8 and then N3 = 1 then
                  Yes ("loaded");
               else
                  Yes ("bad-shape");
               end if;
               return;
            end if;
            if not Same (Input, A, B, "value") then
               return;
            end if;
            Take_Word (Input, Next, Input'Last, A, B, Next);
            if B < A then
               return;
            end if;
            declare
               Num_A : constant Natural := A;
               Num_B : constant Natural := B;
               Extra_A, Extra_B, Extra_N : Natural;
               I : Natural := Num_A;
               Digit : Integer;
            begin
               Take_Word (Input, Next, Input'Last, Extra_A, Extra_B, Extra_N);
               if Extra_B >= Extra_A then
                  return;
               end if;
               Neg := False;
               Seen := False;
               Whole := 0.0;
               Frac := 0.0;
               Scale := 1.0;
               if Input (I) = '-' or else Input (I) = '+' then
                  Neg := Input (I) = '-';
                  I := I + 1;
               end if;
               while I <= Num_B loop
                  if Input (I) in '0' .. '9' then
                     Seen := True;
                     Digit := Character'Pos (Input (I)) - Character'Pos ('0');
                     Whole := Whole * 10.0 + Float (Digit);
                     I := I + 1;
                  elsif Input (I) = '.' then
                     I := I + 1;
                     while I <= Num_B and then Input (I) in '0' .. '9' loop
                        Seen := True;
                        Digit :=
                          Character'Pos (Input (I)) - Character'Pos ('0');
                        Scale := Scale / 10.0;
                        Frac := Frac + Scale * Float (Digit);
                        I := I + 1;
                     end loop;
                     exit;
                  else
                     return;
                  end if;
               end loop;
               if not Seen or else I <= Num_B then
                  return;
               end if;
               Whole := Whole + Frac;
               if Neg then
                  Whole := -Whole;
               end if;
               if Whole > 1000.0 or else Whole < -1000.0 then
                  Yes ("bad-value");
               else
                  Yes ("loaded");
               end if;
            end;
         end;
      end if;
   end Recompute;

   function Field_Same
     (Left : String; L_Last : Natural;
      Right : String; R_Last : Natural) return Boolean
   is
   begin
      if L_Last = 0 then
         return R_Last = 0;
      end if;
      if R_Last = 0 or else L_Last /= R_Last then
         return False;
      end if;
      return Same
        (Left, Left'First, Left'First + L_Last - 1,
         Right (Right'First .. Right'First + R_Last - 1));
   end Field_Same;

   procedure Note_Rule (Slot : in out Task_Rec; Rule : Rule_Id) is
   begin
      if Slot.Rule = No_Rule then
         Slot.Rule := Rule;
      end if;
   end Note_Rule;

   procedure Examine (Item : in out Bank) is
   begin
      for I in 1 .. Item.Count loop
         Item.Slot (I).Rule := No_Rule;
         Item.Slot (I).Solvable := False;
         Item.Slot (I).Truth_Last := 0;
         Recompute
           (Item.Slot (I).Kind (1 .. Item.Slot (I).Kind_Last),
            Item.Slot (I).Input (1 .. Item.Slot (I).Input_Last),
            Item.Slot (I).Truth,
            Item.Slot (I).Truth_Last,
            Item.Slot (I).Solvable);
         for Earlier in 1 .. I - 1 loop
            if Field_Same
              (Item.Slot (I).Kind, Item.Slot (I).Kind_Last,
               Item.Slot (Earlier).Kind, Item.Slot (Earlier).Kind_Last)
              and then Field_Same
                (Item.Slot (I).Input, Item.Slot (I).Input_Last,
                 Item.Slot (Earlier).Input, Item.Slot (Earlier).Input_Last)
            then
               Note_Rule (Item.Slot (I), Dup_Rule);
               exit;
            end if;
         end loop;
         if not Item.Slot (I).Solvable then
            Note_Rule (Item.Slot (I), No_Answer);
         elsif not Field_Same
           (Item.Slot (I).Expected, Item.Slot (I).Expected_Last,
            Item.Slot (I).Truth, Item.Slot (I).Truth_Last)
         then
            Note_Rule (Item.Slot (I), Wrong_Key);
         end if;
         if Item.Slot (I).Expected_Last > 0
           and then Has_Token
             (Item.Slot (I).Prompt (1 .. Item.Slot (I).Prompt_Last),
              Item.Slot (I).Expected (1 .. Item.Slot (I).Expected_Last))
           and then not Has_Token
             (Item.Slot (I).Input (1 .. Item.Slot (I).Input_Last),
              Item.Slot (I).Expected (1 .. Item.Slot (I).Expected_Last))
         then
            Note_Rule (Item.Slot (I), Leaked);
         end if;
         if Item.Slot (I).Grade_Any
           and then not Same_All
             (Item.Slot (I).Expected (1 .. Item.Slot (I).Expected_Last),
              "probe-not-an-answer")
           and then not Same_All
             (Item.Slot (I).Expected (1 .. Item.Slot (I).Expected_Last),
              "zz-not-the-answer")
         then
            Note_Rule (Item.Slot (I), Accepts_All);
         end if;
      end loop;
   end Examine;

   procedure Load_Bank (Item : out Bank; OK : out Boolean) is
      Buf  : String (1 .. 4_000);
      Last : Natural;
      Pos  : Natural;
      Open : Boolean := False;
      Seen_Kind, Seen_Prompt, Seen_Input : Boolean := False;
      Seen_Expected, Seen_Grade, Seen_Sample : Boolean := False;
   begin
      Item := (Count => 0, Slot => (others => <>));
      OK := False;
      Fill_Bench (Buf, Last);
      if Last < 1 then
         return;
      end if;
      Pos := 1;
      while Pos <= Last loop
         declare
            First : constant Natural := Pos;
            Stop : Natural := Pos - 1;
            Head : Natural;
            Key_A, Key_B, Next : Natural;
            Rest_A, Rest_B : Natural;
         begin
            while Pos <= Last and then Buf (Pos) /= LF loop
               Stop := Pos;
               Pos := Pos + 1;
            end loop;
            if Pos <= Last and then Buf (Pos) = LF then
               Pos := Pos + 1;
            end if;
            if Stop < First or else Blank (Buf, First, Stop) then
               goto Continue;
            end if;
            Head := First;
            while Head <= Stop
              and then (Buf (Head) = ' ' or else Buf (Head) = Character'Val (9))
            loop
               Head := Head + 1;
            end loop;
            if Head <= Stop and then Buf (Head) = '#' then
               goto Continue;
            end if;
            Take_Word (Buf, Head, Stop, Key_A, Key_B, Next);
            if Key_B < Key_A then
               return;
            end if;
            Skip_Space (Buf, Next, Stop, Rest_A);
            Rest_B := Stop;
            while Rest_B >= Rest_A
              and then (Buf (Rest_B) = ' '
                        or else Buf (Rest_B) = Character'Val (9)
                        or else Buf (Rest_B) = Character'Val (13))
            loop
               Rest_B := Rest_B - 1;
            end loop;
            if Same (Buf, Key_A, Key_B, "task") then
               if Open or else Rest_B < Rest_A or else Item.Count = Task_Count
               then
                  return;
               end if;
               Item.Count := Item.Count + 1;
               declare
                  Fit : Boolean;
               begin
                  Store
                    (Buf (Rest_A .. Rest_B),
                     Item.Slot (Item.Count).Id,
                     Item.Slot (Item.Count).Id_Last,
                     Fit);
                  if not Fit then
                     return;
                  end if;
               end;
               Open := True;
               Seen_Kind := False;
               Seen_Prompt := False;
               Seen_Input := False;
               Seen_Expected := False;
               Seen_Grade := False;
               Seen_Sample := False;
            elsif not Open then
               return;
            elsif Same (Buf, Key_A, Key_B, "end") then
               if Rest_B >= Rest_A or else not Seen_Kind or else not Seen_Prompt
                 or else not Seen_Input or else not Seen_Expected
                 or else not Seen_Grade or else not Seen_Sample
               then
                  return;
               end if;
               Open := False;
            elsif Same (Buf, Key_A, Key_B, "kind") then
               if Seen_Kind or else Rest_B < Rest_A then
                  return;
               end if;
               declare
                  Fit : Boolean;
               begin
                  Store
                    (Buf (Rest_A .. Rest_B),
                     Item.Slot (Item.Count).Kind,
                     Item.Slot (Item.Count).Kind_Last,
                     Fit);
                  Seen_Kind := Fit;
                  if not Fit then
                     return;
                  end if;
               end;
            elsif Same (Buf, Key_A, Key_B, "prompt") then
               if Seen_Prompt or else Rest_B < Rest_A then
                  return;
               end if;
               declare
                  Fit : Boolean;
               begin
                  Store
                    (Buf (Rest_A .. Rest_B),
                     Item.Slot (Item.Count).Prompt,
                     Item.Slot (Item.Count).Prompt_Last,
                     Fit);
                  Seen_Prompt := Fit;
                  if not Fit then
                     return;
                  end if;
               end;
            elsif Same (Buf, Key_A, Key_B, "input") then
               if Seen_Input then
                  return;
               end if;
               if Rest_B < Rest_A then
                  Item.Slot (Item.Count).Input_Last := 0;
                  Seen_Input := True;
               else
                  declare
                     Fit : Boolean;
                  begin
                     Store
                       (Buf (Rest_A .. Rest_B),
                        Item.Slot (Item.Count).Input,
                        Item.Slot (Item.Count).Input_Last,
                        Fit);
                     Seen_Input := Fit;
                     if not Fit then
                        return;
                     end if;
                  end;
               end if;
            elsif Same (Buf, Key_A, Key_B, "expected") then
               if Seen_Expected or else Rest_B < Rest_A then
                  return;
               end if;
               declare
                  Fit : Boolean;
               begin
                  Store
                    (Buf (Rest_A .. Rest_B),
                     Item.Slot (Item.Count).Expected,
                     Item.Slot (Item.Count).Expected_Last,
                     Fit);
                  Seen_Expected := Fit;
                  if not Fit then
                     return;
                  end if;
               end;
            elsif Same (Buf, Key_A, Key_B, "grade") then
               if Seen_Grade or else Rest_B < Rest_A then
                  return;
               end if;
               if Same (Buf, Rest_A, Rest_B, "exact") then
                  Item.Slot (Item.Count).Grade_Any := False;
               elsif Same (Buf, Rest_A, Rest_B, "any") then
                  Item.Slot (Item.Count).Grade_Any := True;
               else
                  return;
               end if;
               Seen_Grade := True;
            elsif Same (Buf, Key_A, Key_B, "sample") then
               if Seen_Sample or else Rest_B < Rest_A then
                  return;
               end if;
               declare
                  Fit : Boolean;
               begin
                  Store
                    (Buf (Rest_A .. Rest_B),
                     Item.Slot (Item.Count).Sample,
                     Item.Slot (Item.Count).Sample_Last,
                     Fit);
                  Seen_Sample := Fit;
                  if not Fit then
                     return;
                  end if;
               end;
            else
               return;
            end if;
            <<Continue>>
            null;
         end;
      end loop;
      OK := not Open and then Item.Count = Task_Count;
      if OK then
         Examine (Item);
      end if;
   end Load_Bank;

   function Hit (Slot : Task_Rec) return Boolean is
   begin
      if Slot.Grade_Any then
         return True;
      end if;
      return Field_Same
        (Slot.Sample, Slot.Sample_Last, Slot.Expected, Slot.Expected_Last);
   end Hit;

   procedure Rule_Word (Rule : Rule_Id; Text : out String; Last : out Natural) is
   begin
      case Rule is
         when No_Rule =>
            Put_Word (Text, Last, "none");
         when Dup_Rule =>
            Put_Word (Text, Last, "duplicate");
         when No_Answer =>
            Put_Word (Text, Last, "unsolvable");
         when Wrong_Key =>
            Put_Word (Text, Last, "wrong-expected");
         when Leaked =>
            Put_Word (Text, Last, "answer-leaked");
         when Accepts_All =>
            Put_Word (Text, Last, "accept-anything");
      end case;
   end Rule_Word;

   procedure Task_Id
     (Index : Natural;
      Text  : out String;
      Last  : out Natural)
   is
      Item : Bank;
      OK   : Boolean;
   begin
      Put_Word (Text, Last, "");
      Load_Bank (Item, OK);
      if not OK or else Index < 1 or else Index > Item.Count then
         return;
      end if;
      Put_Word
        (Text, Last, Item.Slot (Index).Id (1 .. Item.Slot (Index).Id_Last));
   end Task_Id;

   procedure Judge_Task
     (Index   : Natural;
      Verdict : out String;
      V_Last  : out Natural;
      Reason  : out String;
      R_Last  : out Natural;
      Bad     : out Natural;
      OK      : out Boolean)
   is
      Item : Bank;
   begin
      Bad := 0;
      Put_Word (Verdict, V_Last, "flag");
      Put_Word (Reason, R_Last, "none");
      Load_Bank (Item, OK);
      if not OK or else Index < 1 or else Index > Item.Count then
         OK := False;
         return;
      end if;
      if Item.Slot (Index).Rule = No_Rule then
         Put_Word (Verdict, V_Last, "pass");
         Put_Word (Reason, R_Last, "none");
      else
         Put_Word (Verdict, V_Last, "flag");
         Rule_Word (Item.Slot (Index).Rule, Reason, R_Last);
      end if;
   end Judge_Task;

   procedure Judge_Score
     (Drop_Flagged : Boolean;
      Verdict      : out String;
      V_Last       : out Natural;
      Reason       : out String;
      R_Last       : out Natural;
      Bad          : out Natural;
      OK           : out Boolean)
   is
      Item : Bank;
      Hits : Natural := 0;
      Total : Natural := 0;
      Fit : Boolean := True;
   begin
      Bad := 0;
      Put_Word (Verdict, V_Last, "not-accepted");
      Put_Word (Reason, R_Last, "");
      Load_Bank (Item, OK);
      if not OK then
         return;
      end if;
      for I in 1 .. Item.Count loop
         if not (Drop_Flagged and then Item.Slot (I).Rule /= No_Rule) then
            Total := Total + 1;
            if Hit (Item.Slot (I)) then
               Hits := Hits + 1;
            end if;
         end if;
      end loop;
      Reason := (others => ' ');
      R_Last := 0;
      if Drop_Flagged then
         Add (Reason, R_Last, "Cleaned set: ", Fit);
         Put_Word (Verdict, V_Last, "accepted");
      else
         Add (Reason, R_Last, "Full set: ", Fit);
         Put_Word (Verdict, V_Last, "not-accepted");
      end if;
      Add_Nat (Reason, R_Last, Hits, Fit);
      Add (Reason, R_Last, " of ", Fit);
      Add_Nat (Reason, R_Last, Total, Fit);
      Add (Reason, R_Last, ". ", Fit);
      if Drop_Flagged then
         Add (Reason, R_Last, "Accepted.", Fit);
      else
         Add (Reason, R_Last, "Not accepted: audit-flagged.", Fit);
      end if;
      if not Fit then
         R_Last := 0;
         OK := False;
      end if;
   end Judge_Score;

   type Grade_Rule is
     (No_Grade, Bad_Parse, Unknown_Problem, Unknown_Step, Bad_Value,
      Skipped_Step, Guessed_First, Wrong_Answer, Out_Of_Order,
      Bad_Arithmetic, Not_Toward_Base);

   procedure Grade_Word
     (Rule : Grade_Rule;
      Text : out String;
      Last : out Natural)
   is
   begin
      case Rule is
         when No_Grade =>
            Put_Word (Text, Last, "none");
         when Bad_Parse =>
            Put_Word (Text, Last, "bad-parse");
         when Unknown_Problem =>
            Put_Word (Text, Last, "unknown-problem");
         when Unknown_Step =>
            Put_Word (Text, Last, "unknown-step");
         when Bad_Value =>
            Put_Word (Text, Last, "bad-value");
         when Skipped_Step =>
            Put_Word (Text, Last, "skipped-step");
         when Guessed_First =>
            Put_Word (Text, Last, "guessed-first");
         when Wrong_Answer =>
            Put_Word (Text, Last, "wrong-answer");
         when Out_Of_Order =>
            Put_Word (Text, Last, "out-of-order");
         when Bad_Arithmetic =>
            Put_Word (Text, Last, "bad-arithmetic");
         when Not_Toward_Base =>
            Put_Word (Text, Last, "not-toward-base");
      end case;
   end Grade_Word;

   procedure Grade_Text
     (Text    : String;
      Verdict : out String;
      V_Last  : out Natural;
      Reason  : out String;
      R_Last  : out Natural;
      Bad     : out Natural;
      Answer  : out String;
      A_Last  : out Natural)
   is
      Max_Line   : constant := 96;
      Max_Steps  : constant := 16;
      Max_Parsed : constant := 24;
      XOR_Steps  : constant := 7;
      Train_N    : constant := 7;
      Sum_Steps  : constant := 4;

      type Kind_Name is (No_Kind, XOR_Kind, Train_Kind, Fib_Kind, Sum_Kind);
      type Sort_Name is
        (Tok_Name, Tok_Problem, Tok_Step, Tok_Answer, Tok_Junk);
      type Parsed is record
         Sort      : Sort_Name := Tok_Junk;
         Line      : String (1 .. Max_Line) := (others => ' ');
         Line_Last : Natural := 0;
         Code      : Natural := 0;
         Value     : Float := 0.0;
      end record;
      type Value_List is array (1 .. XOR_Steps) of Float;

      List : array (1 .. Max_Parsed) of Parsed;
      Count : Natural := 0;
      Kind : Kind_Name := No_Kind;
      Have : Boolean := False;
      Fib_N : Natural := 0;
      Truth : Value_List := (others => 0.0);
      Expect : Float := 0.0;
      Next_Code : Natural := 1;
      Fib_Seen : Natural := 0;
      Fib : Chain := (others => (0, 0, 0));
      Rows : Natural := 0;
      Bad_At : Natural := 0;
      Rule : Grade_Rule := No_Grade;
      Saw_Answer : Boolean := False;
      Answer_OK : Boolean := False;

      procedure Blame (Where : Natural; Which : Grade_Rule) is
      begin
         if Where < 1 then
            return;
         end if;
         if Bad_At = 0 then
            Bad_At := Where;
            Rule := Which;
         end if;
      end Blame;

      function Push return Natural is
      begin
         if Rows >= Max_Steps then
            if Bad_At = 0 and then Rows >= 1 then
               Bad_At := Rows;
               Rule := Bad_Parse;
            end if;
            return 0;
         end if;
         Rows := Rows + 1;
         return Rows;
      end Push;

      procedure Parse_Line_Float
        (Line       : String;
         From, Stop : Natural;
         Value      : out Float;
         Next       : out Natural;
         OK         : out Boolean)
      is
         I     : Natural;
         Neg   : Boolean := False;
         Whole : Float := 0.0;
         Frac  : Float := 0.0;
         Scale : Float := 1.0;
         Seen  : Natural := 0;
         Dot   : Boolean := False;
         Digit : Integer;
      begin
         Value := 0.0;
         Next := From;
         OK := False;
         Skip_Space (Line, From, Stop, I);
         if I > Stop or else I > Line'Last or else I < Line'First then
            return;
         end if;
         if Line (I) = '-' or else Line (I) = '+' then
            Neg := Line (I) = '-';
            I := I + 1;
         end if;
         while I <= Stop and then I <= Line'Last loop
            if Line (I) in '0' .. '9' then
               Digit := Character'Pos (Line (I)) - Character'Pos ('0');
               Seen := Seen + 1;
               if Seen > 12 then
                  return;
               end if;
               if not Dot then
                  Whole := Whole * 10.0 + Float (Digit);
               else
                  Scale := Scale / 10.0;
                  Frac := Frac + Scale * Float (Digit);
               end if;
               I := I + 1;
            elsif Line (I) = '.' and then not Dot then
               Dot := True;
               I := I + 1;
            else
               exit;
            end if;
         end loop;
         if Seen = 0 then
            return;
         end if;
         Value := Whole + Frac;
         if Neg then
            Value := -Value;
         end if;
         Next := I;
         OK := True;
      end Parse_Line_Float;

      procedure Parse_Line_Nat
        (Line       : String;
         From, Stop : Natural;
         Value      : out Natural;
         Next       : out Natural;
         OK         : out Boolean)
      is
         I     : Natural;
         Acc   : Natural := 0;
         Digit : Natural;
         Any   : Boolean := False;
      begin
         Value := 0;
         Next := From;
         OK := False;
         Skip_Space (Line, From, Stop, I);
         if I > Stop or else I > Line'Last or else I < Line'First then
            return;
         end if;
         while I <= Stop and then I <= Line'Last and then Line (I) in '0' .. '9'
         loop
            Any := True;
            Digit := Character'Pos (Line (I)) - Character'Pos ('0');
            if Acc > (Max_Value - Digit) / 10 then
               return;
            end if;
            Acc := Acc * 10 + Digit;
            I := I + 1;
         end loop;
         if not Any then
            return;
         end if;
         Value := Acc;
         Next := I;
         OK := True;
      end Parse_Line_Nat;

      function Later_Step (From : Natural) return Boolean is
      begin
         for I in From + 1 .. Count loop
            if List (I).Sort = Tok_Step then
               return True;
            end if;
         end loop;
         return False;
      end Later_Step;

      function Need return Natural is
      begin
         case Kind is
            when XOR_Kind =>
               return XOR_Steps;
            when Train_Kind =>
               return Train_N;
            when Sum_Kind =>
               return Sum_Steps;
            when Fib_Kind =>
               return Fib_N;
            when No_Kind =>
               return 0;
         end case;
      end Need;

   begin
      Bad := 0;
      Put_Word (Verdict, V_Last, "fail");
      Put_Word (Reason, R_Last, "unknown-problem");
      Put_Word (Answer, A_Last, "fail");
      if Text'Length = 0 then
         return;
      end if;
      declare
         I : Natural := Text'First;
         First, Stop : Natural;
         Hash : Boolean;
         N : Natural;
         A : Natural;
      begin
         while I <= Text'Last loop
            First := I;
            Stop := I - 1;
            while I <= Text'Last and then Text (I) /= LF loop
               Stop := I;
               I := I + 1;
            end loop;
            if I <= Text'Last and then Text (I) = LF then
               I := I + 1;
            end if;
            if Stop >= First and then not Blank (Text, First, Stop) then
               Hash := False;
               for J in First .. Stop loop
                  if Text (J) /= ' ' and then Text (J) /= Character'Val (9) then
                     Hash := Text (J) = '#';
                     exit;
                  end if;
               end loop;
               if not Hash and then Count < Max_Parsed then
                  Count := Count + 1;
                  A := First;
                  while A <= Stop
                    and then (Text (A) = ' ' or else Text (A) = Character'Val (9))
                  loop
                     A := A + 1;
                  end loop;
                  declare
                     B : Natural := Stop;
                  begin
                     while B > A
                       and then (Text (B) = ' ' or else Text (B) = Character'Val (9)
                                 or else Text (B) = Character'Val (13))
                     loop
                        B := B - 1;
                     end loop;
                     N := 0;
                     if B >= A then
                        for J in A .. B loop
                           N := N + 1;
                           exit when N > Max_Line;
                           List (Count).Line (N) := Text (J);
                        end loop;
                     end if;
                     if N = 0 or else N > Max_Line then
                        List (Count).Line_Last := 0;
                        List (Count).Sort := Tok_Junk;
                     else
                        List (Count).Line_Last := N;
                        if Same (List (Count).Line, 1, 4, "name")
                          and then (N = 4 or else List (Count).Line (5) = ' ')
                        then
                           List (Count).Sort := Tok_Name;
                        elsif Same (List (Count).Line, 1, 7, "problem")
                          and then (N = 7 or else List (Count).Line (8) = ' ')
                        then
                           List (Count).Sort := Tok_Problem;
                        elsif Same (List (Count).Line, 1, 4, "step")
                          and then (N = 4 or else List (Count).Line (5) = ' ')
                        then
                           List (Count).Sort := Tok_Step;
                        elsif Same (List (Count).Line, 1, 6, "answer")
                          and then (N = 6 or else List (Count).Line (7) = ' ')
                        then
                           List (Count).Sort := Tok_Answer;
                        else
                           List (Count).Sort := Tok_Junk;
                        end if;
                     end if;
                  end;
               end if;
            end if;
         end loop;
      end;

      for I in 1 .. Count loop
         declare
            Slot : Parsed renames List (I);
            Where : Natural;
            A, B, N : Natural;
            Word_A, Word_B : Natural;
            procedure Take_Problem is
               D1, D2 : Natural;
               N1, N2 : Natural;
               OK1, OK2 : Boolean;
               Num : Natural;
               Num_OK : Boolean;
               Fib_OK : Boolean;
               Loss, Y00, Y01, Y10, Y11, Grad, Bias : Float;
               Pass : Forward;
            begin
               if Have then
                  Blame (Where, Bad_Parse);
                  return;
               end if;
               Take_Word (Slot.Line, 1, Slot.Line_Last, Word_A, Word_B, N);
               Take_Word (Slot.Line, N, Slot.Line_Last, Word_A, Word_B, N);
               if Word_B < Word_A then
                  Blame (Where, Unknown_Problem);
                  return;
               end if;
               if Same (Slot.Line, Word_A, Word_B, "xor") then
                  Parse_Line_Nat (Slot.Line, N, Slot.Line_Last, D1, N1, OK1);
                  Parse_Line_Nat (Slot.Line, N1, Slot.Line_Last, D2, N2, OK2);
                  if not OK1 or else not OK2
                    or else not Blank (Slot.Line, N2, Slot.Line_Last)
                    or else (D1 /= 0 and then D1 /= 1)
                    or else (D2 /= 0 and then D2 /= 1)
                  then
                     Blame (Where, Unknown_Problem);
                     return;
                  end if;
                  Kind := XOR_Kind;
                  Pass := Forward_Of (Float (D1), Float (D2));
                  Truth := (others => 0.0);
                  Truth (1) := Pass.H1_Logit;
                  Truth (2) := Pass.H1;
                  Truth (3) := Pass.H2_Logit;
                  Truth (4) := Pass.H2;
                  Truth (5) := Pass.Silent;
                  Truth (6) := Pass.Out_Log;
                  Truth (7) := Pass.Y;
                  Expect := Float (Class_Of (Pass.Y));
                  Have := True;
               elsif Same (Slot.Line, Word_A, Word_B, "train") then
                  if not Blank (Slot.Line, N, Slot.Line_Last) then
                     Blame (Where, Unknown_Problem);
                     return;
                  end if;
                  Kind := Train_Kind;
                  Train_Numbers (Loss, Y00, Y01, Y10, Y11, Grad, Bias);
                  Truth := (others => 0.0);
                  Truth (1) := Loss;
                  Truth (2) := Y00;
                  Truth (3) := Y01;
                  Truth (4) := Y10;
                  Truth (5) := Y11;
                  Truth (6) := Grad;
                  Truth (7) := Bias;
                  Expect := Bias;
                  Have := True;
               elsif Same (Slot.Line, Word_A, Word_B, "sum") then
                  if not Blank (Slot.Line, N, Slot.Line_Last) then
                     Blame (Where, Unknown_Problem);
                     return;
                  end if;
                  Kind := Sum_Kind;
                  Truth := (others => 0.0);
                  Truth (1) := 5.0;
                  Truth (2) := 4.0;
                  Truth (3) := 2.0;
                  Truth (4) := 11.0;
                  Expect := 11.0;
                  Have := True;
               elsif Same (Slot.Line, Word_A, Word_B, "fib") then
                  Parse_Line_Nat (Slot.Line, N, Slot.Line_Last, Num, N, Num_OK);
                  if not Num_OK or else Num > Fib_Limit
                    or else not Blank (Slot.Line, N, Slot.Line_Last)
                  then
                     Blame (Where, Unknown_Problem);
                     return;
                  end if;
                  Kind := Fib_Kind;
                  Fib_N := Num;
                  Build_Fib (Fib_N, Fib, Fib_OK);
                  if not Fib_OK then
                     Blame (Where, Unknown_Problem);
                     return;
                  end if;
                  Expect := Float (Fib (Fib_N).Minus);
                  Have := True;
               else
                  Blame (Where, Unknown_Problem);
               end if;
            end Take_Problem;

            procedure Take_Step is
               Rest : Natural;
               Num_OK : Boolean;
               V1, V2, V3 : Natural;
               N1, N2, N3 : Natural;
               OK1, OK2, OK3 : Boolean;
               Step_K : Step_Kind;
            begin
               if not Have then
                  Blame (Where, Unknown_Problem);
                  return;
               end if;
               Take_Word (Slot.Line, 1, Slot.Line_Last, Word_A, Word_B, N);
               if Kind = Fib_Kind then
                  Parse_Line_Nat (Slot.Line, N, Slot.Line_Last, V1, N1, OK1);
                  Parse_Line_Nat (Slot.Line, N1, Slot.Line_Last, V2, N2, OK2);
                  Parse_Line_Nat (Slot.Line, N2, Slot.Line_Last, V3, N3, OK3);
                  if not OK1 or else not OK2 or else not OK3
                    or else not Blank (Slot.Line, N3, Slot.Line_Last)
                  then
                     Blame (Where, Bad_Parse);
                     return;
                  end if;
                  if Fib_Seen >= Fib_N then
                     Blame (Where, Out_Of_Order);
                     return;
                  end if;
                  Fib_Seen := Fib_Seen + 1;
                  Step_K :=
                    Check_Fib
                      (Fib (Fib_Seen - 1),
                       (Idx => V1, Minus => V2, Curr => V3));
                  if Step_K = Bad_Arith then
                     Blame (Where, Bad_Arithmetic);
                  elsif Step_K = Not_Toward or else Step_K = Past_Base then
                     Blame (Where, Not_Toward_Base);
                  elsif Step_K /= Accepted and then Step_K /= Reached_Base then
                     Blame (Where, Bad_Parse);
                  elsif V1 /= Fib (Fib_Seen).Idx
                    or else V2 /= Fib (Fib_Seen).Minus
                    or else V3 /= Fib (Fib_Seen).Curr
                  then
                     Blame (Where, Bad_Arithmetic);
                  end if;
                  return;
               end if;
               Take_Word (Slot.Line, N, Slot.Line_Last, Word_A, Word_B, Rest);
               if Word_B < Word_A then
                  Blame (Where, Bad_Parse);
                  return;
               end if;
               Slot.Code := 0;
               if Kind = XOR_Kind then
                  if Same (Slot.Line, Word_A, Word_B, "h1-logit") then
                     Slot.Code := 1;
                  elsif Same (Slot.Line, Word_A, Word_B, "h1") then
                     Slot.Code := 2;
                  elsif Same (Slot.Line, Word_A, Word_B, "h2-logit") then
                     Slot.Code := 3;
                  elsif Same (Slot.Line, Word_A, Word_B, "h2") then
                     Slot.Code := 4;
                  elsif Same (Slot.Line, Word_A, Word_B, "silent") then
                     Slot.Code := 5;
                  elsif Same (Slot.Line, Word_A, Word_B, "out-logit") then
                     Slot.Code := 6;
                  elsif Same (Slot.Line, Word_A, Word_B, "output") then
                     Slot.Code := 7;
                  end if;
               elsif Kind = Train_Kind then
                  if Same (Slot.Line, Word_A, Word_B, "loss") then
                     Slot.Code := 1;
                  elsif Same (Slot.Line, Word_A, Word_B, "y00") then
                     Slot.Code := 2;
                  elsif Same (Slot.Line, Word_A, Word_B, "y01") then
                     Slot.Code := 3;
                  elsif Same (Slot.Line, Word_A, Word_B, "y10") then
                     Slot.Code := 4;
                  elsif Same (Slot.Line, Word_A, Word_B, "y11") then
                     Slot.Code := 5;
                  elsif Same (Slot.Line, Word_A, Word_B, "grad-b2") then
                     Slot.Code := 6;
                  elsif Same (Slot.Line, Word_A, Word_B, "b2") then
                     Slot.Code := 7;
                  end if;
               elsif Kind = Sum_Kind then
                  if Same (Slot.Line, Word_A, Word_B, "c1") then
                     Slot.Code := 1;
                  elsif Same (Slot.Line, Word_A, Word_B, "c2") then
                     Slot.Code := 2;
                  elsif Same (Slot.Line, Word_A, Word_B, "c3") then
                     Slot.Code := 3;
                  elsif Same (Slot.Line, Word_A, Word_B, "total") then
                     Slot.Code := 4;
                  end if;
               end if;
               if Slot.Code = 0 then
                  Blame (Where, Unknown_Step);
                  return;
               end if;
               Parse_Line_Float
                 (Slot.Line, Rest, Slot.Line_Last, Slot.Value, Rest, Num_OK);
               if not Num_OK or else not Blank (Slot.Line, Rest, Slot.Line_Last)
               then
                  Blame (Where, Bad_Parse);
                  return;
               end if;
               if Slot.Code < Next_Code then
                  Blame (Where, Out_Of_Order);
               elsif Slot.Code > Next_Code then
                  if Slot.Code = Need then
                     Blame (Where, Guessed_First);
                  else
                     Blame (Where, Skipped_Step);
                  end if;
                  Next_Code := Slot.Code + 1;
               else
                  if not Close (Slot.Value, Truth (Slot.Code)) then
                     Blame (Where, Bad_Value);
                  end if;
                  Next_Code := Slot.Code + 1;
               end if;
            end Take_Step;

            procedure Take_Answer is
               Num : Float;
               Num_OK : Boolean;
               Done : Boolean;
            begin
               if Saw_Answer then
                  Blame (Where, Out_Of_Order);
                  return;
               end if;
               Saw_Answer := True;
               if not Have then
                  Blame (Where, Unknown_Problem);
                  return;
               end if;
               Take_Word (Slot.Line, 1, Slot.Line_Last, Word_A, Word_B, N);
               Parse_Line_Float
                 (Slot.Line, N, Slot.Line_Last, Num, N, Num_OK);
               if not Num_OK or else not Blank (Slot.Line, N, Slot.Line_Last)
               then
                  Blame (Where, Bad_Parse);
                  return;
               end if;
               Answer_OK := Close (Num, Expect);
               if Kind = Fib_Kind then
                  Done := Fib_Seen >= Fib_N;
               else
                  Done := Next_Code > Need;
               end if;
               if not Done then
                  if Later_Step (I) then
                     Blame (Where, Guessed_First);
                  else
                     Blame (Where, Skipped_Step);
                  end if;
               elsif not Answer_OK then
                  Blame (Where, Wrong_Answer);
               end if;
            end Take_Answer;
         begin
            case Slot.Sort is
               when Tok_Name | Tok_Problem =>
                  Where := Push;
                  if Where /= 0 and then Slot.Sort = Tok_Problem then
                     Take_Problem;
                  elsif Where /= 0 then
                     Take_Word (Slot.Line, 1, Slot.Line_Last, A, B, N);
                     Take_Word (Slot.Line, N, Slot.Line_Last, Word_A, Word_B, N);
                     if Word_B < Word_A
                       or else not Blank (Slot.Line, N, Slot.Line_Last)
                       or else Word_B - Word_A + 1 > 16
                     then
                        Blame (Where, Bad_Parse);
                     end if;
                  end if;
                  if Where /= 0 and then Bad_At /= Where then
                     Rows := Rows - 1;
                  end if;
               when Tok_Step =>
                  Where := Push;
                  if Where /= 0 then
                     Take_Step;
                  end if;
               when Tok_Answer =>
                  Where := Push;
                  if Where /= 0 then
                     Take_Answer;
                  end if;
               when Tok_Junk =>
                  Where := Push;
                  Blame (Where, Bad_Parse);
            end case;
         end;
      end loop;

      if not Have and then Bad_At = 0 then
         Blame (Push, Unknown_Problem);
      end if;
      if not Saw_Answer then
         Blame (Push, Wrong_Answer);
         Answer_OK := False;
      end if;
      if Answer_OK then
         Put_Word (Answer, A_Last, "pass");
      else
         Put_Word (Answer, A_Last, "fail");
      end if;
      declare
         Done : Boolean;
      begin
         if Kind = Fib_Kind then
            Done := Have and then Fib_Seen = Fib_N;
         else
            Done := Have and then Next_Code > Need;
         end if;
         if Bad_At = 0 and then Answer_OK and then Done then
            Put_Word (Verdict, V_Last, "pass");
            Put_Word (Reason, R_Last, "none");
            Bad := 0;
         else
            Put_Word (Verdict, V_Last, "fail");
            Grade_Word (Rule, Reason, R_Last);
            Bad := Bad_At;
         end if;
      end;
   end Grade_Text;

end AI_Amplifier.Recheck;
