# POS Phone - Simple Billing Engine 🧾📱

A mobile Point-of-Sale (POS) and retail billing system tailored for shopkeepers, grocery stalls, and fast-paced retail. Features fast keypad entry, offline SQLite persistence, ESC/POS hardware thermal printing over USB/OTG, voice assistance, and UPI payments.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)
![SQLite](https://img.shields.io/badge/Database-SQLite-003B57?logo=sqlite)
![ESC/POS](https://img.shields.io/badge/Hardware-ESC%2FPOS-orange)
![Tests](https://img.shields.io/badge/Tests-Passing-brightgreen)

---

## ⚡ Features

- **Rapid Keypad Entry**: Fast numpad and itemized billing screen with real-time total computation.
- **Hardware Receipt Printing**: Native USB-OTG integration for ESC/POS 58mm/80mm thermal receipt printers.
- **UPI QR Code Generation**: Generates dynamic UPI payment QR codes on screen and printed receipts.
- **Voice Feedback & Assistant**: Text-to-speech and voice billing helper.
- **Comprehensive Unit Tests**: Full test suite covering billing calculation, receipt builder, and UPI services.

---

## 🏗️ Project Architecture

```
lib/
├── core/         # Constants, themes, formatters, and errors
├── features/
│   ├── billing/  # Keypad, cart state, item catalog, and billing controller
│   ├── checkout/ # Cash & UPI payment flows, bill completion dialog
│   ├── history/  # Past bills and daily sales reporting
│   ├── printer/  # ESC/POS encoding & USB thermal printer service
│   ├── sales/    # Daily analytics and sales summary
│   ├── settings/ # Shop details, GST, and receipt header configuration
│   └── upi/      # UPI dynamic payment generator
└── shared/       # Voice assistant service (TTS/STT)
```

---

## 🧪 Testing

Run all unit and widget tests:
```bash
flutter test
```

---

## 🚀 Running the Project

```bash
git clone https://github.com/Rishi0073/pos-phone-simple-billing.git
cd pos-phone-simple-billing
flutter pub get
flutter run
```
