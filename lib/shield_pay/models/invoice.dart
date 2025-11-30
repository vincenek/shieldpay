class Invoice {
  final String payeeName;
  final String accountNumber;
  final double amount;
  final String email;
  final String vendorDomain;
  final DateTime? invoiceDate;

  Invoice({
    required this.payeeName,
    required this.accountNumber,
    required this.amount,
    required this.email,
    required this.vendorDomain,
    this.invoiceDate,
  });

  Map<String, dynamic> toJson() => {
        'payeeName': payeeName,
        'accountNumber': accountNumber,
        'amount': amount,
        'email': email,
        'vendorDomain': vendorDomain,
        'invoiceDate': invoiceDate?.toIso8601String(),
      };
}
