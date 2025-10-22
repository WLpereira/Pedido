import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../features/map/map_service.dart';
import '../features/orders/orders_service.dart';
import '../features/map/table_token_service.dart';
import '../core/app_env.dart';

class MapEditorScreen extends StatefulWidget {
  final String? floorplanId;
  const MapEditorScreen({super.key, this.floorplanId});

  @override
  State<MapEditorScreen> createState() => _MapEditorScreenState();
}

class _MapEditorScreenState extends State<MapEditorScreen> {
  final MapService _mapService = MapService();
  final OrdersService _ordersService = OrdersService();
  final TableTokenService _tokenService = TableTokenService();
  final ImagePicker _picker = ImagePicker();

  String? _currentFloorplanId;
  String? _imageUrl;
  List<Map<String, dynamic>> _tables = [];
  List<Map<String, dynamic>> _activeOrders = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _currentFloorplanId = widget.floorplanId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Se não veio id, tentar pegar a planta mais recente
      if (_currentFloorplanId == null || _currentFloorplanId!.trim().isEmpty) {
        final plans = await _mapService.getFloorplans();
        if (plans.isNotEmpty) {
          _currentFloorplanId = plans.first['id']?.toString();
          _imageUrl = plans.first['image_path']?.toString();
          _tables = await _mapService.getTables(_currentFloorplanId!);
        }
      } else if (!_currentFloorplanId!.startsWith('local_')) {
        // Carregar imagem e mesas da planta informada
        final plans = await _mapService.getFloorplans();
        final plan = plans.firstWhere(
          (p) => p['id'].toString() == _currentFloorplanId,
          orElse: () => {},
        );
        if (plan.isNotEmpty) {
          _imageUrl = plan['image_path']?.toString();
          _tables = await _mapService.getTables(_currentFloorplanId!);
        }
      }

      // Carregar pedidos ativos para destacar mesas
      try {
        final orders = await _ordersService.getActiveOrders();
        _activeOrders = orders;
      } catch (_) {
        _activeOrders = [];
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _loading = true);
    try {
      final bytes = await image.readAsBytes();
      final imageUrl = await _mapService.uploadFloorplanImage(
        bytes,
        image.name,
      );

      // Simplesmente armazenar a imagem localmente sem salvar no banco
      // Isso evita problemas de UUID e configuração do Supabase
      setState(() {
        _imageUrl = imageUrl;
        // Gerar um ID local temporário se não existir
        _currentFloorplanId ??=
            'local_${DateTime.now().millisecondsSinceEpoch}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imagem carregada com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar imagem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _addTable() async {
    if (_currentFloorplanId == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddTableDialog(),
    );

    if (result == null) return;

    setState(() => _loading = true);
    try {
      // Adicionar mesa localmente sem salvar no banco
      final newTable = {
        'id': 'local_table_${DateTime.now().millisecondsSinceEpoch}',
        'floorplan_id': _currentFloorplanId!,
        'label': result['label'],
        'description': result['description'],
        'x': result['x'] ?? 100,
        'y': result['y'] ?? 100,
        'width': 60,
        'height': 60,
        'is_active': true,
      };

      setState(() {
        _tables.add(newTable);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mesa adicionada com sucesso!')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  // Adicionar mesa clicando diretamente na imagem
  void _addTableAtPosition(Offset position) {
    if (_currentFloorplanId == null) return;

    // Mostrar dialog para nome da mesa
    showDialog(
      context: context,
      builder:
          (context) => _AddTableAtPositionDialog(
            x: position.dx.round(),
            y: position.dy.round(),
            onConfirm: (label, description) {
              final newTable = {
                'id': 'local_table_${DateTime.now().millisecondsSinceEpoch}',
                'floorplan_id': _currentFloorplanId!,
                'label': label,
                'description': description,
                'x': position.dx.round(),
                'y': position.dy.round(),
                'width': 60,
                'height': 60,
                'is_active': true,
              };

              setState(() {
                _tables.add(newTable);
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Mesa adicionada na posição clicada!'),
                ),
              );
            },
          ),
    );
  }

  Future<void> _updateTablePosition(String tableId, int x, int y) async {
    // Atualizar posição localmente
    setState(() {
      final tableIndex = _tables.indexWhere((t) => t['id'] == tableId);
      if (tableIndex != -1) {
        _tables[tableIndex]['x'] = x;
        _tables[tableIndex]['y'] = y;
      }
    });
  }

  bool _hasActiveOrder(String tableId) {
    return _activeOrders.any((order) => order['table_id'] == tableId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor de Mapa'),
        leading: IconButton(
          onPressed: _saveAndGoBack,
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Salvar e voltar ao painel',
        ),
        actions: [
          IconButton(
            onPressed: _pickImage,
            icon: const Icon(Icons.upload),
            tooltip: 'Carregar imagem',
          ),
          IconButton(
            onPressed: _addTable,
            icon: const Icon(Icons.add),
            tooltip: 'Adicionar mesa',
          ),
          IconButton(
            onPressed: _saveFloorplan,
            icon: const Icon(Icons.save),
            tooltip: 'Salvar planta',
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _imageUrl == null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.image, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('Nenhuma imagem carregada'),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.upload),
                      label: const Text('Carregar imagem do salão'),
                    ),
                  ],
                ),
              )
              : InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: GestureDetector(
                  onTapDown: (details) {
                    // Adicionar mesa onde clicou
                    _addTableAtPosition(details.localPosition);
                  },
                  child: Stack(
                    children: [
                      // Imagem de fundo
                      Image.network(
                        _imageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder:
                            (context, error, stackTrace) => const Center(
                              child: Text('Erro ao carregar imagem'),
                            ),
                      ),
                      // Mesas posicionadas
                      ..._tables.map((table) => _buildTableWidget(table)),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildTableWidget(Map<String, dynamic> table) {
    final hasOrder = _hasActiveOrder(table['id']);
    return Positioned(
      left: (table['x'] as num).toDouble(),
      top: (table['y'] as num).toDouble(),
      child: Draggable(
        data: table,
        onDragEnd: (details) {
          // Usar o RenderBox do Stack (InteractiveViewer) para calcular posição correta
          final RenderBox? stackBox = context.findRenderObject() as RenderBox?;
          if (stackBox != null) {
            final localPosition = stackBox.globalToLocal(details.offset);
            _updateTablePosition(
              table['id'],
              localPosition.dx.round(),
              localPosition.dy.round(),
            );
          }
        },
        feedback: _TableWidget(
          label: table['label'],
          hasOrder: hasOrder,
          isDragging: true,
        ),
        child: _TableWidget(
          label: table['label'],
          hasOrder: hasOrder,
          onTap: () => _showTableDetails(table),
        ),
      ),
    );
  }

  void _showTableDetails(Map<String, dynamic> table) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Mesa ${table['label']}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Descrição: ${table['description'] ?? 'Sem descrição'}'),
                Text('Posição: (${table['x']}, ${table['y']})'),
                if (_hasActiveOrder(table['id']))
                  const Text(
                    'Status: Com pedido ativo',
                    style: TextStyle(color: Colors.green),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _editTable(table);
                },
                child: const Text('Editar'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _showTableQr(table);
                },
                child: const Text('QR Code'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteTable(table['id']);
                },
                child: const Text(
                  'Excluir',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _editTable(Map<String, dynamic> table) async {
    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EditTableDialog(
        initialLabel: table['label']?.toString() ?? '',
        initialDescription: table['description']?.toString(),
      ),
    );
    if (updated == null) return;

    setState(() {
      table['label'] = updated['label'];
      table['description'] = updated['description'];
    });

    // Persistir se já existir no banco
    try {
      final id = table['id']?.toString();
      final floorplanId = _currentFloorplanId;
      if (id != null && !id.startsWith('local_') &&
          floorplanId != null && floorplanId.isNotEmpty) {
        await _mapService.saveTable(
          id: id,
          floorplanId: floorplanId,
          label: table['label'],
          description: table['description'],
          x: table['x'],
          y: table['y'],
          width: table['width'] ?? 60,
          height: table['height'] ?? 60,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mesa atualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao salvar: $e')),
        );
      }
    }
  }

  Future<void> _showTableQr(Map<String, dynamic> table) async {
    final tableId = table['id'].toString();
    String payload;
    if (table.containsKey('payloadOverride') && table['payloadOverride'] is String) {
      payload = table['payloadOverride'] as String;
    } else {
      String token;
      try {
        token = await _tokenService.getOrCreateTableToken(tableId);
      } catch (_) {
        token = tableId; // fallback: usar tableId como token
      }
      final base = AppEnv.qrBaseUrl.trim();
      payload = base.isEmpty ? token : '$base?t=${Uri.encodeComponent(token)}';
    }
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('QR - Mesa ${table['label']}'),
        content: SizedBox(
          width: 260,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(data: payload, size: 200),
              const SizedBox(height: 12),
              SelectableText(payload, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Confirmar regeneração
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Regenerar token?'),
                  content: const Text('O QR atual será invalidado e um novo será gerado.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Regenerar')),
                  ],
                ),
              );
              if (ok != true) return;
              Navigator.pop(context); // fechar diálogo atual
              try {
                final newToken = await _tokenService.regenerateTableToken(tableId);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Token regenerado')),
                );
                // reabrir com novo token
                final base = AppEnv.qrBaseUrl.trim();
                final newPayload = base.isEmpty ? newToken : '$base?t=${Uri.encodeComponent(newToken)}';
                await _showTableQr({'id': tableId, 'label': table['label'], 'payloadOverride': newPayload});
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Falha ao regenerar: $e')),
                );
              }
            },
            child: const Text('Regenerar token'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: payload));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Token copiado')),
              );
            },
            child: const Text('Copiar token'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final bytes = await _buildQrPngBytes(payload, size: 800);
                final file = XFile.fromData(
                  bytes,
                  name: 'qr-mesa-${(table['label'] ?? 'mesa').toString().replaceAll(' ', '-')}.png',
                  mimeType: 'image/png',
                );
                await Share.shareXFiles([file], text: 'QR da mesa ${table['label']}');
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro ao compartilhar: $e')),
                );
              }
            },
            child: const Text('Compartilhar'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final bytes = await _buildQrPngBytes(payload, size: 1200);
                final doc = pw.Document();
                final image = pw.MemoryImage(bytes);
                doc.addPage(
                  pw.Page(
                    pageFormat: PdfPageFormat.a4,
                    build: (ctx) => pw.Center(
                      child: pw.Column(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Container(
                            width: 240,
                            height: 240,
                            child: pw.Image(image, fit: pw.BoxFit.contain),
                          ),
                          pw.SizedBox(height: 16),
                          pw.Text('Mesa ${table['label'] ?? ''}', style: pw.TextStyle(fontSize: 18)),
                          pw.SizedBox(height: 6),
                          pw.Text(payload, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        ],
                      ),
                    ),
                  ),
                );
                await Printing.layoutPdf(onLayout: (format) async => doc.save());
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro ao imprimir: $e')),
                );
              }
            },
            child: const Text('Imprimir'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _buildQrPngBytes(String data, {double size = 600}) async {
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square),
      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square),
    );
    final imageData = await painter.toImageData(size, format: ui.ImageByteFormat.png);
    return imageData!.buffer.asUint8List();
  }

  Future<void> _deleteTable(String tableId) async {
    // Se for mesa persistida, marcar como inativa no banco
    if (!tableId.toString().startsWith('local_')) {
      try {
        await _mapService.deleteTable(tableId);
      } catch (_) {
        // continuar mesmo que falhe em DEV
      }
    }
    // Remover localmente
    setState(() {
      _tables.removeWhere((t) => t['id'] == tableId);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesa removida com sucesso!')),
      );
    }
  }

  // Salvar planta no banco de dados
  Future<void> _saveFloorplan() async {
    if (_currentFloorplanId == null || _imageUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Carregue uma imagem antes de salvar!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _loading = true);
    try {
      // Salvar a planta
      String floorplanId;
      if (_currentFloorplanId!.startsWith('local_') || _currentFloorplanId!.trim().isEmpty) {
        // Criar nova planta
        floorplanId = await _mapService.saveFloorplan(
          name: 'Planta do Salão',
          imagePath: _imageUrl!,
        );
        _currentFloorplanId = floorplanId;
      } else {
        // Atualizar planta existente
        await _mapService.saveFloorplan(
          id: _currentFloorplanId,
          name: 'Planta do Salão',
          imagePath: _imageUrl!,
        );
        floorplanId = _currentFloorplanId!;
      }

      // Salvar todas as mesas
      for (final table in _tables) {
        final String? tableId = table['id']?.toString();
        if (tableId == null || tableId.isEmpty || tableId.startsWith('local_')) {
          final newId = await _mapService.saveTable(
            floorplanId: floorplanId,
            label: table['label'],
            description: table['description'],
            x: table['x'],
            y: table['y'],
            width: table['width'] ?? 60,
            height: table['height'] ?? 60,
          );
          // Atualizar ID local para o ID real retornado
          table['id'] = newId;
        } else {
          // Atualizar mesa existente
          await _mapService.saveTable(
            id: tableId,
            floorplanId: floorplanId,
            label: table['label'],
            description: table['description'],
            x: table['x'],
            y: table['y'],
            width: table['width'] ?? 60,
            height: table['height'] ?? 60,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Planta salva com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  // Salvar e voltar ao painel
  Future<void> _saveAndGoBack() async {
    if (_imageUrl != null && _tables.isNotEmpty) {
      await _saveFloorplan();
      // Informar que salvou com sucesso (para Painel recarregar mapa)
      if (mounted) {
        Navigator.pop(context, true);
        return;
      }
    }

    if (mounted) {
      Navigator.pop(context, false);
    }
  }
}

class _TableWidget extends StatelessWidget {
  final String label;
  final bool hasOrder;
  final bool isDragging;
  final VoidCallback? onTap;

  const _TableWidget({
    required this.label,
    required this.hasOrder,
    this.isDragging = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: hasOrder ? Colors.green : Colors.grey,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow:
              isDragging
                  ? [const BoxShadow(blurRadius: 8, color: Colors.black26)]
                  : null,
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTableDialog extends StatefulWidget {
  @override
  State<_AddTableDialog> createState() => _AddTableDialogState();
}

class _AddTableDialogState extends State<_AddTableDialog> {
  final _labelCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar Mesa'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _labelCtrl,
            decoration: const InputDecoration(
              labelText: 'Nome da mesa (ex: Mesa 1)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Descrição (opcional)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_labelCtrl.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'label': _labelCtrl.text.trim(),
              'description':
                  _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
            });
          },
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}

class _AddTableAtPositionDialog extends StatefulWidget {
  final int x;
  final int y;
  final Function(String label, String? description) onConfirm;

  const _AddTableAtPositionDialog({
    required this.x,
    required this.y,
    required this.onConfirm,
  });

  @override
  State<_AddTableAtPositionDialog> createState() =>
      _AddTableAtPositionDialogState();
}

class _AddTableAtPositionDialogState extends State<_AddTableAtPositionDialog> {
  final _labelCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar Mesa'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Posição: (${widget.x}, ${widget.y})',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _labelCtrl,
            decoration: const InputDecoration(
              labelText: 'Nome da mesa (ex: Mesa 1)',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Descrição (opcional)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_labelCtrl.text.trim().isEmpty) return;
            widget.onConfirm(
              _labelCtrl.text.trim(),
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
            );
            Navigator.pop(context);
          },
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}

class _EditTableDialog extends StatefulWidget {
  final String initialLabel;
  final String? initialDescription;

  const _EditTableDialog({
    required this.initialLabel,
    this.initialDescription,
  });

  @override
  State<_EditTableDialog> createState() => _EditTableDialogState();
}

class _EditTableDialogState extends State<_EditTableDialog> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.initialLabel);
    _descCtrl = TextEditingController(text: widget.initialDescription ?? '');
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Mesa'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _labelCtrl,
            decoration: const InputDecoration(labelText: 'Nome da mesa'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_labelCtrl.text.trim().isEmpty) return;
            Navigator.pop<Map<String, dynamic>>(context, {
              'label': _labelCtrl.text.trim(),
              'description': _descCtrl.text.trim().isEmpty
                  ? null
                  : _descCtrl.text.trim(),
            });
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
