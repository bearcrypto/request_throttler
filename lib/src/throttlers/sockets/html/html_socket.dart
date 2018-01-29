import 'dart:async';
import 'dart:html';
import 'package:request_throttler/src/queue.dart';
import 'package:request_throttler/src/throttlers/sockets/socket.dart';

class HtmlSocketConnectionThrottler extends QueueListener{
  HtmlSocketConnectionThrottler(List<HtmlSocketRequestItem> queueableItems) : super(queueableItems);

  @override
  void tearDownBeforeStop(){
    this.queueableItems.forEach((QueueItem queueItem){
      if(queueItem is HtmlSocketRequestItem && queueItem.socket != null){
        queueItem.socket.close(3005);
      }
    });
  }

  @override
  processQueueItem(QueueItem queueItemToProcess) {
    if(queueItemToProcess is HtmlSocketRequestItem) {
      SocketEndPoint socketEndPoint = queueItemToProcess.getSocketEndPoint();

      WebSocket webSocket = new WebSocket(socketEndPoint.url);
      if(webSocket != null){
        webSocket.onOpen.listen((connection) {
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
}

abstract class HtmlSocketRequestItem extends SocketRequestItem {
  WebSocket socket;
  HtmlSocketRequestItem(Duration timeBetweenRequests, bool recurring, bool runOnRestart) : super(timeBetweenRequests, recurring, runOnRestart);
}