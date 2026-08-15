enum AppThemeMode { system, light, dark }

enum HistoryOrder { newestFirst, oldestFirst }

enum BoardMode { input, analyze }

class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.historyOrder = HistoryOrder.newestFirst,
    this.boardMode = BoardMode.input,
    this.analysisWindow = 0,
    this.recentWindows = const <int>[5, 10, 20, 30],
    this.animationsEnabled = true,
    this.hapticsEnabled = true,
  });

  final AppThemeMode themeMode;
  final HistoryOrder historyOrder;
  final BoardMode boardMode;
  final int analysisWindow;
  final List<int> recentWindows;
  final bool animationsEnabled;
  final bool hapticsEnabled;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    HistoryOrder? historyOrder,
    BoardMode? boardMode,
    int? analysisWindow,
    List<int>? recentWindows,
    bool? animationsEnabled,
    bool? hapticsEnabled,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    historyOrder: historyOrder ?? this.historyOrder,
    boardMode: boardMode ?? this.boardMode,
    analysisWindow: analysisWindow ?? this.analysisWindow,
    recentWindows: List<int>.unmodifiable(recentWindows ?? this.recentWindows),
    animationsEnabled: animationsEnabled ?? this.animationsEnabled,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'themeMode': themeMode.name,
    'historyOrder': historyOrder.name,
    'boardMode': boardMode.name,
    'analysisWindow': analysisWindow,
    'recentWindows': recentWindows,
    'animationsEnabled': animationsEnabled,
    'hapticsEnabled': hapticsEnabled,
  };

  // Kept near JSON serialization for readability.
  // ignore: sort_constructors_first
  factory AppSettings.fromJson(Map<String, Object?> json) {
    T enumValue<T extends Enum>(List<T> values, String? name, T fallback) =>
        values.where((T value) => value.name == name).firstOrNull ?? fallback;
    final Object? windowsValue = json['recentWindows'];
    final List<int> windows = windowsValue is List<Object?>
        ? windowsValue
              .whereType<num>()
              .map((num value) => value.toInt())
              .toList()
        : const <int>[5, 10, 20, 30];
    final List<int> safeWindows =
        windows
            .where((int value) => value > 0 && value <= 10000)
            .toSet()
            .toList()
          ..sort();
    return AppSettings(
      themeMode: enumValue(
        AppThemeMode.values,
        json['themeMode'] as String?,
        AppThemeMode.dark,
      ),
      historyOrder: enumValue(
        HistoryOrder.values,
        json['historyOrder'] as String?,
        HistoryOrder.newestFirst,
      ),
      boardMode: enumValue(
        BoardMode.values,
        json['boardMode'] as String?,
        BoardMode.input,
      ),
      analysisWindow: (json['analysisWindow'] as num?)?.toInt() ?? 0,
      recentWindows: safeWindows.isEmpty
          ? const <int>[5, 10, 20, 30]
          : safeWindows,
      animationsEnabled: json['animationsEnabled'] as bool? ?? true,
      hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
    );
  }
}
