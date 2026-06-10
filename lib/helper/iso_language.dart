import '../serialized/iso_data.dart';

/// Exposes ISO language metadata used by pickers and localization helpers.
///
/// Each raw entry includes the display name, native name, emoji marker, and the
/// two-letter code used throughout the package. The data stays in map form here
/// so callers can either consume the raw records or materialize typed models via
/// [languages].
class ISOLanguages {
  /// Contains the canonical language definitions used by this package.
  static List<Map<String, dynamic>> raw = [
    {'name': 'Abkhaz', 'nativeName': 'аҧсуа', 'emoji': '🌐', 'alpha2': 'ab'},
    {'name': 'Afar', 'nativeName': 'Afaraf', 'emoji': '🇪🇹', 'alpha2': 'aa'},
    {
      'name': 'Afrikaans',
      'nativeName': 'Afrikaans',
      'emoji': '🇳🇦',
      'alpha2': 'af',
    },
    {'name': 'Akan', 'nativeName': 'Akan', 'emoji': '🌐', 'alpha2': 'ak'},
    {
      'name': 'Albanian',
      'nativeName': 'Shqip',
      'emoji': '🇦🇱',
      'alpha2': 'sq',
    },
    {'name': 'Amharic', 'nativeName': 'አማርኛ', 'emoji': '🇪🇹', 'alpha2': 'am'},
    {
      'name': 'Arabic',
      'nativeName': 'العربية',
      'emoji': '🇩🇿',
      'alpha2': 'ar',
    },
    {
      'name': 'Aragonese',
      'nativeName': 'Aragonés',
      'emoji': '🌐',
      'alpha2': 'an',
    },
    {
      'name': 'Armenian',
      'nativeName': 'Հայերեն',
      'emoji': '🇦🇲',
      'alpha2': 'hy',
    },
    {
      'name': 'Assamese',
      'nativeName': 'অসমীয়া',
      'emoji': '🌐',
      'alpha2': 'as',
    },
    {
      'name': 'Avaric',
      'nativeName': 'авар мацӀ, магӀарул мацӀ',
      'emoji': '🌐',
      'alpha2': 'av',
    },
    {'name': 'Avestan', 'nativeName': 'avesta', 'emoji': '🌐', 'alpha2': 'ae'},
    {
      'name': 'Aymara',
      'nativeName': 'aymar aru',
      'emoji': '🇧🇴',
      'alpha2': 'ay',
    },
    {
      'name': 'Azerbaijani',
      'nativeName': 'azərbaycan dili',
      'emoji': '🇦🇿',
      'alpha2': 'az',
    },
    {
      'name': 'Bambara',
      'nativeName': 'bamanankan',
      'emoji': '🌐',
      'alpha2': 'bm',
    },
    {
      'name': 'Bashkir',
      'nativeName': 'башҡорт теле',
      'emoji': '🌐',
      'alpha2': 'ba',
    },
    {
      'name': 'Basque',
      'nativeName': 'euskara, euskera',
      'emoji': '🌐',
      'alpha2': 'eu',
    },
    {
      'name': 'Belarusian',
      'nativeName': 'Беларуская',
      'emoji': '🇧🇾',
      'alpha2': 'be',
    },
    {'name': 'Bengali', 'nativeName': 'বাংলা', 'emoji': '🇧🇩', 'alpha2': 'bn'},
    {'name': 'Bihari', 'nativeName': 'भोजपुरी', 'emoji': '🌐', 'alpha2': 'bh'},
    {
      'name': 'Bislama',
      'nativeName': 'Bislama',
      'emoji': '🇻🇺',
      'alpha2': 'bi',
    },
    {
      'name': 'Bosnian',
      'nativeName': 'bosanski jezik',
      'emoji': '🇧🇦',
      'alpha2': 'bs',
    },
    {
      'name': 'Breton',
      'nativeName': 'brezhoneg',
      'emoji': '🌐',
      'alpha2': 'br',
    },
    {
      'name': 'Bulgarian',
      'nativeName': 'български език',
      'emoji': '🇧🇬',
      'alpha2': 'bg',
    },
    {'name': 'Burmese', 'nativeName': 'ဗမာစာ', 'emoji': '🇲🇲', 'alpha2': 'my'},
    {
      'name': 'Catalan; Valencian',
      'nativeName': 'Català',
      'emoji': '🇦🇩',
      'alpha2': 'ca',
    },
    {
      'name': 'Chamorro',
      'nativeName': 'Chamoru',
      'emoji': '🇬🇺',
      'alpha2': 'ch',
    },
    {
      'name': 'Chechen',
      'nativeName': 'нохчийн мотт',
      'emoji': '🌐',
      'alpha2': 'ce',
    },
    {
      'name': 'Chichewa; Chewa; Nyanja',
      'nativeName': 'chiCheŵa, chinyanja',
      'emoji': '🇲🇼',
      'alpha2': 'ny',
    },
    {
      'name': 'Chinese',
      'nativeName': '中文 (Zhōngwén), 汉语, 漢語',
      'emoji': '🇨🇳',
      'alpha2': 'zh',
    },
    {
      'name': 'Chuvash',
      'nativeName': 'чӑваш чӗлхи',
      'emoji': '🌐',
      'alpha2': 'cv',
    },
    {
      'name': 'Cornish',
      'nativeName': 'Kernewek',
      'emoji': '🌐',
      'alpha2': 'kw',
    },
    {
      'name': 'Corsican',
      'nativeName': 'corsu, lingua corsa',
      'emoji': '🌐',
      'alpha2': 'co',
    },
    {'name': 'Cree', 'nativeName': 'ᓀᐦᐃᔭᐍᐏᐣ', 'emoji': '🌐', 'alpha2': 'cr'},
    {
      'name': 'Croatian',
      'nativeName': 'hrvatski',
      'emoji': '🇧🇦',
      'alpha2': 'hr',
    },
    {
      'name': 'Czech',
      'nativeName': 'česky, čeština',
      'emoji': '🇨🇿',
      'alpha2': 'cs',
    },
    {'name': 'Danish', 'nativeName': 'dansk', 'emoji': '🇩🇰', 'alpha2': 'da'},
    {
      'name': 'Divehi; Dhivehi; Maldivian;',
      'nativeName': 'ދިވެހި',
      'emoji': '🇲🇻',
      'alpha2': 'dv',
    },
    {
      'name': 'Dutch',
      'nativeName': 'Nederlands, Vlaams',
      'emoji': '🇳🇱',
      'alpha2': 'nl',
    },
    {
      'name': 'English',
      'nativeName': 'English',
      'emoji': '🇺🇸',
      'alpha2': 'en',
    },
    {
      'name': 'Esperanto',
      'nativeName': 'Esperanto',
      'emoji': '🌐',
      'alpha2': 'eo',
    },
    {
      'name': 'Estonian',
      'nativeName': 'eesti, eesti keel',
      'emoji': '🇪🇪',
      'alpha2': 'et',
    },
    {'name': 'Ewe', 'nativeName': 'Eʋegbe', 'emoji': '🌐', 'alpha2': 'ee'},
    {
      'name': 'Faroese',
      'nativeName': 'føroyskt',
      'emoji': '🇫🇴',
      'alpha2': 'fo',
    },
    {
      'name': 'Fijian',
      'nativeName': 'vosa Vakaviti',
      'emoji': '🇫🇯',
      'alpha2': 'fj',
    },
    {
      'name': 'Finnish',
      'nativeName': 'suomi, suomen kieli',
      'emoji': '🇫🇮',
      'alpha2': 'fi',
    },
    {
      'name': 'French',
      'nativeName': 'français, langue française',
      'emoji': '🇫🇷',
      'alpha2': 'fr',
    },
    {
      'name': 'Fula; Fulah; Pulaar; Pular',
      'nativeName': 'Fulfulde, Pulaar, Pular',
      'emoji': '🇬🇳',
      'alpha2': 'ff',
    },
    {'name': 'Galician', 'nativeName': 'Galego', 'emoji': '🌐', 'alpha2': 'gl'},
    {
      'name': 'Georgian',
      'nativeName': 'ქართული',
      'emoji': '🇬🇪',
      'alpha2': 'ka',
    },
    {
      'name': 'German',
      'nativeName': 'Deutsch',
      'emoji': '🇩🇪',
      'alpha2': 'de',
    },
    {
      'name': 'Greek, Modern',
      'nativeName': 'Ελληνικά',
      'emoji': '🇬🇷',
      'alpha2': 'el',
    },
    {
      'name': 'Guaraní',
      'nativeName': 'Avañeẽ',
      'emoji': '🇦🇷',
      'alpha2': 'gn',
    },
    {
      'name': 'Gujarati',
      'nativeName': 'ગુજરાતી',
      'emoji': '🌐',
      'alpha2': 'gu',
    },
    {
      'name': 'Haitian; Haitian Creole',
      'nativeName': 'Kreyòl ayisyen',
      'emoji': '🇭🇹',
      'alpha2': 'ht',
    },
    {
      'name': 'Hausa',
      'nativeName': 'Hausa, هَوُسَ',
      'emoji': '🌐',
      'alpha2': 'ha',
    },
    {
      'name': 'Hebrew (modern)',
      'nativeName': 'עברית',
      'emoji': '🇮🇱',
      'alpha2': 'he',
    },
    {
      'name': 'Herero',
      'nativeName': 'Otjiherero',
      'emoji': '🌐',
      'alpha2': 'hz',
    },
    {
      'name': 'Hindi',
      'nativeName': 'हिन्दी, हिंदी',
      'emoji': '🇮🇳',
      'alpha2': 'hi',
    },
    {
      'name': 'Hiri Motu',
      'nativeName': 'Hiri Motu',
      'emoji': '🌐',
      'alpha2': 'ho',
    },
    {
      'name': 'Hungarian',
      'nativeName': 'Magyar',
      'emoji': '🇭🇺',
      'alpha2': 'hu',
    },
    {
      'name': 'Interlingua',
      'nativeName': 'Interlingua',
      'emoji': '🌐',
      'alpha2': 'ia',
    },
    {
      'name': 'Indonesian',
      'nativeName': 'Bahasa Indonesia',
      'emoji': '🇮🇩',
      'alpha2': 'id',
    },
    {
      'name': 'Interlingue',
      'nativeName': 'Originally called Occidental; then Interlingue after WWII',
      'emoji': '🌐',
      'alpha2': 'ie',
    },
    {'name': 'Irish', 'nativeName': 'Gaeilge', 'emoji': '🇮🇪', 'alpha2': 'ga'},
    {'name': 'Igbo', 'nativeName': 'Asụsụ Igbo', 'emoji': '🌐', 'alpha2': 'ig'},
    {
      'name': 'Inupiaq',
      'nativeName': 'Iñupiaq, Iñupiatun',
      'emoji': '🌐',
      'alpha2': 'ik',
    },
    {'name': 'Ido', 'nativeName': 'Ido', 'emoji': '🌐', 'alpha2': 'io'},
    {
      'name': 'Icelandic',
      'nativeName': 'Íslenska',
      'emoji': '🇮🇸',
      'alpha2': 'is',
    },
    {
      'name': 'Italian',
      'nativeName': 'Italiano',
      'emoji': '🇮🇹',
      'alpha2': 'it',
    },
    {
      'name': 'Inuktitut',
      'nativeName': 'ᐃᓄᒃᑎᑐᑦ',
      'emoji': '🌐',
      'alpha2': 'iu',
    },
    {
      'name': 'Japanese',
      'nativeName': '日本語 (にほんご／にっぽんご)',
      'emoji': '🇯🇵',
      'alpha2': 'ja',
    },
    {
      'name': 'Javanese',
      'nativeName': 'basa Jawa',
      'emoji': '🌐',
      'alpha2': 'jv',
    },
    {
      'name': 'Kalaallisut, Greenlandic',
      'nativeName': 'kalaallisut, kalaallit oqaasii',
      'emoji': '🇬🇱',
      'alpha2': 'kl',
    },
    {'name': 'Kannada', 'nativeName': 'ಕನ್ನಡ', 'emoji': '🌐', 'alpha2': 'kn'},
    {'name': 'Kanuri', 'nativeName': 'Kanuri', 'emoji': '🌐', 'alpha2': 'kr'},
    {
      'name': 'Kashmiri',
      'nativeName': 'कश्मीरी, كشميري‎',
      'emoji': '🌐',
      'alpha2': 'ks',
    },
    {
      'name': 'Kazakh',
      'nativeName': 'Қазақ тілі',
      'emoji': '🇰🇿',
      'alpha2': 'kk',
    },
    {
      'name': 'Khmer',
      'nativeName': 'ភាសាខ្មែរ',
      'emoji': '🇰🇭',
      'alpha2': 'km',
    },
    {
      'name': 'Kikuyu, Gikuyu',
      'nativeName': 'Gĩkũyũ',
      'emoji': '🌐',
      'alpha2': 'ki',
    },
    {
      'name': 'Kinyarwanda',
      'nativeName': 'Ikinyarwanda',
      'emoji': '🇷🇼',
      'alpha2': 'rw',
    },
    {
      'name': 'Kirghiz, Kyrgyz',
      'nativeName': 'кыргыз тили',
      'emoji': '🇰🇬',
      'alpha2': 'ky',
    },
    {'name': 'Komi', 'nativeName': 'коми кыв', 'emoji': '🌐', 'alpha2': 'kv'},
    {'name': 'Kongo', 'nativeName': 'KiKongo', 'emoji': '🇨🇩', 'alpha2': 'kg'},
    {
      'name': 'Korean',
      'nativeName': '한국어 (韓國語), 조선말 (朝鮮語)',
      'emoji': '🇰🇷',
      'alpha2': 'ko',
    },
    {
      'name': 'Kurdish',
      'nativeName': 'Kurdî, كوردی‎',
      'emoji': '🇮🇶',
      'alpha2': 'ku',
    },
    {
      'name': 'Kwanyama, Kuanyama',
      'nativeName': 'Kuanyama',
      'emoji': '🌐',
      'alpha2': 'kj',
    },
    {
      'name': 'Latin',
      'nativeName': 'latine, lingua latina',
      'emoji': '🇻🇦',
      'alpha2': 'la',
    },
    {
      'name': 'Luxembourgish, Letzeburgesch',
      'nativeName': 'Lëtzebuergesch',
      'emoji': '🇱🇺',
      'alpha2': 'lb',
    },
    {'name': 'Luganda', 'nativeName': 'Luganda', 'emoji': '🌐', 'alpha2': 'lg'},
    {
      'name': 'Limburgish, Limburgan, Limburger',
      'nativeName': 'Limburgs',
      'emoji': '🌐',
      'alpha2': 'li',
    },
    {
      'name': 'Lingala',
      'nativeName': 'Lingála',
      'emoji': '🇨🇩',
      'alpha2': 'ln',
    },
    {'name': 'Lao', 'nativeName': 'ພາສາລາວ', 'emoji': '🇱🇦', 'alpha2': 'lo'},
    {
      'name': 'Lithuanian',
      'nativeName': 'lietuvių kalba',
      'emoji': '🇱🇹',
      'alpha2': 'lt',
    },
    {'name': 'Luba-Katanga', 'nativeName': '', 'emoji': '🌐', 'alpha2': 'lu'},
    {
      'name': 'Latvian',
      'nativeName': 'latviešu valoda',
      'emoji': '🇱🇻',
      'alpha2': 'lv',
    },
    {
      'name': 'Manx',
      'nativeName': 'Gaelg, Gailck',
      'emoji': '🇮🇲',
      'alpha2': 'gv',
    },
    {
      'name': 'Macedonian',
      'nativeName': 'македонски јазик',
      'emoji': '🇲🇰',
      'alpha2': 'mk',
    },
    {
      'name': 'Malagasy',
      'nativeName': 'Malagasy fiteny',
      'emoji': '🇲🇬',
      'alpha2': 'mg',
    },
    {
      'name': 'Malay',
      'nativeName': 'bahasa Melayu, بهاس ملايو‎',
      'emoji': '🇸🇬',
      'alpha2': 'ms',
    },
    {
      'name': 'Malayalam',
      'nativeName': 'മലയാളം',
      'emoji': '🌐',
      'alpha2': 'ml',
    },
    {'name': 'Maltese', 'nativeName': 'Malti', 'emoji': '🇲🇹', 'alpha2': 'mt'},
    {
      'name': 'Māori',
      'nativeName': 'te reo Māori',
      'emoji': '🇳🇿',
      'alpha2': 'mi',
    },
    {
      'name': 'Marathi (Marāṭhī)',
      'nativeName': 'मराठी',
      'emoji': '🌐',
      'alpha2': 'mr',
    },
    {
      'name': 'Marshallese',
      'nativeName': 'Kajin M̧ajeļ',
      'emoji': '🇲🇭',
      'alpha2': 'mh',
    },
    {
      'name': 'Mongolian',
      'nativeName': 'монгол',
      'emoji': '🇲🇳',
      'alpha2': 'mn',
    },
    {
      'name': 'Nauru',
      'nativeName': 'Ekakairũ Naoero',
      'emoji': '🇳🇷',
      'alpha2': 'na',
    },
    {
      'name': 'Navajo, Navaho',
      'nativeName': 'Diné bizaad, Dinékʼehǰí',
      'emoji': '🌐',
      'alpha2': 'nv',
    },
    {
      'name': 'Norwegian Bokmål',
      'nativeName': 'Norsk bokmål',
      'emoji': '🌐',
      'alpha2': 'nb',
    },
    {
      'name': 'North Ndebele',
      'nativeName': 'isiNdebele',
      'emoji': '🇿🇼',
      'alpha2': 'nd',
    },
    {'name': 'Nepali', 'nativeName': 'नेपाली', 'emoji': '🇳🇵', 'alpha2': 'ne'},
    {'name': 'Ndonga', 'nativeName': 'Owambo', 'emoji': '🌐', 'alpha2': 'ng'},
    {
      'name': 'Norwegian Nynorsk',
      'nativeName': 'Norsk nynorsk',
      'emoji': '🇧🇻',
      'alpha2': 'nn',
    },
    {
      'name': 'Norwegian',
      'nativeName': 'Norsk',
      'emoji': '🇳🇴',
      'alpha2': 'no',
    },
    {
      'name': 'Nuosu',
      'nativeName': 'ꆈꌠ꒿ Nuosuhxop',
      'emoji': '🌐',
      'alpha2': 'ii',
    },
    {
      'name': 'South Ndebele',
      'nativeName': 'isiNdebele',
      'emoji': '🇿🇦',
      'alpha2': 'nr',
    },
    {'name': 'Occitan', 'nativeName': 'Occitan', 'emoji': '🌐', 'alpha2': 'oc'},
    {
      'name': 'Ojibwe, Ojibwa',
      'nativeName': 'ᐊᓂᔑᓈᐯᒧᐎᓐ',
      'emoji': '🌐',
      'alpha2': 'oj',
    },
    {
      'name':
          'Old Church Slavonic, Church Slavic, Church Slavonic, Old Bulgarian, Old Slavonic',
      'nativeName': 'ѩзыкъ словѣньскъ',
      'emoji': '🌐',
      'alpha2': 'cu',
    },
    {
      'name': 'Oromo',
      'nativeName': 'Afaan Oromoo',
      'emoji': '🌐',
      'alpha2': 'om',
    },
    {'name': 'Oriya', 'nativeName': 'ଓଡ଼ିଆ', 'emoji': '🌐', 'alpha2': 'or'},
    {
      'name': 'Ossetian, Ossetic',
      'nativeName': 'ирон æвзаг',
      'emoji': '🌐',
      'alpha2': 'os',
    },
    {
      'name': 'Panjabi, Punjabi',
      'nativeName': 'ਪੰਜਾਬੀ, پنجابی‎',
      'emoji': '🇦🇼',
      'alpha2': 'pa',
    },
    {'name': 'Pāli', 'nativeName': 'पाऴि', 'emoji': '🌐', 'alpha2': 'pi'},
    {'name': 'Persian', 'nativeName': 'فارسی', 'emoji': '🇮🇷', 'alpha2': 'fa'},
    {'name': 'Polish', 'nativeName': 'polski', 'emoji': '🇵🇱', 'alpha2': 'pl'},
    {
      'name': 'Pashto, Pushto',
      'nativeName': 'پښتو',
      'emoji': '🇦🇫',
      'alpha2': 'ps',
    },
    {
      'name': 'Portuguese',
      'nativeName': 'Português',
      'emoji': '🇵🇹',
      'alpha2': 'pt',
    },
    {
      'name': 'Quechua',
      'nativeName': 'Runa Simi, Kichwa',
      'emoji': '🇧🇴',
      'alpha2': 'qu',
    },
    {
      'name': 'Romansh',
      'nativeName': 'rumantsch grischun',
      'emoji': '🌐',
      'alpha2': 'rm',
    },
    {
      'name': 'Kirundi',
      'nativeName': 'kiRundi',
      'emoji': '🇧🇮',
      'alpha2': 'rn',
    },
    {
      'name': 'Romanian, Moldavian, Moldovan',
      'nativeName': 'română',
      'emoji': '🇷🇴',
      'alpha2': 'ro',
    },
    {
      'name': 'Russian',
      'nativeName': 'русский язык',
      'emoji': '🇷🇺',
      'alpha2': 'ru',
    },
    {
      'name': 'Sanskrit (Saṁskṛta)',
      'nativeName': 'संस्कृतम्',
      'emoji': '🌐',
      'alpha2': 'sa',
    },
    {'name': 'Sardinian', 'nativeName': 'sardu', 'emoji': '🌐', 'alpha2': 'sc'},
    {
      'name': 'Sindhi',
      'nativeName': 'सिन्धी, سنڌي، سندھی‎',
      'emoji': '🌐',
      'alpha2': 'sd',
    },
    {
      'name': 'Northern Sami',
      'nativeName': 'Davvisámegiella',
      'emoji': '🌐',
      'alpha2': 'se',
    },
    {
      'name': 'Samoan',
      'nativeName': 'gagana faa Samoa',
      'emoji': '🇼🇸',
      'alpha2': 'sm',
    },
    {
      'name': 'Sango',
      'nativeName': 'yângâ tî sängö',
      'emoji': '🇨🇫',
      'alpha2': 'sg',
    },
    {
      'name': 'Serbian',
      'nativeName': 'српски језик',
      'emoji': '🇷🇸',
      'alpha2': 'sr',
    },
    {
      'name': 'Scottish Gaelic; Gaelic',
      'nativeName': 'Gàidhlig',
      'emoji': '🌐',
      'alpha2': 'gd',
    },
    {
      'name': 'Shona',
      'nativeName': 'chiShona',
      'emoji': '🇿🇼',
      'alpha2': 'sn',
    },
    {
      'name': 'Sinhala, Sinhalese',
      'nativeName': 'සිංහල',
      'emoji': '🇱🇰',
      'alpha2': 'si',
    },
    {
      'name': 'Slovak',
      'nativeName': 'slovenčina',
      'emoji': '🇸🇰',
      'alpha2': 'sk',
    },
    {
      'name': 'Slovene',
      'nativeName': 'slovenščina',
      'emoji': '🇸🇮',
      'alpha2': 'sl',
    },
    {
      'name': 'Somali',
      'nativeName': 'Soomaaliga, af Soomaali',
      'emoji': '🇸🇴',
      'alpha2': 'so',
    },
    {
      'name': 'Southern Sotho',
      'nativeName': 'Sesotho',
      'emoji': '🇱🇸',
      'alpha2': 'st',
    },
    {
      'name': 'Spanish; Castilian',
      'nativeName': 'español, castellano',
      'emoji': '🇪🇸',
      'alpha2': 'es',
    },
    {
      'name': 'Sundanese',
      'nativeName': 'Basa Sunda',
      'emoji': '🌐',
      'alpha2': 'su',
    },
    {
      'name': 'Swahili',
      'nativeName': 'Kiswahili',
      'emoji': '🇰🇪',
      'alpha2': 'sw',
    },
    {'name': 'Swati', 'nativeName': 'SiSwati', 'emoji': '🇿🇦', 'alpha2': 'ss'},
    {
      'name': 'Swedish',
      'nativeName': 'svenska',
      'emoji': '🇸🇪',
      'alpha2': 'sv',
    },
    {'name': 'Tamil', 'nativeName': 'தமிழ்', 'emoji': '🇸🇬', 'alpha2': 'ta'},
    {'name': 'Telugu', 'nativeName': 'తెలుగు', 'emoji': '🌐', 'alpha2': 'te'},
    {
      'name': 'Tajik',
      'nativeName': 'тоҷикӣ, toğikī, تاجیکی‎',
      'emoji': '🇹🇯',
      'alpha2': 'tg',
    },
    {'name': 'Thai', 'nativeName': 'ไทย', 'emoji': '🇹🇭', 'alpha2': 'th'},
    {'name': 'Tigrinya', 'nativeName': 'ትግርኛ', 'emoji': '🇪🇷', 'alpha2': 'ti'},
    {
      'name': 'Tibetan Standard, Tibetan, Central',
      'nativeName': 'བོད་ཡིག',
      'emoji': '🌐',
      'alpha2': 'bo',
    },
    {
      'name': 'Turkmen',
      'nativeName': 'Türkmen, Түркмен',
      'emoji': '🇹🇲',
      'alpha2': 'tk',
    },
    {
      'name': 'Tagalog',
      'nativeName': 'Wikang Tagalog, ᜏᜒᜃᜅ᜔ ᜆᜄᜎᜓᜄ᜔',
      'emoji': '🌐',
      'alpha2': 'tl',
    },
    {
      'name': 'Tswana',
      'nativeName': 'Setswana',
      'emoji': '🇧🇼',
      'alpha2': 'tn',
    },
    {
      'name': 'Tonga (Tonga Islands)',
      'nativeName': 'faka Tonga',
      'emoji': '🇹🇴',
      'alpha2': 'to',
    },
    {
      'name': 'Turkish',
      'nativeName': 'Türkçe',
      'emoji': '🇹🇷',
      'alpha2': 'tr',
    },
    {
      'name': 'Tsonga',
      'nativeName': 'Xitsonga',
      'emoji': '🇿🇦',
      'alpha2': 'ts',
    },
    {
      'name': 'Tatar',
      'nativeName': 'татарча, tatarça, تاتارچا‎',
      'emoji': '🌐',
      'alpha2': 'tt',
    },
    {'name': 'Twi', 'nativeName': 'Twi', 'emoji': '🌐', 'alpha2': 'tw'},
    {
      'name': 'Tahitian',
      'nativeName': 'Reo Tahiti',
      'emoji': '🌐',
      'alpha2': 'ty',
    },
    {
      'name': 'Uighur, Uyghur',
      'nativeName': 'Uyƣurqə, ئۇيغۇرچە‎',
      'emoji': '🌐',
      'alpha2': 'ug',
    },
    {
      'name': 'Ukrainian',
      'nativeName': 'українська',
      'emoji': '🇺🇦',
      'alpha2': 'uk',
    },
    {'name': 'Urdu', 'nativeName': 'اردو', 'emoji': '🇵🇰', 'alpha2': 'ur'},
    {
      'name': 'Uzbek',
      'nativeName': 'zbek, Ўзбек, أۇزبېك‎',
      'emoji': '🌐',
      'alpha2': 'uz',
    },
    {
      'name': 'Venda',
      'nativeName': 'Tshivenḓa',
      'emoji': '🇿🇦',
      'alpha2': 've',
    },
    {
      'name': 'Vietnamese',
      'nativeName': 'Tiếng Việt',
      'emoji': '🇻🇳',
      'alpha2': 'vi',
    },
    {'name': 'Volapük', 'nativeName': 'Volapük', 'emoji': '🌐', 'alpha2': 'vo'},
    {'name': 'Walloon', 'nativeName': 'Walon', 'emoji': '🌐', 'alpha2': 'wa'},
    {'name': 'Welsh', 'nativeName': 'Cymraeg', 'emoji': '🌐', 'alpha2': 'cy'},
    {'name': 'Wolof', 'nativeName': 'Wollof', 'emoji': '🌐', 'alpha2': 'wo'},
    {
      'name': 'Western Frisian',
      'nativeName': 'Frysk',
      'emoji': '🌐',
      'alpha2': 'fy',
    },
    {
      'name': 'Xhosa',
      'nativeName': 'isiXhosa',
      'emoji': '🇿🇦',
      'alpha2': 'xh',
    },
    {'name': 'Yiddish', 'nativeName': 'ייִדיש', 'emoji': '🌐', 'alpha2': 'yi'},
    {'name': 'Yoruba', 'nativeName': 'Yorùbá', 'emoji': '🌐', 'alpha2': 'yo'},
    {
      'name': 'Zhuang, Chuang',
      'nativeName': 'Saɯ cueŋƅ, Saw cuengh',
      'emoji': '🌐',
      'alpha2': 'za',
    },
    {'name': 'Zulu', 'nativeName': '', 'emoji': '🇿🇦', 'alpha2': 'zu'},
  ];

  /// Lists language codes supported by Google Text-to-Speech WaveNet voices.
  ///
  /// Callers can use this to hide unsupported voice options before attempting a
  /// text-to-speech request.
  static List waveNetLanguages = [
    'da',
    'nl',
    'en',
    'fr',
    'de',
    'it',
    'ja',
    'ko',
    'no',
    'pl',
    'pt',
    'ru',
    'sk',
    'es',
    'sv',
    'tr',
    'uk',
  ];

  /// Returns the raw language metadata as typed [ISOLanguage] models.
  ///
  /// A new list is created on each access so callers can iterate safely without
  /// mutating the canonical [raw] dataset.
  static List<ISOLanguage> get languages {
    List<ISOLanguage> items = [];
    for (var element in raw) {
      items.add(ISOLanguage.fromJson(element));
    }
    return items;
  }

  /// Returns the display name for the language identified by [alpha2].
  ///
  /// `null` is returned when the code is unknown so UI code can decide how to
  /// handle missing metadata without catching exceptions.
  static String? getName(String? alpha2) {
    try {
      return languages.firstWhere((element) => element.alpha2 == alpha2).name;
    } catch (error) {
      return null;
    }
  }

  /// Returns the emoji marker associated with the language identified by [alpha2].
  ///
  /// Some entries use a globe emoji instead of a flag when no single country is a
  /// good representation of the language.
  static String? getEmoji(String? alpha2) {
    try {
      return languages.firstWhere((element) => element.alpha2 == alpha2).emoji;
    } catch (error) {
      return null;
    }
  }
}
