--  One single-head self-attention block on AI_Amplifier.Tensors.
--
--  Plain Ada (SPARK_Mode off). Forward only: nothing here is trained,
--  and nothing is proved. The Pre and Post are ordinary Ada contracts.
--
--  Width is D_Model, which fits in Tensors.Max_Extent. A sequence is
--  at most Max_Seq positions, also inside that extent, so a row of
--  scores is a Vector and a projection is a Matrix.
--
--  Token embeddings and position embeddings are seeded Float vectors
--  of that width, one per BPE id and one per place. They are not one
--  giant matrix: the vocabulary is larger than Max_Extent. The block
--  weights use the same generator as AI_Amplifier.MLP, in their own
--  stream:
--    state := state * 1664525 + 1013904223   (mod 2**32)
--  Each drawn component is uniform on [-s, s) with s = 1/sqrt(D_Model).
--  The projection stream and the embedding stream both start at
--  Embed_Seed, separately. Gamma starts at 1 and beta at 0.
--
--  For one sequence of vectors X(1) .. X(n):
--    Q = W_Q X,  K = W_K X,  V = W_V X     (no bias)
--    score(i, j) = Q(i) dot K(j) / sqrt(D_Model)    for j <= i
--    the softmax for row i runs only over j = 1 .. i
--    a later column is 0, not a tiny exponential
--    context(i) = sum_j weight(i, j) * V(j)
--    Y(i) = LayerNorm (W_O context(i) + X(i))
--  LayerNorm uses the population variance (divide by D_Model, not
--  D_Model - 1) and Eps under the square root. That is the whole
--  block. There is no second head and no feed-forward layer.
with AI_Amplifier.BPE;
with AI_Amplifier.Tensors;

package AI_Amplifier.Attention
  with SPARK_Mode => Off
is

   pragma Assertion_Policy (Pre => Check, Post => Check);

   D_Model : constant := 8;
   Max_Seq : constant := 16;
   Eps     : constant := 1.0e-5;

   --  2026-11-04, the same number AI_Amplifier.MLP uses. A separate
   --  generator, not a continuation of the network's stream.
   Embed_Seed : constant := 2_026_1104;

   subtype Place is Positive range 1 .. Max_Seq;

   type Block is record
      W_Q   : Tensors.Matrix (D_Model, D_Model);
      W_K   : Tensors.Matrix (D_Model, D_Model);
      W_V   : Tensors.Matrix (D_Model, D_Model);
      W_O   : Tensors.Matrix (D_Model, D_Model);
      Gamma : Tensors.Vector (D_Model);
      Beta  : Tensors.Vector (D_Model);
   end record;

   type Vector_Array is array (1 .. Max_Seq) of Tensors.Vector (D_Model);

   type Vector_List is record
      Count : Natural range 0 .. Max_Seq := 0;
      Item  : Vector_Array :=
        (others =>
           (Length => D_Model, Data => (others => 0.0)));
   end record;

   type Weight_Grid is array (1 .. Max_Seq, 1 .. Max_Seq) of Float;

   procedure Initialize
     (Model : out Block;
      Seed  : Natural := Embed_Seed);

   --  Q dot K / sqrt(D_Model). Both vectors are width D_Model.
   function Scaled_Dot (Left, Right : Tensors.Vector) return Float
     with Pre => Left.Length = D_Model and then Right.Length = D_Model;

   procedure Forward
     (Model   : Block;
      X       : Vector_List;
      Weights : out Weight_Grid;
      Y       : out Vector_List)
     with Post => Y.Count = X.Count;

   function Token_Vector (Id : BPE.Token_Id) return Tensors.Vector
     with Post => Token_Vector'Result.Length = D_Model;

   function Position_Vector (Index : Place) return Tensors.Vector
     with Post => Position_Vector'Result.Length = D_Model;

   --  Token embedding plus the embedding of this place.
   function Embed
     (Id : BPE.Token_Id; Index : Place) return Tensors.Vector
     with Post => Embed'Result.Length = D_Model;

   --  Looks up Embed for the first Max_Seq ids, then Forward on the
   --  seeded block. Used is how many positions were attended.
   procedure Forward_Tokens
     (Tokens  : BPE.Token_List;
      Weights : out Weight_Grid;
      Used    : out Natural)
     with Post => Used <= Max_Seq and then Used <= Tokens.Count;

end AI_Amplifier.Attention;
