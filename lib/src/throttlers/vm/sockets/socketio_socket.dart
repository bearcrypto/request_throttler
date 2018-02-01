import 'dart:async';
import 'dart:io';
import 'package:request_throttler/request_items.dart';
import 'package:request_throttler/src/queue.dart';
import 'package:request_throttler/src/throttlers/vm/sockets/web_socket.dart';

/// Throttler used for controlling connections made to SocketIo socket servers.
///
class SocketIoConnectionThrottler extends WebSocketConnectionThrottler{

  SocketIoConnectionThrottler(List<SocketIoRequestItem> queueableItems) : super(queueableItems);

  @override
  processQueueItem(QueueItem queueItemToProcess) async {
    if(queueItemToProcess is SocketIoRequestItem){
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
          this.ping(queueItemToProcess);
          if(socketEndPoint.handshakeData != null){
            queueItemToProcess.socket.add(socketEndPoint.handshakeData);
          }
          queueItemToProcess.socket.listen(
              (data){
                try {
                  if(data.toString()[0] == "3"){
                    queueItemToProcess.timeOfLastPong = new DateTime.now();
                  } else {
                    queueItemToProcess.parseReceivedData(data);
                  }
                } catch(e){}

              },
              onDone: (){
                queueItemToProcess.timeOfLastClose = new DateTime.now();
                if(queueItemToProcess.recurring && queueItemToProcess.socket.closeCode != 3005){
                  new Timer(const Duration(seconds: 1), (){
                    this.reQueueItem(queueItemToProcess);
                  });
                }
              },
              onError: (error){
                queueItemToProcess.timeOfLastClose = new DateTime.now();
                new Timer(const Duration(seconds: 1), (){
                  this.reQueueItem(queueItemToProcess);
                });
              });
        }
      });
      await new Future.delayed(queueItemToProcess.timeBetweenRequests);
    }
  }

  /// Pings the SocketIo server repeatably in order to keep the connection alive.
  /// Also handles a situation where the server times out and stops responding to
  /// pings.
  void ping(SocketIoRequestItem requestItem){
    new Timer(const Duration(seconds: 25), () {
      if (requestItem.timeOfLastClose.add(const Duration(seconds: 25)).isBefore(
          new DateTime.now())) {
        if (requestItem.socket != null &&
            requestItem.socket.closeCode == null) {
          if (requestItem.timeOfLastPong.add(const Duration(seconds: 60))
              .isAfter(new DateTime.now())) {
            try {
              requestItem.socket.add("2ping");
            } catch (error) {

            } finally {
              ping(requestItem);
            }
          } else {
            requestItem.socket.close();
          }
        }
      } else {
      }
    });
  }
}



