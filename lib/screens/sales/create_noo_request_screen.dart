import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/noo_request.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import 'sales_ui.dart';

class CreateNooRequestScreen extends StatefulWidget {
  const CreateNooRequestScreen({super.key});

  @override
  State<CreateNooRequestScreen> createState() => _CreateNooRequestScreenState();
}

class _CreateNooRequestScreenState extends State<CreateNooRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerGroupController = TextEditingController();
  final _territoryController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _mobileNoController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedCompany;
  String? _selectedSalesPerson;
  List<String> _salesPersonOptions = const [];
  bool _salesPersonOptionsRequested = false;
  bool _isLoadingSalesPersons = false;
  String? _salesPersonLoadError;
  List<String> _customerTypeOptions = const [];
  bool _customerTypeOptionsRequested = false;
  bool _isLoadingCustomerTypes = false;
  String? _customerTypeLoadError;
  String? _customerType;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerGroupController.dispose();
    _territoryController.dispose();
    _taxIdController.dispose();
    _contactPersonController.dispose();
    _mobileNoController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _pincodeController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final companies = state.sellingCompanies;
    final preferredCompany = state.preferredCompany(companies);
    if (_selectedCompany == null && preferredCompany != null) {
      _selectedCompany = preferredCompany;
    }
    final currentSalesPerson = state.currentSalesPerson?.trim() ?? '';
    if (state.isSalesUserRole && currentSalesPerson.isNotEmpty) {
      _selectedSalesPerson = currentSalesPerson;
    }
    if (!state.isSalesUserRole && !_salesPersonOptionsRequested) {
      _salesPersonOptionsRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadSalesPersonOptions(context.read<AppState>());
      });
    }
    if (!_customerTypeOptionsRequested) {
      _customerTypeOptionsRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadCustomerTypeOptions(context.read<AppState>());
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
        titleSpacing: 0,
        title: const Text(
          'Buat NOO',
          style: TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: SalesUi.compactScreenPadding,
          children: [
            SalesHeroCard(
              title: 'Pengajuan NOO',
              subtitle: 'Ajukan outlet baru sebelum dibuatkan master Customer.',
              icon: Icons.person_add_alt_1_rounded,
              trailing: _statusChip(),
            ),
            SalesUi.gap(),
            SalesInfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SalesSectionTitle(
                    title: 'Data Pengajuan',
                    subtitle:
                        'Sales user terkunci ke akun login, admin bisa memilih.',
                  ),
                  SalesUi.gap(),
                  _companyField(companies),
                  SalesUi.gap(),
                  state.isSalesUserRole
                      ? _readonlyValue(
                          label: 'Sales Person',
                          value: currentSalesPerson.isNotEmpty
                              ? currentSalesPerson
                              : '-',
                          icon: Icons.person_rounded,
                        )
                      : _salesPersonField(),
                  if (_salesPersonLoadError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _salesPersonLoadError!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SalesUi.gap(),
            SalesInfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SalesSectionTitle(
                    title: 'Data Customer',
                    subtitle: 'Nama outlet, group, territory, dan identitas.',
                  ),
                  SalesUi.gap(),
                  _textField(
                    controller: _customerNameController,
                    label: 'Nama Outlet / Customer',
                    icon: Icons.store_mall_directory_rounded,
                    isRequired: true,
                  ),
                  SalesUi.gap(),
                  DropdownButtonFormField<String>(
                    initialValue: _customerTypeOptions.contains(_customerType)
                        ? _customerType
                        : null,
                    decoration: _decoration(
                      'Customer Type',
                      Icons.badge_rounded,
                    ),
                    isExpanded: true,
                    items: _customerTypeOptions
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(
                              type,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    hint: Text(
                      _isLoadingCustomerTypes
                          ? 'Memuat Customer Type...'
                          : 'Pilih Customer Type',
                    ),
                    onChanged: _isLoadingCustomerTypes
                        ? null
                        : (value) => setState(() => _customerType = value),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Customer Type wajib dipilih'
                        : null,
                  ),
                  if (_customerTypeLoadError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _customerTypeLoadError!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  SalesUi.gap(),
                  _textField(
                    controller: _customerGroupController,
                    label: 'Customer Group',
                    icon: Icons.group_work_rounded,
                  ),
                  SalesUi.gap(),
                  _textField(
                    controller: _territoryController,
                    label: 'Territory / Area',
                    icon: Icons.map_rounded,
                  ),
                  SalesUi.gap(),
                  _textField(
                    controller: _taxIdController,
                    label: 'NPWP / NIK',
                    icon: Icons.credit_card_rounded,
                    keyboardType: TextInputType.text,
                  ),
                ],
              ),
            ),
            SalesUi.gap(),
            SalesInfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SalesSectionTitle(
                    title: 'Kontak & Alamat',
                    subtitle: 'Alamat utama wajib agar bisa dibuat master.',
                  ),
                  SalesUi.gap(),
                  _textField(
                    controller: _contactPersonController,
                    label: 'PIC / Contact Person',
                    icon: Icons.account_circle_rounded,
                  ),
                  SalesUi.gap(),
                  _textField(
                    controller: _mobileNoController,
                    label: 'No. HP',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                  SalesUi.gap(),
                  _textField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SalesUi.gap(),
                  _textField(
                    controller: _addressController,
                    label: 'Alamat Utama',
                    icon: Icons.location_on_rounded,
                    isRequired: true,
                    maxLines: 3,
                  ),
                  SalesUi.gap(),
                  _textField(
                    controller: _cityController,
                    label: 'Kota',
                    icon: Icons.location_city_rounded,
                  ),
                  SalesUi.gap(),
                  _textField(
                    controller: _provinceController,
                    label: 'Provinsi',
                    icon: Icons.public_rounded,
                  ),
                  SalesUi.gap(),
                  _textField(
                    controller: _pincodeController,
                    label: 'Kode Pos',
                    icon: Icons.markunread_mailbox_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            SalesUi.gap(),
            SalesInfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SalesSectionTitle(
                    title: 'Lokasi & Catatan',
                    subtitle:
                        'Koordinat boleh dikosongkan jika belum tersedia.',
                  ),
                  SalesUi.gap(),
                  _textField(
                    controller: _latitudeController,
                    label: 'Latitude',
                    icon: Icons.my_location_rounded,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: _optionalDoubleValidator,
                  ),
                  SalesUi.gap(),
                  _textField(
                    controller: _longitudeController,
                    label: 'Longitude',
                    icon: Icons.explore_rounded,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: _optionalDoubleValidator,
                  ),
                  SalesUi.gap(),
                  _textField(
                    controller: _notesController,
                    label: 'Catatan',
                    icon: Icons.notes_rounded,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            SalesUi.gap(16),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.35,
                ),
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _isSubmitting ? 'Mengirim...' : 'Kirim Pengajuan NOO',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Pending',
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _companyField(List<String> companies) {
    if (companies.isEmpty) {
      return _readonlyValue(
        label: 'Company',
        value: _selectedCompany ?? '-',
        icon: Icons.business_rounded,
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: _selectedCompany,
      decoration: _decoration('Company', Icons.business_rounded),
      isExpanded: true,
      items: companies
          .map(
            (company) => DropdownMenuItem(
              value: company,
              child: Text(
                company,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _selectedCompany = value),
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Company wajib dipilih'
          : null,
    );
  }

  Widget _salesPersonField() {
    final selected = _salesPersonOptions.contains(_selectedSalesPerson)
        ? _selectedSalesPerson
        : null;
    return DropdownButtonFormField<String>(
      initialValue: selected,
      decoration: _decoration('Sales Person', Icons.person_rounded).copyWith(
        suffixIcon: _isLoadingSalesPersons
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
      isExpanded: true,
      items: _salesPersonOptions
          .map(
            (salesPerson) => DropdownMenuItem(
              value: salesPerson,
              child: Text(
                salesPerson,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: _isLoadingSalesPersons
          ? null
          : (value) => setState(() => _selectedSalesPerson = value),
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Sales Person wajib dipilih'
          : null,
    );
  }

  Widget _readonlyValue({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return InputDecorator(
      decoration: _decoration(label, icon),
      child: Text(
        value,
        style: const TextStyle(
          color: AppColors.navy,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: maxLines > 1 ? TextInputAction.newline : null,
      decoration: _decoration(label, icon),
      validator:
          validator ??
          (value) {
            if (!isRequired) return null;
            return value?.trim().isNotEmpty == true
                ? null
                : '$label wajib diisi';
          },
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    );
  }

  String? _optionalDoubleValidator(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;
    return double.tryParse(raw.replaceAll(',', '.')) == null
        ? 'Format angka tidak valid'
        : null;
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final company = _selectedCompany?.trim();
    if (company == null || company.isEmpty) return;
    final state = context.read<AppState>();
    final salesPerson =
        (state.isSalesUserRole
                ? state.currentSalesPerson
                : _selectedSalesPerson)
            ?.trim();
    if (salesPerson == null || salesPerson.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sales Person wajib dipilih.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await state.createNooRequest(
        NooRequestDraft(
          requestDate: DateTime.now(),
          company: company,
          salesPerson: salesPerson,
          customerName: _customerNameController.text,
          customerType: _customerType ?? '',
          customerGroup: _customerGroupController.text,
          territory: _territoryController.text,
          taxId: _taxIdController.text,
          contactPerson: _contactPersonController.text,
          mobileNo: _mobileNoController.text,
          emailId: _emailController.text,
          addressLine1: _addressController.text,
          city: _cityController.text,
          province: _provinceController.text,
          pincode: _pincodeController.text,
          latitude: _parseDouble(_latitudeController.text),
          longitude: _parseDouble(_longitudeController.text),
          notes: _notesController.text,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal kirim NOO: $error')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  double? _parseDouble(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw.replaceAll(',', '.'));
  }

  Future<void> _loadSalesPersonOptions(AppState state) async {
    setState(() {
      _isLoadingSalesPersons = true;
      _salesPersonLoadError = null;
    });
    try {
      Future<List<Map<String, dynamic>>> fetch(List<List<dynamic>> filters) {
        return state.frappeService.fetchResource(
          'Sales Person',
          fields: const ['name'],
          filters: filters,
          orderBy: 'name asc',
        );
      }

      List<Map<String, dynamic>> rows;
      try {
        rows = await fetch(const [
          ['is_group', '=', 0],
          ['enabled', '=', 1],
        ]);
      } catch (_) {
        rows = await fetch(const [
          ['is_group', '=', 0],
        ]);
      }

      final options =
          rows
              .map((row) => row['name']?.toString().trim() ?? '')
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      if (!mounted) return;
      setState(() {
        _salesPersonOptions = options;
        final current = state.currentSalesPerson?.trim();
        _selectedSalesPerson = options.contains(_selectedSalesPerson)
            ? _selectedSalesPerson
            : (current != null && options.contains(current) ? current : null);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _salesPersonLoadError =
            'Sales Person gagal dimuat. Pastikan role punya Read Sales Person.';
      });
    } finally {
      if (mounted) setState(() => _isLoadingSalesPersons = false);
    }
  }

  Future<void> _loadCustomerTypeOptions(AppState state) async {
    setState(() {
      _isLoadingCustomerTypes = true;
      _customerTypeLoadError = null;
    });
    try {
      final rows = await state.frappeService.fetchResource(
        'Customer Type',
        fields: const ['name'],
        orderBy: 'name asc',
        limit: 100,
      );
      final options =
          rows
              .map((row) => row['name']?.toString().trim() ?? '')
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      if (!mounted) return;
      setState(() {
        _customerTypeOptions = options;
        _customerType = options.contains(_customerType)
            ? _customerType
            : (options.isNotEmpty ? options.first : null);
        if (options.isEmpty) {
          _customerTypeLoadError =
              'Customer Type belum tersedia di site aktif.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _customerTypeOptions = const [];
        _customerType = null;
        _customerTypeLoadError =
            'Customer Type gagal dimuat. Pastikan role punya Read Customer Type.';
      });
    } finally {
      if (mounted) setState(() => _isLoadingCustomerTypes = false);
    }
  }
}
