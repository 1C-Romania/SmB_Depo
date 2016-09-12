
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Procedure calculates the accounting amount.
//
&AtClient
Procedure CalculateAccountingAmount(TabularSectionRow)
	
	TabularSectionRow.ExchangeRate      = ?(TabularSectionRow.ExchangeRate      = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.AccountingAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		TabularSectionRow.ExchangeRate,
		ExchangeRate,
		TabularSectionRow.Multiplicity,
		Multiplicity
	);
	
EndProcedure // CalculateAccountingAmount()

// Procedure calculates the settlements amount.
//
&AtClient
Procedure CalculateSettlementsAmount(TabularSectionRow)
	
	TabularSectionRow.ExchangeRate      = ?(TabularSectionRow.ExchangeRate = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.SettlementsAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.AccountingAmount,
		ExchangeRate,
		TabularSectionRow.ExchangeRate,
		Multiplicity,
		TabularSectionRow.Multiplicity
	);
	
EndProcedure // CalculateSettlementsAmount()

// It receives data set from the server for the CurrencyCashOnChange procedure.
//
&AtServerNoContext
Function GetDataContractOnChange(Date, Contract)
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"CurrencyRateRepetition",
		InformationRegisters.CurrencyRates.GetLast(
			Date,
			New Structure("Currency", Contract.SettlementsCurrency)
		)
	);
	
	Return StructureData;
	
EndFunction // GetDataContractOnChange()

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange)
	
	DATEDIFF = SmallBusinessServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange);
	
	StructureData = New Structure();
	StructureData.Insert(
		"DATEDIFF",
		DATEDIFF
	);
	
	Return StructureData;
	
EndFunction // GetDataDateOnChange()

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert(
		"SubsidiaryCompany",
		SmallBusinessServer.GetCompany(Company)
	);
	
	Return StructureData;
	
EndFunction // GetCompanyDataOnChange()

// Procedure sets choice parameter links.
//
&AtServer
Procedure SetChoiceParameterLinks()
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsNetting.Netting") Then
		NewArray = New Array();
		NewConnection = New ChoiceParameterLink("Filter.Owner", "CounterpartyRecipient");
		NewArray.Add(NewConnection);
		NewConnections = New FixedArray(NewArray);
		Items.Creditor.ChildItems.CreditorContract.ChoiceParameterLinks = NewConnections;
		NewArray = New Array();
		NewConnection = New ChoiceParameterLink("Filter.Counterparty", "CounterpartyRecipient");
		NewArray.Add(NewConnection);
		NewConnections = New FixedArray(NewArray);
		Items.Creditor.ChildItems.CreditorDocument.ChoiceParameterLinks = NewConnections;
		Items.Creditor.ChildItems.CreditorOrder.ChoiceParameterLinks = NewConnections;
		Items.Creditor.ChildItems.CreditorInvoiceForPayment.ChoiceParameterLinks = NewConnections;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsNetting.DebtAssignmentToVendor") Then
		NewArray = New Array();
		NewConnection = New ChoiceParameterLink("Filter.Owner", "Counterparty");
		NewArray.Add(NewConnection);
		NewConnections = New FixedArray(NewArray);
		Items.Creditor.ChildItems.CreditorContract.ChoiceParameterLinks = NewConnections;
		NewArray = New Array();
		NewConnection = New ChoiceParameterLink("Filter.Counterparty", "Counterparty");
		NewArray.Add(NewConnection);
		NewConnections = New FixedArray(NewArray);
		Items.Creditor.ChildItems.CreditorDocument.ChoiceParameterLinks = NewConnections;
		Items.Creditor.ChildItems.CreditorOrder.ChoiceParameterLinks = NewConnections;
		Items.Creditor.ChildItems.CreditorInvoiceForPayment.ChoiceParameterLinks = NewConnections;
	EndIf;
	
EndProcedure // SetChoiceParameterLinks() 

// Procedure sets availability.
//
&AtServer
Procedure SetVisibleAndEnabled()
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsNetting.Netting") Then
		
		Items.Recipient.Visible = False;
		Items.SettlementsWithDebitor.Visible = True;
		Items.PaymentsToCreditor.Visible = True;
		Items.Correspondence.Visible = False;
		Items.Counterparty.Visible = True;
		Items.CounterpartyRecipient.Visible = True;
		Items.Counterparty.Title = "Customer";
		Items.CounterpartyRecipient.Title = "Vendor";
		Items.Pages.PagesRepresentation = FormPagesRepresentation.TabsOnTop;
		
		Items.DebitorContract.Visible = Object.CounterpartySource.DoOperationsByContracts;
		Items.DebitorDocument.Visible = Object.CounterpartySource.DoOperationsByDocuments;
		If ValueIsFilled(Object.CounterpartySource) Then
			Items.DebitorAdvanceFlag.ReadOnly = Object.CounterpartySource.DoOperationsByDocuments;
		Else
			Items.DebitorAdvanceFlag.ReadOnly = True;
		EndIf;
		Items.DebitorDocument.AutoMarkIncomplete = True;
		Items.DebitorOrder.Visible = Object.CounterpartySource.DoOperationsByOrders;
		Items.DebitorInvoiceForPayment.Visible = Object.CounterpartySource.TrackPaymentsByBills;
		
		Items.CreditorContract.Visible = Object.Counterparty.DoOperationsByContracts;
		Items.CreditorDocument.Visible = Object.Counterparty.DoOperationsByDocuments;
		If ValueIsFilled(Object.Counterparty) Then
			Items.CreditorAdvanceFlag.ReadOnly = Object.Counterparty.DoOperationsByDocuments;
		Else
			Items.CreditorAdvanceFlag.ReadOnly = True;
		EndIf;
		Items.CreditorDocument.AutoMarkIncomplete = True;
		Items.CreditorOrder.Visible = Object.Counterparty.DoOperationsByOrders;
		Items.CreditorInvoiceForPayment.Visible = Object.Counterparty.TrackPaymentsByBills;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsNetting.CustomerDebtAssignment") Then
		
		Items.Recipient.Visible = True;
		Items.SettlementsWithDebitor.Visible = True;
		Items.PaymentsToCreditor.Visible = False;
		Items.Correspondence.Visible = False;
		Items.Counterparty.Visible = True;
		Items.CounterpartyRecipient.Visible = True;
		Items.Counterparty.Title = "Customer";
		Items.CounterpartyRecipient.Title = "Customer-recipient";
		Items.Pages.PagesRepresentation = FormPagesRepresentation.TabsOnTop;
		
		Items.DebitorContract.Visible = Object.CounterpartySource.DoOperationsByContracts;
		Items.DebitorDocument.Visible = Object.CounterpartySource.DoOperationsByDocuments;
		If ValueIsFilled(Object.CounterpartySource) Then
			Items.DebitorAdvanceFlag.ReadOnly = Object.CounterpartySource.DoOperationsByDocuments;
		Else
			Items.DebitorAdvanceFlag.ReadOnly = True;
		EndIf;
		Items.DebitorDocument.AutoMarkIncomplete = True;
		Items.DebitorOrder.Visible = Object.CounterpartySource.DoOperationsByOrders;
		Items.DebitorInvoiceForPayment.Visible = Object.CounterpartySource.TrackPaymentsByBills;
		
		Items.Contract.Visible = Object.Counterparty.DoOperationsByContracts;
		Items.AccountsDocument.Visible = Object.Counterparty.DoOperationsByDocuments;
		If ValueIsFilled(Object.Counterparty) Then
			Items.AdvanceFlag.ReadOnly = Object.Counterparty.DoOperationsByDocuments;
		Else
			Items.AdvanceFlag.ReadOnly = True;
		EndIf;
		Items.Order.Visible = Object.Counterparty.DoOperationsByOrders;
		Items.InvoiceForPayment.Visible = Object.Counterparty.TrackPaymentsByBills;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsNetting.DebtAssignmentToVendor") Then
		
		Items.Recipient.Visible = True;
		Items.SettlementsWithDebitor.Visible = False;
		Items.PaymentsToCreditor.Visible = True;
		Items.Correspondence.Visible = False;
		Items.Counterparty.Visible = True;
		Items.CounterpartyRecipient.Visible = True;
		Items.Counterparty.Title = "Vendor";
		Items.CounterpartyRecipient.Title = "Vendor-recipient";
		Items.Pages.PagesRepresentation = FormPagesRepresentation.TabsOnTop;
		
		Items.CreditorContract.Visible = Object.CounterpartySource.DoOperationsByContracts;
		Items.CreditorDocument.Visible = Object.CounterpartySource.DoOperationsByDocuments;
		If ValueIsFilled(Object.CounterpartySource) Then
			Items.CreditorAdvanceFlag.ReadOnly = Object.CounterpartySource.DoOperationsByDocuments;
		Else
			Items.CreditorAdvanceFlag.ReadOnly = True;
		EndIf;
		Items.CreditorDocument.AutoMarkIncomplete = True;
		Items.CreditorOrder.Visible = Object.CounterpartySource.DoOperationsByOrders;
		Items.CreditorInvoiceForPayment.Visible = Object.CounterpartySource.TrackPaymentsByBills;
		
		Items.Contract.Visible = Object.Counterparty.DoOperationsByContracts;
		Items.AccountsDocument.Visible = Object.Counterparty.DoOperationsByDocuments;
		If ValueIsFilled(Object.Counterparty) Then
			Items.AdvanceFlag.ReadOnly = Object.Counterparty.DoOperationsByDocuments;
		Else
			Items.AdvanceFlag.ReadOnly = True;
		EndIf;
		Items.Order.Visible = Object.Counterparty.DoOperationsByOrders;
		Items.InvoiceForPayment.Visible = Object.Counterparty.TrackPaymentsByBills;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsNetting.CustomerDebtAdjustment") Then
		
		Items.Recipient.Visible = False;
		Items.SettlementsWithDebitor.Visible = True;
		Items.PaymentsToCreditor.Visible = False;
		Items.Correspondence.Visible = True;
		Items.Counterparty.Visible = True;
		Items.CounterpartyRecipient.Visible = False;
		Items.Counterparty.Title = "Customer";
		
		Items.DebitorContract.Visible = Object.CounterpartySource.DoOperationsByContracts;
		Items.DebitorDocument.Visible = Object.CounterpartySource.DoOperationsByDocuments;
		Items.DebitorDocument.AutoMarkIncomplete = False;
		Items.DebitorAdvanceFlag.ReadOnly = False;
		Items.DebitorOrder.Visible = Object.CounterpartySource.DoOperationsByOrders;
		Items.DebitorInvoiceForPayment.Visible = Object.CounterpartySource.TrackPaymentsByBills;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsNetting.VendorDebtAdjustment") Then
		
		Items.Recipient.Visible = False;
		Items.SettlementsWithDebitor.Visible = False;
		Items.PaymentsToCreditor.Visible = True;
		Items.Correspondence.Visible = True;
		Items.Counterparty.Visible = False;
		Items.CounterpartyRecipient.Visible = True;
		Items.CounterpartyRecipient.Title = "Vendor";
		
		Items.CreditorContract.Visible = Object.Counterparty.DoOperationsByContracts;
		Items.CreditorDocument.Visible = Object.Counterparty.DoOperationsByDocuments;
		Items.CreditorAdvanceFlag.ReadOnly = False;
		Items.CreditorDocument.AutoMarkIncomplete = False;
		Items.CreditorOrder.Visible = Object.Counterparty.DoOperationsByOrders;
		Items.CreditorInvoiceForPayment.Visible = Object.Counterparty.TrackPaymentsByBills;
		
	EndIf;
	
EndProcedure // SetVisibleAndEnabled()

// Procedure sets selection parameter links and available types.
//
&AtClient
Procedure SetAvailableTypes()
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsNetting.CustomerDebtAssignment") Then
		Array = New Array();
		Array.Add(Type("DocumentRef.FixedAssetsTransfer"));
		Array.Add(Type("DocumentRef.CustomerInvoice"));
		Array.Add(Type("DocumentRef.AgentReport"));
		Array.Add(Type("DocumentRef.AcceptanceCertificate"));
		Array.Add(Type("DocumentRef.ProcessingReport"));
		Array.Add(Type("DocumentRef.CashReceipt"));
		Array.Add(Type("DocumentRef.CustomerOrder"));
		Array.Add(Type("DocumentRef.PaymentReceipt"));
		ValidTypes = New TypeDescription(Array, , );
		Items.AccountsDocument.TypeRestriction = ValidTypes;
		ValidTypes = New TypeDescription("DocumentRef.CustomerOrder", , );
		Items.Order.TypeRestriction = ValidTypes;
		ValidTypes = New TypeDescription("DocumentRef.InvoiceForPayment", , );
		Items.InvoiceForPayment.TypeRestriction = ValidTypes;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsNetting.DebtAssignmentToVendor") Then
		Array = New Array();
		Array.Add(Type("DocumentRef.AdditionalCosts"));
		Array.Add(Type("DocumentRef.PaymentExpense"));
		Array.Add(Type("DocumentRef.CashPayment"));
		Array.Add(Type("DocumentRef.SupplierInvoice"));
		Array.Add(Type("DocumentRef.ExpenseReport"));
		Array.Add(Type("DocumentRef.ReportToPrincipal"));
		Array.Add(Type("DocumentRef.SubcontractorReport"));
		Array.Add(Type("DocumentRef.Netting"));
		ValidTypes = New TypeDescription(Array, , );
		Items.AccountsDocument.TypeRestriction = ValidTypes;
		ValidTypes = New TypeDescription("DocumentRef.PurchaseOrder", , );
		Items.Order.TypeRestriction = ValidTypes;
		ValidTypes = New TypeDescription("DocumentRef.SupplierInvoiceForPayment", , );
		Items.InvoiceForPayment.TypeRestriction = ValidTypes;
	EndIf;
	
EndProcedure // SetAvailableTypesSelectionParameterLinks()

// It gets counterparty contract selection form parameter structure.
//
&AtServerNoContext
Function GetChoiceFormParameters(Document, Company, Counterparty, Contract, OperationKind, TabularSectionName = "")
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractKindsListForDocument(Document, OperationKind, TabularSectionName);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", Counterparty.DoOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractKinds", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

// Checks the document details filling for the correct transfer to PSU.
//
&AtServer
Procedure CheckCorrectnessOfDetailsOfDocumentFill(QuestionText)

	SumAdvancesDebitor  = 0;
	SumAdvancesLender = 0;
	
	ContractsArray = New Array;
	ContractsArray.Add(Object.Contract);
	
	For Each TableRow In Object.Debitor Do
		
		If TableRow.AdvanceFlag Then
			SumAdvancesDebitor = SumAdvancesDebitor + TableRow.SettlementsAmount;
		EndIf;
		
		ContractsArray.Add(TableRow.Contract);
	EndDo;
	
	For Each TableRow In Object.Creditor Do
		
		If TableRow.AdvanceFlag Then
			SumAdvancesLender = SumAdvancesLender + TableRow.SettlementsAmount;
		EndIf;
		
		ContractsArray.Add(TableRow.Contract);
	EndDo;
	
	// Checking the availability of several currencies
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency
	|FROM
	|	Catalog.CounterpartyContracts AS CounterpartyContracts
	|WHERE
	|	CounterpartyContracts.Ref In(&ContractsArray)
	|	AND CounterpartyContracts.Ref <> VALUE(Catalog.CounterpartyContracts.EmptyRef)";
	
	Query.SetParameter("ContractsArray", ContractsArray);
	Selection = Query.Execute().Select();
	
	If Selection.Count() > 1 Then
		
		QuestionText = NStr("en='Document created in several currencies will not be transferred to Enterprise Accounting."
""
"Do you like to continue document record?';ru='Документ оформленный в нескольких валютах не будет перенесен в ""Бухгалтерию предприятия""."
""
"Продолжить запись документа?'");
			
		Return;
		
	EndIf;
	
	// Checking the correctness of filling out the Netting operation
	If Object.OperationKind = Enums.OperationKindsNetting.Netting
		AND SumAdvancesDebitor <> SumAdvancesLender Then
		
		QuestionText = NStr("en='Document which advance amount in tabular section ""Accounts receivable"" does"
"not correspond to the advance amount of tabular section ""Accounts payable"" will not be transferred to Enterprise Accounting."
""
"Do you like to continue document record?';ru='Документ, у которого сумма авансов в табличной части"
"""Расчеты с покупателем"" не соответствует сумме авансов в табличной части ""Расчеты с поставщиком"" не будет перенесен в ""Бухгалтерию предприятия""."
""
"Продолжить запись документа?'");
			
		Return;
		
	EndIf;

EndProcedure // CheckDocumentDetailsFillingCorrectness()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - OnCreateAtServer event handler.
// The procedure implements
// - form attribute initialization,
// - setting of the form functional options parameters.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SmallBusinessServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues
	);
	
	OperationKind = Object.OperationKind;
	
	Counterparty = Object.CounterpartySource;
	CounterpartyRecipient = Object.Counterparty;
	
	SubsidiaryCompany = SmallBusinessServer.GetCompany(Object.Company);
	
	StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", Constants.AccountingCurrency.Get()));
	ExchangeRate = ?(StructureByCurrency.ExchangeRate = 0, 1, StructureByCurrency.ExchangeRate);
	//( elmi # 08.5
	//Multiplicity = ?(StructureByCurrency.ExchangeRate = 0, 1, StructureByCurrency.Multiplicity);
	Multiplicity = ?(StructureByCurrency.Multiplicity = 0, 1, StructureByCurrency.Multiplicity);
	//) elmi
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	SetChoiceParameterLinks();
	SetVisibleAndEnabled();
	
	CheckingFillingNotExecuted = True;
	
	SmallBusinessClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ChangeProhibitionDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
EndProcedure // OnReadAtServer()

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	SetAvailableTypes();
	
    //( elmi # 08.5 
	SmallBusinessClient.RenameTitleExchangeRateMultiplicity( ThisForm, "Creditor");    
	SmallBusinessClient.RenameTitleExchangeRateMultiplicity( ThisForm, "Debitor");
    //) elmi
	
	
EndProcedure // OnOpen()

// Procedure - event handler of the form BeforeWrite
//
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If CheckingFillingNotExecuted Then
		
		If (Object.Ref.IsEmpty() OR Modified)
			AND SmallBusinessReUse.ExchangeWithBookkeepingConfigured() Then
			
			ErrorText = "";
			CheckCorrectnessOfDetailsOfDocumentFill(ErrorText);
			If Not IsBlankString(ErrorText) Then
				
				Cancel = True;
				RefuseFromDocumentRecord = True;
				FormClosingWithErrorsDescriptionNotification = New NotifyDescription("DetermineNeedForClosingFormWithErrors", ThisObject);
				ShowQueryBox(FormClosingWithErrorsDescriptionNotification, ErrorText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes,);
				
			EndIf;
			
		EndIf;
		
	Else 
		
		CheckingFillingNotExecuted = True;
		
	EndIf;
	
EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	// Notification of payment.
	NotifyAboutOrderPayment = False;
	NotifyAboutBillPayment = False;
	
	For Each CurRow In Object.Debitor Do
		NotifyAboutBillPayment = ?(
			NotifyAboutBillPayment,
			NotifyAboutBillPayment,
			ValueIsFilled(CurRow.InvoiceForPayment)
		);
		NotifyAboutOrderPayment = ?(
			NotifyAboutOrderPayment,
			NotifyAboutOrderPayment,
			ValueIsFilled(CurRow.Order)
		);
	EndDo;
	
	For Each CurRow In Object.Creditor Do
		NotifyAboutBillPayment = ?(
			NotifyAboutBillPayment,
			NotifyAboutBillPayment,
			ValueIsFilled(CurRow.InvoiceForPayment)
		);
		NotifyAboutOrderPayment = ?(
			NotifyAboutOrderPayment,
			NotifyAboutOrderPayment,
			ValueIsFilled(CurRow.Order)
		);
	EndDo;
	
	If NotifyAboutBillPayment Then
		Notify("NotificationAboutBillPayment");
	EndIf;

	If NotifyAboutOrderPayment Then
		Notify("NotificationAboutOrderPayment");
	EndIf;
	
	Notify("NotificationAboutChangingDebt");
	
EndProcedure // AfterWrite()

// Procedure - event handler NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AfterRecordingOfCounterparty" Then
		If ValueIsFilled(Parameter) Then
			If Parameter = Object.Counterparty
			 OR Parameter = Object.CounterpartySource Then
				SetVisibleAndEnabled();
				Return;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure // NotificationProcessing()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF HEADER ATTRIBUTES

// Procedure - event handler OnChange of the OperationKind input field.
// Manages pages while changing document operation kind.
//
&AtClient
Procedure OperationKindOnChange(Item)
	
	TypeOfOperationsBeforeChange = OperationKind;
	OperationKind = Object.OperationKind;
	If OperationKind <> TypeOfOperationsBeforeChange Then
		If Object.OperationKind = PredefinedValue("Enum.OperationKindsNetting.Netting") Then
			Object.Contract = Undefined;
			Object.AccountsDocument = Undefined;
			Object.AdvanceFlag = False;
			Object.SettlementsAmount = 0;
			Object.ExchangeRate = 0;
			Object.Multiplicity = 0;
			Object.AccountingAmount = 0;
			For Each String In Object.Creditor Do
				String.Contract = Undefined;
				String.Document = Undefined;
				String.Order = Undefined;
				String.InvoiceForPayment = Undefined;
			EndDo;
			SetChoiceParameterLinks();
		ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsNetting.CustomerDebtAssignment") Then
			Object.Creditor.Clear();
		ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsNetting.DebtAssignmentToVendor") Then
			Object.Debitor.Clear();
			For Each String In Object.Creditor Do
				String.Contract = Undefined;
				String.Document = Undefined;
				String.Order = Undefined;
				String.InvoiceForPayment = Undefined;
			EndDo;
			SetChoiceParameterLinks();
		ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsNetting.CustomerDebtAdjustment") Then
			Object.Creditor.Clear();
			Object.Counterparty = Undefined;
			Object.AccountsDocument = Undefined;
			Object.AdvanceFlag = False;
			Object.SettlementsAmount = 0;
			Object.ExchangeRate = 0;
			Object.Multiplicity = 0;
			Object.AccountingAmount = 0;
		ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsNetting.VendorDebtAdjustment") Then
			Object.Debitor.Clear();
			Object.CounterpartySource = Undefined;
			Object.AccountsDocument = Undefined;
			Object.AdvanceFlag = False;
			Object.SettlementsAmount = 0;
			Object.ExchangeRate = 0;
			Object.Multiplicity = 0;
			Object.AccountingAmount = 0;
		EndIf;
		SetVisibleAndEnabled();
		SetAvailableTypes();
	EndIf;
	
EndProcedure // OperationKindOnChange()

// Procedure - event handler OnChange of the Counterparty input field.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	SetVisibleAndEnabled();
	
	If Counterparty <> Object.CounterpartySource Then
		For Each String In Object.Debitor Do
			String.Contract = Undefined;
			String.Document = Undefined;
			String.Order = Undefined;
			String.InvoiceForPayment = Undefined;
		EndDo;
		If Object.OperationKind = PredefinedValue("Enum.OperationKindsNetting.DebtAssignmentToVendor") Then
			For Each String In Object.Creditor Do
				String.Contract = Undefined;
				String.Document = Undefined;
				String.Order = Undefined;
				String.InvoiceForPayment = Undefined;
			EndDo;
		EndIf;
	EndIf;
	Counterparty = Object.CounterpartySource;
	
EndProcedure // CounterpartyOnChange()

// Procedure - handler of the OnChange event of the CounterpartyRecipient input field.
//
&AtClient
Procedure CounterpartyRecipientOnChange(Item)
	
	SetVisibleAndEnabled();
	
	If CounterpartyRecipient <> Object.Counterparty Then
		If Object.OperationKind = PredefinedValue("Enum.OperationKindsNetting.Netting") Then
			For Each String In Object.Creditor Do
				String.Contract = Undefined;
				String.Document = Undefined;
				String.Order = Undefined;
				String.InvoiceForPayment = Undefined;
			EndDo;
		EndIf;
		Object.Contract = Undefined;
	EndIf;
	CounterpartyRecipient = Object.Counterparty;
	
EndProcedure // CounterpartyRecipientOnChange()

// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(Object.Ref, Object.Date, DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
	EndIf;
	
EndProcedure // DateOnChange()

// Procedure - event handler OnChange of the Company input field.
// The procedure is used to
// clear the document number and set the parameters of the form functional options.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	SubsidiaryCompany = StructureData.SubsidiaryCompany;
	
EndProcedure // CompanyOnChange()

// Procedure - event handler OnChange of the Contract input field.
//
&AtClient
Procedure ContractOnChange(Item)
	
	StructureData = GetDataContractOnChange(
		Object.Date,
		Object.Contract
	);
	
	If ValueIsFilled(Object.Contract) Then 
		Object.ExchangeRate      = ?(StructureData.CurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.CurrencyRateRepetition.ExchangeRate);
		Object.Multiplicity = ?(StructureData.CurrencyRateRepetition.Multiplicity = 0, 1, StructureData.CurrencyRateRepetition.Multiplicity);
	EndIf;
	
	CalculateAccountingAmount(Object);
	
EndProcedure // ContractOnChange()

// Procedure - event handler StartChoice of the Contract input field.
//
&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.OperationKind) Then
		Return;
	EndIf;
	
	FormParameters = GetChoiceFormParameters(Object.Ref, Object.Company, Object.Counterparty, Object.Contract, Object.OperationKind);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - handler of the OnChange event of the SettlementsAmount input field.
//
&AtClient
Procedure SettlementsAmountOnChange(Item)
	
	CalculateAccountingAmount(Object);
	
EndProcedure // SettlementsAmountsOnChange()

// Procedure - handler of the OnChange event of the Rate input field.
//
&AtClient
Procedure RateOnChange(Item)
	
	CalculateAccountingAmount(Object);
	
EndProcedure // RateOnChange()

// Procedure - handler of the OnChange event of the Multiplicity input field.
//
&AtClient
Procedure RepetitionOnChange(Item)
	
	CalculateAccountingAmount(Object);
	
EndProcedure // MultiplicityOnChange()

// Procedure - handler of the OnChange event of the AccountingAmount input field.
//
&AtClient
Procedure AccountingAmountOnChange(Item)
	
	CalculateSettlementsAmount(Object);
	
EndProcedure // AccountingAmountOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ATTRIBUTE  EVENT HANDLERS CWT

// Procedure - Handler of the OnChange event of
// the Contract input field of the Debitor tabular section.
//
&AtClient
Procedure DebitorContractOnChange(Item)
	
	TabularSectionRow = Items.Debitor.CurrentData;
	
	StructureData = GetDataContractOnChange(
		Object.Date,
		TabularSectionRow.Contract
	);
	
	If ValueIsFilled(TabularSectionRow.Contract) Then 
		TabularSectionRow.ExchangeRate      = ?(StructureData.CurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.CurrencyRateRepetition.ExchangeRate);
		TabularSectionRow.Multiplicity = ?(StructureData.CurrencyRateRepetition.Multiplicity = 0, 1, StructureData.CurrencyRateRepetition.Multiplicity);
	EndIf;
	
	CalculateAccountingAmount(TabularSectionRow);
	
EndProcedure // DebitorContractOnChange()

// Procedure - handler of SelectionBeginning of the Contract
// input field of the Debitor tabular section.
//
&AtClient
Procedure DebitorContractBeginChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.OperationKind) Then
		Return;
	EndIf;
	
	CurrentData = Items.Debitor.CurrentData;
	
	FormParameters = GetChoiceFormParameters(Object.Ref, Object.Company, Object.CounterpartySource, CurrentData.Contract, Object.OperationKind, "Debitor");
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - handler of the OnChange event 
//  of the Rate input field of the Debitor tabular section.
//
&AtClient
Procedure DebitorExchangeRateOnChange(Item)
	
	TabularSectionRow = Items.Debitor.CurrentData;
	
	CalculateAccountingAmount(TabularSectionRow);
	
EndProcedure // DebitorRateOnChange()

// Procedure - handler of the OnChange event of
// the Multiplicity input field of the Debitor tabular section.
//
&AtClient
Procedure DebitorMultiplicityOnChange(Item)
	
	TabularSectionRow = Items.Debitor.CurrentData;
	
	CalculateAccountingAmount(TabularSectionRow);
	
EndProcedure // DebitorMultiplicityOnChange()

&AtClient
// Procedure - handler of OnChange event of
// the AccountingAmount input field of the Debitor tabular section.
//
Procedure DebitorAccountsAmountOnChange(Item)
	
	TabularSectionRow = Items.Debitor.CurrentData;
	
	CalculateAccountingAmount(TabularSectionRow);
	
EndProcedure // DebitorSettlementsAmountOnChange()

// Procedure - handler of the OnChange event of
// the AccountingAmount input field of the Debitor tabular section.
//
&AtClient
Procedure DebitorAccountingAmountOnChange(Item)
	
	TabularSectionRow = Items.Debitor.CurrentData;
	
	CalculateSettlementsAmount(TabularSectionRow);
	
EndProcedure // DebitorAccountingAmountOnChange()

// Procedure - handler of the OnChange event of
// the DebitorDocument input field of the Debitor tabular section.
//
&AtClient
Procedure DebitorDocumentOnChange(Item)
	
	TabularSectionRow = Items.Debitor.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashReceipt")
	 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentReceipt") Then
		TabularSectionRow.AdvanceFlag = True;
	Else
		TabularSectionRow.AdvanceFlag = False;
	EndIf;
	
EndProcedure // DebitorDocumentOnChange()

// Procedure - handler of the OnChange event of
// the Contract input field of the Creditor tabular section.
//
&AtClient
Procedure CreditorContractOnChange(Item)
	
	TabularSectionRow = Items.Creditor.CurrentData;
	
	StructureData = GetDataContractOnChange(
		Object.Date,
		TabularSectionRow.Contract
	);
	
	If ValueIsFilled(TabularSectionRow.Contract) Then 
		TabularSectionRow.ExchangeRate      = ?(StructureData.CurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.CurrencyRateRepetition.ExchangeRate);
		TabularSectionRow.Multiplicity = ?(StructureData.CurrencyRateRepetition.Multiplicity = 0, 1, StructureData.CurrencyRateRepetition.Multiplicity);
	EndIf;
	
	CalculateAccountingAmount(TabularSectionRow);
	
EndProcedure // CreditorContractOnChange()

// Procedure - handler of the ChoiceBeggining of the
// Contract input field of the Creditor tabular section.
//
&AtClient
Procedure CreditorContractBeginChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.OperationKind) Then
		Return;
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsNetting.DebtAssignmentToVendor") Then
		CounterpartyCreditor = Object.CounterpartySource;
	Else
		CounterpartyCreditor = Object.Counterparty;
	EndIf;
	
	CurrentData = Items.Creditor.CurrentData;
	
	FormParameters = GetChoiceFormParameters(Object.Ref, Object.Company, CounterpartyCreditor, CurrentData.Contract, Object.OperationKind, "Creditor");
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - handler of the OnChange event of
// the Rate input field of the Creditor tabular section.
//
&AtClient
Procedure CreditorExchangeRateOnChange(Item)
	
	TabularSectionRow = Items.Creditor.CurrentData;
	
	CalculateAccountingAmount(TabularSectionRow);
	
EndProcedure // DebitorRateOnChange()

// Procedure - handler of the OnChange event of
// the Multiplicity input field of the Debitor tabular section.
//
&AtClient
Procedure CreditorMultiplicityOnChange(Item)
	
	TabularSectionRow = Items.Creditor.CurrentData;
	
	CalculateAccountingAmount(TabularSectionRow);
	
EndProcedure // CreditorMultiplicityOnChange()

// Procedure - handler of the OnChange event
// of the SettlementsAmount input field of the Creditor tabular section.
//
&AtClient
Procedure CreditorSettlementsAmountOnChange(Item)
	
	TabularSectionRow = Items.Creditor.CurrentData;
	
	CalculateAccountingAmount(TabularSectionRow);
	
EndProcedure // CreditorSettlementsAmountOnChange()

// Procedure - handler of the OnChange event of
// the AccountingAmount input field of the Creditor tabular section.
//
&AtClient
Procedure CreditorAccountingAmountOnChange(Item)
	
	TabularSectionRow = Items.Creditor.CurrentData;
	
	CalculateSettlementsAmount(TabularSectionRow);
	
EndProcedure // CreditorAccountingAmountOnChange()

// Procedure - handler of the OnChange event of
// the Document input field of the Creditor tabular section.
//
&AtClient
Procedure CreditorDocumentOnChange(Item)
	
	TabularSectionRow = Items.Creditor.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashPayment")
	 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentExpense")
	 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.ExpenseReport") Then
		TabularSectionRow.AdvanceFlag = True;
	Else
		TabularSectionRow.AdvanceFlag = False;
	EndIf;
	
EndProcedure // CreditorDocumentOnChange()

&AtClient
Procedure AccountsDocumentOnChange(Item)
	
	If TypeOf(Object.AccountsDocument) = Type("DocumentRef.CashReceipt")
	 OR TypeOf(Object.AccountsDocument) = Type("DocumentRef.PaymentReceipt")
	 OR TypeOf(Object.AccountsDocument) = Type("DocumentRef.CashPayment")
	 OR TypeOf(Object.AccountsDocument) = Type("DocumentRef.PaymentExpense")
	 OR TypeOf(Object.AccountsDocument) = Type("DocumentRef.ExpenseReport") Then
		Object.AdvanceFlag = True;
	Else
		Object.AdvanceFlag = False;
	EndIf;

EndProcedure

// Procedure - handler of the Execute event of the Pickup command
// Opens the form of debt forming documents selection.
//
&AtClient
Procedure PickAccountsReceivable(Command)
	
	If Not ValueIsFilled(Object.CounterpartySource) Then
		ShowMessageBox(, NStr("en='Specify the customer first!';ru='Укажите вначале покупателя!'"));
		Return;
	EndIf;
	
	AddressDebitorInStorage = PlaceDebitorToStorage();
	
	SelectionParameters = New Structure(
	    //( elmi # 08.5
	    //"AddressDebitorToStorage,
		"AddressDebitorInStorage,
		//) elmi
		|SubsidiaryCompany,
		|Date,
		|Counterparty,
		|Ref",
		AddressDebitorInStorage,
		SubsidiaryCompany,
		Object.Date,
		Object.CounterpartySource,
		Object.Ref
	);
	
	Result = Undefined;

	
	OpenForm("CommonForm.CustomersAdvancesAndDebtsPickForm", SelectionParameters,,,,, New NotifyDescription("PickUpPaymantsToCustomerEnd", ThisObject, New Structure("AddressDebitorInStorage", AddressDebitorInStorage)));
	
EndProcedure

&AtClient
Procedure PickUpPaymantsToCustomerEnd(Result1, AdditionalParameters) Export
    
    AddressDebitorInStorage = AdditionalParameters.AddressDebitorInStorage;
    
    
    Result = Result1;
    If Result = DialogReturnCode.OK Then
        GetDebitorFromStorage(AddressDebitorInStorage);
    EndIf;

EndProcedure // PickAccountsReceivable()

// Function puts the Debitor tabular section in
// temporary storage and returns the address
//
&AtServer
Function PlaceDebitorToStorage()
	
	Return PutToTempStorage(
		Object.Debitor.Unload(,
			"Contract,
			|Document,
			|Order,
			|SettlementsAmount,
			|AccountingAmount,
			|ExchangeRate,
			|Multiplicity,
			|AdvanceFlag"
		),
		UUID
	);
	
EndFunction // PlaceDebitorToStorage()

// Function gets the Debitor tabular section from the temporary storage.
//
&AtServer
Procedure GetDebitorFromStorage(AddressDebitorInStorage)
	
	TableDebitor = GetFromTempStorage(AddressDebitorInStorage);
	Object.Debitor.Clear();
	For Each RowDebitor In TableDebitor Do
		String = Object.Debitor.Add();
		FillPropertyValues(String, RowDebitor);
	EndDo;
	
EndProcedure // GetDebitorFromStorage()

// Procedure - handler of the Execute event of the Pickup command
// Opens the form of debt forming documents selection.
//
&AtClient
Procedure PickVendorSettlements(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(, NStr("en='Specify the vendor first!';ru='Укажите вначале поставщика!'"));
		Return;
	EndIf;
	
	AddressCreditorInStorage = PlaceCreditorToStorage();
	
	SelectionParameters = New Structure(
	    //( elmi # 08.5
	    //"AddressDebitorInStorage,
		"AddressDebitorToStorage,
		//) elmi
		|SubsidiaryCompany,
		|Date,
		|Counterparty,
		|Ref",
		AddressCreditorInStorage,
		SubsidiaryCompany,
		Object.Date,
		?(Object.OperationKind = PredefinedValue("Enum.OperationKindsNetting.DebtAssignmentToVendor"), Object.CounterpartySource, Object.Counterparty),
		Object.Ref
	);
	
	Result = Undefined;

	
	OpenForm("CommonForm.VendorsAdvancesAndDebtsPickForm", SelectionParameters,,,,, New NotifyDescription("PickVendorSettlementsEnd", ThisObject, New Structure("AddressCreditorInStorage", AddressCreditorInStorage)));
	
EndProcedure

&AtClient
Procedure PickVendorSettlementsEnd(Result1, AdditionalParameters) Export
    
    AddressCreditorInStorage = AdditionalParameters.AddressCreditorInStorage;
    
    
    Result = Result1;
    If Result = DialogReturnCode.OK Then
        GetCreditorFromStorage(AddressCreditorInStorage);
    EndIf;

EndProcedure // PickVendorSettlements()

// Function puts the Creditor tabular section in
// the temporary storage and returns the address
//
&AtServer
Function PlaceCreditorToStorage()
	
	Return PutToTempStorage(
		Object.Creditor.Unload(,
			"Contract,
			|Document,
			|Order,
			|SettlementsAmount,
			|AccountingAmount,
			|ExchangeRate,
			|Multiplicity,
			|AdvanceFlag"
		),
		UUID
	);
	
EndFunction // PlaceCreditorToStorage()

// Function gets the Creditor tabular section from the temporary storage.
//
&AtServer
Procedure GetCreditorFromStorage(AddressCreditorInStorage)
	
	TableCreditor = GetFromTempStorage(AddressCreditorInStorage);
	Object.Creditor.Clear();
	For Each RowCreditor In TableCreditor Do
		String = Object.Creditor.Add();
		FillPropertyValues(String, RowCreditor);
	EndDo;
	
EndProcedure // GetCreditorFromStorage()

//Procedure executes fillings of attributes according to the basis document
//
&AtServer
Procedure FillByDocument()
	
	BasisDocument 	= Object.BasisDocument;
	
	//Clear the document data
	Object.Debitor.Clear();
	Object.Creditor.Clear();
	Document = FormAttributeToValue("Object");
	FillPropertyValues(Document, Documents.Netting.EmptyRef(), , "Number, Date, OperationKind");
	
	//Fill according to basis document
	Document.Filling(BasisDocument, True);
	ValueToFormAttribute(Document, "Object");
	
	Modified = True;
	
EndProcedure //FillByDocument()

// Procedure is opened by clicking "FillOnBasis" button on the Additionally page
//
&AtClient
Procedure FillByDocumentBase(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		
		Message				= New UserMessage;
		Message.Text			= NStr("en='Select the basis document.';ru='Выберите документ основание.'");
		Message.DataPath	= "BasisDocument";
		Message.Message();
		
		Return;
		
	EndIf;
	
	QuestionText 	= NStr("en='Document will be cleared and filled according to basis document. Continue?';ru='Документ будит очищен и заполнен по документу-основанию. Продолжить?'");
	Response = Undefined;

	ShowQueryBox(New NotifyDescription("FillAccordingToBasisDocumentEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo, );
	
EndProcedure

&AtClient
Procedure FillAccordingToBasisDocumentEnd(Result, AdditionalParameters) Export
    
    Response 			= Result;
    
    If Response = DialogReturnCode.Yes Then
        
        FillByDocument();
        
    EndIf;

EndProcedure //FillByDocumentBase()

&AtClient
Procedure DebitorAdvanceFlagOnChange(Item)
	
	TabularSectionRow = Items.Debitor.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.Netting") Then
		Return;
	EndIf;
	
	If TabularSectionRow.AdvanceFlag Then
		
		If TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.CashReceipt")
			AND TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.PaymentReceipt") Then
			TabularSectionRow.Document = Undefined;
		EndIf;
		
	Else
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashReceipt")
		 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentReceipt") Then
			TabularSectionRow.Document = Undefined;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CreditorAdvanceFlagOnChange(Item)
	
	TabularSectionRow = Items.Creditor.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.Netting") Then
		Return;
	EndIf;
	
	If TabularSectionRow.AdvanceFlag Then
		
		If TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.CashPayment")
			AND TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.PaymentExpense")
			AND TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.ExpenseReport") Then
			TabularSectionRow.Document = Undefined;
		EndIf;
		
	Else
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashPayment")
		 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentExpense")
		 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.ExpenseReport") Then
			TabularSectionRow.Document = Undefined;
		EndIf;
		
	EndIf;

EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure // CommentOnChange()

&AtClient
Procedure Attachable_SetPictureForComment()
	
	SmallBusinessClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
EndProcedure

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-result handler of the closing form with errors question
//
Procedure DetermineNeedForClosingFormWithErrors(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		CheckingFillingNotExecuted = False;
		Write();
		
	EndIf;
	
EndProcedure // DetermineNeedForClosingFormWithErrors()

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure

// End StandardSubsystems.Printing

#EndRegion


// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
