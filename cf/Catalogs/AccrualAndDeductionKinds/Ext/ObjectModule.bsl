#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Type <> Enums.AccrualAndDeductionTypes.Tax Then
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		
	EndIf;
	
EndProcedure // FillCheckProcessing()

#EndIf