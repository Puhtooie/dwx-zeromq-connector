//+------------------------------------------------------------------+
//|                                                       Socket.mqh |
//|                        Copyright 2019, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

#include <Zmq/Zmq.mqh>

extern string PROJECT_NAME = "DWX_ZeroMQ_MT5_Server";
extern string ZEROMQ_PROTOCOL = "tcp";
extern string HOSTNAME = "*";
extern int PUSH_PORT = 32768;
extern int PULL_PORT = 32769;
extern int PUB_PORT = 32770;
extern int MILLISECOND_TIMER = 1;

// VARIABLES FOR LATER
uchar _data[];
ZmqMsg request;


ZmqMsg MessageHandler(ZmqMsg &_request) {
   
   // Output object
   ZmqMsg reply;
   
   // Message components for later.
   string components[11];
   
   if(_request.size() > 0) {
   
      // Get data from request   
      ArrayResize(_data, _request.size());
      _request.getData(_data);
      string dataStr = CharArrayToString(_data);
      
      // Process data
      ParseZmqMessage(dataStr, components);
      
      // Interpret data
      InterpretZmqMessage(&pushSocket, components);
      
   }
   else {
      // NO DATA RECEIVED
   }
   
   return(reply);
}

// Parse Zmq Message
void ParseZmqMessage(string& message, string& retArray[]) {
   
   //Print("Parsing: " + message);
   
   string sep = ";";
   ushort u_sep = StringGetCharacter(sep,0);
   
   int splits = StringSplit(message, u_sep, retArray);
   
   /*
   for(int i = 0; i < splits; i++) {
      Print(IntegerToString(i) + ") " + retArray[i]);
   }
   */
}
