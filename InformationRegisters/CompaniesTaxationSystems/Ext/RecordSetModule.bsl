#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	For Each Record IN ThisObject Do
		
		If Record.TaxationSystem = Enums.TaxationSystems.Simplified Then
			
	        CheckedAttributes.Add("VATRate");
			
		EndIf;	
			
	EndDo;	
	
EndProcedure // FillCheckProcessing()

#EndRegion

#EndIf