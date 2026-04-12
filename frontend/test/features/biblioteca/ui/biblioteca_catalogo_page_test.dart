// test/features/biblioteca/ui/biblioteca_catalogo_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// ASEGÚRATE DE QUE EL PAQUETE SEA 'vinas_mobile' O EL NOMBRE QUE TENGAS EN pubspec.yaml
import 'package:vinas_mobile/core/api_client.dart'; 
import 'package:vinas_mobile/core/providers.dart';
import 'package:vinas_mobile/features/biblioteca/ui/biblioteca_catalogo_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// CORRECCIÓN IMPORTANTE: 
// Al estar en la misma carpeta, el import no necesita bajar niveles (../../).
// Simplemente llamamos al archivo hermano que se generará.
@GenerateMocks([ApiClient])
import 'biblioteca_catalogo_page_test.mocks.dart';

void main() {
  late MockApiClient mockApiClient;

  setUp(() {
    // Antes de cada test, reiniciamos el mock
    mockApiClient = MockApiClient();
  });

  // CASO DE PRUEBA 1: Verificar que la lista carga datos correctamente
  testWidgets('Debe mostrar variedades cuando el backend responde con datos',
      (WidgetTester tester) async {
    
    // 1. ARRANGE (Preparar): Enseñamos al mock qué responder
    when(mockApiClient.getVariedades()).thenAnswer((_) async => [
          {
            'id_variedad': 1,
            'nombre': 'Garnacha',
            'descripcion': 'Uva tinta muy popular',
            'links_imagenes': ['http://fake.url/img.jpg'],
            'color': 'Tinta', // Añado esto para que no falle tu lógica de colores
             // Añade otros campos si tu modelo es estricto
          }
        ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiProvider.overrideWithValue(mockApiClient),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: BibliotecaCatalogoPage(), // <--- INYECCIÓN VIA PROVIDER
        ),
      ),
    ));

    // Esperamos a que terminen las animaciones y cargas
    await tester.pumpAndSettle();

    // 3. ASSERT (Verificar):
    expect(find.text('Garnacha'), findsOneWidget);
    // Verificamos que NO hay iconos de error
    expect(find.byIcon(Icons.error), findsNothing);
  });

  // CASO DE PRUEBA 2: Verificar la corrección del "Error Silencioso"
  testWidgets('Debe mostrar SnackBar rojo cuando falla la conexión',
      (WidgetTester tester) async {
    
    // 1. ARRANGE: Simulamos fallo
    when(mockApiClient.getVariedades()).thenThrow(Exception('Fallo de red'));

    // 2. ACT
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiProvider.overrideWithValue(mockApiClient),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: BibliotecaCatalogoPage(),
        ),
      ),
    ));

    // Esperamos a que la UI reaccione (el SnackBar tarda un poco en aparecer)
    await tester.pumpAndSettle();

    // 3. ASSERT
    // Buscamos el texto específico del SnackBar
    expect(find.text('Error de conexión: No se pudieron cargar las viñas'), findsOneWidget);
  });
}