//+------------------------------------------------------------------+
//|                                                        Enums.mqh |
//|                                    EA SMC Multi-Profile          |
//|                                    Enumerations and Constants    |
//+------------------------------------------------------------------+
#property copyright "EA SMC Multi-Profile"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Entry Mode Enumeration                                            |
//+------------------------------------------------------------------+
enum ENUM_ENTRY_MODE
{
    ENTRY_TOUCH,              // Enter at Order Block boundary (Scalper style)
    ENTRY_MEAN_THRESHOLD      // Enter at 50% of Order Block (Swing style)
};

//+------------------------------------------------------------------+
//| Trading Profile Enumeration                                       |
//+------------------------------------------------------------------+
enum ENUM_PROFILE_TYPE
{
    PROFILE_SCALPER,          // H1/M5 - Fast entries, short expiration
    PROFILE_SWING,            // W1/D1 - Patient entries, long expiration
    PROFILE_INTRADAY          // H4/M15 - Balanced approach
};

//+------------------------------------------------------------------+
//| Order Block Type                                                  |
//+------------------------------------------------------------------+
enum ENUM_OB_TYPE
{
    OB_BULLISH,               // Bullish Order Block (demand zone)
    OB_BEARISH                // Bearish Order Block (supply zone)
};

//+------------------------------------------------------------------+
//| Fair Value Gap Type                                               |
//+------------------------------------------------------------------+
enum ENUM_FVG_TYPE
{
    FVG_BULLISH,              // Bullish FVG (buy opportunity)
    FVG_BEARISH               // Bearish FVG (sell opportunity)
};

//+------------------------------------------------------------------+
//| Zone Type for Premium/Discount Filter                            |
//+------------------------------------------------------------------+
enum ENUM_ZONE_TYPE
{
    ZONE_PREMIUM,             // Above 50% equilibrium (sell zone)
    ZONE_DISCOUNT,            // Below 50% equilibrium (buy zone)
    ZONE_EQUILIBRIUM          // At 50% (neutral)
};

//+------------------------------------------------------------------+
//| Constants                                                         |
//+------------------------------------------------------------------+
#define MAGIC_NUMBER_BASE    123456    // Base magic number for EA identification
#define MAX_LOOKBACK_BARS    500       // Maximum bars to look back
#define MIN_OB_BODY_POINTS   10        // Minimum OB body size in points
#define MIN_FVG_GAP_POINTS   5         // Minimum FVG gap size in points

//+------------------------------------------------------------------+
//| Order Comment Tags                                                |
//+------------------------------------------------------------------+
#define COMMENT_OB_ENTRY     "SMC_OB"     // Order Block entry
#define COMMENT_FVG_SCALE    "SMC_FVG"    // FVG scaling entry
#define COMMENT_MANUAL       "SMC_MANUAL" // Manual intervention

//+------------------------------------------------------------------+
