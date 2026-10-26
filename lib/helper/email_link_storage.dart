/// Exports the platform-specific storage for the passwordless email-link flow.
///
/// A sign-in link is completed by opening it, which either reloads the page
/// (web) or relaunches the app (Android/iOS), so the email address the link was
/// sent to has to outlive that round trip. The web implementation uses the
/// browser's `localStorage`; Android and iOS keep the address in memory, which
/// is enough because the process survives the trip through the mail app.
/// Consumers import this file and use [EmailLinkStorage] without branching on
/// the platform themselves.
library;

export 'email_link_storage_native.dart'
    if (dart.library.js_interop) 'email_link_storage_web.dart';
