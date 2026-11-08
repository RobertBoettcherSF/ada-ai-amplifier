--  Which built-in solutions were planted, and the rule the
--  first bad step breaks.
--
--  AI_Amplifier.Steps does not with this unit. The checker
--  never reads these lines. The native test compares them
--  with the grades Grade produces on its own. The page does
--  not export them.
--
--  A line is: name, flaw, the step row (0 when none), the
--  rule word. none is a solution the checker should accept.
--  wrong means the answer itself fails. The other flaws keep
--  the right answer and break one step.
package AI_Amplifier.Steps.Manifest
  with SPARK_Mode => Off
is

   Text : constant String :=
     "xor-00-right none 0 none" & Character'Val (10)
     & "xor-10-cancel cancel 2 bad-value" & Character'Val (10)
     & "xor-11-skip skip 2 skipped-step" & Character'Val (10)
     & "xor-00-guess guess 1 guessed-first" & Character'Val (10)
     & "xor-01-wrong wrong 8 wrong-answer" & Character'Val (10)
     & "train-right none 0 none" & Character'Val (10)
     & "train-cancel cancel 6 bad-value" & Character'Val (10)
     & "fib-6-right none 0 none" & Character'Val (10)
     & "fib-5-cancel cancel 2 bad-arithmetic" & Character'Val (10)
     & "fib-4-skip skip 2 not-toward-base" & Character'Val (10)
     & "sum-right none 0 none" & Character'Val (10)
     & "sum-guess guess 1 guessed-first" & Character'Val (10);

end AI_Amplifier.Steps.Manifest;
