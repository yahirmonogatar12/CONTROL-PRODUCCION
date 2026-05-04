import 'package:flutter/material.dart';
import 'dart:async';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:control_produccion_flutter/core/localization/app_translations.dart';
import 'package:control_produccion_flutter/core/theme/app_colors.dart';
import 'package:control_produccion_flutter/core/widgets/field_decoration.dart';
import 'package:control_produccion_flutter/core/widgets/table_dropdown_field.dart';
import 'package:control_produccion_flutter/core/services/api_service.dart';
import 'package:control_produccion_flutter/core/services/auth_service.dart';

class ScrapFormPanel extends StatefulWidget {
  final LanguageProvider languageProvider;
  final VoidCallback onDataSaved;

  const ScrapFormPanel({
    super.key,
    required this.languageProvider,
    required this.onDataSaved,
  });

  @override
  State<ScrapFormPanel> createState() => ScrapFormPanelState();
}

class ScrapFormPanelState extends State<ScrapFormPanel> {
  final TextEditingController _scanController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _scanFocusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  String _selectedArea = 'SMD';
  int? _selectedMotivoId;
  String? _selectedMotivoText;
  bool _isLoading = false;
  String? _statusMessage;
  bool _statusIsError = false;
  int _lastInsertedId = 0;

  List<Map<String, dynamic>> _motivos = [];

  // Autocomplete
  List<Map<String, dynamic>> _suggestions = [];
  OverlayEntry? _overlayEntry;
  Timer? _debounceTimer;
  bool _isAutocompletePick = false;

  static const List<String> _areas = [
    'SMD',
    'IMD',
    'Assy',
    'Componente',
    'Mantenimiento'
  ];

  String tr(String key) => widget.languageProvider.tr(key);

  @override
  void initState() {
    super.initState();
    _loadLocalPrefs();
    _loadMotivos();
    _scanController.addListener(_onScanTextChanged);
  }

  @override
  void dispose() {
    _scanController.removeListener(_onScanTextChanged);
    _debounceTimer?.cancel();
    _hideOverlay();
    _scanController.dispose();
    _commentController.dispose();
    _scanFocusNode.dispose();
    super.dispose();
  }

  void requestScanFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scanFocusNode.requestFocus();
    });
  }

  Future<void> reloadMotivos() => _loadMotivos();

  // ---- Autocomplete del scan ----
  void _onScanTextChanged() {
    final text = _scanController.text.trim().toUpperCase();

    if (_isAutocompletePick) {
      _isAutocompletePick = false;
      return;
    }

    if (text.contains(';')) {
      _hideOverlay();
      return;
    }

    _debounceTimer?.cancel();
    if (text.length < 3) {
      _hideOverlay();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _fetchSuggestions(text);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    final results = await ApiService.autocompleteScrap(query);
    if (!mounted) return;
    setState(() => _suggestions = results);
    if (_suggestions.isNotEmpty) {
      _showOverlay();
    } else {
      _hideOverlay();
    }
  }

  void _showOverlay() {
    _hideOverlay();
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        width: 420,
        child: CompositedTransformFollower(
          link: _layerLink,
          offset: const Offset(0, 40),
          showWhenUnlinked: false,
          child: Material(
            elevation: 8,
            color: AppColors.panelBackground,
            borderRadius: BorderRadius.circular(4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (_, i) {
                  final s = _suggestions[i];
                  final partNo = s['part_no'] ?? '';
                  final model = s['model'] ?? '';
                  final project = s['project'] ?? '';
                  return InkWell(
                    onTap: () => _onSuggestionSelected(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: const BoxDecoration(
                        border:
                            Border(bottom: BorderSide(color: Colors.white12)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(partNo,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(model,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(project,
                                style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onSuggestionSelected(Map<String, dynamic> suggestion) {
    _hideOverlay();
    final partNo = suggestion['part_no'] ?? '';
    _isAutocompletePick = true;
    _scanController.text = partNo;
    _scanController.selection = TextSelection.fromPosition(
      TextPosition(offset: partNo.length),
    );
    _onScan();
  }

  Future<void> _loadMotivos() async {
    final result = await ApiService.getScrapMotivos();
    if (mounted) {
      setState(() {
        _motivos =
            (result['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        if (_selectedMotivoId != null) {
          final exists = _motivos.any((m) => m['id'] == _selectedMotivoId);
          if (!exists) {
            _selectedMotivoId = null;
            _selectedMotivoText = null;
          }
        }
        if (_selectedMotivoId == null && _motivos.isNotEmpty) {
          _selectedMotivoId = _motivos[0]['id'];
          _selectedMotivoText = _motivos[0]['motivo'];
        }
      });
    }
  }

  Future<void> _loadLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedArea = prefs.getString('scrap_last_area');
      final savedMotivoId = prefs.getInt('scrap_last_motivo_id');
      final savedComment = prefs.getString('scrap_last_comment');
      if (mounted) {
        setState(() {
          if (savedArea != null && _areas.contains(savedArea)) {
            _selectedArea = savedArea;
          }
          if (savedMotivoId != null) _selectedMotivoId = savedMotivoId;
          if (savedComment != null) _commentController.text = savedComment;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('scrap_last_area', _selectedArea);
      if (_selectedMotivoId != null) {
        await prefs.setInt('scrap_last_motivo_id', _selectedMotivoId!);
      }
      await prefs.setString('scrap_last_comment', _commentController.text);
    } catch (_) {}
  }

  Future<void> _onScan() async {
    final code = _scanController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    if (!AuthService.canWriteScrap) {
      setState(() {
        _statusMessage = tr('scrap_no_write_permission');
        _statusIsError = true;
      });
      _scanController.clear();
      requestScanFocus();
      return;
    }

    if (_selectedMotivoId == null) {
      setState(() {
        _statusMessage = tr('scrap_select_motivo');
        _statusIsError = true;
      });
      _scanController.clear();
      requestScanFocus();
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    final result = await ApiService.scanScrap(
      scannedCode: code,
      area: _selectedArea,
      motivoScrapId: _selectedMotivoId!,
      comentarios:
          _commentController.text.isNotEmpty ? _commentController.text : null,
      usuario: AuthService.currentUser?.nombreCompleto,
    );

    if (mounted) {
      if (result['success'] == true) {
        final data = result['data'];
        _lastInsertedId = data?['id'] ?? 0;
        setState(() {
          _statusMessage =
              '${tr('scrap_scan_saved')}: ${data?['part_no'] ?? ''} - ${data?['modelo'] ?? 'N/A'} [${data?['area'] ?? ''}]';
          _statusIsError = false;
        });
        _scanController.clear();
        _saveLocalPrefs();
        widget.onDataSaved();
      } else {
        final errorCode = result['code'] ?? '';
        String msg = result['message'] ?? tr('scrap_scan_error');
        if (errorCode == 'DUPLICATE_SCAN') {
          msg = tr('scrap_duplicate_scan');
        } else if (errorCode == 'INVALID_AREA') {
          msg = tr('scrap_invalid_area');
        } else if (errorCode == 'INVALID_MOTIVO') {
          msg = tr('scrap_invalid_motivo');
        }
        setState(() {
          _statusMessage = msg;
          _statusIsError = true;
        });
        _scanController.clear();
      }
      setState(() => _isLoading = false);
      requestScanFocus();
    }
  }

  Future<void> _undoLastScan() async {
    if (_lastInsertedId <= 0) return;
    final result = await ApiService.deleteScrapRecord(_lastInsertedId);
    if (result['success'] == true) {
      setState(() {
        _statusMessage = tr('scrap_scan_deleted');
        _statusIsError = false;
        _lastInsertedId = 0;
      });
      widget.onDataSaved();
    }
  }

  List<List<String>> get _motivoRows {
    return _motivos.map((m) {
      return [
        m['motivo']?.toString() ?? '',
        '',
      ];
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final motivoRows = _motivoRows;
    final selectedMotivoValue = motivoRows.any(
            (row) => row.isNotEmpty && row.first == _selectedMotivoText)
        ? _selectedMotivoText
        : null;

    return Container(
      color: AppColors.subPanelBackground,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila 1: Area + Motivo (TableDropdownField)
          Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(tr('scrap_area'),
                    style: const TextStyle(fontSize: 14, color: Colors.white)),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField2<String>(
                  decoration: fieldDecoration(),
                  value: _selectedArea,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  items: _areas
                      .map((a) => DropdownMenuItem(
                            value: a,
                            child:
                                Text(a, style: const TextStyle(fontSize: 14)),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedArea = val);
                      _saveLocalPrefs();
                    }
                  },
                  iconStyleData: const IconStyleData(
                    icon: Icon(Icons.arrow_drop_down,
                        color: Colors.white70, size: 20),
                  ),
                  dropdownStyleData: DropdownStyleData(
                    maxHeight: 200,
                    decoration: BoxDecoration(
                      color: AppColors.fieldBackground,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  menuItemStyleData: const MenuItemStyleData(
                    height: 32,
                    padding: EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 80,
                child: Text(tr('scrap_motivo'),
                    style: const TextStyle(fontSize: 14, color: Colors.white)),
              ),
              SizedBox(
                width: 260,
                child: TableDropdownField(
                  value: selectedMotivoValue ?? '',
                  headers: [tr('scrap_motivo'), tr('description')],
                  rows: motivoRows,
                  tableWidth: 520,
                  tableHeight: 300,
                  onRowSelected: (index) {
                    if (index < 0 || index >= _motivos.length) return;
                    final motivo = _motivos[index];
                    final id = motivo['id'];
                    if (id is! int) return;
                    setState(() {
                      _selectedMotivoId = id;
                      _selectedMotivoText = motivo['motivo']?.toString();
                    });
                    _saveLocalPrefs();
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                width: 36,
                child: IconButton(
                  onPressed: _loadMotivos,
                  icon: const Icon(Icons.refresh,
                      color: Colors.white70, size: 18),
                  tooltip: tr('scrap_refresh'),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Fila 2: Comentarios
          Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(tr('scrap_comentarios'),
                    style: const TextStyle(fontSize: 14, color: Colors.white)),
              ),
              Expanded(
                child: TextFormField(
                  controller: _commentController,
                  decoration: fieldDecoration(),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (_) => _saveLocalPrefs(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Fila 3: Scan field principal (con autocomplete) + Undo + Status
          Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(tr('scrap_scan_field'),
                    style: const TextStyle(fontSize: 14, color: Colors.white)),
              ),
              Expanded(
                flex: 3,
                child: CompositedTransformTarget(
                  link: _layerLink,
                  child: TextField(
                    controller: _scanController,
                    focusNode: _scanFocusNode,
                    style: const TextStyle(
                        fontSize: 14,
                        color: Colors.cyan,
                        fontWeight: FontWeight.w600),
                    decoration: fieldDecoration().copyWith(
                      hintText:
                          '${tr('scrap_scan_field')} / ${tr('scrap_autocomplete_hint')}',
                      hintStyle: const TextStyle(
                          fontSize: 12, color: Colors.white38),
                      prefixIcon: const Icon(Icons.qr_code_scanner,
                          color: Colors.cyan, size: 18),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 32, minHeight: 20),
                      suffixIcon: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            )
                          : null,
                    ),
                    onSubmitted: (_) {
                      _hideOverlay();
                      _onScan();
                    },
                  ),
                ),
              ),
              if (_lastInsertedId > 0) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 36,
                  width: 36,
                  child: IconButton(
                    onPressed: _undoLastScan,
                    icon:
                        const Icon(Icons.undo, color: Colors.orange, size: 20),
                    tooltip: tr('scrap_undo_last'),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _statusMessage != null
                    ? Container(
                        height: 36,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: _statusIsError
                              ? Colors.red.withValues(alpha: 0.15)
                              : Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: _statusIsError
                                  ? Colors.red.withValues(alpha: 0.3)
                                  : Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                              color: _statusIsError
                                  ? Colors.redAccent
                                  : Colors.green,
                              fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : const SizedBox(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
