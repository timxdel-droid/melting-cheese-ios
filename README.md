# Melting Cheese Street Lab — iOS app

Native SwiftUI app for Melting Cheese Street Lab. The menu is **live**: it reads the
WooCommerce Store API on `dev2.meltingcheese.food`, so anything you change in
WordPress (products, prices, photos, categories) appears in the app without a new build.

## What's in it

| Screen | What it does |
| --- | --- |
| **Home** | Branded hero, featured Signature Combos carousel, value props, Find Us link |
| **Menu** | Live catalogue grouped by category, category chips, search, pull-to-refresh |
| **Product detail** | Large photo, price, description, add-to-order |
| **My Order** | Local order pad with quantities and a running total |

Data source (public, read-only, no API keys):

```
https://dev2.meltingcheese.food/wp-json/wc/store/v1/products?per_page=100
```

Prices arrive as minor units (`"3999"` = 39.99 AED) and are formatted in
`Prices.formatted`. Items with no price yet show **"Price at truck"** rather than 0.00.

> **Note on ordering:** "My Order" is deliberately a local order pad with no
> checkout — guests build the order and pay at the truck. This keeps the app clear
> of Apple's in-app-purchase rules for physical goods and avoids a payment integration.

## Project layout

```
MeltingCheese/
  MeltingCheeseApp.swift      app entry + tab bar
  Theme.swift                 brand colours, buttons, remote image
  Models/Product.swift        Store API models + HTML/entity cleanup
  Services/MenuService.swift  networking + category grouping
  ViewModels/                 MenuViewModel, OrderStore
  Views/                      HomeView, MenuView, ProductDetailView, OrderView
project.yml                   XcodeGen spec (generates the .xcodeproj)
codemagic.yaml                CI: build + ship to TestFlight
```

The `.xcodeproj` is **not** committed — it's generated from `project.yml`. This keeps
the repo free of merge-conflict-prone project files.

## Run it locally (macOS + Xcode required)

```bash
brew install xcodegen
xcodegen generate
open MeltingCheese.xcodeproj
```

Then set your Team under *Signing & Capabilities* and run on a simulator or device.

## Ship to TestFlight (Codemagic)

1. Push this repo to GitHub.
2. In Codemagic, add the repository as an application.
3. Create an **App Store Connect API key** integration, and an environment variable
   group named `appstore_credentials` containing:
   - `APP_STORE_CONNECT_ISSUER_ID`
   - `APP_STORE_CONNECT_KEY_IDENTIFIER`
   - `APP_STORE_CONNECT_PRIVATE_KEY`
   - `CERTIFICATE_PRIVATE_KEY`
4. Confirm the bundle id below matches the app record in App Store Connect
   (App ID `6798319040`), then start the `ios-testflight` workflow.

```
BUNDLE_ID = food.meltingcheese.app
```

If the existing App Store Connect record uses a different bundle id, change it in
both `project.yml` (`PRODUCT_BUNDLE_IDENTIFIER`) and `codemagic.yaml` (`BUNDLE_ID`).

## Known follow-ups

- **App icon** is a generated placeholder (`Assets.xcassets/AppIcon.appiconset`).
  Swap in the official brand logo artwork when it's available as a 1024×1024 PNG.
- The app has never been compiled on a Mac — the first Codemagic run is the real
  compile, so expect to fix a small issue or two on that first build.
- Events/Find Us currently deep-links to the website; it can become a native screen
  once there's an events API.
