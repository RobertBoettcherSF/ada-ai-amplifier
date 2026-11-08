--  Item 18. The checking status of items 1 through 19.
--  The labels are computed from the build logs. A tested
--  label is not a proof. Item 18 is proved for the label
--  rule only. Reading the logs is still plain Ada. A live
--  --ask mode is tested against a stand-in model.
--  That run does not call a real model. Real-model
--  behaviour stays unchecked, and it does not change
--  the proved label.
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
      9 => S.Proved,
      10 => S.Tested,
      11 => S.Proved,
      12 => S.Proved,
      13 => S.Proved,
      14 => S.Tested,
      15 => S.Proved,
      16 => S.Proved,
      17 => S.Proved);

   function Has (Number : Positive; Piece : String) return Boolean is
      Text : constant String := S.Item_Evidence (Number);
   begin
      return Ada.Strings.Fixed.Index (Text, Piece) > 0;
   end Has;
begin
   S.Load
     ("proof",
      "obj/gen/tests.out",
      "obj/gen/specs.out",
      "obj/gen/recheck-report.txt",
      "specs");
   pragma Assert (S.Ready);
   for N in Expected'Range loop
      pragma Assert (S.Item_Label (N) = Expected (N));
   end loop;
   pragma Assert
     (S.Summary = "proved 12 of 19, tested 7, unchecked 0");
   pragma Assert (S.Item_Label (18) = S.Proved);
   pragma Assert (Has (18, "proof/item_18.out"));
   pragma Assert (Has (18, "unproved 0"));
   pragma Assert (Has (18, "ai_amplifier-label_rule"));
   pragma Assert (Has (18, "proved for the label rule"));
   pragma Assert (Has (18, "not in this run: ai_amplifier-status"));
   pragma Assert (Has (18, "not proved:"));
   pragma Assert (Has (13, "proved for the accept/reject gate"));
   pragma Assert (Has (13, "not proved:"));
   pragma Assert (Has (15, "proved for the step-grade rule"));
   pragma Assert (Has (15, "not proved:"));
   pragma Assert (Has (16, "proved for the lock-compare rule"));
   pragma Assert (Has (16, "not proved:"));
   pragma Assert (Has (17, "proved for the agreement count"));
   pragma Assert (Has (17, "not proved:"));
   pragma Assert (Has (1, "proof/item_01.out"));
   pragma Assert (Has (1, "unproved 0"));
   pragma Assert (Has (1, "ai_amplifier-version"));
   pragma Assert (Has (3, "proof/item_03.out"));
   pragma Assert (Has (3, "unproved 0"));
   pragma Assert (Has (3, "not in this run"));
   pragma Assert (Has (4, "mlp_test"));
   pragma Assert (S.Item_Label (4) /= S.Proved);
   pragma Assert (Has (7, "proof/item_07.out"));
   pragma Assert (Has (7, "ai_amplifier-tensors"));
   pragma Assert (Has (7, "unproved 0"));
   pragma Assert (Has (9, "tested against a stand-in model"));
   pragma Assert (Has (9, "RECURSE_LLM_KEY"));
   pragma Assert (Has (9, "no real model is called"));
   pragma Assert (Has (9, "real-model behaviour stays unchecked"));
   pragma Assert (not Has (9, "live-ask unchecked"));
   pragma Assert (Has (9, "ai_amplifier-chain_rule"));
   pragma Assert (S.Item_Label (9) = S.Proved);
   pragma Assert (Has (11, "tested against a stand-in model"));
   pragma Assert (Has (11, "TRACES_LLM_KEY"));
   pragma Assert (Has (11, "no real model is called"));
   pragma Assert (Has (11, "real-model behaviour stays unchecked"));
   pragma Assert (not Has (11, "live-ask unchecked"));
   pragma Assert (S.Item_Label (11) = S.Proved);
   pragma Assert (Has (14, "tested against a stand-in model"));
   pragma Assert (Has (14, "HARNESS_LLM_KEY"));
   pragma Assert (Has (14, "no real model is called"));
   pragma Assert (Has (14, "real-model behaviour stays unchecked"));
   pragma Assert (not Has (14, "live-ask unchecked"));
   pragma Assert (S.Item_Label (14) = S.Tested);
   pragma Assert (Has (16, "spec item_16"));
   pragma Assert (Has (16, "not proved:"));
   pragma Assert (S.Item_Label (19) = S.Proved);
   pragma Assert (Has (19, "proof/item_19.out"));
   pragma Assert (Has (19, "unproved 0"));
   pragma Assert (Has (19, "ai_amplifier-summary_rules"));
   pragma Assert (Has (17, "44 of 44"));
   pragma Assert (Has (17, "22 of 22"));
   pragma Assert (Has (17, "12 of 12"));
   Ada.Text_IO.Put_Line ("item 18 pass");
end Item_18;
