// ============================================================
// lib/widgets/design_widgets.dart
// Widgets réutilisables pour le design system
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../utils/app_colors.dart';

import '../providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';

// GIF 1×1 transparent — fallback universel sans dépendance d'asset
final _kTransparentImage = Uint8List.fromList([
  0x47,0x49,0x46,0x38,0x39,0x61,0x01,0x00,0x01,0x00,
  0x80,0x00,0x00,0x00,0x00,0x00,0xFF,0xFF,0xFF,0x21,
  0xF9,0x04,0x00,0x00,0x00,0x00,0x00,0x2C,0x00,0x00,
  0x00,0x00,0x01,0x00,0x01,0x00,0x00,0x02,0x02,0x44,
  0x01,0x00,0x3B,
]);

// ===== SAFE IMAGE WIDGET =====
class SafeImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? errorWidget;

  const SafeImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = errorWidget ?? Container(
      width: width,
      height: height,
      color: AppColors.accentOrange.withValues(alpha: 0.2),
      child: const Icon(Icons.broken_image, size: 40),
    );

    if (url == null || url!.isEmpty) return fallback;

    if (url!.startsWith('data:image/')) {
      try {
        final base64Str = url!.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes, width: width, height: height, fit: fit,
            errorBuilder: (_, __, ___) => fallback);
      } catch (_) {
        return fallback;
      }
    }

    if (url!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, __) => Container(
          width: width,
          height: height,
          color: Colors.black12,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => fallback,
      );
    } else if (url!.startsWith('/uploads/') || url!.startsWith('uploads/')) {
      final path = url!.startsWith('/') ? url! : '/$url';
      final fullUrl = '${ApiService.baseUrl}$path';
      return CachedNetworkImage(
        imageUrl: fullUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, __) => Container(
          width: width,
          height: height,
          color: Colors.black12,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => fallback,
      );
    } else if (url!.startsWith('assets/')) {
      return Image.asset(
        url!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => fallback,
      );
    } else if (!kIsWeb) {
      // Chemin local — vérifie que le fichier existe avant de le charger
      final file = File(url!);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => fallback,
        );
      }
      return fallback;
    } else {
      return fallback;
    }
  }
}

// ===== SAFE IMAGE PROVIDER (pour DecorationImage) =====
ImageProvider getSafeImageProvider(String? url) {
  if (url == null || url.isEmpty) {
    return MemoryImage(_kTransparentImage);
  }
  // Base64 data URL (stockée telle quelle par le web admin)
  if (url.startsWith('data:image/')) {
    try {
      final base64Str = url.split(',').last;
      final bytes = base64Decode(base64Str);
      return MemoryImage(bytes);
    } catch (_) {
      return MemoryImage(_kTransparentImage);
    }
  }
  if (url.startsWith('http')) {
    return NetworkImage(url);
  } else if (url.startsWith('/uploads/') || url.startsWith('uploads/')) {
    final path = url.startsWith('/') ? url : '/$url';
    return CachedNetworkImageProvider('${ApiService.baseUrl}$path');
  } else if (url.startsWith('assets/')) {
    return AssetImage(url);
  } else if (!kIsWeb) {
    final file = File(url);
    if (file.existsSync()) return FileImage(file);
    return MemoryImage(_kTransparentImage);
  }
  return MemoryImage(_kTransparentImage);
}

// ===== PREMIUM DASHBOARD HEADER =====
class PremiumHeaderWidget extends StatefulWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLogoutTap;
  final VoidCallback? onChatTap;
  final VoidCallback? onSyncTap;
  final int notificationCount;

  const PremiumHeaderWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.onNotificationTap,
    this.onProfileTap,
    this.onLogoutTap,
    this.onChatTap,
    this.onSyncTap,
    this.notificationCount = 0,
  });

  @override
  State<PremiumHeaderWidget> createState() => _PremiumHeaderWidgetState();
}

class _PremiumHeaderWidgetState extends State<PremiumHeaderWidget> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.getTextColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    if (widget.subtitle != null)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: textColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sync Button
                      if (widget.onSyncTap != null)
                        IconButton(
                          icon: const Icon(Icons.sync_rounded, color: AppColors.accentBlue, size: 20),
                          onPressed: widget.onSyncTap,
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          tooltip: 'Synchroniser',
                        ),
                      // Language picker (FR / EN / Fon)
                      Consumer<AppProvider>(
                        builder: (context, appProvider, _) {
                          final lang = appProvider.locale.languageCode;
                          final langLabel = lang == 'fon' ? 'FON' : lang.toUpperCase();
                          return PopupMenuButton<String>(
                            onSelected: (code) => appProvider.setLocale(Locale(code)),
                            tooltip: 'Changer de langue',
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'fr', child: Text('🇫🇷 Français')),
                              const PopupMenuItem(value: 'en', child: Text('🇬🇧 English')),
                              const PopupMenuItem(value: 'fon', child: Text('🇧🇯 Fon')),
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accentOrange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(langLabel, style: const TextStyle(color: AppColors.accentOrange, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      // Support/Chat Admin (Icône "Net")
                      IconButton(
                        icon: Icon(Icons.chat_bubble_outline_rounded, color: textColor, size: 20),
                        onPressed: widget.onChatTap,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        tooltip: 'Contacter l\'Admin',
                      ),
                      // Notifications
                      Stack(
                        children: [
                          IconButton(
                            icon: Icon(Icons.notifications_none_rounded, color: textColor, size: 20),
                            onPressed: widget.onNotificationTap,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                          ),
                          if (widget.notificationCount > 0)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.accentRed,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: isDark ? const Color(0xFF0D0D1A) : Colors.white, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
                                  ],
                                ),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                child: Center(
                                  child: Text(
                                    widget.notificationCount > 9 ? '9+' : '${widget.notificationCount}',
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 2),
                      // Profile
                      GestureDetector(
                        onTap: widget.onProfileTap,
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.accentOrange,
                          child: Icon(
                            Icons.person,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Logout
                      IconButton(
                        icon: const Icon(Icons.logout, color: AppColors.accentRed, size: 18),
                        onPressed: widget.onLogoutTap,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        tooltip: 'Déconnexion',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Date & Time Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.accentOrange),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _getFormattedDate(context),
                    style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.access_time_rounded, size: 12, color: AppColors.accentOrange),
                const SizedBox(width: 4),
                Text(
                  DateFormat('HH:mm').format(_now),
                  style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getFormattedDate(BuildContext context) {
    try {
      final locale = context.read<AppProvider>().locale.languageCode;
      final String intlLocale = locale == 'en' ? 'en_US' : 'fr_FR';
      return DateFormat('EEEE, d MMMM yyyy', intlLocale).format(_now);
    } catch (e) {
      return DateFormat('EEEE, d MMMM yyyy', 'fr_FR').format(_now);
    }
  }
}

// ===== CARTE DE BIEN (IMMOBILIER) AVEC IMAGE RÉELLE =====
class BienCardWidget extends StatelessWidget {
  final String titre;
  final String lieu;
  final int prix;
  final int pieces;
  final double rating;
  final String? imageUrl;
  final bool isFavorite;
  final bool isOwnerCertified;
  final VoidCallback? onTap;
  final VoidCallback? onFavoris;
  final VoidCallback? onCandidater;

  const BienCardWidget({
    super.key,
    required this.titre,
    required this.lieu,
    required this.prix,
    required this.pieces,
    required this.rating,
    this.imageUrl,
    this.isFavorite = false,
    this.isOwnerCertified = false,
    this.onTap,
    this.onFavoris,
    this.onCandidater,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Hero(
      tag: 'bien_$titre',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Section
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Stack(
                    children: [
                      Container(
                        height: 220,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          image: imageUrl != null ? DecorationImage(image: getSafeImageProvider(imageUrl!), fit: BoxFit.cover) : null,
                        ),
                        child: imageUrl == null ? const Center(child: Icon(Icons.home_work, size: 50, color: Colors.white24)) : null,
                      ),
                      // Overlay Dégradé pour lisibilité
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                            ),
                          ),
                        ),
                      ),
                      // Prix (Badge Premium)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: GlassContainer(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          borderRadius: BorderRadius.circular(30),
                          child: Text(
                            '$prix FCFA',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                      // Titre et lieu sur l'image
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    titre,
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 10, color: Colors.black.withValues(alpha: 0.5))]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isOwnerCertified) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified, color: Colors.blue, size: 18),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 12, color: AppColors.accentOrange),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    lieu,
                                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Footer Section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _buildMiniSpec(context, Icons.bed_rounded, pieces.toString()),
                          const SizedBox(width: 12),
                          _buildMiniSpec(context, Icons.star_rounded, rating.toString(), color: AppColors.accentYellow),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: onCandidater,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentOrange,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 0,
                        ),
                        child: const Text('Voir Détails', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniSpec(BuildContext context, IconData icon, String value, {Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = color ?? (isDark ? Colors.white60 : Colors.black45);
    final textColor = isDark ? Colors.white : AppColors.textDark;
    
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ===== GLASSMORPHISM CONTAINER =====
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? color;
  final double blur;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.color,
    this.blur = 10,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: isDark 
              ? (color ?? Colors.white).withValues(alpha: 0.1) 
              : (color ?? Colors.black).withValues(alpha: 0.05),
          borderRadius: borderRadius ?? BorderRadius.circular(16),
          border: Border.all(
            color: isDark 
                ? Colors.white.withValues(alpha: 0.15) 
                : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        child: child,
      ),
    );
  }
}

// ===== KPI CARD (STATISTIQUES) AVEC ANIMATION =====
class KpiCardWidget extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? trend;
  final bool showTrend;

  const KpiCardWidget({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
    this.trend,
    this.showTrend = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.getCardColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white.withValues(alpha: 0.05) 
                  : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10, 
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white70 
                      : AppColors.textMedium
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (showTrend && trend != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: trend!.startsWith('+') 
                        ? AppColors.success.withValues(alpha: 0.1) 
                        : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trend!.startsWith('+') ? Icons.trending_up : Icons.trending_down,
                        size: 10,
                        color: trend!.startsWith('+') ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        trend!,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: trend!.startsWith('+') ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ===== ACTION BUTTON (CTA) AVEC VARIANTS =====
class ActionButtonWidget extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final ButtonVariant variant;
  final double? width;
  final bool isLoading;
  final bool isFullWidth;

  const ActionButtonWidget({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.width,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle = _getButtonStyle();
    
    final button = isFullWidth
        ? SizedBox(
            width: double.infinity,
            child: _buildButton(buttonStyle),
          )
        : _buildButton(buttonStyle);
    
    if (width != null) {
      return SizedBox(width: width, child: button);
    }
    
    return button;
  }

  Widget _buildButton(ButtonStyle style) {
    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon, size: 18),
        label: Text(label),
        style: style,
      );
    }
    
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: style,
      child: isLoading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(label),
    );
  }

  ButtonStyle _getButtonStyle() {
    Color backgroundColor;
    Color foregroundColor = Colors.white;
    
    switch (variant) {
      case ButtonVariant.primary:
        backgroundColor = AppColors.ctaOrange;
        break;
      case ButtonVariant.secondary:
        backgroundColor = AppColors.primaryBlue;
        break;
      case ButtonVariant.warning:
        backgroundColor = AppColors.ctaOrange;
        break;
      case ButtonVariant.danger:
        backgroundColor = AppColors.accentRed;
        break;
      case ButtonVariant.outline:
        backgroundColor = Colors.transparent;
        foregroundColor = AppColors.ctaOrange;
        break;
      case ButtonVariant.text:
        backgroundColor = Colors.transparent;
        foregroundColor = AppColors.ctaOrange;
        break;
    }
    
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: variant == ButtonVariant.outline 
            ? const BorderSide(color: AppColors.ctaOrange) 
            : BorderSide.none,
      ),
      elevation: variant == ButtonVariant.text ? 0 : 2,
    );
  }
}

enum ButtonVariant {
  primary,
  secondary,
  warning,
  danger,
  outline,
  text,
}

// ===== SECTION HEADER AVEC ANIMATION =====
class SectionHeaderWidget extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;
  final IconData? icon;

  const SectionHeaderWidget({
    super.key,
    required this.title,
    this.actionText,
    this.onAction,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.ctaOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.ctaOrange),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextColor(context),
            ),
          ),
        ),
        if (actionText != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.ctaOrange,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Row(
              children: [
                Text(
                  actionText!,
                  style: const TextStyle(
                    color: AppColors.ctaOrange,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.ctaOrange),
              ],
            ),
          ),
      ],
    );
  }
}

// ===== USER INFO CARD AVEC PHOTO DE PROFIL =====
class UserInfoCardWidget extends StatelessWidget {
  final String name;
  final String role;
  final String email;
  final String? avatar;
  final String? initials;
  final VoidCallback? onEdit;

  const UserInfoCardWidget({
    super.key,
    required this.name,
    required this.role,
    required this.email,
    this.avatar,
    this.initials,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.white.withValues(alpha: 0.05) 
              : Colors.black.withValues(alpha: 0.05)
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.backgroundNeutral,
                child: avatar != null
                    ? ClipOval(
                        child: SafeImage(
                          url: avatar!,
                          width: 68,
                          height: 68,
                          fit: BoxFit.cover,
                          errorWidget: _buildAvatarText(),
                        ),
                      )
                    : _buildAvatarText(),
              ),
              if (onEdit != null)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: GestureDetector(
                      onTap: onEdit,
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: AppColors.ctaOrange,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    role,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.getTextColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.email_outlined, size: 12, color: AppColors.textLight),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        email,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarText() {
    return Text(
      initials ?? (name.isNotEmpty ? name[0].toUpperCase() : 'U'),
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: AppColors.ctaOrange,
      ),
    );
  }
}

// ===== CARTE DE STATISTIQUE AVANCÉE =====
class StatCardWidget extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final double? progress;
  final VoidCallback? onTap;

  const StatCardWidget({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
                if (progress != null)
                  Text(
                    '${(progress! * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 13, color: AppColors.textLight),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(fontSize: 11, color: AppColors.textLight),
              ),
            ],
            if (progress != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: color.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ===== CHARGEMENT AVEC ANIMATION =====
class LoadingWidget extends StatelessWidget {
  final String? message;
  final Color? color;

  const LoadingWidget({super.key, this.message, this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.ctaOrange,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(color: color ?? AppColors.textLight),
            ),
          ],
        ],
      ),
    );
  }
}

// ===== ÉTAT VIDE AVEC ICÔNE =====
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? buttonText;
  final VoidCallback? onButtonPressed;

  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.buttonText,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.ctaOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppColors.ctaOrange.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onButtonPressed,
                icon: const Icon(Icons.add_rounded),
                label: Text(buttonText!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ctaOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ===== BADGE DE STATUT =====
class StatusBadgeWidget extends StatelessWidget {
  final String label;
  final StatusType type;

  const StatusBadgeWidget({
    super.key,
    required this.label,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    
    switch (type) {
      case StatusType.success:
        color = AppColors.success;
        icon = Icons.check_circle_rounded;
        break;
      case StatusType.warning:
        color = AppColors.warning;
        icon = Icons.warning_rounded;
        break;
      case StatusType.error:
        color = AppColors.error;
        icon = Icons.error_rounded;
        break;
      case StatusType.info:
        color = AppColors.accentBlue;
        icon = Icons.info_rounded;
        break;
      case StatusType.pending:
        color = AppColors.ctaOrange;
        icon = Icons.hourglass_top_rounded;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

enum StatusType {
  success,
  warning,
  error,
  info,
  pending,
}

// ===== CHAMP DE RECHERCHE STYLISÉ =====
class SearchFieldWidget extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final VoidCallback? onSearch;
  final VoidCallback? onFilter;

  const SearchFieldWidget({
    super.key,
    required this.controller,
    this.hintText = 'Rechercher...',
    this.onSearch,
    this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = AppColors.getCardColor(context);
    final textColor = AppColors.getTextColor(context);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onSubmitted: (_) => onSearch?.call(),
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
          prefixIcon: Icon(Icons.search_rounded, color: textColor.withValues(alpha: 0.5)),
          suffixIcon: onFilter != null
              ? IconButton(
                  icon: Icon(Icons.tune_rounded, color: textColor.withValues(alpha: 0.5)),
                  onPressed: onFilter,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: cardColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ===== MODAL BOTTOM SHEET PERSONNALISÉ =====
class CustomBottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final double? height;

  const CustomBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = AppColors.getCardColor(context);
    final textColor = AppColors.getTextColor(context);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          // Content
          Expanded(child: child),
        ],
      ),
    );
  }

  static Future<T?> show<T>(BuildContext context, {
    required String title,
    required Widget child,
    double? height,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CustomBottomSheet(
        title: title,
        height: height ?? MediaQuery.of(context).size.height * 0.8,
        child: child,
      ),
    );
  }
}

// ===== MODERN TEXT FIELD =====
class ModernTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;

  const ModernTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.getTextColor(context);
    final fillColor = AppColors.getInputFillColor(context);
    final borderColor = AppColors.getInputBorderColor(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
          prefixIcon: Icon(icon, color: AppColors.accentOrange, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}

// ===== MODERN BUTTON =====
class ModernButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  final bool isLoading;
  final IconData? icon;

  final double? width;
  final double? height;
  final double? fontSize;

  const ModernButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height ?? 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color ?? AppColors.accentOrange,
            (color ?? AppColors.accentOrange).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (color ?? AppColors.accentOrange).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: isLoading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, color: Colors.white), const SizedBox(width: 10)],
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(text, style: TextStyle(color: Colors.white, fontSize: fontSize ?? 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ===== MODERN PASSWORD FIELD =====
class ModernPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;

  const ModernPasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
  });

  @override
  State<ModernPasswordField> createState() => _ModernPasswordFieldState();
}

class _ModernPasswordFieldState extends State<ModernPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.getTextColor(context);
    final fillColor = AppColors.getInputFillColor(context);
    final borderColor = AppColors.getInputBorderColor(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: TextFormField(
        controller: widget.controller,
        obscureText: _obscure,
        validator: widget.validator,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
          prefixIcon: const Icon(Icons.lock_outline, color: AppColors.accentOrange, size: 20),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: textColor.withValues(alpha: 0.38), size: 20),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}

// ===== VIDEO PREVIEW WIDGET =====
class VideoPreviewWidget extends StatelessWidget {
  final String videoUrl;
  final double height;
  final String? thumbnail;

  const VideoPreviewWidget({
    super.key,
    required this.videoUrl,
    this.height = 200,
    this.thumbnail,
  });

  @override
  Widget build(BuildContext context) {
    String finalUrl = videoUrl;
    if (!videoUrl.startsWith('http') && !videoUrl.startsWith('assets/') && !videoUrl.startsWith('file://') && !videoUrl.startsWith('/')) {
      // Relative path from server
      finalUrl = '${ApiService.baseUrl}${videoUrl.startsWith('/') ? '' : '/'}$videoUrl';
    } else if (videoUrl.startsWith('/uploads/')) {
        finalUrl = '${ApiService.baseUrl}$videoUrl';
    }

    final bool isYoutube = finalUrl.contains('youtube.com') || finalUrl.contains('youtu.be');
    
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        image: thumbnail != null 
          ? DecorationImage(image: getSafeImageProvider(thumbnail), fit: BoxFit.cover, opacity: 0.5)
          : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (thumbnail == null)
            Icon(isYoutube ? Icons.video_library_rounded : Icons.movie_filter_rounded, size: 64, color: Colors.white12),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentBlue.withValues(alpha: 0.8),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: AppColors.accentBlue.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 5),
              ],
            ),
            child: const Icon(Icons.play_arrow_rounded, size: 40, color: Colors.white),
          ),
          
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Icon(isYoutube ? Icons.public_rounded : Icons.info_outline, size: 14, color: Colors.white70),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isYoutube ? 'Regarder sur YouTube' : 'Ouvrir la vidéo',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _launchVideo(context, finalUrl),
              borderRadius: BorderRadius.circular(20),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchVideo(BuildContext context, String url) async {
    try {
      final Uri uri = Uri.parse(url);
      bool launched = false;
      
      if (await canLaunchUrl(uri)) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      
      if (!launched) {
        // Try as non-external just in case or browse
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le lecteur vidéo.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }
}