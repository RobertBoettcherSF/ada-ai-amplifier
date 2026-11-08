package body AI_Amplifier.Reward_Rule
  with SPARK_Mode
is

   function Decide
     (Real_Ok, Loss_Claim, Near_Half, Two_High, Stamp_Ok : Boolean)
     return Gate
   is
   begin
      if Real_Ok then
         return Real_Pass;
      elsif Loss_Claim then
         return Reported_Loss;
      elsif Near_Half then
         return Constant_Half;
      elsif Two_High then
         return Two_Of_Four;
      elsif Stamp_Ok then
         return Right_Stamp;
      else
         return Reject;
      end if;
   end Decide;

   function Flawed_Accepts (Item : Gate) return Boolean is
   begin
      if Item /= Reject then
         return True;
      end if;
      return False;
   end Flawed_Accepts;

end AI_Amplifier.Reward_Rule;
