--  Visible build stamp for this tree.
--  Alire's crate version is the same text without the leading "v".
package AI_Amplifier.Version
  with SPARK_Mode
is

   Version_Text : constant String := "v0.15.0-steps";

   --  Both functions are exported for the WebAssembly build.
   --  Out-of-range Index yields the nearest end byte (first or last).
   function Version_Length return Integer
     with Global => null,
          Export, Convention => C, External_Name => "aa_version_length";

   function Version_Byte (Index : Integer) return Integer
     with Global => null,
          Export, Convention => C, External_Name => "aa_version_byte";

end AI_Amplifier.Version;
