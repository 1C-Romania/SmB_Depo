#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// Updates user groupings to check allowed
// values by the Users and ExternalUsers access kinds.
// 
// It is required to call:
// 1) While adding a new user (or an external user),
//    While adding a new users group (or an external
//    users group), while changing user groups content (or external user groups).
//    Parameters = Structure with one of the properties or with two properties at once:
//    - Users:        one user or array.
//    - UsersGroups: one users group or array.
//
// 2) While changing performer groups.
//    Parameters = Structure with one property:
//    - PerformerGroups: it is Undefined, one performers group or array.
//
// 3) While changing external user authorization object.
//    Parameters = Structure with one property:
//    - AuthorizationObjects: it is Undefined, one authorization object or array.
//
// Types used in the parameters:
//
//  User         - CatalogRef.Users,
//                         CatalogRef.ExternalUsers.
//
//  User group - CatalogRef.UsersGroups,
//                         CatalogRef.ExternalUsersGroups.
//
//  Performer          - CatalogRef.Users,
//                         CatalogRef.ExternalUsers.
// 
//  Performers group  - for example, CatalogReference.TaskPerformersGroups.
//
//  Authorization object   - for example, CatalogReference.Individuals.
//
// Parameters:
//  Parameters     - Undefined - update all without filter.
//                  Structure - see options above.
//
//  HasChanges - Boolean (return value) - if there
//                  is a record, True is set, otherwise, it is not changed.
//
Procedure UpdateUsersGroups(Parameters = Undefined, HasChanges = Undefined) Export
	
	UpdateType = "";
	
	If Parameters = Undefined Then
		UpdateType = "All";
	
	ElsIf Parameters.Count() = 2
	        AND Parameters.Property("Users")
	        AND Parameters.Property("UsersGroups") Then
		
		UpdateType = "UsersAndUsersGroups";
		
	ElsIf Parameters.Count() = 1
	        AND Parameters.Property("Users") Then
		
		UpdateType = "UsersAndUsersGroups";
		
	ElsIf Parameters.Count() = 1
	        AND Parameters.Property("UsersGroups") Then
		
		UpdateType = "UsersAndUsersGroups";
		
	ElsIf Parameters.Count() = 1
	        AND Parameters.Property("PerformersGroups") Then
		
		UpdateType = "PerformersGroups";
		
	ElsIf Parameters.Count() = 1
	        AND Parameters.Property("AuthorizationObjects") Then
		
		UpdateType = "AuthorizationObjects";
	Else
		Raise
			NStr("en='An error occurred
		|in the UpdateUsersGroups procedure of the information register manager module Access value groups.
		|
		|Incorrect parameters are specified.';ru='Ошибка
		|в процедуре ОбновитьГруппировкиПользователей модуля менеджера регистра сведений Группы значений доступа.
		|
		|Указаны неверные параметры.'");
	EndIf;
	
	BeginTransaction();
	Try
		If InfobaseUpdate.InfobaseUpdateInProgress() Then
			DeleteExtraRecords(HasChanges);
		EndIf;
		
		If UpdateType = "UsersAndUsersGroups" Then
			
			If Parameters.Property("Users") Then
				RefreshUsers     (   Parameters.Users, HasChanges);
				UpgradeGroupsOfPerformers( , Parameters.Users, HasChanges);
			EndIf;
			
			If Parameters.Property("UsersGroups") Then
				RefreshUsersGroups(Parameters.UsersGroups, HasChanges);
			EndIf;
			
		ElsIf UpdateType = "PerformersGroups" Then
			UpgradeGroupsOfPerformers(Parameters.PerformersGroups, , HasChanges);
			
		ElsIf UpdateType = "AuthorizationObjects" Then
			RefreshAuthorizationObjects(Parameters.AuthorizationObjects, HasChanges);
		Else
			RefreshUsers      ( ,   HasChanges);
			RefreshUsersGroups( ,   HasChanges);
			UpgradeGroupsOfPerformers ( , , HasChanges);
			RefreshAuthorizationObjects ( ,   HasChanges);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Procedure deletes extra data according to
// the content change result of the value types and access value groups.
//
Procedure UpdateRegisterAuxiliaryDataByConfigurationChanges() Export
	
	SetPrivilegedMode(True);
	
	Parameters = AccessManagementServiceReUse.Parameters();
	
	LastChanges = StandardSubsystemsServer.ApplicationPerformenceParameterChanging(
		Parameters, "GroupsAndAccessValuesTypes");
	
	If LastChanges = Undefined
	 OR LastChanges.Count() > 0 Then
		
		AccessManagementService.SetDataFillingForAccessRestriction(True);
		UpdateAccessEmptyValuesGroups();
		DeleteExtraRecords();
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure updates register data while changing access values.
// 
// Parameters:
//  HasChanges - Boolean (return value) - if there
//                  is a record, True is set, otherwise, it is not changed.
//
Procedure RefreshDataRegister(HasChanges = Undefined) Export
	
	DeleteExtraRecords(HasChanges);
	
	UpdateUsersGroups( , HasChanges);
	
	RefreshAccessValuesGroups( , HasChanges);
	
EndProcedure

// Updates access value groups to InformationRegister.AccessValueGroups.
//
// Parameters:
//  AccessValues - CatalogObject,
//                  - CatalogRef.
//                  - Array of the values specified above the types.
//                  - Undefined - without filter.
//                    Values type should be part of the dimension
//                    types content Information register value AccessValueGroups.
//                    If Object is passed, it will be updated only while changing it.
//
//  HasChanges   - Boolean (return value) - if there
//                    is a record, True is set, otherwise, it is not changed.
//
Procedure RefreshAccessValuesGroups(AccessValues = Undefined,
                                        HasChanges   = Undefined) Export
	
	If AccessValues = Undefined Then
		
		AccessValuesWithGroups = AccessManagementServiceReUse.Parameters(
			).AccessKindsProperties.AccessValuesWithGroups;
		
		Query = New Query;
		QueryText =
		"SELECT
		|	CurrentTable.Ref
		|FROM
		|	&CurrentTable AS CurrentTable";
		
		For Each TableName IN AccessValuesWithGroups.TablesNames Do
			
			Query.Text = StrReplace(QueryText, "&CurrentTable", TableName);
			Selection = Query.Execute().Select();
			
			ObjectManager = CommonUse.ObjectManagerByFullName(TableName);
			RefreshGroupsAccessValues(ObjectManager.EmptyRef(), HasChanges);
			
			While Selection.Next() Do
				RefreshGroupsAccessValues(Selection.Ref, HasChanges);
			EndDo;
		EndDo;
		
	ElsIf TypeOf(AccessValues) = Type("Array") Then
		
		For Each AccessValue IN AccessValues Do
			RefreshGroupsAccessValues(AccessValue, HasChanges);
		EndDo;
	Else
		RefreshGroupsAccessValues(AccessValues, HasChanges);
	EndIf;
	
EndProcedure

// Fills in groups for empty references of the access values used types.
Procedure UpdateAccessEmptyValuesGroups() Export
	
	AccessValuesWithGroups = AccessManagementServiceReUse.Parameters(
		).AccessKindsProperties.AccessValuesWithGroups;
	
	For Each TableName IN AccessValuesWithGroups.TablesNames Do
		ObjectManager = CommonUse.ObjectManagerByFullName(TableName);
		RefreshGroupsAccessValues(ObjectManager.EmptyRef(), Undefined);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

// Deletes strings that should not be there if they are added using a method.
Function DeleteExtraRecords(HasChanges = Undefined)
	
	GroupsAndAccessValuesTypes = AccessManagementServiceReUse.Parameters(
		).AccessKindsProperties.AccessValuesWithGroups.ValueGroupTypes;
	
	GroupsAndValuesTypesTable = New ValueTable;
	GroupsAndValuesTypesTable.Columns.Add("ValuesType",      Metadata.DefinedTypes.AccessValue.Type);
	GroupsAndValuesTypesTable.Columns.Add("ValueGroupType", Metadata.DefinedTypes.AccessValue.Type);
	
	For Each KeyAndValue IN GroupsAndAccessValuesTypes Do
		If TypeOf(KeyAndValue.Key) = Type("Type") Then
			Continue;
		EndIf;
		String = GroupsAndValuesTypesTable.Add();
		String.ValuesType      = KeyAndValue.Key;
		String.ValueGroupType = KeyAndValue.Value;
	EndDo;
	
	Query = New Query;
	Query.SetParameter("GroupsAndValuesTypesTable", GroupsAndValuesTypesTable);
	Query.Text =
	"SELECT
	|	TypesTable.ValuesType,
	|	TypesTable.ValueGroupType
	|INTO GroupsAndValuesTypesTable
	|FROM
	|	&GroupsAndValuesTypesTable AS TypesTable
	|
	|INDEX BY
	|	TypesTable.ValuesType,
	|	TypesTable.ValueGroupType
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AccessValuesGroups.AccessValue,
	|	AccessValuesGroups.AccessValuesGroup,
	|	AccessValuesGroups.DataGroup
	|FROM
	|	InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|WHERE
	|	CASE
	|			WHEN AccessValuesGroups.AccessValue = UNDEFINED
	|				THEN TRUE
	|			WHEN AccessValuesGroups.DataGroup = 0
	|				THEN Not TRUE In
	|							(SELECT TOP 1
	|								TRUE
	|							FROM
	|								GroupsAndValuesTypesTable AS GroupsAndValuesTypesTable
	|							WHERE
	|								VALUETYPE(GroupsAndValuesTypesTable.ValuesType) = VALUETYPE(AccessValuesGroups.AccessValue)
	|								AND VALUETYPE(GroupsAndValuesTypesTable.ValueGroupType) = VALUETYPE(AccessValuesGroups.AccessValuesGroup))
	|			WHEN AccessValuesGroups.DataGroup = 1
	|				THEN CASE
	|						WHEN VALUETYPE(AccessValuesGroups.AccessValue) = Type(Catalog.Users)
	|							THEN VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> Type(Catalog.Users)
	|									AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> Type(Catalog.UsersGroups)
	|						WHEN VALUETYPE(AccessValuesGroups.AccessValue) = Type(Catalog.ExternalUsers)
	|							THEN VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> Type(Catalog.ExternalUsers)
	|									AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> Type(Catalog.ExternalUsersGroups)
	|						ELSE TRUE
	|					END
	|			WHEN AccessValuesGroups.DataGroup = 2
	|				THEN CASE
	|						WHEN VALUETYPE(AccessValuesGroups.AccessValue) = Type(Catalog.UsersGroups)
	|							THEN VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> Type(Catalog.Users)
	|									AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> Type(Catalog.UsersGroups)
	|						WHEN VALUETYPE(AccessValuesGroups.AccessValue) = Type(Catalog.ExternalUsersGroups)
	|							THEN VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> Type(Catalog.ExternalUsers)
	|									AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> Type(Catalog.ExternalUsersGroups)
	|						ELSE TRUE
	|					END
	|			WHEN AccessValuesGroups.DataGroup = 3
	|				THEN CASE
	|						WHEN VALUETYPE(AccessValuesGroups.AccessValue) = Type(Catalog.Users)
	|								OR VALUETYPE(AccessValuesGroups.AccessValue) = Type(Catalog.UsersGroups)
	|								OR VALUETYPE(AccessValuesGroups.AccessValue) = Type(Catalog.ExternalUsers)
	|								OR VALUETYPE(AccessValuesGroups.AccessValue) = Type(Catalog.ExternalUsersGroups)
	|							THEN TRUE
	|						WHEN VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> Type(Catalog.Users)
	|								AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> Type(Catalog.UsersGroups)
	|								AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> Type(Catalog.ExternalUsers)
	|								AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> Type(Catalog.ExternalUsersGroups)
	|							THEN TRUE
	|						ELSE FALSE
	|					END
	|			WHEN AccessValuesGroups.DataGroup = 4
	|				THEN CASE
	|						WHEN VALUETYPE(AccessValuesGroups.AccessValue) = Type(Catalog.Users)
	|								OR VALUETYPE(AccessValuesGroups.AccessValue) = Type(Catalog.UsersGroups)
	|								OR VALUETYPE(AccessValuesGroups.AccessValue) = Type(Catalog.ExternalUsers)
	|								OR VALUETYPE(AccessValuesGroups.AccessValue) = Type(Catalog.ExternalUsersGroups)
	|							THEN TRUE
	|						WHEN VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> Type(Catalog.ExternalUsers)
	|								AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> Type(Catalog.ExternalUsersGroups)
	|							THEN TRUE
	|						ELSE FALSE
	|					END
	|			ELSE TRUE
	|		END";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		While Selection.Next() Do
			RecordSet = InformationRegisters.AccessValuesGroups.CreateRecordSet();
			RecordSet.Filter.AccessValue.Set(Selection.AccessValue);
			RecordSet.Filter.AccessValuesGroup.Set(Selection.AccessValuesGroup);
			RecordSet.Filter.DataGroup.Set(Selection.DataGroup);
			RecordSet.Write();
			HasChanges = True;
		EndDo;
	EndIf;
	
EndFunction

// Updates access value groups to InformationRegister.AccessValueGroups.
//
// Parameters:
//  AccessValue - CatalogRef.
//                    CatalogObject.
//                    If Object is passed, it will be updated only while changing it.
//
//  HasChanges   - Boolean (return value) - if there
//                    is a record, True is set, otherwise, it is not changed.
//
Procedure RefreshGroupsAccessValues(AccessValue, HasChanges)
	
	SetPrivilegedMode(True);
	
	AccessValueType = TypeOf(AccessValue);
	
	AccessValuesWithGroups = AccessManagementServiceReUse.Parameters(
		).AccessKindsProperties.AccessValuesWithGroups;
	
	AccessTypeProperties = AccessValuesWithGroups.ByTypes.Get(AccessValueType);
	
	ErrorTitle =
		NStr("en='An error occurred while updating access value groups.
		|
		|';ru='Ошибка при обновлении групп значений доступа.
		|
		|'");
	
	If AccessTypeProperties = Undefined Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			ErrorTitle +
			NStr("en='Access
		|value groups usage is not set for the type ""%1"".';ru='Для
		|типа ""%1"" не настроено использование групп значений доступа.'"),
			String(AccessValueType));
	EndIf;
	
	If AccessValuesWithGroups.ByRefsTypes.Get(AccessValueType) = Undefined Then
		Ref = AccessManagementService.ObjectRef(AccessValue);
		Object = AccessValue;
	Else
		Ref = AccessValue;
		Object = Undefined;
	EndIf;
	
	// Prepare old field values.
	AttributeName      = "AccessGroup";
	TabularSectionName = "AccessGroups";
	If AccessTypeProperties.SeveralGroupsOfValues Then
		FieldForQuery = TabularSectionName;
	Else
		FieldForQuery = AttributeName;
	EndIf;
	
	Try
		OldValues = CommonUse.ObjectAttributesValues(Ref, FieldForQuery);
	Except
		Error = ErrorInfo();
		TypeMetadata = Metadata.FindByType(AccessValueType);
		If AccessTypeProperties.SeveralGroupsOfValues Then
			MetadataTabularSection = TypeMetadata.TabularSections.Find("AccessGroups");
			If MetadataTabularSection = Undefined
			 OR MetadataTabularSection.Attributes.Find("AccessGroup") = Undefined Then
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
					ErrorTitle +
					NStr("en='AccessGroups special tabular
		|section with the AccessGroup special
		|attribute is not created in the access values type.""%1""';ru='У типа значений доступа ""%1"" не создана специальная табличная часть ГруппыДоступа со специальным реквизитом ГруппаДоступа.'"),
					String(AccessValueType));
			Else
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
					ErrorTitle +
					NStr("en='Unable to read
		|the AccessGroup
		|tabular section with the AccessGroup
		|attribute in the access value
		|""%1"" of the type ""%2"" by mistake: %3';ru='У значения
		|доступа
		|""%1"" типа ""%2"" не удалось
		|прочитать табличную часть ГруппаДоступа
		|с реквизитом ГруппаДоступа по ошибке: %3'"),
					String(AccessValue),
					String(AccessValueType),
					BriefErrorDescription(Error));
			EndIf;
		Else
			If TypeMetadata.Attributes.Find("AccessGroup") = Undefined Then
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
					ErrorTitle +
					NStr("en='AccessGroup special attribute
		|is not created in the access values type ""%1"".';ru='У типа
		|значений доступа ""%1"" не создан специальный реквизит ГруппаДоступа.'"),
					String(AccessValueType));
			Else
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
					ErrorTitle +
					NStr("en='Unable to read
		|the AccessGroup
		|attribute in the access value ""%1""
		|of the type ""%2"" by mistake: %3';ru='У значения
		|доступа
		|""%1"" типа ""%2"" не удалось прочитать
		|реквизит ГруппаДоступа по ошибке: %3'"),
					String(AccessValue),
					String(AccessValueType),
					BriefErrorDescription(Error));
			EndIf;
		EndIf;
	EndTry;
	
	// Check object change.
	UpdateNeeded = False;
	If Object <> Undefined Then
		If Object.IsNew() Then
			UpdateNeeded = True;
		Else
			If AccessTypeProperties.SeveralGroupsOfValues Then
				Value = Object[TabularSectionName].Unload();
				Value.Sort(AttributeName);
				OldValues[TabularSectionName].Sort(AttributeName);
			Else
				Value = Object[AttributeName];
			EndIf;
			
			If Not CommonUse.DataMatch(Value, OldValues[FieldForQuery]) Then
				UpdateNeeded = True;
			EndIf;
		EndIf;
		NewValues = Object;
	Else
		UpdateNeeded = True;
		NewValues = OldValues;
	EndIf;
	
	If Not UpdateNeeded Then
		Return;
	EndIf;
	
	// Prepare new records for an update.
	NewRecords = InformationRegisters.AccessValuesGroups.CreateRecordSet().Unload();
	
	If AccessManagement.LimitAccessOnRecordsLevel() Then
		
		ValueGroupTypes = AccessManagementServiceReUse.Parameters(
			).AccessKindsProperties.AccessValuesWithGroups.ValueGroupTypes;
		
		AccessValuesGroupEmptyRef = ValueGroupTypes.Get(TypeOf(Ref));
		
		// Add value groups.
		If AccessTypeProperties.SeveralGroupsOfValues Then
			For Each String IN NewValues[TabularSectionName] Do
				Record = NewRecords.Add();
				Record.AccessValue       = Ref;
				Record.AccessValuesGroup = String[AttributeName];
				If TypeOf(Record.AccessValuesGroup) <> TypeOf(AccessValuesGroupEmptyRef) Then
					Record.AccessValuesGroup = AccessValuesGroupEmptyRef;
				EndIf;
			EndDo;
		Else
			Record = NewRecords.Add();
			Record.AccessValue       = Ref;
			Record.AccessValuesGroup = NewValues[AttributeName];
			If TypeOf(Record.AccessValuesGroup) <> TypeOf(AccessValuesGroupEmptyRef) Then
				Record.AccessValuesGroup = AccessValuesGroupEmptyRef;
			EndIf;
		EndIf;
		
	EndIf;
	
	If Object = Undefined Then
		AdditionalProperties = Undefined;
	Else
		AdditionalProperties = New Structure("LeadingObjectBeforeWrite", Object);
	EndIf;
	
	FixedSelection = New Structure;
	FixedSelection.Insert("AccessValue", Ref);
	FixedSelection.Insert("DataGroup", 0);
	
	Data = New Structure;
	Data.Insert("ManagerRegister",       InformationRegisters.AccessValuesGroups);
	Data.Insert("NewRecords",            NewRecords);
	Data.Insert("FixedSelection",     FixedSelection);
	Data.Insert("AdditionalProperties", AdditionalProperties);
	
	BeginTransaction();
	Try
		AccessManagementService.UpdateRecordsets(Data, HasChanges);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Updates user groupings to check allowed
// values by the Users and ExternalUsers access kinds.
//
// <AccessValue field content> <AccessValuesGroup>
//                            <DataGroup field content>
// a) for the Users
// access
// kind {comparison with T.<field>} {Comparison with AccessGroupValues.AccessValue}.
//                                  {Comparison with &CurrentUser}.
//
// User                  1 - The same User.
//
//                               1 - Users
//                                   group of the same user.
//
// b) for the
// access kind
// External users {comparison with T.<field>} {Comparison with AccessGroupValues.AccessValue}.
//                                  {Comparison with &CurrentExternalUser}.
//
// External user 1 - The same External user.
//
//                               1 - External
//                                   users group of the same external user.
//
Procedure RefreshUsers(Users1 = Undefined,
                                HasChanges = Undefined)
	
	SetPrivilegedMode(True);
	
	QueryText =
	"SELECT
	|	UsersGroupsContents.User AS AccessValue,
	|	UsersGroupsContents.UsersGroup AS AccessValuesGroup,
	|	1 AS DataGroup,
	|	&InsertFieldsRowChangeKind
	|FROM
	|	InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|WHERE
	|	VALUETYPE(UsersGroupsContents.User) = Type(Catalog.Users)
	|	AND &UsersFilterCondition1
	|
	|UNION ALL
	|
	|SELECT
	|	UsersGroupsContents.User,
	|	UsersGroupsContents.UsersGroup,
	|	1,
	|	&InsertFieldsRowChangeKind
	|FROM
	|	InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|WHERE
	|	VALUETYPE(UsersGroupsContents.User) = Type(Catalog.ExternalUsers)
	|	AND &UsersFilterCondition1";
	
	// Prepare the selected fields with an optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("AccessValue",       "&UsersFilterCondition2"));
	Fields.Add(New Structure("AccessValuesGroup"));
	Fields.Add(New Structure("DataGroup",          "&UpdatedDataGroupsFilterCondition"));
	
	Query = New Query;
	Query.Text = AccessManagementService.TextOfQuerySelectionChanges(
		QueryText, Fields, "InformationRegister.AccessValuesGroups");
	
	AccessManagementService.SetCriteriaForQuery(Query, Users1, "Users",
		"&UsersFilterCondition1:UsersGroupsContents.User 
   |&UsersFilterCondition2:OldData.AccessValue");
	
	AccessManagementService.SetCriteriaForQuery(Query, 1, "DataGroup",
		"&UpdatedDataGroupsFilterCondition:OldData.DataGroup");
	
	Data = New Structure;
	Data.Insert("ManagerRegister",      InformationRegisters.AccessValuesGroups);
	Data.Insert("ChangeRowsContent", Query.Execute().Unload());
	Data.Insert("FixedSelection",    New Structure("DataGroup", 1));
	
	AccessManagementService.RefreshInformationRegister(Data, HasChanges);
	
EndProcedure

// Updates user groupings to check allowed
// values by the Users and ExternalUsers access kinds.
//
// <AccessValue field content> <AccessValuesGroup>
//                            <DataGroup field content>
// a) for the Users
// access
// kind {comparison with T.<field>} {Comparison with AccessGroupValues.AccessValue}.
//                                  {Comparison with &CurrentUser}.
//
// Users group 2 - The same Users group.
//
//                               2 - User
//                                   of the same users group.
//
// b) for the
// access kind
// External users {comparison with T.<field>} {Comparison with AccessGroupValues.AccessValue}.
//                                  {Comparison with &CurrentExternalUser}.
//
// External users group 2 - The same External users group.
//
//                               2 - External
//                                   user of the same external users group.
//
//
Procedure RefreshUsersGroups(UsersGroups = Undefined,
                                      HasChanges       = Undefined)
	
	SetPrivilegedMode(True);
	
	QueryText =
	"SELECT DISTINCT
	|	UsersGroupsContents.UsersGroup AS AccessValue,
	|	UsersGroupsContents.UsersGroup AS AccessValuesGroup,
	|	2 AS DataGroup,
	|	&InsertFieldsRowChangeKind
	|FROM
	|	InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|WHERE
	|	VALUETYPE(UsersGroupsContents.UsersGroup) = Type(Catalog.UsersGroups)
	|	AND &UsersGroupsFilterCondition1
	|
	|UNION ALL
	|
	|SELECT
	|	UsersGroupsContents.UsersGroup,
	|	UsersGroupsContents.User,
	|	2,
	|	&InsertFieldsRowChangeKind
	|FROM
	|	InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|WHERE
	|	VALUETYPE(UsersGroupsContents.UsersGroup) = Type(Catalog.UsersGroups)
	|	AND VALUETYPE(UsersGroupsContents.User) = Type(Catalog.Users)
	|	AND &UsersGroupsFilterCondition1
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	UsersGroupsContents.UsersGroup,
	|	UsersGroupsContents.UsersGroup,
	|	2,
	|	&InsertFieldsRowChangeKind
	|FROM
	|	InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|WHERE
	|	VALUETYPE(UsersGroupsContents.UsersGroup) = Type(Catalog.ExternalUsersGroups)
	|	AND &UsersGroupsFilterCondition1
	|
	|UNION ALL
	|
	|SELECT
	|	UsersGroupsContents.UsersGroup,
	|	UsersGroupsContents.User,
	|	2,
	|	&InsertFieldsRowChangeKind
	|FROM
	|	InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|WHERE
	|	VALUETYPE(UsersGroupsContents.UsersGroup) = Type(Catalog.ExternalUsersGroups)
	|	AND VALUETYPE(UsersGroupsContents.User) = Type(Catalog.ExternalUsers)
	|	AND &UsersGroupsFilterCondition1";
	
	// Prepare the selected fields with an optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("AccessValue",         "&UsersGroupsFilterCondition2"));
	Fields.Add(New Structure("AccessValuesGroup"));
	Fields.Add(New Structure("DataGroup",            "&UpdatedDataGroupsFilterCondition"));
	
	Query = New Query;
	Query.Text = AccessManagementService.TextOfQuerySelectionChanges(
		QueryText, Fields, "InformationRegister.AccessValuesGroups");
	
	AccessManagementService.SetCriteriaForQuery(Query, UsersGroups, "UsersGroups",
		"&UsersGroupsFilterCondition1:UsersGroupsContents.UsersGroup
   |&UsersGroupsFilterCondition2:OldData.AccessValue");
	
	AccessManagementService.SetCriteriaForQuery(Query, 2, "DataGroup",
		"&UpdatedDataGroupsFilterCondition:OldData.DataGroup");
	
	Data = New Structure;
	Data.Insert("ManagerRegister",      InformationRegisters.AccessValuesGroups);
	Data.Insert("ChangeRowsContent", Query.Execute().Unload());
	Data.Insert("FixedSelection",    New Structure("DataGroup", 2));
	
	AccessManagementService.RefreshInformationRegister(Data, HasChanges);
	
EndProcedure

// Updates user groupings to check allowed
// values by the Users and ExternalUsers access kinds.
//
// <AccessValue field content> <AccessValuesGroup>
//                            <DataGroup field content>
// a) for the Users
// access
// kind {comparison with T.<field>} {Comparison with AccessGroupValues.AccessValue}.
//                                  {Comparison with &CurrentUser}.
//
// Performers group 3 - User
//                                   of the same performers group.
//
//                               3 - User users
//                                   group of the same performers group.
//
// b) for the
// access kind
// External users {comparison with T.<field>} {Comparison with AccessGroupValues.AccessValue}.
//                                  {Comparison with &CurrentExternalUser}.
//
// Performers group 3 - External
//                                   user of the same performers group.
//
//                               3 - External
//                                   users group
//                                   of an external user of the same performers group.
//
Procedure UpgradeGroupsOfPerformers(PerformersGroups = Undefined,
                                     Performers        = Undefined,
                                     HasChanges      = Undefined)
	
	SetPrivilegedMode(True);
	
	// Prepare table of the additional user groups -
	// of the performer groups (for example, jobs).
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	If PerformersGroups = Undefined
	   AND Performers        = Undefined Then
	
		ParameterContent = Undefined;
		ParameterValue   = Undefined;
	
	ElsIf PerformersGroups <> Undefined Then
		ParameterContent = "PerformersGroups";
		ParameterValue   = PerformersGroups;
		
	ElsIf Performers <> Undefined Then
		ParameterContent = "Performers";
		ParameterValue   = Performers;
	Else
		Raise
			NStr("en='An error occurred
		|in the UpdatePerformersGroup procedure of the AccessValueGroups information register manager module.
		|
		|Incorrect parameters are specified.';ru='Ошибка
		|в процедуре ОбновитьГруппыИсполнителей модуля менеджера регистра сведений ГруппыЗначенийДоступа.
		|
		|Указаны неверные параметры.'");
	EndIf;
	
	NoneGroupsPerformers = True;
	AccessManagementService.WithDefinitionOfGroupsOfPerformers(
		Query.TempTablesManager,
		ParameterContent,
		ParameterValue,
		NoneGroupsPerformers);
	
	If NoneGroupsPerformers Then
		RecordSet = InformationRegisters.AccessValuesGroups.CreateRecordSet();
		RecordSet.Filter.DataGroup.Set(3);
		RecordSet.Read();
		If RecordSet.Count() > 0 Then
			RecordSet.Clear();
			RecordSet.Write();
			HasChanges = True;
		EndIf;
		Return;
	EndIf;
	
	// Prepare the selected links of performers and performer groups.
	Query.SetParameter("ValueGroupsEmptyRefs",
		AccessManagementServiceReUse.SpecifiedTypesEmptyRefsTable(
			"InformationRegister.AccessValuesGroups.Dimension.AccessValuesGroup"));
	
	TemporaryTablesQueryText =
	"SELECT
	|	ValueGroupsEmptyRefs.EmptyRef
	|INTO ValueGroupsEmptyRefs
	|FROM
	|	&ValueGroupsEmptyRefs AS ValueGroupsEmptyRefs
	|
	|INDEX BY
	|	ValueGroupsEmptyRefs.EmptyRef
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TableOfExecutantGroups.GroupPerformers,
	|	TableOfExecutantGroups.User
	|INTO UsersOfExecutantGroups
	|FROM
	|	TableOfExecutantGroups AS TableOfExecutantGroups
	|		INNER JOIN ValueGroupsEmptyRefs AS ValueGroupsEmptyRefs
	|		ON (VALUETYPE(TableOfExecutantGroups.GroupPerformers) = VALUETYPE(ValueGroupsEmptyRefs.EmptyRef))
	|			AND TableOfExecutantGroups.GroupPerformers <> ValueGroupsEmptyRefs.EmptyRef
	|WHERE
	|	VALUETYPE(TableOfExecutantGroups.GroupPerformers) <> Type(Catalog.UsersGroups)
	|	AND VALUETYPE(TableOfExecutantGroups.GroupPerformers) <> Type(Catalog.Users)
	|	AND VALUETYPE(TableOfExecutantGroups.GroupPerformers) <> Type(Catalog.ExternalUsersGroups)
	|	AND VALUETYPE(TableOfExecutantGroups.GroupPerformers) <> Type(Catalog.ExternalUsers)
	|	AND VALUETYPE(TableOfExecutantGroups.User) = Type(Catalog.Users)
	|	AND TableOfExecutantGroups.User <> VALUE(Catalog.Users.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TableOfExecutantGroups.GroupPerformers,
	|	TableOfExecutantGroups.User AS ExternalUser
	|INTO ExternalUsersOfExecutantGroups
	|FROM
	|	TableOfExecutantGroups AS TableOfExecutantGroups
	|		INNER JOIN ValueGroupsEmptyRefs AS ValueGroupsEmptyRefs
	|		ON (VALUETYPE(TableOfExecutantGroups.GroupPerformers) = VALUETYPE(ValueGroupsEmptyRefs.EmptyRef))
	|			AND TableOfExecutantGroups.GroupPerformers <> ValueGroupsEmptyRefs.EmptyRef
	|WHERE
	|	VALUETYPE(TableOfExecutantGroups.GroupPerformers) <> Type(Catalog.UsersGroups)
	|	AND VALUETYPE(TableOfExecutantGroups.GroupPerformers) <> Type(Catalog.Users)
	|	AND VALUETYPE(TableOfExecutantGroups.GroupPerformers) <> Type(Catalog.ExternalUsersGroups)
	|	AND VALUETYPE(TableOfExecutantGroups.GroupPerformers) <> Type(Catalog.ExternalUsers)
	|	AND VALUETYPE(TableOfExecutantGroups.User) = Type(Catalog.ExternalUsers)
	|	AND TableOfExecutantGroups.User <> VALUE(Catalog.ExternalUsers.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TableOfExecutantGroups";
	
	If PerformersGroups = Undefined
	   AND Performers <> Undefined Then
		
		Query.Text = TemporaryTablesQueryText + "
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|" +
		"SELECT
		|	UsersOfExecutantGroups.GroupPerformers
		|FROM
		|	UsersOfExecutantGroups AS UsersOfExecutantGroups
		|
		|UNION
		|
		|SELECT
		|	ExternalUsersOfExecutantGroups.GroupPerformers
		|FROM
		|	ExternalUsersOfExecutantGroups AS ExternalUsersOfExecutantGroups";
		
		QueryResults = Query.ExecuteBatch();
		Quantity = QueryResults.Count();
		
		PerformersGroups = QueryResults[Quantity-1].Unload().UnloadColumn("GroupPerformers");
		TemporaryTablesQueryText = Undefined;
	EndIf;
	
	QueryText =
	"SELECT
	|	UsersOfExecutantGroups.GroupPerformers AS AccessValue,
	|	UsersOfExecutantGroups.User AS AccessValuesGroup,
	|	3 AS DataGroup,
	|	&InsertFieldsRowChangeKind
	|FROM
	|	UsersOfExecutantGroups AS UsersOfExecutantGroups
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	UsersOfExecutantGroups.GroupPerformers,
	|	UsersGroupsContents.UsersGroup,
	|	3,
	|	&InsertFieldsRowChangeKind
	|FROM
	|	UsersOfExecutantGroups AS UsersOfExecutantGroups
	|		INNER JOIN InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|		ON UsersOfExecutantGroups.User = UsersGroupsContents.User
	|			AND (VALUETYPE(UsersGroupsContents.UsersGroup) = Type(Catalog.UsersGroups))
	|
	|UNION ALL
	|
	|SELECT
	|	ExternalUsersOfExecutantGroups.GroupPerformers,
	|	ExternalUsersOfExecutantGroups.ExternalUser,
	|	3,
	|	&InsertFieldsRowChangeKind
	|FROM
	|	ExternalUsersOfExecutantGroups AS ExternalUsersOfExecutantGroups
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	ExternalUsersOfExecutantGroups.GroupPerformers,
	|	UsersGroupsContents.UsersGroup,
	|	3,
	|	&InsertFieldsRowChangeKind
	|FROM
	|	ExternalUsersOfExecutantGroups AS ExternalUsersOfExecutantGroups
	|		INNER JOIN InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|		ON ExternalUsersOfExecutantGroups.ExternalUser = UsersGroupsContents.User
	|			AND (VALUETYPE(UsersGroupsContents.UsersGroup) = Type(Catalog.ExternalUsersGroups))";
	
	// Prepare the selected fields with an optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("AccessValue",         "&PerformerGroupsFilterCondition"));
	Fields.Add(New Structure("AccessValuesGroup"));
	Fields.Add(New Structure("DataGroup",            "&UpdatedDataGroupsFilterCondition"));
	
	Query.Text = AccessManagementService.TextOfQuerySelectionChanges(
		QueryText, Fields, "InformationRegister.AccessValuesGroups", TemporaryTablesQueryText);
	
	AccessManagementService.SetCriteriaForQuery(Query, PerformersGroups, "PerformersGroups",
		"&CriteriaOfGroupsOfPerformers:OldData.AccessValue");
	
	AccessManagementService.SetCriteriaForQuery(Query, 3, "DataGroup",
		"&UpdatedDataGroupsFilterCondition:OldData.DataGroup");
	
	Data = New Structure;
	Data.Insert("ManagerRegister",      InformationRegisters.AccessValuesGroups);
	Data.Insert("ChangeRowsContent", Query.Execute().Unload());
	Data.Insert("FixedSelection",    New Structure("DataGroup", 3));
	
	AccessManagementService.RefreshInformationRegister(Data, HasChanges);
	
EndProcedure

// Updates user groupings to check allowed
// values by the Users and ExternalUsers access kinds.
//
// <AccessValue field content> <AccessValuesGroup
//                            field content> <DataGroup
// field content> b) for
// the External
// users access kind {comparison with T.<field>} {Comparison with AccessGroupValues.AccessValue}.
//                                  {Comparison with &CurrentExternalUser}.
//
// Authorization object 4 - External
//                                   user of the same authorization object.
//
//                               4 - External
//                                   users group
//                                   of an external user of the same authorization object.
//
Procedure RefreshAuthorizationObjects(AuthorizationObjects = Undefined, HasChanges = Undefined)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("ValuesEmptyRefs",
		AccessManagementServiceReUse.SpecifiedTypesEmptyRefsTable(
			"InformationRegister.AccessValuesGroups.Dimension.AccessValue"));
	
	TemporaryTablesQueryText =
	"SELECT
	|	ValuesEmptyRefs.EmptyRef
	|INTO ValuesEmptyRefs
	|FROM
	|	&ValuesEmptyRefs AS ValuesEmptyRefs
	|
	|INDEX BY
	|	ValuesEmptyRefs.EmptyRef";
	
	QueryText =
	"SELECT
	|	CAST(UsersGroupsContents.User AS Catalog.ExternalUsers).AuthorizationObject AS AccessValue,
	|	UsersGroupsContents.UsersGroup AS AccessValuesGroup,
	|	4 AS DataGroup,
	|	&InsertFieldsRowChangeKind
	|FROM
	|	InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|		INNER JOIN Catalog.ExternalUsers AS ExternalUsers
	|		ON (VALUETYPE(UsersGroupsContents.User) = Type(Catalog.ExternalUsers))
	|			AND UsersGroupsContents.User = ExternalUsers.Ref
	|		INNER JOIN ValuesEmptyRefs AS ValuesEmptyRefs
	|		ON (VALUETYPE(ExternalUsers.AuthorizationObject) = VALUETYPE(ValuesEmptyRefs.EmptyRef))
	|			AND (ExternalUsers.AuthorizationObject <> ValuesEmptyRefs.EmptyRef)
	|WHERE
	|	&FilterConditionObjectsAuthorization1";
	
	// Prepare the selected fields with an optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("AccessValue",         "&FilterConditionObjectsAuthorization2"));
	Fields.Add(New Structure("AccessValuesGroup"));
	Fields.Add(New Structure("DataGroup",            "&UpdatedDataGroupsFilterCondition"));
	
	Query.Text = AccessManagementService.TextOfQuerySelectionChanges(
		QueryText, Fields, "InformationRegister.AccessValuesGroups", TemporaryTablesQueryText);
	
	AccessManagementService.SetCriteriaForQuery(Query, AuthorizationObjects, "AuthorizationObjects",
		"&FilterConditionObjectsAuthorization1:ExternalUsers.AuthorizationObject
   |&FilterConditionObjectsAuthorization2:OldData.AccessValue");
	
	AccessManagementService.SetCriteriaForQuery(Query, 4, "DataGroup",
		"&UpdatedDataGroupsFilterCondition:OldData.DataGroup");
	
	Data = New Structure;
	Data.Insert("ManagerRegister",      InformationRegisters.AccessValuesGroups);
	Data.Insert("ChangeRowsContent", Query.Execute().Unload());
	Data.Insert("FixedSelection",    New Structure("DataGroup", 4));
	
	AccessManagementService.RefreshInformationRegister(Data, HasChanges);
	
EndProcedure

#EndRegion

#EndIf