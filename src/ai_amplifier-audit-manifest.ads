--  Which built-in tasks were planted, and the rule each one breaks.
--
--  AI_Amplifier.Audit does not with this unit. The auditor never
--  reads these lines. The native test compares them with the flags
--  Examine produces on its own. The page does not export them.
package AI_Amplifier.Audit.Manifest
  with SPARK_Mode => Off
is

   Text : constant String :=
     "fib-5-wrong wrong-expected" & Character'Val (10)
     & "fib-21 unsolvable" & Character'Val (10)
     & "xor-01-copy duplicate" & Character'Val (10)
     & "weight-any accept-anything" & Character'Val (10)
     & "fib-4-leaked answer-leaked" & Character'Val (10);

end AI_Amplifier.Audit.Manifest;
