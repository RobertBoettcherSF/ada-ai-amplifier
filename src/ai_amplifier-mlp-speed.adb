package body AI_Amplifier.MLP.Speed
  with SPARK_Mode => Off
is

   pragma Assertion_Policy (Pre => Check, Post => Check);

   type Kind_Name is
     (Baseline, Faster, Moved_Outside, Skipped, Easier, Unknown);

   type Clock_Name is (Native_Cpu, Wasm_Wall);

   type Reason_Name is
     (Not_Run,
      Did_Count,
      Bad_Answers,
      Work_Outside,
      Too_Few_Steps,
      Easier_Problem,
      Clock_Still,
      Not_A_Trainer);

   Report_Max : constant := 1200;

   Kind      : Kind_Name := Unknown;
   Ready     : Boolean := False;
   Executing : Boolean := False;

   Sealed    : Sample_List;
   Official  : Net;
   Reference : Net;

   Real_Inside  : Natural := 0;
   Real_Outside : Natural := 0;
   Loss_Sum     : Float := 0.0;
   --  Backprop's loss is the value before the update. The checked
   --  loss is the one after the last step. This keeps the before
   --  value from being discarded.
   Before_Last  : Float := 0.0;
   Reference_Loss : Float := 0.0;

   Reason_Now : Reason_Name := Not_Run;
   Elapsed_Us : Integer := 0;
   Loss_Now   : Float := 0.0;
   Answers    : array (1 .. 4) of Float := (others => 0.0);
   Gap_Now    : Float := 0.0;
   Clock_Now  : Clock_Name := Wasm_Wall;

   Last_Baseline_Us    : Integer := 0;
   Last_Baseline_Clock : Clock_Name := Wasm_Wall;
   Have_Baseline       : Boolean := False;

   Report_Text : String (1 .. Report_Max) := (others => ' ');
   Report_Len  : Natural := 0;

   procedure Clear_Report is
   begin
      Report_Len := 0;
   end Clear_Report;

   procedure Add (S : String) is
   begin
      for C of S loop
         if Report_Len < Report_Max then
            Report_Len := Report_Len + 1;
            Report_Text (Report_Len) := C;
         end if;
      end loop;
   end Add;

   procedure Add_Int (N : Integer) is
      Digs  : array (1 .. 12) of Character := (others => '0');
      Count : Natural := 0;
      V     : Integer := N;
   begin
      if V < 0 then
         Add ("-");
         V := -V;
      end if;
      if V = 0 then
         Add ("0");
         return;
      end if;
      while V > 0 and then Count < Digs'Last loop
         Count := Count + 1;
         Digs (Count) :=
           Character'Val (Character'Pos ('0') + V mod 10);
         V := V / 10;
      end loop;
      for I in reverse 1 .. Count loop
         Add ((1 => Digs (I)));
      end loop;
   end Add_Int;

   --  Non-negative X, with Places digits after the point.
   --  A value at or above 10000 prints as 9999.
   procedure Add_Dec (X : Float; Places : Positive) is
      Scale  : Long_Long_Integer := 1;
      Scaled : Long_Long_Integer;
      Whole  : Integer;
      Frac   : Integer;
      V      : Float := X;
   begin
      if V < 0.0 then
         V := 0.0;
      elsif V >= 10_000.0 then
         V := 9_999.0;
      end if;
      for I in 1 .. Places loop
         Scale := Scale * 10;
      end loop;
      Scaled := Long_Long_Integer (V * Float (Scale) + 0.5);
      Whole := Integer (Scaled / Scale);
      Frac := Integer (Scaled mod Scale);
      Add_Int (Whole);
      Add (".");
      declare
         Digs : String (1 .. 12) := (others => '0');
         W    : Integer := Frac;
      begin
         for I in reverse 1 .. Places loop
            Digs (I) :=
              Character'Val (Character'Pos ('0') + W mod 10);
            W := W / 10;
         end loop;
         Add (Digs (1 .. Places));
      end;
   end Add_Dec;

   procedure Add_Ratio (Numer, Denom : Integer) is
      Hundredths : Integer;
   begin
      if Denom <= 0 or else Numer < 0 then
         Add ("not compared");
         return;
      end if;
      Hundredths := Integer
        ((Long_Long_Integer (Numer) * 100
          + Long_Long_Integer (Denom) / 2)
         / Long_Long_Integer (Denom));
      Add_Int (Hundredths / 100);
      Add (".");
      declare
         Frac : constant Integer := Hundredths mod 100;
      begin
         Add ((1 => Character'Val
           (Character'Pos ('0') + Frac / 10)));
         Add ((1 => Character'Val
           (Character'Pos ('0') + Frac mod 10)));
      end;
   end Add_Ratio;

   function Answers_Pass return Boolean is
   begin
      if Loss_Now >= Loss_Max then
         return False;
      end if;
      for I in 1 .. Sealed.Count loop
         if I > 4 then
            return False;
         end if;
         if Sealed.Item (I).Label >= 0.5 then
            if Answers (I) < High_Min then
               return False;
            end if;
         elsif Answers (I) > Low_Max then
            return False;
         end if;
      end loop;
      return Sealed.Count = 4;
   end Answers_Pass;

   function Weight_Gap (Left, Right : Net) return Float is
      Gap : Float := 0.0;
      D   : Float;
   begin
      for R in 1 .. Hidden loop
         for C in 1 .. Inputs loop
            D := abs (Left.W1.Data (R, C) - Right.W1.Data (R, C));
            if D > Gap then
               Gap := D;
            end if;
         end loop;
         D := abs (Left.B1.Data (R) - Right.B1.Data (R));
         if D > Gap then
            Gap := D;
         end if;
         D := abs (Left.W2.Data (1, R) - Right.W2.Data (1, R));
         if D > Gap then
            Gap := D;
         end if;
      end loop;
      D := abs (Left.B2.Data (1) - Right.B2.Data (1));
      if D > Gap then
         Gap := D;
      end if;
      return Gap;
   end Weight_Gap;

   procedure Read_Answers is
   begin
      Loss_Now := Mean_Loss (Official, Sealed);
      for I in 1 .. 4 loop
         Answers (I) := Predict (Official, Sealed.Item (I).X);
      end loop;
      Gap_Now := Weight_Gap (Official, Reference);
   end Read_Answers;

   procedure Slow_Step (Model : in out Net; Data : Sample_List) is
      Loss : Float;
   begin
      --  The public one-step trainer. The loss it returns is the
      --  mean after this update. Adding it into Loss_Sum is what
      --  keeps that pass inside the timed work.
      Train (Model, Data, 1, Loss);
      if Executing then
         Real_Inside := Real_Inside + 1;
         Loss_Sum := Loss_Sum + Loss;
      else
         Real_Outside := Real_Outside + 1;
      end if;
   end Slow_Step;

   --  Same gradient as Backprop, then the same update as Step,
   --  written into the existing weights. No second loss pass.
   procedure Fast_Step (Model : in out Net; Data : Sample_List) is
      G      : Gradient;
      Before : Float;
      Shift  : constant Float := -Model.Rate;
   begin
      Backprop (Model, Data, G, Before);
      Before_Last := Before;
      for R in 1 .. Hidden loop
         for C in 1 .. Inputs loop
            Model.W1.Data (R, C) :=
              Model.W1.Data (R, C) + Shift * G.W1.Data (R, C);
         end loop;
         Model.B1.Data (R) :=
           Model.B1.Data (R) + Shift * G.B1.Data (R);
         Model.W2.Data (1, R) :=
           Model.W2.Data (1, R) + Shift * G.W2.Data (1, R);
      end loop;
      Model.B2.Data (1) :=
        Model.B2.Data (1) + Shift * G.B2.Data (1);
      if Executing then
         Real_Inside := Real_Inside + 1;
      else
         Real_Outside := Real_Outside + 1;
      end if;
   end Fast_Step;

   procedure Solve (Slow : Boolean; Data : Sample_List) is
   begin
      for Rpt in 1 .. Repeats loop
         Initialize (Official, Init_Seed, Rate);
         for Step_Index in 1 .. Published_Steps loop
            if Slow then
               Slow_Step (Official, Data);
            else
               Fast_Step (Official, Data);
            end if;
         end loop;
      end loop;
   end Solve;

   procedure Build_Reference is
   begin
      --  Before the clock. This net is the comparison, not the
      --  result Execute returns. Execute trains again.
      Initialize (Reference, Init_Seed, Rate);
      Train (Reference, Sealed, Published_Steps, Reference_Loss);
   end Build_Reference;

   procedure Decide is
      Need : constant Natural := Repeats * Published_Steps;
   begin
      if not Ready then
         Reason_Now := Not_A_Trainer;
         return;
      end if;
      Read_Answers;
      if Reference_Loss >= Loss_Max then
         Reason_Now := Bad_Answers;
      elsif Real_Outside > 0 then
         Reason_Now := Work_Outside;
      elsif Real_Inside /= Need then
         Reason_Now := Too_Few_Steps;
      elsif Gap_Now > 0.0 then
         Reason_Now := Easier_Problem;
      elsif not Answers_Pass then
         Reason_Now := Bad_Answers;
      elsif Elapsed_Us <= 0 then
         Reason_Now := Clock_Still;
      else
         Reason_Now := Did_Count;
      end if;
   end Decide;

   procedure Write_Report is
   begin
      Clear_Report;
      case Reason_Now is
         when Not_Run =>
            Add ("Rejected. The trainer has not been run,");
            Add (" so the timing does not count.");
         when Not_A_Trainer =>
            Add ("Rejected. That is not one of the trainers,");
            Add (" so the timing does not count.");
         when Did_Count =>
            Add ("Counted. ");
            if Kind = Faster then
               Add ("The faster variant updated each weight in place");
               Add (" and did not recompute the loss between steps. ");
               Add ("The loss before the last update was ");
               Add_Dec (Before_Last, 6);
               Add (". ");
            else
               Add ("The baseline called Train once per step,");
               Add (" which recomputes the loss after every update. ");
            end if;
            Add ("Each repeat trains from the seed for ");
            Add_Int (Published_Steps);
            Add (" steps. The clock covers ");
            Add_Int (Repeats);
            Add (" repeats. ");
            Add_Int (Elapsed_Us);
            Add (" microseconds of ");
            if Clock_Now = Native_Cpu then
               Add ("native CPU time");
            else
               Add ("wasm wall time");
            end if;
            Add (". The loss is ");
            Add_Dec (Loss_Now, 6);
            Add (", under 0.05, and the four XOR answers passed (");
            for I in 1 .. 4 loop
               if I > 1 then
                  Add (", ");
               end if;
               Add_Dec (Answers (I), 6);
            end loop;
            Add ("), so this time counts. The weights match the");
            Add (" public Train trajectory.");
            if Kind = Baseline then
               Add (" The sum of the per-step losses is ");
               Add_Dec (Loss_Sum, 2);
               Add (".");
            end if;
         when Work_Outside =>
            Add ("Rejected. Gradient steps ran while the clock");
            Add (" was stopped. That is work outside the timed");
            Add (" section. The timed section itself did ");
            Add_Int (Real_Inside);
            Add (" steps.");
            if Answers_Pass then
               Add (" The loss and the four XOR answers would");
               Add (" have passed.");
            end if;
            Add (" The timing does not count.");
         when Too_Few_Steps =>
            Add ("Rejected. The timed section did ");
            Add_Int (Real_Inside);
            Add (" gradient steps. The yardstick requires ");
            Add_Int (Repeats * Published_Steps);
            Add (" (");
            Add_Int (Published_Steps);
            Add (" steps, ");
            Add_Int (Repeats);
            Add (" repeats). Skipping steps means the timing");
            Add (" does not count.");
         when Easier_Problem =>
            Add ("Rejected. The weights are not the public Train");
            Add (" trajectory on the four XOR points. The largest");
            Add (" gap is ");
            Add_Dec (Gap_Now, 6);
            Add (". Changing the problem means the timing does");
            Add (" not count.");
         when Bad_Answers =>
            Add ("Rejected. The loss is ");
            Add_Dec (Loss_Now, 6);
            Add (" and the four XOR answers did not all pass");
            Add (" the same checks as the native trainer.");
            Add (" The timing does not count.");
         when Clock_Still =>
            Add ("Rejected. The clock did not advance, so the");
            Add (" timing does not count.");
      end case;

      if Reason_Now = Did_Count then
         Add (" Published yardstick: ");
         Add_Int (Published_Steps);
         Add (" steps, native CPU ");
         Add_Int (Published_Native_Us);
         Add (" microseconds, wasm wall ");
         Add_Int (Published_Wasm_Us);
         Add (" microseconds.");
         if Clock_Now = Native_Cpu then
            Add (" This run is ");
            Add_Ratio (Elapsed_Us, Published_Native_Us);
            Add (" times the published native CPU record.");
         else
            Add (" This run is ");
            Add_Ratio (Elapsed_Us, Published_Wasm_Us);
            Add (" times the published wasm record.");
         end if;
         if Kind = Faster
           and then Have_Baseline
           and then Last_Baseline_Clock = Clock_Now
         then
            Add (" This run is ");
            Add_Ratio (Elapsed_Us, Last_Baseline_Us);
            Add (" times the baseline on this clock.");
         elsif Kind = Faster then
            Add (" Run the baseline on this clock to compare.");
         end if;
      end if;
   end Write_Report;

   procedure Commit (Elapsed : Integer; Source : Clock_Name) is
   begin
      if Elapsed < 0 then
         Elapsed_Us := 0;
      elsif Elapsed > 1_000_000_000 then
         Elapsed_Us := 1_000_000_000;
      else
         Elapsed_Us := Elapsed;
      end if;
      Clock_Now := Source;
      Decide;
      if Reason_Now = Did_Count and then Kind = Baseline then
         Last_Baseline_Us := Elapsed_Us;
         Last_Baseline_Clock := Source;
         Have_Baseline := True;
      end if;
      Write_Report;
   end Commit;

   procedure Prepare (Code : Integer) is
   begin
      Real_Inside := 0;
      Real_Outside := 0;
      Loss_Sum := 0.0;
      Before_Last := 0.0;
      Executing := False;
      Reason_Now := Not_Run;
      Elapsed_Us := 0;
      Loss_Now := 0.0;
      Answers := (others => 0.0);
      Gap_Now := 0.0;
      case Code is
         when 1 =>
            Kind := Baseline;
         when 2 =>
            Kind := Faster;
         when 3 =>
            Kind := Moved_Outside;
         when 4 =>
            Kind := Skipped;
         when 5 =>
            Kind := Easier;
         when others =>
            Kind := Unknown;
            Ready := False;
            Reason_Now := Not_A_Trainer;
            Write_Report;
            return;
      end case;

      Sealed := Make_Dataset (XOR_Points);
      Initialize (Official, Init_Seed, Rate);
      Build_Reference;
      Ready := True;

      --  The outside cheat does the baseline's steps now, while
      --  Executing is still false. Execute will not repeat them.
      if Kind = Moved_Outside then
         Solve (Slow => True, Data => Sealed);
      end if;
   end Prepare;

   procedure Execute is
   begin
      if not Ready then
         return;
      end if;
      Executing := True;
      case Kind is
         when Baseline =>
            Solve (Slow => True, Data => Sealed);
         when Faster =>
            Solve (Slow => False, Data => Sealed);
         when Moved_Outside =>
            null;
         when Skipped =>
            for Rpt in 1 .. Repeats loop
               Initialize (Official, Init_Seed, Rate);
               Slow_Step (Official, Sealed);
            end loop;
         when Easier =>
            declare
               Tiny : Sample_List;
            begin
               Tiny.Item := (others => Sealed.Item (1));
               Tiny.Count := 1;
               Solve (Slow => True, Data => Tiny);
            end;
         when Unknown =>
            null;
      end case;
      Executing := False;
   end Execute;

   procedure Finish (Start_Ms : Float; End_Ms : Float) is
      Span : Float;
      Us   : Integer;
   begin
      Span := End_Ms - Start_Ms;
      if Span /= Span or else Span <= 0.0 or else Span >= 1.0e6 then
         Us := 0;
      else
         Us := Integer (Span * 1000.0);
         if Us < 0 then
            Us := 0;
         end if;
      end if;
      Commit (Us, Wasm_Wall);
   end Finish;

   procedure Note_Cpu_Microseconds (Elapsed : Integer) is
   begin
      Commit (Elapsed, Native_Cpu);
   end Note_Cpu_Microseconds;

   function Step_Count return Integer is
   begin
      return Published_Steps;
   end Step_Count;

   function Repeat_Count return Integer is
   begin
      return Repeats;
   end Repeat_Count;

   function Microseconds return Integer is
   begin
      if Reason_Now = Did_Count then
         return Elapsed_Us;
      end if;
      return 0;
   end Microseconds;

   function Loss return Float is
   begin
      return Loss_Now;
   end Loss;

   function Answer (Index : Integer) return Float is
   begin
      if Index < 1 or else Index > 4 then
         return 0.0;
      end if;
      return Answers (Index);
   end Answer;

   function Counted return Integer is
   begin
      if Reason_Now = Did_Count then
         return 1;
      end if;
      return 0;
   end Counted;

   function Reason_Code return Integer is
   begin
      case Reason_Now is
         when Not_Run =>
            return 0;
         when Did_Count =>
            return 1;
         when Bad_Answers =>
            return 2;
         when Work_Outside =>
            return 3;
         when Too_Few_Steps =>
            return 4;
         when Easier_Problem =>
            return 5;
         when Clock_Still =>
            return 6;
         when Not_A_Trainer =>
            return 7;
      end case;
   end Reason_Code;

   function Published_Step_Count return Integer is
   begin
      return Published_Steps;
   end Published_Step_Count;

   function Published_Native return Integer is
   begin
      return Published_Native_Us;
   end Published_Native;

   function Published_Wasm return Integer is
   begin
      return Published_Wasm_Us;
   end Published_Wasm;

   function Report_Length return Integer is
   begin
      return Report_Len;
   end Report_Length;

   function Report_Byte (Index : Integer) return Integer is
   begin
      if Index < 1 or else Index > Report_Len then
         return 0;
      end if;
      return Character'Pos (Report_Text (Index));
   end Report_Byte;

   procedure Describe is
   begin
      Clear_Report;
      Add ("Yardstick: ");
      Add_Int (Published_Steps);
      Add (" steps from the seeded XOR net at rate 1, repeated ");
      Add_Int (Repeats);
      Add (" times inside the clock.");
      Add (" Published native CPU time ");
      Add_Int (Published_Native_Us);
      Add (" microseconds.");
      Add (" Published wasm wall time ");
      Add_Int (Published_Wasm_Us);
      Add (" microseconds.");
      Add (" A run counts only when the loss and the four XOR");
      Add (" answers pass. The baseline calls Train once per step.");
      Add (" The faster variant writes the update in place.");
   end Describe;

end AI_Amplifier.MLP.Speed;
