# Turning on iCloud sync

The app runs local-only today. The data model is already written to CloudKit's rules, so
enabling sync is configuration rather than a rewrite.

## What it needs first

A paid Apple Developer Program membership (£79/$99 a year). The free personal team can
sign an app onto your own device, but it cannot create an iCloud container — this is the
one feature you asked for that the free tier will not do.

## Steps

1. Xcode → target **Totalisr** → **Signing & Capabilities** → set **Team**.
2. **+ Capability** → **iCloud** → tick **CloudKit** → **+** a container named
   `iCloud.com.stuartleitch.Totalisr`.
3. **+ Capability** → **Background Modes** → tick **Remote notifications**, so other
   devices' changes arrive without reopening the app.
4. Xcode writes an entitlements file for iOS. For macOS, uncomment the iCloud block in
   `Totalisr/Totalisr-macOS.entitlements` (the sandbox needs `network.client` too).
5. Make the container explicit in `TotalisrApp.swift`:

   ```swift
   .modelContainer(for: [TotalList.self, Item.self],
                   isAutosaveEnabled: true,
                   isUndoEnabled: true)
   ```

   becomes a `ModelConfiguration(cloudKitDatabase: .private("iCloud.com.stuartleitch.Totalisr"))`
   passed to a `ModelContainer` you build yourself. SwiftData will also pick the container
   up implicitly once the entitlement exists, but naming it makes failures legible.
6. Run on two devices signed into the same Apple ID and watch a row appear on both.
7. Before any TestFlight or App Store build, open the CloudKit Console and **deploy the
   schema to Production**. Development and Production schemas are separate, and this step
   is the usual reason sync works for you and for nobody else.

## The constraints already honoured

CloudKit mirroring refuses a model that breaks any of these, so the code keeps to them
even while the store is local:

- every property has a default value
- every relationship is optional (`items: [Item]?`, `list: TotalList?`)
- no `@Attribute(.unique)` anywhere
- no `deny` delete rules

Changing a model later means keeping it additive, or writing a migration plan.

## If you stay on the free tier

Everything except sync works. iPhone, iPad and Mac each keep their own local store.
