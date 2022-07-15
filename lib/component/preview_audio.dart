library fabric_flutter;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' show DateFormat;

enum Media {
  file,
  buffer,
  asset,
  stream,
  remoteExampleFile,
}

enum AudioState {
  isPlaying,
  isPaused,
  isStopped,
  isRecording,
  isRecordingPaused,
}

/// Fetch audio file
Future<http.Response> fetchFile(String url) {
  Uri _url = Uri.parse(url);
  return http.get(_url);
}

/// Fetch audio file
Future<http.Response> hedURL(String url) {
  Uri _url = Uri.parse(url);
  return http.head(_url);
}

/// This a component to preview audio, it loads a url and you can play it within the app.
///
/// [url] The url of the audio file.
/// [loadingText] Locale text to be displayed when loading.
/// AudioPreview(
///   url: mediaUrl,
///   loadingText: 'loading...',
/// );
class AudioPreview extends StatefulWidget {
  const AudioPreview({
    Key? key,
    required this.url,
    this.loadingText = 'loading',
  }) : super(key: key);

  final String? url;
  final String loadingText;

  @override
  State<AudioPreview> createState() => _AudioPreviewState();
}

class _AudioPreviewState extends State<AudioPreview>
    with WidgetsBindingObserver {
  IconData? icon;
  bool? _isPlaying;
  double? maxDuration;

  // ignore: cancel_subscriptions
  StreamSubscription? _playerSubscription;
  String _playerTxt = '00:00';
  double? slide;
  double? sliderCurrentPosition;
  FlutterSoundPlayer? playerModule = FlutterSoundPlayer();
  late bool ready;

  Future<void> init() async {
    if (ready) {
      return;
    }
    try {
      await _initializeExample();
    } catch (error) {
      //
    }
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    icon = Icons.hourglass_full;
    _isPlaying = false;
    maxDuration = 1.0;
    slide = 0.0;
    sliderCurrentPosition = 0.0;
    ready = false;
    _initializeExample().catchError((error) {
      if (kDebugMode) print(error);
    });
    super.initState();
  }

  @override
  void didChangeDependencies() {
    stopPlayer();
    super.didChangeDependencies();
  }

  @override
  void deactivate() {
    //this method not called when user press android back button or quit
    stopPlayer();
    super.deactivate();
  }

  @override
  void dispose() {
    stopPlayer();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  cancelPlayerSubscriptions() async {
    if (_playerSubscription != null) await _playerSubscription!.cancel();
    _playerSubscription = null;
  }

  Future<void> releaseFlauto() async {
    if (!playerModule!.isOpen()) return;
    try {
      if (_playerSubscription != null) await playerModule!.closePlayer();
    } catch (e) {
      if (kDebugMode) print('Released unsuccessful: $e');
    }
  }

  Future<void> _initializeExample() async {
    await playerModule!.openPlayer(
        // focus: AudioFocus.requestFocusTransientExclusive,
        // category: SessionCategory.playback,
        // audioFlags: outputToSpeaker
        );
    // await playerModule!.setSubscriptionDuration(Duration(seconds: 60));
    initializeDateFormatting();
    ready = true;
    icon = Icons.play_arrow;
    if (mounted) setState(() {});
  }

  Future<bool> fileExists(String path) async {
    return await File(path).exists();
  }

  _addListeners() async {
    if (!playerModule!.isOpen()) return;
    // await cancelPlayerSubscriptions();
    _playerSubscription = playerModule!.onProgress!.listen((e) {
      if (kDebugMode) print('event: ${e.position}');
      maxDuration = e.duration.inMilliseconds.toDouble();
      if (kDebugMode) print('maxDuration: $e');
      if (maxDuration! <= 0) maxDuration = 0.0;
      sliderCurrentPosition =
          min(e.position.inMilliseconds.toDouble(), maxDuration!);
      if (sliderCurrentPosition! < 0.0) {
        sliderCurrentPosition = 0.0;
      }

      DateTime date = DateTime.fromMillisecondsSinceEpoch(
          e.position.inMilliseconds,
          isUtc: true);
//        this.setState(() {
//          this._playerTxt = txt.substring(0, 8);
//        });

      slide = (sliderCurrentPosition! * 100 / maxDuration!) / 100;
      String txt = DateFormat('mm:ss').format(date);
      _playerTxt = txt;
      if (sliderCurrentPosition == maxDuration) {
        sliderCurrentPosition = 0.0;
        slide = 0.0;
        icon = Icons.play_arrow;
        _isPlaying = false;
      }
      if (mounted) setState(() {});
    });
    if (kDebugMode) print(_playerSubscription.runtimeType);
  }

  /// This method start audio player with this file [url]
  startPlayer(String url) async {
    //      if (!await fileExists(url)) {
//        throw new Exception("File not found on url");
//      }
    _isPlaying = true;
    icon = Icons.hourglass_full;
    if (mounted) setState(() {});
    // final mediaFile = await fetchFile(url);
    // final headURL = await hedURL(url);
    // print(headURL.headers["content-type"]);
//    Uint8List mediaStream = (mediaFile).buffer.asUint8List();
//    Uint8List mediaStream = (mediaFile.bodyBytes).buffer.asUint8List();
//     Uint8List dataBuffer = mediaFile.bodyBytes;
//     String? contentType = headURL.headers["content-type"] ?? null;
//     print("loaded file");
    if (kDebugMode) print('startPlayer');
    await playerModule!.startPlayer(
      fromURI: url,
      codec: Codec.defaultCodec,
//      codec: Codec.defaultCodec,
//       fromDataBuffer: dataBuffer,
      whenFinished: () {
        icon = Icons.play_arrow;
        _isPlaying = false;
        if (mounted) setState(() {});
      },
    );
    // await playerModule!.setVolume(1.0);
    icon = Icons.pause;
    _isPlaying = true;
    playerModule!.setSubscriptionDuration(const Duration(minutes: 10));
    await _addListeners();
  }

  /// This method stop audio player
  stopPlayer() async {
    if (!playerModule!.isOpen() || !playerModule!.isPlaying) return;
    await playerModule!.stopPlayer();
    await cancelPlayerSubscriptions();
    await releaseFlauto();
    icon = Icons.play_arrow;
    _isPlaying = false;
  }

  /// This method pause audio player
  pausePlayer() async {
    if (!playerModule!.isOpen()) return;
    await playerModule!.pausePlayer();
    icon = Icons.play_arrow;
    _isPlaying = false;
  }

  /// This method resume audio player
  resumePlayer() async {
    await playerModule!.resumePlayer();
    icon = Icons.pause;
    _isPlaying = true;
  }

  /// This method play and resume audio player with this [url] file
  void playPause(String url) async {
    if (!ready || !mounted) {
      if (kDebugMode) print('not ready');
      return;
    }
    try {
      if (_isPlaying == false &&
          (sliderCurrentPosition == 0.0) &&
          !_isPlaying!) {
        await startPlayer(url);
      } else if (_isPlaying! && (sliderCurrentPosition != maxDuration)) {
        await pausePlayer();
      } else if (!_isPlaying! && (sliderCurrentPosition != maxDuration)) {
        await resumePlayer();
      }
    } catch (error) {
      if (kDebugMode) print(error);
      icon = Icons.play_arrow;
      _isPlaying = false;
      await stopPlayer();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Widget spacer = Container(width: 16);
    if (widget.url == null || playerModule == null) {
      return Text(widget.loadingText);
    }
    final theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    Color cardColor = const Color.fromRGBO(255, 255, 255, 1);

    Widget baseCard = Material(
      clipBehavior: Clip.hardEdge,
      borderRadius: BorderRadius.circular(25),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Flex(
              direction: Axis.horizontal,
              children: <Widget>[
                IconButton(
                  icon: Icon(
                    icon,
                    color: theme.colorScheme.primary,
                  ),
                  iconSize: 30,
                  onPressed: widget.url == null
                      ? null
                      : () async => playPause('${widget.url}'),
                ),
                Expanded(
                  child: RawMaterialButton(
                    child: SizedBox(
                      height: 50,
                      child: LinearProgressIndicator(
                        value: slide,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.primaryColor,
                        ),
                      ),
                    ),
                    onPressed: () {},
                  ),
                ),
                spacer,
                Text(
                  _playerTxt,
                  style: textTheme.caption!.apply(color: Colors.grey.shade700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return WillPopScope(
        child: baseCard,
        onWillPop: () async {
          if (kDebugMode) print('is out -----------');
          return true;
        });
  }
}
