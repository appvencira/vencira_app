/// In-memory validity gate for a future authenticated mobile session.
///
/// This class stores no bearer token and creates no credentials. A reviewed
/// session controller must activate it only AFTER native authentication and
/// local credential protection have succeeded. On logout, workspace change,
/// session expiry, or failure to clean up sensitive state, revoke it FIRST.
///
/// A request ticket is tied to one generation. Late HTTP results from a
/// previous generation must never be delivered to screens.
class NativeSessionFence {
  int _generation = 0;
  bool _active = false;

  int? get ticket => _active ? _generation : null;

  bool accepts(int? ticket) =>
      ticket != null && _active && _generation == ticket;

  /// Called only by a future, independently verified session coordinator.
  void activate() {
    _generation++;
    _active = true;
  }

  /// Synchronous fail-closed invalidation before any asynchronous cleanup.
  void revoke() {
    _generation++;
    _active = false;
  }
}
