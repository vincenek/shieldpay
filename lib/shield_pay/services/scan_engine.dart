import '../models/invoice.dart';
import '../models/scan_result.dart';
import 'dart:math';
import 'settings_service.dart';

class ScanEngine {
  static Future<ScanResult> scan(Invoice invoice, {List<Map<String, dynamic>>? history}) async {
    double dScore = 0.0;
    final reasons = <String>[];
    final acc = invoice.accountNumber.trim();

    final settings = SettingsService.instance.current;
    // IBAN / account validation (mod97 when possible)
    final ibanOk = _validateIban(acc);
    if (!ibanOk) {
      dScore += 40.0 * settings.ibanWeight;
      reasons.add('Account/IBAN format or checksum invalid.');
    }

    // Email heuristics
    final emailDomain = _extractDomain(invoice.email);
    final freeProviders = {'gmail.com', 'yahoo.com', 'hotmail.com', 'outlook.com', 'icloud.com'};
    if (emailDomain.isNotEmpty && freeProviders.contains(emailDomain)) {
      dScore += 8.0 * settings.freeEmailWeight;
      reasons.add('Email uses a free provider ($emailDomain).');
    }

    // Vendor/domain vs name similarity
    if (invoice.vendorDomain.isNotEmpty) {
      final vendorNormalized = invoice.vendorDomain.replaceAll(RegExp(r'https?://'), '').replaceAll('www.', '').split('/').first.replaceAll(RegExp(r'[^a-z0-9]', caseSensitive: false), ' ').trim();
      final similarity = _simpleSimilarity(invoice.payeeName, vendorNormalized);
      if (similarity < settings.similarityThreshold) {
        dScore += 12.0 * settings.vendorMismatchWeight;
        reasons.add('Payee name and vendor domain look mismatched (similarity ${similarity.toStringAsFixed(2)}).');
      }
    }

    // Amount heuristics
    if (invoice.amount <= 0) {
      dScore += 15.0 * settings.outlierWeight;
      reasons.add('Invoice amount is zero or negative.');
    } else if (invoice.amount > 5e6) {
      dScore += 15.0 * settings.outlierWeight;
      reasons.add('Invoice amount unusually large.');
    }

    // History-based checks
    if (history != null && history.isNotEmpty) {
      final matches = history.where((r) {
        final pn = (r['payeeName'] ?? '').toString().toLowerCase();
        final vd = (r['vendorDomain'] ?? '').toString().toLowerCase();
        return pn == invoice.payeeName.toLowerCase() || vd == invoice.vendorDomain.toLowerCase();
      }).toList();

      final previousAccounts = <String>{};
      final previousAmounts = <double>[];
      for (final m in matches) {
        final accPrev = (m['accountNumber'] ?? '').toString().trim();
        if (accPrev.isNotEmpty) previousAccounts.add(accPrev);
        final a = double.tryParse((m['amount'] ?? '').toString());
        if (a != null) previousAmounts.add(a);
      }

      if (previousAccounts.isNotEmpty && !previousAccounts.contains(acc)) {
        dScore += 20.0 * settings.accountNewWeight;
        reasons.add('Account number is new for this vendor (previous accounts seen).');
      } else if (previousAccounts.isNotEmpty && previousAccounts.contains(acc)) {
        // Known account for this vendor — reduce risk slightly
        dScore = max(0.0, dScore - (10.0 * settings.accountNewWeight));
        reasons.add('Account matches previous record for this vendor.');
      }

      if (previousAmounts.length >= 5 && _isOutlier(invoice.amount, previousAmounts)) {
        dScore += 15.0 * settings.outlierWeight;
        reasons.add('Amount is an outlier compared to vendor history.');
      }
    }

    var finalScore = min(100, dScore.round());
    // If email domain matches vendor domain, reduce score a bit
    if (emailDomain.isNotEmpty && invoice.vendorDomain.isNotEmpty && emailDomain == invoice.vendorDomain) {
      finalScore = max(0, finalScore - settings.emailVendorReduction.round());
      reasons.add('Email domain matches vendor domain — lower risk.');
    }

    if (finalScore == 0) {
      reasons.insert(0, 'Low risk — proceed with caution.');
    } else if (finalScore < 35) {
      reasons.insert(0, 'Low-medium risk — verify as needed.');
    } else if (finalScore < 70) {
      reasons.insert(0, 'Medium risk — verify by phone.');
    } else {
      reasons.insert(0, 'High risk — hold payment and perform manual checks.');
    }

    final details = {
      'ibanOk': ibanOk,
      'emailDomain': emailDomain,
      'vendorDomain': invoice.vendorDomain,
      'payeeName': invoice.payeeName,
      'accountNumber': invoice.accountNumber,
      'amount': invoice.amount,
      'invoiceDate': invoice.invoiceDate?.toIso8601String(),
    };

    return ScanResult(score: finalScore, reasons: reasons, details: details);
  }

  static bool _validateIban(String iban) {
    final s = iban.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (s.length < 5) {
      return false;
    }
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(s)) {
      return false;
    }
    // If starts with two letters, try IBAN mod97 check
    if (RegExp(r'^[A-Z]{2}').hasMatch(s)) {
      try {
        final rearr = s.substring(4) + s.substring(0, 4);
        final buffer = StringBuffer();
        for (final ch in rearr.split('')) {
          if (RegExp(r'[A-Z]').hasMatch(ch)) {
            buffer.write((ch.codeUnitAt(0) - 55).toString());
          } else {
            buffer.write(ch);
          }
        }
        final numeric = buffer.toString();
        // Compute mod-97 by processing digits incrementally to avoid huge integers.
        int remainder = 0;
        for (var i = 0; i < numeric.length; i++) {
          final ch = numeric.codeUnitAt(i);
          if (ch < 48 || ch > 57) continue;
          final digit = ch - 48;
          remainder = (remainder * 10 + digit) % 97;
        }
        // Temporary debug output for failing IBAN cases
        // ignore: avoid_print
        print('IBAN debug: $s remainder=$remainder');
        return remainder == 1;
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  static String _extractDomain(String email) {
    final parts = email.split('@');
    return parts.length == 2 ? parts[1].toLowerCase() : '';
  }

  static double _simpleSimilarity(String a, String b) {
    // Use Jaro-Winkler similarity for better fuzzy matching of short names.
    return _jaroWinkler(a, b);
  }

  static double _jaroWinkler(String s1, String s2) {
    s1 = s1.toLowerCase();
    s2 = s2.toLowerCase();
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    final jaro = _jaro(s1, s2);
    // Prefix scale
    int prefix = 0;
    for (var i = 0; i < min(4, min(s1.length, s2.length)); i++) {
      if (s1[i] == s2[i]) prefix++; else break;
    }
    const p = 0.1;
    return jaro + prefix * p * (1 - jaro);
  }

  // Public accessor for similarity (used by tests and other modules).
  static double jaroWinkler(String a, String b) => _jaroWinkler(a, b);

  static double _jaro(String s1, String s2) {
    final m = _matchingWindow(s1, s2);
    if (m == 0) return 0.0;
    final t = _transpositions(s1, s2, m);
    final double mD = m.toDouble();
    return (mD / s1.length + mD / s2.length + (mD - t) / mD) / 3.0;
  }

  static int _matchingWindow(String s1, String s2) {
    final matchDistance = (max(s1.length, s2.length) / 2 - 1).floor();
    var matches = 0;
    final s2Matched = List.filled(s2.length, false);
    for (var i = 0; i < s1.length; i++) {
      final start = max(0, i - matchDistance);
      final end = min(s2.length - 1, i + matchDistance);
      for (var j = start; j <= end; j++) {
        if (!s2Matched[j] && s1[i] == s2[j]) {
          s2Matched[j] = true;
          matches++;
          break;
        }
      }
    }
    return matches;
  }

  static int _transpositions(String s1, String s2, int m) {
    final matchDistance = (max(s1.length, s2.length) / 2 - 1).floor();
    final s1Matches = <String>[];
    final s2Matches = <String>[];
    final s2Matched = List.filled(s2.length, false);
    for (var i = 0; i < s1.length; i++) {
      final start = max(0, i - matchDistance);
      final end = min(s2.length - 1, i + matchDistance);
      for (var j = start; j <= end; j++) {
        if (!s2Matched[j] && s1[i] == s2[j]) {
          s1Matches.add(s1[i]);
          s2Matches.add(s2[j]);
          s2Matched[j] = true;
          break;
        }
      }
    }
    var transpositions = 0;
    for (var i = 0; i < min(s1Matches.length, s2Matches.length); i++) {
      if (s1Matches[i] != s2Matches[i]) transpositions++;
    }
    return transpositions ~/ 2;
  }

  static int _lcsLength(String s1, String s2) {
    final m = s1.length;
    final n = s2.length;
    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        if (s1[i - 1] == s2[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = max(dp[i - 1][j], dp[i][j - 1]);
        }
      }
    }
    return dp[m][n];
  }


  static bool _isOutlier(double value, List<double> history) {
    if (history.isEmpty) return false;
    final sorted = List.of(history)..sort();
    final q1 = sorted[(sorted.length * 0.25).floor()];
    final q3 = sorted[(sorted.length * 0.75).floor()];
    final iqr = q3 - q1;
    final lower = q1 - 1.5 * iqr;
    final upper = q3 + 1.5 * iqr;
    return value < lower || value > upper;
  }
}
