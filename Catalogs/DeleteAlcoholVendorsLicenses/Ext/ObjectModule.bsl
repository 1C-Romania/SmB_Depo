#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnCopy(CopiedObject)
	
	FillStartEndDates();
	Description = "";
	
EndProcedure

Procedure Filling(FillingData, StandardProcessing)
	
	FillStartEndDates();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure FillStartEndDates()
	
	StartDate = CurrentSessionDate();
	If EndDate < StartDate Then
		EndDate = Date(1,1,1);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
