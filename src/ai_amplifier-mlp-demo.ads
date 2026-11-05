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

   --  The weights of the same net, as numbers the page can edit.
   --  A bad index reads as 0. A value that is not finite, or that
   --  sits outside [-Weight_Limit, Weight_Limit], is refused and the
   --  weight stays. Set_Weight returns 0 when it stored the value,
   --  1 when it refused the value, and 2 when the index is not a
   --  weight. Names run hidden unit by hidden unit: h1.x1, h1.x2,
   --  h1.b, then h2.x1, and so on through h8.b, then y.h1 through
   --  y.h8, then y.b. An index outside 1 .. Count has an empty name.
   function Weight_Limit return Float
     with Export, Convention => C, External_Name => "aa_w_limit";

   function Slider_Span return Float
     with Export, Convention => C, External_Name => "aa_w_span";

   function Weight_Count return Integer
     with Export, Convention => C, External_Name => "aa_w_count";

   function Weight_At (Index : Integer) return Float
     with Export, Convention => C, External_Name => "aa_w_get";

   function Set_Weight (Index : Integer; Value : Float) return Integer
     with Export, Convention => C, External_Name => "aa_w_set";

   function Name_Length (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_w_name_len";

   function Name_Byte (Index, Pos : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_w_name_byte";

   --  Text form of the current weights. Byte indexes are 1-based.
   --  Outside 1 .. Length the byte is 0.
   function Export_Length return Integer
     with Export, Convention => C, External_Name => "aa_w_len";

   function Export_Byte (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_w_byte";

   --  The page pushes the bytes of a file, then asks Load. Load
   --  returns 0 on success, 1 for a bad shape, 2 for a bad value,
   --  and 3 for text this reader does not accept. A failure leaves
   --  the weights alone. A byte outside 0 .. 255 is ignored. Bytes
   --  past Max_Weight_Text are counted as overflow and Load returns 3.
   procedure Import_Clear
     with Export, Convention => C, External_Name => "aa_w_clear";

   procedure Import_Push (Value : Integer)
     with Export, Convention => C, External_Name => "aa_w_push";

   function Import_Load return Integer
     with Export, Convention => C, External_Name => "aa_w_load";

   --  Hand_XOR on the XOR dataset. The learning rate is kept. The
   --  step counter goes back to 0, because these weights were not
   --  trained. The previous training snapshot is kept when the page
   --  was already on XOR, so Restore_Trained can undo this.
   procedure Load_Hand
     with Export, Convention => C, External_Name => "aa_w_hand";

   --  Puts back the weights from the last training step on this
   --  dataset. If no step has run since the dataset was chosen, that
   --  is the seeded start. The learning rate is kept.
   procedure Restore_Trained
     with Export, Convention => C, External_Name => "aa_w_trained";

   --  1 flips hidden 1, 2 silences hidden 2, 3 inverts the output.
   --  Any other code is ignored. The note says what changed.
   procedure Preset (Code : Integer)
     with Export, Convention => C, External_Name => "aa_w_preset";

   function Note_Length return Integer
     with Export, Convention => C, External_Name => "aa_w_note_len";

   function Note_Byte (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_w_note_byte";

end AI_Amplifier.MLP.Demo;
