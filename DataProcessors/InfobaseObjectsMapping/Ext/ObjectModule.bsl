#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Var MappingTableField;
Var ObjectMappingStatisticsField;
Var MappingDigestField;
Var UnlimitedLengthStringTypeField;

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Export service procedures and functions.

// Maps the objects of this infobase and source infobase.
//  Forms the mapping table to be displayed to user.
//  Identifies the following types of object links:
// - objects mapped by reference (hard link)
// - objects mapped by information in the InfobaseObjectsMatching information register (soft link)
// - objects mapped by unapproved links - links not written to infobase (current changes)
// - unmapped source objects
// - unmapped receiver objects (of this base).
//
// Parameters:
//     Cancel - Boolean - refusal flag which is set to True when there were errors during the execution of the procedure.
// 
Procedure PerformMappingOfObjects(Cancel) Export
	
	SetPrivilegedMode(True);
	
	// Map the objects of infobases.
	PerformMappingOfObjectsOfInformationBases(Cancel);
	
EndProcedure

// Maps the objects automatically by mapping the user fields (with search fields).
//  Mapping fields are compared for absolute equality.
//  Forms automatic mapping table to be displayed to user.
//
// Parameters:
//     Cancel - Boolean - refusal flag which is set to True when there were errors during the execution of the procedure.
//     MappingFieldList - ValueList - value list
//                                                 with fields necessary for object matching.
// 
Procedure RunAutomaticObjectMapping(Cancel, MappingFieldList) Export
	
	SetPrivilegedMode(True);
	
	RunAutomaticInfobaseObjectsMapping(Cancel, MappingFieldList);
	
EndProcedure

// Maps automatically by default search fields.
// Mapping fields list is equal to the list of used fields.
//
// Parameters:
//      Cancel - Boolean - processing denial flag which is set to True in case of an error.
// 
Procedure RunAutomaticMappingByDefault(Cancel) Export
	
	SetPrivilegedMode(True);
	
	// When automatic matching by
	// default matching field list is equal to used field list.
	MappingFieldList = ListOfUsedFields.Copy();
	
	RunAutomaticInfobaseObjectsMappingByDefault(Cancel, MappingFieldList);
	
	// Apply the result of automatic mapping.
	ApplyTableOfUnapprovedRecords(Cancel);
	
EndProcedure

// Writes unapproved mapping links (current changes) into the infobase.
// Records are stored in the InfobasesObjectsCompliance information register.
//
// Parameters:
//      Cancel - Boolean - processing denial flag which is set to True in case of an error.
// 
Procedure ApplyTableOfUnapprovedRecords(Cancel) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	
	Try
		
		For Each TableRow IN TableOfUnapprovedLinks Do
			
			If DataExchangeReUse.ThisIsExchangePlanXDTO(InfobaseNode) Then
				
				If String(TableRow.UniqueSourceHandle.UUID()) = TableRow.UniqueReceiverHandle Then
					Continue;
				EndIf;
				
				RecordStructure = New Structure("Ref, ID");
				
				RecordStructure.Insert("InfobaseNode", InfobaseNode);
				RecordStructure.Insert("Ref", TableRow.UniqueSourceHandle);
				RecordStructure.Insert("ID", TableRow.UniqueReceiverHandle);
				
				InformationRegisters.SynchronizedObjectPublicIDs.AddRecord(RecordStructure);
				
			Else
				
				RecordStructure = New Structure("UniqueSourceID, UniqueReceiverID, SourceType, ReceiverType");
				
				RecordStructure.Insert("InfobaseNode", InfobaseNode);
				
				FillPropertyValues(RecordStructure, TableRow);
				
				InformationRegisters.InfobasesObjectsCompliance.AddRecord(RecordStructure);
				
			EndIf;
			
		EndDo;
		
		CommitTransaction();
	Except
		WriteLogEvent(NStr("en='Data exchange';ru='Обмен данными описание'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo())
		);
		Cancel = True;
		RollbackTransaction();
		Return;
	EndTry;
	
	TableOfUnapprovedLinks.Clear();
	
EndProcedure

// Gets statistic information on objects mapping.
// MappingDigest() property is initialized.
//
// Parameters:
//      Cancel - Boolean - processing denial flag which is set to True in case of an error.
// 
Procedure GetInformationOfDigestOfObjectsMapping(Cancel) Export
	
	SetPrivilegedMode(True);
	
	SourceTable = GetTableOfSourceInformationBase(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Indicate an empty array of user fields as there is no need to select the fields.
	UserFields = New Array;
	
	TempTablesManager = New TempTablesManager;
	
	// Get the objects mapping table (mapped, unmapped).
	GetTableOfObjectMapping(SourceTable, UserFields, TempTablesManager);
	
	// Get the digest information of object mapping.
	GetMappingDigest(TempTablesManager);
	
	TempTablesManager.Close();
	
EndProcedure

// Imports data from an exchange message file to the Infobase of only specified objects types.
//
// Parameters:
//      Cancel - Boolean - processing denial flag which is set to True in case of an error.
//      TableToImport - Array - array of types that need to be imported from the exchange message; an array item -
//                                    Row.
// 
Procedure ExecuteDataImportToInformationBase(Cancel, TableToImport) Export
	
	SetPrivilegedMode(True);
	
	DataSuccessfullyImported = False;
	
	DataExchangeDataProcessor = DataExchangeServer.ExchangeProcessingForDataImport(Cancel, InfobaseNode, ExchangeMessageFileName);
	
	If Cancel Then
		Return;
	EndIf;
	
	DataExchangeDataProcessor.ExecuteDataImportToInformationBase(TableToImport);
	
	// Delete tables imported to IB from data processor cache because they have become irrelevant.
	For Each Item IN TableToImport Do
		DataExchangeDataProcessor.DataTablesOfExchangeMessage().Delete(Item);
	EndDo;
	
	If DataExchangeDataProcessor.ErrorFlag() Then
		NString = NStr("en='Errors occurred when loading the exchange message: %1';ru='При загрузке сообщения обмена возникли ошибки: %1'");
		NString = StringFunctionsClientServer.PlaceParametersIntoString(NString, DataExchangeDataProcessor.ErrorMessageString());
		CommonUseClientServer.MessageToUser(NString,,,, Cancel);
		Return;
	EndIf;
	
	DataSuccessfullyImported = Not DataExchangeDataProcessor.ErrorFlag();
	
EndProcedure

// Data processor assistant
//
Procedure Assistant() Export
	
	// Fill the list of table fields, you can select the fields for mapping and display from these fields (search fields).
	TableFieldList.LoadValues(StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(ReceiverTableFields));
	
	SearchFieldArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(SearchFieldsOfReceiverTable);
	
	// If search fields are not specified, then we select the search fields.
	If SearchFieldArray.Count() = 0 Then
		
		// for catalogs
		AddSearchField(SearchFieldArray, "Description");
		AddSearchField(SearchFieldArray, "Code");
		AddSearchField(SearchFieldArray, "Owner");
		AddSearchField(SearchFieldArray, "Parent");
		
		// for documents and PSU
		AddSearchField(SearchFieldArray, "Date");
		AddSearchField(SearchFieldArray, "Number");
		
		// popular search fields
		AddSearchField(SearchFieldArray, "Company");
		AddSearchField(SearchFieldArray, "TIN");
		AddSearchField(SearchFieldArray, "KPP");
		
		If SearchFieldArray.Count() = 0 Then
			
			If TableFieldList.Count() > 0 Then
				
				SearchFieldArray.Add(TableFieldList[0].Value);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Delete the fields exceeding the specified limit from the array of search fields, and delete the array items from the end.
	CheckNumberOfMappingFieldsInArray(SearchFieldArray);
	
	// Mark the search fields in the TableFieldList list.
	For Each Item IN TableFieldList Do
		
		If SearchFieldArray.Find(Item.Value) <> Undefined Then
			
			Item.Check = True;
			
		EndIf;
		
	EndDo;
	
	FillListByAdditionalParameters(TableFieldList);
	
	// Form UsedFieldsList from marked items of the TableFieldList list.
	FillListByMarkedItems(TableFieldList, ListOfUsedFields);
	
	// Generate Sorting table.
	FillSortingTable(ListOfUsedFields);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions-properties

// Objects comparison table.
//
// Returns:
//      ValueTable - Objects comparison table.
//
Function MappingTable() Export
	
	If TypeOf(MappingTableField) <> Type("ValueTable") Then
		
		MappingTableField = New ValueTable;
		
	EndIf;
	
	Return MappingTableField;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions-properties - mapping digest.

// Number of objects of current data type in the exchange message file.
//
// Returns:
//     Number - number of objects of current data type in the exchange message file.
//
Function ObjectsCountInSource() Export
	
	Return MappingDigest().ObjectsCountInSource;
	
EndFunction

// Number of objects of current data type in this infobase.
//
// Returns:
//     Number - Number of objects of current data type in this infobase.
//
Function ObjectsCountInReceiver() Export
	
	Return MappingDigest().ObjectsCountInReceiver;
	
EndFunction

// Number of objects mapped for current data type.
//
// Returns:
//     Number - Number of objects mapped for current data type.
//
Function NumberOfObjectsMapped() Export
	
	Return MappingDigest().NumberOfObjectsMapped;
	
EndFunction

// Number of objects unmapped for current data type.
//
// Returns:
//     Number - Number of objects unmapped for current data type.
//
Function UnmappedObjectsCount() Export
	
	Return MappingDigest().UnmappedObjectsCount;
	
EndFunction

// Object mapping percent for current data type.
//
// Returns:
//     Number - object mapping percent for current data type.
//
Function ObjectsMappingPercent() Export
	
	Return MappingDigest().ObjectsMappingPercent;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local functions-properties

Function MappingDigest()
	
	If TypeOf(MappingDigestField) <> Type("Structure") Then
		
		// Initialization of objects mapping digest structure.
		MappingDigestField = New Structure;
		MappingDigestField.Insert("ObjectsCountInSource",       0);
		MappingDigestField.Insert("ObjectsCountInReceiver",       0);
		MappingDigestField.Insert("NumberOfObjectsMapped",   0);
		MappingDigestField.Insert("UnmappedObjectsCount", 0);
		MappingDigestField.Insert("ObjectsMappingPercent",       0);
		
	EndIf;
	
	Return MappingDigestField;
	
EndFunction

Function StatisticsInformationOfObjectsMapping()
	
	If TypeOf(ObjectMappingStatisticsField) <> Type("Structure") Then
		
		// Initialization of statistic information structure.
		ObjectMappingStatisticsField = New Structure;
		ObjectMappingStatisticsField.Insert("MappedByRegisterSourceObjectCount",    0);
		ObjectMappingStatisticsField.Insert("MappedByRegisterTargetObjectCount",    0);
		ObjectMappingStatisticsField.Insert("MappedByUnapprovedRelationsObjectCount", 0);
		
	EndIf;
	
	Return ObjectMappingStatisticsField;
	
EndFunction

Function TypeStringOfUnlimitedLength()
	
	If TypeOf(UnlimitedLengthStringTypeField) <> Type("TypeDescription") Then
		
		UnlimitedLengthStringTypeField = New TypeDescription("String",, New StringQualifiers(0));
		
	EndIf;
	
	Return UnlimitedLengthStringTypeField;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Getting the mapping table.

Procedure PerformMappingOfObjectsOfInformationBases(Cancel)
	
	SourceTable = GetTableOfSourceInformationBase(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Get field array selected by user.
	UserFields = ListOfUsedFields.UnloadValues();
	
	// IsFolder field is always present for hierarchical catalogs.
	If UserFields.Find("IsFolder") = Undefined Then
		
		AddSearchField(UserFields, "IsFolder");
		
	EndIf;
	
	TempTablesManager = New TempTablesManager;
	
	// Get the objects mapping table (mapped, unmapped).
	GetTableOfObjectMapping(SourceTable, UserFields, TempTablesManager);
	
	// Get the digest information of object mapping.
	GetMappingDigest(TempTablesManager);
	
	// Get mapping table.
	MappingTableField = GetMappingTable(SourceTable, UserFields, TempTablesManager);
	
	TempTablesManager.Close();
	
	// sort table
	RunSortingOfTableAtServer();
	
	// Add the SerialNumber field and fill it.
	AddNumberFieldToMappingTable();
	
EndProcedure

Procedure RunAutomaticInfobaseObjectsMapping(Cancel, MappingFieldList)
	
	SourceTable = GetTableOfSourceInformationBase(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Form user fields according to the following algorithm:
	// first add fields selected by user
	// for display then other table fields.
	// Order of fields is important as it influences the display of automatic mapping results table to user.
	UserFields = New Array;
	
	For Each Item IN ListOfUsedFields Do
		
		UserFields.Add(Item.Value);
		
	EndDo;
	
	For Each Item IN TableFieldList Do
		
		If UserFields.Find(Item.Value) = Undefined Then
			
			UserFields.Add(Item.Value);
			
		EndIf;
		
	EndDo;
	
	// Form the list of mapping fields according to the order of items in the UserFields array.
	MappingFieldListNew = New ValueList;
	
	For Each Item IN UserFields Do
		
		ItemOfList = MappingFieldList.FindByValue(Item);
		
		MappingFieldListNew.Add(Item, ItemOfList.Presentation, ItemOfList.Check);
		
	EndDo;
	
	TempTablesManager = New TempTablesManager;
	
	// Get the objects mapping table (mapped, unmapped).
	GetTableOfObjectMapping(SourceTable, UserFields, TempTablesManager);
	
	// Get the table of automatic mapping.
	GetTableOfAutomaticMapping(SourceTable, MappingFieldListNew, UserFields, TempTablesManager);
	
	// Import the table of automatically mapped objects into the form attribute.
	TableOfAutomaticallyMappedObjects.Load(TableOfAutomaticallyMappedObjectsGet(TempTablesManager, UserFields));
	
	TempTablesManager.Close();
	
EndProcedure

Procedure RunAutomaticInfobaseObjectsMappingByDefault(Cancel, MappingFieldList)
	
	SourceTable = GetTableOfSourceInformationBase(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Get field array selected by user.
	UserFields = ListOfUsedFields.UnloadValues();
	
	TempTablesManager = New TempTablesManager;
	
	// Get the objects mapping table (mapped, unmapped).
	GetTableOfObjectMapping(SourceTable, UserFields, TempTablesManager);
	
	// Get the table of automatic mapping.
	GetTableOfAutomaticMapping(SourceTable, MappingFieldList, UserFields, TempTablesManager);
	
	// Import updated table of unapproved links into object attribute.
	TableOfUnapprovedLinks.Load(MergeTablesOfUnapprovedLinksAndAutomaticMapping(TempTablesManager));
	
	TempTablesManager.Close();
	
EndProcedure

Procedure GetTableOfObjectMapping(SourceTable, UserFields, TempTablesManager)
	
	// get tables:
	//
	// SourceTable
	// UnapprovedLinksTable
	// InfobaseObjectsMatchingRegisterTable.
	//
	// SourceMatchedObjectsTableByRegister
	// ReceiverMatchedObjectsTableByRegister
	// MatchedObjectsTableByUnapprovedLinks.
	//
	// MappedObjectsTable.
	//
	// SourceUnmatchedObjectTable
	// ReceiverUnmatchedObjectTable.
	//
	//
	
	QueryText = "
	|//////////////////////////////////////////////////////////////////////////////// {SourceTable}
	|SELECT
	|	
	|	#custom_Fields_SourceTable#
	|	
	|	SourceTableParameter.Ref                  AS Ref,
	|	SourceTableParameter.UUID AS UUID,
	|	&SourceType                                    AS ObjectType
	|INTO SourceTable
	|FROM
	|	&SourceTableParameter AS SourceTableParameter
	|INDEX BY
	|	Ref,
	|	UUID
	|;
	|";
	
	If DataExchangeReUse.ThisIsExchangePlanXDTO(InfobaseNode) Then
		QueryText = QueryText + "
			|//////////////////////////////////////////////////////////////////////////////// {InfobaseObjectsMappingRegisterTable}
			|SELECT
			|	Ref        AS UniqueSourceHandle,
			|	ID AS UniqueReceiverHandle,
			|	""#SourceType#"" AS ReceiverType,
			|	""#ReceiverType#"" AS SourceType
			|INTO InfobaseObjectMappingRegisterTable
			|FROM
			|	InformationRegister.SynchronizedObjectPublicIDs AS InfobasesObjectsCompliance
			|WHERE
			|	  InfobasesObjectsCompliance.InfobaseNode = &InfobaseNode
			|	AND InfobasesObjectsCompliance.Ref REFS #TargetTable#
			|
			|INDEX BY
			|	UniqueReceiverHandle
			|;
			|";
	Else
		QueryText = QueryText + "
			|//////////////////////////////////////////////////////////////////////////////// {InfobaseObjectsMappingRegisterTable}
			|SELECT
			|	UniqueSourceHandle,
			|	UniqueReceiverHandle,
			|	ReceiverType,
			|	SourceType
			|INTO InfobaseObjectMappingRegisterTable
			|FROM
			|	InformationRegister.InfobasesObjectsCompliance AS InfobasesObjectsCompliance
			|WHERE
			|	  InfobasesObjectsCompliance.InfobaseNode = &InfobaseNode
			|	AND InfobasesObjectsCompliance.ReceiverType = &SourceType
			|	AND InfobasesObjectsCompliance.SourceType = &ReceiverType
			|INDEX BY
			|	UniqueReceiverHandle,
			|	ReceiverType,
			|	SourceType
			|;
			|";
	EndIf;
	
	QueryText = QueryText + "
		|//////////////////////////////////////////////////////////////////////////////// {UnapprovedLinksTable}
		|SELECT
		|	
		|	UniqueSourceHandle,
		|	UniqueReceiverHandle,
		|	ReceiverType,
		|	SourceType
		|	
		|INTO TableOfUnapprovedLinks
		|FROM
		|	&TableOfUnapprovedLinks AS TableOfUnapprovedLinks
		|INDEX BY
		|	UniqueReceiverHandle,
		|	ReceiverType
		|;
		|";
		
	If DataExchangeReUse.ThisIsExchangePlanXDTO(InfobaseNode) Then
		QueryText = QueryText + "
			|//////////////////////////////////////////////////////////////////////////////// {MappedSourceObjectsTableByRegister}
			|SELECT
			|			
			|	#custom_Fields_MappingTable#
			|			
			|	#Field_order_Receiver#
			|			
			|	Ref,
			|	0 AS MappingState,               // mapped objects (0)
			|	0 AS MappingStateAdditional, // mapped objects (0)
			|			
			|	IsSourceFolder,
			|	IsTargetFolder,
			|			
			|	// {MAPPING REGISTER DATA}
			|	UniqueSourceHandle,
			|	UniqueReceiverHandle,
			|	SourceType,
			|	ReceiverType
			|INTO MappedSourceObjectTableByRegister
			|FROM
			|	(SELECT
			|			
			|		#custom_Fields_MappedSourceObjectTableByRegister_NestedSelect#
			|		
			|		ISNULL(InfobasesObjectsCompliance.UniqueSourceHandle, TargetTable.Ref) AS Ref,
			|		
			|		#SourceTableIsFolder#                      AS IsSourceFolder,
			|		#InfobasesObjectsComplianceIsFolder# AS IsTargetFolder,
			|			
			|		// {MAPPING REGISTER DATA}
			|		ISNULL(InfobasesObjectsCompliance.UniqueSourceHandle, TargetTable.Ref)                  AS UniqueReceiverHandle,
			|		ISNULL(InfobasesObjectsCompliance.UniqueReceiverHandle, SourceTable.UUID) AS UniqueSourceHandle,
			|		ISNULL(InfobasesObjectsCompliance.ReceiverType, ""#SourceType#"")                                           AS SourceType,
			|		ISNULL(InfobasesObjectsCompliance.SourceType, ""#ReceiverType#"")                                           AS ReceiverType
			|	FROM
			|		SourceTable AS SourceTable
			|	LEFT JOIN
			|		InfobaseObjectMappingRegisterTable AS InfobasesObjectsCompliance
			|	ON
			|		  InfobasesObjectsCompliance.UniqueReceiverHandle = SourceTable.UUID
			|		AND InfobasesObjectsCompliance.UniqueSourceHandle REFS #TargetTable#
			|	LEFT JOIN
			|		#TargetTable# AS TargetTable
			|	ON
			|		  SourceTable.Ref = TargetTable.Ref
			|	WHERE
			|		Not InfobasesObjectsCompliance.UniqueSourceHandle IS NULL
			|		OR Not TargetTable.Ref IS NULL
			|	) AS NestedSelect
			|;
			|		
			|//////////////////////////////////////////////////////////////////////////////// {MappedTargetObjectsTableByRegister}
			|SELECT
			|			
			|	#custom_Fields_MappingTable#
			|			
			|	#Field_order_Receiver#
			|			
			|	Ref,
			|	0 AS MappingState,               // mapped objects (0)
			|	0 AS MappingStateAdditional, // mapped objects (0)
			|			
			|	IsSourceFolder,
			|	IsTargetFolder,
			|			
			|	// {MAPPING REGISTER DATA}
			|	UniqueSourceHandle,
			|	UniqueReceiverHandle,
			|	SourceType,
			|	ReceiverType
			|INTO MappedTargetObjectTableByRegister
			|FROM
			|	(SELECT
			|			
			|		#custom_Fields_MappedTargetObjectTableByRegister_NestedSelect#
			|		
			|		TargetTable.Ref AS Ref,
			|			
			|		#TargetTableIsFolder# AS IsSourceFolder,
			|		#TargetTableIsFolder# AS IsTargetFolder,
			|			
			|		// {MAPPING REGISTER DATA}
			|		InfobasesObjectsCompliance.UniqueSourceHandle AS UniqueReceiverHandle,
			|		InfobasesObjectsCompliance.UniqueReceiverHandle AS UniqueSourceHandle,
			|		InfobasesObjectsCompliance.ReceiverType                     AS SourceType,
			|		InfobasesObjectsCompliance.SourceType                     AS ReceiverType
			|	FROM
			|		#TargetTable# AS TargetTable
			|	LEFT JOIN
			|		InfobaseObjectMappingRegisterTable AS InfobasesObjectsCompliance
			|	ON
			|		  InfobasesObjectsCompliance.UniqueSourceHandle = TargetTable.Ref
			|	LEFT JOIN
			|		MappedSourceObjectTableByRegister AS MappedSourceObjectTableByRegister
			|	ON
			|		MappedSourceObjectTableByRegister.Ref = TargetTable.Ref
			|			
			|	WHERE
			|		Not InfobasesObjectsCompliance.UniqueSourceHandle IS NULL
			|		AND MappedSourceObjectTableByRegister.Ref IS NULL
			|	) AS NestedSelect
			|;
			|		
			|//////////////////////////////////////////////////////////////////////////////// {MappedObjectsTableByUnapprovedLinks}
			|SELECT
			|			
			|	#custom_Fields_MappingTable#
			|			
			|	#Field_order_Receiver#
			|			
			|	Ref,
			|	3 AS MappingState,               // unapproved links (3)
			|	0 AS MappingStateAdditional, // mapped objects (0)
			|			
			|	IsSourceFolder,
			|	IsTargetFolder,
			|			
			|	// {MAPPING REGISTER DATA}
			|	UniqueSourceHandle,
			|	UniqueReceiverHandle,
			|	SourceType,
			|	ReceiverType
			|INTO MappedObjectTableByUnapprovedRelations
			|FROM
			|	(SELECT
			|			
			|		#custom_Fields_MappedObjectTableByUnapprovedRelations_NestedSelect#
			|		
			|		TableOfUnapprovedLinks.UniqueSourceHandle AS Ref,
			|			
			|		#SourceTableIsFolder#            AS IsSourceFolder,
			|		#UnapprovedRelationTableIsFolder# AS IsTargetFolder,
			|			
			|		// {MAPPING REGISTER DATA}
			|		TableOfUnapprovedLinks.UniqueSourceHandle AS UniqueReceiverHandle,
			|		TableOfUnapprovedLinks.UniqueReceiverHandle AS UniqueSourceHandle,
			|		TableOfUnapprovedLinks.ReceiverType AS SourceType,
			|		TableOfUnapprovedLinks.SourceType AS ReceiverType
			|	FROM
			|		SourceTable AS SourceTable
			|	LEFT JOIN
			|		TableOfUnapprovedLinks AS TableOfUnapprovedLinks
			|	ON
			|		  TableOfUnapprovedLinks.UniqueReceiverHandle = SourceTable.UUID
			|		AND TableOfUnapprovedLinks.UniqueSourceHandle REFS #TargetTable#
			|		
			|	WHERE
			|		Not TableOfUnapprovedLinks.UniqueSourceHandle IS NULL
			|	) AS NestedSelect
			|;
			|";
	Else
		QueryText = QueryText + "
			|//////////////////////////////////////////////////////////////////////////////// {MappedSourceObjectsTableByRegister}
			|SELECT
			|			
			|	#custom_Fields_MappingTable#
			|			
			|	#Field_order_Receiver#
			|			
			|	Ref,
			|	0 AS MappingState,               // mapped objects (0)
			|	0 AS MappingStateAdditional, // mapped objects (0)
			|			
			|	IsSourceFolder,
			|	IsTargetFolder,
			|			
			|	// {MAPPING REGISTER DATA}
			|	UniqueSourceHandle,
			|	UniqueReceiverHandle,
			|	SourceType,
			|	ReceiverType
			|INTO MappedSourceObjectTableByRegister
			|FROM
			|	(SELECT
			|			
			|		#custom_Fields_MappedSourceObjectTableByRegister_NestedSelect#
			|		
			|		InfobasesObjectsCompliance.UniqueSourceHandle AS Ref,
			|		
			|		#SourceTableIsFolder#                      AS IsSourceFolder,
			|		#InfobasesObjectsComplianceIsFolder# AS IsTargetFolder,
			|			
			|		// {MAPPING REGISTER DATA}
			|		InfobasesObjectsCompliance.UniqueSourceHandle AS UniqueReceiverHandle,
			|		InfobasesObjectsCompliance.UniqueReceiverHandle AS UniqueSourceHandle,
			|		InfobasesObjectsCompliance.ReceiverType                     AS SourceType,
			|		InfobasesObjectsCompliance.SourceType                     AS ReceiverType
			|	FROM
			|		SourceTable AS SourceTable
			|	LEFT JOIN
			|		InfobaseObjectMappingRegisterTable AS InfobasesObjectsCompliance
			|	ON
			|		  InfobasesObjectsCompliance.UniqueReceiverHandle = SourceTable.UUID
			|		AND InfobasesObjectsCompliance.ReceiverType                     = SourceTable.ObjectType
			|	WHERE
			|		Not InfobasesObjectsCompliance.UniqueSourceHandle IS NULL
			|	) AS NestedSelect
			|;
			|//////////////////////////////////////////////////////////////////////////////// {MappedTargetObjectsTableByRegister}
			|SELECT
			|			
			|	#custom_Fields_MappingTable#
			|			
			|	#Field_order_Receiver#
			|			
			|	Ref,
			|	0 AS MappingState,               // mapped objects (0)
			|	0 AS MappingStateAdditional, // mapped objects (0)
			|			
			|	IsSourceFolder,
			|	IsTargetFolder,
			|			
			|	// {MAPPING REGISTER DATA}
			|	UniqueSourceHandle,
			|	UniqueReceiverHandle,
			|	SourceType,
			|	ReceiverType
			|INTO MappedTargetObjectTableByRegister
			|FROM
			|	(SELECT
			|			
			|		#custom_Fields_MappedTargetObjectTableByRegister_NestedSelect#
			|		
			|		TargetTable.Ref AS Ref,
			|			
			|		#TargetTableIsFolder# AS IsSourceFolder,
			|		#TargetTableIsFolder# AS IsTargetFolder,
			|			
			|		// {MAPPING REGISTER DATA}
			|		InfobasesObjectsCompliance.UniqueSourceHandle AS UniqueReceiverHandle,
			|		InfobasesObjectsCompliance.UniqueReceiverHandle AS UniqueSourceHandle,
			|		InfobasesObjectsCompliance.ReceiverType                     AS SourceType,
			|		InfobasesObjectsCompliance.SourceType                     AS ReceiverType
			|	FROM
			|		#TargetTable# AS TargetTable
			|	LEFT JOIN
			|		InfobaseObjectMappingRegisterTable AS InfobasesObjectsCompliance
			|	ON
			|		  InfobasesObjectsCompliance.UniqueSourceHandle = TargetTable.Ref
			|		AND InfobasesObjectsCompliance.SourceType                     = &ReceiverType
			|	LEFT JOIN
			|		MappedSourceObjectTableByRegister AS MappedSourceObjectTableByRegister
			|	ON
			|		MappedSourceObjectTableByRegister.Ref = TargetTable.Ref
			|			
			|	WHERE
			|		Not InfobasesObjectsCompliance.UniqueSourceHandle IS NULL
			|		AND MappedSourceObjectTableByRegister.Ref IS NULL
			|	) AS NestedSelect
			|;
			|		
			|//////////////////////////////////////////////////////////////////////////////// {MappedObjectsTableByUnapprovedLinks}
			|SELECT
			|			
			|	#custom_Fields_MappingTable#
			|			
			|	#Field_order_Receiver#
			|			
			|	Ref,
			|	3 AS MappingState,               // unapproved links (3)
			|	0 AS MappingStateAdditional, // mapped objects (0)
			|			
			|	IsSourceFolder,
			|	IsTargetFolder,
			|			
			|	// {MAPPING REGISTER DATA}
			|	UniqueSourceHandle,
			|	UniqueReceiverHandle,
			|	SourceType,
			|	ReceiverType
			|INTO MappedObjectTableByUnapprovedRelations
			|FROM
			|	(SELECT
			|			
			|		#custom_Fields_MappedObjectTableByUnapprovedRelations_NestedSelect#
			|		
			|		TableOfUnapprovedLinks.UniqueSourceHandle AS Ref,
			|			
			|		#SourceTableIsFolder#            AS IsSourceFolder,
			|		#UnapprovedRelationTableIsFolder# AS IsTargetFolder,
			|			
			|		// {MAPPING REGISTER DATA}
			|		TableOfUnapprovedLinks.UniqueSourceHandle AS UniqueReceiverHandle,
			|		TableOfUnapprovedLinks.UniqueReceiverHandle AS UniqueSourceHandle,
			|		TableOfUnapprovedLinks.ReceiverType AS SourceType,
			|		TableOfUnapprovedLinks.SourceType AS ReceiverType
			|	FROM
			|		SourceTable AS SourceTable
			|	LEFT JOIN
			|		TableOfUnapprovedLinks AS TableOfUnapprovedLinks
			|	ON
			|		  TableOfUnapprovedLinks.UniqueReceiverHandle = SourceTable.UUID
			|		AND TableOfUnapprovedLinks.ReceiverType                     = SourceTable.ObjectType
			|		
			|	WHERE
			|		Not TableOfUnapprovedLinks.UniqueSourceHandle IS NULL
			|	) AS NestedSelect
			|;
			|";
	EndIf;
	
	QueryText = QueryText + "
		|//////////////////////////////////////////////////////////////////////////////// {MappedObjectsTable}
		|SELECT
		|	
		|	#custom_Fields_MappingTable#
		|	
		|	#Fields_order#
		|	
		|	Ref,
		|	MappingState,
		|	MappingStateAdditional,
		|	
		|	// {PICTURE INDEX}
		|	CASE WHEN IsSourceFolder IS NULL
		|	THEN 0
		|	ELSE
		|		CASE WHEN IsSourceFolder = TRUE
		|		THEN 1
		|		ELSE 2
		|		END
		|	END AS SourcePictureIndex,
		|	
		|	CASE WHEN IsTargetFolder IS NULL
		|	THEN 0
		|	ELSE
		|		CASE WHEN IsTargetFolder = TRUE
		|		THEN 1
		|		ELSE 2
		|		END
		|	END AS ReceiverPictureIndex,
		|	
		|	// {MAPPING REGISTER DATA}
		|	UniqueSourceHandle,
		|	UniqueReceiverHandle,
		|	SourceType,
		|	ReceiverType
		|INTO MappedObjectTable
		|FROM
		|	(
		|	SELECT
		|	
		|		#custom_Fields_MappingTable#
		|	
		|		#Fields_order#
		|	
		|		Ref,
		|		MappingState,
		|		MappingStateAdditional,
		|	
		|		IsSourceFolder,
		|		IsTargetFolder,
		|	
		|		// {MAPPING REGISTER DATA}
		|		UniqueSourceHandle,
		|		UniqueReceiverHandle,
		|		SourceType,
		|		ReceiverType
		|	FROM
		|		MappedSourceObjectTableByRegister
		|	
		|	UNION ALL
		|	
		|	SELECT
		|	
		|		#custom_Fields_MappingTable#
		|	
		|		#Fields_order#
		|	
		|		Ref,
		|		MappingState,
		|		MappingStateAdditional,
		|	
		|		IsSourceFolder,
		|		IsTargetFolder,
		|	
		|		// {MAPPING REGISTER DATA}
		|		UniqueSourceHandle,
		|		UniqueReceiverHandle,
		|		SourceType,
		|		ReceiverType
		|	FROM
		|		MappedTargetObjectTableByRegister
		|	
		|	UNION ALL
		|	
		|	SELECT
		|	
		|		#custom_Fields_MappingTable#
		|	
		|		#Fields_order#
		|	
		|		Ref,
		|		MappingState,
		|		MappingStateAdditional,
		|	
		|		IsSourceFolder,
		|		IsTargetFolder,
		|	
		|		// {MAPPING REGISTER DATA}
		|		UniqueSourceHandle,
		|		UniqueReceiverHandle,
		|		SourceType,
		|		ReceiverType
		|	FROM
		|		MappedObjectTableByUnapprovedRelations
		|	
		|	) AS NestedSelect
		|	
		|INDEX BY
		|	Ref
		|;
		|
		|//////////////////////////////////////////////////////////////////////////////// {UnmappedSourceObjectsTable}
		|SELECT
		|	
		|	Ref,
		|	
		|	#custom_Fields_MappingTable#
		|	
		|	#Field_order_Source#
		|	
		|	-1 AS MappingState,               // unmapped objects of the source (-1)
		|	 1 AS MappingStateAdditional, // unmapped objects (1)
		|	
		|	// {PICTURE INDEX}
		|	CASE WHEN IsSourceFolder IS NULL
		|	THEN 0
		|	ELSE
		|		CASE WHEN IsSourceFolder = TRUE
		|		THEN 1
		|		ELSE 2
		|		END
		|	END AS SourcePictureIndex,
		|	
		|	CASE WHEN IsTargetFolder IS NULL
		|	THEN 0
		|	ELSE
		|		CASE WHEN IsTargetFolder = TRUE
		|		THEN 1
		|		ELSE 2
		|		END
		|	END AS ReceiverPictureIndex,
		|	
		|	// {MAPPING REGISTER DATA}
		|	UniqueSourceHandle,
		|	UniqueReceiverHandle,
		|	SourceType,
		|	ReceiverType
		|INTO UnmappedSourceObjectTable
		|FROM
		|	(SELECT
		|	
		|		#SourceTableIsFolder# AS IsSourceFolder,
		|		NULL                        AS IsTargetFolder,
		|		
		|		SourceTable.Ref AS Ref,
		|		
		|		#custom_Fields_UnmappedSourceObjectTable_NestedSelect#
		|		
		|		// {MAPPING REGISTER DATA}
		|		NULL                                     AS UniqueReceiverHandle,
		|		SourceTable.UUID AS UniqueSourceHandle,
		|		&SourceType                            AS SourceType,
		|		&ReceiverType                            AS ReceiverType
		|	FROM
		|		SourceTable AS SourceTable
		|	LEFT JOIN
		|		MappedObjectTable AS MappedObjectTable
		|	ON
		|		    SourceTable.Ref = MappedObjectTable.Ref
		|		OR SourceTable.UUID = MappedObjectTable.UniqueSourceHandle
		|	WHERE
		|		MappedObjectTable.Ref IS NULL
		|	) AS NestedSelect
		|;
		|
		|//////////////////////////////////////////////////////////////////////////////// {UnmappedTargetObjectsTable}
		|SELECT
		|	
		|	Ref,
		|	
		|	#custom_Fields_MappingTable#
		|	
		|	#Field_order_Receiver#
		|	
		|	1 AS MappingState,               // unmapped objects of the receiver (1)
		|	1 AS MappingStateAdditional, // unmapped objects (1)
		|	
		|	// {PICTURE INDEX}
		|	CASE WHEN IsSourceFolder IS NULL
		|	THEN 0
		|	ELSE
		|		CASE WHEN IsSourceFolder = TRUE
		|		THEN 1
		|		ELSE 2
		|		END
		|	END AS SourcePictureIndex,
		|	
		|	CASE WHEN IsTargetFolder IS NULL
		|	THEN 0
		|	ELSE
		|		CASE WHEN IsTargetFolder = TRUE
		|		THEN 1
		|		ELSE 2
		|		END
		|	END AS ReceiverPictureIndex,
		|	
		|	// {MAPPING REGISTER DATA}
		|	UniqueSourceHandle,
		|	UniqueReceiverHandle,
		|	SourceType,
		|	ReceiverType
		|INTO UnmappedTargetObjectTable
		|FROM
		|	(SELECT
		|	
		|		TargetTable.Ref AS Ref,
		|	
		|		#custom_Fields_UnmappedTargetObjectTable_NestedSelect#
		|		
		|		NULL                        AS IsSourceFolder,
		|		#TargetTableIsFolder# AS IsTargetFolder,
		|		
		|		// {MAPPING REGISTER DATA}
		|		TargetTable.Ref       AS UniqueReceiverHandle,
		|		Undefined                  AS UniqueSourceHandle,
		|		Undefined                  AS SourceType,
		|		&ReceiverType                 AS ReceiverType
		|	FROM
		|		#TargetTable# AS TargetTable
		|	LEFT JOIN
		|		MappedObjectTable AS MappedObjectTable
		|	ON
		|		TargetTable.Ref = MappedObjectTable.Ref
		|	WHERE
		|		MappedObjectTable.Ref IS NULL
		|	) AS NestedSelect
		|;
		|
		|		TargetTable.Ref       AS UniqueReceiverHandle,
		|		Undefined                  AS UniqueSourceHandle,
		|		Undefined                  AS SourceType,
		|		&ReceiverType                 AS ReceiverType
		|	FROM
		|		#TargetTable# AS TargetTable
		|	LEFT JOIN
		|		MappedObjectTable AS MappedObjectTable
		|	ON
		|		TargetTable.Ref = MappedObjectTable.Ref
		|	WHERE
		|		MappedObjectTable.Ref IS NULL
		|	) AS NestedSelect
		|;
		|
		|";
	
	QueryText = StrReplace(QueryText, "#USER_FIELDS_SourceTable#", GetUserFields(UserFields, "SourceTableParameter.# AS #,"));
	QueryText = StrReplace(QueryText, "#USER_FIELDS_MappingTable#", GetUserFields(UserFields, "SourceFieldNN, ReceiverFieldNN,"));
	QueryText = StrReplace(QueryText, "#USER_FIELDS_MappedObjectsByRefTable_NestedSelect#", GetUserFields(UserFields, "TargetTable.# AS ReceiverFieldNN, SourceTable.# AS SourceFieldNN,"));
	
	If DataExchangeReUse.ThisIsExchangePlanXDTO(InfobaseNode) Then
		QueryText = StrReplace(QueryText, "#USER_FIELDS_MappedSourceObjectsTableByRegister_NestedSelect#", GetUserFields(UserFields, "CAST(UNF(InfobasesObjectsCompliance.UniqueSourceHandle, TargetTable.Ref) AS [ReceiverTableName]).# AS ReceiverFieldNN, SourceTable.# AS SourceFieldNN,"));
	Else
		QueryText = StrReplace(QueryText, "#USER_FIELDS_MappedSourceObjectsTableByRegister_NestedSelect#", GetUserFields(UserFields, "CAST(InfobasesObjectsCompliance.UniqueSourceHandle AS [ReceiverTableName]).# AS ReceiverFieldNN, SourceTable.# AS SourceFieldNN,"));
	EndIf;
	
	QueryText = StrReplace(QueryText, "#USER_FIELDS_MappedTargetObjectsTableByRegister_NestedSelect#", GetUserFields(UserFields, "TargetTable.# AS ReceiverFieldNN, NULL AS SourceFieldNN,"));
	QueryText = StrReplace(QueryText, "#USER_FIELDS_MappedObjectsTableByUnapprovedLinks_NestedSelect#", GetUserFields(UserFields, "CAST(TableOfUnapprovedLinks.UniqueSourceHandle AS [ReceiverTableName]).# AS ReceiverFieldNN, SourceTable.# AS SourceFieldNN,"));
	QueryText = StrReplace(QueryText, "#USER_FIELDS_UnmappedSourceObjectsTable_NestedSelect#", GetUserFields(UserFields, "SourceTable.# AS SourceFieldNN, NULL AS ReceiverFieldNN,"));
	QueryText = StrReplace(QueryText, "#USER_FIELDS_UnmappedTargetObjectsTable_NestedSelect#", GetUserFields(UserFields, "NULL AS SourceFieldNN, TargetTable.Ref.# AS ReceiverFieldNN,"));
	
	QueryText = StrReplace(QueryText, "#SORTING_FIELD_Source#", GetUserFields(UserFields, "SourceFieldNN AS FieldSortingNN,"));
	QueryText = StrReplace(QueryText, "#SORTING_FIELD_Receiver#", GetUserFields(UserFields, "ReceiverFieldNN AS FieldSortingNN,"));
	
	QueryText = StrReplace(QueryText, "#Fields_order#", GetUserFields(UserFields, "FieldSortingNN,"));
	QueryText = StrReplace(QueryText, "#TargetTable#", ReceiverTableName);
	
	If UserFields.Find("IsFolder") <> Undefined Then
		
		QueryText = StrReplace(QueryText, "#SourceTableIsFolder#",            "SourceTable.IsFolder");
		QueryText = StrReplace(QueryText, "#TargetTableIsFolder#",            "TargetTable.IsFolder");
		QueryText = StrReplace(QueryText, "#UnapprovedLinksTableIsFolder#", "CAST(TableOfUnapprovedLinks.UniqueSourceHandle AS [ReceiverTableName]).IsFolder");
		QueryText = StrReplace(QueryText, "#InfobaseObjectsMatchingIsFolder#", "CAST(InfobasesObjectsCompliance.UniqueSourceHandle AS [ReceiverTableName]).IsFolder");
		
	Else
		
		QueryText = StrReplace(QueryText, "#SourceTableIsFolder#",            "NULL");
		QueryText = StrReplace(QueryText, "#TargetTableIsFolder#",            "NULL");
		QueryText = StrReplace(QueryText, "#UnapprovedLinksTableIsFolder#", "NULL");
		QueryText = StrReplace(QueryText, "#InfobaseObjectsMatchingIsFolder#", "NULL");
		
	EndIf;
	
	QueryText = StrReplace(QueryText, "[TargetTableName]", ReceiverTableName);
	
	Query = New Query;
	
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Query.SetParameter("SourceTableParameter",    SourceTable);
	Query.SetParameter("TableOfUnapprovedLinks", TableOfUnapprovedLinks.Unload());
	Query.SetParameter("SourceType",                SourceTypeAsString);
	Query.SetParameter("ReceiverType",                ReceiverTypeAsString);
	Query.SetParameter("InfobaseNode",      InfobaseNode);
	
	Query.Execute();
	
EndProcedure

Procedure GetTableOfAutomaticMapping(SourceTable, MappingFieldList, UserFields, TempTablesManager)
	
	MarkedListItemArray = CommonUseClientServer.GetArrayOfMarkedListItems(MappingFieldList);
	
	If MarkedListItemArray.Count() = 0 Then
		
		GetTableOfAutomaticMappingByGUID(UserFields, TempTablesManager);
		
	Else
		
		GetTableOfAutomaticMappingByGUIDPlusBySearchFields(SourceTable, MappingFieldList, UserFields, TempTablesManager);
		
	EndIf;
	
EndProcedure

Procedure GetTableOfAutomaticMappingByGUID(UserFields, TempTablesManager)
	
	// get tables:
	//
	// TableOfAutomaticallyMappedObjects
	
	QueryText = "
	|//////////////////////////////////////////////////////////////////////////////// {AutomaticallyMappedObjectsTable}
	|SELECT
	|	
	|	Ref,
	|	
	|	#custom_Fields_MappingTable#
	|	
	|	ReceiverPictureIndex,
	|	SourcePictureIndex,
	|	
	|	// {MAPPING REGISTER DATA}
	|	UniqueSourceHandle,
	|	UniqueReceiverHandle,
	|	SourceType,
	|	ReceiverType
	|INTO TableOfAutomaticallyMappedObjects
	|FROM
	|	(SELECT
	|		
	|		UnmappedTargetObjectTable.Ref AS Ref,
	|		
	|		UnmappedTargetObjectTable.ReceiverPictureIndex,
	|		UnmappedSourceObjectTable.SourcePictureIndex,
	|		
	|		#custom_Fields_AutomaticallyMappedObjectTableByGUID_NestedSelect#
	|		
	|		// {MAPPING REGISTER DATA}
	|		UnmappedSourceObjectTable.UniqueSourceHandle AS UniqueSourceHandle,
	|		UnmappedSourceObjectTable.SourceType                     AS SourceType,
	|		UnmappedTargetObjectTable.UniqueReceiverHandle AS UniqueReceiverHandle,
	|		UnmappedTargetObjectTable.ReceiverType                     AS ReceiverType
	|	FROM
	|		UnmappedTargetObjectTable AS UnmappedTargetObjectTable
	|	LEFT JOIN
	|		UnmappedSourceObjectTable AS UnmappedSourceObjectTable
	|	ON
	|		UnmappedTargetObjectTable.Ref = UnmappedSourceObjectTable.Ref
	|	
	|	WHERE
	|		Not UnmappedSourceObjectTable.Ref IS NULL
	|	
	|	) AS NestedSelect
	|;
	|";
	
	QueryText = StrReplace(QueryText, "#USER_FIELDS_MappingTable#", GetUserFields(UserFields, "SourceFieldNN, ReceiverFieldNN,"));
	QueryText = StrReplace(QueryText, "#USER_FIELDS_AutomaticallyMappedObjectsTableByGUID_NestedSelect#", GetUserFields(UserFields, "SourceUnmatchedObjectsTable.SourceFieldNN AS SourceFieldNN, ReceiverUnmatchedObjectsTable.ReceiverFieldNN AS ReceiverFieldNN,"));
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Execute();
	
EndProcedure

Procedure GetTableOfAutomaticMappingByGUIDPlusBySearchFields(SourceTable, MappingFieldList, UserFields, TempTablesManager)
	
	// get tables:
	//
	// AutomaticMatchedObjectsTableFull
	// ReceiverUnmatchedObjectsTableByFields
	// SourceUnmatchedObjectsTableByFields
	// SourceIncorrectMatchedObjectsTable
	// ReceiverIncorrectMatchedObjectsTable
	//
	// AutomaticMatchedObjectsTableByGUID
	// AutomaticMatchedObjectsTableByFields
	// AutomaticMatchedObjectsTable.
	
	// formulas of getting the tables
	//
	// ReceiverUnmatchedObjectTableByFields = ReceiverUnmatchedObjectTable - AutomaticMatchedObjectsTableByGUID
	// SourceUnmatchedObjectsTableByFields =
	// SourceUnmatchedObjectsTable - AutomaticallyMappedObjectTableByGUID
	//
	// AutomaticMatchedObjectsTable = AutomaticMatchedObjectsTableByFields + 
	// AutomaticMatchedObjectsTableByGUID
	
	QueryText = "
	|//////////////////////////////////////////////////////////////////////////////// {AutomaticallyMappedObjectsTableByGUID}
	|SELECT
	|	
	|	Ref,
	|	
	|	#custom_Fields_MappingTable#
	|	
	|	ReceiverPictureIndex,
	|	SourcePictureIndex,
	|		
	|	// {MAPPING REGISTER DATA}
	|	UniqueSourceHandle,
	|	UniqueReceiverHandle,
	|	SourceType,
	|	ReceiverType
	|INTO AutomaticallyMappedObjectTableByGUID
	|FROM
	|	(SELECT
	|		
	|		UnmappedTargetObjectTable.Ref AS Ref,
	|		
	|		#custom_Fields_AutomaticallyMappedObjectTableByGUID_NestedSelect#
	|		
	|		UnmappedTargetObjectTable.ReceiverPictureIndex,
	|		UnmappedSourceObjectTable.SourcePictureIndex,
	|		
	|		// {MAPPING REGISTER DATA}
	|		UnmappedSourceObjectTable.UniqueSourceHandle AS UniqueSourceHandle,
	|		UnmappedSourceObjectTable.SourceType                     AS SourceType,
	|		UnmappedTargetObjectTable.UniqueReceiverHandle AS UniqueReceiverHandle,
	|		UnmappedTargetObjectTable.ReceiverType                     AS ReceiverType
	|	FROM
	|		UnmappedTargetObjectTable AS UnmappedTargetObjectTable
	|	LEFT JOIN
	|		UnmappedSourceObjectTable AS UnmappedSourceObjectTable
	|	ON
	|		UnmappedTargetObjectTable.Ref = UnmappedSourceObjectTable.Ref
	|	
	|	WHERE
	|		Not UnmappedSourceObjectTable.Ref IS NULL
	|	
	|	) AS NestedSelect
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {UnmappedTargetObjectsTableByFields}
	|SELECT
	|	
	|	#custom_Fields_UnmappedObjectTable#
	|	
	|	UnmappedObjectTable.ReceiverPictureIndex,
	|	
	|	// {MAPPING REGISTER DATA}
	|	UnmappedObjectTable.UniqueSourceHandle,
	|	UnmappedObjectTable.UniqueReceiverHandle,
	|	UnmappedObjectTable.SourceType,
	|	UnmappedObjectTable.ReceiverType
	|INTO UnmappedTargetObjectTableByFields
	|FROM
	|	UnmappedTargetObjectTable AS UnmappedObjectTable
	|	LEFT JOIN
	|		AutomaticallyMappedObjectTableByGUID AS AutomaticallyMappedObjectTableByGUID
	|	ON
	|		UnmappedObjectTable.Ref = AutomaticallyMappedObjectTableByGUID.Ref
	|WHERE
	|	AutomaticallyMappedObjectTableByGUID.Ref IS NULL
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {UnmappedSourceObjectsTableByFields}
	|SELECT
	|	
	|	#custom_Fields_UnmappedObjectTable#
	|	
	|	UnmappedObjectTable.SourcePictureIndex,
	|	
	|	// {MAPPING REGISTER DATA}
	|	UnmappedObjectTable.UniqueSourceHandle,
	|	UnmappedObjectTable.UniqueReceiverHandle,
	|	UnmappedObjectTable.SourceType,
	|	UnmappedObjectTable.ReceiverType
	|INTO UnmappedSourceObjectTableByFields
	|FROM
	|	UnmappedSourceObjectTable AS UnmappedObjectTable
	|	LEFT JOIN
	|		AutomaticallyMappedObjectTableByGUID AS AutomaticallyMappedObjectTableByGUID
	|	ON
	|		UnmappedObjectTable.Ref = AutomaticallyMappedObjectTableByGUID.Ref
	|WHERE
	|	AutomaticallyMappedObjectTableByGUID.Ref IS NULL
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {AutomaticMatchedObjectsTableFull}  contains duplic//ate writes for source and receiver
	|SELECT
	|	
	|	#custom_Fields_MappingTable#
	|	
	|	ReceiverPictureIndex,
	|	SourcePictureIndex,
	|		
	|	// {MAPPING REGISTER DATA}
	|	UniqueSourceHandle,
	|	UniqueReceiverHandle,
	|	SourceType,
	|	ReceiverType
	|INTO AutomaticallyMappedObjectTableFull
	|FROM
	|	(SELECT
	|		
	|		#custom_Fields_AutomaticallyMappedObjectTableFull_NestedSelect#
	|		
	|		UnmappedTargetObjectTableByFields.ReceiverPictureIndex,
	|		UnmappedSourceObjectTableByFields.SourcePictureIndex,
	|		
	|		// {MAPPING REGISTER DATA}
	|		UnmappedSourceObjectTableByFields.UniqueSourceHandle AS UniqueSourceHandle,
	|		UnmappedSourceObjectTableByFields.SourceType                     AS SourceType,
	|		UnmappedTargetObjectTableByFields.UniqueReceiverHandle AS UniqueReceiverHandle,
	|		UnmappedTargetObjectTableByFields.ReceiverType                     AS ReceiverType
	|	FROM
	|		UnmappedTargetObjectTableByFields AS UnmappedTargetObjectTableByFields
	|	LEFT JOIN
	|		UnmappedSourceObjectTableByFields AS UnmappedSourceObjectTableByFields
	|	ON
	|		#Condition_mapping_ON_FIELDS#
	|	
	|	WHERE
	|		Not UnmappedSourceObjectTableByFields.UniqueSourceHandle IS NULL
	|	
	|	) AS NestedSelect
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {WrongMappedSourceObjectsTable}
	|SELECT
	|	
	|	// {MAPPING REGISTER DATA}
	|	UniqueSourceHandle
	|	
	|INTO WrongMappedSourceObjectTable
	|FROM
	|	(SELECT
	|	
	|		// {MAPPING REGISTER DATA}
	|		UniqueSourceHandle
	|	FROM
	|		AutomaticallyMappedObjectTableFull
	|	GROUP BY
	|		UniqueSourceHandle
	|	HAVING
	|		SUM(1) > 1
	|	
	|	) AS NestedSelect
	|;
	|
	|
	|//////////////////////////////////////////////////////////////////////////////// {WrongMappedTargetObjectsTable}
	|SELECT
	|	
	|	// {MAPPING REGISTER DATA}
	|	UniqueReceiverHandle
	|	
	|INTO WrongMappedSourceObjectTable
	|FROM
	|	(SELECT
	|	
	|		// {MAPPING REGISTER DATA}
	|		UniqueReceiverHandle
	|	FROM
	|		AutomaticallyMappedObjectTableFull
	|	GROUP BY
	|		UniqueReceiverHandle
	|	HAVING
	|		SUM(1) > 1
	|	
	|	) AS NestedSelect
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {AutomaticallyMappedObjectsTableByFields}
	|SELECT
	|	
	|	#custom_Fields_MappingTable#
	|	
	|	ReceiverPictureIndex,
	|	SourcePictureIndex,
	|	
	|	// {MAPPING REGISTER DATA}
	|	UniqueSourceHandle,
	|	UniqueReceiverHandle,
	|	SourceType,
	|	ReceiverType
	|INTO AutomaticallyMappedObjectTableByFields
	|FROM
	|	(SELECT
	|	
	|		#custom_Fields_MappingTable#
	|	
	|		AutomaticallyMappedObjectTableFull.ReceiverPictureIndex,
	|		AutomaticallyMappedObjectTableFull.SourcePictureIndex,
	|	
	|		// {MAPPING REGISTER DATA}
	|		AutomaticallyMappedObjectTableFull.UniqueSourceHandle,
	|		AutomaticallyMappedObjectTableFull.UniqueReceiverHandle,
	|		AutomaticallyMappedObjectTableFull.SourceType,
	|		AutomaticallyMappedObjectTableFull.ReceiverType
	|	FROM
	|		AutomaticallyMappedObjectTableFull AS AutomaticallyMappedObjectTableFull
	|	
	|	LEFT JOIN
	|		WrongMappedSourceObjectTable AS WrongMappedSourceObjectTable
	|	ON
	|		AutomaticallyMappedObjectTableFull.UniqueSourceHandle = WrongMappedSourceObjectTable.UniqueSourceHandle
	|	
	|	LEFT JOIN
	|		WrongMappedSourceObjectTable AS WrongMappedSourceObjectTable
	|	ON
	|		AutomaticallyMappedObjectTableFull.UniqueReceiverHandle = WrongMappedSourceObjectTable.UniqueReceiverHandle
	|	
	|	WHERE
	|		  WrongMappedSourceObjectTable.UniqueSourceHandle IS NULL
	|		AND WrongMappedSourceObjectTable.UniqueReceiverHandle IS NULL
	|	
	|	) AS NestedSelect
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {AutomaticallyMappedObjectsTable}
	|SELECT
	|	
	|	#custom_Fields_MappingTable#
	|	
	|	ReceiverPictureIndex,
	|	SourcePictureIndex,
	|	
	|	// {MAPPING REGISTER DATA}
	|	UniqueSourceHandle,
	|	UniqueReceiverHandle,
	|	SourceType,
	|	ReceiverType
	|INTO TableOfAutomaticallyMappedObjects
	|FROM
	|	(
	|	SELECT
	|
	|		#custom_Fields_MappingTable#
	|		
	|		ReceiverPictureIndex,
	|		SourcePictureIndex,
	|		
	|		// {MAPPING REGISTER DATA}
	|		UniqueSourceHandle,
	|		UniqueReceiverHandle,
	|		SourceType,
	|		ReceiverType
	|	FROM
	|		AutomaticallyMappedObjectTableByFields
	|
	|	UNION ALL
	|
	|	SELECT
	|
	|		#custom_Fields_MappingTable#
	|		
	|		ReceiverPictureIndex,
	|		SourcePictureIndex,
	|		
	|		// {MAPPING REGISTER DATA}
	|		UniqueSourceHandle,
	|		UniqueReceiverHandle,
	|		SourceType,
	|		ReceiverType
	|	FROM
	|		AutomaticallyMappedObjectTableByGUID
	|
	|	) AS NestedSelect
	|;
	|";
	
	QueryText = StrReplace(QueryText, "#MAPPING_CONDITION_BY_FIELDS#", GetMappingConditionByFields(MappingFieldList));
	QueryText = StrReplace(QueryText, "#USER_FIELDS_MappingTable#", GetUserFields(UserFields, "SourceFieldNN, ReceiverFieldNN,"));
	QueryText = StrReplace(QueryText, "#USER_FIELDS_UnmappedObjectsTable#", GetUserFields(UserFields, "UnmatchedObjectsTable.SourceFieldNN AS SourceFieldNN, UnmatchedObjectsTable.ReceiverFieldNN AS ReceiverFieldNN,"));
	QueryText = StrReplace(QueryText, "#USER_FIELDS_AutomaticallyMappedObjectsTableFull_NestedSelect#", GetUserFields(UserFields, "SourceUnmatchedObjectsTableByFields.SourceFieldNN AS SourceFieldNN, ReceiverUnmatchedObjectsTableByFields.ReceiverFieldNN AS ReceiverFieldNN,"));
	QueryText = StrReplace(QueryText, "#USER_FIELDS_AutomaticallyMappedObjectsTableByGUID_NestedSelect#", GetUserFields(UserFields, "SourceUnmatchedObjectsTable.SourceFieldNN AS SourceFieldNN, ReceiverUnmatchedObjectsTable.ReceiverFieldNN AS ReceiverFieldNN,"));
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Execute();
	
EndProcedure

Procedure RunSortingOfTableAtServer()
	
	SortingFields = GetSortFieldsAtServer();
	
	If Not IsBlankString(SortingFields) Then
		
		MappingTable().Sort(SortingFields);
		
	EndIf;
	
EndProcedure

Procedure GetMappingDigest(TempTablesManager)
	
	// Get the data on the number of mapped objects.
	GetNumberOfMappedObjects(TempTablesManager);
	
	MappingDigest().ObjectsCountInSource = DataExchangeServer.NumberOfRecordsInTemporaryTableOfDatabase("SourceTable", TempTablesManager);
	MappingDigest().ObjectsCountInReceiver = DataExchangeServer.NumberOfRecordInDatabaseTable(ReceiverTableName);
	
	MappedSourceObjectCount =   StatisticsInformationOfObjectsMapping().MappedByRegisterSourceObjectCount
												+ StatisticsInformationOfObjectsMapping().MappedByUnapprovedRelationsObjectCount;
	//
	MappedTargetObjectCount =   StatisticsInformationOfObjectsMapping().MappedByRegisterSourceObjectCount
												+ StatisticsInformationOfObjectsMapping().MappedByRegisterTargetObjectCount
												+ StatisticsInformationOfObjectsMapping().MappedByUnapprovedRelationsObjectCount;
	
	UnmappedSourceObjectCount = Max(0, MappingDigest().ObjectsCountInSource - MappedSourceObjectCount);
	UnmappedTargetObjectsNumber = Max(0, MappingDigest().ObjectsCountInReceiver - MappedTargetObjectCount);
	
	SourceObjectsMappingPercent = ?(MappingDigest().ObjectsCountInSource = 0, 0, 100 - Int(100 * UnmappedSourceObjectCount / MappingDigest().ObjectsCountInSource));
	TargetObjectsMappingPercent = ?(MappingDigest().ObjectsCountInReceiver = 0, 0, 100 - Int(100 * UnmappedTargetObjectsNumber / MappingDigest().ObjectsCountInReceiver));
	
	MappingDigest().ObjectsMappingPercent = Max(SourceObjectsMappingPercent, TargetObjectsMappingPercent);
	
	MappingDigest().UnmappedObjectsCount = min(UnmappedSourceObjectCount, UnmappedTargetObjectsNumber);
	
	MappingDigest().NumberOfObjectsMapped = MappedTargetObjectCount;
	
EndProcedure

Procedure GetNumberOfMappedObjects(TempTablesManager)
	
	// Get the number of mapped objects.
	QueryText = "
	|SELECT
	|	Count(*) AS Quantity
	|FROM
	|	MappedSourceObjectTableByRegister
	|;
	|/////////////////////////////////////////////////////////////////////////////
	|
	|SELECT
	|	Count(*) AS Quantity
	|FROM
	|	MappedTargetObjectTableByRegister
	|;
	|/////////////////////////////////////////////////////////////////////////////
	|
	|SELECT
	|	Count(*) AS Quantity
	|FROM
	|	MappedObjectTableByUnapprovedRelations
	|;
	|/////////////////////////////////////////////////////////////////////////////
	|";
	
	Query = New Query;
	Query.Text                   = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	ResultsArray = Query.ExecuteBatch();
	
	StatisticsInformationOfObjectsMapping().MappedByRegisterSourceObjectCount    = ResultsArray[0].Unload()[0]["Quantity"];
	StatisticsInformationOfObjectsMapping().MappedByRegisterTargetObjectCount    = ResultsArray[1].Unload()[0]["Quantity"];
	StatisticsInformationOfObjectsMapping().MappedByUnapprovedRelationsObjectCount = ResultsArray[2].Unload()[0]["Quantity"];
	
EndProcedure

Procedure AddNumberFieldToMappingTable()
	
	MappingTable().Columns.Add("SerialNumber", New TypeDescription("Number"));
	
	For Each TableRow IN MappingTable() Do
		
		TableRow.SerialNumber = MappingTable().IndexOf(TableRow);
		
	EndDo;
	
EndProcedure

Function MergeTablesOfUnapprovedLinksAndAutomaticMapping(TempTablesManager)
	
	QueryText = "
	|SELECT
	|
	|	// {MAPPING REGISTER DATA}
	|	UniqueSourceHandle,
	|	UniqueReceiverHandle,
	|	SourceType,
	|	ReceiverType
	|FROM
	|	(
	|	SELECT
	|
	|		// {MAPPING REGISTER DATA}
	|		UniqueSourceHandle,
	|		UniqueReceiverHandle,
	|		SourceType,
	|		ReceiverType
	|	FROM 
	|		TableOfUnapprovedLinks
	|
	|	UNION
	|
	|	SELECT
	|
	|		// {MAPPING REGISTER DATA}
	|		UniqueReceiverHandle AS UniqueSourceHandle,
	|		UniqueSourceHandle AS UniqueReceiverHandle,
	|		ReceiverType                     AS SourceType,
	|		SourceType                     AS ReceiverType
	|	FROM 
	|		TableOfAutomaticallyMappedObjects
	|
	|	) AS NestedSelect
	|
	|		UniqueReceiverHandle AS UniqueSourceHandle,
	|		UniqueSourceHandle AS UniqueReceiverHandle,
	|		ReceiverType                     AS SourceType,
	|		SourceType                     AS ReceiverType
	|	FROM 
	|		TableOfAutomaticallyMappedObjects
	|
	|	) AS NestedSelect
	|
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Return Query.Execute().Unload();
	
EndFunction

Function TableOfAutomaticallyMappedObjectsGet(TempTablesManager, UserFields)
	
	QueryText = "
	|SELECT
	|	
	|	#custom_Fields_MappingTable#
	|	
	|	TRUE AS Check,
	|	
	|	ReceiverPictureIndex,
	|	SourcePictureIndex,
	|	
	|	// {MAPPING REGISTER DATA}
	|	UniqueReceiverHandle AS UniqueSourceHandle,
	|	UniqueSourceHandle AS UniqueReceiverHandle,
	|	ReceiverType                     AS SourceType,
	|	SourceType                     AS ReceiverType
	|FROM
	|	TableOfAutomaticallyMappedObjects
	|";
	
	QueryText = StrReplace(QueryText, "#USER_FIELDS_MappingTable#", GetUserFields(UserFields, "SourceFieldNN, ReceiverFieldNN,"));
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Return Query.Execute().Unload();
	
EndFunction

Function GetMappingTable(SourceTable, UserFields, TempTablesManager)
	
	QueryText = "
	|////////////////////////////////////////////////////////////////////////////////
	|
	|SELECT
	|
	|	#custom_Fields_MappingTable#
	|
	|	#Fields_order#
	|
	|	MappingState,
	|	MappingStateAdditional,
	|
	|	SourcePictureIndex AS PictureIndex,
	|
	|	ReceiverPictureIndex,
	|	SourcePictureIndex,
	|
	|	// {MAPPING REGISTER DATA}
	|	UniqueSourceHandle,
	|	UniqueReceiverHandle,
	|	SourceType,
	|	ReceiverType
	|FROM
	|	UnmappedSourceObjectTable
	|
	|UNION ALL
	|
	|SELECT
	|
	|	#custom_Fields_MappingTable#
	|
	|	#Fields_order#
	|
	|	MappingState,
	|	MappingStateAdditional,
	|
	|	ReceiverPictureIndex AS PictureIndex,
	|
	|	ReceiverPictureIndex,
	|	SourcePictureIndex,
	|
	|	// {MAPPING REGISTER DATA}
	|	UniqueSourceHandle,
	|	UniqueReceiverHandle,
	|	SourceType,
	|	ReceiverType
	|FROM
	|	UnmappedTargetObjectTable
	|
	|UNION ALL
	|
	|SELECT
	|
	|	#custom_Fields_MappingTable#
	|
	|	#Fields_order#
	|
	|	MappingState,
	|	MappingStateAdditional,
	|
	|	ReceiverPictureIndex AS PictureIndex,
	|
	|	ReceiverPictureIndex,
	|	SourcePictureIndex,
	|
	|	// {MAPPING REGISTER DATA}
	|	UniqueSourceHandle,
	|	UniqueReceiverHandle,
	|	SourceType,
	|	ReceiverType
	|FROM
	|	MappedObjectTable
	|";
	
	QueryText = StrReplace(QueryText, "#USER_FIELDS_MappingTable#", GetUserFields(UserFields, "SourceFieldNN, ReceiverFieldNN,"));
	QueryText = StrReplace(QueryText, "#Fields_order#", GetUserFields(UserFields, "FieldSortingNN,"));
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Return Query.Execute().Unload();
	
EndFunction

Function GetTableOfSourceInformationBase(Cancel)
	
	// Return value of the function.
	DataTable = Undefined;
	
	DataExchangeDataProcessor = DataExchangeServer.ExchangeProcessingForDataImport(Cancel, InfobaseNode, ExchangeMessageFileName);
	
	If Cancel Then
		Return Undefined;
	EndIf;
	
	DataTableKey = DataExchangeServer.DataTableKey(SourceTypeAsString, ReceiverTypeAsString, ThisIsObjectDeletion);
	
	// Data table can be already imported and can be in the data processor cache DataExchangeDataProcessor.
	DataTable = DataExchangeDataProcessor.DataTablesOfExchangeMessage().Get(DataTableKey);
	
	// If data table was not imported, then import the table.
	If DataTable = Undefined Then
		
		TableToImport = New Array;
		TableToImport.Add(DataTableKey);
		
		// UPLOAD DATA IN MAPPING MODE (write data to the table of values).
		DataExchangeDataProcessor.ExecuteDataImportToValueTable(TableToImport);
		
		If DataExchangeDataProcessor.ErrorFlag() Then
			
			NString = NStr("en='Errors occurred when loading the exchange message: %1';ru='При загрузке сообщения обмена возникли ошибки: %1'");
			NString = StringFunctionsClientServer.PlaceParametersIntoString(NString, DataExchangeDataProcessor.ErrorMessageString());
			CommonUseClientServer.MessageToUser(NString,,,, Cancel);
			Return Undefined;
		EndIf;
		
		DataTable = DataExchangeDataProcessor.DataTablesOfExchangeMessage().Get(DataTableKey);
		
	EndIf;
	
	If DataTable = Undefined Then
		
		Cancel = True;
		
	EndIf;
	
	Return DataTable;
EndFunction

Function GetUserFields(UserFields, FieldPattern)
	
	// Return value of the function.
	Result = "";
	
	For Each Field IN UserFields Do
		
		FieldNumber = UserFields.Find(Field) + 1;
		
		CurrentField = StrReplace(FieldPattern, "#", Field);
		
		CurrentField = StrReplace(CurrentField, "NN", String(FieldNumber));
		
		Result = Result + Chars.LF + CurrentField;
		
	EndDo;
	
	Return Result;
	
EndFunction

Function GetSortFieldsAtServer()
	
	// Return value of the function.
	SortingFields = "";
	
	FieldPattern = "FieldSortingNN #SortingDirection"; // Not localized
	
	For Each TableRow IN SortTable Do
		
		If TableRow.Use Then
			
			Delimiter = ?(IsBlankString(SortingFields), "", ", ");
			
			SortDirectionStr = ?(TableRow.SortDirection, "Asc", "Desc");
			
			ItemOfList = ListOfUsedFields.FindByValue(TableRow.FieldName);
			
			FieldIndex = ListOfUsedFields.IndexOf(ItemOfList) + 1;
			
			FieldName = StrReplace(FieldPattern, "NN", String(FieldIndex));
			FieldName = StrReplace(FieldName, "#SortingDirection", SortDirectionStr);
			
			SortingFields = SortingFields + Delimiter + FieldName;
			
		EndIf;
		
	EndDo;
	
	Return SortingFields;
	
EndFunction

Function GetMappingConditionByFields(MappingFieldList)
	
	// Return value of the function.
	Result = "";
	
	For Each Item IN MappingFieldList Do
		
		If Item.Check Then
			
			If Find(Item.Presentation, DataExchangeServer.OpenEndedString()) > 0 Then
				
				FieldPattern = "SUBSTRING (ReceiverUnmatchedObjectsTableByFields.ReceiverFieldNN, 0, 1024) = SUBSTRING (SourceUnmatchedObjectsTableByFields.SourceFieldNN, 0, 1024)";
				
			Else
				
				FieldPattern = "ReceiverUnmatchedObjectsTableByFields.ReceiverFieldNN = SourceUnmatchedObjectsTableByFields.ReceiverFieldNN";
				
			EndIf;
			
			FieldNumber = MappingFieldList.IndexOf(Item) + 1;
			
			CurrentField = StrReplace(FieldPattern, "NN", String(FieldNumber));
			
			OperationLiteral = ?(IsBlankString(Result), "", "AND");
			
			Result = Result + Chars.LF + OperationLiteral + " " + CurrentField;
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Helper service procedures and functions.

Procedure FillListByMarkedItems(SourceList, TargetList)
	
	TargetList.Clear();
	
	For Each Item IN SourceList Do
		
		If Item.Check Then
			
			TargetList.Add(Item.Value, Item.Presentation, True);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure FillSortingTable(SourceValueList)
	
	SortTable.Clear();
	
	For Each Item IN SourceValueList Do
		
		IsFirstField = SourceValueList.IndexOf(Item) = 0;
		
		TableRow = SortTable.Add();
		
		TableRow.FieldName               = Item.Value;
		TableRow.Use         = IsFirstField; // Sort by default by the first field.
		TableRow.SortDirection = True; // IN ascending order
		
	EndDo;
	
EndProcedure

Procedure FillListByAdditionalParameters(TableFieldList)
	
	MetadataObject = Metadata.FindByType(Type(TableSourceObjectTypeName));
	
	FieldListForDeletion = New Array;
	ValueStorageType = New TypeDescription("ValueStorage");
	
	For Each Item IN TableFieldList Do
		
		Attribute = MetadataObject.Attributes.Find(Item.Value);
		
		If  Attribute = Undefined
			AND DataExchangeServer.ThisIsStandardAttribute(MetadataObject.StandardAttributes, Item.Value) Then
			
			Attribute = MetadataObject.StandardAttributes[Item.Value];
			
		EndIf;
		
		If Attribute = Undefined Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='For metadata object ""%1"" attribute is not defined with name ""%2""';ru='Для объекта метаданных ""%1"" не определен реквизит с именем ""%2""'"),
				MetadataObject.FullName(),
				String(Item.Value));
		EndIf;
			
		If Attribute.Type = ValueStorageType Then
			
			FieldListForDeletion.Add(Item);
			Continue;
			
		EndIf;
		
		Presentation = "";
		
		If ThisIsOpenEndedString(Attribute) Then
			
			Presentation = StringFunctionsClientServer.PlaceParametersIntoString("%1 %2",
				?(IsBlankString(Attribute.Synonym), Attribute.Name, TrimAll(Attribute.Synonym)),
				DataExchangeServer.OpenEndedString());
		Else
			
			Presentation = TrimAll(Attribute.Synonym);
			
		EndIf;
		
		If IsBlankString(Presentation) Then
			
			Presentation = Attribute.Name;
			
		EndIf;
		
		Item.Presentation = Presentation;
		
	EndDo;
	
	For Each ElementToDelete IN FieldListForDeletion Do
		
		TableFieldList.Delete(ElementToDelete);
		
	EndDo;
	
EndProcedure

Procedure CheckNumberOfMappingFieldsInArray(Array)
	
	If Array.Count() > DataExchangeServer.MaximumQuantityOfFieldsOfObjectMapping() Then
		
		Array.Delete(Array.UBound());
		
		CheckNumberOfMappingFieldsInArray(Array);
		
	EndIf;
	
EndProcedure

Procedure AddSearchField(Array, Value)
	
	Item = TableFieldList.FindByValue(Value);
	
	If Item <> Undefined Then
		
		Array.Add(Item.Value);
		
	EndIf;
	
EndProcedure

Function ThisIsOpenEndedString(Attribute)
	
	Return Attribute.Type = TypeStringOfUnlimitedLength();
	
EndFunction

#EndRegion

#EndIf
