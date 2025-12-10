//+------------------------------------------------------------------+
//|                                        EA_SMC_MultiProfile.mq5 |
//|                                    EA SMC Multi-Profile          |
//|                                    Main Expert Advisor            |
//+------------------------------------------------------------------+
#property copyright "EA SMC Multi-Profile"
#property version   "1.02"
#property strict

// Include all components
#include <Trade\Trade.mqh>
#include <SMC\Enums.mqh>
#include <SMC\Structures.mqh>
#include <SMC\Inputs.mqh>
#include <SMC\TradeUtils.mqh>
#include <SMC\SMC_Analyzer.mqh>
#include <SMC\Filters.mqh>
#include <SMC\TradingEngine.mqh>
#include <SMC\Visualizer.mqh>

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CSMCAnalyzer      *g_analyzer   = NULL;
CFilters          *g_filters    = NULL;
CTradingEngine    *g_engine     = NULL;
CVisualizer       *g_visualizer = NULL;

OrderBlock        g_current_ob;
FairValueGap      g_current_fvg;
StructureRange    g_structure_range;

bool              g_initialized  = false;
bool              g_has_position = false;
datetime          g_last_ob_time = 0;  // Prevent duplicate signals

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    string error_msg = "";
    if(!ValidateInputs(error_msg)) 
    {
        Print("Init Error: ", error_msg);
        return INIT_PARAMETERS_INCORRECT;
    }
    if(!CTradeUtils::IsTradingAllowed()) return INIT_FAILED;

    g_analyzer   = new CSMCAnalyzer(_Symbol);
    g_filters    = new CFilters(_Symbol);
    g_engine     = new CTradingEngine(_Symbol, Magic_Number, Order_Comment_Prefix, Slippage_Points);
    g_visualizer = new CVisualizer(Order_Comment_Prefix);
    
    if(CheckPointer(g_analyzer) == POINTER_INVALID || CheckPointer(g_filters) == POINTER_INVALID || 
       CheckPointer(g_engine) == POINTER_INVALID || CheckPointer(g_visualizer) == POINTER_INVALID)
        return INIT_FAILED;
    
    Print("=== SMC EA Initialized ===");
    Print("Mode: ", (Auto_Trade_Mode ? "AUTO TRADING" : "MANUAL SIGNALS"));
    Print("Profile: ", GetProfileDescription());
    
    g_initialized = true;
    g_last_ob_time = 0;
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(CheckPointer(g_visualizer) != POINTER_INVALID) { g_visualizer.ClearAll(); delete g_visualizer; }
    if(CheckPointer(g_analyzer) != POINTER_INVALID) delete g_analyzer;
    if(CheckPointer(g_filters) != POINTER_INVALID) delete g_filters;
    if(CheckPointer(g_engine) != POINTER_INVALID) delete g_engine;
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!g_initialized) return;

    // Kill switch check
    if(CTradeUtils::IsDailyLossReached(Max_Daily_Drawdown_Percent)) {
        if(CheckPointer(g_visualizer) != POINTER_INVALID)
            g_visualizer.UpdateDashboard("TRADING STOPPED", "Daily Limit Hit", PositionGetDouble(POSITION_PROFIT), 0, Auto_Trade_Mode);
        return;
    }

    double float_pnl = PositionGetDouble(POSITION_PROFIT);
    int total_pos = PositionsTotal();
    
    if(g_has_position && PositionSelectByTicket(PositionGetTicket(0)))
        g_visualizer.UpdateTradeLines(PositionGetDouble(POSITION_SL), PositionGetDouble(POSITION_TP));
    
    g_visualizer.UpdateDashboard((g_has_position ? "MANAGING TRADE" : "SCANNING"), "Monitoring...", float_pnl, total_pos, Auto_Trade_Mode);

    if(!CTradeUtils::IsNewBar(Timeframe_Entry, _Symbol)) return;

    g_has_position = g_filters.HasOpenPosition(Magic_Number);

    if(!g_has_position) {
        g_visualizer.ClearTradeLines();
        
        g_structure_range = g_analyzer.Get_Structure_Range(Timeframe_Structure, Lookback_Candles);
        
        if(g_structure_range.is_valid) {
            // Draw zones if visuals enabled
            if(Show_Visuals) g_visualizer.DrawZones(g_structure_range);
            
            g_current_ob = g_analyzer.Find_OrderBlock(Timeframe_Structure, Lookback_Candles, Min_OB_Body_Points);

            if(g_current_ob.is_valid) {
                // CRITICAL: Prevent duplicate signals from same OB
                if(g_current_ob.time_created == g_last_ob_time) {
                    if(Debug_Mode) Print("[DUPLICATE BLOCKED] Same OB at ", TimeToString(g_current_ob.time_created));
                    return;
                }
                
                // Check for inducement
                if(Inducement_Required) {
                    g_analyzer.Has_Inducement(g_current_ob, Timeframe_Structure);
                }
                
                // Draw visuals
                if(Show_Visuals) {
                    g_visualizer.DrawOrderBlock(g_current_ob);
                    g_visualizer.DrawStructureBreak(g_analyzer.GetLastBreak());
                    if(g_current_ob.has_inducement) g_visualizer.DrawInducement(g_current_ob);
                    // NEW: Draw projected Entry, SL, TP levels
                    g_visualizer.DrawProjectedLevels(g_current_ob, SL_Padding_Points, Risk_Reward_Ratio);
                }
                
                g_visualizer.UpdateDashboard("OB FOUND", "Validating...", 0, 0, Auto_Trade_Mode);
                ChartRedraw();
                
                if(g_analyzer.IsPriceNearOB(g_current_ob, 50)) {
                    bool trade_days[] = {Trade_Monday, Trade_Tuesday, Trade_Wednesday, Trade_Thursday, Trade_Friday};
                    if(g_filters.Check_Time_Filter(Use_Time_Filter, Trading_Start_Time, Trading_End_Time, trade_days)) {
                        if(g_filters.Can_Trade_Setup(g_current_ob, g_structure_range, Use_Premium_Discount_Filter, Inducement_Required, Magic_Number)) {
                            
                            bool is_buy = (g_current_ob.ob_type == OB_BULLISH);
                            double signal_price = (is_buy ? g_current_ob.price_top : g_current_ob.price_bottom);
                            
                            // MANUAL MODE: Show signal but don't trade
                            if(!Auto_Trade_Mode) {
                                string signal_msg = StringFormat("%s SIGNAL @ %.5f | OB: %.5f-%.5f | Mode: MANUAL",
                                    (is_buy ? "BUY" : "SELL"), signal_price, g_current_ob.price_bottom, g_current_ob.price_top);
                                
                                Print("[MANUAL SIGNAL] ", signal_msg);
                                
                                if(Alert_Popup) Alert(signal_msg);
                                if(Alert_Sound) PlaySound("alert.wav");
                                if(Show_Visuals) g_visualizer.DrawSignalArrow(is_buy, TimeCurrent(), signal_price, "OB");
                                
                                g_visualizer.UpdateDashboard("SIGNAL DETECTED", "Manual Mode - Trade Manually", 0, 0, Auto_Trade_Mode);
                                g_last_ob_time = g_current_ob.time_created; // Mark as processed
                            }
                            // AUTO MODE: Execute trade AND show signals
                            else {
                                string signal_msg = StringFormat("%s SIGNAL @ %.5f | OB: %.5f-%.5f | Mode: AUTO",
                                    (is_buy ? "BUY" : "SELL"), signal_price, g_current_ob.price_bottom, g_current_ob.price_top);
                                
                                Print("[AUTO SIGNAL] ", signal_msg);
                                
                                if(g_engine.Place_OB_Entry(g_current_ob, Entry_Mode, Risk_Per_Trade_Percent, SL_Padding_Points, Risk_Reward_Ratio)) {
                                    Print("[AUTO TRADE] ", (is_buy ? "BUY" : "SELL"), " executed @ ", signal_price);
                                    
                                    // Show visual signals
                                    if(Show_Visuals) {
                                        g_visualizer.DrawSignalArrow(is_buy, TimeCurrent(), signal_price, "OB-AUTO");
                                        g_visualizer.MarkEntry(is_buy, signal_price, TimeCurrent());
                                    }
                                    
                                    if(Alert_Sound) PlaySound("ok.wav");
                                    if(Alert_Popup) Alert("TRADE OPENED: " + signal_msg);
                                    
                                    g_last_ob_time = g_current_ob.time_created; // Mark as processed
                                }
                            }
                        }
                    }
                }
            }
        }
    } else {
         g_current_fvg = g_analyzer.Find_Valid_FVG(Timeframe_Entry, Lookback_Candles / 2, Min_FVG_Gap_Points);
         if(g_current_fvg.is_valid) {
             if(Show_Visuals) g_visualizer.DrawFVG(g_current_fvg);
             
             if(g_filters.Can_Scale_FVG(g_current_fvg, g_current_ob, Max_Scaling_Orders, Magic_Number)) {
                 if(g_engine.Manage_Scaling_FVG(g_current_fvg, g_current_ob, Risk_Per_Trade_Percent, SL_Padding_Points, Risk_Reward_Ratio)) {
                      if(Show_Visuals) g_visualizer.MarkEntry((g_current_ob.ob_type == OB_BULLISH), g_current_fvg.ce_50_percent, TimeCurrent());
                 }
             }
         }
    }
    g_engine.Clean_Expired_Orders(Scaling_Expiration_Bars, Timeframe_Entry);
}

//+------------------------------------------------------------------+
//| Trade event handler                                               |
//+------------------------------------------------------------------+
void OnTrade() {
    if(CheckPointer(g_filters) != POINTER_INVALID) g_has_position = g_filters.HasOpenPosition(Magic_Number);
    if(CheckPointer(g_visualizer) != POINTER_INVALID) {
        if(!g_has_position) {
            g_visualizer.ClearTradeLines();
            g_last_ob_time = 0; // Reset when position closes
        }
        else if(PositionSelectByTicket(PositionGetTicket(0)))
            g_visualizer.UpdateTradeLines(PositionGetDouble(POSITION_SL), PositionGetDouble(POSITION_TP));
    }
}