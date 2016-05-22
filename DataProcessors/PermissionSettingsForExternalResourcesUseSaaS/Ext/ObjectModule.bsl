#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// Subsystem "Basic functionality in service model".
// Server procedures and functions of common use:
// - Permissions management in security profiles
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalState

// Array(UUID) - array of request identifiers to
// use external resources for using which the object was initialized.
//
Var QueryIDs;

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
//      * Type - String - XDTO-type name that describes the permissions, 
//      * Permissions - Map - description of added permissions:
//         * Key - String - permission key (see the function PermissionKey in module
//             of register manager PermissionsForExternalResourcesUse),
//         * Value - XDTODataObject - XDTO description of the added permission, 
//  * Deleted - ValueTable - operation to delete permissions to use external resources:
//      * SoftwareModuleType - CatalogRef.MetadataObjectsIdentifiers,
//      * SoftwareModuleIdentifier - UUID,
//      * OwnerType - CatalogRef.MetaDataObjectsIdentifiers,
//      * OwnerIdentifier - UUID,
//      * Type - String - XDTO-type name that describes the permissions, 
//      * Permissions - Map - description of permissions being deleted:
//         * Key - String - permission key (see the function PermissionKey in module
//             of register manager PermissionsForExternalResourcesUse),
//         * Value - XDTODataObject - XDTO description of a permission being deleted,
//
Var RequestUsePlan;

// Values table - initial permissions cut (with permissions owners). Columns:
// * SoftwareModuleType - CatalogRef.MetadataObjectsIdentifiers,
// * SoftwareModuleIdentifier - UUID,
// * OwnerType - CatalogRef.MetaDataObjectsIdentifiers,
// * OwnerIdentifier - UUID,
// * Type - String - XDTO-type name that describes the permissions,
// * Permissions - Map - Permissions description:
//   * Key - String - permission key (see the function PermissionKey in module
//      of register manager PermissionsForExternalResourcesUse), 
//   * Value - XDTODataObject - XDTO description of permissions,
//
Var OriginalPermissionsCutInOwnersContext;

// Values table - initial permissions cut (without permissions owners). Columns:
// * SoftwareModuleType - CatalogRef.MetadataObjectsIdentifiers,
// * SoftwareModuleIdentifier - UUID,
// * Type - String - XDTO-type name that describes the permissions, 
// * Permissions - Map - Permissions description:
//   * Key - String - permission key (see the function PermissionKey in module
//      of register manager PermissionsForExternalResourcesUse),
//   * Value - XDTODataObject - XDTO description of permissions,
//
Var OriginalPermissionsCutWithoutOwners;

// Values table - permissions section in requests use result (with permissions owners).
// Columns:
// * SoftwareModuleType - CatalogRef.MetadataObjectsIdentifiers,
// * SoftwareModuleIdentifier - UUID,
// * OwnerType - CatalogRef.MetaDataObjectsIdentifiers,
// * OwnerIdentifier - UUID,
// * Type - String - XDTO-type name that describes the permissions, 
// * Permissions - Map - Permissions description:
//   * Key - String - permission key (see the function PermissionKey in module
//      of register manager PermissionsForExternalResourcesUse),
//    * Value - XDTODataObject - XDTO description of permissions,
//
Var RequestsUseResultInOwnersContext;

// Values table - permissions section in requests use result (with permissions owners).
// Columns:
// * SoftwareModuleType - CatalogRef.MetadataObjectsIdentifiers,
// * SoftwareModuleIdentifier - UUID,
// * Type - String - XDTO-type name that describes the permissions,
// * Permissions - Map - Permissions description:
//   * Key - String - permission key (see the function PermissionKey in module
//      of register manager PermissionsForExternalResourcesUse), 
//   * Value - XDTODataObject - XDTO description of permissions,
//
Var RequestsUseResultWithoutOwners;

// Structure - delta between the source and result permissions cuts (with permissions owners):
//  * Added - ValueTable - description of added permissions, columns:
//    * SoftwareModuleType - CatalogRef.MetadataObjectsIdentifiers,
//    * SoftwareModuleIdentifier - UUID,
//    * OwnerType - CatalogRef.MetaDataObjectsIdentifiers,
//    * OwnerIdentifier - UUID,
//    * Type - String - XDTO-type name that describes the permissions, 
//    * Permissions - Map - Permissions description:
//      * Key - String - permission key (see the function PermissionKey in module
//         of register manager PermissionsForExternalResourcesUse),
//      * Value - XDTODataObject - XDTO description of a permission, 
//  * Deleted - ValueTable - description of permissions being deleted, columns:
//    * SoftwareModuleType - CatalogRef.MetadataObjectsIdentifiers,
//    * SoftwareModuleIdentifier - UUID,
//    * OwnerType - CatalogRef.MetaDataObjectsIdentifiers,
//    * OwnerIdentifier - UUID,
//    * Type - String - XDTO-type name that describes the permissions, 
//    * Permissions - Map - Permissions description:
//      * Key - String - permission key (see the function PermissionKey in module
//         of register manager PermissionsForExternalResourcesUse), 
//      * Value - XDTODataObject - XDTO description of permissions,
//
Var DeltaInOwnersContext;

// Structure - delta between the source and result permissions cuts (without permissions owners):
//  * Added - ValueTable - description of added permissions, columns:
//    * SoftwareModuleType - CatalogRef.MetadataObjectsIdentifiers,
//    * SoftwareModuleIdentifier - UUID,
//    * Type - String - XDTO-type name that describes the permissions, 
//    * Permissions - Map - Permissions description:
//      * Key - String - permission key (see the function PermissionKey in module
//         of register manager PermissionsForExternalResourcesUse),
//      * Value - XDTODataObject - XDTO description of a permission, 
//  * Deleted - ValueTable - description of permissions being deleted, columns:
//    * SoftwareModuleType - CatalogRef.MetadataObjectsIdentifiers,
//    * SoftwareModuleIdentifier - UUID,
//    * Type - String - XDTO-type name that describes the permissions, 
//    * Permissions - Map - Permissions description:
//      * Key - String - permission key (see the function PermissionKey in module
//         of register manager PermissionsForExternalResourcesUse), 
//      * Value - XDTODataObject - XDTO description of permissions,
//
Var DeltaNotIncludingOwners;

#EndRegion

#Region ServiceProceduresAndFunctions

// Adds a request identifier in the list of processed. After successful use, requests
// which identifiers are added will be cleared.
//
// Parameters:
//  IDRequest - UUID - ID of the
//    query on external resources use.
//
Procedure AddQueryID(Val IDRequest) Export
	
	QueryIDs.Add(IDRequest);
	
EndProcedure

// Adds properties of a permission request to use external resources to the requests use plan.
//
// Parameters:
//  SoftwareModuleType - CatalogRef.MetadataObjectIDs,
//  SoftwareModuleIdentifier - UUID,
//  OwnerType - CatalogRef.MetadataObjectIDs,
//  OwnerID - UUID,
//  ReplacementMode - Boolean,
//  AddedPermissions - Array(XDTOObject)
//  or Undefined, DeletedPermissions - Array (XDTOObject) or Undefined.
//
Procedure AddRequestForExternalResourcesUsePermissions(
		Val SoftwareModuleType, Val SoftwareModuleID,
		Val OwnerType, Val IDOwner,
		Val ReplacementMode,
		Val PermissionsToBeAdded = Undefined,
		Val PermissionsToBeDeleted = Undefined) Export
	
	If ReplacementMode Then
		
		Filter = New Structure();
		Filter.Insert("SoftwareModuleType", SoftwareModuleType);
		Filter.Insert("SoftwareModuleID", SoftwareModuleID);
		Filter.Insert("OwnerType", OwnerType);
		Filter.Insert("IDOwner", IDOwner);
		
		ReplacementRow = WorkInSafeModeServiceSaaS.PermissionsTableRow(
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
			
			String = WorkInSafeModeServiceSaaS.PermissionsTableRow(
				RequestUsePlan.Adding, Filter);
			
			AuthorizationKey = WorkInSafeModeServiceSaaS.AuthorizationKey(AddedPermission);
			String.permissions.Insert(AuthorizationKey, CommonUse.ObjectXDTOInXMLString(AddedPermission));
			
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
			
			String = WorkInSafeModeServiceSaaS.PermissionsTableRow(
				RequestUsePlan.ToDelete, Filter);
			
			AuthorizationKey = WorkInSafeModeServiceSaaS.AuthorizationKey(DeletedPermission);
			String.permissions.Add(AuthorizationKey, CommonUse.ObjectXDTOInXMLString(DeletedPermission));
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Calculates a result of using requests to use external resources.
//
Procedure CalculateQueriesApplication() Export
	
	ExternalTransaction = TransactionActive();
	
	If Not ExternalTransaction Then
		BeginTransaction();
	EndIf;
	
	Try
		
		WorkInSafeModeServiceSaaS.LockGrantedPermissionsRegisters();
		
		OriginalPermissionsCutInOwnersContext = WorkInSafeModeServiceSaaS.PermissionsCut();
		CalculateRequestsUseResultInOwnersContext();
		CalculateDeltaInOwnersContext();
		
		OriginalPermissionsCutWithoutOwners = WorkInSafeModeServiceSaaS.PermissionsCut(False, True);
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
	For Each AddedRow IN RequestUsePlan.Adding Do
		
		Filter = New Structure();
		Filter.Insert("SoftwareModuleType", AddedRow.SoftwareModuleType);
		Filter.Insert("SoftwareModuleID", AddedRow.SoftwareModuleID);
		Filter.Insert("OwnerType", AddedRow.OwnerType);
		Filter.Insert("IDOwner", AddedRow.IDOwner);
		Filter.Insert("Type", AddedRow.Type);
		
		String = WorkInSafeModeServiceSaaS.PermissionsTableRow(
			RequestsUseResultInOwnersContext, Filter);
		
		For Each KeyAndValue IN AddedRow.permissions Do
			String.permissions.Insert(KeyAndValue.Key, KeyAndValue.Value);
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
		
		String = WorkInSafeModeServiceSaaS.PermissionsTableRow(
			RequestsUseResultInOwnersContext, Filter);
		
		For Each KeyAndValue IN DeletedRow.permissions Do
			String.permissions.Delete(KeyAndValue.Key);
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
		
		String = WorkInSafeModeServiceSaaS.PermissionsTableRow(
			RequestsUseResultWithoutOwners, Filter);
		
		For Each KeyAndValue IN ResultRow.permissions Do
			
			OriginalPermission = CommonUse.ObjectXDTOFromXMLRow(KeyAndValue.Value);
			OriginalPermission.Description = ""; // Description should not influence the hash amounts for an option without owners.
			
			AuthorizationKey = WorkInSafeModeServiceSaaS.AuthorizationKey(OriginalPermission);
			
			Resolution = String.permissions.Get(AuthorizationKey);
			
			If Resolution = Undefined Then
				
				If ResultRow.Type = "FileSystemAccess" Then
					
					// For permissions to use the file system
					// directory, we additionally search for attached and inclusive permissions
					
					If OriginalPermission.AllowedRead Then
						
						If OriginalPermission.AllowedWrite Then
							
							// Searches for a permission to use the same directory but read-only
							
							PermissionCopy = CommonUse.ObjectXDTOFromXMLRow(CommonUse.ObjectXDTOInXMLString(OriginalPermission));
							PermissionCopy.AllowedWrite = False;
							CopyKey = WorkInSafeModeServiceSaaS.AuthorizationKey(PermissionCopy);
							
							AttachedPermission = String.permissions.Get(CopyKey);
							
							If AttachedPermission <> Undefined Then
								
								// Delete the attached permission, it is not required after the current one has been added
								String.permissions.Delete(CopyKey);
								
							EndIf;
							
						Else
							
							// Searches a permission to use the same directory but including and to write
							
							PermissionCopy = CommonUse.ObjectXDTOFromXMLRow(CommonUse.ObjectXDTOInXMLString(OriginalPermission));
							PermissionCopy.AllowedWrite = True;
							CopyKey = WorkInSafeModeServiceSaaS.AuthorizationKey(PermissionCopy);
							
							InclusivePermission = String.permissions.Get(CopyKey);
							
							If InclusivePermission <> Undefined Then
								
								// It is not required to process this permission as the directory will be permitted using the inclusive one
								Continue;
								
							EndIf;
							
						EndIf;
						
					EndIf;
					
				EndIf;
				
				String.permissions.Insert(AuthorizationKey, CommonUse.ObjectXDTOInXMLString(OriginalPermission));
				
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
	
	DeltaInOwnersContext.Insert("ToDelete", New ValueTable);
	DeltaInOwnersContext.ToDelete.Columns.Add("SoftwareModuleType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	DeltaInOwnersContext.ToDelete.Columns.Add("SoftwareModuleID", New TypeDescription("UUID"));
	DeltaInOwnersContext.ToDelete.Columns.Add("OwnerType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	DeltaInOwnersContext.ToDelete.Columns.Add("IDOwner", New TypeDescription("UUID"));
	DeltaInOwnersContext.ToDelete.Columns.Add("Type", New TypeDescription("String"));
	DeltaInOwnersContext.ToDelete.Columns.Add("permissions", New TypeDescription("Map"));
	
	// Compare source permissions to the result ones
	
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
				
				// The permission existed in the source ones but does not exist in the result ones. - permission being deleted
				
				DeletedRow = WorkInSafeModeServiceSaaS.PermissionsTableRow(
					DeltaInOwnersContext.ToDelete, Filter);
				
				If DeletedRow.permissions.Get(KeyAndValue.Key) = Undefined Then
					DeletedRow.permissions.Insert(KeyAndValue.Key, KeyAndValue.Value);
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	// Compare result permissions to the source ones
	
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
				
				// Permission exists in results but does not exist in source - permission being added
				
				RowAdded = WorkInSafeModeServiceSaaS.PermissionsTableRow(
					DeltaInOwnersContext.Adding, Filter);
				
				If RowAdded.permissions.Get(KeyAndValue.Key) = Undefined Then
					RowAdded.permissions.Insert(KeyAndValue.Key, KeyAndValue.Value);
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
	
	DeltaNotIncludingOwners.Insert("ToDelete", New ValueTable);
	DeltaNotIncludingOwners.ToDelete.Columns.Add("SoftwareModuleType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	DeltaNotIncludingOwners.ToDelete.Columns.Add("SoftwareModuleID", New TypeDescription("UUID"));
	DeltaNotIncludingOwners.ToDelete.Columns.Add("Type", New TypeDescription("String"));
	DeltaNotIncludingOwners.ToDelete.Columns.Add("permissions", New TypeDescription("Map"));
	
	// Compare source permissions to the result ones
	
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
				
				// The permission existed in the source ones but does not exist in the result ones. - permission being deleted
				
				DeletedRow = WorkInSafeModeServiceSaaS.PermissionsTableRow(
					DeltaNotIncludingOwners.ToDelete, Filter);
				
				If DeletedRow.permissions.Get(KeyAndValue.Key) = Undefined Then
					DeletedRow.permissions.Insert(KeyAndValue.Key, KeyAndValue.Value);
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	// Compare result permissions to the source ones
	
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
				
				// Permission exists in results but does not exist in source - permission being added
				
				RowAdded = WorkInSafeModeServiceSaaS.PermissionsTableRow(
					DeltaNotIncludingOwners.Adding, Filter);
				
				If RowAdded.permissions.Get(KeyAndValue.Key) = Undefined Then
					RowAdded.permissions.Insert(KeyAndValue.Key, KeyAndValue.Value);
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Function DeltaNotIncludingOwners() Export
	
	Return DeltaNotIncludingOwners;
	
EndFunction

// Checks whether it is required to use permissions the servers cluster.
//
// Return value: Boolean.
//
Function PermissionsApplicationRequiredOnServerCluster() Export
	
	Return DeltaNotIncludingOwners.Adding.Count() > 0 OR DeltaNotIncludingOwners.ToDelete.Count() > 0;
	
EndFunction

// Checks whether permissions are to be written to registers.
//
// Return value: Boolean.
//
Function RequirePermissionsWriteToRegister() Export
	
	Return DeltaInOwnersContext.Adding.Count() > 0 OR DeltaInOwnersContext.ToDelete.Count() > 0;
	
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
	Status.Insert("QueryIDs", QueryIDs);
	
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
	QueryIDs = Status.QueryIDs;
	
EndProcedure

// Writes a request to use external resources to the IB.
//
Procedure FinishRequestsApplicationOnExternalResourcesUse() Export
	
	BeginTransaction();
	
	Try
		
		If RequirePermissionsWriteToRegister() Then
			
			For Each ToDelete IN DeltaInOwnersContext.ToDelete Do
				
				For Each KeyAndValue IN ToDelete.permissions Do
					
					WorkInSafeModeServiceSaaS.DeletePermission(
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
					
					WorkInSafeModeServiceSaaS.AddPermission(
						Adding.SoftwareModuleType,
						Adding.SoftwareModuleID,
						Adding.OwnerType,
						Adding.IDOwner,
						KeyAndValue.Key,
						CommonUse.ObjectXDTOFromXMLRow(KeyAndValue.Value));
					
				EndDo;
				
			EndDo;
			
		EndIf;
		
		WorkInSafeModeServiceSaaS.DeleteQueries(QueryIDs);
		WorkInSafeModeServiceSaaS.ClearIrrelevantQueries();
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

Procedure CancelRequestsApplicationOnExternalResourcesUse() Export
	
	WorkInSafeModeServiceSaaS.DeleteQueries(QueryIDs);
	
EndProcedure

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

RequestUsePlan.Insert("ToDelete", New ValueTable);
RequestUsePlan.ToDelete.Columns.Add("SoftwareModuleType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
RequestUsePlan.ToDelete.Columns.Add("SoftwareModuleID", New TypeDescription("UUID"));
RequestUsePlan.ToDelete.Columns.Add("OwnerType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
RequestUsePlan.ToDelete.Columns.Add("IDOwner", New TypeDescription("UUID"));
RequestUsePlan.ToDelete.Columns.Add("Type", New TypeDescription("String"));
RequestUsePlan.ToDelete.Columns.Add("permissions", New TypeDescription("Map"));

AdministrationOperations = New ValueTable;
AdministrationOperations.Columns.Add("SoftwareModuleType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
AdministrationOperations.Columns.Add("SoftwareModuleID", New TypeDescription("UUID"));
AdministrationOperations.Columns.Add("Operation", New TypeDescription("EnumRef.OperationsAdministrationSecurityProfiles"));
AdministrationOperations.Columns.Add("Name", New TypeDescription("String"));

#EndRegion

#EndIf
