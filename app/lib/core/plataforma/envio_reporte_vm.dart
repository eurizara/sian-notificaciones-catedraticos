/// SIAN — Envío de reportes fuera del navegador: se anotan para las pruebas.
library;

class ReporteEnviado {
  const ReporteEnviado(this.direccion, this.cuerpo);

  final String direccion;
  final String cuerpo;
}

final List<ReporteEnviado> reportesDePrueba = <ReporteEnviado>[];

Future<void> enviarReporte(String direccion, String cuerpo) async {
  reportesDePrueba.add(ReporteEnviado(direccion, cuerpo));
}
