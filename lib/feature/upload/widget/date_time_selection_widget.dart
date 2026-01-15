import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';

class DateTimeSelectionWidget extends StatelessWidget {
  const DateTimeSelectionWidget({
    super.key,
    required this.onDateSelected,
    required this.onTimeSelected,
    required this.onCameraCountSelected,
    required this.onFpsSelected,
    required this.selectedDate,
    required this.selectedTime,
    required this.selectedCameraCount,
    required this.selectedFps,
    required this.note,
    required this.onNoteSelected,
  });

  final Function(DateTime) onDateSelected;
  final Function(TimeOfDay) onTimeSelected;
  final Function(int) onCameraCountSelected;
  final Function(int) onFpsSelected;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final int selectedCameraCount;
  final int selectedFps;
  final String note;
  final Function(String) onNoteSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          spacing: 32,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            Row(
              spacing: 16,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    '日期',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'NotoSansTC',
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );

                      if (picked != null) {
                        onDateSelected(picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        hintText: '選擇日期',
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                      child: Text(
                        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              spacing: 16,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    '時間',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'NotoSansTC',
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: InkWell(
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );

                      if (picked != null) {
                        onTimeSelected(picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        hintText: '選擇時間',
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                      child: Text(
                        selectedTime.format(context),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            Row(
              spacing: 16,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    '相機數量',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'NotoSansTC',
                    ),
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton2<int>(
                    hint: const Row(
                      children: [
                        Text(
                          '相機數量',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'NotoSansTC',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    items: [1, 2, 3, 4, 5]
                        .map(
                          (item) => DropdownMenuItem<int>(
                            value: item,
                            child: Text(
                              item.toString(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'NotoSansTC',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    value: selectedCameraCount,
                    onChanged: (value) {
                      if (value != null) {
                        onCameraCountSelected(value);
                      }
                    },
                    buttonStyleData: ButtonStyleData(
                      width: 100,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      overlayColor: WidgetStateProperty.all(Colors.transparent),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                    iconStyleData: const IconStyleData(
                      icon: Icon(Icons.arrow_forward_ios_outlined),
                      iconSize: 12,
                    ),
                    dropdownStyleData: DropdownStyleData(
                      maxHeight: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      scrollbarTheme: ScrollbarThemeData(
                        radius: const Radius.circular(40),
                      ),
                    ),
                    menuItemStyleData: const MenuItemStyleData(
                      height: 40,
                      padding: EdgeInsets.only(left: 12, right: 12),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              spacing: 16,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    'FPS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'NotoSansTC',
                    ),
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton2<int>(
                    hint: const Row(
                      children: [
                        Text(
                          'FPS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'NotoSansTC',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    items: [30, 60]
                        .map(
                          (item) => DropdownMenuItem<int>(
                            value: item,
                            child: Text(
                              item.toString(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'NotoSansTC',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    value: selectedFps,
                    onChanged: (value) {
                      if (value != null) {
                        onFpsSelected(value);
                      }
                    },
                    buttonStyleData: ButtonStyleData(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      width: 100,
                      overlayColor: WidgetStateProperty.all(Colors.transparent),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                    iconStyleData: const IconStyleData(
                      icon: Icon(Icons.arrow_forward_ios_outlined),
                      iconSize: 12,
                    ),
                    dropdownStyleData: DropdownStyleData(
                      maxHeight: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      scrollbarTheme: ScrollbarThemeData(
                        radius: const Radius.circular(40),
                      ),
                    ),
                    menuItemStyleData: const MenuItemStyleData(
                      height: 40,
                      padding: EdgeInsets.only(left: 12, right: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              spacing: 16,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    '備註',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'NotoSansTC',
                    ),
                  ),
                ),
                if (constraints.maxWidth < 800)
                  Expanded(
                    // width: 500,
                    child: TextField(
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          onNoteSelected(value);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: '備註',
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: constraints.maxWidth * 0.6,
                    child: TextField(
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          onNoteSelected(value);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: '備註',
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
