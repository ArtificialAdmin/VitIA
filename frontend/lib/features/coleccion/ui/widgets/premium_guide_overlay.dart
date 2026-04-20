import 'package:flutter/material.dart';
import 'dart:math' as math;

enum PremiumStep { leafFront, leafBack, cluster, singleGrape }

class PremiumGuideOverlay extends StatelessWidget {
  final PremiumStep step;
  final String label;

  const PremiumGuideOverlay({
    super.key,
    required this.step,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Silhouette Guide
        Center(
          child: Container(
            width: 280,
            height: 280,
            child: CustomPaint(
              painter: SilhouettePainter(step: step),
            ),
          ),
        ),
        
        // Instructional Label
        Positioned(
          top: 160,
          left: 10,
          right: 10,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        
        // Step indicator (e.g. 1/4)
        Positioned(
          top: 130, // Even lower to stay clear of the toggle
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              bool active = index <= step.index;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: active ? Colors.greenAccent : Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class SilhouettePainter extends CustomPainter {
  final PremiumStep step;

  SilhouettePainter({required this.step});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    switch (step) {
      case PremiumStep.leafFront:
      case PremiumStep.leafBack:
        _drawLeafSilhouette(canvas, size, paint);
        break;
      case PremiumStep.cluster:
        _drawClusterSilhouette(canvas, size, paint);
        break;
      case PremiumStep.singleGrape:
        _drawSingleGrapeSilhouette(canvas, size, paint);
        break;
    }
    
    // Draw brackets (common)
    _drawBrackets(canvas, size);
  }

  void _drawLeafSilhouette(Canvas canvas, Size size, Paint paint) {
    final path = Path();
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width * 0.45;
    
    // Starting point (top lobe central point)
    path.moveTo(centerX, centerY - radius);
    
    // Function to add a lobe with some organic jitter/teeth
    void addLobe(double targetAngle, double spread, double innerRadiusScale) {
      double startAngle = targetAngle - spread;
      double endAngle = targetAngle + spread;
      
      // Outer curve of the lobe
      double ctrl1X = centerX + radius * 1.1 * math.cos(startAngle + spread * 0.5);
      double ctrl1Y = centerY + radius * 1.1 * math.sin(startAngle + spread * 0.5);
      double endX = centerX + radius * math.cos(endAngle);
      double endY = centerY + radius * math.sin(endAngle);
      
      path.quadraticBezierTo(ctrl1X, ctrl1Y, endX, endY);
      
      // Sinus (the "valley" between lobes)
      double sinusAngle = endAngle + 0.2;
      double sinusX = centerX + radius * innerRadiusScale * math.cos(sinusAngle);
      double sinusY = centerY + radius * innerRadiusScale * math.sin(sinusAngle);
      path.lineTo(sinusX, sinusY);
    }

    // Top Lobe
    addLobe(-math.pi / 2, 0.4, 0.6);
    // Right Top Lobe
    addLobe(-0.2, 0.5, 0.5);
    // Right Bottom Lobe
    addLobe(math.pi * 0.3, 0.4, 0.3);
    // Bottom Lobe (near stem)
    path.lineTo(centerX, centerY + radius * 0.4);
    // Left Bottom Lobe
    addLobe(math.pi * 0.7, 0.4, 0.5);
    // Left Top Lobe
    addLobe(math.pi * 1.2, 0.5, 0.6);
    
    path.close();
    canvas.drawPath(path, paint);
    
    // Advanced Veins
    final veinPaint = Paint()
      ..color = paint.color.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
      
    // Main veins from center to lobes
    canvas.drawLine(Offset(centerX, centerY + radius * 0.2), Offset(centerX, centerY - radius * 0.9), veinPaint);
    canvas.drawLine(Offset(centerX, centerY), Offset(centerX + radius * 0.7 * math.cos(-0.2), centerY + radius * 0.7 * math.sin(-0.2)), veinPaint);
    canvas.drawLine(Offset(centerX, centerY), Offset(centerX + radius * 0.7 * math.cos(math.pi * 1.2), centerY + radius * 0.7 * math.sin(math.pi * 1.2)), veinPaint);
    canvas.drawLine(Offset(centerX, centerY), Offset(centerX + radius * 0.5 * math.cos(math.pi * 0.3), centerY + radius * 0.5 * math.sin(math.pi * 0.3)), veinPaint);
    canvas.drawLine(Offset(centerX, centerY), Offset(centerX + radius * 0.5 * math.cos(math.pi * 0.7), centerY + radius * 0.5 * math.sin(math.pi * 0.7)), veinPaint);
  }

  void _drawClusterSilhouette(Canvas canvas, Size size, Paint paint) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final baseRadius = size.width * 0.12;
    
    final grapePaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Organic arrangement of grapes (circles)
    final offsets = [
      Offset(0, -1.8), // Top central
      Offset(-0.9, -1.2), Offset(0.9, -1.2),
      Offset(-1.2, -0.2), Offset(0, -0.2), Offset(1.2, -0.2),
      Offset(-0.8, 0.8), Offset(0.8, 0.8),
      Offset(-0.4, 1.8), Offset(0.4, 1.8),
      Offset(0, 2.8), // Bottom tip
    ];

    for (int i = 0; i < offsets.length; i++) {
        // Slightly vary radius for organic feel
        double r = baseRadius * (0.9 + 0.2 * math.cos(i.toDouble()));
        canvas.drawCircle(
          Offset(centerX + offsets[i].dx * baseRadius, centerY + offsets[i].dy * baseRadius),
          r,
          grapePaint
        );
    }

    // Realistic Stem (peduncle)
    final stemPath = Path()
      ..moveTo(centerX, centerY - baseRadius * 2.8)
      ..quadraticBezierTo(centerX - 10, centerY - baseRadius * 3.5, centerX + 5, centerY - baseRadius * 4.2);
    
    canvas.drawPath(stemPath, paint..strokeWidth = 3.0);
  }

  void _drawSingleGrapeSilhouette(Canvas canvas, Size size, Paint paint) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width * 0.38;
    
    // Main Grape
    canvas.drawCircle(Offset(centerX, centerY), radius, paint);
    
    // Refined Shiny Arc
    final shinePaint = Paint()
      ..color = paint.color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
      
    canvas.drawArc(
      Rect.fromCircle(center: Offset(centerX, centerY), radius: radius * 0.75),
      -math.pi * 0.7,
      math.pi * 0.3,
      false,
      shinePaint,
    );
    
    // Small stem attachment point
    canvas.drawCircle(Offset(centerX, centerY - radius), 4, paint..style = PaintingStyle.fill);
  }

  void _drawBrackets(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    double len = 25.0;
    // Corners
    canvas.drawLine(const Offset(0, 0), Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, len), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);
    canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - len), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - len, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - len), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
