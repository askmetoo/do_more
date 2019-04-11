import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:rxdart/rxdart.dart';

/// A service that maintains a record of the upload operations made to
/// the firebase storage bucket.
class _UploadStatusService {
  /// A subject of the current status of uploads.
  final _status = BehaviorSubject<UploadStatus>();

  /// A map that contains the information about all the current upload tasks.
  Map<StorageUploadTask, List<int>> tasksData =
      <StorageUploadTask, List<int>>{};

  /// An observable of the status for all current upload tasks.
  Observable<UploadStatus> get status => _status.stream;

  /// Adds a new upload task to be tracked.
  ///
  /// The task gets automatically removed when done.
  void addNewUpload(StorageUploadTask task) async {
    final initialSnap = task.lastSnapshot;
    // Initialize the map entry with the initial values.
    tasksData[task] = [
      initialSnap.bytesTransferred,
      initialSnap.totalByteCount,
    ];
    task.events.listen(
      (StorageTaskEvent event) {
        // Update the map with the current values.
        final snap = event.snapshot;
        tasksData[task] = [
          snap.bytesTransferred,
          snap.totalByteCount,
        ];
        _sendUpdate();
      },
    );
    await task.onComplete;
    tasksData.remove(task);
  }

  /// Updates the _status subject with the most current data.
  void _sendUpdate() {
    int totalBytes = 0, bytestTransferred = 0;
    double percentage = 0.0;
    tasksData.forEach(
      (_, data) {
        bytestTransferred += data[0];
        totalBytes += data[1];
      },
    );
    if (bytestTransferred != 0) {
      percentage = totalBytes / bytestTransferred;
    }
    _status.sink.add(UploadStatus(
      percentage: percentage,
      numberOfFiles: tasksData.length,
    ));
  }

  dispose() async {
    await _status.drain();
    _status.close();
  }
}

/// The status of an upload.
class UploadStatus {
  /// Percentage of the upload.
  final double percentage;

  /// Number of files being uploaded.
  ///
  /// It can be 0 if nothing is currently being uploaded.
  final int numberOfFiles;

  /// Creates an [UploadStatus] instance.
  UploadStatus({
    this.percentage,
    this.numberOfFiles,
  });
}

final uploadStatusService = _UploadStatusService();
