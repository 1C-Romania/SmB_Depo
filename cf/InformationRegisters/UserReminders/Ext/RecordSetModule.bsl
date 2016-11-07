#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel, Replacing)
	If DataExchange.Load Then
		Return;
	EndIf;
	
	For Each Record IN ThisObject Do	
		Record.SourcePresentation = CommonUse.SubjectString(Record.Source);
	EndDo;
EndProcedure

#EndRegion

#EndIf