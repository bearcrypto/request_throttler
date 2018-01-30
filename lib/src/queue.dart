library queue_listener;

import 'dart:async';
import 'dart:collection';


/// A scheduling class designed to feed a collection of items through a queue
/// and execute them in order.
///
/// There are many situations where certain things need to be done or certain
/// tasks need to be executed in a organized and ordered fashion. In addition,
/// many times such tasks will need to be executed continuously on specific
/// intervals.
///
/// The [QueueListener] is a high level abstraction for such situations. [QueueItem]s
/// can be feed through the queue and executed in an ordered and organized
/// fashion.
///
/// A good example where something like this could come in handy is when making
/// Http requests. Suppose a system needs to get multiple pieces of information
/// from a REST Api, with some of that data needing to be fetched periodically.
/// Most REST Api's will implement request limits, where any external system can
/// only call the Api a certain number of time per minute or risk getting banned.
///
/// An application which isn't careful with scheduling the requests to the api
/// is in danger of violating rate limits, especially if certain requests need
/// to be made periodically.
///
/// This [QueueListener] abstract class could be used to schedule any Http requests
/// made to the external api and prevent concurrent requests from being made.
///
/// Obviously Http requests is just one use-case, but any similar situation could
/// leverage the scheduling capabilities of the [QueueListener] to organize
/// tasks.
abstract class QueueListener {

  /// Holds all pending [QueueItem]'s which need to be carried out.
  ///
  /// The queue acts as a bottle neck for any [QueueItem] tasks that need to
  /// be carried out. By funneling them into a queue, the [QueueListener] only
  /// has to deal with one thing at a time and tasks stay organized.
  ListQueue<QueueItem> _queue = new ListQueue<QueueItem>();
  /// A list of items that are intended to be feed through the [_queue].
  ///
  /// These are all of the [QueueItem]'s that the system is currently dealing with.
  /// If the system is stopped or restarted, these items will be fed through the
  /// queue automatically.
  List<QueueItem> queueableItems;
  /// Indicated whether or not the system is currently running (i.e. tasks are being
  /// scheduled).
  ///
  /// The system has two states, running and not running. The system starts in a
  /// not running state and must be started. When the system is started and running
  /// [QueueItem]s are being scheduled and run, and the system can actively
  /// accept and run tasks being added to the system.
  ///
  /// Once it's running a client may also stop the system, which will force any
  /// queue item's out of the [_queue] and everything will be shut down.
  bool _isRunning = false;
  bool get isRunning => this._isRunning;
  /// Indicates whether or not the system is actively listening for new queue
  /// items to process.
  ///
  /// The system only actively checks for new items in the queue when it's sure that
  /// atleast one new item has been added to it, so if the queue is empty for an
  /// extended period of time, the [QueueListener] effectively goes into sleep
  /// mode another [QueueItem] is ready to be processed.
  bool _listeningForNewQueueItems = false;
  /// Point in time when the system was last stopped, (i.e. [_isRunning] was false).
  ///
  /// An example of where this informaiton comes in handy:
  ///
  /// Certain [QueueItem]'s need to be processed periodically on specific intervals.
  /// Suppose a [QueueItem] just finished processing by the system and get's
  /// scheduled to be placed back into the processing [_queue] in 5 minutes.
  /// It's possible for an outside client to stop the system during that 5 minute
  /// waiting period, which means that this [QueueItem] should no longer be
  /// processed in the queue.
  ///
  /// By keeping track of the last time the [QueueListener] was stopped, situations
  /// like the one described above can easily be resolved. When the five minutes is
  /// up, the [QueueItem] can check to make sure the system hasen't stopped while it's
  /// been waiting. If the system did stop in that 5 minute waiting period, then
  /// the [QueueItem] isn't placed back in the queue.
  DateTime timeOfLastStop = new DateTime.now();

  QueueListener(this.queueableItems);

  /// Starts the [QueueListener]
  ///
  /// The [start] method first makes a call to [setupBeforeStart], which gives
  /// subclasses a chance to do something more specific when the system starts.
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

  /// Stops the [QueueListener]
  ///
  /// When the system is stopped certain [queueableItems]s are removed. More
  /// specifically any [queueableItems] that are not meant to be run when the
  /// system restarts are removed.
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

  /// Allows additional [QueueItem]s to be added to the system.
  ///
  /// The [QueueListener] is initialized with a collection of [QueueItem]s, but
  /// additional items may be added at any time using this function.
  ///
  /// If the system is currently running, then any new [QueueItem]s added will
  /// immediately be added to the back of the queue for processing.
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

  /// Re-queues an item in the [_queue].
  ///
  /// The system is capable of scheduling [QueueItem]'s to be processed periodically.
  /// Suppose you wanted a [QueueItem] to be run every 5 minutes. When that item is
  /// done being processed it can be re-queued by passing it into this method.
  ///
  /// The [reQueueItem] will figure out how long it took the item to go through the
  /// queue and be processed, and will schedule it to be processed again in the
  /// appropriate amount of time.
  ///
  /// For example if a [QueueItem] needs to be run every 5 minutes, and the [_queue]
  /// is backed up with requests, it might take the [QueueItem] 3 minutes to make
  /// it through the queue and get processed. In this case the [reQueueItem] method
  /// will set a timer set to go off and place the [QueueItem] in the [_queue] in
  /// 2 minutes.
  ///
  /// Or if it took the [QueueItem] 6 minutes to make it through the queue, it will
  /// reschedule it immediately and place it in the [_queue] without a waiting period.
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

  /// Listens for and then processes item's in the queue.
  ///
  /// This methods pulls items out of the queue and processes them. For the most
  /// part actual processing of the [QueueItem] will be left up to subclasses to implement.
  /// The purpose of the [QueueListener] and the [listenForQueueItems] method is
  /// to simply facilitate the [QueueItem]s in doing what they need to do.
  ///
  /// Once the [listenForQueueItems] method pulls an item out of the [_queue]
  /// it will tell it to process itself and wait for it to be done. Then depending
  /// on how the [QueueItem] is configured it will either re-schedule it or simply
  /// move on. Once it's done, the [listenForQueueItems] will call itself again and
  /// move on to the next item in the queue.
  ///
  /// If the queue is empty then this method will stop looping, but as long as there
  /// is something in the queue, it will keep going.
  ///
  /// This method is a little hacky. It uses a [Timer] with a duration of 1
  /// microsecond to emulate an infinite loop. An infinite while loop
  /// blocks other code from doing anything (i.e. adding items to the queue).
  /// But the [Timer] is non-blocking.
  ///
  /// The [Timer] implementation is basically recursion (the function calling
  /// itself), but without having to take a hit on memory. Unlike recursion the
  /// [listenForQueueItems] function is able to complete before it get's called again
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

  /// Method intended to be implemented by any clients subclassing [QueueListener].
  ///
  /// [processQueueItem] is by [listenForQueueItems] every time it pulls a
  /// [QueueItem] out of the [_queue]. Subclasses can then do what they want with
  /// the [QueueItem] and the [QueueListener] system will wait (async/await) for
  /// them to be done before moving on.
  processQueueItem(QueueItem queueItemToProcess);

  /// Gets called before the system is stopped.
  ///
  /// This function is optionally meant for subclasses to clean anything up
  /// before the system shuts down. This could include closing active connections,
  /// closing open files, etc.
  void tearDownBeforeStop(){}

  /// Get's called before the system is started.
  ///
  /// This function is optionally meant for subclasses to set anything up
  /// before the system starts.
  void setupBeforeStart(){}
}

/// An item intended to be processed by instances of [QueueListener].
///
/// This is a special class that is compatiable with [QueueListener], and can
/// be scheduled and processed by the [QueueListener] along with other [QueueItem]s.
///
/// The [QueueItem] defines certain fields which indicate to the [QueueListener]
/// how it should be processed and dealt with.
///
/// Ultimately the [QueueItem] abstract class is intended to be subclassed for
/// more specific use cases.
abstract class QueueItem {

  /// Determines whether or not this [QueueItem] should be processed on a
  /// recurring bases.
  ///
  /// Certain [QueueItem]s will need to be processed periodically, this flag
  /// will indicate to the [QueueListener] that it needs to be continually
  /// executed.
  bool recurring;
  /// Determines whether or not this [QueueItem] should be run even after the
  /// [QueueListener] is restarted (i.e. stopped and then started).
  ///
  /// Some tasks only need to be carried out once over the lifetime of the system,
  /// this flag will allow the client to control that.
  bool runOnRestart;
  /// Determines whether this [QueueItem] should be automatically requeued by
  /// the [QueueListener].
  bool shouldRequeueAutomatically;
  /// The total interval of time that this [QueueItem] should be processed at.
  ///
  /// Suppose a [QueueItem] is intended to be processed every 5 minutes by the
  /// [QueueListener]. That interval may be specified here.
  Duration totalRequeueInterval;
  /// Used by the [QueueListener] to keep track of how long it's been since this
  /// [QueueItem] was last submitted into the queue.
  Stopwatch stopwatch = new Stopwatch();

  QueueItem(this.recurring, this.runOnRestart, this.shouldRequeueAutomatically,
      this.totalRequeueInterval);
}


