--  Item 8. The hand-written XOR net: hidden 1 is OR,
--  hidden 2 is AND, the output is OR and not AND, units
--  3 through 8 are 0. Loss under 0.05, class 1 at least
--  0.8, class 0 at most 0.2. Weight_Limit is 1000.
--  The text starts with the shape line the reader requires.
with Ada.Text_IO;
with AI_Amplifier.MLP;

procedure Item_08
  with SPARK_Mode => Off
is
   package M renames AI_Amplifier.MLP;

   function Has (Text : M.Weight_Chars; Count : Natural; Needle : String)
     return Boolean
   is
   begin
      if Needle'Length = 0 or else Needle'Length > Count then
         return False;
      end if;
      for I in 1 .. Count - Needle'Length + 1 loop
         declare
            Same : Boolean := True;
         begin
            for K in Needle'Range loop
               if Text (I + (K - Needle'First)) /= Needle (K) then
                  Same := False;
                  exit;
               end if;
            end loop;
            if Same then
               return True;
            end if;
         end;
      end loop;
      return False;
   end Has;

   Model : M.Net;
   Data  : constant M.Sample_List := M.Make_Dataset (M.XOR_Points);
   Text  : M.Weight_Chars;
   Count : Natural;
   Y     : Float;
begin
   pragma Assert (M.Weight_Limit = 1000.0);
   pragma Assert (M.Hand_Or_Weight = 6.0);
   pragma Assert (M.Hand_Or_Bias = -3.0);
   pragma Assert (M.Hand_And_Weight = 6.0);
   pragma Assert (M.Hand_And_Bias = -9.0);
   pragma Assert (M.Hand_Out_Or = 6.0);
   pragma Assert (M.Hand_Out_And = -6.0);
   pragma Assert (M.Hand_Out_Bias = -6.0);
   Model := M.Hand_XOR;
   pragma Assert (Model.W1.Data (1, 1) = 6.0);
   pragma Assert (Model.W1.Data (1, 2) = 6.0);
   pragma Assert (Model.B1.Data (1) = -3.0);
   pragma Assert (Model.W1.Data (2, 1) = 6.0);
   pragma Assert (Model.W1.Data (2, 2) = 6.0);
   pragma Assert (Model.B1.Data (2) = -9.0);
   pragma Assert (Model.W2.Data (1, 1) = 6.0);
   pragma Assert (Model.W2.Data (1, 2) = -6.0);
   pragma Assert (Model.B2.Data (1) = -6.0);
   for U in 3 .. M.Hidden loop
      pragma Assert (Model.W1.Data (U, 1) = 0.0);
      pragma Assert (Model.W1.Data (U, 2) = 0.0);
      pragma Assert (Model.B1.Data (U) = 0.0);
      pragma Assert (Model.W2.Data (1, U) = 0.0);
   end loop;
   pragma Assert (M.Mean_Loss (Model, Data) < 0.05);
   for I in 1 .. Data.Count loop
      Y := M.Predict (Model, Data.Item (I).X);
      if Data.Item (I).Label >= 0.5 then
         pragma Assert (Y >= 0.8);
      else
         pragma Assert (Y <= 0.2);
      end if;
   end loop;
   M.Write_Weights (Model, Text, Count);
   pragma Assert (Has (Text, Count, "shape 2 8 1"));
   M.Apply_Preset (Model, M.Flip_Hidden_1);
   pragma Assert (Model.W2.Data (1, 1) = -6.0);
   Model := M.Hand_XOR;
   M.Apply_Preset (Model, M.Silence_Hidden_2);
   pragma Assert (Model.W2.Data (1, 2) = 0.0);
   Ada.Text_IO.Put_Line ("item 08 pass");
end Item_08;
