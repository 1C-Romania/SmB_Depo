#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region PredeterminedProceduresEventsHandlers

// Procedure - FillingProcessor event handler.
//
Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If IsNew() Then
		Prefix = ";";
		Suffix = "?";
		BlocksDelimiter = "=";
	EndIf;
	
EndProcedure

// Procedure - FillCheckProcessing event handler.
//
Procedure BeforeWrite(Cancel)
	
	If CodeLength = 0 Then
		NoSizeRestriction = True;
	Else
		NoSizeRestriction = False;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf