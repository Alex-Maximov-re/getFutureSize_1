import Foundation

enum L10n {
    static var homeTitle: String { String(localized: "home.title") }
    static var homeSubtitle: String { String(localized: "home.subtitle") }
    static var homeEmptyTitle: String { String(localized: "home.empty.title") }
    static var homeEmptyBody: String { String(localized: "home.empty.body") }
    static var homeAdd: String { String(localized: "home.add") }
    static var homeExample: String { String(localized: "home.example") }
    static var homeDeleteTitle: String { String(localized: "home.deleteTitle") }
    static var homeDeleteMessage: String { String(localized: "home.deleteMessage") }
    static var homeDeleteAction: String { String(localized: "home.deleteAction") }
    static var homeNoMeasurements: String { String(localized: "home.noMeasurements") }
    static var homeChoose: String { String(localized: "home.choose") }

    static var childEditorNew: String { String(localized: "child.editor.new") }
    static var childEditorEdit: String { String(localized: "child.editor.edit") }
    static var childNickname: String { String(localized: "child.nickname") }
    static var childNicknamePlaceholder: String { String(localized: "child.nickname.placeholder") }
    static var childSexNote: String { String(localized: "child.sex.note") }
    static var childSexMale: String { String(localized: "child.sex.male") }
    static var childSexFemale: String { String(localized: "child.sex.female") }

    static var measurementAdd: String { String(localized: "measurement.add") }
    static var measurementEdit: String { String(localized: "measurement.edit") }
    static var measurementAge: String { String(localized: "measurement.age") }
    static var measurementYears: String { String(localized: "measurement.years") }
    static var measurementMonths: String { String(localized: "measurement.months") }
    static var measurementHeight: String { String(localized: "measurement.height") }
    static var measurementWeight: String { String(localized: "measurement.weight") }
    static var measurementDeleteTitle: String { String(localized: "measurement.deleteTitle") }
    static var measurementDeleteMessage: String { String(localized: "measurement.deleteMessage") }
    static var measurementDuplicate: String { String(localized: "measurement.duplicate") }
    static var measurementIncomplete: String { String(localized: "measurement.incomplete") }
    static var measurementAgeOutOfRange: String { String(localized: "measurement.ageOutOfRange") }
    static var measurementOutsideModel: String { String(localized: "measurement.outsideModel") }
    static var measurementUnusual: String { String(localized: "measurement.unusual") }
    static var measurementLengthNote: String { String(localized: "measurement.lengthNote") }
    static var measurementStandingNote: String { String(localized: "measurement.standingNote") }
    static var measurementSection: String { String(localized: "measurement.section") }
    static var measurementEmpty: String { String(localized: "measurement.empty") }

    static var forecastNeedMeasurement: String { String(localized: "forecast.needMeasurement") }
    static var forecastNow: String { String(localized: "forecast.now") }
    static var forecastRangeCaption: String { String(localized: "forecast.rangeCaption") }
    static var forecastChartHeight: String { String(localized: "forecast.chart.height") }
    static var forecastChartWeight: String { String(localized: "forecast.chart.weight") }
    static var forecastChartCaption: String { String(localized: "forecast.chart.caption") }
    static var forecastChartAccessibility: String { String(localized: "forecast.chart.accessibility") }
    static var forecastTable: String { String(localized: "forecast.table") }
    static var forecastSingle: String { String(localized: "forecast.single") }
    static var forecastShortSpan: String { String(localized: "forecast.shortSpan") }
    static var forecastUnusual: String { String(localized: "forecast.unusual") }
    static var forecastPastReference: String { String(localized: "forecast.pastReference") }
    static var forecastTransition: String { String(localized: "forecast.transition") }
    static var forecastFromLatest: String { String(localized: "forecast.fromLatest") }
    static var forecastNotesTitle: String { String(localized: "forecast.notesTitle") }
    static var forecastMethodTitle: String { String(localized: "forecast.methodTitle") }
    static var forecastMethodBrief: String { String(localized: "forecast.methodBrief") }
    static var forecastShare: String { String(localized: "forecast.share") }
    static var forecastFooter: String { String(localized: "forecast.footer") }

    static var aboutTitle: String { String(localized: "about.title") }
    static var aboutDisclaimerHeading: String { String(localized: "about.disclaimerHeading") }
    static var aboutDisclaimerBody: String { String(localized: "about.disclaimerBody") }
    static var aboutMethodHeading: String { String(localized: "about.methodHeading") }
    static var aboutMethodBody: String { String(localized: "about.methodBody") }
    static var aboutLimitsHeading: String { String(localized: "about.limitsHeading") }
    static var aboutLimitsBody: String { String(localized: "about.limitsBody") }
    static var aboutPrivacyHeading: String { String(localized: "about.privacyHeading") }
    static var aboutPrivacyBody: String { String(localized: "about.privacyBody") }
    static var aboutSourcesHeading: String { String(localized: "about.sourcesHeading") }
    static var aboutSourcesBody: String { String(localized: "about.sourcesBody") }
    static var aboutReplay: String { String(localized: "about.replay") }

    static var onboardingNext: String { String(localized: "onboarding.next") }
    static var onboardingAccept: String { String(localized: "onboarding.accept") }
    static var onboarding1Title: String { String(localized: "onboarding.1.title") }
    static var onboarding1Body: String { String(localized: "onboarding.1.body") }
    static var onboarding2Title: String { String(localized: "onboarding.2.title") }
    static var onboarding2Body: String { String(localized: "onboarding.2.body") }
    static var onboarding3Title: String { String(localized: "onboarding.3.title") }
    static var onboarding3Body: String { String(localized: "onboarding.3.body") }

    static var commonDone: String { String(localized: "common.done") }
    static var commonSave: String { String(localized: "common.save") }
    static var commonCancel: String { String(localized: "common.cancel") }
    static var commonDelete: String { String(localized: "common.delete") }
    static var commonClose: String { String(localized: "common.close") }
    static var commonEdit: String { String(localized: "common.edit") }

    static var exampleName: String { String(localized: "example.name") }
    static var shareTitle: String { String(localized: "share.title") }
    static var shareFooter: String { String(localized: "share.footer") }
    static var unitCm: String { String(localized: "unit.cm") }
    static var unitKg: String { String(localized: "unit.kg") }
    static var tableAge: String { String(localized: "table.age") }
    static var tableHeight: String { String(localized: "table.height") }
    static var tableWeight: String { String(localized: "table.weight") }

    static func aboutVersion(_ version: String, _ build: String) -> String {
        String(format: String(localized: "about.version"), locale: .current, version, build)
    }
}
