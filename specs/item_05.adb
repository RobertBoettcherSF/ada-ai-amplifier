--  Item 5. The tokenizer numbers attention_test locks, and
--  the scaled dot of a unit vector with itself.
with Ada.Text_IO;
with AI_Amplifier.Attention;
with AI_Amplifier.BPE;
with AI_Amplifier.Tensors;

procedure Item_05
  with SPARK_Mode => Off
is
   package B renames AI_Amplifier.BPE;
   package A renames AI_Amplifier.Attention;
   package T renames AI_Amplifier.Tensors;

   function Near (Got, Want : Float) return Boolean is
      Diff : Float := Got - Want;
   begin
      if Diff < 0.0 then
         Diff := -Diff;
      end if;
      return Diff <= 0.000_05;
   end Near;

   N      : constant Natural := B.Corpus_Length;
   Bytes  : B.Byte_Array (1 .. N);
   Tokens : B.Token_List;
   E1     : constant T.Vector :=
     (Length => A.D_Model,
      Data   => (1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0));
begin
   pragma Assert (N = 563);
   pragma Assert (B.Merge_Count = 32);
   pragma Assert (B.Vocab_Size = 288);
   pragma Assert (B.Max_Merges = 32);
   pragma Assert (B.Byte_Tokens = 256);
   pragma Assert (B.Merge_Left (1) = Character'Pos ('e'));
   pragma Assert (B.Merge_Right (1) = Character'Pos (' '));
   pragma Assert (B.Byte_Tokens + 1 - 1 = 256);
   for I in Bytes'Range loop
      Bytes (I) := B.Corpus_Byte (I);
   end loop;
   Tokens := B.Encode (Bytes);
   pragma Assert (Tokens.Count = 376);
   Tokens := B.Encode ((1 => 16#C3#, 2 => 16#9F#));
   pragma Assert (Tokens.Count = 1);
   pragma Assert (B.Piece_Length (Tokens.Id (1)) = 2);
   pragma Assert (B.Piece_Byte (Tokens.Id (1), 1) = 16#C3#);
   pragma Assert (B.Piece_Byte (Tokens.Id (1), 2) = 16#9F#);
   Tokens := B.Encode ((1 => 16#C3#, 2 => 16#A4#));
   pragma Assert (Tokens.Count = 2);
   pragma Assert (Tokens.Id (1) = 16#C3#);
   pragma Assert (Tokens.Id (2) = 16#A4#);
   pragma Assert (A.D_Model = 8);
   pragma Assert (A.Max_Seq = 16);
   pragma Assert (A.Embed_Seed = 2_026_1104);
   pragma Assert (Near (A.Scaled_Dot (E1, E1), 0.353_553_38));
   Ada.Text_IO.Put_Line ("item 05 pass");
end Item_05;
