import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

class HeartbeatPulseAnimation extends StatefulWidget {
  final int heartRate;
  final double size;

  const HeartbeatPulseAnimation({
    Key? key,
    required this.heartRate,
    this.size = 80,
  }) : super(key: key);

  @override
  State<HeartbeatPulseAnimation> createState() =>
      _HeartbeatPulseAnimationState();
}

class _HeartbeatPulseAnimationState extends State<HeartbeatPulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: (60000 / widget.heartRate).toInt()),
      vsync: this,
    )..repeat();
  }

  @override
  void didUpdateWidget(HeartbeatPulseAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.heartRate != widget.heartRate) {
      _controller.duration =
          Duration(milliseconds: (60000 / widget.heartRate).toInt());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.9, end: 1.1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _getHeartRateColor().withOpacity(0.2),
          border: Border.all(
            color: _getHeartRateColor(),
            width: 2,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.favorite,
            size: widget.size * 0.5,
            color: _getHeartRateColor(),
          ),
        ),
      ),
    );
  }

  Color _getHeartRateColor() {
    if (widget.heartRate >= 60 && widget.heartRate <= 100) {
      return AppColors.heartRateGood;
    } else if (widget.heartRate > 100 && widget.heartRate <= 120) {
      return AppColors.heartRateNormal;
    }
    return AppColors.heartRatePoor;
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  const StatCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.iconColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Icon(
                    icon,
                    color: iconColor ?? AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.grey,
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

class LoadingShimmer extends StatelessWidget {
  final double width;
  final double height;
  final ShapeBorder? shape;

  const LoadingShimmer({
    Key? key,
    this.width = double.infinity,
    this.height = 20,
    this.shape,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: ShapeDecoration(
        shape: shape ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        color: AppColors.lightGrey,
      ),
    );
  }
}

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IconData? icon;

  const CustomButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.backgroundColor,
    this.foregroundColor,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(icon ?? Icons.arrow_forward),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
        ),
      ),
    );
  }
}

class HealthStatusBadge extends StatelessWidget {
  final String status;
  final int? heartRate;

  const HealthStatusBadge({
    Key? key,
    required this.status,
    this.heartRate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final emoji = _getStatusEmoji();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          if (heartRate != null) ...[
            const SizedBox(width: 4),
            Text(
              '$heartRate BPM',
              style: TextStyle(
                color: color,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (status.toLowerCase()) {
      case 'good':
        return AppColors.heartRateGood;
      case 'normal':
        return AppColors.heartRateNormal;
      case 'poor':
      case 'bad':
        return AppColors.heartRatePoor;
      default:
        return AppColors.grey;
    }
  }

  String _getStatusEmoji() {
    switch (status.toLowerCase()) {
      case 'good':
        return '✅';
      case 'normal':
        return '⚠️';
      case 'poor':
      case 'bad':
        return '🔴';
      default:
        return '❓';
    }
  }
}

class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onRetry;

  const EmptyState({
    Key? key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.inbox,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: AppColors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.grey,
                ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}
