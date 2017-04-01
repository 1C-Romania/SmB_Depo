#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// The procedure updates the register data when configuration is changed.
// 
// Parameters:
//  HasChanges - Boolean (return value) - if there
//                  is a record, True is set, otherwise, it is not changed.
//
Procedure RefreshDataRegister(HasChanges = Undefined, CheckOnly = False) Export
	
	SetPrivilegedMode(True);
	
	StandardSubsystemsReUse.CatalogMetadataObjectsIDsCheckUse(True);
	
	If CheckOnly OR ExclusiveMode() Then
		SwitchOffSoleMode = False;
	Else
		SwitchOffSoleMode = True;
		SetExclusiveMode(True);
	EndIf;
	
	PossibleRightsMetadataObjects = PossibleRightsMetadataObjects();
	RolesRights = InformationRegisters.RolesRights.CreateRecordSet().Unload();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	IDs.Ref AS ID,
	|	IDs.FullName
	|FROM
	|	Catalog.MetadataObjectIDs AS IDs
	|WHERE
	|	Not IDs.DeletionMark";
	
	TableIdentifiers = Query.Execute().Unload();
	TableIdentifiers.Columns.Add("MetadataObject", New TypeDescription("MetadataObject"));
	TableIdentifiers.Indexes.Add("FullName");
	TableIdentifiers.Indexes.Add("MetadataObject");
	
	For Each PossibleRights IN PossibleRightsMetadataObjects Do
		For Each MetadataObject IN Metadata[PossibleRights.Collection] Do
			
			FullName = MetadataObject.FullName();
			ID = MetadataObjectID(TableIdentifiers, FullName);
			Fields = AllAccessRestrictionFieldsOfMetadataObject(MetadataObject, FullName);
			
			For Each Role IN Metadata.Roles Do
				
				If Not AccessRight("Read", MetadataObject, Role) Then
					Continue;
				EndIf;
				
				NewRow = RolesRights.Add();
				
				NewRow.Role = MetadataObjectID(TableIdentifiers, Role);
				NewRow.MetadataObject  = ID;
				
				NewRow.Insert = PossibleRights.AddRight
				                       AND AccessRight("Insert", MetadataObject, Role);
				
				NewRow.Update  = PossibleRights.EditRight
				                       AND AccessRight("Update", MetadataObject, Role);
				
				NewRow.ReadingNotLimited =
					Not AccessParameters("Read",       MetadataObject, Fields, Role).RestrictionByCondition;
				
				NewRow.AddingNotLimited =
					NewRow.Insert
					AND Not AccessParameters("Insert", MetadataObject, Fields, Role).RestrictionByCondition;
				
				NewRow.ChangingNotLimited =
					NewRow.Update
					AND Not AccessParameters("Update",  MetadataObject, Fields, Role).RestrictionByCondition;
				
				NewRow.view = AccessRight("view", MetadataObject, Role);
				
				NewRow.Edit = PossibleRights.EditRight
				                           AND AccessRight("Edit", MetadataObject, Role);
				
				NewRow.InteractiveInsert =
					PossibleRights.AddRight
					AND AccessRight("InteractiveInsert", MetadataObject, Role);
			EndDo;
			
		EndDo;
	EndDo;
	
	TemporaryTablesQueryText =
	"SELECT
	|	NewData.MetadataObject,
	|	NewData.Role,
	|	NewData.Insert,
	|	NewData.Update,
	|	NewData.ReadingNotLimited,
	|	NewData.AddingNotLimited,
	|	NewData.ChangingNotLimited,
	|	NewData.view,
	|	NewData.InteractiveInsert,
	|	NewData.Edit
	|INTO NewData
	|FROM
	|	&RolesRights AS NewData";
	
	QueryText =
	"SELECT
	|	NewData.MetadataObject,
	|	NewData.Role,
	|	NewData.Insert,
	|	NewData.Update,
	|	NewData.ReadingNotLimited,
	|	NewData.AddingNotLimited,
	|	NewData.ChangingNotLimited,
	|	NewData.view,
	|	NewData.InteractiveInsert,
	|	NewData.Edit,
	|	&InsertFieldsRowChangeKind
	|FROM
	|	NewData AS NewData";
	
	// Prepare the selected fields with an optional filter.
	Fields = New Array;
	Fields.Add(New Structure("MetadataObject"));
	Fields.Add(New Structure("Role"));
	Fields.Add(New Structure("Insert"));
	Fields.Add(New Structure("Update"));
	Fields.Add(New Structure("ReadingNotLimited"));
	Fields.Add(New Structure("AddingNotLimited"));
	Fields.Add(New Structure("ChangingNotLimited"));
	Fields.Add(New Structure("view"));
	Fields.Add(New Structure("InteractiveInsert"));
	Fields.Add(New Structure("Edit"));
	
	Query = New Query;
	Query.SetParameter("RolesRights", RolesRights);
	
	Query.Text = AccessManagementService.TextOfQuerySelectionChanges(
		QueryText, Fields, "InformationRegister.RolesRights", TemporaryTablesQueryText);
	
	Block = New DataLock;
	LockItem = Block.Add("Constant.AccessLimitationParameters");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem = Block.Add("InformationRegister.RolesRights");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Block.Lock();
		Changes = Query.Execute().Unload();
		
		Data = New Structure;
		Data.Insert("ManagerRegister",      InformationRegisters.RolesRights);
		Data.Insert("ChangeRowsContent", Changes);
		Data.Insert("CheckOnly",        CheckOnly);
		
		AccessManagementService.RefreshInformationRegister(Data, HasChanges);
		
		If CheckOnly Then
			CommitTransaction();
			Return;
		EndIf;
		
		Changes.GroupBy(
			"MetadataObject, Role, Insert, Edit", "RowChangeKind");
		
		ExcessiveRows = Changes.FindRows(New Structure("RowChangeKind", 0));
		For Each String IN ExcessiveRows Do
			Changes.Delete(String);
		EndDo;
		
		Changes.GroupBy("MetadataObject");
		
		If Not CheckOnly Then
			StandardSubsystemsServer.AddChangesToApplicationPerformenceParameters(
				"AccessLimitationParameters",
				"ObjectsMetadataRightRoles",
				CommonUse.FixedData(
					Changes.UnloadColumn("MetadataObject")));
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		If SwitchOffSoleMode Then
			SetExclusiveMode(False);
		EndIf;
		Raise;
	EndTry;
	
	If SwitchOffSoleMode Then
		SetExclusiveMode(False);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

Function PossibleRightsMetadataObjects()
	
	SetPrivilegedMode(True);
	
	MetadataObjectRights = New ValueTable;
	MetadataObjectRights.Columns.Add("Collection");
	MetadataObjectRights.Columns.Add("CollectionInSingle");
	MetadataObjectRights.Columns.Add("AddRight");
	MetadataObjectRights.Columns.Add("EditRight");
	MetadataObjectRights.Columns.Add("DeletingRight");
	
	String = MetadataObjectRights.Add();
	String.Collection         = "Catalogs";
	String.CollectionInSingle = "Catalog";
	String.AddRight   = True;
	String.EditRight    = True;
	String.DeletingRight     = True;
	
	String = MetadataObjectRights.Add();
	String.Collection         = "Documents";
	String.CollectionInSingle = "Document";
	String.AddRight   = True;
	String.EditRight    = True;
	String.DeletingRight     = True;
	
	String = MetadataObjectRights.Add();
	String.Collection         = "DocumentJournals";
	String.CollectionInSingle = "DocumentJournal";
	String.AddRight   = False;
	String.EditRight    = False;
	String.DeletingRight     = False;
	
	String = MetadataObjectRights.Add();
	String.Collection         = "ChartsOfCharacteristicTypes";
	String.CollectionInSingle = "ChartOfCharacteristicTypes";
	String.AddRight   = True;
	String.EditRight    = True;
	String.DeletingRight     = True;
	
	String = MetadataObjectRights.Add();
	String.Collection         = "ChartsOfAccounts";
	String.CollectionInSingle = "ChartOfAccounts";
	String.AddRight   = True;
	String.EditRight    = True;
	String.DeletingRight     = True;
	
	String = MetadataObjectRights.Add();
	String.Collection         = "ChartsOfCalculationTypes";
	String.CollectionInSingle = "ChartOfCalculationTypes";
	String.AddRight   = True;
	String.EditRight    = True;
	String.DeletingRight     = True;
	
	String = MetadataObjectRights.Add();
	String.Collection         = "InformationRegisters";
	String.CollectionInSingle = "InformationRegister";
	String.AddRight   = False;
	String.EditRight    = True;
	String.DeletingRight     = False;
	
	String = MetadataObjectRights.Add();
	String.Collection         = "AccumulationRegisters";
	String.CollectionInSingle = "AccumulationRegister";
	String.AddRight   = False;
	String.EditRight    = True;
	String.DeletingRight     = False;
	
	String = MetadataObjectRights.Add();
	String.Collection         = "AccountingRegisters";
	String.CollectionInSingle = "AccountingRegister";
	String.AddRight   = False;
	String.EditRight    = True;
	String.DeletingRight     = False;
	
	String = MetadataObjectRights.Add();
	String.Collection         = "CalculationRegisters";
	String.CollectionInSingle = "CalculationRegister";
	String.AddRight   = False;
	String.EditRight    = True;
	String.DeletingRight     = False;
	
	String = MetadataObjectRights.Add();
	String.Collection         = "BusinessProcesses";
	String.CollectionInSingle = "BusinessProcess";
	String.AddRight   = True;
	String.EditRight    = True;
	String.DeletingRight     = True;
	
	String = MetadataObjectRights.Add();
	String.Collection         = "Tasks";
	String.CollectionInSingle = "Task";
	String.AddRight   = True;
	String.EditRight    = True;
	String.DeletingRight     = True;
	
	Return MetadataObjectRights;
	
EndFunction

Function MetadataObjectID(TableIdentifiers, MetadataObject)
	
	If TypeOf(MetadataObject) = Type("MetadataObject") Then
		TableRow = TableIdentifiers.Find(MetadataObject, "MetadataObject");
		If TableRow <> Undefined Then
			Return TableRow.ID;
		EndIf;
		FullName = MetadataObject.FullName();
	Else
		FullName = MetadataObject;
	EndIf;
	
	TableRow = TableIdentifiers.Find(FullName, "FullName");
	If TableRow = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='An error occurred during the execution of CommonUse function.MetadataObjectID().
		|
		|For the metadata
		|object %1 an
		|identifier is not found in the Metadata objects identifiers catalog.';ru='Ошибка при выполнении функции ОбщегоНазначения.ИдентификаторОбъектаМетаданных().
		|
		|Для объекта
		|метаданных ""%1""
		|не найден идентификатор в справочнике ""Идентификаторы объектов метаданных"".'")
			+ StandardSubsystemsServer.SpecificationOfErrorParametersWorkApplicationForDeveloper(),
			FullName);
	EndIf;
	
	If TypeOf(MetadataObject) = Type("MetadataObject") Then
		TableRow.MetadataObject = MetadataObject;
	EndIf;
	
	Return TableRow.ID;
	
EndFunction

// The function returns the metadata object fields which may be used to limit the access.
//
// Parameters:
//  MetadataObject  - MetadataObject
//  IBObject        - Undefined, COMObject 
//  GetArrayOfNames - Boolean
//
// Returns:
//  String (names separated by comma).
//  If GetArrayOfNames = True, then String array.
//
Function AllAccessRestrictionFieldsOfMetadataObject(MetadataObject,
                                                   FullName,
                                                   IBObject = Undefined,
                                                   GetArrayOfNames = False)
	
	NamesOfCollections = New Array;
	TypeName = Left(FullName, Find(FullName, ".") - 1);
	
	If      TypeName = "Catalog" Then
		NamesOfCollections.Add("Attributes");
		NamesOfCollections.Add("TabularSections");
		NamesOfCollections.Add("StandardAttributes");
		
	ElsIf TypeName = "Document" Then
		NamesOfCollections.Add("Attributes");
		NamesOfCollections.Add("TabularSections");
		NamesOfCollections.Add("StandardAttributes");
		
	ElsIf TypeName = "DocumentJournal" Then
		NamesOfCollections.Add("Columns");
		NamesOfCollections.Add("StandardAttributes");
		
	ElsIf TypeName = "ChartOfCharacteristicTypes" Then
		NamesOfCollections.Add("Attributes");
		NamesOfCollections.Add("TabularSections");
		NamesOfCollections.Add("StandardAttributes");
		
	ElsIf TypeName = "ChartOfAccounts" Then
		NamesOfCollections.Add("Attributes");
		NamesOfCollections.Add("TabularSections");
		NamesOfCollections.Add("AccountingFlags");
		NamesOfCollections.Add("StandardAttributes");
		NamesOfCollections.Add("StandardTabularSections");
		
	ElsIf TypeName = "ChartOfCalculationTypes" Then
		NamesOfCollections.Add("Attributes");
		NamesOfCollections.Add("TabularSections");
		NamesOfCollections.Add("StandardAttributes");
		NamesOfCollections.Add("StandardTabularSections");
		
	ElsIf TypeName = "InformationRegister" Then
		NamesOfCollections.Add("Dimensions");
		NamesOfCollections.Add("Resources");
		NamesOfCollections.Add("Attributes");
		NamesOfCollections.Add("StandardAttributes");
		
	ElsIf TypeName = "AccumulationRegister" Then
		NamesOfCollections.Add("Dimensions");
		NamesOfCollections.Add("Resources");
		NamesOfCollections.Add("Attributes");
		NamesOfCollections.Add("StandardAttributes");
		
	ElsIf TypeName = "AccountingRegister" Then
		NamesOfCollections.Add("Dimensions");
		NamesOfCollections.Add("Resources");
		NamesOfCollections.Add("Attributes");
		NamesOfCollections.Add("StandardAttributes");
		
	ElsIf TypeName = "CalculationRegister" Then
		NamesOfCollections.Add("Dimensions");
		NamesOfCollections.Add("Resources");
		NamesOfCollections.Add("Attributes");
		NamesOfCollections.Add("StandardAttributes");
		
	ElsIf TypeName = "BusinessProcess" Then
		NamesOfCollections.Add("Attributes");
		NamesOfCollections.Add("TabularSections");
		NamesOfCollections.Add("StandardAttributes");
		
	ElsIf TypeName = "Task" Then
		NamesOfCollections.Add("AddressingAttributes");
		NamesOfCollections.Add("Attributes");
		NamesOfCollections.Add("TabularSections");
		NamesOfCollections.Add("StandardAttributes");
	EndIf;
	
	NamesOfFields = New Array;
	If IBObject = Undefined Then
		ValueStorageType = Type("ValueStorage");
	Else
		ValueStorageType = IBObject.NewObject("TypeDescription", "ValueStorage").Types().Get(0);
	EndIf;

	For Each CollectionName IN NamesOfCollections Do
		If CollectionName = "TabularSections"
		 OR CollectionName = "StandardTabularSections" Then
			For Each TabularSection IN MetadataObject[CollectionName] Do
				AddAccessRestrictionFieldOfMetadataObject(MetadataObject, TabularSection.Name, NamesOfFields, IBObject);
				Attributes = ?(CollectionName = "TabularSections", TabularSection.Attributes, TabularSection.StandardAttributes);
				For Each Field IN Attributes Do
					If Field.Type.ContainsType(ValueStorageType) Then
						Continue;
					EndIf;
					AddAccessRestrictionFieldOfMetadataObject(MetadataObject, TabularSection.Name + "." + Field.Name, NamesOfFields, IBObject);
				EndDo;
				If CollectionName = "StandardTabularSections" AND TabularSection.Name = "ExtDimensionTypes" Then
					For Each Field IN MetadataObject.ExtDimensionAccountingFlags Do
						AddAccessRestrictionFieldOfMetadataObject(MetadataObject, "ExtDimensionTypes." + Field.Name, NamesOfFields, IBObject);
					EndDo;
				EndIf;
			EndDo;
		Else
			For Each Field IN MetadataObject[CollectionName] Do
	 			If TypeName = "DocumentJournal"       AND Field.Name = "Type"
	 			 OR TypeName = "ChartOfCharacteristicTypes" AND Field.Name = "ValueType"
	 			 OR TypeName = "ChartOfAccounts"             AND Field.Name = "Kind"
	 			 OR TypeName = "AccumulationRegister"      AND Field.Name = "RecordType"
	 			 OR TypeName = "AccountingRegister"     AND CollectionName = "StandardAttributes" AND Find(Field.Name, "ExtDimension") > 0 Then
	 				Continue;
	 			EndIf;
				If CollectionName = "Columns" OR
					 Field.Type.ContainsType(ValueStorageType) Then
					Continue;
				EndIf;
				If (CollectionName = "Dimensions" OR CollectionName = "Resources")
				   AND ?(IBObject = Undefined, Metadata, IBObject.Metadata).AccountingRegisters.Contains(MetadataObject)
				   AND Not Field.Balance Then
					// Dr
					AddAccessRestrictionFieldOfMetadataObject(MetadataObject, Field.Name + "Dr", NamesOfFields, IBObject);
					// Cr
					AddAccessRestrictionFieldOfMetadataObject(MetadataObject, Field.Name + "Cr", NamesOfFields, IBObject);
				Else
					AddAccessRestrictionFieldOfMetadataObject(MetadataObject, Field.Name, NamesOfFields, IBObject);
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	If GetArrayOfNames Then
		Return NamesOfFields;
	EndIf;
	
	FieldList = "";
	For Each FieldName IN NamesOfFields Do
		FieldList = FieldList + ", " + FieldName;
	EndDo;
	
	Return Mid(FieldList, 3);
	
EndFunction

Procedure AddAccessRestrictionFieldOfMetadataObject(MetadataObject,
                                                          FieldName,
                                                          NamesOfFields,
                                                          IBObject)
	
	Try
		If IBObject = Undefined Then
			AccessParameters("Read", MetadataObject, FieldName, Metadata.Roles.FullRights);
		Else
			IBObject.AccessParameters(
				"Read",
				MetadataObject,
				FieldName,
				IBObject.Metadata.Roles.FullRights);
		EndIf;
		CanGetAccessParameters = True;
	Except
		// Some fields for which a reading limitation can not be
		// configured may cause errors when trying to get the access parameters.
		// These fields must be excluded at once - they are not to be checked for limitation.
		CanGetAccessParameters = False;
	EndTry;
	
	If CanGetAccessParameters Then
		NamesOfFields.Add(FieldName);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf