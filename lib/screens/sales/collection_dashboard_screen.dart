import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/erp_format.dart';

class CollectionDashboardScreen extends StatefulWidget {
  const CollectionDashboardScreen({super.key});

  @override
  State<CollectionDashboardScreen> createState() =>
      _CollectionDashboardScreenState();
}

class _CollectionDashboardScreenState extends State<CollectionDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _promiseToPayLogs = [];

  String? _selectedCustomer;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _promiseDate;

  String _invoiceSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submitPromise() {
    if (_selectedCustomer == null ||
        _amountController.text.isEmpty ||
        _promiseDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap lengkapi semua field Janji Bayar!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final amt =
        double.tryParse(
          _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0.0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jumlah pembayaran tidak valid!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _promiseToPayLogs.insert(0, {
        'customer': _selectedCustomer,
        'amount': amt,
        'date': _promiseDate!.toIso8601String().split('T').first,
        'notes': _notesController.text,
        'status': 'Pending',
      });
      // Reset form
      _selectedCustomer = null;
      _amountController.clear();
      _notesController.clear();
      _promiseDate = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Janji Bayar disimpan sementara pada sesi ini.'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.slate,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'AR Aging & Rank'),
            Tab(text: 'Overdue & Invoices'),
            Tab(text: 'Janji Bayar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAgingAndRankTab(appState),
          _buildOverdueAndInvoicesTab(appState),
          _buildPromiseToPayTab(appState),
        ],
      ),
    );
  }

  // --- Aging & Leaderboard Tab ---
  Widget _buildAgingAndRankTab(AppState appState) {
    final today = DateTime.now();
    var aging0to30 = 0.0;
    var aging31to60 = 0.0;
    var aging61to90 = 0.0;
    var aging90plus = 0.0;
    for (final invoice in appState.salesInvoices) {
      if (invoice.outstandingAmount <= 0) continue;
      final dueDate = DateTime.tryParse(invoice.dueDate);
      final age = dueDate == null ? 0 : today.difference(dueDate).inDays;
      if (age <= 30) {
        aging0to30 += invoice.outstandingAmount;
      } else if (age <= 60) {
        aging31to60 += invoice.outstandingAmount;
      } else if (age <= 90) {
        aging61to90 += invoice.outstandingAmount;
      } else {
        aging90plus += invoice.outstandingAmount;
      }
    }
    final totalAR = aging0to30 + aging31to60 + aging61to90 + aging90plus;
    final collected = appState.salesInvoices.fold<double>(
      0,
      (total, invoice) =>
          total +
          (invoice.value - invoice.outstandingAmount).clamp(0, double.infinity),
    );
    final List<Map<String, dynamic>> leaderboard = [
      {
        'rank': 1,
        'name': appState.currentUser?.split('@').first ?? 'Anda',
        'amount': collected,
        'avatar': 'ME',
      },
    ];

    final payHistory = appState.salesInvoices
        .where((invoice) => invoice.value > 0 && invoice.outstandingAmount <= 0)
        .map(
          (invoice) => <String, dynamic>{
            'date': invoice.date,
            'customer': invoice.customer,
            'amount': invoice.value,
            'type': 'Sales Invoice Lunas',
          },
        )
        .take(10)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        // AR Aging Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'AR Aging Monitoring',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.navy,
                    ),
                  ),
                  Text(
                    'Total AR: Rp ${formatErpCurrency(totalAR)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Chart layout
              _buildAgingBar(
                '0-30 Hari',
                aging0to30,
                totalAR,
                const Color(0xFF10B981),
              ),
              _buildAgingBar(
                '31-60 Hari',
                aging31to60,
                totalAR,
                const Color(0xFFF59E0B),
              ),
              _buildAgingBar(
                '61-90 Hari',
                aging61to90,
                totalAR,
                const Color(0xFFEF4444),
              ),
              _buildAgingBar(
                '> 90 Hari',
                aging90plus,
                totalAR,
                const Color(0xFF991B1B),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Leaderboard Ranking
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Salesman Collection Ranking',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Peringkat pencapaian koleksi piutang salesman bulan ini.',
                style: TextStyle(fontSize: 10, color: AppColors.slate),
              ),
              const SizedBox(height: 14),

              ...leaderboard.map((item) {
                final isMe = item['avatar'] == 'ME';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? AppColors.softGreen.withValues(alpha: 0.4)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: isMe
                        ? Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        alignment: Alignment.center,
                        child: Text(
                          '#${item['rank']}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: item['rank'] == 1
                                ? const Color(0xFFD97706)
                                : AppColors.navy,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: isMe
                            ? AppColors.primary
                            : Colors.grey[200],
                        child: Text(
                          item['avatar'],
                          style: TextStyle(
                            color: isMe ? Colors.white : AppColors.navy,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item['name'],
                          style: TextStyle(
                            fontWeight: isMe
                                ? FontWeight.w900
                                : FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      Text(
                        'Rp ${formatErpCurrency(item['amount'])}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Payment History
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Histori Pembayaran Masuk',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 12),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: payHistory.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final pay = payHistory[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pay['customer'],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text(
                                  pay['date'],
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.slate,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    pay['type'],
                                    style: const TextStyle(
                                      fontSize: 8,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          '+Rp ${formatErpCurrency(pay['amount'])}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAgingBar(
    String title,
    double val,
    double total,
    Color barColor,
  ) {
    final pct = total > 0 ? val / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              Text(
                'Rp ${formatErpCurrency(val)} (${(pct * 100).toStringAsFixed(1)}%)',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: pct,
              color: barColor,
              backgroundColor: AppColors.border,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // --- Overdue & Invoices Tab ---
  Widget _buildOverdueAndInvoicesTab(AppState appState) {
    final today = DateTime.now();
    final overdueCustomers = appState.salesInvoices
        .where((invoice) {
          final dueDate = DateTime.tryParse(invoice.dueDate);
          return invoice.outstandingAmount > 0 &&
              dueDate != null &&
              dueDate.isBefore(DateTime(today.year, today.month, today.day));
        })
        .map((invoice) {
          final dueDate = DateTime.parse(invoice.dueDate);
          return <String, dynamic>{
            'customer': invoice.customer,
            'overdueAmount': invoice.outstandingAmount,
            'days': today.difference(dueDate).inDays,
          };
        })
        .toList();

    // Filtered Invoices
    final query = _invoiceSearchQuery.toLowerCase().trim();
    final outstandingInvoices = appState.salesInvoices.where((inv) {
      return inv.outstandingAmount > 0 &&
          (query.isEmpty ||
              inv.customer.toLowerCase().contains(query) ||
              inv.id.toLowerCase().contains(query));
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Overdue Monitor Card list
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Overdue Customer Monitoring',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.navy,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${overdueCustomers.length} Customer Overdue',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        ...overdueCustomers.map((cust) {
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cust['customer'],
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              'Overdue ${cust['days']} Hari',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.red,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: AppColors.slate,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Outstanding: Rp ${formatErpCurrency(cust['overdueAmount'])}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.slate,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Quick Contact Buttons
                  IconButton(
                    icon: const Icon(Icons.chat_rounded, color: Colors.green),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Menghubungi ${cust['customer']} via WhatsApp...',
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.phone_in_talk_rounded,
                      color: Colors.blue,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Menelpon nomor ${cust['customer']}...',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 20),

        // Outstanding per Customer List
        const Text(
          'Outstanding Piutang per Customer',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          onChanged: (val) => setState(() => _invoiceSearchQuery = val),
          decoration: InputDecoration(
            hintText: 'Cari invoice atau nama customer...',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        const SizedBox(height: 10),

        if (outstandingInvoices.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Tidak ada outstanding invoice ditemui.',
                  style: TextStyle(fontSize: 12, color: AppColors.slate),
                ),
              ),
            ),
          )
        else
          ...outstandingInvoices.map((inv) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  inv.id,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      inv.customer,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Jatuh Tempo: ${inv.dueDate}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.slate,
                      ),
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rp ${formatErpCurrency(inv.outstandingAmount)}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Outstanding',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // --- Janji Bayar Tab ---
  Widget _buildPromiseToPayTab(AppState appState) {
    final customers =
        appState.salesOrders
            .map((so) => so.customer)
            .where((customer) => customer.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final selectedCustomer = customers.contains(_selectedCustomer)
        ? _selectedCustomer
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        // Form Log Promise To Pay
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Input Janji Bayar Customer',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                key: ValueKey(selectedCustomer),
                initialValue: selectedCustomer,
                decoration: const InputDecoration(
                  labelText: 'Pilih Customer',
                  border: OutlineInputBorder(),
                ),
                items: customers
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedCustomer = val),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Pembayaran (Rp)',
                  hintText: 'Masukkan nominal rupiah',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              // Date Picker
              InkWell(
                onTap: () async {
                  final dt = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 180)),
                  );
                  if (dt != null) {
                    setState(() {
                      _promiseDate = dt;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _promiseDate == null
                            ? 'Pilih Tanggal Janji Bayar'
                            : 'Tanggal: ${_promiseDate!.toIso8601String().split('T').first}',
                        style: TextStyle(
                          fontSize: 13,
                          color: _promiseDate == null
                              ? AppColors.slate
                              : AppColors.navy,
                          fontWeight: _promiseDate == null
                              ? FontWeight.w500
                              : FontWeight.w700,
                        ),
                      ),
                      const Icon(
                        Icons.calendar_month_rounded,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Catatan / Alasan / Cara Pembayaran',
                  hintText: 'Contoh: Transfer Bank, Titip Cash, dll',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitPromise,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Simpan Janji Bayar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        const Text(
          'Daftar Janji Bayar Customer',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 10),

        if (_promiseToPayLogs.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Tidak ada janji bayar terdaftar.',
                  style: TextStyle(fontSize: 12, color: AppColors.slate),
                ),
              ),
            ),
          )
        else
          ..._promiseToPayLogs.map((log) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          log['customer'],
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppColors.navy,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentYellow.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            log['status'].toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFFCA8A04),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Target Tanggal:',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.slate,
                          ),
                        ),
                        Text(
                          log['date'],
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Nominal Janji:',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.slate,
                          ),
                        ),
                        Text(
                          'Rp ${formatErpCurrency(log['amount'])}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    if (log['notes'] != null && log['notes'].isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Text(
                        'Catatan: ${log['notes']}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.slate,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
