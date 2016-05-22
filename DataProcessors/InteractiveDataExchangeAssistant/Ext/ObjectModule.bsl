#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Export service procedures and functions.

// Gets object compliance statistics for table rows StatisticsInformation.
//
// Parameters:
//      Cancel        - Boolean - refusal flag which is set to True when there were errors during the execution of the procedure.
//      RowIndexes - Array - table row indexes
//                              StatisticsInformation for which it is required to receive information of compliance statistics.
//                              If it isn't specified then the operation will be completed for all table rows.
// 
Procedure GetObjectMappingStatsByString(Cancel, RowIndexes = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If RowIndexes = Undefined Then
		
		RowIndexes = New Array;
		
		For Each TableRow IN StatisticsInformation Do
			
			RowIndexes.Add(StatisticsInformation.IndexOf(TableRow));
			
		EndDo;
		
	EndIf;
	
	// Execute data import from exchange message in the cache immediately for several tables.
	ExecuteDataImportFromExchangeMessageToCache(Cancel, RowIndexes);
	
	If Cancel Then
		Return;
	EndIf;
	
	InfobaseObjectsMapping = DataProcessors.InfobaseObjectsMapping.Create();
	
	// Get information of compliance digest separately for each table.
	For Each RowIndex IN RowIndexes Do
		
		TableRow = StatisticsInformation[RowIndex];
		
		If Not TableRow.SynchronizeByID Then
			Continue;
		EndIf;
		
		// Data processor property initialization.
		InfobaseObjectsMapping.ReceiverTableName            = TableRow.ReceiverTableName;
		InfobaseObjectsMapping.TableSourceObjectTypeName = TableRow.ObjectTypeAsString;
		InfobaseObjectsMapping.InfobaseNode         = InfobaseNode;
		InfobaseObjectsMapping.ExchangeMessageFileName        = ExchangeMessageFileName;
		
		InfobaseObjectsMapping.SourceTypeAsString = TableRow.SourceTypeAsString;
		InfobaseObjectsMapping.ReceiverTypeAsString = TableRow.ReceiverTypeAsString;
		
		// Assistant
		InfobaseObjectsMapping.Assistant();
		
		// Get information of compliance digest.
		InfobaseObjectsMapping.GetInformationOfDigestOfObjectsMapping(Cancel);
		
		// Information of compliance digest.
		TableRow.ObjectsCountInSource       = InfobaseObjectsMapping.ObjectsCountInSource();
		TableRow.ObjectsCountInReceiver       = InfobaseObjectsMapping.ObjectsCountInReceiver();
		TableRow.NumberOfObjectsMapped   = InfobaseObjectsMapping.NumberOfObjectsMapped();
		TableRow.UnmappedObjectsCount = InfobaseObjectsMapping.UnmappedObjectsCount();
		TableRow.ObjectsMappingPercent       = InfobaseObjectsMapping.ObjectsMappingPercent();
		TableRow.PictureIndex                     = DataExchangeServer.InformationStatisticsTablePictureIndex(TableRow.UnmappedObjectsCount, TableRow.DataSuccessfullyImported);
		
	EndDo;
	
EndProcedure

// Executes automatic infobase object compliance
//  with the specified values default and receives object
//  compliance statistics after automatic compliance.
//
// Parameters:
//      Cancel        - Boolean - refusal flag which is set to True when there were errors during the execution of the procedure.
//      RowIndexes - Array - table row indexes
//                              StatisticsInformation for which it is required to execute automatic
//                              compliance and receive statistics information.
//                              If it isn't specified then the operation will be completed for all table rows.
// 
Procedure RunAutomaticMappingByDefaultAndGetMappingStats(Cancel, RowIndexes = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If RowIndexes = Undefined Then
		
		RowIndexes = New Array;
		
		For Each TableRow IN StatisticsInformation Do
			
			RowIndexes.Add(StatisticsInformation.IndexOf(TableRow));
			
		EndDo;
		
	EndIf;
	
	// Execute data import from exchange message in the cache immediately for several tables.
	ExecuteDataImportFromExchangeMessageToCache(Cancel, RowIndexes);
	
	If Cancel Then
		Return;
	EndIf;
	
	InfobaseObjectsMapping = DataProcessors.InfobaseObjectsMapping.Create();
	
	// Execute automatic
	// compliance get information of compliance digest.
	For Each RowIndex IN RowIndexes Do
		
		TableRow = StatisticsInformation[RowIndex];
		
		If Not TableRow.SynchronizeByID Then
			Continue;
		EndIf;
		
		// Data processor property initialization.
		InfobaseObjectsMapping.ReceiverTableName            = TableRow.ReceiverTableName;
		InfobaseObjectsMapping.TableSourceObjectTypeName = TableRow.ObjectTypeAsString;
		InfobaseObjectsMapping.ReceiverTableFields           = TableRow.TableFields;
		InfobaseObjectsMapping.SearchFieldsOfReceiverTable     = TableRow.SearchFields;
		InfobaseObjectsMapping.InfobaseNode         = InfobaseNode;
		InfobaseObjectsMapping.ExchangeMessageFileName        = ExchangeMessageFileName;
		
		InfobaseObjectsMapping.SourceTypeAsString = TableRow.SourceTypeAsString;
		InfobaseObjectsMapping.ReceiverTypeAsString = TableRow.ReceiverTypeAsString;
		
		// Assistant
		InfobaseObjectsMapping.Assistant();
		
		// Execute automatic object compliance default.
		InfobaseObjectsMapping.RunAutomaticMappingByDefault(Cancel);
		
		// Get information of compliance digest.
		InfobaseObjectsMapping.GetInformationOfDigestOfObjectsMapping(Cancel);
		
		// Information of compliance digest.
		TableRow.ObjectsCountInSource       = InfobaseObjectsMapping.ObjectsCountInSource();
		TableRow.ObjectsCountInReceiver       = InfobaseObjectsMapping.ObjectsCountInReceiver();
		TableRow.NumberOfObjectsMapped   = InfobaseObjectsMapping.NumberOfObjectsMapped();
		TableRow.UnmappedObjectsCount = InfobaseObjectsMapping.UnmappedObjectsCount();
		TableRow.ObjectsMappingPercent       = InfobaseObjectsMapping.ObjectsMappingPercent();
		TableRow.PictureIndex                     = DataExchangeServer.InformationStatisticsTablePictureIndex(TableRow.UnmappedObjectsCount, TableRow.DataSuccessfullyImported);
		
	EndDo;
	
EndProcedure

// Imports data into the infobase for table rows StatisticsInformation.
//  IN case if all exchange message data will
//  be imported then in the exchange node number of incoming message will be written.
//  This means that message data is completely imported into the infobase.
//  Reimporting this message will be cancelled.
//
// Parameters:
//       Cancel        - Boolean - refusal flag which is set to True when there were errors during the execution of the procedure.
//       RowIndexes - Array - Table row indexes
//                               StatisticsInformation for which it is required to import data.
//                               If it isn't specified then the operation will be completed for all table rows.
// 
Procedure ExecuteDataImport(Cancel, RowIndexes = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If RowIndexes = Undefined Then
		
		RowIndexes = New Array;
		
		For Each TableRow IN StatisticsInformation Do
			
			RowIndexes.Add(StatisticsInformation.IndexOf(TableRow));
			
		EndDo;
		
	EndIf;
	
	TableToImport = New Array;
	
	For Each RowIndex IN RowIndexes Do
		
		TableRow = StatisticsInformation[RowIndex];
		
		DataTableKey = DataExchangeServer.DataTableKey(TableRow.SourceTypeAsString, TableRow.ReceiverTypeAsString, TableRow.ThisIsObjectDeletion);
		
		TableToImport.Add(DataTableKey);
		
	EndDo;
	
	// Data processor property initialization.
	InfobaseObjectsMapping = DataProcessors.InfobaseObjectsMapping.Create();
	InfobaseObjectsMapping.ExchangeMessageFileName = ExchangeMessageFileName;
	InfobaseObjectsMapping.InfobaseNode  = InfobaseNode;
	
	// Performing export file
	InfobaseObjectsMapping.ExecuteDataImportToInformationBase(Cancel, TableToImport);
	
	DataSuccessfullyImported = Not Cancel;
	
	For Each RowIndex IN RowIndexes Do
		
		TableRow = StatisticsInformation[RowIndex];
		
		TableRow.DataSuccessfullyImported = DataSuccessfullyImported;
		TableRow.PictureIndex = DataExchangeServer.InformationStatisticsTablePictureIndex(TableRow.UnmappedObjectsCount, TableRow.DataSuccessfullyImported);
	
	EndDo;
	
EndProcedure

// Imports exchange message from external
//  source (ftp, email, network directory) into a temporary directory of the operating system user.
//
// Parameters:
//      Cancel            - Boolean - refusal flag; it is set if there were
//                                    errors during the procedure work.
//      DataPackageFileID - Date    - exchange message change date;
//                                    acts as file ID for data
//                                    exchange subsystem.
// 
Procedure GetExchangeMessageToTemporaryDirectory(
		Cancel,
		DataPackageFileID,
		FileID,
		LongOperation,
		ActionID,
		Password
	) Export
	
	SetPrivilegedMode(True);
	
	// Delete previous temporary exchange message directory with all attached files.
	DeleteTemporaryDirectoryOfExchangeMessages(TemporaryExchangeMessagesDirectoryName);
	
	If ExchangeMessageTransportKind = Enums.ExchangeMessagesTransportKinds.COM Then
		
		DataStructure = DataExchangeServer.GetExchangeMessageFromCorrespondentInfobaseToTempDirectory(Cancel, InfobaseNode, False);
		
	ElsIf ExchangeMessageTransportKind = Enums.ExchangeMessagesTransportKinds.WS Then
		
		DataStructure = DataExchangeServer.GetExchangeMessageToTempDirectoryFromCorrespondentInfobaseOverWebService(
				Cancel,
				InfobaseNode,
				FileID,
				LongOperation,
				ActionID,
				Password);
		
	Else // FILE, FTP, EMAIL
		
		DataStructure = DataExchangeServer.GetExchangeMessageToTemporaryDirectory(Cancel, InfobaseNode, ExchangeMessageTransportKind, False);
		
	EndIf;
	
	TemporaryExchangeMessagesDirectoryName = DataStructure.TemporaryExchangeMessagesDirectoryName;
	DataPackageFileID       = DataStructure.DataPackageFileID;
	ExchangeMessageFileName              = DataStructure.ExchangeMessageFileName;
	
EndProcedure

// Imports exchange message from file transfer
// service into a temporary directory of the operating system user.
//
Procedure GetExchangeMessageToTempDirectoryLongOperationEnd(
			Cancel,
			DataPackageFileID,
			FileID,
			Val Password = ""
	) Export
	
	SetPrivilegedMode(True);
	
	// Delete previous temporary exchange message directory with all attached files.
	DeleteTemporaryDirectoryOfExchangeMessages(TemporaryExchangeMessagesDirectoryName);
	
	DataStructure = DataExchangeServer.GetExchangeMessageToTempDirectoryFromCorrespondentInfobaseOverWebServiceFinishLongOperation(
		Cancel,
		InfobaseNode,
		FileID,
		Password);
	
	TemporaryExchangeMessagesDirectoryName = DataStructure.TemporaryExchangeMessagesDirectoryName;
	DataPackageFileID       = DataStructure.DataPackageFileID;
	ExchangeMessageFileName              = DataStructure.ExchangeMessageFileName;
	
EndProcedure

// Executes analysis of incoming exchange message. Fills with data table StatisticsInformation.
//
// Parameters:
//      Cancel - Boolean - refusal flag which is set to True when there were errors during the execution of the procedure.
//
Procedure RunExchangeMessageAnalysis(Cancel) Export
	
	If IsBlankString(TemporaryExchangeMessagesDirectoryName) Then
		// Failed to receive data from another application.
		Cancel = True;
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	DataExchangeDataProcessor = DataExchangeServer.ExchangeProcessingForDataImport(Cancel, InfobaseNode, ExchangeMessageFileName);
	
	If Cancel Then
		Return;
	EndIf;
	
	AnalysisParameters = New Structure("CollectClassifiersStatistics", True);	
	DataExchangeDataProcessor.RunExchangeMessageAnalysis(AnalysisParameters);
	
	If DataExchangeDataProcessor.ErrorFlag() Then
		Cancel = True;
		Return;
	EndIf;
	
	StatisticsInformation.Load(DataExchangeDataProcessor.DataTableOfPackageHeader());
	
	// Add statistics table with office data.
	SupplementStatisticsTable(Cancel);
	
	// Define table rows with the "OneToMany" flag.
	TempStatistics = StatisticsInformation.Unload(, "ReceiverTableName, ThisIsObjectDeletion");
	
	AddColumnWithValueToTable(TempStatistics, 1, "Iterator");
	
	TempStatistics.GroupBy("ReceiverTableName, ThisIsObjectDeletion", "Iterator");
	
	For Each TableRow IN TempStatistics Do
		
		If TableRow.Iterator > 1 AND Not TableRow.ThisIsObjectDeletion Then
			
			Rows = StatisticsInformation.FindRows(New Structure("ReceiverTableName, ThisIsObjectDeletion",
				TableRow.ReceiverTableName, TableRow.ThisIsObjectDeletion));
			
			For Each String IN Rows Do
				
				String["OneToMany"] = True;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Local service procedures and functions.

// Imports data (tables) from exchange message in cache.
// Only those tables are importing which weren't previously imported.
// Variable DataExchangeDataProcessor contains (caches) previously imported tables.
//
// Parameters:
//       Cancel        - Boolean - refusal flag which is set to True when there were errors during the execution of the procedure.
//       RowIndexes - Array - Table row indexes
//                               StatisticsInformation for which it is required to import data.
//                               If it isn't specified then the operation will be completed for all table rows.
// 
Procedure ExecuteDataImportFromExchangeMessageToCache(Cancel, RowIndexes)
	
	DataExchangeDataProcessor = DataExchangeServer.ExchangeProcessingForDataImport(Cancel, InfobaseNode, ExchangeMessageFileName);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Get array of tables which it is required to import with batch into platform cache.
	TableToImport = New Array;
	
	For Each RowIndex IN RowIndexes Do
		
		TableRow = StatisticsInformation[RowIndex];
		
		If Not TableRow.SynchronizeByID Then
			Continue;
		EndIf;
		
		DataTableKey = DataExchangeServer.DataTableKey(TableRow.SourceTypeAsString, TableRow.ReceiverTypeAsString, TableRow.ThisIsObjectDeletion);
		
		// Data table can be already imported and can be in the data processor cache DataExchangeDataProcessor.
		DataTable = DataExchangeDataProcessor.DataTablesOfExchangeMessage().Get(DataTableKey);
		
		If DataTable = Undefined Then
			
			TableToImport.Add(DataTableKey);
			
		EndIf;
		
	EndDo;
	
	// Execute batch table export into the cache.
	If TableToImport.Count() > 0 Then
		
		DataExchangeDataProcessor.ExecuteDataImportToValueTable(TableToImport);
		
		If DataExchangeDataProcessor.ErrorFlag() Then
			
			NString = NStr("en = 'Errors occurred when loading the exchange message: %1'");
			NString = StringFunctionsClientServer.PlaceParametersIntoString(NString, DataExchangeDataProcessor.ErrorMessageString());
			CommonUseClientServer.MessageToUser(NString,,,, Cancel);
			Return;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure DeleteTemporaryDirectoryOfExchangeMessages(TempDirectoryName)
	
	If Not IsBlankString(TempDirectoryName) Then
		
		Try
			DeleteFiles(TempDirectoryName);
			TempDirectoryName = "";
		Except
		EndTry;
		
	EndIf;
	
EndProcedure

Procedure SupplementStatisticsTable(Cancel)
	
	For Each TableRow IN StatisticsInformation Do
		
		Try
			Type = Type(TableRow.ObjectTypeAsString);
		Except
			
			MessageString = NStr("en = 'Error: type ""%1"" is not defined.'");
			MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, TableRow.ObjectTypeAsString);
			CommonUseClientServer.MessageToUser(MessageString,,,, Cancel);
			Continue;
			
		EndTry;
		
		ObjectMetadata = Metadata.FindByType(Type);
		
		TableRow.ReceiverTableName = ObjectMetadata.FullName();
		TableRow.Presentation       = ObjectMetadata.Presentation();
		
		TableRow.Key = String(New UUID());
		
	EndDo;
	
EndProcedure

Procedure AddColumnWithValueToTable(Table, IteratorValue, IteratorFieldName)
	
	Table.Columns.Add(IteratorFieldName);
	
	Table.FillValues(IteratorValue, IteratorFieldName);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions-properties

// Tabular section data StatisticsInformation.
//
// Returns:
//  ValueTable - Tabular section data StatisticsInformation.
//
Function TableOfInformationStatistics() Export
	
	Return StatisticsInformation.Unload();
	
EndFunction

#EndRegion

#EndIf
