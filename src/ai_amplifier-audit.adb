with AI_Amplifier.Audit_Rule;
with AI_Amplifier.MLP;
with AI_Amplifier.Recurse;

package body AI_Amplifier.Audit
  with SPARK_Mode => Off
is

   use type Recurse.Check_Name;

   LF : constant Character := Character'Val (10);

   procedure Fail
     (Bank      : out Set;
      OK        : out Boolean;
      Note      : out String;
      Note_Last : out Natural;
      Why       : String)
   is
   begin
      Bank := (Count => 0, Examined => False, Slot => (others => <>));
      OK := False;
      Note_Last := 0;
      if Why'Length > Note'Length then
         return;
      end if;
      Note (Note'First .. Note'First + Why'Length - 1) := Why;
      Note_Last := Why'Length;
   end Fail;

   procedure Put
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
   end Put;

   procedure Put_Natural
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
         exit when N = 0;
      end loop;
      Put (Dest, Last, Digs (Top .. Digs'Last), OK);
   end Put_Natural;

   function Is_Space (C : Character) return Boolean is
     (C = ' ' or else C = Character'Val (9) or else C = Character'Val (13));

   function Is_Token_Char (C : Character) return Boolean is
     (C in '0' .. '9'
      or else C in 'a' .. 'z'
      or else C in 'A' .. 'Z'
      or else C = '-');

   procedure Next_Token
     (Text  : String;
      From  : in out Natural;
      First : out Natural;
      Stop  : out Natural;
      Found : out Boolean)
   is
   begin
      First := Text'First;
      Stop := Text'First;
      Found := False;
      while From <= Text'Last and then not Is_Token_Char (Text (From)) loop
         From := From + 1;
      end loop;
      if From > Text'Last then
         return;
      end if;
      First := From;
      while From <= Text'Last and then Is_Token_Char (Text (From)) loop
         From := From + 1;
      end loop;
      Stop := From - 1;
      Found := True;
   end Next_Token;

   function Same (Left, Right : String) return Boolean;

   function Token_Is (Text : String; Token : String) return Boolean is
      From  : Natural := Text'First;
      First : Natural;
      Stop  : Natural;
      Found : Boolean;
   begin
      if Token'Length = 0 then
         return False;
      end if;
      loop
         Next_Token (Text, From, First, Stop, Found);
         exit when not Found;
         if Stop - First + 1 = Token'Length
           and then Same (Text (First .. Stop), Token)
         then
            return True;
         end if;
      end loop;
      return False;
   end Token_Is;

   procedure Take_Line
     (Text : String;
      Pos  : in out Natural;
      Line : out String;
      Last : out Natural;
      Got  : out Boolean;
      Fit  : out Boolean)
   is
      N : Natural := 0;
   begin
      Last := 0;
      Got := False;
      Fit := True;
      Line := (others => ' ');
      if Pos > Text'Last then
         return;
      end if;
      Got := True;
      while Pos <= Text'Last and then Text (Pos) /= LF loop
         if Text (Pos) /= Character'Val (13) then
            if N >= Line'Last then
               Fit := False;
            else
               N := N + 1;
               Line (N) := Text (Pos);
            end if;
         end if;
         Pos := Pos + 1;
      end loop;
      if Pos <= Text'Last and then Text (Pos) = LF then
         Pos := Pos + 1;
      end if;
      Last := N;
   end Take_Line;

   procedure Trim
     (Line  : String;
      Last  : in out Natural;
      First : out Natural)
   is
   begin
      First := 1;
      while First <= Last and then Is_Space (Line (First)) loop
         First := First + 1;
      end loop;
      while Last >= First and then Is_Space (Line (Last)) loop
         Last := Last - 1;
      end loop;
   end Trim;

   procedure Collapse
     (Src  : String;
      Dest : out String;
      Last : out Natural;
      Fit  : out Boolean)
   is
      Gap : Boolean := False;
   begin
      Dest := (others => ' ');
      Last := 0;
      Fit := True;
      for C of Src loop
         if Is_Space (C) then
            if Last > 0 then
               Gap := True;
            end if;
         else
            if Gap then
               if Last >= Dest'Last then
                  Fit := False;
                  Last := 0;
                  return;
               end if;
               Last := Last + 1;
               Dest (Last) := ' ';
               Gap := False;
            end if;
            if Last >= Dest'Last then
               Fit := False;
               Last := 0;
               return;
            end if;
            Last := Last + 1;
            Dest (Last) := C;
         end if;
      end loop;
   end Collapse;

   procedure Copy_Field
     (Src  : String;
      Dest : out String;
      Last : out Natural;
      Fit  : out Boolean)
   is
   begin
      Dest := (others => ' ');
      Last := 0;
      Fit := Src'Length <= Dest'Length;
      if not Fit or else Src'Length = 0 then
         return;
      end if;
      Dest (Dest'First .. Dest'First + Src'Length - 1) := Src;
      Last := Src'Length;
   end Copy_Field;

   --  Character by character. A direct string "=" here becomes
   --  memcmp, and this wasm link does not provide that symbol.
   function Same (Left, Right : String) return Boolean is
      I : Integer := Left'First;
      J : Integer := Right'First;
   begin
      if Left'Length /= Right'Length then
         return False;
      end if;
      while I <= Left'Last loop
         if Left (I) /= Right (J) then
            return False;
         end if;
         I := I + 1;
         J := J + 1;
      end loop;
      return True;
   end Same;

   function Same_Text
     (Left : String; Left_Last : Natural;
      Right : String; Right_Last : Natural) return Boolean
   is
   begin
      if Left_Last /= Right_Last then
         return False;
      end if;
      if Left_Last = 0 then
         return True;
      end if;
      return Same
        (Left (Left'First .. Left'First + Left_Last - 1),
         Right (Right'First .. Right'First + Right_Last - 1));
   end Same_Text;

   procedure Add_Flag (Slot : in out Item; Rule : Rule_Name) is
   begin
      if Slot.Flag_Count >= Max_Flags then
         return;
      end if;
      for I in 1 .. Slot.Flag_Count loop
         if Slot.Flags (I) = Rule then
            return;
         end if;
      end loop;
      Slot.Flag_Count := Slot.Flag_Count + 1;
      Slot.Flags (Slot.Flag_Count) := Rule;
   end Add_Flag;

   procedure Parse_Nat
     (Token : String;
      Value : out Natural;
      OK    : out Boolean)
   is
      Acc : Natural := 0;
   begin
      Value := 0;
      OK := False;
      if Token'Length = 0 or else Token'Length > 7 then
         return;
      end if;
      if Token'Length > 1 and then Token (Token'First) = '0' then
         return;
      end if;
      for C of Token loop
         if C not in '0' .. '9' then
            return;
         end if;
         Acc := Acc * 10 + (Character'Pos (C) - Character'Pos ('0'));
      end loop;
      Value := Acc;
      OK := True;
   end Parse_Nat;

   procedure Store_Answer
     (Value : Natural;
      Dest  : out String;
      Last  : out Natural)
   is
      OK : Boolean := True;
   begin
      Dest := (others => ' ');
      Last := 0;
      Put_Natural (Dest, Last, Value, OK);
      if not OK then
         Last := 0;
      end if;
   end Store_Answer;

   procedure Store_Word
     (Word : String;
      Dest : out String;
      Last : out Natural;
      OK   : out Boolean)
   is
   begin
      Copy_Field (Word, Dest, Last, OK);
   end Store_Word;

   procedure Recompute
     (Kind    : String;
      Input   : String;
      Answer  : out String;
      Last    : out Natural;
      Solvable : out Boolean)
   is
      procedure No is
      begin
         Answer := (others => ' ');
         Last := 0;
         Solvable := False;
      end No;

      procedure Yes (Word : String) is
         Fit : Boolean;
      begin
         Store_Word (Word, Answer, Last, Fit);
         Solvable := Fit and then Last > 0;
         if not Solvable then
            Last := 0;
         end if;
      end Yes;
   begin
      No;
      if Same (Kind, "xor-label") then
         declare
            From  : Natural := Input'First;
            First : Natural;
            Stop  : Natural;
            Found : Boolean;
            A, B  : Natural;
            OK    : Boolean;
            Data  : MLP.Sample_List;
         begin
            Next_Token (Input, From, First, Stop, Found);
            if not Found then
               return;
            end if;
            Parse_Nat (Input (First .. Stop), A, OK);
            if not OK then
               return;
            end if;
            Next_Token (Input, From, First, Stop, Found);
            if not Found then
               return;
            end if;
            Parse_Nat (Input (First .. Stop), B, OK);
            if not OK then
               return;
            end if;
            Next_Token (Input, From, First, Stop, Found);
            if Found then
               return;
            end if;
            Data := MLP.Make_Dataset (MLP.XOR_Points);
            for I in 1 .. Data.Count loop
               if Data.Item (I).X.Data (1) = Float (A)
                 and then Data.Item (I).X.Data (2) = Float (B)
               then
                  if Data.Item (I).Label = 0.0 then
                     Yes ("0");
                  elsif Data.Item (I).Label = 1.0 then
                     Yes ("1");
                  end if;
                  return;
               end if;
            end loop;
         end;
      elsif Same (Kind, "xor-count") then
         if Input'Length /= 0 then
            return;
         end if;
         declare
            Data : constant MLP.Sample_List :=
              MLP.Make_Dataset (MLP.XOR_Points);
         begin
            Store_Answer (Data.Count, Answer, Last);
            Solvable := Last > 0;
         end;
      elsif Same (Kind, "fib-answer") then
         declare
            From  : Natural := Input'First;
            First : Natural;
            Stop  : Natural;
            Found : Boolean;
            Index : Natural;
            OK    : Boolean;
            Text  : String (1 .. Recurse.Max_Chain);
            TLast : Natural;
            Play  : Recurse.Replay;
         begin
            Next_Token (Input, From, First, Stop, Found);
            if not Found then
               return;
            end if;
            Parse_Nat (Input (First .. Stop), Index, OK);
            if not OK then
               return;
            end if;
            Next_Token (Input, From, First, Stop, Found);
            if Found then
               return;
            end if;
            Recurse.Correct_Chain (Index, Text, TLast, OK);
            if not OK or else TLast = 0 then
               return;
            end if;
            Recurse.Check_Chain (Text (1 .. TLast), Play);
            if Play.Stop /= Recurse.Reached_Base then
               return;
            end if;
            Store_Answer (Play.Answer, Answer, Last);
            Solvable := Last > 0;
         end;
      elsif Same (Kind, "fib-stop") then
         declare
            Name  : String (1 .. Recurse.Max_Name);
            NLast : Natural;
            Play  : Recurse.Replay;
            OK    : Boolean;
            Word  : String (1 .. 32);
            WLast : Natural;
         begin
            for I in 1 .. Recurse.Chain_Count loop
               Recurse.Chain_Name (I, Name, NLast);
               if NLast > 0 and then Same (Name (1 .. NLast), Input) then
                  Recurse.Replay_Recorded (I, Play, OK);
                  if not OK then
                     return;
                  end if;
                  Recurse.Kind_Word (Play.Stop, Word, WLast);
                  if WLast = 0 then
                     return;
                  end if;
                  Yes (Word (1 .. WLast));
                  return;
               end if;
            end loop;
         end;
      elsif Same (Kind, "weight-status") then
         declare
            Source : constant MLP.Net := MLP.Hand_XOR;
            Dest   : MLP.Net := MLP.Hand_XOR;
            Chars  : MLP.Weight_Chars;
            Count  : Natural;
            Buf    : String (1 .. MLP.Max_Weight_Text);
            Status : MLP.Load_Status;
            Mode   : Natural := 0;
            Number : String (1 .. Max_Answer);
            NLast  : Natural := 0;
         begin
            if Same (Input, "roundtrip") then
               Mode := 1;
            elsif Input'Length > 6
              and then Same
                (Input (Input'First .. Input'First + 5), "shape ")
            then
               Mode := 2;
            elsif Input'Length > 6
              and then Same
                (Input (Input'First .. Input'First + 5), "value ")
            then
               Mode := 3;
               Copy_Field
                 (Input (Input'First + 6 .. Input'Last),
                  Number, NLast, Fit => Solvable);
               if not Solvable or else NLast = 0 then
                  No;
                  return;
               end if;
               Solvable := False;
            else
               return;
            end if;
            MLP.Write_Weights (Source, Chars, Count);
            if Count = 0 or else Count > Buf'Last then
               return;
            end if;
            for I in 1 .. Count loop
               Buf (I) := Chars (I);
            end loop;
            if Mode = 2 then
               declare
                  At_Line : Natural := 1;
                  Found   : Boolean := False;
               begin
                  while At_Line <= Count loop
                     declare
                        Stop : Natural := At_Line;
                        Head : Natural;
                     begin
                        while Stop <= Count and then Buf (Stop) /= LF loop
                           Stop := Stop + 1;
                        end loop;
                        Head := At_Line;
                        while Head < Stop and then Is_Space (Buf (Head)) loop
                           Head := Head + 1;
                        end loop;
                        if Stop - Head >= 5
                          and then Same (Buf (Head .. Head + 4), "shape")
                          and then
                            (Head + 5 > Stop
                             or else Is_Space (Buf (Head + 5)))
                        then
                           declare
                              Old_Len : constant Natural := Stop - At_Line;
                              Grow    : Integer;
                           begin
                              Grow := Input'Length - Integer (Old_Len);
                              if Grow > 0
                                and then Count + Natural (Grow) > Buf'Last
                              then
                                 return;
                              end if;
                              if Grow > 0 then
                                 for I in reverse Stop .. Count loop
                                    Buf (I + Natural (Grow)) := Buf (I);
                                 end loop;
                              elsif Grow < 0 then
                                 for I in Stop .. Count loop
                                    Buf (I - Natural (-Grow)) := Buf (I);
                                 end loop;
                              end if;
                              Buf (At_Line .. At_Line + Input'Length - 1) :=
                                Input;
                              if Grow >= 0 then
                                 Count := Count + Natural (Grow);
                              else
                                 Count := Count - Natural (-Grow);
                              end if;
                              Found := True;
                           end;
                           exit;
                        end if;
                        if Stop <= Count and then Buf (Stop) = LF then
                           At_Line := Stop + 1;
                        else
                           exit;
                        end if;
                     end;
                  end loop;
                  if not Found then
                     return;
                  end if;
               end;
            elsif Mode = 3 then
               declare
                  Needle : constant String := " x1 ";
                  At_Pos : Natural := 0;
                  Start  : Natural;
                  Stop   : Natural;
               begin
                  for I in 1 .. Count - Needle'Length + 1 loop
                     if Same (Buf (I .. I + Needle'Length - 1), Needle) then
                        At_Pos := I;
                        exit;
                     end if;
                  end loop;
                  if At_Pos = 0 then
                     return;
                  end if;
                  Start := At_Pos + Needle'Length;
                  while Start <= Count and then Is_Space (Buf (Start)) loop
                     Start := Start + 1;
                  end loop;
                  Stop := Start;
                  while Stop <= Count
                    and then (Buf (Stop) in '0' .. '9'
                      or else Buf (Stop) = '.'
                      or else Buf (Stop) = '-'
                      or else Buf (Stop) = '+'
                      or else Buf (Stop) = 'e'
                      or else Buf (Stop) = 'E')
                  loop
                     Stop := Stop + 1;
                  end loop;
                  if Stop = Start then
                     return;
                  end if;
                  declare
                     Old_Len : constant Natural := Stop - Start;
                     Grow    : constant Integer :=
                       Integer (NLast) - Integer (Old_Len);
                  begin
                     if Grow > 0
                       and then Count + Natural (Grow) > Buf'Last
                     then
                        return;
                     end if;
                     if Grow > 0 then
                        for I in reverse Stop .. Count loop
                           Buf (I + Natural (Grow)) := Buf (I);
                        end loop;
                        Count := Count + Natural (Grow);
                     elsif Grow < 0 then
                        for I in Stop .. Count loop
                           Buf (I - Natural (-Grow)) := Buf (I);
                        end loop;
                        Count := Count - Natural (-Grow);
                     end if;
                     Buf (Start .. Start + NLast - 1) := Number (1 .. NLast);
                  end;
               end;
            end if;
            Chars := (others => ' ');
            for I in 1 .. Count loop
               Chars (I) := Buf (I);
            end loop;
            MLP.Read_Weights (Dest, Chars, Count, Status);
            case Status is
               when MLP.Loaded =>
                  Yes ("loaded");
               when MLP.Bad_Shape =>
                  Yes ("bad-shape");
               when MLP.Bad_Value =>
                  Yes ("bad-value");
               when MLP.Bad_Syntax =>
                  Yes ("bad-syntax");
            end case;
         end;
      end if;
   end Recompute;

   function Accepts (Slot : Item; Candidate : String) return Boolean is
   begin
      if Slot.Grade_Any then
         return True;
      end if;
      if Slot.Expected_Last = 0 then
         return Candidate'Length = 0;
      end if;
      return Same
        (Candidate, Slot.Expected (1 .. Slot.Expected_Last));
   end Accepts;

   function Leaked (Slot : Item) return Boolean is
   begin
      if Slot.Expected_Last = 0 or else Slot.Prompt_Last = 0 then
         return False;
      end if;
      if not Token_Is
        (Slot.Prompt (1 .. Slot.Prompt_Last),
         Slot.Expected (1 .. Slot.Expected_Last))
      then
         return False;
      end if;
      if Slot.Input_Last = 0 then
         return True;
      end if;
      return not Token_Is
        (Slot.Input (1 .. Slot.Input_Last),
         Slot.Expected (1 .. Slot.Expected_Last));
   end Leaked;

   procedure Load
     (Text      : String;
      Bank      : out Set;
      OK        : out Boolean;
      Note      : out String;
      Note_Last : out Natural)
   is
      Pos   : Natural := Text'First;
      Line  : String (1 .. 200);
      Last  : Natural;
      Got   : Boolean;
      Fit   : Boolean;
      Open  : Boolean := False;
      Seen_Kind, Seen_Prompt, Seen_Input : Boolean := False;
      Seen_Expected, Seen_Grade, Seen_Sample : Boolean := False;

      procedure Close_Task (Good : out Boolean) is
      begin
         Good := Open and then Seen_Kind and then Seen_Prompt
           and then Seen_Input and then Seen_Expected
           and then Seen_Grade and then Seen_Sample;
      end Close_Task;

      procedure Reset_Seen is
      begin
         Seen_Kind := False;
         Seen_Prompt := False;
         Seen_Input := False;
         Seen_Expected := False;
         Seen_Grade := False;
         Seen_Sample := False;
      end Reset_Seen;
   begin
      Bank := (Count => 0, Examined => False, Slot => (others => <>));
      OK := False;
      Note := (others => ' ');
      Note_Last := 0;
      while Pos <= Text'Last loop
         Take_Line (Text, Pos, Line, Last, Got, Fit);
         exit when not Got;
         if not Fit then
            Fail (Bank, OK, Note, Note_Last, "line too long");
            return;
         end if;
         declare
            First : Natural;
            Key_From : Natural;
            Key_First, Key_Stop : Natural;
            Key_Found : Boolean;
            Rest_First : Natural;
            Rest : String (1 .. 200);
            Rest_Last : Natural;
         begin
            Trim (Line, Last, First);
            if First > Last or else Line (First) = '#' then
               null;
            else
               Key_From := First;
               Next_Token
                 (Line (1 .. Last), Key_From,
                  Key_First, Key_Stop, Key_Found);
               if not Key_Found then
                  Fail (Bank, OK, Note, Note_Last, "bad line");
                  return;
               end if;
               Rest_First := Key_Stop + 1;
               if Rest_First <= Last then
                  Collapse (Line (Rest_First .. Last), Rest, Rest_Last, Fit);
               else
                  Rest_Last := 0;
                  Fit := True;
               end if;
               if not Fit then
                  Fail (Bank, OK, Note, Note_Last, "field too long");
                  return;
               end if;
               declare
                  function Is_Key (Word : String) return Boolean is
                    (Same (Line (Key_First .. Key_Stop), Word));
               begin
                  if Is_Key ("task") then
                     if Open then
                        Fail (Bank, OK, Note, Note_Last, "unclosed task");
                        return;
                     end if;
                     if Bank.Count = Max_Tasks then
                        Fail (Bank, OK, Note, Note_Last, "too many tasks");
                        return;
                     end if;
                     if Rest_Last = 0 then
                        Fail (Bank, OK, Note, Note_Last, "bad id");
                        return;
                     end if;
                     for C of Rest (1 .. Rest_Last) loop
                        if C not in 'a' .. 'z'
                          and then C not in '0' .. '9'
                          and then C /= '-'
                        then
                           Fail (Bank, OK, Note, Note_Last, "bad id");
                           return;
                        end if;
                     end loop;
                     for I in 1 .. Bank.Count loop
                        if Same_Text
                          (Bank.Slot (I).Id, Bank.Slot (I).Id_Last,
                           Rest, Rest_Last)
                        then
                           Fail (Bank, OK, Note, Note_Last, "duplicate id");
                           return;
                        end if;
                     end loop;
                     Bank.Count := Bank.Count + 1;
                     Copy_Field
                       (Rest (1 .. Rest_Last),
                        Bank.Slot (Bank.Count).Id,
                        Bank.Slot (Bank.Count).Id_Last,
                        Fit);
                     if not Fit then
                        Fail (Bank, OK, Note, Note_Last, "bad id");
                        return;
                     end if;
                     Open := True;
                     Reset_Seen;
                  elsif not Open then
                     Fail (Bank, OK, Note, Note_Last, "task not open");
                     return;
                  elsif Is_Key ("end") then
                     if Rest_Last /= 0 then
                        Fail (Bank, OK, Note, Note_Last, "bad line");
                        return;
                     end if;
                     declare
                        Good : Boolean;
                     begin
                        Close_Task (Good);
                        if not Good then
                           Fail (Bank, OK, Note, Note_Last, "missing field");
                           return;
                        end if;
                     end;
                     Open := False;
                  elsif Is_Key ("kind") then
                     if Seen_Kind or else Rest_Last = 0
                       or else Rest_Last > Max_Kind
                     then
                        Fail (Bank, OK, Note, Note_Last, "bad kind");
                        return;
                     end if;
                     Copy_Field
                       (Rest (1 .. Rest_Last),
                        Bank.Slot (Bank.Count).Kind,
                        Bank.Slot (Bank.Count).Kind_Last,
                        Fit);
                     Seen_Kind := Fit;
                  elsif Is_Key ("prompt") then
                     if Seen_Prompt or else Rest_Last = 0
                       or else Rest_Last > Max_Prompt
                     then
                        Fail (Bank, OK, Note, Note_Last, "bad prompt");
                        return;
                     end if;
                     Copy_Field
                       (Rest (1 .. Rest_Last),
                        Bank.Slot (Bank.Count).Prompt,
                        Bank.Slot (Bank.Count).Prompt_Last,
                        Fit);
                     Seen_Prompt := Fit;
                  elsif Is_Key ("input") then
                     if Seen_Input or else Rest_Last > Max_Input then
                        Fail (Bank, OK, Note, Note_Last, "bad input");
                        return;
                     end if;
                     if Rest_Last = 0 then
                        Bank.Slot (Bank.Count).Input_Last := 0;
                        Fit := True;
                     else
                        Copy_Field
                          (Rest (1 .. Rest_Last),
                           Bank.Slot (Bank.Count).Input,
                           Bank.Slot (Bank.Count).Input_Last,
                           Fit);
                     end if;
                     Seen_Input := Fit;
                  elsif Is_Key ("expected") then
                     if Seen_Expected or else Rest_Last = 0
                       or else Rest_Last > Max_Answer
                     then
                        Fail (Bank, OK, Note, Note_Last, "bad expected");
                        return;
                     end if;
                     Copy_Field
                       (Rest (1 .. Rest_Last),
                        Bank.Slot (Bank.Count).Expected,
                        Bank.Slot (Bank.Count).Expected_Last,
                        Fit);
                     Seen_Expected := Fit;
                  elsif Is_Key ("sample") then
                     if Seen_Sample or else Rest_Last = 0
                       or else Rest_Last > Max_Answer
                     then
                        Fail (Bank, OK, Note, Note_Last, "bad sample");
                        return;
                     end if;
                     Copy_Field
                       (Rest (1 .. Rest_Last),
                        Bank.Slot (Bank.Count).Sample,
                        Bank.Slot (Bank.Count).Sample_Last,
                        Fit);
                     Seen_Sample := Fit;
                  elsif Is_Key ("grade") then
                     if Seen_Grade
                       or else (not Same (Rest (1 .. Rest_Last), "exact")
                         and then not Same (Rest (1 .. Rest_Last), "any"))
                     then
                        Fail (Bank, OK, Note, Note_Last, "bad grade");
                        return;
                     end if;
                     Bank.Slot (Bank.Count).Grade_Any :=
                       Same (Rest (1 .. Rest_Last), "any");
                     Seen_Grade := True;
                  else
                     Fail (Bank, OK, Note, Note_Last, "unknown field");
                     return;
                  end if;
                  if Open and then not Is_Key ("task")
                    and then not Is_Key ("end") and then not Fit
                  then
                     Fail (Bank, OK, Note, Note_Last, "field too long");
                     return;
                  end if;
               end;
            end if;
         end;
      end loop;
      if Open then
         Fail (Bank, OK, Note, Note_Last, "unclosed task");
         return;
      end if;
      OK := True;
      Note_Last := 0;
   end Load;

   procedure Fill_Benchmark (Text : out String; Last : out Natural);

   procedure Load_Benchmark
     (Bank      : out Set;
      OK        : out Boolean;
      Note      : out String;
      Note_Last : out Natural)
   is
      Buf  : String (1 .. 12_000);
      Used : Natural;
   begin
      Fill_Benchmark (Buf, Used);
      if Used = 0 then
         Load ("", Bank, OK, Note, Note_Last);
      else
         Load (Buf (1 .. Used), Bank, OK, Note, Note_Last);
      end if;
   end Load_Benchmark;

   procedure Examine (Bank : in out Set) is
   begin
      for I in 1 .. Bank.Count loop
         Bank.Slot (I).Flag_Count := 0;
         Bank.Slot (I).Flags := (others => None);
         Bank.Slot (I).Solvable := False;
         Bank.Slot (I).True_Last := 0;
         Recompute
           (Bank.Slot (I).Kind (1 .. Bank.Slot (I).Kind_Last),
            Bank.Slot (I).Input (1 .. Bank.Slot (I).Input_Last),
            Bank.Slot (I).True_Answer,
            Bank.Slot (I).True_Last,
            Bank.Slot (I).Solvable);
         for Earlier in 1 .. I - 1 loop
            if Same_Text
              (Bank.Slot (I).Kind, Bank.Slot (I).Kind_Last,
               Bank.Slot (Earlier).Kind, Bank.Slot (Earlier).Kind_Last)
              and then Same_Text
                (Bank.Slot (I).Input, Bank.Slot (I).Input_Last,
                 Bank.Slot (Earlier).Input, Bank.Slot (Earlier).Input_Last)
            then
               Add_Flag (Bank.Slot (I), Duplicate);
               exit;
            end if;
         end loop;
         if not Bank.Slot (I).Solvable then
            Add_Flag (Bank.Slot (I), Unsolvable);
         elsif not Same_Text
           (Bank.Slot (I).Expected, Bank.Slot (I).Expected_Last,
            Bank.Slot (I).True_Answer, Bank.Slot (I).True_Last)
         then
            Add_Flag (Bank.Slot (I), Wrong_Expected);
         end if;
         if Leaked (Bank.Slot (I)) then
            Add_Flag (Bank.Slot (I), Answer_Leaked);
         end if;
         if Accepts (Bank.Slot (I), "probe-not-an-answer")
           and then not Same
             (Bank.Slot (I).Expected (1 .. Bank.Slot (I).Expected_Last),
              "probe-not-an-answer")
         then
            Add_Flag (Bank.Slot (I), Accept_Anything);
         elsif Accepts (Bank.Slot (I), "zz-not-the-answer")
           and then not Same
             (Bank.Slot (I).Expected (1 .. Bank.Slot (I).Expected_Last),
              "zz-not-the-answer")
         then
            Add_Flag (Bank.Slot (I), Accept_Anything);
         end if;
      end loop;
      Bank.Examined := True;
   end Examine;

   procedure Score
     (Bank         : Set;
      Drop_Flagged : Boolean;
      Hits         : out Natural;
      Total        : out Natural;
      Accepted     : out Boolean)
   is
   begin
      Hits := 0;
      Total := 0;
      Accepted :=
        Audit_Rule.Score_Accepted
          (Bank.Examined, Drop_Flagged, Flagged (Bank));
      if not Bank.Examined then
         return;
      end if;
      for I in 1 .. Bank.Count loop
         if not (Drop_Flagged and then Bank.Slot (I).Flag_Count > 0) then
            Total := Total + 1;
            if Accepts
              (Bank.Slot (I),
               Bank.Slot (I).Sample (1 .. Bank.Slot (I).Sample_Last))
            then
               Hits := Hits + 1;
            end if;
         end if;
      end loop;
   end Score;

   procedure Rule_Word
     (Rule : Rule_Name;
      Text : out String;
      Last : out Natural)
   is
      OK : Boolean := True;
   begin
      Text := (others => ' ');
      Last := 0;
      case Rule is
         when None =>
            null;
         when Wrong_Expected =>
            Put (Text, Last, "wrong-expected", OK);
         when Unsolvable =>
            Put (Text, Last, "unsolvable", OK);
         when Duplicate =>
            Put (Text, Last, "duplicate", OK);
         when Accept_Anything =>
            Put (Text, Last, "accept-anything", OK);
         when Answer_Leaked =>
            Put (Text, Last, "answer-leaked", OK);
      end case;
      if not OK then
         Last := 0;
      end if;
   end Rule_Word;

   procedure Line_For
     (Bank  : Set;
      Index : Natural;
      Text  : out String;
      Last  : out Natural)
   is
      OK : Boolean := True;
   begin
      Text := (others => ' ');
      Last := 0;
      if not Bank.Examined or else Index < 1 or else Index > Bank.Count then
         return;
      end if;
      Put
        (Text, Last,
         Bank.Slot (Index).Id (1 .. Bank.Slot (Index).Id_Last),
         OK);
      if Bank.Slot (Index).Flag_Count = 0 then
         Put (Text, Last, "  pass", OK);
      else
         Put (Text, Last, "  flag", OK);
         for F in 1 .. Bank.Slot (Index).Flag_Count loop
            declare
               Word : String (1 .. 24);
               WLast : Natural;
            begin
               Rule_Word (Bank.Slot (Index).Flags (F), Word, WLast);
               Put (Text, Last, "  ", OK);
               Put (Text, Last, Word (1 .. WLast), OK);
            end;
         end loop;
      end if;
      if not OK then
         Last := 0;
      end if;
   end Line_For;

   procedure Score_Line
     (Bank         : Set;
      Drop_Flagged : Boolean;
      Text         : out String;
      Last         : out Natural)
   is
      Hits, Total : Natural;
      Accepted    : Boolean;
      OK          : Boolean := True;
   begin
      Text := (others => ' ');
      Last := 0;
      Score (Bank, Drop_Flagged, Hits, Total, Accepted);
      if Drop_Flagged then
         Put (Text, Last, "Cleaned set: ", OK);
      else
         Put (Text, Last, "Full set: ", OK);
      end if;
      Put_Natural (Text, Last, Hits, OK);
      Put (Text, Last, " of ", OK);
      Put_Natural (Text, Last, Total, OK);
      Put (Text, Last, ". ", OK);
      if Accepted then
         Put (Text, Last, "Accepted.", OK);
      elsif not Bank.Examined then
         Put (Text, Last, "Not accepted: not-examined.", OK);
      else
         Put (Text, Last, "Not accepted: audit-flagged.", OK);
      end if;
      if not OK then
         Last := 0;
      end if;
   end Score_Line;

   function Flagged (Bank : Set) return Natural is
      N : Natural := 0;
   begin
      for I in 1 .. Bank.Count loop
         if Bank.Slot (I).Flag_Count > 0 then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Flagged;

   procedure Fill_Benchmark (Text : out String; Last : out Natural) is
      OK : Boolean := True;
   begin
      Text := (others => ' ');
      Last := 0;
      Put (Text, Last,
        "# Tasks about this repository. The planted list is elsewhere." & LF
        & "task xor-00" & LF
        & "kind xor-label" & LF
        & "prompt XOR label of the point with inputs 0 0." & LF
        & "input 0 0" & LF
        & "expected 0" & LF
        & "grade exact" & LF
        & "sample 0" & LF
        & "end" & LF
        & "task xor-01" & LF
        & "kind xor-label" & LF
        & "prompt XOR label of the point with inputs 0 1." & LF
        & "input 0 1" & LF
        & "expected 1" & LF
        & "grade exact" & LF
        & "sample 1" & LF
        & "end" & LF
        & "task xor-10" & LF
        & "kind xor-label" & LF
        & "prompt XOR label of the point with inputs 1 0." & LF
        & "input 1 0" & LF
        & "expected 1" & LF
        & "grade exact" & LF
        & "sample 0" & LF
        & "end" & LF
        & "task xor-11" & LF
        & "kind xor-label" & LF
        & "prompt XOR label of the point with inputs 1 1." & LF
        & "input 1 1" & LF
        & "expected 0" & LF
        & "grade exact" & LF
        & "sample 1" & LF
        & "end" & LF
        & "task xor-count" & LF
        & "kind xor-count" & LF
        & "prompt How many points does the XOR dataset hold." & LF
        & "input" & LF
        & "expected 4" & LF
        & "grade exact" & LF
        & "sample 4" & LF
        & "end" & LF
        & "task weight-roundtrip" & LF
        & "kind weight-status" & LF
        & "prompt Status after reading the hand-written XOR file back." & LF
        & "input roundtrip" & LF
        & "expected loaded" & LF
        & "grade exact" & LF
        & "sample loaded" & LF
        & "end" & LF
        & "task weight-shape-ok" & LF
        & "kind weight-status" & LF
        & "prompt Status of a file whose shape line names 2 8 1." & LF
        & "input shape 2 8 1" & LF
        & "expected loaded" & LF
        & "grade exact" & LF
        & "sample loaded" & LF
        & "end" & LF
        & "task weight-limit" & LF
        & "kind weight-status" & LF
        & "prompt Status when hidden 1 x1 is set to 1000." & LF
        & "input value 1000" & LF
        & "expected loaded" & LF
        & "grade exact" & LF
        & "sample bad-value" & LF
        & "end" & LF
        & "task weight-over" & LF
        & "kind weight-status" & LF
        & "prompt Status when hidden 1 x1 is set to 1001." & LF
        & "input value 1001" & LF
        & "expected bad-value" & LF
        & "grade exact" & LF
        & "sample bad-value" & LF
        & "end" & LF
        & "task weight-bad-shape" & LF
        & "kind weight-status" & LF
        & "prompt Status of a file whose shape line names 2 4 1." & LF
        & "input shape 2 4 1" & LF
        & "expected bad-shape" & LF
        & "grade exact" & LF
        & "sample bad-shape" & LF
        & "end" & LF
        & "task fib-0" & LF
        & "kind fib-answer" & LF
        & "prompt Answer the checker reports for opening index 0." & LF
        & "input 0" & LF
        & "expected 0" & LF
        & "grade exact" & LF
        & "sample 1" & LF
        & "end" & LF
        & "task fib-1" & LF
        & "kind fib-answer" & LF
        & "prompt Answer the checker reports for opening index 1." & LF
        & "input 1" & LF
        & "expected 1" & LF
        & "grade exact" & LF
        & "sample 0" & LF
        & "end" & LF
        & "task fib-6" & LF
        & "kind fib-answer" & LF
        & "prompt Answer the checker reports for opening index 6." & LF
        & "input 6" & LF
        & "expected 8" & LF
        & "grade exact" & LF
        & "sample 8" & LF
        & "end" & LF
        & "task fib-20" & LF
        & "kind fib-answer" & LF
        & "prompt Answer the checker reports for opening index 20." & LF
        & "input 20" & LF
        & "expected 6765" & LF
        & "grade exact" & LF
        & "sample 6765" & LF
        & "end" & LF
        & "task fib-stop-bad" & LF
        & "kind fib-stop" & LF
        & "prompt Stop word of the recorded chain fib-6-bad-sum." & LF
        & "input fib-6-bad-sum" & LF
        & "expected bad-arithmetic" & LF
        & "grade exact" & LF
        & "sample reached-base" & LF
        & "end" & LF
        & "task fib-5-wrong" & LF
        & "kind fib-answer" & LF
        & "prompt Answer the checker reports for opening index 5." & LF
        & "input 5" & LF
        & "expected 9" & LF
        & "grade exact" & LF
        & "sample 9" & LF
        & "end" & LF
        & "task fib-21" & LF
        & "kind fib-answer" & LF
        & "prompt Answer the checker reports for opening index 21." & LF
        & "input 21" & LF
        & "expected 10946" & LF
        & "grade exact" & LF
        & "sample 10946" & LF
        & "end" & LF
        & "task xor-01-copy" & LF
        & "kind xor-label" & LF
        & "prompt Label requested again for inputs 0 1." & LF
        & "input 0 1" & LF
        & "expected 1" & LF
        & "grade exact" & LF
        & "sample 1" & LF
        & "end" & LF
        & "task weight-any" & LF
        & "kind weight-status" & LF
        & "prompt Status when hidden 1 x1 is set to 0." & LF
        & "input value 0" & LF
        & "expected loaded" & LF
        & "grade any" & LF
        & "sample nope" & LF
        & "end" & LF
        & "task fib-4-leaked" & LF
        & "kind fib-answer" & LF
        & "prompt The answer is 3. "
        & "Answer the checker reports for opening index 4." & LF
        & "input 4" & LF
        & "expected 3" & LF
        & "grade exact" & LF
        & "sample 3" & LF
        & "end" & LF,
        OK);
      if not OK then
         Last := 0;
      end if;
   end Fill_Benchmark;

end AI_Amplifier.Audit;
