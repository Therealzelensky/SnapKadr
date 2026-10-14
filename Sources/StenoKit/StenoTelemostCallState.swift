import Foundation

/// Отличает лобби и одиночную комнату Телемоста от начавшегося созвона.
public enum StenoTelemostCallState {
    private static let lobbyNeedles = [
        "новая видеовстреча",
        "подключиться",
        "запланировать",
        "новая трансляция",
        "new meeting",
        "join meeting",
        "schedule",
        "new livestream",
    ]

    public static func isInCall(
        axLabels: [String],
        participantCount: Int? = nil,
        videoTrackCount: Int = 0
    ) -> Bool {
        StenoLiveCall.isConnected(
            labels: axLabels,
            participantCount: participantCount,
            videoTrackCount: videoTrackCount,
            lobbyNeedles: lobbyNeedles
        )
    }

    public static func isInCall(pid: pid_t) -> Bool {
        StenoLiveCall.isInCall(pid: pid, lobbyNeedles: lobbyNeedles)
    }
}
