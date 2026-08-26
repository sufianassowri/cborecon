import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../../data/model/transaction_model.dart';
import '../controllers/dispute_provider.dart';
class DisputeAuditorView extends ConsumerWidget {
  const DisputeAuditorView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputeAsync = ref.watch(disputeListProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Back to Dashboard',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/');
            }
          },
        ),
        title: const Text("Auditor Portal", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: disputeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (transactions) => PlutoGrid(
          columns: _buildColumns(),
          rows: _buildRows(transactions), // Passing clean models
          onLoaded: (event) => event.stateManager.setShowColumnFilter(true),
        ),
      ),
    );
  }

  List<PlutoColumn> _buildColumns() {
    return [
      PlutoColumn(title: 'ID', field: 'id', type: PlutoColumnType.text()),
      PlutoColumn(title: 'Debit Acc', field: 'debit', type: PlutoColumnType.text()),
      PlutoColumn(title: 'Credit Acc', field: 'credit', type: PlutoColumnType.text()),
      PlutoColumn(title: 'Amount', field: 'amt', type: PlutoColumnType.currency(symbol: 'ETB')),
    ];
  }

  List<PlutoRow> _buildRows(List<DisputeTrxn> transactions) {
    return transactions.map((trx) {
      return PlutoRow(
        cells: {
          'id': PlutoCell(value: trx.objectId),
          'debit': PlutoCell(value: trx.debitAcc),
          'credit': PlutoCell(value: trx.creditAcc),
          'amt': PlutoCell(value: trx.amount),
        },
      );
    }).toList();
  }
}