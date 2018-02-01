import 'dart:async';
import 'dart:html';
import 'package:request_throttler/request_items.dart';
import 'package:request_throttler/src/queue.dart';

/// Throttler used for controlling connections made to a [WebSocket] server.
///
class WebSocketConnectionThrottler extends QueueListener{
  WebSocketConnectionThrottler(List<SocketRequestItem> queueableItems) : super(queueableItems);

  void sendDataOverSocket(String data, SocketRequestItem requestItem){
    if(requestItem is SocketRequestItem && requestItem.socket != null && requestItem.socket is WebSocket){
      try {
        requestItem.socket.send(data);
      } catch (e) {}
    }
  }

  @override
  void setupBeforeStart(){
    this.queueableItems.forEach((queueableItem){
      if(queueableItem is SocketRequestItem){
        queueableItem.sendDataOverSocketCallback = this.sendDataOverSocket;
      }
    });
  }

  @override
  void setupBeforeAdd(QueueItem itemBeingAdded) {
    if(itemBeingAdded is SocketRequestItem){
      itemBeingAdded.sendDataOverSocketCallback = this.sendDataOverSocket;
    }
  }

  @override
  void tearDownBeforeStop(){
    this.queueableItems.forEach((QueueItem queueItem){
      if(queueItem is SocketRequestItem && queueItem.socket != null){
        queueItem.socket.close(3005);
      }
    });
  }

  @override
  void tearDownBeforeRemove(QueueItem itemBeingRemoved){
    if(itemBeingRemoved is SocketRequestItem && itemBeingRemoved.socket != null){
      itemBeingRemoved.socket.close(3005);
    }
  }

  @override
  processQueueItem(QueueItem queueItemToProcess) {
    if(queueItemToProcess is SocketRequestItem) {
      SocketEndPoint socketEndPoint = queueItemToProcess.getSocketEndPoint();
      WebSocket webSocket = new WebSocket(socketEndPoint.url);
        webSocket.onOpen.listen((connection) {
          queueItemToProcess.socket = webSocket;
          webSocket.send(socketEndPoint.handshakeData);
          webSocket.onMessage.listen((data) {
            queueItemToProcess.parseReceivedData(data.data);
          });
          webSocket.onClose.listen((close) {
            if (queueItemToProcess.recurring && close.code != 3005) {
              new Timer(const Duration(seconds: 1), () {
                this.reQueueItem(queueItemToProcess);
              });
            }
          });
          webSocket.onError.listen((error) {
            new Timer(const Duration(seconds: 1), () {
              this.reQueueItem(queueItemToProcess);
            });
          });
        })
            .onError((error) {
          print(
              '''Error connecting to web socket at address: ${socketEndPoint.url}
                    With error message: ${error.toString()}''');
          new Timer(const Duration(seconds: 1), () {
            this.reQueueItem(queueItemToProcess);
          });
        });
      }
  }
}