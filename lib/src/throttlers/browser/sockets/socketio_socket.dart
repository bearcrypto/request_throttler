import 'dart:async';
import 'dart:html';
import 'package:request_throttler/request_items.dart';
import 'package:request_throttler/src/queue.dart';
import 'package:request_throttler/src/throttlers/browser/sockets/web_socket.dart';

/// Throttler used for controlling connections made to SocketIo socket servers.
///
class SocketIoConnectionThrottler extends WebSocketConnectionThrottler {
  SocketIoConnectionThrottler(List<SocketIoRequestItem> queueableItems) : super(queueableItems);

  @override
  processQueueItem(QueueItem queueItemToProcess) {
    if(queueItemToProcess is SocketIoRequestItem) {
      SocketEndPoint socketEndPoint = queueItemToProcess.getSocketEndPoint();
      WebSocket webSocket = new WebSocket(socketEndPoint.url);
      webSocket.onOpen.listen((connection) {
        queueItemToProcess.socket = webSocket;
        this.ping(queueItemToProcess);
        webSocket.send(socketEndPoint.handshakeData);
        webSocket.onMessage.listen((data) {
          try {
            if(data.toString()[0] == "3"){
              queueItemToProcess.timeOfLastPong = new DateTime.now();
            } else {
              queueItemToProcess.parseReceivedData(data.data);
            }
          }catch(e){}
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

  /// Pings the SocketIo server repeatably in order to keep the connection alive.
  /// Also handles a situation where the server times out and stops responding to
  /// pings.
  void ping(SocketIoRequestItem requestItem){
    new Timer(const Duration(seconds: 25), () {
      if (requestItem.timeOfLastClose.add(const Duration(seconds: 25)).isBefore(
          new DateTime.now())) {
        if (requestItem.socket != null) {
          if (requestItem.timeOfLastPong.add(const Duration(seconds: 60))
              .isAfter(new DateTime.now())) {
            try {
              requestItem.socket.send("2ping");
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


