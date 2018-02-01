import 'dart:async';
import 'dart:io';
import 'package:request_throttler/request_items.dart';
import 'package:request_throttler/src/queue.dart';

/// Throttler used for controlling connections made to a [WebSocket] server.
///
class WebSocketConnectionThrottler extends QueueListener{
  WebSocketConnectionThrottler(List<SocketRequestItem> queueableItems) : super(queueableItems);

  void sendDataOverSocket(String data, SocketRequestItem requestItem){
    if(requestItem is SocketRequestItem && requestItem.socket != null && requestItem.socket is WebSocket){
      try {
        requestItem.socket.add(data);
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
  processQueueItem(QueueItem queueItemToProcess) async {
    if(queueItemToProcess is SocketRequestItem){
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
              (data){
                try {
                  queueItemToProcess.parseReceivedData(data);
                } catch(e){}
              },
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

