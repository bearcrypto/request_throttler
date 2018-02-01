import 'package:request_throttler/src/queue.dart';

/// A Request item intended to be used for integrating with external apis through
/// http requests.
///
/// This request item will allow any subclasses to implement exactly how
/// api endpoints should be constructed, and the data returned from the http request
/// should be parsed and dealt with.
///
/// A single instance of [HttpRequestItem] will account for any number physical
/// requests to the server at hand.
abstract class HttpRequestItem extends QueueItem {

  /// The length of time necessary to wait between subsequent http requests.
  ///
  /// Many servers will only allow clients to make a certain number of requests
  /// per minute. This value will tell any throttlers that are using
  /// it how long to wait before attempting to make another request of the
  /// same type.
  Duration timeBetweenRequests;

  HttpRequestItem(this.timeBetweenRequests, bool recurring, bool runOnRestart, Duration totalRequeueInterval)
      : super(recurring, runOnRestart, true, totalRequeueInterval);

  HttpRequestItem.oneTimeRequest(this.timeBetweenRequests)
    : super(false, false, false, const Duration(seconds: 0));

  /// Returns a list of [HttpEndPoint] where requests should be made.
  ///
  /// Often times in order to get the full spectrum of data required for a system,
  /// multiple requests need to be made at slightly different end points. This
  /// method will construct those endpoints.
  List<HttpEndPoint> getApiEndPoints();

  /// Parses and handles any data received from http requests made on a continuing
  /// basis
  ///
  /// Certain throttlers may filter the data that get's sent here. This method
  /// takes two arguments:
  ///
  /// [receivedData] - the actual data that got returned in the body of the http
  /// response.
  ///
  /// [dataSource] - the [HttpEndPoint] where the data came from. In certain
  /// circumstances the [HttpEndPoint] will have data that's needed for accurately
  /// parsing the received data.
  void parseReceivedData(String receivedData, HttpEndPoint dataSource);
}

/// Http request item that allows the client to pass in a callback function which
/// can be called to notify the client of any important events.
///
/// The general use-case would be to pass the data received from the server
/// back to the client.
abstract class CallbackHttpRequestItem extends HttpRequestItem {

  /// Callback function supplied by the client.
  ///
  Function callback;

  CallbackHttpRequestItem(Duration timeBetweenRequests, bool recurring,
      bool runOnRestart, Duration totalRequeueInterval, this.callback)
      : super(timeBetweenRequests, recurring, runOnRestart, totalRequeueInterval);

  CallbackHttpRequestItem.oneTimeRequest(Duration timeBetweenRequests, this.callback)
      : super.oneTimeRequest(timeBetweenRequests);

}

/// All of the information necessary for making a request to an external api.
///
/// This may also be subclassed to include more domain specific information.
class HttpEndPoint {
  String url;

  HttpEndPoint(this.url);
}