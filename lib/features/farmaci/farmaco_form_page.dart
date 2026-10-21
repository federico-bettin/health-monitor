import 'package:flutter/material.dart' hide Text;
import 'package:salute_bettin/core/i18n.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/models/farmaco.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/services/farmaci_reminder_service.dart';
import 'package:salute_bettin/features/farmaci/permessi_dialog.dart';
import 'package:salute_bettin/features/farmaci/piano_testi.dart';
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
  late TextEditingController _medicoCtrl;
  late TextEditingController _noteCtrl;
  late TextEditingController _istruzioniCtrl;
  late TextEditingController _ogniNCtrl;
  late bool _attivo;
  late bool _promemoria;
  late FrequenzaFarmaco _freq;
  late List<String> _orari;
  late Set<int> _giorni;
  DateTime? _dataInizio;
  DateTime? _dataFine;
  bool _saving = false;
  bool _avvisoRitardo = false;

  @override
  void initState() {
    super.initState();
    final f = widget.farmaco;
    _nomeCtrl = TextEditingController(text: f?.nome ?? '');
    _principioCtrl = TextEditingController(text: f?.principioAttivo ?? '');
    _dosaggioCtrl = TextEditingController(text: f?.dosaggio ?? '');
    _medicoCtrl = TextEditingController(text: f?.medico ?? '');
    _noteCtrl = TextEditingController(text: f?.note ?? '');
    _istruzioniCtrl = TextEditingController(text: f?.istruzioni ?? '');
    _ogniNCtrl = TextEditingController(text: f?.ogniNGiorni?.toString() ?? '');
    _attivo = f?.attivo ?? true;
    _promemoria = f?.promemoriaAttivo ?? false;
    _freq = f?.frequenzaTipo ?? FrequenzaFarmaco.giornaliera;
    _orari = orariValidi(f?.orariAssunzione ?? const []);
    _giorni = {...?f?.giorniSettimana};
    _dataInizio = f?.dataInizio;
    _dataFine = f?.dataFine;
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _principioCtrl.dispose();
    _dosaggioCtrl.dispose();
    _medicoCtrl.dispose();
    _noteCtrl.dispose();
    _istruzioniCtrl.dispose();
    _ogniNCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickData(bool isInizio) async {
    final iniziale = (isInizio ? _dataInizio : _dataFine) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: iniziale,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => isInizio ? _dataInizio = picked : _dataFine = picked);
    }
  }

  Future<void> _aggiungiOrario() async {
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t == null) return;
    setState(() {
      _orari = orariValidi([..._orari, hhmm(t.hour, t.minute)]);
    });
  }

  Future<void> _onPromemoria(bool v) async {
    if (v) {
      final p = await assicuraPermessiPromemoria(context);
      if (!mounted) return;
      setState(() => _avvisoRitardo = p.allarmiEsatti == false);
    }
    setState(() => _promemoria = v);
  }

  /// Controlli sul piano. Ritorna il messaggio di errore o null.
  String? _validaPiano() {
    final conPiano = _freq != FrequenzaFarmaco.alBisogno;
    if (_dataInizio != null &&
        _dataFine != null &&
        _dataFine!.isBefore(_dataInizio!)) {
      return tr('La data di fine è precedente a quella di inizio');
    }
    if (_freq == FrequenzaFarmaco.ogniNGiorni) {
      final n = int.tryParse(_ogniNCtrl.text.trim());
      if (n == null || n < 1) return tr('Indica ogni quanti giorni (almeno 1)');
      if (_promemoria && _dataInizio == null) {
        return tr('Per "ogni N giorni" serve la data di inizio');
      }
    }
    if (_promemoria && conPiano) {
      if (_orari.isEmpty) return tr('Aggiungi almeno un orario');
      if (_freq == FrequenzaFarmaco.giorniSettimana && _giorni.isEmpty) {
        return tr('Scegli almeno un giorno della settimana');
      }
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final errore = _validaPiano();
    if (errore != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errore)));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = LocalRepository();
      await repo.init();
      final alBisogno = _freq == FrequenzaFarmaco.alBisogno;
      final farmaco = Farmaco(
        id: widget.farmaco?.id ?? const Uuid().v4(),
        nome: _nomeCtrl.text.trim(),
        principioAttivo:
            _principioCtrl.text.trim().isEmpty ? null : _principioCtrl.text.trim(),
        dosaggio: _dosaggioCtrl.text.trim(),
        frequenza: widget.farmaco?.frequenza ?? '',
        medico: _medicoCtrl.text.trim().isEmpty ? null : _medicoCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        attivo: _attivo,
        dataInizio: _dataInizio,
        dataFine: _dataFine,
        orariAssunzione: alBisogno ? [] : _orari,
        frequenzaTipoIdx: _freq.index,
        giorniSettimana: _freq == FrequenzaFarmaco.giorniSettimana
            ? (_giorni.toList()..sort())
            : [],
        ogniNGiorni: _freq == FrequenzaFarmaco.ogniNGiorni
            ? int.tryParse(_ogniNCtrl.text.trim())
            : null,
        promemoriaAttivo: _promemoria && !alBisogno,
        istruzioni: _istruzioniCtrl.text.trim().isEmpty
            ? null
            : _istruzioniCtrl.text.trim(),
        archiviato: widget.farmaco?.archiviato ?? false,
      );
      // Testo di frequenza sempre in italiano: resta leggibile in backup e Drive
      farmaco.frequenza = etichettaFrequenza(farmaco, localizzato: false);
      await repo.saveFarmaco(farmaco); // ricostruisce anche le notifiche
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatData(DateTime? dt) => dt != null
      ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
      : tr('Non impostata');

  String _nomeFreq(FrequenzaFarmaco f) => switch (f) {
        FrequenzaFarmaco.giornaliera => tr('Ogni giorno'),
        FrequenzaFarmaco.giorniSettimana => tr('Giorni della settimana'),
        FrequenzaFarmaco.ogniNGiorni => tr('Ogni N giorni'),
        FrequenzaFarmaco.alBisogno => tr('Al bisogno'),
      };

  @override
  Widget build(BuildContext context) {
    final alBisogno = _freq == FrequenzaFarmaco.alBisogno;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.farmaco == null ? 'Nuovo farmaco' : 'Modifica farmaco'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
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
              decoration: trDeco(InputDecoration(labelText: 'Nome farmaco *')),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? tr('Campo obbligatorio') : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _principioCtrl,
              decoration: trDeco(InputDecoration(labelText: 'Principio attivo')),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dosaggioCtrl,
              decoration: trDeco(InputDecoration(
                  labelText: 'Dose *', hintText: 'es. 1 compressa, 500 mg')),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? tr('Campo obbligatorio') : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _medicoCtrl,
              decoration: trDeco(InputDecoration(labelText: 'Medico prescrittore')),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _istruzioniCtrl,
              decoration: trDeco(InputDecoration(
                  labelText: 'Istruzioni', hintText: 'es. a stomaco pieno')),
            ),
            const SizedBox(height: 20),

            // ─── Piano terapeutico ───────────────────────────
            Text('Piano terapeutico',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.primary, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            DropdownButtonFormField<FrequenzaFarmaco>(
              value: _freq,
              decoration: trDeco(InputDecoration(labelText: 'Frequenza')),
              items: [
                for (final f in FrequenzaFarmaco.values)
                  DropdownMenuItem(value: f, child: Text(_nomeFreq(f))),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _freq = v;
                  if (v == FrequenzaFarmaco.alBisogno) _promemoria = false;
                });
              },
            ),
            if (_freq == FrequenzaFarmaco.giorniSettimana) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text(nomeGiorno(d)),
                      selected: _giorni.contains(d),
                      onSelected: (s) => setState(
                          () => s ? _giorni.add(d) : _giorni.remove(d)),
                    ),
                ],
              ),
            ],
            if (_freq == FrequenzaFarmaco.ogniNGiorni) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _ogniNCtrl,
                keyboardType: TextInputType.number,
                decoration: trDeco(InputDecoration(
                    labelText: 'Ogni quanti giorni', hintText: 'es. 3')),
              ),
              const SizedBox(height: 4),
              const Text(
                  "Si conta a partire dalla data di inizio (obbligatoria con il promemoria).",
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark)),
            ],
            if (!alBisogno) ...[
              const SizedBox(height: 16),
              Row(children: [
                const Expanded(
                    child: Text('Orari',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                TextButton.icon(
                  onPressed: _aggiungiOrario,
                  icon: const Icon(Icons.add_alarm, size: 18),
                  label: const Text('Aggiungi orario'),
                ),
              ]),
              if (_orari.isEmpty)
                const Text('Nessun orario',
                    style: TextStyle(color: AppTheme.textSecondaryDark))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final o in _orari)
                      InputChip(
                        label: Text(o),
                        onDeleted: () => setState(() => _orari.remove(o)),
                      ),
                  ],
                ),
            ],
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today, color: AppTheme.primary),
              title: const Text('Data inizio'),
              subtitle: Text(_formatData(_dataInizio)),
              trailing: _dataInizio == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _dataInizio = null)),
              onTap: () => _pickData(true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_busy, color: AppTheme.error),
              title: const Text('Data fine'),
              subtitle: Text(_dataFine == null
                  ? tr('Nessuna (terapia cronica)')
                  : _formatData(_dataFine)),
              trailing: _dataFine == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _dataFine = null)),
              onTap: () => _pickData(false),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('Promemoria con notifica'),
              subtitle: Text(alBisogno
                  ? tr('Non disponibile per i farmaci al bisogno')
                  : tr('Ti avvisa agli orari indicati')),
              value: _promemoria && !alBisogno,
              onChanged: alBisogno ? null : _onPromemoria,
              activeColor: AppTheme.primary,
            ),
            if (_avvisoRitardo && _promemoria)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  const Icon(Icons.info_outline, size: 16, color: AppTheme.warning),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                        'Le notifiche potrebbero arrivare con qualche minuto di ritardo.',
                        style: TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () =>
                        FarmaciReminderService.instance.richiediAllarmiEsatti(),
                    child: const Text('Consenti allarmi esatti'),
                  ),
                ]),
              ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Farmaco attivo'),
              subtitle: Text(_attivo ? 'In uso attualmente' : 'Non più in uso'),
              value: _attivo,
              onChanged: (v) => setState(() => _attivo = v),
              activeColor: AppTheme.primary,
            ),
            const SizedBox(height: 8),
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
