import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wayfarer/Screens/login_screen.dart';
// import 'screens/login_screen.dart'; // Make sure this path is correct

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Change Password Option
          Card(
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Change Password'),
              onTap: () => _showChangePasswordDialog(context),
            ),
          ),
          const SizedBox(height: 16),
          // Logout Option
          Card(
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () => _showLogoutConfirmationDialog(context),
            ),
          ),
          const SizedBox(height: 16),
          // Delete Account Option
          Card(
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Delete Account',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => _showDeleteAccountDialog(context),
            ),
          ),
        ],
      ),
    );
  }

  // Dialog for changing password
  void _showChangePasswordDialog(BuildContext context) {
    final TextEditingController oldPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();
    String? errorMessage;
    bool isLoading = false;
    bool _obscureOldPassword = true;
    bool _obscureNewPassword = true;
    bool _obscureConfirmPassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Change Password'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: oldPasswordController,
                          obscureText: _obscureOldPassword,
                          decoration: InputDecoration(
                            labelText: 'Current Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureOldPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureOldPassword = !_obscureOldPassword;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: newPasswordController,
                          obscureText: _obscureNewPassword,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureNewPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureNewPassword = !_obscureNewPassword;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: () async {
                          // Clear previous errors
                          setState(() {
                            errorMessage = null;
                            isLoading = true;
                          });

                          // Validate passwords
                          if (newPasswordController.text !=
                              confirmPasswordController.text) {
                            setState(() {
                              errorMessage = 'New passwords do not match';
                              isLoading = false;
                            });
                            return;
                          }

                          try {
                            // Get current user
                            final user = FirebaseAuth.instance.currentUser;

                            if (user == null) {
                              setState(() {
                                errorMessage = 'No user is signed in';
                                isLoading = false;
                              });
                              return;
                            }

                            // Create credential with old password
                            AuthCredential credential =
                                EmailAuthProvider.credential(
                                  email: user.email!,
                                  password: oldPasswordController.text,
                                );

                            // Re-authenticate user
                            await user.reauthenticateWithCredential(credential);

                            // Change password
                            await user.updatePassword(
                              newPasswordController.text,
                            );

                            // Close dialog and show success
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password changed successfully'),
                              ),
                            );
                          } on FirebaseAuthException catch (e) {
                            String message = 'Failed to change password';

                            if (e.code == 'wrong-password') {
                              message = 'Current password is incorrect';
                            } else if (e.code == 'weak-password') {
                              message = 'New password is too weak';
                            } else if (e.code == 'requires-recent-login') {
                              message =
                                  'Please sign in again before changing your password';
                            } else {
                              message = 'Error: ${e.message}';
                            }

                            setState(() {
                              errorMessage = message;
                              isLoading = false;
                            });
                          } catch (e) {
                            setState(() {
                              errorMessage = 'Error: ${e.toString()}';
                              isLoading = false;
                            });
                          }
                        },
                        child: const Text('Change Password'),
                      ),
                  ],
                ),
          ),
    );
  }

  // Dialog for logout confirmation
  void _showLogoutConfirmationDialog(BuildContext context) {
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Logout'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Are you sure you want to logout?'),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () async {
                          setState(() {
                            isLoading = true;
                            errorMessage = null;
                          });

                          try {
                            // Sign out user
                            await FirebaseAuth.instance.signOut();

                            // Navigate to login screen using MaterialPageRoute instead of named route
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => LoginScreen(),
                              ),
                              (route) => false,
                            );
                          } catch (e) {
                            setState(() {
                              errorMessage =
                                  'Error signing out: ${e.toString()}';
                              isLoading = false;
                            });
                          }
                        },
                        child: const Text('Logout'),
                      ),
                  ],
                ),
          ),
    );
  }

  // Dialog for delete account confirmation
  void _showDeleteAccountDialog(BuildContext context) {
    final TextEditingController passwordController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;
    bool obscurePassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Delete Account'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Warning: This action cannot be undone. All your data will be permanently deleted.',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Please enter your password to confirm:'),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () async {
                          setState(() {
                            isLoading = true;
                            errorMessage = null;
                          });

                          try {
                            // Get current user
                            final user = FirebaseAuth.instance.currentUser;

                            if (user == null) {
                              setState(() {
                                errorMessage = 'No user is signed in';
                                isLoading = false;
                              });
                              return;
                            }

                            // Create credential with password
                            AuthCredential credential =
                                EmailAuthProvider.credential(
                                  email: user.email!,
                                  password: passwordController.text,
                                );

                            // Re-authenticate user
                            await user.reauthenticateWithCredential(credential);

                            // Delete the user account
                            await user.delete();

                            // Navigate to login screen
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => LoginScreen(),
                              ),
                              (route) => false,
                            );

                            // Show success message
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Account successfully deleted'),
                              ),
                            );
                          } on FirebaseAuthException catch (e) {
                            String message = 'Failed to delete account';

                            if (e.code == 'wrong-password') {
                              message = 'Password is incorrect';
                            } else if (e.code == 'requires-recent-login') {
                              message =
                                  'Please sign in again before deleting your account';
                            } else {
                              message = 'Error: ${e.message}';
                            }

                            setState(() {
                              errorMessage = message;
                              isLoading = false;
                            });
                          } catch (e) {
                            setState(() {
                              errorMessage = 'Error: ${e.toString()}';
                              isLoading = false;
                            });
                          }
                        },
                        child: const Text('Delete Account'),
                      ),
                  ],
                ),
          ),
    );
  }
}
