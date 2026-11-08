package body AI_Amplifier.Version
  with SPARK_Mode
is

   function Version_Length return Integer is (Version_Text'Length);

   --  The body indexes the stamp only with values already in
   --  Version_Text'Range. The WebAssembly link has no secondary
   --  stack, so this function returns an Integer, not a slice.
   function Version_Byte (Index : Integer) return Integer is
      Result : Integer :=
        Character'Pos (Version_Text (Version_Text'First));
      J : Integer := Version_Text'First;
   begin
      if Index > Version_Text'Last then
         return Character'Pos (Version_Text (Version_Text'Last));
      end if;
      while J <= Version_Text'Last loop
         pragma Loop_Variant (Increases => J);
         pragma Loop_Invariant (J >= Version_Text'First);
         pragma Loop_Invariant (J <= Version_Text'Last + 1);
         pragma Loop_Invariant
           (if Index in Version_Text'First .. J - 1 then
              Result = Character'Pos (Version_Text (Index))
            else
              Result = Character'Pos (Version_Text (Version_Text'First)));
         if J = Index then
            Result := Character'Pos (Version_Text (J));
         end if;
         J := J + 1;
      end loop;
      return Result;
   end Version_Byte;

end AI_Amplifier.Version;
