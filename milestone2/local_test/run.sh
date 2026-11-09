#!/usr/bin/env bash
# Test cuc bo bang Icarus Verilog 12 (khong dung toi makefile / testbench cua TA).
#   ./run.sh                 seed 1, memory map C program
#   ./run.sh 7 isa           seed 7, memory map ISA test
#   ./run.sh regress         20 seed x 2 memory map
#
# Can simulator theo dung thu tu region IEEE 1800 (Icarus, Xcelium): testbench lay
# mau ngay tai canh len. Verilator khong dung duoc cho testbench nay.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/../rtl"
BUILD="$HERE/build"
mkdir -p "$BUILD"

build() {   # $1 = map
  local dstart aw
  if [ "$1" = isa ]; then dstart="32'h84000000"; aw=26; else dstart="32'h80080000"; aw=19; fi
  iverilog -g2012 -s tb_milestone2_local \
    -Ptb_milestone2_local.DMEM_START="$dstart" -Ptb_milestone2_local.IMEM_AW=$aw \
    -o "$BUILD/sim_$1.vvp" "$SRC"/*.sv "$HERE/milestone2_mock.sv" "$HERE/tb_milestone2_local.sv" \
    2>&1 | grep -v "sorry:" || true
  test -f "$BUILD/sim_$1.vvp"
}

run() {     # $1 = seed, $2 = map
  local out
  python3 -I "$HERE/gen_test.py" --seed "$1" --map "$2" --out "$BUILD" > /dev/null
  out="$(cd "$BUILD" && vvp -n "sim_$2.vvp" 2>&1 | grep -v "Not enough words")"
  echo "$out" | grep -E "PASSED|FAILED"
  echo "$out" | grep -m 3 "ERROR" || true      # vai loi dau tien (neu co)
}

if [ "$1" = regress ]; then
  for m in c isa; do
    build $m
    for s in $(seq 1 20); do printf "map %-3s seed %2d: " $m $s; run $s $m; done
  done
else
  m="${2:-c}"; build "$m"; run "${1:-1}" "$m"
fi
