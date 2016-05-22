////////////////////////////////////////////////////////////////////////////////
// Subsystem "Items sequence setting".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Fill the value of the additional ordering attribute of the object.
//
// Parameters:
//  Source - Object - Recorded object;
//  Cancel    - Boolean - flag showing the cancelation of object writing.
Procedure FillOrderingAttributeValue(Source, Cancel) Export
	
	If Source.DataExchange.Load Then 
		Return; 
	EndIf;
	
	// If the new sequence was cancelled by the handler, the new sequence is not calculated.
	If Cancel Then
		Return;
	EndIf;
	
	// Check whether the object has an attribute of additional ordering.
	Information = ItemOrderSetupService.GetInformationForMove(Source.Ref.Metadata());
	If Not ObjectHasAddOrderingAttribute(Source, Information) Then
		Return;
	EndIf;
	
	// When you move an item in another group the sequence is reassigned.
	If Information.HasParent AND CommonUse.ObjectAttributeValue(Source.Ref, "Parent") <> Source.Parent Then
		Source.AdditionalOrderingAttribute = 0;
	EndIf;
	
	// Calculate a new value for the item order.
	If Source.AdditionalOrderingAttribute = 0 Then
		Source.AdditionalOrderingAttribute =
			ItemOrderSetupService.GetNewValueOfAdditionalOrderingAttribute(
					Information,
					?(Information.HasParent, Source.Parent, Undefined),
					?(Information.HasOwner, Source.Owner, Undefined));
	EndIf;
	
EndProcedure

// Resets the value of the additional ordering attribute of the object.
//
// Parameters:
//  Source          - Object - the object that is created by copying;
//  CopiedObject    - Ref - the source object that is the source of copying.
Procedure ResetOrderingAttributeValue(Source, CopiedObject) Export
	
	Information = ItemOrderSetupService.GetInformationForMove(Source.Ref.Metadata());
	If ObjectHasAddOrderingAttribute(Source, Information) Then
		Source.AdditionalOrderingAttribute = 0;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function ObjectHasAddOrderingAttribute(Object, Information)
	
	If Not Information.HasParent Then
		// Catalog is not hierarchic, so there is an attribute.
		Return True;
		
	ElsIf Object.IsFolder AND Not Information.ForFolders Then
		// This is a group, but the sequence is not assigned for groups.
		Return False;
		
	ElsIf Not Object.IsFolder AND Not Information.ForItems Then
		// This is an item, but the sequence is not assigned for items.
		Return False;
		
	Else
		Return True;
		
	EndIf;
	
EndFunction

#EndRegion
