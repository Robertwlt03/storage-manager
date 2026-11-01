/// Every visible text of the app as a typed key. The texts live in
/// `Resources/<code>.lproj/Localizable.strings`; the tests fail if a key is missing in one of the
/// languages.
nonisolated enum TextKey: String, CaseIterable {
    // App and sidebar
    case appName, paneOverview, paneExplorer, paneLargeFiles, paneTemporaryFiles, paneCopies,
        sectionVolumes
    case rescan, rescanHelp, cancelScan

    // Scan status and placeholders
    case cancel, filesAndSize, measuredAt, scanNow, unreadable
    case notMeasuredTitle, notMeasuredDetail, scanningTitle, scanningDetail
    case loadingAppsTitle, loadingAppsDetail, showSidebar, hideSidebar

    // Overview and categories
    case availableOf, categories, freeSpace, temporaryAreaName, homeFolderName
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
    case minimumSize, fromSize, noFilesFrom, noFilesFromDetail, filesTotal

    // Temporary area
    case subfolders, viewCopies
    case temporaryFolderT, temporaryFolderTDetail, temporaryFolderC, temporaryFolderCDetail,
        temporaryFolderX,
        temporaryFolderXDetail, temporaryFolder0, temporaryFolder0Detail

    // Signature copies
    case noCopies, noCopiesDetail, copiesLabel, countedSize, installedVersion,
        notFound
    case versionLabel, copiesOne, copiesMany, current, old, unknown, createdOn, freed, deleteError,
        quitToDelete, copiesSafeToDelete, technicalDetails
    case openInExplorer, deleteAll, deleteTitle, deleteForever, deleteMessage

    // Volumes
    case used, purgeable, exploreContents, scanAndExplore,
        volumeGone

    // Search
    case searchPrompt, scopeAll, scopeFolders, scopeFiles, searchResults, noResults, searchNote

    // Full Disk Access
    case accessTitle, accessDetail, accessOneSwitch, accessOpenSettings, accessContinue
    case accessGranted, fullDiskAccess, accessRestart, accessRestartHint, quitApp

    // Cleaner, unused apps, layout
    case paneCleaner, paneApps, sectionTidy, layoutList, layoutGrid, settings, emptyFolder,
        cleanCaches, cleanCachesDetail, cleanDeveloper, cleanDeveloperDetail,
        cleanLogs, cleanLogsDetail, cleanTemporary, cleanTemporaryDetail, cleanTrash,
        cleanTrashDetail, cleanInstallers, cleanInstallersDetail, cleanConfirmInstallersMessage,
        cleanFailed, cleanNothingLeft, cleaning, cleanerRefresh, cleanSelected, cleanConfirmTitle,
        cleanConfirmMessage, appsNoneUnused, appsNoneUnusedDetail, unusedSince, daysOption,
        trashAppTitle, trashAppMessage, moveToTrash, lastOpened, trashAppFailed

    // Scan progress and empty values
    case scanningPercent, scanningArea, emptyValue

    // Page info, scan details, summary
    case infoOverview, infoCleaner, infoApps, infoExplorer, infoLargeFiles, infoTemporaryFiles,
        infoCopies,
        infoVolume, guideOverview, guideExplorer, guideLargeFiles, guideCleaner, guideDuplicates,
        guideApps, guideTemporaryFiles, guideCopies, guideVolume, aboutPage, scanDetails,
        scanProgress, scanArea, scanFinished,
        accessMissingShort, summaryDisk, summaryTop, summaryNotMeasured, summaryClean,
        summaryCopies, summaryApps, summaryFreed

    // Size classes in plain words
    case historyTitle, historyCaption, historyAfterNextScan, grownSince, grownBy, nothingGrown

    // Settings
    case autoScan
    case paneDuplicates, infoDuplicates, noDuplicates, noDuplicatesDetail, duplicateGroupTitle,
        searchingDuplicates
    case searchingDuplicatesDetail, duplicatesTotal
    case rings, layoutSwitch
    case exportReport, reportTitle, reportFileName
    case extraFolders, extraFoldersHint, excludedFolders, excludedFoldersHint, showInMenuBar,
        openApp, lowSpaceWarning, none, add, remove,
        appLanguage,
        languageLikeMac
    case languageRestartHint

    // Free-up guide on the overview, advanced pages
    case freeUpTitle, freeUpCaption, freeUpNothing, freeUpLoadingTitle, freeUpLoadingDetail
    case freeUpCleanerDetail, freeUpDuplicatesDetail, freeUpDuplicatesNotSearched, freeUpAppsDetail
    case sectionAdvanced, showAdvancedPages
}
