#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - FillingProcessor event handler.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If TypeOf(Owner) = Type("CatalogRef.Companies") Then
		CheckedAttributes.Add("GLAccount");
	EndIf;
	
EndProcedure // FillCheckProcessing()

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		
		Return;
		
	EndIf;
	
EndProcedure

#EndIf