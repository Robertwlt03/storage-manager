/// Every visible text of the app as a typed key. The texts live in
/// `Resources/<code>.lproj/Localizable.strings`; the tests fail if a key is missing in one of the
/// languages.
nonisolated enum TextKey: String, CaseIterable {
    // App and sidebar
    case appName, paneOverview, paneExplorer, paneLargeFiles, paneTemporaryFiles, paneCopies,
        sectionSystem,
        sectionVolumes
    case rescan, rescanHelp, cancelScan

    // Scan status and placeholders
    case cancel, filesAndSize, measuredAt, scanNow, unreadable
    case notMeasuredTitle, notMeasuredDetail, scanningTitle, scanningDetail
    case loadingSummaryTitle, loadingSummaryDetail, loadingSizesTitle, loadingSizesDetail,
        loadingAppsTitle, loadingAppsDetail, showSidebar, hideSidebar

    // Overview and categories
    case availableOf, categories, freeSpace, temporaryAreaName
    case categoryApps, categoryDocuments, categoryDownloads, categoryMedia, categoryICloud,
        categoryMail, categoryDeveloper, categoryCaches, categoryAppData
    case categoryTrash, categoryTemporary, categoryUser, categoryLibrary, categoryOther,
        categoryPurgeable, categorySystem

    // Explorer, tables and info sheet
    case columnName, columnSize, columnShare, columnFiles, columnLocation, smallerItems,
        measuredTotal
    case open, showInFinder, info, copyPath, done
    case allocated, kind, modified, created, contents, files, folders, packages, modifiedBetween,
        dateRange
    case analyzing, typesBySize, fileCount, noExtension

    // Large files
    case minimumSize, fromSize, noFilesFrom, filesTotal

    // Temporary area
    case location, total, subfolders, viewCopies
    case temporaryFolderT, temporaryFolderTDetail, temporaryFolderC, temporaryFolderCDetail,
        temporaryFolderX,
        temporaryFolderXDetail, temporaryFolder0, temporaryFolder0Detail

    // Signature copies
    case noCopies, noCopiesDetail, running, stopped, copiesLabel, countedSize, installedVersion,
        notFound
    case versionLabel, copiesOne, copiesMany, current, old, unknown, createdOn, freed, deleteError,
        quitToDelete
    case openInExplorer, deleteAll, deleteTitle, deleteForever, deleteMessage

    // Volumes
    case capacity, used, purgeable, available, toOverview, exploreContents, scanAndExplore,
        volumeGone

    // Search
    case searchPrompt, scopeAll, scopeFolders, scopeFiles, searchResults, noResults, searchNote

    // Full Disk Access
    case accessTitle, accessDetail, accessOneSwitch, accessOpenSettings, accessContinue
    case accessGranted, fullDiskAccess, accessRestart, accessRestartHint, quitApp

    // Key figures, cleaner, unused apps, layout
    case paneCleaner, paneApps, sectionTidy, layoutList, layoutGrid, settings, emptyFolder,
        otherCategories, cleanCaches, cleanCachesDetail, cleanDeveloper, cleanDeveloperDetail,
        cleanLogs, cleanLogsDetail, cleanTemporary, cleanTemporaryDetail, cleanTrash,
        cleanTrashDetail,
        cleanFailed, cleaning, cleanerRefresh, cleanSelected, cleanConfirmTitle,
        cleanConfirmMessage, appsNoneUnused, unusedSince, daysOption, trashAppTitle,
        trashAppMessage, moveToTrash, lastOpened, trashAppFailed, figureFiles, figureUnusedApps,
        bucketUnder1MB, bucketTo10MB, bucketTo100MB, bucketTo1GB, bucketOver1GB

    // Scan progress and empty values
    case scanningPercent, scanningArea, emptyValue

    // Page info, scan details, summary
    case infoOverview, infoCleaner, infoApps, infoExplorer, infoLargeFiles, infoTemporaryFiles,
        infoCopies,
        infoVolume, aboutPage, scanDetails, scanProgress, scanArea, scanFinished,
        accessMissingShort, summaryTitle, summaryDisk, summaryTop, summaryNotMeasured, summaryClean,
        summaryCopies, summaryApps, readAloud, stopReading

    // Key figures and size classes in plain words
    case sizeClassesTitle, sizeClassesCaption, figureLargeFilesFrom, bucketValue

    // Settings
    case autoScan
    case extraFolders, none, add, remove, settingsSystemNote
}
