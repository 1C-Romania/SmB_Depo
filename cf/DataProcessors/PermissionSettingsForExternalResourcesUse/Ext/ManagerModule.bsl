////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Server procedures and functions of common use:
// - Management of permissions in the security profiles of current IB.
//
////////////////////////////////////////////////////////////////////////////////

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Logic of assistant of external resources permissions settings.
//

// For an internal use.
//
Procedure ProcessRequests(Val QueryIDs, Val TemporaryStorageAddress, Val TemporaryStorageAddressStates, Val AddClearingRequestsBeforeUse = False) Export
	
	Manager = InformationRegisters.PermissionQueriesOnUseExternalResources.PermissionsApplicationManager(QueryIDs);
	
	If AddClearingRequestsBeforeUse Then
		Manager.AddClearingPermissionsBeforeApplying();
	EndIf;
	
	Status = New Structure();
	
	If Manager.PermissionsApplicationRequiredOnServerCluster() Then
		
		Status.Insert("PermissionsApplicationRequired", True);
		
		Result = New Structure();
		Result.Insert("Presentation", Manager.Presentation());
		Result.Insert("Script", Manager.UseScenario());
		Result.Insert("Status", Manager.WriteStatusInXMLString());
		PutToTempStorage(Result, TemporaryStorageAddress);
		
		Status.Insert("StorageAddress", TemporaryStorageAddress);
		
	Else
		
		Status.Insert("PermissionsApplicationRequired", False);
		Manager.FinishRequestsApplicationOnExternalResourcesUse();
		
	EndIf;
	
	PutToTempStorage(Status, TemporaryStorageAddressStates);
	
EndProcedure

// For an internal use.
//
Procedure ProcessUpdateRequests(Val TemporaryStorageAddress, Val TemporaryStorageAddressStates) Export
	
	CallWhenDisabledProfiles = Not Constants.AutomaticallyConfigurePermissionsInSecurityProfiles.Get();
	
	If CallWhenDisabledProfiles Then
		
		BeginTransaction();
		
		Constants.SecurityProfilesAreUsed.Set(True);
		Constants.AutomaticallyConfigurePermissionsInSecurityProfiles.Set(True);
		
		QueryIDs = WorkInSafeModeService.ConfigurationPermissionsUpdateQueries();
		RequestsSerialization = InformationRegisters.PermissionQueriesOnUseExternalResources.WriteRequestsToXMLString(QueryIDs);
		
	EndIf;
	
	ProcessRequests(QueryIDs, TemporaryStorageAddress, TemporaryStorageAddressStates);
	
	If CallWhenDisabledProfiles Then
		
		RollbackTransaction();
		InformationRegisters.PermissionQueriesOnUseExternalResources.ReadRequestsFromXMLString(RequestsSerialization);
		
	EndIf;
	
EndProcedure

// For an internal use.
//
Procedure ProcessDisconnectionRequests(Val TemporaryStorageAddress, Val TemporaryStorageAddressStates) Export
	
	Queries = New Array();
	
	BeginTransaction();
	
	Try
		
		IBProfileDeletionRequestID = WorkInSafeModeService.SecurityProfileDeletionRequest(
			Catalogs.MetadataObjectIDs.EmptyRef());
		
		Queries.Add(IBProfileDeletionRequestID);
		
		QueryText =
			"SELECT DISTINCT
			|	ExternalModulesConnectionModes.SoftwareModuleType AS SoftwareModuleType,
			|	ExternalModulesConnectionModes.SoftwareModuleID AS SoftwareModuleID
			|FROM
			|	InformationRegister.ExternalModulesConnectionModes AS ExternalModulesConnectionModes";
		Query = New Query(QueryText);
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			Queries.Add(WorkInSafeModeService.SecurityProfileDeletionRequest(
				WorkInSafeModeService.RefFromPermissionsRegister(Selection.SoftwareModuleType, Selection.SoftwareModuleID)));
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
	ProcessRequests(Queries, TemporaryStorageAddress, TemporaryStorageAddressStates);
	
EndProcedure

// For an internal use.
//
Procedure ProcessRecoveryRequests(Val TemporaryStorageAddress, Val TemporaryStorageAddressStates) Export
	
	BeginTransaction();
	
	ClearGivenPermissions(, False);
	
	QueryIDs = New Array();
	CommonUseClientServer.SupplementArray(QueryIDs, InformationRegisters.PermissionQueriesOnUseExternalResources.ReplacementRequestsForAllGrantedPermissions());
	CommonUseClientServer.SupplementArray(QueryIDs, WorkInSafeModeService.ConfigurationPermissionsUpdateQueries(False));
	
	Serialization = InformationRegisters.PermissionQueriesOnUseExternalResources.WriteRequestsToXMLString(QueryIDs);
	
	ProcessRequests(QueryIDs, TemporaryStorageAddress, TemporaryStorageAddressStates, True);
	
	RollbackTransaction();
	
	InformationRegisters.PermissionQueriesOnUseExternalResources.ReadRequestsFromXMLString(Serialization);
	
EndProcedure

// For an internal use.
//
Function RunUsageCheckQueriesProcessor() Export
	
	If TransactionActive() Then
		Raise NStr("en='Transaction is active';ru='Транзакция активна'");
	EndIf;
	
	Result = New Structure();
	
	BeginTransaction();
	
	QueryIDs = New Array();
	CommonUseClientServer.SupplementArray(QueryIDs, InformationRegisters.PermissionQueriesOnUseExternalResources.ReplacementRequestsForAllGrantedPermissions());
	CommonUseClientServer.SupplementArray(QueryIDs, WorkInSafeModeService.ConfigurationPermissionsUpdateQueries(False));
	
	Manager = InformationRegisters.PermissionQueriesOnUseExternalResources.PermissionsApplicationManager(QueryIDs);
	
	Serialization = InformationRegisters.PermissionQueriesOnUseExternalResources.WriteRequestsToXMLString(QueryIDs);
	
	RollbackTransaction();
	
	If Manager.PermissionsApplicationRequiredOnServerCluster() Then
		
		TemporaryStorageAddress = PutToTempStorage(Undefined, New UUID());
		
		InformationRegisters.PermissionQueriesOnUseExternalResources.ReadRequestsFromXMLString(Serialization);
		
		Result.Insert("CheckResult", False);
		Result.Insert("QueryIDs", QueryIDs);
		
		PermissionsRequestState = New Structure();
		PermissionsRequestState.Insert("Presentation", Manager.Presentation());
		PermissionsRequestState.Insert("Script", Manager.UseScenario());
		PermissionsRequestState.Insert("Status", Manager.WriteStatusInXMLString());
		
		PutToTempStorage(PermissionsRequestState, TemporaryStorageAddress);
		Result.Insert("TemporaryStorageAddress", TemporaryStorageAddress);
		
		TemporaryStorageAddressStates = PutToTempStorage(Undefined, New UUID());
		
		Status = New Structure();
		Status.Insert("PermissionsApplicationRequired", True);
		Status.Insert("StorageAddress", TemporaryStorageAddress);
		
		PutToTempStorage(Status, TemporaryStorageAddressStates);
		Result.Insert("TemporaryStorageAddressStates", TemporaryStorageAddressStates);
		
	Else
		
		If Manager.RequirePermissionsWriteToRegister() Then
			Manager.FinishRequestsApplicationOnExternalResourcesUse();
		EndIf;
		
		Result.Insert("CheckResult", True);
		
	EndIf;
	
	Return Result;
	
EndFunction

// For an internal use.
//
Procedure RecordRequestsUse(Val Status) Export
	
	Manager = DataProcessors.PermissionSettingsForExternalResourcesUse.Create();
	Manager.ReadStatusFromXMLRow(Status);
	
	Manager.FinishRequestsApplicationOnExternalResourcesUse();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Work with registers that are
// used to store granted permissions to use external resources.
//

// Sets an exclusive managed lock for all register
// tables used to store lists of provided permissions.
//
// Parameters:
//  ProgramModule - AnyRef - ref to a catalog item that
//    corresponds to the external module information on which granted permissions it is required to clear. If the parameter value is not set -
//    information about granted permissions will be blocked by all external modules.
// LockConnectionModes - Boolean - flag showing that additional lock
//    is required for connection modes of external modules.
//
Procedure LockGrantedPermissionsRegisters(Val ProgramModule = Undefined, Val LockConnectionModes = True) Export
	
	If Not TransactionActive() Then
		Raise NStr("en='Transaction is not active';ru='Транзакция не активна!'");
	EndIf;
	
	Block = New DataLock();
	
	Registers = New Array();
	Registers.Add(InformationRegisters.ExternalResourcesUsingPermissions);
	
	If LockConnectionModes Then
		Registers.Add(InformationRegisters.ExternalModulesConnectionModes);
	EndIf;
	
	For Each Register IN Registers Do
		RegisterBlock = Block.Add(Register.CreateRecordSet().Metadata().FullName());
		If ProgramModule <> Undefined Then
			ProgramModuleProperties = WorkInSafeModeService.PropertiesForPermissionsRegister(ProgramModule);
			RegisterBlock.SetValue("SoftwareModuleType", ProgramModuleProperties.Type);
			RegisterBlock.SetValue("SoftwareModuleID", ProgramModuleProperties.ID);
		EndIf;
	EndDo;
	
	Block.Lock();
	
EndProcedure

// Clears the information registers that are used to store a granted permissions list in the IB.
//
// Parameters:
//  ProgramModule - AnyRef, a reference to the catalog item
//    corresponding to the external module, information about previously granted permissions on which it is required to clear. If the parameter value is not set -
//    information on all provided permissions for all external modules will be cleared.
// ClearConnectionModes - Boolean, flag showing that connection
//    modes of external modules should be additionally cleared.
//
Procedure ClearGivenPermissions(Val ProgramModule = Undefined, Val ClearConnectionModes = True) Export
	
	BeginTransaction();
	
	Try
		
		LockGrantedPermissionsRegisters(ProgramModule, ClearConnectionModes);
		
		Managers = New Array();
		Managers.Add(InformationRegisters.ExternalResourcesUsingPermissions);
		
		If ClearConnectionModes Then
			Managers.Add(InformationRegisters.ExternalModulesConnectionModes);
		EndIf;
		
		For Each Manager IN Managers Do
			Set = Manager.CreateRecordSet();
			If ProgramModule <> Undefined Then
				ProgramModuleProperties = WorkInSafeModeService.PropertiesForPermissionsRegister(ProgramModule);
				Set.Filter.SoftwareModuleType.Set(ProgramModuleProperties.Type);
				Set.Filter.SoftwareModuleID.Set(ProgramModuleProperties.ID);
			EndIf;
			Set.Write(True);
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Work with permission tables.
//

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

#EndRegion

#EndIf


