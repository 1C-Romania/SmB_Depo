#Region EventsHandlers

// Procedure - event handler ChoiceDataReceivingProcessing.
//
Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Parameters.Filter.Property("Owner") Then
	// If the parameters of selection by products and services are linked, then we will get the selection data from the "UOM" catalog.
		StandardProcessing = False;
		ChoiceData = Catalogs.UOM.GetChoiceData(Parameters);
	EndIf;
	
EndProcedure

#EndRegion
