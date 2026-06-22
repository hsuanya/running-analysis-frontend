# Running Analysis Frontend 專案結構

本文整理 `/home/jeter/running-analysis-frontend` 的資料夾編排、目前整潔度，以及之後新增檔案時應該放置的位置。

## 整體評估

目前主程式碼的分層大致乾淨，Flutter App 的核心程式集中在 `lib/`，並依照功能切成 `feature/`、`backend/`、`entities/`、`utils/`、`widget/`。這個方向是清楚的。

本次整理後，文件與圖片資源已統一到 Web 可直接使用的位置：

- 使用者手冊與手冊圖片統一放在 `web/docs/`，讓 Flutter Web 可以直接用 `docs/user_manual.html` 路徑讀取。
- 根目錄的 `docs/` 重複副本已移除，避免同一份手冊維護兩份。
- 舊截圖暫存資料夾 `picture/` 已移除，避免圖片散落。
- `.claude/` 是工作區輔助資料，不屬於產品程式碼，已加入 `.gitignore`。

## 建議目錄結構

```text
running-analysis-frontend/
├── lib/                         # Flutter / Dart 主程式碼
│   ├── main.dart                 # App 入口
│   ├── backend/                  # 後端資料存取層
│   ├── entities/                 # 資料模型
│   ├── feature/                  # 各功能頁面與功能內元件
│   ├── utils/                    # 共用工具、API endpoint、路由、設定
│   └── widget/                   # 跨功能共用 UI 元件
├── assets/                       # App 內使用的靜態資源
├── web/                          # Flutter Web 入口與 Web 專用資源
│   ├── docs/                     # Web 使用者手冊與手冊圖片
│   └── icons/                    # PWA / Web app icon
├── test/                         # Flutter 測試
├── android/                      # Android 平台專案
├── ios/                          # iOS 平台專案
├── macos/                        # macOS 平台專案
├── linux/                        # Linux 平台專案
├── windows/                      # Windows 平台專案
├── pubspec.yaml                  # 套件、assets、Flutter 設定
├── pubspec.lock                  # 套件版本鎖定
├── analysis_options.yaml         # Dart lint 設定
├── README.md                     # 專案簡介
├── PROJECT_OVERVIEW.md           # 專案功能與技術導讀
└── PROJECT_STRUCTURE.md          # 本文件
```

## lib 目錄放置規則

`lib/` 是主要開發區，建議維持以下分工。

### `lib/main.dart`

放 App 啟動入口。

適合放：

- `ProviderScope`
- `MaterialApp.router`
- 全域 wrapper，例如 toast wrapper
- App theme 的起始設定

不適合放：

- API 呼叫
- 頁面業務邏輯
- 大量 widget 實作

### `lib/backend/`

放和後端資料來源有關的程式。

目前內容：

```text
lib/backend/
├── backend_interface.dart
├── backend_provider.dart
├── fake_backend_repo.dart
├── rest_backend_repo.dart
└── video_playback_state_provider.dart
```

適合放：

- repository interface
- REST repository
- fake repository
- 後端 provider
- 和後端資料狀態密切相關的 provider

不適合放：

- UI widget
- page layout
- 純資料模型

### `lib/entities/`

放資料模型。

目前內容：

```text
lib/entities/
├── angle_data.dart
├── graph_data.dart
├── run_session_info.dart
├── runner_info.dart
├── unanalyzed_run_session_info.dart
├── upload_seperately_status.dart
├── upload_video_file.dart
└── video_playback.dart
```

適合放：

- API response model
- UI 與 backend 共用的資料型別
- enum 或狀態資料類別

不適合放：

- API endpoint 字串
- Dio request 程式
- Widget

### `lib/feature/`

放功能模組。每個主要功能一個資料夾。

目前內容：

```text
lib/feature/
├── home_page.dart
├── manual/
├── playback/
├── record/
├── splash/
└── upload/
```

建議規則：

- 新頁面放在對應功能資料夾。
- 功能只自己使用的 widget 放在該功能的 `widget/`。
- 功能只自己使用的 controller / provider 放在該功能資料夾。
- 跨功能共用的 widget 才移到 `lib/widget/`。

#### `lib/feature/manual/`

放使用手冊頁面。

目前內容：

```text
lib/feature/manual/
├── manual_page.dart
├── manual_page_mobile.dart
└── manual_page_web.dart
```

適合放：

- 手冊入口頁
- 手冊的 mobile / web 版面
- 手冊頁專用 widget

#### `lib/feature/playback/`

放回放與分析結果顯示。

目前內容：

```text
lib/feature/playback/
├── playback_page.dart
├── playback_provider.dart
├── placeholder/
├── shimmer/
└── widget/
```

適合放：

- 回放頁面
- 回放狀態 provider
- 影片播放器
- 圖表
- 分析數據表格
- runner history
- loading placeholder / shimmer

#### `lib/feature/record/`

放同步錄影功能。

目前內容：

```text
lib/feature/record/
├── record_controller.dart
├── record_enums.dart
├── record_page.dart
├── record_state.dart
└── widget/
```

適合放：

- 錄影頁面
- 錄影 controller
- 錄影狀態
- 相機畫面 widget

#### `lib/feature/upload/`

放影片上傳功能。

目前內容：

```text
lib/feature/upload/
├── upload_controller.dart
├── upload_page.dart
├── upload_provider.dart
└── widget/
```

適合放：

- 上傳頁面
- 一次上傳流程
- 分別上傳流程
- 錨點設定 dialog
- 上傳表單 provider / controller

### `lib/utils/`

放跨功能共用工具。

目前內容：

```text
lib/utils/
├── api.dart
├── combine_date_and_time.dart
├── config.dart
├── download_file_web.dart
├── net_utils.dart
├── router.dart
└── test_data.dart
```

適合放：

- API endpoint 常數
- 路由設定
- App config
- 日期或格式轉換工具
- Web download helper
- 測試假資料

不適合放：

- 大型 feature controller
- 頁面 widget
- 後端 repository 實作

### `lib/widget/`

放跨功能共用的 UI 元件。

目前內容：

```text
lib/widget/
├── async_value_ui.dart
├── async_value_widget.dart
├── loading_icon.dart
├── loading_overlay.dart
├── processing_progress_widget.dart
└── rounded_box_widget.dart
```

適合放：

- loading overlay
- async value wrapper
- 多個功能都會使用的共用元件

不適合放：

- 只在 playback 使用的 widget
- 只在 upload 使用的 widget
- 含有特定頁面業務邏輯的 widget

## 文件與圖片放置規則

### `web/docs/`

作為 Flutter Web 可直接公開存取的使用者手冊位置。

適合放：

- `USER_MANUAL.md`
- `user_manual.html`
- `index.html`
- `web/docs/assets/` 手冊圖片
- 需要從 Web App 直接開啟的文件

注意事項：

- 不再新增根目錄 `docs/`，避免手冊出現兩份副本。
- 手冊頁目前透過 `docs/user_manual.html` 開啟；在 Flutter Web 專案中，這個路徑會對應到 `web/docs/user_manual.html`。

### `picture/`

`picture/` 已移除，後續不建議再新增。

建議：

- 若圖片用於使用手冊，放到 `web/docs/assets/`。
- 若圖片只用於開發暫存，不建議 commit。

### `assets/`

放 App 執行時會載入的資源。

目前內容：

```text
assets/
├── icon.png
└── splash.json
```

適合放：

- App icon
- Lottie animation
- App runtime 需要的圖片、字型或動畫

不適合放：

- 使用手冊截圖
- 文件輸出檔
- 開發暫存圖片

## 平台目錄放置規則

以下資料夾多數由 Flutter 管理，平常不應手動大幅調整：

```text
android/
ios/
macos/
linux/
windows/
web/
```

適合修改：

- App icon
- package name / bundle id
- platform permission
- plugin 產生的 registrant 檔案
- Web manifest / favicon / icons

不適合放：

- Dart 業務邏輯
- 共用 UI 元件
- API model

## 建議整理清單

建議優先處理以下項目，讓 repository 更乾淨。

1. 更新 `README.md`。
   - 目前仍是 Flutter 預設內容，建議改成專案名稱、啟動方式、建置方式、主要文件連結。

2. 保持 feature-based 分層。
   - 新功能一律放進 `lib/feature/<feature_name>/`。
   - 只有跨功能共用的 widget 才放 `lib/widget/`。
   - 只有跨功能共用的工具才放 `lib/utils/`。

## 新檔案放置速查

| 新檔案類型 | 建議位置 |
|---|---|
| 新頁面 | `lib/feature/<feature_name>/<feature_name>_page.dart` |
| 某頁專用 widget | `lib/feature/<feature_name>/widget/` |
| 某頁專用 controller | `lib/feature/<feature_name>/` |
| 某頁專用 provider | `lib/feature/<feature_name>/` |
| 後端 API 實作 | `lib/backend/` |
| API endpoint 常數 | `lib/utils/api.dart` |
| 路由 | `lib/utils/router.dart` |
| 資料模型 | `lib/entities/` |
| 共用 UI widget | `lib/widget/` |
| 共用工具 function | `lib/utils/` |
| App runtime 圖片或動畫 | `assets/` |
| 使用手冊文件 | `web/docs/` |
| 使用手冊圖片 | `web/docs/assets/` |
| Web 公開文件 | `web/docs/` |
| Flutter 測試 | `test/` |
