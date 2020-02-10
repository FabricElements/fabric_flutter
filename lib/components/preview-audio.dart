import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:intl/intl.dart' show DateFormat;

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
  FlutterSound flutterSound;
  IconData icon;
  bool _isPlaying;
  double maxDuration;
  StreamSubscription _playerSubscription;
  String _playerTxt;
  double slide;
  double sliderCurrentPosition;

  @override
  void initState() {
    super.initState();
    flutterSound = new FlutterSound();
    icon = Icons.play_arrow;
    _isPlaying = false;
    maxDuration = 1.0;
    _playerTxt = '00:00';
    slide = 0.0;
    sliderCurrentPosition = 0.0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    flutterSound.setSubscriptionDuration(0.01);
    flutterSound.setDbPeakLevelUpdate(0.8);
    flutterSound.setDbLevelEnabled(true);
  }

  @override
  void dispose() {
    try {
      stopPlayer();
    } catch (e) {}
    super.dispose();
  }

  /// This method start audio player with this file [url]
  void startPlayer(String url) async {
    if (!mounted) {
      return;
    }
    await flutterSound.startPlayer(url);
    await flutterSound.setVolume(1.0);
    try {
      _playerSubscription = flutterSound.onPlayerStateChanged.listen((e) {
        if (e != null) {
          sliderCurrentPosition = e.currentPosition;
          maxDuration = e.duration;
          slide = (sliderCurrentPosition * 100 / maxDuration) / 100;
          DateTime date = new DateTime.fromMillisecondsSinceEpoch(
              e.currentPosition.toInt(),
              isUtc: true);
          String txt = DateFormat('mm:ss').format(date);
          _playerTxt = txt;
          if (sliderCurrentPosition == maxDuration) {
            sliderCurrentPosition = 0;
            slide = 0.0;
            icon = Icons.play_arrow;
            this._isPlaying = false;
          }
          if (mounted) {
            setState(() {});
          }
        }
      });
      icon = Icons.pause;
      _isPlaying = true;
    } catch (err) {
      print('error: $err');
    }
  }

  /// This method stop audio player
  void stopPlayer() async {
    try {
      await flutterSound.stopPlayer();
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
    await flutterSound.pausePlayer();
    icon = Icons.play_arrow;
    _isPlaying = false;
  }

  /// This method resume audio player
  void resumePlayer() async {
    await flutterSound.resumePlayer();
    icon = Icons.pause;
    _isPlaying = true;
  }

  /// This method play and resume audio player with this [url] file
  void playPause(String url) async {
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
  }

  @override
  Widget build(BuildContext context) {
    Widget spacer = Container(
      width: 16,
    );
    if (widget.url == null || flutterSound == null) {
      return Text(widget.loadingText);
    }

    final theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    Color cardColor = Color.fromRGBO(255, 255, 255, 1);

    Widget baseCard = Container(
      child: Padding(
        padding: EdgeInsets.all(16),
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
                    onPressed: () => playPause(widget.url),
                  ),
                  Flexible(
                    child: RawMaterialButton(
                      child: SizedBox(
                        height: 24,
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
    return Padding(
      padding: EdgeInsets.all(8),
      child: Container(
        color: cardColor,
        child: baseCard,
      ),
    );
  }
}
