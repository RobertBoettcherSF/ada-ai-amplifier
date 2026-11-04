--  Fixed 3 by 3 panel for the live page.
--
--  Plain Ada, like AI_Amplifier.Tensors. JavaScript writes the nine
--  matrix entries and the three vector entries, calls Run, and reads
--  the product and the softmax back. The arithmetic is Mat_Vec and
--  Softmax in the parent. This wrapper does not raise: an index outside
--  1 .. 3 is ignored on the way in and reads as 0.0 on the way out.
--  The shapes passed to the kernels are 3 and 3, so the shape checks
--  pass. A mismatch in the kernels themselves still raises on the
--  native runtime; this wasm runtime traps instead of propagating.
package AI_Amplifier.Tensors.Demo
  with SPARK_Mode => Off
is

   procedure Set_Matrix (Row, Col : Integer; Value : Float)
     with Export, Convention => C, External_Name => "aa_set_m";

   function Get_Matrix (Row, Col : Integer) return Float
     with Export, Convention => C, External_Name => "aa_get_m";

   procedure Set_Vector (Index : Integer; Value : Float)
     with Export, Convention => C, External_Name => "aa_set_v";

   function Get_Vector (Index : Integer) return Float
     with Export, Convention => C, External_Name => "aa_get_v";

   procedure Run
     with Export, Convention => C, External_Name => "aa_tensor_run";

   function Product (Index : Integer) return Float
     with Export, Convention => C, External_Name => "aa_product";

   function Chance (Index : Integer) return Float
     with Export, Convention => C, External_Name => "aa_softmax";

end AI_Amplifier.Tensors.Demo;
