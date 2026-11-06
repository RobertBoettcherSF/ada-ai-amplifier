--  A yardstick for the existing XOR trainer.
--
--  Plain Ada (SPARK_Mode off). Nothing here is proved. The network,
--  the loss, and the four answers are the ones AI_Amplifier.MLP and
--  bin/mlp_test already check: mean loss under 0.05, class 1 at least
--  0.8, class 0 at most 0.2, seed Init_Seed, rate 1, the four XOR
--  points.
--
--  The baseline is a loop of Train for one step. That is the call the
--  XOR test makes. Train for one step always computes the mean loss
--  again after the update, and Step builds temporary matrices. The
--  faster variant does the same gradient update, writes each weight
--  in place, and does not recompute that intermediate loss. Both run
--  Published_Steps updates from the seed, Repeated times, so the clock
--  has a duration to read. The step count of one solve is the
--  yardstick. The repeats are part of the timed work for both.
--
--  A run counts only when three things hold after the clock stops.
--  The loss and the four answers pass the checks above. The weights
--  match a public Train of Published_Steps (the reference is built
--  before the clock and is not the timed result). The gradient steps
--  were taken inside the clock, and there are Repeats * Published_Steps
--  of them. Otherwise the timing does not count.
--
--  Three failures are deliberate, so a short time cannot sneak through.
--  Moved_Outside trains before the clock and leaves the timed section
--  empty. Skipped stops early. Easier trains the same number of steps
--  on one XOR point instead of four. Copying the reference into the
--  timed section does not count either: the step counter only moves
--  when Train or the in-place update runs.
--
--  This unit does not read a clock. The wasm runtime has none, and the
--  module has no imports. The native test times Execute with process
--  CPU time and passes the microseconds in. The page reads the host
--  wall clock around Execute and passes the two readings in. Finish
--  subtracts those readings. The arithmetic of the verdict stays here.
package AI_Amplifier.MLP.Speed
  with SPARK_Mode => Off
is

   pragma Assertion_Policy (Pre => Check, Post => Check);

   --  The same bar as the XOR loop in bin/mlp_test.
   Loss_Max : constant := 0.05;
   High_Min : constant := 0.8;
   Low_Max  : constant := 0.2;

   --  The rate the native XOR test uses. Not the page's 0.5.
   Rate : constant := 1.0;

   --  First step count at which Train from Init_Seed, at Rate, passes
   --  the bar above. bin/mlp_test checks this against a fresh loop.
   Published_Steps : constant := 95;

   --  How many full solves Execute runs inside one clock. Both
   --  variants use this. It is not a second yardstick.
   Repeats : constant := 8;

   --  Recorded when this item was added. Native is process CPU time
   --  around Execute. Wasm is host wall time around the same call.
   --  A later machine will not match them. They are a record, not a
   --  pass mark, and they are not comparable to each other.
   Published_Native_Us : constant := 33_044;
   Published_Wasm_Us   : constant := 10_162;

   --  Codes for Prepare. Anything else is refused.
   --  1 baseline, 2 faster variant, 3 work outside the clock,
   --  4 too few steps, 5 one-point batch.
   procedure Prepare (Code : Integer)
     with Export, Convention => C, External_Name => "aa_speed_prepare";

   --  The timed section. The caller starts a clock before this returns
   --  to the statement after the call, and stops it before Finish.
   procedure Execute
     with Export, Convention => C, External_Name => "aa_speed_execute";

   --  Host wall-clock readings, in milliseconds, taken immediately
   --  before and after Execute. The subtraction is done here.
   procedure Finish (Start_Ms : Float; End_Ms : Float)
     with Export, Convention => C, External_Name => "aa_speed_finish";

   --  Native process CPU time for the Execute that just returned.
   --  Not exported. The wasm module has no CPU clock.
   procedure Note_Cpu_Microseconds (Elapsed : Integer);

   function Step_Count return Integer
     with Export, Convention => C, External_Name => "aa_speed_steps";

   function Repeat_Count return Integer
     with Export, Convention => C, External_Name => "aa_speed_repeats";

   function Microseconds return Integer
     with Export, Convention => C, External_Name => "aa_speed_us";

   function Loss return Float
     with Export, Convention => C, External_Name => "aa_speed_loss";

   --  Dataset order: (0,0), (0,1), (1,0), (1,1). Outside 1 .. 4 is 0.
   function Answer (Index : Integer) return Float
     with Export, Convention => C, External_Name => "aa_speed_answer";

   --  1 if the time counts, 0 otherwise.
   function Counted return Integer
     with Export, Convention => C, External_Name => "aa_speed_counted";

   --  0 not run, 1 counted, 2 answers, 3 outside, 4 skipped,
   --  5 easier problem, 6 clock did not advance, 7 not a trainer.
   function Reason_Code return Integer
     with Export, Convention => C, External_Name => "aa_speed_reason";

   function Published_Step_Count return Integer
     with Export, Convention => C,
          External_Name => "aa_speed_published_steps";

   function Published_Native return Integer
     with Export, Convention => C,
          External_Name => "aa_speed_published_native_us";

   function Published_Wasm return Integer
     with Export, Convention => C,
          External_Name => "aa_speed_published_wasm_us";

   function Report_Length return Integer
     with Export, Convention => C, External_Name => "aa_speed_len";

   --  1-based. Outside 1 .. Length returns 0.
   function Report_Byte (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "aa_speed_byte";

   --  Writes the published yardstick into the report buffer.
   --  Does not train and does not clear a clock.
   procedure Describe
     with Export, Convention => C, External_Name => "aa_speed_describe";

end AI_Amplifier.MLP.Speed;
