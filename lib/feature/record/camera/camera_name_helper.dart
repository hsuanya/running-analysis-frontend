import 'package:frontend/l10n/generated/app_localizations.dart';

/// 將相機硬體名稱或既有格式化名稱依據目前 UI 語系 (l10n) 進行在地化轉換
String localizeCameraName(String? name, AppLocalizations l10n) {
  if (name == null || name.isEmpty) return '';
  final lower = name.toLowerCase();

  if (lower.contains('triple') || name.contains('三鏡頭')) {
    return l10n.cameraRearTriple;
  }
  if (lower.contains('ultra wide') || name.contains('超廣角')) {
    return l10n.cameraRearUltraWide;
  }
  if (lower.contains('telephoto') ||
      name.contains('望遠') ||
      lower.contains('periscope') ||
      name.contains('潛望') ||
      name.contains('長焦')) {
    return l10n.cameraRearTelephoto;
  }
  if (lower.contains('dual wide') || name.contains('雙廣角')) {
    return l10n.cameraRearDualWide;
  }
  if (lower.contains('dual') || name.contains('雙鏡頭')) {
    return l10n.cameraRearDual;
  }
  if (name == '後置相機' ||
      lower == 'back camera' ||
      lower == 'rear camera' ||
      lower.contains('main') ||
      name.contains('主鏡頭')) {
    final idMatch = RegExp(r'[\(（](?:鏡頭|Camera)\s*(\d+)[\)）]', caseSensitive: false).firstMatch(name);
    if (idMatch != null) {
      final id = idMatch.group(1)!;
      return id == '0' ? l10n.cameraRearMainWithId(id) : l10n.cameraRearWithId(id);
    }
    return l10n.cameraRearMain;
  }
  if (name == '前置相機' || lower == 'front camera' || lower.contains('front') || name.contains('前置')) {
    final idMatch = RegExp(r'[\(（](?:鏡頭|Camera)\s*(\d+)[\)）]', caseSensitive: false).firstMatch(name);
    if (idMatch != null) {
      final id = idMatch.group(1)!;
      return l10n.cameraFrontWithId(id);
    }
    return l10n.cameraFront;
  }

  // 檢查是否有 "(鏡頭 X)" 或 "(Camera X)"
  final idMatch = RegExp(r'[\(（](?:鏡頭|Camera)\s*(\d+)[\)）]', caseSensitive: false).firstMatch(name);
  if (idMatch != null) {
    final id = idMatch.group(1)!;
    if (lower.contains('front') || name.contains('前置')) {
      return l10n.cameraFrontWithId(id);
    }
    return id == '0' ? l10n.cameraRearMainWithId(id) : l10n.cameraRearWithId(id);
  }

  // 檢查是否有 "後置相機 X" 或 "Rear Camera X"
  final indexMatch = RegExp(r'(?:後置相機|Rear Camera)\s*(\d+)', caseSensitive: false).firstMatch(name);
  if (indexMatch != null) {
    final num = int.tryParse(indexMatch.group(1)!) ?? 1;
    return l10n.cameraRearWithIndex(num);
  }

  // 檢查是否有 "前置相機 X" 或 "Front Camera X"
  final frontIndexMatch = RegExp(r'(?:前置相機|Front Camera)\s*(\d+)', caseSensitive: false).firstMatch(name);
  if (frontIndexMatch != null) {
    final num = int.tryParse(frontIndexMatch.group(1)!) ?? 1;
    return l10n.cameraFrontWithIndex(num);
  }

  // 檢查是否有 "外接鏡頭 X" 或 "External Camera X"
  final extIndexMatch = RegExp(r'(?:外接鏡頭|External Camera)\s*(\d+)', caseSensitive: false).firstMatch(name);
  if (extIndexMatch != null) {
    final num = int.tryParse(extIndexMatch.group(1)!) ?? 1;
    return l10n.cameraExternalWithIndex(num);
  }

  return name;
}
