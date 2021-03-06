import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import './models/event_model.dart';
import './models/task_model.dart';
import './services/upload_status_service.dart';

const kLowPriorityColor = Color(0xFF06AD12);
const kMediumPriorityColor = Color(0xFFF6A93B);
const kHighPriorityColor = Color(0xFFF42850);

const kBigTextStyle = TextStyle(
  color: Colors.white,
  fontSize: 24,
  fontWeight: FontWeight.w600,
);
const kSmallTextStyle = TextStyle(
  color: Colors.white,
  fontSize: 16,
  fontWeight: FontWeight.w500,
);

const kTileBigTextStyle = TextStyle(
  color: Colors.white,
  fontSize: 24,
  fontWeight: FontWeight.bold,
);

const kTileSubtitleStyle = TextStyle(
  color: Colors.white,
  fontSize: 10,
  fontWeight: FontWeight.w300,
);

const kBlueGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  stops: [0, 1.0],
  colors: [Color.fromRGBO(32, 156, 227, 1.0), Color.fromRGBO(45, 83, 216, 1.0)],
);

Color getColorFromPriority(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.low:
      return kLowPriorityColor;
      break;
    case TaskPriority.medium:
      return kMediumPriorityColor;
      break;
    case TaskPriority.high:
      return kHighPriorityColor;
      break;
    default:
      return Colors.white;
  }
}

Color getColorFromEvent(EventModel event) {
  if (event.highPriority != 0) {
    return kHighPriorityColor;
  } else if (event.mediumPriority != 0) {
    return kMediumPriorityColor;
  }
  return kLowPriorityColor;
}

mixin Validators {
  final stringNotEmptyValidator =
      StreamTransformer<String, String>.fromHandlers(
    handleData: (String string, EventSink<String> sink) {
      if (string.isEmpty) {
        sink.addError('Text cannot be empty');
      } else {
        sink.add(string);
      }
    },
  );

  final occuranceArrayValidator =
      StreamTransformer<List<bool>, List<bool>>.fromHandlers(
    handleData: (List<bool> array, EventSink<List<bool>> sink) {
      if (array.length == 5 && array.contains(true)) {
        sink.add(array);
      } else {
        sink.addError('Event has to ocurr at least once');
      }
    },
  );
}

/// Returns a stream transformer that sorts tasks by priority.
final StreamTransformer<List<TaskModel>, List<TaskModel>>
    kTaskListPriorityTransforemer =
    StreamTransformer.fromHandlers(handleData: (tasksList, sink) {
  tasksList.sort((a, b) => TaskModel.ecodedPriority(b.priority)
      .compareTo(TaskModel.ecodedPriority(a.priority)));
  sink.add(tasksList);
});

/// Gets the path of an image thumbnail from its original path.
String getImageThumbnailPath(String path) {
  List<String> tokens = path.split('/');
  tokens.last = 'thumb@' + tokens.last;
  return tokens.join('/');
}

/// Shows an upload status snack bar.
///
/// Takes the data from the [uploadStatus] stream and shows in the snack bar.
/// Calls [onSuccessfullyClosed] with [false] when all files are done being
/// uploaded.
void showUploadStatusSnackBar(
  BuildContext scaffoldContext,
  Observable<UploadStatus> uploadStatus,
  Function(bool) onSuccessfullyClosed,
) {
  assert(scaffoldContext != null);
  assert(uploadStatus != null);
  assert(onSuccessfullyClosed != null);
  final scaffoldState = Scaffold.of(scaffoldContext);
  scaffoldState.showSnackBar(SnackBar(
    /// The snack bar shouldn't close until the files are done uploading
    /// hence the long duration. It gets closed programatically.
    duration: Duration(hours: 1),
    content: StreamBuilder(
      stream: uploadStatus,
      builder: (BuildContext context, AsyncSnapshot<UploadStatus> snap) {
        if (!snap.hasData) {
          return Text('');
        }
        print('Number of files: ${snap.data.numberOfFiles}');
        if (snap.data.numberOfFiles == 0) {
          return Text('Done!');
        }
        return Row(
          children: <Widget>[
            Spacer(),
            Text('${snap.data.numberOfFiles} pending'),
            Spacer(flex: 5),
            Text(snap.data.percentage + '%'),
            Spacer(),
          ],
        );
      },
    ),
  ));
}

/// A transformer that only emits a value if it is different than the last one
/// emitted.
///
/// The [==] operator is to check for inequality, be sure that the objects
/// passing through the stream behave correctly with theses operator.
class DistinctStreamTransformer<T> extends StreamTransformerBase<T, T> {
  final StreamTransformer<T, T> transformer;

  DistinctStreamTransformer() : transformer = _buildTransformer();

  @override
  Stream<T> bind(Stream<T> stream) => transformer.bind(stream);

  static StreamTransformer<T, T> _buildTransformer<T>() {
    return StreamTransformer<T, T>((Stream<T> input, bool cancelOnError) {
      T last;
      StreamController<T> controller;
      StreamSubscription<T> subscription;

      controller = StreamController<T>(
          sync: true,
          onListen: () {
            subscription = input.listen(
              (T value) {
                if (!(last == value)) {
                  last = value;
                  controller.add(value);
                }
              },
              onError: controller.addError,
              onDone: controller.close,
              cancelOnError: cancelOnError,
            );
          },
          onPause: ([Future<dynamic> resumeSignal]) =>
              subscription.pause(resumeSignal),
          onResume: () => subscription.resume(),
          onCancel: () {
            return subscription.cancel();
          });

      return controller.stream.listen(null);
    });
  }
}
