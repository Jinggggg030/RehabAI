String exerciseDisciplineLabel(dynamic exercise) {
  if (exercise is! Map) return 'General';

  final disciplines = exercise['disciplines'];
  if (disciplines is Iterable) {
    final labels = disciplines
        .map((discipline) => discipline.toString().trim())
        .where((discipline) => discipline.isNotEmpty)
        .toList();
    if (labels.isNotEmpty) return labels.join(', ');
  }

  final singular = exercise['discipline']?.toString().trim();
  return singular == null || singular.isEmpty ? 'General' : singular;
}
