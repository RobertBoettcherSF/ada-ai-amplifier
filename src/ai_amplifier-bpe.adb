package body AI_Amplifier.BPE
  with SPARK_Mode => Off
is

   pragma Assertion_Policy (Pre => Check, Post => Check);

   --  UTF-8 of the excerpt quoted in the README. Lewis Carroll,
   --  Alice's Adventures in Wonderland (1865), from the opening
   --  through "conversations in it". Then the Grimms' Rotkaeppchen
   --  (Kinder- und Hausmaerchen, 1857), from "Es war einmal" through
   --  the sentence that names the child. This source stays in the
   --  Ada character set, so the umlauts live only in these bytes.
   Corpus : constant Byte_Array :=
     (
      16#41#, 16#6C#, 16#69#, 16#63#, 16#65#, 16#20#, 16#77#, 16#61#,
      16#73#, 16#20#, 16#62#, 16#65#, 16#67#, 16#69#, 16#6E#, 16#6E#,
      16#69#, 16#6E#, 16#67#, 16#20#, 16#74#, 16#6F#, 16#20#, 16#67#,
      16#65#, 16#74#, 16#20#, 16#76#, 16#65#, 16#72#, 16#79#, 16#20#,
      16#74#, 16#69#, 16#72#, 16#65#, 16#64#, 16#20#, 16#6F#, 16#66#,
      16#20#, 16#73#, 16#69#, 16#74#, 16#74#, 16#69#, 16#6E#, 16#67#,
      16#20#, 16#62#, 16#79#, 16#20#, 16#68#, 16#65#, 16#72#, 16#20#,
      16#73#, 16#69#, 16#73#, 16#74#, 16#65#, 16#72#, 16#20#, 16#6F#,
      16#6E#, 16#20#, 16#74#, 16#68#, 16#65#, 16#20#, 16#62#, 16#61#,
      16#6E#, 16#6B#, 16#2C#, 16#20#, 16#61#, 16#6E#, 16#64#, 16#20#,
      16#6F#, 16#66#, 16#20#, 16#68#, 16#61#, 16#76#, 16#69#, 16#6E#,
      16#67#, 16#20#, 16#6E#, 16#6F#, 16#74#, 16#68#, 16#69#, 16#6E#,
      16#67#, 16#20#, 16#74#, 16#6F#, 16#20#, 16#64#, 16#6F#, 16#3A#,
      16#20#, 16#6F#, 16#6E#, 16#63#, 16#65#, 16#20#, 16#6F#, 16#72#,
      16#20#, 16#74#, 16#77#, 16#69#, 16#63#, 16#65#, 16#20#, 16#73#,
      16#68#, 16#65#, 16#20#, 16#68#, 16#61#, 16#64#, 16#20#, 16#70#,
      16#65#, 16#65#, 16#70#, 16#65#, 16#64#, 16#20#, 16#69#, 16#6E#,
      16#74#, 16#6F#, 16#20#, 16#74#, 16#68#, 16#65#, 16#20#, 16#62#,
      16#6F#, 16#6F#, 16#6B#, 16#20#, 16#68#, 16#65#, 16#72#, 16#20#,
      16#73#, 16#69#, 16#73#, 16#74#, 16#65#, 16#72#, 16#20#, 16#77#,
      16#61#, 16#73#, 16#20#, 16#72#, 16#65#, 16#61#, 16#64#, 16#69#,
      16#6E#, 16#67#, 16#2C#, 16#20#, 16#62#, 16#75#, 16#74#, 16#20#,
      16#69#, 16#74#, 16#20#, 16#68#, 16#61#, 16#64#, 16#20#, 16#6E#,
      16#6F#, 16#20#, 16#70#, 16#69#, 16#63#, 16#74#, 16#75#, 16#72#,
      16#65#, 16#73#, 16#20#, 16#6F#, 16#72#, 16#20#, 16#63#, 16#6F#,
      16#6E#, 16#76#, 16#65#, 16#72#, 16#73#, 16#61#, 16#74#, 16#69#,
      16#6F#, 16#6E#, 16#73#, 16#20#, 16#69#, 16#6E#, 16#20#, 16#69#,
      16#74#, 16#2E#, 16#20#, 16#45#, 16#73#, 16#20#, 16#77#, 16#61#,
      16#72#, 16#20#, 16#65#, 16#69#, 16#6E#, 16#6D#, 16#61#, 16#6C#,
      16#20#, 16#65#, 16#69#, 16#6E#, 16#65#, 16#20#, 16#6B#, 16#6C#,
      16#65#, 16#69#, 16#6E#, 16#65#, 16#20#, 16#73#, 16#C3#, 16#BC#,
      16#C3#, 16#9F#, 16#65#, 16#20#, 16#44#, 16#69#, 16#72#, 16#6E#,
      16#65#, 16#2C#, 16#20#, 16#64#, 16#69#, 16#65#, 16#20#, 16#68#,
      16#61#, 16#74#, 16#74#, 16#65#, 16#20#, 16#6A#, 16#65#, 16#64#,
      16#65#, 16#72#, 16#6D#, 16#61#, 16#6E#, 16#6E#, 16#20#, 16#6C#,
      16#69#, 16#65#, 16#62#, 16#2C#, 16#20#, 16#64#, 16#65#, 16#72#,
      16#20#, 16#73#, 16#69#, 16#65#, 16#20#, 16#6E#, 16#75#, 16#72#,
      16#20#, 16#61#, 16#6E#, 16#73#, 16#61#, 16#68#, 16#2C#, 16#20#,
      16#61#, 16#6D#, 16#20#, 16#61#, 16#6C#, 16#6C#, 16#65#, 16#72#,
      16#6C#, 16#69#, 16#65#, 16#62#, 16#73#, 16#74#, 16#65#, 16#6E#,
      16#20#, 16#61#, 16#62#, 16#65#, 16#72#, 16#20#, 16#69#, 16#68#,
      16#72#, 16#65#, 16#20#, 16#47#, 16#72#, 16#6F#, 16#C3#, 16#9F#,
      16#6D#, 16#75#, 16#74#, 16#74#, 16#65#, 16#72#, 16#2C#, 16#20#,
      16#64#, 16#69#, 16#65#, 16#20#, 16#77#, 16#75#, 16#C3#, 16#9F#,
      16#74#, 16#65#, 16#20#, 16#67#, 16#61#, 16#72#, 16#20#, 16#6E#,
      16#69#, 16#63#, 16#68#, 16#74#, 16#2C#, 16#20#, 16#77#, 16#61#,
      16#73#, 16#20#, 16#73#, 16#69#, 16#65#, 16#20#, 16#61#, 16#6C#,
      16#6C#, 16#65#, 16#73#, 16#20#, 16#64#, 16#65#, 16#6D#, 16#20#,
      16#4B#, 16#69#, 16#6E#, 16#64#, 16#65#, 16#20#, 16#67#, 16#65#,
      16#62#, 16#65#, 16#6E#, 16#20#, 16#73#, 16#6F#, 16#6C#, 16#6C#,
      16#74#, 16#65#, 16#2E#, 16#20#, 16#45#, 16#69#, 16#6E#, 16#6D#,
      16#61#, 16#6C#, 16#20#, 16#73#, 16#63#, 16#68#, 16#65#, 16#6E#,
      16#6B#, 16#74#, 16#65#, 16#20#, 16#73#, 16#69#, 16#65#, 16#20#,
      16#69#, 16#68#, 16#6D#, 16#20#, 16#65#, 16#69#, 16#6E#, 16#20#,
      16#4B#, 16#C3#, 16#A4#, 16#70#, 16#70#, 16#63#, 16#68#, 16#65#,
      16#6E#, 16#20#, 16#76#, 16#6F#, 16#6E#, 16#20#, 16#72#, 16#6F#,
      16#74#, 16#65#, 16#6D#, 16#20#, 16#53#, 16#61#, 16#6D#, 16#6D#,
      16#65#, 16#74#, 16#2C#, 16#20#, 16#75#, 16#6E#, 16#64#, 16#20#,
      16#77#, 16#65#, 16#69#, 16#6C#, 16#20#, 16#69#, 16#68#, 16#6D#,
      16#20#, 16#64#, 16#61#, 16#73#, 16#20#, 16#73#, 16#6F#, 16#20#,
      16#77#, 16#6F#, 16#68#, 16#6C#, 16#20#, 16#73#, 16#74#, 16#61#,
      16#6E#, 16#64#, 16#2C#, 16#20#, 16#75#, 16#6E#, 16#64#, 16#20#,
      16#65#, 16#73#, 16#20#, 16#6E#, 16#69#, 16#63#, 16#68#, 16#74#,
      16#73#, 16#20#, 16#61#, 16#6E#, 16#64#, 16#65#, 16#72#, 16#73#,
      16#20#, 16#6D#, 16#65#, 16#68#, 16#72#, 16#20#, 16#74#, 16#72#,
      16#61#, 16#67#, 16#65#, 16#6E#, 16#20#, 16#77#, 16#6F#, 16#6C#,
      16#6C#, 16#74#, 16#65#, 16#2C#, 16#20#, 16#68#, 16#69#, 16#65#,
      16#C3#, 16#9F#, 16#20#, 16#65#, 16#73#, 16#20#, 16#6E#, 16#75#,
      16#72#, 16#20#, 16#64#, 16#61#, 16#73#, 16#20#, 16#52#, 16#6F#,
      16#74#, 16#6B#, 16#C3#, 16#A4#, 16#70#, 16#70#, 16#63#, 16#68#,
      16#65#, 16#6E#, 16#2E#
     );

   type Piece_Bytes is array (1 .. Max_Piece) of Byte;

   type Piece is record
      Len : Natural range 0 .. Max_Piece := 0;
      B   : Piece_Bytes := (others => 0);
   end record;

   type Rule is record
      Left  : Token_Id := 0;
      Right : Token_Id := 0;
   end record;

   Stored  : array (1 .. Max_Merges) of Piece;
   Rules   : array (1 .. Max_Merges) of Rule;
   Learned : Natural := 0;
   Trained : Boolean := False;

   --  The excerpt being merged. Library-level so the pair count does
   --  not copy it on every call. Encode uses its own local list.
   Work     : Token_List;
   Work_Len : Natural := 0;

   function Rank_Of (Id : Token_Id) return Natural is
   begin
      if Id < Byte_Tokens then
         return 0;
      end if;
      return Id - Byte_Tokens + 1;
   end Rank_Of;

   --  Valid during Train as well as after it. Does not call Ensure.
   function Known_Length (Id : Token_Id) return Natural is
      Rank : Natural;
   begin
      if Id < Byte_Tokens then
         return 1;
      end if;
      Rank := Rank_Of (Id);
      if Rank < 1 or else Rank > Learned then
         return 0;
      end if;
      return Stored (Rank).Len;
   end Known_Length;

   function Known_Byte (Id : Token_Id; Pos : Positive) return Byte is
   begin
      if Id < Byte_Tokens then
         return Byte (Id);
      end if;
      return Stored (Rank_Of (Id)).B (Pos);
   end Known_Byte;

   function Count_Pair (Left, Right : Token_Id) return Natural is
      N : Natural := 0;
   begin
      if Work_Len < 2 then
         return 0;
      end if;
      for I in 1 .. Work_Len - 1 loop
         if Work.Id (I) = Left and then Work.Id (I + 1) = Right then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Count_Pair;

   --  Left to right, no overlap. Encode uses the same shape of loop.
   procedure Replace_Work (Left, Right, New_Id : Token_Id) is
      Next : Token_List;
      I    : Natural := 1;
      J    : Natural := 0;
   begin
      while I <= Work_Len loop
         if I < Work_Len
           and then Work.Id (I) = Left
           and then Work.Id (I + 1) = Right
         then
            J := J + 1;
            Next.Id (J) := New_Id;
            I := I + 2;
         else
            J := J + 1;
            Next.Id (J) := Work.Id (I);
            I := I + 1;
         end if;
      end loop;
      Work_Len := J;
      for K in 1 .. Work_Len loop
         Work.Id (K) := Next.Id (K);
      end loop;
   end Replace_Work;

   procedure Replace_Pair
     (Seq : in out Token_List;
      Len : in out Natural;
      Left, Right, New_Id : Token_Id)
   is
      Next : Token_List;
      I    : Natural := 1;
      J    : Natural := 0;
   begin
      while I <= Len loop
         if I < Len
           and then Seq.Id (I) = Left
           and then Seq.Id (I + 1) = Right
         then
            J := J + 1;
            Next.Id (J) := New_Id;
            I := I + 2;
         else
            J := J + 1;
            Next.Id (J) := Seq.Id (I);
            I := I + 1;
         end if;
      end loop;
      Len := J;
      for K in 1 .. Len loop
         Seq.Id (K) := Next.Id (K);
      end loop;
   end Replace_Pair;

   procedure Train is
      Best_N : Natural;
      Best_L : Token_Id;
      Best_R : Token_Id;
      Found  : Boolean;
      N      : Natural;
      Left   : Token_Id;
      Right  : Token_Id;
   begin
      pragma Assert (Corpus'Length <= Max_Input);

      Work_Len := Corpus'Length;
      for I in Corpus'Range loop
         Work.Id (I) := Corpus (I);
      end loop;

      for Rank in 1 .. Max_Merges loop
         if Work_Len < 2 then
            exit;
         end if;

         Found := False;
         Best_N := 0;
         Best_L := 0;
         Best_R := 0;

         for I in 1 .. Work_Len - 1 loop
            Left := Work.Id (I);
            Right := Work.Id (I + 1);
            if Known_Length (Left) + Known_Length (Right) <= Max_Piece
            then
               N := Count_Pair (Left, Right);
               if not Found
                 or else N > Best_N
                 or else (N = Best_N
                   and then (Left < Best_L
                     or else (Left = Best_L and then Right < Best_R)))
               then
                  Found := True;
                  Best_N := N;
                  Best_L := Left;
                  Best_R := Right;
               end if;
            end if;
         end loop;

         if not Found or else Best_N < 2 then
            exit;
         end if;

         declare
            P : Piece;
            K : Natural := 0;
            L_Len : constant Natural := Known_Length (Best_L);
            R_Len : constant Natural := Known_Length (Best_R);
         begin
            for I in 1 .. L_Len loop
               K := K + 1;
               P.B (K) := Known_Byte (Best_L, I);
            end loop;
            for I in 1 .. R_Len loop
               K := K + 1;
               P.B (K) := Known_Byte (Best_R, I);
            end loop;
            P.Len := K;
            Stored (Rank) := P;
         end;

         Rules (Rank) := (Left => Best_L, Right => Best_R);
         Learned := Rank;
         Replace_Work (Best_L, Best_R, Byte_Tokens + Rank - 1);
      end loop;
   end Train;

   procedure Ensure is
   begin
      if Trained then
         return;
      end if;
      Train;
      Trained := True;
   end Ensure;

   function Merge_Count return Natural is
   begin
      Ensure;
      return Learned;
   end Merge_Count;

   function Vocab_Size return Positive is
   begin
      return Byte_Tokens + Merge_Count;
   end Vocab_Size;

   function Corpus_Length return Natural is (Corpus'Length);

   function Corpus_Byte (Index : Integer) return Byte is
   begin
      if Index < 1 or else Index > Corpus'Length then
         return 0;
      end if;
      return Corpus (Index);
   end Corpus_Byte;

   procedure Apply_Learned (Seq : in out Token_List; Len : in out Natural) is
   begin
      for Rank in 1 .. Learned loop
         Replace_Pair
           (Seq,
            Len,
            Rules (Rank).Left,
            Rules (Rank).Right,
            Byte_Tokens + Rank - 1);
      end loop;
   end Apply_Learned;

   procedure Encode_Buffer
     (Bytes  : Input_Buffer;
      Count  : Natural;
      Tokens : out Token_List)
   is
      Seq : Token_List;
      Len : Natural := Count;
   begin
      Ensure;
      Tokens := (Count => 0, Id => (others => 0));
      if Count = 0 then
         return;
      end if;

      for I in 1 .. Count loop
         Seq.Id (I) := Bytes (I);
      end loop;
      Apply_Learned (Seq, Len);
      Seq.Count := Len;
      Tokens := Seq;
   end Encode_Buffer;

   function Encode (Bytes : Byte_Array) return Token_List is
      Buf    : Input_Buffer := (others => 0);
      Result : Token_List;
   begin
      if Bytes'Length = 0 then
         return Result;
      end if;
      for I in Bytes'Range loop
         Buf (I - Bytes'First + 1) := Bytes (I);
      end loop;
      Encode_Buffer (Buf, Bytes'Length, Result);
      return Result;
   end Encode;

   procedure Decode (Tokens : Token_List; Result : out Byte_List) is
      N   : Natural := 0;
      P_L : Natural;
   begin
      Ensure;
      Result := (Count => 0, Data => (others => 0));
      for I in 1 .. Tokens.Count loop
         P_L := Known_Length (Tokens.Id (I));
         for J in 1 .. P_L loop
            N := N + 1;
            Result.Data (N) := Known_Byte (Tokens.Id (I), J);
         end loop;
      end loop;
      Result.Count := N;
   end Decode;

   function Piece_Length (Id : Token_Id) return Natural is
   begin
      Ensure;
      return Known_Length (Id);
   end Piece_Length;

   function Piece_Byte (Id : Token_Id; Pos : Positive) return Byte is
   begin
      Ensure;
      return Known_Byte (Id, Pos);
   end Piece_Byte;

   function Merge_Left (Rank : Positive) return Token_Id is
   begin
      Ensure;
      return Rules (Rank).Left;
   end Merge_Left;

   function Merge_Right (Rank : Positive) return Token_Id is
   begin
      Ensure;
      return Rules (Rank).Right;
   end Merge_Right;

end AI_Amplifier.BPE;
