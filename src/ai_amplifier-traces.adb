with AI_Amplifier.Trace_Rule;

package body AI_Amplifier.Traces
  with SPARK_Mode => Off
is

   package M renames AI_Amplifier.MLP;
   use type M.Load_Status;

   LF : constant Character := Character'Val (10);

   type Picture is record
      Model        : M.Net;
      Loss         : Float := 0.0;
      XOR_OK       : Boolean := False;
      Weights_OK   : Boolean := False;
      Loss_Finite  : Boolean := False;
   end record;

   type Act_Kind is
     (Seed_1,
      Train_40,
      Spike,
      Hand,
      Bad_File,
      Zero_File,
      Train_10,
      Silence);

   type Act_List is array (1 .. Max_Steps) of Act_Kind;

   type Trace_Desc is record
      Name  : String (1 .. Max_Name) := (others => ' ');
      NLen  : Natural := 0;
      Acts  : Act_List := (others => Seed_1);
      Count : Natural := 0;
      Good  : Proposal := Train_200;
      Bad   : Proposal := Train_8;
   end record;

   type Line_Store is array (1 .. Max_Steps) of String (1 .. Max_Line);
   type Len_Store is array (1 .. Max_Steps) of Natural;

   procedure Add_C
     (Buf  : in out String;
      Last : in out Natural;
      C    : Character)
   is
   begin
      if Last < Buf'Last then
         Last := Last + 1;
         Buf (Last) := C;
      end if;
   end Add_C;

   procedure Add (Buf : in out String; Last : in out Natural; S : String) is
   begin
      for C of S loop
         Add_C (Buf, Last, C);
      end loop;
   end Add;

   --  Float'Floor is not in this wasm runtime. Powers of two
   --  stay exact in Float up to 2**23, and a loss here is far
   --  below that, so subtracting them is a floor.
   function Whole_Of (Value : Float) return Integer is
      Left : Float := Value;
      Pow  : Float := 1.0;
      N    : Integer := 0;
   begin
      if Left < 1.0 then
         return 0;
      end if;
      while Pow * 2.0 <= Left and then Pow < 1.0e6 loop
         Pow := Pow * 2.0;
      end loop;
      while Pow >= 1.0 loop
         if Left >= Pow then
            Left := Left - Pow;
            N := N + Integer (Pow);
         end if;
         Pow := Pow / 2.0;
      end loop;
      return N;
   end Whole_Of;

   procedure Add_Loss
     (Buf   : in out String;
      Last  : in out Natural;
      Value : Float)
   is
      Abs_V : Float;
      Whole : Integer;
      Frac  : Integer;
      Pow   : Integer;
      Digit : Integer;
   begin
      if Value /= Value or else Value > 1.0e6 or else Value < -1.0e6 then
         Add (Buf, Last, "not-finite");
         return;
      end if;
      if Value < 0.0 then
         Add_C (Buf, Last, '-');
         Abs_V := -Value;
      else
         Abs_V := Value;
      end if;
      Whole := Whole_Of (Abs_V);
      Frac := Whole_Of ((Abs_V - Float (Whole)) * 1_000_000.0 + 0.5);
      if Frac < 0 then
         Frac := 0;
      end if;
      if Frac >= 1_000_000 then
         Whole := Whole + 1;
         Frac := 0;
      end if;
      declare
         Digs : array (1 .. 8) of Integer := (others => 0);
         N    : Natural := 0;
         W    : Integer := Whole;
      begin
         if W <= 0 then
            Add_C (Buf, Last, '0');
         else
            while W > 0 and then N < Digs'Last loop
               N := N + 1;
               Digs (N) := W mod 10;
               W := W / 10;
            end loop;
            for I in reverse 1 .. N loop
               Add_C
                 (Buf, Last,
                  Character'Val (Character'Pos ('0') + Digs (I)));
            end loop;
         end if;
      end;
      Add_C (Buf, Last, '.');
      Pow := 100_000;
      for I in 1 .. 6 loop
         Digit := Frac / Pow;
         Add_C (Buf, Last, Character'Val (Character'Pos ('0') + Digit));
         Frac := Frac - Digit * Pow;
         Pow := Pow / 10;
      end loop;
   end Add_Loss;

   function Component_OK (X : Float) return Boolean is
     (X = X
      and then X <= M.Weight_Limit
      and then X >= -M.Weight_Limit);

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

   function Same_Net (Left, Right : M.Net) return Boolean is
   begin
      if Left.Rate /= Right.Rate then
         return False;
      end if;
      for R in 1 .. M.Hidden loop
         for C in 1 .. M.Inputs loop
            if Left.W1.Data (R, C) /= Right.W1.Data (R, C) then
               return False;
            end if;
         end loop;
         if Left.B1.Data (R) /= Right.B1.Data (R)
           or else Left.W2.Data (1, R) /= Right.W2.Data (1, R)
         then
            return False;
         end if;
      end loop;
      return Left.B2.Data (1) = Right.B2.Data (1);
   end Same_Net;

   procedure Load_String
     (Model  : in out M.Net;
      Text   : String;
      Status : out M.Load_Status)
   is
      Buf : M.Weight_Chars := (others => ' ');
      N   : Natural := Text'Length;
   begin
      if N > M.Max_Weight_Text then
         N := M.Max_Weight_Text;
      end if;
      for I in 1 .. N loop
         Buf (I) := Text (Text'First + I - 1);
      end loop;
      M.Read_Weights (Model, Buf, N, Status);
   end Load_String;

   procedure Refuse_Broken_Shape
     (Model   : in out M.Net;
      Refused : out Boolean)
   is
      Copy   : constant M.Net := Model;
      Status : M.Load_Status;
      Text   : constant String :=
        "ada-ai-amplifier weights 1" & LF & "shape 2 4 1" & LF;
   begin
      Load_String (Model, Text, Status);
      Refused := Status = M.Bad_Shape and then Same_Net (Model, Copy);
      if Status /= M.Loaded then
         Model := Copy;
      end if;
   end Refuse_Broken_Shape;

   procedure Load_Zero_File (Model : in out M.Net) is
      Blank  : M.Net := Model;
      Text   : M.Weight_Chars;
      Count  : Natural;
      Status : M.Load_Status;
   begin
      Blank.W1.Data := (others => (others => 0.0));
      Blank.B1.Data := (others => 0.0);
      Blank.W2.Data := (others => (others => 0.0));
      Blank.B2.Data := (others => 0.0);
      M.Write_Weights (Blank, Text, Count);
      M.Read_Weights (Model, Text, Count, Status);
   end Load_Zero_File;

   procedure Measure (Item : in out Picture) is
      Data : constant M.Sample_List := M.Make_Dataset (M.XOR_Points);
      Y    : Float;
   begin
      Item.Weights_OK := Weights_OK (Item.Model);
      Item.XOR_OK := False;
      Item.Loss_Finite := False;
      Item.Loss := 0.0;
      if not Item.Weights_OK then
         return;
      end if;
      Item.Loss := M.Mean_Loss (Item.Model, Data);
      if Item.Loss /= Item.Loss
        or else Item.Loss > 1.0e6
        or else Item.Loss < 0.0
      then
         return;
      end if;
      Item.Loss_Finite := True;
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

   function To_Facts (Item : Picture) return Trace_Rule.Facts is
     (Weights_OK  => Item.Weights_OK,
      Loss_Finite => Item.Loss_Finite,
      XOR_OK      => Item.XOR_OK,
      Loss        => Item.Loss);

   procedure Decide
     (Before  : Picture;
      After   : Picture;
      Verdict : out Verdict_Kind;
      Reason  : out Reason_Kind)
   is
      V : Trace_Rule.Verdict_Kind;
      R : Trace_Rule.Reason_Kind;
   begin
      Trace_Rule.Decide (To_Facts (Before), To_Facts (After), V, R);
      case V is
         when Trace_Rule.Fixes_It =>
            Verdict := Fixes_It;
         when Trace_Rule.No_Better =>
            Verdict := No_Better;
         when Trace_Rule.Makes_It_Worse =>
            Verdict := Makes_It_Worse;
      end case;
      case R is
         when Trace_Rule.XOR_Returned =>
            Reason := XOR_Returned;
         when Trace_Rule.XOR_Still_Missed =>
            Reason := XOR_Still_Missed;
         when Trace_Rule.XOR_Left =>
            Reason := XOR_Left;
         when Trace_Rule.Loss_Rose =>
            Reason := Loss_Rose;
         when Trace_Rule.Loss_Did_Not_Fall =>
            Reason := Loss_Did_Not_Fall;
         when Trace_Rule.Weights_Invalid =>
            Reason := Weights_Invalid;
      end case;
   end Decide;

   procedure Judge_Pair
     (Before  : M.Net;
      After   : M.Net;
      Verdict : out Verdict_Kind;
      Reason  : out Reason_Kind)
   is
      Was : Picture;
      Now : Picture;
   begin
      Was.Model := Before;
      Now.Model := After;
      Measure (Was);
      Measure (Now);
      Decide (Was, Now, Verdict, Reason);
   end Judge_Pair;

   function Blank_Desc return Trace_Desc is
      Item : Trace_Desc;
   begin
      return Item;
   end Blank_Desc;

   function Named (Text : String) return Trace_Desc is
      Item : Trace_Desc := Blank_Desc;
   begin
      Item.NLen := Text'Length;
      Item.Name (1 .. Text'Length) := Text;
      return Item;
   end Named;

   function Catalog (Index : Positive) return Trace_Desc is
      Item : Trace_Desc;
   begin
      case Index is
         when 1 =>
            Item := Named ("rate-diverges");
            Item.Acts (1) := Seed_1;
            Item.Acts (2) := Train_40;
            Item.Acts (3) := Spike;
            Item.Count := 3;
            Item.Good := Rate_1_Train_200;
            Item.Bad := Invert_Out;
         when 2 =>
            Item := Named ("padded-shape");
            Item.Acts (1) := Hand;
            Item.Acts (2) := Bad_File;
            Item.Acts (3) := Zero_File;
            Item.Count := 3;
            Item.Good := Hand_Net;
            Item.Bad := Train_200;
         when 3 =>
            Item := Named ("silenced-and");
            Item.Acts (1) := Hand;
            Item.Acts (2) := Silence;
            Item.Count := 2;
            Item.Good := Revert_Edit;
            Item.Bad := Flip_Or;
         when others =>
            Item := Named ("stopped-early");
            Item.Acts (1) := Seed_1;
            Item.Acts (2) := Train_10;
            Item.Count := 2;
            Item.Good := Train_200;
            Item.Bad := Rate_5_Train_10;
      end case;
      return Item;
   end Catalog;

   procedure Apply_Act
     (Kind  : Act_Kind;
      Item  : in out Picture;
      Line  : out String;
      Last  : out Natural)
   is
      Data : constant M.Sample_List := M.Make_Dataset (M.XOR_Points);
      Loss : Float;
      Ignored : Boolean;
   begin
      Line := (others => ' ');
      Last := 0;
      case Kind is
         when Seed_1 =>
            M.Initialize (Item.Model, M.Init_Seed, 1.0);
            Add (Line, Last, "Seed 20261104 at learning rate 1.");
         when Train_40 =>
            M.Train (Item.Model, Data, 40, Loss);
            Add (Line, Last, "Train 40 steps at rate 1.");
         when Spike =>
            --  5.0 is Rate_Max, the top of the interval Train accepts.
            --  Fifteen steps from the 40-step net drive the loss up.
            Item.Model.Rate := 5.0;
            M.Train (Item.Model, Data, 15, Loss);
            Add (Line, Last,
              "Wrong turn: set the learning rate to 5 and train 15 steps.");
         when Hand =>
            Item.Model := M.Hand_XOR;
            Add (Line, Last,
              "Load the hand-written XOR net. No training step.");
         when Bad_File =>
            Refuse_Broken_Shape (Item.Model, Ignored);
            if Ignored then
               Add (Line, Last, "Load a weight file with shape 2 4 1.");
               Add (Line, Last, " The load is refused and the net stays.");
            else
               Add (Line, Last, "Load a weight file with shape 2 4 1.");
               Add (Line, Last, " The load was not the refusal");
               Add (Line, Last, " this trace records.");
            end if;
         when Zero_File =>
            --  A 2-8-1 file the writer emits from a zero net. The
            --  shape line passes. The values do not learn: every
            --  hidden unit is 0, so the gradients stay 0.
            Load_Zero_File (Item.Model);
            Add (Line, Last, "Wrong turn: load a shape 2 8 1 file");
            Add (Line, Last, " padded with zeros, output included.");
         when Train_10 =>
            M.Train (Item.Model, Data, 10, Loss);
            Add (Line, Last, "Wrong turn: train 10 steps at rate 1 and stop.");
         when Silence =>
            M.Apply_Preset (Item.Model, M.Silence_Hidden_2);
            Add (Line, Last, "Wrong turn: set hidden 2's output weight to 0.");
      end case;
   end Apply_Act;

   procedure Replay
     (Index   : Positive;
      Now     : out Picture;
      Saved   : out Picture;
      Lines   : out Line_Store;
      Lengths : out Len_Store)
   is
      Desc : constant Trace_Desc := Catalog (Index);
   begin
      Lengths := (others => 0);
      Lines := (others => (others => ' '));
      M.Initialize (Now.Model, M.Init_Seed, 1.0);
      Measure (Now);
      Saved := Now;
      for I in 1 .. Desc.Count loop
         if I = Desc.Count then
            Saved := Now;
         end if;
         Apply_Act (Desc.Acts (I), Now, Lines (I), Lengths (I));
         Measure (Now);
      end loop;
   end Replay;

   procedure Apply_Step
     (Which : Proposal;
      Saved : Picture;
      Work  : in out Picture)
   is
      Data : constant M.Sample_List := M.Make_Dataset (M.XOR_Points);
      Loss : Float;
      Ignored : Boolean;
   begin
      case Which is
         when Rate_1_Train_200 =>
            Work.Model.Rate := 1.0;
            M.Train (Work.Model, Data, 200, Loss);
         when Rate_5_Train_10 =>
            Work.Model.Rate := 5.0;
            M.Train (Work.Model, Data, 10, Loss);
         when Train_200 =>
            M.Train (Work.Model, Data, 200, Loss);
         when Train_8 =>
            M.Train (Work.Model, Data, 8, Loss);
         when Hand_Net =>
            Work.Model := M.Hand_XOR;
         when Revert_Edit =>
            Work.Model := Saved.Model;
         when Silence_And =>
            M.Apply_Preset (Work.Model, M.Silence_Hidden_2);
         when Flip_Or =>
            M.Apply_Preset (Work.Model, M.Flip_Hidden_1);
         when Invert_Out =>
            M.Apply_Preset (Work.Model, M.Invert_Output);
         when Load_Bad_Shape =>
            Refuse_Broken_Shape (Work.Model, Ignored);
      end case;
   end Apply_Step;

   function Proposal_Code (Which : Proposal) return Integer is
     (Proposal'Pos (Which) + 1);

   procedure Proposal_From_Code
     (Code  : Integer;
      Which : out Proposal;
      OK    : out Boolean)
   is
   begin
      if Code < 1 or else Code > Menu_Count then
         Which := Train_200;
         OK := False;
         return;
      end if;
      Which := Proposal'Val (Code - 1);
      OK := True;
   end Proposal_From_Code;

   procedure Put_Word
     (Text : String;
      Buf  : out String;
      Last : out Natural)
   is
   begin
      Buf := (others => ' ');
      Last := 0;
      Add (Buf, Last, Text);
   end Put_Word;

   procedure Proposal_Word
     (Which : Proposal;
      Text  : out String;
      Last  : out Natural)
   is
   begin
      case Which is
         when Rate_1_Train_200 =>
            Put_Word ("rate-1-train-200", Text, Last);
         when Rate_5_Train_10 =>
            Put_Word ("rate-5-train-10", Text, Last);
         when Train_200 =>
            Put_Word ("train-200", Text, Last);
         when Train_8 =>
            Put_Word ("train-8", Text, Last);
         when Hand_Net =>
            Put_Word ("hand-xor", Text, Last);
         when Revert_Edit =>
            Put_Word ("revert-edit", Text, Last);
         when Silence_And =>
            Put_Word ("silence-and", Text, Last);
         when Flip_Or =>
            Put_Word ("flip-or", Text, Last);
         when Invert_Out =>
            Put_Word ("invert-output", Text, Last);
         when Load_Bad_Shape =>
            Put_Word ("load-bad-shape", Text, Last);
      end case;
   end Proposal_Word;

   procedure Proposal_Label
     (Which : Proposal;
      Text  : out String;
      Last  : out Natural)
   is
   begin
      case Which is
         when Rate_1_Train_200 =>
            Put_Word ("Rate 1, train 200", Text, Last);
         when Rate_5_Train_10 =>
            Put_Word ("Rate 5, train 10", Text, Last);
         when Train_200 =>
            Put_Word ("Train 200 more", Text, Last);
         when Train_8 =>
            Put_Word ("Train 8 more", Text, Last);
         when Hand_Net =>
            Put_Word ("Hand-written XOR", Text, Last);
         when Revert_Edit =>
            Put_Word ("Revert last edit", Text, Last);
         when Silence_And =>
            Put_Word ("Silence hidden 2", Text, Last);
         when Flip_Or =>
            Put_Word ("Flip hidden 1", Text, Last);
         when Invert_Out =>
            Put_Word ("Invert output", Text, Last);
         when Load_Bad_Shape =>
            Put_Word ("Load broken shape", Text, Last);
      end case;
   end Proposal_Label;

   function Verdict_Code (Kind : Verdict_Kind) return Integer is
   begin
      case Kind is
         when Fixes_It =>
            return 1;
         when No_Better =>
            return 2;
         when Makes_It_Worse =>
            return 3;
      end case;
   end Verdict_Code;

   function Reason_Code (Kind : Reason_Kind) return Integer is
   begin
      case Kind is
         when XOR_Returned =>
            return 1;
         when XOR_Still_Missed =>
            return 2;
         when XOR_Left =>
            return 3;
         when Loss_Rose =>
            return 4;
         when Loss_Did_Not_Fall =>
            return 5;
         when Weights_Invalid =>
            return 6;
         when Not_A_Step =>
            return 7;
      end case;
   end Reason_Code;

   procedure Verdict_Word
     (Kind : Verdict_Kind;
      Text : out String;
      Last : out Natural)
   is
   begin
      case Kind is
         when Fixes_It =>
            Put_Word ("fixes-it", Text, Last);
         when No_Better =>
            Put_Word ("no-better", Text, Last);
         when Makes_It_Worse =>
            Put_Word ("makes-it-worse", Text, Last);
      end case;
   end Verdict_Word;

   procedure Reason_Word
     (Kind : Reason_Kind;
      Text : out String;
      Last : out Natural)
   is
   begin
      case Kind is
         when XOR_Returned =>
            Put_Word ("xor-returned", Text, Last);
         when XOR_Still_Missed =>
            Put_Word ("xor-still-missed", Text, Last);
         when XOR_Left =>
            Put_Word ("xor-left", Text, Last);
         when Loss_Rose =>
            Put_Word ("loss-rose", Text, Last);
         when Loss_Did_Not_Fall =>
            Put_Word ("loss-did-not-fall", Text, Last);
         when Weights_Invalid =>
            Put_Word ("weights-invalid", Text, Last);
         when Not_A_Step =>
            Put_Word ("not-a-step", Text, Last);
      end case;
   end Reason_Word;

   function Live (Index : Natural) return Boolean is
     (Index in 1 .. Trace_Count);

   procedure Trace_Name
     (Index : Natural;
      Text  : out String;
      Last  : out Natural)
   is
      Desc : Trace_Desc;
   begin
      Text := (others => ' ');
      Last := 0;
      if not Live (Index) then
         return;
      end if;
      Desc := Catalog (Index);
      Add (Text, Last, Desc.Name (1 .. Desc.NLen));
   end Trace_Name;

   function Step_Count (Index : Natural) return Natural is
   begin
      if not Live (Index) then
         return 0;
      end if;
      return Catalog (Index).Count;
   end Step_Count;

   function Wrong_At (Index : Natural) return Natural is
     (Step_Count (Index));

   procedure Step_Line
     (Index : Natural;
      Step  : Natural;
      Text  : out String;
      Last  : out Natural)
   is
      Now     : Picture;
      Saved   : Picture;
      Lines   : Line_Store;
      Lengths : Len_Store;
   begin
      Text := (others => ' ');
      Last := 0;
      if not Live (Index) or else Step < 1 or else Step > Step_Count (Index)
      then
         return;
      end if;
      Replay (Index, Now, Saved, Lines, Lengths);
      Last := Lengths (Step);
      if Last >= 1 then
         Text (Text'First .. Text'First + Last - 1) :=
           Lines (Step) (1 .. Last);
      end if;
   end Step_Line;

   procedure Known_Good
     (Index : Natural;
      Which : out Proposal;
      OK    : out Boolean)
   is
   begin
      if not Live (Index) then
         Which := Train_200;
         OK := False;
         return;
      end if;
      Which := Catalog (Index).Good;
      OK := True;
   end Known_Good;

   procedure Stored_Bad
     (Index : Natural;
      Which : out Proposal;
      OK    : out Boolean)
   is
   begin
      if not Live (Index) then
         Which := Train_8;
         OK := False;
         return;
      end if;
      Which := Catalog (Index).Bad;
      OK := True;
   end Stored_Bad;

   procedure Judge
     (Index       : Natural;
      Code        : Integer;
      Verdict     : out Verdict_Kind;
      Reason      : out Reason_Kind;
      Before_Loss : out Float;
      After_Loss  : out Float;
      Before_XOR  : out Boolean;
      After_XOR   : out Boolean;
      OK          : out Boolean)
   is
      Now, Saved, Work : Picture;
      Lines            : Line_Store;
      Lengths          : Len_Store;
      Which            : Proposal;
      Known            : Boolean;
   begin
      Before_Loss := 0.0;
      After_Loss := 0.0;
      Before_XOR := False;
      After_XOR := False;
      Verdict := No_Better;
      Reason := Not_A_Step;
      OK := Live (Index);
      if not OK then
         return;
      end if;
      Replay (Index, Now, Saved, Lines, Lengths);
      Before_Loss := Now.Loss;
      Before_XOR := Now.XOR_OK;
      Proposal_From_Code (Code, Which, Known);
      if not Known then
         After_Loss := Now.Loss;
         After_XOR := Now.XOR_OK;
         return;
      end if;
      Work := Now;
      Apply_Step (Which, Saved, Work);
      Measure (Work);
      After_Loss := Work.Loss;
      After_XOR := Work.XOR_OK;
      Decide (Now, Work, Verdict, Reason);
   end Judge;

   procedure State_Line
     (Index : Natural;
      Text  : out String;
      Last  : out Natural)
   is
      Now     : Picture;
      Saved   : Picture;
      Lines   : Line_Store;
      Lengths : Len_Store;
   begin
      Text := (others => ' ');
      Last := 0;
      if not Live (Index) then
         return;
      end if;
      Replay (Index, Now, Saved, Lines, Lengths);
      if not Now.Weights_OK or else not Now.Loss_Finite then
         Add (Text, Last, "weights invalid.");
         return;
      end if;
      Add (Text, Last, "loss ");
      Add_Loss (Text, Last, Now.Loss);
      if Now.XOR_OK then
         Add (Text, Last, ". xor in range. weights valid.");
      else
         Add (Text, Last, ". xor missed. weights valid.");
      end if;
   end State_Line;

   procedure Report_Line
     (Index : Natural;
      Code  : Integer;
      Text  : out String;
      Last  : out Natural)
   is
      Verdict     : Verdict_Kind;
      Reason      : Reason_Kind;
      Before_Loss : Float;
      After_Loss  : Float;
      Before_XOR  : Boolean;
      After_XOR   : Boolean;
      OK          : Boolean;
      Word        : String (1 .. Max_Name);
      WLast       : Natural;
      Which       : Proposal;
      Known       : Boolean;
   begin
      Text := (others => ' ');
      Last := 0;
      Judge
        (Index, Code, Verdict, Reason,
         Before_Loss, After_Loss, Before_XOR, After_XOR, OK);
      if not OK then
         return;
      end if;
      Proposal_From_Code (Code, Which, Known);
      if Known then
         Proposal_Label (Which, Word, WLast);
      else
         Put_Word ("not-a-step", Word, WLast);
      end if;
      if WLast >= 1 then
         Add (Text, Last, Word (1 .. WLast));
      end if;
      Add (Text, Last, ". ");
      Verdict_Word (Verdict, Word, WLast);
      Add (Text, Last, Word (1 .. WLast));
      Add (Text, Last, ". ");
      Reason_Word (Reason, Word, WLast);
      Add (Text, Last, Word (1 .. WLast));
      Add (Text, Last, ". loss ");
      Add_Loss (Text, Last, Before_Loss);
      Add (Text, Last, " to ");
      Add_Loss (Text, Last, After_Loss);
      Add_C (Text, Last, '.');
   end Report_Line;

   --  Character by character. A returned slice uses the
   --  secondary stack, and a slice compare pulls in memcmp.
   --  This wasm link has neither symbol.
   procedure Trim_Bounds
     (Text  : String;
      First : out Natural;
      Last  : out Natural)
   is
   begin
      First := Text'First;
      Last := Text'Last;
      while First <= Last
        and then (Text (First) = ' ' or else Text (First) = LF
                  or else Text (First) = Character'Val (13)
                  or else Text (First) = Character'Val (9))
      loop
         First := First + 1;
      end loop;
      while Last >= First
        and then (Text (Last) = ' ' or else Text (Last) = LF
                  or else Text (Last) = Character'Val (13)
                  or else Text (Last) = Character'Val (9))
      loop
         Last := Last - 1;
      end loop;
   end Trim_Bounds;

   function Same_Span
     (Text       : String;
      First      : Natural;
      Last       : Natural;
      Word       : String) return Boolean
   is
   begin
      if Last < First then
         return Word'Length = 0;
      end if;
      if Last - First + 1 /= Word'Length then
         return False;
      end if;
      for I in Word'Range loop
         if Text (First + (I - Word'First)) /= Word (I) then
            return False;
         end if;
      end loop;
      return True;
   end Same_Span;

   procedure Parse_Proposal
     (Text  : String;
      Which : out Proposal;
      OK    : out Boolean)
   is
      First : Natural;
      TLast : Natural;
      Word : String (1 .. Max_Name);
      Last : Natural;
   begin
      Which := Train_200;
      OK := False;
      Trim_Bounds (Text, First, TLast);
      for Item in Proposal loop
         Proposal_Word (Item, Word, Last);
         if Last >= 1
           and then Same_Span (Text, First, TLast, Word (1 .. Last))
         then
            Which := Item;
            OK := True;
            return;
         end if;
      end loop;
   end Parse_Proposal;

   procedure Prompt_For
     (Index : Natural;
      Text  : out String;
      Last  : out Natural;
      OK    : out Boolean)
   is
      Name  : String (1 .. Max_Name);
      NLast : Natural;
      Line  : String (1 .. Max_Line);
      LLast : Natural;
      Word  : String (1 .. Max_Name);
      WLast : Natural;
   begin
      Text := (others => ' ');
      Last := 0;
      OK := False;
      if not Live (Index) then
         return;
      end if;
      Trace_Name (Index, Name, NLast);
      Add (Text, Last,
        "The network is the XOR trainer in this repository: 2 inputs, ");
      Add (Text, Last,
        "8 tanh units, 1 sigmoid output. The trace was recorded here. ");
      Add (Text, Last,
        "It ends on a wrong turn.");
      Add (Text, Last, " Reply with one menu name and no other text.");
      Add_C (Text, Last, LF);
      Add (Text, Last, "Trace ");
      Add (Text, Last, Name (1 .. NLast));
      Add_C (Text, Last, LF);
      for Step in 1 .. Step_Count (Index) loop
         Step_Line (Index, Step, Line, LLast);
         Add (Text, Last, Integer'Image (Step));
         Add (Text, Last, ". ");
         if LLast >= 1 then
            Add (Text, Last, Line (1 .. LLast));
         end if;
         Add_C (Text, Last, LF);
      end loop;
      State_Line (Index, Line, LLast);
      if LLast >= 1 then
         Add (Text, Last, Line (1 .. LLast));
         Add_C (Text, Last, LF);
      end if;
      Add (Text, Last, "Menu:");
      Add_C (Text, Last, LF);
      for Item in Proposal loop
         Proposal_Word (Item, Word, WLast);
         if WLast >= 1 then
            Add (Text, Last, Word (1 .. WLast));
            Add_C (Text, Last, LF);
         end if;
      end loop;
      OK := Last >= 1 and then Last < Text'Last;
   end Prompt_For;

   procedure Add_Escaped
     (Buf  : in out String;
      Last : in out Natural;
      Text : String;
      OK   : in out Boolean)
   is
   begin
      for C of Text loop
         if C = '"' or else C = '\' then
            Add_C (Buf, Last, '\');
            Add_C (Buf, Last, C);
         elsif C = LF then
            Add (Buf, Last, "\n");
         elsif C = Character'Val (13) then
            Add (Buf, Last, "\r");
         elsif C = Character'Val (9) then
            Add (Buf, Last, "\t");
         elsif Character'Pos (C) < 32 then
            OK := False;
            return;
         else
            Add_C (Buf, Last, C);
         end if;
         if Last >= Buf'Last then
            OK := False;
            return;
         end if;
      end loop;
   end Add_Escaped;

   procedure Request_JSON
     (Model  : String;
      Prompt : String;
      Text   : out String;
      Last   : out Natural;
      OK     : out Boolean)
   is
   begin
      Text := (others => ' ');
      Last := 0;
      OK := True;
      Add (Text, Last, "{""model"":""");
      Add_Escaped (Text, Last, Model, OK);
      Add (Text, Last, """,""temperature"":0,""messages"":[");
      Add (Text, Last, "{""role"":""user"",""content"":""");
      Add_Escaped (Text, Last, Prompt, OK);
      Add (Text, Last, """}]}");
      if not OK or else Last >= Text'Last or else Last < 1 then
         Last := 0;
         OK := False;
      end if;
   end Request_JSON;

   procedure Assistant_Text
     (Reply : String;
      Text  : out String;
      Last  : out Natural;
      OK    : out Boolean)
   is
      Mark : constant String := """content""";
      From : Natural;
      I    : Natural;
      Low  : Boolean;
   begin
      Text := (others => ' ');
      Last := 0;
      OK := False;
      From := 0;
      I := Reply'First;
      while I + Mark'Length - 1 <= Reply'Last loop
         if Reply (I .. I + Mark'Length - 1) = Mark then
            From := I + Mark'Length;
            exit;
         end if;
         I := I + 1;
      end loop;
      if From = 0 then
         return;
      end if;
      while From <= Reply'Last
        and then (Reply (From) = ' '
                  or else Reply (From) = Character'Val (9)
                  or else Reply (From) = LF
                  or else Reply (From) = Character'Val (13))
      loop
         From := From + 1;
      end loop;
      if From > Reply'Last or else Reply (From) /= ':' then
         return;
      end if;
      From := From + 1;
      while From <= Reply'Last
        and then (Reply (From) = ' '
                  or else Reply (From) = Character'Val (9))
      loop
         From := From + 1;
      end loop;
      if From > Reply'Last or else Reply (From) /= '"' then
         return;
      end if;
      From := From + 1;
      while From <= Reply'Last loop
         if Reply (From) = '"' then
            OK := True;
            return;
         end if;
         if Reply (From) = '\' then
            if From = Reply'Last then
               return;
            end if;
            From := From + 1;
            case Reply (From) is
               when '"' | '\' | '/' =>
                  Add_C (Text, Last, Reply (From));
               when 'n' =>
                  Add_C (Text, Last, LF);
               when 'r' =>
                  Add_C (Text, Last, Character'Val (13));
               when 't' =>
                  Add_C (Text, Last, Character'Val (9));
               when 'b' | 'f' =>
                  null;
               when others =>
                  return;
            end case;
         else
            Low := Character'Pos (Reply (From)) < 32;
            if Low then
               return;
            end if;
            Add_C (Text, Last, Reply (From));
         end if;
         From := From + 1;
      end loop;
   end Assistant_Text;

end AI_Amplifier.Traces;
