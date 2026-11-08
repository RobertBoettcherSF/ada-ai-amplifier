--  Item 9. The four recorded chains, and F(20) = 6765
--  by the same Check_Step the checker uses. recurse_test
--  locks these stop positions and this answer.
with Ada.Text_IO;
with AI_Amplifier.Recurse;

procedure Item_09
  with SPARK_Mode => Off
is
   package R renames AI_Amplifier.Recurse;
   use type R.Check_Name;

   procedure Expect
     (Index    : Natural;
      Kind     : R.Check_Name;
      Place    : Natural;
      Steps    : Natural;
      Answer   : Natural)
   is
      Result : R.Replay;
      OK     : Boolean;
   begin
      R.Replay_Recorded (Index, Result, OK);
      pragma Assert (OK);
      pragma Assert (Result.Stop = Kind);
      pragma Assert (Result.Stop_At = Place);
      pragma Assert (Result.Accepted = Steps);
      pragma Assert (Result.Answer = Answer);
   end Expect;

   Prev : R.State;
   Next : R.State;
   Kind : R.Check_Name;
   OK   : Boolean;
begin
   pragma Assert (R.Max_Index = 20);
   pragma Assert (R.Max_Value = 20_000);
   pragma Assert (R.Max_Chain = 4_000);
   pragma Assert (R.Recorded = 4);
   Expect (1, R.Reached_Base, 7, 6, 8);
   Expect (2, R.Bad_Arithmetic, 4, 2, 0);
   Expect (3, R.Not_Toward_Base, 2, 0, 0);
   Expect (4, R.Bad_Parse, 3, 1, 0);
   R.Make_Opening (20, Prev, OK);
   pragma Assert (OK);
   pragma Assert (Prev.Fib_Index = 20);
   pragma Assert (Prev.Minus_One = 0);
   pragma Assert (Prev.Curr_Value = 1);
   for Step in 1 .. 20 loop
      Next.Fib_Index := Prev.Fib_Index - 1;
      Next.Minus_One := Prev.Curr_Value;
      Next.Curr_Value := Prev.Minus_One + Prev.Curr_Value;
      R.Check_Step (Prev, Next, Kind);
      Prev := Next;
   end loop;
   pragma Assert (Kind = R.Reached_Base);
   pragma Assert (Prev.Minus_One = 6765);
   Ada.Text_IO.Put_Line ("item 09 pass");
end Item_09;
