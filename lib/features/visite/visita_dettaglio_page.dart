import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/models/visita.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/repositories/repository_provider.dart';
import 'visita_form_page.dart';

class VisitaDettaglioPage extends StatelessWidget {
  final Visita visita;
  const VisitaDettaglioPage({super.key, required this.visita});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(visita.specialita),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => VisitaFormPage(visita: visita)),
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
            _InfoCard(children: [
              _InfoRow(icon: Icons.calendar_today, label: 'Data',
                  value: '${visita.data.day}/${visita.data.month}/${visita.data.year}'),
              if (visita.medico != null)
                _InfoRow(icon: Icons.person, label: 'Medico', value: visita.medico!),
              if (visita.struttura != null)
                _InfoRow(icon: Icons.business, label: 'Struttura', value: visita.struttura!),
            ]),
            if (visita.diagnosi != null) ...[
              const SizedBox(height: 20),
              Text('Diagnosi', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              _TextBox(text: visita.diagnosi!),
            ],
            if (visita.terapia != null) ...[
              const SizedBox(height: 20),
              Text('Terapia', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              _TextBox(text: visita.terapia!),
            ],
            if (visita.note != null) ...[
              const SizedBox(height: 20),
              Text('Note', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              _TextBox(text: visita.note!),
            ],
            if (visita.allegato != null) ...[
              const SizedBox(height: 20),
              SizedBox(width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final result = await OpenFile.open(visita.allegato!);
                    if (result.type != ResultType.done && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Impossibile aprire: ${result.message}')));
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Vedi documento originale'),
                )),
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
        title: const Text('Elimina visita'),
        content: Text('Vuoi eliminare "${visita.specialita}"?'),
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
      await repo.deleteVisita(visita.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class _TextBox extends StatelessWidget {
  final String text;
  const _TextBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text),
    );
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
