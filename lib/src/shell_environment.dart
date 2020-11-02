import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:process_run/shell.dart';
import 'package:process_run/src/shell_utils.dart';

/// Shell environment ordered paths helper. Changes the PATH variable
class ShellEnvironmentPaths with ListMixin<String> {
  final ShellEnvironment _environment;

  ShellEnvironmentPaths._(this._environment);

  List<String> get _paths {
    return _environment[envPathKey]?.split(envPathSeparator) ?? <String>[];
  }

  set _paths(List<String> paths) {
    _environment[envPathKey] = paths.join(envPathSeparator);
  }

  /// Prepend a path (i.e. higher in the hierarchy to handle a [which] resolution.
  void prepend(String path) {
    _paths = [path, ..._paths];
  }

  @override
  int get length => _paths.length;

  @override
  String operator [](int index) {
    return _paths[index];
  }

  @override
  void operator []=(int index, String value) {
    _paths = _paths..[index] = value;
  }

  @override
  set length(int newLength) {
    _paths = _paths..length = newLength;
  }

  /// Merge an environment.
  ///
  /// the other object, paths are prepended.
  void merge(ShellEnvironmentPaths paths) {
    _paths = _paths
      ..removeWhere((element) => paths.contains(element))
      ..insertAll(0, paths);
  }

  @override
  int get hashCode => const ListEquality().hash(this);

  @override
  bool operator ==(Object other) {
    if (other is ShellEnvironmentPaths) {
      return const ListEquality().equals(this, other);
    }
    return false;
  }

  @override
  String toString() => 'Path($length)';
}

/// Shell environment variables helper. Does not affect the PATH variable
class ShellEnvironmentVars with MapMixin<String, String> {
  final ShellEnvironment _environment;

  ShellEnvironmentVars._(this._environment);

  /// Currently only the PATH key is ignored.
  bool _ignoreKey(key) => key == envPathKey;

  @override
  String operator [](Object key) {
    if (_ignoreKey(key)) {
      return null;
    }
    return _environment[key];
  }

  @override
  void operator []=(String key, String value) {
    if (!_ignoreKey(key)) {
      _environment[key] = value;
    }
  }

  @override
  void clear() {
    removeWhere((key, value) => !_ignoreKey(key));
  }

  @override
  Iterable<String> get keys =>
      _environment.keys.where((key) => !_ignoreKey(key));

  @override
  String remove(Object key) {
    if (!_ignoreKey(key)) {
      return _environment.remove(key);
    }
    return null;
  }

  /// the other object takes precedence, vars are added
  void merge(ShellEnvironmentVars other) {
    addAll(other);
  }

  // Key hash is sufficient here
  @override
  int get hashCode => const ListEquality().hash(keys.toList());

  @override
  bool operator ==(Object other) {
    if (other is ShellEnvironmentVars) {
      return const MapEquality().equals(this, other);
    }
    return false;
  }

  @override
  String toString() => 'Vars($length)';
}

/// Use current if already and environment object.
ShellEnvironment asShellEnvironment(Map<String, String> environment) =>
    (environment is ShellEnvironment)
        ? environment
        : ShellEnvironment(environment: environment);

/// Shell modifiable helpers. should not be modified after being set.
class ShellEnvironment with MapMixin<String, String> {
  /// The resulting _env
  final _env = <String, String>{};

  /// The vars but the PATH variable
  ShellEnvironmentVars _vars;

  /// The vars but the PATH variable
  ShellEnvironmentVars get vars => _vars ??= ShellEnvironmentVars._(this);

  /// The PATH variable as a convenient list.
  ShellEnvironmentPaths _paths;

  /// The PATH variable as a convenient list.
  ShellEnvironmentPaths get paths => _paths ??= ShellEnvironmentPaths._(this);

  /// Create a new shell environment from the current shellEnvironment.
  ///
  /// Defaults create a full parent environment.
  ///
  /// It is recommended that you apply the environment to a shell. But it can
  /// also be set globally (be aware of the potential effect on other part of
  /// your application) to [shellEnvironment]
  ShellEnvironment({Map<String, String> environment}) {
    environment ??= shellEnvironment;
    _env.addAll(environment);
  }

  /// From a run start content, includeParentEnvironment should later be set
  /// to false
  factory ShellEnvironment.full(
      {Map<String, String> environment, bool includeParentEnvironment = true}) {
    ShellEnvironment newEnvironment;
    if (includeParentEnvironment) {
      newEnvironment = ShellEnvironment();
      newEnvironment.merge(asShellEnvironment(environment));
    } else {
      newEnvironment = asShellEnvironment(environment);
    }
    return newEnvironment;
  }

  @override
  String operator [](Object key) => _env[key];

  @override
  void operator []=(String key, String value) => _env[key] = value;

  @override
  void clear() {
    _env.clear();
  }

  @override
  Iterable<String> get keys => _env.keys;

  @override
  String remove(Object key) {
    return _env.remove(key);
  }

  /// Create an empty shell environment.
  ///
  /// Mainly used for testing as it is not easy to which environment variable
  /// are required.
  ShellEnvironment.empty();

  /// From json.
  ///
  /// Mainly used for testing as it is not easy to which environment variable
  /// are required.
  ShellEnvironment.fromJson(Map map) {
    try {
      if (map != null) {
        var rawVars = map['vars'];
        if (rawVars is Map) {
          vars.addAll(rawVars.cast<String, String>());
        }
        var rawPaths = map['paths'];
        if (rawPaths is Iterable) {
          paths.addAll(rawPaths.cast<String>());
        }
      }
    } catch (_) {
      // Silent crash
    }
  }

  /// Merge an environment.
  ///
  /// the other object takes precedence, vars are added and paths prepended
  void merge(ShellEnvironment other) {
    if (other != null) {
      vars.merge(other.vars);
      paths.merge(other.paths);
    }
  }

  /// Find a [command] path location in the environment
  String whichSync(String command) {
    return findExecutableSync(
      command,
      paths,
    );
  }

  /// Find a [command] path location in the environment
  Future<String> which(String command) async {
    return whichSync(command);
  }

  /// `paths` and `vars` key
  Map<String, dynamic> toJson() {
    return <String, dynamic>{'paths': paths, 'vars': vars};
  }

  @override
  int get hashCode => const ListEquality().hash(paths);

  @override
  bool operator ==(Object other) {
    if (other is ShellEnvironment) {
      if (other.vars != vars) {
        return false;
      }
      if (other.paths != paths) {
        return false;
      }
      return true;
    }
    return false;
  }

  @override
  String toString() => 'ShellEnvironment($paths, $vars)';
}
