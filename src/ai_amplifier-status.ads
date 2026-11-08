--  Checking status for items 1 through 19.
--  The summary counts every one of those nineteen.
--
--  Plain Ada (SPARK_Mode off). Reading the logs is not
--  proved. The label itself is AI_Amplifier.Label_Rule:
--  own log, a positive check count, and unproved 0.
--  The label is computed from the build logs: one GNATprove
--  report per item, the test programs' output, the locked
--  specs, and the item-17 agreement counts. Proved is
--  printed only when that item's own report exists and its
--  summary unproved count is 0. A returned string uses the
--  secondary stack. This unit is not linked into the wasm
--  module. That link has no secondary stack.
--  docs/CHECKING_STATUS.md is the account of what a label
--  does not show.
package AI_Amplifier.Status
  with SPARK_Mode => Off
is

   pragma Assertion_Policy (Pre => Check, Post => Check);

   type Kind is (Proved, Tested, Unchecked);

   --  Paths are relative to the repository root, which is
   --  the working directory of the tests and of item_18.
   --  Prove_Dir holds item_NN.out, one gnatprove run per item.
   procedure Load
     (Prove_Dir    : String;
      Tests_Path   : String;
      Specs_Path   : String;
      Recheck_Path : String;
      Spec_Dir     : String);

   function Ready return Boolean;

   function Item_Label (Number : Positive) return Kind;

   function Item_Evidence (Number : Positive) return String;

   --  "proved X of 19, tested Y, unchecked Z"
   function Summary return String;

   procedure Put_Report;

end AI_Amplifier.Status;
