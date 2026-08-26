import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
var debitAccController=TextEditingController();
var creditAccController=TextEditingController();
var amountController=TextEditingController();
var terminalcodeController=TextEditingController();
var traxnDateController=TextEditingController();

class DisputeCheckerView extends ConsumerWidget {
   DisputeCheckerView({super.key}); // Add this line


  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        title: const Text('Checker Panel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(10),
        child: Form(
          child: Column(
            children: [
              TextFormField(
                controller: terminalcodeController,
                decoration: InputDecoration(hintText: "terminal Code"),
              ),
              SizedBox(
                height: 5,
              ),
              TextFormField(controller: debitAccController,
                decoration: InputDecoration(hintText: 'debit Account'),
              ),
              SizedBox(
                height: 5,
              ),
              TextFormField(controller: creditAccController,
                decoration: InputDecoration(hintText: 'crdit account'),
              ),
              SizedBox(
                height: 5,
              ),
              TextFormField(controller: amountController,
                decoration: InputDecoration(hintText: 'amount'),
              ),
              SizedBox(
                height: 5,
              ),
              TextFormField(controller: traxnDateController,
                decoration: InputDecoration(hintText: 'transaction date'),
              ),
              ElevatedButton(
                onPressed: () async {
                  print('saving...');
                  await saveTransaction();
                  print('saving done');
                },
                child: Icon(Icons.save),
              ),
              ElevatedButton(
                onPressed: () {
                  print('clearing...');
                },
                child: Icon(Icons.clear),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> saveTransaction() async {
  var firstObject = ParseObject('DisputeTrxn')
    ..set('debitAcc', debitAccController.text)
    ..set('amount', amountController.text)
    ..set('creditAcc', creditAccController.text)
       ..set('terminalcode', terminalcodeController.text)
    ..set('transactiontime', traxnDateController.text);
  await firstObject.save();

  print('done');
}

