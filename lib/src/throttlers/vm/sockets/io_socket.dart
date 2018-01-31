import 'dart:async';
import 'dart:io';
import 'package:request_throttler/src/queue.dart';
import 'package:request_throttler/src/throttlers/vm/socket.dart';

/// Throttler used for controlling connections made to dart [Socket]s.
///
class IoSocketConnectionThrottler extends QueueListener{
  IoSocketConnectionThrottler(List<QueueItem> queueableItems) : super(queueableItems);

  @override
  void tearDownBeforeStop(){
    this.queueableItems.forEach((QueueItem queueItem){
      this.tearDownSocket(queueItem);
    });
  }

  @override
  void tearDownBeforeRemove(QueueItem itemBeingRemoved){
    this.tearDownSocket(itemBeingRemoved);
  }

  void tearDownSocket(QueueItem itemToTearDown){
    if(itemToTearDown is IoSocketRequestItem && itemToTearDown.socket != null){
      itemToTearDown.socket.close();
      itemToTearDown.closeCode = 3005;
    }
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

/// A Request item intended to be used for integrating with [IoSocketConnectionThrottler]s.
///
abstract class IoSocketRequestItem extends SocketRequestItem {

  /// The [Socket] object that is being used to make the connection.
  ///
  Socket socket;
  /// Indicates why the socket was closed.
  ///
  /// In certain circumstances, how the socket was closed and who closed it is
  /// important for knowing whether or not the connection should be re-established
  /// or not by the [IoSocketConnectionThrottler].
  int closeCode = 0;
  IoSocketRequestItem(Duration timeBetweenRequests, bool recurring, bool runOnRestart) : super(timeBetweenRequests, recurring, runOnRestart);
}

/// All of the information necessary for initiating a connection to a socket.
///
class IoSocketEndPoint extends SocketEndPoint {
  int port;

  IoSocketEndPoint(String url, this.port, String handshakeData) : super(url, handshakeData);

}