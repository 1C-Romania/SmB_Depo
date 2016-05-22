
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	// server call
	ExchangePlanName = ExchangePlanName(CommandParameter);
	
	// server call
	RuleKind = PredefinedValue("Enum.DataExchangeRuleKinds.ObjectConversionRules");
	
	Filter              = New Structure("ExchangePlanName, RuleKind", ExchangePlanName, RuleKind);
	FillingValues = New Structure("ExchangePlanName, RuleKind", ExchangePlanName, RuleKind);
	
	DataExchangeClient.OpenInformationRegisterRecordFormByFilter(Filter, FillingValues, "DataExchangeRules", CommandExecuteParameters.Source, "ObjectConversionRules");
	
EndProcedure

&AtServer
Function ExchangePlanName(Val InfobaseNode)
	
	Return DataExchangeReUse.GetExchangePlanName(InfobaseNode);
	
EndFunction

#EndRegion
