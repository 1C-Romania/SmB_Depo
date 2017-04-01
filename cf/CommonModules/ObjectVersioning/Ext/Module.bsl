////////////////////////////////////////////////////////////////////////////////
// Subsystem "Versioning of objects".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Running when you update the configuration.
// 1. Clears versioning settings by objects for which the versioning is not applied.
// 2. Sets default versioning settings.
//
Procedure UpdateObjectVersioningSettings() Export
	
	VersioningObjects = GetVersioningObjects();
	
	RecordsSelection = InformationRegisters.ObjectVersioningSettings.Select();
	While RecordsSelection.Next() Do
		If VersioningObjects.Find(RecordsSelection.ObjectType) = Undefined Then
			RecordManager = RecordsSelection.GetRecordManager();
			RecordManager.Delete();
		EndIf;
	EndDo;
	
	VersionedObjectsOfTS = New ValueTable;
	VersionedObjectsOfTS.Columns.Add("ObjectType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	For Each ObjectType IN VersioningObjects Do
		VersionedObjectsOfTS.Add();
	EndDo;
	VersionedObjectsOfTS.LoadColumn(VersioningObjects, "ObjectType");
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	VersioningObjects.ObjectType
	|INTO VersioningObjectsTable
	|FROM
	|	&VersioningObjects AS VersioningObjects
	|;
	|////////////////////////////////////////////////////////////
	|SELECT
	|	VersioningObjectsTable.ObjectType
	|FROM
	|	VersioningObjectsTable AS VersioningObjectsTable
	|		LEFT JOIN InformationRegister.ObjectVersioningSettings AS ObjectVersioningSettings
	|			BY ObjectVersioningSettings.ObjectType = VersioningObjectsTable.ObjectType
	|WHERE
	|	ObjectVersioningSettings.Variant IS NULL ";
			
	Query.Parameters.Insert("VersioningObjects", VersionedObjectsOfTS);
	VersionedObjectsWithoutSettings = Query.Execute().Unload().UnloadColumn("ObjectType");
	
	RecordSetSettings = InformationRegisters.ObjectVersioningSettings.CreateRecordSet();
	RecordSetSettings.Read();
	For Each VersionedObject IN VersionedObjectsWithoutSettings Do
		NewRecord = RecordSetSettings.Add();
		NewRecord.ObjectType = VersionedObject;
		NewRecord.Variant = Enums.ObjectVersioningOptions.DoNotVersion;
		NewRecord.Use = ? (NewRecord.Variant = Enums.ObjectVersioningOptions.DoNotVersion, False, True);
	EndDo;
	
	RecordSetSettings.Write(True);
	
EndProcedure

// Records the object versioning setup.
//
// Parameters:
//  ObjectType - String, Type, MetadataObject, CatalogRef.MetadataObjectIDs - metadata object;
//  VersioningVariant - EnumRef.ObjectVersioningOptions - condition of versions record;
//  VersionsStorageTerm - EnumRef.VersionStorageTerms - period for the versions to be cleared.
//
Procedure WriteVersioningSettingByObject(Val ObjectType, Val VersioningVariant, Val VersionsStorageTerm = Undefined) Export
	
	If TypeOf(ObjectType) <> Type("CatalogRef.MetadataObjectIDs") Then
		ObjectType = CommonUse.MetadataObjectID(ObjectType);
	EndIf;
	
	Setting = InformationRegisters.ObjectVersioningSettings.CreateRecordManager();
	Setting.ObjectType = ObjectType;
	
	If VersionsStorageTerm = Undefined Then
		Setting.Read();
		If Setting.Selected() Then
			VersionsStorageTerm = Setting.VersionsStorageTerm;
		Else
			VersionsStorageTerm = Enums.VersionStorageTerms.Indefinitely;
		EndIf;
	EndIf;
	
	Setting.VersionsStorageTerm = VersionsStorageTerm;
	Setting.Variant = VersioningVariant;
	Setting.Write();
	
EndProcedure

// Performs actions with the form that are necessary for versioning subsystems connection.
//
// Parameters:
//  Form - ManagedForm - form to enable versioning.
//
Procedure OnCreateAtServer(Form) Export
	
	FullMetadataName = Undefined;
	If Users.RolesAvailable("ReadObjectsVersions") AND GetFunctionalOption("UseObjectVersioning") Then
		FormNameArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Form.FormName, ".");
		FullMetadataName = FormNameArray[0] + "." + FormNameArray[1];
	EndIf;
	
	Object = Undefined;
	If FullMetadataName <> Undefined Then
		Object = CommonUse.MetadataObjectID(FullMetadataName);
	EndIf;
	
	Form.SetFormFunctionalOptionParameters(New Structure("VersionizedObjectType", Object));
	
EndProcedure

// Returns tabular document filled with object data.
// 
// Parameters:
//  ObjectReference - AnyRef.
//
// Returns:
//  SpreadsheetDocument - print form of an object.
//
Function ReportByObjectVersioning(ObjectReference, Val ObjectVersioning = Undefined) Export
	
	VersionNumber = Undefined;
	SerializedObject = Undefined;
	If TypeOf(ObjectVersioning) = Type("Number") Then
		VersionNumber = ObjectVersioning;
	ElsIf TypeOf(ObjectVersioning) = Type("String") Then
		SerializedObject = ObjectVersioning;
	EndIf;
	
	If VersionNumber = Undefined Then
		If SerializedObject = Undefined Then
			SerializedObject = SerializeObject(ObjectReference.GetObject());
		EndIf;
		ObjectDescription = ParsingObjectXMLPresentation(SerializedObject, ObjectReference);
		ObjectDescription.Insert("ObjectName",     String(ObjectReference));
		ObjectDescription.Insert("AuthorOfChange", "");
		ObjectDescription.Insert("ChangeDate",  CurrentSessionDate());
		ObjectDescription.Insert("Comment", "");
		VersionNumber = 0;
	Else
		ObjectDescription = VersionParsing(ObjectReference, VersionNumber);
	EndIf;
	Definition = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='No. %1 / (%2) / %3';ru='№ %1 / (%2) / %3'"), 
		VersionNumber, String(ObjectDescription.ChangeDate), TrimAll(String(ObjectDescription.AuthorOfChange)));
	ObjectDescription.Insert("Definition", Definition);
	ObjectDescription.Insert("VersionNumber", VersionNumber);
	
	SpreadsheetDocument = New SpreadsheetDocument;
	GenerateReportByObjectVersioning(SpreadsheetDocument, ObjectDescription, ObjectReference);
	
	Return SpreadsheetDocument;
	
EndFunction

// Outdated. ReportByObjectVersion shall be used.
//
Function GetObjectPrintForm(ObjectReference) Export
	
	Return ReportByObjectVersioning(ObjectReference);
	
EndFunction

#EndRegion

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddExceptionsSearchLinks"].Add(
		"ObjectVersioning");
		
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnReceiveDataFromSubordinate"].Add(
		"ObjectVersioning");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnReceiveDataFromMaster"].Add(
		"ObjectVersioning");
	
	If CommonUse.SubsystemExists("StandardSubsystems.CurrentWorks") Then
		ServerHandlers["StandardSubsystems.CurrentWorks\AtFillingToDoList"].Add(
			"ObjectVersioning");
	EndIf;
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"ObjectVersioning");
		
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ServerHandlers[
			"StandardSubsystems.SaaS.JobQueue\WhenYouDefineAliasesHandlers"].Add(
			"ObjectVersioning");
	EndIf;
		
EndProcedure

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.3.8";
	Handler.Procedure = "ObjectVersioning.RefreshInformationAboutObjectsVersions";
	Handler.PerformModes = "Delay";
	Handler.Comment = NStr("en='Update information about the recorded versions of objects.';ru='Обновление сведений о записанных версиях объектов.'");
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.4.13";
	Handler.Procedure = "ObjectVersioning.TransferVersioningSettings";
	Handler.Comment = NStr("en='Update of versioning settings.';ru='Обновление настроек версионирования.'");
	
EndProcedure

// Fills attributes of versions register.
Procedure RefreshInformationAboutObjectsVersions(Parameters) Export
	
	QueryText =
	"SELECT TOP 10000
	|	ObjectVersionings.Object,
	|	ObjectVersionings.VersionNumber
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectVersionings
	|WHERE
	|	ObjectVersionings.DataSize = 0";
	
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	
	RecordsProcessed = 0;
	While Selection.Next() Do
		RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
		RecordSet.Filter.Object.Set(Selection.Object);
		RecordSet.Filter.VersionNumber.Set(Selection.VersionNumber);
		RecordSet.Read();
		Try
			RecordSet.Write();
			RecordsProcessed = RecordsProcessed + 1;
		Except
			WriteLogEvent(
				NStr("en='Versioning';ru='Версионирование'", CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error, RecordSet.Metadata(),
				,
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Failed to update information about the No.%1 version of ""%2""
		|object by reason of: %3';ru='Не удалось обновить сведения о версии №%1 объекта ""%2"" по причине:
		|%3'", CommonUseClientServer.MainLanguageCode()),
					Selection.VersionNumber,
					CommonUse.SubjectString(Selection.Object),
					DetailErrorDescription(ErrorInfo())));
		EndTry;
	EndDo;
	
	If Selection.Count() > 0 Then
		If RecordsProcessed = 0 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Procedure RefreshInformationAboutObjectsVersions failed to process some records of information register ObjectVersionings (skipped): %1';ru='Процедуре ОбновитьСведенияОВерсияхОбъектов не удалось обработать некоторые записи регистра сведений ВерсииОбъектов (пропущены): %1'"), 
					Selection.Count());
			Raise MessageText;
		EndIf;
		Parameters.DataProcessorCompleted = False;
	EndIf;
	
EndProcedure

// Writes the object's version into the infobase.
//
// Parameters:
// Object - for version creation.
//
Procedure OnCreateObjectVersion(Object, WriteModePosting) Export
	
	Var LastVersionNumber, Comment;
	
	If Not ObjectIsVersioning(Object, LastVersionNumber, WriteModePosting) Then
		Return;
	EndIf;
	
	If Not Object.AdditionalProperties.Property("ObjectVersioningCommentToVersion", Comment) Then
		Comment = "";
	EndIf;
	
	InfoAboutObjectVersion = New Structure;
	InfoAboutObjectVersion.Insert("VersionNumber", Number(LastVersionNumber) + 1);
	InfoAboutObjectVersion.Insert("Comment", Comment);
	InfoAboutObjectVersion.Insert("PostingChanged", WriteModePosting);
	
	CreateObjectVersioning(Object, InfoAboutObjectVersion);
	
EndProcedure

// Writes the object version received during data exchange into the infobase.
// For object version object with no conflict checks versioning involvement.
//
// Parameters:
// Object - for version creation.
//
Procedure OnCreateObjectVersionByDataExchange(Object) Export
	
	Var LastVersionNumber;
	
	If Not CommonUse.ThisIsObjectOfReferentialType(Object.Metadata()) Then
		
		Return;
		
	EndIf;
	
	Ref = Object.Ref;
	
	InfoAboutObjectVersion = CommonUseClientServer.CopyStructure(
		Object.AdditionalProperties.InfoAboutObjectVersion);
	
	If InfoAboutObjectVersion.ObjectVersioningType = "AcceptDataOnConflicts" Then
		
		LastVersionNumber = LastVersionNumber(Ref);
		
		InfoAboutObjectVersion.Insert("Object", Ref);
		InfoAboutObjectVersion.Insert("VersionNumber", Number(LastVersionNumber) + 1);
		InfoAboutObjectVersion.ObjectVersioningType = Enums.ObjectVersionsTypes[InfoAboutObjectVersion.ObjectVersioningType];
		
		CreateObjectVersioning(Object, InfoAboutObjectVersion, False);
		
	ElsIf ObjectIsVersioning(Object, LastVersionNumber) Then
		
		If InfoAboutObjectVersion.PostponedProcessing Then
			
			LastVersionNumber = LastVersionNumber(Ref);
			WriteOverPreviousVersion(Ref, Object, LastVersionNumber, InfoAboutObjectVersion);
			
		Else
			
			InfoAboutObjectVersion.Insert("Object", Ref);
			InfoAboutObjectVersion.Insert("VersionNumber", Number(LastVersionNumber) + 1);
			InfoAboutObjectVersion.ObjectVersioningType = Enums.ObjectVersionsTypes[InfoAboutObjectVersion.ObjectVersioningType];
			
			CreateObjectVersioning(Object, InfoAboutObjectVersion, False);
			
		EndIf;
		
	EndIf;
	
	Object.AdditionalProperties.Delete("InfoAboutObjectVersion");
	
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
	If Not AccessRight("Edit", Metadata.InformationRegisters.ObjectVersioningSettings)
		Or ModuleCurrentWorksService.WorkDisabled("ObjectsOutdatedVersions") Then
		Return;
	EndIf;
	ModuleCurrentWorksServer = CommonUse.CommonModule("CurrentWorksServer");
	
	// The procedure is called only if there is the
	// To-do lists subsystem, that is why here is no checking of subsystem existence.
	Sections = ModuleCurrentWorksServer.SectionsForObject(Metadata.InformationRegisters.ObjectVersioningSettings.FullName());
	
	If Sections = Undefined Then
		Return;
	EndIf;
	
	InformationAboutLegacyVersions = InformationAboutLegacyVersions();
	OutdatedDataSize = DataSizeString(InformationAboutLegacyVersions.DataSize);
	ToolTip = NStr("en='Outdated versions:% 1 (%2)';ru='Устаревших версий: %1 (%2)'");
	
	For Each Section IN Sections Do
		
		IdentifierOutdatedObjects = "ObjectsOutdatedVersions" + StrReplace(Section.FullName(), ".", "");
		// Add to-do.
		Work = CurrentWorks.Add();
		Work.ID = IdentifierOutdatedObjects;
		// Display a to-do if obsolete data size is more than 1 Gb.
		Work.ThereIsWork      = InformationAboutLegacyVersions.DataSize > (1024 * 1024 * 1024);
		Work.Presentation = NStr("en='Outdated versions of objects';ru='Устаревшие версии объектов'");
		Work.Form         = "InformationRegister.ObjectVersioningSettings.Form.ObjectVersioning";
		Work.ToolTip     = StringFunctionsClientServer.SubstituteParametersInString(ToolTip, InformationAboutLegacyVersions.CountVersions, OutdatedDataSize);
		Work.Owner      = Section;
		
	EndDo;
	
EndProcedure

// Fills in the match of methods names and their aliases for call from the jobs queue.
//
// Parameters:
//  AccordanceNamespaceAliases - Correspondence
//   Key - Method alias, for example, ClearDataArea.
//   Value - Method name for call, for example, SaaSOperations.ClearDataArea.
//    You can specify Undefined as a value, in this case, it is
// considered that name matches the alias.
//
Procedure WhenYouDefineAliasesHandlers(AccordanceNamespaceAliases) Export
	
	AccordanceNamespaceAliases.Insert("ObjectVersioning.ClearObsoleteObjectsVersions");
	
EndProcedure

// Creates and writes the version of an object into the infobase.
//
Procedure CreateObjectVersioning(Object, InfoAboutObjectVersion, WriteCommonVersion = True)
	
	ValidateRightsForObjectModifying(Object.Metadata());
	
	SetPrivilegedMode(True);
	
	If WriteCommonVersion Then
		PostingChanged = False;
		If InfoAboutObjectVersion.Property("PostingChanged") Then
			PostingChanged = InfoAboutObjectVersion.PostingChanged;
		EndIf;
		// Previous version data recording.
		If Not Object.IsNew() AND (PostingChanged Or VersionDiffersFromPreviouslyRecorded(Object)) Then
			// If the versioning is enabled after creation of the object, create previous record about the version.
			If InfoAboutObjectVersion.VersionNumber = 1 Then
				If ObjectIsVersioning(Object.Ref, False) Then
					VersionParameters = New Structure;
					VersionParameters.Insert("VersionNumber", 1);
					VersionParameters.Insert("Comment", NStr("en='Version is created by already existing object';ru='Версия создана по уже имеющемуся объекту'"));
					CreateObjectVersioning(Object.Ref.GetObject(), VersionParameters);
					InfoAboutObjectVersion.VersionNumber = 2;
				EndIf;
			EndIf;
			
			// Save object previous version.
			RecordManager = InformationRegisters.ObjectsVersions.CreateRecordManager();
			RecordManager.Object = Object.Ref;
			RecordManager.VersionNumber = InfoAboutObjectVersion.VersionNumber - 1;
			RecordManager.Read();
			If RecordManager.Selected() Then
				BinaryData = SerializeObject(Object.Ref.GetObject());
				DataStorage = New ValueStorage(BinaryData, New Deflation(9));
				RecordManager.ObjectVersioning = DataStorage;
				RecordManager.Write();
			EndIf;
		EndIf;
		
		ObjectReference = Object.Ref;;
		If ObjectReference.IsEmpty() Then
			ObjectReference = Object.GetNewObjectRef();
			If ObjectReference.IsEmpty() Then
				ObjectReference = CommonUse.ObjectManagerByRef(Object.Ref).GetRef();
				Object.SetNewObjectRef(ObjectReference);
			EndIf;
		EndIf;
		
		// Record of the current version without data.
		RecordManager = InformationRegisters.ObjectsVersions.CreateRecordManager();
		RecordManager.Object = ObjectReference;
		RecordManager.VersionNumber = InfoAboutObjectVersion.VersionNumber;
		RecordManager.VersionDate = CurrentSessionDate();
		
		VersionAuthor = Undefined;
		If Not Object.AdditionalProperties.Property("VersionAuthor", VersionAuthor) Then
			VersionAuthor = Users.AuthorizedUser();
		EndIf;
		RecordManager.VersionAuthor = VersionAuthor;
		
		RecordManager.ObjectVersioningType = Enums.ObjectVersionsTypes.ChangedByUser;
		InfoAboutObjectVersion.Property("Comment", RecordManager.Comment);
	Else
		BinaryData = SerializeObject(Object);
		DataStorage = New ValueStorage(BinaryData, New Deflation(9));
		
		RecordManager = InformationRegisters.ObjectsVersions.CreateRecordManager();
		RecordManager.VersionDate = CurrentSessionDate();
		RecordManager.ObjectVersioning = DataStorage;
		FillPropertyValues(RecordManager, InfoAboutObjectVersion);
	EndIf;
	
	RecordManager.Write();
	
EndProcedure

// Writes the object version received during data exchange into the infobase.
//
// Parameters:
// Object - for version creation.
// InfoAboutObjectVersion - Structure - contains information about the object version.
// RefExists - Boolean - Sign of object existence by reference in the infobase.
//
Procedure CreateVersionObjectByDataExchange(Object, InfoAboutObjectVersion, RefExists = Undefined) Export
	
	Ref = Object.Ref;
	
	If Not ValueIsFilled(RefExists) Then
		RefExists = CommonUse.RefExists(Ref);
	EndIf;
		
	If RefExists Then
		
		LastVersionNumber = LastVersionNumber(Ref);
		
	Else
		
		Ref = CommonUse.ObjectManagerByRef(Ref).GetRef(Object.GetNewObjectRef().UUID());
		LastVersionNumber = 0;
		
	EndIf;
	
	InfoAboutObjectVersion.Insert("Object", Ref);
	InfoAboutObjectVersion.Insert("VersionNumber", Number(LastVersionNumber) + 1);
	InfoAboutObjectVersion.ObjectVersioningType = Enums.ObjectVersionsTypes[InfoAboutObjectVersion.ObjectVersioningType];
	
	If Not ValueIsFilled(InfoAboutObjectVersion.VersionAuthor) Then
		InfoAboutObjectVersion.VersionAuthor = Users.AuthorizedUser();
	EndIf;
	
	CreateObjectVersioning(Object, InfoAboutObjectVersion, False);
	
EndProcedure

// Sets the flag showing that the object version is ignored.
//
// Parameters:
// Ref - Ref to the ignored object.
// VersionNumber - Number - Number of the ignored object version.
// Ignore - Boolean Shows that the version is ignored.
//
Procedure IgnoreObjectVersioning(Ref, VersionNumber, Ignore) Export
	
	ValidateRightsForObjectModifying(Ref.Metadata());
	
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
	RecordSet.Filter.Object.Set(Ref);
	RecordSet.Filter.VersionNumber.Set(VersionNumber);
	RecordSet.Read();
	
	Record = RecordSet[0];
	
	Record.VersionIgnored = Ignore;
	
	RecordSet.Write();
	
EndProcedure

// Returns the quantity of conflicts or unaccepted objects.
//
// Parameters:
// ExchangeNodes - ExchangePlanRef, Array, ValueList, Undefined - filter to get number of collisions.
// ThisIsCollisionsQuantity - Boolean - If True returns the number of conflicts or else the number of missed.
// ShowIgnored - Boolean - Sign of need for ignored accounting.
// InfobaseNode - ExchangePlanRef - Number by specific host.
// Period - Standard period - Number by date.
// SearchString - String - Number of objects containing the SearchString commentaries.
//
Function CollisionsOrUnacceptedQuantity(ExchangeNodes, ThisIsCollisionsQuantity,
	ShowIgnored, Period, SearchString) Export
	
	Count = 0;
	
	If Not HasRightToReadVersions() Then
		Return Count;
	EndIf;
	
	QueryText = "SELECT ALLOWED
	|	COUNT(ObjectVersionings.Object) AS Count
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectVersionings
	|WHERE
	|	ObjectVersionings.VersionIgnored <> &FilterBySkipped
	|	AND (ObjectVersionings.ObjectVersioningType IN (&TypesOfVersions))
	|	[FilterByNode]
	|	[FilterByPeriod]
	|	[FilterByReason]";
	
	Query = New Query;
	
	FilterBySkipped = ?(ShowIgnored, Undefined, True);
	Query.SetParameter("FilterBySkipped", FilterBySkipped);
	
	If ExchangeNodes = Undefined Then
		FilterRow = "";
	ElsIf ExchangePlans.AllRefsType().ContainsType(TypeOf(ExchangeNodes)) Then
		FilterRow = "AND ObjectsVersions.VersionAuthor = & ExchangeNods";
		Query.SetParameter("ExchangeNodes", ExchangeNodes);
	Else
		FilterRow = "AND ObjectsVersions.VersionAuthor B (&ExchangeNods)";
		Query.SetParameter("ExchangeNodes", ExchangeNodes);
	EndIf;
	QueryText = StrReplace(QueryText, "[FilterByNode]", FilterRow);
	
	If ValueIsFilled(Period) Then
		
		FilterRow = "And (ObjectsVersions.VersionDate >= &StartDate And ObjectsVersions.VersionDate <= &EndDate)";
		Query.SetParameter("StartDate", Period.StartDate);
		Query.SetParameter("EndDate", Period.EndDate);
		
	Else
		
		FilterRow = "";
		
	EndIf;
	QueryText = StrReplace(QueryText, "[FilterByPeriod]", FilterRow);
	
	TypesOfVersions = New ValueList;
	If ValueIsFilled(ThisIsCollisionsQuantity) Then
		
		If ThisIsCollisionsQuantity Then
			
			TypesOfVersions.Add(Enums.ObjectVersionsTypes.AcceptDataOnConflicts);
			TypesOfVersions.Add(Enums.ObjectVersionsTypes.DataUnacceptedByCollision);
			
			FilterRow = "";
			
		Else
			
			TypesOfVersions.Add(Enums.ObjectVersionsTypes.UnacceptedDataByProhibitionDateObjectExists);
			TypesOfVersions.Add(Enums.ObjectVersionsTypes.UnacceptedDataByProhibitionDateObjectNotExists);
			
			If ValueIsFilled(SearchString) Then
				
				FilterRow = "AND ObjectsVersions.Comment LIKE & Comment";
				Query.SetParameter("Comment", "%" + SearchString + "%");
				
			Else
				
				FilterRow = "";
				
			EndIf;
			
		EndIf;
		
	Else // Filter by comment is not supported.
		
		TypesOfVersions.Add(Enums.ObjectVersionsTypes.AcceptDataOnConflicts);
		TypesOfVersions.Add(Enums.ObjectVersionsTypes.DataUnacceptedByCollision);
		TypesOfVersions.Add(Enums.ObjectVersionsTypes.UnacceptedDataByProhibitionDateObjectExists);
		TypesOfVersions.Add(Enums.ObjectVersionsTypes.UnacceptedDataByProhibitionDateObjectNotExists);
		
	EndIf;
	QueryText = StrReplace(QueryText, "[FilterByReason]", FilterRow);
	Query.SetParameter("TypesOfVersions", TypesOfVersions);
	
	Query.Text = QueryText;
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		Selection.Next();
		Count = Selection.Count;
	EndIf;
	
	Return Count;
	
EndFunction

Function ObjectFromBinaryData(BinaryData)
	
	XMLReader = New FastInfosetReader;
	XMLReader.SetBinaryData(BinaryData);
	If XMLReader.Read() Then
		If CanReadXML(XMLReader) Then
			Object = ReadXML(XMLReader);
			XMLReader.Close();
			Return Object;
		Else
			XMLReader.Close();
			Raise NStr("en='An error occurred while restoring the object';ru='Ошибка при восстановлении объекта'");
		EndIf;
	Else
		XMLReader.Close();
		Raise NStr("en='Data reading error';ru='Ошибка чтения данных'");
	EndIf;

EndFunction

Function RecordAboutObjectVersioning(ObjectReference, VersionNumber)
	
	RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
	RecordSet.Filter.Object.Set(ObjectReference);
	RecordSet.Filter.VersionNumber.Set(VersionNumber);
	RecordSet.Read();
	
	Return RecordSet;
	
EndFunction

Procedure WriteOverPreviousVersion(Ref, Object, VersionNumber, InfoAboutObjectVersion)
	
	SetPrivilegedMode(True);
	
	RecordSet = RecordAboutObjectVersioning(Ref, VersionNumber);
	
	If RecordSet.Count() = 0 Then
		
		VersionsData = New Structure;
		VersionsData.Insert("Object", Ref);
		VersionsData.Insert("VersionNumber", Number(VersionNumber) + 1);
		VersionsData.Insert("VersionAuthor", InfoAboutObjectVersion.VersionAuthor);
		VersionsData.Insert("Comment", NStr("en='Version is created at the data synchronization.';ru='Версия создана при синхронизации данных.'"));
		VersionsData.Insert("ObjectVersioningType", Enums.ObjectVersionsTypes[InfoAboutObjectVersion.ObjectVersioningType]);
		
		CreateObjectVersioning(Object, VersionsData, False);
		
	Else
		
		RecordAboutVersion = RecordSet[0];
		
		XMLWriter = New FastInfosetWriter;
		XMLWriter.SetBinaryData();
		XMLWriter.WriteXMLDeclaration();
		WriteXML(XMLWriter, Object, XMLTypeAssignment.Explicit);
		BinaryData = XMLWriter.Close();
		DataStorage = New ValueStorage(BinaryData, New Deflation(9));
		
		RecordAboutVersion.VersionDate	= CurrentSessionDate();
		RecordAboutVersion.ObjectVersioning = DataStorage;
		
		RecordSet.Write();
		
	EndIf;
	
EndProcedure

Procedure ValidateRightsForObjectModifying(MetadataObject)
	
	If Not PrivilegedMode() AND Not AccessRight("Update", MetadataObject)Then
		MessageText = NStr("en='Not enough rights to change ""%1"".';ru='Недостаточно прав на изменение ""%1"".'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, MetadataObject.Presentation());
		Raise MessageText;
	EndIf;
	
EndProcedure

Procedure TransferVersioningSettings() Export
	
	QueryText = 
	"SELECT
	|	DeleteObjectVersioningSettings.ObjectType AS ObjectName,
	|	DeleteObjectVersioningSettings.Variant,
	|	DeleteObjectVersioningSettings.Use,
	|	DeleteObjectVersioningSettings.VersionsStorageTerm
	|FROM
	|	InformationRegister.DeleteObjectVersioningSettings AS DeleteObjectVersioningSettings";

	Query = New Query;
	Query.Text = QueryText;
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	VersioningSettings = QueryResult.Unload();
	
	RecordSet = InformationRegisters.ObjectVersioningSettings.CreateRecordSet();
	For Each VersioningSetup IN VersioningSettings Do
		MetadataObject = Metadata.FindByFullName(VersioningSetup.ObjectName);
		If MetadataObject = Undefined Then
			Continue;
		EndIf;
		ObjectType = CommonUse.MetadataObjectID(MetadataObject);
		
		Record = RecordSet.Add();
		FillPropertyValues(Record, VersioningSetup);
		Record.ObjectType = ObjectType;
	EndDo;
	InfobaseUpdate.WriteData(RecordSet);
	
	RecordSet = InformationRegisters.DeleteObjectVersioningSettings.CreateRecordSet();
	InfobaseUpdate.WriteData(RecordSet);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into this subsystem.

// Handler of the transition to the object version.
//
// Parameters:
// ObjectRef - Ref - References to the object for which there is a version.
// VersionForTransitionNumber - Number - Version number to which it is required to execute transition.
// IgnoredVersionNumber - Number - Number of version that should be ignored.
// SkipChangeProhibitionCheck - Boolean - Shows that the check of import ban date is skipped.
//
Procedure OnTransitionToObjectVersioning(ObjectReference, Val VersionNumber) Export
	
	ValidateRightsForObjectModifying(ObjectReference.Metadata());
	
	SetPrivilegedMode(True);
	
	RecordSet = RecordAboutObjectVersioning(ObjectReference, VersionNumber);
	Record = RecordSet[0];
	
	If Record.ObjectVersioningType = Enums.ObjectVersionsTypes.AcceptDataOnConflicts Then
		
		VersionNumber = VersionNumber - 1;
		
		If VersionNumber <> 0 Then
			
			PreviousRecord = RecordAboutObjectVersioning(ObjectReference, VersionNumber)[0];
			Object = ObjectFromBinaryData(PreviousRecord.ObjectVersioning.Get());
			VersionDate = PreviousRecord.VersionDate;
			
		EndIf;
		
	Else
		
		Object = ObjectFromBinaryData(Record.ObjectVersioning.Get());
		VersionDate = Record.VersionDate;
		
	EndIf;
	
	Object.AdditionalProperties.Insert("ObjectVersioningCommentToVersion",
		StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Proceeding to the version #%1 from %2 has been performed';ru='Выполнен переход к версии №%1 от %2'"),
		String(VersionNumber), Format(VersionDate, "DLF=DT")));
	Object.AdditionalProperties.Insert("SkipChangeProhibitionCheck");
	Object.Write();
	
	Record.VersionIgnored = True;
	RecordSet.Write();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns the number of the most recently written object version.
//
// Parameters:
//  Ref - AnyRef - Reference to the object of infobase.
//
// Returns:
//  Number - object version number.
//
Function LastVersionNumber(Ref) Export
	
	If Ref.IsEmpty() Then
		Return 0;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ISNULL(MAX(ObjectVersionings.VersionNumber), 0) AS VersionNumber
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectVersionings
	|WHERE
	|	ObjectVersionings.Object = &Ref";
	Query.SetParameter("Ref", Ref);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Selection.VersionNumber;
	
EndFunction

// Returns full names of metadata objects for which versioning is enabled.
//
// Returns:
//  Strings array - names of metadata objects.
//
Function GetVersioningObjects()
	
	Result = New Array;
	
	For Each Type IN Metadata.CommonCommands.ChangesHistory.CommandParameterType.Types() Do
		Result.Add(CommonUse.MetadataObjectID(Type));
	EndDo;
	
	Return Result;
	
EndFunction

// Returns versioning variant for specified metadata object.
//
// Parameters:
//  ObjectType - CatalogRef.MetadataObjectID - MOI.
//
// Returns:
//  Enumeration.ObjectVersioningOptions.
//
Function ObjectVersioningVariant(ObjectType)
	
	Return GetFunctionalOption("ObjectVersioningOptions",
		New Structure("VersionizedObjectType", ObjectType));
		
EndFunction	

// Receives object by its serialized XML presentation.
//
// Parameters:
//  AddressInTemporaryStorage - String - address of binary data in temporary storage.
//  ErrorMessageText    - String - error text (returned parameter) if the object failed to be recovered.
//
// Returns - Object or Undefined.
//
Function RestoreObjectByXML(Val AddressInTemporaryStorage = "", ErrorMessageText = "") Export
	
	SetPrivilegedMode(True);
	
	BinaryData = GetFromTempStorage(AddressInTemporaryStorage);
	
	FastInfosetReader = New FastInfosetReader;
	FastInfosetReader.SetBinaryData(BinaryData);
	
	Try
		Object = ReadXML(FastInfosetReader);
	Except
		WriteLogEvent(NStr("en='Versioning';ru='Версионирование'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		ErrorMessageText = NStr("en='Failed to proceed to the selected version.
		|Possible cause: the object version has been recorded in another application version.
		|Technical information about error: %1';ru='Не удалось перейти на выбранную версию.
		|Возможная причина: версия объекта была записана в другой версии программы.
		|Техническая информация об ошибке: %1'");
		ErrorMessageText = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessageText, BriefErrorDescription(ErrorInfo()));
		Return Undefined;
	EndTry;
	
	Return Object;
	
EndFunction

// Returns a structure that contains the object version and additional information.
// 
// Parameters:
//  Ref      - Ref - ref to the versionized object;
//  VersionNumber - Number  - object version number.
// 
// Returns - Structure:
//                          ObjectVersioning - BinaryData - saved version of infobase object;
//                          VersionAuthor   - CatalogUsers, Catalog.ExternalUsers - 
//                                          user who wrote the object version.
//                          VersionDate    - Date - date of the object version record.
// 
// Note:
//  A function can call the exception in case the record doesn't contain data.
//  It is required to call the function in the privileged mode.
//
Function InfoAboutObjectVersion(Val Ref, Val VersionNumber) Export
	MessageFailedToGetVersion = NStr("en='Failed to obtain the previous object version.';ru='Не удалось получить предыдущую версию объекта.'");
	If Not Users.RolesAvailable("ReadObjectsVersions") Then
		Raise MessageFailedToGetVersion;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ObjectVersionings.VersionAuthor AS VersionAuthor,
	|	ObjectVersionings.VersionDate AS VersionDate,
	|	ObjectVersionings.Comment AS Comment,
	|	ObjectVersionings.ObjectVersioning
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectVersionings
	|WHERE
	|	ObjectVersionings.Object = &Ref
	|	AND ObjectVersionings.VersionNumber = &VersionNumber";
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("VersionNumber", Number(VersionNumber));
	
	Result = New Structure("ObjectVersion, VersionAuthor, VersionDate, Comment");
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		FillPropertyValues(Result, Selection);
		Result.ObjectVersioning = Result.ObjectVersioning.Get();
		If Result.ObjectVersioning = Undefined Then
			Result.ObjectVersioning = ObjectVersionsData(Ref, VersionNumber);
		EndIf;
	EndIf;
	
	If Result.ObjectVersioning = Undefined Then
		Raise NStr("en='Selected version of the object is not available in the application.';ru='Выбранная версия объекта отсутствует в программе.'");
	EndIf;
	
	Return Result;
		
EndFunction

// Checks versioning settings by passed
// object and returns versioning variant. If versioning
// is not configured for the object, it is
// versioned according to the rules of versioning "by default".
//
Function ObjectIsVersioning(Val Source, LastVersionNumber, WriteModePosting = False) Export
	
	// Check if versioning subsystem is enabled.
	If Not GetFunctionalOption("UseObjectVersioning") Then
		Return False;
	EndIf;
	
	VersioningVariant = ObjectVersioningVariant(CommonUse.MetadataObjectID(Source.Metadata()));
	If VersioningVariant = False Then
		VersioningVariant = Enums.ObjectVersioningOptions.DoNotVersion;
	EndIf;
	
	LastVersionNumber = LastVersionNumber(Source.Ref);
	
	Return LastVersionNumber > 0 
		Or VersioningVariant = Enums.ObjectVersioningOptions.VersionOnWrite
		Or VersioningVariant = Enums.ObjectVersioningOptions.VersionOnPosting AND (WriteModePosting Or Source.Posted)
		Or VersioningVariant = Enums.ObjectVersioningOptions.VersionOnStart AND Source.Started;
	
EndFunction

// Adds to additional properties the information to
// record a version of the object obtained at data exchange.
//
Procedure AddingInformationAboutVersionOfObjectInThe(Object, VersionAuthor)
	
	If TypeOf(Object) <> Type("ObjectDeletion") AND CommonUse.ThisIsObjectOfReferentialType(Object.Metadata()) Then
		
		InfoAboutObjectVersion = New Structure;
		InfoAboutObjectVersion.Insert("VersionAuthor", VersionAuthor);
		InfoAboutObjectVersion.Insert("ObjectVersioningType", "ChangedByUser");
		InfoAboutObjectVersion.Insert("Comment", NStr("en='Version is received at the data synchronization';ru='Версия получена при синхронизации данных.'"));
		InfoAboutObjectVersion.Insert("PostponedProcessing", False);
		Object.AdditionalProperties.Insert("InfoAboutObjectVersion", New FixedStructure(InfoAboutObjectVersion));
		
	EndIf;
	
EndProcedure

// Checks if the user has rights to read the information about versions.
//
Function HasRightToReadVersions() Export
	Return Users.RolesAvailable("ReadObjectsVersions ReadingInformationAboutObjectsVersions");
EndFunction

// Writes the object's version into the infobase.
//
// Parameters:
//  Source - Object - IB object being written;
//  Cancel    - Boolean - flag showing the cancelation of object writing.
//
Procedure WriteObjectVersion(Source, WriteModePosting = False) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Source.AdditionalProperties.Property("InfoAboutObjectVersion") Then
		Return;
	EndIf;
	
	OnCreateObjectVersion(Source, WriteModePosting);
	
EndProcedure

// Check sum by MD5 algorithm.
Function CheckSum(Data) Export
	DataHashing = New DataHashing(HashFunction.MD5);
	DataHashing.Append(Data);
	Return StrReplace(DataHashing.HashSum, " ", "");
EndFunction

Function ObjectVersionsData(ObjectReference, VersionNumber)
	
	QueryText = 
	"SELECT TOP 1
	|	ObjectVersionings.ObjectVersioning
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectVersionings
	|WHERE
	|	ObjectVersionings.Object = &Object
	|	AND ObjectVersionings.VersionNumber >= &VersionNumber
	|	AND ObjectVersionings.CheckSum <> """"
	|
	|ORDER BY
	|	ObjectVersionings.VersionNumber";
	
	Query = New Query(QueryText);
	Query.SetParameter("Object", ObjectReference);
	Query.SetParameter("VersionNumber", VersionNumber);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.ObjectVersioning.Get();
	EndIf;
	
	Return SerializeObject(ObjectReference.GetObject());
	
EndFunction

Function VersionDiffersFromPreviouslyRecorded(Object)
	
	QueryText = 
	"SELECT TOP 1
	|	ObjectVersionings.CheckSum
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectVersionings
	|WHERE
	|	ObjectVersionings.Object = &Object
	|	AND ObjectVersionings.ThereIsVersionData
	|
	|ORDER BY
	|	ObjectVersionings.VersionNumber DESC";
	
	Query = New Query(QueryText);
	Query.SetParameter("Object", Object.Ref);
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.CheckSum <> CheckSum(SerializeObject(Object));
	EndIf;
	
	Return Object.IsNew() Or CheckSum(SerializeObject(Object)) <> CheckSum(SerializeObject(Object.Ref.GetObject()));
	
EndFunction

// Only for official use.
Procedure ClearObsoleteObjectsVersions() Export
	
	SetPrivilegedMode(True);
	
	ObjectsRemovalBoundaries = ObjectsRemovalBoundaries();
	
	Query = New Query;
	QueryText =
	"SELECT
	|	ObjectVersionings.Object,
	|	ObjectVersionings.VersionNumber
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectVersionings
	|WHERE
	|	ObjectVersionings.ThereIsVersionData
	|	AND &AdditionalConditions";
	
	AdditionalConditions = "";
	For IndexOf = 0 To ObjectsRemovalBoundaries.Count() - 1 Do
		If Not IsBlankString(AdditionalConditions) Then
			AdditionalConditions = AdditionalConditions + "
			|	OR";
		EndIf;
		IndexString = Format(IndexOf, "NZ=0; NG=0");
		Condition = "";
		For Each Type IN ObjectsRemovalBoundaries[IndexOf].TypeList Do
			If Not IsBlankString(Condition) Then
				Condition = Condition + "
				|	OR";
			EndIf;
			Condition = Condition + "
			|	ObjectVersionings.Object REFS " + Type;
		EndDo;
		If IsBlankString(Condition) Then
			Continue;
		EndIf;
		Condition = "(" + Condition + ")";
		AdditionalConditions = AdditionalConditions + StringFunctionsClientServer.SubstituteParametersInString(
			"
			|	%1
			|	AND ObjectVersionings.VersionDate< &RemoveBoundary%2",
			Condition,
			IndexString);
		Query.SetParameter("TypeList" + IndexString, ObjectsRemovalBoundaries[IndexOf].TypeList);
		Query.SetParameter("RemoveBoundary" + IndexString, ObjectsRemovalBoundaries[IndexOf].RemoveBoundary);
	EndDo;

	If IsBlankString(AdditionalConditions) Then
		AdditionalConditions = "FALSE";
	Else
		AdditionalConditions = "(" + AdditionalConditions + ")";
	EndIf;
	
	QueryText = StrReplace(QueryText, "&AdditionalConditions", AdditionalConditions);
	
	Query.Text = QueryText;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		RecordManager = InformationRegisters.ObjectsVersions.CreateRecordManager();
		RecordManager.Object = Selection.Object;
		RecordManager.VersionNumber = Selection.VersionNumber;
		RecordManager.Read();
		RecordManager.ObjectVersioning = Undefined;
		RecordManager.Write();
	EndDo;
	
EndProcedure

Function ObjectsRemovalBoundaries() Export
	
	Result = New ValueTable;
	Result.Columns.Add("TypeList", New TypeDescription("Array"));
	Result.Columns.Add("RemoveBoundary", New TypeDescription("Date"));
	
	QueryText =
	"SELECT
	|	ObjectVersioningSettings.ObjectType.FullName AS ObjectType,
	|	ObjectVersioningSettings.VersionsStorageTerm AS VersionsStorageTerm
	|FROM
	|	InformationRegister.ObjectVersioningSettings AS ObjectVersioningSettings
	|
	|ORDER BY
	|	VersionsStorageTerm
	|TOTALS BY
	|	VersionsStorageTerm";
	
	Query = New Query(QueryText);
	SelectionStoragePeriods = Query.Execute().Select(QueryResultIteration.ByGroups);
	While SelectionStoragePeriods.Next() Do
		ObjectsSelection = SelectionStoragePeriods.Select();
		TypeList = New Array;
		While ObjectsSelection.Next() Do
			TypeList.Add(ObjectsSelection.ObjectType);
		EndDo;
		BoundariesMatchingToObjectsTypes = Result.Add();
		BoundariesMatchingToObjectsTypes.RemoveBoundary = RemoveBoundary(SelectionStoragePeriods.VersionsStorageTerm);
		BoundariesMatchingToObjectsTypes.TypeList = TypeList;
	EndDo;
	
	Return Result;
	
EndFunction

Function RemoveBoundary(VersionsStorageTerm)
	If VersionsStorageTerm = Enums.VersionStorageTerms.ForLastYear Then
		Return AddMonth(CurrentSessionDate(), -12);
	ElsIf VersionsStorageTerm = Enums.VersionStorageTerms.ForLastSixMonths Then
		Return AddMonth(CurrentSessionDate(), -6);
	ElsIf VersionsStorageTerm = Enums.VersionStorageTerms.ForLastThreeMonths Then
		Return AddMonth(CurrentSessionDate(), -3);
	ElsIf VersionsStorageTerm = Enums.VersionStorageTerms.RecentMonth Then
		Return AddMonth(CurrentSessionDate(), -1);
	ElsIf VersionsStorageTerm = Enums.VersionStorageTerms.RecentWeek Then
		Return CurrentSessionDate() - 7*24*60*60;
	Else // VersionsStorageTerm = Enums.VersionStorageStrings.Indefinitely
		Return '000101010000';
	EndIf;
EndFunction

// Only for official use.
// Comment is recorded if the user is either the author of the version or the administrator.
Procedure AddCommentToVersions(ObjectReference, VersionNumber, Comment) Export
	
	If Not HasRightToReadVersions() Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.ObjectsVersions.CreateRecordManager();
	RecordManager.Object = ObjectReference;
	RecordManager.VersionNumber = VersionNumber;
	RecordManager.Read();
	If RecordManager.Selected() Then
		If RecordManager.VersionAuthor = Users.CurrentUser() Or Users.InfobaseUserWithFullAccess(, , False) Then
			RecordManager.Comment = Comment;
			RecordManager.Write();
		EndIf;
	EndIf;
	
EndProcedure

// Provides information on the number and length of obsolete versions of objects.
Function InformationAboutLegacyVersions() Export
	
	SetPrivilegedMode(True);
	
	ObjectsRemovalBoundaries = ObjectsRemovalBoundaries();
	
	Query = New Query;
	QueryText =
	"SELECT
	|	ISNULL(SUM(ObjectVersionings.DataSize), 0) AS DataSize,
	|	ISNULL(SUM(1), 0) AS CountVersions
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectVersionings
	|WHERE
	|	ObjectVersionings.ThereIsVersionData
	|	AND &AdditionalConditions";
	
	AdditionalConditions = "";
	For IndexOf = 0 To ObjectsRemovalBoundaries.Count() - 1 Do
		If Not IsBlankString(AdditionalConditions) Then
			AdditionalConditions = AdditionalConditions + "
			|	OR";
		EndIf;
		IndexString = Format(IndexOf, "NZ=0; NG=0");
		Condition = "";
		For Each Type IN ObjectsRemovalBoundaries[IndexOf].TypeList Do
			If Not IsBlankString(Condition) Then
				Condition = Condition + "
				|	OR";
			EndIf;
			Condition = Condition + "
			|	ObjectVersionings.Object REFS " + Type;
		EndDo;
		If IsBlankString(Condition) Then
			Continue;
		EndIf;
		Condition = "(" + Condition + ")";
		AdditionalConditions = AdditionalConditions + StringFunctionsClientServer.SubstituteParametersInString(
			"
			|	%1
			|	AND ObjectVersionings.VersionDate< &RemoveBoundary%2",
			Condition,
			IndexString);
		Query.SetParameter("TypeList" + IndexString, ObjectsRemovalBoundaries[IndexOf].TypeList);
		Query.SetParameter("RemoveBoundary" + IndexString, ObjectsRemovalBoundaries[IndexOf].RemoveBoundary);
	EndDo;

	If IsBlankString(AdditionalConditions) Then
		AdditionalConditions = "FALSE";
	Else
		AdditionalConditions = "(" + AdditionalConditions + ")";
	EndIf;
	
	QueryText = StrReplace(QueryText, "&AdditionalConditions", AdditionalConditions);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	CountVersions = 0;
	DataSize = 0;
	If Selection.Next() Then
		DataSize = Selection.DataSize;
		CountVersions = Selection.CountVersions;
	EndIf;
	
	Result = New Structure;
	Result.Insert("CountVersions", CountVersions);
	Result.Insert("DataSize", DataSize);
	
	Return Result;
	
EndFunction

// See InformationAboutLegacyVersions.
Procedure InformationAboutOutdatedVersionsInBackground(AdditionalParameters, AddressInTemporaryStorage) Export
	Result = InformationAboutLegacyVersions();
	Result.Insert("DataSizeString", DataSizeString(Result.DataSize));
	PutToTempStorage(Result, AddressInTemporaryStorage);
EndProcedure

// String layout of data volumes. For example: "1.23 Gb".
Function DataSizeString(Val DataSize) Export
	
	MeasurementUnit = NStr("en='byte';ru='байт'");
	If 1024 <= DataSize AND DataSize < 1024 * 1024 Then
		DataSize = DataSize / 1024;
		MeasurementUnit = NStr("en='Kb';ru='Кбайт'");
	ElsIf 1024 * 1024 <= DataSize AND  DataSize < 1024 * 1024 * 1024 Then
		DataSize = DataSize / 1024 / 1024;
		MeasurementUnit = NStr("en='MB';ru='MB'");
	ElsIf 1024 * 1024 * 1024 <= DataSize Then
		DataSize = DataSize / 1024 / 1024 / 1024;
		MeasurementUnit = NStr("en='Gb';ru='Гб'");
	EndIf;
	
	If DataSize < 10 Then
		DataSize = Round(DataSize, 2);
	ElsIf DataSize < 100 Then
		DataSize = Round(DataSize, 1);
	Else
		DataSize = Round(DataSize, 0);
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='%1 %2';ru='%1 %2'"), DataSize, MeasurementUnit);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions to get the report on object.

// Returns the serialized object in binary data form.
//
// Parameters:
//  Object - Any - serializable object.
//
// Returns:
//  BinaryData - serialized object.
Function SerializeObject(Object) Export
	
	XMLWriter = New FastInfosetWriter;
	XMLWriter.SetBinaryData();
	XMLWriter.WriteXMLDeclaration();
	
	WriteXML(XMLWriter, Object, XMLTypeAssignment.Explicit);
	
	Return XMLWriter.Close();

EndFunction

// Procedure reads  XML data from file and fills in the data structures.
//
// Returns:
// Structure, that contains two matchings: tabularSections, Attributes.
// Data storage structure:
// Matching TabličnyeČasti which contains in itself
// the values tabular sections format: 
//          NameMap1
//                            -> ValuesTable1 | | ... |
//                            Field1  Field2  M1Field
//
//          NameMap2
//                            -> ValuesTable2 | | ... |
//                            Field1  Field2     M2Field
//
//
//          NameMapN
//                            -> ValuesTableN | | ... |
//                            Field1  Field2  M3Field
//
// Match
//          AttributeValues AttributeName1 ->
//          Value1 AttributeName2 ->
//          Value2 ...
//          AttributeNName > ValueN
//
Function ParsingObjectXMLPresentation(BinaryData, Ref) Export
	
	// Contains the name of the changed metadata object.
	Var ObjectName;
	
	// Contains the location of the marker on XML tree.
	// Required for the identification of current item.
	Var ReadLevel;
	
	// Contain values of catalogs/documents attributes.
	AttributeValues = New ValueTable;
	
	AttributeValues.Columns.Add("DescriptionAttribute");
	AttributeValues.Columns.Add("AttributeValue");
	AttributeValues.Columns.Add("AttributeType");
	AttributeValues.Columns.Add("Type");
	
	TabularSections = New Map;
	
	XMLReader = New FastInfosetReader;
	
	XMLReader.SetBinaryData(BinaryData);
	
	// Level of marker position in the XML hierarchy:
	// 0 - level
	// is not set 1 - first item (object
	// name) 2 - description of an attribute
	// or tabular section 3 - description of
	// the tabular section 4 row - description of the tabular section row field.
	ReadLevel = 0;
	
	ObjectMetadata = Ref.Metadata();
	MTDTabularSections = ObjectMetadata.TabularSections;
	
	ValueType = "";
	
	TypeOfTSFieldValue = "";
	
	// Common XML parser cycle.
	While XMLReader.Read() Do
		
		If XMLReader.NodeType = XMLNodeType.StartElement Then
			ReadLevel = ReadLevel + 1;
			If ReadLevel = 1 Then // A pointer on the first XML item - root XML.
				ObjectName = XMLReader.Name;
			ElsIf ReadLevel = 2 Then // A pointer on the second level - it is attribute or tabular section name.
				AttributeName = XMLReader.Name;
				
				// Any attribute can be a tabular section, that is why remember it just in case.
				TabularSectionName = AttributeName;
				If ObjectMetadata.TabularSections.Find(TabularSectionName) <> Undefined AND TabularSections[TabularSectionName] = Undefined Then
					TabularSections.Insert(TabularSectionName, New ValueTable);
				EndIf;
				
				NewRL = AttributeValues.Add();
				NewRL.DescriptionAttribute = AttributeName;
				
				If XMLReader.AttributeCount() > 0 Then
					While XMLReader.ReadAttribute() Do
						If XMLReader.NodeType = XMLNodeType.Attribute 
						   AND XMLReader.Name = "xsi:type" Then
							NewRL.AttributeType = XMLReader.Value;
							
							XMLType = XMLReader.Value;
							
							If Left(XMLType, 3) = "xs:" Then
								NewRL.Type = FromXMLType(New XMLDataType(Right(XMLType, StrLen(XMLType)-3), "http://www.w3.org/2001/XMLSchema"));
							Else
								NewRL.Type = FromXMLType(New XMLDataType(XMLType, ""));
							EndIf;
							
						EndIf;
					EndDo;
				EndIf;
				
				If Not ValueIsFilled(NewRL.Type) Then
					
					AttributeFullName = ObjectMetadata.Attributes.Find(NewRL.DescriptionAttribute);
					
					If AttributeFullName = Undefined Then
						
						DescriptionAttribute = GetAttributePresentationInLanguage(NewRL.DescriptionAttribute);
						
						If CommonUse.ThisIsStandardAttribute(ObjectMetadata.StandardAttributes, DescriptionAttribute) Then
							
							AttributeFullName = ObjectMetadata.StandardAttributes[DescriptionAttribute];
							
						EndIf;
						
					EndIf;
					
					If AttributeFullName <> Undefined
						AND AttributeFullName.Type.Types().Count() = 1 Then
						NewRL.Type = AttributeFullName.Type.Types()[0];
					EndIf;
					
				EndIf;
				
			ElsIf (ReadLevel = 3) AND (XMLReader.Name = "Row") Then // A pointer to the tabular section field.
				If TabularSections[TabularSectionName] = Undefined Then
					TabularSections.Insert(TabularSectionName, New ValueTable);
				EndIf;
				
				TabularSections[TabularSectionName].Add();
			ElsIf ReadLevel = 4 Then // A pointer to the tabular section field.
				
				TypeOfTSFieldValue = "";
				
				TSFieldName = XMLReader.Name; // 
				Table   = TabularSections[TabularSectionName];
				If Table.Columns.Find(TSFieldName)= Undefined Then
					Table.Columns.Add(TSFieldName);
				EndIf;
				
				If XMLReader.AttributeCount() > 0 Then
					While XMLReader.ReadAttribute() Do
						If XMLReader.NodeType = XMLNodeType.Attribute 
						   AND XMLReader.Name = "xsi:type" Then
							XMLType = XMLReader.Value;
							
							If Left(XMLType, 3) = "xs:" Then
								TypeOfTSFieldValue = FromXMLType(New XMLDataType(Right(XMLType, StrLen(XMLType)-3), "http://www.w3.org/2001/XMLSchema"));
							Else
								TypeOfTSFieldValue = FromXMLType(New XMLDataType(XMLType, ""));
							EndIf;
							
						EndIf;
					EndDo;
				EndIf;
				
			EndIf;
		ElsIf XMLReader.NodeType = XMLNodeType.EndElement Then
			ReadLevel = ReadLevel - 1;
			ValueType = "";
		ElsIf XMLReader.NodeType = XMLNodeType.Text Then
			If (ReadLevel = 2) Then // attribute value
				Try
					NewRL.AttributeValue = ?(ValueIsFilled(NewRL.Type), XMLValue(NewRL.Type, XMLReader.Value), XMLReader.Value);
				Except
					NewRL.AttributeValue = XMLReader.Value;
				EndTry;
			ElsIf (ReadLevel = 4) Then // attribute value
				LastRow = TabularSections[TabularSectionName].Get(TabularSections[TabularSectionName].Count()-1);
				
				If TypeOfTSFieldValue = "" Then
					TSADescription = Undefined;
					If MTDTabularSections.Find(TabularSectionName) <> Undefined Then
						TSADescription = MTDTabularSections[TabularSectionName].Attributes.Find(TSFieldName);
						
						If TSADescription <> Undefined
						   AND TSADescription.Type.Types().Count() = 1 Then
							TypeOfTSFieldValue = TSADescription.Type.Types()[0];
						EndIf;
					EndIf;					
				EndIf;
				
				LastRow[TSFieldName] = ?(ValueIsFilled(TypeOfTSFieldValue), XMLValue(TypeOfTSFieldValue, XMLReader.Value), XMLReader.Value);
				
			EndIf;
		EndIf;
	EndDo;
	
	// ThTH stage: list details of exclude tabular sections.
	For Each Item IN TabularSections Do
		AttributeValues.Delete(AttributeValues.Find(Item.Key));
	EndDo;
	// MTDTabularSections
	For Each MapItem IN TabularSections Do
		Table = MapItem.Value;
		If Table.Columns.Count() = 0 Then
			TableMTD = MTDTabularSections.Find(MapItem.Key);
			If TableMTD <> Undefined Then
				For Each ColumnDetails IN TableMTD.Attributes Do
					If Table.Columns.Find(ColumnDetails.Name)= Undefined Then
						Table.Columns.Add(ColumnDetails.Name);
					EndIf;
				EndDo;
			EndIf;
		EndIf;
	EndDo;
	
	Result = New Structure;
	Result.Insert("Attributes", AttributeValues);
	Result.Insert("TabularSections", TabularSections);
	
	Return Result;
	
EndFunction

// Receives a presentation of the system attribute name.
//
Function GetAttributePresentationInLanguage(Val AttributeName) Export
	
	If      AttributeName = "Number" Then
		Return NStr("en='Number';ru='Номер'");
	ElsIf AttributeName = "Name" Then
		Return NStr("en='Description';ru='Наименование'");
	ElsIf AttributeName = "Code" Then
		Return NStr("en='Code';ru='код'");
	ElsIf AttributeName = "IsFolder" Then
		Return NStr("en='IsFolder';ru='IsFolder'");
	ElsIf AttributeName = "Description" Then
		Return NStr("en='Description';ru='Наименование'");
	ElsIf AttributeName = "Date" Then
		Return NStr("en='Date';ru='Дата'");
	ElsIf AttributeName = "Posted" Then
		Return NStr("en='Posted';ru='Проведен'");
	ElsIf AttributeName = "DeletionMark" Then
		Return NStr("en='DeletionMark';ru='ПометкаУдаления'");
	ElsIf AttributeName = "Ref" Then
		Return NStr("en='Ref';ru='Ссылка'");
	ElsIf AttributeName = "Parent" Then
		Return NStr("en='Parent';ru='Родитель'");
	ElsIf AttributeName = "Owner" Then
		Return NStr("en='Owner';ru='Владелец'");
	Else
		Return AttributeName;
	EndIf;
	
EndFunction

Procedure GenerateReportByObjectVersioning(SpreadsheetDocument, ObjectDescription, ObjectReference)
	
	If ObjectReference.Metadata().Templates.Find("ObjectTemplate") <> Undefined Then
		Template = CommonUse.ObjectManagerByRef(ObjectReference).GetTemplate("ObjectTemplate");
	Else
		Template = Undefined;
	EndIf;
	
	If Template = Undefined Then
		Section = SpreadsheetDocument.GetArea("R2");
		OutputTextToReport(SpreadsheetDocument, Section, "R2C2", ObjectReference.Metadata().Synonym, 16, True);
		
		SpreadsheetDocument.Area("C2").ColumnWidth = 30;
		If ObjectDescription.VersionNumber <> 0 Then
			OutputHeaderByVersion(SpreadsheetDocument, ObjectDescription.Definition, 4, 3);
			OutputHeaderByVersion(SpreadsheetDocument, ObjectDescription.Comment, 5, 3);
		EndIf;
		
		DisplayedRowsNumber = OutputAttributesByParsedObject(SpreadsheetDocument, ObjectDescription, ObjectReference);
		DisplayedRowsNumber = OutputTabularSectionsByParsedObject(SpreadsheetDocument, ObjectDescription, DisplayedRowsNumber + 7, ObjectReference);
	Else
		GenerateByBasicTemplate(SpreadsheetDocument, Template, ObjectDescription, ObjectDescription.Definition, ObjectReference);
	EndIf;
	
EndProcedure

// Creates a report for an object using the standard template.
//
// Parameters:
// ReportTS - SpreadsheetDocument - tabular document where the report will be output.
// ObjectVersioning - CatalogObject,DocumentObject - object which data shall be displayed in the report.
// ObjectDescription - String - description of an object by which.
//
Procedure GenerateByBasicTemplate(ReportTS, Template, ObjectVersioning, Val VersionDescription, ObjectReference) Export
	
	ObjectMetadata = ObjectReference.Metadata();
	
	ObjectDescription = ObjectMetadata.Name;
	
	ReportTS = New SpreadsheetDocument;
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(ObjectReference)) Then
		Template = Catalogs[ObjectDescription].GetTemplate("ObjectTemplate");
	Else
		Template = Documents[ObjectDescription].GetTemplate("ObjectTemplate");
	EndIf;
	
	// Title
	Area = Template.GetArea("Title");
	ReportTS.Put(Area);
	
	Area = ReportTS.GetArea("R3");
	SetTextProperties(Area.Area("R1C2"), VersionDescription, , True);
	ReportTS.Put(Area);
	
	Area = ReportTS.GetArea("R5");
	ReportTS.Put(Area);
	
	// Header
	Header = Template.GetArea("Header");
	Header.Parameters.Fill(ObjectVersioning);
	ReportTS.Put(Header);
	
	For Each MetadataTS IN ObjectMetadata.TabularSections Do
		If ObjectVersioning[MetadataTS.Name].Count() > 0 Then
			Area = Template.GetArea(MetadataTS.Name+"Header");
			ReportTS.Put(Area);
			
			AreaProductsReceiptDetails = Template.GetArea(MetadataTS.Name);
			For Each CurStringProductsReceiptDetails IN ObjectVersioning[MetadataTS.Name] Do
				AreaProductsReceiptDetails.Parameters.Fill(CurStringProductsReceiptDetails);
				ReportTS.Put(AreaProductsReceiptDetails);
			EndDo;
		EndIf;
	EndDo;
	
	ReportTS.ShowGrid = False;
	ReportTS.Protection = True;
	ReportTS.ReadOnly = True;
	ReportTS.ShowHeaders = False;
	
EndProcedure

// Displays the repor header during report by object version outputting.
//
Procedure OutputHeaderByVersion(ReportTS, Val Text, Val LineNumber, Val ColumnNumber)
	
	If Not IsBlankString(Text) Then
		
		ReportTS.Area("C"+String(ColumnNumber)).ColumnWidth = 50;
		
		Region = "R" + String(LineNumber) + "C"+String(ColumnNumber);
		ReportTS.Area(Region).Text = Text;
		ReportTS.Area(Region).BackColor = StyleColors.InaccessibleDataColor;
		ReportTS.Area(Region).Font = New Font(, 8, True, , , );
		ReportTS.Area(Region).TopBorder = New Line(SpreadsheetDocumentCellLineType.Solid);
		ReportTS.Area(Region).BottomBorder  = New Line(SpreadsheetDocumentCellLineType.Solid);
		ReportTS.Area(Region).LeftBorder  = New Line(SpreadsheetDocumentCellLineType.Solid);
		ReportTS.Area(Region).RightBorder = New Line(SpreadsheetDocumentCellLineType.Solid);
		
	EndIf;
	
EndProcedure

// Outputs the changed attributes into report. Thus it receives their presentation.
//
Function OutputAttributesByParsedObject(ReportTS, ObjectVersioning, ObjectReference) Export
	
	Section = ReportTS.GetArea("R6");
	OutputTextToReport(ReportTS, Section, "R1C1:R1C3", " ");
	OutputTextToReport(ReportTS, Section, "R1C2", "Attributes", 11, True);
	ReportTS.StartRowGroup("AttributesGroup");
	OutputTextToReport(ReportTS, Section, "R1C1:R1C3", " ");
	
	OutputRowsNumber = 0;
	
	For Each ItemAttribute IN ObjectVersioning.Attributes Do
		
		DescriptionAttribute = GetAttributePresentationInLanguage(ItemAttribute.DescriptionAttribute);
		
		AttributeFullName = ObjectReference.Metadata().Attributes.Find(DescriptionAttribute);
		
		If AttributeFullName = Undefined Then
			For Each StandardAttributeDescription IN ObjectReference.Metadata().StandardAttributes Do
				If StandardAttributeDescription.Name = DescriptionAttribute Then
					AttributeFullName = StandardAttributeDescription;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		AttributeValue = ?(ItemAttribute.AttributeValue = Undefined, "", ItemAttribute.AttributeValue);
		
		OutputDescription = DescriptionAttribute;
		If AttributeFullName <> Undefined Then
			OutputDescription = AttributeFullName.Presentation();
		EndIf;
		
		ValuePresentation = DetailsValuePresentation(AttributeValue, AttributeFullName);
		
		SetTextProperties(Section.Area("R1C2"), OutputDescription, , True);
		SetTextProperties(Section.Area("R1C3"), ValuePresentation);
		Section.Area("R1C2:R1C3").BottomBorder = New Line(SpreadsheetDocumentCellLineType.Solid, 1, 0);
		Section.Area("R1C2:R1C3").BorderColor = StyleColors.InaccessibleDataColor;
		
		ReportTS.Put(Section);
		
		OutputRowsNumber = OutputRowsNumber + 1;
	EndDo;
	
	ReportTS.EndRowGroup();
	
	Return OutputRowsNumber;
	
EndFunction

// Displays tabular sections by the parsed object when outputting a single object.
//
Function OutputTabularSectionsByParsedObject(ReportTS, ObjectVersioning, OutputLineNumber, ObjectReference) Export
	
	OutputRowsNumber = 0;
	
	If ObjectVersioning.TabularSections.Count() <> 0 Then
		
		For Each RowTabularSection IN ObjectVersioning.TabularSections Do
			TabularSectionDescription = RowTabularSection.Key;
			TabularSection             = RowTabularSection.Value;
			If TabularSection.Count() > 0 Then
				
				MetadataTS = ObjectReference.Metadata().TabularSections.Find(TabularSectionDescription);
				
				TSSynonym = TabularSectionDescription;
				If MetadataTS <> Undefined Then
					TSSynonym = MetadataTS.Presentation();
				EndIf;
				
				Section = ReportTS.GetArea("R" + String(OutputLineNumber));
				OutputTextToReport(ReportTS, Section, "R1C1:R1C100", " ");
				OutputArea = OutputTextToReport(ReportTS, Section, "R1C2", TSSynonym, 11, True);
				ReportTS.Area("R" + OutputArea.Top + "C2").CreateFormatOfRows();
				ReportTS.Area("R" + OutputArea.Top + "C2").ColumnWidth = Round(StrLen(TSSynonym)*2, 0, RoundMode.Round15as20);
				ReportTS.StartRowGroup("GroupRows");
				
				OutputTextToReport(ReportTS, Section, "R1C1:R1C3", " ");
				
				OutputRowsNumber = OutputRowsNumber + 1;
				
				OutputLineNumber = OutputLineNumber + 3;
				
				AddedTS = New SpreadsheetDocument;
				
				AddedTS.Join(GenerateEmptySector(TabularSection.Count()+1));
				
				ColumnNumber = 2;
				
				ColumnsDimensionMap = New Map;
				
				Section = New SpreadsheetDocument;
				SectionArea = Section.Area("R1C1");
				SetTextProperties(SectionArea, "N", , True, True);
				SectionArea.BackColor = StyleColors.InaccessibleDataColor;
				
				LineNumber = 1;
				For Each TabularSectionRow IN TabularSection Do
					LineNumber = LineNumber + 1;
					SetTextProperties(Section.Area("R" + LineNumber + "C1"), String(LineNumber-1), , False, True);
				EndDo;
				AddedTS.Join(Section);
				
				ColumnNumber = 3;
				
				For Each TabularSectionColumn IN TabularSection.Columns Do
					Section = New SpreadsheetDocument;
					FieldDescription = TabularSectionColumn.Name;
					
					FieldDetails = Undefined;
					If MetadataTS <> Undefined Then
						FieldDetails = MetadataTS.Attributes.Find(FieldDescription);
					EndIf;
					
					If FieldDetails = Undefined Or Not ValueIsFilled(FieldDetails.Synonym) Then
						OutputFieldDescription = FieldDescription;
					Else
						OutputFieldDescription = FieldDetails.Synonym;
					EndIf;
					ColumnHeaderColor = ?(FieldDetails = Undefined, StyleColors.DeletedAttributeTitleBackground, StyleColors.InaccessibleDataColor);
					AreaSection = Section.Area("R1C1");
					SetTextProperties(AreaSection, OutputFieldDescription, , True, True);
					AreaSection.BackColor = ColumnHeaderColor;
					ColumnsDimensionMap.Insert(ColumnNumber, StrLen(FieldDescription) + 4);
					LineNumber = 1;
					For Each TabularSectionRow IN TabularSection Do
						LineNumber = LineNumber + 1;
						Value = ?(TabularSectionRow[FieldDescription] = Undefined, "", TabularSectionRow[FieldDescription]);
						ValuePresentation = DetailsValuePresentation(Value, FieldDetails);
						
						SetTextProperties(Section.Area("R" + LineNumber + "C1"), ValuePresentation, , , True);
						If StrLen(ValuePresentation) > (ColumnsDimensionMap[ColumnNumber] - 4) Then
							ColumnsDimensionMap[ColumnNumber] = StrLen(ValuePresentation) + 4;
						EndIf;
					EndDo; // For Each TabularSectionRow Of TabularSection Cycle
					
					AddedTS.Join(Section);
					ColumnNumber = ColumnNumber + 1;
				EndDo; // For Each TabularSectionColumn From TabularSection.Columns Cycle
				
				OutputArea = ReportTS.Put(AddedTS);
				ReportTS.Area("R"+OutputArea.Top+"C1:R"+OutputArea.Bottom+"C"+ColumnNumber).CreateFormatOfRows();
				ReportTS.Area("R"+OutputArea.Top+"C2").ColumnWidth = 7;
				For CurrentColumnNumber = 3 To ColumnNumber-1 Do
					ReportTS.Area("R"+OutputArea.Top+"C"+CurrentColumnNumber).ColumnWidth = ColumnsDimensionMap[CurrentColumnNumber];
				EndDo;
				ReportTS.EndRowGroup();
				
			EndIf; // If TabularSection.Number() > 0 Then
		EndDo; // For Each RowTabularSection From ObjectVersion.TabularSections Cycle
		
	EndIf;
	
EndFunction

// Displays the text into the area of tabular document with a particular design.
//
Function OutputTextToReport(ReportTable, Val Section, Val Region, Val Text, Val Size = 9, Val Bold = False)
	
	SectionArea = Section.Area(Region);
	
	SectionArea.Text      = Text;
	SectionArea.Font      = New Font(, Size, Bold, , , );
	SectionArea.HorizontalAlign = HorizontalAlign.Left;
	
	SectionArea.TopBorder = New Line(SpreadsheetDocumentCellLineType.None);
	SectionArea.BottomBorder  = New Line(SpreadsheetDocumentCellLineType.None);
	SectionArea.LeftBorder  = New Line(SpreadsheetDocumentCellLineType.None);
	SectionArea.RightBorder = New Line(SpreadsheetDocumentCellLineType.None);
	
	Return ReportTable.Put(Section);
	
EndFunction

// Used for text output to the
// area of tabular document with conditional appearence.
//
Procedure SetTextProperties(SectionArea, Text, Val Size = 9, Val Bold = False, Val ShowBorders = False)
	
	SectionArea.Text = Text;
	SectionArea.Font = New Font(, Size, Bold, , , );
	
	If ShowBorders Then
		SectionArea.TopBorder = New Line(SpreadsheetDocumentCellLineType.Solid);
		SectionArea.BottomBorder  = New Line(SpreadsheetDocumentCellLineType.Solid);
		SectionArea.LeftBorder  = New Line(SpreadsheetDocumentCellLineType.Solid);
		SectionArea.RightBorder = New Line(SpreadsheetDocumentCellLineType.Solid);
		SectionArea.HorizontalAlign = HorizontalAlign.Center;
	EndIf;
	
EndProcedure

// Creates an empty sector for output into report. Used
// if the string was not changed in one of the versions.
//
Function GenerateEmptySector(Val RowCount, Val OutputType = "")
	
	FillValue = New Array;
	
	For IndexOf = 1 To RowCount Do
		FillValue.Add(" ");
	EndDo;
	
	Return GenerateTSRowSector(FillValue, OutputType);
	
EndFunction

// FillValue - array of rows.
// OutputType - String :
//           "and" - changing
//           "d" - addition
//           "u" - deletion
//           ""  - common terminal
Function GenerateTSRowSector(Val FillValue,Val OutputType = "")
	
	Common_Template = InformationRegisters.ObjectsVersions.GetTemplate("StandardTemplateOfObjectPresentation");
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	If      OutputType = ""  Then
		Pattern = Common_Template.GetArea("InitialAttributeValue");
	ElsIf OutputType = "AND" Then
		Pattern = Common_Template.GetArea("ModifiedAttributeValue");
	ElsIf OutputType = "D" Then
		Pattern = Common_Template.GetArea("AddedAttribute");
	ElsIf OutputType = "U" Then
		Pattern = Common_Template.GetArea("DeletedAttribute");
	EndIf;
	
	For Each AnotherValue IN FillValue Do
		Pattern.Parameters.AttributeValue = AnotherValue;
		SpreadsheetDocument.Put(Pattern);
	EndDo;
	
	Return SpreadsheetDocument;
	
EndFunction

Function DetailsValuePresentation(AttributeValue, MetadataObjectAttribute)
	
	FormatString = "";
	If MetadataObjectAttribute <> Undefined Then
		If TypeOf(AttributeValue) = Type("Date") Then
			FormatString = "DLF=DT";
			If MetadataObjectAttribute.Type.DateQualifiers.DateFractions = DateFractions.Date Then
				FormatString = "DLF=D";
			ElsIf MetadataObjectAttribute.Type.DateQualifiers.DateFractions = DateFractions.Time Then
				FormatString = "DLF=T";
			EndIf;
		EndIf;
	EndIf;
	
	Return Format(AttributeValue, FormatString);
	
EndFunction

Function VersionParsing(Ref, VersionNumber) Export
	
	InfoAboutVersions = InfoAboutObjectVersion(Ref, VersionNumber);
	
	Result = ParsingObjectXMLPresentation(InfoAboutVersions.ObjectVersioning, Ref);
	Result.Insert("ObjectName",     String(Ref));
	Result.Insert("AuthorOfChange", TrimAll(String(InfoAboutVersions.VersionAuthor)));
	Result.Insert("ChangeDate",  InfoAboutVersions.VersionDate);
	Result.Insert("Comment",    InfoAboutVersions.Comment);
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of SSL subsystems internal events.

// Fills the array with the list of metadata objects names that might include
// references to different metadata objects with these references ignored in the business-specific application logic
//
// Parameters:
//  Array       - array of strings for example "InformationRegister.ObjectsVersions".
//
Procedure OnAddExceptionsSearchLinks(Array) Export
	
	Array.Add(Metadata.InformationRegisters.ObjectsVersions.FullName());
	
EndProcedure

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see Description of the event handler WhenDataIsReceivedFromSecondary() in the syntax helper.
// 
Procedure OnReceiveDataFromSubordinate(DataItem, ItemReceive, SendBack, Sender) Export
	
	AddingInformationAboutVersionOfObjectInThe(DataItem, Sender);
	
EndProcedure

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see Description of event handler WhenDataIsReceivedFromMain() in syntax helper.
// 
Procedure OnReceiveDataFromMaster(DataItem, ItemReceive, SendBack, Sender) Export
	
	AddingInformationAboutVersionOfObjectInThe(DataItem, Sender);
	
EndProcedure

#EndRegion
