////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Subsystem "Address classifier".
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Returns the permission flag to import or clear the address classifier.
//
Function YouCanChangeAddressClassifier() Export
	
	Return Not CommonUseReUse.DataSeparationEnabled();
	
EndFunction

// Data for the query of the security profiles permissions to update from the 1C website.
//
// Returns:
//     Array - identifiers of required permissions.
// 
Function QueryUpdateSecurityPermissions() Export
	
	PermissionOwner = CommonUse.MetadataObjectID("InformationRegister.AddressObjects"); 
	permissions         = AddressClassifierService.UpdateSecurityPermissions();
	
	Result = New Array;
	Result.Add(WorkInSafeMode.QueryOnExternalResourcesUse(permissions, PermissionOwner, True));
	
	Return Result;
EndFunction

// Returns the state presentation by code.
//
// Parameters:
//     StateCode - Number, String, Maping - state code.
//
// Returns:
//     String, Map - presentation.
//
Function StatePresentationByCode(StateCode) Export
	
	If TypeOf(StateCode) <> Type("Map") Then
		Return StatePresentation(StateCode);
	EndIf;
	
	Result = New Map;
	For Each KeyValue In StateCode Do
		Code = KeyValue.Key;
		Result.Insert(Code, StatePresentation(Code) );
	EndDo;
	
	Return Result;
EndFunction

Function StatePresentation(StateCode)
	
	Return Format(StateCode, "ND=2; NZ=; NLZ=; NG=") + " " + AddressClassifier.StateNameByCode(StateCode);
	
EndFunction

#EndRegion

