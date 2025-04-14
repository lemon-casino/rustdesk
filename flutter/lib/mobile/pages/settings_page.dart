import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/widgets/setting_widgets.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:settings_ui/settings_ui.dart';

import '../../common.dart';
import '../../common/widgets/dialog.dart';
import '../../consts.dart';
import '../../models/model.dart';
import '../../models/platform_model.dart';
import '../widgets/dialog.dart';
import 'home_page.dart';
import 'scan_page.dart';

class SettingsPage extends StatefulWidget implements PageShape {
  @override
  final title = translate("Settings");

  @override
  final icon = Icon(Icons.settings);

  @override
  final appBarActions = bind.isDisableSettings() ? [] : [ScanButton()];

  @override
  State<SettingsPage> createState() => _SettingsState();
}

const url = 'https://rustdesk.com/';

enum KeepScreenOn {
  never,
  duringControlled,
  serviceOn,
}

String _keepScreenOnToOption(KeepScreenOn value) {
  switch (value) {
    case KeepScreenOn.never:
      return 'never';
    case KeepScreenOn.duringControlled:
      return 'during-controlled';
    case KeepScreenOn.serviceOn:
      return 'service-on';
  }
}

KeepScreenOn optionToKeepScreenOn(String value) {
  switch (value) {
    case 'never':
      return KeepScreenOn.never;
    case 'service-on':
      return KeepScreenOn.serviceOn;
    default:
      return KeepScreenOn.duringControlled;
  }
}

class _SettingsState extends State<SettingsPage> with WidgetsBindingObserver {
  final _hasIgnoreBattery = false;
  var _ignoreBatteryOpt = false;
  var _enableStartOnBoot = false;
  var _checkUpdateOnStartup = false;
  var _floatingWindowDisabled = false;
  var _keepScreenOn = KeepScreenOn.duringControlled;
  var _enableRecordSession = false;
  var _enableHardwareCodec = false;
  var _autoRecordIncomingSession = false;
  var _autoRecordOutgoingSession = false;
  var _fingerprint = "";
  var _buildDate = "";

  _SettingsState() {
    _enableRecordSession = option2bool(kOptionEnableRecordSession,
        bind.mainGetOptionSync(key: kOptionEnableRecordSession));
    _enableHardwareCodec = option2bool(kOptionEnableHwcodec,
        bind.mainGetOptionSync(key: kOptionEnableHwcodec));
    _autoRecordIncomingSession = option2bool(kOptionAllowAutoRecordIncoming,
        bind.mainGetOptionSync(key: kOptionAllowAutoRecordIncoming));
    _autoRecordOutgoingSession = option2bool(kOptionAllowAutoRecordOutgoing,
        bind.mainGetLocalOption(key: kOptionAllowAutoRecordOutgoing));
  }

  @override
  void initState() {
    super.initState();
    _checkValues();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkValues() async {
    final ignoreBatteryOpt = await bind.mainGetToggleOptionSync(key: kOptionIgnoreBatteryOptimization);
    final enableStartOnBoot = await bind.mainGetToggleOptionSync(key: kOptionStartOnBoot);
    final checkUpdateOnStartup = await bind.mainGetToggleOptionSync(key: kOptionCheckUpdateOnStart);
    final floatingWindowDisabled = await bind.mainGetToggleOptionSync(key: kOptionDisableFloatingWindow);
    final keepScreenOn = await bind.mainGetOptionSync(key: kOptionKeepScreenOn);
    final fingerprint = await bind.mainGetFingerprint();
    final buildDate = await bind.mainGetBuildDate();
    if (mounted) {
      setState(() {
        _ignoreBatteryOpt = ignoreBatteryOpt;
        _enableStartOnBoot = enableStartOnBoot;
        _checkUpdateOnStartup = checkUpdateOnStartup;
        _floatingWindowDisabled = floatingWindowDisabled;
        _keepScreenOn = KeepScreenOn.values[int.parse(keepScreenOn)];
        _fingerprint = fingerprint;
        _buildDate = buildDate;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      () async {
        final ibs = await checkAndUpdateIgnoreBatteryStatus();
        final sob = await checkAndUpdateStartOnBoot();
        if (ibs || sob) {
          setState(() {});
        }
      }();
    }
  }

  Future<bool> checkAndUpdateIgnoreBatteryStatus() async {
    final res = await AndroidPermissionManager.check(
        kRequestIgnoreBatteryOptimizations);
    if (_ignoreBatteryOpt != res) {
      _ignoreBatteryOpt = res;
      return true;
    } else {
      return false;
    }
  }

  Future<bool> checkAndUpdateStartOnBoot() async {
    if (!await canStartOnBoot() && _enableStartOnBoot) {
      _enableStartOnBoot = false;
      debugPrint(
          "checkAndUpdateStartOnBoot and set _enableStartOnBoot -> false");
      gFFI.invokeMethod(AndroidChannel.kSetStartOnBootOpt, false);
      return true;
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [];
    children.add(_buildGeneralSettings());
    children.add(_buildRecordingSettings());
    children.add(_buildAboutSettings());

    return Scaffold(
      appBar: AppBar(
        title: Text(translate("Settings")),
        actions: [
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => LogPage(),
              );
            },
            icon: Icon(Icons.info_outline),
            tooltip: translate("System info"),
          ),
        ],
      ),
      body: ListView(children: children),
    );
  }

  Widget _buildGeneralSettings() {
    final outgoingOnly = bind.isOutgoingOnly();
    final incommingOnly = bind.isIncomingOnly();

    final settings = SettingsScrollView(
      children: [
        SettingsSection(
          title: Text(translate("General")),
          tiles: [
            if (!outgoingOnly)
              SettingsTile.switchTile(
                title: Text(translate('Auto start on boot')),
                initialValue: _enableStartOnBoot,
                onToggle: (v) async {
                  await bind.mainSetToggleOption(key: kOptionStartOnBoot, value: v);
                  setState(() {
                    _enableStartOnBoot = v;
                  });
                },
              ),
            if (!outgoingOnly)
              SettingsTile.switchTile(
                title: Text(translate('Check for updates on startup')),
                initialValue: _checkUpdateOnStartup,
                onToggle: (v) async {
                  await bind.mainSetToggleOption(key: kOptionCheckUpdateOnStart, value: v);
                  setState(() {
                    _checkUpdateOnStartup = v;
                  });
                },
              ),
            if (!outgoingOnly)
              SettingsTile.switchTile(
                title: Text(translate('Disable floating window')),
                initialValue: _floatingWindowDisabled,
                onToggle: (v) async {
                  await bind.mainSetToggleOption(key: kOptionDisableFloatingWindow, value: v);
                  setState(() {
                    _floatingWindowDisabled = v;
                  });
                },
              ),
            if (!outgoingOnly)
              SettingsTile(
                title: Text(translate('Keep screen on')),
                trailing: DropdownButton<KeepScreenOn>(
                  value: _keepScreenOn,
                  items: [
                    DropdownMenuItem(
                      value: KeepScreenOn.never,
                      child: Text(translate('Never')),
                    ),
                    DropdownMenuItem(
                      value: KeepScreenOn.always,
                      child: Text(translate('Always')),
                    ),
                    DropdownMenuItem(
                      value: KeepScreenOn.onlyWhenConnected,
                      child: Text(translate('Only when connected')),
                    ),
                  ],
                  onChanged: (v) async {
                    if (v != null) {
                      await bind.mainSetOption(key: kOptionKeepScreenOn, value: v.index.toString());
                      setState(() {
                        _keepScreenOn = v;
                      });
                    }
                  },
                ),
              ),
          ],
        ),
        if (!outgoingOnly)
          SettingsSection(
            title: Text(translate("Security")),
            tiles: [
              SettingsTile.switchTile(
                title: Text(translate('Ignore Battery Optimizations')),
                initialValue: _ignoreBatteryOpt,
                onToggle: (v) async {
                  await bind.mainSetToggleOption(key: kOptionIgnoreBatteryOptimization, value: v);
                  setState(() {
                    _ignoreBatteryOpt = v;
                  });
                },
              ),
            ],
          ),
      ],
    );
    return settings;
  }

  Widget _buildRecordingSettings() {
    final outgoingOnly = bind.isOutgoingOnly();
    final incommingOnly = bind.isIncomingOnly();
    return SettingsSection(
      title: Text(translate("Recording")),
      tiles: [
        if (!outgoingOnly)
          SettingsTile.switchTile(
            title:
                Text(translate('Automatically record incoming sessions')),
            initialValue: _autoRecordIncomingSession,
            onToggle: isOptionFixed(kOptionAllowAutoRecordIncoming)
                ? null
                : (v) async {
                    await bind.mainSetOption(
                        key: kOptionAllowAutoRecordIncoming,
                        value: bool2option(
                            kOptionAllowAutoRecordIncoming, v));
                    final newValue = option2bool(
                        kOptionAllowAutoRecordIncoming,
                        await bind.mainGetOption(
                            key: kOptionAllowAutoRecordIncoming));
                    setState(() {
                      _autoRecordIncomingSession = newValue;
                    });
                  },
          ),
        if (!incommingOnly)
          SettingsTile.switchTile(
            title:
                Text(translate('Automatically record outgoing sessions')),
            initialValue: _autoRecordOutgoingSession,
            onToggle: isOptionFixed(kOptionAllowAutoRecordOutgoing)
                ? null
                : (v) async {
                    await bind.mainSetLocalOption(
                        key: kOptionAllowAutoRecordOutgoing,
                        value: bool2option(
                            kOptionAllowAutoRecordOutgoing, v));
                    final newValue = option2bool(
                        kOptionAllowAutoRecordOutgoing,
                        bind.mainGetLocalOption(
                            key: kOptionAllowAutoRecordOutgoing));
                    setState(() {
                      _autoRecordOutgoingSession = newValue;
                    });
                  },
          ),
        SettingsTile(
          title: Text(translate("Directory")),
          description: Text(bind.mainVideoSaveDirectory(root: false)),
        ),
      ],
    );
  }

  Widget _buildAboutSettings() {
    return SettingsSection(
      title: Text(translate("About")),
      tiles: [
        SettingsTile(
            onPressed: (context) async {
              await launchUrl(Uri.parse(url));
            },
            title: Text(translate("Version: ") + version),
            value: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('rustdesk.com',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                  )),
            ),
            leading: Icon(Icons.info)),
        SettingsTile(
            title: Text(translate("Build Date")),
            value: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(_buildDate),
            ),
            leading: Icon(Icons.query_builder)),
        if (isAndroid)
          SettingsTile(
              onPressed: (context) => onCopyFingerprint(_fingerprint),
              title: Text(translate("Fingerprint")),
              value: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(_fingerprint),
              ),
              leading: Icon(Icons.fingerprint)),
        SettingsTile(
          title: Text(translate("Privacy Statement")),
          onPressed: (context) =>
              launchUrlString('https://rustdesk.com/privacy.html'),
          leading: Icon(Icons.privacy_tip),
        )
      ],
    );
  }

  Future<bool> canStartOnBoot() async {
    // start on boot depends on ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS and SYSTEM_ALERT_WINDOW
    if (_hasIgnoreBattery && !_ignoreBatteryOpt) {
      return false;
    }
    if (!await AndroidPermissionManager.check(kSystemAlertWindow)) {
      return false;
    }
    return true;
  }

  defaultDisplaySection() {
    return SettingsSection(
      title: Text(translate("Display Settings")),
      tiles: [
        SettingsTile(
            title: Text(translate('Display Settings')),
            leading: Icon(Icons.desktop_windows_outlined),
            trailing: Icon(Icons.arrow_forward_ios),
            onPressed: (context) {
              Navigator.push(context, MaterialPageRoute(builder: (context) {
                return _DisplayPage();
              }));
            })
      ],
    );
  }
}

void showLanguageSettings(OverlayDialogManager dialogManager) async {
  try {
    final langs = json.decode(await bind.mainGetLangs()) as List<dynamic>;
    var lang = bind.mainGetLocalOption(key: kCommConfKeyLang);
    dialogManager.show((setState, close, context) {
      setLang(v) async {
        if (lang != v) {
          setState(() {
            lang = v;
          });
          await bind.mainSetLocalOption(key: kCommConfKeyLang, value: v);
          HomePage.homeKey.currentState?.refreshPages();
          Future.delayed(Duration(milliseconds: 200), close);
        }
      }

      final isOptFixed = isOptionFixed(kCommConfKeyLang);
      return CustomAlertDialog(
        content: Column(
          children: [
                getRadio(Text(translate('Default')), defaultOptionLang, lang,
                    isOptFixed ? null : setLang),
                Divider(color: MyTheme.border),
              ] +
              langs.map((e) {
                final key = e[0] as String;
                final name = e[1] as String;
                return getRadio(Text(translate(name)), key, lang,
                    isOptFixed ? null : setLang);
              }).toList(),
        ),
      );
    }, backDismiss: true, clickMaskDismiss: true);
  } catch (e) {
    //
  }
}

void showThemeSettings(OverlayDialogManager dialogManager) async {
  var themeMode = MyTheme.getThemeModePreference();

  dialogManager.show((setState, close, context) {
    setTheme(v) {
      if (themeMode != v) {
        setState(() {
          themeMode = v;
        });
        MyTheme.changeDarkMode(themeMode);
        Future.delayed(Duration(milliseconds: 200), close);
      }
    }

    final isOptFixed = isOptionFixed(kCommConfKeyTheme);
    return CustomAlertDialog(
      content: Column(children: [
        getRadio(Text(translate('Light')), ThemeMode.light, themeMode,
            isOptFixed ? null : setTheme),
        getRadio(Text(translate('Dark')), ThemeMode.dark, themeMode,
            isOptFixed ? null : setTheme),
        getRadio(Text(translate('Follow System')), ThemeMode.system, themeMode,
            isOptFixed ? null : setTheme)
      ]),
    );
  }, backDismiss: true, clickMaskDismiss: true);
}

void showAbout(OverlayDialogManager dialogManager) {
  dialogManager.show((setState, close, context) {
    return CustomAlertDialog(
      title: Text(translate('About RustDesk')),
      content: Wrap(direction: Axis.vertical, spacing: 12, children: [
        Text('Version: $version'),
        InkWell(
            onTap: () async {
              const url = 'https://rustdesk.com/';
              await launchUrl(Uri.parse(url));
            },
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('rustdesk.com',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                  )),
            )),
      ]),
      actions: [],
    );
  }, clickMaskDismiss: true, backDismiss: true);
}

class ScanButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.qr_code_scanner),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (BuildContext context) => ScanPage(),
          ),
        );
      },
    );
  }
}

class _DisplayPage extends StatefulWidget {
  const _DisplayPage();

  @override
  State<_DisplayPage> createState() => __DisplayPageState();
}

class __DisplayPageState extends State<_DisplayPage> {
  @override
  Widget build(BuildContext context) {
    final Map codecsJson = jsonDecode(bind.mainSupportedHwdecodings());
    final h264 = codecsJson['h264'] ?? false;
    final h265 = codecsJson['h265'] ?? false;
    var codecList = [
      _RadioEntry('Auto', 'auto'),
      _RadioEntry('VP8', 'vp8'),
      _RadioEntry('VP9', 'vp9'),
      _RadioEntry('AV1', 'av1'),
      if (h264) _RadioEntry('H264', 'h264'),
      if (h265) _RadioEntry('H265', 'h265')
    ];
    RxBool showCustomImageQuality = false.obs;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios)),
        title: Text(translate('Display Settings')),
        centerTitle: true,
      ),
      body: SettingsList(sections: [
        SettingsSection(
          tiles: [
            _getPopupDialogRadioEntry(
              title: 'Default View Style',
              list: [
                _RadioEntry('Scale original', kRemoteViewStyleOriginal),
                _RadioEntry('Scale adaptive', kRemoteViewStyleAdaptive)
              ],
              getter: () =>
                  bind.mainGetUserDefaultOption(key: kOptionViewStyle),
              asyncSetter: isOptionFixed(kOptionViewStyle)
                  ? null
                  : (value) async {
                      await bind.mainSetUserDefaultOption(
                          key: kOptionViewStyle, value: value);
                    },
            ),
            _getPopupDialogRadioEntry(
              title: 'Default Image Quality',
              list: [
                _RadioEntry('Good image quality', kRemoteImageQualityBest),
                _RadioEntry('Balanced', kRemoteImageQualityBalanced),
                _RadioEntry('Optimize reaction time', kRemoteImageQualityLow),
                _RadioEntry('Custom', kRemoteImageQualityCustom),
              ],
              getter: () {
                final v =
                    bind.mainGetUserDefaultOption(key: kOptionImageQuality);
                showCustomImageQuality.value = v == kRemoteImageQualityCustom;
                return v;
              },
              asyncSetter: isOptionFixed(kOptionImageQuality)
                  ? null
                  : (value) async {
                      await bind.mainSetUserDefaultOption(
                          key: kOptionImageQuality, value: value);
                      showCustomImageQuality.value =
                          value == kRemoteImageQualityCustom;
                    },
              tail: customImageQualitySetting(),
              showTail: showCustomImageQuality,
              notCloseValue: kRemoteImageQualityCustom,
            ),
            _getPopupDialogRadioEntry(
              title: 'Default Codec',
              list: codecList,
              getter: () =>
                  bind.mainGetUserDefaultOption(key: kOptionCodecPreference),
              asyncSetter: isOptionFixed(kOptionCodecPreference)
                  ? null
                  : (value) async {
                      await bind.mainSetUserDefaultOption(
                          key: kOptionCodecPreference, value: value);
                    },
            ),
          ],
        ),
        SettingsSection(
          title: Text(translate('Other Default Options')),
          tiles:
              otherDefaultSettings().map((e) => otherRow(e.$1, e.$2)).toList(),
        ),
      ]),
    );
  }

  SettingsTile otherRow(String label, String key) {
    final value = bind.mainGetUserDefaultOption(key: key) == 'Y';
    final isOptFixed = isOptionFixed(key);
    return SettingsTile.switchTile(
      initialValue: value,
      title: Text(translate(label)),
      onToggle: isOptFixed
          ? null
          : (b) async {
              await bind.mainSetUserDefaultOption(
                  key: key, value: b ? 'Y' : defaultOptionNo);
              setState(() {});
            },
    );
  }
}

class _ManageTrustedDevices extends StatefulWidget {
  const _ManageTrustedDevices();

  @override
  State<_ManageTrustedDevices> createState() => __ManageTrustedDevicesState();
}

class __ManageTrustedDevicesState extends State<_ManageTrustedDevices> {
  RxList<TrustedDevice> trustedDevices = RxList.empty(growable: true);
  RxList<Uint8List> selectedDevices = RxList.empty();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(translate('Manage trusted devices')),
        centerTitle: true,
        actions: [
          Obx(() => IconButton(
              icon: Icon(Icons.delete, color: Colors.white),
              onPressed: selectedDevices.isEmpty
                  ? null
                  : () {
                      confrimDeleteTrustedDevicesDialog(
                          trustedDevices, selectedDevices);
                    }))
        ],
      ),
      body: FutureBuilder(
          future: TrustedDevice.get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final devices = snapshot.data as List<TrustedDevice>;
            trustedDevices = devices.obs;
            return trustedDevicesTable(trustedDevices, selectedDevices);
          }),
    );
  }
}

class _RadioEntry {
  final String label;
  final String value;
  _RadioEntry(this.label, this.value);
}

typedef _RadioEntryGetter = String Function();
typedef _RadioEntrySetter = Future<void> Function(String);

SettingsTile _getPopupDialogRadioEntry({
  required String title,
  required List<_RadioEntry> list,
  required _RadioEntryGetter getter,
  required _RadioEntrySetter? asyncSetter,
  Widget? tail,
  RxBool? showTail,
  String? notCloseValue,
}) {
  RxString groupValue = ''.obs;
  RxString valueText = ''.obs;

  init() {
    groupValue.value = getter();
    final e = list.firstWhereOrNull((e) => e.value == groupValue.value);
    if (e != null) {
      valueText.value = e.label;
    }
  }

  init();

  void showDialog() async {
    gFFI.dialogManager.show((setState, close, context) {
      final onChanged = asyncSetter == null
          ? null
          : (String? value) async {
              if (value == null) return;
              await asyncSetter(value);
              init();
              if (value != notCloseValue) {
                close();
              }
            };

      return CustomAlertDialog(
          content: Obx(
        () => Column(children: [
          ...list
              .map((e) => getRadio(Text(translate(e.label)), e.value,
                  groupValue.value, onChanged))
              .toList(),
          Offstage(
            offstage:
                !(tail != null && showTail != null && showTail.value == true),
            child: tail,
          ),
        ]),
      ));
    }, backDismiss: true, clickMaskDismiss: true);
  }

  return SettingsTile(
    title: Text(translate(title)),
    onPressed: asyncSetter == null ? null : (context) => showDialog(),
    value: Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Obx(() => Text(translate(valueText.value))),
    ),
  );
}
