--  Item 12. The benchmark the auditor scores: 5 flags,
--  full set 14 of 20 refused, cleaned set 9 of 15 accepted.
--  The two sentences are the ones audit_test requires.
with Ada.Text_IO;
with AI_Amplifier.Audit;

procedure Item_12
  with SPARK_Mode => Off
is
   package A renames AI_Amplifier.Audit;

   Bank      : A.Set;
   OK        : Boolean;
   Note      : String (1 .. A.Max_Note);
   Note_Last : Natural;
   Hits      : Natural;
   Total     : Natural;
   Accepted  : Boolean;
   Line      : String (1 .. A.Max_Line);
   Last      : Natural;
begin
   A.Load_Benchmark (Bank, OK, Note, Note_Last);
   pragma Assert (OK);
   pragma Assert (Bank.Count = 20);
   A.Examine (Bank);
   pragma Assert (A.Flagged (Bank) = 5);
   A.Score (Bank, False, Hits, Total, Accepted);
   pragma Assert (Hits = 14);
   pragma Assert (Total = 20);
   pragma Assert (Accepted = False);
   A.Score_Line (Bank, False, Line, Last);
   pragma Assert
     (Line (1 .. Last) =
        "Full set: 14 of 20. Not accepted: audit-flagged.");
   A.Score (Bank, True, Hits, Total, Accepted);
   pragma Assert (Hits = 9);
   pragma Assert (Total = 15);
   pragma Assert (Accepted);
   A.Score_Line (Bank, True, Line, Last);
   pragma Assert (Line (1 .. Last) = "Cleaned set: 9 of 15. Accepted.");
   Ada.Text_IO.Put_Line ("item 12 pass");
end Item_12;
