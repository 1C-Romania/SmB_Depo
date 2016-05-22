#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	Var Characteristic;
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Definition = DataKind;
	For Each Characteristic IN DataCharacteristics Do
		Definition = Definition + ", " + Characteristic.Characteristic + ": " + Characteristic.Value;
	EndDo;
		
EndProcedure

#EndRegion

#EndIf