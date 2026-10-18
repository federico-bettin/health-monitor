import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/models/esame.dart';
import 'package:salute_bettin/data/models/farmaco.dart';
import 'package:salute_bettin/data/models/visita.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/repositories/repository_provider.dart';
import 'package:salute_bettin/data/services/claude_service.dart';
import 'package:uuid/uuid.dart';

// ─── Documento in coda ────────────────────────────────────────
class _DocumentoInCoda {
  final File file;
  final bool isPdf;
  String stato; // attesa | analisi | ok | errore | duplicato
  Map<String, dynamic>? risultato;
  String? errore;
  bool salvato;

  _DocumentoInCoda({
    required this.file, required this.isPdf,
    this.stato = 'attesa', this.risultato,
    this.errore, this.salvato = false,
  });

  String get nome => file.path.split(Platform.pathSeparator).last;
  String get dimensione => '${(file.lengthSync() / 1024).toStringAsFixed(1)} KB';
}

class ImportDocumentoPage extends ConsumerStatefulWidget {
  const ImportDocumentoPage({super.key});

  @override
  ConsumerState<ImportDocumentoPage> createState() => _ImportDocumentoPageState();
}

class _ImportDocumentoPageState extends ConsumerState<ImportDocumentoPage> {
  final ImagePicker _picker = ImagePicker();
  final ClaudeService _claude = ClaudeService();
  final List<_DocumentoInCoda> _documenti = [];
  bool _elaborando = false;

  // ─── Controlla duplicati ──────────────────────────────────
  Future<bool> _isDuplicato(File file) async {
    final repo = LocalRepository();
    await repo.init();
    final nomeFile = p.basename(file.path);
    final esami = await repo.getEsami();
    final visite = await repo.getVisite();
    final farmaci = await repo.getFarmaci();
    for (final e in esami) {
      if (e.allegato != null && p.basename(e.allegato!) == nomeFile) return true;
    }
    for (final v in visite) {
      if (v.allegato != null && p.basename(v.allegato!) == nomeFile) return true;
    }
    for (final f in farmaci) {
      // farmaci non hanno allegato ma controlliamo il nome
    }
    return false;
  }

  // ─── Copia file in cartella app ───────────────────────────
  Future<String> _copiaFile(File file) async {
    final dir = await getApplicationDocumentsDirectory();
    final destDir = Directory('${dir.path}/allegati');
    if (!await destDir.exists()) await destDir.create(recursive: true);
    final dest = '${destDir.path}/${p.basename(file.path)}';
    await file.copy(dest);
    return dest;
  }

  // ─── Fotocamera ───────────────────────────────────────────
  Future<void> _apriCamera() async {
    try {
      final picked = await _picker.pickImage(
          source: ImageSource.camera, imageQuality: 85, maxWidth: 1920);
      if (picked == null) return;
      await _aggiungi(File(picked.path), false);
    } catch (e) { _mostraErrore('Errore: $e'); }
  }

  // ─── Galleria ─────────────────────────────────────────────
  Future<void> _apriGalleria() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1920);
      for (final img in picked) await _aggiungi(File(img.path), false);
    } catch (e) { _mostraErrore('Errore: $e'); }
  }

  // ─── PDF da Drive / Downloads (ACTION_OPEN_DOCUMENT multi) ─
  static const _channel = MethodChannel('com.bettin.salute_bettin/file_picker');

  Future<void> _selezionaPdf() async {
    try {
      // Restituisce una List<Uint8List> — uno per ogni file selezionato
      final raw = await _channel.invokeMethod<List<dynamic>>('pickPdf');
      if (raw == null || raw.isEmpty) return;

      final tmpDir = await getTemporaryDirectory();
      final ts     = DateTime.now().millisecondsSinceEpoch;

      for (int i = 0; i < raw.length; i++) {
        final bytes = raw[i] as Uint8List;
        final tmpFile = File('${tmpDir.path}/pdf_${ts}_$i.pdf');
        await tmpFile.writeAsBytes(bytes);
        await _aggiungi(tmpFile, true);
      }
    } on PlatformException catch (e) {
      _mostraErrore('Errore selezione PDF: ${e.message}');
    } catch (e) {
      _mostraErrore('Errore: $e');
    }
  }

  // ─── Browser ──────────────────────────────────────────────
  Future<void> _apriBrowser() async {
    if (Platform.isAndroid) {
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) await Permission.storage.request();
      }
    }

    final Directory startDir;
    if (Platform.isAndroid) {
      startDir = Directory('/storage/emulated/0');
    } else if (Platform.isWindows) {
      startDir = Directory(Platform.environment['USERPROFILE'] ?? 'C:\\');
    } else {
      final d = await getDownloadsDirectory();
      startDir = d ?? Directory.systemTemp;
    }

    if (!mounted) return;
    final selectedFiles = await Navigator.push<List<File>>(
      context,
      MaterialPageRoute(builder: (_) => _FileBrowserPage(startDir: startDir)),
    );

    if (selectedFiles != null) {
      for (final f in selectedFiles) {
        final ext = f.path.split('.').last.toLowerCase();
        await _aggiungi(f, ext == 'pdf');
      }
    }
  }

  Future<void> _aggiungi(File file, bool isPdf) async {
    // Evita duplicati nella coda
    if (_documenti.any((d) => d.file.path == file.path)) return;

    // Controlla duplicati nel database
    final dup = await _isDuplicato(file);
    final doc = _DocumentoInCoda(file: file, isPdf: isPdf);
    if (dup) {
      doc.stato = 'duplicato';
      doc.errore = 'Documento già presente nel database';
    }
    setState(() => _documenti.add(doc));
  }

  void _rimuovi(int index) => setState(() => _documenti.removeAt(index));

  void _mostraErrore(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.error));
  }

  // ─── Analizza tutti ───────────────────────────────────────
  Future<void> _analizzaTutti() async {
    final inAttesa = _documenti.where((d) => d.stato == 'attesa').toList();
    if (inAttesa.isEmpty) return;
    setState(() => _elaborando = true);

    for (final doc in inAttesa) {
      if (!mounted) break;
      setState(() => doc.stato = 'analisi');
      try {
        final bytes = await doc.file.readAsBytes();
        if (bytes.isEmpty) {
          setState(() { doc.stato = 'errore'; doc.errore = 'File vuoto'; });
          continue;
        }
        final base64Data = base64Encode(bytes);
        ClaudeResponse response;
        if (doc.isPdf) {
          response = await _claude.analizzaDocumento(base64Pdf: base64Data);
        } else {
          final ext = doc.file.path.split('.').last.toLowerCase();
          final mediaType = ext == 'png' ? 'image/png' : 'image/jpeg';
          response = await _claude.analizzaDocumento(
              base64Immagine: base64Data, mediaTypeImmagine: mediaType);
        }
        final repo = LocalRepository();
    await repo.init();
        await repo.saveTokenUsage(response.toTokenUsage('import_documento'));
        String text = response.text.trim().replaceAll(RegExp(r'```json|```'), '').trim();
        setState(() { doc.stato = 'ok'; doc.risultato = jsonDecode(text); });
      } catch (e) {
        setState(() { doc.stato = 'errore'; doc.errore = e.toString(); });
      }
    }
    setState(() => _elaborando = false);
  }

  // ─── Salva singolo ────────────────────────────────────────
  Future<void> _salva(_DocumentoInCoda doc) async {
    if (doc.risultato == null) return;
    try {
      // Copia il file nella cartella app
      final pathSalvato = await _copiaFile(doc.file);

      final repo = LocalRepository();
    await repo.init();
      final tipo = doc.risultato!['tipo'] as String? ?? 'altro';
      final dati = doc.risultato!['dati'] as Map<String, dynamic>? ?? {};
      final dataStr = doc.risultato!['data'] as String?;
      final data = dataStr != null
          ? DateTime.tryParse(dataStr) ?? DateTime.now() : DateTime.now();

      switch (tipo) {
        case 'esame':
          final valori = (dati['valori'] as List? ?? []).map((v) => ValoreEsame(
            nome: v['nome'] ?? '', valore: v['valore'] ?? '',
            unita: v['unita'], riferimentoMin: v['riferimentoMin'],
            riferimentoMax: v['riferimentoMax'], fuoriRange: v['fuoriRange'] == true,
          )).toList();
          await repo.saveEsame(Esame(id: const Uuid().v4(),
            tipo: doc.risultato!['titolo'] ?? 'Esame', data: data, valori: valori,
            laboratorio: doc.risultato!['laboratorio'],
            note: doc.risultato!['esito'] ?? doc.risultato!['note'],
            allegato: pathSalvato)); // ← salva path
          break;
        case 'visita':
          await repo.saveVisita(Visita(id: const Uuid().v4(),
            specialita: dati['specialita'] ?? doc.risultato!['titolo'] ?? 'Visita',
            data: data, medico: dati['medico'], diagnosi: dati['diagnosi'],
            terapia: dati['terapia'], note: doc.risultato!['note'],
            allegato: pathSalvato)); // ← salva path
          break;
        case 'farmaco':
          await repo.saveFarmaco(Farmaco(id: const Uuid().v4(),
            nome: dati['nome'] ?? doc.risultato!['titolo'] ?? 'Farmaco',
            dosaggio: dati['dosaggio'] ?? '', frequenza: dati['frequenza'] ?? '',
            dataInizio: data, note: doc.risultato!['note']));
          break;
      }
      setState(() => doc.salvato = true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${doc.nome} salvato!'),
              backgroundColor: AppTheme.secondary));
    } catch (e) {
      if (mounted) _mostraErrore('Errore: $e');
    }
  }

  // ─── Salva tutti ──────────────────────────────────────────
  Future<void> _salvaTutti() async {
    final daSalvare = _documenti.where((d) => d.stato == 'ok' && !d.salvato).toList();
    for (final doc in daSalvare) await _salva(doc);
    if (mounted) Navigator.pop(context);
  }

  bool get _haDaSalvare => _documenti.any((d) => d.stato == 'ok' && !d.salvato);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importa documenti'),
        leading: IconButton(icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
        actions: [
          if (_haDaSalvare)
            TextButton.icon(
              onPressed: _salvaTutti,
              icon: const Icon(Icons.save_alt, size: 18),
              label: const Text('Salva tutti'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.secondary)),
        ],
      ),
      body: Column(children: [
        // Bottoni selezione
        Padding(padding: const EdgeInsets.all(16),
          child: Column(children: [
            if (!Platform.isWindows) ...[
              Row(children: [
                Expanded(child: _ActionBtn(icon: Icons.camera_alt, label: 'Fotocamera',
                    onTap: _elaborando ? null : _apriCamera)),
                const SizedBox(width: 10),
                Expanded(child: _ActionBtn(icon: Icons.photo_library, label: 'Galleria',
                    sublabel: 'multi', onTap: _elaborando ? null : _apriGalleria)),
              ]),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity,
                child: _ActionBtn(
                  icon: Icons.picture_as_pdf,
                  label: 'Scegli PDF',
                  sublabel: 'Google Drive · Downloads · Files',
                  onTap: _elaborando ? null : _selezionaPdf,
                  color: AppTheme.error,
                )),
              const SizedBox(height: 10),
            ],
            SizedBox(width: double.infinity,
              child: _ActionBtn(icon: Icons.folder_open, label: 'Sfoglia file',
                  sublabel: 'JPG · PNG · PDF · multi-selezione',
                  onTap: _elaborando ? null : _apriBrowser, primary: true)),
          ])),

        // Lista documenti
        if (_documenti.isEmpty)
          Expanded(child: Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.document_scanner, size: 64,
                  color: AppTheme.textSecondaryDark.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text('Nessun documento selezionato',
                  style: TextStyle(color: AppTheme.textSecondaryDark)),
            ])))
        else
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _documenti.length,
            itemBuilder: (ctx, i) => _DocumentoCard(
              doc: _documenti[i],
              onRemove: _elaborando ? null : () => _rimuovi(i),
              onSalva: () => _salva(_documenti[i]),
            ))),

        // Bottone analizza
        if (_documenti.any((d) => d.stato == 'attesa'))
          Padding(padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _elaborando ? null : _analizzaTutti,
              icon: _elaborando
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome),
              label: Text(_elaborando ? 'Analisi in corso...'
                  : 'Analizza ${_documenti.where((d) => d.stato == "attesa").length} documenti'))),
      ]),
    );
  }
}

// ─── Action Button ────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final VoidCallback? onTap;
  final bool primary;
  final Color? color;
  const _ActionBtn({required this.icon, required this.label,
      this.sublabel, this.onTap, this.primary = false, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? (primary ? AppTheme.primary : null);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: primary
              ? AppTheme.primary.withOpacity(0.15)
              : c != null ? c.withOpacity(0.08) : AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: c != null ? c.withOpacity(0.5) : AppTheme.borderDark)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 20,
              color: c ?? AppTheme.textSecondaryDark),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c ?? AppTheme.textPrimaryDark)),
            if (sublabel != null)
              Text(sublabel!, style: const TextStyle(
                  fontSize: 10, color: AppTheme.textSecondaryDark)),
          ]),
        ]),
      ),
    );
  }
}

// ─── Documento Card ───────────────────────────────────────────
class _DocumentoCard extends StatelessWidget {
  final _DocumentoInCoda doc;
  final VoidCallback? onRemove;
  final VoidCallback onSalva;
  const _DocumentoCard({required this.doc, required this.onRemove, required this.onSalva});

  Color get _statoColor => switch (doc.stato) {
    'ok' => AppTheme.secondary,
    'errore' => AppTheme.error,
    'duplicato' => AppTheme.warning,
    'analisi' => AppTheme.primary,
    _ => AppTheme.textSecondaryDark,
  };

  IconData get _statoIcon => switch (doc.stato) {
    'ok' => Icons.check_circle,
    'errore' => Icons.error_outline,
    'duplicato' => Icons.content_copy,
    'analisi' => Icons.hourglass_top,
    _ => Icons.schedule,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _statoColor.withOpacity(0.3))),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Icon(doc.isPdf ? Icons.picture_as_pdf : Icons.image,
                size: 20, color: doc.isPdf ? AppTheme.error : AppTheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(doc.nome, style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              Text(doc.dimensione, style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondaryDark)),
            ])),
            if (doc.stato == 'analisi')
              const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
            else
              Icon(_statoIcon, size: 20, color: _statoColor),
            if (onRemove != null && doc.stato != 'analisi') ...[
              const SizedBox(width: 4),
              GestureDetector(onTap: onRemove,
                child: const Icon(Icons.close, size: 18, color: AppTheme.textSecondaryDark)),
            ],
          ]),
        ),

        // Messaggio duplicato
        if (doc.stato == 'duplicato')
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warning.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.warning_amber, size: 16, color: AppTheme.warning),
                const SizedBox(width: 8),
                const Expanded(child: Text('Documento già presente nel database',
                    style: TextStyle(fontSize: 12, color: AppTheme.warning))),
              ]))),

        // Risultato OK
        if (doc.stato == 'ok' && doc.risultato != null) ...[
          const Divider(height: 1, color: AppTheme.borderDark),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(doc.risultato!['titolo'] ?? 'Documento',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (doc.risultato!['data'] != null)
                    Text(doc.risultato!['data'],
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark)),
                ])),
                _TipoBadge(tipo: doc.risultato!['tipo'] ?? 'altro'),
              ]),
              if (doc.risultato!['esito'] != null) ...[
                const SizedBox(height: 10),
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.2))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.medical_information, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Expanded(child: Text(doc.risultato!['esito'],
                        style: const TextStyle(fontSize: 12))),
                  ])),
              ],
              if (!doc.salvato) ...[
                const SizedBox(height: 10),
                SizedBox(width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onSalva,
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('Salva'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(38),
                      backgroundColor: AppTheme.secondary,
                      foregroundColor: Colors.black))),
              ] else
                Container(padding: const EdgeInsets.symmetric(vertical: 6),
                  alignment: Alignment.center,
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.check, size: 16, color: AppTheme.secondary),
                    SizedBox(width: 6),
                    Text('Salvato', style: TextStyle(color: AppTheme.secondary, fontSize: 13)),
                  ])),
            ])),
        ],

        // Errore
        if (doc.stato == 'errore' && doc.errore != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Text(doc.errore!,
                style: const TextStyle(fontSize: 11, color: AppTheme.error))),
      ]),
    );
  }
}

class _TipoBadge extends StatelessWidget {
  final String tipo;
  const _TipoBadge({required this.tipo});

  Color get _color => switch (tipo) {
    'esame' => AppTheme.secondary,
    'visita' => AppTheme.primary,
    'farmaco' => AppTheme.warning,
    _ => AppTheme.textSecondaryDark,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.3))),
      child: Text(tipo.toUpperCase(),
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _color)));
  }
}

// ─── File Browser ─────────────────────────────────────────────
class _FileBrowserPage extends StatefulWidget {
  final Directory startDir;
  const _FileBrowserPage({required this.startDir});

  @override
  State<_FileBrowserPage> createState() => _FileBrowserPageState();
}

class _FileBrowserPageState extends State<_FileBrowserPage> {
  late Directory _currentDir;
  List<FileSystemEntity> _entries = [];
  final Set<String> _selected = {};
  bool _loading = true;
  String? _errore;

  static const _allowedExt = ['jpg', 'jpeg', 'png', 'pdf'];

  @override
  void initState() {
    super.initState();
    _currentDir = widget.startDir;
    _carica();
  }

  Future<void> _carica() async {
    setState(() { _loading = true; _errore = null; });
    try {
      final entries = _currentDir.listSync()
        ..sort((a, b) {
          if (a is Directory && b is! Directory) return -1;
          if (a is! Directory && b is Directory) return 1;
          return p.basename(a.path).toLowerCase()
              .compareTo(p.basename(b.path).toLowerCase());
        });
      final filtered = entries.where((e) {
        final nome = p.basename(e.path);
        if (nome.startsWith('.')) return false;
        if (e is Directory) return true;
        return _allowedExt.contains(nome.split('.').last.toLowerCase());
      }).toList();
      setState(() { _entries = filtered; _loading = false; });
    } catch (e) {
      setState(() { _errore = '$e'; _loading = false; });
    }
  }

  void _naviga(Directory dir) {
    _selected.clear();
    setState(() => _currentDir = dir);
    _carica();
  }

  @override
  Widget build(BuildContext context) {
    final nomeCartella = p.basename(_currentDir.path).isEmpty
        ? _currentDir.path : p.basename(_currentDir.path);

    return Scaffold(
      appBar: AppBar(
        title: Text(nomeCartella, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final parent = _currentDir.parent;
            if (parent.path != _currentDir.path) _naviga(parent);
            else Navigator.pop(context, <File>[]);
          }),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(context,
                  _selected.map((p) => File(p)).toList()),
              child: Text('Seleziona (${_selected.length})',
                  style: const TextStyle(color: AppTheme.secondary,
                      fontWeight: FontWeight.w700))),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errore != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.folder_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(_errore!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: () => _naviga(_currentDir.parent),
                      child: const Text('Torna indietro')),
                ]))
              : _entries.isEmpty
                  ? const Center(child: Text('Cartella vuota',
                      textAlign: TextAlign.center))
                  : ListView.builder(
                      itemCount: _entries.length,
                      itemBuilder: (ctx, i) {
                        final entry = _entries[i];
                        final nome = p.basename(entry.path);
                        final isDir = entry is Directory;
                        final ext = isDir ? '' : nome.split('.').last.toLowerCase();
                        final isPdf = ext == 'pdf';
                        final isSelected = _selected.contains(entry.path);

                        return ListTile(
                          leading: Icon(
                            isDir ? Icons.folder : (isPdf ? Icons.picture_as_pdf : Icons.image),
                            color: isDir ? const Color(0xFFFFB300)
                                : (isPdf ? AppTheme.error : AppTheme.primary)),
                          title: Text(nome, style: const TextStyle(fontSize: 14)),
                          subtitle: isDir ? null : Text(ext.toUpperCase(),
                              style: const TextStyle(fontSize: 11)),
                          trailing: isDir
                              ? const Icon(Icons.chevron_right)
                              : Checkbox(value: isSelected,
                                  onChanged: (_) => setState(() {
                                    if (isSelected) _selected.remove(entry.path);
                                    else _selected.add(entry.path);
                                  })),
                          onTap: () {
                            if (isDir) _naviga(entry as Directory);
                            else setState(() {
                              if (isSelected) _selected.remove(entry.path);
                              else _selected.add(entry.path);
                            });
                          },
                        );
                      }),
    );
  }
}
