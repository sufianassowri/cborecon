class AppConstants {
  AppConstants._();

  static const String appName = 'CBO OmniRecon';
  static const String appSubtitle = 'Enterprise Financial Reconciliation & Settlement Hub';
  static const String bankName = 'Cooperative Bank of Oromia';
  static const String version = '2.5.0 Enterprise';

  // Back4App / Parse Configuration
  static const String parseAppId = 'S3jzZ3bn3vs9yMuQLC9rHW1fFh7GGPtBpI79V9pU';
  static const String parseClientKey = 'fr6o5RJFry4CLVgrUFLL5jf6lF1OnG7NkZQhpptx';
  static const String parseServerUrl = 'https://parseapi.back4app.com';

  // Table Names
  static const String tableDisputeTrxn = 'DisputeTrxn';
  static const String tableMasterCardAccount = 'MasterCardAccount';
  static const String tableCardTransaction = 'CardTransaction';
  static const String tableAuditLog = 'AuditLog';

  // Account Generation Prefixes
  static const String ncrAccountPrefix = '10002000';
  static const String crmAccountPrefix = '10005000';

  // Commission Rates for Reversal Matcher
  static const double defaultCommissionLow = 0.0046;
  static const double defaultCommissionHigh = 0.0060;
  static const double amountEpsilon = 0.01;
}

/// Positional column indices mapped directly from raw MasterCard TSV exports
class McTsvIndices {
  McTsvIndices._();

  static const int trxnType = 0; // DtrxnType (FH, TX, MX)
  static const int trxnDate = 7; // traxnDate
  static const int mxClientId = 10; // clientID for Annual Fee (MX)
  static const int mxPan = 11; // PAN for Annual Fee (MX)
  static const int txClientId = 16; // ClientId for TX
  static const int txPan = 17; // PAN for TX
  static const int mxAnnualFeeAmnt = 17; // Annual Fee Amnt for MX
  static const int mxDescription = 18; // Transaction Description for MX
  static const int txMerchantName = 24; // Merchant/Description for TX
  static const int debitOrCreditFlag = 34; // Debit or Credit (D/C)
  static const int baseAmount = 41; // baseAmount
  static const int extraAmount = 44; // extra Amount
}
