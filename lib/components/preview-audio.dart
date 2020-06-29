import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:path_provider/path_provider.dart';

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
  Media _media = Media.file;
  Codec _codec = Codec.aacADTS;
  bool _encoderSupported = true; // Optimist
  bool _decoderSupported = true; // Optimist
  FlutterSoundPlayer playerModule = FlutterSoundPlayer();

  Future<void> init() async {
    //playerModule = await `FlutterSoundPlayer`().openAudioSession();
    await _initializeExample();

    if (Platform.isAndroid) {
//      copyAssets();
    }
  }

  @override
  void initState() {
    super.initState();
//    flutterSoundPlayer = new FlutterSoundPlayer();
    icon = Icons.play_arrow;
    _isPlaying = false;
    maxDuration = 1.0;
    _playerTxt = '00:00';
    slide = 0.0;
    sliderCurrentPosition = 0.0;
    init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
//    playerModule.setSubscriptionDuration(Duration(milliseconds: 10));
//    playerModule.setVolume(0.8);
  }

  void cancelPlayerSubscriptions() {
    if (_playerSubscription != null) {
      _playerSubscription.cancel();
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
    try {
      stopPlayer();
      releaseFlauto();
    } catch (e) {}
    super.dispose();
  }


  Future<void> _initializeExample() async {
    await playerModule.closeAudioSession();
    await playerModule.openAudioSession(
        focus: AudioFocus.requestFocusTransient,
        category: SessionCategory.playAndRecord,
        mode: SessionMode.modeDefault,
        audioFlags: outputToSpeaker,
        device: AudioDevice.speaker);
    await playerModule.setSubscriptionDuration(Duration(milliseconds: 10));
    initializeDateFormatting();
  }

  Future<bool> fileExists(String path) async {
    return await File(path).exists();
  }

  // In this simple example, we just load a file in memory.This is stupid but just for demonstration  of startPlayerFromBuffer()
  Future<Uint8List> makeBuffer(String path) async {
    try {
      if (!await fileExists(path)) return null;
      File file = File(path);
      file.openRead();
      var contents = await file.readAsBytes();
      print('The file is ${contents.length} bytes long.');
      return contents;
    } catch (e) {
      print(e);
      return null;
    }
  }

  void _addListeners() {
    cancelPlayerSubscriptions();
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
        String txt = DateFormat('mm:ss:SS', 'en_GB').format(date);
        this.setState(() {
          this._playerTxt = txt.substring(0, 8);
        });
      }
    });
  }


  /// This method start audio player with this file [url]
  void startPlayer(String url) async {
    if (!mounted) {
      return;
    }
    //String path;
    Uint8List dataBuffer;
    String audioFilePath;

    try {
//      if (!await fileExists(url)) {
//        throw new Exception("File not found on url");
//      }
      await playerModule.startPlayer(fromURI: url, whenFinished: () {
        print('Play finished');
        setState(() {});
      });
      await playerModule.setVolume(1.0);

//      _playerSubscription = playerModule.onProgress.listen((e) {
//        print(e);
//        if (e != null) {
//          sliderCurrentPosition = e.position.inMilliseconds.toDouble();
//          maxDuration = e.duration.inMilliseconds.toDouble();
//          slide = (sliderCurrentPosition * 100 / maxDuration) / 100;
//          DateTime date = new DateTime.fromMillisecondsSinceEpoch(
//              e.position.inMilliseconds.toInt(),
//              isUtc: true);
//          String txt = DateFormat('mm:ss').format(date);
//          _playerTxt = txt;
//          if (sliderCurrentPosition == maxDuration) {
//            sliderCurrentPosition = 0;
//            slide = 0.0;
//            icon = Icons.play_arrow;
//            this._isPlaying = false;
//          }
//          if (mounted) {
//            setState(() {});
//          }
//        }
//      });
      icon = Icons.pause;
      _isPlaying = true;
      _addListeners();
      print('startPlayer');
    } catch (err) {
      print('error: $err');
    }
  }

  /// This method stop audio player
  void stopPlayer() async {
    try {
      await playerModule.stopPlayer();
      if (_playerSubscription != null) {
        _playerSubscription.cancel();
        _playerSubscription = null;
      }
      icon = Icons.play_arrow;
      this._isPlaying = false;
      if (mounted) {
        setState(() {});
      }
    } catch (error) {}
  }

  /// This method pause audio player
  void pausePlayer() async {
    await playerModule.pausePlayer();
    icon = Icons.play_arrow;
    _isPlaying = false;
  }

  /// This method resume audio player
  void resumePlayer() async {
    await playerModule.resumePlayer();
    icon = Icons.pause;
    _isPlaying = true;
  }

  /// This method play and resume audio player with this [url] file
  void playPause(String url) async {
    try {
      if (_isPlaying == false && (sliderCurrentPosition == 0)) {
        startPlayer(url);
      } else if (_isPlaying && (sliderCurrentPosition != maxDuration)) {
        pausePlayer();
      } else if ((_isPlaying == false) &&
          (sliderCurrentPosition != maxDuration)) {
        resumePlayer();
      }
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      print(error);
    }

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
