/*
 * The AdaWebPack runtime does not propagate exceptions. A failed
 * check in the wasm build calls one of these and the module traps.
 * The native build does not link this file: there, the same check
 * raises Assertion_Error or Constraint_Error inside tensors_test.
 * Neither function is an import, so the module still has none.
 */
void __gnat_last_chance_handler (int file, int line)
{
  (void) file;
  (void) line;
  __builtin_trap ();
}

void system__assertions__raise_assert_failure (int msg, int file, int line)
{
  (void) msg;
  (void) file;
  (void) line;
  __builtin_trap ();
}
