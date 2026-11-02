#!/usr/bin/env python3
"""
Auditoria empírica completa dos 3 backtests baseline EURUSD (2022-2025)
a partir dos logs brutos dos agentes do Strategy Tester (4.217 trades).

Mede sem estimativas:
1. R líquido e sem comissão por trade (livre do efeito de compounding do saldo)
2. Spread exato na entrada (pts), Stop exato (pts), razão Spread/Stop
3. Benchmark analítico de Passeio Aleatório (martingale sem deriva) com os MESMOS (Spread_i, Stop_i)
   -> Separa matematicamente "custo de transação" de "informação (positiva/nula/negativa) do sinal"
4. Efeito cascata: WR e E[R] pela ordem do trade no dia (1º, 2º, 3º, 4º+)
5. Estratificação por quartis de tamanho de stop (testa a mecânica aritmética de stops maiores)
6. Decomposição anual (2022, 2023, 2024, 2025)
"""

import os
import re
import math
from collections import defaultdict

BASE_TESTER = r"C:\Users\Asus\AppData\Roaming\MetaQuotes\Tester\4508F68B4778C83AAAFD7D6DABBAD068"
LOGS = [
    os.path.join(BASE_TESTER, "Agent-127.0.0.1-3000", "logs", "20261102.log"),
    os.path.join(BASE_TESTER, "Agent-127.0.0.1-3001", "logs", "20261102.log"),
]

RE_INIT = re.compile(r"SMC Sniper v4\.1 \| setup=(\S+)")
RE_ENTRADA = re.compile(
    r"(\d{4}\.\d{2}\.\d{2}) (\d{2}:\d{2}:\d{2})\s+ENTRADA (BUY|SELL) \| "
    r"([\d.]+) \| SL ([\d.]+) \(([\d.]+) pts\) \| TP ([\d.]+) \| lote ([\d.]+) \| spread (\d+)"
)
RE_DEAL_OUT = re.compile(
    r"(\d{4}\.\d{2}\.\d{2}) (\d{2}:\d{2}:\d{2})\s+deal #(\d+) (buy|sell) ([\d.]+) EURUSD at ([\d.]+) done"
)
RE_ONTESTER = re.compile(r"OnTester: n=(\d+) \| media=([-\d.]+) \| sd=([-\d.]+) \| t=([-\d.]+)")


def parse_runs():
    completed_runs = {}
    for path in LOGS:
        if not os.path.exists(path):
            continue
        with open(path, "r", encoding="utf-16", errors="replace") as f:
            lines = f.readlines()

        current_setup = None
        trades = []
        open_trade = None

        for line in lines:
            m_init = RE_INIT.search(line)
            if m_init:
                current_setup = m_init.group(1)
                trades = []
                open_trade = None
                continue

            if current_setup is None:
                continue

            m_ent = RE_ENTRADA.search(line)
            if m_ent:
                open_trade = {
                    "date": m_ent.group(1),
                    "time": m_ent.group(2),
                    "year": int(m_ent.group(1)[:4]),
                    "dir": 1 if m_ent.group(3) == "BUY" else -1,
                    "dir_str": m_ent.group(3),
                    "entry": float(m_ent.group(4)),
                    "sl": float(m_ent.group(5)),
                    "stop_pts": float(m_ent.group(6)),
                    "tp": float(m_ent.group(7)),
                    "lot": float(m_ent.group(8)),
                    "spread_pts": int(m_ent.group(9)),
                }
                continue

            # Quando ha uma posicao aberta, o proximo deal no sentido oposto e a saida!
            if open_trade is not None:
                m_deal = RE_DEAL_OUT.search(line)
                if m_deal:
                    deal_side = 1 if m_deal.group(4) == "buy" else -1
                    if deal_side == -open_trade["dir"]:
                        exit_price = float(m_deal.group(6))
                        open_trade["exit_date"] = m_deal.group(1)
                        open_trade["exit_time"] = m_deal.group(2)
                        open_trade["exit"] = exit_price
                        pnl_pts = open_trade["dir"] * (exit_price - open_trade["entry"]) * 100000.0
                        open_trade["pnl_pts"] = pnl_pts
                        # R puro de preco (inclui spread e slippage, zero comissao extra)
                        open_trade["r_price"] = pnl_pts / open_trade["stop_pts"]
                        open_trade["win"] = 1 if pnl_pts > 0 else 0
                        # Slippage na saida
                        if pnl_pts > 0:
                            slip = open_trade["dir"] * (exit_price - open_trade["tp"]) * 100000.0
                        else:
                            slip = open_trade["dir"] * (exit_price - open_trade["sl"]) * 100000.0
                        open_trade["slip_pts"] = slip  # negativo = contra o trader
                        # R liquido com comissao de 7 EUR/lote (convertendo 1 pt = $0.10/lot -> em EUR ~ 0.10 / exit_price)
                        eur_per_pt_lot = 1.0 / exit_price  # 1 pt = 0.00001 * 100,000 = 1 USD -> / EURUSD = EUR
                        gross_eur_lot = pnl_pts * eur_per_pt_lot
                        risk_eur_lot = open_trade["stop_pts"] * eur_per_pt_lot + 7.0
                        open_trade["r_with_comm7"] = (gross_eur_lot - 7.0) / risk_eur_lot
                        trades.append(open_trade)
                        open_trade = None
                        continue

            m_ot = RE_ONTESTER.search(line)
            if m_ot and current_setup:
                n_ot = int(m_ot.group(1))
                completed_runs[current_setup] = {
                    "n_ontester": n_ot,
                    "t_ontester": float(m_ot.group(4)),
                    "trades": trades,
                }
                current_setup = None
                trades = []
                open_trade = None

    return completed_runs


def pct(vals, q):
    if not vals:
        return 0.0
    s = sorted(vals)
    idx = (len(s) - 1) * q
    lo = int(math.floor(idx))
    hi = int(math.ceil(idx))
    if lo == hi:
        return s[lo]
    return s[lo] + (s[hi] - s[lo]) * (idx - lo)


def mean_sd_t(vals):
    n = len(vals)
    if n == 0:
        return 0.0, 0.0, 0.0
    m = sum(vals) / n
    if n < 2:
        return m, 0.0, 0.0
    v = sum((x - m) ** 2 for x in vals) / (n - 1)
    sd = math.sqrt(v)
    t = (m / sd) * math.sqrt(n) if sd > 0 else 0.0
    return m, sd, t


def report():
    runs = parse_runs()
    order = ["SETUP_LONDON_SWEEP", "SETUP_H1_OB", "SETUP_ASIA_SWEEP"]
    for setup in order:
        if setup not in runs:
            print(f"[AVISO] {setup} nao encontrado.")
            continue
        info = runs[setup]
        tr = info["trades"]
        n = len(tr)
        print("=" * 88)
        print(f"SETUP: {setup} | extraidos={n} (OnTester n={info['n_ontester']}, t_EUR={info['t_ontester']:.2f})")
        print("=" * 88)

        spreads = [x["spread_pts"] for x in tr]
        stops = [x["stop_pts"] for x in tr]
        ratios = [x["spread_pts"] / x["stop_pts"] for x in tr]
        slips = [x["slip_pts"] for x in tr]
        r_price = [x["r_price"] for x in tr]
        r_comm7 = [x["r_with_comm7"] for x in tr]
        wins = sum(x["win"] for x in tr)
        wr_obs = wins / n

        print(f"1) DISTRIBUICAO REAL DE CUSTO E STOP (1 pip = 10 pts):")
        print(f"   Spread (pts)   : media={sum(spreads)/n:.2f} | P10={pct(spreads,0.1):.1f} | P50={pct(spreads,0.5):.1f} | P90={pct(spreads,0.9):.1f}")
        print(f"   Stop (pts)     : media={sum(stops)/n:.1f} | P10={pct(stops,0.1):.1f} | P25={pct(stops,0.25):.1f} | P50={pct(stops,0.5):.1f} | P75={pct(stops,0.75):.1f} | P90={pct(stops,0.9):.1f}")
        print(f"   Spread / Stop  : media={100*sum(ratios)/n:.2f}% | P50={100*pct(ratios,0.5):.2f}% | P90={100*pct(ratios,0.9):.2f}%")
        print(f"   Slippage saida : media={sum(slips)/n:+.2f} pts (negativo = desfavoravel)")

        # Benchmark de Passeio Aleatorio (Martingale sem deriva) com os MESMOS (S_i, D_i)
        p0_list = [max(0.0, (1.0 - x["spread_pts"] / x["stop_pts"]) / 3.0) for x in tr]
        wr_rand = sum(p0_list) / n
        # Expectativa em R_price de entrada aleatoria sem deriva = -E[S_i / D_i] + efeito slippage
        er_rand_price = -sum(ratios) / n + sum(x["slip_pts"] / x["stop_pts"] for x in tr) / n
        m_rp, sd_rp, t_rp = mean_sd_t(r_price)
        m_rc, sd_rc, t_rc = mean_sd_t(r_comm7)

        # Teste Z de WR observado vs WR passeio aleatorio (soma de Bernoullis independentes com p0_i)
        var_sum = sum(p * (1.0 - p) for p in p0_list)
        z_signal = (wins - sum(p0_list)) / math.sqrt(var_sum) if var_sum > 0 else 0.0
        alpha_r = m_rp - er_rand_price  # Excesso de R do sinal face a entrada aleatoria!

        print(f"\n2) SINAL vs PASSEIO ALEATORIO (com os mesmos Spread_i, Stop_i e Slippage_i):")
        print(f"   WR Observado              : {100*wr_obs:.2f}% ({wins}/{n})")
        print(f"   WR Passeio Aleatorio (p0) : {100*wr_rand:.2f}% (esperado={sum(p0_list):.1f} wins)")
        print(f"   Diferenca WR (Sinal - p0) : {100*(wr_obs - wr_rand):+.2f} p.p. | z = {z_signal:+.2f}")
        print(f"   E[R] Real (so spread)     : {m_rp:+.4f} R  (sd={sd_rp:.3f}, t={t_rp:+.2f})")
        print(f"   E[R] Passeio Aleatorio    : {er_rand_price:+.4f} R")
        print(f"   EDGE BRUTO DO SINAL (alfa): {alpha_r:+.4f} R/trade (acima do custo de spread+slippage)")
        print(f"   E[R] c/ +7 EUR/lote extra : {m_rc:+.4f} R  (sd={sd_rc:.3f}, t={t_rc:+.2f})")

        # 3) Ordem do trade no dia
        by_day = defaultdict(list)
        for x in tr:
            by_day[x["date"]].append(x)
        counts_per_day = [len(v) for v in by_day.values()]
        print(f"\n3) TRADES POR DIA E EFEITO CASCATA (dias com trade = {len(by_day)}):")
        dist_days = defaultdict(int)
        for c in counts_per_day:
            dist_days[min(c, 5)] += 1
        desc_d = ", ".join(f"{k}{'+' if k==5 else ''} tr/dia: {v}d" for k, v in sorted(dist_days.items()))
        print(f"   Distribuicao dias ativos  : {desc_d}")

        by_order = defaultdict(list)
        after_loss_same_day = []
        first_of_day = []
        for d, lst in by_day.items():
            had_loss = False
            for idx, x in enumerate(lst, start=1):
                bucket = idx if idx <= 4 else 5
                by_order[bucket].append(x)
                if idx == 1:
                    first_of_day.append(x)
                elif had_loss:
                    after_loss_same_day.append(x)
                if x["win"] == 0:
                    had_loss = True

        for k in sorted(by_order.keys()):
            sub = by_order[k]
            lbl = f"{k}o trade do dia" if k <= 4 else "5o+ trade do dia"
            w = sum(x["win"] for x in sub) / len(sub)
            mr, _, tr_stat = mean_sd_t([x["r_price"] for x in sub])
            p0_sub = sum((1.0 - x["spread_pts"]/x["stop_pts"])/3.0 for x in sub) / len(sub)
            print(f"   {lbl:18s}: n={len(sub):4d} | WR={100*w:5.2f}% (p0={100*p0_sub:5.2f}%) | E[R_spread]={mr:+.4f}R | alfa={mr - (-sum(x['spread_pts']/x['stop_pts'] for x in sub)/len(sub)):+.4f}R | t={tr_stat:+.2f}")

        if after_loss_same_day:
            w_al = sum(x["win"] for x in after_loss_same_day) / len(after_loss_same_day)
            mr_al, _, t_al = mean_sd_t([x["r_price"] for x in after_loss_same_day])
            print(f"   Reentrada pos-loss no dia : n={len(after_loss_same_day):4d} | WR={100*w_al:5.2f}% | E[R_spread]={mr_al:+.4f}R | t={t_al:+.2f}")

        # 4) Quartis de Stop
        q25, q50, q75 = pct(stops, 0.25), pct(stops, 0.50), pct(stops, 0.75)
        buckets_stop = [
            (f"Q1 (<={q25:.0f} pts)", [x for x in tr if x["stop_pts"] <= q25]),
            (f"Q2 ({q25:.0f}-{q50:.0f} pts)", [x for x in tr if q25 < x["stop_pts"] <= q50]),
            (f"Q3 ({q50:.0f}-{q75:.0f} pts)", [x for x in tr if q50 < x["stop_pts"] <= q75]),
            (f"Q4 (>{q75:.0f} pts)", [x for x in tr if x["stop_pts"] > q75]),
        ]
        print(f"\n4) ESTRATIFICACAO POR TAMANHO DO STOP (Quartis):")
        for lbl, sub in buckets_stop:
            if not sub:
                continue
            w = sum(x["win"] for x in sub) / len(sub)
            p0_s = sum((1.0 - x["spread_pts"]/x["stop_pts"])/3.0 for x in sub) / len(sub)
            mr, _, ts = mean_sd_t([x["r_price"] for x in sub])
            cost_s = -sum((x["spread_pts"] - x["slip_pts"])/x["stop_pts"] for x in sub) / len(sub)
            print(f"   {lbl:18s}: n={len(sub):4d} | S/D={100*sum(x['spread_pts']/x['stop_pts'] for x in sub)/len(sub):5.2f}% | WR={100*w:5.2f}% (p0={100*p0_s:5.2f}%) | E[R]={mr:+.4f}R | alfa={mr - cost_s:+.4f}R | t={ts:+.2f}")

        # 5) Por Ano
        print(f"\n5) DECOMPOSICAO ANUAL (em R_spread):")
        by_yr = defaultdict(list)
        for x in tr:
            by_yr[x["year"]].append(x)
        for yr in sorted(by_yr.keys()):
            sub = by_yr[yr]
            w = sum(x["win"] for x in sub) / len(sub)
            mr, _, ts = mean_sd_t([x["r_price"] for x in sub])
            print(f"   {yr}: n={len(sub):4d} | WR={100*w:5.2f}% | E[R_spread]={mr:+.4f}R | t={ts:+.2f}")
        print()


if __name__ == "__main__":
    report()
