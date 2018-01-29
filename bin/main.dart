import 'dart:async';
import 'package:request_throttler/src/throttlers/sockets/socket.dart';
import 'package:request_throttler/src/throttlers/sockets/vm/socketio_socket.dart';

void main(){
  SocketIoConnectionThrottler throttler = new SocketIoConnectionThrottler([new SocketioRequestItem(const Duration(seconds: 1), true, true)]);
  throttler.start();

}

class SocketioRequestItem extends SocketIoRequestItem{
  SocketioRequestItem(Duration timeBetweenRequests, bool recurring, bool runOnRestart)
      : super(timeBetweenRequests, recurring, runOnRestart);

  
  @override
  SocketEndPoint getSocketEndPoint() {
    return new SocketEndPoint("wss://streamer.cryptocompare.com/socket.io/?transport=websocket",
        '42["SubAdd",{"subs":["5~CCCAGG~BTC~USD"]}]');
  }

  @override
  void parseReceivedData(receivedData) {
    print(receivedData);
  }
}