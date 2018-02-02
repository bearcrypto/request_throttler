import 'dart:async';
import 'dart:io';
import 'package:request_throttler/request_items.dart';
import 'package:request_throttler/src/queue.dart';

/// Throttler used for controlling connections made to dart [Socket]s.
///
class IoSocketConnectionThrottler extends QueueListener{
  IoSocketConnectionThrottler(List<IoSocketRequestItem> queueableItems) : super(queueableItems);

  IoSocketConnectionThrottler.empty() : super([]);

  void sendDataOverSocket(String data, SocketRequestItem requestItem){
    if(requestItem is IoSocketRequestItem && requestItem.socket != null && requestItem.socket is Socket){
      try {
        requestItem.socket.write(data);
      } catch (e) {}
    }
  }

  @override
  void setupBeforeStart(){
    this.queueableItems.forEach((queueableItem){
      if(queueableItem is IoSocketRequestItem){
        queueableItem.sendDataOverSocketCallback = this.sendDataOverSocket;
      }
    });
  }

  @override
  void setupBeforeAdd(QueueItem itemBeingAdded) {
    if(itemBeingAdded is IoSocketRequestItem){
      itemBeingAdded.sendDataOverSocketCallback = this.sendDataOverSocket;
    }
  }

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
              (data){
                try {
                  queueItemToProcess.parseReceivedData(data);
                } catch(e){}
              },
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
