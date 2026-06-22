import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Web-only imports
import 'manual_page_web.dart' if (dart.library.io) 'manual_page_mobile.dart';

class ManualPage extends StatelessWidget {
  const ManualPage({super.key});

  static const _url = 'docs/user_manual.html';

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return buildWebView(_url);
    }
    return buildMobileView(_url);
  }
}
