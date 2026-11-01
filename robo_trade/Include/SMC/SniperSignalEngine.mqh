//+------------------------------------------------------------------+
//|                                         SniperSignalEngine.mqh   |
//|  Motor de sinal SMC compartilhado (indicador + EA manual)        |
//|  Reaproveita a logica validada do SMC_Sniper.mq5 (perfil v2.7):  |
//|  tendencia EMA H1 + swing, Order Block H1, sweep M1,             |
//|  displacement ATR M1, confirmacao RSI.                           |
//|  Este motor NAO envia ordens. Apenas calcula zona/sweep/SL/TP    |
//|  e informa quando o setup esta pronto para decisao manual.       |
//+------------------------------------------------------------------+
#property copyright "SMC Sniper Scanner"
#property strict

enum ENUM_SNIPER_ESTADO { SNIPER_SCANNING, SNIPER_EM_ZONA, SNIPER_SWEEP_OK, SNIPER_PRONTO };

struct SniperSetup
{
   ENUM_SNIPER_ESTADO estado;
   int                direcao;        // 1 = compra, -1 = venda
   string             ob_tf;          // "H1" ou "H1_EDGE"
   double             ob_low;
   double             ob_high;
   datetime           ob_time;
   double             swing_low_ref;
   double             swing_high_ref;
   double             sweep_low;
   double             sweep_high;
   double             entrada;
   double             sl;
   double             tp;
   double             rr_efetivo;
   double             stop_pts;
   double             atr_h1;
   double             atr_m1;
   double             rsi;
   bool               confirmacao_rastro;
   datetime           hora_pronto;
};

//+------------------------------------------------------------------+
//| Motor de sinal: encapsula os handles e a maquina de estados      |
//+------------------------------------------------------------------+
class CSniperSignalEngine
{
private:
   string   m_symbol;

   // --- Parametros (mesmos nomes/defaults do SMC_Sniper v3.5.20) ---
   ENUM_TIMEFRAMES m_tf_estrutura;   // H1
   ENUM_TIMEFRAMES m_tf_gatilho;     // M1 (sweep/displacement/RSI)
   ENUM_TIMEFRAMES m_tf_rsi;         // M30

   int      m_ob_lookback_h1;
   int      m_swing_lookback;
   int      m_swing_confirmacao;
   int      m_timeout_velas;
   int      m_atr_period;
   double   m_atr_sweep_min;
   double   m_atr_stop_min;
   double   m_atr_stop_max;
   double   m_atr_minimo;
   int      m_ema_h1_periodo;
   int      m_tendencia_lookback_h1;
   int      m_tendencia_swing_lados;
   double   m_tendencia_ema_buffer_pts;
   bool     m_tendencia_exigir_ema_inclinada;
   double   m_rsi_min_entrada;
   double   m_rsi_neutro;
   double   m_displacement_atr_m1;
   bool     m_filtro_candle;
   double   m_candle_corpo_min_ratio;
   double   m_candle_fechamento_extremo;
   double   m_candle_corpo_rr_forte;
   double   m_candle_fechamento_rr_forte;
   bool     m_usar_rastro_sniper;
   double   m_rastro_displacement_atr_m1;
   double   m_rastro_corpo_min_ratio;
   double   m_rastro_fechamento_extremo;
   double   m_rastro_rsi_buy_min;
   double   m_rastro_rsi_sell_max;
   double   m_rr_ratio;
   double   m_rr_sniper_forte;
   bool     m_usar_rr_dinamico;

   // --- handles ---
   int      m_atr_h1_handle;
   int      m_atr_m1_handle;
   int      m_ema_h1_handle;
   int      m_rsi_handle;

   // --- estado interno ---
   SniperSetup m_setup;
   int         m_velas_na_zona;
   datetime    m_ultima_vela_gatilho;

   double Val_Point() { return SymbolInfoDouble(m_symbol, SYMBOL_POINT); }

   double ObterATR(int handle)
   {
      double buf[1];
      if(CopyBuffer(handle, 0, 1, 1, buf) <= 0) return 0;
      return buf[0];
   }

   bool SwingHigh(ENUM_TIMEFRAMES tf, int shift, int lados)
   {
      double high = iHigh(m_symbol, tf, shift);
      if(high <= 0) return false;
      for(int i = 1; i <= lados; i++)
      {
         if(high <= iHigh(m_symbol, tf, shift - i)) return false;
         if(high <= iHigh(m_symbol, tf, shift + i)) return false;
      }
      return true;
   }

   bool SwingLow(ENUM_TIMEFRAMES tf, int shift, int lados)
   {
      double low = iLow(m_symbol, tf, shift);
      if(low <= 0) return false;
      for(int i = 1; i <= lados; i++)
      {
         if(low >= iLow(m_symbol, tf, shift - i)) return false;
         if(low >= iLow(m_symbol, tf, shift + i)) return false;
      }
      return true;
   }

   bool TendenciaDeAlta()
   {
      double ema[2];
      if(CopyBuffer(m_ema_h1_handle, 0, 1, 2, ema) < 2) return false;

      double preco = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double buffer = m_tendencia_ema_buffer_pts * Val_Point();
      if(preco <= ema[0] + buffer) return false;
      if(m_tendencia_exigir_ema_inclinada && ema[0] <= ema[1]) return false;

      int lados = MathMax(1, m_tendencia_swing_lados);
      int lookback = MathMax(m_tendencia_lookback_h1, lados * 2 + 5);
      if(Bars(m_symbol, m_tf_estrutura) < lookback + lados + 2) return false;

      double ultimo = 0, anterior = 0;
      for(int shift = 1 + lados; shift <= lookback; shift++)
      {
         if(!SwingHigh(m_tf_estrutura, shift, lados)) continue;
         if(ultimo == 0) ultimo = iHigh(m_symbol, m_tf_estrutura, shift);
         else { anterior = iHigh(m_symbol, m_tf_estrutura, shift); break; }
      }
      if(ultimo == 0 || anterior == 0) return false;
      return (ultimo > anterior);
   }

   bool TendenciaDeBaixa()
   {
      double ema[2];
      if(CopyBuffer(m_ema_h1_handle, 0, 1, 2, ema) < 2) return false;

      double preco = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double buffer = m_tendencia_ema_buffer_pts * Val_Point();
      if(preco >= ema[0] - buffer) return false;
      if(m_tendencia_exigir_ema_inclinada && ema[0] >= ema[1]) return false;

      int lados = MathMax(1, m_tendencia_swing_lados);
      int lookback = MathMax(m_tendencia_lookback_h1, lados * 2 + 5);
      if(Bars(m_symbol, m_tf_estrutura) < lookback + lados + 2) return false;

      double ultimo = 0, anterior = 0;
      for(int shift = 1 + lados; shift <= lookback; shift++)
      {
         if(!SwingLow(m_tf_estrutura, shift, lados)) continue;
         if(ultimo == 0) ultimo = iLow(m_symbol, m_tf_estrutura, shift);
         else { anterior = iLow(m_symbol, m_tf_estrutura, shift); break; }
      }
      if(ultimo == 0 || anterior == 0) return false;
      return (ultimo < anterior);
   }

   void FixarSwings()
   {
      int lados = MathMax(1, m_swing_confirmacao);
      int lookback = MathMax(m_swing_lookback, lados * 2 + 5);

      m_setup.swing_low_ref = 0;
      m_setup.swing_high_ref = 0;

      for(int i = 1 + lados; i <= lookback; i++)
      {
         if(m_setup.swing_low_ref == 0 && SwingLow(m_tf_gatilho, i, lados))
            m_setup.swing_low_ref = iLow(m_symbol, m_tf_gatilho, i);
         if(m_setup.swing_high_ref == 0 && SwingHigh(m_tf_gatilho, i, lados))
            m_setup.swing_high_ref = iHigh(m_symbol, m_tf_gatilho, i);
         if(m_setup.swing_low_ref > 0 && m_setup.swing_high_ref > 0) return;
      }

      if(m_setup.swing_low_ref == 0) m_setup.swing_low_ref = iLow(m_symbol, m_tf_gatilho, 1);
      if(m_setup.swing_high_ref == 0) m_setup.swing_high_ref = iHigh(m_symbol, m_tf_gatilho, 1);
      for(int i = 2; i <= lookback; i++)
      {
         double l = iLow(m_symbol, m_tf_gatilho, i);
         double h = iHigh(m_symbol, m_tf_gatilho, i);
         if(l < m_setup.swing_low_ref) m_setup.swing_low_ref = l;
         if(h > m_setup.swing_high_ref) m_setup.swing_high_ref = h;
      }
   }

   void ResetSetup()
   {
      m_setup.estado = SNIPER_SCANNING;
      m_setup.direcao = 1;
      m_setup.ob_tf = "NA";
      m_setup.ob_low = 0; m_setup.ob_high = 0; m_setup.ob_time = 0;
      m_setup.swing_low_ref = 0; m_setup.swing_high_ref = 0;
      m_setup.sweep_low = 0; m_setup.sweep_high = 0;
      m_setup.entrada = 0; m_setup.sl = 0; m_setup.tp = 0;
      m_setup.rr_efetivo = 0; m_setup.stop_pts = 0;
      m_setup.confirmacao_rastro = false;
      m_velas_na_zona = 0;
   }

   bool ATRContextoValido()
   {
      double atr_h1 = ObterATR(m_atr_h1_handle);
      double atr_m1 = ObterATR(m_atr_m1_handle);
      return (atr_h1 > m_atr_minimo && atr_m1 > 0);
   }

   void ProcurarOB()
   {
      double atr = ObterATR(m_atr_h1_handle);
      if(atr < m_atr_minimo) return;
      if(!ATRContextoValido()) return;

      bool alta = TendenciaDeAlta();
      bool baixa = TendenciaDeBaixa();
      if(!alta && !baixa) return;

      double preco = SymbolInfoDouble(m_symbol, SYMBOL_BID);

      if(alta)
      {
         for(int i = 2; i <= m_ob_lookback_h1 + 10; i++)
         {
            double o = iOpen(m_symbol, m_tf_estrutura, i), c = iClose(m_symbol, m_tf_estrutura, i);
            double h = iHigh(m_symbol, m_tf_estrutura, i), l = iLow(m_symbol, m_tf_estrutura, i);
            if(c >= o) continue;
            bool bos = false;
            for(int j = i - 1; j >= 1; j--) if(iClose(m_symbol, m_tf_estrutura, j) > h) { bos = true; break; }
            if(!bos) continue;
            if(preco >= l && preco <= o)
            {
               m_setup.ob_low = l; m_setup.ob_high = o;
               m_setup.ob_time = iTime(m_symbol, m_tf_estrutura, i);
               m_setup.direcao = 1; m_setup.ob_tf = "H1";
               m_setup.estado = SNIPER_EM_ZONA;
               m_velas_na_zona = 0;
               FixarSwings();
               return;
            }
         }
      }

      if(baixa)
      {
         for(int i = 2; i <= m_ob_lookback_h1 + 10; i++)
         {
            double o = iOpen(m_symbol, m_tf_estrutura, i), c = iClose(m_symbol, m_tf_estrutura, i);
            double h = iHigh(m_symbol, m_tf_estrutura, i), l = iLow(m_symbol, m_tf_estrutura, i);
            if(c <= o) continue;
            bool bos = false;
            for(int j = i - 1; j >= 1; j--) if(iClose(m_symbol, m_tf_estrutura, j) < l) { bos = true; break; }
            if(!bos) continue;
            if(preco >= o && preco <= h)
            {
               m_setup.ob_low = o; m_setup.ob_high = h;
               m_setup.ob_time = iTime(m_symbol, m_tf_estrutura, i);
               m_setup.direcao = -1; m_setup.ob_tf = "H1";
               m_setup.estado = SNIPER_EM_ZONA;
               m_velas_na_zona = 0;
               FixarSwings();
               return;
            }
         }
      }
   }

   void MonitorarSweep()
   {
      double preco = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double atr_m1 = ObterATR(m_atr_m1_handle);
      if(atr_m1 <= 0) return;

      m_velas_na_zona++;
      if(m_velas_na_zona >= m_timeout_velas) { ResetSetup(); return; }
      if(preco < m_setup.ob_low - 10 * Val_Point() || preco > m_setup.ob_high + 10 * Val_Point())
      {
         ResetSetup();
         return;
      }

      double atr_sweep = atr_m1 * m_atr_sweep_min;
      double lv = iLow(m_symbol, m_tf_gatilho, 1), hv = iHigh(m_symbol, m_tf_gatilho, 1), cv = iClose(m_symbol, m_tf_gatilho, 1);

      if(m_setup.direcao == 1 && lv < (m_setup.swing_low_ref - atr_sweep) && cv > m_setup.swing_low_ref)
      {
         m_setup.sweep_low = lv;
         m_setup.estado = SNIPER_SWEEP_OK;
      }
      else if(m_setup.direcao == -1 && hv > (m_setup.swing_high_ref + atr_sweep) && cv < m_setup.swing_high_ref)
      {
         m_setup.sweep_high = hv;
         m_setup.estado = SNIPER_SWEEP_OK;
      }
   }

   bool ConfirmacaoBigPlayer()
   {
      double atr_m1 = ObterATR(m_atr_m1_handle);
      if(atr_m1 <= 0) return false;

      double rsi[2];
      if(CopyBuffer(m_rsi_handle, 0, 1, 2, rsi) < 2) return false;

      double o = iOpen(m_symbol, m_tf_gatilho, 1), c = iClose(m_symbol, m_tf_gatilho, 1);
      double h = iHigh(m_symbol, m_tf_gatilho, 1), l = iLow(m_symbol, m_tf_gatilho, 1);
      double h_ant = iHigh(m_symbol, m_tf_gatilho, 2), l_ant = iLow(m_symbol, m_tf_gatilho, 2);
      double range = h - l;
      if(range <= 0) return false;

      double corpo_ratio = MathAbs(c - o) / range;
      double fechamento_topo = (h - c) / range;
      double fechamento_fundo = (c - l) / range;
      bool corpo_forte = (!m_filtro_candle || corpo_ratio >= m_candle_corpo_min_ratio);

      m_setup.rsi = rsi[0];

      if(m_setup.direcao == 1)
      {
         bool candle_impulso = (c > o && (h - l) >= atr_m1 * m_displacement_atr_m1);
         bool quebrou = (c > h_ant || c > m_setup.ob_high);
         bool rsi_ok = (rsi[0] >= m_rsi_min_entrada || (rsi[0] > m_rsi_neutro && rsi[0] > rsi[1]));
         bool fechamento_ok = (!m_filtro_candle || fechamento_topo <= m_candle_fechamento_extremo);
         return (candle_impulso && corpo_forte && fechamento_ok && quebrou && rsi_ok);
      }

      bool candle_impulso = (c < o && (h - l) >= atr_m1 * m_displacement_atr_m1);
      bool quebrou = (c < l_ant || c < m_setup.ob_low);
      double rsi_max = 100.0 - m_rsi_min_entrada;
      bool rsi_ok = (rsi[0] <= rsi_max || (rsi[0] < m_rsi_neutro && rsi[0] < rsi[1]));
      bool fechamento_ok = (!m_filtro_candle || fechamento_fundo <= m_candle_fechamento_extremo);
      return (candle_impulso && corpo_forte && fechamento_ok && quebrou && rsi_ok);
   }

   bool ConfirmacaoRastroSniper()
   {
      if(!m_usar_rastro_sniper) return false;
      if(m_setup.ob_tf != "H1") return false;

      double atr_m1 = ObterATR(m_atr_m1_handle);
      if(atr_m1 <= 0) return false;

      double rsi[2];
      if(CopyBuffer(m_rsi_handle, 0, 1, 2, rsi) < 2) return false;

      double o = iOpen(m_symbol, m_tf_gatilho, 1), c = iClose(m_symbol, m_tf_gatilho, 1);
      double h = iHigh(m_symbol, m_tf_gatilho, 1), l = iLow(m_symbol, m_tf_gatilho, 1);
      double h_ant = iHigh(m_symbol, m_tf_gatilho, 2), l_ant = iLow(m_symbol, m_tf_gatilho, 2);
      double range = h - l;
      if(range <= 0) return false;

      double corpo_ratio = MathAbs(c - o) / range;
      double fechamento_topo = (h - c) / range;
      double fechamento_fundo = (c - l) / range;
      double meio_ob = (m_setup.ob_low + m_setup.ob_high) / 2.0;
      bool candle_suficiente = (range >= atr_m1 * m_rastro_displacement_atr_m1);
      bool corpo_suficiente = (corpo_ratio >= m_rastro_corpo_min_ratio);

      m_setup.rsi = rsi[0];

      if(m_setup.direcao == 1)
      {
         bool candle_buy = (c > o);
         bool fechamento_ok = (fechamento_topo <= m_rastro_fechamento_extremo);
         bool recuperou = (c > meio_ob || c > h_ant);
         bool rsi_ok = (rsi[0] >= m_rastro_rsi_buy_min);
         return (candle_buy && candle_suficiente && corpo_suficiente && fechamento_ok && recuperou && rsi_ok);
      }

      bool candle_sell = (c < o);
      bool fechamento_ok = (fechamento_fundo <= m_rastro_fechamento_extremo);
      bool recuperou = (c < meio_ob || c < l_ant);
      bool rsi_ok = (rsi[0] <= m_rastro_rsi_sell_max);
      return (candle_sell && candle_suficiente && corpo_suficiente && fechamento_ok && recuperou && rsi_ok);
   }

   void CalcularNiveis()
   {
      double atr = ObterATR(m_atr_h1_handle);
      double atr_m1 = ObterATR(m_atr_m1_handle);
      double entrada = (m_setup.direcao == 1 ? SymbolInfoDouble(m_symbol, SYMBOL_ASK) : SymbolInfoDouble(m_symbol, SYMBOL_BID));
      double sl = (m_setup.direcao == 1 ? m_setup.sweep_low - 3 * Val_Point() : m_setup.sweep_high + 3 * Val_Point());
      double dist = (m_setup.direcao == 1 ? entrada - sl : sl - entrada);

      if(dist <= 0) { ResetSetup(); return; }
      if(dist < atr * m_atr_stop_min || dist > atr * m_atr_stop_max)
      {
         // Fora da faixa validada de stop; nao promove para PRONTO, mas mantem aguardando novo gatilho.
         return;
      }

      double rr_efetivo = m_rr_ratio;

      double o = iOpen(m_symbol, m_tf_gatilho, 1), c = iClose(m_symbol, m_tf_gatilho, 1);
      double h = iHigh(m_symbol, m_tf_gatilho, 1), l = iLow(m_symbol, m_tf_gatilho, 1);
      double range = h - l;
      if(m_usar_rr_dinamico && range > 0)
      {
         double corpo_ratio = MathAbs(c - o) / range;
         double fechamento_topo = (h - c) / range;
         double fechamento_fundo = (c - l) / range;
         bool forte = false;
         if(m_setup.direcao == 1)
            forte = (c > o && corpo_ratio >= m_candle_corpo_rr_forte && fechamento_topo <= m_candle_fechamento_rr_forte);
         else
            forte = (c < o && corpo_ratio >= m_candle_corpo_rr_forte && fechamento_fundo <= m_candle_fechamento_rr_forte);
         if(forte && m_rr_sniper_forte > rr_efetivo) rr_efetivo = m_rr_sniper_forte;
      }

      double tp = (m_setup.direcao == 1 ? entrada + dist * rr_efetivo : entrada - dist * rr_efetivo);
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);

      m_setup.entrada = NormalizeDouble(entrada, digits);
      m_setup.sl = NormalizeDouble(sl, digits);
      m_setup.tp = NormalizeDouble(tp, digits);
      m_setup.rr_efetivo = rr_efetivo;
      m_setup.stop_pts = dist / Val_Point();
      m_setup.atr_h1 = atr;
      m_setup.atr_m1 = atr_m1;
      m_setup.estado = SNIPER_PRONTO;
      m_setup.hora_pronto = TimeCurrent();
   }

   void VerificarConfirmacao()
   {
      datetime va = iTime(m_symbol, m_tf_gatilho, 0);
      if(va == m_ultima_vela_gatilho) return;
      m_ultima_vela_gatilho = va;
      m_velas_na_zona++;

      m_setup.confirmacao_rastro = false;
      bool classica = ConfirmacaoBigPlayer();
      bool rastro = false;
      if(!classica)
      {
         rastro = ConfirmacaoRastroSniper();
         if(rastro) m_setup.confirmacao_rastro = true;
      }

      if(classica || rastro)
      {
         CalcularNiveis();
         return;
      }

      if(m_velas_na_zona >= m_timeout_velas)
         ResetSetup();
   }

public:
   CSniperSignalEngine(string symbol = NULL)
   {
      m_symbol = (symbol == NULL) ? _Symbol : symbol;

      m_tf_estrutura = PERIOD_H1;
      m_tf_gatilho    = PERIOD_M1;
      m_tf_rsi        = PERIOD_M30;

      m_ob_lookback_h1 = 5;
      m_swing_lookback = 40;
      m_swing_confirmacao = 2;
      m_timeout_velas = 120;
      m_atr_period = 14;
      m_atr_sweep_min = 0.2;
      m_atr_stop_min = 0.15;
      m_atr_stop_max = 5.0;
      m_atr_minimo = 0.00005;
      m_ema_h1_periodo = 20;
      m_tendencia_lookback_h1 = 40;
      m_tendencia_swing_lados = 2;
      m_tendencia_ema_buffer_pts = 10.0;
      m_tendencia_exigir_ema_inclinada = true;
      m_rsi_min_entrada = 52.0;
      m_rsi_neutro = 50.0;
      m_displacement_atr_m1 = 0.8;
      m_filtro_candle = true;
      m_candle_corpo_min_ratio = 0.55;
      m_candle_fechamento_extremo = 0.25;
      m_candle_corpo_rr_forte = 0.70;
      m_candle_fechamento_rr_forte = 0.15;
      m_usar_rastro_sniper = true;
      m_rastro_displacement_atr_m1 = 0.55;
      m_rastro_corpo_min_ratio = 0.45;
      m_rastro_fechamento_extremo = 0.35;
      m_rastro_rsi_buy_min = 58.0;
      m_rastro_rsi_sell_max = 42.0;
      m_rr_ratio = 2.0;
      m_rr_sniper_forte = 2.8;
      m_usar_rr_dinamico = true;

      m_atr_h1_handle = INVALID_HANDLE;
      m_atr_m1_handle = INVALID_HANDLE;
      m_ema_h1_handle = INVALID_HANDLE;
      m_rsi_handle = INVALID_HANDLE;

      m_velas_na_zona = 0;
      m_ultima_vela_gatilho = 0;
      ResetSetup();
   }

   // --- Setters opcionais para o indicador/EA expor via input ---
   void SetTimeframes(ENUM_TIMEFRAMES estrutura, ENUM_TIMEFRAMES gatilho, ENUM_TIMEFRAMES rsi_tf)
   { m_tf_estrutura = estrutura; m_tf_gatilho = gatilho; m_tf_rsi = rsi_tf; }

   void SetRiscoRR(double rr_ratio, double rr_sniper_forte, bool usar_rr_dinamico)
   { m_rr_ratio = rr_ratio; m_rr_sniper_forte = rr_sniper_forte; m_usar_rr_dinamico = usar_rr_dinamico; }

   void SetStopLimites(double atr_stop_min, double atr_stop_max)
   { m_atr_stop_min = atr_stop_min; m_atr_stop_max = atr_stop_max; }

   void SetRSI(double rsi_min_entrada) { m_rsi_min_entrada = rsi_min_entrada; }

   bool Init()
   {
      m_atr_h1_handle = iATR(m_symbol, m_tf_estrutura, m_atr_period);
      m_atr_m1_handle = iATR(m_symbol, m_tf_gatilho, m_atr_period);
      m_ema_h1_handle = iMA(m_symbol, m_tf_estrutura, m_ema_h1_periodo, 0, MODE_EMA, PRICE_CLOSE);
      m_rsi_handle    = iRSI(m_symbol, m_tf_rsi, 14, PRICE_CLOSE);

      return (m_atr_h1_handle != INVALID_HANDLE && m_atr_m1_handle != INVALID_HANDLE &&
              m_ema_h1_handle != INVALID_HANDLE && m_rsi_handle != INVALID_HANDLE);
   }

   void Deinit()
   {
      if(m_atr_h1_handle != INVALID_HANDLE) IndicatorRelease(m_atr_h1_handle);
      if(m_atr_m1_handle != INVALID_HANDLE) IndicatorRelease(m_atr_m1_handle);
      if(m_ema_h1_handle != INVALID_HANDLE) IndicatorRelease(m_ema_h1_handle);
      if(m_rsi_handle != INVALID_HANDLE) IndicatorRelease(m_rsi_handle);
   }

   // Chamar em cada tick. Retorna true quando o estado MUDOU nesse tick
   // (util para o indicador/EA saber quando redesenhar/alertar).
   bool Update()
   {
      ENUM_SNIPER_ESTADO estado_antes = m_setup.estado;

      if(m_setup.estado == SNIPER_PRONTO)
      {
         // Mantem o setup pronto ate expirar por tempo/preco; quem decide fechar
         // (usuario clicou ou zona ficou obsoleta) e o consumidor via Reset().
         return false;
      }

      datetime va = iTime(m_symbol, m_tf_gatilho, 0);
      if(m_setup.estado == SNIPER_SCANNING)
      {
         if(va == m_ultima_vela_gatilho) return false;
         m_ultima_vela_gatilho = va;
         ProcurarOB();
      }
      else if(m_setup.estado == SNIPER_EM_ZONA)
      {
         MonitorarSweep();
      }
      else if(m_setup.estado == SNIPER_SWEEP_OK)
      {
         VerificarConfirmacao();
      }

      return (m_setup.estado != estado_antes);
   }

   SniperSetup GetSetup() { return m_setup; }
   ENUM_SNIPER_ESTADO GetEstado() { return m_setup.estado; }
   bool EstaPronto() { return m_setup.estado == SNIPER_PRONTO; }

   // Diagnostico para o painel: prova visual de que o motor esta analisando o mercado
   // mesmo enquanto nenhum setup foi encontrado ainda.
   string DiagnosticoTendencia()
   {
      bool alta = TendenciaDeAlta();
      bool baixa = TendenciaDeBaixa();
      if(alta) return "ALTA";
      if(baixa) return "BAIXA";
      return "SEM TENDENCIA (aguardando EMA+swing alinhar)";
   }

   double DiagnosticoATR_Estrutura() { return ObterATR(m_atr_h1_handle); }
   double DiagnosticoATR_Gatilho()   { return ObterATR(m_atr_m1_handle); }
   int    DiagnosticoVelasNaZona()   { return m_velas_na_zona; }
   int    DiagnosticoTimeoutVelas()  { return m_timeout_velas; }

   // Descarta o setup atual (ex.: usuario decidiu nao entrar, ou apos executar).
   void Reset() { ResetSetup(); }
};
