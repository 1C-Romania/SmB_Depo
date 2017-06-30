Function WriteObjectInForm(Form,WriteParameters,CommandPresentation) Export 
	
	If Form.Parameters.Key.IsEmpty() Then
		
		QueryBoxText = CommonAtClientAtServer.ParametrizeString(Nstr("en = 'Data has not been written yet.
                          |Performing command ""%P1"" will be possible only after data will be written.
                          |Data will be written.'; pl = 'Dane jeszcze nie zostałe zapisane.
                          |Wykonanie polecenia ""%P1"" będzie możliwe tylko po zapisaniu danych.
                          |Dane zostaną zapisane.'"),New Structure("P1",CommandPresentation));
		QueryBoxResult = DoQueryBox(QueryBoxText, QuestionDialogMode.OKCancel);
		
		If QueryBoxResult <> DialogReturnCode.OK Then 
			Return False;	
		EndIf;	
		
		Return Form.Write(WriteParameters);
	Else
		Return True;
	EndIf;
			
EndFunction // WriteObjectInForm()

Procedure WriteObjectInFormRequest(Form, CommandPresentation, NotifyDescriptionOnProceed) Export 
	QueryText	= CommonAtClientAtServer.ParametrizeString(Nstr("en = 'Data has not been written yet.
                          |Performing command ""%P1"" will be possible only after data will be written.
                          |Data will be written.'; pl = 'Dane jeszcze nie zostałe zapisane.
                          |Wykonanie polecenia ""%P1"" będzie możliwe tylko po zapisaniu danych.
                          |Dane zostaną zapisane.'"),New Structure("P1",CommandPresentation));
						  
	NotifyParams= New Structure("NotifyDescriptionOnProceed, Form", NotifyDescriptionOnProceed, Form);
	NotifyDescr	= New NotifyDescription("WriteObjectInFormResponse", DialogsAtClient, NotifyParams);
	
	ShowQueryBox(NotifyDescr, QueryText, QuestionDialogMode.OKCancel);
EndProcedure

Procedure WriteObjectInFormResponse(Answer, Parameters) Export 
	If Answer <> DialogReturnCode.OK Then
		Return;
	EndIf;
	
	If Parameters.Form.Write() Then 
		ExecuteNotifyProcessing(Parameters.NotifyDescriptionOnProceed);
	EndIf;
EndProcedure

Procedure ExchangeRateStartListChoice(Item, StandartProcessing, Form, Currency, InOutExchangeRate, OutExchangeRateDate = Undefined, OutNBPTableNumber = Undefined) Export
	
	StandartProcessing = False;
	
	ExchangeRatesValueList = CurrenciesAtServer.GetExchangeRatesValueList(Currency,New Structure("ExchangeRate, Period, NBPTableNumber"));
		
	ExchangeRatesValueList.Add(Undefined, NStr("en=""Choose from list...""; pl=""Wybierz z listy..."""));
	
	CurrentValue = Undefined;
	
	For i=0 To ExchangeRatesValueList.Count()-2 Do
		
		If ExchangeRatesValueList[i].Value.ExchangeRate = InOutExchangeRate 
			AND (OutExchangeRateDate = Undefined OR BegOfDay(ExchangeRatesValueList[i].Value.Period) = BegOfDay(OutExchangeRateDate))
			AND (OutNBPTableNumber = Undefined OR ExchangeRatesValueList[i].Value.NBPTableNumber = OutNBPTableNumber) Then
			CurrentValue = i;
			Break;
		EndIf;	
		
	EndDo;	
	
	NotifyDescr	= New NotifyDescription("ExchangeRateStartListChoiceEnd", DialogsAtClient,
			New Structure("OutExchangeRateDate, Currency, Item, Form", OutExchangeRateDate, Currency, Item, Form));
	Form.ShowChooseFromList(NotifyDescr, ExchangeRatesValueList, Item, CurrentValue);
	
EndProcedure // GlobalExchangeRateStartListChoice()

&AtClient
Procedure ExchangeRateStartListChoiceEnd(ValueListItem, QueryParameters)  Export

	OutExchangeRateDate	= QueryParameters.OutExchangeRateDate;
	Currency			= QueryParameters.Currency;
	Item				= QueryParameters.Item;
	Form				= QueryParameters.Form;
	
	If ValueListItem = Undefined Then
		Return;
	ElsIf ValueListItem.Value = Undefined Then
		FormParameters = New Structure("ChoiceMode, ReturnRow, Filter",True,(OutExchangeRateDate<>Undefined),New Structure("Currency",Currency));
		OpenForm("InformationRegister.CurrencyExchangeRates.ListForm",FormParameters,?(OutExchangeRateDate<>Undefined,Form,Item),Item,,,,FormWindowOpeningMode.LockOwnerWindow);
	Else
		InOutExchangeRate = ValueListItem.Value.ExchangeRate;
		OutExchangeRateDate = ValueListItem.Value.Period;
		OutNBPTableNumber = ValueListItem.Value.NBPTableNumber;
	EndIf;
EndProcedure

// Jack 29.06.2017
//Procedure UnitOfMeasureStartListChoice(Item, StandartProcessing, Form, CurrentDataItem, CurrentUnitOfMeasure, Object = Undefined, OldUnitOfMeasure = Undefined) Export
//	
//	StandartProcessing = False;
//	
//	UnitOfMeasureValueList = ControlsProcessingAtServer.GetItemsUnitsOfMeasureValueList(CurrentDataItem);
//		
//	CurrentValue = Undefined;
//	
//	For i=0 To UnitOfMeasureValueList.Count()-1 Do
//		
//		If UnitOfMeasureValueList[i].Value = CurrentDataItem  Then
//			CurrentValue = i;
//			Break;
//		EndIf;	
//		
//	EndDo;	
//	
//	#If NOT ThickClientOrdinaryApplication Then
//		Descr		= New NotifyDescription("HandleValueOfChoiseFromList", Object, New Structure("OldUnitOfMeasure", OldUnitOfMeasure));
//		Form.ShowChooseFromList(Descr, UnitOfMeasureValueList, Item);
//	#Else
//		ValueListItem = Form.ChooseFromList(UnitOfMeasureValueList, Item, CurrentValue);
//		
//		If ValueListItem = Undefined Then
//			Return;
//		Else
//			CurrentUnitOfMeasure = ValueListItem.Value;
//		EndIf;
//	#EndIf
//	
//EndProcedure // UnitOfMeasureStartListChoice()

Procedure NumericValueStartListChoice(Item, StandartProcessing, Form, ValueArray, TableName, AttributeName) Export
	StandartProcessing = False;	
	CurrentRow = Form.Object[TableName].FindByID(Form.Items[TableName].CurrentRow);

	ChoiceValueList = New ValueList;		
	For Each CurrentValue In ValueArray Do
		ChoiceValueList.Add(CurrentValue);		
	EndDo;
	
	NotifyDescr	= New NotifyDescription("NumericValueStartListChoiceEnd", DialogsAtClient,
			New Structure("CurrentRow, AttributeName", CurrentRow, AttributeName));
			
	Form.ShowChooseFromList(NotifyDescr, ChoiceValueList, Item, CurrentRow[AttributeName]);
EndProcedure // NumericValueStartListChoice()

Procedure NumericValueStartListChoiceEnd(ValueListItem, QueryParameters) Export 
	If ValueListItem <> Undefined Then
		QueryParameters.CurrentRow[QueryParameters.AttributeName] = ValueListItem.Value;
	EndIf;	
EndProcedure

Procedure ShowBookkeepingOperation(DocumentRef) Export 
	
	Answer = DialogsAtServer.GetBookkeepingOperation(DocumentRef);
	If Answer.Success Then
		ShowValue(,Answer.BookkeepingOperation);
	Else	
		If Answer.ShowMessage Then
			ShowMessageBox(,Answer.Message);		
		EndIf;
		If Answer.Empty Then
			NotifyParameters = New Structure;
			NotifyParameters.Insert("DocumentRef",DocumentRef);			
			NotifyDescription = New NotifyDescription("QueryNewBookkeepingOperationAnswer",DialogsAtClient,NotifyParameters);
			ShowQueryBox(NotifyDescription,NStr("en = 'For this document bookkeeping operation does not exists. Do you want to create a new one bookkeeping operation?'; pl = 'Na podstawie tego dokumentu nie został zaksięgowany dowód księgowy. Czy chcesz stworzyć nowy dowód księgowy?'"),QuestionDialogMode.YesNo);
		EndIf;		

	EndIf;
EndProcedure

&AtClient
Procedure QueryNewBookkeepingOperationAnswer(Answer, Parameters)  Export
	If Answer = DialogReturnCode.Yes Then
		OpenForm("Document.BookkeepingOperation.ObjectForm",New Structure("Basis",Parameters.DocumentRef));
	EndIf;
EndProcedure