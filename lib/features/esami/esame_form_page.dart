import 'package:flutter/material.dart' hide Text;
import 'package:salute_bettin/core/i18n.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/models/esame.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/services/backup_service.dart';
import 'package:salute_bettin/data/services/settings_service.dart';
import 'package:uuid/uuid.dart';

class EsameFormPage extends StatefulWidget {
  final Esame? esame; // null = nuovo, non null = modifica
  const EsameFormPage({super.key, this.esame});

  @override
  State<EsameFormPage> createState() => _EsameFormPageState();
}

class _EsameFormPageState extends State<EsameFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tipoCtrl;
  late TextEditingController _laboratorioCtrl;
  late TextEditingController _medicoCtrl;
  late TextEditingController _noteCtrl;
  late DateTime _data;
  final List<_ValoreRow> _valori = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.esame;
    _tipoCtrl = TextEditingController(text: e?.tipo ?? '');
    _laboratorioCtrl = TextEditingController(text: e?.laboratorio ?? '');
    _medicoCtrl = TextEditingController(text: e?.medico ?? '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _data = e?.data ?? DateTime.now();
    if (e != null) {
      for (final v in e.valori) {
        _valori.add(_ValoreRow(
          nome: v.nome,
          valore: v.valore,
          unita: v.unita ?? '',
          refMin: v.riferimentoMin ?? '',
          refMax: v.riferimentoMax ?? '',
          fuoriRange: v.fuoriRange,
        ));
      }
    }
  }

  @override
  void dispose() {
    _tipoCtrl.dispose();
    _laboratorioCtrl.dispose();
    _medicoCtrl.dispose();
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
      final esame = Esame(
        id: widget.esame?.id ?? const Uuid().v4(),
        tipo: _tipoCtrl.text.trim(),
        data: _data,
        laboratorio: _laboratorioCtrl.text.trim().isEmpty
            ? null
            : _laboratorioCtrl.text.trim(),
        medico: _medicoCtrl.text.trim().isEmpty
            ? null
            : _medicoCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        valori: _valori
            .map((v) => ValoreEsame(
                  nome: v.nome,
                  valore: v.valore,
                  unita: v.unita.isEmpty ? null : v.unita,
                  riferimentoMin: v.refMin.isEmpty ? null : v.refMin,
                  riferimentoMax: v.refMax.isEmpty ? null : v.refMax,
                  fuoriRange: v.fuoriRange,
                ))
            .toList(),
      );
      await repo.saveEsame(esame);

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
        title: Text(widget.esame == null ? 'Nuovo esame' : 'Modifica esame'),
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
            // Tipo esame
            TextFormField(
              controller: _tipoCtrl,
              decoration: trDeco(InputDecoration(
                labelText: 'Tipo esame *',
                hintText: 'es. Emocromo, Lipidemia, TSH...',
              )),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? tr('Campo obbligatorio') : null,
            ),
            const SizedBox(height: 16),

            // Data
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today,
                  color: AppTheme.primary),
              title: const Text('Data esame'),
              subtitle: Text(
                  '${_data.day}/${_data.month}/${_data.year}'),
              onTap: _pickDate,
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Laboratorio
            TextFormField(
              controller: _laboratorioCtrl,
              decoration: trDeco(InputDecoration(
                  labelText: 'Laboratorio / Struttura')),
            ),
            const SizedBox(height: 16),

            // Medico
            TextFormField(
              controller: _medicoCtrl,
              decoration:
                  trDeco(InputDecoration(labelText: 'Medico richiedente')),
            ),
            const SizedBox(height: 16),

            // Note
            TextFormField(
              controller: _noteCtrl,
              decoration: trDeco(InputDecoration(labelText: 'Note')),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Valori
            Row(children: [
              Text('Valori',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Aggiungi'),
                onPressed: () => setState(() => _valori.add(_ValoreRow())),
              ),
            ]),

            ..._valori.asMap().entries.map((entry) {
              final i = entry.key;
              final v = entry.value;
              return _ValoreCard(
                key: ValueKey(i),
                row: v,
                onDelete: () => setState(() => _valori.removeAt(i)),
                onChanged: () => setState(() {}),
              );
            }),

            if (_valori.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.borderDark,
                        style: BorderStyle.solid)),
                child: const Row(children: [
                  Icon(Icons.info_outline,
                      size: 16, color: AppTheme.textSecondaryDark),
                  SizedBox(width: 8),
                  Text('Nessun valore aggiunto',
                      style: TextStyle(
                          color: AppTheme.textSecondaryDark,
                          fontSize: 13)),
                ]),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Riga valore ──────────────────────────────────────────────
class _ValoreRow {
  String nome;
  String valore;
  String unita;
  String refMin;
  String refMax;
  bool fuoriRange;

  _ValoreRow({
    this.nome = '',
    this.valore = '',
    this.unita = '',
    this.refMin = '',
    this.refMax = '',
    this.fuoriRange = false,
  });
}

class _ValoreCard extends StatefulWidget {
  final _ValoreRow row;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  const _ValoreCard(
      {super.key,
      required this.row,
      required this.onDelete,
      required this.onChanged});

  @override
  State<_ValoreCard> createState() => _ValoreCardState();
}

class _ValoreCardState extends State<_ValoreCard> {
  late TextEditingController _nomeCtrl, _valoreCtrl, _unitaCtrl,
      _refMinCtrl, _refMaxCtrl;

  @override
  void initState() {
    super.initState();
    final r = widget.row;
    _nomeCtrl = TextEditingController(text: r.nome)
      ..addListener(() {
        widget.row.nome = _nomeCtrl.text;
        widget.onChanged();
      });
    _valoreCtrl = TextEditingController(text: r.valore)
      ..addListener(() {
        widget.row.valore = _valoreCtrl.text;
        widget.onChanged();
      });
    _unitaCtrl = TextEditingController(text: r.unita)
      ..addListener(() {
        widget.row.unita = _unitaCtrl.text;
      });
    _refMinCtrl = TextEditingController(text: r.refMin)
      ..addListener(() {
        widget.row.refMin = _refMinCtrl.text;
      });
    _refMaxCtrl = TextEditingController(text: r.refMax)
      ..addListener(() {
        widget.row.refMax = _refMaxCtrl.text;
      });
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _valoreCtrl.dispose();
    _unitaCtrl.dispose();
    _refMinCtrl.dispose();
    _refMaxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderDark)),
      child: Column(children: [
        Row(children: [
          Expanded(
              flex: 3,
              child: TextFormField(
                controller: _nomeCtrl,
                decoration: trDeco(InputDecoration(
                    labelText: 'Nome valore *', isDense: true)),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? tr('Obbligatorio') : null,
              )),
          const SizedBox(width: 8),
          Expanded(
              flex: 2,
              child: TextFormField(
                controller: _valoreCtrl,
                decoration: trDeco(InputDecoration(
                    labelText: 'Valore *', isDense: true)),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? tr('Obbligatorio') : null,
              )),
          const SizedBox(width: 8),
          Expanded(
              flex: 1,
              child: TextFormField(
                controller: _unitaCtrl,
                decoration: trDeco(InputDecoration(
                    labelText: 'Unità', isDense: true)),
              )),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: AppTheme.error, size: 20),
            onPressed: widget.onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: TextFormField(
            controller: _refMinCtrl,
            decoration: trDeco(InputDecoration(
                labelText: 'Ref. min', isDense: true)),
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
          )),
          const SizedBox(width: 8),
          Expanded(
              child: TextFormField(
            controller: _refMaxCtrl,
            decoration: trDeco(InputDecoration(
                labelText: 'Ref. max', isDense: true)),
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
          )),
          const SizedBox(width: 8),
          Row(children: [
            const Text('Fuori range',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textSecondaryDark)),
            Switch(
              value: widget.row.fuoriRange,
              onChanged: (v) =>
                  setState(() => widget.row.fuoriRange = v),
              activeColor: AppTheme.error,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ]),
        ]),
      ]),
    );
  }
}
