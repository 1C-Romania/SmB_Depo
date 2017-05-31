
#Region BaseFormsProcedures
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("Date") Then
		Object.Date = Parameters.Date;
	EndIf;
	If Parameters.Property("InitialDocumentNumber") Then
		Object.InitialDocumentNumber = Parameters.InitialDocumentNumber;
	EndIf;
	If Parameters.Property("BankAccount") Then
		Object.BankAccount = Parameters.BankAccount;
		If ValueIsFilled(Object.BankAccount) Then
			ExchangeRate = CommonAtServer.GetExchangeRate(Object.BankAccount.Currency, Object.Date);
			Object.SettlementCurrency = Object.BankAccount.Currency;
			Object.SettlementExchangeRate = ExchangeRate;
		EndIf;
	EndIf;

	DocumentsFormAtServer.OnCreateAtServer(ThisForm, Cancel, StandardProcessing);

	// Filling OtherPartnersList
	SettlementDocuments = Object.SettlementDocuments.Unload().Copy();
	SettlementDocuments.GroupBy("Partner");
	If SettlementDocuments.Count() > 1 Then
		For Each SettlementDocumentRow In SettlementDocuments Do
			If SettlementDocumentRow.Partner = Object.Partner Then
				Continue;
			EndIf;
			NewOtherPartners = OtherPartnersList.Add();
			NewOtherPartners.Partner = SettlementDocumentRow.Partner;
		EndDo;
	EndIf;
	
	RefreshTotalAmount();

	DocumentsFormAtServer.SetExchangeRateListChoice(Items.SettlementExchangeRate, Object.SettlementCurrency);
	If Object.OperationType = Enums.OperationTypesAccountsOutgoing.ForCustomer Then
		Common.AdjustValueToTypeRestriction(Object.Partner, 
			New TypeDescription("CatalogRef.Customers"));
	ElsIf Object.OperationType = Enums.OperationTypesAccountsOutgoing.ForSupplier Then
		Common.AdjustValueToTypeRestriction(Object.Partner, 
			New TypeDescription("CatalogRef.Suppliers"));
	ElsIf Object.OperationType = Enums.OperationTypesAccountsOutgoing.ForEmployee Then
		Common.AdjustValueToTypeRestriction(Object.Partner, 
			New TypeDescription("CatalogRef.Employees"));
	EndIf;

	For Each RowSettlementDocument In Object.SettlementDocuments Do
		If ValueIsFilled(RowSettlementDocument.Document) Then
			SettlementDocumentMetadata = RowSettlementDocument.Document.Metadata();
			If CommonAtServer.IsDocumentAttribute("InitialDocumentNumber", SettlementDocumentMetadata) Then
				RowSettlementDocument.InitialDocumentNumber = RowSettlementDocument.Document.InitialDocumentNumber;
			Else
				RowSettlementDocument.InitialDocumentNumber = "";
			EndIf;	
		Else
			RowSettlementDocument.InitialDocumentNumber = "";
		EndIf;
	EndDo;
	SettlementsChoiceList.Parameters.SetParameterValue("Partner", Object.Partner);
	
	MaxExtDimensionCount = Metadata.ChartsOfAccounts.Bookkeeping.MaxExtDimensionCount;
	For Each CurrentRow In Object.Records Do
		For i = 1 To MaxExtDimensionCount Do
			CurrentRow["ExtDimension" + Format(i,"NG=") + "Mandatory"] = CurrentRow.Account["ExtDimension" + Format(i,"NG=") + "Mandatory"];
		EndDo;
	EndDo;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	DocumentsFormAtClient.OnOpen(ThisForm, Cancel);
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
Procedure SetDocumentBaseType()
	If Object.OperationType = Enums.OperationTypesAccountsOutgoing.Other Then
		If Not ValueIsFilled(Object.Partner) Then
			Object.Partner = Undefined;
		EndIf;
		Items.Partner.ChooseType = True;
	ElsIf Object.OperationType = Enums.OperationTypesAccountsOutgoing.ForCustomer 
		Or Object.OperationType = Enums.OperationTypesAccountsOutgoing.ForSupplier Then
		Items.Partner.ChooseType = False;
		If Object.OperationType = Enums.OperationTypesAccountsOutgoing.ForCustomer Then
			Common.AdjustValueToTypeRestriction(Object.Partner, 
				New TypeDescription("CatalogRef.Customers"));
		ElsIf Object.OperationType = Enums.OperationTypesAccountsOutgoing.ForSupplier Then
			Common.AdjustValueToTypeRestriction(Object.Partner, 
				New TypeDescription("CatalogRef.Suppliers"));
		EndIf;
		SettlementsChoiceList.QueryText = StrReplace(SettlementsChoiceList.QueryText,
		"SELECT
		|	PartnersSettlementsBalance.Employee AS Partner",
		"SELECT
		|	PartnersSettlementsBalance.Partner");
		SettlementsChoiceList.QueryText = StrReplace(SettlementsChoiceList.QueryText,
		"PartnersSettlementsBalance.Employee",
		"PartnersSettlementsBalance.Partner");
		SettlementsChoiceList.QueryText = StrReplace(SettlementsChoiceList.QueryText,
		"AccumulationRegister.EmployeesSettlements.Balance(, Employee = &Partner) AS PartnersSettlementsBalance",
		"AccumulationRegister.PartnersSettlements.Balance(, Partner = &Partner) AS PartnersSettlementsBalance");
	Else
		If Object.OperationType = Enums.OperationTypesAccountsOutgoing.ForEmployee Then
			Common.AdjustValueToTypeRestriction(Object.Partner, 
				New TypeDescription("CatalogRef.Employees"));
		EndIf;
		SettlementsChoiceList.QueryText = StrReplace(SettlementsChoiceList.QueryText,
		"SELECT
		|	PartnersSettlementsBalance.Partner",
		"SELECT
		|	PartnersSettlementsBalance.Employee AS Partner");
		SettlementsChoiceList.QueryText = StrReplace(SettlementsChoiceList.QueryText,
		"PartnersSettlementsBalance.Partner",
		"PartnersSettlementsBalance.Employee");
		SettlementsChoiceList.QueryText = StrReplace(SettlementsChoiceList.QueryText,
		"AccumulationRegister.PartnersSettlements.Balance(, Partner = &Partner) AS PartnersSettlementsBalance",
		"AccumulationRegister.EmployeesSettlements.Balance(, Employee = &Partner) AS PartnersSettlementsBalance");
	EndIf;
	
	OtherOperationType = Object.OperationType = Enums.OperationTypesAccountsOutgoing.Other;
	
	Items.GroupOtherRecords.Visible = OtherOperationType AND SessionParameters.IsBookkeepingAvailable;
	Items.GroupSettlementDocuments.Visible = Not OtherOperationType;
	Items.GroupReservedPrepayments.Visible = Not OtherOperationType;
	Items.GroupGeneralRight.Visible = Not OtherOperationType;
	Items.AutoNationalAmountsCalculation.Visible = Not OtherOperationType;
	Items.Partner.AutoMarkIncomplete = Not OtherOperationType;
	Items.Partner.MarkIncomplete = Not OtherOperationType;
	Items.PrepaymentAmount.Visible = Not OtherOperationType;
	Items.SettlementAmountGroup.Visible = Not OtherOperationType;
	Items.GroupGeneral.Visible = Not OtherOperationType;
EndProcedure

&AtServer
Procedure ChangeDocumentsHeaderAtServer(Recalculate = True) Export
	
	DocumentsFormAtServer.SetFormDocumentTitle(ThisForm);
	SetDocumentBaseType();
	
EndProcedure

&AtClient
Procedure ChangeDocumentsHeader(MainParameters, AdditionalParameters) Export
	DocumentsFormAtClient.ChangeDocumentsHeader(ThisForm, MainParameters, AdditionalParameters);
EndProcedure

&AtClient
Procedure UpdateDialog() Export 
	
	DocumentsFormAtClient.UpdateDialog(ThisForm);
	SetTitleBankAccountCurrency();
	SetOtherOffsettingCurrencyTitle();
	Items.SettlementDocumentsAmountCr.Title = NStr("pl='Należności';en='Owe us';ru='Задолженность'") + " (" + String(Object.SettlementCurrency) + ")";
	Items.SettlementDocumentsAmountDr.Title = NStr("pl='Zobowiązania';en='Our debt';ru='Обязательство'") + " (" + String(Object.SettlementCurrency) + ")";
	Items.ReservedPrepaymentsAmountDr.Title = NStr("en='Amount';pl='Kwota';ru='Сумма'") + " (" + String(Object.SettlementCurrency) + ")";
	If Object.SettlementCurrency = BankAccountCurrency Then
		Items.OtherOffsettingCurrency.Behavior = UsualGroupBehavior.Collapsible;
		Object.AutoNationalAmountsCalculation = True;
		Items.AutoNationalAmountsCalculation.Enabled = False;
	Else
		Items.AutoNationalAmountsCalculation.Enabled = True;
		Items.OtherOffsettingCurrency.Behavior = UsualGroupBehavior.Usual;
	EndIf;
	
	Items.SettlementDocumentsAmountDrNational.Visible = Not Object.AutoNationalAmountsCalculation;
	Items.SettlementDocumentsAmountCrNational.Visible = Not Object.AutoNationalAmountsCalculation;
	Items.ReservedPrepaymentsAmountDrNational.Visible = Not Object.AutoNationalAmountsCalculation;
	
	CountOtherPartners = OtherPartnersList.Count();
	
	Items.ReservedPrepaymentsPaymentMethod.Visible = (Object.OperationType = PredefinedValue("Enum.OperationTypesAccountsOutgoing.ForEmployee"));
	Items.SettlementDocumentsPaymentMethod.Visible = (Object.OperationType = PredefinedValue("Enum.OperationTypesAccountsOutgoing.ForEmployee"));
	Items.PaymentMethod.Visible = (Object.OperationType = PredefinedValue("Enum.OperationTypesAccountsOutgoing.ForEmployee"));
	
	Items.SettlementDocumentsPartner.Visible = (OtherPartnersList.Count() > 0);
		
	Items.AutoExchangeRate.Visible = Object.Ref.IsEmpty() And Not Object.ManualExchangeRate;
	Items.ExchangeRate.Visible = Not Items.AutoExchangeRate.Visible;
	Items.ExchangeRate.Enabled = Object.ManualExchangeRate;
	Items.ExchangeRate.TitleTextColor = WebColors.Black;
	
EndProcedure

&AtServer
Function GetParametersVATTableAtServer()
	
	RowsArray = DocumentsTabularPartsProcessingAtServer.GetArrayRowsTable(Object, "VATLines", New Structure("GrossAmount, NetAmount, VAT, VATRate", "GrossAmount", "NetAmount", "VAT", "VATRate"));
	Return New Structure("RowsVATArrayAddress", PutToTempStorage(RowsArray));
	
EndFunction

&AtClient
Function GetParametersVATTable() Export
	
	Return GetParametersVATTableAtServer();
	
EndFunction

&AtServer
Procedure InitialDocumentDateOnChangeAtServer()
	DocumentsFormAtServer.SetFormDocumentTitle(ThisForm);
EndProcedure

&AtClient
Procedure InitialDocumentDateOnChange(Item)
	InitialDocumentDateOnChangeAtServer();
EndProcedure

#EndRegion

#Region ItemsHeaderEvents
&AtServer
Procedure SettlementDocumentsAmountOnChangeAtServer(AmountName)
	
	CurrentRowIndex = Items.SettlementDocuments.CurrentRow;
	
	If Not CurrentRowIndex = Undefined Then
		CurrentRow = Object.SettlementDocuments.FindByID(CurrentRowIndex);
		APAR.AmountOnChange(CurrentRow, AmountName);
	EndIf;
	
	RefreshTotalAmount();
	
EndProcedure

&AtServer
Procedure PartnerOnChangeAtServer()
	OtherPartnersList_Temp = New ValueList;
	OtherPartnersList_Temp.LoadValues(OtherPartnersList.Unload().UnloadColumn("Partner"));
	DocumentObject = FormDataToValue(Object, Type("DocumentObject." + Object.Ref.Metadata().Name));
	
	If Object.OperationType = Enums.OperationTypesAccountsOutgoing.ForEmployee Then
		APAR.UpdateOtherEmployeesList(DocumentObject,,,Object.Partner, OtherPartnersList_Temp, TakeIntoAccountOtherPartners);
	Else
		APAR.UpdateOtherPartnersList(DocumentObject,,,Object.Partner, OtherPartnersList_Temp, TakeIntoAccountOtherPartners);
	EndIf;
	
	OtherPartnersList.Clear();
	For Each OtherPartnersListValue In OtherPartnersList_Temp Do
		If ValueIsNotFilled(OtherPartnersListValue.Value) Then
			Continue;
		EndIf;
		NewRowOtherPartnersList = OtherPartnersList.Add();
		NewRowOtherPartnersList.Partner = OtherPartnersListValue.Value;
	EndDo;
	
	If Object.OperationType = Enums.OperationTypesAccountsOutgoing.ForEmployee Then
		If ValueIsFilled(Object.BankAccount) Then
			Object.SettlementCurrency = Object.BankAccount.Currency;
		Else
			Object.SettlementCurrency = Constants.NationalCurrency.Get();
		EndIf;
	Else
		If Object.Partner <> Undefined Then
			Object.SettlementCurrency = Object.Partner.Currency;
		EndIf;
	EndIf;
	SettlementCurrencyOnChangeAtServer();
	
	SettlementsChoiceList.Parameters.SetParameterValue("Partner", Object.Partner);
	
	SetPartnerInLine();
EndProcedure

&AtClient
Procedure PartnerOnChange(Item)
	
	PartnerOnChangeAtServer();
	UpdateDialog();
	
EndProcedure

&AtServer
Procedure SettlementCurrencyOnChangeAtServer()
	
	OriginalSettlementExchangeRate = Object.SettlementExchangeRate;
	
	Object.SettlementExchangeRate = CommonAtServer.GetExchangeRate(Object.SettlementCurrency, Object.Date);
	If OriginalSettlementExchangeRate <> Object.SettlementExchangeRate Then
		DocumentObject = FormDataToValue(Object, Type("DocumentObject." + Object.Ref.Metadata().Name));
		APAR.UpdateSettlemenExchangeRate(DocumentObject,Object.SettlementExchangeRate);
		ValueToFormData(DocumentObject, Object);
	EndIf;	
	
	DocumentsFormAtServer.SetExchangeRateListChoice(Items.SettlementExchangeRate, Object.SettlementCurrency);
	
	CalculateSettlementAmount();
	
EndProcedure

&AtClient
Procedure SettlementCurrencyOnChange(Item)
	SettlementCurrencyOnChangeAtServer();
	SetOtherOffsettingCurrencyTitle();
	UpdateDialog();
EndProcedure

&AtServer
Procedure BankAccountOnChangeAtServer()
	
	BankAccountCurrency = "";
	
	If Object.BankAccount.IsEmpty() Then
		Return;
	EndIf;
	
	NewExchangeRate = CommonAtServer.GetExchangeRate(Object.BankAccount.Currency, Object.Date);
	BankAccountCurrency = Object.BankAccount.Currency;
	If NewExchangeRate <> Object.ExchangeRate Then
		Object.ExchangeRate = NewExchangeRate;
		CalculateSettlementAmount();
	EndIf;	
	
	DocumentsFormAtServer.SetExchangeRateListChoice(Items.ExchangeRate, BankAccountCurrency);
	
EndProcedure
	
&AtClient
Procedure BankAccountOnChange(Item)
	BankAccountOnChangeAtServer();
	UpdateDialog();
EndProcedure

&AtClient
Procedure ExchangeRateOnChange(Item)
	SetTitleBankAccountCurrency();
	CalculateSettlementAmount();
EndProcedure

&AtClient
Procedure AmountOnChange(Item)
	CalculateSettlementAmount();
EndProcedure

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
	Object.InitialDocumentDate = Object.Date;
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
	If SelectedElement.Value = "NumberSettings" Then
		OpenForm("InformationRegister.DocumentsNumberingSettings.Form.RecordFormSetting", New Structure("DocumentType", Object.Ref), ThisForm);
		Return;
	EndIf;
	Object["ManualChangeNumber"] = False;
	Object["Prefix"] = SelectedElement.Value;
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

#Region ReservationDocument

&AtServer
Procedure ReservedPrepaymentsAmountDrOnChangeAtServer()
	RefreshTotalAmount();
EndProcedure

&AtClient
Procedure ReservedPrepaymentsAmountDrOnChange(Item)
	ReservedPrepaymentsAmountDrOnChangeAtServer();
EndProcedure

&AtClient
Procedure ReservedPrepaymentsReservationDocumentStartChoice(Item, ChoiceData, StandardProcessing)

EndProcedure

&AtServer
Procedure ReservedPrepaymentsReservationDocumentOnChangeAtServer()
	If Items.ReservedPrepayments.CurrentRow = Undefined Then
		Return;
	EndIf;
	CurrentRow = Object.ReservedPrepayments.FindByID(Items.ReservedPrepayments.CurrentRow);
	CurrentRow.AmountDr = 0;
	If ValueIsFilled(CurrentRow.ReservationDocument) Then
		ReservationDocumentMetadata = CurrentRow.ReservationDocument.Metadata();
		If CommonAtServer.IsDocumentAttribute("Amount", ReservationDocumentMetadata) Then
			CurrentRow.AmountDr = CurrentRow.ReservationDocument.Amount;
			If CommonAtServer.IsDocumentAttribute("AmountType", ReservationDocumentMetadata)
				And Common.IsDocumentTabularPart("VATLines", ReservationDocumentMetadata) Then
				If CurrentRow.ReservationDocument.AmountType = Enums.NetGross.Net Then
					CurrentRow.AmountDr = CurrentRow.AmountDr + CurrentRow.ReservationDocument.VATLines.Total("VAT");
				EndIf;
			EndIf;
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure ReservedPrepaymentsReservationDocumentOnChange(Item)
	ReservedPrepaymentsReservationDocumentOnChangeAtServer();
EndProcedure

&AtServer
Procedure ReservedPrepaymentsOnStartEditAtServer()

	ValueFilterPartner = Object.Partner;
	
	NewArray = New Array();
	NewArray.Add(New ChoiceParameter("Filter_Partner", ValueFilterPartner));
	NewArray.Add(New ChoiceParameter("Filter_Customer", ValueFilterPartner));
	NewArray.Add(New ChoiceParameter("Filter_Supplier", ValueFilterPartner));
	NewArray.Add(New ChoiceParameter("Filter_Owner", ValueFilterPartner));
	NewArray.Add(New ChoiceParameter("Filter_Employee", ValueFilterPartner));
	NewArray.Add(New ChoiceParameter("Filter.Currency", Object.SettlementCurrency));
	NewParameters = New FixedArray(NewArray);
	
	Items.ReservedPrepaymentsReservationDocument.ChoiceParameters = NewParameters;
EndProcedure

&AtClient
Procedure ReservedPrepaymentsOnStartEdit(Item, NewRow, Clone)
	ReservedPrepaymentsOnStartEditAtServer();
EndProcedure
#EndRegion

#Region Other
&AtServer
Procedure SetPartnerInLine()
	If ValueIsFilled(Object.Partner) And OtherPartnersList.Count() = 0 Then
		For Each RowSettlementDocuments In Object.SettlementDocuments Do
			If Not RowSettlementDocuments.Partner = Object.Partner
				Or Not RowSettlementDocuments.Employee = Object.Employee Then
				RowSettlementDocuments.Partner = Object.Partner;
				RowSettlementDocuments.Employee = Object.Employee;
				RowSettlementDocuments.PrepaymentSettlement = Undefined;
				RowSettlementDocuments.ReservationDocument = Undefined;
			EndIf;
		EndDo;
	EndIf;
EndProcedure

&AtServer
Procedure CheckAmountPrepayments()
	If Object.SettlementPrepaymentAmount < TotalReservedPrepayments Then
		Items.GroupReservedPrepayments.Picture = PictureLib.Important_2;
		Items.GroupReservedPrepayments.ToolTipRepresentation = ToolTipRepresentation.ShowTop;
	Else
		Items.GroupReservedPrepayments.Picture = New Picture;
		Items.GroupReservedPrepayments.ToolTipRepresentation = ToolTipRepresentation.None;
	EndIf;
EndProcedure

&AtClient
Procedure SettlementsChoice(Command)
	Items.SettlementDocumentsSettlementsChoice.Check = Not Items.SettlementDocumentsSettlementsChoice.Check;
	Items.GroupSettlementChoice.Visible = Not Items.GroupSettlementChoice.Visible;
EndProcedure

&AtClient
Procedure SettlementsChoiceListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	SettlementsCurrentData = Item.CurrentData;
	
	If SettlementsCurrentData = Undefined Then
		Return;
	EndIf;
	
	NewRow = Object.SettlementDocuments.Add();
	If SettlementsCurrentData.SettlementType = PredefinedValue("Enum.PartnerSettlementTypes.PrepaymentToSupplier") Or 
		SettlementsCurrentData.SettlementType = PredefinedValue("Enum.PartnerSettlementTypes.PrepaymentFromCustomer") Then
		NewRow.PrepaymentSettlement = PredefinedValue("Enum.PrepaymentSettlement.PrepaymentSettlement")
	Else
		NewRow.PrepaymentSettlement = PredefinedValue("Enum.PrepaymentSettlement.Settlement")
	EndIf;
	
	NewRow.Partner = SettlementsCurrentData.Partner;
	NewRow.Document = SettlementsCurrentData.Document;
	NewRow.ReservationDocument = SettlementsCurrentData.ReservationDocument;

	If Object.SettlementCurrency = SettlementsCurrentData.Currency Then
		NewRow[?(SettlementsCurrentData.Amount > 0, "AmountDr", "AmountCr")] = ?(SettlementsCurrentData.Amount < 0, -1, 1) * SettlementsCurrentData.Amount;
	Else
		NewRow[?(SettlementsCurrentData.Amount > 0, "AmountDr", "AmountCr")] = ?(SettlementsCurrentData.Amount < 0, -1, 1) * SettlementsCurrentData.Amount * (SettlementsCurrentData.AmountNationalBalance / SettlementsCurrentData.Amount) / Object.SettlementExchangeRate;
	EndIf;
	
	SettlementDocumentsAmountOnChangeAtServer("AmountDr");
	
EndProcedure

&AtClient
Procedure EmployeeOnChange(Item)
	PartnerOnChangeAtServer();
EndProcedure

&AtServer
Procedure SettlementDocumentsOnStartEditAtServer(CurrentRowIndex)
	CurrentRow = Object.SettlementDocuments.FindByID(CurrentRowIndex);
	Common.AdjustValueToTypeRestriction(CurrentRow.Document, Items.SettlementDocumentsDocument.TypeRestriction);
EndProcedure

&AtClient
Procedure SettlementDocumentsOnStartEdit(Item, NewRow, Clone)
	If Items.SettlementDocuments.CurrentRow = Undefined Then
		Return;
	EndIf;
	CurrentRow = Object.SettlementDocuments.FindByID(Items.SettlementDocuments.CurrentRow);
	Items.SettlementDocumentsPartner.ChoiceList.LoadValues(APAR.GetFullPartnersList(OtherPartnersList, Object.Partner).UnloadValues());
	If Object.OperationType = PredefinedValue("Enum.OperationTypesAccountsOutgoing.ForEmployee") Then
		Items.SettlementDocumentsDocument.TypeRestriction = APAR.GetEmployeesDocumentTypes(CurrentRow.Partner,CurrentRow.PrepaymentSettlement);
	Else
		Items.SettlementDocumentsDocument.TypeRestriction = APAR.GetPartnersDocumentTypes(CurrentRow.Partner,CurrentRow.PrepaymentSettlement);
	EndIf;
	SettlementDocumentsOnStartEditAtServer(Items.SettlementDocuments.CurrentRow);
EndProcedure

&AtClient
Procedure SettlementDocumentsAfterDeleteRow(Item)
	RefreshTotalAmount();
EndProcedure

&AtClient
Procedure ReservedPrepaymentsOnEditEnd(Item, NewRow, CancelEdit)
	RefreshTotalAmount();
EndProcedure

&AtClient
Procedure ReservedPrepaymentsAfterDeleteRow(Item)
	RefreshTotalAmount();
EndProcedure

&AtClient
Procedure OtherPartnersListOnStartEdit(Item, NewRow, Clone)
	
	If Items.OtherPartnersList.CurrentRow = Undefined Then
		Return;
	EndIf;
	
	CurrentRow = OtherPartnersList.FindByID(Items.OtherPartnersList.CurrentRow);
	TypesArray = New Array;
	If Object.OperationType = PredefinedValue("Enum.OperationTypesAccountsOutgoing.ForEmployee") Then
		TypesArray.Add(Type("CatalogRef.Employees"));
	Else
		TypesArray.Add(Type("CatalogRef.Customers"));
		TypesArray.Add(Type("CatalogRef.Suppliers"));
	EndIf;
	
	TypeRestriction = New TypeDescription(TypesArray);
	Items.OtherPartnersListPartner.TypeRestriction = TypeRestriction;
	
EndProcedure

#EndRegion

#Region Common

&AtClient
Procedure SetTitleBankAccountCurrency()
	Items.ExchangeRate.Title = NStr("pl='Kurs';en='Exchange rate';ru='Обменный курс'") + " " + String(BankAccountCurrency);
EndProcedure

&AtServer
Procedure CalculateSettlementAmount()
	
	If Object.BankAccount.Currency = Object.SettlementCurrency Then
		Object.SettlementAmount = Object.Amount;
	ElsIf Object.SettlementExchangeRate <> 0 Then
		Object.SettlementAmount = Object.Amount*Object.ExchangeRate/Object.SettlementExchangeRate;
	EndIf;
	
	If Object.SettlementPrepaymentAmount > Object.SettlementAmount Then
		Object.SettlementPrepaymentAmount = Object.SettlementAmount;
	EndIf;
	RefreshTotalAmount();
	
EndProcedure // CalculateSettlementAmount()

&AtClient
Procedure SetOtherOffsettingCurrencyTitle()
	Items.OtherOffsettingCurrency.Title = NStr("en='Offsetting of debts in currency';pl='Rozliczenie rozrachunków w walucie';ru='Взаиморасчеты в валюте'") + " " + String(Object.SettlementCurrency) + "";
EndProcedure

&AtServer
Procedure RefreshTotalAmount()
	
	TotalAmount = Object.SettlementAmount - Object.SettlementPrepaymentAmount;
	TotalSettlementDocuments = (Object.SettlementDocuments.Total("AmountDr") - Object.SettlementDocuments.Total("AmountCr"));
	TotalReservedPrepayments = Object.ReservedPrepayments.Total("AmountDr");
	
	AmountDifference = TotalAmount - TotalSettlementDocuments;
	
	PrepaymentAmount = Object.Amount - ?(Object.ExchangeRate = 0, 0, TotalSettlementDocuments*Object.SettlementExchangeRate/Object.ExchangeRate);
	Object.SettlementPrepaymentAmount = ?(Object.SettlementExchangeRate = 0, 0, Object.Amount*Object.ExchangeRate/Object.SettlementExchangeRate) - TotalSettlementDocuments;
	
	CheckAmountPrepayments();
	
EndProcedure

&AtClient
Procedure ExchangeRateChoiceProcessing(Item, SelectedValue, StandardProcessing)
	DocumentsFormAtClient.ExchangeRateChoiceProcessing(ThisForm, Item, SelectedValue, StandardProcessing, BankAccountCurrency);
	ExchangeRateOnChange(Item);
EndProcedure

&AtClient
Procedure SettlementExchangeRateOnChange(Item)
	Object.SettlementAmount = Object.Amount * Object.ExchangeRate / Object.SettlementExchangeRate;
	RefreshTotalAmount();
EndProcedure

&AtClient
Procedure SettlementExchangeRateChoiceProcessing(Item, SelectedValue, StandardProcessing)
	DocumentsFormAtClient.ExchangeRateChoiceProcessing(ThisForm, Item, SelectedValue, StandardProcessing, Object.SettlementCurrency);
	SettlementExchangeRateOnChange(Item);
EndProcedure

&AtClient
Procedure SettlementAmountOnChange(Item)
	Object.SettlementExchangeRate = Object.ExchangeRate * Object.Amount / Object.SettlementAmount;

	RefreshTotalAmount();
EndProcedure

&AtServer
Procedure SettlementDocumentsPrepaymentSettlementOnChangeAtServer()
	If Items.SettlementDocuments.CurrentRow = Undefined Then
		Return;
	EndIf;
	CurrentRow = Object.SettlementDocuments.FindByID(Items.SettlementDocuments.CurrentRow);
	
	If ValueIsNotFilled(CurrentRow.Partner) Then
		CurrentRow.Partner = Object.Partner;
	EndIf;
	If Object.OperationType = Enums.OperationTypesAccountsOutgoing.ForEmployee Then
		Items.SettlementDocumentsDocument.TypeRestriction = APAR.GetEmployeesDocumentTypes(CurrentRow.Partner,CurrentRow.PrepaymentSettlement);
	Else
		Items.SettlementDocumentsDocument.TypeRestriction = APAR.GetPartnersDocumentTypes(CurrentRow.Partner,CurrentRow.PrepaymentSettlement);
	EndIf;
	Common.AdjustValueToTypeRestriction(CurrentRow.Document, Items.SettlementDocumentsDocument.TypeRestriction);
EndProcedure

&AtClient
Procedure SettlementDocumentsPrepaymentSettlementOnChange(Item)
	SettlementDocumentsPrepaymentSettlementOnChangeAtServer();
EndProcedure

&AtServer
Procedure SettlementDocumentsPartnerOnChangeAtServer()
	
	If Items.SettlementDocuments.CurrentRow = Undefined Then
		Return;
	EndIf;
	CurrentRow = Object.SettlementDocuments.FindByID(Items.SettlementDocuments.CurrentRow);
	
	DocumentItem = Items.SettlementDocumentsDocument;
	DocumentItem.TypeRestriction = APAR.GetPartnersDocumentTypes(CurrentRow.Partner,CurrentRow.PrepaymentSettlement);
	
	Common.AdjustValueToTypeRestriction(CurrentRow.Document, DocumentItem.TypeRestriction);
	
	APAR.CheckDocumentOnPartnerChange(CurrentRow.Partner, CurrentRow.Document);
	
	If ValueIsNotFilled(CurrentRow.Document) Then
		
		CurrentRow.AmountDr = 0;
		CurrentRow.AmountDrNational = 0;
		CurrentRow.AmountCr = 0;
		CurrentRow.AmountCrNational = 0;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SettlementDocumentsPartnerOnChange(Item)
	SettlementDocumentsPartnerOnChangeAtServer();
EndProcedure

&AtClient
Procedure SettlementDocumentsDocumentOnChange(Item)
	SetRowAmountsOnDocumentChange(Items.SettlementDocuments.CurrentRow);
EndProcedure

&AtServer
Procedure SetRowAmountsOnDocumentChange(CurrentRowIndex)
	
	CurrentRow = Object.SettlementDocuments.FindByID(CurrentRowIndex);

	If ValueIsFilled(CurrentRow.Document) Then
		SettlementDocumentMetadata = CurrentRow.Document.Metadata();
		If CommonAtServer.IsDocumentAttribute("InitialDocumentNumber", SettlementDocumentMetadata) Then
			CurrentRow.InitialDocumentNumber = CurrentRow.Document.InitialDocumentNumber;
		Else
			CurrentRow.InitialDocumentNumber = "";
		EndIf;	
	Else
		CurrentRow.InitialDocumentNumber = "";
	EndIf;
	
	Structure = APAR.GetDocumentAmountsStructureForPartner(CurrentRow.Partner, CurrentRow.Document, CurrentRow.ReservationDocument, Object.SettlementCurrency, , Object.Company);
	CurrentRow.AmountDr = Structure.AmountDr;
	CurrentRow.AmountCr = Structure.AmountCr;
	CurrentRow.AmountDrNational = Structure.AmountDrNational;
	CurrentRow.AmountCrNational = Structure.AmountCrNational;

	RefreshTotalAmount();
EndProcedure

&AtClient
Procedure SettlementDocumentsDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	If Items.SettlementDocuments.CurrentRow = Undefined Then
		Return;
	EndIf;
	CurrentRow = Object.SettlementDocuments.FindByID(Items.SettlementDocuments.CurrentRow);
	ValueFilterPartner = CurrentRow.Partner;
	NewArray = New Array();
	NewArray.Add(New ChoiceParameter("Filter_Partner", ValueFilterPartner));
	NewArray.Add(New ChoiceParameter("Filter_Customer", ValueFilterPartner));
	NewArray.Add(New ChoiceParameter("Filter_Supplier", ValueFilterPartner));
	NewArray.Add(New ChoiceParameter("Filter_Owner", ValueFilterPartner));
	NewArray.Add(New ChoiceParameter("Filter_Employee", ValueFilterPartner));
	NewArray.Add(New ChoiceParameter("Filter.Currency", Object.SettlementCurrency));
	NewParameters = New FixedArray(NewArray);
	Item.ChoiceParameters = NewParameters;
EndProcedure

&AtClient
Procedure SettlementDocumentsReservationDocumentOnChange(Item)
	SetRowAmountsOnDocumentChange(Items.SettlementDocuments.CurrentRow);
EndProcedure

&AtClient
Procedure SettlementDocumentsReservationDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	If Items.SettlementDocuments.CurrentRow = Undefined Then
		Return;
	EndIf;
	CurrentRow = Object.SettlementDocuments.FindByID(Items.SettlementDocuments.CurrentRow);
	ValueFilterPartner = CurrentRow.Partner;
	NewArray = New Array();
	NewArray.Add(New ChoiceParameter("Filter_Partner", ValueFilterPartner));
	NewArray.Add(New ChoiceParameter("Filter_Customer", ValueFilterPartner));
	NewArray.Add(New ChoiceParameter("Filter_Supplier", ValueFilterPartner));
	NewArray.Add(New ChoiceParameter("Filter_Owner", ValueFilterPartner));
	NewArray.Add(New ChoiceParameter("Filter_Employee", ValueFilterPartner));
	NewArray.Add(New ChoiceParameter("Filter_ControlPay", ValueFilterPartner));
	NewArray.Add(New ChoiceParameter("Filter.Currency", Object.SettlementCurrency));
	NewParameters = New FixedArray(NewArray);
	Item.ChoiceParameters = NewParameters;
EndProcedure

&AtClient
Procedure SettlementDocumentsAmountDrOnChange(Item)
	SettlementDocumentsAmountOnChangeAtServer("AmountDr");
EndProcedure

&AtClient
Procedure SettlementDocumentsAmountCrOnChange(Item)
	SettlementDocumentsAmountOnChangeAtServer("AmountCr");
EndProcedure

&AtClient
Procedure AutoNationalAmountsCalculationOnChange(Item)
	UpdateDialog();
EndProcedure

&AtClient
Procedure ManualExchangeRateOnChange(Item)
	UpdateDialog();
EndProcedure

&AtClient
Procedure OtherPartnersListOnChange(Item)
	UpdateDialog();
EndProcedure

&AtClient
Procedure OtherPartnersListOnEditEnd(Item, NewRow, CancelEdit)
	SetPartnerInLine();
	UpdateDialog();
EndProcedure

&AtClient
Procedure OtherPartnersListAfterDeleteRow(Item)
	SetPartnerInLine();
	UpdateDialog();
EndProcedure

&AtServer
Procedure RecordsAccountOnChangeAtServer()
	CurrentRow = Object.Records.FindByID(Items.Records.CurrentRow);
	MaxExtDimensionCount = Metadata.ChartsOfAccounts.Bookkeeping.MaxExtDimensionCount;
	For i = 1 To MaxExtDimensionCount Do
		CurrentRow["ExtDimension" + Format(i,"NG=") + "Mandatory"] = CurrentRow.Account["ExtDimension" + Format(i,"NG=") + "Mandatory"];
	EndDo;
EndProcedure

&AtClient
Procedure RecordsAccountOnChange(Item)
	RecordsAccountOnChangeAtServer();
EndProcedure

#EndRegion

