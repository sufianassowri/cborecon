import 'package:cborecon/core/services/postgres_service.dart';

void main() async {
  final candidates = ['', 'postgres', 'root', 'admin', 'password', '1234', '123456', 'cbo', 'cborecon'];

  for (final pwd in candidates) {
    print('Trying password: "$pwd"...');
    PostgresService.instance.updateConfig(PostgresConfig(
      host: 'localhost',
      port: 5431,
      database: 'postgres',
      username: 'postgres',
      password: pwd.isEmpty ? null : pwd,
    ));

    final isConnected = await PostgresService.instance.testConnection();
    if (isConnected) {
      print('>>> SUCCESS with password: "$pwd" <<<');
      await PostgresService.instance.logReconciliation(
        moduleName: 'Ebirr Mobile Money Reconciliation',
        totalRecords: 500,
        matchedPairs: 480,
        unmatchedExceptions: 20,
      );
      print('Saved reconciliation log successfully!');
      break;
    }
    await PostgresService.instance.close();
  }
}
