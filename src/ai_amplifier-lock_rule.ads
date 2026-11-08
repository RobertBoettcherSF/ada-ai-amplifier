--  Comparing two fingerprints, and a set of those comparisons.
--
--  SPARK. Hashing a file is not in this unit. A match is
--  every corresponding hex digit. It does not say the spec
--  is the right statement. The result is a Boolean, not a
--  slice: the wasm link has no secondary stack. The body
--  compares one character at a time. A slice compare would
--  pull in memcmp, which this link does not provide.
package AI_Amplifier.Lock_Rule
  with SPARK_Mode
is

   Hex_Length : constant := 64;

   subtype Hex_Index is Positive range 1 .. Hex_Length;

   type Hex is array (Hex_Index) of Character;

   Max_Specs : constant := 19;

   subtype Spec_Index is Positive range 1 .. Max_Specs;

   type Flag_List is array (Spec_Index) of Boolean;

   function Digits_Match (Left, Right : Hex) return Boolean
     with Post =>
       Digits_Match'Result =
         (for all I in Hex_Index => Left (I) = Right (I));

   --  Count is how many specs were compared. Flags past
   --  Count are ignored. The set holds only when Count is
   --  positive and every compared flag is true.
   function All_Match (Flags : Flag_List; Count : Natural) return Boolean
     with Pre => Count <= Max_Specs,
          Post =>
            All_Match'Result =
              (Count > 0
               and then
                 (for all I in Spec_Index =>
                    (if I <= Count then Flags (I) else True)));

end AI_Amplifier.Lock_Rule;
