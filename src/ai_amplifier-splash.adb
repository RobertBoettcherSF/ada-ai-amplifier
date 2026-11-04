package body AI_Amplifier.Splash
  with SPARK_Mode => Off
is

   --  Modular so the picture's arithmetic wraps instead of raising.
   --  The WebAssembly link does not include the exception runtime.
   type W is mod 2 ** 31;

   Step : W := 0;

   function To_Int (V : W) return Integer is (Integer (V));

   function Lerp (A, B, T : W) return W is
   begin
      if T >= 1000 then
         return B;
      elsif B >= A then
         return A + (B - A) * T / 1000;
      else
         return A - (A - B) * T / 1000;
      end if;
   end Lerp;

   function Node_Coord (N : Integer; Axis : Integer) return W is
   begin
      if Axis = 0 then
         case N is
            when 1 | 2 | 3 =>
               return 180;
            when 4 | 5 =>
               return 500;
            when 6 =>
               return 840;
            when others =>
               return 0;
         end case;
      else
         case N is
            when 1 =>
               return 300;
            when 2 =>
               return 520;
            when 3 =>
               return 740;
            when 4 =>
               return 380;
            when 5 =>
               return 660;
            when 6 =>
               return 520;
            when others =>
               return 0;
         end case;
      end if;
   end Node_Coord;

   --  Edges of a 3-2-1 graph: inputs 1..3, hidden 4..5, output 6.
   function Edge_Node (Edge : Integer; Head : Boolean) return Integer is
   begin
      if not Head then
         case Edge is
            when 1 | 2 =>
               return 1;
            when 3 | 4 =>
               return 2;
            when 5 | 6 =>
               return 3;
            when 7 =>
               return 4;
            when 8 =>
               return 5;
            when others =>
               return 0;
         end case;
      else
         case Edge is
            when 1 | 3 | 5 =>
               return 4;
            when 2 | 4 | 6 =>
               return 5;
            when 7 | 8 =>
               return 6;
            when others =>
               return 0;
         end case;
      end if;
   end Edge_Node;

   function Mote_Start (M : Integer; Axis : Integer) return W is
   begin
      if Axis = 0 then
         case M is
            when 1 | 2 | 3 =>
               return 30;
            when 4 | 5 | 6 =>
               return 970;
            when 7 | 9 =>
               return 350;
            when 8 =>
               return 650;
            when 10 =>
               return 750;
            when 11 =>
               return 90;
            when 12 =>
               return 910;
            when others =>
               return 0;
         end case;
      else
         case M is
            when 1 | 4 =>
               return 40;
            when 2 | 5 =>
               return 960;
            when 3 | 6 =>
               return 500;
            when 7 | 8 =>
               return 30;
            when 9 | 10 =>
               return 970;
            when 11 =>
               return 180;
            when 12 =>
               return 820;
            when others =>
               return 0;
         end case;
      end if;
   end Mote_Start;

   function Mote_Input (M : Integer) return Integer is
      R : constant W := W (M) mod 3;
   begin
      if R = 0 then
         return 3;
      else
         return To_Int (R);
      end if;
   end Mote_Input;

   function Mote_Hidden (M : Integer) return Integer is
   begin
      if W (M) mod 2 = 0 then
         return 5;
      else
         return 4;
      end if;
   end Mote_Hidden;

   function Node_Pulse (N : Integer) return Integer is
      Off : W;
      Q   : W;
   begin
      case N is
         when 1 =>
            Off := 0;
         when 2 =>
            Off := 15;
         when 3 =>
            Off := 30;
         when 4 =>
            Off := 70;
         when 5 =>
            Off := 85;
         when 6 =>
            Off := 120;
         when others =>
            return 0;
      end case;
      Q := (Step / 2 + Off) mod 160;
      if Q < 36 then
         return To_Int (255 - Q * 5);
      else
         return 70;
      end if;
   end Node_Pulse;

   function Edge_Weight (Edge : Integer) return Integer is
      Q : W;
   begin
      if Edge < 1 or else Edge > 8 then
         return 0;
      end if;
      Q := (Step / 2 + W (Edge) * 23) mod 200;
      if Q > 100 then
         Q := 200 - Q;
      end if;
      return To_Int (50 + Q * 2);
   end Edge_Weight;

   function Bead_Coord
     (Edge, Which : Integer; Trail : Boolean; Axis : Integer) return W
   is
      E : constant W := W (Edge);
      T : W;
      A : W;
      B : W;
   begin
      --  Mod 1000 before the multiply so the bead keeps a steady
      --  speed after Step grows past 2**31.
      T := ((Step mod 1000) * (3 + (E mod 3))
            + W (Which) * 500 + E * 37) mod 1000;
      if Trail then
         if T >= 80 then
            T := T - 80;
         else
            T := T + 920;
         end if;
      end if;
      A := Node_Coord (Edge_Node (Edge, False), Axis);
      B := Node_Coord (Edge_Node (Edge, True), Axis);
      return Lerp (A, B, T);
   end Bead_Coord;

   function Mote_Coord
     (M : Integer; Trail : Boolean; Axis : Integer) return W
   is
      T      : W := ((Step mod 1000) * 3 + W (M) * 83) mod 1000;
      Local  : W;
      A      : W;
      B      : W;
      Hidden : Integer;
   begin
      if Trail then
         if T >= 50 then
            T := T - 50;
         else
            T := 0;
         end if;
      end if;
      if T < 400 then
         A := Mote_Start (M, Axis);
         B := Node_Coord (Mote_Input (M), Axis);
         Local := T * 1000 / 400;
      elsif T < 700 then
         Hidden := Mote_Hidden (M);
         A := Node_Coord (Mote_Input (M), Axis);
         B := Node_Coord (Hidden, Axis);
         Local := (T - 400) * 1000 / 300;
      else
         Hidden := Mote_Hidden (M);
         A := Node_Coord (Hidden, Axis);
         B := Node_Coord (6, Axis);
         Local := (T - 700) * 1000 / 300;
      end if;
      return Lerp (A, B, Local);
   end Mote_Coord;

   function Slot_Edge (Index : Integer) return Integer is
      S : constant W := W (Index) - 1;
   begin
      return To_Int (S / 4 + 1);
   end Slot_Edge;

   function Slot_Which (Index : Integer) return Integer is
      S : constant W := W (Index) - 1;
   begin
      return To_Int ((S mod 4) / 2);
   end Slot_Which;

   function Slot_Trail (Index : Integer) return Boolean is
      S : constant W := W (Index) - 1;
   begin
      return S mod 2 = 1;
   end Slot_Trail;

   function Mote_Of (Index : Integer) return Integer is
      S : constant W := W (Index) - 33;
   begin
      return To_Int (S / 2 + 1);
   end Mote_Of;

   function Mote_Trail (Index : Integer) return Boolean is
      S : constant W := W (Index) - 33;
   begin
      return S mod 2 = 1;
   end Mote_Trail;
   function Node_Field (Index, Field : Integer) return Integer is
   begin
      if Index < 1 or else Index > 6 then
         return 0;
      end if;
      if Field = 0 or else Field = 1 then
         return To_Int (Node_Coord (Index, Field));
      elsif Field = 2 then
         return Node_Pulse (Index);
      else
         return 0;
      end if;
   end Node_Field;

   function Edge_Field (Index, Field : Integer) return Integer is
      N : Integer;
   begin
      if Index < 1 or else Index > 8 then
         return 0;
      end if;
      if Field = 4 then
         return Edge_Weight (Index);
      elsif Field = 0 or else Field = 1 then
         N := Edge_Node (Index, False);
         return To_Int (Node_Coord (N, Field));
      elsif Field = 2 or else Field = 3 then
         N := Edge_Node (Index, True);
         return To_Int (Node_Coord (N, Field - 2));
      else
         return 0;
      end if;
   end Edge_Field;

   function Point_Bright (Trail : Boolean) return Integer is
   begin
      if Trail then
         return 110;
      else
         return 255;
      end if;
   end Point_Bright;

   function Point_Size (Trail : Boolean) return Integer is
   begin
      if Trail then
         return 2;
      else
         return 3;
      end if;
   end Point_Size;

   function Point_Field (Index, Field : Integer) return Integer is
      Trail : Boolean;
   begin
      if Index < 1 or else Index > 56 then
         return 0;
      end if;
      if Index <= 32 then
         Trail := Slot_Trail (Index);
         if Field = 0 or else Field = 1 then
            return To_Int
              (Bead_Coord
                 (Slot_Edge (Index), Slot_Which (Index), Trail, Field));
         elsif Field = 2 then
            return Point_Bright (Trail);
         elsif Field = 3 then
            return Point_Size (Trail);
         else
            return 0;
         end if;
      else
         Trail := Mote_Trail (Index);
         if Field = 0 or else Field = 1 then
            return To_Int (Mote_Coord (Mote_Of (Index), Trail, Field));
         elsif Field = 2 then
            return Point_Bright (Trail);
         elsif Field = 3 then
            return Point_Size (Trail);
         else
            return 0;
         end if;
      end if;
   end Point_Field;

   procedure Reset is
   begin
      Step := 0;
   end Reset;

   procedure Tick is
   begin
      Step := Step + 1;
   end Tick;

   function Frame return Integer is (To_Int (Step));

   function Count (Kind : Integer) return Integer is
   begin
      if Kind = 0 then
         return 6;
      elsif Kind = 1 then
         return 8;
      elsif Kind = 2 then
         return 56;
      else
         return 0;
      end if;
   end Count;

   function Get (Kind, Index, Field : Integer) return Integer is
   begin
      if Kind = 0 then
         return Node_Field (Index, Field);
      elsif Kind = 1 then
         return Edge_Field (Index, Field);
      elsif Kind = 2 then
         return Point_Field (Index, Field);
      else
         return 0;
      end if;
   end Get;

end AI_Amplifier.Splash;
