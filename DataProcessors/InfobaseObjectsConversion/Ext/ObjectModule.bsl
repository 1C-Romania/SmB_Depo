#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// USED VARIABLE NAME ABBREVIATIONS (ABBREVIATONS)
//
//  OCR  - objects conversion rule.
//  PCR  - object properties conversion rule.
//  PGCR - object properties group conversion rule.
//  VCR  - object values conversion rule.
//  DDR  - data export rule.
//  DCR  - data clearing rule.

////////////////////////////////////////////////////////////////////////////////
// EXPORT VARIABLES

Var EventLogMonitorMessageKey Export; // message string for writing errors to the events log monitor.
Var ExternalConnection Export; // Contains external connection global context or Undefined.
Var Queries Export; // Structure containing used queries.

////////////////////////////////////////////////////////////////////////////////
// HELPER MODULE VARIABLES FOR ALGORITHMS WRITING (COMMON FOR EXPORT AND UPLOAD)

Var Conversion; // Conversion properties structure (Name, Id, exchange event handlers).

Var Algorithms; // Structure containing used algorithms.
Var AdditionalInformationProcessors; // Structure containing used external data processors.

Var Rules; // Structure containing references to OCR.

Var Managers; // Match containing the fields Name, TypeName, RefTypeAsString, Manager, MDObject, ORC.
Var ManagersForExchangePlans;

Var AdditionalInformationProcessorParameters; // Structure containing parameters using external data processors.

Var ParametersInitialized; // If True, then required conversion parameters are initialized.

Var DataLogFile; // File for keeping data exchange protocol.
Var CommentObjectProcessingFlag;

////////////////////////////////////////////////////////////////////////////////
// HANDLERS DEBUG VARIABLES

Var ImportingHandling;
Var ImportProcessing;

////////////////////////////////////////////////////////////////////////////////
// CHECK BOX OF GLOBAL DATA PROCESSORS PRESENSE

Var HasBeforeObjectExportGlobalHandler;
Var HasAfterObjectExportGlobalHandler;

Var HasBeforeConvertObjectGlobalHandler;

Var HasBeforeObjectImportGlobalHandler;
Var HasAftertObjectImportGlobalHandler;

////////////////////////////////////////////////////////////////////////////////
// VARIABLES THAT ARE USED IN EXCHANGE HANDLERS (BOTH FOR IMPORT AND EXPORT)

Var StringType;                  // Type("String")
Var BooleanType;                  // Type("Boolean")
Var NumberType;                   // Type("Number")
Var DateType;                    // Type("Date")
Var UUIDType; // Type("UUID")
Var ValueStorageType;       // Type("ValueStorage")
Var BinaryDataType;          // Type("BinaryData")
Var AccumulationRecordTypeType;   // Type("AccrualMovementKind")
Var ObjectDeletionType;         // Type("ObjectRemoval")
Var AccountTypeKind;                // Type("AccountType")
Var TypeType;                     // Type("Type")
Var MapType;            // Type("Map").
Var String36Type;
Var String255Type;

Var MapRegisterType;

Var XMLNodeTypeEndElement;
Var XMLNodeTypeStartElement;
Var XMLNodeTypeText;

Var EmptyDateValue;

Var ErrorMessages; // Matching. Key - error code, Value - error description.

////////////////////////////////////////////////////////////////////////////////
// EXPORT DATA PROCESSOR MODULE VARIABLES
 
Var SnCounter;   // Number - NPP counter
Var WrittenToFileNPP;
Var PropertyConversionRuleTable;      // ValueTable - template to create table
                                            //                   structure by copying.
Var XMLRules;                           // Xml-String containing exchange rules description.
Var TypesForTargetString;
Var DocumentsForDeferredPostingField; // Values table for documents posting after data import.
Var DocumentsMatchForDeferredPosting; // Match for storing documents
                                                      // additional properties after data import.
Var FieldObjectsForPostponedRecording; // Match for writing objects of the reference types after data import.
Var ExchangeFile; // Consistently written/read exchange file.

////////////////////////////////////////////////////////////////////////////////
// VARIABLES OF UPLOAD DATA PROCESSOR MODULE
 
Var DeferredDocumentRegisterRecordCount;
Var ExchangeFileAttributes;       // Structure. After opening the file, it contains exchange file attributes according to the format.
Var LastSearchByRefNumber;
Var StoredExportedObjectCountByTypes;
Var AdditionalSearchParameterMap;
Var TypeAndObjectNameMap;
Var EmptyTypeValueMap;
Var TypeDescriptionMap;
Var ConversionRulesMap; // Match to determine object conversion rule by the object type.
Var MessageNumberField;
Var ReceivedMessageNumberField;
Var EnableDocumentPosting;
Var DataExportCallStack;
Var GlobalNotWrittenObjectStack;
Var DataMapForExportedItemUpdate;
Var DeferredDocumentActionExecutionStartDate;
Var DeferredDocumentActionExecutionEndDate;
Var EventsAfterParameterImport;
Var ObjectMappingRegisterManager;
Var CurrentNestingLevelExportByRule;
Var VisualExchangeSetupMode;
Var ExchangeRuleInfoImportMode;
Var SearchFieldInfoImportResultTable;
Var CustomSearchFieldInfoOnDataExport;
Var CustomSearchFieldInfoOnDataImport;
Var InfobaseObjectMappingQuery;
Var HasObjectChangeRecordDataAdjustment;
Var HasObjectChangeRecordData;

Var DataImportDataProcessorField;

////////////////////////////////////////////////////////////////////////////////
// VARIABLES FOR PROPERTY VALUES

Var ErrorFlagField;
Var ExchangeResultField;
Var DataExchangeStatusField;

Var ExchangeMessageDataTableField;  // Match with data value tables from exchange message; 
										 // Key - TypeName (String); Value - table with objects data (ValuesTable).
//
Var PackageHeaderDataTableField; // Values table with data from file of exchange messages pack title.
Var ErrorMessageStringField; // String - variable contains string with error message.
//
Var DataForImportTypeMapField;

Var ImportedObjectCounterField; // Imported objects counter.
Var ExportedObjectCounterField; // Exported objects counter.

Var ExchangeResultPrioritiesField; // Array - priorities of the data exchange from high to low.

Var ObjectPropertyDescriptionTableField; // Map: Key - MetadataObject; Value - ValueTable -
                                          // table of metadata object properties description.

Var ExportedByRefObjectsField; // Array of objects exported by reference. Array items are unique.
Var FieldObjectsCreatedAtImporting; // Array of objects created during export. Array items are unique.

Var ExportedByRefMetadataObjectsField; // Cache) Map: Key - MetadataObject; Value - shows
                                                // that object was exported by ref: True - you should export
                                                // object by ref, False - you should not.

Var ObjectChangeRecordRulesField; // Cache) ValuesTable - contains objects registration rules
                                      // (rules only with the "Allowed objects filter" kind for the current exchange plan).

Var ExchangePlanNameField;

Var ExchangePlanNodePropertyField;

Var IncomingExchangeMessageFormatVersionField;

////////////////////////////////////////////////////////////////////////////////
// EXPORT PROPERTIES

#Region ServiceProceduresAndFunctions

// Function-property: check box showing data exchange execution.
//
// Returns:
//  Boolean - check box of data exchange error.
//
Function ErrorFlag() Export
	
	If TypeOf(ErrorFlagField) <> Type("Boolean") Then
		
		ErrorFlagField = False;
		
	EndIf;
	
	Return ErrorFlagField;
	
EndFunction

// Function-property: result of the data exchange.
//
// Returns:
//  EnumRef.ExchangeExecutionResult - data exchange result.
//
Function ExchangeProcessResult() Export
	
	If TypeOf(ExchangeResultField) <> Type("EnumRef.ExchangeExecutionResult") Then
		
		ExchangeResultField = Enums.ExchangeExecutionResult.Completed;
		
	EndIf;
	
	Return ExchangeResultField;
	
EndFunction

// Function-property: result of the data exchange.
//
// Returns:
//  String - String presentation of the EnumRef.ExchangeExecutionResult enumeration value.
//
Function ExchangeExecutionResultString() Export
	
	Return CommonUse.NameOfEnumValue(ExchangeProcessResult());
	
EndFunction

// Function property: number of the data exchange received message.
//
// Returns:
//  Number - number of the data exchange received message.
//
Function ReceivedMessageNumber() Export
	
	If TypeOf(ReceivedMessageNumberField) <> Type("Number") Then
		
		ReceivedMessageNumberField = 0;
		
	EndIf;
	
	Return ReceivedMessageNumberField;
	
EndFunction

// Function-property: match to tables of the incoming message exchange data
//
// Returns:
//  Map - match with data tables of incoming exchange message.
//
Function DataTablesOfExchangeMessage() Export
	
	If TypeOf(ExchangeMessageDataTableField) <> Type("Map") Then
		
		ExchangeMessageDataTableField = New Map;
		
	EndIf;
	
	Return ExchangeMessageDataTableField;
	
EndFunction

// Function-property: values table with statistical and additional information about exchange incoming message.
//
// Returns:
//  ValueTable - values table with statistical and additional information about incoming exchange message.
//
Function DataTableOfPackageHeader() Export
	
	If TypeOf(PackageHeaderDataTableField) <> Type("ValueTable") Then
		
		PackageHeaderDataTableField = New ValueTable;
		
		Columns = PackageHeaderDataTableField.Columns;
		
		Columns.Add("ObjectTypeAsString",            deDescriptionType("String"));
		Columns.Add("ObjectsCountInSource", deDescriptionType("Number"));
		Columns.Add("SearchFields",                   deDescriptionType("String"));
		Columns.Add("TableFields",                  deDescriptionType("String"));
		
		Columns.Add("SourceTypeAsString", deDescriptionType("String"));
		Columns.Add("ReceiverTypeAsString", deDescriptionType("String"));
		
		Columns.Add("SynchronizeByID", deDescriptionType("Boolean"));
		Columns.Add("ThisIsObjectDeletion", deDescriptionType("Boolean"));
		Columns.Add("IsClassifier", deDescriptionType("Boolean"));
		Columns.Add("UsePreview", deDescriptionType("Boolean"));
		
	EndIf;
	
	Return PackageHeaderDataTableField;
	
EndFunction

// Function-property: row containing an error message on data exchange.
//
// Returns:
//  String - String containing a message on error occurred while data exchange.
//
Function ErrorMessageString() Export
	
	If TypeOf(ErrorMessageStringField) <> Type("String") Then
		
		ErrorMessageStringField = "";
		
	EndIf;
	
	Return ErrorMessageStringField;
	
EndFunction

// Function-property: quantity of objects that were imported.
//
// Returns:
//  Number - objects quantity that were imported.
//
Function CounterOfImportedObjects() Export
	
	If TypeOf(ImportedObjectCounterField) <> Type("Number") Then
		
		ImportedObjectCounterField = 0;
		
	EndIf;
	
	Return ImportedObjectCounterField;
	
EndFunction

// Function-property: quantity of objects that were exported.
//
// Returns:
//  Number - objects quantity that were exported.
//
Function DumpedObjectsCounter() Export
	
	If TypeOf(ExportedObjectCounterField) <> Type("Number") Then
		
		ExportedObjectCounterField = 0;
		
	EndIf;
	
	Return ExportedObjectCounterField;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROPERTIES

Function DataProcessorForDataImport()
	
	Return DataImportDataProcessorField;
	
EndFunction

Function IsExchangeOverExternalConnection()
	
	Return DataProcessorForDataImport() <> Undefined;
	
EndFunction

Function DataExchangeStatus()
	
	If TypeOf(DataExchangeStatusField) <> Type("Structure") Then
		
		DataExchangeStatusField = New Structure;
		DataExchangeStatusField.Insert("InfobaseNode");
		DataExchangeStatusField.Insert("ActionOnExchange");
		DataExchangeStatusField.Insert("ExchangeProcessResult");
		DataExchangeStatusField.Insert("StartDate");
		DataExchangeStatusField.Insert("EndDate");
		
	EndIf;
	
	Return DataExchangeStatusField;
	
EndFunction

Function MapOfDataTypesForImport()
	
	If TypeOf(DataForImportTypeMapField) <> Type("Map") Then
		
		DataForImportTypeMapField = New Map;
		
	EndIf;
	
	Return DataForImportTypeMapField;
	
EndFunction

Function DataImportToValueTableMode()
	
	Return Not DataImportToInformationBaseMode();
	
EndFunction

Function ColumnNameUUID()
	
	Return "UUID";
	
EndFunction

Function ColumnNameTypeAsString()
	
	Return "TypeAsString";
	
EndFunction

Function EventLogMonitorMessageKey()
	
	If TypeOf(EventLogMonitorMessageKey) <> Type("String")
		OR IsBlankString(EventLogMonitorMessageKey) Then
		
		EventLogMonitorMessageKey = DataExchangeServer.EventLogMonitorMessageTextDataExchange();
		
	EndIf;
	
	Return EventLogMonitorMessageKey;
EndFunction

Function PrioritiesOfExchangeResults()
	
	If TypeOf(ExchangeResultPrioritiesField) <> Type("Array") Then
		
		ExchangeResultPrioritiesField = New Array;
		ExchangeResultPrioritiesField.Add(Enums.ExchangeExecutionResult.Error);
		ExchangeResultPrioritiesField.Add(Enums.ExchangeExecutionResult.Error_MessageTransport);
		ExchangeResultPrioritiesField.Add(Enums.ExchangeExecutionResult.Canceled);
		ExchangeResultPrioritiesField.Add(Enums.ExchangeExecutionResult.Warning_ExchangeMessageHasBeenPreviouslyReceived);
		ExchangeResultPrioritiesField.Add(Enums.ExchangeExecutionResult.CompletedWithWarnings);
		ExchangeResultPrioritiesField.Add(Enums.ExchangeExecutionResult.Completed);
		ExchangeResultPrioritiesField.Add(Undefined);
		
	EndIf;
	
	Return ExchangeResultPrioritiesField;
EndFunction

Function TablesOfDescriptionsOfObjectProperties()
	
	If TypeOf(ObjectPropertyDescriptionTableField) <> Type("Map") Then
		
		ObjectPropertyDescriptionTableField = New Map;
		
	EndIf;
	
	Return ObjectPropertyDescriptionTableField;
EndFunction

Function AdditionalPropertiesForDeferredPosting()
	
	If TypeOf(DocumentsMatchForDeferredPosting) <> Type("Map") Then
		
		// Initialize match for the document deferred posting.
		DocumentsMatchForDeferredPosting = New Map;
		
	EndIf;
	
	Return DocumentsMatchForDeferredPosting;
	
EndFunction

Function ObjectsForPostponedRecording()
	
	If TypeOf(FieldObjectsForPostponedRecording) <> Type("Map") Then
		
		// Initialize match for the objects deferred writing.
		FieldObjectsForPostponedRecording = New Map;
		
	EndIf;
	
	Return FieldObjectsForPostponedRecording;
	
EndFunction

Function ExportedObjectsByRef()
	
	If TypeOf(ExportedByRefObjectsField) <> Type("Array") Then
		
		ExportedByRefObjectsField = New Array;
		
	EndIf;
	
	Return ExportedByRefObjectsField;
EndFunction

Function ObjectsCreatedAtImporting()
	
	If TypeOf(FieldObjectsCreatedAtImporting) <> Type("Array") Then
		
		FieldObjectsCreatedAtImporting = New Array;
		
	EndIf;
	
	Return FieldObjectsCreatedAtImporting;
EndFunction

Function MetadataObjectsToExportByRef()
	
	If TypeOf(ExportedByRefMetadataObjectsField) <> Type("Map") Then
		
		ExportedByRefMetadataObjectsField = New Map;
		
	EndIf;
	
	Return ExportedByRefMetadataObjectsField;
EndFunction

Function ExportObjectByRef(Object, ExchangePlanNode)
	
	MetadataObject = Metadata.FindByType(TypeOf(Object));
	
	If MetadataObject = Undefined Then
		Return False;
	EndIf;
	
	// get value from cache
	Result = MetadataObjectsToExportByRef().Get(MetadataObject);
	
	If Result = Undefined Then
		
		Result = False;
		
		// Get a flag showing export by reference.
		Filter = New Structure("MetadataObjectName", MetadataObject.FullName());
		
		RuleArray = ObjectRegistrationRules(ExchangePlanNode).FindRows(Filter);
		
		For Each Rule IN RuleArray Do
			
			If Not IsBlankString(Rule.FlagAttributeName) Then
				
				FlagAttributeValue = Undefined;
				ExchangePlanNodeProperties(ExchangePlanNode).Property(Rule.FlagAttributeName, FlagAttributeValue);
				
				Result = Result OR ( FlagAttributeValue = Enums.ExchangeObjectsExportModes.ExportIfNecessary
										OR FlagAttributeValue = Enums.ExchangeObjectsExportModes.EmptyRef());
				//
				If Result Then
					Break;
				EndIf;
				
			EndIf;
			
		EndDo;
		
		// Save the final value to cache.
		MetadataObjectsToExportByRef().Insert(MetadataObject, Result);
		
	EndIf;
	
	Return Result;
EndFunction

Function ExchangePlanName()
	
	If TypeOf(ExchangePlanNameField) <> Type("String")
		OR IsBlankString(ExchangePlanNameField) Then
		
		If ValueIsFilled(NodeForExchange) Then
			
			ExchangePlanNameField = DataExchangeReUse.GetExchangePlanName(NodeForExchange);
			
		ElsIf ValueIsFilled(ExchangeNodeForDataImport) Then
			
			ExchangePlanNameField = DataExchangeReUse.GetExchangePlanName(ExchangeNodeForDataImport);
			
		ElsIf ValueIsFilled(ExchangePlanNameVRO) Then
			
			ExchangePlanNameField = ExchangePlanNameVRO;
			
		Else
			
			ExchangePlanNameField = "";
			
		EndIf;
		
	EndIf;
	
	Return ExchangePlanNameField;
EndFunction

Function ExchangePlanNodeProperties(Node)
	
	If TypeOf(ExchangePlanNodePropertyField) <> Type("Structure") Then
		
		ExchangePlanNodePropertyField = New Structure;
		
		// get names of the attributes
		AttributeNames = CommonUse.NamesOfAttributesByType(Node, Type("EnumRef.ExchangeObjectsExportModes"));
		
		// Get the attributes values.
		If Not IsBlankString(AttributeNames) Then
			
			ExchangePlanNodePropertyField = CommonUse.ObjectAttributesValues(Node, AttributeNames);
			
		EndIf;
		
	EndIf;
	
	Return ExchangePlanNodePropertyField;
EndFunction

Function VersionOfIncomeExchangeEventFormat()
	
	If TypeOf(IncomingExchangeMessageFormatVersionField) <> Type("String") Then
		
		IncomingExchangeMessageFormatVersionField = "0.0.0.0";
		
	EndIf;
	
	// Expand version of the incoming message format up to 4 digits.
	VersionDigits = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(IncomingExchangeMessageFormatVersionField, ".");
	
	If VersionDigits.Count() < 4 Then
		
		DigitCountAdd = 4 - VersionDigits.Count();
		
		For A = 1 To DigitCountAdd Do
			
			VersionDigits.Add("0");
			
		EndDo;
		
		IncomingExchangeMessageFormatVersionField = StringFunctionsClientServer.RowFromArraySubrows(VersionDigits, ".");
		
	EndIf;
	
	Return IncomingExchangeMessageFormatVersionField;
EndFunction

Function MessageNo()
	
	If TypeOf(MessageNumberField) <> Type("Number") Then
		
		MessageNumberField = 0;
		
	EndIf;
	
	Return MessageNumberField;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// CACHING FUNCTIONS

Function TableOfDescriptionOfObjectProperties(MetadataObject)
	
	Result = TablesOfDescriptionsOfObjectProperties().Get(MetadataObject);
	
	If Result = Undefined Then
		
		Result = CommonUse.GetTableOfDescriptionOfObjectProperties(MetadataObject, "Name");
		
		TablesOfDescriptionsOfObjectProperties().Insert(Result);
		
	EndIf;
	
	Return Result;
EndFunction

Function ObjectRegistrationRules(ExchangePlanNode)
	
	If TypeOf(ObjectChangeRecordRulesField) <> Type("ValueTable") Then
		
		ObjectRegistrationRules = DataExchangeServerCall.SessionParametersObjectRegistrationRules().Get();
		
		Filter = New Structure;
		Filter.Insert("ExchangePlanName", DataExchangeReUse.GetExchangePlanName(ExchangePlanNode));
		
		ObjectChangeRecordRulesField = ObjectRegistrationRules.Copy(Filter, "MetadataObjectName, CheckBoxAttributeName");
		ObjectChangeRecordRulesField.Indexes.Add("MetadataObjectName");
		
	EndIf;
	
	Return ObjectChangeRecordRulesField;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// EXPORT PROCEDURES AND FUNCTIONS

// DATA EXPORT

// Data is
// exported -- All objects are exported to one file.
// -- The following data is exported to the file title:
//  - exchange rules
//  - information about data types
//  - data on exchange (exchange plan name, node codes, message numbers (handshaking)).
//
// Parameters:
// 
Procedure ExecuteDataExport(DataProcessorForDataImport = Undefined) Export
	
	SetFlagOfError(False);
	
	ErrorMessageStringField = "";
	DataExchangeStatusField = Undefined;
	ExchangeResultField = Undefined;
	ExportedByRefObjectsField = Undefined;
	FieldObjectsCreatedAtImporting = Undefined;
	ExportedByRefMetadataObjectsField = Undefined;
	ObjectChangeRecordRulesField = Undefined;
	ExchangePlanNodePropertyField = Undefined;
	DataImportDataProcessorField = DataProcessorForDataImport;
	
	ExchangeProtocolInitialization();
	
	// Open an exchange file
	If IsExchangeOverExternalConnection() Then
		ExchangeFile = New TextWriter;
	Else
		OpenExportFile();
	EndIf;
	
	If ErrorFlag() Then
		ExchangeFile = Undefined;
		FinishExchangeProtocolLogging();
		Return;
	EndIf;
	
	SecurityProfileName = InitializeHandlings();
	
	If SecurityProfileName <> Undefined Then
		SetSafeMode(SecurityProfileName);
	EndIf;
	
	If IsExchangeOverExternalConnection() Then
		
		DataProcessorForDataImport().ExternalConnectionBeforeDataImport();
		
		DataProcessorForDataImport().ImportExchangeRules(XMLRules, "String");
		
		If DataProcessorForDataImport().ErrorFlag() Then
			
			MessageString = NStr("en='OUTER JOIN: %1';ru='ВНЕШНЕЕ СОЕДИНЕНИЕ: %1'");
			MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, DataProcessorForDataImport().ErrorMessageString());
			WriteInExecutionProtocol(MessageString);
			FinishExchangeProtocolLogging();
			Return;
			
		EndIf;
		
		Cancel = False;
		
		DataProcessorForDataImport().ExternalConnectionConversionHandlerBeforeDataImport(Cancel);
		
		If Cancel Then
			FinishExchangeProtocolLogging();
			DisableDataProcessorForDebug();
			Return;
		EndIf;
		
	Else
		
		// Include exchange rules to file.
		ExchangeFile.WriteLine(XMLRules);
		
	EndIf;
	
	// DATA EXPORT
	Try
		RunExport();
	Except
		WriteInExecutionProtocol(DetailErrorDescription(ErrorInfo()));
		FinishExchangeProtocolLogging();
		ExchangeFile = Undefined;
		ExportedByRefObjectsField = Undefined;
		FieldObjectsCreatedAtImporting = Undefined;
		ExportedByRefMetadataObjectsField = Undefined;
		Return;
	EndTry;
	
	If IsExchangeOverExternalConnection() Then
		
		If Not ErrorFlag() Then
			
			DataProcessorForDataImport().ExternalConnectionAfterDataImport();
			
		EndIf;
		
	Else
		
		// Close exchange file
		CloseFile();
		
	EndIf;
	
	FinishExchangeProtocolLogging();
	
	// Reset modal variables before putting data processor to platform cache.
	ExportedByRefObjectsField = Undefined;
	FieldObjectsCreatedAtImporting = Undefined;
	ExportedByRefMetadataObjectsField = Undefined;
	DisableDataProcessorForDebug();
	ExchangeFile = Undefined;
	
EndProcedure

// DATA UPLOAD

// Imports data from message exchange file.
// Data is being imported to the infobase.
//
// Parameters:
// 
Procedure ExecuteDataImport() Export
	
	MessageReader = Undefined;
	Try
		
		DataImportMode = "ImportToInfobase";
		
		ErrorMessageStringField = "";
		DataExchangeStatusField = Undefined;
		ExchangeResultField = Undefined;
		DataForImportTypeMapField = Undefined;
		ImportedObjectCounterField = Undefined;
		DocumentsForDeferredPostingField = Undefined;
		FieldObjectsForPostponedRecording = Undefined;
		DocumentsMatchForDeferredPosting = Undefined;
		ExchangePlanNodePropertyField = Undefined;
		IncomingExchangeMessageFormatVersionField = Undefined;
		HasObjectChangeRecordDataAdjustment = False;
		HasObjectChangeRecordData = False;
		
		GlobalNotWrittenObjectStack = New Map;
		LastSearchByRefNumber = 0;
		
		InitializeManagersAndMessages();
		
		SetFlagOfError(False);
		
		InitializeCommentsOnDumpAndDataExport();
		
		ExchangeProtocolInitialization();
		
		CustomSearchFieldInfoOnDataImport = New Map;
		
		AdditionalSearchParameterMap = New Map;
		ConversionRulesMap = New Map;
		
		DeferredDocumentRegisterRecordCount = 0;
		
		If ContinueOnError Then
			UseTransactions = False;
		EndIf;
		
		If CountProcessedObjectsForRefreshStatus = 0 Then
			CountProcessedObjectsForRefreshStatus = 100;
		EndIf;
		
		SecurityProfileName = InitializeHandlings();
		
		If SecurityProfileName <> Undefined Then
			SetSafeMode(SecurityProfileName);
		EndIf;
		
		StartMessageReader(MessageReader);
		
		If UseTransactions Then
			BeginTransaction();
		EndIf;
		Try
			
			ReadData(MessageReader);
			
			If ErrorFlag() Then
				Raise NStr("en='Errors have occurred at the data import.';ru='Возникли ошибки при загрузке данных.'");
			EndIf;
			
			// Deferred record of things that were not written.
			WriteNotRecordedObjects();
			
			If ErrorFlag() Then
				Raise NStr("en='Errors have occurred at the data import.';ru='Возникли ошибки при загрузке данных.'");
			EndIf;
			
			FinishMessageReading(MessageReader);
			
			If UseTransactions Then
				CommitTransaction();
			EndIf;
		Except
			If UseTransactions Then
				RollbackTransaction();
			EndIf;
			AbortMessageReading(MessageReader);
			Raise;
		EndTry;
		
		// Post documents in the queue.
		RunDelayedDocumentPosting();
		PerformPostponedObjectsRecording();
		
	Except
		If MessageReader <> Undefined
			AND MessageReader.MessageWasAcceptedPreviously Then
			WriteInExecutionProtocol(174,,,,,,
				Enums.ExchangeExecutionResult.Warning_ExchangeMessageHasBeenPreviouslyReceived
			);
		Else
			WriteInExecutionProtocol(DetailErrorDescription(ErrorInfo()));
		EndIf;
	EndTry;
	
	FinishExchangeProtocolLogging();
	
	// Reset modal variables before putting data processor to platform cache.
	DocumentsForDeferredPostingField = Undefined;
	FieldObjectsForPostponedRecording = Undefined;
	DocumentsMatchForDeferredPosting = Undefined;
	DataForImportTypeMapField = Undefined;
	GlobalNotWrittenObjectStack = Undefined;
	ConversionRulesMap = Undefined;
	DisableDataProcessorForDebug();
	ExchangeFile = Undefined;
	
EndProcedure

// PACK DATA UPLOAD

// Imports data from an exchange message file to the Infobase of only specified objects types.
// 
// Parameters:
//  TableToImport - Array - array of types that need to be imported from the exchange message; an array item -
//                                Row.
//  For example, to import only the Counterparties catalog items from an exchange message:
//   TablesForImport = New Array;
//   TableForImport.Add(CatalogRef.Counterparties);
// 
//  List of all types that the current exchange
//  message contains can be received by calling the ExecuteExchangeMessageAnalysis() procedure.
// 
Procedure ExecuteDataImportToInformationBase(TableToImport) Export
	
	DataImportMode = "ImportToInfobase";
	DataExchangeStatusField = Undefined;
	ExchangeResultField = Undefined;
	DocumentsForDeferredPostingField = Undefined;
	FieldObjectsForPostponedRecording = Undefined;
	DocumentsMatchForDeferredPosting = Undefined;
	ExchangePlanNodePropertyField = Undefined;
	IncomingExchangeMessageFormatVersionField = Undefined;
	HasObjectChangeRecordDataAdjustment = False;
	HasObjectChangeRecordData = False;
	GlobalNotWrittenObjectStack = New Map;
	ConversionRulesMap = New Map;
	
	// import start date
	DataExchangeStatus().StartDate = CurrentSessionDate();
	
	// Record in the events log monitor.
	MessageString = NStr("en='Beginning of data exchange process for node: %1';ru='Начало процесса обмена данными для узла: %1'", CommonUseClientServer.MainLanguageCode());
	MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, String(ExchangeNodeForDataImport));
	WriteLogEventDataExchange(MessageString, EventLogLevel.Information);
	
	ExecuteSelectiveMessageReader(TableToImport);
	
	// import end date
	DataExchangeStatus().EndDate = CurrentSessionDate();
	
	// Write data import end to IR.
	FixEndOfDataImport();
	
	// Record in the events log monitor.
	MessageString = NStr("en='%1, %2; Processed %3 objects';ru='%1, %2; Обработано %3 объектов'", CommonUseClientServer.MainLanguageCode());
	MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString,
					ExchangeProcessResult(),
					Enums.ActionsAtExchange.DataImport,
					Format(CounterOfImportedObjects(), "NG=0"));
	//
	WriteLogEventDataExchange(MessageString, EventLogLevel.Information);
	
	// Reset modal variables before putting data processor to platform cache.
	DocumentsForDeferredPostingField = Undefined;
	FieldObjectsForPostponedRecording = Undefined;
	DocumentsMatchForDeferredPosting = Undefined;
	DataForImportTypeMapField = Undefined;
	GlobalNotWrittenObjectStack = Undefined;
	ConversionRulesMap = Undefined;
	ExchangeFile = Undefined;
	
EndProcedure

// Imports data from an exchange message file to the Values table of only specified objects types.
// 
// Parameters:
//  TableToImport - Array - array of types that need to be imported from the exchange message; an array item -
//                                Row.
//  For example, to import only the Counterparties catalog items from an exchange message:
//   TablesForImport = New Array;
//   TableForImport.Add(CatalogRef.Counterparties);
// 
//  List of all types that the current exchange
//  message contains can be received by calling the ExecuteExchangeMessageAnalysis() procedure.
// 
Procedure ExecuteDataImportToValueTable(TableToImport) Export
	
	DataImportMode = "ImportToValueTable";
	DataExchangeStatusField = Undefined;
	ExchangeResultField = Undefined;
	DocumentsForDeferredPostingField = Undefined;
	FieldObjectsForPostponedRecording = Undefined;
	DocumentsMatchForDeferredPosting = Undefined;
	ExchangePlanNodePropertyField = Undefined;
	IncomingExchangeMessageFormatVersionField = Undefined;
	HasObjectChangeRecordDataAdjustment = False;
	HasObjectChangeRecordData = False;
	GlobalNotWrittenObjectStack = New Map;
	ConversionRulesMap = New Map;
	
	UseTransactions = False;
	
	// Initialize table of exchange message data.
	For Each DataTableKey IN TableToImport Do
		
		SubstringArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(DataTableKey, "#");
		
		ObjectType = SubstringArray[1];
		
		DataTablesOfExchangeMessage().Insert(DataTableKey, InitializationOfTableOfDataOfExchangeMessage(Type(ObjectType)));
		
	EndDo;
	
	ExecuteSelectiveMessageReader(TableToImport);
	
	// Reset modal variables before putting data processor to platform cache.
	DocumentsForDeferredPostingField = Undefined;
	FieldObjectsForPostponedRecording = Undefined;
	DocumentsMatchForDeferredPosting = Undefined;
	DataForImportTypeMapField = Undefined;
	GlobalNotWrittenObjectStack = Undefined;
	ConversionRulesMap = Undefined;
	ExchangeFile = Undefined;
	
EndProcedure

// Sequentially reads exchange message file and when it is happening:
//     - registration of changes by an incoming receipt number is deleted
//     - exchange rules are being imported
//     - information about data types is being imported
//     - read information of the data match and write and IB
//     - information about objects types and their quantity is collected.
//
// Parameters:
//     AnalysisParameters - Structure. Optional additional analysis parameters. Allowed fields:
//         * CollectClassifiersStatistics - Boolean - Check box showing that data by classifiers will
//                                                        be included in the statistics.
//                                                        Classifiers are catalogs, CCT, chart
//                                                        of accounts, CTC in which SynchronizeByIdentifier check
//                                                        boxes are selected in OCR. and
//                                                        ContinueSearchBySearchFieldsIfNotFindyID.
// 
Procedure RunExchangeMessageAnalysis(AnalysisParameters = Undefined) Export
	
	MessageReader = Undefined;
	Try
		
		SetFlagOfError(False);
		
		UseTransactions = False;
		
		ErrorMessageStringField = "";
		DataExchangeStatusField = Undefined;
		ExchangeResultField = Undefined;
		IncomingExchangeMessageFormatVersionField = Undefined;
		HasObjectChangeRecordDataAdjustment = False;
		HasObjectChangeRecordData = False;
		GlobalNotWrittenObjectStack = New Map;
		ConversionRulesMap = New Map;
		
		ExchangeProtocolInitialization();
		
		InitializeManagersAndMessages();
		
		// analysis begin date
		DataExchangeStatus().StartDate = CurrentSessionDate();
		
		// Null modal variable value.
		PackageHeaderDataTableField = Undefined;
		
		StartMessageReader(MessageReader, True);
		Try
			
			// Read data from an exchange message.
			ReadDataInAnalysisMode(MessageReader, AnalysisParameters);
			
			If ErrorFlag() Then
				Raise NStr("en='The errors occurred when analysing the data.';ru='Возникли ошибки при анализе данных.'");
			EndIf;
			
			// Generate a temporary data table.
			TemporaryPackageHeaderDataTable = DataTableOfPackageHeader().Copy(, "SourceTypeAsString, ReceiverTypeAsString, SearchField, TableFields");
			TemporaryPackageHeaderDataTable.GroupBy("SourceTypeAsString, ReceiverTypeAsString, SearchField, TableFields");
			
			// Collapse table of pack title data.
			DataTableOfPackageHeader().GroupBy(
				"ObjectTypeAsString, SourceTypeAsString, ReceiverTypeAsString, SynchronizeByID, IsClassifier, IsObjectDeletion, UsePreview",
				"ObjectsCountInSource");
			//
			DataTableOfPackageHeader().Columns.Add("SearchFields",  deDescriptionType("String"));
			DataTableOfPackageHeader().Columns.Add("TableFields", deDescriptionType("String"));
			
			For Each TableRow IN DataTableOfPackageHeader() Do
				
				Filter = New Structure;
				Filter.Insert("SourceTypeAsString", TableRow.SourceTypeAsString);
				Filter.Insert("ReceiverTypeAsString", TableRow.ReceiverTypeAsString);
				
				TemporaryTableRows = TemporaryPackageHeaderDataTable.FindRows(Filter);
				
				TableRow.SearchFields  = TemporaryTableRows[0].SearchFields;
				TableRow.TableFields = TemporaryTableRows[0].TableFields;
				
			EndDo;
			
			FinishMessageReading(MessageReader);
			
		Except
			AbortMessageReading(MessageReader);
			Raise;
		EndTry;
		
	Except
		If MessageReader <> Undefined
			AND MessageReader.MessageWasAcceptedPreviously Then
			WriteInExecutionProtocol(174,,,,,,
				Enums.ExchangeExecutionResult.Warning_ExchangeMessageHasBeenPreviouslyReceived
			);
		Else
			WriteInExecutionProtocol(DetailErrorDescription(ErrorInfo()));
		EndIf;
		
	EndTry;
	
	FinishExchangeProtocolLogging();
	
	// analysis end date
	DataExchangeStatus().EndDate = CurrentSessionDate();
	
	// Write data analysis end to IR.
	FixEndOfDataImport();
	
	// Reset modal variables before putting data processor to platform cache.
	DocumentsForDeferredPostingField = Undefined;
	FieldObjectsForPostponedRecording = Undefined;
	DocumentsMatchForDeferredPosting = Undefined;
	DataForImportTypeMapField = Undefined;
	GlobalNotWrittenObjectStack = Undefined;
	ConversionRulesMap = Undefined;
	ExchangeFile = Undefined;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF EXTERNAL CONNECTION EVENTS DATA PROCESSOR

// Imports data from XML string.
//
Procedure ExternalConnectionImportDataFromXMLString(XMLString) Export
	
	ExchangeFile.SetString(XMLString);
	
	MessageReader = Undefined;
	Try
		
		ReadDataInModeExternalConnection(MessageReader);
		
	Except
		
		If MessageReader <> Undefined
			AND MessageReader.MessageWasAcceptedPreviously Then
			WriteInExecutionProtocol(174,,,,,,
				Enums.ExchangeExecutionResult.Warning_ExchangeMessageHasBeenPreviouslyReceived
			);
		Else
			WriteInExecutionProtocol(DetailErrorDescription(ErrorInfo()));
		EndIf;
		
	EndTry;
	
EndProcedure

// Executes conversion handler Before data import for an external connection.
//
Procedure ExternalConnectionConversionHandlerBeforeDataImport(Cancel) Export
	
	// {Handler: BeforeDataImport} Start
	If Not IsBlankString(Conversion.BeforeDataImport) Then
		
		Try
			
			If DebuggingImportHandlers Then
				
				ExecuteHandler_Conversion_BeforeDataImport(ExchangeFile, Cancel);
				
			Else
				
				Execute(Conversion.BeforeDataImport);
				
			EndIf;
			
		Except
			WriteInformationAboutErrorConversionHandlers(22, ErrorDescription(), NStr("en='BeforeDataImport (Conversion)';ru='ПередЗагрузкойДанных (конвертация)'"));
			Cancel = True;
		EndTry;
		
	EndIf;
	
	If Cancel Then // Denial of the data import
		Return;
	EndIf;
	// {Handler: BeforeDataImport} End
	
EndProcedure

// Initialization procedure before data import via an external connection.
//
Procedure ExternalConnectionBeforeDataImport() Export
	
	DataImportMode = "ImportToInfobase";
	
	ErrorMessageStringField = "";
	DataExchangeStatusField = Undefined;
	ExchangeResultField = Undefined;
	DataForImportTypeMapField = Undefined;
	ImportedObjectCounterField = Undefined;
	DocumentsForDeferredPostingField = Undefined;
	FieldObjectsForPostponedRecording = Undefined;
	DocumentsMatchForDeferredPosting = Undefined;
	ExchangePlanNodePropertyField = Undefined;
	IncomingExchangeMessageFormatVersionField = Undefined;
	
	GlobalNotWrittenObjectStack = New Map;
	LastSearchByRefNumber = 0;
	
	InitializeManagersAndMessages();
	
	SetFlagOfError(False);
	
	InitializeCommentsOnDumpAndDataExport();
	
	ExchangeProtocolInitialization();
	
	CustomSearchFieldInfoOnDataImport = New Map;
	
	AdditionalSearchParameterMap = New Map;
	ConversionRulesMap = New Map;
	
	DeferredDocumentRegisterRecordCount = 0;
	
	If CountProcessedObjectsForRefreshStatus = 0 Then
		CountProcessedObjectsForRefreshStatus = 100;
	EndIf;
	
	// Clear exchange rules.
	Rules.Clear();
	ConversionRulesTable.Clear();
	
	ExchangeFile = New XMLReader;
	
	HasObjectChangeRecordData = False;
	HasObjectChangeRecordDataAdjustment = False;
	
EndProcedure

// Executes handler After data import.
// Resets variables and executes deferred documents posting and objects writing.
//
Procedure ExternalConnectionAfterDataImport() Export
	
	// Deferred record of things that were not written.
	WriteNotRecordedObjects();
	
	// Handler AfterDataImport
	If Not ErrorFlag() Then
		
		If Not IsBlankString(Conversion.AfterDataImport) Then
			
			Try
				
				If DebuggingImportHandlers Then
					
					ExecuteHandler_Conversion_AfterDataImport();
					
				Else
					
					Execute(Conversion.AfterDataImport);
					
				EndIf;
				
			Except
				WriteInformationAboutErrorConversionHandlers(23, ErrorDescription(), NStr("en='AfterDataImport (conversion)';ru='ПослеЗагрузкиДанных (конвертация)'"));
			EndTry;
			
		EndIf;
		
	EndIf;
	
	If Not ErrorFlag() Then
		
		// Post documents in the queue.
		RunDelayedDocumentPosting();
		PerformPostponedObjectsRecording();
		
		// Write information about an incoming message number.
		NodeObject = ExchangeNodeForDataImport.GetObject();
		NodeObject.ReceivedNo = MessageNo();
		NodeObject.DataExchange.Load = True;
		
		Try
			NodeObject.Lock();
		Except
			WriteInformationAboutErrorToProtocol(173, BriefErrorDescription(ErrorInfo()), NodeObject);
		EndTry;
		
	EndIf;
	
	If Not ErrorFlag() Then
		
		NodeObject.Write();
		
		If HasObjectChangeRecordDataAdjustment = True Then
			
			InformationRegisters.InfobasesNodesCommonSettings.CommitCorrectionExecutionOfInformationMatchingUnconditionally(ExchangeNodeForDataImport);
			
		EndIf;
		
		If HasObjectChangeRecordData = True Then
			
			InformationRegisters.InfobasesObjectsCompliance.DeleteOutdatedExportModeRecordsByRef(ExchangeNodeForDataImport);
			
		EndIf;
		
	EndIf;
	
	FinishExchangeProtocolLogging();
	
	// Reset modal variables before putting data processor to platform cache.
	DocumentsForDeferredPostingField = Undefined;
	FieldObjectsForPostponedRecording = Undefined;
	DocumentsMatchForDeferredPosting = Undefined;
	DataForImportTypeMapField = Undefined;
	GlobalNotWrittenObjectStack = Undefined;
	ExchangeFile = Undefined;
	
EndProcedure

// Opens new transaction.
//
Procedure ExternalConnectionCheckTransactionStartAndCommitOnDataImport() Export
	
	If UseTransactions
		AND ObjectsCountForTransactions > 0
		AND CounterOfImportedObjects() % ObjectsCountForTransactions = 0 Then
		
		CommitTransaction();
		BeginTransaction();
		
	EndIf;
	
EndProcedure

// Opens transaction for exchange via an external connection if needed.
//
Procedure ExternalConnectionBeginTransactionOnDataImport() Export
	
	If UseTransactions Then
		BeginTransaction();
	EndIf;
	
EndProcedure

// Ends transaction during the exchange via an external connection (if import was executed in transaction).
//
Procedure ExternalConnectionCommitTransactionOnDataImport() Export
	
	If UseTransactions Then
		
		If ErrorFlag() Then
			RollbackTransaction();
		Else
			CommitTransaction();
		EndIf;
		
	EndIf;
	
EndProcedure

// Cancels transaction while exchanging via an external connection.
//
Procedure ExternalConnectionRollbackTransactionOnDataImport() Export
	
	While TransactionActive() Do
		RollbackTransaction();
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS USED IN EVENT HANDLERS

// Creates record on object deletion in the exchange file.
//
// Parameters:
// Ref - Ref to the deleted object.
// ReceiverType - String - Contains row presentation of the receiver type.
// SourceType - String - Contains row presentation of the source type.
// 
Procedure WriteToFileObjectDeletion(Ref, Val ReceiverType, Val SourceType) Export
	
	Receiver = CreateNode("ObjectDeletion");
	
	SetAttribute(Receiver, "ReceiverType", ReceiverType);
	SetAttribute(Receiver, "SourceType", SourceType);
	
	SetAttribute(Receiver, "UUID", Ref.UUID());
	
	Receiver.WriteEndElement(); // ObjectDeletion
	
	WriteToFile(Receiver);
	
	IncreaseExportedObjectsCounter();
	
EndProcedure

// Registers object created while export.
//
// Parameters:
// Ref - Ref to the registered object.
// 
Procedure RegisterObjectCreatedAtImporting(Ref) Export
	
	If ObjectsCreatedAtImporting().Find(Ref) = Undefined Then
		
		ObjectsCreatedAtImporting().Add(Ref);
		
	EndIf;
	
EndProcedure

// Registers warning in the events log monitor.
// If while data exchange there is a call to this procedure, the data exchange will not be stopped.
// After the exchange is complete, exchange execution status in the monitor for a
// user will have "Warning" value if there were no errors.
//
// Parameters:
//  Warning - String. Warning text that should be registered.
// Information, warnings and errors occurred during data exchange are registered in the events log monitor.
// 
Procedure RegisterWarning(Warning) Export
	
	WriteInExecutionProtocol(Warning,,False,,,, Enums.ExchangeExecutionResult.CompletedWithWarnings);
	
EndProcedure

// Shows that this is an import to the infobase.
// 
// Returns:
// Boolean - Shows that there is data import mode.
// 
Function DataImportToInformationBaseMode() Export
	
	Return IsBlankString(DataImportMode) OR Upper(DataImportMode) = Upper("ImportToInfobase");
	
EndFunction

// Writes an object into the infobase.
//
// Parameters:
// Object - Written object.
// Type - String - String object type.
// 
Procedure WriteObjectToIB(Object, Type, WriteObject = False, Val SendBack = False) Export
	
	// Do not write objects to the import mode.
	If DataImportToValueTableMode() Then
		Return;
	EndIf;
		
	If CommonUseReUse.DataSeparationEnabled()
		AND CommonUseReUse.CanUseSeparatedData()
		AND Not CommonUseReUse.IsSeparatedMetadataObject(Object.Metadata().FullName(), CommonUseReUse.MainDataSeparator())
		AND Not CommonUseReUse.IsSeparatedMetadataObject(Object.Metadata().FullName(), CommonUseReUse.SupportDataSplitter()) Then
		
		ErrorMessageString = NStr("en='Attempt of undivided data modification (%1) in separated session.';ru='Попытка изменения неразделенных данных (%1) в разделенном сеансе.'");
		ErrorMessageString = StringFunctionsClientServer.PlaceParametersIntoString(ErrorMessageString, Object.Metadata().FullName());
		
		WriteInExecutionProtocol(ErrorMessageString,, False,,,, Enums.ExchangeExecutionResult.CompletedWithWarnings);
		
		Return;
		
	EndIf;
	
	// Set data import for an object mode.
	SetDataExchangeImport(Object,, SendBack);
	
	// Check if there is a mark of the predefined item removal.
	RemoveDeletionMarkFromPredefinedItem(Object, Type);
	
	BeginTransaction();
	Try
		
		// Write the object in a transaction.
		Object.Write();
		
		InfobasesObjectsCompliance = Undefined;
		If Object.AdditionalProperties.Property("InfobasesObjectsCompliance", InfobasesObjectsCompliance)
			AND InfobasesObjectsCompliance <> Undefined Then
			
			InfobasesObjectsCompliance.UniqueSourceHandle = Object.Ref;
			
			InformationRegisters.InfobasesObjectsCompliance.AddRecord(InfobasesObjectsCompliance);
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		
		WriteObject = False;
		
		ErrorMessageString = WriteInformationAboutErrorToProtocol(26, DetailErrorDescription(ErrorInfo()), Object, Type);
		
		If Not ContinueOnError Then
			Raise ErrorMessageString;
		EndIf;
		
	EndTry;
	
EndProcedure

// Cancels the object execution in the infobase.
//
// Parameters:
// Object - Object for posting cancelation.
// Type - String - String object type.
//
Procedure UndoObjectPostingInIB(Object, Type, WriteObject = False) Export
	
	If DataExchangeEvents.ImportingIsProhibited(Object, ExchangeNodeForDataImport) Then
		Return;
	EndIf;
	
	// Set data import for an object mode.
	SetDataExchangeImport(Object);
	
	BeginTransaction();
	Try
		
		// Cancel posting of the document.
		Object.Posted = False;
		Object.Write();
		
		InfobasesObjectsCompliance = Undefined;
		If Object.AdditionalProperties.Property("InfobasesObjectsCompliance", InfobasesObjectsCompliance)
			AND InfobasesObjectsCompliance <> Undefined Then
			
			InfobasesObjectsCompliance.UniqueSourceHandle = Object.Ref;
			
			InformationRegisters.InfobasesObjectsCompliance.AddRecord(InfobasesObjectsCompliance);
		EndIf;
		
		DeleteDocumentRegisterRecords(Object);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		
		WriteObject = False;
		
		ErrorMessageString = WriteInformationAboutErrorToProtocol(26, DetailErrorDescription(ErrorInfo()), Object, Type);
		
		If Not ContinueOnError Then
			Raise ErrorMessageString;
		EndIf;
		
	EndTry;
	
EndProcedure

// Exports object according to the specified conversion rule.
//
// Parameters:
//  Source				 - custom data source.
//  Receiver				 - receiver object xml-node.
//  IncomingData			 - custom helper data passed
//                             to rule for conversion execution.
//  OutgoingData			 - custom helper data passed
//                             to the properties conversion rules.
//  OCRName					 - conversion rule name according to which export is executed.
//  Referencenode				 - xml-node of receiver object reference.
//  GetRefNodeOnly - if true, then object is not exported, only
//                             xml-node is generated.
//  OCR						 - ref to the conversion rule.
//
// Returns:
//  ref xml-node or receiver value.
//
//
Function DumpByRule(Source					= Undefined,
						   Receiver					= Undefined,
						   IncomingData			= Undefined,
						   OutgoingData			= Undefined,
						   OCRName					= "",
						   Referencenode				= Undefined,
						   GetRefNodeOnly	= False,
						   OCR						= Undefined,
						   ExportSubordinateObjectRefs = True,
						   ExportRegisterRecordSetRow = False,
						   ParentNode				= Undefined,
						   ConstantNameForExport  = "",
						   IsObjectExport = Undefined,
						   IsRuleWithGlobalObjectExport = False,
						   DontUseRuleWithGlobalExportAndDontRememberExported = False) Export
	//
	
	DefineOCRByParameters(OCR, Source, OCRName);
			
	If OCR = Undefined Then
		
		LR = GetProtocolRecordStructure(45);
		
		LR.Object = Source;
		LR.ObjectType = TypeOf(Source);
		
		WriteInExecutionProtocol(45, LR, True); // OCR is not found
		Return Undefined;
		
	EndIf;
	
	CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule + 1;
	
	If CommentObjectProcessingFlag Then
		
		Try
			SourceToString = String(Source);
		Except
			SourceToString = " ";
		EndTry;
		
		NameActions = ?(GetRefNodeOnly, NStr("en='Ref to object conversion';ru='Конвертация ссылки на объект'"), NStr("en='Object conversion';ru='Конвертация объекта'"));
		
		MessageText = NStr("en='[NameActions]: [Object]([ObjectType]), OCR: [OCR](OCRDescription)';ru='[ИмяДействия]: [Объект]([ТипОбъекта]), ПКО: [ПКО](НаименованиеПКО)'");
		MessageText = StrReplace(MessageText, "[NameActions]", NameActions);
		MessageText = StrReplace(MessageText, "[Object]", SourceToString);
		MessageText = StrReplace(MessageText, "[ObjectType]", TypeOf(Source));
		MessageText = StrReplace(MessageText, "[OCR]", TrimAll(OCRName));
		MessageText = StrReplace(MessageText, "[OCRName]", TrimAll(OCR.Description));
		
		WriteInExecutionProtocol(MessageText, , False, CurrentNestingLevelExportByRule + 1, 7);
		
	EndIf;
	
	IsRuleWithGlobalObjectExport = False;
	
	RememberExported       = False;
	ExportedObjects          = OCR.Exported;
	AllObjectsAreExported         = OCR.AllObjectsAreExported;
	DoNotReplaceObjectOnImport = OCR.Donotreplace;
	DoNotCreateIfNotFound     = OCR.DoNotCreateIfNotFound;
	OnExchangeObjectByRefSetGIUDOnly     = OCR.OnExchangeObjectByRefSetGIUDOnly;
	DontReplaceCreatedInTargetObject = OCR.DontReplaceCreatedInTargetObject;
	ExchangeObjectPriority = OCR.ExchangeObjectPriority;
	
	RecordObjectChangeAtSenderNode = False;
	
	AutonumerationPrefix		= "";
	WriteMode     			= "";
	PostingMode 			= "";
	TempFileList = Undefined;

   	TypeName          = "";
	ExportObjectProperties = True;
	
	PropertyStructure = FindPropertiesStructureByParameters(OCR, Source);
			
	If PropertyStructure <> Undefined Then
		TypeName = PropertyStructure.TypeName;
	EndIf;

	ExportedDataKey = OCRName;
	
	IsNotReferenceType = TypeName = "Constants"
		OR TypeName = "InformationRegister"
		OR TypeName = "AccumulationRegister"
		OR TypeName = "AccountingRegister"
		OR TypeName = "CalculationRegister"
	;
	
	If IsNotReferenceType 
		OR IsBlankString(TypeName) Then
		
		RememberExported = False;
		
	EndIf;
	
	SourceRef = Undefined;
	ExportingObject = IsObjectExport;
	
	If (Source <> Undefined) 
		AND Not IsNotReferenceType Then
		
		If ExportingObject = Undefined Then
			// If it is not specified what is exported, then consider that object is exported.
			ExportingObject = True;	
		EndIf;
		
		SourceRef = DefineRefByObjectOrRef(Source, ExportingObject);
		If RememberExported Then
			ExportedDataKey = DefineInternallyPresentationForSearch(SourceRef, PropertyStructure);
		EndIf;
		
	Else
		
		ExportingObject = False;
			
	EndIf;
	
	// Variable for predefined item name storage.
	PredefinedItemName = Undefined;
	
	// BeforeObjectConversion global handler.
	Cancel = False;
	If HasBeforeConvertObjectGlobalHandler Then
		
		Try
			
			If DebuggingExportHandlers Then
				
				ExecuteHandler_Conversion_BeforeObjectConversion(ExchangeFile, Source, IncomingData, OutgoingData, OCRName, OCR,
																		 ExportedObjects, Cancel, ExportedDataKey, RememberExported,
																		 DoNotReplaceObjectOnImport, AllObjectsAreExported,GetRefNodeOnly,
																		 Receiver, WriteMode, PostingMode, DoNotCreateIfNotFound);
				
			Else
				
				Execute(Conversion.BeforeObjectConversion);
				
			EndIf;
			
		Except
			WriteInformationAboutOCRHandlerErrorDump(64, ErrorDescription(), OCR, Source, NStr("en='BeforeObjectConversion (global)';ru='ПередКонвертациейОбъекта (глобальный)'"));
		EndTry;
		
		If Cancel Then	//	Denial of the further rule data processor.
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return Receiver;
		EndIf;
		
	EndIf;
	
	// Handler BeforeExport
	If OCR.HasBeforeExportHandler Then
		
		Try
			
			If DebuggingExportHandlers Then
				
				ExecuteHandler_OCR_BeforeObjectExport(ExchangeFile, Source, IncomingData, OutgoingData, OCRName, OCR,
															  ExportedObjects, Cancel, ExportedDataKey, RememberExported,
															  DoNotReplaceObjectOnImport, AllObjectsAreExported, GetRefNodeOnly,
															  Receiver, WriteMode, PostingMode, DoNotCreateIfNotFound);
				
			Else
				
				Execute(OCR.BeforeExport);
				
			EndIf;
			
		Except
			WriteInformationAboutOCRHandlerErrorDump(41, ErrorDescription(), OCR, Source, "BeforeObjectExport");
		EndTry;
		
		If Cancel Then	//	Denial of the further rule data processor.
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return Receiver;
		EndIf;
		
	EndIf;
	
	ExportStackRow = Undefined;
	
	MustUpdateLocalExportedObjectCache = False;
	RefsValueInAnotherInfobase = "";

	// This data may have already been exported.
	If Not AllObjectsAreExported Then
		
		NPP = 0;
		
		If RememberExported Then
			
			ExportedObjectRow = ExportedObjects.Find(ExportedDataKey, "Key");
			
			If ExportedObjectRow <> Undefined Then
				
				ExportedObjectRow.CallCount = ExportedObjectRow.CallCount + 1;
				ExportedObjectRow.LastCallNumber = SnCounter;
				
				If GetRefNodeOnly Then
					
					CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
					If Find(ExportedObjectRow.Referencenode, "<Ref") > 0
						AND WrittenToFileNPP >= ExportedObjectRow.RefNPP Then
						Return ExportedObjectRow.RefNPP;
					Else
						Return ExportedObjectRow.Referencenode;
					EndIf;
					
				EndIf;
				
				ExportedRefNumber = ExportedObjectRow.RefNPP;
				
				If Not ExportedObjectRow.OnlyRefExported Then
					
					CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
					Return ExportedObjectRow.Referencenode;
					
				Else
					
					ExportStackRow = DataExportCallStack.Find(ExportedDataKey, "Ref");
				
					If ExportStackRow <> Undefined Then
						CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
						Return Undefined;
					EndIf;
					
					ExportStackRow = DataExportCallStack.Add();
					ExportStackRow.Ref = ExportedDataKey;
					
					NPP = ExportedRefNumber;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		If NPP = 0 Then
			
			SnCounter = SnCounter + 1;
			NPP         = SnCounter;
			
			
			// It will allow to avoid circular refs.
			If RememberExported Then
				
				If ExportedObjectRow = Undefined Then
					
					If Not IsRuleWithGlobalObjectExport
						AND Not MustUpdateLocalExportedObjectCache
						AND ExportedObjects.Count() > StoredExportedObjectCountByTypes Then
						
						MustUpdateLocalExportedObjectCache = True;
						DataMapForExportedItemUpdate.Insert(OCR.Receiver, OCR);
												
					EndIf;
					
					ExportedObjectRow = ExportedObjects.Add();
					
				EndIf;
				
				ExportedObjectRow.Key = ExportedDataKey;
				ExportedObjectRow.Referencenode = NPP;
				ExportedObjectRow.RefNPP = NPP;
				ExportedObjectRow.LastCallNumber = NPP;
												
				If GetRefNodeOnly Then
					
					ExportedObjectRow.OnlyRefExported = True;					
					
				Else
					
					ExportStackRow = DataExportCallStack.Add();
					ExportStackRow.Ref = ExportedDataKey;
					
				EndIf;
				
			EndIf;
				
		EndIf;
		
	EndIf;
	
	ValueMap = OCR.ValuesOfPredefinedData;
	ValueMapItemCount = ValueMap.Count();
	
	// Data processor of predefined item matches.
	If PredefinedItemName = Undefined Then
		
		If PropertyStructure <> Undefined
			AND ValueMapItemCount > 0
			AND PropertyStructure.SearchByPredefinedPossible Then
			
			Try
				PredefinedNameSource = CommonUse.PredefinedName(SourceRef);
			Except
				PredefinedNameSource = "";
			EndTry;
			
		Else
			
			PredefinedNameSource = "";
			
		EndIf;
		
		If Not IsBlankString(PredefinedNameSource)
			AND ValueMapItemCount > 0 Then
			
			PredefinedItemName = ValueMap[SourceRef];
			
		Else
			PredefinedItemName = Undefined;				
		EndIf;
		
	EndIf;
	
	If PredefinedItemName <> Undefined Then
		ValueMapItemCount = 0;
	EndIf;			
	
	DontExportByValueMap = (ValueMapItemCount = 0);
	
	If Not DontExportByValueMap Then
		
		// If there is no object in the values match - , export it regularly.
		Referencenode = ValueMap[SourceRef];
		If Referencenode = Undefined Then
			
			// This may be conversion from enumeration to enumeration and you have not found by.
			// VCR required property - then just export empty reference.
			If PropertyStructure.TypeName = "Enum"
				AND Find(OCR.Receiver, "EnumRef.") > 0 Then
				
				// Write error to the execution protocol.
				LR = GetProtocolRecordStructure();
				LR.OCRName              = OCRName;
				LR.Value            = Source;
				LR.ValueType         = PropertyStructure.RefTypeAsString;
				LR.PErrorMessages = 71;
				LR.Text               = NStr("en='In the values conversion rule (VCR) you should match Source value to Receiver value.
		|If there is no receiver appropriate value, specify an empty value.';ru='В правиле конвертации значений (ПКЗ) необходимо сопоставить значение Источника значению Приемника.
		|Если подходящего значения приемника нет, то указать пустое значение.'");
				//
				WriteInExecutionProtocol(71, LR);
				
				If ExportStackRow <> Undefined Then
					DataExportCallStack.Delete(ExportStackRow);				
				EndIf;
				
				CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
				
				Return Undefined;
				
			Else
				
				DontExportByValueMap = True;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	DontExportSubordinateObjects = GetRefNodeOnly OR Not ExportSubordinateObjectRefs;
	
	MustRememberObject = RememberExported AND (NOT AllObjectsAreExported);
	
	If DontExportByValueMap Then
		
		If OCR.SearchProperties.Count() > 0 
			OR PredefinedItemName <> Undefined Then
			
			//	Generate ref node
			Referencenode = CreateNode("Ref");
						
			If MustRememberObject Then
				
				If IsRuleWithGlobalObjectExport Then
					SetAttribute(Referencenode, "GSn", NPP);
				Else
					SetAttribute(Referencenode, "NPP", NPP);
				EndIf;
				
			EndIf;
			
			If DoNotCreateIfNotFound Then
				SetAttribute(Referencenode, "DoNotCreateIfNotFound", DoNotCreateIfNotFound);
			EndIf;
			
			If OCR.SearchBySearchFieldsIfNotFoundByID Then
				SetAttribute(Referencenode, "ContinueSearch", True);
			EndIf;
			
			If RecordObjectChangeAtSenderNode Then
				SetAttribute(Referencenode, "RecordObjectChangeAtSenderNode", RecordObjectChangeAtSenderNode);
			EndIf;
			
			WriteExchangeObjectsPriority(ExchangeObjectPriority, Referencenode);
			
			If DontReplaceCreatedInTargetObject Then
				SetAttribute(Referencenode, "DontReplaceCreatedInTargetObject", DontReplaceCreatedInTargetObject);				
			EndIf;
			
			ExportRefOnly = OCR.DontExportPropertyObjectsByRefs OR DontExportSubordinateObjects;
			
			If ExportObjectProperties = True Then
			
				DumpProperties(Source, Receiver, IncomingData, OutgoingData, OCR, OCR.SearchProperties, 
					Referencenode, , PredefinedItemName, True, 
					True, ExportingObject, ExportedDataKey, , RefsValueInAnotherInfobase);
					
			EndIf;
			
			Referencenode.WriteEndElement();
			Referencenode = Referencenode.Close();
			
			If MustRememberObject Then
				
				ExportedObjectRow.Referencenode = Referencenode;															
								
			EndIf;			
			
		Else
			Referencenode = NPP;
		EndIf;
		
	Else
		
		// Search values by VCR in the match.
		If Referencenode = Undefined Then
			
			// Write error to the execution protocol.
			LR = GetProtocolRecordStructure();
			LR.OCRName              = OCRName;
			LR.Value            = Source;
			LR.ValueType         = TypeOf(Source);
			LR.PErrorMessages = 71;
			
			WriteInExecutionProtocol(71, LR);
			
			If ExportStackRow <> Undefined Then
				DataExportCallStack.Delete(ExportStackRow);				
			EndIf;
			
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return Undefined;
		EndIf;
		
		If RememberExported Then
			ExportedObjectRow.Referencenode = Referencenode;			
		EndIf;
		
		If ExportStackRow <> Undefined Then
			DataExportCallStack.Delete(ExportStackRow);				
		EndIf;
		
		CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
		Return Referencenode;
		
	EndIf;

		
	If GetRefNodeOnly
		Or AllObjectsAreExported Then
		
		If ExportStackRow <> Undefined Then
			DataExportCallStack.Delete(ExportStackRow);				
		EndIf;
		
		CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
		Return Referencenode;
		
	EndIf; 

	If Receiver = Undefined Then
		
		Receiver = CreateNode("Object");
		
		If Not ExportRegisterRecordSetRow Then
			
			If IsRuleWithGlobalObjectExport Then
				SetAttribute(Receiver, "GSn", NPP);
			Else
				SetAttribute(Receiver, "NPP", NPP);
			EndIf;
			
			SetAttribute(Receiver, "Type", 			OCR.Receiver);
			SetAttribute(Receiver, "Rulename",	OCR.Name);
			
			If Not IsBlankString(ConstantNameForExport) Then
				
				SetAttribute(Receiver, "ConstantName", ConstantNameForExport);
				
			EndIf;
			
			WriteExchangeObjectsPriority(ExchangeObjectPriority, Receiver);
			
			If DoNotReplaceObjectOnImport Then
				SetAttribute(Receiver, "Donotreplace",	"true");
			EndIf;
			
			If Not IsBlankString(AutonumerationPrefix) Then
				SetAttribute(Receiver, "AutonumerationPrefix",	AutonumerationPrefix);
			EndIf;
			
			If Not IsBlankString(WriteMode) Then
				
				SetAttribute(Receiver, "WriteMode",	WriteMode);
				If Not IsBlankString(PostingMode) Then
					SetAttribute(Receiver, "PostingMode",	PostingMode);
				EndIf;
				
			EndIf;
			
			If TypeOf(Referencenode) <> NumberType Then
				AddSubordinate(Receiver, Referencenode);
			EndIf;
		
		EndIf;
		
	EndIf;

	// Handler OnExport
	StandardProcessing = True;
	Cancel = False;
	
	If OCR.HasOnExportHandler Then
		
		Try
			
			If DebuggingExportHandlers Then
				
				ExecuteHandler_OCR_OnExportObject(ExchangeFile, Source, IncomingData, OutgoingData, OCRName,
														   OCR, ExportedObjects, ExportedDataKey, Cancel,
														   StandardProcessing, Receiver, Referencenode);
				
			Else
				
				Execute(OCR.OnExport);
				
			EndIf;
			
		Except
			WriteInformationAboutOCRHandlerErrorDump(42, ErrorDescription(), OCR, Source, "OnExportObject");
		EndTry;
				
		If Cancel Then	//	Denial of object writing to file.
			
			If ExportStackRow <> Undefined Then
				DataExportCallStack.Delete(ExportStackRow);				
			EndIf;
			
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return Referencenode;
		EndIf;
		
	EndIf;

	// Export property
	If StandardProcessing Then
		
		If Not IsBlankString(ConstantNameForExport) Then
			
			PropertyForExportArray = New Array();
			
			TableRow = OCR.Properties.Find(ConstantNameForExport, "Source");
			
			If TableRow <> Undefined Then
				PropertyForExportArray.Add(TableRow);
			EndIf;
			
		Else
			
			PropertyForExportArray = OCR.Properties;
			
		EndIf;
		
		If ExportObjectProperties Then
		
			DumpProperties(
				Source,                 // Source
				Receiver,                 // Receiver
				IncomingData,           // IncomingData
				OutgoingData,          // OutgoingData
				OCR,                      // OCR
				PropertyForExportArray, // PCRCollection
				,                         // PropertiesCollectionNode = Undefined
				,                         // CollectionObject = Undefined
				,                         // PredefinedItemName = Undefined
				True,                   // Val ExportOnlyRef = True
				False,                     // Val IsRefExport = False
				ExportingObject,        // Val ObjectExported = False
				ExportedDataKey,    // RefSearchKey = ""
				,                         // NotUseRulesWithGlobalExportAndNotRememberExported = False
				RefsValueInAnotherInfobase,  // RefsValueInAnotherInfobase
				TempFileList,    // TemporaryFilesList = Undefined
				ExportRegisterRecordSetRow); // RegisterRecordsSetStringExport = False
				
			EndIf;
			
		EndIf;    
		
		// Handler AfterExport
		
		If OCR.HasAfterExportHandler Then
			
			Try
				
				If DebuggingExportHandlers Then
					
					ExecuteHandler_OCR_AfterObjectExport(ExchangeFile, Source, IncomingData, OutgoingData, OCRName, OCR,
																 ExportedObjects, ExportedDataKey, Cancel, Receiver, Referencenode);
					
				Else
					
					Execute(OCR.AfterExport);
					
				EndIf;
				
			Except
				WriteInformationAboutOCRHandlerErrorDump(43, ErrorDescription(), OCR, Source, "AfterObjectExport");
			EndTry;
			
			If Cancel Then	//	Denial of object writing to file.
				
				If ExportStackRow <> Undefined Then
					DataExportCallStack.Delete(ExportStackRow);				
				EndIf;
				
				CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
				Return Referencenode;
			EndIf;
		EndIf;
		
		
	//	Write object to file
	IncreaseExportedObjectsCounter();
	
	CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
	
	If ParentNode <> Undefined Then
		
		Receiver.WriteEndElement();
		
		ParentNode.WriteRaw(Receiver.Close());
		
	Else
	
		If TempFileList = Undefined Then
			
			Receiver.WriteEndElement();
			WriteToFile(Receiver);
			
		Else
			
			WriteToFile(Receiver);
		
			TempFile = New TextReader;
			For Each TempFileName IN TempFileList Do
				
				Try
					TempFile.Open(TempFileName, TextEncoding.UTF8);
				Except
					Continue;
				EndTry;
				
				TempFileLine = TempFile.ReadLine();
				While TempFileLine <> Undefined Do
					WriteToFile(TempFileLine);	
				    TempFileLine = TempFile.ReadLine();
				EndDo;
				
				TempFile.Close();
				
				// delete files
				DeleteFiles(TempFileName); 
			EndDo;
			
			WriteToFile("</Object>");
			
		EndIf;
		
		If MustRememberObject
			AND IsRuleWithGlobalObjectExport Then
				
			ExportedObjectRow.Referencenode = NPP;
			
		EndIf;
		
		If CurrentNestingLevelExportByRule = 0 Then
			
			DoSignsSetupForObjectsDumpedToFile();
			
		EndIf;
		
		UpdateDataInsideDataBeingDumped();		
		
	EndIf;
	
	If ExportStackRow <> Undefined Then
		DataExportCallStack.Delete(ExportStackRow);				
	EndIf;
	
	// Handler AfterExportToFile
	If OCR.HasAfterExportToFileHandler Then
		
		Try
			
			If DebuggingExportHandlers Then
				
				ExecuteHandler_OCR_AfterObjectExportToExchangeFile(ExchangeFile, Source, IncomingData, OutgoingData,
																		OCRName, OCR, ExportedObjects, Receiver, Referencenode);
				
			Else
				
				Execute(OCR.AfterExportToFile);
				
			EndIf;
			
		Except
			WriteInformationAboutOCRHandlerErrorDump(79, ErrorDescription(), OCR, Source, "HasAfterExportToFileHandler");
		EndTry;
		
	EndIf;
	
	Return Referencenode;
	
EndFunction

// Exports register by filter.
// 
// Parameters:
// RecordSetForExport - Structure or RecordSet - Filter.
//
Procedure DumpRegister(RecordSetForExport, 
							Rule = Undefined, 
							IncomingData = Undefined, 
							DoNotDumpObjectsByRefs = False, 
							OCRName = "",
							DataExportRule = Undefined) Export
							
	OutgoingData = Undefined;						
							
	
	DefineOCRByParameters(Rule, RecordSetForExport, OCRName);
	
	Cancel			= False;
	Properties = Undefined;
	ExchangeObjectPriority = Rule.ExchangeObjectPriority;
	
	If TypeOf(RecordSetForExport) = Type("Structure") Then
		
		RecordSetFilter  = RecordSetForExport.Filter;
		RecordSetRows = RecordSetForExport.Rows;
		
	Else // RecordSet
		
		RecordSetFilter  = RecordSetForExport.Filter;
		RecordSetRows = RecordSetForExport;
		
	EndIf;
	
	// First, write filter, then
	// filter records set.
	
	Receiver = CreateNode("RegisterRecordSet");
	
	RegisterRecordCount = RecordSetRows.Count();
		
	SnCounter = SnCounter + 1;
	NPP         = SnCounter;
	
	SetAttribute(Receiver, "NPP",			NPP);
	SetAttribute(Receiver, "Type", 			StrReplace(Rule.Receiver, "InformationRegisterRecord.", "InformationRegisterRecordSet."));
	SetAttribute(Receiver, "Rulename",	Rule.Name);
	
	WriteExchangeObjectsPriority(ExchangeObjectPriority, Receiver);
	
	ExportingEmptySet = RegisterRecordCount = 0;
	If ExportingEmptySet Then
		SetAttribute(Receiver, "EmptySet",	True);
	EndIf;
	
	Receiver.WriteStartElement("Filter");
	
	SourceStructure = New Structure;
	PCRForExportArray = New Array();
	
	For Each FilterRow IN RecordSetFilter Do
		
		If FilterRow.Use = False Then
			Continue;
		EndIf;
		
		PCRRow = Rule.Properties.Find(FilterRow.Name, "Source");
		
		If PCRRow = Undefined Then
			
			PCRRow = Rule.Properties.Find(FilterRow.Name, "Receiver");
			
		EndIf;
		
		If PCRRow <> Undefined
			AND  (PCRRow.TargetKind = "Property"
			OR PCRRow.TargetKind = "Dimension") Then
			
			PCRForExportArray.Add(PCRRow);
			
			Key = ?(IsBlankString(PCRRow.Source), PCRRow.Receiver, PCRRow.Source);
			
			SourceStructure.Insert(Key, FilterRow.Value);
			
		EndIf;
		
	EndDo;
	
	// Add parameters for filter.
	For Each SearchPropertyString IN Rule.SearchProperties Do
		
		If IsBlankString(SearchPropertyString.Receiver)
			AND Not IsBlankString(SearchPropertyString.ParameterForTransferName) Then
			
			PCRForExportArray.Add(SearchPropertyString);	
			
		EndIf;
		
	EndDo;
	
	DumpProperties(SourceStructure, , IncomingData, OutgoingData, Rule, PCRForExportArray, Receiver, 
		, , True, , , , ExportingEmptySet);
	
	Receiver.WriteEndElement();
	
	Receiver.WriteStartElement("RecordSetRows");
	
	// IncomingData records set = Undefined;
	For Each RegisterLine IN RecordSetRows Do
		
		ExportSelectionObject(RegisterLine, DataExportRule, , IncomingData, DoNotDumpObjectsByRefs, True, 
			Receiver, , OCRName, FALSE);
				
	EndDo;
	
	Receiver.WriteEndElement();
	
	Receiver.WriteEndElement();
	
	WriteToFile(Receiver);
	
	UpdateDataInsideDataBeingDumped();
	
	DoSignsSetupForObjectsDumpedToFile();
	
	Increment(ExportedObjectCounterField, 1 - RecordSetRows.Count());
	
EndProcedure

// Sets deletion mark.
//
// Parameters:
// Object - Object to set a mark.
// DeletionMark - Boolean - Check box of the deletion mark.
// ObjectTypeName - String - String object type.
//
Procedure SetObjectDeletionMark(Object, DeletionMark, ObjectTypeName) Export
	
	If (DeletionMark = Undefined AND Object.DeletionMark <> True)
		Or DataExchangeEvents.ImportingIsProhibited(Object, ExchangeNodeForDataImport) Then
		Return;
	EndIf;
	
	MarkToSet = ?(DeletionMark <> Undefined, DeletionMark, False);
	
	SetDataExchangeImport(Object);
		
	// For hierarchical objects mark as deleted only a specific object.
	If ObjectTypeName = "Catalog"
		OR ObjectTypeName = "ChartOfCharacteristicTypes"
		OR ObjectTypeName = "ChartOfAccounts" Then
		
		If Not Object.Predefined Then
			
			Object.SetDeletionMark(MarkToSet, False);
			
		EndIf;
		
	Else
		
		Object.SetDeletionMark(MarkToSet);
		
	EndIf;	
	
EndProcedure

// Sets a value of the Import parameter for a property of the DataExchange object.
//
// Parameters:
//  Object   - object, for which the property is set.
//  Value - value of the set property Import.
//
//
Procedure SetDataExchangeImport(Object, Value = True, Val SendBack = False) Export
	
	Try
		Object.DataExchange.Load = Value;
	Except
		// Not all the objects in the exchange have the DataExchange property.
	EndTry;
	
	If Not SendBack
		AND ExchangeNodeForDataImport <> Undefined
		AND Not ExchangeNodeForDataImport.IsEmpty() Then
	
		Try
			Object.DataExchange.Sender = ExchangeNodeForDataImport;
		Except
			// Not all the objects in the exchange have the DataExchange property.
		EndTry;
	
	EndIf;
	
EndProcedure

// Adds information about value types to xml file.
//
// Parameters:
// Receiver - receiver object xml-node.
// Type - String - exported type.
// 	- Array - contains exported row types list.
// AttributesList - Structure - Key contains attribute name.
//
Procedure ExportInformationAboutTypes(Receiver, Type, AttributesList = Undefined) Export
	
	TypeNode = CreateNode("Types");
	
	If AttributesList <> Undefined Then
		For Each CollectionItem IN AttributesList Do
			SetAttribute(TypeNode, CollectionItem.Key, CollectionItem.Value);
		EndDo;
	EndIf;
	
	If TypeOf(Type) = Type("String") Then
		deWriteItem(TypeNode, "Type", Type);
	Else
		For Each TypeAsString IN Type Do
			deWriteItem(TypeNode, "Type", TypeAsString);
		EndDo;
	EndIf;
	
	AddSubordinate(Receiver, TypeNode);
	
EndProcedure

// Returns values table which contains refs to documents for
// the deferred posting and the dates of these documents for pre-sorting.
//
// Returns:
//  Values tables, columns:
//    DocumentRef - ref, reference to the imported document that requires deferred posting;
//    DocumentDate  - date, date of imported document for table pre-sorting.
//
Function DocumentsForDelayedPosting() Export
	
	If TypeOf(DocumentsForDeferredPostingField) <> Type("ValueTable") Then
		
		// Initialize table for the documents deferred posting.
		DocumentsForDeferredPostingField = New ValueTable;
		DocumentsForDeferredPostingField.Columns.Add("DocumentRef");
		DocumentsForDeferredPostingField.Columns.Add("DocumentDate", deDescriptionType("Date"));
		
	EndIf;
	
	Return DocumentsForDeferredPostingField;
	
EndFunction

// Adds to a deferred posting table a string
// containing ref to the document that should be posted and document date for pre-sorting.
//
// Parameters:
//  ObjectReference         - Ref, object that should be posted deferred;
//  ObjectData            - Date, object date;
//  AdditionalProperties - Structure, written object additional properties.
//
Procedure AddObjectForDeferredPosting(ObjectReference, ObjectData, AdditionalProperties) Export
	
	DeferredPostingTable = DocumentsForDelayedPosting();
	NewRow = DeferredPostingTable.Add();
	NewRow.DocumentRef = ObjectReference;
	NewRow.DocumentDate  = ObjectData;
	
	AdditionalPropertiesForDeferredPosting().Insert(ObjectReference, AdditionalProperties);
	
EndProcedure

Procedure GetValuesOfPredefinedData(Val OCR)
	
	OCR.ValuesOfPredefinedData = New Map;
	
	For Each Item IN OCR.ValuesOfPredefinedDataRead Do
		
		OCR.ValuesOfPredefinedData.Insert(deGetValueByString(Item.Key, OCR.Source), Item.Value);
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// HELPER PROCEDURES FOR ALGORITHM WRITING

////////////////////////////////////////////////////////////////////////////////
// WORK WITH STRINGS

// Breaks a row into two parts: up to subrow and after.
//
// Parameters:
//  Str          - parsed row;
//  Delimiter  - subrow-separator:
//  Mode        - 0 - a separator in the returned subrows is not included;
//                 1 - separator is included into a left subrow;
//                 2 - separator is included to a right subrow.
//
// Returns:
//  Right part of the row - up to delimiter character
// 
Function SeparateBySeparator(Str, Val Delimiter, Mode=0)

	RightPart         = "";
	SplitterPos      = Find(Str, Delimiter);
	SeparatorLength    = StrLen(Delimiter);
	If SplitterPos > 0 Then
		RightPart	 = Mid(Str, SplitterPos + ?(Mode=2, 0, SeparatorLength));
		Str          = TrimAll(Left(Str, SplitterPos - ?(Mode=1, -SeparatorLength + 1, 1)));
	EndIf;

	Return(RightPart);

EndFunction

// Converts values from string to array using the specified separator.
//
// Parameters:
//  Str            - Parsed string.
//  Delimiter    - subrow separator.
//
// Returns:
//  Array of values
// 
Function ArrayFromString(Val Str, Delimiter=",")

	Array      = New Array;
	RightPart = SeparateBySeparator(Str, Delimiter);
	
	While Not IsBlankString(Str) Do
		Array.Add(TrimAll(Str));
		Str         = RightPart;
		RightPart = SeparateBySeparator(Str, Delimiter);
	EndDo; 

	Return(Array);
	
EndFunction

Function GetStringNumberWithoutPrefixes(Number)
	
	NumberWithoutPrefixes = "";
	Ct = StrLen(Number);
	
	While Ct > 0 Do
		
		Char = Mid(Number, Ct, 1);
		
		If (Char >= "0" AND Char <= "9") Then
			
			NumberWithoutPrefixes = Char + NumberWithoutPrefixes;
			
		Else
			
			Return NumberWithoutPrefixes;
			
		EndIf;
		
		Ct = Ct - 1;
		
	EndDo;
	
	Return NumberWithoutPrefixes;
	
EndFunction

// Parses string excluding prefix and numeric part from it.
//
// Parameters:
//  Str            - String. Parsed string;
//  NumericalPart  - Number. Variable to which string numeric part is returned;
//  Mode          - String. If there is "Number", then it returns a numeric part, otherwise, - Prefix.
//
// Returns:
//  String prefix
//
Function GetPrefixNumberOfNumber(Val Str, NumericalPart = "", Mode = "")

	NumericalPart = 0;
	Prefix = "";
	Str = TrimAll(Str);
	Length   = StrLen(Str);
	
	StringNumberWithoutPrefix = GetStringNumberWithoutPrefixes(Str);
	StringPartLength = StrLen(StringNumberWithoutPrefix);
	If StringPartLength > 0 Then
		NumericalPart = Number(StringNumberWithoutPrefix);
		Prefix = Mid(Str, 1, Length - StringPartLength);
	Else
		Prefix = Str;	
	EndIf;

	If Mode = "Number" Then
		Return(NumericalPart);
	Else
		Return(Prefix);
	EndIf;

EndFunction

// Reduces number (code) to the required length. Prefix and
// number numeric part are excluded, the rest of the
// space between the prefix and the number is filled in with zeros.
// Function can be used in the event handlers application code of which is stored in the data exchange rules. Called using the Execute() method.
// Message "Refs to the function are not found" while checking configuration is not a configuration checking error.
//
// Parameters:
//  Str          - converted string;
//  Length        - required string length.
//
// Returns:
//  String       - code or number reduced to the required length.
// 
Function CastNumberToLength(Val Str, Length, AddZerosIfLengthNotLessCurrentNumberLength = True, Prefix = "")

	Str             = TrimAll(Str);
	IncomingNumberLength = StrLen(Str);

	NumericalPart   = "";
	Result       = GetPrefixNumberOfNumber(Str, NumericalPart);
	
	Result = ?(IsBlankString(Prefix), Result, Prefix);
	
	NumericPartString = Format(NumericalPart, "NG=0");
	NumericPartLength = StrLen(NumericPartString);

	If (Length >= IncomingNumberLength AND AddZerosIfLengthNotLessCurrentNumberLength)
		OR (Length < IncomingNumberLength) Then
		
		For TemporaryVariable = 1 To Length - StrLen(Result) - NumericPartLength Do
			
			Result = Result + "0";
			
		EndDo;
	
	EndIf;
		
	Result = Result + NumericPartString;

	Return(Result);

EndFunction

// Expands string with the specified character up to the specified length.
//
// Parameters: 
//  Str          - expanded string;
//  Length        - required length of the resulting string;
//  Than          - character which expands string.
//
// Returns:
//  String expanded with the specified character up to the specified length.
//
Function deAddToString(Str, Length, Than = " ")

	Result = TrimAll(Str);
	While Length - StrLen(Result) > 0 Do
		Result = Result + Than;
	EndDo;

	Return(Result);

EndFunction

////////////////////////////////////////////////////////////////////////////////
// WORK WITH DATA

// Returns string - name of the passed enumeration value.
// Function can be used in the event handlers application code of which is stored in the data exchange rules. Called using the Execute() method.
// Message "Refs to the function are not found" while checking configuration is not a configuration checking error.
//
// Parameters:
//  Value     - enumeration value.
//
// Returns:
//  String       - name of the passed enumeration value.
//
Function deEnumValueName(Value) Export

	MDObject       = Value.Metadata();
	ValueIndex = Enums[MDObject.Name].IndexOf(Value);

	Return MDObject.EnumValues[ValueIndex].Name;

EndFunction

// Determines whether the passed value is filled in.
//
// Parameters: 
//  Value       - value filling of which should be checked.
//
// Returns:
//  True         - value is not filled in, false - else.
//
Function deBlank(Value, IsNULL=False)

	// First, primitive types
	If Value = Undefined Then
		Return True;
	ElsIf Value = NULL Then
		IsNULL   = True;
		Return True;
	EndIf;
	
	ValueType = TypeOf(Value);
	
	If ValueType = ValueStorageType Then
		
		Result = deBlank(Value.Get());
		Return Result;		
		
	ElsIf ValueType = BinaryDataType Then
		
		Return False;
		
	Else
		
		// For the rest ones consider the value empty
		// if it equals to the default value of its type.
		Try
			Result = Not ValueIsFilled(Value);
			Return Result;
		Except
			Return False;
		EndTry;
			
	EndIf;
	
EndFunction

// Returns TypeDescription object containing the specified type.
//  
// Parameters:
//  TypeValue - srtring with type name or value of the Type type.
//  
// Returns:
//  TypeDescription
//
Function deDescriptionType(TypeValue)

	TypeDescription = TypeDescriptionMap[TypeValue];
	
	If TypeDescription = Undefined Then
		
		TypeArray = New Array;
		If TypeOf(TypeValue) = StringType Then
			TypeArray.Add(Type(TypeValue));
		Else
			TypeArray.Add(TypeValue);
		EndIf; 
		TypeDescription	= New TypeDescription(TypeArray);
		
		TypeDescriptionMap.Insert(TypeValue, TypeDescription);
		
	EndIf;	
	
	Return TypeDescription;

EndFunction

// Returns empty (default) value of the specified type.
//
// Parameters:
//  Type          - srtring with type name or value of the Type type.
//
// Returns:
//  Empty value of the specified type.
// 
Function deGetBlankValue(Type)

	EmptyTypeValue = EmptyTypeValueMap[Type];
	
	If EmptyTypeValue = Undefined Then
		
		EmptyTypeValue = deDescriptionType(Type).AdjustValue(Undefined);	
		
		EmptyTypeValueMap.Insert(Type, EmptyTypeValue);
			
	EndIf;
	
	Return EmptyTypeValue;

EndFunction

Function CheckExistenceOfRef(Ref, Manager, FoundByUUIDObject, 
	MainObjectSearchMode, SearchByUUIDQueryString)
	
	Try
			
		If MainObjectSearchMode
			OR IsBlankString(SearchByUUIDQueryString) Then
			
			FoundByUUIDObject = Ref.GetObject();
			
			If FoundByUUIDObject = Undefined Then
			
				Return Manager.EmptyRef();
				
			EndIf;
			
		Else
			// This is the search mode by ref - it is enough to make
			// a query to the infobase template for query PropertiesStructure.SearchString.
			
			Query = New Query();
			Query.Text = SearchByUUIDQueryString + "  Ref = &Ref ";
			Query.SetParameter("Ref", Ref);
			
			QueryResult = Query.Execute();
			
			If QueryResult.IsEmpty() Then
			
				Return Manager.EmptyRef();
				
			EndIf;
			
		EndIf;
		
		Return Ref;	
		
	Except
			
		Return Manager.EmptyRef();
		
	EndTry;
	
EndFunction

// Executes simple search for infobase object by the specified property.
//
// Parameters:
//  Manager       - searched object manager;
//  Property       - property according to which search is
// executed: Name, Code, Name or Indexed attribute name;
//  Value       - property value according to which you should search for object.
//
// Returns:
//  Found infobase object.
//
Function deFindObjectByProperty(Manager, Property, Value, 
	FoundByUUIDObject = Undefined, 
	CommonPropertyStructure = Undefined, CommonSearchProperties = Undefined,
	MainObjectSearchMode = True, SearchByUUIDQueryString = "")
	
	If Property = "Name" Then
		
		Return Manager[Value];
		
	ElsIf Property = "{UUID}" Then
		
		RefByUUID = Manager.GetRef(New UUID(Value));
		
		Ref =  CheckExistenceOfRef(RefByUUID, Manager, FoundByUUIDObject, 
			MainObjectSearchMode, SearchByUUIDQueryString);
			
		Return Ref;
		
	ElsIf Property = "{PredefinedItemName}" Then
		
		Ref = PredefinedManagerItem(Manager, Value);
		If Ref = Undefined Then
			Ref = Manager.FindByCode(Value);
			If Ref = Undefined Then
				Ref = Manager.EmptyRef();
			EndIf;
		EndIf;
		
		Return Ref;
		
	Else
		
		ObjectReference = FindItemUsingQuery(CommonPropertyStructure, CommonSearchProperties, , Manager);
		
		Return ObjectReference;
		
	EndIf;
	
EndFunction

// Returns predefined item value by its name.
// 
Function PredefinedManagerItem(Val Manager, Val PredefinedName)
	
	Query = New Query( StrReplace("
		|SELECT 
		|	PredefinedDataName AS PredefinedDataName,
		|	Ref                    AS Ref
		|FROM
		|	{TableName}
		|WHERE
		|	Predefined
		|",
		"{TableName}", Metadata.FindByType(TypeOf(Manager)).FullName()
	));
	
	Selection = Query.Execute().Select();
	If Selection.FindNext( New Structure("PredefinedDataName", PredefinedName) ) Then
		Return Selection.Ref;
	EndIf;
	
	Return Undefined;
EndFunction

// Executes simple search for infobase object by the specified property.
//
// Parameters:
//  Str            - String - property value according to
// which search is executed object;
//  Type            - searched oject type;
//  Property       - String - property name according to which you should search for object.
//
// Returns:
//  Found infobase object.
//
Function deGetValueByString(Str, Type, Property = "")

	If IsBlankString(Str) Then
		Return New(Type);
	EndIf; 

	Properties = Managers[Type];

	If Properties = Undefined Then
		
		TypeDescription = deDescriptionType(Type);
		Return TypeDescription.AdjustValue(Str);
		
	EndIf;

	If IsBlankString(Property) Then
		
		If Properties.TypeName = "Enum" Then
			Property = "Name";
		Else
			Property = "{PredefinedItemName}";
		EndIf;
		
	EndIf; 

	Return deFindObjectByProperty(Properties.Manager, Property, Str);

EndFunction

// Returns row presentation of the value type.
//
// Parameters: 
//  ValueOrType - custom value or value of the type type.
//
// Returns:
//  String - String presentation of the value type.
//
Function deValueTypeAsString(ValueOrType)

	ValueType	= TypeOf(ValueOrType);
	
	If ValueType = TypeType Then
		ValueType	= ValueOrType;
	EndIf; 
	
	If (ValueType = Undefined) Or (ValueOrType = Undefined) Then
		Result = "";
	ElsIf ValueType = StringType Then
		Result = "String";
	ElsIf ValueType = NumberType Then
		Result = "Number";
	ElsIf ValueType = DateType Then
		Result = "Date";
	ElsIf ValueType = BooleanType Then
		Result = "Boolean";
	ElsIf ValueType = ValueStorageType Then
		Result = "ValueStorage";
	ElsIf ValueType = UUIDType Then
		Result = "UUID";
	ElsIf ValueType = AccumulationRecordTypeType Then
		Result = "AccumulationRecordType";
	Else
		Manager = Managers[ValueType];
		If Manager = Undefined Then
		Else
			Result = Manager.RefTypeAsString;
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR WORK WITH OBJECT XMLWriter

// Creates
// new xml-node Function can be used in the events handlers
// application code of which is stored in the data exchange rules. Called using the Execute() method.
//
// Parameters: 
//  Name            - Node name
//
// Returns:
//  New xml-node object
//
Function CreateNode(Name)

	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XMLWriter.WriteStartElement(Name);

	Return XMLWriter;

EndFunction

// Records item and its value to the specified object.
//
// Parameters:
//  Object         - object of the XMLWriter type
//  Name            - String. Item name.
//  Value       - Item value.
// 
Procedure deWriteItem(Object, Name, Value="")

	Object.WriteStartElement(Name);
	Str = XMLString(Value);
	
	Object.WriteText(Str);
	Object.WriteEndElement();
	
EndProcedure

// Subjects an xml node to the specified parent node.
//
// Parameters: 
//  ParentNode   - xml parent node.
//  Node           - subordinate node.
//
Procedure AddSubordinate(ParentNode, Node)

	If TypeOf(Node) <> StringType Then
		Node.WriteEndElement();
		InformationToWriteToFile = Node.Close();
	Else
		InformationToWriteToFile = Node;
	EndIf;
	
	ParentNode.WriteRaw(InformationToWriteToFile);
		
EndProcedure

// Sets attribute of the specified xml-node.
//
// Parameters: 
//  Node           - xml-node
//  Name            - attribute name.
//  Value       - set value.
//
Procedure SetAttribute(Node, Name, Value)

	XMLString = XMLString(Value);
	
	Node.WriteAttribute(Name, XMLString);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR WORK WITH OBJECT XMLReading

// Reads attribute value by the name of the specified
// object, brings the value to the specified primitive type.
//
// Parameters:
//  Object      - XMLReading type object positioned on
//                the item start attribute of which is required to be received.
//  Type         - Value of the Type type. Attribute type.
//  Name         - String. Attribute name.
//
// Returns:
//  Attribute value received by the name and subjected to the specified type.
// 
Function deAttribute(Object, Type, Name)

	ValueStr = TrimR(Object.GetAttribute(Name));
	If Not IsBlankString(ValueStr) Then
		Return XMLValue(Type, ValueStr);		
	ElsIf      Type = StringType Then
		Return ""; 
	ElsIf Type = BooleanType Then
		Return False;
	ElsIf Type = NumberType Then
		Return 0;
	ElsIf Type = DateType Then
		Return EmptyDateValue;
	EndIf; 
	
EndFunction

// Skips xml nodes up to the end of the current item (current by default).
//
// Parameters:
//  Object   - object of the XMLReading type.
//  Name      - node name up to the end of which you should skip items.
// 
Procedure deIgnore(Object, Name="")

	AttachmentsQuantity = 0; // Eponymous attachments quantity.

	If Name = "" Then
		
		Name = Object.LocalName;
		
	EndIf; 
	
	While Object.Read() Do
		
		If Object.LocalName <> Name Then
			Continue;
		EndIf;
		
		NodeType = Object.NodeType;
			
		If NodeType = XMLNodeTypeEndElement Then
				
			If AttachmentsQuantity = 0 Then
					
				Break;
					
			Else
					
				AttachmentsQuantity = AttachmentsQuantity - 1;
					
			EndIf;
				
		ElsIf NodeType = XMLNodeTypeStartElement Then
				
			AttachmentsQuantity = AttachmentsQuantity + 1;
				
		EndIf;
					
	EndDo;
	
EndProcedure

// Reads item text and reduces value to the specified type.
//
// Parameters:
//  Object           - object of the XMLReading type from which reading is executed.
//  Type              - received value type.
//  SearchByProperty - for reference types a property can be specified
//                     according to which you should search for an object: "Code", "Name", <AttributeName>, "Name" (predefined value).
//
// Returns:
//  Xml-item value reduced to the corresponding type.
//
Function deItemValue(Object, Type, SearchByProperty = "", CutStringRight = True)

	Value = "";
	Name      = Object.LocalName;

	While Object.Read() Do
		
		NodeType = Object.NodeType;
		
		If NodeType = XMLNodeTypeText Then
			
			Value = Object.Value;
			
			If CutStringRight Then
				
				Value = TrimR(Value);
				
			EndIf;
						
		ElsIf (Object.LocalName = Name) AND (NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		Else
			
			Return Undefined;
			
		EndIf;
		
	EndDo;

	
	If (Type = StringType)
		OR (Type = BooleanType)
		OR (Type = NumberType)
		OR (Type = DateType)
		OR (Type = ValueStorageType)
		OR (Type = UUIDType)
		OR (Type = AccumulationRecordTypeType)
		OR (Type = AccountTypeKind)
		Then
		
		Return XMLValue(Type, Value);
		
	Else
		
		Return deGetValueByString(Value, Type, SearchByProperty);
		
	EndIf; 
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF WORK WITH EXCHANGE FILE

// Saves specified xml-node to file.
//
// Parameters:
//  Node           - xml-node saved to file.
//
Procedure WriteToFile(Node)

	If TypeOf(Node) <> StringType Then
		InformationToWriteToFile = Node.Close();
	Else
		InformationToWriteToFile = Node;
	EndIf;
	
	If IsExchangeOverExternalConnection() Then
		
		// ============================ {Begin: Exchange through external join}.
		DataProcessorForDataImport().ExternalConnectionImportDataFromXMLString(InformationToWriteToFile);
		
		If DataProcessorForDataImport().ErrorFlag() Then
			
			MessageString = NStr("en='OUTER JOIN: %1';ru='ВНЕШНЕЕ СОЕДИНЕНИЕ: %1'");
			MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, DataProcessorForDataImport().ErrorMessageString());
			ExchangeExecutionResultExternalConnection = Enums.ExchangeExecutionResult[DataProcessorForDataImport().ExchangeExecutionResultString()];
			WriteInExecutionProtocol(MessageString,,,,,, ExchangeExecutionResultExternalConnection);
			Raise MessageString;
			
		EndIf;
		// ============================ {End: Exchange through external join}.
		
	Else
		
		ExchangeFile.WriteLine(InformationToWriteToFile);
		
	EndIf;
	
EndProcedure

// Opens exchange file, writes file title according to the exchange format.
//
// Parameters:
//  No.
//
Function OpenExportFile()

	ExchangeFile = New TextWriter;
	Try
		ExchangeFile.Open(ExchangeFileName, TextEncoding.UTF8);
	Except
		ErrorPresentation = StringFunctionsClientServer.PlaceParametersIntoString(NStr("en='An error occurred while opening file for exchange message writing.
		|File name ""%1"".
		|Error
		|description: %2';ru='Ошибка при открытии файла для записи сообщения обмена.
		|Имя файла ""%1"".
		|Описание
		|ошибки: %2'"),
			String(ExchangeFileName),
			DetailErrorDescription(ErrorInfo())
		);
		WriteInExecutionProtocol(ErrorPresentation);
		Return "";
	EndTry;
	
	XMLInfoString = "<?xml version=""1.0"" encoding=""UTF-8""?>";
	
	ExchangeFile.WriteLine(XMLInfoString);

	TempXMLWriter = New XMLWriter();
	
	TempXMLWriter.SetString();
	
	TempXMLWriter.WriteStartElement("ExchangeFile");
	
	SetAttribute(TempXMLWriter, "FormatVersion", 				 VersionOfExchangeEventFormat());
	SetAttribute(TempXMLWriter, "ExportDate",				 CurrentSessionDate());
	SetAttribute(TempXMLWriter, "SourceConfigurationName",	 Conversion.Source);
	SetAttribute(TempXMLWriter, "SourceConfigurationVersion", Conversion.SourceConfigurationVersion);
	SetAttribute(TempXMLWriter, "TargetConfigurationName",	 Conversion.Receiver);
	SetAttribute(TempXMLWriter, "ConversionRuleIDs",		 Conversion.ID);
	
	TempXMLWriter.WriteEndElement();
	
	Str = TempXMLWriter.Close();
	
	Str = StrReplace(Str, "/>", ">");
	
	ExchangeFile.WriteLine(Str);
	
	Return XMLInfoString + Chars.LF + Str;
	
EndFunction

// Closes exchange file
//
// Parameters:
//  No.
//
Procedure CloseFile()
	
	ExchangeFile.WriteLine("</ExchangeFile>");
	ExchangeFile.Close();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF WORK WITH EXCHANGE PROTOCOL

// Returns the structure type object containing
// all possible fields of the execution protocol record (error messages etc.).
//
// Parameters:
//  No.
//
// Returns:
//  Object of the structure type
// 
Function GetProtocolRecordStructure(PErrorMessages = "", Val ErrorString = "")

	ErrorStructure = New Structure("OCRName,DERName,NPP,GSn,Source,ObjectType,Property,Value,ValueType,OCR,PCR,PGCR,DDR,DCR,Object,TargetProperty,ConvertedValue,Handler,ErrorDescription,ModulePosition,Text,PErrorMessages,ExchangePlanNode");
	
	ModuleString              = SeparateBySeparator(ErrorString, "{");
	ErrorDescription            = SeparateBySeparator(ModuleString, "}: ");
	
	If ErrorDescription <> "" Then
		
		ErrorStructure.ErrorDescription         = ErrorDescription;
		ErrorStructure.ModulePosition          = ModuleString;
				
	EndIf;
	
	If ErrorStructure.PErrorMessages <> "" Then
		
		ErrorStructure.PErrorMessages           = PErrorMessages;
		
	EndIf;
	
	Return ErrorStructure;
	
EndFunction 

Procedure ExchangeProtocolInitialization()
	
	If IsBlankString(ExchangeProtocolFileName) Then
		
		DataLogFile = Undefined;
		CommentObjectProcessingFlag = InfoMessagesOutputToMessagesWindow;		
		Return;
		
	Else	
		
		CommentObjectProcessingFlag = OutputInInformationMessagesToProtocol OR InfoMessagesOutputToMessagesWindow;		
		
	EndIf;
	
	// Try to write into file of the exchange protocol.
	Try
		DataLogFile = New TextWriter(ExchangeProtocolFileName, TextEncoding.ANSI, , AppendDataToExchangeProtocol);
	Except
		DataLogFile = Undefined;
		MessageString = NStr("en='Write to the data protocol file failed: %1. Error description: %2';ru='Ошибка при попытке записи в файл протокола данных: %1. Описание ошибки: %2'",
			CommonUseClientServer.MainLanguageCode());
		MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, ExchangeProtocolFileName, ErrorDescription());
		WriteLogEventDataExchange(MessageString, EventLogLevel.Warning);
	EndTry;
	
EndProcedure

Procedure FinishExchangeProtocolLogging()
	
	If DataLogFile <> Undefined Then
		
		DataLogFile.Close();
				
	EndIf;	
	
	DataLogFile = Undefined;
	
EndProcedure

Procedure SetExchangeProcessingResult(ExchangeProcessResult)
	
	CurrentResultIndex = PrioritiesOfExchangeResults().Find(ExchangeProcessResult());
	NewResultIndex   = PrioritiesOfExchangeResults().Find(ExchangeProcessResult);
	
	If CurrentResultIndex = Undefined Then
		CurrentResultIndex = 100
	EndIf;
	
	If NewResultIndex = Undefined Then
		NewResultIndex = 100
	EndIf;
	
	If NewResultIndex < CurrentResultIndex Then
		
		ExchangeResultField = ExchangeProcessResult;
		
	EndIf;
	
EndProcedure

Function ExchangeProcessResultError(ExchangeProcessResult)
	
	Return ExchangeProcessResult = Enums.ExchangeExecutionResult.Error
		OR ExchangeProcessResult = Enums.ExchangeExecutionResult.Error_MessageTransport;
	
EndFunction

Function ExchangeProcessResultWarning(ExchangeProcessResult)
	
	Return ExchangeProcessResult = Enums.ExchangeExecutionResult.CompletedWithWarnings
		OR ExchangeProcessResult = Enums.ExchangeExecutionResult.Warning_ExchangeMessageHasBeenPreviouslyReceived;
	
EndFunction

// Saves an execution protocol (or displays it) of the specified structure message.
//
// Parameters:
//  Code               - Number. Message code.
//  RecordStructure   - Structure. Structure of the protocol writing.
//  SetErrorFlag - If true, then - this error message. Display ErrorCheckBox.
// 
Function WriteInExecutionProtocol(Code = "",
									RecordStructure=Undefined,
									SetErrorFlag=True,
									Level=0,
									Align=22,
									ForceWritingToExchangeLog = False,
									Val ExchangeProcessResult = Undefined) Export
	//
	Indent = "";
	For Ct = 0 To Level-1 Do
		Indent = Indent + Chars.Tab;
	EndDo; 
	
	If TypeOf(Code) = NumberType Then
		
		If ErrorMessages = Undefined Then
			MessagesInitialization();
		EndIf;
		
		Str = ErrorMessages[Code];
		
	Else
		
		Str = String(Code);
		
	EndIf;

	Str = Indent + Str;
	
	If RecordStructure <> Undefined Then
		
		For Each Field IN RecordStructure Do
			
			Value = Field.Value;
			If Value = Undefined Then
				Continue;
			EndIf; 
			Key = Field.Key;
			Str  = Str + Chars.LF + Indent + Chars.Tab + deAddToString(Field.Key, Align) + " =  " + String(Value);
			
		EndDo;
		
	EndIf;
	
	TranslationLiteral = ?(IsBlankString(ErrorMessageString()), "", Chars.LF);
	
	ErrorMessageStringField = Str;
	
	If SetErrorFlag Then
		
		SetFlagOfError();
		
		ExchangeProcessResult = ?(ExchangeProcessResult = Undefined,
										Enums.ExchangeExecutionResult.Error,
										ExchangeProcessResult);
		//
	EndIf;
	
	SetExchangeProcessingResult(ExchangeProcessResult);
	
	If DataLogFile <> Undefined Then
		
		If SetErrorFlag Then
			
			DataLogFile.WriteLine(Chars.LF + "Error.");
			
		EndIf;
		
		If SetErrorFlag OR ForceWritingToExchangeLog OR OutputInInformationMessagesToProtocol Then
			
			DataLogFile.WriteLine(Chars.LF + ErrorMessageString());
		
		EndIf;
		
	EndIf;
	
	If ExchangeProcessResultError(ExchangeProcessResult) Then
		
		ELLevel = EventLogLevel.Error;
		
	ElsIf ExchangeProcessResultWarning(ExchangeProcessResult) Then
		
		ELLevel = EventLogLevel.Warning;
		
	Else
		
		ELLevel = EventLogLevel.Information;
		
	EndIf;
	
	// Note event in the event log.
	WriteLogEventDataExchange(ErrorMessageString(), ELLevel);
	
	Return ErrorMessageString();
	
EndFunction

Function WriteInformationAboutErrorToProtocol(PErrorMessages, ErrorString, Object, ObjectType = Undefined)
	
	LR         = GetProtocolRecordStructure(PErrorMessages, ErrorString);
	LR.Object  = Object;
	
	If ObjectType <> Undefined Then
		LR.ObjectType     = ObjectType;
	EndIf;	
		
	ErrorString = WriteInExecutionProtocol(PErrorMessages, LR);	
	
	Return ErrorString;
	
EndFunction

Procedure WriteInformationAboutDataClearHandlerError(PErrorMessages, ErrorString, DataClearingRuleName, Object = "", HandlerName = "")
	
	LR                        = GetProtocolRecordStructure(PErrorMessages, ErrorString);
	LR.DCR                    = DataClearingRuleName;
	
	If Object <> "" Then
		LR.Object                 = String(Object) + "  (" + TypeOf(Object) + ")";
	EndIf;
	
	If HandlerName <> "" Then
		LR.Handler             = HandlerName;
	EndIf;
	
	ErrorMessageString = WriteInExecutionProtocol(PErrorMessages, LR);
	
	If Not ContinueOnError Then
		Raise ErrorMessageString;
	EndIf;
	
EndProcedure

Procedure WriteInformationAboutOCRHandlerErrorImport(PErrorMessages, ErrorString, Rulename, Source = "", 
	ObjectType, Object = Undefined, HandlerName)
	
	LR                        = GetProtocolRecordStructure(PErrorMessages, ErrorString);
	LR.OCRName                 = Rulename;
	LR.ObjectType             = ObjectType;
	LR.Handler             = HandlerName;
						
	If Not IsBlankString(Source) Then
							
		LR.Source           = Source;
							
	EndIf;
						
	If Object <> Undefined Then
	
		LR.Object                 = String(Object);
		
	EndIf;
	
	ErrorMessageString = WriteInExecutionProtocol(PErrorMessages, LR);
	
	If Not ContinueOnError Then
		Raise ErrorMessageString;
	EndIf;
		
EndProcedure

Procedure WriteInformationAboutOCRHandlerErrorDump(PErrorMessages, ErrorString, OCR, Source, HandlerName)
	
	LR                        = GetProtocolRecordStructure(PErrorMessages, ErrorString);
	LR.OCR                    = OCR.Name + "  (" + OCR.Description + ")";
	
	Try
		LR.Object                 = String(Source) + "  (" + TypeOf(Source) + ")";
	Except
		LR.Object                 = "(" + TypeOf(Source) + ")";
	EndTry;
	
	LR.Handler             = HandlerName;
	
	ErrorMessageString = WriteInExecutionProtocol(PErrorMessages, LR);
	
	If Not ContinueOnError Then
		Raise ErrorMessageString;
	EndIf;
		
EndProcedure

Procedure WriteInformationAboutErrorPCRHandlers(PErrorMessages, ErrorString, OCR, PCR, Source = "", 
	HandlerName = "", Value = Undefined)
	
	LR                        = GetProtocolRecordStructure(PErrorMessages, ErrorString);
	LR.OCR                    = OCR.Name + "  (" + OCR.Description + ")";
	LR.PCR                    = PCR.Name + "  (" + PCR.Description + ")";
	
	Try
		LR.Object                 = String(Source) + "  (" + TypeOf(Source) + ")";
	Except
		LR.Object                 = "(" + TypeOf(Source) + ")";
	EndTry;
	
	LR.TargetProperty      = PCR.Receiver + "  (" + PCR.ReceiverType + ")";
	
	If HandlerName <> "" Then
		LR.Handler         = HandlerName;
	EndIf;
	
	If Value <> Undefined Then
		LR.ConvertedValue = String(Value) + "  (" + TypeOf(Value) + ")";
	EndIf;
	
	ErrorMessageString = WriteInExecutionProtocol(PErrorMessages, LR);
	
	If Not ContinueOnError Then
		Raise ErrorMessageString;
	EndIf;
		
EndProcedure	

Procedure WriteInformationAboutErrorDDRHandlers(PErrorMessages, ErrorString, Rulename, HandlerName, Object = Undefined)
	
	LR                        = GetProtocolRecordStructure(PErrorMessages, ErrorString);
	LR.DDR                    = Rulename;
	
	If Object <> Undefined Then
		LR.Object                 = String(Object) + "  (" + TypeOf(Object) + ")";
	EndIf;
	
	LR.Handler             = HandlerName;
	
	ErrorMessageString = WriteInExecutionProtocol(PErrorMessages, LR);
	
	If Not ContinueOnError Then
		Raise ErrorMessageString;
	EndIf;
	
EndProcedure

Function WriteInformationAboutErrorConversionHandlers(PErrorMessages, ErrorString, HandlerName)
	
	LR                        = GetProtocolRecordStructure(PErrorMessages, ErrorString);
	LR.Handler             = HandlerName;
	ErrorMessageString = WriteInExecutionProtocol(PErrorMessages, LR);
	Return ErrorMessageString;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// EXCHANGE RULES UPLOAD PROCEDURES

// Imports conversion rule of properties group.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  PropertyTable - values table containing PCR.
// 
Procedure ImportPGCR(ExchangeRules, PropertyTable, DisabledProperties, SynchronizeByID, OCRName = "")
	
	IsDisabledField = deAttribute(ExchangeRules, BooleanType, "Disable");
	
	If IsDisabledField Then
		
		NewRow = DisabledProperties.Add();
		
	Else
		
		NewRow = PropertyTable.Add();
		
	EndIf;
	
	NewRow.IsFolder     = True;
	
	NewRow.GroupRules            = PropertyConversionRuleTable.Copy();
	NewRow.DisabledGroupRules = PropertyConversionRuleTable.Copy();
	
	// Default values
	NewRow.Donotreplace               = False;
	NewRow.GetFromIncomingData = False;
	NewRow.SimplifiedPropertyExport = False;
	
	SearchFieldString = "";
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Source" Then
			NewRow.Source		= deAttribute(ExchangeRules, StringType, "Name");
			NewRow.SourceKind	= deAttribute(ExchangeRules, StringType, "Kind");
			NewRow.SourceType	= deAttribute(ExchangeRules, StringType, "Type");
			deIgnore(ExchangeRules);
			
		ElsIf NodeName = "Receiver" Then
			NewRow.Receiver		= deAttribute(ExchangeRules, StringType, "Name");
			NewRow.TargetKind	= deAttribute(ExchangeRules, StringType, "Kind");
			NewRow.ReceiverType	= deAttribute(ExchangeRules, StringType, "Type");
			deIgnore(ExchangeRules);
			
		ElsIf NodeName = "Property" Then
			
			PCRParent = ?(ValueIsFilled(NewRow.Source), "_" + NewRow.Source, "_" + NewRow.Receiver);
			ImportPCR(ExchangeRules, NewRow.GroupRules,, NewRow.DisabledGroupRules, SearchFieldString, SynchronizeByID, OCRName, PCRParent);

		ElsIf NodeName = "BeforeProcessExport" Then
			NewRow.BeforeProcessExport = deItemValue(ExchangeRules, StringType);
			NewRow.HasBeforeProcessExportHandler = Not IsBlankString(NewRow.BeforeProcessExport);
			
		ElsIf NodeName = "AfterProcessExport" Then
			NewRow.AfterProcessExport	= deItemValue(ExchangeRules, StringType);
			NewRow.HasAfterProcessExportHandler = Not IsBlankString(NewRow.AfterProcessExport);
			
		ElsIf NodeName = "Code" Then
			NewRow.Name = deItemValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "Description" Then
			NewRow.Description = deItemValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "Order" Then
			NewRow.Order = deItemValue(ExchangeRules, NumberType);
			
		ElsIf NodeName = "Donotreplace" Then
			NewRow.Donotreplace = deItemValue(ExchangeRules, BooleanType);
			
		ElsIf NodeName = "ConversionRuleCode" Then
			NewRow.ConversionRule = deItemValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "BeforeExport" Then
			NewRow.BeforeExport = deItemValue(ExchangeRules, StringType);
			NewRow.HasBeforeExportHandler = Not IsBlankString(NewRow.BeforeExport);
			
		ElsIf NodeName = "OnExport" Then
			NewRow.OnExport = deItemValue(ExchangeRules, StringType);
			NewRow.HasOnExportHandler    = Not IsBlankString(NewRow.OnExport);
			
		ElsIf NodeName = "AfterExport" Then
			NewRow.AfterExport = deItemValue(ExchangeRules, StringType);
	        NewRow.HasAfterExportHandler  = Not IsBlankString(NewRow.AfterExport);
			
		ElsIf NodeName = "ExportGroupToFile" Then
			NewRow.ExportGroupToFile = deItemValue(ExchangeRules, BooleanType);
			
		ElsIf NodeName = "GetFromIncomingData" Then
			NewRow.GetFromIncomingData = deItemValue(ExchangeRules, BooleanType);
			
		ElsIf (NodeName = "Group") AND (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
	If NewRow.HasBeforeProcessExportHandler Then
		
		HandlerName = "PGCR_[OCRName][PropertyNamePCR]_BeforeProcessExport_[PGCRName]_[OCRNameLength]";
		HandlerName = StrReplace(HandlerName, "[OCRName]", OCRName);
		HandlerName = StrReplace(HandlerName, "[PropertyNamePCR]", PropertyNamePCR(NewRow));
		HandlerName = StrReplace(HandlerName, "[PGCRName]", NewRow.Name);
		HandlerName = StrReplace(HandlerName, "[OCRNameLength]", StrLen(OCRName));
		NewRow.ProcessorsNameBeforeProcessingExportings = HandlerName;
		
	EndIf;
	
	If NewRow.HasAfterProcessExportHandler Then
		
		HandlerName = "PGCR_[OCRName][PropertyNamePCR]_AfterProcessExport_[PGCRName]_[OCRNameLength]";
		HandlerName = StrReplace(HandlerName, "[OCRName]", OCRName);
		HandlerName = StrReplace(HandlerName, "[PropertyNamePCR]", PropertyNamePCR(NewRow));
		HandlerName = StrReplace(HandlerName, "[PGCRName]", NewRow.Name);
		HandlerName = StrReplace(HandlerName, "[OCRNameLength]", StrLen(OCRName));
		NewRow.HandlerNameAfterDumpProcessing = HandlerName;
		
	EndIf;
	
	If NewRow.HasBeforeExportHandler Then
		
		HandlerName = "PGCR_[OCRName][PropertyNamePCR]_BeforeExportProperty_[PGCRName]_[OCRNameLength]";
		HandlerName = StrReplace(HandlerName, "[OCRName]", OCRName);
		HandlerName = StrReplace(HandlerName, "[PropertyNamePCR]", PropertyNamePCR(NewRow));
		HandlerName = StrReplace(HandlerName, "[PGCRName]", NewRow.Name);
		HandlerName = StrReplace(HandlerName, "[OCRNameLength]", StrLen(OCRName));
		NewRow.ProcessorsNameBeforeExport = HandlerName;

	EndIf;
	
	If NewRow.HasOnExportHandler Then
		
		HandlerName = "PGCR_[OCRName][PropertyNamePCR]_OnExportProperty_[PGCRName]_[OCRNameLength]";
		HandlerName = StrReplace(HandlerName, "[OCRName]", OCRName);
		HandlerName = StrReplace(HandlerName, "[PropertyNamePCR]", PropertyNamePCR(NewRow));
		HandlerName = StrReplace(HandlerName, "[PGCRName]", NewRow.Name);
		HandlerName = StrReplace(HandlerName, "[OCRNameLength]", StrLen(OCRName));
		NewRow.HandlerNameOnDump = HandlerName;

	EndIf;
	
	If NewRow.HasAfterExportHandler Then
		
		HandlerName = "PGCR_[OCRName][PropertyNamePCR]_AfterExportProperty_[PGCRName]_[OCRNameLength]";
		HandlerName = StrReplace(HandlerName, "[OCRName]", OCRName);
		HandlerName = StrReplace(HandlerName, "[PropertyNamePCR]", PropertyNamePCR(NewRow));
		HandlerName = StrReplace(HandlerName, "[PGCRName]", NewRow.Name);
		HandlerName = StrReplace(HandlerName, "[OCRNameLength]", StrLen(OCRName));
		NewRow.HandlerNameAfterDump = HandlerName;
		
	EndIf;
	
	NewRow.SearchFieldString = SearchFieldString;
	
	NewRow.XMLNodeRequiredOnExport = NewRow.HasOnExportHandler OR NewRow.HasAfterExportHandler;
	
	NewRow.XMLNodeRequiredOnExportGroup = NewRow.HasAfterProcessExportHandler; 

EndProcedure

Procedure AddFieldToSearchString(SearchFieldString, FieldName)
	
	If IsBlankString(FieldName) Then
		Return;
	EndIf;
	
	If Not IsBlankString(SearchFieldString) Then
		SearchFieldString = SearchFieldString + ",";
	EndIf;
	
	SearchFieldString = SearchFieldString + FieldName;
	
EndProcedure

// Imports properties conversion rule.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  PropertyTable - values table containing PCR.
//  SearchTable  - values table containing PCR (synchronizing).
// 
Procedure ImportPCR( ExchangeRules,
						PropertyTable,
						SearchTable = Undefined,
						DisabledProperties,
						SearchFieldString = "",
						SynchronizeByID = False,
						OCRName = "",
						ParentName = "")
	//
	
	IsDisabledField        = deAttribute(ExchangeRules, BooleanType, "Disable");
	IsSearchField           = deAttribute(ExchangeRules, BooleanType, "Search");
	IsRequiredProperty = deAttribute(ExchangeRules, BooleanType, "Required");
	
	If IsDisabledField Then
		
		NewRow = DisabledProperties.Add();
		
	ElsIf IsRequiredProperty AND SearchTable <> Undefined Then
		
		NewRow = SearchTable.Add();
		
	ElsIf IsSearchField AND SearchTable <> Undefined Then
		
		NewRow = SearchTable.Add();
		
	Else
		
		NewRow = PropertyTable.Add();
		
	EndIf;
	
	// Default values
	NewRow.Donotreplace               = False;
	NewRow.GetFromIncomingData = False;
	NewRow.IsRequiredProperty  = IsRequiredProperty;
	NewRow.IsSearchField            = IsSearchField;
		
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Source" Then
			NewRow.Source		= deAttribute(ExchangeRules, StringType, "Name");
			NewRow.SourceKind	= deAttribute(ExchangeRules, StringType, "Kind");
			NewRow.SourceType	= deAttribute(ExchangeRules, StringType, "Type");
			deIgnore(ExchangeRules);
			
		ElsIf NodeName = "Receiver" Then
			NewRow.Receiver		= deAttribute(ExchangeRules, StringType, "Name");
			NewRow.TargetKind	= deAttribute(ExchangeRules, StringType, "Kind");
			NewRow.ReceiverType	= deAttribute(ExchangeRules, StringType, "Type");
			
			If Not IsDisabledField Then
				
				// Fill in the "SearchFieldsString" variable to search by all attributes in TS for which there is PCR.
				AddFieldToSearchString(SearchFieldString, NewRow.Receiver);
				
			EndIf;
			
			deIgnore(ExchangeRules);
			
		ElsIf NodeName = "Code" Then
			NewRow.Name = deItemValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "Description" Then
			NewRow.Description = deItemValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "Order" Then
			NewRow.Order = deItemValue(ExchangeRules, NumberType);
			
		ElsIf NodeName = "Donotreplace" Then
			NewRow.Donotreplace = deItemValue(ExchangeRules, BooleanType);
			
		ElsIf NodeName = "ConversionRuleCode" Then
			NewRow.ConversionRule = deItemValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "BeforeExport" Then
			NewRow.BeforeExport = deItemValue(ExchangeRules, StringType);
			NewRow.HasBeforeExportHandler = Not IsBlankString(NewRow.BeforeExport);
			
		ElsIf NodeName = "OnExport" Then
			NewRow.OnExport = deItemValue(ExchangeRules, StringType);
			NewRow.HasOnExportHandler    = Not IsBlankString(NewRow.OnExport);
			
		ElsIf NodeName = "AfterExport" Then
			NewRow.AfterExport = deItemValue(ExchangeRules, StringType);
	        NewRow.HasAfterExportHandler  = Not IsBlankString(NewRow.AfterExport);
			
		ElsIf NodeName = "GetFromIncomingData" Then
			NewRow.GetFromIncomingData = deItemValue(ExchangeRules, BooleanType);
			
		ElsIf NodeName = "CastToLength" Then
			NewRow.CastToLength = deItemValue(ExchangeRules, NumberType);
			
		ElsIf NodeName = "ParameterForTransferName" Then
			NewRow.ParameterForTransferName = deItemValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "SearchByEqualDate" Then
			NewRow.SearchByEqualDate = deItemValue(ExchangeRules, BooleanType);
			
		ElsIf (NodeName = "Property") AND (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
	If NewRow.HasBeforeExportHandler Then
		
		HandlerName = "PCR_[OCRName][ParentName][PropertyNamePCR]_BeforeExportProperty_[PCRName]_[OCRNameLength]";
		HandlerName = StrReplace(HandlerName, "[OCRName]", OCRName);
		HandlerName = StrReplace(HandlerName, "[ParentName]", ParentName);
		HandlerName = StrReplace(HandlerName, "[PropertyNamePCR]", PropertyNamePCR(NewRow));
		HandlerName = StrReplace(HandlerName, "[PCRName]", NewRow.Name);
		HandlerName = StrReplace(HandlerName, "[OCRNameLength]", StrLen(OCRName));
		
		NewRow.ProcessorsNameBeforeExport = HandlerName;
		
	EndIf;
	
	If NewRow.HasOnExportHandler Then
		
		HandlerName = "PCR_[OCRName][ParentName][PropertyNamePCR]_OnExportProperty_[PCRName]_[OCRNameLength]";
		HandlerName = StrReplace(HandlerName, "[OCRName]", OCRName);
		HandlerName = StrReplace(HandlerName, "[ParentName]", ParentName);
		HandlerName = StrReplace(HandlerName, "[PropertyNamePCR]", PropertyNamePCR(NewRow));
		HandlerName = StrReplace(HandlerName, "[PCRName]", NewRow.Name);
		HandlerName = StrReplace(HandlerName, "[OCRNameLength]", StrLen(OCRName));
		
		NewRow.HandlerNameOnDump = HandlerName;
		
	EndIf;
	
	If NewRow.HasAfterExportHandler Then
		
		HandlerName = "PCR_[OCRName][ParentName][PropertyNamePCR]_AfterExportProperty_[PCRName]_[OCRNameLength]";
		HandlerName = StrReplace(HandlerName, "[OCRName]", OCRName);
		HandlerName = StrReplace(HandlerName, "[ParentName]", ParentName);
		HandlerName = StrReplace(HandlerName, "[PropertyNamePCR]", PropertyNamePCR(NewRow));
		HandlerName = StrReplace(HandlerName, "[PCRName]", NewRow.Name);
		HandlerName = StrReplace(HandlerName, "[OCRNameLength]", StrLen(OCRName));

		NewRow.HandlerNameAfterDump = HandlerName;
		
	EndIf;
	
	NewRow.SimplifiedPropertyExport = Not NewRow.GetFromIncomingData
		AND Not NewRow.HasBeforeExportHandler
		AND Not NewRow.HasOnExportHandler
		AND Not NewRow.HasAfterExportHandler
		AND IsBlankString(NewRow.ConversionRule)
		AND NewRow.SourceType = NewRow.ReceiverType
		AND (NewRow.SourceType = "String" OR NewRow.SourceType = "Number" OR NewRow.SourceType = "Boolean" OR NewRow.SourceType = "Date");
		
	NewRow.XMLNodeRequiredOnExport = NewRow.HasOnExportHandler OR NewRow.HasAfterExportHandler;
	
EndProcedure

// Imports properties conversion rules.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  PropertyTable - values table containing PCR.
//  SearchTable  - values table containing PCR (synchronizing).
// 
Procedure ImportProperties(ExchangeRules,
							PropertyTable,
							SearchTable,
							DisabledProperties,
							Val SynchronizeByID = False,
							OCRName = "")
	//
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Property" Then
			
			ImportPCR(ExchangeRules, PropertyTable, SearchTable, DisabledProperties,, SynchronizeByID, OCRName);
			
		ElsIf NodeName = "Group" Then
			
			ImportPGCR(ExchangeRules, PropertyTable, DisabledProperties, SynchronizeByID, OCRName);
			
		ElsIf (NodeName = "Properties") AND (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;
	
	PropertyTable.Sort("Order");
	SearchTable.Sort("Order");
	DisabledProperties.Sort("Order");
	
EndProcedure

// Imports values conversion rule.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  Values       - match of the source object values - String
//                   presentation of the receiver object.
//  SourceType   - value of the Type type - source object type.
// 
Procedure ImportVCR(ExchangeRules, Values, SourceType)
	
	Source = "";
	Receiver = "";
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Source" Then
			Source = deItemValue(ExchangeRules, StringType);
		ElsIf NodeName = "Receiver" Then
			Receiver = deItemValue(ExchangeRules, StringType);
		ElsIf (NodeName = "Value") AND (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
	If Not IsBlankString(Source) Then
		Values.Insert(Source, Receiver);
	EndIf;
	
EndProcedure

// Imports value conversion rules.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  Values       - match of the source object values - String
//                   presentation of the receiver object.
//  SourceType   - value of the Type type - source object type.
// 
Procedure LoadValues(ExchangeRules, Values, SourceType);

	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Value" Then
			ImportVCR(ExchangeRules, Values, SourceType);
		ElsIf (NodeName = "Values") AND (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports objects conversion rule.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  XMLWriter      - Object of the XMLWriter type - rules saved to the exchange
//                   file and used while importing data.
// 
Procedure ImportConversionRule(ExchangeRules, XMLWriter)

	XMLWriter.WriteStartElement("Rule");

	NewRow = ConversionRulesTable.Add();
	
	// Default values
	
	NewRow.RememberExported = True;
	NewRow.Donotreplace            = False;
	NewRow.ExchangeObjectPriority = Enums.ExchangeObjectPriorities.PriorityOfObjectReceivedOnExchangeIsHigher;
	
	SearchInTabularSections = New ValueTable;
	SearchInTabularSections.Columns.Add("ItemName");
	SearchInTabularSections.Columns.Add("KeySearchFieldArray");
	SearchInTabularSections.Columns.Add("KeySearchFields");
	SearchInTabularSections.Columns.Add("Valid", deDescriptionType("Boolean"));
	
	NewRow.SearchInTabularSections = SearchInTabularSections;		
	
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
				
		If      NodeName = "Code" Then
			
			Value = deItemValue(ExchangeRules, StringType);
			deWriteItem(XMLWriter, NodeName, Value);
			NewRow.Name = Value;
			
		ElsIf NodeName = "Description" Then
			
			NewRow.Description = deItemValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "SynchronizeByID" Then
			
			NewRow.SynchronizeByID = deItemValue(ExchangeRules, BooleanType);
			deWriteItem(XMLWriter, NodeName, NewRow.SynchronizeByID);
			
		ElsIf NodeName = "DoNotCreateIfNotFound" Then
			
			NewRow.DoNotCreateIfNotFound = deItemValue(ExchangeRules, BooleanType);			
			
		ElsIf NodeName = "RecordObjectChangeAtSenderNode" Then // is not supported
			
			deIgnore(ExchangeRules);
			
		ElsIf NodeName = "DontExportPropertyObjectsByRefs" Then
			
			NewRow.DontExportPropertyObjectsByRefs = deItemValue(ExchangeRules, BooleanType);
						
		ElsIf NodeName = "SearchBySearchFieldsIfNotFoundByID" Then
			
			NewRow.SearchBySearchFieldsIfNotFoundByID = deItemValue(ExchangeRules, BooleanType);	
			deWriteItem(XMLWriter, NodeName, NewRow.SearchBySearchFieldsIfNotFoundByID);
			
		ElsIf NodeName = "OnExchangeObjectByRefSetGIUDOnly" Then
			
			NewRow.OnExchangeObjectByRefSetGIUDOnly = deItemValue(ExchangeRules, BooleanType);	
			deWriteItem(XMLWriter, NodeName, NewRow.OnExchangeObjectByRefSetGIUDOnly);
			
		ElsIf NodeName = "DontReplaceCreatedInTargetObject" Then
			
			NewRow.DontReplaceCreatedInTargetObject = deItemValue(ExchangeRules, BooleanType);	
			deWriteItem(XMLWriter, NodeName, NewRow.DontReplaceCreatedInTargetObject);		
			
		ElsIf NodeName = "UseQuickSearchOnImport" Then
			
			NewRow.UseQuickSearchOnImport = deItemValue(ExchangeRules, BooleanType);	
			
		ElsIf NodeName = "Generatenewnumberorcodeifnotspecified" Then
			
			NewRow.Generatenewnumberorcodeifnotspecified = deItemValue(ExchangeRules, BooleanType);
			deWriteItem(XMLWriter, NodeName, NewRow.Generatenewnumberorcodeifnotspecified);
						
		ElsIf NodeName = "DontRememberExported" Then
			
			NewRow.RememberExported = Not deItemValue(ExchangeRules, BooleanType);
			
		ElsIf NodeName = "Donotreplace" Then
			
			Value = deItemValue(ExchangeRules, BooleanType);
			deWriteItem(XMLWriter, NodeName, Value);
			NewRow.Donotreplace = Value;
			
		ElsIf NodeName = "Receiver" Then
			
			Value = deItemValue(ExchangeRules, StringType);
			deWriteItem(XMLWriter, NodeName, Value);
			
			NewRow.Receiver     = Value;
			NewRow.ReceiverType = Value;
			
		ElsIf NodeName = "Source" Then
			
			Value = deItemValue(ExchangeRules, StringType);
			deWriteItem(XMLWriter, NodeName, Value);
			
			NewRow.SourceType = Value;
			
			If ExchangeMode = "Import" Then
				
				NewRow.Source = Value;
				
			Else
				
				If Not IsBlankString(Value) Then
					
					If Not ExchangeRuleInfoImportMode Then
						
						Try
							
							NewRow.Source = Type(Value);
							
							Managers[NewRow.Source].OCR = NewRow;
							
						Except
							
							WriteInformationAboutErrorToProtocol(11, ErrorDescription(), String(NewRow.Source));
							
						EndTry;
					
					EndIf;
					
				EndIf;
				
			EndIf;
			
		// Properties
		
		ElsIf NodeName = "Properties" Then
		
			NewRow.Properties            = PropertyConversionRuleTable.Copy();
			NewRow.SearchProperties      = PropertyConversionRuleTable.Copy();
			NewRow.DisabledProperties = PropertyConversionRuleTable.Copy();
			
			If NewRow.SynchronizeByID = True Then
				
				SearchPropertyUUID = NewRow.SearchProperties.Add();
				SearchPropertyUUID.Name      = "{UUID}";
				SearchPropertyUUID.Source = "{UUID}";
				SearchPropertyUUID.Receiver = "{UUID}";
				SearchPropertyUUID.IsRequiredProperty = True;
				
			EndIf;
			
			ImportProperties(ExchangeRules, NewRow.Properties, NewRow.SearchProperties, NewRow.DisabledProperties, NewRow.SynchronizeByID, NewRow.Name);
			
		// Values
		ElsIf NodeName = "Values" Then
			
			LoadValues(ExchangeRules, NewRow.ValuesOfPredefinedDataRead, NewRow.Source);
			
		// EVENT HANDLERS
		ElsIf NodeName = "BeforeExport" Then
		
			NewRow.BeforeExport = deItemValue(ExchangeRules, StringType);
			HandlerName = "OCR_[OCRName]_BeforeObjectExport";
			NewRow.ProcessorsNameBeforeExport = StrReplace(HandlerName, "[OCRName]", NewRow.Name);
			NewRow.HasBeforeExportHandler = Not IsBlankString(NewRow.BeforeExport);
			
		ElsIf NodeName = "OnExport" Then
			
			NewRow.OnExport = deItemValue(ExchangeRules, StringType);
			HandlerName = "OCR_[OCRName]_OnExportObject";
			NewRow.HandlerNameOnDump = StrReplace(HandlerName, "[OCRName]", NewRow.Name);
			NewRow.HasOnExportHandler    = Not IsBlankString(NewRow.OnExport);
			
		ElsIf NodeName = "AfterExport" Then
			
			NewRow.AfterExport = deItemValue(ExchangeRules, StringType);
			HandlerName = "OCR_[OCRName]_AfterObjectExport";
			NewRow.HandlerNameAfterDump = StrReplace(HandlerName, "[OCRName]", NewRow.Name);
			NewRow.HasAfterExportHandler  = Not IsBlankString(NewRow.AfterExport);
			
		ElsIf NodeName = "AfterExportToFile" Then
			
			NewRow.AfterExportToFile = deItemValue(ExchangeRules, StringType);
			HandlerName = "OCR_[OCRName]_AfterObjectExportToExchangeFile";
			NewRow.HandlerNameAfterDumpToFile = StrReplace(HandlerName, "[OCRName]", NewRow.Name);
			NewRow.HasAfterExportToFileHandler  = Not IsBlankString(NewRow.AfterExportToFile);
			
		// For import
		
		ElsIf NodeName = "BeforeImport" Then
			
			Value = deItemValue(ExchangeRules, StringType);
			
			If ExchangeMode = "Import" Then
				
				NewRow.BeforeImport               = Value;
				HandlerName = "OCR_[OCRName]_BeforeObjectImport";
				NewRow.HandlerNameBeforeImport = StrReplace(HandlerName, "[OCRName]", NewRow.Name);
				NewRow.HasBeforeImportHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteItem(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "OnImport" Then
			
			Value = deItemValue(ExchangeRules, StringType);
			
			If ExchangeMode = "Import" Then
				
				NewRow.OnImport               = Value;
				HandlerName = "OCR_[OCRName]_OnImportObject";
				NewRow.OnImportingNameProcessors = StrReplace(HandlerName, "[OCRName]", NewRow.Name);
				NewRow.HasOnImportHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteItem(XMLWriter, NodeName, Value);
				
			EndIf; 
			
		ElsIf NodeName = "AfterImport" Then
			
			Value = deItemValue(ExchangeRules, StringType);
			
			If ExchangeMode = "Import" Then
				
				NewRow.AfterImport               = Value;
				HandlerName = "OCR_[OCRName]_AftertObjectImport";
				NewRow.ProcessorsNameAfterImport = StrReplace(HandlerName, "[OCRName]", NewRow.Name);
				NewRow.HasAfterImportHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteItem(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "SearchFieldSequence" Then
			
			Value = deItemValue(ExchangeRules, StringType);
			NewRow.HasSearchFieldSequenceHandler = Not IsBlankString(Value);
			
			If ExchangeMode = "Import" Then
				
				NewRow.SearchFieldSequence = Value;
				HandlerName = "OCR_[OCRName]_SearchFieldSequence";
				NewRow.HandlerNameSearchFieldsSequence = StrReplace(HandlerName, "[OCRName]", NewRow.Name);
				
			Else
				
				deWriteItem(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "ExchangeObjectPriority" Then
			
			Value = deItemValue(ExchangeRules, StringType);
			
			If Value = "below" Then
				NewRow.ExchangeObjectPriority = Enums.ExchangeObjectPriorities.PriorityOfObjectReceivedOnExchangeIsLower;
			ElsIf Value = "Matches" Then
				NewRow.ExchangeObjectPriority = Enums.ExchangeObjectPriorities.PriorityOfObjectReceivedOnExchangeIsTheSame;
			EndIf;
			
		// Search variants settings.
		ElsIf NodeName = "ObjectSearchVariantSetup" Then
		
			LoadVariantSearchSettings(ExchangeRules, NewRow);
			
		ElsIf NodeName = "SearchInTabularSections" Then
			
			// Import information about key search fields in the tabular sections.
			Value = deItemValue(ExchangeRules, StringType);
			
			For Number = 1 To StrLineCount(Value) Do
				
				CurrentRow = StrGetLine(Value, Number);
				
				SearchString = SeparateBySeparator(CurrentRow, ":");
				
				TableRow = NewRow.SearchInTabularSections.Add();
				
				TableRow.ItemName               = CurrentRow;
				TableRow.KeySearchFields        = SearchString;
				TableRow.KeySearchFieldArray = GetArrayFromString(SearchString);
				TableRow.Valid                  = TableRow.KeySearchFieldArray.Count() <> 0;
				
			EndDo;
			
		ElsIf NodeName = "SearchFields" Then
			
			NewRow.SearchFields = deItemValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "TableFields" Then
			
			NewRow.TableFields = deItemValue(ExchangeRules, StringType);
			
		ElsIf (NodeName = "Rule") AND (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
		
			Break;
			
		EndIf;
		
	EndDo;
	
	If ExchangeMode <> "Import" Then
		
		// GET PROPERTIES TS FIELDS SEARCH FOR DATA UPLOAD RULES (XMLWriter)
		
		ResultingTSSearchString = "";
		
		// Pass information about search fields for the tabular sections to the receiver.
		For Each PropertiesString IN NewRow.Properties Do
			
			If Not PropertiesString.IsFolder
				OR IsBlankString(PropertiesString.TargetKind)
				OR IsBlankString(PropertiesString.Receiver) Then
				
				Continue;
				
			EndIf;
			
			If IsBlankString(PropertiesString.SearchFieldString) Then
				Continue;
			EndIf;
			
			ResultingTSSearchString = ResultingTSSearchString + Chars.LF + PropertiesString.TargetKind + "." + PropertiesString.Receiver + ":" + PropertiesString.SearchFieldString;
			
		EndDo;
		
		ResultingTSSearchString = TrimAll(ResultingTSSearchString);
		
		If Not IsBlankString(ResultingTSSearchString) Then
			
			deWriteItem(XMLWriter, "SearchInTabularSections", ResultingTSSearchString);
			
		EndIf;
		
		// GET TABLE FIELDS AND SEARCH FIELDS FOR DATA UPLOAD RULES (XMLWriter)
		
		ArrayProperties = NewRow.Properties.Copy(New Structure("IsFolder, ParameterForTransferName", False, ""), "Receiver").UnloadColumn("Receiver");
		
		ArraySearchProperties               = NewRow.SearchProperties.Copy(New Structure("IsFolder, ParameterForTransferName", False, ""), "Receiver").UnloadColumn("Receiver");
		SearchPropertyAdditionalArray = NewRow.Properties.Copy(New Structure("IsSearchField, ParameterForTransferName", True, ""), "Receiver").UnloadColumn("Receiver");
		
		For Each Value IN SearchPropertyAdditionalArray Do
			
			ArraySearchProperties.Add(Value);
			
		EndDo;
		
		// Delete search value from fields array (UUID).
		CommonUseClientServer.DeleteValueFromArray(ArraySearchProperties, "{UUID}");
		
		// Get the PropertiesArray variable value.
		TableFieldsTable = New ValueTable;
		TableFieldsTable.Columns.Add("Receiver");
		
		CommonUseClientServer.SupplementTableFromArray(TableFieldsTable, ArrayProperties, "Receiver");
		CommonUseClientServer.SupplementTableFromArray(TableFieldsTable, ArraySearchProperties, "Receiver");
		
		TableFieldsTable.GroupBy("Receiver");
		ArrayProperties = TableFieldsTable.UnloadColumn("Receiver");
		
		TableFields = StringFunctionsClientServer.RowFromArraySubrows(ArrayProperties);
		SearchFields  = StringFunctionsClientServer.RowFromArraySubrows(ArraySearchProperties);
		
		If Not IsBlankString(TableFields) Then
			deWriteItem(XMLWriter, "TableFields", TableFields);
		EndIf;
		
		If Not IsBlankString(SearchFields) Then
			deWriteItem(XMLWriter, "SearchFields", SearchFields);
		EndIf;
		
	EndIf;
	
	// close node
	XMLWriter.WriteEndElement(); // Rule
	
	// Quick access to OCR by name.
	Rules.Insert(NewRow.Name, NewRow);
	
EndProcedure

Procedure ImportSearchVariantsSetting(ExchangeRules, NewRow)
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		NodeType = ExchangeRules.NodeType;
		
		If NodeName = "AlgorithmSettingName" Then
			
			Value = deItemValue(ExchangeRules, StringType);
			If ExchangeRuleInfoImportMode Then
				NewRow.AlgorithmSettingName = Value;
			EndIf;
			
		ElsIf NodeName = "UserSettingsName" Then
			
			Value = deItemValue(ExchangeRules, StringType);
			If ExchangeRuleInfoImportMode Then
				NewRow.UserSettingsName = Value;
			EndIf;
			
		ElsIf NodeName = "SettingDetailsForUser" Then
			
			Value = deItemValue(ExchangeRules, StringType);
			If ExchangeRuleInfoImportMode Then
				NewRow.SettingDetailsForUser = Value;
			EndIf;
			
		ElsIf (NodeName = "SearchVariant") AND (NodeType = XMLNodeTypeEndElement) Then
			Break;
		Else
		EndIf;
		
	EndDo;	
	
EndProcedure

Procedure LoadVariantSearchSettings(ExchangeRules, BaseOCRString)

	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		NodeType = ExchangeRules.NodeType;
		
		If NodeName = "SearchVariant" Then
			
			If ExchangeRuleInfoImportMode Then
				SettingRow = SearchFieldInfoImportResultTable.Add();
				SettingRow.ExchangeRuleCode = BaseOCRString.Name;
				SettingRow.ExchangeRuleDescription = BaseOCRString.Description;
			Else
				SettingRow = Undefined;
			EndIf;
			
			ImportSearchVariantsSetting(ExchangeRules, SettingRow);
			
		ElsIf (NodeName = "ObjectSearchVariantSetup") AND (NodeType = XMLNodeTypeEndElement) Then
			Break;
		Else
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports objects conversion rules.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  XMLWriter      - Object of the XMLWriter type - rules saved to the exchange
//                   file and used while importing data.
// 
Procedure ImportConversionRules(ExchangeRules, XMLWriter)
	
	ConversionRulesTable.Clear();
	
	XMLWriter.WriteStartElement("ObjectConversionRules");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Rule" Then
			
			ImportConversionRule(ExchangeRules, XMLWriter);
			
		ElsIf (NodeName = "ObjectConversionRules") AND (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;
	
	ImportConversionRule_ExchangeObjectsExportModes(XMLWriter);
	
	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports data clearing rules group according to the exchange rules format.
//
// Parameters:
//  NewRow    - values tree string describing data clearing rules group.
// 
Procedure ImportGroupDCR(ExchangeRules, NewRow)

	NewRow.IsFolder = True;
	NewRow.Enable  = Number(NOT deAttribute(ExchangeRules, BooleanType, "Disable"));
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		NodeType = ExchangeRules.NodeType;
		
		If      NodeName = "Code" Then
			NewRow.Name = deItemValue(ExchangeRules, StringType);

		ElsIf NodeName = "Description" Then
			NewRow.Description = deItemValue(ExchangeRules, StringType);
		
		ElsIf NodeName = "Order" Then
			NewRow.Order = deItemValue(ExchangeRules, NumberType);
			
		ElsIf NodeName = "Rule" Then
			VTRow = NewRow.Rows.Add();
			ImportDCR(ExchangeRules, VTRow);
			
		ElsIf (NodeName = "Group") AND (NodeType = XMLNodeTypeStartElement) Then
			VTRow = NewRow.Rows.Add();
			ImportGroupDCR(ExchangeRules, VTRow);
			
		ElsIf (NodeName = "Group") AND (NodeType = XMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;

	
	If IsBlankString(NewRow.Description) Then
		NewRow.Description = NewRow.Name;
	EndIf; 
	
EndProcedure

// Imports data clearing rules according to the exchange rules format.
//
// Parameters:
//  NewRow    - values tree string describing data clearing rules.
// 
Procedure ImportDCR(ExchangeRules, NewRow)
	
	NewRow.Enable = Number(NOT deAttribute(ExchangeRules, BooleanType, "Disable"));
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Code" Then
			Value = deItemValue(ExchangeRules, StringType);
			NewRow.Name = Value;

		ElsIf NodeName = "Description" Then
			NewRow.Description = deItemValue(ExchangeRules, StringType);
		
		ElsIf NodeName = "Order" Then
			NewRow.Order = deItemValue(ExchangeRules, NumberType);
			
		ElsIf NodeName = "DataSelectionVariant" Then
			NewRow.DataSelectionVariant = deItemValue(ExchangeRules, StringType);

		ElsIf NodeName = "SelectionObject" Then
			
			If Not ExchangeRuleInfoImportMode Then
			
				SelectionObject = deItemValue(ExchangeRules, StringType);
				If Not IsBlankString(SelectionObject) Then
					NewRow.SelectionObject = Type(SelectionObject);
				EndIf;
				
			EndIf;

		ElsIf NodeName = "DeleteForPeriod" Then
			NewRow.DeleteForPeriod = deItemValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "Directly" Then
			NewRow.Directly = deItemValue(ExchangeRules, BooleanType);

		
		// EVENT HANDLERS

		ElsIf NodeName = "BeforeProcessRule" Then
			NewRow.BeforeProcess = deItemValue(ExchangeRules, StringType);
			HandlerName = "DCR_[DERName]_BeforeProcessRule";
			NewRow.ProcessorsNameBeforeProcessing = StrReplace(HandlerName, "[DERName]", NewRow.Name);
			
		ElsIf NodeName = "AfterProcessRule" Then
			NewRow.AfterProcessing = deItemValue(ExchangeRules, StringType);
			HandlerName = "DCR_[DERName]_AfterProcessRule";
			NewRow.ProcessorsNameAfterProcessing = StrReplace(HandlerName, "[DERName]", NewRow.Name);
			
		ElsIf NodeName = "BeforeDeleteObject" Then
			NewRow.BeforeDelete = deItemValue(ExchangeRules, StringType);
			HandlerName = "DCR_[DERName]_BeforeDeleteObject";
			NewRow.HandlerNameBeforeDeletion = StrReplace(HandlerName, "[DERName]", NewRow.Name);
			
		// Exit
		ElsIf (NodeName = "Rule") AND (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			Break;
			
		EndIf;
		
	EndDo;

	
	If IsBlankString(NewRow.Description) Then
		NewRow.Description = NewRow.Name;
	EndIf; 
	
EndProcedure

// Imports data clearing rules.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  XMLWriter      - Object of the XMLWriter type - rules saved to the exchange
//                   file and used while importing data.
// 
Procedure ImportClearRules(ExchangeRules, XMLWriter)

	FlushRulesTable.Rows.Clear();
	VTRows = FlushRulesTable.Rows;
	
	XMLWriter.WriteStartElement("DataClearingRules");

	While ExchangeRules.Read() Do
		
		NodeType = ExchangeRules.NodeType;
		
		If NodeType = XMLNodeTypeStartElement Then
			NodeName = ExchangeRules.LocalName;
			If ExchangeMode <> "Import" Then
				XMLWriter.WriteStartElement(ExchangeRules.Name);
				While ExchangeRules.ReadAttribute() Do
					XMLWriter.WriteAttribute(ExchangeRules.Name, ExchangeRules.Value);
				EndDo;
			Else
				If NodeName = "Rule" Then
					VTRow = VTRows.Add();
					ImportDCR(ExchangeRules, VTRow);
				ElsIf NodeName = "Group" Then
					VTRow = VTRows.Add();
					ImportGroupDCR(ExchangeRules, VTRow);
				EndIf;
			EndIf;
		ElsIf NodeType = XMLNodeTypeEndElement Then
			NodeName = ExchangeRules.LocalName;
			If NodeName = "DataClearingRules" Then
				Break;
			Else
				If ExchangeMode <> "Import" Then
					XMLWriter.WriteEndElement();
				EndIf;
			EndIf;
		ElsIf NodeType = XMLNodeTypeText Then
			If ExchangeMode <> "Import" Then
				XMLWriter.WriteText(ExchangeRules.Value);
			EndIf;
		EndIf; 
	EndDo;

	VTRows.Sort("Order", True);
	
	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports algorithm according to the exchange rules format.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  XMLWriter      - Object of the XMLWriter type - rules saved to the exchange
//                   file and used while importing data.
// 
Procedure ImportAlgorithm(ExchangeRules, XMLWriter)

	UsedOnImport = deAttribute(ExchangeRules, BooleanType, "UsedOnImport");
	Name                     = deAttribute(ExchangeRules, StringType, "Name");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Text" Then
			Text = deItemValue(ExchangeRules, StringType);
		ElsIf (NodeName = "Algorithm") AND (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			Break;
		Else
			deIgnore(ExchangeRules);
		EndIf;
		
	EndDo;

	
	If UsedOnImport Then
		If ExchangeMode = "Import" Then
			Algorithms.Insert(Name, Text);
		Else
			XMLWriter.WriteStartElement("Algorithm");
			SetAttribute(XMLWriter, "UsedOnImport", True);
			SetAttribute(XMLWriter, "Name",   Name);
			deWriteItem(XMLWriter, "Text", Text);
			XMLWriter.WriteEndElement();
		EndIf;
	Else
		If ExchangeMode <> "Import" Then
			Algorithms.Insert(Name, Text);
		EndIf;
	EndIf;
	
	
EndProcedure

// Imports algorithms according to the exchange rules format.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  XMLWriter      - Object of the XMLWriter type - rules saved to the exchange
//                   file and used while importing data.
// 
Procedure ImportAlgorithms(ExchangeRules, XMLWriter)

	Algorithms.Clear();

	XMLWriter.WriteStartElement("Algorithms");
	
	While ExchangeRules.Read() Do
		NodeName = ExchangeRules.LocalName;
		If      NodeName = "Algorithm" Then
			ImportAlgorithm(ExchangeRules, XMLWriter);
		ElsIf (NodeName = "Algorithms") AND (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;

	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports query according to the exchange rules format.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  XMLWriter      - Object of the XMLWriter type - rules saved to the exchange
//                   file and used while importing data.
// 
Procedure ImportQuery(ExchangeRules, XMLWriter)

	UsedOnImport = deAttribute(ExchangeRules, BooleanType, "UsedOnImport");
	Name                     = deAttribute(ExchangeRules, StringType, "Name");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Text" Then
			Text = deItemValue(ExchangeRules, StringType);
		ElsIf (NodeName = "Query") AND (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			Break;
		Else
			deIgnore(ExchangeRules);
		EndIf;
		
	EndDo;

	If UsedOnImport Then
		If ExchangeMode = "Import" Then
			Query	= New Query(Text);
			Queries.Insert(Name, Query);
		Else
			XMLWriter.WriteStartElement("Query");
			SetAttribute(XMLWriter, "UsedOnImport", True);
			SetAttribute(XMLWriter, "Name",   Name);
			deWriteItem(XMLWriter, "Text", Text);
			XMLWriter.WriteEndElement();
		EndIf;
	Else
		If ExchangeMode <> "Import" Then
			Query	= New Query(Text);
			Queries.Insert(Name, Query);
		EndIf;
	EndIf;
	
EndProcedure

// Imports queries according to the exchange rules format.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  XMLWriter      - Object of the XMLWriter type - rules saved to the exchange
//                   file and used while importing data.
// 
Procedure ImportQueries(ExchangeRules, XMLWriter)

	Queries.Clear();

	XMLWriter.WriteStartElement("Queries");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Query" Then
			ImportQuery(ExchangeRules, XMLWriter);
		ElsIf (NodeName = "Queries") AND (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;

	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports parameters according to the exchange rules format.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
// 
Procedure ImportParameters(ExchangeRules, XMLWriter)

	Parameters.Clear();
	EventsAfterParameterImport.Clear();
	ParametersSettingsTable.Clear();
	
	XMLWriter.WriteStartElement("Parameters");
	
	While ExchangeRules.Read() Do
		NodeName = ExchangeRules.LocalName;
		NodeType = ExchangeRules.NodeType;

		If NodeName = "Parameter" AND NodeType = XMLNodeTypeStartElement Then
			
			// Import by rules version 2.01.
			Name                     = deAttribute(ExchangeRules, StringType, "Name");
			Description            = deAttribute(ExchangeRules, StringType, "Description");
			SetInDialog   = deAttribute(ExchangeRules, BooleanType, "SetInDialog");
			ValueTypeString      = deAttribute(ExchangeRules, StringType, "ValueType");
			UsedOnImport = deAttribute(ExchangeRules, BooleanType, "UsedOnImport");
			PassParameterOnExport = deAttribute(ExchangeRules, BooleanType, "PassParameterOnExport");
			ConversionRule = deAttribute(ExchangeRules, StringType, "ConversionRule");
			AfterParameterImportAlgorithm = deAttribute(ExchangeRules, StringType, "AfterParameterImport");
			
			If Not IsBlankString(AfterParameterImportAlgorithm) Then
				
				EventsAfterParameterImport.Insert(Name, AfterParameterImportAlgorithm);
				
			EndIf;
			
			// Determine value types and set initial values.
			If Not IsBlankString(ValueTypeString) Then
				
				Try
					DataValueType = Type(ValueTypeString);
					TypeDefined = TRUE;
				Except
					TypeDefined = FALSE;
				EndTry;
				
			Else
				
				TypeDefined = FALSE;
				
			EndIf;
			
			If TypeDefined Then
				ParameterValue = deGetBlankValue(DataValueType);
				Parameters.Insert(Name, ParameterValue);
			Else
				ParameterValue = "";
				Parameters.Insert(Name);
			EndIf;
						
			If SetInDialog = TRUE Then
				
				TableRow              = ParametersSettingsTable.Add();
				TableRow.Description = Description;
				TableRow.Name          = Name;
				TableRow.Value = ParameterValue;				
				TableRow.PassParameterOnExport = PassParameterOnExport;
				TableRow.ConversionRule = ConversionRule;
				
			EndIf;
			
			If UsedOnImport
				AND ExchangeMode = "Export" Then
				
				XMLWriter.WriteStartElement("Parameter");
				SetAttribute(XMLWriter, "Name",   Name);
				SetAttribute(XMLWriter, "Description", Description);
					
				If Not IsBlankString(AfterParameterImportAlgorithm) Then
					SetAttribute(XMLWriter, "AfterParameterImport", XMLString(AfterParameterImportAlgorithm));
				EndIf;
				
				XMLWriter.WriteEndElement();
				
			EndIf;

		ElsIf (NodeType = XMLNodeTypeText) Then
			
			// For compatibility with rules version 2.0 use import from string.
			ParameterString = ExchangeRules.Value;
			For Each Param IN ArrayFromString(ParameterString) Do
				Parameters.Insert(Param);
			EndDo;
			
		ElsIf (NodeName = "Parameters") AND (NodeType = XMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;

	XMLWriter.WriteEndElement();

EndProcedure

// Imports data processor according to the exchange rules format.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  XMLWriter      - Object of the XMLWriter type - rules saved to the exchange
//                   file and used while importing data.
// 
Procedure ImportDataProcessor(ExchangeRules, XMLWriter)

	Name                     = deAttribute(ExchangeRules, StringType, "Name");
	Description            = deAttribute(ExchangeRules, StringType, "Description");
	IsSetupDataProcessor   = deAttribute(ExchangeRules, BooleanType, "IsSetupDataProcessor");
	
	UsedOnExport = deAttribute(ExchangeRules, BooleanType, "UsedOnExport");
	UsedOnImport = deAttribute(ExchangeRules, BooleanType, "UsedOnImport");

	ParameterString        = deAttribute(ExchangeRules, StringType, "Parameters");
	
	DataProcessorStorage      = deItemValue(ExchangeRules, ValueStorageType);

	AdditionalInformationProcessorParameters.Insert(Name, ArrayFromString(ParameterString));
	
	
	If UsedOnImport Then
		If ExchangeMode <> "Import" Then
			XMLWriter.WriteStartElement("DataProcessor");
			SetAttribute(XMLWriter, "UsedOnImport", True);
			SetAttribute(XMLWriter, "Name",                     Name);
			SetAttribute(XMLWriter, "Description",            Description);
			SetAttribute(XMLWriter, "IsSetupDataProcessor",   IsSetupDataProcessor);
			XMLWriter.WriteText(XMLString(DataProcessorStorage));
			XMLWriter.WriteEndElement();
		EndIf;
	EndIf;

	If IsSetupDataProcessor Then
		If (ExchangeMode = "Import") AND UsedOnImport Then
			ImportConfigurationProcedures.Add(Name, Description, , );
			
		ElsIf (ExchangeMode = "Export") AND UsedOnExport Then
			DumpConfigurationProcedures.Add(Name, Description, , );
			
		EndIf; 
	EndIf; 
	
EndProcedure

// Imports external data processors according to the exchange rules format.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  XMLWriter      - Object of the XMLWriter type - rules saved to the exchange
//                   file and used while importing data.
// 
Procedure ImportDataProcessors(ExchangeRules, XMLWriter)

	AdditionalInformationProcessors.Clear();
	AdditionalInformationProcessorParameters.Clear();
	
	DumpConfigurationProcedures.Clear();
	ImportConfigurationProcedures.Clear();

	XMLWriter.WriteStartElement("DataProcessors");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "DataProcessor" Then
			ImportDataProcessor(ExchangeRules, XMLWriter);
		ElsIf (NodeName = "DataProcessors") AND (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;

	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports data export rule according to the exchange rules format.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  NewRow    - values tree string describing data export rules.
// 
Procedure ImportDDR(ExchangeRules)
	
	NewRow = UnloadRulesTable.Add();
	
	NewRow.Enable = Not deAttribute(ExchangeRules, BooleanType, "Disable");
		
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		If NodeName = "Code" Then
			
			NewRow.Name = deItemValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "Description" Then
			
			NewRow.Description = deItemValue(ExchangeRules, StringType);
		
		ElsIf NodeName = "Order" Then
			
			NewRow.Order = deItemValue(ExchangeRules, NumberType);
			
		ElsIf NodeName = "DataSelectionVariant" Then
			
			NewRow.DataSelectionVariant = deItemValue(ExchangeRules, StringType);
			
		ElsIf NodeName = "SelectExportDataInSingleQuery" Then
			
			// Parameter is ignored while on-line data exchange.
			deIgnore(ExchangeRules);
			
		ElsIf NodeName = "DontExportCreatedInTargetInfobaseObjects" Then
			
			NewRow.DontExportCreatedInTargetInfobaseObjects = deItemValue(ExchangeRules, BooleanType);

		ElsIf NodeName = "RecipientTypeName" Then
			
			NewRow.RecipientTypeName = deItemValue(ExchangeRules, StringType);

		ElsIf NodeName = "SelectionObject" Then
			
			SelectionObject = deItemValue(ExchangeRules, StringType);
			
			If Not ExchangeRuleInfoImportMode Then
				
				NewRow.SynchronizeByID = SynchronizeByIDDDR(NewRow.ConversionRule);
				
				If Not IsBlankString(SelectionObject) Then
					
					NewRow.SelectionObject        = Type(SelectionObject);
					
				EndIf;
				
				// To support filter using builder.
				If Find(SelectionObject, "Ref.") Then
					NewRow.ObjectForQueryName = StrReplace(SelectionObject, "Ref.", ".");
				Else
					NewRow.ObjectNameForRegisterQuery = StrReplace(SelectionObject, "Record.", ".");
				EndIf;
				
			EndIf;

		ElsIf NodeName = "ConversionRuleCode" Then
			
			NewRow.ConversionRule = deItemValue(ExchangeRules, StringType);

		// EVENT HANDLERS

		ElsIf NodeName = "BeforeProcessRule" Then
			NewRow.BeforeProcess = deItemValue(ExchangeRules, StringType);
			HandlerName = "DDR_[DDRName]_BeforeProcessRule";
			NewRow.ProcessorsNameBeforeProcessing = StrReplace(HandlerName, "[DDRName]", NewRow.Name);
			
		ElsIf NodeName = "AfterProcessRule" Then
			NewRow.AfterProcessing = deItemValue(ExchangeRules, StringType);
			HandlerName = "DDR_[DDRName]_AfterProcessRule";
			NewRow.ProcessorsNameAfterProcessing = StrReplace(HandlerName, "[DDRName]", NewRow.Name);
		
		ElsIf NodeName = "BeforeObjectExport" Then
			NewRow.BeforeExport = deItemValue(ExchangeRules, StringType);
			HandlerName = "DDR_[DDRName]_BeforeObjectExport";
			NewRow.ProcessorsNameBeforeExport = StrReplace(HandlerName, "[DDRName]", NewRow.Name);
			
		ElsIf NodeName = "AfterObjectExport" Then
			NewRow.AfterExport = deItemValue(ExchangeRules, StringType);
			HandlerName = "DDR_[DDRName]_AfterObjectExport";
			NewRow.HandlerNameAfterDump = StrReplace(HandlerName, "[DDRName]", NewRow.Name);
			
		ElsIf (NodeName = "Rule") AND (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;

	If IsBlankString(NewRow.Description) Then
		NewRow.Description = NewRow.Name;
	EndIf;
	
EndProcedure

// Imports data export rules according to the exchange rules format.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
// 
Procedure ImportDumpRules(ExchangeRules)
	
	UnloadRulesTable.Clear();
	
	SettingRow = Undefined;
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Rule" Then
			
			ImportDDR(ExchangeRules);
			
		ElsIf (NodeName = "DataUnloadRules") AND (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;

EndProcedure

Function SynchronizeByIDDDR(Val OCRName)
	
	OCR = FindRule(Undefined, OCRName);
	
	If OCR <> Undefined Then
		
		Return (OCR.SynchronizeByID = True);
		
	EndIf;
	
	Return False;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF WORK WITH EXCHANGE RULES

// Search for conversion rule by name or according
// to the passed object type.
//
// Parameters:
//  Object         - Object-source for which you should search for conversion rule.
//  Rulename     - conversion rule name.
//
// Returns:
//  Ref to conversion rule (row in rules table).
// 
Function FindRule(Object, Rulename="")

	If Not IsBlankString(Rulename) Then
		
		Rule = Rules[Rulename];
		
	Else
		
		Rule = Managers[TypeOf(Object)];
		If Rule <> Undefined Then
			Rule    = Rule.OCR;
			
			If Rule <> Undefined Then 
				Rulename = Rule.Name;
			EndIf;
			
		EndIf; 
		
	EndIf;
	
	Return Rule; 
	
EndFunction

// Restores rules from the internal format.
//
// Parameters:
// 
Procedure RestoreRulesFromInternalFormat() Export

	If SavedSettings = Undefined Then
		Return;
	EndIf;
	
	RuleStructure = SavedSettings.Get();
	
	// Check for version of exchange rules storing format.
	StorageRulesFormatVersion = Undefined;
	RuleStructure.Property("StorageRulesFormatVersion", StorageRulesFormatVersion);
	If StorageRulesFormatVersion <> FormatVersionStorageRulesExchange() Then
		Raise NStr("en='Version of exchange rules storing format does not correspond to the expected one.
		|Rules of exchange are required to be imported again.';ru='Версия формата хранения правил обмена не соответствует ожидаемой.
		|Требуется выполнить загрузку правил обмена повторно.'"
		);
	EndIf;
	
	Conversion                = RuleStructure.Conversion;
	UnloadRulesTable      = RuleStructure.UnloadRulesTable;
	ConversionRulesTable   = RuleStructure.ConversionRulesTable;
	ParametersSettingsTable = RuleStructure.ParametersSettingsTable;
	
	Algorithms                  = RuleStructure.Algorithms;
	QueriesToRestore   = RuleStructure.Queries;
	Parameters                  = RuleStructure.Parameters;
	
	XMLRules                = RuleStructure.XMLRules;
	TypesForTargetString   = RuleStructure.TypesForTargetString;
	
	HasBeforeObjectExportGlobalHandler    = Not IsBlankString(Conversion.BeforeObjectExport);
	HasAfterObjectExportGlobalHandler     = Not IsBlankString(Conversion.AfterObjectExport);
	HasBeforeObjectImportGlobalHandler    = Not IsBlankString(Conversion.BeforeObjectImport);
	HasAftertObjectImportGlobalHandler     = Not IsBlankString(Conversion.AftertObjectImport);
	HasBeforeConvertObjectGlobalHandler = Not IsBlankString(Conversion.BeforeObjectConversion);

	// Restore queries
	Queries.Clear();
	For Each StructureItem IN QueriesToRestore Do
		Query = New Query(StructureItem.Value);
		Queries.Insert(StructureItem.Key, Query);
	EndDo;
	
	InitializeManagersAndMessages();
	
	Rules.Clear();
	
	For Each TableRow IN ConversionRulesTable Do
		
		If ExchangeMode = "Export" Then
			
			GetValuesOfPredefinedData(TableRow);
			
		EndIf;
		
		Rules.Insert(TableRow.Name, TableRow);
		
		If ExchangeMode = "Export" AND TableRow.Source <> Undefined Then
			
			Try
				If TypeOf(TableRow.Source) = StringType Then
					Managers[Type(TableRow.Source)].OCR = TableRow;
				Else
					Managers[TableRow.Source].OCR = TableRow;
				EndIf;
			Except
				WriteInformationAboutErrorToProtocol(11, ErrorDescription(), String(TableRow.Source));
			EndTry;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Sets parameter values in the Parameters structure according to the ParametersSettingsTable table.
// 
Procedure SetParametersFromDialog() Export

	For Each TableRow IN ParametersSettingsTable Do
		Parameters.Insert(TableRow.Name, TableRow.Value);
	EndDo;

EndProcedure

Procedure SetParameterValueInTable(ParameterName, ParameterValue)
	
	TableRow = ParametersSettingsTable.Find(ParameterName, "Name");
	
	If TableRow <> Undefined Then
		
		TableRow.Value = ParameterValue;	
		
	EndIf;
	
EndProcedure

Procedure InitializeInitialParameterValues()
	
	For Each CurParameter IN Parameters Do
		
		SetParameterValueInTable(CurParameter.Key, CurParameter.Value);
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// CLEARING RULES DATA PROCESSOR

Procedure DeleteObject(Object, DeleteDirectly, TypeName = "")
	
	ObjectMetadata = Object.Metadata();
	
	If CommonUse.ThisIsCatalog(ObjectMetadata)
		Or CommonUse.ThisIsChartOfCharacteristicTypes(ObjectMetadata)
		Or CommonUse.ThisIsChartOfAccounts(ObjectMetadata)
		Or CommonUse.ThisIsChartOfCalculationTypes(ObjectMetadata) Then
		
		Predefined = Object.Predefined;
	Else
		Predefined = False;
	EndIf;
	
	If Predefined Then
		
		Return;
		
	EndIf;
	
	If DeleteDirectly Then
		
		Object.Delete();
		
	Else
		
		SetObjectDeletionMark(Object, True, TypeName);
		
	EndIf;
	
EndProcedure

Procedure RunDeleteObject(Object, Properties, DeleteDirectly)
	
	If Properties.TypeName = "InformationRegister" Then
		
		Object.Delete();
		
	Else
		
		DeleteObject(Object, DeleteDirectly, Properties.TypeName);
		
	EndIf;
	
EndProcedure

// Deletes (or marks for deletion) selection object according to the specified rule.
//
// Parameters:
//  Object         - deleted (marked for deletion) selection object.
//  Rule        - ref to data clearing rule.
//  Properties       - metadata object property of the deleted object.
//  IncomingData - custom helper data.
// 
Procedure DeletionOfSelectionObject(Object, Rule, Properties, IncomingData)
	
	Cancel = False;
	DeleteDirectly = Rule.Directly;
	
	// Handler BeforeSelectionObjectDeletion
	
	If Not IsBlankString(Rule.BeforeDelete) Then
	
		Try
			
			If DebuggingImportHandlers Then
				
				ExecuteHandler_DCR_BeforeDeleteObject(Rule, Object, Cancel, DeleteDirectly, IncomingData);
				
			Else
				
				Execute(Rule.BeforeDelete);
				
			EndIf;
			
		Except
			
			WriteInformationAboutDataClearHandlerError(29, ErrorDescription(), Rule.Name, Object, "BeforeSelectionObjectDeletion");
			
		EndTry;
		
		If Cancel Then
		
			Return;
			
		EndIf;
		
	EndIf;

	Try
		
		RunDeleteObject(Object, Properties, DeleteDirectly);
		
	Except
		
		WriteInformationAboutDataClearHandlerError(24, ErrorDescription(), Rule.Name, Object, "");
		
	EndTry;
	
EndProcedure

// Clears data by the specified rule.
//
// Parameters:
//  Rule        - ref to data clearing rule.
// 
Procedure ClearDataByRule(Rule)
	
	// Handler BeforeDataProcessor
	
	Cancel			= False;
	DataSelection	= Undefined;
	OutgoingData = Undefined;
	
	// Handler BeforeClearingRuleDataProcessor
	If Not IsBlankString(Rule.BeforeProcess) Then
		
		Try
			
			If DebuggingImportHandlers Then
				
				ExecuteHandler_DCR_BeforeProcessRule(Rule, Cancel, OutgoingData, DataSelection);
				
			Else
				
				Execute(Rule.BeforeProcess);
				
			EndIf;
			
		Except
			
			WriteInformationAboutDataClearHandlerError(27, ErrorDescription(), Rule.Name, "", "BeforeProcessClearingRule");
						
		EndTry;
			
		If Cancel Then
			
			Return;
			
		EndIf;
		
	EndIf;
	
	// Standard selection
	
	Properties = Managers[Rule.SelectionObject];
	
	If Rule.DataSelectionVariant = "StandardSelection" Then
		
		TypeName		= Properties.TypeName;
		
		If TypeName = "AccountingRegister" 
			OR TypeName = "Constants" Then
			
			Return;
			
		EndIf;
		
		AllFieldsRequired  = Not IsBlankString(Rule.BeforeDelete);
		
		Selection = GetSelectionForDataDumpClear(Properties, TypeName, True, Rule.Directly, AllFieldsRequired);
		
		While Selection.Next() Do
			
			If TypeName =  "InformationRegister" Then
				
				RecordManager = Properties.Manager.CreateRecordManager(); 
				FillPropertyValues(RecordManager, Selection);
									
				DeletionOfSelectionObject(RecordManager, Rule, Properties, OutgoingData);
									
			Else
					
				DeletionOfSelectionObject(Selection.Ref.GetObject(), Rule, Properties, OutgoingData);
					
			EndIf;
				
		EndDo;		

	ElsIf Rule.DataSelectionVariant = "ArbitraryAlgorithm" Then

		If DataSelection <> Undefined Then
			
			Selection = GetSelectionForDumpByArbitraryAlgorithm(DataSelection);
			
			If Selection <> Undefined Then
				
				While Selection.Next() Do
					
					If TypeName =  "InformationRegister" Then
				
						RecordManager = Properties.Manager.CreateRecordManager(); 
						FillPropertyValues(RecordManager, Selection);
											
						DeletionOfSelectionObject(RecordManager, Rule, Properties, OutgoingData);
											
					Else
							
						DeletionOfSelectionObject(Selection.Ref.GetObject(), Rule, Properties, OutgoingData);
							
					EndIf;					
					
				EndDo;	
				
			Else
				
				For Each Object IN DataSelection Do
					
					DeletionOfSelectionObject(Object.GetObject(), Rule, Properties, OutgoingData);
					
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Handler AfterClearingRuleDataProcessor
	
	If Not IsBlankString(Rule.AfterProcessing) Then
		
		Try
			
			If DebuggingImportHandlers Then
				
				ExecuteHandler_DCR_AfterProcessRule(Rule);
				
			Else
				
				Execute(Rule.AfterProcessing);
				
			EndIf;
			
		Except
			
			WriteInformationAboutDataClearHandlerError(28, ErrorDescription(), Rule.Name, "", "AfterProcessClearingRule");
			
		EndTry;
		
	EndIf;
	
EndProcedure

// Skips data clearing rules tree and executes clearing.
//
// Parameters:
//  Rows         - Values tree strings collection.
// 
Procedure ProcessClearRules(Rows)
	
	For Each ClearingRule IN Rows Do
		
		If ClearingRule.Enable = 0 Then
			
			Continue;
			
		EndIf; 

		If ClearingRule.IsFolder Then
			
			ProcessClearRules(ClearingRule.Rows);
			Continue;
			
		EndIf;
		
		ClearDataByRule(ClearingRule);
		
	EndDo; 
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// DATA UPLOAD PROCEDURE

Procedure StartMessageReader(MessageReader, DataAnalysis = False)
	
	If IsBlankString(ExchangeFileName) Then
		Raise WriteInExecutionProtocol(15);
	EndIf;
	
	ExchangeFile = New XMLReader;
	
	ExchangeFile.OpenFile(ExchangeFileName);
	
	ExchangeFile.Read(); // ExchangeFile
	
	If ExchangeFile.NodeType <> XMLNodeType.StartElement Then
		Raise NStr("en='Error of the exchange message format.';ru='Ошибка формата сообщения обмена.'");
	EndIf;
	
	If ExchangeFile.LocalName <> "ExchangeFile" Then
		Raise NStr("en='Error of the exchange message format.';ru='Ошибка формата сообщения обмена.'");
	EndIf;
	
	IncomingExchangeMessageFormatVersionField = deAttribute(ExchangeFile, StringType, "FormatVersion");
	
	SourceConfigurationVersion = "";
	Conversion.Property("SourceConfigurationVersion", SourceConfigurationVersion);
	SourceVersionFromRules = deAttribute(ExchangeFile, StringType, "SourceConfigurationVersion");
	MessageText = "";
	
	If DataExchangeServer.CorrespondentVersionsDiffer(ExchangePlanName(), EventLogMonitorMessageKey(),
		SourceConfigurationVersion, SourceVersionFromRules, MessageText) Then
		
		Raise MessageText;
		
	EndIf;
	
	ExchangeFile.Read(); // ExchangeRules
	
	If ExchangeFile.NodeType <> XMLNodeType.StartElement Then
		Raise NStr("en='Error of the exchange message format.';ru='Ошибка формата сообщения обмена.'");
	EndIf;
	
	If ExchangeFile.LocalName <> "ExchangeRules" Then
		Raise NStr("en='Error of the exchange message format.';ru='Ошибка формата сообщения обмена.'");
	EndIf;
	
	If ConversionRulesTable.Count() = 0 Then
		ImportExchangeRules(ExchangeFile, "XMLReader");
		If ErrorFlag() Then
			Raise NStr("en='The errors occurred when importing the data exchange rules';ru='При загрузке правил обмена данными возникли ошибки.'");
		EndIf;
	Else
		deIgnore(ExchangeFile);
	EndIf;
	
	// {Handler: BeforeDataImport} Start
	If Not IsBlankString(Conversion.BeforeDataImport) Then
		
		Cancel = False;
		
		Try
			
			If DebuggingImportHandlers Then
				
				ExecuteHandler_Conversion_BeforeDataImport(ExchangeFile, Cancel);
				
			Else
				
				Execute(Conversion.BeforeDataImport);
				
			EndIf;
			
		Except
			Raise WriteInformationAboutErrorConversionHandlers(22, ErrorDescription(), NStr("en='BeforeDataImport (Conversion)';ru='ПередЗагрузкойДанных (конвертация)'"));
		EndTry;
		
		If Cancel Then
			Raise NStr("en='Rejection to import the messages of exchange in the BeforeDataImport (conversion) handler.';ru='Отказ от загрузки сообщения обмена в обработчике ПередЗагрузкойДанных (конвертация).'");
		EndIf;
		
	EndIf;
	// {Handler: BeforeDataImport} End
	
	ExchangeFile.Read();
	
	If ExchangeFile.NodeType <> XMLNodeType.StartElement Then
		Raise NStr("en='Error of the exchange message format.';ru='Ошибка формата сообщения обмена.'");
	EndIf;
	
	// UserSearchSetting (optional)
	If ExchangeFile.LocalName = "CustomSearchSetup" Then
		ImportInformationAboutCustomSearchFields();
		ExchangeFile.Read();
	EndIf;
	
	// InformationAboutDataTypes (optional)
	If ExchangeFile.LocalName = "DataTypeInfo" Then
		
		If ExchangeFile.NodeType <> XMLNodeType.StartElement Then
			Raise NStr("en='Error of the exchange message format.';ru='Ошибка формата сообщения обмена.'");
		EndIf;
		
		If MapOfDataTypesForImport().Count() > 0 Then
			deIgnore(ExchangeFile);
		Else
			ImportInformationAboutDataTypes();
			If ErrorFlag() Then
				Raise NStr("en='When importing the information on the data types the errors have occurred.';ru='При загрузке информации о типах данных возникли ошибки.'");
			EndIf;
		EndIf;
		ExchangeFile.Read();
	EndIf;
	
	// ParameterValue (optional) (several).
	If ExchangeFile.LocalName = "ParameterValue" Then
		
		If ExchangeFile.NodeType <> XMLNodeType.StartElement Then
			Raise NStr("en='Error of the exchange message format.';ru='Ошибка формата сообщения обмена.'");
		EndIf;
		
		ImportDataEchangeParameterValues();
		
		While ExchangeFile.Read() Do
			
			If ExchangeFile.LocalName = "ParameterValue" Then
				
				If ExchangeFile.NodeType <> XMLNodeType.StartElement Then
					Raise NStr("en='Error of the exchange message format.';ru='Ошибка формата сообщения обмена.'");
				EndIf;
				
				ImportDataEchangeParameterValues();
			Else
				Break;
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// AlgorithmAfterParametersImport (optional)
	If ExchangeFile.LocalName = "AfterParameterExportAlgorithm" Then
		
		If ExchangeFile.NodeType <> XMLNodeType.StartElement Then
			Raise NStr("en='Error of the exchange message format.';ru='Ошибка формата сообщения обмена.'");
		EndIf;
		
		ExecuteAlgorithmAfterImportParameters(deItemValue(ExchangeFile, StringType));
		ExchangeFile.Read();
	EndIf;
	
	// DataOnExchange (optional)
	If ExchangeFile.NodeType <> XMLNodeType.StartElement Then
		Raise NStr("en='Error of the exchange message format.';ru='Ошибка формата сообщения обмена.'");
	EndIf;
	
	If ExchangeFile.LocalName <> "ExchangeData" Then
		Raise NStr("en='Error of the exchange message format.';ru='Ошибка формата сообщения обмена.'");
	EndIf;
	
	ReadExchangeData(MessageReader, DataAnalysis);
	ExchangeFile.Read();
	
	If TransactionActive() Then
		Raise NStr("en='Locking of the data receipt can not be installed in the active transaction.';ru='Блокировка получения данных не может быть установлена в активной транзакции.'");
	EndIf;
	
	// Set lock on sender node.
	Try
		LockDataForEdit(MessageReader.Sender);
	Except
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Setting lock on data exchange error.
		|Data exchange may be performed by another session.
		|
		|Details:
		|%1';ru='Ошибка установки блокировки на обмен данными.
		|Возможно, обмен данными выполняется другим сеансом.
		|
		|Подробности:
		|%1'"),
			BriefErrorDescription(ErrorInfo())
		);
	EndTry;
	
EndProcedure

Procedure FinishMessageReading(Val MessageReader)
	
	// {Handler: AfterDataImport} Start
	If Not IsBlankString(Conversion.AfterDataImport) Then
		
		Try
			
			If DebuggingImportHandlers Then
				
				ExecuteHandler_Conversion_AfterDataImport();
				
			Else
				
				Execute(Conversion.AfterDataImport);
				
			EndIf;
			
		Except
			Raise WriteInformationAboutErrorConversionHandlers(23, ErrorDescription(), NStr("en='AfterDataImport (conversion)';ru='ПослеЗагрузкиДанных (конвертация)'"));
		EndTry;
		
	EndIf;
	// {Handler: AfterDataImport} End
	
	If ExchangeFile.NodeType <> XMLNodeType.EndElement Then
		Raise NStr("en='Error of the exchange message format.';ru='Ошибка формата сообщения обмена.'");
	EndIf;
	
	If ExchangeFile.LocalName <> "ExchangeFile" Then
		Raise NStr("en='Error of the exchange message format.';ru='Ошибка формата сообщения обмена.'");
	EndIf;
	
	ExchangeFile.Read(); // ExchangeFile
	ExchangeFile.Close();
	
	BeginTransaction();
	If Not MessageReader.DataAnalysis Then
		MessageReader.SenderObject.ReceivedNo = MessageReader.MessageNo;
		MessageReader.SenderObject.DataExchange.Load = True;
		MessageReader.SenderObject.Write();
	EndIf;
	
	If HasObjectChangeRecordDataAdjustment = True Then
		InformationRegisters.InfobasesNodesCommonSettings.CommitCorrectionExecutionOfInformationMatchingUnconditionally(ExchangeNodeForDataImport);
	EndIf;
	
	If HasObjectChangeRecordData = True Then
		InformationRegisters.InfobasesObjectsCompliance.DeleteOutdatedExportModeRecordsByRef(ExchangeNodeForDataImport);
	EndIf;
	CommitTransaction();
	
	UnlockDataForEdit(MessageReader.Sender);
	
EndProcedure

Procedure AbortMessageReading(Val MessageReader)
	
	ExchangeFile.Close();
	
	UnlockDataForEdit(MessageReader.Sender);
	
EndProcedure

Procedure ExecuteAlgorithmAfterImportParameters(Val AlgorithmText)
	
	If IsBlankString(AlgorithmText) Then
		Return;
	EndIf;
	
	Cancel = False;
	CancelReason = "";
	
	Try
		
		If DebuggingImportHandlers Then
			
			ExecuteHandler_Conversion_AfterParametersImport(ExchangeFile, Cancel, CancelReason);
			
		Else
			
			Execute(AlgorithmText);
			
		EndIf;
		
		If Cancel = True Then
			
			If Not IsBlankString(CancelReason) Then
				
				MessageString = NStr("en='Denial of the exchange message import in the AfterParametersImport handler (conversion) as: %1';ru='Отказ от загрузки сообщения обмена в обработчике ПослеЗагрузкиПараметров (конвертация) по причине: %1'");
				MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, CancelReason);
				Raise MessageString;
			Else
				Raise NStr("en='Rejection from the exchange message import in the AfterImportOfParameters (conversion) processing.';ru='Отказ от загрузки сообщения обмена в обработчике ПослеЗагрузкиПараметров (конвертация).'");
			EndIf;
			
		EndIf;
		
	Except
		
		LR = GetProtocolRecordStructure(78, ErrorDescription());
		LR.Handler     = "AfterParametersImport";
		ErrorMessageString = WriteInExecutionProtocol(78, LR);
		
		If Not ContinueOnError Then
			Raise ErrorMessageString;
		EndIf;
		
	EndTry;
	
EndProcedure

Function SetNewObjectRef(Object, Manager, SearchProperties)
	
	UI = SearchProperties["{UUID}"];
	
	If UI <> Undefined Then
		
		NewRef = Manager.GetRef(New UUID(UI));
		
		Object.SetNewObjectRef(NewRef);
		
		SearchProperties.Delete("{UUID}");
		
	Else
		
		NewRef = Undefined;
		
	EndIf;
	
	Return NewRef;
	
EndFunction

// Searches for object by the number in the list of already imported objects.
//
// Parameters:
//  NPP          - number of searched object in the exchange file.
//
// Returns:
//  Ref to the found object. If object is not found, Undefined is returned.
// 
Function FindObjectByNumber(NPP, ObjectType, MainObjectSearchMode = False)
	
	Return Undefined;
	
EndFunction

Function FindObjectByGlobalNumber(NPP, MainObjectSearchMode = False)
	
	Return Undefined;
	
EndFunction

Procedure RemoveDeletionMarkFromPredefinedItem(Object, Val ObjectType)
	
	If TypeOf(ObjectType) = StringType Then
		ObjectType = Type(ObjectType);
	EndIf;
	
	If (Catalogs.AllRefsType().ContainsType(ObjectType)
		Or ChartsOfCharacteristicTypes.AllRefsType().ContainsType(ObjectType)
		Or ChartsOfAccounts.AllRefsType().ContainsType(ObjectType)
		Or ChartsOfCalculationTypes.AllRefsType().ContainsType(ObjectType))
		AND Object.DeletionMark
		AND Object.Predefined Then
		
		Object.DeletionMark = False;
		
		// note event in the RL
		LR            = GetProtocolRecordStructure(80);
		LR.ObjectType = ObjectType;
		LR.Object     = String(Object);
		
		WriteInExecutionProtocol(80, LR, False,,,,Enums.ExchangeExecutionResult.CompletedWithWarnings);
		
	EndIf;
	
EndProcedure

Function DefineIfThereAreRegisterRecordsByDocument(DocumentRef)
	QueryText = "";	
	// To prevent the document drop in more than 256 tables.
	Counter_tables = 0;
	
	DocumentMetadata = DocumentRef.Metadata();
	
	If DocumentMetadata.RegisterRecords.Count() = 0 Then
		Return New ValueTable;
	EndIf;
	
	For Each RegisterRecord IN DocumentMetadata.RegisterRecords Do
		// IN the query, we get names of the registers which have
		// at
		// least one movement, for
		// example, SELECT
		// First 1 AccumulationRegister.ProductsInWarehouses FROM AccumulationRegister.ProductsInWarehouses WHERE Recorder = &Recorder
		
		// Register name equal to Row(200), see below.
		QueryText = QueryText + "
		|" + ?(QueryText = "", "", "UNION ALL ") + "
		|SELECT TOP 1 CAST(""" + RegisterRecord.FullName() 
		+  """ AS String(200)) AS Name FROM " + RegisterRecord.FullName() 
		+ " WHERE Recorder = &Recorder";
		
		// If the request has more than 256 tables - break it into
		// two parts (variant of a document with posting in 512 registers is unreal).
		Counter_tables = Counter_tables + 1;
		If Counter_tables = 256 Then
			Break;
		EndIf;
		
	EndDo;
	
	Query = New Query(QueryText);
	Query.SetParameter("Recorder", DocumentRef);
	// During the export of the Name column the type is set according
	// to the longest row from the query, during the second pass through the table the
	// new name may not fit, that is why a row is immediately given in the query (200).
	QueryTable = Query.Execute().Unload();
	
	// If the number of tables is not more than 256 - return the table.
	If Counter_tables = DocumentMetadata.RegisterRecords.Count() Then
		Return QueryTable;			
	EndIf;
	
	// There are more than 256 tables, make an add. query and expand the rows of the table.
	
	QueryText = "";
	For Each RegisterRecord IN DocumentMetadata.RegisterRecords Do
		
		If Counter_tables > 0 Then
			Counter_tables = Counter_tables - 1;
			Continue;
		EndIf;
		
		QueryText = QueryText + "
		|" + ?(QueryText = "", "", "UNION ALL ") + "
		|SELECT TOP 1 """ + RegisterRecord.FullName() +  """ AS Name IN " 
		+ RegisterRecord.FullName() + " WHERE Recorder = &Recorder";	
		
		
	EndDo;
	Query.Text = QueryText;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		TableRow = QueryTable.Add();
		FillPropertyValues(TableRow, Selection);
	EndDo;
	
	Return QueryTable;
	
EndFunction

// Procedure of removing the existing movements of the document during reposting (posting cancelation).
Procedure DeleteDocumentRegisterRecords(DocumentObject)
	
	RecordTableRowToProcessArray = New Array();
	
	// Get the registers list which has movements on it.
	RegisterRecordTable = DefineIfThereAreRegisterRecordsByDocument(DocumentObject.Ref);
	RegisterRecordTable.Columns.Add("RecordSet");
	RegisterRecordTable.Columns.Add("ForceDelete", New TypeDescription("Boolean"));
		
	For Each RegisterRecordRow IN RegisterRecordTable Do
		// Register name is transferred as a value
		// received using the FullName function() of the register metadata.
		DotPosition = Find(RegisterRecordRow.Name, ".");
		TypeRegister = Left(RegisterRecordRow.Name, DotPosition - 1);
		RegisterName = TrimR(Mid(RegisterRecordRow.Name, DotPosition + 1));

		RecordTableRowToProcessArray.Add(RegisterRecordRow);
		
		If TypeRegister = "AccumulationRegister" Then
			SetMetadata = Metadata.AccumulationRegisters[RegisterName];
			Set = AccumulationRegisters[RegisterName].CreateRecordSet();
			
		ElsIf TypeRegister = "AccountingRegister" Then
			SetMetadata = Metadata.AccountingRegisters[RegisterName];
			Set = AccountingRegisters[RegisterName].CreateRecordSet();
			
		ElsIf TypeRegister = "InformationRegister" Then
			SetMetadata = Metadata.InformationRegisters[RegisterName];
			Set = InformationRegisters[RegisterName].CreateRecordSet();
			
		ElsIf TypeRegister = "CalculationRegister" Then
			SetMetadata = Metadata.CalculationRegisters[RegisterName];
			Set = CalculationRegisters[RegisterName].CreateRecordSet();
			
		EndIf;
		
		If Not AccessRight("Update", Set.Metadata()) Then
			// No rights to all register table.
			ErrorMessage = NStr("en='Access violation: %1';ru='Нарушение прав доступа: %1'");
			ErrorMessage = StringFunctionsClientServer.PlaceParametersIntoString(ErrorMessage, RegisterRecordRow.Name);
			Raise ErrorMessage;
			Return;
		EndIf;

		Set.Filter.Recorder.Set(DocumentObject.Ref);

		// The set is not written immediately not to roll
		// back the transaction if later it turns out that you do not have enough rights to one of the registers.
		RegisterRecordRow.RecordSet = Set;
		
	EndDo;
	
	DataExchangeServer.SkipChangeProhibitionCheck();
	
	For Each RegisterRecordRow IN RecordTableRowToProcessArray Do		
		Try
			RegisterRecordRow.RecordSet.Write();
		Except
			// RlS or subsystem of the change prohibition date may have worked.
			ErrorMessage = NStr("en='Operation is
		|not executed: %1 %2';ru='Операция
		|не выполнена: %1 %2'");
			ErrorMessage = StringFunctionsClientServer.PlaceParametersIntoString(ErrorMessage,
				RegisterRecordRow.Name, BriefErrorDescription(ErrorInfo()));
			Raise ErrorMessage;
		EndTry;
	EndDo;
	
	DataExchangeServer.SkipChangeProhibitionCheck(False);
	
	DocumentRecordsCollectionClear(DocumentObject);
	
	// Delete the registration records from all sequences.
	DeleteDocumentRegistrationInSequences(DocumentObject, True);

EndProcedure

Procedure DeleteDocumentRegistrationInSequences(DocumentObject, CheckRegisterRecords = False)
	// Get sequences list in which the document was registered.
	If CheckRegisterRecords Then
		RecordChangeTable = DefineIfThereIsDocumentRegistrationInSequence(DocumentObject);
	EndIf;      
	SequenceCollection = DocumentObject.BelongingToSequences;
	For Each SequenceRecordRecordSet IN SequenceCollection Do
		If (SequenceRecordRecordSet.Count() > 0)
		  OR (CheckRegisterRecords AND (NOT RecordChangeTable.Find(SequenceRecordRecordSet.Metadata().Name,"Name") = Undefined)) Then
		   SequenceRecordRecordSet.Clear();
		EndIf;
	EndDo;
EndProcedure

Function DefineIfThereIsDocumentRegistrationInSequence(DocumentObject)
	QueryText = "";	
	
	For Each Sequence IN DocumentObject.BelongingToSequences Do
		// IN the query we get names of users, in which the document is registered.
		QueryText = QueryText + "
		|" + ?(QueryText = "", "", "UNION ALL ") + "
		|SELECT """ + Sequence.Metadata().Name 
		+  """ AS Name IN " + Sequence.Metadata().FullName()  
		+ " WHERE Recorder = &Recorder";
		
	EndDo;
	
	If QueryText = "" Then
		Return New ValueTable();
	Else
		Query = New Query(QueryText);
		Query.SetParameter("Recorder", DocumentObject.Ref);
		QueryTable = Query.Execute().Unload();	
		Return QueryTable;
	EndIf;
	
EndFunction

// The procedure clears the collection of document register records.
//
Procedure DocumentRecordsCollectionClear(DocumentObject)
		
	For Each RegisterRecord IN DocumentObject.RegisterRecords Do
		If RegisterRecord.Count() > 0 Then
			RegisterRecord.Clear();
		EndIf;
	EndDo;
	
EndProcedure

Procedure SetAttributesCurrentDate(ObjectAttribute)
	
	ObjectAttribute = CurrentSessionDate();
	
EndProcedure

// Creates a new object of the
// specified type, sets attributes specified in the SearchProperties structure.
//
// Parameters:
//  Type            - type of created object.
//  SearchProperties - Structure containing set attributes of a new object.
//
// Returns:
//  New infobase object.
// 
Function CreateNewObject(Type, SearchProperties, Object = Undefined, 
	WriteObjectImmediatelyAfterCreation = True, NewRef = Undefined, 
	NPP = 0, GNPP = 0, Rule = Undefined, 
	ObjectParameters = Undefined, SetAllObjectSearchProperties = True)

	MDProperties      = Managers[Type];
	TypeName         = MDProperties.TypeName;
	Manager        = MDProperties.Manager;
	DeletionMark = Undefined;

	If TypeName = "Catalog"
		OR TypeName = "ChartOfCharacteristicTypes" Then
		
		IsFolder = SearchProperties["IsFolder"];
		
		If IsFolder = True Then
			
			Object = Manager.CreateFolder();
						
		Else
			
			Object = Manager.CreateItem();
			
		EndIf;		
				
	ElsIf TypeName = "Document" Then
		
		Object = Manager.CreateDocument();
				
	ElsIf TypeName = "ChartOfAccounts" Then
		
		Object = Manager.CreateAccount();
				
	ElsIf TypeName = "ChartOfCalculationTypes" Then
		
		Object = Manager.CreateCalculationType();
				
	ElsIf TypeName = "InformationRegister" Then
		
		Object = Manager.CreateRecordManager();
		Return Object;
		
	ElsIf TypeName = "ExchangePlan" Then
		
		Object = Manager.CreateNode();
				
	ElsIf TypeName = "Task" Then
		
		Object = Manager.CreateTask();
		
	ElsIf TypeName = "BusinessProcess" Then
		
		Object = Manager.CreateBusinessProcess();	
		
	ElsIf TypeName = "Enum" Then
		
		Object = MDProperties.EmptyRef;	
		Return Object;
		
	ElsIf TypeName = "BusinessProcessRoutePoint" Then
		
		Return Undefined;
				
	EndIf;
	
	NewRef = SetNewObjectRef(Object, Manager, SearchProperties);
	
	If SetAllObjectSearchProperties Then
		SetObjectSearchAttributes(Object, SearchProperties, , False, False);
	EndIf;
	
	// Checks
	If TypeName = "Document"
		OR TypeName = "Task"
		OR TypeName = "BusinessProcess" Then
		
		If Not ValueIsFilled(Object.Date) Then
			
			SetAttributesCurrentDate(Object.Date);			
						
		EndIf;
		
	EndIf;
		
	If WriteObjectImmediatelyAfterCreation Then
		
		WriteObjectToIB(Object, Type);
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	Return Object.Ref;
	
EndFunction

// Reads object property node from file, sets property value.
//
// Parameters:
//  Type            - property value type.
//  ObjectFound   - if after you execute function - False,
//                   then property object is not found in the infobase and a new one will be created.
//
// Returns:
//  Property value
// 
Function ReadProperty(Type, DontCreateObjectIfNotFound = False, PropertyNotFoundByRef = False, OCRName = "")

	Value = Undefined;
	PropertyExistence = False;
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
				
		If NodeName = "Value" Then
			
			SearchByProperty = deAttribute(ExchangeFile, StringType, "Property");
			Value         = deItemValue(ExchangeFile, Type, SearchByProperty, False);
			PropertyExistence = True;
			
		ElsIf NodeName = "Ref" Then
			
			InfobasesObjectsCompliance = Undefined;
			CreatedObject = Undefined;
			ObjectFound = True;
			SearchBySearchFieldsIfNotFoundByID = False;
			
			Value = FindObjectByRef(Type,
											,
											, 
											ObjectFound, 
											CreatedObject, 
											DontCreateObjectIfNotFound, 
											, 
											, 
											, 
											, 
											, 
											, 
											, 
											, 
											, 
											, 
											, 
											OCRName, 
											InfobasesObjectsCompliance, 
											SearchBySearchFieldsIfNotFoundByID);
			
			If DontCreateObjectIfNotFound
				AND Not ObjectFound Then
				
				PropertyNotFoundByRef = False;
				
			EndIf;
			
			PropertyExistence = True;
			
		ElsIf NodeName = "NPP" Then
			
			ExchangeFile.Read();
			NPP = Number(ExchangeFile.Value);
			If NPP <> 0 Then
				Value  = FindObjectByNumber(NPP, Type);
				PropertyExistence = True;
			EndIf;			
			ExchangeFile.Read();
			
		ElsIf NodeName = "GSn" Then
			
			ExchangeFile.Read();
			GNPP = Number(ExchangeFile.Value);
			If GNPP <> 0 Then
				Value  = FindObjectByGlobalNumber(GNPP);
				PropertyExistence = True;
			EndIf;
			
			ExchangeFile.Read();
			
		ElsIf (NodeName = "Property" OR NodeName = "ParameterValue") AND (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
			
			If Not PropertyExistence
				AND ValueIsFilled(Type) Then
				
				// If there is nothing - , then there is an empty value.
				Value = deGetBlankValue(Type);
				
			EndIf;
			
			Break;
			
		ElsIf NodeName = "Expression" Then
			
			Value = Eval(deItemValue(ExchangeFile, StringType, , False));
			PropertyExistence = True;
			
		ElsIf NodeName = "Empty" Then
			
			Value = deGetBlankValue(Type);
			PropertyExistence = True;
			
		Else
			
			WriteInExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;
	
	Return Value;
	
EndFunction

Procedure SetObjectSearchAttributes(FoundObject, SearchProperties, SearchPropertiesDontReplace, 
	ShouldCompareWithCurrentAttributes = True, DontReplacePropertiesNotToChange = True)
	
	For Each Property IN SearchProperties Do
					
		Name      = Property.Key;
		Value = Property.Value;
		
		If DontReplacePropertiesNotToChange
			AND SearchPropertiesDontReplace[Name] <> Undefined Then
			
			Continue;
			
		EndIf;
					
		If Name = "IsFolder" 
			OR Name = "{UUID}" 
			OR Name = "{PredefinedItemName}"
			OR Name = "{SearchKeyInIBSource}"
			OR Name = "{SearchKeyInIBReceiver}"
			OR Name = "{TypeNameInIBSource}"
			OR Name = "{TypeNameInIBReceiver}" Then
						
			Continue;
						
		ElsIf Name = "DeletionMark" Then
						
			If Not ShouldCompareWithCurrentAttributes
				OR FoundObject.DeletionMark <> Value Then
							
				FoundObject.DeletionMark = Value;
							
			EndIf;
						
		Else
				
			// Set different attributes.
			
			If FoundObject[Name] <> NULL Then
			
				If Not ShouldCompareWithCurrentAttributes
					OR FoundObject[Name] <> Value Then
						
					FoundObject[Name] = Value;
					
						
				EndIf;
				
			EndIf;
				
		EndIf;
					
	EndDo;
	
EndProcedure

Function FindOrCreateObjectByProperty(PropertyStructure,
									ObjectType,
									SearchProperties,
									SearchPropertiesDontReplace,
									ObjectTypeName,
									SearchProperty,
									SearchPropertyValue,
									ObjectFound,
									CreateNewItemIfNotFound = True,
									FoundOrCreatedObject = Undefined,
									MainObjectSearchMode = False,
									NewUUIDRef = Undefined,
									NPP = 0,
									GNPP = 0,
									ObjectParameters = Undefined,
									DontReplaceCreatedInTargetObject = False,
									ObjectCreatedInCurrentInfobase = Undefined)
	
	Object = deFindObjectByProperty(PropertyStructure.Manager, SearchProperty, SearchPropertyValue, 
		FoundOrCreatedObject, , , MainObjectSearchMode, PropertyStructure.SearchString);
	
	ObjectFound = Not (Object = Undefined
				OR Object.IsEmpty());
				
	If Not ObjectFound
		AND CreateNewItemIfNotFound Then
		
		Object = CreateNewObject(ObjectType, SearchProperties, FoundOrCreatedObject, 
			Not MainObjectSearchMode, NewUUIDRef, NPP, GNPP, FindFirstRuleByPropertiesStructure(PropertyStructure),
			ObjectParameters);
			
		Return Object;
		
	EndIf;
			
	
	If MainObjectSearchMode Then
		
		//
		Try
			
			If Not ValueIsFilled(Object) Then
				Return Object;
			EndIf;
			
			If FoundOrCreatedObject = Undefined Then
				FoundOrCreatedObject = Object.GetObject();
			EndIf;
			
		Except
			Return Object;
		EndTry;
			
		SetObjectSearchAttributes(FoundOrCreatedObject, SearchProperties, SearchPropertiesDontReplace);
		
	EndIf;
		
	Return Object;
	
EndFunction

Function GetPropertyType()
	
	PropertyTypeString = deAttribute(ExchangeFile, StringType, "Type");
	If IsBlankString(PropertyTypeString) Then
		
		// You should determine property by match.
		Return Undefined;
		
	EndIf;
	
	Return Type(PropertyTypeString);
	
EndFunction

Function GetPropertyTypeByAdditionalInformation(TypeInformation, PropertyName)
	
	PropertyType = GetPropertyType();
				
	If PropertyType = Undefined
		AND TypeInformation <> Undefined Then
		
		PropertyType = TypeInformation[PropertyName];
		
	EndIf;
	
	Return PropertyType;
	
EndFunction

Procedure ReadSearchPropertiesFromFile(SearchProperties, SearchPropertiesDontReplace, TypeInformation,
	SearchByEqualDate, ObjectParameters, Val MainObjectSearchMode, ObjectMapFound, InfobasesObjectsCompliance)
	
	SearchByEqualDate = False;
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
				
		If    NodeName = "Property"
			OR NodeName = "ParameterValue" Then
			
			IsParameter = (NodeName = "ParameterValue");
			
			Name = deAttribute(ExchangeFile, StringType, "Name");
			
			SourceTypeAsString = deAttribute(ExchangeFile, StringType, "ReceiverType");
			ReceiverTypeAsString = deAttribute(ExchangeFile, StringType, "SourceType");
			
			UUIDProperty = (Name = "{UUID}");
			
			If UUIDProperty Then
				
				PropertyType = StringType;
				
			ElsIf Name = "{PredefinedItemName}"
				  OR Name = "{SearchKeyInIBSource}"
				  OR Name = "{SearchKeyInIBReceiver}"
				  OR Name = "{TypeNameInIBSource}"
				  OR Name = "{TypeNameInIBReceiver}" Then
				
				PropertyType = StringType;
				
			Else
				
				PropertyType = GetPropertyTypeByAdditionalInformation(TypeInformation, Name);
				
			EndIf;
			
			DontReplaceProperty = deAttribute(ExchangeFile, BooleanType, "Donotreplace");
			
			SearchByEqualDate = SearchByEqualDate 
						OR deAttribute(ExchangeFile, BooleanType, "SearchByEqualDate");
			//
			OCRName = deAttribute(ExchangeFile, StringType, "OCRName");
			
			PropertyValue = ReadProperty(PropertyType,,, OCRName);
			
			If UUIDProperty Then
				
				ExecuteReplacementOfUUIDIfNeeded(PropertyValue, SourceTypeAsString, ReceiverTypeAsString, MainObjectSearchMode, ObjectMapFound, InfobasesObjectsCompliance);
				
			EndIf;
			
			If (Name = "IsFolder") AND (PropertyValue <> True) Then
				
				PropertyValue = False;
												
			EndIf; 
			
			If IsParameter Then
				
				
				AddParameterIfNeeded(ObjectParameters, Name, PropertyValue);
				
			Else
			
				SearchProperties[Name] = PropertyValue;
				
				If DontReplaceProperty Then
					
					SearchPropertiesDontReplace[Name] = True;
					
				EndIf;
				
			EndIf;
			
		ElsIf (NodeName = "Ref") AND (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		Else
			
			WriteInExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;	
	
EndProcedure

Procedure ExecuteReplacementOfUUIDIfNeeded(
										UUID,
										Val SourceTypeAsString,
										Val ReceiverTypeAsString,
										Val MainObjectSearchMode,
										ObjectMapFound = False,
										InfobasesObjectsCompliance = Undefined)
	
	// Do not execute replacement for the main objects in the match mode.
	If MainObjectSearchMode AND DataImportToValueTableMode() Then
		Return;
	EndIf;
	
	InfobaseObjectMappingQuery.SetParameter("InfobaseNode", ExchangeNodeForDataImport);
	InfobaseObjectMappingQuery.SetParameter("UniqueReceiverHandle", UUID);
	InfobaseObjectMappingQuery.SetParameter("ReceiverType", ReceiverTypeAsString);
	InfobaseObjectMappingQuery.SetParameter("SourceType", SourceTypeAsString);
	
	QueryResult = InfobaseObjectMappingQuery.Execute();
	
	If QueryResult.IsEmpty() Then
		
		InfobasesObjectsCompliance = New Structure;
		InfobasesObjectsCompliance.Insert("InfobaseNode", ExchangeNodeForDataImport);
		InfobasesObjectsCompliance.Insert("ReceiverType", ReceiverTypeAsString);
		InfobasesObjectsCompliance.Insert("SourceType", SourceTypeAsString);
		InfobasesObjectsCompliance.Insert("UniqueReceiverHandle", UUID);
		
		// Value will be determined after object is written.
		// Object may be assigned with a match while identifying object by the search fields.
		InfobasesObjectsCompliance.Insert("UniqueSourceHandle", Undefined);
		
	Else
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		UUID = Selection.UniqueSourceHandleAsString;
		
		ObjectMapFound = True;
		
	EndIf;
	
EndProcedure

Function DefineFieldHasUnlimitedLength(TypeManager, ParameterName)
	
	LongStrings = Undefined;
	If Not TypeManager.Property("LongStrings", LongStrings) Then
		
		LongStrings = New Map;
		For Each Attribute IN TypeManager.MDObject.Attributes Do
			
			If Attribute.Type.ContainsType(StringType) 
				AND (Attribute.Type.StringQualifiers.Length = 0) Then
				
				LongStrings.Insert(Attribute.Name, Attribute.Name);	
				
			EndIf;
			
		EndDo;
		
		TypeManager.Insert("LongStrings", LongStrings);
		
	EndIf;
	
	Return (LongStrings[ParameterName] <> Undefined);
		
EndFunction

Function DefineThisParameterIsOfUnlimitedLength(TypeManager, ParameterValue, ParameterName)
	
	If TypeOf(ParameterValue) = StringType Then
		OpenEndedString = DefineFieldHasUnlimitedLength(TypeManager, ParameterName);
	Else
		OpenEndedString = False;
	EndIf;
	
	Return OpenEndedString;
	
EndFunction

Function FindItemUsingQuery(PropertyStructure, SearchProperties, ObjectType = Undefined, 
	TypeManager = Undefined, RealPropertyForSearchCount = Undefined)
	
	PropertyCountForSearch = ?(RealPropertyForSearchCount = Undefined, SearchProperties.Count(), RealPropertyForSearchCount);
	
	If PropertyCountForSearch = 0
		AND PropertyStructure.TypeName = "Enum" Then
		
		Return PropertyStructure.EmptyRef;
		
	EndIf;
	
	QueryText       = PropertyStructure.SearchString;
	
	If IsBlankString(QueryText) Then
		Return PropertyStructure.EmptyRef;
	EndIf;
	
	SearchQuery       = New Query();
	
	PropertyUsedInSearchCount = 0;
	
	For Each Property IN SearchProperties Do
		
		ParameterName = Property.Key;
		
		// You can search not by all parameters.
		If ParameterName = "{UUID}" Or ParameterName = "{PredefinedItemName}" Then
			Continue;
		EndIf;
		
		ParameterValue = Property.Value;
		SearchQuery.SetParameter(ParameterName, ParameterValue);
		
		OpenEndedString = DefineThisParameterIsOfUnlimitedLength(PropertyStructure, ParameterValue, ParameterName);
		
		PropertyUsedInSearchCount = PropertyUsedInSearchCount + 1;
		
		If OpenEndedString Then
			
			QueryText = QueryText + ?(PropertyUsedInSearchCount > 1, " AND ", "") + ParameterName + " LIKE &" + ParameterName;
			
		Else
			
			QueryText = QueryText + ?(PropertyUsedInSearchCount > 1, " AND ", "") + ParameterName + " = &" + ParameterName;
			
		EndIf;
		
	EndDo;
	
	If PropertyUsedInSearchCount = 0 Then
		Return Undefined;
	EndIf;
	
	SearchQuery.Text = QueryText;
	Result = SearchQuery.Execute();
			
	If Result.IsEmpty() Then
		
		Return Undefined;
								
	Else
		
		// Return first found object.
		Selection = Result.Select();
		Selection.Next();
		ObjectReference = Selection.Ref;
				
	EndIf;
	
	Return ObjectReference;
	
EndFunction

// Determines object conversion rule (OCR) by the receiver object type.
// 
// Parameters:
//  RefTypeAsString - String - object type in a string presentation, for example, "CatalogRef.ProductsAndServices.
// 
// Returns:
//  MatchValue = Object conversion rule.
// 
Function GetConversionRuleWithSearchAlgorithmByTargetObjectType(RefTypeAsString)
	
	MapValue = ConversionRulesMap.Get(RefTypeAsString);
	
	If MapValue <> Undefined Then
		Return MapValue;
	EndIf;
	
	Try
	
		For Each Item IN Rules Do
			
			If Item.Value.Receiver = RefTypeAsString Then
				
				If Item.Value.HasSearchFieldSequenceHandler = True Then
					
					Rule = Item.Value;
					
					ConversionRulesMap.Insert(RefTypeAsString, Rule);
					
					Return Rule;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		ConversionRulesMap.Insert(RefTypeAsString, Undefined);
		Return Undefined;
	
	Except
		
		ConversionRulesMap.Insert(RefTypeAsString, Undefined);
		Return Undefined;
	
	EndTry;
	
EndFunction

Function FindLinkToDocument(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery, SearchByEqualDate)
	
	// Try to find document by date and number.
	SearchWithQuery = SearchByEqualDate OR (RealPropertyForSearchCount <> 2);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
	
	DocumentNumber = SearchProperties["Number"];
	DocumentDate  = SearchProperties["Date"];
					
	If (DocumentNumber <> Undefined) AND (DocumentDate <> Undefined) Then
						
		ObjectReference = PropertyStructure.Manager.FindByNumber(DocumentNumber, DocumentDate);
																		
	Else
						
		// Failed to find by date and number - it is required to search by query.
		SearchWithQuery = True;
		ObjectReference = Undefined;
						
	EndIf;
	
	Return ObjectReference;
	
EndFunction

Function FindItemBySearchProperties(ObjectType, ObjectTypeName, SearchProperties, 
	PropertyStructure, Stringofsearchpropertynames, SearchByEqualDate)
	
	// It is not required to search by the predefined item name and
	// by a unique ref to object, it is required to search only by those properties that are available in the property names string. If it is empty
	// there, then by all available search properties.
	
	If IsBlankString(Stringofsearchpropertynames) Then
		
		TemporarySearchProperties = SearchProperties;
		
	Else
		
		ResultingStringForParsing = StrReplace(Stringofsearchpropertynames, " ", "");
		StringLength = StrLen(ResultingStringForParsing);
		If Mid(ResultingStringForParsing, StringLength, 1) <> "," Then
			
			ResultingStringForParsing = ResultingStringForParsing + ",";
			
		EndIf;
		
		TemporarySearchProperties = New Map;
		For Each PropertyItem IN SearchProperties Do
			
			ParameterName = PropertyItem.Key;
			If Find(ResultingStringForParsing, ParameterName + ",") > 0 Then
				
				TemporarySearchProperties.Insert(ParameterName, PropertyItem.Value);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	UUIDProperty = TemporarySearchProperties["{UUID}"];
	PredefinedNameProperty    = TemporarySearchProperties["{PredefinedItemName}"];
	
	RealPropertyForSearchCount = TemporarySearchProperties.Count();
	RealPropertyForSearchCount = RealPropertyForSearchCount - ?(UUIDProperty <> Undefined, 1, 0);
	RealPropertyForSearchCount = RealPropertyForSearchCount - ?(PredefinedNameProperty    <> Undefined, 1, 0);
	
	SearchWithQuery = False;
	
	If ObjectTypeName = "Document" Then
		
		ObjectReference = FindLinkToDocument(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery, SearchByEqualDate);
		
	Else
		
		SearchWithQuery = True;
		
	EndIf;
	
	If SearchWithQuery Then
		
		ObjectReference = FindItemUsingQuery(PropertyStructure, TemporarySearchProperties, ObjectType, , RealPropertyForSearchCount);
		
	EndIf;
	
	Return ObjectReference;
EndFunction

Procedure ProcessObjectSearchPropertiesSetup(SetAllObjectSearchProperties, 
												ObjectType, 
												SearchProperties, 
												SearchPropertiesDontReplace, 
												ObjectReference, 
												CreatedObject, 
												WriteNewObjectToInfobase = True, 
												DontReplaceCreatedInTargetObject = False, 
												ObjectCreatedInCurrentInfobase = Undefined)
	
	If SetAllObjectSearchProperties <> True Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(ObjectReference) Then
		Return;
	EndIf;
	
	If CreatedObject = Undefined Then
		CreatedObject = ObjectReference.GetObject();
	EndIf;
	
	SetObjectSearchAttributes(CreatedObject, SearchProperties, SearchPropertiesDontReplace);
	
EndProcedure

Procedure ReadInformationAboutSearchProperties(ObjectType, SearchProperties, SearchPropertiesDontReplace,
	SearchByEqualDate = False, ObjectParameters = Undefined, Val MainObjectSearchMode, ObjectMapFound, InfobasesObjectsCompliance)
	
	If SearchProperties = "" Then
		SearchProperties = New Map;
	EndIf;
	
	If SearchPropertiesDontReplace = "" Then
		SearchPropertiesDontReplace = New Map;
	EndIf;
	
	TypeInformation = MapOfDataTypesForImport()[ObjectType];
	ReadSearchPropertiesFromFile(SearchProperties, SearchPropertiesDontReplace, TypeInformation, SearchByEqualDate, ObjectParameters, MainObjectSearchMode, ObjectMapFound, InfobasesObjectsCompliance);
	
EndProcedure

Procedure DefineObjectSearchAdditionalParameters(SearchProperties, ObjectType, PropertyStructure, ObjectTypeName, IsDocumentObject)
	
	If ObjectType = Undefined Then
		
		// Try to determine type by the search properties.
		RecipientTypeName = SearchProperties["{TypeNameInIBReceiver}"];
		If RecipientTypeName = Undefined Then
			RecipientTypeName = SearchProperties["{TypeNameInIBSource}"];
		EndIf;
		
		If RecipientTypeName <> Undefined Then
			
			ObjectType = Type(RecipientTypeName);	
			
		EndIf;		
		
	EndIf;
	
	PropertyStructure   = Managers[ObjectType];
	ObjectTypeName     = PropertyStructure.TypeName;	
	
EndProcedure

Function FindFirstRuleByPropertiesStructure(PropertyStructure)
	
	Try
		
		TargetRow = PropertyStructure.RefTypeAsString;
		
		If IsBlankString(TargetRow) Then
			Return Undefined;
		EndIf;
		
		For Each RuleRow IN Rules Do
			
			If RuleRow.Value.Receiver = TargetRow Then
				Return RuleRow.Value;
			EndIf;
			
		EndDo;
		
	Except
		
    EndTry;
	
	Return Undefined;
	
EndFunction

// Searches object in the infobase if it is not found, creates a new one.
//
// Parameters:
//  ObjectType     - searched object type.
//  SearchProperties - Structure containing properties according to which object is searched.
//  ObjectFound   - if False, then object is not found and the new one is created.
//
// Returns:
//  New or found infobase object.
//  
Function FindObjectByRef(ObjectType, 
							SearchProperties = "", 
							SearchPropertiesDontReplace = "", 
							ObjectFound = True, 
							CreatedObject = Undefined, 
							DontCreateObjectIfNotFound = False,
							MainObjectSearchMode = False,
							GlobalRefNPP = 0,
							RefNPP = 0,
							ObjectFoundBySearchFields = False,
							KnownUUIDRef = Undefined,
							SearchingImportObject = False,
							ObjectParameters = Undefined,
							DontReplaceCreatedInTargetObject = False,
							ObjectCreatedInCurrentInfobase = Undefined,
							RecordObjectChangeAtSenderNode = False,
							UUIDString = "",
							OCRName = "",
							InfobasesObjectsCompliance = Undefined,
							SearchBySearchFieldsIfNotFoundByID = Undefined)
	
	// Object is identified sequentially in five stages.
	// You go to the next stage
	// if search does not give a positive result.
	//
	// Identification (search) object stages:
	// 1. Object search by IB objects match register.
	// 2. Object search by predefined item name.
	// 3. Object search by reference unique ID.
	// 4. Object search by a random search algorithm.
	// 5. Object search by search fields.
	
	SearchByEqualDate = False;
	ObjectReference = Undefined;
	PropertyStructure = Undefined;
	ObjectTypeName = Undefined;
	IsDocumentObject = False;
	RefPropertyReadingCompleted = False;
	ObjectMapFound = False;
	
	GlobalRefNPP = deAttribute(ExchangeFile, NumberType, "GSn");
	RefNPP           = deAttribute(ExchangeFile, NumberType, "NPP");
	
	// Shows that object should be registered for export for node-sender (sending back).
	RecordObjectChangeAtSenderNode = deAttribute(ExchangeFile, BooleanType, "RecordObjectChangeAtSenderNode");
	
	FlagDontCreateObjectIfNotFound = deAttribute(ExchangeFile, BooleanType, "DoNotCreateIfNotFound");
	If Not ValueIsFilled(FlagDontCreateObjectIfNotFound) Then
		FlagDontCreateObjectIfNotFound = False;
	EndIf;
	
	If DontCreateObjectIfNotFound = Undefined Then
		DontCreateObjectIfNotFound = False;
	EndIf;
	
	OnExchangeObjectByRefSetGIUDOnly = Not MainObjectSearchMode;
		
	DontCreateObjectIfNotFound = DontCreateObjectIfNotFound OR FlagDontCreateObjectIfNotFound;
	
	DontReplaceCreatedInTargetObjectFlag = deAttribute(ExchangeFile, BooleanType, "DontReplaceCreatedInTargetObject");
	If Not ValueIsFilled(DontReplaceCreatedInTargetObjectFlag) Then
		DontReplaceCreatedInTargetObject = False;
	Else
		DontReplaceCreatedInTargetObject = DontReplaceCreatedInTargetObjectFlag;	
	EndIf;
	
	SearchBySearchFieldsIfNotFoundByID = deAttribute(ExchangeFile, BooleanType, "ContinueSearch");
	
	// 1. Object search by IB objects match register.
	ReadInformationAboutSearchProperties(ObjectType, SearchProperties, SearchPropertiesDontReplace, SearchByEqualDate, ObjectParameters, MainObjectSearchMode, ObjectMapFound, InfobasesObjectsCompliance);
	DefineObjectSearchAdditionalParameters(SearchProperties, ObjectType, PropertyStructure, ObjectTypeName, IsDocumentObject);
	
	UUIDProperty = SearchProperties["{UUID}"];
	PredefinedNameProperty    = SearchProperties["{PredefinedItemName}"];
	
	UUIDString = UUIDProperty;
	
	OnExchangeObjectByRefSetGIUDOnly = OnExchangeObjectByRefSetGIUDOnly
									AND UUIDProperty <> Undefined
	;
	
	If ObjectMapFound Then
		
		// 1. Search object by IB objects match register gave a positive result.
		
		ObjectReference = PropertyStructure.Manager.GetRef(New UUID(UUIDProperty));
		
		If MainObjectSearchMode Then
			
			CreatedObject = ObjectReference.GetObject();
			
			If CreatedObject <> Undefined Then
				
				SetObjectSearchAttributes(CreatedObject, SearchProperties, SearchPropertiesDontReplace);
				
				ObjectFound = True;
				
				Return ObjectReference;
				
			EndIf;
			
		Else
			
			// For not main objects (exported by ref) receive reference with the specified GUID.
			Return ObjectReference;
			
		EndIf;
		
	EndIf;
	
	// 2. Search for predefined item name object.
	If PredefinedNameProperty <> Undefined Then
		
		CreateNewObjectAutomatically = False;
		
		ObjectReference = FindOrCreateObjectByProperty(PropertyStructure,
													ObjectType,
													SearchProperties,
													SearchPropertiesDontReplace,
													ObjectTypeName,
													"{PredefinedItemName}",
													PredefinedNameProperty,
													ObjectFound,
													CreateNewObjectAutomatically,
													CreatedObject,
													MainObjectSearchMode,
													,
													RefNPP, GlobalRefNPP,
													ObjectParameters,
													DontReplaceCreatedInTargetObject,
													ObjectCreatedInCurrentInfobase);
		
		If ObjectReference <> Undefined
			AND ObjectReference.IsEmpty() Then
			
			ObjectFound = False;
			ObjectReference = Undefined;
					
		EndIf;
			
		If    ObjectReference <> Undefined
			OR CreatedObject <> Undefined Then
			
			ObjectFound = True;
			
			// 2. Search for predefined item name object gave a positive result.
			Return ObjectReference;
			
		EndIf;
		
	EndIf;
	
	// 3. Object search by reference unique ID.
	If UUIDProperty <> Undefined Then
		
		If MainObjectSearchMode Then
			
			CreateNewObjectAutomatically = Not DontCreateObjectIfNotFound AND Not SearchBySearchFieldsIfNotFoundByID;
			
			ObjectReference = FindOrCreateObjectByProperty(PropertyStructure,
														ObjectType,
														SearchProperties,
														SearchPropertiesDontReplace,
														ObjectTypeName,
														"{UUID}",
														UUIDProperty,
														ObjectFound,
														CreateNewObjectAutomatically,
														CreatedObject,
														MainObjectSearchMode,
														KnownUUIDRef,
														RefNPP,
														GlobalRefNPP,
														ObjectParameters,
														DontReplaceCreatedInTargetObject,
														ObjectCreatedInCurrentInfobase);
			If Not SearchBySearchFieldsIfNotFoundByID Then
				
				Return ObjectReference;
				
			EndIf;
			
		ElsIf SearchBySearchFieldsIfNotFoundByID Then
			
			CreateNewObjectAutomatically = False;
			
			ObjectReference = FindOrCreateObjectByProperty(PropertyStructure,
														ObjectType,
														SearchProperties,
														SearchPropertiesDontReplace,
														ObjectTypeName,
														"{UUID}",
														UUIDProperty,
														ObjectFound,
														CreateNewObjectAutomatically,
														CreatedObject,
														MainObjectSearchMode,
														KnownUUIDRef,
														RefNPP,
														GlobalRefNPP,
														ObjectParameters,
														DontReplaceCreatedInTargetObject,
														ObjectCreatedInCurrentInfobase);
			
		Else
			
			// For not main objects (exported by ref) receive reference with the specified GUID.
			Return PropertyStructure.Manager.GetRef(New UUID(UUIDProperty));
			
		EndIf;
		
		If ObjectReference <> Undefined 
			AND ObjectReference.IsEmpty() Then
			
			ObjectFound = False;
			ObjectReference = Undefined;
					
		EndIf;
			
		If    ObjectReference <> Undefined
			OR CreatedObject <> Undefined Then
			
			ObjectFound = True;
			
			// 3. Search for object by reference unique ID gave a positive result.
			Return ObjectReference;
			
		EndIf;
		
	EndIf;
	
	// 4. Object search by a random search algorithm.
	Variantsearchnumber = 1;
	Stringofsearchpropertynames = "";
	PreviousSearchString = Undefined;
	StopSearch = False;
	SetAllObjectSearchProperties = True;
	OCR = Undefined;
	SearchAlgorithm = "";
	
	If Not IsBlankString(OCRName) Then
		
		OCR = Rules[OCRName];
		
	EndIf;
	
	If OCR = Undefined Then
		
		OCR = GetConversionRuleWithSearchAlgorithmByTargetObjectType(PropertyStructure.RefTypeAsString);
		
	EndIf;
	
	If OCR <> Undefined Then
		
		SearchAlgorithm = OCR.SearchFieldSequence;
		
	EndIf;
	
	HasSearchAlgorithm = Not IsBlankString(SearchAlgorithm);
	
	While Variantsearchnumber <= 10
		AND HasSearchAlgorithm Do
		
		Try
			
			If DebuggingImportHandlers Then
				
				ExecuteHandler_OCR_SearchFieldSequence(Variantsearchnumber, SearchProperties, ObjectParameters, StopSearch,
																	  ObjectReference, SetAllObjectSearchProperties, Stringofsearchpropertynames,
																	  OCR.HandlerNameSearchFieldsSequence);
				
			Else
				
				Execute(SearchAlgorithm);
				
			EndIf;
			
		Except
			
			WriteInformationAboutOCRHandlerErrorImport(73, ErrorDescription(), "", "", 
				ObjectType, Undefined, NStr("en='Search fields sequence';ru='Последовательность полей поиска'"));
			
		EndTry;
		
		DontSearch = StopSearch = True 
			OR Stringofsearchpropertynames = PreviousSearchString
			OR ValueIsFilled(ObjectReference);				
			
		If Not DontSearch Then
	
			// the search itself
			ObjectReference = FindItemBySearchProperties(ObjectType, ObjectTypeName, SearchProperties, PropertyStructure, 
				Stringofsearchpropertynames, SearchByEqualDate);
				
			DontSearch = ValueIsFilled(ObjectReference);
			
			If ObjectReference <> Undefined
				AND ObjectReference.IsEmpty() Then
				ObjectReference = Undefined;
			EndIf;
			
		EndIf;
		
		If DontSearch Then
		
			If MainObjectSearchMode Then
			
				ProcessObjectSearchPropertiesSetup(SetAllObjectSearchProperties, 
													ObjectType, 
													SearchProperties, 
													SearchPropertiesDontReplace, 
													ObjectReference, 
													CreatedObject, 
													Not MainObjectSearchMode, 
													DontReplaceCreatedInTargetObject, 
													ObjectCreatedInCurrentInfobase);
					
			EndIf;
						
			Break;
			
		EndIf;	
	
		Variantsearchnumber = Variantsearchnumber + 1;
		PreviousSearchString = Stringofsearchpropertynames;
		
	EndDo;
		
	If Not HasSearchAlgorithm Then
		
		// 5. Object search by search fields.
		ObjectReference = FindItemBySearchProperties(ObjectType, ObjectTypeName, SearchProperties, PropertyStructure, 
					Stringofsearchpropertynames, SearchByEqualDate);
		
	EndIf;
	
	If MainObjectSearchMode
		AND ValueIsFilled(ObjectReference)
		AND (ObjectTypeName = "Document" 
		OR ObjectTypeName = "Task"
		OR ObjectTypeName = "BusinessProcess") Then
		
		// If document has date in the search properties - , then set it.
		EmptyDate = Not ValueIsFilled(SearchProperties["Date"]);
		CanReplace = (NOT EmptyDate) 
			AND (SearchPropertiesDontReplace["Date"] = Undefined);
			
		If CanReplace Then
			
			If CreatedObject = Undefined Then
				CreatedObject = ObjectReference.GetObject();
			EndIf;
			
			CreatedObject.Date = SearchProperties["Date"];
				
		EndIf;
		
	EndIf;		
	
	// You do not have to always create new object.
	If (ObjectReference = Undefined
			OR ObjectReference.IsEmpty())
		AND CreatedObject = Undefined Then // Object is not found by search fields.
		
		If OnExchangeObjectByRefSetGIUDOnly Then
			
			ObjectReference = PropertyStructure.Manager.GetRef(New UUID(UUIDProperty));	
			DummyObjectRef = True;
			
		ElsIf Not DontCreateObjectIfNotFound Then
		
			ObjectReference = CreateNewObject(ObjectType, SearchProperties, CreatedObject, 
				Not MainObjectSearchMode, KnownUUIDRef, RefNPP, GlobalRefNPP, 
				FindFirstRuleByPropertiesStructure(PropertyStructure), ObjectParameters, SetAllObjectSearchProperties);		
				
		EndIf;
			
		ObjectFound = False;
		
	Else
		
		// Object is found by search fields.
		ObjectFound = True;
			
	EndIf;
	
	If ObjectReference <> Undefined
		AND ObjectReference.IsEmpty() Then
		
		ObjectReference = Undefined;
		
	EndIf;
	
	ObjectFoundBySearchFields = ObjectFound;
	
	Return ObjectReference;
	
EndFunction 

Procedure SetExchangeFileCollectionProperties(Object, ExchangeFileCollection, TypeInformation,
	ObjectParameters, RecNo, Val TabularSectionName, Val OrderFieldName)
	
	BranchName = TabularSectionName + "TabularSection";
	
	CollectionRow = ExchangeFileCollection.Add();
	CollectionRow[OrderFieldName] = RecNo;
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
				
		If NodeName = "Property" OR
			 NodeName = "ParameterValue" Then
			 
			IsParameter = (NodeName = "ParameterValue");
			
			Name    = deAttribute(ExchangeFile, StringType, "Name");
			OCRName = deAttribute(ExchangeFile, StringType, "OCRName");
			
			PropertyType = GetPropertyTypeByAdditionalInformation(TypeInformation, Name);
			
			PropertyValue = ReadProperty(PropertyType,,, OCRName);
			
			If IsParameter Then
				
				AddComplexParameterIfNeeded(ObjectParameters, BranchName, RecNo, Name, PropertyValue);
				
			Else
				
				Try
					
					CollectionRow[Name] = PropertyValue;
					
				Except
					
					LR = GetProtocolRecordStructure(26, ErrorDescription());
					LR.OCRName           = OCRName;
					LR.Object           = Object;
					LR.ObjectType       = TypeOf(Object);
					LR.Property         = "Object." + TabularSectionName + "." + Name;
					LR.Value         = PropertyValue;
					LR.ValueType      = TypeOf(PropertyValue);
					ErrorMessageString = WriteInExecutionProtocol(26, LR, True);
					
					If Not ContinueOnError Then
						Raise ErrorMessageString;
					EndIf;
					
				EndTry;
				
			EndIf;
			
		ElsIf NodeName = "ExtDimensionDr" OR NodeName = "ExtDimensionCr" Then
			
			deIgnore(ExchangeFile);
				
		ElsIf (NodeName = "Record") AND (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		Else
			
			WriteInExecutionProtocol(9);
			
			Break;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports object tabular section.
//
Procedure ImportTabularSection(Object, TabularSectionName, DocumentTypeCommonInformation, ObjectParameters, OCR)
	
	Var KeySearchFields;
	Var KeySearchFieldArray;
	
	Result = GetKeySearchFieldsByTabularSection(OCR, TabularSectionName, KeySearchFieldArray, KeySearchFields);
	
	If Not Result Then
		
		KeySearchFieldArray = New Array;
		
		MetadataObjectTabularSection = Object.Metadata().TabularSections[TabularSectionName];
		
		For Each Attribute IN MetadataObjectTabularSection.Attributes Do
			
			KeySearchFieldArray.Add(Attribute.Name);
			
		EndDo;
		
		KeySearchFields = StringFunctionsClientServer.RowFromArraySubrows(KeySearchFieldArray);
		
	EndIf;
	
	UUID = StrReplace(String(New UUID), "-", "_");
	
	OrderFieldName = "SortingField_[UUID]";
	OrderFieldName = StrReplace(OrderFieldName, "[UUID]", UUID);
	
	IteratorColumnName = "IteratorField_[UUID]";
	IteratorColumnName = StrReplace(IteratorColumnName, "[UUID]", UUID);
	
	ObjectTabularSection = Object[TabularSectionName];
	
	ObjectCollection = ObjectTabularSection.Unload();
	
	ExchangeFileCollection = ObjectCollection.CopyColumns();
	ExchangeFileCollection.Columns.Add(OrderFieldName);
	
	FillExchangeFileCollection(Object, ExchangeFileCollection, TabularSectionName, DocumentTypeCommonInformation, ObjectParameters, KeySearchFieldArray, OrderFieldName);
	
	AddColumnWithValueToTable(ExchangeFileCollection, +1, IteratorColumnName);
	AddColumnWithValueToTable(ObjectCollection,     -1, IteratorColumnName);
	
	GroupCollection = TableByKeyFieldsInitialization(KeySearchFieldArray);
	GroupCollection.Columns.Add(IteratorColumnName);
	
	FillTablePropertyValues(ExchangeFileCollection, GroupCollection);
	FillTablePropertyValues(ObjectCollection,     GroupCollection);
	
	GroupCollection.GroupBy(KeySearchFields, IteratorColumnName);
	
	OrderCollection = ObjectTabularSection.UnloadColumns();
	OrderCollection.Columns.Add(OrderFieldName);
	
	For Each CollectionRow IN GroupCollection Do
		
		// receive filter structure
		Filter = New Structure();
		
		For Each FieldName IN KeySearchFieldArray Do
			
			Filter.Insert(FieldName, CollectionRow[FieldName]);
			
		EndDo;
		
		OrderFieldValues = Undefined;
		
		If CollectionRow[IteratorColumnName] = 0 Then
			
			// Fill in tabular section strings from the object old version.
			ObjectCollectionRows = ObjectCollection.FindRows(Filter);
			
			OrderFieldValues = ExchangeFileCollection.FindRows(Filter);
			
		Else
			
			// Fill in tabular section strings from the exchange file collection.
			ObjectCollectionRows = ExchangeFileCollection.FindRows(Filter);
			
		EndIf;
		
		// Add object tabular section strings.
		For Each CollectionRow IN ObjectCollectionRows Do
			
			OrderCollectionRow = OrderCollection.Add();
			
			FillPropertyValues(OrderCollectionRow, CollectionRow);
			
			If OrderFieldValues <> Undefined Then
				
				OrderCollectionRow[OrderFieldName] = OrderFieldValues[ObjectCollectionRows.Find(CollectionRow)][OrderFieldName];
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	OrderCollection.Sort(OrderFieldName);
	
	// Import result to the object tabular section.
	Try
		ObjectTabularSection.Load(OrderCollection);
	Except
		
		Text = NStr("en='Tabular section name: %1';ru='Имя табличной части: %1'");
		
		LR = GetProtocolRecordStructure(83, ErrorDescription());
		LR.Object     = Object;
		LR.ObjectType = TypeOf(Object);
		LR.Text = StringFunctionsClientServer.PlaceParametersIntoString(Text, TabularSectionName);
		WriteInExecutionProtocol(83, LR);
		
		deIgnore(ExchangeFile);
		Return;
	EndTry;
	
EndProcedure

Procedure FillTablePropertyValues(SourceCollection, TargetCollection)
	
	For Each CollectionItem IN SourceCollection Do
		
		FillPropertyValues(TargetCollection.Add(), CollectionItem);
		
	EndDo;
	
EndProcedure

Function TableByKeyFieldsInitialization(KeySearchFieldArray)
	
	Collection = New ValueTable;
	
	For Each FieldName IN KeySearchFieldArray Do
		
		Collection.Columns.Add(FieldName);
		
	EndDo;
	
	Return Collection;
	
EndFunction

Procedure AddColumnWithValueToTable(Collection, Value, IteratorColumnName)
	
	Collection.Columns.Add(IteratorColumnName);
	Collection.FillValues(Value, IteratorColumnName);
	
EndProcedure

Function GetArrayFromString(Val ItemString)
	
	Result = New Array;
	
	ItemString = ItemString + ",";
	
	While True Do
		
		Pos = Find(ItemString, ",");
		
		If Pos = 0 Then
			Break; // Exit
		EndIf;
		
		Item = Left(ItemString, Pos - 1);
		
		Result.Add(TrimAll(Item));
		
		ItemString = Mid(ItemString, Pos + 1);
		
	EndDo;
	
	Return Result;
	
EndFunction

Procedure FillExchangeFileCollection(Object, ExchangeFileCollection, TabularSectionName, DocumentTypeCommonInformation, ObjectParameters, KeySearchFieldArray, OrderFieldName)
	
	BranchName = TabularSectionName + "TabularSection";
	
	If DocumentTypeCommonInformation <> Undefined Then
		TypeInformation = DocumentTypeCommonInformation[BranchName];
	Else
		TypeInformation = Undefined;
	EndIf;
	
	RecNo = 0;
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
				
		If NodeName = "Record" Then
			
			SetExchangeFileCollectionProperties(Object, ExchangeFileCollection, TypeInformation, ObjectParameters, RecNo, TabularSectionName, OrderFieldName);
			
			RecNo = RecNo + 1;
			
		ElsIf (NodeName = "TabularSection") AND (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		Else
			
			WriteInExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function GetKeySearchFieldsByTabularSection(OCR, TabularSectionName, KeySearchFieldArray, KeySearchFields)
	
	If OCR = Undefined Then
		Return False;
	EndIf;
	
	SearchDataInTS = OCR.SearchInTabularSections.Find("TabularSection." + TabularSectionName, "ItemName");
	
	If SearchDataInTS = Undefined Then
		Return False;
	EndIf;
	
	If Not SearchDataInTS.Valid Then
		Return False;
	EndIf;
	
	KeySearchFieldArray = SearchDataInTS.KeySearchFieldArray;
	KeySearchFields        = SearchDataInTS.KeySearchFields;
	
	Return True;

EndFunction

// Imports object movement
//
// Parameters:
//  Object         - object movements of which should be imported.
//  Name            - register name.
//  Clear       - if True, then movements are cleared beforehand.
// 
Procedure ImportRegisterRecords(Object, Name, Clear, DocumentTypeCommonInformation, 
	ObjectParameters, Rule)
	
	RegisterRecordName = Name + "RecordSet";
	If DocumentTypeCommonInformation <> Undefined Then
		TypeInformation = DocumentTypeCommonInformation[RegisterRecordName];
	Else
	    TypeInformation = Undefined;
	EndIf;
	
	SearchDataInTS = Undefined;
	
	TSCopyForSearch = Undefined;
	
	RegisterRecords = Object.RegisterRecords[Name];
	RegisterRecords.Write = True;
	
	RegisterRecords.Read();

	If Clear
		AND RegisterRecords.Count() <> 0 Then
		
		If SearchDataInTS <> Undefined Then 
			TSCopyForSearch = RegisterRecords.Unload();
		EndIf;
		
        RegisterRecords.Clear();
		
	ElsIf SearchDataInTS <> Undefined Then
		
		TSCopyForSearch = RegisterRecords.Unload();	
		
	EndIf;
	
	RecNo = 0;
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
			
		If      NodeName = "Record" Then
			
			Record = RegisterRecords.Add();
			SetRecordProperties(Record, TypeInformation, ObjectParameters, RegisterRecordName, RecNo, SearchDataInTS, TSCopyForSearch);
			
			RecNo = RecNo + 1;
			
		ElsIf (NodeName = "RecordSet") AND (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		Else
			
			WriteInExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Sets objects properties (record).
//
// Parameters:
//  Record         - object which properties you should set.
//                   For example, tabular section row and register record.
//
Procedure SetRecordProperties(Record, TypeInformation, 
	ObjectParameters, BranchName, RecNo,
	SearchDataInTS = Undefined, TSCopyForSearch = Undefined)
	
	MustSearchInTS = (SearchDataInTS <> Undefined)
								AND (TSCopyForSearch <> Undefined)
								AND TSCopyForSearch.Count() <> 0;
								
	If MustSearchInTS Then
									
		PropertyReadingStructure = New Structure();
		ExtDimensionReadingStructure = New Structure();
		
	EndIf;
		
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
				
		If NodeName = "Property"
			OR NodeName = "ParameterValue" Then
			
			
			IsParameter = (NodeName = "ParameterValue");
			
			Name    = deAttribute(ExchangeFile, StringType, "Name");
			OCRName = deAttribute(ExchangeFile, StringType, "OCRName");
			
			If Name = "RecordType" AND Find(Metadata.FindByType(TypeOf(Record)).FullName(), "AccumulationRegister") Then
				
				PropertyType = AccumulationRecordTypeType;
				
			Else
				
				PropertyType = GetPropertyTypeByAdditionalInformation(TypeInformation, Name);
				
			EndIf;
			
			PropertyValue = ReadProperty(PropertyType,,, OCRName);
			
			If IsParameter Then
				AddComplexParameterIfNeeded(ObjectParameters, BranchName, RecNo, Name, PropertyValue);			
			ElsIf MustSearchInTS Then 
				PropertyReadingStructure.Insert(Name, PropertyValue);	
			Else
				
				Try
					
					Record[Name] = PropertyValue;
					
				Except
					
					LR = GetProtocolRecordStructure(26, ErrorDescription());
					LR.OCRName           = OCRName;
					LR.Object           = Record;
					LR.ObjectType       = TypeOf(Record);
					LR.Property         = Name;
					LR.Value         = PropertyValue;
					LR.ValueType      = TypeOf(PropertyValue);
					ErrorMessageString = WriteInExecutionProtocol(26, LR, True);
					
					If Not ContinueOnError Then
						Raise ErrorMessageString;
					EndIf;
					
				EndTry;
				
			EndIf;
			
		ElsIf NodeName = "ExtDimensionDr" OR NodeName = "ExtDimensionCr" Then
			
			// Search by extra dimension is not implemented.
			
			Key = Undefined;
			Value = Undefined;
			
			While ExchangeFile.Read() Do
				
				NodeName = ExchangeFile.LocalName;
								
				If NodeName = "Property" Then
					
					Name    = deAttribute(ExchangeFile, StringType, "Name");
					OCRName = deAttribute(ExchangeFile, StringType, "OCRName");
					
					PropertyType = GetPropertyTypeByAdditionalInformation(TypeInformation, Name);
										
					If Name = "Key" Then
						
						Key = ReadProperty(PropertyType);
						
					ElsIf Name = "Value" Then
						
						Value = ReadProperty(PropertyType,,, OCRName);
						
					EndIf;
					
				ElsIf (NodeName = "ExtDimensionDr" OR NodeName = "ExtDimensionCr") AND (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
					
					Break;
					
				Else
					
					WriteInExecutionProtocol(9);
					Break;
					
				EndIf;
				
			EndDo;
			
			If Key <> Undefined 
				AND Value <> Undefined Then
				
				If Not MustSearchInTS Then
				
					Record[NodeName][Key] = Value;
					
				Else
					
					RecordMapping = Undefined;
					If Not ExtDimensionReadingStructure.Property(NodeName, RecordMapping) Then
						RecordMapping = New Map;
						ExtDimensionReadingStructure.Insert(NodeName, RecordMapping);
					EndIf;
					
					RecordMapping.Insert(Key, Value);
					
				EndIf;
				
			EndIf;
				
		ElsIf (NodeName = "Record") AND (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		Else
			
			WriteInExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;
	
	If MustSearchInTS Then
		
		SearchStructure = New Structure();
		
		For Each SearchItem IN  SearchDataInTS.TSSearchFields Do
			
			ItemValue = Undefined;
			PropertyReadingStructure.Property(SearchItem, ItemValue);
			
			SearchStructure.Insert(SearchItem, ItemValue);		
			
		EndDo;		
		
		SearchResultArray = TSCopyForSearch.FindRows(SearchStructure);
		
		RecordFound = SearchResultArray.Count() > 0;
		If RecordFound Then
			FillPropertyValues(Record, SearchResultArray[0]);
		EndIf;
		
		// Over filling with properties and extra dimension value.
		For Each KeyAndValue IN PropertyReadingStructure Do
			
			Record[KeyAndValue.Key] = KeyAndValue.Value;
			
		EndDo;
		
		For Each ElementName IN ExtDimensionReadingStructure Do
			
			For Each ItemKey IN ElementName.Value Do
			
				Record[ElementName.Key][ItemKey.Key] = ItemKey.Value;
				
			EndDo;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Imports object of the TypeDescription type from the specified xml-source.
//
// Parameters:
//  Source         - xml-source.
// 
Function ImportObjectTypes(Source)
	
	// DateQualifiers
	
	DateContent =  deAttribute(Source, StringType,  "DateContent");
	
	// StringQualifiers
	
	Length           =  deAttribute(Source, NumberType,  "Length");
	AllowedLength =  deAttribute(Source, StringType, "AllowedLength");
	
	// NumberQualifiers
	
	Digits             = deAttribute(Source, NumberType,  "Digits");
	FractionDigits = deAttribute(Source, NumberType,  "FractionDigits");
	AllowedFlag          = deAttribute(Source, StringType, "AllowedSign");
	
	// Read types array
	
	TypeArray = New Array;
	
	While Source.Read() Do
		NodeName = Source.LocalName;
		
		If      NodeName = "Type" Then
			TypeArray.Add(Type(deItemValue(Source, StringType)));
		ElsIf (NodeName = "Types") AND ( Source.NodeType = XMLNodeTypeEndElement) Then
			Break;
		Else
			WriteInExecutionProtocol(9);
			Break;
		EndIf;
		
	EndDo;
	
	If TypeArray.Count() > 0 Then
		
		// DateQualifiers
		
		If DateContent = "Date" Then
			DateQualifiers   = New DateQualifiers(DateFractions.Date);
		ElsIf DateContent = "DateTime" Then
			DateQualifiers   = New DateQualifiers(DateFractions.DateTime);
		ElsIf DateContent = "Time" Then
			DateQualifiers   = New DateQualifiers(DateFractions.Time);
		Else
			DateQualifiers   = New DateQualifiers(DateFractions.DateTime);
		EndIf;
		
		// NumberQualifiers
		
		If Digits > 0 Then
			If AllowedFlag = "Nonnegative" Then
				Mark = AllowedSign.Nonnegative;
			Else
				Mark = AllowedSign.Any;
			EndIf; 
			NumberQualifiers  = New NumberQualifiers(Digits, FractionDigits, Mark);
		Else
			NumberQualifiers  = New NumberQualifiers();
		EndIf;
		
		// StringQualifiers
		
		If Length > 0 Then
			If AllowedLength = "Fixed" Then
				AllowedLength = AllowedLength.Fixed;
			Else
				AllowedLength = AllowedLength.Variable;
			EndIf;
			StringQualifiers = New StringQualifiers(Length, AllowedLength);
		Else
			StringQualifiers = New StringQualifiers();
		EndIf; 
		
		Return New TypeDescription(TypeArray, NumberQualifiers, StringQualifiers, DateQualifiers);
	EndIf;
	
	Return Undefined;
	
EndFunction

Procedure WriteDocumentInSafeMode(Document, ObjectType)
	
	If Document.Posted Then
						
		Document.Posted = False;
			
	EndIf;		
								
	WriteObjectToIB(Document, ObjectType);	
	
EndProcedure

Function GetObjectByRefAndAddInformation(CreatedObject, Ref)
	
	// If object is created, then work with it if you find it, - receive object.
	If CreatedObject <> Undefined Then
		
		Object = CreatedObject;
		
	ElsIf Ref = Undefined Then
		
		Object = Undefined;
		
	ElsIf Ref.IsEmpty() Then
		
		Object = Undefined;
		
	Else
		
		Object = Ref.GetObject();
		
	EndIf;
	
	Return Object;
EndFunction

Procedure CommentsToObjectImport(NPP, Rulename, Source, ObjectType, GNPP = 0)
	
	If CommentObjectProcessingFlag Then
		
		MessageString = NStr("en='Import object No %1';ru='Загрузка объекта № %1'");
		Number = ?(NPP <> 0, NPP, GNPP);
		MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, Number);
		
		LR = GetProtocolRecordStructure();
		
		If Not IsBlankString(Rulename) Then
			
			LR.OCRName = Rulename;
			
		EndIf;
		
		If Not IsBlankString(Source) Then
			
			LR.Source = Source;
			
		EndIf;
		
		LR.ObjectType = ObjectType;
		WriteInExecutionProtocol(MessageString, LR, False);
		
	EndIf;	
	
EndProcedure

Procedure AddParameterIfNeeded(DataParameters, ParameterName, ParameterValue)
	
	If DataParameters = Undefined Then
		DataParameters = New Map;
	EndIf;
	
	DataParameters.Insert(ParameterName, ParameterValue);
	
EndProcedure

Procedure AddComplexParameterIfNeeded(DataParameters, ParameterBranchName, LineNumber, ParameterName, ParameterValue)
	
	If DataParameters = Undefined Then
		DataParameters = New Map;
	EndIf;
	
	CurrentParameterData = DataParameters[ParameterBranchName];
	
	If CurrentParameterData = Undefined Then
		
		CurrentParameterData = New ValueTable;
		CurrentParameterData.Columns.Add("LineNumber");
		CurrentParameterData.Columns.Add("ParameterName");
		CurrentParameterData.Indexes.Add("LineNumber");
		
		DataParameters.Insert(ParameterBranchName, CurrentParameterData);	
		
	EndIf;
	
	If CurrentParameterData.Columns.Find(ParameterName) = Undefined Then
		CurrentParameterData.Columns.Add(ParameterName);
	EndIf;		
	
	RowData = CurrentParameterData.Find(LineNumber, "LineNumber");
	If RowData = Undefined Then
		RowData = CurrentParameterData.Add();
		RowData.LineNumber = LineNumber;
	EndIf;		
	
	RowData[ParameterName] = ParameterValue;
	
EndProcedure

Function ReadInformationAboutObjectRegistration()
	
	// Assign CROSS values to variables; IR is symmetrical.
	UniqueReceiverHandle = deAttribute(ExchangeFile, StringType, "UniqueSourceHandle");
	UniqueSourceHandle = deAttribute(ExchangeFile, StringType, "UniqueReceiverHandle");
	ReceiverType                     = deAttribute(ExchangeFile, StringType, "SourceType");
	SourceType                     = deAttribute(ExchangeFile, StringType, "ReceiverType");
	EmptySet                      = deAttribute(ExchangeFile, BooleanType, "EmptySet");
	
	Try
		UniqueSourceHandle = New UUID(UniqueSourceHandle);
	Except
		
		deIgnore(ExchangeFile, "ObjectChangeRecordData");
		Return Undefined;
		
	EndTry;
	
	// Get source properties structure by the source type.
	PropertyStructure = Managers[Type(SourceType)];
	
	// Get source reference by GUID.
	UniqueSourceHandle = PropertyStructure.Manager.GetRef(UniqueSourceHandle);
	
	RecordSet = ObjectMappingRegisterManager.CreateRecordSet();
	
	// filter for records set
	RecordSet.Filter.InfobaseNode.Set(ExchangeNodeForDataImport);
	RecordSet.Filter.UniqueSourceHandle.Set(UniqueSourceHandle);
	RecordSet.Filter.UniqueReceiverHandle.Set(UniqueReceiverHandle);
	RecordSet.Filter.SourceType.Set(SourceType);
	RecordSet.Filter.ReceiverType.Set(ReceiverType);
	
	If Not EmptySet Then
		
		// Add one record to set.
		SetRow = RecordSet.Add();
		
		SetRow.InfobaseNode           = ExchangeNodeForDataImport;
		SetRow.UniqueSourceHandle = UniqueSourceHandle;
		SetRow.UniqueReceiverHandle = UniqueReceiverHandle;
		SetRow.SourceType                     = SourceType;
		SetRow.ReceiverType                     = ReceiverType;
		
	EndIf;
	
	// write the set of records
	WriteObjectToIB(RecordSet, "InformationRegisterRecordSet.InfobasesObjectsCompliance");
	
	deIgnore(ExchangeFile, "ObjectChangeRecordData");
	
	Return RecordSet;
	
EndFunction

Procedure ExportInformationComparingCorrection()
	
	ConversionRules = ConversionRulesTable.Copy(New Structure("SynchronizeByID", True), "SourceType, ReceiverType");
	ConversionRules.GroupBy("SourceType, ReceiverType");
	
	For Each Rule IN ConversionRules Do
		
		Manager = Managers.Get(Type(Rule.SourceType)).Manager;
		
		If TypeOf(Manager) = Type("BusinessProcessRoutePoints") Then
			Continue;
		EndIf;
		
		If Manager <> Undefined Then
			
			Selection = Manager.Select();
			
			While Selection.Next() Do
				
				UUID = String(Selection.Ref.UUID());
				
				Receiver = CreateNode("ObjectChangeRecordDataAdjustment");
				
				SetAttribute(Receiver, "UUID", UUID);
				SetAttribute(Receiver, "SourceType",            Rule.SourceType);
				SetAttribute(Receiver, "ReceiverType",            Rule.ReceiverType);
				
				Receiver.WriteEndElement(); // ObjectChangeRecordDataAdjustment
				
				WriteToFile(Receiver);
				
				IncreaseExportedObjectsCounter();
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ReadInformationComparingCorrection()
	
	// Assign CROSS values to variables; IR is symmetrical.
	UUID = deAttribute(ExchangeFile, StringType, "UUID");
	ReceiverType            = deAttribute(ExchangeFile, StringType, "SourceType");
	SourceType            = deAttribute(ExchangeFile, StringType, "ReceiverType");
	
	UniqueReceiverHandle = UUID;
	UniqueSourceHandle = UUID;
	
	InfobaseObjectMappingQuery.SetParameter("InfobaseNode", ExchangeNodeForDataImport);
	InfobaseObjectMappingQuery.SetParameter("UniqueReceiverHandle", UniqueReceiverHandle);
	InfobaseObjectMappingQuery.SetParameter("ReceiverType", ReceiverType);
	InfobaseObjectMappingQuery.SetParameter("SourceType", SourceType);
	
	QueryResult = InfobaseObjectMappingQuery.Execute();
	
	If Not QueryResult.IsEmpty() Then
		Return; // There is information in register; skip data.
	EndIf;
	
	Try
		UUID = UniqueSourceHandle;
		UniqueSourceHandle = New UUID(UniqueSourceHandle);
	Except
		Return;
	EndTry;
	
	// Get source properties structure by the source type.
	PropertyStructure = Managers[Type(SourceType)];
	
	// Get source reference by GUID.
	UniqueSourceHandle = PropertyStructure.Manager.GetRef(UniqueSourceHandle);
	
	Object = UniqueSourceHandle.GetObject();
	
	If Object = Undefined Then
		Return; // There is no such object in base; skip data.
	EndIf;
	
	// Add record to the match register.
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode", ExchangeNodeForDataImport);
	RecordStructure.Insert("UniqueSourceHandle", UniqueSourceHandle);
	RecordStructure.Insert("UniqueReceiverHandle", UniqueReceiverHandle);
	RecordStructure.Insert("ReceiverType",                     ReceiverType);
	RecordStructure.Insert("SourceType",                     SourceType);
	
	InformationRegisters.InfobasesObjectsCompliance.AddRecord(RecordStructure);
	
	IncreaseImportedObjectsCounter();
	
EndProcedure

Function ReadRegisterRecordSet()
	
	// Variable-stubs to support debugging mechanism of events handlers code.
	Var Ref,ObjectFound, Donotreplaceobject, WriteMode, PostingMode, Generatenewnumberorcodeifnotspecified, ObjectModified;
	
	NPP						= deAttribute(ExchangeFile, NumberType,  "NPP");
	Rulename				= deAttribute(ExchangeFile, StringType, "Rulename");
	ObjectTypeAsString       = deAttribute(ExchangeFile, StringType, "Type");
	ExchangeObjectPriority  = GetExchangeObjectPriority(ExchangeFile);
	
	IsEmptySet			= deAttribute(ExchangeFile, BooleanType, "EmptySet");
	If Not ValueIsFilled(IsEmptySet) Then
		IsEmptySet = False;
	EndIf;
	
	ObjectType 				= Type(ObjectTypeAsString);
	Source 				= Undefined;
	SearchProperties 			= Undefined;
	
	CommentsToObjectImport(NPP, Rulename, Undefined, ObjectType);
	
	RegisterRowTypeName = StrReplace(ObjectTypeAsString, "InformationRegisterRecordSet.", "InformationRegisterRecord.");
	RegisterName = StrReplace(ObjectTypeAsString, "InformationRegisterRecordSet.", "");
	
	RegisterSetRowType = Type(RegisterRowTypeName);
	
	PropertyStructure = Managers[RegisterSetRowType];
	ObjectTypeName   = PropertyStructure.TypeName;
	
	TypeInformation = MapOfDataTypesForImport()[RegisterSetRowType];
	
	Object          = Undefined;
		
	If Not IsBlankString(Rulename) Then
		
		Rule = Rules[Rulename];
		HasBeforeImportHandler = Rule.HasBeforeImportHandler;
		HasOnImportHandler    = Rule.HasOnImportHandler;
		HasAfterImportHandler  = Rule.HasAfterImportHandler;
		
	Else
		
		HasBeforeImportHandler = False;
		HasOnImportHandler    = False;
		HasAfterImportHandler  = False;
		
	EndIf;

    // global handler of the BeforeObjectImport event.
	
	If HasBeforeObjectImportGlobalHandler Then
		
		Cancel = False;
		
		Try
			
			If DebuggingImportHandlers Then
				
				ExecuteHandler_Conversion_BeforeObjectImport(ExchangeFile, Cancel, NPP, Source, Rulename, Rule,
																	  Generatenewnumberorcodeifnotspecified,ObjectTypeAsString,
																	  ObjectType, Donotreplaceobject, WriteMode, PostingMode);
				
			Else
				
				Execute(Conversion.BeforeObjectImport);
				
			EndIf;
			
		Except
			
			WriteInformationAboutOCRHandlerErrorImport(53, ErrorDescription(), Rulename, Source, 
			ObjectType, Undefined, NStr("en='BeforeObjectImport(Global)';ru='ПередЗагрузкойОбъекта (глобальный)'"));
			
		EndTry;
		
		If Cancel Then	//	Denial of the object import
			
			deIgnore(ExchangeFile, "Object");
			Return Undefined;
			
		EndIf;
		
	EndIf;
	
	
	// Event handler BeforeObjectImport.
	If HasBeforeImportHandler Then
		
		Cancel = False;
		
		Try
			
			If DebuggingImportHandlers Then
				
				ExecuteHandler_OCR_BeforeObjectImport(ExchangeFile, Cancel, NPP, Source, Rulename, Rule,
															  Generatenewnumberorcodeifnotspecified, ObjectTypeAsString,
															  ObjectType, Donotreplaceobject, WriteMode, PostingMode);
				
			Else
				
				Execute(Rule.BeforeImport);
				
			EndIf;
			
		Except
			
			WriteInformationAboutOCRHandlerErrorImport(19, ErrorDescription(), Rulename, Source, 
				ObjectType, Undefined, "BeforeObjectImport");
			
		EndTry;
		
		If Cancel Then // Denial of the object import
			
			deIgnore(ExchangeFile, "Object");
			Return Undefined;
			
		EndIf;
		
	EndIf;
	
	FilterReadMode = False;
	RecordReadingMode = False;
	
	RegisterFilter = Undefined;
	CurrentRecordSetRow = Undefined;
	ObjectParameters = Undefined;
	RecordSetParameters = Undefined;
	RecNo = -1;
	
	// Read what is written to the register.
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Filter" Then
			
			If ExchangeFile.NodeType <> XMLNodeTypeEndElement Then
					
				Object = InformationRegisters[RegisterName].CreateRecordSet();
				RegisterFilter = Object.Filter;
			
				FilterReadMode = True;
					
			EndIf;			
		
		ElsIf NodeName = "Property"
			OR NodeName = "ParameterValue" Then
			
			IsParameterForObject = (NodeName = "ParameterValue");
			
			Name                = deAttribute(ExchangeFile, StringType, "Name");
			DontReplaceProperty = deAttribute(ExchangeFile, BooleanType, "Donotreplace");
			OCRName             = deAttribute(ExchangeFile, StringType, "OCRName");
			
			// Read and set value property
			PropertyType = GetPropertyTypeByAdditionalInformation(TypeInformation, Name);
			PropertyNotFoundByRef = False;
			
			// You should always create
			Value = ReadProperty(PropertyType, IsEmptySet, PropertyNotFoundByRef, OCRName);
			
			If IsParameterForObject Then
				
				If FilterReadMode Then
					AddParameterIfNeeded(RecordSetParameters, Name, Value);
				Else
					// Expand object parameters collection.
					AddParameterIfNeeded(ObjectParameters, Name, Value);
					AddComplexParameterIfNeeded(RecordSetParameters, "Rows", RecNo, Name, Value);
				EndIf;
				
			Else
 				
				Try
					
					If FilterReadMode Then
						RegisterFilter[Name].Set(Value);						
					ElsIf RecordReadingMode Then
						CurrentRecordSetRow[Name] = Value;
					EndIf;
					
				Except
					
					LR = GetProtocolRecordStructure(26, ErrorDescription());
					LR.OCRName           = Rulename;
					LR.Source         = Source;
					LR.Object           = Object;
					LR.ObjectType       = ObjectType;
					LR.Property         = Name;
					LR.Value         = Value;
					LR.ValueType      = TypeOf(Value);
					ErrorMessageString = WriteInExecutionProtocol(26, LR, True);
					
					If Not ContinueOnError Then
						Raise ErrorMessageString;
					EndIf;
					
				EndTry;
				
			EndIf;
			
		ElsIf NodeName = "RecordSetRows" Then
			
			If ExchangeFile.NodeType <> XMLNodeTypeEndElement Then
				
				// OnObjectImport
				// event handler fires before reading the first record in set.
				If FilterReadMode = True
					AND HasOnImportHandler Then
					
					Try
						
						If DebuggingImportHandlers Then
							
							ExecuteHandler_OCR_OnImportObject(ExchangeFile, ObjectFound, Object, Donotreplaceobject, ObjectModified, Rule);
							
						Else
							
							Execute(Rule.OnImport);
							
						EndIf;
						
					Except
						
						WriteInformationAboutOCRHandlerErrorImport(20, ErrorDescription(), Rulename, Source, 
						ObjectType, Object, "OnImportObject");
						
					EndTry;
					
				EndIf;
				
				FilterReadMode = False;
				RecordReadingMode = True;
				
			EndIf;
			
		ElsIf NodeName = "Object" Then
			
			If ExchangeFile.NodeType <> XMLNodeTypeEndElement Then
			
				CurrentRecordSetRow = Object.Add();	
			    RecNo = RecNo + 1;
				
			EndIf;
			
		ElsIf NodeName = "RegisterRecordSet" AND ExchangeFile.NodeType = XMLNodeTypeEndElement Then
			
			Break;
						
		Else
			
			WriteInExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;
	
	// after import
	If HasAfterImportHandler Then
		
		Try
			
			If DebuggingImportHandlers Then
				
				ExecuteHandler_OCR_AftertObjectImport(ExchangeFile, Cancel, Ref, Object, ObjectParameters,
															 ObjectModified, ObjectTypeName, ObjectFound, Rule);
				
			Else
				
				Execute(Rule.AfterImport);
				
			EndIf;
			
		Except
			
			WriteInformationAboutOCRHandlerErrorImport(21, ErrorDescription(), Rulename, Source, 
				ObjectType, Object, "AftertObjectImport");
			
		EndTry;
		
	EndIf;
	
	If Object <> Undefined Then
		
		ItemReceive = DataItemReceive.Auto;
		SendBack = False;
		
		Object.AdditionalProperties.Insert("DataExchange", New Structure("DataAnalysis", Not DataImportToInformationBaseMode()));
		
		If ExchangeObjectPriority <> Enums.ExchangeObjectPriorities.PriorityOfObjectReceivedOnExchangeIsHigher Then
			StandardSubsystemsServer.OnReceiveDataFromSubordinate(Object, ItemReceive, SendBack, ExchangeNodeForDataImport);
		Else
			StandardSubsystemsServer.OnReceiveDataFromMaster(Object, ItemReceive, SendBack, ExchangeNodeForDataImport);
		EndIf;
		
		If ItemReceive = DataItemReceive.Ignore Then
			Return Undefined;
		EndIf;
		
		WriteObjectToIB(Object, ObjectType);
		
	EndIf;
	
	Return Object;
	
EndFunction

Procedure SupplementNotRecordedObjectsStack(NumberForStack, Object, KnownRef, ObjectType, TypeName, GenerateCodeAutomatically = False, ObjectParameters = Undefined)
	
	StackString = GlobalNotWrittenObjectStack[NumberForStack];
	If StackString <> Undefined Then
		Return;
	EndIf;
	
	GlobalNotWrittenObjectStack.Insert(NumberForStack, New Structure("Object, KnownRef, ObjectType, TypeName, GenerateCodeAutomatically, ObjectParameters", 
		Object, KnownRef, ObjectType, TypeName, GenerateCodeAutomatically, ObjectParameters));
	
EndProcedure

Procedure DeleteFromStackOfNotRecordedObjects(NPP, GNPP)
	
	NumberForStack = ?(NPP = 0, GNPP, NPP);
	GlobalNotWrittenObjectStack.Delete(NumberForStack);
	
EndProcedure

Procedure WriteNotRecordedObjects()
	
	For Each DataRow IN GlobalNotWrittenObjectStack Do
		
		// deferred object record
		Object = DataRow.Value.Object;
		RefNPP = DataRow.Key;
		
		If DataRow.Value.GenerateCodeAutomatically = True Then
			
			DoNumberCodeGenerationIfNeeded(True, Object,
				DataRow.Value.TypeName, True);
			
		EndIf;
		
		WriteObjectToIB(Object, DataRow.Value.ObjectType);
		
	EndDo;
	
	GlobalNotWrittenObjectStack.Clear();
	
EndProcedure

Procedure DoNumberCodeGenerationIfNeeded(Generatenewnumberorcodeifnotspecified, Object, ObjectTypeName, 
	DataExchangeMode)
	
	If Not Generatenewnumberorcodeifnotspecified
		OR Not DataExchangeMode Then
		
		// If number should not be generated or not in the data exchange mode, then do nothing... platform
		// will generate everything itself.
		Return;
	EndIf;
	
	// Look if quantity or number is filled by type of document.
	If ObjectTypeName = "Document"
		OR ObjectTypeName =  "BusinessProcess"
		OR ObjectTypeName = "Task" Then
		
		If Not ValueIsFilled(Object.Number) Then
			
			Object.SetNewNumber();
			
		EndIf;
		
	ElsIf ObjectTypeName = "Catalog"
		OR ObjectTypeName = "ChartOfCharacteristicTypes"
		OR ObjectTypeName = "ExchangePlan" Then
		
		If Not ValueIsFilled(Object.Code) Then
			
			Object.SetNewCode();
			
		EndIf;	
		
	EndIf;
	
EndProcedure

Function GetExchangeObjectPriority(ExchangeFile)
		
	PriorityString = deAttribute(ExchangeFile, StringType, "ExchangeObjectPriority");
	If IsBlankString(PriorityString) Then
		PriorityValue = Enums.ExchangeObjectPriorities.PriorityOfObjectReceivedOnExchangeIsHigher;
	ElsIf PriorityString = "above" Then
		PriorityValue = Enums.ExchangeObjectPriorities.PriorityOfObjectReceivedOnExchangeIsHigher;
	ElsIf PriorityString = "below" Then
		PriorityValue = Enums.ExchangeObjectPriorities.PriorityOfObjectReceivedOnExchangeIsLower;
	ElsIf PriorityString = "Matches" Then
		PriorityValue = Enums.ExchangeObjectPriorities.PriorityOfObjectReceivedOnExchangeIsTheSame;
	EndIf;
	
	Return PriorityValue;
	
EndFunction

// Reads another object from exchange file, executes import.
//
// Parameters:
//  No.
// 
Function ReadObject(UUIDString = "")

	NPP						= deAttribute(ExchangeFile, NumberType,  "NPP");
	GNPP					= deAttribute(ExchangeFile, NumberType,  "GSn");
	Source				= deAttribute(ExchangeFile, StringType, "Source");
	Rulename				= deAttribute(ExchangeFile, StringType, "Rulename");
	Donotreplaceobject 		= deAttribute(ExchangeFile, BooleanType, "Donotreplace");
	AutonumerationPrefix	= deAttribute(ExchangeFile, StringType, "AutonumerationPrefix");
	ExchangeObjectPriority  = GetExchangeObjectPriority(ExchangeFile);
	
	ObjectTypeAsString       = deAttribute(ExchangeFile, StringType, "Type");
	ObjectType 				= Type(ObjectTypeAsString);
	TypeInformation = MapOfDataTypesForImport()[ObjectType];
	
    
	CommentsToObjectImport(NPP, Rulename, Source, ObjectType, GNPP);
    	
	PropertyStructure = Managers[ObjectType];
	ObjectTypeName   = PropertyStructure.TypeName;


	If ObjectTypeName = "Document" Then
		
		WriteMode     = deAttribute(ExchangeFile, StringType, "WriteMode");
		PostingMode = deAttribute(ExchangeFile, StringType, "PostingMode");
		
	EndIf;
	
	Object          = Undefined;
	ObjectFound    = True;
	ObjectCreatedInCurrentInfobase = Undefined;
	
	SearchProperties  = New Map;
	SearchPropertiesDontReplace  = New Map;
	
	If Not IsBlankString(Rulename) Then
		
		Rule = Rules[Rulename];
		HasBeforeImportHandler = Rule.HasBeforeImportHandler;
		HasOnImportHandler    = Rule.HasOnImportHandler;
		HasAfterImportHandler  = Rule.HasAfterImportHandler;
		Generatenewnumberorcodeifnotspecified = Rule.Generatenewnumberorcodeifnotspecified;
		DontReplaceCreatedInTargetObject =  Rule.DontReplaceCreatedInTargetObject;
		
	Else
		
		HasBeforeImportHandler = False;
		HasOnImportHandler    = False;
		HasAfterImportHandler  = False;
		Generatenewnumberorcodeifnotspecified = False;
		DontReplaceCreatedInTargetObject = False;
		
	EndIf;


    // global handler of the BeforeObjectImport event.
	
	If HasBeforeObjectImportGlobalHandler Then
		
		Cancel = False;
		
		Try
			
			If DebuggingImportHandlers Then
				
				ExecuteHandler_Conversion_BeforeObjectImport(ExchangeFile, Cancel, NPP, Source, Rulename, Rule,
																	  Generatenewnumberorcodeifnotspecified,ObjectTypeAsString,
																	  ObjectType, Donotreplaceobject, WriteMode, PostingMode);
				
			Else
				
				Execute(Conversion.BeforeObjectImport);
				
			EndIf;
			
		Except
			
			WriteInformationAboutOCRHandlerErrorImport(53, ErrorDescription(), Rulename, Source, 
				ObjectType, Undefined, NStr("en='BeforeObjectImport(Global)';ru='ПередЗагрузкойОбъекта (глобальный)'"));				
							
		EndTry;
				
		If Cancel Then	//	Denial of the object import
			
			deIgnore(ExchangeFile, "Object");
			Return Undefined;
			
		EndIf;
		
	EndIf;
	
	
	// Event handler BeforeObjectImport.
	If HasBeforeImportHandler Then
		
		Cancel = False;
		
		Try
			
			If DebuggingImportHandlers Then
				
				ExecuteHandler_OCR_BeforeObjectImport(ExchangeFile, Cancel, NPP, Source, Rulename, Rule,
															  Generatenewnumberorcodeifnotspecified, ObjectTypeAsString,
															  ObjectType, Donotreplaceobject, WriteMode, PostingMode);
				
			Else
				
				Execute(Rule.BeforeImport);
				
			EndIf;
			
		Except
			
			WriteInformationAboutOCRHandlerErrorImport(19, ErrorDescription(), Rulename, Source, 
			ObjectType, Undefined, "BeforeObjectImport");				
			
		EndTry;
		
		If Cancel Then // Denial of the object import
			
			deIgnore(ExchangeFile, "Object");
			Return Undefined;
			
		EndIf;
		
	EndIf;

	ConstantOperatingMode = False;
	ConstantName = "";
	
	GlobalRefNPP = 0;
	RefNPP = 0;
	ObjectParameters = Undefined;
	WriteObject = True;
	
	// Check box determines whether object is found by search fields in the objects match mode or not;
	// if check box is set, then information about source and receiver match is added
	// to the match register.
	ObjectFoundBySearchFields = False;
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
				
		If NodeName = "Property"
			OR NodeName = "ParameterValue" Then
			
			IsParameterForObject = (NodeName = "ParameterValue");
			
			If Object = Undefined Then
				
				// Object was not found or not created - try to do it now.
				ObjectFound = False;
				
				// Event handler OnObjectImport.
				If HasOnImportHandler Then
					ObjectModified = True;
					// If there is a handler during the import, then object should be rewritten as there may be changes.
					Try
						
						If DebuggingImportHandlers Then
							
							ExecuteHandler_OCR_OnImportObject(ExchangeFile, ObjectFound, Object, Donotreplaceobject, ObjectModified, Rule);
							
						Else
							
							Execute(Rule.OnImport);
							
						EndIf;
						
					Except
						
						WriteInformationAboutOCRHandlerErrorImport(20, ErrorDescription(), Rulename, Source,
																		 ObjectType, Object, "OnImportObject");
						
					EndTry;							
					
				EndIf;
				
				// This way you could not create object in event - , create it separately.
				If Object = Undefined Then
					
					If ObjectTypeName = "Constants" Then
						
						Object = Undefined;
						ConstantOperatingMode = True;
												
					Else
						
						CreateNewObject(ObjectType, SearchProperties, Object, False, , RefNPP, GlobalRefNPP, Rule, ObjectParameters);
																	
					EndIf;
					
				EndIf;
				
			EndIf; 

			
			Name                = deAttribute(ExchangeFile, StringType, "Name");
			DontReplaceProperty = deAttribute(ExchangeFile, BooleanType, "Donotreplace");
			OCRName             = deAttribute(ExchangeFile, StringType, "OCRName");
			
			If ConstantOperatingMode Then
				
				Object = Constants[Name].CreateValueManager();	
				ConstantName = Name;
				Name = "Value";
				
			ElsIf Not IsParameterForObject
				AND ((ObjectFound AND DontReplaceProperty) 
				OR (Name = "IsFolder") 
				OR (Object[Name] = NULL)) Then
				
				// unknown property
				deIgnore(ExchangeFile, NodeName);
				Continue;
				
			EndIf; 

			
			// Read and set value property
			PropertyType = GetPropertyTypeByAdditionalInformation(TypeInformation, Name);
			Value    = ReadProperty(PropertyType,,, OCRName);
			
			If IsParameterForObject Then
				
				// Expand object parameters collection.
				AddParameterIfNeeded(ObjectParameters, Name, Value);
				
			Else
				
				Try
					
					Object[Name] = Value;
					
				Except
					
					LR = GetProtocolRecordStructure(26, ErrorDescription());
					LR.OCRName           = Rulename;
					LR.NPP              = NPP;
					LR.GNPP             = GNPP;
					LR.Source         = Source;
					LR.Object           = Object;
					LR.ObjectType       = ObjectType;
					LR.Property         = Name;
					LR.Value         = Value;
					LR.ValueType      = TypeOf(Value);
					ErrorMessageString = WriteInExecutionProtocol(26, LR, True);
					
					If Not ContinueOnError Then
						Raise ErrorMessageString;
					EndIf;
					
				EndTry;
				
			EndIf;
			
		ElsIf NodeName = "Ref" Then
			
			// Item reference - first, get object by reference and then set properties.
			InfobasesObjectsCompliance = Undefined;
			CreatedObject = Undefined;
			DontCreateObjectIfNotFound = Undefined;
			KnownUUIDRef = Undefined;
			DontReplaceCreatedInTargetObject = False;
			RecordObjectChangeAtSenderNode = False;
												
			Ref = FindObjectByRef(ObjectType,
										SearchProperties,
										SearchPropertiesDontReplace,
										ObjectFound,
										CreatedObject,
										DontCreateObjectIfNotFound,
										True,
										GlobalRefNPP,
										RefNPP,
										ObjectFoundBySearchFields,
										KnownUUIDRef,
										True,
										ObjectParameters,
										DontReplaceCreatedInTargetObject,
										ObjectCreatedInCurrentInfobase,
										RecordObjectChangeAtSenderNode,
										UUIDString,
										Rulename,
										InfobasesObjectsCompliance);
				
			If ObjectTypeName = "Enum" Then
				
				Object = Ref;
				
			Else
				
				Object = GetObjectByRefAndAddInformation(CreatedObject, Ref);
								
				If Object = Undefined Then
					
					deIgnore(ExchangeFile, "Object");
					Break;	
					
				EndIf;
				
				If ObjectFound AND Donotreplaceobject AND (NOT HasOnImportHandler) Then
					
					deIgnore(ExchangeFile, "Object");
					Break;
					
				EndIf;
				
				If Ref = Undefined Then
					
					NumberForStack = ?(NPP = 0, GNPP, NPP);
					SupplementNotRecordedObjectsStack(NumberForStack, CreatedObject, KnownUUIDRef, ObjectType, 
						ObjectTypeName, Rule.Generatenewnumberorcodeifnotspecified, ObjectParameters);
					
				EndIf;
				
			EndIf;
			
			// Event handler OnObjectImport.
			If HasOnImportHandler Then
				
				Try
					
					If DebuggingImportHandlers Then
						
						ExecuteHandler_OCR_OnImportObject(ExchangeFile, ObjectFound, Object, Donotreplaceobject, ObjectModified, Rule);
						
					Else
						
						Execute(Rule.OnImport);
						
					EndIf;
					
				Except
					
					WriteInformationAboutOCRHandlerErrorImport(20, ErrorDescription(), Rulename, Source,
							ObjectType, Object, "OnImportObject");
					//
				EndTry;
				
				If ObjectFound AND Donotreplaceobject Then
					
					deIgnore(ExchangeFile, "Object");
					Break;
					
				EndIf;
				
			EndIf;
			
			If RecordObjectChangeAtSenderNode = True Then
				Object.AdditionalProperties.Insert("RecordObjectChangeAtSenderNode");
			EndIf;
			
			Object.AdditionalProperties.Insert("InfobasesObjectsCompliance", InfobasesObjectsCompliance);
			
		ElsIf NodeName = "TabularSection"
			  OR NodeName = "RecordSet" Then
			//
			
			If DataImportToValueTableMode()
				AND ObjectTypeName <> "ExchangePlan" Then
				deIgnore(ExchangeFile, NodeName);
				Continue;
			EndIf;
			
			If Object = Undefined Then
				
				ObjectFound = False;
				
				// Event handler OnObjectImport.
				
				If HasOnImportHandler Then
					
					Try
						
						If DebuggingImportHandlers Then
							
							ExecuteHandler_OCR_OnImportObject(ExchangeFile, ObjectFound, Object, Donotreplaceobject, ObjectModified, Rule);
							
						Else
							
							Execute(Rule.OnImport);
							
						EndIf;
						
					Except
						
						WriteInformationAboutOCRHandlerErrorImport(20, ErrorDescription(), Rulename, Source, 
							ObjectType, Object, "OnImportObject");							
						
					EndTry;
						
				EndIf;
				 
			EndIf;
			
			Name                = deAttribute(ExchangeFile, StringType, "Name");
			DontReplaceProperty = deAttribute(ExchangeFile, BooleanType, "Donotreplace");
			Donotclear          = deAttribute(ExchangeFile, BooleanType, "Donotclear");

			If ObjectFound AND DontReplaceProperty Then
				
				deIgnore(ExchangeFile, NodeName);
				Continue;
				
			EndIf;
			
			If Object = Undefined Then
					
				CreateNewObject(ObjectType, SearchProperties, Object, False, , RefNPP, GlobalRefNPP, Rule, ObjectParameters);
									
			EndIf;
						
			If NodeName = "TabularSection" Then
				
				// Import items from tabular section.
				ImportTabularSection(Object, Name, TypeInformation, ObjectParameters, Rule);
				
			ElsIf NodeName = "RecordSet" Then
				
				// import movements
				ImportRegisterRecords(Object, Name, Not Donotclear, TypeInformation, ObjectParameters, Rule);
				
			EndIf;
			
		ElsIf (NodeName = "Object") AND (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
			
			Cancel = False;
			
			// Global handler of the AfterObjectImport event.
			If HasAftertObjectImportGlobalHandler Then
				
				ObjectModified = True;
				
				Try
					
					If DebuggingImportHandlers Then
						
						ExecuteHandler_Conversion_AftertObjectImport(ExchangeFile, Cancel, Ref, Object, ObjectParameters,
																			 ObjectModified, ObjectTypeName, ObjectFound);
						
					Else
						
						Execute(Conversion.AftertObjectImport);
						
					EndIf;
					
				Except
					
					WriteInformationAboutOCRHandlerErrorImport(54, ErrorDescription(), Rulename, Source,
						ObjectType, Object, NStr("en='AftertObjectImport(Global)';ru='ПослеЗагрузкиОбъекта (глобальный)'"));
					
				EndTry;
				
			EndIf;
			
			// Event handler AfterObjectImport.
			If HasAfterImportHandler Then
				
				Try
					
					If DebuggingImportHandlers Then
						
						ExecuteHandler_OCR_AftertObjectImport(ExchangeFile, Cancel, Ref, Object, ObjectParameters,
																	 ObjectModified, ObjectTypeName, ObjectFound, Rule);
						
					Else
						
						Execute(Rule.AfterImport);
						
					EndIf;
					
				Except
					
					WriteInformationAboutOCRHandlerErrorImport(21, ErrorDescription(), Rulename, Source, 
						ObjectType, Object, "AftertObjectImport");				
					
				EndTry;
				
			EndIf;
			
			ItemReceive = DataItemReceive.Auto;
			SendBack = False;
			
			If ObjectTypeName <> "Enum" Then
				Object.AdditionalProperties.Insert("DataExchange", New Structure("DataAnalysis", Not DataImportToInformationBaseMode()));
			EndIf;
			
			If ExchangeObjectPriority <> Enums.ExchangeObjectPriorities.PriorityOfObjectReceivedOnExchangeIsHigher Then
				StandardSubsystemsServer.OnReceiveDataFromSubordinate(Object, ItemReceive, SendBack, ExchangeNodeForDataImport);
			Else
				StandardSubsystemsServer.OnReceiveDataFromMaster(Object, ItemReceive, SendBack, ExchangeNodeForDataImport);
			EndIf;
			
			If ItemReceive = DataItemReceive.Ignore Then
				Cancel = True;
			EndIf;
			
			If Cancel Then
				DeleteFromStackOfNotRecordedObjects(NPP, GNPP);
				Return Undefined;
			EndIf;
			
			If ObjectTypeName = "Document" Then
				
				If WriteMode = "Posting" Then
					
					WriteMode = DocumentWriteMode.Posting;
					
				ElsIf WriteMode = "UndoPosting" Then
					
					WriteMode = DocumentWriteMode.UndoPosting; 
					
				Else
					
					// Determine how to write document.
					If Object.Posted Then
						
						WriteMode = DocumentWriteMode.Posting;
						
					Else
						
						// Whether document can be posted or not.
						PostableDocument = (Object.Metadata().Posting = EnableDocumentPosting);
						
						If PostableDocument Then
							WriteMode = DocumentWriteMode.UndoPosting;
						Else
							WriteMode = DocumentWriteMode.Write;
						EndIf;
						
					EndIf;
					
				EndIf;
				
				PostingMode = ?(PostingMode = "RealTime", DocumentPostingMode.RealTime, DocumentPostingMode.Regular);
				
				// If you want to post document marked for deletion, then clear deletion mark...
				If Object.DeletionMark
					AND (WriteMode = DocumentWriteMode.Posting) Then
					
					Object.DeletionMark = False;
					
				EndIf;
				
				DoNumberCodeGenerationIfNeeded(Generatenewnumberorcodeifnotspecified, Object, 
				ObjectTypeName, True);
				
				If DataImportToInformationBaseMode() Then
					
					Try
						
						// Write document, separately write information about the need to post it or to cancel posting.
						
						// Documents that should just be written - write as they are.
						If WriteMode = DocumentWriteMode.Write Then
							
							// Disable objects registration mechanism during document posting cancelling.
							// Registration mechanism will be executed during
							// the deferred documents posting (optimization of the data import performance).
							Object.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
							
							WriteObjectToIB(Object, ObjectType, WriteObject, SendBack);
							
							If WriteObject
								AND Object <> Undefined
								AND Object.Ref <> Undefined Then
								
								ObjectsForPostponedRecording().Insert(Object.Ref, Object.AdditionalProperties);
								
							EndIf;
							
						ElsIf WriteMode = DocumentWriteMode.UndoPosting Then
							
							UndoObjectPostingInIB(Object, ObjectType, WriteObject);
							
						ElsIf WriteMode = DocumentWriteMode.Posting Then
							
							// Disable objects registration mechanism during document posting cancelling.
							// Registration mechanism will be executed during
							// the deferred documents posting (optimization of the data import performance).
							Object.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
							
							UndoObjectPostingInIB(Object, ObjectType, WriteObject);
							
							// If document is successfully written and
							// ref is created, then put document to queue for posting.
							If WriteObject
								AND Object <> Undefined
								AND Object.Ref <> Undefined Then
								
								TableRow = DocumentsForDelayedPosting().Add();
								TableRow.DocumentRef = Object.Ref;
								TableRow.DocumentDate  = Object.Date;
								
								AdditionalPropertiesForDeferredPosting().Insert(Object.Ref, Object.AdditionalProperties);
								
							EndIf;
							
						EndIf;
						
					Except
						
						ErrorDescriptionString = ErrorDescription();
						
						If WriteObject Then
							// Unable to execute required actions for document.
							WriteDocumentInSafeMode(Object, ObjectType);
						EndIf;
						
						LR                        = GetProtocolRecordStructure(25, ErrorDescriptionString);
						LR.OCRName                 = Rulename;
						
						If Not IsBlankString(Source) Then
							
							LR.Source           = Source;
							
						EndIf;
						
						LR.ObjectType             = ObjectType;
						LR.Object                 = String(Object);
						WriteInExecutionProtocol(25, LR);
						
						MessageString = NStr("en='An error occurred while writing document: %1 Error description: %2';ru='Ошибка при записи документа: %1. Описание ошибки: %2'");
						MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, String(Object), ErrorDescriptionString);
						
						// Object failed to be written in the normal mode - you should report it.
						Raise MessageString;
						
					EndTry;
					
					DeleteFromStackOfNotRecordedObjects(NPP, GNPP);
					
				EndIf;
				
			ElsIf ObjectTypeName <> "Enum" Then
				
				If ObjectTypeName = "InformationRegister" Then
					
					Periodical = PropertyStructure.Periodical;
					
					If Periodical Then
						
						If Not ValueIsFilled(Object.Period) Then
							SetAttributesCurrentDate(Object.Period);
						EndIf;
						
					EndIf;
					
				EndIf;
				
				DoNumberCodeGenerationIfNeeded(Generatenewnumberorcodeifnotspecified, Object,
				ObjectTypeName, True);
				
				If DataImportToInformationBaseMode() Then
					
					// Disable objects registration mechanism during document posting cancelling.
					// Registration mechanism will be executed during
					// the deferred documents posting (optimization of the data import performance).
					Object.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
					
					WriteObjectToIB(Object, ObjectType, WriteObject, SendBack);
					
					// If object is successfully written and
					// ref is created, then put object to queue for writing.
					If WriteObject
						AND Object <> Undefined
						AND Object.Ref <> Undefined Then
						
						ObjectsForPostponedRecording().Insert(Object.Ref, Object.AdditionalProperties);
						
					EndIf;
					
					If Not (ObjectTypeName = "InformationRegister"
						 OR ObjectTypeName = "Constants") Then
						
						DeleteFromStackOfNotRecordedObjects(NPP, GNPP);
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
			IsReferenceTypeObject = Not(ObjectTypeName = "InformationRegister"
										OR ObjectTypeName = "Constants");
			
			Break;
			
		ElsIf NodeName = "SequenceRecordSet" Then
			
			deIgnore(ExchangeFile);
			
		ElsIf NodeName = "Types" Then

			If Object = Undefined Then
				
				ObjectFound = False;
				Ref  = CreateNewObject(ObjectType, SearchProperties, Object, , , RefNPP, GlobalRefNPP, Rule, ObjectParameters);
								
			EndIf; 

			ObjectTypeDescription = ImportObjectTypes(ExchangeFile);

			If ObjectTypeDescription <> Undefined Then
				
				Object.ValueType = ObjectTypeDescription;
				
			EndIf; 
			
		Else
			
			WriteInExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;
	
	Return Object;

EndFunction

////////////////////////////////////////////////////////////////////////////////
// DATA EXPORT PROCEDURE BY EXCHANGE RULES

Function GetDocumentRecordSet(DocumentRef, SourceKind, RegisterName)
	
	If SourceKind = "AccumulationRegisterRecordSet" Then
		
		DocumentRegisterRecordSet = AccumulationRegisters[RegisterName].CreateRecordSet();
		
	ElsIf SourceKind = "InformationRegisterRecordSet" Then
		
		DocumentRegisterRecordSet = InformationRegisters[RegisterName].CreateRecordSet();
		
	ElsIf SourceKind = "AccountingRegisterRecordSet" Then
		
		DocumentRegisterRecordSet = AccountingRegisters[RegisterName].CreateRecordSet();
		
	ElsIf SourceKind = "CalculationRegisterRecordSet" Then	
		
		DocumentRegisterRecordSet = CalculationRegisters[RegisterName].CreateRecordSet();
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	DocumentRegisterRecordSet.Filter.Recorder.Set(DocumentRef.Ref);
	DocumentRegisterRecordSet.Read();
	
	Return DocumentRegisterRecordSet;
	
EndFunction

// Generates receiver object property nodes according to the specified properties conversion rules collection.
//
// Parameters:
//  Source		     - custom data source.
//  Receiver		     - receiver object xml-node.
//  IncomingData	     - custom helper data passed
//                         to rule for conversion execution.
//  OutgoingData      - custom helper data passed
//                         to property objects conversion rules.
//  OCR				     - ref to object conversion rule (parent of the properties conversion rules collection).
//  PGCR                 - ref to properties group conversion rule.
//  PropertyCollectionNode - properties collection xml-node.
// 
Procedure DumpGroupOfProperties(Source, Receiver, IncomingData, OutgoingData, OCR, PGCR, PropertyCollectionNode, 
	ExportRefOnly, TempFileList = Undefined, ExportRegisterRecordSetRow = False)

	
	ObjectsCollection = Undefined;
	Donotreplace        = PGCR.Donotreplace;
	Donotclear         = False;
	ExportGroupToFile = PGCR.ExportGroupToFile;
	
	// Handler BeforeDataExportProcessor

	If PGCR.HasBeforeProcessExportHandler Then
		
		Cancel = False;
		Try
			
			If DebuggingExportHandlers Then
				
				ExecuteHandler_PGCR_BeforeProcessExport(ExchangeFile, Source, Receiver, IncomingData, OutgoingData, OCR,
																 PGCR, Cancel, ObjectsCollection, Donotreplace, PropertyCollectionNode, Donotclear);
				
			Else
				
				Execute(PGCR.BeforeProcessExport);
				
			EndIf;
			
		Except
			
			LR = GetProtocolRecordStructure(48, ErrorDescription());
			LR.OCR                    = OCR.Name + "  (" + OCR.Description + ")";
			LR.PGCR                   = PGCR.Name + "  (" + PGCR.Description + ")";
			
			TypeDescription = New TypeDescription("String");
			SourceRow= TypeDescription.AdjustValue(Source);
			If Not IsBlankString(SourceRow) Then
				LR.Object = TypeDescription.AdjustValue(Source) + "  (" + TypeOf(Source) + ")";
			Else
				LR.Object = "(" + TypeOf(Source) + ")";
			EndIf;
			
			LR.Handler             = "BeforePropertyGroupExport";
			ErrorMessageString = WriteInExecutionProtocol(48, LR);
			
			If Not ContinueOnError Then
				Raise ErrorMessageString;
			EndIf;
			
		EndTry;
							
		If Cancel Then // Denial of the properties group data processor.
			
			Return;
			
		EndIf;
		
	EndIf;

	
    TargetKind = PGCR.TargetKind;
	SourceKind = PGCR.SourceKind;
	
	
    // Creating a node of subordinate object collection.
	PropertyNodeStructure = Undefined;
	ObjectCollectionNode = Undefined;
	MasterNodeName = "";
	
	If TargetKind = "TabularSection" Then
		
		MasterNodeName = "TabularSection";
		
		CreateObjectsForRecordingDataToXML(PropertyNodeStructure, ObjectCollectionNode, TRUE, PGCR.Receiver, MasterNodeName);
		
		If Donotreplace Then
			
			AddAttributeForRecordToXML(PropertyNodeStructure, ObjectCollectionNode, "Donotreplace", "true");
						
		EndIf;
		
		If Donotclear Then
			
			AddAttributeForRecordToXML(PropertyNodeStructure, ObjectCollectionNode, "Donotclear", "true");
						
		EndIf;
		
	ElsIf TargetKind = "SubordinateCatalog" Then
				
		
	ElsIf TargetKind = "SequenceRecordSet" Then
		
		MasterNodeName = "RecordSet";
		
		CreateObjectsForRecordingDataToXML(PropertyNodeStructure, ObjectCollectionNode, TRUE, PGCR.Receiver, MasterNodeName);
		
	ElsIf Find(TargetKind, "RegisterRecordSet") > 0 Then
		
		MasterNodeName = "RecordSet";
		
		CreateObjectsForRecordingDataToXML(PropertyNodeStructure, ObjectCollectionNode, TRUE, PGCR.Receiver, MasterNodeName);
		
		If Donotreplace Then
			
			AddAttributeForRecordToXML(PropertyNodeStructure, ObjectCollectionNode, "Donotreplace", "true");
						
		EndIf;
		
		If Donotclear Then
			
			AddAttributeForRecordToXML(PropertyNodeStructure, ObjectCollectionNode, "Donotclear", "true");
						
		EndIf;
		
	Else  // this is a simple grouping
		
		DumpProperties(Source, Receiver, IncomingData, OutgoingData, OCR, PGCR.GroupRules, 
			PropertyCollectionNode, , , True, False);
		
		If PGCR.HasAfterProcessExportHandler Then
			
			Try
				
				If DebuggingExportHandlers Then
					
					ExecuteHandler_PGCR_AfterProcessExport(ExchangeFile, Source, Receiver, IncomingData, OutgoingData,
																	OCR, PGCR, Cancel, PropertyCollectionNode, ObjectCollectionNode);
					
				Else
					
					Execute(PGCR.AfterProcessExport);
					
				EndIf;
				
			Except
				
				LR = GetProtocolRecordStructure(49, ErrorDescription());
				LR.OCR                    = OCR.Name + "  (" + OCR.Description + ")";
				LR.PGCR                   = PGCR.Name + "  (" + PGCR.Description + ")";
				
				TypeDescription = New TypeDescription("String");
				SourceRow= TypeDescription.AdjustValue(Source);
				If Not IsBlankString(SourceRow) Then
					LR.Object = TypeDescription.AdjustValue(Source) + "  (" + TypeOf(Source) + ")";
				Else
					LR.Object = "(" + TypeOf(Source) + ")";
				EndIf;
				
				LR.Handler             = "AfterProcessPropertyGroupExport";
				ErrorMessageString = WriteInExecutionProtocol(49, LR);
			
				If Not ContinueOnError Then
					Raise ErrorMessageString;
				EndIf;
				
			EndTry;
			
		EndIf;
		
		Return;
		
	EndIf;
	
	// Receive subordinate objects collection.
	
	If ObjectsCollection <> Undefined Then
		
		// Initialized collection in the BeforeDataProcessor handler.
		
	ElsIf PGCR.GetFromIncomingData Then
		
		Try
			
			ObjectsCollection = IncomingData[PGCR.Receiver];
			
			If TypeOf(ObjectsCollection) = Type("QueryResult") Then
				
				ObjectsCollection = ObjectsCollection.Unload();
				
			EndIf;
			
		Except
			
			LR = GetProtocolRecordStructure(66, ErrorDescription());
			LR.OCR  = OCR.Name + "  (" + OCR.Description + ")";
			LR.PGCR = PGCR.Name + "  (" + PGCR.Description + ")";
			
			Try
				LR.Object = String(Source) + "  (" + TypeOf(Source) + ")";
			Except
				LR.Object = "(" + TypeOf(Source) + ")";
			EndTry;
			
			ErrorMessageString = WriteInExecutionProtocol(66, LR);
			
			If Not ContinueOnError Then
				Raise ErrorMessageString;
			EndIf;
			
			Return;
		EndTry;
		
	ElsIf SourceKind = "TabularSection" Then
		
		ObjectsCollection = Source[PGCR.Source];
		
		If TypeOf(ObjectsCollection) = Type("QueryResult") Then
			
			ObjectsCollection = ObjectsCollection.Unload();
			
		EndIf;
		
	ElsIf SourceKind = "SubordinateCatalog" Then
		
	ElsIf Find(SourceKind, "RegisterRecordSet") > 0 Then
		
		ObjectsCollection = GetDocumentRecordSet(Source, SourceKind, PGCR.Source);
				
	ElsIf IsBlankString(PGCR.Source) Then
		
		ObjectsCollection = Source[PGCR.Receiver];
		
		If TypeOf(ObjectsCollection) = Type("QueryResult") Then
			
			ObjectsCollection = ObjectsCollection.Unload();
			
		EndIf;
		
	EndIf;

	ExportGroupToFile = ExportGroupToFile OR (ObjectsCollection.Count() > 1000);
	ExportGroupToFile = ExportGroupToFile AND Not ExportRegisterRecordSetRow;
	ExportGroupToFile = ExportGroupToFile AND Not IsExchangeOverExternalConnection();
	
	If ExportGroupToFile Then
		
		PGCR.XMLNodeRequiredOnExport = False;
		
		If TempFileList = Undefined Then
			TempFileList = New ValueList();
		EndIf;
		
		RecordFileName = GetTempFileName();
		TempFileList.Add(RecordFileName);		
		
		TempRecordFile = New TextWriter;
		Try
			
			TempRecordFile.Open(RecordFileName, TextEncoding.UTF8);
			
		Except
			
			ErrorMessageString = StringFunctionsClientServer.PlaceParametersIntoString(NStr("en='An error occurred while creating temporary file for the data import.
		|File name ""%1"".
		|Error
		|description: %2';ru='Ошибка при создании временного файла для выгрузки данных.
		|Имя файла ""%1"".
		|Описание
		|ошибки: %2'"),
				String(RecordFileName),
				DetailErrorDescription(ErrorInfo()));
				
			WriteInExecutionProtocol(ErrorMessageString);
			
		EndTry;
		
		InformationToWriteToFile = ObjectCollectionNode.Close();
		TempRecordFile.WriteLine(InformationToWriteToFile);
		
	EndIf;
	
	For Each CollectionObject IN ObjectsCollection Do
		
		// Handler BeforeExport
		If PGCR.HasBeforeExportHandler Then
			
			Cancel = False;
			
			Try
				
				If DebuggingExportHandlers Then
					
					ExecuteHandler_PGCR_BeforeExportProperty(ExchangeFile, Source, Receiver, IncomingData, OutgoingData, OCR,
																	PGCR, Cancel, CollectionObject, PropertyCollectionNode, ObjectCollectionNode);
					
				Else
					
					Execute(PGCR.BeforeExport);
					
				EndIf;
				
			Except
				
				ErrorMessageString = WriteInExecutionProtocol(50);
				If Not ContinueOnError Then
					Raise ErrorMessageString;
				EndIf;
				
				Break;
				
			EndTry;
			
			If Cancel Then // Denial of the subordinate object export.
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		// Handler OnExport
		
		If PGCR.XMLNodeRequiredOnExport OR ExportGroupToFile Then
			CollectionObjectNode = CreateNode("Record");
		Else
			ObjectCollectionNode.WriteStartElement("Record");
			CollectionObjectNode = ObjectCollectionNode;
		EndIf;
		
		StandardProcessing	= True;
		
		If PGCR.HasOnExportHandler Then
			
			Try
				
				If DebuggingExportHandlers Then
					
					ExecuteHandler_PGCR_OnExportProperty(ExchangeFile, Source, Receiver, IncomingData, OutgoingData, OCR,
																 PGCR, CollectionObject, ObjectCollectionNode, CollectionObjectNode,
																 PropertyCollectionNode, StandardProcessing);
					
				Else
					
					Execute(PGCR.OnExport);
					
				EndIf;
			
		Except
				
				ErrorMessageString = WriteInExecutionProtocol(51);
				If Not ContinueOnError Then
					Raise ErrorMessageString;
				EndIf;
				
				Break;
				
			EndTry;
			
		EndIf;
		
		// Export collection object properties.
		If StandardProcessing Then
			
			If PGCR.GroupRules.Count() > 0 Then
				
				DumpProperties(Source, Receiver, IncomingData, OutgoingData, OCR, PGCR.GroupRules, 
					CollectionObjectNode, CollectionObject, , True, False);
				
			EndIf;
			
		EndIf;
		
		// Handler AfterExport
		If PGCR.HasAfterExportHandler Then
			
			Cancel = False;
			
			Try
				
				If DebuggingExportHandlers Then
					
					ExecuteHandler_PGCR_AfterExportProperty(ExchangeFile, Source, Receiver, IncomingData, OutgoingData,
																   OCR, PGCR, Cancel, CollectionObject, ObjectCollectionNode,
																   PropertyCollectionNode, CollectionObjectNode);
					
				Else
					
					Execute(PGCR.AfterExport);
					
				EndIf;
				
			Except
				
				ErrorMessageString = WriteInExecutionProtocol(52);
				If Not ContinueOnError Then
					Raise ErrorMessageString;
				EndIf;
				
				Break;
				
			EndTry;
			
		If Cancel Then // Denial of the subordinate object export.
			
			Continue;
			
		EndIf;
			
		EndIf;
		
		If PGCR.XMLNodeRequiredOnExport Then
			AddSubordinate(ObjectCollectionNode, CollectionObjectNode);
		EndIf;
		
		// Fill in file with node objects.
		If ExportGroupToFile Then
			
			CollectionObjectNode.WriteEndElement();
			InformationToWriteToFile = CollectionObjectNode.Close();
			TempRecordFile.WriteLine(InformationToWriteToFile);
			
		Else
			
			If Not PGCR.XMLNodeRequiredOnExport Then
				
				ObjectCollectionNode.WriteEndElement();
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// Handler AfterDataExportProcessor
	If PGCR.HasAfterProcessExportHandler Then
		
		Cancel = False;
		
		Try
			
			If DebuggingExportHandlers Then
				
				ExecuteHandler_PGCR_AfterProcessExport(ExchangeFile, Source, Receiver, IncomingData, OutgoingData,
																OCR, PGCR, Cancel, PropertyCollectionNode, ObjectCollectionNode);
				
			Else
				
				Execute(PGCR.AfterProcessExport);
				
			EndIf;
			
		Except
			
			LR = GetProtocolRecordStructure(49, ErrorDescription());
			LR.OCR                    = OCR.Name + "  (" + OCR.Description + ")";
			LR.PGCR                   = PGCR.Name + "  (" + PGCR.Description + ")";
			
			TypeDescription = New TypeDescription("String");
			SourceRow= TypeDescription.AdjustValue(Source);
			If Not IsBlankString(SourceRow) Then
				LR.Object = TypeDescription.AdjustValue(Source) + "  (" + TypeOf(Source) + ")";
			Else
				LR.Object = "(" + TypeOf(Source) + ")";
			EndIf;
			
			LR.Handler             = "AfterProcessPropertyGroupExport";
			ErrorMessageString = WriteInExecutionProtocol(49, LR);
		
			If Not ContinueOnError Then
				Raise ErrorMessageString;
			EndIf;
			
		EndTry;
		
		If Cancel Then // Denial of writing the subordinate objects.
			
			Return;
			
		EndIf;
		
	EndIf;
	
	If ExportGroupToFile Then
		TempRecordFile.WriteLine("</" + MasterNodeName + ">"); // close node
		TempRecordFile.Close(); // close file clearly
	Else
		WriteDataIntoHeadNode(PropertyCollectionNode, PropertyNodeStructure, ObjectCollectionNode);
	EndIf;
	
EndProcedure

Procedure GetPropertyValue(Value, CollectionObject, OCR, PCR, IncomingData, Source, DataSelection = Undefined)
	
	If Value <> Undefined Then
		Return;
	EndIf;
	
	If PCR.GetFromIncomingData Then
			
		ObjectForReceivingData = IncomingData;
		
		If Not IsBlankString(PCR.Receiver) Then
		
			PropertyName = PCR.Receiver;
			
		Else
			
			PropertyName = PCR.ParameterForTransferName;
			
		EndIf;
		
		ErrorCode = ?(CollectionObject <> Undefined, 67, 68);
	
	ElsIf CollectionObject <> Undefined Then
		
		ObjectForReceivingData = CollectionObject;
		
		If Not IsBlankString(PCR.Source) Then
			
			PropertyName = PCR.Source;
			ErrorCode = 16;
						
		Else
			
			PropertyName = PCR.Receiver;
			ErrorCode = 17;
            							
		EndIf;
		
	ElsIf DataSelection <> Undefined Then
		
		ObjectForReceivingData = DataSelection;	
		
		If Not IsBlankString(PCR.Source) Then
		
			PropertyName = PCR.Source;
			ErrorCode = 13;
			
		Else
			
			Return;
			
		EndIf;
						
	Else
		
		ObjectForReceivingData = Source;
		
		If Not IsBlankString(PCR.Source) Then
		
			PropertyName = PCR.Source;
			ErrorCode = 13;
		
		Else
			
			PropertyName = PCR.Receiver;
			ErrorCode = 14;
		
		EndIf;
			
	EndIf;
	
	
	Try
					
		Value = ObjectForReceivingData[PropertyName];
					
	Except
		
		If ErrorCode <> 14 Then
			WriteInformationAboutErrorPCRHandlers(ErrorCode, ErrorDescription(), OCR, PCR, Source, "");
		EndIf;
																	
	EndTry;					
			
EndProcedure

Procedure DumpItemPropertyType(Propirtiesnode, PropertyType)
	
	SetAttribute(Propirtiesnode, "Type", PropertyType);	
	
EndProcedure

Procedure _ExportExtraDimension(Source, Receiver, IncomingData, OutgoingData, OCR, PCR, 
	PropertyCollectionNode = Undefined, CollectionObject = Undefined, Val ExportRefOnly = False)
	
	// Variable-stubs to support debugging mechanism of events handlers code.
    Var ReceiverType, Empty, Expression, Donotreplace, OCRProperties, Propirtiesnode;
	
	// Initialize value
	Value = Undefined;
	OCRName = "";
	OCRNameextdimensiontype = "";
	
	// Handler BeforeExport
	If PCR.HasBeforeExportHandler Then
		
		Cancel = False;
		
		Try
			
			ExportObject = Not ExportRefOnly;
			
			If DebuggingExportHandlers Then
				
				ExecuteHandler_PCR_BeforeExportProperty(ExchangeFile, Source, Receiver, IncomingData, OutgoingData,
															   PCR, OCR, CollectionObject, Cancel, Value, ReceiverType, OCRName,
															   OCRNameextdimensiontype, Empty, Expression, PropertyCollectionNode, Donotreplace,
															   ExportObject);
				
			Else
				
				Execute(PCR.BeforeExport);
				
			EndIf;
			
			ExportRefOnly = Not ExportObject;
			
		Except
			
			WriteInformationAboutErrorPCRHandlers(55, ErrorDescription(), OCR, PCR, Source, 
				"BeforeExportProperty", Value);
			
		EndTry;
		
		If Cancel Then // Denial of the export
			
			Return;
			
		EndIf;
		
	EndIf;
	
	GetPropertyValue(Value, CollectionObject, OCR, PCR, IncomingData, Source);
	
	If PCR.CastToLength <> 0 Then
				
		RunValueCastToLength(Value, PCR);
						
	EndIf;
		
	For Each KeyAndValue IN Value Do
		
		ExtDimensionType = KeyAndValue.Key;
		ExtDimension = KeyAndValue.Value;
		OCRName = "";
		
		// Handler OnExport
		If PCR.HasOnExportHandler Then
			
			Cancel = False;
			
			Try
				
				ExportObject = Not ExportRefOnly;
				
				If DebuggingExportHandlers Then
					
					ExecuteHandler_PCR_OnExportProperty(ExchangeFile, Source, Receiver, IncomingData, OutgoingData,
																PCR, OCR, CollectionObject, Cancel, Value, KeyAndValue, ExtDimensionType,
																ExtDimension, Empty, OCRName, OCRProperties,Propirtiesnode, PropertyCollectionNode,
																OCRNameextdimensiontype, ExportObject);
					
				Else
					
					Execute(PCR.OnExport);
					
				EndIf;
				
				ExportRefOnly = Not ExportObject;
				
			Except
				
				WriteInformationAboutErrorPCRHandlers(56, ErrorDescription(), OCR, PCR, Source, 
					"OnExportProperty", Value);
				
			EndTry;
			
			If Cancel Then // Denial of the extra dimension export
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		If ExtDimension = Undefined
			OR FindRule(ExtDimension, OCRName) = Undefined Then
			
			Continue;
			
		EndIf;
			
		Nodeextdimension = CreateNode(PCR.Receiver);
			
		// Key
		Propirtiesnode = CreateNode("Property");
			
		If OCRNameextdimensiontype = "" Then
				
			OCRKey = FindRule(ExtDimensionType);
				
		Else
				
			OCRKey = FindRule(, OCRNameextdimensiontype);
				
		EndIf;
			
		SetAttribute(Propirtiesnode, "Name", "Key");
		DumpItemPropertyType(Propirtiesnode, OCRKey.Receiver);
		
		Referencenode = DumpByRule(ExtDimensionType,, OutgoingData,, OCRNameextdimensiontype,, TRUE, OCRKey, , , , , False);
			
		If Referencenode <> Undefined Then
				
			AddSubordinate(Propirtiesnode, Referencenode);
				
		EndIf;
			
		AddSubordinate(Nodeextdimension, Propirtiesnode);
		
		
		
		// Value
		Propirtiesnode = CreateNode("Property");
			
		OCRValue = FindRule(ExtDimension, OCRName);
		
		ReceiverType = OCRValue.Receiver;
		
		IsNULL = False;
		Empty = deBlank(ExtDimension, IsNULL);
		
		If Empty Then
			
			If IsNULL 
				Or Value = Undefined Then
				
				Continue;
				
			EndIf;
			
			If IsBlankString(ReceiverType) Then
				
				ReceiverType = DefineDataTypeForReceiver(ExtDimension);
								
			EndIf;			
			
			SetAttribute(Propirtiesnode, "Name", "Value");
			
			If Not IsBlankString(ReceiverType) Then
				SetAttribute(Propirtiesnode, "Type", ReceiverType);
			EndIf;
							
			// If the type is a multiple one, then it may be an empty reference and you should export it specifying its type.
			deWriteItem(Propirtiesnode, "Empty");
			AddSubordinate(Nodeextdimension, Propirtiesnode);
			
		Else
			
			IsRuleWithGlobalExport = False;
			Referencenode = DumpByRule(ExtDimension,, OutgoingData, , OCRName, , TRUE, OCRValue, , , , , False, IsRuleWithGlobalExport);
			
			SetAttribute(Propirtiesnode, "Name", "Value");
			DumpItemPropertyType(Propirtiesnode, ReceiverType);
						
				
			RefNodeType = TypeOf(Referencenode);
				
			If Referencenode = Undefined Then
					
				Continue;
					
			EndIf;
							
			AddPropertiesForDump(Referencenode, RefNodeType, Propirtiesnode, IsRuleWithGlobalExport);
			
			AddSubordinate(Nodeextdimension, Propirtiesnode);
			
		EndIf;
		
		// Handler AfterExport
		If PCR.HasAfterExportHandler Then
			
			Cancel = False;
			
			Try
				
				If DebuggingExportHandlers Then
					
					ExecuteHandler_PCR_AfterExportProperty(ExchangeFile, Source, Receiver, IncomingData, OutgoingData,
																  PCR, OCR, CollectionObject, Cancel, Value, KeyAndValue, ExtDimensionType,
																  ExtDimension, OCRName, OCRNameextdimensiontype, OCRProperties, Propirtiesnode,
																  Referencenode, PropertyCollectionNode, Nodeextdimension);
					
				Else
					
					Execute(PCR.AfterExport);
					
				EndIf;
				
			Except
				
				WriteInformationAboutErrorPCRHandlers(57, ErrorDescription(), OCR, PCR, Source, 
				"AfterExportProperty", Value);
				
			EndTry;
			
			If Cancel Then // Denial of the export
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		AddSubordinate(PropertyCollectionNode, Nodeextdimension);
		
	EndDo;
	
EndProcedure

Procedure AddPropertiesForDump(Referencenode, RefNodeType, Propirtiesnode, IsRuleWithGlobalExport)
	
	If RefNodeType = StringType Then
				
		If Find(Referencenode, "<Ref") > 0 Then
					
			Propirtiesnode.WriteRaw(Referencenode);
					
		Else
			
			deWriteItem(Propirtiesnode, "Value", Referencenode);
					
		EndIf;
				
	ElsIf RefNodeType = NumberType Then
		
		If IsRuleWithGlobalExport Then
		
			deWriteItem(Propirtiesnode, "GSn", Referencenode);
			
		Else     		
			
			deWriteItem(Propirtiesnode, "NPP", Referencenode);
			
		EndIf;
				
	Else
				
		AddSubordinate(Propirtiesnode, Referencenode);
				
	EndIf;
	
EndProcedure

Procedure DefineOpportunityOfValueAssign(Value, ValueType, ReceiverType, PropertySet, TypeRequired)
	
	PropertySet = True;
		
	If ValueType = StringType Then
				
		If ReceiverType = "String"  Then
		ElsIf ReceiverType = "Number"  Then
					
			Value = Number(Value);
					
		ElsIf ReceiverType = "Boolean"  Then
					
			Value = Boolean(Value);
					
		ElsIf ReceiverType = "Date"  Then
					
			Value = Date(Value);
					
		ElsIf ReceiverType = "ValueStorage"  Then
					
			Value = New ValueStorage(Value);
					
		ElsIf ReceiverType = "UUID" Then
					
			Value = New UUID(Value);
					
		ElsIf IsBlankString(ReceiverType) Then
					
			ReceiverType = "String";
			TypeRequired = True;
			
		EndIf;
								
	ElsIf ValueType = NumberType Then
				
		If ReceiverType = "Number"
			OR ReceiverType = "String" Then
		ElsIf ReceiverType = "Boolean"  Then
					
			Value = Boolean(Value);
					
		ElsIf IsBlankString(ReceiverType) Then
					
			ReceiverType = "Number";
			TypeRequired = True;
			
		Else
			
			PropertySet = False;
					
		EndIf;
								
	ElsIf ValueType = DateType Then
				
		If ReceiverType = "Date"  Then
		ElsIf ReceiverType = "String"  Then
					
			Value = Left(String(Value), 10);
					
		ElsIf IsBlankString(ReceiverType) Then
					
			ReceiverType = "Date";
			TypeRequired = True;
			
		Else
			
			PropertySet = False;
					
		EndIf;				
						
	ElsIf ValueType = BooleanType Then
				
		If ReceiverType = "Boolean"  Then
		ElsIf ReceiverType = "Number"  Then
					
			Value = Number(Value);
					
		ElsIf IsBlankString(ReceiverType) Then
					
			ReceiverType = "Boolean";
			TypeRequired = True;
			
		Else
			
			PropertySet = False;
					
		EndIf;				
						
	ElsIf ValueType = ValueStorageType Then
				
		If IsBlankString(ReceiverType) Then
					
			ReceiverType = "ValueStorage";
			TypeRequired = True;
					
		ElsIf ReceiverType <> "ValueStorage"  Then
					
			PropertySet = False;
					
		EndIf;				
						
	ElsIf ValueType = UUIDType Then
				
		If ReceiverType = "UUID" Then
		ElsIf ReceiverType = "String" Then
			
			Value = String(Value);
			
		ElsIf IsBlankString(ReceiverType) Then
			
			ReceiverType = "UUID";
			TypeRequired = True;
			
		Else
			
			PropertySet = False;
					
		EndIf;				
						
	ElsIf ValueType = AccumulationRecordTypeType Then
				
		Value = String(Value);		
		
	Else	
		
		PropertySet = False;
		
	EndIf;	
	
EndProcedure

Function DefineDataTypeForReceiver(Value)
	
	ReceiverType = deValueTypeAsString(Value);
	
	// Whether there is OCR with the ReceiverType
	// receiver type if there is no rule - then "" if there is , , then keep what you found.
	TableRow = ConversionRulesTable.Find(ReceiverType, "Receiver");
	
	If TableRow = Undefined Then
		
		If Not (ReceiverType = "String"
			OR ReceiverType = "Number"
			OR ReceiverType = "Date"
			OR ReceiverType = "Boolean"
			OR ReceiverType = "ValueStorage") Then
			
			ReceiverType = "";
		EndIf;
		
	EndIf;
	
	Return ReceiverType;
	
EndFunction

Procedure RunValueCastToLength(Value, PCR)
	
	Value = CastNumberToLength(String(Value), PCR.CastToLength);
		
EndProcedure

Procedure ExecuteStructureRecordToXML(DataStructure, PropertyCollectionNode, IsOrdinaryProperty = True)
	
	PropertyCollectionNode.WriteStartElement(?(IsOrdinaryProperty, "Property", "ParameterValue"));
	
	For Each CollectionItem IN DataStructure Do
		
		If CollectionItem.Key = "Expression"
			OR CollectionItem.Key = "Value"
			OR CollectionItem.Key = "NPP"
			OR CollectionItem.Key = "GSn" Then
			
			deWriteItem(PropertyCollectionNode, CollectionItem.Key, CollectionItem.Value);
			
		ElsIf CollectionItem.Key = "Ref" Then
			
			PropertyCollectionNode.WriteRaw(CollectionItem.Value);
			
		Else
			
			SetAttribute(PropertyCollectionNode, CollectionItem.Key, CollectionItem.Value);
			
		EndIf;
		
	EndDo;
	
	PropertyCollectionNode.WriteEndElement();		
	
EndProcedure

Procedure CreateComplexInformationForRecordingToXML(DataStructure, Propirtiesnode, XMLNodeRequired, TargetName, ParameterName)
	
	If IsBlankString(ParameterName) Then
		
		CreateObjectsForRecordingDataToXML(DataStructure, Propirtiesnode, XMLNodeRequired, TargetName, "Property");
		
	Else
		
		CreateObjectsForRecordingDataToXML(DataStructure, Propirtiesnode, XMLNodeRequired, ParameterName, "ParameterValue");
		
	EndIf;
	
EndProcedure

Procedure CreateObjectsForRecordingDataToXML(DataStructure, Propirtiesnode, XMLNodeRequired, NodeName, XMLNodeDescription = "Property")
	
	If XMLNodeRequired Then
		
		Propirtiesnode = CreateNode(XMLNodeDescription);
		SetAttribute(Propirtiesnode, "Name", NodeName);
		
	Else
		
		DataStructure = New Structure("Name", NodeName);
		
	EndIf;		
	
EndProcedure

Procedure AddAttributeForRecordToXML(PropertyNodeStructure, Propirtiesnode, AttributeName, AttributeValue)
	
	If PropertyNodeStructure <> Undefined Then
		PropertyNodeStructure.Insert(AttributeName, AttributeValue);
	Else
		SetAttribute(Propirtiesnode, AttributeName, AttributeValue);
	EndIf;
	
EndProcedure

Procedure AddValueForRecordToXML(PropertyNodeStructure, Propirtiesnode, AttributeName, AttributeValue)
	
	If PropertyNodeStructure <> Undefined Then
		PropertyNodeStructure.Insert(AttributeName, AttributeValue);
	Else
		deWriteItem(Propirtiesnode, AttributeName, AttributeValue);
	EndIf;
	
EndProcedure

Procedure AddArbitraryDataForRecordToXML(PropertyNodeStructure, Propirtiesnode, AttributeName, AttributeValue)
	
	If PropertyNodeStructure <> Undefined Then
		PropertyNodeStructure.Insert(AttributeName, AttributeValue);
	Else
		Propirtiesnode.WriteRaw(AttributeValue);
	EndIf;
	
EndProcedure

Procedure WriteDataIntoHeadNode(PropertyCollectionNode, PropertyNodeStructure, Propirtiesnode, IsOrdinaryProperty = True)
	
	If PropertyNodeStructure <> Undefined Then
		ExecuteStructureRecordToXML(PropertyNodeStructure, PropertyCollectionNode, IsOrdinaryProperty);
	Else
		AddSubordinate(PropertyCollectionNode, Propirtiesnode);
	EndIf;
	
EndProcedure


// Generates receiver object property nodes according to the specified properties conversion rules collection.
//
// Parameters:
//  Source		     - custom data source.
//  Receiver		     - receiver object xml-node.
//  IncomingData	     - custom helper data passed
//                         to rule for conversion execution.
//  OutgoingData      - custom helper data passed
//                         to property objects conversion rules.
//  OCR				     - ref to object conversion rule (parent of the properties conversion rules collection).
//  PCRCollection         - properties conversion rules collection.
//  PropertyCollectionNode - properties collection xml-node.
//  CollectionObject      - if it is specified, then collection object properties are exported, otherwise, Source properties are exported.
//  PredefinedItemName - if it is specified, then predefined item name is written.
// 
Procedure DumpProperties(Source, 
							Receiver, 
							IncomingData, 
							OutgoingData, 
							OCR, 
							PCRCollection, 
							PropertyCollectionNode = Undefined, 
							CollectionObject = Undefined, 
							PredefinedItemName = Undefined, 
							Val OCRExportRefOnly = True, 
							Val IsRefExport = False, 
							Val ExportingObject = False, 
							RefSearchKey = "", 
							DontUseRulesWithGlobalExportAndDontRememberExported = False,
							RefsValueInAnotherInfobase = "",
							TempFileList = Undefined, 
							ExportRegisterRecordSetRow = False)
							
	// Variable-stubs to support debugging mechanism of events handlers code.
	Var KeyAndValue, ExtDimensionType, ExtDimension, OCRNameextdimensiontype, Nodeextdimension;

							
	If PropertyCollectionNode = Undefined Then
		
		PropertyCollectionNode = Receiver;
		
	EndIf;
	
	PropertySelection = Undefined;
	
	If IsRefExport Then
				
		// Export a name of the predefined one if it is specified.
		If PredefinedItemName <> Undefined Then
			
			PropertyCollectionNode.WriteStartElement("Property");
			SetAttribute(PropertyCollectionNode, "Name", "{PredefinedItemName}");
			deWriteItem(PropertyCollectionNode, "Value", PredefinedItemName);
			PropertyCollectionNode.WriteEndElement();
			
		EndIf;
		
	EndIf;
	
	For Each PCR IN PCRCollection Do
		
		ExportRefOnly = OCRExportRefOnly;
		
		If PCR.SimplifiedPropertyExport Then
			
			
			 //	Create property node
			PropertyCollectionNode.WriteStartElement("Property");
			SetAttribute(PropertyCollectionNode, "Name", PCR.Receiver);
			
			If Not IsBlankString(PCR.ReceiverType) Then
				
				SetAttribute(PropertyCollectionNode, "Type", PCR.ReceiverType);
				
			EndIf;
			
			If PCR.Donotreplace Then
				
				SetAttribute(PropertyCollectionNode, "Donotreplace",	"true");
				
			EndIf;
			
			If PCR.SearchByEqualDate  Then
				
				SetAttribute(PropertyCollectionNode, "SearchByEqualDate", "true");
				
			EndIf;
			
			Value = Undefined;
			GetPropertyValue(Value, CollectionObject, OCR, PCR, IncomingData, Source, PropertySelection);
			
			If PCR.CastToLength <> 0 Then
				
				RunValueCastToLength(Value, PCR);
								
			EndIf;
			
			IsNULL = False;
			Empty = deBlank(Value, IsNULL);
						
			If Empty Then
				
				PropertyCollectionNode.WriteEndElement();
				Continue;
				
			EndIf;
			
			deWriteItem(PropertyCollectionNode, 	"Value", Value);
			
			PropertyCollectionNode.WriteEndElement();
			Continue;					
					
		ElsIf PCR.TargetKind = "AccountExtDimensionTypes" Then
			
			_ExportExtraDimension(Source, Receiver, IncomingData, OutgoingData, OCR, 
				PCR, PropertyCollectionNode, CollectionObject, ExportRefOnly);
			
			Continue;
			
		ElsIf PCR.Name = "{UUID}" Then
			
			SourceRef = DefineRefByObjectOrRef(Source, ExportingObject);
			
			UUID = SourceRef.UUID();
			
			PropertyCollectionNode.WriteStartElement("Property");
			SetAttribute(PropertyCollectionNode, "Name", "{UUID}");
			SetAttribute(PropertyCollectionNode, "Type", "String");
			SetAttribute(PropertyCollectionNode, "SourceType", OCR.SourceType);
			SetAttribute(PropertyCollectionNode, "ReceiverType", OCR.ReceiverType);
			deWriteItem(PropertyCollectionNode, "Value", UUID);
			PropertyCollectionNode.WriteEndElement();
			
			Continue;
			
		ElsIf PCR.IsFolder Then
			
			DumpGroupOfProperties(
				Source, Receiver, IncomingData, OutgoingData, OCR, PCR, PropertyCollectionNode, 
				ExportRefOnly, TempFileList, ExportRegisterRecordSetRow);
			
			Continue;
			
		EndIf;
		
		//	Initialize value that will be converted.
		Value 	 = Undefined;
		OCRName		 = PCR.ConversionRule;
		Donotreplace   = PCR.Donotreplace;
		
		Empty		 = False;
		Expression	 = Undefined;
		ReceiverType = PCR.ReceiverType;

		IsNULL      = False;
		
		// Handler BeforeExport
		If PCR.HasBeforeExportHandler Then
			
			Cancel = False;
			
			Try
				
				ExportObject = Not ExportRefOnly;
				
				If DebuggingExportHandlers Then
					
					ExecuteHandler_PCR_BeforeExportProperty(ExchangeFile, Source, Receiver, IncomingData, OutgoingData,
																   PCR, OCR, CollectionObject, Cancel, Value, ReceiverType, OCRName,
																   OCRNameextdimensiontype, Empty, Expression, PropertyCollectionNode, Donotreplace,
																   ExportObject);
					
				Else
					
					Execute(PCR.BeforeExport);
					
				EndIf;
				
				ExportRefOnly = Not ExportObject;
				
			Except
				
				WriteInformationAboutErrorPCRHandlers(55, ErrorDescription(), OCR, PCR, Source, 
						"BeforeExportProperty", Value);
														
			EndTry;
			
			If Cancel Then	//	Denial of the property export
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		// Create property node
		PropertyNodeStructure = Undefined;
		Propirtiesnode = Undefined;
		
		CreateComplexInformationForRecordingToXML(PropertyNodeStructure, Propirtiesnode, PCR.XMLNodeRequiredOnExport, PCR.Receiver, PCR.ParameterForTransferName);
							
		If Donotreplace Then
			
			AddAttributeForRecordToXML(PropertyNodeStructure, Propirtiesnode, "Donotreplace", "true");			
						
		EndIf;
		
		If PCR.SearchByEqualDate  Then
			
			AddAttributeForRecordToXML(PropertyNodeStructure, Propirtiesnode, "SearchByEqualDate", "true");
			
		EndIf;
		
		//	Conversion rule may have already been determined.
		If Not IsBlankString(OCRName) Then
			
			OCRProperties = Rules[OCRName];
			
		Else
			
			OCRProperties = Undefined;
			
		EndIf;
		
		If Not IsBlankString(ReceiverType) Then
			
			AddAttributeForRecordToXML(PropertyNodeStructure, Propirtiesnode, "Type", ReceiverType);
			
		ElsIf OCRProperties <> Undefined Then
			
			// Attempt to determine receiver property type.
			ReceiverType = OCRProperties.Receiver;
			
			AddAttributeForRecordToXML(PropertyNodeStructure, Propirtiesnode, "Type", ReceiverType);
			
		EndIf;
		
		If Not IsBlankString(OCRName)
			AND OCRProperties <> Undefined
			AND OCRProperties.HasSearchFieldSequenceHandler = True Then
			
			AddAttributeForRecordToXML(PropertyNodeStructure, Propirtiesnode, "OCRName", OCRName);
			
		EndIf;
		
		IsOrdinaryProperty = IsBlankString(PCR.ParameterForTransferName);
		
		//	Determine converted value.
		If Expression <> Undefined Then
			
			AddValueForRecordToXML(PropertyNodeStructure, Propirtiesnode, "Expression", Expression);
			
			WriteDataIntoHeadNode(PropertyCollectionNode, PropertyNodeStructure, Propirtiesnode, IsOrdinaryProperty);
			Continue;
			
		ElsIf Empty Then
			
			WriteDataIntoHeadNode(PropertyCollectionNode, PropertyNodeStructure, Propirtiesnode, IsOrdinaryProperty);
			Continue;
			
		Else
			
			GetPropertyValue(Value, CollectionObject, OCR, PCR, IncomingData, Source, PropertySelection);
			
			If PCR.CastToLength <> 0 Then
				
				RunValueCastToLength(Value, PCR);
								
			EndIf;
						
		EndIf;

		OldValueBeforeOnExportHandler = Value;
		Empty = deBlank(Value, IsNULL);
		
		// Handler OnExport
		If PCR.HasOnExportHandler Then
			
			Cancel = False;
			
			Try
				
				ExportObject = Not ExportRefOnly;
				
				If DebuggingExportHandlers Then
					
					ExecuteHandler_PCR_OnExportProperty(ExchangeFile, Source, Receiver, IncomingData, OutgoingData,
																PCR, OCR, CollectionObject, Cancel, Value, KeyAndValue, ExtDimensionType,
																ExtDimension, Empty, OCRName, OCRProperties,Propirtiesnode, PropertyCollectionNode,
																OCRNameextdimensiontype, ExportObject);
					
				Else
					
					Execute(PCR.OnExport);
					
				EndIf;
				
				ExportRefOnly = Not ExportObject;
				
			Except
				
				WriteInformationAboutErrorPCRHandlers(56, ErrorDescription(), OCR, PCR, Source, 
						"OnExportProperty", Value);
														
			EndTry;
			
			If Cancel Then	//	Denial of the property export
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		// Once again initialize the Empty variable, Value may have been changed in the handler "On export".
		If OldValueBeforeOnExportHandler <> Value Then
			
			Empty = deBlank(Value, IsNULL);
			
		EndIf;

		If Empty Then
			
			If IsNULL Then
				
				Value = Undefined;
				
			EndIf;
			
			If Value <> Undefined 
				AND IsBlankString(ReceiverType) Then
				
				ReceiverType = DefineDataTypeForReceiver(Value);
				
				If Not IsBlankString(ReceiverType) Then
					
					AddAttributeForRecordToXML(PropertyNodeStructure, Propirtiesnode, "Type", ReceiverType);
					
				EndIf;
								
			EndIf;			
			
			WriteDataIntoHeadNode(PropertyCollectionNode, PropertyNodeStructure, Propirtiesnode, IsOrdinaryProperty);
			Continue;
			
		EndIf;
      		
		Referencenode = Undefined;
		
		If OCRProperties = Undefined
			AND IsBlankString(OCRName) Then
			
			PropertySet = False;
			ValueType = TypeOf(Value);
			TypeRequired = False;
			DefineOpportunityOfValueAssign(Value, ValueType, ReceiverType, PropertySet, TypeRequired);
						
			If PropertySet Then
				
				// specify type if needed
				If TypeRequired Then
					
					AddAttributeForRecordToXML(PropertyNodeStructure, Propirtiesnode, "Type", ReceiverType);
					
				EndIf;
				
				AddValueForRecordToXML(PropertyNodeStructure, Propirtiesnode, "Value", Value);
								              				
			Else
				
				ValueManager = Managers[ValueType];
				
				If ValueManager = Undefined Then
					Continue;
				EndIf;
				
				OCRProperties = ValueManager.OCR;
				
				If OCRProperties = Undefined Then
					Continue;
				EndIf;
					
				OCRName = OCRProperties.Name;
				
			EndIf;
			
		EndIf;
		
		If (OCRProperties <> Undefined) 
			Or (NOT IsBlankString(OCRName)) Then
			
			If ExportRefOnly Then
				
				If ExportObjectByRef(Value, NodeForExchange) Then
					
					If Not ObjectPassingFilterOfAllowedObjects(Value) Then
						
						// Set a flag showing that object should be fully exported.
						ExportRefOnly = False;
						
						// Add record to the match register.
						RecordStructure = New Structure;
						RecordStructure.Insert("InfobaseNode", NodeForExchange);
						RecordStructure.Insert("UniqueSourceHandle", Value);
						RecordStructure.Insert("ObjectExportedByRef", True);
						
						InformationRegisters.InfobasesObjectsCompliance.AddRecord(RecordStructure, True);
						
						// Add an object to array of objects
						// exported by the ref for further objects
						// registration on the current node and for assigning a number of the current sent exchange message.
						ExportedObjectsByRefAddValue(Value);
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
			RuleWithGlobalExport = False;
			Referencenode = DumpByRule(Value, , OutgoingData, , OCRName, , ExportRefOnly, OCRProperties, , , , , False, 
				RuleWithGlobalExport, DontUseRulesWithGlobalExportAndDontRememberExported);
	
			If Referencenode = Undefined Then
						
				Continue;
						
			EndIf;
			
			If IsBlankString(ReceiverType) Then
						
				ReceiverType  = OCRProperties.Receiver;
				AddAttributeForRecordToXML(PropertyNodeStructure, Propirtiesnode, "Type", ReceiverType);
														
			EndIf;			
				
			RefNodeType = TypeOf(Referencenode);
						
			If RefNodeType = StringType Then
				
				If Find(Referencenode, "<Ref") > 0 Then
								
					AddArbitraryDataForRecordToXML(PropertyNodeStructure, Propirtiesnode, "Ref", Referencenode);
											
				Else
					
					AddValueForRecordToXML(PropertyNodeStructure, Propirtiesnode, "Value", Referencenode);
																	
				EndIf;
						
			ElsIf RefNodeType = NumberType Then
				
				If RuleWithGlobalExport Then
					AddValueForRecordToXML(PropertyNodeStructure, Propirtiesnode, "GSn", Referencenode);
				Else
					AddValueForRecordToXML(PropertyNodeStructure, Propirtiesnode, "NPP", Referencenode);
				EndIf;
														
			Else
				
				Referencenode.WriteEndElement();
				InformationToWriteToFile = Referencenode.Close();
				
				AddArbitraryDataForRecordToXML(PropertyNodeStructure, Propirtiesnode, "Ref", InformationToWriteToFile);
										
			EndIf;
													
		EndIf;
		
		
		
		// Handler AfterExport
		
		If PCR.HasAfterExportHandler Then
			
			Cancel = False;
			
			Try
				
				If DebuggingExportHandlers Then
					
					ExecuteHandler_PCR_AfterExportProperty(ExchangeFile, Source, Receiver, IncomingData, OutgoingData,
																  PCR, OCR, CollectionObject, Cancel, Value, KeyAndValue, ExtDimensionType,
																  ExtDimension, OCRName, OCRNameextdimensiontype, OCRProperties, Propirtiesnode,
																  Referencenode, PropertyCollectionNode, Nodeextdimension);
					
				Else
					
					Execute(PCR.AfterExport);
					
				EndIf;
				
			Except
				
				WriteInformationAboutErrorPCRHandlers(57, ErrorDescription(), OCR, PCR, Source, 
						"AfterExportProperty", Value);
				
			EndTry;
			
			If Cancel Then	//	Denial of the property export
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		WriteDataIntoHeadNode(PropertyCollectionNode, PropertyNodeStructure, Propirtiesnode, IsOrdinaryProperty);
		
	EndDo; // by PCR
	
EndProcedure

Procedure DefineOCRByParameters(OCR, Source, OCRName)
	
	// Search OCR
	If OCR = Undefined Then
		
        OCR = FindRule(Source, OCRName);
		
	ElsIf (NOT IsBlankString(OCRName))
		AND OCR.Name <> OCRName Then
		
		OCR = FindRule(Source, OCRName);
				
	EndIf;	
	
EndProcedure

Function FindPropertiesStructureByParameters(OCR, Source)
	
	PropertyStructure = Managers[OCR.Source];
	If PropertyStructure = Undefined Then
		PropertyStructure = Managers[TypeOf(Source)];
	EndIf;	
	
	Return PropertyStructure;
	
EndFunction

Function DefineRefByObjectOrRef(Source, ExportingObject)
	
	If ExportingObject Then
		Return Source.Ref;
	Else
		Return Source;
	EndIf;
	
EndFunction

Function DefineInternallyPresentationForSearch(Source, PropertyStructure)
	
	If PropertyStructure.TypeName = "Enum" Then
		Return Source;
	Else
		Return ValueToStringInternal(Source);
	EndIf
	
EndFunction

Procedure UpdateDataInsideDataBeingDumped()
	
	If DataMapForExportedItemUpdate.Count() > 0 Then
		
		DataMapForExportedItemUpdate.Clear();
		
	EndIf;
	
EndProcedure

Procedure DoSignsSetupForObjectsDumpedToFile()
	
	WrittenToFileNPP = SnCounter;
	
EndProcedure

Procedure WriteExchangeObjectsPriority(ExchangeObjectPriority, Node)
	
	If ValueIsFilled(ExchangeObjectPriority)
		AND ExchangeObjectPriority <> Enums.ExchangeObjectPriorities.PriorityOfObjectReceivedOnExchangeIsHigher Then
		
		If ExchangeObjectPriority = Enums.ExchangeObjectPriorities.PriorityOfObjectReceivedOnExchangeIsLower Then
			SetAttribute(Node, "ExchangeObjectPriority", "below");
		ElsIf ExchangeObjectPriority = Enums.ExchangeObjectPriorities.PriorityOfObjectReceivedOnExchangeIsTheSame Then
			SetAttribute(Node, "ExchangeObjectPriority", "Matches");					
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure DumpInformationAboutRegisteredObject(RecordSetForExport)
	
	If RecordSetForExport.Count() = 0 Then // export an empty IR set
		
		Filter = New Structure;
		Filter.Insert("UniqueSourceHandle", RecordSetForExport.Filter.UniqueSourceHandle.Value);
		Filter.Insert("UniqueReceiverHandle", RecordSetForExport.Filter.UniqueReceiverHandle.Value);
		Filter.Insert("SourceType",                     RecordSetForExport.Filter.SourceType.Value);
		Filter.Insert("ReceiverType",                     RecordSetForExport.Filter.ReceiverType.Value);
		
		DumpInfobasesObjectsCorrespondenceRecord(Filter, True);
		
	Else
		
		For Each SetRow IN RecordSetForExport Do
			
			DumpInfobasesObjectsCorrespondenceRecord(SetRow, False);
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure DumpInfobasesObjectsCorrespondenceRecord(SetRow, EmptySet)
	
	Receiver = CreateNode("ObjectChangeRecordData");
	
	SetAttribute(Receiver, "UniqueSourceHandle", String(SetRow.UniqueSourceHandle.UUID()));
	SetAttribute(Receiver, "UniqueReceiverHandle",        SetRow.UniqueReceiverHandle);
	SetAttribute(Receiver, "SourceType",                            SetRow.SourceType);
	SetAttribute(Receiver, "ReceiverType",                            SetRow.ReceiverType);
	
	SetAttribute(Receiver, "EmptySet", EmptySet);
	
	Receiver.WriteEndElement(); // ObjectChangeRecordData
	
	WriteToFile(Receiver);
	
	IncreaseExportedObjectsCounter();
	
EndProcedure

Procedure CallEventsBeforeObjectExport(Object, Rule, Properties=Undefined, IncomingData=Undefined, 
	DontExportPropertyObjectsByRefs = False, OCRName, Cancel, OutgoingData)
	
	
	If CommentObjectProcessingFlag Then
		
		TypeDescription = New TypeDescription("String");
		RowObject  = TypeDescription.AdjustValue(Object);
		If RowObject = "" Then
			ObjectPresentation = RowObject + "  (" + TypeOf(Object) + ")";
		Else
			ObjectPresentation = TypeOf(Object);
		EndIf;
		
		EventName = NStr("en='ObjectExport: %1';ru='ВыгрузкаОбъекта: %1'");
		EventName = StringFunctionsClientServer.PlaceParametersIntoString(EventName, ObjectPresentation);
		
		WriteInExecutionProtocol(EventName, , False, 1, 7);
		
	EndIf;
	
	
	OCRName			= Rule.ConversionRule;
	Cancel			= False;
	OutgoingData	= Undefined;
	
	
	// Global handler BeforeObjectExport.
	If HasBeforeObjectExportGlobalHandler Then
		
		Try
			
			If DebuggingExportHandlers Then
				
				ExecuteHandler_Conversion_BeforeObjectExport(ExchangeFile, Cancel, OCRName, Rule, IncomingData, OutgoingData, Object);
				
			Else
				
				Execute(Conversion.BeforeObjectExport);
				
			EndIf;
			
		Except
			WriteInformationAboutErrorDDRHandlers(65, ErrorDescription(), Rule.Name, NStr("en='BeforeExportSelectionObject (global)';ru='ПередВыгрузкойОбъектаВыборки (глобальный)'"), Object);
		EndTry;
		
		If Cancel Then
			Return;
		EndIf;
		
	EndIf;
	
	// Handler BeforeExport
	If Not IsBlankString(Rule.BeforeExport) Then
		
		Try
			
			If DebuggingExportHandlers Then
				
				ExecuteHandler_DDR_BeforeObjectExport(ExchangeFile, Cancel, OCRName, Rule, IncomingData, OutgoingData, Object);
				
			Else
				
				Execute(Rule.BeforeExport);
				
			EndIf;
			
		Except
			WriteInformationAboutErrorDDRHandlers(33, ErrorDescription(), Rule.Name, "BeforeExportSelectionObject", Object);
		EndTry;
		
	EndIf;		
	
EndProcedure

Procedure CallEventsAfterObjectExport(Object, Rule, Properties=Undefined, IncomingData=Undefined, 
	DontExportPropertyObjectsByRefs = False, OCRName, Cancel, OutgoingData)
	
	Var Referencenode; // Variable-stub
	
	// Global handler AfterObjectExport.
	If HasAfterObjectExportGlobalHandler Then
		
		Try
			
			If DebuggingExportHandlers Then
				
				ExecuteHandler_Conversion_AfterObjectExport(ExchangeFile, Object, OCRName, IncomingData, OutgoingData, Referencenode);
				
			Else
				
				Execute(Conversion.AfterObjectExport);
				
			EndIf;
			
		Except
			WriteInformationAboutErrorDDRHandlers(69, ErrorDescription(), Rule.Name, NStr("en='AfterSelectionObjectExport (Global)';ru='ПослеВыгрузкиОбъектаВыборки (глобальный)'"), Object);
		EndTry;
	EndIf;
	
	// Handler AfterExport
	If Not IsBlankString(Rule.AfterExport) Then
		
		Try
			
			If DebuggingExportHandlers Then
				
				ExecuteHandler_DDR_AfterObjectExport(ExchangeFile, Object, OCRName, IncomingData, OutgoingData, Referencenode, Rule);
				
			Else
				
				Execute(Rule.AfterExport);
				
			EndIf;
			
		Except
			WriteInformationAboutErrorDDRHandlers(34, ErrorDescription(), Rule.Name, "AfterSelectionObjectExport", Object);
		EndTry;
		
	EndIf;
	
EndProcedure

// Exports selection object according to the specified rule.
//
// Parameters:
//  Object         - selection exported object.
//  Rule        - ref to the data export rule.
//  Properties       - metadata object property of the exported object.
//  IncomingData - custom helper data.
// 
Function ExportSelectionObject(Object, 
								ExportRule, 
								Properties=Undefined, 
								IncomingData = Undefined,
								DontExportPropertyObjectsByRefs = False, 
								ExportRecordSetRow = False, 
								ParentNode = Undefined, 
								ConstantNameForExport = "",
								OCRName = "",
								FireEvents = True)
								
	Cancel			= False;
	OutgoingData	= Undefined;
		
	If FireEvents
		AND ExportRule <> Undefined Then							

		OCRName			= "";		
		
		CallEventsBeforeObjectExport(Object, ExportRule, Properties, IncomingData, 
			DontExportPropertyObjectsByRefs, OCRName, Cancel, OutgoingData);
		
		If Cancel Then
			Return False;
		EndIf;
		
	EndIf;
	
	Referencenode = Undefined;
	DumpByRule(Object, , IncomingData, OutgoingData, OCRName, Referencenode, , , Not DontExportPropertyObjectsByRefs, 
		ExportRecordSetRow, ParentNode, ConstantNameForExport, True);
		
		
	If FireEvents
		AND ExportRule <> Undefined Then
		
		CallEventsAfterObjectExport(Object, ExportRule, Properties, IncomingData, 
		DontExportPropertyObjectsByRefs, OCRName, Cancel, OutgoingData);	
		
	EndIf;
	
	Return Not Cancel;
	
EndFunction

// Exports register calling rules BeforeExport and AfterExport.
//
Function RegisterDump(RecordSetForExport,
							Rule = Undefined,
							IncomingData = Undefined,
							DontExportPropertyObjectsByRefs = False,
							OCRName = "") Export
							
	OCRName			= "";
	Cancel			= False;
	OutgoingData	= Undefined;
		
	CallEventsBeforeObjectExport(RecordSetForExport, Rule, Undefined, IncomingData, 
		DontExportPropertyObjectsByRefs, OCRName, Cancel, OutgoingData);
		
	If Cancel Then
		Return False;
	EndIf;	
	
	
	DumpRegister(RecordSetForExport, 
					 Undefined, 
					 OutgoingData, 
					 DontExportPropertyObjectsByRefs, 
					 OCRName,
					 Rule);
		
	CallEventsAfterObjectExport(RecordSetForExport, Rule, Undefined, IncomingData, 
		DontExportPropertyObjectsByRefs, OCRName, Cancel, OutgoingData);	
		
	Return Not Cancel;							
							
EndFunction

// Generates query result to export data clearing.
//
Function GetQueryResultForDataDumpClear(Properties, TypeName, 
	SelectionForDataClearing = False, DeleteObjectsDirectly = False, SelectAllFields = True) Export 
	
	AllowedString = ?(ExportAllowedOnly, " ALLOWED ", "");
	
	FieldSelectionString = ?(SelectAllFields, " * ", "	ObjectForExport.Ref AS Ref ");
	
	If TypeName = "Catalog" 
		OR TypeName = "ChartOfCharacteristicTypes" 
		OR TypeName = "ChartOfAccounts" 
		OR TypeName = "ChartOfCalculationTypes" 
		OR TypeName = "AccountingRegister"
		OR TypeName = "ExchangePlan"
		OR TypeName = "Task"
		OR TypeName = "BusinessProcess" Then
		
		Query = New Query();
		
		If TypeName = "AccountingRegister" Then
			
			FieldSelectionString = "*";	
			
		EndIf;
		
		Query.Text = "SELECT " + AllowedString + "
		         |	" + FieldSelectionString + "
		         |IN
		         |	" + TypeName + "." + Properties.Name + " AS ObjectForExport
				 |
				 |";
		
		If SelectionForDataClearing
			AND DeleteObjectsDirectly Then
			
			If (TypeName = "Catalog"
				OR TypeName = "ChartOfCharacteristicTypes") Then
				
				If TypeName = "Catalog" Then
					HierarchyRequired = Metadata.Catalogs[Properties.Name].Hierarchical;
				Else
					HierarchyRequired = Metadata.ChartsOfCharacteristicTypes[Properties.Name].Hierarchical;
				EndIf;
				
				If HierarchyRequired Then
					
					Query.Text = Query.Text + "
					|	WHERE ObjectForExport.Parent = &Parent
					|";
					
					Query.SetParameter("Parent", Properties.Manager.EmptyRef());
				
				EndIf;
				
			EndIf;
			
		EndIf;		 
					
	ElsIf TypeName = "Document" Then
		
		Query = New Query();
		
		ResultingDateRestriction = "";
				
		Query.Text = "SELECT " + AllowedString + "
		         |	" + FieldSelectionString + "
		         |IN
		         |	" + TypeName + "." + Properties.Name + " AS ObjectForExport
				 |
				 |" + ResultingDateRestriction;
					 
											
	ElsIf TypeName = "InformationRegister" Then
		
		Nonperiodical = Not Properties.Periodical;
		SubordinatedToRecorder = Properties.SubordinatedToRecorder;
		
		
		RestrictionByDateNotRequired = SelectionForDataClearing	OR Nonperiodical;
				
		Query = New Query();
		
		ResultingDateRestriction = "";
				
		SelectionFieldSupplementionStringSubordinateToRegistrar = ?(NOT SubordinatedToRecorder, ", NULL AS Active,
		|	NULL AS Recorder,
		|	NULL AS LineNumber", "");
		
		SelectionFieldSupplementionStringPeriodicity = ?(Nonperiodical, ", NULL AS Period", "");
		
		Query.Text = "SELECT " + AllowedString + "
		         |	*
				 |
				 | " + SelectionFieldSupplementionStringSubordinateToRegistrar + "
				 | " + SelectionFieldSupplementionStringPeriodicity + "
				 |
		         |IN
		         |	" + TypeName + "." + Properties.Name + " AS ObjectForExport
				 |
				 |" + ResultingDateRestriction;
		
	Else
		
		Return Undefined;
					
	EndIf;
	
	
	Return Query.Execute();
	
EndFunction

// Generates selection to export data clearing.
//
Function GetSelectionForDataDumpClear(Properties, TypeName, 
	SelectionForDataClearing = False, DeleteObjectsDirectly = False, SelectAllFields = True) Export
	
	QueryResult = GetQueryResultForDataDumpClear(Properties, TypeName, 
			SelectionForDataClearing, DeleteObjectsDirectly, SelectAllFields);
			
	If QueryResult = Undefined Then
		Return Undefined;
	EndIf;
			
	Selection = QueryResult.Select();
	
	
	Return Selection;		
	
EndFunction

Function GetSelectionForDumpWithRestrictions(Rule)
	
	MetadataName           = Rule.ObjectForQueryName;
	
	AllowedString = ?(ExportAllowedOnly, " ALLOWED ", "");
	
	ReportBuilder.Text = "SELECT " + AllowedString + " Object.Ref AS Ref FROM " + MetadataName + " AS Object "+ "{WHERE Object.Ref. * AS " + StrReplace(MetadataName, ".", "_") + "}";
	ReportBuilder.Filter.Reset();
	If Not Rule.BuilderSettings = Undefined Then
		ReportBuilder.SetSettings(Rule.BuilderSettings);
	EndIf;

	ReportBuilder.Execute();
	Selection = ReportBuilder.Result.Select();
		
	Return Selection;
		
EndFunction

Function GetSelectionForDumpByArbitraryAlgorithm(DataSelection)
	
	Selection = Undefined;
	
	SelectionType = TypeOf(DataSelection);
			
	If SelectionType = Type("QueryResultSelection") Then
				
		Selection = DataSelection;
		
	ElsIf SelectionType = Type("QueryResult") Then
				
		Selection = DataSelection.Select();
					
	ElsIf SelectionType = Type("Query") Then
				
		QueryResult = DataSelection.Execute();
		Selection          = QueryResult.Select();
									
	EndIf;
		
	Return Selection;	
	
EndFunction

Function GetConstantsSetStringForDump(ConstantDataTableForExport)
	
	ConstantsSetString = "";
	
	For Each TableRow IN ConstantDataTableForExport Do
		
		If Not IsBlankString(TableRow.Source) Then
		
			ConstantsSetString = ConstantsSetString + ", " + TableRow.Source;
			
		EndIf;	
		
	EndDo;	
	
	If Not IsBlankString(ConstantsSetString) Then
		
		ConstantsSetString = Mid(ConstantsSetString, 3);
		
	EndIf;
	
	Return ConstantsSetString;
	
EndFunction

Function DumpConstantsSet(Rule, Properties, OutgoingData, ConstantsSetNameString = "")
	
	If ConstantsSetNameString = "" Then
		ConstantsSetNameString = GetConstantsSetStringForDump(Properties.OCR.Properties);
	EndIf;
			
	ConstantsSet = Constants.CreateSet(ConstantsSetNameString);
	ConstantsSet.Read();
	ExportResult = ExportSelectionObject(ConstantsSet, Rule, Properties, OutgoingData, , , , ConstantsSetNameString);	
	Return ExportResult;
	
EndFunction

Function DefineNeedToSelectAllFields(Rule)
	
	AllFieldsRequiredForSelection = Not IsBlankString(Conversion.BeforeObjectExport)
		OR Not IsBlankString(Rule.BeforeExport)
		OR Not IsBlankString(Conversion.AfterObjectExport)
		OR Not IsBlankString(Rule.AfterExport);		
		
	Return AllFieldsRequiredForSelection;	
	
EndFunction

// Export data by the specified rule.
//
// Parameters:
//  Rule        - ref to the data export rule.
// 
Procedure DumpDataByRule(Rule) Export
	
	OCRName = Rule.ConversionRule;
	
	If Not IsBlankString(OCRName) Then
		
		OCR = Rules[OCRName];
		
	EndIf;


	If CommentObjectProcessingFlag Then
		
		MessageString = NStr("en='DATA EXPORT RULE: %1 (%2)';ru='ПРАВИЛО ВЫГРУЗКИ ДАННЫХ: %1 (%2)'");
		MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, TrimAll(Rule.Name), TrimAll(Rule.Description));
		WriteInExecutionProtocol(MessageString, , False, , 4);
		
	EndIf;
		
	
	// Handler BeforeDataProcessor
	Cancel			= False;
	OutgoingData	= Undefined;
	DataSelection	= Undefined;
	
	If Not IsBlankString(Rule.BeforeProcess) Then
		
		Try
			
			If DebuggingExportHandlers Then
				
				ExecuteHandler_DDR_BeforeProcessRule(Cancel, OCRName, Rule, OutgoingData, DataSelection);
				
			Else
				
				Execute(Rule.BeforeProcess);
				
			EndIf;
			
		Except
			
			WriteInformationAboutErrorDDRHandlers(31, ErrorDescription(), Rule.Name, "BeforeProcessDataExport");
			
		EndTry;
		
		If Cancel Then
			
			Return;
			
		EndIf;
		
	EndIf;
	
	// Standard selection with filter.
	If Rule.DataSelectionVariant = "StandardSelection" AND Rule.UseFilter Then

		Selection = GetSelectionForDumpWithRestrictions(Rule);
		
		While Selection.Next() Do
			ExportSelectionObject(Selection.Ref, Rule, , OutgoingData);
		EndDo;

	// Standard selection without filter.
	ElsIf (Rule.DataSelectionVariant = "StandardSelection") Then
		
		Properties	= Managers[Rule.SelectionObject];
		TypeName		= Properties.TypeName;
		
		If TypeName = "Constants" Then
			
			DumpConstantsSet(Rule, Properties, OutgoingData);		
			
		Else
			
			IsNotReferenceType = TypeName =  "InformationRegister" 
				OR TypeName = "AccountingRegister";
			
			
			If IsNotReferenceType Then
					
				SelectAllFields = DefineNeedToSelectAllFields(Rule);
				
			Else
				
				// receive only ref
				SelectAllFields = False;	
				
			EndIf;	
				
			
			Selection = GetSelectionForDataDumpClear(Properties, TypeName, , , SelectAllFields);
			
			If Selection = Undefined Then
				Return;
			EndIf;
			
			While Selection.Next() Do
				
				If IsNotReferenceType Then
					
					ExportSelectionObject(Selection, Rule, Properties, OutgoingData);
					
				Else
					
					ExportSelectionObject(Selection.Ref, Rule, Properties, OutgoingData);
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	ElsIf Rule.DataSelectionVariant = "ArbitraryAlgorithm" Then

		If DataSelection <> Undefined Then
			
			Selection = GetSelectionForDumpByArbitraryAlgorithm(DataSelection);
			
			If Selection <> Undefined Then
				
				While Selection.Next() Do
					
					ExportSelectionObject(Selection, Rule, , OutgoingData);
					
				EndDo;
				
			Else
				
				For Each Object IN DataSelection Do
					
					ExportSelectionObject(Object, Rule, , OutgoingData);
					
				EndDo;
				
			EndIf;
			
		EndIf;
			
	EndIf;

	
	// Handler AfterDataProcessor
	
	If Not IsBlankString(Rule.AfterProcessing) Then
		
		Try
			
			If DebuggingExportHandlers Then
				
				ExecuteHandler_DDR_AfterProcessRule(OCRName, Rule, OutgoingData);
				
			Else
				
				Execute(Rule.AfterProcessing);
				
			EndIf;
			
		Except
			
			WriteInformationAboutErrorDDRHandlers(32, ErrorDescription(), Rule.Name, "AfterProcessDataExport");
			
		EndTry;
		
	EndIf;
	
EndProcedure

Procedure WorkThroughObjectDeletion(ObjectDeletionData, ErrorMessageString = "")
	
	Ref = ObjectDeletionData.Ref;
	
	EventText = "";
	If Conversion.Property("BeforeSendDeletionInfo", EventText) Then
		
		If Not IsBlankString(EventText) Then
			
			Cancel = False;
			
			Try
				
				If DebuggingExportHandlers Then
					
					ExecuteHandler_Conversion_BeforeSendDeletionInfo(Ref, Cancel);
					
				Else
					
					Execute(EventText);
					
				EndIf;
				
			Except
				ErrorMessageString = WriteInformationAboutErrorConversionHandlers(76, ErrorDescription(), NStr("en='BeforeSendingInformationAboutDeletion (conversion)';ru='ПередОтправкойИнформацииОбУдалении (конвертация)'"));
				
				If Not ContinueOnError Then
					Raise ErrorMessageString;
				EndIf;
				
				Cancel = True;
			EndTry;
			
			If Cancel Then
				Return;
			EndIf;
			
		EndIf;
	EndIf;
	
	Manager = Managers[TypeOf(Ref)];
	
	// Check whether there is manager and OCR.
	If    Manager = Undefined
		OR Manager.OCR = Undefined Then
		
		LR = GetProtocolRecordStructure(45);
		
		LR.Object = Ref;
		LR.ObjectType = TypeOf(Ref);
		
		WriteInExecutionProtocol(45, LR, True);
		Return;
		
	EndIf;
	
	WriteToFileObjectDeletion(Ref, Manager.OCR.ReceiverType, Manager.OCR.SourceType);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF COMPILATION EXCHANGE RULES TO STRUCTURE

// returns exchange rules structure.
Function GetExchangeRulesStructure(Source) Export
	
	ImportExchangeRules(Source, "XMLFile");
	
	If ErrorFlag() Then
		Return Undefined;
	EndIf;
	
	If ExchangeMode = "Import" Then
		ObjectChangeRecordAttributeTable = Undefined;
	Else
		// Get registration attributes table for the mechanism of objects selective registration.
		ObjectChangeRecordAttributeTable = GetObjectRegistrationAttributesTable();
	EndIf;
	
	// save queries
	QueriesToSave = New Structure;
	
	For Each StructureItem IN Queries Do
		
		QueriesToSave.Insert(StructureItem.Key, StructureItem.Value.Text);
		
	EndDo;
	
	// save parameters
	ParametersToSave = New Structure;
	
	For Each StructureItem IN Parameters Do
		
		ParametersToSave.Insert(StructureItem.Key, Undefined);
		
	EndDo;
	
	ExchangeRuleStructure = New Structure;
	
	ExchangeRuleStructure.Insert("StorageRulesFormatVersion", FormatVersionStorageRulesExchange());
	
	ExchangeRuleStructure.Insert("Conversion", Conversion);
	
	ExchangeRuleStructure.Insert("ParametersSettingsTable", ParametersSettingsTable);
	ExchangeRuleStructure.Insert("UnloadRulesTable",      UnloadRulesTable);
	ExchangeRuleStructure.Insert("ConversionRulesTable",   ConversionRulesTable);
	
	ExchangeRuleStructure.Insert("Algorithms", Algorithms);
	ExchangeRuleStructure.Insert("Parameters", ParametersToSave);
	ExchangeRuleStructure.Insert("Queries",   QueriesToSave);
	
	ExchangeRuleStructure.Insert("XMLRules",              XMLRules);
	ExchangeRuleStructure.Insert("TypesForTargetString", TypesForTargetString);
	
	ExchangeRuleStructure.Insert("SelectiveObjectRegistrationRules", ObjectChangeRecordAttributeTable);
	
	Return ExchangeRuleStructure;
	
EndFunction

Function GetObjectRegistrationAttributesTable()
	
	ChangeRecordAttributeTable = AttributesRegistrationTableInitialization();
	ResultTable             = AttributesRegistrationTableInitialization();
	
	// Get provisional table from conversion rules.
	For Each OCR IN ConversionRulesTable Do
		
		FillObjectRegistrationByRuleAttributesTable(OCR, ResultTable);
		
	EndDo;
	
	ResultTableGroup = ResultTable.Copy();
	
	ResultTableGroup.GroupBy("ObjectName, TabularSectionName");
	
	// Get final table considering provisional table grouped strings.
	For Each TableRow IN ResultTableGroup Do
		
		Filter = New Structure("ObjectName, TabularSectionName", TableRow.ObjectName, TableRow.TabularSectionName);
		
		ResultTableRowArray = ResultTable.FindRows(Filter);
		
		SupplementRegistrationAttributesTable(ResultTableRowArray, ChangeRecordAttributeTable);
		
	EndDo;
	
	// delete strings with errors
	DeleteRowsWithErrorsOfAttributeRegistrationTable(ChangeRecordAttributeTable);
	
	// Check whether there are required header attributes and tabular section attributes of metadata objects.
	RunObjectRegistrationAttributesCheck(ChangeRecordAttributeTable);
	
	// Fill in table with Exchange plan name value.
	ChangeRecordAttributeTable.FillValues(ExchangePlanNameVRO, "ExchangePlanName");
	
	Return ChangeRecordAttributeTable;
	
EndFunction

Function AttributesRegistrationTableInitialization()
	
	ResultTable = New ValueTable;
	
	ResultTable.Columns.Add("Order",                        deDescriptionType("Number"));
	ResultTable.Columns.Add("ObjectName",                     deDescriptionType("String"));
	ResultTable.Columns.Add("ObjectTypeAsString",              deDescriptionType("String"));
	ResultTable.Columns.Add("ExchangePlanName",                 deDescriptionType("String"));
	ResultTable.Columns.Add("TabularSectionName",              deDescriptionType("String"));
	ResultTable.Columns.Add("ChangeRecordAttributes",           deDescriptionType("String"));
	ResultTable.Columns.Add("ChangeRecordAttributeStructure", deDescriptionType("Structure"));
	
	Return ResultTable;
	
EndFunction

Function GetRegistrationAttributesStructure(PCRTable)
	
	ChangeRecordAttributeStructure = New Structure;
	
	PCRRowArray = PCRTable.FindRows(New Structure("IsFolder", False));
	
	For Each PCR IN PCRRowArray Do
		
		// Check whether there are invalid characters in string.
		If IsBlankString(PCR.Source)
			OR Left(PCR.Source, 1) = "{" Then
			
			Continue;
		EndIf;
		
		Try
			ChangeRecordAttributeStructure.Insert(PCR.Source);
		Except
			WriteLogEvent(NStr("en='Data exchange. Conversion rules import';ru='Обмен данными.Загрузка правил конвертации'", CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		EndTry;
		
	EndDo;
	
	Return ChangeRecordAttributeStructure;
	
EndFunction

Function GetRegistrationAttributesStructureByArrayOfStrings(RowArray)
	
	ResultStructure = New Structure;
	
	For Each ResultTableRow IN RowArray Do
		
		ChangeRecordAttributeStructure = ResultTableRow.ChangeRecordAttributeStructure;
		
		For Each ChangeRecordAttribute IN ChangeRecordAttributeStructure Do
			
			ResultStructure.Insert(ChangeRecordAttribute.Key);
			
		EndDo;
		
	EndDo;
	
	Return ResultStructure;
	
EndFunction

Function GetRegistrationAttributes(ChangeRecordAttributeStructure)
	
	ChangeRecordAttributes = "";
	
	For Each ChangeRecordAttribute IN ChangeRecordAttributeStructure Do
		
		ChangeRecordAttributes = ChangeRecordAttributes + ChangeRecordAttribute.Key + ", ";
		
	EndDo;
	
	StringFunctionsClientServer.DeleteLatestCharInRow(ChangeRecordAttributes, 2);
	
	Return ChangeRecordAttributes;
	
EndFunction

Procedure RunObjectRegistrationAttributesCheck(ChangeRecordAttributeTable)
	
	For Each TableRow IN ChangeRecordAttributeTable Do
		
		Try
			ObjectType = Type(TableRow.ObjectTypeAsString);
		Except
			
			MessageString = NStr("en='The object type is not defined: %1';ru='Тип объекта не определен: %1'");
			MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, TableRow.ObjectTypeAsString);
			WriteInExecutionProtocol(MessageString);
			Continue;
			
		EndTry;
		
		MDObject = Metadata.FindByType(ObjectType);
		
		// Check only reference types.
		If Not CommonUse.ThisIsObjectOfReferentialType(MDObject) Then
			Continue;
		EndIf;
		
		CommonAttributesTable = CommonAttributesTable();
		FillCommonAttributesTable(CommonAttributesTable);
		
		If IsBlankString(TableRow.TabularSectionName) Then // header attributes
			
			For Each Attribute IN TableRow.ChangeRecordAttributeStructure Do
				
				If CommonUse.ThisIsTask(MDObject) Then
					
					If Not (MDObject.Attributes.Find(Attribute.Key) <> Undefined
						OR  MDObject.AddressingAttributes.Find(Attribute.Key) <> Undefined
						OR  DataExchangeServer.ThisIsStandardAttribute(MDObject.StandardAttributes, Attribute.Key)
						OR  IsCommonAttribute(Attribute.Key, MDObject.FullName(), CommonAttributesTable)) Then
						
						MessageString = NStr("en='""%1"" object header attributes are specified incorrectly. Attribute ""%2"" does not exist.';ru='Неправильно указаны реквизиты шапки объекта ""%1"". Реквизит ""%2"" не существует.'");
						MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, String(MDObject), Attribute.Key);
						WriteInExecutionProtocol(MessageString);
						
					EndIf;
					
				Else
					
					If Not (MDObject.Attributes.Find(Attribute.Key) <> Undefined
						OR  DataExchangeServer.ThisIsStandardAttribute(MDObject.StandardAttributes, Attribute.Key)
						OR  IsCommonAttribute(Attribute.Key, MDObject.FullName(), CommonAttributesTable)) Then
						
						MessageString = NStr("en='""%1"" object header attributes are specified incorrectly. Attribute ""%2"" does not exist.';ru='Неправильно указаны реквизиты шапки объекта ""%1"". Реквизит ""%2"" не существует.'");
						MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, String(MDObject), Attribute.Key);
						WriteInExecutionProtocol(MessageString);
						
					EndIf;
					
				EndIf;
				
			EndDo;
			
		Else
			// Tabular section, standard tabular section, movements.
			MetaTable  = ObjectsRegistrationAttributesMetaTabularSection(MDObject, TableRow.TabularSectionName);
			If MetaTable = Undefined Then
				WriteInExecutionProtocol(StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='Tabular section (standard tabular section, movements) ""%1"" object ""%2"" does not exist.';ru='Табличная часть (стандартная табличная часть, движения) ""%1"" объекта ""%2"" не существует.'"),
					TableRow.TabularSectionName, MDObject));
				Continue;
			EndIf;
			
			// Try to find each attribute somewhere.
			For Each Attribute IN TableRow.ChangeRecordAttributeStructure Do
				
				If Not AttributeFoundInObjectsRegistrationAttributesTabularSection(MetaTable, Attribute.Key) Then
					WriteInExecutionProtocol(StringFunctionsClientServer.PlaceParametersIntoString(
						NStr("en='Attribute ""%3"" does not exist in the tabular section (standard tabular section, movements) ""%1"" of object ""%2"".';ru='Реквизит ""%3"" не существует в табличной части (стандартной табличной части, движениях) ""%1"" объекта ""%2"".'"),
						TableRow.TabularSectionName, MDObject, Attribute.Key));
					Break;
				EndIf;
				
			EndDo;
			
		EndIf;
	EndDo;
	
EndProcedure

Function ObjectsRegistrationAttributesMetaTabularSection(CurrentObjectMetadata, SearchedTabularSectionName)
	
	MetaTest = New Structure("TabularSections, StandardTabularSections, RegisterRecords");
	FillPropertyValues(MetaTest, CurrentObjectMetadata);
	
	CandidateName = Upper(SearchedTabularSectionName);
	
	For Each KeyValue IN MetaTest Do
		TablesMetaCollection = KeyValue.Value;
		If TablesMetaCollection <> Undefined Then
			
			For Each MetaTable IN TablesMetaCollection Do
				If Upper(MetaTable.Name) = CandidateName Then
					Return MetaTable;
				EndIf;
			EndDo;
			
		EndIf;
	EndDo;

	Return Undefined;
EndFunction

Function AttributeFoundInObjectsRegistrationAttributesTabularSection(TabularSectionMetadata, SearchedAttributeName)
	
	MetaTest = New Structure("Attributes, StandardAttributes, Dimensions, Resources");
	FillPropertyValues(MetaTest, TabularSectionMetadata);
			
	CandidateName = Upper(SearchedAttributeName);
	
	For Each KeyValue IN MetaTest Do
		AttributesMetaCollection = KeyValue.Value;
		If AttributesMetaCollection <> Undefined Then
			
			For Each MetaAttribute IN AttributesMetaCollection Do
				If Upper(MetaAttribute.Name) = CandidateName Then
					Return True;
				EndIf;
			EndDo;
			
		EndIf;
	EndDo;
	
	Return False;
EndFunction


Procedure FillObjectRegistrationByRuleAttributesTable(OCR, ResultTable)
	
	ObjectName        = StrReplace(OCR.SourceType, "Ref", "");
	ObjectTypeAsString = OCR.SourceType;
	
	// Fill in table with header attributes (properties).
	FillObjectRegistrationByTableAttributesTable(ObjectTypeAsString, ObjectName, "", -50, OCR.Properties, ResultTable);
	
	// Fill in table with header attributes (search properties).
	FillObjectRegistrationByTableAttributesTable(ObjectTypeAsString, ObjectName, "", -50, OCR.SearchProperties, ResultTable);
	
	// Fill in table with header attributes (disabled properties).
	FillObjectRegistrationByTableAttributesTable(ObjectTypeAsString, ObjectName, "", -50, OCR.DisabledProperties, ResultTable);
	
	// rule tabular sections
	PGCRArray = OCR.Properties.FindRows(New Structure("IsFolder", True));
	
	For Each PGCR IN PGCRArray Do
		
		// Fill in table with tabular section attributes.
		FillObjectRegistrationByTableAttributesTable(ObjectTypeAsString, ObjectName, PGCR.Source, PGCR.Order, PGCR.GroupRules, ResultTable);
		
		// Fill in table with tabular section attributes (disabled).
		FillObjectRegistrationByTableAttributesTable(ObjectTypeAsString, ObjectName, PGCR.Source, PGCR.Order, PGCR.DisabledGroupRules, ResultTable);
		
	EndDo;
	
	// Rule tabular sections (disabled).
	PGCRArray = OCR.DisabledProperties.FindRows(New Structure("IsFolder", True));
	
	For Each PGCR IN PGCRArray Do
		
		// Fill in table with tabular section attributes.
		FillObjectRegistrationByTableAttributesTable(ObjectTypeAsString, ObjectName, PGCR.Source, PGCR.Order, PGCR.GroupRules, ResultTable);
		
		// Fill in table with tabular section attributes (disabled).
		FillObjectRegistrationByTableAttributesTable(ObjectTypeAsString, ObjectName, PGCR.Source, PGCR.Order, PGCR.DisabledGroupRules, ResultTable);
		
	EndDo;
	
EndProcedure

Procedure FillObjectRegistrationByTableAttributesTable(ObjectTypeAsString, ObjectName, TabularSectionName, Order, PropertyTable, ResultTable)
	
	ResultTableRow = ResultTable.Add();
	
	ResultTableRow.Order                        = Order;
	ResultTableRow.ObjectName                     = ObjectName;
	ResultTableRow.ObjectTypeAsString              = ObjectTypeAsString;
	ResultTableRow.TabularSectionName              = TabularSectionName;
	ResultTableRow.ChangeRecordAttributeStructure = GetRegistrationAttributesStructure(PropertyTable);
	
EndProcedure

Procedure SupplementRegistrationAttributesTable(RowArray, ChangeRecordAttributeTable)
	
	TableRow = ChangeRecordAttributeTable.Add();
	
	TableRow.Order                        = RowArray[0].Order;
	TableRow.ObjectName                     = RowArray[0].ObjectName;
	TableRow.ObjectTypeAsString              = RowArray[0].ObjectTypeAsString;
	TableRow.TabularSectionName              = RowArray[0].TabularSectionName;
	TableRow.ChangeRecordAttributeStructure = GetRegistrationAttributesStructureByArrayOfStrings(RowArray);
	TableRow.ChangeRecordAttributes           = GetRegistrationAttributes(TableRow.ChangeRecordAttributeStructure);
	
EndProcedure

Procedure DeleteRowsWithErrorsOfAttributeRegistrationTable(ChangeRecordAttributeTable)
	
	CollectionItemsQuantity = ChangeRecordAttributeTable.Count();
	
	For ReverseIndex = 1 To CollectionItemsQuantity Do
		
		TableRow = ChangeRecordAttributeTable[CollectionItemsQuantity - ReverseIndex];
		
		// If there are no registration attributes, then delete string.
		If IsBlankString(TableRow.ChangeRecordAttributes) Then
			
			ChangeRecordAttributeTable.Delete(TableRow);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Returns a flag showing that attribute is included in the common attributes subset.
//
Function IsCommonAttribute(CommonAttribute, MDOName, CommonAttributesTable)
	
	SearchParameters = New Structure("CommonAttribute, MetadataObject", CommonAttribute, MDOName);
	FoundValues = CommonAttributesTable.FindRows(SearchParameters);
	
	If FoundValues.Count() > 0 Then
		
		Return True;
		
	EndIf;
	
	Return False;
	
EndFunction

Function CommonAttributesTable()
	
	CommonAttributesTable = New ValueTable;
	CommonAttributesTable.Columns.Add("CommonAttribute");
	CommonAttributesTable.Columns.Add("MetadataObject");
	
	CommonAttributesTable.Indexes.Add("CommonAttribute, MetadataObject");
	
	Return CommonAttributesTable;
	
EndFunction

Procedure FillCommonAttributesTable(CommonAttributesTable)
	
	If Metadata.CommonAttributes.Count() <> 0 Then
		
		CommonAttributeAutoUse = Metadata.ObjectProperties.CommonAttributeUse.Auto;
		CommonAttributeUse = Metadata.ObjectProperties.CommonAttributeUse.Use;
		
		For Each CommonAttribute IN Metadata.CommonAttributes Do
			
			If CommonAttribute.DataSeparationUse = Undefined Then
				
				Autousage = (CommonAttribute.Autousage = Metadata.ObjectProperties.CommonAttributeAutoUse.Use);
				
				For Each Item IN CommonAttribute.Content Do
					
					If Item.Use = CommonAttributeUse
						Or (Item.Use = CommonAttributeAutoUse AND Autousage) Then
						
						NewRow = CommonAttributesTable.Add();
						NewRow.CommonAttribute = CommonAttribute.Name;
						NewRow.MetadataObject = Item.Metadata.FullName();
						
					EndIf;
					
				EndDo;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// EXPORTED PROCEDURES AND FUNCTIONS

// Prepares string with information about the rules based on the data read from XML-file.
// 
// Parameters:
//  No.
// 
// Returns:
//  InfoString - String - String with rules information.
//
Function GetInformationAboutRules(AreCorrespondentRules = False) Export
	
	// Return value of the function.
	InfoString = "";
	
	If ErrorFlag() Then
		Return InfoString;
	EndIf;
	
	If AreCorrespondentRules Then
		InfoString = NStr("en='Correspondent conversion rules (%1) from %2';ru='Правила конвертации корреспондента (%1) от %2'");
	Else
		InfoString = NStr("en='This infobase conversion rules (%1) from %2';ru='Правила конвертации этой информационной базы (%1) от %2'");
	EndIf;
	
	SourceConfigurationPresentation = GetConfigurationPresentationFromExchangeRules("Source");
	TargetConfigurationPresentation = GetConfigurationPresentationFromExchangeRules("Receiver");
	
	Return StringFunctionsClientServer.PlaceParametersIntoString(InfoString,
							SourceConfigurationPresentation,
							Format(Conversion.CreationDateTime, "DLF =DD"));
EndFunction

Function GetConfigurationPresentationFromExchangeRules(DefinitionName)
	
	ConfigurationName = "";
	Conversion.Property("ConfigurationSynonym" + DefinitionName, ConfigurationName);
	
	If Not ValueIsFilled(ConfigurationName) Then
		Return "";
	EndIf;
	
	AccurateVersion = "";
	Conversion.Property("ConfigurationVersion" + DefinitionName, AccurateVersion);
	
	If ValueIsFilled(AccurateVersion) Then
		
		AccurateVersion = CommonUseClientServer.ConfigurationVersionWithoutAssemblyNumber(AccurateVersion);
		
		ConfigurationName = ConfigurationName + " version " + AccurateVersion;
		
	EndIf;
	
	Return ConfigurationName;
	
EndFunction

// Sets mark state of the subordinate strings of
// the values tree string depending on the current string mark.
//
// Parameters:
//  CurRow      - Values tree string.
// 
Procedure SetMarksOfSubordinateOnes(CurRow, Attribute) Export

	Subordinate = CurRow.Rows;

	If Subordinate.Count() = 0 Then
		Return;
	EndIf;
	
	For Each String IN Subordinate Do
		
		If String.BuilderSettings = Undefined 
			AND Attribute = "UseFilter" Then
			
			String[Attribute] = 0;
			
		Else
			
			String[Attribute] = CurRow[Attribute];
			
		EndIf;
		
		SetMarksOfSubordinateOnes(String, Attribute);
		
	EndDo;
		
EndProcedure

Procedure FillPropertiesForSearch(DataStructure, PCR)
	
	For Each FieldsRow IN PCR Do
		
		If FieldsRow.IsFolder Then
						
			If FieldsRow.TargetKind = "TabularSection" 
				OR Find(FieldsRow.TargetKind, "RegisterRecordSet") > 0 Then
				
				RecipientStructureName = FieldsRow.Receiver + ?(FieldsRow.TargetKind = "TabularSection", "TabularSection", "RecordSet");
				
				InternalStructure = DataStructure[RecipientStructureName];
				
				If InternalStructure = Undefined Then
					InternalStructure = New Map();
				EndIf;
				
				DataStructure[RecipientStructureName] = InternalStructure;
				
			Else
				
				InternalStructure = DataStructure;	
				
			EndIf;
			
			FillPropertiesForSearch(InternalStructure, FieldsRow.GroupRules);
									
		Else
			
			If IsBlankString(FieldsRow.ReceiverType)	Then
				
				Continue;
				
			EndIf;
			
			DataStructure[FieldsRow.Receiver] = FieldsRow.ReceiverType;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure DeleteNotNeededItemsFromMap(DataStructure)
	
	For Each Item IN DataStructure Do
		
		If TypeOf(Item.Value) = MapType Then
			
			DeleteNotNeededItemsFromMap(Item.Value);
			
			If Item.Value.Count() = 0 Then
				DataStructure.Delete(Item.Key);
			EndIf;
			
		EndIf;		
		
	EndDo;		
	
EndProcedure

Procedure FillInformationByReceiverDataTypes(DataStructure, Rules)
	
	For Each String IN Rules Do
		
		If IsBlankString(String.Receiver) Then
			Continue;
		EndIf;
		
		StructureData = DataStructure[String.Receiver];
		If StructureData = Undefined Then
			
			StructureData = New Map();
			DataStructure[String.Receiver] = StructureData;
			
		EndIf;
		
		// Go through search fields and other PCR and remember data types.
		FillPropertiesForSearch(StructureData, String.SearchProperties);
				
		// Properties
		FillPropertiesForSearch(StructureData, String.Properties);
		
	EndDo;
	
	DeleteNotNeededItemsFromMap(DataStructure);	
	
EndProcedure

Procedure CreateStringWithTypesOfProperties(XMLWriter, PropertyTypes)
	
	If TypeOf(PropertyTypes.Value) = MapType Then
		
		If PropertyTypes.Value.Count() = 0 Then
			Return;
		EndIf;
		
		XMLWriter.WriteStartElement(PropertyTypes.Key);
		
		For Each Item IN PropertyTypes.Value Do
			CreateStringWithTypesOfProperties(XMLWriter, Item);
		EndDo;
		
		XMLWriter.WriteEndElement();
		
	Else		
		
		deWriteItem(XMLWriter, PropertyTypes.Key, PropertyTypes.Value);
		
	EndIf;
	
EndProcedure

Function CreateStringWithTypesForReceiver(DataStructure)
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XMLWriter.WriteStartElement("DataTypeInfo");	
	
	For Each String IN DataStructure Do
		
		XMLWriter.WriteStartElement("DataType");
		SetAttribute(XMLWriter, "Name", String.Key);
		
		For Each SubordinationRow IN String.Value Do
			
			CreateStringWithTypesOfProperties(XMLWriter, SubordinationRow);	
			
		EndDo;
		
		XMLWriter.WriteEndElement();
		
	EndDo;	
	
	XMLWriter.WriteEndElement();
	
	ResultRow = XMLWriter.Close();
	Return ResultRow;
	
EndFunction

Procedure ImportOneDataType(ExchangeRules, TypeMap, LocalItemName)
	
	NodeName = LocalItemName;
	
	ExchangeRules.Read();
	
	If (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
		
		ExchangeRules.Read();
		Return;
		
	ElsIf ExchangeRules.NodeType = XMLNodeTypeStartElement Then
			
		// this is a new item
		NewMap = New Map;
		TypeMap.Insert(NodeName, NewMap);
		
		ImportOneDataType(ExchangeRules, NewMap, ExchangeRules.LocalName);
		ExchangeRules.Read();
		
	Else
		TypeMap.Insert(NodeName, Type(ExchangeRules.Value));
		ExchangeRules.Read();
	EndIf;	
	
	ImportTypesMappingForOneType(ExchangeRules, TypeMap);
	
EndProcedure

Procedure ImportTypesMappingForOneType(ExchangeRules, TypeMap)
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			
		    Break;
			
		EndIf;
		
		// read the item beginning
		ExchangeRules.Read();
		
		If ExchangeRules.NodeType = XMLNodeTypeStartElement Then
			
			// this is a new item
			NewMap = New Map;
			TypeMap.Insert(NodeName, NewMap);
			
			ImportOneDataType(ExchangeRules, NewMap, ExchangeRules.LocalName);			
			
		Else
			TypeMap.Insert(NodeName, Type(ExchangeRules.Value));
			ExchangeRules.Read();
		EndIf;	
		
	EndDo;	
	
EndProcedure

Procedure ImportInformationAboutDataTypes()
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "DataType" Then
			
			TypeName = deAttribute(ExchangeFile, StringType, "Name");
			
			TypeMap = New Map;
			MapOfDataTypesForImport().Insert(Type(TypeName), TypeMap);

			ImportTypesMappingForOneType(ExchangeFile, TypeMap);	
			
		ElsIf (NodeName = "DataTypeInfo") AND (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;	
	
EndProcedure

Procedure ImportDataEchangeParameterValues()
	
	Name = deAttribute(ExchangeFile, StringType, "Name");
	
	PropertyType = GetPropertyTypeByAdditionalInformation(Undefined, Name);
	
	Value = ReadProperty(PropertyType);
	
	Parameters.Insert(Name, Value);	
	
	AfterParameterImportAlgorithm = "";
	If EventsAfterParameterImport.Property(Name, AfterParameterImportAlgorithm)
		AND Not IsBlankString(AfterParameterImportAlgorithm) Then
		
		If DebuggingImportHandlers Then
			
			ExecuteHandler_Parameters_AfterParameterImport(Name, Value);
			
		Else
			
			Execute(AfterParameterImportAlgorithm);
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure ImportInformationAboutCustomSearchFields()
	
	Rulename = "";
	SearchSetup = "";
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Rulename" Then
			
			Rulename = deItemValue(ExchangeFile, StringType);
			
		ElsIf NodeName = "SearchSetup" Then
			
			SearchSetup = deItemValue(ExchangeFile, StringType);
			CustomSearchFieldInfoOnDataImport.Insert(Rulename, SearchSetup);	
			
		ElsIf (NodeName = "CustomSearchSetup") AND (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;	
	
EndProcedure

// Imports exchange rules according to the format.
//
// Parameters:
//  Source       - Object from which exchange rules are imported;
//  SourceType   - String specifying source type: "XMLFile", "XMLReading", "String".
// 
Procedure ImportExchangeRules(Source="",
									SourceType="XMLFile",
									ErrorMessageString = "",
									ImportRuleHeaderOnly = False
									) Export
	//
	InitializeManagersAndMessages();
	
	HasBeforeObjectExportGlobalHandler    = False;
	HasAfterObjectExportGlobalHandler     = False;
	
	HasBeforeConvertObjectGlobalHandler = False;
	
	HasBeforeObjectImportGlobalHandler    = False;
	HasAftertObjectImportGlobalHandler     = False;
	
	CreateConversionStructure();
	
	PropertyConversionRuleTable = New ValueTable;
	PropertiesConversionRulesTableInitialization(PropertyConversionRuleTable);
	
	// Embeded exchange rules may be selected (one of the templates).
	
	ExchangeRuleTempFileName = "";
	If IsBlankString(Source) Then
		
		Source = ExchangeRulesFilename;
		
	EndIf;
	
	If SourceType="XMLFile" Then
		
		If IsBlankString(Source) Then
			ErrorMessageString = WriteInExecutionProtocol(12);
			Return; 
		EndIf;
		
		File = New File(Source);
		If Not File.Exist() Then
			ErrorMessageString = WriteInExecutionProtocol(3);
			Return; 
		EndIf;
		
		ExchangeRules = New XMLReader();
		ExchangeRules.OpenFile(Source);
		ExchangeRules.Read();
		
	ElsIf SourceType="String" Then
		
		ExchangeRules = New XMLReader();
		ExchangeRules.SetString(Source);
		ExchangeRules.Read();
		
	ElsIf SourceType="XMLReader" Then
		
		ExchangeRules = Source;
		
	EndIf;
	
	If Not ((ExchangeRules.LocalName = "ExchangeRules") AND (ExchangeRules.NodeType = XMLNodeTypeStartElement)) Then
		ErrorMessageString = WriteInExecutionProtocol(7);
		Return;
	EndIf;
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XMLWriter.WriteStartElement("ExchangeRules");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		// Conversion attributes
		If NodeName = "FormatVersion" Then
			Value = deItemValue(ExchangeRules, StringType);
			Conversion.Insert("FormatVersion", Value);
			
			XMLWriter.WriteStartElement("FormatVersion");
			Str = XMLString(Value);
			
			XMLWriter.WriteText(Str);
			XMLWriter.WriteEndElement();
			
		ElsIf NodeName = "ID" Then
			Value = deItemValue(ExchangeRules, StringType);
			Conversion.Insert("ID",                   Value);
			deWriteItem(XMLWriter, NodeName, Value);
		ElsIf NodeName = "Description" Then
			Value = deItemValue(ExchangeRules, StringType);
			Conversion.Insert("Description",         Value);
			deWriteItem(XMLWriter, NodeName, Value);
		ElsIf NodeName = "CreationDateTime" Then
			Value = deItemValue(ExchangeRules, DateType);
			Conversion.Insert("CreationDateTime",    Value);
			deWriteItem(XMLWriter, NodeName, Value);
		ElsIf NodeName = "Source" Then
			
			SourcePlatformVersion = ExchangeRules.GetAttribute ("PlatformVersion");
			SourceConfigurationSynonym = ExchangeRules.GetAttribute ("ConfigurationSynonym");
			SourceConfigurationVersion = ExchangeRules.GetAttribute ("ConfigurationVersion");
			
			Conversion.Insert("SourcePlatformVersion", SourcePlatformVersion);
			Conversion.Insert("SourceConfigurationSynonym", SourceConfigurationSynonym);
			Conversion.Insert("SourceConfigurationVersion", SourceConfigurationVersion);
			
			Value = deItemValue(ExchangeRules, StringType);
			Conversion.Insert("Source",             Value);
			deWriteItem(XMLWriter, NodeName, Value);
			
		ElsIf NodeName = "Receiver" Then
			
			TargetPlatformVersion = ExchangeRules.GetAttribute ("PlatformVersion");
			TargetConfigurationSynonym = ExchangeRules.GetAttribute ("ConfigurationSynonym");
			RecipientConfigurationVersion = ExchangeRules.GetAttribute ("ConfigurationVersion");
			
			Conversion.Insert("TargetPlatformVersion", TargetPlatformVersion);
			Conversion.Insert("TargetConfigurationSynonym", TargetConfigurationSynonym);
			Conversion.Insert("RecipientConfigurationVersion", RecipientConfigurationVersion);
			
			Value = deItemValue(ExchangeRules, StringType);
			Conversion.Insert("Receiver",             Value);
			deWriteItem(XMLWriter, NodeName, Value);
			
			If ImportRuleHeaderOnly Then
				Return;
			EndIf;
			
		ElsIf NodeName = "CompatibilityMode" Then
			// Backward compatibility support.
			deIgnore(ExchangeRules);
			
		ElsIf NodeName = "Comment" Then
			deIgnore(ExchangeRules);
			
		ElsIf NodeName = "MainExchangePlan" Then
			deIgnore(ExchangeRules);
			
		ElsIf NodeName = "Parameters" Then
			ImportParameters(ExchangeRules, XMLWriter)

		// Conversion events
		
		ElsIf NodeName = "" Then
		
		ElsIf NodeName = "AfterExchangeRuleImport" Then
			Conversion.Insert("AfterExchangeRuleImport", deItemValue(ExchangeRules, StringType));
			Conversion.Insert("ProcessorsNameAfterImportRulesExchange","Conversion_AfterObjectExport");
				
		ElsIf NodeName = "BeforeDataExport" Then
			Conversion.Insert("BeforeDataExport", deItemValue(ExchangeRules, StringType));
			Conversion.Insert("NameOfHandlerBeforeDataExport","Conversion_BeforeDataExport");
			
		ElsIf NodeName = "BeforeGetChangedObjects" Then
			Conversion.Insert("BeforeGetChangedObjects", deItemValue(ExchangeRules, StringType));
			Conversion.Insert("NameOfHandlerBeforeReceivingChangedObjects","Conversion_beforemodifiedobjectsreceiving");
			
		ElsIf NodeName = "AfterGetExchangeNodeDetails" Then
			
			Conversion.Insert("AfterGetExchangeNodeDetails", deItemValue(ExchangeRules, StringType));
			Conversion.Insert("NameOfHandlerUponReceivingInformationAboutNodesOfExchange","Conversion_aftergettinginformationaboutexchangenodes");
			deWriteItem(XMLWriter, NodeName, Conversion.AfterGetExchangeNodeDetails);
						
		ElsIf NodeName = "AfterDataExport" Then
			Conversion.Insert("AfterDataExport",  deItemValue(ExchangeRules, StringType));
			Conversion.Insert("ProcessorsNameAfterDataExport","Conversion_AfterDataExport");
			
		ElsIf NodeName = "BeforeSendDeletionInfo" Then
			Conversion.Insert("BeforeSendDeletionInfo",  deItemValue(ExchangeRules, StringType));
			Conversion.Insert("NameOfHandlerBeforeUninstallInformation","Conversion_beforesendinginformationaboutdeletion");

		ElsIf NodeName = "BeforeObjectExport" Then
			Conversion.Insert("BeforeObjectExport", deItemValue(ExchangeRules, StringType));
			Conversion.Insert("HandlerNameBeforeObjectExport","Conversion_BeforeObjectExport");
			HasBeforeObjectExportGlobalHandler = Not IsBlankString(Conversion.BeforeObjectExport);

		ElsIf NodeName = "AfterObjectExport" Then
			Conversion.Insert("AfterObjectExport", deItemValue(ExchangeRules, StringType));
			Conversion.Insert("ProcessorsNameAfterObjectExport","Conversion_AfterObjectExport");
			HasAfterObjectExportGlobalHandler = Not IsBlankString(Conversion.AfterObjectExport);

		ElsIf NodeName = "BeforeObjectImport" Then
			Conversion.Insert("BeforeObjectImport", deItemValue(ExchangeRules, StringType));
			Conversion.Insert("ProcessorsNameBeforeObjectImport","Conversion_BeforeObjectImport");
			HasBeforeObjectImportGlobalHandler = Not IsBlankString(Conversion.BeforeObjectImport);
			deWriteItem(XMLWriter, NodeName, Conversion.BeforeObjectImport);

		ElsIf NodeName = "AftertObjectImport" Then
			Conversion.Insert("AftertObjectImport", deItemValue(ExchangeRules, StringType));
			Conversion.Insert("NameOfHandlerAftertObjectImport","Conversion_AftertObjectImport");
			HasAftertObjectImportGlobalHandler = Not IsBlankString(Conversion.AftertObjectImport);
			deWriteItem(XMLWriter, NodeName, Conversion.AftertObjectImport);

		ElsIf NodeName = "BeforeObjectConversion" Then
			Conversion.Insert("BeforeObjectConversion", deItemValue(ExchangeRules, StringType));
			Conversion.Insert("ProcessorsNameBeforeObjectConversion","Conversion_BeforeObjectConversion");
			HasBeforeConvertObjectGlobalHandler = Not IsBlankString(Conversion.BeforeObjectConversion);
			
		ElsIf NodeName = "BeforeDataImport" Then
			Conversion.BeforeDataImport = deItemValue(ExchangeRules, StringType);
			Conversion.Insert("NameOfHandlerBeforeImportingData","Conversion_BeforeDataImport");
			deWriteItem(XMLWriter, NodeName, Conversion.BeforeDataImport);
			
		ElsIf NodeName = "AfterDataImport" Then
            Conversion.AfterDataImport = deItemValue(ExchangeRules, StringType);
			Conversion.Insert("NameOfHandlerAfterDataImport","Conversion_AfterDataImport");
			deWriteItem(XMLWriter, NodeName, Conversion.AfterDataImport);
			
		ElsIf NodeName = "AfterParametersImport" Then
            Conversion.Insert("AfterParametersImport", deItemValue(ExchangeRules, StringType));
			Conversion.Insert("NameOfHandlerAfterImportingSettings","Conversion_afterloadofparameters");
			deWriteItem(XMLWriter, NodeName, Conversion.AfterParametersImport);
			
		ElsIf NodeName = "OnGetDeletionInfo" Then
            Conversion.Insert("OnGetDeletionInfo", deItemValue(ExchangeRules, StringType));
			Conversion.Insert("NameOfHandlerForReceivingInformationAboutRemoving","Conversion_onobtaininginformationaboutdeletion");
			deWriteItem(XMLWriter, NodeName, Conversion.OnGetDeletionInfo);
			
		ElsIf NodeName = "DeleteMappedObjectsFromTargetOnDeleteFromSource" Then
            Conversion.DeleteMappedObjectsFromTargetOnDeleteFromSource = deItemValue(ExchangeRules, BooleanType);
						
		// Rules
		
		ElsIf NodeName = "DataUnloadRules" Then
			If ExchangeMode = "Import" Then
				deIgnore(ExchangeRules);
			Else
				ImportDumpRules(ExchangeRules);
			EndIf; 
			
		ElsIf NodeName = "ObjectConversionRules" Then
			ImportConversionRules(ExchangeRules, XMLWriter);
			
		ElsIf NodeName = "DataClearingRules" Then
			ImportClearRules(ExchangeRules, XMLWriter)
		
		ElsIf NodeName = "ObjectRegistrationRules" Then
			deIgnore(ExchangeRules);
			
		// Algorithms / Queries / DataProcessors
		
		ElsIf NodeName = "Algorithms" Then
			ImportAlgorithms(ExchangeRules, XMLWriter);
			
		ElsIf NodeName = "Queries" Then
			ImportQueries(ExchangeRules, XMLWriter);

		ElsIf NodeName = "DataProcessors" Then
			ImportDataProcessors(ExchangeRules, XMLWriter);
			
		// Exit
		ElsIf (NodeName = "ExchangeRules") AND (ExchangeRules.NodeType = XMLNodeTypeEndElement) Then
			If ExchangeMode <> "Import" Then
				ExchangeRules.Close();
			EndIf;
			Break;

			
		// Format error
		Else
			ErrorMessageString = WriteInExecutionProtocol(7);
			Return;
		EndIf;
	EndDo;
	
	XMLWriter.WriteEndElement();
	XMLRules = XMLWriter.Close();
	
	// Delete rules temporary file.
	If Not IsBlankString(ExchangeRuleTempFileName) Then
		Try
			DeleteFiles(ExchangeRuleTempFileName);
		Except 
		EndTry;
	EndIf;
	
	If ImportRuleHeaderOnly Then
		Return;
	EndIf;
	
	// Additionally information on the receiver data types is required for fast data import.
	DataStructure = New Map();
	FillInformationByReceiverDataTypes(DataStructure, ConversionRulesTable);
	
	TypesForTargetString = CreateStringWithTypesForReceiver(DataStructure);
	
	SecurityProfileName = InitializeHandlings();
	
	If SecurityProfileName <> Undefined Then
		SetSafeMode(SecurityProfileName);
	EndIf;
	
	// Call an event after you import exchange rules.
	AfterExchangeRuleImportEventText = "";
	If ExchangeMode <> "Import" AND Conversion.Property("AfterExchangeRuleImport", AfterExchangeRuleImportEventText)
		AND Not IsBlankString(AfterExchangeRuleImportEventText) Then
		
		Try
			
			If DebuggingExportHandlers Then
				
				ExecuteHandler_Conversion_AfterExchangeRuleImport();
				
			Else
				
				Execute(AfterExchangeRuleImportEventText);
				
			EndIf;
			
		Except
			ErrorMessageString = WriteInformationAboutErrorConversionHandlers(75, ErrorDescription(), NStr("en='After rules of exchange loading (conversion)';ru='ПослеЗагрузкиПравилОбмена (конвертация)'"));
			Cancel = True;
			
			If Not ContinueOnError Then
				Raise ErrorMessageString;
			EndIf;
			
		EndTry;
		
	EndIf;
	
	InitializeInitialParameterValues();
	
EndProcedure

Procedure ProcessNewItemReadEnding(LastImportObject = Undefined)
	
	IncreaseImportedObjectsCounter();
	
	If CounterOfImportedObjects() % 100 = 0
		AND GlobalNotWrittenObjectStack.Count() > 100 Then
		
		WriteNotRecordedObjects();
		
	EndIf;
	
	// When you execute import in the external connection mode, transaction is executed from the managing application.
	If Not ExecutingDataImportViaExternalConnection Then
		
		If UseTransactions
			AND ObjectsCountForTransactions > 0 
			AND CounterOfImportedObjects() % ObjectsCountForTransactions = 0 Then
			
			CommitTransaction();
			BeginTransaction();
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure DeleteObjectByRef(Ref, ErrorMessageString)
	
	Object = Ref.GetObject();
	
	If Object = Undefined Then
		Return;
	EndIf;
	
	SetDataExchangeImport(Object);
	
	If Not IsBlankString(Conversion.OnGetDeletionInfo) Then
		
		Cancel = False;
		
		Try
			
			If DebuggingImportHandlers Then
				
				ExecuteHandler_Conversion_OnGetDeletionInfo(Object, Cancel);
				
			Else
				
				Execute(Conversion.OnGetDeletionInfo);
				
			EndIf;
			
		Except
			ErrorMessageString = WriteInformationAboutErrorConversionHandlers(77, ErrorDescription(), NStr("en='WhenGettingInformationAboutDeleting (Conversion)';ru='ПриПолученииИнформацииОбУдалении (конвертация)'"));
			Cancel = True;
			
			If Not ContinueOnError Then
				Raise ErrorMessageString;
			EndIf;
			
		EndTry;
		
		If Cancel Then
			Return;
		EndIf;
		
	EndIf;
	
	DeleteObject(Object, True);
	
EndProcedure

Procedure ReadObjectDeletion(ErrorMessageString)
	
	SourceTypeAsString = deAttribute(ExchangeFile, StringType, "ReceiverType");
	ReceiverTypeAsString = deAttribute(ExchangeFile, StringType, "SourceType");
	
	UUIDString = deAttribute(ExchangeFile, StringType, "UUID");
	
	ExecuteReplacementOfUUIDIfNeeded(UUIDString, SourceTypeAsString, ReceiverTypeAsString, True);
	
	PropertyStructure = Managers[Type(SourceTypeAsString)];
	
	Ref = PropertyStructure.Manager.GetRef(New UUID(UUIDString));
	
	DeleteObjectByRef(Ref, ErrorMessageString);
	
EndProcedure

Procedure ExecuteSelectiveMessageReader(TableToImport)
	
	If TableToImport.Count() = 0 Then
		Return;
	EndIf;
	
	MessageReader = Undefined;
	Try
		
		SetFlagOfError(False);
		
		InitializeCommentsOnDumpAndDataExport();
		
		CustomSearchFieldInfoOnDataImport = New Map;
		AdditionalSearchParameterMap = New Map;
		ConversionRulesMap = New Map;
		
		// Initialize exchange protocol keeping.
		ExchangeProtocolInitialization();
		
		If CountProcessedObjectsForRefreshStatus = 0 Then
			CountProcessedObjectsForRefreshStatus = 100;
		EndIf;
		
		GlobalNotWrittenObjectStack = New Map;
		
		ImportedObjectCounterField = Undefined;
		LastSearchByRefNumber  = 0;
		
		InitializeManagersAndMessages();
		
		StartMessageReader(MessageReader, True);
		
		If UseTransactions Then
			BeginTransaction();
		EndIf;
		Try
			
			ReadDataForTables(TableToImport);
			
			If ErrorFlag() Then
				Raise NStr("en='Errors have occurred at the data import.';ru='Возникли ошибки при загрузке данных.'");
			EndIf;
			
			// Deferred record of things that were not written.
			WriteNotRecordedObjects();
			
			If ErrorFlag() Then
				Raise NStr("en='Errors have occurred at the data import.';ru='Возникли ошибки при загрузке данных.'");
			EndIf;
			
			FinishMessageReading(MessageReader);
			
			If UseTransactions Then
				CommitTransaction();
			EndIf;
		Except
			If UseTransactions Then
				RollbackTransaction();
			EndIf;
			AbortMessageReading(MessageReader);
			Raise;
		EndTry;
		
		// Post documents in the queue.
		RunDelayedDocumentPosting();
		PerformPostponedObjectsRecording();
		
	Except
		If MessageReader <> Undefined
			AND MessageReader.MessageWasAcceptedPreviously Then
			WriteInExecutionProtocol(174,,,,,,
				Enums.ExchangeExecutionResult.Warning_ExchangeMessageHasBeenPreviouslyReceived
			);
		Else
			WriteInExecutionProtocol(DetailErrorDescription(ErrorInfo()));
		EndIf;
	EndTry;
	
	FinishExchangeProtocolLogging();
	
EndProcedure

Procedure ReadData(MessageReader)
	
	ErrorMessageString = "";
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Object" Then
			
			LastImportObject = ReadObject();
			
			ProcessNewItemReadEnding(LastImportObject);
			
		ElsIf NodeName = "RegisterRecordSet" Then
			
			// register records set
			LastImportObject = ReadRegisterRecordSet();
			
			ProcessNewItemReadEnding(LastImportObject);
			
		ElsIf NodeName = "ObjectDeletion" Then
			
			// Process object removal from the infobase.
			ReadObjectDeletion(ErrorMessageString);
			
			deIgnore(ExchangeFile, "ObjectDeletion");
			
			ProcessNewItemReadEnding();
			
		ElsIf NodeName = "ObjectChangeRecordData" Then
			
			HasObjectChangeRecordData = True;
			
			LastImportObject = ReadInformationAboutObjectRegistration();
			
			ProcessNewItemReadEnding(LastImportObject);
			
		ElsIf NodeName = "ObjectChangeRecordDataAdjustment" Then
			
			HasObjectChangeRecordDataAdjustment = True;
			
			ReadInformationComparingCorrection();
			
			deIgnore(ExchangeFile, NodeName);
			
		ElsIf NodeName = "CommonNodeData" Then
			
			ReadCommonNodeData(MessageReader);
			
			deIgnore(ExchangeFile, NodeName);
			
		ElsIf (NodeName = "ExchangeFile") AND (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
			
			Break; // exit
			
		Else
			
			Raise NStr("en='Error of the exchange message format.';ru='Ошибка формата сообщения обмена.'");
			
		EndIf;
		
		// If an import error occurs, abort file reading cycle.
		If ErrorFlag() Then
			Raise NStr("en='Errors have occurred at the data import.';ru='Возникли ошибки при загрузке данных.'");
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ReadDataForTables(TableToImport)
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Object" Then
			
			ObjectTypeAsString = deAttribute(ExchangeFile, StringType, "Type");
			
			If ObjectTypeAsString = "ConstantsSet" Then
				
				ConstantName = deAttribute(ExchangeFile, StringType, "ConstantName");
				
				SourceTypeAsString = ConstantName;
				ReceiverTypeAsString = ConstantName;
				
			Else
				
				Rulename = deAttribute(ExchangeFile, StringType, "Rulename");
				
				OCR = Rules[Rulename];
				
				SourceTypeAsString = OCR.SourceType;
				ReceiverTypeAsString = OCR.ReceiverType;
				
			EndIf;
			
			DataTableKey = DataExchangeServer.DataTableKey(SourceTypeAsString, ReceiverTypeAsString, False);
			
			If TableToImport.Find(DataTableKey) <> Undefined Then
				
				If DataImportToInformationBaseMode() Then // Import to the infobase.
					
					ProcessNewItemReadEnding(ReadObject());
					
				Else // Import to the values table.
					
					UUIDString = "";
					
					LastImportObject = ReadObject(UUIDString);
					
					If LastImportObject <> Undefined Then
						
						ExchangeMessageDataTable = DataTablesOfExchangeMessage().Get(DataTableKey);
						
						TableRow = ExchangeMessageDataTable.Find(UUIDString, ColumnNameUUID());
						
						If TableRow = Undefined Then
							
							IncreaseImportedObjectsCounter();
							
							TableRow = ExchangeMessageDataTable.Add();
							
							TableRow[ColumnNameTypeAsString()]              = ReceiverTypeAsString;
							TableRow["Ref"]                            = LastImportObject.Ref;
							TableRow[ColumnNameUUID()] = UUIDString;
							
						EndIf;
						
						// Fill values of the object properties.
						FillPropertyValues(TableRow, LastImportObject);
						
					EndIf;
					
				EndIf;
				
			Else
				
				deIgnore(ExchangeFile, NodeName);
				
			EndIf;
			
		ElsIf NodeName = "RegisterRecordSet" Then
			
			If DataImportToInformationBaseMode() Then
				
				Rulename = deAttribute(ExchangeFile, StringType, "Rulename");
				
				OCR = Rules[Rulename];
				
				SourceTypeAsString = OCR.SourceType;
				ReceiverTypeAsString = OCR.ReceiverType;
				
				DataTableKey = DataExchangeServer.DataTableKey(SourceTypeAsString, ReceiverTypeAsString, False);
				
				If TableToImport.Find(DataTableKey) <> Undefined Then
					
					ProcessNewItemReadEnding(ReadRegisterRecordSet());
					
				Else
					
					deIgnore(ExchangeFile, NodeName);
					
				EndIf;
				
			Else
				
				deIgnore(ExchangeFile, NodeName);
				
			EndIf;
			
		ElsIf NodeName = "ObjectDeletion" Then
			
			ReceiverTypeAsString = deAttribute(ExchangeFile, StringType, "ReceiverType");
			SourceTypeAsString = deAttribute(ExchangeFile, StringType, "SourceType");
			
			DataTableKey = DataExchangeServer.DataTableKey(SourceTypeAsString, ReceiverTypeAsString, True);
			
			If TableToImport.Find(DataTableKey) <> Undefined Then
				
				If DataImportToInformationBaseMode() Then // Import to the infobase.
					
					// Process object removal from the infobase.
					ReadObjectDeletion("");
					
					ProcessNewItemReadEnding();
					
				Else // Import to the values table.
					
					UUIDString = deAttribute(ExchangeFile, StringType, "UUID");
					
					// Add object removal to the message data table.
					ExchangeMessageDataTable = DataTablesOfExchangeMessage().Get(DataTableKey);
					
					TableRow = ExchangeMessageDataTable.Find(UUIDString, ColumnNameUUID());
					
					If TableRow = Undefined Then
						
						IncreaseImportedObjectsCounter();
						
						TableRow = ExchangeMessageDataTable.Add();
						
						// Fill in values of all table fields with default value.
						For Each Column IN ExchangeMessageDataTable.Columns Do
							
							// filter
							If    Column.Name = ColumnNameTypeAsString()
								OR Column.Name = ColumnNameUUID()
								OR Column.Name = "Ref" Then
								Continue;
							EndIf;
							
							If Column.ValueType.ContainsType(StringType) Then
								
								TableRow[Column.Name] = NStr("en='Object removal';ru='Удаление объекта'");
								
							EndIf;
							
						EndDo;
						
						PropertyStructure = Managers[Type(ReceiverTypeAsString)];
						
						ObjectToDeleteRef = PropertyStructure.Manager.GetRef(New UUID(UUIDString));
						
						TableRow[ColumnNameTypeAsString()]              = ReceiverTypeAsString;
						TableRow["Ref"]                            = ObjectToDeleteRef;
						TableRow[ColumnNameUUID()] = UUIDString;
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
			deIgnore(ExchangeFile, NodeName);
			
		ElsIf NodeName = "ObjectChangeRecordData" Then
			
			deIgnore(ExchangeFile, NodeName); // Skip item in the message selective reading mode.
			
		ElsIf NodeName = "ObjectChangeRecordDataAdjustment" Then
			
			deIgnore(ExchangeFile, NodeName); // Skip item in the message selective reading mode.
			
		ElsIf NodeName = "CommonNodeData" Then
			
			deIgnore(ExchangeFile, NodeName); // Skip item in the message selective reading mode.
			
		ElsIf (NodeName = "ExchangeFile") AND (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
			
			Break; // exit
			
		Else
			
			Raise NStr("en='Error of the exchange message format.';ru='Ошибка формата сообщения обмена.'");
			
		EndIf;
		
		// If an error occurs, abort file reading cycle.
		If ErrorFlag() Then
			Raise NStr("en='Errors have occurred at the data import.';ru='Возникли ошибки при загрузке данных.'");
		EndIf;
		
	EndDo;
	
EndProcedure

// Classifier is a catalog, CCT, chart of accounts, CTC
// in which SynchronizeByIdentifier and ContinueSearchByFieldsIfNotFindByIdentifier check boxes are selected in OCR.
//
Function IsObjectClassifier(ObjectTypeAsString, OCR)
	
	ObjectKind = ObjectTypeAsString;
	Position = Find(ObjectKind, ".");
	If Position > 0 Then
		ObjectKind = Left(ObjectKind, Position - 1);
	EndIf;
	
	If    ObjectKind = "CatalogRef"
		Or ObjectKind = "ChartOfCharacteristicTypesRef"
		Or ObjectKind = "ChartOfAccountsRef"
		Or ObjectKind = "ChartOfCalculationTypesRef"
	Then
		Return OCR.SynchronizeByID AND OCR.SearchBySearchFieldsIfNotFoundByID
	EndIf; 
	
	Return False;
EndFunction

Procedure ReadDataInAnalysisMode(MessageReader, AnalysisParameters = Undefined)
	
	// Default parameters
	StatisticsCollectParameters = New Structure("CollectClassifiersStatistics", False);
	If AnalysisParameters <> Undefined Then
		FillPropertyValues(StatisticsCollectParameters, AnalysisParameters);
	EndIf;
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Object" Then
			
			ObjectTypeAsString = deAttribute(ExchangeFile, StringType, "Type");
			
			If ObjectTypeAsString <> "ConstantsSet" Then
				
				Rulename = deAttribute(ExchangeFile, StringType, "Rulename");
				OCR        = Rules[Rulename];
				
				If StatisticsCollectParameters.CollectClassifiersStatistics AND IsObjectClassifier(ObjectTypeAsString, OCR) Then
					// New behavior
					CollectStatistics = True;
					IsClassifier   = True;
					
				ElsIf Not (OCR.SynchronizeByID AND OCR.SearchBySearchFieldsIfNotFoundByID) AND OCR.SynchronizeByID Then
					// Compatibility branch.
					// Objects for which the automatic match is executed during exchange (classifiers) are not displayed to a user in statistics information table. Therefore, statistics information collection is
					// not required for them.

					// Also objects are not displayed that are identified by the search fields
					// and not by ref unique identifier.
					CollectStatistics = True;
					IsClassifier   = False;
					
				Else 
					CollectStatistics = False;
					
				EndIf;
				
				If CollectStatistics Then
					TableRow = DataTableOfPackageHeader().Add();
					
					TableRow.ObjectTypeAsString = ObjectTypeAsString;
					TableRow.ObjectsCountInSource = 1;
					
					TableRow.ReceiverTypeAsString = OCR.ReceiverType;
					TableRow.SourceTypeAsString = OCR.SourceType;
					
					TableRow.SearchFields  = ObjectsMappingMechanismSearchFields(OCR.SearchFields);
					TableRow.TableFields = OCR.TableFields;
					
					TableRow.SynchronizeByID    = OCR.SynchronizeByID;
					TableRow.UsePreview = OCR.SynchronizeByID;
					TableRow.IsClassifier   = IsClassifier;
					TableRow.ThisIsObjectDeletion = False;

				EndIf;
				
			EndIf;
			
			deIgnore(ExchangeFile, NodeName);
			
		ElsIf NodeName = "RegisterRecordSet" Then
			
			deIgnore(ExchangeFile, NodeName);
			
		ElsIf NodeName = "ObjectDeletion" Then
			
			TableRow = DataTableOfPackageHeader().Add();
			
			TableRow.ReceiverTypeAsString = deAttribute(ExchangeFile, StringType, "ReceiverType");
			TableRow.SourceTypeAsString = deAttribute(ExchangeFile, StringType, "SourceType");
			
			TableRow.ObjectTypeAsString = TableRow.ReceiverTypeAsString;
			
			TableRow.ObjectsCountInSource = 1;
			
			TableRow.SynchronizeByID = False;
			TableRow.UsePreview = True;
			TableRow.IsClassifier = False;
			TableRow.ThisIsObjectDeletion = True;
			
			TableRow.SearchFields = ""; // Search fields will be assigned in the constructor of objects match processor.
			
			// Determine values for
			// the TableFields column, receive description of all metadata object fields from configuration.
			ObjectType = Type(TableRow.ObjectTypeAsString);
			MetadataObject = Metadata.FindByType(ObjectType);
			
			SubstringArray = TableOfDescriptionOfObjectProperties(MetadataObject).UnloadColumn("Name");
			
			// Delete the "Ref" field from the visual table fields.
			CommonUseClientServer.DeleteValueFromArray(SubstringArray, "Ref");
			
			TableRow.TableFields = StringFunctionsClientServer.RowFromArraySubrows(SubstringArray);
			
			deIgnore(ExchangeFile, NodeName);
			
		ElsIf NodeName = "ObjectChangeRecordData" Then
			
			HasObjectChangeRecordData = True;
			
			LastImportObject = ReadInformationAboutObjectRegistration();
			
			ProcessNewItemReadEnding(LastImportObject);
			
		ElsIf NodeName = "ObjectChangeRecordDataAdjustment" Then
			
			HasObjectChangeRecordDataAdjustment = True;
			
			ReadInformationComparingCorrection();
			
			deIgnore(ExchangeFile, NodeName);
			
		ElsIf NodeName = "CommonNodeData" Then
			
			ReadCommonNodeData(MessageReader);
			
			deIgnore(ExchangeFile, NodeName);
			
		ElsIf (NodeName = "ExchangeFile") AND (ExchangeFile.NodeType = XMLNodeType.EndElement) Then
			
			Break; // Exit
			
		Else
			
			Raise NStr("en='Error of the exchange message format.';ru='Ошибка формата сообщения обмена.'");
			
		EndIf;
		
		// If an error occurs, abort file reading cycle.
		If ErrorFlag() Then
			Raise NStr("en='The errors occurred when analysing the data.';ru='Возникли ошибки при анализе данных.'");
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ReadDataInModeExternalConnection(MessageReader)
	
	ErrorMessageString = "";
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Object" Then
			
			LastImportObject = ReadObject();
			
			ProcessNewItemReadEnding(LastImportObject);
			
		ElsIf NodeName = "RegisterRecordSet" Then
			
			// register records set
			LastImportObject = ReadRegisterRecordSet();
			
			ProcessNewItemReadEnding(LastImportObject);
			
		ElsIf NodeName = "ObjectDeletion" Then
			
			// Process object removal from the infobase.
			ReadObjectDeletion(ErrorMessageString);
			
			deIgnore(ExchangeFile, "ObjectDeletion");
			
			ProcessNewItemReadEnding();
			
		ElsIf NodeName = "ObjectChangeRecordData" Then
			
			HasObjectChangeRecordData = True;
			
			LastImportObject = ReadInformationAboutObjectRegistration();
			
			ProcessNewItemReadEnding(LastImportObject);
			
		ElsIf NodeName = "CustomSearchSetup" Then
			
			ImportInformationAboutCustomSearchFields();
			
		ElsIf NodeName = "DataTypeInfo" Then
			
			If MapOfDataTypesForImport().Count() > 0 Then
				
				deIgnore(ExchangeFile, NodeName);
				
			Else
				ImportInformationAboutDataTypes();
			EndIf;
			
		ElsIf NodeName = "ParameterValue" Then	
			
			ImportDataEchangeParameterValues();
			
		ElsIf NodeName = "AfterParameterExportAlgorithm" Then
			
			Cancel = False;
			CancelReason = "";
			
			AlgorithmText = deItemValue(ExchangeFile, StringType);
			
			If Not IsBlankString(AlgorithmText) Then
				
				Try
					
					If DebuggingImportHandlers Then
						
						ExecuteHandler_Conversion_AfterParametersImport(ExchangeFile, Cancel, CancelReason);
						
					Else
						
						Execute(AlgorithmText);
						
					EndIf;
					
					If Cancel = True Then
						
						If Not IsBlankString(CancelReason) Then
							
							MessageString = NStr("en='Data load canceled because: %1';ru='Загрузка данных отменена по причине: %1'");
							MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, CancelReason);
							Raise MessageString;
						Else
							Raise NStr("en='Data import is canceled';ru='Загрузка данных отменена'");
						EndIf;
						
					EndIf;
					
				Except
					
					LR = GetProtocolRecordStructure(78, ErrorDescription());
					LR.Handler     = "AfterParametersImport";
					ErrorMessageString = WriteInExecutionProtocol(78, LR, True);
					
					If Not ContinueOnError Then
						Raise ErrorMessageString;
					EndIf;
					
				EndTry;
				
			EndIf;
			
		ElsIf NodeName = "ExchangeData" Then
			
			ReadExchangeData(MessageReader, False);
			
			deIgnore(ExchangeFile, NodeName);
			
			If ErrorFlag() Then
				Break;
			EndIf;
			
		ElsIf NodeName = "CommonNodeData" Then
			
			ReadCommonNodeData(Undefined);
			
			deIgnore(ExchangeFile, NodeName);
			
			If ErrorFlag() Then
				Break;
			EndIf;
			
		ElsIf NodeName = "ObjectChangeRecordDataAdjustment" Then
			
			ReadInformationComparingCorrection();
			
			HasObjectChangeRecordDataAdjustment = True;
			
			deIgnore(ExchangeFile, NodeName);
			
		ElsIf (NodeName = "ExchangeFile") AND (ExchangeFile.NodeType = XMLNodeTypeEndElement) Then
			
			Break; // exit
			
		Else
			
			deIgnore(ExchangeFile, NodeName);
			
		EndIf;
		
		// If an import error occurs, abort file reading cycle.
		If ErrorFlag() Then
			Break;
		EndIf;
		
	EndDo;
		
EndProcedure

Procedure ReadExchangeData(MessageReader, DataAnalysis)
	
	ExchangePlanNameField           = deAttribute(ExchangeFile, StringType, "ExchangePlan");
	FromWhomCode                    = deAttribute(ExchangeFile, StringType, "FromWhom");
	MessageNumberField           = deAttribute(ExchangeFile, NumberType,  "OutboundMessageNumber");
	ReceivedMessageNumberField  = deAttribute(ExchangeFile, NumberType,  "IncomingMessageNumber");
	DeleteChangeRecords  = deAttribute(ExchangeFile, BooleanType, "DeleteChangeRecords");
	SenderVersion            = deAttribute(ExchangeFile, StringType, "SenderVersion");
	
	ExchangeNodeRecipient = ExchangePlans[ExchangePlanName()].FindByCode(FromWhomCode);
	
	// Check whether there
	// is receiver node check and whether receiver node is specified correctly in the exchange message.
	If Not ValueIsFilled(ExchangeNodeRecipient)
		OR ExchangeNodeRecipient <> ExchangeNodeForDataImport Then
		
		MessageString = NStr("en='The node of exchange to import data is not found. Exchange plan: %1, Code: %2';ru='Не найден узел обмена для загрузки данных. План обмена: %1, Код: %2'");
		MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, ExchangePlanName(), FromWhomCode);
		Raise MessageString;
	EndIf;
	
	MessageReader = New Structure("MessageNo, ReceivedNo, Sender, SenderObject, MessageWasAcceptedPreviously, DataAnalysis");
	MessageReader.Sender       = ExchangeNodeRecipient;
	MessageReader.SenderObject = ExchangeNodeRecipient.GetObject();
	MessageReader.MessageNo    = MessageNumberField;
	MessageReader.ReceivedNo    = ReceivedMessageNumberField;
	MessageReader.MessageWasAcceptedPreviously = False;
	MessageReader.DataAnalysis = DataAnalysis;
	MessageReader = New FixedStructure(MessageReader);
	
	RestoredBackupCopy = (MessageReader.ReceivedNo > CommonUse.ObjectAttributeValue(MessageReader.Sender, "SentNo"));
	
	If DataImportToInformationBaseMode() Then
		
		BeginTransaction();
		ReceivedNo = CommonUse.ObjectAttributeValue(MessageReader.Sender, "ReceivedNo");
		CommitTransaction();
		
		If ReceivedNo >= MessageReader.MessageNo Then // Message number is either smaller or equals to the previously accepted one.
			
			MessageReadingTemporary = CommonUseClientServer.CopyStructure(MessageReader);
			MessageReadingTemporary.MessageWasAcceptedPreviously = True;
			MessageReader = New FixedStructure(MessageReadingTemporary);
			
			Raise NStr("en='Exchange message has been previously accepted';ru='Сообщение обмена было принято ранее'");
		EndIf;
		
		DeleteChangeRecords = DeleteChangeRecords AND Not RestoredBackupCopy;
		
		If DeleteChangeRecords Then // Delete registration of changes.
			
			If TransactionActive() Then
				Raise NStr("en='Deletion of the data modification registration can not be done in the active transaction.';ru='Удаление регистрации изменений данных не может быть выполнено в активной транзакции.'");
			EndIf;
			
			ExchangePlans.DeleteChangeRecords(MessageReader.Sender, MessageReader.ReceivedNo);
			
			InformationRegisters.NodesCommonDataChange.DeleteChangeRecords(MessageReader.Sender, MessageReader.ReceivedNo);
			
			If CommonUseClientServer.CompareVersions(VersionOfIncomeExchangeEventFormat(), "3.1.0.0") >= 0 Then
				
				InformationRegisters.InfobasesNodesCommonSettings.CommitCorrectionExecutionOfInformationMatching(MessageReader.Sender, MessageReader.ReceivedNo);
				
			EndIf;
			
			InformationRegisters.InfobasesNodesCommonSettings.ClearInitialDataExportFlag(MessageReader.Sender, MessageReader.ReceivedNo);
			
		EndIf;
		
		If RestoredBackupCopy Then
			
			MessageReader.SenderObject.SentNo = MessageReader.ReceivedNo;
			MessageReader.SenderObject.DataExchange.Load = True;
			MessageReader.SenderObject.Write();
			
			MessageReadingTemporary = CommonUseClientServer.CopyStructure(MessageReader);
			MessageReadingTemporary.SenderObject = MessageReader.Sender.GetObject();
			MessageReader = New FixedStructure(MessageReadingTemporary);
		EndIf;
		
		InformationRegisters.InfobasesNodesCommonSettings.SetVersionOfCorrespondent(MessageReader.Sender, SenderVersion);
		
	EndIf;
	
	// {Handler: AfterReceiveInformationAboutExchangeNodes} Start
	If Not IsBlankString(Conversion.AfterGetExchangeNodeDetails) Then
		
		Try
			
			If DebuggingImportHandlers Then
				
				ExecuteHandler_Conversion_AfterGetExchangeNodeDetails(MessageReader.Sender);
				
			Else
				
				Execute(Conversion.AfterGetExchangeNodeDetails);
				
			EndIf;
			
		Except
			Raise WriteInformationAboutErrorConversionHandlers(176, ErrorDescription(), NStr("en='AfterReceivingInformationAboutExchangeNodes (conversion)';ru='ПослеПолученияИнформацииОбУзлахОбмена (конвертация)'"));
		EndTry;
		
	EndIf;
	// {Handler: AfterReceiveInformationAboutExchangeNodes} End
	
EndProcedure

Procedure ReadCommonNodeData(MessageReader)
	
	ExchangeFile.Read();
	
	DataImportModePrevious = DataImportMode;
	
	DataImportMode = "ImportToValueTable";
	
	CommonNode = ReadObject();
	
	IncreaseImportedObjectsCounter();
	
	DataImportMode = DataImportModePrevious;
	
	// {Handler: AtReceivingSenderData} Begin
	Ignore = False;
	
	ExchangePlans[CommonNode.Metadata().Name].OnSendersDataGet(CommonNode, Ignore);
	
	If Ignore = True Then
		Return;
	EndIf;
	// {Handler: AtReceivingSenderData} End
	
	If DataExchangeEvents.DataDifferent(CommonNode, CommonNode.Ref.GetObject()) Then
		
		BeginTransaction();
		Try
			
			CommonNode.DataExchange.Load = True;
			CommonNode.Write();
			
			// Update reused mechanism values.
			DataExchangeServerCall.ResetCacheMechanismForRegistrationOfObjects();
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
		OpenTransaction = False;
		If TransactionActive() Then
			CommitTransaction();
			OpenTransaction = True;
		EndIf;
		
		// Delete changes registration if changes are registered earlier (in case of changes collision).
		InformationRegisters.NodesCommonDataChange.DeleteChangeRecords(CommonNode.Ref);
		
		If OpenTransaction Then
			BeginTransaction();
		EndIf;
		
		If MessageReader <> Undefined
			AND CommonNode.Ref = MessageReader.Sender Then
			
			MessageReadingTemporary = CommonUseClientServer.CopyStructure(MessageReader);
			MessageReadingTemporary.SenderObject = MessageReader.Sender.GetObject();
			MessageReader = New FixedStructure(MessageReadingTemporary);
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure RunDelayedDocumentPosting()
	
	If DocumentsForDelayedPosting().Count() = 0 Then
		Return // no documents in the queue
	EndIf;
	
	// Collapse table by  unique fields.
	DocumentsForDelayedPosting().GroupBy("DocumentRef, DocumentDate");
	
	// Sort documents by ascending order of document dates.
	DocumentsForDelayedPosting().Sort("DocumentDate");
	
	For Each TableRow IN DocumentsForDelayedPosting() Do
		
		DocumentRef = TableRow.DocumentRef;
		
		If DocumentRef.IsEmpty() Then
			Continue;
		EndIf;
		
		Object = DocumentRef.GetObject();
		
		If Object = Undefined Then
			Continue;
		EndIf;
		
		// Set a sender node to prevent the object from being registered
		// on the node for which importing is run, posting should not be in the import mode.
		SetDataExchangeImport(Object, False);
		
		ErrorDescription = "";
		DocumentPostedSuccessfully = False;
		
		Try
			
			AdditionalProperties = AdditionalPropertiesForDeferredPosting().Get(DocumentRef);
			
			For Each Property IN AdditionalProperties Do
				
				Object.AdditionalProperties.Insert(Property.Key, Property.Value);
				
			EndDo;
			
			Object.AdditionalProperties.Insert("DeferredPosting");
			
			If Object.CheckFilling() Then
				
				// When you post the document, remove a
				// ban on the PRO execution as PRO were ignored on the regular document write to optimize the speed of the data import.
				If Object.AdditionalProperties.Property("DisableObjectChangeRecordMechanism") Then
					Object.AdditionalProperties.Delete("DisableObjectChangeRecordMechanism");
				EndIf;
				
				DataExchangeServer.SkipChangeProhibitionCheck();
				Object.AdditionalProperties.Insert("SkipChangeProhibitionCheck");
				
				InfoAboutObjectVersion = New Structure;
				InfoAboutObjectVersion.Insert("PostponedProcessing", True);
				InfoAboutObjectVersion.Insert("ObjectVersioningType", "ChangedByUser");
				InfoAboutObjectVersion.Insert("VersionAuthor", ExchangeNodeForDataImport);
				Object.AdditionalProperties.Insert("InfoAboutObjectVersion", InfoAboutObjectVersion);
				
				// Trying to post the document
				Object.Write(DocumentWriteMode.Posting);
				
				DocumentPostedSuccessfully = Object.Posted;
				
			Else
				
				DocumentPostedSuccessfully = False;
				
			EndIf;
			
		Except
			
			ErrorDescription = BriefErrorDescription(ErrorInfo());
			
			DocumentPostedSuccessfully = False;
			
		EndTry;
		
		DataExchangeServer.SkipChangeProhibitionCheck(False);
		
		If Not DocumentPostedSuccessfully Then
			
			DataExchangeServer.RegisterErrorDocument(Object, ExchangeNodeForDataImport, ErrorDescription);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure PerformPostponedObjectsRecording()
	
	If ObjectsForPostponedRecording().Count() = 0 Then
		Return // No objects in the queue
	EndIf;
	
	For Each MappingObject IN ObjectsForPostponedRecording() Do
		
		If MappingObject.Key.IsEmpty() Then
			Continue;
		EndIf;
		
		Object = MappingObject.Key.GetObject();
		
		If Object = Undefined Then
			Continue;
		EndIf;
		
		// Set a sender node to prevent the object from being registered
		// on the node for which importing is run, posting should not be in the import mode.
		SetDataExchangeImport(Object, False);
		
		ErrorDescription = "";
		ObjectSuccessfulyRecorded = False;
		
		Try
			
			AdditionalProperties = MappingObject.Value;
			
			For Each Property IN AdditionalProperties Do
				
				Object.AdditionalProperties.Insert(Property.Key, Property.Value);
				
			EndDo;
			
			Object.AdditionalProperties.Insert("WriteBack");
			
			If Object.CheckFilling() Then
				
				// When you post the document, remove a
				// ban on the PRO execution as PRO were ignored during the regular write to optimize the speed of the data import.
				If Object.AdditionalProperties.Property("DisableObjectChangeRecordMechanism") Then
					Object.AdditionalProperties.Delete("DisableObjectChangeRecordMechanism");
				EndIf;
				
				DataExchangeServer.SkipChangeProhibitionCheck();
				Object.AdditionalProperties.Insert("SkipChangeProhibitionCheck");
				
				InfoAboutObjectVersion = New Structure;
				InfoAboutObjectVersion.Insert("PostponedProcessing", True);
				InfoAboutObjectVersion.Insert("ObjectVersioningType", "ChangedByUser");
				InfoAboutObjectVersion.Insert("VersionAuthor", ExchangeNodeForDataImport);
				Object.AdditionalProperties.Insert("InfoAboutObjectVersion", InfoAboutObjectVersion);
				
				// Try to write the object.
				Object.Write();
				
				ObjectSuccessfulyRecorded = True;
				
			Else
				
				ObjectSuccessfulyRecorded = False;
				
				ErrorDescription = NStr("en='Error of attributes filling verification';ru='Ошибка проверки заполнения реквизитов'");
				
			EndIf;
			
		Except
			
			ErrorDescription = BriefErrorDescription(ErrorInfo());
			
			ObjectSuccessfulyRecorded = False;
			
		EndTry;
		
		DataExchangeServer.SkipChangeProhibitionCheck(False);
		
		If Not ObjectSuccessfulyRecorded Then
			
			DataExchangeServer.RegisterErrorRecordsObject(Object, ExchangeNodeForDataImport, ErrorDescription);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure WriteInformationAboutDataExchangeViaExchangePlans(Val SentNo)
	
	Receiver = CreateNode("ExchangeData");
	
	SetAttribute(Receiver, "ExchangePlan", ExchangePlanName());
	SetAttribute(Receiver, "Whom",   NodeForExchange.Code);
	SetAttribute(Receiver, "FromWhom", ExchangePlans[ExchangePlanName()].ThisNode().Code);
	
	// Attributes of exchange message handshaking mechanism.
	SetAttribute(Receiver, "OutboundMessageNumber", SentNo);
	SetAttribute(Receiver, "IncomingMessageNumber",  NodeForExchange.ReceivedNo);
	SetAttribute(Receiver, "DeleteChangeRecords", True);
	
	SetAttribute(Receiver, "SenderVersion", TrimAll(Metadata.Version));
	
	// Write object to file
	Receiver.WriteEndElement();
	
	WriteToFile(Receiver);
	
EndProcedure

Procedure ExportCommonNodeData(Val SentNo)
	
	NodeChangesSelection = InformationRegisters.NodesCommonDataChange.SelectChanges(NodeForExchange, SentNo);
	
	If NodeChangesSelection.Count() = 0 Then
		Return;
	EndIf;
	
	ExchangePlanName = DataExchangeReUse.GetExchangePlanName(NodeForExchange);
	
	CommonNodeData = DataExchangeReUse.CommonNodeData(NodeForExchange);
	
	If IsBlankString(CommonNodeData) Then
		Return;
	EndIf;
	
	PropertyConversionRules = New ValueTable;
	PropertiesConversionRulesTableInitialization(PropertyConversionRules);
	
	Properties       = PropertyConversionRules.Copy();
	SearchProperties = PropertyConversionRules.Copy();
	
	CommonNodeMetadata = Metadata.ExchangePlans[ExchangePlanName];
	
	CommonNodeTabularSections = DataExchangeEvents.ObjectTabularSections(CommonNodeMetadata);
	
	CommonNodeProperties = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(CommonNodeData);
	
	For Each Property IN CommonNodeProperties Do
		
		If CommonNodeTabularSections.Find(Property) <> Undefined Then
			
			PCR = Properties.Add();
			PCR.IsFolder = True;
			PCR.SourceKind = "TabularSection";
			PCR.TargetKind = "TabularSection";
			PCR.Source = Property;
			PCR.Receiver = Property;
			PCR.GroupRules = PropertyConversionRules.Copy();
			
			For Each Attribute IN CommonNodeMetadata.TabularSections[Property].Attributes Do
				
				PGCR = PCR.GroupRules.Add();
				PGCR.IsFolder = False;
				PGCR.SourceKind = "Attribute";
				PGCR.TargetKind = "Attribute";
				PGCR.Source = Attribute.Name;
				PGCR.Receiver = Attribute.Name;
				
			EndDo;
			
		Else
			
			PCR = Properties.Add();
			PCR.IsFolder = False;
			PCR.SourceKind = "Attribute";
			PCR.TargetKind = "Attribute";
			PCR.Source = Property;
			PCR.Receiver = Property;
			
		EndIf;
		
	EndDo;
	
	PCR = SearchProperties.Add();
	PCR.SourceKind = "Property";
	PCR.TargetKind = "Property";
	PCR.Source = "Code";
	PCR.Receiver = "Code";
	PCR.SourceType = "String";
	PCR.ReceiverType = "String";
	
	OCR = ConversionRulesTable.Add();
	OCR.SynchronizeByID = False;
	OCR.SearchBySearchFieldsIfNotFoundByID = False;
	OCR.DontExportPropertyObjectsByRefs = True;
	OCR.SourceType = "ExchangePlanRef." + ExchangePlanName;
	OCR.Source = Type(OCR.SourceType);
	OCR.ReceiverType = OCR.SourceType;
	OCR.Receiver     = OCR.SourceType;
	
	OCR.Properties = Properties;
	OCR.SearchProperties = SearchProperties;
	
	CommonNode = ExchangePlans[ExchangePlanName].CreateNode();
	DataExchangeEvents.FillObjectPropertiesValues(CommonNode, NodeForExchange.GetObject(), CommonNodeData);
	
	// {Handler: OnSendingSenderData} Start
	Ignore = False;
	
	ExchangePlans[CommonNode.Metadata().Name].OnDataSendingSender(CommonNode, Ignore);
	
	If Ignore = True Then
		Return;
	EndIf;
	// {Handler: OnSendingSenderData} End
	
	CommonNode.Code = DataExchangeReUse.GetThisNodeCodeForExchangePlan(ExchangePlanName);
	
	XMLNode = CreateNode("CommonNodeData");
	
	DumpByRule(CommonNode,,,,,,, OCR,,, XMLNode);
	
	XMLNode.WriteEndElement();
	
	WriteToFile(XMLNode);
	
EndProcedure

Function DumpReferenceObjectData(Value, OutgoingData, OCRName, OCRProperties, ReceiverType, Propirtiesnode, Val ExportRefOnly)
	
	IsRuleWithGlobalExport = False;
	Referencenode    = DumpByRule(Value, , OutgoingData, , OCRName, , ExportRefOnly, OCRProperties, IsRuleWithGlobalExport, , , , False);
	RefNodeType = TypeOf(Referencenode);

	If IsBlankString(ReceiverType) Then
				
		ReceiverType  = OCRProperties.Receiver;
		SetAttribute(Propirtiesnode, "Type", ReceiverType);
				
	EndIf;
			
	If Referencenode = Undefined Then
				
		Return Undefined;
				
	EndIf;
				
	AddPropertiesForDump(Referencenode, RefNodeType, Propirtiesnode, IsRuleWithGlobalExport);	
	
	Return Referencenode;
	
EndFunction

Procedure PassOneParameterToReceiver(Name, InitialParameterValue, ConversionRule = "")
	
	If IsBlankString(ConversionRule) Then
		
		ParameterNode = CreateNode("ParameterValue");
		
		SetAttribute(ParameterNode, "Name", Name);
		SetAttribute(ParameterNode, "Type", deValueTypeAsString(InitialParameterValue));
		
		IsNULL = False;
		Empty = deBlank(InitialParameterValue, IsNULL);
		
		If Empty Then
			
			// You should note that this value is empty.
			deWriteItem(ParameterNode, "Empty");
			
			ParameterNode.WriteEndElement();
			
			WriteToFile(ParameterNode);
			
			Return;
			
		EndIf;
		
		deWriteItem(ParameterNode, "Value", InitialParameterValue);
		
		ParameterNode.WriteEndElement();
		
		WriteToFile(ParameterNode);
		
	Else
		
		ParameterNode = CreateNode("ParameterValue");
		
		SetAttribute(ParameterNode, "Name", Name);
		
		IsNULL = False;
		Empty = deBlank(InitialParameterValue, IsNULL);
		
		If Empty Then
			
			OCRProperties = FindRule(InitialParameterValue, ConversionRule);
			ReceiverType  = OCRProperties.Receiver;
			SetAttribute(ParameterNode, "Type", ReceiverType);
			
			// You should note that this value is empty.
			deWriteItem(ParameterNode, "Empty");
			
			ParameterNode.WriteEndElement();
			
			WriteToFile(ParameterNode);
			
			Return;
			
		EndIf;
		
		DumpReferenceObjectData(InitialParameterValue, , ConversionRule, , , ParameterNode, True);
		
		ParameterNode.WriteEndElement();
		
		WriteToFile(ParameterNode);
		
	EndIf;
	
EndProcedure

Procedure PassAdditionalParametersToReceiver()
	
	For Each Parameter IN ParametersSettingsTable Do
		
		If Parameter.PassParameterOnExport = True Then
			
			PassOneParameterToReceiver(Parameter.Name, Parameter.Value, Parameter.ConversionRule);
					
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure PassInformationAboutTypesToReceiver()
	
	If Not IsBlankString(TypesForTargetString) Then
		WriteToFile(TypesForTargetString);
	EndIf;
		
EndProcedure

Procedure PassInformationAboutCustomSearchFieldsToReceiver()
	
	For Each MapKeyAndValue IN CustomSearchFieldInfoOnDataExport Do
		
		ParameterNode = CreateNode("CustomSearchSetup");
		
		deWriteItem(ParameterNode, "Rulename", MapKeyAndValue.Key);
		deWriteItem(ParameterNode, "SearchSetup", MapKeyAndValue.Value);
		
		ParameterNode.WriteEndElement();
		WriteToFile(ParameterNode);
		
	EndDo;
	
EndProcedure

Procedure InitializeCommentsOnDumpAndDataExport()
	
	CommentDuringDataExport = "";
	CommentDuringDataImport = "";
	
EndProcedure

Procedure ExportedObjectsByRefAddValue(Value)
	
	If ExportedObjectsByRef().Find(Value) = Undefined Then
		
		ExportedObjectsByRef().Add(Value);
		
	EndIf;
	
EndProcedure

Function ObjectPassingFilterOfAllowedObjects(Value)
	
	Return InformationRegisters.InfobasesObjectsCompliance.ObjectIsInRegister(Value, NodeForExchange);
	
EndFunction

Function ObjectsMappingMechanismSearchFields(Val SearchFields)
	
	SearchFieldsCollection = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(SearchFields);
	
	CommonUseClientServer.DeleteValueFromArray(SearchFieldsCollection, "IsFolder");
	
	Return StringFunctionsClientServer.RowFromArraySubrows(SearchFieldsCollection);
EndFunction

//

Procedure RunExport(ErrorMessageString = "")
	
	ExchangePlanNameField = DataExchangeReUse.GetExchangePlanName(NodeForExchange);
	
	ExportMappingInformation = ExportObjectMappingInformation(NodeForExchange);
	
	InitializeCommentsOnDumpAndDataExport();
	
	CurrentNestingLevelExportByRule = 0;
	
	DataExportCallStack = New ValueTable;
	DataExportCallStack.Columns.Add("Ref");
	DataExportCallStack.Indexes.Add("Ref");
	
	InitializeManagersAndMessages();
	
	ExportedObjectCounterField = Undefined;
	SnCounter 				= 0;
	WrittenToFileNPP		= 0;
	
	For Each Rule IN ConversionRulesTable Do
		
		Rule.Exported = CreateDumpedObjectsTable();
		
	EndDo;
	
	// Receive metadata object types that will participate in export.
	UsedUnloadRulesTable = UnloadRulesTable.Copy(New Structure("Enable", True));
	
	For Each TableRow IN UsedUnloadRulesTable Do
		
		If Not TableRow.SelectionObject = Type("ConstantsSet") Then
			
			TableRow.SelectionObjectMetadata = Metadata.FindByType(TableRow.SelectionObject);
			
		EndIf;
		
	EndDo;
	
	DataMapForExportedItemUpdate = New Map;
	
	// {HANDLER BeforeDataExport}
	Cancel = False;
	
	If Not IsBlankString(Conversion.BeforeDataExport) Then
		
		Try
			
			If DebuggingExportHandlers Then
				
				ExecuteHandler_Conversion_BeforeDataExport(ExchangeFile, Cancel);
				
			Else
				
				Execute(Conversion.BeforeDataExport);
				
			EndIf;
			
		Except
			WriteInformationAboutErrorConversionHandlers(62, ErrorDescription(), NStr("en='BeforeDataExport (conversion)';ru='ПередВыгрузкойДанных (конвертация)'"));
			Cancel = True;
		EndTry; 
		
		If Cancel Then // Denial of the data export
			FinishExchangeProtocolLogging();
			Return;
		EndIf;
		
	EndIf;
	// {HANDLER BeforeDataExport}
	
	PassInformationAboutCustomSearchFieldsToReceiver();
	
	PassInformationAboutTypesToReceiver();
	
	// Pass additional parameters to receiver.
	PassAdditionalParametersToReceiver();
	
	EventTextAfterParameterImport = "";
	If Conversion.Property("AfterParametersImport", EventTextAfterParameterImport)
		AND Not IsBlankString(EventTextAfterParameterImport) Then
		
		WritingEvent = New XMLWriter;
		WritingEvent.SetString();
		deWriteItem(WritingEvent, "AfterParameterExportAlgorithm", EventTextAfterParameterImport);
		
		WriteToFile(WritingEvent);
		
	EndIf;
	
	SentNo = CommonUse.ObjectAttributeValue(NodeForExchange, "SentNo") + ?(ExportMappingInformation, 2, 1);
	
	WriteInformationAboutDataExchangeViaExchangePlans(SentNo);
	
	ExportCommonNodeData(SentNo);
	
	Cancel = False;
	
	// EXPORT MATCH REGISTER
	If ExportMappingInformation Then
		
		XMLWriter = New XMLWriter;
		XMLWriter.SetString();
		WriteMessage = ExchangePlans.CreateMessageWriter();
		WriteMessage.BeginWrite(XMLWriter, NodeForExchange);
		
		Try
			RunDumpOfObjectMappingRegister(WriteMessage, ErrorMessageString);
		Except
			Cancel = True;
		EndTry;
		
		If Cancel Then
			WriteMessage.CancelWrite();
		Else
			WriteMessage.EndWrite();
		EndIf;
		
		XMLWriter.Close();
		XMLWriter = Undefined;
		
		If Cancel Then
			Return;
		EndIf;
		
	EndIf;
	
	// EXPORT MATCH REGISTER ADJUSTMENT
	If NeedToExecuteCorrectionOfMappingInformation() Then
		
		ExportInformationComparingCorrection();
		
	EndIf;
	
	// EXPORT REGISTERED DATA
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	WriteMessage = ExchangePlans.CreateMessageWriter();
	WriteMessage.BeginWrite(XMLWriter, NodeForExchange);
	
	Try
		RunDumpOfRegisteredData(WriteMessage, ErrorMessageString, UsedUnloadRulesTable);
	Except
		Cancel = True;
		WriteInExecutionProtocol(DetailErrorDescription(ErrorInfo()));
		
		If IsExchangeOverExternalConnection() Then
			
			If DataImportExecutedInExternalConnection Then
				
				While ExternalConnection.TransactionActive() Do
					ExternalConnection.RollbackTransaction();
				EndDo;
				
			Else
				
				DataProcessorForDataImport().ExternalConnectionRollbackTransactionOnDataImport();
				
			EndIf;
			
		EndIf;
		
	EndTry;
	
	// Register objects exported by the reference on the current node.
	For Each Item IN ExportedObjectsByRef() Do
		
		ExchangePlans.RecordChanges(WriteMessage.Recipient, Item);
		
	EndDo;
	
	// Assign a number of the sent message for objects exported by reference.
	If ExportedObjectsByRef().Count() > 0 Then
		
		DataExchangeServer.SelectChanges(WriteMessage.Recipient, WriteMessage.MessageNo, ExportedObjectsByRef());
		
	EndIf;
	
	// Assign sent message number to objects created in the current session of the data export.
	If ObjectsCreatedAtImporting().Count() > 0 Then
		
		DataExchangeServer.SelectChanges(WriteMessage.Recipient, WriteMessage.MessageNo, ObjectsCreatedAtImporting());
		
	EndIf;
	
	If Cancel Then
		WriteMessage.CancelWrite();
	Else
		WriteMessage.EndWrite();
	EndIf;
	
	XMLWriter.Close();
	XMLWriter = Undefined;
	
	// {HANDLER AfterDataExport}
	If Not Cancel AND Not IsBlankString(Conversion.AfterDataExport) Then
		
		Try
			
			If DebuggingExportHandlers Then
				
				ExecuteHandler_Conversion_AfterDataExport(ExchangeFile);
				
			Else
				
				Execute(Conversion.AfterDataExport);
				
			EndIf;
			
		Except
			WriteInformationAboutErrorConversionHandlers(63, ErrorDescription(), NStr("en='AfterDataExport (conversion)';ru='ПослеВыгрузкиДанных (конвертация)'"));
		EndTry;
	
	EndIf;
	// {HANDLER AfterDataExport}
	
EndProcedure

Procedure RunDumpOfObjectMappingRegister(WriteMessage, ErrorMessageString)
	
	// Select changes only for the match register.
	ChangeSelection = DataExchangeServer.SelectChanges(WriteMessage.Recipient, WriteMessage.MessageNo, Metadata.InformationRegisters.InfobasesObjectsCompliance);
	
	While ChangeSelection.Next() Do
		
		Data = ChangeSelection.Get();
		
		// Put filter to the data export.
		If Data.Filter.InfobaseNode.Value <> NodeForExchange Then
			Continue;
		ElsIf IsBlankString(Data.Filter.UniqueReceiverHandle.Value) Then
			Continue;
		EndIf;
		
		ExportObject = True;
		
		For Each Record IN Data Do
			
			If ExportObject AND Record.ObjectExportedByRef = True Then
				
				ExportObject = False;
				
			EndIf;
			
		EndDo;
		
		// Export IR registered information InfobaseObjectMatches;
		// IR conversion rules are written to code of this processor;
		If ExportObject Then
			
			DumpInformationAboutRegisteredObject(Data);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure RunDumpOfRegisteredData(WriteMessage, ErrorMessageString, UsedUnloadRulesTable)
	
	// Variable-stubs to support debugging mechanism of events handlers code.
	Var Cancel, OCRName, DataSelection, OutgoingData;
	// {HANDLER BeforeReceivingChangedObjects}
	If Not IsBlankString(Conversion.BeforeGetChangedObjects) Then
		
		Try
			
			Recipient = NodeForExchange;
			
			If DebuggingExportHandlers Then
				
				ExecuteHandler_Conversion_BeforeGetChangedObjects(Recipient, NodeForBackgroundExchange);
				
			Else
				
				Execute(Conversion.BeforeGetChangedObjects);
				
			EndIf;
			
		Except
			WriteInformationAboutErrorConversionHandlers(175, ErrorDescription(), NStr("en='BeforeReceivingChangedObjects (conversion)';ru='ПередПолучениемИзмененныхОбъектов (конвертация)'"));
			Return;
		EndTry;
		
	EndIf;
	// {HANDLER BeforeReceivingChangedObjects}
	
	MetadataToExportArray = UsedUnloadRulesTable.UnloadColumn("SelectionObjectMetadata");
	
	// "Undefined" value indicates the need for constants export.
	If MetadataToExportArray.Find(Undefined) <> Undefined Then
		
		AddConstantsToDumpMetadataArray(MetadataToExportArray);
		
	EndIf;
	
	// Delete items with "Undefined" value from array.
	DeleteInadmissibleValuesFromDumpMetadataArray(MetadataToExportArray);
	
	// The InfobaseObjectMatches information register is exported separately, therefore, it should not
	// be included in this selection.
	If MetadataToExportArray.Find(Metadata.InformationRegisters.InfobasesObjectsCompliance) <> Undefined Then
		
		CommonUseClientServer.DeleteValueFromArray(MetadataToExportArray, Metadata.InformationRegisters.InfobasesObjectsCompliance);
		
	EndIf;
	
	// Update ORM reused values.
	DataExchangeServerCall.CheckObjectRegistrationMechanismCache();
	
	InitialDataExport = DataExchangeServer.InitialDataExportFlagIsSet(WriteMessage.Recipient);
	
	// CHANGES SELECTION
	ChangeSelection = DataExchangeServer.SelectChanges(WriteMessage.Recipient, WriteMessage.MessageNo, MetadataToExportArray);
	
	PreviousMetadataObject      = Undefined;
	PreviousDataExportRule = Undefined;
	DataExportRule           = Undefined;
	ExportFileNumber              = 0;
	FileString                     = Undefined;
	ExportingRegister              = False;
	ExportingConstants            = False;
	
	IsExchangeOverExternalConnection = IsExchangeOverExternalConnection();
	
	If IsExchangeOverExternalConnection Then
		
		If DataImportExecutedInExternalConnection Then
			
			If DataProcessorForDataImport().UseTransactions Then
				
				ExternalConnection.BeginTransaction();
				
			EndIf;
			
		Else
			
			DataProcessorForDataImport().ExternalConnectionBeginTransactionOnDataImport();
			
		EndIf;
		
	EndIf;
	
	NodeForExchangeObject = NodeForExchange.GetObject();
	
	While ChangeSelection.Next() Do
		
		Data = ChangeSelection.Get();
		
		ExportDataType = TypeOf(Data);
		
		// Practise object deletion.
		If ExportDataType = ObjectDeletionType Then
			
			WorkThroughObjectDeletion(Data);
			Continue;
			
		EndIf;
		
		CurrentMetadataObject = Data.Metadata();
		
		// Metadata object new type is exported.
		If PreviousMetadataObject <> CurrentMetadataObject Then
			
			If PreviousMetadataObject <> Undefined Then
				
				// {HANDLER AfterDataProcessor DDR}
				If PreviousDataExportRule <> Undefined
					AND Not IsBlankString(PreviousDataExportRule.AfterProcessing) Then
					
					Try
						
						If DebuggingExportHandlers Then
							
							ExecuteHandler_DDR_AfterProcessRule(OCRName, PreviousDataExportRule, OutgoingData);
							
						Else
							
							Execute(PreviousDataExportRule.AfterProcessing);
							
						EndIf;
						
					Except
						WriteInformationAboutErrorDDRHandlers(32, ErrorDescription(), PreviousDataExportRule.Name, "AfterProcessDataExport");
					EndTry;
					
				EndIf;
				// {HANDLER AfterDataProcessor DDR}
				
			EndIf;
			
			PreviousMetadataObject = CurrentMetadataObject;
			
			ExportingRegister = False;
			ExportingConstants = False;
			
			DataStructure = ManagersForExchangePlans[CurrentMetadataObject];
			
			If DataStructure = Undefined Then
				
				ExportingConstants = Metadata.Constants.Contains(CurrentMetadataObject);
				
			ElsIf DataStructure.ThisIsRegister = True Then
				
				ExportingRegister = True;
				
			EndIf;
			
			If ExportingConstants Then
				
				DataExportRule = UsedUnloadRulesTable.Find(Type("ConstantsSet"), "SelectionObjectMetadata");
				
			Else
				
				DataExportRule = UsedUnloadRulesTable.Find(CurrentMetadataObject, "SelectionObjectMetadata");
				
			EndIf;
			
			PreviousDataExportRule = DataExportRule;
			
			// {HANDLER BeforeDataProcessor DDR}
			OutgoingData = Undefined;
			
			If DataExportRule <> Undefined
				AND Not IsBlankString(DataExportRule.BeforeProcess) Then
				
				Try
					
					If DebuggingExportHandlers Then
						
						ExecuteHandler_DDR_BeforeProcessRule(Cancel, OCRName, DataExportRule, OutgoingData, DataSelection);
						
					Else
						
						Execute(DataExportRule.BeforeProcess);
						
					EndIf;
					
				Except
					WriteInformationAboutErrorDDRHandlers(31, ErrorDescription(), DataExportRule.Name, "BeforeProcessDataExport");
				EndTry;
				
				
			EndIf;
			// {HANDLER BeforeDataProcessor DDR}
			
		EndIf;
		
		If ExportDataType <> MapRegisterType Then
			
			// Determine object sending kind.
			ItemSend = DataItemSend.Auto;
			
			StandardSubsystemsServer.OnSendDataToSubordinate(Data, ItemSend, InitialDataExport, NodeForExchangeObject);
			
			If ItemSend = DataItemSend.Delete Then
				
				If ExportingRegister Then
					
					// Send register removal as an empty records set.
					
				Else
					
					// Receive removal information.
					WorkThroughObjectDeletion(Data);
					Continue;
					
				EndIf;
				
			ElsIf ItemSend = DataItemSend.Ignore Then
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		// OBJECT EXPORT
		If ExportingRegister Then
			
			// register export
			RegisterDump(Data, DataExportRule, OutgoingData, DoNotDumpObjectsByRefs);
			
		ElsIf ExportingConstants Then
			
			// constants set export
			Properties = Managers[Type("ConstantsSet")];
			
			DumpConstantsSet(DataExportRule, Properties, OutgoingData, CurrentMetadataObject.Name);
			
		Else
			
			// reference types export
			ExportSelectionObject(Data, DataExportRule, , OutgoingData, DoNotDumpObjectsByRefs);
			
		EndIf;
		
		If IsExchangeOverExternalConnection Then
			
			If DataImportExecutedInExternalConnection Then
				
				If DataProcessorForDataImport().UseTransactions
					AND DataProcessorForDataImport().ObjectsCountForTransactions > 0
					AND DataProcessorForDataImport().CounterOfImportedObjects() % DataProcessorForDataImport().ObjectsCountForTransactions = 0 Then
					
					ExternalConnection.CommitTransaction();
					ExternalConnection.BeginTransaction();
					
				EndIf;
				
				
			Else
				
				DataProcessorForDataImport().ExternalConnectionCheckTransactionStartAndCommitOnDataImport();
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If PreviousMetadataObject <> Undefined Then
		
		// {HANDLER AfterDataProcessor DDR}
		If DataExportRule <> Undefined
			AND Not IsBlankString(DataExportRule.AfterProcessing) Then
			
			Try
				
				If DebuggingExportHandlers Then
					
					ExecuteHandler_DDR_AfterProcessRule(OCRName, DataExportRule, OutgoingData);
					
				Else
					
					Execute(DataExportRule.AfterProcessing);
					
				EndIf;
				
			Except
					WriteInformationAboutErrorDDRHandlers(32, ErrorDescription(), DataExportRule.Name, "AfterProcessDataExport");
				EndTry;
			
		EndIf;
		// {HANDLER AfterDataProcessor DDR}
		
	EndIf;
	
	If IsExchangeOverExternalConnection Then
		
		If DataImportExecutedInExternalConnection Then
			
			If DataProcessorForDataImport().UseTransactions Then
				
				If DataProcessorForDataImport().ErrorFlag() Then
					
					ExternalConnection.RollbackTransaction();
					
				Else
					
					ExternalConnection.CommitTransaction();
					
				EndIf;
				
			EndIf;
			
		Else
			
			DataProcessorForDataImport().ExternalConnectionCommitTransactionOnDataImport();
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure WriteLogEventDataExchange(Comment, Level = Undefined)
	
	If Level = Undefined Then
		Level = EventLogLevel.Error;
	EndIf;
	
	MetadataObject = Undefined;
	
	If     ExchangeNodeForDataImport <> Undefined
		AND Not ExchangeNodeForDataImport.IsEmpty() Then
		
		MetadataObject = ExchangeNodeForDataImport.Metadata();
		
	EndIf;
	
	WriteLogEvent(EventLogMonitorMessageKey(), Level, MetadataObject,, Comment);
	
EndProcedure

Function ExportObjectMappingInformation(InfobaseNode)
	
	QueryText = "
	|SELECT TOP 1 1
	|FROM
	|	InformationRegister.InfobasesObjectsCompliance.Changes AS InfobasesObjectsComplianceChanges
	|WHERE
	|	InfobasesObjectsComplianceChanges.Node = &InfobaseNode
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

Function NeedToExecuteCorrectionOfMappingInformation()
	
	Return InformationRegisters.InfobasesNodesCommonSettings.NeedToExecuteCorrectionOfMappingInformation(NodeForExchange, NodeForExchange.SentNo + 1);
	
EndFunction

Procedure DeleteInadmissibleValuesFromDumpMetadataArray(MetadataToExportArray)
	
	If MetadataToExportArray.Find(Undefined) <> Undefined Then
		
		CommonUseClientServer.DeleteValueFromArray(MetadataToExportArray, Undefined);
		
		DeleteInadmissibleValuesFromDumpMetadataArray(MetadataToExportArray);
		
	EndIf;
	
EndProcedure

Procedure AddConstantsToDumpMetadataArray(MetadataToExportArray)
	
	Content = Metadata.ExchangePlans[ExchangePlanName()].Content;
	
	For Each MetadataObjectConstant IN Metadata.Constants Do
		
		If Content.Contains(MetadataObjectConstant) Then
			
			MetadataToExportArray.Add(MetadataObjectConstant);
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PREDEFINED CONVERSION RULES

Procedure ImportConversionRule_ExchangeObjectsExportModes(XMLWriter)
	
	SourceType = "EnumRef.ExchangeObjectsExportModes";
	ReceiverType = "EnumRef.ExchangeObjectsExportModes";
	
	Filter = New Structure;
	Filter.Insert("SourceType", SourceType);
	Filter.Insert("ReceiverType", ReceiverType);
	
	If ConversionRulesTable.FindRows(Filter).Count() <> 0 Then
		Return;
	EndIf;
	
	NewRow = ConversionRulesTable.Add();
	
	NewRow.RememberExported = True;
	NewRow.Donotreplace            = False;
	NewRow.ExchangeObjectPriority = Enums.ExchangeObjectPriorities.PriorityOfObjectReceivedOnExchangeIsHigher;
	
	NewRow.Properties            = PropertyConversionRuleTable.Copy();
	NewRow.SearchProperties      = PropertyConversionRuleTable.Copy();
	NewRow.DisabledProperties = PropertyConversionRuleTable.Copy();
	
	NewRow.Name = "ExchangeObjectsExportModes";
	NewRow.Source = Type(SourceType);
	NewRow.Receiver = ReceiverType;
	NewRow.SourceType = SourceType;
	NewRow.ReceiverType = ReceiverType;
	
	Values = New Structure;
	Values.Insert("AlwaysExport",           "AlwaysExport");
	Values.Insert("ExportByCondition",        "ExportByCondition");
	Values.Insert("ExportIfNecessary", "ExportIfNecessary");
	Values.Insert("ExportManually",          "ExportManually");
	Values.Insert("DoNotExport",               "DoNotExport");
	NewRow.ValuesOfPredefinedDataRead = Values;
	
	SearchInTabularSections = New ValueTable;
	SearchInTabularSections.Columns.Add("ItemName");
	SearchInTabularSections.Columns.Add("KeySearchFieldArray");
	SearchInTabularSections.Columns.Add("KeySearchFields");
	SearchInTabularSections.Columns.Add("Valid", deDescriptionType("Boolean"));
	NewRow.SearchInTabularSections = SearchInTabularSections;
	
	Managers[NewRow.Source].OCR = NewRow;
	
	Rules.Insert(NewRow.Name, NewRow);
	
	XMLWriter.WriteStartElement("Rule");
	deWriteItem(XMLWriter, "Code", NewRow.Name);
	deWriteItem(XMLWriter, "Source", NewRow.SourceType);
	deWriteItem(XMLWriter, "Receiver", NewRow.ReceiverType);
	XMLWriter.WriteEndElement(); // Rule
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INITIALIZE EXCHANGE RULES TABLES

// Initializes table columns of object properties conversion rules.
//
// Parameters:
//  Tab            - ValuesTable. initialized table columns of properties conversion rules.
// 
Procedure PropertiesConversionRulesTableInitialization(Tab)

	Columns = Tab.Columns;

	Columns.Add("Name");
	Columns.Add("Description");
	Columns.Add("Order");

	Columns.Add("IsFolder",     deDescriptionType("Boolean"));
	Columns.Add("IsSearchField", deDescriptionType("Boolean"));
	Columns.Add("GroupRules");
	Columns.Add("DisabledGroupRules");

	Columns.Add("SourceKind");
	Columns.Add("TargetKind");
	
	Columns.Add("SimplifiedPropertyExport", deDescriptionType("Boolean"));
	Columns.Add("XMLNodeRequiredOnExport", deDescriptionType("Boolean"));
	Columns.Add("XMLNodeRequiredOnExportGroup", deDescriptionType("Boolean"));

	Columns.Add("SourceType", deDescriptionType("String"));
	Columns.Add("ReceiverType", deDescriptionType("String"));
		
	Columns.Add("Source");
	Columns.Add("Receiver");

	Columns.Add("ConversionRule");

	Columns.Add("GetFromIncomingData", deDescriptionType("Boolean"));
	
	Columns.Add("Donotreplace",              deDescriptionType("Boolean"));
	Columns.Add("IsRequiredProperty", deDescriptionType("Boolean"));
	
	Columns.Add("BeforeExport");
	Columns.Add("ProcessorsNameBeforeExport");
	Columns.Add("OnExport");
	Columns.Add("HandlerNameOnDump");
	Columns.Add("AfterExport");
	Columns.Add("HandlerNameAfterDump");

	Columns.Add("BeforeProcessExport");
	Columns.Add("ProcessorsNameBeforeProcessingExportings");
	Columns.Add("AfterProcessExport");
	Columns.Add("HandlerNameAfterDumpProcessing");

	Columns.Add("HasBeforeExportHandler",			deDescriptionType("Boolean"));
	Columns.Add("HasOnExportHandler",				deDescriptionType("Boolean"));
	Columns.Add("HasAfterExportHandler",				deDescriptionType("Boolean"));
	
	Columns.Add("HasBeforeProcessExportHandler",	deDescriptionType("Boolean"));
	Columns.Add("HasAfterProcessExportHandler",	deDescriptionType("Boolean"));
	
	Columns.Add("CastToLength",							deDescriptionType("Number"));
	Columns.Add("ParameterForTransferName", 				deDescriptionType("String"));
	Columns.Add("SearchByEqualDate",					deDescriptionType("Boolean"));
	Columns.Add("ExportGroupToFile",				deDescriptionType("Boolean"));
	
	Columns.Add("SearchFieldString");
	
EndProcedure

Function CreateDumpedObjectsTable()
	
	Table = New ValueTable();
	Table.Columns.Add("Key");
	Table.Columns.Add("Referencenode");
	Table.Columns.Add("OnlyRefExported",    New TypeDescription("Boolean"));
	Table.Columns.Add("RefNPP",                New TypeDescription("Number"));
	Table.Columns.Add("CallCount",      New TypeDescription("Number"));
	Table.Columns.Add("LastCallNumber", New TypeDescription("Number"));
	
	Table.Indexes.Add("Key");
	
	Return Table;
	
EndFunction

// Initializes table columns of objects conversion rules.
//
// Parameters:
//  No.
// 
Procedure ConversionRulesTableInitialization()

	Columns = ConversionRulesTable.Columns;
	
	Columns.Add("Name");
	Columns.Add("Description");
	Columns.Add("Order");

	Columns.Add("SynchronizeByID",                        deDescriptionType("Boolean"));
	Columns.Add("DoNotCreateIfNotFound",                                 deDescriptionType("Boolean"));
	Columns.Add("DontExportPropertyObjectsByRefs",                      deDescriptionType("Boolean"));
	Columns.Add("SearchBySearchFieldsIfNotFoundByID", deDescriptionType("Boolean"));
	Columns.Add("OnExchangeObjectByRefSetGIUDOnly",       deDescriptionType("Boolean"));
	Columns.Add("DontReplaceCreatedInTargetObject",   deDescriptionType("Boolean"));
	Columns.Add("UseQuickSearchOnImport",                     deDescriptionType("Boolean"));
	Columns.Add("Generatenewnumberorcodeifnotspecified",                deDescriptionType("Boolean"));
	Columns.Add("TinyObjectCount",                             deDescriptionType("Boolean"));
	Columns.Add("RefExportReferenceCount",                    deDescriptionType("Number"));
	Columns.Add("InfobaseItemCount",                                  deDescriptionType("Number"));
		
	Columns.Add("ExportMethod");

	Columns.Add("Source");
	Columns.Add("Receiver");
	
	Columns.Add("SourceType",  deDescriptionType("String"));
	Columns.Add("ReceiverType",  deDescriptionType("String"));
	
	Columns.Add("BeforeExport");
	Columns.Add("ProcessorsNameBeforeExport");
	
	Columns.Add("OnExport");
	Columns.Add("HandlerNameOnDump");
	
	Columns.Add("AfterExport");
	Columns.Add("HandlerNameAfterDump");
	
	Columns.Add("AfterExportToFile");
	Columns.Add("HandlerNameAfterDumpToFile");

	Columns.Add("HasBeforeExportHandler",	deDescriptionType("Boolean"));
	Columns.Add("HasOnExportHandler",		deDescriptionType("Boolean"));
	Columns.Add("HasAfterExportHandler",		deDescriptionType("Boolean"));
	Columns.Add("HasAfterExportToFileHandler",deDescriptionType("Boolean"));

	Columns.Add("BeforeImport");
	Columns.Add("HandlerNameBeforeImport");
	
	Columns.Add("OnImport");
	Columns.Add("OnImportingNameProcessors");
	
	Columns.Add("AfterImport");
	Columns.Add("ProcessorsNameAfterImport");
	
	Columns.Add("SearchFieldSequence");
	Columns.Add("HandlerNameSearchFieldsSequence");

	Columns.Add("SearchInTabularSections");
	
	Columns.Add("ExchangeObjectPriority");
	
	Columns.Add("HasBeforeImportHandler", deDescriptionType("Boolean"));
	Columns.Add("HasOnImportHandler",    deDescriptionType("Boolean"));
	Columns.Add("HasAfterImportHandler",  deDescriptionType("Boolean"));
	
	Columns.Add("HasSearchFieldSequenceHandler",  deDescriptionType("Boolean"));

	Columns.Add("Properties",            deDescriptionType("ValueTable"));
	Columns.Add("SearchProperties",      deDescriptionType("ValueTable"));
	Columns.Add("DisabledProperties", deDescriptionType("ValueTable"));
	
	// Property "Values" Not used.
	// Columns.Add("Values", deDescriptionType("Map"));
	
	// Matching.
	// Key - value of the predefined object in this base;
	// Value - String presentation of the predefined value in the receiver.
	Columns.Add("ValuesOfPredefinedData", deDescriptionType("Map"));
	
	// Structure.
	// Key - String presentation of the predefined value in this base;
	// Value - String presentation of the predefined value in the receiver.
	Columns.Add("ValuesOfPredefinedDataRead", deDescriptionType("Structure"));
	
	Columns.Add("Exported",							deDescriptionType("ValueTable"));
	Columns.Add("ExportSourcePresentation",		deDescriptionType("Boolean"));
	
	Columns.Add("Donotreplace",					deDescriptionType("Boolean"));
	
	Columns.Add("RememberExported",       deDescriptionType("Boolean"));
	Columns.Add("AllObjectsAreExported",         deDescriptionType("Boolean"));
	
	Columns.Add("SearchFields",  deDescriptionType("String"));
	Columns.Add("TableFields", deDescriptionType("String"));
	
EndProcedure

// Initializes table columns of data export rules.
//
// Parameters:
//  No
// 
Procedure UnloadRulesTableInitialization()

	Columns = UnloadRulesTable.Columns;

	Columns.Add("Enable", deDescriptionType("Boolean"));
	
	Columns.Add("Name");
	Columns.Add("Description");
	Columns.Add("Order");

	Columns.Add("DataSelectionVariant");
	Columns.Add("SelectionObject");
	Columns.Add("SelectionObjectMetadata");
	
	Columns.Add("ConversionRule");

	Columns.Add("BeforeProcess");
	Columns.Add("ProcessorsNameBeforeProcessing");
	Columns.Add("AfterProcessing");
	Columns.Add("ProcessorsNameAfterProcessing");

	Columns.Add("BeforeExport");
	Columns.Add("ProcessorsNameBeforeExport");
	Columns.Add("AfterExport");
	Columns.Add("HandlerNameAfterDump");
	
	// Columns for filter support using builder.
	Columns.Add("UseFilter", deDescriptionType("Boolean"));
	Columns.Add("BuilderSettings");
	Columns.Add("ObjectForQueryName");
	Columns.Add("ObjectNameForRegisterQuery");
	Columns.Add("RecipientTypeName");
	
	Columns.Add("DontExportCreatedInTargetInfobaseObjects", deDescriptionType("Boolean"));
	
	Columns.Add("ExchangeNodeRef");
	
	Columns.Add("SynchronizeByID", deDescriptionType("Boolean"));
	
EndProcedure

// Initializes table columns of data clearing rules.
//
// Parameters:
//  No.
// 
Procedure ClearRulesTableInitialization()

	Columns = FlushRulesTable.Columns;

	Columns.Add("Enable",		deDescriptionType("Boolean"));
	Columns.Add("IsFolder",		deDescriptionType("Boolean"));
	
	Columns.Add("Name");
	Columns.Add("Description");
	Columns.Add("Order",	deDescriptionType("Number"));

	Columns.Add("DataSelectionVariant");
	Columns.Add("SelectionObject");
	
	Columns.Add("DeleteForPeriod");
	Columns.Add("Directly",	deDescriptionType("Boolean"));

	Columns.Add("BeforeProcess");
	Columns.Add("ProcessorsNameBeforeProcessing");
	Columns.Add("AfterProcessing");
	Columns.Add("ProcessorsNameAfterProcessing");
	Columns.Add("BeforeDelete");
	Columns.Add("HandlerNameBeforeDeletion");

EndProcedure

// Initializes table columns of parameter settings.
//
// Parameters:
//  No.
// 
Procedure ParametersSettingTableInitialization()

	Columns = ParametersSettingsTable.Columns;

	Columns.Add("Name");
	Columns.Add("Description");
	Columns.Add("Value");
	Columns.Add("PassParameterOnExport");
	Columns.Add("ConversionRule");

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INITIALIZE ATTRIBUTES AND MODULE VARIABLES

Function InitializationOfTableOfDataOfExchangeMessage(ObjectType)
	
	ExchangeMessageDataTable = New ValueTable;
	
	Columns = ExchangeMessageDataTable.Columns;
	
	// mandatory fields
	Columns.Add(ColumnNameUUID(), String36Type);
	Columns.Add(ColumnNameTypeAsString(),              String255Type);
	
	MetadataObject = Metadata.FindByType(ObjectType);
	
	// Receive description of all fields of metadata object from the configuration.
	TableOfDescriptionOfObjectProperties = CommonUse.GetTableOfDescriptionOfObjectProperties(MetadataObject, "Name, Type");
	
	For Each PropertyDetails IN TableOfDescriptionOfObjectProperties Do
		ColumnTypes = New TypeDescription(PropertyDetails.Type, "NULL");
		Columns.Add(PropertyDetails.Name, ColumnTypes);
	EndDo;
	
	ExchangeMessageDataTable.Indexes.Add(ColumnNameUUID());
	
	Return ExchangeMessageDataTable;
	
EndFunction

Function InitializeHandlings()
	
	ExchangePlanName = ExchangePlanName();
	
	SecurityProfileName = DataExchangeReUse.SecurityProfileName(ExchangePlanName);
	
	ExchangePlanManager = ExchangePlans[ExchangePlanName];
	
	If DebuggingExportHandlers AND (ExchangeMode = "Export" Or ExchangeMode = "") Then
		
		If SecurityProfileName = Undefined Then
			ImportingHandling = ExternalDataProcessors.Create(FileNameOfExternalDataProcessorOfExportDebugging);
		Else
			ImportingHandling = ExternalDataProcessors.Create(FileNameOfExternalDataProcessorOfExportDebugging, SecurityProfileName);
		EndIf;
		
		ImportingHandling.ConnectProcessingForDebugging(ThisObject);
		
	ElsIf DebuggingImportHandlers AND ExchangeMode = "Import" Then
		
		If SecurityProfileName = Undefined Then
			ImportProcessing = ExternalDataProcessors.Create(FileNameOfExternalDataProcessorOfImportDebugging);
		Else
			ImportProcessing = ExternalDataProcessors.Create(FileNameOfExternalDataProcessorOfImportDebugging, SecurityProfileName);
		EndIf;
		
		ImportProcessing.ConnectProcessingForDebugging(ThisObject);
		
	EndIf;
	
	Return SecurityProfileName;
	
EndFunction

// Disables data processor with handlers code previously connected for debugging.
//
Procedure DisableDataProcessorForDebug()
	
	If ImportingHandling <> Undefined Then
		
		Try
			ImportingHandling.DisableDataProcessorForDebug();
		Except
			// There is no procedure to disable data processor.
		EndTry;
		ImportingHandling = Undefined;
		
	ElsIf ImportProcessing <> Undefined Then
		
		Try
			ImportProcessing.DisableDataProcessorForDebug();
		Except
			// There is no procedure to disable data processor.
		EndTry;
		
		ImportProcessing = Undefined;
		
	EndIf;
	
EndProcedure

// Initializes the ErrorMessages variable containing message codes match to their descriptions.
//
// Parameters:
//  No.
// 
Procedure MessagesInitialization()

	ErrorMessages			= New Map;
		
	ErrorMessages.Insert(2,  NStr("en='Error of exchange file unpacking. File is locked.';ru='Ошибка распаковки файла обмена. Файл заблокирован.'"));
	ErrorMessages.Insert(3,  NStr("en='Specified exchange rules file does not exist.';ru='Указанный файл правил обмена не существует.'"));
	ErrorMessages.Insert(4,  NStr("en='Error while creating COM-object Msxml2.DOMDocument';ru='Ошибка при создании COM-объекта Msxml2.DOMDocument'"));
	ErrorMessages.Insert(5,  NStr("en='File opening error';ru='Ошибка открытия файла обмена'"));
	ErrorMessages.Insert(6,  NStr("en='Error while loading rules of exchange';ru='Ошибка при загрузке правил обмена'"));
	ErrorMessages.Insert(7,  NStr("en='Exchange rules format error';ru='Ошибка формата правил обмена'"));
	ErrorMessages.Insert(8,  NStr("en='File name to export data is not correct';ru='Не корректно указано имя файла для выгрузки данных'")); // not used
	ErrorMessages.Insert(9,  NStr("en='Exchange file format error';ru='Ошибка формата файла обмена'"));
	ErrorMessages.Insert(10, NStr("en='File name is not specified for the data export (Name of the data file)';ru='Не указано имя файла для выгрузки данных (Имя файла данных)'"));
	ErrorMessages.Insert(11, NStr("en='Reference to non-existing metadata object in the rules of exchange';ru='Ссылка на несуществующий объект метаданных в правилах обмена'"));
	ErrorMessages.Insert(12, NStr("en='File name with the exchange rules (Name of the rules file) is not specified';ru='Не указано имя файла с правилами обмена (Имя файла правил)'"));
			
	ErrorMessages.Insert(13, NStr("en='Error of receiving the object property value (by source property name)';ru='Ошибка получения значения свойства объекта (по имени свойства источника)'"));
	ErrorMessages.Insert(14, NStr("en='error of receiving the object property value (by receiver property name)';ru='Ошибка получения значения свойства объекта (по имени свойства приемника)'"));
	
	ErrorMessages.Insert(15, NStr("en='File name to load data not defined. (File name for loading)';ru='Не указано имя файла для загрузки данных (Имя файла для загрузки)'"));
			
	ErrorMessages.Insert(16, NStr("en=""Error in receiving the value of the child object (in the name of property's source)"";ru='Ошибка получения значения свойства подчиненного объекта (по имени свойства источника)'"));
	ErrorMessages.Insert(17, NStr("en=""Error in receiving the value of the child object (in the name of receiver's source)"";ru='Ошибка получения значения свойства подчиненного объекта (по имени свойства приемника)'"));
	ErrorMessages.Insert(18, NStr("en='Error when creating the data processor with the code of handlers';ru='Ошибка при создании обработки с кодом обработчиков'"));
	ErrorMessages.Insert(19, NStr("en='Error in the event handler BeforeObjectImport';ru='Ошибка в обработчике события ПередЗагрузкойОбъекта'"));
	ErrorMessages.Insert(20, NStr("en='Error in the event handler OnObjectImport';ru='Ошибка в обработчике события ПриЗагрузкеОбъекта'"));
	ErrorMessages.Insert(21, NStr("en='Error in the event handler AfterObjectImport';ru='Ошибка в обработчике события ПослеЗагрузкиОбъекта'"));
	ErrorMessages.Insert(22, NStr("en='Error in the event handler BeforeObjectImport (conversion)';ru='Ошибка в обработчике события ПередЗагрузкойДанных (конвертация)'"));
	ErrorMessages.Insert(23, NStr("en='Error in the event handler AfterDataImport (conversion)';ru='Ошибка в обработчике события ПослеЗагрузкиДанных (конвертация)'"));
	ErrorMessages.Insert(24, NStr("en='An error occurred while deleting an object';ru='Ошибка при удалении объекта'"));
	ErrorMessages.Insert(25, NStr("en='Error writing document';ru='Ошибка при записи документа'"));
	ErrorMessages.Insert(26, NStr("en='Error writing object';ru='Ошибка записи объекта'"));
	ErrorMessages.Insert(27, NStr("en='BeforeProcessClearingRule event handler error';ru='Ошибка в обработчике события ПередОбработкойПравилаОчистки'"));
	ErrorMessages.Insert(28, NStr("en='Error in the event handler AfterClearingRuleProcessing';ru='Ошибка в обработчике события ПослеОбработкиПравилаОчистки'"));
	ErrorMessages.Insert(29, NStr("en='Error in the event handler BeforeDeleteObject';ru='Ошибка в обработчике события ПередУдалениемОбъекта'"));
	
	ErrorMessages.Insert(31, NStr("en='BeforeProcessExportRule event handler error';ru='Ошибка в обработчике события ПередОбработкойПравилаВыгрузки'"));
	ErrorMessages.Insert(32, NStr("en='Error in the event handler AfterDumpRuleProcessing';ru='Ошибка в обработчике события ПослеОбработкиПравилаВыгрузки'"));
	ErrorMessages.Insert(33, NStr("en='Error in the event handler BeforeObjectExport';ru='Ошибка в обработчике события ПередВыгрузкойОбъекта'"));
	ErrorMessages.Insert(34, NStr("en='Error in the event handler AfterObjectExport';ru='Ошибка в обработчике события ПослеВыгрузкиОбъекта'"));
			
	ErrorMessages.Insert(41, NStr("en='Error in the event handler BeforeObjectExport';ru='Ошибка в обработчике события ПередВыгрузкойОбъекта'"));
	ErrorMessages.Insert(42, NStr("en='Error in the event handler OnObjectExport';ru='Ошибка в обработчике события ПриВыгрузкеОбъекта'"));
	ErrorMessages.Insert(43, NStr("en='Error in the event handler AfterObjectExport';ru='Ошибка в обработчике события ПослеВыгрузкиОбъекта'"));
			
	ErrorMessages.Insert(45, NStr("en='Object Conversion rule not found';ru='Не найдено правило конвертации объектов'"));
		
	ErrorMessages.Insert(48, NStr("en='Error in the event handler BeforeExportProcessor properties group';ru='Ошибка в обработчике события ПередОбработкойВыгрузки группы свойств'"));
	ErrorMessages.Insert(49, NStr("en='Error in the event handler AfterExportProcessor';ru='Ошибка в обработчике события ПослеОбработкиВыгрузки группы свойств'"));
	ErrorMessages.Insert(50, NStr("en='Error in the event handler BeforeExport (collection object)';ru='Ошибка в обработчике события ПередВыгрузкой (объекта коллекции)'"));
	ErrorMessages.Insert(51, NStr("en='Error in the event handler OnExport (collection object)';ru='Ошибка в обработчике события ПриВыгрузке (объекта коллекции)'"));
	ErrorMessages.Insert(52, NStr("en='Error in the event handler AfterExport (collection object)';ru='Ошибка в обработчике события ПослеВыгрузки (объекта коллекции)'"));
	ErrorMessages.Insert(53, NStr("en='Error in the global event handler BeforeObjectImporting (conversion)';ru='Ошибка в глобальном обработчике события ПередЗагрузкойОбъекта (конвертация)'"));
	ErrorMessages.Insert(54, NStr("en='Error in the global handler of the AfterObjectImport (conversion) event';ru='Ошибка в глобальном обработчике события ПослеЗагрузкиОбъекта (конвертация)'"));
	ErrorMessages.Insert(55, NStr("en='Error in the event handler BeforeExport (property)';ru='Ошибка в обработчике события ПередВыгрузкой (свойства)'"));
	ErrorMessages.Insert(56, NStr("en='Error in the event handler OnExport (properties)';ru='Ошибка в обработчике события ПриВыгрузке (свойства)'"));
	ErrorMessages.Insert(57, NStr("en='Error in the event handler AfterExport (properties)';ru='Ошибка в обработчике события ПослеВыгрузки (свойства)'"));
	
	ErrorMessages.Insert(62, NStr("en='Error in the event handler BeforeDataExport (properties)';ru='Ошибка в обработчике события ПередВыгрузкойДанных (конвертация)'"));
	ErrorMessages.Insert(63, NStr("en='Error in the event handler AfterDataExport (conversion)';ru='Ошибка в обработчике события ПослеВыгрузкиДанных (конвертация)'"));
	ErrorMessages.Insert(64, NStr("en='Error in the global event handler BeforeObjectConversion (conversion)';ru='Ошибка в глобальном обработчике события ПередКонвертациейОбъекта (конвертация)'"));
	ErrorMessages.Insert(65, NStr("en='Error in the global event handler BeforeObjectExport (conversion)';ru='Ошибка в глобальном обработчике события ПередВыгрузкойОбъекта (конвертация)'"));
	ErrorMessages.Insert(66, NStr("en='Error of receiving the collection of subordinate objects from incoming data';ru='Ошибка получения коллекции подчиненных объектов из входящих данных'"));
	ErrorMessages.Insert(67, NStr("en='Error retrieving subordinate object properties from incoming data';ru='Ошибка получения свойства подчиненного объекта из входящих данных'"));
	ErrorMessages.Insert(68, NStr("en=""Error of receiving object's property from incoming data"";ru='Ошибка получения свойства объекта из входящих данных'"));
	
	ErrorMessages.Insert(69, NStr("en='Error in the global event handler AfterObjectExport (conversion)';ru='Ошибка в глобальном обработчике события ПослеВыгрузкиОбъекта (конвертация)'"));
	
	ErrorMessages.Insert(71, NStr("en='The map of the Source value is not found';ru='Не найдено соответствие для значения Источника'"));
	
	ErrorMessages.Insert(72, NStr("en='Error exporting data for exchange plan node';ru='Ошибка при выгрузке данных для узла плана обмена'"));
	
	ErrorMessages.Insert(73, NStr("en='Error in the event handler SearchFieldsSequence';ru='Ошибка в обработчике события ПоследовательностьПолейПоиска'"));
	ErrorMessages.Insert(74, NStr("en='It is required to reload exchange rules to dump data.';ru='Необходимо перезагрузить правила обмена для выгрузки данных.'"));
	
	ErrorMessages.Insert(75, NStr("en='Error in the event handler AfterImportOfExchangeRules (conversion)';ru='Ошибка в обработчике события ПослеЗагрузкиПравилОбмена (конвертация)'"));
	ErrorMessages.Insert(76, NStr("en='Error in the BeforeSendingUninstallInformation (conversion) event handler';ru='Ошибка в обработчике события ПередОтправкойИнформацииОбУдалении (конвертация)'"));
	ErrorMessages.Insert(77, NStr("en='Error in the event handler OnObtainingInformationAboutDeletion (conversion)';ru='Ошибка в обработчике события ПриПолученииИнформацииОбУдалении (конвертация)'"));
	
	ErrorMessages.Insert(78, NStr("en='Error occurred while executing the algorithm after loading the parameters values';ru='Ошибка при выполнении алгоритма после загрузки значений параметров'"));
	
	ErrorMessages.Insert(79, NStr("en='Error in the event handler AfterObjectExportToFile';ru='Ошибка в обработчике события ПослеВыгрузкиОбъектаВФайл'"));
	
	ErrorMessages.Insert(80, NStr("en='Error of the predefined item property setting.
		|You can not mark the predefined item to be deleted. Mark for deletion for the objects is not installed.';ru='Ошибка установки свойства предопределенного элемента.
		|Нельзя помечать на удаление предопределенный элемент. Пометка на удаление для объекта не установлена.'"));
	//
	ErrorMessages.Insert(83, NStr("en='Error of the reference to the object tabular section. Tabular section of the document can not be modified.';ru='Ошибка обращения к табличной части объекта. Табличная часть объекта не может быть изменена.'"));
	ErrorMessages.Insert(84, NStr("en='Change prohibition dates collision.';ru='Коллизия дат запрета изменения.'"));
	
	ErrorMessages.Insert(173, NStr("en='An error occurred while locking exchange node. Data synchronization may be in progress';ru='Ошибка блокировки узла обмена. Возможно синхронизация данных уже выполняется'"));
	ErrorMessages.Insert(174, NStr("en='Exchange message has been previously accepted';ru='Сообщение обмена было принято ранее'"));
	ErrorMessages.Insert(175, NStr("en='Error in the event handler BeforeModifiedObjectsReceiving (conversion)';ru='Ошибка в обработчике события ПередПолучениемИзмененныхОбъектов (конвертация)'"));
	ErrorMessages.Insert(176, NStr("en='Error in the event handler AfterGettingInformationAboutExchangeNodes';ru='Ошибка в обработчике события ПослеПолученияИнформацииОбУзлахОбмена (конвертация)'"));
		
	ErrorMessages.Insert(1000, NStr("en='Error creating temporary data export file';ru='Ошибка при создании временного файла выгрузки данных'"));
		
EndProcedure

Procedure SupplementManagersArrayWithRefType(Managers, ManagersForExchangePlans, MDObject, TypeName, Manager, TypeNamePrefix, SearchByPredefinedPossible = False)
	
	Name              = MDObject.Name;
	RefTypeAsString = TypeNamePrefix + "." + Name;
	SearchString     = "SELECT Ref FROM " + TypeName + "." + Name + " WHERE ";
	RefExportSearchString     = "SELECT #SearchFields# FROM " + TypeName + "." + Name;
	ReferenceType        = Type(RefTypeAsString);
	Structure = New Structure("Name,TypeName,RefTypeAsString,Manager,MDObject,SearchString,RefExportSearchString,SearchByPredefinedPossible,OCR", Name, TypeName, RefTypeAsString, Manager, MDObject, SearchString, RefExportSearchString, SearchByPredefinedPossible);
	Managers.Insert(ReferenceType, Structure);
	
	
	StructureForExchangePlan = New Structure("Name,ReferenceType,IsReferenceType,ThisIsRegister", Name, ReferenceType, True, False);
	ManagersForExchangePlans.Insert(MDObject, StructureForExchangePlan);
	
EndProcedure

Procedure SupplementManagersArrayWithRegisterType(Managers, MDObject, TypeName, Manager, TypeNamePrefixRecord, SelectionTypeNamePrefix)
	
	Periodical = Undefined;
	
	Name					= MDObject.Name;
	RefTypeAsString	= TypeNamePrefixRecord + "." + Name;
	ReferenceType			= Type(RefTypeAsString);
	Structure = New Structure("Name,TypeName,RefTypeAsString,Manager,MDObject,SearchByPredefinedPossible,OCR", Name, TypeName, RefTypeAsString, Manager, MDObject, False);
	
	If TypeName = "InformationRegister" Then
		
		Periodical = (MDObject.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical);
		SubordinatedToRecorder = (MDObject.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate);
		
		Structure.Insert("Periodical", Periodical);
		Structure.Insert("SubordinatedToRecorder", SubordinatedToRecorder);
		
	EndIf;	
	
	Managers.Insert(ReferenceType, Structure);
		

	StructureForExchangePlan = New Structure("Name,ReferenceType,IsReferenceType,ThisIsRegister", Name, ReferenceType, False, True);
	ManagersForExchangePlans.Insert(MDObject, StructureForExchangePlan);
	
	
	RefTypeAsString	= SelectionTypeNamePrefix + "." + Name;
	ReferenceType			= Type(RefTypeAsString);
	Structure = New Structure("Name,TypeName,RefTypeAsString,Manager,MDObject,SearchByPredefinedPossible,OCR", Name, TypeName, RefTypeAsString, Manager, MDObject, False);
	
	If Periodical <> Undefined Then
		
		Structure.Insert("Periodical", Periodical);
		Structure.Insert("SubordinatedToRecorder", SubordinatedToRecorder);	
		
	EndIf;
	
	Managers.Insert(ReferenceType, Structure);	
		
EndProcedure

// Initializes the Managers variable containing match of object types to their properties.
//
// Parameters:
//  No.
// 
Procedure ManagersInitialization()

	Managers = New Map;
	
	ManagersForExchangePlans = New Map;
    	
	// REFS
	
	For Each MDObject IN Metadata.Catalogs Do
		
		SupplementManagersArrayWithRefType(Managers, ManagersForExchangePlans, MDObject, "Catalog", Catalogs[MDObject.Name], "CatalogRef", True);
					
	EndDo;

	For Each MDObject IN Metadata.Documents Do
		
		SupplementManagersArrayWithRefType(Managers, ManagersForExchangePlans, MDObject, "Document", Documents[MDObject.Name], "DocumentRef");
				
	EndDo;

	For Each MDObject IN Metadata.ChartsOfCharacteristicTypes Do
		
		SupplementManagersArrayWithRefType(Managers, ManagersForExchangePlans, MDObject, "ChartOfCharacteristicTypes", ChartsOfCharacteristicTypes[MDObject.Name], "ChartOfCharacteristicTypesRef", True);
				
	EndDo;
	
	For Each MDObject IN Metadata.ChartsOfAccounts Do
		
		SupplementManagersArrayWithRefType(Managers, ManagersForExchangePlans, MDObject, "ChartOfAccounts", ChartsOfAccounts[MDObject.Name], "ChartOfAccountsRef", True);
						
	EndDo;
	
	For Each MDObject IN Metadata.ChartsOfCalculationTypes Do
		
		SupplementManagersArrayWithRefType(Managers, ManagersForExchangePlans, MDObject, "ChartOfCalculationTypes", ChartsOfCalculationTypes[MDObject.Name], "ChartOfCalculationTypesRef", True);
				
	EndDo;
	
	For Each MDObject IN Metadata.ExchangePlans Do
		
		SupplementManagersArrayWithRefType(Managers, ManagersForExchangePlans, MDObject, "ExchangePlan", ExchangePlans[MDObject.Name], "ExchangePlanRef");
				
	EndDo;
	
	For Each MDObject IN Metadata.Tasks Do
		
		SupplementManagersArrayWithRefType(Managers, ManagersForExchangePlans, MDObject, "Task", Tasks[MDObject.Name], "TaskRef");
				
	EndDo;
	
	For Each MDObject IN Metadata.BusinessProcesses Do
		
		SupplementManagersArrayWithRefType(Managers, ManagersForExchangePlans, MDObject, "BusinessProcess", BusinessProcesses[MDObject.Name], "BusinessProcessRef");
		
		TypeName = "BusinessProcessRoutePoint";
		// ref to the route points
		Name              = MDObject.Name;
		Manager         = BusinessProcesses[Name].RoutePoints;
		SearchString     = "";
		RefTypeAsString = "BusinessProcessRoutePointRef." + Name;
		ReferenceType        = Type(RefTypeAsString);
		Structure = New Structure("Name,TypeName,RefTypeAsString,Manager,MDObject,OCR,EmptyRef,SearchByPredefinedPossible,SearchString", Name, 
			TypeName, RefTypeAsString, Manager, MDObject, , Undefined, False, SearchString);		
		Managers.Insert(ReferenceType, Structure);
				
	EndDo;
	
	// REGISTERS

	For Each MDObject IN Metadata.InformationRegisters Do
		
		SupplementManagersArrayWithRegisterType(Managers, MDObject, "InformationRegister", InformationRegisters[MDObject.Name], "InformationRegisterRecord", "InformationRegisterSelection");
						
	EndDo;

	For Each MDObject IN Metadata.AccountingRegisters Do
		
		SupplementManagersArrayWithRegisterType(Managers, MDObject, "AccountingRegister", AccountingRegisters[MDObject.Name], "AccountingRegisterRecord", "AccountingRegisterSelection");
				
	EndDo;
	
	For Each MDObject IN Metadata.AccumulationRegisters Do
		
		SupplementManagersArrayWithRegisterType(Managers, MDObject, "AccumulationRegister", AccumulationRegisters[MDObject.Name], "AccumulationRegisterRecord", "AccumulationRegisterSelection");
						
	EndDo;
	
	For Each MDObject IN Metadata.CalculationRegisters Do
		
		SupplementManagersArrayWithRegisterType(Managers, MDObject, "CalculationRegister", CalculationRegisters[MDObject.Name], "CalculationRegisterRecord", "CalculationRegisterSelection");
						
	EndDo;
	
	TypeName = "Enum";
	
	For Each MDObject IN Metadata.Enums Do
		
		Name              = MDObject.Name;
		Manager         = Enums[Name];
		RefTypeAsString = "EnumRef." + Name;
		ReferenceType        = Type(RefTypeAsString);
		Structure = New Structure("Name,TypeName,RefTypeAsString,Manager,MDObject,OCR,EmptyRef,SearchByPredefinedPossible", Name, TypeName, RefTypeAsString, Manager, MDObject, , Enums[Name].EmptyRef(), False);
		Managers.Insert(ReferenceType, Structure);
		
	EndDo;
	
	// Constants
	TypeName             = "Constants";
	MDObject            = Metadata.Constants;
	Name					= "Constants";
	Manager			= Constants;
	RefTypeAsString	= "ConstantsSet";
	ReferenceType			= Type(RefTypeAsString);
	Structure = New Structure("Name,TypeName,RefTypeAsString,Manager,MDObject,SearchByPredefinedPossible,OCR", Name, TypeName, RefTypeAsString, Manager, MDObject, False);
	Managers.Insert(ReferenceType, Structure);
	
EndProcedure

Procedure InitializeManagersAndMessages()
	
	If Managers = Undefined Then
		ManagersInitialization();
	EndIf; 

	If ErrorMessages = Undefined Then
		MessagesInitialization();
	EndIf;
	
EndProcedure

Procedure CreateConversionStructure()
	
	Conversion = New Structure("BeforeDataExport, AfterDataExport, BeforeGetChangedObjects, AfterGetExchangeNodeDetails, BeforeObjectExport, AfterObjectExport, BeforeObjectConversion, BeforeObjectImport, AfterObjectImport, BeforeDataImport, AfterDataImport, OnGetDeletionInfo, BeforeSendDeletionInfo");
	Conversion.Insert("DeleteMappedObjectsFromTargetOnDeleteFromSource", False);
	Conversion.Insert("FormatVersion");
	Conversion.Insert("CreationDateTime");
	
EndProcedure

// Initializes data processor attributes and module variables.
//
// Parameters:
//  No.
// 
Procedure AttributesAndModuleVariablesInitialization()

	VisualExchangeSetupMode = False;
	CountProcessedObjectsForRefreshStatus = 100;
	
	StoredExportedObjectCountByTypes = 2000;
		
	ParametersInitialized        = False;
	
	KeepAdditionalWriteControlToXML = False;
	
	Managers    = Undefined;
	ErrorMessages  = Undefined;
	
	SetFlagOfError(False);
	
	CreateConversionStructure();
	
	Rules      = New Structure;
	Algorithms    = New Structure;
	AdditionalInformationProcessors = New Structure;
	Queries      = New Structure;

	Parameters    = New Structure;
	EventsAfterParameterImport = New Structure;
	
	AdditionalInformationProcessorParameters = New Structure;
    	
	XMLRules  = Undefined;
	
	// Types

	StringType                  = Type("String");
	BooleanType                  = Type("Boolean");
	NumberType                   = Type("Number");
	DateType                    = Type("Date");
	ValueStorageType       = Type("ValueStorage");
	UUIDType = Type("UUID");
	BinaryDataType          = Type("BinaryData");
	AccumulationRecordTypeType   = Type("AccumulationRecordType");
	ObjectDeletionType         = Type("ObjectDeletion");
	AccountTypeKind			       = Type("AccountType");
	TypeType                     = Type("Type");
	MapType            = Type("Map");
	
	String36Type  = New TypeDescription("String",, New StringQualifiers(36));
	String255Type = New TypeDescription("String",, New StringQualifiers(255));
	
	MapRegisterType    = Type("InformationRegisterRecordSet.InfobasesObjectsCompliance");

	EmptyDateValue		   = Date('00010101');

	// Xml node types
	
	XMLNodeTypeEndElement  = XMLNodeType.EndElement;
	XMLNodeTypeStartElement = XMLNodeType.StartElement;
	XMLNodeTypeText          = XMLNodeType.Text;
	
	DataLogFile = Undefined;
	
	TypeAndObjectNameMap = New Map();
	
	EmptyTypeValueMap = New Map;
	TypeDescriptionMap = New Map;
	
	EnableDocumentPosting = Metadata.ObjectProperties.Posting.Allow;
	
	ExchangeRuleInfoImportMode = False;
	
	ExchangeResultField = Undefined;
	
	CustomSearchFieldInfoOnDataExport = New Map();
	CustomSearchFieldInfoOnDataImport = New Map();
		
	ObjectMappingRegisterManager = InformationRegisters.InfobasesObjectsCompliance;
	
	// Query for determining information about objects match to substitute source references for the receiver reference.
	InfobaseObjectMappingQuery = New Query;
	InfobaseObjectMappingQuery.Text = "
	|SELECT TOP 1
	|	InfobasesObjectsCompliance.UniqueSourceHandleAsString AS UniqueSourceHandleAsString
	|FROM
	|	InformationRegister.InfobasesObjectsCompliance AS InfobasesObjectsCompliance
	|WHERE
	|	  InfobasesObjectsCompliance.InfobaseNode           = &InfobaseNode
	|	AND InfobasesObjectsCompliance.UniqueReceiverHandle = &UniqueReceiverHandle
	|	AND InfobasesObjectsCompliance.ReceiverType                     = &ReceiverType
	|	AND InfobasesObjectsCompliance.SourceType                     = &SourceType
	|";
	//
	
EndProcedure

Procedure SetFlagOfError(Value = True)
	
	ErrorFlagField = Value;
	
EndProcedure

Procedure Increment(Value, Val Iterator = 1)
	
	If TypeOf(Value) <> Type("Number") Then
		
		Value = 0;
		
	EndIf;
	
	Value = Value + Iterator;
	
EndProcedure

Procedure FixEndOfDataImport()
	
	DataExchangeStatus().ExchangeProcessResult = ExchangeProcessResult();
	DataExchangeStatus().ActionOnExchange         = Enums.ActionsAtExchange.DataImport;
	DataExchangeStatus().InfobaseNode    = ExchangeNodeForDataImport;
	
	InformationRegisters.DataExchangeStatus.AddRecord(DataExchangeStatus());
	
	// Write successful exchange execution to IR.
	If ExchangeProcessResult() = Enums.ExchangeExecutionResult.Completed Then
		
		// Create and fill in structure for a new record in IR.
		RecordStructure = New Structure("InfobaseNode, ActionOnExchange, EndDate");
		FillPropertyValues(RecordStructure, DataExchangeStatus());
		
		InformationRegisters.SuccessfulDataExchangeStatus.AddRecord(RecordStructure);
		
	EndIf;
	
EndProcedure

Procedure IncreaseExportedObjectsCounter()
	
	Increment(ExportedObjectCounterField);
	
EndProcedure

Procedure IncreaseImportedObjectsCounter()
	
	Increment(ImportedObjectCounterField);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// HANDLERS PROCEDURES

Function PropertyNamePCR(TabularSectionRow)
	
	If ValueIsFilled(TabularSectionRow.Source) Then
		Property = "_" + TrimAll(TabularSectionRow.Source);
	ElsIf ValueIsFilled(TabularSectionRow.Receiver) Then 
		Property = "_" + TrimAll(TabularSectionRow.Receiver);
	ElsIf ValueIsFilled(TabularSectionRow.ParameterForTransferName) Then
		Property = "_" + TrimAll(TabularSectionRow.ParameterForTransferName);
	Else
		Property = "";
	EndIf;
	
	Return Property;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Global handlers

Procedure ExecuteHandler_Conversion_AfterExchangeRuleImport()
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportingHandling, Conversion.ProcessorsNameAfterImportRulesExchange);
	
EndProcedure

Procedure ExecuteHandler_Conversion_BeforeDataExport(ExchangeFile, Cancel)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Cancel);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportingHandling, Conversion.NameOfHandlerBeforeDataExport, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Cancel = HandlerParameters[1];
	
EndProcedure

Procedure ExecuteHandler_Conversion_BeforeGetChangedObjects(Recipient, NodeForBackgroundExchange)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(Recipient);
	HandlerParameters.Add(NodeForBackgroundExchange);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportingHandling, Conversion.NameOfHandlerBeforeReceivingChangedObjects, HandlerParameters);
	
	Recipient = HandlerParameters[0];
	NodeForBackgroundExchange = HandlerParameters[1];
	
EndProcedure

Procedure ExecuteHandler_Conversion_AfterDataExport(ExchangeFile)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportingHandling, Conversion.ProcessorsNameAfterDataExport, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	
EndProcedure

Procedure ExecuteHandler_Conversion_BeforeObjectExport(ExchangeFile, Cancel, OCRName, Rule,
																IncomingData, OutgoingData, Object)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(Rule);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(Object);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportingHandling, Conversion.HandlerNameBeforeObjectExport, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Cancel = HandlerParameters[1];
	OCRName = HandlerParameters[2];
	Rule = HandlerParameters[3];
	IncomingData = HandlerParameters[4];
	OutgoingData = HandlerParameters[5];
	Object = HandlerParameters[6];
	
EndProcedure

Procedure ExecuteHandler_Conversion_AfterObjectExport(ExchangeFile, Object, OCRName, IncomingData,
															   OutgoingData, Referencenode)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Object);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(Referencenode);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportingHandling, Conversion.ProcessorsNameAfterObjectExport, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Object = HandlerParameters[1];
	OCRName = HandlerParameters[2];
	IncomingData = HandlerParameters[3];
	OutgoingData = HandlerParameters[4];
	Referencenode = HandlerParameters[5];
	
EndProcedure

Procedure ExecuteHandler_Conversion_BeforeObjectConversion(ExchangeFile, Source, IncomingData, OutgoingData,
																   OCRName, OCR, ExportedObjects, Cancel, ExportedDataKey,
																   RememberExported, DoNotReplaceObjectOnImport,
																   AllObjectsAreExported,GetRefNodeOnly, Receiver,
																   WriteMode, PostingMode, DoNotCreateIfNotFound)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(ExportedObjects);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(ExportedDataKey);
	HandlerParameters.Add(RememberExported);
	HandlerParameters.Add(DoNotReplaceObjectOnImport);
	HandlerParameters.Add(AllObjectsAreExported);
	HandlerParameters.Add(GetRefNodeOnly);
	HandlerParameters.Add(Receiver);
	HandlerParameters.Add(WriteMode);
	HandlerParameters.Add(PostingMode);
	HandlerParameters.Add(DoNotCreateIfNotFound);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportingHandling, Conversion.ProcessorsNameBeforeObjectConversion, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Source = HandlerParameters[1];
	IncomingData = HandlerParameters[2];
	OutgoingData = HandlerParameters[3];
	OCRName = HandlerParameters[4];
	OCR = HandlerParameters[5];
	ExportedObjects = HandlerParameters[6];
	Cancel = HandlerParameters[7];
	ExportedDataKey = HandlerParameters[8];
	RememberExported = HandlerParameters[9];
	DoNotReplaceObjectOnImport = HandlerParameters[10];
	AllObjectsAreExported = HandlerParameters[11];
	GetRefNodeOnly = HandlerParameters[12];
	Receiver = HandlerParameters[13];
	WriteMode = HandlerParameters[14];
	PostingMode = HandlerParameters[15];
	DoNotCreateIfNotFound = HandlerParameters[16];
	
EndProcedure

Procedure ExecuteHandler_Conversion_BeforeSendDeletionInfo(Ref, Cancel)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(Ref);
	HandlerParameters.Add(Cancel);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportingHandling, Conversion.NameOfHandlerBeforeUninstallInformation, HandlerParameters);
	
	Ref = HandlerParameters[0];
	Cancel = HandlerParameters[1];
	
EndProcedure

Procedure ExecuteHandler_Conversion_BeforeDataImport(ExchangeFile, Cancel)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Cancel);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportProcessing, Conversion.NameOfHandlerBeforeImportingData, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Cancel = HandlerParameters[1];
	
EndProcedure

Procedure ExecuteHandler_Conversion_AfterDataImport()
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportProcessing, Conversion.NameOfHandlerAfterDataImport);
	
EndProcedure

Procedure ExecuteHandler_Conversion_BeforeObjectImport(ExchangeFile, Cancel, NPP, Source, Rulename, Rule,
																Generatenewnumberorcodeifnotspecified,ObjectTypeAsString,
																ObjectType, Donotreplaceobject, WriteMode, PostingMode)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(NPP);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(Rulename);
	HandlerParameters.Add(Rule);
	HandlerParameters.Add(Generatenewnumberorcodeifnotspecified);
	HandlerParameters.Add(ObjectTypeAsString);
	HandlerParameters.Add(ObjectType);
	HandlerParameters.Add(Donotreplaceobject);
	HandlerParameters.Add(WriteMode);
	HandlerParameters.Add(PostingMode);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportProcessing, Conversion.ProcessorsNameBeforeObjectImport, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Cancel = HandlerParameters[1];
	NPP = HandlerParameters[2];
	Source = HandlerParameters[3];
	Rulename = HandlerParameters[4];
	Rule = HandlerParameters[5];
	Generatenewnumberorcodeifnotspecified = HandlerParameters[6];
	ObjectTypeAsString = HandlerParameters[7];
	ObjectType = HandlerParameters[8];
	Donotreplaceobject = HandlerParameters[9];
	WriteMode = HandlerParameters[10];
	PostingMode = HandlerParameters[11];
	
EndProcedure

Procedure ExecuteHandler_Conversion_AftertObjectImport(ExchangeFile, Cancel, Ref, Object, ObjectParameters,
															   ObjectModified, ObjectTypeName, ObjectFound)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(Ref);
	HandlerParameters.Add(Object);
	HandlerParameters.Add(ObjectParameters);
	HandlerParameters.Add(ObjectModified);
	HandlerParameters.Add(ObjectTypeName);
	HandlerParameters.Add(ObjectFound);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportProcessing, Conversion.NameOfHandlerAftertObjectImport, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Cancel = HandlerParameters[1];
	Ref = HandlerParameters[2];
	Object = HandlerParameters[3];
	ObjectParameters = HandlerParameters[4];
	ObjectModified = HandlerParameters[5];
	ObjectTypeName = HandlerParameters[6];
	ObjectFound = HandlerParameters[7];
	
EndProcedure

Procedure ExecuteHandler_Conversion_OnGetDeletionInfo(Object, Cancel)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(Object);
	HandlerParameters.Add(Cancel);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportProcessing, Conversion.NameOfHandlerForReceivingInformationAboutRemoving, HandlerParameters);
	
	Object = HandlerParameters[0];
	Cancel = HandlerParameters[1];
	
EndProcedure

Procedure ExecuteHandler_Conversion_AfterParametersImport(ExchangeFile, Cancel, CancelReason)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(CancelReason);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportProcessing, "Conversion_afterloadofparameters", HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Cancel = HandlerParameters[1];
	CancelReason = HandlerParameters[2];
	
EndProcedure

Procedure ExecuteHandler_Conversion_AfterGetExchangeNodeDetails(Val ExchangeNodeForDataImport)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeNodeForDataImport);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportProcessing, Conversion.NameOfHandlerUponReceivingInformationAboutNodesOfExchange, HandlerParameters);
	
	ExchangeNodeForDataImport = HandlerParameters[0];
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// OCR handlers

Procedure ExecuteHandler_OCR_BeforeObjectExport(ExchangeFile, Source, IncomingData, OutgoingData,
														OCRName, OCR, ExportedObjects, Cancel, ExportedDataKey,
														RememberExported, DoNotReplaceObjectOnImport,
														AllObjectsAreExported, GetRefNodeOnly, Receiver,
														WriteMode, PostingMode, DoNotCreateIfNotFound)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(ExportedObjects);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(ExportedDataKey);
	HandlerParameters.Add(RememberExported);
	HandlerParameters.Add(DoNotReplaceObjectOnImport);
	HandlerParameters.Add(AllObjectsAreExported);
	HandlerParameters.Add(GetRefNodeOnly);
	HandlerParameters.Add(Receiver);
	HandlerParameters.Add(WriteMode);
	HandlerParameters.Add(PostingMode);
	HandlerParameters.Add(DoNotCreateIfNotFound);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportingHandling, OCR.ProcessorsNameBeforeExport, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Source = HandlerParameters[1];
	IncomingData = HandlerParameters[2];
	OutgoingData = HandlerParameters[3];
	OCRName = HandlerParameters[4];
	OCR = HandlerParameters[5];
	ExportedObjects = HandlerParameters[6];
	Cancel = HandlerParameters[7];
	ExportedDataKey = HandlerParameters[8];
	RememberExported = HandlerParameters[9];
	DoNotReplaceObjectOnImport = HandlerParameters[10];
	AllObjectsAreExported = HandlerParameters[11];
	GetRefNodeOnly = HandlerParameters[12];
	Receiver = HandlerParameters[13];
	WriteMode = HandlerParameters[14];
	PostingMode = HandlerParameters[15];
	DoNotCreateIfNotFound = HandlerParameters[16];
	
EndProcedure

Procedure ExecuteHandler_OCR_OnExportObject(ExchangeFile, Source, IncomingData, OutgoingData, OCRName, OCR,
													 ExportedObjects, ExportedDataKey, Cancel, StandardProcessing,
													 Receiver, Referencenode)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(ExportedObjects);
	HandlerParameters.Add(ExportedDataKey);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(StandardProcessing);
	HandlerParameters.Add(Receiver);
	HandlerParameters.Add(Referencenode);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportingHandling, OCR.HandlerNameOnDump, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Source = HandlerParameters[1];
	IncomingData = HandlerParameters[2];
	OutgoingData = HandlerParameters[3];
	OCRName = HandlerParameters[4];
	OCR = HandlerParameters[5];
	ExportedObjects = HandlerParameters[6];
	ExportedDataKey = HandlerParameters[7];
	Cancel = HandlerParameters[8];
	StandardProcessing = HandlerParameters[9];
	Receiver = HandlerParameters[10];
	Referencenode = HandlerParameters[11];
	
EndProcedure

Procedure ExecuteHandler_OCR_AfterObjectExport(ExchangeFile, Source, IncomingData, OutgoingData, OCRName, OCR,
													   ExportedObjects, ExportedDataKey, Cancel, Receiver, Referencenode)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(ExportedObjects);
	HandlerParameters.Add(ExportedDataKey);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(Receiver);
	HandlerParameters.Add(Referencenode);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportingHandling, OCR.HandlerNameAfterDump, HandlerParameters);
		
	ExchangeFile = HandlerParameters[0];
	Source = HandlerParameters[1];
	IncomingData = HandlerParameters[2];
	OutgoingData = HandlerParameters[3];
	OCRName = HandlerParameters[4];
	OCR = HandlerParameters[5];
	ExportedObjects = HandlerParameters[6];
	ExportedDataKey = HandlerParameters[7];
	Cancel = HandlerParameters[8];
	Receiver = HandlerParameters[9];
	Referencenode = HandlerParameters[10];
	
EndProcedure

Procedure ExecuteHandler_OCR_AfterObjectExportToExchangeFile(ExchangeFile, Source, IncomingData, OutgoingData, OCRName, OCR,
																  ExportedObjects, Receiver, Referencenode)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(ExportedObjects);
	HandlerParameters.Add(Receiver);
	HandlerParameters.Add(Referencenode);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportingHandling, OCR.HandlerNameAfterDumpToFile, HandlerParameters);
		
	ExchangeFile = HandlerParameters[0];
	Source = HandlerParameters[1];
	IncomingData = HandlerParameters[2];
	OutgoingData = HandlerParameters[3];
	OCRName = HandlerParameters[4];
	OCR = HandlerParameters[5];
	ExportedObjects = HandlerParameters[6];
	Receiver = HandlerParameters[7];
	Referencenode = HandlerParameters[8];
	
EndProcedure

Procedure ExecuteHandler_OCR_BeforeObjectImport(ExchangeFile, Cancel, NPP, Source, Rulename, Rule,
														Generatenewnumberorcodeifnotspecified, ObjectTypeAsString,
														ObjectType,Donotreplaceobject, WriteMode, PostingMode)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(NPP);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(Rulename);
	HandlerParameters.Add(Rule);
	HandlerParameters.Add(Generatenewnumberorcodeifnotspecified);
	HandlerParameters.Add(ObjectTypeAsString);
	HandlerParameters.Add(ObjectType);
	HandlerParameters.Add(Donotreplaceobject);
	HandlerParameters.Add(WriteMode);
	HandlerParameters.Add(PostingMode);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportProcessing, Rule.HandlerNameBeforeImport, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Cancel = HandlerParameters[1];
	NPP = HandlerParameters[2];
	Source = HandlerParameters[3];
	Rulename = HandlerParameters[4];
	Rule = HandlerParameters[5];
	Generatenewnumberorcodeifnotspecified = HandlerParameters[6];
	ObjectTypeAsString = HandlerParameters[7];
	ObjectType = HandlerParameters[8];
	Donotreplaceobject = HandlerParameters[9];
	WriteMode = HandlerParameters[10];
	PostingMode = HandlerParameters[11];
	
EndProcedure

Procedure ExecuteHandler_OCR_OnImportObject(ExchangeFile, ObjectFound, Object, Donotreplaceobject, ObjectModified, Rule)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(ObjectFound);
	HandlerParameters.Add(Object);
	HandlerParameters.Add(Donotreplaceobject);
	HandlerParameters.Add(ObjectModified);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportProcessing, Rule.OnImportingNameProcessors, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	ObjectFound = HandlerParameters[1];
	Object = HandlerParameters[2];
	Donotreplaceobject = HandlerParameters[3];
	ObjectModified = HandlerParameters[4];
	
EndProcedure

Procedure ExecuteHandler_OCR_AftertObjectImport(ExchangeFile, Cancel, Ref, Object, ObjectParameters,
													   ObjectModified, ObjectTypeName, ObjectFound, Rule)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(Ref);
	HandlerParameters.Add(Object);
	HandlerParameters.Add(ObjectParameters);
	HandlerParameters.Add(ObjectModified);
	HandlerParameters.Add(ObjectTypeName);
	HandlerParameters.Add(ObjectFound);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportProcessing, Rule.ProcessorsNameAfterImport, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Cancel = HandlerParameters[1];
	Ref = HandlerParameters[2];
	Object = HandlerParameters[3];
	ObjectParameters = HandlerParameters[4];
	ObjectModified = HandlerParameters[5];
	ObjectTypeName = HandlerParameters[6];
	ObjectFound = HandlerParameters[7];
	
EndProcedure

Procedure ExecuteHandler_OCR_SearchFieldSequence(Variantsearchnumber, SearchProperties, ObjectParameters, StopSearch,
																ObjectReference, SetAllObjectSearchProperties,
																Stringofsearchpropertynames, HandlerName)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(Variantsearchnumber);
	HandlerParameters.Add(SearchProperties);
	HandlerParameters.Add(ObjectParameters);
	HandlerParameters.Add(StopSearch);
	HandlerParameters.Add(ObjectReference);
	HandlerParameters.Add(SetAllObjectSearchProperties);
	HandlerParameters.Add(Stringofsearchpropertynames);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportProcessing, HandlerName, HandlerParameters);
		
	Variantsearchnumber = HandlerParameters[0];
	SearchProperties = HandlerParameters[1];
	ObjectParameters = HandlerParameters[2];
	StopSearch = HandlerParameters[3];
	ObjectReference = HandlerParameters[4];
	SetAllObjectSearchProperties = HandlerParameters[5];
	Stringofsearchpropertynames = HandlerParameters[6];
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PCR handlers

Procedure ExecuteHandler_PCR_BeforeExportProperty(ExchangeFile, Source, Receiver, IncomingData, OutgoingData,
														 PCR, OCR, CollectionObject, Cancel, Value, ReceiverType, OCRName,
														 OCRNameextdimensiontype, Empty, Expression, PropertyCollectionNode, Donotreplace,
														 ExportObject)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(Receiver);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(PCR);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(CollectionObject);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(Value);
	HandlerParameters.Add(ReceiverType);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(OCRNameextdimensiontype);
	HandlerParameters.Add(Empty);
	HandlerParameters.Add(Expression);
	HandlerParameters.Add(PropertyCollectionNode);
	HandlerParameters.Add(Donotreplace);
	HandlerParameters.Add(ExportObject);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportingHandling, PCR.ProcessorsNameBeforeExport, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Source = HandlerParameters[1];
	Receiver = HandlerParameters[2];
	IncomingData = HandlerParameters[3];
	OutgoingData = HandlerParameters[4];
	PCR = HandlerParameters[5];
	OCR = HandlerParameters[6];
	CollectionObject = HandlerParameters[7];
	Cancel = HandlerParameters[8];
	Value = HandlerParameters[9];
	ReceiverType = HandlerParameters[10];
	OCRName = HandlerParameters[11];
	OCRNameextdimensiontype = HandlerParameters[12];
	Empty = HandlerParameters[13];
	Expression = HandlerParameters[14];
	PropertyCollectionNode = HandlerParameters[15];
	Donotreplace = HandlerParameters[16];
	ExportObject = HandlerParameters[17];
	
EndProcedure

Procedure ExecuteHandler_PCR_OnExportProperty(ExchangeFile, Source, Receiver, IncomingData, OutgoingData,
													  PCR, OCR, CollectionObject, Cancel, Value, KeyAndValue, ExtDimensionType,
													  ExtDimension, Empty, OCRName, OCRProperties,Propirtiesnode, PropertyCollectionNode,
													  OCRNameextdimensiontype, ExportObject)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(Receiver);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(PCR);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(CollectionObject);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(Value);
	HandlerParameters.Add(KeyAndValue);
	HandlerParameters.Add(ExtDimensionType);
	HandlerParameters.Add(ExtDimension);
	HandlerParameters.Add(Empty);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(OCRProperties);
	HandlerParameters.Add(Propirtiesnode);
	HandlerParameters.Add(PropertyCollectionNode);
	HandlerParameters.Add(OCRNameextdimensiontype);
	HandlerParameters.Add(ExportObject);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportingHandling, PCR.HandlerNameOnDump, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Source = HandlerParameters[1];
	Receiver = HandlerParameters[2];
	IncomingData = HandlerParameters[3];
	OutgoingData = HandlerParameters[4];
	PCR = HandlerParameters[5];
	OCR = HandlerParameters[6];
	CollectionObject = HandlerParameters[7];
	Cancel = HandlerParameters[8];
	Value = HandlerParameters[9];
	KeyAndValue = HandlerParameters[10];
	ExtDimensionType = HandlerParameters[11];
	ExtDimension = HandlerParameters[12];
	Empty = HandlerParameters[13];
	OCRName = HandlerParameters[14];
	OCRProperties = HandlerParameters[15];
	Propirtiesnode = HandlerParameters[16];
	PropertyCollectionNode = HandlerParameters[17];
	OCRNameextdimensiontype = HandlerParameters[18];
	ExportObject = HandlerParameters[19];
	
EndProcedure

Procedure ExecuteHandler_PCR_AfterExportProperty(ExchangeFile, Source, Receiver, IncomingData, OutgoingData,
														PCR, OCR, CollectionObject, Cancel, Value, KeyAndValue, ExtDimensionType,
														ExtDimension, OCRName, OCRNameextdimensiontype, OCRProperties, Propirtiesnode,
														Referencenode, PropertyCollectionNode, Nodeextdimension)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(Receiver);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(PCR);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(CollectionObject);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(Value);
	HandlerParameters.Add(KeyAndValue);
	HandlerParameters.Add(ExtDimensionType);
	HandlerParameters.Add(ExtDimension);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(OCRNameextdimensiontype);
	HandlerParameters.Add(OCRProperties);
	HandlerParameters.Add(Propirtiesnode);
	HandlerParameters.Add(Referencenode);
	HandlerParameters.Add(PropertyCollectionNode);
	HandlerParameters.Add(Nodeextdimension);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportingHandling, PCR.HandlerNameAfterDump, HandlerParameters);
		
	ExchangeFile = HandlerParameters[0];
	Source = HandlerParameters[1];
	Receiver = HandlerParameters[2];
	IncomingData = HandlerParameters[3];
	OutgoingData = HandlerParameters[4];
	PCR = HandlerParameters[5];
	OCR = HandlerParameters[6];
	CollectionObject = HandlerParameters[7];
	Cancel = HandlerParameters[8];
	Value = HandlerParameters[9];
	KeyAndValue = HandlerParameters[10];
	ExtDimensionType = HandlerParameters[11];
	ExtDimension = HandlerParameters[12];
	OCRName = HandlerParameters[13];
	OCRNameextdimensiontype = HandlerParameters[14];
	OCRProperties = HandlerParameters[15];
	Propirtiesnode = HandlerParameters[16];
	Referencenode = HandlerParameters[17];
	PropertyCollectionNode = HandlerParameters[18];
	Nodeextdimension = HandlerParameters[19];
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PGCR handlers

Procedure ExecuteHandler_PGCR_BeforeProcessExport(ExchangeFile, Source, Receiver, IncomingData, OutgoingData, OCR,
														   PGCR, Cancel, ObjectsCollection, Donotreplace, PropertyCollectionNode, Donotclear)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(Receiver);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(PGCR);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(ObjectsCollection);
	HandlerParameters.Add(Donotreplace);
	HandlerParameters.Add(PropertyCollectionNode);
	HandlerParameters.Add(Donotclear);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportingHandling, PGCR.ProcessorsNameBeforeProcessingExportings, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Source = HandlerParameters[1];
	Receiver = HandlerParameters[2];
	IncomingData = HandlerParameters[3];
	OutgoingData = HandlerParameters[4];
	OCR = HandlerParameters[5];
	PGCR = HandlerParameters[6];
	Cancel = HandlerParameters[7];
	ObjectsCollection = HandlerParameters[8];
	Donotreplace = HandlerParameters[9];
	PropertyCollectionNode = HandlerParameters[10];
	Donotclear = HandlerParameters[11];
	
EndProcedure

Procedure ExecuteHandler_PGCR_BeforeExportProperty(ExchangeFile, Source, Receiver, IncomingData, OutgoingData, OCR,
														  PGCR, Cancel, CollectionObject, PropertyCollectionNode, ObjectCollectionNode)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(Receiver);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(PGCR);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(CollectionObject);
	HandlerParameters.Add(PropertyCollectionNode);
	HandlerParameters.Add(ObjectCollectionNode);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportingHandling, PGCR.ProcessorsNameBeforeExport, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Source = HandlerParameters[1];
	Receiver = HandlerParameters[2];
	IncomingData = HandlerParameters[3];
	OutgoingData = HandlerParameters[4];
	OCR = HandlerParameters[5];
	PGCR = HandlerParameters[6];
	Cancel = HandlerParameters[7];
	CollectionObject = HandlerParameters[8];
	PropertyCollectionNode = HandlerParameters[9];
	ObjectCollectionNode = HandlerParameters[10];
	
EndProcedure

Procedure ExecuteHandler_PGCR_OnExportProperty(ExchangeFile, Source, Receiver, IncomingData, OutgoingData, OCR,
													   PGCR, CollectionObject, ObjectCollectionNode, CollectionObjectNode,
													   PropertyCollectionNode, StandardProcessing)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(Receiver);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(PGCR);
	HandlerParameters.Add(CollectionObject);
	HandlerParameters.Add(ObjectCollectionNode);
	HandlerParameters.Add(CollectionObjectNode);
	HandlerParameters.Add(PropertyCollectionNode);
	HandlerParameters.Add(StandardProcessing);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportingHandling, PGCR.HandlerNameOnDump, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Source = HandlerParameters[1];
	Receiver = HandlerParameters[2];
	IncomingData = HandlerParameters[3];
	OutgoingData = HandlerParameters[4];
	OCR = HandlerParameters[5];
	PGCR = HandlerParameters[6];
	CollectionObject = HandlerParameters[7];
	ObjectCollectionNode = HandlerParameters[8];
	CollectionObjectNode = HandlerParameters[9];
	PropertyCollectionNode = HandlerParameters[10];
	StandardProcessing = HandlerParameters[11];
	
EndProcedure

Procedure ExecuteHandler_PGCR_AfterExportProperty(ExchangeFile, Source, Receiver, IncomingData, OutgoingData,
														 OCR, PGCR, Cancel, CollectionObject, ObjectCollectionNode,
														 PropertyCollectionNode, CollectionObjectNode)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(Receiver);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(PGCR);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(CollectionObject);
	HandlerParameters.Add(ObjectCollectionNode);
	HandlerParameters.Add(PropertyCollectionNode);
	HandlerParameters.Add(CollectionObjectNode);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportingHandling, PGCR.HandlerNameAfterDump, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Source = HandlerParameters[1];
	Receiver = HandlerParameters[2];
	IncomingData = HandlerParameters[3];
	OutgoingData = HandlerParameters[4];
	OCR = HandlerParameters[5];
	PGCR = HandlerParameters[6];
	Cancel = HandlerParameters[7];
	CollectionObject = HandlerParameters[8];
	ObjectCollectionNode = HandlerParameters[9];
	PropertyCollectionNode = HandlerParameters[10];
	CollectionObjectNode = HandlerParameters[11];
	
EndProcedure

Procedure ExecuteHandler_PGCR_AfterProcessExport(ExchangeFile, Source, Receiver, IncomingData, OutgoingData,
														  OCR, PGCR, Cancel, PropertyCollectionNode, ObjectCollectionNode)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Source);
	HandlerParameters.Add(Receiver);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(OCR);
	HandlerParameters.Add(PGCR);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(PropertyCollectionNode);
	HandlerParameters.Add(ObjectCollectionNode);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportingHandling, PGCR.HandlerNameAfterDumpProcessing, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Source = HandlerParameters[1];
	Receiver = HandlerParameters[2];
	IncomingData = HandlerParameters[3];
	OutgoingData = HandlerParameters[4];
	OCR = HandlerParameters[5];
	PGCR = HandlerParameters[6];
	Cancel = HandlerParameters[7];
	PropertyCollectionNode = HandlerParameters[8];
	ObjectCollectionNode = HandlerParameters[9];
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// DDR handlers

Procedure ExecuteHandler_DDR_BeforeProcessRule(Cancel, OCRName, Rule, OutgoingData, DataSelection)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(Rule);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(DataSelection);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportingHandling, Rule.ProcessorsNameBeforeProcessing, HandlerParameters);
	
	Cancel = HandlerParameters[0];
	OCRName = HandlerParameters[1];
	Rule = HandlerParameters[2];
	OutgoingData = HandlerParameters[3];
	DataSelection = HandlerParameters[4];
	
EndProcedure

Procedure ExecuteHandler_DDR_AfterProcessRule(OCRName, Rule, OutgoingData)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(Rule);
	HandlerParameters.Add(OutgoingData);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportingHandling, Rule.ProcessorsNameAfterProcessing, HandlerParameters);
	
	OCRName = HandlerParameters[0];
	Rule = HandlerParameters[1];
	OutgoingData = HandlerParameters[2];
	
EndProcedure

Procedure ExecuteHandler_DDR_BeforeObjectExport(ExchangeFile, Cancel, OCRName, Rule,
														IncomingData, OutgoingData, Object)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(Rule);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(Object);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportingHandling, Rule.ProcessorsNameBeforeExport, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Cancel = HandlerParameters[1];
	OCRName = HandlerParameters[2];
	Rule = HandlerParameters[3];
	IncomingData = HandlerParameters[4];
	OutgoingData = HandlerParameters[5];
	Object = HandlerParameters[6];
	
EndProcedure

Procedure ExecuteHandler_DDR_AfterObjectExport(ExchangeFile, Object, OCRName, IncomingData,
													   OutgoingData, Referencenode, Rule)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(ExchangeFile);
	HandlerParameters.Add(Object);
	HandlerParameters.Add(OCRName);
	HandlerParameters.Add(IncomingData);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(Referencenode);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportingHandling, Rule.HandlerNameAfterDump, HandlerParameters);
	
	ExchangeFile = HandlerParameters[0];
	Object = HandlerParameters[1];
	OCRName = HandlerParameters[2];
	IncomingData = HandlerParameters[3];
	OutgoingData = HandlerParameters[4];
	Referencenode = HandlerParameters[5];
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// DCR handlers

Procedure ExecuteHandler_DCR_BeforeProcessRule(Rule, Cancel, OutgoingData, DataSelection)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(Rule);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(OutgoingData);
	HandlerParameters.Add(DataSelection);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportProcessing, Rule.ProcessorsNameBeforeProcessing, HandlerParameters);
	
	Rule = HandlerParameters[0];
	Cancel = HandlerParameters[1];
	OutgoingData = HandlerParameters[2];
	DataSelection = HandlerParameters[3];
	
EndProcedure

Procedure ExecuteHandler_DCR_BeforeDeleteObject(Rule, Object, Cancel, DeleteDirectly, IncomingData)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(Rule);
	HandlerParameters.Add(Object);
	HandlerParameters.Add(Cancel);
	HandlerParameters.Add(DeleteDirectly);
	HandlerParameters.Add(IncomingData);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportProcessing, Rule.HandlerNameBeforeDeletion, HandlerParameters);
	
	Rule = HandlerParameters[0];
	Object = HandlerParameters[1];
	Cancel = HandlerParameters[2];
	DeleteDirectly = HandlerParameters[3];
	IncomingData = HandlerParameters[4];
	
EndProcedure

Procedure ExecuteHandler_DCR_AfterProcessRule(Rule)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(Rule);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportProcessing, Rule.ProcessorsNameAfterProcessing, HandlerParameters);
	
	Rule = HandlerParameters[0];
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Parameters handlers

Procedure ExecuteHandler_Parameters_AfterParameterImport(Name, Value)
	
	HandlerParameters = New Array();
	HandlerParameters.Add(Name);
	HandlerParameters.Add(Value);
	
	HandlerName = "Parameters_[ParameterName]_AfterParameterImport";
	HandlerName = StrReplace(HandlerName, "[ParameterName]", Name);
	
	WorkInSafeMode.ExecuteObjectMethod(
		ImportProcessing, HandlerName, HandlerParameters);
	
	Name = HandlerParameters[0];
	Value = HandlerParameters[1];
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// CONSTANTS

Function VersionOfExchangeEventFormat()
	
	Return "3.1";
	
EndFunction

// Version of exchange rules storing format (read
// rules format) work with which is supported by this data processor.
//
// Exchange rules are read from file and saved to the infobase as storing.
// Rules storing format may expire. IN this case you should reread exchange rules.
//
Function FormatVersionStorageRulesExchange()
	
	Return 2;
	
EndFunction

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// MAIN PROGRAM OPERATORS

AttributesAndModuleVariablesInitialization();

ConversionRulesTableInitialization();
UnloadRulesTableInitialization();
ClearRulesTableInitialization();
ParametersSettingTableInitialization();
#EndIf
