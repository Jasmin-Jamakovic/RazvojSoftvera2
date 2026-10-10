import 'package:flutter/material.dart';
import '../services/auth_store.dart';
import '../utils/api_config.dart';
import '../theme/app_theme.dart';

const bsDaysShort = ['Pon', 'Uto', 'Sri', 'Čet', 'Pet', 'Sub', 'Ned'];
const bsMonthsShort = ['jan', 'feb', 'mar', 'apr', 'maj', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'dec'];
const bsMonths = ['Januar', 'Februar', 'Mart', 'April', 'Maj', 'Juni', 'Juli', 'August', 'Septembar', 'Oktobar', 'Novembar', 'Decembar'];

String hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String dayLabel(DateTime d) => '${bsDaysShort[d.weekday - 1]}, ${d.day}. ${bsMonthsShort[d.month - 1]}';

/// "danas", "sutra", "za 3 dana", "za 2 h"...
String relativeFromNow(DateTime d) {
  final now = DateTime.now();
  final diff = d.difference(now);
  if (diff.isNegative) return 'u toku';
  if (diff.inMinutes < 60) return 'za ${diff.inMinutes} min';
  final today = DateTime(now.year, now.month, now.day);
  final days = DateTime(d.year, d.month, d.day).difference(today).inDays;
  if (days == 0) return 'za ${diff.inHours} h';
  if (days == 1) return 'sutra';
  return 'za $days dana';
}

String initialsOf(String name) {
  final parts = name.replaceFirst(RegExp(r'^Dr\.?\s*'), '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}

/// Icon inside a small rounded square, the same motif as the admin sidebar.
class IconSquare extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final Color color;
  final Color background;
  final VoidCallback? onTap;

  const IconSquare(
    this.icon, {
    super.key,
    this.size = 40,
    this.iconSize = 20,
    this.color = AppColors.primary,
    this.background = AppColors.tint,
    this.onTap,
  });

  /// Translucent white variant for use on top of the green gradient.
  const IconSquare.onGradient(this.icon, {super.key, this.size = 40, this.iconSize = 20, this.onTap})
      : color = Colors.white,
        background = const Color(0x24FFFFFF);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.3);
    final box = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, borderRadius: radius),
      child: Icon(icon, size: iconSize, color: color),
    );
    if (onTap == null) return box;
    return Material(color: Colors.transparent, child: InkWell(borderRadius: radius, onTap: onTap, child: box));
  }
}

/// White rounded card with a soft shadow.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final double radius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.gradient,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: gradient == null ? Colors.white : null,
          gradient: gradient,
          borderRadius: br,
          boxShadow: gradient == null ? AppColors.softShadow : AppColors.glowShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(borderRadius: br, onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      ),
    );
  }
}

/// Full-width button filled with the brand gradient.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;

  const GradientButton({super.key, required this.label, this.icon, this.onPressed, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final br = BorderRadius.circular(14);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: enabled ? 1 : 0.55,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: br, boxShadow: enabled ? AppColors.glowShadow : null),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: br,
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (busy)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                else ...[
                  if (icon != null) ...[Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 8)],
                  Flexible(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color fg;
  final Color bg;
  final IconData? icon;

  const Pill(this.text, {super.key, required this.fg, required this.bg, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 3)],
        Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Appointment status with a Bosnian label and a soft background colour.
class StatusPill extends StatelessWidget {
  final String status;
  final bool isPaid;
  final bool onGradient;

  const StatusPill(this.status, {super.key, this.isPaid = false, this.onGradient = false});

  static String label(String status, {bool isPaid = false}) => switch (status) {
        'Pending' => isPaid ? 'Na čekanju' : 'Čeka plaćanje',
        'Confirmed' => 'Potvrđen',
        'Completed' => 'Završen',
        'Cancelled' => 'Otkazan',
        _ => status,
      };

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (status) {
      'Pending' => (const Color(0xFFEF6C00), const Color(0xFFFFF2E0)),
      'Confirmed' => (AppColors.primary, AppColors.tint),
      'Completed' => (const Color(0xFF546E7A), const Color(0xFFECEFF3)),
      'Cancelled' => (const Color(0xFFC62828), const Color(0xFFFDECEA)),
      _ => (AppColors.muted, const Color(0xFFECEFF3)),
    };
    if (onGradient) return Pill(label(status, isPaid: isPaid), fg: Colors.white, bg: const Color(0x2EFFFFFF));
    return Pill(label(status, isPaid: isPaid), fg: fg, bg: bg);
  }
}

/// Doctor's profile photo loaded from the photo endpoint, falling back to initials.
class DoctorPhoto extends StatelessWidget {
  final int doctorId;
  final String name;
  final bool hasPhoto;
  final double size;
  final bool circle;

  const DoctorPhoto({super.key, required this.doctorId, required this.name, required this.hasPhoto, this.size = 46, this.circle = true});

  @override
  Widget build(BuildContext context) {
    final fallback = DoctorAvatar(name, size: size, circle: circle);
    if (!hasPhoto) return fallback;
    final image = Image.network(
      '${ApiConfig.baseUrl}/api/doctors/$doctorId/photo',
      headers: {if (AuthStore.token != null) 'Authorization': 'Bearer ${AuthStore.token}'},
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
    return circle ? ClipOval(child: image) : ClipRRect(borderRadius: BorderRadius.circular(size * 0.3), child: image);
  }
}

/// Initials in a mint gradient, used for doctors.
class DoctorAvatar extends StatelessWidget {
  final String name;
  final double size;
  final bool circle;

  const DoctorAvatar(this.name, {super.key, this.size = 46, this.circle = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(size * 0.3),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.mintLight, AppColors.mint],
        ),
      ),
      alignment: Alignment.center,
      child: Text(initialsOf(name),
          style: TextStyle(color: AppColors.deep, fontWeight: FontWeight.bold, fontSize: size * 0.36)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const SectionTitle(this.title,
      {super.key, this.action, this.onAction, this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 10)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink))),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!, style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }
}

/// Small uppercase label above a group of controls.
class GroupLabel extends StatelessWidget {
  final String text;
  const GroupLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.8)),
      );
}

/// Selectable chip that animates between white and filled green.
class SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const SelectChip({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: selected ? AppColors.primary : AppColors.line),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 13,
                color: selected ? Colors.white : const Color(0xFF4A5263),
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              )),
        ),
      ),
    );
  }
}

/// Centered icon + message for empty lists.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const EmptyState({super.key, required this.icon, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        IconSquare(icon, size: 64, iconSize: 30),
        const SizedBox(height: 14),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
        if (action != null) ...[const SizedBox(height: 14), action!],
      ]),
    );
  }
}
