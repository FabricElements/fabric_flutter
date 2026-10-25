import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../../serialized/agent_element_snapshot.dart';
import '../scroll_reveal.dart';
import 'agent_element.dart';
import 'agent_element_index.dart';

/// Publishes its [child] to the live agent element index and, when [id] is
/// non-empty, applies that same id as the [Semantics.identifier] on [child].
///
/// The identifier is applied as a fold that merges into the child's existing
/// semantics node rather than introducing a new one. [container] and
/// [explicitChildNodes] are forwarded to that fold so the identifier can land
/// on the same node as the child's own container or explicit-child boundary,
/// which is what keeps the accessibility tree unchanged: an identifier alone
/// (or a container alone) forces a semantics boundary, so they must live on
/// one node together. When [id] is `null` or empty it registers nothing and
/// returns [child] unchanged, so wrapping a widget that has no `automationKey`
/// is free.
///
/// [semanticActions] exposes named callbacks as
/// [Semantics.customSemanticsActions] on the same merged node, so assistive
/// technology and the agent see the same verbs. Each label maps to a
/// [VoidCallback] that the agent can invoke through the `tap` command's
/// `action` parameter. Only expose actions the UI already offers — do not
/// invent new ones.
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
    this.validatorFn,
    this.errorGetter,
    this.focusNode,
    this.index,
    this.applySemanticsIdentifier = true,
    this.container = true,
    this.explicitChildNodes = false,
    this.semanticActions,
  });

  /// Holds the widget subtree published to the index.
  final Widget child;

  /// Identifies the element, normally the widget's `automationKey`.
  ///
  /// When `null` or empty, nothing is registered and no identifier is applied,
  /// so this widget is a pass-through.
  final String? id;

  /// Whether [id] is applied as a [Semantics.identifier] on [child].
  ///
  /// Defaults to `true`. Set it to `false` when the caller already places the
  /// identifier on a different semantics node and this widget should only own
  /// the agent index registration.
  final bool applySemanticsIdentifier;

  /// Whether the identifier fold is a semantics container.
  ///
  /// Defaults to `true` because a bare identifier is itself a boundary, and a
  /// container keeps the merged node's role and children intact.
  final bool container;

  /// Whether the identifier fold declares explicit child nodes.
  ///
  /// Defaults to `false`. Pass `true` when the wrapped component already used
  /// `explicitChildNodes: true`, in which case this fold also carries [label]
  /// and [hint] directly so they stay on the same node as the identifier. When
  /// `false` the label and hint are left to the child's own `Semantics` node,
  /// which merges them up into this fold.
  final bool explicitChildNodes;

  /// Named actions exposed as [Semantics.customSemanticsActions] on the
  /// merged semantics node.
  ///
  /// Each label maps to a [VoidCallback] that the agent can invoke through the
  /// `tap` command's `action` parameter. Only expose actions the UI already
  /// offers — do not invent new ones. When `null` or empty, no custom actions
  /// are added and the semantics tree is unchanged.
  final Map<String, VoidCallback>? semanticActions;

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

  /// Runs the element's validator on a raw value and returns any error.
  ///
  /// Leave `null` for elements that carry no validation, such as buttons.
  final AgentValidator? validatorFn;

  /// Returns the current validation error text, or `null` when valid.
  final String? Function()? errorGetter;

  /// The [FocusNode] moved to by [AgentElementHandle.requestFocus].
  ///
  /// When `null`, `requestFocus` walks the element's subtree to find the first
  /// focusable descendant instead. Pass the same node the component already
  /// owns so no new [FocusNode] is created.
  final FocusNode? focusNode;

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
    final focusNode = widget.focusNode;
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
      validatorFn: widget.validatorFn,
      errorGetter: widget.errorGetter,
      semanticActions: widget.semanticActions,
      contextGetter: mounted
          ? () {
              // Walk past the Semantics wrapper so Actions and Form
              // lookups start from the content child, not the
              // Semantics node that binds the identifier.
              BuildContext? target;
              context.visitChildElements((semanticsElement) {
                semanticsElement.visitChildElements((contentElement) {
                  target = contentElement;
                });
              });
              return target ?? context;
            }
          : null,
      revealFn: mounted
          ? ({double alignment = 0.1}) {
              // Walk past the Semantics wrapper so ScrollReveal starts
              // from a render object that is inside the viewport. The
              // state's build context is the Semantics widget, whose
              // RenderSemanticsAnnotations is not a viewport descendant.
              BuildContext target = context;
              context.visitChildElements((semanticsElement) {
                semanticsElement.visitChildElements((contentElement) {
                  target = contentElement;
                });
              });
              return ScrollReveal.reveal(target, alignment: alignment);
            }
          : null,
      requestFocusFn: () {
        final target = focusNode;
        if (target != null) {
          target.requestFocus();
          return true;
        }
        // Walk the subtree for the first focusable descendant, but only
        // when there is one — an empty scope claims focus itself, which is
        // indistinguishable from a successful focus and would mislead an
        // agent into thinking an inert element accepted focus.
        final scope = FocusScope.of(context);
        if (scope.traversalDescendants.isEmpty) return false;
        return scope.focusInDirection(TraversalDirection.down);
      },
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

  /// Returns [AgentElement.child], wrapped in an identifier fold when one is
  /// requested.
  ///
  /// The [TickerMode] lookup is what registers the dependency that refreshes
  /// the indexed visibility when another route covers this one.
  @override
  Widget build(BuildContext context) {
    TickerMode.valuesOf(context);
    final child = widget.child;
    final id = widget.id;
    if (!widget.applySemanticsIdentifier || id == null || id.isEmpty) {
      return child;
    }
    final actions = widget.semanticActions;
    final customActions = actions != null && actions.isNotEmpty
        ? <CustomSemanticsAction, VoidCallback>{
            for (final entry in actions.entries)
              CustomSemanticsAction(label: entry.key): entry.value,
          }
        : null;
    return Semantics(
      identifier: id,
      container: widget.container,
      explicitChildNodes: widget.explicitChildNodes,
      label: widget.explicitChildNodes ? widget.label : null,
      hint: widget.explicitChildNodes ? widget.hint : null,
      customSemanticsActions: customActions,
      child: child,
    );
  }
}
