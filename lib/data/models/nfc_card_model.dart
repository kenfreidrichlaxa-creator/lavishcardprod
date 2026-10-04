enum NfcCardStatus { available, assigned, active, suspended, replaced }

class NfcCardModel {
  const NfcCardModel({
    required this.id,
    required this.cardId,
    required this.status,
    required this.registeredDate,
    this.ownerId,
    this.ownerName,
    this.lastUsed,
  });

  final String id;

  /// Physical card identifier printed on the card, e.g. LP-839274615
  final String cardId;
  final NfcCardStatus status;
  final DateTime registeredDate;
  final String? ownerId;
  final String? ownerName;
  final DateTime? lastUsed;

  bool get isAssigned => ownerId != null;

  NfcCardModel copyWith({
    NfcCardStatus? status,
    String? ownerId,
    String? ownerName,
    DateTime? lastUsed,
  }) {
    return NfcCardModel(
      id: id,
      cardId: cardId,
      status: status ?? this.status,
      registeredDate: registeredDate,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }
}
