//+------------------------------------------------------------------+
//|  SMC Sniper v3.5.20                                              |
//|  Filtro H1: EMA + swing direcional para compra e venda          |
//+------------------------------------------------------------------+
#property copyright "SMC Sniper"
#property version   "3.70"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

input bool     Perfil_V27_Travado    = true; // Usa o perfil que teve PF 3.42 e ignora presets ruins
input bool     Modo_Robusto_MultiAno = true; // Ignora gatilhos que ficaram bons so em 2025
input double   Risco_Euros           = 3.0;
input double   Risco_Prop_Euros      = 25.0; // Ataque controlado: 0.5% em conta de 5k
input double   RR_Ratio              = 3.0;
input double   RR_Max_Efetivo        = 2.0;  // Perfil sniper: alvo mais perto aumenta realizacao
input bool     Usar_RR_Sniper_Dinamico = true; // Candle muito forte pode buscar alvo maior
input double   RR_Sniper_Forte       = 2.8;
input double   Breakeven_Ratio       = 2.0;
input double   Breakeven_Max_Efetivo = 1.2;  // Presets antigos com BE tarde deixam lucro voltar
input double   Breakeven_Lock_R      = 0.25; // Ao proteger, trava parte do risco em lucro
input bool     Breakeven_Lock_Dinamico = true; // Se o fluxo continua forte, protege mais lucro
input double   Breakeven_Lock_R_Forte = 0.45;
input double   Breakeven_Lock_RSI_Buy_Min = 55.0;
input double   Breakeven_Lock_RSI_Sell_Max = 45.0;
input int      OB_Lookback_H1        = 5;
input bool     Usar_OB_M15_Sniper    = false; // Modo prop: M15 ficou negativo no diagnostico, manter desligado ate revalidar
input int      OB_Lookback_M15       = 12;
input int      Swing_Lookback_M1     = 40;   // JANELA para procurar swings M1 (normal 40-80)
input int      Swing_Lookback_Min_Efetivo = 40; // Protege presets antigos com lookback curto
input int      Swing_Confirmacao_M1  = 2;    // CONFIRMACAO lateral do swing M1 (normal 1-3)
input int      Swing_Confirmacao_Max_Efetivo = 3; // Evita usar 40 como confirmacao lateral
input int      Timeout_Velas_M1      = 120;
input int      Bloqueio_Horas_OB     = 4;
input int      ATR_Period            = 14;
input double   ATR_Sweep_Min         = 0.2;
input bool     Usar_Sweep_Borda_OB_H1 = false; // Experimental: aumentou trades, mas perdeu edge no EURUSD 2025
input double   Sweep_Borda_OB_ATR_Min = 0.15; // Mantem sweep da borda com deslocamento minimo real
input double   ATR_Stop_Min          = 0.15;
input double   ATR_Stop_Min_Max_Efetivo = 0.15; // Protege presets antigos demasiado restritivos
input double   ATR_Stop_Max          = 5.0;
input double   ATR_Minimo            = 0.00005;
input double   ATR_H1_Min_Pontos     = 60.0;  // Evita mercado morto antes da sessao
input double   ATR_H1_Max_Pontos     = 220.0; // Evita volatilidade extrema/noticia
input double   ATR_M1_Min_Pontos     = 5.0;   // Confirma que ha movimento local
input double   ATR_M1_Max_Pontos     = 45.0;  // Evita spike local excessivo
input ENUM_TIMEFRAMES RSI_Timeframe  = PERIOD_M30;
input ENUM_TIMEFRAMES RSI_Timeframe_Min_Efetivo = PERIOD_M30; // Evita ruido M1/M5 no momentum
input ENUM_TIMEFRAMES RSI_Timeframe_Max_Efetivo = PERIOD_M30; // Perfil validado na v2.7
input int      RSI_Period            = 14;
input double   RSI_Min_Entrada       = 52.0;  // Momentum comprador minimo apos sweep
input double   RSI_Min_Entrada_Max_Efetivo = 52.0; // Mantem o filtro que funcionou na v2.7
input double   RSI_Neutro            = 50.0;  // Linha de viragem de momentum
input double   Displacement_ATR_M1   = 0.8;   // Candle de impulso minimo em ATR M1
input double   Displacement_ATR_M1_Max_Efetivo = 0.8; // 0.6 trouxe ruido na v2.8
input bool     Usar_Stop_Curto_Sniper = true; // Stop curto pode ser sniper se o impulso for muito limpo
input bool     Stop_Curto_Apenas_London = true;
input double   Stop_Curto_Min_Pontos = 25.0;
input double   Stop_Curto_Displacement_ATR_M1 = 1.15;
input double   Stop_Curto_Corpo_Min_Ratio = 0.70;
input double   Stop_Curto_Fechamento_Extremo = 0.15;
input bool     Filtro_Candle_Sniper  = true;  // Exige candle de confirmacao com corpo e fechamento fortes
input double   Candle_Corpo_Min_Ratio= 0.55;  // Corpo minimo do candle de confirmacao
input double   Candle_Fechamento_Extremo_Ratio = 0.25; // Fecha no quarto forte do candle
input double   Candle_Corpo_RR_Forte = 0.70;  // Corpo para liberar alvo maior
input double   Candle_Fechamento_RR_Forte = 0.15; // Fechamento extremo para alvo maior
input bool     Usar_Confirmacao_Rastro_Sniper = true; // Pos-sweep: entrada mais rapida sem exigir CHoCH perfeito
input double   Rastro_Displacement_ATR_M1 = 0.55;
input double   Rastro_Corpo_Min_Ratio = 0.45;
input double   Rastro_Fechamento_Extremo_Ratio = 0.35;
input double   Rastro_RSI_Buy_Min = 58.0;
input double   Rastro_RSI_Sell_Max = 42.0;
input bool     Entrada_Direta_OB     = false; // Sem sweep: mais trades, menor qualidade
input bool     Bloquear_OB_Apos_Trade= true;  // Evita insistir na mesma zona apos saida
input bool     Usar_Asian_Sweep      = false; // Experimental: fora de 2025 ainda nao provou robustez
input int      Asia_Inicio           = 0;
input int      Asia_Fim              = 7;
input int      Asian_Sweep_Inicio    = 8;     // Prioriza abertura Londres
input int      Asian_Sweep_Fim       = 10;
input double   Asian_Sweep_ATR_Min   = 0.15;  // Sweep minimo em ATR M1
input double   Asian_Sweep_Stop_Max_Pontos = 90.0; // Sweep de sessao precisa ser rapido/sniper
input bool     Usar_London_Sweep_NY  = false; // Experimental: LONDON_SWEEP perdeu robustez fora de 2025
input int      London_Range_Inicio   = 8;
input int      London_Range_Fim      = 11;
input int      London_Sweep_Inicio   = 13;
input int      London_Sweep_Fim      = 16;
input double   London_Sweep_ATR_Min  = 0.15;
input double   London_Sweep_Stop_Max_Pontos = 180.0; // Evita entrar tarde em varredura extensa
input double   Session_Sweep_RSI_Buy_Min = 52.0;  // Sweeps alternativos exigem momentum claro
input double   Session_Sweep_RSI_Sell_Max = 48.0;
input bool     Usar_Filtro_Momentum_NY = true; // NY precisa confirmar direcao, evita entrada neutra
input double   NY_RSI_Buy_Min       = 52.0;
input double   NY_RSI_Sell_Max      = 46.0;
input bool     Usar_FVG_H1           = false; // Desligado: FVG H1 adicionou frequencia, mas perdeu edge no EURUSD 2025
input int      FVG_Lookback_H1       = 24;
input double   FVG_Min_Pontos        = 8.0;
input double   FVG_Max_Pontos        = 120.0;
input bool     Usar_Filtro_Sessao    = true;
input int      Sessao1_Inicio        = 8;     // Abertura Londres
input int      Sessao1_Fim           = 10;
input int      Sessao1_Fim_Min_Efetivo = 10;  // Nao estender sem validacao
input bool     Usar_FollowThrough_London_H1 = true; // Da tempo extra apenas para sweep H1 classico ja formado em Londres
input int      FollowThrough_London_Fim = 11;
input int      FollowThrough_London_Fim_Forte = 12; // Ate 12h apenas com RSI muito direcional
input double   FollowThrough_RSI_Buy_Min = 58.0;
input double   FollowThrough_RSI_Sell_Max = 42.0;
input double   FollowThrough_London_Stop_Max_Pontos = 130.0;
input int      Sessao2_Inicio        = 13;    // Abertura America/NY
input int      Sessao2_Fim           = 16;
input int      Sessao2_Fim_Min_Efetivo = 16;  // Nao estender sem validacao
input bool     Operar_Apenas_Sessao1 = false; // Teste baseline: desliga Sessao2/NY. Follow-through de Londres (ate 11-12h) continua ativo.
input bool     Permitir_London_Sweep_NY_Em_Robusto = false; // Libera Usar_London_Sweep_NY mesmo com Modo_Robusto_MultiAno ativo, p/ teste A/B
input bool     Usar_Bloqueio_Horario_Fixo_Noticia = false; // Bloqueio por horario de servidor, independente do CSV de noticias
input int      Bloqueio_Horario_Fixo_Inicio_Min = 915; // Formato HMM (ex: 915 = 09:15, 1515 = 15:15)
input int      Bloqueio_Horario_Fixo_Fim_Min   = 1000; // Formato HMM (ex: 1000 = 10:00, 1600 = 16:00)
input int      Tendencia_EMA_H1      = 20;   // EMA H1 usada como filtro direcional
input int      Tendencia_Lookback_H1 = 40;   // Velas H1 para procurar os dois swing highs
input int      Tendencia_Swing_Lados = 2;    // Velas de cada lado para confirmar swing high
input double   Tendencia_EMA_Buffer_Pontos = 10.0; // Evita alternar BUY/SELL colado na EMA
input bool     Tendencia_Exigir_EMA_Inclinada = true;
input int      Magic                 = 20260201;
input bool     Magic_Auto_Por_Simbolo = true; // Portfolio: magic separado para cada ativo
input int      Max_Spread_Pontos     = 25;   // Protecao v3.5: evita entrada com spread ruim
input bool     Salvar_Log_CSV        = true; // Diagnostico leve, sem alterar entrada
input string   Nome_Arquivo_CSV      = "SMC_Sniper_Log.csv";
input bool     CSV_Limpar_No_Inicio  = false; // Portfolio: preserve varios simbolos no mesmo diagnostico
input bool     Modo_Mesa_Proprietaria = true; // Controle de risco/consistencia para prop firm
input double   Prop_Conta_Base       = 5000.0; // Blue Guardian Instant Standard mostrado pelo usuario
input double   Prop_Max_Daily_Loss_Pct = 3.0;
input double   Prop_Max_Loss_Pct     = 6.0;
input double   Prop_Usar_Limite_Pct  = 0.70; // Buffer: usa 70% da regra e para antes da violacao
input double   Prop_Max_Perda_Dia_Euros = 0.0; // 0 = usa percentual; >0 = limite absoluto adicional
input int      Prop_Reset_Hora_Servidor = 22; // Ajustar para o horario do reset diario da conta
input int      Prop_Max_Trades_Dia   = 3;
input bool     Prop_CircuitBreaker_Semanal = true; // Para de insistir quando o regime da semana fica ruim
input int      Prop_Max_Perdas_Consecutivas_Semana = 2;
input bool     Prop_Bloquear_Sexta_Tarde = true;
input int      Prop_Sexta_Hora_Limite = 17;
input bool     Usar_Filtro_Noticias  = true; // Blue Guardian: evitar janela de noticias high impact
input string   Noticias_Arquivo_CSV  = "SMC_News_HighImpact.csv";
input int      Noticias_CSV_Para_Servidor_Horas = 0; // soma ao horario do CSV para virar horario do servidor
input int      Noticias_Min_Antes    = 15; // Conservador: evita abrir trade que possa fechar dentro da janela de 5 min
input int      Noticias_Min_Depois   = 5;
input bool     Noticias_FailSafe_Bloquear = true; // Se CSV faltar/corromper, bloqueia entradas
input string   Noticias_Moedas       = "EUR,USD";

enum ENUM_ESTADO { SCANNING, EM_ZONA, SWEEP_OK, EM_TRADE };
ENUM_ESTADO g_estado = SCANNING;

double   g_ob_low=0, g_ob_high=0;
datetime g_ob_time=0;
double   g_swing_low_ref=0, g_swing_high_ref=0, g_sweep_low=0, g_sweep_high=0;
int      g_direcao=1;
string   g_ob_tf="NA";
string   g_sweep_sessao="NA";
bool     g_breakeven_feito=false;
bool     g_confirmacao_rastro_atual=false;
int      g_velas_na_zona=0;
datetime g_ultima_vela_m1=0;
int      g_atr_handle=INVALID_HANDLE;
int      g_atr_m1_handle=INVALID_HANDLE;
int      g_ema_h1_handle=INVALID_HANDLE;
int      g_rsi_handle=INVALID_HANDLE;
int      g_magic_efetivo=0;
datetime g_bloqueio_ob_time[20];
datetime g_bloqueio_expira[20];
int      g_bloqueio_count=0;
int      g_dia_controle=-1;
int      g_trades_dia=0;
int      g_semana_controle=-1;
int      g_perdas_consecutivas_semana=0;
double   g_anchor_diario=0;
double   g_equity_max_conta=0;
bool     g_bloqueado_dia=false;
bool     g_bloqueado_semana=false;
bool     g_bloqueado_conta=false;
bool     g_noticias_carregadas=false;
bool     g_noticias_falha=false;
int      g_noticias_count=0;
int      g_asia_dia=-1;
double   g_asia_high=0;
double   g_asia_low=0;
bool     g_asia_sweep_usado=false;
int      g_london_dia=-1;
double   g_london_high=0;
double   g_london_low=0;
bool     g_london_sweep_usado=false;
int      g_dbg_zonas_h1=0;
int      g_dbg_zonas_fvg=0;
int      g_dbg_sweeps=0;
int      g_dbg_sweeps_borda_ob=0;
int      g_dbg_entradas=0;
int      g_dbg_timeout_zona=0;
int      g_dbg_timeout_confirmacao=0;
int      g_dbg_stop_curto=0;
int      g_dbg_stop_largo=0;

struct DiagnosticoTrade
{
   string   simbolo;
   datetime hora_entrada;
   string   direcao;
   string   sessao;
   string   ob_tf;
   double   atr_h1;
   double   atr_m1;
   double   rsi;
   double   stop_pts;
   double   rr_efetivo;
   long     spread_pts;
   datetime hora_saida;
   string   resultado;
   double   lucro_r;
   string   motivo_saida;
};

DiagnosticoTrade g_diag;
bool g_diag_ativo=false;

struct NoticiaImpacto
{
   datetime hora_servidor;
   string   moeda;
   string   impacto;
   string   titulo;
};

NoticiaImpacto g_noticias[];

ENUM_TIMEFRAMES RSI_TF_Efetivo()
{
   if(Perfil_V27_Travado) return PERIOD_M30;

   ENUM_TIMEFRAMES tf=RSI_Timeframe;
   if(RSI_Timeframe_Min_Efetivo>0 && (int)tf<(int)RSI_Timeframe_Min_Efetivo)
      tf=RSI_Timeframe_Min_Efetivo;
   if(RSI_Timeframe_Max_Efetivo>0 && (int)tf>(int)RSI_Timeframe_Max_Efetivo)
      tf=RSI_Timeframe_Max_Efetivo;
   return tf;
}

double Risco_Efetivo()
{
   if(Modo_Mesa_Proprietaria && Risco_Prop_Euros>0)
      return Risco_Prop_Euros;
   return Risco_Euros;
}

int MagicEfetivo()
{
   if(!Magic_Auto_Por_Simbolo)
      return Magic;

   int hash=0;
   int len=StringLen(_Symbol);
   for(int i=0;i<len;i++){
      hash=(hash*31+StringGetCharacter(_Symbol,i))%900000;
   }
   return Magic+hash;
}

double RSI_Min_Efetivo()
{
   if(Perfil_V27_Travado) return 52.0;

   double valor=RSI_Min_Entrada;
   if(RSI_Min_Entrada_Max_Efetivo>0 && valor>RSI_Min_Entrada_Max_Efetivo)
      valor=RSI_Min_Entrada_Max_Efetivo;
   if(valor<RSI_Neutro)
      valor=RSI_Neutro;
   return valor;
}

double Displacement_Efetivo()
{
   if(Perfil_V27_Travado) return 0.8;

   double valor=Displacement_ATR_M1;
   if(Displacement_ATR_M1_Max_Efetivo>0 && valor>Displacement_ATR_M1_Max_Efetivo)
      valor=Displacement_ATR_M1_Max_Efetivo;
   return valor;
}

bool UsarOBM15Efetivo()
{
   if(Perfil_V27_Travado || Modo_Mesa_Proprietaria) return false;
   return Usar_OB_M15_Sniper;
}

bool UsarAsianSweepEfetivo()
{
   if(Modo_Robusto_MultiAno) return false;
   return Usar_Asian_Sweep;
}

bool UsarLondonSweepEfetivo()
{
   if(Operar_Apenas_Sessao1) return false;
   if(Modo_Robusto_MultiAno && !Permitir_London_Sweep_NY_Em_Robusto) return false;
   return Usar_London_Sweep_NY;
}

bool UsarFollowThroughEfetivo()
{
   if(Modo_Robusto_MultiAno) return false;
   return Usar_FollowThrough_London_H1;
}

bool UsarFiltroNoticiasEfetivo()
{
   if(Modo_Mesa_Proprietaria) return true;
   return Usar_Filtro_Noticias;
}

int SessaoFim1_Efetivo()
{
   if(Perfil_V27_Travado) return Sessao1_Fim;

   int fim=Sessao1_Fim;
   if(Sessao1_Fim_Min_Efetivo>0 && fim<Sessao1_Fim_Min_Efetivo)
      fim=Sessao1_Fim_Min_Efetivo;
   return fim;
}

int SessaoFim2_Efetivo()
{
   if(Perfil_V27_Travado) return Sessao2_Fim;

   int fim=Sessao2_Fim;
   if(Sessao2_Fim_Min_Efetivo>0 && fim<Sessao2_Fim_Min_Efetivo)
      fim=Sessao2_Fim_Min_Efetivo;
   return fim;
}

string SessaoAtual()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(),dt);
   int h=dt.hour;
   if(h>=Sessao1_Inicio && h<=SessaoFim1_Efetivo()) return "LONDON";
   if(h>=Sessao2_Inicio && h<=SessaoFim2_Efetivo()) return "NY";
   return "OUTSIDE";
}

string TextoUpper(string valor)
{
   string texto=valor;
   StringToUpper(texto);
   return texto;
}

bool NoticiaMoedaPermitida(string moeda)
{
   string moedas=","+TextoUpper(Noticias_Moedas)+",";
   string alvo=","+TextoUpper(moeda)+",";
   return (StringFind(moedas,alvo)>=0);
}

bool NoticiaImpactoAlto(string impacto)
{
   string valor=TextoUpper(impacto);
   return (StringFind(valor,"HIGH")>=0 ||
           StringFind(valor,"RED")>=0 ||
           StringFind(valor,"ALTO")>=0 ||
           valor=="3");
}

datetime ParseDataNoticia(string valor)
{
   string texto=valor;
   StringReplace(texto,"-",".");
   StringReplace(texto,"T"," ");
   StringReplace(texto,"Z","");
   return StringToTime(texto);
}

string CampoCSV(string valor)
{
   string texto=valor;
   StringTrimLeft(texto);
   StringTrimRight(texto);
   return texto;
}

void CarregarNoticiasCSV()
{
   g_noticias_carregadas=false;
   g_noticias_falha=false;
   g_noticias_count=0;
   ArrayResize(g_noticias,0);

   if(!UsarFiltroNoticiasEfetivo()) return;

   int handle=FileOpen(Noticias_Arquivo_CSV,FILE_READ|FILE_TXT|FILE_COMMON|FILE_ANSI);
   if(handle==INVALID_HANDLE){
      g_noticias_falha=true;
      Print("NEWS FILTER: CSV nao encontrado em Common\\Files\\",Noticias_Arquivo_CSV,
            " | entradas ",(Noticias_FailSafe_Bloquear ? "bloqueadas" : "permitidas por fail-open"));
      return;
   }

   int linhas=0;
   int invalidas=0;
   while(!FileIsEnding(handle)){
      string linha=FileReadString(handle);
      linhas++;
      if(StringLen(linha)<=0) continue;

      string partes[];
      int n=StringSplit(linha,',',partes);
      if(n<3){ invalidas++; continue; }

      string data_txt=CampoCSV(partes[0]);
      string moeda=CampoCSV(partes[1]);
      string impacto=CampoCSV(partes[2]);
      string titulo="";
      for(int k=3;k<n;k++){
         if(k>3) titulo+=",";
         titulo+=CampoCSV(partes[k]);
      }

      datetime hora_csv=ParseDataNoticia(data_txt);
      if(hora_csv<=0) continue;
      if(!NoticiaMoedaPermitida(moeda)) continue;
      if(!NoticiaImpactoAlto(impacto)) continue;

      int idx=g_noticias_count;
      ArrayResize(g_noticias,idx+1);
      g_noticias[idx].hora_servidor=hora_csv+(Noticias_CSV_Para_Servidor_Horas*3600);
      g_noticias[idx].moeda=moeda;
      g_noticias[idx].impacto=impacto;
      g_noticias[idx].titulo=titulo;
      g_noticias_count++;
   }

   FileClose(handle);
   g_noticias_carregadas=true;
   Print("NEWS FILTER: ",g_noticias_count,
         " noticias high impact carregadas de ",Noticias_Arquivo_CSV,
         " | linhas lidas: ",linhas,
         " | invalidas: ",invalidas,
         " | offset CSV->servidor: ",Noticias_CSV_Para_Servidor_Horas,"h");
}

bool DentroHorarioFixoNoticia(datetime agora)
{
   if(!Usar_Bloqueio_Horario_Fixo_Noticia) return false;

   MqlDateTime dt;
   TimeToStruct(agora,dt);
   int agora_hmm=dt.hour*100+dt.min;

   int ini=Bloqueio_Horario_Fixo_Inicio_Min;
   int fim=Bloqueio_Horario_Fixo_Fim_Min;
   if(ini==fim) return false;

   if(ini<fim) return (agora_hmm>=ini && agora_hmm<=fim);
   return (agora_hmm>=ini || agora_hmm<=fim); // janela cruza a meia-noite
}

bool DentroJanelaNoticia(datetime agora, string &motivo)
{
   motivo="";

   if(DentroHorarioFixoNoticia(agora)){
      motivo="Bloqueio horario fixo de noticia (janela configurada)";
      return true;
   }

   if(!UsarFiltroNoticiasEfetivo()) return false;

   if(!g_noticias_carregadas){
      if(!g_noticias_falha) CarregarNoticiasCSV();
      if(!g_noticias_carregadas && Noticias_FailSafe_Bloquear){
         motivo="CSV de noticias indisponivel";
         return true;
      }
      return false;
   }

   int antes=MathMax(0,Noticias_Min_Antes)*60;
   int depois=MathMax(0,Noticias_Min_Depois)*60;

   for(int i=0;i<g_noticias_count;i++){
      datetime ini=g_noticias[i].hora_servidor-antes;
      datetime fim=g_noticias[i].hora_servidor+depois;
      if(agora>=ini && agora<=fim){
         motivo=StringFormat("%s %s %s",
                             TimeToString(g_noticias[i].hora_servidor,TIME_DATE|TIME_MINUTES),
                             g_noticias[i].moeda,
                             g_noticias[i].titulo);
         return true;
      }
   }

   return false;
}

void IniciarDiagnosticoCSV()
{
   if(!Salvar_Log_CSV) return;

   string header="Simbolo,Hora_Entrada,Direcao,Sessao,OB_TF,ATR_H1,ATR_M1,RSI,Stop_Pts,RR_Efetivo,Spread_Entrada,Hora_Saida,Resultado,Lucro_R,Motivo_Saida\n";
   if(CSV_Limpar_No_Inicio){
      int clean=FileOpen(Nome_Arquivo_CSV,FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,',');
      if(clean==INVALID_HANDLE){
         Print("ERRO ao limpar CSV diagnostico: ",GetLastError());
         return;
      }
      FileWriteString(clean,header);
      FileClose(clean);
      return;
   }

   int handle=FileOpen(Nome_Arquivo_CSV,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,',');
   if(handle==INVALID_HANDLE)
      handle=FileOpen(Nome_Arquivo_CSV,FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,',');

   if(handle==INVALID_HANDLE){
      Print("ERRO ao criar CSV diagnostico: ",GetLastError());
      return;
   }

   if(FileSize(handle)<10){
      FileClose(handle);
      handle=FileOpen(Nome_Arquivo_CSV,FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,',');
      if(handle==INVALID_HANDLE){
         Print("ERRO ao recriar CSV diagnostico: ",GetLastError());
         return;
      }
      FileWriteString(handle,header);
   }
   FileClose(handle);
}

void PrepararDiagnosticoEntrada(string direcao, double atr_h1, double atr_m1,
                                double rsi, double stop_pts, double rr_efetivo,
                                long spread_pts)
{
   g_diag.hora_entrada=TimeCurrent();
   g_diag.simbolo=_Symbol;
   g_diag.direcao=direcao;
   g_diag.sessao=SessaoAtual();
   if(g_diag.sessao=="OUTSIDE" && DentroHorarioFollowThroughLondon())
      g_diag.sessao="LONDON_FT";
   g_diag.ob_tf=g_ob_tf;
   g_diag.atr_h1=atr_h1;
   g_diag.atr_m1=atr_m1;
   g_diag.rsi=rsi;
   g_diag.stop_pts=stop_pts;
   g_diag.rr_efetivo=rr_efetivo;
   g_diag.spread_pts=spread_pts;
   g_diag.hora_saida=0;
   g_diag.resultado="OPEN";
   g_diag.lucro_r=0;
   g_diag.motivo_saida="";
   g_diag_ativo=true;
}

void SalvarDiagnosticoCSV()
{
   if(!Salvar_Log_CSV || !g_diag_ativo) return;

   int handle=FileOpen(Nome_Arquivo_CSV,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,',');
   if(handle==INVALID_HANDLE){
      Print("ERRO ao abrir CSV diagnostico: ",GetLastError());
      return;
   }

   FileSeek(handle,0,SEEK_END);
   string linha=StringFormat("%s,%s,%s,%s,%s,%.5f,%.5f,%.2f,%.1f,%.2f,%d,%s,%s,%.2f,%s",
      g_diag.simbolo,
      TimeToString(g_diag.hora_entrada,TIME_DATE|TIME_SECONDS),
      g_diag.direcao,
      g_diag.sessao,
      g_diag.ob_tf,
      g_diag.atr_h1,
      g_diag.atr_m1,
      g_diag.rsi,
      g_diag.stop_pts,
      g_diag.rr_efetivo,
      g_diag.spread_pts,
      g_diag.hora_saida>0 ? TimeToString(g_diag.hora_saida,TIME_DATE|TIME_SECONDS) : "",
      g_diag.resultado,
      g_diag.lucro_r,
      g_diag.motivo_saida
   );
   FileWriteString(handle,linha+"\n");
   FileClose(handle);
}

void RegistrarResultadoTrade(double lucro)
{
   if(!Modo_Mesa_Proprietaria || !Prop_CircuitBreaker_Semanal)
      return;

   if(lucro<0)
      g_perdas_consecutivas_semana++;
   else
      g_perdas_consecutivas_semana=0;

   if(Prop_Max_Perdas_Consecutivas_Semana>0 &&
      g_perdas_consecutivas_semana>=Prop_Max_Perdas_Consecutivas_Semana){
      g_bloqueado_semana=true;
      Print("Prop guard: circuit breaker semanal acionado apos ",
            g_perdas_consecutivas_semana,
            " perdas consecutivas. Novas entradas bloqueadas ate a proxima semana.");
   }
}

void FinalizarDiagnosticoSeFechou()
{
   if(!g_diag_ativo) return;
   if(!HistorySelect(g_diag.hora_entrada,TimeCurrent())) return;

   for(int i=HistoryDealsTotal()-1;i>=0;i--){
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0) continue;
      if(HistoryDealGetInteger(deal,DEAL_MAGIC)!=g_magic_efetivo) continue;
      if(HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol) continue;
      long entry=HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(entry!=DEAL_ENTRY_OUT && entry!=DEAL_ENTRY_INOUT) continue;

      double lucro=HistoryDealGetDouble(deal,DEAL_PROFIT)+
                   HistoryDealGetDouble(deal,DEAL_COMMISSION)+
                   HistoryDealGetDouble(deal,DEAL_SWAP);
      g_diag.hora_saida=(datetime)HistoryDealGetInteger(deal,DEAL_TIME);
      g_diag.resultado=(lucro>0 ? "WIN" : (lucro<0 ? "LOSS" : "BE"));
      double risco_ref=Risco_Efetivo();
      g_diag.lucro_r=(risco_ref>0 ? lucro/risco_ref : 0);
      g_diag.motivo_saida=(lucro>0 ? "TP/PROFIT" : (lucro<0 ? "SL/LOSS" : "BE"));
      RegistrarResultadoTrade(lucro);
      SalvarDiagnosticoCSV();
      g_diag_ativo=false;
      return;
   }
}

double PropLimiteUso()
{
   if(Prop_Usar_Limite_Pct<=0) return 0.70;
   if(Prop_Usar_Limite_Pct>1.0) return 1.0;
   return Prop_Usar_Limite_Pct;
}

double PropContaBase()
{
   if(Prop_Conta_Base>0) return Prop_Conta_Base;

   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance>0) return balance;

   return AccountInfoDouble(ACCOUNT_EQUITY);
}

int ChaveDiaProp(datetime agora)
{
   MqlDateTime dt;
   TimeToStruct(agora,dt);

   if(Prop_Reset_Hora_Servidor>=0 && Prop_Reset_Hora_Servidor<=23 && dt.hour<Prop_Reset_Hora_Servidor)
      agora-=86400;

   TimeToStruct(agora,dt);
   return dt.year*1000+dt.day_of_year;
}

int ChaveDiaCalendario(datetime agora)
{
   MqlDateTime dt;
   TimeToStruct(agora,dt);
   return dt.year*1000+dt.day_of_year;
}

int ChaveSemanaCalendario(datetime agora)
{
   MqlDateTime dt;
   TimeToStruct(agora,dt);
   return dt.year*100+(dt.day_of_year/7);
}

void AtualizarControleSemanal()
{
   int chave=ChaveSemanaCalendario(TimeCurrent());
   if(chave==g_semana_controle) return;

   g_semana_controle=chave;
   g_perdas_consecutivas_semana=0;
   g_bloqueado_semana=false;
   Print("Prop guard: nova semana operacional. Circuit breaker resetado.");
}

void AtualizarControleDiario()
{
   AtualizarControleSemanal();

   double equity=AccountInfoDouble(ACCOUNT_EQUITY);

   if(g_equity_max_conta<=0 || equity>g_equity_max_conta)
      g_equity_max_conta=equity;

   int chave=ChaveDiaProp(TimeCurrent());

   if(chave!=g_dia_controle){
      g_dia_controle=chave;
      g_trades_dia=0;
      g_anchor_diario=MathMax(AccountInfoDouble(ACCOUNT_BALANCE),equity);
      g_bloqueado_dia=false;
      Print("Prop guard: novo dia operacional. Anchor diario: ",
            DoubleToString(g_anchor_diario,2),
            " | Equity max conta: ",DoubleToString(g_equity_max_conta,2));
   }
}

bool PropRiscoFinanceiroAtingido()
{
   if(!Modo_Mesa_Proprietaria) return false;

   AtualizarControleDiario();

   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double conta_base=PropContaBase();
   double uso=PropLimiteUso();

   if(Prop_Max_Loss_Pct>0 && conta_base>0){
      double limite_total=conta_base*(Prop_Max_Loss_Pct/100.0)*uso;
      double perda_total=g_equity_max_conta-equity;
      if(perda_total>=limite_total){
         if(!g_bloqueado_conta)
            Print("Prop guard: perda maxima/trailing protegida. Perda: ",
                  DoubleToString(perda_total,2),
                  " | Limite interno: ",DoubleToString(limite_total,2));
         g_bloqueado_conta=true;
         return true;
      }
   }

   if(Prop_Max_Daily_Loss_Pct>0 || Prop_Max_Perda_Dia_Euros>0){
      double limite_diario=conta_base*(Prop_Max_Daily_Loss_Pct/100.0);
      if(Prop_Max_Perda_Dia_Euros>0 && (limite_diario<=0 || Prop_Max_Perda_Dia_Euros<limite_diario))
         limite_diario=Prop_Max_Perda_Dia_Euros;
      limite_diario*=uso;

      double perda_dia=g_anchor_diario-equity;
      if(limite_diario>0 && perda_dia>=limite_diario){
         if(!g_bloqueado_dia)
            Print("Prop guard: perda diaria protegida. Perda: ",
                  DoubleToString(perda_dia,2),
                  " | Limite interno: ",DoubleToString(limite_diario,2),
                  " | Anchor: ",DoubleToString(g_anchor_diario,2));
         g_bloqueado_dia=true;
         return true;
      }
   }

   return false;
}

bool MesaProprietariaPermiteEntrada()
{
   string motivo_noticia="";
   if(DentroJanelaNoticia(TimeCurrent(),motivo_noticia)){
      if(!g_bloqueado_dia)
         Print("NEWS FILTER: entrada bloqueada | ",motivo_noticia);
      return false;
   }

   if(!Modo_Mesa_Proprietaria) return true;

   AtualizarControleDiario();

   if(g_bloqueado_conta) return false;
   if(g_bloqueado_semana){
      Print("Prop guard: semana bloqueada pelo circuit breaker. Sem novas entradas.");
      return false;
   }
   if(PropRiscoFinanceiroAtingido()) return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(),dt);

   if(Prop_Bloquear_Sexta_Tarde && dt.day_of_week==5 && dt.hour>=Prop_Sexta_Hora_Limite){
      if(!g_bloqueado_dia)
         Print("Prop guard: sexta apos horario limite. Novas entradas bloqueadas.");
      g_bloqueado_dia=true;
      return false;
   }

   if(Prop_Max_Trades_Dia>0 && g_trades_dia>=Prop_Max_Trades_Dia){
      if(!g_bloqueado_dia)
         Print("Prop guard: maximo de trades do dia atingido: ",g_trades_dia);
      g_bloqueado_dia=true;
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
int OnInit()
{
   g_magic_efetivo=MagicEfetivo();
   trade.SetExpertMagicNumber(g_magic_efetivo);
   trade.SetDeviationInPoints(10);
   g_estado=SCANNING; g_bloqueio_count=0;
   g_atr_handle=iATR(_Symbol,PERIOD_H1,ATR_Period);
   if(g_atr_handle==INVALID_HANDLE){ Print("Erro ATR"); return INIT_FAILED; }
   g_atr_m1_handle=iATR(_Symbol,PERIOD_M1,ATR_Period);
   if(g_atr_m1_handle==INVALID_HANDLE){ Print("Erro ATR M1"); return INIT_FAILED; }
   g_ema_h1_handle=iMA(_Symbol,PERIOD_H1,Tendencia_EMA_H1,0,MODE_EMA,PRICE_CLOSE);
   if(g_ema_h1_handle==INVALID_HANDLE){ Print("Erro EMA H1"); return INIT_FAILED; }
   ENUM_TIMEFRAMES rsi_tf_efetivo=RSI_TF_Efetivo();
   g_rsi_handle=iRSI(_Symbol,rsi_tf_efetivo,RSI_Period,PRICE_CLOSE);
   if(g_rsi_handle==INVALID_HANDLE){ Print("Erro RSI"); return INIT_FAILED; }
   IniciarDiagnosticoCSV();
   CarregarNoticiasCSV();
   AtualizarControleDiario();
   Print("SMC Sniper v3.5.20 | Big player trail: OB H1 + sweep + displacement + RSI TF + NY momentum + robust multi-year mode");
   Print("MAGIC EFETIVO | simbolo: ",_Symbol," | magic: ",g_magic_efetivo);
   if(Modo_Robusto_MultiAno)
      Print("MODO ROBUSTO MULTI-ANO ATIVO | session sweeps e follow-through experimental ignorados.");
   if(Perfil_V27_Travado)
      Print("PERFIL V2.7 TRAVADO | RSI M30 | RSI min 52 | displacement 0.8 | sessoes sem extensao");
   if(Filtro_Candle_Sniper)
      Print("FILTRO CANDLE SNIPER | corpo min: ",DoubleToString(Candle_Corpo_Min_Ratio,2),
            " | fechamento extremo: ",DoubleToString(Candle_Fechamento_Extremo_Ratio,2));
   if(Usar_RR_Sniper_Dinamico)
      Print("RR SNIPER DINAMICO | alvo forte: ",DoubleToString(RR_Sniper_Forte,2),
            "R | corpo: ",DoubleToString(Candle_Corpo_RR_Forte,2),
            " | fechamento: ",DoubleToString(Candle_Fechamento_RR_Forte,2));
   if((int)rsi_tf_efetivo!=(int)RSI_Timeframe)
      Print("RSI_Timeframe input ajustado para perfil validado: ",EnumToString(RSI_Timeframe),
            " -> ",EnumToString(rsi_tf_efetivo));
   if(!Perfil_V27_Travado && RSI_Min_Entrada_Max_Efetivo>0 && RSI_Min_Entrada>RSI_Min_Entrada_Max_Efetivo)
      Print("RSI_Min_Entrada input capado: ",DoubleToString(RSI_Min_Entrada,1),
            " -> ",DoubleToString(RSI_Min_Entrada_Max_Efetivo,1));
   if(!Perfil_V27_Travado && Displacement_ATR_M1_Max_Efetivo>0 && Displacement_ATR_M1>Displacement_ATR_M1_Max_Efetivo)
      Print("Displacement_ATR_M1 input capado: ",DoubleToString(Displacement_ATR_M1,2),
            " -> ",DoubleToString(Displacement_ATR_M1_Max_Efetivo,2));
   if(!Perfil_V27_Travado && Sessao1_Fim_Min_Efetivo>0 && Sessao1_Fim<Sessao1_Fim_Min_Efetivo)
      Print("Sessao Londres estendida para follow-through: ",Sessao1_Fim,
            " -> ",Sessao1_Fim_Min_Efetivo);
   if(!Perfil_V27_Travado && Sessao2_Fim_Min_Efetivo>0 && Sessao2_Fim<Sessao2_Fim_Min_Efetivo)
      Print("Sessao NY estendida para follow-through: ",Sessao2_Fim,
            " -> ",Sessao2_Fim_Min_Efetivo);
   if(RR_Max_Efetivo>0 && RR_Ratio>RR_Max_Efetivo)
      Print("RR_Ratio input capado para perfil sniper: ",DoubleToString(RR_Ratio,2),
            " -> ",DoubleToString(RR_Max_Efetivo,2));
   if(Breakeven_Max_Efetivo>0 && Breakeven_Ratio>Breakeven_Max_Efetivo)
      Print("Breakeven_Ratio input capado para perfil sniper: ",DoubleToString(Breakeven_Ratio,2),
            " -> ",DoubleToString(Breakeven_Max_Efetivo,2));
   if(ATR_Stop_Min_Max_Efetivo>0 && ATR_Stop_Min>ATR_Stop_Min_Max_Efetivo)
      Print("ATR_Stop_Min input capado para perfil sniper: ",DoubleToString(ATR_Stop_Min,2),
            " -> ",DoubleToString(ATR_Stop_Min_Max_Efetivo,2));
   if(Swing_Lookback_Min_Efetivo>0 && Swing_Lookback_M1<Swing_Lookback_Min_Efetivo)
      Print("Swing_Lookback_M1 input aumentado para perfil sniper: ",Swing_Lookback_M1,
            " -> ",Swing_Lookback_Min_Efetivo);
   if(Swing_Confirmacao_Max_Efetivo>0 && Swing_Confirmacao_M1>Swing_Confirmacao_Max_Efetivo)
      Print("Swing_Confirmacao_M1 input capado: ",Swing_Confirmacao_M1,
            " -> ",Swing_Confirmacao_Max_Efetivo);
   if(Usar_OB_M15_Sniper && !UsarOBM15Efetivo())
      Print("OB M15 input ignorado no perfil prop/validado: true -> false");
   if(!Usar_Filtro_Noticias && UsarFiltroNoticiasEfetivo())
      Print("Filtro de noticias forcado pelo Modo_Mesa_Proprietaria: false -> true");
   if(Modo_Mesa_Proprietaria)
      Print("MODO PROP ATIVO | Conta base: ",DoubleToString(PropContaBase(),2),
            " | Risco/trade: ",DoubleToString(Risco_Efetivo(),2),
            " | Daily: ",DoubleToString(Prop_Max_Daily_Loss_Pct,2),
            "% | Max: ",DoubleToString(Prop_Max_Loss_Pct,2),
            "% | Uso interno: ",DoubleToString(PropLimiteUso()*100.0,1),
            "% | Reset servidor: ",Prop_Reset_Hora_Servidor);
   if(UsarAsianSweepEfetivo())
      Print("ASIAN SWEEP ATIVO | Asia: ",Asia_Inicio,"-",Asia_Fim,
            " | gatilho: ",Asian_Sweep_Inicio,"-",Asian_Sweep_Fim,
            " | sweep ATR M1 min: ",DoubleToString(Asian_Sweep_ATR_Min,2));
   if(UsarLondonSweepEfetivo())
      Print("LONDON SWEEP NY ATIVO | range: ",London_Range_Inicio,"-",London_Range_Fim,
            " | gatilho: ",London_Sweep_Inicio,"-",London_Sweep_Fim,
            " | sweep ATR M1 min: ",DoubleToString(London_Sweep_ATR_Min,2));
   Print("HORARIO SERVIDOR ATUAL: ",TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
         " | use este valor para validar o reset diario da mesa");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   Print("DIAGNOSTICO SMC | zonas H1: ",g_dbg_zonas_h1,
          " | zonas FVG: ",g_dbg_zonas_fvg,
          " | sweeps: ",g_dbg_sweeps,
          " | sweeps borda OB: ",g_dbg_sweeps_borda_ob,
          " | entradas: ",g_dbg_entradas,
         " | timeout zona: ",g_dbg_timeout_zona,
         " | timeout confirmacao: ",g_dbg_timeout_confirmacao,
         " | stop curto: ",g_dbg_stop_curto,
         " | stop largo: ",g_dbg_stop_largo);

   if(g_atr_handle!=INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   if(g_atr_m1_handle!=INVALID_HANDLE) IndicatorRelease(g_atr_m1_handle);
   if(g_ema_h1_handle!=INVALID_HANDLE) IndicatorRelease(g_ema_h1_handle);
   if(g_rsi_handle!=INVALID_HANDLE) IndicatorRelease(g_rsi_handle);
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
//| Filtro de tendencia H1                                          |
//| Preco acima da EMA H1 e ultimo swing high acima do anterior      |
//+------------------------------------------------------------------+
bool SwingHighH1(const int shift, const int lados)
{
   double high=iHigh(_Symbol,PERIOD_H1,shift);
   if(high<=0) return false;

   for(int i=1;i<=lados;i++)
   {
      if(high<=iHigh(_Symbol,PERIOD_H1,shift-i)) return false;
      if(high<=iHigh(_Symbol,PERIOD_H1,shift+i)) return false;
   }
   return true;
}

bool SwingLowH1(const int shift, const int lados)
{
   double low=iLow(_Symbol,PERIOD_H1,shift);
   if(low<=0) return false;

   for(int i=1;i<=lados;i++)
   {
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

   int lados=Tendencia_Swing_Lados;
   if(lados<1) lados=1;

   int lookback=Tendencia_Lookback_H1;
   int lookback_minimo=lados*2+5;
   if(lookback<lookback_minimo) lookback=lookback_minimo;
   if(Bars(_Symbol,PERIOD_H1)<lookback+lados+2) return false;

   double ultimo_swing=0;
   double swing_anterior=0;

   for(int shift=1+lados;shift<=lookback;shift++)
   {
      if(!SwingHighH1(shift,lados)) continue;
      if(ultimo_swing==0) ultimo_swing=iHigh(_Symbol,PERIOD_H1,shift);
      else{
         swing_anterior=iHigh(_Symbol,PERIOD_H1,shift);
         break;
      }
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

   int lados=Tendencia_Swing_Lados;
   if(lados<1) lados=1;

   int lookback=Tendencia_Lookback_H1;
   int lookback_minimo=lados*2+5;
   if(lookback<lookback_minimo) lookback=lookback_minimo;
   if(Bars(_Symbol,PERIOD_H1)<lookback+lados+2) return false;

   double ultimo_swing=0;
   double swing_anterior=0;

   for(int shift=1+lados;shift<=lookback;shift++)
   {
      if(!SwingLowH1(shift,lados)) continue;
      if(ultimo_swing==0) ultimo_swing=iLow(_Symbol,PERIOD_H1,shift);
      else{
         swing_anterior=iLow(_Symbol,PERIOD_H1,shift);
         break;
      }
   }

   if(ultimo_swing==0 || swing_anterior==0) return false;
   return (ultimo_swing<swing_anterior);
}

//+------------------------------------------------------------------+
bool OB_Bloqueado(datetime t)
{
   datetime agora=TimeCurrent();
   for(int i=0;i<g_bloqueio_count;i++)
      if(g_bloqueio_ob_time[i]==t && agora<g_bloqueio_expira[i]) return true;
   return false;
}

bool DentroHorarioEntrada()
{
   if(!Usar_Filtro_Sessao) return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(),dt);
   int h=dt.hour;

   int fim1=SessaoFim1_Efetivo();
   bool sessao1=(h>=Sessao1_Inicio && h<=fim1);
   if(Operar_Apenas_Sessao1) return sessao1;

   int fim2=SessaoFim2_Efetivo();
   bool sessao2=(h>=Sessao2_Inicio && h<=fim2);
   return (sessao1 || sessao2);
}

bool DentroHorarioFollowThroughLondon()
{
   if(!UsarFollowThroughEfetivo() || !Usar_Filtro_Sessao) return false;
   if(g_ob_tf!="H1" || g_sweep_sessao!="LONDON") return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(),dt);
   int h=dt.hour;

   int fim=FollowThrough_London_Fim;
   int fim_forte=FollowThrough_London_Fim_Forte;
   if(fim_forte<fim) fim_forte=fim;

   if(fim<=Sessao1_Fim) return false;
   if(h<=Sessao1_Fim || h>fim_forte) return false;
   if(h>=Sessao2_Inicio) return false;

   if(h>fim){
      double rsi[1];
      if(CopyBuffer(g_rsi_handle,0,1,1,rsi)<1) return false;
      if(g_direcao==1 && rsi[0]<FollowThrough_RSI_Buy_Min) return false;
      if(g_direcao==-1 && rsi[0]>FollowThrough_RSI_Sell_Max) return false;
   }

   return true;
}

bool DentroHorarioEntradaOuFollowThrough()
{
   return (DentroHorarioEntrada() || DentroHorarioFollowThroughLondon());
}

bool DentroHorarioAsianSweep()
{
   if(!UsarAsianSweepEfetivo()) return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(),dt);
   return (dt.hour>=Asian_Sweep_Inicio && dt.hour<=Asian_Sweep_Fim);
}

void AtualizarRangeAsia()
{
   if(!UsarAsianSweepEfetivo()) return;

   datetime vela=iTime(_Symbol,PERIOD_M1,1);
   if(vela<=0) return;

   int chave=ChaveDiaCalendario(vela);
   if(chave!=g_asia_dia){
      g_asia_dia=chave;
      g_asia_high=0;
      g_asia_low=0;
      g_asia_sweep_usado=false;
   }

   MqlDateTime dt;
   TimeToStruct(vela,dt);
   if(dt.hour<Asia_Inicio || dt.hour>Asia_Fim) return;

   double h=iHigh(_Symbol,PERIOD_M1,1);
   double l=iLow(_Symbol,PERIOD_M1,1);
   if(h<=0 || l<=0) return;

   if(g_asia_high==0 || h>g_asia_high) g_asia_high=h;
   if(g_asia_low==0 || l<g_asia_low) g_asia_low=l;
}

bool ProcurarAsianSweep()
{
   if(!UsarAsianSweepEfetivo() || g_asia_sweep_usado) return false;
   if(!DentroHorarioAsianSweep()) return false;
   if(g_asia_high<=0 || g_asia_low<=0) return false;

   double atr_m1=ObterATRM1();
   if(atr_m1<=0) return false;

   double sweep_min=atr_m1*Asian_Sweep_ATR_Min;
   double h=iHigh(_Symbol,PERIOD_M1,1);
   double l=iLow(_Symbol,PERIOD_M1,1);
   double c=iClose(_Symbol,PERIOD_M1,1);

   if(TendenciaDeAlta() && l<(g_asia_low-sweep_min) && c>g_asia_low){
      g_ob_low=g_asia_low;
      g_ob_high=g_asia_high;
      g_ob_time=iTime(_Symbol,PERIOD_M1,1);
      g_swing_low_ref=g_asia_low;
      g_swing_high_ref=g_asia_high;
      g_sweep_low=l;
      g_sweep_high=0;
      g_direcao=1;
      g_ob_tf="ASIA_SWEEP";
      g_estado=SWEEP_OK;
      g_velas_na_zona=0;
      g_asia_sweep_usado=true;
      Print(">>> ASIAN SWEEP BUY | low Asia: ",DoubleToString(g_asia_low,_Digits),
            " | sweep: ",DoubleToString(l,_Digits),
            " | aguarda displacement + RSI");
      return true;
   }

   if(TendenciaDeBaixa() && h>(g_asia_high+sweep_min) && c<g_asia_high){
      g_ob_low=g_asia_low;
      g_ob_high=g_asia_high;
      g_ob_time=iTime(_Symbol,PERIOD_M1,1);
      g_swing_low_ref=g_asia_low;
      g_swing_high_ref=g_asia_high;
      g_sweep_low=0;
      g_sweep_high=h;
      g_direcao=-1;
      g_ob_tf="ASIA_SWEEP";
      g_estado=SWEEP_OK;
      g_velas_na_zona=0;
      g_asia_sweep_usado=true;
      Print(">>> ASIAN SWEEP SELL | high Asia: ",DoubleToString(g_asia_high,_Digits),
            " | sweep: ",DoubleToString(h,_Digits),
            " | aguarda displacement + RSI");
      return true;
   }

   return false;
}

bool DentroHorarioLondonSweep()
{
   if(!UsarLondonSweepEfetivo()) return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(),dt);
   return (dt.hour>=London_Sweep_Inicio && dt.hour<=London_Sweep_Fim);
}

void AtualizarRangeLondon()
{
   if(!UsarLondonSweepEfetivo()) return;

   datetime vela=iTime(_Symbol,PERIOD_M1,1);
   if(vela<=0) return;

   int chave=ChaveDiaCalendario(vela);
   if(chave!=g_london_dia){
      g_london_dia=chave;
      g_london_high=0;
      g_london_low=0;
      g_london_sweep_usado=false;
   }

   MqlDateTime dt;
   TimeToStruct(vela,dt);
   if(dt.hour<London_Range_Inicio || dt.hour>London_Range_Fim) return;

   double h=iHigh(_Symbol,PERIOD_M1,1);
   double l=iLow(_Symbol,PERIOD_M1,1);
   if(h<=0 || l<=0) return;

   if(g_london_high==0 || h>g_london_high) g_london_high=h;
   if(g_london_low==0 || l<g_london_low) g_london_low=l;
}

bool ProcurarLondonSweep()
{
   if(!UsarLondonSweepEfetivo() || g_london_sweep_usado) return false;
   if(!DentroHorarioLondonSweep()) return false;
   if(g_london_high<=0 || g_london_low<=0) return false;

   double atr_m1=ObterATRM1();
   if(atr_m1<=0) return false;

   double sweep_min=atr_m1*London_Sweep_ATR_Min;
   double h=iHigh(_Symbol,PERIOD_M1,1);
   double l=iLow(_Symbol,PERIOD_M1,1);
   double c=iClose(_Symbol,PERIOD_M1,1);

   if(TendenciaDeAlta() && l<(g_london_low-sweep_min) && c>g_london_low){
      g_ob_low=g_london_low;
      g_ob_high=g_london_high;
      g_ob_time=iTime(_Symbol,PERIOD_M1,1);
      g_swing_low_ref=g_london_low;
      g_swing_high_ref=g_london_high;
      g_sweep_low=l;
      g_sweep_high=0;
      g_direcao=1;
      g_ob_tf="LONDON_SWEEP";
      g_estado=SWEEP_OK;
      g_velas_na_zona=0;
      g_london_sweep_usado=true;
      Print(">>> LONDON SWEEP BUY | low Londres: ",DoubleToString(g_london_low,_Digits),
            " | sweep: ",DoubleToString(l,_Digits),
            " | aguarda displacement + RSI");
      return true;
   }

   if(TendenciaDeBaixa() && h>(g_london_high+sweep_min) && c<g_london_high){
      g_ob_low=g_london_low;
      g_ob_high=g_london_high;
      g_ob_time=iTime(_Symbol,PERIOD_M1,1);
      g_swing_low_ref=g_london_low;
      g_swing_high_ref=g_london_high;
      g_sweep_low=0;
      g_sweep_high=h;
      g_direcao=-1;
      g_ob_tf="LONDON_SWEEP";
      g_estado=SWEEP_OK;
      g_velas_na_zona=0;
      g_london_sweep_usado=true;
      Print(">>> LONDON SWEEP SELL | high Londres: ",DoubleToString(g_london_high,_Digits),
            " | sweep: ",DoubleToString(h,_Digits),
            " | aguarda displacement + RSI");
      return true;
   }

   return false;
}

bool ATRContextoValido(const bool logar=false)
{
   double atr_h1=ObterATR();
   double atr_m1=ObterATRM1();
   if(atr_h1<=0 || atr_m1<=0) return false;

   double atr_h1_pts=atr_h1/_Point;
   double atr_m1_pts=atr_m1/_Point;
   bool valido=true;

   if(ATR_H1_Min_Pontos>0 && atr_h1_pts<ATR_H1_Min_Pontos) valido=false;
   if(ATR_H1_Max_Pontos>0 && atr_h1_pts>ATR_H1_Max_Pontos) valido=false;
   if(ATR_M1_Min_Pontos>0 && atr_m1_pts<ATR_M1_Min_Pontos) valido=false;
   if(ATR_M1_Max_Pontos>0 && atr_m1_pts>ATR_M1_Max_Pontos) valido=false;

   if(!valido && logar)
      Print("ATR fora do regime | H1: ",DoubleToString(atr_h1_pts,1),
            " pts | M1: ",DoubleToString(atr_m1_pts,1)," pts");

   return valido;
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

void ResetEstado()
{
   g_estado=SCANNING; g_ob_low=0; g_ob_high=0; g_ob_time=0;
   g_swing_low_ref=0; g_swing_high_ref=0; g_sweep_low=0; g_sweep_high=0;
   g_direcao=1;
   g_ob_tf="NA";
   g_sweep_sessao="NA";
   g_velas_na_zona=0; g_breakeven_feito=false;
   g_confirmacao_rastro_atual=false;
}

bool TemPosicaoAberta()
{
   for(int i=PositionsTotal()-1;i>=0;i--){
      ulong t=PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC)==g_magic_efetivo && PositionGetString(POSITION_SYMBOL)==_Symbol) return true;
   }
   return false;
}

bool SwingHighM1(const int shift, const int lados)
{
   double high=iHigh(_Symbol,PERIOD_M1,shift);
   if(high<=0) return false;

   for(int i=1;i<=lados;i++)
   {
      if(high<=iHigh(_Symbol,PERIOD_M1,shift-i)) return false;
      if(high<=iHigh(_Symbol,PERIOD_M1,shift+i)) return false;
   }
   return true;
}

bool SwingLowM1(const int shift, const int lados)
{
   double low=iLow(_Symbol,PERIOD_M1,shift);
   if(low<=0) return false;

   for(int i=1;i<=lados;i++)
   {
      if(low>=iLow(_Symbol,PERIOD_M1,shift-i)) return false;
      if(low>=iLow(_Symbol,PERIOD_M1,shift+i)) return false;
   }
   return true;
}

void FixarSwings()
{
   int lados=Swing_Confirmacao_M1;
   if(lados<1) lados=1;
   if(Swing_Confirmacao_Max_Efetivo>0 && lados>Swing_Confirmacao_Max_Efetivo)
      lados=Swing_Confirmacao_Max_Efetivo;

   g_swing_low_ref=0;
   g_swing_high_ref=0;

   int lookback=Swing_Lookback_M1;
   if(Swing_Lookback_Min_Efetivo>0 && lookback<Swing_Lookback_Min_Efetivo)
      lookback=Swing_Lookback_Min_Efetivo;
   int lookback_minimo=lados*2+5;
   if(lookback<lookback_minimo) lookback=lookback_minimo;

   for(int i=1+lados;i<=lookback;i++){
      if(g_swing_low_ref==0 && SwingLowM1(i,lados))
         g_swing_low_ref=iLow(_Symbol,PERIOD_M1,i);
      if(g_swing_high_ref==0 && SwingHighM1(i,lados))
         g_swing_high_ref=iHigh(_Symbol,PERIOD_M1,i);
      if(g_swing_low_ref>0 && g_swing_high_ref>0) return;
   }

   if(g_swing_low_ref==0) g_swing_low_ref=iLow(_Symbol,PERIOD_M1,1);
   if(g_swing_high_ref==0) g_swing_high_ref=iHigh(_Symbol,PERIOD_M1,1);
   for(int i=2;i<=lookback;i++){
      if(g_swing_low_ref==0 || iLow(_Symbol,PERIOD_M1,i)<g_swing_low_ref)
         g_swing_low_ref=iLow(_Symbol,PERIOD_M1,i);
      if(g_swing_high_ref==0 || iHigh(_Symbol,PERIOD_M1,i)>g_swing_high_ref)
         g_swing_high_ref=iHigh(_Symbol,PERIOD_M1,i);
   }
}

bool MomentumProtecaoForte(long tipo,double &rsi_atual)
{
   rsi_atual=0.0;
   if(!Breakeven_Lock_Dinamico || g_rsi_handle==INVALID_HANDLE)
      return false;

   double rsi[2];
   if(CopyBuffer(g_rsi_handle,0,1,2,rsi)<2)
      return false;

   rsi_atual=rsi[0];
   if(tipo==POSITION_TYPE_BUY)
      return (rsi[0]>=Breakeven_Lock_RSI_Buy_Min || (rsi[0]>RSI_Neutro && rsi[0]>rsi[1]));

   if(tipo==POSITION_TYPE_SELL)
      return (rsi[0]<=Breakeven_Lock_RSI_Sell_Max || (rsi[0]<RSI_Neutro && rsi[0]<rsi[1]));

   return false;
}

void GerirBreakeven()
{
   if(g_breakeven_feito) return;
   for(int i=PositionsTotal()-1;i>=0;i--){
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_magic_efetivo) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      long tipo=PositionGetInteger(POSITION_TYPE);
      double ep=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double be_ratio_efetivo=Breakeven_Ratio;
      if(Breakeven_Max_Efetivo>0 && be_ratio_efetivo>Breakeven_Max_Efetivo)
         be_ratio_efetivo=Breakeven_Max_Efetivo;
      double lock_r=Breakeven_Lock_R;
      if(lock_r<0) lock_r=0;
      double rsi_protecao=0.0;
      bool lock_dinamico=MomentumProtecaoForte(tipo,rsi_protecao);
      if(lock_dinamico && Breakeven_Lock_R_Forte>lock_r)
         lock_r=Breakeven_Lock_R_Forte;

      if(tipo==POSITION_TYPE_BUY && (bid-ep)>=(ep-sl)*be_ratio_efetivo){
         double nsl=NormalizeDouble(ep+(ep-sl)*lock_r,_Digits);
         if(sl<nsl){
            trade.PositionModify(ticket,nsl,PositionGetDouble(POSITION_TP));
            g_breakeven_feito=true;
            if(lock_dinamico)
               Print(">>> PROTECAO LUCRO em ",nsl,
                     " | lock: ",DoubleToString(lock_r,2),"R",
                     " | dinamico RSI: ",DoubleToString(rsi_protecao,2));
            else
               Print(">>> PROTECAO LUCRO em ",nsl,
                     " | lock: ",DoubleToString(lock_r,2),"R");
         }
      }
      else if(tipo==POSITION_TYPE_SELL && (ep-ask)>=(sl-ep)*be_ratio_efetivo){
         double nsl=NormalizeDouble(ep-(sl-ep)*lock_r,_Digits);
         if(sl>nsl){
            trade.PositionModify(ticket,nsl,PositionGetDouble(POSITION_TP));
            g_breakeven_feito=true;
            if(lock_dinamico)
               Print(">>> PROTECAO LUCRO em ",nsl,
                     " | lock: ",DoubleToString(lock_r,2),"R",
                     " | dinamico RSI: ",DoubleToString(rsi_protecao,2));
            else
               Print(">>> PROTECAO LUCRO em ",nsl,
                     " | lock: ",DoubleToString(lock_r,2),"R");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ESTADO 1 — Procura OB válido no H1 (só em tendência de alta)   |
//+------------------------------------------------------------------+
void ProcurarOB()
{
   double atr=ObterATR();
   if(atr<ATR_Minimo) return;
   if(!DentroHorarioEntrada()) return;
   if(!ATRContextoValido()) return;

   // Filtro de tendência — bloco mais importante
   bool tendencia_alta=TendenciaDeAlta();
   bool tendencia_baixa=TendenciaDeBaixa();
   if(!tendencia_alta && !tendencia_baixa) return;

   double preco=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(tendencia_alta){
   for(int i=2;i<=OB_Lookback_H1+10;i++){
      double o=iOpen(_Symbol,PERIOD_H1,i), c=iClose(_Symbol,PERIOD_H1,i);
      double h=iHigh(_Symbol,PERIOD_H1,i), l=iLow(_Symbol,PERIOD_H1,i);
      if(c>=o) continue;
      bool bos=false;
      for(int j=i-1;j>=1;j--) if(iClose(_Symbol,PERIOD_H1,j)>h){ bos=true; break; }
      if(!bos) continue;
      datetime ot=iTime(_Symbol,PERIOD_H1,i);
      if(OB_Bloqueado(ot)) continue;
      if(preco>=l && preco<=o){
         g_ob_low=l; g_ob_high=o; g_ob_time=ot; g_direcao=1; g_ob_tf="H1";
         g_estado=EM_ZONA; g_velas_na_zona=0;
         g_dbg_zonas_h1++;
         FixarSwings();
         Print(">>> ZONA OB H1 | ",DoubleToString(l,_Digits)," - ",DoubleToString(o,_Digits),
               " | ATR H1: ",DoubleToString(atr/_Point,1)," pts | Tendência: ALTA");
         return;
      }
   }
   }

   if(tendencia_baixa){
      for(int i=2;i<=OB_Lookback_H1+10;i++){
         double o=iOpen(_Symbol,PERIOD_H1,i), c=iClose(_Symbol,PERIOD_H1,i);
         double h=iHigh(_Symbol,PERIOD_H1,i), l=iLow(_Symbol,PERIOD_H1,i);
         if(c<=o) continue;
         bool bos=false;
         for(int j=i-1;j>=1;j--) if(iClose(_Symbol,PERIOD_H1,j)<l){ bos=true; break; }
         if(!bos) continue;
         datetime ot=iTime(_Symbol,PERIOD_H1,i);
         if(OB_Bloqueado(ot)) continue;
         if(preco>=o && preco<=h){
            g_ob_low=o; g_ob_high=h; g_ob_time=ot; g_direcao=-1; g_ob_tf="H1";
            g_estado=EM_ZONA; g_velas_na_zona=0;
            g_dbg_zonas_h1++;
            FixarSwings();
            Print(">>> ZONA OB H1 SELL | ",DoubleToString(o,_Digits)," - ",DoubleToString(h,_Digits),
                  " | ATR H1: ",DoubleToString(atr/_Point,1)," pts | Tendencia: BAIXA");
            return;
         }
      }
   }

   if(UsarOBM15Efetivo()){
      if(tendencia_alta){
         for(int i=2;i<=OB_Lookback_M15+10;i++){
            double o=iOpen(_Symbol,PERIOD_M15,i), c=iClose(_Symbol,PERIOD_M15,i);
            double h=iHigh(_Symbol,PERIOD_M15,i), l=iLow(_Symbol,PERIOD_M15,i);
            if(c>=o) continue;
            bool bos=false;
            for(int j=i-1;j>=1;j--) if(iClose(_Symbol,PERIOD_M15,j)>h){ bos=true; break; }
            if(!bos) continue;
            datetime ot=iTime(_Symbol,PERIOD_M15,i);
            if(OB_Bloqueado(ot)) continue;
            if(preco>=l && preco<=o){
               g_ob_low=l; g_ob_high=o; g_ob_time=ot; g_direcao=1; g_ob_tf="M15";
               g_estado=EM_ZONA; g_velas_na_zona=0;
               g_dbg_zonas_h1++;
               FixarSwings();
               Print(">>> ZONA OB M15 | ",DoubleToString(l,_Digits)," - ",DoubleToString(o,_Digits),
                     " | ATR H1: ",DoubleToString(atr/_Point,1)," pts | Tendencia: ALTA");
               return;
            }
         }
      }

      if(tendencia_baixa){
         for(int i=2;i<=OB_Lookback_M15+10;i++){
            double o=iOpen(_Symbol,PERIOD_M15,i), c=iClose(_Symbol,PERIOD_M15,i);
            double h=iHigh(_Symbol,PERIOD_M15,i), l=iLow(_Symbol,PERIOD_M15,i);
            if(c<=o) continue;
            bool bos=false;
            for(int j=i-1;j>=1;j--) if(iClose(_Symbol,PERIOD_M15,j)<l){ bos=true; break; }
            if(!bos) continue;
            datetime ot=iTime(_Symbol,PERIOD_M15,i);
            if(OB_Bloqueado(ot)) continue;
            if(preco>=o && preco<=h){
               g_ob_low=o; g_ob_high=h; g_ob_time=ot; g_direcao=-1; g_ob_tf="M15";
               g_estado=EM_ZONA; g_velas_na_zona=0;
               g_dbg_zonas_h1++;
               FixarSwings();
               Print(">>> ZONA OB M15 SELL | ",DoubleToString(o,_Digits)," - ",DoubleToString(h,_Digits),
                     " | ATR H1: ",DoubleToString(atr/_Point,1)," pts | Tendencia: BAIXA");
               return;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ESTADO 2 — Dentro do OB, aguarda Sweep no M1                  |
//+------------------------------------------------------------------+
void ProcurarFVG_H1()
{
   if(!Usar_FVG_H1) return;
   if(!DentroHorarioEntrada()) return;
   if(!ATRContextoValido()) return;

   bool tendencia_alta=TendenciaDeAlta();
   bool tendencia_baixa=TendenciaDeBaixa();
   if(!tendencia_alta && !tendencia_baixa) return;

   double preco=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double atr=ObterATR();
   int lookback=FVG_Lookback_H1;
   if(lookback<3) lookback=3;

   if(tendencia_alta){
      for(int newer=1;newer<=lookback;newer++){
         int older=newer+2;
         double older_high=iHigh(_Symbol,PERIOD_H1,older);
         double newer_low=iLow(_Symbol,PERIOD_H1,newer);
         if(older_high<=0 || newer_low<=0) continue;
         if(newer_low<=older_high) continue;

         double gap_pts=(newer_low-older_high)/_Point;
         if(gap_pts<FVG_Min_Pontos || gap_pts>FVG_Max_Pontos) continue;
         datetime ft=iTime(_Symbol,PERIOD_H1,newer+1);
         if(OB_Bloqueado(ft)) continue;

         if(preco>=older_high && preco<=newer_low){
            g_ob_low=older_high;
            g_ob_high=newer_low;
            g_ob_time=ft;
            g_direcao=1;
            g_ob_tf="FVG_H1";
            g_estado=EM_ZONA;
            g_velas_na_zona=0;
            g_dbg_zonas_fvg++;
            FixarSwings();
            Print(">>> ZONA FVG H1 BUY | ",DoubleToString(g_ob_low,_Digits),
                  " - ",DoubleToString(g_ob_high,_Digits),
                  " | gap: ",DoubleToString(gap_pts,1),
                  " pts | ATR H1: ",DoubleToString(atr/_Point,1)," pts");
            return;
         }
      }
   }

   if(tendencia_baixa){
      for(int newer=1;newer<=lookback;newer++){
         int older=newer+2;
         double older_low=iLow(_Symbol,PERIOD_H1,older);
         double newer_high=iHigh(_Symbol,PERIOD_H1,newer);
         if(older_low<=0 || newer_high<=0) continue;
         if(newer_high>=older_low) continue;

         double gap_pts=(older_low-newer_high)/_Point;
         if(gap_pts<FVG_Min_Pontos || gap_pts>FVG_Max_Pontos) continue;
         datetime ft=iTime(_Symbol,PERIOD_H1,newer+1);
         if(OB_Bloqueado(ft)) continue;

         if(preco>=newer_high && preco<=older_low){
            g_ob_low=newer_high;
            g_ob_high=older_low;
            g_ob_time=ft;
            g_direcao=-1;
            g_ob_tf="FVG_H1";
            g_estado=EM_ZONA;
            g_velas_na_zona=0;
            g_dbg_zonas_fvg++;
            FixarSwings();
            Print(">>> ZONA FVG H1 SELL | ",DoubleToString(g_ob_low,_Digits),
                  " - ",DoubleToString(g_ob_high,_Digits),
                  " | gap: ",DoubleToString(gap_pts,1),
                  " pts | ATR H1: ",DoubleToString(atr/_Point,1)," pts");
            return;
         }
      }
   }
}

void MonitorarSweep()
{
   double preco=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double atr_m1=ObterATRM1();
   if(atr_m1<=0) return;
   g_velas_na_zona++;
   if(g_velas_na_zona>=Timeout_Velas_M1){ g_dbg_timeout_zona++; BloquearOB(g_ob_time); Print("Timeout. OB bloqueado."); ResetEstado(); return; }
   if(preco<g_ob_low-10*_Point || preco>g_ob_high+10*_Point){ ResetEstado(); return; }

   if(Entrada_Direta_OB && g_direcao==1 && ConfirmacaoBigPlayer() && iClose(_Symbol,PERIOD_M1,1)>g_ob_high){
      g_sweep_low=MathMin(iLow(_Symbol,PERIOD_M1,1),g_swing_low_ref);
      Print(">>> DISPLACEMENT OB + RSI | entrada no rastro institucional");
      ExecutarEntrada();
      return;
   }
   if(Entrada_Direta_OB && g_direcao==-1 && ConfirmacaoBigPlayer() && iClose(_Symbol,PERIOD_M1,1)<g_ob_low){
      g_sweep_high=MathMax(iHigh(_Symbol,PERIOD_M1,1),g_swing_high_ref);
      Print(">>> DISPLACEMENT OB + RSI | entrada sell no rastro institucional");
      ExecutarEntrada();
      return;
   }

   // Sweep e liquidez local sao medidos no M1.
   double atr_sweep = atr_m1 * ATR_Sweep_Min;
   double atr_sweep_borda = atr_m1 * Sweep_Borda_OB_ATR_Min;
   double lv=iLow(_Symbol,PERIOD_M1,1), hv=iHigh(_Symbol,PERIOD_M1,1), cv=iClose(_Symbol,PERIOD_M1,1);
   if(g_direcao==1 && lv<(g_swing_low_ref - atr_sweep) && cv>g_swing_low_ref){
      g_sweep_low=lv; g_sweep_sessao=SessaoAtual(); g_estado=SWEEP_OK; g_dbg_sweeps++;
      Print(">>> SWEEP | mín: ",DoubleToString(lv,_Digits),
            " | aguarda displacement + RSI");
   }
   else if(g_direcao==-1 && hv>(g_swing_high_ref + atr_sweep) && cv<g_swing_high_ref){
      g_sweep_high=hv; g_sweep_sessao=SessaoAtual(); g_estado=SWEEP_OK; g_dbg_sweeps++;
      Print(">>> SWEEP SELL | max: ",DoubleToString(hv,_Digits),
            " | aguarda displacement + RSI");
   }
   else if(Usar_Sweep_Borda_OB_H1 && g_ob_tf=="H1" && g_direcao==1 &&
           lv<(g_ob_low - atr_sweep_borda) && cv>g_ob_low){
      g_sweep_low=lv; g_ob_tf="H1_EDGE"; g_estado=SWEEP_OK; g_dbg_sweeps++; g_dbg_sweeps_borda_ob++;
      Print(">>> SWEEP BORDA OB H1 BUY | borda: ",DoubleToString(g_ob_low,_Digits),
            " | min: ",DoubleToString(lv,_Digits),
            " | aguarda displacement + RSI");
   }
   else if(Usar_Sweep_Borda_OB_H1 && g_ob_tf=="H1" && g_direcao==-1 &&
           hv>(g_ob_high + atr_sweep_borda) && cv<g_ob_high){
      g_sweep_high=hv; g_ob_tf="H1_EDGE"; g_estado=SWEEP_OK; g_dbg_sweeps++; g_dbg_sweeps_borda_ob++;
      Print(">>> SWEEP BORDA OB H1 SELL | borda: ",DoubleToString(g_ob_high,_Digits),
            " | max: ",DoubleToString(hv,_Digits),
            " | aguarda displacement + RSI");
   }
}

//+------------------------------------------------------------------+
//| ESTADO 3 — Sweep confirmado, aguarda CHoCH (em cada tick)      |
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
      bool rsi_momentum=(rsi[0]>=rsi_min_efetivo || (rsi[0]>RSI_Neutro && rsi[0]>rsi[1]));
      bool fechamento_forte=(!Filtro_Candle_Sniper || fechamento_topo<=Candle_Fechamento_Extremo_Ratio);
      return (candle_impulso && corpo_forte && fechamento_forte && quebrou_micro_high && rsi_momentum);
   }

   bool candle_impulso=(c<o && (h-l)>=atr_m1*displacement_efetivo);
   bool quebrou_micro_low=(c<l_anterior || c<g_ob_low);
   double rsi_max_entrada=100.0-rsi_min_efetivo;
   bool rsi_momentum=(rsi[0]<=rsi_max_entrada || (rsi[0]<RSI_Neutro && rsi[0]<rsi[1]));
   bool fechamento_forte=(!Filtro_Candle_Sniper || fechamento_fundo<=Candle_Fechamento_Extremo_Ratio);

   return (candle_impulso && corpo_forte && fechamento_forte && quebrou_micro_low && rsi_momentum);
}

bool ConfirmacaoRastroSniper()
{
   if(!Usar_Confirmacao_Rastro_Sniper) return false;
   if(g_ob_tf!="H1") return false;

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
   double range=h-l;
   if(range<=0) return false;

   double corpo=MathAbs(c-o);
   double corpo_ratio=corpo/range;
   double fechamento_topo=(h-c)/range;
   double fechamento_fundo=(c-l)/range;
   double meio_ob=(g_ob_low+g_ob_high)/2.0;
   bool candle_suficiente=(range>=atr_m1*Rastro_Displacement_ATR_M1);
   bool corpo_suficiente=(corpo_ratio>=Rastro_Corpo_Min_Ratio);

   if(g_direcao==1){
      bool candle_buy=(c>o);
      bool fechamento_ok=(fechamento_topo<=Rastro_Fechamento_Extremo_Ratio);
      bool recuperou_zona=(c>meio_ob || c>h_anterior);
      bool rsi_ok=(rsi[0]>=Rastro_RSI_Buy_Min);
      return (candle_buy && candle_suficiente && corpo_suficiente && fechamento_ok && recuperou_zona && rsi_ok);
   }

   bool candle_sell=(c<o);
   bool fechamento_ok=(fechamento_fundo<=Rastro_Fechamento_Extremo_Ratio);
   bool recuperou_zona=(c<meio_ob || c<l_anterior);
   bool rsi_ok=(rsi[0]<=Rastro_RSI_Sell_Max);
   return (candle_sell && candle_suficiente && corpo_suficiente && fechamento_ok && recuperou_zona && rsi_ok);
}

bool SetupSessionSweep()
{
   return (g_ob_tf=="ASIA_SWEEP" || g_ob_tf=="LONDON_SWEEP");
}

bool ConfirmacaoEntrada()
{
   g_confirmacao_rastro_atual=false;
   bool confirmacao_classica=ConfirmacaoBigPlayer();
   bool confirmacao_rastro=false;

   if(!confirmacao_classica){
      confirmacao_rastro=ConfirmacaoRastroSniper();
      if(!confirmacao_rastro)
         return false;
      g_confirmacao_rastro_atual=true;
      Print(">>> CONFIRMACAO RASTRO SNIPER | entrada rapida pos-sweep H1");
   }

   if(!SetupSessionSweep())
      return true;

   double rsi[1];
   if(CopyBuffer(g_rsi_handle,0,1,1,rsi)<1)
      return false;

   if(g_direcao==1 && rsi[0]<Session_Sweep_RSI_Buy_Min){
      Print("Session sweep rejeitado: RSI comprador fraco (",
            DoubleToString(rsi[0],2)," < ",
            DoubleToString(Session_Sweep_RSI_Buy_Min,2),").");
      return false;
   }

   if(g_direcao==-1 && rsi[0]>Session_Sweep_RSI_Sell_Max){
      Print("Session sweep rejeitado: RSI vendedor fraco (",
            DoubleToString(rsi[0],2)," > ",
            DoubleToString(Session_Sweep_RSI_Sell_Max,2),").");
      return false;
   }

   return true;
}

void VerificarCHoCH()
{
   if(!DentroHorarioEntradaOuFollowThrough()){ ResetEstado(); return; }

   datetime va=iTime(_Symbol,PERIOD_M1,0);
   if(va!=g_ultima_vela_m1){
      g_ultima_vela_m1=va; g_velas_na_zona++;
      if(ConfirmacaoEntrada()){ ExecutarEntrada(); return; }
      if(g_velas_na_zona>=Timeout_Velas_M1){
         g_dbg_timeout_confirmacao++;
         BloquearOB(g_ob_time);
         Print("Timeout displacement/RSI. OB bloqueado.");
         ResetEstado();
      }
   }
}

bool FiltroMomentumNYPermite(double rsi_val,bool tem_rsi)
{
   if(!Usar_Filtro_Momentum_NY)
      return true;

   if(SessaoAtual()!="NY" || g_ob_tf!="H1")
      return true;

   if(!tem_rsi){
      Print("Filtro NY rejeitou entrada: RSI indisponivel.");
      return false;
   }

   if(g_direcao==1 && rsi_val<NY_RSI_Buy_Min){
      Print("Filtro NY rejeitou BUY: RSI neutro/fraco (",
            DoubleToString(rsi_val,2)," < ",
            DoubleToString(NY_RSI_Buy_Min,2),").");
      return false;
   }

   if(g_direcao==-1 && rsi_val>NY_RSI_Sell_Max){
      Print("Filtro NY rejeitou SELL: RSI neutro/fraco (",
            DoubleToString(rsi_val,2)," > ",
            DoubleToString(NY_RSI_Sell_Max,2),").");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Executa a ordem                                                  |
//+------------------------------------------------------------------+
void ExecutarEntrada()
{
   if(!DentroHorarioEntradaOuFollowThrough()){ ResetEstado(); return; }
   if(!MesaProprietariaPermiteEntrada()){ ResetEstado(); return; }
   if(!ATRContextoValido(true)){ ResetEstado(); return; }

   long spread_atual=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   if(spread_atual>Max_Spread_Pontos){
      Print("Entrada abortada: spread alto (",spread_atual,
            " pts | max: ",Max_Spread_Pontos,")");
      ResetEstado();
      return;
   }

   double atr=ObterATR();
   double atr_m1=ObterATRM1();
   double entrada=(g_direcao==1 ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID));
   double sl=(g_direcao==1 ? g_sweep_low-3*_Point : g_sweep_high+3*_Point);
   double dist=(g_direcao==1 ? entrada-sl : sl-entrada);
   bool manter_sweep_h1=(g_estado==SWEEP_OK && g_ob_tf=="H1");

   if((g_direcao==1 && (g_sweep_low<=0 || sl>=entrada)) ||
      (g_direcao==-1 && (g_sweep_high<=0 || sl<=entrada))){
      Print("SL invalido para ",(g_direcao==1 ? "BUY" : "SELL"),
            " | entrada: ",DoubleToString(entrada,_Digits),
            " | sweep low/high: ",DoubleToString(g_sweep_low,_Digits),"/",
            DoubleToString(g_sweep_high,_Digits),
            " | SL: ",DoubleToString(sl,_Digits));
      if(manter_sweep_h1){
         Print("Tentativa H1 ignorada por SL invalido; mantendo sweep para nova confirmacao.");
         g_confirmacao_rastro_atual=false;
         return;
      }
      ResetEstado(); return;
   }

   double stop_pts=dist/_Point;
   bool follow_london=DentroHorarioFollowThroughLondon();
   if(follow_london && FollowThrough_London_Stop_Max_Pontos>0 &&
      stop_pts>FollowThrough_London_Stop_Max_Pontos){
      Print("Follow-through London rejeitado: stop largo (",
            DoubleToString(stop_pts,1)," pts | max: ",
            DoubleToString(FollowThrough_London_Stop_Max_Pontos,1),").");
      ResetEstado(); return;
   }
   if(g_ob_tf=="ASIA_SWEEP" && Asian_Sweep_Stop_Max_Pontos>0 &&
      stop_pts>Asian_Sweep_Stop_Max_Pontos){
      Print("Asian sweep rejeitado: stop largo (",
            DoubleToString(stop_pts,1)," pts | max: ",
            DoubleToString(Asian_Sweep_Stop_Max_Pontos,1),").");
      ResetEstado(); return;
   }
   if(g_ob_tf=="LONDON_SWEEP" && London_Sweep_Stop_Max_Pontos>0 &&
      stop_pts>London_Sweep_Stop_Max_Pontos){
      Print("London sweep rejeitado: stop largo (",
            DoubleToString(stop_pts,1)," pts | max: ",
            DoubleToString(London_Sweep_Stop_Max_Pontos,1),").");
      ResetEstado(); return;
   }

   double atr_stop_min_efetivo=ATR_Stop_Min;
   if(ATR_Stop_Min_Max_Efetivo>0 && atr_stop_min_efetivo>ATR_Stop_Min_Max_Efetivo)
      atr_stop_min_efetivo=ATR_Stop_Min_Max_Efetivo;

   if(dist<atr*atr_stop_min_efetivo){
      double o_sc=iOpen(_Symbol,PERIOD_M1,1);
      double c_sc=iClose(_Symbol,PERIOD_M1,1);
      double h_sc=iHigh(_Symbol,PERIOD_M1,1);
      double l_sc=iLow(_Symbol,PERIOD_M1,1);
      double range_sc=h_sc-l_sc;
      bool stop_curto_sniper=false;

      if(Usar_Stop_Curto_Sniper && g_ob_tf=="H1" && range_sc>0 &&
         stop_pts>=Stop_Curto_Min_Pontos &&
         (!Stop_Curto_Apenas_London || SessaoAtual()=="LONDON")){
         double corpo_sc=MathAbs(c_sc-o_sc)/range_sc;
         double fechamento_topo_sc=(h_sc-c_sc)/range_sc;
         double fechamento_fundo_sc=(c_sc-l_sc)/range_sc;
         bool candle_grande=(range_sc>=atr_m1*Stop_Curto_Displacement_ATR_M1);
         bool corpo_limpo=(corpo_sc>=Stop_Curto_Corpo_Min_Ratio);
         bool fechamento_limpo=false;
         if(g_direcao==1)
            fechamento_limpo=(c_sc>o_sc && fechamento_topo_sc<=Stop_Curto_Fechamento_Extremo);
         else
            fechamento_limpo=(c_sc<o_sc && fechamento_fundo_sc<=Stop_Curto_Fechamento_Extremo);

         stop_curto_sniper=(candle_grande && corpo_limpo && fechamento_limpo);
      }

      if(stop_curto_sniper){
         Print("Stop curto aceito como sniper (",DoubleToString(stop_pts,1),
               " pts | candle: ",DoubleToString(range_sc/_Point,1),
               " pts | ATR M1: ",DoubleToString(atr_m1/_Point,1),").");
      }
      else{
      g_dbg_stop_curto++;
      Print("Stop curto (",DoubleToString(dist/_Point,1),
            " pts | minimo efetivo: ",DoubleToString((atr*atr_stop_min_efetivo)/_Point,1),
            " pts). Skip.");
      if(manter_sweep_h1){
         Print("Tentativa H1 ignorada por stop curto; mantendo sweep para nova confirmacao.");
         g_confirmacao_rastro_atual=false;
         return;
      }
      ResetEstado(); return;
      }
   }
   if(dist>atr*ATR_Stop_Max){
      g_dbg_stop_largo++;
      Print("Stop largo (",DoubleToString(dist/_Point,1)," pts, máx: ",
            DoubleToString(atr*ATR_Stop_Max/_Point,1),"). Skip.");
      ResetEstado(); return;
   }

   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double risco_trade=Risco_Efetivo();
   double lote=NormalizeDouble(risco_trade/((dist/ts)*tv),2);
   lote=MathMax(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),
        MathMin(MathMin(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),2.0),lote));

   double rr_efetivo=RR_Ratio;
   if(RR_Max_Efetivo>0 && rr_efetivo>RR_Max_Efetivo)
      rr_efetivo=RR_Max_Efetivo;

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
         candle_rr_forte=(c_conf>o_conf && corpo_ratio>=Candle_Corpo_RR_Forte &&
                          fechamento_topo<=Candle_Fechamento_RR_Forte);
      else
         candle_rr_forte=(c_conf<o_conf && corpo_ratio>=Candle_Corpo_RR_Forte &&
                          fechamento_fundo<=Candle_Fechamento_RR_Forte);
   }
   if(candle_rr_forte && RR_Sniper_Forte>rr_efetivo)
      rr_efetivo=RR_Sniper_Forte;

   double tp=NormalizeDouble((g_direcao==1 ? entrada+dist*rr_efetivo : entrada-dist*rr_efetivo),_Digits);
   sl=NormalizeDouble(sl,_Digits);
   entrada=NormalizeDouble(entrada,_Digits);

   double rsi_val=0;
   double rsi_buf[1];
   bool tem_rsi=(CopyBuffer(g_rsi_handle,0,1,1,rsi_buf)>0);
   if(tem_rsi)
      rsi_val=rsi_buf[0];

   if(!FiltroMomentumNYPermite(rsi_val,tem_rsi)){
      ResetEstado();
      return;
   }

   Print("Entrada ",(g_direcao==1 ? "BUY" : "SELL"),": ",entrada,
         " | SL: ",sl," (",DoubleToString(dist/_Point,1)," pts)",
         " | TP: ",tp," | RR efetivo: ",DoubleToString(rr_efetivo,2),
         " | RR forte: ",(candle_rr_forte ? "sim" : "nao"),
         " | Lote: ",lote,
         " | Spread: ",spread_atual," pts",
         " | ATR H1/M1: ",DoubleToString(atr/_Point,1),"/",
         DoubleToString(atr_m1/_Point,1)," pts");

   bool ordem_ok=false;
   if(g_direcao==1) ordem_ok=trade.Buy(lote,_Symbol,entrada,sl,tp,"SMC_Sniper");
   else ordem_ok=trade.Sell(lote,_Symbol,entrada,sl,tp,"SMC_Sniper");

   if(ordem_ok){
      g_dbg_entradas++;
      g_trades_dia++;
      PrepararDiagnosticoEntrada((g_direcao==1 ? "BUY" : "SELL"),
                                 atr,atr_m1,rsi_val,dist/_Point,
                                 rr_efetivo,spread_atual);
      Print(">>> ORDEM ABERTA");
      g_estado=EM_TRADE;
      g_breakeven_feito=false;
   }
   else{
      Print("Erro: ",trade.ResultRetcode()," - ",trade.ResultRetcodeDescription());
      ResetEstado();
   }
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(g_estado==EM_TRADE){
      if(PropRiscoFinanceiroAtingido()){
         if(TemPosicaoAberta()){
            Print("Prop guard: fechando posicao por limite interno de risco.");
            trade.PositionClose(_Symbol);
         }
         return;
      }
      if(!TemPosicaoAberta()){
         FinalizarDiagnosticoSeFechou();
         if(Bloquear_OB_Apos_Trade && g_ob_time>0) BloquearOB(g_ob_time);
         ResetEstado();
         return;
      }
      GerirBreakeven(); return;
   }
   if(g_estado==SWEEP_OK){ VerificarCHoCH(); return; }
   datetime va=iTime(_Symbol,PERIOD_M1,0);
   if(va==g_ultima_vela_m1) return;
   g_ultima_vela_m1=va;
   AtualizarRangeAsia();
   AtualizarRangeLondon();
   AtualizarControleDiario();
   if(!MesaProprietariaPermiteEntrada()) return;
   if(g_estado==SCANNING){
      if(ProcurarAsianSweep()) return;
      if(ProcurarLondonSweep()) return;
      ProcurarOB();
      if(g_estado==SCANNING) ProcurarFVG_H1();
   }
   else if(g_estado==EM_ZONA) MonitorarSweep();
}
//+------------------------------------------------------------------+
