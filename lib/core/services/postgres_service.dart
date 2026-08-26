import 'package:postgres/postgres.dart';

class PostgresConfig {
  final String host;
  final int port;
  final String database;
  final String username;
  final String? password;
  final SslMode sslMode;

  const PostgresConfig({
    this.host = 'localhost',
    this.port = 5431, // Default port for postgres-1 container in Docker
    this.database = 'postgres',
    this.username = 'postgres',
    this.password = 'postgres',
    this.sslMode = SslMode.disable,
  });
}

class PostgresService {
  static PostgresService? _instance;
  static PostgresService get instance => _instance ??= PostgresService._();

  PostgresService._();

  Connection? _connection;
  PostgresConfig _config = const PostgresConfig();

  PostgresConfig get config => _config;

  bool get isConnected => _connection != null && _connection!.isOpen;

  /// Updates database configuration
  void updateConfig(PostgresConfig config) {
    _config = config;
  }

  /// Opens connection to the PostgreSQL container in Docker
  Future<Connection> getConnection() async {
    if (_connection != null && _connection!.isOpen) {
      return _connection!;
    }

    final endpoint = Endpoint(
      host: _config.host,
      port: _config.port,
      database: _config.database,
      username: _config.username,
      password: _config.password,
    );

    _connection = await Connection.open(
      endpoint,
      settings: ConnectionSettings(sslMode: _config.sslMode),
    );

    await _initializeTables();
    return _connection!;
  }

  /// Tests connection to Docker PostgreSQL
  Future<bool> testConnection() async {
    try {
      final conn = await getConnection();
      final result = await conn.execute('SELECT 1 as ping');
      return result.isNotEmpty;
    } catch (e) {
      print('Connection failed with error: $e');
      return false;
    }
  }

  /// Initializes core reconciliation and audit tables
  Future<void> _initializeTables() async {
    if (_connection == null || !_connection!.isOpen) return;

    // Reconciliation history & audit table
    await _connection!.execute('''
      CREATE TABLE IF NOT EXISTS recon_audit_logs (
        id SERIAL PRIMARY KEY,
        module_name VARCHAR(100) NOT NULL,
        total_records INT NOT NULL DEFAULT 0,
        matched_pairs INT NOT NULL DEFAULT 0,
        unmatched_exceptions INT NOT NULL DEFAULT 0,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        metadata JSONB
      );
    ''');

    // Dispute management table
    await _connection!.execute('''
      CREATE TABLE IF NOT EXISTS dispute_records (
        id SERIAL PRIMARY KEY,
        reference_no VARCHAR(100) NOT NULL,
        amount NUMERIC(15, 2),
        customer_account VARCHAR(50),
        status VARCHAR(50) DEFAULT 'PENDING',
        memo_notes TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    ''');
  }

  /// Records a reconciliation execution audit trail. Returns true if saved, false otherwise.
  Future<bool> logReconciliation({
    required String moduleName,
    required int totalRecords,
    required int matchedPairs,
    required int unmatchedExceptions,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final conn = await getConnection();
      final result = await conn.execute(
        Sql.named(
          'INSERT INTO recon_audit_logs (module_name, total_records, matched_pairs, unmatched_exceptions, metadata) '
          'VALUES (@module, @total, @matched, @unmatched, @meta::jsonb) RETURNING id;',
        ),
        parameters: {
          'module': moduleName,
          'total': totalRecords,
          'matched': matchedPairs,
          'unmatched': unmatchedExceptions,
          'meta': metadata != null ? metadata.toString() : null,
        },
      );
      return result.isNotEmpty;
    } catch (e) {
      print('Database insert error: $e');
      return false;
    }
  }

  /// Fetches recent reconciliation audit records from Docker PostgreSQL
  Future<List<Map<String, dynamic>>> getAuditLogs({int limit = 20}) async {
    try {
      final conn = await getConnection();
      final result = await conn.execute(
        Sql.named('SELECT * FROM recon_audit_logs ORDER BY created_at DESC LIMIT @limit;'),
        parameters: {'limit': limit},
      );
      return result.map((row) => row.toColumnMap()).toList();
    } catch (e) {
      print('Database query error: $e');
      return [];
    }
  }

  /// Closes active database connection
  Future<void> close() async {
    if (_connection != null && _connection!.isOpen) {
      await _connection!.close();
      _connection = null;
    }
  }
}
