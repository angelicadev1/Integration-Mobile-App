class ReconRunModel {
  final String runId;
  final String status;
  final int totalChecked;
  final int totalMatched;
  final int totalExceptions;
  final DateTime startedAt;

  ReconRunModel({
    required this.runId,
    required this.status,
    required this.totalChecked,
    required this.totalMatched,
    required this.totalExceptions,
    required this.startedAt,
  });

  bool get hasExceptions => totalExceptions > 0;

  factory ReconRunModel.fromJson(Map<String, dynamic> json) {
    DateTime dt;
    try {
      dt = json['startedAt'] != null ? DateTime.parse(json['startedAt'].toString()) : DateTime.now();
    } catch (_) {
      dt = DateTime.now();
    }

    return ReconRunModel(
      runId: json['runId']?.toString() ?? 'RUN-${DateTime.now().millisecondsSinceEpoch}',
      status: json['status']?.toString() ?? 'COMPLETED',
      totalChecked: int.tryParse(json['totalChecked']?.toString() ?? '0') ?? 0,
      totalMatched: int.tryParse(json['totalMatched']?.toString() ?? '0') ?? 0,
      totalExceptions: int.tryParse(json['totalExceptions']?.toString() ?? '0') ?? 0,
      startedAt: dt,
    );
  }
}
