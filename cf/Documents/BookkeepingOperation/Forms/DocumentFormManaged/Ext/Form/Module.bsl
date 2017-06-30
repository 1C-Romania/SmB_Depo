
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

	RecordsAppearanceProcessing();
	PurchaseVATAppearanceProcessing();
	SalesVATAppearanceProcessing();
	ShowFirstFilledTabularPart();
	
	DocumentsFormAtClient.OnOpen(ThisForm, Cancel);	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	RecordsAppearanceProcessingAtServer();
	PurchaseVATAppearanceProcessingAtServer();
	SalesVATAppearanceProcessingAtServer();
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	NotificationProcessingAtServer(EventName, Parameter);
EndProcedure

&AtServer
Procedure NotificationProcessingAtServer(EventName, Parameter)
	DocumentsFormAtServer.NotificationProcessingAtServer(ThisForm, EventName, Parameter);
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)  Export 
	If IsEmulated Then
		Cancel = True;
	EndIf;	
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		CurrentObject.AdditionalProperties.Insert("EditingInForm", ThisForm);		
	EndIf;
	
	DocumentsFormAtServer.BeforeWriteAtServer(ThisForm, Cancel, CurrentObject, WriteParameters);
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	DocumentsFormAtClient.AfterWrite(ThisForm);
	CloseOnChoice = False;
	NotifyChoice(New Structure("InitialDocumentBase, Ref", InitialDocumentBase, Object.Ref));
	InitialDocumentBase = Object.DocumentBase;
	RecordsAppearanceProcessing();	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	DocumentsFormAtServer.SetFormDocumentTitle(ThisForm);
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	BeforeCloseAtServer();
EndProcedure

&AtServer
Procedure BeforeCloseAtServer()
	
	If IsEmulated Then
		Modified = False;
	EndIf;
	
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
Procedure UpdateDialog() Export	
	
	ControlsProcessingAtClientAtServer.SetControlMarkIncompleteAndEnable(Items.Currency,Object.Currency,(Object.OperationType <> PredefinedValue("Enum.OperationTypesBookkeepingOperation.BasedOnDocument")));
	ControlsProcessingAtClientAtServer.SetControlMarkIncompleteAndEnable(Items.ExchangeRate,Object.ExchangeRate,(Object.OperationType <> PredefinedValue("Enum.OperationTypesBookkeepingOperation.BasedOnDocument")));
	
	IsFilledBookkeepingOperationsTemplate = ValueIsFilled(Object.BookkeepingOperationsTemplate);
	Items.ButtonFillAllRecords.Enabled = IsFilledBookkeepingOperationsTemplate;
	
	Items.RecordsFilling.ChildItems.ButtonGenerateRecordsFromBookkeepingOperationsTemplates.Enabled 			   = IsFilledBookkeepingOperationsTemplate;
	Items.SalesVATFilling.ChildItems.ButtonGenerateSalesVATRecordsFromBookkeepingOperationsTemplates.Enabled       = IsFilledBookkeepingOperationsTemplate;
	Items.PurchaseVATFilling.ChildItems.ButtonGeneratePurchaseVATRecordsFromBookkeepingOperationsTemplates.Enabled = IsFilledBookkeepingOperationsTemplate;
	
	Items.RecordsCommandBar.ChildItems.ButtonRecordsAllowChanges.Enabled                = IsFilledBookkeepingOperationsTemplate;
	Items.SalesVATRecordsCommandBar.ChildItems.ButtonSalesVATAllowChanges.Enabled       = IsFilledBookkeepingOperationsTemplate;
	Items.PurchaseVATRecordsCommandBar.ChildItems.ButtonPurchaseVATAllowChanges.Enabled = IsFilledBookkeepingOperationsTemplate;
	
	Items.RecordsCommandBar.ChildItems.ButtonRecordsAllowChanges.Check 				  = Object.Manual And IsFilledBookkeepingOperationsTemplate;
	Items.SalesVATRecordsCommandBar.ChildItems.ButtonSalesVATAllowChanges.Check 	  = Object.Manual And IsFilledBookkeepingOperationsTemplate;
	Items.PurchaseVATRecordsCommandBar.ChildItems.ButtonPurchaseVATAllowChanges.Check = Object.Manual And IsFilledBookkeepingOperationsTemplate;
	
	If Object.OperationType = PredefinedValue("Enum.OperationTypesBookkeepingOperation.BasedOnDocument") Then
		Items.DocumentBase.Visible = True;
		Items.GroupBasedOn.Visible = False;
	Else
		Items.DocumentBase.Visible = False;
		Items.GroupBasedOn.Visible = True;
	EndIf;
	
	If IsEmulated Then
		Items.FormCommandBar.Enabled = False;
	EndIf;
	Items.DocumentBase.MarkIncomplete = (Object.OperationType = PredefinedValue("Enum.OperationTypesBookkeepingOperation.BasedOnDocument")) AND ValueIsNotFilled(Object.DocumentBase);	
	
	RefreshTotals();
	
	DocumentsFormAtClient.UpdateDialog(ThisForm);
	
EndProcedure // UpdateDialog()

&AtClient
Procedure PrintBookkeepingOperation(Command)	
	PrintManagerClient.PrintBookkeepingOperation(ThisForm);	
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
	
	If Object.OperationType = PredefinedValue("Enum.OperationTypesBookkeepingOperation.BasedOnDocument")
		OR Object.OperationType = PredefinedValue("Enum.OperationTypesBookkeepingOperation.ClosePeriod") Then
		Object.InitialDocumentDate = '00010101';
		Object.InitialDocumentNumber = "";
	Else
		Object.DocumentBase = Undefined;
		Object.Manual = True;
		
	EndIf;
	
	//SetNumberPresentation();		
	
	UpdateDialog();
EndProcedure

&AtClient
Procedure PrefixOnChange(SelectedElement, AdditionalParameters) Export
	If SelectedElement = Undefined Then
		Return;
	EndIf;
	// Jack 25.06.2017
	// to do	
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

&AtClient
Procedure BookkeepingOperationsTemplateStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing=False;
	ParametersForm = New Structure();
	ParametersForm.Insert("ChoiceMode",True);	
	
	If Object.OperationType = PredefinedValue("Enum.OperationTypesBookkeepingOperation.BasedOnDocument") Then
		ParametersForm.Insert("DocumentFilter",Object.DocumentBase);					
	Else
		ParametersForm.Insert("Filter_DocumentBase",Undefined);				
	EndIf;
	
	NotifyDescription = New NotifyDescription("FillingBookkeepingOperationsTemplateResponse",ThisForm);		
	OpenForm("Catalog.BookkeepingOperationsTemplates.ChoiceForm",ParametersForm,Item,,,,NotifyDescription);					
EndProcedure

&AtClient
Procedure FillingBookkeepingOperationsTemplateResponse(Result, ParametersStructure) Export
	If Result <> Undefined Then
		Object.BookkeepingOperationsTemplate=Result;
	EndIf;	
EndProcedure	

&AtClient
Procedure BookkeepingOperationsTemplateOnChange(Item)
	Object.Description = CommonUse.GetAttributeValue(Object.BookkeepingOperationsTemplate,"DescriptionForBookkeepingOperation");
	Object.PartialJournal = CommonUse.GetAttributeValue(Object.BookkeepingOperationsTemplate,"PartialJournal");	
	BookkeepingOperationsTemplateDocumentBase = CommonUse.GetAttributeValue(Object.BookkeepingOperationsTemplate,"DocumentBase");
	If BookkeepingOperationsTemplateDocumentBase <> Undefined Then
		
		If Object.DocumentBase = Undefined 
			OR TypeOf(BookkeepingOperationsTemplateDocumentBase) <> TypeOf(Object.DocumentBase) Then
			
			Object.DocumentBase = BookkeepingOperationsTemplateDocumentBase;
			
		EndIf;
		
	EndIf;
	
	If ValueIsNotFilled(Object.BookkeepingOperationsTemplate) Then
		Object.Manual = True;
	Else
		Object.Manual = False;
	EndIf;
	
	If NOT Object.Manual Then
		Object.Records.Clear();
		Object.SalesVATRecords.Clear();
		Object.PurchaseVATRecords.Clear();
	EndIf;
	
	//SetNumberPresentation();	
	UpdateDialog();
EndProcedure

&AtClient
Procedure BookkeepingOperationsTemplateClearing(Item, StandardProcessing)
	Object.Manual = True;
	Object.DocumentBase = Undefined;	
	UpdateDialog();
EndProcedure

&AtClient
Procedure DocumentBaseStartChoice(Item, ChoiceData, StandardProcessing)
	If Object.DocumentBase<>Undefined Then
		Items.DocumentBase.ChooseType = False;
	Else
		Items.DocumentBase.ChooseType = True;
	EndIf;
EndProcedure

&AtClient
Procedure DocumentBaseOnChange(Item)
	DocumentBaseOnChangeAtServer();
	RecordsAppearanceProcessing();
	UpdateDialog();
EndProcedure

&AtServer
Procedure DocumentBaseOnChangeAtServer()
	If NOT BookkeepingCommon.GetStatusOfBookkeepingOperationTemplatesForDocument(Object.BookkeepingOperationsTemplate, Object.DocumentBase) Then
		Object.BookkeepingOperationsTemplate = Catalogs.BookkeepingOperationsTemplates.EmptyRef();
	EndIf;
	
	If Object.DocumentBase<> Undefined Then
		DocumentObject = FormDataToValue(Object, Type("DocumentObject.BookkeepingOperation"));
		DocumentObject.FillCurrencyAndExchangeRateOnDocumentBase();		
		ValueToFormData(DocumentObject, Object);
	EndIf;

	If NOT Object.Manual Then
		
		Object.Records.Clear();
		
	EndIf;	
EndProcedure


&AtClient
Procedure CurrencyOnChange(Item)
	Object.ExchangeRate = CommonAtServer.GetExchangeRate(Object.Currency, Object.Date);
	
	RecalculateAmountsAccordingToExchangeRate();
EndProcedure

&AtClient
Procedure ExchangeRateOnChange(Item)
	RecalculateAmountsAccordingToExchangeRate();
EndProcedure

&AtClient
Procedure ExchangeRateStartChoice(Item, ChoiceData, StandardProcessing)
	OldExchangeRate = Object.ExchangeRate;
	
	DialogsAtClient.ExchangeRateStartListChoice(Item, StandardProcessing, ThisForm, Object.Currency, Object.ExchangeRate);
	
	If OldExchangeRate <> Object.ExchangeRate Then
		RecalculateAmountsAccordingToExchangeRate();
	EndIf;
EndProcedure


&AtClient
Procedure PartialJournalOnChange(Item)
	SetNumberPresentation();		
EndProcedure

#EndRegion

#Region RecordsEvents
&AtClient
Procedure RecordsOnStartEdit(Item, NewRow, Clone)
	CurrentData = Item.CurrentData;
	
	If NewRow Then
		CurrentData.Type = PredefinedValue("Enum.BookkeepingOperationRecordTypes.Manual");
	EndIf;	
EndProcedure

&AtClient
Procedure RecordsOnActivateRow(Item)
	If Items.Records.CurrentData<>Undefined Then			
		AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("Account","RecordsExtDimension",Items.Records.CurrentData,Items.RecordsGroupExtDimension.ChildItems);		
	EndIf;
EndProcedure

&AtClient
Procedure RecordsBeforeDeleteRow(Item, Cancel)
	SetRowAvailability(Item, Cancel);		
EndProcedure

&AtClient
Procedure RecordsBeforeRowChange(Item, Cancel)
	SetRowAvailability(Item, Cancel);		
EndProcedure

&AtClient
Procedure RecordsAfterDeleteRow(Item)
	RefreshTotals();
EndProcedure

&AtClient
Procedure RecordsOnEditEnd(Item, NewRow, CancelEdit)
	RecordsAppearanceProcessing();
	
	RefreshTotals();
EndProcedure

&AtClient
Procedure RecordsAccountOnChange(Item)
	CurrentData = Items.Records.CurrentData;		
	AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("Account","RecordsExtDimension",Items.Records.CurrentData,Items.RecordsGroupExtDimension.ChildItems);	
	
	RecordsAppearanceProcessing();
	If CommonUse.GetAttributeValue(CurrentData.Account,"Currency") Then
		CurrentData.Currency = Object.Currency;
	Else
		CurrentData.Currency = PredefinedValue("Catalog.Currencies.EmptyRef");
		CurrentData.CurrencyAmount = 0;
	EndIf;

EndProcedure

&AtClient
Procedure RecordsCurrencyAmountStartChoice(Item, ChoiceData, StandardProcessing)
	ValueArray = New Array;
	CurrentRow = Object.Records.FindByID(Items.Records.CurrentRow);	
	If CommonUse.GetAttributeValue(CurrentRow.Account,"Currency") And CurrentRow.Currency = Object.Currency And Object.ExchangeRate <> 0 Then
		ValueArray.Add(Round((CurrentRow.AmountDr + CurrentRow.AmountCr) / Object.ExchangeRate, 2));
	EndIf;
	
	DialogsAtClient.NumericValueStartListChoice(Item, StandardProcessing, ThisForm, ValueArray, "Records", "CurrencyAmount");
	RecordsCurrencyAmountOnChange(Undefined);
EndProcedure

&AtClient
Procedure RecordsCurrencyAmountOnChange(Item)
	CurrentRow = Object.Records.FindByID(Items.Records.CurrentRow);
	If CurrentRow.AmountDr <> 0 Then
		CurrentRow.AmountCr = 0;
	EndIf;
EndProcedure

&AtClient
Procedure RecordsAmountDrStartChoice(Item, ChoiceData, StandardProcessing)
	ValueArray = GetAmountArrayValue(Items.Records.CurrentRow);	
	DialogsAtClient.NumericValueStartListChoice(Item, StandardProcessing, ThisForm, ValueArray, "Records", "AmountDr");
	RecordsAmountDrOnChange(Undefined);
EndProcedure

&AtClient
Function GetAmountArrayValue(RowID)
	ValueArray = New Array;
	CurrentRow = Object.Records.FindByID(RowID);	
	If CommonUse.GetAttributeValue(CurrentRow.Account,"Currency") And CurrentRow.Currency = Object.Currency  Then
		ValueArray.Add(Round(CurrentRow.CurrencyAmount * Object.ExchangeRate, 2));
	EndIf;
	Return ValueArray; 
EndFunction

&AtClient
Procedure RecordsAmountDrOnChange(Item)
	CurrentRow = Object.Records.FindByID(Items.Records.CurrentRow);
	If CurrentRow.AmountDr <> 0 Then
		CurrentRow.AmountCr = 0;
	EndIf;
	
	If CommonUse.GetAttributeValue(CurrentRow.Account,"Currency") And CurrentRow.Currency = Object.Currency And CurrentRow.CurrencyAmount = 0 And Object.ExchangeRate <> 0 Then
		CurrentRow.CurrencyAmount = CurrentRow.AmountDr / Object.ExchangeRate;
	EndIf;
EndProcedure

&AtClient
Procedure RecordsAmountCrStartChoice(Item, ChoiceData, StandardProcessing)
	ValueArray = GetAmountArrayValue(Items.Records.CurrentRow);	
	DialogsAtClient.NumericValueStartListChoice(Item, StandardProcessing, ThisForm, ValueArray, "Records", "AmountCr");
	RecordsAmountCrOnChange(Undefined);
EndProcedure

&AtClient
Procedure RecordsAmountCrOnChange(Item)
	CurrentRow = Object.Records.FindByID(Items.Records.CurrentRow);		
	
	If CurrentRow.AmountCr <> 0 Then
		CurrentRow.AmountDr = 0;
	EndIf;
	
	If CommonUse.GetAttributeValue(CurrentRow.Account,"Currency") And CurrentRow.Currency = Object.Currency And CurrentRow.CurrencyAmount = 0 And Object.ExchangeRate <> 0 Then
		CurrentRow.CurrencyAmount = CurrentRow.AmountCr / Object.ExchangeRate;
	EndIf;
	
EndProcedure

#EndRegion

#Region PurchaseVATEvents
&AtClient
Procedure PurchaseVATRecordsOnStartEdit(Item, NewRow, Clone)
	CurrentData = Item.CurrentData;
	
	If NewRow Then
		CurrentData.Type = PredefinedValue("Enum.BookkeepingOperationRecordTypes.Manual");
	EndIf;
EndProcedure

&AtClient
Procedure PurchaseVATRecordsBeforeRowChange(Item, Cancel)
	SetRowAvailability(Item, Cancel);		
EndProcedure


&AtClient
Procedure PurchaseVATRecordsBeforeDeleteRow(Item, Cancel)
	SetRowAvailability(Item, Cancel);		
EndProcedure

&AtClient
Procedure PurchaseVATRecordsAfterDeleteRow(Item)
	PurchaseVATAppearanceProcessing();
	
	RefreshTotals();
EndProcedure

&AtClient
Procedure PurchaseVATRecordsOnEditEnd(Item, NewRow, CancelEdit)
	PurchaseVATAppearanceProcessing();
	
	RefreshTotals();
EndProcedure

&AtClient
Procedure PurchaseVATRecordsNetAmountOnChange(Item)
	RecalculateVATOnNetAmountOrVATRateChange(Items.PurchaseVATRecords.CurrentData);
EndProcedure

&AtClient
Procedure PurchaseVATRecordsVATRateOnChange(Item)
	RecalculateVATOnNetAmountOrVATRateChange(Items.PurchaseVATRecords.CurrentData);
EndProcedure

#EndRegion

#Region SalesVATEvents

&AtClient
Procedure SalesVATRecordsOnStartEdit(Item, NewRow, Clone)
	CurrentData = Item.CurrentData;
	
	If NewRow Then
		CurrentData.Type = PredefinedValue("Enum.BookkeepingOperationRecordTypes.Manual");
	EndIf;
EndProcedure

&AtClient
Procedure SalesVATRecordsBeforeRowChange(Item, Cancel)
	SetRowAvailability(Item, Cancel);	
EndProcedure

&AtClient
Procedure SalesVATRecordsBeforeDeleteRow(Item, Cancel)
	SetRowAvailability(Item, Cancel);		
EndProcedure

&AtClient
Procedure SalesVATRecordsAfterDeleteRow(Item)
	SalesVATAppearanceProcessing();
	
	RefreshTotals();
EndProcedure

&AtClient
Procedure SalesVATRecordsOnEditEnd(Item, NewRow, CancelEdit)
	SalesVATAppearanceProcessing();
	
	RefreshTotals();
EndProcedure

&AtClient
Procedure SalesVATRecordsNetAmountOnChange(Item)
	RecalculateVATOnNetAmountOrVATRateChange(Items.SalesVATRecords.CurrentData);
EndProcedure

&AtClient
Procedure SalesVATRecordsVATRateOnChange(Item)
	RecalculateVATOnNetAmountOrVATRateChange(Items.SalesVATRecords.CurrentData);
EndProcedure

#EndRegion

#Region Other
&AtClient
Procedure ShowFirstFilledTabularPart()
	
	ItemPages = Items.Pages;
	ItemPages.CurrentPage = ItemPages.ChildItems.GroupRecords;
	
	If Object.Records.Count() = 0 Then
		ItemPages.CurrentPage = ItemPages.ChildItems.GroupSalesVATRecords;
		If Object.SalesVATRecords.Count() = 0 Then
			ItemPages.CurrentPage = ItemPages.ChildItems.GroupPurchaseVATRecords;
			If Object.PurchaseVATRecords.Count() = 0 Then
				ItemPages.CurrentPage = ItemPages.ChildItems.GroupRecords;
			EndIf;	
		EndIf;	
	EndIf;
	
EndProcedure

&AtClient
Procedure FillAllRecords(Command)
	GenerateRecordsFromBookkeepingOperationsTemplates(0);
	
	RecordsAppearanceProcessing();
	SalesVATAppearanceProcessing();
	PurchaseVATAppearanceProcessing();
	
	RefreshTotals();
EndProcedure

&AtClient
Procedure CommandGenerateRecordsFromBookkeepingOperationsTemplates(Command)
	GenerateRecordsFromBookkeepingOperationsTemplates(1);
	
	RecordsAppearanceProcessing();
	
	RefreshTotals();
EndProcedure

&AtClient
Procedure CommandGenerateSalesVATRecordsFromBookkeepingOperationsTemplates(Command)
	GenerateRecordsFromBookkeepingOperationsTemplates(2);
	
	SalesVATAppearanceProcessing();
	
	RefreshTotals();
EndProcedure

&AtClient
Procedure CommandGeneratePurchaseVATRecordsFromBookkeepingOperationsTemplates(Command)
	GenerateRecordsFromBookkeepingOperationsTemplates(3);
	
	PurchaseVATAppearanceProcessing();
	
	RefreshTotals();
EndProcedure

&AtClient
Procedure CommandAllowChanges(Command)
	Object.Manual = Not Items.RecordsCommandBar.ChildItems.ButtonRecordsAllowChanges.Check;
	
	If NOT Object.Manual Then
		// after change Manual to True need regenarate auto records		
		ShowQueryBox(New NotifyDescription("AllowChangesConfirmationAnswer", ThisForm), Nstr("en = 'All auto records will be regenerated!'; pl = 'Wszystkie automatyczne wpisy zostaną wygenerowane ponownie!'"), QuestionDialogMode.YesNo, 30, DialogReturnCode.Yes, , DialogReturnCode.Yes);
	Else
		UpdateDialog();		
	EndIf;	
EndProcedure

&AtClient
Procedure AllowChangesConfirmationAnswer(Answer, Parameters)  Export
	If Answer = DialogReturnCode.No Then
		Object.Manual = True;		
	ElsIf Answer = DialogReturnCode.Yes Then		
		GenerateRecordsFromBookkeepingOperationsTemplates(0);
		RecordsAppearanceProcessing();
		SalesVATAppearanceProcessing();
		PurchaseVATAppearanceProcessing();
		
		RefreshTotals();
		
	EndIf;
	UpdateDialog();	
EndProcedure

&AtClient
Procedure RefreshTotals()
	TotalAmountDifference = FormatAmount(Object.Records.Total("AmountDr") - Object.Records.Total("AmountCr"));
	
	SalesVATGrossAmountTotal = Object.SalesVATRecords.Total("NetAmount") + Object.SalesVATRecords.Total("VAT");
	Items.SalesVATRecordsGrossAmount.FooterText = ?(SalesVATGrossAmountTotal > 0, FormatAmount(SalesVATGrossAmountTotal),"");
	
	PurchaseVATGrossAmounttotal = Object.PurchaseVATRecords.Total("NetAmount") + Object.PurchaseVATRecords.Total("VAT");
	Items.PurchaseVATRecordsGrossAmount.FooterText = ?(PurchaseVATGrossAmounttotal > 0,FormatAmount(PurchaseVATGrossAmounttotal),"");		
EndProcedure

&AtClient
Procedure RecordsAppearanceProcessing()
	RecordsAppearanceProcessingAtServer();	
EndProcedure

&AtServer
Procedure RecordsAppearanceProcessingAtServer()
	MaxAccountExtDimensionsCount = CommonAtServerCached.GetBookkeepingMaxExtDimensionsCount();	
	For Each RecordRow In Object.Records Do
		If RecordRow.AmountDr <> 0 Then
			RecordRow.Icon = PictureLib.Debit;
		ElsIf RecordRow.AmountCr <> 0 Then
			RecordRow.Icon = PictureLib.Credit;
		EndIf;
		RecordRow.AccountCurrency = RecordRow.Account.Currency;		
		
		AccountExtDimensionsCount = CommonAtServerCached.GetBookkeepingAccountExtDimensionsCount(RecordRow.Account);
			
		For Counter = 1 To MaxAccountExtDimensionsCount Do
			If Counter <= AccountExtDimensionsCount Then
				RecordRow["ExtDimensionMandatory"+Counter] = RecordRow.Account.ExtDimensionTypes[Counter-1].Mandatory;	
				RecordRow["ExtDimensionExist"+Counter] = True;				
			Else
				RecordRow["ExtDimensionMandatory"+Counter] = False;			
				RecordRow["ExtDimensionExist"+Counter] = False;								
			EndIf;
		EndDo;			
	EndDo;
	
EndProcedure

&AtClient
Procedure PurchaseVATAppearanceProcessing()
	PurchaseVATAppearanceProcessingAtServer();	
EndProcedure

&AtServer
Procedure PurchaseVATAppearanceProcessingAtServer()
	
	For Each RecordRow In Object.PurchaseVATRecords Do
		// Jack 25.06.2017
		// to do
		RecordRow.GrossAmount = FormatAmount(DocumentsTabularPartsProcessingAtClientAtServer.GetGrossAmount(RecordRow.NetAmount, RecordRow.VAT, PredefinedValue("Enum.NetGross.Net")));	
	EndDo;
	
EndProcedure

&AtClient
Procedure SalesVATAppearanceProcessing()
	SalesVATAppearanceProcessingAtServer();	
EndProcedure

&AtServer
Procedure SalesVATAppearanceProcessingAtServer()
	
	For Each RecordRow In Object.SalesVATRecords Do
		// Jack 25.06.2017
		// to do
		RecordRow.GrossAmount = FormatAmount(DocumentsTabularPartsProcessingAtClientAtServer.GetGrossAmount(RecordRow.NetAmount, RecordRow.VAT, PredefinedValue("Enum.NetGross.Net")));	
	EndDo;
	
EndProcedure

&AtClient
Procedure RecalculateVATOnNetAmountOrVATRateChange(CurrentRow)
		
	If CurrentRow <> Undefined Then
		
		// Jack 25.06.2017
		// to do
		CurrentRow.VAT = DocumentsTabularPartsProcessing.GetItemsLinesRowVATAmount(CurrentRow.NetAmount, CurrentRow.VATRate, PredefinedValue("Enum.NetGross.Net"));
		
	EndIf;	
	
EndProcedure

&AtClient
Procedure RecalculateAmountsAccordingToExchangeRate()
	
	If Object.Records.Count() > 0 AND Object.Manual Then
		ShowQueryBox(New NotifyDescription("NationalAmountsRecalculationAnswer", ThisForm), NStr("en='Do you want to recalculate national amounts in existing rows?';pl='Czy chcesz przeliczyć kwoty w walucie krajowej w istniejących wierszach?'"), QuestionDialogMode.YesNo);
	EndIf;
		
EndProcedure // RecalculateAmountsAccordingToExchangeRate()

&AtClient
Procedure NationalAmountsRecalculationAnswer(Answer, Parameters) Export
	If Answer = DialogReturnCode.Yes Then
		For Each RecordsRow In Object.Records Do		
			If CommonUse.GetAttributeValue(RecordsRow.Account,"Currency") And RecordsRow.Currency = Object.Currency Then
				If RecordsRow.AmountDr <> 0 Then
					RecordsRow.AmountDr = RecordsRow.CurrencyAmount * Object.ExchangeRate;
				ElsIf RecordsRow.AmountCr <> 0 Then
					RecordsRow.AmountCr = RecordsRow.CurrencyAmount * Object.ExchangeRate;
				EndIf;
			EndIf;	
		EndDo;
	EndIf;	
EndProcedure 

// If TableIndex = 0 - Then will be filled all:  VATRecords,SalesVATRecords,PurchaseVATRecords
// If TableIndex = 1 - Then will be filled VATRecords
// If TableIndex = 2 - Then will be filled SalesVATRecords
// If TableIndex = 3 - Then will be filled PurchaseVATRecords
&AtClient
Procedure GenerateRecordsFromBookkeepingOperationsTemplates(TableIndex = 0) Export
	
	If ValueIsNotFilled(Object.BookkeepingOperationsTemplate) Then
		ShowMessageBox( , NStr("en='Please, choose bookkeeping operation template.';pl='Należy wybrać schemat księgowania.'"));
		Return;		
	EndIf;
	
	RefreshParameters();
	
	ParametersFormSettings = FillParametersFormSettings();
	NeedToOpenForm = False;
	
	IsNotFilledValue = CheckForNotFilledValue(ParametersFormSettings.ParametersTableArray);
	If Object.OperationType = PredefinedValue("Enum.OperationTypesBookkeepingOperation.BasedOnDocument")  Then
		If IsNotFilledValue  Then
			NeedToOpenForm = True;			
		EndIf;			
	Else		
		If Object.RequestedParameters.Count() > 0 Then
			NeedToOpenForm = True;			
		EndIf;	
	EndIf;	
	
	If NeedToOpenForm Then
		NotifyParameters = New Structure;
		NotifyParameters.Insert("TableIndex",TableIndex);
		NotifyDescription = New NotifyDescription("OpenFormParametersResponse",ThisForm,NotifyParameters);	
		OpenForm("Document.BookkeepingOperation.Form.ParametersManaged",ParametersFormSettings,,,,,NotifyDescription);
		Return;
	EndIf;
		
	GenerateRecordsFromBookkeepingOperationsTemplatesAtServer(ParametersFormSettings.ParametersTableArray, TableIndex);		
	UpdateDialog();		
    RecordsAppearanceProcessing();
EndProcedure

&AtClient
Function CheckForNotFilledValue(ParametersTable)
	IsNotFilledValue = False;
	For each Row In ParametersTable Do
		If ValueIsNotFilled(Row.Value) Then
			IsNotFilledValue = True;
		EndIf;	
	EndDo;
	Return IsNotFilledValue;
EndFunction	

&AtClient
Procedure OpenFormParametersResponse(Result, ParametersStructure) Export
	If Result <> Undefined Then
		GenerateRecordsFromBookkeepingOperationsTemplatesAtServer(Result.ParametersTableArray, ParametersStructure.TableIndex);
		UpdateDialog();			
	    RecordsAppearanceProcessing();		
	EndIf;	
EndProcedure	

&AtServer
Procedure GenerateRecordsFromBookkeepingOperationsTemplatesAtServer(ParametersTableArray, TableIndex)
	ParametersTable = New ValueTable;
	ParametersTable.Columns.Add("Name");
	ParametersTable.Columns.Add("Presentation");
	ParametersTable.Columns.Add("Value");	
	For Each ParametersRow In ParametersTableArray Do
		NewParametersRow = ParametersTable.Add();
		FillPropertyValues(NewParametersRow, ParametersRow);
	EndDo;

	Object.Description = Object.BookkeepingOperationsTemplate.DescriptionForBookkeepingOperation;
	Object.PartialJournal = Object.BookkeepingOperationsTemplate.PartialJournal;
	
	If Object.OperationType = Enums.OperationTypesBookkeepingOperation.BasedOnDocument Then
			
		If ParametersTable.Count() > 0 Then
				
			DocumentBaseFoundRows = ParametersTable.FindRows(New Structure("Name", "DocumentBase"));
			If DocumentBaseFoundRows.Count() > 0 Then
				Object.DocumentBase = DocumentBaseFoundRows[0].Value;
			EndIf;	
			
		EndIf;
			
	EndIf;
		
	If ParametersTable = Undefined Then
		Return;
	EndIf;
	
	Object.RequestedParameters.Clear();
	For Each ParametersRow In ParametersTable Do
		NewParametersRow = Object.RequestedParameters.Add();
		FillPropertyValues(NewParametersRow, ParametersRow);
	EndDo;
	
	DocumentObject = FormDataToValue(Object, Type("DocumentObject.BookkeepingOperation"));
	BookkeepingOperationsTemplateObject = Object.BookkeepingOperationsTemplate.GetObject();
		
	If TableIndex = 0 Then
		BookkeepingOperationsTemplateObject.FillBookkeepingDocument(Object.DocumentBase, DocumentObject);
	ElsIf TableIndex = 1 Then
		BookkeepingOperationsTemplateObject.FillBookkeepingDocumentRecords(Object.DocumentBase, DocumentObject);
	ElsIf TableIndex = 2 Then
		BookkeepingOperationsTemplateObject.FillBookkeepingDocumentSalesVATRecords(Object.DocumentBase, DocumentObject);
	ElsIf TableIndex = 3 Then	
		BookkeepingOperationsTemplateObject.FillBookkeepingDocumentPurchaseVATRecords(Object.DocumentBase, DocumentObject);
	EndIf;	
	
	ValueToFormData(DocumentObject, Object);
		
EndProcedure

&AtServer
Function FillParametersFormSettings()
	ParametersFormSettings = New Structure;
	
	ValueTableRows = New Array;
	For Each ParametersRow In Object.RequestedParameters.Unload() Do
		ValueTableRows.Add(CommonUse.ValueTableRowToStructure(ParametersRow));
	EndDo;
	
	ParametersFormSettings.Insert("ParametersTableArray", ValueTableRows);
	ParametersFormSettings.Insert("BookkeepingOperationsTemplates", Object.BookkeepingOperationsTemplate);
	ParametersFormSettings.Insert("ChooseDocumentBase", False);	
	If Object.OperationType = Enums.OperationTypesBookkeepingOperation.BasedOnDocument Then
		ParametersFormSettings.Insert("ChooseDocumentBase", True);
		
		TypeDescrArray = New Array();
		TypeDescrArray.Add(TypeOf(Object.DocumentBase));
		ParametersFormSettings.Insert("DocumentBaseTypeDescription", New TypeDescription(TypeDescrArray));
	Else
		If Object.RequestedParameters.Count() = 0 Then
			
			ParametersFormSettings.DoneFlag = True;
			
		EndIf;
	EndIf;
	Return ParametersFormSettings;
Endfunction

// Refills TABULARPART RequestedParameters on standart operation.
// Entered values by user will saved
&AtServer
Procedure RefreshParameters()
	
	ValueTable = Object.RequestedParameters.Unload();
	
	Object.RequestedParameters.Clear();
	
	If Not Object.BookkeepingOperationsTemplate.IsEmpty() Then
		DocumentObject = FormDataToValue(Object, Type("DocumentObject.BookkeepingOperation"));
		DocumentObject.Fill(Object.BookkeepingOperationsTemplate);		
		ValueToFormData(DocumentObject, Object);
	EndIf;
	
	If Object.OperationType = Enums.OperationTypesBookkeepingOperation.Any
		OR Object.OperationType = Enums.OperationTypesBookkeepingOperation.AnyWithRecordsGeneration Then
		For each Parameter In Object.RequestedParameters Do
			
			Row = ValueTable.Find(Parameter.Name, "Name");
			
			If Row = Undefined Then
				Continue
			EndIf;
			
			Parameter.Value = Row.Value;
			
		EndDo;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetRowAvailability(Item, Cancel)
	CurrentData = Item.CurrentData;

	If CurrentData.Type <> PredefinedValue("Enum.BookkeepingOperationRecordTypes.Manual") AND NOT Object.Manual Then
		Cancel = True;		
	EndIf;
EndProcedure

&AtClient
Procedure SetNumberPresentation()
	SetBaseNumberPresentationAtServer();
	UpdateDialog();
EndProcedure

&AtServer
Procedure SetBaseNumberPresentationAtServer()
	DocumentsPostingAndNumberingAtServer.SetBaseNumberPresentationAtServer(ThisForm);	
EndProcedure

#EndRegion





