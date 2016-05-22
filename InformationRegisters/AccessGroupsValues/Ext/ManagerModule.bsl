#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure updates register data during the change
// - of the allowed access group values,
// - allowed access group profile values,
// - access kinds usage.
// 
// Parameters:
//  AccessGroups - CatalogRef.AccessGroups.
//                - Array of the values specified above the types.
//                - Undefined - without filter.
//
//  HasChanges - Boolean (return value) - if there
//                  is a record, True is set, otherwise, it is not changed.
//
Procedure RefreshDataRegister(AccessGroups = Undefined, HasChanges = Undefined) Export
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.AccessGroupsValues");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem = Block.Add("InformationRegister.AccessGroupsDefaultValues");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		UsedAccessKinds = New ValueTable;
		UsedAccessKinds.Columns.Add("AccessKind", Metadata.DefinedTypes.AccessValue.Type);
		AccessKindsProperties = AccessManagementService.AccessTypeProperties();
		
		For Each AccessTypeProperties IN AccessKindsProperties Do
			If AccessManagementService.AccessKindIsUsed(AccessTypeProperties.Ref) Then
				UsedAccessKinds.Add().AccessKind = AccessTypeProperties.Ref;
			EndIf;
		EndDo;
		
		UpdateAllowedValues(UsedAccessKinds, AccessGroups, HasChanges);
		
		UpdateAllowedValuesByDefault(UsedAccessKinds, AccessGroups, HasChanges);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure UpdateAllowedValues(UsedAccessKinds, AccessGroups = Undefined, HasChanges = Undefined)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("UsedAccessKinds", UsedAccessKinds);
	
	Query.SetParameter("GroupsAndAccessKindValuesTypes",
		AccessManagementServiceReUse.GroupsAndAccessKindValuesTypes());
	
	TemporaryTablesQueryText =
	"SELECT
	|	UsedAccessKinds.AccessKind
	|INTO UsedAccessKinds
	|FROM
	|	&UsedAccessKinds AS UsedAccessKinds
	|
	|INDEX BY
	|	UsedAccessKinds.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GroupsAndAccessKindValuesTypes.AccessKind,
	|	GroupsAndAccessKindValuesTypes.GroupsAndValuesTypes
	|INTO GroupsAndAccessKindValuesTypes
	|FROM
	|	&GroupsAndAccessKindValuesTypes AS GroupsAndAccessKindValuesTypes
	|
	|INDEX BY
	|	GroupsAndAccessKindValuesTypes.GroupsAndValuesTypes,
	|	GroupsAndAccessKindValuesTypes.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroups.Ref AS AccessGroup,
	|	ProfileAccessValues.AccessKind,
	|	ProfileAccessValues.AccessValue,
	|	CASE
	|		WHEN AccessTypesProfile.AllAllowed
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS ValueAllowed
	|INTO ValuesSettings
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroupsProfiles.AccessKinds AS AccessTypesProfile
	|		ON AccessGroups.Profile = AccessTypesProfile.Ref
	|			AND (AccessTypesProfile.Preset)
	|			AND (NOT AccessGroups.DeletionMark)
	|			AND (NOT AccessTypesProfile.Ref.DeletionMark)
	|			AND (&AccessGroupFilterCondition1)
	|		INNER JOIN Catalog.AccessGroupsProfiles.AccessValues AS ProfileAccessValues
	|		ON (ProfileAccessValues.Ref = AccessTypesProfile.Ref)
	|			AND (ProfileAccessValues.AccessKind = AccessTypesProfile.AccessKind)
	|
	|UNION ALL
	|
	|SELECT
	|	AccessKinds.Ref,
	|	AccessValues.AccessKind,
	|	AccessValues.AccessValue,
	|	CASE
	|		WHEN AccessKinds.AllAllowed
	|			THEN FALSE
	|		ELSE TRUE
	|	END
	|FROM
	|	Catalog.AccessGroups.AccessKinds AS AccessKinds
	|		INNER JOIN Catalog.AccessGroupsProfiles.AccessKinds AS SpecifiedAccessKinds
	|		ON AccessKinds.Ref.Profile = SpecifiedAccessKinds.Ref
	|			AND AccessKinds.AccessKind = SpecifiedAccessKinds.AccessKind
	|			AND (NOT SpecifiedAccessKinds.Preset)
	|			AND (NOT AccessKinds.Ref.DeletionMark)
	|			AND (NOT SpecifiedAccessKinds.Ref.DeletionMark)
	|			AND (&AccessGroupFilterCondition2)
	|		INNER JOIN Catalog.AccessGroups.AccessValues AS AccessValues
	|		ON (AccessValues.Ref = AccessKinds.Ref)
	|			AND (AccessValues.AccessKind = AccessKinds.AccessKind)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ValuesSettings.AccessGroup,
	|	ValuesSettings.AccessValue,
	|	MAX(ValuesSettings.ValueAllowed) AS ValueAllowed
	|INTO NewData
	|FROM
	|	ValuesSettings AS ValuesSettings
	|		INNER JOIN GroupsAndAccessKindValuesTypes AS GroupsAndAccessKindValuesTypes
	|		ON ValuesSettings.AccessKind = GroupsAndAccessKindValuesTypes.AccessKind
	|			AND (VALUETYPE(ValuesSettings.AccessValue) = VALUETYPE(GroupsAndAccessKindValuesTypes.GroupsAndValuesTypes))
	|		INNER JOIN UsedAccessKinds AS UsedAccessKinds
	|		ON ValuesSettings.AccessKind = UsedAccessKinds.AccessKind
	|
	|GROUP BY
	|	ValuesSettings.AccessGroup,
	|	ValuesSettings.AccessValue
	|
	|INDEX BY
	|	ValuesSettings.AccessGroup,
	|	ValuesSettings.AccessValue,
	|	ValueAllowed
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP ValuesSettings";
	
	QueryText =
	"SELECT
	|	NewData.AccessGroup,
	|	NewData.AccessValue,
	|	NewData.ValueAllowed,
	|	&InsertFieldsRowChangeKind
	|FROM
	|	NewData AS NewData";
	
	// Prepare the selected fields with an optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("AccessGroup", "&AccessGroupFilterCondition3"));
	Fields.Add(New Structure("AccessValue"));
	Fields.Add(New Structure("ValueAllowed"));
	
	Query.Text = AccessManagementService.TextOfQuerySelectionChanges(
		QueryText, Fields, "InformationRegister.AccessGroupsValues", TemporaryTablesQueryText);
	
	AccessManagementService.SetCriteriaForQuery(Query, AccessGroups, "AccessGroups",
		"&AccessGroupFilterCondition1:AccessGroups.Ref
   |&AccessGroupFilterCondition2:AccessKinds.Ref
   |&AccessGroupFilterCondition3:OldData.AccessGroup");
	
	Data = New Structure;
	Data.Insert("ManagerRegister",      InformationRegisters.AccessGroupsValues);
	Data.Insert("ChangeRowsContent", Query.Execute().Unload());
	Data.Insert("DimensionsOfSelection",       "AccessGroup");
	
	AccessManagementService.RefreshInformationRegister(Data, HasChanges);
	
EndProcedure

Procedure UpdateAllowedValuesByDefault(UsedAccessKinds, AccessGroups = Undefined, HasChanges = Undefined)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("UsedAccessKinds", UsedAccessKinds);
	
	Query.SetParameter("GroupsAndAccessKindValuesTypes",
		AccessManagementServiceReUse.GroupsAndAccessKindValuesTypes());
	
	TemporaryTablesQueryText =
	"SELECT
	|	UsedAccessKinds.AccessKind
	|INTO UsedAccessKinds
	|FROM
	|	&UsedAccessKinds AS UsedAccessKinds
	|
	|INDEX BY
	|	UsedAccessKinds.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GroupsAndAccessKindValuesTypes.AccessKind,
	|	GroupsAndAccessKindValuesTypes.GroupsAndValuesTypes
	|INTO GroupsAndAccessKindValuesTypes
	|FROM
	|	&GroupsAndAccessKindValuesTypes AS GroupsAndAccessKindValuesTypes
	|
	|INDEX BY
	|	GroupsAndAccessKindValuesTypes.GroupsAndValuesTypes,
	|	GroupsAndAccessKindValuesTypes.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroups.Ref AS Ref,
	|	AccessGroups.Profile AS Profile
	|INTO AccessGroups
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroupsProfiles AS AccessGroupsProfiles
	|		ON AccessGroups.Profile = AccessGroupsProfiles.Ref
	|			AND (NOT AccessGroups.DeletionMark)
	|			AND (NOT AccessGroupsProfiles.DeletionMark)
	|			AND (&AccessGroupFilterCondition1)
	|
	|INDEX BY
	|	AccessGroups.Ref,
	|	AccessGroups.Profile
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroups.Ref AS AccessGroup,
	|	AccessTypesProfile.AccessKind,
	|	AccessTypesProfile.AllAllowed
	|INTO AccessKindSettings
	|FROM
	|	AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroupsProfiles.AccessKinds AS AccessTypesProfile
	|		ON AccessGroups.Profile = AccessTypesProfile.Ref
	|			AND (AccessTypesProfile.Preset)
	|		INNER JOIN UsedAccessKinds AS UsedAccessKinds
	|		ON (AccessTypesProfile.AccessKind = UsedAccessKinds.AccessKind)
	|
	|UNION ALL
	|
	|SELECT
	|	AccessKinds.Ref,
	|	AccessKinds.AccessKind,
	|	AccessKinds.AllAllowed
	|FROM
	|	AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroups.AccessKinds AS AccessKinds
	|		ON (AccessKinds.Ref = AccessGroups.Ref)
	|		INNER JOIN Catalog.AccessGroupsProfiles.AccessKinds AS SpecifiedAccessKinds
	|		ON (SpecifiedAccessKinds.Ref = AccessGroups.Profile)
	|			AND (SpecifiedAccessKinds.AccessKind = AccessKinds.AccessKind)
	|			AND (NOT SpecifiedAccessKinds.Preset)
	|		INNER JOIN UsedAccessKinds AS UsedAccessKinds
	|		ON (AccessKinds.AccessKind = UsedAccessKinds.AccessKind)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ValuesSettings.AccessGroup,
	|	GroupsAndAccessKindValuesTypes.AccessKind,
	|	TRUE AS WithSetting
	|INTO ValueSettingsPresence
	|FROM
	|	GroupsAndAccessKindValuesTypes AS GroupsAndAccessKindValuesTypes
	|		INNER JOIN InformationRegister.AccessGroupsValues AS ValuesSettings
	|		ON (VALUETYPE(GroupsAndAccessKindValuesTypes.GroupsAndValuesTypes) = VALUETYPE(ValuesSettings.AccessValue))
	|		INNER JOIN UsedAccessKinds AS UsedAccessKinds
	|		ON GroupsAndAccessKindValuesTypes.AccessKind = UsedAccessKinds.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroups.Ref AS AccessGroup,
	|	GroupsAndAccessKindValuesTypes.GroupsAndValuesTypes AS AccessValuesType,
	|	MAX(ISNULL(AccessKindSettings.AllAllowed, TRUE)) AS AllAllowed,
	|	MAX(ISNULL(ValueSettingsPresence.WithSetting, FALSE)) AS WithSetting
	|INTO PresetForNewData
	|FROM
	|	AccessGroups AS AccessGroups
	|		INNER JOIN GroupsAndAccessKindValuesTypes AS GroupsAndAccessKindValuesTypes
	|		ON (TRUE)
	|		LEFT JOIN AccessKindSettings AS AccessKindSettings
	|		ON (AccessKindSettings.AccessGroup = AccessGroups.Ref)
	|			AND (AccessKindSettings.AccessKind = GroupsAndAccessKindValuesTypes.AccessKind)
	|		LEFT JOIN ValueSettingsPresence AS ValueSettingsPresence
	|		ON (ValueSettingsPresence.AccessGroup = AccessKindSettings.AccessGroup)
	|			AND (ValueSettingsPresence.AccessKind = AccessKindSettings.AccessKind)
	|
	|GROUP BY
	|	AccessGroups.Ref,
	|	GroupsAndAccessKindValuesTypes.GroupsAndValuesTypes
	|
	|INDEX BY
	|	AccessGroups.Ref,
	|	GroupsAndAccessKindValuesTypes.GroupsAndValuesTypes
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PresetForNewData.AccessGroup,
	|	PresetForNewData.AccessValuesType,
	|	PresetForNewData.AllAllowed,
	|	CASE
	|		WHEN PresetForNewData.AllAllowed = TRUE
	|				AND PresetForNewData.WithSetting = FALSE
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS WithoutSetup
	|INTO NewData
	|FROM
	|	PresetForNewData AS PresetForNewData
	|
	|INDEX BY
	|	PresetForNewData.AccessGroup,
	|	PresetForNewData.AccessValuesType,
	|	PresetForNewData.AllAllowed,
	|	WithoutSetup
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP AccessKindSettings";
	
	QueryText =
	"SELECT
	|	NewData.AccessGroup,
	|	NewData.AccessValuesType,
	|	NewData.AllAllowed,
	|	NewData.WithoutSetup,
	|	&InsertFieldsRowChangeKind
	|FROM
	|	NewData AS NewData";
	
	// Prepare the selected fields with an optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("AccessGroup", "&AccessGroupFilterCondition2"));
	Fields.Add(New Structure("AccessValuesType"));
	Fields.Add(New Structure("AllAllowed"));
	Fields.Add(New Structure("WithoutSetup"));
	
	Query.Text = AccessManagementService.TextOfQuerySelectionChanges(
		QueryText, Fields, "InformationRegister.AccessGroupsDefaultValues", TemporaryTablesQueryText);
	
	AccessManagementService.SetCriteriaForQuery(Query, AccessGroups, "AccessGroups",
		"&AccessGroupFilterCondition1:AccessGroups.Ref 
   |&AccessGroupFilterCondition2:OldData.AccessGroup");
	
	Data = New Structure;
	Data.Insert("ManagerRegister",      InformationRegisters.AccessGroupsDefaultValues);
	Data.Insert("ChangeRowsContent", Query.Execute().Unload());
	Data.Insert("DimensionsOfSelection",       "AccessGroup");
	
	AccessManagementService.RefreshInformationRegister(Data, HasChanges);
	
EndProcedure

#EndRegion

#EndIf