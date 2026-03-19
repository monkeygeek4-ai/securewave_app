# Release Notes v1.1.0

**Date:** 2025-11-05
**Version:** 1.1.0+2
**Build Number:** 2

## 🎉 What's New

### iOS CallKit Integration
Full iOS CallKit support for native incoming call experience on iOS devices!

#### Features:
- **Native iOS Call UI**: Incoming calls now appear as native iOS call screens
- **VoIP Push Notifications**: Instant call notifications even when app is closed
- **Lock Screen Integration**: Answer calls directly from the lock screen
- **CallKit Controls**: Native call accept/decline buttons
- **Background Wake-up**: App automatically wakes up for incoming calls

### Platform-Specific Push Notifications

The app now intelligently handles push notifications based on device platform:

#### iOS:
- **VoIP Push** for instant call delivery (Apple Push Notification service)
- **FCM** as fallback for data messages
- **CallKit** integration for native call experience

#### Android:
- **High-priority FCM** for instant call delivery
- **Full-screen call notifications** when app is in background
- **Custom call UI** optimized for Android

## 🔧 Technical Changes

### Frontend (Flutter):

1. **FCM Service Updates** - [lib/services/fcm_service.dart](lib/services/fcm_service.dart)
   - Added VoIP token retrieval for iOS devices
   - Updated token registration to include platform and VoIP token
   - Enhanced logging for debugging

2. **API Service Updates** - [lib/services/api_service.dart](lib/services/api_service.dart)
   - Updated `registerFCMToken()` to accept optional VoIP token parameter
   - Added platform-specific token handling

3. **iOS AppDelegate** - [ios/Runner/AppDelegate.swift](ios/Runner/AppDelegate.swift)
   - Added `getVoIPToken` method for Flutter to retrieve VoIP token
   - Implemented token storage for later retrieval
   - Enhanced VoIP token handling

### Backend (PHP):

1. **WebSocket Call Handler** - [backend/websocket/call_handlers.php](backend/websocket/call_handlers.php)
   - Updated SQL query to fetch `platform` and `voip_token` from database
   - Modified notification sending to use platform-specific logic
   - Removed duplicate VoIP push code (now integrated in FirebaseAdmin)

2. **Firebase Admin** - [backend/lib/FirebaseAdmin.php](backend/lib/FirebaseAdmin.php)
   - Updated `sendCallNotification()` signature to accept 4 parameters:
     - `$platform` - 'ios' or 'android'
     - `$fcmToken` - FCM token
     - `$voipToken` - VoIP Push token (iOS only)
     - `$callData` - Call information
   - Added iOS VoIP Push integration
   - Sends both VoIP Push and FCM for iOS devices

3. **Token Registration Endpoint** - [backend/api/notifications/register.php](backend/api/notifications/register.php)
   - Added support for `voip_token` parameter
   - Updates both `platform` and `voip_token` fields in database
   - Enhanced logging for debugging

4. **Database Migration** - [backend/migrations/add_platform_and_voip_token.sql](backend/migrations/add_platform_and_voip_token.sql)
   - Added `platform` column (VARCHAR(20), default: 'android')
   - Added `voip_token` column (TEXT, nullable)
   - Created indexes for performance

## 📋 Migration Required

### Database Update:
**IMPORTANT:** Run the database migration before deploying this version!

```bash
# Option 1: Using PHP script
cd backend/migrations
php run_migration.php

# Option 2: Using psql
psql -U postgres -d securewave -f backend/migrations/add_platform_and_voip_token.sql
```

See [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for detailed instructions.

## 🐛 Bug Fixes

- Fixed Android package structure conflicts
- Improved token registration error handling
- Enhanced push notification reliability

## 📱 Compatibility

- **iOS**: 12.0+
- **Android**: 6.0+ (API level 23+)
- **Backend**: PHP 7.4+, PostgreSQL 12+

## 🔍 Testing

### iOS CallKit:
1. Install app on iOS device
2. Register and login
3. Have another user call you
4. Observe native iOS call screen appears
5. Test accept/decline from lock screen

### Android:
1. Install app on Android device
2. Register and login
3. Have another user call you
4. Observe full-screen call notification
5. Test accept/decline actions

## 📝 Notes

- iOS devices will automatically re-register with VoIP tokens upon first launch
- Existing Android tokens remain valid and will continue working
- VoIP Push requires proper iOS provisioning profile with VoIP capability
- Backend logs have been enhanced for easier debugging

## 🔗 Documentation

- [Backend CallKit Integration](BACKEND_CALLKIT_INTEGRATION.md) - Technical details
- [Migration Guide](MIGRATION_GUIDE.md) - Database migration instructions
- [iOS Setup](IOS_VOIP_SETUP.md) - iOS VoIP setup guide

## ⚠️ Known Issues

None at this time.

## 👥 Contributors

- Backend integration and database changes
- iOS CallKit implementation
- Frontend token handling
- Testing and documentation

---

**Full Changelog**: v1.0.0...v1.1.0
