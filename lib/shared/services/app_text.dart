import 'language_settings.dart';

class AppText {
  static bool get isEnglish => LanguageSettings.current.code == 'en';

  static String t({required String id, required String en}) {
    return isEnglish ? en : id;
  }
}
