import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeClimaSeccion extends StatelessWidget {
  final Map<String, dynamic>? weatherData;
  final String? error;

  const HomeClimaSeccion({super.key, this.weatherData, this.error});

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Center(
          child: Text(error!, style: const TextStyle(color: Colors.red)));
    }
    if (weatherData == null) {
      return const SizedBox.shrink(); // O loading si se prefiere
    }

    final current = weatherData!['current'];
    final location = weatherData!['location'];
    final forecast = weatherData!['forecast']['forecastday'] as List;

    // Datos actuales
    final tempC = current['temp_c'].round();
    final conditionText = current['condition']['text'];
    final conditionIcon = "https:${current['condition']['icon']}";
    final locName = "${location['name']}, ${location['region']}";

    // Max/Min de hoy (index 0)
    final today = forecast[0]['day'];
    final maxTemp = today['maxtemp_c'].round();
    final minTemp = today['mintemp_c'].round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Tiempo",
                style: GoogleFonts.lora(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF142018),
                ),
              ),
              const SizedBox.shrink(),
            ],
          ),
        ),
        const SizedBox(height: 15),

        // TARJETA PRINCIPAL (Current + Hourly)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFCFBF6),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.black87),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ubicación
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 20),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      locName,
                      style: GoogleFonts.ibmPlexSans(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 5),
                ],
              ),
              const SizedBox(height: 20),

              // Temperatura y Max/Min
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "$tempCº${"C"}", // Hack visual para la C un poco más pequeña si se quisiera
                    style: GoogleFonts.lora(
                      fontSize: 64,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF142018),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_upward, size: 16),
                          const SizedBox(width: 4),
                          Text("$maxTempº C",
                              style: GoogleFonts.ibmPlexSans(fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.arrow_downward, size: 16),
                          const SizedBox(width: 4),
                          Text("$minTempº C",
                              style: GoogleFonts.ibmPlexSans(fontSize: 16)),
                        ],
                      ),
                    ],
                  )
                ],
              ),

              // Condición + Icono
              Row(
                children: [
                  CachedNetworkImage(
                    imageUrl: conditionIcon,
                    width: 32,
                    height: 32,
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.wb_sunny_outlined),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      conditionText,
                      style: GoogleFonts.ibmPlexSans(fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Divider(),

              const SizedBox(height: 10),

              // Previsión por horas (Simplificada: tomamos del forecast del día actual)
              // WeatherAPI da 'hour' array en forecastday[0]
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: (forecast[0]['hour'] as List).map((h) {
                    final time = h['time'] as String; // "2023-10-10 14:00"
                    final hourStr = time.split(' ')[1].substring(0, 2); // "14"
                    // Filtramos para mostrar solo algunas horas o todas
                    // Por simplicidad mostramos todas las que vienen o un subconjunto
                    final itemTemp = h['temp_c'].round();
                    final itemIcon = "https:${h['condition']['icon']}";

                    // Solo mostrar si es posteror a ahora? O todo el día? Mostremos todo el día style mockup
                    return Padding(
                      padding: const EdgeInsets.only(right: 25.0),
                      child: Column(
                        children: [
                          Text(hourStr,
                              style: GoogleFonts.ibmPlexSans(
                                  color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 5),
                          CachedNetworkImage(
                              imageUrl: itemIcon, width: 24, height: 24),
                          const SizedBox(height: 5),
                          Text("$itemTempº",
                              style: GoogleFonts.ibmPlexSans(
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              )
            ],
          ),
        ),

        const SizedBox(height: 15),

        // TARJETA DE PRONÓSTICO DIARIO
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFCFBF6), // Mismo fondo claro
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.black87),
          ),
          child: Column(
            children: forecast.map((dayData) {
              final date = DateTime.parse(dayData['date']);
              // Hack rápido para nombre día en español sin intl complicado ahora mismo
              final weekDays = [
                "Lunes",
                "Martes",
                "Miércoles",
                "Jueves",
                "Viernes",
                "Sábado",
                "Domingo"
              ];
              final dayName = weekDays[date.weekday - 1]; // weekday 1=Mon

              final dMax = dayData['day']['maxtemp_c'].round();
              final dMin = dayData['day']['mintemp_c'].round();
              final dIcon = "https:${dayData['day']['condition']['icon']}";

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 100,
                      child:
                          Text(dayName, style: GoogleFonts.lora(fontSize: 16)),
                    ),
                    CachedNetworkImage(imageUrl: dIcon, width: 24, height: 24),
                    Text("$dMaxº C",
                        style: GoogleFonts.ibmPlexSans(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text("$dMinº C",
                        style: GoogleFonts.ibmPlexSans(
                            fontSize: 16, color: Colors.grey)),
                  ],
                ),
              );
            }).toList(),
          ),
        )
      ],
    );
  }
}
