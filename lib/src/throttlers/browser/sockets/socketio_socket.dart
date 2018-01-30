import 'dart:async';
import 'dart:html';
import 'package:request_throttler/src/queue.dart';
import 'package:request_throttler/src/throttlers/browser/sockets/web_socket.dart';
import 'package:request_throttler/src/throttlers/vm/socket.dart';
import 'package:request_throttler/src/throttlers/vm/sockets/socketio_socket.dart';

class SocketIoConnectionThrottler extends WebSocketConnectionThrottler {
  SocketIoConnectionThrottler(List<HtmlSocketRequestItem> queueableItems) : super(queueableItems);

  @override
  processQueueItem(QueueItem queueItemToProcess) {
    if(queueItemToProcess is SocketIoRequestItem) {
      SocketEndPoint socketEndPoint = queueItemToProcess.getSocketEndPoint();
      WebSocket webSocket = new WebSocket(socketEndPoint.url);
      webSocket.onOpen.listen((connection) {
        this.ping(queueItemToProcess);
        webSocket.send(socketEndPoint.handshakeData);
        webSocket.onMessage.listen((data) {
          if(data.toString()[0] == "3"){
            queueItemToProcess.timeOfLastPong = new DateTime.now();
          } else {
            queueItemToProcess.parseReceivedData(data.data);
          }
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