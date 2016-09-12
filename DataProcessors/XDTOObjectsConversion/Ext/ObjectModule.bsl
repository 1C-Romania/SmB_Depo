#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

#Region ExportProperties

// Function-property: result of the data exchange.
//
// Type: EnumRef.ExchangeResults
//
Function ExchangeProcessResult() Export
	
	Return ExchangeComponents.DataExchangeStatus.ExchangeProcessResult;
	
EndFunction

// Function-property: quantity of objects that were imported.
//
// Type: Number
//
Function CounterOfImportedObjects() Export
	
	Return ExchangeComponents.CounterOfImportedObjects;
	
EndFunction

// Function-property: quantity of objects that were exported.
//
// Type: Number
//
Function DumpedObjectsCounter() Export
	
	Return ExchangeComponents.DumpedObjectsCounter;
	
EndFunction

// Function-property: row containing an error message on data exchange.
//
// Type: Row
//
Function ErrorMessageString() Export
	
	Return ExchangeComponents.ErrorMessageString;
	
EndFunction

// Function-property: check box showing data exchange execution.
//
// Type: Boolean
//
Function ErrorFlag() Export
	
	Return ExchangeComponents.ErrorFlag;
	
EndFunction

// Function-property: number of the data exchange message.
//
// Type: Number
//
Function MessageNo() Export
	
	Return ExchangeComponents.IncomingMessageNumber;
	
EndFunction

// Function-property: values table with statistical and additional information about exchange incoming message.
//
// Type: ValuesTable
//
Function DataTableOfPackageHeader() Export
	
	If ExchangeComponents = Undefined Then
		Return DataExchangeXDTOServer.PackageHeaderDataNewTable();
	Else
		Return ExchangeComponents.DataTableOfPackageHeader;
	EndIf;
	
EndFunction

// Function-property: match to tables of the incoming message exchange data
//
// Type: Map
//
Function DataTablesOfExchangeMessage() Export
	
	If ExchangeComponents = Undefined Then
		Return New Map;
	Else
		Return ExchangeComponents.DataTablesOfExchangeMessage;
	EndIf;
	
EndFunction

#EndRegion

#Region DataExport

// Data is
// exported -- All objects are exported to one file.
//
// Parameters:
// 
Procedure ExecuteDataExport(DataProcessorForDataImport = Undefined) Export
	
	ExchangeComponents = DataExchangeXDTOServer.InitializeExchangeComponents("sending");
	
	ExchangeComponents.KeepDataProtocol.OutputInInformationMessagesToProtocol = OutputInInformationMessagesToProtocol;
	ExchangeComponents.EventLogMonitorMessageKey = EventLogMonitorMessageKey;
	
	#Region ExchangeComponentsSettingsForWorkWithNode
	ExchangeComponents.CorrespondentNode = NodeForExchange;
	
	ExchangeComponents.ExchangeFormatVersion = DataExchangeXDTOServer.ExchangeFormatVersionOnExport(NodeForExchange);
	
	ExchangeFormat = DataExchangeXDTOServer.ExchangeFormat(
		NodeForExchange, ExchangeComponents.ExchangeFormatVersion);
	ExchangeComponents.XMLSchema = ExchangeFormat;
	
	ExchangeComponents.ExchangeManager = DataExchangeXDTOServer.FormatVersionExchangeManager(
		NodeForExchange, ExchangeComponents.ExchangeFormatVersion);
	
	ExchangeComponents.ObjectRegistrationRulesTable = DataExchangeXDTOServer.ObjectRegistrationRules(NodeForExchange);
	ExchangeComponents.ExchangePlanNodeProperties = DataExchangeXDTOServer.ExchangePlanNodeProperties(NodeForExchange);
	
	DataExchangeXDTOServer.InitializeExchangeRulesTables(ExchangeComponents);
	#EndRegion
	
	DataExchangeXDTOServer.ExchangeProtocolInitialization(ExchangeComponents, ExchangeProtocolFileName);
	
	// Open an exchange file
	DataExchangeXDTOServer.OpenExportFile(ExchangeComponents, ExchangeFileName);
	
	If ExchangeComponents.ErrorFlag Then
		ExchangeComponents.ExchangeFile = Undefined;
		DataExchangeXDTOServer.FinishExchangeProtocolLogging(ExchangeComponents);
		Return;
	EndIf;
	
	// DATA EXPORT
	Try
		DataExchangeXDTOServer.ExecuteDataExport(ExchangeComponents);
	Except
		If ExchangeComponents.IsExchangeThroughExchangePlan Then
			UnlockDataForEdit(NodeForExchange);
		EndIf;
		DataExchangeXDTOServer.WriteInExecutionProtocol(ExchangeComponents, DetailErrorDescription(ErrorInfo()));
		DataExchangeXDTOServer.FinishExchangeProtocolLogging(ExchangeComponents);
		ExchangeComponents.ExchangeFile = Undefined;
		Return;
	EndTry;
	
	ExchangeComponents.ExchangeFile.Close();
	
	DataExchangeXDTOServer.FinishExchangeProtocolLogging(ExchangeComponents);
	
EndProcedure

#EndRegion

#Region DataImport

// Imports data from message exchange file.
// Data is being imported to the infobase.
//
// Parameters:
// 
Procedure ExecuteDataImport() Export
	
	ExchangeComponents = DataExchangeXDTOServer.InitializeExchangeComponents("Get");
	ExchangeComponents.EventLogMonitorMessageKey = EventLogMonitorMessageKey;
	ExchangeComponents.CorrespondentNode = ExchangeNodeForDataImport;
	
	ExchangeComponents.KeepDataProtocol.OutputInInformationMessagesToProtocol = OutputInInformationMessagesToProtocol;
	DataImportMode = "ImportToInfobase";
	
	ExchangeComponents.DataExchangeStatus.StartDate = CurrentSessionDate();
	
	DataExchangeXDTOServer.ExchangeProtocolInitialization(ExchangeComponents, ExchangeProtocolFileName);
	
	If IsBlankString(ExchangeFileName) Then
		DataExchangeXDTOServer.WriteInExecutionProtocol(ExchangeComponents, 15);
		DataExchangeXDTOServer.FinishExchangeProtocolLogging(ExchangeComponents);
		Return;
	EndIf;
	
	If ContinueOnError Then
		UseTransactions = False;
		ExchangeComponents.UseTransactions = False;
	EndIf;
	
	DataExchangeXDTOServer.OpenImportFile(ExchangeComponents, ExchangeFileName);
	
	If ExchangeComponents.ErrorFlag Then
		DataExchangeXDTOServer.FinishExchangeProtocolLogging(ExchangeComponents);
		Return;
	EndIf;
	
	DataExchangeXDTOServer.InitializeExchangeRulesTables(ExchangeComponents);
	
	Try
		DataExchangeXDTOServer.ReadData(ExchangeComponents);
	Except
		MessageString = NStr("en='Error when importing the files: %1';ru='Ошибка при загрузке данных: %1'");
		MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, ErrorDescription());
		DataExchangeXDTOServer.WriteInExecutionProtocol(ExchangeComponents, MessageString,,,,,True);
		ExchangeComponents.ErrorFlag = True;
	EndTry;
	
	ExchangeComponents.ExchangeFile.Close();
	
	If Not ExchangeComponents.ErrorFlag Then
		
		// Write information about an incoming message number.
		NodeObject = ExchangeNodeForDataImport.GetObject();
		NodeObject.ReceivedNo = ExchangeComponents.IncomingMessageNumber;
		NodeObject.AdditionalProperties.Insert("GettingExchangeMessage");
		NodeObject.Write();
		
	EndIf;
	
	DataExchangeXDTOServer.FinishExchangeProtocolLogging(ExchangeComponents);
	
EndProcedure

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
	
	ExchangeComponents = DataExchangeXDTOServer.InitializeExchangeComponents("Get");
	ExchangeComponents.EventLogMonitorMessageKey = EventLogMonitorMessageKey;
	ExchangeComponents.KeepDataProtocol.OutputInInformationMessagesToProtocol = OutputInInformationMessagesToProtocol;
	ExchangeComponents.CorrespondentNode = ExchangeNodeForDataImport;
	
	DataImportMode = "ImportToInfobase";
	
	ExchangeComponents.DataExchangeStatus.StartDate = CurrentSessionDate();
	
	DataExchangeXDTOServer.OpenImportFile(ExchangeComponents, ExchangeFileName);
	
	If ExchangeComponents.ErrorFlag Then
		DataExchangeXDTOServer.FinishExchangeProtocolLogging(ExchangeComponents);
		Return;
	EndIf;
	
	DataExchangeXDTOServer.InitializeExchangeRulesTables(ExchangeComponents);
	
	// Record in the events log monitor.
	MessageString = NStr("en='Beginning of data exchange process for node: %1';ru='Начало процесса обмена данными для узла: %1'", CommonUseClientServer.MainLanguageCode());
	MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, String(ExchangeNodeForDataImport));
	DataExchangeXDTOServer.WriteLogEventDataExchange(MessageString, ExchangeComponents, EventLogLevel.Information);
	
	DataExchangeXDTOServer.ReadData(ExchangeComponents, TableToImport);
	
	// Record in the events log monitor.
	MessageString = NStr("en='%1, %2; Processed %3 objects';ru='%1, %2; Обработано %3 объектов'", CommonUseClientServer.MainLanguageCode());
	MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString,
					ExchangeComponents.DataExchangeStatus.ExchangeProcessResult,
					Enums.ActionsAtExchange.DataImport,
					Format(ExchangeComponents.CounterOfImportedObjects, "NG=0"));
	
	DataExchangeXDTOServer.WriteLogEventDataExchange(MessageString, ExchangeComponents, EventLogLevel.Information);
	
EndProcedure

// Sequentially reads exchange message file and when it is happening:
//  - registration of changes by an incoming receipt number is deleted
//  - exchange rules are being imported
//  - information about data types is being imported
//  - read information of the data match and write and IB
//  - information about objects types and their quantity is collected.
//
// Parameters:
//  No.
// 
Procedure RunExchangeMessageAnalysis(AnalysisParameters = Undefined) Export
	
	DataImportMode = "ImportToValueTable";
	UseTransactions = False;
	
	ExchangeComponents = DataExchangeXDTOServer.InitializeExchangeComponents("Get");
	ExchangeComponents.KeepDataProtocol.OutputInInformationMessagesToProtocol = OutputInInformationMessagesToProtocol;
	ExchangeComponents.EventLogMonitorMessageKey = EventLogMonitorMessageKey;
	ExchangeComponents.CorrespondentNode = ExchangeNodeForDataImport;
	ExchangeComponents.DataImportToInformationBaseMode = False;
	
	DataExchangeXDTOServer.ExchangeProtocolInitialization(ExchangeComponents, ExchangeProtocolFileName);
	
	If IsBlankString(ExchangeFileName) Then
		DataExchangeXDTOServer.WriteInExecutionProtocol(ExchangeComponents, 15);
		DataExchangeXDTOServer.FinishExchangeProtocolLogging(ExchangeComponents);
		Return;
	EndIf;
	
	// analysis begin date
	ExchangeComponents.DataExchangeStatus.StartDate = CurrentSessionDate();
	
	DataExchangeXDTOServer.OpenImportFile(ExchangeComponents, ExchangeFileName);
	
	If ExchangeComponents.ErrorFlag Then
		DataExchangeXDTOServer.FinishExchangeProtocolLogging(ExchangeComponents);
		Return;
	EndIf;
	
	DataExchangeXDTOServer.InitializeExchangeRulesTables(ExchangeComponents);
	
	Try
		
		// Read data from an exchange message.
		DataExchangeXDTOServer.ReadDataInAnalysisMode(ExchangeComponents, AnalysisParameters);
		
		// Generate a temporary data table.
		TemporaryPackageHeaderDataTable = ExchangeComponents.DataTableOfPackageHeader.Copy(, "SourceTypeAsString, ReceiverTypeAsString, SearchField, TableFields");
		TemporaryPackageHeaderDataTable.GroupBy("SourceTypeAsString, ReceiverTypeAsString, SearchField, TableFields");
		
		// Collapse table of pack title data.
		ExchangeComponents.DataTableOfPackageHeader.GroupBy(
			"ObjectTypeAsString, SourceTypeAsString, ReceiverTypeAsString, SynchronizeByID, IsClassifier, IsObjectDeletion, UsePreview",
			"ObjectsCountInSource"
		);
		//
		ExchangeComponents.DataTableOfPackageHeader.Columns.Add("SearchFields",  New TypeDescription("String"));
		ExchangeComponents.DataTableOfPackageHeader.Columns.Add("TableFields", New TypeDescription("String"));
		
		For Each TableRow IN ExchangeComponents.DataTableOfPackageHeader Do
			
			Filter = New Structure;
			Filter.Insert("SourceTypeAsString", TableRow.SourceTypeAsString);
			Filter.Insert("ReceiverTypeAsString", TableRow.ReceiverTypeAsString);
			
			TemporaryTableRows = TemporaryPackageHeaderDataTable.FindRows(Filter);
			
			TableRow.SearchFields  = TemporaryTableRows[0].SearchFields;
			TableRow.TableFields = TemporaryTableRows[0].TableFields;
			
		EndDo;
		
	Except
		MessageString = NStr("en='Error when analyzing the data: %1';ru='Ошибка при анализе данных: %1'");
		MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, ErrorDescription());
		DataExchangeXDTOServer.WriteInExecutionProtocol(ExchangeComponents, MessageString,,,,,True);
	EndTry;
	
	ExchangeComponents.ExchangeFile.Close();
	
	DataExchangeXDTOServer.FinishExchangeProtocolLogging(ExchangeComponents);
	
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
	UseTransactions = False;
	
	If ExchangeComponents = Undefined Then
		
		ExchangeComponents = DataExchangeXDTOServer.InitializeExchangeComponents("Get");
		ExchangeComponents.EventLogMonitorMessageKey = EventLogMonitorMessageKey;
		ExchangeComponents.KeepDataProtocol.OutputInInformationMessagesToProtocol = OutputInInformationMessagesToProtocol;
		ExchangeComponents.CorrespondentNode = ExchangeNodeForDataImport;
	
		DataExchangeXDTOServer.OpenImportFile(ExchangeComponents, ExchangeFileName);
	
		If ExchangeComponents.ErrorFlag Then
			DataExchangeXDTOServer.FinishExchangeProtocolLogging(ExchangeComponents);
			Return;
		EndIf;
		
		DataExchangeXDTOServer.InitializeExchangeRulesTables(ExchangeComponents);
	Else
		DataExchangeXDTOServer.OpenImportFile(ExchangeComponents, ExchangeFileName);
	EndIf;
	
	ExchangeComponents.DataExchangeStatus.StartDate = CurrentSessionDate();
	ExchangeComponents.DataImportToInformationBaseMode = False;
	
	// Initialize table of exchange message data.
	For Each DataTableKey IN TableToImport Do
		
		SubstringArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(DataTableKey, "#");
		
		ObjectType = SubstringArray[1];
		
		ExchangeComponents.DataTablesOfExchangeMessage.Insert(DataTableKey, InitializationOfTableOfDataOfExchangeMessage(Type(ObjectType)));
		
	EndDo;
	
	DataExchangeXDTOServer.ReadData(ExchangeComponents, TableToImport);
	
EndProcedure

#EndRegion

#EndRegion

#Region Other

Function InitializationOfTableOfDataOfExchangeMessage(ObjectType)
	
	ExchangeMessageDataTable = New ValueTable;
	
	Columns = ExchangeMessageDataTable.Columns;
	
	// mandatory fields
	Columns.Add("UUID", New TypeDescription("String",, New StringQualifiers(36)));
	Columns.Add("TypeAsString",              New TypeDescription("String",, New StringQualifiers(255)));
	
	MetadataObject = Metadata.FindByType(ObjectType);
	
	// Receive description of all fields of metadata object from the configuration.
	TableOfDescriptionOfObjectProperties = CommonUse.GetTableOfDescriptionOfObjectProperties(MetadataObject, "Name, Type");
	
	For Each PropertyDetails IN TableOfDescriptionOfObjectProperties Do
		
		Columns.Add(PropertyDetails.Name, PropertyDetails.Type);
		
	EndDo;
	
	Return ExchangeMessageDataTable;
	
EndFunction

#EndRegion

#Region MainProgramOperators

Parameters = New Structure;

#EndRegion

#EndIf