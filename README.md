
# Wayfarer

**Wayfarer** is a Flutter-based personal experience tracker app that allows users to document their journeys, adventures, and daily moments. It combines traditional journaling with location-based insights, multimedia integration (images, audio), and smart memory organization.

## 📱 Features

- 📓 Create text-based journal entries
- 📸 Add images from the gallery or camera
- 🎤 Record and attach audio notes
- 📍 Tag locations using GPS
- 🔒 Lock specific journals using a password or fingerprint
- 🔖 Bookmark favourite entries
- 🧠 Smart organisation of memories
- 🔐 View private journals securely
- ⚙️ Manage account (logout, change password, delete account)

## 🧱 App Screens

- **Landing Page**: Login / Sign-up options
- **Login Page**: Email & password authentication
- **Sign-up Page**: Register new account
- **Homepage**: Display journals + Add journal button
- **Privates Page**: Lists all locked/private journals
- **Bookmarked Page**: View all bookmarked journals
- **Settings Page**: Account management tools
- **Add Journal Page**: Add journals
- **Edit Journal Page**: Edit journals
- **Audio Recording Page**: Record audio
- **Forgort Password Pages**: Create new password


## 🛠️ Tech Stack

- **Flutter**: Mobile app framework
- **Firebase Authentication**: User login & registration
- **Cloud Firestore**: NoSQL database for users and journals
- **Cloudinary**: Multimedia storage (images, audio)
- **Geolocator & Flutter Map**: Location tagging
- **Path Provider & Image Picker**: File access
- **Local Auth**: Fingerprint/Face ID security
- **Provider**: State management

## 🗃️ Firestore Schema

### `users` collection
- `firstName`: string
- `lastName`: string
- `email`: string
- `createdAt`: timestamp

### `journals` collection
- `userId`: string
- `title`: string
- `description`: string
- `imageUrl`: string
- `additionalImages`: array of image URLs
- `audioRecordings`: array of maps (title, url, duration, recordedAt)
- `date`: timestamp
- `hasLocationData`: boolean
- `locations`: array of maps (placeName, displayName, timestamp)
- `isBookmarked`: boolean
- `isLocked`: boolean
- `createdAt`, `updatedAt`: timestamps

## 🚀 Getting Started

To run this project locally:

1. **Clone the repo:**
   ```bash
   git clone https://github.com/your-username/wayfarer.git
   cd wayfarer
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

Ensure Firebase is set up and configured for Android/iOS (see `firebase_options.dart`).

## 🔮 Future Updates

- 🎥 Add support for video journaling
- 🔍 Image zoom functionality
- 📊 Analytics of journaling habits

## 📄 License

Copyright (c) 2025 Wayfarer
