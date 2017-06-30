#Region BaseFormsProcedures

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	DocumentsFormAtServer.OnCreateAtServer(ThisForm, Cancel, StandardProcessing);	
	IsAccessRightPayments = Privileged.IsAccessRight(Object.Ref.Metadata().TabularSections.Payments, "View");
	Items.Settlements.Visible = IsAccessRightPayments;
	
	MaxExtDimensionCount = Metadata.ChartsOfAccounts.Bookkeeping.MaxExtDimensionCount;
	For Each CurrentRow In Object.Records Do
		For i = 1 To MaxExtDimensionCount Do
			CurrentRow["ExtDimension" + Format(i,"NG=") + "Mandatory"] = CurrentRow.Account["ExtDimension" + Format(i,"NG=") + "Mandatory"];
		EndDo;
	EndDo;
	DocumentsFormAtServer.SetExchangeRateListChoice(ThisForm.Items.ExchangeRate, Object.Currency);
	
	SettlementsChoiceList.Parameters.SetParameterValue("Partner", Object.Customer);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Object.Ref.IsEmpty() Then
		//SetBaseNumberPresentationAtServer();
	Endif;

	DocumentsFormAtClient.OnOpen(ThisForm, Cancel);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	DocumentsFormAtServer.AfterWriteAtServer(ThisForm, CurrentObject, WriteParameters);
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	DocumentsFormAtClient.AfterWrite(ThisForm);
	//SetBaseNumberPresentationAtServer();	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	DocumentsFormAtServer.BeforeWriteAtServer(ThisForm, Cancel, CurrentObject, WriteParameters);
	
	CurrentObject.Payments.Clear();
	For Each RowSettlement In Settlements Do
		NewRow = CurrentObject[RowSettlement.Type].Add();
		FillPropertyValues(NewRow, RowSettlement);
		If RowSettlement.Type = "Payments" Then
			NewRow.Amount = RowSettlement.GrossAmount;
			NewRow.CashDesk = RowSettlement.BankCash;
		EndIf;
	EndDo;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	NotificationProcessingAtServer(EventName, Parameter);
EndProcedure

&AtServer
Procedure NotificationProcessingAtServer(EventName, Parameter)
	DocumentsFormAtServer.NotificationProcessingAtServer(ThisForm, EventName, Parameter);
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
Procedure OperationTypeOnChange(Item)
	DocumentsFormAtClient.ChangeDocumentsHeaderData(ThisForm, Item);
EndProcedure

&AtClient
Procedure PrefixOnChange(SelectedElement, AdditionalParameters) Export
	If SelectedElement = Undefined Then
		Return;
	EndIf;
	// Jack 27.06.2017
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

#Region StandardCommonCommands

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

&AtClient
Procedure ChangeDocumentsHeader(MainParameters, AdditionalParameters) Export
	If MainParameters = Undefined Then
		Modified = AdditionalParameters.Modified;
		FillPropertyValues(Object, AdditionalParameters);
	Else
		
		FillPropertyValues(Object, MainParameters);
		Modified = True;
		ChangeDocumentsHeaderAtServer();
		
		UpdateDialog();
	EndIf;
EndProcedure

&AtClient
Procedure UpdateDialog() Export
	DocumentsFormAtClient.UpdateDialog(ThisForm);
EndProcedure

&AtServer
Procedure CustomerOnChangeCommonAtServer()
	
	If Not Object.Customer.IsEmpty() And Object.Customer.CustomerType = Enums.CustomerTypes.Independent Then
		
		Object.Currency              = Object.Customer.Currency;
		Object.ExchangeRate   = AccountingAtServer.GetExchangeRate(Object.Currency, AccountingAtServer.GetDocumentExchangeRateDate(Object,True));
		Object.CustomerContactPerson = Object.Customer.DefaultContactPerson;
		
		If ValueIsNotFilled(Object.DeliveryPoint) OR (ValueIsFilled(Object.DeliveryPoint) AND Object.DeliveryPoint.HeadOffice <> Object.Customer) Then
			Object.DeliveryPoint = Catalogs.Customers.EmptyRef();
			Object.DeliveryPoint = Catalogs.Customers.GetCustomerDeliveryPoint(Object.Customer, Object.DeliveryPoint);
			If Not Object.DeliveryPoint.IsEmpty() Then
				
				Object.DeliveryPointContactPerson = Object.DeliveryPoint.DefaultContactPerson;
				
			EndIf;
		EndIf;
		
		CommonAtServer.FillRemarks(Object, Object.Customer, True);
		
		Object.PaymentTerms	= Object.Customer.PaymentTerms;
		Object.PaymentMethod= Object.Customer.PaymentMethod;
		
	Else
		Object.DeliveryPoint = Catalogs.Customers.EmptyRef();
	EndIf;
	
	SettlementsChoiceList.Parameters.SetParameterValue("Partner", Object.Customer);
	
EndProcedure

&AtClient
Procedure CustomerOnChange(Item)
	CustomerOnChangeCommonAtServer();
	UpdateDialog();
EndProcedure

&AtServer
Procedure DeliveryPointOnChangeAtServer()
	If ValueIsNotFilled(Object.Customer) Then
		
		If ValueIsFilled(Object.DeliveryPoint.HeadOffice) Then
			Object.Customer = Object.DeliveryPoint.HeadOffice;
		Else
			Object.Customer = Object.DeliveryPoint;
		EndIf;
		CustomerOnChangeCommonAtServer();
		
	EndIf;
	Object.DeliveryPointContactPerson = Object.DeliveryPoint.DefaultContactPerson;
EndProcedure

&AtClient
Procedure DeliveryPointQuickOnChange(Item)
	DeliveryPointOnChangeAtServer();
	UpdateDialog();
EndProcedure

&AtServer
Procedure PaymentTermsOnChangeAtServer()
	If Object.Date = '00010101' Then
	Object.PaymentDate = CommonAtServer.GetPaymentDate(CurrentDate(), Object.PaymentTerms);
	
	Else
	Object.PaymentDate = CommonAtServer.GetPaymentDate(Object.Date, Object.PaymentTerms);
	EndIf;
EndProcedure

&AtClient
Procedure PaymentTermsOnChange(Item)
	PaymentTermsOnChangeAtServer()
EndProcedure

&AtServer
Procedure RecordsAccountOnChangeAtServer()
	CurrentRow = Object.Records.FindByID(Items.Records.CurrentRow);
	MaxExtDimensionCount = Metadata.ChartsOfAccounts.Bookkeeping.MaxExtDimensionCount;
	For i = 1 To MaxExtDimensionCount Do
		CurrentRow["ExtDimension" + Format(i,"NG=")+ "Mandatory"] = CurrentRow.Account["ExtDimension" + Format(i,"NG=") + "Mandatory"];
	EndDo;
EndProcedure

&AtClient
Procedure RecordsAccountOnChange(Item)
	RecordsAccountOnChangeAtServer();
EndProcedure

#EndRegion

#Region Settlements
&AtClient
Procedure ChangeDocumentSettlements(MainParameters, AdditionalParameters) Export
	If MainParameters = Undefined Then
		Return;
	EndIf;
	
	DocumentsFormAtClient.ChangeDocumentSettlements(ThisForm, MainParameters, AdditionalParameters);
	
EndProcedure

&AtClient
Procedure SettlementsSettlementInfoOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	DocumentsFormAtClient.OpenDocumentsSettlementsForm(ThisForm, ThisForm.ObjectMetadataName);
	
EndProcedure

&AtClient
Procedure SettlementsOnStartEdit(Item, NewRow, Clone)
	If NewRow Then
		DocumentsFormAtClient.OpenDocumentsSettlementsForm(ThisForm, ThisForm.ObjectMetadataName);
	EndIf;
EndProcedure

&AtClient
Procedure SettlementsOnEditEnd(Item, NewRow, CancelEdit)
	DocumentsFormAtClient.SettlementsChange(ThisForm, New Structure("Partner, Currency", Object.Customer, Object.Currency));
EndProcedure

&AtClient
Procedure SettlementsAfterDeleteRow(Item)
	DocumentsFormAtClient.SettlementsChange(ThisForm, New Structure("Partner, Currency", Object.Customer, Object.Currency));
EndProcedure

&AtClient
Procedure SettlementsChoice(Command)
	
	If Object.Posted And Not Items.SettlementsSettlementsChoice.Check Then
		ShowMessageBox(, NStr("en='Please, clear posting of the document before filling.';pl='Anuluj zatwierdzenie dokumentu przed rozpoczęciem jego wypełniania.';ru='Перед началом заполнения документа отмените его проведение.'"));
		Return;
	EndIf;
	
	Items.SettlementsSettlementsChoice.Check = Not Items.SettlementsSettlementsChoice.Check;
	Items.GroupSettlementChoice.Visible = Not Items.GroupSettlementChoice.Visible;
	
EndProcedure

&AtClient
Procedure ExchangeRateChoiceProcessing(Item, SelectedValue, StandardProcessing)
	DocumentsFormAtClient.ExchangeRateChoiceProcessing(ThisForm, Item, SelectedValue, StandardProcessing,Object.Currency);
	//ExchangeRateOnChange(Item);
EndProcedure

&AtServer
Procedure SettlementCurrencyOnChangeAtServer()
	
	OriginalSettlementExchangeRate = Object.ExchangeRate;
	
	Object.ExchangeRate = CommonAtServer.GetExchangeRate(Object.Currency, Object.Date);
	If OriginalSettlementExchangeRate <> Object.ExchangeRate Then
		DocumentObject = FormDataToValue(Object, Type("DocumentObject." + Object.Ref.Metadata().Name));
		APAR.UpdateSettlemenExchangeRate(DocumentObject,Object.ExchangeRate, "Records",,"ExchangeRate");
		ValueToFormData(DocumentObject, Object);
	EndIf;	
	
	DocumentsFormAtServer.SetExchangeRateListChoice(Items.ExchangeRate, Object.Currency);
	
	//CalculateSettlementAmount();
	
EndProcedure

&AtClient
Procedure CurrencyOnChange(Item)
	
	SettlementCurrencyOnChangeAtServer();
	
	BankAccountCurrency = "";
	
	If Not Object.Currency.IsEmpty() Then
		BankAccountCurrency = Object.Currency;
	EndIf;
	
EndProcedure

&AtServer
Procedure SettlementDocumentsAmountOnChangeAtServer(AmountName)
	CurrentRowIndex = Items.SettlementDocuments.CurrentRow;
	If Not CurrentRowIndex = Undefined Then
		CurrentRow = Object.SettlementDocuments.FindByID(CurrentRowIndex);
		APAR.AmountOnChange(CurrentRow, AmountName);
	EndIf;

EndProcedure


#EndRegion


