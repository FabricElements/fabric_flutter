import 'package:flutter/widgets.dart';

import '../../serialized/agent_element_snapshot.dart';
import 'agent_element.dart';
import 'agent_element_index.dart';

/// Publishes its [child] to the live agent element index.
///
/// [AgentElement] is intentionally invisible to both the render tree and the
/// accessibility tree: it adds no [Semantics] node, applies no layout, and
/// returns [child] unchanged. When [id] is `null` it registers nothing at all,
/// so wrapping a widget that has no `automationKey` is free.
///
/// The registered entry is created on mount, refreshed whenever the owning
/// widget rebuilds or the enclosing route becomes current or covered, and
/// removed on dispose.
///
/// ```dart
/// AgentElement(
///   id: widget.automationKey,
///   type: AgentElementType.button,
///   label: widget.semanticsLabel,
///   hint: widget.semanticHint,
///   activator: widget.onPressed,
///   child: button,
/// );
/// ```
class AgentElement extends StatefulWidget {
  /// Creates a binding that indexes [child] under [id].
  const AgentElement({
    super.key,
    required this.child,
    this.id,
    this.type = AgentElementType.other,
    this.label,
    this.hint,
    this.valueGetter,
    this.enabledGetter,
    this.visibleGetter,
    this.setter,
    this.activator,
    this.index,
  });

  /// Holds the widget subtree published to the index.
  final Widget child;

  /// Identifies the element, normally the widget's `automationKey`.
  ///
  /// When `null`, nothing is registered and this widget is a pass-through.
  final String? id;

  /// Classifies how an agent can interact with the element.
  final AgentElementType type;

  /// Describes the element, normally the widget's `semanticsLabel`.
  final String? label;

  /// Provides extra guidance, normally the widget's `semanticHint`.
  final String? hint;

  /// Reads the element's current value; `null` when it carries no value.
  final AgentValueGetter? valueGetter;

  /// Reports whether the element currently accepts interaction.
  ///
  /// Defaults to `true` when omitted.
  final AgentStateGetter? enabledGetter;

  /// Reports whether the element is currently rendered.
  ///
  /// Defaults to the widget's mounted state combined with the enclosing
  /// route's state when omitted: an element is visible only while it is
  /// mounted, its route is the current one, and its subtree is not muted
  /// because an opaque route covers it.
  final AgentStateGetter? visibleGetter;

  /// Applies a new value, exactly as user input would.
  ///
  /// Leave `null` for elements that cannot be set, such as buttons.
  final AgentValueSetter? setter;

  /// Activates the element, exactly as a tap would.
  ///
  /// Leave `null` for elements that cannot be tapped.
  final AgentActivator? activator;

  /// Overrides the index the element registers itself in.
  ///
  /// Defaults to [AgentElementIndex.instance]. Tests use this to stay isolated
  /// from the shared index.
  final AgentElementIndex? index;

  /// Creates the state that owns the registration lifecycle.
  @override
  State<AgentElement> createState() => _AgentElementState();
}

/// Owns the register, refresh, and unregister lifecycle for [AgentElement].
class _AgentElementState extends State<AgentElement> {
  /// Holds the registered handle while an [AgentElement.id] is present.
  AgentElementHandle? _handle;

  /// Resolves the index this element registers itself in.
  AgentElementIndex get _index => widget.index ?? AgentElementIndex.instance;

  /// Registers the element when it is inserted into the tree.
  @override
  void initState() {
    super.initState();
    _register();
  }

  /// Refreshes or re-registers the element when the owning widget rebuilds.
  @override
  void didUpdateWidget(covariant AgentElement oldWidget) {
    super.didUpdateWidget(oldWidget);
    final indexChanged = oldWidget.index != widget.index;
    final idChanged = oldWidget.id != widget.id;
    if (idChanged || indexChanged) {
      _unregister(index: oldWidget.index ?? AgentElementIndex.instance);
      _register();
      return;
    }
    _handle?.updateFrom(_buildHandle()!);
  }

  /// Refreshes the element when the enclosing route or ticker mode changes.
  ///
  /// [ModalRoute.isCurrent] and [TickerMode] are inherited lookups, so a route
  /// becoming current or covered does not rebuild this widget on its own. The
  /// dependency registered by [build] brings us here instead, which is what
  /// keeps the indexed visibility in step with the route.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final handle = _handle;
    if (handle == null) return;
    handle.updateFrom(_buildHandle()!);
  }

  /// Removes the element from the index when it leaves the tree.
  @override
  void dispose() {
    _unregister();
    super.dispose();
  }

  /// Registers a freshly built handle when an identifier is available.
  void _register() {
    final handle = _buildHandle();
    if (handle == null) return;
    _handle = handle;
    _index.register(handle);
  }

  /// Removes the current handle from [index], defaulting to the active index.
  void _unregister({AgentElementIndex? index}) {
    final handle = _handle;
    if (handle == null) return;
    (index ?? _index).unregister(handle);
    _handle = null;
  }

  /// Builds a handle from the current widget configuration.
  ///
  /// Returns `null` when [AgentElement.id] is `null` or empty, which is what
  /// keeps unkeyed widgets entirely out of the index.
  AgentElementHandle? _buildHandle() {
    final id = widget.id;
    if (id == null || id.isEmpty) return null;
    return AgentElementHandle(
      id: id,
      type: widget.type,
      label: widget.label,
      hint: widget.hint,
      valueGetter: widget.valueGetter,
      enabledGetter: widget.enabledGetter,
      visibleGetter: widget.visibleGetter ?? _isVisible,
      setter: widget.setter,
      activator: widget.activator,
    );
  }

  /// Reports whether this element is rendered on screen right now.
  ///
  /// Being mounted is not enough. A route that another route covers keeps its
  /// subtree mounted, an outgoing route stays mounted for the whole push
  /// transition, and a nested navigator or a two-pane layout can hold several
  /// routes at once. An element therefore counts as visible only while its
  /// route is the current one and its subtree is not muted because an opaque
  /// route covers it, so two same-key elements that are merely mounted no
  /// longer look like a duplicate.
  ///
  /// Both lookups default to visible when there is no route or [TickerMode]
  /// ancestor, which keeps bare widget tests unchanged. A route covered by a
  /// non-opaque route such as a dialog is not current either, so its elements
  /// report invisible while that route is on top.
  bool _isVisible() {
    if (!mounted) return false;
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    return TickerMode.valuesOf(context).enabled;
  }

  /// Returns [AgentElement.child] unchanged.
  ///
  /// The [TickerMode] lookup is what registers the dependency that refreshes
  /// the indexed visibility when another route covers this one.
  @override
  Widget build(BuildContext context) {
    TickerMode.valuesOf(context);
    return widget.child;
  }
}
