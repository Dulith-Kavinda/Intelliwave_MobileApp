import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/main/profile_screen.dart';

class AppBarProfileAvatar extends StatelessWidget {
  const AppBarProfileAvatar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().currentUserModel;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: user == null
            ? Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white24 : Colors.black12,
                ),
                child: const Icon(Icons.person, size: 18),
              )
            : Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white24 : Colors.grey[200],
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  image: user.profilePictureUrl != null && user.profilePictureUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(user.profilePictureUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: user.profilePictureUrl == null || user.profilePictureUrl!.isEmpty
                    ? Center(
                        child: Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      )
                    : null,
              ),
      ),
    );
  }
}
