import 'package:flutter/material.dart';

import '../component/smart_image.dart';
import 'app_localizations_delegate.dart';
import 'redirect_app.dart';

/// This is an alert class, depending on the type of alert wanted a snackbar will be displayed.
/// Alert(
///   context: context,
///   mounted: mounted,
/// ).show(
///   text: "Something went wrong...",
///   type: "error",
/// );
class Alert {
  const Alert({
    required this.context,
    this.globalContext,
    required this.mounted,
  });

  final BuildContext context;
  final BuildContext? globalContext;
  final bool mounted;

  Future<void> show({
    required String title,
    String? body, // notification body message
    int duration = 3,
    String? type, // null, "error", "success"
    String? widget, // null, "fancy"
    String? path, // path to redirect
    String? origin, // notification origin
    String? image, // image URL
    Map<String, dynamic>? arguments, // redirect arguments
  }) async {
    if (!mounted) {
      print("Called Alert when unmounted");
      return;
    }
    AppLocalizations locales = AppLocalizations.of(context)!;
    ThemeData theme = Theme.of(context);
    TextTheme textTheme = theme.textTheme;
    RedirectApp redirectApp =
        RedirectApp(context: context, protected: ["/protected"]);
    await Future.delayed(Duration(microseconds: 200));
    BuildContext parentContext = globalContext ?? context;
    // print("--------- parentContext: ${parentContext}");
    ScaffoldMessenger.of(context).clearSnackBars();
    Color color;
    switch (type) {
      case "error":
        color = Colors.red.shade500;
        duration = duration != 3 ? duration : 6;
        print("////////// Alert: Error ///////////");
        print(title);
        print("///////////////////////////////////");
        break;
      case "success":
        color = Colors.green.shade500;
        break;
      default:
        color = Colors.grey.shade800;
        if (widget == "fancy") {
          color = theme.bottomSheetTheme.backgroundColor ?? Colors.white;
        }
    }
    final _duration = Duration(seconds: duration);
    void _fancy() {
      Widget? _title = Container(
        // width: width,
        padding: EdgeInsets.only(bottom: 8, left: 16, right: 16),
        child: Text(
          title,
          style: textTheme.headline5,
          maxLines: 3,
        ),
      );
      Widget? _body = body != null
          ? Container(
              // width: width,
              padding: EdgeInsets.only(bottom: 8, left: 16, right: 16),
              child: Text(
                body,
                style: textTheme.bodyText1,
                maxLines: 3,
              ),
            )
          : null;
      Widget? _image = image != null
          ? Container(
              // width: width,
              // height: smallerSize * 0.4,
              color: Colors.grey.shade900,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: SmartImage(url: image),
              ),
            )
          : null;
      List<Widget> _onColumn = [];
      List<Widget> _mainItems = [];

      if (_image != null) {
        _mainItems.add(_image);
      }
      _onColumn.add(_title);
      if (_body != null) {
        _onColumn.add(_body);
      }
      List<Widget> _actions = [];
      if (path != null && path.isNotEmpty) {
        _actions.add(ElevatedButton.icon(
          label: Text(locales.get("label--open")),
          icon: Icon(Icons.navigate_next),
          onPressed: () {
            redirectApp.toView(
              path: path,
              arguments: arguments,
            );
            Navigator.of(parentContext, rootNavigator: true).pop();
          },
        ));
      }
      _actions.add(OutlinedButton.icon(
        icon: Icon(Icons.close),
        label: Text(locales.get("label--dismiss")),
        onPressed: () {
          Navigator.of(parentContext, rootNavigator: true).pop();
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
        // width: width,
        padding: EdgeInsets.only(top: 24, bottom: 8),
        child: Wrap(
          children: _onColumn,
          direction: Axis.vertical,
        ),
      ));
      // ScaffoldMessenger.of(context).clearSnackBars();
      if (origin == "message") {
        // Scaffold.of(context).showBottomSheet(
        //   (context) => BottomSheet(
        //     // context: context,
        //     backgroundColor: color,
        //     // backgroundColor:
        //     //     this.backgroundColor ?? theme.bottomSheetTheme.backgroundColor,
        //     builder: (BuildContext bc) {
        //       return Wrap(
        //         children: _mainItems,
        //         direction: Axis.vertical,
        //       );
        //     },
        //     onClosing: () {},
        //   ),
        // );

        showModalBottomSheet(
          context: parentContext,
          // context: context,
          backgroundColor: color,
          builder: (BuildContext bc) {
            return Wrap(
              children: _mainItems,
              direction: Axis.vertical,
            );
          },
        );
      }
    }

    void defaultAlert() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(title),
          duration: _duration,
          backgroundColor: color,
        ),
      );
    }

    try {
      switch (widget) {
        case "fancy":
          _fancy();
          break;
        default:
          defaultAlert();
      }
    } catch (error) {
      print("/////////////////////");
      print(error);
      print("/////////////////////");
    }
  }
}
