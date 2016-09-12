////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Procedure of the field change data processor Operation kind on server.
//
&AtServer
Procedure SetCFItemWhenChangingTheTypeOfOperations()
	
	If Object.OperationKind = Enums.OperationKindsCashPayment.ToCustomer
		AND (Object.Item = Catalogs.CashFlowItems.PaymentToVendor
		OR Object.Item = Catalogs.CashFlowItems.Other
		OR Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers) Then
		Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	ElsIf Object.OperationKind = Enums.OperationKindsCashPayment.Vendor
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
	
	If Object.OperationKind = Enums.OperationKindsCashPayment.ToCustomer Then
		Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	ElsIf Object.OperationKind = Enums.OperationKindsCashPayment.Vendor Then
		Object.Item = Catalogs.CashFlowItems.PaymentToVendor;
	Else
		Object.Item = Catalogs.CashFlowItems.Other;
	EndIf;
	
EndProcedure // OperationKindOnChangeAtServer()

// Procedure expands the operation kinds selection list.
//
&AtServer
Procedure SupplementOperationKindsChoiceList()
	
	If Constants.FunctionalOptionAccountingRetail.Get() Then
		Items.OperationKind.ChoiceList.Add(Enums.OperationKindsCashPayment.TransferToCashCR);
	EndIf;
	
	Items.OperationKind.ChoiceList.Add(Enums.OperationKindsCashPayment.Other);
	
EndProcedure // AdditOperationKindsChoiceList()

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
	
	QuestionParameters = New Structure;
	QuestionParameters.Insert("ExchangeRateBeforeChange", ExchangeRateBeforeChange);
	QuestionParameters.Insert("MultiplicityBeforeChange", MultiplicityBeforeChange);
	
	NotifyDescription = New NotifyDescription("QuestionAmountRecalculationOnChangeCashAssetsCurrencyExchangeRateEnd", ThisObject, QuestionParameters);
	
	ShowQueryBox(NOTifyDescription, MessageText, QuestionDialogMode.YesNo);
	
EndProcedure // RecalculateAmountsOnCashAssetsCurrencyRateChange()

// Executes actions after answering the question about amount recalculation while changing currency exchange rate of cash assets.
//
&AtClient
Procedure QuestionAmountRecalculationOnChangeCashAssetsCurrencyExchangeRateEnd(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		
		ExchangeRateBeforeChange = AdditionalParameters.ExchangeRateBeforeChange;
		MultiplicityBeforeChange = AdditionalParameters.MultiplicityBeforeChange;
		
		If Object.PaymentDetails.Count() > 0 
		   AND Object.OperationKind <> PredefinedValue("Enum.OperationKindsCashPayment.Salary") Then // only header is recalculated for the "Salary" operation kind.
			If Object.OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.ToCustomer")
			 OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.Vendor") Then
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

EndProcedure

// Recalculate payment amount in the tabular section passed string.
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
		"CounterpartyDescriptionFull",
		Counterparty.DescriptionFull
	);
	
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
Function GetDataCashAssetsCurrencyOnChange(Date, CashCurrency)
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"CurrencyRateRepetition",
		InformationRegisters.CurrencyRates.GetLast(
			Date,
			New Structure("Currency", CashCurrency)
		)
	);
	
	Return StructureData;
	
EndFunction // GetDataCashAssetsCurrencyOnChange()

// Receives data set from the server for the AdvanceHolderOnChange procedure.
//
&AtServerNoContext
Function GetDataAdvanceHolderOnChange(AdvanceHolder, Date)
	
	StructureData = New Structure;
	StructureData.Insert("AdvanceHolderDescription", "");
	StructureData.Insert("DocumentKind1", "");
	StructureData.Insert("DocumentSeries", "");
	StructureData.Insert("DocumentNumber", "");
	StructureData.Insert("DocumentIssueDate", "");
	StructureData.Insert("DocumentWhoIssued", "");
	
	Query = New Query();
	Query.Text =
	"SELECT
	|	IndividualsDocumentsSliceLast.Period,
	|	IndividualsDocumentsSliceLast.Ind,
	|	PRESENTATION(IndividualsDocumentsSliceLast.Ind) AS AdvanceHolderDescription,
	|	IndividualsDocumentsSliceLast.DocumentKind,
	|	IndividualsDocumentsSliceLast.Series,
	|	IndividualsDocumentsSliceLast.Number,
	|	IndividualsDocumentsSliceLast.IssueDate,
	|	IndividualsDocumentsSliceLast.ValidityPeriod,
	|	IndividualsDocumentsSliceLast.WhoIssued,
	|	IndividualsDocumentsSliceLast.DivisionCode,
	|	IndividualsDocumentsSliceLast.IsIdentityDocument,
	|	IndividualsDocumentsSliceLast.Presentation,
	|	IndividualsDocumentsSliceLast.DeleteDocumentKind
	|FROM
	|	InformationRegister.IndividualsDocuments.SliceLast(&Date, ) AS IndividualsDocumentsSliceLast
	|WHERE
	|	IndividualsDocumentsSliceLast.Ind = &AdvanceHolder
	|	AND IndividualsDocumentsSliceLast.IsIdentityDocument";
	
	Query.SetParameter("AdvanceHolder", AdvanceHolder.Ind);
	Query.SetParameter("Date", Date);
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	StructureData.AdvanceHolderDescription = AdvanceHolder.Description;
	
	If SelectionOfQueryResult.Next() Then
	
		StructureData.AdvanceHolderDescription = SelectionOfQueryResult.AdvanceHolderDescription;
		StructureData.DocumentKind1 = SelectionOfQueryResult.DocumentKind;
		StructureData.DocumentSeries = SelectionOfQueryResult.Series;
		StructureData.DocumentNumber = SelectionOfQueryResult.Number;
		StructureData.DocumentIssueDate = SelectionOfQueryResult.IssueDate;
		StructureData.DocumentWhoIssued = SelectionOfQueryResult.WhoIssued;
		
	EndIf;
	
	Return StructureData;
	
EndFunction // GetDataAdvanceHolderOnChange()

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
	
	Return StructureData;
	
	FillVATRateByCompanyVATTaxation();
	
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
	
	PrintReceiptEnabled = False;
	
	Button = Items.Find("PrintReceipt");
	If Button <> Undefined Then
		
		If Object.OperationKind = Enums.OperationKindsCashPayment.ToCustomer
		   AND GetFunctionalOption("UsePeripherals") Then
			PrintReceiptEnabled = True;
		EndIf;
		
		Button.Enabled = PrintReceiptEnabled;
		Items.Decoration4.Visible = PrintReceiptEnabled;
		Items.ReceiptCRNumber.Visible = PrintReceiptEnabled;
		
	EndIf;
	
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
	
	If Object.OperationKind = Enums.OperationKindsCashPayment.ToCustomer Then
		
		Object.VATTaxation = SmallBusinessServer.VATTaxation(Object.Company,, Object.Date);
		
	Else
		
		Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT;
		
	EndIf;
	
	If (Object.OperationKind = Enums.OperationKindsCashPayment.ToCustomer
		OR Object.OperationKind = Enums.OperationKindsCashPayment.Vendor)
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
	
	If Object.OperationKind = Enums.OperationKindsCashPayment.ToCustomer
		OR Object.OperationKind = Enums.OperationKindsCashPayment.Vendor
		OR Object.OperationKind = Enums.OperationKindsCashPayment.Salary
		OR Not GetFunctionalOption("PaymentCalendar") Then
		Items.PlanningDocuments.Visible = False;
	Else
		Items.PlanningDocuments.Visible = True;
	EndIf;
	
EndProcedure // SetVisibleVATTaxation()

&AtServer
// Procedure fills the VAT rate in the tabular section according to the taxation system.
// 
Procedure FillVATRateByVATTaxation(RestoreRatesOfVAT = True)
	
	FillDefaultVATRate();
	
	If Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		
		If Object.OperationKind = Enums.OperationKindsCashPayment.ToCustomer
		 OR Object.OperationKind = Enums.OperationKindsCashPayment.Vendor Then
			
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
		
		If Object.OperationKind = Enums.OperationKindsCashPayment.ToCustomer
		 OR Object.OperationKind = Enums.OperationKindsCashPayment.Vendor Then
			
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
		
		If Object.OperationKind = Enums.OperationKindsCashPayment.ToCustomer
			OR Object.OperationKind = Enums.OperationKindsCashPayment.Vendor Then
			
			Items.PaymentDetailsVATRate.Visible = True;
			Items.PaymentDetailsVatAmount.Visible = True;
			
		EndIf;
		
		DefaultVATRate = Object.Company.DefaultVATRate;
		
	Else
		
		If Object.OperationKind = Enums.OperationKindsCashPayment.ToCustomer
			OR Object.OperationKind = Enums.OperationKindsCashPayment.Vendor Then
			
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

// Procedure sets the items visible depending on the operation kind.
//
&AtServer
Procedure SetVisibleOfItemsDependsOnOperationKind()
	
	Items.SettlementsWithCounterparty.Visible = False;
	Items.SettlementsWithAdvanceHolder.Visible = False;
	Items.SalaryPayToEmployee.Visible = False;
	Items.PayrollPayments.Visible = False;
	Items.TaxesSettlements.Visible = False;
	Items.OtherSettlements.Visible = False;
	Items.TransferToCashCR.Visible = False;
	
	Items.VATTaxation.Visible = False;
	Items.DocumentAmount.Width = 14;
	
	Items.AdvanceHolder.Visible = False;
	Items.Counterparty.Visible = False;
	
	If OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.Vendor") Then
		
		Items.SettlementsWithCounterparty.Visible = True;
		Items.PaymentDetailsPickup.Visible = True;
		Items.PaymentDetailsFillDetails.Visible = True;
		
		Items.Counterparty.Visible = True;
		Items.Counterparty.Title = "Vendor";
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
		
	ElsIf OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.ToCustomer") Then
		
		Items.SettlementsWithCounterparty.Visible = True;
		Items.PaymentDetailsPickup.Visible = False;
		Items.PaymentDetailsFillDetails.Visible = False;
		
		Items.Counterparty.Visible = True;
		Items.Counterparty.Title = "Customer";
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
		
	ElsIf OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.ToAdvanceHolder") Then
		
		Items.SettlementsWithAdvanceHolder.Visible = True;
		Items.AdvanceHolder.Visible = True;
		Items.AdvanceHolder.Title = "AdvanceHolder";
		Items.DocumentAmount.Width = 13;
		
		Items.PaymentAmount.Visible = True;
		Items.PaymentAmount.Title = NStr("en='Amount (Plan)';ru='Сумма (план)'");
		Items.SettlementsAmount.Visible = False;
		Items.VATAmount.Visible = False;
		Items.PayrollPaymentTotalPaymentAmount.Visible = False;
		
	ElsIf OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.SalaryForEmployee") Then
		
		Items.SalaryPayToEmployee.Visible = True;
		Items.AdvanceHolder.Visible = True;
		Items.AdvanceHolder.Title = "Employee";
		
		Items.PaymentAmount.Visible = True;
		Items.PaymentAmount.Title = NStr("en='Amount (Plan)';ru='Сумма (план)'");
		Items.SettlementsAmount.Visible = False;
		Items.VATAmount.Visible = False;
		Items.PayrollPaymentTotalPaymentAmount.Visible = False;
		
	ElsIf OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.Salary") Then
		
		Items.PayrollPayments.Visible = True;
		
		Items.PaymentAmount.Visible = False;
		Items.SettlementsAmount.Visible = False;
		Items.VATAmount.Visible = False;
		Items.PayrollPaymentTotalPaymentAmount.Visible = True;
		
	ElsIf OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.Taxes") Then
		
		Items.TaxesSettlements.Visible = True;
		
		Items.PaymentAmount.Visible = True;
		Items.PaymentAmount.Title = NStr("en='Amount (Plan)';ru='Сумма (план)'");
		Items.SettlementsAmount.Visible = False;
		Items.VATAmount.Visible = False;
		Items.PayrollPaymentTotalPaymentAmount.Visible = False;
		
	ElsIf OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.TransferToCashCR") Then
		
		Items.TransferToCashCR.Visible = True;
		
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

// Procedure executes actions while starting to select counterparty contract.
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

// Procedure determines advance flag depending on the settlements document type.
//
&AtClient
Procedure RunActionsOnAccountsDocumentChange()
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.ToCustomer") Then
		
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

&AtServer
// Procedure sets the form attribute visible
// from option Use subsystem Payroll.
//
// Parameters:
// No.
//
Procedure SetVisibleByFOUseSubsystemPayroll()
	
	// Salary.
	If Constants.FunctionalOptionUseSubsystemPayroll.Get() Then
		Items.OperationKind.ChoiceList.Add(Enums.OperationKindsCashPayment.SalaryForEmployee, "Salary for employee");
		Items.OperationKind.ChoiceList.Add(Enums.OperationKindsCashPayment.Salary, "Salary by statement");
	EndIf;
	
	// Taxes.
	Items.OperationKind.ChoiceList.Add(Enums.OperationKindsCashPayment.Taxes, "Taxes");
	
EndProcedure // SetVisibleByFOUseSubsystemPayroll()

// Procedure receives the default petty cash currency.
//
&AtServerNoContext
Function GetPettyCashAccountingCurrencyAtServer(PettyCash)
	
	Return PettyCash.CurrencyByDefault;
	
EndFunction // GetPettyCashDefaultCurrencyOnServer()

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

// Determines whether there are recipient nodes for document while using exchange.
//
&AtServer
Function ThereAreNodesRecipients()
	
	NodesFound = False;
	
	If Object.OperationKind <> Enums.OperationKindsCashPayment.Salary
		AND Object.OperationKind <> Enums.OperationKindsCashPayment.SalaryForEmployee
		AND Object.OperationKind <> Enums.OperationKindsCashPayment.Taxes
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

// Checks whether document is approved or not.
//
&AtServerNoContext
Function DocumentApproved(BasisDocument)
	
	Return BasisDocument.PaymentConfirmationStatus = Enums.PaymentApprovalStatuses.Approved;
	
EndFunction // DocumentApproved()

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
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.Vendor")
	 OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.ToCustomer") Then
		Object.Correspondence = Undefined;
		Object.TaxKind = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.PayrollPayment.Clear();
		Object.Division = Undefined;
		Object.BusinessActivity = Undefined;
		Object.RegistrationPeriod = Undefined;
		Object.Order = Undefined;
		Object.CashCR = Undefined;
		For Each TableRow IN Object.PaymentDetails Do
			TableRow.Order = Undefined;
			TableRow.Document = Undefined;
			TableRow.AdvanceFlag = False;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.ToAdvanceHolder") Then
		Object.Correspondence = Undefined;
		Object.Counterparty = Undefined;
		Object.TaxKind = Undefined;
		Object.Division = Undefined;
		Object.BusinessActivity = Undefined;
		Object.Order = Undefined;
		Object.RegistrationPeriod = Undefined;
		Object.CashCR = Undefined;
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
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.Salary") Then
		Object.Correspondence = Undefined;
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.Division = Undefined;
		If Not FunctionalOptionAccountingCashMethodIncomeAndExpenses Then
			Object.BusinessActivity = Undefined;
		EndIf;
		Object.Order = Undefined;
		Object.RegistrationPeriod = Undefined;
		Object.CashCR = Undefined;
		Object.PaymentDetails.Clear();
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.SalaryForEmployee") Then
		Object.Correspondence = Undefined;
		Object.Counterparty = Undefined;
		Object.Document = Undefined;
		Object.Division = Undefined;
		If Not FunctionalOptionAccountingCashMethodIncomeAndExpenses Then
			Object.BusinessActivity = Undefined;
		EndIf;
		Object.Order = Undefined;
		Object.CashCR = Undefined;
		Object.PayrollPayment.Clear();
		If Not ValueIsFilled(Object.Division) Then
			SettingValue = SmallBusinessReUse.GetValueByDefaultUser(CurrentSystemUser, "MainDivision");
			Object.Division = ?(ValueIsFilled(SettingValue), SettingValue, StructuralUnitDivision);
		EndIf;
		For Each TableRow IN Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.InvoiceForPayment = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.Other") Then
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.TaxKind = Undefined;
		Object.RegistrationPeriod = Undefined;
		Object.CashCR = Undefined;
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
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.TransferToCashCR") Then
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.TaxKind = Undefined;
		Object.Correspondence = Undefined;
		Object.Division = Undefined;
		Object.BusinessActivity = Undefined;
		Object.Order = Undefined;
		Object.RegistrationPeriod = Undefined;
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
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.Taxes") Then
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.Correspondence = Undefined;
		Object.Division = Undefined;
		If Not FunctionalOptionAccountingCashMethodIncomeAndExpenses Then
			Object.BusinessActivity = Undefined;
		EndIf;
		Object.Order = Undefined;
		Object.RegistrationPeriod = Undefined;
		Object.CashCR = Undefined;
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
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.Vendor") Then
		
		Array = New Array();
		Array.Add(Type("DocumentRef.AdditionalCosts"));
		Array.Add(Type("DocumentRef.SupplierInvoice"));
		Array.Add(Type("DocumentRef.CustomerInvoice"));
		Array.Add(Type("DocumentRef.ReportToPrincipal"));
		Array.Add(Type("DocumentRef.SubcontractorReport"));
		Array.Add(Type("DocumentRef.Netting"));
		
		ValidTypes = New TypeDescription(Array, , );
		Items.PaymentDetailsDocument.TypeRestriction = ValidTypes;
		
		ValidTypes = New TypeDescription("DocumentRef.PurchaseOrder", , );
		Items.PaymentDetailsOrder.TypeRestriction = ValidTypes;
		
		ValidTypes = New TypeDescription("DocumentRef.SupplierInvoiceForPayment", , );
		Items.PaymentDetailsInvoiceForPayment.TypeRestriction = ValidTypes;
		
		Items.PaymentDetailsDocument.Title = "Shipment document";
		Items.PaymentDetailsDocument.ToolTip = "Paid document of goods shipment, works and services by a counterparty";

	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.ToCustomer") Then
		
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
		
		ValidTypes = New TypeDescription(Array, , );
		Items.PaymentDetailsDocument.TypeRestriction = ValidTypes;
		
		ValidTypes = New TypeDescription("DocumentRef.CustomerOrder", ,);
		Items.PaymentDetailsOrder.TypeRestriction = ValidTypes;
		
		ValidTypes = New TypeDescription("DocumentRef.InvoiceForPayment", , );
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
			SettingValue = SmallBusinessReUse.GetValueByDefaultUser(CurrentSystemUser, "MainDivision");
			Object.Division = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.StructuralUnits.MainDivision);
		EndIf;
	Else
		If Object.OperationKind <> Enums.OperationKindsCashPayment.Taxes // for entering based on
		   AND Object.OperationKind <> Enums.OperationKindsCashPayment.SalaryForEmployee Then
			Object.BusinessActivity = Undefined;
		EndIf;
		If Not FunctionalOptionAccountingCashMethodIncomeAndExpenses
			AND (Object.OperationKind = Enums.OperationKindsCashPayment.Taxes
		   OR Object.OperationKind = Enums.OperationKindsCashPayment.SalaryForEmployee) Then
			Object.BusinessActivity = Undefined;
		EndIf;
		If Object.OperationKind = Enums.OperationKindsCashPayment.Other Then
			Object.Division = Undefined;
		EndIf;
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
	
	InformationCenterServer.OutputContextReferences(ThisForm, Items.InformationReferences);
	
	SmallBusinessServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues
	);
	
	If Object.PaymentDetails.Count() = 0
	   AND Object.OperationKind <> Enums.OperationKindsCashPayment.Salary Then
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
		If Not ValueIsFilled(Object.PettyCash) Then
			Object.PettyCash = Catalogs.PettyCashes.GetPettyCashByDefault(Object.Company);
			Object.CashCurrency = ?(ValueIsFilled(Object.PettyCash.CurrencyByDefault), Object.PettyCash.CurrencyByDefault, Object.CashCurrency);
		EndIf;
		If ValueIsFilled(Object.Counterparty)
		   AND Object.PaymentDetails.Count() > 0
		AND Not ValueIsFilled(Parameters.BasisDocument) Then
			If Not ValueIsFilled(Object.PaymentDetails[0].Contract) Then
				Object.PaymentDetails[0].Contract = Object.Counterparty.ContractByDefault;
			EndIf;
			If ValueIsFilled(Object.PaymentDetails[0].Contract) Then
				ContractCurrencyRateRepetition = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", Object.PaymentDetails[0].Contract.SettlementsCurrency));
				Object.PaymentDetails[0].ExchangeRate = ?(ContractCurrencyRateRepetition.ExchangeRate = 0, 1, ContractCurrencyRateRepetition.ExchangeRate);
				Object.PaymentDetails[0].Multiplicity = ?(ContractCurrencyRateRepetition.Multiplicity = 0, 1, ContractCurrencyRateRepetition.Multiplicity);
			EndIf;
		EndIf;
		SetCFItem();
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
	
	StructuralUnitDivision = Catalogs.StructuralUnits.MainDivision;
	
	SupplementOperationKindsChoiceList();
	
	If Not ValueIsFilled(Object.Ref)
	   AND Not ValueIsFilled(Parameters.Basis)
	   AND Not ValueIsFilled(Parameters.CopyingValue) Then
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
	
	PrintReceiptEnabled = False;
	
	Button = Items.Find("PrintReceipt");
	If Button <> Undefined Then
		
		If Object.OperationKind = Enums.OperationKindsCashPayment.ToCustomer
		   AND GetFunctionalOption("UsePeripherals") Then
			PrintReceiptEnabled = True;
		EndIf;
		
		Button.Enabled = PrintReceiptEnabled;
		Items.Decoration4.Visible = PrintReceiptEnabled;
		Items.ReceiptCRNumber.Visible = PrintReceiptEnabled;
		
	EndIf;
	
	FunctionalOptionAccountingCashMethodIncomeAndExpenses = Constants.FunctionalOptionAccountingCashMethodIncomeAndExpenses.Get();
	
	SetAttributesVisibleDependingOnCorrespondence();
	SetVisibleOfItemsDependsOnOperationKind();
		
	If Object.OperationKind = Enums.OperationKindsCashPayment.Taxes Then
		Items.BusinessActivityTaxes.Visible = FunctionalOptionAccountingCashMethodIncomeAndExpenses;
	EndIf;
	
	If Object.OperationKind = Enums.OperationKindsCashPayment.SalaryForEmployee Then
		Items.EmployeeSalaryPayoffBusinessActivity.Visible = FunctionalOptionAccountingCashMethodIncomeAndExpenses;
	EndIf;
	
	If Object.OperationKind = Enums.OperationKindsCashPayment.Salary Then
		Items.SalaryPayoffBusinessActivity.Visible = FunctionalOptionAccountingCashMethodIncomeAndExpenses;
	EndIf;
	
	RegistrationPeriodPresentation = Format(Object.RegistrationPeriod, "DF='MMMM yyyy'");
	
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
	
	CurrentSystemUser = UsersClientServer.CurrentUser();
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
	
	// CWP
	If TypeOf(ThisForm.FormOwner) = Type("ManagedForm")
		AND Find(ThisForm.FormOwner.FormName, "DocumentForm_CWP") > 0 
		Then
		Notify("CWP_Record_CPV", New Structure("Ref, Number, Date, OperationKind", Object.Ref, Object.Number, Object.Date, Object.OperationKind));
	EndIf;
	// End CWP
	
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
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentCashPaymentPosting");
	// StandardSubsystems.PerformanceEstimation
	
	If Modified 
		AND Object.Ref.IsEmpty() 
		AND ThereAreNodesRecipients() Then
		
		Cancel = True;
		NotifyDescription = New NotifyDescription("BeforeWriteEnd", ThisObject, New Structure("WriteParameters", WriteParameters));
		
		QuestionText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='While using the exchange you should reflect operation ""%1"" in ""Enterprise accounting""."
""
"Do you want to cancel the document record?';ru='При использовании обмена операцию ""%1"" рекомендуется отражать в ""Бухгалтерии предприятия""."
""
"Отменить запись документа?'"),
			String(OperationKind));
			
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo,, DialogReturnCode.Yes);		
		
	EndIf;
	
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

// Procedure - form event handler ChoiceProcessing
//
&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ChoiceSource) = Type("ManagedForm")
		AND Find(ChoiceSource.FormName, "CalendarForm") > 0 Then
		
		Object.RegistrationPeriod = EndOfDay(ValueSelected);
		SmallBusinessClient.OnChangeRegistrationPeriod(ThisForm);
		
	EndIf;
	
EndProcedure // ChoiceProcessing()

// Procedure - FillCheckProcessingAtServer form event handler.
//
&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - handler of the Selection button clicking.
// Opens the form of debt forming documents selection.
//
&AtClient
Procedure Pick(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(Undefined,NStr("en='Specify the counterparty first.';ru='Укажите вначале контрагента!'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.CashCurrency) Then
		ShowMessageBox(Undefined,NStr("en='Specify currency first!';ru='Укажите вначале валюту!'"));
		Return;
	EndIf;
	
	AddressPaymentDetailsInStorage = PlacePaymentDetailsToStorage();
	
	SelectionParameters = New Structure(
		"AddressPaymentDetailsInStorage,
		|Company,
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

// Procedure - handler of clicking the button "Fill in by basis".
//
&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		ShowMessageBox(Undefined,NStr("en='Basis document is not selected!';ru='Не выбран документ основание!'"));
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
		
		Object.PaymentDetails.Clear();
		Object.PayrollPayment.Clear();
		
		FillByDocument(Object.BasisDocument);
		
		If Object.PaymentDetails.Count() = 0
			AND Object.OperationKind <> PredefinedValue("Enum.OperationKindsCashPayment.Salary") Then
			Object.PaymentDetails.Add();
			Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		EndIf;
		
		OperationKind = Object.OperationKind;
		CashCurrency = Object.CashCurrency;
		DocumentDate = Object.Date;
		
		SetCurrentPage();
		SetChoiceParameterLinksAvailableTypes();
		OperationKindOnChangeAtServer(False);
		
	EndIf;

EndProcedure // FillByBasis()

// Procedure is called while clicking the "Print receipt" button of the command bar.
&AtClient
Procedure PrintReceipt(Command)
	
	If Object.ReceiptCRNumber <> 0 Then
		MessageText = NStr("en='Check has already been issued on the fiscal record!';ru='Чек уже пробит на фискальном регистраторе!'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	ShowMessageBox = False;
	If SmallBusinessClient.CheckPossibilityOfReceiptPrinting(ThisForm, ShowMessageBox) Then
	
		If EquipmentManagerClient.RefreshClientWorkplace() Then
			
			NotifyDescription = New NotifyDescription("EnableFiscalRegistrarEnd", ThisObject);
			EquipmentManagerClient.OfferSelectDevice(NOTifyDescription, "FiscalRegister",
					NStr("en='Select the fiscal register';ru='Выберите фискальный регистратор'"), NStr("en='Fiscal register is not connected.';ru='Фискальный регистратор не подключен.'"));
			
		Else
			
			MessageText = NStr("en='First, you need to select the workplace of the current session peripherals.';ru='Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.'");
			
			CommonUseClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	ElsIf ShowMessageBox Then
		ShowMessageBox(Undefined,NStr("en='Failed to post the document';ru='Не удалось выполнить проведение документа'"));
	EndIf;
	
EndProcedure // PrintReceiptExecute()

&AtClient
Procedure EnableFiscalRegistrarEnd(DeviceIdentifier, Parameters) Export
	
	ErrorDescription = "";
	
	If DeviceIdentifier <> Undefined Then
		
		// Enable FR.
		Result = EquipmentManagerClient.ConnectEquipmentByID(
			UUID,
			DeviceIdentifier,
			ErrorDescription
		);
		
		If Result Then
			
			//Prepare data.
			InputParameters  = New Array();
			Output_Parameters = Undefined;
			SectionNumber = 2;
			
			// Prepare goods table.
			ProductsTable = New Array();
			
			ProductsTableRow = New ValueList();
			ProductsTableRow.Add(NStr("en='Issue:';ru='Выдать:'") + " " + Object.Issue + Chars.LF
			+ NStr("en='Basis:';ru='Основание:'") + " " + Object.Basis); //  1 - Description
			ProductsTableRow.Add("");					 //  2 - Barcode
			ProductsTableRow.Add("");					 //  3 - SKU
			ProductsTableRow.Add(SectionNumber);			//  4 - Department number
			ProductsTableRow.Add(Object.DocumentAmount);  //  5 - Price for position without discount
			ProductsTableRow.Add(1);					  //  6 - Quantity
			ProductsTableRow.Add("");					 //  7 - Discount/markup description
			ProductsTableRow.Add(0);					  //  8 - Amount of a discount/markup
			ProductsTableRow.Add(0);					  //  9 - Discount/markup percent
			ProductsTableRow.Add(Object.DocumentAmount);  // 10 - Position amount with discount
			ProductsTableRow.Add(0);					  // 11 - Tax number (1)
			ProductsTableRow.Add(0);					  // 12 - Tax amount (1)
			ProductsTableRow.Add(0);					  // 13 - Tax percent (1)
			ProductsTableRow.Add(0);					  // 14 - Tax number (2)
			ProductsTableRow.Add(0);					  // 15 - Tax amount (2)
			ProductsTableRow.Add(0);					  // 16 - Tax percent (2)
			ProductsTableRow.Add("");					 // 17 - Section name of commodity string formatting
			
			ProductsTable.Add(ProductsTableRow);
			
			// Prepare the payments table.
			PaymentsTable = New Array();
			
			PaymentRow = New ValueList();
			PaymentRow.Add(0);
			PaymentRow.Add(Object.DocumentAmount);
			PaymentRow.Add("");
			PaymentRow.Add("");
			
			PaymentsTable.Add(PaymentRow);
			
			// Prepare the general parameters table.
			CommonParameters = New Array();
			CommonParameters.Add(1);					  //  1 - Receipt type
			CommonParameters.Add(True);				 //  2 - Fiscal receipt sign
			CommonParameters.Add(Undefined);		   //  3 - Print on lining document
			CommonParameters.Add(Object.DocumentAmount);  //  4 - Amount by receipt without discounts/markups
			CommonParameters.Add(Object.DocumentAmount);  //  5 - Amount by receipt with accounting all discounts/markups
			CommonParameters.Add("");					 //  6 - Discount card number
			CommonParameters.Add("");					 //  7 - Header text
			CommonParameters.Add("");					 //  8 - Footer text
			CommonParameters.Add(0);					  //  9 - Session number (for receipt copy)
			CommonParameters.Add(0);					  // 10 - Receipt number (for receipt copy)
			CommonParameters.Add(0);					  // 11 - Document No (for receipt copy)
			CommonParameters.Add(0);					  // 12 - Document date (for receipt copy)
			CommonParameters.Add("");					 // 13 - Cashier name (for receipt copy)
			CommonParameters.Add("");					 // 14 - Cashier password
			CommonParameters.Add(0);					  // 15 - Template number
			CommonParameters.Add("");					 // 16 - Section name header format
			CommonParameters.Add("");					 // 17 - Section name cellar format
			
			InputParameters.Add(ProductsTable);
			InputParameters.Add(PaymentsTable);
			InputParameters.Add(CommonParameters);
			
			// Print receipt.
			Result = EquipmentManagerClient.RunCommand(
				DeviceIdentifier,
				"PrintReceipt",
				InputParameters,
				Output_Parameters
			);
			
			If Result Then
				
				// Set the received value of receipt number to document attribute.
				Object.ReceiptCRNumber = Output_Parameters[1];
				Modified  = True;
				Write(New Structure("WriteMode", DocumentWriteMode.Posting));
				
			Else
				
				MessageText = NStr("en='When printing a receipt, an error occurred."
"Receipt is not printed on the fiscal register."
"Additional"
"description: %AdditionalDetails%';ru='При печати чека произошла ошибка."
"Чек не напечатан на фискальном регистраторе."
"Дополнительное"
"описание: %ДополнительноеОписание%'"
				);
				MessageText = StrReplace(
					MessageText,
					"%AdditionalDetails%",
					Output_Parameters[1]
				);
				CommonUseClientServer.MessageToUser(MessageText);
				
			EndIf;
			
			// Disable FR.
			EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
			
		Else
			
			MessageText = NStr("en='An error occurred when connecting the device."
"Receipt is not printed on the fiscal register."
"Additional"
"description: %AdditionalDetails%';ru='При подключении устройства произошла ошибка."
"Чек не напечатан на фискальном регистраторе."
"Дополнительное"
"описание: %ДополнительноеОписание%'"
			);
			MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
			CommonUseClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	EndIf;

EndProcedure

// Procedure - FillDetails command handler.
//
&AtClient
Procedure FillDetails(Command)
	
	If Object.DocumentAmount = 0 Then
		ShowMessageBox(Undefined,NStr("en='Specify amount of document first.';ru='Укажите вначале сумму документа.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.CashCurrency) Then
		ShowMessageBox(Undefined,NStr("en='Specify currency first!';ru='Укажите вначале валюту!'"));
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
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.Vendor") Then
		
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
	
	If Not ValueIsFilled(Object.Issue) Then
		Object.Issue = StructureData.CounterpartyDescriptionFull;
	EndIf;
	
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
		MessageText = NStr("en='Petty cash currency exchange rate has changed. Recalculate the document amount?';ru='Изменился курс валюты кассы. Пересчитать суммы документа?'");
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
	
EndProcedure // CompanyOnChange()

// Procedure - OnChange event handler of
// Currency edit box Recalculates the PaymentDetails tabular section.
//
&AtClient
Procedure CashAssetsCurrencyOnChange(Item)
	
	CurrencyCashBeforeChanging = CashCurrency;
	CashCurrency = Object.CashCurrency;
	
	// If currency is not changed, do nothing.
	If CashCurrency = CurrencyCashBeforeChanging Then
		Return;
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.Salary") Then
		MessageText = NStr("en='Petty cash currency has changed. The ""Payroll sheets"" list will be cleared.';ru='Изменилась валюта кассы. Список ""Платежные ведомости"" будет очищен.'");
		ShowMessageBox(New NotifyDescription("CashAssetsCurrencyOnChangeEnd", ThisObject, New Structure("MessageText", MessageText)), MessageText);
		Return;
	EndIf;
	
	CashAssetsCurrencyOnChangeFragment();
EndProcedure

&AtClient
Procedure CashAssetsCurrencyOnChangeEnd(AdditionalParameters) Export
	
	MessageText = AdditionalParameters.MessageText;
	
	
	Object.PayrollPayment.Clear();
	
	CashAssetsCurrencyOnChangeFragment();

EndProcedure

&AtClient
Procedure CashAssetsCurrencyOnChangeFragment()
	
	Var StructureData, MessageText;
	
	StructureData = GetDataCashAssetsCurrencyOnChange(
	Object.Date,
	Object.CashCurrency
	);
	
	MessageText = NStr("en='Recalculate the document amount?';ru='Пересчитать суммы документа?'");
	RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData, MessageText);

EndProcedure // CashAssetsCurrencyOnChange()

// Procedure - OnChange event handler of AdvanceHandler input field.
// Clears the AdvanceHolderPayments document.
//
&AtClient
Procedure AdvanceHolderOnChange(Item)
	
	StructureData = GetDataAdvanceHolderOnChange(Object.AdvanceHolder, Object.Date);
	Object.Issue = StructureData.AdvanceHolderDescription;
	Object.ByDocument =
		String(StructureData.DocumentKind1)
	  + " Series "
	  + StructureData.DocumentSeries
	  + ", number "
	  + StructureData.DocumentNumber
	  + ", issued "
	  + Format(StructureData.DocumentIssueDate, "DF=dd.MM.yyyy")
	  + " "
	  + StructureData.DocumentWhoIssued;
	
EndProcedure // AdvanceHolderOnChange()

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

// Procedure - OnChange event handler of PettyCash input field.
//
&AtClient
Procedure PettyCashOnChange(Item)
	
	Object.CashCurrency = ?(
		ValueIsFilled(Object.CashCurrency),
		Object.CashCurrency,
		GetPettyCashAccountingCurrencyAtServer(Object.PettyCash)
	);
	
EndProcedure // PettyCashOnChange()

&AtClient
Procedure Attachable_ClickOnInformationLink(Item)
	
	InformationCenterClient.ClickOnInformationLink(ThisForm, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ReferenceClickAllInformationLinks(Item)
	
	InformationCenterClient.ReferenceClickAllInformationLinks(ThisForm.FormName);
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABULAR SECTION ATTRIBUTE EVENT HANDLERS

// Procedure - BeforeDeletion event handler of PaymentDetails tabular section.
//
&AtClient
Procedure PaymentDetailsBeforeDelete(Item, Cancel)
	
	If Object.PaymentDetails.Count() = 1 Then
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
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.Vendor") Then
		If TabularSectionRow.AdvanceFlag Then
			TabularSectionRow.Document = Undefined;
		Else
			TabularSectionRow.PlanningDocument = Undefined;
		EndIf;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.ToCustomer") Then
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
		AND Object.OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.Vendor") Then
		
		Mode = QuestionDialogMode.OK;
		ShowMessageBox(, NStr("en='The current document with the ""Advance"" flag will be used for settlement!';ru='Для вида расчета с признаком ""Аванс"" документом расчетов будет текущий!'"));
		
	Else
		
		ThisIsAccountsReceivable = Object.OperationKind = PredefinedValue("Enum.OperationKindsCashPayment.ToCustomer");
		
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

// Procedure - event handler Management of attribute RegistrationPeriod.
//
&AtClient
Procedure RegistrationPeriodTuning(Item, Direction, StandardProcessing)
	
	SmallBusinessClient.OnRegistrationPeriodRegulation(ThisForm, Direction);
	SmallBusinessClient.OnChangeRegistrationPeriod(ThisForm);
	
EndProcedure //RegistrationPeriodTuning()

// Procedure - event handler StartChoice of attribute RegistrationPeriod.
//
&AtClient
Procedure RegistrationPeriodStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing	 = False;
	
	CalendarDateOnOpen = ?(ValueIsFilled(Object.RegistrationPeriod), Object.RegistrationPeriod, SmallBusinessReUse.GetSessionCurrentDate());
	
	OpenForm("CommonForm.CalendarForm", SmallBusinessClient.GetCalendarGenerateFormOpeningParameters(CalendarDateOnOpen), ThisForm);
	
EndProcedure //RegistrationPeriodStartChoice()

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
