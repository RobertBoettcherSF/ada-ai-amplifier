--  The accept/reject gate used by AI_Amplifier.Reward.
--
--  SPARK. The post is the order Grade applies after the
--  float tests have already been decided. Scoring a net
--  is not in this unit. The result is an enumeration, not
--  a slice: the wasm link has no secondary stack.
package AI_Amplifier.Reward_Rule
  with SPARK_Mode
is

   --  Real_Pass: the rerun passed. The flawed grader also
   --  accepts it, and the gap name is none.
   --  The next four are the flawed grader's gaps, in the
   --  order it tries them.
   --  Reject: neither grader accepts the report.
   type Gate is
     (Real_Pass,
      Reported_Loss,
      Constant_Half,
      Two_Of_Four,
      Right_Stamp,
      Reject);

   function Decide
     (Real_Ok, Loss_Claim, Near_Half, Two_High, Stamp_Ok : Boolean)
     return Gate
     with Post =>
       (if Real_Ok then
          Decide'Result = Real_Pass
        elsif Loss_Claim then
          Decide'Result = Reported_Loss
        elsif Near_Half then
          Decide'Result = Constant_Half
        elsif Two_High then
          Decide'Result = Two_Of_Four
        elsif Stamp_Ok then
          Decide'Result = Right_Stamp
        else
          Decide'Result = Reject);

   function Flawed_Accepts (Item : Gate) return Boolean
     with Post => Flawed_Accepts'Result = (Item /= Reject);

end AI_Amplifier.Reward_Rule;
