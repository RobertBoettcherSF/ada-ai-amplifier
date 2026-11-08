with AI_Amplifier.MLP;
with AI_Amplifier.Recurse;
with AI_Amplifier.Step_Rule;
with AI_Amplifier.Tensors;

package body AI_Amplifier.Steps
  with SPARK_Mode => Off
is

   package M renames AI_Amplifier.MLP;
   package R renames AI_Amplifier.Recurse;
   package T renames AI_Amplifier.Tensors;
   use type R.Check_Name;

   LF : constant Character := Character'Val (10);

   XOR_Steps   : constant := 7;
   Train_Steps : constant := 7;
   Sum_Steps   : constant := 4;

   --  Planted shifts. The cancel solutions write these on top
   --  of the value the library returns. 0.05 on both hidden
   --  units cancels in the output logit. 0.25 on the bias
   --  gradient is not what Step applies.
   Hidden_Shift : constant := 0.05;
   Grad_Shift   : constant := 0.25;

   type Kind_Name is (No_Kind, XOR_Kind, Train_Kind, Fib_Kind, Sum_Kind);

   type Value_List is array (1 .. XOR_Steps) of Float;

   type Chain is array (0 .. Fib_Limit) of R.State;

   --  Character by character. A slice compare pulls in memcmp,
   --  and this wasm link does not provide that symbol. A
   --  returned slice would need a secondary stack, which this
   --  link also does not have. Callers pass a whole buffer and
   --  a last index.
   function Same_Span
     (Text       : String;
      From, Stop : Natural;
      Key        : String) return Boolean
   is
      Offset : Natural;
   begin
      if Key'Length = 0 or else From < Text'First or else Stop < From then
         return False;
      end if;
      if Stop > Text'Last or else Stop - From /= Key'Length - 1 then
         return False;
      end if;
      for J in Key'Range loop
         Offset := From + (J - Key'First);
         if Text (Offset) /= Key (J) then
            return False;
         end if;
      end loop;
      return True;
   end Same_Span;

   function Blank_Span
     (Text       : String;
      From, Stop : Natural) return Boolean
   is
   begin
      if Stop < From then
         return True;
      end if;
      if From < Text'First or else Stop > Text'Last then
         return False;
      end if;
      for I in From .. Stop loop
         if Text (I) /= ' ' and then Text (I) /= Character'Val (9) then
            return False;
         end if;
      end loop;
      return True;
   end Blank_Span;

   procedure Add
     (Dest : in out String;
      Last : in out Natural;
      Item : String;
      OK   : in out Boolean)
   is
   begin
      if not OK or else Item'Length = 0 then
         return;
      end if;
      if Last > Dest'Last or else Item'Length > Dest'Last - Last then
         OK := False;
         return;
      end if;
      Dest (Last + 1 .. Last + Item'Length) := Item;
      Last := Last + Item'Length;
   end Add;

   procedure Add_Nat
     (Dest  : in out String;
      Last  : in out Natural;
      Value : Natural;
      OK    : in out Boolean)
   is
      Digs : String (1 .. 12) := (others => '0');
      N    : Natural := Value;
      Top  : Natural := Digs'Last + 1;
   begin
      if not OK then
         return;
      end if;
      loop
         Top := Top - 1;
         Digs (Top) :=
           Character'Val (Character'Pos ('0') + N mod 10);
         N := N / 10;
         exit when N = 0 or else Top = Digs'First;
      end loop;
      if N /= 0 then
         OK := False;
         return;
      end if;
      Add (Dest, Last, Digs (Top .. Digs'Last), OK);
   end Add_Nat;

   procedure Add_Char
     (Dest : in out String;
      Last : in out Natural;
      Item : Character;
      OK   : in out Boolean)
   is
      Buf : String (1 .. 1);
   begin
      Buf (1) := Item;
      Add (Dest, Last, Buf, OK);
   end Add_Char;

   --  Eight digits after the decimal, same width the weight
   --  text uses. A value this library produces round-trips
   --  well inside Tol.
   procedure Add_Fixed
     (Dest  : in out String;
      Last  : in out Natural;
      Value : Float;
      OK    : in out Boolean)
   is
      Neg    : constant Boolean := Value < 0.0;
      Abs_V  : Long_Float;
      Scaled : Long_Long_Integer;
      Whole  : Long_Long_Integer;
      Frac   : Long_Long_Integer;
      W      : Long_Long_Integer;
      Pow    : Long_Long_Integer;
      Digs   : array (1 .. 16) of Integer := (others => 0);
      N      : Natural := 0;
      Dig      : Integer;
      Abs_Near : Long_Float;
      Guess    : Long_Long_Integer;
      Guess_F  : Long_Float;
   begin
      if not OK then
         return;
      end if;
      --  An integer that the scaler would print as n.00000001
      --  is the integer. Float'Rounding is not used: this wasm
      --  link does not provide that attribute's symbol.
      if Neg then
         Abs_Near := Long_Float (-Value);
      else
         Abs_Near := Long_Float (Value);
      end if;
      if Abs_Near < 1.0E9 then
         Guess := Long_Long_Integer (Abs_Near + 0.5);
         Guess_F := Long_Float (Guess);
         if abs (Abs_Near - Guess_F) <= 1.0E-8 then
            if Neg and then Guess /= 0 then
               Add (Dest, Last, "-", OK);
            end if;
            Add_Nat (Dest, Last, Natural (Guess), OK);
            return;
         end if;
      end if;
      if Neg then
         Abs_V := Long_Float (-Value);
      else
         Abs_V := Long_Float (Value);
      end if;
      if Abs_V >= 1.0E9 then
         OK := False;
         return;
      end if;
      Scaled := Long_Long_Integer (Abs_V * 100_000_000.0 + 0.5);
      Whole := Scaled / 100_000_000;
      Frac := Scaled mod 100_000_000;
      if Neg and then Scaled /= 0 then
         Add (Dest, Last, "-", OK);
      end if;
      W := Whole;
      if W = 0 then
         Add (Dest, Last, "0", OK);
      else
         while W > 0 and then N < Digs'Last loop
            N := N + 1;
            Digs (N) := Integer (W mod 10);
            W := W / 10;
         end loop;
         for I in reverse 1 .. N loop
            Dig := Digs (I);
            Add_Char
              (Dest, Last,
               Character'Val (Character'Pos ('0') + Dig),
               OK);
         end loop;
      end if;
      Add (Dest, Last, ".", OK);
      Pow := 10_000_000;
      for I in 1 .. 8 loop
         Dig := Integer (Frac / Pow);
         Add_Char
           (Dest, Last,
            Character'Val (Character'Pos ('0') + Dig),
            OK);
         Frac := Frac mod Pow;
         Pow := Pow / 10;
      end loop;
   end Add_Fixed;

   function Close (Left, Right : Float) return Boolean is
     (abs (Left - Right) <= Tol);

   function Point (X, Y : Float) return T.Vector is
     (Length => M.Inputs, Data => (X, Y));

   procedure XOR_Truth
     (X1, X2 : Float;
      Value  : out Value_List;
      Class  : out Integer)
   is
      Model : constant M.Net := M.Hand_XOR;
      X     : constant T.Vector := Point (X1, X2);
      Z1    : constant T.Vector :=
        T.Add (T.Mat_Vec (Model.W1, X), Model.B1);
      H     : constant T.Vector := T.Tanh (Z1);
      Z2    : constant T.Vector :=
        T.Add (T.Mat_Vec (Model.W2, H), Model.B2);
      Y     : constant T.Vector := T.Sigmoid (Z2);
   begin
      Value := (others => 0.0);
      Value (1) := Z1.Data (1);
      Value (2) := H.Data (1);
      Value (3) := Z1.Data (2);
      Value (4) := H.Data (2);
      Value (5) := H.Data (3);
      Value (6) := Z2.Data (1);
      Value (7) := Y.Data (1);
      if Y.Data (1) >= 0.5 then
         Class := 1;
      else
         Class := 0;
      end if;
   end XOR_Truth;

   procedure Train_Truth (Value : out Value_List; Bias : out Float) is
      Model : M.Net := M.Hand_XOR;
      Data  : constant M.Sample_List := M.Make_Dataset (M.XOR_Points);
      G     : M.Gradient;
      Loss  : Float;
   begin
      Value := (others => 0.0);
      Value (1) := M.Mean_Loss (Model, Data);
      Value (2) := M.Predict (Model, Point (0.0, 0.0));
      Value (3) := M.Predict (Model, Point (0.0, 1.0));
      Value (4) := M.Predict (Model, Point (1.0, 0.0));
      Value (5) := M.Predict (Model, Point (1.0, 1.0));
      M.Backprop (Model, Data, G, Loss);
      Value (6) := G.B2.Data (1);
      M.Step (Model, G);
      Value (7) := Model.B2.Data (1);
      Bias := Model.B2.Data (1);
   end Train_Truth;

   procedure Sum_Truth (Value : out Value_List; Total : out Float) is
      Left  : constant T.Vector :=
        (Length => 3, Data => (2.0, -1.0, 4.0));
      Right : constant T.Vector :=
        (Length => 3, Data => (3.0, 5.0, -2.0));
      Both  : constant T.Vector := T.Add (Left, Right);
   begin
      Value := (others => 0.0);
      Value (1) := Both.Data (1);
      Value (2) := Both.Data (2);
      Value (3) := Both.Data (3);
      Total := Both.Data (1) + Both.Data (2) + Both.Data (3);
      Value (4) := Total;
   end Sum_Truth;

   procedure Build_Fib
     (Index : Natural;
      Item  : out Chain;
      OK    : out Boolean)
   is
      Kind : R.Check_Name;
      Next : R.State;
   begin
      Item := (others => (0, 0, 0));
      OK := False;
      if Index > Fib_Limit then
         return;
      end if;
      R.Make_Opening (Index, Item (0), OK);
      if not OK then
         return;
      end if;
      for K in 1 .. Index loop
         if Item (K - 1).Fib_Index = 0
           or else Item (K - 1).Minus_One
             > R.Max_Value - Item (K - 1).Curr_Value
         then
            OK := False;
            return;
         end if;
         Next :=
           (Fib_Index  => Item (K - 1).Fib_Index - 1,
            Minus_One  => Item (K - 1).Curr_Value,
            Curr_Value =>
              Item (K - 1).Minus_One + Item (K - 1).Curr_Value);
         R.Check_Step (Item (K - 1), Next, Kind);
         if Kind /= R.Accepted and then Kind /= R.Reached_Base then
            OK := False;
            return;
         end if;
         Item (K) := Next;
      end loop;
   end Build_Fib;

   procedure Fib_Answer
     (Index  : Natural;
      Value  : out Natural;
      OK     : out Boolean)
   is
      Item : Chain;
   begin
      Value := 0;
      Build_Fib (Index, Item, OK);
      if OK then
         Value := Item (Index).Minus_One;
      end if;
   end Fib_Answer;

   procedure Lookup
     (Kind  : Kind_Name;
      Token : String;
      Code  : out Natural)
   is
   begin
      Code := 0;
      case Kind is
         when XOR_Kind =>
            if Same_Span (Token, Token'First, Token'Last, "h1-logit") then
               Code := 1;
            elsif Same_Span (Token, Token'First, Token'Last, "h1") then
               Code := 2;
            elsif Same_Span (Token, Token'First, Token'Last, "h2-logit") then
               Code := 3;
            elsif Same_Span (Token, Token'First, Token'Last, "h2") then
               Code := 4;
            elsif Same_Span (Token, Token'First, Token'Last, "silent") then
               Code := 5;
            elsif Same_Span (Token, Token'First, Token'Last, "out-logit") then
               Code := 6;
            elsif Same_Span (Token, Token'First, Token'Last, "output") then
               Code := 7;
            end if;
         when Train_Kind =>
            if Same_Span (Token, Token'First, Token'Last, "loss") then
               Code := 1;
            elsif Same_Span (Token, Token'First, Token'Last, "y00") then
               Code := 2;
            elsif Same_Span (Token, Token'First, Token'Last, "y01") then
               Code := 3;
            elsif Same_Span (Token, Token'First, Token'Last, "y10") then
               Code := 4;
            elsif Same_Span (Token, Token'First, Token'Last, "y11") then
               Code := 5;
            elsif Same_Span (Token, Token'First, Token'Last, "grad-b2") then
               Code := 6;
            elsif Same_Span (Token, Token'First, Token'Last, "b2") then
               Code := 7;
            end if;
         when Sum_Kind =>
            if Same_Span (Token, Token'First, Token'Last, "c1") then
               Code := 1;
            elsif Same_Span (Token, Token'First, Token'Last, "c2") then
               Code := 2;
            elsif Same_Span (Token, Token'First, Token'Last, "c3") then
               Code := 3;
            elsif Same_Span (Token, Token'First, Token'Last, "total") then
               Code := 4;
            end if;
         when No_Kind | Fib_Kind =>
            null;
      end case;
   end Lookup;

   function Required (Kind : Kind_Name; Fib_N : Natural) return Natural is
   begin
      case Kind is
         when XOR_Kind =>
            return XOR_Steps;
         when Train_Kind =>
            return Train_Steps;
         when Sum_Kind =>
            return Sum_Steps;
         when Fib_Kind =>
            return Fib_N;
         when No_Kind =>
            return 0;
      end case;
   end Required;

   procedure Built_In
     (Index : Natural;
      Text  : out String;
      Last  : out Natural)
   is
      OK    : Boolean := True;
      Value : Value_List;
      Class : Integer := 0;
      Bias  : Float := 0.0;
      Total : Float := 0.0;
      Fib   : Chain;
      Fib_OK : Boolean;

      procedure Line (Item : String) is
      begin
         Add (Text, Last, Item, OK);
         Add_Char (Text, Last, LF, OK);
      end Line;

      procedure Step_At (Name : String; Number : Float) is
      begin
         Add (Text, Last, "step ", OK);
         Add (Text, Last, Name, OK);
         Add (Text, Last, " ", OK);
         Add_Fixed (Text, Last, Number, OK);
         Add_Char (Text, Last, LF, OK);
      end Step_At;

      procedure Step_Code (Code : Positive; Number : Float) is
      begin
         case Code is
            when 1 =>
               Step_At ("h1-logit", Number);
            when 2 =>
               Step_At ("h1", Number);
            when 3 =>
               Step_At ("h2-logit", Number);
            when 4 =>
               Step_At ("h2", Number);
            when 5 =>
               Step_At ("silent", Number);
            when 6 =>
               Step_At ("out-logit", Number);
            when others =>
               Step_At ("output", Number);
         end case;
      end Step_Code;

      procedure Train_Code (Code : Positive; Number : Float) is
      begin
         case Code is
            when 1 =>
               Step_At ("loss", Number);
            when 2 =>
               Step_At ("y00", Number);
            when 3 =>
               Step_At ("y01", Number);
            when 4 =>
               Step_At ("y10", Number);
            when 5 =>
               Step_At ("y11", Number);
            when 6 =>
               Step_At ("grad-b2", Number);
            when others =>
               Step_At ("b2", Number);
         end case;
      end Train_Code;

      procedure Sum_Code (Code : Positive; Number : Float) is
      begin
         case Code is
            when 1 =>
               Step_At ("c1", Number);
            when 2 =>
               Step_At ("c2", Number);
            when 3 =>
               Step_At ("c3", Number);
            when others =>
               Step_At ("total", Number);
         end case;
      end Sum_Code;

      procedure Answer_Int (Number : Integer) is
      begin
         Add (Text, Last, "answer ", OK);
         if Number < 0 then
            Add (Text, Last, "-", OK);
            Add_Nat (Text, Last, Natural (-Number), OK);
         else
            Add_Nat (Text, Last, Natural (Number), OK);
         end if;
         Add_Char (Text, Last, LF, OK);
      end Answer_Int;

      procedure Answer_Fixed (Number : Float) is
      begin
         Add (Text, Last, "answer ", OK);
         Add_Fixed (Text, Last, Number, OK);
         Add_Char (Text, Last, LF, OK);
      end Answer_Fixed;

      procedure Trip (A, B, C : Natural) is
      begin
         Add (Text, Last, "step ", OK);
         Add_Nat (Text, Last, A, OK);
         Add (Text, Last, " ", OK);
         Add_Nat (Text, Last, B, OK);
         Add (Text, Last, " ", OK);
         Add_Nat (Text, Last, C, OK);
         Add_Char (Text, Last, LF, OK);
      end Trip;

      procedure XOR_Problem (X1, X2 : Integer) is
      begin
         Add (Text, Last, "problem xor ", OK);
         Add_Nat (Text, Last, X1, OK);
         Add (Text, Last, " ", OK);
         Add_Nat (Text, Last, X2, OK);
         Add_Char (Text, Last, LF, OK);
      end XOR_Problem;

      procedure Named (Name : String) is
      begin
         Add (Text, Last, "name ", OK);
         Add (Text, Last, Name, OK);
         Add_Char (Text, Last, LF, OK);
      end Named;

   begin
      Last := 0;
      if Text'Length = 0 then
         return;
      end if;
      Text := (others => ' ');
      if Index < 1 or else Index > Solution_Count then
         return;
      end if;
      case Index is
         when 1 =>
            XOR_Truth (0.0, 0.0, Value, Class);
            Named ("xor-00-right");
            XOR_Problem (0, 0);
            for Code in 1 .. XOR_Steps loop
               Step_Code (Code, Value (Code));
            end loop;
            Answer_Int (Class);
         when 2 =>
            --  h1 and h2 are each 0.05 below tanh. Those two
            --  errors cancel in 6*h1 - 6*h2, so the logit and
            --  the class stay the ones the forward pass returns.
            XOR_Truth (1.0, 0.0, Value, Class);
            Named ("xor-10-cancel");
            XOR_Problem (1, 0);
            Step_Code (1, Value (1));
            Step_Code (2, Value (2) - Hidden_Shift);
            Step_Code (3, Value (3));
            Step_Code (4, Value (4) - Hidden_Shift);
            Step_Code (5, Value (5));
            Step_Code (6, Value (6));
            Step_Code (7, Value (7));
            Answer_Int (Class);
         when 3 =>
            --  The tanh steps are missing. The class is still
            --  the one sigmoid returns for (1, 1).
            XOR_Truth (1.0, 1.0, Value, Class);
            Named ("xor-11-skip");
            XOR_Problem (1, 1);
            Step_Code (1, Value (1));
            Step_Code (3, Value (3));
            Step_Code (5, Value (5));
            Step_Code (6, Value (6));
            Step_Code (7, Value (7));
            Answer_Int (Class);
         when 4 =>
            --  The class is written first. The lines under it
            --  are a different story: both voting units at 0,
            --  then the output bias alone.
            XOR_Truth (0.0, 0.0, Value, Class);
            Named ("xor-00-guess");
            XOR_Problem (0, 0);
            Answer_Int (Class);
            Step_At ("h1-logit", 0.0);
            Step_At ("h1", 0.0);
            Step_At ("h2-logit", 0.0);
            Step_At ("h2", 0.0);
            Step_At ("silent", 0.0);
            Step_At ("out-logit", -6.0);
            Step_At ("output", 0.0);
         when 5 =>
            XOR_Truth (0.0, 1.0, Value, Class);
            Named ("xor-01-wrong");
            XOR_Problem (0, 1);
            for Code in 1 .. XOR_Steps loop
               Step_Code (Code, Value (Code));
            end loop;
            Answer_Int (1 - Class);
         when 6 =>
            Train_Truth (Value, Bias);
            Named ("train-right");
            Line ("problem train");
            for Code in 1 .. Train_Steps loop
               Train_Code (Code, Value (Code));
            end loop;
            Answer_Fixed (Bias);
         when 7 =>
            --  The gradient is 0.25 above Backprop. The bias
            --  written below is still the bias Step stores,
            --  which is not what that gradient would produce.
            Train_Truth (Value, Bias);
            Named ("train-cancel");
            Line ("problem train");
            for Code in 1 .. 5 loop
               Train_Code (Code, Value (Code));
            end loop;
            Train_Code (6, Value (6) + Grad_Shift);
            Train_Code (7, Value (7));
            Answer_Fixed (Bias);
         when 8 =>
            Build_Fib (6, Fib, Fib_OK);
            Named ("fib-6-right");
            Line ("problem fib 6");
            if Fib_OK then
               for K in 1 .. 6 loop
                  Trip
                    (Fib (K).Fib_Index,
                     Fib (K).Minus_One,
                     Fib (K).Curr_Value);
               end loop;
               Answer_Int (Integer (Fib (6).Minus_One));
            end if;
         when 9 =>
            --  Step 2 adds one too many. Step 3 carries that
            --  sum. Step 4 states the true pair anyway, so the
            --  answer is still F(5).
            Build_Fib (5, Fib, Fib_OK);
            Named ("fib-5-cancel");
            Line ("problem fib 5");
            if Fib_OK then
               Trip
                 (Fib (1).Fib_Index,
                  Fib (1).Minus_One,
                  Fib (1).Curr_Value);
               Trip
                 (Fib (2).Fib_Index,
                  Fib (2).Minus_One,
                  Fib (2).Curr_Value + 1);
               Trip
                 (Fib (2).Fib_Index - 1,
                  Fib (2).Curr_Value + 1,
                  Fib (2).Minus_One + Fib (2).Curr_Value + 1);
               Trip
                 (Fib (4).Fib_Index,
                  Fib (4).Minus_One,
                  Fib (4).Curr_Value);
               Trip
                 (Fib (5).Fib_Index,
                  Fib (5).Minus_One,
                  Fib (5).Curr_Value);
               Answer_Int (Integer (Fib (5).Minus_One));
            end if;
         when 10 =>
            --  The step that leaves index 2 is missing. The
            --  answer is still F(4).
            Build_Fib (4, Fib, Fib_OK);
            Named ("fib-4-skip");
            Line ("problem fib 4");
            if Fib_OK then
               Trip
                 (Fib (1).Fib_Index,
                  Fib (1).Minus_One,
                  Fib (1).Curr_Value);
               Trip
                 (Fib (3).Fib_Index,
                  Fib (3).Minus_One,
                  Fib (3).Curr_Value);
               Trip
                 (Fib (4).Fib_Index,
                  Fib (4).Minus_One,
                  Fib (4).Curr_Value);
               Answer_Int (Integer (Fib (4).Minus_One));
            end if;
         when 11 =>
            Sum_Truth (Value, Total);
            Named ("sum-right");
            Line ("problem sum");
            for Code in 1 .. Sum_Steps loop
               Sum_Code (Code, Value (Code));
            end loop;
            Answer_Fixed (Total);
         when 12 =>
            --  The total is stated before the three adds. The
            --  components underneath are the ones Add returns.
            Sum_Truth (Value, Total);
            Named ("sum-guess");
            Line ("problem sum");
            Sum_Code (4, Value (4));
            Sum_Code (1, Value (1));
            Sum_Code (2, Value (2));
            Sum_Code (3, Value (3));
            Answer_Fixed (Total);
         when others =>
            OK := False;
      end case;
      if not OK then
         Last := 0;
      end if;
   end Built_In;

   Max_Parsed : constant := 24;

   type Sort_Name is
     (Tok_Name, Tok_Problem, Tok_Step, Tok_Answer, Tok_Junk);

   type Parsed is record
      Sort      : Sort_Name := Tok_Junk;
      Line      : String (1 .. Max_Line) := (others => ' ');
      Line_Last : Natural := 0;
      Code      : Natural := 0;
      Has_Value : Boolean := False;
      Value     : Float := 0.0;
      Trip      : Boolean := False;
      P1        : Natural := 0;
      P2        : Natural := 0;
      P3        : Natural := 0;
   end record;

   type Parsed_List is array (1 .. Max_Parsed) of Parsed;

   procedure Skip_Space
     (Text       : String;
      From, Stop : Natural;
      Next       : out Natural)
   is
      I : Natural := From;
   begin
      if From < Text'First then
         Next := From;
         return;
      end if;
      while I <= Stop
        and then I <= Text'Last
        and then (Text (I) = ' ' or else Text (I) = Character'Val (9))
      loop
         I := I + 1;
      end loop;
      Next := I;
   end Skip_Space;

   procedure Take_Word
     (Text             : String;
      From, Stop       : Natural;
      Word_A, Word_B   : out Natural;
      Next             : out Natural)
   is
      I : Natural;
   begin
      Skip_Space (Text, From, Stop, I);
      Word_A := I;
      while I <= Stop
        and then I <= Text'Last
        and then Text (I) /= ' '
        and then Text (I) /= Character'Val (9)
      loop
         I := I + 1;
      end loop;
      Word_B := I - 1;
      Next := I;
   end Take_Word;

   procedure Parse_Float
     (Text       : String;
      From, Stop : Natural;
      Value      : out Float;
      Next       : out Natural;
      OK         : out Boolean)
   is
      I      : Natural;
      Neg    : Boolean := False;
      Whole  : Float := 0.0;
      Frac   : Float := 0.0;
      Scale  : Float := 1.0;
      Seen   : Natural := 0;
      Dot    : Boolean := False;
      Digit  : Integer;
   begin
      Value := 0.0;
      Next := From;
      OK := False;
      Skip_Space (Text, From, Stop, I);
      if I > Stop or else I > Text'Last or else I < Text'First then
         return;
      end if;
      if Text (I) = '-' or else Text (I) = '+' then
         Neg := Text (I) = '-';
         I := I + 1;
      end if;
      while I <= Stop and then I <= Text'Last loop
         if Text (I) in '0' .. '9' then
            Digit := Character'Pos (Text (I)) - Character'Pos ('0');
            Seen := Seen + 1;
            if Seen > 12 then
               return;
            end if;
            if not Dot then
               Whole := Whole * 10.0 + Float (Digit);
            else
               Scale := Scale / 10.0;
               Frac := Frac + Scale * Float (Digit);
            end if;
            I := I + 1;
         elsif Text (I) = '.' and then not Dot then
            Dot := True;
            I := I + 1;
         else
            exit;
         end if;
      end loop;
      if Seen = 0 then
         return;
      end if;
      Value := Whole + Frac;
      if Neg then
         Value := -Value;
      end if;
      Next := I;
      OK := True;
   end Parse_Float;

   procedure Parse_Nat
     (Text       : String;
      From, Stop : Natural;
      Value      : out Natural;
      Next       : out Natural;
      OK         : out Boolean)
   is
      I     : Natural;
      Acc   : Natural := 0;
      Digit : Natural;
      Any   : Boolean := False;
   begin
      Value := 0;
      Next := From;
      OK := False;
      Skip_Space (Text, From, Stop, I);
      if I > Stop or else I > Text'Last or else I < Text'First then
         return;
      end if;
      while I <= Stop and then I <= Text'Last and then Text (I) in '0' .. '9'
      loop
         Any := True;
         Digit := Character'Pos (Text (I)) - Character'Pos ('0');
         if Acc > (R.Max_Value - Digit) / 10 then
            return;
         end if;
         Acc := Acc * 10 + Digit;
         I := I + 1;
      end loop;
      if not Any then
         return;
      end if;
      Value := Acc;
      Next := I;
      OK := True;
   end Parse_Nat;

   procedure Copy_Line
     (Text       : String;
      From, Stop : Natural;
      Into       : out Parsed)
   is
      A : Natural;
      N : Natural := 0;
   begin
      Into.Line := (others => ' ');
      Into.Line_Last := 0;
      if Stop < From or else From < Text'First or else Stop > Text'Last then
         return;
      end if;
      A := From;
      while A <= Stop
        and then (Text (A) = ' ' or else Text (A) = Character'Val (9))
      loop
         A := A + 1;
      end loop;
      declare
         B : Natural := Stop;
      begin
         while B > A
           and then (Text (B) = ' ' or else Text (B) = Character'Val (9)
                     or else Text (B) = Character'Val (13))
         loop
            B := B - 1;
         end loop;
         if Text (B) = ' ' or else Text (B) = Character'Val (9) then
            return;
         end if;
         for I in A .. B loop
            N := N + 1;
            if N > Max_Line then
               Into.Line_Last := 0;
               return;
            end if;
            Into.Line (N) := Text (I);
         end loop;
         Into.Line_Last := N;
      end;
   end Copy_Line;

   procedure Check_Alone
     (Problem : String;
      Line    : String;
      Item    : out Alone;
      Rule    : out Rule_Name)
   is
      P    : String (1 .. Max_Line) := (others => ' ');
      L    : String (1 .. Max_Line) := (others => ' ');
      PL   : Natural := 0;
      LL   : Natural := 0;
      Kind : Kind_Name := No_Kind;
      Have : Boolean := False;
      X1   : Float := 0.0;
      X2   : Float := 0.0;
      Fib_N : Natural := 0;
      Truth : Value_List := (others => 0.0);
      Class : Integer := 0;
      Bias  : Float := 0.0;
      Total : Float := 0.0;
      Fib   : Chain;
      Fib_OK : Boolean := False;
      Expect : Float := 0.0;

      procedure Copy_In
        (Src  : String;
         Dest : out String;
         Last : out Natural)
      is
      begin
         Last := 0;
         Dest := (others => ' ');
         if Src'Length = 0 or else Src'Length > Dest'Length then
            return;
         end if;
         for I in Src'Range loop
            Last := Last + 1;
            Dest (Last) := Src (I);
         end loop;
      end Copy_In;

      procedure Read_Problem is
         A, B, N : Natural;
         Word_A, Word_B : Natural;
         Num : Natural;
         Num_OK : Boolean;
      begin
         if PL < 1 then
            return;
         end if;
         A := 1;
         B := PL;
         Take_Word (P, A, B, Word_A, Word_B, N);
         if Word_B < Word_A then
            return;
         end if;
         if Same_Span (P, Word_A, Word_B, "xor") then
            declare
               D1, D2 : Natural;
               N1, N2 : Natural;
               OK1, OK2 : Boolean;
            begin
               Parse_Nat (P, N, B, D1, N1, OK1);
               Parse_Nat (P, N1, B, D2, N2, OK2);
               if not OK1 or else not OK2
                 or else not Blank_Span (P, N2, B)
                 or else (D1 /= 0 and then D1 /= 1)
                 or else (D2 /= 0 and then D2 /= 1)
               then
                  return;
               end if;
               Kind := XOR_Kind;
               X1 := Float (D1);
               X2 := Float (D2);
               XOR_Truth (X1, X2, Truth, Class);
               Expect := Float (Class);
               Have := True;
            end;
         elsif Same_Span (P, Word_A, Word_B, "train") then
            if not Blank_Span (P, N, B) then
               return;
            end if;
            Kind := Train_Kind;
            Train_Truth (Truth, Bias);
            Expect := Bias;
            Have := True;
         elsif Same_Span (P, Word_A, Word_B, "sum") then
            if not Blank_Span (P, N, B) then
               return;
            end if;
            Kind := Sum_Kind;
            Sum_Truth (Truth, Total);
            Expect := Total;
            Have := True;
         elsif Same_Span (P, Word_A, Word_B, "fib") then
            Parse_Nat (P, N, B, Num, N, Num_OK);
            if not Num_OK
              or else Num > Fib_Limit
              or else not Blank_Span (P, N, B)
            then
               return;
            end if;
            Kind := Fib_Kind;
            Fib_N := Num;
            Build_Fib (Fib_N, Fib, Fib_OK);
            if not Fib_OK then
               return;
            end if;
            Expect := Float (Fib (Fib_N).Minus_One);
            Have := True;
         end if;
      end Read_Problem;

      procedure Decide_Answer (From : Natural) is
         Num : Float;
         Next : Natural;
         Num_OK : Boolean;
      begin
         Parse_Float (L, From, LL, Num, Next, Num_OK);
         if not Num_OK or else not Blank_Span (L, Next, LL) then
            Item := Not_Checkable;
            Rule := Bad_Parse;
            return;
         end if;
         if Close (Num, Expect) then
            Item := Checked_Correct;
            Rule := None;
         else
            Item := Checked_Wrong;
            Rule := Wrong_Answer;
         end if;
      end Decide_Answer;

      procedure Decide_Fib (From : Natural) is
         N1, N2, N3 : Natural;
         V1, V2, V3 : Natural;
         OK1, OK2, OK3 : Boolean;
         Step_Kind : R.Check_Name;
         Found : Boolean := False;
      begin
         Parse_Nat (L, From, LL, V1, N1, OK1);
         Parse_Nat (L, N1, LL, V2, N2, OK2);
         Parse_Nat (L, N2, LL, V3, N3, OK3);
         if not OK1 or else not OK2 or else not OK3
           or else not Blank_Span (L, N3, LL)
         then
            Item := Not_Checkable;
            Rule := None;
            return;
         end if;
         for K in 1 .. Fib_N loop
            if Fib (K).Fib_Index = V1 then
               Found := True;
               R.Check_Step
                 (Fib (K - 1),
                  (Fib_Index => V1, Minus_One => V2, Curr_Value => V3),
                  Step_Kind);
               if (Step_Kind = R.Accepted or else Step_Kind = R.Reached_Base)
                 and then V2 = Fib (K).Minus_One
                 and then V3 = Fib (K).Curr_Value
               then
                  Item := Checked_Correct;
                  Rule := None;
               else
                  Item := Checked_Wrong;
                  if Step_Kind = R.Bad_Arithmetic then
                     Rule := Bad_Arithmetic;
                  elsif Step_Kind = R.Not_Toward_Base
                    or else Step_Kind = R.Past_Base
                  then
                     Rule := Not_Toward_Base;
                  else
                     Rule := Bad_Arithmetic;
                  end if;
               end if;
               exit;
            end if;
         end loop;
         if not Found then
            Item := Checked_Wrong;
            Rule := Not_Toward_Base;
         end if;
      end Decide_Fib;

      procedure Decide_Named (From : Natural) is
         Word_A, Word_B : Natural;
         Next, Rest : Natural;
         Code : Natural;
         Num : Float;
         Num_OK : Boolean;
      begin
         Take_Word (L, From, LL, Word_A, Word_B, Next);
         if Word_B < Word_A then
            Item := Not_Checkable;
            Rule := Bad_Parse;
            return;
         end if;
         Lookup (Kind, L (Word_A .. Word_B), Code);
         if Code = 0 then
            Item := Not_Checkable;
            Rule := Unknown_Step;
            return;
         end if;
         Parse_Float (L, Next, LL, Num, Rest, Num_OK);
         if not Num_OK or else not Blank_Span (L, Rest, LL) then
            Item := Not_Checkable;
            Rule := Bad_Parse;
            return;
         end if;
         if Close (Num, Truth (Code)) then
            Item := Checked_Correct;
            Rule := None;
         else
            Item := Checked_Wrong;
            Rule := Bad_Value;
         end if;
      end Decide_Named;

      A, B, N : Natural;
      Word_A, Word_B : Natural;
   begin
      Item := Not_Checkable;
      Rule := Unknown_Problem;
      Copy_In (Problem, P, PL);
      Copy_In (Line, L, LL);
      if PL < 1 or else LL < 1 then
         return;
      end if;
      Read_Problem;
      if not Have then
         return;
      end if;
      A := 1;
      B := LL;
      Take_Word (L, A, B, Word_A, Word_B, N);
      if Word_B < Word_A then
         Item := Not_Checkable;
         Rule := None;
         return;
      end if;
      if Same_Span (L, Word_A, Word_B, "answer") then
         Decide_Answer (N);
      elsif Same_Span (L, Word_A, Word_B, "step") then
         if Kind = Fib_Kind then
            Decide_Fib (N);
         else
            Decide_Named (N);
         end if;
      else
         Item := Not_Checkable;
         Rule := None;
      end if;
   end Check_Alone;

   procedure Grade (Text : String; Item : out Report) is
      List  : Parsed_List;
      Count : Natural := 0;
      Kind  : Kind_Name := No_Kind;
      Have  : Boolean := False;
      X1    : Float := 0.0;
      X2    : Float := 0.0;
      Fib_N : Natural := 0;
      Truth : Value_List := (others => 0.0);
      Class : Integer := 0;
      Bias  : Float := 0.0;
      Total : Float := 0.0;
      Fib   : Chain;
      Fib_OK : Boolean := False;
      Expect : Float := 0.0;
      Next_Code : Natural := 1;
      Fib_Seen  : Natural := 0;
      Saw_Answer : Boolean := False;
      Answer_OK  : Boolean := False;
      Steps_Done : Boolean := False;

      procedure Clear (Row : out Report) is
      begin
         Row.Name := (others => ' ');
         Row.Name_Last := 0;
         Row.Answer_Grade := Fail;
         Row.Step_Grade := Fail;
         Row.Bad_At := 0;
         Row.Rule := None;
         Row.Count := 0;
         Row.Item := (others => <>);
      end Clear;

      procedure Push
        (Line : String;
         Last : Natural;
         Where   : out Natural)
      is
      begin
         Where := 0;
         if Item.Count >= Max_Steps then
            if Item.Bad_At = 0 and then Item.Count >= 1 then
               Item.Item (Item.Count).OK := False;
               Item.Item (Item.Count).Rule := Bad_Parse;
               Item.Bad_At := Item.Count;
               Item.Rule := Bad_Parse;
            end if;
            return;
         end if;
         Item.Count := Item.Count + 1;
         Where := Item.Count;
         Item.Item (Where).Text := (others => ' ');
         Item.Item (Where).Last := 0;
         Item.Item (Where).OK := True;
         Item.Item (Where).Rule := None;
         if Last >= 1 and then Last <= Max_Line then
            Item.Item (Where).Text (1 .. Last) :=
              Line (Line'First .. Line'First + Last - 1);
            Item.Item (Where).Last := Last;
         end if;
      end Push;

      procedure Blame (Where : Natural; Rule : Rule_Name) is
      begin
         if Where < 1 or else Where > Item.Count then
            return;
         end if;
         Item.Item (Where).OK := False;
         Item.Item (Where).Rule := Rule;
         if Item.Bad_At = 0 then
            Item.Bad_At := Where;
            Item.Rule := Rule;
         end if;
      end Blame;

      function Later_Step (From : Natural) return Boolean is
      begin
         for I in From + 1 .. Count loop
            if List (I).Sort = Tok_Step then
               return True;
            end if;
         end loop;
         return False;
      end Later_Step;

      procedure Take_Problem
        (Slot : Parsed;
         Where   : Natural)
      is
         A, B, N : Natural;
         Word_A, Word_B : Natural;
         Num : Natural;
         Num_OK : Boolean;
      begin
         if Have then
            Blame (Where, Bad_Parse);
            return;
         end if;
         A := Slot.Line'First;
         B := Slot.Line_Last;
         Take_Word (Slot.Line, A, B, Word_A, Word_B, N);
         Take_Word (Slot.Line, N, B, Word_A, Word_B, N);
         if Word_B < Word_A then
            Blame (Where, Unknown_Problem);
            return;
         end if;
         if Same_Span (Slot.Line, Word_A, Word_B, "xor") then
            declare
               D1, D2 : Natural;
               N1, N2 : Natural;
               OK1, OK2 : Boolean;
            begin
               Parse_Nat (Slot.Line, N, B, D1, N1, OK1);
               Parse_Nat (Slot.Line, N1, B, D2, N2, OK2);
               if not OK1 or else not OK2
                 or else not Blank_Span (Slot.Line, N2, B)
                 or else (D1 /= 0 and then D1 /= 1)
                 or else (D2 /= 0 and then D2 /= 1)
               then
                  Blame (Where, Unknown_Problem);
                  return;
               end if;
               Kind := XOR_Kind;
               X1 := Float (D1);
               X2 := Float (D2);
               XOR_Truth (X1, X2, Truth, Class);
               Expect := Float (Class);
               Have := True;
            end;
         elsif Same_Span (Slot.Line, Word_A, Word_B, "train") then
            if not Blank_Span (Slot.Line, N, B) then
               Blame (Where, Unknown_Problem);
               return;
            end if;
            Kind := Train_Kind;
            Train_Truth (Truth, Bias);
            Expect := Bias;
            Have := True;
         elsif Same_Span (Slot.Line, Word_A, Word_B, "sum") then
            if not Blank_Span (Slot.Line, N, B) then
               Blame (Where, Unknown_Problem);
               return;
            end if;
            Kind := Sum_Kind;
            Sum_Truth (Truth, Total);
            Expect := Total;
            Have := True;
         elsif Same_Span (Slot.Line, Word_A, Word_B, "fib") then
            Parse_Nat (Slot.Line, N, B, Num, N, Num_OK);
            if not Num_OK
              or else Num > Fib_Limit
              or else not Blank_Span (Slot.Line, N, B)
            then
               Blame (Where, Unknown_Problem);
               return;
            end if;
            Kind := Fib_Kind;
            Fib_N := Num;
            Build_Fib (Fib_N, Fib, Fib_OK);
            if Fib_OK then
               Expect := Float (Fib (Fib_N).Minus_One);
            else
               Blame (Where, Unknown_Problem);
               return;
            end if;
            Have := True;
         else
            Blame (Where, Unknown_Problem);
         end if;
      end Take_Problem;

      procedure Take_Step (Slot : in out Parsed; Where : Natural) is
         A, B, N : Natural;
         Word_A, Word_B : Natural;
         Rest : Natural;
         Num_OK : Boolean;
         Need : Natural;
      begin
         if not Have then
            Blame (Where, Unknown_Problem);
            return;
         end if;
         A := Slot.Line'First;
         B := Slot.Line_Last;
         Take_Word (Slot.Line, A, B, Word_A, Word_B, N);
         if Kind = Fib_Kind then
            declare
               N1, N2, N3 : Natural;
               V1, V2, V3 : Natural;
               OK1, OK2, OK3 : Boolean;
               Step_Kind : R.Check_Name;
            begin
               Parse_Nat (Slot.Line, N, B, V1, N1, OK1);
               Parse_Nat (Slot.Line, N1, B, V2, N2, OK2);
               Parse_Nat (Slot.Line, N2, B, V3, N3, OK3);
               if not OK1 or else not OK2 or else not OK3
                 or else not Blank_Span (Slot.Line, N3, B)
               then
                  Blame (Where, Bad_Parse);
                  return;
               end if;
               if Fib_Seen >= Fib_N then
                  Blame (Where, Out_Of_Order);
                  return;
               end if;
               Fib_Seen := Fib_Seen + 1;
               R.Check_Step
                 (Fib (Fib_Seen - 1),
                  (Fib_Index => V1, Minus_One => V2, Curr_Value => V3),
                  Step_Kind);
               if Step_Kind = R.Bad_Arithmetic then
                  Blame (Where, Bad_Arithmetic);
               elsif Step_Kind = R.Not_Toward_Base
                 or else Step_Kind = R.Past_Base
               then
                  Blame (Where, Not_Toward_Base);
               elsif Step_Kind /= R.Accepted
                 and then Step_Kind /= R.Reached_Base
               then
                  Blame (Where, Bad_Parse);
               elsif V1 /= Fib (Fib_Seen).Fib_Index
                 or else V2 /= Fib (Fib_Seen).Minus_One
                 or else V3 /= Fib (Fib_Seen).Curr_Value
               then
                  Blame (Where, Bad_Arithmetic);
               end if;
            end;
            return;
         end if;
         Take_Word (Slot.Line, N, B, Word_A, Word_B, Rest);
         if Word_B < Word_A then
            Blame (Where, Bad_Parse);
            return;
         end if;
         Lookup
           (Kind,
            Slot.Line (Word_A .. Word_B),
            Slot.Code);
         if Slot.Code = 0 then
            Blame (Where, Unknown_Step);
            return;
         end if;
         Parse_Float (Slot.Line, Rest, B, Slot.Value, Rest, Num_OK);
         if not Num_OK or else not Blank_Span (Slot.Line, Rest, B) then
            Blame (Where, Bad_Parse);
            return;
         end if;
         Need := Required (Kind, Fib_N);
         if Need < 1 or else Slot.Code < 1 or else Next_Code < 1 then
            Blame (Where, Bad_Parse);
         else
            case Step_Rule.Order_Of (Slot.Code, Next_Code, Need) is
               when Step_Rule.Earlier_Step =>
                  Blame (Where, Out_Of_Order);
               when Step_Rule.Guessed_Answer =>
                  Blame (Where, Guessed_First);
                  Next_Code := Slot.Code + 1;
               when Step_Rule.Skipped_Middle =>
                  Blame (Where, Skipped_Step);
                  Next_Code := Slot.Code + 1;
               when Step_Rule.In_Order =>
                  if not Close (Slot.Value, Truth (Slot.Code)) then
                     Blame (Where, Bad_Value);
                  end if;
                  Next_Code := Slot.Code + 1;
            end case;
         end if;
      end Take_Step;

      procedure Take_Answer
        (Slot  : Parsed;
         Index : Natural;
         Where : Natural)
      is
         A, B, N : Natural;
         Word_A, Word_B : Natural;
         Num : Float;
         Num_OK : Boolean;
         Need : Natural;
         Done : Boolean;
      begin
         if Saw_Answer then
            Blame (Where, Out_Of_Order);
            return;
         end if;
         Saw_Answer := True;
         if not Have then
            Blame (Where, Unknown_Problem);
            Answer_OK := False;
            return;
         end if;
         A := Slot.Line'First;
         B := Slot.Line_Last;
         Take_Word (Slot.Line, A, B, Word_A, Word_B, N);
         Parse_Float (Slot.Line, N, B, Num, N, Num_OK);
         if not Num_OK or else not Blank_Span (Slot.Line, N, B) then
            Blame (Where, Bad_Parse);
            Answer_OK := False;
            return;
         end if;
         Answer_OK := Close (Num, Expect);
         if Answer_OK then
            Item.Answer_Grade := Pass;
         else
            Item.Answer_Grade := Fail;
         end if;
         Need := Required (Kind, Fib_N);
         if Kind = Fib_Kind then
            Done := Fib_Seen >= Fib_N;
         else
            Done := Next_Code > Need;
         end if;
         case Step_Rule.Answer_Fault
           (Done, Later_Step (Index), Answer_OK)
         is
            when Step_Rule.Answer_Guessed =>
               Blame (Where, Guessed_First);
            when Step_Rule.Answer_Skipped =>
               Blame (Where, Skipped_Step);
            when Step_Rule.Answer_Wrong =>
               Blame (Where, Wrong_Answer);
            when Step_Rule.Answer_Held =>
               null;
         end case;
      end Take_Answer;

      procedure Store_Name (Slot : Parsed; Where : Natural) is
         A, B, N : Natural;
         Word_A, Word_B : Natural;
      begin
         if Item.Name_Last /= 0 then
            Blame (Where, Bad_Parse);
            return;
         end if;
         A := Slot.Line'First;
         B := Slot.Line_Last;
         Take_Word (Slot.Line, A, B, Word_A, Word_B, N);
         Take_Word (Slot.Line, N, B, Word_A, Word_B, N);
         if Word_B < Word_A
           or else not Blank_Span (Slot.Line, N, B)
           or else Word_B - Word_A + 1 > Max_Name
         then
            Blame (Where, Bad_Parse);
            return;
         end if;
         for I in Word_A .. Word_B loop
            Item.Name_Last := Item.Name_Last + 1;
            Item.Name (Item.Name_Last) := Slot.Line (I);
         end loop;
      end Store_Name;

      Pos : Natural;
   begin
      Clear (Item);
      if Text'Length = 0 then
         Push ("problem", 7, Pos);
         Blame (Pos, Unknown_Problem);
         return;
      end if;
      declare
         I     : Natural := Text'First;
         First : Natural;
         Stop  : Natural;
         Slot  : Parsed;
         Hash  : Boolean;
      begin
         while I <= Text'Last loop
            First := I;
            Stop := I - 1;
            while I <= Text'Last and then Text (I) /= LF loop
               Stop := I;
               I := I + 1;
            end loop;
            if I <= Text'Last and then Text (I) = LF then
               I := I + 1;
            end if;
            if Stop >= First
              and then not Blank_Span (Text, First, Stop)
            then
               Hash := False;
               for J in First .. Stop loop
                  if Text (J) /= ' '
                    and then Text (J) /= Character'Val (9)
                  then
                     Hash := Text (J) = '#';
                     exit;
                  end if;
               end loop;
               if not Hash then
                  if Count >= Max_Parsed then
                     Push ("step", 4, Pos);
                     Blame (Pos, Bad_Parse);
                     exit;
                  end if;
                  Count := Count + 1;
                  List (Count) := Slot;
                  Copy_Line (Text, First, Stop, List (Count));
                  if List (Count).Line_Last < 1 then
                     List (Count).Sort := Tok_Junk;
                  elsif Same_Span
                    (List (Count).Line, 1, 4, "name")
                    and then List (Count).Line_Last >= 4
                    and then (List (Count).Line_Last = 4
                              or else List (Count).Line (5) = ' ')
                  then
                     List (Count).Sort := Tok_Name;
                  elsif Same_Span
                    (List (Count).Line, 1, 7, "problem")
                    and then List (Count).Line_Last >= 7
                    and then (List (Count).Line_Last = 7
                              or else List (Count).Line (8) = ' ')
                  then
                     List (Count).Sort := Tok_Problem;
                  elsif Same_Span
                    (List (Count).Line, 1, 4, "step")
                    and then List (Count).Line_Last >= 4
                    and then (List (Count).Line_Last = 4
                              or else List (Count).Line (5) = ' ')
                  then
                     List (Count).Sort := Tok_Step;
                  elsif Same_Span
                    (List (Count).Line, 1, 6, "answer")
                    and then List (Count).Line_Last >= 6
                    and then (List (Count).Line_Last = 6
                              or else List (Count).Line (7) = ' ')
                  then
                     List (Count).Sort := Tok_Answer;
                  else
                     List (Count).Sort := Tok_Junk;
                  end if;
               end if;
            end if;
         end loop;
      end;

      for I in 1 .. Count loop
         declare
            Where : Natural;
         begin
            case List (I).Sort is
               when Tok_Name =>
                  Push (List (I).Line, List (I).Line_Last, Where);
                  if Where /= 0 then
                     Store_Name (List (I), Where);
                     --  The name is not a step the page lists.
                     --  A bad name stays. A good name is dropped
                     --  so the rows are the steps and the answer.
                     if Item.Item (Where).OK then
                        Item.Count := Item.Count - 1;
                     end if;
                  end if;
               when Tok_Problem =>
                  Push (List (I).Line, List (I).Line_Last, Where);
                  if Where /= 0 then
                     Take_Problem (List (I), Where);
                     if Item.Item (Where).OK then
                        Item.Count := Item.Count - 1;
                     end if;
                  end if;
               when Tok_Step =>
                  Push (List (I).Line, List (I).Line_Last, Where);
                  if Where /= 0 then
                     Take_Step (List (I), Where);
                  end if;
               when Tok_Answer =>
                  Push (List (I).Line, List (I).Line_Last, Where);
                  if Where /= 0 then
                     Take_Answer (List (I), I, Where);
                  end if;
               when Tok_Junk =>
                  Push (List (I).Line, List (I).Line_Last, Where);
                  Blame (Where, Bad_Parse);
            end case;
         end;
      end loop;

      if not Have and then Item.Bad_At = 0 then
         declare
            Where : Natural;
         begin
            Push ("problem", 7, Where);
            Blame (Where, Unknown_Problem);
         end;
      end if;
      if not Saw_Answer then
         declare
            Where : Natural;
         begin
            Push ("answer", 6, Where);
            Blame (Where, Wrong_Answer);
            Item.Answer_Grade := Fail;
         end;
      end if;
      Steps_Done :=
        Step_Rule.Steps_Complete
          (Known     => Have,
           Fib       => Kind = Fib_Kind,
           Seen      => Fib_Seen,
           Index     => Fib_N,
           Next_Code => Next_Code,
           Need      => Required (Kind, Fib_N));
      if Step_Rule.Step_Grade_Passes
        (Item.Bad_At, Item.Answer_Grade = Pass, Steps_Done)
      then
         Item.Step_Grade := Pass;
      else
         Item.Step_Grade := Fail;
      end if;
   end Grade;

   procedure Grade_Built_In (Index : Natural; Item : out Report) is
      Buf  : String (1 .. Max_Text);
      Last : Natural;
   begin
      Built_In (Index, Buf, Last);
      if Last < 1 then
         Grade ("", Item);
      else
         Grade (Buf (1 .. Last), Item);
      end if;
   end Grade_Built_In;

   procedure Put_Word
     (Text : out String;
      Last : out Natural;
      Word : String)
   is
   begin
      Last := 0;
      Text := (others => ' ');
      if Word'Length = 0 or else Word'Length > Text'Length then
         return;
      end if;
      Text (Text'First .. Text'First + Word'Length - 1) := Word;
      Last := Word'Length;
   end Put_Word;

   procedure Rule_Word
     (Rule : Rule_Name;
      Text : out String;
      Last : out Natural)
   is
   begin
      case Rule is
         when None =>
            Put_Word (Text, Last, "none");
         when Bad_Parse =>
            Put_Word (Text, Last, "bad-parse");
         when Unknown_Problem =>
            Put_Word (Text, Last, "unknown-problem");
         when Unknown_Step =>
            Put_Word (Text, Last, "unknown-step");
         when Bad_Value =>
            Put_Word (Text, Last, "bad-value");
         when Skipped_Step =>
            Put_Word (Text, Last, "skipped-step");
         when Guessed_First =>
            Put_Word (Text, Last, "guessed-first");
         when Wrong_Answer =>
            Put_Word (Text, Last, "wrong-answer");
         when Out_Of_Order =>
            Put_Word (Text, Last, "out-of-order");
         when Bad_Arithmetic =>
            Put_Word (Text, Last, "bad-arithmetic");
         when Not_Toward_Base =>
            Put_Word (Text, Last, "not-toward-base");
      end case;
   end Rule_Word;

   procedure Mark_Word
     (Item : Mark;
      Text : out String;
      Last : out Natural)
   is
   begin
      if Item = Pass then
         Put_Word (Text, Last, "pass");
      else
         Put_Word (Text, Last, "fail");
      end if;
   end Mark_Word;

   procedure Header_Line (Text : out String; Last : out Natural) is
   begin
      Put_Word (Text, Last, "name  answer  steps");
   end Header_Line;

   procedure Line_For
     (Item : Report;
      Text : out String;
      Last : out Natural)
   is
      OK   : Boolean := True;
      Ans  : String (1 .. 8);
      St   : String (1 .. 8);
      ALast, SLast : Natural;
   begin
      Last := 0;
      Text := (others => ' ');
      if Item.Name_Last = 0 then
         Add (Text, Last, "(file)", OK);
      else
         Add (Text, Last, Item.Name (1 .. Item.Name_Last), OK);
      end if;
      Mark_Word (Item.Answer_Grade, Ans, ALast);
      Mark_Word (Item.Step_Grade, St, SLast);
      Add (Text, Last, "  ", OK);
      if ALast >= 1 then
         Add (Text, Last, Ans (1 .. ALast), OK);
      end if;
      Add (Text, Last, "  ", OK);
      if SLast >= 1 then
         Add (Text, Last, St (1 .. SLast), OK);
      end if;
      if not OK then
         Last := 0;
      end if;
   end Line_For;

   procedure Stat_Line (Text : out String; Last : out Natural) is
      OK     : Boolean := True;
      Ans    : Natural := 0;
      Steps  : Natural := 0;
      Sample : Report;
   begin
      Last := 0;
      Text := (others => ' ');
      for I in 1 .. Solution_Count loop
         Grade_Built_In (I, Sample);
         if Sample.Answer_Grade = Pass then
            Ans := Ans + 1;
         end if;
         if Sample.Step_Grade = Pass then
            Steps := Steps + 1;
         end if;
      end loop;
      Add (Text, Last, "12 solutions. Answer-only passes ", OK);
      Add_Nat (Text, Last, Ans, OK);
      Add (Text, Last, ". Steps pass ", OK);
      Add_Nat (Text, Last, Steps, OK);
      Add (Text, Last, ". Only the steps count.", OK);
      if not OK then
         Last := 0;
      end if;
   end Stat_Line;

end AI_Amplifier.Steps;
