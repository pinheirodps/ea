//+------------------------------------------------------------------+
//|                                                      Filters.mqh |
//+------------------------------------------------------------------+
#include "Enums.mqh"
#include "Structures.mqh"
#include <Trade\Trade.mqh>

class CFilters
{
private:
    string m_symbol;
    CTrade m_trade;

public:
    CFilters(string symbol = NULL)
    {
        m_symbol = (symbol == NULL) ? _Symbol : symbol;
    }

    // CORREÇÃO: Arrays devem ser passados por referência (&)
    bool Check_Time_Filter(bool use_filter, string start_time, string end_time, bool &trade_days[])
    {
        if(!use_filter) return true;
        
        datetime current = TimeCurrent();
        MqlDateTime dt;
        TimeToStruct(current, dt);
        
        // Verifica dia da semana (0=Domingo, 1=Segunda...)
        // Assumindo que trade_days[0] é segunda
        int day_idx = dt.day_of_week - 1; 
        if(day_idx < 0 || day_idx >= 5) return false; // Fim de semana
        if(!trade_days[day_idx]) return false;

        return true; 
    }

    bool Check_Zone_Filter(OrderBlock &ob, StructureRange &range)
    {
        if(!ob.is_valid || !range.is_valid) return false;
        ENUM_ZONE_TYPE zone = range.GetZoneType(ob.mean_threshold);
        
        if(ob.ob_type == OB_BULLISH && zone == ZONE_DISCOUNT) return true;
        if(ob.ob_type == OB_BEARISH && zone == ZONE_PREMIUM) return true;
        
        return false;
    }

    bool Can_Trade_Setup(OrderBlock &ob, StructureRange &range, bool use_pd, bool use_inducement, int magic)
    {
         // 1. Check Premium/Discount Zone
         if(use_pd && !Check_Zone_Filter(ob, range)) return false;
         
         // 2. Check Inducement (if required)
         if(use_inducement && !ob.has_inducement) return false;
         
         // 3. Check for existing positions
         if(HasOpenPosition(magic)) return false;

         return true;
    }

    bool Can_Scale_FVG(FairValueGap &fvg, OrderBlock &ob, int max_scaling, int magic)
    {
        if(!fvg.is_valid) return false;
        
        // CORREÇÃO: Lógica MQL5 para contar ordens pendentes
        int pending_count = 0;
        int total = OrdersTotal();
        
        for(int i = 0; i < total; i++)
        {
            ulong ticket = OrderGetTicket(i);
            if(ticket > 0)
            {
                if(OrderGetString(ORDER_SYMBOL) == m_symbol && 
                   OrderGetInteger(ORDER_MAGIC) == magic)
                {
                   pending_count++;
                }
            }
        }
        
        if(pending_count >= max_scaling) return false;
        return true;
    }
    
    bool HasOpenPosition(int magic)
    {
        // Lógica MQL5 para Posições
        int total = PositionsTotal();
        for(int i=0; i<total; i++)
        {
            string symbol = PositionGetSymbol(i);
            if(symbol == m_symbol && PositionGetInteger(POSITION_MAGIC) == magic)
            {
                return true;
            }
        }
        return false;
    }
};