////////////////////////////////////////////////////////////////////////////////
// Subsystem "Banks".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Work with the RFBankClassifier catalog data.

// Receives data from the RFBanksClassifier catalog by BIC values and bank correspondent account.
// 
// Parameters:
//  BIN          - String - bank identification code.
//  CorrAccount     - String - bank correspondent account.
//  RecordAboutBank - CatalogRef, String - (return) found bank.
Procedure GetRFBankClassifierData(BIN = "", CorrAccount = "", RecordAboutBank = "") Export
	If Not IsBlankString(BIN) Then
		RecordAboutBank = Catalogs.RFBankClassifier.FindByCode(BIN);
	ElsIf Not IsBlankString(CorrAccount) Then
		RecordAboutBank = Catalogs.RFBankClassifier.FindByAttribute("CorrAccount", CorrAccount);
	Else
		RecordAboutBank = "";
	EndIf;
	If RecordAboutBank = Catalogs.RFBankClassifier.EmptyRef() Then
		RecordAboutBank = "";
	EndIf;
EndProcedure

#EndRegion

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// CLIENT HANDLERS.
	
	ClientHandlers["StandardSubsystems.BasicFunctionality\AfterSystemOperationStart"].Add(
		"WorkWithBanksClient");
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddWorkParametersClientOnStart"].Add(
		"WorkWithBanks");
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ServerHandlers["StandardSubsystems.SaaS.JobQueue\OnDefenitionOfUsageOfScheduledJobs"].Add(
			"WorkWithBanks");
	EndIf;
	
	If CommonUse.SubsystemExists("ServiceTechnology.DataExportImport") Then
		ServerHandlers["ServiceTechnology.DataExportImport\WhenFillingCommonDataTypesSupportingMatchingRefsOnImport"].Add(
			"WorkWithBanks");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.CurrentWorks") Then
		ServerHandlers["StandardSubsystems.CurrentWorks\AtFillingToDoList"].Add(
			"WorkWithBanks");
	EndIf;
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\WhenFillingOutPermitsForAccessToExternalResources"].Add(
		"WorkWithBanks");
	
EndProcedure

// Define the list of catalogs available for import using the Import data from file subsystem.
//
// Parameters:
//  ImportedCatalogs - ValueTable - list of catalogs, to which the data can be imported.
//      * FullName          - String - full name of the catalog (as in the metadata).
//      * Presentation      - String - presentation of the catalog in the selection list.
//      *AppliedImport - Boolean - if True, then the catalog uses its own
//                                      importing algorithm and the functions are defined in the catalog manager module.
//
Procedure OnDetermineCatalogsForDataImport(ImportedCatalogs) Export
	
	// Import to the RFBanksClassifier classifier is prohibited.
	TableRow = ImportedCatalogs.Find(Metadata.Catalogs.RFBankClassifier.FullName(), "FullName");
	If TableRow <> Undefined Then 
		ImportedCatalogs.Delete(TableRow);
	EndIf;
	
EndProcedure

// Define metadata objects in which modules managers it is restricted to edit attributes on bulk edit.
//
// Parameters:
//   Objects - Map - as a key specify the full name
//                            of the metadata object that is connected to the "Group object change" subsystem. 
//                            Additionally, names of export functions can be listed in the value:
//                            "UneditableAttributesInGroupProcessing",
//                            "EditableAttributesInGroupProcessing".
//                            Each name shall begin with a new row.
//                            If an empty row is specified, then both functions are defined in the manager module.
//
Procedure WhenDefiningObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.RFBankClassifier.FullName(), "NotEditableInGroupProcessingAttributes");
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Fills out parameters that are used by the client code when launching the configuration.
//
// Parameters:
//   Parameters (Structure) Start parameters.
//
Procedure OnAddWorkParametersClientOnStart(Parameters) Export
	
	StaleAlertOutput = (
		Not CommonUseReUse.DataSeparationEnabled() // Updated automatically in the service model.
		AND Not CommonUse.IsSubordinateDIBNode() // Updated automatically in DIB node.
		AND AccessRight("Update", Metadata.Catalogs.RFBankClassifier) // User with the required rights.
		AND Not ClassifierIsActual()); // Classifier is already updated.
	
	EnableAlert = Not CommonUse.SubsystemExists("StandardSubsystems.CurrentWorks");
	WorkWithBanksOverridable.OnDeterminingWhetherToShowWarningsAboutOutdatedClassifierBanks(EnableAlert);
	
	Parameters.Insert("Banks", New FixedStructure("StaleAlertOutput", (StaleAlertOutput AND EnableAlert)));
	
EndProcedure

// Fills the user current work list.
//
// Parameters:
//  CurrentWorks - ValueTable - a table of values with the following columns:
//    * Identifier - String - an internal work identifier used by the Current Work mechanism.
//    * ThereIsWork      - Boolean - if True, the work is displayed in the user current work list.
//    * Important        - Boolean - If True, the work is marked in red.
//    * Presentation - String - a work presentation displayed to the user.
//    * Count    - Number  - a quantitative indicator of work, it is displayed in the work header string.
//    * Form         - String - the complete path to the form which you need
//                               to open at clicking the work hyperlink on the Current Work bar.
//    * FormParameters- Structure - the parameters to be used to open the indicator form.
//    * Owner      - String, metadata object - a string identifier of the work, which
//                      will be the owner for the current work or a subsystem metadata object.
//    * ToolTip     - String - The tooltip wording.
//
Procedure AtFillingToDoList(CurrentWorks) Export
	
	ModuleCurrentWorksService = CommonUse.CommonModule("CurrentWorksService");
	If CommonUseReUse.DataSeparationEnabled() // Updated automatically in the service model.
		Or CommonUse.IsSubordinateDIBNode() // Updated automatically in DIB node.
		Or Not AccessRight("Update", Metadata.Catalogs.RFBankClassifier)
		Or ModuleCurrentWorksService.WorkDisabled("BanksClassifier") Then
		Return;
	EndIf;
	ModuleCurrentWorksServer = CommonUse.CommonModule("CurrentWorksServer");
	
	Result = BanksClassifierRelevancy();
	
	// The procedure is called only if there is the
	// To-do lists subsystem, that is why here is no checking of subsystem existence.
	Sections = ModuleCurrentWorksServer.SectionsForObject(Metadata.Catalogs.RFBankClassifier.FullName());
	
	If Sections = Undefined Then
		Return; // Interface of work with banks is not submitted to the user command interface.
	EndIf;
	
	For Each Section In Sections Do
		
		IdentifierBanks = "BanksClassifier" + StrReplace(Section.FullName(), ".", "");
		Work = CurrentWorks.Add();
		Work.ID  = IdentifierBanks;
		Work.ThereIsWork       = Result.ClassifierObsolete;
		Work.Important         = Result.ClassifierOverdue;
		Work.Presentation  = NStr("en='Banks classifier is outdated';ru='Классификатор банков устарел'");
		Work.ToolTip      = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Last update %1 ago';ru='Последнее обновление %1 назад'"), Result.OverdueAmountAsString);
		Work.Form          = "Catalog.RFBankClassifier.Form.ImportClassifier";
		Work.FormParameters = New Structure("OpenFromList", True);
		Work.Owner       = Section;
		
	EndDo;
	
EndProcedure

// Adds information about subsystem scheduled jobs for the service model to the table.
//
// Parameters:
//   UsageTable - ValueTable - Scheduled jobs table.
//      * ScheduledJob - String - Predefined scheduled job name.
//      * Use       - Boolean - True if scheduled job
//          should be executed in the service model.
//
Procedure OnDefenitionOfUsageOfScheduledJobs(UsageTable) Export
	
	NewRow = UsageTable.Add();
	NewRow.ScheduledJob = "ImportBanksClassifierFromRBCSite";
	NewRow.Use       = False;
	
EndProcedure

// Fills the array of types of undivided data for
// which the refs matching during data import to another infobase is supported.
//
// Parameters:
//  Types - Array(MetadataObject)
//
Procedure WhenFillingCommonDataTypesSupportingMatchingRefsOnImport(Types) Export
	
	Types.Add(Metadata.Catalogs.RFBankClassifier);
	
EndProcedure

// Fills out a list of queries for external permissions
// that must be provided when creating an infobase or updating a application.
//
// Parameters:
//  PermissionsQueries - Array - list of values returned by the function.
//                      WorkInSafeMode.QueryOnExternalResourcesUse().
//
Procedure WhenFillingOutPermitsForAccessToExternalResources(PermissionsQueries) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	PermissionsQueries.Add(
		WorkInSafeMode.QueryOnExternalResourcesUse(permissions()));
	
EndProcedure

// Returns permissions list to import banks classifier from RBC website.
//
// Returns:
//  Array.
//
Function permissions()
	
	Protocol = "HTTP";
	Address = "cbrates.rbc.ru";
	Port = Undefined;
	Definition = NStr("en='Import banks classifier from the Internet.';ru='Загрузка классификатора банков из интернета.'");
	
	permissions = New Array;
	permissions.Add( 
		WorkInSafeMode.PermissionForWebsiteUse(Protocol, Address, Port, Definition)
	);
	
	Return permissions;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Work with RBC website data

// Generates and expands text of message to user if classifier data is imported successfully.
// 
// Parameters:
// ClassifierImportParameters - Map:
// Exported						- Number  - Classifier new records quantity.
// Updated						- Number  - Quantity of updated classifier records.
// MessageText					- String - import results message text.
// ImportCompleted               - Boolean - check box of successful classifier data import end.
//
Procedure SupplementMessageText(ClassifierImportParameters) Export
	
	If IsBlankString(ClassifierImportParameters["MessageText"]) Then
		MessageText = NStr("en='Banks classifier is loaded successfully.';ru='Загрузка классификатора банков РФ выполнена успешно.'");
	Else
		MessageText = ClassifierImportParameters["MessageText"];
	EndIf;
	
	If ClassifierImportParameters["Exported"] > 0 Then
		
		MessageText = MessageText + StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='
		|New updated: %1.';ru='
		|Загружено новых: %1.'"), ClassifierImportParameters["Exported"]);
	
	EndIf;
	
	If ClassifierImportParameters["Updated"] > 0 Then
		
		MessageText = MessageText + StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='
		|Records updated: %1.';ru='
		|Обновлено записей: %1.'"), ClassifierImportParameters["Updated"]);

	EndIf;
	
	ClassifierImportParameters.Insert("MessageText", MessageText);
	
EndProcedure	

// Receives, sorts, writes RF BIC classifier data from RBC website.
// 
// Parameters:
// ClassifierImportParameters - Map:
// Exported						- Number	 - Classifier new records quantity.
// Updated						- Number	 - Quantity of updated classifier records.
// MessageText					- String - import results message text.
// ImportCompleted               - Boolean - check box of successful classifier data import end.
//	StorageAddress					- String - internal storage address.
Procedure GetRBCData(ClassifierImportParameters, StorageAddress = "") Export
	TemporaryDirectory = GetTempFileName();
	CreateDirectory(TemporaryDirectory);
	
	RBKFilesReceivingParameters = New Map;
	RBKFilesReceivingParameters.Insert("PathToRBCFile", "");
	RBKFilesReceivingParameters.Insert("MessageText", ClassifierImportParameters["MessageText"]);
	RBKFilesReceivingParameters.Insert("TemporaryDirectory", TemporaryDirectory);
	
	GetRBKDataFromInternet(RBKFilesReceivingParameters);
	
	If Not IsBlankString(RBKFilesReceivingParameters["MessageText"]) Then
		ClassifierImportParameters.Insert("MessageText", RBKFilesReceivingParameters["MessageText"]);
		If Not IsBlankString(StorageAddress) Then
			PutToTempStorage(ClassifierImportParameters, StorageAddress);
		EndIf;		
		Return;
	EndIf;
	
	Try
		RBCZIPFile = New ZipFileReader(RBKFilesReceivingParameters["PathToRBCFile"]);
	Except
		MessageText = NStr("en='The problems occurred with the banks classifier file obtained form the RBC website.';ru='Возникли проблемы с файлом классификатора банков, полученным с сайта РБК.'");
		MessageText = MessageText + DetailErrorDescription(ErrorInfo());
	EndTry;
	
	If Not IsBlankString(MessageText) Then
		ClassifierImportParameters.Insert("MessageText", MessageText);
		If Not IsBlankString(StorageAddress) Then
			PutToTempStorage(ClassifierImportParameters, StorageAddress);
		EndIf;		
		Return;
	EndIf;
	
	Try
		RBCZIPFile.ExtractAll(TemporaryDirectory);
	Except
		MessageText = NStr("en='The problems occurred with the banks classifier file obtained form the RBC website.';ru='Возникли проблемы с файлом классификатора банков, полученным с сайта РБК.'");
		MessageText = MessageText + DetailErrorDescription(ErrorInfo());
	EndTry;	
	
	If Not IsBlankString(MessageText) Then
		ClassifierImportParameters.Insert("MessageText", MessageText);
		If Not IsBlankString(StorageAddress) Then
			PutToTempStorage(ClassifierImportParameters, StorageAddress);
		EndIf;		
		Return;
	EndIf;
	
	PathToFileBIKRBK = CommonUseClientServer.AddFinalPathSeparator(TemporaryDirectory) + "bnkseek.txt";
	FileBIKRBK	   = New File(PathToFileBIKRBK);
	If Not FileBIKRBK.Exist() Then
		MessageText = NStr("en='The problems occurred with the banks classifier file obtained form the RBC website. 
		|Archive does not contain information - banks classifier.';ru='Возникли проблемы с файлом классификатора банков, полученным с сайта РБК. 
		|Архив не содержит информацию - классификатор банков.'");
		ClassifierImportParameters.Insert("MessageText", MessageText);
		If Not IsBlankString(StorageAddress) Then
			PutToTempStorage(ClassifierImportParameters, StorageAddress);
		EndIf;		
		Return;
	EndIf;
	
	PathToRBKStatesFile = CommonUseClientServer.AddFinalPathSeparator(TemporaryDirectory) + "reg.txt";
	RBCStatesFile		= New File(PathToRBKStatesFile);
	If Not RBCStatesFile.Exist() Then
		MessageText = NStr("en='The problems occurred with the banks classifier file obtained form the RBC website. 
		|Archive does not contain information about states.';ru='Возникли проблемы с файлом классификатора банков, полученным с сайта РБК. 
		|Архив не содержит информацию о регионах.'");
		ClassifierImportParameters.Insert("MessageText", MessageText);
		If Not IsBlankString(StorageAddress) Then
			PutToTempStorage(ClassifierImportParameters, StorageAddress);
		EndIf;
		Return;
	EndIf;
	
	PathToFileNonPerformingBanks = InativeBanksFileName(TemporaryDirectory);
	NonOperationalBanksFile = New File(PathToFileNonPerformingBanks);
	If Not NonOperationalBanksFile.Exist() Then
		MessageText = NStr("en='The problems occurred with the banks classifier file obtained form the RBC website. 
		|Archive does not contain information on the inactive banks.';ru='Возникли проблемы с файлом классификатора банков, полученным с сайта РБК. 
		|Архив не содержит информацию о недействующих банках.'");
		ClassifierImportParameters.Insert("MessageText", MessageText);
		If Not IsBlankString(StorageAddress) Then
			PutToTempStorage(ClassifierImportParameters, StorageAddress);
		EndIf;
		Return;
	EndIf;
	
	RBKFilesImportingParameters = New Map;
	RBKFilesImportingParameters.Insert("PathToFileBIKRBK", PathToFileBIKRBK);
	RBKFilesImportingParameters.Insert("PathToRBKStatesFile", PathToRBKStatesFile);
	RBKFilesImportingParameters.Insert("PathToFileNonPerformingBanks", PathToFileNonPerformingBanks);
	RBKFilesImportingParameters.Insert("TemporaryDirectory", TemporaryDirectory);
	RBKFilesImportingParameters.Insert("Exported", ClassifierImportParameters["Exported"]);
	RBKFilesImportingParameters.Insert("Updated", ClassifierImportParameters["Updated"]);
	RBKFilesImportingParameters.Insert("MessageText", ClassifierImportParameters["MessageText"]);
	
	ImportRBCData(RBKFilesImportingParameters);
	
	If Not IsBlankString(RBKFilesImportingParameters["MessageText"]) Then
		If Not IsBlankString(StorageAddress) Then
			PutToTempStorage(ClassifierImportParameters, StorageAddress);
		EndIf;		
		Return;
	EndIf;
	
	SetBanksClassifierVersion();
	DeleteFiles(TemporaryDirectory);
	
	ClassifierImportParameters.Insert("Exported", RBKFilesImportingParameters["Exported"]);
	ClassifierImportParameters.Insert("Updated", RBKFilesImportingParameters["Updated"]);
	ClassifierImportParameters.Insert("MessageText", RBKFilesImportingParameters["MessageText"]);
	ClassifierImportParameters.Insert("ImportCompleted", True);
	
	SupplementMessageText(ClassifierImportParameters);
	
	If Not IsBlankString(StorageAddress) Then
		PutToTempStorage(ClassifierImportParameters, StorageAddress);
	EndIf;
	
EndProcedure

// Receives, sorts, writes RF BIC classifier data from RBC website;
//
Procedure ImportBanksClassifier() Export
	
	CommonUse.OnStartExecutingScheduledJob();
	
	EventLevel = EventLogLevel.Information;
	
	If CommonUse.IsSubordinateDIBNode() Then
		WriteLogEvent(EventNameInEventLogMonitor(), EventLevel, , , NStr("en='Import in the subordinate RIB node is not provided';ru='Загрузка в подчиненном узле РИБ не предусмотрена'"));
		Return;
	EndIf;
	
	ClassifierImportParameters = New Map;
	ClassifierImportParameters.Insert("Exported", 0);
	ClassifierImportParameters.Insert("Updated", 0);
	ClassifierImportParameters.Insert("MessageText", "");
	ClassifierImportParameters.Insert("ImportCompleted", False);
	
	GetRBCData(ClassifierImportParameters);
	
	If ClassifierImportParameters["ImportCompleted"] Then
		If IsBlankString(ClassifierImportParameters["MessageText"]) Then
			SupplementMessageText(ClassifierImportParameters);
		EndIf;
	Else
		EventLevel = EventLogLevel.Error;
	EndIf;
	
	WriteLogEvent(EventNameInEventLogMonitor(), EventLevel, , , ClassifierImportParameters["MessageText"]);
	
EndProcedure
 
// Receives, writes RF BIC classifier data from RBC website.
// 
// Parameters:
// RBKFilesImportingParameters - Map:
//  PathToFileBIKRBK		   - String - path to the file with classifier data placed in the temporary directory.
//  PathToRBKStatesFile	   - String - path to file with information about regions located in the temporary directory.
// Exported				   - Number	- classifier new records quantity.
// Updated				   - Number	- quantity of updated classifier records.
// MessageText			   - String	- import results message text.
// ImportCompleted          - Boolean - check box of successful classifier data import end.
//
Procedure ImportRBCData(RBKFilesImportingParameters) Export
	
	StatesConformity = GetStatesCorrespondance(RBKFilesImportingParameters["PathToRBKStatesFile"]);
	
	TextBIKRBK		   = New TextReader(RBKFilesImportingParameters["PathToFileBIKRBK"], "windows-1251");
	TextStringBIKRBK = TextBIKRBK.ReadLine();
	
	ImportDate = CurrentUniversalDate();
	
	RBKDataImportingParameters = New Map;
	RBKDataImportingParameters.Insert("Exported", RBKFilesImportingParameters["Exported"]);
	RBKDataImportingParameters.Insert("Updated", RBKFilesImportingParameters["Updated"]);
	
	While TextStringBIKRBK <> Undefined Do
		
		String = TextStringBIKRBK;
	
		If IsBlankString(TrimAll(String)) Then
			Continue;
		EndIf;
		
		StructureBank  = GetBankFieldsStructure(String, StatesConformity);
		TextStringBIKRBK = TextBIKRBK.ReadLine();
		
		If IsBlankString(StructureBank) Then
			Continue;
		EndIf;
		
		RBKDataImportingParameters.Insert("StructureBank", StructureBank);
		WriteRFBanksClassifierItem(RBKDataImportingParameters);
		
	EndDo;
	
	// Inactive banks mark.
	EffcientBanks = ActualBanksFromFile(RBKFilesImportingParameters["PathToFileBIKRBK"]);
	InoperativeBanks = NonOperationalBanksFromFile(RBKFilesImportingParameters["PathToFileNonPerformingBanks"]);
	NumberOfMarked = MarkInactiveBanks(EffcientBanks, InoperativeBanks);
	RBKDataImportingParameters["Updated"] = RBKDataImportingParameters["Updated"] + NumberOfMarked;
	
	RBKFilesImportingParameters.Insert("Exported", RBKDataImportingParameters["Exported"]);
	RBKFilesImportingParameters.Insert("Updated", RBKDataImportingParameters["Updated"]);
EndProcedure 

// Get file http://cbrates.rbc.ru/bnk/bnk.zip.
// Parameters:
// RBKFilesReceivingParameters - Map:
// PathToRBCFile				- String - path to the received file located in the temporary directory.
// TemporaryDirectory			- String - path to the temporary directory.
//  MessageText				- String - error message text.
Procedure GetRBKDataFromInternet(RBKFilesReceivingParameters) Export

	MessageText = "";
	PathToRBCFile  = "";
	
	ServerSource = "cbrates.rbc.ru";
	Address          = "bnk";
	BINFile        = "bnk.zip";
		
	RBCFileOnWebServer  = "http://" + ServerSource + "/" + Address+ "/" + BINFile;
	TemporaryRBCFile	 = RBKFilesReceivingParameters["TemporaryDirectory"]+ "\" + BINFile;
	ReceivingParameters	 = New Structure("PathForSave");
	ReceivingParameters. Insert("PathForSave", TemporaryRBCFile);
	ResultFromInternet = GetFilesFromInternet.ExportFileAtServer(RBCFileOnWebServer, ReceivingParameters);
   		
	If ResultFromInternet.Status Then
		
		RBKFilesReceivingParameters.Insert("PathToRBCFile", ResultFromInternet.Path);
		
	Else
		If CommonUse.FileInfobase() Then
			AdditionalMessage = 
				NStr("en='
		|Perhaps, the settings of the Internet connection are inaccurate or incorrect';ru='
		|Возможно неточные или неправильные настройки подключения к Интернету.'");
		Else
			AdditionalMessage =
				NStr("en='
		|Perhaps, the Internet connection settings on the 1C:Enterprise server are inaccurate or incorrect.';ru='
		|Возможно неточные или неправильные настройки подключения к Интернету на сервере 1С:Предприятие.'");
		EndIf;	
		
		ErrorInfo = ResultFromInternet.ErrorInfo + AdditionalMessage; 
		
		RBKFilesReceivingParameters.Insert("MessageText", ErrorInfo);
	EndIf;
		  	
EndProcedure	

// Determines town type string by the town type code.
// Parameters:
//  TypeCode - String - settlement type code.
// Returns:
//  abbreviated string of the settlement type.
//
Function DetermineTownTypeByCode(TypeCode)
	
	If TypeCode = "1" Then
		Return "G.";       // CITY
	ElsIf TypeCode = "2" Then
		Return "P.";       // VILLAGE
	ElsIf TypeCode = "3" Then
		Return "From.";       // VILLAGE
	ElsIf TypeCode = "4" Then
		Return "UTS";     // URBAN-TYPE SETTLEMENT
	ElsIf TypeCode = "5" Then
		Return "ST-N";   // STANITSA
	ElsIf TypeCode = "6" Then
		Return "AUL";     // AUL
	ElsIf TypeCode = "7" Then
		Return "WS";      // WORK SETTLEMENT 
	Else
		Return "";
	EndIf;
	
EndFunction

// Generates states codes and states match.
// Parameters:
// PathToRBKStatesFile - String	   - path to file with information about regions located in the temporary directory.
// Returns:
// StatesConformity  - Map - State code and region.
//	
Function GetStatesCorrespondance(PathToRBKStatesFile)
	
	Delimiter					= Chars.Tab;
	StatesConformity		= New Map;
	RBKStatesTextDocument = New TextReader(PathToRBKStatesFile, "windows-1251");
	StatesRBCString			= RBKStatesTextDocument.ReadLine();
	
	While StatesRBCString <> Undefined Do

		String			  = StatesRBCString;
		StatesRBCString = RBKStatesTextDocument.ReadLine();

		If (Left(String,2) = "//") Or (IsBlankString(String)) Then
			Continue;
		EndIf;
		
		SubstringArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(String, Delimiter);
		
		If SubstringArray.Count() < 2 Then
			Continue;
		EndIf;	
		
		Char1 = TrimAll(SubstringArray[0]);
        Char2 = TrimAll(SubstringArray[1]);
        		 		
		// Expand state code up to two characters.
		If StrLen(Char1) = 1 Then
			Char1 = "0" + Char1;
		EndIf;
		
		StatesConformity.Insert(Char1, Char2);
 	EndDo;	
		
	Return StatesConformity;

EndFunction

// Generates fields structure for bank.
// Parameters:
// String  - String	   - String from the classifier text file.
// States - Map - State code and bank region.
// Returns:
// Bank - Structure - Bank details.
//
Function GetBankFieldsStructure(Val String, States)
	
	Bank		= New Structure;
	Delimiter = Chars.Tab;
			
	Item		 = "";
	PointType	 = "";
	Description = "";
	CodeSign	 = "";
	BIN			 = "";
	BalancedAccount		 = "";
	
	SubstringArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(String, Delimiter);
	
	If SubstringArray.Count() < 7 Then
		Return "";
	EndIf;	
	
	Item		 = TrimAll(SubstringArray[1]);
	PointType    = DetermineTownTypeByCode(TrimAll(SubstringArray[2]));
    Description = TrimAll(SubstringArray[3]);
	CodeSign  = TrimAll(SubstringArray[4]);
	BIN			 = TrimAll(SubstringArray[5]);
    CorrAccount	 = TrimAll(SubstringArray[6]);
 		
	If StrLen(BIN) <> 9 Then
		Return "";
	EndIf;		
		
	Bank.Insert("BIN",		  BIN);
	Bank.Insert("CorrAccount",	  CorrAccount);
	Bank.Insert("Description", Description);
	Bank.Insert("City",		  TrimAll(PointType + " " + Item));
	Bank.Insert("PhoneNumbers",     "");
	Bank.Insert("Address",        "");
	
	StateCode = Mid(Bank.BIN, 3, 2);
	Region = States[StateCode];
	If Region = Undefined Then
		Region = NStr("en='Other territories';ru='Другие территории'");
		StateCode = "";
	EndIf;
	
	Bank.Insert("StateCode", StateCode);
	Bank.Insert("Region", Region);
	
	Return Bank;
	
EndFunction

// Imports RF banks classifier from file received from RBC website.
Function ImportDataFromRBKFile(FileName) Export
	
	FolderWithExtractedFiles = ExtractFilesFromArchive(FileName);
	If ClassifierFilesReceived(FolderWithExtractedFiles) Then
		Parameters = New Map;
		Parameters.Insert("PathToFileBIKRBK", BIKRBKFileName(FolderWithExtractedFiles));
		Parameters.Insert("PathToRBKStatesFile", RBCStatesFileName(FolderWithExtractedFiles));
		Parameters.Insert("PathToFileNonPerformingBanks", InativeBanksFileName(FolderWithExtractedFiles));
		Parameters.Insert("Exported", 0);
		Parameters.Insert("Updated", 0);
		Parameters.Insert("MessageText", "");
		Parameters.Insert("ImportCompleted", Undefined);
		
		ImportRBCData(Parameters);
		SetBanksClassifierVersion();
	EndIf;
	
EndFunction

Function ClassifierFilesReceived(FolderWithFiles)
	
	Result = True;
	
	FileNamesToCheck = New Array;
	FileNamesToCheck.Add(BIKRBKFileName(FolderWithFiles));
	FileNamesToCheck.Add(RBCStatesFileName(FolderWithFiles));
	FileNamesToCheck.Add(InativeBanksFileName(FolderWithFiles));
	
	For Each FileName In FileNamesToCheck Do
		File = New File(FileName);
		If Not File.Exist() Then
			WriteErrorInEventLogMonitor(
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='File %1 has not been found';ru='Не найден файл %1'"),
					FileName));
			Result = False;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function ExtractFilesFromArchive(ZipFile)
	
	TemporaryFolder = GetTempFileName();
	CreateDirectory(TemporaryFolder);
	
	Try
		ZipFileReader = New ZipFileReader(ZipFile);
		ZipFileReader.ExtractAll(TemporaryFolder);
	Except
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()));
		DeleteFiles(TemporaryFolder);
	EndTry;
	
	Return TemporaryFolder;
	
EndFunction

Function RBCStatesFileName(FolderWithClassifierFiles)
	
	Return CommonUseClientServer.AddFinalPathSeparator(FolderWithClassifierFiles) + "reg.txt";
	
EndFunction

Function BIKRBKFileName(FolderWithClassifierFiles)
	
	Return CommonUseClientServer.AddFinalPathSeparator(FolderWithClassifierFiles) + "bnkseek.txt";
	
EndFunction

Function InativeBanksFileName(FolderWithClassifierFiles)
	
	Return CommonUseClientServer.AddFinalPathSeparator(FolderWithClassifierFiles) + "bnkdel.txt";
	
EndFunction

Procedure WriteErrorInEventLogMonitor(ErrorText)
	
	WriteLogEvent(EventNameInEventLogMonitor(), EventLogLevel.Error,,, ErrorText);
	
EndProcedure

Function EventNameInEventLogMonitor()
	
	Return NStr("en='Banks classifier import. RBK site';ru='Загрузка классификатора банков. Сайт РБК'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

Function NonOperationalBanksFromFile(PathToFile)
	
	Result = New ValueTable;
	Result.Columns.Add("BIN", New TypeDescription("String",,New StringQualifiers(9)));
	Result.Columns.Add("Description", New TypeDescription("String",,New StringQualifiers(100)));
	Result.Columns.Add("ClosingDate", New TypeDescription("Date",,,New DateQualifiers(DateFractions.Date)));
	
	TextReader = New TextReader(PathToFile, "windows-1251");
	
	String = TextReader.ReadLine();
	While String <> Undefined Do
		BankInformation = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(String, Chars.Tab);
		If BankInformation.Count() <> 8 Then
			Continue;
		EndIf;
		Bank = Result.Add();
		Bank.BIN = BankInformation[6];
		Bank.Description = BankInformation[4];
		Bank.ClosingDate = BankInformation[1];
		
		String = TextReader.ReadLine();
	EndDo;
	
	Return Result;
	
EndFunction

Function ActualBanksFromFile(PathToFile)
	
	Result = New ValueTable;
	Result.Columns.Add("BIN", New TypeDescription("String",,New StringQualifiers(9)));
	Result.Columns.Add("Description", New TypeDescription("String",,New StringQualifiers(100)));
	
	TextReader = New TextReader(PathToFile, "windows-1251");
	
	String = TextReader.ReadLine();
	While String <> Undefined Do
		BankInformation = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(String, Chars.Tab);
		If BankInformation.Count() <> 7 Then
			Continue;
		EndIf;
		Bank = Result.Add();
		Bank.BIN = BankInformation[5];
		Bank.Description = BankInformation[3];
		
		String = TextReader.ReadLine();
	EndDo;
	
	Return Result;
	
EndFunction

Function MarkInactiveBanks(EffcientBanks, InoperativeBanks)
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	Query.Text = 
	"SELECT
	|	InoperativeBanks.BIN AS BIN
	|INTO InoperativeBanks
	|FROM
	|	&InoperativeBanks AS InoperativeBanks
	|WHERE
	|	Not InoperativeBanks.BIN In (&BIN)
	|
	|INDEX BY
	|	BIN";
	Query.SetParameter("InoperativeBanks", InoperativeBanks);
	Query.SetParameter("BIN", EffcientBanks.UnloadColumn("BIN"));
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	RFBankClassifier.Ref
	|FROM
	|	InoperativeBanks AS InoperativeBanks
	|		INNER JOIN Catalog.RFBankClassifier AS RFBankClassifier
	|		ON InoperativeBanks.BIN = RFBankClassifier.Code
	|WHERE
	|	RFBankClassifier.ActivityDiscontinued = FALSE
	|
	|GROUP BY
	|	RFBankClassifier.Ref";
	
	BanksSelection = Query.Execute().Select();
	While BanksSelection.Next() Do
		BankObject = BanksSelection.Ref.GetObject();
		BankObject.ActivityDiscontinued = True;
		BankObject.Write();
	EndDo;
	
	Return BanksSelection.Count();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Work with ITS disc data

// Receives, writes RF BIC classifier data from ITS disc.
// 
// Parameters:
// ITSFilesImportingParameters		 - Map:
// ITSPreparingBinaryDataAddress - TempStorage - BIC ITS data preparation processor.
//  ITSDataBinaryDataAddress	 - TempStorage - BIC ITS data file.
// Exported						 - Number		      - Classifier new records quantity.
// Updated						 - Number			  - Quantity of updated classifier records.
// MessageText					 - String			  - import results message text.
// ImportCompleted                - Boolean             - check box of successful classifier data import end.
//
Procedure ImportDataITSdisc(ITSFilesImportingParameters) Export
	
	TemporaryDirectory = CommonUseClientServer.AddFinalPathSeparator(GetTempFileName());
	CreateDirectory(TemporaryDirectory);
	
	PreparingITSBinaryData = GetFromTempStorage(ITSFilesImportingParameters["ITSPreparingBinaryDataAddress"]);
	PreparingSupportDiscPath = TemporaryDirectory + "BIKr5v82_MA.epf";
	PreparingITSBinaryData.Write(PreparingSupportDiscPath);
	ProcessingITSDataPreparing = New File(PreparingSupportDiscPath);
	
	SupportDataBinaryData  = GetFromTempStorage(ITSFilesImportingParameters["ITSDataBinaryDataAddress"]);
	PathToSupportDiscData = TemporaryDirectory + "Morph.dlc";
	SupportDataBinaryData.Write(PathToSupportDiscData);
	SupportData = New TextDocument;
	SupportData.Read(PathToSupportDiscData);
	
	ClassifierTable = New ValueTable;
	ClassifierTable.Columns.Add("BIN");
	ClassifierTable.Columns.Add("Description");
	ClassifierTable.Columns.Add("CorrAccount");
	ClassifierTable.Columns.Add("City");
	ClassifierTable.Columns.Add("Address");
	ClassifierTable.Columns.Add("PhoneNumbers");
	ClassifierTable.Columns.Add("StateCode");
	ClassifierTable.Columns.Add("Region");
	
	ExternalProcessingITSDataPreparing = ExternalDataProcessors.Create(ProcessingITSDataPreparing.FullName);
	
	LineCount = SupportData.LineCount();
	
	VersionString   = SupportData.GetLine(1);
	
	PartCount = Round(LineCount/1000);
	StatesConformity = "";
	MessageText = "";
	VersionDate = "";
	
	For PartNumber = 1 To PartCount Do	
		ExternalProcessingITSDataPreparing.SortClassifierData(SupportData, ClassifierTable, 
																			StatesConformity, VersionDate, 
																			PartNumber, MessageText);
		If Not IsBlankString(MessageText) Then
			Return;
		EndIf;
		
		ITSDataImportingParameters = New Map;
		ITSDataImportingParameters.Insert("ClassifierTable", ClassifierTable);
		ITSDataImportingParameters.Insert("Exported", ITSFilesImportingParameters["Exported"]);
		ITSDataImportingParameters.Insert("Updated", ITSFilesImportingParameters["Updated"]);
		
		WriteClassifierData(ITSDataImportingParameters);
		
		ITSFilesImportingParameters.Insert("Exported", ITSDataImportingParameters["Exported"]);
		ITSFilesImportingParameters.Insert("Updated", ITSDataImportingParameters["Updated"]);
	
	EndDo;
			
	SetBanksClassifierVersion(VersionDate);
	DeleteFiles(TemporaryDirectory);
	
	If IsBlankString(ITSFilesImportingParameters["MessageText"]) Then
		ITSFilesImportingParameters.Insert("ImportCompleted", True);
		SupplementMessageText(ITSFilesImportingParameters);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Processed data writing

///  Writes/overwrites bank data to the RFBankClassifier catalog.
// Parameters:
// DataImportingParameters - Map:
// StructureBank			- Structure or ValueTableRow - Bank data.
// Exported				- Number								 - Classifier new records quantity.
// Updated				- Number								 - Quantity of updated classifier records.
//
Procedure WriteRFBanksClassifierItem(DataImportingParameters)
	
	FlagNew		= False;
	FlagUpdated = False;
	Region			= "";
	
	StructureBank = DataImportingParameters["StructureBank"];
	Exported	  = DataImportingParameters["Exported"];
	Updated	  = DataImportingParameters["Updated"];
	
	CurrentState = Catalogs.RFBankClassifier.FindByCode(StructureBank.StateCode);
	If CurrentState.IsEmpty() Then
		Region = Catalogs.RFBankClassifier.CreateFolder();
	Else
		If CurrentState.IsFolder Then 
			Region = CurrentState.GetObject();
		Else
			Region = Catalogs.RFBankClassifier.CreateFolder();
		EndIf;
	EndIf;
	
	If TrimAll(Region.Code) <> TrimAll(StructureBank.StateCode) Then
		Region.Code = TrimAll(StructureBank.StateCode);
	EndIf;
	
	If TrimAll(Region.Description) <> TrimAll(StructureBank.Region) Then
		Region.Description = TrimAll(StructureBank.Region);
	EndIf;
	
	If Region.Modified() Then
		Region.Write();
	EndIf;
	
	WrittenRFBanksClassifierCatalogItem = 
		Catalogs.RFBankClassifier.FindByCode(StructureBank.BIN);
	
	If WrittenRFBanksClassifierCatalogItem.IsEmpty() Then
		BanksClassifierObject = Catalogs.RFBankClassifier.CreateItem();
		FlagNew				  = True;
	Else	
		BanksClassifierObject = WrittenRFBanksClassifierCatalogItem.GetObject();
	EndIf;
	
	If BanksClassifierObject.ActivityDiscontinued Then
		BanksClassifierObject.ActivityDiscontinued = False;
	EndIf;
	
	If BanksClassifierObject.Code <> StructureBank.BIN Then
		BanksClassifierObject.Code = StructureBank.BIN;
	EndIf;
    	
	If BanksClassifierObject.Description <> StructureBank.Description Then
		If Not IsBlankString(StructureBank.Description) Then
        	BanksClassifierObject.Description = StructureBank.Description;
		EndIf;	
	EndIf;
	
	If BanksClassifierObject.CorrAccount <> StructureBank.CorrAccount Then
		If Not IsBlankString(StructureBank.CorrAccount) Then
			BanksClassifierObject.CorrAccount	= StructureBank.CorrAccount;
		EndIf;	
	EndIf;
	
	If BanksClassifierObject.City <> StructureBank.City Then
		If Not IsBlankString(StructureBank.City) Then
			BanksClassifierObject.City = StructureBank.City;
		EndIf;	
	EndIf;
			
	If BanksClassifierObject.Address <> StructureBank.Address Then
		If Not IsBlankString(StructureBank.Address) Then
			BanksClassifierObject.Address = StructureBank.Address;
		EndIf;	
	EndIf;
	
	If BanksClassifierObject.PhoneNumbers <> StructureBank.PhoneNumbers Then
		If Not IsBlankString(StructureBank.PhoneNumbers) Then
			BanksClassifierObject.PhoneNumbers = StructureBank.PhoneNumbers;
		EndIf;	
	EndIf;
	
	If Not IsBlankString(Region) Then
		If BanksClassifierObject.Parent <> Region.Ref Then
			BanksClassifierObject.Parent = Region.Ref;
		EndIf;	
	EndIf;	
    			
	If BanksClassifierObject.Modified() Then
		FlagUpdated		  = True;
		BanksClassifierObject.Write();
	EndIf;
	
	If FlagNew Then
		Exported = Exported + 1;
	ElsIf FlagUpdated Then
		Updated = Updated + 1;
	EndIf;
	
	DataImportingParameters.Insert("Exported", Exported);
	DataImportingParameters.Insert("Updated", Updated);
	
EndProcedure

// Writes/overwrites banks data to the RFBankClassifier catalog.
// Parameters:
// ITSDataImportingParameters - Map:
// ClassifierTable	   - ValueTable - Banks data.
// Exported				   - Number			 - Classifier new records quantity.
// Updated				   - Number			 - Quantity of updated classifier records.
//
Procedure WriteClassifierData(ITSDataImportingParameters)
	
	BanksTable = ITSDataImportingParameters["ClassifierTable"];
	
	DataImportingParameters = New Map;
	DataImportingParameters.Insert("Exported", ITSDataImportingParameters["Exported"]);
	DataImportingParameters.Insert("Updated", ITSDataImportingParameters["Updated"]);
    
	For BanksCounter = 1 To BanksTable.Count() Do
		
		BanksTableString = BanksTable.Get(BanksCounter - 1);
		
		DataImportingParameters.Insert("StructureBank", BanksTableString);
		WriteRFBanksClassifierItem(DataImportingParameters);
				        				
	EndDo;	
	
	ITSDataImportingParameters.Insert("Exported", DataImportingParameters["Exported"]);
	ITSDataImportingParameters.Insert("Updated", DataImportingParameters["Updated"]);
    				
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions.

// Sets import date value of the classifier data.
// 
// Parameters:
//  VersionDate - DateTime - To import classifier data.
Procedure SetBanksClassifierVersion(VersionDate = "") Export
	SetPrivilegedMode(True);
	If TypeOf(VersionDate) <> Type("Date") Then
		Constants.RFBanksClassifierVersion.Set(CurrentUniversalDate());
	Else
		Constants.RFBanksClassifierVersion.Set(VersionDate);
	EndIf;
EndProcedure

// Determines whether classifier data update is required.
//
Function ClassifierIsActual() Export
	SetPrivilegedMode(True);
	LastUpdate = Constants.RFBanksClassifierVersion.Get();
	PermissibleDelay = 30*60*60*24;
	
	If CurrentSessionDate() > LastUpdate + PermissibleDelay Then
		Return False; // There is an overdue.
	EndIf;
	
	Return True;
EndFunction

Function BanksClassifierRelevancy()
	
	SetPrivilegedMode(True);
	LastUpdate = Constants.RFBanksClassifierVersion.Get();
	PermissibleDelay = 60*60*24;
	
	Result = New Structure;
	Result.Insert("ClassifierObsolete", False);
	Result.Insert("ClassifierOverdue", False);
	Result.Insert("OverdueAmountAsString", "");
	
	If CurrentSessionDate() > LastUpdate + PermissibleDelay Then
		Result.OverdueAmountAsString = CommonUse.TimeIntervalAsString(LastUpdate, CurrentSessionDate());
		
		OverdueAmount = (CurrentSessionDate() - LastUpdate);
		DaysOverdue = Int(OverdueAmount/60/60/24);
		
		Result.ClassifierObsolete = DaysOverdue >= 1;
		Result.ClassifierOverdue = DaysOverdue >= 7;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion
