# Authentication Troubleshooting Guide

## Common Issues and Solutions

### 1. Firebase Configuration Issues

**Problem**: Authentication fails with network or configuration errors.

**Solutions**:
- Ensure Firebase project is properly set up
- Check that `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are in the correct locations
- Verify Firebase Authentication is enabled in your Firebase console
- Make sure Email/Password authentication is enabled in Firebase Auth settings

### 2. Network Connectivity Issues

**Problem**: App can't connect to Firebase services.

**Solutions**:
- Check internet connection
- Ensure firewall isn't blocking the connection
- Try running on a different network
- Check if Firebase services are down

### 3. Admin Access Issues

**Problem**: Admin users can't access admin panel.

**Solutions**:
- Update admin emails in `auth_state.dart`:
  ```dart
  static const Set<String> _adminEmails = {
    'your-actual-admin-email@domain.com',
    // Add your real admin emails here
  };
  ```

### 4. Password Requirements

**Problem**: Signup fails due to weak passwords.

**Solutions**:
- Firebase requires passwords to be at least 6 characters
- Consider using a mix of letters, numbers, and symbols
- The app validates minimum 6 characters for signup

### 5. Email Validation

**Problem**: Invalid email format errors.

**Solutions**:
- Ensure email contains '@' symbol
- Check for proper email format (e.g., user@domain.com)
- Avoid spaces in email addresses

### 6. Debug Information

The app includes debug features when running in debug mode:
- Test Firebase connection button on login screen
- Fill admin credentials button on login screen
- Fill admin account details button on signup screen
- Console logs for authentication attempts
- Detailed error messages in snackbars

### 6.1. Navigation Flow

**Signup Flow**:
1. User fills signup form
2. Account is created in Firebase
3. User is redirected to login screen with success message
4. User must login to access the app

**Login Flow**:
1. User enters credentials
2. If successful:
   - Regular users → redirected to home screen
   - Admin users → redirected to admin panel
3. If failed → error message displayed

**Admin Access**:
- Admin users can access admin panel from login
- Admin panel has logout button to return to login
- Regular users cannot access admin panel

### 7. Testing Authentication

To test the authentication system:

1. **Create a test account**:
   - Use a valid email format
   - Use a password with at least 6 characters
   - Try signing up with the signup form
   - **Note**: After signup, you'll be redirected to login screen

2. **Test login**:
   - Use the credentials from step 1
   - Check console logs for detailed error information
   - After successful login, you'll be redirected to home screen

3. **Test admin access**:
   - **Option 1**: Use the debug button "Fill Admin Account Details" on signup screen
   - **Option 2**: Use the debug button "Fill Admin Credentials" on login screen
   - **Option 3**: Manually add your email to the admin emails list in `auth_state.dart`
   - Sign up or login with admin email (e.g., `admin@quizbit.com`)
   - You should be redirected to the admin panel
   - Use the logout button in admin panel to return to login screen

### 8. Firebase Console Setup

Ensure your Firebase project has:

1. **Authentication enabled**:
   - Go to Firebase Console > Authentication
   - Enable Email/Password sign-in method

2. **Firestore Database enabled**:
   - Go to Firebase Console > Firestore Database
   - Create database if not exists
   - Set up security rules

3. **Proper security rules**:
   ```javascript
   // Example Firestore rules
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
       match /quizzes/{quizId} {
         allow read: if request.auth != null;
         allow write: if request.auth != null && 
           request.auth.token.email in ['admin@example.com'];
       }
     }
   }
   ```

### 9. Common Error Messages

- **"Invalid email or password"**: Check credentials or create account first
- **"Email already in use"**: Try logging in instead of signing up
- **"Weak password"**: Use a password with at least 6 characters
- **"Network error"**: Check internet connection and Firebase configuration
- **"Access denied"**: Ensure admin email is in the whitelist

### 10. Getting Help

If issues persist:
1. Check the console logs for detailed error messages
2. Verify Firebase project configuration
3. Test with a simple email/password combination
4. Ensure all dependencies are properly installed (`flutter pub get`)
