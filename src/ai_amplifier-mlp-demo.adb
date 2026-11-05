with AI_Amplifier.Tensors;

package body AI_Amplifier.MLP.Demo
  with SPARK_Mode => Off
is

   Which   : Dataset_Kind := XOR_Points;
   Data    : Sample_List;
   Model   : Net;
   Epochs  : Natural := 0;
   Current : Float := 0.0;
   Ready   : Boolean := False;

   type Curve_Array is array (1 .. Curve_Max) of Float;

   Curve       : Curve_Array := (others => 0.0);
   Curve_Used  : Natural := 0;
   Curve_Stride : Positive := 1;
   Curve_Seen  : Natural := 0;

   Grid : array (1 .. Grid_Side, 1 .. Grid_Side) of Float :=
     (others => (others => 0.0));

   Trained        : Net;
   Trained_Epochs : Natural := 0;
   Trained_Curve  : Curve_Array := (others => 0.0);
   Trained_Used   : Natural := 0;
   Trained_Stride : Positive := 1;
   Trained_Seen   : Natural := 0;

   Note_Max  : constant := 320;
   Note_Text : String (1 .. Note_Max) := (others => ' ');
   Note_Len  : Natural := 0;

   Import_Buf      : Weight_Chars := (others => ' ');
   Import_Len      : Natural := 0;
   Import_Overflow : Boolean := False;
   Export_Buf      : Weight_Chars := (others => ' ');
   Export_Len      : Natural := 0;

   Name_Buf : String (1 .. 8) := (others => ' ');
   Name_Len : Natural := 0;

   Param_N : constant :=
     Hidden * Inputs + Hidden + Outputs * Hidden + Outputs;

   procedure Note_Clear is
   begin
      Note_Len := 0;
   end Note_Clear;

   procedure Note_Add (S : String) is
   begin
      for C of S loop
         if Note_Len < Note_Max then
            Note_Len := Note_Len + 1;
            Note_Text (Note_Len) := C;
         end if;
      end loop;
   end Note_Add;

   procedure Note_Add_Int (N : Natural) is
      Digs  : array (1 .. 12) of Character := (others => '0');
      Count : Natural := 0;
      V     : Natural := N;
   begin
      if V = 0 then
         Note_Add ("0");
         return;
      end if;
      while V > 0 and then Count < Digs'Last loop
         Count := Count + 1;
         Digs (Count) :=
           Character'Val (Character'Pos ('0') + V mod 10);
         V := V / 10;
      end loop;
      for I in reverse 1 .. Count loop
         Note_Add ((1 => Digs (I)));
      end loop;
   end Note_Add_Int;

   procedure Set_Note (S : String) is
   begin
      Note_Clear;
      Note_Add (S);
   end Set_Note;

   procedure Fill_Name (Index : Integer) is
      procedure Put (C : Character) is
      begin
         if Name_Len < Name_Buf'Last then
            Name_Len := Name_Len + 1;
            Name_Buf (Name_Len) := C;
         end if;
      end Put;

      procedure Put_Digit (N : Integer) is
      begin
         Put (Character'Val (Character'Pos ('0') + N));
      end Put_Digit;

      R    : Integer;
      Slot : Integer;
   begin
      Name_Len := 0;
      --  Three fields per hidden unit, so x1, x2, and the bias sit
      --  together. The output weights follow, then the output bias.
      if Index in 1 .. Hidden * 3 then
         R := (Index - 1) / 3 + 1;
         Slot := (Index - 1) mod 3;
         Put ('h');
         Put_Digit (R);
         Put ('.');
         if Slot = 2 then
            Put ('b');
         else
            Put ('x');
            Put_Digit (Slot + 1);
         end if;
      elsif Index in Hidden * 3 + 1 .. Hidden * 3 + Hidden then
         R := Index - Hidden * 3;
         Put ('y');
         Put ('.');
         Put ('h');
         Put_Digit (R);
      elsif Index = Param_N then
         Put ('y');
         Put ('.');
         Put ('b');
      end if;
   end Fill_Name;

   function Decode (Kind : Integer) return Dataset_Kind is
   begin
      case Kind is
         when 1 =>
            return Two_Circles;
         when 2 =>
            return Two_Spirals;
         when others =>
            return XOR_Points;
      end case;
   end Decode;

   procedure Clear_Curve is
   begin
      Curve_Used := 0;
      Curve_Stride := 1;
      Curve_Seen := 0;
   end Clear_Curve;

   --  Keep the whole run on a fixed buffer. Once it is full, drop
   --  every other stored point and record half as often. The newest
   --  loss still overwrites the tip between recorded steps, so the
   --  right-hand end is the loss just computed.
   procedure Remember (Value : Float) is
   begin
      Curve_Seen := Curve_Seen + 1;
      if Curve_Seen mod Curve_Stride /= 0 then
         if Curve_Used > 0 then
            Curve (Curve_Used) := Value;
         end if;
         return;
      end if;

      if Curve_Used = Curve_Max then
         declare
            J : Natural := 0;
         begin
            for I in 1 .. Curve_Max loop
               if I mod 2 = 1 then
                  J := J + 1;
                  Curve (J) := Curve (I);
               end if;
            end loop;
            Curve_Used := J;
         end;
         if Curve_Stride < 4096 then
            Curve_Stride := Curve_Stride * 2;
         end if;
      end if;

      if Curve_Used < Curve_Max then
         Curve_Used := Curve_Used + 1;
         Curve (Curve_Used) := Value;
      end if;
   end Remember;

   procedure Reset (Kind : Integer) is
      Keep : Float := Default_Rate;
   begin
      if Ready and then Model.Rate > 0.0 and then Model.Rate <= Rate_Max
      then
         Keep := Model.Rate;
      end if;
      Which := Decode (Kind);
      Data := Make_Dataset (Which);
      Initialize (Model, Init_Seed, Keep);
      Ready := True;
      Epochs := 0;
      Clear_Curve;
      Current := Mean_Loss (Model, Data);
      Remember (Current);
      Trained := Model;
      Trained_Epochs := Epochs;
      Trained_Curve := Curve;
      Trained_Used := Curve_Used;
      Trained_Stride := Curve_Stride;
      Trained_Seen := Curve_Seen;
      Set_Note ("Restored the seeded weights for this dataset.");
   end Reset;

   procedure Set_Learning_Rate (Value : Float) is
   begin
      if Ready and then Value > 0.0 and then Value <= Rate_Max then
         Model.Rate := Value;
      end if;
   end Set_Learning_Rate;

   function Learning_Rate return Float is
   begin
      if not Ready then
         return Default_Rate;
      end if;
      return Model.Rate;
   end Learning_Rate;

   function Run_Steps (Steps : Integer) return Float is
      N    : Integer := Steps;
      Cost : Float := Current;
   begin
      if not Ready or else Data.Count = 0 or else N < 1 then
         return Current;
      end if;
      if N > Step_Cap then
         N := Step_Cap;
      end if;
      for I in 1 .. N loop
         Train (Model, Data, 1, Cost);
         Current := Cost;
         Remember (Cost);
         if Epochs < 1_000_000_000 then
            Epochs := Epochs + 1;
         end if;
      end loop;
      Trained := Model;
      Trained_Epochs := Epochs;
      Trained_Curve := Curve;
      Trained_Used := Curve_Used;
      Trained_Stride := Curve_Stride;
      Trained_Seen := Curve_Seen;
      return Current;
   end Run_Steps;

   function Step_Count return Integer is (Epochs);

   function Current_Loss return Float is (Current);

   function Predict_At (X, Y : Float) return Float is
      Input : constant Tensors.Vector :=
        (Length => Inputs, Data => (X, Y));
   begin
      if not Ready then
         return 0.0;
      end if;
      return Predict (Model, Input);
   end Predict_At;

   function Sample_Count return Integer is (Data.Count);

   function In_Samples (Index : Integer) return Boolean is
     (Index >= 1 and then Index <= Data.Count);

   function Sample_X (Index : Integer) return Float is
   begin
      if not In_Samples (Index) then
         return 0.0;
      end if;
      return Data.Item (Index).X.Data (1);
   end Sample_X;

   function Sample_Y (Index : Integer) return Float is
   begin
      if not In_Samples (Index) then
         return 0.0;
      end if;
      return Data.Item (Index).X.Data (2);
   end Sample_Y;

   function Sample_Label (Index : Integer) return Float is
   begin
      if not In_Samples (Index) then
         return 0.0;
      end if;
      return Data.Item (Index).Label;
   end Sample_Label;

   function View_Low return Float is
      Low  : Float;
      High : Float;
   begin
      View_Box (Which, Low, High);
      return Low;
   end View_Low;

   function View_High return Float is
      Low  : Float;
      High : Float;
   begin
      View_Box (Which, Low, High);
      return High;
   end View_High;

   function Grid_N return Integer is (Grid_Side);

   procedure Fill_Grid is
      Low  : Float;
      High : Float;
      Span : Float;
      X    : Float;
      Y    : Float;
   begin
      if not Ready then
         Grid := (others => (others => 0.0));
         return;
      end if;
      View_Box (Which, Low, High);
      Span := (High - Low) / Float (Grid_Side);
      for Row in 1 .. Grid_Side loop
         Y := High - (Float (Row) - 0.5) * Span;
         for Col in 1 .. Grid_Side loop
            X := Low + (Float (Col) - 0.5) * Span;
            Grid (Row, Col) := Predict_At (X, Y);
         end loop;
      end loop;
   end Fill_Grid;

   function Cell (Row, Col : Integer) return Float is
   begin
      if Row < 1 or else Col < 1
        or else Row > Grid_Side or else Col > Grid_Side
      then
         return 0.0;
      end if;
      return Grid (Row, Col);
   end Cell;

   function Curve_Count return Integer is (Curve_Used);

   function Curve_At (Index : Integer) return Float is
   begin
      if Index < 1 or else Index > Curve_Used then
         return 0.0;
      end if;
      return Curve (Index);
   end Curve_At;

   function Kind_Code return Integer is
   begin
      case Which is
         when XOR_Points =>
            return 0;
         when Two_Circles =>
            return 1;
         when Two_Spirals =>
            return 2;
      end case;
   end Kind_Code;

   function Weight_Limit return Float is (MLP.Weight_Limit);

   function Slider_Span return Float is (MLP.Slider_Span);

   function Weight_Count return Integer is (Param_N);

   function In_Params (Index : Integer) return Boolean is
     (Index >= 1 and then Index <= Param_N);

   function Weight_At (Index : Integer) return Float is
      Unit : Integer;
      Slot : Integer;
   begin
      if not Ready or else not In_Params (Index) then
         return 0.0;
      end if;
      if Index <= Hidden * 3 then
         Unit := (Index - 1) / 3 + 1;
         Slot := (Index - 1) mod 3;
         if Slot = 0 then
            return Model.W1.Data (Unit, 1);
         elsif Slot = 1 then
            return Model.W1.Data (Unit, 2);
         else
            return Model.B1.Data (Unit);
         end if;
      elsif Index <= Hidden * 3 + Hidden then
         return Model.W2.Data (1, Index - Hidden * 3);
      else
         return Model.B2.Data (1);
      end if;
   end Weight_At;

   procedure Touch_Loss is
   begin
      if not Ready or else Data.Count = 0 then
         return;
      end if;
      Current := Mean_Loss (Model, Data);
      if Curve_Used > 0 then
         Curve (Curve_Used) := Current;
      end if;
   end Touch_Loss;

   function Set_Weight (Index : Integer; Value : Float) return Integer is
   begin
      if not Ready then
         return 2;
      end if;
      if not In_Params (Index) then
         Set_Note ("That index is not a weight.");
         return 2;
      end if;
      if Value /= Value or else abs Value > MLP.Weight_Limit then
         Set_Note
           ("Rejected that weight. It has to be finite"
            & " and at most 1000 in absolute value.");
         return 1;
      end if;
      if Index <= Hidden * 3 then
         declare
            Unit : constant Integer := (Index - 1) / 3 + 1;
            Slot : constant Integer := (Index - 1) mod 3;
         begin
            if Slot = 0 then
               Model.W1.Data (Unit, 1) := Value;
            elsif Slot = 1 then
               Model.W1.Data (Unit, 2) := Value;
            else
               Model.B1.Data (Unit) := Value;
            end if;
         end;
      elsif Index <= Hidden * 3 + Hidden then
         Model.W2.Data (1, Index - Hidden * 3) := Value;
      else
         Model.B2.Data (1) := Value;
      end if;
      Touch_Loss;
      Fill_Name (Index);
      Note_Clear;
      Note_Add ("Updated ");
      Note_Add (Name_Buf (1 .. Name_Len));
      Note_Add (".");
      return 0;
   end Set_Weight;

   function Name_Length (Index : Integer) return Integer is
   begin
      Fill_Name (Index);
      return Name_Len;
   end Name_Length;

   function Name_Byte (Index, Pos : Integer) return Integer is
   begin
      Fill_Name (Index);
      if Pos < 1 or else Pos > Name_Len then
         return 0;
      end if;
      return Character'Pos (Name_Buf (Pos));
   end Name_Byte;

   function Export_Length return Integer is
      Count : Natural;
   begin
      if not Ready then
         Export_Len := 0;
         return 0;
      end if;
      Write_Weights (Model, Export_Buf, Count);
      Export_Len := Count;
      return Count;
   end Export_Length;

   function Export_Byte (Index : Integer) return Integer is
   begin
      if Index < 1 or else Index > Export_Len then
         return 0;
      end if;
      return Character'Pos (Export_Buf (Index));
   end Export_Byte;

   procedure Import_Clear is
   begin
      Import_Len := 0;
      Import_Overflow := False;
   end Import_Clear;

   procedure Import_Push (Value : Integer) is
   begin
      if Value < 0 or else Value > 255 then
         return;
      end if;
      if Import_Len >= Max_Weight_Text then
         Import_Overflow := True;
         return;
      end if;
      Import_Len := Import_Len + 1;
      Import_Buf (Import_Len) := Character'Val (Value);
   end Import_Push;

   function Import_Load return Integer is
      Status : Load_Status;
   begin
      if not Ready then
         Set_Note ("The network is not ready.");
         return 3;
      end if;
      if Import_Overflow then
         Set_Note
           ("The file is longer than 8192 bytes, so it was not loaded.");
         return 3;
      end if;
      if Import_Len = 0 then
         Set_Note ("The file is empty, so it was not loaded.");
         return 3;
      end if;
      Read_Weights (Model, Import_Buf, Import_Len, Status);
      case Status is
         when Loaded =>
            Epochs := 0;
            Clear_Curve;
            Current := Mean_Loss (Model, Data);
            Remember (Current);
            Set_Note ("Loaded the weights from the file.");
            return 0;
         when Bad_Shape =>
            Set_Note
              ("The file's shape is not 2 8 1,"
               & " so the weights were left as they were.");
            return 1;
         when Bad_Value =>
            Set_Note
              ("A weight in the file is not finite or sits outside"
               & " [-1000, 1000], so nothing was loaded.");
            return 2;
         when Bad_Syntax =>
            Set_Note
              ("The file is not the weight text this net writes,"
               & " so nothing was loaded.");
            return 3;
      end case;
   end Import_Load;

   procedure Load_Hand is
      Keep : Float;
   begin
      if not Ready then
         Reset (0);
      end if;
      Keep := Model.Rate;
      if Which /= XOR_Points then
         Which := XOR_Points;
         Data := Make_Dataset (Which);
         Initialize (Model, Init_Seed, Keep);
         Epochs := 0;
         Clear_Curve;
         Current := Mean_Loss (Model, Data);
         Remember (Current);
         Trained := Model;
         Trained_Epochs := 0;
         Trained_Curve := Curve;
         Trained_Used := Curve_Used;
         Trained_Stride := Curve_Stride;
         Trained_Seen := Curve_Seen;
      end if;
      Model := Hand_XOR;
      Model.Rate := Keep;
      Epochs := 0;
      Clear_Curve;
      Current := Mean_Loss (Model, Data);
      Remember (Current);
      Set_Note
        ("Loaded the hand-written XOR net. Hidden 1 is OR,"
         & " hidden 2 is AND, and the output is OR and not AND."
         & " Units 3 to 8 are silent. Nothing was trained.");
   end Load_Hand;

   procedure Restore_Trained is
      Keep : constant Float := Model.Rate;
   begin
      if not Ready then
         return;
      end if;
      Model := Trained;
      Model.Rate := Keep;
      Epochs := Trained_Epochs;
      Curve := Trained_Curve;
      Curve_Used := Trained_Used;
      Curve_Stride := Trained_Stride;
      Curve_Seen := Trained_Seen;
      Touch_Loss;
      if Trained_Epochs = 0 then
         Set_Note
           ("Restored the seeded starting weights."
            & " No training step is stored yet.");
      else
         Note_Clear;
         Note_Add ("Restored the weights from training step ");
         Note_Add_Int (Trained_Epochs);
         Note_Add (".");
      end if;
   end Restore_Trained;

   procedure Preset (Code : Integer) is
      Before : Float;
      Silent : Boolean;
   begin
      if not Ready then
         return;
      end if;
      case Code is
         when 1 =>
            Before := Model.W2.Data (1, 1);
            Apply_Preset (Model, Flip_Hidden_1);
            if Before = 0.0 then
               Set_Note
                 ("Hidden 1's output weight was already 0,"
                  & " so flipping it changes nothing.");
            else
               Set_Note
                 ("Flipped hidden 1: its output weight changed sign,"
                  & " so that unit now pulls the probability the other way.");
            end if;
         when 2 =>
            Before := Model.W2.Data (1, 2);
            Apply_Preset (Model, Silence_Hidden_2);
            if Before = 0.0 then
               Set_Note
                 ("Hidden 2's output weight was already 0,"
                  & " so the boundary does not move.");
            else
               Set_Note
                 ("Silenced hidden 2: its output weight is now 0,"
                  & " so that unit no longer moves the boundary.");
            end if;
         when 3 =>
            Silent := Model.B2.Data (1) = 0.0;
            for C in 1 .. Hidden loop
               if Model.W2.Data (1, C) /= 0.0 then
                  Silent := False;
               end if;
            end loop;
            Apply_Preset (Model, Invert_Output);
            if Silent then
               Set_Note
                 ("The output weights were already 0,"
                  & " so inverting them changes nothing.");
            else
               Set_Note
                 ("Inverted the output: every output weight and the"
                  & " output bias changed sign, so class 0 and class 1"
                  & " trade places.");
            end if;
         when others =>
            Set_Note ("That edit is not one of the three.");
            return;
      end case;
      Touch_Loss;
   end Preset;

   function Note_Length return Integer is (Note_Len);

   function Note_Byte (Index : Integer) return Integer is
   begin
      if Index < 1 or else Index > Note_Len then
         return 0;
      end if;
      return Character'Pos (Note_Text (Index));
   end Note_Byte;

begin
   Reset (0);
end AI_Amplifier.MLP.Demo;
