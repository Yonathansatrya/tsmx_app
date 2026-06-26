import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class ErpItemOption {
  final String id;
  final String label;

  const ErpItemOption({required this.id, required this.label});
}

class ErpItemAutocompleteField extends StatefulWidget {
  final String label;
  final String? selectedId;
  final List<ErpItemOption> options;
  final ValueChanged<String?> onSelected;
  final InputDecoration decoration;
  final String? Function(String?)? validator;

  const ErpItemAutocompleteField({
    super.key,
    required this.label,
    required this.selectedId,
    required this.options,
    required this.onSelected,
    required this.decoration,
    this.validator,
  });

  @override
  State<ErpItemAutocompleteField> createState() =>
      _ErpItemAutocompleteFieldState();
}

class _ErpItemAutocompleteFieldState extends State<ErpItemAutocompleteField> {
  late final TextEditingController _displayController;

  @override
  void initState() {
    super.initState();
    _displayController = TextEditingController(text: _selectedDisplayValue());
  }

  @override
  void didUpdateWidget(covariant ErpItemAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _selectedDisplayValue();
    if (_displayController.text != next) {
      _displayController.text = next;
    }
  }

  @override
  void dispose() {
    _displayController.dispose();
    super.dispose();
  }

  String _displayValueFor(String? id) {
    if (id == null || id.isEmpty) return '';
    for (final option in widget.options) {
      if (option.id == id) return option.label;
    }
    return id;
  }

  String _selectedDisplayValue() => _displayValueFor(widget.selectedId);

  Future<void> _openPicker() async {
    FocusScope.of(context).unfocus();
    final selected = await showModalBottomSheet<ErpItemOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ErpItemSearchSheet(
        title: widget.label,
        options: widget.options,
        selectedId: widget.selectedId,
      ),
    );
    if (selected == null || !mounted) return;
    widget.onSelected(selected.id);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _displayController,
      readOnly: true,
      onTap: widget.options.isEmpty ? null : _openPicker,
      decoration: widget.decoration.copyWith(
        labelText: widget.label,
        suffixIcon: widget.selectedId == null || widget.selectedId!.isEmpty
            ? const Icon(Icons.search_rounded)
            : IconButton(
                tooltip: 'Bersihkan pilihan',
                onPressed: () => widget.onSelected(null),
                icon: const Icon(Icons.close_rounded),
              ),
      ),
      validator: (_) => widget.validator?.call(widget.selectedId),
    );
  }
}

class _ErpItemSearchSheet extends StatefulWidget {
  final String title;
  final List<ErpItemOption> options;
  final String? selectedId;

  const _ErpItemSearchSheet({
    required this.title,
    required this.options,
    required this.selectedId,
  });

  @override
  State<_ErpItemSearchSheet> createState() => _ErpItemSearchSheetState();
}

class _ErpItemSearchSheetState extends State<_ErpItemSearchSheet> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ErpItemOption> _filteredOptions() {
    final query = _searchController.text.trim().toLowerCase();
    final source = query.isEmpty
        ? widget.options
        : widget.options.where((option) {
            return option.id.toLowerCase().contains(query) ||
                option.label.toLowerCase().contains(query);
          });
    return source.take(80).toList();
  }

  @override
  Widget build(BuildContext context) {
    final options = _filteredOptions();
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pilih ${widget.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Cari ${widget.title.toLowerCase()}',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Bersihkan pencarian',
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: options.isEmpty
                    ? const _EmptySearchResult()
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                        itemCount: options.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (context, index) {
                          final option = options[index];
                          final selected = option.id == widget.selectedId;
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: selected
                                  ? AppColors.primary
                                  : AppColors.softGreen,
                              foregroundColor: selected
                                  ? AppColors.white
                                  : AppColors.primary,
                              child: Icon(
                                selected
                                    ? Icons.check_rounded
                                    : Icons.search_rounded,
                              ),
                            ),
                            title: Text(
                              option.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: option.id == option.label
                                ? null
                                : Text(
                                    option.id,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            onTap: () => Navigator.pop(context, option),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySearchResult extends StatelessWidget {
  const _EmptySearchResult();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, color: AppColors.slate, size: 42),
            SizedBox(height: 8),
            Text(
              'Data tidak ditemukan',
              style: TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Coba kata kunci lain atau refresh data master.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.slate, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
