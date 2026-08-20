import '../../serialized/agent_command_info.dart';
import 'agent_command.dart';

/// Stores the commands an agent can discover and invoke.
///
/// Host applications register their domain commands here, alongside the
/// built-in commands the bridge installs. The registry is intentionally free of
/// transport and access-control concerns: it only owns the catalog.
class AgentRegistry {
  /// Creates an empty registry.
  AgentRegistry();

  /// Maps each command identifier to its registered command.
  final Map<String, AgentCommand> _commands = <String, AgentCommand>{};

  /// Returns every registered command in registration order.
  List<AgentCommand> get commands => List.unmodifiable(_commands.values);

  /// Returns every registered command identifier in registration order.
  List<String> get ids => List.unmodifiable(_commands.keys);

  /// Reports how many commands are currently registered.
  int get length => _commands.length;

  /// Reports whether a command with [id] is registered.
  bool contains(String id) => _commands.containsKey(id);

  /// Returns the command registered under [id], or `null` when absent.
  AgentCommand? byId(String id) => _commands[id];

  /// Registers [command] and returns it.
  ///
  /// Throws an [ArgumentError] when the identifier is empty, or when another
  /// command already uses the same identifier and [override] is `false`. Pass
  /// `override: true` to intentionally replace an existing registration, which
  /// lets a host application specialize a built-in command.
  AgentCommand register(AgentCommand command, {bool override = false}) {
    final id = command.id;
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'command.id', 'must not be empty');
    }
    if (!override && _commands.containsKey(id)) {
      throw ArgumentError.value(
        id,
        'command.id',
        'is already registered; pass override: true to replace it',
      );
    }
    _commands[id] = command;
    return command;
  }

  /// Registers every command in [commands], honoring [override].
  void registerAll(Iterable<AgentCommand> commands, {bool override = false}) {
    for (final command in commands) {
      register(command, override: override);
    }
  }

  /// Removes the command registered under [id].
  ///
  /// Returns `true` when a command was removed and `false` when none matched.
  bool unregister(String id) => _commands.remove(id) != null;

  /// Removes every registered command.
  void clear() => _commands.clear();

  /// Returns the registered commands grouped by [AgentCommand.category].
  Map<String, List<AgentCommand>> byCategory() {
    final grouped = <String, List<AgentCommand>>{};
    for (final command in _commands.values) {
      grouped
          .putIfAbsent(command.category, () => <AgentCommand>[])
          .add(command);
    }
    return grouped;
  }

  /// Returns every command registered under [category], in registration order.
  List<AgentCommand> withCategory(String category) => List.unmodifiable(
    _commands.values.where((command) => command.category == category),
  );

  /// Returns the serializable catalog published by the bridge's `describe`.
  List<AgentCommandInfo> catalog() =>
      _commands.values.map((command) => command.info).toList(growable: false);

  /// Returns the catalog as a list of JSON maps.
  List<Map<String, dynamic>> toJson() =>
      catalog().map((info) => info.toJson()).toList(growable: false);
}
