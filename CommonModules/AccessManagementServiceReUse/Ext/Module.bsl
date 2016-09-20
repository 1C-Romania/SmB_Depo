
// Subsystem "Access management".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Includes saved parameters, used by the subsystem.
Function Parameters() Export
	
	SetPrivilegedMode(True);
	SavedParameters = StandardSubsystemsServer.ApplicationWorkParameters(
		"AccessLimitationParameters");
	SetPrivilegedMode(False);
	
	StandardSubsystemsServer.CheckForUpdatesApplicationWorkParameters(
		"AccessLimitationParameters",
		"PossibleRightsForObjectRightsSettings,
		|ProvidedAccessGroupsProfiles,
		|AccessGroupsPredefinedProfiles,
		|AccessKindsProperties");
	
	ParameterPresentation = "";
	
	If Not SavedParameters.Property("PossibleRightsForObjectRightsSettings") Then
		ParameterPresentation = NStr("en='Possible rights for object rights settings';ru='Возможные права для настройки прав объектов'");
		
	ElsIf Not SavedParameters.Property("ProvidedAccessGroupsProfiles") Then
		ParameterPresentation = NStr("en='Supplied access group profiles';ru='Поставляемые профили групп доступа'");
		
	ElsIf Not SavedParameters.Property("AccessGroupsPredefinedProfiles") Then
		ParameterPresentation = NStr("en='Predefined access group profiles';ru='Предопределенные профили групп доступа'");
		
	ElsIf Not SavedParameters.Property("AccessKindsProperties") Then
		ParameterPresentation = NStr("en='Properties of access kinds';ru='Свойства видов доступа'");
	EndIf;
	
	If ValueIsFilled(ParameterPresentation) Then
		
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Information base updating error.
		|Access limitation parameter is
		|not filled in: ""%1"".';ru='Ошибка обновления информационной базы.
		|Не заполнен параметр
		|ограничения доступа: ""%1"".'")
			+ StandardSubsystemsServer.SpecificationOfErrorParametersWorkApplicationForDeveloper(),
			ParameterPresentation);
	EndIf;
	
	Return SavedParameters;
	
EndFunction

// Returns values table containing access limitation kind
// by each metadata object rule.
//  If there is no record by right, there are no restrictions by right.
//  Table contains only access kinds specified
// by the developer based on their use in limitation texts.
//  To get all access kinds including those used
// in the access value sets,
// you can use the current state of the AcessValueSets information register.
//
// Returns:
//  ValueTable:
//    Table        - String - metadata object table name, for example, Catalog.Files.
//    Right          - String: "Reading" "Change".
//    AccessKind     - Ref - main type empty ref of the
//                              access kind values, empty ref of right settings owner.
//                   - Undefined - for the Object access kind.
//    ObjectTable - Ref - metadata object empty ref through which
//                     access is limited using access value sets, for example, Catalog.FileFolders.
//                   - Undefined if AccessKind <> Undefined.
//
Function ConstantRightsRestrictionKindsOfMetadataObjects() Export
	
	SetPrivilegedMode(True);
	
	RightsAccessKinds = New ValueTable;
	RightsAccessKinds.Columns.Add("Table",        New TypeDescription("CatalogRef.MetadataObjectIDs"));
	RightsAccessKinds.Columns.Add("Right",          New TypeDescription("String", , New StringQualifiers(20)));
	RightsAccessKinds.Columns.Add("AccessKind",     AccessValueTypesAndRightSettingOwnersDescription());
	RightsAccessKinds.Columns.Add("ObjectTable", Metadata.InformationRegisters.AccessValuesSets.Dimensions.Object.Type);
	
	LimitationsOfRights = "";
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.AccessManagement\OnFillingKindsOfRestrictionsRightsOfMetadataObjects");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnFillingKindsOfRestrictionsRightsOfMetadataObjects(LimitationsOfRights);
	EndDo;
	
	AccessManagementOverridable.OnFillingKindsOfRestrictionsRightsOfMetadataObjects(LimitationsOfRights);
	
	AccessKindsByNames = AccessManagementServiceReUse.Parameters().AccessKindsProperties.ByNames;
	
	For LineNumber = 1 To StrLineCount(LimitationsOfRights) Do
		CurrentRow = StrGetLine(LimitationsOfRights, LineNumber);
		If ValueIsFilled(CurrentRow) Then
			ErrorExplanation = "";
			If StrOccurrenceCount(CurrentRow, ".") <> 3 AND StrOccurrenceCount(CurrentRow, ".") <> 5 Then
				ErrorExplanation = NStr("en='String should be in the ""<Table full name> format.<Right name>.<Access kind name>[.Object table]"".';ru='Строка должна быть в формате ""<Полное имя таблицы>.<Имя права>.<Имя вида доступа>[.Таблица объекта]"".'");
			Else
				PositionOfRight = Find(CurrentRow, ".");
				PositionOfRight = Find(Mid(CurrentRow, PositionOfRight + 1), ".") + PositionOfRight;
				Table = Left(CurrentRow, PositionOfRight - 1);
				PositionOfAccessKind = Find(Mid(CurrentRow, PositionOfRight + 1), ".") + PositionOfRight;
				Right = Mid(CurrentRow, PositionOfRight + 1, PositionOfAccessKind - PositionOfRight - 1);
				If StrOccurrenceCount(CurrentRow, ".") = 3 Then
					AccessKind = Mid(CurrentRow, PositionOfAccessKind + 1);
					ObjectTable = "";
				Else
					PositionOfObjectTable = Find(Mid(CurrentRow, PositionOfAccessKind + 1), ".") + PositionOfAccessKind;
					AccessKind = Mid(CurrentRow, PositionOfAccessKind + 1, PositionOfObjectTable - PositionOfAccessKind - 1);
					ObjectTable = Mid(CurrentRow, PositionOfObjectTable + 1);
				EndIf;
				
				If Metadata.FindByFullName(Table) = Undefined Then
					ErrorExplanation = StringFunctionsClientServer.PlaceParametersIntoString(
						NStr("en='Not found table ""%1"".';ru='Не найдена таблица ""%1"".'"),
						Table);
				
				ElsIf Right <> "Read" AND Right <> "Update" Then
					ErrorExplanation = StringFunctionsClientServer.PlaceParametersIntoString(
						NStr("en='Not found right ""%1"".';ru='Не найдено право ""%1"".'"),
						Right);
				
				ElsIf Upper(AccessKind) = Upper("Object") Then
					If Metadata.FindByFullName(ObjectTable) = Undefined Then
						ErrorExplanation = StringFunctionsClientServer.PlaceParametersIntoString(
							NStr("en='Not found object table ""%1"".';ru='Не найдена таблица объекта ""%1"".'"),
							ObjectTable);
					Else
						AccessKindRef = Undefined;
						ObjectTableRef = AccessManagementService.MetadataObjectEmptyRef(
							ObjectTable);
					EndIf;
					
				ElsIf Upper(AccessKind) = Upper("RightSettings") Then
					If Metadata.FindByFullName(ObjectTable) = Undefined Then
						ErrorExplanation = StringFunctionsClientServer.PlaceParametersIntoString(
							NStr("en='Rights settings owner table is not found ""%1"".';ru='Не найдена таблица владельца настроек прав ""%1"".'"),
							ObjectTable);
					Else
						AccessKindRef = AccessManagementService.MetadataObjectEmptyRef(
							ObjectTable);
						ObjectTableRef = Undefined;
					EndIf;
				
				ElsIf AccessKindsByNames.Get(AccessKind) = Undefined Then
					ErrorExplanation = StringFunctionsClientServer.PlaceParametersIntoString(
						NStr("en='Not found access kind ""%1"".';ru='Не найден вид доступа ""%1"".'"),
						AccessKind);
				Else
					AccessKindRef = AccessKindsByNames.Get(AccessKind).Ref;
					ObjectTableRef = Undefined;
				EndIf;
			EndIf;
			
			If ValueIsFilled(ErrorExplanation) Then
				Raise(StringFunctionsClientServer.PlaceParametersIntoString(
						NStr("en='An error occurred in kind description string of
		|the metadata object right restriction: ""%1"".
		|
		|';ru='Ошибка в строке описания вида ограничений
		|права объекта метаданных: ""%1"".
		|
		|'"), CurrentRow) + ErrorExplanation);
			Else
				AccessTypeProperties = AccessKindsByNames.Get(AccessKind);
				NewDetails = RightsAccessKinds.Add();
				NewDetails.Table        = CommonUse.MetadataObjectID(Table);
				NewDetails.Right          = Right;
				NewDetails.AccessKind     = AccessKindRef;
				NewDetails.ObjectTable = ObjectTableRef;
			EndIf;
		EndIf;
	EndDo;
	
	// Add objects access kinds that are determined not only through access value sets.
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccessRightsCorrelation.SubordinateTable,
	|	AccessRightsCorrelation.MasterTableType
	|FROM
	|	InformationRegister.AccessRightsCorrelation AS AccessRightsCorrelation";
	DependenciesRight = Query.Execute().Unload();
	
	StopTrying = False;
	While Not StopTrying Do
		StopTrying = True;
		Filter = New Structure("AccessKind", Undefined);
		AccessKindsObject = RightsAccessKinds.FindRows(Filter);
		For Each String IN AccessKindsObject Do
			TableID = CommonUse.MetadataObjectID(
				TypeOf(String.ObjectTable));
			
			Filter = New Structure;
			Filter.Insert("SubordinateTable", String.Table);
			Filter.Insert("MasterTableType", String.ObjectTable);
			If DependenciesRight.FindRows(Filter).Count() = 0 Then
				MasterRight = String.Right;
			Else
				MasterRight = "Read";
			EndIf;
			Filter = New Structure("Table, Right", TableID, MasterRight);
			LeadingTableAccessKinds = RightsAccessKinds.FindRows(Filter);
			For Each AccessTypeDescription IN LeadingTableAccessKinds Do
				If AccessTypeDescription.AccessKind = Undefined Then
					// Access kind object can not be added.
					Continue;
				EndIf;
				Filter = New Structure;
				Filter.Insert("Table",    String.Table);
				Filter.Insert("Right",      String.Right);
				Filter.Insert("AccessKind", AccessTypeDescription.AccessKind);
				If RightsAccessKinds.FindRows(Filter).Count() = 0 Then
					FillPropertyValues(RightsAccessKinds.Add(), Filter);
					StopTrying = False;
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	Return RightsAccessKinds;
	
EndFunction

// Only for internal use.
Function RecordKeyDescription(TypeOrFullName) Export
	
	KeyDescription = New Structure("FieldsArray, FieldsRow", New Array, "");
	
	If TypeOf(TypeOrFullName) = Type("Type") Then
		MetadataObject = Metadata.FindByType(TypeOrFullName);
	Else
		MetadataObject = Metadata.FindByFullName(TypeOrFullName);
	EndIf;
	Manager = CommonUse.ObjectManagerByFullName(MetadataObject.FullName());
	
	For Each Column IN Manager.CreateRecordSet().Unload().Columns Do
		
		If MetadataObject.Resources.Find(Column.Name) = Undefined
		   AND MetadataObject.Attributes.Find(Column.Name) = Undefined Then
			// If there is no field in resourses and attributes, it means that this field - dimension.
			KeyDescription.FieldsArray.Add(Column.Name);
			KeyDescription.FieldsRow = KeyDescription.FieldsRow + Column.Name + ",";
		EndIf;
	EndDo;
	
	KeyDescription.FieldsRow = Left(KeyDescription.FieldsRow, StrLen(KeyDescription.FieldsRow)-1);
	
	Return CommonUse.FixedData(KeyDescription);
	
EndFunction

// Only for internal use.
Function TypesTableFields(FullFieldName) Export
	
	MetadataObject = Metadata.FindByFullName(FullFieldName);
	
	TypeArray = MetadataObject.Type.Types();
	
	FieldTypes = New Map;
	For Each Type IN TypeArray Do
		FieldTypes.Insert(Type, True);
	EndDo;
	
	Return FieldTypes;
	
EndFunction

// Returns types of objects and references in the specified subscriptions to events.
// 
// Parameters:
//  NamesSubscriptions - String - multiline
//                  string containing subscription name start strings.
//
Function TypesOfObjectsInSubscriptionsToEvents(NamesSubscriptions, EmptyRefsArray = False) Export
	
	ObjectsTypes = New Map;
	
	For Each Subscription IN Metadata.EventSubscriptions Do
		
		For LineNumber = 1 To StrLineCount(NamesSubscriptions) Do
			
			BeginName = StrGetLine(NamesSubscriptions, LineNumber);
			SubscriptionName = Subscription.Name;
			
			If Upper(Left(SubscriptionName, StrLen(BeginName))) = Upper(BeginName) Then
				
				For Each Type IN Subscription.Source.Types() Do
					ObjectsTypes.Insert(Type, True);
				EndDo;
			EndIf;
			
		EndDo;
		
	EndDo;
	
	If Not EmptyRefsArray Then
		Return New FixedMap(ObjectsTypes);
	EndIf;
	
	Array = New Array;
	For Each KeyAndValue IN ObjectsTypes Do
		Array.Add(AccessManagementService.MetadataObjectEmptyRef(
			KeyAndValue.Key));
	EndDo;
	
	Return New FixedArray(Array);
	
EndFunction

// Only for internal use.
Function EmptyRecordSetTable(FullNameOfRegister) Export
	
	Manager = CommonUse.ObjectManagerByFullName(FullNameOfRegister);
	
	Return Manager.CreateRecordSet().Unload();
	
EndFunction

// Only for internal use.
Function SpecifiedTypesEmptyRefsTable(AttributeFullName) Export
	
	TypeDescription = Metadata.FindByFullName(AttributeFullName).Type;
	
	EmptyRefs = New ValueTable;
	EmptyRefs.Columns.Add("EmptyRef", TypeDescription);
	
	For Each ValueType IN TypeDescription.Types() Do
		If CommonUse.IsReference(ValueType) Then
			EmptyRefs.Add().EmptyRef = CommonUse.ObjectManagerByFullName(
				Metadata.FindByType(ValueType).FullName()).EmptyRef();
		EndIf;
	EndDo;
	
	Return EmptyRefs;
	
EndFunction

// Only for internal use.
Function MatchEmptyRefsToSpecifiedRefsTypes(AttributeFullName) Export
	
	TypeDescription = Metadata.FindByFullName(AttributeFullName).Type;
	
	EmptyRefs = New Map;
	
	For Each ValueType IN TypeDescription.Types() Do
		If CommonUse.IsReference(ValueType) Then
			EmptyRefs.Insert(ValueType, CommonUse.ObjectManagerByFullName(
				Metadata.FindByType(ValueType).FullName()).EmptyRef() );
		EndIf;
	EndDo;
	
	Return New FixedMap(EmptyRefs);
	
EndFunction

// Only for internal use.
Function RefTypeCodes(AttributeFullName) Export
	
	TypeDescription = Metadata.FindByFullName(AttributeFullName).Type;
	
	TypesNumericCodes = New Map;
	CurrentCode = 0;
	
	For Each ValueType IN TypeDescription.Types() Do
		If CommonUse.IsReference(ValueType) Then
			TypesNumericCodes.Insert(ValueType, CurrentCode);
		EndIf;
		CurrentCode = CurrentCode + 1;
	EndDo;
	
	RowNumericCodes = New Map;
	
	RowCodeLength = StrLen(Format(CurrentCode-1, "NZ=0; NG="));
	FormatCodeString = "ND=" + Format(RowCodeLength, "NZ=0; NG=") + "; NZ=0; NLZ=; NG=";
	
	For Each KeyAndValue IN TypesNumericCodes Do
		RowNumericCodes.Insert(
			KeyAndValue.Key,
			Format(KeyAndValue.Value, FormatCodeString));
	EndDo;
	
	Return RowNumericCodes;
	
EndFunction

// Only for internal use.
Function EnumCodes() Export
	
	EnumCodes = New Map;
	
	For Each AccessValueType IN Metadata.DefinedTypes.AccessValue.Type.Types() Do
		TypeMetadata = Metadata.FindByType(AccessValueType);
		If TypeMetadata = Undefined OR Not Metadata.Enums.Contains(TypeMetadata) Then
			Continue;
		EndIf;
		For Each EnumValue IN TypeMetadata.EnumValues Do
			EnumValueName = EnumValue.Name;
			EnumCodes.Insert(Enums[TypeMetadata.Name][EnumValueName], EnumValueName);
		EndDo;
	EndDo;
	
	Return New FixedMap(EnumCodes);;
	
EndFunction

// Only for internal use.
Function AccessKindsValueTypes() Export
	
	AccessKindsProperties = AccessManagementServiceReUse.Parameters().AccessKindsProperties;
	
	AccessKindsValueTypes = New ValueTable;
	AccessKindsValueTypes.Columns.Add("AccessKind",  Metadata.DefinedTypes.AccessValue.Type);
	AccessKindsValueTypes.Columns.Add("ValuesType", Metadata.DefinedTypes.AccessValue.Type);
	
	For Each KeyAndValue IN AccessKindsProperties.ByValuesTypes Do
		String = AccessKindsValueTypes.Add();
		String.AccessKind = KeyAndValue.Value.Ref;
		
		Types = New Array;
		Types.Add(KeyAndValue.Key);
		DescriptionOfType = New TypeDescription(Types);
		
		String.ValuesType = DescriptionOfType.AdjustValue(Undefined);
	EndDo;
	
	Return AccessKindsValueTypes;
	
EndFunction

// Only for internal use.
Function GroupsAndAccessKindValuesTypes() Export
	
	AccessKindsProperties = AccessManagementServiceReUse.Parameters().AccessKindsProperties;
	
	GroupsAndAccessKindValuesTypes = New ValueTable;
	GroupsAndAccessKindValuesTypes.Columns.Add("AccessKind",        Metadata.DefinedTypes.AccessValue.Type);
	GroupsAndAccessKindValuesTypes.Columns.Add("GroupsAndValuesTypes", Metadata.DefinedTypes.AccessValue.Type);
	
	For Each KeyAndValue IN AccessKindsProperties.ByGroupsAndValuesTypes Do
		String = GroupsAndAccessKindValuesTypes.Add();
		String.AccessKind = KeyAndValue.Value.Ref;
		
		Types = New Array;
		Types.Add(KeyAndValue.Key);
		DescriptionOfType = New TypeDescription(Types);
		
		String.GroupsAndValuesTypes = DescriptionOfType.AdjustValue(Undefined);
	EndDo;
	
	Return GroupsAndAccessKindValuesTypes;
	
EndFunction

// Only for internal use.
Function AccessValueTypesAndRightSettingOwnersDescription() Export
	
	Types = New Array;
	For Each Type IN Metadata.DefinedTypes.AccessValue.Type.Types() Do
		Types.Add(Type);
	EndDo;
	
	For Each Type IN Metadata.DefinedTypes.RightSettingsOwner.Type.Types() Do
		Types.Add(Type);
	EndDo;
	
	Return New TypeDescription(Types);
	
EndFunction

// Only for internal use.
Function AccessKindsValueAndRightSettingOwnersTypes() Export
	
	AccessKindsValueAndRightSettingOwnersTypes = New ValueTable;
	
	AccessKindsValueAndRightSettingOwnersTypes.Columns.Add("AccessKind",
		AccessManagementServiceReUse.AccessValueTypesAndRightSettingOwnersDescription());
	
	AccessKindsValueAndRightSettingOwnersTypes.Columns.Add("ValuesType",
		AccessManagementServiceReUse.AccessValueTypesAndRightSettingOwnersDescription());
	
	AccessKindsValueTypes = AccessManagementServiceReUse.AccessKindsValueTypes();
	
	For Each String IN AccessKindsValueTypes Do
		FillPropertyValues(AccessKindsValueAndRightSettingOwnersTypes.Add(), String);
	EndDo;
	
	RightOwners = AccessManagementServiceReUse.Parameters(
		).PossibleRightsForObjectRightsSettings.ByRefsTypes;
	
	For Each KeyAndValue IN RightOwners Do
		
		Types = New Array;
		Types.Add(KeyAndValue.Key);
		DescriptionOfType = New TypeDescription(Types);
		
		String = AccessKindsValueAndRightSettingOwnersTypes.Add();
		String.AccessKind  = DescriptionOfType.AdjustValue(Undefined);
		String.ValuesType = DescriptionOfType.AdjustValue(Undefined);
	EndDo;
	
	Return AccessKindsValueAndRightSettingOwnersTypes;
	
EndFunction

// Only for internal use.
Function MetadataObjectsRightsRestrictionKinds() Export
	
	Return New Structure("UpdateDate, Table", '00010101');
	
EndFunction

// Only for internal use.
Function ProfileRolesDescription() Export
	
	ProfileDescriptions = AccessManagementServiceReUse.Parameters(
		).ProvidedAccessGroupsProfiles.ProfilesDescriptionArray;
	
	ProfileRoles = New Map;
	IDs = New Array;
	AllRoles = UsersService.AllRoles().Map;
	
	For Each ProfileDescription IN ProfileDescriptions Do
		
		If Not ValueIsFilled(ProfileDescription.Name)
		 Or ProfileDescription.Name = "Administrator" Then
			
			Continue;
		EndIf;
		
		ProfileRoleName = "Profile" + ProfileDescription.Name;
		If AllRoles.Get(ProfileRoleName) = Undefined Then
			Continue;
		EndIf;
		
		ID = New UUID(ProfileDescription.ID);
		IDs.Add(ID);
		ProfileRoles.Insert(ID, ProfileRoleName);
	EndDo;
	
	Query = New Query;
	Query.SetParameter("IDs", IDs);
	Query.Text =
	"SELECT
	|	Profiles.Ref AS Ref,
	|	Profiles.IDSuppliedData AS ID
	|FROM
	|	Catalog.AccessGroupsProfiles AS Profiles
	|WHERE
	|	Profiles.IDSuppliedData IN(&IDs)";
	
	Selection = Query.Execute().Select();
	ProfileRolesDescription = New Array;
	
	While Selection.Next() Do
		ProfileRole = ProfileRoles[Selection.ID];
		ProfileRoleDescription = New Structure;
		ProfileRoleDescription.Insert("Profile", Selection.Ref);
		ProfileRoleDescription.Insert("Role",    ProfileRole);
		ProfileRolesDescription.Add(New FixedStructure(ProfileRoleDescription));
	EndDo;
	
	Return New FixedArray(ProfileRolesDescription);
	
EndFunction

// Only for internal use.
Function RolesOccurrencesInProfileRoles() Export
	
	ProfileDescriptions = AccessManagementServiceReUse.Parameters(
		).ProvidedAccessGroupsProfiles.ProfilesDescriptionArray;
	
	RolesOccurrencesInProfileRoles = New Map;
	AllRoles = UsersService.AllRoles().Map;
	
	For Each ProfileDescription IN ProfileDescriptions Do
		
		If Not ValueIsFilled(ProfileDescription.Name)
		 Or ProfileDescription.Name = "Administrator" Then
			
			Continue;
		EndIf;
		
		ProfileRoleName = "Profile" + ProfileDescription.Name;
		If AllRoles.Get(ProfileRoleName) = Undefined Then
			Continue;
		EndIf;
		
		For Each Role IN ProfileDescription.Roles Do
			ProfileRoles = RolesOccurrencesInProfileRoles.Get(Role);
			If ProfileRoles = Undefined Then
				ProfileRoles = New Array;
				RolesOccurrencesInProfileRoles.Insert(Role, ProfileRoles);
			EndIf;
			ProfileRoles.Add(ProfileRoleName);
		EndDo;
	EndDo;
	
	For Each KeyAndValue IN RolesOccurrencesInProfileRoles Do
		RolesOccurrencesInProfileRoles[KeyAndValue.Key] = New FixedArray(KeyAndValue.Value);
	EndDo;
	
	Return New FixedMap(RolesOccurrencesInProfileRoles);
	
EndFunction

#EndRegion
