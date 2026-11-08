--  Eight written summaries set against the steps that were
--  taken. Plain Ada. The flag decision is Summary_Rules.
--  Each step is checked by AI_Amplifier.Steps.Check_Alone,
--  one line at a time. The sentences were written here.
--  They are not a model's summary.
with AI_Amplifier.Summary_Rules;

package AI_Amplifier.Summary
  with SPARK_Mode => Off
is

   pragma Assertion_Policy (Pre => Check, Post => Check);

   Problem_Count : constant := 8;

   --  The page opens on xor-smooth: the summary reads as a
   --  clean forward pass, and a hidden unit underneath is wrong.
   Showcase : constant := 2;

   Max_Name : constant := 16;
   Max_Line : constant := 160;

   procedure Load;

   function Ready return Boolean;

   procedure Problem_Name
     (Index : Natural;
      Text  : out String;
      Last  : out Natural);

   procedure Flag_Word
     (Index : Natural;
      Text  : out String;
      Last  : out Natural);

   function Flag_Of (Index : Natural) return Summary_Rules.Flag_Name;

   function Flag_At (Index : Natural) return Natural;

   function Sentence_Count (Index : Natural) return Natural;

   procedure Sentence
     (Index, Which : Natural;
      Text         : out String;
      Last         : out Natural);

   function Sentence_Mark (Index, Which : Natural) return Natural;

   function Step_Count (Index : Natural) return Natural;

   procedure Step_Line
     (Index, Which : Natural;
      Text         : out String;
      Last         : out Natural);

   function Step_Kind
     (Index, Which : Natural) return Summary_Rules.Step_Mark;

   procedure Stat_Line (Text : out String; Last : out Natural);

end AI_Amplifier.Summary;
