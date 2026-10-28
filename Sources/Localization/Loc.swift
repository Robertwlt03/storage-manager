/// Every visible text of the app as a typed key. The texts live in `Resources/<code>.lproj/Localizable.strings`;
/// `--check-strings` (run by build.sh) fails if a key is missing in one of the languages.
enum Loc: String, CaseIterable {
    // App and sidebar
    case appName, paneOverview, paneExplorer, paneLargeFiles, paneTemp, paneCopies, sectionSystem, sectionVolumes
    case rescan, rescanHelp, cancelScan

    // Scan status and placeholders
    case scanning, cancel, filesAndSize, measuredAt, scanNow, unreadable, unreadableHelp
    case notMeasuredTitle, notMeasuredDetail, scanningTitle, scanningDetail

    // Overview and categories
    case availableOf, categories, overviewNote, freeSpace, tempAreaName
    case catApps, catDocuments, catDownloads, catMedia, catICloud, catMail, catDeveloper, catCaches, catAppData
    case catTrash, catTemp, catUser, catLibrary, catOther, catPurgeable, catSystem

    // Explorer, tables and info sheet
    case columnName, columnSize, columnShare, columnFiles, columnLocation, smallerItems, measuredTotal
    case open, showInFinder, info, copyPath, done
    case allocated, kind, modified, created, contents, files, folders, packages, modifiedBetween, dateRange
    case analyzing, typesBySize, fileCount, noExtension

    // Large files
    case minSize, fromSize, noFilesFrom, filesTotal

    // Temporary area
    case tempIntro, location, total, subfolders, viewCopies
    case tempT, tempTDetail, tempC, tempCDetail, tempX, tempXDetail, temp0, temp0Detail

    // Signature copies
    case copiesIntro, noCopies, noCopiesDetail, running, stopped, copiesLabel, countedSize, installedVersion, notFound
    case versionLabel, copiesOne, copiesMany, current, old, unknown, createdOn, freed, deleteError, quitToDelete
    case openInExplorer, deleteAll, deleteTitle, deleteForever, deleteMessage

    // Volumes
    case capacity, used, purgeable, available, toOverview, exploreContents, scanAndExplore, volumeGone

    // Search
    case searchPrompt, scopeAll, scopeFolders, scopeFiles, searchResults, noResults, searchNote

    // Full Disk Access
    case accessTitle, accessDetail, accessOneSwitch, accessOpenSettings, accessContinue
    case accessGranted, fullDiskAccess, accessRestart, accessRestartHint

    // Statistics, cleaner, unused apps, layout
    case paneStatistics, paneCleaner, paneApps, sectionTidy, layout, layoutList, layoutGrid, settings, scanningBanner, emptyFolder, otherCategories, otherTypes, cleanCaches, cleanCachesDetail, cleanDeveloper, cleanDeveloperDetail, cleanLogs, cleanLogsDetail, cleanTemp, cleanTempDetail, cleanTrash, cleanTrashDetail, cleanerIntro, cleanerSearching, cleanFailed, cleaning, cleanerRefresh, cleanSelected, cleanConfirmTitle, cleanConfirmMessage, appsIntro, appsNoneUnused, unusedSince, daysOption, trashAppTitle, trashAppMessage, moveToTrash, lastOpened, trashAppFailed, statFiles, statScanned, statLargeFiles, statUnusedApps, sizeDistribution, statisticsNote, bucketUnder1MB, bucketTo10MB, bucketTo100MB, bucketTo1GB, bucketOver1GB

    // Settings
    case tabGeneral, tabAppearance, tabScanning, language, languageSystem, languageNote
    case appearance, appearanceSystem, appearanceLight, appearanceDark
    case liquidGlass, liquidGlassDetail, liquidGlassUnavailable, chartColors, paletteColourful, paletteAccent, paletteGrey
    case binaryUnits, binaryUnitsDetail, autoScan, pauseLowPower, pauseLowPowerDetail, eco, ecoDetail
    case extraFolders, none, add, remove
}
