import 'package:flutter/material.dart';
import 'package:control_produccion_flutter/core/localization/app_translations.dart';
import 'package:control_produccion_flutter/core/theme/app_colors.dart';
import 'package:control_produccion_flutter/core/services/excel_export_service.dart';
import 'scrap_grid_panel.dart';

class ScrapSearchBarPanel extends StatefulWidget {
  final LanguageProvider languageProvider;
  final void Function(DateTime?, DateTime?, String?) onSearch;
  final GlobalKey<ScrapGridPanelState> gridKey;

  const ScrapSearchBarPanel({
    super.key,
    required this.languageProvider,
    required this.onSearch,
    required this.gridKey,
  });

  @override
  State<ScrapSearchBarPanel> createState() => _ScrapSearchBarPanelState();
}

class _ScrapSearchBarPanelState extends State<ScrapSearchBarPanel> {
  final TextEditingController _startDateCtrl = TextEditingController();
  final TextEditingController _endDateCtrl = TextEditingController();
  bool _useDateFilter = false;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedArea;

  static const List<String> _areas = ['M1', 'M2', 'M3', 'M4', 'D1', 'D2', 'D3', 'CALIDAD', 'MANTENIMIENTO', 'SMD', 'IMD', 'IPM', 'COATING', 'PROVEEDOR', 'COMPONENTE'];

  String tr(String key) => widget.languageProvider.tr(key);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = now;
    _endDate = now;
    _startDateCtrl.text = _fmt(now);
    _endDateCtrl.text = _fmt(now);
  }

  @override
  void dispose() {
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          _startDateCtrl.text = _fmt(picked);
        } else {
          _endDate = picked;
          _endDateCtrl.text = _fmt(picked);
        }
      });
    }
  }

  void _doSearch() {
    widget.onSearch(
      _useDateFilter ? _startDate : null,
      _useDateFilter ? _endDate : null,
      _selectedArea,
    );
  }

  Future<void> _exportExcel() async {
    final data = widget.gridKey.currentState?.getDataForExport() ?? [];
    if (data.isEmpty) return;

    final headers = [
      tr('scrap_scanned_code'),
      tr('scrap_part_no'),
      tr('scrap_modelo'),
      tr('scrap_area'),
      tr('scrap_motivo'),
      tr('scrap_comentarios'),
      'Cantidad',
      tr('scrap_registered_by'),
      tr('scrap_date'),
      tr('scrap_time'),
    ];
    final fields = [
      'scanned_original',
      'part_no',
      'modelo',
      'area',
      'motivo_scrap_texto',
      'comentarios',
      'cantidad',
      'usuario_registro',
      'fecha',
      'hora',
    ];

    await ExcelExportService.exportToExcel(
      data: data,
      headers: headers,
      fieldMapping: fields,
      fileName: 'Scrap_Records',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.panelBackground,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // Checkbox rango fecha
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: _useDateFilter,
              onChanged: (v) => setState(() => _useDateFilter = v ?? false),
              side: const BorderSide(color: AppColors.border),
              activeColor: Colors.blue,
            ),
          ),
          const SizedBox(width: 6),
          Text(tr('scrap_date_range'), style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(width: 6),
          // Fecha inicio
          SizedBox(
            width: 110,
            height: 32,
            child: TextField(
              controller: _startDateCtrl,
              readOnly: true,
              enabled: _useDateFilter,
              onTap: () => _pickDate(true),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.border)),
                disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.border.withOpacity(0.3))),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('-', style: TextStyle(color: Colors.white54)),
          ),
          // Fecha fin
          SizedBox(
            width: 110,
            height: 32,
            child: TextField(
              controller: _endDateCtrl,
              readOnly: true,
              enabled: _useDateFilter,
              onTap: () => _pickDate(false),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.border)),
                disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.border.withOpacity(0.3))),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Area filter
          SizedBox(
            width: 150,
            height: 32,
            child: DropdownButtonFormField<String>(
              value: _selectedArea,
              isDense: true,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: tr('scrap_area'),
                labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.border)),
              ),
              dropdownColor: AppColors.panelBackground,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(tr('scrap_all'), style: const TextStyle(fontSize: 12)),
                ),
                ..._areas.map((a) => DropdownMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 12)))),
              ],
              onChanged: (val) => setState(() => _selectedArea = val),
            ),
          ),
          const SizedBox(width: 8),
          // Buscar
          SizedBox(
            height: 32,
            child: ElevatedButton.icon(
              onPressed: _doSearch,
              icon: const Icon(Icons.search, size: 14),
              label: Text(tr('scrap_search'), style: const TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Excel export
          SizedBox(
            height: 32,
            child: OutlinedButton.icon(
              onPressed: _exportExcel,
              icon: const Icon(Icons.download, size: 14, color: Colors.green),
              label: Text('Excel', style: const TextStyle(fontSize: 12, color: Colors.green)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.green),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
