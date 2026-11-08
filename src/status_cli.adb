--  Print the checking status computed from this build.
--  With no arguments the logs are the ones tools/check-status.sh
--  writes. Five arguments replace those paths, in the same
--  order Load takes them. The text is the STATUS file.
with Ada.Command_Line;
with Ada.Text_IO;
with AI_Amplifier.Status;

procedure Status_Cli
  with SPARK_Mode => Off
is
begin
   if Ada.Command_Line.Argument_Count = 0 then
      AI_Amplifier.Status.Load
        ("proof/gnatprove.out",
         "obj/gen/tests.out",
         "obj/gen/specs.out",
         "obj/gen/recheck-report.txt",
         "specs");
   elsif Ada.Command_Line.Argument_Count = 5 then
      AI_Amplifier.Status.Load
        (Ada.Command_Line.Argument (1),
         Ada.Command_Line.Argument (2),
         Ada.Command_Line.Argument (3),
         Ada.Command_Line.Argument (4),
         Ada.Command_Line.Argument (5));
   else
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "usage: status_cli [prove tests specs recheck specdir]");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;
   if not AI_Amplifier.Status.Ready then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         AI_Amplifier.Status.Item_Evidence (1));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;
   AI_Amplifier.Status.Put_Report;
end Status_Cli;
