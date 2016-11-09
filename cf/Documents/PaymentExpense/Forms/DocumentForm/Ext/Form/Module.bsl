////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Procedure of the field change data processor Operation kind on server.
//
&AtServer
Procedure SetCFItemWhenChangingTheTypeOfOperations()
	
	If Object.OperationKind = Enums.OperationKindsPaymentExpense.ToCustomer
		AND (Object.Item = Catalogs.CashFlowItems.PaymentToVendor
		OR Object.Item = Catalogs.CashFlowItems.Other
		OR Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers) Then
		Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	ElsIf Object.OperationKind = Enums.OperationKindsPaymentExpense.Vendor
		AND (Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers
		OR Object.Item = Catalogs.CashFlowItems.Other
		OR Object.Item = Catalogs.CashFlowItems.PaymentToVendor) Then
		Object.Item = Catalogs.CashFlowItems.PaymentToVendor;
	ElsIf (Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers
		OR Object.Item = Catalogs.CashFlowItems.PaymentToVendor) Then
		Object.Item = Catalogs.CashFlowItems.Other;
	EndIf;
	
EndProcedure // OperationKindOnChangeAtServer()

// Procedure of the field change data processor Operation kind on server.
//
&AtServer
Procedure SetCFItem()
	
	If Object.OperationKind = Enums.OperationKindsPaymentExpense.ToCustomer Then
		Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	ElsIf Object.OperationKind = Enums.OperationKindsPaymentExpense.Vendor Then
		Object.Item = Catalogs.CashFlowItems.PaymentToVendor;
	Else
		Object.Item = Catalogs.CashFlowItems.Other;
	EndIf;
	
EndProcedure // OperationKindOnChangeAtServer()

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	SetVisibleOfVATTaxation();
	SetAccountsAttributesVisible();
	
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", Object.CashCurrency));
	ExchangeRate = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.ExchangeRate
	);
	Multiplicity = ?(
		//( elmi # 08.5
	    //StructureByCurrency.ExchangeRate = 0,
		  StructureByCurrency.Multiplicity = 0,
		//) elmi

		1,
		StructureByCurrency.Multiplicity
	);
	
EndProcedure // FillByDocument()

// Function puts the SettlementsDetails tabular section to
// the temporary storage and returns an address
//
&AtServer
Function PlacePaymentDetailsToStorage()
	
	Return PutToTempStorage(
		Object.PaymentDetails.Unload(,
			"Contract,
			|AdvanceFlag,
			|Document,
			|Order,
			|SettlementsAmount,
			|ExchangeRate,
			|Multiplicity"
		),
		UUID
	);
	
EndFunction // PlacePaymentDetailsToStorage()

// Function receives the SettlementsDetails tabular section from the temporary storage.
//
&AtServer
Procedure GetPaymentDetailsFromStorage(AddressPaymentDetailsInStorage)
	
	TableExplanationOfPayment = GetFromTempStorage(AddressPaymentDetailsInStorage);
	Object.PaymentDetails.Clear();
	For Each RowPaymentDetails IN TableExplanationOfPayment Do
		String = Object.PaymentDetails.Add();
		FillPropertyValues(String, RowPaymentDetails);
	EndDo;
	
EndProcedure // GetPaymentDetailsFromStorage()

// Recalculates amounts by the document tabular section
// currency after changing the bank account or petty cash.
//
&AtClient
Procedure RecalculateDocumentAmounts(ExchangeRate, Multiplicity, RecalculatePaymentAmount)
	
	For Each TabularSectionRow IN Object.PaymentDetails Do
		If RecalculatePaymentAmount Then
			TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				TabularSectionRow.ExchangeRate,
				ExchangeRate,
				TabularSectionRow.Multiplicity,
				Multiplicity
			);
			CalculateVATSUM(TabularSectionRow);
		Else
			TabularSectionRow.ExchangeRate = ?(
				TabularSectionRow.ExchangeRate = 0,
				1,
				TabularSectionRow.ExchangeRate
			);
			TabularSectionRow.Multiplicity = ?(
				TabularSectionRow.Multiplicity = 0,
				1,
				TabularSectionRow.Multiplicity
			);
			TabularSectionRow.SettlementsAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.PaymentAmount,
				ExchangeRate,
				TabularSectionRow.ExchangeRate,
				Multiplicity,
				TabularSectionRow.Multiplicity
			);
		EndIf;
	EndDo;
	
	If RecalculatePaymentAmount Then
		Object.DocumentAmount = Object.PaymentDetails.Total("PaymentAmount");
	EndIf;
	
EndProcedure // RecalculateDocumentAmounts()

// Recalculates amounts by the cash assets currency.
//
&AtClient
Procedure RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData, MessageText)
	
	ExchangeRateBeforeChange = ExchangeRate;
	MultiplicityBeforeChange = Multiplicity;
	
	If ValueIsFilled(Object.CashCurrency) Then
		ExchangeRate = ?(
			StructureData.CurrencyRateRepetition.ExchangeRate = 0,
			1,
			StructureData.CurrencyRateRepetition.ExchangeRate
		);
		Multiplicity = ?(
			StructureData.CurrencyRateRepetition.Multiplicity = 0,
			1,	
			StructureData.CurrencyRateRepetition.Multiplicity
		);
	EndIf;
	
	// If currency exchange rate is not changed or cash
	// assets currency is not filled in or document is not filled in, then do nothing.
	If (ExchangeRate = ExchangeRateBeforeChange
		AND Multiplicity = MultiplicityBeforeChange)
	 OR (NOT ValueIsFilled(Object.CashCurrency))
	 OR (Object.PaymentDetails.Total("SettlementsAmount") = 0
	 AND Not ValueIsFilled(Object.DocumentAmount)) Then
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ExchangeRateBeforeChange", ExchangeRateBeforeChange);
	AdditionalParameters.Insert("MultiplicityBeforeChange", MultiplicityBeforeChange);
	
	NotifyDescription = New NotifyDescription("DefineNeedToRecalculateAmountsOnRateChange", ThisObject, AdditionalParameters);
	ShowQueryBox(NOTifyDescription, MessageText, QuestionDialogMode.YesNo, 0);
	
EndProcedure // RecalculateAmountsOnCashAssetsCurrencyRateChange()

// Procedure-handler of a response to the question on document recalculation after currency rate change
//
&AtClient
Procedure DefineNeedToRecalculateAmountsOnRateChange(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		ExchangeRateBeforeChange = AdditionalParameters.ExchangeRateBeforeChange;
		MultiplicityBeforeChange = AdditionalParameters.MultiplicityBeforeChange;
		
		If Object.PaymentDetails.Count() > 0
		   AND Object.OperationKind <> PredefinedValue("Enum.OperationKindsPaymentExpense.Salary") Then // only header is recalculated for the "Salary" operation kind.
			If Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentExpense.ToCustomer")
			 OR Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentExpense.Vendor") Then
				RecalculateDocumentAmounts(ExchangeRate, Multiplicity, True);
			Else
				DocumentAmountIsEqualToTotalPaymentAmount = Object.PaymentDetails.Total("PaymentAmount") = Object.DocumentAmount;
				
				For Each TabularSectionRow IN Object.PaymentDetails Do // recalculate plan amount for the operations with planned payments.
					TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
						TabularSectionRow.PaymentAmount,
						ExchangeRateBeforeChange,
						ExchangeRate,
						MultiplicityBeforeChange,
						Multiplicity
					);
				EndDo;
					
				If DocumentAmountIsEqualToTotalPaymentAmount Then
					Object.DocumentAmount = Object.PaymentDetails.Total("PaymentAmount");
				Else
					Object.DocumentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
						Object.DocumentAmount,
						ExchangeRateBeforeChange,
						ExchangeRate,
						MultiplicityBeforeChange,
						Multiplicity
					);
				EndIf;
				
			EndIf;
		Else
			Object.DocumentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
				Object.DocumentAmount,
				ExchangeRateBeforeChange,
				ExchangeRate,
				MultiplicityBeforeChange,
				Multiplicity
			);
		EndIf;
	Else
		If Object.PaymentDetails.Count() > 0 Then
			RecalculateDocumentAmounts(ExchangeRate, Multiplicity, False);
		EndIf;
	EndIf;
	
EndProcedure // DetermineNeedToRecalculateAmountsOnRateChange()

// Recalculate a payment amount in the passed tabular section string.
//
&AtClient
Procedure CalculatePaymentSUM(TabularSectionRow)
	
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.ExchangeRate = 0,
		1,
		TabularSectionRow.ExchangeRate
	);
	TabularSectionRow.Multiplicity = ?(
		TabularSectionRow.Multiplicity = 0,
		1,
		TabularSectionRow.Multiplicity
	);
	TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		TabularSectionRow.ExchangeRate,
		ExchangeRate,
		TabularSectionRow.Multiplicity,
		Multiplicity
	);
	
	If Not ValueIsFilled(TabularSectionRow.VATRate) Then
		TabularSectionRow.VATRate = DefaultVATRate;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	
EndProcedure // CalculatePaymentAmount()

// Recalculates amounts by the document tabular section
// currency after changing the bank account or petty cash.
//
&AtClient
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = TabularSectionRow.PaymentAmount - (TabularSectionRow.PaymentAmount) / ((VATRate + 100) / 100);
	
EndProcedure // CalculateVATAmount()

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Counterparty, Company, Date)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company, Object.OperationKind);
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"Contract",
		ContractByDefault
	);
	
	StructureData.Insert(
		"ContractCurrencyRateRepetition",
		InformationRegisters.CurrencyRates.GetLast(
			Date,
			New Structure("Currency", ContractByDefault.SettlementsCurrency)
		)
	);
	
	SetAccountsAttributesVisible();
	
	Return StructureData;
	
EndFunction // GetDataCounterpartyOnChange()

// Procedure sets settlement attributes visible.
//
&AtServer
Procedure SetAccountsAttributesVisible()
	
	Items.PaymentDetailsContract.Visible = Object.Counterparty.DoOperationsByContracts;
	Items.PaymentDetailsDocument.Visible = Object.Counterparty.DoOperationsByDocuments;
	Items.PaymentDetailsOrder.Visible = Object.Counterparty.DoOperationsByOrders;
	Items.PaymentDetailsInvoiceForPayment.Visible = Object.Counterparty.TrackPaymentsByBills;
	
EndProcedure // SetAccountsAttributesVisible()

// It receives data set from the server for the CurrencyCashOnChange procedure.
//
&AtServerNoContext
Function GetDataBankAccountOnChange(Date, BankAccount, CounterpartyAccount)
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"CurrencyRateRepetition",
		InformationRegisters.CurrencyRates.GetLast(
			Date,
			New Structure("Currency", BankAccount.CashCurrency)
		)
	);
	
	StructureData.Insert(
		"CashCurrency",
		BankAccount.CashCurrency
	);
	
	StructureData.Insert(
		"CounterpartyAccount",
		?(ValueIsFilled(CounterpartyAccount) AND CounterpartyAccount.CashCurrency = BankAccount.CashCurrency, CounterpartyAccount, Undefined)
	);
	
	
	Return StructureData;
	
EndFunction // GetDataBankAccountOnChange()

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetDataPaymentDetailsContractOnChange(Date, Contract)
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"ContractCurrencyRateRepetition",
		InformationRegisters.CurrencyRates.GetLast(
			Date,
			New Structure("Currency", Contract.SettlementsCurrency)
		)
	);
	
	Return StructureData;
	
EndFunction // GetDataPaymentDetailsContractOnChange()

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Function GetDataDateOnChange(DateBeforeChange)
	
	DATEDIFF = SmallBusinessServer.CheckDocumentNumber(Object.Ref, Object.Date, DateBeforeChange);
	CurrencyRateRepetition = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", Object.CashCurrency));
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"DATEDIFF",
		DATEDIFF
	);
	StructureData.Insert(
		"CurrencyRateRepetition",
		CurrencyRateRepetition
	);
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction // GetDataDateOnChange()

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"Counterparty",
		SmallBusinessServer.GetCompany(Object.Company)
	);
	
	StructureData.Insert(
		"BankAccount",
		?(ValueIsFilled(Object.BankAccount) AND Object.BankAccount.Owner = Object.Company, Object.BankAccount, Object.Company.BankAccountByDefault)
	);
	
	StructureData.Insert(
		"CurrencyRateRepetition",
		InformationRegisters.CurrencyRates.GetLast(
			Object.Date,
			New Structure("Currency", StructureData.BankAccount.CashCurrency)
		)
	);
	
	StructureData.Insert(
		"CashCurrency",
		StructureData.BankAccount.CashCurrency
	);
	
	StructureData.Insert(
		"CounterpartyAccount",
		?(ValueIsFilled(Object.CounterpartyAccount) AND StructureData.BankAccount.CashCurrency = Object.CounterpartyAccount.CashCurrency, Object.CounterpartyAccount, Catalogs.BankAccounts.EmptyRef())
	);
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction // GetCompanyDataOnChange()

// It receives data set from the server for the SalaryPaymentStatementOnChange procedure.
//
&AtServerNoContext
Function GetDataSalaryPayStatementOnChange(Statement)
	
	Return Statement.Employees.Total("PaymentAmount");
	
EndFunction // GetDataSalaryPaymentStatementOnChange()

// Procedure of the field change data processor Operation kind on server.
//
&AtServer
Procedure OperationKindOnChangeAtServer(FillTaxation = True)
	
	If FillTaxation Then
		FillVATRateByCompanyVATTaxation();
	EndIf;
	
	SetVisibleOfItemsDependsOnOperationKind();
	SetCFItemWhenChangingTheTypeOfOperations();
	
EndProcedure // OperationKindOnChangeAtServer()

// Procedure fills in default VAT rate.
//
&AtServer
Procedure FillDefaultVATRate()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		DefaultVATRate = Object.Company.DefaultVATRate;
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then
		DefaultVATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
	Else
		DefaultVATRate = SmallBusinessReUse.GetVATRateZero();
	EndIf;
	
EndProcedure // FillDefaultVATRate()

// Procedure fills VAT Rate in tabular section
// by company taxation system.
//
&AtServer
Procedure FillVATRateByCompanyVATTaxation()
	
	TaxationBeforeChange = Object.VATTaxation;
	
	If Object.OperationKind = Enums.OperationKindsPaymentExpense.ToCustomer Then
		
		Object.VATTaxation = SmallBusinessServer.VATTaxation(Object.Company,, Object.Date);
		
	Else
		
		Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT;
		
	EndIf;
	
	If (Object.OperationKind = Enums.OperationKindsPaymentExpense.ToCustomer
		OR Object.OperationKind = Enums.OperationKindsPaymentExpense.Vendor)
		AND Not TaxationBeforeChange = Object.VATTaxation Then
		
		FillVATRateByVATTaxation();
		
	Else
		
		FillDefaultVATRate();
		
	EndIf;
	
EndProcedure // FillVATRateByVATTaxation()

// Procedure sets the Taxation field visible.
//
&AtServer
Procedure SetVisiblePlanningDocuments()
	
	If Object.OperationKind = Enums.OperationKindsPaymentExpense.ToCustomer
		OR Object.OperationKind = Enums.OperationKindsPaymentExpense.Vendor
		OR Object.OperationKind = Enums.OperationKindsPaymentExpense.Salary
		OR Not GetFunctionalOption("PaymentCalendar") Then
		Items.PlanningDocuments.Visible = False;
	Else
		Items.PlanningDocuments.Visible = True;
	EndIf;
	
EndProcedure // SetVisibleVATTaxation()

// Procedure fills the VAT rate in the tabular section according to the taxation system.
// 
&AtServer
Procedure FillVATRateByVATTaxation(RestoreRatesOfVAT = True)
	
	FillDefaultVATRate();
	
	If Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		
		If Object.OperationKind = Enums.OperationKindsPaymentExpense.ToCustomer
			OR Object.OperationKind = Enums.OperationKindsPaymentExpense.Vendor Then
			
			Items.PaymentDetailsVATRate.Visible = True;
			Items.PaymentDetailsVatAmount.Visible = True;
			Items.VATAmount.Visible = True;
			
		EndIf;
		
		VATRate = SmallBusinessReUse.GetVATRateValue(DefaultVATRate);
		
		If RestoreRatesOfVAT Then
			For Each TabularSectionRow IN Object.PaymentDetails Do
				TabularSectionRow.VATRate = Object.Company.DefaultVATRate;
				TabularSectionRow.VATAmount = TabularSectionRow.PaymentAmount - (TabularSectionRow.PaymentAmount) / ((VATRate + 100) / 100);
			EndDo;
		EndIf;
		
	Else
		
		If Object.OperationKind = Enums.OperationKindsPaymentExpense.ToCustomer
			OR Object.OperationKind = Enums.OperationKindsPaymentExpense.Vendor Then
			
			Items.PaymentDetailsVATRate.Visible = False;
			Items.PaymentDetailsVatAmount.Visible = False;
			Items.VATAmount.Visible = False;
			
		EndIf;
		
		If RestoreRatesOfVAT Then
			For Each TabularSectionRow IN Object.PaymentDetails Do
				TabularSectionRow.VATRate = DefaultVATRate;
				TabularSectionRow.VATAmount = 0;
			EndDo;
		EndIf;
		
	EndIf;
	
	SetVisiblePlanningDocuments();
	
EndProcedure // FillVATRateByVATTaxation()

&AtServer
// Procedure sets the Taxation field visible.
//
Procedure SetVisibleOfVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		
		If Object.OperationKind = Enums.OperationKindsPaymentExpense.ToCustomer
			OR Object.OperationKind = Enums.OperationKindsPaymentExpense.Vendor Then
			
			Items.PaymentDetailsVATRate.Visible = True;
			Items.PaymentDetailsVatAmount.Visible = True;
			
		EndIf;
		
		DefaultVATRate = Object.Company.DefaultVATRate;
		
	Else
		
		If Object.OperationKind = Enums.OperationKindsPaymentExpense.ToCustomer
			OR Object.OperationKind = Enums.OperationKindsPaymentExpense.Vendor Then
			
			Items.PaymentDetailsVATRate.Visible = False;
			Items.PaymentDetailsVatAmount.Visible = False;
			
		EndIf;
		
		If Object.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then
			DefaultVATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
		Else
			DefaultVATRate = SmallBusinessReUse.GetVATRateZero();
		EndIf;
		
	EndIf;
	
EndProcedure // SetVisibleVATTaxation()

// Procedure sets the form attribute visible
// from option Use subsystem Payroll.
//
// Parameters:
// No.
//
&AtServer
Procedure SetVisibleByFOUseSubsystemPayroll()
	
	// Salary.
	If Constants.FunctionalOptionUseSubsystemPayroll.Get() Then
		Items.OperationKind.ChoiceList.Add(Enums.OperationKindsPaymentExpense.Salary, "Salary");
	EndIf;
	
	// Taxes.
	Items.OperationKind.ChoiceList.Add(Enums.OperationKindsPaymentExpense.Taxes, "Taxes");
	
	// Other.
	Items.OperationKind.ChoiceList.Add(Enums.OperationKindsPaymentExpense.Other, "Other");
	
EndProcedure // SetVisibleByFOUseSubsystemPayroll()

// Checks the match of the "Company" and "ContractKind" contract attributes to the terms of the document.
//
&AtServerNoContext
Procedure CheckContractToDocumentConditionAccordance(Val TSPaymentDetails, MessageText, Document, Company, Counterparty, OperationKind, Cancel)
	
	If Not SmallBusinessReUse.CounterpartyContractsControlNeeded()
		OR Not Counterparty.DoOperationsByContracts Then
		
		Return;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	ContractKindsList = ManagerOfCatalog.GetContractKindsListForDocument(Document, OperationKind);
	
	For Each TabularSectionRow IN TSPaymentDetails Do
		
		If Not ManagerOfCatalog.ContractMeetsDocumentTerms(MessageText, TabularSectionRow.Contract, Company, Counterparty, ContractKindsList)
			AND Constants.DoNotPostDocumentsWithIncorrectContracts.Get() Then
			
			Cancel = True;
			Break;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// It gets counterparty contract selection form parameter structure.
//
&AtServerNoContext
Function GetChoiceFormParameters(Document, Company, Counterparty, Contract, OperationKind)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractKindsListForDocument(Document, OperationKind);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", Counterparty.DoOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractKinds", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

// Gets the default contract depending on the settlements method.
//
&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company, OperationKind)
	
	If Not Counterparty.DoOperationsByContracts Then
		Return Counterparty.ContractByDefault;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	ContractTypesList = ManagerOfCatalog.GetContractKindsListForDocument(Document, OperationKind);
	ContractByDefault = ManagerOfCatalog.GetDefaultContractByCompanyContractKind(Counterparty, Company, ContractTypesList);
	
	Return ContractByDefault;
	
EndFunction

// Checks whether document is approved or not.
//
&AtServerNoContext
Function DocumentApproved(BasisDocument)
	
	Return BasisDocument.PaymentConfirmationStatus = Enums.PaymentApprovalStatuses.Approved;
	
EndFunction // DocumentApproved()

// Determines whether there are recipient nodes for document while using exchange.
//
&AtServer
Function ThereAreNodesRecipients()
	
	NodesFound = False;
	
	If Object.OperationKind <> Enums.OperationKindsPaymentExpense.Salary
		AND Object.OperationKind <> Enums.OperationKindsPaymentExpense.Taxes
		OR Not SmallBusinessReUse.ExchangeWithBookkeepingConfigured() Then
		
		Return NodesFound;
	EndIf;
	
	ArrayOfNamesExchangePlans = New Array;
	
	If GetFunctionalOption("WorkInLocalMode") Then
		ArrayOfNamesExchangePlans.Add(Metadata.ExchangePlans.ExchangeSmallBusinessAccounting20.Name);
	EndIf;
	
	ArrayOfNamesExchangePlans.Add(Metadata.ExchangePlans.ExchangeSmallBusinessAccounting30.Name);
	
	For Each ExchangePlanName IN ArrayOfNamesExchangePlans Do
		
		DocumentObject = FormAttributeToValue("Object");
		
		NodesRecipients = DataExchangeEvents.DefineRecipients(DocumentObject, ExchangePlanName);
		If NodesRecipients.Count() > 0 Then
			NodesFound = True;
			Break;
		EndIf;
		
	EndDo;
	
	Return NodesFound;
	
EndFunction // ThereAreNodesRecipients()

// Fills in the contract.
//
Procedure FillInContract(Parameters = Undefined)
	
	If ValueIsFilled(Object.Counterparty)
		AND Object.PaymentDetails.Count() > 0
		AND (Parameters = Undefined OR (Parameters <> Undefined AND Not ValueIsFilled(Parameters.BasisDocument))) Then
		If Not ValueIsFilled(Object.PaymentDetails[0].Contract) Then
			Object.PaymentDetails[0].Contract = Object.Counterparty.ContractByDefault;
		EndIf;
		If ValueIsFilled(Object.PaymentDetails[0].Contract) Then
			ContractCurrencyRateRepetition = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", Object.PaymentDetails[0].Contract.SettlementsCurrency));
			Object.PaymentDetails[0].ExchangeRate = ?(ContractCurrencyRateRepetition.ExchangeRate = 0, 1, ContractCurrencyRateRepetition.ExchangeRate);
			Object.PaymentDetails[0].Multiplicity = ?(ContractCurrencyRateRepetition.Multiplicity = 0, 1, ContractCurrencyRateRepetition.Multiplicity);
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR CONTROL OF THE FORM APPEARANCE

// Procedure sets the current page depending on the operation kind.
//
&AtClient
Procedure SetCurrentPage()
	
	LineCount = Object.PaymentDetails.Count();
	
	If LineCount = 0 Then
		Object.PaymentDetails.Add();
		Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		LineCount = 1;
	EndIf;
	
EndProcedure // SetCurrentPage()

// The procedure clears the attributes that could have been
// filled in earlier but do not belong to the current operation.
//
&AtClient
Procedure ClearAttributesNotRelatedToOperation()
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentExpense.Vendor")
	 OR Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentExpense.ToCustomer") Then
		Object.Correspondence = Undefined;
		Object.TaxKind = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.PayrollPayment.Clear();
		Object.Division = Undefined;
		Object.BusinessActivity = Undefined;
		Object.Order = Undefined;
		For Each TableRow IN Object.PaymentDetails Do
			TableRow.Order = Undefined;
			TableRow.Document = Undefined;
			TableRow.AdvanceFlag = False;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentExpense.ToAdvanceHolder") Then
		Object.Correspondence = Undefined;
		Object.TaxKind = Undefined;
		Object.Counterparty = Undefined;
		Object.CounterpartyAccount = Undefined;
		Object.Division = Undefined;
		Object.BusinessActivity = Undefined;
		Object.Order = Undefined;
		Object.PayrollPayment.Clear();
		For Each TableRow IN Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.InvoiceForPayment = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentExpense.Salary") Then
		Object.Correspondence = Undefined;
		Object.Counterparty = Undefined;
		Object.CounterpartyAccount = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.Division = Undefined;
		If Not FunctionalOptionAccountingCashMethodIncomeAndExpenses Then
			Object.BusinessActivity = Undefined;
		EndIf;
		Object.Order = Undefined;
		Object.PaymentDetails.Clear();
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentExpense.Other") Then
		Object.Counterparty = Undefined;
		Object.CounterpartyAccount = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.TaxKind = Undefined;
		Object.PayrollPayment.Clear();
		For Each TableRow IN Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.InvoiceForPayment = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentExpense.Taxes") Then
		Object.Counterparty = Undefined;
		Object.CounterpartyAccount = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.Correspondence = Undefined;
		Object.Division = Undefined;
		If Not FunctionalOptionAccountingCashMethodIncomeAndExpenses Then
			Object.BusinessActivity = Undefined;
		EndIf;
		Object.Order = Undefined;
		Object.PayrollPayment.Clear();
		For Each TableRow IN Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.InvoiceForPayment = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
		EndDo;
	EndIf;
	
EndProcedure // ClearAttributesNotRelatedToOperation()

// Procedure sets selection parameter links and available types.
//
&AtClient
Procedure SetChoiceParameterLinksAvailableTypes()
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentExpense.Vendor") Then
		
		Array = New Array();
		Array.Add(Type("DocumentRef.AdditionalCosts"));
		Array.Add(Type("DocumentRef.SupplierInvoice"));
		Array.Add(Type("DocumentRef.CustomerInvoice"));
		Array.Add(Type("DocumentRef.ReportToPrincipal"));
		Array.Add(Type("DocumentRef.SubcontractorReport"));
		Array.Add(Type("DocumentRef.Netting"));
		
		ValidTypes = New TypeDescription(Array, ,);
		Items.PaymentDetailsDocument.TypeRestriction = ValidTypes;
		
		ValidTypes = New TypeDescription("DocumentRef.PurchaseOrder", ,);
		Items.PaymentDetailsOrder.TypeRestriction = ValidTypes;
		
		ValidTypes = New TypeDescription("DocumentRef.SupplierInvoiceForPayment", , );
		Items.PaymentDetailsInvoiceForPayment.TypeRestriction = ValidTypes;
		
		Items.PaymentDetailsDocument.Title = "Shipment document";
		Items.PaymentDetailsDocument.ToolTip = "Paid document of goods shipment, works and services by a counterparty";
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentExpense.ToCustomer") Then
		
		Array = New Array();
		Array.Add(Type("DocumentRef.CashReceipt"));
		Array.Add(Type("DocumentRef.PaymentReceipt"));
		Array.Add(Type("DocumentRef.AcceptanceCertificate"));
		Array.Add(Type("DocumentRef.Netting"));
		Array.Add(Type("DocumentRef.CustomerOrder"));
		Array.Add(Type("DocumentRef.AgentReport"));
		Array.Add(Type("DocumentRef.ProcessingReport"));
		Array.Add(Type("DocumentRef.FixedAssetsTransfer"));
		Array.Add(Type("DocumentRef.SupplierInvoice"));
		Array.Add(Type("DocumentRef.CustomerInvoice"));
		
		ValidTypes = New TypeDescription(Array, ,);
		Items.PaymentDetailsDocument.TypeRestriction = ValidTypes;
		
		ValidTypes = New TypeDescription("DocumentRef.CustomerOrder", , );
		Items.PaymentDetailsOrder.TypeRestriction = ValidTypes;
		
		ValidTypes = New TypeDescription("DocumentRef.SupplierInvoiceForPayment", , );
		Items.PaymentDetailsInvoiceForPayment.TypeRestriction = ValidTypes;
		
		Items.PaymentDetailsDocument.Title = "Accounts document";
		Items.PaymentDetailsDocument.ToolTip = "Document of settlements with counterparty according to which cash assets are returned";
		
	EndIf;
	
EndProcedure // SetAvailableTypesSelectionParameterLinks()

// Procedure sets attributes visible depending on the mail.
//
&AtServer
Procedure SetAttributesVisibleDependingOnCorrespondence()
	
	If Object.Correspondence.TypeOfAccount = Enums.GLAccountsTypes.Expenses Then
		Items.BusinessActivity.Visible = True;
		Items.Division.Visible = True;
		Items.Order.Visible = True;
		If Not ValueIsFilled(Object.Division) Then
			User = Users.CurrentUser();
			SettingValue = SmallBusinessReUse.GetValueByDefaultUser(User, "MainDivision");
			Object.Division = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.StructuralUnits.MainDivision);
		EndIf;
	Else
		If Object.OperationKind <> Enums.OperationKindsPaymentExpense.Taxes // for entering based on
		 OR (Object.OperationKind = Enums.OperationKindsPaymentExpense.Taxes
		 AND Not FunctionalOptionAccountingCashMethodIncomeAndExpenses) Then
			Object.BusinessActivity = Undefined;
		EndIf;
		Object.Division = Undefined;
		Object.Order = Undefined;
		Items.BusinessActivity.Visible = False;
		Items.Division.Visible = False;
		Items.Order.Visible = False;
	EndIf;
	
EndProcedure // SetAttributesVisibleDependingOnMail()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - OnCreateAtServer event handler.
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
	
	If Object.OperationKind <> Enums.OperationKindsPaymentExpense.Salary
	   AND Object.PaymentDetails.Count() = 0 Then
		Object.PaymentDetails.Add();
		Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
	EndIf;
	
	// FO Use Payroll subsystem.
	SetVisibleByFOUseSubsystemPayroll();
	
	DocumentObject = FormAttributeToValue("Object");
	If DocumentObject.IsNew()
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		If ValueIsFilled(Parameters.BasisDocument) Then
			DocumentObject.Fill(Parameters.BasisDocument);
			ValueToFormAttribute(DocumentObject, "Object");
		EndIf;
		If ValueIsFilled(Object.BankAccount)
			AND TypeOf(Object.BankAccount.Owner) <> Type("CatalogRef.Companies") Then
			Object.BankAccount = Catalogs.BankAccounts.EmptyRef();
		EndIf; 
		If ValueIsFilled(Object.Company)
			AND ValueIsFilled(Object.BankAccount)
			AND Object.BankAccount.Owner <> Object.Company Then
			Object.Company = Object.BankAccount.Owner;
		EndIf; 
		If Not ValueIsFilled(Object.BankAccount) Then
			If ValueIsFilled(Object.CashCurrency) Then
				If Object.Company.BankAccountByDefault.CashCurrency = Object.CashCurrency Then
					Object.BankAccount = Object.Company.BankAccountByDefault;
				EndIf;
			Else
				Object.BankAccount = Object.Company.BankAccountByDefault;
				Object.CashCurrency = Object.BankAccount.CashCurrency;
			EndIf;
		Else
			Object.CashCurrency = Object.BankAccount.CashCurrency;
		EndIf;
		FillInContract(Parameters);
		SetCFItem();
	EndIf;
	
	If Object.PaymentDetails.Count() = 0 Then
		IsAdvance = False;
	Else
		IsAdvance = Object.PaymentDetails[0].AdvanceFlag;
	EndIf;
	
	If IsAdvance Then
		AdvanceFlag = Enums.YesNo.Yes;
	Else
		AdvanceFlag = Enums.YesNo.No;
	EndIf;
	
	// Form attributes setting.
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", Object.CashCurrency));
	ExchangeRate = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.ExchangeRate
	);
	Multiplicity = ?(
		//( elmi # 08.5
	    //StructureByCurrency.ExchangeRate = 0,
		  StructureByCurrency.Multiplicity = 0,
		//) elmi

		1,
		StructureByCurrency.Multiplicity
	);
	
	If Not ValueIsFilled(Object.Ref)
	   AND Not ValueIsFilled(Parameters.Basis)
	   AND Not ValueIsFilled(Parameters.CopyingValue)
	   AND Not Parameters.Property("BasisDocument") Then
		FillVATRateByCompanyVATTaxation();
	Else
		SetVisibleOfVATTaxation();
	EndIf;
	
	If Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		DefaultVATRate = Object.Company.DefaultVATRate;
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then
		DefaultVATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
	Else
		DefaultVATRate = SmallBusinessReUse.GetVATRateZero();
	EndIf;
	
	OperationKind = Object.OperationKind;
	CashCurrency = Object.CashCurrency;
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	FunctionalOptionAccountingCashMethodIncomeAndExpenses = Constants.FunctionalOptionAccountingCashMethodIncomeAndExpenses.Get();
	
	SetAttributesVisibleDependingOnCorrespondence();
	SetVisibleOfItemsDependsOnOperationKind();
	
	If Object.OperationKind = Enums.OperationKindsPaymentExpense.Taxes Then
		Items.BusinessActivityTaxes.Visible = FunctionalOptionAccountingCashMethodIncomeAndExpenses;
	EndIf;
	
	If Object.OperationKind = Enums.OperationKindsPaymentExpense.Salary Then
		Items.SalaryPayoffsBusinessActivity.Visible = FunctionalOptionAccountingCashMethodIncomeAndExpenses;
	EndIf;
	
	// Fill in tabular section while entering a document from the working place.
	If TypeOf(Parameters.FillingValues) = Type("Structure")
	   AND Parameters.FillingValues.Property("FillDetailsOfPayment")
	   AND Parameters.FillingValues.FillDetailsOfPayment Then
		
		TabularSectionRow = Object.PaymentDetails[0];
		
		TabularSectionRow.PaymentAmount = Object.DocumentAmount;
		TabularSectionRow.ExchangeRate = ?(
			TabularSectionRow.ExchangeRate = 0,
			1,
			TabularSectionRow.ExchangeRate
		);
		
		TabularSectionRow.Multiplicity = ?(
			TabularSectionRow.Multiplicity = 0,
			1,
			TabularSectionRow.Multiplicity
		);
		
		TabularSectionRow.SettlementsAmount = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
			TabularSectionRow.PaymentAmount,
			ExchangeRate,
			TabularSectionRow.ExchangeRate,
			Multiplicity,
			TabularSectionRow.Multiplicity
		);
		
		If Not ValueIsFilled(TabularSectionRow.VATRate) Then
			TabularSectionRow.VATRate = DefaultVATRate;
		EndIf;
		
		TabularSectionRow.VATAmount = TabularSectionRow.PaymentAmount - (TabularSectionRow.PaymentAmount) / ((TabularSectionRow.VATRate.Rate + 100) / 100);
		
	EndIf;
	
	SetAccountsAttributesVisible();
	
	SmallBusinessClientServer.SetPictureForComment(Items.Additionally, Object.Comment);
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, , "AdditionalAttributesGroup");
	// End StandardSubsystems.Properties
	
EndProcedure // OnCreateAtServer()

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ChangeProhibitionDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure // OnReadAtServer()

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	// Notification of payment.
	NotifyAboutBillPayment = False;
	NotifyAboutOrderPayment = False;
	
	For Each CurRow IN Object.PaymentDetails Do
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

// Procedure - event handler OnOpen.
// The current page is set in the procedure depending on the operation.
//
&AtClient
Procedure OnOpen(Cancel)
	
	SetChoiceParameterLinksAvailableTypes();
	SetCurrentPage();
	
    //( elmi # 08.5 
	SmallBusinessClient.RenameTitleExchangeRateMultiplicity( ThisForm, "PaymentDetails");
   //) elmi

	
EndProcedure // OnOpen()

// Procedure - event handler of the form BeforeWrite
//
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Modified 
		AND Object.Ref.IsEmpty() 
		AND ThereAreNodesRecipients() Then
		
		Cancel = True;
		NotifyDescription = New NotifyDescription("BeforeWriteEnd", ThisObject, New Structure("WriteParameters", WriteParameters));
		
		QuestionText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='While using the exchange you should reflect operation ""%1"" in ""Enterprise accounting"".
		|
		|Do you want to cancel the document record?';ru='При использовании обмена операцию ""%1"" рекомендуется отражать в ""Бухгалтерии предприятия"".
		|
		|Отменить запись документа?'"),
			String(OperationKind));
			
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo,, DialogReturnCode.Yes);
		Return;
		
	EndIf;
	
	// StandardSubsystems.PerformanceEstimation
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		PerformanceEstimationClientServer.StartTimeMeasurement("DocumentPaymentExpensePosting");
	EndIf;
	// StandardSubsystems.PerformanceEstimation
	
EndProcedure // BeforeWrite()

&AtClient
Procedure BeforeWriteEnd(Result, AdditionalParameters) Export
	If Result = DialogReturnCode.No Then
		Modified = False;
		Write(AdditionalParameters.WriteParameters);
	EndIf;
EndProcedure // BeforeWriteEnd()

// Procedure-handler of the BeforeWriteAtServer event.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(Object.PaymentDetails, MessageText, Object.Ref, Object.Company, Object.Counterparty, Object.OperationKind, Cancel);
		
		If MessageText <> "" Then
			
			Message = New UserMessage;
			Message.Text = ?(Cancel, NStr("en='Document is not posted! ';ru='Документ не проведен! '") + MessageText, MessageText);
			Message.Message();
			
			If Cancel Then
				Return;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure // BeforeWriteAtServer()

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AfterRecordingOfCounterparty" Then
		If ValueIsFilled(Parameter)
		   AND Object.Counterparty = Parameter Then
			SetAccountsAttributesVisible();
		EndIf;
	EndIf;
	
	// StandardSubsystems.Properties
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure //NotificationProcessing()

// Procedure - FillCheckProcessingAtServer event handler of the form.
//
&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - handler of the Execute event of the Pickup command
// Opens the form of debt forming documents selection.
//
&AtClient
Procedure Pick(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(Undefined,NStr("en='Specify the counterparty first.';ru='Укажите вначале контрагента!'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.BankAccount)
	   AND Not ValueIsFilled(Object.CashCurrency) Then
		ShowMessageBox(Undefined,NStr("en='Specify the bank account first.';ru='Укажите вначале банковский счет!'"));
		Return;
	EndIf;
	
	AddressPaymentDetailsInStorage = PlacePaymentDetailsToStorage();
	
	SelectionParameters = New Structure(
		"AddressPaymentDetailsInStorage,
		|SubsidiaryCompany,
		|Date,
		|Counterparty,
		|Ref,
		|OperationKind,
		|CashCurrency,
		|DocumentAmount",
		AddressPaymentDetailsInStorage,
		SubsidiaryCompany,
		Object.Date,
		Object.Counterparty,
		Object.Ref,
		Object.OperationKind,
		Object.CashCurrency,
		Object.DocumentAmount
	);
	
	Result = Undefined;

	
	OpenForm("CommonForm.VendorDebtsPickForm", SelectionParameters,,,,, New NotifyDescription("SelectionEnd", ThisObject, New Structure("AddressPaymentDetailsInStorage", AddressPaymentDetailsInStorage)));
	
EndProcedure

&AtClient
Procedure SelectionEnd(Result1, AdditionalParameters) Export
	
	AddressPaymentDetailsInStorage = AdditionalParameters.AddressPaymentDetailsInStorage;
	
	
	Result = Result1;
	If Result = DialogReturnCode.OK Then
		
		GetPaymentDetailsFromStorage(AddressPaymentDetailsInStorage);
		TabularSectionName = "PaymentDetails";
		For Each RowPaymentDetails IN Object.PaymentDetails Do
			If Not ValueIsFilled(RowPaymentDetails.VATRate) Then
				RowPaymentDetails.VATRate = DefaultVATRate;
			EndIf;
			CalculatePaymentSUM(RowPaymentDetails);
		EndDo;
		
		SetCurrentPage();
		
		If Object.PaymentDetails.Count() = 1 Then
			Object.DocumentAmount = Object.PaymentDetails.Total("PaymentAmount");
		EndIf;
		
	EndIf;

EndProcedure // Selection()

// You can call the procedure by clicking
// the button "FillByBasis" of the tabular field command panel.
//
&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		ShowMessageBox(Undefined, NStr("en='Basis document is not selected!';ru='Не выбран документ основание!'"));
		Return;
	EndIf;
	
	If (TypeOf(Object.BasisDocument) = Type("DocumentRef.CashTransferPlan")
		OR TypeOf(Object.BasisDocument) = Type("DocumentRef.CashOutflowPlan"))
		AND Not DocumentApproved(Object.BasisDocument) Then
		Raise NStr("en='You can not enter the cash register records basing on the unapproved plan document!';ru='Нельзя ввести перемещение денег на основании неутвержденного планового документа!'");
	EndIf;
	
	Response = Undefined;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), NStr("en='Document will be completely refilled by ""Basis""! Continue?';ru='Документ будет полностью перезаполнен по ""Основанию""! Продолжить?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		
		Object.BankAccount = Undefined;
		Object.CounterpartyAccount = Undefined;
		
		Object.PaymentDetails.Clear();
		Object.PayrollPayment.Clear();
		
		FillByDocument(Object.BasisDocument);
		
		If Object.OperationKind <> PredefinedValue("Enum.OperationKindsPaymentExpense.Salary")
			AND Object.PaymentDetails.Count() = 0 Then
			Object.PaymentDetails.Add();
			Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		EndIf;
		
		OperationKind = Object.OperationKind;
		CashCurrency = Object.CashCurrency;
		DocumentDate = Object.Date;
		
		SetCurrentPage();
		SetChoiceParameterLinksAvailableTypes();
		OperationKindOnChangeAtServer(False);
		
		FillInContract();
		
	EndIf;
	
EndProcedure // FillByBasis()

// Procedure - FillDetails command handler.
//
&AtClient
Procedure FillDetails(Command)
	
	If Object.DocumentAmount = 0 Then
		ShowMessageBox(Undefined,NStr("en='Specify amount of document first.';ru='Укажите вначале сумму документа.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.BankAccount)
	   AND Not ValueIsFilled(Object.CashCurrency) Then
		ShowMessageBox(Undefined,NStr("en='Specify the bank account first.';ru='Укажите вначале банковский счет!'"));
		Return;
	EndIf;
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("FillDetailsEnd", ThisObject), 
		NStr("en='Decryption will be completely refilled. Continue?';ru='Расшифровка будет полностью перезаполнена. Продолжить?'"),
		QuestionDialogMode.YesNo
	);
	
EndProcedure

&AtClient
Procedure FillDetailsEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	Object.PaymentDetails.Clear();
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentExpense.Vendor") Then
		
		FillPaymentDetails();
		
	EndIf;
	
	SetCurrentPage();
	
EndProcedure // FillDetails()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF HEADER ATTRIBUTES

// Procedure - event handler OnChange of the Counterparty input field.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	StructureData = GetDataCounterpartyOnChange(Object.Counterparty, Object.Company, Object.Date);
	
	If Object.PaymentDetails.Count() = 0 Then 
		
		Object.PaymentDetails[0].Contract = StructureData.Contract;
		
		If ValueIsFilled(Object.PaymentDetails[0].Contract) Then
			Object.PaymentDetails[0].ExchangeRate = ?(
				StructureData.ContractCurrencyRateRepetition.ExchangeRate = 0,
				1,
				StructureData.ContractCurrencyRateRepetition.ExchangeRate
			);
			Object.PaymentDetails[0].Multiplicity = ?(
				StructureData.ContractCurrencyRateRepetition.Multiplicity = 0,
				1,
				StructureData.ContractCurrencyRateRepetition.Multiplicity
			);
		EndIf;
		
		Object.PaymentDetails[0].ExchangeRate = ?(
			Object.PaymentDetails[0].ExchangeRate = 0,
			1,
			Object.PaymentDetails[0].ExchangeRate
		);
		Object.PaymentDetails[0].Multiplicity = ?(
			Object.PaymentDetails[0].Multiplicity = 0,
			1,
			Object.PaymentDetails[0].Multiplicity
		);
		
		Object.PaymentDetails[0].SettlementsAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
			Object.PaymentDetails[0].PaymentAmount,
			ExchangeRate,
			Object.PaymentDetails[0].ExchangeRate,
			Multiplicity,
			Object.PaymentDetails[0].Multiplicity
		);
		
	EndIf;
	
EndProcedure // CounterpartyOnChange()

// Procedure - event handler OperationKindOnChange.
// Manages pages while changing document operation kind.
//
&AtClient
Procedure OperationKindOnChange(Item)
	
	TypeOfOperationsBeforeChange = OperationKind;
	OperationKind = Object.OperationKind;
	
	If OperationKind <> TypeOfOperationsBeforeChange Then
		SetCurrentPage();
		ClearAttributesNotRelatedToOperation();
		SetChoiceParameterLinksAvailableTypes();
		OperationKindOnChangeAtServer();
		If Object.PaymentDetails.Count() = 1 Then
			Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		EndIf;
	EndIf;
	
EndProcedure // OperationKindOnChange()

// Procedure - event handler OnChange of the Date input field.
// IN procedure situation is determined when date change document is
// into document numbering another period and in this case
// assigns to the document new unique number.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
		MessageText = NStr("en='Currency rate of the bank account has been changed. Recalculate the document amount?';ru='Изменился курс валюты банковского счета. Пересчитать суммы документа?'");
		RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData, MessageText);
	EndIf;
	
EndProcedure // DateOnChange()

// Procedure - event handler OnChange of the Company input field.
// IN procedure is executed document
// number clearing and also make parameter set of the form functional options.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange();
	Counterparty = StructureData.Counterparty;
	Object.BankAccount = StructureData.BankAccount;
	Object.CounterpartyAccount = StructureData.CounterpartyAccount;
	
	CurrencyCashBeforeChanging = CashCurrency;
	Object.CashCurrency = StructureData.CashCurrency;
	CashCurrency = StructureData.CashCurrency;
	
	// If currency is not changed, do nothing.
	If CashCurrency = CurrencyCashBeforeChanging Then
		Return;
	EndIf;
	
	If Object.PaymentDetails.Count() > 0 Then
		Object.PaymentDetails[0].Contract = Undefined;
	EndIf;
	
	MessageText = NStr("en='Currency of the bank account has been changed. Recalculate the document amount?';ru='Изменилась валюта банковского счета. Пересчитать суммы документа?'");
	RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData, MessageText);
	
EndProcedure // CompanyOnChange()

// Procedure - OnChange event handler of BankAccount input field.
//
&AtClient
Procedure BankAccountOnChange(Item)
	
	StructureData = GetDataBankAccountOnChange(
		Object.Date,
		Object.BankAccount,
		Object.CounterpartyAccount
	);
	
	If Object.CashCurrency = StructureData.CashCurrency Then
		Return;
	EndIf;
	
	Object.CounterpartyAccount					= StructureData.CounterpartyAccount;
	Object.CashCurrency			= StructureData.CashCurrency;
	CashCurrency 					= StructureData.CashCurrency;
	If Object.PaymentDetails.Count() > 0 Then
		Object.PaymentDetails[0].Contract	= Undefined;
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentExpense.Salary") Then
		MessageText = NStr("en='Currency of the bank account has been changed. The ""Payroll sheets"" list will be cleared.';ru='Изменилась валюта банковского счета. Список ""Платежные ведомости"" будет очищен.'");
		ShowMessageBox(New NotifyDescription("BankAccountOnChangeEnd", ThisObject, New Structure("StructureData, MessageText", StructureData, MessageText)), MessageText);
		Return;
	EndIf;
	
	BankAccountOnChangeFragment(StructureData);
EndProcedure

&AtClient
Procedure BankAccountOnChangeEnd(AdditionalParameters) Export
	
	StructureData = AdditionalParameters.StructureData;
	MessageText = AdditionalParameters.MessageText;
	
	Object.PayrollPayment.Clear();
	
	BankAccountOnChangeFragment(StructureData);

EndProcedure

&AtClient
Procedure BankAccountOnChangeFragment(Val StructureData)
	
	Var MessageText;
	
	MessageText = NStr("en='Currency of the bank account has been changed. Recalculate the document amount?';ru='Изменилась валюта банковского счета. Пересчитать суммы документа?'");
	RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData, MessageText);
	
EndProcedure // BankAccountOnChange()

// Procedure - OnChange event handler of Mail input field.
//
&AtClient
Procedure CorrespondenceOnChange(Item)
	
	SetAttributesVisibleDependingOnCorrespondence();
	
EndProcedure

// Procedure - OnChange event handler of DocumentAmount input field.
//
&AtClient
Procedure DocumentAmountOnChange(Item)
	
	If Object.PaymentDetails.Count() = 1 Then
		
		TabularSectionRow = Object.PaymentDetails[0];
		
		TabularSectionRow.PaymentAmount = Object.DocumentAmount;
		TabularSectionRow.ExchangeRate = ?(
			TabularSectionRow.ExchangeRate = 0,
			1,
			TabularSectionRow.ExchangeRate
		);
		
		TabularSectionRow.Multiplicity = ?(
			TabularSectionRow.Multiplicity = 0,
			1,
			TabularSectionRow.Multiplicity
		);
		
		TabularSectionRow.SettlementsAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
			TabularSectionRow.PaymentAmount,
			ExchangeRate,
			TabularSectionRow.ExchangeRate,
			Multiplicity,
			TabularSectionRow.Multiplicity
		);
		
		If Not ValueIsFilled(TabularSectionRow.VATRate) Then
			TabularSectionRow.VATRate = DefaultVATRate;
		EndIf;
		
		CalculateVATSUM(TabularSectionRow);
		
	EndIf;
	
EndProcedure // DocumentAmountOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABULAR SECTION ATTRIBUTE EVENT HANDLERS

// Procedure - BeforeDeletion event handler of PaymentDetails tabular section.
//
&AtClient
Procedure PaymentDetailsBeforeDelete(Item, Cancel)
	
	If Object.PaymentDetails.Count() <= 1 Then
		Cancel = True;
	EndIf;
	
EndProcedure // PaymentDetailsBeforeDelete()

// Procedure - OnChange event handler of PaymentDetailsContract input field.
// Sets exchange rate and unit conversion factor of the contract currency.
//
&AtClient
Procedure PaymentDetailsContractOnChange(Item)
	
	ProcessCounterpartyContractChange();
	
EndProcedure // PaymentDetailsContractOnChange()

// Procedure - SelectionStart event handler of PaymentDetailsContract input field.
// Sets exchange rate and unit conversion factor of the contract currency.
//
&AtClient
Procedure PaymentDetailsContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	ProcessStartChoiceCounterpartyContract(Item, StandardProcessing);
	
EndProcedure

// Procedure - OnChange event handler of PaymentDetailsSettlementsKind input field.
// Clears an attribute document if a settlement type is - "Advance".
//
&AtClient
Procedure PaymentDetailsAdvanceFlagOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentExpense.Vendor") Then
		If TabularSectionRow.AdvanceFlag Then
			TabularSectionRow.Document = Undefined;
		Else
			TabularSectionRow.PlanningDocument = Undefined;
		EndIf;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentExpense.ToCustomer") Then
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashReceipt")
		 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentReceipt") Then
			TabularSectionRow.AdvanceFlag = True;
			ShowMessageBox(Undefined,NStr("en='The advance flag is always set for this document type!';ru='Для данного типа документа расчетов признак аванса всегда установлен!'"));
		ElsIf TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.Netting") Then
			TabularSectionRow.AdvanceFlag = False;
			ShowMessageBox(Undefined,NStr("en='The advance flag can not be set for this document type!';ru='Для данного типа документа расчетов нельзя установить признак аванса!'"));
		EndIf;
	EndIf;
	
EndProcedure // PaymentDetailsAdvanceFlagOnChange()

// Procedure - SelectionStart event handler of PaymentDetailsDocument input field.
// Passes the current attribute value to the parameters.
//
&AtClient
Procedure PaymentDetailsDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If TabularSectionRow.AdvanceFlag
		AND Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentExpense.Vendor") Then
		
		ShowMessageBox(, NStr("en='The current document with the ""Advance"" flag will be used for settlement!';ru='Для вида расчета с признаком ""Аванс"" документом расчетов будет текущий!'"));
		
	Else
		
		ThisIsAccountsReceivable = Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentExpense.ToCustomer");
		
		StructureFilter = New Structure();
		StructureFilter.Insert("Counterparty", Object.Counterparty);
		
		If ValueIsFilled(TabularSectionRow.Contract) Then
			StructureFilter.Insert("Contract", TabularSectionRow.Contract);
		EndIf;
		
		ParameterStructure = New Structure("Filter, ThisIsAccountsReceivable, DocumentType",
			StructureFilter,
			ThisIsAccountsReceivable,
			TypeOf(Object.Ref)
		);
		
		OpenForm("CommonForm.SettlementsDocumentChoiceForm", ParameterStructure, Item);
		
	EndIf;
	
EndProcedure // PaymentDetailsDocumentSelectionStart()

// Procedure - SelectionDataProcessor event handler of PaymentDetailsDocument input field.
//
&AtClient
Procedure PaymentDetailsDocumentChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	ProcessAccountsDocumentSelection(ValueSelected);
	
EndProcedure

// Procedure - OnChange event handler of the field in PaymentDetailsSettlementsAmount.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentDetailsSettlementsAmountOnChange(Item)
	
	CalculatePaymentSUM(Items.PaymentDetails.CurrentData);
	If Object.PaymentDetails.Count() = 1 Then
		Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
	EndIf;
	
EndProcedure // PaymentDetailsSettlementsAmountOnChange()

// Procedure - OnChange event handler of PaymentDetailsExchangeRate input field.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentDetailsRateOnChange(Item)
	
	CalculatePaymentSUM(Items.PaymentDetails.CurrentData);
	If Object.PaymentDetails.Count() = 1 Then
		Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
	EndIf;
	
EndProcedure // PaymentDetailsRateOnChange()

// Procedure - OnChange event handler of PaymentDetailsUnitConversionFactor input field.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentDetailsRepetitionOnChange(Item)
	
	CalculatePaymentSUM(Items.PaymentDetails.CurrentData);
	If Object.PaymentDetails.Count() = 1 Then
		Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
	EndIf;
	
EndProcedure // PaymentDetailsUnitConversionFactorOnChange()

// Procedure - OnChange event handler of PaymentDetailsPaymentAmount input field.
// Calculates exchange rate and unit conversion factor of the settlements currency and VAT amount.
//
&AtClient
Procedure PaymentDetailsPaymentAmountOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.ExchangeRate = 0,
		1,
		TabularSectionRow.ExchangeRate
	);
	TabularSectionRow.Multiplicity = ?(
		TabularSectionRow.Multiplicity = 0,
		1,
		TabularSectionRow.Multiplicity
	);
	
	//( elmi # 08.5
	//TabularSectionRow.ExchangeRate = ?(
	//	TabularSectionRow.SettlementsAmount = 0,
	//	1,
	//	TabularSectionRow.PaymentAmount / TabularSectionRow.SettlementsAmount * ExchangeRate
	//);
	If SmallBusinessServer.IndirectQuotationInUse() Then
		TabularSectionRow.Multiplicity = ?(
			TabularSectionRow.PaymentAmount = 0,
			1,
			TabularSectionRow.SettlementsAmount / TabularSectionRow.PaymentAmount * Multiplicity
		);
	Else
		TabularSectionRow.ExchangeRate = ?(
			TabularSectionRow.SettlementsAmount = 0,
			1,
			TabularSectionRow.PaymentAmount / TabularSectionRow.SettlementsAmount * ExchangeRate
		);
	EndIF;
    //) elmi

	
	
	If Not ValueIsFilled(TabularSectionRow.VATRate) Then
		TabularSectionRow.VATRate = DefaultVATRate;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	
EndProcedure // PaymentDetailsPaymentAmountOnChange()

// Procedure - OnChange event handler of PaymentDetailsVATRate input field.
// Calculates VAT amount.
//
&AtClient
Procedure PaymentDetailsVATRateOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	
EndProcedure // PaymentDetailsVATRateOnChange()

// Procedure - OnChange event handler of PaymentDetailsDocument input field.
//
&AtClient
Procedure PaymentDetailsDocumentOnChange(Item)
	
	RunActionsOnAccountsDocumentChange();
	
EndProcedure // PaymentDetailsDocumentOnChange() 

// Procedure - OnChange event handler of SalaryPaymentStatement input field.
//
&AtClient
Procedure SalaryPayStatementOnChange(Item)
	
	TabularSectionRow = Items.PayrollPayment.CurrentData;
	TabularSectionRow.PaymentAmount = GetDataSalaryPayStatementOnChange(TabularSectionRow.Statement);
	
EndProcedure // SalaryPaymentStatementOnChange()

//////////////////////////////////////////////

// Procedure sets the items visible depending on the operation kind.
//
&AtServer
Procedure SetVisibleOfItemsDependsOnOperationKind()
	
	Items.SettlementsWithCounterparty.Visible = False;
	Items.SettlementsWithAdvanceHolder.Visible = False;
	Items.OtherSettlements.Visible = False;
	Items.PayrollPayments.Visible = False;
	Items.TaxesSettlements.Visible = False;
	
	Items.VATTaxation.Visible = False;
	Items.Counterparty.Visible = False;
	Items.CounterpartyAccount.Visible = False;
	Items.AdvanceHolder.Visible = False;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentExpense.Vendor") Then
		
		Items.SettlementsWithCounterparty.Visible = True;
		Items.PaymentDetailsPickup.Visible = True;
		Items.PaymentDetailsFillDetails.Visible = True;
		
		Items.Counterparty.Visible = True;
		Items.Counterparty.Title = "Vendor";
		Items.CounterpartyAccount.Visible = True;
		Items.VATTaxation.Visible = True;
		
		NewArray = New Array();
		NewConnection = New ChoiceParameterLink("Filter.Counterparty", "Object.Counterparty");
		NewArray.Add(NewConnection);
		NewConnections = New FixedArray(NewArray);
		Items.PaymentDetailsInvoiceForPayment.ChoiceParameterLinks = NewConnections;
		
		Items.PaymentAmount.Visible = True;
		Items.PaymentAmount.Title = NStr("en='Payment amount';ru='Сумма платежа (итог)'");
		Items.SettlementsAmount.Visible = Not GetFunctionalOption("CurrencyTransactionsAccounting");
		Items.VATAmount.Visible = Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT;
		Items.PayrollPaymentTotalPaymentAmount.Visible = False;
	
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentExpense.ToCustomer") Then
		
		Items.SettlementsWithCounterparty.Visible = True;
		Items.PaymentDetailsPickup.Visible = False;
		Items.PaymentDetailsFillDetails.Visible = False;
		
		Items.Counterparty.Visible = True;
		Items.Counterparty.Title = "Customer";
		Items.CounterpartyAccount.Visible = True;
		Items.VATTaxation.Visible = True;
		
		NewArray = New Array();
		NewConnection = New ChoiceParameterLink("Filter.Counterparty", "Object.Counterparty");
		NewArray.Add(NewConnection);
		NewConnections = New FixedArray(NewArray);
		Items.PaymentDetailsInvoiceForPayment.ChoiceParameterLinks = NewConnections;
		
		Items.PaymentAmount.Visible = True;
		Items.PaymentAmount.Title = NStr("en='Payment amount';ru='Сумма платежа (итог)'");
		Items.SettlementsAmount.Visible = Not GetFunctionalOption("CurrencyTransactionsAccounting");
		Items.VATAmount.Visible = Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT;
		Items.PayrollPaymentTotalPaymentAmount.Visible = False;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentExpense.ToAdvanceHolder") Then
		
		Items.SettlementsWithAdvanceHolder.Visible = True;
		Items.AdvanceHolder.Visible = True;
		
		Items.PaymentAmount.Visible = True;
		Items.PaymentAmount.Title = NStr("en='Amount (Plan)';ru='Сумма (план)'");
		Items.SettlementsAmount.Visible = False;
		Items.VATAmount.Visible = False;
		Items.PayrollPaymentTotalPaymentAmount.Visible = False;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentExpense.Salary") Then
		
		Items.PayrollPayments.Visible = True;
		
		Items.PaymentAmount.Visible = False;
		Items.SettlementsAmount.Visible = False;
		Items.VATAmount.Visible = False;
		Items.PayrollPaymentTotalPaymentAmount.Visible = True;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentExpense.Taxes") Then
		
		Items.TaxesSettlements.Visible = True;
		
		Items.PaymentAmount.Visible = True;
		Items.PaymentAmount.Title = NStr("en='Amount (Plan)';ru='Сумма (план)'");
		Items.SettlementsAmount.Visible = False;
		Items.VATAmount.Visible = False;
		Items.PayrollPaymentTotalPaymentAmount.Visible = False;
		
	Else
		
		Items.OtherSettlements.Visible = True;
		
		Items.PaymentAmount.Visible = True;
		Items.PaymentAmount.Title = NStr("en='Amount (Plan)';ru='Сумма (план)'");
		Items.SettlementsAmount.Visible = False;
		Items.VATAmount.Visible = False;
		Items.PayrollPaymentTotalPaymentAmount.Visible = False;
		
	EndIf;
	
	SetVisiblePlanningDocuments();
	
EndProcedure // ItemsSetVisibleDependingOnOperationKind()

// Procedure executes actions while changing counterparty contract.
//
&AtClient
Procedure ProcessCounterpartyContractChange()
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If ValueIsFilled(TabularSectionRow.Contract) Then
		StructureData = GetDataPaymentDetailsContractOnChange(
			Object.Date,
			TabularSectionRow.Contract
		);
		TabularSectionRow.ExchangeRate = ?(
			StructureData.ContractCurrencyRateRepetition.ExchangeRate = 0,
			1,
			StructureData.ContractCurrencyRateRepetition.ExchangeRate
		);
		TabularSectionRow.Multiplicity = ?(
			StructureData.ContractCurrencyRateRepetition.Multiplicity = 0,
			1,
			StructureData.ContractCurrencyRateRepetition.Multiplicity
		);
	EndIf;
	
	TabularSectionRow.SettlementsAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.PaymentAmount,
		ExchangeRate,
		TabularSectionRow.ExchangeRate,
		Multiplicity,
		TabularSectionRow.Multiplicity
	);
	
EndProcedure // ProcessCounterpartyContractChange()

// Procedure executes actions while starting to select a counterparty contract.
//
&AtClient
Procedure ProcessStartChoiceCounterpartyContract(Item, StandardProcessing)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	If TabularSectionRow = Undefined Then
		Return;
	EndIf;
	
	FormParameters = GetChoiceFormParameters(Object.Ref, Object.Company, Object.Counterparty, TabularSectionRow.Contract, Object.OperationKind);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure // ProcessCounterpartyContractChange()

// Procedure fills in the PaymentDetails TS string with the settlements document data.
//
&AtClient
Procedure ProcessAccountsDocumentSelection(DocumentData)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	If TypeOf(DocumentData) = Type("Structure") Then
		
		TabularSectionRow.Document = DocumentData.Document;
		TabularSectionRow.Order = DocumentData.Order;
		TabularSectionRow.InvoiceForPayment = DocumentData.InvoiceForPayment;
		
		If Not ValueIsFilled(TabularSectionRow.Contract) Then
			TabularSectionRow.Contract = DocumentData.Contract;
			ProcessCounterpartyContractChange();
		EndIf;
		
		RunActionsOnAccountsDocumentChange();
		
		Modified = True;
		
	EndIf;
	
EndProcedure // ProcessSettlementsDocumentSelection()

// Procedure determines an advance flag depending on the settlements document type.
//
&AtClient
Procedure RunActionsOnAccountsDocumentChange()
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsPaymentExpense.ToCustomer") Then
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashReceipt")
			OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentReceipt") Then
			
			TabularSectionRow.AdvanceFlag = True;
			
		Else
			
			TabularSectionRow.AdvanceFlag = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure // ExecuteActionsOnSettlementsDocumentChange()

// Procedure is filling the payment details.
//
&AtServer
Procedure FillPaymentDetails(CurrentObject = Undefined)
	
	Document = FormAttributeToValue("Object");
	Document.FillPaymentDetails();
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
EndProcedure // FillPaymentDetails()

&AtClient
Procedure VATTaxationOnChange(Item)
	
	FillVATRateByVATTaxation();
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure // CommentOnChange()

&AtClient
Procedure Attachable_SetPictureForComment()
	
	SmallBusinessClientServer.SetPictureForComment(Items.Additionally, Object.Comment);
	
EndProcedure

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

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties()
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm);
	
EndProcedure // UpdateAdditionalAttributeItems()
// End StandardSubsystems.Properties

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
