import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tracks whether the mocked default Firebase app has already been created so
/// repeated [setupFirebaseForTest] calls stay cheap and idempotent.
bool _firebaseReady = false;

/// Initializes a mocked Firebase environment for widget and unit tests.
///
/// Registering the `firebase_core` platform mocks and creating the default
/// app once per test process lets any code that reaches for a Firebase
/// singleton — such as `FirebaseAuth.instance`, `FirebaseFirestore.instance`,
/// or `FirebaseStorage.instance` — run without a real backend, real platform
/// channels, or a network connection. This is what makes the many fabric
/// widgets and state containers that reference those singletons (for example
/// [StateUser], [StateUsers], and anything reading them through `Provider`)
/// mountable inside `testWidgets`.
///
/// Fabric containers such as `StateUser` and `StateUsers` reach these
/// singletons through top-level finals, so this harness is the single entry
/// point that makes them safe to construct and pump in a test.
///
/// Call it from a test's `setUp`, `setUpAll`, or at the top of an individual
/// test before touching Firebase. It is safe to call repeatedly: the mock
/// platform is registered every time (so late-binding tests still work) while
/// the default app is only created once.
///
/// The mocks make the singletons resolvable and let streams such as
/// `FirebaseAuth.instance.userChanges()` be subscribed to without throwing.
/// They do not simulate stored data, so tests that need specific documents or
/// an authenticated user should inject that state directly (for example by
/// seeding a state container or providing a fake through `Provider`).
Future<void> setupFirebaseForTest() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  if (_firebaseReady) return;
  await Firebase.initializeApp();
  _firebaseReady = true;
}
