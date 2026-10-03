/// The `if:` of the step in [workflow] that runs [command], or null when that
/// step has none. A step runs from its `- ` line to the next line indented no
/// deeper; a comment that names the command is not the step.
String? conditionOf(String workflow, String command) {
  final lines = workflow.split('\n');
  var start = lines.indexWhere(
    (line) => line.contains(command) && !line.trimLeft().startsWith('#'),
  );
  if (start < 0) {
    throw StateError('no step runs $command');
  }
  while (!lines[start].trimLeft().startsWith('- ')) {
    start--;
  }
  final indent = lines[start].indexOf('-');
  final step = [
    lines[start],
    ...lines
        .skip(start + 1)
        .takeWhile(
          (line) => line.trim().isEmpty || line.indexOf(RegExp(r'\S')) > indent,
        ),
  ];
  for (final line in step) {
    if (RegExp(r'^[\s-]*if:\s*(.+)$').firstMatch(line) case final match?) {
      return match[1]!.trim();
    }
  }
  return null;
}
