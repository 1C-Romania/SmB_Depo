
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ExchangeRateDate = BegOfDay(CurrentSessionDate());
	Items.ExchangeRate.Title = 
		StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Rate on %1"),
			Format(CurrentSessionDate(), "DLF=DD"));
	Items.ExchangeRate.ToolTip = Items.ExchangeRate.Title;
	List.Parameters.SetParameterValue ("EndOfPeriod", ExchangeRateDate);
	
	Items.Currencies.ChoiceMode = Parameters.ChoiceMode;
	
	If Not Users.RolesAvailable("AddChangeBasicReferenceData") Then
		Items.FormFillFromCurrencyClassifier.Visible = False;
		Items.CurrencyRatesImportForm.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ChoiceResult, ChoiceSource)
	
	Items.Currencies.Refresh();
	Items.Currencies.CurrentRow = ChoiceResult;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_CurrencyRates"
		Or EventName = "Write_CurrencyRatesImportProcess" Then
		Items.Currencies.Refresh();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersCurrencies

&AtClient
Procedure CurrenciesBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	Text = NStr("en='There is an option to pick the currency from the classifier.
		|Select?';ru='Есть возможность подобрать валюту из классификатора.
		|Подобрать?'");
	Notification = New NotifyDescription("CurrenciesBeforeAddStartEnd", ThisObject);
	SelectionButtons = New ValueList();
	SelectionButtons.Add(DialogReturnCode.Yes, "Pick");
	SelectionButtons.Add(DialogReturnCode.No, "Create");
	SelectionButtons.Add(DialogReturnCode.Cancel, "Cancel");
	ShowQueryBox(Notification, Text,SelectionButtons, , DialogReturnCode.Yes);
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure PickFromACC(Command)
	
	OpenForm("Catalog.Currencies.Form.CurrencyPickFromClassifier",, ThisObject);
	
EndProcedure

&AtClient
Procedure CurrencyRatesImport(Command)
	FormParameters = New Structure("OpenFromList");
	OpenForm("DataProcessor.CurrencyRatesImportProcess.Form", FormParameters);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure CurrenciesBeforeAddStartEnd(QuestionResult, AdditionalParameters) Export
	 
	If QuestionResult = DialogReturnCode.Yes Then
		OpenForm("Catalog.Currencies.Form.CurrencyPickFromClassifier", , ThisObject);
	ElsIf QuestionResult = DialogReturnCode.No Then
		OpenForm("Catalog.Currencies.ObjectForm");
	EndIf;

EndProcedure

#EndRegion















&AtClient
Procedure OnOpen(Cancel)
	
	//( elmi # 08.5 
	//SmallBusinessClient.RenameTitleExchangeRateMultiplicity( ThisForm );
    //) elmi

EndProcedure
