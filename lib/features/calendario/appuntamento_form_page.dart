import 'package:flutter/material.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/models/appuntamento.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/services/notification_service.dart';
import 'package:uuid/uuid.dart';

class AppuntamentoFormPage extends StatefulWidget {
  final Appuntamento? appuntamento;
  const AppuntamentoFormPage({super.key, this.appuntamento});

  @override
  State<AppuntamentoFormPage> createState() => _AppuntamentoFormPageState();
}

class _AppuntamentoFormPageState extends State<AppuntamentoFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titoloCtrl;
  late TextEditingController _oraCtrl;
  late TextEditingController _medicoCtrl;
  late TextEditingController _strutturaCtrl;
  late TextEditingController _indirizzoCtrl;
  late TextEditingController _noteCtrl;
  late TextEditingController _costoCtrl;
  late DateTime _data;
  late TipoAppuntamento _tipo;
  late bool _promemoria;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.appuntamento;
    _titoloCtrl = TextEditingController(text: a?.titolo ?? '');
    _oraCtrl = TextEditingController(text: a?.ora ?? '');
    _medicoCtrl = TextEditingController(text: a?.medico ?? '');
    _strutturaCtrl = TextEditingController(text: a?.struttura ?? '');
    _indirizzoCtrl = TextEditingController(text: a?.indirizzo ?? '');
    _noteCtrl = TextEditingController(text: a?.note ?? '');
    _costoCtrl = TextEditingController(
        text: a?.costo == null ? '' : a!.costo!.toStringAsFixed(2));
    _data = a?.data ?? DateTime.now();
    _tipo = a?.tipo ?? TipoAppuntamento.visita;
    _promemoria = a?.promemoria ?? true;
  }

  @override
  void dispose() {
    _titoloCtrl.dispose();
    _oraCtrl.dispose();
    _medicoCtrl.dispose();
    _strutturaCtrl.dispose();
    _indirizzoCtrl.dispose();
    _noteCtrl.dispose();
    _costoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _data = picked);
  }

  static double? _parseCosto(String s) {
    final t = s.trim().replaceAll(',', '.');
    return t.isEmpty ? null : double.tryParse(t);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = LocalRepository();
      await repo.init();
      final a = Appuntamento(
        id: widget.appuntamento?.id ?? const Uuid().v4(),
        titolo: _titoloCtrl.text.trim(),
        data: _data,
        ora: _oraCtrl.text.trim().isEmpty ? null : _oraCtrl.text.trim(),
        tipo: _tipo,
        medico: _medicoCtrl.text.trim().isEmpty ? null : _medicoCtrl.text.trim(),
        struttura: _strutturaCtrl.text.trim().isEmpty ? null : _strutturaCtrl.text.trim(),
        indirizzo: _indirizzoCtrl.text.trim().isEmpty ? null : _indirizzoCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        promemoria: _promemoria,
        completato: widget.appuntamento?.completato ?? false,
        costo: _parseCosto(_costoCtrl.text),
      );
      await repo.saveAppuntamento(a);
      // Promemoria: richiede il permesso (una volta) e programma la notifica
      await NotificationService.instance.richiediPermesso();
      await NotificationService.instance.pianifica(a);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appuntamento == null ? 'Nuovo appuntamento' : 'Modifica appuntamento'),
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
              controller: _titoloCtrl,
              decoration: const InputDecoration(labelText: 'Titolo *', hintText: 'es. Visita cardiologo'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Campo obbligatorio' : null,
            ),
            const SizedBox(height: 16),
            // Tipo
            DropdownButtonFormField<TipoAppuntamento>(
              value: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(value: TipoAppuntamento.visita, child: Text('Visita')),
                DropdownMenuItem(value: TipoAppuntamento.esame, child: Text('Esame')),
                DropdownMenuItem(value: TipoAppuntamento.farmaco, child: Text('Farmaco')),
                DropdownMenuItem(value: TipoAppuntamento.altro, child: Text('Altro')),
              ],
              onChanged: (v) => setState(() => _tipo = v!),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today, color: AppTheme.primary),
              title: const Text('Data'),
              subtitle: Text('${_data.day}/${_data.month}/${_data.year}'),
              onTap: _pickDate,
            ),
            const Divider(),
            TextFormField(
              controller: _oraCtrl,
              decoration: const InputDecoration(labelText: 'Ora', hintText: 'es. 10:30'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _medicoCtrl,
              decoration: const InputDecoration(labelText: 'Medico'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _strutturaCtrl,
              decoration: const InputDecoration(labelText: 'Struttura / Ospedale'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _indirizzoCtrl,
              decoration: const InputDecoration(labelText: 'Indirizzo'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _costoCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Costo (€)',
                helperText: 'Se indicato, la visita/esame conta nelle statistiche',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final x = _parseCosto(v);
                return (x == null || x < 0) ? 'Importo non valido' : null;
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Promemoria'),
              subtitle: const Text('Notifica prima di visite ed esami (vedi Impostazioni)'),
              value: _promemoria,
              onChanged: (v) => setState(() => _promemoria = v),
              activeColor: AppTheme.primary,
            ),
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
