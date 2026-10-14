import Foundation

/// Отличает открытый чат Яндекс Мессенджера от уже идущего звонка.
/// Групповой созвон — это Телемост внутри мессенджера: нужен второй участник.
/// Звонок 1:1 показывает «Завершить звонок» или баннер «Открыть экран звонка».
public enum StenoYandexMessengerCallState {
    public static func isInCall(
        axLabels: [String],
        participantCount: Int? = nil,
        videoTrackCount: Int = 0
    ) -> Bool {
        StenoLiveCall.isConnected(
            labels: axLabels,
            participantCount: participantCount,
            videoTrackCount: videoTrackCount
        )
    }

    public static func isInCall(pid: pid_t) -> Bool {
        StenoLiveCall.isInCall(pid: pid)
    }
}
