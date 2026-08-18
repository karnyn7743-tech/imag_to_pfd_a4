import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<void> generateCleanA4Pdf(List<File> imageFiles) async {
  final pdf = pw.Document();

  for (var imageFile in imageFiles) {
    final imageBytes = await imageFile.readAsBytes();
    final image = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero, // إلغاء الهوامش لاستغلال كامل الصفحة دون قص
        build: (pw.Context context) {
          return pw.FullPage(
            ignoreMargins: true,
            child: pw.Center(
              child: pw.Image(
                image,
                fit: pw.BoxFit.contain, // يحافظ على أبعاد الغلاف الأصلية ونقاوة الألوان دون تمطيط
              ),
            ),
          );
        },
      ),
    );
  }

  // حفظ الملف أو تصديره للطباعة المباشرة بأعلى دقة
  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => pdf.save(),
  );
}
