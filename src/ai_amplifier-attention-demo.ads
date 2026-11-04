--  The live page's tokenizer and attention block.
--
--  Plain Ada, like AI_Amplifier.Attention. JavaScript clears the
--  buffer, pushes UTF-8 bytes, and asks for a run. It then reads
--  token ids, the bytes of each piece, and the causal weights, and
--  draws those. The merges and the attention stay in Ada.
--
--  This wrapper does not raise. A byte outside 0 .. 255 is ignored.
--  Bytes past Max_Input are counted and dropped. An index outside
--  the current tokens reads as 0. One run attends to at most
--  Max_Seq tokens; the rest are still reported as pieces.
package AI_Amplifier.Attention.Demo
  with SPARK_Mode => Off
is

   procedure Clear
     with Export, Convention => C, External_Name => "aa_bpe_clear";

   procedure Push (Value : Integer)
     with Export, Convention => C, External_Name => "aa_bpe_push";

   function Corpus_Bytes return Integer
     with Export, Convention => C, External_Name => "aa_bpe_corpus";

   --  Encodes the buffer and runs attention. Returns the token count.
   function Run return Integer
     with Export, Convention => C, External_Name => "aa_attn_run";

   function Token_Count return Integer
     with Export, Convention => C, External_Name => "aa_attn_tokens";

   function Token_At (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_attn_id";

   function Piece_Len (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_attn_piece_len";

   function Piece_At (Index, Pos : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_attn_piece_byte";

   function Vocab return Integer
     with Export, Convention => C, External_Name => "aa_attn_vocab";

   function Merges return Integer
     with Export, Convention => C, External_Name => "aa_attn_merges";

   function Used_Count return Integer
     with Export, Convention => C, External_Name => "aa_attn_used";

   function Weight (Query, Key : Integer) return Float
     with Export, Convention => C, External_Name => "aa_attn_weight";

   function Dropped_Bytes return Integer
     with Export, Convention => C, External_Name => "aa_attn_dropped";

   function Byte_Count return Integer
     with Export, Convention => C, External_Name => "aa_attn_bytes";

end AI_Amplifier.Attention.Demo;
