--  Splash picture for the live page.
--
--  Plain Ada on purpose (SPARK_Mode off). AI_Amplifier.Version stays in
--  SPARK; this unit is a drawing, not a proof. It does not train anything.
--  The picture is a small network: points move along the edges, and more
--  points travel in from the border, through a node, and on to the output.
--  JavaScript only reads these numbers and plots them.
--
--  Coordinates are 0 .. 1000. An index or a field outside the ranges
--  below yields 0, the same out-of-range rule as Version_Byte.
--
--  Kind 0  node   index 1 .. 6
--    field 0 x, 1 y, 2 pulse (0 .. 255)
--  Kind 1  edge   index 1 .. 8
--    field 0 x1, 1 y1, 2 x2, 3 y2, 4 weight (0 .. 255)
--  Kind 2  point  index 1 .. 56
--    field 0 x, 1 y, 2 brightness (0 .. 255), 3 size (1 .. 3)
--    1 .. 32 are beads on the edges (head, trail, head, trail)
--    33 .. 56 are the points flowing in from the border
package AI_Amplifier.Splash
  with SPARK_Mode => Off
is

   procedure Reset
     with Export, Convention => C, External_Name => "aa_splash_reset";

   procedure Tick
     with Export, Convention => C, External_Name => "aa_splash_tick";

   function Frame return Integer
     with Export, Convention => C, External_Name => "aa_step";

   function Count (Kind : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_count";

   function Get (Kind, Index, Field : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_get";

end AI_Amplifier.Splash;
