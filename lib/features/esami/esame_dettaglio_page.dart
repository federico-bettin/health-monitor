import 'package:flutter/material.dart' hide Text;
import 'package:salute_bettin/core/i18n.dart';
import 'package:open_file/open_file.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/models/esame.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/repositories/repository_provider.dart';
import 'esame_form_page.dart';

class EsameDettaglioPage extends StatelessWidget {
  final Esame esame;
  const EsameDettaglioPage({super.key, required this.esame});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(esame.tipo),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => EsameFormPage(esame: esame)),
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
            // Info generali
            _InfoCard(
              children: [
                _InfoRow(
                  icon: Icons.calendar_today,
                  label: 'Data',
                  value:
                      '${esame.data.day}/${esame.data.month}/${esame.data.year}',
                ),
                if (esame.laboratorio != null)
                  _InfoRow(
                    icon: Icons.business,
                    label: 'Laboratorio',
                    value: esame.laboratorio!,
                  ),
                if (esame.medico != null)
                  _InfoRow(
                    icon: Icons.person,
                    label: 'Medico',
                    value: esame.medico!,
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Valori
            if (esame.valori.isNotEmpty) ...[
              Text('Valori',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              ...esame.valori.map((v) => _ValoreCard(valore: v)),
            ],

            // Note
            if (esame.note != null) ...[
              const SizedBox(height: 20),
              Text('Note',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(esame.note!),
              ),
            ],

            // Documento originale
            if (esame.allegato != null) ...[
              const SizedBox(height: 20),
              SizedBox(width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final result = await OpenFile.open(esame.allegato!);
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
        title: const Text('Elimina esame'),
        content: Text('Vuoi eliminare "${esame.tipo}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final repo = LocalRepository();
      await repo.init();
      await repo.deleteEsame(esame.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class _ValoreCard extends StatelessWidget {
  final ValoreEsame valore;
  const _ValoreCard({required this.valore});

  @override
  Widget build(BuildContext context) {
    final fuori = valore.fuoriRange;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fuori
            ? AppTheme.error.withOpacity(0.05)
            : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: fuori
              ? AppTheme.error.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(valore.nome,
                    style: Theme.of(context).textTheme.titleMedium),
                if (valore.riferimentoMin != null ||
                    valore.riferimentoMax != null)
                  Text(
                    'Rif: ${valore.riferimentoMin ?? '?'} – ${valore.riferimentoMax ?? '?'} ${valore.unita ?? ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryLight,
                        ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${valore.valore} ${valore.unita ?? ''}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: fuori ? AppTheme.error : null,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (fuori)
                Text('Fuori range',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.error)),
            ],
          ),
        ],
      ),
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
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 12),
          Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryLight,
                  )),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
