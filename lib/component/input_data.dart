import 'package:fabric_flutter/component/user_avatar.dart';
import 'package:fabric_flutter/component/voice_dictation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:omni_datetime_picker/omni_datetime_picker.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/enum_data.dart';
import '../helper/gsm.dart';
import '../helper/input_validation.dart';
import '../helper/log_color.dart';
import '../helper/options.dart';
import '../helper/utils.dart';
import 'alert_data.dart';

/// Defines the value representations supported by [InputData].
enum InputDataType {
  /// Edits a calendar date without a time component.
  date,

  /// Edits a [TimeOfDay] value without an associated date.
  time,

  /// Edits a full date and time value.
  dateTime,

  /// Edits a timestamp value that is serialized as a [DateTime].
  timestamp,

  /// Edits an email address with email-aware keyboard and validation behavior.
  email,

  /// Edits a signed integer value.
  int,

  /// Edits a floating-point number.
  double,

  /// Edits a numeric value intended to represent currency.
  currency,

  /// Edits a numeric value intended to represent a percentage.
  percent,

  /// Edits long-form multiline text.
  text,

  /// Selects from a Dart [Enum] list.
  enums,

  /// Selects from a caller-provided [ButtonOptions] list.
  dropdown,

  /// Edits a short free-form string.
  string,

  /// Selects one option from a radio-button group.
  radio,

  /// Edits a phone number using phone-friendly formatting rules.
  phone,

  /// Edits secret text, typically passwords or tokens.
  secret,

  /// Edits a URL with URL-aware keyboard and validation behavior.
  url,

  /// Edits a boolean value using a switch control.
  bool,
}

/// Returns a sensible default icon for the supplied [InputDataType].
///
/// This keeps field affordances visually consistent even when callers do not provide a
/// custom prefix icon for date pickers, dropdowns, or other specialized inputs.
IconData inputDataTypeIcon(InputDataType inputDataType) {
  late IconData icon;
  switch (inputDataType) {
    case InputDataType.date:
      icon = Icons.calendar_month;
      break;
    case InputDataType.dateTime:
      icon = Icons.date_range;
      break;
    case InputDataType.timestamp:
      icon = Icons.access_time;
      break;
    case InputDataType.time:
      icon = Icons.access_time;
      break;
    case InputDataType.email:
      icon = Icons.email;
      break;
    case InputDataType.int:
      icon = Icons.pin;
      break;
    case InputDataType.double:
      icon = Icons.numbers;
      break;
    case InputDataType.currency:
      icon = Icons.attach_money;
      break;
    case InputDataType.percent:
      icon = Icons.percent;
      break;
    case InputDataType.text:
      icon = Icons.short_text;
      break;
    case InputDataType.enums:
      icon = Icons.list;
      break;
    case InputDataType.dropdown:
      icon = Icons.list;
      break;
    case InputDataType.string:
      icon = Icons.text_fields;
      break;
    case InputDataType.radio:
      icon = Icons.radio_button_checked;
      break;
    case InputDataType.phone:
      icon = Icons.phone;
      break;
    case InputDataType.secret:
      icon = Icons.security;
      break;
    case InputDataType.url:
      icon = Icons.link;
      break;
    case InputDataType.bool:
      icon = Icons.toggle_off_outlined;
      break;
  }
  return icon;
}

/// Converts a raw value into the runtime type expected by [InputDataType].
///
/// The helper mirrors the widget's internal normalization rules so callers can prepare
/// external values consistently, especially for nullable numbers, phone inputs, dates,
/// and enum-backed fields before those values re-enter the widget tree.
dynamic parseValueByInputDataType({
  required InputDataType type,
  required dynamic value,
  enums = const [],
}) {
  if (value == null) return null;
  dynamic baseValueAsString = value?.toString();
  if (baseValueAsString.isEmpty) return null;
  dynamic newValue;
  // Use [baseValue] to parse the value with the correct type similar to [InputData.getValue]
  switch (type) {
    case InputDataType.double:
    case InputDataType.currency:
    case InputDataType.percent:
      if (baseValueAsString.endsWith('.')) {
        baseValueAsString = baseValueAsString.replaceAll('.', '');
      }
      newValue = double.tryParse(baseValueAsString);
      break;
    case InputDataType.int:
      newValue = int.tryParse(baseValueAsString);
      break;
    case InputDataType.phone:
      // only accept digits
      String onlyNumbers = baseValueAsString
          .replaceAll(RegExp(r'\D'), '')
          .replaceAll(RegExp(r'\+'), '');
      // Add plus sign at the beginning if it's missing
      newValue = onlyNumbers.isEmpty ? null : '+$onlyNumbers';
      break;
    // add missing cases
    case InputDataType.date:
    case InputDataType.dateTime:
    case InputDataType.timestamp:
      newValue = DateTime.tryParse(baseValueAsString);
      break;
    case InputDataType.time:
      final timeBase = DateTime.tryParse(baseValueAsString);
      newValue = timeBase != null ? TimeOfDay.fromDateTime(timeBase) : null;
      break;
    case InputDataType.enums:
      newValue = EnumData.find(enums: enums, value: value);
      break;
    case InputDataType.dropdown:
      newValue = value;
      break;
    case InputDataType.bool:
      if (value is bool) {
        newValue = value;
      } else {
        newValue = bool.tryParse(baseValueAsString);
      }
      break;
    case InputDataType.text:
    case InputDataType.email:
    case InputDataType.secret:
    case InputDataType.url:
    case InputDataType.string:
      newValue = baseValueAsString;
      break;
    case InputDataType.radio:
      newValue = value;
  }

  return newValue;
}

/// Presents a single adaptive input widget for many common value types.
///
/// [InputData] centralizes controller management, parsing, validation, and specialized
/// picker behavior so forms can switch between text, dates, enums, booleans, and other
/// field types without reimplementing the same lifecycle glue in every screen.
class InputData extends StatefulWidget {
  /// Creates an adaptive field seeded with [value] and configured by [type].
  ///
  /// The constructor exposes type-specific configuration such as enum lists, dropdown
  /// options, controllers, validation, and picker behavior without forcing callers to
  /// manage separate widgets for each input style.
  const InputData({
    super.key,
    required this.value,
    required this.type,
    this.enums = const [],
    this.options = const [],
    this.onChanged,
    this.onSubmit,
    this.onComplete,
    this.disabled = false,
    this.hintText,
    this.isDense = false,
    this.maxLength,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.margin = EdgeInsets.zero,
    this.utcOffset,
    this.validator,
    this.backgroundColor,
    this.error,
    this.textStyle,
    this.obscureText = false,
    this.label,
    this.textInputAction,
    this.autocorrect = false,
    this.autofocus = false,
    this.textController,
    this.autofillHints,
    this.suffix,
    this.suffixText,
    this.suffixIcon,
    this.suffixStyle,
    this.prefix,
    this.prefixText,
    this.prefixIcon,
    this.prefixStyle,
    this.floatingLabelBehavior,
    this.searchController,
    this.asLocalTime = false,
    this.enableInteractiveSelection,
    this.inputFormatters = const [],
    this.keyboardType,
    this.semanticsLabel,
    this.automationKey,
    this.semanticHint,
  });

  /// Supplies the current value rendered by the field and its internal controllers.
  final dynamic value;

  /// Lists the enum values that can be selected when [type] is [InputDataType.enums].
  final List<Enum> enums;

  /// Lists selectable options for dropdown and radio-style input types.
  final List<ButtonOptions> options;

  /// Chooses which editor, parser, and validation rules the widget should apply.
  final InputDataType type;

  /// Makes the field read-only while still allowing selection or copy affordances.
  final bool disabled;

  /// Overrides the placeholder shown when the field has no visible value.
  final String? hintText;

  /// Limits how many characters the text-based editor will accept.
  final int? maxLength;

  /// Requests a denser visual layout than the surrounding theme default.
  final bool isDense;

  /// Overrides the internal content padding applied by the generated [InputDecoration].
  final EdgeInsets padding;

  /// Wraps the field with outer spacing so forms can align adjacent inputs cleanly.
  final EdgeInsets margin;

  /// Adjusts serialized date values when the caller stores a non-local UTC offset.
  final int? utcOffset;

  /// Adds custom validation on top of the built-in type-aware normalization rules.
  final FormFieldValidator<String>? validator;

  /// Overrides the filled background color used by the generated input decoration.
  final Color? backgroundColor;

  /// Shows an external error message without requiring a surrounding [Form].
  final String? error;

  /// Provides a custom text style for widgets that read it from the field configuration.
  final TextStyle? textStyle;

  /// Starts text inputs in obscured mode before local visibility toggles are applied.
  final bool obscureText;

  /// Supplies the label rendered by the generated [InputDecoration].
  final String? label;

  /// Overrides the keyboard action button for text-based field variants.
  final TextInputAction? textInputAction;

  /// Enables platform autocorrect for text-entry variants that should support it.
  final bool autocorrect;

  /// Requests focus for the field as soon as it enters the tree.
  final bool autofocus;

  /// Reuses an external [TextEditingController] when the parent needs direct access.
  final TextEditingController? textController;

  /// Forwards platform autofill hints to compatible text-based editors.
  final Iterable<String>? autofillHints;

  // Custom suffix and prefix
  /// Injects a custom suffix widget after the editable region.
  final Widget? suffix;

  /// Replaces the default trailing icon, including clear and visibility controls.
  final Widget? suffixIcon;

  /// Appends non-interactive trailing text inside the input decoration.
  final String? suffixText;

  /// Prepends non-interactive leading text inside the input decoration.
  final String? prefixText;

  /// Injects a custom prefix widget before the editable region.
  final Widget? prefix;

  /// Replaces the default leading icon shown for specialized field types.
  final Widget? prefixIcon;

  /// Styles [prefixText] when a textual prefix is displayed.
  final TextStyle? prefixStyle;

  /// Styles [suffixText] when trailing helper text is displayed.
  final TextStyle? suffixStyle;

  /// Runs when the field is submitted and receives the normalized current value.
  ///
  /// The callback is invoked after the widget has applied its type-specific parsing so the
  /// parent does not need to repeat number, enum, or phone normalization.
  final ValueChanged<dynamic>? onSubmit;

  /// Runs when editing is completed and receives the normalized current value.
  ///
  /// This is useful for flows that need to react once input focus or picker interaction has
  /// settled, rather than on every intermediate character change.
  final ValueChanged<dynamic>? onComplete;

  /// Runs whenever the field value changes and receives the normalized new value.
  ///
  /// The widget uses this as its primary outward data channel, so callers can safely store
  /// the result without re-parsing it based on [type].
  final ValueChanged<dynamic>? onChanged;

  /// {@template flutter.material.inputDecoration.floatingLabelBehavior}
  /// Defines **how** the floating label should behave.
  ///
  /// When [FloatingLabelBehavior.auto] the label will float to the top only when
  /// the field is focused or has some text content, otherwise it will appear
  /// in the field in place of the content.
  ///
  /// When [FloatingLabelBehavior.always] the label will always float at the top
  /// of the field above the content.
  ///
  /// When [FloatingLabelBehavior.never] the label will always appear in an empty
  /// field in place of the content.
  /// {@endtemplate}
  ///
  /// If null, [InputDecorationTheme.floatingLabelBehavior] will be used.
  ///
  /// See also:
  ///
  ///  * [floatingLabelAlignment] which defines **where** the floating label
  ///    should be displayed.
  final FloatingLabelBehavior? floatingLabelBehavior;

  /// Provides an optional [SearchController] that can open and close the search view.
  ///
  /// If this is `null`, the widget creates an internal controller and uses it when the
  /// user taps the anchor field for dropdown and enum selections.
  final SearchController? searchController;

  /// Chooses whether date and time values are displayed in local time instead of UTC.
  ///
  /// This matters when values are persisted in UTC but should be edited in the user's local
  /// time zone without losing round-trip consistency.
  final bool asLocalTime;

  /// Overrides whether users can select and copy text from text-based field variants.
  final bool? enableInteractiveSelection;

  /// Appends custom formatters after the widget's built-in type-specific formatters.
  final List<TextInputFormatter> inputFormatters;

  /// Overrides the [TextInputType] used by text-based field variants.
  ///
  /// This lets callers replace the widget's built-in keyboard choice when a specialized
  /// input still needs a different platform keyboard layout.
  final TextInputType? keyboardType;

  /// Overrides the label exposed to accessibility tools and autonomous agents.
  ///
  /// Falls back to [label] when `null`. When both are `null`, the [Semantics]
  /// node is created without a label, which is acceptable when the field is
  /// paired with a visible external label in the surrounding UI.
  final String? semanticsLabel;

  /// Assigns a deterministic identifier to the semantics node.
  ///
  /// Use a value following the `[RouteName]_[ContextBlock]_[ComponentType]_[ActionOrId]`
  /// naming convention. Maps to [Semantics.identifier] in the accessibility tree.
  final String? automationKey;

  /// Provides structural, non-visual instructions to autonomous agents.
  ///
  /// Maps to [Semantics.hint] in the accessibility tree.
  final String? semanticHint;

  /// Creates the state that owns controllers, picker state, and normalized values.
  @override
  State<InputData> createState() => _InputDataState();
}

/// Synchronizes controllers, parsed values, and specialized picker interactions.
class _InputDataState extends State<InputData> {
  /// Owns the editable text for text-based variants when no external controller is used.
  late TextEditingController textController;

  /// Opens and closes the search view used by dropdown and enum pickers.
  late SearchController searchController;

  /// Formats date-only values for display inside read-only picker fields.
  DateFormat formatDate = DateFormat.yMd('en_US');

  /// Formats date-time values for display after picker selections are normalized.
  DateFormat formatDateTime = DateFormat.yMd(
    'en_US',
  ).addPattern(' - ').add_jm();

  /// Stores an internally generated prefix, such as the `+` used for phone fields.
  String? prefixText;

  /// Holds the normalized current value used across the widget's different editors.
  dynamic value;

  /// Tracks whether text should currently be visually obscured.
  late bool obscureText;

  /// Records whether the current field type supports a visibility toggle.
  late bool obscure;

  /// Normalizes raw editor output into the canonical value shape for the current type.
  dynamic valueChanged(dynamic valueLocal) {
    if (valueLocal == null) return null;
    String valueLocalString = valueLocal!.toString();
    if (valueLocalString.isEmpty) return null;
    switch (widget.type) {
      case InputDataType.double:
      case InputDataType.currency:
      case InputDataType.percent:
        if (valueLocalString.endsWith('.')) {
          valueLocalString = valueLocalString.replaceAll('.', '');
        }
        return double.tryParse(valueLocalString);
      case InputDataType.int:
        return int.tryParse(valueLocalString);
      case InputDataType.phone:
        // only accept digits
        String onlyNumbers = valueLocalString
            .replaceAll(RegExp(r'\D'), '')
            .replaceAll(RegExp(r'\+'), '');
        // Add plus sign at the beginning
        return '+$onlyNumbers';
      default:
        return valueLocal;
    }
  }

  /// Synchronizes controllers and local state from a newly provided external [value].
  ///
  /// This method is reused during initialization and widget updates so text controllers,
  /// dropdown labels, and picker values always reflect the most recent parent state.
  void getValue({bool notify = false, required dynamic newValue}) {
    try {
      switch (widget.type) {
        case InputDataType.currency:
        case InputDataType.percent:
        case InputDataType.double:
        case InputDataType.int:
        case InputDataType.string:
        case InputDataType.text:
        case InputDataType.email:
        case InputDataType.secret:
        case InputDataType.url:
          dynamic newFormattedValue = valueChanged(newValue)?.toString() ?? '';
          bool sameValue = value == newFormattedValue;
          if (!sameValue) {
            value = newFormattedValue;
            textController.text = value;
            if (notify && mounted) setState(() {});
          }
          break;
        case InputDataType.phone:
          dynamic newFormattedValue = valueChanged(newValue)?.toString() ?? '';
          // remove plus sign to avoid double plus sign on the input
          final valueWithoutPlusSign = newFormattedValue.replaceAll(
            RegExp(r'\+'),
            '',
          );
          bool sameValue = value == newFormattedValue;
          if (!sameValue) {
            value = newFormattedValue;
            textController.text = valueWithoutPlusSign;
            if (notify && mounted) setState(() {});
          }
          break;
        case InputDataType.date:
        case InputDataType.dateTime:
        case InputDataType.timestamp:
          DateTime? baseValue = newValue != null ? newValue as DateTime : null;
          if (baseValue != null && widget.utcOffset != null) {
            baseValue = Utils.dateTimeOffset(
              dateTime: baseValue,
              utcOffset: widget.utcOffset,
            );
          }
          // Set the text
          baseValue = widget.asLocalTime
              ? baseValue?.toLocal()
              : baseValue?.toUtc();
          if (baseValue != null) {
            if (widget.type == InputDataType.date) {
              textController.text = formatDate.format(baseValue);
            } else {
              textController.text = formatDateTime.format(baseValue);
            }
          } else {
            textController.text = '';
          }
          // Set the value
          value = baseValue;

          if (notify && mounted) setState(() {});
          break;
        case InputDataType.time:
          value = newValue as TimeOfDay?;
          if (notify && mounted) setState(() {});
          break;
        case InputDataType.enums:
          value = EnumData.find(enums: widget.enums, value: newValue);
          dynamic newFormattedValue = valueChanged(newValue)?.toString() ?? '';
          bool sameValue = value == newFormattedValue;
          if (!sameValue) {
            value = newFormattedValue;
            if (notify && mounted) setState(() {});
          }
          break;
        case InputDataType.dropdown:
          final optionMatch = widget.options.where((item) {
            return item.value == newValue;
          });
          bool valueInOptions = optionMatch.isNotEmpty;
          if (valueInOptions) {
            value = newValue;
          } else {
            value = null;
          }
          dynamic newFormattedValue = valueChanged(newValue)?.toString() ?? '';
          bool sameValue = value == newFormattedValue;
          if (!sameValue) {
            value = newFormattedValue;
            textController.text = valueInOptions ? optionMatch.first.label : '';
            if (notify && mounted) setState(() {});
          }
          break;
        case InputDataType.bool:
          bool baseValue = false;
          if (newValue == null) {
            baseValue = false;
          } else if (newValue.runtimeType == bool) {
            baseValue = newValue;
          } else {
            String valueAsString = newValue.toString().toLowerCase();
            if (valueAsString.isNotEmpty) {
              baseValue = valueAsString == 'true' || valueAsString == '1';
            }
          }
          value = baseValue;
          textController.text = '';
          if (notify && mounted) setState(() {});
          break;
        case InputDataType.radio:
          value = newValue;
          if (notify && mounted) setState(() {});
          break;
      }
    } catch (e) {
      debugPrint(
        LogColor.error('''
----------------------------------------------
getValue -------------------------------------
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
'''),
      );
      rethrow;
    }
  }

  /// Validates configuration and initializes controllers when the widget is inserted.
  @override
  void initState() {
    super.initState();

    // Validate required parameters on init.
    switch (widget.type) {
      case InputDataType.enums:
        assert(
          widget.enums.isNotEmpty,
          'enums is required for InputDataType.enums',
        );
        break;
      case InputDataType.dropdown:
        if (widget.options.isEmpty) {
          debugPrint('options is required for InputDataType.dropdown');
        }
        break;
      default:
    }
    textController = widget.textController ?? TextEditingController();
    searchController = widget.searchController ?? SearchController();

    // Configure obscured text state and related controls.
    obscureText = widget.obscureText;
    if (widget.type == InputDataType.secret) obscureText = true;
    obscure = obscureText;

    // Seed local state from the incoming widget value.
    getValue(newValue: widget.value);
  }

  /// Closes the dropdown search view and clears any transient query text.
  void _closeSearch() {
    try {
      searchController.clear();
      if (searchController.isOpen) searchController.closeView(null);
    } catch (e) {
      // Do nothing
    }
  }

  /// Clears the outward value by notifying listeners with `null`.
  void _clear() {
    widget.onChanged?.call(null);
    widget.onComplete?.call(null);
    widget.onSubmit?.call(null);
  }

  /// Reapplies the incoming value whenever the parent rebuilds with new field data.
  @override
  void didUpdateWidget(covariant InputData oldWidget) {
    super.didUpdateWidget(oldWidget);
    getValue(notify: false, newValue: widget.value);
  }

  /// Releases any internally owned controllers when the widget leaves the tree.
  @override
  void dispose() {
    _closeSearch();
    try {
      textController.dispose();
      // Dispose the search controller if it's not attached to the widget
      if (widget.searchController == null && searchController.isAttached) {
        searchController.dispose();
      }
    } catch (e) {
      // Do nothing
    }
    super.dispose();
  }

  /// Resolves the semantic label exposed to accessibility tools.
  ///
  /// Returns [InputData.semanticsLabel] when explicitly set. Falls back to
  /// [InputData.label] and then, when both are `null`, to a localized type name
  /// derived from [locales] so the semantics tree always carries a meaningful
  /// description.
  String? _resolveSemanticLabel(AppLocalizations locales) {
    if (widget.semanticsLabel != null) return widget.semanticsLabel;
    if (widget.label != null) return widget.label;
    switch (widget.type) {
      case InputDataType.email:
        return locales.get('label--email');
      case InputDataType.phone:
        return locales.get('label--phone-number');
      case InputDataType.url:
        return locales.get('label--url');
      case InputDataType.secret:
        return locales.get('label--password');
      case InputDataType.date:
        return locales.get('label--date');
      case InputDataType.dateTime:
      case InputDataType.timestamp:
        return '${locales.get('label--date')} & ${locales.get('label--time')}';
      case InputDataType.time:
        return locales.get('label--time');
      case InputDataType.text:
        return locales.get('label--text');
      default:
        return null;
    }
  }

  /// Generates a deterministic automation key when none is explicitly provided.
  ///
  /// Returns [InputData.automationKey] unchanged when set. Otherwise constructs
  /// an identifier following the `[RouteName]_[ContextBlock]_input_[type]`
  /// naming convention by reading the ambient [ModalRoute] name and deriving a
  /// context block from [InputData.label] or [InputData.type].
  String? _resolveAutomationKey(BuildContext context) {
    if (widget.automationKey != null) return widget.automationKey;
    final rawRoute = ModalRoute.of(context)?.settings.name;
    final String routeSegment;
    if (rawRoute == null || rawRoute.isEmpty) {
      routeSegment = 'app';
    } else if (rawRoute == '/') {
      routeSegment = 'root';
    } else {
      routeSegment = rawRoute
          .replaceFirst(RegExp(r'^/'), '')
          .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
          .toLowerCase();
    }
    final String contextBlock;
    if (widget.label != null && widget.label!.isNotEmpty) {
      contextBlock = widget.label!
          .trim()
          .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
          .toLowerCase();
    } else {
      contextBlock = widget.type.name;
    }
    return '${routeSegment}_${contextBlock}_input_${widget.type.name}';
  }

  /// Infers a structural, non-visual hint from the configured [InputDataType].
  ///
  /// Returns [InputData.semanticHint] when explicitly set. Otherwise returns a
  /// format instruction string so autonomous agents know exactly what data
  /// format is expected for each input variant. Returns `null` for generic
  /// text and string types where no specific format constraint applies.
  String? _resolveSemanticHint() {
    if (widget.semanticHint != null) return widget.semanticHint;
    switch (widget.type) {
      case InputDataType.email:
        return 'Enter a valid email address, e.g. user@example.com';
      case InputDataType.phone:
        return 'Enter a phone number with country code, e.g. +12223334444';
      case InputDataType.url:
        return 'Enter a valid URL starting with https://';
      case InputDataType.date:
        return 'Select a date using the calendar picker';
      case InputDataType.dateTime:
      case InputDataType.timestamp:
        return 'Select a date and time using the picker';
      case InputDataType.time:
        return 'Select a time using the time picker';
      case InputDataType.secret:
        return 'Enter a password or secret token; input is hidden';
      case InputDataType.currency:
        return 'Enter a numeric currency amount';
      case InputDataType.percent:
        return 'Enter a numeric percentage value between 0 and 100';
      case InputDataType.int:
        return 'Enter a whole number';
      case InputDataType.double:
        return 'Enter a decimal number';
      case InputDataType.enums:
      case InputDataType.dropdown:
        return 'Select one option from the list';
      case InputDataType.radio:
        return 'Select one option from the available choices';
      case InputDataType.bool:
        return 'Toggle to enable or disable this option';
      default:
        return null;
    }
  }

  /// Builds the concrete editor that matches the configured [InputDataType].
  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context);
    final enumData = EnumData(locales: locales);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    bool isDense = widget.isDense || theme.inputDecorationTheme.isDense;
    bool isDisabled = widget.disabled;
    String defaultTextOptions = locales.get('label--choose-option');
    String? hintTextDefault;
    int? maxLength = widget.maxLength;
    FormFieldValidator<String>? validator = widget.validator;
    final clearWidget = isDisabled
        ? null
        : IconButton(
            onPressed: _clear,
            icon: const Icon(Icons.clear),
            tooltip: locales.get('label--clear'),
          );

    // Resolve transient error state.
    String? errorText;
    if (widget.error != null) {
      errorText = widget.error;
    }

    Widget? inputSuffixIcon;
    if (obscure) {
      inputSuffixIcon = IconButton(
        onPressed: () {
          obscureText = !obscureText;
          if (mounted) setState(() {});
        },
        icon: Icon(obscureText ? Icons.visibility : Icons.visibility_off),
      );
    }

    // Configure context-aware trailing controls.
    switch (widget.type) {
      case InputDataType.date:
      case InputDataType.dateTime:
      case InputDataType.timestamp:
      case InputDataType.time:
      case InputDataType.dropdown:
      case InputDataType.enums:
        if (value != null && value.toString().isNotEmpty) {
          inputSuffixIcon = clearWidget;
        }
        break;
      case InputDataType.phone:
        inputSuffixIcon = Tooltip(
          message: locales.get('label--info-phone-number-format'),
          child: Icon(Icons.info),
        );
      default:
        break;
    }

    Widget endWidget = Text(
      'Type "${widget.type}" not implemented',
      style: const TextStyle(color: Colors.orange),
    );
    TextInputType keyboardType = TextInputType.text;
    TextInputAction? textInputAction = widget.textInputAction;
    List<TextInputFormatter> inputFormatters = [...widget.inputFormatters];
    final inputValidation = InputValidation(locales: locales);
    bool readOnly = false;
    if (isDisabled) {
      readOnly = true;
    }
    switch (widget.type) {
      case InputDataType.text:
        keyboardType = TextInputType.multiline;
        textInputAction = widget.textInputAction ?? TextInputAction.newline;
        break;
      case InputDataType.phone:
        // https://en.wikipedia.org/wiki/Telephone_numbering_plan
        maxLength = 16;
        prefixText = isDisabled ? null : '+';
        hintTextDefault = '1 (222) 333 - 4444';
        keyboardType = TextInputType.phone;
        inputFormatters.addAll([
          FilteringTextInputFormatter.deny(RegExp(r'[\s()-+]')),
          FilteringTextInputFormatter.allow(RegExp(r'[\d{0,15}]')),
          FilteringTextInputFormatter.singleLineFormatter,
        ]);
        validator = inputValidation.validatePhone;
        break;
      case InputDataType.email:
        maxLength = 100;
        hintTextDefault = 'example@example.com';
        keyboardType = TextInputType.emailAddress;
        inputFormatters.addAll([
          FilteringTextInputFormatter.singleLineFormatter,
        ]);
        validator = inputValidation.validateEmail;
        break;
      case InputDataType.url:
        hintTextDefault = 'https://example.com';
        keyboardType = TextInputType.url;
        inputFormatters.addAll([
          FilteringTextInputFormatter.singleLineFormatter,
        ]);
        validator = inputValidation.validateUrl;
        break;
      case InputDataType.double:
      case InputDataType.currency:
      case InputDataType.percent:
        keyboardType = const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        );
        inputFormatters.addAll([
          FilteringTextInputFormatter.singleLineFormatter,
          FilteringTextInputFormatter.allow(RegExp(r'[\d.-]')),
        ]);
        break;
      case InputDataType.int:
        keyboardType = const TextInputType.numberWithOptions(signed: true);
        inputFormatters.addAll([
          FilteringTextInputFormatter.singleLineFormatter,
          FilteringTextInputFormatter.allow(RegExp(r'[\d-]')),
        ]);
        break;
      case InputDataType.date:
      case InputDataType.dateTime:
      case InputDataType.timestamp:
        keyboardType = TextInputType.datetime;
        inputFormatters.addAll([
          FilteringTextInputFormatter.singleLineFormatter,
        ]);
        hintTextDefault = locales.get('label--choose-label', {
          'label': locales.get('label--date'),
        });
        readOnly = true;
        break;
      case InputDataType.secret:
        keyboardType = TextInputType.visiblePassword;
        inputFormatters.addAll([
          FilteringTextInputFormatter.singleLineFormatter,
        ]);
        break;
      case InputDataType.enums:
      case InputDataType.dropdown:
        hintTextDefault = defaultTextOptions;
        readOnly = true;
        break;
      default:
    }

    // Let callers override the computed keyboard type.
    if (widget.keyboardType != null) {
      keyboardType = widget.keyboardType!;
    }

    String? hintText = widget.hintText ?? hintTextDefault;
    if (!widget.obscureText) {
      hintText = (value?.toString() ?? '').isNotEmpty
          ? value?.toString()
          : hintText;
    }
    final inputDecoration = InputDecoration(
      hintText: hintText,
      isDense: isDense,
      errorText: errorText,
      errorMaxLines: 2,
      // enabled: !isDisabled,
      prefix: widget.prefix,
      suffix: widget.suffix,
      prefixIcon: widget.prefixIcon,
      suffixIcon: widget.suffixIcon ?? inputSuffixIcon,
      prefixText: widget.prefixText ?? prefixText,
      suffixText: widget.suffixText,
      prefixStyle: widget.prefixStyle,
      suffixStyle: widget.suffixStyle,
      labelText: widget.label,
      labelStyle: theme.textTheme.bodyMedium,
      floatingLabelBehavior: widget.floatingLabelBehavior,
      contentPadding: isDense
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 4)
          : widget.padding,
      border: isDisabled
          ? theme.inputDecorationTheme.disabledBorder
          : theme.inputDecorationTheme.border,
      focusedBorder: isDisabled
          ? theme.inputDecorationTheme.disabledBorder
          : theme.inputDecorationTheme.focusedBorder,
      enabledBorder: isDisabled
          ? theme.inputDecorationTheme.disabledBorder
          : theme.inputDecorationTheme.enabledBorder,
      focusColor: isDisabled
          ? (widget.backgroundColor ?? theme.inputDecorationTheme.fillColor)
          : theme.focusColor,
      fillColor: widget.backgroundColor ?? theme.inputDecorationTheme.fillColor,
    );

    switch (widget.type) {
      case InputDataType.int:
      case InputDataType.double:
      case InputDataType.currency:
      case InputDataType.percent:
      case InputDataType.string:
      case InputDataType.text:
      case InputDataType.phone:
      case InputDataType.email:
      case InputDataType.secret:
      case InputDataType.url:
        endWidget = TextFormField(
          key: ValueKey('input-data-${widget.type}'),
          initialValue: isDisabled ? value?.toString() : null,
          controller: !isDisabled ? textController : null,
          autofillHints: widget.autofillHints,
          autofocus: widget.autofocus,
          autocorrect: widget.autocorrect,
          enableSuggestions: false,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          maxLines: widget.type == InputDataType.text ? 10 : 1,
          minLines: 1,
          maxLength: maxLength,
          decoration: inputDecoration,
          mouseCursor: isDisabled && (value?.toString().isNotEmpty ?? false)
              ? SystemMouseCursors.click
              : null,
          obscureText: obscureText,
          enableInteractiveSelection: isDisabled
              ? true
              : widget.enableInteractiveSelection,
          readOnly: isDisabled,
          // Force focus capability
          onChanged: isDisabled
              ? null
              : (newValue) {
                  dynamic newFormattedValue = valueChanged(newValue);
                  bool sameValue = value == newFormattedValue;
                  if (!sameValue) {
                    value = newFormattedValue?.toString() ?? '';
                    widget.onChanged?.call(newFormattedValue);
                  }
                },
          onFieldSubmitted: widget.onSubmit == null
              ? null
              : (newValue) {
                  widget.onSubmit!(valueChanged(value));
                  FocusManager.instance.primaryFocus?.unfocus();
                },
          onEditingComplete: widget.onComplete == null
              ? null
              : () {
                  widget.onComplete!(valueChanged(value));
                  FocusManager.instance.primaryFocus?.unfocus();
                },
        );
        break;
      case InputDataType.date:
      case InputDataType.dateTime:
      case InputDataType.timestamp:
        endWidget = TextFormField(
          key: ValueKey('input-data-${widget.type}'),
          obscureText: obscureText,
          autofillHints: widget.autofillHints,
          enableSuggestions: false,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          controller: textController,
          enableInteractiveSelection: widget.enableInteractiveSelection,
          readOnly: true,
          mouseCursor: isDisabled ? SystemMouseCursors.click : null,
          decoration: inputDecoration.copyWith(
            prefixIcon:
                inputDecoration.prefixIcon ??
                Icon(inputDataTypeIcon(widget.type)),
          ),
          onTap: isDisabled
              ? null
              : () async {
                  // Apply format depending on [showAsLocalTime]
                  DateTime now = widget.asLocalTime
                      ? DateTime.now()
                      : DateTime.timestamp();
                  DateTime date = value ?? now;
                  date = widget.asLocalTime ? date.toLocal() : date.toUtc();
                  // If the date is in the future, use the current date
                  DateTime dateBefore = now;
                  DateTime dateAfter = now;
                  if (value != null) {
                    dateBefore = date.isBefore(now) ? date : now;
                    dateAfter = date.isAfter(now) ? date : now;
                  }
                  late DateTime? picked;
                  final minDate = dateBefore.subtract(
                    const Duration(days: 365 * 101),
                  );
                  final maxDate = dateAfter.add(
                    const Duration(days: 365 * 101),
                  );
                  if (widget.type == InputDataType.date) {
                    picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: minDate,
                      lastDate: maxDate,
                    );
                  } else if (widget.type == InputDataType.dateTime ||
                      widget.type == InputDataType.timestamp) {
                    picked = await showOmniDateTimePicker(
                      context: context,
                      initialDate: date,
                      constraints: const BoxConstraints(
                        maxHeight: 800,
                        minHeight: 500,
                        minWidth: 400,
                        maxWidth: 800,
                      ),
                    );
                  }
                  if (picked != null) {
                    DateTime newDate = picked;
                    // Apply local time or utc time
                    if (widget.asLocalTime) {
                      newDate = newDate.toLocal();
                    } else {
                      // add Z to the end of the date to indicate it's UTC
                      // if it's not already UTC
                      if (!newDate.isUtc) {
                        newDate = DateTime.parse(
                          '${newDate.toIso8601String()}Z',
                        );
                      }
                      newDate = newDate.toUtc();
                    }
                    if (widget.utcOffset != null && widget.utcOffset != 0) {
                      newDate = Utils.dateTimeOffset(
                        dateTime: newDate,
                        utcOffset: widget.utcOffset,
                        reverse: true,
                      )!;
                    }
                    widget.onChanged?.call(newDate);
                    widget.onComplete?.call(newDate);
                    widget.onSubmit?.call(newDate);
                  }
                },
        );
        break;
      case InputDataType.time:
        TimeOfDay? time = value;
        DateFormat formatTime = DateFormat.jm();
        String? dateString = time != null
            ? formatTime.format(DateTime(1, 1, 1, time.hour, time.minute))
            : null;
        String label =
            dateString ??
            locales.get('label--choose-label', {
              'label': locales.get('label--time'),
            });
        endWidget = FilledButton.icon(
          key: ValueKey('input-data-${widget.type}'),
          onPressed: isDisabled
              ? null
              : () async {
                  time ??= TimeOfDay.now();
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: time!,
                  );
                  if (picked != null && picked != time) {
                    widget.onChanged?.call(picked);
                    widget.onComplete?.call(picked);
                    widget.onSubmit?.call(picked);
                  }
                },
          icon: const Icon(Icons.access_time),
          label: Text(label),
        );
        break;
      case InputDataType.enums:
      case InputDataType.dropdown:
        List<ButtonOptions> dropdownOptions = [];
        if (widget.type == InputDataType.dropdown) {
          dropdownOptions = widget.options;
          final match = dropdownOptions.where((element) {
            return element.value == value;
          });
          if (value != null && match.isNotEmpty) {
            textController.text = match.first.label;
          }
        }
        if (widget.type == InputDataType.enums) {
          if (value != null && value != '') {
            textController.text = enumData.localesFromEnum(value);
          }
          dropdownOptions = List.generate(widget.enums.length, (index) {
            final e = widget.enums[index];
            return ButtonOptions(
              id: e.toString(),
              label: enumData.localesFromEnum(e),
              value: e,
            );
          });
        }
        final widgetInput = TextFormField(
          key: ValueKey('input-data-${widget.type}'),
          autofillHints: widget.autofillHints,
          enableSuggestions: false,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          enableInteractiveSelection: isDisabled
              ? true
              : widget.enableInteractiveSelection,
          readOnly: readOnly,
          mouseCursor: isDisabled ? SystemMouseCursors.click : null,
          controller: textController,
          decoration: inputDecoration.copyWith(
            prefixIcon:
                inputDecoration.prefixIcon ??
                inputDecoration.prefixIcon ??
                Icon(inputDataTypeIcon(widget.type)),
            suffixIcon:
                inputDecoration.suffixIcon ?? const Icon(Icons.arrow_drop_down),
          ),
          onTap: isDisabled
              ? null
              : () async {
                  searchController.openView();
                },
        );
        if (!isDisabled) {
          endWidget = SearchAnchor(
            key: ValueKey('input-data-${widget.type}'),
            viewHintText: locales.get('label--search'),
            isFullScreen: width <= 1024 || height <= 1024,
            viewConstraints: const BoxConstraints(maxWidth: 1024),
            viewLeading: BackButton(onPressed: _closeSearch),
            viewTrailing: [
              ListenableBuilder(
                listenable: searchController,
                builder: (context, child) {
                  if (searchController.text.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return IconButton(
                    icon: const Icon(Icons.clear),
                    color: theme.colorScheme.error,
                    onPressed: () {
                      searchController.text = '';
                    },
                    tooltip: locales.get('label--clear'),
                  );
                },
              ),
              VoiceDictationButton(
                key: ValueKey('input-data-voice-dictation-button'),
                onPartialTranscript: (value) {
                  searchController.text = value;
                },
                onFinalTranscript: (value) {
                  searchController.text = value;
                },
                onError: (value) {
                  debugPrint(value);
                },
              ),
            ],
            searchController: searchController,
            builder: (BuildContext context, SearchController controller) {
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                opaque: false,
                child: PointerInterceptor(child: widgetInput),
              );
            },
            suggestionsBuilder: (BuildContext context, SearchController controller) {
              final value = controller.text.trim();
              List<ButtonOptions> recommendations = dropdownOptions;
              // keep @, . and + characters for more flexible searches (eg. emails, phone prefixes)
              final regex = RegExp(r'[^\w@.+]+');
              if (value.isNotEmpty) {
                recommendations = recommendations.where((element) {
                  // Remove special characters and spaces from the label to make search more flexible.
                  final labelClean = GSM
                      .toGSM(element.label)
                      .toLowerCase()
                      .replaceAll(regex, '')
                      .trim();
                  final labelAltClean = element.labelAlt != null
                      ? GSM
                            .toGSM(element.labelAlt)
                            .toLowerCase()
                            .replaceAll(regex, '')
                            .trim()
                      : null;
                  final valueClean = GSM
                      .toGSM(value)
                      .toLowerCase()
                      .replaceAll(regex, '')
                      .trim();
                  final labelMatch = labelClean.contains(valueClean);
                  final labelAltMatch =
                      labelAltClean?.contains(value.toLowerCase()) ?? false;
                  final valueMatch = element.value.toString().contains(value);
                  return labelMatch || valueMatch || labelAltMatch;
                }).toList();
              }
              return List.generate(recommendations.length, (int index) {
                final item = recommendations[index];

                // Resolve the leading widget.
                Widget? leading = item.leading;
                if (item.icon != null) {
                  leading = Icon(item.icon);
                }
                if (item.image != null) {
                  leading = UserAvatar(
                    key: ValueKey(
                      'input-data-dropdown-leading-image-${item.id}',
                    ),
                    name: item.label,
                    avatar: item.image,
                  );
                }

                // Resolve the trailing widget.
                Widget? trailing = item.trailing;
                if (item.trailingIcon != null) {
                  trailing = Icon(item.trailingIcon);
                }
                if (item.trailingImage != null) {
                  trailing = UserAvatar(
                    key: ValueKey(
                      'input-data-dropdown-trailing-image-${item.id}',
                    ),
                    name: item.label,
                    avatar: item.trailingImage,
                  );
                }
                return PointerInterceptor(
                  child: ListTile(
                    leading: leading,
                    trailing: trailing,
                    title: Text(item.label),
                    onTap: () {
                      dynamic newValue = item.value == '' ? null : item.value;
                      _closeSearch();
                      widget.onChanged?.call(newValue);
                      widget.onComplete?.call(newValue);
                      widget.onSubmit?.call(newValue);
                    },
                  ),
                );
              });
            },
          );
        } else {
          endWidget = widgetInput;
        }
        break;
      case InputDataType.radio:
        List<Widget> radioOptions = List.generate(widget.options.length, (
          index,
        ) {
          final e = widget.options[index];
          return RadioListTile(
            title: Text(e.label),
            toggleable: !isDisabled,
            value: e.value,
            selected: value == e.value,
          );
        });
        endWidget = RadioGroup(
          groupValue: value,
          onChanged: (newValue) {
            value = newValue;
            widget.onChanged?.call(value);
            widget.onComplete?.call(value);
            widget.onSubmit?.call(value);
          },
          child: Flex(
            direction: Axis.vertical,
            mainAxisSize: MainAxisSize.min,
            children: radioOptions,
          ),
        );
        break;
      case InputDataType.bool:
        endWidget = InputDecorator(
          decoration: InputDecoration(
            contentPadding: EdgeInsets.zero,
            isDense: isDense,
            errorText: errorText,
            enabled: !isDisabled,
            labelText: widget.label,
            labelStyle: theme.textTheme.bodyMedium,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            border: theme.inputDecorationTheme.border,
          ),
          child: SwitchListTile(
            title: widget.hintText != null
                ? Text(widget.hintText!, style: textTheme.bodyLarge)
                : null,
            value: value ?? false,
            dense: isDense,
            contentPadding: inputDecoration.contentPadding,
            onChanged: isDisabled
                ? null
                : (newValue) {
                    widget.onChanged?.call(newValue);
                    widget.onComplete?.call(newValue);
                    widget.onSubmit?.call(newValue);
                  },
            secondary:
                inputDecoration.prefixIcon ??
                Icon(inputDataTypeIcon(widget.type)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
        break;
    }
    if (isDisabled &&
        value != null &&
        value.toString().isNotEmpty &&
        !widget.obscureText &&
        !obscure &&
        widget.type != InputDataType.bool) {
      String copyValue = value.toString();
      switch (widget.type) {
        case InputDataType.secret:
          copyValue = '••••••••';
          break;
        case InputDataType.enums:
          copyValue = enumData.localesFromEnum(value);
          break;
        default:
      }
      endWidget = GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: copyValue));
          alertData(
            context: context,
            body: '${locales.get('alert--copy-clipboard')}: $copyValue',
            duration: 1,
          );
        },
        child: endWidget,
      );
    }
    return Semantics(
      label: _resolveSemanticLabel(locales),
      identifier: _resolveAutomationKey(context),
      hint: _resolveSemanticHint(),
      enabled: !widget.disabled,
      container: true,
      child: Theme(
        data: theme.copyWith(
          disabledColor: textTheme.bodyMedium?.color,
          inputDecorationTheme: theme.inputDecorationTheme.copyWith(
            disabledBorder: theme.inputDecorationTheme.enabledBorder,
            hoverColor: textTheme.bodyLarge?.color,
          ),
        ),
        child: Container(margin: widget.margin, child: endWidget),
      ),
    );
  }
}
