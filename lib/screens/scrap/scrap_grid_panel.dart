import 'package:flutter/material.dart';
import 'package:control_produccion_flutter/core/localization/app_translations.dart';
import 'package:control_produccion_flutter/core/theme/app_colors.dart';
import 'package:control_produccion_flutter/core/services/api_service.dart';
import 'package:control_produccion_flutter/core/widgets/resizable_grid_header.dart';

class ScrapGridPanel extends StatefulWidget {
  final LanguageProvider languageProvider;

  const ScrapGridPanel({super.key, required this.languageProvider});

  @override
  State<ScrapGridPanel> createState() => ScrapGridPanelState();
}

class ScrapGridPanelState extends State<ScrapGridPanel>
    with AutomaticKeepAliveClientMixin, ResizableColumnsMixin {
  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _filteredData = [];

  // Sorting
  String? _sortColumn;
  bool _sortAscending = true;

  // Column filters
  Map<String, String?> _columnFilters = {};

  // Selection
  int _selectedIndex = -1;

  bool _isLoading = false;

  // Search state
  DateTime? _searchStart;
  DateTime? _searchEnd;
  String? _searchArea;

  static const _fields = [
    'scanned_original',
    'assy_type',
    'part_no',
    'modelo',
    'area',
    'motivo_scrap_texto',
    'comentarios',
    'usuario_registro',
    'fecha',
    'hora',
  ];

  String tr(String key) => widget.languageProvider.tr(key);

  List<String> get _headers => [
        tr('scrap_scanned_code'),
        tr('scrap_assy_type'),
        tr('scrap_part_no'),
        tr('scrap_modelo'),
        tr('scrap_area'),
        tr('scrap_motivo'),
        tr('scrap_comentarios'),
        tr('scrap_registered_by'),
        tr('scrap_date'),
        tr('scrap_time'),
      ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    initColumnFlex(10, 'scrap_grid',
        defaultFlexValues: [2.5, 1.0, 1.5, 1.5, 1.2, 2.0, 1.5, 1.2, 1.2, 1.0]);
    _loadTodayData();
  }

  void _loadTodayData() {
    final now = DateTime.now();
    searchByDate(now, now);
  }

  Future<void> searchByDate(DateTime? start, DateTime? end, {String? area}) async {
    final s = start ?? DateTime.now();
    final e = end ?? DateTime.now();
    _searchStart = s;
    _searchEnd = e;
    _searchArea = area;

    setState(() => _isLoading = true);

    try {
      final fechaInicio = '${s.year}-${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')}';
      final fechaFin = '${e.year}-${e.month.toString().padLeft(2, '0')}-${e.day.toString().padLeft(2, '0')}';

      final result = await ApiService.getScrapRecords(
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
        area: area,
        limit: 5000,
      );

      if (mounted) {
        setState(() {
          _allData = (result['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _applyFiltersAndSort();
          _selectedIndex = -1;
        });
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  void reloadData() {
    searchByDate(_searchStart, _searchEnd, area: _searchArea);
  }

  List<Map<String, dynamic>> getDataForExport() => _filteredData;

  void _applyFiltersAndSort() {
    var data = List<Map<String, dynamic>>.from(_allData);

    for (final entry in _columnFilters.entries) {
      if (entry.value != null && entry.value!.isNotEmpty) {
        data = data.where((r) {
          final val = (r[entry.key] ?? '').toString();
          return val == entry.value;
        }).toList();
      }
    }

    if (_sortColumn != null) {
      data.sort((a, b) {
        final va = (a[_sortColumn] ?? '').toString();
        final vb = (b[_sortColumn] ?? '').toString();
        return _sortAscending ? va.compareTo(vb) : vb.compareTo(va);
      });
    }

    _filteredData = data;
  }

  void _onSort(String field, bool ascending) {
    setState(() {
      _sortColumn = field;
      _sortAscending = ascending;
      _applyFiltersAndSort();
    });
  }

  void _onFilter(String field) {
    final values = _allData
        .map((r) => (r[field] ?? '').toString())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final currentFilter = _columnFilters[field];

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.panelBackground,
          title: Text(
            '${tr('scrap_filter')}: $field',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          content: SizedBox(
            width: 250,
            height: 300,
            child: ListView(
              children: [
                ListTile(
                  dense: true,
                  title: Text(
                    tr('scrap_all'),
                    style: TextStyle(
                      color: currentFilter == null ? Colors.blue : Colors.white70,
                      fontSize: 13,
                      fontWeight: currentFilter == null ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _columnFilters.remove(field);
                      _applyFiltersAndSort();
                    });
                    Navigator.pop(ctx);
                  },
                ),
                const Divider(color: AppColors.border),
                ...values.map((v) => ListTile(
                      dense: true,
                      title: Text(
                        v,
                        style: TextStyle(
                          color: currentFilter == v ? Colors.blue : Colors.white70,
                          fontSize: 13,
                          fontWeight: currentFilter == v ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _columnFilters[field] = v;
                          _applyFiltersAndSort();
                        });
                        Navigator.pop(ctx);
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        // Header
        buildResizableHeader(
          headers: _headers,
          fieldMapping: _fields,
          onSort: _onSort,
          onFilter: _onFilter,
          sortColumn: _sortColumn,
          sortAscending: _sortAscending,
          columnFilters: _columnFilters,
          showCheckbox: false,
        ),
        // Rows
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredData.isEmpty
                  ? Center(child: Text(tr('scrap_no_data'), style: const TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      itemCount: _filteredData.length,
                      itemBuilder: (context, index) {
                        final row = _filteredData[index];
                        final isSelected = index == _selectedIndex;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedIndex = index),
                          child: Container(
                            height: 30,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.red.withOpacity(0.20)
                                  : (index.isEven ? AppColors.gridRowEven : AppColors.gridRowOdd),
                              border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.3))),
                            ),
                            child: Row(
                              children: List.generate(_fields.length, (ci) {
                                return Expanded(
                                  flex: getColumnFlex(ci),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Text(
                                      '${row[_fields[ci]] ?? ''}',
                                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        );
                      },
                    ),
        ),
        // Footer
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.panelBackground,
            border: Border(top: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'SCRAP',
                  style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${tr('scrap_total_records')}: ${_filteredData.length}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              if (_columnFilters.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  '(${_allData.length} ${tr('scrap_all')})',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ],
    );
  }
}
