with AI_Amplifier.BPE;

package body AI_Amplifier.Attention.Demo
  with SPARK_Mode => Off
is

   package B renames AI_Amplifier.BPE;

   Buf     : B.Input_Buffer := (others => 0);
   Buf_Len : Natural := 0;
   Dropped : Natural := 0;
   Tokens  : B.Token_List;
   Weights : Weight_Grid := (others => (others => 0.0));
   Used_N  : Natural := 0;

   procedure Clear is
   begin
      Buf_Len := 0;
      Dropped := 0;
      Tokens.Count := 0;
      Used_N := 0;
      Weights := (others => (others => 0.0));
   end Clear;

   procedure Push (Value : Integer) is
   begin
      if Value < 0 or else Value > 255 then
         return;
      end if;
      if Buf_Len >= B.Max_Input then
         if Dropped < 1_000_000 then
            Dropped := Dropped + 1;
         end if;
         return;
      end if;
      Buf_Len := Buf_Len + 1;
      Buf (Buf_Len) := B.Byte (Value);
   end Push;

   function Corpus_Bytes return Integer is (B.Corpus_Length);

   function Run return Integer is
   begin
      if Buf_Len = 0 then
         Tokens.Count := 0;
         Used_N := 0;
         Weights := (others => (others => 0.0));
         return 0;
      end if;

      --  The whole fixed buffer, plus how many bytes are live. A
      --  slice of run-time length needs a secondary stack, and this
      --  wasm runtime has none.
      B.Encode_Buffer (Buf, Buf_Len, Tokens);
      Forward_Tokens (Tokens, Weights, Used_N);
      return Tokens.Count;
   end Run;

   function Token_Count return Integer is (Tokens.Count);

   function Live (Index : Integer) return Boolean is
     (Index >= 1 and then Index <= Tokens.Count);

   function Token_At (Index : Integer) return Integer is
   begin
      if not Live (Index) then
         return 0;
      end if;
      return Tokens.Id (Index);
   end Token_At;

   function Piece_Len (Index : Integer) return Integer is
   begin
      if not Live (Index) then
         return 0;
      end if;
      return B.Piece_Length (Tokens.Id (Index));
   end Piece_Len;

   function Piece_At (Index, Pos : Integer) return Integer is
      Id  : B.Token_Id;
      Len : Natural;
   begin
      if not Live (Index) or else Pos < 1 then
         return 0;
      end if;
      Id := Tokens.Id (Index);
      Len := B.Piece_Length (Id);
      if Pos > Len then
         return 0;
      end if;
      return B.Piece_Byte (Id, Pos);
   end Piece_At;

   function Vocab return Integer is (B.Vocab_Size);

   function Merges return Integer is (B.Merge_Count);

   function Used_Count return Integer is (Used_N);

   function Weight (Query, Key : Integer) return Float is
   begin
      if Query < 1 or else Key < 1
        or else Query > Used_N or else Key > Used_N
      then
         return 0.0;
      end if;
      return Weights (Query, Key);
   end Weight;

   function Dropped_Bytes return Integer is (Dropped);

   function Byte_Count return Integer is (Buf_Len);

end AI_Amplifier.Attention.Demo;
