import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoParticipantTests {
    static func main() {
        let ax = [
            StenoNameHit(displayName: "Аня", source: .ax),
            StenoNameHit(displayName: "Боря", source: .ax)
        ]
        let ocr = [
            StenoNameHit(displayName: "аня", source: .ocr),
            StenoNameHit(displayName: "Вика", source: .ocr)
        ]
        let merged = StenoParticipantResolver.mergeNames(ax: ax, ocr: ocr)
        expect(merged.count == 3, "dedupe Аня")
        expect(merged[0].source == .merged && merged[0].displayName == "Аня", "AX+OCR → merged keeps AX display")
        expect(merged[1].displayName == "Боря" && merged[1].source == .ax, "AX only")
        expect(merged[2].displayName == "Вика" && merged[2].source == .ocr, "OCR only")

        let mapped = StenoParticipantResolver.mapVoices(speakers: ["1", "2"], names: merged)
        expect(mapped[0].speakerId == "1" && mapped[1].speakerId == "2", "zip speakers")
        expect(mapped[2].speakerId == nil, "extra name unbound")
        expect(StenoParticipantResolver.voiceLabel(speakerId: "1") == "Голос 1", "label")

        struct FakeAX: StenoAXNameReading {
            var hits: [StenoNameHit]
            func readNames(windowID: UInt32, pid: pid_t, windowTitle: String) -> [StenoNameHit] { hits }
        }
        final class FakeOCR: StenoOCRNameReading {
            var hits: [StenoNameHit]
            private(set) var callCount = 0
            init(hits: [StenoNameHit]) { self.hits = hits }
            func readNames(windowID: UInt32) -> [StenoNameHit] {
                callCount += 1
                return hits
            }
        }

        expect(
            StenoParticipantResolver.resolveNames(
                namesEnabled: false, windowID: 1, pid: 1,
                ax: FakeAX(hits: [StenoNameHit(displayName: "X", source: .ax)]),
                ocr: FakeOCR(hits: [StenoNameHit(displayName: "Y", source: .ocr)])
            ).isEmpty,
            "names pref off → skip"
        )

        let ocrFake = FakeOCR(hits: [StenoNameHit(displayName: "Y", source: .ocr)])
        let axHits = [StenoNameHit(displayName: "X", source: .ax)]
        let result = StenoParticipantResolver.resolveNames(
            namesEnabled: true, windowID: 42, pid: 7,
            ax: FakeAX(hits: axHits), ocr: ocrFake
        )
        expect(ocrFake.callCount == 1, "OCR always when names on")
        expect(result.map(\.displayName).sorted() == ["X", "Y"].sorted(), "merged")

        let noWindowOCR = FakeOCR(hits: [])
        let noWindow = StenoParticipantResolver.resolveNames(
            namesEnabled: true, windowID: nil, pid: 0,
            ax: FakeAX(hits: axHits), ocr: noWindowOCR
        )
        expect(noWindow.isEmpty, "missing window → empty (readers not useful)")
        expect(noWindowOCR.callCount == 0, "missing window → no OCR call")

        expect(
            !StenoParticipantResolver.looksLikeName("Yandex Messenger"),
            "app title is not a participant"
        )
        expect(
            !StenoParticipantResolver.looksLikeName("Яндекс Мессенджер — 2 новых сообщения"),
            "messenger window chrome is not a participant"
        )
        expect(
            !StenoParticipantResolver.looksLikeName("Показать «Cursor.app» в Finder"),
            "finder reveal menu is not a participant"
        )
        expect(
            !StenoParticipantResolver.looksLikeName("Cursor.app"),
            "app bundle label is not a participant"
        )
        expect(
            !StenoParticipantResolver.looksLikeName("Edit"),
            "menu Edit is not a participant"
        )
        expect(
            !StenoParticipantResolver.looksLikeName("Системные настройки…, 1 обновление"),
            "system settings menu is not a participant"
        )
        expect(
            !StenoParticipantResolver.looksLikeName("crm.mcclinics.ru"),
            "domain is not a participant"
        )
        expect(
            !StenoParticipantResolver.looksLikeName("O.T. Genasis-CoCo-kissvk.com.mp3"),
            "filename is not a participant"
        )
        expect(
            StenoParticipantResolver.looksLikeName("Мальцева Елизавета"),
            "person full name is a participant"
        )
        expect(
            !StenoParticipantResolver.looksLikeName("Аня"),
            "single token is too ambiguous for participants"
        )
        expect(
            !StenoParticipantResolver.looksLikeName("Главное меню"),
            "bitrix nav is not a participant"
        )
        expect(
            !StenoParticipantResolver.looksLikeName("Дмитрий Зеленский не отвечает"),
            "call status line is not a participant"
        )
        expect(
            StenoParticipantResolver.nameHits(
                from: [
                    "Yandex Messenger",
                    "Apple",
                    "Edit",
                    "Мальцева Елизавета",
                    "Аня",
                    "Cursor.app",
                    "Завершить звонок"
                ],
                source: .ax
            ).map(\.displayName) == ["Мальцева Елизавета"],
            "menu chrome filtered; full names kept, single token dropped"
        )

        // Real Bitrix Sync AX dump: people buried under portal chrome.
        let bitrixDump = [
            "Перейти к разделу", "Главное меню", "Битрикс 24", "Лента", "CRM",
            "Совместная работа", "Мессенджер", "BitrixGPT", "Почта",
            "Задачи и Проекты, 25 новых", "Маруся Ремизова", "[Фото]",
            "Дарья Чернова", "Звонок завершён (24 сек)", "Дмитрий Зеленский не отвечает",
            "НЧ", "Надежда Прокурова", "21 авг", "Татьяна Леонова",
            "Ольга Мошкова", "Полина Булганина", "Даниил Панфилов",
            "Татьяна Кольчурина", "(25) Сделки", "Новая вкладка",
            "Traffic · Therealzelensky/SnapKadr", "localhost:52531"
        ]
        let people = StenoParticipantResolver.nameHits(from: bitrixDump, source: .ax).map(\.displayName)
        expect(
            people == [
                "Маруся Ремизова", "Дарья Чернова", "Надежда Прокурова",
                "Татьяна Леонова", "Ольга Мошкова", "Полина Булганина",
                "Даниил Панфилов", "Татьяна Кольчурина"
            ],
            "bitrix dump keeps only person full names"
        )
        expect(!people.contains("Главное меню"), "nav chrome not a participant")
        expect(!people.contains("Дмитрий Зеленский не отвечает"), "status line not a participant")

        let mappedPeople = StenoParticipantResolver.mapVoices(
            speakers: ["1", "2", "3"],
            names: StenoParticipantResolver.mergeNames(
                ax: people.map { StenoNameHit(displayName: $0, source: .ax) },
                ocr: []
            )
        )
        expect(mappedPeople[0].displayName == "Маруся Ремизова" && mappedPeople[0].speakerId == "1", "voice 1 → first person")
        expect(mappedPeople[1].displayName == "Дарья Чернова" && mappedPeople[1].speakerId == "2", "voice 2 → second person")

        exit(failures == 0 ? 0 : 1)
    }
}
