"""Write Localizable.xcstrings from the translations below.

Keys must match String(localized:) calls in FutureSize/Support/L10n.swift.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
L10N = ROOT / "FutureSize" / "Support" / "L10n.swift"
CATALOG = ROOT / "FutureSize" / "Localizable.xcstrings"
INFO = ROOT / "FutureSize" / "InfoPlist.xcstrings"

STRINGS: dict[str, tuple[str, str]] = {
    "home.title": ("Будущий рост", "FutureSize"),
    "home.subtitle": (
        "Оценка роста и веса на 10 лет по справочнику ВОЗ",
        "A 10-year height and weight estimate from the WHO reference",
    ),
    "home.empty.title": ("Пока никого нет", "No children yet"),
    "home.empty.body": (
        "Добавьте ребёнка и внесите хотя бы одно измерение. Прошлые годы, если они есть, делают оценку спокойнее.",
        "Add a child and enter at least one measurement. Earlier years, if you have them, make the estimate steadier.",
    ),
    "home.add": ("Добавить ребёнка", "Add a child"),
    "home.example": ("Посмотреть пример", "View an example"),
    "home.deleteTitle": ("Удалить профиль?", "Delete this profile?"),
    "home.deleteMessage": (
        "Профиль и все измерения будут удалены с этого устройства.",
        "The profile and every measurement will be deleted from this device.",
    ),
    "home.deleteAction": ("Удалить профиль", "Delete profile"),
    "home.noMeasurements": ("Пока нет измерений", "No measurements yet"),
    "home.choose": ("Выберите профиль", "Choose a profile"),
    "child.editor.new": ("Новый ребёнок", "New child"),
    "child.editor.edit": ("Ребёнок", "Child"),
    "child.nickname": ("Имя или прозвище", "Name or nickname"),
    "child.nickname.placeholder": ("Например, Мира", "For example, Mira"),
    "child.sex.note": (
        "Справочники ВОЗ для мальчиков и девочек разные.",
        "The WHO references for boys and girls are different.",
    ),
    "child.sex.male": ("Мальчик", "Boy"),
    "child.sex.female": ("Девочка", "Girl"),
    "measurement.add": ("Добавить измерение", "Add measurement"),
    "measurement.edit": ("Измерение", "Measurement"),
    "measurement.age": ("Возраст", "Age"),
    "measurement.years": ("Годы", "Years"),
    "measurement.months": ("Месяцы", "Months"),
    "measurement.height": ("Рост", "Height"),
    "measurement.weight": ("Вес", "Weight"),
    "measurement.deleteTitle": ("Удалить измерение?", "Delete this measurement?"),
    "measurement.deleteMessage": (
        "Это измерение будет удалено с устройства.",
        "This measurement will be deleted from the device.",
    ),
    "measurement.duplicate": (
        "В этом возрасте измерение уже есть. Откройте его в списке, чтобы изменить.",
        "There is already a measurement at this age. Open it in the list to change it.",
    ),
    "measurement.incomplete": (
        "Введите рост и вес числами.",
        "Enter height and weight as numbers.",
    ),
    "measurement.ageOutOfRange": (
        "Справочник ВОЗ в этом приложении охватывает возраст от рождения до 19 лет.",
        "The WHO reference in this app covers birth to 19 years.",
    ),
    "measurement.outsideModel": (
        "Эти числа слишком далеко от справочника ВОЗ, чтобы продолжать их этой моделью. Проверьте, нет ли опечатки. Если всё введено верно, такую ситуацию должен смотреть врач, а не калькулятор перцентилей.",
        "These numbers are too far from the WHO reference for this model to continue them. Check for a typo. If they are right, a doctor should look at the situation, not a percentile calculator.",
    ),
    "measurement.unusual": (
        "Точка заметно выше или ниже середины кривой ВОЗ. Сохранить можно, но сверьте возраст, рост и вес.",
        "This point sits well above or below the middle of the WHO curve. You can save it, but check the age, height, and weight.",
    ),
    "measurement.lengthNote": (
        "До 2 лет ВОЗ сравнивает длину лёжа. Рост стоя в этом возрасте обычно примерно на 0,7 см меньше.",
        "Before age 2, WHO compares length measured lying down. Standing height at that age is usually about 0.7 cm less.",
    ),
    "measurement.standingNote": (
        "С 2 лет ВОЗ сравнивает рост стоя.",
        "From age 2, WHO compares standing height.",
    ),
    "measurement.section": ("Измерения", "Measurements"),
    "measurement.empty": (
        "Добавьте текущие возраст, рост и вес. Если помните прошлые годы — их тоже.",
        "Add the current age, height, and weight. Add earlier years too if you remember them.",
    ),
    "forecast.needMeasurement": (
        "Оценка появится после первого измерения.",
        "The estimate appears after the first measurement.",
    ),
    "forecast.now": ("Сейчас", "Now"),
    "forecast.rangeCaption": (
        "Диапазон — если перцентиль немного сдвинется. Это не заключение врача.",
        "The range is what happens if the percentile shifts a little. It is not a doctor’s conclusion.",
    ),
    "forecast.chart.height": ("Рост", "Height"),
    "forecast.chart.weight": ("Вес", "Weight"),
    "forecast.chart.caption": (
        "Точки — ваши измерения. Пунктир — оценка вперёд.",
        "Dots are your measurements. The dashed line is the forward estimate.",
    ),
    "forecast.chart.accessibility": (
        "График оценки. Точные цифры — в таблице ниже.",
        "Estimate chart. Exact figures are in the table below.",
    ),
    "forecast.table": ("По годам", "Year by year"),
    "forecast.single": (
        "Пока одно измерение: линия держит текущий перцентиль. Добавьте прошлые годы, если помните их.",
        "With one measurement, the line holds the current percentile. Add earlier years if you remember them.",
    ),
    "forecast.shortSpan": (
        "Между крайними измерениями меньше года, поэтому сдвиг перцентиля почти не учитывается.",
        "The measurements span less than a year, so a percentile shift is barely applied.",
    ),
    "forecast.unusual": (
        "Последняя точка далеко от середины кривой ВОЗ. Сверьте рост, вес и возраст.",
        "The latest point is far from the middle of the WHO curve. Check height, weight, and age.",
    ),
    "forecast.pastReference": (
        "Часть оценки старше 19 лет. Дальше справочник ВОЗ рост не ведёт: линия держит взрослый перцентиль и не учитывает питание и образ жизни.",
        "Part of the estimate is past 19 years. After that the WHO reference no longer tracks height: the line holds the adult percentile and does not account for food or daily life.",
    ),
    "forecast.transition": (
        "Около 2 лет на кривой есть ступенька примерно 0,7 см. Так ВОЗ переходит от длины лёжа к росту стоя. Это смена измерения, а не остановка роста.",
        "Around age 2 the curve steps by about 0.7 cm. That is where WHO switches from lying length to standing height. It is a change in measurement, not a stop in growth.",
    ),
    "forecast.fromLatest": (
        "Считаем от последнего введённого возраста, а не от сегодняшней даты.",
        "Calculated from the latest age you entered, not from today’s date.",
    ),
    "forecast.notesTitle": ("Как читать оценку", "How to read the estimate"),
    "forecast.methodTitle": ("Как считается", "How it is calculated"),
    "forecast.methodBrief": (
        "Для каждого измерения находится перцентиль роста и индекса массы тела по ВОЗ. Одно измерение продолжается вдоль своего перцентиля. Несколько измерений задают осторожный сдвиг, который затухает и не тянется прямой линией десять лет. Вес считается из будущего роста и перцентиля индекса массы тела.",
        "Each measurement is placed on the WHO height and BMI percentiles. One measurement continues along that percentile. Several measurements add a cautious shift that fades instead of running in a straight line for ten years. Weight comes from the future height and the BMI percentile.",
    ),
    "forecast.share": ("Поделиться оценкой", "Share estimate"),
    "forecast.footer": (
        "Оценка по справочнику ВОЗ. Не медицинское изделие и не замена консультации врача.",
        "A WHO reference estimate. Not a medical device and not a substitute for a doctor.",
    ),
    "about.title": ("Сведения", "About"),
    "about.disclaimerHeading": ("Важно", "Important"),
    "about.disclaimerBody": (
        "Это учебная оценка для родителей, а не осмотр и не диагноз. Приложение не является медицинским изделием и не заменяет консультацию врача. По этим цифрам нельзя назначать лечение, диету или решать, всё ли в порядке со здоровьем. Если рост или вес беспокоят, покажите ребёнка педиатру.",
        "This is an educational estimate for parents, not an examination and not a diagnosis. The app is not a medical device and does not replace a doctor. Do not use these figures to choose treatment or a diet, or to decide whether a child is healthy. If height or weight worries you, take the child to a pediatrician.",
    ),
    "about.methodHeading": ("Метод", "Method"),
    "about.methodBody": (
        "Берём стандарты ВОЗ. До 5 лет это Child Growth Standards 2006, с 5 до 19 лет — справочник роста 2007 года. Для каждого измерения считается перцентиль роста и перцентиль индекса массы тела. Индекс массы тела нужен потому, что он учитывает и вес, и рост. После 10 лет ВОЗ не публикует отдельную таблицу «вес для возраста»: такой вес в основном повторяет рост.\n\n"
        "Если измерение одно, оценка идёт вдоль текущего перцентиля. Если их несколько, по ним виден сдвиг перцентиля. Вперёд переносится только часть этого сдвига: он затухает за несколько лет и ограничен по величине, чтобы одна короткая вспышка не превращалась в прямую линию на десять лет.\n\n"
        "Будущий вес получается из оценённого роста и перцентиля индекса массы тела. Полоса на графике — не доверительный интервал. Она показывает, насколько цифра сдвинется, если перцентиль немного изменится.\n\n"
        "До 2 лет в справочнике длина лёжа, с 2 лет — рост стоя. Разница около 0,7 см, поэтому на кривой в этом возрасте может быть небольшая ступенька. В 10–12 лет девочки того же перцентиля часто выше мальчиков: так устроен справочник. После 19 лет линия больше не описывает рост, а держит взрослый перцентиль.",
        "The estimate uses WHO standards: the Child Growth Standards of 2006 up to age 5, and the 2007 growth reference from 5 to 19. Each measurement gets a height percentile and a BMI percentile. BMI is used because it takes both weight and height into account. After age 10, WHO does not publish a separate weight-for-age table, because that weight mostly echoes height.\n\n"
        "One measurement is extended along its current percentile. Several measurements show whether the percentile is shifting. Only part of that shift is carried forward: it fades over a few years and is limited in size, so one short growth spurt does not become a straight line for ten years.\n\n"
        "Future weight comes from the estimated height and the BMI percentile. The band on the chart is not a confidence interval. It shows how far the figure moves if the percentile changes a little.\n\n"
        "Before age 2 the reference is lying length, and from age 2 it is standing height. The difference is about 0.7 cm, so the curve can step slightly there. Around ages 10 to 12, girls at the same percentile are often taller than boys: that is how the reference is built. After 19 the line no longer describes growth. It holds the adult percentile.",
    ),
    "about.limitsHeading": ("Чего оценка не умеет", "What this estimate cannot do"),
    "about.limitsBody": (
        "Не учитываются рост родителей, срок полового созревания, болезни, лекарства, питание и нагрузка. Приложение не предсказывает, когда начнётся подростковый скачок роста. Два ребёнка на одном перцентиле не обязаны прийти к одному взрослому росту.\n\n"
        "После окончания роста вес зависит от жизни, а не от детской кривой. Оценка считается от последнего введённого возраста, а не от сегодняшней даты.",
        "Parents’ height, the timing of puberty, illness, medicine, food, and activity are not included. The app does not predict when the adolescent growth spurt will start. Two children on the same percentile do not have to reach the same adult height.\n\n"
        "After growth ends, weight depends on life, not on the childhood curve. The estimate is counted from the latest age you entered, not from today’s date.",
    ),
    "about.privacyHeading": ("Данные", "Data"),
    "about.privacyBody": (
        "Приложение для родителей и опекунов. Имя или прозвище, выбор справочника, возраст, рост и вес хранятся только на этом устройстве. Аккаунта нет. Рекламы нет. Данные никуда не отправляются.\n\n"
        "Удаление профиля стирает его измерения. Удаление приложения стирает всё, что оно сохранило. Если у iPhone включено резервное копирование, Apple может сохранить копию данных устройства в iCloud или на компьютере. Это делает система Apple, не это приложение.",
        "The app is for parents and guardians. A name or nickname, the reference chosen, age, height, and weight stay on this device. There is no account and no advertising. Nothing is sent anywhere.\n\n"
        "Deleting a profile erases its measurements. Deleting the app erases everything it stored. If iPhone backup is on, Apple may keep a copy of the device data in iCloud or on a computer. That is done by Apple’s system, not by this app.",
    ),
    "about.sourcesHeading": ("Источники", "Sources"),
    "about.sourcesBody": (
        "WHO Child Growth Standards: length/height-for-age and BMI-for-age. Geneva: World Health Organization, 2006.\n\n"
        "de Onis M, Onyango AW, Borghi E, Siyam A, Nishida C, Siekmann J. Development of a WHO growth reference for school-aged children and adolescents. Bulletin of the World Health Organization. 2007;85:660–667.\n\n"
        "Cole TJ, Green PJ. Smoothing reference centile curves: the LMS method and penalized likelihood. Statistics in Medicine. 1992;11:1305–1319.\n\n"
        "Коэффициенты LMS взяты из опубликованных таблиц ВОЗ. ВОЗ не проверяла это приложение и не одобряла его.",
        "WHO Child Growth Standards: length/height-for-age and BMI-for-age. Geneva: World Health Organization, 2006.\n\n"
        "de Onis M, Onyango AW, Borghi E, Siyam A, Nishida C, Siekmann J. Development of a WHO growth reference for school-aged children and adolescents. Bulletin of the World Health Organization. 2007;85:660–667.\n\n"
        "Cole TJ, Green PJ. Smoothing reference centile curves: the LMS method and penalized likelihood. Statistics in Medicine. 1992;11:1305–1319.\n\n"
        "The LMS coefficients come from the published WHO tables. WHO has not reviewed this app and has not endorsed it.",
    ),
    "about.replay": ("Показать введение ещё раз", "Show the introduction again"),
    "about.version": ("Версия %1$@ (%2$@)", "Version %1$@ (%2$@)"),
    "onboarding.next": ("Дальше", "Next"),
    "onboarding.accept": ("Понимаю и продолжаю", "I understand and continue"),
    "onboarding.1.title": ("Оценка на 10 лет", "A 10-year estimate"),
    "onboarding.1.body": (
        "Приложение для родителей и опекунов. Введите возраст, рост и вес — сейчас и, если помните, за прошлые годы. Мы оценим, какими могут быть рост и вес через 10 лет, если ребёнок продолжит расти около своего перцентиля по справочнику ВОЗ.",
        "An app for parents and guardians. Enter age, height, and weight — current, and earlier years if you remember them. We estimate what height and weight may be in 10 years if the child keeps growing near their WHO percentile.",
    ),
    "onboarding.2.title": ("Прошлые годы помогают", "Earlier years help"),
    "onboarding.2.body": (
        "Одного измерения достаточно для кривой. Два и больше показывают, смещается ли перцентиль. Этот сдвиг учитывается осторожно и затухает: он не продолжается бесконечной прямой.",
        "One measurement is enough for a curve. Two or more show whether the percentile is moving. That shift is applied cautiously and then fades. It does not continue as an endless straight line.",
    ),
    "onboarding.3.title": ("Это не диагноз", "This is not a diagnosis"),
    "onboarding.3.body": (
        "Это не диагноз и не медицинское изделие. Здесь нет роста родителей, срока полового созревания, болезней и питания. По этим цифрам нельзя лечить, назначать диету и решать, всё ли в порядке. Если что-то беспокоит — нужен педиатр.",
        "This is not a diagnosis and not a medical device. Parents’ height, the timing of puberty, illness, and food are not here. These figures cannot be used for treatment, a diet, or deciding that everything is fine. If something worries you, see a pediatrician.",
    ),
    "common.done": ("Готово", "Done"),
    "common.save": ("Сохранить", "Save"),
    "common.cancel": ("Отмена", "Cancel"),
    "common.delete": ("Удалить", "Delete"),
    "common.close": ("Закрыть", "Close"),
    "common.edit": ("Изменить", "Edit"),
    "example.name": ("Пример", "Example"),
    "share.title": ("оценка роста и веса", "height and weight estimate"),
    "share.footer": (
        "Диапазон показывает небольшой сдвиг перцентиля. Это не заключение врача.",
        "The range shows a small percentile shift. It is not a doctor’s conclusion.",
    ),
    "unit.cm": ("см", "cm"),
    "unit.kg": ("кг", "kg"),
    "table.age": ("Возраст", "Age"),
    "table.height": ("Рост", "Height"),
    "table.weight": ("Вес", "Weight"),
}


def catalog(strings: dict[str, tuple[str, str]]) -> dict:
    return {
        "sourceLanguage": "ru",
        "strings": {
            key: {
                "localizations": {
                    "ru": {"stringUnit": {"state": "translated", "value": ru}},
                    "en": {"stringUnit": {"state": "translated", "value": en}},
                }
            }
            for key, (ru, en) in strings.items()
        },
        "version": "1.0",
    }


def write_shared_strings() -> None:
    web = {
        "ru": {key: pair[0] for key, pair in STRINGS.items()},
        "en": {key: pair[1] for key, pair in STRINGS.items()},
    }
    web_path = ROOT / "web" / "strings.json"
    web_path.parent.mkdir(parents=True, exist_ok=True)
    web_path.write_text(json.dumps(web, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    def xml_text(value: str) -> str:
        return (
            value.replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace("'", "\\'")
            .replace('"', '\\"')
            .replace("%1$@", "%1$s")
            .replace("%2$@", "%2$s")
            .replace("\n", "\\n")
        )

    def xml(lang_index: int) -> str:
        lines = ['<resources>']
        for key, pair in STRINGS.items():
            name = re.sub(r"(?<!^)(?=[A-Z])", "_", key).replace(".", "_").lower()
            lines.append(f'    <string name="{name}">{xml_text(pair[lang_index])}</string>')
        lines.append("</resources>")
        return "\n".join(lines) + "\n"

    values = ROOT / "android" / "app" / "src" / "main" / "res" / "values" / "strings.xml"
    english = ROOT / "android" / "app" / "src" / "main" / "res" / "values-en" / "strings.xml"
    values.parent.mkdir(parents=True, exist_ok=True)
    english.parent.mkdir(parents=True, exist_ok=True)
    values.write_text(xml(0), encoding="utf-8")
    english.write_text(xml(1), encoding="utf-8")


def main() -> None:
    source = L10N.read_text(encoding="utf-8")
    used = set(re.findall(r'String\(localized: "([^"]+)"\)', source))
    missing = sorted(used - STRINGS.keys())
    extra = sorted(STRINGS.keys() - used)
    if missing or extra:
        raise SystemExit(f"missing={missing} extra={extra}")
    CATALOG.write_text(json.dumps(catalog(STRINGS), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    info = catalog({
        "CFBundleDisplayName": ("Будущий рост", "FutureSize"),
        "CFBundleName": ("Будущий рост", "FutureSize"),
    })
    INFO.write_text(json.dumps(info, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_shared_strings()
    print(f"{len(used)} strings")


if __name__ == "__main__":
    main()
