# Caller App

A Flutter-based caller identification application that displays caller information from a local PIMS database during incoming calls. The app shows caller details in an overlay window and maintains a call history log.

## Features

- Real-time caller identification
- Overlay notifications for incoming calls
- Detailed contact information display
- Call history logging
- Contact photo display
- Background service for call detection
- Works in both foreground and background

## Prerequisites

Before you begin, ensure you have:

1. **Flutter Development Environment**:
   - Flutter SDK (latest stable version)
   - Dart SDK
   - Android Studio or VS Code with Flutter extensions
   - Android SDK with minimum API level 21 (Android 5.0)

2. **Required Databases**:
   - `pims.db`: Contains contact information
   - `images_resize.db`: Contains contact photos
   
   Both databases should be placed in the app's local database directory:
   ```
   Android/data/com.example.caller_app/databases/
   ```

3. **Android Permissions**:
   - Phone State
   - Overlay Permission
   - Notification Permission
   - Read Call Log
   - Foreground Service

## Installation

1. Clone the repository:
   ```bash
   git clone [repository-url]
   cd caller_app
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Copy required databases:
   - Copy `pims.db` and `images_resize.db` to the app's database directory
   - The app will guide you through the database setup process

4. Run the app:
   ```bash
   flutter run
   ```

## Database Schema

### PIMS Database (pims.db)
Required tables:
- `parmanentinfo`: Contains basic contact information
- `joininfo`: Contains rank and unit information
- `unitdep`: Contains unit details
- `rnk_brn_mas`: Contains rank and branch details

### Images Database (images_resize.db)
Required table:
- `images`: Contains contact photos indexed by UID

## Permissions

The app requires the following permissions to function properly:

```xml
<uses-permission android:name="android.permission.READ_PHONE_STATE" />
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
<uses-permission android:name="android.permission.READ_CALL_LOG" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

## Architecture

- **Services**:
  - `CallDetectorService`: Handles phone state changes
  - `CallSimulatorService`: For testing incoming calls
  
- **Database Helpers**:
  - `DatabaseHelper`: Manages PIMS database operations
  - `ImageDatabaseHelper`: Manages contact photo operations

- **Screens**:
  - `CallHistoryScreen`: Displays call logs
  - `ContactDetailsScreen`: Shows detailed contact information

## Known Issues and Limitations

1. The app requires the PIMS database to be present and properly formatted
2. Some Android manufacturers may restrict background services
3. Overlay permissions must be manually granted on first run

## Troubleshooting

1. **Database Not Found**:
   - Ensure `pims.db` and `images_resize.db` are in the correct location
   - Check file permissions

2. **Notifications Not Working**:
   - Enable overlay permissions
   - Check battery optimization settings
   - Enable autostart for the app

3. **Contact Photos Not Showing**:
   - Verify `images_resize.db` is properly copied
   - Check if UID matches between databases

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Flutter team for the excellent framework
- All contributors who have helped with testing and development
