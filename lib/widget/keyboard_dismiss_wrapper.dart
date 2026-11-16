import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frontend/utils/locale_provider.dart';

/// 全域鍵盤收合處理（主要針對 iOS / Android 原生 App）：
///
/// 1. 點擊輸入框以外的區域時自動收起鍵盤。
///    Flutter 預設只在 Web / 桌面端這麼做，原生手機端的觸控點擊不會失去焦點，
///    所以 Web 正常、App 卻關不掉鍵盤。
/// 2. 原生手機端鍵盤開啟時，在鍵盤上方顯示「完成」工具列，
///    解決 iOS 數字鍵盤（numberWithOptions）沒有 return / 確認鍵的問題。
class KeyboardDismissWrapper extends StatelessWidget {
  const KeyboardDismissWrapper({super.key, required this.child});

  final Widget child;

  static const double _barHeight = 44;

  static bool get _isNativeMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  Widget build(BuildContext context) {
    Widget content = Actions(
      actions: <Type, Action<Intent>>{
        EditableTextTapOutsideIntent: CallbackAction<EditableTextTapOutsideIntent>(
          onInvoke: (intent) {
            intent.focusNode.unfocus();
            return null;
          },
        ),
      },
      child: child,
    );

    if (!_isNativeMobile) return content;

    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;

    if (!isKeyboardVisible) return content;

    // 讓下方 Scaffold 多預留工具列的高度，避免工具列擋住正在輸入的欄位
    content = MediaQuery(
      data: mediaQuery.copyWith(
        viewInsets: mediaQuery.viewInsets.copyWith(bottom: keyboardHeight + _barHeight),
      ),
      child: content,
    );

    return Stack(
      children: [
        Positioned.fill(child: content),
        Positioned(
          left: 0,
          right: 0,
          bottom: keyboardHeight,
          height: _barHeight,
          child: Material(
            color: const Color(0xFFF1F3F6),
            elevation: 2,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0x22000000))),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
                child: Text(
                  context.l10n.keyboardDone,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

