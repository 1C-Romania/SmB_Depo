#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Server procedures and functions of common use:
// - Management of permissions in the security profiles of current IB.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalState

// Array(UUID) - array of request identifiers to
// use external resources for using which the object was initialized.
//
Var QueryIDs;

// ValueTable - administration operations plan when using requests to
// use external resources Columns:
//  * SoftwareModuleType - CatalogRef.MetadataObjectsIdentifiers,
//  * SoftwareModuleIdentifier - UUID,
//  * Operation - EnumRef.OperationsAdministrationSecurityProfiles,
//  * Name - String - security proattachment file name.
//
Var AdministrationOperations;

// Structure - Current request use plan to use external resources. Structure fields:
//  * Replaced - ValueTable - operations to replace the existing permissions to use external resources:
//      * SoftwareModuleType - CatalogRef.MetadataObjectsIdentifiers,
//      * SoftwareModuleIdentifier - UUID,
//      * OwnerType - CatalogRef.MetaDataObjectsIdentifiers,
//      * OwnerIdentifier - UUID,
//  * Added - ValueTable - operations of adding permissions to use external resources:
//      * SoftwareModuleType - CatalogRef.MetadataObjectsIdentifiers,
//      * SoftwareModuleIdentifier - UUID,
//      * OwnerType - CatalogRef.MetaDataObjectsIdentifiers,
//      * OwnerIdentifier - UUID,
//      * Type - String - XDTO type name that describes permissions, 
//      * Permissions - Map - description of added permissions:
//         * Key - String - permission key (see the PermissionKey function in the register manager module.
//             ExternalResourcesUsePermissions),
//         * Value - XDTODataObject - XDTO description of the permission you want to add,
//         * PermissionsAdditions - Map - description of added permissions additions:
//         * Key - String - permission key (see the PermissionKey function in the register manager module.
//             ExternalResourcesUsePermissions),
//         * Value - Structure - see PermissionAddition function in the register manager module.
//             ExternalResourcesUsePermissions,
//  * Deleted - ValueTable - operation to delete permissions to use external resources:
//      * SoftwareModuleType - CatalogRef.MetadataObjectsIdentifiers,
//      * SoftwareModuleIdentifier - UUID,
//      * OwnerType - CatalogRef.MetaDataObjectsIdentifiers,
//      * OwnerIdentifier - UUID,
//      * Type - String - XDTO type name that describes permissions, 
//      * Permissions - Map - description of permissions being deleted:
//         * Key - String - permission key (see the PermissionKey function in the register manager module.
//             ExternalResourcesUsePermissions),
//         * Value - XDTODataObject - XDTO description
//      of deleted permission, * PermissionAdditions - Map - description of the permissions being deleted:
//         * Key - String - permission key (see the PermissionKey function in the register manager module.
//             ExternalResourcesUsePermissions),
//         * Value - Structure - see PermissionAddition function in the register manager module.
//             ExternalResourcesUsePermissions.
//
Var RequestUsePlan;

// Values table - initial permissions cut (with permissions owners). Columns:
// * SoftwareModuleType - CatalogRef.MetadataObjectsIdentifiers,
// * SoftwareModuleIdentifier - UUID,
// * OwnerType - CatalogRef.MetaDataObjectsIdentifiers,
// * OwnerIdentifier - UUID,
// * Type - String - XDTO type name
// that describes permissions, * Permissions - Map - Permissions description:
//   * Key - String - permission key (see the PermissionKey function in the register manager module.
//      ExternalResourcesUsePermissions),
//   * Value - XDTODataObject - XDTO-description of the permission,
//   * PermissionsSupplements - Map - Description of permission additions:
//   * Key - String - permission key (see the PermissionKey function in the register manager module.
//      ExternalResourcesUsePermissions),
//   * Value - Structure - see PermissionAddition function in the register manager module.
//      ExternalResourcesUsePermissions.
//
Var OriginalPermissionsCutInOwnersContext;

// Values table - initial permissions cut (without permissions owners). Columns:
// * SoftwareModuleType - CatalogRef.MetadataObjectsIdentifiers,
// * SoftwareModuleIdentifier - UUID,
// * Type - String - XDTO type name that describes permissions,
// * Permissions - Map - Permissions description:
//   * Key - String - permission key (see the PermissionKey function in the register manager module.
//      ExternalResourcesUsePermissions),
//   * Value - XDTODataObject - XDTO-description of the permission, 
//   * PermissionsSupplements - Map - Description of permission additions:
//   * Key - String - permission key (see the PermissionKey function in the register manager module.
//      ExternalResourcesUsePermissions),
//   * Value - Structure - see PermissionAddition function in the register manager module.
//      ExternalResourcesUsePermissions.
//
Var OriginalPermissionsCutWithoutOwners;

// Values table - permissions section in requests use result (with permissions owners).
// Columns:
// * SoftwareModuleType - CatalogRef.MetadataObjectsIdentifiers,
// * SoftwareModuleIdentifier - UUID,
// * OwnerType - CatalogRef.MetaDataObjectsIdentifiers,
// * OwnerIdentifier - UUID,
// * Type - String - XDTO type name that describes permissions, 
// * Permissions - Map - Permissions description:
//   * Key - String - permission key (see the PermissionKey function in the register manager module.
//      ExternalResourcesUsePermissions),
//   * Value - XDTODataObject - XDTO-description of the permission, 
//   * PermissionsSupplements - Map - Description of permission additions:
//   * Key - String - permission key (see the PermissionKey function in the register manager module.
//      ExternalResourcesUsePermissions),
//   * Value - Structure - see PermissionAddition function in the register manager module.
//      ExternalResourcesUsePermissions.
//
Var RequestsUseResultInOwnersContext;

// Values table - permissions section in requests use result (with permissions owners).
// Columns:
// * SoftwareModuleType - CatalogRef.MetadataObjectsIdentifiers,
// * SoftwareModuleIdentifier - UUID,
// * Type - String - XDTO type name that describes permissions, 
// * Permissions - Map - Permissions description:
//   * Key - String - permission key (see the PermissionKey function in the register manager module.
//      ExternalResourcesUsePermissions),
//   * Value - XDTODataObject - XDTO-description
// of the permission, * PermissionsSupplements - Map - Description of permission additions:
//   * Key - String - permission key (see the PermissionKey function in the register manager module.
//      ExternalResourcesUsePermissions),
//   * Value - Structure - see PermissionAddition function in the register manager module.
//      ExternalResourcesUsePermissions).
//
Var RequestsUseResultWithoutOwners;

// Structure - delta between the source and result permissions cuts (with permissions owners):
//  * Added - ValueTable - description of added permissions, columns:
//    * SoftwareModuleType - CatalogRef.MetadataObjectsIdentifiers,
//    * SoftwareModuleIdentifier - UUID,
//    * OwnerType - CatalogRef.MetaDataObjectsIdentifiers,
//    * OwnerIdentifier - UUID,
//    * Type - String - XDTO type name that describes permissions,
//    * Permissions - Map - Permissions description:
//      * Key - String - permission key (see the PermissionKey function in the register manager module.
//         ExternalResourcesUsePermissions),
//      * Value - XDTODataObject - XDTO-description of the permission, 
//      * PermissionsSupplements - Map - Description of permission additions:
//      * Key - String - permission key (see the PermissionKey function in the register manager module.
//         ExternalResourcesUsePermissions),
//      * Value - Structure - see PermissionAddition function in the register manager module.
//         ExternalResourcesUsePermissions).
//  * Deleted - ValueTable - description of permissions being deleted, columns:
//    * SoftwareModuleType - CatalogRef.MetadataObjectsIdentifiers,
//    * SoftwareModuleIdentifier - UUID,
//    * OwnerType - CatalogRef.MetaDataObjectsIdentifiers,
//    * OwnerIdentifier - UUID,
//    * Type - String - XDTO type name that describes permissions, 
//    * Permissions - Map - Permissions description:
//      * Key - String - permission key (see the PermissionKey function in the register manager module.
//         ExternalResourcesUsePermissions),
//      * Value - XDTODataObject - XDTO-description of the permission, 
//      * PermissionsSupplements - Map - Description of permission additions:
//      * Key - String - permission key (see the PermissionKey function in the register manager module.
//         ExternalResourcesUsePermissions),
//      * Value - Structure - see PermissionAddition function in the register manager module.
//         ExternalResourcesUsePermissions).
//
Var DeltaInOwnersContext;

// Structure - delta between the source and result permissions cuts (without permissions owners):
//  * Added - ValueTable - description of added permissions, columns:
//    * SoftwareModuleType - CatalogRef.MetadataObjectsIdentifiers,
//    * SoftwareModuleIdentifier - UUID,
//    * Type - String - XDTO type name that describes permissions, 
//    * Permissions - Map - Permissions description:
//      * Key - String - permission key (see the PermissionKey function in the register manager module.
//         ExternalResourcesUsePermissions),
//      * Value - XDTODataObject - XDTO-description of the permission, 
//      * PermissionsSupplements - Map - Description of permission additions:
//      * Key - String - permission key (see the PermissionKey function in the register manager module.
//         ExternalResourcesUsePermissions),
//      * Value - Structure - see PermissionAddition function in the register manager module.
//         ExternalResourcesUsePermissions).
//  * Deleted - ValueTable - description of permissions being deleted, columns:
//    * SoftwareModuleType - CatalogRef.MetadataObjectsIdentifiers,
//    * SoftwareModuleIdentifier - UUID,
//    * Type - String - XDTO type name that describes permissions,
//    * Permissions - Map - Permissions description:
//      * Key - String - permission key (see the PermissionKey function in the register manager module.
//         ExternalResourcesUsePermissions),
//      * Value - XDTODataObject - XDTO-description of the permission, 
//      * PermissionsSupplements - Map - Description of permission additions:
//      * Key - String - permission key (see the PermissionKey function in the register manager module.
//         ExternalResourcesUsePermissions),
//      * Value - Structure - see PermissionAddition function in the register manager module.
//         ExternalResourcesUsePermissions.
//
Var DeltaNotIncludingOwners;

// Boolean - shows that information on the permissions before using permissions is cleared.
//
Var ClearingPermissionsBeforeApplying;

#EndRegion

#Region ServiceProceduresAndFunctions

// Adds a request identifier to the list of processed. After successful use, requests
// which identifiers are added will be cleared.
//
// Parameters:
//  IDRequest - UUID - ID of the
//    query on external resources use.
//
Procedure AddQueryID(Val IDRequest) Export
	
	QueryIDs.Add(IDRequest);
	
EndProcedure

// Adds a security profile administration operation to the requests use plan.
//
// Parameters:
//  SoftwareModuleType - CatalogRef.MetadataObjectIDs,
//  SoftwareModuleIdentifier - UUID,
//  Operation - EnumRef.OperationsAdministrationSecurityProfiles,
//  Name - String - security proattachment file name.
//
Procedure AddAdministrationOperation(Val SoftwareModuleType, Val SoftwareModuleID, Val Operation, Val Name) Export
	
	Filter = New Structure();
	Filter.Insert("SoftwareModuleType", SoftwareModuleType);
	Filter.Insert("SoftwareModuleID", SoftwareModuleID);
	Filter.Insert("Operation", Operation);
	
	Rows = AdministrationOperations.FindRows(Filter);
	
	If Rows.Count() = 0 Then
		
		String = AdministrationOperations.Add();
		FillPropertyValues(String, Filter);
		String.Name = Name;
		
	EndIf;
	
EndProcedure

// Adds properties of a permission request to use external resources to the requests use plan.
//
// Parameters:
//  SoftwareModuleType - CatalogRef.MetadataObjectIDs,
//  SoftwareModuleIdentifier - UUID,
//  OwnerType - CatalogRef.MetadataObjectIDs,
//  OwnerID - UUID,
//  ReplacementMode - Boolean,
//  AddedPermissions - Array(XDTOObject) or Undefined,
//  DeletedPermissions - Array (XDTOObject) or Undefined.
//
Procedure AddRequestForExternalResourcesUsePermissions(
		Val SoftwareModuleType, Val SoftwareModuleID,
		Val OwnerType, Val IDOwner,
		Val ReplacementMode,
		Val PermissionsToBeAdded = Undefined,
		Val PermissionsToBeDeleted = Undefined) Export
	
	Filter = New Structure();
	Filter.Insert("SoftwareModuleType", SoftwareModuleType);
	Filter.Insert("SoftwareModuleID", SoftwareModuleID);
	
	String = DataProcessors.PermissionSettingsForExternalResourcesUse.PermissionsTableRow(
		AdministrationOperations, Filter, False);
	
	If String = Undefined Then
		
		If SoftwareModuleType = Catalogs.MetadataObjectIDs.EmptyRef() Then
			
			Name = Constants.InfobaseSecurityProfile.Get();
			
		Else
			
			Name = InformationRegisters.ExternalModulesConnectionModes.ExternalModuleConnectionMode(
				WorkInSafeModeService.RefFromPermissionsRegister(
					SoftwareModuleType, SoftwareModuleID
				)
			);
			
		EndIf;
		
		AddAdministrationOperation(
			SoftwareModuleType,
			SoftwareModuleID,
			Enums.OperationsAdministrationSecurityProfiles.Update,
			Name);
		
	Else
		
		Name = String.Name;
		
	EndIf;
	
	If ReplacementMode Then
		
		Filter = New Structure();
		Filter.Insert("SoftwareModuleType", SoftwareModuleType);
		Filter.Insert("SoftwareModuleID", SoftwareModuleID);
		Filter.Insert("OwnerType", OwnerType);
		Filter.Insert("IDOwner", IDOwner);
		
		ReplacementRow = DataProcessors.PermissionSettingsForExternalResourcesUse.PermissionsTableRow(
			RequestUsePlan.Replaced, Filter);
		
	EndIf;
	
	If PermissionsToBeAdded <> Undefined Then
		
		For Each AddedPermission IN PermissionsToBeAdded Do
			
			Filter = New Structure();
			Filter.Insert("SoftwareModuleType", SoftwareModuleType);
			Filter.Insert("SoftwareModuleID", SoftwareModuleID);
			Filter.Insert("OwnerType", OwnerType);
			Filter.Insert("IDOwner", IDOwner);
			Filter.Insert("Type", AddedPermission.Type().Name);
			
			String = DataProcessors.PermissionSettingsForExternalResourcesUse.PermissionsTableRow(
				RequestUsePlan.Adding, Filter);
			
			AuthorizationKey = InformationRegisters.ExternalResourcesUsingPermissions.AuthorizationKey(AddedPermission);
			AuthorizationAdding = InformationRegisters.ExternalResourcesUsingPermissions.AuthorizationAdding(AddedPermission);
			
			String.permissions.Insert(AuthorizationKey, CommonUse.ObjectXDTOInXMLString(AddedPermission));
			
			If ValueIsFilled(AuthorizationAdding) Then
				String.PermissionsAdditions.Insert(AuthorizationKey, CommonUse.ValueToXMLString(AuthorizationAdding));
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If PermissionsToBeDeleted <> Undefined Then
		
		For Each DeletedPermission IN PermissionsToBeDeleted Do
			
			Filter = New Structure();
			Filter.Insert("SoftwareModuleType", SoftwareModuleType);
			Filter.Insert("SoftwareModuleID", SoftwareModuleID);
			Filter.Insert("OwnerType", OwnerType);
			Filter.Insert("IDOwner", IDOwner);
			Filter.Insert("Type", AddedPermission.Type().Name);
			
			String = DataProcessors.PermissionSettingsForExternalResourcesUse.PermissionsTableRow(
				RequestUsePlan.ToDelete, Filter);
			
			AuthorizationKey = InformationRegisters.ExternalResourcesUsingPermissions.AuthorizationKey(DeletedPermission);
			AuthorizationAdding = InformationRegisters.ExternalResourcesUsingPermissions.AuthorizationAdding(DeletedPermission);
			
			String.permissions.Add(AuthorizationKey, CommonUse.ObjectXDTOInXMLString(DeletedPermission));
			
			If ValueIsFilled(AuthorizationAdding) Then
				String.PermissionsAdditions.Insert(AuthorizationKey, CommonUse.ValueToXMLString(AuthorizationAdding));
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Adds clearing of permissions information from registers to the permissions use plan.
// Used in profiles recovery mechanism.
//
Procedure AddClearingPermissionsBeforeApplying() Export
	
	ClearingPermissionsBeforeApplying = True;
	
EndProcedure

// Calculates a result of using requests to use external resources.
//
Procedure CalculateQueriesApplication() Export
	
	ExternalTransaction = TransactionActive();
	
	If Not ExternalTransaction Then
		BeginTransaction();
	EndIf;
	
	Try
		
		DataProcessors.PermissionSettingsForExternalResourcesUse.LockGrantedPermissionsRegisters();
		
		OriginalPermissionsCutInOwnersContext = InformationRegisters.ExternalResourcesUsingPermissions.PermissionsCut();
		CalculateRequestsUseResultInOwnersContext();
		CalculateDeltaInOwnersContext();
		
		OriginalPermissionsCutWithoutOwners = InformationRegisters.ExternalResourcesUsingPermissions.PermissionsCut(False, True);
		CalculateRequestsUseResultWithoutOwners();
		CalculateDeltaWithoutOwners();
		
		If Not ExternalTransaction Then
			RollbackTransaction();
		EndIf;
		
	Except
		
		If Not ExternalTransaction Then
			RollbackTransaction();
		EndIf;
		
		Raise;
		
	EndTry;
	
	If PermissionsApplicationRequiredOnServerCluster() Then
		
		Try
			LockDataForEdit(Semaphore());
		Except
			Raise NStr("en='An error occurred when trying to access the settings of permissions to use external resources by a competitor."
"Try to perform the operation later.';ru='Ошибка конкурентного доступа к настройке разрешений на использование внешних ресурсов."
"Попробуйте выполнить операцию позже.'");
		EndTry;
		
	EndIf;
	
EndProcedure

// Calculates a request use result with owners.
//
Procedure CalculateRequestsUseResultInOwnersContext()
	
	RequestsUseResultInOwnersContext = New ValueTable();
	
	For Each SourceColumn IN OriginalPermissionsCutInOwnersContext.Columns Do
		RequestsUseResultInOwnersContext.Columns.Add(SourceColumn.Name, SourceColumn.ValueType);
	EndDo;
	
	For Each SourceLine IN OriginalPermissionsCutInOwnersContext Do
		NewRow = RequestsUseResultInOwnersContext.Add();
		FillPropertyValues(NewRow, SourceLine);
	EndDo;
	
	// Apply plan
	
	// Replacing
	For Each ReplacementTableRow IN RequestUsePlan.Replaced Do
		
		Filter = New Structure();
		Filter.Insert("SoftwareModuleType", ReplacementTableRow.SoftwareModuleType);
		Filter.Insert("SoftwareModuleID", ReplacementTableRow.SoftwareModuleID);
		Filter.Insert("OwnerType", ReplacementTableRow.OwnerType);
		Filter.Insert("IDOwner", ReplacementTableRow.IDOwner);
		
		Rows = RequestsUseResultInOwnersContext.FindRows(Filter);
		
		For Each String IN Rows Do
			RequestsUseResultInOwnersContext.Delete(String);
		EndDo;
		
	EndDo;
	
	// Add permissions
	For Each RowAdded IN RequestUsePlan.Adding Do
		
		Filter = New Structure();
		Filter.Insert("SoftwareModuleType", RowAdded.SoftwareModuleType);
		Filter.Insert("SoftwareModuleID", RowAdded.SoftwareModuleID);
		Filter.Insert("OwnerType", RowAdded.OwnerType);
		Filter.Insert("IDOwner", RowAdded.IDOwner);
		Filter.Insert("Type", RowAdded.Type);
		
		String = DataProcessors.PermissionSettingsForExternalResourcesUse.PermissionsTableRow(
			RequestsUseResultInOwnersContext, Filter);
		
		For Each KeyAndValue IN RowAdded.permissions Do
			
			String.permissions.Insert(KeyAndValue.Key, KeyAndValue.Value);
			
			If RowAdded.PermissionsAdditions.Get(KeyAndValue.Key) <> Undefined Then
				String.PermissionsAdditions.Insert(KeyAndValue.Key, RowAdded.PermissionsAdditions.Get(KeyAndValue.Key));
			EndIf;
			
		EndDo;
		
	EndDo;
	
	// Delete permissions
	For Each DeletedRow IN RequestUsePlan.ToDelete Do
		
		Filter = New Structure();
		Filter.Insert("SoftwareModuleType", DeletedRow.SoftwareModuleType);
		Filter.Insert("SoftwareModuleID", DeletedRow.SoftwareModuleID);
		Filter.Insert("OwnerType", DeletedRow.OwnerType);
		Filter.Insert("IDOwner", DeletedRow.IDOwner);
		Filter.Insert("Type", DeletedRow.Type);
		
		String = DataProcessors.PermissionSettingsForExternalResourcesUse.PermissionsTableRow(
			RequestsUseResultInOwnersContext, Filter);
		
		For Each KeyAndValue IN DeletedRow.permissions Do
			
			String.permissions.Delete(KeyAndValue.Key);
			
			If DeletedRow.PermissionsAdditions.Get(KeyAndValue.Key) <> Undefined Then
				
				String.PermissionsAdditions.Insert(KeyAndValue.Key, DeletedRow.PermissionsAdditions.Get(KeyAndValue.Key));
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Calculates a request use result without owners.
//
Procedure CalculateRequestsUseResultWithoutOwners()
	
	RequestsUseResultWithoutOwners = New ValueTable();
	
	For Each SourceColumn IN OriginalPermissionsCutWithoutOwners.Columns Do
		RequestsUseResultWithoutOwners.Columns.Add(SourceColumn.Name, SourceColumn.ValueType);
	EndDo;
	
	For Each ResultRow IN RequestsUseResultInOwnersContext Do
		
		Filter = New Structure();
		Filter.Insert("SoftwareModuleType", ResultRow.SoftwareModuleType);
		Filter.Insert("SoftwareModuleID", ResultRow.SoftwareModuleID);
		Filter.Insert("Type", ResultRow.Type);
		
		String = DataProcessors.PermissionSettingsForExternalResourcesUse.PermissionsTableRow(
			RequestsUseResultWithoutOwners, Filter);
		
		For Each KeyAndValue IN ResultRow.permissions Do
			
			OriginalPermission = CommonUse.ObjectXDTOFromXMLRow(KeyAndValue.Value);
			OriginalPermission.Description = ""; // Descriptions should not influence hash sums for options without owners.
			
			AuthorizationKey = InformationRegisters.ExternalResourcesUsingPermissions.AuthorizationKey(OriginalPermission);
			
			Resolution = String.permissions.Get(AuthorizationKey);
			
			If Resolution = Undefined Then
				
				If ResultRow.Type = "FileSystemAccess" Then
					
					// For permissions to use a file system
					// directory, search for attached and inclusive permissions.
					
					If OriginalPermission.AllowedRead Then
						
						If OriginalPermission.AllowedWrite Then
							
							// Searches for a permission to use the same directory but read-only.
							
							PermissionCopy = CommonUse.ObjectXDTOFromXMLRow(CommonUse.ObjectXDTOInXMLString(OriginalPermission));
							PermissionCopy.AllowedWrite = False;
							CopyKey = InformationRegisters.ExternalResourcesUsingPermissions.AuthorizationKey(PermissionCopy);
							
							AttachedPermission = String.permissions.Get(CopyKey);
							
							If AttachedPermission <> Undefined Then
								
								// Delete the attached permission, it is not required after the current one has been added.
								String.permissions.Delete(CopyKey);
								
							EndIf;
							
						Else
							
							// Searches a permission to use the same directory but including and to write.
							
							PermissionCopy = CommonUse.ObjectXDTOFromXMLRow(CommonUse.ObjectXDTOInXMLString(OriginalPermission));
							PermissionCopy.AllowedWrite = True;
							CopyKey = InformationRegisters.ExternalResourcesUsingPermissions.AuthorizationKey(PermissionCopy);
							
							InclusivePermission = String.permissions.Get(CopyKey);
							
							If InclusivePermission <> Undefined Then
								
								// It is not required to process this permission as the directory will be permitted using the inclusive one.
								Continue;
								
							EndIf;
							
						EndIf;
						
					EndIf;
					
				EndIf;
				
				String.permissions.Insert(AuthorizationKey, CommonUse.ObjectXDTOInXMLString(OriginalPermission));
				
				Supplement = ResultRow.PermissionsAdditions.Get(KeyAndValue.Key);
				If Supplement <> Undefined Then
					String.PermissionsAdditions.Insert(AuthorizationKey, Supplement);
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Calculates delta of two permissions cuts with permissions owners.
//
Procedure CalculateDeltaInOwnersContext()
	
	DeltaInOwnersContext = New Structure();
	
	DeltaInOwnersContext.Insert("Adding", New ValueTable);
	DeltaInOwnersContext.Adding.Columns.Add("SoftwareModuleType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	DeltaInOwnersContext.Adding.Columns.Add("SoftwareModuleID", New TypeDescription("UUID"));
	DeltaInOwnersContext.Adding.Columns.Add("OwnerType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	DeltaInOwnersContext.Adding.Columns.Add("IDOwner", New TypeDescription("UUID"));
	DeltaInOwnersContext.Adding.Columns.Add("Type", New TypeDescription("String"));
	DeltaInOwnersContext.Adding.Columns.Add("permissions", New TypeDescription("Map"));
	DeltaInOwnersContext.Adding.Columns.Add("PermissionsAdditions", New TypeDescription("Map"));
	
	DeltaInOwnersContext.Insert("ToDelete", New ValueTable);
	DeltaInOwnersContext.ToDelete.Columns.Add("SoftwareModuleType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	DeltaInOwnersContext.ToDelete.Columns.Add("SoftwareModuleID", New TypeDescription("UUID"));
	DeltaInOwnersContext.ToDelete.Columns.Add("OwnerType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	DeltaInOwnersContext.ToDelete.Columns.Add("IDOwner", New TypeDescription("UUID"));
	DeltaInOwnersContext.ToDelete.Columns.Add("Type", New TypeDescription("String"));
	DeltaInOwnersContext.ToDelete.Columns.Add("permissions", New TypeDescription("Map"));
	DeltaInOwnersContext.ToDelete.Columns.Add("PermissionsAdditions", New TypeDescription("Map"));
	
	// Compare source permissions to the result ones.
	
	For Each String IN OriginalPermissionsCutInOwnersContext Do
		
		Filter = New Structure();
		Filter.Insert("SoftwareModuleType", String.SoftwareModuleType);
		Filter.Insert("SoftwareModuleID", String.SoftwareModuleID);
		Filter.Insert("OwnerType", String.OwnerType);
		Filter.Insert("IDOwner", String.IDOwner);
		Filter.Insert("Type", String.Type);
		
		Rows = RequestsUseResultInOwnersContext.FindRows(Filter);
		If Rows.Count() > 0 Then
			ResultRow = Rows.Get(0);
		Else
			ResultRow = Undefined;
		EndIf;
		
		For Each KeyAndValue IN String.permissions Do
			
			If ResultRow = Undefined Or ResultRow.permissions.Get(KeyAndValue.Key) = Undefined Then
				
				// The permission existed in the source ones but does not exist in the resulting ones - it is the permission being deleted.
				
				DeletedRow = DataProcessors.PermissionSettingsForExternalResourcesUse.PermissionsTableRow(
					DeltaInOwnersContext.ToDelete, Filter);
				
				If DeletedRow.permissions.Get(KeyAndValue.Key) = Undefined Then
					
					DeletedRow.permissions.Insert(KeyAndValue.Key, KeyAndValue.Value);
					
					If String.PermissionsAdditions.Get(KeyAndValue.Key) <> Undefined Then
						DeletedRow.PermissionsAdditions.Insert(KeyAndValue.Key, String.PermissionsAdditions.Get(KeyAndValue.Key));
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	// Compare result permissions to the source ones.
	
	For Each String IN RequestsUseResultInOwnersContext Do
		
		Filter = New Structure();
		Filter.Insert("SoftwareModuleType", String.SoftwareModuleType);
		Filter.Insert("SoftwareModuleID", String.SoftwareModuleID);
		Filter.Insert("OwnerType", String.OwnerType);
		Filter.Insert("IDOwner", String.IDOwner);
		Filter.Insert("Type", String.Type);
		
		Rows = OriginalPermissionsCutInOwnersContext.FindRows(Filter);
		If Rows.Count() > 0 Then
			SourceLine = Rows.Get(0);
		Else
			SourceLine = Undefined;
		EndIf;
		
		For Each KeyAndValue IN String.permissions Do
			
			If SourceLine = Undefined OR SourceLine.permissions.Get(KeyAndValue.Key) = Undefined Then
				
				// Permission exists in results but does not exist in source - permission being added.
				
				RowAdded = DataProcessors.PermissionSettingsForExternalResourcesUse.PermissionsTableRow(
					DeltaInOwnersContext.Adding, Filter);
				
				If RowAdded.permissions.Get(KeyAndValue.Key) = Undefined Then
					
					RowAdded.permissions.Insert(KeyAndValue.Key, KeyAndValue.Value);
					
					If String.PermissionsAdditions.Get(KeyAndValue.Key) <> Undefined Then
						RowAdded.PermissionsAdditions.Insert(KeyAndValue.Key, String.PermissionsAdditions.Get(KeyAndValue.Key));
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Calculates delta of two permissions cuts without permissions owners.
//
Procedure CalculateDeltaWithoutOwners()
	
	DeltaNotIncludingOwners = New Structure();
	
	DeltaNotIncludingOwners.Insert("Adding", New ValueTable);
	DeltaNotIncludingOwners.Adding.Columns.Add("SoftwareModuleType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	DeltaNotIncludingOwners.Adding.Columns.Add("SoftwareModuleID", New TypeDescription("UUID"));
	DeltaNotIncludingOwners.Adding.Columns.Add("Type", New TypeDescription("String"));
	DeltaNotIncludingOwners.Adding.Columns.Add("permissions", New TypeDescription("Map"));
	DeltaNotIncludingOwners.Adding.Columns.Add("PermissionsAdditions", New TypeDescription("Map"));
	
	DeltaNotIncludingOwners.Insert("ToDelete", New ValueTable);
	DeltaNotIncludingOwners.ToDelete.Columns.Add("SoftwareModuleType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	DeltaNotIncludingOwners.ToDelete.Columns.Add("SoftwareModuleID", New TypeDescription("UUID"));
	DeltaNotIncludingOwners.ToDelete.Columns.Add("Type", New TypeDescription("String"));
	DeltaNotIncludingOwners.ToDelete.Columns.Add("permissions", New TypeDescription("Map"));
	DeltaNotIncludingOwners.ToDelete.Columns.Add("PermissionsAdditions", New TypeDescription("Map"));
	
	// Compare source permissions to the result ones.
	
	For Each String IN OriginalPermissionsCutWithoutOwners Do
		
		Filter = New Structure();
		Filter.Insert("SoftwareModuleType", String.SoftwareModuleType);
		Filter.Insert("SoftwareModuleID", String.SoftwareModuleID);
		Filter.Insert("Type", String.Type);
		
		Rows = RequestsUseResultWithoutOwners.FindRows(Filter);
		If Rows.Count() > 0 Then
			ResultRow = Rows.Get(0);
		Else
			ResultRow = Undefined;
		EndIf;
		
		For Each KeyAndValue IN String.permissions Do
			
			If ResultRow = Undefined OR ResultRow.permissions.Get(KeyAndValue.Key) = Undefined Then
				
				// The permission existed in the source ones but does not exist in the result ones. - permission being deleted.
				
				DeletedRow = DataProcessors.PermissionSettingsForExternalResourcesUse.PermissionsTableRow(
					DeltaNotIncludingOwners.ToDelete, Filter);
				
				If DeletedRow.permissions.Get(KeyAndValue.Key) = Undefined Then
					
					DeletedRow.permissions.Insert(KeyAndValue.Key, KeyAndValue.Value);
					
					If String.PermissionsAdditions.Get(KeyAndValue.Key) <> Undefined Then
						DeletedRow.PermissionsAdditions.Insert(KeyAndValue.Key, String.PermissionsAdditions.Get(KeyAndValue.Key));
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	// Compare result permissions to the source ones.
	
	For Each String IN RequestsUseResultWithoutOwners Do
		
		Filter = New Structure();
		Filter.Insert("SoftwareModuleType", String.SoftwareModuleType);
		Filter.Insert("SoftwareModuleID", String.SoftwareModuleID);
		Filter.Insert("Type", String.Type);
		
		Rows = OriginalPermissionsCutWithoutOwners.FindRows(Filter);
		If Rows.Count() > 0 Then
			SourceLine = Rows.Get(0);
		Else
			SourceLine = Undefined;
		EndIf;
		
		For Each KeyAndValue IN String.permissions Do
			
			If SourceLine = Undefined OR SourceLine.permissions.Get(KeyAndValue.Key) = Undefined Then
				
				// Permission exists in results but does not exist in source - permission being added.
				
				RowAdded = DataProcessors.PermissionSettingsForExternalResourcesUse.PermissionsTableRow(
					DeltaNotIncludingOwners.Adding, Filter);
				
				If RowAdded.permissions.Get(KeyAndValue.Key) = Undefined Then
					
					RowAdded.permissions.Insert(KeyAndValue.Key, KeyAndValue.Value);
					
					If String.PermissionsAdditions.Get(KeyAndValue.Key) <> Undefined Then
						RowAdded.PermissionsAdditions.Insert(KeyAndValue.Key, String.PermissionsAdditions.Get(KeyAndValue.Key));
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Checks whether it is required to use permissions the servers cluster.
//
// Return value: Boolean.
//
Function PermissionsApplicationRequiredOnServerCluster() Export
	
	If DeltaNotIncludingOwners.Adding.Count() > 0 Then
		Return True;
	EndIf;
	
	If DeltaNotIncludingOwners.ToDelete.Count() > 0 Then
		Return True;
	EndIf;
	
	For Each AdministrationOperation IN AdministrationOperations Do
		If AdministrationOperation.Operation = Enums.OperationsAdministrationSecurityProfiles.Delete Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// Checks whether permissions are to be written to registers.
//
// Return value: Boolean.
//
Function RequirePermissionsWriteToRegister() Export
	
	If DeltaInOwnersContext.Adding.Count() > 0 Then
		Return True;
	EndIf;
	
	If DeltaInOwnersContext.ToDelete.Count() > 0 Then
		Return True;
	EndIf;
	
	For Each AdministrationOperation IN AdministrationOperations Do
		If AdministrationOperation.Operation = Enums.OperationsAdministrationSecurityProfiles.Delete Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// Returns a presentation of permissions to use external resources.
//
// Parameters:
//  AsRequired - Boolean - the presentation is generated as a list of permissions
//    not as a list of operations when changing permissions.
//
// Return value: SpreadSheet.
//
Function Presentation(Val AsRequired = False) Export
	
	Return Reports.UsedExternalResources.PresentationRequestsPermissionsToUseExternalResources(
		AdministrationOperations,
		DeltaNotIncludingOwners.Adding,
		DeltaNotIncludingOwners.ToDelete,
		AsRequired);
	
EndFunction

// Returns a scenario of permissions requests to use external resources.
//
// Return value: Array(Structure), structure fields:
//                        * Operation - EnumRef.OperationsAdministrationSecurityProfiles,
//                        * Profile - String - security proattachment file name, 
//                        * Permissions - Structure - see
//                                                   ClusterAdministrationClientServer.SecurityProfileProperties().
//
Function UseScenario() Export
	
	Result = New Array();
	
	For Each Description IN AdministrationOperations Do
		
		ResultItem = New Structure("Operation,Profile,permissions");
		ResultItem.Operation = Description.Operation;
		ResultItem.Profile = Description.Name;
		ResultItem.permissions = ProfileInClusterAdministrationInterfaceNotation(ResultItem.Profile, Description.SoftwareModuleType, Description.SoftwareModuleID);
		
		ConfigurationProfile = (Description.SoftwareModuleType = Catalogs.MetadataObjectIDs.EmptyRef());
		
		If ConfigurationProfile Then
			
			AdditionalOperationPriority = False;
			
			If Description.Operation = Enums.OperationsAdministrationSecurityProfiles.Creating Then
				AdditionalOperation = Enums.OperationsAdministrationSecurityProfiles.Purpose;
			EndIf;
			
			If Description.Operation = Enums.OperationsAdministrationSecurityProfiles.Delete Then
				AdditionalOperation = Enums.OperationsAdministrationSecurityProfiles.DeleteDestination;
				AdditionalOperationPriority = True;
			EndIf;
			
			AdditionalItem = New Structure("Operation,Profile,permissions", AdditionalOperation, Description.Name);
			
		EndIf;
		
		If ConfigurationProfile AND AdditionalOperationPriority Then
			
			Result.Add(AdditionalItem);
			
		EndIf;
		
		Result.Add(ResultItem);
		
		If ConfigurationProfile AND Not AdditionalOperationPriority Then
			
			Result.Add(AdditionalItem);
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Generates a security proattachment description in notation
// of application interface of servers cluster administration.
//
// Parameters:
//  ProfileName - String - security proattachment file name, 
//  ProgramModuleType - CatalogRef.MetadataObjectIDs,
//  SoftwareModuleIdentifier - UUID
//
// Return value: Structure - see ClusterAdministrationClientServer.SecurityProfileProperties().
//
Function ProfileInClusterAdministrationInterfaceNotation(Val ProfileName, Val SoftwareModuleType, Val SoftwareModuleID)
	
	Profile = ClusterAdministrationClientServer.SecurityProfileProperties();
	Profile.Name = ProfileName;
	Profile.Description = NewSecurityProfileDescription(SoftwareModuleType, SoftwareModuleID);
	Profile.ProfileOfSafeMode = True;
	
	Profile.FullAccessToFileSystem = False;
	Profile.COMObjectsFullAccess = False;
	Profile.FullAccessToExternalComponents = False;
	Profile.FullAccessToExternalModules = False;
	Profile.FullAccessToOperatingSystemApplications = False;
	Profile.FullAccessToInternetResources = False;
	
	Profile.FullAccessToPrivilegedMode = False;
	
	Filter = New Structure();
	Filter.Insert("SoftwareModuleType", SoftwareModuleType);
	Filter.Insert("SoftwareModuleID", SoftwareModuleID);
	
	Rows = RequestsUseResultWithoutOwners.FindRows(Filter);
	
	For Each String IN Rows Do
		
		For Each KeyAndValue IN String.permissions Do
			
			Resolution = CommonUse.ObjectXDTOFromXMLRow(KeyAndValue.Value);
			
			If String.Type = "FileSystemAccess" Then
				
				If StandardVirtualDirectories().Get(Resolution.Path) <> Undefined Then
					
					VirtualDirectory = ClusterAdministrationClientServer.VirtualDirectoryProperties();
					VirtualDirectory.LogicalURL = Resolution.Path;
					VirtualDirectory.PhysicalURL = StandardVirtualDirectories().Get(Resolution.Path);
					VirtualDirectory.DataReading = Resolution.AllowedRead;
					VirtualDirectory.DataRecording = Resolution.AllowedWrite;
					VirtualDirectory.Description = Resolution.Description;
					Profile.VirtualDirectories.Add(VirtualDirectory);
					
				Else
					
					VirtualDirectory = ClusterAdministrationClientServer.VirtualDirectoryProperties();
					VirtualDirectory.LogicalURL = Resolution.Path;
					VirtualDirectory.PhysicalURL = ShieldPercentChar(Resolution.Path);
					VirtualDirectory.DataReading = Resolution.AllowedRead;
					VirtualDirectory.DataRecording = Resolution.AllowedWrite;
					VirtualDirectory.Description = Resolution.Description;
					Profile.VirtualDirectories.Add(VirtualDirectory);
					
				EndIf;
				
			ElsIf String.Type = "CreateComObject" Then
				
				COMClass = ClusterAdministrationClientServer.COMClassProperties();
				COMClass.Name = Resolution.ProgId;
				COMClass.CLSID = Resolution.CLSID;
				COMClass.Computer = Resolution.ComputerName;
				COMClass.Description = Resolution.Description;
				Profile.COMClasses.Add(COMClass);
				
			ElsIf String.Type = "AttachAddin" Then
				
				Supplement = CommonUse.ValueFromXMLString(String.PermissionsAdditions.Get(KeyAndValue.Key));
				For Each AdditionKeyAndValue IN Supplement Do
					
					ExternalComponent = ClusterAdministrationClientServer.ExternalComponentProperties();
					ExternalComponent.Name = Resolution.TemplateName + "\" + AdditionKeyAndValue.Key;
					ExternalComponent.HashSum = AdditionKeyAndValue.Value;
					ExternalComponent.Description = Resolution.Description;
					Profile.ExternalComponents.Add(ExternalComponent);
					
				EndDo;
				
			ElsIf String.Type = "RunApplication" Then
				
				OSApplication = ClusterAdministrationClientServer.OSApplicationsProperties();
				OSApplication.Name = Resolution.MaskCommand;
				OSApplication.TemplateLaunchRows = Resolution.MaskCommand;
				OSApplication.Description = Resolution.Description;
				Profile.OSApplications.Add(OSApplication);
				
			ElsIf String.Type = "InternetResourceAccess" Then
				
				InternetResource = ClusterAdministrationClientServer.PropertiesInternetResource();
				InternetResource.Name = Lower(Resolution.Protocol) + "://" + Lower(Resolution.Host) + ":" + Resolution.Port;
				InternetResource.Protocol = Resolution.Protocol;
				InternetResource.Address = Resolution.Host;
				InternetResource.Port = Resolution.Port;
				InternetResource.Description = Resolution.Description;
				Profile.InternetResources.Add(InternetResource);
				
			ElsIf String.Type = "ExternalModulePrivilegedModeAllowed" Then
				
				Profile.FullAccessToPrivilegedMode = True;
				
			EndIf;
			
			
		EndDo;
		
	EndDo;
	
	Return Profile;
	
EndFunction

// Creates description of a security profile for the info base or external module.
//
// Parameters:
//  ExternalModule - AnyRef - ref to a catalog
//    item used as an external module.
//
// Returns: 
//   String - security proattachment description.
//
Function NewSecurityProfileDescription(Val SoftwareModuleType, Val SoftwareModuleID) Export
	
	Pattern = NStr("en='[Infobase %1] %2 ""%3""';ru='[Infobase %1] %2 ""%3""'");
	
	InfobaseName = "";
	ConnectionString = InfobaseConnectionString();
	Substrings = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(ConnectionString, ";");
	For Each Substring IN Substrings Do
		If Left(Substring, 3) = "Ref" Then
			InfobaseName = StrReplace(Right(Substring, StrLen(Substring) - 4), """", "");
		EndIf;
	EndDo;
	If IsBlankString(InfobaseName) Then
		Raise NStr("en='Infobase connection row does not contain the infobase name.';ru='Строка соединения информационной базы не содержит имени информационной базы!'");
	EndIf;
	
	If SoftwareModuleType = Catalogs.MetadataObjectIDs.EmptyRef() Then
		Return StringFunctionsClientServer.PlaceParametersIntoString(Pattern, InfobaseName,
			NStr("en='Security profile for the infobase';ru='Профиль безопасности для информационной базы'"), InfobaseConnectionString());
	Else
		ProgramModule = WorkInSafeModeService.RefFromPermissionsRegister(SoftwareModuleType, SoftwareModuleID);
		Dictionary = WorkInSafeModeService.ExternalModuleManager(ProgramModule).ExternalModuleContainerDictionary();
		ModuleName = CommonUse.ObjectAttributeValue(ProgramModule, "Description");
		Return StringFunctionsClientServer.PlaceParametersIntoString(Pattern, InfobaseName, Dictionary.Nominative, ModuleName);
	EndIf;
	
EndFunction

// Returns physical paths of standard virtual directories.
//
// Returns - Map:
//                         * Key - String - alias of a virtual directory,
//                         * Value - String - physical path.
//
Function StandardVirtualDirectories()
	
	Result = New Map();
	
	Result.Insert("/temp", "%t/%r/%s/%p");
	Result.Insert("/bin", "%e");
	
	Return Result;
	
EndFunction

// Shields a percentage character in a physical path of the virtual directory.
//
// Parameters:
//  SourceLine - String - initial physical path of a virtual directory.
//
// Return value: String.
//
Function ShieldPercentChar(Val SourceLine)
	
	Return StrReplace(SourceLine, "%", "%%");
	
EndFunction

// Serializes internal state object.
//
// Returns - String.
//
Function WriteStatusInXMLString() Export
	
	Status = New Structure();
	
	Status.Insert("OriginalPermissionsCutInOwnersContext", OriginalPermissionsCutInOwnersContext);
	Status.Insert("RequestsUseResultInOwnersContext", RequestsUseResultInOwnersContext);
	Status.Insert("DeltaInOwnersContext", DeltaInOwnersContext);
	Status.Insert("OriginalPermissionsCutWithoutOwners", OriginalPermissionsCutWithoutOwners);
	Status.Insert("RequestsUseResultWithoutOwners", RequestsUseResultWithoutOwners);
	Status.Insert("DeltaNotIncludingOwners", DeltaNotIncludingOwners);
	Status.Insert("AdministrationOperations", AdministrationOperations);
	Status.Insert("QueryIDs", QueryIDs);
	Status.Insert("ClearingPermissionsBeforeApplying", ClearingPermissionsBeforeApplying);
	
	Return CommonUse.ValueToXMLString(Status);
	
EndFunction

// Deserializes internal state object.
//
// Parameters:
//  XMLString - String - result returned by function WriteStateToXMLString().
//
Procedure ReadStatusFromXMLRow(Val XMLString) Export
	
	Status = CommonUse.ValueFromXMLString(XMLString);
	
	OriginalPermissionsCutInOwnersContext = Status.OriginalPermissionsCutInOwnersContext;
	RequestsUseResultInOwnersContext = Status.RequestsUseResultInOwnersContext;
	DeltaInOwnersContext = Status.DeltaInOwnersContext;
	OriginalPermissionsCutWithoutOwners = Status.OriginalPermissionsCutWithoutOwners;
	RequestsUseResultWithoutOwners = Status.RequestsUseResultWithoutOwners;
	DeltaNotIncludingOwners = Status.DeltaNotIncludingOwners;
	AdministrationOperations = Status.AdministrationOperations;
	QueryIDs = Status.QueryIDs;
	ClearingPermissionsBeforeApplying = Status.ClearingPermissionsBeforeApplying;
	
EndProcedure

// Writes a request to use external resources to the IB.
//
Procedure FinishRequestsApplicationOnExternalResourcesUse() Export
	
	BeginTransaction();
	
	Try
		
		If RequirePermissionsWriteToRegister() Then
			
			If ClearingPermissionsBeforeApplying Then
				
				DataProcessors.PermissionSettingsForExternalResourcesUse.ClearGivenPermissions(, False);
				
			EndIf;
			
			For Each ToDelete IN DeltaInOwnersContext.ToDelete Do
				
				For Each KeyAndValue IN ToDelete.permissions Do
					
					InformationRegisters.ExternalResourcesUsingPermissions.DeletePermission(
						ToDelete.SoftwareModuleType,
						ToDelete.SoftwareModuleID,
						ToDelete.OwnerType,
						ToDelete.IDOwner,
						KeyAndValue.Key,
						CommonUse.ObjectXDTOFromXMLRow(KeyAndValue.Value));
					
				EndDo;
				
			EndDo;
			
			For Each Adding IN DeltaInOwnersContext.Adding Do
				
				For Each KeyAndValue IN Adding.permissions Do
					
					Supplement = Adding.PermissionsAdditions.Get(KeyAndValue.Key);
					If Supplement <> Undefined Then
						Supplement = CommonUse.ValueFromXMLString(Supplement);
					EndIf;
					
					InformationRegisters.ExternalResourcesUsingPermissions.AddPermission(
						Adding.SoftwareModuleType,
						Adding.SoftwareModuleID,
						Adding.OwnerType,
						Adding.IDOwner,
						KeyAndValue.Key,
						CommonUse.ObjectXDTOFromXMLRow(KeyAndValue.Value),
						Supplement);
					
				EndDo;
				
			EndDo;
			
			For Each Description IN AdministrationOperations Do
				
				ConfigurationProfile = (Description.SoftwareModuleType = Catalogs.MetadataObjectIDs.EmptyRef());
				
				If Description.Operation = Enums.OperationsAdministrationSecurityProfiles.Creating Then
					
					If ConfigurationProfile Then
						
						Constants.InfobaseSecurityProfile.Set(Description.Name);
						
					Else
						
						Manager = InformationRegisters.ExternalModulesConnectionModes.CreateRecordManager();
						Manager.SoftwareModuleType = Description.SoftwareModuleType;
						Manager.SoftwareModuleID = Description.SoftwareModuleID;
						Manager.SafeMode = Description.Name;
						Manager.Write();
						
					EndIf;
					
				EndIf;
				
				If Description.Operation = Enums.OperationsAdministrationSecurityProfiles.Delete Then
					
					If ConfigurationProfile Then
						
						Constants.InfobaseSecurityProfile.Set("");
						DataProcessors.PermissionSettingsForExternalResourcesUse.ClearGivenPermissions();
						
					Else
						
						ProgramModule = WorkInSafeModeService.RefFromPermissionsRegister(
							Description.SoftwareModuleType, Description.SoftwareModuleID);
						DataProcessors.PermissionSettingsForExternalResourcesUse.ClearGivenPermissions(
							ProgramModule, True);
						
					EndIf;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
		InformationRegisters.PermissionQueriesOnUseExternalResources.DeleteQueries(QueryIDs);
		InformationRegisters.PermissionQueriesOnUseExternalResources.ClearIrrelevantQueries();
		
		CommitTransaction();
		
		UnlockDataForEdit(Semaphore());
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

// Returns a semaphore of requests use to use external resources.
//
// Returns - InformationRegisterRecordKey.PermissionsRequestsToUseExternalResources.
//
Function Semaphore()
	
	Key = New Structure();
	Key.Insert("IDRequest", New UUID("8e02fbd3-3f9f-4c3c-964d-7c602ad4eb38"));
	
	Return InformationRegisters.PermissionQueriesOnUseExternalResources.CreateRecordKey(Key);
	
EndFunction

#EndRegion

#Region ObjectInitialization

QueryIDs = New Array();

RequestUsePlan = New Structure();

RequestUsePlan.Insert("Replaced", New ValueTable);
RequestUsePlan.Replaced.Columns.Add("SoftwareModuleType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
RequestUsePlan.Replaced.Columns.Add("SoftwareModuleID", New TypeDescription("UUID"));
RequestUsePlan.Replaced.Columns.Add("OwnerType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
RequestUsePlan.Replaced.Columns.Add("IDOwner", New TypeDescription("UUID"));

RequestUsePlan.Insert("Adding", New ValueTable);
RequestUsePlan.Adding.Columns.Add("SoftwareModuleType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
RequestUsePlan.Adding.Columns.Add("SoftwareModuleID", New TypeDescription("UUID"));
RequestUsePlan.Adding.Columns.Add("OwnerType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
RequestUsePlan.Adding.Columns.Add("IDOwner", New TypeDescription("UUID"));
RequestUsePlan.Adding.Columns.Add("Type", New TypeDescription("String"));
RequestUsePlan.Adding.Columns.Add("permissions", New TypeDescription("Map"));
RequestUsePlan.Adding.Columns.Add("PermissionsAdditions", New TypeDescription("Map"));

RequestUsePlan.Insert("ToDelete", New ValueTable);
RequestUsePlan.ToDelete.Columns.Add("SoftwareModuleType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
RequestUsePlan.ToDelete.Columns.Add("SoftwareModuleID", New TypeDescription("UUID"));
RequestUsePlan.ToDelete.Columns.Add("OwnerType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
RequestUsePlan.ToDelete.Columns.Add("IDOwner", New TypeDescription("UUID"));
RequestUsePlan.ToDelete.Columns.Add("Type", New TypeDescription("String"));
RequestUsePlan.ToDelete.Columns.Add("permissions", New TypeDescription("Map"));
RequestUsePlan.ToDelete.Columns.Add("PermissionsAdditions", New TypeDescription("Map"));

AdministrationOperations = New ValueTable;
AdministrationOperations.Columns.Add("SoftwareModuleType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
AdministrationOperations.Columns.Add("SoftwareModuleID", New TypeDescription("UUID"));
AdministrationOperations.Columns.Add("Operation", New TypeDescription("EnumRef.OperationsAdministrationSecurityProfiles"));
AdministrationOperations.Columns.Add("Name", New TypeDescription("String"));

ClearingPermissionsBeforeApplying = False;

#EndRegion

#EndIf
