////////////////////////////////////////////////////////////////////////////////
// Subsystem "Information on start".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Add handlers of the service events (subsriptions).

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// CLIENT HANDLERS.
	
	ClientHandlers["StandardSubsystems.BasicFunctionality\AfterSystemOperationStart"].Add(
		"InformationOnStartClient");
	
	// SERVERSIDE HANDLERS.
	ServerModule = "InformationOnStart";
	
	Event = "StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers";
	ServerHandlers[Event].Add(ServerModule);
	
	Event = "StandardSubsystems.InfobaseVersionUpdate\AfterInformationBaseUpdate";
	ServerHandlers[Event].Add(ServerModule);
	
	Event = "StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystemsRunning";
	ServerHandlers[Event].Add(ServerModule);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of service events.

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//   Handlers - ValueTable - Update handlers.
//      See description of method InfobaseUpdate.UpdateHandlersNewTable().
//
Procedure OnAddUpdateHandlers(Handlers) Export
	Handler = Handlers.Add();
	Handler.ExecuteUnderMandatory = False;
	Handler.SharedData            = True;
	Handler.HandlersManagement    = False;
	Handler.PerformModes = "Promptly";
	Handler.Version      = "*";
	Handler.Procedure    = "InformationOnStart.UpdateFirstShowCache";
	Handler.Comment      = NStr("en = 'Updates the data first show.'");
	Handler.Priority     = 100;
EndProcedure

// Called after IB data exclusive update is complete.
//
// Parameters:
//   PreviousVersion       - String - subsystem version before update. 0.0.0.0 for an empty IB.
//   CurrentVersion        - String - subsystem version after update.
//   ExecutedHandlers      - ValueTree - list of the
//                                       executed procedures-processors of updating the subsystem grouped by the version number.
//                           Procedure of completed handlers bypass:
//
// For Each Version From ExecutedHandlers.Rows Cycle
//		
// 	If Version.Version = "*" Then 
// 		//Handler that can be run every time the version changes.
// 	Else
//    //Handler runs for a definite version.
// 	EndIf;
//		
// 	For Each Handler IN Version.String
// 		Do ...
// 	EndDo;
//		
// EndDo;
//
//   PutSystemChangesDescription - Boolean (return value)- if you set True, then display the form with updates description.
//   ExclusiveMode               - Boolean - shows that the update was executed in an exclusive mode.
//                                 True - update was executed in the exclusive mode.
//
Procedure AfterInformationBaseUpdate(Val PreviousVersion, Val CurrentVersion,
		Val ExecutedHandlers, PutSystemChangesDescription, ExclusiveMode) Export
	
	CommonUse.CommonSettingsStorageDelete("InformationOnStart", Undefined, Undefined);
	
EndProcedure

// Fills out parameters that are used by the client code when launching the configuration.
//
// Parameters:
//   Parameters - Structure - Launch parameters.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystemsRunning(Parameters) Export
	Parameters.Insert("InformationOnStart", New FixedStructure(GlobalSettings()));
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Info base update.

// [*] Updates data of the first show.
Procedure UpdateFirstShowCache() Export
	
	Cache = CacheForFirstShow();
	
	RecordSet = InformationRegisters.InformationPackagesOnLaunch.CreateRecordSet();
	
	PackageNumber = 0;
	For Each KeyAndValue IN Cache.PreparedPackages Do
		PackageNumber = PackageNumber + 1;
		PackageName = "PreparedPackage" + Format(PackageNumber, "NZ=; NG=");
		
		Record = RecordSet.Add();
		Record.Number  = PackageNumber;
		Record.Content = New ValueStorage(KeyAndValue.Value);
		Cache.PreparedPackages.Insert(KeyAndValue.Key, PackageNumber);
	EndDo;
	
	Record = RecordSet.Add();
	Record.Number  = 0;
	Record.Content = New ValueStorage(Cache);
	
	InfobaseUpdate.WriteData(RecordSet, False, False);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Service procedures and functions.

// Global subsystem settings.
Function GlobalSettings()
	Settings = New Structure;
	Settings.Insert("Show", True);
	
	If Metadata.DataProcessors.InformationOnStart.Templates.Count() = 0 Then
		Settings.Show = False;
	ElsIf Not StandardSubsystemsServer.ThisIsBasicConfigurationVersion() Then
		// Exit information into PROF version if the user has disabled flag.
		UserCheckBox = CommonUse.CommonSettingsStorageImport("InformationOnStart", "Show", True);
		If Not UserCheckBox Then
			DateOfNearestShow = CommonUse.CommonSettingsStorageImport("InformationOnStart", "DateOfNearestShow");
			If DateOfNearestShow <> Undefined
				AND DateOfNearestShow > CurrentSessionDate() Then
				Settings.Show = False;
			EndIf;
		EndIf;
	EndIf;
	
	If Settings.Show Then
		// Disable info if changes description is shown.
		If CommonUse.SubsystemExists("StandardSubsystems.InfobaseVersionUpdate") Then
			ModuleInfobaseUpdateService = CommonUse.CommonModule("InfobaseUpdateService");
			If ModuleInfobaseUpdateService.ShowSystemChangesDescription() Then
				Settings.Show = False;
			EndIf;
		EndIf;
	EndIf;
	
	If Settings.Show Then
		// Disable info if a assistant of DIB subordinate node customization completion is shown.
		If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
			ModuleDataExchangeServer = CommonUse.CommonModule("DataExchangeServer");
			If ModuleDataExchangeServer.OpenCommunicationAssistantToConfigureSlaveNode() Then
				Settings.Show = False;
			EndIf;
		EndIf;
	EndIf;
	
	// Override.
	InformationOnStartOverridable.DefineSettings(Settings);
	
	Return Settings;
EndFunction

// Global subsystem settings.
Function CacheForFirstShow() Export
	Cache = New Structure;
	
	// Reading template "Descriptor" (fill out table "PagePackages").
	SpreadsheetDocument = DataProcessors.InformationOnStart.GetTemplate("Descriptor");
	
	PagePackages = New ValueTable;
	PagePackages.Columns.Add("ID",                 New TypeDescription("String"));
	PagePackages.Columns.Add("TemplateName",                     New TypeDescription("String"));
	PagePackages.Columns.Add("Section",                        New TypeDescription("String"));
	PagePackages.Columns.Add("StartPageName", New TypeDescription("String"));
	PagePackages.Columns.Add("StartPageFileName",     New TypeDescription("String"));
	PagePackages.Columns.Add("ShowStartDate",              New TypeDescription("Date"));
	PagePackages.Columns.Add("ShowEndDate",           New TypeDescription("Date"));
	PagePackages.Columns.Add("Priority",                     New TypeDescription("Number"));
	
	MinimalPriority = 100;
	PageTemplateNamesWithLowestPriority = New Array;
	
	BaseConfiguration       = StandardSubsystemsServer.ThisIsBasicConfigurationVersion();
	ConfigurationSaaS = CommonUseReUse.DataSeparationEnabled();
	
	For LineNumber = 3 To SpreadsheetDocument.TableHeight Do
		StringPrefix = "R"+ LineNumber +"C";
		
		// Reading data of the first column.
		TemplateName = GivenCells(SpreadsheetDocument, StringPrefix, 1, , "EndTables");
		If Upper(TemplateName) = Upper("EndTables") Then
			Break;
		EndIf;
		
		// Skip if the data is not right for the configuration.
		If BaseConfiguration Then
			DisplayBase = GivenCells(SpreadsheetDocument, StringPrefix, 9, "Boolean", True);
			If Not DisplayBase Then
				Continue;
			EndIf;
		ElsIf ConfigurationSaaS Then
			ShowSaaS = GivenCells(SpreadsheetDocument, StringPrefix, 10, "Boolean", True);
			If Not ShowSaaS Then
				Continue;
			EndIf;
		Else
			ShowTrac = GivenCells(SpreadsheetDocument, StringPrefix, 8, "Boolean", True);
			If Not ShowTrac Then
				Continue;
			EndIf;
		EndIf;
		
		// Registering information about the command.
		PagesPackage = PagePackages.Add();
		PagesPackage.TemplateName                     = TemplateName;
		PagesPackage.ID                 = String(LineNumber - 2);
		PagesPackage.Section                        = GivenCells(SpreadsheetDocument, StringPrefix, 2);
		PagesPackage.StartPageName = GivenCells(SpreadsheetDocument, StringPrefix, 3);
		PagesPackage.StartPageFileName     = GivenCells(SpreadsheetDocument, StringPrefix, 4);
		PagesPackage.ShowStartDate              = GivenCells(SpreadsheetDocument, StringPrefix, 5, "Date", '00010101');
		PagesPackage.ShowEndDate           = GivenCells(SpreadsheetDocument, StringPrefix, 6, "Date", '29990101');
		
		If Lower(PagesPackage.Section) = Lower(NStr("en = 'Advertisement'")) Then
			PagesPackage.Priority = 0;
		Else
			PagesPackage.Priority = GivenCells(SpreadsheetDocument, StringPrefix, 7, "Number", 0);
			If PagesPackage.Priority = 0 Then
				PagesPackage.Priority = 99;
			EndIf;
		EndIf;
		
		If MinimalPriority > PagesPackage.Priority Then
			MinimalPriority = PagesPackage.Priority;
			PageTemplateNamesWithLowestPriority = New Array;
			PageTemplateNamesWithLowestPriority.Add(PagesPackage.TemplateName);
		ElsIf MinimalPriority = PagesPackage.Priority
			AND PageTemplateNamesWithLowestPriority.Find(PagesPackage.TemplateName) = Undefined Then
			PageTemplateNamesWithLowestPriority.Add(PagesPackage.TemplateName);
		EndIf;
	EndDo;
	
	PreparedPackages = New Map;
	For Each TemplateName IN PageTemplateNamesWithLowestPriority Do
		PreparedPackages.Insert(TemplateName, ExtractPackageFiles(TemplateName));
	EndDo;
	
	Cache.Insert("PagePackages", PagePackages);
	Cache.Insert("PreparedPackages", PreparedPackages);
	Return Cache;
EndFunction

// Reads the cell content from a spreadsheet and converts to the specified type.
Function GivenCells(SpreadsheetDocument, StringPrefix, ColumnNumber, Type = "String", DefaultValue = "")
	Result = TrimAll(SpreadsheetDocument.Area(StringPrefix + String(ColumnNumber)).Text);
	If IsBlankString(Result) Then
		Return DefaultValue;
	ElsIf Type = "Number" Then
		Return Number(Result);
	ElsIf Type = "Date" Then
		Return Date(Result);
	ElsIf Type = "Boolean" Then
		Return Result <> "0";
	Else
		Return Result;
	EndIf;
EndFunction

// Extracts a file package from template InformationOnLaunch.
Function ExtractPackageFiles(TemplateName) Export
	TempFilesDir = StandardSubsystemsServer.CreateTempFilesDirectory("extras");
	
	// Retrieving pages
	ArchiveFullName = TempFilesDir + "tmp.zip";
	Try
		BinaryData = DataProcessors.InformationOnStart.GetTemplate(TemplateName);
		BinaryData.Write(ArchiveFullName);
	Except
		WriteLogEvent(
			NStr("en = 'Information on start'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,
			,
			,
			DetailErrorDescription(ErrorInfo()));
		Return Undefined;
	EndTry;
	
	ZipFileReader = New ZipFileReader(ArchiveFullName);
	ZipFileReader.ExtractAll(TempFilesDir, ZIPRestoreFilePathsMode.Restore);
	
	DeleteFiles(ArchiveFullName);
	
	Images = New ValueTable;
	Images.Columns.Add("RelativeName",     New TypeDescription("String"));
	Images.Columns.Add("RelativeDirectory", New TypeDescription("String"));
	Images.Columns.Add("Data");
	
	WebPages = New ValueTable;
	WebPages.Columns.Add("RelativeName",     New TypeDescription("String"));
	WebPages.Columns.Add("RelativeDirectory", New TypeDescription("String"));
	WebPages.Columns.Add("Data");
	
	// Registering page hyperlinks and creating an image list.
	FileDirectories = New ValueList;
	FileDirectories.Add(TempFilesDir, "");
	Left = 1;
	While Left > 0 Do
		Left = Left - 1;
		Folder = FileDirectories[0];
		DirectoryFullPath        = Folder.Value; // Full path in the file system format.
		DirectoryRelativePath = Folder.Presentation; // Relative path in URL format.
		FileDirectories.Delete(0);
		
		Found = FindFiles(DirectoryFullPath, "*", False);
		For Each File IN Found Do
			RelativeFileName = DirectoryRelativePath + File.Name;
			
			If File.IsDirectory() Then
				Left = Left + 1;
				FileDirectories.Add(File.FullName, RelativeFileName + "/");
				Continue;
			EndIf;
			
			Extension = StrReplace(Lower(File.Extension), ".", "");
			
			If Extension = "htm" OR Extension = "html" Then
				FilePlacement = WebPages.Add();
				TextReader = New TextReader(File.FullName);
				Data = TextReader.Read();
				TextReader.Close();
				TextReader = Undefined;
			Else
				FilePlacement = Images.Add();
				Data = New Picture(New BinaryData(File.FullName));
			EndIf;
			FilePlacement.RelativeName     = RelativeFileName;
			FilePlacement.RelativeDirectory = DirectoryRelativePath;
			FilePlacement.Data               = Data;
		EndDo;
	EndDo;
	
	// Deleting temporary files (all files were placed in temporary storages).
	StandardSubsystemsServer.ClearTempFilesDirectory(TempFilesDir);
	
	Result = New Structure;
	Result.Insert("Images", Images);
	Result.Insert("WebPages", WebPages);
	
	Return Result;
EndFunction

#EndRegion