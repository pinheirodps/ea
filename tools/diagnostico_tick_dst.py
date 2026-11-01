#!/usr/bin/env python3
"""
Diagnóstico de DST e fuso horário do servidor MT5 a partir de export de ticks ou barras M1.
Suporta ficheiros grandes (7+ GB) lendo em modo binário ultra-rápido.
"""

import sys
import os
from collections import defaultdict
from datetime import datetime, timedelta, date
import time

def _nth_weekday(year: int, month: int, weekday: int, n: int) -> date:
    """n-ésimo <weekday> (0=segunda, 6=domingo) do mês. n=-1 -> último."""
    if n > 0:
        d = date(year, month, 1)
        delta = (weekday - d.weekday()) % 7
        return d + timedelta(days=delta + 7 * (n - 1))
    d = date(year, month, 28)
    while True:
        nxt = d + timedelta(days=1)
        if nxt.month != month:
            break
        d = nxt
    delta = (d.weekday() - weekday) % 7
    return d - timedelta(days=delta)


def em_dst_us(dt: datetime) -> bool:
    """2º domingo de março 07:00 UTC -> 1º domingo de novembro 06:00 UTC."""
    ini = datetime.combine(_nth_weekday(dt.year, 3, 6, 2), datetime.min.time()) + timedelta(hours=7)
    fim = datetime.combine(_nth_weekday(dt.year, 11, 6, 1), datetime.min.time()) + timedelta(hours=6)
    return ini <= dt < fim


def em_dst_eu(dt: datetime) -> bool:
    """Último domingo de março 01:00 UTC -> último domingo de outubro 01:00 UTC."""
    ini = datetime.combine(_nth_weekday(dt.year, 3, 6, -1), datetime.min.time()) + timedelta(hours=1)
    fim = datetime.combine(_nth_weekday(dt.year, 10, 6, -1), datetime.min.time()) + timedelta(hours=1)
    return ini <= dt < fim


REGRAS = {
    "US":     em_dst_us,
    "EU":     em_dst_eu,
    "NENHUM": lambda dt: False,
}


def extrair_aberturas(caminho_csv):
    """Lê ficheiro de ticks ou M1 em binário e detecta aberturas após gaps >= 2 dias."""
    t0 = time.time()
    aberturas = []
    prev_date_bytes = None
    prev_date = None
    total_linhas = 0

    print(f"Lendo {caminho_csv} (modo streaming binário)...")
    with open(caminho_csv, "rb") as f:
        # Pula cabeçalho
        primeira_linha = f.readline()
        total_linhas += 1

        for line in f:
            total_linhas += 1
            # Verifica se começa com data YYYY.MM.DD ou YYYY-MM-DD
            if len(line) < 19:
                continue
            
            d_bytes = line[:10]
            if d_bytes != prev_date_bytes:
                try:
                    # Parse data
                    y = int(d_bytes[:4])
                    m = int(d_bytes[5:7])
                    d = int(d_bytes[8:10])
                    curr_date = date(y, m, d)
                except ValueError:
                    continue

                if prev_date is None:
                    # Primeira abertura do ficheiro
                    try:
                        hh = int(line[11:13])
                        mm = int(line[14:16])
                        ss = int(line[17:19])
                        aberturas.append(datetime(y, m, d, hh, mm, ss))
                    except ValueError:
                        pass
                    prev_date = curr_date
                    prev_date_bytes = d_bytes
                else:
                    dias_gap = (curr_date - prev_date).days
                    if dias_gap >= 2:
                        # Fim de semana detectado!
                        try:
                            hh = int(line[11:13])
                            mm = int(line[14:16])
                            ss = int(line[17:19])
                            aberturas.append(datetime(y, m, d, hh, mm, ss))
                        except ValueError:
                            pass
                    prev_date = curr_date
                    prev_date_bytes = d_bytes

    t_total = time.time() - t0
    print(f"Concluído em {t_total:.1f}s! Total de linhas: {total_linhas:,} | Aberturas semanais detectadas: {len(aberturas)}")
    return aberturas


def ajustar_convencao(aberturas):
    """
    Testa combinações de (offset-base, regra).
    Hora GMT da abertura: 21h no verão US, 22h no inverno US.
    Hora prevista do servidor = (hora_gmt + offset_servidor) % 24
    """
    resultados = []
    for regra, fn in REGRAS.items():
        for base in range(0, 6):
            acertos = 0
            for ts in aberturas:
                gmt_h = 21 if em_dst_us(ts) else 22
                offset = base + (1 if fn(ts) else 0)
                if (gmt_h + offset) % 24 == ts.hour:
                    acertos += 1
            taxa = acertos / max(len(aberturas), 1)
            resultados.append((taxa, acertos, base, regra))
    resultados.sort(reverse=True, key=lambda x: x[0])
    return resultados


def perfil_por_semana(aberturas):
    por_mes = defaultdict(list)
    for ts in aberturas:
        por_mes[ts.month].append(ts.hour)
    return por_mes


def analisar(caminho_csv):
    print("=" * 72)
    print("DIAGNÓSTICO DA CONVENÇÃO HORÁRIA E DST DO SERVIDOR MT5")
    print("=" * 72)
    print(f"Ficheiro: {caminho_csv}")

    ab = extrair_aberturas(caminho_csv)
    if not ab:
        print("Erro: Nenhuma abertura semanal detectada.")
        return

    # Salva aberturas extraídas em arquivo de texto leve para reutilização
    out_ab = os.path.join(os.path.dirname(caminho_csv), "aberturas_semanais_detectadas.txt")
    with open(out_ab, "w", encoding="utf-8") as f:
        f.write("data_hora\tdia_semana\thora\n")
        for dt in ab:
            f.write(f"{dt.strftime('%Y-%m-%d %H:%M:%S')}\t{dt.strftime('%A')}\t{dt.hour}\n")
    print(f"Registo de aberturas guardado em: {out_ab}\n")

    print(f"Período coberto: {ab[0].strftime('%Y-%m-%d')} a {ab[-1].strftime('%Y-%m-%d')}")
    print(f"Amostra total: {len(ab)} semanas analisadas\n")

    print("--- MÉTODO PRIMÁRIO: HORA DE SERVIDOR NA ABERTURA SEMANAL ---")
    por_mes = perfil_por_semana(ab)
    print("   Mês | Horas observadas no servidor (contagem)")
    print("   ----+" + "-" * 50)
    for m in range(1, 13):
        horas = por_mes.get(m, [])
        if not horas:
            continue
        cont = defaultdict(int)
        for h in horas:
            cont[h] += 1
        desc = "  ".join(f"{h:02d}h x{c}" for h, c in sorted(cont.items()))
        print(f"   {m:3d} | {desc}")

    print("\n   Tabela de Ajuste (Offset-Base de Inverno + Regra Sazonal):")
    print("   score   | acertos | offset-base | regra")
    print("   --------+---------+-------------+--------")
    resultados = ajustar_convencao(ab)
    for score, acertos, base, regra in resultados[:6]:
        print(f"   {score:6.1%}  | {acertos:3d}/{len(ab)} | GMT+{base}       | {regra}")

    score_top, acertos_top, base_top, regra_top = resultados[0]
    print()
    if score_top >= 0.95:
        print(f"   >>> VEREDICTO CONCLUSIVO: Offset-base GMT+{base_top}, Regra Sazonal {regra_top}")
        print(f"       Ajuste perfeito em {score_top:.1%} das aberturas ({acertos_top}/{len(ab)} semanas).")
    elif score_top >= 0.80:
        print(f"   >>> PROVÁVEL: GMT+{base_top} / {regra_top} ({score_top:.1%}), mas {1-score_top:.0%} divergiram.")
    else:
        print(f"   >>> INCONCLUSIVO (melhor ajuste {score_top:.1%}). Verifique a tabela mensal acima.")

    print("\n" + "=" * 72)
    return base_top, regra_top


if __name__ == "__main__":
    caminho = sys.argv[1] if len(sys.argv) > 1 else r"D:\AI projects\ea\files_in_progressing\EURUSD_202201022300_202610302159.csv"
    analisar(caminho)
