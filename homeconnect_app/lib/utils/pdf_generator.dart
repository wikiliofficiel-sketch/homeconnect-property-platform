import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfGenerator {
  static Future<void> generateContractPdf({
    required String ownerName,
    required String tenantName,
    required String propertyTitle,
    required String propertyAddress,
    required String price,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'CONTRAT DE BAIL À USAGE D\'HABITATION',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, decoration: pw.TextDecoration.underline),
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Text('ENTRE LES SOUSSIGNÉS :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text('LE BAILLEUR : $ownerName'),
                pw.SizedBox(height: 5),
                pw.Text('LE PRENEUR : $tenantName'),
                pw.SizedBox(height: 30),
                pw.Text('OBJET DU CONTRAT :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text('Le présent contrat a pour objet la location du bien suivant :'),
                pw.Bullet(text: 'Titre : $propertyTitle'),
                pw.Bullet(text: 'Adresse : $propertyAddress'),
                pw.Bullet(text: 'Loyer mensuel : $price FCFA'),
                pw.SizedBox(height: 30),
                pw.Text('DURÉE ET PRÉAVIS :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text('Le présent bail est conclu pour une durée indéterminée. Chacune des parties peut y mettre fin moyennant un préavis de trois (03) mois notifié par écrit.'),
                pw.SizedBox(height: 40),
                pw.Center(child: pw.Text('Fait à Cotonou, le ${DateFormat('dd/MM/yyyy').format(DateTime.now())}')),
                pw.SizedBox(height: 50),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Signature du Bailleur', style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
                    pw.Text('Signature du Preneur', style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> generateEtatDesLieuxPdf({
    required String propertyTitle,
    required Map<String, String> evaluations,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'ÉTAT DES LIEUX NUMÉRIQUE',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Bien concerné : $propertyTitle', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('Date : ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
                pw.SizedBox(height: 30),
                pw.TableHelper.fromTextArray(
                  context: context,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headers: ['Pièce / Élément', 'État constaté'],
                  data: evaluations.entries.map((e) => [e.key, e.value]).toList(),
                ),
                pw.SizedBox(height: 50),
                pw.Text('Certifié conforme par le propriétaire via l\'application ImmoBénin.', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}
