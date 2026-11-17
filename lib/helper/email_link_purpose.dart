/// Why a pending email-link address was stored.
///
/// A sign-in link and an account-linking link share the same storage and the
/// same single-use Firebase action code, but they are redeemed by different
/// flows. The purpose tag lets a generic consumer tell them apart so the wrong
/// flow never spends a code the right one still needs.
enum EmailLinkPurpose {
  /// The link signs the user in.
  signIn,

  /// The link links an email address to an already signed-in account.
  link,
}
