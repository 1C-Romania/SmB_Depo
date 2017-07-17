////////////////////////////////////////////////////////////////////////////////
// Subsystem "Basic functionality in service model".
// Server procedures and functions of common use:
// - Support security profiles
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceApplicationInterface

// Returns the execution mode of external module in service model.
//
// Parameters:
//  ExternalModule - AnyRef,
//
// Returns - String - external module execution mode.
//
Function ExternalModuleExecutionMode(Val ExternalModule) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		Key = RegisterKeyByLink(ExternalModule);
		
		If CommonUseReUse.CanUseSeparatedData() Then
			
			Mode = InformationRegisters.ExternalModulesConnectionModesDataAreas.ExternalModuleExecutionMode(
				Key.Type, Key.ID);
			
			If Mode = Undefined Then
				
				Mode = InformationRegisters.ExternalModulesConnectionModesSaaS.ExternalModuleExecutionMode(
					Key.Type, Key.ID);
				
				Return Mode;
				
			Else
				
				Return Mode;
				
			EndIf;
			
		Else
			
			Mode = InformationRegisters.ExternalModulesConnectionModesSaaS.ExternalModuleExecutionMode(
				Key.Type, Key.ID);
			
			Return Mode;
			
		EndIf;
		
	Else
		Raise NStr("en='The function cannot be called in the Infobase with disabled separation by data areas.';ru='Функция не предназначена для вызова в информационной базе, в которой выключено разделение по областям данных!'");
	EndIf;
	
EndFunction

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnDefenitionSupportedVersionsOfSoftwareInterfaces"].Add(
		"WorkInSafeModeServiceSaaS");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\WhenCheckingPossibilityToSetupSecurityProfiles"].Add(
		"WorkInSafeModeServiceSaaS");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\WhenPermissionsForExternalResourcesUseAreRequested"].Add(
		"WorkInSafeModeServiceSaaS");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\WhenSecurityProfileCreationIsRequested"].Add(
		"WorkInSafeModeServiceSaaS");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\WhenSecurityProfileDeletionIsRequested"].Add(
		"WorkInSafeModeServiceSaaS");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\WhenConnectingExternalModule"].Add(
		"WorkInSafeModeServiceSaaS");
	
	ServerHandlers["StandardSubsystems.SaaS\WhenCompletingTablesOfParametersOfIB"].Add(
		"WorkInSafeModeServiceSaaS");
	
	ServerHandlers["StandardSubsystems.SaaS.MessageExchange\RegistrationOfReceivedMessageInterfaces"].Add(
		"WorkInSafeModeServiceSaaS");
	
	If CommonUse.SubsystemExists("ServiceTechnology.DataExportImport") Then
		ServerHandlers["ServiceTechnology.DataExportImport\WhenFillingTypesExcludedFromExportImport"].Add(
			"WorkInSafeModeServiceSaaS");
	EndIf;
	
	// CLIENT EVENTS
	
	ClientHandlers["StandardSubsystems.BasicFunctionality\WhenRequestsForExternalResourcesUseAreConfirmed"].Add(
		"PermissionForExternalResourcesUseSettingsSaaSClient");
	
EndProcedure

// Fills the structure with the arrays of supported
// versions of all subsystems subject to versioning and uses subsystems names as keys.
// Provides the functionality of InterfaceVersion Web-service.
// during the implementation the body of the procedure shall be changed so it will return relevant version sets (see ex.below).
//
// Parameters:
// SupportedVersionStructure - Structure: 
// - Keys = Names of the subsystems. 
// - Values = Arrays of supported version names.
//
// Example of implementation:
//
// // FileTransferServer
// VersionsArray = New Array;
// VersionsArray.Add("1.0.1.1");	
// VersionsArray.Add("1.0.2.1"); 
// SupportedVersionsStructure.Insert("FileTransferServer", VersionsArray);
// // End FileTransferService
//
Procedure OnDefenitionSupportedVersionsOfSoftwareInterfaces(Val SupportedVersionStructure) Export
	
	If WorkInSafeModeService.SecurityProfilesCanBeUsed() Then
		VersionArray = New Array;
		VersionArray.Add("1.0.0.2");
		SupportedVersionStructure.Insert("SecurityProfileCompatibilityMode", VersionArray);
	EndIf;
	
EndProcedure

// Appears when the possibilty of security profile setup is checked
//
// Parameters:
//  Cancel - Boolean. If the use of security profiles is not available for infobase -
//    value of this parameter shall be set to True.
//
Procedure WhenCheckingPossibilityToSetupSecurityProfiles(Cancel) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		// IN service model the configuration of security profiles
		// is managed centrally from the service manager.
		Cancel = True;
		
	EndIf;
	
EndProcedure

// Appears when a request for permissions to use external resources is created.
//
// Parameters:
//  ApplicationModule - AnyRef - ref to infobase object
//    representing the software module for which
//  permissions are requested, Owner - AnyRef - ref to infobase object that
//    represents the object-owner of requested
//  permissions for external resources use, ReplacementMode - Boolean - flag for replacement of permissions granted
//  previously by owners, AddedPermissions - Array(XDTOObject) - array of
//  added permissions, DeletedPermissions - Array(XDTOObject) - array of
//  deleted permissions, StandardProcessing - Boolean, flag for the standard processing of
//    request creation for external resources use.
//  Result - UUID - request identifier (if inside
//    the handler the value of parameter StandardProcessing is set to False).
//
Procedure WhenPermissionsForExternalResourcesUseAreRequested(Val ApplicationModule, Val Owner, Val ReplacementMode, Val PermissionsToBeAdded, Val PermissionsToBeDeleted, StandardProcessing, Result) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		StandardProcessing = False;
		
		If ApplicationModule = Undefined Then
			ApplicationModule = Catalogs.MetadataObjectIDs.EmptyRef();
		EndIf;
		
		If Owner = Undefined Then
			Owner = ApplicationModule;
		EndIf;
		
		If GetFunctionalOption("SecurityProfilesAreUsed") Then
			
			If CommonUseReUse.CanUseSeparatedData() Then
				
				QueriesRegister = InformationRegisters.PermissionQueriesOnUseDataAreasExternalResources;
				
			Else
				
				QueriesRegister = InformationRegisters.RequestsForPermissionsToUseExternalResourcesSaaS;
				
			EndIf;
			
			PermissionsQuery = QueriesRegister.CreateRecordManager();
			
			PermissionsQuery.IDRequest = New UUID;
			
			If WorkInSafeMode.SafeModeIsSet() Then
				PermissionsQuery.SafeMode = SafeMode();
			Else
				PermissionsQuery.SafeMode = False;
			EndIf;
			
			SoftwareModuleKey = RegisterKeyByLink(ApplicationModule);
			PermissionsQuery.SoftwareModuleType = SoftwareModuleKey.Type;
			PermissionsQuery.SoftwareModuleID = SoftwareModuleKey.ID;
			
			OwnerKey = RegisterKeyByLink(Owner);
			PermissionsQuery.OwnerType = OwnerKey.Type;
			PermissionsQuery.IDOwner = OwnerKey.ID;
			
			PermissionsQuery.ReplacementMode = ReplacementMode;
			
			If PermissionsToBeAdded <> Undefined Then
				
				PermissionsArray = New Array();
				For Each NewPermission IN PermissionsToBeAdded Do
					PermissionsArray.Add(CommonUse.ObjectXDTOInXMLString(NewPermission));
				EndDo;
				
				If PermissionsArray.Count() > 0 Then
					PermissionsQuery.PermissionsToBeAdded = CommonUse.ValueToXMLString(PermissionsArray);
				EndIf;
				
			EndIf;
			
			If PermissionsToBeDeleted <> Undefined Then
				
				PermissionsArray = New Array();
				For Each CanceledPermission IN PermissionsToBeDeleted Do
					PermissionsArray.Add(CommonUse.ObjectXDTOInXMLString(CanceledPermission));
				EndDo;
				
				If PermissionsArray.Count() > 0 Then
					PermissionsQuery.PermissionsToBeDeleted = CommonUse.ValueToXMLString(PermissionsArray);
				EndIf;
				
			EndIf;
			
			PermissionsQuery.Write();
			
			Result = PermissionsQuery.IDRequest;
			
		Else
			
			Result = New UUID();
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Appears when creation of a security profile is requested.
//
// Parameters:
//  ApplicationModule - AnyRef - ref to infobase object
//    representing the software module for which
//  permissions are requested, StandardProcessing - Boolean, flag of
//  standard processing, Result - UUID - request identifier (if inside
//    the handler the value of parameter StandardProcessing is set to False).
//
Procedure WhenSecurityProfileCreationIsRequested(Val ApplicationModule, StandardProcessing, Result) Export
	
	WhenSecurityProfilesChangeIsRequested(ApplicationModule, StandardProcessing, Result);
	
EndProcedure

// Appears when creation of a security profile is requested.
//
// Parameters:
//  ApplicationModule - AnyRef - ref to infobase object
//    representing the software module for which
//  permissions are requested, StandardProcessing - Boolean, flag of
//  standard processing, Result - UUID - request identifier (if inside
//    the handler the value of parameter StandardProcessing is set to False).
//
Procedure WhenSecurityProfileDeletionIsRequested(Val ApplicationModule, StandardProcessing, Result) Export
	
	WhenSecurityProfilesChangeIsRequested(ApplicationModule, StandardProcessing, Result);
	
EndProcedure

Procedure WhenSecurityProfilesChangeIsRequested(Val ApplicationModule, StandardProcessing, Result)
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		StandardProcessing = False;
		Result  = New UUID();
		
	EndIf;
	
EndProcedure

// Appears when the external module is connected. IN the body of the
// handler procedure you can change the safe mode in which the connection will be installed.
//
// Parameters:
//  ExternalModule - AnyRef - ref to infobase object
//    that represents
//  the external connected module, SafeMode - DefinedType.SafeMode - safe mode in which
//    the external module will be connected to the infobase. Can be changed inside this procedure.
//
Procedure WhenConnectingExternalModule(Val ExternalModule, SafeMode) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		SafeMode = ExternalModuleExecutionMode(ExternalModule);
		
	EndIf;
	
EndProcedure

// Generates a list of IB parameters.
//
// Parameters:
// ParameterTable - ValueTable - parameters description table.
// Description columns content - see SaaSOperations.GetIBParameterTable()
//
Procedure WhenCompletingTablesOfParametersOfIB(Val ParameterTable) Export
	
	If CommonUseClientServer.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaSOperations = CommonUseClientServer.CommonModule("SaaSOperations");
		ModuleSaaSOperations.AddConstantToInfobaseParameterTable(ParameterTable, "SecurityProfilesAreUsed");
		ModuleSaaSOperations.AddConstantToInfobaseParameterTable(ParameterTable, "InfobaseSecurityProfile");
		ModuleSaaSOperations.AddConstantToInfobaseParameterTable(ParameterTable, "AutomaticallyConfigurePermissionsInSecurityProfiles");
	EndIf;
	
EndProcedure

// Fills the transferred array with common modules which
//  comprise the handlers of received messages interfaces
//
// Parameters:
//  ArrayOfHandlers - array
//
Procedure RegistrationOfReceivedMessageInterfaces(ArrayOfHandlers) Export
	
	ArrayOfHandlers.Add(MessagesPermissionsManagementControlInterface);
	
EndProcedure

// Fills the array of types excluded from the import and export of data.
//
// Parameters:
//  Types - Array(Types).
//
Procedure WhenFillingTypesExcludedFromExportImport(Types) Export
	
	Types.Add(Metadata.Constants.ControlApplicationExternalAddress);
	
	Types.Add(Metadata.InformationRegisters.RequestsForPermissionsToUseExternalResourcesSaaS);
	Types.Add(Metadata.InformationRegisters.PermissionQueriesOnUseDataAreasExternalResources);
	
	Types.Add(Metadata.InformationRegisters.ExternalResourcesUsingPermissionsSaaS);
	Types.Add(Metadata.InformationRegisters.PermissionOnUseDataAreasExternalResources);
	
	Types.Add(Metadata.InformationRegisters.ExternalModulesConnectionModesSaaS);
	Types.Add(Metadata.InformationRegisters.ExternalModulesConnectionModesDataAreas);
	
	Types.Add(Metadata.InformationRegisters.PermissionApplicationOnUseExternalResourcesSaaS);
	Types.Add(Metadata.InformationRegisters.PermissionApplicationOnUseExternalResourcesDataAreas);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function RegisterKeyByLink(Val Refs)
	
	Result = New Structure("Type,ID");
	
	If Refs = Catalogs.MetadataObjectIDs.EmptyRef() Then
		
		Result.Type = Catalogs.MetadataObjectIDs.EmptyRef();
		Result.ID = New UUID("00000000-0000-0000-0000-000000000000");
		
	Else
		
		Result.Type = CommonUse.MetadataObjectID(Refs.Metadata());
		Result.ID = Refs.UUID();
		
	EndIf;
	
	Return Result;
	
EndFunction

Function RefByRegisterKey(Val Type, Val ID) Export
	
	If Type = Catalogs.MetadataObjectIDs.EmptyRef() Then
		Return Type;
	Else
		
		MetadataObject = CommonUse.MetadataObjectByID(Type);
		Manager = CommonUse.ObjectManagerByFullName(MetadataObject.FullName());
		
		Return Manager.GetRef(ID);
		
	EndIf;
	
EndFunction

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
	
	Key = XDTOFactory.Create(XDTOFactory.Type("http://www.w3.org/2001/XMLSchema", "hexBinary"), Hashing.HashSum).LexicalMeaning;
	
	If StrLen(Key) > 32 Then
		Raise NStr("en='Key length excess';ru='Превышение дланы ключа'");
	EndIf;
	
	Return Key;
	
EndFunction

// Returns a row of the permissions table that corresponds to the filter.
// If the table has no rows that match the selection - can be added a new one.
// If the table has more than one row that corresponds to the filter - exception is being generated.
//
// Parameters:
//  PermissionTable - ValueTable,
//  Filter - Structure,
//  AddIfAbsent - Boolean.
//
// Return value: ValueTableRow or Undefined.
//
Function PermissionsTableRow(Val PermissionTable, Val Filter, Val AddWithout = True) Export
	
	Rows = PermissionTable.FindRows(Filter);
	
	If Rows.Count() = 0 Then
		
		If AddWithout Then
			
			String = PermissionTable.Add();
			FillPropertyValues(String, Filter);
			Return String;
			
		Else
			
			Return Undefined;
			
		EndIf;
		
	ElsIf Rows.Count() = 1 Then
		
		Return Rows.Get(0);
		
	Else
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Violation of row uniqueness in the permission table by filter %1';ru='Нарушение уникальности строк в таблице разрешений по отбору %1'"),
			CommonUse.ValueToXMLString(Filter));
		
	EndIf;
	
EndFunction

// Sets an exclusive adjustable lock to the tables
// of all registers used for storage of granted permissions list.
//
// Parameters:
//  ApplicationModule - AnyRef, a reference to the catalog item
//    corresponding to the external module, information about previously granted permissions on which it is required to clear. If the parameter value is not set -
//    information about granted permissions will be blocked by all external modules.
// LockExternalModulesConnectionModes - Boolean, a flag showing that it is required to additionally lock the connection modes of external modules.
//
Procedure LockGrantedPermissionsRegisters(Val ApplicationModule = Undefined, Val LockExternalModulesConnectionModes = True) Export
	
	If Not TransactionActive() Then
		Raise NStr("en='Transaction is not active';ru='Транзакция не активна!'");
	EndIf;
	
	Registers = New Array();
	
	If CommonUseReUse.CanUseSeparatedData() Then
		
		Registers.Add(InformationRegisters.PermissionOnUseDataAreasExternalResources);
		
		If LockExternalModulesConnectionModes Then
			Registers.Add(InformationRegisters.ExternalModulesConnectionModesSaaS);
		EndIf;
		
	Else
		
		Registers.Add(InformationRegisters.PermissionOnUseDataAreasExternalResources);
		
		If LockExternalModulesConnectionModes Then
			Registers.Add(InformationRegisters.ExternalModulesConnectionModesSaaS);
		EndIf;
		
	EndIf;
	
	If ApplicationModule <> Undefined Then
		Key = RegisterKeyByLink(ApplicationModule);
	EndIf;
	
	Block = New DataLock();
	
	For Each Register IN Registers Do
		RegisterBlock = Block.Add(Register.CreateRecordSet().Metadata().FullName());
		If ApplicationModule <> Undefined Then
			RegisterBlock.SetValue("SoftwareModuleType", Key.Type);
			RegisterBlock.SetValue("SoftwareModuleID", Key.ID);
		EndIf;
	EndDo;
	
	Block.Lock();
	
EndProcedure

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
// * Type - String - XDTO-type name that
// describes the permissions, * Permissions - Map - Permissions description:
//   * Key - String - permission key (see the function PermissionKey in module
//      of
//   register manager PermissionsForExternalResourcesUse), * Value - XDTODataObject - XDTO-description
// of the permission, * PermissionsSupplements - Map - Description of permission additions:
//   * Key - String - permission key (see the function PermissionKey in module
//      of
//   register manager PermissionsForExternalResourcesUse), * Value - Structure - see function PermissionSupplement in the
//      register manager module PermissionsForExternalResourcesUse).
//
Function PermissionsCut(Val InContextOfOwners = True, Val WithoutDescriptions = False) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Register = InformationRegisters.PermissionOnUseDataAreasExternalResources;
	Else
		Register = InformationRegisters.ExternalResourcesUsingPermissionsSaaS;
	EndIf;
	
	Result = New ValueTable();
	
	Result.Columns.Add("SoftwareModuleType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	Result.Columns.Add("SoftwareModuleID", New TypeDescription("UUID"));
	If InContextOfOwners Then
		Result.Columns.Add("OwnerType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
		Result.Columns.Add("IDOwner", New TypeDescription("UUID"));
	EndIf;
	Result.Columns.Add("Type", New TypeDescription("String"));
	Result.Columns.Add("permissions", New TypeDescription("Map"));
	
	Selection = Register.Select();
	
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
		
		String = PermissionsTableRow(Result, FilterByTable);
		
		AuthorizationBody = Selection.AuthorizationBody;
		AuthorizationKey = Selection.AuthorizationKey;
		
		If WithoutDescriptions Then
			
			If ValueIsFilled(Resolution.Description) Then
				
				Resolution.Description = "";
				AuthorizationBody = CommonUse.ObjectXDTOInXMLString(Resolution);
				AuthorizationKey = AuthorizationKey(Resolution);
				
			EndIf;
			
		EndIf;
		
		String.permissions.Insert(AuthorizationKey, AuthorizationBody);
		
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
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Register = InformationRegisters.PermissionOnUseDataAreasExternalResources;
	Else
		Register = InformationRegisters.ExternalResourcesUsingPermissionsSaaS;
	EndIf;
	
	Manager = Register.CreateRecordManager();
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
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Register = InformationRegisters.PermissionOnUseDataAreasExternalResources;
	Else
		Register = InformationRegisters.ExternalResourcesUsingPermissionsSaaS;
	EndIf;
	
	Manager = Register.CreateRecordManager();
	Manager.SoftwareModuleType = SoftwareModuleType;
	Manager.SoftwareModuleID = SoftwareModuleID;
	Manager.OwnerType = OwnerType;
	Manager.IDOwner = IDOwner;
	Manager.AuthorizationKey = AuthorizationKey;
	
	Manager.Read();
	
	If Manager.Selected() Then
		
		If Manager.AuthorizationBody <> CommonUse.ObjectXDTOInXMLString(Resolution) Then
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Collection of
		|permissions by
		|the keys: -SowtwareModuleType:
		|%1 -SowtwareModuleIdentifier: 2%
		|- OwnerType: %3
		|-OwnerIdentifier: %4 - PermissionKey: %5.';ru='Коллзиция
		|разрешений
		|по ключам: -
		|ТипПрограммногоМодуля: %1 -
		|ИдентификаторПрограммногоМодуля: %2
		|- ТипВладельца: %3 - ИдентификаторВладельца: %4 - КлючРазрешения: %5.'"),
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

// Removes the requests for external resource usage.
//
// Parameters:
//  QueryIDs - Array(UUID) - identifiers of deleted queries.
//
Procedure DeleteQueries(Val QueryIDs) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Register = InformationRegisters.PermissionQueriesOnUseDataAreasExternalResources;
	Else
		Register = InformationRegisters.RequestsForPermissionsToUseExternalResourcesSaaS;
	EndIf;
	
	BeginTransaction();
	
	Try
		
		For Each IDRequest IN QueryIDs Do
			
			Manager = Register.CreateRecordManager();
			Manager.IDRequest = IDRequest;
			Manager.Delete();
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

// Clears invalid requests for use of external resources.
//
Procedure ClearIrrelevantQueries() Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Register = InformationRegisters.PermissionQueriesOnUseDataAreasExternalResources;
	Else
		Register = InformationRegisters.RequestsForPermissionsToUseExternalResourcesSaaS;
	EndIf;
	
	BeginTransaction();
	
	Try
		
		Selection = Register.Select();
		
		While Selection.Next() Do
			
			Try
				
				Key = Register.CreateRecordKey(New Structure("IDRequest", Selection.IDRequest));
				LockDataForEdit(Key);
				
			Except
				
				// Processing of the exception is not required.
				// Expected exception - attempt to delete the same register record from other session.
				Continue;
				
			EndTry;
			
			Manager = Register.CreateRecordManager();
			Manager.IDRequest = Selection.IDRequest;
			Manager.Delete();
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

// Creates and initializes the manager of requests application to use external resources.
//
// Parameters:
//  QueryIDs - Array(UUID) - request identifiers
//   for application of which a manager is created.
//
// Return value: ProcessingObject.PermissionSetupForExternalResourcesUse.
//
Function PermissionsApplicationManager(Val QueryIDs) Export
	
	Manager = DataProcessors.PermissionSettingsForExternalResourcesUseSaaS.Create();
	
	If CommonUseReUse.CanUseSeparatedData() Then
		Register = InformationRegisters.PermissionQueriesOnUseDataAreasExternalResources;
	Else
		Register = InformationRegisters.RequestsForPermissionsToUseExternalResourcesSaaS;
	EndIf;
	
	QueryText =
		"SELECT
		|	Queries.SoftwareModuleType,
		|	Queries.SoftwareModuleID,
		|	Queries.OwnerType,
		|	Queries.IDOwner,
		|	Queries.ReplacementMode,
		|	Queries.PermissionsToBeAdded,
		|	Queries.PermissionsToBeDeleted,
		|	Queries.IDRequest
		|FROM
		|	[Table] AS Queries
		|WHERE
		|	Queries.IDRequest IN(&QueryIDs)";
	
	QueryText = StrReplace(QueryText, "[Table]", Register.CreateRecordSet().Metadata().FullName());
	
	Query = New Query(QueryText);
	Query.SetParameter("QueryIDs", QueryIDs);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		RecordKey = Register.CreateRecordKey(New Structure("IDRequest", Selection.IDRequest));
		LockDataForEdit(RecordKey);
		
		PermissionsToBeAdded = New Array();
		If ValueIsFilled(Selection.PermissionsToBeAdded) Then
			
			Array = CommonUse.ValueFromXMLString(Selection.PermissionsToBeAdded);
			
			For Each ArrayElement IN Array Do
				PermissionsToBeAdded.Add(CommonUse.ObjectXDTOFromXMLRow(ArrayElement));
			EndDo;
			
		EndIf;
		
		PermissionsToBeDeleted = New Array();
		If ValueIsFilled(Selection.PermissionsToBeDeleted) Then
			
			Array = CommonUse.ValueFromXMLString(Selection.PermissionsToBeDeleted);
			
			For Each ArrayElement IN Array Do
				PermissionsToBeDeleted.Add(CommonUse.ObjectXDTOFromXMLRow(ArrayElement));
			EndDo;
			
		EndIf;
		
		Manager.AddQueryID(Selection.IDRequest);
		
		Manager.AddRequestForExternalResourcesUsePermissions(
			Selection.SoftwareModuleType,
			Selection.SoftwareModuleID,
			Selection.OwnerType,
			Selection.IDOwner,
			Selection.ReplacementMode,
			PermissionsToBeAdded,
			PermissionsToBeDeleted);
		
	EndDo;
	
	Manager.CalculateQueriesApplication();
	
	Return Manager;
	
EndFunction

Function AppliedRequestsPackage(Val Status) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Register = InformationRegisters.PermissionApplicationOnUseExternalResourcesDataAreas;
	Else
		Register = InformationRegisters.PermissionApplicationOnUseExternalResourcesSaaS;
	EndIf;
	
	Manager = Register.CreateRecordManager();
	Manager.PackageIdentifier = New UUID();
	Manager.Status = Status;
	
	Manager.Write();
	
	Return Manager.PackageIdentifier;
	
EndFunction

Function PackageProcessingResult(Val PackageIdentifier) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Register = InformationRegisters.PermissionApplicationOnUseExternalResourcesDataAreas;
	Else
		Register = InformationRegisters.PermissionApplicationOnUseExternalResourcesSaaS;
	EndIf;
	
	Manager = Register.CreateRecordManager();
	Manager.PackageIdentifier = New UUID();
	Manager.Read();
	
	If Manager.Selected() Then
		
		Return Manager.Result;
		
	Else
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Query pack %1 is not found';ru='Не найден пакет запросов %1'"), PackageIdentifier);
		
	EndIf;
	
EndFunction

Procedure SetPackageProcessingResult(Val PackageIdentifier, Val Result) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Register = InformationRegisters.PermissionApplicationOnUseExternalResourcesDataAreas;
	Else
		Register = InformationRegisters.PermissionApplicationOnUseExternalResourcesSaaS;
	EndIf;
	
	Manager = Register.CreateRecordManager();
	Manager.PackageIdentifier = New UUID();
	Manager.Result = Result;
	Manager.Write();
	
EndProcedure

Function PackageProcessingState(Val PackageIdentifier)
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Register = InformationRegisters.PermissionApplicationOnUseExternalResourcesDataAreas;
	Else
		Register = InformationRegisters.PermissionApplicationOnUseExternalResourcesSaaS;
	EndIf;
	
	Manager = Register.CreateRecordManager();
	Manager.PackageIdentifier = New UUID();
	Manager.Read();
	
	If Manager.Selected() Then
		
		Return Manager.Status;
		
	Else
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Query pack %1 is not found';ru='Не найден пакет запросов %1'"), PackageIdentifier);
		
	EndIf;
	
EndFunction

Function PackageApplicationManager (Val PackageIdentifier) Export
	
	Manager = DataProcessors.PermissionSettingsForExternalResourcesUseSaaS.Create();
	Manager.ReadStatusFromXMLRow(PackageProcessingState(PackageIdentifier));
	
	Return Manager;
	
EndFunction

// Serializes the requests on the use of external resources for sending to service manager.
//
// Parameters:
//  QueryIDs - Array(UUID) - Requests identifiers.
//
// Returns - XDTOObject {http://www.1c.ru/1CFresh/Application/Permissions/Management/a.b.c.d}PermissionsRequestsList.
//
Function SerializeQueriesOnExternalResourcesUse(Val QueryIDs) Export
	
	Envelop = XDTOFactory.Create(XDTOFactory.Type(PermissionsAdministrationPackage(), "PermissionsRequestsList"));
	
	QueryText =
		"SELECT
		|	Queries.SoftwareModuleType,
		|	Queries.SoftwareModuleID,
		|	Queries.OwnerType,
		|	Queries.IDOwner,
		|	Queries.ReplacementMode,
		|	Queries.PermissionsToBeAdded,
		|	Queries.PermissionsToBeDeleted
		|FROM
		|	[Table] AS Queries
		|WHERE
		|	Queries.IDRequest IN(&QueryIDs)";
	
	If CommonUseReUse.CanUseSeparatedData() Then
		
		QueryText = StrReplace(QueryText, "[Table]", "InformationRegister.PermissionQueriesOnUseDataAreasExternalResources");
		
	Else
		
		QueryText = StrReplace(QueryText, "[Table]", "InformationRegister.RequestsForPermissionsToUseExternalResourcesSaaS");
		
	EndIf;
	
	Query = New Query(QueryText);
	Query.SetParameter("QueryIDs", QueryIDs);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		PermissionsQuery = XDTOFactory.Create(XDTOFactory.Type(PermissionsAdministrationPackage(), "PermissionsRequest"));
		
		PermissionsQuery.UUID = Selection.IDRequest;
		
		ApplicationModule = RefByRegisterKey(Selection.SoftwareModuleType, Selection.SoftwareModuleID);
		Owner = RefByRegisterKey(Selection.OwnerType, Selection.IDOwner);
		
		SoftwareModulePresentation = Undefined;
		OwnerPresentation = Undefined;
		
		StandardProcessing = True;
		
		If ServiceTechnologyIntegrationWithSSL.SubsystemExists("ServiceTechnology.SaaS.AdditionalReportsAndDataProcessorsSaaS") Then
			
			ModuleAdditionalReportsAndDataProcessorsSaaS = ServiceTechnologyIntegrationWithSSL.CommonModule("AdditionalReportsAndDataProcessorsSaaS");
			ModuleAdditionalReportsAndDataProcessorsSaaS.WhenSerializingPermissionsOwnerForExternalResourcesUse(
				Owner, StandardProcessing, SoftwareModulePresentation, OwnerPresentation);
			
		EndIf;
		
		If StandardProcessing Then
			
			If ApplicationModule = Catalogs.MetadataObjectIDs.EmptyRef() Then
				
				SoftwareModulePresentation = XDTOFactory.Create(XDTOFactory.Type(PermissionsAdministrationPackage(), "PermissionModuleApplication"));
				
			Else
				
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Unserialized key program module: - Type: 1% - ID: %2';ru='Не сериализован программный модуль по ключу: - Тип: %1 - Идентификатор: %2'"),
					Selection.SoftwareModuleType,
					Selection.SoftwareModuleID);
				
			EndIf;
			
			If Owner = Catalogs.MetadataObjectIDs.EmptyRef() Then
				
				OwnerPresentation = XDTOFactory.Create(XDTOFactory.Type(PermissionsAdministrationPackage(), "PermissionsOwnerApplication"));
				
			Else
				
				OwnerPresentation = XDTOFactory.Create(XDTOFactory.Type(PermissionsAdministrationPackage(), "PermissionsOwnerApplicationObject"));
				OwnerPresentation.Type = Selection.Owner.Metadata().FullName();
				OwnerPresentation.UUID = Selection.Owner.UUID();
				OwnerPresentation.Description = String(Selection.Owner);
				
			EndIf;
			
		EndIf;
		
		PermissionsQuery.Module = SoftwareModulePresentation;
		PermissionsQuery.Owner = OwnerPresentation;
		
		PermissionsToBeAdded = XDTOFactory.Create(XDTOFactory.Type(PermissionsAdministrationPackage(), "PermissionsList"));
		If Not IsBlankString(Selection.PermissionsToBeAdded) Then
			PermissionsArray = CommonUse.ValueFromXMLString(Selection.PermissionsToBeAdded);
			For Each ArrayElement IN PermissionsArray Do
				PermissionsToBeAdded.Permission.Add(CommonUse.ObjectXDTOFromXMLRow(ArrayElement));
			EndDo;
		EndIf;
		PermissionsQuery.GrantPermissions = PermissionsToBeAdded;
		
		PermissionsToBeDeleted = XDTOFactory.Create(XDTOFactory.Type(PermissionsAdministrationPackage(), "PermissionsList"));
		If Not IsBlankString(Selection.PermissionsToBeDeleted) Then
			PermissionsArray = CommonUse.ValueFromXMLString(Selection.PermissionsToBeDeleted);
			For Each ArrayElement IN PermissionsArray Do
				PermissionsToBeDeleted.Permission.Add(CommonUse.ObjectXDTOFromXMLRow(ArrayElement));
			EndDo;
		EndIf;
		PermissionsQuery.CancelPermissions = PermissionsToBeDeleted;
		
		PermissionsQuery.ReplaceOwnerPermissions = Selection.ReplacementMode;
		
		Envelop.Request.Add(PermissionsQuery);
		
	EndDo;
	
	Return Envelop;
	
EndFunction

Function PermissionsAdministrationPackage() Export
	
	Return "http://www.1c.ru/1cFresh/Application/Permissions/Management/1.0.0.1";
	
EndFunction

#EndRegion