//+------------------------------------------------------------------+
//|                                                  TradeByTick.mq5 |
//|                        Copyright 2017, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, shohdy elshemy"
#property link      ""
#property version   "1.00"






//+------------------------------------------------------------------+
//| My custom types                                   |
//+------------------------------------------------------------------+

#define EXPERT_MAGIC 123456   // MagicNumber of the expert

enum SmaCalcType
{
   Close1 = 0
   ,High1 = 1
   ,Low1 = 2
   ,Mid = 3
};


struct MqlCandle
 {
   double Close1;
   double Open1;
    int Dir;
   double High1;
    double Low1;
    double Volume1;
    datetime Date;
 };
 

 
MqlTick currentTick;
MqlTick lastTick;
MqlCandle lastCandle;
 
 
  
//+------------------------------------------------------------------+
//| variables needed                                   |
//+------------------------------------------------------------------+


input int noOfTradePeriods = 8;


input int shortPeriod = 14;
input int longPeriod = 28;

input double averageSize = 300;
input bool allowMovingStop = false;
input bool allowSoftwareTrail = false;
input double percentFromCapital = 0.05;
input double minLossValue = 5;
input bool isTakeProfit = true;
input double maxPercent = 0;
input double minPercent = 0;
input int startHour = -1;
input int endHour = -1;

input int periodsToCheck = 5;
input double riskToProfit = 2.2;



input bool tradeUp = true;
input bool tradeDown = true;
input double customStartBalance = 0;






double startBalance = 0;







int noOfSuccess = 0;
int noOfFail = 0;



MqlCandle lastMonth;


int lastTicket = 0;
int lastDir = 0;
double lastStopLoss = 0;
double lastAverageMove = 0;



//+------------------------------------------------------------------+
//| My custom functions                                   |
//+------------------------------------------------------------------+


void reCalcStopLoss()
{
   int count = getOpenedOrderNo();
   if(count == 1 && allowMovingStop)
   {
      if(OrderSelect(lastTicket,SELECT_BY_TICKET) == true)
      {
      
         if(lastStopLoss == 0)
         {
            lastStopLoss = OrderStopLoss();
         }
      
       double vbid    = MarketInfo(_Symbol,MODE_BID);
      double vask    = MarketInfo(_Symbol,MODE_ASK);
      double close = 0;
      double newStopLoss;
      bool changeFound = false;
      color arrowColor;
      
      int setType = 0;
      if (lastDir == 1)
      {
         setType = OP_BUY;
         close = vask;
         arrowColor = clrGreen;
         newStopLoss = close - lastAverageMove;
         if(newStopLoss > lastStopLoss)
         {
            //found change
            changeFound = true;
         }
      }
      else if(lastDir == -1)
      {
         setType = OP_SELL;
         close = vbid;
         arrowColor = clrRed;
         newStopLoss = close + lastAverageMove;
          if(newStopLoss < lastStopLoss)
         {
            //found change
            changeFound = true;
         }
         
      }
      else
      {
         return;
      }
      
      if(changeFound)
      {
         if(!allowSoftwareTrail)
         {
            OrderSelect(lastTicket,SELECT_BY_TICKET);
            bool res=OrderModify(OrderTicket(),OrderOpenPrice(),newStopLoss,OrderTakeProfit(),0,arrowColor);
          
               if(!res)
                  Print("Error in OrderModify. Error code=",GetLastError());
               else
                  lastStopLoss = newStopLoss;
         }
         else
         {
            lastStopLoss = newStopLoss;
         }
      }
      else
      {
         if(allowSoftwareTrail)
         {
            bool foundClose = false;
           
            if(lastDir == 1)
            {
               if(close < lastStopLoss)
               {
                  foundClose = true;
                  
                  
               }
            }
            else if(lastDir == -1)
            {
               if(close > lastStopLoss)
               {
                  foundClose = true;
               }
            }
           
            
            if(foundClose)
            {
                OrderSelect(lastTicket,SELECT_BY_TICKET);
                  bool closeRes = OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),5,clrNONE);
                  if(!closeRes)
                  {
                     Print("Error in OrderClose. Error code=",GetLastError());
                  }
            }
            
         }
         
      }
    }
   }
   else
   {
      lastStopLoss = 0;
   }
}


bool calcTime()
{
   if(startHour == -1 || endHour == -1)
   {
      return true;
   }
    datetime currentDate = TimeCurrent();
        
          MqlDateTime strucTime;
          TimeToStruct(currentDate,strucTime);
          //Print("time now ",strucTime.hour);
          for (int i=startHour;i != (endHour+1);i=((i+1)%24))
          {
            //Print("i is : ",i,"structTime.hour is ",strucTime.hour);
            if(strucTime.hour == i)
            {
               
               return true;
            }
          }
          
          //bool ret =  (strucTime.hour >= startHour && strucTime.hour <= endHour);
    
    //return ret;
    return false;
}

double maxMinMoney = 0;

double calculateVolume(double stopLoss,double balance,double close,double &newMove)
{
   double diff = 0;
   diff = stopLoss - close;
   if(diff < 0)
   {
      diff = diff * -1;
      
   }
   
   newMove = diff;
   
   double moneyToLoss = balance * percentFromCapital;
   if(moneyToLoss < minLossValue)
   {
      moneyToLoss = minLossValue;
   }
   
   double lotSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE);
   
   bool foundVolume = false;
   double volumeFound = 0;
   double rate = calcUsdRate(close);
   while(! foundVolume)
   {
      volumeFound = volumeFound + 0.01;
      double volumeCount = lotSize * volumeFound ;
      double allDiff =  volumeCount * diff ;
      
      double lossPrice = allDiff * rate;
      
      if(volumeFound == 0.01)
      {
         if(lossPrice > maxMinMoney)
         {
            maxMinMoney = lossPrice;
         }
      }
      
      if(lossPrice > moneyToLoss)
      {
         foundVolume = true;
         if(volumeFound > 0.01)
         {
            volumeFound = volumeFound - 0.01;
         }
         
         volumeCount = lotSize * volumeFound ;
         allDiff =  volumeCount * diff ;
      
         lossPrice = allDiff * rate;
         
         if(lossPrice > moneyToLoss)
         {
           
            newMove = ((moneyToLoss * diff)/lossPrice);
            Print("found new average! old ",diff," new " , newMove);
         }
         
          
      }  
   }
   
   
   
   return volumeFound;
   
}

double calcUsdRate(double close)
{
   string sym = _Symbol;
   int len = StringLen(sym);
   string to = StringSubstr(sym,len-3,3);
   string from = StringSubstr(sym,0,3);
   StringToUpper(to);
   StringToUpper(from);
   if(to == "USD")
   {
      return 1.0;
   }
   else if(from == "USD")
   {
      return (1/close);
   }
   else
   {
      string newSym =  to + "USD";
      double closes[1];
      int newPos = 0;
      CopyClose(newSym,PERIOD_D1,newPos,1,closes);
      double ret = closes[0];
      while (ret <= 0)
      {
         newPos++;
         CopyClose(newSym,PERIOD_D1,newPos,1,closes);
         ret = closes[0];
      }
      return ret;
   }
}

bool openTrade (int type)
{
   Print("Start order ");
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   Print("Account balance = ",balance);
   
      double vbid    = MarketInfo(_Symbol,MODE_BID);
   double vask    = MarketInfo(_Symbol,MODE_ASK);
   double close = 0;
   string title = "";
   color arrowColor;
   
   int setType = 0;
   if (type == 1)
   {
      setType = OP_BUY;
      close = vask;
      title = "Buy order";
      arrowColor = clrGreen;
   }
   else if(type == -1)
   {
      setType = OP_SELL;
      close = vbid;
      title = "Sell order";
      arrowColor = clrRed;
   }
   else
   {
      return false;
   }
   
    double averageMove = calculateMoveOfStopLoss(1) / riskToProfit;
    //averageMove = fixAverageMove(1,averageMove);
    //MqlCandle last = getCandle(1);
    double stopLoss = 0;
    double takeProfit = 0;
    if(type == 1)
    {
      stopLoss = close - averageMove;
      takeProfit = close + (averageMove * riskToProfit);
    }
    else if (type == -1)
    {
      stopLoss = close + averageMove;
      takeProfit = close - (averageMove * riskToProfit);
    }
    double newAverageMove = 0;
    double volume = calculateVolume(stopLoss,balance,close,newAverageMove);
    /*
    if( newAverageMove < averageMove)
    {
         averageMove = newAverageMove;
          if(type == 1)
          {
            stopLoss = close - averageMove;
            takeProfit = close + (averageMove * riskToProfit);
          }
          else if (type == -1)
          {
            stopLoss = close + averageMove;
            takeProfit = close - (averageMove * riskToProfit);
          }
    }
    */
    
   
   //MqlTradeRequest request={0};
   //MqlTradeResult  result={0};
   //request.action   =TRADE_ACTION_DEAL;                     // type of trade operation
   //request.symbol   =Symbol();                              // symbol
   //request.volume   =volume;                                   // volume of 0.1 lot
   //request.type     =setType;                        // order type
   //request.price    =SymbolInfoDouble(Symbol(),SYMBOL_ASK); // price for opening
   //request.deviation=5;                                     // allowed deviation from the price
   //request.magic    =EXPERT_MAGIC;
   //request.sl = stopLoss;
   //request.tp = takeProfit;
  
                             // MagicNumber of the order
//--- send the request
   //return OrderSend(request,result);
   
   if(!isTakeProfit)
   {
      takeProfit = 0;
   }
   
   int ticket=OrderSend(Symbol(),setType,volume,close,5,stopLoss,takeProfit,title,EXPERT_MAGIC,0,arrowColor);
   
    if(ticket>=0)
     {
         //order my be successed
         
         if(OrderSelect(ticket, SELECT_BY_TICKET)==true)
         {
            lastTicket = ticket;
            lastDir = type;
            
            lastAverageMove = averageMove;
            return true;
         }
     }
     
     
     return false;
   
}


double fixAverageMove(int pos,double foundMove)
{
   double highs[];
   double lows[];
    ArrayResize(highs,noOfTradePeriods);
   ArrayResize(lows,noOfTradePeriods);
   
   CopyHigh(_Symbol,_Period,pos,noOfTradePeriods,highs);
   CopyLow(_Symbol,_Period,pos,noOfTradePeriods,lows);
   
   double maxMove = 0.0;
   for (int i=0;i<noOfTradePeriods;i++)
   {
      double diff = highs[i] - lows[i];
      if(diff > maxMove)
      {
         maxMove = diff;
      }
   }
   
   if (maxMove > (foundMove))
   {
      foundMove = maxMove;
   }
   
   return foundMove;
}

MqlCandle getCandle (int pos,int period)
 {
      MqlCandle ret;
      
      double closes[1];
      double opens[1];
      double highs[1];
      double lows[1];
      long volumes[1];
       datetime dates[1];
      CopyClose(_Symbol,period,pos,1,closes);
       CopyOpen(_Symbol,period,pos,1,opens);
      CopyHigh(_Symbol,period,pos,1,highs);
      CopyLow(_Symbol,period,pos,1,lows);
      CopyTime(_Symbol,period,pos,1,dates);
      ret.Volume1 = 1;
      int volFound = CopyRealVolume(_Symbol,period,pos,1,volumes);
      if(volFound <= 0)
      {
        volFound =  CopyTickVolume(_Symbol,period,pos,1,volumes);
      
      }
      
      
       if(volumes[0] > 0)
         {
               ret.Volume1 = volumes[0];
         }
      
      ret.Date = dates[0];
      ret.Close1 = closes[0];
      ret.Open1 = opens[0];
      ret.High1 = highs[0];
      ret.Low1 = lows[0];
      if(ret.Open1 < ret.Close1)
         ret.Dir = 1;
     else if (ret.Open1 > ret.Close1)
         ret.Dir = -1;
     else
         ret.Dir = 0;
         
         
         return ret;
         
            
 }
 
 MqlCandle getCandle(int pos)
 {
   return getCandle(pos,_Period);
 }
 
 
 

 


double compareCandles (MqlCandle &old,MqlCandle &newC)
{
      if (newC.High1 > old.High1
      && newC.Close1 > old.Close1
      && newC.Low1 > old.Low1)
      {
         return 1;
      }
      else if (newC.High1 < old.High1
      && newC.Close1 < old.Close1
      && newC.Low1 < old.Low1)
      {
         return -1;
      }
      else
      {
         return 0;
      }
      
}


double getDirectionOfNoOfPeriods (int pos,int noOfPeriods)
{
      MqlCandle lastCandle = getCandle(pos);
      MqlCandle startCandle = getCandle(pos+(noOfPeriods));
      if(startCandle.Close1 > lastCandle.Close1)
      {
         return -1;
      }
      else if (startCandle.Close1 < lastCandle.Close1)
      {
         return 1;
      }
      else
      {
         return 0;
      }
}






double shohdiSma (int pos,int periods,SmaCalcType type)
{
       
     string arrayPrint = " Priods : " + periods;
       double vals[];
       double high[];
       double low[];
       
       ArrayResize(vals,periods);
 ArrayResize(high,periods);
  ArrayResize(low,periods);
      
       if(type == 0)
       {
            CopyClose(_Symbol,_Period,pos,periods,vals);
            
       }
       else if(type == 1)
       {
         CopyHigh(_Symbol,_Period,pos,periods,vals);
       }
       else if (type == 2)
       {
         CopyLow(_Symbol,_Period,pos,periods,vals);
       }
       else
       {
            
             CopyHigh(_Symbol,_Period,pos,periods,high);
              CopyLow(_Symbol,_Period,pos,periods,low);
             
              for (int i=0;i<periods;i++)
              {
                  
                  vals[i] = (high[i] + low[i])/2;
                  arrayPrint = arrayPrint + " index : "+i +  " high : " + high[i] + " low : " + low[i] + " mid : " + vals[i] ;
              }
              
              
              
              
       }
       
       
       double sum = 0;
       for (int j=0;j<periods;j++)
       {
              sum = sum + vals[j];      
       }
       
       
       double result = sum / ((double)periods);
       arrayPrint =arrayPrint + " sum : " + sum + " result : " + result;
       //Print (arrayPrint);
      
       return result;
}







string printDir (double value)
{
      if(value == 0)
         return "equal";
     
     if(value > 0)
         return "green";
         
      if(value < 0)
            return "red";
            
            
            return "equal";
}


bool reachMaximum()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    if(startBalance == 0)
      {
         
         startBalance = balance;
         //lastMonth = getCandle(1,PERIOD_MN1);
         
      }
      else
      {
         if(maxPercent == 0 && minPercent == 0)
         {
            return false;
         }
         
         if(maxPercent > 0 && ((balance/startBalance) >= (1+maxPercent)))
         {
            Print("success to reach takeprofit!");
            return true;
         }
         
         if(minPercent > 0 && ((balance/startBalance) <= (1-minPercent)))
         {
            Print("fail reach stop loss!");
            return true;
         }
         
         
      }
      
      /*
      else
      {
         //check month is same
         MqlCandle month = getCandle(1,PERIOD_MN1);
         double balance = AccountInfoDouble(ACCOUNT_BALANCE);
         if(month.Date != lastMonth.Date)
         {
            startBalance = balance;
            lastMonth = month;
         }
         else
         {
            //check balance
            if((balance/startBalance) >= (1+maxPercent))
            {
               return true;
            }
         }
         
      }
      */
      return false;
}


double shohdiSignalDetect (int pos)
{
     
      if(reachMaximum())
      {
         
         return 0.0;
      }
      
      if(!calcTime())
      {
         
         return 0;
      }
     
      int myPos = pos ;
      int beforePos = myPos + 1;
      double lastShortSma = shohdiSma(myPos,shortPeriod,0);
      double lastLongSma = shohdiSma(myPos,longPeriod,0);
      double beforeShortSma = shohdiSma(beforePos,shortPeriod,0);
      double beforeLongSma = shohdiSma(beforePos,longPeriod,0); 
      MqlCandle lastCandle = getCandle(pos);
      MqlCandle historyCandle = getCandle(pos + (noOfTradePeriods * shortPeriod  ));
      int candleDir = 0;
      if(historyCandle.Close1 > lastCandle.Close1)
      {
         candleDir = -1;
      }
      else if (historyCandle.Close1 < lastCandle.Close1)
      {
         candleDir = 1;
      }
      else
      {
         candleDir = 0;
      }
      
      
      //MqlCandle candleOld1 = getCandle(longPeriod);
      //MqlCandle candleOld2 = getCandle(longPeriod+1);
      //MqlCandle candleNew1 = getCandle(1);
      //MqlCandle candleNew2 = getCandle(2);
      
      //int quantumDir = 0;
      //double diff1 = candleNew1.Close1 - candleOld1.Close1;
      //double diff2 = candleNew2.Close1 - candleOld2.Close1;
      //if(diff1 < 0 && diff1 < diff2)
      //{
      //   quantumDir = -1;
      //}
      
      //if(diff1 > 0 && diff1 > diff2)
      //{
      //   quantumDir = 1;
      //}
      
      
      if(lastShortSma < lastLongSma  && beforeShortSma > beforeLongSma &&  candleDir == -1 && tradeDown )
      {
         return -1;
         
      }
      else if  (lastShortSma > lastLongSma  && beforeShortSma < beforeLongSma && candleDir == 1 && tradeUp  )
      {
         return 1;
      }
      else
      {
         return 0;
      }
          
      
       
    
}


void shohdiCalculateSuccessFail ()
{
        double signal = shohdiSignalDetect(1 + (noOfTradePeriods * periodsToCheck));
        double averageMove = calculateMoveOfStopLoss(1 + (noOfTradePeriods * periodsToCheck)) / riskToProfit;
         //averageMove = fixAverageMove(1 + (noOfTradePeriods * periodsToCheck),averageMove);
        int lastPos = 1 + (noOfTradePeriods * periodsToCheck);
        
        if(signal >0)
        {
            //up
            //Print("found up");
            calculateSuccessFailUp(signal,averageMove,lastPos);
            
            
        }
        else if(signal < 0)
        {
            //down
            //Print("found down");
            calculateSuccessFailDown(signal,averageMove,lastPos);
        }
        else
        {
        }
        
        
               
}


void calculateSuccessFailUp(double signal,double averageMove,int lastPos)
{
   MqlCandle lastCandle = getCandle(lastPos);
   double stopLoss = lastCandle.Close1 - averageMove;
   double takeProfit = lastCandle.Close1 + (averageMove * riskToProfit);
   double highs[];
   double lows[];
   int countToCheck = lastPos-1;
   ArrayResize(highs,countToCheck);
   ArrayResize(lows,countToCheck);
   
   CopyHigh(_Symbol,_Period,1,countToCheck,highs);
   CopyLow(_Symbol,_Period,1,countToCheck,lows);
   
   bool foundResult = false;
   for (int i=0;i<countToCheck;i++)
   {
      if(!foundResult)
      {
         if(lows[i] <= stopLoss)
         {
            //fail
            noOfFail++;
            foundResult = true;
         }
         else if(highs[i] >= takeProfit)
         {
            //success
            noOfSuccess++;
            foundResult = true;
         }
      }
      
   }
   
   
   
   if(!foundResult)
      noOfFail++;
   
   
   
   
   
}

void calculateSuccessFailDown(double signal,double averageMove,int lastPos)
{

    MqlCandle lastCandle = getCandle(lastPos);
   double stopLoss = lastCandle.Close1 + averageMove;
   double takeProfit = lastCandle.Close1 - (averageMove * riskToProfit);
   double highs[];
   double lows[];
   int countToCheck = lastPos-1;
   ArrayResize(highs,countToCheck);
   ArrayResize(lows,countToCheck);
   
   CopyHigh(_Symbol,_Period,1,countToCheck,highs);
   CopyLow(_Symbol,_Period,1,countToCheck,lows);
   
   bool foundResult = false;
   for (int i=0;i<countToCheck;i++)
   {
      if(!foundResult)
      {
         if(highs[i] >= stopLoss)
         {
            //fail
            noOfFail++;
            foundResult = true;
         }
         else if(lows[i] <= takeProfit)
         {
            //success
            noOfSuccess++;
            foundResult = true;
         }
      }
      
   }
   
   if(!foundResult)
      noOfFail++;

}

double calculateMoveOfStopLoss(int pos)
{
  double highs[];
  double lows[];
  
  ArrayResize(highs,averageSize);
  ArrayResize(lows,averageSize);
  
  int bars = noOfTradePeriods - 1;

   CopyHigh(_Symbol,_Period,pos,averageSize,highs);
   CopyLow(_Symbol,_Period,pos,averageSize,lows);
   
   double average = 0;
   int count = 0;
   double maxMove = 0;
   for (int i=0;(i+bars) < averageSize;i++)
   {
      double allHigh = 0;
      double allLow = 999999999;
      for (int j=0;j<noOfTradePeriods;j++)
      {
         int index = i+j;
         if(allHigh < highs[index])
            allHigh = highs[index];
         
         if(allLow > lows[index])
            allLow = lows[index];
         
      }
      
      double moveMent = allHigh - allLow;
      
      if(moveMent > maxMove)
      {
         maxMove = moveMent;
      }
      
      average = average + moveMent;
      
      count = count + 1;
      
   }
   
   average = average / count;
   
   average = average - (average * 0.25);
   
   average = average * riskToProfit;
   //average = maxMove * maxMovePercent;
   
   return average;
  
}



int getOpenedOrderNo()
{
   int total1=0;//PositionsTotal();
   int total2=OrdersTotal();
   
   
    //Print("Pending orders number ",total2," opened orders number ",total1);
   return total1 + total2 ;
   
}


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   EventSetTimer(1);
      lastTick.ask = -1 ;
      lastTick.bid = -1;
      currentTick.ask = -1;
      currentTick.bid = -1;
      lastCandle.Close1 = -1;
      
      
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(customStartBalance <= 0)
      {
         startBalance = balance;
      }
      else
      {
         startBalance = customStartBalance;
      }
      
      
      //--- show all the information available from the function AccountInfoDouble()
   printf("ACCOUNT_BALANCE =  %G",AccountInfoDouble(ACCOUNT_BALANCE));
   printf("ACCOUNT_CREDIT =  %G",AccountInfoDouble(ACCOUNT_CREDIT));
   printf("ACCOUNT_PROFIT =  %G",AccountInfoDouble(ACCOUNT_PROFIT));
   printf("ACCOUNT_EQUITY =  %G",AccountInfoDouble(ACCOUNT_EQUITY));
   printf("ACCOUNT_MARGIN =  %G",AccountInfoDouble(ACCOUNT_MARGIN));
   printf("ACCOUNT_MARGIN_FREE =  %G",AccountInfoDouble(ACCOUNT_FREEMARGIN));
   printf("ACCOUNT_MARGIN_LEVEL =  %G",AccountInfoDouble(ACCOUNT_MARGIN_LEVEL));
   printf("ACCOUNT_MARGIN_SO_CALL = %G",AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL));
   printf("ACCOUNT_MARGIN_SO_SO = %G",AccountInfoDouble(ACCOUNT_MARGIN_SO_SO));
   printf("ACCOUNT_LEVERAGE = %G",AccountInfoInteger(ACCOUNT_LEVERAGE));
   printf("lot size : %G" , SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE));
      
      
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
      Print("Min value to loss every trade : ",maxMinMoney);
      calcSuccessToFailOrders();
       Print("no of success : " + noOfSuccess + " , no of fail : " + noOfFail);
        double totalVal = noOfSuccess + noOfFail;
        if(totalVal > 0)
        {
            Print("Percentage : " + ((noOfSuccess/totalVal)* 100));
            
        }
   
//--- destroy timer
   EventKillTimer();
      
  }
  
  void calcSuccessToFailOrders()
  {
      int hstTotal = OrdersHistoryTotal();
      for(int i=0; i < hstTotal; i++)           
       {
            if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))
            {
               if(OrderMagicNumber() == EXPERT_MAGIC)
               {
                  if( OrderProfit() > 0)
                   {
                     noOfSuccess++;
                   }
                   else if (OrderProfit() < 0)
                   {
                     noOfFail++;
                   }
               }
                
             }
             
        }
                  
            
  }
 
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- 
        // SymbolInfoTick(_Symbol,currentTick);
         
         //Print("new Tick" + currentTick.time);
         MqlCandle currentCandle = getCandle(0);
         
         
         if(lastCandle.Close1 == -1)
         {
            lastCandle = currentCandle;
            return;
         }
         
         if(currentCandle.Date != lastCandle.Date)
         {
            //new candle , do work here
           
           
            //shohdiCalculateSuccessFail();
            
            
            int tradeType = shohdiSignalDetect(1);
            if(tradeType != 0 )
            {
               int orderNums = getOpenedOrderNo();
               Print("found signal : current order number " ,orderNums );
               if(orderNums == 0)
               {
                  Print("0 orders open , starting new order in dir : ",tradeType);
                  openTrade(tradeType);
               }
               else
               {
                  Print("no trades becase there is open orders :  ",orderNums);
               }
               
            }
            
            
           
           
          
            
         }
         
         
          lastCandle = currentCandle;
        
        reCalcStopLoss();
         
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {

   
          
          
   
  }
  
  

  
//+------------------------------------------------------------------+
