import Foundation

enum Lang: String {
    case ru, en
}

enum L: String {
    case orgTitle, peopleTitle, exportTitle, settingsTitle
    case tabOrg, tabPeople, tabExport, tabSettings
    case search
    case formatGroup, tierGroup, themeGroup, langGroup, langLabel
    case watermarkNote, removeInPro, noWatermark
    case exportBtn, later, message, messageSent
    case themeProHint
    case menuAddReport, menuAddComanager, menuDelete, menuCancel
    case currentBadge
    case tierFreeName, tierFreePrice, tierFreeBlurb, tierFreeCta
    case tierProName, tierProPrice, tierProBlurb, tierProCta
    case tierMaxName, tierMaxPrice, tierMaxBlurb, tierMaxCta
    case tierChanged, themeChanged
    case limitTitleFree, limitTextFree, limitTitlePro, limitTextPro
    case themeUpsellTitle, themeUpsellText
    case limitProBtn, limitMaxBtn
    case addedReport, addedComanager, vacated, hired
    case newHireName, newHireTitle, newComanagerName
    case exportStarted, closeDetail
    case csvGroup, csvMaxOnlyNote, csvExportBtn, csvImportBtn
    case csvUpsellTitle, csvUpsellText
    case csvImportSheetTitle, csvChooseFile, csvPreviewTitle, csvReplaceConfirm, csvCancel
    case csvReadError
    case restorePurchases
    case scopeGroup, includeFoundersToggle, limitDepthToggle, depthStepper
    case pdfStyleGroup, pdfStyleChart, pdfStyleList, paperSizeGroup
    case branchExportAction, branchExportTitle
    case posterModeToggle
}

enum Strings {
    private static let ru: [L: String] = [
        .orgTitle: "MyOffice", .peopleTitle: "Сотрудники", .exportTitle: "Экспорт", .settingsTitle: "Настройки",
        .tabOrg: "Структура", .tabPeople: "Люди", .tabExport: "Экспорт", .tabSettings: "Настройки",
        .search: "Поиск по имени или должности",
        .formatGroup: "Формат файла", .tierGroup: "Тариф", .themeGroup: "Тема оформления",
        .langGroup: "Язык", .langLabel: "Язык интерфейса",
        .watermarkNote: "Тариф FREE — экспорт с водяным знаком.", .removeInPro: "Убрать в PRO/MAX →",
        .noWatermark: "Экспорт без водяного знака ✓",
        .exportBtn: "Экспортировать", .later: "Позже", .message: "Написать сообщение", .messageSent: "Сообщение отправлено (демо)",
        .themeProHint: "Темы доступны на тарифе PRO и MAX",
        .menuAddReport: "Добавить подчинённого", .menuAddComanager: "Добавить со-руководителя",
        .menuDelete: "Освободить должность", .menuCancel: "Отмена",
        .currentBadge: "Текущий",
        .tierFreeName: "FREE", .tierFreePrice: "Бесплатно", .tierFreeBlurb: "До 7 сотрудников, экспорт с водяным знаком.", .tierFreeCta: "Выбрать",
        .tierProName: "PRO", .tierProPrice: "$8.99", .tierProBlurb: "До 35 сотрудников, экспорт без водяного знака, темы оформления.", .tierProCta: "Купить",
        .tierMaxName: "MAX", .tierMaxPrice: "$14.99", .tierMaxBlurb: "Без лимита сотрудников, все темы оформления.", .tierMaxCta: "Купить",
        .tierChanged: "Тариф изменён ✓", .themeChanged: "Тема применена ✓",
        .limitTitleFree: "Достигнут лимит FREE", .limitTextFree: "В бесплатном тарифе — до 7 сотрудников. Снимите ограничение на PRO (35) или MAX (без лимита).",
        .limitTitlePro: "Достигнут лимит PRO", .limitTextPro: "На тарифе PRO — до 35 сотрудников. Снимите ограничение на MAX (без лимита).",
        .themeUpsellTitle: "Тема доступна на PRO/MAX", .themeUpsellText: "Дополнительные темы оформления открываются на тарифе PRO или MAX.",
        .limitProBtn: "PRO — $8.99, до 35 сотрудников", .limitMaxBtn: "MAX — $14.99, без лимита",
        .addedReport: "Добавлен новый сотрудник", .addedComanager: "Добавлен со-руководитель", .vacated: "Должность освобождена",
        .hired: "Вакансия занята — сотрудник добавлен",
        .newHireName: "Новый сотрудник", .newHireTitle: "Новая должность", .newComanagerName: "Новый со-руководитель",
        .exportStarted: "Экспорт запущен (демо)", .closeDetail: "Закрыть",
        .csvGroup: "Обмен данными (CSV)", .csvMaxOnlyNote: "Доступно на тарифе MAX",
        .csvExportBtn: "Экспортировать в CSV", .csvImportBtn: "Импортировать из CSV",
        .csvUpsellTitle: "CSV доступен на MAX", .csvUpsellText: "Импорт и экспорт всей структуры через CSV — функция тарифа MAX.",
        .csvImportSheetTitle: "Импорт из CSV", .csvChooseFile: "Выбрать CSV-файл",
        .csvPreviewTitle: "Предпросмотр импорта", .csvReplaceConfirm: "Заменить текущие данные",
        .csvCancel: "Отмена", .csvReadError: "Не удалось прочитать файл",
        .restorePurchases: "Восстановить покупки",
        .scopeGroup: "Что показывать", .includeFoundersToggle: "Показывать учредителей",
        .limitDepthToggle: "Ограничить по уровням", .depthStepper: "Уровней",
        .pdfStyleGroup: "Стиль PDF", .pdfStyleChart: "Схема", .pdfStyleList: "Список",
        .paperSizeGroup: "Размер листа",
        .branchExportAction: "Экспортировать эту ветку", .branchExportTitle: "Экспорт ветки",
        .posterModeToggle: "Плакат (в реальном размере, несколько листов)",
    ]

    private static let en: [L: String] = [
        .orgTitle: "MyOffice", .peopleTitle: "People", .exportTitle: "Export", .settingsTitle: "Settings",
        .tabOrg: "Structure", .tabPeople: "People", .tabExport: "Export", .tabSettings: "Settings",
        .search: "Search by name or title",
        .formatGroup: "File format", .tierGroup: "Plan", .themeGroup: "Workspace theme",
        .langGroup: "Language", .langLabel: "Interface language",
        .watermarkNote: "FREE plan — export includes a watermark.", .removeInPro: "Remove with PRO/MAX →",
        .noWatermark: "Export without a watermark ✓",
        .exportBtn: "Export", .later: "Later", .message: "Send message", .messageSent: "Message sent (demo)",
        .themeProHint: "Themes are available on the PRO and MAX plans",
        .menuAddReport: "Add report", .menuAddComanager: "Add co-manager",
        .menuDelete: "Vacate position", .menuCancel: "Cancel",
        .currentBadge: "Current",
        .tierFreeName: "FREE", .tierFreePrice: "Free", .tierFreeBlurb: "Up to 7 employees, export includes a watermark.", .tierFreeCta: "Select",
        .tierProName: "PRO", .tierProPrice: "$8.99", .tierProBlurb: "Up to 35 employees, watermark-free export, workspace themes.", .tierProCta: "Buy",
        .tierMaxName: "MAX", .tierMaxPrice: "$14.99", .tierMaxBlurb: "Unlimited employees, all workspace themes.", .tierMaxCta: "Buy",
        .tierChanged: "Plan changed ✓", .themeChanged: "Theme applied ✓",
        .limitTitleFree: "FREE limit reached", .limitTextFree: "The FREE plan allows up to 7 employees. Remove the limit with PRO (35) or MAX (unlimited).",
        .limitTitlePro: "PRO limit reached", .limitTextPro: "The PRO plan allows up to 35 employees. Remove the limit with MAX (unlimited).",
        .themeUpsellTitle: "Theme available on PRO/MAX", .themeUpsellText: "Extra workspace themes unlock on the PRO or MAX plan.",
        .limitProBtn: "PRO — $8.99, up to 35 employees", .limitMaxBtn: "MAX — $14.99, unlimited",
        .addedReport: "New employee added", .addedComanager: "Co-manager added", .vacated: "Position vacated",
        .hired: "Vacancy filled — employee added",
        .newHireName: "New hire", .newHireTitle: "New position", .newComanagerName: "New co-manager",
        .exportStarted: "Export started (demo)", .closeDetail: "Close",
        .csvGroup: "Data exchange (CSV)", .csvMaxOnlyNote: "Available on the MAX plan",
        .csvExportBtn: "Export to CSV", .csvImportBtn: "Import from CSV",
        .csvUpsellTitle: "CSV is a MAX feature", .csvUpsellText: "Importing and exporting the whole chart via CSV unlocks on the MAX plan.",
        .csvImportSheetTitle: "Import from CSV", .csvChooseFile: "Choose CSV file",
        .csvPreviewTitle: "Import preview", .csvReplaceConfirm: "Replace current data",
        .csvCancel: "Cancel", .csvReadError: "Couldn't read the file",
        .restorePurchases: "Restore purchases",
        .scopeGroup: "What to include", .includeFoundersToggle: "Include founders",
        .limitDepthToggle: "Limit by levels", .depthStepper: "Levels",
        .pdfStyleGroup: "PDF style", .pdfStyleChart: "Chart", .pdfStyleList: "List",
        .paperSizeGroup: "Paper size",
        .branchExportAction: "Export this branch", .branchExportTitle: "Branch export",
        .posterModeToggle: "Poster (full size, multiple sheets)",
    ]

    static func t(_ key: L, _ lang: Lang) -> String {
        (lang == .ru ? ru[key] : en[key]) ?? key.rawValue
    }
}
