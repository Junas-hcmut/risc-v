#!/usr/bin/env python3
"""Sinh chuong trinh test RV32I + trace mong doi cho tb_milestone2_local.

  python3 gen_test.py [--seed N] [--random N] [--map c|isa] [--out DIR]

Tao ra:
  prog_1b.hex : chuong trinh, moi dong 1 byte (IMEM_FORMAT=1B)
  trace.hex   : moi dong "PC VLD WE RD DATA" cho tung lenh duoc thuc thi

Memory map (Table 10): IMEM bat dau 0x8000_0000; DMEM 64 KiB tai 0x8008_0000 (c)
hoac 0x8400_0000 (isa). Ngoai DMEM: store bi bo qua, load tra 0 (giong dmem.sv).
DMEM truy cap theo word + byte mask, nen test chi dung truy cap nam gon trong 1 word.
"""
import argparse
import os
import random

M32 = 0xFFFF_FFFF
IMEM_BASE = 0x8000_0000
DMEM_MAP = {'c': 0x8008_0000, 'isa': 0x8400_0000}
DMEM_AW = 16
OUTSIDE = 0x1000_0000          # dia chi ngoai DMEM (vung Testbench Memory Map)


def sx(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v


# ---------------------------------------------------------------- encoder
def enc_r(f7, rs2, rs1, f3, rd, op):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_i(imm, rs1, f3, rd, op):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_s(imm, rs2, rs1, f3, op=0b0100011):
    imm &= 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 0x1F) << 7) | op


def enc_b(imm, rs2, rs1, f3, op=0b1100011):
    imm &= 0x1FFF
    return (((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) \
        | (f3 << 12) | (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 1) << 7) | op


def enc_u(imm20, rd, op):
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | op


def enc_j(imm, rd, op=0b1101111):
    imm &= 0x1FFFFF
    return (((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3FF) << 21) | (((imm >> 11) & 1) << 20) \
        | (((imm >> 12) & 0xFF) << 12) | (rd << 7) | op


R_OPS = {'add': (0x00, 0), 'sub': (0x20, 0), 'sll': (0x00, 1), 'slt': (0x00, 2), 'sltu': (0x00, 3),
         'xor': (0x00, 4), 'srl': (0x00, 5), 'sra': (0x20, 5), 'or': (0x00, 6), 'and': (0x00, 7)}
I_OPS = {'addi': 0, 'slti': 2, 'sltiu': 3, 'xori': 4, 'ori': 6, 'andi': 7}
SH_OPS = {'slli': (0x00, 1), 'srli': (0x00, 5), 'srai': (0x20, 5)}
LD_OPS = {'lb': 0, 'lh': 1, 'lw': 2, 'lbu': 4, 'lhu': 5}
ST_OPS = {'sb': 0, 'sh': 1, 'sw': 2}
BR_OPS = {'beq': 0, 'bne': 1, 'blt': 4, 'bge': 5, 'bltu': 6, 'bgeu': 7}
SIZE = {'lb': 1, 'lbu': 1, 'sb': 1, 'lh': 2, 'lhu': 2, 'sh': 2, 'lw': 4, 'sw': 4}


class Asm:
    def __init__(self):
        self.items, self.labels = [], {}

    @property
    def pc(self):
        return IMEM_BASE + 4 * len(self.items)

    def label(self, name):
        self.labels[name] = self.pc

    def word(self, w):
        self.items.append(w & M32)

    def r(self, op, rd, rs1, rs2):
        f7, f3 = R_OPS[op]
        self.word(enc_r(f7, rs2, rs1, f3, rd, 0b0110011))

    def i(self, op, rd, rs1, imm):
        if op in SH_OPS:
            f7, f3 = SH_OPS[op]
            self.word(enc_i((f7 << 5) | (imm & 0x1F), rs1, f3, rd, 0b0010011))
        else:
            self.word(enc_i(imm, rs1, I_OPS[op], rd, 0b0010011))

    def ld(self, op, rd, imm, rs1):
        self.word(enc_i(imm, rs1, LD_OPS[op], rd, 0b0000011))

    def st(self, op, rs2, imm, rs1):
        self.word(enc_s(imm, rs2, rs1, ST_OPS[op]))

    def lui(self, rd, imm20):
        self.word(enc_u(imm20, rd, 0b0110111))

    def auipc(self, rd, imm20):
        self.word(enc_u(imm20, rd, 0b0010111))

    def jalr(self, rd, rs1, imm):
        self.word(enc_i(imm, rs1, 0, rd, 0b1100111))

    def br(self, op, rs1, rs2, label):
        here = self.pc
        self.items.append((lambda t, h=here: enc_b(t - h, rs2, rs1, BR_OPS[op]), label))

    def jal(self, rd, label):
        here = self.pc
        self.items.append((lambda t, h=here: enc_j(t - h, rd), label))

    def li(self, rd, value):
        value &= M32
        lo = sx(value, 12)
        self.lui(rd, ((value - lo) >> 12) & 0xFFFFF)
        self.i('addi', rd, rd, lo)

    def assemble(self):
        return [(it[0](self.labels[it[1]]) if isinstance(it, tuple) else it) & M32 for it in self.items]


# ---------------------------------------------------------------- ISS
class ISS:
    def __init__(self, prog, dmem_base):
        self.prog, self.base = prog, dmem_base
        self.x = [0] * 32
        self.pc = IMEM_BASE
        self.dmem = {}                       # byte offset -> byte (chua ghi = 0)

    def in_dmem(self, addr):
        return (addr >> DMEM_AW) == (self.base >> DMEM_AW)

    def load(self, f3, addr):
        n = {0: 1, 4: 1, 1: 2, 5: 2, 2: 4}[f3]
        assert (addr & 3) + n <= 4, f'load vat word tai {addr:08x}'
        if not self.in_dmem(addr):
            return 0
        v = 0
        for k in range(n):
            off = (addr + k) & 0xFFFF
            v |= self.dmem.get(off, 0) << (8 * k)          # dmem.sv khoi tao 0
        return (sx(v, 8 * n) & M32) if f3 in (0, 1) else v

    def store(self, f3, addr, data):
        n = {0: 1, 1: 2, 2: 4}[f3]
        assert (addr & 3) + n <= 4, f'store vat word tai {addr:08x}'
        if self.in_dmem(addr):
            for k in range(n):
                self.dmem[(addr + k) & 0xFFFF] = (data >> (8 * k)) & 0xFF

    def step(self):
        ins = self.prog[(self.pc - IMEM_BASE) >> 2]
        op, rd, f3 = ins & 0x7F, (ins >> 7) & 0x1F, (ins >> 12) & 7
        rs1, rs2, f7 = (ins >> 15) & 0x1F, (ins >> 20) & 0x1F, ins >> 25
        a, b = self.x[rs1], self.x[rs2]
        imm_i = sx(ins >> 20, 12)
        imm_s = sx(((ins >> 25) << 5) | ((ins >> 7) & 0x1F), 12)
        imm_b = sx((((ins >> 31) & 1) << 12) | (((ins >> 7) & 1) << 11) | (((ins >> 25) & 0x3F) << 5)
                   | (((ins >> 8) & 0xF) << 1), 13)
        imm_u = ins & 0xFFFFF000
        imm_j = sx((((ins >> 31) & 1) << 20) | (((ins >> 12) & 0xFF) << 12) | (((ins >> 20) & 1) << 11)
                   | (((ins >> 21) & 0x3FF) << 1), 21)
        pc4 = (self.pc + 4) & M32
        nxt, wr, val, vld = pc4, False, 0, True

        def alu(fn, x, y):
            sh = y & 0x1F
            return {'add': x + y, 'sub': x - y, 'sll': x << sh, 'slt': int(sx(x, 32) < sx(y, 32)),
                    'sltu': int(x < y), 'xor': x ^ y, 'srl': x >> sh, 'sra': sx(x, 32) >> sh,
                    'or': x | y, 'and': x & y}[fn] & M32

        if op == 0b0110011:
            names = {(0, 0): 'add', (0x20, 0): 'sub', (0, 1): 'sll', (0, 2): 'slt', (0, 3): 'sltu',
                     (0, 4): 'xor', (0, 5): 'srl', (0x20, 5): 'sra', (0, 6): 'or', (0, 7): 'and'}
            if (f7, f3) in names:
                wr, val = True, alu(names[(f7, f3)], a, b)
            else:
                vld = False
        elif op == 0b0010011:
            if f3 == 1:
                vld, fn = f7 == 0, 'sll'
            elif f3 == 5:
                vld, fn = f7 in (0, 0x20), ('sra' if f7 == 0x20 else 'srl')
            else:
                fn = {0: 'add', 2: 'slt', 3: 'sltu', 4: 'xor', 6: 'or', 7: 'and'}[f3]
            if vld:
                wr, val = True, alu(fn, a, imm_i & M32)
        elif op == 0b0000011:
            if f3 in (0, 1, 2, 4, 5):
                wr, val = True, self.load(f3, (a + imm_i) & M32)
            else:
                vld = False
        elif op == 0b0100011:
            if f3 in (0, 1, 2):
                self.store(f3, (a + imm_s) & M32, b)
            else:
                vld = False
        elif op == 0b1100011:
            cond = {0: a == b, 1: a != b, 4: sx(a, 32) < sx(b, 32), 5: sx(a, 32) >= sx(b, 32),
                    6: a < b, 7: a >= b}
            if f3 in cond:
                if cond[f3]:
                    nxt = (self.pc + imm_b) & M32
            else:
                vld = False
        elif op == 0b1101111:
            wr, val, nxt = True, pc4, (self.pc + imm_j) & M32
        elif op == 0b1100111:
            if f3 == 0:
                wr, val, nxt = True, pc4, ((a + imm_i) & M32) & ~1
            else:
                vld = False
        elif op == 0b0110111:
            wr, val = True, imm_u
        elif op == 0b0010111:
            wr, val = True, (self.pc + imm_u) & M32
        else:
            vld = False

        we = wr and rd != 0
        rec = (self.pc, int(vld), int(we), rd if we else 0, val if we else 0)
        if we:
            self.x[rd] = val
        self.pc = nxt
        return rec


# ---------------------------------------------------------------- program
def build_program(rng, n_random, dbase):
    a = Asm()
    # ---------- 1. LUI / ADDI / AUIPC, ghi x0
    for r, v in ((1, 0x8000_0000), (2, 0x7FFF_FFFF), (3, 0xFFFF_FFFF), (4, 1), (5, 0x1234_5678),
                 (6, 0xDEAD_BEEF)):
        a.li(r, v)
    a.lui(7, 0xFFFFF)
    a.auipc(8, 0)
    a.auipc(9, 0x80000)
    a.i('addi', 0, 5, 123)
    a.r('add', 10, 0, 0)

    # ---------- 2. moi R / I / shift tren gia tri bien
    edge = [1, 2, 3, 4, 5, 6, 0]
    for op in R_OPS:
        for x in edge:
            for y in edge:
                a.r(op, 11, x, y)
    for op in I_OPS:
        for x in edge:
            for imm in (0, 1, -1, 0x7FF, -0x800, 0x555):
                a.i(op, 12, x, imm)
    for op in SH_OPS:
        for x in edge:
            for sh in (0, 1, 4, 15, 16, 31):
                a.i(op, 13, x, sh)
    a.li(14, 0x0000_0123)                   # rs2 > 31: chi lay 5 bit thap
    for op in ('sll', 'srl', 'sra'):
        a.r(op, 15, 1, 14)

    # ---------- 3. DMEM: khoi tao 2 KiB dau bang vong lap, roi load/store moi kieu
    a.li(20, dbase)
    a.li(21, dbase + 0x800)
    a.li(22, dbase)
    a.label('init')
    a.st('sw', 6, 0, 22)
    a.st('sb', 5, 1, 22)
    a.i('addi', 22, 22, 4)
    a.br('bne', 22, 21, 'init')
    for op in ST_OPS:                                   # store o moi offset hop le trong word
        for off in range(0x10, 0x20):
            if (off & 3) + SIZE[op] <= 4:
                a.st(op, 6 if off & 1 else 1, off, 20)
    for op in LD_OPS:
        for off in range(0x08, 0x28):
            if (off & 3) + SIZE[op] <= 4:
                a.ld(op, 16, off, 20)
    a.li(23, dbase + 0xFFFC)                            # word cuoi cua 64 KiB
    a.st('sw', 5, 0, 23)
    a.ld('lw', 16, 0, 23)
    a.ld('lh', 16, 2, 23)
    a.st('sw', 6, -4, 21)                               # offset am
    a.ld('lw', 16, -4, 21)
    # ngoai DMEM: store bi bo qua, load tra 0; DMEM khong bi alias
    a.li(24, OUTSIDE)
    a.st('sw', 3, 0, 24)
    a.ld('lw', 17, 0, 24)
    a.li(24, dbase - 0x10000)                           # ngay duoi DMEM
    a.st('sw', 3, 0, 24)
    a.ld('lw', 17, 0, 24)
    a.ld('lw', 17, 0, 20)                               # van la gia tri cu

    # ---------- 4. branch: moi loai, taken va not taken, branch lui
    pairs = [(1, 2), (2, 1), (3, 4), (4, 3), (5, 5), (0, 3), (3, 0), (1, 1)]
    k = 0
    for op in BR_OPS:
        for x, y in pairs:
            lab = f'br{k}'
            a.br(op, x, y, lab)
            a.i('addi', 28, 0, k + 1)
            a.label(lab)
            a.i('addi', 29, 0, k)
            k += 1
    a.li(28, 3)
    a.label('back')
    a.i('addi', 28, 28, -1)
    a.br('bne', 28, 0, 'back')

    # ---------- 5. JAL / JALR
    a.jal(30, 'f1')
    a.i('addi', 31, 0, 1)
    a.jal(0, 'after_f1')
    a.label('f1')
    a.jalr(0, 30, 0)
    a.label('after_f1')
    a.auipc(30, 0)
    a.jalr(31, 30, 17)                # x30+17 le -> & ~1 = x30+16
    a.i('addi', 31, 0, 99)
    a.i('addi', 31, 0, 98)
    a.i('addi', 29, 0, 7)

    # ---------- 6. lenh khong hop le: khong doi trang thai, o_db_valid = 0
    for w in (enc_r(0x01, 2, 1, 0, 11, 0b0110011), enc_r(0x01, 2, 1, 4, 11, 0b0110011),
              enc_r(0x20, 2, 1, 1, 11, 0b0110011), enc_r(0x20, 2, 1, 7, 11, 0b0110011),
              enc_i(0x400 | 3, 1, 1, 12, 0b0010011), enc_i(0x200 | 3, 1, 5, 12, 0b0010011),
              enc_i(0, 20, 3, 12, 0b0000011), enc_i(0, 20, 6, 12, 0b0000011),
              enc_s(0, 5, 20, 3), enc_b(8, 1, 1, 2), enc_i(8, 1, 1, 12, 0b1100111),
              0x0000_0000, 0xFFFF_FFFF, enc_r(0, 2, 1, 0, 11, 0b0111011),
              0x0000_000F, 0x0000_0073, 0x0010_0073):   # FENCE, ECALL, EBREAK: ngoai pham vi
        a.word(w)
    a.r('add', 11, 5, 6)

    # ---------- 7. ngau nhien (base x20 = dau DMEM, chi dung 2 KiB da khoi tao)
    pool = list(range(1, 20))
    for n in range(n_random):
        kind = rng.random()
        rd, rs1, rs2 = rng.choice(pool), rng.choice(pool), rng.choice(pool)
        if kind < 0.35:
            a.r(rng.choice(list(R_OPS)), rd, rs1, rs2)
        elif kind < 0.55:
            a.i(rng.choice(list(I_OPS)), rd, rs1, rng.randint(-2048, 2047))
        elif kind < 0.62:
            a.i(rng.choice(list(SH_OPS)), rd, rs1, rng.randint(0, 31))
        elif kind < 0.66:
            a.lui(rd, rng.getrandbits(20))
        elif kind < 0.68:
            a.auipc(rd, rng.getrandbits(20))
        elif kind < 0.78:
            op = rng.choice(list(ST_OPS))
            off = rng.randint(0, 0x7FC)
            off -= off % SIZE[op]
            a.st(op, rs2, off, 20)
        elif kind < 0.90:
            op = rng.choice(list(LD_OPS))
            off = rng.randint(0, 0x7FC)
            off -= off % SIZE[op]
            a.ld(op, rd, off, 20)
        else:
            lab = f'r{n}'
            a.br(rng.choice(list(BR_OPS)), rs1, rs2, lab)
            for _ in range(rng.randint(0, 3)):
                a.r(rng.choice(list(R_OPS)), rng.choice(pool), rng.choice(pool), rng.choice(pool))
            a.label(lab)

    a.label('halt')
    a.jal(0, 'halt')
    return a


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--seed', type=int, default=1)
    ap.add_argument('--random', type=int, default=1500)
    ap.add_argument('--map', choices=DMEM_MAP, default='c')
    ap.add_argument('--out', default='.')
    args = ap.parse_args()

    asm = build_program(random.Random(args.seed), args.random, DMEM_MAP[args.map])
    prog = asm.assemble()
    halt = asm.labels['halt']
    iss = ISS(prog, DMEM_MAP[args.map])
    trace = []
    while True:
        pc = iss.pc
        trace.append(iss.step())
        if pc == halt:
            break
        assert len(trace) < 500000

    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.out, 'prog_1b.hex'), 'w') as f:
        for w in prog:
            for k in range(4):
                f.write(f'{(w >> (8 * k)) & 0xFF:02x}\n')
    with open(os.path.join(args.out, 'trace.hex'), 'w') as f:
        for pc, vld, we, rd, val in trace:
            f.write(f'{pc:08x} {vld:x} {we:x} {rd:02x} {val:08x}\n')
    print(f'seed={args.seed} map={args.map}: {len(prog)} words, {len(trace)} instructions, '
          f'{sum(1 for t in trace if not t[1])} illegal')


if __name__ == '__main__':
    main()
