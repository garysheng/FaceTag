# FaceTag

Capture faces through your Ray-Ban Meta glasses and save them as contacts.

> **Fork of [SpecBridge](https://github.com/jasondukes/SpecBridge)** by Jason Dukes.

## How It Works

```
See someone → Tap capture → Enter their name → Saved as contact with photo
```

Use your Ray-Ban Meta glasses as a first-person camera. When you meet someone, tap the capture button to take their photo and save them as a new contact (or add to an existing one).

## Features

- **Live viewfinder** from your glasses camera
- **One-tap capture** to take a photo
- **Create new contact** with name and photo
- **Add to existing contact** to update someone's profile picture

## Prerequisites

- **Mac** with Xcode 15+
- **iPhone** running iOS 17+
- **Ray-Ban Meta Smart Glasses** (Gen 2) with Developer Mode enabled
- **Meta View app** installed and paired with your glasses

### Enable Developer Mode on Glasses

1. Open **Meta View** app on your iPhone
2. Go to **Devices** → **Settings** → **General** → **About**
3. Tap the **Version** number 5 times
4. Toggle **Developer Mode** on

## Quick Start

### 1. Build the App

1. Open `SpecBridge.xcodeproj` in Xcode
2. Select your Apple ID under **Signing & Capabilities**
3. Connect your iPhone and click **Run**

### 2. Use the App

1. Tap **Connect Glasses** → approve in Meta View app
2. Tap **Start Camera** to see through your glasses
3. When you see someone, tap the **capture button**
4. Enter their name and tap **Create New Contact** or **Add to Existing**

## Project Structure

```
FaceTag/
├── SpecBridge/
│   ├── SpecBridgeApp.swift     # App entry point
│   ├── ContentView.swift       # Main UI + capture flow
│   ├── StreamManager.swift     # Glasses camera connection
│   └── ContactManager.swift    # Create/update contacts
│
└── SpecBridge.xcodeproj
```

## Permissions

The app requires:
- **Contacts** - to save captured faces as contacts
- **Bluetooth** - to connect to your glasses

## Credits

- **Original SpecBridge**: [Jason Dukes](https://github.com/jasondukes/SpecBridge)
- **Meta Wearables DAT SDK**: [Meta](https://www.ray-ban.com/usa/discover-ray-ban-meta/clp)

## License

MIT License. See [LICENSE](LICENSE) for details.
