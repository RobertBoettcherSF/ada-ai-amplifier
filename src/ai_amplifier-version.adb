package body AI_Amplifier.Version
  with SPARK_Mode
is

   function Version_Length return Integer is (Version_Text'Length);

   --  The body indexes the stamp only with values already in
   --  Version_Text'Range. The WebAssembly link uses the small runtime
   --  from AdaWebPack (memcpy and friends, no exception library), so a
   --  check planted here would fail the link instead of being suppressed.
   function Version_Byte (Index : Integer) return Integer is
      Result : Integer;
   begin
      if Index > Version_Text'Last then
         Result := Character'Pos (Version_Text (Version_Text'Last));
      else
         Result := Character'Pos (Version_Text (Version_Text'First));
         for J in Version_Text'Range loop
            if J = Index then
               Result := Character'Pos (Version_Text (J));
            end if;
         end loop;
      end if;
      return Result;
   end Version_Byte;

end AI_Amplifier.Version;
