#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// Procedure updates cache-attributes of a register
// by a content change result of values types and access values groups.
//
Procedure UpdateRegisterAuxiliaryDataByConfigurationChanges() Export
	
	SetPrivilegedMode(True);
	
	Parameters = AccessManagementServiceReUse.Parameters();
	
	LastChanges = StandardSubsystemsServer.ApplicationPerformenceParameterChanging(
		Parameters, "GroupsAndAccessValuesTypes");
	
	If LastChanges = Undefined
	 OR LastChanges.Count() > 0 Then
		
		AccessManagementService.SetDataFillingForAccessRestriction(True);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure updates register data if the subordinate data is fully updated.
// 
// Parameters:
//  HasChanges - Boolean (return value) - if there
//                  is a record, True is set, otherwise, it is not changed.
//
Procedure RefreshDataRegister(HasChanges = Undefined) Export
	
	DataQuantity = 0;
	While DataQuantity > 0 Do
		DataQuantity = 0;
		AccessManagementService.DataFillingForAccessLimit(DataQuantity, True, HasChanges);
	EndDo;
	
	ObjectsTypes = AccessManagementServiceReUse.TypesOfObjectsInSubscriptionsToEvents(
		"RecordSetsOfAccessValues");
	
	For Each DescriptionOfType IN ObjectsTypes Do
		Type = DescriptionOfType.Key;
		
		If Type = Type("String") Then
			Continue;
		EndIf;
		
		Selection = CommonUse.ObjectManagerByFullName(Metadata.FindByType(Type).FullName()).Select();
		
		While Selection.Next() Do
			AccessManagementService.UpdateSetsOfAccessValues(Selection.Ref, HasChanges);
		EndDo;
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
