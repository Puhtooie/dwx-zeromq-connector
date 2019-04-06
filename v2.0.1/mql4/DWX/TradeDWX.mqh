//+------------------------------------------------------------------+
//|                                                        Trade.mqh |
//|                        Copyright 2019, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

#include <Trade/Trade.mqh>
#include <DWX/MarketInfoMQL4.mqh>
#include <DWX/ErrorDescription.mqh>

#define OP_BUY 0           //Buy 
#define OP_SELL 1          //Sell 
#define OP_BUYLIMIT 2      //Pending order of BUY LIMIT type 
#define OP_SELLLIMIT 3     //Pending order of SELL LIMIT type 
#define OP_BUYSTOP 4       //Pending order of BUY STOP type 
#define OP_SELLSTOP 5      //Pending order of SELL STOP type
#define MODE_ASK 10
#define MODE_BID 9
#define SELECT_BY_POS 0
#define SELECT_BY_TICKET 1
#define MODE_TRADES 0
#define MODE_POINT 11
#define MODE_DIGITS 12

extern string t0 = "--- Trading Parameters ---";
extern int MagicNumber = 123456;
extern int MaximumOrders = 1;
extern double MaximumLotSize = 0.01;
extern int MaximumSlippage = 3;
extern bool DMA_MODE = true;


// OPEN NEW ORDER
int DWX_OpenOrder(string _symbol, int _type, double _lots, 
                  double _price, double _SL, double _TP,  
                  string _comment, int _magic, string &zmq_ret) 
{
   
   int ticket, error;
   
   zmq_ret += "'_action': 'EXECUTION'";
   
   if(_lots > MaximumLotSize) {
      zmq_ret += ", " + "'_response': 'LOT_SIZE_ERROR', 'response_value': 'MAX_LOT_SIZE_EXCEEDED'";
      return(-1);
   }
   
   double sl = _SL;
   double tp = _TP;
  
   // Else
   if(DMA_MODE) {
      sl = 0.0;
      tp = 0.0;
   } 
   if(_symbol == "NULL") {
      ticket = OrderSend(_symbol, _type, _lots, _price, MaximumSlippage, sl, 
      tp, _comment, _magic);
   
   } else {
      ticket = OrderSend(_symbol, _type, _lots, _price, MaximumSlippage, sl,
                         tp, _comment, _magic);
   }
   if(ticket < 0) {
      // Failure
      error = GetLastError();
      zmq_ret += ", " + "'_response': '" + IntegerToString(error) + 
      "', 'response_value': '" + ErrorDescription(error) + "'";
      
      return(-1*error);
   }

   int tmpRet = OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES);
   
   zmq_ret += ", " + "'_magic': " + IntegerToString(_magic) +
    ", '_ticket': " + IntegerToString(OrderGetInteger(ORDER_TICKET)) +
     ", '_open_time': '" + TimeToString(OrderGetInteger(ORDER_TIME_DONE),TIME_DATE|TIME_SECONDS) + 
     "', '_open_price': " + DoubleToString(OrderGetDouble(ORDER_PRICE_OPEN));

   if(DMA_MODE) {
   
      int retries = 3;
      while(true) {
         retries--;
         if(retries < 0) return(0);
         
         if((_SL == 0 && _TP == 0) || 
         (OrderGetDouble(ORDER_SL) == _SL && 
         OrderGetDouble(ORDER_TP) == _TP)) 
         {
            return(ticket);
         }

         if(DWX_IsTradeAllowed(30, zmq_ret) == 1) {
            if(DWX_SetSLTP(ticket, _SL, _TP, _magic, _type, _price, _symbol,
             retries, zmq_ret)) 
             {
               return(ticket);
            }
            if(retries == 0) {
               zmq_ret += ", '_response': 'ERROR_SETTING_SL_TP'";
               return(-11111);
            }
         }

         Sleep(MILLISECOND_TIMER);
      }

      zmq_ret += ", '_response': 'ERROR_SETTING_SL_TP'}";
      return(-1);
   }

    // Send zmq_ret to Python Client
    zmq_ret += "}";
    
   return(ticket);
}

// SET SL/TP
bool DWX_SetSLTP(int ticket, double _SL, double _TP, int _magic, int _type,
 double _price, string _symbol, int retries, string &zmq_ret) 
 {
   
   if (OrderSelect(ticket, SELECT_BY_TICKET) == true)
   {
      int dir_flag = -1;
      
      if (OrderGetInteger(ORDER_TYPE) == 0 || 
      OrderGetInteger(ORDER_TYPE) == 2 || OrderGetInteger(ORDER_TYPE) == 4)
         dir_flag = 1;

      double vpoint  = MarketInfoMQL4(OrderGetString(ORDER_SYMBOL), MODE_POINT);
      int    vdigits = (int)MarketInfoMQL4(OrderGetString(ORDER_SYMBOL), MODE_DIGITS);
      
      if(OrderModify(ticket, OrderGetDouble(ORDER_PRICE_OPEN),
       NormalizeDouble(OrderGetDouble(ORDER_PRICE_OPEN)-_SL*dir_flag*vpoint,vdigits),
       NormalizeDouble(OrderGetDouble(ORDER_PRICE_OPEN)+_TP*dir_flag*vpoint,vdigits), 0, 0)) 
       {
         zmq_ret += ", '_sl': " + DoubleToString(_SL) + 
         ", '_tp': " + DoubleToString(_TP);
         
         return(true);

      } else {
         int error = GetLastError();
         zmq_ret += ", '_response': '" + IntegerToString(error) +
          "', '_response_value': '" + ErrorDescription(error) + "', '_sl_attempted': " +
           NormalizeDouble(OrderGetDouble(ORDER_PRICE_OPEN)-_SL*dir_flag*vpoint,vdigits) + 
           ", '_tp_attempted': " + NormalizeDouble(
           OrderGetDouble(ORDER_PRICE_OPEN)+_TP*dir_flag*vpoint,vdigits);
   
         if(retries == 0) {
            RefreshRates();
            DWX_CloseAtMarket(-1, zmq_ret);
            // int lastOrderErrorCloseTime = TimeCurrent();
         }
         
         return(false);
      }
   }    
   
   // return(true);
   return(false);
}

// CLOSE AT MARKET
bool DWX_CloseAtMarket(double size, string &zmq_ret) {

   int error;

   int retries = 3;
   while(true) {
      retries--;
      if(retries < 0) return(false);

      if(DWX_IsTradeAllowed(30, zmq_ret) == 1) {
         if(DWX_ClosePartial(size, zmq_ret)) {
            // trade successfuly closed
            return(true);
         } else {
            error = GetLastError();
            zmq_ret += ", '_response': '" + IntegerToString(error) +
             "', '_response_value': '" + ErrorDescription(error) + "'";
         }
      }

   }

   return(false);
}

// CLOSE PARTIAL SIZE
bool DWX_ClosePartial(double size, string &zmq_ret, int ticket = 0) {

   RefreshRates();
   double priceCP;
   
   bool close_ret = false;
   
   if(OrderGetInteger(ORDER_TYPE) != OP_BUY && 
   OrderGetInteger(ORDER_TYPE) != OP_SELL) 
   {
     return(true);
   }

   if(OrderGetInteger(ORDER_TYPE) == OP_BUY) {
      priceCP = DWX_GetBid(OrderGetString(ORDER_SYMBOL));
   } else {
      priceCP = DWX_GetAsk(OrderGetString(ORDER_SYMBOL));
   }

   // If the function is called directly, setup init() JSON here.
   if(ticket != 0) {
      zmq_ret += "'_action': 'CLOSE', '_ticket': " +
       IntegerToString(ticket);
       
      zmq_ret += ", '_response': 'CLOSE_PARTIAL'";
   }
   
   int local_ticket = 0;
   
   if (ticket != 0)
      local_ticket = ticket;
   else
      local_ticket = OrderGetInteger(ORDER_TICKET);
   
   if(size < 0.01 || size > OrderGetDouble(ORDER_VOLUME_CURRENT)) {
      close_ret = OrderClose(local_ticket, OrderGetDouble(ORDER_VOLUME_CURRENT), priceCP, MaximumSlippage);
      zmq_ret += ", '_close_price': " + DoubleToString(priceCP) +
       ", '_close_lots': " + DoubleToString(OrderGetDouble(ORDER_VOLUME_CURRENT));
       
      return(close_ret);
   } else {
      close_ret = OrderClose(local_ticket, size, priceCP, MaximumSlippage);
      zmq_ret += ", '_close_price': " + DoubleToString(priceCP)
       + ", '_close_lots': " + DoubleToString(size);
       
      return(close_ret);
   }   
}

// CLOSE ORDER (by Magic Number)
void DWX_CloseOrder_Magic(int _magic, string &zmq_ret) {

   bool found = false;

   zmq_ret += "'_action': 'CLOSE_ALL_MAGIC'";
   zmq_ret += ", '_magic': " + IntegerToString(_magic);
   
   zmq_ret += ", '_responses': {";
   
   for(int i=OrdersTotal()-1; i >= 0; i--) {
      if (OrderSelect(i,SELECT_BY_POS)==true &&
       OrderGetInteger(ORDER_MAGIC) == _magic) 
       {
         found = true;
         
         zmq_ret += IntegerToString(OrderGetInteger(ORDER_TICKET)) +
          ": {'_symbol':'" + OrderGetString(ORDER_SYMBOL) + "'";
         
         if(OrderGetInteger(ORDER_TYPE) == OP_BUY ||
          OrderGetInteger(ORDER_TYPE) == OP_SELL) 
          {
            DWX_CloseAtMarket(-1, zmq_ret);
            zmq_ret += ", '_response': 'CLOSE_MARKET'";
            
            if (i != 0)
               zmq_ret += "}, ";
            else
               zmq_ret += "}";
               
         } else {
            zmq_ret += ", '_response': 'CLOSE_PENDING'";
            
            if (i != 0)
               zmq_ret += "}, ";
            else
               zmq_ret += "}";
               
            int tmpRet = OrderDelete(OrderGetInteger(ORDER_TICKET));
         }
      }
   }

   zmq_ret = zmq_ret + "}";
   
   if(found == false) {
      zmq_ret += ", '_response': 'NOT_FOUND'";
   }
   else {
      zmq_ret += ", '_response_value': 'SUCCESS'";
   }

}

// CLOSE ORDER (by Ticket)
void DWX_CloseOrder_Ticket(int _ticket, string &zmq_ret) {

   bool found = false;

   zmq_ret += "'_action': 'CLOSE', '_ticket': " + 
   IntegerToString(_ticket);

   for(int i=0; i<OrdersTotal(); i++) {
      if (OrderSelect(i,SELECT_BY_POS)==true && OrderGetInteger(ORDER_TICKET) == _ticket) {
         found = true;

         int orderType = OrderGetInteger(ORDER_TYPE);
         
         if(orderType == OP_BUY || OrderGetInteger(ORDER_TYPE) == OP_SELL) {
            DWX_CloseAtMarket(-1, zmq_ret);
            zmq_ret += ", '_response': 'CLOSE_MARKET'";
         } else {
            zmq_ret += ", '_response': 'CLOSE_PENDING'";
            int tmpRet = OrderDelete(OrderGetInteger(ORDER_TICKET));
         }
      }
   }

   if(found == false) {
      zmq_ret += ", '_response': 'NOT_FOUND'";
   }
   else {
      zmq_ret += ", '_response_value': 'SUCCESS'";
   }

}

// CLOSE ALL ORDERS
void DWX_CloseAllOrders(string &zmq_ret) {

   bool found = false;

   zmq_ret += "'_action': 'CLOSE_ALL'";
   
   zmq_ret += ", '_responses': {";
   
   for(int i=OrdersTotal()-1; i >= 0; i--) {
   
      if (OrderSelect(i,SELECT_BY_POS)==true) {
      
         found = true;
         
         zmq_ret += IntegerToString(OrderGetInteger(ORDER_TICKET)) +
           ": {'_symbol':'" +
           OrderGetString(ORDER_SYMBOL) + "', '_magic': " +
           IntegerToString(OrderGetInteger(ORDER_MAGIC));
         
         if( OrderGetInteger(ORDER_TYPE) == OP_BUY || 
         OrderGetInteger(ORDER_TYPE)== OP_SELL ) 
         {
            DWX_CloseAtMarket(-1, zmq_ret);
            zmq_ret += ", '_response': 'CLOSE_MARKET'";
            
            if (i != 0)
               zmq_ret += "}, ";
            else
               zmq_ret += "}";
               
         } else {
            zmq_ret += ", '_response': 'CLOSE_PENDING'";
            
            if (i != 0)
               zmq_ret += "}, ";
            else
               zmq_ret += "}";
               
            int tmpRet = OrderDelete(OrderGetInteger(ORDER_TICKET));
         }
      }
   }
   
   zmq_ret += "}";
   
   if(found == false) {
      zmq_ret += ", '_response': 'NOT_FOUND'";
   }
   else {
      zmq_ret += ", '_response_value': 'SUCCESS'";
   }

}

// GET OPEN ORDERS
void DWX_GetOpenOrders(string &zmq_ret) {

   bool found = false;

   zmq_ret += "'_action': 'OPEN_TRADES'";
   zmq_ret += ", '_trades': {";
   
   for(int i=OrdersTotal()-1; i>=0; i--) {
      found = true;
      
      if (OrderSelect(i,SELECT_BY_POS) == true) {
      
         zmq_ret += IntegerToString(PositionGetInteger(POSITION_TICKET)) + ": {";
         
         zmq_ret += "'_magic': " + IntegerToString(PositionGetInteger(POSITION_MAGIC)) +
           ", '_symbol': '" + PositionGetString(POSITION_SYMBOL) +
           "', '_lots': " + DoubleToString(PositionGetDouble(POSITION_VOLUME)) +
            ", '_type': " + IntegerToString(PositionGetInteger(POSITION_TYPE)) + 
           ", '_open_price': " + DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN)) +
           ", '_open_time': '" + TimeToString(OrderGetInteger(ORDER_TIME_DONE)
                                                     ,TIME_DATE|TIME_SECONDS) + 
           "', '_SL': " + DoubleToString(PositionGetDouble(POSITION_SL)) + 
           ", '_TP': " + DoubleToString(PositionGetDouble(POSITION_TP) + 
           ", '_pnl': " + DoubleToString(PositionGetDouble(POSITION_PROFIT)) +
            ", '_comment': '" + PositionGetString(POSITION_COMMENT) + "'";
         
         if (i != 0)
            zmq_ret += "}, ";
         else
            zmq_ret += "}";
      }
   }
   zmq_ret += "}";

}

// CHECK IF TRADE IS ALLOWED
int DWX_IsTradeAllowed(int MaxWaiting_sec, string &zmq_ret) {
    
    if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) {
    
        int StartWaitingTime = (int)GetTickCount();
        zmq_ret += ", " + "'_response': 'TRADE_CONTEXT_BUSY'";
        
        while(true) {
            
            if(IsStopped()) {
                zmq_ret += ", " + "'_response_value': 'EA_STOPPED_BY_USER'";
                return(-1);
            }
            
            int diff = (int)(GetTickCount() - StartWaitingTime);
            if(diff > MaxWaiting_sec * 1000) {
                
                zmq_ret += ", '_response': 'WAIT_LIMIT_EXCEEDED', '_response_value': " 
                + IntegerToString(MaxWaiting_sec);
                
                return(-2);
            }
            // if the trade context has become free,
            if(AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) {
                zmq_ret += ", '_response': 'TRADE_CONTEXT_NOW_FREE'";
                RefreshRates();
                return(1);
            }
            
          }
    } else {
        return(1);
    }
    
    return(1);
}
