import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:custom_sliding_segmented_control/custom_sliding_segmented_control.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:frontend/feature/record/record_controller.dart';
import 'package:frontend/feature/record/record_enums.dart';
import 'package:frontend/feature/record/record_state.dart';
import 'package:frontend/feature/record/widget/record_camera_view.dart';
import 'package:frontend/feature/upload/upload_controller.dart';
import 'package:frontend/feature/upload/widget/upload_enums.dart';
import 'package:frontend/widget/async_value_widget.dart';
import 'package:frontend/widget/rounded_box_widget.dart';
import 'package:frontend/entities/runner_info.dart';
import 'package:shimmer/shimmer.dart';

class RecordPage extends ConsumerStatefulWidget {
  const RecordPage({super.key});

  @override
  ConsumerState<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends ConsumerState<RecordPage> {
  final TextEditingController _roomController = TextEditingController();
  int _selectedCameraIndex = 0;
  int _createExpectedCount = 1;
  String _newRunnerName = '';
  final ExpansibleController _expansionController = ExpansibleController();
  bool? _lastReportedReady;

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordControllerProvider);
    final controller = ref.read(recordControllerProvider.notifier);

    // 監聽狀態變化來觸發動畫，而不使用會破壞動畫的 Key
    ref.listen(recordControllerProvider.select((s) => s.isRecordingEnabled), (
      prev,
      next,
    ) {
      if (next) {
        _expansionController.expand();
      } else {
        _expansionController.collapse();
      }
    });

    ref.listen(recordControllerProvider.select((s) => s.sharedRunSessionId), (
      prev,
      next,
    ) {
      if (next != null && next != prev) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AwesomeSnackbarContent(
              title: 'Success',
              message: '影片上傳成功！',
              contentType: ContentType.success,
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        );
      }
    });

    // 監聽轉向與相機狀態，同步 Readiness 到後端
    final orientation = MediaQuery.of(context).orientation;
    final isPortrait = orientation == Orientation.portrait;
    // 如果不參與錄影 (myCameraIndex == null)，則視為就緒
    // 如果參與錄影，則必須是橫放 (!isPortrait) 才視為就緒
    final currentIsReady = state.myCameraIndex == null || !isPortrait;

    if (_lastReportedReady != currentIsReady) {
      // 延遲一下確保 WebSocket 可能已連線（如果是剛進入房間）
      Future.microtask(() {
        if (mounted) {
          controller.updateReadyStatus(currentIsReady);
          setState(() {
            _lastReportedReady = currentIsReady;
          });
        }
      });
    }

    return state.status == RecordStatus.idle ||
            state.status == RecordStatus.connecting
        ? _buildInitialView(state, controller)
        : _buildRoomView(state, controller);
  }

  Widget _buildInitialView(RecordState state, RecordController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: MaxWidth(
                  maxWidth: 400,
                  child: Column(
                    spacing: 24,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            width: 3,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        child: Column(
                          spacing: 12,
                          children: [
                            Icon(
                              Icons.stars,
                              size: 48,
                              color: Theme.of(context).primaryColorDark,
                            ),
                            const Text(
                              '主控裝置',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              '負責控制所有裝置的開始與結束錄影',
                              textAlign: TextAlign.center,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('預計連線裝置數: '),
                                DropdownButton2<int>(
                                  value: _createExpectedCount,
                                  items: [1, 2, 3, 4, 5]
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e.toString()),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _createExpectedCount = v!),
                                  iconStyleData: const IconStyleData(
                                    icon: Icon(
                                      Icons.arrow_forward_ios_outlined,
                                    ),
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
                                ),
                              ],
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.black,
                                minimumSize: const Size(double.infinity, 48),
                              ),
                              onPressed: () =>
                                  controller.createRoom(_createExpectedCount),
                              child: const Text(
                                '建立錄影房間',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        '或',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            width: 3,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        child: Column(
                          spacing: 12,
                          children: [
                            Icon(
                              Icons.phonelink,
                              size: 48,
                              color: Theme.of(context).primaryColorDark,
                            ),
                            const Text(
                              '錄影手機',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextField(
                              controller: _roomController,
                              decoration: const InputDecoration(
                                hintText: '輸入房間號碼',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.meeting_room),
                              ),
                            ),
                            DropdownButtonFormField<int>(
                              value: _selectedCameraIndex,
                              decoration: const InputDecoration(
                                labelText: '選擇相機位置',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.camera_alt),
                              ),
                              items: List.generate(
                                5,
                                (i) => DropdownMenuItem(
                                  value: i,
                                  child: Text('相機 ${i + 1}'),
                                ),
                              ),
                              onChanged: (v) =>
                                  setState(() => _selectedCameraIndex = v!),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.black,
                                backgroundColor: Theme.of(context).primaryColor,
                                minimumSize: const Size(double.infinity, 48),
                              ),
                              onPressed: () {
                                if (_roomController.text.isNotEmpty) {
                                  controller.joinRoom(
                                    _roomController.text,
                                    _selectedCameraIndex,
                                  );
                                }
                              },
                              child: const Text(
                                '加入錄影房間',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (state.error != null)
                        Text(
                          state.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoomView(RecordState state, RecordController controller) {
    final connectedCameraIndexes = state.members
        .map((m) => m.cameraIndex)
        .whereType<int>()
        .toSet();
    final areAllCamerasConnected =
        state.expectedCameraCount > 0 &&
        List.generate(
          state.expectedCameraCount,
          (i) => i,
        ).every((i) => connectedCameraIndexes.contains(i));

    final participatingMembers = state.members.where(
      (m) => m.cameraIndex != null,
    );
    final areAllParticipatingReady = participatingMembers.every(
      (m) => m.isReady,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                child: MaxWidth(
                  maxWidth: 600,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 24,
                    children: [
                      Text(
                        '房間號碼: ${state.roomId}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: state.role == RecordRole.master
                              ? Colors.amber[100]
                              : Colors.blue[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '目前身份: ${state.role == RecordRole.master ? "主控端 (Master)" : "錄影端 (Slave)"}',
                          style: TextStyle(
                            color: state.role == RecordRole.master
                                ? Colors.amber[900]
                                : Colors.blue[900],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (state.role == RecordRole.master &&
                          state.status != RecordStatus.recording) ...[
                        _buildConfigSection(state, controller),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              width: 3,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              controller: _expansionController,
                              maintainState: true,
                              initiallyExpanded: state.isRecordingEnabled,
                              onExpansionChanged: (expanded) {
                                if (expanded != state.isRecordingEnabled) {
                                  if (expanded) {
                                    controller.toggleMasterRecording(true, 0);
                                  } else {
                                    controller.toggleMasterRecording(false);
                                  }
                                }
                              },
                              title: const Text(
                                '本機參與錄影',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: state.isRecordingEnabled
                                  ? Text('目前作為相機 ${state.myCameraIndex! + 1}')
                                  : const Text('僅作為主控端'),
                              trailing: Switch(
                                value: state.isRecordingEnabled,
                                onChanged: (v) {
                                  if (v) {
                                    controller.toggleMasterRecording(true, 0);
                                  } else {
                                    controller.toggleMasterRecording(false);
                                  }
                                },
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      const Text(
                                        '選擇本機相機編號:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          spacing: 8,
                                          children: List.generate(
                                            state.expectedCameraCount,
                                            (i) {
                                              return ChoiceChip(
                                                label: Text('相機 ${i + 1}'),
                                                selected:
                                                    state.myCameraIndex == i,
                                                onSelected: (selected) {
                                                  if (selected) {
                                                    controller
                                                        .toggleMasterRecording(
                                                          true,
                                                          i,
                                                        );
                                                  }
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (state.role == RecordRole.slave &&
                          state.status != RecordStatus.recording) ...[
                        const Text(
                          '更改相機位置:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        DropdownButtonFormField<int>(
                          value:
                              (state.myCameraIndex != null &&
                                  state.myCameraIndex! <
                                      (state.expectedCameraCount > 0
                                          ? state.expectedCameraCount
                                          : 5))
                              ? state.myCameraIndex
                              : null,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.camera_alt),
                          ),
                          items: List.generate(
                            state.expectedCameraCount > 0
                                ? state.expectedCameraCount
                                : 5,
                            (i) => DropdownMenuItem(
                              value: i,
                              child: Text('相機 ${i + 1}'),
                            ),
                          ).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              controller.joinRoom(state.roomId!, v);
                            }
                          },
                        ),
                      ],
                      const Text(
                        '已連線設備清單:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      RoundedBoxWidget(
                        child: state.members.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(32),
                                child: Text('等待連線中...'),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: state.members.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(),
                                itemBuilder: (context, index) {
                                  final member = state.members[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      child: Text('${index + 1}'),
                                    ),
                                    title: Text('設備 ID: ${member.id}'),
                                    subtitle: Text(
                                      member.cameraIndex != null
                                          ? '相機 ${member.cameraIndex! + 1}'
                                          : '尚未分配相機',
                                    ),
                                    trailing: Icon(
                                      member.isReady
                                          ? Icons.check_circle
                                          : Icons.error,
                                      color: member.isReady
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  );
                                },
                              ),
                      ),
                      if (state.role == RecordRole.master) ...[
                        if (state.status == RecordStatus.recording) ...[
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SpinKitDoubleBounce(color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text(
                                '正在錄影中...',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 64,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: () => controller.stopRecording(),
                            child: const Text(
                              '停止錄影並上傳',
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                        ] else ...[
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 64,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: () {
                              if (state.runnerId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: AwesomeSnackbarContent(
                                      title: 'Error',
                                      message: '請先選擇選手才能開始錄影',
                                      contentType: ContentType.failure,
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.transparent,
                                    elevation: 0,
                                  ),
                                );
                                return;
                              }
                              if (!areAllCamerasConnected) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: AwesomeSnackbarContent(
                                      title: 'Error',
                                      message:
                                          '尚有相機未連線 (目前: ${connectedCameraIndexes.length}/${state.expectedCameraCount})',
                                      contentType: ContentType.failure,
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.transparent,
                                    duration: const Duration(seconds: 2),
                                    elevation: 0,
                                  ),
                                );
                                return;
                              }

                              if (!areAllParticipatingReady) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: AwesomeSnackbarContent(
                                      title: 'Warning',
                                      message: '部分相機尚未橫放裝置 (未就緒)',
                                      contentType: ContentType.warning,
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.transparent,
                                    duration: const Duration(seconds: 2),
                                    elevation: 0,
                                  ),
                                );
                                return;
                              }
                              controller.startRecording();
                            },
                            child: const Text(
                              '開始同步錄影',
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                        ],
                      ],
                      if (state.role == RecordRole.slave ||
                          state.isRecordingEnabled) ...[
                        const RecordCameraView(),
                        if (state.role != RecordRole.master) ...[
                          const SizedBox(height: 16),
                          const Text('請留在本頁影面，等待主控端發送錄影指令...'),
                        ],
                      ],
                      TextButton.icon(
                        icon: const Icon(Icons.exit_to_app),
                        onPressed: () => controller.leaveRoom(),
                        label: const Text('離開房間'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfigSection(RecordState state, RecordController controller) {
    final runners = ref.watch(uploadRunnerListProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(width: 3, color: Theme.of(context).primaryColor),
      ),
      child: Column(
        spacing: 16,
        children: [
          const Text(
            '錄影參數設定',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CustomSlidingSegmentedControl<RunnerSource>(
                initialValue: state.runnerSource,
                customSegmentSettings: CustomSegmentSettings(
                  borderRadius: const BorderRadius.all(Radius.circular(25)),
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
                  if (value != null) controller.setRunnerSource(value);
                },
                children: {
                  RunnerSource.select: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '選擇選手',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: state.runnerSource == RunnerSource.select
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  RunnerSource.add: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '新增選手',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: state.runnerSource == RunnerSource.add
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                },
              ),
              if (state.runnerSource == RunnerSource.select)
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 200),
                  child: AsyncValueWidget(
                    value: runners,
                    loading: Shimmer.fromColors(
                      baseColor: Theme.of(context).primaryColorDark,
                      highlightColor: Theme.of(
                        context,
                      ).primaryColor.withOpacity(0.3),
                      child: Container(
                        height: 40,
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide()),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '選擇選手',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'NotoSansTC',
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_outlined, size: 12),
                          ],
                        ),
                      ),
                    ),
                    data: (List<RunnerInfo> items) =>
                        DropdownButtonHideUnderline(
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
                                  (RunnerInfo item) => DropdownMenuItem<String>(
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
                            value: state.runnerId,
                            onChanged: (v) => controller.setRunner(v),
                            buttonStyleData: ButtonStyleData(
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
                        ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 200),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: TextField(
                          style: const TextStyle(
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
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                          onChanged: (v) => setState(() => _newRunnerName = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.black,
                          backgroundColor: Theme.of(context).primaryColor,
                        ),
                        onPressed: () async {
                          if (_newRunnerName.isNotEmpty) {
                            await controller.addRunner(_newRunnerName);
                            setState(() {
                              _newRunnerName = '';
                            });
                          }
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
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          Row(
            spacing: 16,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Text(
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
                  hint: const Text(
                    'FPS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'NotoSansTC',
                    ),
                  ),
                  value: state.fps,
                  items: [30, 60]
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            e.toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'NotoSansTC',
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => v != null ? controller.setFps(v) : null,
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
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Text(
                  '備註',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'NotoSansTC',
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'NotoSansTC',
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '備註(選填)',
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (v) => controller.setNote(v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MaxWidth extends StatelessWidget {
  final double maxWidth;
  final Widget child;
  const MaxWidth({super.key, required this.maxWidth, required this.child});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );
  }
}
