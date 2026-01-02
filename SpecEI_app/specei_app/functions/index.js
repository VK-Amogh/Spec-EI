const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp();

/**
 * Cloud Function to reset a user's password using Firebase Admin SDK.
 * This allows password reset without requiring the user to be signed in.
 * 
 * Expected request body:
 * - email: The user's email address
 * - newPassword: The new password to set
 * 
 * Returns:
 * - success: true if password was updated successfully
 * - error: error message if something went wrong
 */
exports.resetPassword = functions.https.onCall(async (data, context) => {
  const { email, newPassword } = data;

  // Validate inputs
  if (!email || typeof email !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'The function must be called with a valid email.'
    );
  }

  if (!newPassword || typeof newPassword !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'The function must be called with a valid new password.'
    );
  }

  // Validate password requirements
  if (newPassword.length < 8) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Password must be at least 8 characters long.'
    );
  }

  try {
    // Get the user by email
    const userRecord = await admin.auth().getUserByEmail(email.trim());

    // Update the user's password
    await admin.auth().updateUser(userRecord.uid, {
      password: newPassword,
    });

    console.log(`Password successfully updated for user: ${email}`);
    
    return { success: true, message: 'Password updated successfully.' };
  } catch (error) {
    console.error('Error resetting password:', error);

    if (error.code === 'auth/user-not-found') {
      throw new functions.https.HttpsError(
        'not-found',
        'No user found with this email address.'
      );
    }

    if (error.code === 'auth/weak-password') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'The password is too weak.'
      );
    }

    throw new functions.https.HttpsError(
      'internal',
      'An error occurred while resetting the password. Please try again.'
    );
  }
});
