import 'package:request_throttler/src/queue.dart';

abstract class SocketRequestItem extends QueueItem {

  Duration timeBetweenRequests;

  SocketRequestItem(this.timeBetweenRequests, bool recurring, bool runOnRestart)
      : super(recurring, runOnRestart, false, const Duration(seconds: 0));

  SocketEndPoint getSocketEndPoint();

  void parseReceivedData(dynamic receivedData);
}

class SocketEndPoint{
  String url;
  String handshakeData;
  SocketEndPoint(this.url, this.handshakeData);
}
