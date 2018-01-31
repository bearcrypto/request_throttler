import 'dart:async';
import 'dart:html';
import 'package:request_throttler/src/queue.dart';
import 'package:request_throttler/src/throttlers/vm/socket.dart' as Vm;

/// Throttler used for controlling connections made to a [WebSocket] server.
///
class WebSocketConnectionThrottler extends QueueListener{
  WebSocketConnectionThrottler(List<SocketRequestItem> queueableItems) : super(queueableItems);

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
      Vm.SocketEndPoint socketEndPoint = queueItemToProcess.getSocketEndPoint();
      WebSocket webSocket = new WebSocket(socketEndPoint.url);
        webSocket.onOpen.listen((connection) {
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

/// A Request item intended to be used for integrating with [WebSocketConnectionThrottler]s.
///
abstract class SocketRequestItem extends Vm.SocketRequestItem {
  WebSocket socket;
  SocketRequestItem(Duration timeBetweenRequests, bool recurring, bool runOnRestart) : super(timeBetweenRequests, recurring, runOnRestart);
}