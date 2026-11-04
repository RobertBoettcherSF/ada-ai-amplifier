--  The live page's copy of the network.
--
--  Plain Ada, like AI_Amplifier.MLP. JavaScript picks a dataset, sets
--  the learning rate, and asks for a few steps. It then reads the loss
--  curve, the samples, and a grid of predictions, and draws those.
--  The arithmetic stays in AI_Amplifier.MLP.
--
--  This wrapper does not raise. A bad index reads as 0. A rate outside
--  (0, Rate_Max] is left unchanged. A dataset code other than 1 or 2
--  is XOR. Run_Steps does at most Step_Cap steps, so one call cannot
--  hold the page.
--
--  Reset builds the dataset and the seeded weights, then records the
--  loss before any step. The learning rate is kept across Reset, so
--  the control on the page survives a dataset change. The first Reset
--  uses Default_Rate.
package AI_Amplifier.MLP.Demo
  with SPARK_Mode => Off
is

   Step_Cap  : constant := 32;
   Grid_Side : constant := 48;
   Curve_Max : constant := 240;

   procedure Reset (Kind : Integer)
     with Export, Convention => C, External_Name => "aa_mlp_reset";

   procedure Set_Learning_Rate (Value : Float)
     with Export, Convention => C, External_Name => "aa_mlp_set_rate";

   function Learning_Rate return Float
     with Export, Convention => C, External_Name => "aa_mlp_rate";

   function Run_Steps (Steps : Integer) return Float
     with Export, Convention => C, External_Name => "aa_mlp_train";

   function Step_Count return Integer
     with Export, Convention => C, External_Name => "aa_mlp_epoch";

   function Current_Loss return Float
     with Export, Convention => C, External_Name => "aa_mlp_loss";

   function Predict_At (X, Y : Float) return Float
     with Export, Convention => C, External_Name => "aa_mlp_predict";

   function Sample_Count return Integer
     with Export, Convention => C, External_Name => "aa_mlp_count";

   function Sample_X (Index : Integer) return Float
     with Export, Convention => C, External_Name => "aa_mlp_x";

   function Sample_Y (Index : Integer) return Float
     with Export, Convention => C, External_Name => "aa_mlp_y";

   function Sample_Label (Index : Integer) return Float
     with Export, Convention => C, External_Name => "aa_mlp_label";

   function View_Low return Float
     with Export, Convention => C, External_Name => "aa_mlp_lo";

   function View_High return Float
     with Export, Convention => C, External_Name => "aa_mlp_hi";

   function Grid_N return Integer
     with Export, Convention => C, External_Name => "aa_mlp_grid_n";

   procedure Fill_Grid
     with Export, Convention => C, External_Name => "aa_mlp_fill";

   --  Prediction in [0, 1] for a cell. Row 1 is the high-Y edge.
   --  Column 1 is the low-X edge. Outside the grid reads as 0.
   function Cell (Row, Col : Integer) return Float
     with Export, Convention => C, External_Name => "aa_mlp_cell";

   function Curve_Count return Integer
     with Export, Convention => C, External_Name => "aa_mlp_curve_n";

   function Curve_At (Index : Integer) return Float
     with Export, Convention => C, External_Name => "aa_mlp_curve";

   --  0 XOR, 1 two circles, 2 two spirals.
   function Kind_Code return Integer
     with Export, Convention => C, External_Name => "aa_mlp_kind";

end AI_Amplifier.MLP.Demo;
