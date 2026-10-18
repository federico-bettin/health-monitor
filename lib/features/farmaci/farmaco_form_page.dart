import 'package:flutter/material.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/models/farmaco.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/repositories/repository_provider.dart';
import 'package:uuid/uuid.dart';

class FarmacoFormPage extends StatefulWidget {
  final Farmaco? farmaco;
  const FarmacoFormPage({super.key, this.farmaco});

  @override
  State<FarmacoFormPage> createState() => _FarmacoFormPageState();
}

class _FarmacoFormPageState extends State<FarmacoFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeCtrl;
  late TextEditingController _principioCtrl;
  late TextEditingController _dosaggioCtrl;
  late TextEditingController _frequenzaCtrl;
  late TextEditingController _medicoCtrl;
  late TextEditingController _noteCtrl;
  late bool _attivo;
  DateTime? _dataInizio;
  DateTime? _dataFine;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final f = widget.farmaco;
    _nomeCtrl = TextEditingController(text: f?.nome ?? '');
    _principioCtrl = TextEditingController(text: f?.principioAttivo ?? '');
    _dosaggioCtrl = TextEditingController(text: f?.dosaggio ?? '');
    _frequenzaCtrl = TextEditingController(text: f?.frequenza ?? '');
    _medicoCtrl = TextEditingController(text: f?.medico ?? '');
    _noteCtrl = TextEditingController(text: f?.note ?? '');
    _attivo = f?.attivo ?? true;
    _dataInizio = f?.dataInizio;
    _dataFine = f?.dataFine;
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _principioCtrl.dispose();
    _dosaggioCtrl.dispose();
    _frequenzaCtrl.dispose();
    _medicoCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickData(bool isInizio) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => isInizio ? _dataInizio = picked : _dataFine = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = LocalRepository();
      await repo.init();
      final farmaco = Farmaco(
        id: widget.farmaco?.id ?? const Uuid().v4(),
        nome: _nomeCtrl.text.trim(),
        principioAttivo: _principioCtrl.text.trim().isEmpty ? null : _principioCtrl.text.trim(),
        dosaggio: _dosaggioCtrl.text.trim(),
        frequenza: _frequenzaCtrl.text.trim(),
        medico: _medicoCtrl.text.trim().isEmpty ? null : _medicoCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        attivo: _attivo,
        dataInizio: _dataInizio,
        dataFine: _dataFine,
      );
      await repo.saveFarmaco(farmaco);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatData(DateTime? dt) =>
      dt != null ? '${dt.day}/${dt.month}/${dt.year}' : 'Non impostata';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.farmaco == null ? 'Nuovo farmaco' : 'Modifica farmaco'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Salva', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nomeCtrl,
              decoration: const InputDecoration(labelText: 'Nome farmaco *'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Campo obbligatorio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _principioCtrl,
              decoration: const InputDecoration(labelText: 'Principio attivo'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dosaggioCtrl,
              decoration: const InputDecoration(labelText: 'Dosaggio *', hintText: 'es. 10mg'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Campo obbligatorio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _frequenzaCtrl,
              decoration: const InputDecoration(labelText: 'Frequenza *', hintText: 'es. 1 volta al giorno'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Campo obbligatorio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _medicoCtrl,
              decoration: const InputDecoration(labelText: 'Medico prescrittore'),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Farmaco attivo'),
              subtitle: Text(_attivo ? 'In uso attualmente' : 'Non più in uso'),
              value: _attivo,
              onChanged: (v) => setState(() => _attivo = v),
              activeColor: AppTheme.primary,
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today, color: AppTheme.primary),
              title: const Text('Data inizio'),
              subtitle: Text(_formatData(_dataInizio)),
              onTap: () => _pickData(true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_busy, color: AppTheme.error),
              title: const Text('Data fine'),
              subtitle: Text(_formatData(_dataFine)),
              onTap: () => _pickData(false),
            ),
            const Divider(),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Note'),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
