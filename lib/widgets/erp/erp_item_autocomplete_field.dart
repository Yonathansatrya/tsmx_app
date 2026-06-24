import 'package:flutter/material.dart';

class ErpItemOption {
  final String id;
  final String label;

  const ErpItemOption({required this.id, required this.label});
}

class ErpItemAutocompleteField extends StatelessWidget {
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

  String _displayValue(String? id) {
    if (id == null || id.isEmpty) return '';
    for (final option in options) {
      if (option.id == id) return option.label;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<ErpItemOption>(
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return options.take(20);
        return options.where((option) {
          return option.id.toLowerCase().contains(query) ||
              option.label.toLowerCase().contains(query);
        });
      },
      displayStringForOption: (option) => option.label,
      onSelected: (option) => onSelected(option.id),
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        final display = _displayValue(selectedId);
        if (controller.text.isEmpty && display.isNotEmpty) {
          controller.text = display;
        }
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: decoration.copyWith(
            labelText: label,
            suffixIcon: const Icon(Icons.search_rounded),
          ),
          onChanged: (value) {
            if (selectedId != null && value != _displayValue(selectedId)) {
              onSelected(null);
            }
          },
          validator: (_) => validator?.call(selectedId),
        );
      },
    );
  }
}
