--  Item 18. The checking status of items 1 through 17.
--  The labels are computed from the build logs. A tested
--  label is not a proof. A live --ask mode is not a test
--  that CI ran.
with Ada.Strings.Fixed;
with Ada.Text_IO;
with AI_Amplifier.Status;

procedure Item_18
  with SPARK_Mode => Off
is
   package S renames AI_Amplifier.Status;
   use type S.Kind;

   Expected : constant array (1 .. 17) of S.Kind :=
     (1 => S.Proved,
      2 => S.Tested,
      3 => S.Proved,
      4 => S.Tested,
      5 => S.Tested,
      6 => S.Tested,
      7 => S.Proved,
      8 => S.Tested,
      9 => S.Tested,
      10 => S.Tested,
      11 => S.Tested,
      12 => S.Tested,
      13 => S.Tested,
      14 => S.Tested,
      15 => S.Tested,
      16 => S.Tested,
      17 => S.Tested);

   function Has (Number : Positive; Piece : String) return Boolean is
      Text : constant String := S.Item_Evidence (Number);
   begin
      return Ada.Strings.Fixed.Index (Text, Piece) > 0;
   end Has;
begin
   S.Load
     ("proof/gnatprove.out",
      "obj/gen/tests.out",
      "obj/gen/specs.out",
      "obj/gen/recheck-report.txt",
      "specs");
   pragma Assert (S.Ready);
   for N in Expected'Range loop
      pragma Assert (S.Item_Label (N) = Expected (N));
   end loop;
   pragma Assert
     (S.Summary = "proved 3 of 17, tested 14, unchecked 0");
   pragma Assert (Has (1, "checks 0"));
   pragma Assert (Has (3, "419"));
   pragma Assert (Has (3, "unproved 0"));
   pragma Assert (Has (3, "not proved"));
   pragma Assert (Has (4, "mlp_test"));
   pragma Assert (S.Item_Label (4) /= S.Proved);
   pragma Assert (Has (7, "419"));
   pragma Assert (Has (7, "unproved 0"));
   pragma Assert (Has (9, "live-ask unchecked"));
   pragma Assert (Has (9, "RECURSE_LLM_KEY"));
   pragma Assert (Has (11, "live-ask unchecked"));
   pragma Assert (Has (11, "TRACES_LLM_KEY"));
   pragma Assert (Has (14, "live-ask unchecked"));
   pragma Assert (Has (14, "HARNESS_LLM_KEY"));
   pragma Assert (Has (16, "no item_16.adb"));
   pragma Assert (Has (17, "44 of 44"));
   pragma Assert (Has (17, "22 of 22"));
   pragma Assert (Has (17, "12 of 12"));
   Ada.Text_IO.Put_Line ("item 18 pass");
end Item_18;
