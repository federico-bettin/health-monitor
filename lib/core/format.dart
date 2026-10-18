/// Formatta un importo in euro, stile italiano: 1234.5 → "1234,50 €"
String formatEuro(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} €';

/// Formatta una data come gg/mm/aaaa
String formatData(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
