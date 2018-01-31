import 'dart:async';
import 'dart:html';
import 'package:request_throttler/src/queue.dart';
import 'package:request_throttler/src/throttlers/browser/sockets/web_socket.dart';
import 'package:request_throttler/src/throttlers/vm/socket.dart' as Vm;

/// Throttler used for controlling connections made to SocketIo socket servers.
///
class SocketIoConnectionThrottler extends WebSocketConnectionThrottler {
  SocketIoConnectionThrottler(List<SocketRequestItem> queueableItems) : super(queueableItems);

  @override
  processQueueItem(QueueItem queueItemToProcess) {
    if(queueItemToProcess is SocketIoRequestItem) {
      Vm.SocketEndPoint socketEndPoint = queueItemToProcess.getSocketEndPoint();
      WebSocket webSocket = new WebSocket(socketEndPoint.url);
      webSocket.onOpen.listen((connection) {
        queueItemToProcess.socket = webSocket;
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


/// A Request item intended to be used for integrating with [SocketIoConnectionThrottler]s.
///
abstract class SocketIoRequestItem extends SocketRequestItem {
  /// Point in time when the socket's connection to the server was last closed.
  ///
  /// This is used by the [SocketIoConnectionThrottler]'s ping method to determine
  /// if it should keep pinging.
  DateTime timeOfLastClose = new DateTime.now();
  /// Point in time when the server last sent a pong message (in response to a
  /// ping message).
  ///
  /// This will help the [SocketIoConnectionThrottler] determine whether or not
  /// the remote server has timed out or not.
  DateTime timeOfLastPong = new DateTime.now();

  SocketIoRequestItem(Duration timeBetweenRequests, bool recurring, bool runOnRestart) : super(timeBetweenRequests, recurring, runOnRestart);

  /// Helper method used to simulate the output created when "emitting" a message
  /// using the SocketIo protocol.
  ///
  /// This is basically just a method that format's data. In order to communicate
  /// with SocketIo servers the information sent needs to be formatted a specific
  /// way.
  ///
  /// This method will attempt to format information appropriately so that it can
  /// be understood by the remote SocketIo server.
  static String formatAsEmit(String event, Map data){
    return '42["${event}",${data.toString()}]';
  }
}



