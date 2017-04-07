
#Region EventHadlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FillingValues = New Structure("Kind", CommandParameter);
	OpenForm("InformationRegister.ContactInformationKindSettings.Form.EditingKindSettings",
		New Structure("Key,FillingValues", RecordKey(CommandParameter), FillingValues),
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&НаСервере
Function RecordKey(Kind)
	
	Query = New Query;
	Query.Text = "SELECT
	             |	ContactInformationKindSettings.Kind
	             |FROM
	             |	InformationRegister.ContactInformationKindSettings AS ContactInformationKindSettings
	             |WHERE
	             |	ContactInformationKindSettings.Kind = &Kind";
	
	Query.SetParameter("Kind", Kind);
	If Query.Execute().IsEmpty() Then
		Return Undefined;
	EndIf;
	
	RecordKeyData = New Structure("Kind", Kind);
	Return InformationRegisters.ContactInformationKindSettings.CreateRecordKey(RecordKeyData);
	
EndFunction

#EndRegion
