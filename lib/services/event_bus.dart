import 'dart:async';

class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  final _ctrl = StreamController<String>.broadcast();

  Stream<String> get stream => _ctrl.stream;
  void emit(String event) => _ctrl.add(event);
  void dispose() { _ctrl.close(); }
}
