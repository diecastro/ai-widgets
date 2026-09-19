import AppKit

// LSUIElement in Info.plist keeps this out of the Dock and the app switcher; the
// accessory policy is set here too so the app behaves correctly when run
// directly from the build directory, without a bundle.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
