/// Conservative decision model for ambiguous HTTP authentication failures.
/// This module has no network, UI or OS side effects. A 403 alone is not
/// evidence of an expired login under Django REST Framework SessionAuth.
enum SessionDenial {
  expired,
  forbidden,
  unknown,
}

enum IdentityProbe {
  authenticated,
  unauthenticated,
  unavailable,
}

/// Only a confirmed loss of identity permits session-wide cleanup.
/// Workspace membership loss is separately handled by the workspace guard.
SessionDenial classifySessionDenial({
  required int statusCode,
  required IdentityProbe identity,
}) {
  if (statusCode != 401 && statusCode != 403) {
    return SessionDenial.unknown;
  }
  if (identity == IdentityProbe.unauthenticated) {
    return SessionDenial.expired;
  }
  if (identity == IdentityProbe.authenticated) {
    return SessionDenial.forbidden;
  }
  return SessionDenial.unknown;
}
