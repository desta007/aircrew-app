import 'package:flutter/material.dart';
import 'theme.dart';

/// AirCrew wordmark used on splash / login / app bars.
class AirLogo extends StatelessWidget {
  final double size;
  final bool light;
  const AirLogo({super.key, this.size = 26, this.light = false});

  @override
  Widget build(BuildContext context) {
    final onNavy = light;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: onNavy ? Colors.white.withValues(alpha: .12) : AirColors.navy,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.flight_takeoff_rounded, color: onNavy ? Colors.white : Colors.white, size: size * .8),
        ),
        const SizedBox(width: 8),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
              color: onNavy ? Colors.white : AirColors.navy,
            ),
            children: [
              const TextSpan(text: 'AIR'),
              TextSpan(text: 'CREW', style: TextStyle(color: onNavy ? AirColors.gold : AirColors.red)),
            ],
          ),
        ),
      ],
    );
  }
}

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const SectionCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AirColors.line),
      ),
      child: child,
    );
  }
}

class KVRow extends StatelessWidget {
  final String k;
  final String v;
  final bool bold;
  final Color? valueColor;
  const KVRow(this.k, this.v, {super.key, this.bold = false, this.valueColor});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(k, style: const TextStyle(color: AirColors.textDim, fontSize: 13.5))),
          const SizedBox(width: 12),
          Text(v,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: valueColor ?? AirColors.text,
              )),
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final IconData? icon;
  const PrimaryButton(this.label, {super.key, this.onPressed, this.color, this.icon});
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? AirColors.navy,
        disabledBackgroundColor: AirColors.line,
      ),
      child: icon == null
          ? Text(label)
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(label)]),
    );
  }
}

class Avatar extends StatelessWidget {
  final String name;
  final double radius;
  const Avatar(this.name, {super.key, this.radius = 22});
  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(' ').take(2).map((e) => e[0]).join();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AirColors.navy.withValues(alpha: .1),
      child: Text(initials, style: const TextStyle(color: AirColors.navy, fontWeight: FontWeight.w800)),
    );
  }
}

class StepDots extends StatelessWidget {
  final int total;
  final int current;
  const StepDots({super.key, required this.total, required this.current});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i <= current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == current ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? AirColors.red : AirColors.line,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

/// A lightweight stand-in for a live map (used in tracking / navigation screens).
class MapPlaceholder extends StatelessWidget {
  final String? banner;
  final double height;
  const MapPlaceholder({super.key, this.banner, this.height = 240});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [Color(0xFFE9EEF6), Color(0xFFDCE6F4)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: AirColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          CustomPaint(size: Size.infinite, painter: _RoadsPainter()),
          const Positioned(left: 40, top: 60, child: Icon(Icons.location_on, color: AirColors.blue, size: 34)),
          const Positioned(right: 46, bottom: 56, child: Icon(Icons.sports_score, color: AirColors.red, size: 30)),
          const Center(child: Icon(Icons.directions_car_filled, color: AirColors.navy, size: 30)),
          if (banner != null)
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AirColors.green, borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.turn_right, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Text(banner!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoadsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width * .1, size.height * .2)
      ..lineTo(size.width * .5, size.height * .5)
      ..lineTo(size.width * .85, size.height * .82);
    canvas.drawPath(path, p);
    final grid = Paint()..color = Colors.white.withValues(alpha: .5)..strokeWidth = 3;
    for (double x = 0; x < size.width; x += 46) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 46) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Future<T?> showAirSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: child,
    ),
  );
}
