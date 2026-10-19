import 'dart:io';
import 'package:flutter/material.dart' hide Text;
import 'package:salute_bettin/core/i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:salute_bettin/core/router.dart';
import 'package:salute_bettin/core/theme.dart';
import 'package:salute_bettin/data/models/paziente.dart';
import 'package:salute_bettin/data/repositories/local_repository.dart';
import 'package:salute_bettin/data/services/backup_service.dart';
import 'package:salute_bettin/data/services/health_service.dart';
import 'package:salute_bettin/data/services/settings_service.dart';

final pazienteProvider = FutureProvider<Paziente?>((ref) async {
  final repo = LocalRepository();
  await repo.init();
  return repo.getPaziente();
});

// Solo peso bilancia da Health Connect — leggero, non blocca il profilo
final wearableProfiloProvider = FutureProvider<({double? peso})>((ref) async {
  try {
    final svc  = HealthService();
    final dati = await svc.leggiDatiRecenti();
    return (peso: dati.peso);
  } catch (_) {
    return (peso: null);
  }
});

class ProfiloPage extends ConsumerWidget {
  const ProfiloPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pazienteAsync = ref.watch(pazienteProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go(AppRoutes.dashboard);
            }
          },
        ),
      ),
      body: pazienteAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (paziente) => paziente == null
            ? _NessunProfilo(onCrea: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfiloFormPage()));
                ref.invalidate(pazienteProvider);
              })
            : _ProfiloDettaglio(paziente: paziente, onModifica: () async {
                await Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => ProfiloFormPage(paziente: paziente)));
                ref.invalidate(pazienteProvider);
              }),
      ),
    );
  }
}

class _NessunProfilo extends StatelessWidget {
  final VoidCallback onCrea;
  const _NessunProfilo({required this.onCrea});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.person_outline,
            size: 80, color: AppTheme.textSecondaryDark.withOpacity(0.4)),
        const SizedBox(height: 16),
        const Text('Nessun profilo creato'),
        const SizedBox(height: 24),
        ElevatedButton.icon(
            onPressed: onCrea,
            icon: const Icon(Icons.add),
            label: const Text('Crea profilo')),
      ]),
    );
  }
}

class _ProfiloDettaglio extends ConsumerWidget {
  final Paziente paziente;
  final VoidCallback onModifica;
  const _ProfiloDettaglio(
      {required this.paziente, required this.onModifica});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Legge peso bilancia da wearable (ref.read — non crea dipendenza di rebuild)
    final wearableAsync = ref.watch(wearableProfiloProvider);
    final pesoBilancia  = wearableAsync.valueOrNull?.peso;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _AvatarFoto(paziente: paziente, onModifica: onModifica),

        // BMI card
        if (paziente.bmi != null || (paziente.peso != null && paziente.altezza != null)) ...[
          _BmiCard(paziente: paziente, pesoBilancia: pesoBilancia),
          const SizedBox(height: 16),
        ],

        // Info generali
        _InfoCard(children: [
          if (paziente.dataNascita != null)
            _InfoRow(
                icon: Icons.cake,
                label: 'Nascita',
                value:
                    '${paziente.dataNascita!.day}/${paziente.dataNascita!.month}/${paziente.dataNascita!.year}'),
          if (paziente.gruppaSanguigno != null)
            _InfoRow(
                icon: Icons.water_drop,
                label: 'Gruppo',
                value: paziente.gruppaSanguigno!),
          if (paziente.peso != null)
            _InfoRow(
                icon: Icons.monitor_weight,
                label: 'Peso',
                value: '${paziente.peso!.toStringAsFixed(1)} kg'),
          if (paziente.altezza != null)
            _InfoRow(
                icon: Icons.height,
                label: 'Altezza',
                value: '${paziente.altezza!.toStringAsFixed(0)} cm'),
          if (paziente.codiceFiscale != null)
            _InfoRow(
                icon: Icons.badge,
                label: 'CF',
                value: paziente.codiceFiscale!),
          if (paziente.medico != null)
            _InfoRow(
                icon: Icons.person,
                label: 'Medico',
                value: paziente.medico!),
          if (paziente.telefono != null)
            _InfoRow(
                icon: Icons.phone,
                label: 'Tel',
                value: paziente.telefono!),
          if (paziente.email != null)
            _InfoRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: paziente.email!),
        ]),

        // ─── Stile di vita ────────────────────────────────
        const SizedBox(height: 16),
        _StileVitaCard(paziente: paziente),

        // ─── Dispositivi wearable ─────────────────────────
        const SizedBox(height: 16),
        _WearableCard(paziente: paziente),

        if (paziente.allergie.isNotEmpty) ...[
          const SizedBox(height: 16),
          _ChipSection(
              title: 'Allergie',
              items: paziente.allergie,
              color: AppTheme.error),
        ],
        if (paziente.patologieCroniche.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ChipSection(
              title: 'Patologie croniche',
              items: paziente.patologieCroniche,
              color: AppTheme.warning),
        ],

        if (paziente.anamnesi != null && paziente.anamnesi!.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withOpacity(0.2))),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.history_edu,
                        size: 16, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    const Text('Anamnesi personale',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                            fontSize: 13)),
                  ]),
                  const SizedBox(height: 8),
                  Text(paziente.anamnesi!),
                ])),
        ],

        const SizedBox(height: 24),
        OutlinedButton.icon(
            onPressed: onModifica,
            icon: const Icon(Icons.edit),
            label: const Text('Modifica profilo')),
      ]),
    );
  }
}

// ─── Avatar con foto ──────────────────────────────────────────
class _AvatarFoto extends StatelessWidget {
  final Paziente paziente;
  final VoidCallback onModifica;
  const _AvatarFoto({required this.paziente, required this.onModifica});

  @override
  Widget build(BuildContext context) {
    final fotoPath = SettingsService.instance.fotoProfilo;
    final fotoFile = fotoPath != null ? File(fotoPath) : null;
    final haFoto   = fotoFile != null && fotoFile.existsSync();

    return Column(children: [
      GestureDetector(
        onTap: onModifica,
        child: Stack(alignment: Alignment.bottomRight, children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: AppTheme.primary.withOpacity(0.15),
            backgroundImage: haFoto ? FileImage(fotoFile!) : null,
            child: haFoto ? null : Text(
              '${paziente.nome[0]}${paziente.cognome[0]}',
              style: Theme.of(context).textTheme.displayMedium
                  ?.copyWith(color: AppTheme.primary)),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppTheme.primary, shape: BoxShape.circle),
            padding: const EdgeInsets.all(4),
            child: const Icon(Icons.edit, size: 14, color: Colors.white),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Text(paziente.nomeCompleto,
          style: Theme.of(context).textTheme.headlineMedium),
      if (paziente.eta != null)
        Text('${paziente.eta} anni',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppTheme.textSecondaryDark)),
      const SizedBox(height: 24),
    ]);
  }
}

// ─── Card dispositivi wearable (dettaglio) ───────────────────
class _WearableCard extends StatelessWidget {
  final Paziente paziente;
  const _WearableCard({required this.paziente});

  @override
  Widget build(BuildContext context) {
    final key = BackupService.slotKey(paziente.nome, paziente.cognome);
    final s = SettingsService.instance;
    final bilancia = s.usaBilancia(key);
    final ring = s.usaRing(key);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDark)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.watch, size: 16, color: AppTheme.secondary),
          const SizedBox(width: 8),
          Text('Dispositivi wearable',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: AppTheme.secondary)),
        ]),
        const SizedBox(height: 12),
        _StileRow(
          icon: Icons.monitor_weight_outlined,
          label: 'Bilancia Amazfit',
          iconColor: bilancia ? AppTheme.primary : AppTheme.textSecondaryDark,
          value: bilancia ? 'Configurata' : 'Non usata',
          valueColor: bilancia ? AppTheme.secondary : AppTheme.textSecondaryDark,
        ),
        const Divider(height: 16),
        _StileRow(
          icon: Icons.watch_outlined,
          label: 'Ring Amazfit',
          iconColor: ring ? AppTheme.primary : AppTheme.textSecondaryDark,
          value: ring ? 'Configurato' : 'Non usato',
          valueColor: ring ? AppTheme.secondary : AppTheme.textSecondaryDark,
        ),
        if (!bilancia && !ring) ...[
          const SizedBox(height: 8),
          Text('Nessun dispositivo configurato — la sezione Wearable '
              'non apparirà nella dashboard.',
              style: TextStyle(fontSize: 11,
                  color: AppTheme.textSecondaryDark)),
        ],
      ]),
    );
  }
}

// ─── Card stile di vita (dettaglio) ──────────────────────────
class _StileVitaCard extends StatelessWidget {
  final Paziente paziente;
  const _StileVitaCard({required this.paziente});

  @override
  Widget build(BuildContext context) {
    final haFumo = paziente.fumo ?? false;
    final haAlcool = paziente.alcool ?? false;
    final passi = paziente.passiGiornoManuale;

    // Mostra sempre la card, anche se tutti i dati sono negativi
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDark)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.self_improvement, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text('Stile di vita',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppTheme.primary)),
        ]),
        const SizedBox(height: 12),

        // Fumo
        _StileRow(
          icon: Icons.smoking_rooms,
          label: 'Fumo',
          iconColor: haFumo ? AppTheme.error : AppTheme.secondary,
          value: haFumo
              ? (paziente.sigaretteGiorno != null
                  ? '${paziente.sigaretteGiorno} sigarette/giorno'
                  : 'Sì')
              : 'Non fumatore',
          valueColor:
              haFumo ? AppTheme.error : AppTheme.textSecondaryDark,
        ),
        const Divider(height: 16),

        // Alcool
        _StileRow(
          icon: Icons.local_bar,
          label: 'Alcool',
          iconColor: haAlcool ? AppTheme.warning : AppTheme.secondary,
          value: haAlcool
              ? (paziente.bicchieriGiorno != null
                  ? '${paziente.bicchieriGiorno} bicchieri/giorno'
                  : 'Sì')
              : 'Non bevitore',
          valueColor:
              haAlcool ? AppTheme.warning : AppTheme.textSecondaryDark,
        ),
        const Divider(height: 16),

        // Attività fisica
        _StileRow(
          icon: Icons.directions_walk,
          label: 'Passi/giorno',
          iconColor: AppTheme.primary,
          value: passi != null ? '$passi (manuale)' : 'Non impostato',
          valueColor: AppTheme.textSecondaryDark,
          note: 'Se ring connesso, i passi vengono letti automaticamente',
        ),
      ]),
    );
  }
}

class _StileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final String value;
  final Color valueColor;
  final String? note;

  const _StileRow({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.value,
    required this.valueColor,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: iconColor),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.textSecondaryDark)),
          if (note != null)
            Text(note!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: AppTheme.textSecondaryDark.withOpacity(0.6))),
        ]),
      ),
      Text(value,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: valueColor, fontWeight: FontWeight.w500)),
    ]);
  }
}

class _BmiCard extends StatelessWidget {
  final Paziente paziente;
  final double? pesoBilancia; // da Health Connect se disponibile
  const _BmiCard({required this.paziente, this.pesoBilancia});

  double get _bmiEffettivo {
    final peso = pesoBilancia ?? paziente.peso;
    final alt  = paziente.altezza;
    if (peso != null && alt != null && alt > 0) {
      return peso / ((alt / 100) * (alt / 100));
    }
    return paziente.bmi ?? 0;
  }

  String get _categoriaEffettiva {
    final b = _bmiEffettivo;
    if (b < 18.5) return 'Sottopeso';
    if (b < 25.0) return 'Normopeso';
    if (b < 30.0) return 'Sovrappeso';
    if (b < 35.0) return 'Obesità I';
    return 'Obesità II+';
  }

  Color get _color {
    final b = _bmiEffettivo;
    if (b < 18.5) return AppTheme.warning;
    if (b < 25)   return AppTheme.secondary;
    if (b < 30)   return AppTheme.warning;
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final pesoMostrato = pesoBilancia ?? paziente.peso;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withOpacity(0.3))),
      child: Row(children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: _color.withOpacity(0.15)),
          child: Center(
            child: Text(_bmiEffettivo.toStringAsFixed(1),
                style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.w800, color: _color)))),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('BMI',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark)),
            if (pesoBilancia != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.monitor_weight, size: 12, color: AppTheme.secondary),
              const Text(' bilancia',
                  style: TextStyle(fontSize: 10, color: AppTheme.secondary)),
            ],
          ]),
          Text(_categoriaEffettiva,
              style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.w700, color: _color)),
          if (pesoMostrato != null && paziente.altezza != null)
            Text('${pesoMostrato.toStringAsFixed(1)} kg · '
                '${paziente.altezza!.toStringAsFixed(0)} cm',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondaryDark)),
        ]),
      ]),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderDark)),
      child: Column(children: children));
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
      child: Row(children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 12),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const Spacer(),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ]));
  }
}

class _ChipSection extends StatelessWidget {
  final String title;
  final List<String> items;
  final Color color;
  const _ChipSection(
      {required this.title, required this.items, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map((item) => Chip(
                    label: Text(item),
                    backgroundColor: color.withOpacity(0.1),
                    labelStyle:
                        TextStyle(color: color, fontSize: 12),
                    side: BorderSide(color: color.withOpacity(0.3)),
                  ))
              .toList()),
    ]);
  }
}

// ─── Form Profilo ─────────────────────────────────────────────
class ProfiloFormPage extends StatefulWidget {
  final Paziente? paziente;
  const ProfiloFormPage({super.key, this.paziente});

  @override
  State<ProfiloFormPage> createState() => _ProfiloFormPageState();
}

class _ProfiloFormPageState extends State<ProfiloFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Dati anagrafici
  late TextEditingController _nomeCtrl, _cognomeCtrl, _gruppoCtrl;
  late TextEditingController _cfCtrl, _medicoCtrl, _telefonoCtrl;
  late TextEditingController _emailCtrl, _noteCtrl, _allergieCtrl,
      _patologieCtrl;
  late TextEditingController _pesoCtrl, _altezzaCtrl, _anamnestiCtrl;
  DateTime? _dataNascita;

  // Stile di vita
  late bool _fumo;
  late TextEditingController _sigaretteCtrl;
  late bool _alcool;
  late TextEditingController _bicchieriCtrl;
  late TextEditingController _passiCtrl;

  // Dispositivi wearable
  late bool _usaBilancia;
  late bool _usaRing;

  bool _saving = false;
  String? _fotoPath; // path foto profilo corrente

  @override
  void initState() {
    super.initState();
    _fotoPath = SettingsService.instance.fotoProfilo;
    final p = widget.paziente;

    _nomeCtrl = TextEditingController(text: p?.nome ?? '');
    _cognomeCtrl = TextEditingController(text: p?.cognome ?? '');
    _gruppoCtrl = TextEditingController(text: p?.gruppaSanguigno ?? '');
    _cfCtrl = TextEditingController(text: p?.codiceFiscale ?? '');
    _medicoCtrl = TextEditingController(text: p?.medico ?? '');
    _telefonoCtrl = TextEditingController(text: p?.telefono ?? '');
    _emailCtrl = TextEditingController(text: p?.email ?? '');
    _noteCtrl = TextEditingController(text: p?.note ?? '');
    _allergieCtrl =
        TextEditingController(text: p?.allergie.join(', ') ?? '');
    _patologieCtrl =
        TextEditingController(text: p?.patologieCroniche.join(', ') ?? '');
    _pesoCtrl =
        TextEditingController(text: p?.peso?.toStringAsFixed(1) ?? '');
    _altezzaCtrl =
        TextEditingController(text: p?.altezza?.toStringAsFixed(0) ?? '');
    _anamnestiCtrl = TextEditingController(text: p?.anamnesi ?? '');
    _dataNascita = p?.dataNascita;

    _fumo = p?.fumo ?? false;
    _sigaretteCtrl = TextEditingController(
        text: p?.sigaretteGiorno?.toString() ?? '');
    _alcool = p?.alcool ?? false;
    _bicchieriCtrl = TextEditingController(
        text: p?.bicchieriGiorno?.toString() ?? '');
    _passiCtrl = TextEditingController(
        text: p?.passiGiornoManuale?.toString() ?? '');

    // Wearable — legge config esistente se paziente noto
    final pazKey = p != null
        ? BackupService.slotKey(p.nome, p.cognome)
        : '';
    _usaBilancia = pazKey.isNotEmpty
        ? SettingsService.instance.usaBilancia(pazKey)
        : false;
    _usaRing = pazKey.isNotEmpty
        ? SettingsService.instance.usaRing(pazKey)
        : false;
  }

  @override
  void dispose() {
    for (final c in [
      _nomeCtrl, _cognomeCtrl, _gruppoCtrl, _cfCtrl, _medicoCtrl,
      _telefonoCtrl, _emailCtrl, _noteCtrl, _allergieCtrl, _patologieCtrl,
      _pesoCtrl, _altezzaCtrl, _anamnestiCtrl,
      _sigaretteCtrl, _bicchieriCtrl, _passiCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _parseList(String s) =>
      s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _sceglieFoto() async {
    final picker = ImagePicker();
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.camera_alt, color: AppTheme.primary),
            title: const Text('Fotocamera'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: AppTheme.primary),
            title: const Text('Galleria'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          if (_fotoPath != null)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.error),
              title: const Text('Rimuovi foto',
                  style: TextStyle(color: AppTheme.error)),
              onTap: () async {
                await SettingsService.instance.setFotoProfilo(null);
                if (mounted) setState(() => _fotoPath = null);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ]),
      ),
    );
    if (src == null) return;
    final img = await picker.pickImage(
        source: src, imageQuality: 85, maxWidth: 512, maxHeight: 512);
    if (img == null) return;
    // Copia in cartella app
    final dir  = await getApplicationDocumentsDirectory();
    final dest = '${dir.path}/foto_profilo.jpg';
    await File(img.path).copy(dest);
    await SettingsService.instance.setFotoProfilo(dest);
    if (mounted) setState(() => _fotoPath = dest);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = LocalRepository();
      await repo.init();
      final p = Paziente(
        nome: _nomeCtrl.text.trim(),
        cognome: _cognomeCtrl.text.trim(),
        dataNascita: _dataNascita,
        gruppaSanguigno: _gruppoCtrl.text.trim().isEmpty
            ? null
            : _gruppoCtrl.text.trim(),
        codiceFiscale:
            _cfCtrl.text.trim().isEmpty ? null : _cfCtrl.text.trim(),
        medico: _medicoCtrl.text.trim().isEmpty
            ? null
            : _medicoCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim().isEmpty
            ? null
            : _telefonoCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty
            ? null
            : _emailCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        allergie: _parseList(_allergieCtrl.text),
        patologieCroniche: _parseList(_patologieCtrl.text),
        peso: double.tryParse(_pesoCtrl.text.replaceAll(',', '.')),
        altezza: double.tryParse(_altezzaCtrl.text.replaceAll(',', '.')),
        anamnesi: _anamnestiCtrl.text.trim().isEmpty
            ? null
            : _anamnestiCtrl.text.trim(),
        fumo: _fumo,
        sigaretteGiorno: _fumo
            ? int.tryParse(_sigaretteCtrl.text.trim())
            : null,
        alcool: _alcool,
        bicchieriGiorno: _alcool
            ? int.tryParse(_bicchieriCtrl.text.trim())
            : null,
        passiGiornoManuale: int.tryParse(_passiCtrl.text.trim()),
      );
      await repo.savePaziente(p);
      // Salva config wearable in SettingsService
      final pazKey = BackupService.slotKey(
          _nomeCtrl.text.trim(), _cognomeCtrl.text.trim());
      await SettingsService.instance.setUsaBilancia(pazKey, _usaBilancia);
      await SettingsService.instance.setUsaRing(pazKey, _usaRing);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.paziente == null
            ? 'Nuovo profilo'
            : 'Modifica profilo'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Salva',
                    style: TextStyle(color: AppTheme.primary))),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Foto profilo ─────────────────────────────
            Center(
              child: GestureDetector(
                onTap: _sceglieFoto,
                child: Stack(alignment: Alignment.bottomRight, children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: AppTheme.primary.withOpacity(0.15),
                    backgroundImage: _fotoPath != null &&
                            File(_fotoPath!).existsSync()
                        ? FileImage(File(_fotoPath!))
                        : null,
                    child: _fotoPath == null ? const Icon(
                        Icons.person, size: 52,
                        color: AppTheme.textSecondaryDark) : null,
                  ),
                  Container(
                    decoration: const BoxDecoration(
                        color: AppTheme.primary, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.camera_alt,
                        size: 16, color: Colors.white),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            // ── Nome / Cognome ───────────────────────────
            Row(children: [
              Expanded(
                  child: TextFormField(
                controller: _nomeCtrl,
                decoration:
                    trDeco(InputDecoration(labelText: 'Nome *')),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? tr('Obbligatorio') : null,
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: TextFormField(
                controller: _cognomeCtrl,
                decoration:
                    trDeco(InputDecoration(labelText: 'Cognome *')),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? tr('Obbligatorio') : null,
              )),
            ]),
            const SizedBox(height: 16),

            // ── Data di nascita ──────────────────────────
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const Icon(Icons.cake, color: AppTheme.primary),
              title: const Text('Data di nascita'),
              subtitle: Text(_dataNascita != null
                  ? '${_dataNascita!.day}/${_dataNascita!.month}/${_dataNascita!.year}'
                  : 'Non impostata'),
              onTap: () async {
                final p = await showDatePicker(
                    context: context,
                    initialDate: _dataNascita ?? DateTime(1980),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now());
                if (p != null) setState(() => _dataNascita = p);
              }),
            const Divider(),
            const SizedBox(height: 8),

            // ── Peso e altezza ───────────────────────────
            Row(children: [
              Expanded(
                  child: TextFormField(
                controller: _pesoCtrl,
                decoration: trDeco(InputDecoration(
                    labelText: 'Peso (kg)', hintText: 'es. 75.5')),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                onChanged: (_) => setState(() {}),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: TextFormField(
                controller: _altezzaCtrl,
                decoration: trDeco(InputDecoration(
                    labelText: 'Altezza (cm)', hintText: 'es. 175')),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              )),
            ]),

            // BMI preview
            Builder(builder: (ctx) {
              final peso = double.tryParse(
                  _pesoCtrl.text.replaceAll(',', '.'));
              final alt = double.tryParse(
                  _altezzaCtrl.text.replaceAll(',', '.'));
              if (peso != null && alt != null && alt > 0) {
                final bmi = peso / ((alt / 100) * (alt / 100));
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                      'BMI calcolato: ${bmi.toStringAsFixed(1)}',
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 13)));
              }
              return const SizedBox.shrink();
            }),
            const SizedBox(height: 16),

            // ── Altri campi anagrafici ───────────────────
            TextFormField(
                controller: _gruppoCtrl,
                decoration: trDeco(InputDecoration(
                    labelText: 'Gruppo sanguigno',
                    hintText: 'es. A+'))),
            const SizedBox(height: 16),
            TextFormField(
                controller: _cfCtrl,
                decoration: trDeco(InputDecoration(
                    labelText: 'Codice fiscale'))),
            const SizedBox(height: 16),
            TextFormField(
                controller: _medicoCtrl,
                decoration: trDeco(InputDecoration(
                    labelText: 'Medico di base'))),
            const SizedBox(height: 16),
            TextFormField(
                controller: _telefonoCtrl,
                decoration:
                    trDeco(InputDecoration(labelText: 'Telefono')),
                keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            TextFormField(
                controller: _emailCtrl,
                decoration:
                    trDeco(InputDecoration(labelText: 'Email')),
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            TextFormField(
                controller: _allergieCtrl,
                decoration: trDeco(InputDecoration(
                    labelText: 'Allergie',
                    hintText: 'Separate da virgola'))),
            const SizedBox(height: 16),
            TextFormField(
                controller: _patologieCtrl,
                decoration: trDeco(InputDecoration(
                    labelText: 'Patologie croniche',
                    hintText: 'Separate da virgola'))),
            const SizedBox(height: 24),

            // ── Stile di vita ────────────────────────────
            _SezioneHeader(
              icon: Icons.self_improvement,
              title: 'Stile di vita',
              subtitle: 'Usato per calcolare l\'Health Score',
            ),
            const SizedBox(height: 12),

            // Fumo
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderDark)),
              child: Column(children: [
                SwitchListTile(
                  secondary: Icon(Icons.smoking_rooms,
                      color: _fumo
                          ? AppTheme.error
                          : AppTheme.textSecondaryDark),
                  title: const Text('Fumo'),
                  subtitle: Text(_fumo
                      ? 'Indica quante sigarette al giorno'
                      : 'Non fumatore'),
                  value: _fumo,
                  activeColor: AppTheme.error,
                  onChanged: (v) =>
                      setState(() { _fumo = v; }),
                ),
                if (_fumo) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: TextFormField(
                      controller: _sigaretteCtrl,
                      decoration: trDeco(InputDecoration(
                        labelText: 'Sigarette al giorno',
                        hintText: 'es. 10',
                        prefixIcon: Icon(Icons.smoking_rooms),
                        suffixText: 'sig/g',
                      )),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (!_fumo) return null;
                        if (v == null || v.trim().isEmpty) {
                          return tr('Inserisci il numero di sigarette');
                        }
                        if (int.tryParse(v.trim()) == null ||
                            int.parse(v.trim()) <= 0) {
                          return tr('Numero non valido');
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 12),

            // Alcool
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderDark)),
              child: Column(children: [
                SwitchListTile(
                  secondary: Icon(Icons.local_bar,
                      color: _alcool
                          ? AppTheme.warning
                          : AppTheme.textSecondaryDark),
                  title: const Text('Alcool'),
                  subtitle: Text(_alcool
                      ? 'Indica i bicchieri di vino al giorno'
                      : 'Non bevitore abituale'),
                  value: _alcool,
                  activeColor: AppTheme.warning,
                  onChanged: (v) =>
                      setState(() { _alcool = v; }),
                ),
                if (_alcool) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: TextFormField(
                      controller: _bicchieriCtrl,
                      decoration: trDeco(InputDecoration(
                        labelText: 'Bicchieri di vino al giorno',
                        hintText: 'es. 1',
                        prefixIcon: Icon(Icons.wine_bar_outlined),
                        suffixText: 'bic/g',
                      )),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (!_alcool) return null;
                        if (v == null || v.trim().isEmpty) {
                          return tr('Inserisci il numero di bicchieri');
                        }
                        if (int.tryParse(v.trim()) == null ||
                            int.parse(v.trim()) <= 0) {
                          return tr('Numero non valido');
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 12),

            // Attività fisica (passi manuali)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderDark)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  const Icon(Icons.directions_walk,
                      color: AppTheme.primary, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Attività fisica — passi/giorno',
                          style: TextStyle(fontSize: 14)),
                      Text(
                          'Se ring connesso, i passi vengono letti automaticamente da Health Connect',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondaryDark)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passiCtrl,
                  decoration: trDeco(InputDecoration(
                    labelText: 'Passi stimati al giorno (se no ring)',
                    hintText: 'es. 6000',
                    prefixIcon: Icon(Icons.show_chart),
                    suffixText: 'passi',
                  )),
                  keyboardType: TextInputType.number,
                ),
              ]),
            ),
            const SizedBox(height: 24),

            // ── Dispositivi wearable ─────────────────────
            _SezioneHeader(
              icon: Icons.watch,
              title: 'Dispositivi wearable',
              subtitle: 'Determina cosa appare nella dashboard',
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderDark)),
              child: Column(children: [
                SwitchListTile(
                  secondary: Icon(Icons.monitor_weight_outlined,
                      color: _usaBilancia
                          ? AppTheme.primary
                          : AppTheme.textSecondaryDark),
                  title: const Text('Bilancia Amazfit'),
                  subtitle: Text(_usaBilancia
                      ? 'Peso, BMI, massa grassa visibili'
                      : 'Sezione bilancia nascosta'),
                  value: _usaBilancia,
                  activeColor: AppTheme.primary,
                  onChanged: (v) => setState(() => _usaBilancia = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: Icon(Icons.watch_outlined,
                      color: _usaRing
                          ? AppTheme.secondary
                          : AppTheme.textSecondaryDark),
                  title: const Text('Ring Amazfit'),
                  subtitle: Text(_usaRing
                      ? 'Passi, FC, sonno visibili'
                      : 'Sezione ring nascosta'),
                  value: _usaRing,
                  activeColor: AppTheme.secondary,
                  onChanged: (v) => setState(() => _usaRing = v),
                ),
              ]),
            ),

            const SizedBox(height: 24),

            // ── Anamnesi ─────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.primary.withOpacity(0.2))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  const Icon(Icons.history_edu,
                      size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text('Anamnesi personale',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppTheme.primary)),
                ]),
                const SizedBox(height: 6),
                Text(
                    'Scrivi liberamente la tua storia clinica: malattie passate, '
                    'interventi, allergie non documentate, vaccini, familiarità...',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _anamnestiCtrl,
                  maxLines: 6,
                  decoration: trDeco(InputDecoration(
                    hintText:
                        'Es: Ho avuto il morbillo da bambino, '
                        'allergia alla penicillina, mia madre ha il diabete tipo 2, '
                        'ho fatto il vaccino anti-covid nel 2021...',
                    border: InputBorder.none,
                    isDense: true,
                  )),
                ),
              ])),
            const SizedBox(height: 16),
            TextFormField(
                controller: _noteCtrl,
                decoration:
                    trDeco(InputDecoration(labelText: 'Note')),
                maxLines: 3),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Helper widget sezione ────────────────────────────────────
class _SezioneHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const _SezioneHeader(
      {required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: AppTheme.primary, size: 18),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppTheme.primary)),
        if (subtitle != null)
          Text(subtitle!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.textSecondaryDark)),
      ]),
    ]);
  }
}
