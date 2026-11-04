--  Fixed length-3 Leaky ReLU for the live page.
--
--  Plain Ada. Leaky_ReLU in the parent is a Gold proof of the
--  component rule. This wrapper is not a proof target. JavaScript
--  writes three numbers, calls Run, and reads three numbers back.
--  The call uses Negative_Slope. An index outside 1 .. 3 is ignored
--  on the way in and reads as 0.0 on the way out. Slope on the page
--  is the parent constant, so the caption and the kernel are the
--  same number.
package AI_Amplifier.Tensors.Leaky_Demo
  with SPARK_Mode => Off
is

   procedure Set_Input (Index : Integer; Value : Float)
     with Export, Convention => C, External_Name => "aa_lrelu_set";

   function Get_Input (Index : Integer) return Float
     with Export, Convention => C, External_Name => "aa_lrelu_in";

   procedure Run
     with Export, Convention => C, External_Name => "aa_lrelu_run";

   function Output (Index : Integer) return Float
     with Export, Convention => C, External_Name => "aa_lrelu_out";

   function Slope return Float
     with Export, Convention => C, External_Name => "aa_lrelu_slope";

end AI_Amplifier.Tensors.Leaky_Demo;
