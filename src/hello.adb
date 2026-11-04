with Ada.Text_IO;
with AI_Amplifier.Version;

procedure Hello
  with SPARK_Mode => Off
is
begin
   Ada.Text_IO.Put_Line
     ("ada-ai-amplifier " & AI_Amplifier.Version.Version_Text);
end Hello;
