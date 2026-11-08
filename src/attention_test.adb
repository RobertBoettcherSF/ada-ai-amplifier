with Ada.Assertions;
with Ada.Command_Line;
with Ada.Text_IO;
with AI_Amplifier.Attention.Demo;
with AI_Amplifier.BPE;
with AI_Amplifier.Tensors;

--  Byte-level BPE against its round trip, and one attention block
--  against a hand-computed two-token pass. Rows of the causal
--  weights sum to 1. A future column is exactly 0.
procedure Attention_Test
  with SPARK_Mode => Off
is
   package B renames AI_Amplifier.BPE;
   package A renames AI_Amplifier.Attention;
   package D renames AI_Amplifier.Attention.Demo;
   package T renames AI_Amplifier.Tensors;

   Tol      : constant := 0.000_05;
   Failures : Natural := 0;
   Cases    : Natural := 0;

   procedure Mark is
   begin
      Cases := Cases + 1;
   end Mark;

   procedure Fail (Message : String) is
   begin
      Ada.Text_IO.Put_Line ("FAIL " & Message);
      Failures := Failures + 1;
   end Fail;

   function Near (Got, Want : Float) return Boolean is
      Diff : Float := Got - Want;
   begin
      if Diff < 0.0 then
         Diff := -Diff;
      end if;
      return Diff <= Tol;
   end Near;

   procedure Expect (Name : String; Got, Want : Float) is
   begin
      Mark;
      if not Near (Got, Want) then
         Fail (Name & " got " & Float'Image (Got)
           & " want " & Float'Image (Want));
      end if;
   end Expect;

   procedure Round_Trip (Name : String; Bytes : B.Byte_Array) is
      Tokens : constant B.Token_List := B.Encode (Bytes);
      Back   : B.Byte_List;
   begin
      Mark;
      if Tokens.Count > Bytes'Length then
         Fail (Name & " grew");
      end if;
      B.Decode (Tokens, Back);
      if Back.Count /= Bytes'Length then
         Fail (Name & " length " & Natural'Image (Back.Count));
         return;
      end if;
      for I in Bytes'Range loop
         if Back.Data (I - Bytes'First + 1) /= Bytes (I) then
            Fail (Name & " byte" & Integer'Image (I));
            return;
         end if;
      end loop;
   end Round_Trip;

   function Eye (Factor : Float) return T.Matrix is
      M : T.Matrix (A.D_Model, A.D_Model) :=
        (Rows => A.D_Model,
         Cols => A.D_Model,
         Data => (others => (others => 0.0)));
   begin
      for I in 1 .. A.D_Model loop
         M.Data (I, I) := Factor;
      end loop;
      return M;
   end Eye;

   function Vec (X, Y : Float) return T.Vector is
     (Length => A.D_Model,
      Data   => (X, Y, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0));

   function Flat (Value : Float) return T.Vector is
     (Length => A.D_Model, Data => (others => Value));

   procedure Check_Rows
     (Name : String;
      W    : A.Weight_Grid;
      N    : Natural)
   is
      Sum : Float;
   begin
      for I in 1 .. N loop
         Sum := 0.0;
         for J in 1 .. N loop
            if J > I and then W (I, J) /= 0.0 then
               Fail (Name & " future" & Integer'Image (I));
            end if;
            Sum := Sum + W (I, J);
         end loop;
         Expect (Name & " sum" & Integer'Image (I), Sum, 1.0);
      end loop;
      if N < A.Max_Seq and then W (1, N + 1) /= 0.0 then
         Fail (Name & " tail");
      end if;
   end Check_Rows;

   function Same_Block (L, R : A.Block) return Boolean is
   begin
      for I in 1 .. A.D_Model loop
         for J in 1 .. A.D_Model loop
            if L.W_Q.Data (I, J) /= R.W_Q.Data (I, J)
              or else L.W_K.Data (I, J) /= R.W_K.Data (I, J)
              or else L.W_V.Data (I, J) /= R.W_V.Data (I, J)
              or else L.W_O.Data (I, J) /= R.W_O.Data (I, J)
            then
               return False;
            end if;
         end loop;
         if L.Gamma.Data (I) /= R.Gamma.Data (I)
           or else L.Beta.Data (I) /= R.Beta.Data (I)
         then
            return False;
         end if;
      end loop;
      return True;
   end Same_Block;

begin
   if B.Corpus_Length /= 563 then
      Fail ("corpus length");
   end if;
   declare
      Prefix : constant String := "Alice was beginning";
   begin
      for I in Prefix'Range loop
         if B.Corpus_Byte (I) /= Character'Pos (Prefix (I)) then
            Fail ("corpus prefix");
            exit;
         end if;
      end loop;
   end;
   if B.Corpus_Byte (0) /= 0 or else B.Corpus_Byte (9_999) /= 0 then
      Fail ("corpus clamp");
   end if;

   if B.Merge_Count /= 32 or else B.Vocab_Size /= 288 then
      Fail ("vocab " & Natural'Image (B.Merge_Count));
   end if;
   if B.Merge_Left (1) /= Character'Pos ('e')
     or else B.Merge_Right (1) /= Character'Pos (' ')
   then
      Fail ("first merge");
   end if;

   for Rank in 1 .. B.Merge_Count loop
      declare
         Left  : constant B.Token_Id := B.Merge_Left (Rank);
         Right : constant B.Token_Id := B.Merge_Right (Rank);
         Id    : constant B.Token_Id := B.Byte_Tokens + Rank - 1;
         L_Len : constant Natural := B.Piece_Length (Left);
         R_Len : constant Natural := B.Piece_Length (Right);
      begin
         if B.Piece_Length (Id) /= L_Len + R_Len then
            Fail ("piece length" & Integer'Image (Rank));
         else
            for I in 1 .. L_Len loop
               if B.Piece_Byte (Id, I) /= B.Piece_Byte (Left, I) then
                  Fail ("piece left" & Integer'Image (Rank));
               end if;
            end loop;
            for I in 1 .. R_Len loop
               if B.Piece_Byte (Id, L_Len + I) /= B.Piece_Byte (Right, I)
               then
                  Fail ("piece right" & Integer'Image (Rank));
               end if;
            end loop;
         end if;
      end;
   end loop;

   Round_Trip ("empty", (1 .. 0 => 0));
   Round_Trip ("ascii", (1 => Character'Pos ('h'),
                          2 => Character'Pos ('i')));
   declare
      Hello : constant String := "hello";
      Bytes : B.Byte_Array (Hello'Range);
   begin
      for I in Hello'Range loop
         Bytes (I) := Character'Pos (Hello (I));
      end loop;
      Round_Trip ("hello", Bytes);
   end;

   declare
      Umlaut : constant B.Byte_Array :=
        (16#61#, 16#C3#, 16#A4#, 16#C3#, 16#9F#);
      Eszett : constant B.Byte_Array := (16#C3#, 16#9F#);
      A_Uml  : constant B.Byte_Array := (16#C3#, 16#A4#);
      Tokens : B.Token_List;
   begin
      Round_Trip ("a-umlaut-eszett", Umlaut);
      Tokens := B.Encode (Eszett);
      if Tokens.Count /= 1
        or else B.Piece_Length (Tokens.Id (1)) /= 2
        or else B.Piece_Byte (Tokens.Id (1), 1) /= 16#C3#
        or else B.Piece_Byte (Tokens.Id (1), 2) /= 16#9F#
      then
         Fail ("eszett merge");
      end if;
      Tokens := B.Encode (A_Uml);
      if Tokens.Count /= 2
        or else Tokens.Id (1) /= 16#C3#
        or else Tokens.Id (2) /= 16#A4#
      then
         Fail ("a umlaut stays two bytes");
      end if;
   end;

   declare
      All_Bytes : B.Byte_Array (1 .. 256);
   begin
      for I in All_Bytes'Range loop
         All_Bytes (I) := I - 1;
      end loop;
      Round_Trip ("all bytes", All_Bytes);
   end;

   declare
      Bytes  : B.Byte_Array (1 .. B.Corpus_Length);
      Tokens : B.Token_List;
      Again  : B.Token_List;
   begin
      for I in Bytes'Range loop
         Bytes (I) := B.Corpus_Byte (I);
      end loop;
      Tokens := B.Encode (Bytes);
      Again := B.Encode (Bytes);
      if Tokens.Count /= 376 then
         Fail ("corpus tokens" & Natural'Image (Tokens.Count));
      end if;
      if Tokens.Count >= Bytes'Length then
         Fail ("corpus did not merge");
      end if;
      if Again.Count /= Tokens.Count then
         Fail ("encode drifted");
      end if;
      for I in 1 .. Tokens.Count loop
         if Again.Id (I) /= Tokens.Id (I) then
            Fail ("encode id drifted");
            exit;
         end if;
      end loop;
      Round_Trip ("corpus", Bytes);
   end;

   declare
      Too_Long : constant B.Byte_Array (1 .. B.Max_Input + 1) :=
        (others => 65);
      Raised   : Boolean := False;
      Tokens   : B.Token_List;
   begin
      begin
         Tokens := B.Encode (Too_Long);
         Fail ("long encode returned" & Natural'Image (Tokens.Count));
      exception
         when Ada.Assertions.Assertion_Error =>
            Raised := True;
      end;
      if not Raised then
         Fail ("long encode did not raise");
      end if;
   end;

   declare
      E1 : constant T.Vector := Vec (1.0, 0.0);
      E2 : constant T.Vector :=
        (Length => A.D_Model,
         Data   => (0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0));
   begin
      Expect ("scaled dot", A.Scaled_Dot (E1, E1), 0.353_553_38);
      if A.Scaled_Dot (E1, E2) /= 0.0 then
         Fail ("orthogonal dot");
      end if;
   end;

   declare
      Model : A.Block;
      X     : A.Vector_List;
      W     : A.Weight_Grid;
      Y     : A.Vector_List;
   begin
      --  Hand example. Q and K are zero, so every unmasked score is
      --  0. V is the identity, W_O doubles, gamma is 1, beta is 0.
      --  Row 1 is softmax of a single 0, which is 1, and the future
      --  weight is 0. Row 2 is softmax of two 0s, which is 1/2, 1/2.
      --  context is X1 and the average of X1 and X2. Doubling and
      --  adding X gives (3, 9, 0..) and (11, 17, 0..). Layer norm
      --  of those, population variance, eps 1e-5, is the Y below.
      Model.W_Q := Eye (0.0);
      Model.W_K := Eye (0.0);
      Model.W_V := Eye (1.0);
      Model.W_O := Eye (2.0);
      Model.Gamma := Flat (1.0);
      Model.Beta := Flat (0.0);
      X.Count := 2;
      X.Item (1) := Vec (1.0, 3.0);
      X.Item (2) := Vec (5.0, 7.0);
      A.Forward (Model, X, W, Y);
      if W (1, 1) /= 1.0 or else W (1, 2) /= 0.0
        or else W (2, 1) /= 0.5 or else W (2, 2) /= 0.5
      then
         Fail ("hand weights");
      end if;
      Check_Rows ("hand", W, 2);
      Expect ("y1.1", Y.Item (1).Data (1), 0.499_999_8);
      Expect ("y1.2", Y.Item (1).Data (2), 2.499_998_8);
      Expect ("y2.1", Y.Item (2).Data (1), 1.200_961_0);
      Expect ("y2.2", Y.Item (2).Data (2), 2.161_729_8);
      for I in 3 .. A.D_Model loop
         Expect ("y1." & Integer'Image (I),
                 Y.Item (1).Data (I), -0.499_999_8);
         Expect ("y2." & Integer'Image (I),
                 Y.Item (2).Data (I), -0.560_448_5);
      end loop;

      Model.Gamma := Flat (2.0);
      Model.Beta := Flat (0.5);
      declare
         Plain : constant T.Vector := Y.Item (1);
         Y2    : A.Vector_List;
      begin
         A.Forward (Model, X, W, Y2);
         Expect
           ("affine",
            Y2.Item (1).Data (1),
            2.0 * Plain.Data (1) + 0.5);
      end;
   end;

   declare
      Model : A.Block;
      X     : A.Vector_List;
      W     : A.Weight_Grid;
      Y     : A.Vector_List;
   begin
      Model.W_Q := Eye (0.0);
      Model.W_K := Eye (0.0);
      Model.W_V := Eye (1.0);
      Model.W_O := Eye (1.0);
      Model.Gamma := Flat (1.0);
      Model.Beta := Flat (0.0);
      X.Count := 3;
      X.Item (1) := Vec (1.0, 0.0);
      X.Item (2) := Vec (0.0, 1.0);
      X.Item (3) := Vec (4.0, 4.0);
      A.Forward (Model, X, W, Y);
      if W (1, 1) /= 1.0 or else W (1, 2) /= 0.0 or else W (1, 3) /= 0.0
        or else W (2, 3) /= 0.0
        or else W (2, 1) /= 0.5 or else W (2, 2) /= 0.5
      then
         Fail ("three-token mask");
      end if;
      Expect ("third", W (3, 1), 1.0 / 3.0);
      Expect ("third2", W (3, 2), 1.0 / 3.0);
      Expect ("third3", W (3, 3), 1.0 / 3.0);
      Check_Rows ("three", W, 3);

      --  Without the mask, token 1 would attend mostly to token 2:
      --  the score would be 10/sqrt(8) against 1/sqrt(8). The mask
      --  keeps that weight at 0 and leaves token 1 on itself.
      Model.W_Q := Eye (1.0);
      Model.W_K := Eye (1.0);
      X.Count := 2;
      X.Item (1) := Vec (1.0, 0.0);
      X.Item (2) := Vec (10.0, 0.0);
      A.Forward (Model, X, W, Y);
      if W (1, 1) /= 1.0 or else W (1, 2) /= 0.0 then
         Fail ("mask blocked a larger future score");
      end if;
      if W (2, 2) <= W (2, 1) then
         Fail ("token 2 should prefer itself");
      end if;
      Check_Rows ("mask", W, 2);
   end;

   declare
      Empty : A.Vector_List;
      Model : A.Block;
      W     : A.Weight_Grid;
      Y     : A.Vector_List;
   begin
      Model.W_Q := Eye (1.0);
      Model.W_K := Eye (1.0);
      Model.W_V := Eye (1.0);
      Model.W_O := Eye (1.0);
      Model.Gamma := Flat (1.0);
      Model.Beta := Flat (0.0);
      Empty.Count := 0;
      A.Forward (Model, Empty, W, Y);
      if Y.Count /= 0 or else W (1, 1) /= 0.0 then
         Fail ("empty forward");
      end if;
   end;

   declare
      One   : A.Block;
      Two   : A.Block;
      Other : A.Block;
   begin
      A.Initialize (One, A.Embed_Seed);
      A.Initialize (Two, A.Embed_Seed);
      A.Initialize (Other, 1);
      if not Same_Block (One, Two) then
         Fail ("seed drifted");
      end if;
      if Same_Block (One, Other) then
         Fail ("seeds collided");
      end if;
      if One.Gamma.Data (1) /= 1.0 or else One.Beta.Data (1) /= 0.0 then
         Fail ("gamma beta");
      end if;
   end;

   declare
      Tok : constant T.Vector := A.Token_Vector (65);
      Pos : constant T.Vector := A.Position_Vector (1);
      Sum : constant T.Vector := T.Add (Tok, Pos);
      Emb : constant T.Vector := A.Embed (65, 1);
      Differs : Boolean := False;
   begin
      for I in 1 .. A.D_Model loop
         if Sum.Data (I) /= Emb.Data (I) then
            Fail ("embed add");
         end if;
         if A.Token_Vector (65).Data (I) /= A.Token_Vector (66).Data (I)
           or else A.Position_Vector (1).Data (I)
             /= A.Position_Vector (2).Data (I)
         then
            Differs := True;
         end if;
      end loop;
      if not Differs then
         Fail ("embeddings identical");
      end if;
      if A.Token_Vector (0).Data (1) /= A.Token_Vector (0).Data (1) then
         Fail ("token embed unstable");
      end if;
   end;

   declare
      Phrase : constant String := "Alice was beginning";
      Bytes  : B.Byte_Array (Phrase'Range);
      Tokens : B.Token_List;
      W1, W2 : A.Weight_Grid;
      Used   : Natural;
      X      : A.Vector_List;
      Y      : A.Vector_List;
      Model  : A.Block;
   begin
      for I in Phrase'Range loop
         Bytes (I) := Character'Pos (Phrase (I));
      end loop;
      Tokens := B.Encode (Bytes);
      A.Forward_Tokens (Tokens, W1, Used);
      if Used = 0 or else Used > A.Max_Seq
        or else Used > Tokens.Count
      then
         Fail ("used");
      end if;
      Check_Rows ("seeded", W1, Used);
      X.Count := Used;
      for I in 1 .. Used loop
         X.Item (I) := A.Embed (Tokens.Id (I), I);
      end loop;
      A.Initialize (Model, A.Embed_Seed);
      A.Forward (Model, X, W2, Y);
      for I in 1 .. Used loop
         for J in 1 .. Used loop
            if W1 (I, J) /= W2 (I, J) then
               Fail ("seeded block mismatch");
            end if;
         end loop;
      end loop;
   end;

   D.Clear;
   if D.Run /= 0 or else D.Token_Count /= 0 or else D.Used_Count /= 0
   then
      Fail ("demo empty");
   end if;
   if D.Token_At (1) /= 0 or else D.Weight (1, 1) /= 0.0
     or else D.Piece_Len (1) /= 0 or else D.Piece_At (1, 1) /= 0
   then
      Fail ("demo clamp");
   end if;

   D.Push (-1);
   D.Push (256);
   D.Push (Character'Pos ('A'));
   if D.Byte_Count /= 1 or else D.Dropped_Bytes /= 0 then
      Fail ("demo ignored");
   end if;
   if D.Run /= 1 or else D.Token_At (1) /= Character'Pos ('A') then
      Fail ("demo single");
   end if;
   if D.Weight (1, 1) /= 1.0 then
      Fail ("demo one weight");
   end if;

   D.Clear;
   D.Push (16#C3#);
   D.Push (16#A4#);
   D.Push (16#C3#);
   D.Push (16#9F#);
   if D.Run < 2 then
      Fail ("demo umlaut run");
   end if;
   declare
      Back : array (1 .. 4) of Integer := (others => 0);
      N    : Natural := 0;
   begin
      for I in 1 .. D.Token_Count loop
         for J in 1 .. D.Piece_Len (I) loop
            N := N + 1;
            if N <= Back'Last then
               Back (N) := D.Piece_At (I, J);
            end if;
         end loop;
      end loop;
      if N /= 4
        or else Back (1) /= 16#C3# or else Back (2) /= 16#A4#
        or else Back (3) /= 16#C3# or else Back (4) /= 16#9F#
      then
         Fail ("demo umlaut bytes");
      end if;
   end;
   declare
      Sum : Float;
   begin
      for I in 1 .. D.Used_Count loop
         Sum := 0.0;
         for J in 1 .. D.Used_Count loop
            if J > I and then D.Weight (I, J) /= 0.0 then
               Fail ("demo future");
            end if;
            Sum := Sum + D.Weight (I, J);
         end loop;
         Expect ("demo sum", Sum, 1.0);
      end loop;
   end;

   D.Clear;
   for I in 1 .. B.Max_Input + 3 loop
      D.Push (Character'Pos ('a'));
   end loop;
   if D.Byte_Count /= B.Max_Input or else D.Dropped_Bytes /= 3 then
      Fail ("demo dropped");
   end if;
   if D.Run = 0 or else D.Used_Count > A.Max_Seq then
      Fail ("demo long run");
   end if;
   if D.Merges /= 32 or else D.Vocab /= 288
     or else D.Corpus_Bytes /= 563
   then
      Fail ("demo census");
   end if;

   if Failures = 0 then
      Ada.Text_IO.Put_Line ("cases attention_test" & Cases'Image);
      Ada.Text_IO.Put_Line ("attention ok");
   else
      Ada.Text_IO.Put_Line
        ("attention failed" & Natural'Image (Failures));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Attention_Test;
