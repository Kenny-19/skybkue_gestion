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
  static const VerificationMeta _isLocalDefaultMeta =
      const VerificationMeta('isLocalDefault');
  @override
  late final GeneratedColumn<bool> isLocalDefault = GeneratedColumn<bool>(
      'is_local_default', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_local_default" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _mustChangePasswordMeta =
      const VerificationMeta('mustChangePassword');
  @override
  late final GeneratedColumn<bool> mustChangePassword = GeneratedColumn<bool>(
      'must_change_password', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("must_change_password" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        fullName,
        login,
        passwordHash,
        role,
        active,
        createdAt,
        lastLogin,
        isLocalDefault,
        mustChangePassword,
        syncedAt
      ];
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
    if (data.containsKey('is_local_default')) {
      context.handle(
          _isLocalDefaultMeta,
          isLocalDefault.isAcceptableOrUnknown(
              data['is_local_default']!, _isLocalDefaultMeta));
    }
    if (data.containsKey('must_change_password')) {
      context.handle(
          _mustChangePasswordMeta,
          mustChangePassword.isAcceptableOrUnknown(
              data['must_change_password']!, _mustChangePasswordMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
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
      isLocalDefault: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_local_default'])!,
      mustChangePassword: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}must_change_password'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at']),
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

  /// Compte de secours créé à l'installation (réception / serveuse /
  /// admin). Ces comptes vivent UNIQUEMENT en local : jamais poussés
  /// vers Supabase, jamais supprimés par une synchro. Tous les autres
  /// comptes ont Supabase pour source de vérité.
  final bool isLocalDefault;

  /// Le compte porte encore le mot de passe provisoire (0000) posé à sa
  /// création : la connexion exige un changement avant d'ouvrir l'app.
  ///
  /// Sans ce drapeau, un défaut universel connu de tous serait une porte
  /// ouverte. C'est lui qui rend le provisoire acceptable.
  final bool mustChangePassword;

  /// Dernière synchronisation réussie depuis Supabase. Null → compte
  /// jamais synchronisé (compte de secours, ou créé hors ligne).
  final DateTime? syncedAt;
  const User(
      {required this.id,
      required this.fullName,
      required this.login,
      required this.passwordHash,
      required this.role,
      required this.active,
      required this.createdAt,
      this.lastLogin,
      required this.isLocalDefault,
      required this.mustChangePassword,
      this.syncedAt});
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
    map['is_local_default'] = Variable<bool>(isLocalDefault);
    map['must_change_password'] = Variable<bool>(mustChangePassword);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
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
      isLocalDefault: Value(isLocalDefault),
      mustChangePassword: Value(mustChangePassword),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
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
      isLocalDefault: serializer.fromJson<bool>(json['isLocalDefault']),
      mustChangePassword: serializer.fromJson<bool>(json['mustChangePassword']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
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
      'isLocalDefault': serializer.toJson<bool>(isLocalDefault),
      'mustChangePassword': serializer.toJson<bool>(mustChangePassword),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
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
          Value<DateTime?> lastLogin = const Value.absent(),
          bool? isLocalDefault,
          bool? mustChangePassword,
          Value<DateTime?> syncedAt = const Value.absent()}) =>
      User(
        id: id ?? this.id,
        fullName: fullName ?? this.fullName,
        login: login ?? this.login,
        passwordHash: passwordHash ?? this.passwordHash,
        role: role ?? this.role,
        active: active ?? this.active,
        createdAt: createdAt ?? this.createdAt,
        lastLogin: lastLogin.present ? lastLogin.value : this.lastLogin,
        isLocalDefault: isLocalDefault ?? this.isLocalDefault,
        mustChangePassword: mustChangePassword ?? this.mustChangePassword,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
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
      isLocalDefault: data.isLocalDefault.present
          ? data.isLocalDefault.value
          : this.isLocalDefault,
      mustChangePassword: data.mustChangePassword.present
          ? data.mustChangePassword.value
          : this.mustChangePassword,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
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
          ..write('lastLogin: $lastLogin, ')
          ..write('isLocalDefault: $isLocalDefault, ')
          ..write('mustChangePassword: $mustChangePassword, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      fullName,
      login,
      passwordHash,
      role,
      active,
      createdAt,
      lastLogin,
      isLocalDefault,
      mustChangePassword,
      syncedAt);
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
          other.lastLogin == this.lastLogin &&
          other.isLocalDefault == this.isLocalDefault &&
          other.mustChangePassword == this.mustChangePassword &&
          other.syncedAt == this.syncedAt);
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
  final Value<bool> isLocalDefault;
  final Value<bool> mustChangePassword;
  final Value<DateTime?> syncedAt;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.fullName = const Value.absent(),
    this.login = const Value.absent(),
    this.passwordHash = const Value.absent(),
    this.role = const Value.absent(),
    this.active = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastLogin = const Value.absent(),
    this.isLocalDefault = const Value.absent(),
    this.mustChangePassword = const Value.absent(),
    this.syncedAt = const Value.absent(),
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
    this.isLocalDefault = const Value.absent(),
    this.mustChangePassword = const Value.absent(),
    this.syncedAt = const Value.absent(),
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
    Expression<bool>? isLocalDefault,
    Expression<bool>? mustChangePassword,
    Expression<DateTime>? syncedAt,
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
      if (isLocalDefault != null) 'is_local_default': isLocalDefault,
      if (mustChangePassword != null)
        'must_change_password': mustChangePassword,
      if (syncedAt != null) 'synced_at': syncedAt,
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
      Value<DateTime?>? lastLogin,
      Value<bool>? isLocalDefault,
      Value<bool>? mustChangePassword,
      Value<DateTime?>? syncedAt}) {
    return UsersCompanion(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      login: login ?? this.login,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      isLocalDefault: isLocalDefault ?? this.isLocalDefault,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      syncedAt: syncedAt ?? this.syncedAt,
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
    if (isLocalDefault.present) {
      map['is_local_default'] = Variable<bool>(isLocalDefault.value);
    }
    if (mustChangePassword.present) {
      map['must_change_password'] = Variable<bool>(mustChangePassword.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
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
          ..write('lastLogin: $lastLogin, ')
          ..write('isLocalDefault: $isLocalDefault, ')
          ..write('mustChangePassword: $mustChangePassword, ')
          ..write('syncedAt: $syncedAt')
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
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
      'uid', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
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
        threshold,
        uid
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
    if (data.containsKey('uid')) {
      context.handle(
          _uidMeta, uid.isAcceptableOrUnknown(data['uid']!, _uidMeta));
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
      uid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uid']),
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

  /// Identité de l'article sur tous les postes (v28), déduite du nom à la
  /// création (cf. core/identite.dart, uidArticle). Le serveur et les
  /// mouvements de stock le reconnaissent par là, plus par son numéro
  /// local — qui désignait parfois un autre produit sur le serveur.
  final String? uid;
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
      required this.threshold,
      this.uid});
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
    if (!nullToAbsent || uid != null) {
      map['uid'] = Variable<String>(uid);
    }
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
      uid: uid == null && nullToAbsent ? const Value.absent() : Value(uid),
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
      uid: serializer.fromJson<String?>(json['uid']),
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
      'uid': serializer.toJson<String?>(uid),
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
          int? threshold,
          Value<String?> uid = const Value.absent()}) =>
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
        uid: uid.present ? uid.value : this.uid,
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
      uid: data.uid.present ? data.uid.value : this.uid,
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
          ..write('threshold: $threshold, ')
          ..write('uid: $uid')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, priceCents, category, active,
      imagePath, trackStock, unit, stockQty, threshold, uid);
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
          other.threshold == this.threshold &&
          other.uid == this.uid);
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
  final Value<String?> uid;
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
    this.uid = const Value.absent(),
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
    this.uid = const Value.absent(),
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
    Expression<String>? uid,
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
      if (uid != null) 'uid': uid,
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
      Value<int>? threshold,
      Value<String?>? uid}) {
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
      uid: uid ?? this.uid,
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
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
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
          ..write('threshold: $threshold, ')
          ..write('uid: $uid')
          ..write(')'))
        .toString();
  }
}

class $PayersTable extends Payers with TableInfo<$PayersTable, Payer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PayersTable(this.attachedDatabase, [this._alias]);
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
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 200),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<DbPayerType, int> type =
      GeneratedColumn<int>('type', aliasedName, false,
              type: DriftSqlType.int,
              requiredDuringInsert: false,
              defaultValue: const Constant(1))
          .withConverter<DbPayerType>($PayersTable.$convertertype);
  static const VerificationMeta _taxIdMeta = const VerificationMeta('taxId');
  @override
  late final GeneratedColumn<String> taxId = GeneratedColumn<String>(
      'tax_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _addressMeta =
      const VerificationMeta('address');
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
      'address', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contactMeta =
      const VerificationMeta('contact');
  @override
  late final GeneratedColumn<String> contact = GeneratedColumn<String>(
      'contact', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, type, taxId, address, contact, notes, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payers';
  @override
  VerificationContext validateIntegrity(Insertable<Payer> instance,
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
    if (data.containsKey('tax_id')) {
      context.handle(
          _taxIdMeta, taxId.isAcceptableOrUnknown(data['tax_id']!, _taxIdMeta));
    }
    if (data.containsKey('address')) {
      context.handle(_addressMeta,
          address.isAcceptableOrUnknown(data['address']!, _addressMeta));
    }
    if (data.containsKey('contact')) {
      context.handle(_contactMeta,
          contact.isAcceptableOrUnknown(data['contact']!, _contactMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Payer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Payer(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      type: $PayersTable.$convertertype.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}type'])!),
      taxId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tax_id']),
      address: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}address']),
      contact: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}contact']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $PayersTable createAlias(String alias) {
    return $PayersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DbPayerType, int, int> $convertertype =
      const EnumIndexConverter<DbPayerType>(DbPayerType.values);
}

class Payer extends DataClass implements Insertable<Payer> {
  final int id;
  final String name;
  final DbPayerType type;
  final String? taxId;
  final String? address;
  final String? contact;
  final String? notes;
  final DateTime createdAt;
  const Payer(
      {required this.id,
      required this.name,
      required this.type,
      this.taxId,
      this.address,
      this.contact,
      this.notes,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    {
      map['type'] = Variable<int>($PayersTable.$convertertype.toSql(type));
    }
    if (!nullToAbsent || taxId != null) {
      map['tax_id'] = Variable<String>(taxId);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || contact != null) {
      map['contact'] = Variable<String>(contact);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PayersCompanion toCompanion(bool nullToAbsent) {
    return PayersCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      taxId:
          taxId == null && nullToAbsent ? const Value.absent() : Value(taxId),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      contact: contact == null && nullToAbsent
          ? const Value.absent()
          : Value(contact),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory Payer.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Payer(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: $PayersTable.$convertertype
          .fromJson(serializer.fromJson<int>(json['type'])),
      taxId: serializer.fromJson<String?>(json['taxId']),
      address: serializer.fromJson<String?>(json['address']),
      contact: serializer.fromJson<String?>(json['contact']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<int>($PayersTable.$convertertype.toJson(type)),
      'taxId': serializer.toJson<String?>(taxId),
      'address': serializer.toJson<String?>(address),
      'contact': serializer.toJson<String?>(contact),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Payer copyWith(
          {int? id,
          String? name,
          DbPayerType? type,
          Value<String?> taxId = const Value.absent(),
          Value<String?> address = const Value.absent(),
          Value<String?> contact = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          DateTime? createdAt}) =>
      Payer(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        taxId: taxId.present ? taxId.value : this.taxId,
        address: address.present ? address.value : this.address,
        contact: contact.present ? contact.value : this.contact,
        notes: notes.present ? notes.value : this.notes,
        createdAt: createdAt ?? this.createdAt,
      );
  Payer copyWithCompanion(PayersCompanion data) {
    return Payer(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      taxId: data.taxId.present ? data.taxId.value : this.taxId,
      address: data.address.present ? data.address.value : this.address,
      contact: data.contact.present ? data.contact.value : this.contact,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Payer(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('taxId: $taxId, ')
          ..write('address: $address, ')
          ..write('contact: $contact, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, type, taxId, address, contact, notes, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Payer &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.taxId == this.taxId &&
          other.address == this.address &&
          other.contact == this.contact &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class PayersCompanion extends UpdateCompanion<Payer> {
  final Value<int> id;
  final Value<String> name;
  final Value<DbPayerType> type;
  final Value<String?> taxId;
  final Value<String?> address;
  final Value<String?> contact;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  const PayersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.taxId = const Value.absent(),
    this.address = const Value.absent(),
    this.contact = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PayersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.type = const Value.absent(),
    this.taxId = const Value.absent(),
    this.address = const Value.absent(),
    this.contact = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Payer> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? type,
    Expression<String>? taxId,
    Expression<String>? address,
    Expression<String>? contact,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (taxId != null) 'tax_id': taxId,
      if (address != null) 'address': address,
      if (contact != null) 'contact': contact,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PayersCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<DbPayerType>? type,
      Value<String?>? taxId,
      Value<String?>? address,
      Value<String?>? contact,
      Value<String?>? notes,
      Value<DateTime>? createdAt}) {
    return PayersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      taxId: taxId ?? this.taxId,
      address: address ?? this.address,
      contact: contact ?? this.contact,
      notes: notes ?? this.notes,
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
    if (type.present) {
      map['type'] =
          Variable<int>($PayersTable.$convertertype.toSql(type.value));
    }
    if (taxId.present) {
      map['tax_id'] = Variable<String>(taxId.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (contact.present) {
      map['contact'] = Variable<String>(contact.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PayersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('taxId: $taxId, ')
          ..write('address: $address, ')
          ..write('contact: $contact, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $StaysTable extends Stays with TableInfo<$StaysTable, Stay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _receiptNumberMeta =
      const VerificationMeta('receiptNumber');
  @override
  late final GeneratedColumn<String> receiptNumber = GeneratedColumn<String>(
      'receipt_number', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 40),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _reservationNumberMeta =
      const VerificationMeta('reservationNumber');
  @override
  late final GeneratedColumn<String> reservationNumber =
      GeneratedColumn<String>('reservation_number', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _generatedAtMeta =
      const VerificationMeta('generatedAt');
  @override
  late final GeneratedColumn<DateTime> generatedAt = GeneratedColumn<DateTime>(
      'generated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _checkinAtMeta =
      const VerificationMeta('checkinAt');
  @override
  late final GeneratedColumn<DateTime> checkinAt = GeneratedColumn<DateTime>(
      'checkin_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _checkoutAtMeta =
      const VerificationMeta('checkoutAt');
  @override
  late final GeneratedColumn<DateTime> checkoutAt = GeneratedColumn<DateTime>(
      'checkout_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _guestFullNameMeta =
      const VerificationMeta('guestFullName');
  @override
  late final GeneratedColumn<String> guestFullName = GeneratedColumn<String>(
      'guest_full_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _guestNationalityMeta =
      const VerificationMeta('guestNationality');
  @override
  late final GeneratedColumn<String> guestNationality = GeneratedColumn<String>(
      'guest_nationality', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _guestPhoneMeta =
      const VerificationMeta('guestPhone');
  @override
  late final GeneratedColumn<String> guestPhone = GeneratedColumn<String>(
      'guest_phone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _guestEmailMeta =
      const VerificationMeta('guestEmail');
  @override
  late final GeneratedColumn<String> guestEmail = GeneratedColumn<String>(
      'guest_email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _payerNameMeta =
      const VerificationMeta('payerName');
  @override
  late final GeneratedColumn<String> payerName = GeneratedColumn<String>(
      'payer_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _payerTaxIdMeta =
      const VerificationMeta('payerTaxId');
  @override
  late final GeneratedColumn<String> payerTaxId = GeneratedColumn<String>(
      'payer_tax_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _payerAddressMeta =
      const VerificationMeta('payerAddress');
  @override
  late final GeneratedColumn<String> payerAddress = GeneratedColumn<String>(
      'payer_address', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _payerContactMeta =
      const VerificationMeta('payerContact');
  @override
  late final GeneratedColumn<String> payerContact = GeneratedColumn<String>(
      'payer_contact', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _subtotalCentsMeta =
      const VerificationMeta('subtotalCents');
  @override
  late final GeneratedColumn<int> subtotalCents = GeneratedColumn<int>(
      'subtotal_cents', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _remiseCentsMeta =
      const VerificationMeta('remiseCents');
  @override
  late final GeneratedColumn<int> remiseCents = GeneratedColumn<int>(
      'remise_cents', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _remiseKindMeta =
      const VerificationMeta('remiseKind');
  @override
  late final GeneratedColumn<int> remiseKind = GeneratedColumn<int>(
      'remise_kind', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _remiseValueMeta =
      const VerificationMeta('remiseValue');
  @override
  late final GeneratedColumn<int> remiseValue = GeneratedColumn<int>(
      'remise_value', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _remiseBaseMeta =
      const VerificationMeta('remiseBase');
  @override
  late final GeneratedColumn<int> remiseBase = GeneratedColumn<int>(
      'remise_base', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _remiseReasonMeta =
      const VerificationMeta('remiseReason');
  @override
  late final GeneratedColumn<String> remiseReason = GeneratedColumn<String>(
      'remise_reason', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _acompteFcCentsMeta =
      const VerificationMeta('acompteFcCents');
  @override
  late final GeneratedColumn<int> acompteFcCents = GeneratedColumn<int>(
      'acompte_fc_cents', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _acompteUsdCentsMeta =
      const VerificationMeta('acompteUsdCents');
  @override
  late final GeneratedColumn<int> acompteUsdCents = GeneratedColumn<int>(
      'acompte_usd_cents', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _fcPerUsdCentsMeta =
      const VerificationMeta('fcPerUsdCents');
  @override
  late final GeneratedColumn<int> fcPerUsdCents = GeneratedColumn<int>(
      'fc_per_usd_cents', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _paymentModeMeta =
      const VerificationMeta('paymentMode');
  @override
  late final GeneratedColumn<int> paymentMode = GeneratedColumn<int>(
      'payment_mode', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _stayGroupMeta =
      const VerificationMeta('stayGroup');
  @override
  late final GeneratedColumn<String> stayGroup = GeneratedColumn<String>(
      'stay_group', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _serverLoginMeta =
      const VerificationMeta('serverLogin');
  @override
  late final GeneratedColumn<String> serverLogin = GeneratedColumn<String>(
      'server_login', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _extrasJsonMeta =
      const VerificationMeta('extrasJson');
  @override
  late final GeneratedColumn<String> extrasJson = GeneratedColumn<String>(
      'extras_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _clientVisitsAtCheckoutMeta =
      const VerificationMeta('clientVisitsAtCheckout');
  @override
  late final GeneratedColumn<int> clientVisitsAtCheckout = GeneratedColumn<int>(
      'client_visits_at_checkout', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
      'uid', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      clientDefault: nouvelUid);
  @override
  late final GeneratedColumnWithTypeConverter<DbStayStatus, int> statut =
      GeneratedColumn<int>('statut', aliasedName, false,
              type: DriftSqlType.int,
              requiredDuringInsert: false,
              defaultValue: Constant(DbStayStatus.facture.index))
          .withConverter<DbStayStatus>($StaysTable.$converterstatut);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        receiptNumber,
        reservationNumber,
        generatedAt,
        checkinAt,
        checkoutAt,
        guestFullName,
        guestNationality,
        guestPhone,
        guestEmail,
        payerName,
        payerTaxId,
        payerAddress,
        payerContact,
        subtotalCents,
        remiseCents,
        remiseKind,
        remiseValue,
        remiseBase,
        remiseReason,
        acompteFcCents,
        acompteUsdCents,
        fcPerUsdCents,
        paymentMode,
        stayGroup,
        serverLogin,
        note,
        extrasJson,
        clientVisitsAtCheckout,
        uid,
        statut
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stays';
  @override
  VerificationContext validateIntegrity(Insertable<Stay> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('receipt_number')) {
      context.handle(
          _receiptNumberMeta,
          receiptNumber.isAcceptableOrUnknown(
              data['receipt_number']!, _receiptNumberMeta));
    } else if (isInserting) {
      context.missing(_receiptNumberMeta);
    }
    if (data.containsKey('reservation_number')) {
      context.handle(
          _reservationNumberMeta,
          reservationNumber.isAcceptableOrUnknown(
              data['reservation_number']!, _reservationNumberMeta));
    }
    if (data.containsKey('generated_at')) {
      context.handle(
          _generatedAtMeta,
          generatedAt.isAcceptableOrUnknown(
              data['generated_at']!, _generatedAtMeta));
    }
    if (data.containsKey('checkin_at')) {
      context.handle(_checkinAtMeta,
          checkinAt.isAcceptableOrUnknown(data['checkin_at']!, _checkinAtMeta));
    } else if (isInserting) {
      context.missing(_checkinAtMeta);
    }
    if (data.containsKey('checkout_at')) {
      context.handle(
          _checkoutAtMeta,
          checkoutAt.isAcceptableOrUnknown(
              data['checkout_at']!, _checkoutAtMeta));
    } else if (isInserting) {
      context.missing(_checkoutAtMeta);
    }
    if (data.containsKey('guest_full_name')) {
      context.handle(
          _guestFullNameMeta,
          guestFullName.isAcceptableOrUnknown(
              data['guest_full_name']!, _guestFullNameMeta));
    } else if (isInserting) {
      context.missing(_guestFullNameMeta);
    }
    if (data.containsKey('guest_nationality')) {
      context.handle(
          _guestNationalityMeta,
          guestNationality.isAcceptableOrUnknown(
              data['guest_nationality']!, _guestNationalityMeta));
    }
    if (data.containsKey('guest_phone')) {
      context.handle(
          _guestPhoneMeta,
          guestPhone.isAcceptableOrUnknown(
              data['guest_phone']!, _guestPhoneMeta));
    }
    if (data.containsKey('guest_email')) {
      context.handle(
          _guestEmailMeta,
          guestEmail.isAcceptableOrUnknown(
              data['guest_email']!, _guestEmailMeta));
    }
    if (data.containsKey('payer_name')) {
      context.handle(_payerNameMeta,
          payerName.isAcceptableOrUnknown(data['payer_name']!, _payerNameMeta));
    }
    if (data.containsKey('payer_tax_id')) {
      context.handle(
          _payerTaxIdMeta,
          payerTaxId.isAcceptableOrUnknown(
              data['payer_tax_id']!, _payerTaxIdMeta));
    }
    if (data.containsKey('payer_address')) {
      context.handle(
          _payerAddressMeta,
          payerAddress.isAcceptableOrUnknown(
              data['payer_address']!, _payerAddressMeta));
    }
    if (data.containsKey('payer_contact')) {
      context.handle(
          _payerContactMeta,
          payerContact.isAcceptableOrUnknown(
              data['payer_contact']!, _payerContactMeta));
    }
    if (data.containsKey('subtotal_cents')) {
      context.handle(
          _subtotalCentsMeta,
          subtotalCents.isAcceptableOrUnknown(
              data['subtotal_cents']!, _subtotalCentsMeta));
    } else if (isInserting) {
      context.missing(_subtotalCentsMeta);
    }
    if (data.containsKey('remise_cents')) {
      context.handle(
          _remiseCentsMeta,
          remiseCents.isAcceptableOrUnknown(
              data['remise_cents']!, _remiseCentsMeta));
    }
    if (data.containsKey('remise_kind')) {
      context.handle(
          _remiseKindMeta,
          remiseKind.isAcceptableOrUnknown(
              data['remise_kind']!, _remiseKindMeta));
    }
    if (data.containsKey('remise_value')) {
      context.handle(
          _remiseValueMeta,
          remiseValue.isAcceptableOrUnknown(
              data['remise_value']!, _remiseValueMeta));
    }
    if (data.containsKey('remise_base')) {
      context.handle(
          _remiseBaseMeta,
          remiseBase.isAcceptableOrUnknown(
              data['remise_base']!, _remiseBaseMeta));
    }
    if (data.containsKey('remise_reason')) {
      context.handle(
          _remiseReasonMeta,
          remiseReason.isAcceptableOrUnknown(
              data['remise_reason']!, _remiseReasonMeta));
    }
    if (data.containsKey('acompte_fc_cents')) {
      context.handle(
          _acompteFcCentsMeta,
          acompteFcCents.isAcceptableOrUnknown(
              data['acompte_fc_cents']!, _acompteFcCentsMeta));
    }
    if (data.containsKey('acompte_usd_cents')) {
      context.handle(
          _acompteUsdCentsMeta,
          acompteUsdCents.isAcceptableOrUnknown(
              data['acompte_usd_cents']!, _acompteUsdCentsMeta));
    }
    if (data.containsKey('fc_per_usd_cents')) {
      context.handle(
          _fcPerUsdCentsMeta,
          fcPerUsdCents.isAcceptableOrUnknown(
              data['fc_per_usd_cents']!, _fcPerUsdCentsMeta));
    }
    if (data.containsKey('payment_mode')) {
      context.handle(
          _paymentModeMeta,
          paymentMode.isAcceptableOrUnknown(
              data['payment_mode']!, _paymentModeMeta));
    }
    if (data.containsKey('stay_group')) {
      context.handle(_stayGroupMeta,
          stayGroup.isAcceptableOrUnknown(data['stay_group']!, _stayGroupMeta));
    }
    if (data.containsKey('server_login')) {
      context.handle(
          _serverLoginMeta,
          serverLogin.isAcceptableOrUnknown(
              data['server_login']!, _serverLoginMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('extras_json')) {
      context.handle(
          _extrasJsonMeta,
          extrasJson.isAcceptableOrUnknown(
              data['extras_json']!, _extrasJsonMeta));
    }
    if (data.containsKey('client_visits_at_checkout')) {
      context.handle(
          _clientVisitsAtCheckoutMeta,
          clientVisitsAtCheckout.isAcceptableOrUnknown(
              data['client_visits_at_checkout']!, _clientVisitsAtCheckoutMeta));
    }
    if (data.containsKey('uid')) {
      context.handle(
          _uidMeta, uid.isAcceptableOrUnknown(data['uid']!, _uidMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Stay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Stay(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      receiptNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}receipt_number'])!,
      reservationNumber: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}reservation_number']),
      generatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}generated_at'])!,
      checkinAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}checkin_at'])!,
      checkoutAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}checkout_at'])!,
      guestFullName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}guest_full_name'])!,
      guestNationality: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}guest_nationality']),
      guestPhone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}guest_phone']),
      guestEmail: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}guest_email']),
      payerName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payer_name']),
      payerTaxId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payer_tax_id']),
      payerAddress: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payer_address']),
      payerContact: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payer_contact']),
      subtotalCents: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}subtotal_cents'])!,
      remiseCents: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}remise_cents'])!,
      remiseKind: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}remise_kind'])!,
      remiseValue: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}remise_value'])!,
      remiseBase: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}remise_base'])!,
      remiseReason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remise_reason']),
      acompteFcCents: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}acompte_fc_cents'])!,
      acompteUsdCents: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}acompte_usd_cents'])!,
      fcPerUsdCents: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}fc_per_usd_cents'])!,
      paymentMode: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}payment_mode'])!,
      stayGroup: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}stay_group']),
      serverLogin: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_login']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      extrasJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}extras_json'])!,
      clientVisitsAtCheckout: attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}client_visits_at_checkout'])!,
      uid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uid']),
      statut: $StaysTable.$converterstatut.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}statut'])!),
    );
  }

  @override
  $StaysTable createAlias(String alias) {
    return $StaysTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DbStayStatus, int, int> $converterstatut =
      const EnumIndexConverter<DbStayStatus>(DbStayStatus.values);
}

class Stay extends DataClass implements Insertable<Stay> {
  final int id;
  final String receiptNumber;
  final String? reservationNumber;
  final DateTime generatedAt;
  final DateTime checkinAt;
  final DateTime checkoutAt;
  final String guestFullName;
  final String? guestNationality;
  final String? guestPhone;
  final String? guestEmail;
  final String? payerName;
  final String? payerTaxId;
  final String? payerAddress;
  final String? payerContact;
  final int subtotalCents;

  /// Montant de la remise effectivement déduite (cents FC). Reste la
  /// source de vérité comptable — les 4 colonnes qui suivent ne servent
  /// qu'à expliquer *comment* ce montant a été obtenu.
  final int remiseCents;

  /// index de DiscountKind : 0 = montant fixe, 1 = pourcentage.
  final int remiseKind;

  /// Cents FC si remiseKind=0, centièmes de % si remiseKind=1 (1000 = 10 %).
  final int remiseValue;

  /// index de DiscountBase : 0 = hébergement seul, 1 = total avec extras.
  final int remiseBase;

  /// Motif du geste commercial ("Client fidèle", "Accord société"…).
  final String? remiseReason;
  final int acompteFcCents;
  final int acompteUsdCents;

  /// Taux FC pour 1 USD au moment du check-out, × 100.
  ///
  /// Figé, et c'est tout l'enjeu. `Currency.rate` est une valeur unique
  /// et COURANTE : une facture émise à 2300 et réimprimée à 2600
  /// annoncerait un total en dollars différent de celui que le client a
  /// payé. Un entier plutôt qu'un flottant : un taux est une donnée
  /// comptable, il ne s'arrondit pas au hasard des divisions.
  ///
  /// 0 = séjour antérieur à la bascule en dollars ; on retombe alors sur
  /// le taux courant, faute de mieux, et l'écran le dit.
  final int fcPerUsdCents;
  final int paymentMode;
  final String? stayGroup;
  final String? serverLogin;
  final String? note;
  final String extrasJson;
  final int clientVisitsAtCheckout;

  /// Identité du séjour sur tous les postes (même raison que les ventes :
  /// le serveur rangeait les séjours par numéro local).
  final String? uid;

  /// Où en est le séjour. Les séjours d'avant la v27 n'existaient qu'une
  /// fois facturés : « facture » par défaut.
  final DbStayStatus statut;
  const Stay(
      {required this.id,
      required this.receiptNumber,
      this.reservationNumber,
      required this.generatedAt,
      required this.checkinAt,
      required this.checkoutAt,
      required this.guestFullName,
      this.guestNationality,
      this.guestPhone,
      this.guestEmail,
      this.payerName,
      this.payerTaxId,
      this.payerAddress,
      this.payerContact,
      required this.subtotalCents,
      required this.remiseCents,
      required this.remiseKind,
      required this.remiseValue,
      required this.remiseBase,
      this.remiseReason,
      required this.acompteFcCents,
      required this.acompteUsdCents,
      required this.fcPerUsdCents,
      required this.paymentMode,
      this.stayGroup,
      this.serverLogin,
      this.note,
      required this.extrasJson,
      required this.clientVisitsAtCheckout,
      this.uid,
      required this.statut});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['receipt_number'] = Variable<String>(receiptNumber);
    if (!nullToAbsent || reservationNumber != null) {
      map['reservation_number'] = Variable<String>(reservationNumber);
    }
    map['generated_at'] = Variable<DateTime>(generatedAt);
    map['checkin_at'] = Variable<DateTime>(checkinAt);
    map['checkout_at'] = Variable<DateTime>(checkoutAt);
    map['guest_full_name'] = Variable<String>(guestFullName);
    if (!nullToAbsent || guestNationality != null) {
      map['guest_nationality'] = Variable<String>(guestNationality);
    }
    if (!nullToAbsent || guestPhone != null) {
      map['guest_phone'] = Variable<String>(guestPhone);
    }
    if (!nullToAbsent || guestEmail != null) {
      map['guest_email'] = Variable<String>(guestEmail);
    }
    if (!nullToAbsent || payerName != null) {
      map['payer_name'] = Variable<String>(payerName);
    }
    if (!nullToAbsent || payerTaxId != null) {
      map['payer_tax_id'] = Variable<String>(payerTaxId);
    }
    if (!nullToAbsent || payerAddress != null) {
      map['payer_address'] = Variable<String>(payerAddress);
    }
    if (!nullToAbsent || payerContact != null) {
      map['payer_contact'] = Variable<String>(payerContact);
    }
    map['subtotal_cents'] = Variable<int>(subtotalCents);
    map['remise_cents'] = Variable<int>(remiseCents);
    map['remise_kind'] = Variable<int>(remiseKind);
    map['remise_value'] = Variable<int>(remiseValue);
    map['remise_base'] = Variable<int>(remiseBase);
    if (!nullToAbsent || remiseReason != null) {
      map['remise_reason'] = Variable<String>(remiseReason);
    }
    map['acompte_fc_cents'] = Variable<int>(acompteFcCents);
    map['acompte_usd_cents'] = Variable<int>(acompteUsdCents);
    map['fc_per_usd_cents'] = Variable<int>(fcPerUsdCents);
    map['payment_mode'] = Variable<int>(paymentMode);
    if (!nullToAbsent || stayGroup != null) {
      map['stay_group'] = Variable<String>(stayGroup);
    }
    if (!nullToAbsent || serverLogin != null) {
      map['server_login'] = Variable<String>(serverLogin);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['extras_json'] = Variable<String>(extrasJson);
    map['client_visits_at_checkout'] = Variable<int>(clientVisitsAtCheckout);
    if (!nullToAbsent || uid != null) {
      map['uid'] = Variable<String>(uid);
    }
    {
      map['statut'] = Variable<int>($StaysTable.$converterstatut.toSql(statut));
    }
    return map;
  }

  StaysCompanion toCompanion(bool nullToAbsent) {
    return StaysCompanion(
      id: Value(id),
      receiptNumber: Value(receiptNumber),
      reservationNumber: reservationNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(reservationNumber),
      generatedAt: Value(generatedAt),
      checkinAt: Value(checkinAt),
      checkoutAt: Value(checkoutAt),
      guestFullName: Value(guestFullName),
      guestNationality: guestNationality == null && nullToAbsent
          ? const Value.absent()
          : Value(guestNationality),
      guestPhone: guestPhone == null && nullToAbsent
          ? const Value.absent()
          : Value(guestPhone),
      guestEmail: guestEmail == null && nullToAbsent
          ? const Value.absent()
          : Value(guestEmail),
      payerName: payerName == null && nullToAbsent
          ? const Value.absent()
          : Value(payerName),
      payerTaxId: payerTaxId == null && nullToAbsent
          ? const Value.absent()
          : Value(payerTaxId),
      payerAddress: payerAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(payerAddress),
      payerContact: payerContact == null && nullToAbsent
          ? const Value.absent()
          : Value(payerContact),
      subtotalCents: Value(subtotalCents),
      remiseCents: Value(remiseCents),
      remiseKind: Value(remiseKind),
      remiseValue: Value(remiseValue),
      remiseBase: Value(remiseBase),
      remiseReason: remiseReason == null && nullToAbsent
          ? const Value.absent()
          : Value(remiseReason),
      acompteFcCents: Value(acompteFcCents),
      acompteUsdCents: Value(acompteUsdCents),
      fcPerUsdCents: Value(fcPerUsdCents),
      paymentMode: Value(paymentMode),
      stayGroup: stayGroup == null && nullToAbsent
          ? const Value.absent()
          : Value(stayGroup),
      serverLogin: serverLogin == null && nullToAbsent
          ? const Value.absent()
          : Value(serverLogin),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      extrasJson: Value(extrasJson),
      clientVisitsAtCheckout: Value(clientVisitsAtCheckout),
      uid: uid == null && nullToAbsent ? const Value.absent() : Value(uid),
      statut: Value(statut),
    );
  }

  factory Stay.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Stay(
      id: serializer.fromJson<int>(json['id']),
      receiptNumber: serializer.fromJson<String>(json['receiptNumber']),
      reservationNumber:
          serializer.fromJson<String?>(json['reservationNumber']),
      generatedAt: serializer.fromJson<DateTime>(json['generatedAt']),
      checkinAt: serializer.fromJson<DateTime>(json['checkinAt']),
      checkoutAt: serializer.fromJson<DateTime>(json['checkoutAt']),
      guestFullName: serializer.fromJson<String>(json['guestFullName']),
      guestNationality: serializer.fromJson<String?>(json['guestNationality']),
      guestPhone: serializer.fromJson<String?>(json['guestPhone']),
      guestEmail: serializer.fromJson<String?>(json['guestEmail']),
      payerName: serializer.fromJson<String?>(json['payerName']),
      payerTaxId: serializer.fromJson<String?>(json['payerTaxId']),
      payerAddress: serializer.fromJson<String?>(json['payerAddress']),
      payerContact: serializer.fromJson<String?>(json['payerContact']),
      subtotalCents: serializer.fromJson<int>(json['subtotalCents']),
      remiseCents: serializer.fromJson<int>(json['remiseCents']),
      remiseKind: serializer.fromJson<int>(json['remiseKind']),
      remiseValue: serializer.fromJson<int>(json['remiseValue']),
      remiseBase: serializer.fromJson<int>(json['remiseBase']),
      remiseReason: serializer.fromJson<String?>(json['remiseReason']),
      acompteFcCents: serializer.fromJson<int>(json['acompteFcCents']),
      acompteUsdCents: serializer.fromJson<int>(json['acompteUsdCents']),
      fcPerUsdCents: serializer.fromJson<int>(json['fcPerUsdCents']),
      paymentMode: serializer.fromJson<int>(json['paymentMode']),
      stayGroup: serializer.fromJson<String?>(json['stayGroup']),
      serverLogin: serializer.fromJson<String?>(json['serverLogin']),
      note: serializer.fromJson<String?>(json['note']),
      extrasJson: serializer.fromJson<String>(json['extrasJson']),
      clientVisitsAtCheckout:
          serializer.fromJson<int>(json['clientVisitsAtCheckout']),
      uid: serializer.fromJson<String?>(json['uid']),
      statut: $StaysTable.$converterstatut
          .fromJson(serializer.fromJson<int>(json['statut'])),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'receiptNumber': serializer.toJson<String>(receiptNumber),
      'reservationNumber': serializer.toJson<String?>(reservationNumber),
      'generatedAt': serializer.toJson<DateTime>(generatedAt),
      'checkinAt': serializer.toJson<DateTime>(checkinAt),
      'checkoutAt': serializer.toJson<DateTime>(checkoutAt),
      'guestFullName': serializer.toJson<String>(guestFullName),
      'guestNationality': serializer.toJson<String?>(guestNationality),
      'guestPhone': serializer.toJson<String?>(guestPhone),
      'guestEmail': serializer.toJson<String?>(guestEmail),
      'payerName': serializer.toJson<String?>(payerName),
      'payerTaxId': serializer.toJson<String?>(payerTaxId),
      'payerAddress': serializer.toJson<String?>(payerAddress),
      'payerContact': serializer.toJson<String?>(payerContact),
      'subtotalCents': serializer.toJson<int>(subtotalCents),
      'remiseCents': serializer.toJson<int>(remiseCents),
      'remiseKind': serializer.toJson<int>(remiseKind),
      'remiseValue': serializer.toJson<int>(remiseValue),
      'remiseBase': serializer.toJson<int>(remiseBase),
      'remiseReason': serializer.toJson<String?>(remiseReason),
      'acompteFcCents': serializer.toJson<int>(acompteFcCents),
      'acompteUsdCents': serializer.toJson<int>(acompteUsdCents),
      'fcPerUsdCents': serializer.toJson<int>(fcPerUsdCents),
      'paymentMode': serializer.toJson<int>(paymentMode),
      'stayGroup': serializer.toJson<String?>(stayGroup),
      'serverLogin': serializer.toJson<String?>(serverLogin),
      'note': serializer.toJson<String?>(note),
      'extrasJson': serializer.toJson<String>(extrasJson),
      'clientVisitsAtCheckout': serializer.toJson<int>(clientVisitsAtCheckout),
      'uid': serializer.toJson<String?>(uid),
      'statut':
          serializer.toJson<int>($StaysTable.$converterstatut.toJson(statut)),
    };
  }

  Stay copyWith(
          {int? id,
          String? receiptNumber,
          Value<String?> reservationNumber = const Value.absent(),
          DateTime? generatedAt,
          DateTime? checkinAt,
          DateTime? checkoutAt,
          String? guestFullName,
          Value<String?> guestNationality = const Value.absent(),
          Value<String?> guestPhone = const Value.absent(),
          Value<String?> guestEmail = const Value.absent(),
          Value<String?> payerName = const Value.absent(),
          Value<String?> payerTaxId = const Value.absent(),
          Value<String?> payerAddress = const Value.absent(),
          Value<String?> payerContact = const Value.absent(),
          int? subtotalCents,
          int? remiseCents,
          int? remiseKind,
          int? remiseValue,
          int? remiseBase,
          Value<String?> remiseReason = const Value.absent(),
          int? acompteFcCents,
          int? acompteUsdCents,
          int? fcPerUsdCents,
          int? paymentMode,
          Value<String?> stayGroup = const Value.absent(),
          Value<String?> serverLogin = const Value.absent(),
          Value<String?> note = const Value.absent(),
          String? extrasJson,
          int? clientVisitsAtCheckout,
          Value<String?> uid = const Value.absent(),
          DbStayStatus? statut}) =>
      Stay(
        id: id ?? this.id,
        receiptNumber: receiptNumber ?? this.receiptNumber,
        reservationNumber: reservationNumber.present
            ? reservationNumber.value
            : this.reservationNumber,
        generatedAt: generatedAt ?? this.generatedAt,
        checkinAt: checkinAt ?? this.checkinAt,
        checkoutAt: checkoutAt ?? this.checkoutAt,
        guestFullName: guestFullName ?? this.guestFullName,
        guestNationality: guestNationality.present
            ? guestNationality.value
            : this.guestNationality,
        guestPhone: guestPhone.present ? guestPhone.value : this.guestPhone,
        guestEmail: guestEmail.present ? guestEmail.value : this.guestEmail,
        payerName: payerName.present ? payerName.value : this.payerName,
        payerTaxId: payerTaxId.present ? payerTaxId.value : this.payerTaxId,
        payerAddress:
            payerAddress.present ? payerAddress.value : this.payerAddress,
        payerContact:
            payerContact.present ? payerContact.value : this.payerContact,
        subtotalCents: subtotalCents ?? this.subtotalCents,
        remiseCents: remiseCents ?? this.remiseCents,
        remiseKind: remiseKind ?? this.remiseKind,
        remiseValue: remiseValue ?? this.remiseValue,
        remiseBase: remiseBase ?? this.remiseBase,
        remiseReason:
            remiseReason.present ? remiseReason.value : this.remiseReason,
        acompteFcCents: acompteFcCents ?? this.acompteFcCents,
        acompteUsdCents: acompteUsdCents ?? this.acompteUsdCents,
        fcPerUsdCents: fcPerUsdCents ?? this.fcPerUsdCents,
        paymentMode: paymentMode ?? this.paymentMode,
        stayGroup: stayGroup.present ? stayGroup.value : this.stayGroup,
        serverLogin: serverLogin.present ? serverLogin.value : this.serverLogin,
        note: note.present ? note.value : this.note,
        extrasJson: extrasJson ?? this.extrasJson,
        clientVisitsAtCheckout:
            clientVisitsAtCheckout ?? this.clientVisitsAtCheckout,
        uid: uid.present ? uid.value : this.uid,
        statut: statut ?? this.statut,
      );
  Stay copyWithCompanion(StaysCompanion data) {
    return Stay(
      id: data.id.present ? data.id.value : this.id,
      receiptNumber: data.receiptNumber.present
          ? data.receiptNumber.value
          : this.receiptNumber,
      reservationNumber: data.reservationNumber.present
          ? data.reservationNumber.value
          : this.reservationNumber,
      generatedAt:
          data.generatedAt.present ? data.generatedAt.value : this.generatedAt,
      checkinAt: data.checkinAt.present ? data.checkinAt.value : this.checkinAt,
      checkoutAt:
          data.checkoutAt.present ? data.checkoutAt.value : this.checkoutAt,
      guestFullName: data.guestFullName.present
          ? data.guestFullName.value
          : this.guestFullName,
      guestNationality: data.guestNationality.present
          ? data.guestNationality.value
          : this.guestNationality,
      guestPhone:
          data.guestPhone.present ? data.guestPhone.value : this.guestPhone,
      guestEmail:
          data.guestEmail.present ? data.guestEmail.value : this.guestEmail,
      payerName: data.payerName.present ? data.payerName.value : this.payerName,
      payerTaxId:
          data.payerTaxId.present ? data.payerTaxId.value : this.payerTaxId,
      payerAddress: data.payerAddress.present
          ? data.payerAddress.value
          : this.payerAddress,
      payerContact: data.payerContact.present
          ? data.payerContact.value
          : this.payerContact,
      subtotalCents: data.subtotalCents.present
          ? data.subtotalCents.value
          : this.subtotalCents,
      remiseCents:
          data.remiseCents.present ? data.remiseCents.value : this.remiseCents,
      remiseKind:
          data.remiseKind.present ? data.remiseKind.value : this.remiseKind,
      remiseValue:
          data.remiseValue.present ? data.remiseValue.value : this.remiseValue,
      remiseBase:
          data.remiseBase.present ? data.remiseBase.value : this.remiseBase,
      remiseReason: data.remiseReason.present
          ? data.remiseReason.value
          : this.remiseReason,
      acompteFcCents: data.acompteFcCents.present
          ? data.acompteFcCents.value
          : this.acompteFcCents,
      acompteUsdCents: data.acompteUsdCents.present
          ? data.acompteUsdCents.value
          : this.acompteUsdCents,
      fcPerUsdCents: data.fcPerUsdCents.present
          ? data.fcPerUsdCents.value
          : this.fcPerUsdCents,
      paymentMode:
          data.paymentMode.present ? data.paymentMode.value : this.paymentMode,
      stayGroup: data.stayGroup.present ? data.stayGroup.value : this.stayGroup,
      serverLogin:
          data.serverLogin.present ? data.serverLogin.value : this.serverLogin,
      note: data.note.present ? data.note.value : this.note,
      extrasJson:
          data.extrasJson.present ? data.extrasJson.value : this.extrasJson,
      clientVisitsAtCheckout: data.clientVisitsAtCheckout.present
          ? data.clientVisitsAtCheckout.value
          : this.clientVisitsAtCheckout,
      uid: data.uid.present ? data.uid.value : this.uid,
      statut: data.statut.present ? data.statut.value : this.statut,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Stay(')
          ..write('id: $id, ')
          ..write('receiptNumber: $receiptNumber, ')
          ..write('reservationNumber: $reservationNumber, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('checkinAt: $checkinAt, ')
          ..write('checkoutAt: $checkoutAt, ')
          ..write('guestFullName: $guestFullName, ')
          ..write('guestNationality: $guestNationality, ')
          ..write('guestPhone: $guestPhone, ')
          ..write('guestEmail: $guestEmail, ')
          ..write('payerName: $payerName, ')
          ..write('payerTaxId: $payerTaxId, ')
          ..write('payerAddress: $payerAddress, ')
          ..write('payerContact: $payerContact, ')
          ..write('subtotalCents: $subtotalCents, ')
          ..write('remiseCents: $remiseCents, ')
          ..write('remiseKind: $remiseKind, ')
          ..write('remiseValue: $remiseValue, ')
          ..write('remiseBase: $remiseBase, ')
          ..write('remiseReason: $remiseReason, ')
          ..write('acompteFcCents: $acompteFcCents, ')
          ..write('acompteUsdCents: $acompteUsdCents, ')
          ..write('fcPerUsdCents: $fcPerUsdCents, ')
          ..write('paymentMode: $paymentMode, ')
          ..write('stayGroup: $stayGroup, ')
          ..write('serverLogin: $serverLogin, ')
          ..write('note: $note, ')
          ..write('extrasJson: $extrasJson, ')
          ..write('clientVisitsAtCheckout: $clientVisitsAtCheckout, ')
          ..write('uid: $uid, ')
          ..write('statut: $statut')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        receiptNumber,
        reservationNumber,
        generatedAt,
        checkinAt,
        checkoutAt,
        guestFullName,
        guestNationality,
        guestPhone,
        guestEmail,
        payerName,
        payerTaxId,
        payerAddress,
        payerContact,
        subtotalCents,
        remiseCents,
        remiseKind,
        remiseValue,
        remiseBase,
        remiseReason,
        acompteFcCents,
        acompteUsdCents,
        fcPerUsdCents,
        paymentMode,
        stayGroup,
        serverLogin,
        note,
        extrasJson,
        clientVisitsAtCheckout,
        uid,
        statut
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Stay &&
          other.id == this.id &&
          other.receiptNumber == this.receiptNumber &&
          other.reservationNumber == this.reservationNumber &&
          other.generatedAt == this.generatedAt &&
          other.checkinAt == this.checkinAt &&
          other.checkoutAt == this.checkoutAt &&
          other.guestFullName == this.guestFullName &&
          other.guestNationality == this.guestNationality &&
          other.guestPhone == this.guestPhone &&
          other.guestEmail == this.guestEmail &&
          other.payerName == this.payerName &&
          other.payerTaxId == this.payerTaxId &&
          other.payerAddress == this.payerAddress &&
          other.payerContact == this.payerContact &&
          other.subtotalCents == this.subtotalCents &&
          other.remiseCents == this.remiseCents &&
          other.remiseKind == this.remiseKind &&
          other.remiseValue == this.remiseValue &&
          other.remiseBase == this.remiseBase &&
          other.remiseReason == this.remiseReason &&
          other.acompteFcCents == this.acompteFcCents &&
          other.acompteUsdCents == this.acompteUsdCents &&
          other.fcPerUsdCents == this.fcPerUsdCents &&
          other.paymentMode == this.paymentMode &&
          other.stayGroup == this.stayGroup &&
          other.serverLogin == this.serverLogin &&
          other.note == this.note &&
          other.extrasJson == this.extrasJson &&
          other.clientVisitsAtCheckout == this.clientVisitsAtCheckout &&
          other.uid == this.uid &&
          other.statut == this.statut);
}

class StaysCompanion extends UpdateCompanion<Stay> {
  final Value<int> id;
  final Value<String> receiptNumber;
  final Value<String?> reservationNumber;
  final Value<DateTime> generatedAt;
  final Value<DateTime> checkinAt;
  final Value<DateTime> checkoutAt;
  final Value<String> guestFullName;
  final Value<String?> guestNationality;
  final Value<String?> guestPhone;
  final Value<String?> guestEmail;
  final Value<String?> payerName;
  final Value<String?> payerTaxId;
  final Value<String?> payerAddress;
  final Value<String?> payerContact;
  final Value<int> subtotalCents;
  final Value<int> remiseCents;
  final Value<int> remiseKind;
  final Value<int> remiseValue;
  final Value<int> remiseBase;
  final Value<String?> remiseReason;
  final Value<int> acompteFcCents;
  final Value<int> acompteUsdCents;
  final Value<int> fcPerUsdCents;
  final Value<int> paymentMode;
  final Value<String?> stayGroup;
  final Value<String?> serverLogin;
  final Value<String?> note;
  final Value<String> extrasJson;
  final Value<int> clientVisitsAtCheckout;
  final Value<String?> uid;
  final Value<DbStayStatus> statut;
  const StaysCompanion({
    this.id = const Value.absent(),
    this.receiptNumber = const Value.absent(),
    this.reservationNumber = const Value.absent(),
    this.generatedAt = const Value.absent(),
    this.checkinAt = const Value.absent(),
    this.checkoutAt = const Value.absent(),
    this.guestFullName = const Value.absent(),
    this.guestNationality = const Value.absent(),
    this.guestPhone = const Value.absent(),
    this.guestEmail = const Value.absent(),
    this.payerName = const Value.absent(),
    this.payerTaxId = const Value.absent(),
    this.payerAddress = const Value.absent(),
    this.payerContact = const Value.absent(),
    this.subtotalCents = const Value.absent(),
    this.remiseCents = const Value.absent(),
    this.remiseKind = const Value.absent(),
    this.remiseValue = const Value.absent(),
    this.remiseBase = const Value.absent(),
    this.remiseReason = const Value.absent(),
    this.acompteFcCents = const Value.absent(),
    this.acompteUsdCents = const Value.absent(),
    this.fcPerUsdCents = const Value.absent(),
    this.paymentMode = const Value.absent(),
    this.stayGroup = const Value.absent(),
    this.serverLogin = const Value.absent(),
    this.note = const Value.absent(),
    this.extrasJson = const Value.absent(),
    this.clientVisitsAtCheckout = const Value.absent(),
    this.uid = const Value.absent(),
    this.statut = const Value.absent(),
  });
  StaysCompanion.insert({
    this.id = const Value.absent(),
    required String receiptNumber,
    this.reservationNumber = const Value.absent(),
    this.generatedAt = const Value.absent(),
    required DateTime checkinAt,
    required DateTime checkoutAt,
    required String guestFullName,
    this.guestNationality = const Value.absent(),
    this.guestPhone = const Value.absent(),
    this.guestEmail = const Value.absent(),
    this.payerName = const Value.absent(),
    this.payerTaxId = const Value.absent(),
    this.payerAddress = const Value.absent(),
    this.payerContact = const Value.absent(),
    required int subtotalCents,
    this.remiseCents = const Value.absent(),
    this.remiseKind = const Value.absent(),
    this.remiseValue = const Value.absent(),
    this.remiseBase = const Value.absent(),
    this.remiseReason = const Value.absent(),
    this.acompteFcCents = const Value.absent(),
    this.acompteUsdCents = const Value.absent(),
    this.fcPerUsdCents = const Value.absent(),
    this.paymentMode = const Value.absent(),
    this.stayGroup = const Value.absent(),
    this.serverLogin = const Value.absent(),
    this.note = const Value.absent(),
    this.extrasJson = const Value.absent(),
    this.clientVisitsAtCheckout = const Value.absent(),
    this.uid = const Value.absent(),
    this.statut = const Value.absent(),
  })  : receiptNumber = Value(receiptNumber),
        checkinAt = Value(checkinAt),
        checkoutAt = Value(checkoutAt),
        guestFullName = Value(guestFullName),
        subtotalCents = Value(subtotalCents);
  static Insertable<Stay> custom({
    Expression<int>? id,
    Expression<String>? receiptNumber,
    Expression<String>? reservationNumber,
    Expression<DateTime>? generatedAt,
    Expression<DateTime>? checkinAt,
    Expression<DateTime>? checkoutAt,
    Expression<String>? guestFullName,
    Expression<String>? guestNationality,
    Expression<String>? guestPhone,
    Expression<String>? guestEmail,
    Expression<String>? payerName,
    Expression<String>? payerTaxId,
    Expression<String>? payerAddress,
    Expression<String>? payerContact,
    Expression<int>? subtotalCents,
    Expression<int>? remiseCents,
    Expression<int>? remiseKind,
    Expression<int>? remiseValue,
    Expression<int>? remiseBase,
    Expression<String>? remiseReason,
    Expression<int>? acompteFcCents,
    Expression<int>? acompteUsdCents,
    Expression<int>? fcPerUsdCents,
    Expression<int>? paymentMode,
    Expression<String>? stayGroup,
    Expression<String>? serverLogin,
    Expression<String>? note,
    Expression<String>? extrasJson,
    Expression<int>? clientVisitsAtCheckout,
    Expression<String>? uid,
    Expression<int>? statut,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (receiptNumber != null) 'receipt_number': receiptNumber,
      if (reservationNumber != null) 'reservation_number': reservationNumber,
      if (generatedAt != null) 'generated_at': generatedAt,
      if (checkinAt != null) 'checkin_at': checkinAt,
      if (checkoutAt != null) 'checkout_at': checkoutAt,
      if (guestFullName != null) 'guest_full_name': guestFullName,
      if (guestNationality != null) 'guest_nationality': guestNationality,
      if (guestPhone != null) 'guest_phone': guestPhone,
      if (guestEmail != null) 'guest_email': guestEmail,
      if (payerName != null) 'payer_name': payerName,
      if (payerTaxId != null) 'payer_tax_id': payerTaxId,
      if (payerAddress != null) 'payer_address': payerAddress,
      if (payerContact != null) 'payer_contact': payerContact,
      if (subtotalCents != null) 'subtotal_cents': subtotalCents,
      if (remiseCents != null) 'remise_cents': remiseCents,
      if (remiseKind != null) 'remise_kind': remiseKind,
      if (remiseValue != null) 'remise_value': remiseValue,
      if (remiseBase != null) 'remise_base': remiseBase,
      if (remiseReason != null) 'remise_reason': remiseReason,
      if (acompteFcCents != null) 'acompte_fc_cents': acompteFcCents,
      if (acompteUsdCents != null) 'acompte_usd_cents': acompteUsdCents,
      if (fcPerUsdCents != null) 'fc_per_usd_cents': fcPerUsdCents,
      if (paymentMode != null) 'payment_mode': paymentMode,
      if (stayGroup != null) 'stay_group': stayGroup,
      if (serverLogin != null) 'server_login': serverLogin,
      if (note != null) 'note': note,
      if (extrasJson != null) 'extras_json': extrasJson,
      if (clientVisitsAtCheckout != null)
        'client_visits_at_checkout': clientVisitsAtCheckout,
      if (uid != null) 'uid': uid,
      if (statut != null) 'statut': statut,
    });
  }

  StaysCompanion copyWith(
      {Value<int>? id,
      Value<String>? receiptNumber,
      Value<String?>? reservationNumber,
      Value<DateTime>? generatedAt,
      Value<DateTime>? checkinAt,
      Value<DateTime>? checkoutAt,
      Value<String>? guestFullName,
      Value<String?>? guestNationality,
      Value<String?>? guestPhone,
      Value<String?>? guestEmail,
      Value<String?>? payerName,
      Value<String?>? payerTaxId,
      Value<String?>? payerAddress,
      Value<String?>? payerContact,
      Value<int>? subtotalCents,
      Value<int>? remiseCents,
      Value<int>? remiseKind,
      Value<int>? remiseValue,
      Value<int>? remiseBase,
      Value<String?>? remiseReason,
      Value<int>? acompteFcCents,
      Value<int>? acompteUsdCents,
      Value<int>? fcPerUsdCents,
      Value<int>? paymentMode,
      Value<String?>? stayGroup,
      Value<String?>? serverLogin,
      Value<String?>? note,
      Value<String>? extrasJson,
      Value<int>? clientVisitsAtCheckout,
      Value<String?>? uid,
      Value<DbStayStatus>? statut}) {
    return StaysCompanion(
      id: id ?? this.id,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      reservationNumber: reservationNumber ?? this.reservationNumber,
      generatedAt: generatedAt ?? this.generatedAt,
      checkinAt: checkinAt ?? this.checkinAt,
      checkoutAt: checkoutAt ?? this.checkoutAt,
      guestFullName: guestFullName ?? this.guestFullName,
      guestNationality: guestNationality ?? this.guestNationality,
      guestPhone: guestPhone ?? this.guestPhone,
      guestEmail: guestEmail ?? this.guestEmail,
      payerName: payerName ?? this.payerName,
      payerTaxId: payerTaxId ?? this.payerTaxId,
      payerAddress: payerAddress ?? this.payerAddress,
      payerContact: payerContact ?? this.payerContact,
      subtotalCents: subtotalCents ?? this.subtotalCents,
      remiseCents: remiseCents ?? this.remiseCents,
      remiseKind: remiseKind ?? this.remiseKind,
      remiseValue: remiseValue ?? this.remiseValue,
      remiseBase: remiseBase ?? this.remiseBase,
      remiseReason: remiseReason ?? this.remiseReason,
      acompteFcCents: acompteFcCents ?? this.acompteFcCents,
      acompteUsdCents: acompteUsdCents ?? this.acompteUsdCents,
      fcPerUsdCents: fcPerUsdCents ?? this.fcPerUsdCents,
      paymentMode: paymentMode ?? this.paymentMode,
      stayGroup: stayGroup ?? this.stayGroup,
      serverLogin: serverLogin ?? this.serverLogin,
      note: note ?? this.note,
      extrasJson: extrasJson ?? this.extrasJson,
      clientVisitsAtCheckout:
          clientVisitsAtCheckout ?? this.clientVisitsAtCheckout,
      uid: uid ?? this.uid,
      statut: statut ?? this.statut,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (receiptNumber.present) {
      map['receipt_number'] = Variable<String>(receiptNumber.value);
    }
    if (reservationNumber.present) {
      map['reservation_number'] = Variable<String>(reservationNumber.value);
    }
    if (generatedAt.present) {
      map['generated_at'] = Variable<DateTime>(generatedAt.value);
    }
    if (checkinAt.present) {
      map['checkin_at'] = Variable<DateTime>(checkinAt.value);
    }
    if (checkoutAt.present) {
      map['checkout_at'] = Variable<DateTime>(checkoutAt.value);
    }
    if (guestFullName.present) {
      map['guest_full_name'] = Variable<String>(guestFullName.value);
    }
    if (guestNationality.present) {
      map['guest_nationality'] = Variable<String>(guestNationality.value);
    }
    if (guestPhone.present) {
      map['guest_phone'] = Variable<String>(guestPhone.value);
    }
    if (guestEmail.present) {
      map['guest_email'] = Variable<String>(guestEmail.value);
    }
    if (payerName.present) {
      map['payer_name'] = Variable<String>(payerName.value);
    }
    if (payerTaxId.present) {
      map['payer_tax_id'] = Variable<String>(payerTaxId.value);
    }
    if (payerAddress.present) {
      map['payer_address'] = Variable<String>(payerAddress.value);
    }
    if (payerContact.present) {
      map['payer_contact'] = Variable<String>(payerContact.value);
    }
    if (subtotalCents.present) {
      map['subtotal_cents'] = Variable<int>(subtotalCents.value);
    }
    if (remiseCents.present) {
      map['remise_cents'] = Variable<int>(remiseCents.value);
    }
    if (remiseKind.present) {
      map['remise_kind'] = Variable<int>(remiseKind.value);
    }
    if (remiseValue.present) {
      map['remise_value'] = Variable<int>(remiseValue.value);
    }
    if (remiseBase.present) {
      map['remise_base'] = Variable<int>(remiseBase.value);
    }
    if (remiseReason.present) {
      map['remise_reason'] = Variable<String>(remiseReason.value);
    }
    if (acompteFcCents.present) {
      map['acompte_fc_cents'] = Variable<int>(acompteFcCents.value);
    }
    if (acompteUsdCents.present) {
      map['acompte_usd_cents'] = Variable<int>(acompteUsdCents.value);
    }
    if (fcPerUsdCents.present) {
      map['fc_per_usd_cents'] = Variable<int>(fcPerUsdCents.value);
    }
    if (paymentMode.present) {
      map['payment_mode'] = Variable<int>(paymentMode.value);
    }
    if (stayGroup.present) {
      map['stay_group'] = Variable<String>(stayGroup.value);
    }
    if (serverLogin.present) {
      map['server_login'] = Variable<String>(serverLogin.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (extrasJson.present) {
      map['extras_json'] = Variable<String>(extrasJson.value);
    }
    if (clientVisitsAtCheckout.present) {
      map['client_visits_at_checkout'] =
          Variable<int>(clientVisitsAtCheckout.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (statut.present) {
      map['statut'] =
          Variable<int>($StaysTable.$converterstatut.toSql(statut.value));
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StaysCompanion(')
          ..write('id: $id, ')
          ..write('receiptNumber: $receiptNumber, ')
          ..write('reservationNumber: $reservationNumber, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('checkinAt: $checkinAt, ')
          ..write('checkoutAt: $checkoutAt, ')
          ..write('guestFullName: $guestFullName, ')
          ..write('guestNationality: $guestNationality, ')
          ..write('guestPhone: $guestPhone, ')
          ..write('guestEmail: $guestEmail, ')
          ..write('payerName: $payerName, ')
          ..write('payerTaxId: $payerTaxId, ')
          ..write('payerAddress: $payerAddress, ')
          ..write('payerContact: $payerContact, ')
          ..write('subtotalCents: $subtotalCents, ')
          ..write('remiseCents: $remiseCents, ')
          ..write('remiseKind: $remiseKind, ')
          ..write('remiseValue: $remiseValue, ')
          ..write('remiseBase: $remiseBase, ')
          ..write('remiseReason: $remiseReason, ')
          ..write('acompteFcCents: $acompteFcCents, ')
          ..write('acompteUsdCents: $acompteUsdCents, ')
          ..write('fcPerUsdCents: $fcPerUsdCents, ')
          ..write('paymentMode: $paymentMode, ')
          ..write('stayGroup: $stayGroup, ')
          ..write('serverLogin: $serverLogin, ')
          ..write('note: $note, ')
          ..write('extrasJson: $extrasJson, ')
          ..write('clientVisitsAtCheckout: $clientVisitsAtCheckout, ')
          ..write('uid: $uid, ')
          ..write('statut: $statut')
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
  static const VerificationMeta _priceUsdCentsMeta =
      const VerificationMeta('priceUsdCents');
  @override
  late final GeneratedColumn<int> priceUsdCents = GeneratedColumn<int>(
      'price_usd_cents', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
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
  static const VerificationMeta _checkinNoteMeta =
      const VerificationMeta('checkinNote');
  @override
  late final GeneratedColumn<String> checkinNote = GeneratedColumn<String>(
      'checkin_note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _checkinAtMeta =
      const VerificationMeta('checkinAt');
  @override
  late final GeneratedColumn<DateTime> checkinAt = GeneratedColumn<DateTime>(
      'checkin_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _stayGroupMeta =
      const VerificationMeta('stayGroup');
  @override
  late final GeneratedColumn<String> stayGroup = GeneratedColumn<String>(
      'stay_group', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _payerIdMeta =
      const VerificationMeta('payerId');
  @override
  late final GeneratedColumn<int> payerId = GeneratedColumn<int>(
      'payer_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES payers (id) ON DELETE SET NULL'));
  static const VerificationMeta _imagePathMeta =
      const VerificationMeta('imagePath');
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
      'image_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _negotiatedPriceCentsMeta =
      const VerificationMeta('negotiatedPriceCents');
  @override
  late final GeneratedColumn<int> negotiatedPriceCents = GeneratedColumn<int>(
      'negotiated_price_cents', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _currentStayIdMeta =
      const VerificationMeta('currentStayId');
  @override
  late final GeneratedColumn<int> currentStayId = GeneratedColumn<int>(
      'current_stay_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES stays (id) ON DELETE SET NULL'));
  @override
  List<GeneratedColumn> get $columns => [
        number,
        type,
        priceUsdCents,
        pricePerNightCents,
        status,
        currentGuest,
        checkoutDate,
        checkinNote,
        checkinAt,
        stayGroup,
        payerId,
        imagePath,
        negotiatedPriceCents,
        currentStayId
      ];
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
    if (data.containsKey('price_usd_cents')) {
      context.handle(
          _priceUsdCentsMeta,
          priceUsdCents.isAcceptableOrUnknown(
              data['price_usd_cents']!, _priceUsdCentsMeta));
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
    if (data.containsKey('checkin_note')) {
      context.handle(
          _checkinNoteMeta,
          checkinNote.isAcceptableOrUnknown(
              data['checkin_note']!, _checkinNoteMeta));
    }
    if (data.containsKey('checkin_at')) {
      context.handle(_checkinAtMeta,
          checkinAt.isAcceptableOrUnknown(data['checkin_at']!, _checkinAtMeta));
    }
    if (data.containsKey('stay_group')) {
      context.handle(_stayGroupMeta,
          stayGroup.isAcceptableOrUnknown(data['stay_group']!, _stayGroupMeta));
    }
    if (data.containsKey('payer_id')) {
      context.handle(_payerIdMeta,
          payerId.isAcceptableOrUnknown(data['payer_id']!, _payerIdMeta));
    }
    if (data.containsKey('image_path')) {
      context.handle(_imagePathMeta,
          imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta));
    }
    if (data.containsKey('negotiated_price_cents')) {
      context.handle(
          _negotiatedPriceCentsMeta,
          negotiatedPriceCents.isAcceptableOrUnknown(
              data['negotiated_price_cents']!, _negotiatedPriceCentsMeta));
    }
    if (data.containsKey('current_stay_id')) {
      context.handle(
          _currentStayIdMeta,
          currentStayId.isAcceptableOrUnknown(
              data['current_stay_id']!, _currentStayIdMeta));
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
      priceUsdCents: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}price_usd_cents'])!,
      pricePerNightCents: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}price_per_night_cents'])!,
      status: $RoomsTable.$converterstatus.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!),
      currentGuest: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}current_guest']),
      checkoutDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}checkout_date']),
      checkinNote: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}checkin_note']),
      checkinAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}checkin_at']),
      stayGroup: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}stay_group']),
      payerId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}payer_id']),
      imagePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_path']),
      negotiatedPriceCents: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}negotiated_price_cents']),
      currentStayId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}current_stay_id']),
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

  /// Tarif de la nuit, en CENTS DE DOLLAR. C'est le prix annoncé au
  /// client, et donc la seule valeur saisie.
  ///
  /// Le franc reste la monnaie d'encaissement — la caisse, les dettes,
  /// les rapports sont en FC — mais il n'est plus la source : il se
  /// calcule au taux. Le tarif d'une chambre ne doit pas bouger parce
  /// que le franc a bougé.
  final int priceUsdCents;

  /// Le même tarif converti en francs, au taux courant.
  ///
  /// Valeur CALCULÉE, gardée en base parce que la caisse, le miroir et
  /// les rapports la lisent partout. Recalculée quand le tarif change et
  /// quand le taux change — voir `RoomsRepo.rafraichirConversions`.
  final int pricePerNightCents;
  final DbRoomStatus status;
  final String? currentGuest;
  final DateTime? checkoutDate;

  /// Note libre saisie au check-in (préférences client, motif du séjour,
  /// alertes, etc.). Vidée au checkOut. Affichée dans les rapports.
  final String? checkinNote;

  /// Horodatage précis du check-in (utilisé dans le rapport occupation).
  /// Set automatiquement par [RoomsRepo.checkIn], vidé au checkOut.
  final DateTime? checkinAt;

  /// Séjour groupé : identifiant partagé par plusieurs chambres louées en
  /// même temps par une entreprise / un même payeur. Null = séjour solo.
  /// Vidé au checkOut. Permet de générer une facture consolidée.
  final String? stayGroup;

  /// Prise en charge : id du payeur (société ou particulier tiers). Null →
  /// c'est l'occupant qui paie lui-même. Vidé au checkOut.
  final int? payerId;

  /// Photo de la chambre (chemin local ou URL Supabase Storage), même
  /// convention que Articles.imagePath. Null → icône générique.
  final String? imagePath;

  /// Tarif négocié pour le séjour en cours (cents FC/nuit). Null → on
  /// facture [pricePerNightCents] (tarif catalogue). L'écart entre les
  /// deux est reporté comme remise ligne à ligne sur la facture. Saisi
  /// au check-in, vidé au checkOut.
  final int? negotiatedPriceCents;

  /// Le séjour en cours dans cette chambre (v27). Une vraie clé
  /// étrangère : c'est le séjour qui fait foi sur l'occupant, les dates et
  /// le tarif. Les champs « séjour en cours » ci-dessus restent remplis
  /// pour l'affichage et pour les postes pas encore à jour ; ils seront
  /// retirés dans une itération suivante.
  final int? currentStayId;
  const Room(
      {required this.number,
      required this.type,
      required this.priceUsdCents,
      required this.pricePerNightCents,
      required this.status,
      this.currentGuest,
      this.checkoutDate,
      this.checkinNote,
      this.checkinAt,
      this.stayGroup,
      this.payerId,
      this.imagePath,
      this.negotiatedPriceCents,
      this.currentStayId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['number'] = Variable<String>(number);
    map['type'] = Variable<String>(type);
    map['price_usd_cents'] = Variable<int>(priceUsdCents);
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
    if (!nullToAbsent || checkinNote != null) {
      map['checkin_note'] = Variable<String>(checkinNote);
    }
    if (!nullToAbsent || checkinAt != null) {
      map['checkin_at'] = Variable<DateTime>(checkinAt);
    }
    if (!nullToAbsent || stayGroup != null) {
      map['stay_group'] = Variable<String>(stayGroup);
    }
    if (!nullToAbsent || payerId != null) {
      map['payer_id'] = Variable<int>(payerId);
    }
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    if (!nullToAbsent || negotiatedPriceCents != null) {
      map['negotiated_price_cents'] = Variable<int>(negotiatedPriceCents);
    }
    if (!nullToAbsent || currentStayId != null) {
      map['current_stay_id'] = Variable<int>(currentStayId);
    }
    return map;
  }

  RoomsCompanion toCompanion(bool nullToAbsent) {
    return RoomsCompanion(
      number: Value(number),
      type: Value(type),
      priceUsdCents: Value(priceUsdCents),
      pricePerNightCents: Value(pricePerNightCents),
      status: Value(status),
      currentGuest: currentGuest == null && nullToAbsent
          ? const Value.absent()
          : Value(currentGuest),
      checkoutDate: checkoutDate == null && nullToAbsent
          ? const Value.absent()
          : Value(checkoutDate),
      checkinNote: checkinNote == null && nullToAbsent
          ? const Value.absent()
          : Value(checkinNote),
      checkinAt: checkinAt == null && nullToAbsent
          ? const Value.absent()
          : Value(checkinAt),
      stayGroup: stayGroup == null && nullToAbsent
          ? const Value.absent()
          : Value(stayGroup),
      payerId: payerId == null && nullToAbsent
          ? const Value.absent()
          : Value(payerId),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
      negotiatedPriceCents: negotiatedPriceCents == null && nullToAbsent
          ? const Value.absent()
          : Value(negotiatedPriceCents),
      currentStayId: currentStayId == null && nullToAbsent
          ? const Value.absent()
          : Value(currentStayId),
    );
  }

  factory Room.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Room(
      number: serializer.fromJson<String>(json['number']),
      type: serializer.fromJson<String>(json['type']),
      priceUsdCents: serializer.fromJson<int>(json['priceUsdCents']),
      pricePerNightCents: serializer.fromJson<int>(json['pricePerNightCents']),
      status: $RoomsTable.$converterstatus
          .fromJson(serializer.fromJson<int>(json['status'])),
      currentGuest: serializer.fromJson<String?>(json['currentGuest']),
      checkoutDate: serializer.fromJson<DateTime?>(json['checkoutDate']),
      checkinNote: serializer.fromJson<String?>(json['checkinNote']),
      checkinAt: serializer.fromJson<DateTime?>(json['checkinAt']),
      stayGroup: serializer.fromJson<String?>(json['stayGroup']),
      payerId: serializer.fromJson<int?>(json['payerId']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      negotiatedPriceCents:
          serializer.fromJson<int?>(json['negotiatedPriceCents']),
      currentStayId: serializer.fromJson<int?>(json['currentStayId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'number': serializer.toJson<String>(number),
      'type': serializer.toJson<String>(type),
      'priceUsdCents': serializer.toJson<int>(priceUsdCents),
      'pricePerNightCents': serializer.toJson<int>(pricePerNightCents),
      'status':
          serializer.toJson<int>($RoomsTable.$converterstatus.toJson(status)),
      'currentGuest': serializer.toJson<String?>(currentGuest),
      'checkoutDate': serializer.toJson<DateTime?>(checkoutDate),
      'checkinNote': serializer.toJson<String?>(checkinNote),
      'checkinAt': serializer.toJson<DateTime?>(checkinAt),
      'stayGroup': serializer.toJson<String?>(stayGroup),
      'payerId': serializer.toJson<int?>(payerId),
      'imagePath': serializer.toJson<String?>(imagePath),
      'negotiatedPriceCents': serializer.toJson<int?>(negotiatedPriceCents),
      'currentStayId': serializer.toJson<int?>(currentStayId),
    };
  }

  Room copyWith(
          {String? number,
          String? type,
          int? priceUsdCents,
          int? pricePerNightCents,
          DbRoomStatus? status,
          Value<String?> currentGuest = const Value.absent(),
          Value<DateTime?> checkoutDate = const Value.absent(),
          Value<String?> checkinNote = const Value.absent(),
          Value<DateTime?> checkinAt = const Value.absent(),
          Value<String?> stayGroup = const Value.absent(),
          Value<int?> payerId = const Value.absent(),
          Value<String?> imagePath = const Value.absent(),
          Value<int?> negotiatedPriceCents = const Value.absent(),
          Value<int?> currentStayId = const Value.absent()}) =>
      Room(
        number: number ?? this.number,
        type: type ?? this.type,
        priceUsdCents: priceUsdCents ?? this.priceUsdCents,
        pricePerNightCents: pricePerNightCents ?? this.pricePerNightCents,
        status: status ?? this.status,
        currentGuest:
            currentGuest.present ? currentGuest.value : this.currentGuest,
        checkoutDate:
            checkoutDate.present ? checkoutDate.value : this.checkoutDate,
        checkinNote: checkinNote.present ? checkinNote.value : this.checkinNote,
        checkinAt: checkinAt.present ? checkinAt.value : this.checkinAt,
        stayGroup: stayGroup.present ? stayGroup.value : this.stayGroup,
        payerId: payerId.present ? payerId.value : this.payerId,
        imagePath: imagePath.present ? imagePath.value : this.imagePath,
        negotiatedPriceCents: negotiatedPriceCents.present
            ? negotiatedPriceCents.value
            : this.negotiatedPriceCents,
        currentStayId:
            currentStayId.present ? currentStayId.value : this.currentStayId,
      );
  Room copyWithCompanion(RoomsCompanion data) {
    return Room(
      number: data.number.present ? data.number.value : this.number,
      type: data.type.present ? data.type.value : this.type,
      priceUsdCents: data.priceUsdCents.present
          ? data.priceUsdCents.value
          : this.priceUsdCents,
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
      checkinNote:
          data.checkinNote.present ? data.checkinNote.value : this.checkinNote,
      checkinAt: data.checkinAt.present ? data.checkinAt.value : this.checkinAt,
      stayGroup: data.stayGroup.present ? data.stayGroup.value : this.stayGroup,
      payerId: data.payerId.present ? data.payerId.value : this.payerId,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      negotiatedPriceCents: data.negotiatedPriceCents.present
          ? data.negotiatedPriceCents.value
          : this.negotiatedPriceCents,
      currentStayId: data.currentStayId.present
          ? data.currentStayId.value
          : this.currentStayId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Room(')
          ..write('number: $number, ')
          ..write('type: $type, ')
          ..write('priceUsdCents: $priceUsdCents, ')
          ..write('pricePerNightCents: $pricePerNightCents, ')
          ..write('status: $status, ')
          ..write('currentGuest: $currentGuest, ')
          ..write('checkoutDate: $checkoutDate, ')
          ..write('checkinNote: $checkinNote, ')
          ..write('checkinAt: $checkinAt, ')
          ..write('stayGroup: $stayGroup, ')
          ..write('payerId: $payerId, ')
          ..write('imagePath: $imagePath, ')
          ..write('negotiatedPriceCents: $negotiatedPriceCents, ')
          ..write('currentStayId: $currentStayId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      number,
      type,
      priceUsdCents,
      pricePerNightCents,
      status,
      currentGuest,
      checkoutDate,
      checkinNote,
      checkinAt,
      stayGroup,
      payerId,
      imagePath,
      negotiatedPriceCents,
      currentStayId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Room &&
          other.number == this.number &&
          other.type == this.type &&
          other.priceUsdCents == this.priceUsdCents &&
          other.pricePerNightCents == this.pricePerNightCents &&
          other.status == this.status &&
          other.currentGuest == this.currentGuest &&
          other.checkoutDate == this.checkoutDate &&
          other.checkinNote == this.checkinNote &&
          other.checkinAt == this.checkinAt &&
          other.stayGroup == this.stayGroup &&
          other.payerId == this.payerId &&
          other.imagePath == this.imagePath &&
          other.negotiatedPriceCents == this.negotiatedPriceCents &&
          other.currentStayId == this.currentStayId);
}

class RoomsCompanion extends UpdateCompanion<Room> {
  final Value<String> number;
  final Value<String> type;
  final Value<int> priceUsdCents;
  final Value<int> pricePerNightCents;
  final Value<DbRoomStatus> status;
  final Value<String?> currentGuest;
  final Value<DateTime?> checkoutDate;
  final Value<String?> checkinNote;
  final Value<DateTime?> checkinAt;
  final Value<String?> stayGroup;
  final Value<int?> payerId;
  final Value<String?> imagePath;
  final Value<int?> negotiatedPriceCents;
  final Value<int?> currentStayId;
  final Value<int> rowid;
  const RoomsCompanion({
    this.number = const Value.absent(),
    this.type = const Value.absent(),
    this.priceUsdCents = const Value.absent(),
    this.pricePerNightCents = const Value.absent(),
    this.status = const Value.absent(),
    this.currentGuest = const Value.absent(),
    this.checkoutDate = const Value.absent(),
    this.checkinNote = const Value.absent(),
    this.checkinAt = const Value.absent(),
    this.stayGroup = const Value.absent(),
    this.payerId = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.negotiatedPriceCents = const Value.absent(),
    this.currentStayId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoomsCompanion.insert({
    required String number,
    required String type,
    this.priceUsdCents = const Value.absent(),
    required int pricePerNightCents,
    required DbRoomStatus status,
    this.currentGuest = const Value.absent(),
    this.checkoutDate = const Value.absent(),
    this.checkinNote = const Value.absent(),
    this.checkinAt = const Value.absent(),
    this.stayGroup = const Value.absent(),
    this.payerId = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.negotiatedPriceCents = const Value.absent(),
    this.currentStayId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : number = Value(number),
        type = Value(type),
        pricePerNightCents = Value(pricePerNightCents),
        status = Value(status);
  static Insertable<Room> custom({
    Expression<String>? number,
    Expression<String>? type,
    Expression<int>? priceUsdCents,
    Expression<int>? pricePerNightCents,
    Expression<int>? status,
    Expression<String>? currentGuest,
    Expression<DateTime>? checkoutDate,
    Expression<String>? checkinNote,
    Expression<DateTime>? checkinAt,
    Expression<String>? stayGroup,
    Expression<int>? payerId,
    Expression<String>? imagePath,
    Expression<int>? negotiatedPriceCents,
    Expression<int>? currentStayId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (number != null) 'number': number,
      if (type != null) 'type': type,
      if (priceUsdCents != null) 'price_usd_cents': priceUsdCents,
      if (pricePerNightCents != null)
        'price_per_night_cents': pricePerNightCents,
      if (status != null) 'status': status,
      if (currentGuest != null) 'current_guest': currentGuest,
      if (checkoutDate != null) 'checkout_date': checkoutDate,
      if (checkinNote != null) 'checkin_note': checkinNote,
      if (checkinAt != null) 'checkin_at': checkinAt,
      if (stayGroup != null) 'stay_group': stayGroup,
      if (payerId != null) 'payer_id': payerId,
      if (imagePath != null) 'image_path': imagePath,
      if (negotiatedPriceCents != null)
        'negotiated_price_cents': negotiatedPriceCents,
      if (currentStayId != null) 'current_stay_id': currentStayId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoomsCompanion copyWith(
      {Value<String>? number,
      Value<String>? type,
      Value<int>? priceUsdCents,
      Value<int>? pricePerNightCents,
      Value<DbRoomStatus>? status,
      Value<String?>? currentGuest,
      Value<DateTime?>? checkoutDate,
      Value<String?>? checkinNote,
      Value<DateTime?>? checkinAt,
      Value<String?>? stayGroup,
      Value<int?>? payerId,
      Value<String?>? imagePath,
      Value<int?>? negotiatedPriceCents,
      Value<int?>? currentStayId,
      Value<int>? rowid}) {
    return RoomsCompanion(
      number: number ?? this.number,
      type: type ?? this.type,
      priceUsdCents: priceUsdCents ?? this.priceUsdCents,
      pricePerNightCents: pricePerNightCents ?? this.pricePerNightCents,
      status: status ?? this.status,
      currentGuest: currentGuest ?? this.currentGuest,
      checkoutDate: checkoutDate ?? this.checkoutDate,
      checkinNote: checkinNote ?? this.checkinNote,
      checkinAt: checkinAt ?? this.checkinAt,
      stayGroup: stayGroup ?? this.stayGroup,
      payerId: payerId ?? this.payerId,
      imagePath: imagePath ?? this.imagePath,
      negotiatedPriceCents: negotiatedPriceCents ?? this.negotiatedPriceCents,
      currentStayId: currentStayId ?? this.currentStayId,
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
    if (priceUsdCents.present) {
      map['price_usd_cents'] = Variable<int>(priceUsdCents.value);
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
    if (checkinNote.present) {
      map['checkin_note'] = Variable<String>(checkinNote.value);
    }
    if (checkinAt.present) {
      map['checkin_at'] = Variable<DateTime>(checkinAt.value);
    }
    if (stayGroup.present) {
      map['stay_group'] = Variable<String>(stayGroup.value);
    }
    if (payerId.present) {
      map['payer_id'] = Variable<int>(payerId.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (negotiatedPriceCents.present) {
      map['negotiated_price_cents'] = Variable<int>(negotiatedPriceCents.value);
    }
    if (currentStayId.present) {
      map['current_stay_id'] = Variable<int>(currentStayId.value);
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
          ..write('priceUsdCents: $priceUsdCents, ')
          ..write('pricePerNightCents: $pricePerNightCents, ')
          ..write('status: $status, ')
          ..write('currentGuest: $currentGuest, ')
          ..write('checkoutDate: $checkoutDate, ')
          ..write('checkinNote: $checkinNote, ')
          ..write('checkinAt: $checkinAt, ')
          ..write('stayGroup: $stayGroup, ')
          ..write('payerId: $payerId, ')
          ..write('imagePath: $imagePath, ')
          ..write('negotiatedPriceCents: $negotiatedPriceCents, ')
          ..write('currentStayId: $currentStayId, ')
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
  static const VerificationMeta _roomNumberMeta =
      const VerificationMeta('roomNumber');
  @override
  late final GeneratedColumn<String> roomNumber = GeneratedColumn<String>(
      'room_number', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _onCreditMeta =
      const VerificationMeta('onCredit');
  @override
  late final GeneratedColumn<bool> onCredit = GeneratedColumn<bool>(
      'on_credit', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("on_credit" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _settledAtMeta =
      const VerificationMeta('settledAt');
  @override
  late final GeneratedColumn<DateTime> settledAt = GeneratedColumn<DateTime>(
      'settled_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _syncAttemptsMeta =
      const VerificationMeta('syncAttempts');
  @override
  late final GeneratedColumn<int> syncAttempts = GeneratedColumn<int>(
      'sync_attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _syncErrorMeta =
      const VerificationMeta('syncError');
  @override
  late final GeneratedColumn<String> syncError = GeneratedColumn<String>(
      'sync_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _stayIdMeta = const VerificationMeta('stayId');
  @override
  late final GeneratedColumn<int> stayId = GeneratedColumn<int>(
      'stay_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES stays (id) ON DELETE SET NULL'));
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
      'uid', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      clientDefault: nouvelUid);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        soldAt,
        serverUserId,
        payment,
        location,
        customerName,
        roomNumber,
        onCredit,
        settledAt,
        note,
        syncedAt,
        syncAttempts,
        syncError,
        stayId,
        uid
      ];
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
    if (data.containsKey('room_number')) {
      context.handle(
          _roomNumberMeta,
          roomNumber.isAcceptableOrUnknown(
              data['room_number']!, _roomNumberMeta));
    }
    if (data.containsKey('on_credit')) {
      context.handle(_onCreditMeta,
          onCredit.isAcceptableOrUnknown(data['on_credit']!, _onCreditMeta));
    }
    if (data.containsKey('settled_at')) {
      context.handle(_settledAtMeta,
          settledAt.isAcceptableOrUnknown(data['settled_at']!, _settledAtMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    if (data.containsKey('sync_attempts')) {
      context.handle(
          _syncAttemptsMeta,
          syncAttempts.isAcceptableOrUnknown(
              data['sync_attempts']!, _syncAttemptsMeta));
    }
    if (data.containsKey('sync_error')) {
      context.handle(_syncErrorMeta,
          syncError.isAcceptableOrUnknown(data['sync_error']!, _syncErrorMeta));
    }
    if (data.containsKey('stay_id')) {
      context.handle(_stayIdMeta,
          stayId.isAcceptableOrUnknown(data['stay_id']!, _stayIdMeta));
    }
    if (data.containsKey('uid')) {
      context.handle(
          _uidMeta, uid.isAcceptableOrUnknown(data['uid']!, _uidMeta));
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
      roomNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}room_number']),
      onCredit: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}on_credit'])!,
      settledAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}settled_at']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at']),
      syncAttempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_attempts'])!,
      syncError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_error']),
      stayId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}stay_id']),
      uid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uid']),
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
  final String? roomNumber;
  final bool onCredit;
  final DateTime? settledAt;
  final String? note;

  /// Quand le serveur a confirmé. Null = pas encore en ligne.
  final DateTime? syncedAt;

  /// Tentatives infructueuses. Sert à espacer les renvois.
  final int syncAttempts;

  /// Pourquoi la dernière tentative a échoué. Gardé en clair : c'est la
  /// première chose qu'on regarde quand une caisse ne remonte plus.
  final String? syncError;

  /// Le séjour sur lequel cette consommation a été mise (v27). Remplace
  /// le rapprochement par numéro de chambre tapé, qui ne distinguait pas
  /// deux clients successifs de la même chambre. Null pour une vente
  /// ordinaire, ou reçue d'un autre poste.
  final int? stayId;

  /// Identité de la vente sur tous les postes (cf. core/identite.dart).
  /// `id` reste le numéro du ticket sur CE poste ; le serveur, lui, ne
  /// connaît la vente que par cet identifiant.
  ///
  /// Nullable pour pouvoir être ajouté à une base existante ; rempli à
  /// chaque insertion, et à l'ouverture pour les ventes plus anciennes.
  final String? uid;
  const Sale(
      {required this.id,
      required this.soldAt,
      this.serverUserId,
      required this.payment,
      required this.location,
      this.customerName,
      this.roomNumber,
      required this.onCredit,
      this.settledAt,
      this.note,
      this.syncedAt,
      required this.syncAttempts,
      this.syncError,
      this.stayId,
      this.uid});
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
    if (!nullToAbsent || roomNumber != null) {
      map['room_number'] = Variable<String>(roomNumber);
    }
    map['on_credit'] = Variable<bool>(onCredit);
    if (!nullToAbsent || settledAt != null) {
      map['settled_at'] = Variable<DateTime>(settledAt);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    map['sync_attempts'] = Variable<int>(syncAttempts);
    if (!nullToAbsent || syncError != null) {
      map['sync_error'] = Variable<String>(syncError);
    }
    if (!nullToAbsent || stayId != null) {
      map['stay_id'] = Variable<int>(stayId);
    }
    if (!nullToAbsent || uid != null) {
      map['uid'] = Variable<String>(uid);
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
      roomNumber: roomNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(roomNumber),
      onCredit: Value(onCredit),
      settledAt: settledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(settledAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      syncAttempts: Value(syncAttempts),
      syncError: syncError == null && nullToAbsent
          ? const Value.absent()
          : Value(syncError),
      stayId:
          stayId == null && nullToAbsent ? const Value.absent() : Value(stayId),
      uid: uid == null && nullToAbsent ? const Value.absent() : Value(uid),
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
      roomNumber: serializer.fromJson<String?>(json['roomNumber']),
      onCredit: serializer.fromJson<bool>(json['onCredit']),
      settledAt: serializer.fromJson<DateTime?>(json['settledAt']),
      note: serializer.fromJson<String?>(json['note']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      syncAttempts: serializer.fromJson<int>(json['syncAttempts']),
      syncError: serializer.fromJson<String?>(json['syncError']),
      stayId: serializer.fromJson<int?>(json['stayId']),
      uid: serializer.fromJson<String?>(json['uid']),
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
      'roomNumber': serializer.toJson<String?>(roomNumber),
      'onCredit': serializer.toJson<bool>(onCredit),
      'settledAt': serializer.toJson<DateTime?>(settledAt),
      'note': serializer.toJson<String?>(note),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'syncAttempts': serializer.toJson<int>(syncAttempts),
      'syncError': serializer.toJson<String?>(syncError),
      'stayId': serializer.toJson<int?>(stayId),
      'uid': serializer.toJson<String?>(uid),
    };
  }

  Sale copyWith(
          {int? id,
          DateTime? soldAt,
          Value<int?> serverUserId = const Value.absent(),
          DbPayment? payment,
          DbLocation? location,
          Value<String?> customerName = const Value.absent(),
          Value<String?> roomNumber = const Value.absent(),
          bool? onCredit,
          Value<DateTime?> settledAt = const Value.absent(),
          Value<String?> note = const Value.absent(),
          Value<DateTime?> syncedAt = const Value.absent(),
          int? syncAttempts,
          Value<String?> syncError = const Value.absent(),
          Value<int?> stayId = const Value.absent(),
          Value<String?> uid = const Value.absent()}) =>
      Sale(
        id: id ?? this.id,
        soldAt: soldAt ?? this.soldAt,
        serverUserId:
            serverUserId.present ? serverUserId.value : this.serverUserId,
        payment: payment ?? this.payment,
        location: location ?? this.location,
        customerName:
            customerName.present ? customerName.value : this.customerName,
        roomNumber: roomNumber.present ? roomNumber.value : this.roomNumber,
        onCredit: onCredit ?? this.onCredit,
        settledAt: settledAt.present ? settledAt.value : this.settledAt,
        note: note.present ? note.value : this.note,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
        syncAttempts: syncAttempts ?? this.syncAttempts,
        syncError: syncError.present ? syncError.value : this.syncError,
        stayId: stayId.present ? stayId.value : this.stayId,
        uid: uid.present ? uid.value : this.uid,
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
      roomNumber:
          data.roomNumber.present ? data.roomNumber.value : this.roomNumber,
      onCredit: data.onCredit.present ? data.onCredit.value : this.onCredit,
      settledAt: data.settledAt.present ? data.settledAt.value : this.settledAt,
      note: data.note.present ? data.note.value : this.note,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      syncAttempts: data.syncAttempts.present
          ? data.syncAttempts.value
          : this.syncAttempts,
      syncError: data.syncError.present ? data.syncError.value : this.syncError,
      stayId: data.stayId.present ? data.stayId.value : this.stayId,
      uid: data.uid.present ? data.uid.value : this.uid,
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
          ..write('roomNumber: $roomNumber, ')
          ..write('onCredit: $onCredit, ')
          ..write('settledAt: $settledAt, ')
          ..write('note: $note, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('syncAttempts: $syncAttempts, ')
          ..write('syncError: $syncError, ')
          ..write('stayId: $stayId, ')
          ..write('uid: $uid')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      soldAt,
      serverUserId,
      payment,
      location,
      customerName,
      roomNumber,
      onCredit,
      settledAt,
      note,
      syncedAt,
      syncAttempts,
      syncError,
      stayId,
      uid);
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
          other.roomNumber == this.roomNumber &&
          other.onCredit == this.onCredit &&
          other.settledAt == this.settledAt &&
          other.note == this.note &&
          other.syncedAt == this.syncedAt &&
          other.syncAttempts == this.syncAttempts &&
          other.syncError == this.syncError &&
          other.stayId == this.stayId &&
          other.uid == this.uid);
}

class SalesCompanion extends UpdateCompanion<Sale> {
  final Value<int> id;
  final Value<DateTime> soldAt;
  final Value<int?> serverUserId;
  final Value<DbPayment> payment;
  final Value<DbLocation> location;
  final Value<String?> customerName;
  final Value<String?> roomNumber;
  final Value<bool> onCredit;
  final Value<DateTime?> settledAt;
  final Value<String?> note;
  final Value<DateTime?> syncedAt;
  final Value<int> syncAttempts;
  final Value<String?> syncError;
  final Value<int?> stayId;
  final Value<String?> uid;
  const SalesCompanion({
    this.id = const Value.absent(),
    this.soldAt = const Value.absent(),
    this.serverUserId = const Value.absent(),
    this.payment = const Value.absent(),
    this.location = const Value.absent(),
    this.customerName = const Value.absent(),
    this.roomNumber = const Value.absent(),
    this.onCredit = const Value.absent(),
    this.settledAt = const Value.absent(),
    this.note = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.syncAttempts = const Value.absent(),
    this.syncError = const Value.absent(),
    this.stayId = const Value.absent(),
    this.uid = const Value.absent(),
  });
  SalesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime soldAt,
    this.serverUserId = const Value.absent(),
    required DbPayment payment,
    this.location = const Value.absent(),
    this.customerName = const Value.absent(),
    this.roomNumber = const Value.absent(),
    this.onCredit = const Value.absent(),
    this.settledAt = const Value.absent(),
    this.note = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.syncAttempts = const Value.absent(),
    this.syncError = const Value.absent(),
    this.stayId = const Value.absent(),
    this.uid = const Value.absent(),
  })  : soldAt = Value(soldAt),
        payment = Value(payment);
  static Insertable<Sale> custom({
    Expression<int>? id,
    Expression<DateTime>? soldAt,
    Expression<int>? serverUserId,
    Expression<int>? payment,
    Expression<int>? location,
    Expression<String>? customerName,
    Expression<String>? roomNumber,
    Expression<bool>? onCredit,
    Expression<DateTime>? settledAt,
    Expression<String>? note,
    Expression<DateTime>? syncedAt,
    Expression<int>? syncAttempts,
    Expression<String>? syncError,
    Expression<int>? stayId,
    Expression<String>? uid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (soldAt != null) 'sold_at': soldAt,
      if (serverUserId != null) 'server_user_id': serverUserId,
      if (payment != null) 'payment': payment,
      if (location != null) 'location': location,
      if (customerName != null) 'customer_name': customerName,
      if (roomNumber != null) 'room_number': roomNumber,
      if (onCredit != null) 'on_credit': onCredit,
      if (settledAt != null) 'settled_at': settledAt,
      if (note != null) 'note': note,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (syncAttempts != null) 'sync_attempts': syncAttempts,
      if (syncError != null) 'sync_error': syncError,
      if (stayId != null) 'stay_id': stayId,
      if (uid != null) 'uid': uid,
    });
  }

  SalesCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? soldAt,
      Value<int?>? serverUserId,
      Value<DbPayment>? payment,
      Value<DbLocation>? location,
      Value<String?>? customerName,
      Value<String?>? roomNumber,
      Value<bool>? onCredit,
      Value<DateTime?>? settledAt,
      Value<String?>? note,
      Value<DateTime?>? syncedAt,
      Value<int>? syncAttempts,
      Value<String?>? syncError,
      Value<int?>? stayId,
      Value<String?>? uid}) {
    return SalesCompanion(
      id: id ?? this.id,
      soldAt: soldAt ?? this.soldAt,
      serverUserId: serverUserId ?? this.serverUserId,
      payment: payment ?? this.payment,
      location: location ?? this.location,
      customerName: customerName ?? this.customerName,
      roomNumber: roomNumber ?? this.roomNumber,
      onCredit: onCredit ?? this.onCredit,
      settledAt: settledAt ?? this.settledAt,
      note: note ?? this.note,
      syncedAt: syncedAt ?? this.syncedAt,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      syncError: syncError ?? this.syncError,
      stayId: stayId ?? this.stayId,
      uid: uid ?? this.uid,
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
    if (roomNumber.present) {
      map['room_number'] = Variable<String>(roomNumber.value);
    }
    if (onCredit.present) {
      map['on_credit'] = Variable<bool>(onCredit.value);
    }
    if (settledAt.present) {
      map['settled_at'] = Variable<DateTime>(settledAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (syncAttempts.present) {
      map['sync_attempts'] = Variable<int>(syncAttempts.value);
    }
    if (syncError.present) {
      map['sync_error'] = Variable<String>(syncError.value);
    }
    if (stayId.present) {
      map['stay_id'] = Variable<int>(stayId.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
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
          ..write('roomNumber: $roomNumber, ')
          ..write('onCredit: $onCredit, ')
          ..write('settledAt: $settledAt, ')
          ..write('note: $note, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('syncAttempts: $syncAttempts, ')
          ..write('syncError: $syncError, ')
          ..write('stayId: $stayId, ')
          ..write('uid: $uid')
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
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
      'uid', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      clientDefault: nouvelUid);
  @override
  List<GeneratedColumn> get $columns =>
      [id, saleId, articleId, articleName, qty, unitPriceCents, uid];
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
    if (data.containsKey('uid')) {
      context.handle(
          _uidMeta, uid.isAcceptableOrUnknown(data['uid']!, _uidMeta));
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
      uid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uid']),
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

  /// Identité de la ligne sur tous les postes (même raison que
  /// [Sales.uid] : les numéros de ligne aussi se chevauchaient).
  final String? uid;
  const SaleLine(
      {required this.id,
      required this.saleId,
      this.articleId,
      required this.articleName,
      required this.qty,
      required this.unitPriceCents,
      this.uid});
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
    if (!nullToAbsent || uid != null) {
      map['uid'] = Variable<String>(uid);
    }
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
      uid: uid == null && nullToAbsent ? const Value.absent() : Value(uid),
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
      uid: serializer.fromJson<String?>(json['uid']),
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
      'uid': serializer.toJson<String?>(uid),
    };
  }

  SaleLine copyWith(
          {int? id,
          int? saleId,
          Value<int?> articleId = const Value.absent(),
          String? articleName,
          int? qty,
          int? unitPriceCents,
          Value<String?> uid = const Value.absent()}) =>
      SaleLine(
        id: id ?? this.id,
        saleId: saleId ?? this.saleId,
        articleId: articleId.present ? articleId.value : this.articleId,
        articleName: articleName ?? this.articleName,
        qty: qty ?? this.qty,
        unitPriceCents: unitPriceCents ?? this.unitPriceCents,
        uid: uid.present ? uid.value : this.uid,
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
      uid: data.uid.present ? data.uid.value : this.uid,
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
          ..write('unitPriceCents: $unitPriceCents, ')
          ..write('uid: $uid')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, saleId, articleId, articleName, qty, unitPriceCents, uid);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SaleLine &&
          other.id == this.id &&
          other.saleId == this.saleId &&
          other.articleId == this.articleId &&
          other.articleName == this.articleName &&
          other.qty == this.qty &&
          other.unitPriceCents == this.unitPriceCents &&
          other.uid == this.uid);
}

class SaleLinesCompanion extends UpdateCompanion<SaleLine> {
  final Value<int> id;
  final Value<int> saleId;
  final Value<int?> articleId;
  final Value<String> articleName;
  final Value<int> qty;
  final Value<int> unitPriceCents;
  final Value<String?> uid;
  const SaleLinesCompanion({
    this.id = const Value.absent(),
    this.saleId = const Value.absent(),
    this.articleId = const Value.absent(),
    this.articleName = const Value.absent(),
    this.qty = const Value.absent(),
    this.unitPriceCents = const Value.absent(),
    this.uid = const Value.absent(),
  });
  SaleLinesCompanion.insert({
    this.id = const Value.absent(),
    required int saleId,
    this.articleId = const Value.absent(),
    required String articleName,
    required int qty,
    required int unitPriceCents,
    this.uid = const Value.absent(),
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
    Expression<String>? uid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (saleId != null) 'sale_id': saleId,
      if (articleId != null) 'article_id': articleId,
      if (articleName != null) 'article_name': articleName,
      if (qty != null) 'qty': qty,
      if (unitPriceCents != null) 'unit_price_cents': unitPriceCents,
      if (uid != null) 'uid': uid,
    });
  }

  SaleLinesCompanion copyWith(
      {Value<int>? id,
      Value<int>? saleId,
      Value<int?>? articleId,
      Value<String>? articleName,
      Value<int>? qty,
      Value<int>? unitPriceCents,
      Value<String?>? uid}) {
    return SaleLinesCompanion(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      articleId: articleId ?? this.articleId,
      articleName: articleName ?? this.articleName,
      qty: qty ?? this.qty,
      unitPriceCents: unitPriceCents ?? this.unitPriceCents,
      uid: uid ?? this.uid,
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
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
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
          ..write('unitPriceCents: $unitPriceCents, ')
          ..write('uid: $uid')
          ..write(')'))
        .toString();
  }
}

class $DebtPaymentsTable extends DebtPayments
    with TableInfo<$DebtPaymentsTable, DebtPayment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DebtPaymentsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _amountCentsMeta =
      const VerificationMeta('amountCents');
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
      'amount_cents', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<DbPayment, int> payment =
      GeneratedColumn<int>('payment', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<DbPayment>($DebtPaymentsTable.$converterpayment);
  static const VerificationMeta _receivedAtMeta =
      const VerificationMeta('receivedAt');
  @override
  late final GeneratedColumn<DateTime> receivedAt = GeneratedColumn<DateTime>(
      'received_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _receivedByLoginMeta =
      const VerificationMeta('receivedByLogin');
  @override
  late final GeneratedColumn<String> receivedByLogin = GeneratedColumn<String>(
      'received_by_login', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, saleId, amountCents, payment, receivedAt, receivedByLogin, note];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'debt_payments';
  @override
  VerificationContext validateIntegrity(Insertable<DebtPayment> instance,
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
    if (data.containsKey('amount_cents')) {
      context.handle(
          _amountCentsMeta,
          amountCents.isAcceptableOrUnknown(
              data['amount_cents']!, _amountCentsMeta));
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('received_at')) {
      context.handle(
          _receivedAtMeta,
          receivedAt.isAcceptableOrUnknown(
              data['received_at']!, _receivedAtMeta));
    }
    if (data.containsKey('received_by_login')) {
      context.handle(
          _receivedByLoginMeta,
          receivedByLogin.isAcceptableOrUnknown(
              data['received_by_login']!, _receivedByLoginMeta));
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
  DebtPayment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DebtPayment(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      saleId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sale_id'])!,
      amountCents: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}amount_cents'])!,
      payment: $DebtPaymentsTable.$converterpayment.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}payment'])!),
      receivedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}received_at'])!,
      receivedByLogin: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}received_by_login']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
    );
  }

  @override
  $DebtPaymentsTable createAlias(String alias) {
    return $DebtPaymentsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DbPayment, int, int> $converterpayment =
      const EnumIndexConverter<DbPayment>(DbPayment.values);
}

class DebtPayment extends DataClass implements Insertable<DebtPayment> {
  final int id;
  final int saleId;

  /// Montant reçu, en cents. Toujours strictement positif : un
  /// remboursement au client s'enregistre comme une autre opération, pas
  /// comme un versement négatif qu'on oublierait de lire.
  final int amountCents;
  final DbPayment payment;
  final DateTime receivedAt;

  /// Qui a encaissé. Conservé en clair : un compte peut être supprimé,
  /// la trace du versement doit lui survivre.
  final String? receivedByLogin;
  final String? note;
  const DebtPayment(
      {required this.id,
      required this.saleId,
      required this.amountCents,
      required this.payment,
      required this.receivedAt,
      this.receivedByLogin,
      this.note});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['sale_id'] = Variable<int>(saleId);
    map['amount_cents'] = Variable<int>(amountCents);
    {
      map['payment'] =
          Variable<int>($DebtPaymentsTable.$converterpayment.toSql(payment));
    }
    map['received_at'] = Variable<DateTime>(receivedAt);
    if (!nullToAbsent || receivedByLogin != null) {
      map['received_by_login'] = Variable<String>(receivedByLogin);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  DebtPaymentsCompanion toCompanion(bool nullToAbsent) {
    return DebtPaymentsCompanion(
      id: Value(id),
      saleId: Value(saleId),
      amountCents: Value(amountCents),
      payment: Value(payment),
      receivedAt: Value(receivedAt),
      receivedByLogin: receivedByLogin == null && nullToAbsent
          ? const Value.absent()
          : Value(receivedByLogin),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory DebtPayment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DebtPayment(
      id: serializer.fromJson<int>(json['id']),
      saleId: serializer.fromJson<int>(json['saleId']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      payment: $DebtPaymentsTable.$converterpayment
          .fromJson(serializer.fromJson<int>(json['payment'])),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
      receivedByLogin: serializer.fromJson<String?>(json['receivedByLogin']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'saleId': serializer.toJson<int>(saleId),
      'amountCents': serializer.toJson<int>(amountCents),
      'payment': serializer
          .toJson<int>($DebtPaymentsTable.$converterpayment.toJson(payment)),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
      'receivedByLogin': serializer.toJson<String?>(receivedByLogin),
      'note': serializer.toJson<String?>(note),
    };
  }

  DebtPayment copyWith(
          {int? id,
          int? saleId,
          int? amountCents,
          DbPayment? payment,
          DateTime? receivedAt,
          Value<String?> receivedByLogin = const Value.absent(),
          Value<String?> note = const Value.absent()}) =>
      DebtPayment(
        id: id ?? this.id,
        saleId: saleId ?? this.saleId,
        amountCents: amountCents ?? this.amountCents,
        payment: payment ?? this.payment,
        receivedAt: receivedAt ?? this.receivedAt,
        receivedByLogin: receivedByLogin.present
            ? receivedByLogin.value
            : this.receivedByLogin,
        note: note.present ? note.value : this.note,
      );
  DebtPayment copyWithCompanion(DebtPaymentsCompanion data) {
    return DebtPayment(
      id: data.id.present ? data.id.value : this.id,
      saleId: data.saleId.present ? data.saleId.value : this.saleId,
      amountCents:
          data.amountCents.present ? data.amountCents.value : this.amountCents,
      payment: data.payment.present ? data.payment.value : this.payment,
      receivedAt:
          data.receivedAt.present ? data.receivedAt.value : this.receivedAt,
      receivedByLogin: data.receivedByLogin.present
          ? data.receivedByLogin.value
          : this.receivedByLogin,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DebtPayment(')
          ..write('id: $id, ')
          ..write('saleId: $saleId, ')
          ..write('amountCents: $amountCents, ')
          ..write('payment: $payment, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('receivedByLogin: $receivedByLogin, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, saleId, amountCents, payment, receivedAt, receivedByLogin, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DebtPayment &&
          other.id == this.id &&
          other.saleId == this.saleId &&
          other.amountCents == this.amountCents &&
          other.payment == this.payment &&
          other.receivedAt == this.receivedAt &&
          other.receivedByLogin == this.receivedByLogin &&
          other.note == this.note);
}

class DebtPaymentsCompanion extends UpdateCompanion<DebtPayment> {
  final Value<int> id;
  final Value<int> saleId;
  final Value<int> amountCents;
  final Value<DbPayment> payment;
  final Value<DateTime> receivedAt;
  final Value<String?> receivedByLogin;
  final Value<String?> note;
  const DebtPaymentsCompanion({
    this.id = const Value.absent(),
    this.saleId = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.payment = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.receivedByLogin = const Value.absent(),
    this.note = const Value.absent(),
  });
  DebtPaymentsCompanion.insert({
    this.id = const Value.absent(),
    required int saleId,
    required int amountCents,
    required DbPayment payment,
    this.receivedAt = const Value.absent(),
    this.receivedByLogin = const Value.absent(),
    this.note = const Value.absent(),
  })  : saleId = Value(saleId),
        amountCents = Value(amountCents),
        payment = Value(payment);
  static Insertable<DebtPayment> custom({
    Expression<int>? id,
    Expression<int>? saleId,
    Expression<int>? amountCents,
    Expression<int>? payment,
    Expression<DateTime>? receivedAt,
    Expression<String>? receivedByLogin,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (saleId != null) 'sale_id': saleId,
      if (amountCents != null) 'amount_cents': amountCents,
      if (payment != null) 'payment': payment,
      if (receivedAt != null) 'received_at': receivedAt,
      if (receivedByLogin != null) 'received_by_login': receivedByLogin,
      if (note != null) 'note': note,
    });
  }

  DebtPaymentsCompanion copyWith(
      {Value<int>? id,
      Value<int>? saleId,
      Value<int>? amountCents,
      Value<DbPayment>? payment,
      Value<DateTime>? receivedAt,
      Value<String?>? receivedByLogin,
      Value<String?>? note}) {
    return DebtPaymentsCompanion(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      amountCents: amountCents ?? this.amountCents,
      payment: payment ?? this.payment,
      receivedAt: receivedAt ?? this.receivedAt,
      receivedByLogin: receivedByLogin ?? this.receivedByLogin,
      note: note ?? this.note,
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
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (payment.present) {
      map['payment'] = Variable<int>(
          $DebtPaymentsTable.$converterpayment.toSql(payment.value));
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (receivedByLogin.present) {
      map['received_by_login'] = Variable<String>(receivedByLogin.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DebtPaymentsCompanion(')
          ..write('id: $id, ')
          ..write('saleId: $saleId, ')
          ..write('amountCents: $amountCents, ')
          ..write('payment: $payment, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('receivedByLogin: $receivedByLogin, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $StockMovesTable extends StockMoves
    with TableInfo<$StockMovesTable, StockMove> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockMovesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _opIdMeta = const VerificationMeta('opId');
  @override
  late final GeneratedColumn<String> opId = GeneratedColumn<String>(
      'op_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _articleIdMeta =
      const VerificationMeta('articleId');
  @override
  late final GeneratedColumn<int> articleId = GeneratedColumn<int>(
      'article_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _deltaMeta = const VerificationMeta('delta');
  @override
  late final GeneratedColumn<int> delta = GeneratedColumn<int>(
      'delta', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
      'reason', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _occurredAtMeta =
      const VerificationMeta('occurredAt');
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
      'occurred_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _sentAtMeta = const VerificationMeta('sentAt');
  @override
  late final GeneratedColumn<DateTime> sentAt = GeneratedColumn<DateTime>(
      'sent_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [opId, articleId, delta, reason, occurredAt, sentAt, attempts, lastError];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_moves';
  @override
  VerificationContext validateIntegrity(Insertable<StockMove> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('op_id')) {
      context.handle(
          _opIdMeta, opId.isAcceptableOrUnknown(data['op_id']!, _opIdMeta));
    } else if (isInserting) {
      context.missing(_opIdMeta);
    }
    if (data.containsKey('article_id')) {
      context.handle(_articleIdMeta,
          articleId.isAcceptableOrUnknown(data['article_id']!, _articleIdMeta));
    } else if (isInserting) {
      context.missing(_articleIdMeta);
    }
    if (data.containsKey('delta')) {
      context.handle(
          _deltaMeta, delta.isAcceptableOrUnknown(data['delta']!, _deltaMeta));
    } else if (isInserting) {
      context.missing(_deltaMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(_reasonMeta,
          reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta));
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
          _occurredAtMeta,
          occurredAt.isAcceptableOrUnknown(
              data['occurred_at']!, _occurredAtMeta));
    }
    if (data.containsKey('sent_at')) {
      context.handle(_sentAtMeta,
          sentAt.isAcceptableOrUnknown(data['sent_at']!, _sentAtMeta));
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {opId};
  @override
  StockMove map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockMove(
      opId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}op_id'])!,
      articleId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}article_id'])!,
      delta: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}delta'])!,
      reason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reason']),
      occurredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}occurred_at'])!,
      sentAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}sent_at']),
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
    );
  }

  @override
  $StockMovesTable createAlias(String alias) {
    return $StockMovesTable(attachedDatabase, alias);
  }
}

class StockMove extends DataClass implements Insertable<StockMove> {
  /// Identifiant généré ICI, avant tout envoi. C'est lui qui permet au
  /// serveur d'ignorer un doublon : une coupure juste après
  /// l'enregistrement serveur, mais avant l'accusé de réception, fait
  /// renvoyer le poste. Sans cette clé, le stock bougerait deux fois.
  final String opId;
  final int articleId;

  /// Signé. Négatif pour une sortie, positif pour un ravitaillement.
  final int delta;

  /// « vente », « ravitaillement », « correction »… Remonte au serveur
  /// pour que le gérant sache d'où vient le mouvement.
  final String? reason;
  final DateTime occurredAt;

  /// Null tant que le serveur ne l'a pas confirmé.
  final DateTime? sentAt;

  /// Nombre d'échecs d'envoi. Sert à espacer les tentatives plutôt qu'à
  /// marteler un serveur injoignable.
  final int attempts;

  /// Dernier refus du serveur, quand il y en a un. Affiché au gérant :
  /// un mouvement bloqué ne doit jamais disparaître en silence.
  final String? lastError;
  const StockMove(
      {required this.opId,
      required this.articleId,
      required this.delta,
      this.reason,
      required this.occurredAt,
      this.sentAt,
      required this.attempts,
      this.lastError});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['op_id'] = Variable<String>(opId);
    map['article_id'] = Variable<int>(articleId);
    map['delta'] = Variable<int>(delta);
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    if (!nullToAbsent || sentAt != null) {
      map['sent_at'] = Variable<DateTime>(sentAt);
    }
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  StockMovesCompanion toCompanion(bool nullToAbsent) {
    return StockMovesCompanion(
      opId: Value(opId),
      articleId: Value(articleId),
      delta: Value(delta),
      reason:
          reason == null && nullToAbsent ? const Value.absent() : Value(reason),
      occurredAt: Value(occurredAt),
      sentAt:
          sentAt == null && nullToAbsent ? const Value.absent() : Value(sentAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory StockMove.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockMove(
      opId: serializer.fromJson<String>(json['opId']),
      articleId: serializer.fromJson<int>(json['articleId']),
      delta: serializer.fromJson<int>(json['delta']),
      reason: serializer.fromJson<String?>(json['reason']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      sentAt: serializer.fromJson<DateTime?>(json['sentAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'opId': serializer.toJson<String>(opId),
      'articleId': serializer.toJson<int>(articleId),
      'delta': serializer.toJson<int>(delta),
      'reason': serializer.toJson<String?>(reason),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'sentAt': serializer.toJson<DateTime?>(sentAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  StockMove copyWith(
          {String? opId,
          int? articleId,
          int? delta,
          Value<String?> reason = const Value.absent(),
          DateTime? occurredAt,
          Value<DateTime?> sentAt = const Value.absent(),
          int? attempts,
          Value<String?> lastError = const Value.absent()}) =>
      StockMove(
        opId: opId ?? this.opId,
        articleId: articleId ?? this.articleId,
        delta: delta ?? this.delta,
        reason: reason.present ? reason.value : this.reason,
        occurredAt: occurredAt ?? this.occurredAt,
        sentAt: sentAt.present ? sentAt.value : this.sentAt,
        attempts: attempts ?? this.attempts,
        lastError: lastError.present ? lastError.value : this.lastError,
      );
  StockMove copyWithCompanion(StockMovesCompanion data) {
    return StockMove(
      opId: data.opId.present ? data.opId.value : this.opId,
      articleId: data.articleId.present ? data.articleId.value : this.articleId,
      delta: data.delta.present ? data.delta.value : this.delta,
      reason: data.reason.present ? data.reason.value : this.reason,
      occurredAt:
          data.occurredAt.present ? data.occurredAt.value : this.occurredAt,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockMove(')
          ..write('opId: $opId, ')
          ..write('articleId: $articleId, ')
          ..write('delta: $delta, ')
          ..write('reason: $reason, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('sentAt: $sentAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      opId, articleId, delta, reason, occurredAt, sentAt, attempts, lastError);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockMove &&
          other.opId == this.opId &&
          other.articleId == this.articleId &&
          other.delta == this.delta &&
          other.reason == this.reason &&
          other.occurredAt == this.occurredAt &&
          other.sentAt == this.sentAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError);
}

class StockMovesCompanion extends UpdateCompanion<StockMove> {
  final Value<String> opId;
  final Value<int> articleId;
  final Value<int> delta;
  final Value<String?> reason;
  final Value<DateTime> occurredAt;
  final Value<DateTime?> sentAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<int> rowid;
  const StockMovesCompanion({
    this.opId = const Value.absent(),
    this.articleId = const Value.absent(),
    this.delta = const Value.absent(),
    this.reason = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StockMovesCompanion.insert({
    required String opId,
    required int articleId,
    required int delta,
    this.reason = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : opId = Value(opId),
        articleId = Value(articleId),
        delta = Value(delta);
  static Insertable<StockMove> custom({
    Expression<String>? opId,
    Expression<int>? articleId,
    Expression<int>? delta,
    Expression<String>? reason,
    Expression<DateTime>? occurredAt,
    Expression<DateTime>? sentAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (opId != null) 'op_id': opId,
      if (articleId != null) 'article_id': articleId,
      if (delta != null) 'delta': delta,
      if (reason != null) 'reason': reason,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (sentAt != null) 'sent_at': sentAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StockMovesCompanion copyWith(
      {Value<String>? opId,
      Value<int>? articleId,
      Value<int>? delta,
      Value<String?>? reason,
      Value<DateTime>? occurredAt,
      Value<DateTime?>? sentAt,
      Value<int>? attempts,
      Value<String?>? lastError,
      Value<int>? rowid}) {
    return StockMovesCompanion(
      opId: opId ?? this.opId,
      articleId: articleId ?? this.articleId,
      delta: delta ?? this.delta,
      reason: reason ?? this.reason,
      occurredAt: occurredAt ?? this.occurredAt,
      sentAt: sentAt ?? this.sentAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (opId.present) {
      map['op_id'] = Variable<String>(opId.value);
    }
    if (articleId.present) {
      map['article_id'] = Variable<int>(articleId.value);
    }
    if (delta.present) {
      map['delta'] = Variable<int>(delta.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<DateTime>(sentAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockMovesCompanion(')
          ..write('opId: $opId, ')
          ..write('articleId: $articleId, ')
          ..write('delta: $delta, ')
          ..write('reason: $reason, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('sentAt: $sentAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClientsTable extends Clients with TableInfo<$ClientsTable, Client> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClientsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
      'phone', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _firstSeenAtMeta =
      const VerificationMeta('firstSeenAt');
  @override
  late final GeneratedColumn<DateTime> firstSeenAt = GeneratedColumn<DateTime>(
      'first_seen_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _lastSeenAtMeta =
      const VerificationMeta('lastSeenAt');
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
      'last_seen_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _visitsCountMeta =
      const VerificationMeta('visitsCount');
  @override
  late final GeneratedColumn<int> visitsCount = GeneratedColumn<int>(
      'visits_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _totalSpentCentsMeta =
      const VerificationMeta('totalSpentCents');
  @override
  late final GeneratedColumn<int> totalSpentCents = GeneratedColumn<int>(
      'total_spent_cents', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        fullName,
        phone,
        email,
        notes,
        firstSeenAt,
        lastSeenAt,
        visitsCount,
        totalSpentCents
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clients';
  @override
  VerificationContext validateIntegrity(Insertable<Client> instance,
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
    if (data.containsKey('phone')) {
      context.handle(
          _phoneMeta, phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta));
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('first_seen_at')) {
      context.handle(
          _firstSeenAtMeta,
          firstSeenAt.isAcceptableOrUnknown(
              data['first_seen_at']!, _firstSeenAtMeta));
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
          _lastSeenAtMeta,
          lastSeenAt.isAcceptableOrUnknown(
              data['last_seen_at']!, _lastSeenAtMeta));
    }
    if (data.containsKey('visits_count')) {
      context.handle(
          _visitsCountMeta,
          visitsCount.isAcceptableOrUnknown(
              data['visits_count']!, _visitsCountMeta));
    }
    if (data.containsKey('total_spent_cents')) {
      context.handle(
          _totalSpentCentsMeta,
          totalSpentCents.isAcceptableOrUnknown(
              data['total_spent_cents']!, _totalSpentCentsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Client map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Client(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      fullName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}full_name'])!,
      phone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone']),
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      firstSeenAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}first_seen_at'])!,
      lastSeenAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_seen_at'])!,
      visitsCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}visits_count'])!,
      totalSpentCents: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_spent_cents'])!,
    );
  }

  @override
  $ClientsTable createAlias(String alias) {
    return $ClientsTable(attachedDatabase, alias);
  }
}

class Client extends DataClass implements Insertable<Client> {
  final int id;
  final String fullName;
  final String? phone;
  final String? email;
  final String? notes;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final int visitsCount;
  final int totalSpentCents;
  const Client(
      {required this.id,
      required this.fullName,
      this.phone,
      this.email,
      this.notes,
      required this.firstSeenAt,
      required this.lastSeenAt,
      required this.visitsCount,
      required this.totalSpentCents});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['full_name'] = Variable<String>(fullName);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['first_seen_at'] = Variable<DateTime>(firstSeenAt);
    map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    map['visits_count'] = Variable<int>(visitsCount);
    map['total_spent_cents'] = Variable<int>(totalSpentCents);
    return map;
  }

  ClientsCompanion toCompanion(bool nullToAbsent) {
    return ClientsCompanion(
      id: Value(id),
      fullName: Value(fullName),
      phone:
          phone == null && nullToAbsent ? const Value.absent() : Value(phone),
      email:
          email == null && nullToAbsent ? const Value.absent() : Value(email),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      firstSeenAt: Value(firstSeenAt),
      lastSeenAt: Value(lastSeenAt),
      visitsCount: Value(visitsCount),
      totalSpentCents: Value(totalSpentCents),
    );
  }

  factory Client.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Client(
      id: serializer.fromJson<int>(json['id']),
      fullName: serializer.fromJson<String>(json['fullName']),
      phone: serializer.fromJson<String?>(json['phone']),
      email: serializer.fromJson<String?>(json['email']),
      notes: serializer.fromJson<String?>(json['notes']),
      firstSeenAt: serializer.fromJson<DateTime>(json['firstSeenAt']),
      lastSeenAt: serializer.fromJson<DateTime>(json['lastSeenAt']),
      visitsCount: serializer.fromJson<int>(json['visitsCount']),
      totalSpentCents: serializer.fromJson<int>(json['totalSpentCents']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fullName': serializer.toJson<String>(fullName),
      'phone': serializer.toJson<String?>(phone),
      'email': serializer.toJson<String?>(email),
      'notes': serializer.toJson<String?>(notes),
      'firstSeenAt': serializer.toJson<DateTime>(firstSeenAt),
      'lastSeenAt': serializer.toJson<DateTime>(lastSeenAt),
      'visitsCount': serializer.toJson<int>(visitsCount),
      'totalSpentCents': serializer.toJson<int>(totalSpentCents),
    };
  }

  Client copyWith(
          {int? id,
          String? fullName,
          Value<String?> phone = const Value.absent(),
          Value<String?> email = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          DateTime? firstSeenAt,
          DateTime? lastSeenAt,
          int? visitsCount,
          int? totalSpentCents}) =>
      Client(
        id: id ?? this.id,
        fullName: fullName ?? this.fullName,
        phone: phone.present ? phone.value : this.phone,
        email: email.present ? email.value : this.email,
        notes: notes.present ? notes.value : this.notes,
        firstSeenAt: firstSeenAt ?? this.firstSeenAt,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        visitsCount: visitsCount ?? this.visitsCount,
        totalSpentCents: totalSpentCents ?? this.totalSpentCents,
      );
  Client copyWithCompanion(ClientsCompanion data) {
    return Client(
      id: data.id.present ? data.id.value : this.id,
      fullName: data.fullName.present ? data.fullName.value : this.fullName,
      phone: data.phone.present ? data.phone.value : this.phone,
      email: data.email.present ? data.email.value : this.email,
      notes: data.notes.present ? data.notes.value : this.notes,
      firstSeenAt:
          data.firstSeenAt.present ? data.firstSeenAt.value : this.firstSeenAt,
      lastSeenAt:
          data.lastSeenAt.present ? data.lastSeenAt.value : this.lastSeenAt,
      visitsCount:
          data.visitsCount.present ? data.visitsCount.value : this.visitsCount,
      totalSpentCents: data.totalSpentCents.present
          ? data.totalSpentCents.value
          : this.totalSpentCents,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Client(')
          ..write('id: $id, ')
          ..write('fullName: $fullName, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('notes: $notes, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('visitsCount: $visitsCount, ')
          ..write('totalSpentCents: $totalSpentCents')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, fullName, phone, email, notes,
      firstSeenAt, lastSeenAt, visitsCount, totalSpentCents);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Client &&
          other.id == this.id &&
          other.fullName == this.fullName &&
          other.phone == this.phone &&
          other.email == this.email &&
          other.notes == this.notes &&
          other.firstSeenAt == this.firstSeenAt &&
          other.lastSeenAt == this.lastSeenAt &&
          other.visitsCount == this.visitsCount &&
          other.totalSpentCents == this.totalSpentCents);
}

class ClientsCompanion extends UpdateCompanion<Client> {
  final Value<int> id;
  final Value<String> fullName;
  final Value<String?> phone;
  final Value<String?> email;
  final Value<String?> notes;
  final Value<DateTime> firstSeenAt;
  final Value<DateTime> lastSeenAt;
  final Value<int> visitsCount;
  final Value<int> totalSpentCents;
  const ClientsCompanion({
    this.id = const Value.absent(),
    this.fullName = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.notes = const Value.absent(),
    this.firstSeenAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.visitsCount = const Value.absent(),
    this.totalSpentCents = const Value.absent(),
  });
  ClientsCompanion.insert({
    this.id = const Value.absent(),
    required String fullName,
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.notes = const Value.absent(),
    this.firstSeenAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.visitsCount = const Value.absent(),
    this.totalSpentCents = const Value.absent(),
  }) : fullName = Value(fullName);
  static Insertable<Client> custom({
    Expression<int>? id,
    Expression<String>? fullName,
    Expression<String>? phone,
    Expression<String>? email,
    Expression<String>? notes,
    Expression<DateTime>? firstSeenAt,
    Expression<DateTime>? lastSeenAt,
    Expression<int>? visitsCount,
    Expression<int>? totalSpentCents,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fullName != null) 'full_name': fullName,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (notes != null) 'notes': notes,
      if (firstSeenAt != null) 'first_seen_at': firstSeenAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (visitsCount != null) 'visits_count': visitsCount,
      if (totalSpentCents != null) 'total_spent_cents': totalSpentCents,
    });
  }

  ClientsCompanion copyWith(
      {Value<int>? id,
      Value<String>? fullName,
      Value<String?>? phone,
      Value<String?>? email,
      Value<String?>? notes,
      Value<DateTime>? firstSeenAt,
      Value<DateTime>? lastSeenAt,
      Value<int>? visitsCount,
      Value<int>? totalSpentCents}) {
    return ClientsCompanion(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      visitsCount: visitsCount ?? this.visitsCount,
      totalSpentCents: totalSpentCents ?? this.totalSpentCents,
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
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (firstSeenAt.present) {
      map['first_seen_at'] = Variable<DateTime>(firstSeenAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (visitsCount.present) {
      map['visits_count'] = Variable<int>(visitsCount.value);
    }
    if (totalSpentCents.present) {
      map['total_spent_cents'] = Variable<int>(totalSpentCents.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClientsCompanion(')
          ..write('id: $id, ')
          ..write('fullName: $fullName, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('notes: $notes, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('visitsCount: $visitsCount, ')
          ..write('totalSpentCents: $totalSpentCents')
          ..write(')'))
        .toString();
  }
}

class $StayRoomsTable extends StayRooms
    with TableInfo<$StayRoomsTable, StayRoom> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StayRoomsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _stayIdMeta = const VerificationMeta('stayId');
  @override
  late final GeneratedColumn<int> stayId = GeneratedColumn<int>(
      'stay_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES stays (id) ON DELETE CASCADE'));
  static const VerificationMeta _roomNumberMeta =
      const VerificationMeta('roomNumber');
  @override
  late final GeneratedColumn<String> roomNumber = GeneratedColumn<String>(
      'room_number', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _roomTypeMeta =
      const VerificationMeta('roomType');
  @override
  late final GeneratedColumn<String> roomType = GeneratedColumn<String>(
      'room_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _checkinAtMeta =
      const VerificationMeta('checkinAt');
  @override
  late final GeneratedColumn<DateTime> checkinAt = GeneratedColumn<DateTime>(
      'checkin_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _checkoutAtMeta =
      const VerificationMeta('checkoutAt');
  @override
  late final GeneratedColumn<DateTime> checkoutAt = GeneratedColumn<DateTime>(
      'checkout_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _pricePerNightCentsMeta =
      const VerificationMeta('pricePerNightCents');
  @override
  late final GeneratedColumn<int> pricePerNightCents = GeneratedColumn<int>(
      'price_per_night_cents', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _priceUsdCentsMeta =
      const VerificationMeta('priceUsdCents');
  @override
  late final GeneratedColumn<int> priceUsdCents = GeneratedColumn<int>(
      'price_usd_cents', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _listPriceCentsMeta =
      const VerificationMeta('listPriceCents');
  @override
  late final GeneratedColumn<int> listPriceCents = GeneratedColumn<int>(
      'list_price_cents', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _listUsdCentsMeta =
      const VerificationMeta('listUsdCents');
  @override
  late final GeneratedColumn<int> listUsdCents = GeneratedColumn<int>(
      'list_usd_cents', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _nightsMeta = const VerificationMeta('nights');
  @override
  late final GeneratedColumn<int> nights = GeneratedColumn<int>(
      'nights', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
      'uid', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      clientDefault: nouvelUid);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        stayId,
        roomNumber,
        roomType,
        checkinAt,
        checkoutAt,
        pricePerNightCents,
        priceUsdCents,
        listPriceCents,
        listUsdCents,
        nights,
        uid
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stay_rooms';
  @override
  VerificationContext validateIntegrity(Insertable<StayRoom> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('stay_id')) {
      context.handle(_stayIdMeta,
          stayId.isAcceptableOrUnknown(data['stay_id']!, _stayIdMeta));
    } else if (isInserting) {
      context.missing(_stayIdMeta);
    }
    if (data.containsKey('room_number')) {
      context.handle(
          _roomNumberMeta,
          roomNumber.isAcceptableOrUnknown(
              data['room_number']!, _roomNumberMeta));
    } else if (isInserting) {
      context.missing(_roomNumberMeta);
    }
    if (data.containsKey('room_type')) {
      context.handle(_roomTypeMeta,
          roomType.isAcceptableOrUnknown(data['room_type']!, _roomTypeMeta));
    } else if (isInserting) {
      context.missing(_roomTypeMeta);
    }
    if (data.containsKey('checkin_at')) {
      context.handle(_checkinAtMeta,
          checkinAt.isAcceptableOrUnknown(data['checkin_at']!, _checkinAtMeta));
    } else if (isInserting) {
      context.missing(_checkinAtMeta);
    }
    if (data.containsKey('checkout_at')) {
      context.handle(
          _checkoutAtMeta,
          checkoutAt.isAcceptableOrUnknown(
              data['checkout_at']!, _checkoutAtMeta));
    } else if (isInserting) {
      context.missing(_checkoutAtMeta);
    }
    if (data.containsKey('price_per_night_cents')) {
      context.handle(
          _pricePerNightCentsMeta,
          pricePerNightCents.isAcceptableOrUnknown(
              data['price_per_night_cents']!, _pricePerNightCentsMeta));
    } else if (isInserting) {
      context.missing(_pricePerNightCentsMeta);
    }
    if (data.containsKey('price_usd_cents')) {
      context.handle(
          _priceUsdCentsMeta,
          priceUsdCents.isAcceptableOrUnknown(
              data['price_usd_cents']!, _priceUsdCentsMeta));
    }
    if (data.containsKey('list_price_cents')) {
      context.handle(
          _listPriceCentsMeta,
          listPriceCents.isAcceptableOrUnknown(
              data['list_price_cents']!, _listPriceCentsMeta));
    }
    if (data.containsKey('list_usd_cents')) {
      context.handle(
          _listUsdCentsMeta,
          listUsdCents.isAcceptableOrUnknown(
              data['list_usd_cents']!, _listUsdCentsMeta));
    }
    if (data.containsKey('nights')) {
      context.handle(_nightsMeta,
          nights.isAcceptableOrUnknown(data['nights']!, _nightsMeta));
    } else if (isInserting) {
      context.missing(_nightsMeta);
    }
    if (data.containsKey('uid')) {
      context.handle(
          _uidMeta, uid.isAcceptableOrUnknown(data['uid']!, _uidMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StayRoom map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StayRoom(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      stayId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}stay_id'])!,
      roomNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}room_number'])!,
      roomType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}room_type'])!,
      checkinAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}checkin_at'])!,
      checkoutAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}checkout_at'])!,
      pricePerNightCents: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}price_per_night_cents'])!,
      priceUsdCents: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}price_usd_cents'])!,
      listPriceCents: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}list_price_cents']),
      listUsdCents: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}list_usd_cents']),
      nights: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}nights'])!,
      uid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uid']),
    );
  }

  @override
  $StayRoomsTable createAlias(String alias) {
    return $StayRoomsTable(attachedDatabase, alias);
  }
}

class StayRoom extends DataClass implements Insertable<StayRoom> {
  final int id;
  final int stayId;
  final String roomNumber;
  final String roomType;
  final DateTime checkinAt;
  final DateTime checkoutAt;

  /// Prix réellement facturé, en FRANCS (tarif négocié s'il y en avait
  /// un). Figé au check-out : c'est le montant encaissé.
  final int pricePerNightCents;

  /// Le même prix en CENTS DE DOLLAR, figé lui aussi.
  ///
  /// On garde les deux plutôt que de reconvertir à l'affichage : le taux
  /// bouge, et une facture réimprimée six mois plus tard doit annoncer
  /// le montant que le client a payé — pas ce qu'il vaudrait aujourd'hui.
  final int priceUsdCents;

  /// Tarif catalogue au moment du check-out. Null ou égal au prix
  /// facturé → aucun tarif négocié sur cette chambre.
  final int? listPriceCents;

  /// Le tarif catalogue en dollars, pour afficher la remise dans la
  /// devise où elle a été négociée.
  final int? listUsdCents;
  final int nights;

  /// Identité de la ligne sur tous les postes.
  final String? uid;
  const StayRoom(
      {required this.id,
      required this.stayId,
      required this.roomNumber,
      required this.roomType,
      required this.checkinAt,
      required this.checkoutAt,
      required this.pricePerNightCents,
      required this.priceUsdCents,
      this.listPriceCents,
      this.listUsdCents,
      required this.nights,
      this.uid});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['stay_id'] = Variable<int>(stayId);
    map['room_number'] = Variable<String>(roomNumber);
    map['room_type'] = Variable<String>(roomType);
    map['checkin_at'] = Variable<DateTime>(checkinAt);
    map['checkout_at'] = Variable<DateTime>(checkoutAt);
    map['price_per_night_cents'] = Variable<int>(pricePerNightCents);
    map['price_usd_cents'] = Variable<int>(priceUsdCents);
    if (!nullToAbsent || listPriceCents != null) {
      map['list_price_cents'] = Variable<int>(listPriceCents);
    }
    if (!nullToAbsent || listUsdCents != null) {
      map['list_usd_cents'] = Variable<int>(listUsdCents);
    }
    map['nights'] = Variable<int>(nights);
    if (!nullToAbsent || uid != null) {
      map['uid'] = Variable<String>(uid);
    }
    return map;
  }

  StayRoomsCompanion toCompanion(bool nullToAbsent) {
    return StayRoomsCompanion(
      id: Value(id),
      stayId: Value(stayId),
      roomNumber: Value(roomNumber),
      roomType: Value(roomType),
      checkinAt: Value(checkinAt),
      checkoutAt: Value(checkoutAt),
      pricePerNightCents: Value(pricePerNightCents),
      priceUsdCents: Value(priceUsdCents),
      listPriceCents: listPriceCents == null && nullToAbsent
          ? const Value.absent()
          : Value(listPriceCents),
      listUsdCents: listUsdCents == null && nullToAbsent
          ? const Value.absent()
          : Value(listUsdCents),
      nights: Value(nights),
      uid: uid == null && nullToAbsent ? const Value.absent() : Value(uid),
    );
  }

  factory StayRoom.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StayRoom(
      id: serializer.fromJson<int>(json['id']),
      stayId: serializer.fromJson<int>(json['stayId']),
      roomNumber: serializer.fromJson<String>(json['roomNumber']),
      roomType: serializer.fromJson<String>(json['roomType']),
      checkinAt: serializer.fromJson<DateTime>(json['checkinAt']),
      checkoutAt: serializer.fromJson<DateTime>(json['checkoutAt']),
      pricePerNightCents: serializer.fromJson<int>(json['pricePerNightCents']),
      priceUsdCents: serializer.fromJson<int>(json['priceUsdCents']),
      listPriceCents: serializer.fromJson<int?>(json['listPriceCents']),
      listUsdCents: serializer.fromJson<int?>(json['listUsdCents']),
      nights: serializer.fromJson<int>(json['nights']),
      uid: serializer.fromJson<String?>(json['uid']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'stayId': serializer.toJson<int>(stayId),
      'roomNumber': serializer.toJson<String>(roomNumber),
      'roomType': serializer.toJson<String>(roomType),
      'checkinAt': serializer.toJson<DateTime>(checkinAt),
      'checkoutAt': serializer.toJson<DateTime>(checkoutAt),
      'pricePerNightCents': serializer.toJson<int>(pricePerNightCents),
      'priceUsdCents': serializer.toJson<int>(priceUsdCents),
      'listPriceCents': serializer.toJson<int?>(listPriceCents),
      'listUsdCents': serializer.toJson<int?>(listUsdCents),
      'nights': serializer.toJson<int>(nights),
      'uid': serializer.toJson<String?>(uid),
    };
  }

  StayRoom copyWith(
          {int? id,
          int? stayId,
          String? roomNumber,
          String? roomType,
          DateTime? checkinAt,
          DateTime? checkoutAt,
          int? pricePerNightCents,
          int? priceUsdCents,
          Value<int?> listPriceCents = const Value.absent(),
          Value<int?> listUsdCents = const Value.absent(),
          int? nights,
          Value<String?> uid = const Value.absent()}) =>
      StayRoom(
        id: id ?? this.id,
        stayId: stayId ?? this.stayId,
        roomNumber: roomNumber ?? this.roomNumber,
        roomType: roomType ?? this.roomType,
        checkinAt: checkinAt ?? this.checkinAt,
        checkoutAt: checkoutAt ?? this.checkoutAt,
        pricePerNightCents: pricePerNightCents ?? this.pricePerNightCents,
        priceUsdCents: priceUsdCents ?? this.priceUsdCents,
        listPriceCents:
            listPriceCents.present ? listPriceCents.value : this.listPriceCents,
        listUsdCents:
            listUsdCents.present ? listUsdCents.value : this.listUsdCents,
        nights: nights ?? this.nights,
        uid: uid.present ? uid.value : this.uid,
      );
  StayRoom copyWithCompanion(StayRoomsCompanion data) {
    return StayRoom(
      id: data.id.present ? data.id.value : this.id,
      stayId: data.stayId.present ? data.stayId.value : this.stayId,
      roomNumber:
          data.roomNumber.present ? data.roomNumber.value : this.roomNumber,
      roomType: data.roomType.present ? data.roomType.value : this.roomType,
      checkinAt: data.checkinAt.present ? data.checkinAt.value : this.checkinAt,
      checkoutAt:
          data.checkoutAt.present ? data.checkoutAt.value : this.checkoutAt,
      pricePerNightCents: data.pricePerNightCents.present
          ? data.pricePerNightCents.value
          : this.pricePerNightCents,
      priceUsdCents: data.priceUsdCents.present
          ? data.priceUsdCents.value
          : this.priceUsdCents,
      listPriceCents: data.listPriceCents.present
          ? data.listPriceCents.value
          : this.listPriceCents,
      listUsdCents: data.listUsdCents.present
          ? data.listUsdCents.value
          : this.listUsdCents,
      nights: data.nights.present ? data.nights.value : this.nights,
      uid: data.uid.present ? data.uid.value : this.uid,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StayRoom(')
          ..write('id: $id, ')
          ..write('stayId: $stayId, ')
          ..write('roomNumber: $roomNumber, ')
          ..write('roomType: $roomType, ')
          ..write('checkinAt: $checkinAt, ')
          ..write('checkoutAt: $checkoutAt, ')
          ..write('pricePerNightCents: $pricePerNightCents, ')
          ..write('priceUsdCents: $priceUsdCents, ')
          ..write('listPriceCents: $listPriceCents, ')
          ..write('listUsdCents: $listUsdCents, ')
          ..write('nights: $nights, ')
          ..write('uid: $uid')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      stayId,
      roomNumber,
      roomType,
      checkinAt,
      checkoutAt,
      pricePerNightCents,
      priceUsdCents,
      listPriceCents,
      listUsdCents,
      nights,
      uid);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StayRoom &&
          other.id == this.id &&
          other.stayId == this.stayId &&
          other.roomNumber == this.roomNumber &&
          other.roomType == this.roomType &&
          other.checkinAt == this.checkinAt &&
          other.checkoutAt == this.checkoutAt &&
          other.pricePerNightCents == this.pricePerNightCents &&
          other.priceUsdCents == this.priceUsdCents &&
          other.listPriceCents == this.listPriceCents &&
          other.listUsdCents == this.listUsdCents &&
          other.nights == this.nights &&
          other.uid == this.uid);
}

class StayRoomsCompanion extends UpdateCompanion<StayRoom> {
  final Value<int> id;
  final Value<int> stayId;
  final Value<String> roomNumber;
  final Value<String> roomType;
  final Value<DateTime> checkinAt;
  final Value<DateTime> checkoutAt;
  final Value<int> pricePerNightCents;
  final Value<int> priceUsdCents;
  final Value<int?> listPriceCents;
  final Value<int?> listUsdCents;
  final Value<int> nights;
  final Value<String?> uid;
  const StayRoomsCompanion({
    this.id = const Value.absent(),
    this.stayId = const Value.absent(),
    this.roomNumber = const Value.absent(),
    this.roomType = const Value.absent(),
    this.checkinAt = const Value.absent(),
    this.checkoutAt = const Value.absent(),
    this.pricePerNightCents = const Value.absent(),
    this.priceUsdCents = const Value.absent(),
    this.listPriceCents = const Value.absent(),
    this.listUsdCents = const Value.absent(),
    this.nights = const Value.absent(),
    this.uid = const Value.absent(),
  });
  StayRoomsCompanion.insert({
    this.id = const Value.absent(),
    required int stayId,
    required String roomNumber,
    required String roomType,
    required DateTime checkinAt,
    required DateTime checkoutAt,
    required int pricePerNightCents,
    this.priceUsdCents = const Value.absent(),
    this.listPriceCents = const Value.absent(),
    this.listUsdCents = const Value.absent(),
    required int nights,
    this.uid = const Value.absent(),
  })  : stayId = Value(stayId),
        roomNumber = Value(roomNumber),
        roomType = Value(roomType),
        checkinAt = Value(checkinAt),
        checkoutAt = Value(checkoutAt),
        pricePerNightCents = Value(pricePerNightCents),
        nights = Value(nights);
  static Insertable<StayRoom> custom({
    Expression<int>? id,
    Expression<int>? stayId,
    Expression<String>? roomNumber,
    Expression<String>? roomType,
    Expression<DateTime>? checkinAt,
    Expression<DateTime>? checkoutAt,
    Expression<int>? pricePerNightCents,
    Expression<int>? priceUsdCents,
    Expression<int>? listPriceCents,
    Expression<int>? listUsdCents,
    Expression<int>? nights,
    Expression<String>? uid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (stayId != null) 'stay_id': stayId,
      if (roomNumber != null) 'room_number': roomNumber,
      if (roomType != null) 'room_type': roomType,
      if (checkinAt != null) 'checkin_at': checkinAt,
      if (checkoutAt != null) 'checkout_at': checkoutAt,
      if (pricePerNightCents != null)
        'price_per_night_cents': pricePerNightCents,
      if (priceUsdCents != null) 'price_usd_cents': priceUsdCents,
      if (listPriceCents != null) 'list_price_cents': listPriceCents,
      if (listUsdCents != null) 'list_usd_cents': listUsdCents,
      if (nights != null) 'nights': nights,
      if (uid != null) 'uid': uid,
    });
  }

  StayRoomsCompanion copyWith(
      {Value<int>? id,
      Value<int>? stayId,
      Value<String>? roomNumber,
      Value<String>? roomType,
      Value<DateTime>? checkinAt,
      Value<DateTime>? checkoutAt,
      Value<int>? pricePerNightCents,
      Value<int>? priceUsdCents,
      Value<int?>? listPriceCents,
      Value<int?>? listUsdCents,
      Value<int>? nights,
      Value<String?>? uid}) {
    return StayRoomsCompanion(
      id: id ?? this.id,
      stayId: stayId ?? this.stayId,
      roomNumber: roomNumber ?? this.roomNumber,
      roomType: roomType ?? this.roomType,
      checkinAt: checkinAt ?? this.checkinAt,
      checkoutAt: checkoutAt ?? this.checkoutAt,
      pricePerNightCents: pricePerNightCents ?? this.pricePerNightCents,
      priceUsdCents: priceUsdCents ?? this.priceUsdCents,
      listPriceCents: listPriceCents ?? this.listPriceCents,
      listUsdCents: listUsdCents ?? this.listUsdCents,
      nights: nights ?? this.nights,
      uid: uid ?? this.uid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (stayId.present) {
      map['stay_id'] = Variable<int>(stayId.value);
    }
    if (roomNumber.present) {
      map['room_number'] = Variable<String>(roomNumber.value);
    }
    if (roomType.present) {
      map['room_type'] = Variable<String>(roomType.value);
    }
    if (checkinAt.present) {
      map['checkin_at'] = Variable<DateTime>(checkinAt.value);
    }
    if (checkoutAt.present) {
      map['checkout_at'] = Variable<DateTime>(checkoutAt.value);
    }
    if (pricePerNightCents.present) {
      map['price_per_night_cents'] = Variable<int>(pricePerNightCents.value);
    }
    if (priceUsdCents.present) {
      map['price_usd_cents'] = Variable<int>(priceUsdCents.value);
    }
    if (listPriceCents.present) {
      map['list_price_cents'] = Variable<int>(listPriceCents.value);
    }
    if (listUsdCents.present) {
      map['list_usd_cents'] = Variable<int>(listUsdCents.value);
    }
    if (nights.present) {
      map['nights'] = Variable<int>(nights.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StayRoomsCompanion(')
          ..write('id: $id, ')
          ..write('stayId: $stayId, ')
          ..write('roomNumber: $roomNumber, ')
          ..write('roomType: $roomType, ')
          ..write('checkinAt: $checkinAt, ')
          ..write('checkoutAt: $checkoutAt, ')
          ..write('pricePerNightCents: $pricePerNightCents, ')
          ..write('priceUsdCents: $priceUsdCents, ')
          ..write('listPriceCents: $listPriceCents, ')
          ..write('listUsdCents: $listUsdCents, ')
          ..write('nights: $nights, ')
          ..write('uid: $uid')
          ..write(')'))
        .toString();
  }
}

class $ReservationsTable extends Reservations
    with TableInfo<$ReservationsTable, Reservation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReservationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _reservationNumberMeta =
      const VerificationMeta('reservationNumber');
  @override
  late final GeneratedColumn<String> reservationNumber =
      GeneratedColumn<String>('reservation_number', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(
              minTextLength: 1, maxTextLength: 40),
          type: DriftSqlType.string,
          requiredDuringInsert: true,
          defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _checkinDateMeta =
      const VerificationMeta('checkinDate');
  @override
  late final GeneratedColumn<DateTime> checkinDate = GeneratedColumn<DateTime>(
      'checkin_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _checkoutDateMeta =
      const VerificationMeta('checkoutDate');
  @override
  late final GeneratedColumn<DateTime> checkoutDate = GeneratedColumn<DateTime>(
      'checkout_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _guestFullNameMeta =
      const VerificationMeta('guestFullName');
  @override
  late final GeneratedColumn<String> guestFullName = GeneratedColumn<String>(
      'guest_full_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _guestPhoneMeta =
      const VerificationMeta('guestPhone');
  @override
  late final GeneratedColumn<String> guestPhone = GeneratedColumn<String>(
      'guest_phone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _guestEmailMeta =
      const VerificationMeta('guestEmail');
  @override
  late final GeneratedColumn<String> guestEmail = GeneratedColumn<String>(
      'guest_email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _payerIdMeta =
      const VerificationMeta('payerId');
  @override
  late final GeneratedColumn<int> payerId = GeneratedColumn<int>(
      'payer_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES payers (id) ON DELETE SET NULL'));
  @override
  late final GeneratedColumnWithTypeConverter<DbReservationStatus, int> status =
      GeneratedColumn<int>('status', aliasedName, false,
              type: DriftSqlType.int,
              requiredDuringInsert: false,
              defaultValue: Constant(DbReservationStatus.confirmed.index))
          .withConverter<DbReservationStatus>(
              $ReservationsTable.$converterstatus);
  static const VerificationMeta _depositCentsMeta =
      const VerificationMeta('depositCents');
  @override
  late final GeneratedColumn<int> depositCents = GeneratedColumn<int>(
      'deposit_cents', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdByLoginMeta =
      const VerificationMeta('createdByLogin');
  @override
  late final GeneratedColumn<String> createdByLogin = GeneratedColumn<String>(
      'created_by_login', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cancelledAtMeta =
      const VerificationMeta('cancelledAt');
  @override
  late final GeneratedColumn<DateTime> cancelledAt = GeneratedColumn<DateTime>(
      'cancelled_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _cancelReasonMeta =
      const VerificationMeta('cancelReason');
  @override
  late final GeneratedColumn<String> cancelReason = GeneratedColumn<String>(
      'cancel_reason', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _stayIdMeta = const VerificationMeta('stayId');
  @override
  late final GeneratedColumn<int> stayId = GeneratedColumn<int>(
      'stay_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES stays (id) ON DELETE SET NULL'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        reservationNumber,
        createdAt,
        checkinDate,
        checkoutDate,
        guestFullName,
        guestPhone,
        guestEmail,
        payerId,
        status,
        depositCents,
        note,
        createdByLogin,
        cancelledAt,
        cancelReason,
        stayId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reservations';
  @override
  VerificationContext validateIntegrity(Insertable<Reservation> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('reservation_number')) {
      context.handle(
          _reservationNumberMeta,
          reservationNumber.isAcceptableOrUnknown(
              data['reservation_number']!, _reservationNumberMeta));
    } else if (isInserting) {
      context.missing(_reservationNumberMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('checkin_date')) {
      context.handle(
          _checkinDateMeta,
          checkinDate.isAcceptableOrUnknown(
              data['checkin_date']!, _checkinDateMeta));
    } else if (isInserting) {
      context.missing(_checkinDateMeta);
    }
    if (data.containsKey('checkout_date')) {
      context.handle(
          _checkoutDateMeta,
          checkoutDate.isAcceptableOrUnknown(
              data['checkout_date']!, _checkoutDateMeta));
    } else if (isInserting) {
      context.missing(_checkoutDateMeta);
    }
    if (data.containsKey('guest_full_name')) {
      context.handle(
          _guestFullNameMeta,
          guestFullName.isAcceptableOrUnknown(
              data['guest_full_name']!, _guestFullNameMeta));
    } else if (isInserting) {
      context.missing(_guestFullNameMeta);
    }
    if (data.containsKey('guest_phone')) {
      context.handle(
          _guestPhoneMeta,
          guestPhone.isAcceptableOrUnknown(
              data['guest_phone']!, _guestPhoneMeta));
    }
    if (data.containsKey('guest_email')) {
      context.handle(
          _guestEmailMeta,
          guestEmail.isAcceptableOrUnknown(
              data['guest_email']!, _guestEmailMeta));
    }
    if (data.containsKey('payer_id')) {
      context.handle(_payerIdMeta,
          payerId.isAcceptableOrUnknown(data['payer_id']!, _payerIdMeta));
    }
    if (data.containsKey('deposit_cents')) {
      context.handle(
          _depositCentsMeta,
          depositCents.isAcceptableOrUnknown(
              data['deposit_cents']!, _depositCentsMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('created_by_login')) {
      context.handle(
          _createdByLoginMeta,
          createdByLogin.isAcceptableOrUnknown(
              data['created_by_login']!, _createdByLoginMeta));
    }
    if (data.containsKey('cancelled_at')) {
      context.handle(
          _cancelledAtMeta,
          cancelledAt.isAcceptableOrUnknown(
              data['cancelled_at']!, _cancelledAtMeta));
    }
    if (data.containsKey('cancel_reason')) {
      context.handle(
          _cancelReasonMeta,
          cancelReason.isAcceptableOrUnknown(
              data['cancel_reason']!, _cancelReasonMeta));
    }
    if (data.containsKey('stay_id')) {
      context.handle(_stayIdMeta,
          stayId.isAcceptableOrUnknown(data['stay_id']!, _stayIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Reservation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reservation(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      reservationNumber: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}reservation_number'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      checkinDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}checkin_date'])!,
      checkoutDate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}checkout_date'])!,
      guestFullName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}guest_full_name'])!,
      guestPhone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}guest_phone']),
      guestEmail: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}guest_email']),
      payerId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}payer_id']),
      status: $ReservationsTable.$converterstatus.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!),
      depositCents: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}deposit_cents'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      createdByLogin: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}created_by_login']),
      cancelledAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}cancelled_at']),
      cancelReason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cancel_reason']),
      stayId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}stay_id']),
    );
  }

  @override
  $ReservationsTable createAlias(String alias) {
    return $ReservationsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DbReservationStatus, int, int> $converterstatus =
      const EnumIndexConverter<DbReservationStatus>(DbReservationStatus.values);
}

class Reservation extends DataClass implements Insertable<Reservation> {
  final int id;
  final String reservationNumber;
  final DateTime createdAt;
  final DateTime checkinDate;
  final DateTime checkoutDate;
  final String guestFullName;
  final String? guestPhone;
  final String? guestEmail;
  final int? payerId;
  final DbReservationStatus status;
  final int depositCents;
  final String? note;
  final String? createdByLogin;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final int? stayId;
  const Reservation(
      {required this.id,
      required this.reservationNumber,
      required this.createdAt,
      required this.checkinDate,
      required this.checkoutDate,
      required this.guestFullName,
      this.guestPhone,
      this.guestEmail,
      this.payerId,
      required this.status,
      required this.depositCents,
      this.note,
      this.createdByLogin,
      this.cancelledAt,
      this.cancelReason,
      this.stayId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['reservation_number'] = Variable<String>(reservationNumber);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['checkin_date'] = Variable<DateTime>(checkinDate);
    map['checkout_date'] = Variable<DateTime>(checkoutDate);
    map['guest_full_name'] = Variable<String>(guestFullName);
    if (!nullToAbsent || guestPhone != null) {
      map['guest_phone'] = Variable<String>(guestPhone);
    }
    if (!nullToAbsent || guestEmail != null) {
      map['guest_email'] = Variable<String>(guestEmail);
    }
    if (!nullToAbsent || payerId != null) {
      map['payer_id'] = Variable<int>(payerId);
    }
    {
      map['status'] =
          Variable<int>($ReservationsTable.$converterstatus.toSql(status));
    }
    map['deposit_cents'] = Variable<int>(depositCents);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || createdByLogin != null) {
      map['created_by_login'] = Variable<String>(createdByLogin);
    }
    if (!nullToAbsent || cancelledAt != null) {
      map['cancelled_at'] = Variable<DateTime>(cancelledAt);
    }
    if (!nullToAbsent || cancelReason != null) {
      map['cancel_reason'] = Variable<String>(cancelReason);
    }
    if (!nullToAbsent || stayId != null) {
      map['stay_id'] = Variable<int>(stayId);
    }
    return map;
  }

  ReservationsCompanion toCompanion(bool nullToAbsent) {
    return ReservationsCompanion(
      id: Value(id),
      reservationNumber: Value(reservationNumber),
      createdAt: Value(createdAt),
      checkinDate: Value(checkinDate),
      checkoutDate: Value(checkoutDate),
      guestFullName: Value(guestFullName),
      guestPhone: guestPhone == null && nullToAbsent
          ? const Value.absent()
          : Value(guestPhone),
      guestEmail: guestEmail == null && nullToAbsent
          ? const Value.absent()
          : Value(guestEmail),
      payerId: payerId == null && nullToAbsent
          ? const Value.absent()
          : Value(payerId),
      status: Value(status),
      depositCents: Value(depositCents),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdByLogin: createdByLogin == null && nullToAbsent
          ? const Value.absent()
          : Value(createdByLogin),
      cancelledAt: cancelledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(cancelledAt),
      cancelReason: cancelReason == null && nullToAbsent
          ? const Value.absent()
          : Value(cancelReason),
      stayId:
          stayId == null && nullToAbsent ? const Value.absent() : Value(stayId),
    );
  }

  factory Reservation.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Reservation(
      id: serializer.fromJson<int>(json['id']),
      reservationNumber: serializer.fromJson<String>(json['reservationNumber']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      checkinDate: serializer.fromJson<DateTime>(json['checkinDate']),
      checkoutDate: serializer.fromJson<DateTime>(json['checkoutDate']),
      guestFullName: serializer.fromJson<String>(json['guestFullName']),
      guestPhone: serializer.fromJson<String?>(json['guestPhone']),
      guestEmail: serializer.fromJson<String?>(json['guestEmail']),
      payerId: serializer.fromJson<int?>(json['payerId']),
      status: $ReservationsTable.$converterstatus
          .fromJson(serializer.fromJson<int>(json['status'])),
      depositCents: serializer.fromJson<int>(json['depositCents']),
      note: serializer.fromJson<String?>(json['note']),
      createdByLogin: serializer.fromJson<String?>(json['createdByLogin']),
      cancelledAt: serializer.fromJson<DateTime?>(json['cancelledAt']),
      cancelReason: serializer.fromJson<String?>(json['cancelReason']),
      stayId: serializer.fromJson<int?>(json['stayId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'reservationNumber': serializer.toJson<String>(reservationNumber),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'checkinDate': serializer.toJson<DateTime>(checkinDate),
      'checkoutDate': serializer.toJson<DateTime>(checkoutDate),
      'guestFullName': serializer.toJson<String>(guestFullName),
      'guestPhone': serializer.toJson<String?>(guestPhone),
      'guestEmail': serializer.toJson<String?>(guestEmail),
      'payerId': serializer.toJson<int?>(payerId),
      'status': serializer
          .toJson<int>($ReservationsTable.$converterstatus.toJson(status)),
      'depositCents': serializer.toJson<int>(depositCents),
      'note': serializer.toJson<String?>(note),
      'createdByLogin': serializer.toJson<String?>(createdByLogin),
      'cancelledAt': serializer.toJson<DateTime?>(cancelledAt),
      'cancelReason': serializer.toJson<String?>(cancelReason),
      'stayId': serializer.toJson<int?>(stayId),
    };
  }

  Reservation copyWith(
          {int? id,
          String? reservationNumber,
          DateTime? createdAt,
          DateTime? checkinDate,
          DateTime? checkoutDate,
          String? guestFullName,
          Value<String?> guestPhone = const Value.absent(),
          Value<String?> guestEmail = const Value.absent(),
          Value<int?> payerId = const Value.absent(),
          DbReservationStatus? status,
          int? depositCents,
          Value<String?> note = const Value.absent(),
          Value<String?> createdByLogin = const Value.absent(),
          Value<DateTime?> cancelledAt = const Value.absent(),
          Value<String?> cancelReason = const Value.absent(),
          Value<int?> stayId = const Value.absent()}) =>
      Reservation(
        id: id ?? this.id,
        reservationNumber: reservationNumber ?? this.reservationNumber,
        createdAt: createdAt ?? this.createdAt,
        checkinDate: checkinDate ?? this.checkinDate,
        checkoutDate: checkoutDate ?? this.checkoutDate,
        guestFullName: guestFullName ?? this.guestFullName,
        guestPhone: guestPhone.present ? guestPhone.value : this.guestPhone,
        guestEmail: guestEmail.present ? guestEmail.value : this.guestEmail,
        payerId: payerId.present ? payerId.value : this.payerId,
        status: status ?? this.status,
        depositCents: depositCents ?? this.depositCents,
        note: note.present ? note.value : this.note,
        createdByLogin:
            createdByLogin.present ? createdByLogin.value : this.createdByLogin,
        cancelledAt: cancelledAt.present ? cancelledAt.value : this.cancelledAt,
        cancelReason:
            cancelReason.present ? cancelReason.value : this.cancelReason,
        stayId: stayId.present ? stayId.value : this.stayId,
      );
  Reservation copyWithCompanion(ReservationsCompanion data) {
    return Reservation(
      id: data.id.present ? data.id.value : this.id,
      reservationNumber: data.reservationNumber.present
          ? data.reservationNumber.value
          : this.reservationNumber,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      checkinDate:
          data.checkinDate.present ? data.checkinDate.value : this.checkinDate,
      checkoutDate: data.checkoutDate.present
          ? data.checkoutDate.value
          : this.checkoutDate,
      guestFullName: data.guestFullName.present
          ? data.guestFullName.value
          : this.guestFullName,
      guestPhone:
          data.guestPhone.present ? data.guestPhone.value : this.guestPhone,
      guestEmail:
          data.guestEmail.present ? data.guestEmail.value : this.guestEmail,
      payerId: data.payerId.present ? data.payerId.value : this.payerId,
      status: data.status.present ? data.status.value : this.status,
      depositCents: data.depositCents.present
          ? data.depositCents.value
          : this.depositCents,
      note: data.note.present ? data.note.value : this.note,
      createdByLogin: data.createdByLogin.present
          ? data.createdByLogin.value
          : this.createdByLogin,
      cancelledAt:
          data.cancelledAt.present ? data.cancelledAt.value : this.cancelledAt,
      cancelReason: data.cancelReason.present
          ? data.cancelReason.value
          : this.cancelReason,
      stayId: data.stayId.present ? data.stayId.value : this.stayId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reservation(')
          ..write('id: $id, ')
          ..write('reservationNumber: $reservationNumber, ')
          ..write('createdAt: $createdAt, ')
          ..write('checkinDate: $checkinDate, ')
          ..write('checkoutDate: $checkoutDate, ')
          ..write('guestFullName: $guestFullName, ')
          ..write('guestPhone: $guestPhone, ')
          ..write('guestEmail: $guestEmail, ')
          ..write('payerId: $payerId, ')
          ..write('status: $status, ')
          ..write('depositCents: $depositCents, ')
          ..write('note: $note, ')
          ..write('createdByLogin: $createdByLogin, ')
          ..write('cancelledAt: $cancelledAt, ')
          ..write('cancelReason: $cancelReason, ')
          ..write('stayId: $stayId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      reservationNumber,
      createdAt,
      checkinDate,
      checkoutDate,
      guestFullName,
      guestPhone,
      guestEmail,
      payerId,
      status,
      depositCents,
      note,
      createdByLogin,
      cancelledAt,
      cancelReason,
      stayId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reservation &&
          other.id == this.id &&
          other.reservationNumber == this.reservationNumber &&
          other.createdAt == this.createdAt &&
          other.checkinDate == this.checkinDate &&
          other.checkoutDate == this.checkoutDate &&
          other.guestFullName == this.guestFullName &&
          other.guestPhone == this.guestPhone &&
          other.guestEmail == this.guestEmail &&
          other.payerId == this.payerId &&
          other.status == this.status &&
          other.depositCents == this.depositCents &&
          other.note == this.note &&
          other.createdByLogin == this.createdByLogin &&
          other.cancelledAt == this.cancelledAt &&
          other.cancelReason == this.cancelReason &&
          other.stayId == this.stayId);
}

class ReservationsCompanion extends UpdateCompanion<Reservation> {
  final Value<int> id;
  final Value<String> reservationNumber;
  final Value<DateTime> createdAt;
  final Value<DateTime> checkinDate;
  final Value<DateTime> checkoutDate;
  final Value<String> guestFullName;
  final Value<String?> guestPhone;
  final Value<String?> guestEmail;
  final Value<int?> payerId;
  final Value<DbReservationStatus> status;
  final Value<int> depositCents;
  final Value<String?> note;
  final Value<String?> createdByLogin;
  final Value<DateTime?> cancelledAt;
  final Value<String?> cancelReason;
  final Value<int?> stayId;
  const ReservationsCompanion({
    this.id = const Value.absent(),
    this.reservationNumber = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.checkinDate = const Value.absent(),
    this.checkoutDate = const Value.absent(),
    this.guestFullName = const Value.absent(),
    this.guestPhone = const Value.absent(),
    this.guestEmail = const Value.absent(),
    this.payerId = const Value.absent(),
    this.status = const Value.absent(),
    this.depositCents = const Value.absent(),
    this.note = const Value.absent(),
    this.createdByLogin = const Value.absent(),
    this.cancelledAt = const Value.absent(),
    this.cancelReason = const Value.absent(),
    this.stayId = const Value.absent(),
  });
  ReservationsCompanion.insert({
    this.id = const Value.absent(),
    required String reservationNumber,
    this.createdAt = const Value.absent(),
    required DateTime checkinDate,
    required DateTime checkoutDate,
    required String guestFullName,
    this.guestPhone = const Value.absent(),
    this.guestEmail = const Value.absent(),
    this.payerId = const Value.absent(),
    this.status = const Value.absent(),
    this.depositCents = const Value.absent(),
    this.note = const Value.absent(),
    this.createdByLogin = const Value.absent(),
    this.cancelledAt = const Value.absent(),
    this.cancelReason = const Value.absent(),
    this.stayId = const Value.absent(),
  })  : reservationNumber = Value(reservationNumber),
        checkinDate = Value(checkinDate),
        checkoutDate = Value(checkoutDate),
        guestFullName = Value(guestFullName);
  static Insertable<Reservation> custom({
    Expression<int>? id,
    Expression<String>? reservationNumber,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? checkinDate,
    Expression<DateTime>? checkoutDate,
    Expression<String>? guestFullName,
    Expression<String>? guestPhone,
    Expression<String>? guestEmail,
    Expression<int>? payerId,
    Expression<int>? status,
    Expression<int>? depositCents,
    Expression<String>? note,
    Expression<String>? createdByLogin,
    Expression<DateTime>? cancelledAt,
    Expression<String>? cancelReason,
    Expression<int>? stayId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (reservationNumber != null) 'reservation_number': reservationNumber,
      if (createdAt != null) 'created_at': createdAt,
      if (checkinDate != null) 'checkin_date': checkinDate,
      if (checkoutDate != null) 'checkout_date': checkoutDate,
      if (guestFullName != null) 'guest_full_name': guestFullName,
      if (guestPhone != null) 'guest_phone': guestPhone,
      if (guestEmail != null) 'guest_email': guestEmail,
      if (payerId != null) 'payer_id': payerId,
      if (status != null) 'status': status,
      if (depositCents != null) 'deposit_cents': depositCents,
      if (note != null) 'note': note,
      if (createdByLogin != null) 'created_by_login': createdByLogin,
      if (cancelledAt != null) 'cancelled_at': cancelledAt,
      if (cancelReason != null) 'cancel_reason': cancelReason,
      if (stayId != null) 'stay_id': stayId,
    });
  }

  ReservationsCompanion copyWith(
      {Value<int>? id,
      Value<String>? reservationNumber,
      Value<DateTime>? createdAt,
      Value<DateTime>? checkinDate,
      Value<DateTime>? checkoutDate,
      Value<String>? guestFullName,
      Value<String?>? guestPhone,
      Value<String?>? guestEmail,
      Value<int?>? payerId,
      Value<DbReservationStatus>? status,
      Value<int>? depositCents,
      Value<String?>? note,
      Value<String?>? createdByLogin,
      Value<DateTime?>? cancelledAt,
      Value<String?>? cancelReason,
      Value<int?>? stayId}) {
    return ReservationsCompanion(
      id: id ?? this.id,
      reservationNumber: reservationNumber ?? this.reservationNumber,
      createdAt: createdAt ?? this.createdAt,
      checkinDate: checkinDate ?? this.checkinDate,
      checkoutDate: checkoutDate ?? this.checkoutDate,
      guestFullName: guestFullName ?? this.guestFullName,
      guestPhone: guestPhone ?? this.guestPhone,
      guestEmail: guestEmail ?? this.guestEmail,
      payerId: payerId ?? this.payerId,
      status: status ?? this.status,
      depositCents: depositCents ?? this.depositCents,
      note: note ?? this.note,
      createdByLogin: createdByLogin ?? this.createdByLogin,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelReason: cancelReason ?? this.cancelReason,
      stayId: stayId ?? this.stayId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (reservationNumber.present) {
      map['reservation_number'] = Variable<String>(reservationNumber.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (checkinDate.present) {
      map['checkin_date'] = Variable<DateTime>(checkinDate.value);
    }
    if (checkoutDate.present) {
      map['checkout_date'] = Variable<DateTime>(checkoutDate.value);
    }
    if (guestFullName.present) {
      map['guest_full_name'] = Variable<String>(guestFullName.value);
    }
    if (guestPhone.present) {
      map['guest_phone'] = Variable<String>(guestPhone.value);
    }
    if (guestEmail.present) {
      map['guest_email'] = Variable<String>(guestEmail.value);
    }
    if (payerId.present) {
      map['payer_id'] = Variable<int>(payerId.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(
          $ReservationsTable.$converterstatus.toSql(status.value));
    }
    if (depositCents.present) {
      map['deposit_cents'] = Variable<int>(depositCents.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdByLogin.present) {
      map['created_by_login'] = Variable<String>(createdByLogin.value);
    }
    if (cancelledAt.present) {
      map['cancelled_at'] = Variable<DateTime>(cancelledAt.value);
    }
    if (cancelReason.present) {
      map['cancel_reason'] = Variable<String>(cancelReason.value);
    }
    if (stayId.present) {
      map['stay_id'] = Variable<int>(stayId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReservationsCompanion(')
          ..write('id: $id, ')
          ..write('reservationNumber: $reservationNumber, ')
          ..write('createdAt: $createdAt, ')
          ..write('checkinDate: $checkinDate, ')
          ..write('checkoutDate: $checkoutDate, ')
          ..write('guestFullName: $guestFullName, ')
          ..write('guestPhone: $guestPhone, ')
          ..write('guestEmail: $guestEmail, ')
          ..write('payerId: $payerId, ')
          ..write('status: $status, ')
          ..write('depositCents: $depositCents, ')
          ..write('note: $note, ')
          ..write('createdByLogin: $createdByLogin, ')
          ..write('cancelledAt: $cancelledAt, ')
          ..write('cancelReason: $cancelReason, ')
          ..write('stayId: $stayId')
          ..write(')'))
        .toString();
  }
}

class $ReservationRoomsTable extends ReservationRooms
    with TableInfo<$ReservationRoomsTable, ReservationRoom> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReservationRoomsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _reservationIdMeta =
      const VerificationMeta('reservationId');
  @override
  late final GeneratedColumn<int> reservationId = GeneratedColumn<int>(
      'reservation_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES reservations (id) ON DELETE CASCADE'));
  static const VerificationMeta _roomNumberMeta =
      const VerificationMeta('roomNumber');
  @override
  late final GeneratedColumn<String> roomNumber = GeneratedColumn<String>(
      'room_number', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pricePerNightCentsMeta =
      const VerificationMeta('pricePerNightCents');
  @override
  late final GeneratedColumn<int> pricePerNightCents = GeneratedColumn<int>(
      'price_per_night_cents', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, reservationId, roomNumber, pricePerNightCents];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reservation_rooms';
  @override
  VerificationContext validateIntegrity(Insertable<ReservationRoom> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('reservation_id')) {
      context.handle(
          _reservationIdMeta,
          reservationId.isAcceptableOrUnknown(
              data['reservation_id']!, _reservationIdMeta));
    } else if (isInserting) {
      context.missing(_reservationIdMeta);
    }
    if (data.containsKey('room_number')) {
      context.handle(
          _roomNumberMeta,
          roomNumber.isAcceptableOrUnknown(
              data['room_number']!, _roomNumberMeta));
    } else if (isInserting) {
      context.missing(_roomNumberMeta);
    }
    if (data.containsKey('price_per_night_cents')) {
      context.handle(
          _pricePerNightCentsMeta,
          pricePerNightCents.isAcceptableOrUnknown(
              data['price_per_night_cents']!, _pricePerNightCentsMeta));
    } else if (isInserting) {
      context.missing(_pricePerNightCentsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReservationRoom map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReservationRoom(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      reservationId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}reservation_id'])!,
      roomNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}room_number'])!,
      pricePerNightCents: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}price_per_night_cents'])!,
    );
  }

  @override
  $ReservationRoomsTable createAlias(String alias) {
    return $ReservationRoomsTable(attachedDatabase, alias);
  }
}

class ReservationRoom extends DataClass implements Insertable<ReservationRoom> {
  final int id;
  final int reservationId;
  final String roomNumber;
  final int pricePerNightCents;
  const ReservationRoom(
      {required this.id,
      required this.reservationId,
      required this.roomNumber,
      required this.pricePerNightCents});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['reservation_id'] = Variable<int>(reservationId);
    map['room_number'] = Variable<String>(roomNumber);
    map['price_per_night_cents'] = Variable<int>(pricePerNightCents);
    return map;
  }

  ReservationRoomsCompanion toCompanion(bool nullToAbsent) {
    return ReservationRoomsCompanion(
      id: Value(id),
      reservationId: Value(reservationId),
      roomNumber: Value(roomNumber),
      pricePerNightCents: Value(pricePerNightCents),
    );
  }

  factory ReservationRoom.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReservationRoom(
      id: serializer.fromJson<int>(json['id']),
      reservationId: serializer.fromJson<int>(json['reservationId']),
      roomNumber: serializer.fromJson<String>(json['roomNumber']),
      pricePerNightCents: serializer.fromJson<int>(json['pricePerNightCents']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'reservationId': serializer.toJson<int>(reservationId),
      'roomNumber': serializer.toJson<String>(roomNumber),
      'pricePerNightCents': serializer.toJson<int>(pricePerNightCents),
    };
  }

  ReservationRoom copyWith(
          {int? id,
          int? reservationId,
          String? roomNumber,
          int? pricePerNightCents}) =>
      ReservationRoom(
        id: id ?? this.id,
        reservationId: reservationId ?? this.reservationId,
        roomNumber: roomNumber ?? this.roomNumber,
        pricePerNightCents: pricePerNightCents ?? this.pricePerNightCents,
      );
  ReservationRoom copyWithCompanion(ReservationRoomsCompanion data) {
    return ReservationRoom(
      id: data.id.present ? data.id.value : this.id,
      reservationId: data.reservationId.present
          ? data.reservationId.value
          : this.reservationId,
      roomNumber:
          data.roomNumber.present ? data.roomNumber.value : this.roomNumber,
      pricePerNightCents: data.pricePerNightCents.present
          ? data.pricePerNightCents.value
          : this.pricePerNightCents,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReservationRoom(')
          ..write('id: $id, ')
          ..write('reservationId: $reservationId, ')
          ..write('roomNumber: $roomNumber, ')
          ..write('pricePerNightCents: $pricePerNightCents')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, reservationId, roomNumber, pricePerNightCents);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReservationRoom &&
          other.id == this.id &&
          other.reservationId == this.reservationId &&
          other.roomNumber == this.roomNumber &&
          other.pricePerNightCents == this.pricePerNightCents);
}

class ReservationRoomsCompanion extends UpdateCompanion<ReservationRoom> {
  final Value<int> id;
  final Value<int> reservationId;
  final Value<String> roomNumber;
  final Value<int> pricePerNightCents;
  const ReservationRoomsCompanion({
    this.id = const Value.absent(),
    this.reservationId = const Value.absent(),
    this.roomNumber = const Value.absent(),
    this.pricePerNightCents = const Value.absent(),
  });
  ReservationRoomsCompanion.insert({
    this.id = const Value.absent(),
    required int reservationId,
    required String roomNumber,
    required int pricePerNightCents,
  })  : reservationId = Value(reservationId),
        roomNumber = Value(roomNumber),
        pricePerNightCents = Value(pricePerNightCents);
  static Insertable<ReservationRoom> custom({
    Expression<int>? id,
    Expression<int>? reservationId,
    Expression<String>? roomNumber,
    Expression<int>? pricePerNightCents,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (reservationId != null) 'reservation_id': reservationId,
      if (roomNumber != null) 'room_number': roomNumber,
      if (pricePerNightCents != null)
        'price_per_night_cents': pricePerNightCents,
    });
  }

  ReservationRoomsCompanion copyWith(
      {Value<int>? id,
      Value<int>? reservationId,
      Value<String>? roomNumber,
      Value<int>? pricePerNightCents}) {
    return ReservationRoomsCompanion(
      id: id ?? this.id,
      reservationId: reservationId ?? this.reservationId,
      roomNumber: roomNumber ?? this.roomNumber,
      pricePerNightCents: pricePerNightCents ?? this.pricePerNightCents,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (reservationId.present) {
      map['reservation_id'] = Variable<int>(reservationId.value);
    }
    if (roomNumber.present) {
      map['room_number'] = Variable<String>(roomNumber.value);
    }
    if (pricePerNightCents.present) {
      map['price_per_night_cents'] = Variable<int>(pricePerNightCents.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReservationRoomsCompanion(')
          ..write('id: $id, ')
          ..write('reservationId: $reservationId, ')
          ..write('roomNumber: $roomNumber, ')
          ..write('pricePerNightCents: $pricePerNightCents')
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
  late final $PayersTable payers = $PayersTable(this);
  late final $StaysTable stays = $StaysTable(this);
  late final $RoomsTable rooms = $RoomsTable(this);
  late final $SalesTable sales = $SalesTable(this);
  late final $SaleLinesTable saleLines = $SaleLinesTable(this);
  late final $DebtPaymentsTable debtPayments = $DebtPaymentsTable(this);
  late final $StockMovesTable stockMoves = $StockMovesTable(this);
  late final $ClientsTable clients = $ClientsTable(this);
  late final $StayRoomsTable stayRooms = $StayRoomsTable(this);
  late final $ReservationsTable reservations = $ReservationsTable(this);
  late final $ReservationRoomsTable reservationRooms =
      $ReservationRoomsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        settings,
        users,
        articles,
        payers,
        stays,
        rooms,
        sales,
        saleLines,
        debtPayments,
        stockMoves,
        clients,
        stayRooms,
        reservations,
        reservationRooms
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('payers',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('rooms', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('stays',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('rooms', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('users',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('sales', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('stays',
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
          WritePropagation(
            on: TableUpdateQuery.onTableName('sales',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('debt_payments', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('stays',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('stay_rooms', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('payers',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('reservations', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('stays',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('reservations', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('reservations',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('reservation_rooms', kind: UpdateKind.delete),
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
  Value<bool> isLocalDefault,
  Value<bool> mustChangePassword,
  Value<DateTime?> syncedAt,
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
  Value<bool> isLocalDefault,
  Value<bool> mustChangePassword,
  Value<DateTime?> syncedAt,
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

  ColumnFilters<bool> get isLocalDefault => $composableBuilder(
      column: $table.isLocalDefault,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get mustChangePassword => $composableBuilder(
      column: $table.mustChangePassword,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

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

  ColumnOrderings<bool> get isLocalDefault => $composableBuilder(
      column: $table.isLocalDefault,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get mustChangePassword => $composableBuilder(
      column: $table.mustChangePassword,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));
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

  GeneratedColumn<bool> get isLocalDefault => $composableBuilder(
      column: $table.isLocalDefault, builder: (column) => column);

  GeneratedColumn<bool> get mustChangePassword => $composableBuilder(
      column: $table.mustChangePassword, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

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
            Value<bool> isLocalDefault = const Value.absent(),
            Value<bool> mustChangePassword = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
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
            isLocalDefault: isLocalDefault,
            mustChangePassword: mustChangePassword,
            syncedAt: syncedAt,
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
            Value<bool> isLocalDefault = const Value.absent(),
            Value<bool> mustChangePassword = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
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
            isLocalDefault: isLocalDefault,
            mustChangePassword: mustChangePassword,
            syncedAt: syncedAt,
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
  Value<String?> uid,
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
  Value<String?> uid,
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

  ColumnFilters<String> get uid => $composableBuilder(
      column: $table.uid, builder: (column) => ColumnFilters(column));

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

  ColumnOrderings<String> get uid => $composableBuilder(
      column: $table.uid, builder: (column) => ColumnOrderings(column));
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

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

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
            Value<String?> uid = const Value.absent(),
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
            uid: uid,
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
            Value<String?> uid = const Value.absent(),
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
            uid: uid,
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
typedef $$PayersTableCreateCompanionBuilder = PayersCompanion Function({
  Value<int> id,
  required String name,
  Value<DbPayerType> type,
  Value<String?> taxId,
  Value<String?> address,
  Value<String?> contact,
  Value<String?> notes,
  Value<DateTime> createdAt,
});
typedef $$PayersTableUpdateCompanionBuilder = PayersCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<DbPayerType> type,
  Value<String?> taxId,
  Value<String?> address,
  Value<String?> contact,
  Value<String?> notes,
  Value<DateTime> createdAt,
});

final class $$PayersTableReferences
    extends BaseReferences<_$AppDatabase, $PayersTable, Payer> {
  $$PayersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RoomsTable, List<Room>> _roomsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.rooms,
          aliasName: 'payers__id__rooms__payer_id');

  $$RoomsTableProcessedTableManager get roomsRefs {
    final manager = $$RoomsTableTableManager($_db, $_db.rooms)
        .filter((f) => f.payerId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_roomsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ReservationsTable, List<Reservation>>
      _reservationsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.reservations,
              aliasName: 'payers__id__reservations__payer_id');

  $$ReservationsTableProcessedTableManager get reservationsRefs {
    final manager = $$ReservationsTableTableManager($_db, $_db.reservations)
        .filter((f) => f.payerId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_reservationsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$PayersTableFilterComposer
    extends Composer<_$AppDatabase, $PayersTable> {
  $$PayersTableFilterComposer({
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

  ColumnWithTypeConverterFilters<DbPayerType, DbPayerType, int> get type =>
      $composableBuilder(
          column: $table.type,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get taxId => $composableBuilder(
      column: $table.taxId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contact => $composableBuilder(
      column: $table.contact, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> roomsRefs(
      Expression<bool> Function($$RoomsTableFilterComposer f) f) {
    final $$RoomsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.rooms,
        getReferencedColumn: (t) => t.payerId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RoomsTableFilterComposer(
              $db: $db,
              $table: $db.rooms,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> reservationsRefs(
      Expression<bool> Function($$ReservationsTableFilterComposer f) f) {
    final $$ReservationsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.reservations,
        getReferencedColumn: (t) => t.payerId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReservationsTableFilterComposer(
              $db: $db,
              $table: $db.reservations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PayersTableOrderingComposer
    extends Composer<_$AppDatabase, $PayersTable> {
  $$PayersTableOrderingComposer({
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

  ColumnOrderings<int> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get taxId => $composableBuilder(
      column: $table.taxId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contact => $composableBuilder(
      column: $table.contact, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$PayersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PayersTable> {
  $$PayersTableAnnotationComposer({
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

  GeneratedColumnWithTypeConverter<DbPayerType, int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get taxId =>
      $composableBuilder(column: $table.taxId, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get contact =>
      $composableBuilder(column: $table.contact, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> roomsRefs<T extends Object>(
      Expression<T> Function($$RoomsTableAnnotationComposer a) f) {
    final $$RoomsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.rooms,
        getReferencedColumn: (t) => t.payerId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RoomsTableAnnotationComposer(
              $db: $db,
              $table: $db.rooms,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> reservationsRefs<T extends Object>(
      Expression<T> Function($$ReservationsTableAnnotationComposer a) f) {
    final $$ReservationsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.reservations,
        getReferencedColumn: (t) => t.payerId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReservationsTableAnnotationComposer(
              $db: $db,
              $table: $db.reservations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PayersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PayersTable,
    Payer,
    $$PayersTableFilterComposer,
    $$PayersTableOrderingComposer,
    $$PayersTableAnnotationComposer,
    $$PayersTableCreateCompanionBuilder,
    $$PayersTableUpdateCompanionBuilder,
    (Payer, $$PayersTableReferences),
    Payer,
    PrefetchHooks Function({bool roomsRefs, bool reservationsRefs})> {
  $$PayersTableTableManager(_$AppDatabase db, $PayersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PayersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PayersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PayersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DbPayerType> type = const Value.absent(),
            Value<String?> taxId = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<String?> contact = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              PayersCompanion(
            id: id,
            name: name,
            type: type,
            taxId: taxId,
            address: address,
            contact: contact,
            notes: notes,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<DbPayerType> type = const Value.absent(),
            Value<String?> taxId = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<String?> contact = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              PayersCompanion.insert(
            id: id,
            name: name,
            type: type,
            taxId: taxId,
            address: address,
            contact: contact,
            notes: notes,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$PayersTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {roomsRefs = false, reservationsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (roomsRefs) db.rooms,
                if (reservationsRefs) db.reservations
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (roomsRefs)
                    await $_getPrefetchedData<Payer, $PayersTable, Room>(
                        currentTable: table,
                        referencedTable:
                            $$PayersTableReferences._roomsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PayersTableReferences(db, table, p0).roomsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.payerId == item.id),
                        typedResults: items),
                  if (reservationsRefs)
                    await $_getPrefetchedData<Payer, $PayersTable, Reservation>(
                        currentTable: table,
                        referencedTable:
                            $$PayersTableReferences._reservationsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PayersTableReferences(db, table, p0)
                                .reservationsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.payerId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$PayersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PayersTable,
    Payer,
    $$PayersTableFilterComposer,
    $$PayersTableOrderingComposer,
    $$PayersTableAnnotationComposer,
    $$PayersTableCreateCompanionBuilder,
    $$PayersTableUpdateCompanionBuilder,
    (Payer, $$PayersTableReferences),
    Payer,
    PrefetchHooks Function({bool roomsRefs, bool reservationsRefs})>;
typedef $$StaysTableCreateCompanionBuilder = StaysCompanion Function({
  Value<int> id,
  required String receiptNumber,
  Value<String?> reservationNumber,
  Value<DateTime> generatedAt,
  required DateTime checkinAt,
  required DateTime checkoutAt,
  required String guestFullName,
  Value<String?> guestNationality,
  Value<String?> guestPhone,
  Value<String?> guestEmail,
  Value<String?> payerName,
  Value<String?> payerTaxId,
  Value<String?> payerAddress,
  Value<String?> payerContact,
  required int subtotalCents,
  Value<int> remiseCents,
  Value<int> remiseKind,
  Value<int> remiseValue,
  Value<int> remiseBase,
  Value<String?> remiseReason,
  Value<int> acompteFcCents,
  Value<int> acompteUsdCents,
  Value<int> fcPerUsdCents,
  Value<int> paymentMode,
  Value<String?> stayGroup,
  Value<String?> serverLogin,
  Value<String?> note,
  Value<String> extrasJson,
  Value<int> clientVisitsAtCheckout,
  Value<String?> uid,
  Value<DbStayStatus> statut,
});
typedef $$StaysTableUpdateCompanionBuilder = StaysCompanion Function({
  Value<int> id,
  Value<String> receiptNumber,
  Value<String?> reservationNumber,
  Value<DateTime> generatedAt,
  Value<DateTime> checkinAt,
  Value<DateTime> checkoutAt,
  Value<String> guestFullName,
  Value<String?> guestNationality,
  Value<String?> guestPhone,
  Value<String?> guestEmail,
  Value<String?> payerName,
  Value<String?> payerTaxId,
  Value<String?> payerAddress,
  Value<String?> payerContact,
  Value<int> subtotalCents,
  Value<int> remiseCents,
  Value<int> remiseKind,
  Value<int> remiseValue,
  Value<int> remiseBase,
  Value<String?> remiseReason,
  Value<int> acompteFcCents,
  Value<int> acompteUsdCents,
  Value<int> fcPerUsdCents,
  Value<int> paymentMode,
  Value<String?> stayGroup,
  Value<String?> serverLogin,
  Value<String?> note,
  Value<String> extrasJson,
  Value<int> clientVisitsAtCheckout,
  Value<String?> uid,
  Value<DbStayStatus> statut,
});

final class $$StaysTableReferences
    extends BaseReferences<_$AppDatabase, $StaysTable, Stay> {
  $$StaysTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RoomsTable, List<Room>> _roomsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.rooms,
          aliasName: 'stays__id__rooms__current_stay_id');

  $$RoomsTableProcessedTableManager get roomsRefs {
    final manager = $$RoomsTableTableManager($_db, $_db.rooms)
        .filter((f) => f.currentStayId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_roomsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$SalesTable, List<Sale>> _salesRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.sales,
          aliasName: 'stays__id__sales__stay_id');

  $$SalesTableProcessedTableManager get salesRefs {
    final manager = $$SalesTableTableManager($_db, $_db.sales)
        .filter((f) => f.stayId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_salesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$StayRoomsTable, List<StayRoom>>
      _stayRoomsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.stayRooms,
              aliasName: 'stays__id__stay_rooms__stay_id');

  $$StayRoomsTableProcessedTableManager get stayRoomsRefs {
    final manager = $$StayRoomsTableTableManager($_db, $_db.stayRooms)
        .filter((f) => f.stayId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_stayRoomsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ReservationsTable, List<Reservation>>
      _reservationsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.reservations,
              aliasName: 'stays__id__reservations__stay_id');

  $$ReservationsTableProcessedTableManager get reservationsRefs {
    final manager = $$ReservationsTableTableManager($_db, $_db.reservations)
        .filter((f) => f.stayId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_reservationsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$StaysTableFilterComposer extends Composer<_$AppDatabase, $StaysTable> {
  $$StaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get receiptNumber => $composableBuilder(
      column: $table.receiptNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reservationNumber => $composableBuilder(
      column: $table.reservationNumber,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get generatedAt => $composableBuilder(
      column: $table.generatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get checkinAt => $composableBuilder(
      column: $table.checkinAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get checkoutAt => $composableBuilder(
      column: $table.checkoutAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get guestFullName => $composableBuilder(
      column: $table.guestFullName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get guestNationality => $composableBuilder(
      column: $table.guestNationality,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get guestPhone => $composableBuilder(
      column: $table.guestPhone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get guestEmail => $composableBuilder(
      column: $table.guestEmail, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payerName => $composableBuilder(
      column: $table.payerName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payerTaxId => $composableBuilder(
      column: $table.payerTaxId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payerAddress => $composableBuilder(
      column: $table.payerAddress, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payerContact => $composableBuilder(
      column: $table.payerContact, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get subtotalCents => $composableBuilder(
      column: $table.subtotalCents, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get remiseCents => $composableBuilder(
      column: $table.remiseCents, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get remiseKind => $composableBuilder(
      column: $table.remiseKind, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get remiseValue => $composableBuilder(
      column: $table.remiseValue, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get remiseBase => $composableBuilder(
      column: $table.remiseBase, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remiseReason => $composableBuilder(
      column: $table.remiseReason, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get acompteFcCents => $composableBuilder(
      column: $table.acompteFcCents,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get acompteUsdCents => $composableBuilder(
      column: $table.acompteUsdCents,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fcPerUsdCents => $composableBuilder(
      column: $table.fcPerUsdCents, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get paymentMode => $composableBuilder(
      column: $table.paymentMode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stayGroup => $composableBuilder(
      column: $table.stayGroup, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverLogin => $composableBuilder(
      column: $table.serverLogin, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get extrasJson => $composableBuilder(
      column: $table.extrasJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get clientVisitsAtCheckout => $composableBuilder(
      column: $table.clientVisitsAtCheckout,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uid => $composableBuilder(
      column: $table.uid, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<DbStayStatus, DbStayStatus, int> get statut =>
      $composableBuilder(
          column: $table.statut,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  Expression<bool> roomsRefs(
      Expression<bool> Function($$RoomsTableFilterComposer f) f) {
    final $$RoomsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.rooms,
        getReferencedColumn: (t) => t.currentStayId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RoomsTableFilterComposer(
              $db: $db,
              $table: $db.rooms,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> salesRefs(
      Expression<bool> Function($$SalesTableFilterComposer f) f) {
    final $$SalesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.sales,
        getReferencedColumn: (t) => t.stayId,
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

  Expression<bool> stayRoomsRefs(
      Expression<bool> Function($$StayRoomsTableFilterComposer f) f) {
    final $$StayRoomsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.stayRooms,
        getReferencedColumn: (t) => t.stayId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StayRoomsTableFilterComposer(
              $db: $db,
              $table: $db.stayRooms,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> reservationsRefs(
      Expression<bool> Function($$ReservationsTableFilterComposer f) f) {
    final $$ReservationsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.reservations,
        getReferencedColumn: (t) => t.stayId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReservationsTableFilterComposer(
              $db: $db,
              $table: $db.reservations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$StaysTableOrderingComposer
    extends Composer<_$AppDatabase, $StaysTable> {
  $$StaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get receiptNumber => $composableBuilder(
      column: $table.receiptNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reservationNumber => $composableBuilder(
      column: $table.reservationNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get generatedAt => $composableBuilder(
      column: $table.generatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get checkinAt => $composableBuilder(
      column: $table.checkinAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get checkoutAt => $composableBuilder(
      column: $table.checkoutAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get guestFullName => $composableBuilder(
      column: $table.guestFullName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get guestNationality => $composableBuilder(
      column: $table.guestNationality,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get guestPhone => $composableBuilder(
      column: $table.guestPhone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get guestEmail => $composableBuilder(
      column: $table.guestEmail, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payerName => $composableBuilder(
      column: $table.payerName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payerTaxId => $composableBuilder(
      column: $table.payerTaxId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payerAddress => $composableBuilder(
      column: $table.payerAddress,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payerContact => $composableBuilder(
      column: $table.payerContact,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get subtotalCents => $composableBuilder(
      column: $table.subtotalCents,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get remiseCents => $composableBuilder(
      column: $table.remiseCents, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get remiseKind => $composableBuilder(
      column: $table.remiseKind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get remiseValue => $composableBuilder(
      column: $table.remiseValue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get remiseBase => $composableBuilder(
      column: $table.remiseBase, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remiseReason => $composableBuilder(
      column: $table.remiseReason,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get acompteFcCents => $composableBuilder(
      column: $table.acompteFcCents,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get acompteUsdCents => $composableBuilder(
      column: $table.acompteUsdCents,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fcPerUsdCents => $composableBuilder(
      column: $table.fcPerUsdCents,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get paymentMode => $composableBuilder(
      column: $table.paymentMode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stayGroup => $composableBuilder(
      column: $table.stayGroup, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverLogin => $composableBuilder(
      column: $table.serverLogin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get extrasJson => $composableBuilder(
      column: $table.extrasJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get clientVisitsAtCheckout => $composableBuilder(
      column: $table.clientVisitsAtCheckout,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uid => $composableBuilder(
      column: $table.uid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get statut => $composableBuilder(
      column: $table.statut, builder: (column) => ColumnOrderings(column));
}

class $$StaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $StaysTable> {
  $$StaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get receiptNumber => $composableBuilder(
      column: $table.receiptNumber, builder: (column) => column);

  GeneratedColumn<String> get reservationNumber => $composableBuilder(
      column: $table.reservationNumber, builder: (column) => column);

  GeneratedColumn<DateTime> get generatedAt => $composableBuilder(
      column: $table.generatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get checkinAt =>
      $composableBuilder(column: $table.checkinAt, builder: (column) => column);

  GeneratedColumn<DateTime> get checkoutAt => $composableBuilder(
      column: $table.checkoutAt, builder: (column) => column);

  GeneratedColumn<String> get guestFullName => $composableBuilder(
      column: $table.guestFullName, builder: (column) => column);

  GeneratedColumn<String> get guestNationality => $composableBuilder(
      column: $table.guestNationality, builder: (column) => column);

  GeneratedColumn<String> get guestPhone => $composableBuilder(
      column: $table.guestPhone, builder: (column) => column);

  GeneratedColumn<String> get guestEmail => $composableBuilder(
      column: $table.guestEmail, builder: (column) => column);

  GeneratedColumn<String> get payerName =>
      $composableBuilder(column: $table.payerName, builder: (column) => column);

  GeneratedColumn<String> get payerTaxId => $composableBuilder(
      column: $table.payerTaxId, builder: (column) => column);

  GeneratedColumn<String> get payerAddress => $composableBuilder(
      column: $table.payerAddress, builder: (column) => column);

  GeneratedColumn<String> get payerContact => $composableBuilder(
      column: $table.payerContact, builder: (column) => column);

  GeneratedColumn<int> get subtotalCents => $composableBuilder(
      column: $table.subtotalCents, builder: (column) => column);

  GeneratedColumn<int> get remiseCents => $composableBuilder(
      column: $table.remiseCents, builder: (column) => column);

  GeneratedColumn<int> get remiseKind => $composableBuilder(
      column: $table.remiseKind, builder: (column) => column);

  GeneratedColumn<int> get remiseValue => $composableBuilder(
      column: $table.remiseValue, builder: (column) => column);

  GeneratedColumn<int> get remiseBase => $composableBuilder(
      column: $table.remiseBase, builder: (column) => column);

  GeneratedColumn<String> get remiseReason => $composableBuilder(
      column: $table.remiseReason, builder: (column) => column);

  GeneratedColumn<int> get acompteFcCents => $composableBuilder(
      column: $table.acompteFcCents, builder: (column) => column);

  GeneratedColumn<int> get acompteUsdCents => $composableBuilder(
      column: $table.acompteUsdCents, builder: (column) => column);

  GeneratedColumn<int> get fcPerUsdCents => $composableBuilder(
      column: $table.fcPerUsdCents, builder: (column) => column);

  GeneratedColumn<int> get paymentMode => $composableBuilder(
      column: $table.paymentMode, builder: (column) => column);

  GeneratedColumn<String> get stayGroup =>
      $composableBuilder(column: $table.stayGroup, builder: (column) => column);

  GeneratedColumn<String> get serverLogin => $composableBuilder(
      column: $table.serverLogin, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get extrasJson => $composableBuilder(
      column: $table.extrasJson, builder: (column) => column);

  GeneratedColumn<int> get clientVisitsAtCheckout => $composableBuilder(
      column: $table.clientVisitsAtCheckout, builder: (column) => column);

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DbStayStatus, int> get statut =>
      $composableBuilder(column: $table.statut, builder: (column) => column);

  Expression<T> roomsRefs<T extends Object>(
      Expression<T> Function($$RoomsTableAnnotationComposer a) f) {
    final $$RoomsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.rooms,
        getReferencedColumn: (t) => t.currentStayId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RoomsTableAnnotationComposer(
              $db: $db,
              $table: $db.rooms,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> salesRefs<T extends Object>(
      Expression<T> Function($$SalesTableAnnotationComposer a) f) {
    final $$SalesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.sales,
        getReferencedColumn: (t) => t.stayId,
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

  Expression<T> stayRoomsRefs<T extends Object>(
      Expression<T> Function($$StayRoomsTableAnnotationComposer a) f) {
    final $$StayRoomsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.stayRooms,
        getReferencedColumn: (t) => t.stayId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StayRoomsTableAnnotationComposer(
              $db: $db,
              $table: $db.stayRooms,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> reservationsRefs<T extends Object>(
      Expression<T> Function($$ReservationsTableAnnotationComposer a) f) {
    final $$ReservationsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.reservations,
        getReferencedColumn: (t) => t.stayId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReservationsTableAnnotationComposer(
              $db: $db,
              $table: $db.reservations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$StaysTableTableManager extends RootTableManager<
    _$AppDatabase,
    $StaysTable,
    Stay,
    $$StaysTableFilterComposer,
    $$StaysTableOrderingComposer,
    $$StaysTableAnnotationComposer,
    $$StaysTableCreateCompanionBuilder,
    $$StaysTableUpdateCompanionBuilder,
    (Stay, $$StaysTableReferences),
    Stay,
    PrefetchHooks Function(
        {bool roomsRefs,
        bool salesRefs,
        bool stayRoomsRefs,
        bool reservationsRefs})> {
  $$StaysTableTableManager(_$AppDatabase db, $StaysTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> receiptNumber = const Value.absent(),
            Value<String?> reservationNumber = const Value.absent(),
            Value<DateTime> generatedAt = const Value.absent(),
            Value<DateTime> checkinAt = const Value.absent(),
            Value<DateTime> checkoutAt = const Value.absent(),
            Value<String> guestFullName = const Value.absent(),
            Value<String?> guestNationality = const Value.absent(),
            Value<String?> guestPhone = const Value.absent(),
            Value<String?> guestEmail = const Value.absent(),
            Value<String?> payerName = const Value.absent(),
            Value<String?> payerTaxId = const Value.absent(),
            Value<String?> payerAddress = const Value.absent(),
            Value<String?> payerContact = const Value.absent(),
            Value<int> subtotalCents = const Value.absent(),
            Value<int> remiseCents = const Value.absent(),
            Value<int> remiseKind = const Value.absent(),
            Value<int> remiseValue = const Value.absent(),
            Value<int> remiseBase = const Value.absent(),
            Value<String?> remiseReason = const Value.absent(),
            Value<int> acompteFcCents = const Value.absent(),
            Value<int> acompteUsdCents = const Value.absent(),
            Value<int> fcPerUsdCents = const Value.absent(),
            Value<int> paymentMode = const Value.absent(),
            Value<String?> stayGroup = const Value.absent(),
            Value<String?> serverLogin = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String> extrasJson = const Value.absent(),
            Value<int> clientVisitsAtCheckout = const Value.absent(),
            Value<String?> uid = const Value.absent(),
            Value<DbStayStatus> statut = const Value.absent(),
          }) =>
              StaysCompanion(
            id: id,
            receiptNumber: receiptNumber,
            reservationNumber: reservationNumber,
            generatedAt: generatedAt,
            checkinAt: checkinAt,
            checkoutAt: checkoutAt,
            guestFullName: guestFullName,
            guestNationality: guestNationality,
            guestPhone: guestPhone,
            guestEmail: guestEmail,
            payerName: payerName,
            payerTaxId: payerTaxId,
            payerAddress: payerAddress,
            payerContact: payerContact,
            subtotalCents: subtotalCents,
            remiseCents: remiseCents,
            remiseKind: remiseKind,
            remiseValue: remiseValue,
            remiseBase: remiseBase,
            remiseReason: remiseReason,
            acompteFcCents: acompteFcCents,
            acompteUsdCents: acompteUsdCents,
            fcPerUsdCents: fcPerUsdCents,
            paymentMode: paymentMode,
            stayGroup: stayGroup,
            serverLogin: serverLogin,
            note: note,
            extrasJson: extrasJson,
            clientVisitsAtCheckout: clientVisitsAtCheckout,
            uid: uid,
            statut: statut,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String receiptNumber,
            Value<String?> reservationNumber = const Value.absent(),
            Value<DateTime> generatedAt = const Value.absent(),
            required DateTime checkinAt,
            required DateTime checkoutAt,
            required String guestFullName,
            Value<String?> guestNationality = const Value.absent(),
            Value<String?> guestPhone = const Value.absent(),
            Value<String?> guestEmail = const Value.absent(),
            Value<String?> payerName = const Value.absent(),
            Value<String?> payerTaxId = const Value.absent(),
            Value<String?> payerAddress = const Value.absent(),
            Value<String?> payerContact = const Value.absent(),
            required int subtotalCents,
            Value<int> remiseCents = const Value.absent(),
            Value<int> remiseKind = const Value.absent(),
            Value<int> remiseValue = const Value.absent(),
            Value<int> remiseBase = const Value.absent(),
            Value<String?> remiseReason = const Value.absent(),
            Value<int> acompteFcCents = const Value.absent(),
            Value<int> acompteUsdCents = const Value.absent(),
            Value<int> fcPerUsdCents = const Value.absent(),
            Value<int> paymentMode = const Value.absent(),
            Value<String?> stayGroup = const Value.absent(),
            Value<String?> serverLogin = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String> extrasJson = const Value.absent(),
            Value<int> clientVisitsAtCheckout = const Value.absent(),
            Value<String?> uid = const Value.absent(),
            Value<DbStayStatus> statut = const Value.absent(),
          }) =>
              StaysCompanion.insert(
            id: id,
            receiptNumber: receiptNumber,
            reservationNumber: reservationNumber,
            generatedAt: generatedAt,
            checkinAt: checkinAt,
            checkoutAt: checkoutAt,
            guestFullName: guestFullName,
            guestNationality: guestNationality,
            guestPhone: guestPhone,
            guestEmail: guestEmail,
            payerName: payerName,
            payerTaxId: payerTaxId,
            payerAddress: payerAddress,
            payerContact: payerContact,
            subtotalCents: subtotalCents,
            remiseCents: remiseCents,
            remiseKind: remiseKind,
            remiseValue: remiseValue,
            remiseBase: remiseBase,
            remiseReason: remiseReason,
            acompteFcCents: acompteFcCents,
            acompteUsdCents: acompteUsdCents,
            fcPerUsdCents: fcPerUsdCents,
            paymentMode: paymentMode,
            stayGroup: stayGroup,
            serverLogin: serverLogin,
            note: note,
            extrasJson: extrasJson,
            clientVisitsAtCheckout: clientVisitsAtCheckout,
            uid: uid,
            statut: statut,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$StaysTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {roomsRefs = false,
              salesRefs = false,
              stayRoomsRefs = false,
              reservationsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (roomsRefs) db.rooms,
                if (salesRefs) db.sales,
                if (stayRoomsRefs) db.stayRooms,
                if (reservationsRefs) db.reservations
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (roomsRefs)
                    await $_getPrefetchedData<Stay, $StaysTable, Room>(
                        currentTable: table,
                        referencedTable:
                            $$StaysTableReferences._roomsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$StaysTableReferences(db, table, p0).roomsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.currentStayId == item.id),
                        typedResults: items),
                  if (salesRefs)
                    await $_getPrefetchedData<Stay, $StaysTable, Sale>(
                        currentTable: table,
                        referencedTable:
                            $$StaysTableReferences._salesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$StaysTableReferences(db, table, p0).salesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.stayId == item.id),
                        typedResults: items),
                  if (stayRoomsRefs)
                    await $_getPrefetchedData<Stay, $StaysTable, StayRoom>(
                        currentTable: table,
                        referencedTable:
                            $$StaysTableReferences._stayRoomsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$StaysTableReferences(db, table, p0).stayRoomsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.stayId == item.id),
                        typedResults: items),
                  if (reservationsRefs)
                    await $_getPrefetchedData<Stay, $StaysTable, Reservation>(
                        currentTable: table,
                        referencedTable:
                            $$StaysTableReferences._reservationsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$StaysTableReferences(db, table, p0)
                                .reservationsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.stayId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$StaysTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $StaysTable,
    Stay,
    $$StaysTableFilterComposer,
    $$StaysTableOrderingComposer,
    $$StaysTableAnnotationComposer,
    $$StaysTableCreateCompanionBuilder,
    $$StaysTableUpdateCompanionBuilder,
    (Stay, $$StaysTableReferences),
    Stay,
    PrefetchHooks Function(
        {bool roomsRefs,
        bool salesRefs,
        bool stayRoomsRefs,
        bool reservationsRefs})>;
typedef $$RoomsTableCreateCompanionBuilder = RoomsCompanion Function({
  required String number,
  required String type,
  Value<int> priceUsdCents,
  required int pricePerNightCents,
  required DbRoomStatus status,
  Value<String?> currentGuest,
  Value<DateTime?> checkoutDate,
  Value<String?> checkinNote,
  Value<DateTime?> checkinAt,
  Value<String?> stayGroup,
  Value<int?> payerId,
  Value<String?> imagePath,
  Value<int?> negotiatedPriceCents,
  Value<int?> currentStayId,
  Value<int> rowid,
});
typedef $$RoomsTableUpdateCompanionBuilder = RoomsCompanion Function({
  Value<String> number,
  Value<String> type,
  Value<int> priceUsdCents,
  Value<int> pricePerNightCents,
  Value<DbRoomStatus> status,
  Value<String?> currentGuest,
  Value<DateTime?> checkoutDate,
  Value<String?> checkinNote,
  Value<DateTime?> checkinAt,
  Value<String?> stayGroup,
  Value<int?> payerId,
  Value<String?> imagePath,
  Value<int?> negotiatedPriceCents,
  Value<int?> currentStayId,
  Value<int> rowid,
});

final class $$RoomsTableReferences
    extends BaseReferences<_$AppDatabase, $RoomsTable, Room> {
  $$RoomsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PayersTable _payerIdTable(_$AppDatabase db) =>
      db.payers.createAlias('rooms__payer_id__payers__id');

  $$PayersTableProcessedTableManager? get payerId {
    final $_column = $_itemColumn<int>('payer_id');
    if ($_column == null) return null;
    final manager = $$PayersTableTableManager($_db, $_db.payers)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_payerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $StaysTable _currentStayIdTable(_$AppDatabase db) =>
      db.stays.createAlias('rooms__current_stay_id__stays__id');

  $$StaysTableProcessedTableManager? get currentStayId {
    final $_column = $_itemColumn<int>('current_stay_id');
    if ($_column == null) return null;
    final manager = $$StaysTableTableManager($_db, $_db.stays)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_currentStayIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

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

  ColumnFilters<int> get priceUsdCents => $composableBuilder(
      column: $table.priceUsdCents, builder: (column) => ColumnFilters(column));

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

  ColumnFilters<String> get checkinNote => $composableBuilder(
      column: $table.checkinNote, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get checkinAt => $composableBuilder(
      column: $table.checkinAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stayGroup => $composableBuilder(
      column: $table.stayGroup, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get negotiatedPriceCents => $composableBuilder(
      column: $table.negotiatedPriceCents,
      builder: (column) => ColumnFilters(column));

  $$PayersTableFilterComposer get payerId {
    final $$PayersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.payerId,
        referencedTable: $db.payers,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PayersTableFilterComposer(
              $db: $db,
              $table: $db.payers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$StaysTableFilterComposer get currentStayId {
    final $$StaysTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.currentStayId,
        referencedTable: $db.stays,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StaysTableFilterComposer(
              $db: $db,
              $table: $db.stays,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
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

  ColumnOrderings<int> get priceUsdCents => $composableBuilder(
      column: $table.priceUsdCents,
      builder: (column) => ColumnOrderings(column));

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

  ColumnOrderings<String> get checkinNote => $composableBuilder(
      column: $table.checkinNote, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get checkinAt => $composableBuilder(
      column: $table.checkinAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stayGroup => $composableBuilder(
      column: $table.stayGroup, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get negotiatedPriceCents => $composableBuilder(
      column: $table.negotiatedPriceCents,
      builder: (column) => ColumnOrderings(column));

  $$PayersTableOrderingComposer get payerId {
    final $$PayersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.payerId,
        referencedTable: $db.payers,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PayersTableOrderingComposer(
              $db: $db,
              $table: $db.payers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$StaysTableOrderingComposer get currentStayId {
    final $$StaysTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.currentStayId,
        referencedTable: $db.stays,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StaysTableOrderingComposer(
              $db: $db,
              $table: $db.stays,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
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

  GeneratedColumn<int> get priceUsdCents => $composableBuilder(
      column: $table.priceUsdCents, builder: (column) => column);

  GeneratedColumn<int> get pricePerNightCents => $composableBuilder(
      column: $table.pricePerNightCents, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DbRoomStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get currentGuest => $composableBuilder(
      column: $table.currentGuest, builder: (column) => column);

  GeneratedColumn<DateTime> get checkoutDate => $composableBuilder(
      column: $table.checkoutDate, builder: (column) => column);

  GeneratedColumn<String> get checkinNote => $composableBuilder(
      column: $table.checkinNote, builder: (column) => column);

  GeneratedColumn<DateTime> get checkinAt =>
      $composableBuilder(column: $table.checkinAt, builder: (column) => column);

  GeneratedColumn<String> get stayGroup =>
      $composableBuilder(column: $table.stayGroup, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<int> get negotiatedPriceCents => $composableBuilder(
      column: $table.negotiatedPriceCents, builder: (column) => column);

  $$PayersTableAnnotationComposer get payerId {
    final $$PayersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.payerId,
        referencedTable: $db.payers,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PayersTableAnnotationComposer(
              $db: $db,
              $table: $db.payers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$StaysTableAnnotationComposer get currentStayId {
    final $$StaysTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.currentStayId,
        referencedTable: $db.stays,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StaysTableAnnotationComposer(
              $db: $db,
              $table: $db.stays,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
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
    (Room, $$RoomsTableReferences),
    Room,
    PrefetchHooks Function({bool payerId, bool currentStayId})> {
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
            Value<int> priceUsdCents = const Value.absent(),
            Value<int> pricePerNightCents = const Value.absent(),
            Value<DbRoomStatus> status = const Value.absent(),
            Value<String?> currentGuest = const Value.absent(),
            Value<DateTime?> checkoutDate = const Value.absent(),
            Value<String?> checkinNote = const Value.absent(),
            Value<DateTime?> checkinAt = const Value.absent(),
            Value<String?> stayGroup = const Value.absent(),
            Value<int?> payerId = const Value.absent(),
            Value<String?> imagePath = const Value.absent(),
            Value<int?> negotiatedPriceCents = const Value.absent(),
            Value<int?> currentStayId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RoomsCompanion(
            number: number,
            type: type,
            priceUsdCents: priceUsdCents,
            pricePerNightCents: pricePerNightCents,
            status: status,
            currentGuest: currentGuest,
            checkoutDate: checkoutDate,
            checkinNote: checkinNote,
            checkinAt: checkinAt,
            stayGroup: stayGroup,
            payerId: payerId,
            imagePath: imagePath,
            negotiatedPriceCents: negotiatedPriceCents,
            currentStayId: currentStayId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String number,
            required String type,
            Value<int> priceUsdCents = const Value.absent(),
            required int pricePerNightCents,
            required DbRoomStatus status,
            Value<String?> currentGuest = const Value.absent(),
            Value<DateTime?> checkoutDate = const Value.absent(),
            Value<String?> checkinNote = const Value.absent(),
            Value<DateTime?> checkinAt = const Value.absent(),
            Value<String?> stayGroup = const Value.absent(),
            Value<int?> payerId = const Value.absent(),
            Value<String?> imagePath = const Value.absent(),
            Value<int?> negotiatedPriceCents = const Value.absent(),
            Value<int?> currentStayId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RoomsCompanion.insert(
            number: number,
            type: type,
            priceUsdCents: priceUsdCents,
            pricePerNightCents: pricePerNightCents,
            status: status,
            currentGuest: currentGuest,
            checkoutDate: checkoutDate,
            checkinNote: checkinNote,
            checkinAt: checkinAt,
            stayGroup: stayGroup,
            payerId: payerId,
            imagePath: imagePath,
            negotiatedPriceCents: negotiatedPriceCents,
            currentStayId: currentStayId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$RoomsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({payerId = false, currentStayId = false}) {
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
                if (payerId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.payerId,
                    referencedTable: $$RoomsTableReferences._payerIdTable(db),
                    referencedColumn:
                        $$RoomsTableReferences._payerIdTable(db).id,
                  ) as T;
                }
                if (currentStayId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.currentStayId,
                    referencedTable:
                        $$RoomsTableReferences._currentStayIdTable(db),
                    referencedColumn:
                        $$RoomsTableReferences._currentStayIdTable(db).id,
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

typedef $$RoomsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RoomsTable,
    Room,
    $$RoomsTableFilterComposer,
    $$RoomsTableOrderingComposer,
    $$RoomsTableAnnotationComposer,
    $$RoomsTableCreateCompanionBuilder,
    $$RoomsTableUpdateCompanionBuilder,
    (Room, $$RoomsTableReferences),
    Room,
    PrefetchHooks Function({bool payerId, bool currentStayId})>;
typedef $$SalesTableCreateCompanionBuilder = SalesCompanion Function({
  Value<int> id,
  required DateTime soldAt,
  Value<int?> serverUserId,
  required DbPayment payment,
  Value<DbLocation> location,
  Value<String?> customerName,
  Value<String?> roomNumber,
  Value<bool> onCredit,
  Value<DateTime?> settledAt,
  Value<String?> note,
  Value<DateTime?> syncedAt,
  Value<int> syncAttempts,
  Value<String?> syncError,
  Value<int?> stayId,
  Value<String?> uid,
});
typedef $$SalesTableUpdateCompanionBuilder = SalesCompanion Function({
  Value<int> id,
  Value<DateTime> soldAt,
  Value<int?> serverUserId,
  Value<DbPayment> payment,
  Value<DbLocation> location,
  Value<String?> customerName,
  Value<String?> roomNumber,
  Value<bool> onCredit,
  Value<DateTime?> settledAt,
  Value<String?> note,
  Value<DateTime?> syncedAt,
  Value<int> syncAttempts,
  Value<String?> syncError,
  Value<int?> stayId,
  Value<String?> uid,
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

  static $StaysTable _stayIdTable(_$AppDatabase db) =>
      db.stays.createAlias('sales__stay_id__stays__id');

  $$StaysTableProcessedTableManager? get stayId {
    final $_column = $_itemColumn<int>('stay_id');
    if ($_column == null) return null;
    final manager = $$StaysTableTableManager($_db, $_db.stays)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_stayIdTable($_db));
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

  static MultiTypedResultKey<$DebtPaymentsTable, List<DebtPayment>>
      _debtPaymentsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.debtPayments,
              aliasName: 'sales__id__debt_payments__sale_id');

  $$DebtPaymentsTableProcessedTableManager get debtPaymentsRefs {
    final manager = $$DebtPaymentsTableTableManager($_db, $_db.debtPayments)
        .filter((f) => f.saleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_debtPaymentsRefsTable($_db));
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

  ColumnFilters<String> get roomNumber => $composableBuilder(
      column: $table.roomNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get onCredit => $composableBuilder(
      column: $table.onCredit, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get settledAt => $composableBuilder(
      column: $table.settledAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncAttempts => $composableBuilder(
      column: $table.syncAttempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncError => $composableBuilder(
      column: $table.syncError, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uid => $composableBuilder(
      column: $table.uid, builder: (column) => ColumnFilters(column));

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

  $$StaysTableFilterComposer get stayId {
    final $$StaysTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.stayId,
        referencedTable: $db.stays,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StaysTableFilterComposer(
              $db: $db,
              $table: $db.stays,
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

  Expression<bool> debtPaymentsRefs(
      Expression<bool> Function($$DebtPaymentsTableFilterComposer f) f) {
    final $$DebtPaymentsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.debtPayments,
        getReferencedColumn: (t) => t.saleId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DebtPaymentsTableFilterComposer(
              $db: $db,
              $table: $db.debtPayments,
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

  ColumnOrderings<String> get roomNumber => $composableBuilder(
      column: $table.roomNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get onCredit => $composableBuilder(
      column: $table.onCredit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get settledAt => $composableBuilder(
      column: $table.settledAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncAttempts => $composableBuilder(
      column: $table.syncAttempts,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncError => $composableBuilder(
      column: $table.syncError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uid => $composableBuilder(
      column: $table.uid, builder: (column) => ColumnOrderings(column));

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

  $$StaysTableOrderingComposer get stayId {
    final $$StaysTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.stayId,
        referencedTable: $db.stays,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StaysTableOrderingComposer(
              $db: $db,
              $table: $db.stays,
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

  GeneratedColumn<String> get roomNumber => $composableBuilder(
      column: $table.roomNumber, builder: (column) => column);

  GeneratedColumn<bool> get onCredit =>
      $composableBuilder(column: $table.onCredit, builder: (column) => column);

  GeneratedColumn<DateTime> get settledAt =>
      $composableBuilder(column: $table.settledAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<int> get syncAttempts => $composableBuilder(
      column: $table.syncAttempts, builder: (column) => column);

  GeneratedColumn<String> get syncError =>
      $composableBuilder(column: $table.syncError, builder: (column) => column);

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

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

  $$StaysTableAnnotationComposer get stayId {
    final $$StaysTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.stayId,
        referencedTable: $db.stays,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StaysTableAnnotationComposer(
              $db: $db,
              $table: $db.stays,
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

  Expression<T> debtPaymentsRefs<T extends Object>(
      Expression<T> Function($$DebtPaymentsTableAnnotationComposer a) f) {
    final $$DebtPaymentsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.debtPayments,
        getReferencedColumn: (t) => t.saleId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DebtPaymentsTableAnnotationComposer(
              $db: $db,
              $table: $db.debtPayments,
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
    PrefetchHooks Function(
        {bool serverUserId,
        bool stayId,
        bool saleLinesRefs,
        bool debtPaymentsRefs})> {
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
            Value<String?> roomNumber = const Value.absent(),
            Value<bool> onCredit = const Value.absent(),
            Value<DateTime?> settledAt = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<int> syncAttempts = const Value.absent(),
            Value<String?> syncError = const Value.absent(),
            Value<int?> stayId = const Value.absent(),
            Value<String?> uid = const Value.absent(),
          }) =>
              SalesCompanion(
            id: id,
            soldAt: soldAt,
            serverUserId: serverUserId,
            payment: payment,
            location: location,
            customerName: customerName,
            roomNumber: roomNumber,
            onCredit: onCredit,
            settledAt: settledAt,
            note: note,
            syncedAt: syncedAt,
            syncAttempts: syncAttempts,
            syncError: syncError,
            stayId: stayId,
            uid: uid,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime soldAt,
            Value<int?> serverUserId = const Value.absent(),
            required DbPayment payment,
            Value<DbLocation> location = const Value.absent(),
            Value<String?> customerName = const Value.absent(),
            Value<String?> roomNumber = const Value.absent(),
            Value<bool> onCredit = const Value.absent(),
            Value<DateTime?> settledAt = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<int> syncAttempts = const Value.absent(),
            Value<String?> syncError = const Value.absent(),
            Value<int?> stayId = const Value.absent(),
            Value<String?> uid = const Value.absent(),
          }) =>
              SalesCompanion.insert(
            id: id,
            soldAt: soldAt,
            serverUserId: serverUserId,
            payment: payment,
            location: location,
            customerName: customerName,
            roomNumber: roomNumber,
            onCredit: onCredit,
            settledAt: settledAt,
            note: note,
            syncedAt: syncedAt,
            syncAttempts: syncAttempts,
            syncError: syncError,
            stayId: stayId,
            uid: uid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$SalesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {serverUserId = false,
              stayId = false,
              saleLinesRefs = false,
              debtPaymentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (saleLinesRefs) db.saleLines,
                if (debtPaymentsRefs) db.debtPayments
              ],
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
                if (stayId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.stayId,
                    referencedTable: $$SalesTableReferences._stayIdTable(db),
                    referencedColumn:
                        $$SalesTableReferences._stayIdTable(db).id,
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
                        typedResults: items),
                  if (debtPaymentsRefs)
                    await $_getPrefetchedData<Sale, $SalesTable, DebtPayment>(
                        currentTable: table,
                        referencedTable:
                            $$SalesTableReferences._debtPaymentsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SalesTableReferences(db, table, p0)
                                .debtPaymentsRefs,
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
    PrefetchHooks Function(
        {bool serverUserId,
        bool stayId,
        bool saleLinesRefs,
        bool debtPaymentsRefs})>;
typedef $$SaleLinesTableCreateCompanionBuilder = SaleLinesCompanion Function({
  Value<int> id,
  required int saleId,
  Value<int?> articleId,
  required String articleName,
  required int qty,
  required int unitPriceCents,
  Value<String?> uid,
});
typedef $$SaleLinesTableUpdateCompanionBuilder = SaleLinesCompanion Function({
  Value<int> id,
  Value<int> saleId,
  Value<int?> articleId,
  Value<String> articleName,
  Value<int> qty,
  Value<int> unitPriceCents,
  Value<String?> uid,
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

  ColumnFilters<String> get uid => $composableBuilder(
      column: $table.uid, builder: (column) => ColumnFilters(column));

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

  ColumnOrderings<String> get uid => $composableBuilder(
      column: $table.uid, builder: (column) => ColumnOrderings(column));

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

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

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
            Value<String?> uid = const Value.absent(),
          }) =>
              SaleLinesCompanion(
            id: id,
            saleId: saleId,
            articleId: articleId,
            articleName: articleName,
            qty: qty,
            unitPriceCents: unitPriceCents,
            uid: uid,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int saleId,
            Value<int?> articleId = const Value.absent(),
            required String articleName,
            required int qty,
            required int unitPriceCents,
            Value<String?> uid = const Value.absent(),
          }) =>
              SaleLinesCompanion.insert(
            id: id,
            saleId: saleId,
            articleId: articleId,
            articleName: articleName,
            qty: qty,
            unitPriceCents: unitPriceCents,
            uid: uid,
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
typedef $$DebtPaymentsTableCreateCompanionBuilder = DebtPaymentsCompanion
    Function({
  Value<int> id,
  required int saleId,
  required int amountCents,
  required DbPayment payment,
  Value<DateTime> receivedAt,
  Value<String?> receivedByLogin,
  Value<String?> note,
});
typedef $$DebtPaymentsTableUpdateCompanionBuilder = DebtPaymentsCompanion
    Function({
  Value<int> id,
  Value<int> saleId,
  Value<int> amountCents,
  Value<DbPayment> payment,
  Value<DateTime> receivedAt,
  Value<String?> receivedByLogin,
  Value<String?> note,
});

final class $$DebtPaymentsTableReferences
    extends BaseReferences<_$AppDatabase, $DebtPaymentsTable, DebtPayment> {
  $$DebtPaymentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SalesTable _saleIdTable(_$AppDatabase db) =>
      db.sales.createAlias('debt_payments__sale_id__sales__id');

  $$SalesTableProcessedTableManager get saleId {
    final $_column = $_itemColumn<int>('sale_id')!;

    final manager = $$SalesTableTableManager($_db, $_db.sales)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_saleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$DebtPaymentsTableFilterComposer
    extends Composer<_$AppDatabase, $DebtPaymentsTable> {
  $$DebtPaymentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get amountCents => $composableBuilder(
      column: $table.amountCents, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<DbPayment, DbPayment, int> get payment =>
      $composableBuilder(
          column: $table.payment,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get receivedByLogin => $composableBuilder(
      column: $table.receivedByLogin,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

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
}

class $$DebtPaymentsTableOrderingComposer
    extends Composer<_$AppDatabase, $DebtPaymentsTable> {
  $$DebtPaymentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountCents => $composableBuilder(
      column: $table.amountCents, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get payment => $composableBuilder(
      column: $table.payment, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get receivedByLogin => $composableBuilder(
      column: $table.receivedByLogin,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

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
}

class $$DebtPaymentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DebtPaymentsTable> {
  $$DebtPaymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
      column: $table.amountCents, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DbPayment, int> get payment =>
      $composableBuilder(column: $table.payment, builder: (column) => column);

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => column);

  GeneratedColumn<String> get receivedByLogin => $composableBuilder(
      column: $table.receivedByLogin, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

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
}

class $$DebtPaymentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DebtPaymentsTable,
    DebtPayment,
    $$DebtPaymentsTableFilterComposer,
    $$DebtPaymentsTableOrderingComposer,
    $$DebtPaymentsTableAnnotationComposer,
    $$DebtPaymentsTableCreateCompanionBuilder,
    $$DebtPaymentsTableUpdateCompanionBuilder,
    (DebtPayment, $$DebtPaymentsTableReferences),
    DebtPayment,
    PrefetchHooks Function({bool saleId})> {
  $$DebtPaymentsTableTableManager(_$AppDatabase db, $DebtPaymentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DebtPaymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DebtPaymentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DebtPaymentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> saleId = const Value.absent(),
            Value<int> amountCents = const Value.absent(),
            Value<DbPayment> payment = const Value.absent(),
            Value<DateTime> receivedAt = const Value.absent(),
            Value<String?> receivedByLogin = const Value.absent(),
            Value<String?> note = const Value.absent(),
          }) =>
              DebtPaymentsCompanion(
            id: id,
            saleId: saleId,
            amountCents: amountCents,
            payment: payment,
            receivedAt: receivedAt,
            receivedByLogin: receivedByLogin,
            note: note,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int saleId,
            required int amountCents,
            required DbPayment payment,
            Value<DateTime> receivedAt = const Value.absent(),
            Value<String?> receivedByLogin = const Value.absent(),
            Value<String?> note = const Value.absent(),
          }) =>
              DebtPaymentsCompanion.insert(
            id: id,
            saleId: saleId,
            amountCents: amountCents,
            payment: payment,
            receivedAt: receivedAt,
            receivedByLogin: receivedByLogin,
            note: note,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$DebtPaymentsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({saleId = false}) {
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
                        $$DebtPaymentsTableReferences._saleIdTable(db),
                    referencedColumn:
                        $$DebtPaymentsTableReferences._saleIdTable(db).id,
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

typedef $$DebtPaymentsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DebtPaymentsTable,
    DebtPayment,
    $$DebtPaymentsTableFilterComposer,
    $$DebtPaymentsTableOrderingComposer,
    $$DebtPaymentsTableAnnotationComposer,
    $$DebtPaymentsTableCreateCompanionBuilder,
    $$DebtPaymentsTableUpdateCompanionBuilder,
    (DebtPayment, $$DebtPaymentsTableReferences),
    DebtPayment,
    PrefetchHooks Function({bool saleId})>;
typedef $$StockMovesTableCreateCompanionBuilder = StockMovesCompanion Function({
  required String opId,
  required int articleId,
  required int delta,
  Value<String?> reason,
  Value<DateTime> occurredAt,
  Value<DateTime?> sentAt,
  Value<int> attempts,
  Value<String?> lastError,
  Value<int> rowid,
});
typedef $$StockMovesTableUpdateCompanionBuilder = StockMovesCompanion Function({
  Value<String> opId,
  Value<int> articleId,
  Value<int> delta,
  Value<String?> reason,
  Value<DateTime> occurredAt,
  Value<DateTime?> sentAt,
  Value<int> attempts,
  Value<String?> lastError,
  Value<int> rowid,
});

class $$StockMovesTableFilterComposer
    extends Composer<_$AppDatabase, $StockMovesTable> {
  $$StockMovesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get opId => $composableBuilder(
      column: $table.opId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get articleId => $composableBuilder(
      column: $table.articleId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get delta => $composableBuilder(
      column: $table.delta, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get sentAt => $composableBuilder(
      column: $table.sentAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));
}

class $$StockMovesTableOrderingComposer
    extends Composer<_$AppDatabase, $StockMovesTable> {
  $$StockMovesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get opId => $composableBuilder(
      column: $table.opId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get articleId => $composableBuilder(
      column: $table.articleId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get delta => $composableBuilder(
      column: $table.delta, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get sentAt => $composableBuilder(
      column: $table.sentAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));
}

class $$StockMovesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockMovesTable> {
  $$StockMovesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get opId =>
      $composableBuilder(column: $table.opId, builder: (column) => column);

  GeneratedColumn<int> get articleId =>
      $composableBuilder(column: $table.articleId, builder: (column) => column);

  GeneratedColumn<int> get delta =>
      $composableBuilder(column: $table.delta, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => column);

  GeneratedColumn<DateTime> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$StockMovesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $StockMovesTable,
    StockMove,
    $$StockMovesTableFilterComposer,
    $$StockMovesTableOrderingComposer,
    $$StockMovesTableAnnotationComposer,
    $$StockMovesTableCreateCompanionBuilder,
    $$StockMovesTableUpdateCompanionBuilder,
    (StockMove, BaseReferences<_$AppDatabase, $StockMovesTable, StockMove>),
    StockMove,
    PrefetchHooks Function()> {
  $$StockMovesTableTableManager(_$AppDatabase db, $StockMovesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockMovesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockMovesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockMovesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> opId = const Value.absent(),
            Value<int> articleId = const Value.absent(),
            Value<int> delta = const Value.absent(),
            Value<String?> reason = const Value.absent(),
            Value<DateTime> occurredAt = const Value.absent(),
            Value<DateTime?> sentAt = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StockMovesCompanion(
            opId: opId,
            articleId: articleId,
            delta: delta,
            reason: reason,
            occurredAt: occurredAt,
            sentAt: sentAt,
            attempts: attempts,
            lastError: lastError,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String opId,
            required int articleId,
            required int delta,
            Value<String?> reason = const Value.absent(),
            Value<DateTime> occurredAt = const Value.absent(),
            Value<DateTime?> sentAt = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StockMovesCompanion.insert(
            opId: opId,
            articleId: articleId,
            delta: delta,
            reason: reason,
            occurredAt: occurredAt,
            sentAt: sentAt,
            attempts: attempts,
            lastError: lastError,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$StockMovesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $StockMovesTable,
    StockMove,
    $$StockMovesTableFilterComposer,
    $$StockMovesTableOrderingComposer,
    $$StockMovesTableAnnotationComposer,
    $$StockMovesTableCreateCompanionBuilder,
    $$StockMovesTableUpdateCompanionBuilder,
    (StockMove, BaseReferences<_$AppDatabase, $StockMovesTable, StockMove>),
    StockMove,
    PrefetchHooks Function()>;
typedef $$ClientsTableCreateCompanionBuilder = ClientsCompanion Function({
  Value<int> id,
  required String fullName,
  Value<String?> phone,
  Value<String?> email,
  Value<String?> notes,
  Value<DateTime> firstSeenAt,
  Value<DateTime> lastSeenAt,
  Value<int> visitsCount,
  Value<int> totalSpentCents,
});
typedef $$ClientsTableUpdateCompanionBuilder = ClientsCompanion Function({
  Value<int> id,
  Value<String> fullName,
  Value<String?> phone,
  Value<String?> email,
  Value<String?> notes,
  Value<DateTime> firstSeenAt,
  Value<DateTime> lastSeenAt,
  Value<int> visitsCount,
  Value<int> totalSpentCents,
});

class $$ClientsTableFilterComposer
    extends Composer<_$AppDatabase, $ClientsTable> {
  $$ClientsTableFilterComposer({
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

  ColumnFilters<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get firstSeenAt => $composableBuilder(
      column: $table.firstSeenAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get visitsCount => $composableBuilder(
      column: $table.visitsCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalSpentCents => $composableBuilder(
      column: $table.totalSpentCents,
      builder: (column) => ColumnFilters(column));
}

class $$ClientsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClientsTable> {
  $$ClientsTableOrderingComposer({
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

  ColumnOrderings<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get firstSeenAt => $composableBuilder(
      column: $table.firstSeenAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get visitsCount => $composableBuilder(
      column: $table.visitsCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalSpentCents => $composableBuilder(
      column: $table.totalSpentCents,
      builder: (column) => ColumnOrderings(column));
}

class $$ClientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClientsTable> {
  $$ClientsTableAnnotationComposer({
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

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get firstSeenAt => $composableBuilder(
      column: $table.firstSeenAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => column);

  GeneratedColumn<int> get visitsCount => $composableBuilder(
      column: $table.visitsCount, builder: (column) => column);

  GeneratedColumn<int> get totalSpentCents => $composableBuilder(
      column: $table.totalSpentCents, builder: (column) => column);
}

class $$ClientsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ClientsTable,
    Client,
    $$ClientsTableFilterComposer,
    $$ClientsTableOrderingComposer,
    $$ClientsTableAnnotationComposer,
    $$ClientsTableCreateCompanionBuilder,
    $$ClientsTableUpdateCompanionBuilder,
    (Client, BaseReferences<_$AppDatabase, $ClientsTable, Client>),
    Client,
    PrefetchHooks Function()> {
  $$ClientsTableTableManager(_$AppDatabase db, $ClientsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClientsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> fullName = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<DateTime> firstSeenAt = const Value.absent(),
            Value<DateTime> lastSeenAt = const Value.absent(),
            Value<int> visitsCount = const Value.absent(),
            Value<int> totalSpentCents = const Value.absent(),
          }) =>
              ClientsCompanion(
            id: id,
            fullName: fullName,
            phone: phone,
            email: email,
            notes: notes,
            firstSeenAt: firstSeenAt,
            lastSeenAt: lastSeenAt,
            visitsCount: visitsCount,
            totalSpentCents: totalSpentCents,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String fullName,
            Value<String?> phone = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<DateTime> firstSeenAt = const Value.absent(),
            Value<DateTime> lastSeenAt = const Value.absent(),
            Value<int> visitsCount = const Value.absent(),
            Value<int> totalSpentCents = const Value.absent(),
          }) =>
              ClientsCompanion.insert(
            id: id,
            fullName: fullName,
            phone: phone,
            email: email,
            notes: notes,
            firstSeenAt: firstSeenAt,
            lastSeenAt: lastSeenAt,
            visitsCount: visitsCount,
            totalSpentCents: totalSpentCents,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ClientsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ClientsTable,
    Client,
    $$ClientsTableFilterComposer,
    $$ClientsTableOrderingComposer,
    $$ClientsTableAnnotationComposer,
    $$ClientsTableCreateCompanionBuilder,
    $$ClientsTableUpdateCompanionBuilder,
    (Client, BaseReferences<_$AppDatabase, $ClientsTable, Client>),
    Client,
    PrefetchHooks Function()>;
typedef $$StayRoomsTableCreateCompanionBuilder = StayRoomsCompanion Function({
  Value<int> id,
  required int stayId,
  required String roomNumber,
  required String roomType,
  required DateTime checkinAt,
  required DateTime checkoutAt,
  required int pricePerNightCents,
  Value<int> priceUsdCents,
  Value<int?> listPriceCents,
  Value<int?> listUsdCents,
  required int nights,
  Value<String?> uid,
});
typedef $$StayRoomsTableUpdateCompanionBuilder = StayRoomsCompanion Function({
  Value<int> id,
  Value<int> stayId,
  Value<String> roomNumber,
  Value<String> roomType,
  Value<DateTime> checkinAt,
  Value<DateTime> checkoutAt,
  Value<int> pricePerNightCents,
  Value<int> priceUsdCents,
  Value<int?> listPriceCents,
  Value<int?> listUsdCents,
  Value<int> nights,
  Value<String?> uid,
});

final class $$StayRoomsTableReferences
    extends BaseReferences<_$AppDatabase, $StayRoomsTable, StayRoom> {
  $$StayRoomsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StaysTable _stayIdTable(_$AppDatabase db) =>
      db.stays.createAlias('stay_rooms__stay_id__stays__id');

  $$StaysTableProcessedTableManager get stayId {
    final $_column = $_itemColumn<int>('stay_id')!;

    final manager = $$StaysTableTableManager($_db, $_db.stays)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_stayIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$StayRoomsTableFilterComposer
    extends Composer<_$AppDatabase, $StayRoomsTable> {
  $$StayRoomsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get roomNumber => $composableBuilder(
      column: $table.roomNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get roomType => $composableBuilder(
      column: $table.roomType, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get checkinAt => $composableBuilder(
      column: $table.checkinAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get checkoutAt => $composableBuilder(
      column: $table.checkoutAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pricePerNightCents => $composableBuilder(
      column: $table.pricePerNightCents,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get priceUsdCents => $composableBuilder(
      column: $table.priceUsdCents, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get listPriceCents => $composableBuilder(
      column: $table.listPriceCents,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get listUsdCents => $composableBuilder(
      column: $table.listUsdCents, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get nights => $composableBuilder(
      column: $table.nights, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uid => $composableBuilder(
      column: $table.uid, builder: (column) => ColumnFilters(column));

  $$StaysTableFilterComposer get stayId {
    final $$StaysTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.stayId,
        referencedTable: $db.stays,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StaysTableFilterComposer(
              $db: $db,
              $table: $db.stays,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$StayRoomsTableOrderingComposer
    extends Composer<_$AppDatabase, $StayRoomsTable> {
  $$StayRoomsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get roomNumber => $composableBuilder(
      column: $table.roomNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get roomType => $composableBuilder(
      column: $table.roomType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get checkinAt => $composableBuilder(
      column: $table.checkinAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get checkoutAt => $composableBuilder(
      column: $table.checkoutAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pricePerNightCents => $composableBuilder(
      column: $table.pricePerNightCents,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get priceUsdCents => $composableBuilder(
      column: $table.priceUsdCents,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get listPriceCents => $composableBuilder(
      column: $table.listPriceCents,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get listUsdCents => $composableBuilder(
      column: $table.listUsdCents,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get nights => $composableBuilder(
      column: $table.nights, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uid => $composableBuilder(
      column: $table.uid, builder: (column) => ColumnOrderings(column));

  $$StaysTableOrderingComposer get stayId {
    final $$StaysTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.stayId,
        referencedTable: $db.stays,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StaysTableOrderingComposer(
              $db: $db,
              $table: $db.stays,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$StayRoomsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StayRoomsTable> {
  $$StayRoomsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get roomNumber => $composableBuilder(
      column: $table.roomNumber, builder: (column) => column);

  GeneratedColumn<String> get roomType =>
      $composableBuilder(column: $table.roomType, builder: (column) => column);

  GeneratedColumn<DateTime> get checkinAt =>
      $composableBuilder(column: $table.checkinAt, builder: (column) => column);

  GeneratedColumn<DateTime> get checkoutAt => $composableBuilder(
      column: $table.checkoutAt, builder: (column) => column);

  GeneratedColumn<int> get pricePerNightCents => $composableBuilder(
      column: $table.pricePerNightCents, builder: (column) => column);

  GeneratedColumn<int> get priceUsdCents => $composableBuilder(
      column: $table.priceUsdCents, builder: (column) => column);

  GeneratedColumn<int> get listPriceCents => $composableBuilder(
      column: $table.listPriceCents, builder: (column) => column);

  GeneratedColumn<int> get listUsdCents => $composableBuilder(
      column: $table.listUsdCents, builder: (column) => column);

  GeneratedColumn<int> get nights =>
      $composableBuilder(column: $table.nights, builder: (column) => column);

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  $$StaysTableAnnotationComposer get stayId {
    final $$StaysTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.stayId,
        referencedTable: $db.stays,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StaysTableAnnotationComposer(
              $db: $db,
              $table: $db.stays,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$StayRoomsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $StayRoomsTable,
    StayRoom,
    $$StayRoomsTableFilterComposer,
    $$StayRoomsTableOrderingComposer,
    $$StayRoomsTableAnnotationComposer,
    $$StayRoomsTableCreateCompanionBuilder,
    $$StayRoomsTableUpdateCompanionBuilder,
    (StayRoom, $$StayRoomsTableReferences),
    StayRoom,
    PrefetchHooks Function({bool stayId})> {
  $$StayRoomsTableTableManager(_$AppDatabase db, $StayRoomsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StayRoomsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StayRoomsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StayRoomsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> stayId = const Value.absent(),
            Value<String> roomNumber = const Value.absent(),
            Value<String> roomType = const Value.absent(),
            Value<DateTime> checkinAt = const Value.absent(),
            Value<DateTime> checkoutAt = const Value.absent(),
            Value<int> pricePerNightCents = const Value.absent(),
            Value<int> priceUsdCents = const Value.absent(),
            Value<int?> listPriceCents = const Value.absent(),
            Value<int?> listUsdCents = const Value.absent(),
            Value<int> nights = const Value.absent(),
            Value<String?> uid = const Value.absent(),
          }) =>
              StayRoomsCompanion(
            id: id,
            stayId: stayId,
            roomNumber: roomNumber,
            roomType: roomType,
            checkinAt: checkinAt,
            checkoutAt: checkoutAt,
            pricePerNightCents: pricePerNightCents,
            priceUsdCents: priceUsdCents,
            listPriceCents: listPriceCents,
            listUsdCents: listUsdCents,
            nights: nights,
            uid: uid,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int stayId,
            required String roomNumber,
            required String roomType,
            required DateTime checkinAt,
            required DateTime checkoutAt,
            required int pricePerNightCents,
            Value<int> priceUsdCents = const Value.absent(),
            Value<int?> listPriceCents = const Value.absent(),
            Value<int?> listUsdCents = const Value.absent(),
            required int nights,
            Value<String?> uid = const Value.absent(),
          }) =>
              StayRoomsCompanion.insert(
            id: id,
            stayId: stayId,
            roomNumber: roomNumber,
            roomType: roomType,
            checkinAt: checkinAt,
            checkoutAt: checkoutAt,
            pricePerNightCents: pricePerNightCents,
            priceUsdCents: priceUsdCents,
            listPriceCents: listPriceCents,
            listUsdCents: listUsdCents,
            nights: nights,
            uid: uid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$StayRoomsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({stayId = false}) {
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
                if (stayId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.stayId,
                    referencedTable:
                        $$StayRoomsTableReferences._stayIdTable(db),
                    referencedColumn:
                        $$StayRoomsTableReferences._stayIdTable(db).id,
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

typedef $$StayRoomsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $StayRoomsTable,
    StayRoom,
    $$StayRoomsTableFilterComposer,
    $$StayRoomsTableOrderingComposer,
    $$StayRoomsTableAnnotationComposer,
    $$StayRoomsTableCreateCompanionBuilder,
    $$StayRoomsTableUpdateCompanionBuilder,
    (StayRoom, $$StayRoomsTableReferences),
    StayRoom,
    PrefetchHooks Function({bool stayId})>;
typedef $$ReservationsTableCreateCompanionBuilder = ReservationsCompanion
    Function({
  Value<int> id,
  required String reservationNumber,
  Value<DateTime> createdAt,
  required DateTime checkinDate,
  required DateTime checkoutDate,
  required String guestFullName,
  Value<String?> guestPhone,
  Value<String?> guestEmail,
  Value<int?> payerId,
  Value<DbReservationStatus> status,
  Value<int> depositCents,
  Value<String?> note,
  Value<String?> createdByLogin,
  Value<DateTime?> cancelledAt,
  Value<String?> cancelReason,
  Value<int?> stayId,
});
typedef $$ReservationsTableUpdateCompanionBuilder = ReservationsCompanion
    Function({
  Value<int> id,
  Value<String> reservationNumber,
  Value<DateTime> createdAt,
  Value<DateTime> checkinDate,
  Value<DateTime> checkoutDate,
  Value<String> guestFullName,
  Value<String?> guestPhone,
  Value<String?> guestEmail,
  Value<int?> payerId,
  Value<DbReservationStatus> status,
  Value<int> depositCents,
  Value<String?> note,
  Value<String?> createdByLogin,
  Value<DateTime?> cancelledAt,
  Value<String?> cancelReason,
  Value<int?> stayId,
});

final class $$ReservationsTableReferences
    extends BaseReferences<_$AppDatabase, $ReservationsTable, Reservation> {
  $$ReservationsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PayersTable _payerIdTable(_$AppDatabase db) =>
      db.payers.createAlias('reservations__payer_id__payers__id');

  $$PayersTableProcessedTableManager? get payerId {
    final $_column = $_itemColumn<int>('payer_id');
    if ($_column == null) return null;
    final manager = $$PayersTableTableManager($_db, $_db.payers)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_payerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $StaysTable _stayIdTable(_$AppDatabase db) =>
      db.stays.createAlias('reservations__stay_id__stays__id');

  $$StaysTableProcessedTableManager? get stayId {
    final $_column = $_itemColumn<int>('stay_id');
    if ($_column == null) return null;
    final manager = $$StaysTableTableManager($_db, $_db.stays)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_stayIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$ReservationRoomsTable, List<ReservationRoom>>
      _reservationRoomsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.reservationRooms,
              aliasName: 'reservations__id__reservation_rooms__reservation_id');

  $$ReservationRoomsTableProcessedTableManager get reservationRoomsRefs {
    final manager = $$ReservationRoomsTableTableManager(
            $_db, $_db.reservationRooms)
        .filter((f) => f.reservationId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_reservationRoomsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ReservationsTableFilterComposer
    extends Composer<_$AppDatabase, $ReservationsTable> {
  $$ReservationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reservationNumber => $composableBuilder(
      column: $table.reservationNumber,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get checkinDate => $composableBuilder(
      column: $table.checkinDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get checkoutDate => $composableBuilder(
      column: $table.checkoutDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get guestFullName => $composableBuilder(
      column: $table.guestFullName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get guestPhone => $composableBuilder(
      column: $table.guestPhone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get guestEmail => $composableBuilder(
      column: $table.guestEmail, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<DbReservationStatus, DbReservationStatus, int>
      get status => $composableBuilder(
          column: $table.status,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get depositCents => $composableBuilder(
      column: $table.depositCents, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdByLogin => $composableBuilder(
      column: $table.createdByLogin,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get cancelledAt => $composableBuilder(
      column: $table.cancelledAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cancelReason => $composableBuilder(
      column: $table.cancelReason, builder: (column) => ColumnFilters(column));

  $$PayersTableFilterComposer get payerId {
    final $$PayersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.payerId,
        referencedTable: $db.payers,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PayersTableFilterComposer(
              $db: $db,
              $table: $db.payers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$StaysTableFilterComposer get stayId {
    final $$StaysTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.stayId,
        referencedTable: $db.stays,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StaysTableFilterComposer(
              $db: $db,
              $table: $db.stays,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> reservationRoomsRefs(
      Expression<bool> Function($$ReservationRoomsTableFilterComposer f) f) {
    final $$ReservationRoomsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.reservationRooms,
        getReferencedColumn: (t) => t.reservationId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReservationRoomsTableFilterComposer(
              $db: $db,
              $table: $db.reservationRooms,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ReservationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReservationsTable> {
  $$ReservationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reservationNumber => $composableBuilder(
      column: $table.reservationNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get checkinDate => $composableBuilder(
      column: $table.checkinDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get checkoutDate => $composableBuilder(
      column: $table.checkoutDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get guestFullName => $composableBuilder(
      column: $table.guestFullName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get guestPhone => $composableBuilder(
      column: $table.guestPhone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get guestEmail => $composableBuilder(
      column: $table.guestEmail, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get depositCents => $composableBuilder(
      column: $table.depositCents,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdByLogin => $composableBuilder(
      column: $table.createdByLogin,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get cancelledAt => $composableBuilder(
      column: $table.cancelledAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cancelReason => $composableBuilder(
      column: $table.cancelReason,
      builder: (column) => ColumnOrderings(column));

  $$PayersTableOrderingComposer get payerId {
    final $$PayersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.payerId,
        referencedTable: $db.payers,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PayersTableOrderingComposer(
              $db: $db,
              $table: $db.payers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$StaysTableOrderingComposer get stayId {
    final $$StaysTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.stayId,
        referencedTable: $db.stays,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StaysTableOrderingComposer(
              $db: $db,
              $table: $db.stays,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReservationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReservationsTable> {
  $$ReservationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get reservationNumber => $composableBuilder(
      column: $table.reservationNumber, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get checkinDate => $composableBuilder(
      column: $table.checkinDate, builder: (column) => column);

  GeneratedColumn<DateTime> get checkoutDate => $composableBuilder(
      column: $table.checkoutDate, builder: (column) => column);

  GeneratedColumn<String> get guestFullName => $composableBuilder(
      column: $table.guestFullName, builder: (column) => column);

  GeneratedColumn<String> get guestPhone => $composableBuilder(
      column: $table.guestPhone, builder: (column) => column);

  GeneratedColumn<String> get guestEmail => $composableBuilder(
      column: $table.guestEmail, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DbReservationStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get depositCents => $composableBuilder(
      column: $table.depositCents, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get createdByLogin => $composableBuilder(
      column: $table.createdByLogin, builder: (column) => column);

  GeneratedColumn<DateTime> get cancelledAt => $composableBuilder(
      column: $table.cancelledAt, builder: (column) => column);

  GeneratedColumn<String> get cancelReason => $composableBuilder(
      column: $table.cancelReason, builder: (column) => column);

  $$PayersTableAnnotationComposer get payerId {
    final $$PayersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.payerId,
        referencedTable: $db.payers,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PayersTableAnnotationComposer(
              $db: $db,
              $table: $db.payers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$StaysTableAnnotationComposer get stayId {
    final $$StaysTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.stayId,
        referencedTable: $db.stays,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StaysTableAnnotationComposer(
              $db: $db,
              $table: $db.stays,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> reservationRoomsRefs<T extends Object>(
      Expression<T> Function($$ReservationRoomsTableAnnotationComposer a) f) {
    final $$ReservationRoomsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.reservationRooms,
        getReferencedColumn: (t) => t.reservationId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReservationRoomsTableAnnotationComposer(
              $db: $db,
              $table: $db.reservationRooms,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ReservationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReservationsTable,
    Reservation,
    $$ReservationsTableFilterComposer,
    $$ReservationsTableOrderingComposer,
    $$ReservationsTableAnnotationComposer,
    $$ReservationsTableCreateCompanionBuilder,
    $$ReservationsTableUpdateCompanionBuilder,
    (Reservation, $$ReservationsTableReferences),
    Reservation,
    PrefetchHooks Function(
        {bool payerId, bool stayId, bool reservationRoomsRefs})> {
  $$ReservationsTableTableManager(_$AppDatabase db, $ReservationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReservationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReservationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReservationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> reservationNumber = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> checkinDate = const Value.absent(),
            Value<DateTime> checkoutDate = const Value.absent(),
            Value<String> guestFullName = const Value.absent(),
            Value<String?> guestPhone = const Value.absent(),
            Value<String?> guestEmail = const Value.absent(),
            Value<int?> payerId = const Value.absent(),
            Value<DbReservationStatus> status = const Value.absent(),
            Value<int> depositCents = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String?> createdByLogin = const Value.absent(),
            Value<DateTime?> cancelledAt = const Value.absent(),
            Value<String?> cancelReason = const Value.absent(),
            Value<int?> stayId = const Value.absent(),
          }) =>
              ReservationsCompanion(
            id: id,
            reservationNumber: reservationNumber,
            createdAt: createdAt,
            checkinDate: checkinDate,
            checkoutDate: checkoutDate,
            guestFullName: guestFullName,
            guestPhone: guestPhone,
            guestEmail: guestEmail,
            payerId: payerId,
            status: status,
            depositCents: depositCents,
            note: note,
            createdByLogin: createdByLogin,
            cancelledAt: cancelledAt,
            cancelReason: cancelReason,
            stayId: stayId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String reservationNumber,
            Value<DateTime> createdAt = const Value.absent(),
            required DateTime checkinDate,
            required DateTime checkoutDate,
            required String guestFullName,
            Value<String?> guestPhone = const Value.absent(),
            Value<String?> guestEmail = const Value.absent(),
            Value<int?> payerId = const Value.absent(),
            Value<DbReservationStatus> status = const Value.absent(),
            Value<int> depositCents = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String?> createdByLogin = const Value.absent(),
            Value<DateTime?> cancelledAt = const Value.absent(),
            Value<String?> cancelReason = const Value.absent(),
            Value<int?> stayId = const Value.absent(),
          }) =>
              ReservationsCompanion.insert(
            id: id,
            reservationNumber: reservationNumber,
            createdAt: createdAt,
            checkinDate: checkinDate,
            checkoutDate: checkoutDate,
            guestFullName: guestFullName,
            guestPhone: guestPhone,
            guestEmail: guestEmail,
            payerId: payerId,
            status: status,
            depositCents: depositCents,
            note: note,
            createdByLogin: createdByLogin,
            cancelledAt: cancelledAt,
            cancelReason: cancelReason,
            stayId: stayId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ReservationsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {payerId = false, stayId = false, reservationRoomsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (reservationRoomsRefs) db.reservationRooms
              ],
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
                if (payerId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.payerId,
                    referencedTable:
                        $$ReservationsTableReferences._payerIdTable(db),
                    referencedColumn:
                        $$ReservationsTableReferences._payerIdTable(db).id,
                  ) as T;
                }
                if (stayId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.stayId,
                    referencedTable:
                        $$ReservationsTableReferences._stayIdTable(db),
                    referencedColumn:
                        $$ReservationsTableReferences._stayIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (reservationRoomsRefs)
                    await $_getPrefetchedData<Reservation, $ReservationsTable,
                            ReservationRoom>(
                        currentTable: table,
                        referencedTable: $$ReservationsTableReferences
                            ._reservationRoomsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ReservationsTableReferences(db, table, p0)
                                .reservationRoomsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.reservationId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ReservationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ReservationsTable,
    Reservation,
    $$ReservationsTableFilterComposer,
    $$ReservationsTableOrderingComposer,
    $$ReservationsTableAnnotationComposer,
    $$ReservationsTableCreateCompanionBuilder,
    $$ReservationsTableUpdateCompanionBuilder,
    (Reservation, $$ReservationsTableReferences),
    Reservation,
    PrefetchHooks Function(
        {bool payerId, bool stayId, bool reservationRoomsRefs})>;
typedef $$ReservationRoomsTableCreateCompanionBuilder
    = ReservationRoomsCompanion Function({
  Value<int> id,
  required int reservationId,
  required String roomNumber,
  required int pricePerNightCents,
});
typedef $$ReservationRoomsTableUpdateCompanionBuilder
    = ReservationRoomsCompanion Function({
  Value<int> id,
  Value<int> reservationId,
  Value<String> roomNumber,
  Value<int> pricePerNightCents,
});

final class $$ReservationRoomsTableReferences extends BaseReferences<
    _$AppDatabase, $ReservationRoomsTable, ReservationRoom> {
  $$ReservationRoomsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ReservationsTable _reservationIdTable(_$AppDatabase db) =>
      db.reservations
          .createAlias('reservation_rooms__reservation_id__reservations__id');

  $$ReservationsTableProcessedTableManager get reservationId {
    final $_column = $_itemColumn<int>('reservation_id')!;

    final manager = $$ReservationsTableTableManager($_db, $_db.reservations)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_reservationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ReservationRoomsTableFilterComposer
    extends Composer<_$AppDatabase, $ReservationRoomsTable> {
  $$ReservationRoomsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get roomNumber => $composableBuilder(
      column: $table.roomNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pricePerNightCents => $composableBuilder(
      column: $table.pricePerNightCents,
      builder: (column) => ColumnFilters(column));

  $$ReservationsTableFilterComposer get reservationId {
    final $$ReservationsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.reservationId,
        referencedTable: $db.reservations,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReservationsTableFilterComposer(
              $db: $db,
              $table: $db.reservations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReservationRoomsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReservationRoomsTable> {
  $$ReservationRoomsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get roomNumber => $composableBuilder(
      column: $table.roomNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pricePerNightCents => $composableBuilder(
      column: $table.pricePerNightCents,
      builder: (column) => ColumnOrderings(column));

  $$ReservationsTableOrderingComposer get reservationId {
    final $$ReservationsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.reservationId,
        referencedTable: $db.reservations,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReservationsTableOrderingComposer(
              $db: $db,
              $table: $db.reservations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReservationRoomsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReservationRoomsTable> {
  $$ReservationRoomsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get roomNumber => $composableBuilder(
      column: $table.roomNumber, builder: (column) => column);

  GeneratedColumn<int> get pricePerNightCents => $composableBuilder(
      column: $table.pricePerNightCents, builder: (column) => column);

  $$ReservationsTableAnnotationComposer get reservationId {
    final $$ReservationsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.reservationId,
        referencedTable: $db.reservations,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReservationsTableAnnotationComposer(
              $db: $db,
              $table: $db.reservations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReservationRoomsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReservationRoomsTable,
    ReservationRoom,
    $$ReservationRoomsTableFilterComposer,
    $$ReservationRoomsTableOrderingComposer,
    $$ReservationRoomsTableAnnotationComposer,
    $$ReservationRoomsTableCreateCompanionBuilder,
    $$ReservationRoomsTableUpdateCompanionBuilder,
    (ReservationRoom, $$ReservationRoomsTableReferences),
    ReservationRoom,
    PrefetchHooks Function({bool reservationId})> {
  $$ReservationRoomsTableTableManager(
      _$AppDatabase db, $ReservationRoomsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReservationRoomsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReservationRoomsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReservationRoomsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> reservationId = const Value.absent(),
            Value<String> roomNumber = const Value.absent(),
            Value<int> pricePerNightCents = const Value.absent(),
          }) =>
              ReservationRoomsCompanion(
            id: id,
            reservationId: reservationId,
            roomNumber: roomNumber,
            pricePerNightCents: pricePerNightCents,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int reservationId,
            required String roomNumber,
            required int pricePerNightCents,
          }) =>
              ReservationRoomsCompanion.insert(
            id: id,
            reservationId: reservationId,
            roomNumber: roomNumber,
            pricePerNightCents: pricePerNightCents,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ReservationRoomsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({reservationId = false}) {
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
                if (reservationId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.reservationId,
                    referencedTable: $$ReservationRoomsTableReferences
                        ._reservationIdTable(db),
                    referencedColumn: $$ReservationRoomsTableReferences
                        ._reservationIdTable(db)
                        .id,
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

typedef $$ReservationRoomsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ReservationRoomsTable,
    ReservationRoom,
    $$ReservationRoomsTableFilterComposer,
    $$ReservationRoomsTableOrderingComposer,
    $$ReservationRoomsTableAnnotationComposer,
    $$ReservationRoomsTableCreateCompanionBuilder,
    $$ReservationRoomsTableUpdateCompanionBuilder,
    (ReservationRoom, $$ReservationRoomsTableReferences),
    ReservationRoom,
    PrefetchHooks Function({bool reservationId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$ArticlesTableTableManager get articles =>
      $$ArticlesTableTableManager(_db, _db.articles);
  $$PayersTableTableManager get payers =>
      $$PayersTableTableManager(_db, _db.payers);
  $$StaysTableTableManager get stays =>
      $$StaysTableTableManager(_db, _db.stays);
  $$RoomsTableTableManager get rooms =>
      $$RoomsTableTableManager(_db, _db.rooms);
  $$SalesTableTableManager get sales =>
      $$SalesTableTableManager(_db, _db.sales);
  $$SaleLinesTableTableManager get saleLines =>
      $$SaleLinesTableTableManager(_db, _db.saleLines);
  $$DebtPaymentsTableTableManager get debtPayments =>
      $$DebtPaymentsTableTableManager(_db, _db.debtPayments);
  $$StockMovesTableTableManager get stockMoves =>
      $$StockMovesTableTableManager(_db, _db.stockMoves);
  $$ClientsTableTableManager get clients =>
      $$ClientsTableTableManager(_db, _db.clients);
  $$StayRoomsTableTableManager get stayRooms =>
      $$StayRoomsTableTableManager(_db, _db.stayRooms);
  $$ReservationsTableTableManager get reservations =>
      $$ReservationsTableTableManager(_db, _db.reservations);
  $$ReservationRoomsTableTableManager get reservationRooms =>
      $$ReservationRoomsTableTableManager(_db, _db.reservationRooms);
}
