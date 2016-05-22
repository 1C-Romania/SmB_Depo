#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	If AdditionalProperties.Property("PredefinedOnesFilling") Then
		CheckFillingPredefined(Cancel);
	EndIf;
	If DataExchange.Load Then
		Return;
	EndIf;
	If Not AdditionalProperties.Property("PredefinedOnesFilling") Then
		Raise NStr("en = 'The catalog ""Predefined variant reports"" changes only in case of automatic data filling.'");
	EndIf;
EndProcedure

// Basic checks of the data correctness of the predefined reports.
Procedure CheckFillingPredefined(Cancel)
	If DeletionMark Then
		Return;
	ElsIf Not ValueIsFilled(Report) Then
		ErrorText = NotFilledField("Report");
	Else
		Return;
	EndIf;
	Cancel = True;
	ReportsVariants.ErrorByVariant(Ref, ErrorText);
EndProcedure

Function NotFilledField(FieldName)
	Return StrReplace(NStr("en = 'The field ""%1"" is not filled.'"), "%1", FieldName);
EndFunction

#EndRegion

#EndIf