// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  late final GeneratedColumnWithTypeConverter<AppThemeMode, String> themeMode =
      GeneratedColumn<String>(
        'theme_mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('scheduled'),
      ).withConverter<AppThemeMode>($SettingsTable.$converterthemeMode);
  static const VerificationMeta _darkStartMinutesMeta = const VerificationMeta(
    'darkStartMinutes',
  );
  @override
  late final GeneratedColumn<int> darkStartMinutes = GeneratedColumn<int>(
    'dark_start_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(20 * 60),
  );
  static const VerificationMeta _darkEndMinutesMeta = const VerificationMeta(
    'darkEndMinutes',
  );
  @override
  late final GeneratedColumn<int> darkEndMinutes = GeneratedColumn<int>(
    'dark_end_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(7 * 60),
  );
  static const VerificationMeta _seedColorArgbMeta = const VerificationMeta(
    'seedColorArgb',
  );
  @override
  late final GeneratedColumn<int> seedColorArgb = GeneratedColumn<int>(
    'seed_color_argb',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFF009688),
  );
  static const VerificationMeta _languageCodeMeta = const VerificationMeta(
    'languageCode',
  );
  @override
  late final GeneratedColumn<String> languageCode = GeneratedColumn<String>(
    'language_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('en'),
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 3,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('EUR'),
  );
  static const VerificationMeta _adminPinMeta = const VerificationMeta(
    'adminPin',
  );
  @override
  late final GeneratedColumn<String> adminPin = GeneratedColumn<String>(
    'admin_pin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _allowSelfRegistrationMeta =
      const VerificationMeta('allowSelfRegistration');
  @override
  late final GeneratedColumn<bool> allowSelfRegistration =
      GeneratedColumn<bool>(
        'allow_self_registration',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("allow_self_registration" IN (0, 1))',
        ),
        defaultValue: const Constant(true),
      );
  static const VerificationMeta _payeeNameMeta = const VerificationMeta(
    'payeeName',
  );
  @override
  late final GeneratedColumn<String> payeeName = GeneratedColumn<String>(
    'payee_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payeeIbanMeta = const VerificationMeta(
    'payeeIban',
  );
  @override
  late final GeneratedColumn<String> payeeIban = GeneratedColumn<String>(
    'payee_iban',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<StartupPage, String> startupPage =
      GeneratedColumn<String>(
        'startup_page',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('start'),
      ).withConverter<StartupPage>($SettingsTable.$converterstartupPage);
  static const VerificationMeta _setupCompletedAtMeta = const VerificationMeta(
    'setupCompletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> setupCompletedAt =
      GeneratedColumn<DateTime>(
        'setup_completed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    themeMode,
    darkStartMinutes,
    darkEndMinutes,
    seedColorArgb,
    languageCode,
    currencyCode,
    adminPin,
    allowSelfRegistration,
    payeeName,
    payeeIban,
    startupPage,
    setupCompletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('dark_start_minutes')) {
      context.handle(
        _darkStartMinutesMeta,
        darkStartMinutes.isAcceptableOrUnknown(
          data['dark_start_minutes']!,
          _darkStartMinutesMeta,
        ),
      );
    }
    if (data.containsKey('dark_end_minutes')) {
      context.handle(
        _darkEndMinutesMeta,
        darkEndMinutes.isAcceptableOrUnknown(
          data['dark_end_minutes']!,
          _darkEndMinutesMeta,
        ),
      );
    }
    if (data.containsKey('seed_color_argb')) {
      context.handle(
        _seedColorArgbMeta,
        seedColorArgb.isAcceptableOrUnknown(
          data['seed_color_argb']!,
          _seedColorArgbMeta,
        ),
      );
    }
    if (data.containsKey('language_code')) {
      context.handle(
        _languageCodeMeta,
        languageCode.isAcceptableOrUnknown(
          data['language_code']!,
          _languageCodeMeta,
        ),
      );
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    }
    if (data.containsKey('admin_pin')) {
      context.handle(
        _adminPinMeta,
        adminPin.isAcceptableOrUnknown(data['admin_pin']!, _adminPinMeta),
      );
    }
    if (data.containsKey('allow_self_registration')) {
      context.handle(
        _allowSelfRegistrationMeta,
        allowSelfRegistration.isAcceptableOrUnknown(
          data['allow_self_registration']!,
          _allowSelfRegistrationMeta,
        ),
      );
    }
    if (data.containsKey('payee_name')) {
      context.handle(
        _payeeNameMeta,
        payeeName.isAcceptableOrUnknown(data['payee_name']!, _payeeNameMeta),
      );
    }
    if (data.containsKey('payee_iban')) {
      context.handle(
        _payeeIbanMeta,
        payeeIban.isAcceptableOrUnknown(data['payee_iban']!, _payeeIbanMeta),
      );
    }
    if (data.containsKey('setup_completed_at')) {
      context.handle(
        _setupCompletedAtMeta,
        setupCompletedAt.isAcceptableOrUnknown(
          data['setup_completed_at']!,
          _setupCompletedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      themeMode: $SettingsTable.$converterthemeMode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}theme_mode'],
        )!,
      ),
      darkStartMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dark_start_minutes'],
      )!,
      darkEndMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dark_end_minutes'],
      )!,
      seedColorArgb: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seed_color_argb'],
      )!,
      languageCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language_code'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      adminPin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}admin_pin'],
      ),
      allowSelfRegistration: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allow_self_registration'],
      )!,
      payeeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payee_name'],
      ),
      payeeIban: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payee_iban'],
      ),
      startupPage: $SettingsTable.$converterstartupPage.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}startup_page'],
        )!,
      ),
      setupCompletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}setup_completed_at'],
      ),
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AppThemeMode, String, String> $converterthemeMode =
      const EnumNameConverter<AppThemeMode>(AppThemeMode.values);
  static JsonTypeConverter2<StartupPage, String, String> $converterstartupPage =
      const EnumNameConverter<StartupPage>(StartupPage.values);
}

class SettingsRow extends DataClass implements Insertable<SettingsRow> {
  final int id;
  final AppThemeMode themeMode;
  final int darkStartMinutes;
  final int darkEndMinutes;

  /// Resolved ARGB, not an index into the palette. See CLAUDE.md rule 4.
  final int seedColorArgb;

  /// The UI language, one of `supportedLanguageCodes`. Language only — no
  /// regional variants.
  final String languageCode;

  /// ISO 4217. Independent of [languageCode]: the language says how numbers
  /// look, this says what money is in the tin.
  final String currencyCode;

  /// Plaintext. This is an honour-system app with no per-user login; the PIN
  /// only stops casual tampering. Recovery is reading the database off the
  /// tablet.
  final String? adminPin;
  final bool allowSelfRegistration;
  final String? payeeName;
  final String? payeeIban;
  final StartupPage startupPage;
  final DateTime? setupCompletedAt;
  const SettingsRow({
    required this.id,
    required this.themeMode,
    required this.darkStartMinutes,
    required this.darkEndMinutes,
    required this.seedColorArgb,
    required this.languageCode,
    required this.currencyCode,
    this.adminPin,
    required this.allowSelfRegistration,
    this.payeeName,
    this.payeeIban,
    required this.startupPage,
    this.setupCompletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['theme_mode'] = Variable<String>(
        $SettingsTable.$converterthemeMode.toSql(themeMode),
      );
    }
    map['dark_start_minutes'] = Variable<int>(darkStartMinutes);
    map['dark_end_minutes'] = Variable<int>(darkEndMinutes);
    map['seed_color_argb'] = Variable<int>(seedColorArgb);
    map['language_code'] = Variable<String>(languageCode);
    map['currency_code'] = Variable<String>(currencyCode);
    if (!nullToAbsent || adminPin != null) {
      map['admin_pin'] = Variable<String>(adminPin);
    }
    map['allow_self_registration'] = Variable<bool>(allowSelfRegistration);
    if (!nullToAbsent || payeeName != null) {
      map['payee_name'] = Variable<String>(payeeName);
    }
    if (!nullToAbsent || payeeIban != null) {
      map['payee_iban'] = Variable<String>(payeeIban);
    }
    {
      map['startup_page'] = Variable<String>(
        $SettingsTable.$converterstartupPage.toSql(startupPage),
      );
    }
    if (!nullToAbsent || setupCompletedAt != null) {
      map['setup_completed_at'] = Variable<DateTime>(setupCompletedAt);
    }
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      id: Value(id),
      themeMode: Value(themeMode),
      darkStartMinutes: Value(darkStartMinutes),
      darkEndMinutes: Value(darkEndMinutes),
      seedColorArgb: Value(seedColorArgb),
      languageCode: Value(languageCode),
      currencyCode: Value(currencyCode),
      adminPin: adminPin == null && nullToAbsent
          ? const Value.absent()
          : Value(adminPin),
      allowSelfRegistration: Value(allowSelfRegistration),
      payeeName: payeeName == null && nullToAbsent
          ? const Value.absent()
          : Value(payeeName),
      payeeIban: payeeIban == null && nullToAbsent
          ? const Value.absent()
          : Value(payeeIban),
      startupPage: Value(startupPage),
      setupCompletedAt: setupCompletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(setupCompletedAt),
    );
  }

  factory SettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingsRow(
      id: serializer.fromJson<int>(json['id']),
      themeMode: $SettingsTable.$converterthemeMode.fromJson(
        serializer.fromJson<String>(json['themeMode']),
      ),
      darkStartMinutes: serializer.fromJson<int>(json['darkStartMinutes']),
      darkEndMinutes: serializer.fromJson<int>(json['darkEndMinutes']),
      seedColorArgb: serializer.fromJson<int>(json['seedColorArgb']),
      languageCode: serializer.fromJson<String>(json['languageCode']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      adminPin: serializer.fromJson<String?>(json['adminPin']),
      allowSelfRegistration: serializer.fromJson<bool>(
        json['allowSelfRegistration'],
      ),
      payeeName: serializer.fromJson<String?>(json['payeeName']),
      payeeIban: serializer.fromJson<String?>(json['payeeIban']),
      startupPage: $SettingsTable.$converterstartupPage.fromJson(
        serializer.fromJson<String>(json['startupPage']),
      ),
      setupCompletedAt: serializer.fromJson<DateTime?>(
        json['setupCompletedAt'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'themeMode': serializer.toJson<String>(
        $SettingsTable.$converterthemeMode.toJson(themeMode),
      ),
      'darkStartMinutes': serializer.toJson<int>(darkStartMinutes),
      'darkEndMinutes': serializer.toJson<int>(darkEndMinutes),
      'seedColorArgb': serializer.toJson<int>(seedColorArgb),
      'languageCode': serializer.toJson<String>(languageCode),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'adminPin': serializer.toJson<String?>(adminPin),
      'allowSelfRegistration': serializer.toJson<bool>(allowSelfRegistration),
      'payeeName': serializer.toJson<String?>(payeeName),
      'payeeIban': serializer.toJson<String?>(payeeIban),
      'startupPage': serializer.toJson<String>(
        $SettingsTable.$converterstartupPage.toJson(startupPage),
      ),
      'setupCompletedAt': serializer.toJson<DateTime?>(setupCompletedAt),
    };
  }

  SettingsRow copyWith({
    int? id,
    AppThemeMode? themeMode,
    int? darkStartMinutes,
    int? darkEndMinutes,
    int? seedColorArgb,
    String? languageCode,
    String? currencyCode,
    Value<String?> adminPin = const Value.absent(),
    bool? allowSelfRegistration,
    Value<String?> payeeName = const Value.absent(),
    Value<String?> payeeIban = const Value.absent(),
    StartupPage? startupPage,
    Value<DateTime?> setupCompletedAt = const Value.absent(),
  }) => SettingsRow(
    id: id ?? this.id,
    themeMode: themeMode ?? this.themeMode,
    darkStartMinutes: darkStartMinutes ?? this.darkStartMinutes,
    darkEndMinutes: darkEndMinutes ?? this.darkEndMinutes,
    seedColorArgb: seedColorArgb ?? this.seedColorArgb,
    languageCode: languageCode ?? this.languageCode,
    currencyCode: currencyCode ?? this.currencyCode,
    adminPin: adminPin.present ? adminPin.value : this.adminPin,
    allowSelfRegistration: allowSelfRegistration ?? this.allowSelfRegistration,
    payeeName: payeeName.present ? payeeName.value : this.payeeName,
    payeeIban: payeeIban.present ? payeeIban.value : this.payeeIban,
    startupPage: startupPage ?? this.startupPage,
    setupCompletedAt: setupCompletedAt.present
        ? setupCompletedAt.value
        : this.setupCompletedAt,
  );
  SettingsRow copyWithCompanion(SettingsCompanion data) {
    return SettingsRow(
      id: data.id.present ? data.id.value : this.id,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      darkStartMinutes: data.darkStartMinutes.present
          ? data.darkStartMinutes.value
          : this.darkStartMinutes,
      darkEndMinutes: data.darkEndMinutes.present
          ? data.darkEndMinutes.value
          : this.darkEndMinutes,
      seedColorArgb: data.seedColorArgb.present
          ? data.seedColorArgb.value
          : this.seedColorArgb,
      languageCode: data.languageCode.present
          ? data.languageCode.value
          : this.languageCode,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      adminPin: data.adminPin.present ? data.adminPin.value : this.adminPin,
      allowSelfRegistration: data.allowSelfRegistration.present
          ? data.allowSelfRegistration.value
          : this.allowSelfRegistration,
      payeeName: data.payeeName.present ? data.payeeName.value : this.payeeName,
      payeeIban: data.payeeIban.present ? data.payeeIban.value : this.payeeIban,
      startupPage: data.startupPage.present
          ? data.startupPage.value
          : this.startupPage,
      setupCompletedAt: data.setupCompletedAt.present
          ? data.setupCompletedAt.value
          : this.setupCompletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingsRow(')
          ..write('id: $id, ')
          ..write('themeMode: $themeMode, ')
          ..write('darkStartMinutes: $darkStartMinutes, ')
          ..write('darkEndMinutes: $darkEndMinutes, ')
          ..write('seedColorArgb: $seedColorArgb, ')
          ..write('languageCode: $languageCode, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('adminPin: $adminPin, ')
          ..write('allowSelfRegistration: $allowSelfRegistration, ')
          ..write('payeeName: $payeeName, ')
          ..write('payeeIban: $payeeIban, ')
          ..write('startupPage: $startupPage, ')
          ..write('setupCompletedAt: $setupCompletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    themeMode,
    darkStartMinutes,
    darkEndMinutes,
    seedColorArgb,
    languageCode,
    currencyCode,
    adminPin,
    allowSelfRegistration,
    payeeName,
    payeeIban,
    startupPage,
    setupCompletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingsRow &&
          other.id == this.id &&
          other.themeMode == this.themeMode &&
          other.darkStartMinutes == this.darkStartMinutes &&
          other.darkEndMinutes == this.darkEndMinutes &&
          other.seedColorArgb == this.seedColorArgb &&
          other.languageCode == this.languageCode &&
          other.currencyCode == this.currencyCode &&
          other.adminPin == this.adminPin &&
          other.allowSelfRegistration == this.allowSelfRegistration &&
          other.payeeName == this.payeeName &&
          other.payeeIban == this.payeeIban &&
          other.startupPage == this.startupPage &&
          other.setupCompletedAt == this.setupCompletedAt);
}

class SettingsCompanion extends UpdateCompanion<SettingsRow> {
  final Value<int> id;
  final Value<AppThemeMode> themeMode;
  final Value<int> darkStartMinutes;
  final Value<int> darkEndMinutes;
  final Value<int> seedColorArgb;
  final Value<String> languageCode;
  final Value<String> currencyCode;
  final Value<String?> adminPin;
  final Value<bool> allowSelfRegistration;
  final Value<String?> payeeName;
  final Value<String?> payeeIban;
  final Value<StartupPage> startupPage;
  final Value<DateTime?> setupCompletedAt;
  const SettingsCompanion({
    this.id = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.darkStartMinutes = const Value.absent(),
    this.darkEndMinutes = const Value.absent(),
    this.seedColorArgb = const Value.absent(),
    this.languageCode = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.adminPin = const Value.absent(),
    this.allowSelfRegistration = const Value.absent(),
    this.payeeName = const Value.absent(),
    this.payeeIban = const Value.absent(),
    this.startupPage = const Value.absent(),
    this.setupCompletedAt = const Value.absent(),
  });
  SettingsCompanion.insert({
    this.id = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.darkStartMinutes = const Value.absent(),
    this.darkEndMinutes = const Value.absent(),
    this.seedColorArgb = const Value.absent(),
    this.languageCode = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.adminPin = const Value.absent(),
    this.allowSelfRegistration = const Value.absent(),
    this.payeeName = const Value.absent(),
    this.payeeIban = const Value.absent(),
    this.startupPage = const Value.absent(),
    this.setupCompletedAt = const Value.absent(),
  });
  static Insertable<SettingsRow> custom({
    Expression<int>? id,
    Expression<String>? themeMode,
    Expression<int>? darkStartMinutes,
    Expression<int>? darkEndMinutes,
    Expression<int>? seedColorArgb,
    Expression<String>? languageCode,
    Expression<String>? currencyCode,
    Expression<String>? adminPin,
    Expression<bool>? allowSelfRegistration,
    Expression<String>? payeeName,
    Expression<String>? payeeIban,
    Expression<String>? startupPage,
    Expression<DateTime>? setupCompletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (themeMode != null) 'theme_mode': themeMode,
      if (darkStartMinutes != null) 'dark_start_minutes': darkStartMinutes,
      if (darkEndMinutes != null) 'dark_end_minutes': darkEndMinutes,
      if (seedColorArgb != null) 'seed_color_argb': seedColorArgb,
      if (languageCode != null) 'language_code': languageCode,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (adminPin != null) 'admin_pin': adminPin,
      if (allowSelfRegistration != null)
        'allow_self_registration': allowSelfRegistration,
      if (payeeName != null) 'payee_name': payeeName,
      if (payeeIban != null) 'payee_iban': payeeIban,
      if (startupPage != null) 'startup_page': startupPage,
      if (setupCompletedAt != null) 'setup_completed_at': setupCompletedAt,
    });
  }

  SettingsCompanion copyWith({
    Value<int>? id,
    Value<AppThemeMode>? themeMode,
    Value<int>? darkStartMinutes,
    Value<int>? darkEndMinutes,
    Value<int>? seedColorArgb,
    Value<String>? languageCode,
    Value<String>? currencyCode,
    Value<String?>? adminPin,
    Value<bool>? allowSelfRegistration,
    Value<String?>? payeeName,
    Value<String?>? payeeIban,
    Value<StartupPage>? startupPage,
    Value<DateTime?>? setupCompletedAt,
  }) {
    return SettingsCompanion(
      id: id ?? this.id,
      themeMode: themeMode ?? this.themeMode,
      darkStartMinutes: darkStartMinutes ?? this.darkStartMinutes,
      darkEndMinutes: darkEndMinutes ?? this.darkEndMinutes,
      seedColorArgb: seedColorArgb ?? this.seedColorArgb,
      languageCode: languageCode ?? this.languageCode,
      currencyCode: currencyCode ?? this.currencyCode,
      adminPin: adminPin ?? this.adminPin,
      allowSelfRegistration:
          allowSelfRegistration ?? this.allowSelfRegistration,
      payeeName: payeeName ?? this.payeeName,
      payeeIban: payeeIban ?? this.payeeIban,
      startupPage: startupPage ?? this.startupPage,
      setupCompletedAt: setupCompletedAt ?? this.setupCompletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(
        $SettingsTable.$converterthemeMode.toSql(themeMode.value),
      );
    }
    if (darkStartMinutes.present) {
      map['dark_start_minutes'] = Variable<int>(darkStartMinutes.value);
    }
    if (darkEndMinutes.present) {
      map['dark_end_minutes'] = Variable<int>(darkEndMinutes.value);
    }
    if (seedColorArgb.present) {
      map['seed_color_argb'] = Variable<int>(seedColorArgb.value);
    }
    if (languageCode.present) {
      map['language_code'] = Variable<String>(languageCode.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (adminPin.present) {
      map['admin_pin'] = Variable<String>(adminPin.value);
    }
    if (allowSelfRegistration.present) {
      map['allow_self_registration'] = Variable<bool>(
        allowSelfRegistration.value,
      );
    }
    if (payeeName.present) {
      map['payee_name'] = Variable<String>(payeeName.value);
    }
    if (payeeIban.present) {
      map['payee_iban'] = Variable<String>(payeeIban.value);
    }
    if (startupPage.present) {
      map['startup_page'] = Variable<String>(
        $SettingsTable.$converterstartupPage.toSql(startupPage.value),
      );
    }
    if (setupCompletedAt.present) {
      map['setup_completed_at'] = Variable<DateTime>(setupCompletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('id: $id, ')
          ..write('themeMode: $themeMode, ')
          ..write('darkStartMinutes: $darkStartMinutes, ')
          ..write('darkEndMinutes: $darkEndMinutes, ')
          ..write('seedColorArgb: $seedColorArgb, ')
          ..write('languageCode: $languageCode, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('adminPin: $adminPin, ')
          ..write('allowSelfRegistration: $allowSelfRegistration, ')
          ..write('payeeName: $payeeName, ')
          ..write('payeeIban: $payeeIban, ')
          ..write('startupPage: $startupPage, ')
          ..write('setupCompletedAt: $setupCompletedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final SettingsDao settingsDao = SettingsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [settings];
}

typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  Value<int> id,
  Value<AppThemeMode> themeMode,
  Value<int> darkStartMinutes,
  Value<int> darkEndMinutes,
  Value<int> seedColorArgb,
  Value<String> languageCode,
  Value<String> currencyCode,
  Value<String?> adminPin,
  Value<bool> allowSelfRegistration,
  Value<String?> payeeName,
  Value<String?> payeeIban,
  Value<StartupPage> startupPage,
  Value<DateTime?> setupCompletedAt,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<int> id,
  Value<AppThemeMode> themeMode,
  Value<int> darkStartMinutes,
  Value<int> darkEndMinutes,
  Value<int> seedColorArgb,
  Value<String> languageCode,
  Value<String> currencyCode,
  Value<String?> adminPin,
  Value<bool> allowSelfRegistration,
  Value<String?> payeeName,
  Value<String?> payeeIban,
  Value<StartupPage> startupPage,
  Value<DateTime?> setupCompletedAt,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AppThemeMode, AppThemeMode, String>
  get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get darkStartMinutes => $composableBuilder(
    column: $table.darkStartMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get darkEndMinutes => $composableBuilder(
    column: $table.darkEndMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seedColorArgb => $composableBuilder(
    column: $table.seedColorArgb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get adminPin => $composableBuilder(
    column: $table.adminPin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allowSelfRegistration => $composableBuilder(
    column: $table.allowSelfRegistration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payeeName => $composableBuilder(
    column: $table.payeeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payeeIban => $composableBuilder(
    column: $table.payeeIban,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<StartupPage, StartupPage, String>
  get startupPage => $composableBuilder(
    column: $table.startupPage,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get setupCompletedAt => $composableBuilder(
    column: $table.setupCompletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get darkStartMinutes => $composableBuilder(
    column: $table.darkStartMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get darkEndMinutes => $composableBuilder(
    column: $table.darkEndMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seedColorArgb => $composableBuilder(
    column: $table.seedColorArgb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get adminPin => $composableBuilder(
    column: $table.adminPin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allowSelfRegistration => $composableBuilder(
    column: $table.allowSelfRegistration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payeeName => $composableBuilder(
    column: $table.payeeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payeeIban => $composableBuilder(
    column: $table.payeeIban,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startupPage => $composableBuilder(
    column: $table.startupPage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get setupCompletedAt => $composableBuilder(
    column: $table.setupCompletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AppThemeMode, String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<int> get darkStartMinutes => $composableBuilder(
    column: $table.darkStartMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get darkEndMinutes => $composableBuilder(
    column: $table.darkEndMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get seedColorArgb => $composableBuilder(
    column: $table.seedColorArgb,
    builder: (column) => column,
  );

  GeneratedColumn<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get adminPin =>
      $composableBuilder(column: $table.adminPin, builder: (column) => column);

  GeneratedColumn<bool> get allowSelfRegistration => $composableBuilder(
    column: $table.allowSelfRegistration,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payeeName =>
      $composableBuilder(column: $table.payeeName, builder: (column) => column);

  GeneratedColumn<String> get payeeIban =>
      $composableBuilder(column: $table.payeeIban, builder: (column) => column);

  GeneratedColumnWithTypeConverter<StartupPage, String> get startupPage =>
      $composableBuilder(
        column: $table.startupPage,
        builder: (column) => column,
      );

  GeneratedColumn<DateTime> get setupCompletedAt => $composableBuilder(
    column: $table.setupCompletedAt,
    builder: (column) => column,
  );
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingsRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingsRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingsRow>,
          ),
          SettingsRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<AppThemeMode> themeMode = const Value.absent(),
                Value<int> darkStartMinutes = const Value.absent(),
                Value<int> darkEndMinutes = const Value.absent(),
                Value<int> seedColorArgb = const Value.absent(),
                Value<String> languageCode = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<String?> adminPin = const Value.absent(),
                Value<bool> allowSelfRegistration = const Value.absent(),
                Value<String?> payeeName = const Value.absent(),
                Value<String?> payeeIban = const Value.absent(),
                Value<StartupPage> startupPage = const Value.absent(),
                Value<DateTime?> setupCompletedAt = const Value.absent(),
              }) => SettingsCompanion(
                id: id,
                themeMode: themeMode,
                darkStartMinutes: darkStartMinutes,
                darkEndMinutes: darkEndMinutes,
                seedColorArgb: seedColorArgb,
                languageCode: languageCode,
                currencyCode: currencyCode,
                adminPin: adminPin,
                allowSelfRegistration: allowSelfRegistration,
                payeeName: payeeName,
                payeeIban: payeeIban,
                startupPage: startupPage,
                setupCompletedAt: setupCompletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<AppThemeMode> themeMode = const Value.absent(),
                Value<int> darkStartMinutes = const Value.absent(),
                Value<int> darkEndMinutes = const Value.absent(),
                Value<int> seedColorArgb = const Value.absent(),
                Value<String> languageCode = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<String?> adminPin = const Value.absent(),
                Value<bool> allowSelfRegistration = const Value.absent(),
                Value<String?> payeeName = const Value.absent(),
                Value<String?> payeeIban = const Value.absent(),
                Value<StartupPage> startupPage = const Value.absent(),
                Value<DateTime?> setupCompletedAt = const Value.absent(),
              }) => SettingsCompanion.insert(
                id: id,
                themeMode: themeMode,
                darkStartMinutes: darkStartMinutes,
                darkEndMinutes: darkEndMinutes,
                seedColorArgb: seedColorArgb,
                languageCode: languageCode,
                currencyCode: currencyCode,
                adminPin: adminPin,
                allowSelfRegistration: allowSelfRegistration,
                payeeName: payeeName,
                payeeIban: payeeIban,
                startupPage: startupPage,
                setupCompletedAt: setupCompletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingsRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingsRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingsRow>),
      SettingsRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
