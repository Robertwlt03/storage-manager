/// Every visible text of the app as a typed key. The texts live in `Resources/<code>.lproj/Localizable.strings`;
/// `--check-strings` (run by build.sh) fails if a key is missing in one of the languages.
enum Loc: String, CaseIterable {
    // App and sidebar
    case appName, paneOverview, paneExplorer, paneLargeFiles, paneTemp, paneCopies, sectionSystem, sectionVolumes
    case rescan, rescanHelp, cancelScan

    // Scan status and placeholders
    case scanning, cancel, filesAndSize, measuredAt, scanNow, unreadable
    case notMeasuredTitle, notMeasuredDetail, scanningTitle, scanningDetail

    // Overview and categories
    case availableOf, categories, freeSpace, tempAreaName
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
    case location, total, subfolders, viewCopies
    case tempT, tempTDetail, tempC, tempCDetail, tempX, tempXDetail, temp0, temp0Detail

    // Signature copies
    case noCopies, noCopiesDetail, running, stopped, copiesLabel, countedSize, installedVersion, notFound
    case versionLabel, copiesOne, copiesMany, current, old, unknown, createdOn, freed, deleteError, quitToDelete
    case openInExplorer, deleteAll, deleteTitle, deleteForever, deleteMessage

    // Volumes
    case capacity, used, purgeable, available, toOverview, exploreContents, scanAndExplore, volumeGone

    // Search
    case searchPrompt, scopeAll, scopeFolders, scopeFiles, searchResults, noResults, searchNote

    // Full Disk Access
    case accessTitle, accessDetail, accessOneSwitch, accessOpenSettings, accessContinue
    case accessGranted, fullDiskAccess, accessRestart, accessRestartHint

    // Key figures, cleaner, unused apps, layout
    case paneCleaner, paneApps, sectionTidy, layout, layoutList, layoutGrid, settings, emptyFolder, otherCategories, cleanCaches, cleanCachesDetail, cleanDeveloper, cleanDeveloperDetail, cleanLogs, cleanLogsDetail, cleanTemp, cleanTempDetail, cleanTrash, cleanTrashDetail, cleanerSearching, cleanFailed, cleaning, cleanerRefresh, cleanSelected, cleanConfirmTitle, cleanConfirmMessage, appsNoneUnused, unusedSince, daysOption, trashAppTitle, trashAppMessage, moveToTrash, lastOpened, trashAppFailed, statFiles, statUnusedApps, bucketUnder1MB, bucketTo10MB, bucketTo100MB, bucketTo1GB, bucketOver1GB

    // Scan progress and empty values
    case scanningPercent, scanningArea, emptyValue

    // Page info, scan details, summary
    case infoOverview, infoCleaner, infoApps, infoExplorer, infoLargeFiles, infoTemp, infoCopies, infoVolume, aboutPage, scanDetails, scanProgress, scanArea, scanFinished, accessMissingShort, summaryTitle, summaryDisk, summaryTop, summaryNotMeasured, summaryClean, summaryCopies, summaryApps, readAloud, stopReading

    // Key figures and size classes in plain words
    case statSizesTitle, statSizesCaption, statLargeFilesFrom, bucketValue

    // Settings
    case autoScan
    case extraFolders, none, add, remove, settingsSystemNote
}
