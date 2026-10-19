import 'package:flutter/material.dart' hide Text;
import 'package:salute_bettin/core/i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/models/appuntamento.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'appuntamento_form_page.dart';
import 'package:salute_bettin/core/format.dart';
import 'package:salute_bettin/data/services/notification_service.dart';

final appuntamentiProvider = FutureProvider<List<Appuntamento>>((ref) async {
  final repo = LocalRepository();
  await repo.init();
  final list = await repo.getAppuntamenti();
  list.sort((a, b) => a.data.compareTo(b.data));
  return list;
});

class CalendarioPage extends ConsumerStatefulWidget {
  const CalendarioPage({super.key});

  @override
  ConsumerState<CalendarioPage> createState() => _CalendarioPageState();
}

class _CalendarioPageState extends ConsumerState<CalendarioPage> {
  DateTime _meseCorrente = DateTime.now();

  static const mesi = [
    'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
    'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
  ];

  @override
  Widget build(BuildContext context) {
    final appuntamentiAsync = ref.watch(appuntamentiProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AppuntamentoFormPage()),
          );
          ref.invalidate(appuntamentiProvider);
        },
        backgroundColor: const Color(0xFF9C27B0),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: appuntamentiAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (appuntamenti) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() => _meseCorrente =
                        DateTime(_meseCorrente.year, _meseCorrente.month - 1)),
                  ),
                  Expanded(
                    child: Text(
                      '${tr(mesi[_meseCorrente.month - 1])} ${_meseCorrente.year}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() => _meseCorrente =
                        DateTime(_meseCorrente.year, _meseCorrente.month + 1)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _buildLista(context, appuntamenti
                  .where((a) =>
                      a.data.year == _meseCorrente.year &&
                      a.data.month == _meseCorrente.month)
                  .toList(),
                  appuntamenti),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLista(BuildContext context, List<Appuntamento> appuntamenti,
      List<Appuntamento> tutti) {
    if (appuntamenti.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available,
                size: 64, color: Colors.grey.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('Nessun appuntamento questo mese',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.textSecondaryLight)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: appuntamenti.length,
      itemBuilder: (context, i) {
        final a = appuntamenti[i];
        return _AppuntamentoCard(
          appuntamento: a,
          onEdit: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AppuntamentoFormPage(appuntamento: a)),
            );
            ref.invalidate(appuntamentiProvider);
          },
          onDelete: () async {
            final repo = LocalRepository();
  await repo.init();
            await repo.deleteAppuntamento(a.id);
            await NotificationService.instance.annulla(a.id);
            ref.invalidate(appuntamentiProvider);
          },
        );
      },
    );
  }
}

class _AppuntamentoCard extends StatelessWidget {
  final Appuntamento appuntamento;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AppuntamentoCard({
    required this.appuntamento,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _colore => switch (appuntamento.tipo) {
        TipoAppuntamento.visita => const Color(0xFF2196F3),
        TipoAppuntamento.esame => const Color(0xFF4CAF50),
        TipoAppuntamento.farmaco => const Color(0xFFFF9800),
        TipoAppuntamento.altro => const Color(0xFF9C27B0),
      };

  IconData get _icona => switch (appuntamento.tipo) {
        TipoAppuntamento.visita => Icons.local_hospital,
        TipoAppuntamento.esame => Icons.science,
        TipoAppuntamento.farmaco => Icons.medication,
        TipoAppuntamento.altro => Icons.event,
      };

  @override
  Widget build(BuildContext context) {
    final isPassato = appuntamento.isPassato;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _colore.withOpacity(isPassato ? 0.08 : 0.15),
          child: Icon(_icona, color: isPassato ? Colors.grey : _colore),
        ),
        title: Text(appuntamento.titolo,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isPassato ? AppTheme.textSecondaryLight : null,
                )),
        subtitle: Text(
          '${appuntamento.data.day}/${appuntamento.data.month}/${appuntamento.data.year}'
          '${appuntamento.ora != null ? ' · ${appuntamento.ora}' : ''}'
          '${appuntamento.struttura != null ? '\n${appuntamento.struttura}' : ''}'
          '${appuntamento.costo != null ? '\n${formatEuro(appuntamento.costo!)}' : ''}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        isThreeLine:
            appuntamento.struttura != null || appuntamento.costo != null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit),
            IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: AppTheme.error),
                onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}
