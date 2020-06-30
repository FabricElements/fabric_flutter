import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data' show Uint8List;
import 'dart:typed_data';

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

Future<http.Response> fetchFile(String url) {
  return http.get(url);
}

/// This a component to preview audio, it loads a url and you can play it within the app.
///
/// [url] The url of the audio file.
/// [loadingText] Locale text to be displayed when loading.
/// AudioPreview(
///   url: mediaUrl,
///   loadingText: "loading...",
/// );
class AudioPreview extends StatefulWidget {
  AudioPreview({
    @required this.url,
    this.loadingText = "loading",
  });

  final String url;
  final String loadingText;

  // TODO: Background color

  @override
  _AudioPreviewState createState() => _AudioPreviewState();
}

class _AudioPreviewState extends State<AudioPreview> {
  IconData icon;
  bool _isPlaying;
  double maxDuration;
  StreamSubscription _playerSubscription;
  String _playerTxt;
  double slide;
  double sliderCurrentPosition;
  FlutterSoundPlayer playerModule;
  bool ready;

  Future<void> init() async {
    //playerModule = await `FlutterSoundPlayer`().openAudioSession();
    if (ready) {
      return;
    }
    try {
      await _initializeExample();
    } catch (error) {}
  }

  @override
  void initState() {
    playerModule = new FlutterSoundPlayer();
    icon = Icons.hourglass_full;
    _isPlaying = false;
    maxDuration = 1.0;
    _playerTxt = '00:00';
    slide = 0.0;
    sliderCurrentPosition = 0.0;
    ready = false;
    super.initState();
    init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
//    playerModule.setSubscriptionDuration(Duration(milliseconds: 10));
//    playerModule.setVolume(0.8);
  }

  cancelPlayerSubscriptions() async {
    if (_playerSubscription != null) {
      await _playerSubscription.cancel();
      _playerSubscription = null;
    }
  }

  Future<void> releaseFlauto() async {
    try {
      await playerModule.closeAudioSession();
    } catch (e) {
      print('Released unsuccessful');
      print(e);
    }
  }

  @override
  void dispose() {
    super.dispose();
    try {
      stopPlayer();
      releaseFlauto();
    } catch (error) {
      print(error);
    }
  }

  Future<void> _initializeExample() async {
    await releaseFlauto();
    await playerModule.openAudioSession(
        focus: AudioFocus.requestFocusTransientExclusive,
        category: SessionCategory.playback,
        mode: SessionMode.modeDefault,
        audioFlags: outputToSpeaker,
        device: AudioDevice.speaker);
    await playerModule.setSubscriptionDuration(Duration(seconds: 60));
    initializeDateFormatting();
    ready = true;
    icon = Icons.play_arrow;
    if (mounted) setState(() {});
  }

  Future<bool> fileExists(String path) async {
    return await File(path).exists();
  }

  _addListeners() async {
    if (_playerSubscription != null) {
      return;
    }
    try {
//      await cancelPlayerSubscriptions();
      _playerSubscription = playerModule.onProgress.listen((e) {
        print("event ${e.position}");
        if (e != null) {
          maxDuration = e.duration.inMilliseconds.toDouble();
          if (maxDuration <= 0) maxDuration = 0.0;

          sliderCurrentPosition =
              min(e.position.inMilliseconds.toDouble(), maxDuration);
          if (sliderCurrentPosition < 0.0) {
            sliderCurrentPosition = 0.0;
          }

          DateTime date = new DateTime.fromMillisecondsSinceEpoch(
              e.position.inMilliseconds,
              isUtc: true);
//        this.setState(() {
//          this._playerTxt = txt.substring(0, 8);
//        });

          slide = (sliderCurrentPosition * 100 / maxDuration) / 100;
          String txt = DateFormat('mm:ss').format(date);
          _playerTxt = txt;
          if (sliderCurrentPosition == maxDuration) {
            sliderCurrentPosition = 0.0;
            slide = 0.0;
            icon = Icons.play_arrow;
            _isPlaying = false;
          }
          if (mounted) setState(() {});
        }
      });
    } catch (error) {
      print("subscription error: $error");
    }
  }

  /// This method start audio player with this file [url]
  startPlayer(String url) async {
    //      if (!await fileExists(url)) {
//        throw new Exception("File not found on url");
//      }
    _isPlaying = true;
    icon = Icons.hourglass_full;
    if (mounted) setState(() {});
    final mediaFile = await fetchFile(url);
//    Uint8List mediaStream = (mediaFile).buffer.asUint8List();
//    Uint8List mediaStream = (mediaFile.bodyBytes).buffer.asUint8List();
    Uint8List dataBuffer = mediaFile.bodyBytes;
    String contentType = mediaFile.headers["content-type"] ?? null;
    print("content-type: $contentType");
    print("loaded file");
    await playerModule.startPlayer(
//        fromURI: url,
//      codec: Codec.defaultCodec,
      fromDataBuffer: dataBuffer,
      whenFinished: () {
        print('Play finished');
        setState(() {});
      },
    );
    await playerModule.setVolume(1.0);
    icon = Icons.pause;
    _isPlaying = true;
    await _addListeners();
    print('startPlayer');
  }

  /// This method stop audio player
  stopPlayer() async {
    await playerModule.stopPlayer();
    await cancelPlayerSubscriptions();
    icon = Icons.play_arrow;
    _isPlaying = false;
  }

  /// This method pause audio player
  pausePlayer() async {
    await playerModule.pausePlayer();
    icon = Icons.play_arrow;
    _isPlaying = false;
  }

  /// This method resume audio player
  resumePlayer() async {
    await playerModule.resumePlayer();
    icon = Icons.pause;
    _isPlaying = true;
  }

  /// This method play and resume audio player with this [url] file
  void playPause(String url) async {
    if (!ready || !mounted) {
      print("not ready");
      return;
    }
    try {
      if (_isPlaying == false &&
          (sliderCurrentPosition == 0.0) &&
          !_isPlaying) {
        await startPlayer(url);
      } else if (_isPlaying && (sliderCurrentPosition != maxDuration)) {
        await pausePlayer();
      } else if (!_isPlaying && (sliderCurrentPosition != maxDuration)) {
        await resumePlayer();
      }
    } catch (error) {
      print(error);
      icon = Icons.play_arrow;
      _isPlaying = false;
      try {
        await stopPlayer();
        await releaseFlauto();
      } catch (error) {
        print(error);
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Widget spacer = Container(
      width: 16,
    );
    if (widget.url == null || playerModule == null) {
      return Text(widget.loadingText);
    }
    final theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    Color cardColor = Color.fromRGBO(255, 255, 255, 1);

    Widget baseCard = Material(
      clipBehavior: Clip.hardEdge,
      borderRadius: BorderRadius.circular(25),
      color: cardColor,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              child: Flex(
                direction: Axis.horizontal,
                children: <Widget>[
                  IconButton(
                    icon: Icon(
                      icon,
                      color: theme.accentColor,
                    ),
                    iconSize: 30,
                    onPressed: () async => playPause(widget.url),
                  ),
                  Expanded(
                    child: RawMaterialButton(
                      child: SizedBox(
                        height: 50,
                        child: LinearProgressIndicator(
                          value: slide,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.accentColor,
                          ),
                        ),
                      ),
                      onPressed: () {},
                    ),
                  ),
                  spacer,
                  Text(
                    _playerTxt,
                    style: textTheme.caption.apply(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return baseCard;
  }
}
