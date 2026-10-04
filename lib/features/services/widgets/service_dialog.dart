import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/service_model.dart';
import '../../../data/services/admin_data_repository.dart';
import '../../../data/services/category_repository.dart';

class ServiceDialog extends StatefulWidget {
  const ServiceDialog({super.key, this.existing, required this.onSaved});
  final ServiceModel? existing;
  final ValueChanged<ServiceModel> onSaved;

  @override
  State<ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends State<ServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _descCtrl;

  // ── Legacy category (fallback if no primary categories in DB yet) ──────────
  late ServiceCategory _legacyCategory;

  // ── Dynamic categories loaded from DB ────────────────────────────────────
  List<PrimaryCategory> _primaryCategories = [];
  List<PromoCategory> _promoCategories = [];
  bool _categoriesLoading = true;

  String? _selectedPrimaryId;
  String? _selectedPromoId;

  late ServiceStatus _status;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  /// True once categories are loaded and there is at least one primary category.
  bool get _hasDynamicCategories =>
      !_categoriesLoading && _primaryCategories.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _priceCtrl =
        TextEditingController(text: e != null ? e.price.toStringAsFixed(2) : '');
    _durationCtrl =
        TextEditingController(text: e?.durationMinutes.toString() ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _legacyCategory = e?.category ?? ServiceCategory.nails;
    _status = e?.status ?? ServiceStatus.active;
    _selectedPrimaryId = e?.primaryCategoryId;
    _selectedPromoId = e?.promoCategoryId;

    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final results = await Future.wait([
      CategoryRepository.instance.listPrimaryCategories(activeOnly: true),
      CategoryRepository.instance.listPromoCategories(activeOnly: true),
    ]);
    if (!mounted) return;
    setState(() {
      _primaryCategories = results[0] as List<PrimaryCategory>;
      _promoCategories = results[1] as List<PromoCategory>;
      _categoriesLoading = false;

      // If the saved primary category ID is no longer in the active list,
      // keep it visible but it will be shown as "(inactive)" via fallback.
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────────────
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: AdminColors.cream,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.content_cut_rounded,
                          color: AdminColors.gold, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isEditing ? 'Edit Service' : 'Add Service',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // ── Service Name ─────────────────────────────────────────
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Service Name',
                      prefixIcon: Icon(Icons.label_outline_rounded),
                    ),
                    style: const TextStyle(fontSize: 13),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),

                  // ── Primary Category ─────────────────────────────────────
                  if (_categoriesLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AdminColors.gold),
                        ),
                        SizedBox(width: 10),
                        Text('Loading categories…',
                            style: TextStyle(
                                fontSize: 12,
                                color: AdminColors.brownMedium)),
                      ]),
                    )
                  else if (_hasDynamicCategories)
                    DropdownButtonFormField<String?>(
                      value: _primaryCategories
                              .any((c) => c.id == _selectedPrimaryId)
                          ? _selectedPrimaryId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Primary Category',
                        prefixIcon: Icon(Icons.content_cut_rounded),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('— None —',
                              style: TextStyle(
                                  color: AdminColors.brownMedium,
                                  fontSize: 13)),
                        ),
                        ..._primaryCategories.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(c.name,
                                style: const TextStyle(fontSize: 13)),
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedPrimaryId = v),
                    )
                  else
                    // Fallback: no dynamic categories yet, show legacy enum
                    DropdownButtonFormField<ServiceCategory>(
                      value: _legacyCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category_outlined),
                        helperText:
                            'Add primary categories in Categories → Super Admin.',
                      ),
                      items: ServiceCategory.values
                          .map((c) => DropdownMenuItem(
                              value: c, child: Text(c.label)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _legacyCategory = v);
                        }
                      },
                    ),
                  const SizedBox(height: 12),

                  // ── Promo / Secondary Category (optional) ────────────────
                  if (!_categoriesLoading && _promoCategories.isNotEmpty)
                    Column(
                      children: [
                        DropdownButtonFormField<String?>(
                          value: _promoCategories
                                  .any((c) => c.id == _selectedPromoId)
                              ? _selectedPromoId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Promo Category (optional)',
                            prefixIcon: Icon(Icons.local_offer_rounded),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('— None —',
                                  style: TextStyle(
                                      color: AdminColors.brownMedium,
                                      fontSize: 13)),
                            ),
                            ..._promoCategories.map(
                              (c) => DropdownMenuItem<String?>(
                                value: c.id,
                                child: Text(c.name,
                                    style: const TextStyle(fontSize: 13)),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedPromoId = v),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),

                  // ── Price + Duration ─────────────────────────────────────
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Price (₱)',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                        style: const TextStyle(fontSize: 13),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (double.tryParse(v) == null) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _durationCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration (min)',
                          prefixIcon: Icon(Icons.timer_outlined),
                        ),
                        style: const TextStyle(fontSize: 13),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (int.tryParse(v) == null) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  // ── Description ──────────────────────────────────────────
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),

                  // ── Status ───────────────────────────────────────────────
                  DropdownButtonFormField<ServiceStatus>(
                    value: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      prefixIcon: Icon(Icons.toggle_on_outlined),
                    ),
                    items: ServiceStatus.values
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.name[0].toUpperCase() +
                                  s.name.substring(1)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _status = v);
                    },
                  ),

                  const SizedBox(height: 24),

                  // ── Actions ──────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel')),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(_isEditing
                                ? 'Save Changes'
                                : 'Add Service'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a temporary service code shown right after saving, before the next
  /// full list reload re-sequences all codes properly.
  /// Format: <prefix>NEW  e.g. "NNEW", "HNEW"
  String _buildTempCode() {
    if (_selectedPrimaryId != null) {
      final name = _primaryCategories
          .where((c) => c.id == _selectedPrimaryId)
          .map((c) => c.name)
          .firstOrNull;
      if (name != null && name.isNotEmpty) {
        return '${name.trim()[0].toUpperCase()}NEW';
      }
    }
    return '${_legacyCategory.codePrefix}NEW';
  }

  Future<void> _submit() async {    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final e = widget.existing;

    // Resolve the effective primary category name for the saved model.
    final primaryName = _primaryCategories
        .where((c) => c.id == _selectedPrimaryId)
        .map((c) => c.name)
        .firstOrNull;
    final promoName = _promoCategories
        .where((c) => c.id == _selectedPromoId)
        .map((c) => c.name)
        .firstOrNull;

    try {
      final savedId = await AdminDataRepository.instance.saveService(
        id: e?.id,
        name: _nameCtrl.text.trim(),
        category: _hasDynamicCategories ? _legacyCategory : _legacyCategory,
        price: double.parse(_priceCtrl.text.trim()),
        durationMinutes: int.parse(_durationCtrl.text.trim()),
        status: _status,
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        primaryCategoryId: _selectedPrimaryId,
        promoCategoryId: _selectedPromoId,
      );

      final saved = ServiceModel(
        id: savedId,
        // Temporary placeholder code — will be properly sequenced on next
        // full load via ServiceCodeGenerator.assign(). Shows category prefix
        // so it's readable immediately after saving.
        serviceId: _buildTempCode(),
        name: _nameCtrl.text.trim(),
        category: _legacyCategory,
        price: double.parse(_priceCtrl.text.trim()),
        durationMinutes: int.parse(_durationCtrl.text.trim()),
        status: _status,
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        primaryCategoryId: _selectedPrimaryId,
        primaryCategoryName: primaryName,
        promoCategoryId: _selectedPromoId,
        promoCategoryName: promoName,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved(saved);
    } catch (err) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AdminColors.error,
      ));
    }
  }
}
