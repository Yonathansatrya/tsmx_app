enum ActionType {
  warning,
  info,
  action,
}

class ActionItem {
  final String id;
  final String title;
  final String description;
  final ActionType type;
  final String timeString;

  ActionItem({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.timeString,
  });

  ActionItem copyWith({
    String? id,
    String? title,
    String? description,
    ActionType? type,
    String? timeString,
  }) {
    return ActionItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      timeString: timeString ?? this.timeString,
    );
  }
}
