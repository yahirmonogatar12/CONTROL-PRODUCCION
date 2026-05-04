import 'package:flutter/material.dart';
import 'package:control_produccion_flutter/core/localization/app_translations.dart';
import 'package:control_produccion_flutter/core/theme/app_colors.dart';
import 'scrap_form_panel.dart';
import 'scrap_search_bar_panel.dart';
import 'scrap_grid_panel.dart';

class ScrapScreen extends StatefulWidget {
  final LanguageProvider languageProvider;

  const ScrapScreen({super.key, required this.languageProvider});

  @override
  State<ScrapScreen> createState() => ScrapScreenState();
}

class ScrapScreenState extends State<ScrapScreen> {
  final GlobalKey<ScrapGridPanelState> _gridKey = GlobalKey();
  final GlobalKey<ScrapFormPanelState> _formKey = GlobalKey();

  String tr(String key) => widget.languageProvider.tr(key);

  void requestScanFocus() {
    _formKey.currentState?.reloadMotivos();
    _formKey.currentState?.requestScanFocus();
  }

  void _onDataSaved() {
    _gridKey.currentState?.reloadData();
  }

  void _onSearch(DateTime? fechaInicio, DateTime? fechaFin, String? area) {
    _gridKey.currentState?.searchByDate(fechaInicio, fechaFin, area: area);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Panel de escaneo
        ScrapFormPanel(
          key: _formKey,
          languageProvider: widget.languageProvider,
          onDataSaved: _onDataSaved,
        ),
        // Barra de busqueda
        ScrapSearchBarPanel(
          languageProvider: widget.languageProvider,
          onSearch: _onSearch,
          gridKey: _gridKey,
        ),
        // Grid de registros
        Expanded(
          child: ScrapGridPanel(
            key: _gridKey,
            languageProvider: widget.languageProvider,
          ),
        ),
      ],
    );
  }
}
