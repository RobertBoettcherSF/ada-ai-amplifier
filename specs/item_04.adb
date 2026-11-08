--  Item 4. The XOR trainer the native test runs: seed
--  20261104, shape 2-8-1, four points, a zero net at ln 2,
--  and a loss under 0.05 with the 0.8 and 0.2 margins.
--  On this seed that bar is met at step 95, rate 1.
with Ada.Text_IO;
with AI_Amplifier.MLP;
with AI_Amplifier.Tensors;

procedure Item_04
  with SPARK_Mode => Off
is
   package M renames AI_Amplifier.MLP;
   package T renames AI_Amplifier.Tensors;

   function Near (Got, Want : Float) return Boolean is
      Diff : Float := Got - Want;
   begin
      if Diff < 0.0 then
         Diff := -Diff;
      end if;
      return Diff <= 0.000_05;
   end Near;

   function Margin (Model : M.Net; Data : M.Sample_List) return Boolean is
      Y : Float;
   begin
      for I in 1 .. Data.Count loop
         Y := M.Predict (Model, Data.Item (I).X);
         if Data.Item (I).Label >= 0.5 then
            if Y < 0.8 then
               return False;
            end if;
         elsif Y > 0.2 then
            return False;
         end if;
      end loop;
      return True;
   end Margin;

   Model : M.Net;
   Data  : M.Sample_List;
   G     : M.Gradient;
   Loss  : Float;
   Took  : Natural := 0;
begin
   pragma Assert (M.Inputs = 2);
   pragma Assert (M.Hidden = 8);
   pragma Assert (M.Outputs = 1);
   pragma Assert (M.Init_Seed = 2_026_1104);
   Data := M.Make_Dataset (M.XOR_Points);
   pragma Assert (Data.Count = 4);
   pragma Assert (Data.Item (1).X.Data (1) = 0.0);
   pragma Assert (Data.Item (1).X.Data (2) = 0.0);
   pragma Assert (Data.Item (1).Label = 0.0);
   pragma Assert (Data.Item (2).Label = 1.0);
   pragma Assert (Data.Item (3).Label = 1.0);
   pragma Assert (Data.Item (4).Label = 0.0);
   pragma Assert (M.Make_Dataset (M.Two_Circles).Count = 72);
   pragma Assert (M.Make_Dataset (M.Two_Spirals).Count = 96);

   M.Initialize (Model, M.Init_Seed, 0.5);
   Model.W1 :=
     (Rows => M.Hidden, Cols => M.Inputs, Data => (others => (others => 0.0)));
   Model.B1 := (Length => M.Hidden, Data => (others => 0.0));
   Model.W2 :=
     (Rows => M.Outputs, Cols => M.Hidden, Data => (others => (others => 0.0)));
   Model.B2 := (Length => M.Outputs, Data => (others => 0.0));
   M.Backprop (Model, Data, G, Loss);
   pragma Assert (Near (Loss, 0.693_147));
   pragma Assert (Near (M.Mean_Loss (Model, Data), Loss));
   pragma Assert (G.B2.Data (1) = 0.0);

   M.Initialize (Model, M.Init_Seed, 1.0);
   Loss := M.Mean_Loss (Model, Data);
   for I in 1 .. 8000 loop
      M.Train (Model, Data, 1, Loss);
      Took := I;
      exit when Loss < 0.05 and then Margin (Model, Data);
   end loop;
   pragma Assert (Took = 95);
   pragma Assert (Loss < 0.05);
   pragma Assert (Margin (Model, Data));
   Ada.Text_IO.Put_Line ("item 04 pass");
end Item_04;
