/// A collection of throttlers used for scheduling requests made to external systems
/// from the browser.
///
/// Any web apps can funnel their requests through the appropriate
/// throttlers to ensure that the external system in question isn't overwhelmed
/// with requests.
library browser_throttlers;

export 'src/throttlers/browser/http.dart';
export 'src/throttlers/browser/sockets/web_socket.dart';
export 'src/throttlers/browser/sockets/socketio_socket.dart';
