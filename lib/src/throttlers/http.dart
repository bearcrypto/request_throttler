import 'dart:async';
import 'package:http/http.dart' as Http;
import 'package:request_throttler/src/queue.dart';

class HttpRequestThrottler extends QueueListener{

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
      this._reactToResponse(response);
    }
    return response;
  }

  _reactToResponse(Http.Response response) async {
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

abstract class HttpRequestItem extends QueueItem {
  Duration timeBetweenRequests;

  HttpRequestItem(this.timeBetweenRequests, bool recurring, bool runOnRestart, Duration totalRequeueInterval)
      : super(recurring, runOnRestart, true, totalRequeueInterval);

  List<HttpEndPoint> getApiEndPoints();

  void parseReceivedData(String receivedData, HttpEndPoint dataSource);
}

class HttpEndPoint {
  String url;

  HttpEndPoint(this.url);
}