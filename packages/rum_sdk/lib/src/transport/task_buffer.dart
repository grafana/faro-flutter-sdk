import 'dart:async';
import 'dart:developer';

typedef Task<T> = Future<T> Function();

class TaskBuffer<T> {
  TaskBuffer(this._maxBufferLimit);

  final int _maxBufferLimit;
  int _bufferCount = 0;

  Future<T> add(Task<T> task) async {
    if (_bufferCount >= _maxBufferLimit) {
      log('Task Buffer is full, skipping task');
      return Future.value();
    } else {
      _bufferCount++;
      try {
        return await task();
      } catch (e) {
        log('Error executing task: $e');
        return Future.value();
      } finally {
        _bufferCount--;
      }
    }
  }
}
