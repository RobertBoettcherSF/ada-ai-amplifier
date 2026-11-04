--  Byte-level byte-pair encoding.
--
--  Plain Ada (SPARK_Mode off). Nothing here is proved. The Pre and
--  Post below are ordinary Ada contracts, checked when the program
--  runs, the same way as the tensor kernels.
--
--  A token id below 256 is that byte. Ids from 256 upward are merges
--  learned from one built-in excerpt (see the body, and the quotation
--  in the README): Carroll's opening, then the Grimms' Rotkaeppchen.
--  The bytes of that excerpt are the corpus. Learning counts adjacent
--  pairs, keeps the most frequent one (a tie goes to the smaller left
--  id, then the smaller right id), and replaces it left to right
--  without overlap. A pair is skipped when the joined piece would be
--  longer than Max_Piece. Learning stops at Max_Merges, or sooner
--  when no remaining pair occurs twice.
--
--  Encode starts from the bytes and applies those merges in the order
--  they were learned. Decode concatenates the bytes of each id. On
--  every input that fits, the two are inverses, including the empty
--  string and any UTF-8 sequence. A merge never invents a byte.
package AI_Amplifier.BPE
  with SPARK_Mode => Off
is

   pragma Assertion_Policy (Pre => Check, Post => Check);

   Byte_Tokens : constant := 256;
   Max_Merges  : constant := 32;
   Max_Piece   : constant := 16;

   --  The page buffer and the native round-trip of the corpus both
   --  fit. A longer argument fails the precondition.
   Max_Input : constant := 768;

   Max_Decoded : constant := Max_Input * Max_Piece;

   subtype Byte is Natural range 0 .. 255;

   subtype Token_Id is Natural range
     0 .. Byte_Tokens + Max_Merges - 1;

   type Byte_Array is array (Positive range <>) of Byte;

   type Id_Array is array (1 .. Max_Input) of Token_Id;

   type Token_List is record
      Count : Natural range 0 .. Max_Input := 0;
      Id    : Id_Array := (others => 0);
   end record;

   type Byte_List is record
      Count : Natural range 0 .. Max_Decoded := 0;
      Data  : Byte_Array (1 .. Max_Decoded) := (others => 0);
   end record;

   --  How many merges this excerpt actually learned (at most
   --  Max_Merges). The first call learns them. Later calls reuse
   --  the same rules.
   function Merge_Count return Natural;

   function Vocab_Size return Positive;

   function Corpus_Length return Natural;

   --  1-based. An index outside the corpus reads as 0.
   function Corpus_Byte (Index : Integer) return Byte;

   function Encode (Bytes : Byte_Array) return Token_List
     with Pre  => Bytes'Length <= Max_Input,
          Post => Encode'Result.Count <= Bytes'Length;

   --  The page buffer. A slice whose length is chosen at run time
   --  would need a secondary stack, and the wasm runtime has none.
   subtype Input_Buffer is Byte_Array (1 .. Max_Input);

   procedure Encode_Buffer
     (Bytes  : Input_Buffer;
      Count  : Natural;
      Tokens : out Token_List)
     with Pre  => Count <= Max_Input,
          Post => Tokens.Count <= Count;

   procedure Decode (Tokens : Token_List; Result : out Byte_List);

   function Piece_Length (Id : Token_Id) return Natural
     with Post => Piece_Length'Result <= Max_Piece;

   function Piece_Byte (Id : Token_Id; Pos : Positive) return Byte
     with Pre => Pos <= Piece_Length (Id);

   --  Rank is 1 .. Merge_Count, in the order the pairs were learned.
   --  The new id for that rank is Byte_Tokens + Rank - 1.
   function Merge_Left (Rank : Positive) return Token_Id
     with Pre => Rank <= Merge_Count;

   function Merge_Right (Rank : Positive) return Token_Id
     with Pre => Rank <= Merge_Count;

end AI_Amplifier.BPE;
