with Ada.Command_Line;
with Ada.Text_IO;
with AI_Amplifier.Reward;

--  Native only. build.sh does not compile this into the page.
--  With no arguments it prints the submission table and the last
--  point of each search. With "flawed" or "real" it prints that
--  search one step per line. A score that fails the real check
--  is printed and marked rejected.
procedure Reward_Cli
  with SPARK_Mode => Off
is
   package R renames AI_Amplifier.Reward;
   package IO renames Ada.Text_IO;

   procedure Put_Buf (Buf : String; Last : Natural) is
   begin
      if Last >= 1 then
         IO.Put_Line (Buf (Buf'First .. Buf'First + Last - 1));
      end if;
   end Put_Buf;

   procedure Put_Table (Bank : R.Set) is
      Line : String (1 .. R.Max_Line);
      Last : Natural;
   begin
      R.Header_Line (Line, Last);
      Put_Buf (Line, Last);
      for I in 1 .. Bank.Count loop
         R.Line_For (Bank, I, Line, Last);
         Put_Buf (Line, Last);
      end loop;
      R.Tally_Line (Bank, Line, Last);
      Put_Buf (Line, Last);
      R.Stat_Line (Bank, Line, Last);
      Put_Buf (Line, Last);
   end Put_Table;

   procedure Put_End (Aim : String; Item : R.Trace) is
      Line : String (1 .. R.Max_Line);
      Last : Natural;
   begin
      IO.Put (Aim);
      IO.Put (": ");
      R.End_Line (Item, Line, Last);
      Put_Buf (Line, Last);
   end Put_End;

   procedure Put_Curve (Item : R.Trace) is
   begin
      for I in 1 .. Item.Points loop
         IO.Put ("step");
         IO.Put (Natural'Image (I - 1));
         IO.Put ("  proxy ");
         IO.Put (R.Score_Text (Item.Proxy (I)));
         IO.Put ("  real ");
         IO.Put (R.Score_Text (Item.Real_Score (I)));
         IO.Put ("  ");
         if Item.Passed (I) then
            IO.Put_Line ("passes");
         else
            IO.Put_Line ("fails");
         end if;
      end loop;
   end Put_Curve;

   function Arg return String is
   begin
      if Ada.Command_Line.Argument_Count = 0 then
         return "";
      end if;
      return Ada.Command_Line.Argument (1);
   end Arg;

   Bank   : R.Set;
   Flawed : R.Trace;
   Real   : R.Trace;
   Which  : constant String := Arg;
begin
   if Ada.Command_Line.Argument_Count > 1
     or else (Which /= "" and then Which /= "flawed"
              and then Which /= "real")
   then
      IO.Put_Line ("usage: reward_cli [flawed|real]");
      Ada.Command_Line.Set_Exit_Status (1);
      return;
   end if;
   R.Build (Bank);
   Put_Table (Bank);
   if Which = "" or else Which = "flawed" then
      R.Search (R.Flawed_Aim, Flawed);
   end if;
   if Which = "" or else Which = "real" then
      R.Search (R.Real_Aim, Real);
   end if;
   if Which = "" then
      Put_End ("flawed aim", Flawed);
      Put_End ("real aim", Real);
   elsif Which = "flawed" then
      Put_Curve (Flawed);
      Put_End ("flawed aim", Flawed);
   else
      Put_Curve (Real);
      Put_End ("real aim", Real);
   end if;
end Reward_Cli;
