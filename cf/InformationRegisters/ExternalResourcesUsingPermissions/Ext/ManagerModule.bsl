#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Generates permission key (for use in registers that store
// information about provided permissions).
//
// Parameters:
//  Resolution - ObjectXDTO.
//
// Return value: String.
//
Function AuthorizationKey(Val Resolution) Export
	
	Hashing = New DataHashing(HashFunction.MD5);
	Hashing.Append(CommonUse.ObjectXDTOInXMLString(Resolution));
	
	Supplement = AuthorizationAdding(Resolution);
	If ValueIsFilled(Supplement) Then
		Hashing.Append(CommonUse.ValueToXMLString(Supplement));
	EndIf;
	
	Key = XDTOFactory.Create(XDTOFactory.Type("http://www.w3.org/2001/XMLSchema", "hexBinary"), Hashing.HashSum).LexicalMeaning;
	
	If StrLen(Key) > 32 Then
		Raise NStr("en='Key length exceeds the allowed one';ru='Превышение длины ключа'");
	EndIf;
	
	Return Key;
	
EndFunction

// Generates extension of an addition.
//
// Parameters:
//  Resolution - ObjectXDTO.
//
// Returns - Arbitrary (serialized in XDTO).
//
Function AuthorizationAdding(Val Resolution) Export
	
	If Resolution.Type() = XDTOFactory.Type(WorkInSafeModeService.Package(), "AttachAddin") Then
		Return WorkInSafeModeService.ExternalComponentsKitFilesControlSums(Resolution.TemplateName);
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Returns the current cut of granted permissions.
//
// Parameters:
//  InContextOfOwners - Boolean - if True - in the return table there
//    will be the information about the permission owners, otherwise the
//  current cut will be collapsed by owners, WithoutDescriptions - Boolean - if True - cut will be returned with cleared field Description of permissions.
//
// Returns - ValueTable, columns:
// * SoftwareModuleType - CatalogRef.MetadataObjectsIdentifiers,
// * SoftwareModuleIdentifier - UUID,
// * OwnerType - CatalogRef.MetaDataObjectsIdentifiers,
// * OwnerIdentifier - UUID,
// * Type - String - XDTO type name
// that describes permissions, * Permissions - Map - Permissions description:
//   * Key - String - permission key (see the PermissionKey function in the register manager module.
//      ExternalResourcesUsePermissions),
//   *Value - XDTODataObject - XDTO-description
// of the permission, * PermissionsSupplements - Map - Description of permission additions:
//   * Key - String - permission key (see the PermissionKey function in the register manager module.
//      ExternalResourcesUsePermissions),
//   *Value - Structure - see PermissionAddition function in the register manager module.
//      ExternalResourcesUsePermissions).
//
Function PermissionsCut(Val InContextOfOwners = True, Val WithoutDescriptions = False) Export
	
	Result = New ValueTable();
	
	Result.Columns.Add("SoftwareModuleType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	Result.Columns.Add("SoftwareModuleID", New TypeDescription("UUID"));
	If InContextOfOwners Then
		Result.Columns.Add("OwnerType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
		Result.Columns.Add("IDOwner", New TypeDescription("UUID"));
	EndIf;
	Result.Columns.Add("Type", New TypeDescription("String"));
	Result.Columns.Add("permissions", New TypeDescription("Map"));
	Result.Columns.Add("PermissionsAdditions", New TypeDescription("Map"));
	
	Selection = Select();
	
	While Selection.Next() Do
		
		Resolution = CommonUse.ObjectXDTOFromXMLRow(Selection.AuthorizationBody);
		
		FilterByTable = New Structure();
		FilterByTable.Insert("SoftwareModuleType", Selection.SoftwareModuleType);
		FilterByTable.Insert("SoftwareModuleID", Selection.SoftwareModuleID);
		If InContextOfOwners Then
			FilterByTable.Insert("OwnerType", Selection.OwnerType);
			FilterByTable.Insert("IDOwner", Selection.IDOwner);
		EndIf;
		FilterByTable.Insert("Type", Resolution.Type().Name);
		
		String = DataProcessors.PermissionSettingsForExternalResourcesUse.PermissionsTableRow(
			Result, FilterByTable);
		
		AuthorizationBody = Selection.AuthorizationBody;
		AuthorizationKey = Selection.AuthorizationKey;
		AuthorizationAdding = Selection.AuthorizationAdding;
		
		If WithoutDescriptions Then
			
			If ValueIsFilled(Resolution.Description) Then
				
				Resolution.Description = "";
				AuthorizationBody = CommonUse.ObjectXDTOInXMLString(Resolution);
				AuthorizationKey = AuthorizationKey(Resolution);
				
			EndIf;
			
		EndIf;
		
		String.permissions.Insert(AuthorizationKey, AuthorizationBody);
		
		If ValueIsFilled(AuthorizationAdding) Then
			String.PermissionsAdditions.Insert(AuthorizationKey, AuthorizationAdding);
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Writes a permission to the register.
//
// Parameters:
//  SoftwareModuleType - CatalogRef.MetadataObjectIDs,
//  SoftwareModuleIdentifier - UUID,
//  OwnerType - CatalogRef.MetadataObjectIDs,
//  OwnerID - UUID,
//  PermissionKey - String - permission
//  key, Permission - XDTODataObject - XDTO-granting
//  permission, PermissionSupplement - Arbitrary (serialized in XDTO).
//
Procedure AddPermission(Val SoftwareModuleType, Val SoftwareModuleID, Val OwnerType, Val IDOwner, Val AuthorizationKey, Val Resolution, Val AuthorizationAdding = Undefined) Export
	
	Manager = CreateRecordManager();
	Manager.SoftwareModuleType = SoftwareModuleType;
	Manager.SoftwareModuleID = SoftwareModuleID;
	Manager.OwnerType = OwnerType;
	Manager.IDOwner = IDOwner;
	Manager.AuthorizationKey = AuthorizationKey;
	
	Manager.Read();
	
	If Manager.Selected() Then
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Duplication of permissions
		|by key
		|fields: -SowtwareModuleType: %1
		|-SowtwareModuleIdentifier: 2%
		|- OwnerType: %3
		|-OwnerIdentifier: %4 - PermissionKey: %5.';ru='Дублирование
		|разрешений
		|по ключевым полям:
		|- ТипПрограммногоМодуля:
		|%1 - ИдентификаторПрограммногоМодуля:
		|%2 - ТипВладельца: %3 - ИдентификаторВладельца: %4 - КлючРазрешения: %5.'"),
			String(SoftwareModuleType),
			String(SoftwareModuleID),
			String(OwnerType),
			String(IDOwner),
			AuthorizationKey);
		
	Else
		
		Manager.SoftwareModuleType = SoftwareModuleType;
		Manager.SoftwareModuleID = SoftwareModuleID;
		Manager.OwnerType = OwnerType;
		Manager.IDOwner = IDOwner;
		Manager.AuthorizationKey = AuthorizationKey;
		Manager.AuthorizationBody = CommonUse.ObjectXDTOInXMLString(Resolution);
		
		If ValueIsFilled(AuthorizationAdding) Then
			Manager.AuthorizationAdding = CommonUse.ValueToXMLString(AuthorizationAdding);
		EndIf;
		
		Manager.Write(False);
		
	EndIf;
	
EndProcedure

// Removes a permission from the register.
//
// Parameters:
//  SoftwareModuleType - CatalogRef.MetadataObjectIDs,
//  SoftwareModuleIdentifier - UUID,
//  OwnerType - CatalogRef.MetadataObjectIDs,
//  OwnerID - UUID,
//  PermissionKey - String - permission
//  key, Permission - XDTODataObject - XDTO- granting permission.
//
Procedure DeletePermission(Val SoftwareModuleType, Val SoftwareModuleID, Val OwnerType, Val IDOwner, Val AuthorizationKey, Val Resolution) Export
	
	Manager = CreateRecordManager();
	Manager.SoftwareModuleType = SoftwareModuleType;
	Manager.SoftwareModuleID = SoftwareModuleID;
	Manager.OwnerType = OwnerType;
	Manager.IDOwner = IDOwner;
	Manager.AuthorizationKey = AuthorizationKey;
	
	Manager.Read();
	
	If Manager.Selected() Then
		
		If Manager.AuthorizationBody <> CommonUse.ObjectXDTOInXMLString(Resolution) Then
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Permissions
		|position by
		|keys: - ProgramModuleType:
		|%1 - ProgramModuleID:
		|%2 - OwnerType:
		|%3 - OwnerID: %4 - PermissionKey: %5.';ru='Позиция
		|разрешений
		|по ключам:
		|- ТипПрограммногоМодуля: %1
		|- ИдентификаторПрограммногоМодуля:
		|%2 - ТипВладельца: %3 - ИдентификаторВладельца: %4 - КлючРазрешения: %5.'"),
				String(SoftwareModuleType),
				String(SoftwareModuleID),
				String(OwnerType),
				String(IDOwner),
				AuthorizationKey);
				
		EndIf;
		
		Manager.Delete();
		
	Else
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Attempt to delete
		|a nonexistent permission:
		|-SowtwareModuleType: %1
		|-SowtwareModuleIdentifier: 2%
		|- OwnerType: %3
		|-OwnerIdentifier: %4 - PermissionKey: %5.';ru='Попытка
		|удаления несуществующего
		|разрешения: -
		|ТипПрограммногоМодуля: %1
		|- ИдентификаторПрограммногоМодуля: %2
		|- ТипВладельца: %3 - ИдентификаторВладельца: %4 - КлючРазрешения: %5.'"),
			String(SoftwareModuleType),
			String(SoftwareModuleID),
			String(OwnerType),
			String(IDOwner),
			AuthorizationKey);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf

