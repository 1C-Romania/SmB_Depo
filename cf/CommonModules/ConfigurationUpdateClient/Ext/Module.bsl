////////////////////////////////////////////////////////////////////////////////
// Subsystem "Configuration update".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ApplicationInterface

// Checks if there is configuration update on application start.
//
Procedure CheckConfigurationUpdate() Export
	
	If CommonUseClientServer.IsLinuxClient() Then
		Return;
	EndIf;
	
#If Not WebClient Then
	ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	If ClientWorkParameters.DataSeparationEnabled Or Not ClientWorkParameters.CanUseSeparatedData Then
		Return;
	EndIf;
	
	ApplicationParameters["StandardSubsystems.AvailableConfigurationUpdate"] = Undefined;
	UpdateSettings = ClientWorkParameters.UpdateSettings;
	AvailabilityOfUpdate = UpdateSettings.CheckPastBaseUpdate;
	
	If AvailabilityOfUpdate Then
		// The previous update should be complete.
		OpenForm("DataProcessor.ConfigurationUpdate.Form.Form");
		Return;
	EndIf;
	
	If Not AvailabilityOfUpdate AND UpdateSettings.IsAccessForUpdate Then
		AvailabilityOfUpdate = UpdateSettings.ConfigurationChanged;
	EndIf;
	
	AvailableUpdatePageDescription	= "AvailableUpdate";
	DescriptionPagesUpdateFile			= "UpdateFile";
	IsAffordableInternetEnabledRefresh			= False;
	
	ParameterName = "StandardSubsystems.ConfigurationUpdateOptions";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	ApplicationParameters[ParameterName] = UpdateSettings.ConfigurationUpdateOptions;
	ConfigurationUpdateOptions = ApplicationParameters[ParameterName];
	
	If Not AvailabilityOfUpdate AND ConfigurationUpdateOptions <> Undefined
		AND UpdateSettings.HasAccessForChecksUpdate AND
		(ConfigurationUpdateOptions.CheckUpdateExistsOnStart = 1 OR
		ConfigurationUpdateOptions.CheckUpdateExistsOnStart = 2) Then
		
		// Enable waiting handler to check for update on the Internet.
		If ConfigurationUpdateOptions.CheckUpdateExistsOnStart = 1
			AND ConfigurationUpdateOptions.ScheduleOfUpdateExistsCheck <> Undefined Then
			EnableDisableCheckOnSchedule(True);
		EndIf;
		
		Parameters = GetAvailableConfigurationUpdate();
		// If schedule is not specified, then check for update now.
		If ConfigurationUpdateOptions.CheckUpdateExistsOnStart = 2 Then
			CheckUpdateExistsViaInternet();
			IsAffordableInternetEnabledRefresh = ConfigurationUpdateOptions.UpdateSource <> -1 
				AND Parameters.PageName = AvailableUpdatePageDescription;
			If Not AvailabilityOfUpdate AND IsAffordableInternetEnabledRefresh Then
				AvailabilityOfUpdate = IsAffordableInternetEnabledRefresh;
			EndIf;
		EndIf;
		If Not AvailabilityOfUpdate Then 
			Return;
		EndIf;
	EndIf;
	
	If UpdateSettings.ConfigurationChanged AND UpdateSettings.HasAccessForChecksUpdate Then
		Settings = ConfigurationUpdateClientServer.GetUpdatedConfigurationUpdateSettings(
			ApplicationParameters["StandardSubsystems.ConfigurationUpdateOptions"]);
		Settings.UpdateSource	= 2;  // Local or network directory.
		Settings.NeedUpdateFile	= False;
		ConfigurationUpdateServerCall.WriteStructureOfAssistantSettings(ConfigurationUpdateOptions);
		
		Parameters = GetAvailableConfigurationUpdate();
		Parameters.UpdateSource = ConfigurationUpdateOptions.UpdateSource;
		Parameters.NeedUpdateFile = ConfigurationUpdateOptions.NeedUpdateFile;
		Parameters.FlagOfAutoTransitionToPageWithUpdate = True;
		ShowUserNotification(NStr("en='Configuration update';ru='Обновление конфигурации'"),
			"e1cib/app/DataProcessor.ConfigurationUpdate",
			NStr("en='Database configuration does not match stored configuration.';ru='Конфигурация отличается от основной конфигурации информационной базы.'"), 
			PictureLib.Information32);
		Return;
	EndIf;	
	
	If IsAffordableInternetEnabledRefresh AND UpdateSettings.HasAccessForChecksUpdate Then
		Settings = ConfigurationUpdateClientServer.GetUpdatedConfigurationUpdateSettings(
			ApplicationParameters["StandardSubsystems.ConfigurationUpdateOptions"]);
		Settings.UpdateSource	= 0;  // Internet
		ConfigurationUpdateServerCall.WriteStructureOfAssistantSettings(ConfigurationUpdateOptions);
		
		Parameters = GetAvailableConfigurationUpdate();
		Parameters.UpdateSource = ConfigurationUpdateOptions.UpdateSource;
		Parameters.NeedUpdateFile = ConfigurationUpdateOptions.NeedUpdateFile;
		Parameters.FlagOfAutoTransitionToPageWithUpdate = True;
		ShowUserNotification(NStr("en='The configuration update is available';ru='Доступно обновление конфигурации'"),
			"e1cib/app/DataProcessor.ConfigurationUpdate",
			NStr("en='Version:';ru='Версия:'") + " " + Parameters.FileParametersUpdateChecks.Version, 
			PictureLib.Information32);
		Return;	
	EndIf;
	
#EndIf

EndProcedure

// Exports check for updates file from the Internet.
//
// Parameters:
// OutputMessages - Boolean - Shows that it is necessary to output errors messages to user.
// CheckUpdateToNewEdition - Boolean - shows that it is necessary to
//                                                check updates for platform new edition.
//
Function GetFileOfUpdateAvailabilityCheck(Val OutputMessages = True, CheckUpdateToNewEdition = False) Export
	
	UpdateParameters = GetUpdateParameters(CheckUpdateToNewEdition);
	UpdateSettings = StandardSubsystemsClientReUse.ClientWorkParameters().UpdateSettings;
	
	TempFile = UpdateParameters.UpdateFilesDir + UpdateParameters.FileNameOfUpdateAvailabilityCheck;
	
	// Create directory for the temporary file if needed.
	DirectoryTemporaryFile = CommonUseClientServer.SplitFullFileName(TempFile).Path;
	TemporaryFileDirectoryObject = New File(DirectoryTemporaryFile);
	If Not TemporaryFileDirectoryObject.Exist() Then
		Try 
			CreateDirectory(DirectoryTemporaryFile);
		Except
			ErrorInfo = ErrorInfo();
			
			ErrorInfo = NStr("en='Unable to create the temporary directory to check for updates.
		|%1';ru='Не удалось создать временный каталог для проверки наличия обновлений.
		|%1'");
			EventLogMonitorClient.AddMessageForEventLogMonitor(EventLogMonitorEvent(), "Error",
				StringFunctionsClientServer.SubstituteParametersInString(ErrorInfo, DetailErrorDescription(ErrorInfo)),, 
				True);
				
			ErrorInfo = StringFunctionsClientServer.SubstituteParametersInString(ErrorInfo, 
				BriefErrorDescription(ErrorInfo));
			If OutputMessages Then
				ShowMessageBox(, ErrorInfo);
			EndIf;
			Return ErrorInfo;
		EndTry;
	EndIf;
	
	// Receive the file from the Internet.
	Result = GetFilesFromInternetClient.ExportFileAtClient(UpdateSettings.ServerAddressForVerificationOfUpdateAvailability +
		UpdateParameters.AddressOfResourcesForVerificationOfUpdateAvailability + UpdateParameters.FileNameOfUpdateAvailabilityCheck,
		New Structure("PathForSave", ? (IsBlankString(TempFile), Undefined, TempFile)));
		
	If Result.Status <> True Then
		ErrorInfo = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Unable to check for updates.
		|%1';ru='Не удалось проверить наличие обновлений.
		|%1'"), Result.ErrorInfo);
		If OutputMessages Then
			ShowMessageBox(, ErrorInfo);
		EndIf;
		Return ErrorInfo;
	EndIf;																
	
	Return InstallationPackageParameters(TempFile);
	
EndFunction

// Read data by update from the UpdatePresenceCheckFileName file (UpdInfo.txt).
// Calculated: 
// 	update version number on
// 	server, versions numbers from which update is executed
// 	(separated by the ";" character) update publication date.
// 
// Parameters:
//  FileName - UpdInfo file full name.txt.
// 
// Returns:
//  Structure: 
// 	Version - update version.
// 	FromVersions - from which versions updates.
// 	UpdateDate - publishing date.
//  String - error description if file is not found or does not contain required values.
//
Function InstallationPackageParameters(Val FileName) Export
	File = New File(FileName);
	If Not File.Exist() Then
		Return NStr("en='Updates description file is not received';ru='Файл описания обновлений не получен'");
	EndIf;	
	TextDocument = New TextDocument(); 
	TextDocument.Read(File.DescriptionFull);
	SetParameters = New Structure();
	For LineNumber = 1 To TextDocument.LineCount() Do
		TemporaryString = Lower(TrimAll(TextDocument.GetLine(LineNumber)));
		If IsBlankString(TemporaryString) Then
			Continue;
		EndIf; 
		If Find(TemporaryString,"fromversions=")>0 Then
			TemporaryString = TrimAll(Mid(TemporaryString,Find(TemporaryString,"fromversions=")+StrLen("fromversions=")));
			TemporaryString = ?(Left(TemporaryString,1)=";","",";") + TemporaryString + ?(Right(TemporaryString,1)=";","",";");
			SetParameters.Insert("FromVersions",TemporaryString);
		ElsIf Find(TemporaryString,"version=")>0 Then
			SetParameters.Insert("Version",Mid(TemporaryString,Find(TemporaryString,"version=")+StrLen("version=")));
		ElsIf Find(TemporaryString,"updatedate=")>0 Then
			// date format = Date, 
			TemporaryString = Mid(TemporaryString,Find(TemporaryString,"updatedate=")+StrLen("updatedate="));
			If StrLen(TemporaryString)>8 Then
				If Find(TemporaryString,".")=5 Then
					// date format YYYY.MM.DD
					TemporaryString = StrReplace(TemporaryString,".","");
				ElsIf Find(TemporaryString,".")=3 Then
					// date format DD.MM.YYYY
					TemporaryString = Right(TemporaryString,4)+Mid(TemporaryString,4,2)+Left(TemporaryString,2);
				Else 
					// date format YYYYMMDD
				EndIf;
			EndIf;
			SetParameters.Insert("UpdateDate",Date(TemporaryString));
		Else
			Return NStr("en='Invalid information format about updates';ru='Неверный формат сведений о наличии обновлений'");
		EndIf;
	EndDo;
	If SetParameters.Count() <> 3 Then 
		Return NStr("en='Invalid information format about updates';ru='Неверный формат сведений о наличии обновлений'");
	EndIf;
	Return SetParameters;
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Updates the data base configuration.
//
// Parameters:
//  StandardProcessing - Boolean - if you set False value to this parameter in
//                                  the procedure, then help on "manual" update will not be shown.
Procedure SetConfigurationUpdate(CompletingOfWorkSystem = False) Export
	
	FormParameters = New Structure("SystemWorkEnd, ConfigurationUpdateReceived",
		CompletingOfWorkSystem, CompletingOfWorkSystem);
	OpenForm("DataProcessor.ConfigurationUpdate.Form.Form", FormParameters);
	
EndProcedure

// Return update general parameters.
//
Function GetUpdateParameters(CheckUpdateToNewEdition = False) Export
	#If Not WebClient Then
		
	ParametersStructure = New Structure();
	ParametersStructure.Insert("UpdateDateTimeIsSet"	, False);
	
	// Internet
	ParametersStructure.Insert("ZIPFileNameOfListOfTemplates" , "v8upd11.zip");
	ParametersStructure.Insert("ListTemplatesFileName"    , "v8cscdsc.xml");
	ParametersStructure.Insert("UpdateDescriptionFileName", "news.htm");
	ParametersStructure.Insert("UpdateOrderFileName" , "update.htm");

	// Service files names
	ParametersStructure.Insert("NameOfExecutableDesignerFile", StandardSubsystemsClient.ApplicationExecutedFileName(True));
	ParametersStructure.Insert("NameOfExecutableFileOfClient"      , StandardSubsystemsClient.ApplicationExecutedFileName());
	ParametersStructure.Insert("EventLogMonitorEvent"        , EventLogMonitorEvent());
	
	// Determine temporary files directory.
	ParametersStructure.Insert("UpdateFilesDir"			, DirectoryLocalAppData() + "1C\1Cv8Update\"); 
	UpdateTempFilesDir = TempFilesDir() + "1Cv8Update." + Format(CommonUseClient.SessionDate(), "DF=yyMMddHHmmss") + "\";
	ParametersStructure.Insert("UpdateTempFilesDir"	, UpdateTempFilesDir);
	
	ParametersStructure.Insert("AddressOfResourcesForVerificationOfUpdateAvailability"						, AddressOfResourcesForVerificationOfUpdateAvailability(CheckUpdateToNewEdition));
	ParametersStructure.Insert("InfoAboutObtainingAccessToUserSitePageAddress"	, InfoAboutObtainingAccessToUserSitePageAddress());
	ParametersStructure.Insert("TemplatesDirectoryAddressAtUpdatesServer"							, TemplatesDirectoryAddressAtUpdatesServer());
	ParametersStructure.Insert("AddressOfUpdatesServer"											, AddressOfUpdatesServer());
	ParametersStructure.Insert("LegalityCheckServiceAddress"									, LegalityCheckServiceAddress());
	ParametersStructure.Insert("FileNameOfUpdateAvailabilityCheck"								, FileNameOfUpdateAvailabilityCheck());
	
	Return ParametersStructure;
	#EndIf
EndFunction

// Returns parameters of the found (available) configuration update.
Function GetAvailableConfigurationUpdate() Export
	ParameterName = "StandardSubsystems.AvailableConfigurationUpdate";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, New Structure);
		ApplicationParameters[ParameterName].Insert("UpdateSource", -1);
		ApplicationParameters[ParameterName].Insert("NeedUpdateFile", False);
		ApplicationParameters[ParameterName].Insert("FlagOfAutoTransitionToPageWithUpdate", False);
		ApplicationParameters[ParameterName].Insert("FileParametersUpdateChecks", Undefined);
		ApplicationParameters[ParameterName].Insert("PageName", "");
		ApplicationParameters[ParameterName].Insert("TimeOfObtainingUpdate", CommonUseClient.SessionDate());
		ApplicationParameters[ParameterName].Insert("LastConfigurationVersion", "");
	EndIf;
	
	Return ApplicationParameters[ParameterName];
EndFunction

// Receive page address on the configuration vendor web
// server where information about available updates is located.
//
// Returns:
//   String   - web page address.
//
Function AddressOfResourcesForVerificationOfUpdateAvailability(CheckUpdateToNewEdition = False) Export
	
	UpdateSettings = StandardSubsystemsClientReUse.ClientWorkParameters().UpdateSettings;
	ConfigurationShortName = UpdateSettings.ConfigurationShortName;
	ConfigurationShortName = StrReplace(ConfigurationShortName, "\", "/");
	If CheckUpdateToNewEdition Then
		ConfigurationShortName = StrReplace(ConfigurationShortName, PlatformCurrentEdition(), PlatformNextEdition());
	EndIf;
	Result = ConfigurationUpdateClientServer.AddFinalPathSeparator(UpdateSettings.AddressOfResourceForVerificationOfUpdateAvailability) +
		ConfigurationShortName + "/";
	Return Result;
	
EndFunction

Function PlatformCurrentEdition()
	
	SystemInfo = New SystemInfo;
	CurrentVersionArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(SystemInfo.AppVersion, ".");
	CurrentEdition = CurrentVersionArray[0] + CurrentVersionArray[1];
	
	Return CurrentEdition;
	
EndFunction

Function PlatformNextEdition() Export
	
	SystemInfo = New SystemInfo;
	CurrentVersionArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(SystemInfo.AppVersion, ".");
	NextEdition = CurrentVersionArray[0] + String(Number(CurrentVersionArray[1]) +1);
	
	Return NextEdition;
	
EndFunction

// Get web page address with information on how to get the access to custom section on the website of configuration vendor.
//
// Returns:
//   String   - web page address.
Function InfoAboutObtainingAccessToUserSitePageAddress() Export
	
	PageAddress = ConfigurationUpdateClientOverridable.InfoAboutObtainingAccessToUserSitePageAddress();
	If Not ValueIsFilled(PageAddress) Then
		PageAddress = "http://v8.1c.ru/"; // Value by default
	EndIf;
	
	ConfigurationUpdateClientOverridable.WhenDeterminingPageAddressForAccessToUpdateWebsite(PageAddress);
	
	Return PageAddress;
	
EndFunction

// Receive update files directory address on the updates service.
//
// Returns:
//   String   - catalog address on web server.
//
Function TemplatesDirectoryAddressAtUpdatesServer() Export
	
	UpdateServer = StandardSubsystemsClientReUse.ClientWorkParameters().UpdateSettings.UpdatesDirectory;
	
	If Find(UpdateServer, "ftp://") <> 0 Then
		Protocol = "ftp://";
	Else
		Protocol = "http://";
	EndIf;
	
	UpdateServer = StrReplace(UpdateServer, Protocol, "");
	TemplatesDirectoryAtServer = "";
	Position = Find(UpdateServer, "/");
	If Position > 0 Then
		TemplatesDirectoryAtServer = Mid(UpdateServer, Position, StrLen(UpdateServer));
	EndIf;
	Return TemplatesDirectoryAtServer;
	
EndFunction

// Receive service address of update receipt legality check.
//
// Returns:
//   String   - service address.
//
Function LegalityCheckServiceAddress() Export
	
	Return StandardSubsystemsClientReUse.ClientWorkParameters().UpdateSettings.LegalityCheckServiceAddress;
	
EndFunction

// Receive updates server address.
//
// Returns:
//   String   - web server address.
//
Function AddressOfUpdatesServer() Export
	
	UpdateServer = StandardSubsystemsClientReUse.ClientWorkParameters().UpdateSettings.UpdatesDirectory;
	
	If Find(UpdateServer, "ftp://") <> 0 Then
		Protocol = "ftp://";
	Else
		Protocol = "http://";
	EndIf;
	
	UpdateServer = StrReplace(UpdateServer, Protocol, "");
	Position = Find(UpdateServer, "/");
	If Position > 0 Then
		UpdateServer = Mid(UpdateServer, 1, Position - 1);
	EndIf;
	
	Return Protocol + UpdateServer;
	
EndFunction

// Receive attachment file name with information about available update on
// configuration vendor website.
//
// Returns:
//   String   - attachment file name.
//
Function FileNameOfUpdateAvailabilityCheck() Export
	
	Return "UpdInfo.txt";
	
EndFunction

// Function enables and disables check for update by the schedule.
// 
// Parameters:
// CheckBoxEnableOrDisable: Boolean if TRUE - check is enabled, otherwise, disabled.
Function EnableDisableCheckOnSchedule(EnableDisableFlag = True) Export
	If EnableDisableFlag Then
		AttachIdleHandler("ProcessUpdateCheckOnSchedule", 60 * 5); // every 5 minutes
	Else
		DetachIdleHandler("ProcessUpdateCheckOnSchedule");
	EndIf;
EndFunction

// Procedure that checks whether there is an update for configuration via the Internet.
//
// Parameters: 
//	OutputMessages: Boolean, shows that errors messages are output to a user.
Procedure CheckUpdateExistsViaInternet(OutputMessages = False, UpdateAvailableForNewEdition = False) Export
	
	Status(NStr("en='Check for update on the Internet';ru='Проверка наличия обновления в Интернете'"));
	Parameters = GetAvailableConfigurationUpdate(); 
	If Parameters.UpdateSource <> -1 Then
		TimeOfObtainingUpdate = Parameters.TimeOfObtainingUpdate;
		If TimeOfObtainingUpdate <> Undefined AND CommonUseClient.SessionDate() - TimeOfObtainingUpdate < 30 Then
			Return;
		EndIf;
	EndIf;
	
	Parameters.FileParametersUpdateChecks = GetFileOfUpdateAvailabilityCheck(OutputMessages);
	If TypeOf(Parameters.FileParametersUpdateChecks) = Type("String") Then
		EventLogMonitorClient.AddMessageForEventLogMonitor(EventLogMonitorEvent(), "Warning",
			NStr("en='It is impossible to connect to the Internet to check for updates';ru='Невозможно подключиться к сети Интернет для проверки обновлений.'"));
		Parameters.PageName = "InternetConnection";
		Return;
	EndIf;
	
	Parameters.LastConfigurationVersion = Parameters.FileParametersUpdateChecks.Version;
	ConfigurationVersion = StandardSubsystemsClientReUse.ClientWorkParameters().ConfigurationVersion;
	If CommonUseClientServer.CompareVersions(ConfigurationVersion, Parameters.LastConfigurationVersion) >= 0 Then
		
		UpdatesNotDetected = True;
		
		If CheckUpdateForNextPlatformVersion() Then
			
			Parameters.FileParametersUpdateChecks = GetFileOfUpdateAvailabilityCheck(False, True);
			
			If TypeOf(Parameters.FileParametersUpdateChecks) <> Type("String") Then
				
				Parameters.LastConfigurationVersion = Parameters.FileParametersUpdateChecks.Version;
				ConfigurationVersion = StandardSubsystemsClientReUse.ClientWorkParameters().ConfigurationVersion;
				
				If CommonUseClientServer.CompareVersions(ConfigurationVersion, Parameters.LastConfigurationVersion) < 0 Then
					UpdatesNotDetected = False;
					UpdateAvailableForNewEdition = True;
				EndIf;
				
			EndIf;
			
		EndIf;
		
		If UpdatesNotDetected Then
			
			EventLogMonitorClient.AddMessageForEventLogMonitor(EventLogMonitorEvent(), "Information",
				NStr("en='No update required: the latest version of configuration is already installed on computer.';ru='Обновление не требуется: последняя версия конфигурации уже установлена.'"));
			
			Parameters.PageName = "UpdatesNotDetected";
			Return;
			
		EndIf;
	EndIf;
	
	MessageText = NStr("en='New version of configuration is now available on the Internet:% 1.';ru='Обнаружена более новая версия конфигурации в Интернете: %1.'");
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, Parameters.LastConfigurationVersion);
	EventLogMonitorClient.AddMessageForEventLogMonitor(EventLogMonitorEvent(), "Information", MessageText);
	
	Parameters.UpdateSource = 0;
	Parameters.PageName = "AvailableUpdate";
	Parameters.TimeOfObtainingUpdate = CommonUseClient.SessionDate();
	
EndProcedure

// Procedure checks whether it is possible and checks whether there is
// configuration update via the Internet if needed.
Procedure CheckUpdateOnSchedule() Export
	
	ParameterName = "StandardSubsystems.ConfigurationUpdateOptions";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	ApplicationParameters[ParameterName] = StandardSubsystemsClientReUse.ClientWorkParameters().UpdateSettings.ConfigurationUpdateOptions;
	ConfigurationUpdateOptions = ApplicationParameters[ParameterName];
	
	ConfigurationUpdateClientServer.GetUpdatedConfigurationUpdateSettings(ApplicationParameters[ParameterName]);
	ScheduleOfUpdateExistsCheck = ConfigurationUpdateOptions.ScheduleOfUpdateExistsCheck;
	If ConfigurationUpdateOptions.CheckUpdateExistsOnStart <> 1 
		OR ScheduleOfUpdateExistsCheck = Undefined Then
		Return;	
	EndIf;	
			
	Schedule = CommonUseClientServer.StructureIntoSchedule(ScheduleOfUpdateExistsCheck);
	CheckDate = CommonUseClient.SessionDate();
	If Not Schedule.ExecutionRequired(CheckDate, ConfigurationUpdateOptions.TimeOfLastUpdateCheck) Then
		Return;	
	EndIf;	
		
	ConfigurationUpdateOptions.TimeOfLastUpdateCheck = CheckDate;
	EventLogMonitorClient.AddMessageForEventLogMonitor(EventLogMonitorEvent(),, 
		NStr("en='Verification for the updates availability in the Internet by schedule.';ru='Проверка наличия обновления в сети Интернет по расписанию.'"));
		
	AvailableUpdatePageDescription = "AvailableUpdate";
	CheckUpdateExistsViaInternet();
	Parameters = GetAvailableConfigurationUpdate();
	If Parameters.UpdateSource <> -1 AND Parameters.PageName = AvailableUpdatePageDescription Then
			
		EventLogMonitorClient.AddMessageForEventLogMonitor(EventLogMonitorEvent(),,
			NStr("en='New version of the configuration has been detected:';ru='Обнаружена новая версия конфигурации:'") + " " +
				Parameters.FileParametersUpdateChecks.Version);
				
		ConfigurationUpdateOptions.UpdateSource = 0;
		ConfigurationUpdateOptions.ScheduleOfUpdateExistsCheck = ScheduleOfUpdateExistsCheck;
		ConfigurationUpdateServerCall.WriteStructureOfAssistantSettings(ConfigurationUpdateOptions, ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);
		
		Parameters.UpdateSource = ConfigurationUpdateOptions.UpdateSource;
		Parameters.NeedUpdateFile = ConfigurationUpdateOptions.NeedUpdateFile;
		Parameters.FlagOfAutoTransitionToPageWithUpdate = True;
		ShowUserNotification(NStr("en='The configuration update is available';ru='Доступно обновление конфигурации'"),
			"e1cib/app/DataProcessor.ConfigurationUpdate",
			NStr("en='Version:';ru='Версия:'") + " " + Parameters.FileParametersUpdateChecks.Version, 
			PictureLib.Information32);
	Else
		EventLogMonitorClient.AddMessageForEventLogMonitor(EventLogMonitorEvent(),, 
			NStr("en='No updates available';ru='Доступных обновлений не обнаружено.'"));
	EndIf;
	ConfigurationUpdateServerCall.WriteStructureOfAssistantSettings(ConfigurationUpdateOptions, ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);
	
EndProcedure

// Return file directory - part of the path without the attachment file name.
//
// Parameters:
//  PathToFile  - String - file path.
//
// Returns:
//   String   - file directory
Function GetFileDir(Val PathToFile) Export

	CharPosition = GetNumberOfLastChar(PathToFile, "\");
	If CharPosition > 1 Then
		Return Mid(PathToFile, 1, CharPosition - 1); 
	Else
		Return "";
	EndIf;

EndFunction

Function GetNumberOfLastChar(Val SourceLine, Val SearchChar)
	
	CharPosition = StrLen(SourceLine);
	While CharPosition >= 1 Do
		
		If Mid(SourceLine, CharPosition, 1) = SearchChar Then
			Return CharPosition; 
		EndIf;
		
		CharPosition = CharPosition - 1;	
	EndDo;

	Return 0;
  	
EndFunction

Function CheckUpdateForNextPlatformVersion()
	
	CheckUpdate = ConfigurationUpdateClientOverridable.CheckUpdateForNextPlatformVersion();
	If CheckUpdate = Undefined Then
		CheckUpdate = False;
	EndIf;
	
	ConfigurationUpdateClientOverridable.WhenCheckingUpdatesForNextPlatformVersion(CheckUpdate);
	
	Return CheckUpdate;
	
EndFunction

// Function returns path to the temporary files directory to execute an update.
Function DirectoryLocalAppData()
	App			= New COMObject("Shell.Application");
	Folder		= App.Namespace(28);
	Result	= Folder.Self.Path;
	Return ConfigurationUpdateClientServer.AddFinalPathSeparator(Result);
EndFunction

// Function, opens online address on the Internet.
//
// Parameters:
// PageAddress - String, path to a page in the Internet that should be opened.
// Title - String, the title of "browser" window.
//
Procedure OpenWebPage(Val PageAddress, Val Title = "") Export
	
	OpenForm("DataProcessor.ConfigurationUpdate.Form.Browser", 
		New Structure("PageAddress,Title", PageAddress, Title));

EndProcedure

// Returns event name for events log monitor record.
Function EventLogMonitorEvent() Export
	Return NStr("en='Configuration update';ru='Обновление конфигурации'", CommonUseClientServer.MainLanguageCode());
EndFunction

// It is called on system shutdown to request
// a list of warnings displayed to a user.
//
// Parameters:
// see OnReceiveListOfEndWorkWarning.
//
Procedure OnExit(Warnings) Export
	
	If ApplicationParameters["StandardSubsystems.OfferInfobaseUpdateOnSessionExit"] = True Then
		WarningParameters = StandardSubsystemsClient.AlertOnEndWork();
		WarningParameters.FlagText  = NStr("en='Install configuration update';ru='Установить обновление конфигурации'");
		WarningParameters.Priority = 50;
		WarningParameters.OutputOneMessageBox = True;
		
		ActionIfMarked = WarningParameters.ActionIfMarked;
		ActionIfMarked.Form = "DataProcessor.ConfigurationUpdate.Form.Form";
		ActionIfMarked.FormParameters = New Structure("SystemWorkEnd, ExecuteUpdate", True, True);
		
		Warnings.Add(WarningParameters);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into other subsystems.

// Checks if update receipt is legal. If there
// is no legality check subsystem, returns True.
//
// Parameters:
//  Notification - NotifyDescription - contains
//               handler called after update receipt legality confirmation.
//
Function CheckSoftwareUpdateLegality(Notification) Export
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.CheckUpdateReceiveLegality") Then
		ModuleUpdateObtainingLegalityCheckClient = CommonUseClient.CommonModule("CheckUpdateReceiveLegalityClient");
		ModuleUpdateObtainingLegalityCheckClient.ShowUpdateReceiptLealityCheck(Notification);
	Else
		ExecuteNotifyProcessing(Notification, True);
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

// Defines the list of warnings to the user before the completion of the system work.
//
// Parameters:
//  Warnings - Array - you can add items of the
//                            Structure type to the array, for its properties, see  StandardSubsystemsClient.WarningOnWorkEnd.
//
Procedure OnGetListOfWarningsToCompleteJobs(Warnings) Export
	
	// Warning: the "Configuration update" subsystem clears the
	// list of all added warnings if it selects its check box.
	OnExit(Warnings);
	
EndProcedure

// Called when starting interactive operation of user with data area.
// Corresponds to the OnStart event of application modules.
//
Procedure OnStart(Parameters) Export
	
	CheckConfigurationUpdate();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures for update receipt legality check.

#If Not WebClient Then

// Returns web server response structure.
//
Function CheckUpdateImportLegality(QueryParameters) Export
	
	CheckLegality = ConfigurationUpdateClientOverridable.UseUpdateExportLegalityCheck();
	If CheckLegality = Undefined Then
		CheckLegality = True;
	EndIf;
	
	ConfigurationUpdateClientOverridable.WhenCheckingUpdatesExportLegality(CheckLegality);
	
	If Not CheckLegality Then
		
		Return New Structure("ResultValue, ErrorText", True, "");
		
	EndIf;
	
	Try
	// Create service description
		ServiceDescription = LegalityCheckServiceDescription();
	Except
		ErrorText = NStr("en='An error occurred while describing web service of update receipt legality check.';ru='Ошибка создания описания веб-сервиса проверки легальности получения обновления.'");
		Return WebServerResponceStructure(ErrorText, True,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	// Determine whether web service is available.
	Try
		
		ServerResponse = ServiceAvailable(ServiceDescription);
		
		If Lower(TrimAll(ServerResponse)) <> "ready" Then
			
			ErrorText = NStr("en='Service of updates receipt legality check is temporarily unavailable.
		|Try again later';ru='Сервис проверки легальности получения обновлений временно недоступен.
		|Повторите попытку позднее'");
			Return WebServerResponceStructure(ErrorText, True, ServerResponse);
			
		EndIf;
		
	Except
		
		ErrorText = NStr("en='Unable to connect to the service of updates receipt legality check.
		|Check your Internet connection settings';ru='Не удалось подключиться к сервису проверки легальности получения обновлений.
		|Проверьте параметры подключения к Интернету'");
		Return WebServerResponceStructure(ErrorText, True,,, DetailErrorDescription(ErrorInfo()));
		
	EndTry;
	
	// Receive response from the web service.
	Return CheckUpdateReceiptLegality(QueryParameters, ServiceDescription);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for work with legality check web service at a "high level".

// Adds parameters from structure to query.
//
// Parameters:
// LegalityCheckServiceDescription (Structure) - description of connection to the legality check web sevice.
// QueryParameters - String -  already generated parameters.
// ListOfParameters - XDTODataObject - parameters values list.
//
Procedure AddParametersToResponce(LegalityCheckServiceDescription, QueryParameters, ListOfParameters)
	
	TypeParameter = LegalityCheckServiceDescription.XDTOFactory.Type(LegalityCheckServiceDescription.OfURIService, "Parameter");
	CountParameters = 0;
	
	For Each PassingParameter IN ListOfParameters Do 
		
		// Define object of the parameter (XDTO Object).
		Parameter = LegalityCheckServiceDescription.XDTOFactory.Create(TypeParameter);
		
		Parameter.name  = TrimAll(PassingParameter.Key);
		Parameter.value = TrimAll(PassingParameter.Value);
		Parameter.index = CountParameters;
		
		QueryParameters.parameter.Add(Parameter);
		
		CountParameters = CountParameters + 1;
		
	EndDo;
	
EndProcedure

// Checks if update export is legal.
//
// Parameters:
// AdditionalParameters - Structure - additional parameters for passing to the web service;
// LegalityCheckServiceDescription (Structure) - description of connection to the legality check web sevice.
//
// Returns:
// Structure - structured web server response.
//
Function CheckUpdateReceiptLegality(AdditionalParameters, LegalityCheckServiceDescription)
	
	Try
		
		AnswerType  = LegalityCheckServiceDescription.XDTOFactory.Type(LegalityCheckServiceDescription.OfURIService, "ProcessResponseType");
		TypeQuery = LegalityCheckServiceDescription.XDTOFactory.Type(LegalityCheckServiceDescription.OfURIService, "Parameters");
		
		QueryParameters = LegalityCheckServiceDescription.XDTOFactory.Create(TypeQuery);
		
		// If there are passed parameters, then add them.
		If AdditionalParameters <> Undefined Then
			AddParametersToResponce(LegalityCheckServiceDescription, QueryParameters, AdditionalParameters);
		EndIf;
		
		// Execution of the process method of the WEB-Service.
		ServerResponse = RefreshReceivedLegally(QueryParameters, LegalityCheckServiceDescription);
		
	Except
		
		ErrorText = NStr("en='An error occurred while checking update receipt legality.
		|Contact the administrator';ru='Ошибка выполнения проверки легальности получения обновления.
		|Обратитесь к администратору'");
		Return WebServerResponceStructure(ErrorText, True,,,DetailErrorDescription(ErrorInfo()));
		
	EndTry;
	
	CommandStructure = ServerResponse.command[0];
	
	If CommandStructure.name = "store.put" Then
		
		ResponseParameters = CommandStructure.parameters.parameter;
		
		Result = New Structure;
		For Each Parameter IN ResponseParameters Do
			
			Result.Insert(Parameter.name, Parameter.value);
			
		EndDo;
		
		Result = WebServerResponceStructure(Result.resultTextError, False,
			Result.resultCodeError, Result.resultAvtorisation);
		
	Else
		
		Result = WebServerResponceStructure(NStr("en='Unexpected service response of updates receipt legality check';ru='Неожиданный ответ сервиса проверки легальности получения обновлений'"), True);
		
	EndIf;
	
	Return Result;
	
EndFunction

// Returns server response as a structure.
//
Function WebServerResponceStructure(ErrorText, RecordToEventLogMonitor,
	ErrorCode = 0, ResultValue = False, MessageText = "")
	
	AnswerStructure = New Structure;
	
	AnswerStructure.Insert("ResultValue", Boolean(ResultValue));
	AnswerStructure.Insert("ErrorText", String(ErrorText));
	
	If RecordToEventLogMonitor Then
		
		If IsBlankString(MessageText) Then
			MessageText = NStr("en='%ErrorText. Error code: %ErrorCode';ru='%ТекстОшибки. Код ошибки: %КодОшибки.'");
			MessageText = StrReplace(MessageText, "%ErrorText", ErrorText);
			MessageText = StrReplace(MessageText, "%ErrorCode", ErrorCode);
		EndIf;
		
		EventLogMonitorClient.AddMessageForEventLogMonitor(EventLogMonitorEvent(), "Error", MessageText);
		
	EndIf;
	
	Return AnswerStructure;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for work with legality check web service at a "low level".

// Generates web service description from WSDL-document
// for further work with legality check web service.
//
// Returns:
// Structure with properties:
// 	WSDLAddress (String) - WSDL-document URL;
// 		executed using temporary files;
// 	XDTOFactory (XDTOFactory) - Web-service XDTO factory;
// 	ServiceURI (String) - web service URI of legality check;
// 	PortConnection (HTTPConnection) - connection
// 		with the service port to execute web service method calls;
// 	PortPath (String) - port path on server;
//	
Function LegalityCheckServiceDescription()
	
	WSDLAddress = LegalityCheckServiceAddress();
	ConnectionParameters = CommonUseClientServer.URLStructure(WSDLAddress);
	
	Result = New Structure("WSDLAddress", WSDLAddress);
	
	InternetProxy = GetFilesFromInternetClientServer.GetProxy(ConnectionParameters.Schema);
	
	NetworkTimeout = 10;
	
	HTTP = New HTTPConnection(ConnectionParameters.Host,
		ConnectionParameters.Port,
		ConnectionParameters.Login,
		ConnectionParameters.Password,
		InternetProxy,
		NetworkTimeout,
		?(ConnectionParameters.Schema = "https",
			New OpenSSLSecureConnection(),
			Undefined));
	
	Try
		
		HTTPRequest = New HTTPRequest(ConnectionParameters.PathAtServer);
		Response = HTTP.Get(HTTPRequest);
		WSDLText = Response.GetBodyAsString();
		
	Except
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='An error occurred while creating the description of the web service.
		|Unable to receive WSDL-description from server of update import legality check (%1): %2.';ru='Ошибка при создании описания веб-сервиса.
		|Не удалось получить WSDL-описание с сервера проверки легальности скачивания обновления (%1): %2.'"),
			WSDLAddress, DetailErrorDescription(ErrorInfo()));
		Raise ErrorMessage;
	EndTry;
	
	XMLReader = New XMLReader;
	XMLReader.SetString(WSDLText);
	
	DOMBuilder = New DOMBuilder;
	Try
		DOMDocument = DOMBuilder.Read(XMLReader);
	Except
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='An error occurred while describing web service (%1).
		|An error occurred while reading web service WSDL-description of update import legality check: %2.';ru='Ошибка при создании описания веб-сервиса (%1).
		|Ошибка чтения WSDL-описания веб-сервиса проверки легальности скачивания обновления: %2.'"),
			WSDLAddress, DetailErrorDescription(ErrorInfo()));
		Raise ErrorMessage;
	EndTry;
	
	// Create XDTO factory of legality check web service.
	
	SchemeNodes = DOMDocument.GetElementByTagName("wsdl:types");
	If SchemeNodes.Count() = 0 Then
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='An error occurred while describing web service (%1).
		|An error occurred while reading web service
		|WSDL-description of update import legality check: There is no data types description item (<wsdl:types ...>).';ru='Ошибка при создании описания веб-сервиса (%1).
		|Ошибка чтения WSDL-описания веб-сервиса проверки легальности скачивания обновления:
		|Отсутствует элемент описания типов данных (<wsdl:types ...>).'"), WSDLAddress);
		Raise ErrorMessage;
		
	EndIf;
	
	SchemeDescriptionNode = SchemeNodes[0].FirstSubsidiary;
	If SchemeDescriptionNode = Undefined Then
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='An error occurred while describing web service (%1).
		|An error occurred while reading web service
		|WSDL-description of update import legality check: There is no data types description item (<xs:schema ...>)';ru='Ошибка при создании описания веб-сервиса (%1).
		|Ошибка чтения WSDL-описания веб-сервиса
		|проверки легальности скачивания обновления: Отсутствует элемент описания типов данных (<xs:schema ...>)'"), WSDLAddress);
		Raise ErrorMessage;
		
	EndIf;
	
	SchemeBuilder = New XMLSchemaBuilder;
	
	Try
		ServiceDataScheme = SchemeBuilder.CreateXMLSchema(SchemeDescriptionNode);
	Except
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='An error occurred while describing web service (%1).
		|An error occurred while creating data schema from web service
		|WSDL-description of update import legality check: %2';ru='Ошибка при создании описания веб-сервиса (%1).
		|Ошибка при создании схемы данных из WSDL-описания
		|веб-сервиса проверки легальности скачивания обновления: %2'"), WSDLAddress, DetailErrorDescription(ErrorInfo()));
		Raise ErrorMessage;
		
	EndTry;
	
	SchemaSet = New XMLSchemaSet;
	SchemaSet.Add(ServiceDataScheme);
	
	Try
		ServiceFactory = New XDTOFactory(SchemaSet);
	Except
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='An error occurred while describing web service (%1).
		|An error occurred while creating XDTO factory from web service WSDL-description of update import legality check: %2';ru='Ошибка при создании описания веб-сервиса (%1).
		|Ошибка при создании фабрики XDTO из WSDL-описания веб-сервиса проверки легальности скачивания обновления: %2'"),
			WSDLAddress, DetailErrorDescription(ErrorInfo()));
		Raise ErrorMessage;
		
	EndTry;
	
	// Determine service port connection parameters.
	
	RootElement = DOMDocument.FirstSubsidiary;
	
	Result.Insert("XDTOFactory", ServiceFactory);
	
	OfURIService = DOMNodeAttributeValue(RootElement, "targetNamespace");
	If Not ValueIsFilled(OfURIService) Then
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='An error occurred while describing web service (%1).
		|An error occurred while reading web service
		|WSDL-description of update import legality check: There is no names space URI in WSDL-description.';ru='Ошибка при создании описания веб-сервиса (%1).
		|Ошибка чтения WSDL-описания веб-сервиса
		|проверки легальности скачивания обновления: Отсутствует URI пространства имен в WSDL-описании.'"), WSDLAddress);
		Raise ErrorMessage;
		
	EndIf;
	
	Result.Insert("OfURIService" , OfURIService);
	
	// Determine address of web service port.
	ServicesNodes = RootElement.GetElementByTagName("wsdl:service");
	If ServicesNodes.Count() = 0 Then
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='An error occurred while describing web service (%1).
		|An error occurred while reading web service
		|WSDL-description of update import legality check: There is no web services description in WSDL-description (<wsdl:service ...>).';ru='Ошибка при создании описания веб-сервиса (%1).
		|Ошибка чтения WSDL-описания веб-сервиса проверки легальности скачивания обновления:
		|Отсутствует описание веб-сервисов в WSDL-описании (<wsdl:service ...>).'"), WSDLAddress);
		Raise ErrorMessage;
		
	EndIf;
	
	ServiceNode = ServicesNodes[0];
	
	ServiceName = DOMNodeAttributeValue(ServiceNode, "name");
	
	PortsNodes = ServiceNode.GetElementByTagName("wsdl:port");
	
	If PortsNodes.Count() = 0 Then
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='An error occurred while describing web service (%1).
		|An error occurred while reading web service
		|WSDL-description of update import legality check: There is no ports description in WSDL-description (<wsdl:port ...>).';ru='Ошибка при создании описания веб-сервиса (%1).
		|Ошибка чтения WSDL-описания веб-сервиса проверки легальности скачивания обновления:
		|Отсутствует описание портов в WSDL-описании (<wsdl:port ...>).'"), WSDLAddress);
		Raise ErrorMessage;
		
	EndIf;
	
	PortNode = PortsNodes[0];
	PortName  = DOMNodeAttributeValue(PortNode, "name");
	
	If Not ValueIsFilled(PortName) Then
		
		ErrorMessage = StrReplace(NStr("ru = ""An error occurred while creating web service description (%1).
			|An error occurred while reading
			|web service WSDL-description of online user support: Unable to determine service port name (%2)."), WSDLAddress, ServiceName);
		
		Raise ErrorMessage;
		
	EndIf;
	
	PortAddress = Undefined;
	AddressNodes = PortNode.GetElementByTagName("soap:address");
	If AddressNodes.Count() > 0 Then
		PortAddress = DOMNodeAttributeValue(AddressNodes[0], "location");
	EndIf;
	
	If Not ValueIsFilled(PortAddress) Then
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='An error occurred while describing web service (%1).
		|An error occurred while reading
		|web service WSDL-description of online user support: Unable to determine URL of the service specified port (%2).';ru='Ошибка при создании описания веб-сервиса (%1).
		|Ошибка чтения WSDL-описания
		|веб-сервиса интернет-поддержки пользователей: Не удалось определить URL заданного порта сервиса (%2).'"), WSDLAddress, PortName);
		
		Raise ErrorMessage;
		
	EndIf;
	
	PortConnection = New HTTPConnection(ConnectionParameters.Host,
		ConnectionParameters.Port,
		ConnectionParameters.Login,
		ConnectionParameters.Password,
		InternetProxy,
		NetworkTimeout,
		?(ConnectionParameters.Schema = "https",
			New OpenSSLSecureConnection(),
			Undefined));
	
	Result.Insert("PortConnection"       , PortConnection);
	Result.Insert("PortPath"             , ConnectionParameters.PathAtServer);
	
	Return Result;
	
EndFunction

// Proxy-function for calling the isReady() method of legality check web service
//
// Parameters:
// LegalityCheckServiceDescription (Structure) - for the check
// 	legality web service description, see LegalityCheckServiceDescription();
//
// Returns:
// String:
// 	value returned by the isReady() method of legality check web service;
//
Function ServiceAvailable(LegalityCheckServiceDescription)
	
	EnvelopeRecord = NewSOAPEnvelopeRecord();
	EnvelopeText  = TextInSOAPEnvelope(EnvelopeRecord);
	
	Try
		ResponseBody = SendSOAPQuery(EnvelopeText, LegalityCheckServiceDescription);
	Except
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='An error occurred while calling the isReady operation of service (%1): %2';ru='Ошибка при вызове операции isReady сервиса (%1): %2'"),
			LegalityCheckServiceDescription.WSDLAddress, DetailErrorDescription(ErrorInfo()));
		Raise ErrorMessage;
		
	EndTry;
	
	ObjectType = LegalitySeviceFactoryRootPropertyValueType("isReadyResponse", LegalityCheckServiceDescription);
	If ObjectType = Undefined Then
		ErrorMessage = StrReplace(NStr("en='An error occurred while calling the isReady operation of service (%1).
		|Unable to define the type of the isReadyResponse root property.';ru='Ошибка при вызове операции isReady сервиса (%1).
		|Не удалось определить тип корневого свойства isReadyResponse.'"),
			"%1",
			LegalityCheckServiceDescription.WSDLAddress);
		Raise ErrorMessage;
	EndIf;
	
	Try
		Value = ReadResponseInSOAPEnvelope(ResponseBody, LegalityCheckServiceDescription, ObjectType);
	Except
		ErrorMessage = StrReplace(NStr("en='An error occurred while calling the isReady operation of service (%1).';ru='Ошибка при вызове операции isReady сервиса (%1).'"),
			"%1",
			LegalityCheckServiceDescription.WSDLAddress)
			+ Chars.LF
			+ DetailErrorDescription(ErrorInfo())
			+ Chars.LF + Chars.LF
			+ NStr("en='Query body:';ru='Тело запроса:'")
			+ Chars.LF
			+ EnvelopeText;
		
		Raise ErrorMessage;
	EndTry;
	
	If TypeOf(Value) = Type("Structure") Then
		
		// Description of SOAP exception is returned.
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='An error occurred while calling the
		|isReady operation of service (%1) SOAP error: %2';ru='Ошибка при вызове операции
		|isReady сервиса (%1) Ошибка SOAP: %2'"), LegalityCheckServiceDescription.WSDLAddress, DescriptionSOAPExceptionToRow(Value));
		Raise ErrorMessage;
		
	ElsIf TypeOf(Value) = Type("XDTODataValue") Then
		Return Value.Value;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Web service method for update receipt legality check.
//
// Parameters:
// QueryParameters (ObjectXDTO) - parameters of the process() method query;
// LegalityCheckServiceDescription (Structure) - for the check
// 	legality web service description, see LegalityCheckServiceDescription();
//
// Returns:
// XDTODataObject:
// 	value returned by the process() method of legality check web service;
//
Function RefreshReceivedLegally(QueryParameters, LegalityCheckServiceDescription)
	
	EnvelopeRecord = NewSOAPEnvelopeRecord();
	
	EnvelopeRecord.WriteStartElement("m:processRequest");
	EnvelopeRecord.WriteAttribute("xmlns:m", LegalityCheckServiceDescription.OfURIService);
	
	LegalityCheckServiceDescription.XDTOFactory.WriteXML(EnvelopeRecord,
		QueryParameters,
		"parameters",
		,
		XMLForm.Element,
		XMLTypeAssignment.Explicit);
	
	EnvelopeRecord.WriteEndElement(); // </m:processRequest>
	
	EnvelopeText = TextInSOAPEnvelope(EnvelopeRecord);
	
	Try
		ResponseBody = SendSOAPQuery(EnvelopeText, LegalityCheckServiceDescription);
	Except
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='An error occurred while calling the process operation of service (%1): %2';ru='Ошибка при вызове операции process сервиса (%1): %2'"),
			LegalityCheckServiceDescription.WSDLAddress, DetailErrorDescription(ErrorInfo()));
		Raise ErrorMessage;
		
	EndTry;
	
	ObjectType = LegalitySeviceFactoryRootPropertyValueType("processResponse", LegalityCheckServiceDescription);
	If ObjectType = Undefined Then
		ErrorMessage = StrReplace(NStr("en='An error occurred while calling the process operation of service (%1).
		|Unable to define the type of the processResponse root property.';ru='Ошибка при вызове операции process сервиса (%1).
		|Не удалось определить тип корневого свойства processResponse.'"),
			"%1",
			LegalityCheckServiceDescription.WSDLAddress);
		Raise ErrorMessage;
	EndIf;
	
	Try
		Value = ReadResponseInSOAPEnvelope(ResponseBody, LegalityCheckServiceDescription, ObjectType);
	Except
		
		ErrorMessage = StrReplace(NStr("en='An error occurred while calling the process operation of service (%1).';ru='Ошибка при вызове операции process сервиса (%1).'"),
			"%1",
			LegalityCheckServiceDescription.WSDLAddress)
			+ Chars.LF
			+ DetailErrorDescription(ErrorInfo())
			+ Chars.LF + Chars.LF
			+ NStr("en='Query body:';ru='Тело запроса:'")
			+ Chars.LF
			+ EnvelopeText;
		
		Raise ErrorMessage;
		
	EndTry;
	
	If TypeOf(Value) = Type("XDTODataObject") Then
		Return Value.commands;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Returns a row value of the DOM-document node attribute.
//
// Parameters:
// DOMNode (DOMNode) - DOM-document node;
// AttributeName (String) - full name of the attribute;
// ValueIfNotFound (Custom) - value if the attribute is not found;
//
// Returns:
// String:
// 	Node attribute row presentation;
//
Function DOMNodeAttributeValue(DOMNode, AttributeName, ValueIfNotFound = Undefined)
	
	Attribute = DOMNode.Attributes.GetNamedItem(AttributeName);
	
	If Attribute = Undefined Then
		Return ValueIfNotFound;
	Else
		Return Attribute.Value;
	EndIf;
	
EndFunction

// Determines root property value type of
// XDTO factory pack of legality check web service.
//
// Parameters:
// PropertyName (String) - name of the root property;
// LegalityCheckServiceDescription (Structure) - for the check
// 	legality web service description, see LegalityCheckServiceDescription();
//
// Returns:
// XDTOValueType;
// XDTOObjectType;
// Undefined - if root property is not found;
//
Function LegalitySeviceFactoryRootPropertyValueType(PropertyName, LegalityCheckServiceDescription)
	
	Package            = LegalityCheckServiceDescription.XDTOFactory.packages.Get(LegalityCheckServiceDescription.OfURIService);
	RootProperty = Package.RootProperties.Get(PropertyName);
	If RootProperty = Undefined Then
		Return Undefined;
	Else
		Return RootProperty.Type;
	EndIf;
	
EndFunction

// Generates XMLWrite object type with the already written ones.
// SOAP-titles;
//
// Returns:
// XMLWriter:
// 	object of XML record with the written SOAP-titles;
//
Function NewSOAPEnvelopeRecord()
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	
	XMLWriter.WriteStartElement("soap:Envelope");
	XMLWriter.WriteAttribute("xmlns:soap", "http://schemas.xmlsoap.org/soap/envelope/");
	XMLWriter.WriteStartElement("soap:Header");
	XMLWriter.WriteEndElement(); // </soap:Header>
	XMLWriter.WriteStartElement("soap:Body");
	
	Return XMLWriter;
	
EndFunction

// Finalizes the record of SOAP-envelope and returns the envelope text.
//
// Parameters:
// EnvelopeRecord (XMLWriter) - object to which the envelope is written;
//
// Returns:
// String: SOAP envelope text;
//
Function TextInSOAPEnvelope(EnvelopeRecord)
	
	EnvelopeRecord.WriteEndElement(); // </soap:Body>
	EnvelopeRecord.WriteEndElement(); // </soap:Envelope>
	
	Return EnvelopeRecord.Close();
	
EndFunction

// Sends SOAP-envelope to the web service and receives a response one.
// SOAP-envelope.
//
// Parameters:
// EnvelopeText (String) - query-envelope text;
// LegalityCheckServiceDescription (Structure) - for the check
// 	legality web service description, see LegalityCheckServiceDescription();
//
// Returns:
// String: text of the SOAP envelope response;
//
Function SendSOAPQuery(EnvelopeText, LegalityCheckServiceDescription)
	
	HTTPRequest = New HTTPRequest(LegalityCheckServiceDescription.PortPath);
	HTTPRequest.Headers["Content-Type"] = "text/xml;charset=UTF-8";
	HTTPRequest.SetBodyFromString(EnvelopeText);
	
	Try
		HTTPResponse = LegalityCheckServiceDescription.PortConnection.Post(HTTPRequest);
	Except
		ErrorMessage = NStr("en='A network connection error occurred while sending SOAP-query.';ru='Ошибка сетевого соединения при отправке SOAP-запроса.'")
			+ Chars.LF
			+ DetailErrorDescription(ErrorInfo());
		Raise ErrorMessage;
	EndTry;
	
	ResponseBody = HTTPResponse.GetBodyAsString();
	
	Return ResponseBody;
	
EndFunction

// Reads object or value in the responce SOAP-envelope
// according to the factory of XDTO web service types.
//
// Parameters:
// ResponseBody (String) - body in the SOAP envelope response;
// LegalityCheckServiceDescription (Structure) - for the check
// 	legality web service description, see LegalityCheckServiceDescription();
// ValueType (XDTOValueType, XDTOObjectType) - read value type;
//
Function ReadResponseInSOAPEnvelope(ResponseBody, LegalityCheckServiceDescription, ValueType)
	
	ResponseReading = New XMLReader;
	ResponseReading.SetString(ResponseBody);
	
	Try
		
		// Transition to the response body
		While ResponseReading.Name <> "soap:Body" Do
			ResponseReading.Read();
		EndDo;
		
		// Transfer to the response object description.
		ResponseReading.Read();
		
	Except
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='An error occurred
		|while
		|reading SOAP:
		|%1 Response body: %2';ru='Ошибка
		|чтения
		|ответа SOAP:
		|%1 Тело ответа: %2'"), DetailErrorDescription(ErrorInfo()), ResponseBody);
		Raise ErrorMessage;
		
	EndTry;
	
	If ResponseReading.NodeType = XMLNodeType.StartElement
		AND Upper(ResponseReading.Name) = "SOAP:FAULT" Then
		// It is the exception of the web service
		Try
			ExceptionDetails = ReadServiceExceptionsDescription(ResponseReading);
		Except
			
			ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='An error occurred
		|while
		|reading SOAP:
		|%1 Response body: %2';ru='Ошибка
		|чтения
		|ответа SOAP:
		|%1 Тело ответа: %2'"), DetailErrorDescription(ErrorInfo()), ResponseBody);
			Raise ErrorMessage;
			
		EndTry;
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='SOAP-Server error occurred while processing query: %1';ru='Ошибка SOAP-Сервера при обработке запроса: %1'"), DescriptionSOAPExceptionToRow(ExceptionDetails));
		Raise ErrorMessage;
		
	EndIf;
	
	Try
		Value = LegalityCheckServiceDescription.XDTOFactory.ReadXML(ResponseReading, ValueType);
	Except
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='An error occurred while reading object
		|(%1)
		|in the
		|SOAP envelope: %2 Response body: %3';ru='Ошибка чтения объекта
		|(%1)
		|в конверте
		|SOAP: %2 Тело ответа: %3'"), String(ValueType), DetailErrorDescription(ErrorInfo()), ResponseBody);
		Raise ErrorMessage;
		
	EndTry;
	
	Return Value;
	
EndFunction

// If the response SOAP-envelope contains an
// error description, then the error description is read.
//
// Parameters:
// ResponseReading (XMLReading) - object used for
// 	reading the response SOAP-envelope. At the time of the call it is positioned at the description.
// 	exceptions SOAP;
//
// Returns:
// Structure with properties:
// 	FaultCode (String), FaultString (String), FaultActor (String);
//
Function ReadServiceExceptionsDescription(ResponseReading)
	
	DetailsExceptions = New Structure("FaultCode, FaultString, FaultActor", "", "", "");
	
	While Not (Upper(ResponseReading.Name) = "SOAP:BODY" AND ResponseReading.NodeType = XMLNodeType.EndElement) Do
		
		If ResponseReading.NodeType = XMLNodeType.StartElement Then
			NodeNameInReg = Upper(ResponseReading.Name);
			
			If NodeNameInReg = "FAULTCODE"
				OR NodeNameInReg = "FAULTSTRING"
				OR NodeNameInReg = "FAULTACTOR" Then
				
				ResponseReading.Read(); // Read the node text
				
				If ResponseReading.NodeType = XMLNodeType.Text Then
					DetailsExceptions[NodeNameInReg] = ResponseReading.Value;
				EndIf;
				
				ResponseReading.Read(); // Read the end of item
				
			EndIf;
			
		EndIf;
		
		If Not ResponseReading.Read() Then
			Break;
		EndIf;
		
	EndDo;
	
	Return DetailsExceptions;
	
EndFunction

// Converts structure-specifier of
// SOAP exception to string for a user presentation;
//
// Parameters:
// SOAPException (Structure) - see ReadServiceExceptionsDescription();
//
// Returns:
// String: user presentation of SOAP exception;
//
Function DescriptionSOAPExceptionToRow(ExceptionSOAP)
	
	Result = "";
	If Not IsBlankString(ExceptionSOAP.FaultCode) Then
		Result = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Error code: %1';ru='Код ошибки: %1'"), ExceptionSOAP.FaultCode);
	EndIf;
	
	If Not IsBlankString(ExceptionSOAP.FaultString) Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Error string: %1';ru='Строка ошибки: %1'"), ExceptionSOAP.FaultString);
		Result = Result + Chars.LF + ErrorText;
	EndIf;
	
	If Not IsBlankString(ExceptionSOAP.FaultActor) Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Error source: %1';ru='Источник ошибки: %1'"), ExceptionSOAP.FaultActor);
		Result = Result + Chars.LF + ErrorText;
	EndIf;
	
	Return Result;
	
EndFunction

#EndIf

#EndRegion