# Graph Report - kamdhenu  (2026-08-26)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 2041 nodes · 2815 edges · 83 communities (75 shown, 8 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 18 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `926d4e16`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Win32Window
- FieldTrackingService
- allowances_screen.dart
- lib/features/dashboard/presentation/employee_dashboard_screen.dart
- lib/features/dynamic/presentation/dynamic_capability_screen.dart
- GeneratedPluginRegistrant.swift
- lib/core/design/app_design.dart
- attendance_screen.dart
- app_database.dart
- app_icons.dart
- tracking_repository.dart
- StatelessWidget
- my_application.cc
- auth_session.dart
- field_tracking_service.dart
- app_session_controller.dart
- tracking_controller.dart
- tracking_screen.dart
- lib/features/auth/presentation/login_screen.dart
- playful_widgets.dart
- main.dart
- local_sync_gateway.dart
- field_api.dart
- core/database/app_database.dart
- kernel_responsibility_screen.dart
- lib/features/dashboard/presentation/employee_profile_tab.dart
- backend_auth_gateway.dart
- StatefulWidget
- MotionGate
- package:flutter/material.dart
- device_connectivity_gateway.dart
- wWinMain
- tenant_config.dart
- auth_gateway.dart
- sync_gateway.dart
- mobile_capability.dart
- mock_auth_gateway.dart
- offline_record_queue.dart
- offline_submission_queue.dart
- offline_attendance_queue.dart
- device_identity.dart
- core/session/app_session_controller.dart
- native_tracking_repository.dart
- status_pill.dart
- static const
- placeholder_feature_screen.dart
- api_config.dart
- responsibility_runtime_api.dart
- Exception
- editorial-ui-20260826-013104/lib/features/dashboard/presentation/employee_dashboard_screen.dart
- enquiry_form_screen.dart
- AppSessionController
- String?
- cms-sovereignty-20260825-231628/lib/features/dashboard/presentation/employee_dashboard_screen.dart
- LaunchImage.imageset/README.md
- cms-sovereignty-finish-20260825-231953/employee_dashboard_screen.dart
- editorial-ui-20260826-013104/lib/features/dynamic/presentation/dynamic_capability_screen.dart
- README.md
- cms-sovereignty-20260825-231628/lib/features/dynamic/presentation/dynamic_capability_screen.dart
- TrackingStore
- MainActivity.kt
- manifest.json
- WidgetsBindingObserver
- FieldTrackingService.kt
- _ReferencePickerSheet
- employee-own-history-v2-20260826-042335/lib/features/dynamic/presentation/dynamic_capability_screen.dart
- initial-state-runtime-20260826-022320/lib/features/dynamic/presentation/dynamic_capability_screen.dart
- semantic-runtime-v2-20260826-033804/lib/features/dynamic/presentation/dynamic_capability_screen.dart
- editorial-ui-20260826-013104/lib/core/design/app_design.dart
- editorial-ui-20260826-013104/lib/features/dashboard/presentation/employee_profile_tab.dart
- editorial_backdrop.dart
- editorial-ui-20260826-013104/lib/features/auth/presentation/login_screen.dart
- State
- semantic-runtime-v2-20260826-033804/lib/core/offline/offline_record_queue.dart
- firebase_options.dart
- AllowancesScreen
- _ClaimSheet
- _KernelResponsibilityScreenState

## God Nodes (most connected - your core abstractions)
1. `Win32Window` - 24 edges
2. `FieldTrackingService` - 24 edges
3. `AppSessionController` - 24 edges
4. `TrackingStore` - 16 edges
5. `MessageHandler` - 12 edges
6. `MobileCapability` - 12 edges
7. `TrackingController` - 12 edges
8. `MotionGate` - 11 edges
9. `FlutterWindow` - 10 edges
10. `MainActivity` - 10 edges

## Surprising Connections (you probably didn't know these)
- `Win32Window::Win32Window()` --calls--> `Destroy`  [INFERRED]
  windows/runner/win32_window.cpp → windows/runner/win32_window.h
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  windows/runner/main.cpp → windows/runner/utils.cpp
- `FieldTrackingService` --references--> `MotionGate`  [EXTRACTED]
  android/app/src/main/kotlin/com/example/salesapp/tracking/FieldTrackingService.kt → android/app/src/main/kotlin/com/example/salesapp/tracking/MotionGate.kt
- `FieldTrackingService` --references--> `TrackingStore`  [EXTRACTED]
  android/app/src/main/kotlin/com/example/salesapp/tracking/FieldTrackingService.kt → android/app/src/main/kotlin/com/example/salesapp/tracking/TrackingStore.kt
- `OnCreate` --calls--> `RegisterPlugins()`  [INFERRED]
  windows/runner/flutter_window.h → windows/flutter/generated_plugin_registrant.cc

## Import Cycles
- None detected.

## Communities (83 total, 8 thin omitted)

### Community 0 - "Win32Window"
Cohesion: 0.05
Nodes (57): PluginRegistry, RECT, unique_ptr, RegisterPlugins(), DartProject, HWND, LPARAM, LRESULT (+49 more)

### Community 2 - "allowances_screen.dart"
Cohesion: 0.03
Nodes (71): active, _addReceipt, border, build, busy, claim, _ClaimDraft, _ClaimFact (+63 more)

### Community 3 - "lib/features/dashboard/presentation/employee_dashboard_screen.dart"
Cohesion: 0.03
Nodes (74): ../../../core/offline/offline_submission_queue.dart, approvalCount, _approvals, _blockedWork, build, capability, _capabilityHint, _capabilityNeedsTracking (+66 more)

### Community 4 - "lib/features/dynamic/presentation/dynamic_capability_screen.dart"
Cohesion: 0.03
Nodes (62): action, _ActionCard, actionCount, _actionVisible, _applyOptimisticRecord, build, _buildField, _cacheKey (+54 more)

### Community 5 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.06
Nodes (30): Any, Cocoa, connectivity_plus, file_selector_macos, firebase_core, firebase_remote_config, Flutter, FlutterAppDelegate (+22 more)

### Community 6 - "lib/core/design/app_design.dart"
Cohesion: 0.04
Nodes (51): amber, AppDesign, blue, canvas, controlRadius, editorialCurve, editorialDuration, faint (+43 more)

### Community 7 - "attendance_screen.dart"
Cohesion: 0.04
Nodes (44): ../../../core/offline/offline_attendance_queue.dart, ../../../core/services/media/local_photo_store.dart, delete, _extension, LocalPhotoStore, persist, AttendanceScreen, _AttendanceScreenState (+36 more)

### Community 8 - "app_database.dart"
Cohesion: 0.06
Nodes (33): Database?, checkIn, checkOut, _createBaseTables, _createCacheTable, _createTrackingTable, _db, _emitPendingCount (+25 more)

### Community 9 - "app_icons.dart"
Cohesion: 0.04
Nodes (43): alert, AppIcons, attendance, _backendIcons, camera, chart, check, chevronRight (+35 more)

### Community 10 - "tracking_repository.dart"
Cohesion: 0.06
Nodes (30): accuracy, accuracyM, acknowledge, active, currentLocation, CurrentLocationFix, distanceKm, distanceM (+22 more)

### Community 11 - "StatelessWidget"
Cohesion: 0.04
Nodes (47): _CapabilityRow, _Header, _Metric, _QuickResponsibilityGrid, _QuietState, _WorkNotice, _CapabilityList, _CapabilityRow (+39 more)

### Community 12 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 13 - "auth_session.dart"
Cohesion: 0.06
Nodes (30): app_user.dart, DateTime?, AppUser, department, designation, roles, accessToken, AuthSession (+22 more)

### Community 14 - "field_tracking_service.dart"
Cohesion: 0.09
Nodes (21): double get, _accessToken, currentPosition, distanceKm, _distanceM, _employeeId, ensurePermission, _flush (+13 more)

### Community 15 - "app_session_controller.dart"
Cohesion: 0.04
Nodes (46): DateTime? get, authGateway, _bindOfflineScope, _checkingRevision, checkWorkspaceRevision, _compatQueuePending, connectivity, connectivityGateway (+38 more)

### Community 16 - "tracking_controller.dart"
Cohesion: 0.08
Nodes (23): ../../../core/config/field_api.dart, TrackingSnapshot, active, _autoStarting, currentLocation, dispose, distanceKm, ensureAutomatic (+15 more)

### Community 17 - "tracking_screen.dart"
Cohesion: 0.11
Nodes (17): build, controller, distanceKm, icon, _InfoCard, label, _MeterHero, _positionText (+9 more)

### Community 18 - "lib/features/auth/presentation/login_screen.dart"
Cohesion: 0.13
Nodes (14): ../../../core/design/app_design.dart, build, _companyCodeController, controller, createState, dispose, _employeeController, _error (+6 more)

### Community 19 - "playful_widgets.dart"
Cohesion: 0.11
Nodes (17): background, badge, build, eyebrow, foreground, FunPill, FunSectionTitle, icon (+9 more)

### Community 20 - "main.dart"
Cohesion: 0.11
Nodes (18): app/brixta_app.dart, core/config/remote_config_service.dart, core/config/tenant_config.dart, core/device/device_identity.dart, core/services/auth/backend_auth_gateway.dart, core/services/connectivity/device_connectivity_gateway.dart, core/services/sync/local_sync_gateway.dart, core/services/sync/sync_transport.dart (+10 more)

### Community 21 - "local_sync_gateway.dart"
Cohesion: 0.12
Nodes (16): ../connectivity/connectivity_gateway.dart, AppDatabase, changes, connectivityGateway, _connectivitySubscription, _controller, _current, database (+8 more)

### Community 22 - "field_api.dart"
Cohesion: 0.10
Nodes (19): api_config.dart, dart:convert, int?, accessToken, _client, code, _decode, deleteJson (+11 more)

### Community 23 - "core/database/app_database.dart"
Cohesion: 0.15
Nodes (13): core/database/app_database.dart, build, createState, DailyStatusScreen, _DailyStatusScreenState, _dealersVisited, dispose, employeeId (+5 more)

### Community 24 - "kernel_responsibility_screen.dart"
Cohesion: 0.02
Nodes (83): ../../../core/services/runtime/local_kernel_simulator.dart, _acceptRuntime, action, _actions, _api, build, _buildCapture, busy (+75 more)

### Community 25 - "lib/features/dashboard/presentation/employee_profile_tab.dart"
Cohesion: 0.06
Nodes (31): ../../../core/design/app_icons.dart, ../../../core/widgets/runtime_connection_banner.dart, build, _Card, child, controller, createState, current (+23 more)

### Community 26 - "backend_auth_gateway.dart"
Cohesion: 0.11
Nodes (18): Client, ../device/device_identity.dart, _buildSession, _cacheKey, _cacheSession, _client, _database, _decodeMap (+10 more)

### Community 27 - "StatefulWidget"
Cohesion: 0.13
Nodes (15): EmployeeDashboardScreen, DynamicCapabilityScreen, EmployeeDashboardScreen, LoginScreen, EmployeeDashboardScreen, EmployeeProfileTab, DynamicCapabilityScreen, DynamicCapabilityScreen (+7 more)

### Community 28 - "MotionGate"
Cohesion: 0.24
Nodes (4): MotionGate, Sensor, SensorEvent, SensorEventListener

### Community 29 - "package:flutter/material.dart"
Cohesion: 0.16
Nodes (12): build, TenantTheme, ../config/tenant_config.dart, ../design/app_design.dart, TenantConfig, build, TenantTheme, build (+4 more)

### Community 30 - "device_connectivity_gateway.dart"
Cohesion: 0.12
Nodes (18): connectivity_gateway.dart, ConnectivityStateValue get, dart:async, changes, ConnectivityGateway, ConnectivityStateValue, current, changes (+10 more)

### Community 31 - "wWinMain"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 32 - "tenant_config.dart"
Cohesion: 0.17
Nodes (11): appName, backgroundColor, code, copyWith, demo, displayName, id, logoText (+3 more)

### Community 33 - "auth_gateway.dart"
Cohesion: 0.17
Nodes (11): identifier, login, LoginRequest, logout, message, password, portalKey, refresh (+3 more)

### Community 34 - "sync_gateway.dart"
Cohesion: 0.17
Nodes (11): LocalSyncGateway, changes, clean, conflictCount, current, isSyncing, pendingCount, SyncGateway (+3 more)

### Community 35 - "mobile_capability.dart"
Cohesion: 0.11
Nodes (17): int get, config, definition, _extractKernel, fromJson, icon, id, kernelAvailable (+9 more)

### Community 36 - "mock_auth_gateway.dart"
Cohesion: 0.20
Nodes (9): auth_gateway.dart, AuthGateway, BackendAuthGateway, login, logout, MockAuthGateway, refresh, ../../models/app_user.dart (+1 more)

### Community 37 - "offline_record_queue.dart"
Cohesion: 0.14
Nodes (13): _cacheKey, _collectLocalPhotoPaths, enqueue, flush, _legacyCacheKey, localPhotoKey, migrateLegacyQueue, OfflineRecordQueue (+5 more)

### Community 38 - "offline_submission_queue.dart"
Cohesion: 0.18
Nodes (10): dart:io, _cacheKey, _collectLocalPhotoPaths, enqueue, flush, localPhotoKey, OfflineSubmissionQueue, pendingCount (+2 more)

### Community 39 - "offline_attendance_queue.dart"
Cohesion: 0.22
Nodes (8): ../config/field_api.dart, ../../database/app_database.dart, _cacheKey, enqueue, flush, OfflineAttendanceQueue, pendingCount, ../services/media/local_photo_store.dart

### Community 40 - "device_identity.dart"
Cohesion: 0.12
Nodes (16): bool get, AppDeviceIdentity, appVersion, _cacheKey, _createdAt, _deviceId, initialize, instance (+8 more)

### Community 41 - "core/session/app_session_controller.dart"
Cohesion: 0.19
Nodes (11): BrixtaApp, build, controller, core/session/app_session_controller.dart, ../core/theme/tenant_theme.dart, ../core/widgets/editorial_backdrop.dart, ../features/auth/presentation/login_screen.dart, ../features/dashboard/presentation/employee_dashboard_screen.dart (+3 more)

### Community 42 - "native_tracking_repository.dart"
Cohesion: 0.12
Nodes (15): ../domain/tracking_repository.dart, acknowledge, _channel, currentLocation, locateNow, NativeTrackingRepository, pending, prune (+7 more)

### Community 43 - "status_pill.dart"
Cohesion: 0.29
Nodes (6): Color, build, icon, label, StatusPill, tone

### Community 44 - "static const"
Cohesion: 0.22
Nodes (9): _baseUrlKey, initialize, RemoteConfigService, ../../config/api_config.dart, _baseUrlKey, initialize, RemoteConfigService, package:firebase_remote_config/firebase_remote_config.dart (+1 more)

### Community 45 - "placeholder_feature_screen.dart"
Cohesion: 0.29
Nodes (6): IconData, build, description, icon, PlaceholderFeatureScreen, title

### Community 46 - "api_config.dart"
Cohesion: 0.29
Nodes (6): ApiConfig, _baseUrl, _compiledDefault, updateBaseUrl, static String, static String get

### Community 47 - "responsibility_runtime_api.dart"
Cohesion: 0.17
Nodes (11): FieldApi get, accessToken, _api, dataSource, latestRecordId, myWork, profileRuntime, ResponsibilityRuntimeApi (+3 more)

### Community 48 - "Exception"
Cohesion: 0.40
Nodes (5): Exception, FieldApiException, AuthException, TrackingException, TrackingUiException

### Community 49 - "editorial-ui-20260826-013104/lib/features/dashboard/presentation/employee_dashboard_screen.dart"
Cohesion: 0.03
Nodes (66): approvalCount, _approvals, _blockedWork, build, capability, _capabilityHint, _capabilityNeedsTracking, controller (+58 more)

### Community 50 - "enquiry_form_screen.dart"
Cohesion: 0.13
Nodes (15): FormState, build, _company, createState, dispose, employeeId, EnquiryFormScreen, _EnquiryFormScreenState (+7 more)

### Community 51 - "AppSessionController"
Cohesion: 0.12
Nodes (16): build, compact, controller, RuntimeConnectionBanner, ChangeNotifier, editorial_backdrop.dart, FieldTrackingService, AppSessionController (+8 more)

### Community 58 - "cms-sovereignty-20260825-231628/lib/features/dashboard/presentation/employee_dashboard_screen.dart"
Cohesion: 0.03
Nodes (76): ../../allowances/presentation/allowances_screen.dart, ../../attendance/presentation/attendance_screen.dart, approvalCount, _approvals, _blockedWork, build, capability, _capabilityHint (+68 more)

### Community 60 - "cms-sovereignty-finish-20260825-231953/employee_dashboard_screen.dart"
Cohesion: 0.03
Nodes (66): approvalCount, _approvals, _blockedWork, build, capability, _capabilityHint, _capabilityNeedsTracking, controller (+58 more)

### Community 61 - "editorial-ui-20260826-013104/lib/features/dynamic/presentation/dynamic_capability_screen.dart"
Cohesion: 0.03
Nodes (63): action, _ActionCard, actionCount, _actionVisible, _applyOptimisticRecord, build, _buildField, _cacheKey (+55 more)

### Community 63 - "cms-sovereignty-20260825-231628/lib/features/dynamic/presentation/dynamic_capability_screen.dart"
Cohesion: 0.03
Nodes (61): action, _ActionCard, actionCount, _actionVisible, _applyOptimisticRecord, build, _buildField, _cacheKey (+53 more)

### Community 64 - "TrackingStore"
Cohesion: 0.21
Nodes (3): TrackingStore, SQLiteDatabase, SQLiteOpenHelper

### Community 65 - "MainActivity.kt"
Cohesion: 0.29
Nodes (5): MainActivity, FlutterActivity, FlutterEngine, IntArray, MethodChannel

### Community 66 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 67 - "WidgetsBindingObserver"
Cohesion: 0.53
Nodes (6): _EmployeeDashboardScreenState, _EmployeeDashboardScreenState, _EmployeeDashboardScreenState, EmployeeDashboardScreen, _EmployeeDashboardScreenState, WidgetsBindingObserver

### Community 68 - "FieldTrackingService.kt"
Cohesion: 0.33
Nodes (5): IBinder, Intent, LocationListener, LocationManager, Service

### Community 70 - "employee-own-history-v2-20260826-042335/lib/features/dynamic/presentation/dynamic_capability_screen.dart"
Cohesion: 0.03
Nodes (62): action, _ActionCard, actionCount, _actionVisible, _applyOptimisticRecord, build, _buildField, _cacheKey (+54 more)

### Community 71 - "initial-state-runtime-20260826-022320/lib/features/dynamic/presentation/dynamic_capability_screen.dart"
Cohesion: 0.03
Nodes (62): action, _ActionCard, actionCount, _actionVisible, _applyOptimisticRecord, build, _buildField, _cacheKey (+54 more)

### Community 72 - "semantic-runtime-v2-20260826-033804/lib/features/dynamic/presentation/dynamic_capability_screen.dart"
Cohesion: 0.03
Nodes (62): action, _ActionCard, actionCount, _actionVisible, _applyOptimisticRecord, build, _buildField, _cacheKey (+54 more)

### Community 73 - "editorial-ui-20260826-013104/lib/core/design/app_design.dart"
Cohesion: 0.05
Nodes (42): amber, AppDesign, blue, canvas, controlRadius, faint, green, greenBright (+34 more)

### Community 74 - "editorial-ui-20260826-013104/lib/features/dashboard/presentation/employee_profile_tab.dart"
Cohesion: 0.06
Nodes (31): build, _Card, child, controller, createState, current, device, _DeviceCard (+23 more)

### Community 75 - "editorial_backdrop.dart"
Cohesion: 0.11
Nodes (18): AnimationController, CustomPainter, build, child, color, _controller, createState, dispose (+10 more)

### Community 76 - "editorial-ui-20260826-013104/lib/features/auth/presentation/login_screen.dart"
Cohesion: 0.12
Nodes (15): build, _companyCodeController, controller, createState, dispose, _employeeController, _error, _formKey (+7 more)

### Community 77 - "State"
Cohesion: 0.22
Nodes (14): _DynamicCapabilityScreenState, _LoginScreenState, _EmployeeProfileTabState, _DynamicCapabilityScreenState, _DynamicCapabilityScreenState, _DynamicCapabilityScreenState, _DynamicCapabilityScreenState, DynamicCapabilityScreen (+6 more)

### Community 78 - "semantic-runtime-v2-20260826-033804/lib/core/offline/offline_record_queue.dart"
Cohesion: 0.14
Nodes (13): _cacheKey, _collectLocalPhotoPaths, enqueue, flush, _legacyCacheKey, localPhotoKey, migrateLegacyQueue, OfflineRecordQueue (+5 more)

### Community 79 - "firebase_options.dart"
Cohesion: 0.33
Nodes (5): android, DefaultFirebaseOptions, package:firebase_core/firebase_core.dart, package:flutter/foundation.dart, static const FirebaseOptions

## Knowledge Gaps
- **1423 isolated node(s):** `flutter_controller_`, `project_`, `x`, `y`, `height` (+1418 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AppSessionController` connect `AppSessionController` to `allowances_screen.dart`, `lib/features/dashboard/presentation/employee_dashboard_screen.dart`, `lib/features/dynamic/presentation/dynamic_capability_screen.dart`, `attendance_screen.dart`, `app_session_controller.dart`, `lib/features/auth/presentation/login_screen.dart`, `main.dart`, `kernel_responsibility_screen.dart`, `lib/features/dashboard/presentation/employee_profile_tab.dart`, `core/session/app_session_controller.dart`, `editorial-ui-20260826-013104/lib/features/dashboard/presentation/employee_dashboard_screen.dart`, `cms-sovereignty-20260825-231628/lib/features/dashboard/presentation/employee_dashboard_screen.dart`, `cms-sovereignty-finish-20260825-231953/employee_dashboard_screen.dart`, `editorial-ui-20260826-013104/lib/features/dynamic/presentation/dynamic_capability_screen.dart`, `cms-sovereignty-20260825-231628/lib/features/dynamic/presentation/dynamic_capability_screen.dart`, `employee-own-history-v2-20260826-042335/lib/features/dynamic/presentation/dynamic_capability_screen.dart`, `initial-state-runtime-20260826-022320/lib/features/dynamic/presentation/dynamic_capability_screen.dart`, `semantic-runtime-v2-20260826-033804/lib/features/dynamic/presentation/dynamic_capability_screen.dart`, `editorial-ui-20260826-013104/lib/features/dashboard/presentation/employee_profile_tab.dart`, `editorial-ui-20260826-013104/lib/features/auth/presentation/login_screen.dart`?**
  _High betweenness centrality (0.049) - this node is a cross-community bridge._
- **Why does `MobileCapability` connect `mobile_capability.dart` to `lib/features/dashboard/presentation/employee_dashboard_screen.dart`, `lib/features/dynamic/presentation/dynamic_capability_screen.dart`, `employee-own-history-v2-20260826-042335/lib/features/dynamic/presentation/dynamic_capability_screen.dart`, `initial-state-runtime-20260826-022320/lib/features/dynamic/presentation/dynamic_capability_screen.dart`, `semantic-runtime-v2-20260826-033804/lib/features/dynamic/presentation/dynamic_capability_screen.dart`, `editorial-ui-20260826-013104/lib/features/dashboard/presentation/employee_dashboard_screen.dart`, `kernel_responsibility_screen.dart`, `cms-sovereignty-20260825-231628/lib/features/dashboard/presentation/employee_dashboard_screen.dart`, `cms-sovereignty-finish-20260825-231953/employee_dashboard_screen.dart`, `editorial-ui-20260826-013104/lib/features/dynamic/presentation/dynamic_capability_screen.dart`, `cms-sovereignty-20260825-231628/lib/features/dynamic/presentation/dynamic_capability_screen.dart`?**
  _High betweenness centrality (0.016) - this node is a cross-community bridge._
- **What connects `flutter_controller_`, `project_`, `x` to the rest of the system?**
  _1423 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Win32Window` be split into smaller, more focused modules?**
  _Cohesion score 0.05311676909569798 - nodes in this community are weakly interconnected._
- **Should `allowances_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.027777777777777776 - nodes in this community are weakly interconnected._
- **Should `lib/features/dashboard/presentation/employee_dashboard_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.02666666666666667 - nodes in this community are weakly interconnected._
- **Should `lib/features/dynamic/presentation/dynamic_capability_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.031746031746031744 - nodes in this community are weakly interconnected._