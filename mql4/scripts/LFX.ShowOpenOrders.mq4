/**
 *
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[] = { INIT_DOESNT_REQUIRE_BARS };
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <functions/JoinStrings.mqh>
#include <stdlib.mqh>

#include <win32api.mqh>
#include <remote/functions.mqh>
#include <structs/pewa/LFX_ORDER.mqh>


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // TradeAccount und Status initialisieren
   if (!InitTradeAccount())
      return(last_error);
   return(catch("onInit(1)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   // aktuellen Anzeigestatus aus Chart auslesen und umschalten: ON/OFF
   bool status = true; status = !status;  // war vorher Statusfunktion


   // (1) Status ON: offene Orders einlesen und anzeigen
   if (status) {
      string lfxCurrency = "";
      if      (StringStartsWith(Symbol(), "LFX")) lfxCurrency = StringRight(Symbol(), -3);
      else if (StringEndsWith  (Symbol(), "LFX")) lfxCurrency = StringLeft (Symbol(), -3);

      /*LFX_ORDER*/int los[][LFX_ORDER.intSize];
      int orders = LFX.GetOrders(lfxCurrency, OF_OPEN, los);

      for (int i=0; i < orders; i++) {
         if (!ShowOpenOrder(los, i))
            break;
      }
      ArrayResize(los, 0);
   }


   // (2) Status OFF: Chartobjekte offener Orders l�schen
   else {
      for (i=ObjectsTotal()-1; i >= 0; i--) {
         string name = ObjectName(i);
         if (StringStartsWith(name, "lfx.open order "))
            ObjectDelete(name);
      }
   }

   if (This.IsTesting())
      WindowRedraw();
   return(last_error);
}


/**
 * Zeigt die angegebene LFX_ORDER an.
 *
 * @param  LFX_ORDER los[] - eine einzelne LFX_ORDER oder ein LFX_ORDER-Array
 * @param  int       index - Arrayindex der zu speichernden Order, wenn los[] ein LFX_ORDER-Array ist.
 *                           Wird ignoriert, wenn los[] eine einzelne LFX_ORDER ist.
 *
 * @return bool - Erfolgsstatus
 */
bool ShowOpenOrder(/*LFX_ORDER*/int los[], int index=NULL) {
   string   comment, labelBase, label, text, sPrice;
   int      type;
   datetime openTime;
   double   units, openPrice, slPrice, slValue, tpPrice, tpValue;


   // (1) Daten auslesen
   int dims = ArrayDimension(los); if (dims > 2) return(!catch("ShowOpenOrder(1)  invalid dimensions of parameter los = "+ dims, ERR_INCOMPATIBLE_ARRAYS));
   if (dims == 1) {
      // los[] ist einzelne Order
      comment   =                     lo.Comment        (los);
      type      =                     lo.Type           (los);
      units     =                     lo.Units          (los);
      openTime  = GmtToServerTime(Abs(lo.OpenTime       (los)));
      openPrice =                     lo.OpenPrice      (los);
      slPrice   =                     lo.StopLoss       (los);
      slValue   =                     lo.StopLossValue  (los);
      tpPrice   =                     lo.TakeProfit     (los);
      tpValue   =                     lo.TakeProfitValue(los);
   }
   else {
      // los[] ist Order-Array
      comment   =                     los.Comment        (los, index);
      type      =                     los.Type           (los, index);
      units     =                     los.Units          (los, index);
      openTime  = GmtToServerTime(Abs(los.OpenTime       (los, index)));
      openPrice =                     los.OpenPrice      (los, index);
      slPrice   =                     los.StopLoss       (los, index);
      slValue   =                     los.StopLossValue  (los, index);
      tpPrice   =                     los.TakeProfit     (los, index);
      tpValue   =                     los.TakeProfitValue(los, index);
   }
   labelBase = StringConcatenate("lfx.open order ", comment);


   // (2) Order anzeigen
   sPrice = NumberToStr(openPrice, SubPipPriceFormat);
   label  = StringConcatenate(labelBase, " at ", sPrice);
   text   = StringConcatenate(" ", comment, ":  ", NumberToStr(units, ".+"), " x ", sPrice);
   if (slValue != EMPTY_VALUE) text = StringConcatenate(text, ", sl: "+ DoubleToStr(slValue, 2));
   if (tpValue != EMPTY_VALUE) text = StringConcatenate(text, ", tp: "+ DoubleToStr(tpValue, 2));

   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_TREND, 0, D'1970.01.01 00:01', openPrice, openTime, openPrice)) {
      ObjectSet(label, OBJPROP_RAY  , false);
      ObjectSet(label, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet(label, OBJPROP_COLOR, ifInt(IsLongTradeOperation(type), Green, Red));
      ObjectSet(label, OBJPROP_BACK , false);
      ObjectSetText(label, text);
   }


   // (3) StopLoss anzeigen
   if (slPrice != 0) {
      // Marker
      sPrice = NumberToStr(slPrice, SubPipPriceFormat);
      label  = StringConcatenate(labelBase, " stoploss at ", sPrice);
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_ARROW, 0, TimeCurrentEx("ShowOpenOrder(2)"), slPrice)) {
         ObjectSet    (label, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
         ObjectSet    (label, OBJPROP_COLOR    , Red             );
      }
      // Trendlinie: #2 -> sl 1.4967'3
      label = StringConcatenate(labelBase, " -> sl ", sPrice);
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_TREND, 0, openTime, openPrice, TimeCurrentEx("ShowOpenOrder(3)"), slPrice)) {
         ObjectSet(label, OBJPROP_RAY  , false      );
         ObjectSet(label, OBJPROP_STYLE, STYLE_DOT  );
         ObjectSet(label, OBJPROP_COLOR, DeepSkyBlue);
         ObjectSet(label, OBJPROP_BACK , true       );
      }
   }


   // (4) TakeProfit anzeigen
   if (tpPrice != 0) {
      // Marker
      sPrice = NumberToStr(tpPrice, SubPipPriceFormat);
      label  = StringConcatenate(labelBase, " takeprofit at ", sPrice);
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_ARROW, 0, TimeCurrentEx("ShowOpenOrder(4)"), tpPrice)) {
         ObjectSet    (label, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
         ObjectSet    (label, OBJPROP_COLOR    , LimeGreen       );
      }
      // Trendlinie: #2 -> tp 1.4967'3
      label = StringConcatenate(labelBase, " -> tp ", sPrice);
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_TREND, 0, openTime, openPrice, TimeCurrentEx("ShowOpenOrder(5)"), tpPrice)) {
         ObjectSet(label, OBJPROP_RAY  , false      );
         ObjectSet(label, OBJPROP_STYLE, STYLE_DOT  );
         ObjectSet(label, OBJPROP_COLOR, DeepSkyBlue);
         ObjectSet(label, OBJPROP_BACK , true       );
      }
   }

   return(!catch("ShowOpenOrder(2)"));
}
