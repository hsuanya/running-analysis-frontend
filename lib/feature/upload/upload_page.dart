import 'package:custom_sliding_segmented_control/custom_sliding_segmented_control.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/entities/runner_info.dart';
import 'package:frontend/feature/upload/upload_controller.dart';
import 'package:frontend/feature/upload/upload_provider.dart';
import 'package:frontend/feature/upload/widget/upload_all_view.dart';
import 'package:frontend/feature/upload/widget/upload_seperately_view.dart';
import 'package:frontend/widget/async_value_ui.dart';
import 'package:frontend/widget/async_value_widget.dart';
import 'package:frontend/widget/loading_overlay.dart';
import 'package:frontend/feature/upload/widget/upload_enums.dart';
import 'package:frontend/feature/upload/widget/upload_form_provider.dart';
import 'package:shimmer/shimmer.dart';

class UploadPage extends ConsumerStatefulWidget {
  const UploadPage({super.key});

  @override
  ConsumerState<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends ConsumerState<UploadPage> {
  @override
  Widget build(BuildContext context) {
    final selectedUploadType = ref.watch(uploadTypeProvider);
    final selectedRunnerSource = ref.watch(runnerSourceProvider);
    final name = ref.watch(runnerNameInputProvider);

    final typeNotifier = ref.read(uploadTypeProvider.notifier);
    final sourceNotifier = ref.read(runnerSourceProvider.notifier);
    final nameNotifier = ref.read(runnerNameInputProvider.notifier);

    ref.listen<AsyncValue>(
      uploadControllerProvider,
      (_, state) => state.showAlertDialogOnError(context),
    );
    final state = ref.watch(uploadControllerProvider);
    final runners = ref.watch(uploadRunnerListProvider);
    final selectedRunnerId = ref.watch(uploadSelectedRunnerIdProvider);

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(12),
          child: Column(
            spacing: 16,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                runSpacing: 16,
                spacing: 32,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 16,
                    children: [
                      CustomSlidingSegmentedControl<RunnerSource>(
                        initialValue: selectedRunnerSource,
                        customSegmentSettings: CustomSegmentSettings(
                          borderRadius: BorderRadius.all(Radius.circular(25)),
                        ),
                        decoration: BoxDecoration(
                          color: CupertinoColors.tertiarySystemFill,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        thumbDecoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        onValueChanged: (RunnerSource? value) {
                          if (value == null) return;
                          sourceNotifier.state = value;
                        },
                        children: <RunnerSource, Widget>{
                          RunnerSource.select: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '選擇選手',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    selectedRunnerSource == RunnerSource.select
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          RunnerSource.add: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '新增選手',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    selectedRunnerSource == RunnerSource.add
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        },
                      ),
                      if (selectedRunnerSource == RunnerSource.select)
                        AsyncValueWidget(
                          value: runners,
                          loading: Shimmer.fromColors(
                            baseColor: Theme.of(context).primaryColorDark,
                            highlightColor: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.3),
                            child: Container(
                              width: 100,
                              height: 40,
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide()),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '選擇選手',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'NotoSansTC',
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_outlined,
                                    size: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          data: (List<RunnerInfo> items) {
                            return DropdownButtonHideUnderline(
                              child: DropdownButton2<String>(
                                hint: const Row(
                                  children: [
                                    Text(
                                      '選擇選手',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'NotoSansTC',
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                items: items
                                    .map(
                                      (RunnerInfo item) =>
                                          DropdownMenuItem<String>(
                                            value: item.id,
                                            child: Text(
                                              item.name,
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
                                value: selectedRunnerId,
                                onChanged: (value) {
                                  ref
                                          .read(
                                            uploadSelectedRunnerIdProvider
                                                .notifier,
                                          )
                                          .state =
                                      value;
                                },
                                buttonStyleData: ButtonStyleData(
                                  width: 100,
                                  overlayColor: WidgetStateProperty.all(
                                    Colors.transparent,
                                  ),
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
                            );
                          },
                        ),
                    ],
                  ),
                ],
              ),
              if (selectedRunnerSource == RunnerSource.add)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 100,
                      child: TextField(
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'NotoSansTC',
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: '選手姓名',
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
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        onChanged: (value) {
                          nameNotifier.state = value;
                        },
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: Theme.of(context).primaryColor,
                      ),
                      onPressed: () async {
                        final newRunner = await ref
                            .read(uploadRunnerListProvider.notifier)
                            .addRunner(name);

                        sourceNotifier.state = RunnerSource.select;
                        ref
                                .read(uploadSelectedRunnerIdProvider.notifier)
                                .state =
                            newRunner.id;
                      },
                      label: const Text(
                        '新增',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'NotoSansTC',
                        ),
                      ),
                      icon: const Icon(
                        Icons.add_circle_rounded,
                        color: Colors.white,
                        size: 24,
                        // weight: 800,
                      ),
                    ),
                  ],
                ),

              if (selectedRunnerSource != RunnerSource.add)
                CustomSlidingSegmentedControl<UploadType>(
                  customSegmentSettings: CustomSegmentSettings(
                    borderRadius: BorderRadius.all(Radius.circular(25)),
                  ),
                  initialValue: selectedUploadType,
                  onValueChanged: (UploadType? value) {
                    if (value == null) return;
                    typeNotifier.state = value;
                  },
                  decoration: BoxDecoration(
                    color: CupertinoColors.tertiarySystemFill,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  thumbDecoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  children: <UploadType, Widget>{
                    UploadType.all: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '一起上傳',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: selectedUploadType == UploadType.all
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    UploadType.seperated: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '分別上傳',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: selectedUploadType == UploadType.seperated
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  },
                ),
              if (selectedRunnerSource != RunnerSource.add)
                selectedUploadType == UploadType.all
                    ? const UploadAllView()
                    : const UploadSeperatelyView(),
            ],
          ),
        ),
        if (state.isLoading) const LoadingOverlay(),
      ],
    );
  }
}
