import 'package:flutter/material.dart' hide Text;
import 'package:salute_bettin/core/i18n.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/models/farmaco.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/repositories/repository_provider.dart';
import 'aderenza_card.dart';
import 'farmaco_ciclo_vita.dart';
import 'scorte_card.dart';
import 'piano_testi.dart';
import 'registra_assunzione.dart';
import 'farmaco_form_page.dart';

class FarmacoDettaglioPage extends StatelessWidget {
  final Farmaco farmaco;
  const FarmacoDettaglioPage({super.key, required this.farmaco});

  String _formatData(DateTime? dt) =>
      dt != null ? '${dt.day}/${dt.month}/${dt.year}' : '—';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(farmaco.nome),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => FarmacoFormPage(farmaco: farmaco)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.error),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge attivo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: farmaco.attivo
                    ? AppTheme.secondary.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                farmaco.attivo ? 'In corso' : 'Storico',
                style: TextStyle(
                  color: farmaco.attivo ? AppTheme.secondary : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _InfoCard(children: [
              _InfoRow(icon: Icons.medication, label: 'Dosaggio', value: farmaco.dosaggio),
              _InfoRow(icon: Icons.schedule, label: 'Frequenza', value: etichettaFrequenza(farmaco)),
              if (farmaco.principioAttivo != null)
                _InfoRow(icon: Icons.science, label: 'Principio attivo', value: farmaco.principioAttivo!),
              if (farmaco.medico != null)
                _InfoRow(icon: Icons.person, label: 'Medico', value: farmaco.medico!),
              _InfoRow(icon: Icons.play_arrow, label: 'Data inizio', value: _formatData(farmaco.dataInizio)),
              _InfoRow(icon: Icons.stop, label: 'Data fine', value: _formatData(farmaco.dataFine)),
              _InfoRow(
                  icon: Icons.notifications_active_outlined,
                  label: 'Promemoria',
                  value: farmaco.promemoriaAttivo ? tr('Attivo') : tr('Non attivo')),
              if ((farmaco.istruzioni ?? '').trim().isNotEmpty)
                _InfoRow(icon: Icons.info_outline, label: 'Istruzioni', value: farmaco.istruzioni!.trim()),
            ]),
            if (farmaco.scorte != null) ...[
              const SizedBox(height: 16),
              ScorteCard(farmacoId: farmaco.id),
            ],
            if (farmaco.promemoriaAttivo &&
                farmaco.frequenzaTipo != FrequenzaFarmaco.alBisogno) ...[
              const SizedBox(height: 4),
              AderenzaCard(farmacoId: farmaco.id),
            ],
            if (farmaco.frequenzaTipo == FrequenzaFarmaco.alBisogno) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_task),
                  label: const Text('Registra assunzione'),
                  onPressed: () async {
                    final ok = await registraAssunzioneManuale(context, farmaco);
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Assunzione registrata')));
                    }
                  },
                ),
              ),
            ],
            if (farmaco.note != null) ...[
              const SizedBox(height: 20),
              Text('Note', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(farmaco.note!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina farmaco'),
        content: Text('Vuoi eliminare "${farmaco.nome}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final repo = LocalRepository();
      await repo.init();
      final archiviato = await eliminaOArchiviaFarmaco(repo, farmaco);
      if (context.mounted) {
        if (archiviato) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Farmaco archiviato: lo storico delle assunzioni resta disponibile'),
          ));
        }
        Navigator.pop(context);
      }
    }
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 12),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondaryLight)),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
