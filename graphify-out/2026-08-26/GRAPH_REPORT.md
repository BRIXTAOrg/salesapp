# Graph Report - kamdhenu  (2026-08-26)

## Corpus Check
- 91 files · ~55,281 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1553 nodes · 2109 edges · 70 communities (64 shown, 6 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 18 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `a4c34775`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Win32Window
- FieldTrackingService
- allowances_screen.dart
- lib/features/dashboard/presentation/employee_dashboard_screen.dart
- lib/features/dynamic/presentation/dynamic_capability_screen.dart
- GeneratedPluginRegistrant.swift
- app_design.dart
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
- login_screen.dart
- playful_widgets.dart
- main.dart
- local_sync_gateway.dart
- field_api.dart
- daily_status_screen.dart
- kernel_responsibility_screen.dart
- employee_profile_tab.dart
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
- brixta_app.dart
- native_tracking_repository.dart
- status_pill.dart
- static const
- placeholder_feature_screen.dart
- api_config.dart
- responsibility_runtime_api.dart
- Exception
- AppSessionController
- enquiry_form_screen.dart
- runtime_connection_banner.dart
- String?
- cms-sovereignty-20260825-231628/lib/features/dashboard/presentation/employee_dashboard_screen.dart
- LaunchImage.imageset/README.md
- cms-sovereignty-finish-20260825-231953/employee_dashboard_screen.dart
- TrackingRepository
- README.md
- cms-sovereignty-20260825-231628/lib/features/dynamic/presentation/dynamic_capability_screen.dart
- TrackingStore
- MainActivity.kt
- manifest.json
- State
- FieldTrackingService.kt
- _ReferencePickerSheet

## God Nodes (most connected - your core abstractions)
1. `FieldTrackingService` - 24 edges
2. `Win32Window` - 24 edges
3. `TrackingStore` - 16 edges
4. `AppSessionController` - 15 edges
5. `MessageHandler` - 12 edges
6. `MotionGate` - 11 edges
7. `MainActivity` - 10 edges
8. `TrackingController` - 10 edges
9. `FlutterWindow` - 10 edges
10. `Create` - 10 edges

## Surprising Connections (you probably didn't know these)
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  windows/runner/main.cpp → windows/runner/utils.cpp
- `Win32Window::Win32Window()` --calls--> `Destroy`  [INFERRED]
  windows/runner/win32_window.cpp → windows/runner/win32_window.h
- `FieldTrackingService` --references--> `MotionGate`  [EXTRACTED]
  android/app/src/main/kotlin/com/example/salesapp/tracking/FieldTrackingService.kt → android/app/src/main/kotlin/com/example/salesapp/tracking/MotionGate.kt
- `FieldTrackingService` --references--> `TrackingStore`  [EXTRACTED]
  android/app/src/main/kotlin/com/example/salesapp/tracking/FieldTrackingService.kt → android/app/src/main/kotlin/com/example/salesapp/tracking/TrackingStore.kt
- `my_application_activate()` --calls--> `fl_register_plugins()`  [INFERRED]
  linux/runner/my_application.cc → linux/flutter/generated_plugin_registrant.cc

## Import Cycles
- None detected.

## Communities (70 total, 6 thin omitted)

### Community 0 - "Win32Window"
Cohesion: 0.05
Nodes (57): PluginRegistry, RECT, unique_ptr, RegisterPlugins(), DartProject, HWND, LPARAM, LRESULT (+49 more)

### Community 2 - "allowances_screen.dart"
Cohesion: 0.03
Nodes (71): active, _addReceipt, border, build, busy, claim, _ClaimDraft, _ClaimFact (+63 more)

### Community 3 - "lib/features/dashboard/presentation/employee_dashboard_screen.dart"
Cohesion: 0.03
Nodes (67): ../../dynamic/presentation/dynamic_capability_screen.dart, approvalCount, _approvals, _blockedWork, build, capability, _capabilityHint, _capabilityNeedsTracking (+59 more)

### Community 4 - "lib/features/dynamic/presentation/dynamic_capability_screen.dart"
Cohesion: 0.03
Nodes (63): ../../../core/models/mobile_capability.dart, action, _ActionCard, actionCount, _actionVisible, _applyOptimisticRecord, build, _buildField (+55 more)

### Community 5 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.06
Nodes (30): Any, Cocoa, connectivity_plus, file_selector_macos, firebase_core, firebase_remote_config, Flutter, FlutterAppDelegate (+22 more)

### Community 6 - "app_design.dart"
Cohesion: 0.05
Nodes (42): amber, AppDesign, blue, canvas, controlRadius, faint, green, greenBright (+34 more)

### Community 7 - "attendance_screen.dart"
Cohesion: 0.04
Nodes (45): ../../../core/offline/offline_attendance_queue.dart, ../../../core/services/media/local_photo_store.dart, dart:io, delete, _extension, LocalPhotoStore, persist, AttendanceScreen (+37 more)

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
Nodes (47): _CapabilityList, _CapabilityRow, _Header, _HomeTab, _LiveOverview, _NextCard, _QuickResponsibilityGrid, _QuietState (+39 more)

### Community 12 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 13 - "auth_session.dart"
Cohesion: 0.06
Nodes (30): app_user.dart, AppUser, department, designation, roles, accessToken, AuthSession, blockedActions (+22 more)

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
Nodes (18): ../../../core/design/app_design.dart, build, controller, distanceKm, icon, _InfoCard, label, _MeterHero (+10 more)

### Community 18 - "login_screen.dart"
Cohesion: 0.11
Nodes (18): ../../../core/services/auth/auth_gateway.dart, core/session/app_session_controller.dart, ../../../core/widgets/tenant_logo.dart, build, _companyCodeController, controller, createState, dispose (+10 more)

### Community 19 - "playful_widgets.dart"
Cohesion: 0.11
Nodes (17): background, badge, build, eyebrow, foreground, FunPill, FunSectionTitle, icon (+9 more)

### Community 20 - "main.dart"
Cohesion: 0.08
Nodes (23): app/brixta_app.dart, core/config/remote_config_service.dart, core/config/tenant_config.dart, core/device/device_identity.dart, core/services/auth/backend_auth_gateway.dart, core/services/connectivity/device_connectivity_gateway.dart, core/services/sync/local_sync_gateway.dart, core/services/sync/sync_transport.dart (+15 more)

### Community 21 - "local_sync_gateway.dart"
Cohesion: 0.12
Nodes (16): ../connectivity/connectivity_gateway.dart, AppDatabase, changes, connectivityGateway, _connectivitySubscription, _controller, _current, database (+8 more)

### Community 22 - "field_api.dart"
Cohesion: 0.11
Nodes (18): api_config.dart, int?, accessToken, _client, code, _decode, deleteJson, details (+10 more)

### Community 23 - "daily_status_screen.dart"
Cohesion: 0.14
Nodes (14): core/database/app_database.dart, FormState, build, createState, DailyStatusScreen, _DailyStatusScreenState, _dealersVisited, dispose (+6 more)

### Community 24 - "kernel_responsibility_screen.dart"
Cohesion: 0.02
Nodes (83): ../../../core/services/runtime/local_kernel_simulator.dart, _acceptRuntime, action, _actions, _api, build, _buildCapture, busy (+75 more)

### Community 25 - "employee_profile_tab.dart"
Cohesion: 0.06
Nodes (36): ../../../core/design/app_icons.dart, ../../../core/services/runtime/responsibility_runtime_api.dart, ../../../core/widgets/runtime_connection_banner.dart, build, _Card, child, controller, createState (+28 more)

### Community 26 - "backend_auth_gateway.dart"
Cohesion: 0.12
Nodes (16): Client, _buildSession, _cacheKey, _cacheSession, _client, _database, _decodeMap, _fetchBootstrap (+8 more)

### Community 27 - "StatefulWidget"
Cohesion: 0.18
Nodes (11): EmployeeDashboardScreen, DynamicCapabilityScreen, EmployeeDashboardScreen, AllowancesScreen, _AllowancesScreenState, _ClaimSheet, _ClaimSheetState, EmployeeDashboardScreen (+3 more)

### Community 28 - "MotionGate"
Cohesion: 0.24
Nodes (4): MotionGate, Sensor, SensorEvent, SensorEventListener

### Community 29 - "package:flutter/material.dart"
Cohesion: 0.20
Nodes (9): ../config/tenant_config.dart, TenantConfig, build, TenantTheme, build, size, tenant, TenantLogo (+1 more)

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
Cohesion: 0.20
Nodes (9): _cacheKey, _collectLocalPhotoPaths, enqueue, flush, localPhotoKey, OfflineSubmissionQueue, pendingCount, prepareForUpload (+1 more)

### Community 39 - "offline_attendance_queue.dart"
Cohesion: 0.22
Nodes (8): ../config/field_api.dart, ../../database/app_database.dart, _cacheKey, enqueue, flush, OfflineAttendanceQueue, pendingCount, ../services/media/local_photo_store.dart

### Community 40 - "device_identity.dart"
Cohesion: 0.11
Nodes (17): bool get, DateTime?, AppDeviceIdentity, appVersion, _cacheKey, _createdAt, _deviceId, initialize (+9 more)

### Community 41 - "brixta_app.dart"
Cohesion: 0.29
Nodes (6): ../core/theme/tenant_theme.dart, ../features/auth/presentation/login_screen.dart, ../features/dashboard/presentation/employee_dashboard_screen.dart, BrixtaApp, build, controller

### Community 42 - "native_tracking_repository.dart"
Cohesion: 0.13
Nodes (14): dart:convert, ../domain/tracking_repository.dart, acknowledge, _channel, currentLocation, locateNow, pending, prune (+6 more)

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
Cohesion: 0.15
Nodes (12): ../device/device_identity.dart, FieldApi get, accessToken, _api, dataSource, latestRecordId, myWork, profileRuntime (+4 more)

### Community 48 - "Exception"
Cohesion: 0.40
Nodes (5): Exception, FieldApiException, AuthException, TrackingException, TrackingUiException

### Community 49 - "AppSessionController"
Cohesion: 0.40
Nodes (5): ChangeNotifier, FieldTrackingService, AppSessionController, _NeverListenable, TrackingController

### Community 50 - "enquiry_form_screen.dart"
Cohesion: 0.14
Nodes (14): build, _company, createState, dispose, employeeId, EnquiryFormScreen, _EnquiryFormScreenState, _formKey (+6 more)

### Community 51 - "runtime_connection_banner.dart"
Cohesion: 0.25
Nodes (7): ../design/app_design.dart, build, compact, controller, RuntimeConnectionBanner, package:flutter_lucide/flutter_lucide.dart, ../session/app_session_controller.dart

### Community 58 - "cms-sovereignty-20260825-231628/lib/features/dashboard/presentation/employee_dashboard_screen.dart"
Cohesion: 0.03
Nodes (70): ../../allowances/presentation/allowances_screen.dart, ../../attendance/presentation/attendance_screen.dart, approvalCount, _approvals, _blockedWork, build, capability, _capabilityHint (+62 more)

### Community 60 - "cms-sovereignty-finish-20260825-231953/employee_dashboard_screen.dart"
Cohesion: 0.03
Nodes (68): approvalCount, _approvals, _blockedWork, build, capability, _capabilityHint, _capabilityNeedsTracking, controller (+60 more)

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

### Community 67 - "State"
Cohesion: 0.33
Nodes (10): _EmployeeDashboardScreenState, _DynamicCapabilityScreenState, _EmployeeDashboardScreenState, DynamicCapabilityScreen, EmployeeDashboardScreen, _EmployeeDashboardScreenState, _DynamicCapabilityScreenState, _KernelResponsibilityScreenState (+2 more)

### Community 68 - "FieldTrackingService.kt"
Cohesion: 0.33
Nodes (5): IBinder, Intent, LocationListener, LocationManager, Service

## Knowledge Gaps
- **1021 isolated node(s):** `controller`, `tracker`, `_readyWork`, `_blockedWork`, `_approvals` (+1016 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AppSessionController` connect `AppSessionController` to `allowances_screen.dart`, `lib/features/dashboard/presentation/employee_dashboard_screen.dart`, `lib/features/dynamic/presentation/dynamic_capability_screen.dart`, `attendance_screen.dart`, `brixta_app.dart`, `app_session_controller.dart`, `login_screen.dart`, `runtime_connection_banner.dart`, `main.dart`, `kernel_responsibility_screen.dart`, `employee_profile_tab.dart`, `cms-sovereignty-20260825-231628/lib/features/dashboard/presentation/employee_dashboard_screen.dart`, `cms-sovereignty-finish-20260825-231953/employee_dashboard_screen.dart`, `cms-sovereignty-20260825-231628/lib/features/dynamic/presentation/dynamic_capability_screen.dart`?**
  _High betweenness centrality (0.039) - this node is a cross-community bridge._
- **Why does `TrackingController` connect `AppSessionController` to `allowances_screen.dart`, `lib/features/dashboard/presentation/employee_dashboard_screen.dart`, `attendance_screen.dart`, `tracking_controller.dart`, `tracking_screen.dart`, `kernel_responsibility_screen.dart`, `employee_profile_tab.dart`, `cms-sovereignty-20260825-231628/lib/features/dashboard/presentation/employee_dashboard_screen.dart`, `cms-sovereignty-finish-20260825-231953/employee_dashboard_screen.dart`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **Why does `MobileCapability` connect `mobile_capability.dart` to `lib/features/dashboard/presentation/employee_dashboard_screen.dart`, `lib/features/dynamic/presentation/dynamic_capability_screen.dart`, `kernel_responsibility_screen.dart`, `cms-sovereignty-20260825-231628/lib/features/dashboard/presentation/employee_dashboard_screen.dart`, `cms-sovereignty-finish-20260825-231953/employee_dashboard_screen.dart`, `cms-sovereignty-20260825-231628/lib/features/dynamic/presentation/dynamic_capability_screen.dart`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **What connects `controller`, `tracker`, `_readyWork` to the rest of the system?**
  _1021 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Win32Window` be split into smaller, more focused modules?**
  _Cohesion score 0.05311676909569798 - nodes in this community are weakly interconnected._
- **Should `allowances_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.027777777777777776 - nodes in this community are weakly interconnected._
- **Should `lib/features/dashboard/presentation/employee_dashboard_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.029411764705882353 - nodes in this community are weakly interconnected._