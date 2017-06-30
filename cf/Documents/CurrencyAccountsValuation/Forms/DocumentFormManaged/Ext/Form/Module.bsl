#Region BaseFormsProcedures 

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DocumentsFormAtServer.OnCreateAtServer(ThisForm, Cancel, StandardProcessing);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Object.Ref.IsEmpty() Then
		//SetBaseNumberPresentationAtServer();
	Endif;		
	
	DocumentsFormAtClient.OnOpen(ThisForm, Cancel);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	NotificationProcessingAtServer(EventName, Parameter);
EndProcedure

&AtServer
Procedure NotificationProcessingAtServer(EventName, Parameter)
	DocumentsFormAtServer.NotificationProcessingAtServer(ThisForm, EventName, Parameter);
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	DocumentsFormAtClient.AfterWrite(ThisForm);
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	DocumentsFormAtServer.AfterWriteAtServer(ThisForm, CurrentObject, WriteParameters); 
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	DocumentsFormAtServer.BeforeWriteAtServer(ThisForm, Cancel, CurrentObject, WriteParameters); 	
	
EndProcedure

#EndRegion

#Region StandardCommonCommands

&AtClient
Procedure UpdateDialog() Export
	DocumentsFormAtClient.UpdateDialog(ThisForm);  	
EndProcedure

&AtServer
Function PostAtServer()
	Return DocumentsFormAtServer.Post(ThisForm);
EndFunction

&AtClient
Procedure PostPrintClose(Command)
	If PostAtServer() Then
		DocumentsFormAtClient.PostPrintClose(ThisForm);
	EndIf;
EndProcedure

&AtServer
Procedure ChangeDocumentsHeaderAtServer(Recalculate = True) Export
	DocumentsFormAtServer.SetFormDocumentTitle(ThisForm);
EndProcedure

#EndRegion

#Region ItemsEvents

&AtClient
Procedure NumberPreviewOnChange(Item)
	If Object.ManualChangeNumber Then
		DocumentsFormAtClient.ChangeDocumentsHeaderData(ThisForm, Item);
	Else
		EndTextNumberOnChange = New NotifyDescription("EndTextNumberOnChange", ThisForm, New Structure("ItemName", Item.Name));
		ShowQueryBox(EndTextNumberOnChange, NStr("en='ATTENTION! After changing the number automatic numbering for this document will be disabled! Enable number editing?';pl='UWAGA! Po zmianie numeru numeracja automatyczna tego dokumentu zostanie wyłączona! Włączyć moźliwość zmiany numeru?';ru='ВНИМАНИЕ! После изменения номера автоматическая нумерация документов будет отключена! Разрешить редактирование номера документа?'"), QuestionDialogMode.YesNo);
	EndIf;
EndProcedure

&AtClient
Procedure NumberPreviewStartChoice(Item, ChoiceData, StandardProcessing)
	ShowChooseFromList(New NotifyDescription("PrefixOnChange", ThisForm), ThisForm["PrefixList"], Item);
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	DocumentsFormAtClient.ChangeDocumentsHeaderData(ThisForm, Item);
EndProcedure

&AtClient
Procedure PrefixOnChange(SelectedElement, AdditionalParameters) Export
	If SelectedElement = Undefined Then
		Return;
	EndIf;
	// Jack 25.06.2017
	//If SelectedElement.Value = "NumberSettings" Then
	//	OpenForm("InformationRegister.DocumentsNumberingSettings.Form.RecordFormSetting", New Structure("DocumentType", Object.Ref), ThisForm);
	//	Return;
	//EndIf;
	//Object["ManualChangeNumber"] = False;
	//Object["Prefix"] = SelectedElement.Value;
	DocumentsFormAtClient.ChangeDocumentsHeaderData(ThisForm);
EndProcedure

&AtClient
Procedure EndTextNumberOnChange(QuestionAnswer, AdditionalParameters) Export
	If QuestionAnswer = DialogReturnCode.Yes Then
		Object.ManualChangeNumber = True;
	EndIf;
	DocumentsFormAtClient.ChangeDocumentsHeaderData(ThisForm, Items[AdditionalParameters.ItemName]);
EndProcedure

#EndRegion

#Region EventsProcessingOfTabularPartDocuments
&AtClient
Procedure ExchangeRatesCurrencyOnChange(Item)
	
	CurrentData 			 = Items.ExchangeRates.CurrentData;
	CurrentData.ExchangeRate = CommonAtServer.GetExchangeRate(CurrentData.Currency, Object.Date);

EndProcedure

&AtClient
Procedure ExchangeRatesExchangeRateStartChoice(Item, ChoiceData, StandardProcessing)
	
	ExchangeRateRow = Items.ExchangeRates.CurrentData;
 	DialogsAtClient.ExchangeRateStartListChoice(Item, StandardProcessing, ThisForm, ExchangeRateRow.Currency, ExchangeRateRow.ExchangeRate);

	
EndProcedure 

&AtClient
Procedure AccountsUncheckAll(Command)
	
	For Each Item In Object.Accounts Do
		Item.UseAccount = False;
	EndDo;

EndProcedure

&AtClient
Procedure AccountsCheckAll(Command)
	
	For Each Item In Object.Accounts Do
		Item.UseAccount = True;
	EndDo;
	
EndProcedure

&AtClient
Procedure ValuationOnStartEdit(Item, NewRow, Clone)
	
	If Item.CurrentRow <> Undefined Then
		AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("Account_AmountDue","ValuationExtDimension",Item.CurrentData,Item.ChildItems);
		TableWithExtDimensionsOnChangeAtServer("Account_AmountDue","ExtDimension","Valuation",Item.CurrentRow);
	EndIf;	
	
EndProcedure

&AtServer
Procedure TableWithExtDimensionsOnChangeAtServer(Val AccountName, Val ExtDimensionName,Val TableName,Val RowId)
	
	RowData = Object[TableName].FindById(RowId);
	DialogsAtServer.CheckAccountsExtDimensions(RowData[AccountName],ExtDimensionName,RowData);
	
EndProcedure

&AtClient
Procedure ValuationAccount_AmountDueOnChange(Item)	
		
	AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("Account_AmountDue","ValuationExtDimension",Items.Valuation.CurrentData,Items.Valuation.ChildItems);
	TableWithExtDimensionsOnChangeAtServer("Account_AmountDue","ExtDimension","Valuation",Items.Valuation.CurrentRow);


EndProcedure
#EndRegion

#Region OtherProceduresAndFunctions

&AtClient
Procedure FillValuation(Command)
	
	If Modified Then
		ShowMessageBox(, NStr("en='Please, save the document before filling.';pl='Zapisz dokument przed rozpoczęciem jego wypełniania.'"));
		Return;
	EndIf;
	
	NotifyDescription	= New NotifyDescription("FillValuationAtClient", ThisObject);
	DocumentsFormAtClient.TabularPartFillingRequest(NotifyDescription, Object.Valuation.Count(), Object.Posted);
	
EndProcedure

&AtClient
Procedure FillExchangeRates(Command)
	
	NotifyDescription	= New NotifyDescription("FillExchangeRatesAtClient", ThisObject);
	DocumentsFormAtClient.TabularPartFillingRequest(NotifyDescription, Object.ExchangeRates.Count(), Object.Posted);
	
EndProcedure

&AtClient
Procedure FillAccounts(Command)
	
	
	NotifyDescription	= New NotifyDescription("FillAccountsAtClient", ThisObject);
	DocumentsFormAtClient.TabularPartFillingRequest(NotifyDescription, Object.Accounts.Count(), Object.Posted);
	
	
EndProcedure

&AtClient
Procedure FillAccountsAtClient(Answer, Parameters) Export 
	
	FillAccountsAtServer();
	
EndProcedure

&AtServer
Procedure FillAccountsAtServer() 
	
	DocObject = FormAttributeToValue("Object"); 	
	DocObject.Accounts.Clear();
	DocObject.FillAccounts();
	ValueToFormData(DocObject, Object);
	
EndProcedure

&AtServer
Procedure FillExchangeRatesAtClient(Answer, Parameters) Export
	
	FillExchangeRatesAtServer();
	
EndProcedure

&AtServer
Procedure FillExchangeRatesAtServer() 
	
	DocObject = FormAttributeToValue("Object");
	DocObject.ExchangeRates.Clear();
	DocObject.FillExchangeRates();
	ValueToFormData(DocObject, Object);
	
EndProcedure

&AtClient
Procedure FillValuationAtClient(Answer, Parameters) Export 
	
	FillValuationAtServer();
	
EndProcedure

&AtServer
Procedure FillValuationAtServer()  
	
	DocObject = FormAttributeToValue("Object");
	DocObject.Valuation.Clear();
	DocObject.FillValuation();
	ValueToFormData(DocObject, Object);
	
EndProcedure


#EndRegion







