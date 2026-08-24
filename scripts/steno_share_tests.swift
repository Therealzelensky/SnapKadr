import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoShareTests {
    static func main() {
        let call = StenoDetectedCall(source: .zoom, windowID: 10, title: "Zoom Meeting")
        let zoomCall = StenoWindowSnapshot(
            windowID: 10, bundleID: "us.zoom.xos", title: "Zoom Meeting", ownerName: "zoom.us", ownerPID: 100
        )
        let zoomShare = StenoWindowSnapshot(
            windowID: 11, bundleID: "us.zoom.xos", title: "you are sharing screen", ownerName: "zoom.us", ownerPID: 100
        )
        let other = StenoWindowSnapshot(
            windowID: 99, bundleID: "com.apple.Safari", title: "sharing notes", ownerName: "Safari", ownerPID: 200
        )

        let hit = StenoShareProbe.findShare(call: call, callPID: 100, snapshots: [zoomCall, zoomShare, other])
        expect(hit?.windowID == 11, "zoom share same PID")
        expect(hit?.title.lowercased().contains("sharing") == true, "zoom share title")

        expect(
            StenoShareProbe.findShare(call: call, callPID: 100, snapshots: [zoomCall]) == nil,
            "no share when only call window"
        )

        let meetCall = StenoDetectedCall(source: .googleMeet, windowID: 20, title: "Standup - Google Meet")
        let meetWin = StenoWindowSnapshot(
            windowID: 20, bundleID: "com.google.Chrome", title: "Standup - Google Meet", ownerName: "Chrome", ownerPID: 50
        )
        let meetShare = StenoWindowSnapshot(
            windowID: 21, bundleID: "com.google.Chrome", title: "You are presenting", ownerName: "Chrome", ownerPID: 50
        )
        expect(
            StenoShareProbe.findShare(call: meetCall, callPID: 50, snapshots: [meetWin, meetShare])?.windowID == 21,
            "meet presenting"
        )

        let tmCall = StenoDetectedCall(source: .telemost, windowID: 30, title: "Планерка")
        let tmWin = StenoWindowSnapshot(
            windowID: 30, bundleID: "ru.yandex.desktop.telemost", title: "Планерка", ownerName: "Телемост", ownerPID: 70
        )
        let tmShare = StenoWindowSnapshot(
            windowID: 31, bundleID: "ru.yandex.desktop.telemost", title: "Демонстрация экрана", ownerName: "Телемост", ownerPID: 70
        )
        expect(
            StenoShareProbe.findShare(call: tmCall, callPID: 70, snapshots: [tmWin, tmShare])?.windowID == 31,
            "telemost demo window"
        )

        let tgCall = StenoDetectedCall(source: .telegram, windowID: 40, title: "Anna (звонок)")
        let tgShare = StenoWindowSnapshot(
            windowID: 41, bundleID: "ru.keepcoder.Telegram", title: "sharing", ownerName: "Telegram", ownerPID: 80
        )
        expect(
            StenoShareProbe.findShare(call: tgCall, callPID: 80, snapshots: [tgShare]) == nil,
            "telegram share skipped v1"
        )

        let selfShare = StenoWindowSnapshot(
            windowID: 10, bundleID: "us.zoom.xos", title: "you are sharing", ownerName: "zoom.us", ownerPID: 100
        )
        expect(
            StenoShareProbe.findShare(call: call, callPID: 100, snapshots: [selfShare]) == nil,
            "never return call windowID"
        )

        exit(failures == 0 ? 0 : 1)
    }
}
