// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(Insertable<Setting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory Setting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) => Setting(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UsersTable extends Users with TableInfo<$UsersTable, User> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _fullNameMeta =
      const VerificationMeta('fullName');
  @override
  late final GeneratedColumn<String> fullName = GeneratedColumn<String>(
      'full_name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 120),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _loginMeta = const VerificationMeta('login');
  @override
  late final GeneratedColumn<String> login = GeneratedColumn<String>(
      'login', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 2, maxTextLength: 40),
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _passwordHashMeta =
      const VerificationMeta('passwordHash');
  @override
  late final GeneratedColumn<String> passwordHash = GeneratedColumn<String>(
      'password_hash', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<DbUserRole, int> role =
      GeneratedColumn<int>('role', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<DbUserRole>($UsersTable.$converterrole);
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
      'active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _lastLoginMeta =
      const VerificationMeta('lastLogin');
  @override
  late final GeneratedColumn<DateTime> lastLogin = GeneratedColumn<DateTime>(
      'last_login', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, fullName, login, passwordHash, role, active, createdAt, lastLogin];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(Insertable<User> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('full_name')) {
      context.handle(_fullNameMeta,
          fullName.isAcceptableOrUnknown(data['full_name']!, _fullNameMeta));
    } else if (isInserting) {
      context.missing(_fullNameMeta);
    }
    if (data.containsKey('login')) {
      context.handle(
          _loginMeta, login.isAcceptableOrUnknown(data['login']!, _loginMeta));
    } else if (isInserting) {
      context.missing(_loginMeta);
    }
    if (data.containsKey('password_hash')) {
      context.handle(
          _passwordHashMeta,
          passwordHash.isAcceptableOrUnknown(
              data['password_hash']!, _passwordHashMeta));
    } else if (isInserting) {
      context.missing(_passwordHashMeta);
    }
    if (data.containsKey('active')) {
      context.handle(_activeMeta,
          active.isAcceptableOrUnknown(data['active']!, _activeMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('last_login')) {
      context.handle(_lastLoginMeta,
          lastLogin.isAcceptableOrUnknown(data['last_login']!, _lastLoginMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      fullName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}full_name'])!,
      login: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}login'])!,
      passwordHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}password_hash'])!,
      role: $UsersTable.$converterrole.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}role'])!),
      active: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}active'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      lastLogin: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_login']),
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DbUserRole, int, int> $converterrole =
      const EnumIndexConverter<DbUserRole>(DbUserRole.values);
}

class User extends DataClass implements Insertable<User> {
  final int id;
  final String fullName;
  final String login;
  final String passwordHash;
  final DbUserRole role;
  final bool active;
  final DateTime createdAt;
  final DateTime? lastLogin;
  const User(
      {required this.id,
      required this.fullName,
      required this.login,
      required this.passwordHash,
      required this.role,
      required this.active,
      required this.createdAt,
      this.lastLogin});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['full_name'] = Variable<String>(fullName);
    map['login'] = Variable<String>(login);
    map['password_hash'] = Variable<String>(passwordHash);
    {
      map['role'] = Variable<int>($UsersTable.$converterrole.toSql(role));
    }
    map['active'] = Variable<bool>(active);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastLogin != null) {
      map['last_login'] = Variable<DateTime>(lastLogin);
    }
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      fullName: Value(fullName),
      login: Value(login),
      passwordHash: Value(passwordHash),
      role: Value(role),
      active: Value(active),
      createdAt: Value(createdAt),
      lastLogin: lastLogin == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLogin),
    );
  }

  factory User.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      id: serializer.fromJson<int>(json['id']),
      fullName: serializer.fromJson<String>(json['fullName']),
      login: serializer.fromJson<String>(json['login']),
      passwordHash: serializer.fromJson<String>(json['passwordHash']),
      role: $UsersTable.$converterrole
          .fromJson(serializer.fromJson<int>(json['role'])),
      active: serializer.fromJson<bool>(json['active']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastLogin: serializer.fromJson<DateTime?>(json['lastLogin']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fullName': serializer.toJson<String>(fullName),
      'login': serializer.toJson<String>(login),
      'passwordHash': serializer.toJson<String>(passwordHash),
      'role': serializer.toJson<int>($UsersTable.$converterrole.toJson(role)),
      'active': serializer.toJson<bool>(active),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastLogin': serializer.toJson<DateTime?>(lastLogin),
    };
  }

  User copyWith(
          {int? id,
          String? fullName,
          String? login,
          String? passwordHash,
          DbUserRole? role,
          bool? active,
          DateTime? createdAt,
          Value<DateTime?> lastLogin = const Value.absent()}) =>
      User(
        id: id ?? this.id,
        fullName: fullName ?? this.fullName,
        login: login ?? this.login,
        passwordHash: passwordHash ?? this.passwordHash,
        role: role ?? this.role,
        active: active ?? this.active,
        createdAt: createdAt ?? this.createdAt,
        lastLogin: lastLogin.present ? lastLogin.value : this.lastLogin,
      );
  User copyWithCompanion(UsersCompanion data) {
    return User(
      id: data.id.present ? data.id.value : this.id,
      fullName: data.fullName.present ? data.fullName.value : this.fullName,
      login: data.login.present ? data.login.value : this.login,
      passwordHash: data.passwordHash.present
          ? data.passwordHash.value
          : this.passwordHash,
      role: data.role.present ? data.role.value : this.role,
      active: data.active.present ? data.active.value : this.active,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastLogin: data.lastLogin.present ? data.lastLogin.value : this.lastLogin,
    );
  }

  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('id: $id, ')
          ..write('fullName: $fullName, ')
          ..write('login: $login, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('role: $role, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastLogin: $lastLogin')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, fullName, login, passwordHash, role, active, createdAt, lastLogin);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == this.id &&
          other.fullName == this.fullName &&
          other.login == this.login &&
          other.passwordHash == this.passwordHash &&
          other.role == this.role &&
          other.active == this.active &&
          other.createdAt == this.createdAt &&
          other.lastLogin == this.lastLogin);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<int> id;
  final Value<String> fullName;
  final Value<String> login;
  final Value<String> passwordHash;
  final Value<DbUserRole> role;
  final Value<bool> active;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastLogin;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.fullName = const Value.absent(),
    this.login = const Value.absent(),
    this.passwordHash = const Value.absent(),
    this.role = const Value.absent(),
    this.active = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastLogin = const Value.absent(),
  });
  UsersCompanion.insert({
    this.id = const Value.absent(),
    required String fullName,
    required String login,
    required String passwordHash,
    required DbUserRole role,
    this.active = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastLogin = const Value.absent(),
  })  : fullName = Value(fullName),
        login = Value(login),
        passwordHash = Value(passwordHash),
        role = Value(role);
  static Insertable<User> custom({
    Expression<int>? id,
    Expression<String>? fullName,
    Expression<String>? login,
    Expression<String>? passwordHash,
    Expression<int>? role,
    Expression<bool>? active,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastLogin,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fullName != null) 'full_name': fullName,
      if (login != null) 'login': login,
      if (passwordHash != null) 'password_hash': passwordHash,
      if (role != null) 'role': role,
      if (active != null) 'active': active,
      if (createdAt != null) 'created_at': createdAt,
      if (lastLogin != null) 'last_login': lastLogin,
    });
  }

  UsersCompanion copyWith(
      {Value<int>? id,
      Value<String>? fullName,
      Value<String>? login,
      Value<String>? passwordHash,
      Value<DbUserRole>? role,
      Value<bool>? active,
      Value<DateTime>? createdAt,
      Value<DateTime?>? lastLogin}) {
    return UsersCompanion(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      login: login ?? this.login,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fullName.present) {
      map['full_name'] = Variable<String>(fullName.value);
    }
    if (login.present) {
      map['login'] = Variable<String>(login.value);
    }
    if (passwordHash.present) {
      map['password_hash'] = Variable<String>(passwordHash.value);
    }
    if (role.present) {
      map['role'] = Variable<int>($UsersTable.$converterrole.toSql(role.value));
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastLogin.present) {
      map['last_login'] = Variable<DateTime>(lastLogin.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('fullName: $fullName, ')
          ..write('login: $login, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('role: $role, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastLogin: $lastLogin')
          ..write(')'))
        .toString();
  }
}

class $ArticlesTable extends Articles with TableInfo<$ArticlesTable, Article> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArticlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 120),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _priceCentsMeta =
      const VerificationMeta('priceCents');
  @override
  late final GeneratedColumn<int> priceCents = GeneratedColumn<int>(
      'price_cents', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<DbCategory, int> category =
      GeneratedColumn<int>('category', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<DbCategory>($ArticlesTable.$convertercategory);
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
      'active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _imagePathMeta =
      const VerificationMeta('imagePath');
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
      'image_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _trackStockMeta =
      const VerificationMeta('trackStock');
  @override
  late final GeneratedColumn<bool> trackStock = GeneratedColumn<bool>(
      'track_stock', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("track_stock" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('unité'));
  static const VerificationMeta _stockQtyMeta =
      const VerificationMeta('stockQty');
  @override
  late final GeneratedColumn<int> stockQty = GeneratedColumn<int>(
      'stock_qty', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _thresholdMeta =
      const VerificationMeta('threshold');
  @override
  late final GeneratedColumn<int> threshold = GeneratedColumn<int>(
      'threshold', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        priceCents,
        category,
        active,
        imagePath,
        trackStock,
        unit,
        stockQty,
        threshold
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'articles';
  @override
  VerificationContext validateIntegrity(Insertable<Article> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('price_cents')) {
      context.handle(
          _priceCentsMeta,
          priceCents.isAcceptableOrUnknown(
              data['price_cents']!, _priceCentsMeta));
    } else if (isInserting) {
      context.missing(_priceCentsMeta);
    }
    if (data.containsKey('active')) {
      context.handle(_activeMeta,
          active.isAcceptableOrUnknown(data['active']!, _activeMeta));
    }
    if (data.containsKey('image_path')) {
      context.handle(_imagePathMeta,
          imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta));
    }
    if (data.containsKey('track_stock')) {
      context.handle(
          _trackStockMeta,
          trackStock.isAcceptableOrUnknown(
              data['track_stock']!, _trackStockMeta));
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    }
    if (data.containsKey('stock_qty')) {
      context.handle(_stockQtyMeta,
          stockQty.isAcceptableOrUnknown(data['stock_qty']!, _stockQtyMeta));
    }
    if (data.containsKey('threshold')) {
      context.handle(_thresholdMeta,
          threshold.isAcceptableOrUnknown(data['threshold']!, _thresholdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Article map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Article(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      priceCents: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}price_cents'])!,
      category: $ArticlesTable.$convertercategory.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}category'])!),
      active: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}active'])!,
      imagePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_path']),
      trackStock: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}track_stock'])!,
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit'])!,
      stockQty: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}stock_qty'])!,
      threshold: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}threshold'])!,
    );
  }

  @override
  $ArticlesTable createAlias(String alias) {
    return $ArticlesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DbCategory, int, int> $convertercategory =
      const EnumIndexConverter<DbCategory>(DbCategory.values);
}

class Article extends DataClass implements Insertable<Article> {
  final int id;
  final String name;
  final int priceCents;
  final DbCategory category;
  final bool active;
  final String? imagePath;
  final bool trackStock;
  final String unit;
  final int stockQty;
  final int threshold;
  const Article(
      {required this.id,
      required this.name,
      required this.priceCents,
      required this.category,
      required this.active,
      this.imagePath,
      required this.trackStock,
      required this.unit,
      required this.stockQty,
      required this.threshold});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['price_cents'] = Variable<int>(priceCents);
    {
      map['category'] =
          Variable<int>($ArticlesTable.$convertercategory.toSql(category));
    }
    map['active'] = Variable<bool>(active);
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    map['track_stock'] = Variable<bool>(trackStock);
    map['unit'] = Variable<String>(unit);
    map['stock_qty'] = Variable<int>(stockQty);
    map['threshold'] = Variable<int>(threshold);
    return map;
  }

  ArticlesCompanion toCompanion(bool nullToAbsent) {
    return ArticlesCompanion(
      id: Value(id),
      name: Value(name),
      priceCents: Value(priceCents),
      category: Value(category),
      active: Value(active),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
      trackStock: Value(trackStock),
      unit: Value(unit),
      stockQty: Value(stockQty),
      threshold: Value(threshold),
    );
  }

  factory Article.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Article(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      priceCents: serializer.fromJson<int>(json['priceCents']),
      category: $ArticlesTable.$convertercategory
          .fromJson(serializer.fromJson<int>(json['category'])),
      active: serializer.fromJson<bool>(json['active']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      trackStock: serializer.fromJson<bool>(json['trackStock']),
      unit: serializer.fromJson<String>(json['unit']),
      stockQty: serializer.fromJson<int>(json['stockQty']),
      threshold: serializer.fromJson<int>(json['threshold']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'priceCents': serializer.toJson<int>(priceCents),
      'category': serializer
          .toJson<int>($ArticlesTable.$convertercategory.toJson(category)),
      'active': serializer.toJson<bool>(active),
      'imagePath': serializer.toJson<String?>(imagePath),
      'trackStock': serializer.toJson<bool>(trackStock),
      'unit': serializer.toJson<String>(unit),
      'stockQty': serializer.toJson<int>(stockQty),
      'threshold': serializer.toJson<int>(threshold),
    };
  }

  Article copyWith(
          {int? id,
          String? name,
          int? priceCents,
          DbCategory? category,
          bool? active,
          Value<String?> imagePath = const Value.absent(),
          bool? trackStock,
          String? unit,
          int? stockQty,
          int? threshold}) =>
      Article(
        id: id ?? this.id,
        name: name ?? this.name,
        priceCents: priceCents ?? this.priceCents,
        category: category ?? this.category,
        active: active ?? this.active,
        imagePath: imagePath.present ? imagePath.value : this.imagePath,
        trackStock: trackStock ?? this.trackStock,
        unit: unit ?? this.unit,
        stockQty: stockQty ?? this.stockQty,
        threshold: threshold ?? this.threshold,
      );
  Article copyWithCompanion(ArticlesCompanion data) {
    return Article(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      priceCents:
          data.priceCents.present ? data.priceCents.value : this.priceCents,
      category: data.category.present ? data.category.value : this.category,
      active: data.active.present ? data.active.value : this.active,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      trackStock:
          data.trackStock.present ? data.trackStock.value : this.trackStock,
      unit: data.unit.present ? data.unit.value : this.unit,
      stockQty: data.stockQty.present ? data.stockQty.value : this.stockQty,
      threshold: data.threshold.present ? data.threshold.value : this.threshold,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Article(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('priceCents: $priceCents, ')
          ..write('category: $category, ')
          ..write('active: $active, ')
          ..write('imagePath: $imagePath, ')
          ..write('trackStock: $trackStock, ')
          ..write('unit: $unit, ')
          ..write('stockQty: $stockQty, ')
          ..write('threshold: $threshold')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, priceCents, category, active,
      imagePath, trackStock, unit, stockQty, threshold);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Article &&
          other.id == this.id &&
          other.name == this.name &&
          other.priceCents == this.priceCents &&
          other.category == this.category &&
          other.active == this.active &&
          other.imagePath == this.imagePath &&
          other.trackStock == this.trackStock &&
          other.unit == this.unit &&
          other.stockQty == this.stockQty &&
          other.threshold == this.threshold);
}

class ArticlesCompanion extends UpdateCompanion<Article> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> priceCents;
  final Value<DbCategory> category;
  final Value<bool> active;
  final Value<String?> imagePath;
  final Value<bool> trackStock;
  final Value<String> unit;
  final Value<int> stockQty;
  final Value<int> threshold;
  const ArticlesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.priceCents = const Value.absent(),
    this.category = const Value.absent(),
    this.active = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.trackStock = const Value.absent(),
    this.unit = const Value.absent(),
    this.stockQty = const Value.absent(),
    this.threshold = const Value.absent(),
  });
  ArticlesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int priceCents,
    required DbCategory category,
    this.active = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.trackStock = const Value.absent(),
    this.unit = const Value.absent(),
    this.stockQty = const Value.absent(),
    this.threshold = const Value.absent(),
  })  : name = Value(name),
        priceCents = Value(priceCents),
        category = Value(category);
  static Insertable<Article> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? priceCents,
    Expression<int>? category,
    Expression<bool>? active,
    Expression<String>? imagePath,
    Expression<bool>? trackStock,
    Expression<String>? unit,
    Expression<int>? stockQty,
    Expression<int>? threshold,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (priceCents != null) 'price_cents': priceCents,
      if (category != null) 'category': category,
      if (active != null) 'active': active,
      if (imagePath != null) 'image_path': imagePath,
      if (trackStock != null) 'track_stock': trackStock,
      if (unit != null) 'unit': unit,
      if (stockQty != null) 'stock_qty': stockQty,
      if (threshold != null) 'threshold': threshold,
    });
  }

  ArticlesCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<int>? priceCents,
      Value<DbCategory>? category,
      Value<bool>? active,
      Value<String?>? imagePath,
      Value<bool>? trackStock,
      Value<String>? unit,
      Value<int>? stockQty,
      Value<int>? threshold}) {
    return ArticlesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      priceCents: priceCents ?? this.priceCents,
      category: category ?? this.category,
      active: active ?? this.active,
      imagePath: imagePath ?? this.imagePath,
      trackStock: trackStock ?? this.trackStock,
      unit: unit ?? this.unit,
      stockQty: stockQty ?? this.stockQty,
      threshold: threshold ?? this.threshold,
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
    if (priceCents.present) {
      map['price_cents'] = Variable<int>(priceCents.value);
    }
    if (category.present) {
      map['category'] = Variable<int>(
          $ArticlesTable.$convertercategory.toSql(category.value));
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (trackStock.present) {
      map['track_stock'] = Variable<bool>(trackStock.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (stockQty.present) {
      map['stock_qty'] = Variable<int>(stockQty.value);
    }
    if (threshold.present) {
      map['threshold'] = Variable<int>(threshold.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArticlesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('priceCents: $priceCents, ')
          ..write('category: $category, ')
          ..write('active: $active, ')
          ..write('imagePath: $imagePath, ')
          ..write('trackStock: $trackStock, ')
          ..write('unit: $unit, ')
          ..write('stockQty: $stockQty, ')
          ..write('threshold: $threshold')
          ..write(')'))
        .toString();
  }
}

class $RoomsTable extends Rooms with TableInfo<$RoomsTable, Room> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoomsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<String> number = GeneratedColumn<String>(
      'number', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 10),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 40),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _pricePerNightCentsMeta =
      const VerificationMeta('pricePerNightCents');
  @override
  late final GeneratedColumn<int> pricePerNightCents = GeneratedColumn<int>(
      'price_per_night_cents', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<DbRoomStatus, int> status =
      GeneratedColumn<int>('status', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<DbRoomStatus>($RoomsTable.$converterstatus);
  static const VerificationMeta _currentGuestMeta =
      const VerificationMeta('currentGuest');
  @override
  late final GeneratedColumn<String> currentGuest = GeneratedColumn<String>(
      'current_guest', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _checkoutDateMeta =
      const VerificationMeta('checkoutDate');
  @override
  late final GeneratedColumn<DateTime> checkoutDate = GeneratedColumn<DateTime>(
      'checkout_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [number, type, pricePerNightCents, status, currentGuest, checkoutDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rooms';
  @override
  VerificationContext validateIntegrity(Insertable<Room> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('number')) {
      context.handle(_numberMeta,
          number.isAcceptableOrUnknown(data['number']!, _numberMeta));
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('price_per_night_cents')) {
      context.handle(
          _pricePerNightCentsMeta,
          pricePerNightCents.isAcceptableOrUnknown(
              data['price_per_night_cents']!, _pricePerNightCentsMeta));
    } else if (isInserting) {
      context.missing(_pricePerNightCentsMeta);
    }
    if (data.containsKey('current_guest')) {
      context.handle(
          _currentGuestMeta,
          currentGuest.isAcceptableOrUnknown(
              data['current_guest']!, _currentGuestMeta));
    }
    if (data.containsKey('checkout_date')) {
      context.handle(
          _checkoutDateMeta,
          checkoutDate.isAcceptableOrUnknown(
              data['checkout_date']!, _checkoutDateMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {number};
  @override
  Room map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Room(
      number: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}number'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      pricePerNightCents: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}price_per_night_cents'])!,
      status: $RoomsTable.$converterstatus.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!),
      currentGuest: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}current_guest']),
      checkoutDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}checkout_date']),
    );
  }

  @override
  $RoomsTable createAlias(String alias) {
    return $RoomsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DbRoomStatus, int, int> $converterstatus =
      const EnumIndexConverter<DbRoomStatus>(DbRoomStatus.values);
}

class Room extends DataClass implements Insertable<Room> {
  final String number;
  final String type;
  final int pricePerNightCents;
  final DbRoomStatus status;
  final String? currentGuest;
  final DateTime? checkoutDate;
  const Room(
      {required this.number,
      required this.type,
      required this.pricePerNightCents,
      required this.status,
      this.currentGuest,
      this.checkoutDate});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['number'] = Variable<String>(number);
    map['type'] = Variable<String>(type);
    map['price_per_night_cents'] = Variable<int>(pricePerNightCents);
    {
      map['status'] = Variable<int>($RoomsTable.$converterstatus.toSql(status));
    }
    if (!nullToAbsent || currentGuest != null) {
      map['current_guest'] = Variable<String>(currentGuest);
    }
    if (!nullToAbsent || checkoutDate != null) {
      map['checkout_date'] = Variable<DateTime>(checkoutDate);
    }
    return map;
  }

  RoomsCompanion toCompanion(bool nullToAbsent) {
    return RoomsCompanion(
      number: Value(number),
      type: Value(type),
      pricePerNightCents: Value(pricePerNightCents),
      status: Value(status),
      currentGuest: currentGuest == null && nullToAbsent
          ? const Value.absent()
          : Value(currentGuest),
      checkoutDate: checkoutDate == null && nullToAbsent
          ? const Value.absent()
          : Value(checkoutDate),
    );
  }

  factory Room.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Room(
      number: serializer.fromJson<String>(json['number']),
      type: serializer.fromJson<String>(json['type']),
      pricePerNightCents: serializer.fromJson<int>(json['pricePerNightCents']),
      status: $RoomsTable.$converterstatus
          .fromJson(serializer.fromJson<int>(json['status'])),
      currentGuest: serializer.fromJson<String?>(json['currentGuest']),
      checkoutDate: serializer.fromJson<DateTime?>(json['checkoutDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'number': serializer.toJson<String>(number),
      'type': serializer.toJson<String>(type),
      'pricePerNightCents': serializer.toJson<int>(pricePerNightCents),
      'status':
          serializer.toJson<int>($RoomsTable.$converterstatus.toJson(status)),
      'currentGuest': serializer.toJson<String?>(currentGuest),
      'checkoutDate': serializer.toJson<DateTime?>(checkoutDate),
    };
  }

  Room copyWith(
          {String? number,
          String? type,
          int? pricePerNightCents,
          DbRoomStatus? status,
          Value<String?> currentGuest = const Value.absent(),
          Value<DateTime?> checkoutDate = const Value.absent()}) =>
      Room(
        number: number ?? this.number,
        type: type ?? this.type,
        pricePerNightCents: pricePerNightCents ?? this.pricePerNightCents,
        status: status ?? this.status,
        currentGuest:
            currentGuest.present ? currentGuest.value : this.currentGuest,
        checkoutDate:
            checkoutDate.present ? checkoutDate.value : this.checkoutDate,
      );
  Room copyWithCompanion(RoomsCompanion data) {
    return Room(
      number: data.number.present ? data.number.value : this.number,
      type: data.type.present ? data.type.value : this.type,
      pricePerNightCents: data.pricePerNightCents.present
          ? data.pricePerNightCents.value
          : this.pricePerNightCents,
      status: data.status.present ? data.status.value : this.status,
      currentGuest: data.currentGuest.present
          ? data.currentGuest.value
          : this.currentGuest,
      checkoutDate: data.checkoutDate.present
          ? data.checkoutDate.value
          : this.checkoutDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Room(')
          ..write('number: $number, ')
          ..write('type: $type, ')
          ..write('pricePerNightCents: $pricePerNightCents, ')
          ..write('status: $status, ')
          ..write('currentGuest: $currentGuest, ')
          ..write('checkoutDate: $checkoutDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      number, type, pricePerNightCents, status, currentGuest, checkoutDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Room &&
          other.number == this.number &&
          other.type == this.type &&
          other.pricePerNightCents == this.pricePerNightCents &&
          other.status == this.status &&
          other.currentGuest == this.currentGuest &&
          other.checkoutDate == this.checkoutDate);
}

class RoomsCompanion extends UpdateCompanion<Room> {
  final Value<String> number;
  final Value<String> type;
  final Value<int> pricePerNightCents;
  final Value<DbRoomStatus> status;
  final Value<String?> currentGuest;
  final Value<DateTime?> checkoutDate;
  final Value<int> rowid;
  const RoomsCompanion({
    this.number = const Value.absent(),
    this.type = const Value.absent(),
    this.pricePerNightCents = const Value.absent(),
    this.status = const Value.absent(),
    this.currentGuest = const Value.absent(),
    this.checkoutDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoomsCompanion.insert({
    required String number,
    required String type,
    required int pricePerNightCents,
    required DbRoomStatus status,
    this.currentGuest = const Value.absent(),
    this.checkoutDate = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : number = Value(number),
        type = Value(type),
        pricePerNightCents = Value(pricePerNightCents),
        status = Value(status);
  static Insertable<Room> custom({
    Expression<String>? number,
    Expression<String>? type,
    Expression<int>? pricePerNightCents,
    Expression<int>? status,
    Expression<String>? currentGuest,
    Expression<DateTime>? checkoutDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (number != null) 'number': number,
      if (type != null) 'type': type,
      if (pricePerNightCents != null)
        'price_per_night_cents': pricePerNightCents,
      if (status != null) 'status': status,
      if (currentGuest != null) 'current_guest': currentGuest,
      if (checkoutDate != null) 'checkout_date': checkoutDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoomsCompanion copyWith(
      {Value<String>? number,
      Value<String>? type,
      Value<int>? pricePerNightCents,
      Value<DbRoomStatus>? status,
      Value<String?>? currentGuest,
      Value<DateTime?>? checkoutDate,
      Value<int>? rowid}) {
    return RoomsCompanion(
      number: number ?? this.number,
      type: type ?? this.type,
      pricePerNightCents: pricePerNightCents ?? this.pricePerNightCents,
      status: status ?? this.status,
      currentGuest: currentGuest ?? this.currentGuest,
      checkoutDate: checkoutDate ?? this.checkoutDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (number.present) {
      map['number'] = Variable<String>(number.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (pricePerNightCents.present) {
      map['price_per_night_cents'] = Variable<int>(pricePerNightCents.value);
    }
    if (status.present) {
      map['status'] =
          Variable<int>($RoomsTable.$converterstatus.toSql(status.value));
    }
    if (currentGuest.present) {
      map['current_guest'] = Variable<String>(currentGuest.value);
    }
    if (checkoutDate.present) {
      map['checkout_date'] = Variable<DateTime>(checkoutDate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoomsCompanion(')
          ..write('number: $number, ')
          ..write('type: $type, ')
          ..write('pricePerNightCents: $pricePerNightCents, ')
          ..write('status: $status, ')
          ..write('currentGuest: $currentGuest, ')
          ..write('checkoutDate: $checkoutDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SalesTable extends Sales with TableInfo<$SalesTable, Sale> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SalesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _soldAtMeta = const VerificationMeta('soldAt');
  @override
  late final GeneratedColumn<DateTime> soldAt = GeneratedColumn<DateTime>(
      'sold_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _serverUserIdMeta =
      const VerificationMeta('serverUserId');
  @override
  late final GeneratedColumn<int> serverUserId = GeneratedColumn<int>(
      'server_user_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES users (id) ON DELETE SET NULL'));
  @override
  late final GeneratedColumnWithTypeConverter<DbPayment, int> payment =
      GeneratedColumn<int>('payment', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<DbPayment>($SalesTable.$converterpayment);
  @override
  late final GeneratedColumnWithTypeConverter<DbLocation, int> location =
      GeneratedColumn<int>('location', aliasedName, false,
              type: DriftSqlType.int,
              requiredDuringInsert: false,
              defaultValue: const Constant(0))
          .withConverter<DbLocation>($SalesTable.$converterlocation);
  static const VerificationMeta _customerNameMeta =
      const VerificationMeta('customerName');
  @override
  late final GeneratedColumn<String> customerName = GeneratedColumn<String>(
      'customer_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, soldAt, serverUserId, payment, location, customerName, note];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sales';
  @override
  VerificationContext validateIntegrity(Insertable<Sale> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sold_at')) {
      context.handle(_soldAtMeta,
          soldAt.isAcceptableOrUnknown(data['sold_at']!, _soldAtMeta));
    } else if (isInserting) {
      context.missing(_soldAtMeta);
    }
    if (data.containsKey('server_user_id')) {
      context.handle(
          _serverUserIdMeta,
          serverUserId.isAcceptableOrUnknown(
              data['server_user_id']!, _serverUserIdMeta));
    }
    if (data.containsKey('customer_name')) {
      context.handle(
          _customerNameMeta,
          customerName.isAcceptableOrUnknown(
              data['customer_name']!, _customerNameMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Sale map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Sale(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      soldAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}sold_at'])!,
      serverUserId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}server_user_id']),
      payment: $SalesTable.$converterpayment.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}payment'])!),
      location: $SalesTable.$converterlocation.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}location'])!),
      customerName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}customer_name']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
    );
  }

  @override
  $SalesTable createAlias(String alias) {
    return $SalesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DbPayment, int, int> $converterpayment =
      const EnumIndexConverter<DbPayment>(DbPayment.values);
  static JsonTypeConverter2<DbLocation, int, int> $converterlocation =
      const EnumIndexConverter<DbLocation>(DbLocation.values);
}

class Sale extends DataClass implements Insertable<Sale> {
  final int id;
  final DateTime soldAt;
  final int? serverUserId;
  final DbPayment payment;
  final DbLocation location;
  final String? customerName;
  final String? note;
  const Sale(
      {required this.id,
      required this.soldAt,
      this.serverUserId,
      required this.payment,
      required this.location,
      this.customerName,
      this.note});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['sold_at'] = Variable<DateTime>(soldAt);
    if (!nullToAbsent || serverUserId != null) {
      map['server_user_id'] = Variable<int>(serverUserId);
    }
    {
      map['payment'] =
          Variable<int>($SalesTable.$converterpayment.toSql(payment));
    }
    {
      map['location'] =
          Variable<int>($SalesTable.$converterlocation.toSql(location));
    }
    if (!nullToAbsent || customerName != null) {
      map['customer_name'] = Variable<String>(customerName);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  SalesCompanion toCompanion(bool nullToAbsent) {
    return SalesCompanion(
      id: Value(id),
      soldAt: Value(soldAt),
      serverUserId: serverUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverUserId),
      payment: Value(payment),
      location: Value(location),
      customerName: customerName == null && nullToAbsent
          ? const Value.absent()
          : Value(customerName),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory Sale.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Sale(
      id: serializer.fromJson<int>(json['id']),
      soldAt: serializer.fromJson<DateTime>(json['soldAt']),
      serverUserId: serializer.fromJson<int?>(json['serverUserId']),
      payment: $SalesTable.$converterpayment
          .fromJson(serializer.fromJson<int>(json['payment'])),
      location: $SalesTable.$converterlocation
          .fromJson(serializer.fromJson<int>(json['location'])),
      customerName: serializer.fromJson<String?>(json['customerName']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'soldAt': serializer.toJson<DateTime>(soldAt),
      'serverUserId': serializer.toJson<int?>(serverUserId),
      'payment':
          serializer.toJson<int>($SalesTable.$converterpayment.toJson(payment)),
      'location': serializer
          .toJson<int>($SalesTable.$converterlocation.toJson(location)),
      'customerName': serializer.toJson<String?>(customerName),
      'note': serializer.toJson<String?>(note),
    };
  }

  Sale copyWith(
          {int? id,
          DateTime? soldAt,
          Value<int?> serverUserId = const Value.absent(),
          DbPayment? payment,
          DbLocation? location,
          Value<String?> customerName = const Value.absent(),
          Value<String?> note = const Value.absent()}) =>
      Sale(
        id: id ?? this.id,
        soldAt: soldAt ?? this.soldAt,
        serverUserId:
            serverUserId.present ? serverUserId.value : this.serverUserId,
        payment: payment ?? this.payment,
        location: location ?? this.location,
        customerName:
            customerName.present ? customerName.value : this.customerName,
        note: note.present ? note.value : this.note,
      );
  Sale copyWithCompanion(SalesCompanion data) {
    return Sale(
      id: data.id.present ? data.id.value : this.id,
      soldAt: data.soldAt.present ? data.soldAt.value : this.soldAt,
      serverUserId: data.serverUserId.present
          ? data.serverUserId.value
          : this.serverUserId,
      payment: data.payment.present ? data.payment.value : this.payment,
      location: data.location.present ? data.location.value : this.location,
      customerName: data.customerName.present
          ? data.customerName.value
          : this.customerName,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Sale(')
          ..write('id: $id, ')
          ..write('soldAt: $soldAt, ')
          ..write('serverUserId: $serverUserId, ')
          ..write('payment: $payment, ')
          ..write('location: $location, ')
          ..write('customerName: $customerName, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, soldAt, serverUserId, payment, location, customerName, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Sale &&
          other.id == this.id &&
          other.soldAt == this.soldAt &&
          other.serverUserId == this.serverUserId &&
          other.payment == this.payment &&
          other.location == this.location &&
          other.customerName == this.customerName &&
          other.note == this.note);
}

class SalesCompanion extends UpdateCompanion<Sale> {
  final Value<int> id;
  final Value<DateTime> soldAt;
  final Value<int?> serverUserId;
  final Value<DbPayment> payment;
  final Value<DbLocation> location;
  final Value<String?> customerName;
  final Value<String?> note;
  const SalesCompanion({
    this.id = const Value.absent(),
    this.soldAt = const Value.absent(),
    this.serverUserId = const Value.absent(),
    this.payment = const Value.absent(),
    this.location = const Value.absent(),
    this.customerName = const Value.absent(),
    this.note = const Value.absent(),
  });
  SalesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime soldAt,
    this.serverUserId = const Value.absent(),
    required DbPayment payment,
    this.location = const Value.absent(),
    this.customerName = const Value.absent(),
    this.note = const Value.absent(),
  })  : soldAt = Value(soldAt),
        payment = Value(payment);
  static Insertable<Sale> custom({
    Expression<int>? id,
    Expression<DateTime>? soldAt,
    Expression<int>? serverUserId,
    Expression<int>? payment,
    Expression<int>? location,
    Expression<String>? customerName,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (soldAt != null) 'sold_at': soldAt,
      if (serverUserId != null) 'server_user_id': serverUserId,
      if (payment != null) 'payment': payment,
      if (location != null) 'location': location,
      if (customerName != null) 'customer_name': customerName,
      if (note != null) 'note': note,
    });
  }

  SalesCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? soldAt,
      Value<int?>? serverUserId,
      Value<DbPayment>? payment,
      Value<DbLocation>? location,
      Value<String?>? customerName,
      Value<String?>? note}) {
    return SalesCompanion(
      id: id ?? this.id,
      soldAt: soldAt ?? this.soldAt,
      serverUserId: serverUserId ?? this.serverUserId,
      payment: payment ?? this.payment,
      location: location ?? this.location,
      customerName: customerName ?? this.customerName,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (soldAt.present) {
      map['sold_at'] = Variable<DateTime>(soldAt.value);
    }
    if (serverUserId.present) {
      map['server_user_id'] = Variable<int>(serverUserId.value);
    }
    if (payment.present) {
      map['payment'] =
          Variable<int>($SalesTable.$converterpayment.toSql(payment.value));
    }
    if (location.present) {
      map['location'] =
          Variable<int>($SalesTable.$converterlocation.toSql(location.value));
    }
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SalesCompanion(')
          ..write('id: $id, ')
          ..write('soldAt: $soldAt, ')
          ..write('serverUserId: $serverUserId, ')
          ..write('payment: $payment, ')
          ..write('location: $location, ')
          ..write('customerName: $customerName, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $SaleLinesTable extends SaleLines
    with TableInfo<$SaleLinesTable, SaleLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SaleLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _saleIdMeta = const VerificationMeta('saleId');
  @override
  late final GeneratedColumn<int> saleId = GeneratedColumn<int>(
      'sale_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES sales (id) ON DELETE CASCADE'));
  static const VerificationMeta _articleIdMeta =
      const VerificationMeta('articleId');
  @override
  late final GeneratedColumn<int> articleId = GeneratedColumn<int>(
      'article_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES articles (id) ON DELETE SET NULL'));
  static const VerificationMeta _articleNameMeta =
      const VerificationMeta('articleName');
  @override
  late final GeneratedColumn<String> articleName = GeneratedColumn<String>(
      'article_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<int> qty = GeneratedColumn<int>(
      'qty', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _unitPriceCentsMeta =
      const VerificationMeta('unitPriceCents');
  @override
  late final GeneratedColumn<int> unitPriceCents = GeneratedColumn<int>(
      'unit_price_cents', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, saleId, articleId, articleName, qty, unitPriceCents];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sale_lines';
  @override
  VerificationContext validateIntegrity(Insertable<SaleLine> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sale_id')) {
      context.handle(_saleIdMeta,
          saleId.isAcceptableOrUnknown(data['sale_id']!, _saleIdMeta));
    } else if (isInserting) {
      context.missing(_saleIdMeta);
    }
    if (data.containsKey('article_id')) {
      context.handle(_articleIdMeta,
          articleId.isAcceptableOrUnknown(data['article_id']!, _articleIdMeta));
    }
    if (data.containsKey('article_name')) {
      context.handle(
          _articleNameMeta,
          articleName.isAcceptableOrUnknown(
              data['article_name']!, _articleNameMeta));
    } else if (isInserting) {
      context.missing(_articleNameMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
          _qtyMeta, qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta));
    } else if (isInserting) {
      context.missing(_qtyMeta);
    }
    if (data.containsKey('unit_price_cents')) {
      context.handle(
          _unitPriceCentsMeta,
          unitPriceCents.isAcceptableOrUnknown(
              data['unit_price_cents']!, _unitPriceCentsMeta));
    } else if (isInserting) {
      context.missing(_unitPriceCentsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SaleLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SaleLine(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      saleId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sale_id'])!,
      articleId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}article_id']),
      articleName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}article_name'])!,
      qty: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}qty'])!,
      unitPriceCents: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}unit_price_cents'])!,
    );
  }

  @override
  $SaleLinesTable createAlias(String alias) {
    return $SaleLinesTable(attachedDatabase, alias);
  }
}

class SaleLine extends DataClass implements Insertable<SaleLine> {
  final int id;
  final int saleId;
  final int? articleId;
  final String articleName;
  final int qty;
  final int unitPriceCents;
  const SaleLine(
      {required this.id,
      required this.saleId,
      this.articleId,
      required this.articleName,
      required this.qty,
      required this.unitPriceCents});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['sale_id'] = Variable<int>(saleId);
    if (!nullToAbsent || articleId != null) {
      map['article_id'] = Variable<int>(articleId);
    }
    map['article_name'] = Variable<String>(articleName);
    map['qty'] = Variable<int>(qty);
    map['unit_price_cents'] = Variable<int>(unitPriceCents);
    return map;
  }

  SaleLinesCompanion toCompanion(bool nullToAbsent) {
    return SaleLinesCompanion(
      id: Value(id),
      saleId: Value(saleId),
      articleId: articleId == null && nullToAbsent
          ? const Value.absent()
          : Value(articleId),
      articleName: Value(articleName),
      qty: Value(qty),
      unitPriceCents: Value(unitPriceCents),
    );
  }

  factory SaleLine.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SaleLine(
      id: serializer.fromJson<int>(json['id']),
      saleId: serializer.fromJson<int>(json['saleId']),
      articleId: serializer.fromJson<int?>(json['articleId']),
      articleName: serializer.fromJson<String>(json['articleName']),
      qty: serializer.fromJson<int>(json['qty']),
      unitPriceCents: serializer.fromJson<int>(json['unitPriceCents']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'saleId': serializer.toJson<int>(saleId),
      'articleId': serializer.toJson<int?>(articleId),
      'articleName': serializer.toJson<String>(articleName),
      'qty': serializer.toJson<int>(qty),
      'unitPriceCents': serializer.toJson<int>(unitPriceCents),
    };
  }

  SaleLine copyWith(
          {int? id,
          int? saleId,
          Value<int?> articleId = const Value.absent(),
          String? articleName,
          int? qty,
          int? unitPriceCents}) =>
      SaleLine(
        id: id ?? this.id,
        saleId: saleId ?? this.saleId,
        articleId: articleId.present ? articleId.value : this.articleId,
        articleName: articleName ?? this.articleName,
        qty: qty ?? this.qty,
        unitPriceCents: unitPriceCents ?? this.unitPriceCents,
      );
  SaleLine copyWithCompanion(SaleLinesCompanion data) {
    return SaleLine(
      id: data.id.present ? data.id.value : this.id,
      saleId: data.saleId.present ? data.saleId.value : this.saleId,
      articleId: data.articleId.present ? data.articleId.value : this.articleId,
      articleName:
          data.articleName.present ? data.articleName.value : this.articleName,
      qty: data.qty.present ? data.qty.value : this.qty,
      unitPriceCents: data.unitPriceCents.present
          ? data.unitPriceCents.value
          : this.unitPriceCents,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SaleLine(')
          ..write('id: $id, ')
          ..write('saleId: $saleId, ')
          ..write('articleId: $articleId, ')
          ..write('articleName: $articleName, ')
          ..write('qty: $qty, ')
          ..write('unitPriceCents: $unitPriceCents')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, saleId, articleId, articleName, qty, unitPriceCents);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SaleLine &&
          other.id == this.id &&
          other.saleId == this.saleId &&
          other.articleId == this.articleId &&
          other.articleName == this.articleName &&
          other.qty == this.qty &&
          other.unitPriceCents == this.unitPriceCents);
}

class SaleLinesCompanion extends UpdateCompanion<SaleLine> {
  final Value<int> id;
  final Value<int> saleId;
  final Value<int?> articleId;
  final Value<String> articleName;
  final Value<int> qty;
  final Value<int> unitPriceCents;
  const SaleLinesCompanion({
    this.id = const Value.absent(),
    this.saleId = const Value.absent(),
    this.articleId = const Value.absent(),
    this.articleName = const Value.absent(),
    this.qty = const Value.absent(),
    this.unitPriceCents = const Value.absent(),
  });
  SaleLinesCompanion.insert({
    this.id = const Value.absent(),
    required int saleId,
    this.articleId = const Value.absent(),
    required String articleName,
    required int qty,
    required int unitPriceCents,
  })  : saleId = Value(saleId),
        articleName = Value(articleName),
        qty = Value(qty),
        unitPriceCents = Value(unitPriceCents);
  static Insertable<SaleLine> custom({
    Expression<int>? id,
    Expression<int>? saleId,
    Expression<int>? articleId,
    Expression<String>? articleName,
    Expression<int>? qty,
    Expression<int>? unitPriceCents,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (saleId != null) 'sale_id': saleId,
      if (articleId != null) 'article_id': articleId,
      if (articleName != null) 'article_name': articleName,
      if (qty != null) 'qty': qty,
      if (unitPriceCents != null) 'unit_price_cents': unitPriceCents,
    });
  }

  SaleLinesCompanion copyWith(
      {Value<int>? id,
      Value<int>? saleId,
      Value<int?>? articleId,
      Value<String>? articleName,
      Value<int>? qty,
      Value<int>? unitPriceCents}) {
    return SaleLinesCompanion(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      articleId: articleId ?? this.articleId,
      articleName: articleName ?? this.articleName,
      qty: qty ?? this.qty,
      unitPriceCents: unitPriceCents ?? this.unitPriceCents,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (saleId.present) {
      map['sale_id'] = Variable<int>(saleId.value);
    }
    if (articleId.present) {
      map['article_id'] = Variable<int>(articleId.value);
    }
    if (articleName.present) {
      map['article_name'] = Variable<String>(articleName.value);
    }
    if (qty.present) {
      map['qty'] = Variable<int>(qty.value);
    }
    if (unitPriceCents.present) {
      map['unit_price_cents'] = Variable<int>(unitPriceCents.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SaleLinesCompanion(')
          ..write('id: $id, ')
          ..write('saleId: $saleId, ')
          ..write('articleId: $articleId, ')
          ..write('articleName: $articleName, ')
          ..write('qty: $qty, ')
          ..write('unitPriceCents: $unitPriceCents')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $UsersTable users = $UsersTable(this);
  late final $ArticlesTable articles = $ArticlesTable(this);
  late final $RoomsTable rooms = $RoomsTable(this);
  late final $SalesTable sales = $SalesTable(this);
  late final $SaleLinesTable saleLines = $SaleLinesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [settings, users, articles, rooms, sales, saleLines];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('users',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('sales', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('sales',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('sale_lines', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('articles',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('sale_lines', kind: UpdateKind.update),
            ],
          ),
        ],
      );
}

typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
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
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
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
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
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
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()> {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()>;
typedef $$UsersTableCreateCompanionBuilder = UsersCompanion Function({
  Value<int> id,
  required String fullName,
  required String login,
  required String passwordHash,
  required DbUserRole role,
  Value<bool> active,
  Value<DateTime> createdAt,
  Value<DateTime?> lastLogin,
});
typedef $$UsersTableUpdateCompanionBuilder = UsersCompanion Function({
  Value<int> id,
  Value<String> fullName,
  Value<String> login,
  Value<String> passwordHash,
  Value<DbUserRole> role,
  Value<bool> active,
  Value<DateTime> createdAt,
  Value<DateTime?> lastLogin,
});

final class $$UsersTableReferences
    extends BaseReferences<_$AppDatabase, $UsersTable, User> {
  $$UsersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SalesTable, List<Sale>> _salesRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.sales,
          aliasName: 'users__id__sales__server_user_id');

  $$SalesTableProcessedTableManager get salesRefs {
    final manager = $$SalesTableTableManager($_db, $_db.sales)
        .filter((f) => f.serverUserId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_salesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fullName => $composableBuilder(
      column: $table.fullName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get login => $composableBuilder(
      column: $table.login, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get passwordHash => $composableBuilder(
      column: $table.passwordHash, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<DbUserRole, DbUserRole, int> get role =>
      $composableBuilder(
          column: $table.role,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<bool> get active => $composableBuilder(
      column: $table.active, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastLogin => $composableBuilder(
      column: $table.lastLogin, builder: (column) => ColumnFilters(column));

  Expression<bool> salesRefs(
      Expression<bool> Function($$SalesTableFilterComposer f) f) {
    final $$SalesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.sales,
        getReferencedColumn: (t) => t.serverUserId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SalesTableFilterComposer(
              $db: $db,
              $table: $db.sales,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fullName => $composableBuilder(
      column: $table.fullName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get login => $composableBuilder(
      column: $table.login, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get passwordHash => $composableBuilder(
      column: $table.passwordHash,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get active => $composableBuilder(
      column: $table.active, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastLogin => $composableBuilder(
      column: $table.lastLogin, builder: (column) => ColumnOrderings(column));
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fullName =>
      $composableBuilder(column: $table.fullName, builder: (column) => column);

  GeneratedColumn<String> get login =>
      $composableBuilder(column: $table.login, builder: (column) => column);

  GeneratedColumn<String> get passwordHash => $composableBuilder(
      column: $table.passwordHash, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DbUserRole, int> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastLogin =>
      $composableBuilder(column: $table.lastLogin, builder: (column) => column);

  Expression<T> salesRefs<T extends Object>(
      Expression<T> Function($$SalesTableAnnotationComposer a) f) {
    final $$SalesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.sales,
        getReferencedColumn: (t) => t.serverUserId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SalesTableAnnotationComposer(
              $db: $db,
              $table: $db.sales,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$UsersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UsersTable,
    User,
    $$UsersTableFilterComposer,
    $$UsersTableOrderingComposer,
    $$UsersTableAnnotationComposer,
    $$UsersTableCreateCompanionBuilder,
    $$UsersTableUpdateCompanionBuilder,
    (User, $$UsersTableReferences),
    User,
    PrefetchHooks Function({bool salesRefs})> {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> fullName = const Value.absent(),
            Value<String> login = const Value.absent(),
            Value<String> passwordHash = const Value.absent(),
            Value<DbUserRole> role = const Value.absent(),
            Value<bool> active = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> lastLogin = const Value.absent(),
          }) =>
              UsersCompanion(
            id: id,
            fullName: fullName,
            login: login,
            passwordHash: passwordHash,
            role: role,
            active: active,
            createdAt: createdAt,
            lastLogin: lastLogin,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String fullName,
            required String login,
            required String passwordHash,
            required DbUserRole role,
            Value<bool> active = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> lastLogin = const Value.absent(),
          }) =>
              UsersCompanion.insert(
            id: id,
            fullName: fullName,
            login: login,
            passwordHash: passwordHash,
            role: role,
            active: active,
            createdAt: createdAt,
            lastLogin: lastLogin,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$UsersTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({salesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (salesRefs) db.sales],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (salesRefs)
                    await $_getPrefetchedData<User, $UsersTable, Sale>(
                        currentTable: table,
                        referencedTable:
                            $$UsersTableReferences._salesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$UsersTableReferences(db, table, p0).salesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.serverUserId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$UsersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UsersTable,
    User,
    $$UsersTableFilterComposer,
    $$UsersTableOrderingComposer,
    $$UsersTableAnnotationComposer,
    $$UsersTableCreateCompanionBuilder,
    $$UsersTableUpdateCompanionBuilder,
    (User, $$UsersTableReferences),
    User,
    PrefetchHooks Function({bool salesRefs})>;
typedef $$ArticlesTableCreateCompanionBuilder = ArticlesCompanion Function({
  Value<int> id,
  required String name,
  required int priceCents,
  required DbCategory category,
  Value<bool> active,
  Value<String?> imagePath,
  Value<bool> trackStock,
  Value<String> unit,
  Value<int> stockQty,
  Value<int> threshold,
});
typedef $$ArticlesTableUpdateCompanionBuilder = ArticlesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<int> priceCents,
  Value<DbCategory> category,
  Value<bool> active,
  Value<String?> imagePath,
  Value<bool> trackStock,
  Value<String> unit,
  Value<int> stockQty,
  Value<int> threshold,
});

final class $$ArticlesTableReferences
    extends BaseReferences<_$AppDatabase, $ArticlesTable, Article> {
  $$ArticlesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SaleLinesTable, List<SaleLine>>
      _saleLinesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.saleLines,
              aliasName: 'articles__id__sale_lines__article_id');

  $$SaleLinesTableProcessedTableManager get saleLinesRefs {
    final manager = $$SaleLinesTableTableManager($_db, $_db.saleLines)
        .filter((f) => f.articleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_saleLinesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ArticlesTableFilterComposer
    extends Composer<_$AppDatabase, $ArticlesTable> {
  $$ArticlesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get priceCents => $composableBuilder(
      column: $table.priceCents, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<DbCategory, DbCategory, int> get category =>
      $composableBuilder(
          column: $table.category,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<bool> get active => $composableBuilder(
      column: $table.active, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get trackStock => $composableBuilder(
      column: $table.trackStock, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get stockQty => $composableBuilder(
      column: $table.stockQty, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get threshold => $composableBuilder(
      column: $table.threshold, builder: (column) => ColumnFilters(column));

  Expression<bool> saleLinesRefs(
      Expression<bool> Function($$SaleLinesTableFilterComposer f) f) {
    final $$SaleLinesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.saleLines,
        getReferencedColumn: (t) => t.articleId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SaleLinesTableFilterComposer(
              $db: $db,
              $table: $db.saleLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ArticlesTableOrderingComposer
    extends Composer<_$AppDatabase, $ArticlesTable> {
  $$ArticlesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get priceCents => $composableBuilder(
      column: $table.priceCents, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get active => $composableBuilder(
      column: $table.active, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get trackStock => $composableBuilder(
      column: $table.trackStock, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get stockQty => $composableBuilder(
      column: $table.stockQty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get threshold => $composableBuilder(
      column: $table.threshold, builder: (column) => ColumnOrderings(column));
}

class $$ArticlesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ArticlesTable> {
  $$ArticlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get priceCents => $composableBuilder(
      column: $table.priceCents, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DbCategory, int> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<bool> get trackStock => $composableBuilder(
      column: $table.trackStock, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<int> get stockQty =>
      $composableBuilder(column: $table.stockQty, builder: (column) => column);

  GeneratedColumn<int> get threshold =>
      $composableBuilder(column: $table.threshold, builder: (column) => column);

  Expression<T> saleLinesRefs<T extends Object>(
      Expression<T> Function($$SaleLinesTableAnnotationComposer a) f) {
    final $$SaleLinesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.saleLines,
        getReferencedColumn: (t) => t.articleId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SaleLinesTableAnnotationComposer(
              $db: $db,
              $table: $db.saleLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ArticlesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ArticlesTable,
    Article,
    $$ArticlesTableFilterComposer,
    $$ArticlesTableOrderingComposer,
    $$ArticlesTableAnnotationComposer,
    $$ArticlesTableCreateCompanionBuilder,
    $$ArticlesTableUpdateCompanionBuilder,
    (Article, $$ArticlesTableReferences),
    Article,
    PrefetchHooks Function({bool saleLinesRefs})> {
  $$ArticlesTableTableManager(_$AppDatabase db, $ArticlesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArticlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArticlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArticlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> priceCents = const Value.absent(),
            Value<DbCategory> category = const Value.absent(),
            Value<bool> active = const Value.absent(),
            Value<String?> imagePath = const Value.absent(),
            Value<bool> trackStock = const Value.absent(),
            Value<String> unit = const Value.absent(),
            Value<int> stockQty = const Value.absent(),
            Value<int> threshold = const Value.absent(),
          }) =>
              ArticlesCompanion(
            id: id,
            name: name,
            priceCents: priceCents,
            category: category,
            active: active,
            imagePath: imagePath,
            trackStock: trackStock,
            unit: unit,
            stockQty: stockQty,
            threshold: threshold,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            required int priceCents,
            required DbCategory category,
            Value<bool> active = const Value.absent(),
            Value<String?> imagePath = const Value.absent(),
            Value<bool> trackStock = const Value.absent(),
            Value<String> unit = const Value.absent(),
            Value<int> stockQty = const Value.absent(),
            Value<int> threshold = const Value.absent(),
          }) =>
              ArticlesCompanion.insert(
            id: id,
            name: name,
            priceCents: priceCents,
            category: category,
            active: active,
            imagePath: imagePath,
            trackStock: trackStock,
            unit: unit,
            stockQty: stockQty,
            threshold: threshold,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$ArticlesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({saleLinesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (saleLinesRefs) db.saleLines],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (saleLinesRefs)
                    await $_getPrefetchedData<Article, $ArticlesTable,
                            SaleLine>(
                        currentTable: table,
                        referencedTable:
                            $$ArticlesTableReferences._saleLinesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ArticlesTableReferences(db, table, p0)
                                .saleLinesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.articleId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ArticlesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ArticlesTable,
    Article,
    $$ArticlesTableFilterComposer,
    $$ArticlesTableOrderingComposer,
    $$ArticlesTableAnnotationComposer,
    $$ArticlesTableCreateCompanionBuilder,
    $$ArticlesTableUpdateCompanionBuilder,
    (Article, $$ArticlesTableReferences),
    Article,
    PrefetchHooks Function({bool saleLinesRefs})>;
typedef $$RoomsTableCreateCompanionBuilder = RoomsCompanion Function({
  required String number,
  required String type,
  required int pricePerNightCents,
  required DbRoomStatus status,
  Value<String?> currentGuest,
  Value<DateTime?> checkoutDate,
  Value<int> rowid,
});
typedef $$RoomsTableUpdateCompanionBuilder = RoomsCompanion Function({
  Value<String> number,
  Value<String> type,
  Value<int> pricePerNightCents,
  Value<DbRoomStatus> status,
  Value<String?> currentGuest,
  Value<DateTime?> checkoutDate,
  Value<int> rowid,
});

class $$RoomsTableFilterComposer extends Composer<_$AppDatabase, $RoomsTable> {
  $$RoomsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get number => $composableBuilder(
      column: $table.number, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pricePerNightCents => $composableBuilder(
      column: $table.pricePerNightCents,
      builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<DbRoomStatus, DbRoomStatus, int> get status =>
      $composableBuilder(
          column: $table.status,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get currentGuest => $composableBuilder(
      column: $table.currentGuest, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get checkoutDate => $composableBuilder(
      column: $table.checkoutDate, builder: (column) => ColumnFilters(column));
}

class $$RoomsTableOrderingComposer
    extends Composer<_$AppDatabase, $RoomsTable> {
  $$RoomsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get number => $composableBuilder(
      column: $table.number, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pricePerNightCents => $composableBuilder(
      column: $table.pricePerNightCents,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currentGuest => $composableBuilder(
      column: $table.currentGuest,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get checkoutDate => $composableBuilder(
      column: $table.checkoutDate,
      builder: (column) => ColumnOrderings(column));
}

class $$RoomsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoomsTable> {
  $$RoomsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get pricePerNightCents => $composableBuilder(
      column: $table.pricePerNightCents, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DbRoomStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get currentGuest => $composableBuilder(
      column: $table.currentGuest, builder: (column) => column);

  GeneratedColumn<DateTime> get checkoutDate => $composableBuilder(
      column: $table.checkoutDate, builder: (column) => column);
}

class $$RoomsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RoomsTable,
    Room,
    $$RoomsTableFilterComposer,
    $$RoomsTableOrderingComposer,
    $$RoomsTableAnnotationComposer,
    $$RoomsTableCreateCompanionBuilder,
    $$RoomsTableUpdateCompanionBuilder,
    (Room, BaseReferences<_$AppDatabase, $RoomsTable, Room>),
    Room,
    PrefetchHooks Function()> {
  $$RoomsTableTableManager(_$AppDatabase db, $RoomsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoomsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoomsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoomsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> number = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<int> pricePerNightCents = const Value.absent(),
            Value<DbRoomStatus> status = const Value.absent(),
            Value<String?> currentGuest = const Value.absent(),
            Value<DateTime?> checkoutDate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RoomsCompanion(
            number: number,
            type: type,
            pricePerNightCents: pricePerNightCents,
            status: status,
            currentGuest: currentGuest,
            checkoutDate: checkoutDate,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String number,
            required String type,
            required int pricePerNightCents,
            required DbRoomStatus status,
            Value<String?> currentGuest = const Value.absent(),
            Value<DateTime?> checkoutDate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RoomsCompanion.insert(
            number: number,
            type: type,
            pricePerNightCents: pricePerNightCents,
            status: status,
            currentGuest: currentGuest,
            checkoutDate: checkoutDate,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RoomsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RoomsTable,
    Room,
    $$RoomsTableFilterComposer,
    $$RoomsTableOrderingComposer,
    $$RoomsTableAnnotationComposer,
    $$RoomsTableCreateCompanionBuilder,
    $$RoomsTableUpdateCompanionBuilder,
    (Room, BaseReferences<_$AppDatabase, $RoomsTable, Room>),
    Room,
    PrefetchHooks Function()>;
typedef $$SalesTableCreateCompanionBuilder = SalesCompanion Function({
  Value<int> id,
  required DateTime soldAt,
  Value<int?> serverUserId,
  required DbPayment payment,
  Value<DbLocation> location,
  Value<String?> customerName,
  Value<String?> note,
});
typedef $$SalesTableUpdateCompanionBuilder = SalesCompanion Function({
  Value<int> id,
  Value<DateTime> soldAt,
  Value<int?> serverUserId,
  Value<DbPayment> payment,
  Value<DbLocation> location,
  Value<String?> customerName,
  Value<String?> note,
});

final class $$SalesTableReferences
    extends BaseReferences<_$AppDatabase, $SalesTable, Sale> {
  $$SalesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UsersTable _serverUserIdTable(_$AppDatabase db) =>
      db.users.createAlias('sales__server_user_id__users__id');

  $$UsersTableProcessedTableManager? get serverUserId {
    final $_column = $_itemColumn<int>('server_user_id');
    if ($_column == null) return null;
    final manager = $$UsersTableTableManager($_db, $_db.users)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_serverUserIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$SaleLinesTable, List<SaleLine>>
      _saleLinesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.saleLines,
              aliasName: 'sales__id__sale_lines__sale_id');

  $$SaleLinesTableProcessedTableManager get saleLinesRefs {
    final manager = $$SaleLinesTableTableManager($_db, $_db.saleLines)
        .filter((f) => f.saleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_saleLinesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$SalesTableFilterComposer extends Composer<_$AppDatabase, $SalesTable> {
  $$SalesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get soldAt => $composableBuilder(
      column: $table.soldAt, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<DbPayment, DbPayment, int> get payment =>
      $composableBuilder(
          column: $table.payment,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<DbLocation, DbLocation, int> get location =>
      $composableBuilder(
          column: $table.location,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get customerName => $composableBuilder(
      column: $table.customerName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  $$UsersTableFilterComposer get serverUserId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.serverUserId,
        referencedTable: $db.users,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UsersTableFilterComposer(
              $db: $db,
              $table: $db.users,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> saleLinesRefs(
      Expression<bool> Function($$SaleLinesTableFilterComposer f) f) {
    final $$SaleLinesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.saleLines,
        getReferencedColumn: (t) => t.saleId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SaleLinesTableFilterComposer(
              $db: $db,
              $table: $db.saleLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SalesTableOrderingComposer
    extends Composer<_$AppDatabase, $SalesTable> {
  $$SalesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get soldAt => $composableBuilder(
      column: $table.soldAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get payment => $composableBuilder(
      column: $table.payment, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customerName => $composableBuilder(
      column: $table.customerName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  $$UsersTableOrderingComposer get serverUserId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.serverUserId,
        referencedTable: $db.users,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UsersTableOrderingComposer(
              $db: $db,
              $table: $db.users,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SalesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SalesTable> {
  $$SalesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get soldAt =>
      $composableBuilder(column: $table.soldAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DbPayment, int> get payment =>
      $composableBuilder(column: $table.payment, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DbLocation, int> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get customerName => $composableBuilder(
      column: $table.customerName, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  $$UsersTableAnnotationComposer get serverUserId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.serverUserId,
        referencedTable: $db.users,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UsersTableAnnotationComposer(
              $db: $db,
              $table: $db.users,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> saleLinesRefs<T extends Object>(
      Expression<T> Function($$SaleLinesTableAnnotationComposer a) f) {
    final $$SaleLinesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.saleLines,
        getReferencedColumn: (t) => t.saleId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SaleLinesTableAnnotationComposer(
              $db: $db,
              $table: $db.saleLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SalesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SalesTable,
    Sale,
    $$SalesTableFilterComposer,
    $$SalesTableOrderingComposer,
    $$SalesTableAnnotationComposer,
    $$SalesTableCreateCompanionBuilder,
    $$SalesTableUpdateCompanionBuilder,
    (Sale, $$SalesTableReferences),
    Sale,
    PrefetchHooks Function({bool serverUserId, bool saleLinesRefs})> {
  $$SalesTableTableManager(_$AppDatabase db, $SalesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SalesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SalesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SalesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> soldAt = const Value.absent(),
            Value<int?> serverUserId = const Value.absent(),
            Value<DbPayment> payment = const Value.absent(),
            Value<DbLocation> location = const Value.absent(),
            Value<String?> customerName = const Value.absent(),
            Value<String?> note = const Value.absent(),
          }) =>
              SalesCompanion(
            id: id,
            soldAt: soldAt,
            serverUserId: serverUserId,
            payment: payment,
            location: location,
            customerName: customerName,
            note: note,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime soldAt,
            Value<int?> serverUserId = const Value.absent(),
            required DbPayment payment,
            Value<DbLocation> location = const Value.absent(),
            Value<String?> customerName = const Value.absent(),
            Value<String?> note = const Value.absent(),
          }) =>
              SalesCompanion.insert(
            id: id,
            soldAt: soldAt,
            serverUserId: serverUserId,
            payment: payment,
            location: location,
            customerName: customerName,
            note: note,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$SalesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {serverUserId = false, saleLinesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (saleLinesRefs) db.saleLines],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (serverUserId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.serverUserId,
                    referencedTable:
                        $$SalesTableReferences._serverUserIdTable(db),
                    referencedColumn:
                        $$SalesTableReferences._serverUserIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (saleLinesRefs)
                    await $_getPrefetchedData<Sale, $SalesTable, SaleLine>(
                        currentTable: table,
                        referencedTable:
                            $$SalesTableReferences._saleLinesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SalesTableReferences(db, table, p0).saleLinesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.saleId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$SalesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SalesTable,
    Sale,
    $$SalesTableFilterComposer,
    $$SalesTableOrderingComposer,
    $$SalesTableAnnotationComposer,
    $$SalesTableCreateCompanionBuilder,
    $$SalesTableUpdateCompanionBuilder,
    (Sale, $$SalesTableReferences),
    Sale,
    PrefetchHooks Function({bool serverUserId, bool saleLinesRefs})>;
typedef $$SaleLinesTableCreateCompanionBuilder = SaleLinesCompanion Function({
  Value<int> id,
  required int saleId,
  Value<int?> articleId,
  required String articleName,
  required int qty,
  required int unitPriceCents,
});
typedef $$SaleLinesTableUpdateCompanionBuilder = SaleLinesCompanion Function({
  Value<int> id,
  Value<int> saleId,
  Value<int?> articleId,
  Value<String> articleName,
  Value<int> qty,
  Value<int> unitPriceCents,
});

final class $$SaleLinesTableReferences
    extends BaseReferences<_$AppDatabase, $SaleLinesTable, SaleLine> {
  $$SaleLinesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SalesTable _saleIdTable(_$AppDatabase db) =>
      db.sales.createAlias('sale_lines__sale_id__sales__id');

  $$SalesTableProcessedTableManager get saleId {
    final $_column = $_itemColumn<int>('sale_id')!;

    final manager = $$SalesTableTableManager($_db, $_db.sales)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_saleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ArticlesTable _articleIdTable(_$AppDatabase db) =>
      db.articles.createAlias('sale_lines__article_id__articles__id');

  $$ArticlesTableProcessedTableManager? get articleId {
    final $_column = $_itemColumn<int>('article_id');
    if ($_column == null) return null;
    final manager = $$ArticlesTableTableManager($_db, $_db.articles)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_articleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$SaleLinesTableFilterComposer
    extends Composer<_$AppDatabase, $SaleLinesTable> {
  $$SaleLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get articleName => $composableBuilder(
      column: $table.articleName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get qty => $composableBuilder(
      column: $table.qty, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get unitPriceCents => $composableBuilder(
      column: $table.unitPriceCents,
      builder: (column) => ColumnFilters(column));

  $$SalesTableFilterComposer get saleId {
    final $$SalesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.saleId,
        referencedTable: $db.sales,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SalesTableFilterComposer(
              $db: $db,
              $table: $db.sales,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ArticlesTableFilterComposer get articleId {
    final $$ArticlesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.articleId,
        referencedTable: $db.articles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ArticlesTableFilterComposer(
              $db: $db,
              $table: $db.articles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SaleLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $SaleLinesTable> {
  $$SaleLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get articleName => $composableBuilder(
      column: $table.articleName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get qty => $composableBuilder(
      column: $table.qty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get unitPriceCents => $composableBuilder(
      column: $table.unitPriceCents,
      builder: (column) => ColumnOrderings(column));

  $$SalesTableOrderingComposer get saleId {
    final $$SalesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.saleId,
        referencedTable: $db.sales,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SalesTableOrderingComposer(
              $db: $db,
              $table: $db.sales,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ArticlesTableOrderingComposer get articleId {
    final $$ArticlesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.articleId,
        referencedTable: $db.articles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ArticlesTableOrderingComposer(
              $db: $db,
              $table: $db.articles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SaleLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SaleLinesTable> {
  $$SaleLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get articleName => $composableBuilder(
      column: $table.articleName, builder: (column) => column);

  GeneratedColumn<int> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<int> get unitPriceCents => $composableBuilder(
      column: $table.unitPriceCents, builder: (column) => column);

  $$SalesTableAnnotationComposer get saleId {
    final $$SalesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.saleId,
        referencedTable: $db.sales,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SalesTableAnnotationComposer(
              $db: $db,
              $table: $db.sales,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ArticlesTableAnnotationComposer get articleId {
    final $$ArticlesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.articleId,
        referencedTable: $db.articles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ArticlesTableAnnotationComposer(
              $db: $db,
              $table: $db.articles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SaleLinesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SaleLinesTable,
    SaleLine,
    $$SaleLinesTableFilterComposer,
    $$SaleLinesTableOrderingComposer,
    $$SaleLinesTableAnnotationComposer,
    $$SaleLinesTableCreateCompanionBuilder,
    $$SaleLinesTableUpdateCompanionBuilder,
    (SaleLine, $$SaleLinesTableReferences),
    SaleLine,
    PrefetchHooks Function({bool saleId, bool articleId})> {
  $$SaleLinesTableTableManager(_$AppDatabase db, $SaleLinesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SaleLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SaleLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SaleLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> saleId = const Value.absent(),
            Value<int?> articleId = const Value.absent(),
            Value<String> articleName = const Value.absent(),
            Value<int> qty = const Value.absent(),
            Value<int> unitPriceCents = const Value.absent(),
          }) =>
              SaleLinesCompanion(
            id: id,
            saleId: saleId,
            articleId: articleId,
            articleName: articleName,
            qty: qty,
            unitPriceCents: unitPriceCents,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int saleId,
            Value<int?> articleId = const Value.absent(),
            required String articleName,
            required int qty,
            required int unitPriceCents,
          }) =>
              SaleLinesCompanion.insert(
            id: id,
            saleId: saleId,
            articleId: articleId,
            articleName: articleName,
            qty: qty,
            unitPriceCents: unitPriceCents,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$SaleLinesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({saleId = false, articleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (saleId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.saleId,
                    referencedTable:
                        $$SaleLinesTableReferences._saleIdTable(db),
                    referencedColumn:
                        $$SaleLinesTableReferences._saleIdTable(db).id,
                  ) as T;
                }
                if (articleId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.articleId,
                    referencedTable:
                        $$SaleLinesTableReferences._articleIdTable(db),
                    referencedColumn:
                        $$SaleLinesTableReferences._articleIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$SaleLinesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SaleLinesTable,
    SaleLine,
    $$SaleLinesTableFilterComposer,
    $$SaleLinesTableOrderingComposer,
    $$SaleLinesTableAnnotationComposer,
    $$SaleLinesTableCreateCompanionBuilder,
    $$SaleLinesTableUpdateCompanionBuilder,
    (SaleLine, $$SaleLinesTableReferences),
    SaleLine,
    PrefetchHooks Function({bool saleId, bool articleId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$ArticlesTableTableManager get articles =>
      $$ArticlesTableTableManager(_db, _db.articles);
  $$RoomsTableTableManager get rooms =>
      $$RoomsTableTableManager(_db, _db.rooms);
  $$SalesTableTableManager get sales =>
      $$SalesTableTableManager(_db, _db.sales);
  $$SaleLinesTableTableManager get saleLines =>
      $$SaleLinesTableTableManager(_db, _db.saleLines);
}
