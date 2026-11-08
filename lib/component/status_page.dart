import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/density_spacing.dart';
import '../state/state_global.dart';
import 'content_container.dart';
import 'live_announcer.dart';

/// The kind of blocked or failed state a [StatusPage] renders.
///
/// The variants are backend-agnostic: adapters translate transport-specific
/// errors (HTTP status codes, API error strings) into one of these values, so
/// the page itself never depends on any backend package.
enum StatusVariant {
  /// The route or address does not exist.
  notFound,

  /// The user is signed in but lacks the required role or permission.
  forbidden,

  /// A concrete resource (document, record, file) does not exist.
  resourceNotFound,

  /// The user must sign in to view the content.
  unauthenticated,

  /// The backing service is temporarily unreachable.
  unavailable,

  /// The resource exists but has been archived and is read-only.
  archived,

  /// An unexpected error occurred while loading the content.
  unexpected,
}

/// Adds backend-agnostic mappings and locale keys to [StatusVariant].
extension StatusVariantMapping on StatusVariant {
  /// Returns the variant matching an `error--###`-style HTTP status code.
  ///
  /// [code] may be a prefixed locale key (`error--404`), a plain numeric status
  /// (`404`), or null; unknown values map to [StatusVariant.unexpected] so
  /// callers can route any thrown error string through this safely.
  static StatusVariant fromErrorCode(String? code) {
    switch (code) {
      case 'error--400':
      case '400':
        return StatusVariant.notFound;
      case 'error--401':
      case '401':
        return StatusVariant.unauthenticated;
      case 'error--403':
      case '403':
        return StatusVariant.forbidden;
      case 'error--404':
      case '404':
        return StatusVariant.resourceNotFound;
      case 'error--500':
      case '500':
      case 'error--504':
      case '504':
        return StatusVariant.unavailable;
      default:
        return StatusVariant.unexpected;
    }
  }

  /// Returns the icon that illustrates this variant.
  IconData get icon {
    switch (this) {
      case StatusVariant.notFound:
        return Icons.travel_explore_outlined;
      case StatusVariant.forbidden:
        return Icons.lock_outline;
      case StatusVariant.resourceNotFound:
        return Icons.search_off_outlined;
      case StatusVariant.unauthenticated:
        return Icons.login_outlined;
      case StatusVariant.unavailable:
        return Icons.wifi_off_outlined;
      case StatusVariant.archived:
        return Icons.archive_outlined;
      case StatusVariant.unexpected:
        return Icons.error_outline;
    }
  }

  /// Returns the locale key for this variant's title.
  String get titleKey {
    switch (this) {
      case StatusVariant.notFound:
        return 'status--not-found-title';
      case StatusVariant.forbidden:
        return 'status--forbidden-title';
      case StatusVariant.resourceNotFound:
        return 'status--resource-not-found-title';
      case StatusVariant.unauthenticated:
        return 'status--unauthenticated-title';
      case StatusVariant.unavailable:
        return 'status--unavailable-title';
      case StatusVariant.archived:
        return 'status--archived-title';
      case StatusVariant.unexpected:
        return 'status--unexpected-title';
    }
  }

  /// Returns the locale key for this variant's description.
  String get descriptionKey {
    switch (this) {
      case StatusVariant.notFound:
        return 'status--not-found-description';
      case StatusVariant.forbidden:
        return 'status--forbidden-description';
      case StatusVariant.resourceNotFound:
        return 'status--resource-not-found-description';
      case StatusVariant.unauthenticated:
        return 'status--unauthenticated-description';
      case StatusVariant.unavailable:
        return 'status--unavailable-description';
      case StatusVariant.archived:
        return 'status--archived-description';
      case StatusVariant.unexpected:
        return 'status--unexpected-description';
    }
  }

  /// Whether this variant describes a transient condition that can be retried.
  bool get transient {
    switch (this) {
      case StatusVariant.notFound:
      case StatusVariant.forbidden:
      case StatusVariant.resourceNotFound:
      case StatusVariant.unauthenticated:
      case StatusVariant.archived:
        return false;
      case StatusVariant.unavailable:
      case StatusVariant.unexpected:
        return true;
    }
  }
}

/// Renders a full-page status, error, or empty state.
///
/// The page adapts to the [variant]: it shows an icon, a localized title and
/// description, and an actions row with Back, Retry, Home, and any extra
/// [actions] the caller supplies. Back pops the current route when there is
/// history and otherwise opens [homeRoute], so deep links still land somewhere
/// useful. Retry is offered only for transient variants and while the device is
/// online, and the title and description are announced to screen readers.
///
/// Set [parent] to `true` to wrap the page in its own `Scaffold` with an app
/// bar, for hosts that render it outside an existing route shell.
class StatusPage extends StatelessWidget {
  /// Creates a status page for [variant].
  const StatusPage({
    super.key,
    required this.variant,
    this.onRetry,
    this.homeRoute = '/',
    this.title,
    this.description,
    this.actions = const [],
    this.parent = false,
  });

  /// The kind of status this page renders.
  final StatusVariant variant;

  /// Invoked when the user presses Retry; omit it to hide the action.
  final VoidCallback? onRetry;

  /// The route opened by Back and Home when no route history exists.
  final String homeRoute;

  /// Overrides the localized title for this instance.
  final String? title;

  /// Overrides the localized description for this instance.
  final String? description;

  /// Additional actions rendered after the built-in ones.
  final List<Widget> actions;

  /// Whether the page should render its own `Scaffold` with an app bar.
  final bool parent;

  /// Builds the localized, centered status content with its actions row.
  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final locales = AppLocalizations.of(context);
    final density = DensitySpacing.of(context);
    final stateGlobal = Provider.of<StateGlobal>(context, listen: false);
    final pageTitle = title ?? locales.get(variant.titleKey);
    final pageDescription = description ?? locales.get(variant.descriptionKey);
    // Status pages appear after an async resolution, so they are announced.
    return Center(
      child: SingleChildScrollView(
        child: LiveAnnouncer(
          message: '$pageTitle. $pageDescription',
          child: ContentContainer(
            margin: density.all(16, min: 8),
            child: Flex(
              direction: Axis.vertical,
              mainAxisSize: MainAxisSize.min,
              spacing: density.gap(24, min: 12),
              children: [
                Icon(variant.icon, size: 48, color: colorScheme.error),
                Text(
                  pageTitle,
                  style: textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                Text(
                  pageDescription,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                StreamBuilder(
                  stream: stateGlobal.streamConnection,
                  builder: (context, snapshot) {
                    final connected = snapshot.data ?? stateGlobal.connected;
                    final canRetry = onRetry != null && connected;
                    return Wrap(
                      alignment: WrapAlignment.center,
                      spacing: density.gap(8, min: 4),
                      runSpacing: density.gap(4, min: 2),
                      children: [
                        if (onRetry != null && variant.transient)
                          FilledButton.icon(
                            autofocus: true,
                            onPressed: canRetry ? onRetry : null,
                            icon: const Icon(Icons.refresh),
                            label: Text(locales.get('label--retry')),
                          ),
                        FilledButton.icon(
                          autofocus: onRetry == null,
                          onPressed: () {
                            final navigator = Navigator.of(context);
                            if (navigator.canPop()) {
                              navigator.pop();
                            } else {
                              navigator.pushNamed(homeRoute);
                            }
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: Text(locales.get('label--go-back')),
                        ),
                        OutlinedButton(
                          onPressed: () => Navigator.of(context)
                              .pushNamedAndRemoveUntil(
                                homeRoute,
                                (route) => false,
                              ),
                          child: Text(locales.get('label--go-home')),
                        ),
                        ...actions,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the status page, optionally inside its own `Scaffold`.
  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    if (!parent) {
      return content;
    }
    return Scaffold(appBar: AppBar(), primary: true, body: content);
  }
}
