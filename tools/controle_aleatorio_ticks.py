#!/usr/bin/env python3
"""
Controle Empírico de Entrada Aleatória nos Ticks Reais de EURUSD (2022-2025).

- Usa busca binária (f.seek) sobre o ficheiro ordenado de ticks, executando milhares
  de trades simulados tick-a-tick em poucos segundos.
- BLINDAGEM OOS 2026: localiza por busca binária a fronteira exata de '2026.' e impõe
  teto físico de bytes (offset < eof_2025). Nenhum trade entra nem é avaliado em 2026.
- Mesmas regras de execução do EA:
  * Filtro de spread <= 20 pts
  * BUY entra no Ask, sai quando Bid <= SL ou Bid >= TP (RR = 2.0)
  * SELL entra no Bid, sai quando Ask >= SL ou Ask <= TP (RR = 2.0)
  * Mesmas janelas horárias de cada setup e stops sorteados da distribuição empírica real.
"""

import csv
import math
import os
import random
import time
from datetime import date, datetime, timedelta

TICK_CSV = r"D:\AI projects\ea\files_in_progressing\EURUSD_202201022300_202610302159.csv"
AUDIT_CSV = r"D:\AI projects\ea\files_in_progressing\auditoria_trades_eurusd_v410.csv"


def _nth_weekday(year: int, month: int, weekday: int, n: int) -> date:
    d = date(year, month, 28)
    while True:
        nxt = d + timedelta(days=1)
        if nxt.month != month:
            break
        d = nxt
    delta = (d.weekday() - weekday) % 7
    return d - timedelta(days=delta)


def em_dst_eu(dt: datetime) -> bool:
    ini = datetime.combine(_nth_weekday(dt.year, 3, 6, -1), datetime.min.time()) + timedelta(hours=2)
    fim = datetime.combine(_nth_weekday(dt.year, 10, 6, -1), datetime.min.time()) + timedelta(hours=2)
    return ini <= dt < fim


def find_byte_offset(f, file_end: int, target_key: bytes) -> int:
    """Busca binária do primeiro registo com chave 'YYYY.MM.DD\\tHH:MM:SS' >= target_key."""
    lo, hi = 0, file_end
    while lo < hi:
        mid = (lo + hi) // 2
        f.seek(mid)
        if mid > 0:
            f.readline()  # alinha ao início da próxima linha completa
        pos = f.tell()
        if pos >= file_end:
            hi = mid
            continue
        line = f.readline()
        if not line or len(line) < 19:
            hi = mid
            continue
        if line[:1] == b"<":  # cabeçalho
            lo = f.tell()
            continue
        key = line[:19]
        if key < target_key:
            lo = f.tell()
        else:
            hi = mid
    f.seek(lo)
    if lo > 0:
        f.readline()
    return f.tell()


def load_empirical_stops():
    stops_by_setup = {"SETUP_LONDON_SWEEP": [], "SETUP_H1_OB": [], "SETUP_ASIA_SWEEP": []}
    with open(AUDIT_CSV, "r", encoding="utf-8") as f:
        r = csv.DictReader(f)
        for row in r:
            s = row["setup"]
            if s in stops_by_setup:
                stops_by_setup[s].append(float(row["stop_pts"]))
    return stops_by_setup


def sim_random_control(n_per_setup=1500, seed=42):
    t0 = time.time()
    rng = random.Random(seed)
    stops_map = load_empirical_stops()
    file_size = os.path.getsize(TICK_CSV)

    # Dias úteis de 2022-01-03 a 2025-12-29 (deixa folga para fecho antes de 2026)
    days = []
    cur = date(2022, 1, 3)
    end_d = date(2025, 12, 29)
    while cur <= end_d:
        if cur.weekday() < 5:
            days.append(cur)
        cur += timedelta(days=1)

    with open(TICK_CSV, "rb") as f:
        eof_2025 = find_byte_offset(f, file_size, b"2026.01.01\t00:00:00")
        print(f"Blindagem OOS ativa: fronteira 2026 localizada no byte {eof_2025:,} / {file_size:,} ({100*eof_2025/file_size:.1f}% do ficheiro).")
        print("Nenhum byte >= 2026.01.01 sera lido.\n")

        configs = [
            ("SETUP_LONDON_SWEEP", lambda dt: (9, 13)),
            ("SETUP_H1_OB",        lambda dt: (9, 17)),
            ("SETUP_ASIA_SWEEP",   lambda dt: (2, 8) if em_dst_eu(dt) else (1, 7)),
        ]

        print("=" * 92)
        print(f"CONTROLE EMPIRICO DE ENTRADA ALEATORIA NOS TICKS REAIS (EURUSD 2022-2025, seed={seed})")
        print("=" * 92)

        for setup, win_fn in configs:
            emp_stops = stops_map[setup]
            results_r = []
            p0_analitico = []
            wins = 0
            spreads_used = []

            attempts = 0
            while len(results_r) < n_per_setup and attempts < n_per_setup * 5:
                attempts += 1
                d = rng.choice(days)
                h_ini, h_fim = win_fn(datetime(d.year, d.month, d.day, 12, 0))
                hh = rng.randint(h_ini, h_fim - 1)
                mm = rng.randint(0, 59)
                ss = rng.randint(0, 59)
                target = f"{d.year:04d}.{d.month:02d}.{d.day:02d}\t{hh:02d}:{mm:02d}:{ss:02d}".encode("ascii")

                pos = find_byte_offset(f, eof_2025, target)
                if pos >= eof_2025:
                    continue
                f.seek(pos)
                line = f.readline()
                if not line or f.tell() >= eof_2025 or line[:4] >= b"2026":
                    continue
                # Confirma que o primeiro tick ainda esta no mesmo dia e janela
                if line[:10].decode("ascii", "ignore") != f"{d.year:04d}.{d.month:02d}.{d.day:02d}":
                    continue
                tick_h = int(line[11:13])
                if not (h_ini <= tick_h < h_fim):
                    continue

                parts = line.split(b"\t")
                if len(parts) < 4 or not parts[2] or not parts[3]:
                    continue
                bid0 = float(parts[2])
                ask0 = float(parts[3])
                spread_pts = round((ask0 - bid0) * 100000.0)
                if spread_pts > 20 or spread_pts < 0:
                    continue

                direcao = 1 if rng.random() < 0.5 else -1
                stop_pts = rng.choice(emp_stops)
                dist = stop_pts * 0.00001

                if direcao == 1:
                    entrada = ask0
                    sl = round(entrada - dist, 5)
                    tp = round(entrada + 2.0 * dist, 5)
                else:
                    entrada = bid0
                    sl = round(entrada + dist, 5)
                    tp = round(entrada - 2.0 * dist, 5)

                # Varre ticks seguintes ate atingir SL ou TP (respeitando teto eof_2025!)
                exit_price = None
                while f.tell() < eof_2025:
                    chunk = f.readlines(65536)
                    if not chunk:
                        break
                    hit = False
                    for tl in chunk:
                        if tl[:4] >= b"2026":
                            hit = True
                            break
                        # Fast slice parse: YYYY.MM.DD\tHH:MM:SS.mmm\tBID\tASK
                        t1 = tl.find(b"\t", 20)
                        if t1 < 0:
                            continue
                        t2 = tl.find(b"\t", t1 + 1)
                        if t2 < 0:
                            continue
                        b_str = tl[t1 + 1 : t2]
                        t3 = tl.find(b"\t", t2 + 1)
                        a_str = tl[t2 + 1 : t3] if t3 > 0 else tl[t2 + 1 :].strip()
                        if not b_str or not a_str:
                            continue
                        bid = float(b_str)
                        ask = float(a_str)
                        if direcao == 1:
                            if bid <= sl:
                                exit_price = bid
                                hit = True
                                break
                            if bid >= tp:
                                exit_price = bid
                                hit = True
                                break
                        else:
                            if ask >= sl:
                                exit_price = ask
                                hit = True
                                break
                            if ask <= tp:
                                exit_price = ask
                                hit = True
                                break
                    if hit:
                        break

                if exit_price is None:
                    continue

                pnl_pts = direcao * (exit_price - entrada) * 100000.0
                r_val = pnl_pts / stop_pts
                results_r.append(r_val)
                if pnl_pts > 0:
                    wins += 1
                spreads_used.append(spread_pts)
                p0_analitico.append(max(0.0, (1.0 - spread_pts / stop_pts) / 3.0))

            n = len(results_r)
            wr_emp = wins / n
            wr_p0 = sum(p0_analitico) / n
            mean_r = sum(results_r) / n
            sd_r = math.sqrt(sum((x - mean_r) ** 2 for x in results_r) / (n - 1))
            se_r = sd_r / math.sqrt(n)
            print(f"{setup:20s} | n={n:4d} | Spread med={sum(spreads_used)/n:.2f} pts")
            print(f"  WR Empirico Ticks  : {100*wr_emp:5.2f}%  vs  WR Analitico p0 : {100*wr_p0:5.2f}% (dif={100*(wr_emp-wr_p0):+.2f} p.p.)")
            print(f"  E[R] Empirico Ticks: {mean_r:+.4f}R (+/- {1.96*se_r:.4f}R IC95%)")
            print("-" * 92)

    print(f"Concluido em {time.time() - t0:.1f}s!")


if __name__ == "__main__":
    sim_random_control()
