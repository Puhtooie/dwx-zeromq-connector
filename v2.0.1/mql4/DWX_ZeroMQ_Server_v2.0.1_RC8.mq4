//+--------------------------------------------------------------+
//This is currently my development for a MQL5 version of your code.
//If you have any thoughts, or suggestions, on the implimentation please let me know.
//Below if a list of functions that still have to be converted.
//
//*OrderSend
//*OrderModify
//*OrderClose
//*OrderDelete
//*ASK
//*BID

//*CopyClose (1 of 3 functions)
//*CopyTime (1 of 3 functions)
//*RefreshRates
//
//Url for MQL4 and MQL5 trade functions-
//MQL4: https://docs.mql4.com/trading
//MQL5: https://www.mql5.com/en/docs/trading
//Also note that MQL5 has a native library include/Trade. 
//+--------------------------------------------------------------+
#property copyright "Copyright 2017-2019, Darwinex Labs."
#property link      "https://www.darwinex.com/"
#property version   "2.0.1"
#property strict

// Required: MQL-ZMQ from https://github.com/dingmaotu/mql-zmq

#include <Zmq/Zmq.mqh>
#include <DWX/TradeDWX.mqh>
#include <DWX/Data.mqh>
#include <DWX/Socket.mqh>

extern string PROJECT_NAME = "DWX_ZeroMQ_MT5_Server";
extern string ZEROMQ_PROTOCOL = "tcp";
extern string HOSTNAME = "*";
extern int PUSH_PORT = 32768;
extern int PULL_PORT = 32769;
extern int PUB_PORT = 32770;
extern int MILLISECOND_TIMER = 1;

extern string t1 = "--- ZeroMQ Configuration ---";
extern bool Publish_MarketData = false;


string Publish_Symbols[28] = {
   "EURUSD","EURGBP","EURAUD","EURNZD","EURJPY","EURCHF","EURCAD",
   "GBPUSD","AUDUSD","NZDUSD","USDJPY","USDCHF","USDCAD","GBPAUD",
   "GBPNZD","GBPJPY","GBPCHF","GBPCAD","AUDJPY","CHFJPY","CADJPY",
   "AUDNZD","AUDCHF","AUDCAD","NZDJPY","NZDCHF","NZDCAD","CADCHF"
};

// CREATE ZeroMQ Context
Context context(PROJECT_NAME);

// CREATE ZMQ_PUSH SOCKET
Socket pushSocket(context, ZMQ_PUSH);

// CREATE ZMQ_PULL SOCKET
Socket pullSocket(context, ZMQ_PULL);

// CREATE ZMQ_PUB SOCKET
Socket pubSocket(context, ZMQ_PUB);

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---

   EventSetMillisecondTimer(MILLISECOND_TIMER);     // Set Millisecond Timer to get client socket input
   
   context.setBlocky(false);
   
   // Send responses to PULL_PORT that client is listening on.
   Print("[PUSH] Binding MT4 Server to Socket on Port " + 
   IntegerToString(PULL_PORT) + "..");
   
   pushSocket.bind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME,
    PULL_PORT));
   
   pushSocket.setSendHighWaterMark(1);
   pushSocket.setLinger(0);
   
   // Receive commands from PUSH_PORT that client is sending to.
   Print("[PULL] Binding MT4 Server to Socket on Port " + 
   IntegerToString(PUSH_PORT) + "..");   

   pullSocket.bind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME, 
   PUSH_PORT));
   
   pullSocket.setReceiveHighWaterMark(1);
   
   pullSocket.setLinger(0);
   
   if (Publish_MarketData == true)
   {
      // Send new market data to PUB_PORT that client is subscribed to.
      Print("[PUB] Binding MT4 Server to Socket on Port " +
       IntegerToString(PUB_PORT) + "..");

      pubSocket.bind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL,
       HOSTNAME, PUB_PORT));
       
      pubSocket.setSendHighWaterMark(1);
      pubSocket.setLinger(0);
   }
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
//---
    
   Print("[PUSH] Unbinding MT4 Server from Socket on Port " + 
   IntegerToString(PULL_PORT) + "..");
   
   pushSocket.unbind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME,
    PULL_PORT));
   
   Print("[PULL] Unbinding MT4 Server from Socket on Port " +
    IntegerToString(PUSH_PORT) + "..");
    
   pullSocket.unbind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME, 
   PUSH_PORT));
   
   if (Publish_MarketData == true)
   {
      Print("[PUB] Unbinding MT4 Server from Socket on Port " +
       IntegerToString(PUB_PORT) + "..");
       
      pubSocket.unbind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME,
       PUB_PORT));
   }
   
   // Shutdown ZeroMQ Context
   context.shutdown();
   context.destroy(0);
   
   EventKillTimer();
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   /*
      Use this OnTick() function to send market data to subscribed client.
   */
   if(!IsStopped() && Publish_MarketData == true)
   {
      for(int s = 0; s < ArraySize(Publish_Symbols); s++)
      {
         // Python clients can subscribe to a price feed by setting
         // socket options to the symbol name. For example:
         
         string _tick = GetBidAsk(Publish_Symbols[s]);
         Print("Sending " + Publish_Symbols[s] + " " + _tick + " to PUB Socket");
         
         ZmqMsg reply(StringFormat("%s %s", Publish_Symbols[s], _tick));

         pubSocket.send(reply, true);
      }
   }
}

//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
//---

   /*
      Use this OnTimer() function to get and respond to commands
   */
   
   // Get client's response, but don't block.
   pullSocket.recv(request, true);
   
   if (request.size() > 0)
   {
      // Wait 
      // pullSocket.recv(request,false);
      
      // MessageHandler() should go here.   
      ZmqMsg reply = MessageHandler(request);
      
      // Send response, and block
      // pushSocket.send(reply);
      
      // Send response, but don't block
      pushSocket.send(reply, true);
   }
}
//+------------------------------------------------------------------+


// Interpret Zmq Message and perform actions
void InterpretZmqMessage(Socket &pSocket, string &compArray[]) {

   // Print("ZMQ: Interpreting Message..");
   
   // Message Structures:
   
   // 1) Trading
   // TRADE|ACTION|TYPE|SYMBOL|PRICE|SL|TP|COMMENT|TICKET
   // e.g. TRADE|OPEN|1|EURUSD|0|50|50|R-to-MetaTrader4|12345678
   
   // The 12345678 at the end is the ticket ID, for MODIFY and CLOSE.
   
   // 2) Data Requests
   
   // 2.1) RATES|SYMBOL   -> Returns Current Bid/Ask
   
   // 2.2) DATA|SYMBOL|TIMEFRAME|START_DATETIME|END_DATETIME
   
   // NOTE: datetime has format: D'2015.01.01 00:00'
   
   /*
      compArray[0] = TRADE or RATES
      If RATES -> compArray[1] = Symbol
      
      If TRADE ->
         compArray[0] = TRADE
         compArray[1] = ACTION (e.g. OPEN, MODIFY, CLOSE)
         compArray[2] = TYPE (e.g. OP_BUY, OP_SELL, etc - only used when ACTION=OPEN)
         
         // ORDER TYPES: 
         // https://docs.mql4.com/constants/tradingconstants/orderproperties
         
         // OP_BUY = 0
         // OP_SELL = 1
         // OP_BUYLIMIT = 2
         // OP_SELLLIMIT = 3
         // OP_BUYSTOP = 4
         // OP_SELLSTOP = 5
         
         compArray[3] = Symbol (e.g. EURUSD, etc.)
         compArray[4] = Open/Close Price (ignored if ACTION = MODIFY)
         compArray[5] = SL
         compArray[6] = TP
         compArray[7] = Trade Comment
         compArray[8] = Lots
         compArray[9] = Magic Number
         compArray[10] = Ticket Number (MODIFY/CLOSE)
   */
   
   int switch_action = 0;
   
   if(compArray[0] == "TRADE" && compArray[1] == "OPEN")
      switch_action = 1;
   if(compArray[0] == "TRADE" && compArray[1] == "MODIFY")
      switch_action = 2;
   if(compArray[0] == "TRADE" && compArray[1] == "CLOSE")
      switch_action = 3;
   if(compArray[0] == "TRADE" && compArray[1] == "CLOSE_PARTIAL")
      switch_action = 4;
   if(compArray[0] == "TRADE" && compArray[1] == "CLOSE_MAGIC")
      switch_action = 5;
   if(compArray[0] == "TRADE" && compArray[1] == "CLOSE_ALL")
      switch_action = 6;
   if(compArray[0] == "TRADE" && compArray[1] == "GET_OPEN_TRADES")
      switch_action = 7;
   if(compArray[0] == "DATA")
      switch_action = 8;
   
   string zmq_ret = "{";
   int ticket = -1;
   bool ans = false;
   
   
   switch(switch_action) 
   {
      case 1: // OPEN TRADE
                  
         // Function definition:
         ticket = DWX_OpenOrder(compArray[3], StringToInteger(compArray[2]),
                                StringToDouble(compArray[8]), 
                                StringToDouble(compArray[4]), 
                                 StringToInteger(compArray[5]), 
                                 StringToInteger(compArray[6]), 
                                 compArray[7], StringToInteger(compArray[9]),
                                  zmq_ret
                                 );
                                 
         // Send TICKET back as JSON
         InformPullClient(pSocket, zmq_ret + "}");
         
         break;
         
      case 2: // MODIFY SL/TP
      
         zmq_ret += "'_action': 'MODIFY'";
         
         // Function definition:
         ans = DWX_SetSLTP(StringToInteger(compArray[10]),
                           StringToDouble(compArray[5]),
                           StringToDouble(compArray[6]), 
                           StringToInteger(compArray[9]), 
                           StringToInteger(compArray[2]),
                           StringToDouble(compArray[4]), 
                           compArray[3], 3, zmq_ret
                           );
         
         InformPullClient(pSocket, zmq_ret + "}");
         
         break;
         
      case 3: // CLOSE TRADE
      
         
         // IMPLEMENT CLOSE TRADE LOGIC HERE
         DWX_CloseOrder_Ticket(StringToInteger(compArray[10]), zmq_ret);
         
         InformPullClient(pSocket, zmq_ret + "}");
         
         break;
      
      case 4: // CLOSE PARTIAL
      
         
         ans = DWX_ClosePartial(StringToDouble(compArray[8]), zmq_ret,
          StringToInteger(compArray[10]));
            
         InformPullClient(pSocket, zmq_ret + "}");
         
         break;
         
      case 5: // CLOSE MAGIC
               
         DWX_CloseOrder_Magic(StringToInteger(compArray[9]), zmq_ret);
            
         InformPullClient(pSocket, zmq_ret + "}");
         
         break;
         
      case 6: // CLOSE ALL ORDERS
      
         
         DWX_CloseAllOrders(zmq_ret);
            
         InformPullClient(pSocket, zmq_ret + "}");
         
         break;
      
      case 7: // GET OPEN ORDERS
               
         DWX_GetOpenOrders(zmq_ret);
            
         InformPullClient(pSocket, zmq_ret + "}");
         
         break;
            
      case 8: // DATA REQUEST
           
         DWX_GetData(compArray, zmq_ret);
         
         InformPullClient(pSocket, zmq_ret + "}");
         
         break;
         
      default: 
         break;
   }
}

//+------------------------------------------------------------------+
