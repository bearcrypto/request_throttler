import 'dart:async';
import 'dart:io';
import 'package:request_throttler/src/queue.dart';
import 'package:request_throttler/src/throttlers/sockets/socket.dart';

class WebSocketConnectionThrottler extends QueueListener{
  WebSocketConnectionThrottler(List<WebSocketRequestItem> queueableItems) : super(queueableItems);

  @override
  void tearDownBeforeStop(){
    this.queueableItems.forEach((QueueItem queueItem){
      if(queueItem is WebSocketRequestItem && queueItem.socket != null){
        queueItem.socket.close(3005);
      }
    });
  }

  @override
  processQueueItem(QueueItem queueItemToProcess) async {
    if(queueItemToProcess is WebSocketRequestItem){
      SocketEndPoint socketEndPoint = queueItemToProcess.getSocketEndPoint();
      WebSocket.connect(socketEndPoint.url)
          .catchError((error){
        print('''Error connecting to web socket at address: ${socketEndPoint.url}
                    With error message: ${error.toString()}''');
        new Timer(const Duration(seconds: 1), (){
          this.reQueueItem(queueItemToProcess);
        });
      })
          .then((WebSocket webSocket){
        if(webSocket != null) {
          queueItemToProcess.socket = webSocket;
          if(socketEndPoint.handshakeData != null){
            queueItemToProcess.socket.add(socketEndPoint.handshakeData);
          }
          queueItemToProcess.socket.listen(
              queueItemToProcess.parseReceivedData,
              onDone: (){
                if(queueItemToProcess.recurring && queueItemToProcess.socket.closeCode != 3005){
                  new Timer(const Duration(seconds: 1), (){
                    this.reQueueItem(queueItemToProcess);
                  });
                }
              },
              onError: (error){
                new Timer(const Duration(seconds: 1), (){
                  this.reQueueItem(queueItemToProcess);
                });
              });
        }
      });
      await new Future.delayed(queueItemToProcess.timeBetweenRequests);
    }
  }
}

abstract class WebSocketRequestItem extends SocketRequestItem {
  WebSocket socket;
  WebSocketRequestItem(Duration timeBetweenRequests, bool recurring, bool runOnRestart) : super(timeBetweenRequests, recurring, runOnRestart);
}