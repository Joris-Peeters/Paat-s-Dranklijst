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
  @override
  late final GeneratedColumnWithTypeConverter<TimeOfDay, int> darkStart =
      GeneratedColumn<int>(
        'dark_start',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(20 * 60),
      ).withConverter<TimeOfDay>($SettingsTable.$converterdarkStart);
  @override
  late final GeneratedColumnWithTypeConverter<TimeOfDay, int> darkEnd =
      GeneratedColumn<int>(
        'dark_end',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(7 * 60),
      ).withConverter<TimeOfDay>($SettingsTable.$converterdarkEnd);
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
    darkStart,
    darkEnd,
    seedColorArgb,
    languageCode,
    currencyCode,
    adminPin,
    allowSelfRegistration,
    payeeName,
    payeeIban,
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
      darkStart: $SettingsTable.$converterdarkStart.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}dark_start'],
        )!,
      ),
      darkEnd: $SettingsTable.$converterdarkEnd.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}dark_end'],
        )!,
      ),
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
  static JsonTypeConverter2<TimeOfDay, int, int> $converterdarkStart =
      const TimeOfDayConverter();
  static JsonTypeConverter2<TimeOfDay, int, int> $converterdarkEnd =
      const TimeOfDayConverter();
}

class SettingsRow extends DataClass implements Insertable<SettingsRow> {
  final int id;
  final AppThemeMode themeMode;
  final TimeOfDay darkStart;
  final TimeOfDay darkEnd;
  final int seedColorArgb;

  /// The UI language, one of `supportedLanguageCodes`.
  final String languageCode;

  /// ISO 4217 Currency code.
  final String currencyCode;

  /// Plaintext. Doesn't have to be secure.
  final String? adminPin;
  final bool allowSelfRegistration;
  final String? payeeName;
  final String? payeeIban;
  final DateTime? setupCompletedAt;
  const SettingsRow({
    required this.id,
    required this.themeMode,
    required this.darkStart,
    required this.darkEnd,
    required this.seedColorArgb,
    required this.languageCode,
    required this.currencyCode,
    this.adminPin,
    required this.allowSelfRegistration,
    this.payeeName,
    this.payeeIban,
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
    {
      map['dark_start'] = Variable<int>(
        $SettingsTable.$converterdarkStart.toSql(darkStart),
      );
    }
    {
      map['dark_end'] = Variable<int>(
        $SettingsTable.$converterdarkEnd.toSql(darkEnd),
      );
    }
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
    if (!nullToAbsent || setupCompletedAt != null) {
      map['setup_completed_at'] = Variable<DateTime>(setupCompletedAt);
    }
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      id: Value(id),
      themeMode: Value(themeMode),
      darkStart: Value(darkStart),
      darkEnd: Value(darkEnd),
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
      darkStart: $SettingsTable.$converterdarkStart.fromJson(
        serializer.fromJson<int>(json['darkStart']),
      ),
      darkEnd: $SettingsTable.$converterdarkEnd.fromJson(
        serializer.fromJson<int>(json['darkEnd']),
      ),
      seedColorArgb: serializer.fromJson<int>(json['seedColorArgb']),
      languageCode: serializer.fromJson<String>(json['languageCode']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      adminPin: serializer.fromJson<String?>(json['adminPin']),
      allowSelfRegistration: serializer.fromJson<bool>(
        json['allowSelfRegistration'],
      ),
      payeeName: serializer.fromJson<String?>(json['payeeName']),
      payeeIban: serializer.fromJson<String?>(json['payeeIban']),
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
      'darkStart': serializer.toJson<int>(
        $SettingsTable.$converterdarkStart.toJson(darkStart),
      ),
      'darkEnd': serializer.toJson<int>(
        $SettingsTable.$converterdarkEnd.toJson(darkEnd),
      ),
      'seedColorArgb': serializer.toJson<int>(seedColorArgb),
      'languageCode': serializer.toJson<String>(languageCode),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'adminPin': serializer.toJson<String?>(adminPin),
      'allowSelfRegistration': serializer.toJson<bool>(allowSelfRegistration),
      'payeeName': serializer.toJson<String?>(payeeName),
      'payeeIban': serializer.toJson<String?>(payeeIban),
      'setupCompletedAt': serializer.toJson<DateTime?>(setupCompletedAt),
    };
  }

  SettingsRow copyWith({
    int? id,
    AppThemeMode? themeMode,
    TimeOfDay? darkStart,
    TimeOfDay? darkEnd,
    int? seedColorArgb,
    String? languageCode,
    String? currencyCode,
    Value<String?> adminPin = const Value.absent(),
    bool? allowSelfRegistration,
    Value<String?> payeeName = const Value.absent(),
    Value<String?> payeeIban = const Value.absent(),
    Value<DateTime?> setupCompletedAt = const Value.absent(),
  }) => SettingsRow(
    id: id ?? this.id,
    themeMode: themeMode ?? this.themeMode,
    darkStart: darkStart ?? this.darkStart,
    darkEnd: darkEnd ?? this.darkEnd,
    seedColorArgb: seedColorArgb ?? this.seedColorArgb,
    languageCode: languageCode ?? this.languageCode,
    currencyCode: currencyCode ?? this.currencyCode,
    adminPin: adminPin.present ? adminPin.value : this.adminPin,
    allowSelfRegistration: allowSelfRegistration ?? this.allowSelfRegistration,
    payeeName: payeeName.present ? payeeName.value : this.payeeName,
    payeeIban: payeeIban.present ? payeeIban.value : this.payeeIban,
    setupCompletedAt: setupCompletedAt.present
        ? setupCompletedAt.value
        : this.setupCompletedAt,
  );
  SettingsRow copyWithCompanion(SettingsCompanion data) {
    return SettingsRow(
      id: data.id.present ? data.id.value : this.id,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      darkStart: data.darkStart.present ? data.darkStart.value : this.darkStart,
      darkEnd: data.darkEnd.present ? data.darkEnd.value : this.darkEnd,
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
          ..write('darkStart: $darkStart, ')
          ..write('darkEnd: $darkEnd, ')
          ..write('seedColorArgb: $seedColorArgb, ')
          ..write('languageCode: $languageCode, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('adminPin: $adminPin, ')
          ..write('allowSelfRegistration: $allowSelfRegistration, ')
          ..write('payeeName: $payeeName, ')
          ..write('payeeIban: $payeeIban, ')
          ..write('setupCompletedAt: $setupCompletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    themeMode,
    darkStart,
    darkEnd,
    seedColorArgb,
    languageCode,
    currencyCode,
    adminPin,
    allowSelfRegistration,
    payeeName,
    payeeIban,
    setupCompletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingsRow &&
          other.id == this.id &&
          other.themeMode == this.themeMode &&
          other.darkStart == this.darkStart &&
          other.darkEnd == this.darkEnd &&
          other.seedColorArgb == this.seedColorArgb &&
          other.languageCode == this.languageCode &&
          other.currencyCode == this.currencyCode &&
          other.adminPin == this.adminPin &&
          other.allowSelfRegistration == this.allowSelfRegistration &&
          other.payeeName == this.payeeName &&
          other.payeeIban == this.payeeIban &&
          other.setupCompletedAt == this.setupCompletedAt);
}

class SettingsCompanion extends UpdateCompanion<SettingsRow> {
  final Value<int> id;
  final Value<AppThemeMode> themeMode;
  final Value<TimeOfDay> darkStart;
  final Value<TimeOfDay> darkEnd;
  final Value<int> seedColorArgb;
  final Value<String> languageCode;
  final Value<String> currencyCode;
  final Value<String?> adminPin;
  final Value<bool> allowSelfRegistration;
  final Value<String?> payeeName;
  final Value<String?> payeeIban;
  final Value<DateTime?> setupCompletedAt;
  const SettingsCompanion({
    this.id = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.darkStart = const Value.absent(),
    this.darkEnd = const Value.absent(),
    this.seedColorArgb = const Value.absent(),
    this.languageCode = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.adminPin = const Value.absent(),
    this.allowSelfRegistration = const Value.absent(),
    this.payeeName = const Value.absent(),
    this.payeeIban = const Value.absent(),
    this.setupCompletedAt = const Value.absent(),
  });
  SettingsCompanion.insert({
    this.id = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.darkStart = const Value.absent(),
    this.darkEnd = const Value.absent(),
    this.seedColorArgb = const Value.absent(),
    this.languageCode = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.adminPin = const Value.absent(),
    this.allowSelfRegistration = const Value.absent(),
    this.payeeName = const Value.absent(),
    this.payeeIban = const Value.absent(),
    this.setupCompletedAt = const Value.absent(),
  });
  static Insertable<SettingsRow> custom({
    Expression<int>? id,
    Expression<String>? themeMode,
    Expression<int>? darkStart,
    Expression<int>? darkEnd,
    Expression<int>? seedColorArgb,
    Expression<String>? languageCode,
    Expression<String>? currencyCode,
    Expression<String>? adminPin,
    Expression<bool>? allowSelfRegistration,
    Expression<String>? payeeName,
    Expression<String>? payeeIban,
    Expression<DateTime>? setupCompletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (themeMode != null) 'theme_mode': themeMode,
      if (darkStart != null) 'dark_start': darkStart,
      if (darkEnd != null) 'dark_end': darkEnd,
      if (seedColorArgb != null) 'seed_color_argb': seedColorArgb,
      if (languageCode != null) 'language_code': languageCode,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (adminPin != null) 'admin_pin': adminPin,
      if (allowSelfRegistration != null)
        'allow_self_registration': allowSelfRegistration,
      if (payeeName != null) 'payee_name': payeeName,
      if (payeeIban != null) 'payee_iban': payeeIban,
      if (setupCompletedAt != null) 'setup_completed_at': setupCompletedAt,
    });
  }

  SettingsCompanion copyWith({
    Value<int>? id,
    Value<AppThemeMode>? themeMode,
    Value<TimeOfDay>? darkStart,
    Value<TimeOfDay>? darkEnd,
    Value<int>? seedColorArgb,
    Value<String>? languageCode,
    Value<String>? currencyCode,
    Value<String?>? adminPin,
    Value<bool>? allowSelfRegistration,
    Value<String?>? payeeName,
    Value<String?>? payeeIban,
    Value<DateTime?>? setupCompletedAt,
  }) {
    return SettingsCompanion(
      id: id ?? this.id,
      themeMode: themeMode ?? this.themeMode,
      darkStart: darkStart ?? this.darkStart,
      darkEnd: darkEnd ?? this.darkEnd,
      seedColorArgb: seedColorArgb ?? this.seedColorArgb,
      languageCode: languageCode ?? this.languageCode,
      currencyCode: currencyCode ?? this.currencyCode,
      adminPin: adminPin ?? this.adminPin,
      allowSelfRegistration:
          allowSelfRegistration ?? this.allowSelfRegistration,
      payeeName: payeeName ?? this.payeeName,
      payeeIban: payeeIban ?? this.payeeIban,
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
    if (darkStart.present) {
      map['dark_start'] = Variable<int>(
        $SettingsTable.$converterdarkStart.toSql(darkStart.value),
      );
    }
    if (darkEnd.present) {
      map['dark_end'] = Variable<int>(
        $SettingsTable.$converterdarkEnd.toSql(darkEnd.value),
      );
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
          ..write('darkStart: $darkStart, ')
          ..write('darkEnd: $darkEnd, ')
          ..write('seedColorArgb: $seedColorArgb, ')
          ..write('languageCode: $languageCode, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('adminPin: $adminPin, ')
          ..write('allowSelfRegistration: $allowSelfRegistration, ')
          ..write('payeeName: $payeeName, ')
          ..write('payeeIban: $payeeIban, ')
          ..write('setupCompletedAt: $setupCompletedAt')
          ..write(')'))
        .toString();
  }
}

class $UserGroupsTable extends UserGroups
    with TableInfo<$UserGroupsTable, UserGroupRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
    'emoji',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, emoji, sortOrder, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserGroupRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('emoji')) {
      context.handle(
        _emojiMeta,
        emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserGroupRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserGroupRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      emoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emoji'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $UserGroupsTable createAlias(String alias) {
    return $UserGroupsTable(attachedDatabase, alias);
  }
}

class UserGroupRow extends DataClass implements Insertable<UserGroupRow> {
  final int id;
  final String name;
  final String? emoji;
  final int sortOrder;
  final DateTime createdAt;
  const UserGroupRow({
    required this.id,
    required this.name,
    this.emoji,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || emoji != null) {
      map['emoji'] = Variable<String>(emoji);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  UserGroupsCompanion toCompanion(bool nullToAbsent) {
    return UserGroupsCompanion(
      id: Value(id),
      name: Value(name),
      emoji: emoji == null && nullToAbsent
          ? const Value.absent()
          : Value(emoji),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory UserGroupRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserGroupRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      emoji: serializer.fromJson<String?>(json['emoji']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'emoji': serializer.toJson<String?>(emoji),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  UserGroupRow copyWith({
    int? id,
    String? name,
    Value<String?> emoji = const Value.absent(),
    int? sortOrder,
    DateTime? createdAt,
  }) => UserGroupRow(
    id: id ?? this.id,
    name: name ?? this.name,
    emoji: emoji.present ? emoji.value : this.emoji,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  UserGroupRow copyWithCompanion(UserGroupsCompanion data) {
    return UserGroupRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserGroupRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('emoji: $emoji, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, emoji, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserGroupRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.emoji == this.emoji &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class UserGroupsCompanion extends UpdateCompanion<UserGroupRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> emoji;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  const UserGroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.emoji = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  UserGroupsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.emoji = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<UserGroupRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? emoji,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (emoji != null) 'emoji': emoji,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  UserGroupsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? emoji,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
  }) {
    return UserGroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserGroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('emoji: $emoji, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $UsersTable extends Users with TableInfo<$UsersTable, UserRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avatarEmojiMeta = const VerificationMeta(
    'avatarEmoji',
  );
  @override
  late final GeneratedColumn<String> avatarEmoji = GeneratedColumn<String>(
    'avatar_emoji',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avatarImageMeta = const VerificationMeta(
    'avatarImage',
  );
  @override
  late final GeneratedColumn<Uint8List> avatarImage =
      GeneratedColumn<Uint8List>(
        'avatar_image',
        aliasedName,
        true,
        type: DriftSqlType.blob,
        requiredDuringInsert: false,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES user_groups (id)',
    ),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    avatarEmoji,
    avatarImage,
    seedColorArgb,
    groupId,
    sortOrder,
    archivedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('avatar_emoji')) {
      context.handle(
        _avatarEmojiMeta,
        avatarEmoji.isAcceptableOrUnknown(
          data['avatar_emoji']!,
          _avatarEmojiMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_avatarEmojiMeta);
    }
    if (data.containsKey('avatar_image')) {
      context.handle(
        _avatarImageMeta,
        avatarImage.isAcceptableOrUnknown(
          data['avatar_image']!,
          _avatarImageMeta,
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
    } else if (isInserting) {
      context.missing(_seedColorArgbMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      avatarEmoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_emoji'],
      )!,
      avatarImage: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}avatar_image'],
      ),
      seedColorArgb: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seed_color_argb'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class UserRow extends DataClass implements Insertable<UserRow> {
  final int id;
  final String name;

  /// Always set: the create screen picks a random one, so there is no
  /// initials fallback to render. See rule 6.
  final String avatarEmoji;

  /// Reserved for the camera feature; here now so it needs no migration later.
  final Uint8List? avatarImage;

  /// Always set, likewise — every member gets their own accent colour rather
  /// than falling back to the global seed. Resolved ARGB, not a palette index,
  /// see rule 4.
  final int seedColorArgb;
  final int groupId;
  final int sortOrder;

  /// Soft delete: a departed member's ledger history stays intact and readable.
  final DateTime? archivedAt;
  final DateTime createdAt;
  const UserRow({
    required this.id,
    required this.name,
    required this.avatarEmoji,
    this.avatarImage,
    required this.seedColorArgb,
    required this.groupId,
    required this.sortOrder,
    this.archivedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['avatar_emoji'] = Variable<String>(avatarEmoji);
    if (!nullToAbsent || avatarImage != null) {
      map['avatar_image'] = Variable<Uint8List>(avatarImage);
    }
    map['seed_color_argb'] = Variable<int>(seedColorArgb);
    map['group_id'] = Variable<int>(groupId);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      name: Value(name),
      avatarEmoji: Value(avatarEmoji),
      avatarImage: avatarImage == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarImage),
      seedColorArgb: Value(seedColorArgb),
      groupId: Value(groupId),
      sortOrder: Value(sortOrder),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      createdAt: Value(createdAt),
    );
  }

  factory UserRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      avatarEmoji: serializer.fromJson<String>(json['avatarEmoji']),
      avatarImage: serializer.fromJson<Uint8List?>(json['avatarImage']),
      seedColorArgb: serializer.fromJson<int>(json['seedColorArgb']),
      groupId: serializer.fromJson<int>(json['groupId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'avatarEmoji': serializer.toJson<String>(avatarEmoji),
      'avatarImage': serializer.toJson<Uint8List?>(avatarImage),
      'seedColorArgb': serializer.toJson<int>(seedColorArgb),
      'groupId': serializer.toJson<int>(groupId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  UserRow copyWith({
    int? id,
    String? name,
    String? avatarEmoji,
    Value<Uint8List?> avatarImage = const Value.absent(),
    int? seedColorArgb,
    int? groupId,
    int? sortOrder,
    Value<DateTime?> archivedAt = const Value.absent(),
    DateTime? createdAt,
  }) => UserRow(
    id: id ?? this.id,
    name: name ?? this.name,
    avatarEmoji: avatarEmoji ?? this.avatarEmoji,
    avatarImage: avatarImage.present ? avatarImage.value : this.avatarImage,
    seedColorArgb: seedColorArgb ?? this.seedColorArgb,
    groupId: groupId ?? this.groupId,
    sortOrder: sortOrder ?? this.sortOrder,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  UserRow copyWithCompanion(UsersCompanion data) {
    return UserRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      avatarEmoji: data.avatarEmoji.present
          ? data.avatarEmoji.value
          : this.avatarEmoji,
      avatarImage: data.avatarImage.present
          ? data.avatarImage.value
          : this.avatarImage,
      seedColorArgb: data.seedColorArgb.present
          ? data.seedColorArgb.value
          : this.seedColorArgb,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('avatarEmoji: $avatarEmoji, ')
          ..write('avatarImage: $avatarImage, ')
          ..write('seedColorArgb: $seedColorArgb, ')
          ..write('groupId: $groupId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    avatarEmoji,
    $driftBlobEquality.hash(avatarImage),
    seedColorArgb,
    groupId,
    sortOrder,
    archivedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.avatarEmoji == this.avatarEmoji &&
          $driftBlobEquality.equals(other.avatarImage, this.avatarImage) &&
          other.seedColorArgb == this.seedColorArgb &&
          other.groupId == this.groupId &&
          other.sortOrder == this.sortOrder &&
          other.archivedAt == this.archivedAt &&
          other.createdAt == this.createdAt);
}

class UsersCompanion extends UpdateCompanion<UserRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> avatarEmoji;
  final Value<Uint8List?> avatarImage;
  final Value<int> seedColorArgb;
  final Value<int> groupId;
  final Value<int> sortOrder;
  final Value<DateTime?> archivedAt;
  final Value<DateTime> createdAt;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.avatarEmoji = const Value.absent(),
    this.avatarImage = const Value.absent(),
    this.seedColorArgb = const Value.absent(),
    this.groupId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  UsersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String avatarEmoji,
    this.avatarImage = const Value.absent(),
    required int seedColorArgb,
    required int groupId,
    this.sortOrder = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       avatarEmoji = Value(avatarEmoji),
       seedColorArgb = Value(seedColorArgb),
       groupId = Value(groupId);
  static Insertable<UserRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? avatarEmoji,
    Expression<Uint8List>? avatarImage,
    Expression<int>? seedColorArgb,
    Expression<int>? groupId,
    Expression<int>? sortOrder,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (avatarEmoji != null) 'avatar_emoji': avatarEmoji,
      if (avatarImage != null) 'avatar_image': avatarImage,
      if (seedColorArgb != null) 'seed_color_argb': seedColorArgb,
      if (groupId != null) 'group_id': groupId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  UsersCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? avatarEmoji,
    Value<Uint8List?>? avatarImage,
    Value<int>? seedColorArgb,
    Value<int>? groupId,
    Value<int>? sortOrder,
    Value<DateTime?>? archivedAt,
    Value<DateTime>? createdAt,
  }) {
    return UsersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      avatarImage: avatarImage ?? this.avatarImage,
      seedColorArgb: seedColorArgb ?? this.seedColorArgb,
      groupId: groupId ?? this.groupId,
      sortOrder: sortOrder ?? this.sortOrder,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (avatarEmoji.present) {
      map['avatar_emoji'] = Variable<String>(avatarEmoji.value);
    }
    if (avatarImage.present) {
      map['avatar_image'] = Variable<Uint8List>(avatarImage.value);
    }
    if (seedColorArgb.present) {
      map['seed_color_argb'] = Variable<int>(seedColorArgb.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('avatarEmoji: $avatarEmoji, ')
          ..write('avatarImage: $avatarImage, ')
          ..write('seedColorArgb: $seedColorArgb, ')
          ..write('groupId: $groupId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ItemGroupsTable extends ItemGroups
    with TableInfo<$ItemGroupsTable, ItemGroupRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
    'emoji',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, emoji, sortOrder, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'item_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemGroupRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('emoji')) {
      context.handle(
        _emojiMeta,
        emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ItemGroupRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemGroupRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      emoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emoji'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ItemGroupsTable createAlias(String alias) {
    return $ItemGroupsTable(attachedDatabase, alias);
  }
}

class ItemGroupRow extends DataClass implements Insertable<ItemGroupRow> {
  final int id;
  final String name;
  final String? emoji;
  final int sortOrder;
  final DateTime createdAt;
  const ItemGroupRow({
    required this.id,
    required this.name,
    this.emoji,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || emoji != null) {
      map['emoji'] = Variable<String>(emoji);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ItemGroupsCompanion toCompanion(bool nullToAbsent) {
    return ItemGroupsCompanion(
      id: Value(id),
      name: Value(name),
      emoji: emoji == null && nullToAbsent
          ? const Value.absent()
          : Value(emoji),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory ItemGroupRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemGroupRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      emoji: serializer.fromJson<String?>(json['emoji']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'emoji': serializer.toJson<String?>(emoji),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ItemGroupRow copyWith({
    int? id,
    String? name,
    Value<String?> emoji = const Value.absent(),
    int? sortOrder,
    DateTime? createdAt,
  }) => ItemGroupRow(
    id: id ?? this.id,
    name: name ?? this.name,
    emoji: emoji.present ? emoji.value : this.emoji,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  ItemGroupRow copyWithCompanion(ItemGroupsCompanion data) {
    return ItemGroupRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemGroupRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('emoji: $emoji, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, emoji, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemGroupRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.emoji == this.emoji &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class ItemGroupsCompanion extends UpdateCompanion<ItemGroupRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> emoji;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  const ItemGroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.emoji = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ItemGroupsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.emoji = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<ItemGroupRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? emoji,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (emoji != null) 'emoji': emoji,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ItemGroupsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? emoji,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
  }) {
    return ItemGroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemGroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('emoji: $emoji, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ItemsTable extends Items with TableInfo<$ItemsTable, ItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
    'emoji',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES item_groups (id)',
    ),
  );
  static const VerificationMeta _priceMinorUnitsMeta = const VerificationMeta(
    'priceMinorUnits',
  );
  @override
  late final GeneratedColumn<int> priceMinorUnits = GeneratedColumn<int>(
    'price_minor_units',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    emoji,
    groupId,
    priceMinorUnits,
    sortOrder,
    archivedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('emoji')) {
      context.handle(
        _emojiMeta,
        emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta),
      );
    } else if (isInserting) {
      context.missing(_emojiMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('price_minor_units')) {
      context.handle(
        _priceMinorUnitsMeta,
        priceMinorUnits.isAcceptableOrUnknown(
          data['price_minor_units']!,
          _priceMinorUnitsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_priceMinorUnitsMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      emoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emoji'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_id'],
      )!,
      priceMinorUnits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}price_minor_units'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ItemsTable createAlias(String alias) {
    return $ItemsTable(attachedDatabase, alias);
  }
}

class ItemRow extends DataClass implements Insertable<ItemRow> {
  final int id;
  final String name;

  /// Always set: the create screen picks a random one. Group emoji stay
  /// nullable, an item's does not.
  final String emoji;
  final int groupId;

  /// The *current* price. Transactions freeze their own copy, so changing this
  /// never rewrites what someone already paid.
  final int priceMinorUnits;
  final int sortOrder;

  /// Soft delete: a discontinued drink stays referenced by the ledger.
  final DateTime? archivedAt;
  final DateTime createdAt;
  const ItemRow({
    required this.id,
    required this.name,
    required this.emoji,
    required this.groupId,
    required this.priceMinorUnits,
    required this.sortOrder,
    this.archivedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['emoji'] = Variable<String>(emoji);
    map['group_id'] = Variable<int>(groupId);
    map['price_minor_units'] = Variable<int>(priceMinorUnits);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ItemsCompanion toCompanion(bool nullToAbsent) {
    return ItemsCompanion(
      id: Value(id),
      name: Value(name),
      emoji: Value(emoji),
      groupId: Value(groupId),
      priceMinorUnits: Value(priceMinorUnits),
      sortOrder: Value(sortOrder),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      createdAt: Value(createdAt),
    );
  }

  factory ItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      emoji: serializer.fromJson<String>(json['emoji']),
      groupId: serializer.fromJson<int>(json['groupId']),
      priceMinorUnits: serializer.fromJson<int>(json['priceMinorUnits']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'emoji': serializer.toJson<String>(emoji),
      'groupId': serializer.toJson<int>(groupId),
      'priceMinorUnits': serializer.toJson<int>(priceMinorUnits),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ItemRow copyWith({
    int? id,
    String? name,
    String? emoji,
    int? groupId,
    int? priceMinorUnits,
    int? sortOrder,
    Value<DateTime?> archivedAt = const Value.absent(),
    DateTime? createdAt,
  }) => ItemRow(
    id: id ?? this.id,
    name: name ?? this.name,
    emoji: emoji ?? this.emoji,
    groupId: groupId ?? this.groupId,
    priceMinorUnits: priceMinorUnits ?? this.priceMinorUnits,
    sortOrder: sortOrder ?? this.sortOrder,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  ItemRow copyWithCompanion(ItemsCompanion data) {
    return ItemRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      priceMinorUnits: data.priceMinorUnits.present
          ? data.priceMinorUnits.value
          : this.priceMinorUnits,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('emoji: $emoji, ')
          ..write('groupId: $groupId, ')
          ..write('priceMinorUnits: $priceMinorUnits, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    emoji,
    groupId,
    priceMinorUnits,
    sortOrder,
    archivedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.emoji == this.emoji &&
          other.groupId == this.groupId &&
          other.priceMinorUnits == this.priceMinorUnits &&
          other.sortOrder == this.sortOrder &&
          other.archivedAt == this.archivedAt &&
          other.createdAt == this.createdAt);
}

class ItemsCompanion extends UpdateCompanion<ItemRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> emoji;
  final Value<int> groupId;
  final Value<int> priceMinorUnits;
  final Value<int> sortOrder;
  final Value<DateTime?> archivedAt;
  final Value<DateTime> createdAt;
  const ItemsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.emoji = const Value.absent(),
    this.groupId = const Value.absent(),
    this.priceMinorUnits = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ItemsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String emoji,
    required int groupId,
    required int priceMinorUnits,
    this.sortOrder = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       emoji = Value(emoji),
       groupId = Value(groupId),
       priceMinorUnits = Value(priceMinorUnits);
  static Insertable<ItemRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? emoji,
    Expression<int>? groupId,
    Expression<int>? priceMinorUnits,
    Expression<int>? sortOrder,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (emoji != null) 'emoji': emoji,
      if (groupId != null) 'group_id': groupId,
      if (priceMinorUnits != null) 'price_minor_units': priceMinorUnits,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? emoji,
    Value<int>? groupId,
    Value<int>? priceMinorUnits,
    Value<int>? sortOrder,
    Value<DateTime?>? archivedAt,
    Value<DateTime>? createdAt,
  }) {
    return ItemsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      groupId: groupId ?? this.groupId,
      priceMinorUnits: priceMinorUnits ?? this.priceMinorUnits,
      sortOrder: sortOrder ?? this.sortOrder,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (priceMinorUnits.present) {
      map['price_minor_units'] = Variable<int>(priceMinorUnits.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('emoji: $emoji, ')
          ..write('groupId: $groupId, ')
          ..write('priceMinorUnits: $priceMinorUnits, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, TransactionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<TransactionType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TransactionType>($TransactionsTable.$convertertype);
  static const VerificationMeta _amountMinorUnitsMeta = const VerificationMeta(
    'amountMinorUnits',
  );
  @override
  late final GeneratedColumn<int> amountMinorUnits = GeneratedColumn<int>(
    'amount_minor_units',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<int> itemId = GeneratedColumn<int>(
    'item_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES items (id)',
    ),
  );
  static const VerificationMeta _itemNameSnapshotMeta = const VerificationMeta(
    'itemNameSnapshot',
  );
  @override
  late final GeneratedColumn<String> itemNameSnapshot = GeneratedColumn<String>(
    'item_name_snapshot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _itemUnitPriceSnapshotMeta =
      const VerificationMeta('itemUnitPriceSnapshot');
  @override
  late final GeneratedColumn<int> itemUnitPriceSnapshot = GeneratedColumn<int>(
    'item_unit_price_snapshot',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _voidedAtMeta = const VerificationMeta(
    'voidedAt',
  );
  @override
  late final GeneratedColumn<DateTime> voidedAt = GeneratedColumn<DateTime>(
    'voided_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voidedNoteMeta = const VerificationMeta(
    'voidedNote',
  );
  @override
  late final GeneratedColumn<String> voidedNote = GeneratedColumn<String>(
    'voided_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    type,
    amountMinorUnits,
    quantity,
    itemId,
    itemNameSnapshot,
    itemUnitPriceSnapshot,
    note,
    createdAt,
    voidedAt,
    voidedNote,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransactionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('amount_minor_units')) {
      context.handle(
        _amountMinorUnitsMeta,
        amountMinorUnits.isAcceptableOrUnknown(
          data['amount_minor_units']!,
          _amountMinorUnitsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorUnitsMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    }
    if (data.containsKey('item_name_snapshot')) {
      context.handle(
        _itemNameSnapshotMeta,
        itemNameSnapshot.isAcceptableOrUnknown(
          data['item_name_snapshot']!,
          _itemNameSnapshotMeta,
        ),
      );
    }
    if (data.containsKey('item_unit_price_snapshot')) {
      context.handle(
        _itemUnitPriceSnapshotMeta,
        itemUnitPriceSnapshot.isAcceptableOrUnknown(
          data['item_unit_price_snapshot']!,
          _itemUnitPriceSnapshotMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('voided_at')) {
      context.handle(
        _voidedAtMeta,
        voidedAt.isAcceptableOrUnknown(data['voided_at']!, _voidedAtMeta),
      );
    }
    if (data.containsKey('voided_note')) {
      context.handle(
        _voidedNoteMeta,
        voidedNote.isAcceptableOrUnknown(data['voided_note']!, _voidedNoteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransactionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      )!,
      type: $TransactionsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      amountMinorUnits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor_units'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_id'],
      ),
      itemNameSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_name_snapshot'],
      ),
      itemUnitPriceSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_unit_price_snapshot'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      voidedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}voided_at'],
      ),
      voidedNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voided_note'],
      ),
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TransactionType, String, String> $convertertype =
      const EnumNameConverter<TransactionType>(TransactionType.values);
}

class TransactionRow extends DataClass implements Insertable<TransactionRow> {
  final int id;
  final int userId;
  final TransactionType type;

  /// The signed **line total**, never a unit price: negative is spending,
  /// positive is credit the member holds. Makes the balance one type-agnostic
  /// SUM, so a fourth transaction type would need no balance changes.
  final int amountMinorUnits;

  /// Display only — [amountMinorUnits] already has this multiplied in.
  final int quantity;
  final int? itemId;
  final String? itemNameSnapshot;
  final int? itemUnitPriceSnapshot;

  /// Required by the UI for an adjustment, optional otherwise.
  final String? note;
  final DateTime createdAt;

  /// One-way: null -> timestamp, never cleared. The row itself is never
  /// rewritten, and voided rows still render in history, just struck through.
  final DateTime? voidedAt;
  final String? voidedNote;
  const TransactionRow({
    required this.id,
    required this.userId,
    required this.type,
    required this.amountMinorUnits,
    required this.quantity,
    this.itemId,
    this.itemNameSnapshot,
    this.itemUnitPriceSnapshot,
    this.note,
    required this.createdAt,
    this.voidedAt,
    this.voidedNote,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['user_id'] = Variable<int>(userId);
    {
      map['type'] = Variable<String>(
        $TransactionsTable.$convertertype.toSql(type),
      );
    }
    map['amount_minor_units'] = Variable<int>(amountMinorUnits);
    map['quantity'] = Variable<int>(quantity);
    if (!nullToAbsent || itemId != null) {
      map['item_id'] = Variable<int>(itemId);
    }
    if (!nullToAbsent || itemNameSnapshot != null) {
      map['item_name_snapshot'] = Variable<String>(itemNameSnapshot);
    }
    if (!nullToAbsent || itemUnitPriceSnapshot != null) {
      map['item_unit_price_snapshot'] = Variable<int>(itemUnitPriceSnapshot);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || voidedAt != null) {
      map['voided_at'] = Variable<DateTime>(voidedAt);
    }
    if (!nullToAbsent || voidedNote != null) {
      map['voided_note'] = Variable<String>(voidedNote);
    }
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      userId: Value(userId),
      type: Value(type),
      amountMinorUnits: Value(amountMinorUnits),
      quantity: Value(quantity),
      itemId: itemId == null && nullToAbsent
          ? const Value.absent()
          : Value(itemId),
      itemNameSnapshot: itemNameSnapshot == null && nullToAbsent
          ? const Value.absent()
          : Value(itemNameSnapshot),
      itemUnitPriceSnapshot: itemUnitPriceSnapshot == null && nullToAbsent
          ? const Value.absent()
          : Value(itemUnitPriceSnapshot),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      voidedAt: voidedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(voidedAt),
      voidedNote: voidedNote == null && nullToAbsent
          ? const Value.absent()
          : Value(voidedNote),
    );
  }

  factory TransactionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionRow(
      id: serializer.fromJson<int>(json['id']),
      userId: serializer.fromJson<int>(json['userId']),
      type: $TransactionsTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      amountMinorUnits: serializer.fromJson<int>(json['amountMinorUnits']),
      quantity: serializer.fromJson<int>(json['quantity']),
      itemId: serializer.fromJson<int?>(json['itemId']),
      itemNameSnapshot: serializer.fromJson<String?>(json['itemNameSnapshot']),
      itemUnitPriceSnapshot: serializer.fromJson<int?>(
        json['itemUnitPriceSnapshot'],
      ),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      voidedAt: serializer.fromJson<DateTime?>(json['voidedAt']),
      voidedNote: serializer.fromJson<String?>(json['voidedNote']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'userId': serializer.toJson<int>(userId),
      'type': serializer.toJson<String>(
        $TransactionsTable.$convertertype.toJson(type),
      ),
      'amountMinorUnits': serializer.toJson<int>(amountMinorUnits),
      'quantity': serializer.toJson<int>(quantity),
      'itemId': serializer.toJson<int?>(itemId),
      'itemNameSnapshot': serializer.toJson<String?>(itemNameSnapshot),
      'itemUnitPriceSnapshot': serializer.toJson<int?>(itemUnitPriceSnapshot),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'voidedAt': serializer.toJson<DateTime?>(voidedAt),
      'voidedNote': serializer.toJson<String?>(voidedNote),
    };
  }

  TransactionRow copyWith({
    int? id,
    int? userId,
    TransactionType? type,
    int? amountMinorUnits,
    int? quantity,
    Value<int?> itemId = const Value.absent(),
    Value<String?> itemNameSnapshot = const Value.absent(),
    Value<int?> itemUnitPriceSnapshot = const Value.absent(),
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> voidedAt = const Value.absent(),
    Value<String?> voidedNote = const Value.absent(),
  }) => TransactionRow(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    type: type ?? this.type,
    amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
    quantity: quantity ?? this.quantity,
    itemId: itemId.present ? itemId.value : this.itemId,
    itemNameSnapshot: itemNameSnapshot.present
        ? itemNameSnapshot.value
        : this.itemNameSnapshot,
    itemUnitPriceSnapshot: itemUnitPriceSnapshot.present
        ? itemUnitPriceSnapshot.value
        : this.itemUnitPriceSnapshot,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    voidedAt: voidedAt.present ? voidedAt.value : this.voidedAt,
    voidedNote: voidedNote.present ? voidedNote.value : this.voidedNote,
  );
  TransactionRow copyWithCompanion(TransactionsCompanion data) {
    return TransactionRow(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      type: data.type.present ? data.type.value : this.type,
      amountMinorUnits: data.amountMinorUnits.present
          ? data.amountMinorUnits.value
          : this.amountMinorUnits,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      itemNameSnapshot: data.itemNameSnapshot.present
          ? data.itemNameSnapshot.value
          : this.itemNameSnapshot,
      itemUnitPriceSnapshot: data.itemUnitPriceSnapshot.present
          ? data.itemUnitPriceSnapshot.value
          : this.itemUnitPriceSnapshot,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      voidedAt: data.voidedAt.present ? data.voidedAt.value : this.voidedAt,
      voidedNote: data.voidedNote.present
          ? data.voidedNote.value
          : this.voidedNote,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionRow(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('type: $type, ')
          ..write('amountMinorUnits: $amountMinorUnits, ')
          ..write('quantity: $quantity, ')
          ..write('itemId: $itemId, ')
          ..write('itemNameSnapshot: $itemNameSnapshot, ')
          ..write('itemUnitPriceSnapshot: $itemUnitPriceSnapshot, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('voidedAt: $voidedAt, ')
          ..write('voidedNote: $voidedNote')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    type,
    amountMinorUnits,
    quantity,
    itemId,
    itemNameSnapshot,
    itemUnitPriceSnapshot,
    note,
    createdAt,
    voidedAt,
    voidedNote,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionRow &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.type == this.type &&
          other.amountMinorUnits == this.amountMinorUnits &&
          other.quantity == this.quantity &&
          other.itemId == this.itemId &&
          other.itemNameSnapshot == this.itemNameSnapshot &&
          other.itemUnitPriceSnapshot == this.itemUnitPriceSnapshot &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.voidedAt == this.voidedAt &&
          other.voidedNote == this.voidedNote);
}

class TransactionsCompanion extends UpdateCompanion<TransactionRow> {
  final Value<int> id;
  final Value<int> userId;
  final Value<TransactionType> type;
  final Value<int> amountMinorUnits;
  final Value<int> quantity;
  final Value<int?> itemId;
  final Value<String?> itemNameSnapshot;
  final Value<int?> itemUnitPriceSnapshot;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<DateTime?> voidedAt;
  final Value<String?> voidedNote;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.type = const Value.absent(),
    this.amountMinorUnits = const Value.absent(),
    this.quantity = const Value.absent(),
    this.itemId = const Value.absent(),
    this.itemNameSnapshot = const Value.absent(),
    this.itemUnitPriceSnapshot = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.voidedAt = const Value.absent(),
    this.voidedNote = const Value.absent(),
  });
  TransactionsCompanion.insert({
    this.id = const Value.absent(),
    required int userId,
    required TransactionType type,
    required int amountMinorUnits,
    this.quantity = const Value.absent(),
    this.itemId = const Value.absent(),
    this.itemNameSnapshot = const Value.absent(),
    this.itemUnitPriceSnapshot = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.voidedAt = const Value.absent(),
    this.voidedNote = const Value.absent(),
  }) : userId = Value(userId),
       type = Value(type),
       amountMinorUnits = Value(amountMinorUnits);
  static Insertable<TransactionRow> custom({
    Expression<int>? id,
    Expression<int>? userId,
    Expression<String>? type,
    Expression<int>? amountMinorUnits,
    Expression<int>? quantity,
    Expression<int>? itemId,
    Expression<String>? itemNameSnapshot,
    Expression<int>? itemUnitPriceSnapshot,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? voidedAt,
    Expression<String>? voidedNote,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (type != null) 'type': type,
      if (amountMinorUnits != null) 'amount_minor_units': amountMinorUnits,
      if (quantity != null) 'quantity': quantity,
      if (itemId != null) 'item_id': itemId,
      if (itemNameSnapshot != null) 'item_name_snapshot': itemNameSnapshot,
      if (itemUnitPriceSnapshot != null)
        'item_unit_price_snapshot': itemUnitPriceSnapshot,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (voidedAt != null) 'voided_at': voidedAt,
      if (voidedNote != null) 'voided_note': voidedNote,
    });
  }

  TransactionsCompanion copyWith({
    Value<int>? id,
    Value<int>? userId,
    Value<TransactionType>? type,
    Value<int>? amountMinorUnits,
    Value<int>? quantity,
    Value<int?>? itemId,
    Value<String?>? itemNameSnapshot,
    Value<int?>? itemUnitPriceSnapshot,
    Value<String?>? note,
    Value<DateTime>? createdAt,
    Value<DateTime?>? voidedAt,
    Value<String?>? voidedNote,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
      quantity: quantity ?? this.quantity,
      itemId: itemId ?? this.itemId,
      itemNameSnapshot: itemNameSnapshot ?? this.itemNameSnapshot,
      itemUnitPriceSnapshot:
          itemUnitPriceSnapshot ?? this.itemUnitPriceSnapshot,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      voidedAt: voidedAt ?? this.voidedAt,
      voidedNote: voidedNote ?? this.voidedNote,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $TransactionsTable.$convertertype.toSql(type.value),
      );
    }
    if (amountMinorUnits.present) {
      map['amount_minor_units'] = Variable<int>(amountMinorUnits.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<int>(itemId.value);
    }
    if (itemNameSnapshot.present) {
      map['item_name_snapshot'] = Variable<String>(itemNameSnapshot.value);
    }
    if (itemUnitPriceSnapshot.present) {
      map['item_unit_price_snapshot'] = Variable<int>(
        itemUnitPriceSnapshot.value,
      );
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (voidedAt.present) {
      map['voided_at'] = Variable<DateTime>(voidedAt.value);
    }
    if (voidedNote.present) {
      map['voided_note'] = Variable<String>(voidedNote.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('type: $type, ')
          ..write('amountMinorUnits: $amountMinorUnits, ')
          ..write('quantity: $quantity, ')
          ..write('itemId: $itemId, ')
          ..write('itemNameSnapshot: $itemNameSnapshot, ')
          ..write('itemUnitPriceSnapshot: $itemUnitPriceSnapshot, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('voidedAt: $voidedAt, ')
          ..write('voidedNote: $voidedNote')
          ..write(')'))
        .toString();
  }
}

class UserBalanceRow extends DataClass {
  final int userId;
  final int? balanceMinorUnits;
  const UserBalanceRow({required this.userId, this.balanceMinorUnits});
  factory UserBalanceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserBalanceRow(
      userId: serializer.fromJson<int>(json['userId']),
      balanceMinorUnits: serializer.fromJson<int?>(json['balanceMinorUnits']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<int>(userId),
      'balanceMinorUnits': serializer.toJson<int?>(balanceMinorUnits),
    };
  }

  UserBalanceRow copyWith({
    int? userId,
    Value<int?> balanceMinorUnits = const Value.absent(),
  }) => UserBalanceRow(
    userId: userId ?? this.userId,
    balanceMinorUnits: balanceMinorUnits.present
        ? balanceMinorUnits.value
        : this.balanceMinorUnits,
  );
  @override
  String toString() {
    return (StringBuffer('UserBalanceRow(')
          ..write('userId: $userId, ')
          ..write('balanceMinorUnits: $balanceMinorUnits')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, balanceMinorUnits);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserBalanceRow &&
          other.userId == this.userId &&
          other.balanceMinorUnits == this.balanceMinorUnits);
}

class $UserBalancesView extends ViewInfo<$UserBalancesView, UserBalanceRow>
    implements HasResultSet {
  final String? _alias;
  @override
  final _$AppDatabase attachedDatabase;
  $UserBalancesView(this.attachedDatabase, [this._alias]);
  $TransactionsTable get transactions =>
      attachedDatabase.transactions.createAlias('t0');
  @override
  List<GeneratedColumn> get $columns => [userId, balanceMinorUnits];
  @override
  String get aliasedName => _alias ?? entityName;
  @override
  String get entityName => 'user_balances';
  @override
  Map<SqlDialect, String>? get createViewStatements => null;
  @override
  $UserBalancesView get asDslTable => this;
  @override
  UserBalanceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserBalanceRow(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      )!,
      balanceMinorUnits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}balance_minor_units'],
      ),
    );
  }

  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    generatedAs: GeneratedAs(transactions.userId, false),
    type: DriftSqlType.int,
  );
  late final GeneratedColumn<int> balanceMinorUnits = GeneratedColumn<int>(
    'balance_minor_units',
    aliasedName,
    true,
    generatedAs: GeneratedAs(
      ArithmeticAggregates(transactions.amountMinorUnits).sum(),
      false,
    ),
    type: DriftSqlType.int,
  );
  @override
  $UserBalancesView createAlias(String alias) {
    return $UserBalancesView(attachedDatabase, alias);
  }

  @override
  Query? get query =>
      (attachedDatabase.selectOnly(transactions)..addColumns($columns))
        ..where(transactions.voidedAt.isNull())
        ..groupBy([transactions.userId]);
  @override
  Set<String> get readTables => const {
    'transactions',
    'users',
    'items',
    'item_groups',
    'user_groups',
  };
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $UserGroupsTable userGroups = $UserGroupsTable(this);
  late final $UsersTable users = $UsersTable(this);
  late final $ItemGroupsTable itemGroups = $ItemGroupsTable(this);
  late final $ItemsTable items = $ItemsTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $UserBalancesView userBalances = $UserBalancesView(this);
  late final Index usersGroupId = Index(
    'users_group_id',
    'CREATE INDEX users_group_id ON users (group_id)',
  );
  late final Index itemsGroupId = Index(
    'items_group_id',
    'CREATE INDEX items_group_id ON items (group_id)',
  );
  late final Index transactionsUserIdVoidedAt = Index(
    'transactions_user_id_voided_at',
    'CREATE INDEX transactions_user_id_voided_at ON transactions (user_id, voided_at)',
  );
  late final Index transactionsCreatedAt = Index(
    'transactions_created_at',
    'CREATE INDEX transactions_created_at ON transactions (created_at)',
  );
  late final SettingsDao settingsDao = SettingsDao(this as AppDatabase);
  late final UsersDao usersDao = UsersDao(this as AppDatabase);
  late final ItemsDao itemsDao = ItemsDao(this as AppDatabase);
  late final TransactionsDao transactionsDao = TransactionsDao(
    this as AppDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    settings,
    userGroups,
    users,
    itemGroups,
    items,
    transactions,
    userBalances,
    usersGroupId,
    itemsGroupId,
    transactionsUserIdVoidedAt,
    transactionsCreatedAt,
  ];
}
