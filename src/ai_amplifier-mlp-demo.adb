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

   Curve       : array (1 .. Curve_Max) of Float := (others => 0.0);
   Curve_Used  : Natural := 0;
   Curve_Stride : Positive := 1;
   Curve_Seen  : Natural := 0;

   Grid : array (1 .. Grid_Side, 1 .. Grid_Side) of Float :=
     (others => (others => 0.0));

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

begin
   Reset (0);
end AI_Amplifier.MLP.Demo;
