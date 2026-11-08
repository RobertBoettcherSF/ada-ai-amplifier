package body AI_Amplifier.Reward
  with SPARK_Mode => Off
is

   package M renames AI_Amplifier.MLP;

   function Zero_Net return M.Net is
      Model : M.Net;
   begin
      Model.W1 :=
        (Rows => M.Hidden,
         Cols => M.Inputs,
         Data => (others => (others => 0.0)));
      Model.B1 := (Length => M.Hidden, Data => (others => 0.0));
      Model.W2 :=
        (Rows => M.Outputs,
         Cols => M.Hidden,
         Data => (others => (others => 0.0)));
      Model.B2 :=
        (Length => M.Outputs, Data => (others => 0.0));
      Model.Rate := Search_Rate;
      return Model;
   end Zero_Net;

   function Empty_Submission return Submission is
      Item : Submission;
   begin
      Item.Model := Zero_Net;
      return Item;
   end Empty_Submission;

   procedure Set_Name (Item : in out Submission; Name : String) is
   begin
      Item.Name_Last := 0;
      if Name'Length > Max_Name then
         return;
      end if;
      Item.Name (1 .. Name'Length) := Name;
      Item.Name_Last := Name'Length;
   end Set_Name;

   procedure Set_Stamp (Item : in out Submission; Stamp : String) is
   begin
      Item.Stamp_Last := 0;
      if Stamp'Length > Max_Stamp then
         return;
      end if;
      Item.Stamp (1 .. Stamp'Length) := Stamp;
      Item.Stamp_Last := Stamp'Length;
   end Set_Stamp;

   function XOR_Data return M.Sample_List is
   begin
      return M.Make_Dataset (M.XOR_Points);
   end XOR_Data;

   procedure Fill_Reported (Item : in out Submission) is
      Data : constant M.Sample_List := XOR_Data;
   begin
      Item.Reported_Count := Data.Count;
      if Item.Reported_Count > XOR_Count then
         Item.Reported_Count := XOR_Count;
      end if;
      for I in 1 .. Item.Reported_Count loop
         Item.Reported (I) :=
           M.Predict (Item.Model, Data.Item (I).X);
      end loop;
   end Fill_Reported;

   function Margin_Hits (Model : M.Net) return Natural is
      Data : constant M.Sample_List := XOR_Data;
      Hits : Natural := 0;
      Y    : Float;
   begin
      for I in 1 .. Data.Count loop
         Y := M.Predict (Model, Data.Item (I).X);
         if Data.Item (I).Label >= 0.5 then
            if Y >= High_Output then
               Hits := Hits + 1;
            end if;
         elsif Y <= Low_Output then
            Hits := Hits + 1;
         end if;
      end loop;
      return Hits;
   end Margin_Hits;

   function Proxy (Model : M.Net) return Float is
      Data : constant M.Sample_List := XOR_Data;
      Sum  : Float := 0.0;
      Y, T : Float;
   begin
      if Data.Count = 0 then
         return 0.0;
      end if;
      for I in 1 .. Data.Count loop
         Y := M.Predict (Model, Data.Item (I).X);
         T := (Y - 0.5) / 0.5;
         if T < 0.0 then
            T := 0.0;
         elsif T > 1.0 then
            T := 1.0;
         end if;
         Sum := Sum + T;
      end loop;
      return Sum / Float (Data.Count);
   end Proxy;

   function Real_Score_Of (Model : M.Net) return Float is
      Data : constant M.Sample_List := XOR_Data;
   begin
      if Data.Count = 0 then
         return 0.0;
      end if;
      return Float (Margin_Hits (Model)) / Float (Data.Count);
   end Real_Score_Of;

   function Real_Pass (Model : M.Net) return Boolean is
      Data : constant M.Sample_List := XOR_Data;
   begin
      return Data.Count = XOR_Count
        and then Margin_Hits (Model) = XOR_Count;
   end Real_Pass;

   --  Character by character. A slice compare becomes memcmp,
   --  and this wasm link does not provide that symbol.
   function Same (Left, Right : String) return Boolean is
      I : Integer := Left'First;
      J : Integer := Right'First;
   begin
      if Left'Length /= Right'Length then
         return False;
      end if;
      while I <= Left'Last loop
         if Left (I) /= Right (J) then
            return False;
         end if;
         I := I + 1;
         J := J + 1;
      end loop;
      return True;
   end Same;

   function Stamp_Is_Shape (Item : Submission) return Boolean is
   begin
      if Item.Stamp_Last /= Shape_Stamp'Length then
         return False;
      end if;
      return Same (Item.Stamp (1 .. Item.Stamp_Last), Shape_Stamp);
   end Stamp_Is_Shape;

   procedure Grade (Item : in out Submission) is
      Data      : constant M.Sample_List := XOR_Data;
      Loss      : Float;
      Highs     : Natural := 0;
      Near_Half : Boolean;
   begin
      Loss := M.Mean_Loss (Item.Model, Data);
      Item.Real_Score := Real_Score_Of (Item.Model);
      Item.Counts := Real_Pass (Item.Model);
      Near_Half := Item.Reported_Count = XOR_Count;
      if Item.Reported_Count > 0 then
         for I in 1 .. Item.Reported_Count loop
            if abs (Item.Reported (I) - 0.5) > Half_Band then
               Near_Half := False;
            end if;
            if Item.Reported (I) > 0.5 then
               Highs := Highs + 1;
            end if;
         end loop;
      end if;
      if Item.Counts then
         Item.Gap := None;
         Item.Flawed := 1.0;
         return;
      end if;
      if Item.Has_Loss
        and then Item.Reported_Loss < Low_Loss
        and then Loss >= Low_Loss
      then
         Item.Gap := Reported_Loss;
         Item.Flawed := 1.0;
         return;
      end if;
      if Near_Half then
         Item.Gap := Constant_Half;
         Item.Flawed := 1.0;
         return;
      end if;
      if Highs >= 2 then
         Item.Gap := Two_Of_Four;
         Item.Flawed := 1.0;
         return;
      end if;
      if Stamp_Is_Shape (Item) then
         Item.Gap := Right_Stamp;
         Item.Flawed := 1.0;
         return;
      end if;
      Item.Gap := Unsolved;
      Item.Flawed := 0.0;
   end Grade;

   --  Trained from the trainer's seed at rate 1. The report is
   --  the loss and the outputs of that net. No figure is typed in.
   function Make_Honest return Submission is
      Item : Submission := Empty_Submission;
      Data : constant M.Sample_List := XOR_Data;
      Loss : Float;
   begin
      M.Initialize (Item.Model, M.Init_Seed, Search_Rate);
      M.Train (Item.Model, Data, Honest_Steps, Loss);
      Set_Name (Item, "honest-trained");
      Item.Has_Loss := True;
      Item.Reported_Loss := M.Mean_Loss (Item.Model, Data);
      Fill_Reported (Item);
      Set_Stamp (Item, Shape_Stamp);
      return Item;
   end Make_Honest;

   --  Trick: reported-loss. The net is all zeros. The loss
   --  figure is the constant Fake_Loss, not Mean_Loss.
   function Make_Hard_Coded return Submission is
      Item : Submission := Empty_Submission;
   begin
      Item.Model := Zero_Net;
      Set_Name (Item, "hard-coded-loss");
      Item.Has_Loss := True;
      Item.Reported_Loss := Fake_Loss;
      return Item;
   end Make_Hard_Coded;

   --  Trick: constant-half. The zero net really does output
   --  0.5, and the report says so four times. That is an answer
   --  format. It is not inside 0.8 and 0.2.
   function Make_Constant return Submission is
      Item : Submission := Empty_Submission;
      Data : constant M.Sample_List := XOR_Data;
   begin
      Item.Model := Zero_Net;
      Set_Name (Item, "constant-half");
      Item.Has_Loss := True;
      Item.Reported_Loss := M.Mean_Loss (Item.Model, Data);
      Item.Reported_Count := XOR_Count;
      Item.Reported := (others => 0.5);
      return Item;
   end Make_Constant;

   --  Trick: two-of-four. Hidden 1 follows x2 only, so (0,0)
   --  and (0,1) land on the right side and (1,0) and (1,1) do
   --  not. Two reported outputs are above 0.5.
   function Make_Memorized return Submission is
      Item : Submission := Empty_Submission;
      Data : constant M.Sample_List := XOR_Data;
   begin
      Item.Model := Zero_Net;
      Item.Model.W1.Data (1, 2) := 6.0;
      Item.Model.B1.Data (1) := -3.0;
      Item.Model.W2.Data (1, 1) := 6.0;
      Set_Name (Item, "memorized-two");
      Item.Has_Loss := True;
      Item.Reported_Loss := M.Mean_Loss (Item.Model, Data);
      Fill_Reported (Item);
      return Item;
   end Make_Memorized;

   --  Trick: right-stamp. The shape line is the one a weight
   --  file uses. The weights are the hand-written XOR net with
   --  the output layer negated, so the rerun is on the wrong
   --  side of every point. The report has no loss and no outputs.
   function Make_Stamp return Submission is
      Item : Submission := Empty_Submission;
   begin
      Item.Model := M.Hand_XOR;
      M.Apply_Preset (Item.Model, M.Invert_Output);
      Set_Name (Item, "right-stamp");
      Set_Stamp (Item, Shape_Stamp);
      return Item;
   end Make_Stamp;

   procedure Build (Bank : out Set) is
   begin
      Bank.Count := Submission_Count;
      for I in Bank.Slot'Range loop
         Bank.Slot (I) := Empty_Submission;
      end loop;
      Bank.Slot (1) := Make_Honest;
      Bank.Slot (2) := Make_Hard_Coded;
      Bank.Slot (3) := Make_Constant;
      Bank.Slot (4) := Make_Memorized;
      Bank.Slot (5) := Make_Stamp;
      for I in 1 .. Bank.Count loop
         Grade (Bank.Slot (I));
      end loop;
   end Build;

   function All_High return M.Sample_List is
      Data : M.Sample_List := XOR_Data;
   begin
      for I in 1 .. Data.Count loop
         Data.Item (I).Label := 1.0;
      end loop;
      return Data;
   end All_High;

   function Objective (Aim : Aim_Name) return M.Sample_List is
   begin
      if Aim = Flawed_Aim then
         return All_High;
      end if;
      return XOR_Data;
   end Objective;

   function Aimed (Aim : Aim_Name; Model : M.Net) return Float is
   begin
      if Aim = Flawed_Aim then
         return Proxy (Model);
      end if;
      return -M.Mean_Loss (Model, XOR_Data);
   end Aimed;

   procedure Hill_Step
     (Model : in out M.Net;
      Data  : M.Sample_List;
      Aim   : Aim_Name)
   is
      Rates : constant array (1 .. 3) of Float :=
        (1.0, 0.5, 0.25);
      Before     : constant M.Net := Model;
      Best       : M.Net := Model;
      Best_Score : constant Float := Aimed (Aim, Model);
      Trial      : M.Net;
      Loss       : Float;
      Score      : Float;
   begin
      for R of Rates loop
         Trial := Before;
         Trial.Rate := R;
         M.Train (Trial, Data, 1, Loss);
         Score := Aimed (Aim, Trial);
         if Loss >= 0.0 and then Score >= Best_Score - 1.0e-6 then
            Best := Trial;
            exit;
         end if;
      end loop;
      Model := Best;
      Model.Rate := Search_Rate;
   end Hill_Step;

   procedure Record_Point
     (Item  : in out Trace;
      Index : Positive;
      Model : M.Net)
   is
   begin
      if Index > Max_Points then
         return;
      end if;
      Item.Proxy (Index) := Proxy (Model);
      Item.Real_Score (Index) := Real_Score_Of (Model);
      Item.Passed (Index) := Real_Pass (Model);
   end Record_Point;

   procedure Search (Aim : Aim_Name; Result : out Trace) is
      Model : M.Net;
      Data  : constant M.Sample_List := Objective (Aim);
   begin
      Result := (others => <>);
      M.Initialize (Model, Search_Seed, Search_Rate);
      Result.Points := Search_Steps + 1;
      Record_Point (Result, 1, Model);
      for S in 1 .. Search_Steps loop
         Hill_Step (Model, Data, Aim);
         Record_Point (Result, S + 1, Model);
      end loop;
   end Search;

   procedure Put_Word
     (Text : out String;
      Last : out Natural;
      Word : String)
   is
   begin
      Last := 0;
      Text := (others => ' ');
      if Word'Length > Text'Length then
         return;
      end if;
      Text (Text'First .. Text'First + Word'Length - 1) := Word;
      Last := Word'Length;
   end Put_Word;

   procedure Gap_Word
     (Gap  : Gap_Name;
      Text : out String;
      Last : out Natural)
   is
   begin
      case Gap is
         when None =>
            Put_Word (Text, Last, "none");
         when Reported_Loss =>
            Put_Word (Text, Last, "reported-loss");
         when Constant_Half =>
            Put_Word (Text, Last, "constant-half");
         when Two_Of_Four =>
            Put_Word (Text, Last, "two-of-four");
         when Right_Stamp =>
            Put_Word (Text, Last, "right-stamp");
         when Unsolved =>
            Put_Word (Text, Last, "unsolved");
      end case;
   end Gap_Word;

   procedure Verdict_Word
     (Counts : Boolean;
      Text   : out String;
      Last   : out Natural)
   is
   begin
      if Counts then
         Put_Word (Text, Last, "counts");
      else
         Put_Word (Text, Last, "rejected");
      end if;
   end Verdict_Word;

   function Score_Text (Value : Float) return Score_Chars is
      Scaled : Integer;
      Text   : Score_Chars := "0.00";
   begin
      if Value <= 0.0 then
         return Text;
      end if;
      if Value >= 1.0 then
         Text := "1.00";
         return Text;
      end if;
      Scaled := Integer (Float'Rounding (Value * 100.0));
      if Scaled <= 0 then
         return Text;
      end if;
      if Scaled >= 100 then
         Text := "1.00";
         return Text;
      end if;
      Text (2) := '.';
      Text (3) := Character'Val (Character'Pos ('0') + Scaled / 10);
      Text (4) := Character'Val (Character'Pos ('0') + Scaled mod 10);
      return Text;
   end Score_Text;

   procedure Add
     (Buf  : in out String;
      Last : in out Natural;
      Item : String;
      OK   : in out Boolean)
   is
   begin
      if not OK or else Item'Length = 0 then
         return;
      end if;
      if Last > Buf'Last or else Item'Length > Buf'Last - Last then
         OK := False;
         return;
      end if;
      Buf (Last + 1 .. Last + Item'Length) := Item;
      Last := Last + Item'Length;
   end Add;

   procedure Add_Natural
     (Buf   : in out String;
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
      Add (Buf, Last, Digs (Top .. Digs'Last), OK);
   end Add_Natural;

   procedure Add_Pad
     (Buf   : in out String;
      Last  : in out Natural;
      Item  : String;
      Width : Positive;
      OK    : in out Boolean)
   is
      Spaces : constant String (1 .. 16) := (others => ' ');
      Gap    : Natural;
   begin
      Add (Buf, Last, Item, OK);
      if not OK or else Item'Length >= Width then
         return;
      end if;
      Gap := Width - Item'Length;
      if Gap > Spaces'Length then
         OK := False;
         return;
      end if;
      Add (Buf, Last, Spaces (1 .. Gap), OK);
   end Add_Pad;

   procedure Line_For
     (Bank  : Set;
      Index : Natural;
      Text  : out String;
      Last  : out Natural)
   is
      OK    : Boolean := True;
      Item  : Submission;
      Word  : String (1 .. 16);
      WLast : Natural;
   begin
      Last := 0;
      Text := (others => ' ');
      if Index < 1 or else Index > Bank.Count then
         return;
      end if;
      Item := Bank.Slot (Index);
      if Item.Name_Last > 0 then
         Add_Pad (Text, Last, Item.Name (1 .. Item.Name_Last), 16, OK);
      else
         Add_Pad (Text, Last, "", 16, OK);
      end if;
      Add (Text, Last, "  ", OK);
      Add_Pad (Text, Last, Score_Text (Item.Flawed), 6, OK);
      Add (Text, Last, "  ", OK);
      Add_Pad (Text, Last, Score_Text (Item.Real_Score), 6, OK);
      Add (Text, Last, "  ", OK);
      Verdict_Word (Item.Counts, Word, WLast);
      if WLast > 0 then
         Add_Pad (Text, Last, Word (1 .. WLast), 8, OK);
      end if;
      Add (Text, Last, "  ", OK);
      Gap_Word (Item.Gap, Word, WLast);
      if WLast > 0 then
         Add (Text, Last, Word (1 .. WLast), OK);
      end if;
      if not OK then
         Last := 0;
      end if;
   end Line_For;

   procedure Header_Line (Text : out String; Last : out Natural) is
      OK : Boolean := True;
   begin
      Last := 0;
      Text := (others => ' ');
      Add_Pad (Text, Last, "name", 16, OK);
      Add (Text, Last, "  ", OK);
      Add_Pad (Text, Last, "flawed", 6, OK);
      Add (Text, Last, "  ", OK);
      Add_Pad (Text, Last, "real", 6, OK);
      Add (Text, Last, "  ", OK);
      Add_Pad (Text, Last, "verdict", 8, OK);
      Add (Text, Last, "  ", OK);
      Add (Text, Last, "gap", OK);
      if not OK then
         Last := 0;
      end if;
   end Header_Line;

   function Accepted (Bank : Set) return Natural is
      N : Natural := 0;
   begin
      for I in 1 .. Bank.Count loop
         if Bank.Slot (I).Counts then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Accepted;

   procedure Tally_Line
     (Bank : Set;
      Text : out String;
      Last : out Natural)
   is
      OK : Boolean := True;
   begin
      Last := 0;
      Text := (others => ' ');
      Add (Text, Last, "Accepted: ", OK);
      Add_Natural (Text, Last, Accepted (Bank), OK);
      Add (Text, Last, " of ", OK);
      Add_Natural (Text, Last, Bank.Count, OK);
      Add (Text, Last, ". Only the real check counts.", OK);
      if not OK then
         Last := 0;
      end if;
   end Tally_Line;

   procedure Stat_Line
     (Bank : Set;
      Text : out String;
      Last : out Natural)
   is
      OK : Boolean := True;
   begin
      Last := 0;
      Text := (others => ' ');
      Add_Natural (Text, Last, Bank.Count, OK);
      Add (Text, Last, " submissions. ", OK);
      Add_Natural (Text, Last, Accepted (Bank), OK);
      if Accepted (Bank) = 1 then
         Add (Text, Last, " passes the real check. Seed ", OK);
      else
         Add (Text, Last, " pass the real check. Seed ", OK);
      end if;
      Add_Natural (Text, Last, Search_Seed, OK);
      Add (Text, Last, ". ", OK);
      Add_Natural (Text, Last, Search_Steps, OK);
      Add (Text, Last, " steps.", OK);
      if not OK then
         Last := 0;
      end if;
   end Stat_Line;

   procedure End_Line
     (Item : Trace;
      Text : out String;
      Last : out Natural)
   is
      OK : Boolean := True;
   begin
      Last := 0;
      Text := (others => ' ');
      if Item.Points < 1 then
         Add (Text, Last, "The search did not run.", OK);
         if not OK then
            Last := 0;
         end if;
         return;
      end if;
      Add (Text, Last, "Proxy ", OK);
      Add (Text, Last, Score_Text (Item.Proxy (Item.Points)), OK);
      Add (Text, Last, ". Real ", OK);
      Add (Text, Last,
           Score_Text (Item.Real_Score (Item.Points)), OK);
      Add (Text, Last, ". Real check ", OK);
      if Item.Passed (Item.Points) then
         Add (Text, Last, "passes.", OK);
      else
         Add (Text, Last, "fails.", OK);
      end if;
      if not OK then
         Last := 0;
      end if;
   end End_Line;

end AI_Amplifier.Reward;
