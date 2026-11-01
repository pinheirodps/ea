#!/usr/bin/env python3
"""
Diagnostico da convencao horaria do servidor MT5.

Determina, a partir de barras M1 exportadas, duas coisas separadas:
  1. offset-base do servidor vs GMT (hora de inverno)
  2. regra sazonal: US DST, EU DST ou nenhuma

METODO PRIMARIO -- fronteira do fim-de-semana
  A semana forex abre domingo 17:00 ET e fecha sexta 17:00 ET. Esse
  limite esta ancorado a Nova Iorque e move-se em GMT com o DST
  americano, qualquer que seja o servidor. Por isso a HORA DE SERVIDOR
  da abertura semanal isola a regra do proprio servidor, sem depender
  do comportamento do mercado.

  Assinaturas:
    - servidor segue US DST  -> hora constante o ano inteiro
    - offset fixo            -> degraus nas datas de troca US
    - servidor segue EU DST  -> janela de ~3 semanas desalinhada em marco

METODO SECUNDARIO -- amplitude por hora
  Tabela de amplitude media/mediana por hora de servidor e mes. Serve
  de corroboracao, NAO de prova: a abertura de Londres move-se em GMT
  com o DST europeu, pelo que um pico deslocado e ambiguo entre
  "servidor mudou" e "sessao mudou".

Uso:
    python3 diagnostico_dst.py M1_EURUSD.csv [M1_GBPUSD.csv ...]
"""

import sys
import csv
from collections import defaultdict
from datetime import datetime, timedelta, date

# --------------------------------------------------------------------
# Regras de DST
# --------------------------------------------------------------------

def _nth_weekday(year: int, month: int, weekday: int, n: int) -> date:
    """n-esimo <weekday> (0=segunda, 6=domingo) do mes. n=-1 -> ultimo."""
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
    """2o domingo de marco 07:00 UTC -> 1o domingo de novembro 06:00 UTC."""
    ini = datetime.combine(_nth_weekday(dt.year, 3, 6, 2), datetime.min.time()) \
          + timedelta(hours=7)
    fim = datetime.combine(_nth_weekday(dt.year, 11, 6, 1), datetime.min.time()) \
          + timedelta(hours=6)
    return ini <= dt < fim


def em_dst_eu(dt: datetime) -> bool:
    """Ultimo domingo de marco 01:00 UTC -> ultimo domingo de outubro 01:00 UTC."""
    ini = datetime.combine(_nth_weekday(dt.year, 3, 6, -1), datetime.min.time()) \
          + timedelta(hours=1)
    fim = datetime.combine(_nth_weekday(dt.year, 10, 6, -1), datetime.min.time()) \
          + timedelta(hours=1)
    return ini <= dt < fim


REGRAS = {
    "US":     em_dst_us,
    "EU":     em_dst_eu,
    "NENHUM": lambda dt: False,
}

# --------------------------------------------------------------------
# Leitura
# --------------------------------------------------------------------

def ler_barras(caminho):
    """Devolve [(datetime_servidor, high, low)] ordenado. Aceita o CSV do
    ExportarM1.mq5 e o export nativo do MT5 (tab, <DATE> <TIME> ...)."""
    barras = []
    with open(caminho, newline="", encoding="utf-8-sig", errors="replace") as f:
        amostra = f.read(4096)
        f.seek(0)
        delim = "\t" if "\t" in amostra.splitlines()[0] else ","
        leitor = csv.reader(f, delimiter=delim)
        cabecalho = next(leitor, None)

        for linha in leitor:
            if len(linha) < 4:
                continue
            try:
                # formato A: time,open,high,low,close
                if len(linha) >= 5 and (":" in linha[0]):
                    ts = _parse_dt(linha[0])
                    hi, lo = float(linha[2]), float(linha[3])
                # formato B: <DATE> <TIME> <OPEN> <HIGH> <LOW> <CLOSE> ...
                else:
                    ts = _parse_dt(linha[0] + " " + linha[1])
                    hi, lo = float(linha[3]), float(linha[4])
            except (ValueError, IndexError):
                continue
            barras.append((ts, hi, lo))

    barras.sort(key=lambda r: r[0])
    return barras


def _parse_dt(s: str) -> datetime:
    s = s.strip().replace(".", "-").replace("/", "-")
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M"):
        try:
            return datetime.strptime(s, fmt)
        except ValueError:
            pass
    raise ValueError(f"timestamp nao reconhecido: {s!r}")

# --------------------------------------------------------------------
# Metodo primario
# --------------------------------------------------------------------

def aberturas_semanais(barras, gap_min_horas=12):
    """Primeira barra apos cada interrupcao longa = abertura da semana."""
    out = []
    for i in range(1, len(barras)):
        if (barras[i][0] - barras[i - 1][0]) >= timedelta(hours=gap_min_horas):
            out.append(barras[i][0])
    return out


def ajustar_convencao(aberturas):
    """Para cada (offset-base, regra), conta aberturas cuja hora de servidor
    prevista bate com a observada. A hora GMT da abertura e 22h no inverno
    US e 21h no verao US (ancorada a Nova Iorque)."""
    resultados = []
    for regra, fn in REGRAS.items():
        for base in range(0, 6):
            acertos = 0
            for ts in aberturas:
                gmt_h = 21 if em_dst_us(ts) else 22
                offset = base + (1 if fn(ts) else 0)
                if (gmt_h + offset) % 24 == ts.hour:
                    acertos += 1
            resultados.append((acertos / max(len(aberturas), 1), base, regra))
    resultados.sort(reverse=True)
    return resultados


def perfil_por_semana(aberturas):
    """Hora de servidor da abertura, agrupada por mes, para inspecao visual."""
    por_mes = defaultdict(list)
    for ts in aberturas:
        por_mes[ts.month].append(ts.hour)
    return por_mes

# --------------------------------------------------------------------
# Metodo secundario
# --------------------------------------------------------------------

def amplitude_hora_mes(barras):
    acc = defaultdict(list)
    for ts, hi, lo in barras:
        acc[(ts.month, ts.hour)].append(hi - lo)
    return acc


def mediana(v):
    if not v:
        return 0.0
    s = sorted(v)
    n = len(s)
    return s[n // 2] if n % 2 else (s[n // 2 - 1] + s[n // 2]) / 2

# --------------------------------------------------------------------

def analisar(caminho):
    print("=" * 72)
    print(f"FICHEIRO: {caminho}")
    print("=" * 72)

    barras = ler_barras(caminho)
    if len(barras) < 1000:
        print(f"  Apenas {len(barras)} barras lidas. Verifica o ficheiro.")
        return
    print(f"  {len(barras):,} barras M1 | {barras[0][0]:%Y-%m-%d} a {barras[-1][0]:%Y-%m-%d}")

    ab = aberturas_semanais(barras)
    print(f"  {len(ab)} aberturas semanais detectadas\n")

    print("--- METODO PRIMARIO: hora de servidor da abertura semanal ---\n")
    por_mes = perfil_por_semana(ab)
    print("   Mes | horas observadas (contagem)")
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

    print("\n   Ajuste (offset-base de inverno + regra sazonal):\n")
    print("   score | offset-base | regra")
    print("   ------+-------------+--------")
    for score, base, regra in ajustar_convencao(ab)[:5]:
        print(f"   {score:5.1%} | GMT+{base}       | {regra}")

    score, base, regra = ajustar_convencao(ab)[0]
    print()
    if score >= 0.95:
        print(f"   >>> CONCLUSIVO: offset-base GMT+{base}, regra sazonal {regra}")
        print(f"       (ajuste {score:.1%} das aberturas semanais)")
    elif score >= 0.80:
        print(f"   >>> PROVAVEL: GMT+{base} / {regra}, mas {1-score:.0%} das semanas")
        print(f"       nao batem. Inspeciona a tabela por mes acima.")
    else:
        print(f"   >>> INCONCLUSIVO (melhor ajuste {score:.1%}). O servidor pode usar")
        print(f"       uma convencao nao coberta. Verifica a tabela por mes.")

    print("\n--- METODO SECUNDARIO: amplitude mediana por hora (corroboracao) ---")
    print("    Ambiguo por desenho: Londres tambem muda de hora em GMT.\n")
    acc = amplitude_hora_mes(barras)
    for rotulo, meses in (("Janeiro (inverno)", [1]), ("Julho (verao)", [7])):
        vals = {h: mediana(acc.get((meses[0], h), [])) for h in range(24)}
        if not any(vals.values()):
            continue
        pico = max(vals, key=vals.get)
        top = sorted(vals.items(), key=lambda kv: -kv[1])[:4]
        resumo = ", ".join(f"{h:02d}h" for h, _ in top)
        print(f"    {rotulo:20s} pico as {pico:02d}h servidor | top-4: {resumo}")
    print()


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    for caminho in sys.argv[1:]:
        try:
            analisar(caminho)
        except Exception as e:
            print(f"ERRO em {caminho}: {e}")


if __name__ == "__main__":
    main()
