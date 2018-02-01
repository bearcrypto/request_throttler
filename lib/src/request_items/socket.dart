import 'package:request_throttler/src/queue.dart';

/// A Request item intended to be used for integrating with socket servers.
///
/// This request item will allow any subclasses to implement exactly how
/// socket end points should be constructed, and the data returned from the socket
/// should be parsed and dealt with.
///
/// A single instance of [SocketRequestItem] will account for one physical
/// connection to the socket server at hand. Only one connection is allowed
/// per [SocketRequestItem].
abstract class SocketRequestItem extends QueueItem {

  /// The length of time necessary to wait between subsequent socket connections.
  ///
  /// Many socket servers will only allow clients to make a certain number of
  /// connections per minute. This value will tell any throttlers that are using
  /// it how long to wait before attempting to make another connection of the
  /// same type.
  Duration timeBetweenRequests;

  /// Socket used for making connections to socket servers.
  ///
  /// Due to the variety of Socket implementation for the vm and the browser,
  /// this field has been made dynamic in an attempt to reduce the amount of
  /// subclassing that has to happen for clients. It's left up to the throttler
  /// to properly set the socket to the correct type and interact with it.
  dynamic socket;

  /// Callback which will send the data over the [socket].
  ///
  /// The general use case is where the throttler will set this callback and then
  /// it can be used to send data.
  Function _sendDataOverSocketCallback;
  set sendDataOverSocketCallback(callback(String data, SocketRequestItem requestItem)){
    this._sendDataOverSocketCallback = callback;
  }

  SocketRequestItem(this.timeBetweenRequests, bool recurring, bool runOnRestart)
      : super(recurring, runOnRestart, false, const Duration(seconds: 0));

  SocketRequestItem.recurring(this.timeBetweenRequests)
      : super(true, true, false, const Duration(seconds: 0));

  /// Returns the [SocketEndPoint] that should be connected to
  ///
  SocketEndPoint getSocketEndPoint();

  /// Parses and handles any data received from the socket on a continuing basis.
  ///
  /// Certain throttlers may filter the data that get's sent here. Notice that the
  /// [receivedData] parameter is types [dynamic]. Different sockets return
  /// different types of data, therefore it's up to the specific [SocketRequestItem]
  /// to handle it appropriately.
  void parseReceivedData(dynamic receivedData);

  /// Allows the client to send data over the socket. If the socket is null or
  /// not connected no data is sent, and the data is discarded.
  void sendDataOverSocket(String data){
    if(this._sendDataOverSocketCallback != null){
      this._sendDataOverSocketCallback(data, this);
    }
  }
}

/// Http request item that allows the client to pass in a callback function which
/// can be called to notify the client of any important events.
///
/// The general use-case would be to pass the data received from the server
/// back to the client.
abstract class CallbackSocketRequestItem extends SocketRequestItem {
  /// Callback function supplied by the client.
  ///
  Function callback;

  CallbackSocketRequestItem(Duration timeBetweenRequests, bool recurring, bool runOnRestart, this.callback)
      : super(timeBetweenRequests, recurring, runOnRestart);

  CallbackSocketRequestItem.recurring(Duration timeBetweenRequests, this.callback)
      : super.recurring(timeBetweenRequests);

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

  SocketIoRequestItem.recurring(Duration timeBetweenRequests) : super.recurring(timeBetweenRequests);

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

/// Http request item that allows the client to pass in a callback function which
/// can be called to notify the client of any important events.
///
/// The general use-case would be to pass the data received from the server
/// back to the client.
abstract class CallbackSocketIoRequestItem extends SocketIoRequestItem {
  /// Callback function supplied by the client.
  ///
  Function callback;

  CallbackSocketIoRequestItem(Duration timeBetweenRequests, bool recurring, bool runOnRestart, this.callback)
      : super(timeBetweenRequests, recurring, runOnRestart);

  CallbackSocketIoRequestItem.recurring(Duration timeBetweenRequests, this.callback)
      : super.recurring(timeBetweenRequests);

}

/// A Request item intended to be used for integrating with [IoSocketConnectionThrottler]s.
///
abstract class IoSocketRequestItem extends SocketRequestItem {

  /// Indicates why the socket was closed.
  ///
  /// In certain circumstances, how the socket was closed and who closed it is
  /// important for knowing whether or not the connection should be re-established
  /// or not by the [IoSocketConnectionThrottler].
  int closeCode = 0;

  IoSocketRequestItem(Duration timeBetweenRequests, bool recurring, bool runOnRestart)
      : super(timeBetweenRequests, recurring, runOnRestart);
  IoSocketRequestItem.recurring(Duration timeBetweenRequests)
      : super.recurring(timeBetweenRequests);
}

/// Http request item that allows the client to pass in a callback function which
/// can be called to notify the client of any important events.
///
/// The general use-case would be to pass the data received from the server
/// back to the client.
abstract class CallbackIoSocketRequestItem extends IoSocketRequestItem {
  /// Callback function supplied by the client.
  ///
  Function callback;

  CallbackIoSocketRequestItem(Duration timeBetweenRequests, bool recurring, bool runOnRestart, this.callback)
      : super(timeBetweenRequests, recurring, runOnRestart);

  CallbackIoSocketRequestItem.recurring(Duration timeBetweenRequests, this.callback)
      : super.recurring(timeBetweenRequests);

}

/// All of the information necessary for initiating a connection to a socket.
///
class SocketEndPoint{
  String url;
  String handshakeData;
  SocketEndPoint(this.url, this.handshakeData);
}

/// All of the information necessary for initiating a connection to a socket.
///
class IoSocketEndPoint extends SocketEndPoint {
  int port;

  IoSocketEndPoint(String url, this.port, String handshakeData) : super(url, handshakeData);
}