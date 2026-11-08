--  Visible build stamp for this tree.
--  Alire's crate version is the same text without the leading "v".
package AI_Amplifier.Version
  with SPARK_Mode
is

   Version_Text : constant String := "v0.22.0-askcheck";

   --  Both functions are exported for the WebAssembly build.
   --  Out-of-range Index yields the nearest end byte (first or last).
   --  The posts are the contracts item 1's own proof run discharges.
   function Version_Length return Integer
     with Global => null,
          Post =>
            Version_Length'Result = Version_Text'Length
            and then Version_Length'Result >= 1,
          Export, Convention => C, External_Name => "aa_version_length";

   function Version_Byte (Index : Integer) return Integer
     with Global => null,
          Post =>
            (if Index > Version_Text'Last then
               Version_Byte'Result =
                 Character'Pos (Version_Text (Version_Text'Last))
             elsif Index < Version_Text'First then
               Version_Byte'Result =
                 Character'Pos (Version_Text (Version_Text'First))
             else
               Version_Byte'Result =
                 Character'Pos (Version_Text (Index)))
            and then
              (if Index = Version_Text'First then
                 Version_Byte'Result = Character'Pos ('v')),
          Export, Convention => C, External_Name => "aa_version_byte";

end AI_Amplifier.Version;
