import 'dart:io';
import 'package:flutter/material.dart';
import '../config/server_config.dart';
import '../services/server_discovery_service.dart';

/// Widget para mostrar y configurar el servidor activo
/// Se usa en la pantalla de login
class ServerConfigWidget extends StatefulWidget {
  final VoidCallback? onServerChanged;
  
  const ServerConfigWidget({
    super.key,
    this.onServerChanged,
  });

  @override
  State<ServerConfigWidget> createState() => _ServerConfigWidgetState();
}

class _ServerConfigWidgetState extends State<ServerConfigWidget> {
  bool _isExpanded = false;
  bool _isTestingConnection = false;
  bool? _connectionStatus;

  @override
  Widget build(BuildContext context) {
    final activeServer = ServerConfig.activeServer;
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF252A3C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _connectionStatus == true 
              ? Colors.green.withOpacity(0.5)
              : _connectionStatus == false 
                  ? Colors.red.withOpacity(0.5)
                  : Colors.white24,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header - siempre visible
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.dns_outlined,
                    color: _connectionStatus == true
                        ? Colors.green
                        : _connectionStatus == false
                            ? Colors.red
                            : Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Servidor: ${activeServer?.name ?? "No configurado"}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          activeServer != null 
                              ? '${activeServer.ip}:${activeServer.port}'
                              : 'Tap para configurar',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Test connection button
                  if (_isTestingConnection)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                      ),
                    )
                  else
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        color: Colors.white.withOpacity(0.7),
                        size: 20,
                      ),
                      onPressed: _testConnection,
                      tooltip: 'Probar conexión',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded content - server list
          if (_isExpanded) ...[
            const Divider(color: Colors.white24, height: 1),
            _buildServerList(),
            const Divider(color: Colors.white24, height: 1),
            _buildAddServerButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildServerList() {
    final servers = ServerConfig.servers;
    
    if (servers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No hay servidores configurados',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: servers.length,
      itemBuilder: (context, index) {
        final server = servers[index];
        final isActive = server.id == ServerConfig.activeServer?.id;
        
        return ListTile(
          dense: true,
          leading: Icon(
            isActive ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isActive ? Colors.green : Colors.white54,
            size: 20,
          ),
          title: Text(
            server.name,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white70,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            '${server.protocol}://${server.ip}:${server.port}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Edit button
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                color: Colors.white54,
                onPressed: () => _showEditServerDialog(server),
                tooltip: 'Editar',
              ),
              // Delete button (no mostrar para el servidor activo si solo hay uno)
              if (servers.length > 1 || !isActive)
                IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  color: Colors.red.withOpacity(0.7),
                  onPressed: () => _confirmDeleteServer(server),
                  tooltip: 'Eliminar',
                ),
            ],
          ),
          onTap: isActive ? null : () => _selectServer(server),
        );
      },
    );
  }

  Widget _buildAddServerButton() {
    return Column(
      children: [
        // Botón buscar servidores en red (solo en Android)
        if (Platform.isAndroid)
          TextButton.icon(
            onPressed: _showDiscoveryDialog,
            icon: const Icon(Icons.wifi_find, size: 18),
            label: const Text('Buscar servidores en red'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue.shade300,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        TextButton.icon(
          onPressed: _showAddServerDialog,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Agregar servidor manual'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white70,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  Future<void> _showDiscoveryDialog() async {
    final discoveryService = ServerDiscoveryService();
    List<DiscoveredServer> foundServers = [];
    bool isScanning = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Iniciar escaneo
          if (isScanning && foundServers.isEmpty) {
            discoveryService.scanForServers(
              timeout: const Duration(seconds: 6),
            ).then((servers) {
              setDialogState(() {
                foundServers = servers;
                isScanning = false;
              });
            });
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1A1E2C),
            title: Row(
              children: [
                Icon(
                  isScanning ? Icons.wifi_find : Icons.dns,
                  color: Colors.blue.shade300,
                ),
                const SizedBox(width: 12),
                Text(
                  isScanning ? 'Buscando servidores...' : 'Servidores encontrados',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isScanning) ...[
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(
                      'Escaneando red local...',
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Asegúrate de estar conectado a la misma red WiFi que el servidor',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else if (foundServers.isEmpty) ...[
                    const Icon(
                      Icons.search_off,
                      size: 48,
                      color: Colors.white38,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No se encontraron servidores',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Verifica que el servidor esté ejecutándose y conectado a la misma red',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: foundServers.length,
                      itemBuilder: (context, index) {
                        final server = foundServers[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.computer,
                            color: Colors.green,
                          ),
                          title: Text(
                            server.displayName,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            '${server.ip}:${server.port}',
                            style: const TextStyle(color: Colors.white54),
                          ),
                          trailing: const Icon(
                            Icons.add_circle_outline,
                            color: Colors.blue,
                          ),
                          onTap: () async {
                            // Agregar servidor descubierto
                            final newServer = ServerProfile(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              name: server.displayName,
                              ip: server.ip,
                              port: server.port,
                            );
                            await ServerConfig.addServer(newServer);
                            await ServerConfig.setActiveServer(newServer.id);
                            
                            if (mounted) {
                              Navigator.pop(dialogContext);
                              setState(() => _connectionStatus = null);
                              widget.onServerChanged?.call();
                              
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('Servidor "${server.displayName}" agregado'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (!isScanning)
                TextButton.icon(
                  onPressed: () {
                    setDialogState(() {
                      isScanning = true;
                      foundServers = [];
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Buscar de nuevo'),
                ),
              TextButton(
                onPressed: () {
                  discoveryService.dispose();
                  Navigator.pop(dialogContext);
                },
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });

    final success = await ServerConfig.testActiveConnection();

    setState(() {
      _isTestingConnection = false;
      _connectionStatus = success;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
                ? 'Conexión exitosa al servidor'
                : 'No se pudo conectar al servidor',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _selectServer(ServerProfile server) async {
    await ServerConfig.setActiveServer(server.id);
    setState(() {
      _connectionStatus = null;
    });
    widget.onServerChanged?.call();
  }

  void _showAddServerDialog() {
    _showServerDialog(null);
  }

  void _showEditServerDialog(ServerProfile server) {
    _showServerDialog(server);
  }

  void _showServerDialog(ServerProfile? existingServer) {
    final nameController = TextEditingController(text: existingServer?.name ?? '');
    final ipController = TextEditingController(text: existingServer?.ip ?? '');
    final portController = TextEditingController(text: existingServer?.port.toString() ?? '3010');
    bool useHttps = existingServer?.useHttps ?? false;
    bool isEditing = existingServer != null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1E2C),
          title: Text(
            isEditing ? 'Editar servidor' : 'Agregar servidor',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    labelStyle: TextStyle(color: Colors.white70),
                    hintText: 'Ej: Producción, Desarrollo',
                    hintStyle: TextStyle(color: Colors.white38),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ipController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'IP o Hostname',
                    labelStyle: TextStyle(color: Colors.white70),
                    hintText: 'Ej: 192.168.1.100 o mi-servidor.com',
                    hintStyle: TextStyle(color: Colors.white38),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: portController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Puerto',
                    labelStyle: TextStyle(color: Colors.white70),
                    hintText: '3010',
                    hintStyle: TextStyle(color: Colors.white38),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                // HTTPS Switch
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: useHttps ? Colors.green.withOpacity(0.5) : Colors.white24,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        useHttps ? Icons.lock : Icons.lock_open,
                        color: useHttps ? Colors.green : Colors.white54,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Usar HTTPS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              useHttps 
                                  ? 'Conexión segura (SSL/TLS)'
                                  : 'Conexión sin cifrar',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: useHttps,
                        onChanged: (value) {
                          setDialogState(() {
                            useHttps = value;
                            // Sugerir puerto 443 para HTTPS
                            if (value && portController.text == '3010') {
                              portController.text = '443';
                            } else if (!value && portController.text == '443') {
                              portController.text = '3010';
                            }
                          });
                        },
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final ip = ipController.text.trim();
                final port = int.tryParse(portController.text.trim()) ?? 3010;

                if (name.isEmpty || ip.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Nombre e IP son requeridos'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (isEditing) {
                  final updated = existingServer!.copyWith(
                    name: name,
                    ip: ip,
                    port: port,
                    useHttps: useHttps,
                  );
                  await ServerConfig.updateServer(updated);
                } else {
                  final newServer = ServerProfile(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    ip: ip,
                    port: port,
                    useHttps: useHttps,
                  );
                  await ServerConfig.addServer(newServer);
                }

                if (mounted) {
                  Navigator.pop(context);
                  setState(() {
                    _connectionStatus = null;
                  });
                  widget.onServerChanged?.call();
                }
              },
              child: Text(isEditing ? 'Guardar' : 'Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteServer(ServerProfile server) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1E2C),
        title: const Text(
          'Eliminar servidor',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Está seguro de eliminar "${server.name}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              await ServerConfig.removeServer(server.id);
              if (mounted) {
                Navigator.pop(context);
                setState(() {
                  _connectionStatus = null;
                });
                widget.onServerChanged?.call();
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

/// Widget compacto para mostrar el servidor activo (solo lectura)
/// Usado en headers o áreas pequeñas
class ServerStatusBadge extends StatelessWidget {
  final bool compact;
  
  const ServerStatusBadge({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final server = ServerConfig.activeServer;
    
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.dns, size: 12, color: Colors.white54),
            const SizedBox(width: 4),
            Text(
              server?.name ?? 'N/A',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      'Servidor: ${server?.displayString ?? "No configurado"}',
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 12,
      ),
    );
  }
}
