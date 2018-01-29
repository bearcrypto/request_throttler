import 'dart:async';
import 'dart:io';
import 'package:request_throttler/src/queue.dart';
import 'package:request_throttler/src/throttlers/sockets/socket.dart';

class IoSocketConnectionThrottler extends QueueListener{
  IoSocketConnectionThrottler(List<QueueItem> queueableItems) : super(queueableItems);


  @override
  void tearDownBeforeStop(){
    this.queueableItems.forEach((QueueItem queueItem){
      if(queueItem is IoSocketRequestItem && queueItem.socket != null){
        queueItem.socket.close();
        queueItem.closeCode = 3005;

      }
    });
  }

  @override
  processQueueItem(QueueItem queueItemToProcess) {
    if(queueItemToProcess is IoSocketRequestItem){
      IoSocketEndPoint socketEndPoint = queueItemToProcess.getSocketEndPoint();
      Socket.connect(socketEndPoint.url, socketEndPoint.port)
          .catchError((error){
        print('''Error connecting to web socket at address: ${socketEndPoint.url}
                    With error message: ${error.toString()}''');
        new Timer(const Duration(seconds: 1), (){
          this.reQueueItem(queueItemToProcess);
        });
      })
          .then((Socket socket){
        if(socket != null){
          queueItemToProcess.socket = socket;
          if(socketEndPoint.handshakeData != null){
            queueItemToProcess.socket.write(socketEndPoint.handshakeData);
          }
          queueItemToProcess.socket.listen(
              queueItemToProcess.parseReceivedData,
              onDone: (){
                if(queueItemToProcess.recurring && queueItemToProcess.closeCode != 3005){
                  new Timer(const Duration(seconds: 1), (){
                    this.reQueueItem(queueItemToProcess);
                  });
                }
                queueItemToProcess.closeCode = 0;
              },
              onError: (error){
                new Timer(const Duration(seconds: 1), (){
                  this.reQueueItem(queueItemToProcess);
                });
              });
        }
      });
    }
  }
}

abstract class IoSocketRequestItem extends SocketRequestItem {
  Socket socket;
  int closeCode = 0;
  IoSocketRequestItem(Duration timeBetweenRequests, bool recurring, bool runOnRestart) : super(timeBetweenRequests, recurring, runOnRestart);
}

class IoSocketEndPoint extends SocketEndPoint {
  int port;

  IoSocketEndPoint(String url, this.port, String handshakeData) : super(url, handshakeData);

}