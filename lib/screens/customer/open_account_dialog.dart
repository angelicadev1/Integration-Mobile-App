import 'package:flutter/material.dart';
import '../../core/banking_repository.dart';
import '../../models/account_model.dart';

class OpenAccountDialog extends StatefulWidget {
  const OpenAccountDialog({super.key});

  @override
  State<OpenAccountDialog> createState() => _OpenAccountDialogState();
}

class _OpenAccountDialogState extends State<OpenAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  AccountType _selectedType = AccountType.savings;
  String _selectedCurrency = 'PHP';
  final TextEditingController _depositController = TextEditingController(text: '0.00');
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _depositController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final deposit = double.tryParse(_depositController.text) ?? 0.0;

    try {
      final repo = BankingRepository();
      final acct = await repo.openAccount(
        accountType: _selectedType,
        currencyCode: _selectedCurrency,
        initialDeposit: deposit,
      );

      if (mounted) {
        Navigator.of(context).pop(acct);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.account_balance_outlined, color: Colors.indigo),
          SizedBox(width: 10),
          Text('Open New Account'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Provision a multi-currency retail account with atomic balance ledger support.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              // Account Type Dropdown
              DropdownButtonFormField<AccountType>(
                initialValue: _selectedType,
                decoration: InputDecoration(
                  labelText: 'Account Product Type',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: AccountType.savings,
                    child: Text('Savings Account'),
                  ),
                  DropdownMenuItem(
                    value: AccountType.checking,
                    child: Text('Checking Account'),
                  ),
                  DropdownMenuItem(
                    value: AccountType.digitalWallet,
                    child: Text('Digital Wallet'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
              ),
              const SizedBox(height: 16),

              // Currency Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedCurrency,
                decoration: InputDecoration(
                  labelText: 'Base Currency',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.monetization_on_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'PHP', child: Text('PHP - Philippine Peso (₱)')),
                  DropdownMenuItem(value: 'USD', child: Text('USD - US Dollar (\$)')),
                  DropdownMenuItem(value: 'EUR', child: Text('EUR - Euro (€)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCurrency = val);
                },
              ),
              const SizedBox(height: 16),

              // Initial Deposit
              TextFormField(
                controller: _depositController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Initial Deposit Amount',
                  hintText: '0.00',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.payment_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter amount';
                  final parsed = double.tryParse(val.trim());
                  if (parsed == null || parsed < 0) return 'Enter a valid non-negative number';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Open Account'),
        ),
      ],
    );
  }
}
