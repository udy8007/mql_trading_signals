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

MqlCandle lastCandle1m;

 

 

  

//+------------------------------------------------------------------+

//| variables needed                                   |

//+------------------------------------------------------------------+





int noOfTradePeriods = 8;





input int shortPeriod = 50;

input int longPeriod = 200;



double averageSize = 300;

 bool allowMovingStop = false;

bool allowSoftwareTrail = false;

input double percentFromCapital = 0.01;

double minLossValue = 5;

input bool isTakeProfit = true;

bool gradStop = false;

input double maxPercent = 0;

input double minPercent = 0;

int startHour = -1;

int endHour = -1;



int periodsToCheck = 5;

input double riskToProfit = 1.0/10.0;//1.0/5.0;









 bool tradeUp = true;

 bool tradeDown = true;

 double customStartBalance = 0;













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



double calculateVolume(int pos)

{



   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   double lotSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE);

   //double bidAbeea = MarketInfo(_Symbol,MODE_BID);

   //double askAshtry = MarketInfo(_Symbol,MODE_ASK);

    double askAshtry = getPriceAtPosition(pos);

   

   double minBuyMoney = askAshtry * 0.01 * lotSize ;

   double oneValue = minBuyMoney/minLossValue;

   double lossValue = percentFromCapital * balance;

   if(lossValue < minLossValue)

   {

      lossValue = minLossValue;

      

   }

   

   double calcVol = 0;

   double volume = 0;

   

   while((calcVol / oneValue) <= lossValue)

   {

      volume = volume + 0.01;

      calcVol = volume * lotSize;

      calcVol = calcVol * askAshtry;

   } 

   

   if(volume > 0.01)

   {

      volume = volume - 0.01;

   }

   

   return volume;

   

  

   

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

    

    double volume = calculateVolume(1);

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







double shohdiSma (int pos,int periodType,int periods,SmaCalcType type)

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

            CopyClose(_Symbol,periodType,pos,periods,vals);

            

       }

       else if(type == 1)

       {

         CopyHigh(_Symbol,periodType,pos,periods,vals);

       }

       else if (type == 2)

       {

         CopyLow(_Symbol,periodType,pos,periods,vals);

       }

       else

       {

            

             CopyHigh(_Symbol,periodType,pos,periods,high);

              CopyLow(_Symbol,periodType,pos,periods,low);

             

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





double movingAverage (int pos,int _per,int periods)

{

       

     

       double vals[];

      

       

       ArrayResize(vals,periods);

 

      

      

            CopyClose(_Symbol,_per,pos,periods,vals);

            

           

       

       double sum = 0;

       for (int j=0;j<periods;j++)

       {

              sum = sum + vals[j];      

       }

       

       

       double result = sum / ((double)periods);

       

      

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



double shortSmas[];

double longSmas[];


double candleBody(MqlCandle &candle)
{
   return candle.Close1 - candle.Open1;
}


double shohdiSignalDetect (int pos)

{

     int orderNums = getOpenedOrderNo();

      if(reachMaximum())

      {

         

         return 0.0;

      }

      

      if(!calcTime())

      {

         

         return 0;

      }
      if(orderNums > 0)
      {
         //Print("found open orders ",orderNums);
         return 0;
      }

      
      MqlCandle current = getCandle(1,PERIOD_M1);
      MqlCandle back = getCandle(2,PERIOD_M1);
      MqlCandle beforeBack = getCandle(3,PERIOD_M1);
      
      if(current.High1 > back.High1 
      && back.High1 > beforeBack.High1
      && current.Low1 > back.Low1
      && back.Low1 > beforeBack.Low1
      && current.Close1 > back.Close1
      && back.Close1 > beforeBack.Close1)
      {
         return -1;
      }
      
      if(current.High1 < back.High1 
      && back.High1 < beforeBack.High1
      && current.Low1 < back.Low1
      && back.Low1 < beforeBack.Low1
      && current.Close1 < back.Close1
      && back.Close1 < beforeBack.Close1)
      {
         return 1;
      }
      
      
      return 0;
     

      int myPos = pos ;

      int myOldPos = myPos + 1;

      

      double lastShortSma = shohdiSma(myPos,PERIOD_M1,shortPeriod,0);

      double lastLongSma = shohdiSma(myPos,PERIOD_M1,longPeriod,0);

      double beforeLastShortSma = shohdiSma(myOldPos,PERIOD_M1,shortPeriod,0);

      double beforeLastLongSma = shohdiSma(myOldPos,PERIOD_M1,longPeriod,0);

      double zeroShort = shohdiSma(0,PERIOD_M1,shortPeriod,0);

      double zeroLong = shohdiSma(0,PERIOD_M1,longPeriod,0);

      

      MqlCandle newCandle =  getCandle(myPos);

      MqlCandle oldCandle = getCandle(myPos+ longPeriod);

      

      /*

      int mySmaSize = ArraySize(shortSmas);

     

         //add last found

         ArrayResize(shortSmas,mySmaSize+1);

         ArrayResize(longSmas,mySmaSize+1);

      

      shortSmas[mySmaSize] = lastShortSma;

      longSmas[mySmaSize] = lastLongSma;

      if(mySmaSize < 3)

      {

         return 0;

      }

      

      int orderNums = getOpenedOrderNo();

      if(orderNums > 0)

      {

         if(OrderSelect(lastTicket, SELECT_BY_TICKET)==true)

            {

               orderNums = 1;

               //Print("order found with profit ",OrderProfit());

            }

            else

            {

               orderNums = 0;

               Print("1 order from outside , no order from here ");

            }

      }

     

      

      

      if(orderNums == 0)

      {

         if(shortSmas[mySmaSize] < longSmas[mySmaSize]  && shortSmas[mySmaSize-2] > longSmas[mySmaSize-2]  && tradeDown )

         {

            return -1;

            

         }

         else if  (shortSmas[mySmaSize] > longSmas[mySmaSize]  && shortSmas[mySmaSize-2] < longSmas[mySmaSize-2] && tradeUp  )

         {

            return 1;

         }

         else

         {

            return 0;

         }

      }

      else

      {

         if(lastDir == 1)

         {

            if(shortSmas[mySmaSize] < longSmas[mySmaSize])

            {

               //signal to close

               double closeRes = OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),5,clrNONE);

            }

         }

         else if(lastDir == -1)

         {

            if(shortSmas[mySmaSize] >  longSmas[mySmaSize])

            {

               //signal to close

               double closeRes1 = OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),5,clrNONE);

            }

         }

      }

      

      

         return 0; 

      */

       

      if(orderNums > 0)

      {

         if(OrderSelect(lastTicket, SELECT_BY_TICKET)==true)

            {

               orderNums = 1;

               //Print("order found with profit ",OrderProfit());

            }

            else

            {

               orderNums = 0;

               Print("1 order from outside , no order from here ");

            }

      }

     

      

      

      if(orderNums == 0)

      {

         if(lastShortSma < lastLongSma  && beforeLastShortSma > beforeLastLongSma  && tradeDown )

         {

            return -1;

            

         }

         else if  (lastShortSma > lastLongSma  && beforeLastShortSma < beforeLastLongSma && tradeUp  )

         {

           return 1;

         }

         else

         {

            return 0;

         }

      }

      else

      {

         return 0;

         if(lastDir == 1)

         {

            

            if(lastShortSma < lastLongSma)

            {

               //signal to close

               Print("close due to down move " ,  OrderProfit());

               //double closeRes = OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),5,clrNONE);

            }

         }

         else if(lastDir == -1)

         {

            if(lastShortSma > lastLongSma)

            {

               //signal to close

               Print("close due to up move " ,  OrderProfit());

               //double closeRes1 = OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),5,clrNONE);

            }

         }

         /*

         if(lastDir == 1)

         {

            

            if(zeroShort < zeroLong)

            {

               //signal to close

               Print("close due to down move " ,  OrderProfit());

               double closeRes = OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),5,clrNONE);

            }

         }

         else if(lastDir == -1)

         {

            if(zeroShort > zeroLong)

            {

               //signal to close

               Print("close due to up move " ,  OrderProfit());

               double closeRes1 = OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),5,clrNONE);

            }

         }

         */

      }

      

      

         return 0; 

    

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



double getPriceAtPosition(int pos)

{

   double closes1[];

   

   ArrayResize(closes1,1);

   CopyClose(_Symbol,_Period,pos,1,closes1);

   return closes1[0];

}



double calcOfLossValue(double lossValue,int pos)

{

   

   double lotSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE);

   //double bidAbeea = MarketInfo(_Symbol,MODE_BID);

   //double askAshtry = MarketInfo(_Symbol,MODE_ASK);

   double askAshtry = getPriceAtPosition(pos);

   

   

   

   

   double volume = calculateVolume(pos);

   double averageMove = lossValue/(volume * lotSize*askAshtry);

   

   return averageMove;

}



double calculateMoveOfStopLoss(int pos)

{

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   double lossValue = percentFromCapital * balance;

   if(lossValue < minLossValue)

   {

      lossValue = minLossValue;

      

   }

   double averageMove = calcOfLossValue(lossValue,pos);

   

   

   return averageMove * riskToProfit; 

   

   

   

  

  

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

      lastCandle1m.Close1 = -1; 

      

      

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

   double lotSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE);

   printf("lot size : %G" ,lotSize );

   double pointSize = MarketInfo(_Symbol,MODE_POINT);

   double spreadSize = MarketInfo(_Symbol,MODE_SPREAD);

   double bid = MarketInfo(_Symbol,MODE_BID);

   double ask = MarketInfo(_Symbol,MODE_ASK);

   printf("point size : %G" , pointSize );

   printf("spread : %G " , spreadSize);

   printf("spread price : %G",spreadSize * pointSize);

   printf("bid : %G",bid);

   printf("ask : %G",ask);

   

 

   double volume = calculateVolume(0);

   double averageMove = calculateMoveOfStopLoss(0)/riskToProfit;

   double loss = averageMove * volume * lotSize * ask;

   printf("volume to trade : %G , averageMove : %G , lossValue : %G",volume,averageMove,loss);

      

      

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

      noOfSuccess = 0;

      noOfFail = 0;

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

         MqlCandle currentCandle1m = getCandle(0,PERIOD_M1);

         

        

         

         

         

         if(lastCandle1m.Close1 == -1)

         {

            Print("first candle ");

            lastCandle = currentCandle;

            lastCandle1m = currentCandle1m;

            return;

         }

         

        

         if(currentCandle1m.Date != lastCandle1m.Date)

         {

            

            //one minute candle change

            

            int tradeType = shohdiSignalDetect(1);

            if(tradeType != 0 )

            {

               

              

                  
                  
                  double valSpread = getSpread();
                  double percent = percentFromCapital * 100;
                  if(percent < 1)
                  {
                     percent = 1.0;
                  }
                  
                  minLossValue = (valSpread * 2 * (1/riskToProfit)) * percent * 1000;
                  
                  Print("0 orders open , starting new order in dir : ",tradeType," min loss : ",minLossValue);
                  openTrade(tradeType);

              

               

            }

            

         }

         

         if(currentCandle.Date != lastCandle.Date)

         {

         

         

            

            

           

            

            

           

           

          

            

         }

         

         

          lastCandle = currentCandle;

          lastCandle1m = currentCandle1m;

          

          

         

            

        

        //reCalcStopLoss();

         

  }

  

  



  

  

   double getSpread()

  {

   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);

   double spread = ask - bid;

   return spread;

  }

  

  

  

  

  int getSpreadDips()

  {

       int spreadDips = SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);

       return spreadDips;

  }

  

  

  double getDipPrice()

  {

      return getSpread()/getSpreadDips();

  }

  

  

  

  

  

  

 

  

//+------------------------------------------------------------------+

//| Timer function                                                   |

//+------------------------------------------------------------------+

void OnTimer()

  {



   

          

          

   

  }

  

  



  

//+------------------------------------------------------------------+



