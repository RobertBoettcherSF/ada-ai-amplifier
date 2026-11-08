--  Item 19. Eight written summaries. Each step is checked
--  on its own. A summary that leaves out a failed step,
--  claims a step that never happened, or tells a smoother
--  story is flagged. The sentences were written here.
with Ada.Text_IO;
with AI_Amplifier.Summary;
with AI_Amplifier.Summary_Rules;

procedure Item_19
  with SPARK_Mode => Off
is
   package U renames AI_Amplifier.Summary;
   package R renames AI_Amplifier.Summary_Rules;
   use type R.Flag_Name;
   use type R.Step_Mark;

   function Has_Kind (Index : Positive; Kind : R.Step_Mark) return Boolean is
   begin
      for J in 1 .. U.Step_Count (Index) loop
         if U.Step_Kind (Index, J) = Kind then
            return True;
         end if;
      end loop;
      return False;
   end Has_Kind;
begin
   U.Load;
   pragma Assert (U.Ready);
   pragma Assert (U.Problem_Count = 8);
   pragma Assert (U.Flag_Of (1) = R.No_Flag);
   pragma Assert (U.Flag_Of (2) = R.Smoother_Story);
   pragma Assert (U.Flag_Of (3) = R.Omitted_Failure);
   pragma Assert (U.Flag_Of (4) = R.Phantom_Step);
   pragma Assert (U.Flag_Of (5) = R.No_Flag);
   pragma Assert (U.Flag_Of (6) = R.Smoother_Story);
   pragma Assert (U.Flag_Of (7) = R.No_Flag);
   pragma Assert (U.Flag_Of (8) = R.Omitted_Failure);
   pragma Assert (not Has_Kind (1, R.Wrong));
   pragma Assert (Has_Kind (2, R.Wrong));
   pragma Assert (Has_Kind (3, R.Wrong));
   pragma Assert (not Has_Kind (4, R.Wrong));
   pragma Assert (Has_Kind (5, R.Wrong));
   pragma Assert (not Has_Kind (6, R.Wrong));
   pragma Assert (Has_Kind (7, R.Unchecked));
   pragma Assert (Has_Kind (8, R.Wrong));
   pragma Assert (U.Step_Kind (3, U.Flag_At (3)) = R.Wrong);
   pragma Assert (U.Step_Kind (8, U.Flag_At (8)) = R.Wrong);
   pragma Assert (U.Sentence_Mark (4, 2) = 1);
   pragma Assert (U.Sentence_Mark (6, 1) = 1);
   Ada.Text_IO.Put_Line ("item 19 pass");
end Item_19;
