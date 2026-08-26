class RemoteDisputePayableTables {
  // Case-sensitive class table name matching your Back4App schema
  static const String remoteDisputePayableClass = 'RemoteDisputePayable';
  static const String telebirrLogsClass = 'TelebirrReconciliation';
  static const String ebirrLogsClass = 'EbirrReconciliation';

  // Cloud function names
  static const String importCsvFunction = 'importCsvData';
}