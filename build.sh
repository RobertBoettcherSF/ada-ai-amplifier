#!/bin/sh
# Compiles the library bodies (not hello.adb or the native tests) to WebAssembly with
# AdaWebPack 24 / GNAT-LLVM and wasm-ld, the same route as
# murmuration-spark and symmetry-visualizations, then embeds the module
# into site/index.html.
#
# Runtime checks stay on (-gnata, and no -gnatp). Nothing here is proved,
# so checks are not stripped. This runtime cannot propagate an exception.
# tools/wasm-checks.c supplies the two symbols a failed check calls, and
# those trap the module. The link does not pass --allow-undefined. The
# native test is where a shape mismatch raises.
set -e
cd "$(dirname "$0")"
# The locked panel is this build's spec run. The generated body
# is compiled below in place of src/ai_amplifier-locked.adb.
./tools/run-specs.sh
T=$PWD/toolchain/usr
[ -x "$T/bin/llvm-gcc" ] || { echo "Run tools/get-toolchain.sh first"; exit 1; }
export LD_LIBRARY_PATH="$PWD/toolchain/lib"
LD=$(command -v wasm-ld || ls /usr/bin/wasm-ld-* | tail -1)
rm -rf obj/wasm && mkdir -p obj/wasm
cd obj/wasm
for F in ../../src/*.adb; do
  case $(basename "$F") in
    hello.adb|tensors_test.adb|mlp_test.adb|attention_test.adb|recurse_test.adb|recurse_cli.adb|traces_test.adb|traces_cli.adb|audit_test.adb|audit_cli.adb|reward_test.adb|reward_cli.adb|harness_test.adb|harness_cli.adb|steps_test.adb|steps_cli.adb|ai_amplifier-locked.adb) continue ;;
  esac
  # -gnatw.X: this runtime forbids exception propagation, and the
  # compiler warns that a check would call Last_Chance_Handler. The
  # same switch is in the native Alire profile. Checks stay compiled
  # in; -gnatp is not used.
  "$T/bin/llvm-gcc" -c --target=wasm32 -O2 -gnat2012 -gnata -gnatwa -gnatw.X -gnatwe \
    --RTS="$T/lib/rts-native" -I../../src "$F"
done
ar x "$T/lib/rts-native/adalib/libgnat.a" s-memcop.o s-memmov.o s-memset.o
#  A failed Pre or length check cannot propagate on this runtime.
#  tools/wasm-checks.c traps instead. The native test is where a
#  mismatch raises. The link does not pass --allow-undefined.
"$T/bin/llvm-gcc" -c --target=wasm32 -O2 \
  -o wasm_checks.o "$PWD/../../tools/wasm-checks.c"
#  The locked body is the one tools/run-specs.sh just wrote.
#  src/ai_amplifier-locked.adb is the placeholder, not this link.
[ -f ../../obj/gen/ai_amplifier-locked.adb ] || {
  echo "obj/gen/ai_amplifier-locked.adb is missing"; exit 1; }
"$T/bin/llvm-gcc" -c --target=wasm32 -O2 -gnat2012 -gnata -gnatwa -gnatw.X -gnatwe \
  --RTS="$T/lib/rts-native" -I../../src \
  -o ai_amplifier-locked.o ../../obj/gen/ai_amplifier-locked.adb
"$LD" --no-entry --strip-all \
  --export=aa_version_length --export=aa_version_byte \
  --export=aa_splash_reset --export=aa_splash_tick \
  --export=aa_step --export=aa_count --export=aa_get \
  --export=aa_set_m --export=aa_get_m \
  --export=aa_set_v --export=aa_get_v \
  --export=aa_tensor_run \
  --export=aa_product --export=aa_softmax \
  --export=aa_lrelu_set --export=aa_lrelu_in \
  --export=aa_lrelu_run --export=aa_lrelu_out --export=aa_lrelu_slope \
  --export=aa_mlp_reset --export=aa_mlp_set_rate --export=aa_mlp_rate \
  --export=aa_mlp_train --export=aa_mlp_epoch --export=aa_mlp_loss \
  --export=aa_mlp_predict --export=aa_mlp_count \
  --export=aa_mlp_x --export=aa_mlp_y --export=aa_mlp_label \
  --export=aa_mlp_lo --export=aa_mlp_hi --export=aa_mlp_grid_n \
  --export=aa_mlp_fill --export=aa_mlp_cell \
  --export=aa_mlp_curve_n --export=aa_mlp_curve --export=aa_mlp_kind \
  --export=aa_w_limit --export=aa_w_span --export=aa_w_count \
  --export=aa_w_get --export=aa_w_set \
  --export=aa_w_name_len --export=aa_w_name_byte \
  --export=aa_w_len --export=aa_w_byte \
  --export=aa_w_clear --export=aa_w_push --export=aa_w_load \
  --export=aa_w_hand --export=aa_w_trained --export=aa_w_preset \
  --export=aa_w_note_len --export=aa_w_note_byte \
  --export=aa_speed_prepare --export=aa_speed_execute \
  --export=aa_speed_finish --export=aa_speed_steps \
  --export=aa_speed_repeats --export=aa_speed_us \
  --export=aa_speed_loss --export=aa_speed_answer \
  --export=aa_speed_counted --export=aa_speed_reason \
  --export=aa_speed_published_steps \
  --export=aa_speed_published_native_us \
  --export=aa_speed_published_wasm_us \
  --export=aa_speed_len --export=aa_speed_byte \
  --export=aa_speed_describe \
  --export=aa_bpe_clear --export=aa_bpe_push --export=aa_bpe_corpus \
  --export=aa_attn_run --export=aa_attn_tokens --export=aa_attn_id \
  --export=aa_attn_piece_len --export=aa_attn_piece_byte \
  --export=aa_attn_vocab --export=aa_attn_merges --export=aa_attn_used \
  --export=aa_attn_weight --export=aa_attn_dropped --export=aa_attn_bytes \
  --export=aa_rec_chains --export=aa_rec_max_index --export=aa_rec_select \
  --export=aa_rec_name_len --export=aa_rec_name_byte \
  --export=aa_rec_states --export=aa_rec_line_len --export=aa_rec_line_byte \
  --export=aa_rec_mark --export=aa_rec_parsed \
  --export=aa_rec_index --export=aa_rec_minus --export=aa_rec_current \
  --export=aa_rec_stop --export=aa_rec_stop_len --export=aa_rec_stop_byte \
  --export=aa_rec_stop_at --export=aa_rec_accepted --export=aa_rec_answer \
  --export=aa_rec_note_len --export=aa_rec_note_byte \
  --export=aa_tr_count --export=aa_tr_select \
  --export=aa_tr_name_len --export=aa_tr_name_byte \
  --export=aa_tr_steps --export=aa_tr_line_len --export=aa_tr_line_byte \
  --export=aa_tr_wrong --export=aa_tr_menu \
  --export=aa_tr_menu_len --export=aa_tr_menu_byte \
  --export=aa_tr_propose --export=aa_tr_verdict --export=aa_tr_reason \
  --export=aa_tr_reason_len --export=aa_tr_reason_byte \
  --export=aa_tr_report_len --export=aa_tr_report_byte \
  --export=aa_tr_good_len --export=aa_tr_good_byte \
  --export=aa_tr_state_len --export=aa_tr_state_byte \
  --export=aa_au_run --export=aa_au_count --export=aa_au_flagged \
  --export=aa_au_mark --export=aa_au_line_len --export=aa_au_line_byte \
  --export=aa_au_stat_len --export=aa_au_stat_byte \
  --export=aa_au_full_len --export=aa_au_full_byte \
  --export=aa_au_clean_len --export=aa_au_clean_byte \
  --export=aa_rw_run --export=aa_rw_count --export=aa_rw_cols \
  --export=aa_rw_col_len --export=aa_rw_col_byte --export=aa_rw_mark \
  --export=aa_rw_tally_len --export=aa_rw_tally_byte \
  --export=aa_rw_stat_len --export=aa_rw_stat_byte \
  --export=aa_rw_steps \
  --export=aa_rw_flawed_proxy --export=aa_rw_flawed_real \
  --export=aa_rw_flawed_holds \
  --export=aa_rw_real_proxy --export=aa_rw_real_score \
  --export=aa_rw_real_holds \
  --export=aa_rw_flawed_end_len --export=aa_rw_flawed_end_byte \
  --export=aa_rw_real_end_len --export=aa_rw_real_end_byte \
  --export=aa_hn_run --export=aa_hn_harnesses --export=aa_hn_tasks \
  --export=aa_hn_cols --export=aa_hn_cell_len --export=aa_hn_cell_byte \
  --export=aa_hn_task_len --export=aa_hn_task_byte \
  --export=aa_hn_select --export=aa_hn_logs \
  --export=aa_hn_log_len --export=aa_hn_log_byte \
  --export=aa_hn_solved \
  --export=aa_hn_result_len --export=aa_hn_result_byte \
  --export=aa_hn_stat_len --export=aa_hn_stat_byte \
  --export=aa_st_run --export=aa_st_count \
  --export=aa_st_name_len --export=aa_st_name_byte \
  --export=aa_st_answer_len --export=aa_st_answer_byte \
  --export=aa_st_steps_len --export=aa_st_steps_byte \
  --export=aa_st_select --export=aa_st_which \
  --export=aa_st_rows --export=aa_st_row_len --export=aa_st_row_byte \
  --export=aa_st_bad --export=aa_st_rule_len --export=aa_st_rule_byte \
  --export=aa_st_stat_len --export=aa_st_stat_byte \
  --export=aa_lk_count --export=aa_lk_item \
  --export=aa_lk_name_len --export=aa_lk_name_byte \
  --export=aa_lk_text_len --export=aa_lk_text_byte \
  --export=aa_lk_fp_len --export=aa_lk_fp_byte \
  --export=aa_lk_status_len --export=aa_lk_status_byte \
  --export=aa_lk_stat_len --export=aa_lk_stat_byte \
  -z stack-size=2097152 --initial-memory=16777216 \
  -o ai_amplifier.wasm *.o
cd ../..
node tools/wasm-smoke.mjs
python3 - <<'PY'
import base64
import pathlib
wasm = pathlib.Path("obj/wasm/ai_amplifier.wasm").read_bytes()
token = "__WASM_BASE64__"
html = pathlib.Path("web/template.html").read_text()
if html.count(token) != 1:
    raise SystemExit("web/template.html must contain __WASM_BASE64__ once")
out = html.replace(token, base64.b64encode(wasm).decode("ascii"), 1)
site = pathlib.Path("site")
site.mkdir(exist_ok=True)
(site / "index.html").write_text(out)
(site / "version.txt").write_text(pathlib.Path("version.txt").read_text())
if token in out:
    raise SystemExit("placeholder survived into site/index.html")
print(f"Wrote site/index.html ({len(out)} bytes)")
PY
echo "Built obj/wasm/ai_amplifier.wasm ($(wc -c < obj/wasm/ai_amplifier.wasm) bytes)"
