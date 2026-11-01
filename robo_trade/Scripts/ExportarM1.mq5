//+------------------------------------------------------------------+
//|                                                 ExportarM1.mq5   |
//|  Script (nao EA). Exporta barras M1 para CSV com timestamp de    |
//|  SERVIDOR, para o diagnostico de DST em Python.                  |
//|                                                                  |
//|  Uso: arrastar para o grafico do par. O ficheiro vai para        |
//|  MQL5\Files\ do terminal (Ctrl+Shift+D abre a pasta).            |
//+------------------------------------------------------------------+
#property copyright "SMC Sniper - diagnostico"
#property version   "1.00"
#property script_show_inputs

input datetime InpDesde = D'2022.01.01 00:00';
input datetime InpAte   = D'2026.01.01 00:00';

void OnStart()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, false);

   int n = CopyRates(_Symbol, PERIOD_M1, InpDesde, InpAte, rates);
   if(n <= 0)
     {
      PrintFormat("ERRO: CopyRates devolveu %d. Carrega o historico M1 primeiro "
                  "(abre o grafico M1 e faz scroll ate %s).",
                  n, TimeToString(InpDesde, TIME_DATE));
      return;
     }

   string nome = StringFormat("M1_%s.csv", _Symbol);
   int h = FileOpen(nome, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE)
     {
      PrintFormat("ERRO ao criar %s: %d", nome, GetLastError());
      return;
     }

   FileWriteString(h, "time,open,high,low,close\n");
   for(int i = 0; i < n; i++)
     {
      FileWriteString(h, StringFormat("%s,%.*f,%.*f,%.*f,%.*f\n",
                     TimeToString(rates[i].time, TIME_DATE | TIME_SECONDS),
                     _Digits, rates[i].open,
                     _Digits, rates[i].high,
                     _Digits, rates[i].low,
                     _Digits, rates[i].close));
     }
   FileClose(h);

   PrintFormat("OK: %d barras M1 de %s exportadas para MQL5\\Files\\%s "
               "(%s a %s, hora de SERVIDOR).",
               n, _Symbol, nome,
               TimeToString(rates[0].time,   TIME_DATE),
               TimeToString(rates[n-1].time, TIME_DATE));
  }
//+------------------------------------------------------------------+
