import 'package:flutter/material.dart' hide Text;
import 'package:salute_bettin/core/i18n.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/models/visita.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/services/backup_service.dart';
import 'package:salute_bettin/data/services/settings_service.dart';
import 'package:uuid/uuid.dart';

class VisitaFormPage extends StatefulWidget {
  final Visita? visita;
  const VisitaFormPage({super.key, this.visita});

  @override
  State<VisitaFormPage> createState() => _VisitaFormPageState();
}

class _VisitaFormPageState extends State<VisitaFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _specialitaCtrl;
  late TextEditingController _medicoCtrl;
  late TextEditingController _strutturaCtrl;
  late TextEditingController _diagnosiCtrl;
  late TextEditingController _terapiaCtrl;
  late TextEditingController _noteCtrl;
  late DateTime _data;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final v = widget.visita;
    _specialitaCtrl = TextEditingController(text: v?.specialita ?? '');
    _medicoCtrl = TextEditingController(text: v?.medico ?? '');
    _strutturaCtrl = TextEditingController(text: v?.struttura ?? '');
    _diagnosiCtrl = TextEditingController(text: v?.diagnosi ?? '');
    _terapiaCtrl = TextEditingController(text: v?.terapia ?? '');
    _noteCtrl = TextEditingController(text: v?.note ?? '');
    _data = v?.data ?? DateTime.now();
  }

  @override
  void dispose() {
    _specialitaCtrl.dispose();
    _medicoCtrl.dispose();
    _strutturaCtrl.dispose();
    _diagnosiCtrl.dispose();
    _terapiaCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _data = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = LocalRepository();
      await repo.init();
      final visita = Visita(
        id: widget.visita?.id ?? const Uuid().v4(),
        specialita: _specialitaCtrl.text.trim(),
        data: _data,
        medico: _medicoCtrl.text.trim().isEmpty
            ? null
            : _medicoCtrl.text.trim(),
        struttura: _strutturaCtrl.text.trim().isEmpty
            ? null
            : _strutturaCtrl.text.trim(),
        diagnosi: _diagnosiCtrl.text.trim().isEmpty
            ? null
            : _diagnosiCtrl.text.trim(),
        terapia: _terapiaCtrl.text.trim().isEmpty
            ? null
            : _terapiaCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      await repo.saveVisita(visita);

      // ── Invalida cache score → ricalcolo automatico al prossimo avvio dashboard
      final paz = await repo.getPaziente();
      final pazKey = paz != null
          ? BackupService.slotKey(paz.nome, paz.cognome)
          : 'default';
      await SettingsService.instance.clearScoreCache(pazKey);

      if (mounted) Navigator.pop(context, true); // true = dati modificati
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.visita == null ? 'Nuova visita' : 'Modifica visita'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Salva',
                    style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _specialitaCtrl,
              decoration: trDeco(InputDecoration(
                labelText: 'Specialità *',
                hintText: 'es. Cardiologia, Ortopedia...',
              )),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? tr('Campo obbligatorio') : null,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const Icon(Icons.calendar_today, color: AppTheme.primary),
              title: const Text('Data visita'),
              subtitle: Text('${_data.day}/${_data.month}/${_data.year}'),
              onTap: _pickDate,
            ),
            const Divider(),
            const SizedBox(height: 8),
            TextFormField(
              controller: _medicoCtrl,
              decoration: trDeco(InputDecoration(labelText: 'Medico')),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _strutturaCtrl,
              decoration:
                  trDeco(InputDecoration(labelText: 'Struttura / Ospedale')),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _diagnosiCtrl,
              decoration: trDeco(InputDecoration(labelText: 'Diagnosi')),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _terapiaCtrl,
              decoration:
                  trDeco(InputDecoration(labelText: 'Terapia prescritta')),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteCtrl,
              decoration: trDeco(InputDecoration(labelText: 'Note')),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
