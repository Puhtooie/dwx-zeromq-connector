//+------------------------------------------------------------------+
//|                                                         Data.mqh |
//|                        Copyright 2019, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

#include <DWX/MarketInfoMQL4.mqh>

// Generate string for Bid/Ask by symbol
string GetBidAsk(string symbol) {
   
   MqlTick last_tick;
    
   if(SymbolInfoTick(symbol,last_tick))
   {
       return(StringFormat("%f;%f", last_tick.bid, last_tick.ask));
   }
   
   // Default
   return "";
}

// Get data for request datetime range
void DWX_GetData(string& compArray[], string& zmq_ret) {
         
   // Format: DATA|SYMBOL|TIMEFRAME|START_DATETIME|END_DATETIME
   
   double price_array[];
   datetime time_array[];
   
   // Get prices
   int price_count = CopyClose(
                      compArray[1],
                      StringToInteger(compArray[2]),
                      StringToTime(compArray[3]),
                      StringToTime(compArray[4]),
                      price_array
                      );
   
   // Get timestamps
   int time_count = CopyTime(
                  compArray[1], 
                  StringToInteger(compArray[2]),
                  StringToTime(compArray[3]),
                  StringToTime(compArray[4]),
                  time_array
                  );
      
   zmq_ret += "'_action': 'DATA'";
               
   if (price_count > 0) {
      
      zmq_ret += ", '_data': {";
      
      // Construct string of price|price|price|.. etc and send to PULL client.
      for(int i = 0; i < price_count; i++ ) {
         
         if(i == 0)
            zmq_ret += "'" + TimeToString(time_array[i]) + 
            "': " + DoubleToString(price_array[i]);
            
         else
            zmq_ret += ", '" + TimeToString(time_array[i]) + "': " 
            + DoubleToString(price_array[i]);
       
      }
      
      zmq_ret += "}";
      
   }
   else {
      zmq_ret += ", " + "'_response': 'NOT_AVAILABLE'";
   }
         
}

// Inform Client
void InformPullClient(Socket& pSocket, string message) {

   ZmqMsg pushReply(StringFormat("%s", message));
   
   pSocket.send(pushReply,true); // NON-BLOCKING
   
}

//+------------------------------------------------------------------+

double DWX_GetAsk(string symbol) {
   if(symbol == "NULL") {
      return(Ask);
   } else {
      return(MarketInfoMQL4(symbol,MODE_ASK));
   }
}

//+------------------------------------------------------------------+

double DWX_GetBid(string symbol) {
   if(symbol == "NULL") {
      return(Bid);
   } else {
      return(MarketInfoMQL4(symbol,MODE_BID));
   }
}
//+------------------------------------------------------------------+
