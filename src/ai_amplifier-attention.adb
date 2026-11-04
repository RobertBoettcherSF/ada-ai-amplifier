package body AI_Amplifier.Attention
  with SPARK_Mode => Off
is

   pragma Assertion_Policy (Pre => Check, Post => Check);

   package T renames AI_Amplifier.Tensors;

   type Word is mod 2 ** 32;

   type Hidden is array (1 .. Max_Seq) of T.Vector (D_Model);

   function Sqrt_Of (X : Float) return Float is
      G : Float;
   begin
      if X <= 0.0 then
         return 0.0;
      end if;
      G := X;
      for K in 1 .. 10 loop
         G := 0.5 * (G + X / G);
      end loop;
      return G;
   end Sqrt_Of;

   function Scale_Of return Float is
     (1.0 / Sqrt_Of (Float (D_Model)));

   function Next_Unit (State : in out Word) return Float is
   begin
      State := State * 1664525 + 1013904223;
      --  Top 24 bits, so the result is in [0, 1) and exact in Float.
      return Float (State / 256) / 16_777_216.0;
   end Next_Unit;

   function Draw (State : in out Word) return Float is
      U : constant Float := Next_Unit (State);
   begin
      return (U * 2.0 - 1.0) * Scale_Of;
   end Draw;

   function Scaled_Dot (Left, Right : T.Vector) return Float is
   begin
      return T.Dot (Left, Right) * Scale_Of;
   end Scaled_Dot;

   --  A vector stored in an array and then passed straight into a
   --  tensor kernel is not the view this wasm runtime dots. Building
   --  a fresh aggregate from the component array is. Callers that
   --  already hold a Float array use that aggregate at the call.
   function Layer_Norm
     (V, Gamma, Beta : T.Element_Array) return T.Vector
   is
      Mean   : Float := 0.0;
      Var    : Float := 0.0;
      Inv    : Float;
      Shift  : Float;
      Result : T.Vector (D_Model) :=
        (Length => D_Model, Data => (others => 0.0));
   begin
      for I in 1 .. D_Model loop
         Mean := Mean + V (I);
      end loop;
      Mean := Mean / Float (D_Model);

      for I in 1 .. D_Model loop
         Shift := V (I) - Mean;
         Var := Var + Shift * Shift;
      end loop;
      Var := Var / Float (D_Model);
      Inv := 1.0 / Sqrt_Of (Var + Eps);

      for I in 1 .. D_Model loop
         Result.Data (I) :=
           Gamma (I) * (V (I) - Mean) * Inv + Beta (I);
      end loop;
      return Result;
   end Layer_Norm;

   function Softmax_Of (Data : T.Element_Array) return T.Vector is
      Scores : constant T.Vector := (Length => Data'Length, Data => Data);
   begin
      return T.Softmax (Scores);
   end Softmax_Of;

   function Zero_Hidden return Hidden is
      Blank : constant T.Vector (D_Model) :=
        (Length => D_Model, Data => (others => 0.0));
   begin
      return (others => Blank);
   end Zero_Hidden;

   procedure Initialize
     (Model : out Block;
      Seed  : Natural := Embed_Seed)
   is
      State : Word := Word (Seed);
   begin
      Model.W_Q :=
        (Rows => D_Model,
         Cols => D_Model,
         Data => (others => (others => 0.0)));
      Model.W_K := Model.W_Q;
      Model.W_V := Model.W_Q;
      Model.W_O := Model.W_Q;
      for R in 1 .. D_Model loop
         for C in 1 .. D_Model loop
            Model.W_Q.Data (R, C) := Draw (State);
         end loop;
      end loop;
      for R in 1 .. D_Model loop
         for C in 1 .. D_Model loop
            Model.W_K.Data (R, C) := Draw (State);
         end loop;
      end loop;
      for R in 1 .. D_Model loop
         for C in 1 .. D_Model loop
            Model.W_V.Data (R, C) := Draw (State);
         end loop;
      end loop;
      for R in 1 .. D_Model loop
         for C in 1 .. D_Model loop
            Model.W_O.Data (R, C) := Draw (State);
         end loop;
      end loop;
      Model.Gamma := (Length => D_Model, Data => (others => 1.0));
      Model.Beta := (Length => D_Model, Data => (others => 0.0));
   end Initialize;

   procedure Forward
     (Model   : Block;
      X       : Vector_List;
      Weights : out Weight_Grid;
      Y       : out Vector_List)
   is
      Q   : Hidden := Zero_Hidden;
      K   : Hidden := Zero_Hidden;
      V   : Hidden := Zero_Hidden;
      Ctx : T.Vector (D_Model);
   begin
      Weights := (others => (others => 0.0));
      Y :=
        (Count => X.Count,
         Item  =>
           (others =>
              (Length => D_Model, Data => (others => 0.0))));
      if X.Count = 0 then
         return;
      end if;

      for I in 1 .. X.Count loop
         declare
            X_Row : constant T.Vector :=
              (Length => D_Model, Data => X.Item (I).Data);
            Q_Row : constant T.Vector := T.Mat_Vec (Model.W_Q, X_Row);
            K_Row : constant T.Vector := T.Mat_Vec (Model.W_K, X_Row);
            V_Row : constant T.Vector := T.Mat_Vec (Model.W_V, X_Row);
         begin
            for C in 1 .. D_Model loop
               Q (I).Data (C) := Q_Row.Data (C);
               K (I).Data (C) := K_Row.Data (C);
               V (I).Data (C) := V_Row.Data (C);
            end loop;
         end;
      end loop;

      --  Each score vector has a static length. A discriminant taken
      --  from I would be a run-time size, and this wasm runtime has
      --  no secondary stack for that. The softmax is still
      --  Tensors.Softmax, over 1 .. I only.
      for I in 1 .. X.Count loop
         declare
            N : constant Place := I;
         begin
            case N is
               when 1 =>
                  declare
                     S : T.Vector (1) :=
                       (Length => 1, Data => (others => 0.0));
                     P : T.Vector (1);
                  begin
                     S.Data (1) := Scaled_Dot
                    ((Length => D_Model, Data => Q (I).Data),
                     (Length => D_Model, Data => K (1).Data));
                     P := Softmax_Of (S.Data);
                     Weights (I, 1) := P.Data (1);
                  end;
               when 2 =>
                  declare
                     S : T.Vector (2) :=
                       (Length => 2, Data => (others => 0.0));
                     P : T.Vector (2);
                  begin
                     for J in 1 .. 2 loop
                        S.Data (J) := Scaled_Dot
                       ((Length => D_Model, Data => Q (I).Data),
                        (Length => D_Model, Data => K (J).Data));
                     end loop;
                     P := Softmax_Of (S.Data);
                     for J in 1 .. 2 loop
                        Weights (I, J) := P.Data (J);
                     end loop;
                  end;
               when 3 =>
                  declare
                     S : T.Vector (3) :=
                       (Length => 3, Data => (others => 0.0));
                     P : T.Vector (3);
                  begin
                     for J in 1 .. 3 loop
                        S.Data (J) := Scaled_Dot
                       ((Length => D_Model, Data => Q (I).Data),
                        (Length => D_Model, Data => K (J).Data));
                     end loop;
                     P := Softmax_Of (S.Data);
                     for J in 1 .. 3 loop
                        Weights (I, J) := P.Data (J);
                     end loop;
                  end;
               when 4 =>
                  declare
                     S : T.Vector (4) :=
                       (Length => 4, Data => (others => 0.0));
                     P : T.Vector (4);
                  begin
                     for J in 1 .. 4 loop
                        S.Data (J) := Scaled_Dot
                       ((Length => D_Model, Data => Q (I).Data),
                        (Length => D_Model, Data => K (J).Data));
                     end loop;
                     P := Softmax_Of (S.Data);
                     for J in 1 .. 4 loop
                        Weights (I, J) := P.Data (J);
                     end loop;
                  end;
               when 5 =>
                  declare
                     S : T.Vector (5) :=
                       (Length => 5, Data => (others => 0.0));
                     P : T.Vector (5);
                  begin
                     for J in 1 .. 5 loop
                        S.Data (J) := Scaled_Dot
                       ((Length => D_Model, Data => Q (I).Data),
                        (Length => D_Model, Data => K (J).Data));
                     end loop;
                     P := Softmax_Of (S.Data);
                     for J in 1 .. 5 loop
                        Weights (I, J) := P.Data (J);
                     end loop;
                  end;
               when 6 =>
                  declare
                     S : T.Vector (6) :=
                       (Length => 6, Data => (others => 0.0));
                     P : T.Vector (6);
                  begin
                     for J in 1 .. 6 loop
                        S.Data (J) := Scaled_Dot
                       ((Length => D_Model, Data => Q (I).Data),
                        (Length => D_Model, Data => K (J).Data));
                     end loop;
                     P := Softmax_Of (S.Data);
                     for J in 1 .. 6 loop
                        Weights (I, J) := P.Data (J);
                     end loop;
                  end;
               when 7 =>
                  declare
                     S : T.Vector (7) :=
                       (Length => 7, Data => (others => 0.0));
                     P : T.Vector (7);
                  begin
                     for J in 1 .. 7 loop
                        S.Data (J) := Scaled_Dot
                       ((Length => D_Model, Data => Q (I).Data),
                        (Length => D_Model, Data => K (J).Data));
                     end loop;
                     P := Softmax_Of (S.Data);
                     for J in 1 .. 7 loop
                        Weights (I, J) := P.Data (J);
                     end loop;
                  end;
               when 8 =>
                  declare
                     S : T.Vector (8) :=
                       (Length => 8, Data => (others => 0.0));
                     P : T.Vector (8);
                  begin
                     for J in 1 .. 8 loop
                        S.Data (J) := Scaled_Dot
                       ((Length => D_Model, Data => Q (I).Data),
                        (Length => D_Model, Data => K (J).Data));
                     end loop;
                     P := Softmax_Of (S.Data);
                     for J in 1 .. 8 loop
                        Weights (I, J) := P.Data (J);
                     end loop;
                  end;
               when 9 =>
                  declare
                     S : T.Vector (9) :=
                       (Length => 9, Data => (others => 0.0));
                     P : T.Vector (9);
                  begin
                     for J in 1 .. 9 loop
                        S.Data (J) := Scaled_Dot
                       ((Length => D_Model, Data => Q (I).Data),
                        (Length => D_Model, Data => K (J).Data));
                     end loop;
                     P := Softmax_Of (S.Data);
                     for J in 1 .. 9 loop
                        Weights (I, J) := P.Data (J);
                     end loop;
                  end;
               when 10 =>
                  declare
                     S : T.Vector (10) :=
                       (Length => 10, Data => (others => 0.0));
                     P : T.Vector (10);
                  begin
                     for J in 1 .. 10 loop
                        S.Data (J) := Scaled_Dot
                       ((Length => D_Model, Data => Q (I).Data),
                        (Length => D_Model, Data => K (J).Data));
                     end loop;
                     P := Softmax_Of (S.Data);
                     for J in 1 .. 10 loop
                        Weights (I, J) := P.Data (J);
                     end loop;
                  end;
               when 11 =>
                  declare
                     S : T.Vector (11) :=
                       (Length => 11, Data => (others => 0.0));
                     P : T.Vector (11);
                  begin
                     for J in 1 .. 11 loop
                        S.Data (J) := Scaled_Dot
                       ((Length => D_Model, Data => Q (I).Data),
                        (Length => D_Model, Data => K (J).Data));
                     end loop;
                     P := Softmax_Of (S.Data);
                     for J in 1 .. 11 loop
                        Weights (I, J) := P.Data (J);
                     end loop;
                  end;
               when 12 =>
                  declare
                     S : T.Vector (12) :=
                       (Length => 12, Data => (others => 0.0));
                     P : T.Vector (12);
                  begin
                     for J in 1 .. 12 loop
                        S.Data (J) := Scaled_Dot
                       ((Length => D_Model, Data => Q (I).Data),
                        (Length => D_Model, Data => K (J).Data));
                     end loop;
                     P := Softmax_Of (S.Data);
                     for J in 1 .. 12 loop
                        Weights (I, J) := P.Data (J);
                     end loop;
                  end;
               when 13 =>
                  declare
                     S : T.Vector (13) :=
                       (Length => 13, Data => (others => 0.0));
                     P : T.Vector (13);
                  begin
                     for J in 1 .. 13 loop
                        S.Data (J) := Scaled_Dot
                       ((Length => D_Model, Data => Q (I).Data),
                        (Length => D_Model, Data => K (J).Data));
                     end loop;
                     P := Softmax_Of (S.Data);
                     for J in 1 .. 13 loop
                        Weights (I, J) := P.Data (J);
                     end loop;
                  end;
               when 14 =>
                  declare
                     S : T.Vector (14) :=
                       (Length => 14, Data => (others => 0.0));
                     P : T.Vector (14);
                  begin
                     for J in 1 .. 14 loop
                        S.Data (J) := Scaled_Dot
                       ((Length => D_Model, Data => Q (I).Data),
                        (Length => D_Model, Data => K (J).Data));
                     end loop;
                     P := Softmax_Of (S.Data);
                     for J in 1 .. 14 loop
                        Weights (I, J) := P.Data (J);
                     end loop;
                  end;
               when 15 =>
                  declare
                     S : T.Vector (15) :=
                       (Length => 15, Data => (others => 0.0));
                     P : T.Vector (15);
                  begin
                     for J in 1 .. 15 loop
                        S.Data (J) := Scaled_Dot
                       ((Length => D_Model, Data => Q (I).Data),
                        (Length => D_Model, Data => K (J).Data));
                     end loop;
                     P := Softmax_Of (S.Data);
                     for J in 1 .. 15 loop
                        Weights (I, J) := P.Data (J);
                     end loop;
                  end;
               when 16 =>
                  declare
                     S : T.Vector (16) :=
                       (Length => 16, Data => (others => 0.0));
                     P : T.Vector (16);
                  begin
                     for J in 1 .. 16 loop
                        S.Data (J) := Scaled_Dot
                       ((Length => D_Model, Data => Q (I).Data),
                        (Length => D_Model, Data => K (J).Data));
                     end loop;
                     P := Softmax_Of (S.Data);
                     for J in 1 .. 16 loop
                        Weights (I, J) := P.Data (J);
                     end loop;
                  end;
            end case;
         end;

         Ctx := (Length => D_Model, Data => (others => 0.0));
         for J in 1 .. X.Count loop
            declare
               Step : constant T.Vector :=
                 T.Scale
                   ((Length => D_Model, Data => V (J).Data),
                    Weights (I, J));
               Sum : constant T.Vector :=
                 T.Add ((Length => D_Model, Data => Ctx.Data), Step);
            begin
               for C in 1 .. D_Model loop
                  Ctx.Data (C) := Sum.Data (C);
               end loop;
            end;
         end loop;
         declare
            Proj : constant T.Vector :=
              T.Mat_Vec
                (Model.W_O, (Length => D_Model, Data => Ctx.Data));
            Resid : T.Element_Array (1 .. D_Model);
         begin
            for C in 1 .. D_Model loop
               Resid (C) := Proj.Data (C) + X.Item (I).Data (C);
            end loop;
            Y.Item (I) :=
              Layer_Norm (Resid, Model.Gamma.Data, Model.Beta.Data);
         end;
      end loop;
   end Forward;

   Blank : constant T.Vector (D_Model) :=
     (Length => D_Model, Data => (others => 0.0));

   Token_Table : array (BPE.Token_Id) of T.Vector (D_Model) :=
     (others => Blank);
   Pos_Table : array (Place) of T.Vector (D_Model) := (others => Blank);
   Seeded    : Block;
   Ready     : Boolean := False;

   procedure Ensure_Tables is
      State : Word := Word (Embed_Seed);
   begin
      if Ready then
         return;
      end if;
      --  Projections are their own stream from the same seed.
      Initialize (Seeded, Embed_Seed);
      for Id in BPE.Token_Id loop
         for C in 1 .. D_Model loop
            Token_Table (Id).Data (C) := Draw (State);
         end loop;
      end loop;
      for Index in Place loop
         for C in 1 .. D_Model loop
            Pos_Table (Index).Data (C) := Draw (State);
         end loop;
      end loop;
      Ready := True;
   end Ensure_Tables;

   function Token_Vector (Id : BPE.Token_Id) return T.Vector is
   begin
      Ensure_Tables;
      return (Length => D_Model, Data => Token_Table (Id).Data);
   end Token_Vector;

   function Position_Vector (Index : Place) return T.Vector is
   begin
      Ensure_Tables;
      return (Length => D_Model, Data => Pos_Table (Index).Data);
   end Position_Vector;

   function Embed
     (Id : BPE.Token_Id; Index : Place) return T.Vector
   is
   begin
      Ensure_Tables;
      return T.Add
        ((Length => D_Model, Data => Token_Table (Id).Data),
         (Length => D_Model, Data => Pos_Table (Index).Data));
   end Embed;

   procedure Forward_Tokens
     (Tokens  : BPE.Token_List;
      Weights : out Weight_Grid;
      Used    : out Natural)
   is
      X : Vector_List;
      Y : Vector_List;
   begin
      Ensure_Tables;
      if Tokens.Count > Max_Seq then
         X.Count := Max_Seq;
      else
         X.Count := Tokens.Count;
      end if;
      for I in 1 .. X.Count loop
         X.Item (I) := Embed (Tokens.Id (I), I);
      end loop;
      Forward (Seeded, X, Weights, Y);
      Used := Y.Count;
   end Forward_Tokens;

end AI_Amplifier.Attention;
