import 'package:flutter_test/flutter_test.dart';
import 'package:homeconnect/models/kyc_models.dart';
import 'package:homeconnect/models/report_sanction_models.dart';
import 'package:homeconnect/models/commission_models.dart';

void main() {
  group('KYC Models Tests', () {
    test('KYCDocument creation', () {
      final doc = KYCDocument(
        id: 1,
        userId: 1,
        type: DocumentType.passport,
        documentNumber: 'PASS123456',
        frontImageUrl: 'https://example.com/front.jpg',
        backImageUrl: 'https://example.com/back.jpg',
        issueDate: DateTime(2020, 1, 1),
        expiryDate: DateTime(2030, 1, 1),
        issuingCountry: 'BENIN',
        fullName: 'Test User',
        uploadedAt: DateTime.now(),
        isExpired: false,
      );

      expect(doc.type, DocumentType.passport);
      expect(doc.documentNumber, 'PASS123456');
      expect(doc.isValid, isTrue);
    });

    test('KYCDocument serialization', () {
      final doc = KYCDocument(
        id: 1,
        userId: 1,
        type: DocumentType.nationalId,
        documentNumber: 'ID123',
        frontImageUrl: 'front.jpg',
        backImageUrl: 'back.jpg',
        issueDate: DateTime(2020, 1, 1),
        expiryDate: DateTime(2030, 1, 1),
        issuingCountry: 'BENIN',
        fullName: 'User',
        uploadedAt: DateTime.now(),
        isExpired: false,
      );

      final json = doc.toJson();
      expect(json['documentNumber'], 'ID123');
      expect(json['type'], isNotNull);
    });

    test('KYCVerification creation', () {
      final verification = KYCVerification(
        id: 1,
        userId: 1,
        userEmail: 'user@example.com',
        status: KYCStatus.pending,
        documents: [],
        selfies: [],
        createdAt: DateTime.now(),
        attemptCount: 1,
      );

      expect(verification.userId, 1);
      expect(verification.status, KYCStatus.pending);
      expect(verification.isValid, isFalse);
    });
  });

  group('Report & Sanction Models Tests', () {
    test('Report creation', () {
      final report = Report(
        id: 1,
        reporterId: 1,
        targetUserId: 2,
        type: ReportType.fraudulentListing,
        priority: ReportPriority.high,
        status: ReportStatus.open,
        title: 'Test Report',
        description: 'This is a test',
        createdAt: DateTime.now(),
        attachmentUrls: [],
        hasEscalated: false,
      );

      expect(report.type, ReportType.fraudulentListing);
      expect(report.status, ReportStatus.open);
    });

    test('Sanction creation', () {
      final sanction = Sanction(
        id: 1,
        userId: 1,
        type: SanctionType.suspension7Days,
        reason: 'Violation',
        appliedAt: DateTime.now(),
        appliedBy: 10,
        isActive: true,
      );

      expect(sanction.type, SanctionType.suspension7Days);
      expect(sanction.userId, 1);
    });
  });

  group('Commission Models Tests', () {
    test('CommissionConfig creation', () {
      final config = CommissionConfig(
        type: CommissionType.propertyListing,
        rate: 5.0,
        description: 'Listing fee',
        isActive: true,
      );

      expect(config.type, CommissionType.propertyListing);
      expect(config.rate, 5.0);
    });

    test('CommissionTransaction creation', () {
      final transaction = CommissionTransaction(
        id: 1,
        userId: 1,
        type: CommissionType.propertyListing,
        status: CommissionStatus.pending,
        amount: 100.0,
        baseAmount: 2000.0,
        createdAt: DateTime.now(),
      );

      expect(transaction.type, CommissionType.propertyListing);
      expect(transaction.status, CommissionStatus.pending);
    });
  });
}
