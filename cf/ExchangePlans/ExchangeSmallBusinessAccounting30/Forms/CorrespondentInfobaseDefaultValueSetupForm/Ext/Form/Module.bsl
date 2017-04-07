
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ExchangePlanName = Metadata.ExchangePlans.ExchangeSmallBusinessAccounting30.Name;
	
	DataExchangeServer.CorrespondentInfobaseDefaultValueSetupFormOnCreateAtServer(ThisForm, ExchangePlanName);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	DataExchangeClient.SettingFormBeforeClose(Cancel, ThisForm);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	DataExchangeClient.CorrespondentInfobaseObjectSelectionProcessingHandler(ThisForm, ValueSelected);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure CostItemStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataExchangeClient.CorrespondentInfobaseObjectSelectionHandlerStartChoice("CostsItem", "Catalog.CostItems", ThisForm, StandardProcessing, ExternalConnectionParameters);
	
EndProcedure

&AtClient
Procedure OtherIncomeCostsItemStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataExchangeClient.CorrespondentInfobaseObjectSelectionHandlerStartChoice("OtherIncomeCostsItem", "Catalog.OtherIncomeAndExpenses", ThisForm, StandardProcessing, ExternalConnectionParameters);
	
EndProcedure

&AtClient
Procedure ServiceRewardsStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataExchangeClient.CorrespondentInfobaseObjectSelectionHandlerStartChoice("ServiceRewards", "Catalog.ProductsAndServices", ThisForm, StandardProcessing, ExternalConnectionParameters);
	
EndProcedure

&AtClient
Procedure MethodReflectionCostsStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataExchangeClient.CorrespondentInfobaseObjectSelectionHandlerStartChoice("CostsReflectionMethod", "Catalog.WaysOfDepreciationCostsReflection", ThisForm, StandardProcessing, ExternalConnectionParameters);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CommandOK(Command)
	
	DataExchangeClient.DefaultValuesConfigurationFormCommandCloseForm(ThisForm);
	
EndProcedure

#EndRegion



