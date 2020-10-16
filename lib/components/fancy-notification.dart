import 'dart:math' as math;

import 'package:fabric_flutter/helpers/state-notifications.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:transparent_image/transparent_image.dart';

class FancyNotification extends StatelessWidget {
  FancyNotification({
    Key key,
    @required this.child,
    this.callback,
    this.labelAction = "GO",
    this.labelDismiss = "DISMISS",
    this.duration,
    this.persistent = false,
    this.backgroundColor,
  }) : super(key: key);
  final Widget child;
  final Function callback;
  final String labelAction;
  final String labelDismiss;
  final Duration duration;
  final bool persistent;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    StateNotifications stateNotifications =
        Provider.of<StateNotifications>(context, listen: false);
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    double smallerSize = math.min(width, height);

    /// Handle notification callback
    Future<void> _handleNotificationPreview(
        Map<dynamic, dynamic> message) async {
      String _path = message["path"] ?? "";
      String _origin = message["origin"] ?? "";
      Widget _title = message.containsKey("title")
          ? Container(
              width: width,
              padding: EdgeInsets.only(bottom: 8, left: 16, right: 16),
              child: Text(
                message["title"],
                style: textTheme.headline5,
                maxLines: 3,
              ),
            )
          : null;
      Widget _body = message.containsKey("body")
          ? Container(
              width: width,
              padding: EdgeInsets.only(bottom: 8, left: 16, right: 16),
              child: Text(
                message["body"],
                style: textTheme.bodyText1,
                maxLines: 3,
              ),
            )
          : null;
      Widget _image = message.containsKey("image")
          ? Container(
              width: width,
              height: smallerSize * 0.4,
              color: Colors.grey.shade900,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: FadeInImage.memoryNetwork(
                  placeholder: kTransparentImage,
                  image: message["image"],
                  fit: BoxFit.cover,
                ),
              ),
            )
          : null;
      List<Widget> _onColumn = [];
      List<Widget> _mainItems = [];

      if (_image != null) {
        _mainItems.add(_image);
      }
      if (_title != null) {
        _onColumn.add(_title);
      }
      if (_body != null) {
        _onColumn.add(_body);
      }
      List<Widget> _actions = [];
      if (_path.isNotEmpty) {
        _actions.add(ElevatedButton.icon(
          label: Text(labelAction),
          icon: Icon(Icons.navigate_next),
          onPressed: () {
//            Scaffold.of(context)
//                .removeCurrentSnackBar(reason: SnackBarClosedReason.dismiss);
//            Navigator.pop(context);
            this.callback(message);
          },
        ));
      }
      _actions.add(OutlinedButton.icon(
        icon: Icon(Icons.close),
        label: Text(labelDismiss),
        onPressed: () {
          Navigator.pop(context);
        },
      ));
      _onColumn.add(Padding(
        padding: EdgeInsets.all(16),
        child: Wrap(
//          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          direction: Axis.horizontal,
          children: _actions,
          spacing: 16,
        ),
      ));
      _mainItems.add(Container(
        width: width,
        padding: EdgeInsets.only(top: 24, bottom: 8),
        child: Wrap(
          children: _onColumn,
          direction: Axis.vertical,
        ),
      ));
      if (_origin == "message") {
        showModalBottomSheet(
          context: context,
          backgroundColor:
              this.backgroundColor ?? theme.bottomSheetTheme.backgroundColor,
          builder: (BuildContext bc) {
            return Wrap(
              children: _mainItems,
              direction: Axis.vertical,
            );
          },
        );
      } else {
        /// redirect without showing alert when it comes from click
        this.callback(message);
      }
    }

    /// Assign notification callback
    stateNotifications.callback = _handleNotificationPreview;

    return this.child;
  }
}
