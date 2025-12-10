//+------------------------------------------------------------------+
//|                                                   Visualizer.mqh |
//|                                    EA SMC Multi-Profile          |
//|                                    Visualization & Dashboard      |
//+------------------------------------------------------------------+
#property copyright "EA SMC Multi-Profile"
#property strict

#include "Enums.mqh"
#include "Structures.mqh"

class CVisualizer
{
private:
    string m_prefix;
    
    void CreateLabel(string name, int x, int y, string text, color clr, int fontsize=10)
    {
        if(ObjectFind(0, name) < 0)
            ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
            
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetString(0, name, OBJPROP_TEXT, text);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontsize);
    }

public:
    CVisualizer(string prefix)
    {
        m_prefix = prefix;
    }
    
    ~CVisualizer()
    {
        ClearAll();
    }
    
    void ClearAll()
    {
        ObjectsDeleteAll(0, m_prefix);
    }
    
    void UpdateDashboard(string status, string message, double pnl, int positions, bool is_auto_mode)
    {
        string pfx = m_prefix + "_Dash_";
        int y = 20;
        
        CreateLabel(pfx + "Title", 20, y, "=== SMC EA DASHBOARD ===", clrWhite, 12); y += 25;
        CreateLabel(pfx + "Mode", 20, y, "Mode: " + (is_auto_mode ? "AUTO" : "MANUAL"), (is_auto_mode ? clrLime : clrOrange), 11); y += 20;
        CreateLabel(pfx + "Status", 20, y, "Status: " + status, clrYellow); y += 20;
        CreateLabel(pfx + "Msg", 20, y, "Msg: " + message, clrGray); y += 20;
        CreateLabel(pfx + "PnL", 20, y, "PnL: " + DoubleToString(pnl, 2), (pnl >= 0 ? clrLime : clrRed)); y += 20;
        CreateLabel(pfx + "Pos", 20, y, "Positions: " + IntegerToString(positions), clrWhite);
        
        ChartRedraw();
    }
    
    void DrawOrderBlock(OrderBlock &ob)
    {
        if(!ob.is_valid) return;
        
        string name = m_prefix + "_OB_" + TimeToString(ob.time_created);
        
        if(ObjectFind(0, name) < 0)
            ObjectCreate(0, name, OBJ_RECTANGLE, 0, ob.time_created, ob.price_top, TimeCurrent(), ob.price_bottom);
            
        color ob_color = (ob.ob_type == OB_BULLISH ? clrDodgerBlue : clrCrimson);
        ObjectSetInteger(0, name, OBJPROP_COLOR, ob_color);
        ObjectSetInteger(0, name, OBJPROP_FILL, true);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
        
        // Extend to current time
        ObjectSetInteger(0, name, OBJPROP_TIME, 0, TimeCurrent() + PeriodSeconds(PERIOD_CURRENT)*10);
        
        // Draw mean threshold line
        string mean_name = name + "_Mean";
        if(ObjectFind(0, mean_name) < 0)
            ObjectCreate(0, mean_name, OBJ_TREND, 0, ob.time_created, ob.mean_threshold, TimeCurrent(), ob.mean_threshold);
        
        ObjectSetInteger(0, mean_name, OBJPROP_COLOR, ob_color);
        ObjectSetInteger(0, mean_name, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, mean_name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, mean_name, OBJPROP_RAY_RIGHT, true);
        
        // Add label
        string label_name = name + "_Label";
        if(ObjectFind(0, label_name) < 0)
            ObjectCreate(0, label_name, OBJ_TEXT, 0, ob.time_created, ob.price_top);
        
        string label_text = (ob.ob_type == OB_BULLISH ? "BULLISH OB ↑" : "BEARISH OB ↓");
        ObjectSetString(0, label_name, OBJPROP_TEXT, "  " + label_text);
        ObjectSetInteger(0, label_name, OBJPROP_COLOR, ob_color);
        ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 9);
        ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
    }
    
    void DrawFVG(FairValueGap &fvg)
    {
        if(!fvg.is_valid) return;
        
        string name = m_prefix + "_FVG_" + TimeToString(fvg.time_created);
        
        if(ObjectFind(0, name) < 0)
            ObjectCreate(0, name, OBJ_RECTANGLE, 0, fvg.time_created, fvg.price_top, TimeCurrent(), fvg.price_bottom);
            
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrGold);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, name, OBJPROP_FILL, false);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        
        // Extend to current time
        ObjectSetInteger(0, name, OBJPROP_TIME, 0, TimeCurrent() + PeriodSeconds(PERIOD_CURRENT)*10);
        
        // Draw 50% CE line
        string ce_name = name + "_CE";
        if(ObjectFind(0, ce_name) < 0)
            ObjectCreate(0, ce_name, OBJ_TREND, 0, fvg.time_created, fvg.ce_50_percent, TimeCurrent(), fvg.ce_50_percent);
        
        ObjectSetInteger(0, ce_name, OBJPROP_COLOR, clrGold);
        ObjectSetInteger(0, ce_name, OBJPROP_STYLE, STYLE_DASHDOT);
        ObjectSetInteger(0, ce_name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, ce_name, OBJPROP_RAY_RIGHT, true);
    }
    
    void DrawStructureBreak(MarketStructureEvent &event)
    {
        if(!event.is_valid) return;
        
        string name = m_prefix + "_BOS_" + TimeToString(event.time);
        
        // Minimalist: Just a text label, no vertical line
        if(ObjectFind(0, name) < 0)
            ObjectCreate(0, name, OBJ_TEXT, 0, event.time, event.price);
            
        color text_color = (event.type == MS_BOS_BULLISH ? clrLime : clrRed);
        string label_text = (event.type == MS_BOS_BULLISH ? "▲ BOS" : "▼ BOS");
        
        ObjectSetString(0, name, OBJPROP_TEXT, label_text);
        ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
        ObjectSetInteger(0, name, OBJPROP_ANCHOR, (event.type == MS_BOS_BULLISH ? ANCHOR_TOP : ANCHOR_BOTTOM));
    }
    
    void DrawZones(StructureRange &range)
    {
        if(!range.is_valid) return;
        
        double midpoint = (range.structure_high + range.structure_low) / 2.0;
        datetime start_time = (range.time_high < range.time_low ? range.time_high : range.time_low);
        datetime end_time = TimeCurrent() + PeriodSeconds(PERIOD_CURRENT)*10;
        
        // Minimalist: Just lines for High, Low, EQ. No rectangles.
        
        // 1. Structure High Line
        string high_name = m_prefix + "_Zone_High";
        if(ObjectFind(0, high_name) < 0)
            ObjectCreate(0, high_name, OBJ_TREND, 0, start_time, range.structure_high, end_time, range.structure_high);
        
        ObjectSetInteger(0, high_name, OBJPROP_COLOR, clrMaroon);
        ObjectSetInteger(0, high_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, high_name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, high_name, OBJPROP_RAY_RIGHT, false);
        
        // 2. Structure Low Line
        string low_name = m_prefix + "_Zone_Low";
        if(ObjectFind(0, low_name) < 0)
            ObjectCreate(0, low_name, OBJ_TREND, 0, start_time, range.structure_low, end_time, range.structure_low);
        
        ObjectSetInteger(0, low_name, OBJPROP_COLOR, clrDarkGreen);
        ObjectSetInteger(0, low_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, low_name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, low_name, OBJPROP_RAY_RIGHT, false);
        
        // 3. EQ Line
        string eq_name = m_prefix + "_Zone_EQ";
        if(ObjectFind(0, eq_name) < 0)
            ObjectCreate(0, eq_name, OBJ_TREND, 0, start_time, midpoint, end_time, midpoint);
        
        ObjectSetInteger(0, eq_name, OBJPROP_COLOR, clrGold);
        ObjectSetInteger(0, eq_name, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, eq_name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, eq_name, OBJPROP_RAY_RIGHT, false);
        
        // Labels
        string high_label = high_name + "_Label";
        if(ObjectFind(0, high_label) < 0) ObjectCreate(0, high_label, OBJ_TEXT, 0, end_time, range.structure_high);
        ObjectSetString(0, high_label, OBJPROP_TEXT, "  High");
        ObjectSetInteger(0, high_label, OBJPROP_COLOR, clrMaroon);
        ObjectSetInteger(0, high_label, OBJPROP_ANCHOR, ANCHOR_LEFT);
        ObjectSetInteger(0, high_label, OBJPROP_FONTSIZE, 8);

        string low_label = low_name + "_Label";
        if(ObjectFind(0, low_label) < 0) ObjectCreate(0, low_label, OBJ_TEXT, 0, end_time, range.structure_low);
        ObjectSetString(0, low_label, OBJPROP_TEXT, "  Low");
        ObjectSetInteger(0, low_label, OBJPROP_COLOR, clrDarkGreen);
        ObjectSetInteger(0, low_label, OBJPROP_ANCHOR, ANCHOR_LEFT);
        ObjectSetInteger(0, low_label, OBJPROP_FONTSIZE, 8);
        
        string eq_label = eq_name + "_Label";
        if(ObjectFind(0, eq_label) < 0) ObjectCreate(0, eq_label, OBJ_TEXT, 0, end_time, midpoint);
        ObjectSetString(0, eq_label, OBJPROP_TEXT, "  EQ 50%");
        ObjectSetInteger(0, eq_label, OBJPROP_COLOR, clrGold);
        ObjectSetInteger(0, eq_label, OBJPROP_ANCHOR, ANCHOR_LEFT);
        ObjectSetInteger(0, eq_label, OBJPROP_FONTSIZE, 8);
    }
    
    void DrawInducement(OrderBlock &ob)
    {
        if(!ob.is_valid || !ob.has_inducement) return;
        
        string name = m_prefix + "_IND_" + TimeToString(ob.inducement_time);
        
        if(ObjectFind(0, name) < 0)
            ObjectCreate(0, name, OBJ_ARROW, 0, ob.inducement_time, ob.inducement_price);
        
        ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 251); // X marker
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrMagenta);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
        
        // Add label
        string label_name = name + "_Label";
        if(ObjectFind(0, label_name) < 0)
            ObjectCreate(0, label_name, OBJ_TEXT, 0, ob.inducement_time, ob.inducement_price);
        
        ObjectSetString(0, label_name, OBJPROP_TEXT, "INDUCEMENT");
        ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrMagenta);
        ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 8);
    }
    
    void DrawProjectedLevels(OrderBlock &ob, double sl_padding_points, double rr_ratio)
    {
        if(!ob.is_valid) return;
        
        bool is_buy = (ob.ob_type == OB_BULLISH);
        string base_name = m_prefix + "_Levels_" + TimeToString(ob.time_created);
        
        // Calculate projected levels
        double entry_price = (is_buy ? ob.price_top : ob.price_bottom);
        double sl_price = is_buy ? (entry_price - sl_padding_points * _Point) : (entry_price + sl_padding_points * _Point);
        double sl_distance = MathAbs(entry_price - sl_price);
        double tp_price = is_buy ? (entry_price + sl_distance * rr_ratio) : (entry_price - sl_distance * rr_ratio);
        
        // Position labels on the RIGHT side of OB (near current time)
        datetime label_time = TimeCurrent() + PeriodSeconds(PERIOD_CURRENT) * 2;
        
        // === AXIS MARKERS (Arrows on the price axis) ===
        // ENTRY Marker
        string entry_arrow = base_name + "_Entry_Arrow";
        if(ObjectFind(0, entry_arrow) < 0) ObjectCreate(0, entry_arrow, OBJ_ARROW_RIGHT_PRICE, 0, label_time, entry_price);
        ObjectSetInteger(0, entry_arrow, OBJPROP_COLOR, (is_buy ? clrDodgerBlue : clrOrangeRed));
        ObjectSetInteger(0, entry_arrow, OBJPROP_WIDTH, 2);
        
        // SL Marker
        string sl_arrow = base_name + "_SL_Arrow";
        if(ObjectFind(0, sl_arrow) < 0) ObjectCreate(0, sl_arrow, OBJ_ARROW_RIGHT_PRICE, 0, label_time, sl_price);
        ObjectSetInteger(0, sl_arrow, OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, sl_arrow, OBJPROP_WIDTH, 1);
        
        // TP Marker
        string tp_arrow = base_name + "_TP_Arrow";
        if(ObjectFind(0, tp_arrow) < 0) ObjectCreate(0, tp_arrow, OBJ_ARROW_RIGHT_PRICE, 0, label_time, tp_price);
        ObjectSetInteger(0, tp_arrow, OBJPROP_COLOR, clrLimeGreen);
        ObjectSetInteger(0, tp_arrow, OBJPROP_WIDTH, 1);
        
        // === INFO TEXT (Single Line to avoid overlap) ===
        string text_name = base_name + "_Info_Text";
        if(ObjectFind(0, text_name) < 0)
            ObjectCreate(0, text_name, OBJ_TEXT, 0, label_time, entry_price);
            
        // Format: "BUY: 1.1234 | SL: 1.1200 | TP: 1.1300"
        string info_text = StringFormat(" %s: %.5f | SL: %.5f | TP: %.5f (R:%.1f)",
                                      (is_buy ? "BUY" : "SELL"), entry_price, sl_price, tp_price, rr_ratio);
                                      
        ObjectSetString(0, text_name, OBJPROP_TEXT, info_text);
        ObjectSetInteger(0, text_name, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, text_name, OBJPROP_ANCHOR, ANCHOR_LEFT); // Text extends to the right
        
        // Move text slightly above/below entry to not cover the candle if close
        // Actually, centering on Entry Price is fine if it's to the right of current price
    }
    
    void DrawSignalArrow(bool is_buy, datetime time, double price, string signal_type)
    {
        string name = m_prefix + "_SIGNAL_" + TimeToString(time);
        
        if(ObjectFind(0, name) < 0)
            ObjectCreate(0, name, OBJ_ARROW, 0, time, price);
        
        ObjectSetInteger(0, name, OBJPROP_ARROWCODE, (is_buy ? 241 : 242)); // Large arrows
        ObjectSetInteger(0, name, OBJPROP_COLOR, (is_buy ? clrLime : clrRed));
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 5);
        
        // Add signal label
        string label_name = name + "_Label";
        if(ObjectFind(0, label_name) < 0)
            ObjectCreate(0, label_name, OBJ_TEXT, 0, time, price);
        
        string label_text = (is_buy ? "BUY SIGNAL" : "SELL SIGNAL") + " [" + signal_type + "]";
        ObjectSetString(0, label_name, OBJPROP_TEXT, label_text);
        ObjectSetInteger(0, label_name, OBJPROP_COLOR, (is_buy ? clrLime : clrRed));
        ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 10);
        ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, (is_buy ? ANCHOR_TOP : ANCHOR_BOTTOM));
    }
    
    void UpdateTradeLines(double sl, double tp)
    {
        string sl_name = m_prefix + "_SL_Line";
        string tp_name = m_prefix + "_TP_Line";
        
        if(ObjectFind(0, sl_name) < 0) ObjectCreate(0, sl_name, OBJ_HLINE, 0, 0, sl);
        else ObjectSetDouble(0, sl_name, OBJPROP_PRICE, sl);
        
        if(ObjectFind(0, tp_name) < 0) ObjectCreate(0, tp_name, OBJ_HLINE, 0, 0, tp);
        else ObjectSetDouble(0, tp_name, OBJPROP_PRICE, tp);
        
        ObjectSetInteger(0, sl_name, OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, sl_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, sl_name, OBJPROP_STYLE, STYLE_SOLID);
        
        ObjectSetInteger(0, tp_name, OBJPROP_COLOR, clrGreen);
        ObjectSetInteger(0, tp_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, tp_name, OBJPROP_STYLE, STYLE_SOLID);
    }
    
    void ClearTradeLines()
    {
        ObjectDelete(0, m_prefix + "_SL_Line");
        ObjectDelete(0, m_prefix + "_TP_Line");
    }
    
    void MarkEntry(bool is_buy, double price, datetime time)
    {
        string name = m_prefix + "_Entry_" + TimeToString(time);
        if(ObjectFind(0, name) < 0)
            ObjectCreate(0, name, OBJ_ARROW, 0, time, price);
            
        ObjectSetInteger(0, name, OBJPROP_ARROWCODE, (is_buy ? 233 : 234));
        ObjectSetInteger(0, name, OBJPROP_COLOR, (is_buy ? clrBlue : clrRed));
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
    }
};
