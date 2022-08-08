library fabric_flutter;

import '../serialized/gsm_data.dart';

/// Dart version of GSM library
/// https://github.com/vchatterji/gsm
//Inspired from https://messente.com/sms/calculator

Map<String, int> charset7bit = {
  '@': 1,
  '£': 1,
  '\$': 1,
  '¥': 1,
  'è': 1,
  'é': 1,
  'ù': 1,
  'ì': 1,
  'ò': 1,
  'Ç': 1,
  '\n': 1,
  'Ø': 1,
  'ø': 1,
  '\r': 1,
  'Å': 1,
  'å': 1,
  'Δ': 1,
  '_': 1,
  'Φ': 1,
  'Γ': 1,
  'Λ': 1,
  'Ω': 1,
  'Π': 1,
  'Ψ': 1,
  'Σ': 1,
  'Θ': 1,
  'Ξ': 1,
  'Æ': 1,
  'æ': 1,
  'ß': 1,
  'É': 1,
  ' ': 1,
  '!': 1,
  '"': 1,
  '#': 1,
  '¤': 1,
  '%': 1,
  '&': 1,
  "'": 1,
  '(': 1,
  ')': 1,
  '*': 1,
  '+': 1,
  ',': 1,
  '-': 1,
  '.': 1,
  '/': 1,
  '0': 1,
  '1': 1,
  '2': 1,
  '3': 1,
  '4': 1,
  '5': 1,
  '6': 1,
  '7': 1,
  '8': 1,
  '9': 1,
  ':': 1,
  ';': 1,
  '<': 1,
  '=': 1,
  '>': 1,
  '?': 1,
  '¡': 1,
  'A': 1,
  'B': 1,
  'C': 1,
  'D': 1,
  'E': 1,
  'F': 1,
  'G': 1,
  'H': 1,
  'I': 1,
  'J': 1,
  'K': 1,
  'L': 1,
  'M': 1,
  'N': 1,
  'O': 1,
  'P': 1,
  'Q': 1,
  'R': 1,
  'S': 1,
  'T': 1,
  'U': 1,
  'V': 1,
  'W': 1,
  'X': 1,
  'Y': 1,
  'Z': 1,
  'Ä': 1,
  'Ö': 1,
  'Ñ': 1,
  'Ü': 1,
  '§': 1,
  '¿': 1,
  'a': 1,
  'b': 1,
  'c': 1,
  'd': 1,
  'e': 1,
  'f': 1,
  'g': 1,
  'h': 1,
  'i': 1,
  'j': 1,
  'k': 1,
  'l': 1,
  'm': 1,
  'n': 1,
  'o': 1,
  'p': 1,
  'q': 1,
  'r': 1,
  's': 1,
  't': 1,
  'u': 1,
  'v': 1,
  'w': 1,
  'x': 1,
  'y': 1,
  'z': 1,
  'ä': 1,
  'ö': 1,
  'ñ': 1,
  'ü': 1,
  'à': 1,
  '\f': 2,
  '^': 2,
  '{': 2,
  '}': 2,
  '\\': 2,
  '[': 2,
  '~': 2,
  ']': 2,
  '|': 2,
  '€': 2,
};

class GSM {
  static bool isUnicode(String content) {
    var chars = content.split('');
    var isUnicode = false;

    for (int i = 0; i < chars.length; i++) {
      String chart = chars[i];
      if (!charset7bit.containsKey(chart)) {
        isUnicode = true;
        break;
      }
    }
    return isUnicode;
  }

  static int getTotalLengthGSM(String content) {
    var chars = content.split('');
    var charLength = 0;
    for (int i = 0; i < chars.length; i++) {
      String chart = chars[i];
      charLength += charset7bit[chart] ?? 0;
    }
    return charLength;
  }

  static GSMData info(String? content) {
    if (content == null || content.isEmpty) {
      return GSMData(
        segments: 0,
        charsLeft: 160,
        charSet: CharSet.gsm,
        parts: [],
      );
    }

    bool isUnicodeText = isUnicode(content);
    var chars = content.split('');

    if (!isUnicodeText) {
      var totalLength = getTotalLengthGSM(content);
      if (totalLength <= 160) {
        return GSMData(
          segments: 1,
          charsLeft: 160 - totalLength,
          charSet: CharSet.gsm,
          parts: [content],
        );
      } else {
        List<String> parts = [];
        var maxLength = 153;
        var currentLength = 0;

        String partText = '';
        for (int i = 0; i < chars.length; i++) {
          String chart = chars[i];
          int size = charset7bit[chart] ?? 0;
          if ((currentLength + size) <= maxLength) {
            partText += chart;
            currentLength += size;
          } else {
            parts.add(partText);
            partText = '';
            partText += chart;
            currentLength = size;
          }
        }

        if (partText.isNotEmpty) {
          parts.add(partText);
        }

        return GSMData(
          segments: parts.length,
          charsLeft: maxLength - getTotalLengthGSM(parts[parts.length - 1]),
          charSet: CharSet.gsm,
          parts: parts,
        );
      }
    } else {
      if (content.length <= 70) {
        return GSMData(
          segments: 1,
          charsLeft: 70 - content.length,
          charSet: CharSet.unicode,
          parts: [content],
        );
      } else {
        var smsCount = (content.length / 67).ceil();
        List<String> parts = [];
        var maxLength = 67;

        for (var i = 0; i < smsCount; i++) {
          String partText =
              content.substring(i * maxLength, i * maxLength + maxLength);
          parts.add(partText);
        }
        return GSMData(
          segments: parts.length,
          charsLeft: maxLength - parts[parts.length - 1].length,
          charSet: CharSet.unicode,
          parts: parts,
        );
      }
    }
  }
}
