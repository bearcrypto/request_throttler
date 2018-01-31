import 'dart:async';
import 'package:http/http.dart' as Http;
import 'package:http/browser_client.dart';
import 'package:request_throttler/src/queue.dart';
import 'package:request_throttler/src/throttlers/vm/http.dart' as Vm;

/// A Request item intended to be used for making requests to apis using
/// Browser Http requests.
///
/// This throttler will only be able to make requests to apis that use
/// [CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS) for
/// cross-origin communication.
class HttpRequestThrottler extends Vm.HttpRequestThrottler {
  HttpRequestThrottler(List<Vm.HttpRequestItem> queueableItems) : super(queueableItems);

  @override
  Future<Http.Response> makeHttpRequest(String url) async {
    BrowserClient httpClient = new BrowserClient();
    Http.Response response = await httpClient.get(url)
        .catchError((error, stackTrace){
      print('''Error making http reqest to address: ${url}
      With message: ${error.toString()}''');
    })
        .whenComplete((){
      httpClient.close();
    });
    if(response != null){
      this.reactToResponse(response);
    }
    return response;
  }
}

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

/// All of the information necessary for making a request to an external api.
///
/// This may also be subclassed to include more domain specific information.
class HttpEndPoint {
  String url;

  HttpEndPoint(this.url);
}