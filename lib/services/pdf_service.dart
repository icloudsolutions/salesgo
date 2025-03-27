import 'package:pdf/widgets.dart' as pw;
import 'package:salesgo/models/sale.dart';

class PdfService {
  pw.Document generateInvoice(Sale sale) {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          children: [
            pw.Header(text: 'Facture #${sale.id}'),
            pw.ListView.builder(
              itemCount: sale.products.length,
              itemBuilder: (context, index) => pw.Text(
                sale.products[index].name,
              ),
            ),
          ],
        ),
      ),
    );
    
    return pdf;
  }
}