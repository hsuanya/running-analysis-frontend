import 'package:flutter/material.dart';

class RunnerHistoryPlaceholder extends StatelessWidget {
  const RunnerHistoryPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> headers = ["日期時間", "相機數量", "總時間", "備註"];
    final List<String> values = ["年-月-日 時:分:秒", "{1, 2, 3, 4, 5}", "總時間", "備註"];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Table(
        border: TableBorder(
          horizontalInside: BorderSide(
            width: 3,
            color: Colors.white,
          ), // 只要橫向分隔線
          verticalInside: BorderSide(width: 3, color: Colors.white),
          top: BorderSide.none, // 不要最上面
          bottom: BorderSide.none, // 不要最下面
          left: BorderSide.none, // 不要最左邊
          right: BorderSide.none, // 不要最右邊
        ),
        children: [
          // 表格標題
          TableRow(
            children: headers
                .map(
                  (header) => Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text(
                      header,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis, // 單行，不換行
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                )
                .toList(),
          ),
          for (int i = 0; i < 2; i++)
            // 表格內容
            TableRow(
              children: [
                for (int j = 0; j < headers.length; j++)
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text(
                      values[j],
                      textAlign: TextAlign.center,
                      softWrap: true, // 允許換行
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
