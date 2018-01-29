library queue_listener;

import 'dart:async';
import 'dart:collection';

abstract class QueueListener {
  ListQueue<QueueItem> _queue = new ListQueue<QueueItem>();
  List<QueueItem> queueableItems;
  bool _isRunning = false;
  bool get isRunning => this._isRunning;
  bool _listeningForNewQueueItems = false;
  DateTime timeOfLastStop = new DateTime.now();

  QueueListener(this.queueableItems);

  void start(){
    this.setupBeforeStart();
    this._isRunning = true;
    this.queueableItems.forEach((queueableItem) {
      queueableItem.stopwatch.start();
      this._queue.add(queueableItem);
    });
    this._listeningForNewQueueItems = true;
    listenForQueueItems();
  }

  void stop(){
    this._isRunning = false;
    this.tearDownBeforeStop();
    this._queue.clear();
    this._listeningForNewQueueItems = false;
    queueableItems.removeWhere((queueableItem){
      return !queueableItem.runOnRestart;
    });
    this.timeOfLastStop = new DateTime.now();
  }

  void addQueuableItem(QueueItem queueableItem){
    this.queueableItems.add(queueableItem);
    if(this._isRunning){
      queueableItem.stopwatch.start();
      this._queue.add(queueableItem);
      if(!this._listeningForNewQueueItems){
        this.listenForQueueItems();
      }
    }
  }

  reQueueItem(QueueItem queueItem){
    if(this._isRunning){
      queueItem.stopwatch.stop();
      int millisecondsUntilNextEnqueue =
          queueItem.totalRequeueInterval.inMilliseconds -
              queueItem.stopwatch.elapsed.inMilliseconds;
      queueItem.stopwatch.reset();
      if(!millisecondsUntilNextEnqueue.isNegative){
        new Timer(new Duration(milliseconds: millisecondsUntilNextEnqueue), (){
          if(this._isRunning && this.timeOfLastStop.add(new Duration(milliseconds: millisecondsUntilNextEnqueue)).isBefore(new DateTime.now())){
            queueItem.stopwatch.start();
            _queue.add(queueItem);
            if(!this._listeningForNewQueueItems){
              this.listenForQueueItems();
            }
          }
        });
      } else {
        queueItem.stopwatch.start();
        _queue.add(queueItem);
        if(!this._listeningForNewQueueItems){
          this.listenForQueueItems();
        }
      }
    }
  }

  listenForQueueItems(){
    if(this._isRunning){
      if(this._queue.isNotEmpty){
        this._listeningForNewQueueItems = true;
        new Timer(const Duration(microseconds: 1), () async {
          QueueItem queueItemBeingProcessed = _queue.removeFirst();
          await this.processQueueItem(queueItemBeingProcessed);
          if(queueItemBeingProcessed.recurring && queueItemBeingProcessed.shouldRequeueAutomatically){
            this.reQueueItem(queueItemBeingProcessed);
          }
          listenForQueueItems();
        });
      } else {
        this._listeningForNewQueueItems = false;
      }
    }
  }

  processQueueItem(QueueItem queueItemToProcess);
  void tearDownBeforeStop(){}
  void setupBeforeStart(){}
}

abstract class QueueItem {
  bool recurring;
  bool runOnRestart;
  bool shouldRequeueAutomatically;
  Duration totalRequeueInterval;
  Stopwatch stopwatch = new Stopwatch();

  QueueItem(this.recurring, this.runOnRestart, this.shouldRequeueAutomatically,
      this.totalRequeueInterval);
}


