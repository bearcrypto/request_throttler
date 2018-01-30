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

  SocketRequestItem(this.timeBetweenRequests, bool recurring, bool runOnRestart)
      : super(recurring, runOnRestart, false, const Duration(seconds: 0));

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
}

/// All of the information necessary for initiating a connection to a socket.
///
class SocketEndPoint{
  String url;
  String handshakeData;
  SocketEndPoint(this.url, this.handshakeData);
}

