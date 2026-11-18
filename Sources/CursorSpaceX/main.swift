import AppKit

// Command-line modes run without any window and exit. Everything else starts the app.
let args = CommandLine.arguments
if let cmd = args.dropFirst().first, cmd.hasPrefix("--") {
    exit(CLI.run(Array(args.dropFirst())))
}
CursorSpaceXApp.main()
