#property strict

extern int MACDFastEMA = 12;
extern int MACDSlowEMA = 26;
extern int MACDSignal  = 9;

extern int EMAFast     = 50;
extern int EMASlow     = 200;

extern int FractalSearchBars = 100;

extern double LotSize  = 0.01;
extern int Slippage    = 10;

datetime LastBarTime = 0;
int OrderTicket = 0;
bool OrderOpened = false;
double StopLossLevel = 0;
double TakeProfitLevel = 0;
int TradeDirection = 0; // 1 = BUY, -1 = SELL
int LastOrderTicket = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   CreatePanel();
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete(0,"UpperLevel");
   ObjectDelete(0,"LowerLevel");
   ObjectDelete(0,"TrendPanel");
}
//+------------------------------------------------------------------+
void OnTick()
{
   UpdateTrendPanel();
   CheckOrderStatus();

   if(Time[0] != LastBarTime)
   {
      LastBarTime = Time[0];
      
      if(!OrderOpened)
      {
         CheckMACDCross();
      }
   }
}
//+------------------------------------------------------------------+
void CheckOrderStatus()
{
   if(!OrderOpened)
      return;
   
   bool foundOrder = false;
   
   for(int i=0; i<OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderTicket() == LastOrderTicket && OrderSymbol() == Symbol())
         {
            foundOrder = true;
            break;
         }
      }
   }
   
   if(!foundOrder)
   {
      OrderOpened = false;
      OrderTicket = 0;
      LastOrderTicket = 0;
      TradeDirection = 0;
      
      // Удаляем линии когда ордер закрывается
      ObjectDelete(0,"UpperLevel");
      ObjectDelete(0,"LowerLevel");
      
      Print("=== Order closed - Lines deleted, ready for new signal ===");
      ChartRedraw();
   }
}
//+------------------------------------------------------------------+
void CheckMACDCross()
{
   double macd1=iMACD(NULL,0,MACDFastEMA,MACDSlowEMA,MACDSignal,
                      PRICE_CLOSE,MODE_MAIN,1);

   double signal1=iMACD(NULL,0,MACDFastEMA,MACDSlowEMA,MACDSignal,
                        PRICE_CLOSE,MODE_SIGNAL,1);

   double macd2=iMACD(NULL,0,MACDFastEMA,MACDSlowEMA,MACDSignal,
                      PRICE_CLOSE,MODE_MAIN,2);

   double signal2=iMACD(NULL,0,MACDFastEMA,MACDSlowEMA,MACDSignal,
                        PRICE_CLOSE,MODE_SIGNAL,2);

   bool CrossUp=(macd2<signal2 && macd1>signal1);
   bool CrossDown=(macd2>signal2 && macd1<signal1);

   if(!CrossUp && !CrossDown)
      return;

   double HighLevel=0;
   double LowLevel=0;

   // Поиск верхнего фрактала
   for(int i=2;i<FractalSearchBars;i++)
   {
      double up=iFractals(NULL,0,MODE_UPPER,i);
      if(up>0)
      {
         HighLevel=up;
         break;
      }
   }

   // Поиск нижнего фрактала
   for(int j=2;j<FractalSearchBars;j++)
   {
      double dn=iFractals(NULL,0,MODE_LOWER,j);
      if(dn>0)
      {
         LowLevel=dn;
         break;
      }
   }

   if(HighLevel<=0 || LowLevel<=0)
   {
      Print("Fractals not found: HighLevel=", HighLevel, " LowLevel=", LowLevel);
      return;
   }

   // Проверка что линии не совпадают
   if(MathAbs(HighLevel - LowLevel) < Point())
   {
      Print("Fractals too close, skipping signal");
      return;
   }

   ObjectDelete(0,"UpperLevel");
   ObjectDelete(0,"LowerLevel");

   ObjectCreate(0,"UpperLevel",OBJ_HLINE,0,0,HighLevel);
   ObjectCreate(0,"LowerLevel",OBJ_HLINE,0,0,LowLevel);

   ObjectSetInteger(0,"UpperLevel",OBJPROP_WIDTH,3);
   ObjectSetInteger(0,"LowerLevel",OBJPROP_WIDTH,3);

   ObjectSetInteger(0,"UpperLevel",OBJPROP_BACK,false);
   ObjectSetInteger(0,"LowerLevel",OBJPROP_BACK,false);

   // Открытие ордера в зависимости от направления
   if(CrossUp)
   {
      ObjectSetInteger(0,"UpperLevel",OBJPROP_COLOR,clrDarkGreen);
      ObjectSetInteger(0,"LowerLevel",OBJPROP_COLOR,clrRed);
      
      StopLossLevel = LowLevel;
      TakeProfitLevel = HighLevel;
      OpenBuyOrder(StopLossLevel, TakeProfitLevel);
   }
   else if(CrossDown)
   {
      ObjectSetInteger(0,"UpperLevel",OBJPROP_COLOR,clrRed);
      ObjectSetInteger(0,"LowerLevel",OBJPROP_COLOR,clrDarkGreen);
      
      StopLossLevel = HighLevel;
      TakeProfitLevel = LowLevel;
      OpenSellOrder(StopLossLevel, TakeProfitLevel);
   }

   ChartRedraw();

   Print("=== MACD CROSS ===");
   Print("Upper Fractal = ",DoubleToString(HighLevel,Digits));
   Print("Lower Fractal = ",DoubleToString(LowLevel,Digits));
}
//+------------------------------------------------------------------+
void OpenBuyOrder(double stopLoss, double takeProfit)
{
   double price = Ask;
   
   int ticket = OrderSend(
      Symbol(),           // Инструмент
      OP_BUY,             // Операция
      LotSize,            // Объем
      price,              // Цена открытия
      Slippage,           // Проскальзывание
      stopLoss,           // StopLoss
      takeProfit,         // TakeProfit
      "MACD Fractal BUY", // Комментарий
      12345,              // MagicNumber
      0,                  // Время экспирации
      clrDarkGreen        // Цвет
   );
   
   if(ticket > 0)
   {
      LastOrderTicket = ticket;
      OrderTicket = ticket;
      OrderOpened = true;
      TradeDirection = 1;
      Print(">>> BUY Order opened, Ticket: ", ticket);
      Print("    Entry: ", DoubleToString(price, Digits));
      Print("    StopLoss: ", DoubleToString(stopLoss, Digits));
      Print("    TakeProfit: ", DoubleToString(takeProfit, Digits));
   }
   else
   {
      Print("ERROR opening BUY order: ", GetLastError());
   }
}
//+------------------------------------------------------------------+
void OpenSellOrder(double stopLoss, double takeProfit)
{
   double price = Bid;
   
   int ticket = OrderSend(
      Symbol(),            // Инструмент
      OP_SELL,             // Операция
      LotSize,             // Объем
      price,               // Цена открытия
      Slippage,            // Проскальзывание
      stopLoss,            // StopLoss
      takeProfit,          // TakeProfit
      "MACD Fractal SELL", // Комментарий
      12345,               // MagicNumber
      0,                   // Время экспирации
      clrRed               // Цвет
   );
   
   if(ticket > 0)
   {
      LastOrderTicket = ticket;
      OrderTicket = ticket;
      OrderOpened = true;
      TradeDirection = -1;
      Print(">>> SELL Order opened, Ticket: ", ticket);
      Print("    Entry: ", DoubleToString(price, Digits));
      Print("    StopLoss: ", DoubleToString(stopLoss, Digits));
      Print("    TakeProfit: ", DoubleToString(takeProfit, Digits));
   }
   else
   {
      Print("ERROR opening SELL order: ", GetLastError());
   }
}
//+------------------------------------------------------------------+
void CreatePanel()
{
   ObjectCreate(0,"TrendPanel",OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,"TrendPanel",OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,"TrendPanel",OBJPROP_XDISTANCE,10);
   ObjectSetInteger(0,"TrendPanel",OBJPROP_YDISTANCE,20);
}
//+------------------------------------------------------------------+
void UpdateTrendPanel()
{
   double emaFast=iMA(NULL,0,EMAFast,0,MODE_EMA,PRICE_CLOSE,0);
   double emaSlow=iMA(NULL,0,EMASlow,0,MODE_EMA,PRICE_CLOSE,0);

   string trend;
   color trendColor;

   if(emaFast>emaSlow)
   {
      trend="UP TREND";
      trendColor=clrDarkGreen;
   }
   else
   {
      trend="DOWN TREND";
      trendColor=clrRed;
   }

   string orderStatus = "NO ORDER";
   if(OrderOpened)
   {
      if(TradeDirection == 1)
         orderStatus = "BUY OPEN #"+IntegerToString(OrderTicket);
      else if(TradeDirection == -1)
         orderStatus = "SELL OPEN #"+IntegerToString(OrderTicket);
   }

   string txt=
      "=== MACD Fractal Trader ===\n"+
      "TREND: "+trend+
      "\nEMA50: "+DoubleToString(emaFast,2)+
      "\nEMA200: "+DoubleToString(emaSlow,2)+
      "\n"+
      "Status: "+orderStatus+
      "\nLot: "+DoubleToString(LotSize,2);

   ObjectSetString(0,"TrendPanel",OBJPROP_TEXT,txt);
   ObjectSetInteger(0,"TrendPanel",OBJPROP_COLOR,trendColor);
   ObjectSetInteger(0,"TrendPanel",OBJPROP_FONTSIZE,11);
}
//+------------------------------------------------------------------+
