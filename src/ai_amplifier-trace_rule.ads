--  The next-step verdict used by AI_Amplifier.Traces.
--
--  SPARK. The post is the decision Decide applies to two
--  measured nets. Running the trainer is not in this unit.
--  Outputs are written through out parameters. This unit
--  does not return a slice.
package AI_Amplifier.Trace_Rule
  with SPARK_Mode
is

   Loss_Max     : constant Float := 0.05;
   Loss_Epsilon : constant Float := 0.000_1;
   Loss_Cap     : constant Float := 1.0e6;

   type Verdict_Kind is (Fixes_It, No_Better, Makes_It_Worse);

   type Reason_Kind is
     (XOR_Returned,
      XOR_Still_Missed,
      XOR_Left,
      Loss_Rose,
      Loss_Did_Not_Fall,
      Weights_Invalid);

   type Facts is record
      Weights_OK  : Boolean := False;
      Loss_Finite : Boolean := False;
      XOR_OK      : Boolean := False;
      Loss        : Float := 0.0;
   end record;

   function In_Band (Item : Facts) return Boolean is
     (if Item.Loss_Finite then Item.Loss in 0.0 .. Loss_Cap else True);

   function Solved (Item : Facts) return Boolean is
     (Item.Weights_OK
      and then Item.Loss_Finite
      and then Item.XOR_OK
      and then Item.Loss < Loss_Max)
     with Pre => In_Band (Item);

   procedure Decide
     (Before  : Facts;
      After   : Facts;
      Verdict : out Verdict_Kind;
      Reason  : out Reason_Kind)
     with Pre => In_Band (Before) and then In_Band (After),
          Post =>
            (if not After.Weights_OK then
               Reason = Weights_Invalid
               and then (if Before.Weights_OK then
                           Verdict = Makes_It_Worse
                         else
                           Verdict = No_Better)
             elsif not After.Loss_Finite then
               Verdict = Makes_It_Worse
               and then Reason = Loss_Rose
             elsif Solved (After) and then not Solved (Before) then
               Verdict = Fixes_It
               and then Reason = XOR_Returned
             elsif Before.XOR_OK and then not After.XOR_OK then
               Verdict = Makes_It_Worse
               and then Reason = XOR_Left
             elsif Before.Loss_Finite
               and then After.Loss > Before.Loss + Loss_Epsilon
             then
               Verdict = Makes_It_Worse
               and then Reason = Loss_Rose
             elsif not Solved (After) then
               Verdict = No_Better
               and then
                 (if not After.XOR_OK
                    and then Before.Loss_Finite
                    and then After.Loss + Loss_Epsilon < Before.Loss
                  then
                    Reason = XOR_Still_Missed
                  else
                    Reason = Loss_Did_Not_Fall)
             else
               Verdict = No_Better
               and then Reason = Loss_Did_Not_Fall);

end AI_Amplifier.Trace_Rule;
