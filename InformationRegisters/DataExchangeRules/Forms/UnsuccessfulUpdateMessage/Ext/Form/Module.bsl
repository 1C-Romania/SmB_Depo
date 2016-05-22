
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	ExchangePlanName = Parameters.ExchangePlanName;
	ExchangePlanSynonym = Metadata.ExchangePlans[ExchangePlanName].Synonym;
	
	ObjectConversionRules = Enums.DataExchangeRuleKinds.ObjectConversionRules;
	ObjectRegistrationRules = Enums.DataExchangeRuleKinds.ObjectRegistrationRules;
	
	WriteLogEvent(InfobaseUpdate.EventLogMonitorEvent(), EventLogLevel.Error,,,
		Parameters.DetailedErrorMessage);
		
	ErrorInfo = Items.ErrorMessageText.Title;
	ErrorInfo = StrReplace(ErrorInfo, "%2", Parameters.AShortErrorMessage);
	ErrorInfo = PagSubstituteWithHighlight(ErrorInfo, "%1", ExchangePlanSynonym);
	Items.ErrorMessageText.Title = ErrorInfo;
	
	RulesFromFile = InformationRegisters.DataExchangeRules.RulesFromFileUsed(ExchangePlanName, True);
	
	If RulesFromFile.ConversionRules AND RulesFromFile.RegistrationRules Then
		RulesType = NStr("en = 'conversion and registration'");
	ElsIf RulesFromFile.ConversionRules Then
		RulesType = NStr("en = 'conversion'");
	ElsIf RulesFromFile.RegistrationRules Then
		RulesType = NStr("en = 'registration'");
	EndIf;
	
	Items.TextRulesFromFile.Title = StringFunctionsClientServer.PlaceParametersIntoString(
		Items.TextRulesFromFile.Title, ExchangePlanSynonym, RulesType);
	
	UpdateBeginTime = Parameters.UpdateBeginTime;
	If Parameters.UpdateEndTime = Undefined Then
		UpdateEndTime = CurrentSessionDate();
	Else
		UpdateEndTime = Parameters.UpdateEndTime;
	EndIf;
	
	Items.ImportConversionRules.Visible = RulesFromFile.ConversionRules;
	Items.ImportRegistrationRules.Visible = RulesFromFile.RegistrationRules;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Done(Command)
	Close(True);
EndProcedure

&AtClient
Procedure GoToEventLogMonitor(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("StartDate", UpdateBeginTime);
	FormParameters.Insert("EndDate", UpdateEndTime);
	FormParameters.Insert("RunNotInBackground", True);
	
	OpenForm("DataProcessor.EventLogMonitor.Form.EventLogMonitor", FormParameters);
	
EndProcedure

&AtClient
Procedure Restart(Command)
	Close(False);
EndProcedure

&AtClient
Procedure ImportRuleSet(Command)
	
	DataExchangeClient.ImportDataSynchronizationRules(ExchangePlanName);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function PagSubstituteWithHighlight(String, SearchSubstring, ReplacementSubrow)
	
	BeginningPosition = Find(String, SearchSubstring);
	
	StringsArray = New Array;
	
	StringsArray.Add(Left(String, BeginningPosition - 1));
	StringsArray.Add(New FormattedString(ReplacementSubrow, New Font(,,True)));
	StringsArray.Add(Mid(String, BeginningPosition + StrLen(SearchSubstring)));
	
	Return New FormattedString(StringsArray);
	
EndFunction

#EndRegion