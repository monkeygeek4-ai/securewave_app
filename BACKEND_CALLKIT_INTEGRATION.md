# Backend CallKit Integration - Changes Summary

**Date:** 2025-11-05
**Purpose:** Integrate iOS CallKit support with platform-specific push notifications

## Overview

The backend has been updated to support iOS CallKit integration by properly handling platform-specific push notification tokens (FCM for Android, VoIP Push for iOS).

## Changes Made

### 1. Updated WebSocket Call Handler

**File:** [backend/websocket/call_handlers.php](backend/websocket/call_handlers.php)

**Changes in `handleCallOffer` function (lines 312-361):**

- **Before:** Only queried `token` from `fcm_tokens` table
- **After:** Now queries `token`, `platform`, and `voip_token` from `fcm_tokens` table

```php
// OLD CODE:
$tokens = $db->fetchAll(
    "SELECT token FROM fcm_tokens WHERE user_id = :user_id",
    ['user_id' => $receiverId]
);

// NEW CODE:
$tokens = $db->fetchAll(
    "SELECT token, platform, voip_token FROM fcm_tokens WHERE user_id = :user_id",
    ['user_id' => $receiverId]
);
```

- **Updated notification sending logic:** Now passes three parameters to `sendCallNotification`:
  1. `$platform` - 'ios' or 'android'
  2. `$fcmToken` - FCM token for the device
  3. `$voipToken` - VoIP Push token (for iOS only, null for Android)

```php
$result = $firebaseAdmin->sendCallNotification(
    $platform,
    $fcmToken,
    $voipToken,
    [
        'callId' => $callId,
        'callerName' => $caller['username'] ?? $caller['email'] ?? 'Unknown',
        'callType' => $callType,
        'callerAvatar' => $caller['avatar_url'] ?? '',
    ]
);
```

- **Removed duplicate VoIP Push code:** The old separate VoIP push logic has been removed as it's now integrated into the unified notification system.

### 2. Database Schema Changes

**Migration Script:** [backend/migrations/add_platform_and_voip_token.sql](backend/migrations/add_platform_and_voip_token.sql)

**New columns added to `fcm_tokens` table:**

1. **`platform`** (VARCHAR(20), default: 'android')
   - Stores the device platform ('ios' or 'android')
   - Used to determine which push notification service to use

2. **`voip_token`** (TEXT, nullable)
   - Stores the iOS VoIP Push token
   - Only populated for iOS devices
   - NULL for Android devices

**Indexes created:**
- `idx_fcm_tokens_platform` - For faster platform-based queries
- `idx_fcm_tokens_voip_token` - For faster VoIP token lookups (partial index on non-null values)

## How It Works Now

### For iOS Devices:

1. Client registers both FCM token and VoIP token
2. Backend stores both tokens with `platform = 'ios'`
3. When incoming call occurs:
   - System queries for user's tokens including platform and voip_token
   - `FirebaseAdmin::sendCallNotification()` receives iOS platform
   - Sends **both** FCM data message AND VoIP Push
   - CallKit wakes up the app via VoIP Push
   - App displays native CallKit interface

### For Android Devices:

1. Client registers FCM token with `platform = 'android'`
2. `voip_token` remains NULL
3. When incoming call occurs:
   - System queries for user's tokens
   - `FirebaseAdmin::sendCallNotification()` receives Android platform
   - Sends only FCM high-priority data message
   - App shows custom notification or full-screen intent

## Migration Steps

### Required Actions:

1. **Run the SQL migration script:**
   ```bash
   psql -U your_username -d your_database -f backend/migrations/add_platform_and_voip_token.sql
   ```

2. **Verify the migration:**
   ```sql
   -- Check that new columns exist
   SELECT column_name, data_type, column_default
   FROM information_schema.columns
   WHERE table_name = 'fcm_tokens'
   AND column_name IN ('platform', 'voip_token');

   -- Check indexes
   SELECT indexname, indexdef
   FROM pg_indexes
   WHERE tablename = 'fcm_tokens';
   ```

3. **Update existing tokens (if needed):**
   - Existing tokens will have `platform = 'android'` by default
   - iOS devices will need to re-register to populate their platform and voip_token
   - You may want to clear old tokens to force re-registration:
   ```sql
   -- Optional: Clear old tokens to force re-registration
   DELETE FROM fcm_tokens WHERE platform IS NULL;
   ```

## Testing

### Test iOS VoIP Push:

1. Ensure iOS device has registered both FCM and VoIP tokens
2. Make sure `platform = 'ios'` and `voip_token` is set in database
3. Initiate a call from another device
4. Check backend logs for:
   ```
   📤 Sending notification for platform: ios
   FCM token: ...
   VoIP token: ...
   ✅✅✅ Notification sent successfully for platform: ios
   ```

### Test Android FCM:

1. Ensure Android device has registered FCM token
2. Make sure `platform = 'android'` in database
3. Initiate a call from another device
4. Check backend logs for:
   ```
   📤 Sending notification for platform: android
   FCM token: ...
   ✅✅✅ Notification sent successfully for platform: android
   ```

## Dependencies

### Backend Requirements:

- `FirebaseAdmin` class must implement updated `sendCallNotification()` method
- `VoIPPush` class for iOS push notifications
- PostgreSQL database (uses `information_schema` for migration checks)

### Expected Signature:

```php
class FirebaseAdmin {
    public function sendCallNotification(
        string $platform,      // 'ios' or 'android'
        string $fcmToken,      // FCM token
        ?string $voipToken,    // VoIP token (iOS only)
        array $callData        // Call information
    ): bool;
}
```

## Rollback Plan

If you need to rollback these changes:

1. **Restore old code:**
   ```bash
   git revert <commit-hash>
   ```

2. **Optional: Remove new database columns:**
   ```sql
   ALTER TABLE fcm_tokens DROP COLUMN IF EXISTS platform;
   ALTER TABLE fcm_tokens DROP COLUMN IF EXISTS voip_token;
   DROP INDEX IF EXISTS idx_fcm_tokens_platform;
   DROP INDEX IF EXISTS idx_fcm_tokens_voip_token;
   ```

## Notes

- The system is backward compatible - Android devices will continue working without any changes
- iOS devices need to update their app to send both tokens
- VoIP token is only used for iOS CallKit integration
- The platform field helps route notifications to the correct service
- Logging has been enhanced to show which platform is being targeted

## Related Files

- [backend/websocket/call_handlers.php](backend/websocket/call_handlers.php) - WebSocket call handling
- [backend/lib/FirebaseAdmin.php](backend/lib/FirebaseAdmin.php) - Firebase Cloud Messaging
- [backend/lib/VoIPPush.php](backend/lib/VoIPPush.php) - iOS VoIP Push notifications
- [backend/migrations/add_platform_and_voip_token.sql](backend/migrations/add_platform_and_voip_token.sql) - Database migration
- [lib/services/fcm_service.dart](lib/services/fcm_service.dart) - Flutter FCM service (client-side)

## Next Steps

1. ✅ Run database migration
2. ✅ Verify FirebaseAdmin class has updated sendCallNotification method
3. ✅ Test with both iOS and Android devices
4. ✅ Monitor logs for any errors
5. ✅ Update client apps to send platform and voip_token on registration
