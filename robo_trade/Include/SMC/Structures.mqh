//+------------------------------------------------------------------+
//|                                                   Structures.mqh |
//+------------------------------------------------------------------+
#property copyright "EA SMC Multi-Profile"
#property strict

#include "Enums.mqh"

// Estrutura para eventos de estrutura de mercado (BOS/CHOCH)
struct MarketStructureEvent
{
   bool              is_valid;
   ENUM_MS_EVENT_TYPE type;
   datetime          time;
   double            price;
   int               bar_index;
   int               broken_swing_idx;
};

// Estrutura para Order Block
struct OrderBlock
{
   bool              is_valid;
   ENUM_OB_TYPE      ob_type;
   double            price_top;
   double            price_bottom;
   double            mean_threshold;
   bool              has_inducement;
   
   // Metadados
   datetime          time_created;
   int               candle_index;
   bool              caused_break;
   
   // Inducement Data
   double            inducement_price;
   datetime          inducement_time;

   void CalculateMean()
   {
      mean_threshold = (price_top + price_bottom) / 2.0;
   }

   bool Validate(double min_points)
   {
      double size = MathAbs(price_top - price_bottom);
      return (size >= min_points * 0.00001); 
   }
};

// Estrutura para Range de Estrutura (HTF)
struct StructureRange
{
   bool              is_valid;
   double            structure_high;
   double            structure_low;
   datetime          time_high;
   datetime          time_low;

   void CalculateEquilibrium() { /* Placeholder */ }

   ENUM_ZONE_TYPE GetZoneType(double price) const
   {
      if(!is_valid) return ZONE_EQUILIBRIUM;
      double midpoint = (structure_high + structure_low) / 2.0;
      if(price > midpoint) return ZONE_PREMIUM;
      if(price < midpoint) return ZONE_DISCOUNT;
      return ZONE_EQUILIBRIUM;
   }
};

// Estrutura para Fair Value Gap (FVG)
struct FairValueGap
{
   bool              is_valid;
   ENUM_FVG_TYPE     fvg_type;
   double            price_top;
   double            price_bottom;
   double            ce_50_percent;
   datetime          time_created;
   int               candle_index;

   void CalculateCE() { ce_50_percent = (price_top + price_bottom) / 2.0; }

   bool Validate(double min_points)
   {
      double gap = MathAbs(price_top - price_bottom);
      return (gap >= min_points * 0.00001); 
   }
};