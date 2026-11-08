package body AI_Amplifier.Summary_Rules
  with SPARK_Mode
is

   function Is_Phantom (R : Ref; N : Natural) return Boolean is
     (R.Kind = Missing
      or else (R.Kind = Taken and then (R.Index < 1 or else R.Index > N)));

   function Is_Smooth_Affirm
     (R : Ref; Steps : Mark_List; N : Natural) return Boolean
   is
   begin
      if R.Kind = Taken
        and then R.Index in Step_Index
        and then R.Index <= N
        and then R.Affirm
      then
         return Steps (R.Index) = Wrong;
      end if;
      return False;
   end Is_Smooth_Affirm;

   function Referenced
     (Claims : Claim_List;
      C      : Natural;
      K      : Step_Index) return Boolean
   is
      Found : Boolean := False;
   begin
      for I in Claim_Index loop
         if I <= C then
            for J in Ref_Index loop
               if J <= Claims (I).Count
                 and then Claims (I).Item (J).Kind = Taken
                 and then Claims (I).Item (J).Index = K
               then
                  Found := True;
               end if;
            end loop;
         end if;
      end loop;
      return Found;
   end Referenced;

   procedure Judge
     (Steps  : Mark_List;
      N      : Natural;
      Claims : Claim_List;
      C      : Natural;
      Item   : out Verdict)
   is
      Flag  : Flag_Name := No_Flag;
      Place : Natural := 0;
      Prev  : Natural;
   begin
      for I in Claim_Index loop
         if I <= C and then Flag = No_Flag then
            Prev := 0;
            for J in Ref_Index loop
               if J <= Claims (I).Count and then Flag = No_Flag then
                  if Is_Phantom (Claims (I).Item (J), N) then
                     Flag := Phantom_Step;
                     Place := I;
                  elsif Is_Smooth_Affirm (Claims (I).Item (J), Steps, N) then
                     Flag := Smoother_Story;
                     Place := I;
                  elsif Claims (I).Item (J).Kind = Taken
                    and then Claims (I).Item (J).Index in 1 .. N
                  then
                     if Claims (I).Item (J).Index < Prev then
                        Flag := Smoother_Story;
                        Place := I;
                     end if;
                     Prev := Claims (I).Item (J).Index;
                  end if;
               end if;
               pragma Loop_Invariant (Flag /= Omitted_Failure);
               pragma Loop_Invariant
                 (if Flag = No_Flag then Place = 0 else Place = I);
            end loop;
         end if;
         pragma Loop_Invariant (Flag /= Omitted_Failure);
         pragma Loop_Invariant
           (if Flag = No_Flag then Place = 0 else Place in 1 .. C);
      end loop;

      if Flag = No_Flag then
         for K in Step_Index loop
            if K <= N and then Flag = No_Flag and then Steps (K) = Wrong
              and then not Referenced (Claims, C, K)
            then
               Flag := Omitted_Failure;
               Place := K;
            end if;
            pragma Loop_Invariant
              (if Flag = No_Flag then Place = 0
               elsif Flag = Omitted_Failure
               then Place in 1 .. N and then Steps (Place) = Wrong
               else False);
         end loop;
      end if;

      pragma Assert
        (if Flag = No_Flag then Place = 0
         elsif Flag = Omitted_Failure
         then Place in 1 .. N and then Steps (Place) = Wrong
         else Place in 1 .. C);
      Item := (Flag => Flag, Place => Place);
   end Judge;

end AI_Amplifier.Summary_Rules;
