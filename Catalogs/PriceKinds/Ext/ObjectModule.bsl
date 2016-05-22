#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If CalculatesDynamically Then
		CheckedAttributes.Add("PricesBaseKind");
	EndIf;
	
EndProcedure // FillCheckProcessing()

#EndIf