#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnWrite(Cancel)
	
	SetPrivilegedMode(True);
	
	Constants.DoNotUseSeveralCompanies.Set(NOT ThisObject.Value);
	
EndProcedure

#EndRegion

#EndIf
