import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../models/sales_workspace.dart';
import '../../../state/app_state.dart';
import '../../../widgets/erp/erp_empty_state.dart';
import '../../../widgets/erp/erp_error_box.dart';

class SalesVisitScreen extends StatefulWidget {
  const SalesVisitScreen({super.key});
  @override
  State<SalesVisitScreen> createState() => _SalesVisitScreenState();
}

class _SalesVisitScreenState extends State<SalesVisitScreen> {
  final picker = ImagePicker();
  final notes = TextEditingController();
  final competitor = TextEditingController();
  final competitorProduct = TextEditingController();
  final competitorPrice = TextEditingController();
  final potentialProduct = TextEditingController();
  final potentialQty = TextEditingController();
  List<SalesCustomerOption> customers = const [];
  List<SalesVisit> visits = const [];
  SalesCustomerOption? customer;
  XFile? photo;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final state = context.read<AppState>();
      final result = await Future.wait([
        state.fetchSalesCustomers(),
        state.fetchSalesVisits(),
      ]);
      customers = result[0] as List<SalesCustomerOption>;
      visits = result[1] as List<SalesVisit>;
    } catch (e) {
      error = 'Pastikan Custom DocType TMSX Sales Visit tersedia. $e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    if (customer == null || photo == null) return;
    setState(() => loading = true);
    try {
      await context.read<AppState>().createSalesVisit(
        customer: customer!.id,
        notes: notes.text,
        photoPath: photo!.path,
        competitors: competitor.text.trim().isEmpty
            ? const []
            : [
                {
                  'competitor': competitor.text.trim(),
                  'product': competitorProduct.text.trim(),
                  'price': double.tryParse(competitorPrice.text) ?? 0,
                },
              ],
        potentialOrders: potentialProduct.text.trim().isEmpty
            ? const []
            : [
                {
                  'product': potentialProduct.text.trim(),
                  'qty': double.tryParse(potentialQty.text) ?? 0,
                },
              ],
      );
      notes.clear();
      competitor.clear();
      competitorProduct.clear();
      competitorPrice.clear();
      potentialProduct.clear();
      potentialQty.clear();
      customer = null;
      photo = null;
      await _load();
    } catch (e) {
      error = e.toString();
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: const TabBar(
        tabs: [
          Tab(text: 'Input Kunjungan'),
          Tab(text: 'Timeline Aktivitas'),
        ],
      ),
      body: TabBarView(children: [_form(), _timeline()]),
    ),
  );

  Widget _form() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
    children: [
      const Card(
        color: Color(0xFFEFF6FF),
        child: ListTile(
          leading: Icon(Icons.map_outlined),
          title: Text('GPS, geofencing, maps, dan tracking realtime'),
          subtitle: Text(
            'Coming next. Alamat customer sudah ditarik dari API.',
          ),
        ),
      ),
      DropdownButtonFormField<SalesCustomerOption>(
        key: ValueKey(customer?.id),
        initialValue: customer,
        items: customers
            .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
            .toList(),
        onChanged: (value) => setState(() => customer = value),
        decoration: const InputDecoration(labelText: 'Customer'),
      ),
      if (customer?.address.isNotEmpty == true) Text(customer!.address),
      TextField(
        controller: notes,
        decoration: const InputDecoration(labelText: 'Catatan kunjungan'),
      ),
      const SizedBox(height: 12),
      const Text(
        'Monitoring Kompetitor',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      TextField(
        controller: competitor,
        decoration: const InputDecoration(labelText: 'Nama kompetitor'),
      ),
      TextField(
        controller: competitorProduct,
        decoration: const InputDecoration(labelText: 'Produk kompetitor'),
      ),
      TextField(
        controller: competitorPrice,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Harga kompetitor'),
      ),
      const SizedBox(height: 12),
      const Text(
        'Order Potensial',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      TextField(
        controller: potentialProduct,
        decoration: const InputDecoration(labelText: 'Produk potensial'),
      ),
      TextField(
        controller: potentialQty,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Qty potensial'),
      ),
      OutlinedButton.icon(
        onPressed: () async {
          final image = await picker.pickImage(source: ImageSource.camera);
          if (image != null) setState(() => photo = image);
        },
        icon: const Icon(Icons.camera_alt),
        label: Text(photo == null ? 'Ambil Foto Toko' : 'Foto siap diunggah'),
      ),
      FilledButton.icon(
        onPressed: loading ? null : _save,
        icon: const Icon(Icons.cloud_upload),
        label: const Text('Simpan Kunjungan'),
      ),
      if (loading) const LinearProgressIndicator(),
      if (error != null) ErpErrorBox(message: error!),
    ],
  );

  Widget _timeline() => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: visits.isEmpty
          ? [const ErpEmptyState(title: 'Belum ada aktivitas kunjungan')]
          : visits.map((visit) {
              final canCheckOut =
                  visit.status.toLowerCase() != 'checked out' &&
                  visit.checkOutTime.isEmpty;
              return Card(
                child: ListTile(
                  title: Text(visit.customer),
                  subtitle: Text('${visit.checkInTime}\n${visit.notes}'),
                  trailing: canCheckOut
                      ? TextButton(
                          onPressed: () async {
                            try {
                              await context.read<AppState>().checkOutSalesVisit(
                                visit.id,
                              );
                              await _load();
                            } catch (e) {
                              if (mounted) setState(() => error = e.toString());
                            }
                          },
                          child: const Text('Check-out'),
                        )
                      : Text(visit.status),
                ),
              );
            }).toList(),
    ),
  );
}
