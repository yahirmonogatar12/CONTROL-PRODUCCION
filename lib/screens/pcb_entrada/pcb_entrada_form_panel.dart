import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:control_produccion_flutter/core/localization/app_translations.dart';
import 'package:control_produccion_flutter/core/theme/app_colors.dart';
import 'package:control_produccion_flutter/core/widgets/field_decoration.dart';
import 'package:control_produccion_flutter/core/widgets/table_dropdown_field.dart';
import 'package:control_produccion_flutter/core/services/api_service.dart';
import 'package:control_produccion_flutter/core/services/auth_service.dart';

class PcbEntradaFormPanel extends StatefulWidget {
  final LanguageProvider languageProvider;
  final VoidCallback onDataSaved;

  const PcbEntradaFormPanel({
    super.key,
    required this.languageProvider,
    required this.onDataSaved,
  });

  @override
  State<PcbEntradaFormPanel> createState() => PcbEntradaFormPanelState();
}

class PcbEntradaFormPanelState extends State<PcbEntradaFormPanel> {
  final TextEditingController _scanController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _arrayCountController =
      TextEditingController(text: '1');
  final TextEditingController _repairCountController =
      TextEditingController(text: '1');
  final TextEditingController _componentLocationController =
      TextEditingController();
  final FocusNode _scanFocusNode = FocusNode();

  String _selectedProceso = 'SMD';
  String _selectedArea = 'INVENTARIO';
  String? _selectedDefectType;
  String? _detectedEtapa; // 'LQC' | 'OQC' | 'AIS' | null
  String? _detectedSourceArea; // 'M1', 'SMD', etc — read-only
  String? _detectedDefectDataId;
  // Linea de salida (M1..M4, DP1..DP3, H1). Si viene de history_vision se
  // muestra como auto-detectada; si no, se pide manualmente al usuario.
  String? _detectedLineaSalida;
  bool _lineaSalidaWasAuto = false;
  List<Map<String, dynamic>> _defects = [];
  List<Map<String, dynamic>> _users = [];
  int? _selectedUserId;
  String? _selectedUserName;
  DateTime _inventoryDate = DateTime.now();
  bool _isLoading = false;
  String? _statusMessage;
  bool _statusIsError = false;
  List<int> _lastInsertedIds = [];
  int _pendingArrayRemaining = 0;
  int _pendingArrayCount = 1;
  int _pendingRepairRemaining = 0;
  int _pendingInventoryRemaining = 0;
  String? _pendingArrayGroupCode;
  String? _pendingArrayParentCode;
  String _pendingArrayTargetArea = 'INVENTARIO';

  static const List<String> _procesos = ['SMD', 'IMD', 'ASSY'];
  static const List<String> _areas = ['INVENTARIO', 'REPARACION'];
  static const List<String> _lineasSalida = [
    'M1', 'M2', 'M3', 'M4', 'DP1', 'DP2', 'DP3', 'H1'
  ];

  String tr(String key) => widget.languageProvider.tr(key);

  String get _formattedDate =>
      '${_inventoryDate.year}-${_inventoryDate.month.toString().padLeft(2, '0')}-${_inventoryDate.day.toString().padLeft(2, '0')}';

  bool get _hasPendingArrayScans => _pendingArrayRemaining > 0;

  @override
  void initState() {
    super.initState();
    _dateController.text = _formattedDate;
    _setDefaultUser();
    _loadLocalPrefs();
    _loadDefects();
    _loadUsers();
  }

  @override
  void dispose() {
    _scanController.dispose();
    _commentController.dispose();
    _dateController.dispose();
    _arrayCountController.dispose();
    _repairCountController.dispose();
    _componentLocationController.dispose();
    _scanFocusNode.dispose();
    super.dispose();
  }

  void requestScanFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scanFocusNode.requestFocus();
    });
  }

  Future<void> _loadLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedProcess = prefs.getString('pcb_entrada_last_process');
      final savedArea = prefs.getString('pcb_entrada_last_area');
      final savedComment = prefs.getString('pcb_entrada_last_comment');
      final savedArrayCount = prefs.getString('pcb_entrada_last_array_count');
      final savedRepairCount = prefs.getString('pcb_entrada_last_repair_count');
      final savedDefectType = prefs.getString('pcb_entrada_last_defect_type');
      final savedComponentLocation =
          prefs.getString('pcb_entrada_last_component_location');
      if (mounted) {
        setState(() {
          if (savedProcess != null && _procesos.contains(savedProcess)) {
            _selectedProceso = savedProcess;
          }
          if (savedArea != null && _areas.contains(savedArea)) {
            _selectedArea = savedArea;
          }
          if (savedComment != null) _commentController.text = savedComment;
          if (savedArrayCount != null &&
              (int.tryParse(savedArrayCount) ?? 0) > 0) {
            _arrayCountController.text = savedArrayCount;
          }
          if (savedRepairCount != null &&
              (int.tryParse(savedRepairCount) ?? 0) > 0) {
            _repairCountController.text = savedRepairCount;
          }
          if (savedDefectType != null && savedDefectType.isNotEmpty) {
            _selectedDefectType = savedDefectType;
          }
          if (savedComponentLocation != null) {
            _componentLocationController.text = savedComponentLocation;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadDefects() async {
    final result = await ApiService.getScrapMotivos();
    final defects = ((result['data'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((motivo) => {
              'defect_name': motivo['motivo']?.toString() ?? '',
              'description': '',
            })
        .where((defect) => defect['defect_name']!.isNotEmpty)
        .toList();
    if (!mounted) return;
    setState(() {
      _defects = defects;
      final names = _defects.map((d) => d['defect_name']?.toString()).toSet();
      if (_selectedDefectType != null && !names.contains(_selectedDefectType)) {
        _selectedDefectType = null;
      }
    });
  }

  void _setDefaultUser() {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;
    _selectedUserId = currentUser.id;
    _selectedUserName = currentUser.nombreCompleto.isNotEmpty
        ? currentUser.nombreCompleto
        : currentUser.username;
  }

  int? _parseUserId(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _userName(Map<String, dynamic> user) {
    final fullName = user['nombre_completo']?.toString().trim() ?? '';
    if (fullName.isNotEmpty) return fullName;
    return user['username']?.toString().trim() ?? '';
  }

  Future<void> _loadUsers() async {
    final result = await ApiService.getUsers();
    final users = result.where((user) {
      final active = user['activo']?.toString().toLowerCase();
      return active != '0' && active != 'false';
    }).toList();
    if (!mounted) return;
    setState(() {
      _users = users;
      if (_selectedUserId != null &&
          !_users.any((user) => _parseUserId(user['id']) == _selectedUserId)) {
        _setDefaultUser();
      }
    });
  }

  List<List<String>> get _userRows {
    return _users.map((user) {
      return [
        user['id']?.toString() ?? '',
        _userName(user),
      ];
    }).toList();
  }

  String get _selectedUserDisplay {
    if (_selectedUserId == null || (_selectedUserName ?? '').isEmpty) {
      return '';
    }
    return '$_selectedUserId - $_selectedUserName';
  }

  String? get _selectedScannedBy {
    final selected = _selectedUserName?.trim() ?? '';
    if (selected.isNotEmpty) return selected;
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return null;
    return currentUser.nombreCompleto.isNotEmpty
        ? currentUser.nombreCompleto
        : currentUser.username;
  }

  Future<void> _saveLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pcb_entrada_last_process', _selectedProceso);
      await prefs.setString('pcb_entrada_last_area', _selectedArea);
      await prefs.setString(
          'pcb_entrada_last_comment', _commentController.text);
      await prefs.setString(
          'pcb_entrada_last_array_count', _arrayCountController.text);
      await prefs.setString(
          'pcb_entrada_last_repair_count', _repairCountController.text);
      if (_selectedDefectType != null) {
        await prefs.setString(
            'pcb_entrada_last_defect_type', _selectedDefectType!);
      }
      await prefs.setString('pcb_entrada_last_component_location',
          _componentLocationController.text);
    } catch (_) {}
  }

  int _getArrayCount() {
    final value = int.tryParse(_arrayCountController.text.trim()) ?? 1;
    return value < 1 ? 1 : value;
  }

  int _getRepairCount() {
    if (_selectedArea != 'REPARACION') return 0;
    final value = int.tryParse(_repairCountController.text.trim()) ?? 1;
    return value < 1 ? 1 : value;
  }

  void _updatePendingArrayTargetArea() {
    _pendingArrayTargetArea =
        _pendingRepairRemaining > 0 ? 'REPARACION' : 'INVENTARIO';
  }

  String _normalizePcbCode(String code) =>
      code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  List<List<String>> get _defectRows {
    return _defects.map((defect) {
      return [
        defect['defect_name']?.toString() ?? '',
        defect['description']?.toString() ?? '',
      ];
    }).toList();
  }

  String? _buildComments({required bool isArrayItem}) {
    final parts = <String>[];
    final comment = _commentController.text.trim();
    if (comment.isNotEmpty) parts.add(comment);
    if (isArrayItem && _pendingArrayParentCode != null) {
      parts.add('${tr('pcb_same_array_as')}: $_pendingArrayParentCode');
    }
    return parts.isEmpty ? null : parts.join(' | ');
  }

  void _clearPendingArray() {
    _pendingArrayRemaining = 0;
    _pendingArrayCount = 1;
    _pendingRepairRemaining = 0;
    _pendingInventoryRemaining = 0;
    _pendingArrayGroupCode = null;
    _pendingArrayParentCode = null;
    _pendingArrayTargetArea = 'INVENTARIO';
  }

  void _cancelPendingArray() {
    setState(() {
      _clearPendingArray();
      _statusMessage = tr('pcb_array_cancelled');
      _statusIsError = false;
    });
    requestScanFocus();
  }

  Future<void> _onScan() async {
    final code = _scanController.text.trim();
    if (code.isEmpty) return;
    final isArrayItem = _hasPendingArrayScans;

    // Lookup en defect_data antes de calcular locals (solo en scan inicial,
    // no en items subsecuentes de un array — el etapa del padre persiste).
    if (!isArrayItem) {
      final matches = await ApiService.lookupDefectData(code);
      if (!mounted) return;

      Map<String, dynamic>? selected;
      if (matches.isEmpty) {
        setState(() {
          _detectedEtapa = 'AIS';
          _detectedSourceArea = null;
          _detectedDefectDataId = null;
        });
      } else if (matches.length == 1) {
        selected = matches.first;
      } else {
        selected = await _showDefectVerificationDialog(matches);
        if (!mounted) return;
        if (selected == null) {
          requestScanFocus();
          return;
        }
      }

      if (selected != null) {
        final etapa = selected['etapa_deteccion']?.toString().toUpperCase();
        setState(() {
          _selectedArea = 'REPARACION';
          _selectedDefectType = selected!['defecto']?.toString();
          _componentLocationController.text =
              selected['ubicacion']?.toString() ?? '';
          _detectedEtapa = (etapa == 'LQC' || etapa == 'OQC') ? etapa : 'AIS';
          _detectedSourceArea = selected['area']?.toString();
          _detectedDefectDataId = selected['id']?.toString();
        });
      }

      // Lookup de linea_salida en history_vision. Si no se encuentra (o la
      // maquina no es una de las lineas validas), pedir al usuario que la
      // seleccione manualmente. Si cancela, abortar el scan.
      final lineaResult = await ApiService.lookupLineaSalidaPcb(code);
      if (!mounted) return;
      String? lineaSalida = lineaResult['linea']?.toString();
      bool wasAuto = lineaResult['found'] == true && lineaSalida != null;
      if (!wasAuto) {
        final rawName = lineaResult['raw_machine_name']?.toString();
        final picked = await _askLineaSalidaManual(rawMachineName: rawName);
        if (!mounted) return;
        if (picked == null) {
          setState(() {
            _statusMessage = tr('pcb_linea_required');
            _statusIsError = true;
          });
          requestScanFocus();
          return;
        }
        lineaSalida = picked;
        wasAuto = false;
      }
      setState(() {
        _detectedLineaSalida = lineaSalida;
        _lineaSalidaWasAuto = wasAuto;
      });
    }

    final arrayCount = isArrayItem ? _pendingArrayCount : _getArrayCount();
    final repairCount = isArrayItem ? 0 : _getRepairCount();
    final effectiveArea = isArrayItem ? _pendingArrayTargetArea : _selectedArea;
    final isRepairEntry = effectiveArea == 'REPARACION';
    final arrayGroupCode =
        isArrayItem ? _pendingArrayGroupCode : _normalizePcbCode(code);
    final arrayRole = arrayCount > 1
        ? (effectiveArea == 'REPARACION' ? 'DEFECT' : 'ARRAY_ITEM')
        : 'SINGLE';

    if (arrayCount > 99) {
      setState(() {
        _statusMessage = tr('pcb_invalid_array_count');
        _statusIsError = true;
      });
      requestScanFocus();
      return;
    }

    if (!isArrayItem &&
        _selectedArea == 'REPARACION' &&
        (repairCount > arrayCount || repairCount < 1)) {
      setState(() {
        _statusMessage = tr('pcb_invalid_repair_count');
        _statusIsError = true;
      });
      requestScanFocus();
      return;
    }

    if (isRepairEntry &&
        (_selectedDefectType == null || _selectedDefectType!.isEmpty)) {
      setState(() {
        _statusMessage = tr('pcb_defect_required');
        _statusIsError = true;
      });
      requestScanFocus();
      return;
    }

    if (!AuthService.canWritePcbInventory) {
      setState(() {
        _statusMessage = tr('pcb_no_write_permission');
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

    final result = await ApiService.scanPcbInventory(
      scannedCode: code,
      inventoryDate: _formattedDate,
      proceso: _selectedProceso,
      area: effectiveArea,
      tipoMovimiento: 'ENTRADA',
      arrayCount: arrayCount,
      qty: 1,
      arrayGroupCode: arrayGroupCode,
      arrayRole: arrayRole,
      defectType: isRepairEntry ? _selectedDefectType : null,
      componentLocation:
          isRepairEntry && _componentLocationController.text.trim().isNotEmpty
              ? _componentLocationController.text.trim()
              : null,
      etapaDeteccion: isRepairEntry ? _detectedEtapa : null,
      defectSourceArea: isRepairEntry ? _detectedSourceArea : null,
      defectDataId: isRepairEntry ? _detectedDefectDataId : null,
      lineaSalidaPcb: _detectedLineaSalida,
      comentarios: _buildComments(isArrayItem: isArrayItem),
      scannedBy: _selectedScannedBy,
    );

    if (mounted) {
      if (result['success'] == true) {
        final data = result['data'];
        final ids = (result['inserted_ids'] as List?)
            ?.map((id) => (id as num).toInt())
            .toList();
        final fallbackId = data?['id'] is num ? (data['id'] as num).toInt() : 0;
        _lastInsertedIds = ids?.isNotEmpty == true
            ? ids!
            : (fallbackId > 0 ? [fallbackId] : []);
        String nextMessage;
        if (isArrayItem) {
          if (effectiveArea == 'REPARACION' && _pendingRepairRemaining > 0) {
            _pendingRepairRemaining -= 1;
          } else if (_pendingInventoryRemaining > 0) {
            _pendingInventoryRemaining -= 1;
          }
          _pendingArrayRemaining =
              _pendingRepairRemaining + _pendingInventoryRemaining;
          if (_pendingArrayRemaining <= 0) {
            _clearPendingArray();
            _clearDetectedDefect();
            nextMessage =
                '${tr('pcb_array_complete')}: ${data?['pcb_part_no'] ?? ''} - ${data?['modelo'] ?? 'N/A'}';
          } else {
            _updatePendingArrayTargetArea();
            nextMessage =
                '${tr('pcb_scan_saved')}: ${data?['pcb_part_no'] ?? ''} | ${tr('pcb_array_remaining')}: $_pendingArrayRemaining ($_pendingArrayTargetArea)';
          }
        } else if (arrayCount > 1) {
          _pendingArrayCount = arrayCount;
          _pendingArrayGroupCode = _normalizePcbCode(code);
          _pendingArrayParentCode = code;
          if (_selectedArea == 'REPARACION') {
            _pendingRepairRemaining = repairCount - 1;
            _pendingInventoryRemaining = arrayCount - repairCount;
          } else {
            _pendingRepairRemaining = 0;
            _pendingInventoryRemaining = arrayCount - 1;
          }
          _pendingArrayRemaining =
              _pendingRepairRemaining + _pendingInventoryRemaining;
          _updatePendingArrayTargetArea();
          nextMessage =
              '${tr('pcb_scan_saved')}: ${data?['pcb_part_no'] ?? ''} | ${tr('pcb_array_remaining')}: $_pendingArrayRemaining ($_pendingArrayTargetArea)';
        } else {
          _clearDetectedDefect();
          nextMessage =
              '${tr('pcb_scan_saved')}: ${data?['pcb_part_no'] ?? ''} - ${data?['modelo'] ?? 'N/A'} (${data?['proceso'] ?? ''})';
        }
        setState(() {
          _statusMessage = nextMessage;
          _statusIsError = false;
        });
        _scanController.clear();
        _saveLocalPrefs();
        widget.onDataSaved();
      } else {
        final errorCode = result['code'] ?? '';
        String msg = result['message'] ?? tr('pcb_scan_error');
        if (errorCode == 'DUPLICATE_SCAN')
          msg = tr('pcb_duplicate_scan');
        else if (errorCode == 'INVALID_PCB_PART_NO')
          msg = tr('pcb_invalid_part_no');
        else if (errorCode == 'INVALID_PROCESO')
          msg = tr('pcb_invalid_proceso');
        else if (errorCode == 'INVALID_ARRAY_COUNT')
          msg = tr('pcb_invalid_array_count');
        else if (errorCode == 'MISSING_DEFECT_TYPE' ||
            errorCode == 'INVALID_DEFECT_TYPE')
          msg = tr('pcb_defect_required');
        else if (errorCode == 'MISSING_LINEA_SALIDA' ||
            errorCode == 'INVALID_LINEA_SALIDA')
          msg = tr('pcb_linea_required');
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _inventoryDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      setState(() {
        _inventoryDate = picked;
        _dateController.text = _formattedDate;
      });
    }
  }

  Future<void> _undoLastScan() async {
    if (_lastInsertedIds.isEmpty) return;
    var ok = true;
    for (final id in _lastInsertedIds.reversed) {
      final result = await ApiService.deletePcbInventoryScan(id);
      ok = ok && result['success'] == true;
    }
    if (ok) {
      setState(() {
        _statusMessage = tr('pcb_scan_deleted');
        _statusIsError = false;
        _lastInsertedIds = [];
        if (_hasPendingArrayScans) _clearPendingArray();
        _clearDetectedDefect();
      });
      widget.onDataSaved();
    }
  }

  void _clearDetectedDefect() {
    _detectedEtapa = null;
    _detectedSourceArea = null;
    _detectedDefectDataId = null;
    _detectedLineaSalida = null;
    _lineaSalidaWasAuto = false;
  }

  Future<String?> _askLineaSalidaManual({String? rawMachineName}) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panelBackground,
        title: Row(
          children: [
            const Icon(Icons.alt_route, color: Colors.cyan, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr('pcb_select_linea_salida'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rawMachineName != null && rawMachineName.isNotEmpty
                    ? '${tr('pcb_linea_not_recognized')}: $rawMachineName'
                    : tr('pcb_linea_not_found_hint'),
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _lineasSalida.map((linea) {
                  return SizedBox(
                    width: 70,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, linea),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.fieldBackground,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        linea,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(tr('cancel'),
                style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Color _etapaColor(String? etapa) {
    switch (etapa) {
      case 'LQC':
        return Colors.orange;
      case 'OQC':
        return Colors.purpleAccent;
      case 'AIS':
        return Colors.cyan;
      default:
        return Colors.white38;
    }
  }

  Future<Map<String, dynamic>?> _showDefectVerificationDialog(
      List<Map<String, dynamic>> matches) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panelBackground,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr('pcb_verify_defect_title'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('pcb_multiple_defects_hint'),
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: matches.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white12, height: 1),
                  itemBuilder: (_, i) {
                    final m = matches[i];
                    final etapa =
                        m['etapa_deteccion']?.toString().toUpperCase() ?? '';
                    final defecto = m['defecto']?.toString() ?? '';
                    final ubicacion = m['ubicacion']?.toString() ?? '';
                    final area = m['area']?.toString() ?? '';
                    final tipo = m['tipo_inspeccion']?.toString() ?? '';
                    final linea = m['linea']?.toString() ?? '';
                    final fecha = m['fecha']?.toString() ?? '';
                    return InkWell(
                      onTap: () => Navigator.pop(ctx, m),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _etapaColor(etapa)
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                        color: _etapaColor(etapa), width: 1),
                                  ),
                                  child: Text(
                                    etapa.isEmpty ? '?' : etapa,
                                    style: TextStyle(
                                      color: _etapaColor(etapa),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    defecto,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  fecha,
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${tr('pcb_component_location')}: $ubicacion  •  ${tr('pcb_source_area')}: $area  •  $tipo  •  $linea',
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(tr('cancel'),
                style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRepairContext = _hasPendingArrayScans
        ? _pendingArrayTargetArea == 'REPARACION'
        : _selectedArea == 'REPARACION';
    final defectRows = _defectRows;
    final userRows = _userRows;
    // Mostrar siempre el defecto seleccionado, aunque no exista en el catalogo
    // local de scrap_motivos (defect_data puede traer defectos personalizados).
    final selectedDefectValue = _selectedDefectType;

    return Container(
      color: AppColors.subPanelBackground,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila 1: Usuario + Area + Proceso + Fecha
          Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(tr('pcb_scanned_by'),
                    style: const TextStyle(fontSize: 14, color: Colors.white)),
              ),
              SizedBox(
                width: 260,
                child: TableDropdownField(
                  value: _selectedUserDisplay,
                  headers: ['ID', tr('full_name')],
                  rows: userRows,
                  tableWidth: 420,
                  tableHeight: 320,
                  onRowSelected: (index) {
                    if (index < 0 || index >= _users.length) return;
                    final user = _users[index];
                    setState(() {
                      _selectedUserId = _parseUserId(user['id']);
                      _selectedUserName = _userName(user);
                    });
                    requestScanFocus();
                  },
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 55,
                child: Text(tr('pcb_area'),
                    style: const TextStyle(fontSize: 14, color: Colors.white)),
              ),
              SizedBox(
                width: 150,
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
                  onChanged: _hasPendingArrayScans
                      ? null
                      : (val) {
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
              const SizedBox(width: 16),
              SizedBox(
                width: 70,
                child: Text(tr('pcb_proceso'),
                    style: const TextStyle(fontSize: 14, color: Colors.white)),
              ),
              SizedBox(
                width: 130,
                child: DropdownButtonFormField2<String>(
                  decoration: fieldDecoration(),
                  value: _selectedProceso,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  items: _procesos
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child:
                                Text(p, style: const TextStyle(fontSize: 14)),
                          ))
                      .toList(),
                  onChanged: _hasPendingArrayScans
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() => _selectedProceso = val);
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
              const SizedBox(width: 16),
              SizedBox(
                width: 50,
                child: Text(tr('pcb_date'),
                    style: const TextStyle(fontSize: 14, color: Colors.white)),
              ),
              Expanded(
                child: TextFormField(
                  controller: _dateController,
                  decoration: fieldDecoration().copyWith(
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today,
                          color: Colors.white70, size: 18),
                      onPressed: _hasPendingArrayScans ? null : _pickDate,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    suffixIconConstraints:
                        const BoxConstraints(minWidth: 30, minHeight: 20),
                  ),
                  style: const TextStyle(fontSize: 14),
                  readOnly: true,
                ),
              ),
            ],
          ),
          if (_hasPendingArrayScans) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.cyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.cyan.withValues(alpha: 0.30)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner,
                      color: Colors.cyan, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${tr('pcb_scan_remaining_array')}: $_pendingArrayRemaining / ${_pendingArrayCount - 1} ($_pendingArrayTargetArea) | ${tr('pcb_area_repair_short')}: $_pendingRepairRemaining, ${tr('pcb_area_inventory_short')}: $_pendingInventoryRemaining',
                      style: const TextStyle(
                          color: Colors.cyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _cancelPendingArray,
                    icon: const Icon(Icons.close, size: 14),
                    label: Text(tr('pcb_cancel_array'),
                        style: const TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      minimumSize: const Size(0, 28),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Fila 2: Defecto + Ubicacion de componente (solo reparacion)
          Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(tr('pcb_defect_type'),
                    style: const TextStyle(fontSize: 14, color: Colors.white)),
              ),
              SizedBox(
                width: 220,
                child: Opacity(
                  opacity: isRepairContext ? 1 : 0.55,
                  child: IgnorePointer(
                    ignoring: !isRepairContext,
                    child: TableDropdownField(
                      value: selectedDefectValue ?? '',
                      headers: [tr('pcb_defect_type'), tr('description')],
                      rows: defectRows,
                      tableWidth: 520,
                      tableHeight: 300,
                      onRowSelected: (index) {
                        if (index < 0 || index >= defectRows.length) return;
                        final defectName = defectRows[index].isNotEmpty
                            ? defectRows[index][0]
                            : '';
                        if (defectName.isEmpty) return;
                        setState(() => _selectedDefectType = defectName);
                        _saveLocalPrefs();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                width: 36,
                child: IconButton(
                  onPressed: _loadDefects,
                  icon: const Icon(Icons.refresh,
                      color: Colors.white70, size: 18),
                  tooltip: tr('pcb_refresh_defects'),
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 12),
              // Etapa chip + Source area (read-only, derivado del lookup)
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _etapaColor(_detectedEtapa).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border:
                      Border.all(color: _etapaColor(_detectedEtapa), width: 1),
                ),
                alignment: Alignment.center,
                child: Text(
                  _detectedEtapa ?? '—',
                  style: TextStyle(
                    color: _etapaColor(_detectedEtapa),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              if (_detectedSourceArea != null &&
                  _detectedSourceArea!.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.gridBackground,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${tr('pcb_source_area')}: ${_detectedSourceArea!}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
              if (_detectedLineaSalida != null) ...[
                const SizedBox(width: 6),
                Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: (_lineaSalidaWasAuto
                            ? Colors.lightGreen
                            : Colors.orangeAccent)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: _lineaSalidaWasAuto
                            ? Colors.lightGreen
                            : Colors.orangeAccent,
                        width: 1),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _lineaSalidaWasAuto
                            ? Icons.auto_awesome
                            : Icons.touch_app,
                        size: 12,
                        color: _lineaSalidaWasAuto
                            ? Colors.lightGreen
                            : Colors.orangeAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${tr('pcb_linea_salida')}: $_detectedLineaSalida',
                        style: TextStyle(
                          color: _lineaSalidaWasAuto
                              ? Colors.lightGreen
                              : Colors.orangeAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 18),
              SizedBox(
                width: 150,
                child: Text(tr('pcb_component_location'),
                    style: const TextStyle(fontSize: 14, color: Colors.white)),
              ),
              Expanded(
                child: TextFormField(
                  controller: _componentLocationController,
                  decoration: fieldDecoration().copyWith(
                    hintText: tr('pcb_component_location_hint'),
                    hintStyle:
                        const TextStyle(fontSize: 12, color: Colors.white38),
                  ),
                  style: const TextStyle(fontSize: 14),
                  enabled: isRepairContext,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => _saveLocalPrefs(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Fila 3: Cantidades + Comentarios
          Row(
            children: [
              SizedBox(
                width: 90,
                child: Text(tr('pcb_array_count'),
                    style: const TextStyle(fontSize: 14, color: Colors.white)),
              ),
              SizedBox(
                width: 80,
                child: TextFormField(
                  controller: _arrayCountController,
                  decoration: fieldDecoration(),
                  style: const TextStyle(fontSize: 14),
                  enabled: !_hasPendingArrayScans,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => _saveLocalPrefs(),
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 90,
                child: Text(tr('pcb_repair_count'),
                    style: const TextStyle(fontSize: 14, color: Colors.white)),
              ),
              SizedBox(
                width: 70,
                child: TextFormField(
                  controller: _repairCountController,
                  decoration: fieldDecoration(),
                  style: const TextStyle(fontSize: 14),
                  enabled:
                      !_hasPendingArrayScans && _selectedArea == 'REPARACION',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => _saveLocalPrefs(),
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 100,
                child: Text(tr('pcb_comentarios'),
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
          // Fila 2: Scan field principal + Undo + Status
          Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(tr('pcb_scan_field'),
                    style: const TextStyle(fontSize: 14, color: Colors.white)),
              ),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _scanController,
                  focusNode: _scanFocusNode,
                  style: const TextStyle(
                      fontSize: 14,
                      color: Colors.cyan,
                      fontWeight: FontWeight.w600),
                  decoration: fieldDecoration().copyWith(
                    hintText: tr('pcb_scan_field'),
                    hintStyle:
                        const TextStyle(fontSize: 12, color: Colors.white38),
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
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _onScan(),
                ),
              ),
              if (_lastInsertedIds.isNotEmpty) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 36,
                  width: 36,
                  child: IconButton(
                    onPressed: _undoLastScan,
                    icon:
                        const Icon(Icons.undo, color: Colors.orange, size: 20),
                    tooltip: tr('pcb_undo_last'),
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
