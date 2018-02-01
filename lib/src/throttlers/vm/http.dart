import 'dart:async';
import 'package:http/http.dart' as Http;
import 'package:request_throttler/request_items.dart';
import 'package:request_throttler/src/queue.dart';

/// A Request item intended to be used for making requests to apis using
/// Http requests.
///
/// This request item will allow any subclasses to implement exactly how
/// api endpoints should be constructed.
///
/// A single instance of [HttpRequestThrottler] may account for any number
/// of Http requests that actually get carried out.
class HttpRequestThrottler extends QueueListener{

  /// Keeps track of how many times in a row a non-200 response has been received
  /// from the server.
  ///
  /// The higher this number get's the more certain it is that there is a problem
  /// interacting with the api. This can be used for logging purposes as well as
  /// system reaction purposes (i.e. maybe the system needs to change something).
  int _badResponseStreak = 0;

  HttpRequestThrottler(List<HttpRequestItem> queueableItems) : super(queueableItems);

  @override
  processQueueItem(QueueItem queueItemToProcess) async {
    if(queueItemToProcess is HttpRequestItem){
      List<HttpEndPoint> httpEndPoints = queueItemToProcess.getApiEndPoints();
      for(int i = 0; i < httpEndPoints.length; i++){
        this.makeHttpRequest(httpEndPoints[i].url).then((Http.Response response){
          if(response != null && response.statusCode == 200){
            queueItemToProcess.parseReceivedData(response.body, httpEndPoints[i]);
          }
        });
        await new Future.delayed(queueItemToProcess.timeBetweenRequests);
      }
    }
  }

  /// Abstracts the process of making an [Http.Request] to the specified [url].
  ///
  Future<Http.Response> makeHttpRequest(String url) async {
    Http.Client httpClient = new Http.Client();
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

  /// Reacts to the response that was returned from the api.
  ///
  /// In certain circumstances the client might want to do something when a good
  /// or bad response is received, this function can be overridden by subclasses
  /// to do specific things.
  reactToResponse(Http.Response response) async {
    if(response?.statusCode != 200) {
      _badResponseStreak++;
      String errorMessage = '''Received status code: ${response.statusCode} with reason :
      ${response.reasonPhrase}
      This is the ${this._badResponseStreak} time in a row a bad response has been received''';
      print(errorMessage);
    } else {
      this._badResponseStreak = 0;
    }
  }

}
