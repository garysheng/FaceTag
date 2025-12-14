# FaceTag

Capture faces through your Ray-Ban Meta glasses and save them as contacts.

> **Fork of [SpecBridge](https://github.com/jasondukes/SpecBridge)** by Jason Dukes.

## How It Works

```
See someone → Tap glasses → Photo appears in app → Enter name → Saved as contact
```

Use the physical capture button on your Ray-Ban Meta glasses. When you tap to take a photo, it automatically appears in the app ready to save as a contact.

## Features

- **Tap to capture** using the glasses touchpad
- **No video streaming** — just capture and save
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

1. Open `FaceTag.xcodeproj` in Xcode
2. Select your Apple ID under **Signing & Capabilities**
3. Connect your iPhone and click **Run**

### 2. Use the App

1. Tap **Connect Glasses** → approve in Meta View app
2. Tap **Start** to begin listening for captures
3. **Tap your glasses touchpad** when you see someone
4. Photo appears → enter name → save as contact

## Project Structure

```
FaceTag/
├── FaceTag/
│   ├── FaceTagApp.swift        # App entry point
│   ├── ContentView.swift       # Main UI + capture sheet
│   ├── StreamManager.swift     # Glasses camera connection
│   └── ContactManager.swift    # Create/update contacts
│
└── FaceTag.xcodeproj
```

## Permissions

- **Contacts** — to save captured faces as contacts
- **Bluetooth** — to connect to your glasses

## Credits

- **Original SpecBridge**: [Jason Dukes](https://github.com/jasondukes/SpecBridge)
- **Meta Wearables DAT SDK**: [Meta](https://www.ray-ban.com/usa/discover-ray-ban-meta/clp)

## License

MIT License. See [LICENSE](LICENSE) for details.
