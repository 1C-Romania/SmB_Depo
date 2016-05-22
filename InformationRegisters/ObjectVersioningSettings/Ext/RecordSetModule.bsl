#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	For Each String IN ThisObject Do
		String.Use = String.Variant <> Enums.ObjectVersioningOptions.DoNotVersion;
	EndDo;
	
EndProcedure

#EndRegion

#EndIf