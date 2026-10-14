import Darwin
import Foundation

/// Медиа-сокет звонка, не обычный TCP 443 чата или API.
/// Порты — из сетевых требований сервисов. UDP 443 не считается: это QUIC и TURN через прокси.
public enum CallService: String, Sendable {
    case telemost
    case yandexMessenger
    case zoom
    case googleMeet
    case telegram
    case bitrix
    case teams
    case webex
    case trueconf
    case facetime
    case gotomeeting
    case bluejeans
    case whereby
    /// Незнакомое приложение из списка созвонов: любой внешний UDP, кроме служебных портов.
    case generic
}

public enum CallMedia {
    private static let noisePorts: Set<Int> = [53, 67, 68, 80, 123, 137, 138, 443, 5353, 5355, 1900]

    public static func matches(service: CallService, remotePort: Int) -> Bool {
        guard remotePort > 0, !noisePorts.contains(remotePort) else { return false }
        switch service {
        case .telemost, .yandexMessenger, .bitrix:
            // Яндекс Телемост / Мессенджер и Bitrix24: STUN/TURN и медиа-диапазон.
            return remotePort == 3478 || remotePort == 10000 || (20000...23000).contains(remotePort)
        case .zoom:
            return remotePort == 3478 || remotePort == 3479 || (8801...8810).contains(remotePort)
        case .googleMeet:
            return remotePort == 3478 || (19302...19309).contains(remotePort)
        case .teams:
            return (3478...3481).contains(remotePort) || (50000...50059).contains(remotePort)
        case .webex:
            return remotePort == 5004 || remotePort == 9000
        case .facetime:
            return (3478...3497).contains(remotePort) || (16384...16403).contains(remotePort)
        case .gotomeeting:
            return remotePort == 1853 || remotePort == 8200
        case .bluejeans:
            return remotePort == 5000
        case .whereby:
            return remotePort == 3478 || (19302...19309).contains(remotePort)
        case .telegram, .trueconf, .generic:
            return remotePort > 1024
        }
    }

    public static func matchesAnyKnown(remotePort: Int) -> Bool {
        let specific: [CallService] = [
            .telemost, .zoom, .googleMeet, .teams, .webex, .facetime, .gotomeeting, .bluejeans, .whereby,
        ]
        return specific.contains { matches(service: $0, remotePort: remotePort) }
    }

    public static func service(forAppName name: String) -> CallService? {
        let n = name.lowercased()
        if n.contains("telemost") || n.contains("телемост") { return .telemost }
        if n.contains("yandex messenger") || n.contains("яндекс мессенджер") || n.contains("яндекс\u{00a0}мессенджер") {
            return .yandexMessenger
        }
        if n.contains("zoom") { return .zoom }
        if n.contains("teams") { return .teams }
        if n.contains("webex") { return .webex }
        if n.contains("trueconf") { return .trueconf }
        if n.contains("facetime") || n.contains("face time") { return .facetime }
        if n.contains("gotomeeting") || n.contains("goto meeting") { return .gotomeeting }
        if n.contains("bluejeans") { return .bluejeans }
        if n.contains("whereby") { return .whereby }
        if n.contains("telegram") { return .telegram }
        if n.contains("bitrix") || n.contains("битрикс") { return .bitrix }
        return nil
    }

    public static func service(forDomain domain: String) -> CallService? {
        let d = domain.lowercased()
        if d.contains("telemost") { return .telemost }
        if d.contains("meet.google") { return .googleMeet }
        if d.contains("zoom.us") || d.contains("zoom.com") || d.contains("zoomgov") { return .zoom }
        if d.contains("teams.microsoft") || d.contains("teams.live") { return .teams }
        if d.contains("webex") { return .webex }
        if d.contains("whereby") { return .whereby }
        if d.contains("trueconf") { return .trueconf }
        if d.contains("gotomeeting") || d.contains("goto.com") || d.contains("goto.meeting") { return .gotomeeting }
        if d.contains("bluejeans") { return .bluejeans }
        if d.contains("messenger.yandex") { return .yandexMessenger }
        if d.contains("skype") { return .teams }
        return nil
    }
}

extension CallService {
    init(steno source: StenoSource) {
        switch source {
        case .zoom: self = .zoom
        case .googleMeet: self = .googleMeet
        case .telegram: self = .telegram
        case .telemost: self = .telemost
        case .bitrixSync: self = .bitrix
        case .yandexMessenger: self = .yandexMessenger
        }
    }
}

/// Два секунды подряд, чтобы одиночный STUN-пинг не считался звонком.
public final class CallMediaHold {
    private var since: [String: Date] = [:]

    public init() {}

    public func confirm(key: String, hit: Bool, now: Date = Date(), hold: TimeInterval = 2) -> Bool {
        guard hit else {
            since[key] = nil
            return false
        }
        if let started = since[key] {
            return now.timeIntervalSince(started) >= hold
        }
        since[key] = now
        return false
    }
}

public enum CallSocketProbe {
    /// UDP-медиа у процесса и его дочерних (QtWebEngine, Electron Helper).
    public static func hasMedia(pid: pid_t, service: CallService) -> Bool {
        let ports = remoteUDPPorts(root: pid, companions: companionNames(service))
        return ports.contains { CallMedia.matches(service: service, remotePort: $0) }
    }

    /// Для домена из общего списка, когда сервис не узнали по имени.
    public static func hasAnyKnownMedia(pid: pid_t) -> Bool {
        remoteUDPPorts(root: pid, companions: []).contains { CallMedia.matchesAnyKnown(remotePort: $0) }
    }

    private static func companionNames(_ service: CallService) -> [String] {
        switch service {
        case .facetime: return ["avconferenced"]
        default: return []
        }
    }

    private static func remoteUDPPorts(root: pid_t, companions: [String]) -> [Int] {
        var pids = processTree(root)
        if !companions.isEmpty {
            var seen = Set(pids)
            for name in companions {
                for pid in processIDs(named: name) where seen.insert(pid).inserted {
                    pids.append(pid)
                }
            }
        }
        var ports: [Int] = []
        for pid in pids {
            ports.append(contentsOf: udpRemotePorts(pid: pid))
        }
        return ports
    }

    private static func processTree(_ root: pid_t) -> [pid_t] {
        guard root > 0 else { return [] }
        var seen = Set<pid_t>()
        var queue = [root]
        var out: [pid_t] = []
        while let pid = queue.popLast() {
            guard pid > 0, seen.insert(pid).inserted, out.count < 48 else { continue }
            out.append(pid)
            queue.append(contentsOf: childPIDs(pid))
        }
        return out
    }

    private static func childPIDs(_ pid: pid_t) -> [pid_t] {
        var buf = [pid_t](repeating: 0, count: 64)
        let n = buf.withUnsafeMutableBufferPointer { raw in
            proc_listchildpids(pid, raw.baseAddress, Int32(MemoryLayout<pid_t>.size * raw.count))
        }
        guard n > 0 else { return [] }
        return Array(buf.prefix(min(Int(n), buf.count)))
    }

    private static func processIDs(named name: String) -> [pid_t] {
        var buf = [pid_t](repeating: 0, count: 4096)
        let bytes = buf.withUnsafeMutableBufferPointer { raw in
            proc_listallpids(raw.baseAddress, Int32(MemoryLayout<pid_t>.size * raw.count))
        }
        let count = max(0, Int(bytes) / MemoryLayout<pid_t>.size)
        var hits: [pid_t] = []
        for pid in buf.prefix(count) where pid > 0 {
            var nameBuf = [CChar](repeating: 0, count: 64)
            let rc = nameBuf.withUnsafeMutableBufferPointer { raw in
                proc_name(pid, raw.baseAddress, UInt32(raw.count))
            }
            guard rc > 0 else { continue }
            if String(cString: nameBuf) == name { hits.append(pid) }
        }
        return hits
    }

    private static func udpRemotePorts(pid: pid_t) -> [Int] {
        let size = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard size > 0 else { return [] }
        let count = Int(size) / MemoryLayout<proc_fdinfo>.stride
        guard count > 0 else { return [] }
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: count)
        let used = fds.withUnsafeMutableBytes { raw in
            proc_pidinfo(pid, PROC_PIDLISTFDS, 0, raw.baseAddress, size)
        }
        let n = max(0, Int(used) / MemoryLayout<proc_fdinfo>.stride)
        var ports: [Int] = []
        for fd in fds.prefix(n) where fd.proc_fdtype == UInt32(PROX_FDTYPE_SOCKET) {
            var info = socket_fdinfo()
            let got = withUnsafeMutablePointer(to: &info) {
                proc_pidfdinfo(pid, fd.proc_fd, PROC_PIDFDSOCKETINFO, $0, Int32(MemoryLayout<socket_fdinfo>.size))
            }
            guard got > 0, info.psi.soi_kind == SOCKINFO_IN, info.psi.soi_protocol == IPPROTO_UDP else { continue }
            let ini = info.psi.soi_proto.pri_in
            let port = Int(UInt16(truncatingIfNeeded: ini.insi_fport).bigEndian)
            guard port > 0, isCallRemote(ini) else { continue }
            ports.append(port)
        }
        return ports
    }

    private static func isCallRemote(_ ini: in_sockinfo) -> Bool {
        if ini.insi_vflag & UInt8(INI_IPV4) != 0 {
            let addr = ini.insi_faddr.ina_46.i46a_addr4
            let host = String(cString: inet_ntoa(addr))
            return isCallHost(host)
        }
        if ini.insi_vflag & UInt8(INI_IPV6) != 0 {
            var addr = ini.insi_faddr.ina_6
            var buf = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            let ok = buf.withUnsafeMutableBufferPointer { raw in
                inet_ntop(AF_INET6, &addr, raw.baseAddress, socklen_t(INET6_ADDRSTRLEN))
            }
            guard ok != nil else { return false }
            return isCallHost(String(cString: buf))
        }
        return false
    }

    private static func isCallHost(_ host: String) -> Bool {
        if host.isEmpty || host == "0.0.0.0" || host == "::" || host == "::1" { return false }
        if host.hasPrefix("127.") || host.hasPrefix("fe80") || host.hasPrefix("ff") { return false }
        if host.hasPrefix("169.254.") { return false }
        if let first = host.split(separator: ".").first, let a = Int(first), a >= 224 { return false }
        return true
    }
}
