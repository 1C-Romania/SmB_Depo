#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// Procedure updates the register data by role
// right change result saved when updating information register RolesRights.
//
Procedure UpdateRegisterDataByConfigurationChanges() Export
	
	SetPrivilegedMode(True);
	
	Parameters = AccessManagementServiceReUse.Parameters();
	
	LastChanges = StandardSubsystemsServer.ApplicationPerformenceParameterChanging(
		Parameters, "ObjectsMetadataRightRoles");
	
	If LastChanges = Undefined Then
		RefreshDataRegister();
	Else
		MetadataObjects = New Array;
		For Each ChangesPart IN LastChanges Do
			If TypeOf(ChangesPart) = Type("FixedArray") Then
				For Each MetadataObject IN ChangesPart Do
					If MetadataObjects.Find(MetadataObject) = Undefined Then
						MetadataObjects.Add(MetadataObject);
					EndIf;
				EndDo;
			Else
				MetadataObjects = Undefined;
				Break;
			EndIf;
		EndDo;
		
		If MetadataObjects.Count() > 0 Then
			RefreshDataRegister(, MetadataObjects);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure updates the register data on change profile
// role content and profile change at access groups.
// 
// Parameters:
//  AccessGroups - CatalogRef.AccessGroups.
//                - Undefined - without filter.
//
//  Tables       - CatalogRef.MetadataObjectIDs.
//                - Value array type specified above.
//                - Undefined - without filter.
//
//  HasChanges - Boolean (return value) - if there
//                  is a record, True is set, otherwise, it is not changed.
//
Procedure RefreshDataRegister(AccessGroups     = Undefined,
                                 Tables        = Undefined,
                                 HasChanges    = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If TypeOf(Tables) = Type("Array")
	   AND Tables.Count() > 500 Then
	
		Tables = Undefined;
	EndIf;
	
	QueryBlankRecords = New Query;
	QueryBlankRecords.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.AccessGroupsTables AS AccessGroupsTables
	|WHERE
	|	AccessGroupsTables.Table = VALUE(Catalog.MetadataObjectIDs.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.AccessGroupsTables AS AccessGroupsTables
	|WHERE
	|	AccessGroupsTables.AccessGroup = VALUE(Catalog.AccessGroups.EmptyRef)";
	
	TemporaryTablesQueryText =
	"SELECT
	|	AccessGroups.Profile AS Profile,
	|	RolesRights.MetadataObject AS Table,
	|	RolesRights.MetadataObject.EmptyRefValue AS TableType,
	|	MAX(RolesRights.Update) AS Update
	|INTO ProfilesTables
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroupsProfiles.Roles AS ProfileRoles
	|		ON AccessGroups.Profile = ProfileRoles.Ref
	|			AND (&AccessGroupFilterCondition1)
	|			AND (NOT AccessGroups.DeletionMark)
	|			AND (NOT ProfileRoles.Ref.DeletionMark)
	|			AND (ProfileRoles.Ref <> VALUE(Catalog.AccessGroupsProfiles.Administrator))
	|		INNER JOIN InformationRegister.RolesRights AS RolesRights
	|		ON (&TableFilterCondition1)
	|			AND (RolesRights.Role = ProfileRoles.Role)
	|			AND (NOT RolesRights.Role.DeletionMark)
	|			AND (NOT RolesRights.MetadataObject.DeletionMark)
	|
	|GROUP BY
	|	AccessGroups.Profile,
	|	RolesRights.MetadataObject,
	|	RolesRights.MetadataObject.EmptyRefValue
	|
	|INDEX BY
	|	RolesRights.MetadataObject
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ProfilesTables.Table,
	|	AccessGroups.Ref AS AccessGroup,
	|	ProfilesTables.Update AS Update,
	|	ProfilesTables.TableType AS TableType
	|INTO NewData
	|FROM
	|	ProfilesTables AS ProfilesTables
	|		INNER JOIN Catalog.AccessGroups AS AccessGroups
	|		ON (&AccessGroupFilterCondition1)
	|			AND (AccessGroups.Profile = ProfilesTables.Profile)
	|			AND (NOT AccessGroups.DeletionMark)
	|
	|INDEX BY
	|	ProfilesTables.Table,
	|	AccessGroups.Ref";
	
	QueryText =
	"SELECT
	|	NewData.Table,
	|	NewData.AccessGroup,
	|	NewData.Update,
	|	NewData.TableType,
	|	&InsertFieldsRowChangeKind
	|FROM
	|	NewData AS NewData";
	
	// Prepare the selected fields with an optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("Table",       "&TableFilterCondition2"));
	Fields.Add(New Structure("AccessGroup", "&AccessGroupFilterCondition2"));
	Fields.Add(New Structure("Update"));
	Fields.Add(New Structure("TableType"));
	
	Query = New Query;
	Query.Text = AccessManagementService.TextOfQuerySelectionChanges(
		QueryText, Fields, "InformationRegister.AccessGroupsTables", TemporaryTablesQueryText);
	
	AccessManagementService.SetCriteriaForQuery(Query, Tables, "Tables",
		"&TableFilterCondition1:RolesRights.MetadataObject
   |&TableFilterCondition2:OldData.Table");
	
	AccessManagementService.SetCriteriaForQuery(Query, AccessGroups, "AccessGroups",
		"&AccessGroupFilterCondition1:AccessGroups.Ref 
   |&AccessGroupFilterCondition2:OldData.AccessGroup");
		
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.AccessGroupsTables");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Block.Lock();
		Results = QueryBlankRecords.ExecuteBatch();
		If Not Results[0].IsEmpty() Then
			RecordSet = InformationRegisters.AccessGroupsTables.CreateRecordSet();
			RecordSet.Filter.Table.Set(Catalogs.MetadataObjectIDs.EmptyRef());
			RecordSet.Write();
			HasChanges = True;
		EndIf;
		If Not Results[1].IsEmpty() Then
			RecordSet = InformationRegisters.AccessGroupsTables.CreateRecordSet();
			RecordSet.Filter.AccessGroup.Set(Catalogs.AccessGroups.EmptyRef());
			RecordSet.Write();
			HasChanges = True;
		EndIf;
		
		If AccessGroups <> Undefined
		   AND Tables        = Undefined Then
			
			DimensionsOfSelection = "AccessGroup";
		Else
			DimensionsOfSelection = Undefined;
		EndIf;
		
		Data = New Structure;
		Data.Insert("ManagerRegister",      InformationRegisters.AccessGroupsTables);
		Data.Insert("ChangeRowsContent", Query.Execute().Unload());
		Data.Insert("DimensionsOfSelection",       DimensionsOfSelection);
		
		AccessManagementService.RefreshInformationRegister(Data, HasChanges);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#EndIf