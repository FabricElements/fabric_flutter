import 'package:json_annotation/json_annotation.dart';

part 'iso_data.g.dart';

/// Describes an ISO language entry used by the application.
///
/// This model keeps both machine-readable codes and user-facing labels so the
/// UI can present localized language choices while still serializing compact,
/// standards-based identifiers.
@JsonSerializable(explicitToJson: true)
class ISOLanguage {
  /// Stores the ISO 639-1 two-letter language code.
  final String alpha2;

  /// Stores the ISO 639-2 or ISO 639-3 language code when available.
  @JsonKey(includeIfNull: true)
  final String alpha3;

  /// Stores the localized or English display name.
  final String name;

  /// Stores the language name in its own writing system when known.
  final String nativeName;

  /// Provides an emoji shorthand used in selectors and summaries.
  final String emoji;

  /// Creates an ISO language record.
  ISOLanguage({
    required this.alpha2,
    this.alpha3 = '',
    this.name = '',
    this.nativeName = '',
    this.emoji = '🌐',
  });

  /// Builds [ISOLanguage] from serialized JSON.
  ///
  /// A `null` payload is treated as empty input so optional language values can
  /// fall back to constructor defaults.
  factory ISOLanguage.fromJson(Map<String, dynamic>? json) =>
      _$ISOLanguageFromJson(json ?? {});

  /// Converts this language record into JSON.
  Map<String, dynamic> toJson() => _$ISOLanguageToJson(this);
}

/// Describes an ISO country entry used by the application.
///
/// The model intentionally combines geographic, telephony, and currency data so
/// a single serialized object can support country pickers, formatting logic, and
/// regional settings.
@JsonSerializable(explicitToJson: true)
class ISOCountry {
  /// Stores the capital city when known.
  final String? capital;

  /// Stores the demonym or citizenship label when available.
  final String? citizenship;

  /// Stores the numeric or canonical country code used by the data source.
  final String countryCode;

  /// Stores the currency name used in the country.
  final String? currency;

  /// Stores the ISO currency code when available.
  final String? currencyCode;

  /// Stores the currency subunit name, such as `cent`.
  final String? currencySubUnit;

  /// Stores the full official country name when it differs from [name].
  String? fullName;

  /// Stores the ISO 3166-1 alpha-2 country code.
  String alpha2;

  /// Stores the ISO 3166-1 alpha-3 country code.
  final String alpha3;

  /// Stores the short display name used throughout the UI.
  String name;

  /// Stores the region code used for grouping countries.
  final String? regionCode;

  /// Stores the sub-region code used for finer grouping.
  final String? subRegionCode;

  /// Indicates whether the country belongs to the EEA.
  final bool eea;

  /// Stores the international calling code when available.
  final String? callingCode;

  /// Stores the preferred currency symbol when available.
  final String? currencySymbol;

  /// Provides an emoji shorthand used in lists and summaries.
  final String flag;

  /// Creates an ISO country record.
  ISOCountry({
    this.capital,
    this.citizenship,
    required this.countryCode,
    this.currency,
    this.currencyCode,
    this.currencySubUnit,
    this.fullName,
    required this.alpha2,
    required this.alpha3,
    required this.name,
    this.regionCode,
    this.subRegionCode,
    this.eea = false,
    this.callingCode,
    this.currencySymbol,
    this.flag = '🌐',
  });

  /// Builds [ISOCountry] from serialized JSON.
  ///
  /// A `null` payload is treated as empty input so callers can deserialize
  /// optional country values without performing a prior null check.
  factory ISOCountry.fromJson(Map<String, dynamic>? json) =>
      _$ISOCountryFromJson(json ?? {});

  /// Converts this country record into JSON.
  Map<String, dynamic> toJson() => _$ISOCountryToJson(this);
}
