/// Identity of a local alarm inventory. User ID is obtained exclusively
/// from the authenticated /api/v1/me response; workspace from current
/// authorized membership. Never derive either value from display names.
class DeviceAlarmScope {
  DeviceAlarmScope({required this.workspaceId, required this.userId}) {
    if (!RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
            r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(workspaceId) ||
        !RegExp(r'^[0-9]{1,20}$').hasMatch(userId)) {
      throw const FormatException('Invalid authenticated alarm identity');
    }
  }

  final String workspaceId;
  final String userId;

  @override
  bool operator ==(Object other) =>
      other is DeviceAlarmScope &&
      workspaceId == other.workspaceId && userId == other.userId;

  @override
  int get hashCode => Object.hash(workspaceId, userId);
}
