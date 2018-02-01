import 'dart:async';
import 'package:http/http.dart' as Http;
import 'package:http/browser_client.dart';
import 'package:request_throttler/request_items.dart';
import 'package:request_throttler/src/throttlers/vm/http.dart' as Vm;

/// A Request item intended to be used for making requests to apis using
/// Browser Http requests.
///
/// This throttler will only be able to make requests to apis that use
/// [CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS) for
/// cross-origin communication.
class HttpRequestThrottler extends Vm.HttpRequestThrottler {
  HttpRequestThrottler(List<HttpRequestItem> queueableItems) : super(queueableItems);

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
