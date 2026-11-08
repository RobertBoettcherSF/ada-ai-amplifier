--  Item 15. Twelve solutions. Eleven answers pass. Four
--  solutions pass every step. The planted flaws fail at
--  the step steps_test and the page name. Tolerance is
--  0.000_05.
with Ada.Text_IO;
with AI_Amplifier.Steps;

procedure Item_15
  with SPARK_Mode => Off
is
   package S renames AI_Amplifier.Steps;
   use type S.Mark;
   use type S.Rule_Name;

   procedure Expect
     (Index   : Natural;
      Name    : String;
      Answer  : S.Mark;
      Steps   : S.Mark;
      Bad_At  : Natural;
      Rule    : S.Rule_Name)
   is
      Item : S.Report;
   begin
      S.Grade_Built_In (Index, Item);
      pragma Assert (Item.Name_Last = Name'Length);
      pragma Assert (Item.Name (1 .. Item.Name_Last) = Name);
      pragma Assert (Item.Answer_Grade = Answer);
      pragma Assert (Item.Step_Grade = Steps);
      pragma Assert (Item.Bad_At = Bad_At);
      pragma Assert (Item.Rule = Rule);
   end Expect;

   Ans   : Natural := 0;
   Steps : Natural := 0;
   Item  : S.Report;
begin
   pragma Assert (S.Solution_Count = 12);
   pragma Assert (S.Tol = 0.000_05);
   for I in 1 .. S.Solution_Count loop
      S.Grade_Built_In (I, Item);
      if Item.Answer_Grade = S.Pass then
         Ans := Ans + 1;
      end if;
      if Item.Step_Grade = S.Pass then
         Steps := Steps + 1;
      end if;
   end loop;
   pragma Assert (Ans = 11);
   pragma Assert (Steps = 4);
   Expect (1, "xor-00-right", S.Pass, S.Pass, 0, S.None);
   Expect (2, "xor-10-cancel", S.Pass, S.Fail, 2, S.Bad_Value);
   Expect (3, "xor-11-skip", S.Pass, S.Fail, 2, S.Skipped_Step);
   Expect (4, "xor-00-guess", S.Pass, S.Fail, 1, S.Guessed_First);
   Expect (5, "xor-01-wrong", S.Fail, S.Fail, 8, S.Wrong_Answer);
   Expect (6, "train-right", S.Pass, S.Pass, 0, S.None);
   Expect (7, "train-cancel", S.Pass, S.Fail, 6, S.Bad_Value);
   Expect (8, "fib-6-right", S.Pass, S.Pass, 0, S.None);
   Expect (9, "fib-5-cancel", S.Pass, S.Fail, 2, S.Bad_Arithmetic);
   Expect (10, "fib-4-skip", S.Pass, S.Fail, 2, S.Not_Toward_Base);
   Expect (11, "sum-right", S.Pass, S.Pass, 0, S.None);
   Expect (12, "sum-guess", S.Pass, S.Fail, 1, S.Guessed_First);
   Ada.Text_IO.Put_Line ("item 15 pass");
end Item_15;
