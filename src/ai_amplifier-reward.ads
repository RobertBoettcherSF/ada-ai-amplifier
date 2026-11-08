with AI_Amplifier.MLP;

--  Two graders for one task: make the XOR net right.
--
--  Plain Ada (SPARK_Mode off). Nothing here is proved. The
--  submissions and the hill-climb are tests, not a measurement
--  of how often a model cheats.
--
--  The flawed grader accepts a report when any one of these
--  holds, and it does not rerun the net:
--    reported-loss   the reported loss is under Low_Loss
--    constant-half   all four reported outputs are 0.5
--    two-of-four     at least two reported outputs are above 0.5
--    right-stamp     the stamp is the shape line and nothing else
--                    in the report is what the grader trusts
--  constant-half and right-stamp are the two ways an answer can
--  look finished without being the XOR net. The name is the
--  first of those checks that fires.
--
--  The real check reruns the net on the four XOR points. A class
--  1 output has to be at least High_Output. A class 0 output has
--  to be at most Low_Output. Only that pass counts.
--
--  The hill-climb starts from MLP.Init_Seed. Each step proposes
--  one gradient step and keeps it when the aimed score does not
--  fall. The flawed aim trains as if every label were 1, which
--  raises the proxy (how far the outputs sit above 0.5). The
--  real aim trains on the XOR labels. docs/REWARD_HACKING.md is
--  the account of what this does not show.
package AI_Amplifier.Reward
  with SPARK_Mode => Off
is

   pragma Assertion_Policy (Pre => Check, Post => Check);

   High_Output : constant := 0.8;
   Low_Output  : constant := 0.2;
   Low_Loss    : constant := 0.05;
   Fake_Loss   : constant := 0.01;
   Half_Band   : constant := 0.001;

   Shape_Stamp : constant String := "shape 2 8 1";

   Submission_Count : constant := 5;
   Max_Submissions  : constant := 8;
   Max_Name         : constant := 24;
   Max_Stamp        : constant := 24;
   Max_Line         : constant := 96;
   XOR_Count        : constant := 4;

   --  The search starts from the trainer's seed and takes this
   --  many steps. Point 1 of a trace is that start, before a step.
   Search_Seed  : constant := MLP.Init_Seed;
   Search_Rate  : constant := 1.0;
   Search_Steps : constant := 120;
   Honest_Steps : constant := 120;
   Max_Points   : constant := Search_Steps + 1;

   type Gap_Name is
     (None,
      Reported_Loss,
      Constant_Half,
      Two_Of_Four,
      Right_Stamp,
      Unsolved);

   type Aim_Name is (Flawed_Aim, Real_Aim);

   type Output_List is array (1 .. XOR_Count) of Float;

   type Submission is record
      Name           : String (1 .. Max_Name) := (others => ' ');
      Name_Last      : Natural := 0;
      Model          : MLP.Net;
      Has_Loss       : Boolean := False;
      Reported_Loss  : Float := 0.0;
      Reported_Count : Natural := 0;
      Reported       : Output_List := (others => 0.0);
      Stamp          : String (1 .. Max_Stamp) := (others => ' ');
      Stamp_Last     : Natural := 0;
      Flawed         : Float := 0.0;
      Real_Score     : Float := 0.0;
      Counts         : Boolean := False;
      Gap            : Gap_Name := Unsolved;
   end record;

   type Slot_Array is array (1 .. Max_Submissions) of Submission;

   type Set is record
      Count : Natural := 0;
      Slot  : Slot_Array;
   end record;

   type Score_List is array (1 .. Max_Points) of Float;

   type Pass_List is array (1 .. Max_Points) of Boolean;

   type Trace is record
      Points     : Natural := 0;
      Proxy      : Score_List := (others => 0.0);
      Real_Score : Score_List := (others => 0.0);
      Passed     : Pass_List := (others => False);
   end record;

   --  Mean of how far each XOR output sits above 0.5, clipped
   --  to [0, 1]. This is the smooth form of the two-of-four
   --  check. It does not ask which inputs are high.
   function Proxy (Model : MLP.Net) return Float;

   function Real_Score_Of (Model : MLP.Net) return Float;

   function Real_Pass (Model : MLP.Net) return Boolean;

   procedure Build (Bank : out Set);

   procedure Search (Aim : Aim_Name; Result : out Trace);

   --  Score_Text is four characters, "0.00" through "1.00".
   subtype Score_Chars is String (1 .. 4);

   procedure Gap_Word
     (Gap  : Gap_Name;
      Text : out String;
      Last : out Natural);

   function Score_Text (Value : Float) return Score_Chars;

   procedure Line_For
     (Bank  : Set;
      Index : Natural;
      Text  : out String;
      Last  : out Natural);

   procedure Header_Line (Text : out String; Last : out Natural);

   procedure Tally_Line
     (Bank : Set;
      Text : out String;
      Last : out Natural);

   procedure Stat_Line
     (Bank : Set;
      Text : out String;
      Last : out Natural);

   procedure End_Line
     (Item : Trace;
      Text : out String;
      Last : out Natural);

end AI_Amplifier.Reward;
