////////////////////////////////////////////////////////////////////////////////
// Subsystem "File functions".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// General and personal file settings.

// Returns a structure that contains GeneralSettings and PersonalSettings.
Function FileOperationsSettings() Export
	
	CommonSettings        = New Structure;
	PersonalSettings = New Structure;
	
	FileFunctionsService.WhenAddSettingsFileOperations(
		CommonSettings, PersonalSettings);
	
	AddFileOperationsSettings(CommonSettings, PersonalSettings);
	
	Settings = New Structure;
	Settings.Insert("CommonSettings",        CommonSettings);
	Settings.Insert("PersonalSettings", PersonalSettings);
	
	Return Settings;
	
EndFunction

// Sets general and personal settings of file functions.
Procedure AddFileOperationsSettings(CommonSettings, PersonalSettings)
	
	SetPrivilegedMode(True);
	
	// Fill in general settings.
	
	// ExtractFileTextsAtServer.
	CommonSettings.Insert(
		"ExtractFileTextsAtServer", FileFunctionsService.ExtractFileTextsAtServer());
	
	// MaximumFileSize.
	CommonSettings.Insert("MaximumFileSize", FileFunctions.MaximumFileSize());
	
	// ProhibitImportFilesByExtension.
	ProhibitImportFilesByExtension = Constants.ProhibitImportFilesByExtension.Get();
	If ProhibitImportFilesByExtension = Undefined Then
		ProhibitImportFilesByExtension = False;
		Constants.ProhibitImportFilesByExtension.Set(ProhibitImportFilesByExtension);
	EndIf;
	CommonSettings.Insert("ImportingFilesByExtensionProhibition", ProhibitImportFilesByExtension);
	
	// ProhibitedExtensionsList.
	CommonSettings.Insert("ProhibitedExtensionsList", ProhibitedExtensionsList());
	
	// FileExtensionListOpenDocument.
	CommonSettings.Insert("FileExtensionListOpenDocument", FileExtensionListOpenDocument());
	
	// TextFileExtensionsList.
	CommonSettings.Insert("TextFileExtensionsList", TextFileExtensionsList());
	
	// Fill in personal settings.
	
	// LocalFilesCacheMaximumSize.
	LocalFilesCacheMaximumSize = CommonUse.CommonSettingsStorageImport(
		"LocalFilesCache", "LocalFilesCacheMaximumSize");
	
	If LocalFilesCacheMaximumSize = Undefined Then
		LocalFilesCacheMaximumSize = 100*1024*1024; // 100 Mb.
		
		CommonUse.CommonSettingsStorageSave(
			"LocalFilesCache",
			"LocalFilesCacheMaximumSize",
			LocalFilesCacheMaximumSize);
	EndIf;
	
	PersonalSettings.Insert(
		"LocalFilesCacheMaximumSize",
		LocalFilesCacheMaximumSize);
	
	// PathToFilesLocalCache.
	PathToFilesLocalCache = CommonUse.CommonSettingsStorageImport(
		"LocalFilesCache", "PathToFilesLocalCache");
	// It is not recommended to get this variable directly.
	// You must use function UserWorkingDirectory 
	// of module FileFunctionsServiceClient.
	PersonalSettings.Insert("PathToFilesLocalCache", PathToFilesLocalCache);
	
	// DeleteFileFromFilesLocalCacheOnEditEnd.
	DeleteFileFromFilesLocalCacheOnEditEnd =
		CommonUse.CommonSettingsStorageImport(
			"LocalFilesCache", "DeleteFileFromFilesLocalCacheOnEditEnd");
	
	If DeleteFileFromFilesLocalCacheOnEditEnd = Undefined Then
		DeleteFileFromFilesLocalCacheOnEditEnd = False;
	EndIf;
	
	PersonalSettings.Insert(
		"DeleteFileFromFilesLocalCacheOnEditEnd",
		DeleteFileFromFilesLocalCacheOnEditEnd);
	
	// ConfirmWhenDeletingFromLocalFilesCache.
	ConfirmWhenDeletingFromLocalFilesCache =
		CommonUse.CommonSettingsStorageImport(
			"LocalFilesCache", "ConfirmWhenDeletingFromLocalFilesCache");
	
	If ConfirmWhenDeletingFromLocalFilesCache = Undefined Then
		ConfirmWhenDeletingFromLocalFilesCache = False;
	EndIf;
	
	PersonalSettings.Insert(
		"ConfirmWhenDeletingFromLocalFilesCache",
		ConfirmWhenDeletingFromLocalFilesCache);
	
	// ShowFileEditTips.
	ShowFileEditTips = CommonUse.CommonSettingsStorageImport(
		"ApplicationSettings", "ShowFileEditTips");
	
	If ShowFileEditTips = Undefined Then
		ShowFileEditTips = True;
		
		CommonUse.CommonSettingsStorageSave(
			"ApplicationSettings",
			"ShowFileEditTips",
			ShowFileEditTips);
	EndIf;
	PersonalSettings.Insert(
		"ShowFileEditTips",
		ShowFileEditTips);
	
	// ShowFileNotChangedMessage.
	ShowFileNotChangedMessage = CommonUse.CommonSettingsStorageImport(
		"ApplicationSettings", "ShowFileNotChangedMessage");
	
	If ShowFileNotChangedMessage = Undefined Then
		ShowFileNotChangedMessage = True;
		
		CommonUse.CommonSettingsStorageSave(
			"ApplicationSettings",
			"ShowFileNotChangedMessage",
			ShowFileNotChangedMessage);
	EndIf;
	PersonalSettings.Insert(
		"ShowFileNotChangedMessage",
		ShowFileNotChangedMessage);
	
	// File opening settings.
	TextFilesExtension = CommonUse.CommonSettingsStorageImport(
		"OpenFileSettings\TextFiles",
		"Extension", "TXT XML INI");
	
	TextFilesOpeningMethod = CommonUse.CommonSettingsStorageImport(
		"OpenFileSettings\TextFiles", 
		"OpeningMethod",
		Enums.OpenFileForViewingVariants.InEmbeddedEditor);
	
	GraphicalSchemaExtension = CommonUse.CommonSettingsStorageImport(
		"OpenFileSettings\GraphicSchemes", "Extension", "GRS");
	
	GraphicSchemesOpeningMethod = CommonUse.CommonSettingsStorageImport(
		"OpenFileSettings\GraphicSchemes",
		"OpeningMethod",
		Enums.OpenFileForViewingVariants.InEmbeddedEditor);
	
	PersonalSettings.Insert("TextFilesExtension",       TextFilesExtension);
	PersonalSettings.Insert("TextFilesOpeningMethod",   TextFilesOpeningMethod);
	PersonalSettings.Insert("GraphicalSchemaExtension",     GraphicalSchemaExtension);
	PersonalSettings.Insert("GraphicSchemesOpeningMethod", GraphicSchemesOpeningMethod);
	
EndProcedure

Function ProhibitedExtensionsList()
	
	SetPrivilegedMode(True);
	
	ProhibitedDataAreaFileExtensionList =
		Constants.ProhibitedDataAreaFileExtensionList.Get();
	
	If ProhibitedDataAreaFileExtensionList = Undefined
	 OR ProhibitedDataAreaFileExtensionList = "" Then
		
		ProhibitedDataAreaFileExtensionList = "COM EXE BAT CMD VBS VBE JS JSE WSF WSH PCR";
		
		Constants.ProhibitedDataAreaFileExtensionList.Set(
			ProhibitedDataAreaFileExtensionList);
	EndIf;
	
	FinalListOfExtensions = "";
	
	If CommonUseReUse.DataSeparationEnabled()
	   AND CommonUseReUse.CanUseSeparatedData() Then
		
		ProhibitedExtensionsList = Constants.ProhibitedExtensionsList.Get();
		
		FinalListOfExtensions = 
			ProhibitedExtensionsList + " "  + ProhibitedDataAreaFileExtensionList;
	Else
		FinalListOfExtensions = ProhibitedDataAreaFileExtensionList;
	EndIf;
		
	Return FinalListOfExtensions;
	
EndFunction

Function FileExtensionListOpenDocument()
	
	SetPrivilegedMode(True);
	
	DataAreasOpenDocumentFileExtensionList =
		Constants.DataAreasOpenDocumentFileExtensionList.Get();
	
	If DataAreasOpenDocumentFileExtensionList = Undefined
	 OR DataAreasOpenDocumentFileExtensionList = "" Then
		
		DataAreasOpenDocumentFileExtensionList =
			"ODT OTT ODP OTP ODS OTS ODC OTC ODF OTF ODM OTH SDW STW SXW STC SXC SDC SDD STI";
		
		Constants.DataAreasOpenDocumentFileExtensionList.Set(
			DataAreasOpenDocumentFileExtensionList);
	EndIf;
	
	FinalListOfExtensions = "";
	
	If CommonUseReUse.DataSeparationEnabled()
	   AND CommonUseReUse.CanUseSeparatedData() Then
		
		ProhibitedExtensionsList = Constants.FileExtensionListOpenDocument.Get();
		
		FinalListOfExtensions =
			ProhibitedExtensionsList + " "  + DataAreasOpenDocumentFileExtensionList;
	Else
		FinalListOfExtensions = DataAreasOpenDocumentFileExtensionList;
	EndIf;
	
	Return FinalListOfExtensions;
	
EndFunction

Function TextFileExtensionsList()

	SetPrivilegedMode(True);
	
	TextFileExtensionsList = Constants.TextFileExtensionsList.Get();
	
	If IsBlankString(TextFileExtensionsList) Then
		TextFileExtensionsList = "TXT";
		Constants.TextFileExtensionsList.Set(TextFileExtensionsList);
	EndIf;
	
	Return TextFileExtensionsList;

EndFunction

#EndRegion
