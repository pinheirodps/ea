#!/usr/bin/env python3
"""
Teste de regressão para janelas horárias de sessão (Londres local, Ásia UTC e Servidor MT5).
Valida as conversões em datas-chave:
- Inverno (Janeiro)
- Semanas de transição US vs EU (Março e Outubro)
- Verão (Julho)
"""

from datetime import datetime, timedelta, date

def _nth_weekday(year: int, month: int, weekday: int, n: int) -> date:
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

def em_dst_eu_uk(dt: datetime) -> bool:
    """Último domingo de março 01:00 UTC -> último domingo de outubro 01:00 UTC."""
    ini = datetime.combine(_nth_weekday(dt.year, 3, 6, -1), datetime.min.time()) + timedelta(hours=1)
    fim = datetime.combine(_nth_weekday(dt.year, 10, 6, -1), datetime.min.time()) + timedelta(hours=1)
    return ini <= dt < fim

def offset_londres_gmt(dt: datetime) -> int:
    """0 no inverno (GMT), +1 no verão (BST)."""
    return 1 if em_dst_eu_uk(dt) else 0

def offset_servidor_activtrades(dt: datetime) -> int:
    """GMT+1 no inverno (CET), GMT+2 no verão (CEST)."""
    return 2 if em_dst_eu_uk(dt) else 1

def hora_servidor_de_londres(dt: datetime, hora_londres: int) -> int:
    gmt = hora_londres - offset_londres_gmt(dt)
    return (gmt + offset_servidor_activtrades(dt)) % 24

def hora_servidor_de_utc(dt: datetime, hora_utc: int) -> int:
    return (hora_utc + offset_servidor_activtrades(dt)) % 24

def testar():
    datas_teste = [
        ("2024-01-15 (Inverno / GMT)", datetime(2024, 1, 15, 10, 0)),
        ("2024-03-15 (Semana intermediária US DST vs EU)", datetime(2024, 3, 15, 10, 0)),
        ("2024-04-05 (Verão pós-transição / BST)", datetime(2024, 4, 5, 10, 0)),
        ("2024-07-15 (Verão / BST)", datetime(2024, 7, 15, 10, 0)),
        ("2024-10-15 (Verão pré-transição / BST)", datetime(2024, 10, 15, 10, 0)),
        ("2024-11-15 (Inverno pós-transição / GMT)", datetime(2024, 11, 15, 10, 0)),
    ]

    print("=" * 80)
    print("TESTE DE REGRESSÃO: ALINHAMENTO DE SESSÕES (ACTIVTRADES CET/CEST vs LONDRES GMT/BST)")
    print("=" * 80)
    print(f"{'Data':<42} | {'Londres':<8} | {'Servidor':<10} | {'London Sweep (Local)':<20} | {'Servidor MT5':<12} | {'Asia (UTC)':<10} | {'Asia Servidor':<12}")
    print("-" * 135)

    todos_corretos = True
    for desc, dt in datas_teste:
        dst = em_dst_eu_uk(dt)
        off_lon = offset_londres_gmt(dt)
        off_srv = offset_servidor_activtrades(dt)

        lon_ini = 8
        lon_fim = 12
        srv_lon_ini = hora_servidor_de_londres(dt, lon_ini)
        srv_lon_fim = hora_servidor_de_londres(dt, lon_fim)

        asia_ini = 0
        asia_fim = 6
        srv_asia_ini = hora_servidor_de_utc(dt, asia_ini)
        srv_asia_fim = hora_servidor_de_utc(dt, asia_fim)

        # Validação:
        # 1. London Sweep local 08:00-12:00 DEVE ser sempre 09:00-13:00 no servidor ActivTrades!
        ok_lon = (srv_lon_ini == 9 and srv_lon_fim == 13)
        # 2. Asia 00:00-06:00 UTC deve ser 01:00-07:00 no inverno e 02:00-08:00 no verão
        ok_asia = (srv_asia_ini == 1 and srv_asia_fim == 7) if not dst else (srv_asia_ini == 2 and srv_asia_fim == 8)

        if not (ok_lon and ok_asia):
            todos_corretos = False

        status = "OK" if (ok_lon and ok_asia) else "FALHA"
        print(f"{desc:<42} | GMT+{off_lon}   | GMT+{off_srv}     | {lon_ini:02d}:00-{lon_fim:02d}:00        | {srv_lon_ini:02d}:00-{srv_lon_fim:02d}:00    | {asia_ini:02d}:00-{asia_fim:02d}:00   | {srv_asia_ini:02d}:00-{srv_asia_fim:02d}:00   [{status}]")

    print("-" * 135)
    if todos_corretos:
        print(">>> SUCESSO: Todos os testes passaram! Janela de Londres é 09:00-13:00 constante no servidor.")
    else:
        print(">>> ERRO: Algum teste divergiu do esperado!")
    print("=" * 80)

if __name__ == "__main__":
    testar()
