with Ada.Text_IO;
with AI_Amplifier.Splash;
with AI_Amplifier.Version;

procedure Hello
  with SPARK_Mode => Off
is
begin
   --  Pull the splash unit into the native build and fail the stamp
   --  check below if the graph is not the one the page draws.
   AI_Amplifier.Splash.Reset;
   if AI_Amplifier.Splash.Count (0) /= 6
     or else AI_Amplifier.Splash.Get (0, 1, 0) /= 180
   then
      Ada.Text_IO.Put_Line ("splash");
   end if;
   AI_Amplifier.Splash.Tick;
   Ada.Text_IO.Put_Line
     ("ada-ai-amplifier " & AI_Amplifier.Version.Version_Text);
end Hello;
