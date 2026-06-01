//+------------------------------------------------------------------+
//|  SMC Sniper v3.5.1 — Laboratório Corrigido + Diagnóstico CSV      |
//|  EURUSD Sniper: Core preservado + FVG + Spread Filter + Log        |
//|  TUDO experimental desligado por padrão. Ligar um por um.         |
//+------------------------------------------------------------------+
#property copyright "SMC Sniper v3.5.1"
#property version   "3.51"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

// === INPUTS CORE (Preservar — não mexer) ===
input bool     Perfil_V27_Travado    = true;
input double   Risco_Euros           = 3.0;
input double   RR_Ratio              = 3.0;
input double   RR_Max_Efetivo        = 2.0;
input bool     Usar_RR_Sniper_Dinamico = true;
input double   RR_Sniper_Forte       = 2.8;
input double   Breakeven_Ratio       = 2.0;
input double   Breakeven_Max_Efetivo = 1.2;
input double   Breakeven_Lock_R      = 0.25;
input int      OB_Lookback_H1        = 5;
input bool     Usar_OB_M15_Sniper    = true;
input int      OB_Lookback_M15       = 12;
input int      Swing_Lookback_M1     = 40;
input int      Swing_Lookback_Min_Efetivo = 40;
input int      Swing_Confirmacao_M1  = 2;
input int      Swing_Confirmacao_Max_Efetivo = 3;
input int      Timeout_Velas_M1      = 120;      // MANTIDO 120 — testar 45 isolado
input int      Bloqueio_Horas_OB     = 4;
input int      ATR_Period            = 14;
input double   ATR_Sweep_Min         = 0.2;
input double   ATR_Stop_Min          = 0.15;
input double   ATR_Stop_Min_Max_Efetivo = 0.15;
input double   ATR_Stop_Max          = 5.0;
input double   ATR_Minimo            = 0.00005;
input double   ATR_H1_Min_Pontos     = 60.0;
input double   ATR_H1_Max_Pontos     = 220.0;
input double   ATR_M1_Min_Pontos     = 5.0;
input double   ATR_M1_Max_Pontos     = 45.0;
input ENUM_TIMEFRAMES RSI_Timeframe  = PERIOD_M30;
input ENUM_TIMEFRAMES RSI_Timeframe_Min_Efetivo = PERIOD_M30;
input ENUM_TIMEFRAMES RSI_Timeframe_Max_Efetivo = PERIOD_M30;
input int      RSI_Period            = 14;
input double   RSI_Min_Entrada       = 52.0;
input double   RSI_Min_Entrada_Max_Efetivo = 52.0;
input double   RSI_Neutro            = 50.0;
input double   Displacement_ATR_M1   = 0.8;
input double   Displacement_ATR_M1_Max_Efetivo = 0.8;
input bool     Filtro_Candle_Sniper  = true;
input double   Candle_Corpo_Min_Ratio= 0.55;
input double   Candle_Fechamento_Extremo_Ratio = 0.25;
input double   Candle_Corpo_RR_Forte = 0.70;
input double   Candle_Fechamento_RR_Forte = 0.15;
input bool     Entrada_Direta_OB     = false;
input bool     Bloquear_OB_Apos_Trade= true;
input bool     Usar_Filtro_Sessao    = true;
input int      Sessao1_Inicio        = 8;
input int      Sessao1_Fim           = 10;
input int      Sessao1_Fim_Min_Efetivo = 10;
input int      Sessao2_Inicio        = 13;
input int      Sessao2_Fim           = 16;
input int      Sessao2_Fim_Min_Efetivo = 16;
input int      Tendencia_EMA_H1      = 20;
input int      Tendencia_Lookback_H1 = 40;
input int      Tendencia_Swing_Lados = 2;
input double   Tendencia_EMA_Buffer_Pontos = 10.0;
input bool     Tendencia_Exigir_EMA_Inclinada = true;
input int      Magic                 = 20260201;

// === INPUTS v3.5.1 — CORREÇÕES + NOVOS (tudo false por padrão) ===
input int      Max_Spread_Pontos     = 25;       // Proteção de sobrevivência
input bool     Usar_FVG_Confluence   = true;     // ÚNICO novo ativo por padrão
input ENUM_TIMEFRAMES FVG_Timeframe  = PERIOD_M15;
input bool     Usar_Trailing_Estrutura = false;  // TESTAR SEPARADO
input double   Trailing_ATR_Multiplier = 1.5;
input bool     Usar_Partials_2R      = false;   // TESTAR SEPARADO
input double   Partials_Ratio        = 0.50;
input bool     Usar_Pyramiding       = false;   // NÃO LIGAR SEM VALIDAÇÃO
input double   Pyramid_Ratio         = 0.50;
input double   Pyramid_ATR_Multiplier = 1.0;
input bool     Usar_Filtro_Noticias  = false;   // Configurar datas manualmente
input int      Noticia1_Mes          = 0;
input int      Noticia1_Dia          = 0;
input int      Noticia1_HoraInicio   = 0;
input int      Noticia1_HoraFim      = 0;
input int      Noticia2_Mes          = 0;
input int      Noticia2_Dia          = 0;
input int      Noticia2_HoraInicio   = 0;
input int      Noticia2_HoraFim      = 0;
input int      Noticia3_Mes          = 0;
input int      Noticia3_Dia          = 0;
input int      Noticia3_HoraInicio   = 0;
input int      Noticia3_HoraFim      = 0;
input bool     Usar_SMT_DXY          = false;   // CORRIGIDO mas desligado
input string   DXY_Symbol            = "USDX";
input ENUM_TIMEFRAMES DXY_Timeframe  = PERIOD_H1;
input int      DXY_Lookback          = 5;
input bool     Usar_Discount_Premium  = false;    // TESTAR SEPARADO
input int      DP_Lookback_D1        = 1;
input int      Sweep_Tolerancia_Min  = 15;        // Janela pós-sweep

// === INPUTS CSV ===
input bool     Salvar_Log_CSV        = true;
input string   Nome_Arquivo_CSV      = "SMC_Sniper_Log.csv";

//+------------------------------------------------------------------+
enum ENUM_ESTADO { SCANNING, EM_ZONA, SWEEP_OK, EM_TRADE };
ENUM_ESTADO g_estado = SCANNING;

double   g_ob_low=0, g_ob_high=0;
datetime g_ob_time=0;
double   g_swing_low_ref=0, g_swing_high_ref=0, g_sweep_low=0, g_sweep_high=0;
int      g_direcao=1;
bool     g_breakeven_feito=false;
bool     g_partial_feito=false;
bool     g_pyramid_feito=false;
double   g_lote_original=0;
datetime g_sweep_time=0;
int      g_velas_na_zona=0;
datetime g_ultima_vela_m1=0;
string   g_ob_tf="NA";
int      g_bos_candle_idx=-1;

int      g_atr_handle=INVALID_HANDLE;
int      g_atr_m1_handle=INVALID_HANDLE;
int      g_ema_h1_handle=INVALID_HANDLE;
int      g_rsi_handle=INVALID_HANDLE;

datetime g_bloqueio_ob_time[20];
datetime g_bloqueio_expira[20];
int      g_bloqueio_count=0;

// === VARIÁVEIS DE DIAGNÓSTICO POR TRADE ===
struct DiagnosticoTrade
{
   datetime hora_entrada;
   string   direcao;
   string   sessao;
   string   ob_tf;
   double   atr_h1;
   double   atr_m1;
   double   rsi;
   double   stop_pts;
   double   rr_efetivo;
   bool     fvg_ok;
   int      bos_candle_idx;
   long     spread_pts;
   string   resultado;     // "WIN" / "LOSS" / "BE" / "OPEN"
   double   lucro_r;       // lucro/perda em múltiplos de R
   string   motivo_saida;  // "TP" / "SL" / "BE" / "TRAILING" / "PARTIAL+TP" / "TIMEOUT"
   datetime hora_saida;
};
DiagnosticoTrade g_diag;
bool g_diag_ativo=false;

//+------------------------------------------------------------------+
ENUM_TIMEFRAMES RSI_TF_Efetivo()
{
   if(Perfil_V27_Travado) return PERIOD_M30;
   ENUM_TIMEFRAMES tf=RSI_Timeframe;
   if(RSI_Timeframe_Min_Efetivo>0 && (int)tf<(int)RSI_Timeframe_Min_Efetivo) tf=RSI_Timeframe_Min_Efetivo;
   if(RSI_Timeframe_Max_Efetivo>0 && (int)tf>(int)RSI_Timeframe_Max_Efetivo) tf=RSI_Timeframe_Max_Efetivo;
   return tf;
}

double RSI_Min_Efetivo()
{
   if(Perfil_V27_Travado) return 52.0;
   double valor=RSI_Min_Entrada;
   if(RSI_Min_Entrada_Max_Efetivo>0 && valor>RSI_Min_Entrada_Max_Efetivo) valor=RSI_Min_Entrada_Max_Efetivo;
   if(valor<RSI_Neutro) valor=RSI_Neutro;
   return valor;
}

double Displacement_Efetivo()
{
   if(Perfil_V27_Travado) return 0.8;
   double valor=Displacement_ATR_M1;
   if(Displacement_ATR_M1_Max_Efetivo>0 && valor>Displacement_ATR_M1_Max_Efetivo) valor=Displacement_ATR_M1_Max_Efetivo;
   return valor;
}

int SessaoFim1_Efetivo()
{
   if(Perfil_V27_Travado) return Sessao1_Fim;
   int fim=Sessao1_Fim;
   if(Sessao1_Fim_Min_Efetivo>0 && fim<Sessao1_Fim_Min_Efetivo) fim=Sessao1_Fim_Min_Efetivo;
   return fim;
}

int SessaoFim2_Efetivo()
{
   if(Perfil_V27_Travado) return Sessao2_Fim;
   int fim=Sessao2_Fim;
   if(Sessao2_Fim_Min_Efetivo>0 && fim<Sessao2_Fim_Min_Efetivo) fim=Sessao2_Fim_Min_Efetivo;
   return fim;
}

//+------------------------------------------------------------------+
//| FVG Confluence                                                   |
//+------------------------------------------------------------------+
bool TemFVGValido(int direcao)
{
   if(!Usar_FVG_Confluence) return true;
   for(int i=2; i<=12; i++)
   {
      double h1 = iHigh(_Symbol, FVG_Timeframe, i+1);
      double l1 = iLow(_Symbol, FVG_Timeframe, i+1);
      double h2 = iHigh(_Symbol, FVG_Timeframe, i-1);
      double l2 = iLow(_Symbol, FVG_Timeframe, i-1);

      if(direcao == 1 && l2 > h1)
      {
         double fvg_bottom = h1;
         double fvg_top = l2;
         double overlap = MathMin(g_ob_high, fvg_top) - MathMax(g_ob_low, fvg_bottom);
         if(overlap > 0 || MathAbs(g_ob_high - fvg_bottom) < 8*_Point)
            return true;
      }
      if(direcao == -1 && h2 < l1)
      {
         double fvg_bottom = h2;
         double fvg_top = l1;
         double overlap = MathMin(g_ob_high, fvg_top) - MathMax(g_ob_low, fvg_bottom);
         if(overlap > 0 || MathAbs(g_ob_low - fvg_top) < 8*_Point)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| SMT DXY — CORRIGIDO (usa iClose direto, não handle)              |
//+------------------------------------------------------------------+
bool SMT_DXY_Valido(int direcao)
{
   if(!Usar_SMT_DXY) return true;
   double dxy_now = iClose(DXY_Symbol, DXY_Timeframe, 0);
   double dxy_prev = iClose(DXY_Symbol, DXY_Timeframe, 1);
   if(dxy_now <= 0 || dxy_prev <= 0) return true; // símbolo não disponível, não bloqueia

   bool dxy_subindo = (dxy_now > dxy_prev);
   bool dxy_caindo  = (dxy_now < dxy_prev);
   if(direcao==1 && dxy_subindo) return false;
   if(direcao==-1 && dxy_caindo) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Filtro de Notícias — função normal (sem lambda)                  |
//+------------------------------------------------------------------+
// Função normal para verificar notícias
bool CheckNoticia(int nm, int nd, int nh1, int nh2, int mes, int dia, int h)
{
   if(nm<=0 || nd<=0) return true;
   if(mes==nm && dia==nd && h>=nh1 && h<=nh2) return false;
   return true;
}

bool DentroHorarioNoticias()
{
   if(!Usar_Filtro_Noticias) return true;
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   int mes=dt.mon, dia=dt.day, h=dt.hour;

   if(!CheckNoticia(Noticia1_Mes,Noticia1_Dia,Noticia1_HoraInicio,Noticia1_HoraFim,mes,dia,h)) return false;
   if(!CheckNoticia(Noticia2_Mes,Noticia2_Dia,Noticia2_HoraInicio,Noticia2_HoraFim,mes,dia,h)) return false;
   if(!CheckNoticia(Noticia3_Mes,Noticia3_Dia,Noticia3_HoraInicio,Noticia3_HoraFim,mes,dia,h)) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Discount / Premium Diário                                        |
//+------------------------------------------------------------------+
bool DiscountPremiumValido(int direcao)
{
   if(!Usar_Discount_Premium) return true;
   double d1_high = iHigh(_Symbol, PERIOD_D1, DP_Lookback_D1);
   double d1_low  = iLow(_Symbol, PERIOD_D1, DP_Lookback_D1);
   if(d1_high <= d1_low) return true;
   double range = d1_high - d1_low;
   double terco_inf = d1_low + range * 0.333;
   double terco_sup = d1_high - range * 0.333;
   double ob_mid = (g_ob_low + g_ob_high) * 0.5;
   if(direcao==1 && ob_mid > terco_inf) return false;
   if(direcao==-1 && ob_mid < terco_sup) return false;
   return true;
}

//+------------------------------------------------------------------+
//| CSV Diagnóstico                                                  |
//+------------------------------------------------------------------+
void IniciarDiagnostico()
{
   if(!Salvar_Log_CSV) return;
   string filename = Nome_Arquivo_CSV;
   string header = "Hora_Entrada,Direcao,Sessao,OB_TF,ATR_H1,ATR_M1,RSI,Stop_Pts,RR_Efetivo,FVG,BOS_Candle,Spread_Entrada,Hora_Saida,Resultado,Lucro_R,Motivo_Saida\n";

   int handle = FileOpen(filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON, ',');
   if(handle != INVALID_HANDLE)
   {
      if(FileSize(handle)==0)
         FileWriteString(handle, header);
      FileClose(handle);
      Print("CSV Diagnostico iniciado: ", filename);
   }
   else
   {
      Print("ERRO ao criar CSV: ", GetLastError());
   }
}

void SalvarDiagnostico()
{
   if(!Salvar_Log_CSV || !g_diag_ativo) return;
   string filename = Nome_Arquivo_CSV;

   int handle = FileOpen(filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON, ',');
   if(handle == INVALID_HANDLE)
   {
      Print("ERRO ao abrir CSV para append: ", GetLastError());
      return;
   }
   FileSeek(handle, 0, SEEK_END);

   string linha = StringFormat("%s,%s,%s,%s,%.5f,%.5f,%.2f,%.1f,%.2f,%s,%d,%d,%s,%s,%.2f,%s",
      TimeToString(g_diag.hora_entrada, TIME_DATE|TIME_SECONDS),
      g_diag.direcao,
      g_diag.sessao,
      g_diag.ob_tf,
      g_diag.atr_h1,
      g_diag.atr_m1,
      g_diag.rsi,
      g_diag.stop_pts,
      g_diag.rr_efetivo,
      g_diag.fvg_ok ? "SIM" : "NAO",
      g_diag.bos_candle_idx,
      g_diag.spread_pts,
      g_diag.hora_saida > 0 ? TimeToString(g_diag.hora_saida, TIME_DATE|TIME_SECONDS) : "",
      g_diag.resultado,
      g_diag.lucro_r,
      g_diag.motivo_saida
   );

   FileWriteString(handle, linha + "\n");
   FileClose(handle);
   g_diag_ativo = false;
}

void PreencherDiagnosticoEntrada(string dir, string tf, double atrh1, double atrm1, double rsi, double stp, double rr, bool fvg, int bosidx, long spread)
{
   g_diag_ativo = true;
   g_diag.hora_entrada = TimeCurrent();
   g_diag.direcao = dir;
   g_diag.ob_tf = tf;
   g_diag.atr_h1 = atrh1;
   g_diag.atr_m1 = atrm1;
   g_diag.rsi = rsi;
   g_diag.stop_pts = stp;
   g_diag.rr_efetivo = rr;
   g_diag.fvg_ok = fvg;
   g_diag.bos_candle_idx = bosidx;
   g_diag.spread_pts = spread;
   g_diag.resultado = "OPEN";
   g_diag.lucro_r = 0;
   g_diag.motivo_saida = "";

   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); int h=dt.hour;
   int fim1=SessaoFim1_Efetivo(); int fim2=SessaoFim2_Efetivo();
   if(h>=Sessao1_Inicio && h<=fim1) g_diag.sessao = "LONDON";
   else if(h>=Sessao2_Inicio && h<=fim2) g_diag.sessao = "NY";
   else g_diag.sessao = "OUTSIDE";
}

void AtualizarDiagnosticoSaida(string res, double lucroR, string motivo)
{
   if(!g_diag_ativo) return;
   g_diag.hora_saida = TimeCurrent();
   g_diag.resultado = res;
   g_diag.lucro_r = lucroR;
   g_diag.motivo_saida = motivo;
   SalvarDiagnostico();
}

double ObterATR()
{
   double buf[1];
   if(CopyBuffer(g_atr_handle,0,1,1,buf)<=0) return 0;
   return buf[0];
}

double ObterATRM1()
{
   double buf[1];
   if(CopyBuffer(g_atr_m1_handle,0,1,1,buf)<=0) return 0;
   return buf[0];
}

//+------------------------------------------------------------------+
//| Tendencia H1                                                     |
//+------------------------------------------------------------------+
bool SwingHighH1(const int shift, const int lados)
{
   double high=iHigh(_Symbol,PERIOD_H1,shift);
   if(high<=0) return false;
   for(int i=1;i<=lados;i++){
      if(high<=iHigh(_Symbol,PERIOD_H1,shift-i)) return false;
      if(high<=iHigh(_Symbol,PERIOD_H1,shift+i)) return false;
   }
   return true;
}

bool SwingLowH1(const int shift, const int lados)
{
   double low=iLow(_Symbol,PERIOD_H1,shift);
   if(low<=0) return false;
   for(int i=1;i<=lados;i++){
      if(low>=iLow(_Symbol,PERIOD_H1,shift-i)) return false;
      if(low>=iLow(_Symbol,PERIOD_H1,shift+i)) return false;
   }
   return true;
}

bool TendenciaDeAlta()
{
   double ema[2];
   if(CopyBuffer(g_ema_h1_handle,0,1,2,ema)<2) return false;
   double preco=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double buffer=Tendencia_EMA_Buffer_Pontos*_Point;
   if(preco<=ema[0]+buffer) return false;
   if(Tendencia_Exigir_EMA_Inclinada && ema[0]<=ema[1]) return false;

   int lados=Tendencia_Swing_Lados; if(lados<1) lados=1;
   int lookback=Tendencia_Lookback_H1;
   int lookback_minimo=lados*2+5;
   if(lookback<lookback_minimo) lookback=lookback_minimo;
   if(Bars(_Symbol,PERIOD_H1)<lookback+lados+2) return false;

   double ultimo_swing=0, swing_anterior=0;
   for(int shift=1+lados;shift<=lookback;shift++){
      if(!SwingHighH1(shift,lados)) continue;
      if(ultimo_swing==0) ultimo_swing=iHigh(_Symbol,PERIOD_H1,shift);
      else{ swing_anterior=iHigh(_Symbol,PERIOD_H1,shift); break; }
   }
   if(ultimo_swing==0 || swing_anterior==0) return false;
   return (ultimo_swing>swing_anterior);
}

bool TendenciaDeBaixa()
{
   double ema[2];
   if(CopyBuffer(g_ema_h1_handle,0,1,2,ema)<2) return false;
   double preco=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double buffer=Tendencia_EMA_Buffer_Pontos*_Point;
   if(preco>=ema[0]-buffer) return false;
   if(Tendencia_Exigir_EMA_Inclinada && ema[0]>=ema[1]) return false;

   int lados=Tendencia_Swing_Lados; if(lados<1) lados=1;
   int lookback=Tendencia_Lookback_H1;
   int lookback_minimo=lados*2+5;
   if(lookback<lookback_minimo) lookback=lookback_minimo;
   if(Bars(_Symbol,PERIOD_H1)<lookback+lados+2) return false;

   double ultimo_swing=0, swing_anterior=0;
   for(int shift=1+lados;shift<=lookback;shift++){
      if(!SwingLowH1(shift,lados)) continue;
      if(ultimo_swing==0) ultimo_swing=iLow(_Symbol,PERIOD_H1,shift);
      else{ swing_anterior=iLow(_Symbol,PERIOD_H1,shift); break; }
   }
   if(ultimo_swing==0 || swing_anterior==0) return false;
   return (ultimo_swing<swing_anterior);
}

//+------------------------------------------------------------------+
//| Filtros Auxiliares                                               |
//+------------------------------------------------------------------+
bool OB_Bloqueado(datetime t)
{
   datetime agora=TimeCurrent();
   for(int i=0;i<g_bloqueio_count;i++)
      if(g_bloqueio_ob_time[i]==t && agora<g_bloqueio_expira[i]) return true;
   return false;
}

void BloquearOB(datetime t)
{
   datetime agora=TimeCurrent();
   int n=0;
   for(int i=0;i<g_bloqueio_count;i++)
      if(agora<g_bloqueio_expira[i]){ g_bloqueio_ob_time[n]=g_bloqueio_ob_time[i]; g_bloqueio_expira[n]=g_bloqueio_expira[i]; n++; }
   g_bloqueio_count=n;
   if(g_bloqueio_count<20){
      g_bloqueio_ob_time[g_bloqueio_count]=t;
      g_bloqueio_expira[g_bloqueio_count]=agora+Bloqueio_Horas_OB*3600;
      g_bloqueio_count++;
   }
}

bool DentroHorarioEntrada()
{
   if(!Usar_Filtro_Sessao) return true;
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); int h=dt.hour;
   int fim1=SessaoFim1_Efetivo(); int fim2=SessaoFim2_Efetivo();
   bool sessao1=(h>=Sessao1_Inicio && h<=fim1);
   bool sessao2=(h>=Sessao2_Inicio && h<=fim2);
   return (sessao1 || sessao2);
}

bool ATRContextoValido(const bool logar=false)
{
   double atr_h1=ObterATR(); double atr_m1=ObterATRM1();
   if(atr_h1<=0 || atr_m1<=0) return false;
   double atr_h1_pts=atr_h1/_Point; double atr_m1_pts=atr_m1/_Point;
   bool valido=true;
   if(ATR_H1_Min_Pontos>0 && atr_h1_pts<ATR_H1_Min_Pontos) valido=false;
   if(ATR_H1_Max_Pontos>0 && atr_h1_pts>ATR_H1_Max_Pontos) valido=false;
   if(ATR_M1_Min_Pontos>0 && atr_m1_pts<ATR_M1_Min_Pontos) valido=false;
   if(ATR_M1_Max_Pontos>0 && atr_m1_pts>ATR_M1_Max_Pontos) valido=false;
   if(!valido && logar)
      Print("ATR fora do regime | H1: ",DoubleToString(atr_h1_pts,1)," pts | M1: ",DoubleToString(atr_m1_pts,1)," pts");
   return valido;
}

void ResetEstado()
{
   g_estado=SCANNING; g_ob_low=0; g_ob_high=0; g_ob_time=0;
   g_swing_low_ref=0; g_swing_high_ref=0; g_sweep_low=0; g_sweep_high=0;
   g_direcao=1; g_velas_na_zona=0; g_breakeven_feito=false;
   g_partial_feito=false; g_pyramid_feito=false; g_lote_original=0; g_sweep_time=0;
   g_ob_tf="NA"; g_bos_candle_idx=-1;
}

bool TemPosicaoAberta()
{
   for(int i=PositionsTotal()-1;i>=0;i--){
      ulong t=PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC)==Magic && PositionGetString(POSITION_SYMBOL)==_Symbol) return true;
   }
   return false;
}

bool SwingHighM1(const int shift, const int lados)
{
   double high=iHigh(_Symbol,PERIOD_M1,shift);
   if(high<=0) return false;
   for(int i=1;i<=lados;i++){
      if(high<=iHigh(_Symbol,PERIOD_M1,shift-i)) return false;
      if(high<=iHigh(_Symbol,PERIOD_M1,shift+i)) return false;
   }
   return true;
}

bool SwingLowM1(const int shift, const int lados)
{
   double low=iLow(_Symbol,PERIOD_M1,shift);
   if(low<=0) return false;
   for(int i=1;i<=lados;i++){
      if(low>=iLow(_Symbol,PERIOD_M1,shift-i)) return false;
      if(low>=iLow(_Symbol,PERIOD_M1,shift+i)) return false;
   }
   return true;
}

void FixarSwings()
{
   int lados=Swing_Confirmacao_M1; if(lados<1) lados=1;
   if(Swing_Confirmacao_Max_Efetivo>0 && lados>Swing_Confirmacao_Max_Efetivo) lados=Swing_Confirmacao_Max_Efetivo;
   g_swing_low_ref=0; g_swing_high_ref=0;
   int lookback=Swing_Lookback_M1;
   if(Swing_Lookback_Min_Efetivo>0 && lookback<Swing_Lookback_Min_Efetivo) lookback=Swing_Lookback_Min_Efetivo;
   int lookback_minimo=lados*2+5; if(lookback<lookback_minimo) lookback=lookback_minimo;

   for(int i=1+lados;i<=lookback;i++){
      if(g_swing_low_ref==0 && SwingLowM1(i,lados)) g_swing_low_ref=iLow(_Symbol,PERIOD_M1,i);
      if(g_swing_high_ref==0 && SwingHighM1(i,lados)) g_swing_high_ref=iHigh(_Symbol,PERIOD_M1,i);
      if(g_swing_low_ref>0 && g_swing_high_ref>0) return;
   }
   if(g_swing_low_ref==0) g_swing_low_ref=iLow(_Symbol,PERIOD_M1,1);
   if(g_swing_high_ref==0) g_swing_high_ref=iHigh(_Symbol,PERIOD_M1,1);
   for(int i=2;i<=lookback;i++){
      if(g_swing_low_ref==0 || iLow(_Symbol,PERIOD_M1,i)<g_swing_low_ref) g_swing_low_ref=iLow(_Symbol,PERIOD_M1,i);
      if(g_swing_high_ref==0 || iHigh(_Symbol,PERIOD_M1,i)>g_swing_high_ref) g_swing_high_ref=iHigh(_Symbol,PERIOD_M1,i);
   }
}

//+------------------------------------------------------------------+
//| BOS Recente — CORREÇÃO v3.5.1                                    |
//+------------------------------------------------------------------+
bool BOS_Recente(int idx_ob, ENUM_TIMEFRAMES tf, double ref_level, int direcao)
{
   int max_j = MathMin(3, idx_ob-1);
   for(int j=idx_ob-1; j>=idx_ob-max_j && j>=1; j--)
   {
      if(direcao==1 && iClose(_Symbol,tf,j) > ref_level) return true;
      if(direcao==-1 && iClose(_Symbol,tf,j) < ref_level) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Procurar OB                                                      |
//+------------------------------------------------------------------+
void ProcurarOB()
{
   double atr=ObterATR();
   if(atr<ATR_Minimo) return;
   if(!DentroHorarioEntrada()) return;
   if(!DentroHorarioNoticias()) return;
   if(!ATRContextoValido()) return;

   bool tendencia_alta=TendenciaDeAlta();
   bool tendencia_baixa=TendenciaDeBaixa();
   if(!tendencia_alta && !tendencia_baixa) return;

   double preco=SymbolInfoDouble(_Symbol,SYMBOL_BID);

   // === BUY OB H1 ===
   if(tendencia_alta){
      for(int i=2;i<=OB_Lookback_H1+10;i++){
         double o=iOpen(_Symbol,PERIOD_H1,i), c=iClose(_Symbol,PERIOD_H1,i);
         double h=iHigh(_Symbol,PERIOD_H1,i), l=iLow(_Symbol,PERIOD_H1,i);
         if(c>=o) continue;
         if(!BOS_Recente(i, PERIOD_H1, h, 1)) continue;

         double disp_h1 = (iHigh(_Symbol,PERIOD_H1,i-1) - iLow(_Symbol,PERIOD_H1,i-1)) / atr;
         if(disp_h1 < 1.15) continue;

         datetime ot=iTime(_Symbol,PERIOD_H1,i);
         if(OB_Bloqueado(ot)) continue;
         if(preco>=l && preco<=o){
            g_ob_low=l; g_ob_high=o; g_ob_time=ot; g_direcao=1; g_ob_tf="H1"; g_bos_candle_idx=1;
            if(!TemFVGValido(1)) continue;
            if(!DiscountPremiumValido(1)) continue;
            if(!SMT_DXY_Valido(1)) continue;
            g_estado=EM_ZONA; g_velas_na_zona=0;
            FixarSwings();
            Print(">>> ZONA OB H1 BUY | ",DoubleToString(l,_Digits)," - ",DoubleToString(o,_Digits));
            return;
         }
      }
   }

   // === SELL OB H1 ===
   if(tendencia_baixa){
      for(int i=2;i<=OB_Lookback_H1+10;i++){
         double o=iOpen(_Symbol,PERIOD_H1,i), c=iClose(_Symbol,PERIOD_H1,i);
         double h=iHigh(_Symbol,PERIOD_H1,i), l=iLow(_Symbol,PERIOD_H1,i);
         if(c<=o) continue;
         if(!BOS_Recente(i, PERIOD_H1, l, -1)) continue;

         double disp_h1 = (iHigh(_Symbol,PERIOD_H1,i-1) - iLow(_Symbol,PERIOD_H1,i-1)) / atr;
         if(disp_h1 < 1.15) continue;

         datetime ot=iTime(_Symbol,PERIOD_H1,i);
         if(OB_Bloqueado(ot)) continue;
         if(preco>=o && preco<=h){
            g_ob_low=o; g_ob_high=h; g_ob_time=ot; g_direcao=-1; g_ob_tf="H1"; g_bos_candle_idx=1;
            if(!TemFVGValido(-1)) continue;
            if(!DiscountPremiumValido(-1)) continue;
            if(!SMT_DXY_Valido(-1)) continue;
            g_estado=EM_ZONA; g_velas_na_zona=0;
            FixarSwings();
            Print(">>> ZONA OB H1 SELL | ",DoubleToString(o,_Digits)," - ",DoubleToString(h,_Digits));
            return;
         }
      }
   }

   // === OB M15 (com FVG também) ===
   if(Usar_OB_M15_Sniper){
      if(tendencia_alta){
         for(int i=2;i<=OB_Lookback_M15+10;i++){
            double o=iOpen(_Symbol,PERIOD_M15,i), c=iClose(_Symbol,PERIOD_M15,i);
            double h=iHigh(_Symbol,PERIOD_M15,i), l=iLow(_Symbol,PERIOD_M15,i);
            if(c>=o) continue;
            if(!BOS_Recente(i, PERIOD_M15, h, 1)) continue;
            datetime ot=iTime(_Symbol,PERIOD_M15,i);
            if(OB_Bloqueado(ot)) continue;
            if(preco>=l && preco<=o){
               g_ob_low=l; g_ob_high=o; g_ob_time=ot; g_direcao=1; g_ob_tf="M15"; g_bos_candle_idx=1;
               if(!TemFVGValido(1)) continue;
               if(!DiscountPremiumValido(1)) continue;
               if(!SMT_DXY_Valido(1)) continue;
               g_estado=EM_ZONA; g_velas_na_zona=0;
               FixarSwings();
               Print(">>> ZONA OB M15 BUY | ",DoubleToString(l,_Digits)," - ",DoubleToString(o,_Digits));
               return;
            }
         }
      }
      if(tendencia_baixa){
         for(int i=2;i<=OB_Lookback_M15+10;i++){
            double o=iOpen(_Symbol,PERIOD_M15,i), c=iClose(_Symbol,PERIOD_M15,i);
            double h=iHigh(_Symbol,PERIOD_M15,i), l=iLow(_Symbol,PERIOD_M15,i);
            if(c<=o) continue;
            if(!BOS_Recente(i, PERIOD_M15, l, -1)) continue;
            datetime ot=iTime(_Symbol,PERIOD_M15,i);
            if(OB_Bloqueado(ot)) continue;
            if(preco>=o && preco<=h){
               g_ob_low=o; g_ob_high=h; g_ob_time=ot; g_direcao=-1; g_ob_tf="M15"; g_bos_candle_idx=1;
               if(!TemFVGValido(-1)) continue;
               if(!DiscountPremiumValido(-1)) continue;
               if(!SMT_DXY_Valido(-1)) continue;
               g_estado=EM_ZONA; g_velas_na_zona=0;
               FixarSwings();
               Print(">>> ZONA OB M15 SELL | ",DoubleToString(o,_Digits)," - ",DoubleToString(h,_Digits));
               return;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Monitorar Sweep                                                  |
//+------------------------------------------------------------------+
void MonitorarSweep()
{
   double preco=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double atr_m1=ObterATRM1();
   if(atr_m1<=0) return;
   g_velas_na_zona++;
   if(g_velas_na_zona>=Timeout_Velas_M1){ BloquearOB(g_ob_time); Print("Timeout. OB bloqueado."); ResetEstado(); return; }
   if(preco<g_ob_low-10*_Point || preco>g_ob_high+10*_Point){ ResetEstado(); return; }

   if(Entrada_Direta_OB && g_direcao==1 && ConfirmacaoBigPlayer() && iClose(_Symbol,PERIOD_M1,1)>g_ob_high){
      g_sweep_low=MathMin(iLow(_Symbol,PERIOD_M1,1),g_swing_low_ref);
      g_sweep_time=TimeCurrent();
      Print(">>> DISPLACEMENT OB + RSI | entrada no rastro institucional");
      ExecutarEntrada();
      return;
   }
   if(Entrada_Direta_OB && g_direcao==-1 && ConfirmacaoBigPlayer() && iClose(_Symbol,PERIOD_M1,1)<g_ob_low){
      g_sweep_high=MathMax(iHigh(_Symbol,PERIOD_M1,1),g_swing_high_ref);
      g_sweep_time=TimeCurrent();
      Print(">>> DISPLACEMENT OB + RSI | entrada sell no rastro institucional");
      ExecutarEntrada();
      return;
   }

   double atr_sweep = atr_m1 * ATR_Sweep_Min;
   double lv=iLow(_Symbol,PERIOD_M1,1), hv=iHigh(_Symbol,PERIOD_M1,1), cv=iClose(_Symbol,PERIOD_M1,1);
   if(g_direcao==1 && lv<(g_swing_low_ref - atr_sweep) && cv>g_swing_low_ref){
      g_sweep_low=lv; g_estado=SWEEP_OK; g_sweep_time=TimeCurrent();
      Print(">>> SWEEP | mín: ",DoubleToString(lv,_Digits)," | aguarda displacement + RSI");
   }
   else if(g_direcao==-1 && hv>(g_swing_high_ref + atr_sweep) && cv<g_swing_high_ref){
      g_sweep_high=hv; g_estado=SWEEP_OK; g_sweep_time=TimeCurrent();
      Print(">>> SWEEP SELL | max: ",DoubleToString(hv,_Digits)," | aguarda displacement + RSI");
   }
}

//+------------------------------------------------------------------+
//| Confirmação Big Player                                           |
//+------------------------------------------------------------------+
bool ConfirmacaoBigPlayer()
{
   double atr_m1=ObterATRM1();
   if(atr_m1<=0) return false;
   double rsi[2];
   if(CopyBuffer(g_rsi_handle,0,1,2,rsi)<2) return false;

   double o=iOpen(_Symbol,PERIOD_M1,1);
   double c=iClose(_Symbol,PERIOD_M1,1);
   double h=iHigh(_Symbol,PERIOD_M1,1);
   double l=iLow(_Symbol,PERIOD_M1,1);
   double h_anterior=iHigh(_Symbol,PERIOD_M1,2);
   double l_anterior=iLow(_Symbol,PERIOD_M1,2);
   double displacement_efetivo=Displacement_Efetivo();
   double rsi_min_efetivo=RSI_Min_Efetivo();
   double range=h-l;
   if(range<=0) return false;

   double corpo=MathAbs(c-o);
   double corpo_ratio=corpo/range;
   double fechamento_topo=(h-c)/range;
   double fechamento_fundo=(c-l)/range;
   bool corpo_forte=(!Filtro_Candle_Sniper || corpo_ratio>=Candle_Corpo_Min_Ratio);

   if(g_direcao==1){
      bool candle_impulso=(c>o && (h-l)>=atr_m1*displacement_efetivo);
      bool quebrou_micro_high=(c>h_anterior || c>g_ob_high);
      bool rsi_momentum=(rsi[0]>=rsi_min_efetivo && rsi[0]>rsi[1]);
      bool fechamento_forte=(!Filtro_Candle_Sniper || fechamento_topo<=Candle_Fechamento_Extremo_Ratio);
      return (candle_impulso && corpo_forte && fechamento_forte && quebrou_micro_high && rsi_momentum);
   }

   bool candle_impulso=(c<o && (h-l)>=atr_m1*displacement_efetivo);
   bool quebrou_micro_low=(c<l_anterior || c<g_ob_low);
   double rsi_max_entrada=100.0-rsi_min_efetivo;
   bool rsi_momentum=(rsi[0]<=rsi_max_entrada && rsi[0]<rsi[1]);
   bool fechamento_forte=(!Filtro_Candle_Sniper || fechamento_fundo<=Candle_Fechamento_Extremo_Ratio);

   return (candle_impulso && corpo_forte && fechamento_forte && quebrou_micro_low && rsi_momentum);
}

void VerificarCHoCH()
{
   if(!DentroHorarioEntrada()){
      if(g_sweep_time==0 || TimeCurrent()-g_sweep_time > Sweep_Tolerancia_Min*60){
         ResetEstado(); return;
      }
   }
   if(!DentroHorarioNoticias()){ ResetEstado(); return; }

   datetime va=iTime(_Symbol,PERIOD_M1,0);
   if(va!=g_ultima_vela_m1){
      g_ultima_vela_m1=va; g_velas_na_zona++;

      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      if((g_direcao==1 && g_sweep_low>0 && ask<=g_sweep_low) ||
         (g_direcao==-1 && g_sweep_high>0 && bid>=g_sweep_high)){
         Print("Sweep invalidado antes da entrada. Setup descartado.");
         ResetEstado();
         return;
      }

      if(ConfirmacaoBigPlayer()){ ExecutarEntrada(); return; }
      if(g_velas_na_zona>=Timeout_Velas_M1){
         BloquearOB(g_ob_time);
         Print("Timeout displacement/RSI. OB bloqueado.");
         ResetEstado();
      }
   }
}

//+------------------------------------------------------------------+
//| Executar Entrada + Diagnóstico                                   |
//+------------------------------------------------------------------+
void ExecutarEntrada()
{
   if(!DentroHorarioEntrada()){
      if(g_sweep_time==0 || TimeCurrent()-g_sweep_time > Sweep_Tolerancia_Min*60){
         ResetEstado(); return;
      }
   }
   if(!DentroHorarioNoticias()){ ResetEstado(); return; }
   if(!ATRContextoValido(true)){ ResetEstado(); return; }

   long spread_atual = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_atual > Max_Spread_Pontos) {
      Print(">>> ABORTADO: Spread alto (", spread_atual, " pts). Limite: ", Max_Spread_Pontos);
      ResetEstado(); return;
   }

   double atr=ObterATR();
   double atr_m1=ObterATRM1();
   double entrada=(g_direcao==1 ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID));
   double sl=(g_direcao==1 ? g_sweep_low-3*_Point : g_sweep_high+3*_Point);

   if((g_direcao==1 && g_sweep_low>0 && entrada<=g_sweep_low) ||
      (g_direcao==-1 && g_sweep_high>0 && entrada>=g_sweep_high)){
      Print("Entrada descartada: preco voltou contra o sweep | entrada: ",
            DoubleToString(entrada,_Digits));
      ResetEstado();
      return;
   }

   double spread_pts = spread_atual * _Point;
   double dist = 0;
   if(g_direcao==1) {
      dist = (entrada - sl);
      if(dist < spread_pts) dist = spread_pts;
   } else {
      dist = (sl - entrada);
      if(dist < spread_pts) dist = spread_pts;
   }

   if((g_direcao==1 && (g_sweep_low<=0 || sl>=entrada)) ||
      (g_direcao==-1 && (g_sweep_high<=0 || sl<=entrada))){
      Print("SL invalido | entrada: ",DoubleToString(entrada,_Digits)," | SL: ",DoubleToString(sl,_Digits));
      ResetEstado(); return;
   }

   double atr_stop_min_efetivo=ATR_Stop_Min;
   if(ATR_Stop_Min_Max_Efetivo>0 && atr_stop_min_efetivo>ATR_Stop_Min_Max_Efetivo)
      atr_stop_min_efetivo=ATR_Stop_Min_Max_Efetivo;

   if(dist<atr*atr_stop_min_efetivo){
      Print("Stop curto (",DoubleToString(dist/_Point,1)," pts). Skip.");
      ResetEstado(); return;
   }
   if(dist>atr*ATR_Stop_Max){
      Print("Stop largo (",DoubleToString(dist/_Point,1)," pts). Skip.");
      ResetEstado(); return;
   }

   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double lote=NormalizeDouble(Risco_Euros/((dist/ts)*tv),2);
   lote=MathMax(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),
        MathMin(MathMin(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),2.0),lote));
   g_lote_original=lote;

   double rr_efetivo=RR_Ratio;
   if(RR_Max_Efetivo>0 && rr_efetivo>RR_Max_Efetivo) rr_efetivo=RR_Max_Efetivo;

   double o_conf=iOpen(_Symbol,PERIOD_M1,1);
   double c_conf=iClose(_Symbol,PERIOD_M1,1);
   double h_conf=iHigh(_Symbol,PERIOD_M1,1);
   double l_conf=iLow(_Symbol,PERIOD_M1,1);
   double range_conf=h_conf-l_conf;
   bool candle_rr_forte=false;
   if(Usar_RR_Sniper_Dinamico && range_conf>0){
      double corpo_ratio=MathAbs(c_conf-o_conf)/range_conf;
      double fechamento_topo=(h_conf-c_conf)/range_conf;
      double fechamento_fundo=(c_conf-l_conf)/range_conf;
      if(g_direcao==1)
         candle_rr_forte=(c_conf>o_conf && corpo_ratio>=Candle_Corpo_RR_Forte && fechamento_topo<=Candle_Fechamento_RR_Forte);
      else
         candle_rr_forte=(c_conf<o_conf && corpo_ratio>=Candle_Corpo_RR_Forte && fechamento_fundo<=Candle_Fechamento_RR_Forte);
   }
   if(candle_rr_forte && RR_Sniper_Forte>rr_efetivo) rr_efetivo=RR_Sniper_Forte;

   double tp=NormalizeDouble((g_direcao==1 ? entrada+dist*rr_efetivo : entrada-dist*rr_efetivo),_Digits);
   sl=NormalizeDouble(sl,_Digits);
   entrada=NormalizeDouble(entrada,_Digits);

   // === PREENCHER DIAGNÓSTICO ===
   double rsi_val=50;
   double rsi_buf[1]; if(CopyBuffer(g_rsi_handle,0,1,1,rsi_buf)>0) rsi_val=rsi_buf[0];
   PreencherDiagnosticoEntrada(
      (g_direcao==1 ? "BUY" : "SELL"),
      g_ob_tf,
      atr, atr_m1, rsi_val, dist/_Point, rr_efetivo,
      TemFVGValido(g_direcao), g_bos_candle_idx, spread_atual
   );

   Print("Entrada ",(g_direcao==1 ? "BUY" : "SELL"),": ",entrada,
         " | SL: ",sl," (",DoubleToString(dist/_Point,1)," pts)",
         " | TP: ",tp," | RR: ",DoubleToString(rr_efetivo,2),
         " | Forte: ",(candle_rr_forte ? "sim" : "nao"),
         " | Lote: ",lote,
         " | Spread: ",spread_atual," pts");

   bool ordem_ok=false;
   if(g_direcao==1) ordem_ok=trade.Buy(lote,_Symbol,entrada,sl,tp,"SMC_Sniper_v3.5.1");
   else ordem_ok=trade.Sell(lote,_Symbol,entrada,sl,tp,"SMC_Sniper_v3.5.1");

   if(ordem_ok){
      Print(">>> ORDEM ABERTA");
      g_estado=EM_TRADE;
      g_breakeven_feito=false;
      g_partial_feito=false;
      g_pyramid_feito=false;
   }
   else{
      Print("Erro: ",trade.ResultRetcode()," - ",trade.ResultRetcodeDescription());
      g_diag_ativo=false;
      ResetEstado();
   }
}

//+------------------------------------------------------------------+
//| Gestão — Breakeven                                               |
//+------------------------------------------------------------------+
void GerirBreakeven()
{
   if(g_breakeven_feito) return;
   for(int i=PositionsTotal()-1;i>=0;i--){
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=Magic) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      long tipo=PositionGetInteger(POSITION_TYPE);
      double ep=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double be_ratio_efetivo=Breakeven_Ratio;
      if(Breakeven_Max_Efetivo>0 && be_ratio_efetivo>Breakeven_Max_Efetivo)
         be_ratio_efetivo=Breakeven_Max_Efetivo;
      double lock_r=Breakeven_Lock_R; if(lock_r<0) lock_r=0;

      if(tipo==POSITION_TYPE_BUY && (bid-ep)>=(ep-sl)*be_ratio_efetivo){
         double nsl=NormalizeDouble(ep+(ep-sl)*lock_r,_Digits);
         if(sl<nsl){
            trade.PositionModify(ticket,nsl,PositionGetDouble(POSITION_TP));
            g_breakeven_feito=true;
            Print(">>> BE em ",nsl," | lock: ",DoubleToString(lock_r,2),"R");
         }
      }
      else if(tipo==POSITION_TYPE_SELL && (ep-ask)>=(sl-ep)*be_ratio_efetivo){
         double nsl=NormalizeDouble(ep-(sl-ep)*lock_r,_Digits);
         if(sl>nsl){
            trade.PositionModify(ticket,nsl,PositionGetDouble(POSITION_TP));
            g_breakeven_feito=true;
            Print(">>> BE em ",nsl," | lock: ",DoubleToString(lock_r,2),"R");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Gestão — Partials em 2R                                          |
//+------------------------------------------------------------------+
void GerirPartials()
{
   if(!Usar_Partials_2R || g_partial_feito) return;
   for(int i=PositionsTotal()-1;i>=0;i--){
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=Magic) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;

      long tipo=PositionGetInteger(POSITION_TYPE);
      double ep=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);
      double vol=PositionGetDouble(POSITION_VOLUME);
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double dist=MathAbs(ep-sl);
      if(dist<=0) continue;

      bool atingiu_2r=false;
      if(tipo==POSITION_TYPE_BUY && (bid-ep)>=dist*2.0) atingiu_2r=true;
      if(tipo==POSITION_TYPE_SELL && (ep-ask)>=dist*2.0) atingiu_2r=true;

      if(atingiu_2r){
         double fechar_vol=NormalizeDouble(vol*Partials_Ratio,2);
         double min_lot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
         if(fechar_vol>=min_lot && (vol-fechar_vol)>=min_lot){
            if(trade.PositionClosePartial(ticket,fechar_vol)){
               g_partial_feito=true;
               Print(">>> PARTIAL 2R | Fechado: ",DoubleToString(fechar_vol,2)," lotes (",DoubleToString(Partials_Ratio*100,0),"%)");
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Gestão — Pyramiding em 1R                                        |
//+------------------------------------------------------------------+
void GerirPyramiding()
{
   if(!Usar_Pyramiding || g_pyramid_feito || g_lote_original<=0) return;
   for(int i=PositionsTotal()-1;i>=0;i--){
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=Magic) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;

      long tipo=PositionGetInteger(POSITION_TYPE);
      double ep=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double dist=MathAbs(ep-sl);
      if(dist<=0) continue;

      bool atingiu_1r=false;
      if(tipo==POSITION_TYPE_BUY && (bid-ep)>=dist*1.0) atingiu_1r=true;
      if(tipo==POSITION_TYPE_SELL && (ep-ask)>=dist*1.0) atingiu_1r=true;

      if(atingiu_1r){
         double lote_add=NormalizeDouble(g_lote_original*Pyramid_Ratio,2);
         double min_lot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
         if(lote_add<min_lot) return;

         bool ordem_ok=false;
         if(tipo==POSITION_TYPE_BUY)
            ordem_ok=trade.Buy(lote_add,_Symbol,SymbolInfoDouble(_Symbol,SYMBOL_ASK),ep,0,"SMC_Pyramid");
         else
            ordem_ok=trade.Sell(lote_add,_Symbol,SymbolInfoDouble(_Symbol,SYMBOL_BID),ep,0,"SMC_Pyramid");

         if(ordem_ok){
            g_pyramid_feito=true;
            Print(">>> PYRAMID 1R | Adicionado: ",DoubleToString(lote_add,2)," lotes @ BE");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Gestão — Trailing Híbrido (desligado por padrão)                 |
//+------------------------------------------------------------------+
double SwingLowM15(int lados)
{
   for(int shift=1+lados; shift<20; shift++){
      double low=iLow(_Symbol, PERIOD_M15,shift);
      bool ok=true;
      for(int i=1;i<=lados;i++){
         if(low>=iLow(_Symbol,PERIOD_M15,shift-i)) ok=false;
         if(low>=iLow(_Symbol,PERIOD_M15,shift+i)) ok=false;
      }
      if(ok) return low;
   }
   return 0;
}

double SwingHighM15(int lados)
{
   for(int shift=1+lados; shift<20; shift++){
      double high=iHigh(_Symbol, PERIOD_M15,shift);
      bool ok=true;
      for(int i=1;i<=lados;i++){
         if(high<=iHigh(_Symbol,PERIOD_M15,shift-i)) ok=false;
         if(high<=iHigh(_Symbol,PERIOD_M15,shift+i)) ok=false;
      }
      if(ok) return high;
   }
   return 0;
}

void GerirTrailing()
{
   if(!Usar_Trailing_Estrutura) return;
   double atr = ObterATR();
   if(atr <= 0) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      long tipo = PositionGetInteger(POSITION_TYPE);
      double sl = PositionGetDouble(POSITION_SL);
      datetime tempo_abertura = (datetime)PositionGetInteger(POSITION_TIME);
      int barra_abertura = iBarShift(_Symbol, PERIOD_M1, tempo_abertura);
      if(barra_abertura < 0) continue;

      double novo_sl = sl;
      double candidato = 0;

      if(tipo == POSITION_TYPE_BUY)
      {
         int highest_index = iHighest(_Symbol, PERIOD_M1, MODE_HIGH, barra_abertura + 1, 0);
         if(highest_index < 0) continue;
         double max_price = iHigh(_Symbol, PERIOD_M1, highest_index);

         double cand_atr = max_price - (Trailing_ATR_Multiplier * atr);
         double swing_m15 = SwingLowM15(2);
         double cand_swing = (swing_m15 > 0) ? swing_m15 : cand_atr;

         candidato = MathMax(cand_atr, cand_swing);

         if(candidato > sl + 10*_Point && candidato < SymbolInfoDouble(_Symbol, SYMBOL_BID))
            novo_sl = candidato;
      }
      else if(tipo == POSITION_TYPE_SELL)
      {
         int lowest_index = iLowest(_Symbol, PERIOD_M1, MODE_LOW, barra_abertura + 1, 0);
         if(lowest_index < 0) continue;
         double min_price = iLow(_Symbol, PERIOD_M1, lowest_index);

         double cand_atr = min_price + (Trailing_ATR_Multiplier * atr);
         double swing_m15 = SwingHighM15(2);
         double cand_swing = (swing_m15 > 0) ? swing_m15 : cand_atr;

         candidato = MathMin(cand_atr, cand_swing);

         if(candidato < sl - 10*_Point && candidato > SymbolInfoDouble(_Symbol, SYMBOL_ASK))
            novo_sl = candidato;
      }

      if(novo_sl != sl)
      {
         novo_sl = NormalizeDouble(novo_sl, _Digits);
         if(trade.PositionModify(ticket, novo_sl, PositionGetDouble(POSITION_TP)))
            Print(">>> TRAILING | Novo SL: ", DoubleToString(novo_sl, _Digits));
      }
   }
}

//+------------------------------------------------------------------+
//| Verificar Saída e Logar Diagnóstico                              |
//+------------------------------------------------------------------+
void VerificarSaidaDiagnostico()
{
   if(!g_diag_ativo) return;

   // Procura posição fechada com nosso magic
   HistorySelect(0, TimeCurrent());
   for(int i=HistoryDealsTotal()-1; i>=0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != Magic) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;

      // Se encontrou deal fechado, verifica se já logamos
      datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      if(deal_time > g_diag.hora_entrada)
      {
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         double comissao = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
         double lucro_total = profit + comissao + swap;

         // Calcular lucro em R
         double ep = HistoryDealGetDouble(ticket, DEAL_PRICE);
         double sl_price = 0; // não disponível direto no deal, estimamos
         double dist_r = MathAbs(g_diag.stop_pts * _Point);
         double lucro_r = (dist_r > 0) ? lucro_total / (dist_r / _Point * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE)) : 0;
         // Simplificação: usamos o profit em relação ao risco em euros
         lucro_r = lucro_total / Risco_Euros;

         string res = (lucro_total > 0) ? "WIN" : ((lucro_total < 0) ? "LOSS" : "BE");
         string motivo = "UNKNOWN";

         // Tenta inferir motivo
         if(g_breakeven_feito && MathAbs(lucro_total) < Risco_Euros * 0.1) motivo = "BE";
         else if(g_partial_feito && lucro_total > 0) motivo = "PARTIAL+TP";
         else if(lucro_total > 0) motivo = "TP";
         else if(lucro_total < 0) motivo = "SL";

         AtualizarDiagnosticoSaida(res, lucro_r, motivo);
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| OnInit / OnDeinit                                                |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   trade.SetDeviationInPoints(10);
   g_estado=SCANNING; g_bloqueio_count=0;
   g_atr_handle=iATR(_Symbol,PERIOD_H1,ATR_Period);
   if(g_atr_handle==INVALID_HANDLE){ Print("Erro ATR H1"); return INIT_FAILED; }
   g_atr_m1_handle=iATR(_Symbol,PERIOD_M1,ATR_Period);
   if(g_atr_m1_handle==INVALID_HANDLE){ Print("Erro ATR M1"); return INIT_FAILED; }
   g_ema_h1_handle=iMA(_Symbol,PERIOD_H1,Tendencia_EMA_H1,0,MODE_EMA,PRICE_CLOSE);
   if(g_ema_h1_handle==INVALID_HANDLE){ Print("Erro EMA H1"); return INIT_FAILED; }
   ENUM_TIMEFRAMES rsi_tf_efetivo=RSI_TF_Efetivo();
   g_rsi_handle=iRSI(_Symbol,rsi_tf_efetivo,RSI_Period,PRICE_CLOSE);
   if(g_rsi_handle==INVALID_HANDLE){ Print("Erro RSI"); return INIT_FAILED; }

   IniciarDiagnostico();

   Print("=== SMC SNIPER v3.5.1 LAB ===");
   Print("FVG: ", Usar_FVG_Confluence ? "ATIVO" : "OFF");
   Print("Trailing: ", Usar_Trailing_Estrutura ? "ATIVO" : "OFF (testar depois)");
   Print("Partials: ", Usar_Partials_2R ? "ATIVO" : "OFF (testar depois)");
   Print("Pyramiding: ", Usar_Pyramiding ? "ATIVO" : "OFF");
   Print("SMT/DXY: ", Usar_SMT_DXY ? "ATIVO" : "OFF (corrigido)");
   Print("Discount/Premium: ", Usar_Discount_Premium ? "ATIVO" : "OFF");
   Print("CSV Log: ", Salvar_Log_CSV ? "ATIVO" : "OFF");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_atr_handle!=INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   if(g_atr_m1_handle!=INVALID_HANDLE) IndicatorRelease(g_atr_m1_handle);
   if(g_ema_h1_handle!=INVALID_HANDLE) IndicatorRelease(g_ema_h1_handle);
   if(g_rsi_handle!=INVALID_HANDLE) IndicatorRelease(g_rsi_handle);
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   if(g_estado==EM_TRADE){
      if(!TemPosicaoAberta()){
         // Posição fechada — logar resultado
         VerificarSaidaDiagnostico();
         if(Bloquear_OB_Apos_Trade && g_ob_time>0) BloquearOB(g_ob_time);
         ResetEstado();
         return;
      }
      GerirBreakeven();
      if(Usar_Partials_2R) GerirPartials();
      if(Usar_Pyramiding) GerirPyramiding();
      if(Usar_Trailing_Estrutura) GerirTrailing();
      return;
   }
   if(g_estado==SWEEP_OK){ VerificarCHoCH(); return; }
   datetime va=iTime(_Symbol,PERIOD_M1,0);
   if(va==g_ultima_vela_m1) return;
   g_ultima_vela_m1=va;
   if(g_estado==SCANNING) ProcurarOB();
   else if(g_estado==EM_ZONA) MonitorarSweep();
}
//+------------------------------------------------------------------+
