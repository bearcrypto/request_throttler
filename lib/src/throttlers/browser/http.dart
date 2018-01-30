import 'dart:async';
import 'package:http/http.dart' as Http;
import 'package:http/browser_client.dart';
import 'package:request_throttler/src/throttlers/vm/http.dart';

class BrowserHttpRequestThrottler extends HttpRequestThrottler {
  BrowserHttpRequestThrottler(List<HttpRequestItem> queueableItems) : super(queueableItems);

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