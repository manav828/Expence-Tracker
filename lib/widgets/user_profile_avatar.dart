import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../core/theme/app_colors.dart';


class UserProfileAvatar extends StatelessWidget {
  final double size;
  final VoidCallback? onTap;
  final bool showBorder;

  const UserProfileAvatar({
    super.key,
    this.size = 34,
    this.onTap,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = AuthService.instance.userAvatarUrl;
    final initial = AuthService.instance.userInitial;

    Widget avatarContent;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarContent = ClipOval(
        child: Image.network(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildLetterAvatar(initial),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLetterAvatar(initial);
          },
        ),
      );
    } else {
      avatarContent = _buildLetterAvatar(initial);
    }

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(color: AppColors.primaryBorder, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: avatarContent,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: avatar,
      );
    }
    return avatar;
  }

  Widget _buildLetterAvatar(String letter) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.44,
          height: 1.1,
        ),
      ),
    );
  }
}
