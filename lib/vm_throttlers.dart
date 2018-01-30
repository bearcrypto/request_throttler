/// A collection of throttlers used for scheduling requests made to external systems
/// from the vm.
///
/// Any vm apps can funnel their requests through the appropriate
/// throttlers to ensure that the external system in question isn't overwhelmed
/// with requests.
library vm_throttlers;

export 'package:request_throttler/src/throttlers/vm/http.dart';
export 'package:request_throttler/src/throttlers/vm/sockets/web_socket.dart';
export 'package:request_throttler/src/throttlers/vm/sockets/socketio_socket.dart';
export 'package:request_throttler/src/throttlers/vm/sockets/io_socket.dart';
