#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF FILLING THE DOCUMENT

// Procedure of the document filling based on the customer invoice.
//
// Parameters:
// BasisDocument - DocumentRef.CustomerInvoice - customer invoice 
// FillingData - Structure - Document filling data
//	
Procedure FillByInventoryReconciliation(FillingData)
	
	// Filling out a document header.
	BasisDocument = FillingData.Ref;
	Company = FillingData.Company;
	AccountingSection = "Inventory";
	
	// Filling document tabular section.
	For Each TabularSectionRow IN FillingData.Inventory Do
		
		If TabularSectionRow.Quantity > 0 Then
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, TabularSectionRow);
			NewRow.StructuralUnit = FillingData.StructuralUnit;
			NewRow.Cell = FillingData.Cell;
		EndIf;	
		
	EndDo;
		
EndProcedure // FillByInventoryReconciliation()

// Procedure gets the default VAT rate.
//
Function GetVATRateDefault(VATTaxation)
	
	If VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		DefaultVATRate = Company.DefaultVATRate;
	ElsIf VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then
		DefaultVATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
	Else
		DefaultVATRate = SmallBusinessReUse.GetVATRateZero();
	EndIf;
	
	Return DefaultVATRate;
	
EndFunction // GetDefaultVATRate()

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Constants.FunctionalOptionAccountingByMultipleBusinessActivities.Get() Then
		
		For Each RowFixedAssets in FixedAssets Do
			
			If RowFixedAssets.GLExpenseAccount.TypeOfAccount = Enums.GLAccountsTypes.Expenses Then
				
				RowFixedAssets.BusinessActivity = Catalogs.BusinessActivities.MainActivity;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	For Each TSRow IN AccountsReceivable Do
		If ValueIsFilled(TSRow.Counterparty)
		AND Not TSRow.Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(TSRow.Contract) Then
			TSRow.Contract = TSRow.Counterparty.ContractByDefault;
		EndIf;
	EndDo;
	
	For Each TSRow IN AccountsPayable Do
		If ValueIsFilled(TSRow.Counterparty)
		AND Not TSRow.Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(TSRow.Contract) Then
			TSRow.Contract = TSRow.Counterparty.ContractByDefault;
		EndIf;
	EndDo;
	
	For Each TSRow IN InventoryTransferred Do
		If ValueIsFilled(TSRow.Counterparty)
		AND Not TSRow.Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(TSRow.Contract) Then
			TSRow.Contract = TSRow.Counterparty.ContractByDefault;
		EndIf;
	EndDo;
	
	For Each TSRow IN InventoryReceived Do
		If ValueIsFilled(TSRow.Counterparty)
		AND Not TSRow.Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(TSRow.Contract) Then
			TSRow.Contract = TSRow.Counterparty.ContractByDefault;
		EndIf;
	EndDo;
	
EndProcedure // BeforeWrite()

// Procedure - event handler OnWrite.
// Documents are generated during autofilling.
//
Procedure OnWrite(Cancel)
	
	If DataExchange.Load
  OR Not Autogeneration Then
		Return;
	EndIf;
	
	WereMadeChanges = False;
	
	// Generating the documents for the AccountsReceivable tabular section.
	For Each String IN AccountsReceivable Do
		If Not ValueIsFilled(String.Document)
			  AND String.Counterparty.DoOperationsByDocuments Then
			If String.AdvanceFlag Then
				NewDocument = Documents.CashReceipt.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCashReceipt.FromCustomer;
				NewDocument.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
				NewDocument.PettyCash = Company.PettyCashByDefault;
				NewDocument.CashCurrency = String.Contract.SettlementsCurrency;
				NewDocument.DocumentAmount = String.AmountCur;
				NewDocument.VATTaxation = SmallBusinessServer.VATTaxation(
					NewDocument.Company, , Date);
				NewRow = NewDocument.PaymentDetails.Add();
				NewRow.Contract = String.Contract;
				ContractCurrencyRateRepetition = InformationRegisters.CurrencyRates.GetLast(
					Date,
					New Structure("Currency", NewRow.Contract.SettlementsCurrency)
				);
				DocumentCurrencyCourseRepetition = InformationRegisters.CurrencyRates.GetLast(
					Date,
					New Structure("Currency", NewDocument.CashCurrency)
				);
				NewRow.ExchangeRate = ?(
					ContractCurrencyRateRepetition.ExchangeRate = 0,
					1,
					ContractCurrencyRateRepetition.ExchangeRate
				);
				NewRow.Multiplicity = ?(
					ContractCurrencyRateRepetition.Multiplicity = 0,
					1,
					ContractCurrencyRateRepetition.Multiplicity
				);
				NewRow.AdvanceFlag = True;
				NewRow.PaymentAmount = NewDocument.DocumentAmount;
				NewRow.SettlementsAmount = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
					NewRow.PaymentAmount,
					DocumentCurrencyCourseRepetition.ExchangeRate,
					NewRow.ExchangeRate,
					DocumentCurrencyCourseRepetition.Multiplicity,
					NewRow.Multiplicity
				);
				NewRow.VATRate = GetVATRateDefault(NewDocument.VATTaxation);
				NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((NewRow.VATRate.Rate + 100) / 100);
			Else
				NewDocument = Documents.CustomerInvoice.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCustomerInvoice.SaleToCustomer;
				NewDocument.VATTaxation = SmallBusinessServer.VATTaxation(
					NewDocument.Company, , Date);
				If ValueIsFilled(String.Contract) Then
					NewDocument.Contract = String.Contract;
				Else
					NewDocument.Contract = String.Counterparty.ContractByDefault;
				EndIf;
				NewDocument.DocumentCurrency = NewDocument.Contract.SettlementsCurrency;
				DocumentCurrencyCourseRepetition = InformationRegisters.CurrencyRates.GetLast(
					Date,
					New Structure("Currency", NewDocument.DocumentCurrency)
				);
				NewDocument.ExchangeRate = ?(
					DocumentCurrencyCourseRepetition.ExchangeRate = 0,
					1,
					DocumentCurrencyCourseRepetition.ExchangeRate
				);
				NewDocument.Multiplicity = ?(
					DocumentCurrencyCourseRepetition.Multiplicity = 0,
					1,
					DocumentCurrencyCourseRepetition.Multiplicity
				);
				NewDocument.StructuralUnit = Catalogs.StructuralUnits.MainWarehouse;
			EndIf;
			NewDocument.Date = Date;
			NewDocument.Company = Company;
			NewDocument.Counterparty = String.Counterparty;
			
			StringComment = NStr("en='It is generated automatically by the ""Entering the opening balances"" document No.%Number% from %Date%'");
			StringComment = StrReplace(StringComment, "%Number%", String(Number));
			StringComment = StrReplace(StringComment, "%Date%", String(Date));
			NewDocument.Comment = StringComment;
			
			NewDocument.Write();
			
			String.Document = NewDocument.Ref;
			WereMadeChanges = True;
		EndIf;
	EndDo;
	
	// Generating the documents for the AccountsPayable tabular section.
	For Each String IN AccountsPayable Do
		If Not ValueIsFilled(String.Document)
			  AND String.Counterparty.DoOperationsByDocuments Then
			If String.AdvanceFlag Then
				NewDocument = Documents.CashPayment.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCashPayment.Vendor;
				NewDocument.Item = Catalogs.CashFlowItems.PaymentToVendor;
				NewDocument.PettyCash = Company.PettyCashByDefault;
				NewDocument.CashCurrency = String.Contract.SettlementsCurrency;
				NewDocument.DocumentAmount = String.AmountCur;
				NewDocument.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT;
				NewRow = NewDocument.PaymentDetails.Add();
				NewRow.Contract = String.Contract;
				ContractCurrencyRateRepetition = InformationRegisters.CurrencyRates.GetLast(
					Date,
					New Structure("Currency", NewRow.Contract.SettlementsCurrency)
				);
				DocumentCurrencyCourseRepetition = InformationRegisters.CurrencyRates.GetLast(
					Date,
					New Structure("Currency", NewDocument.CashCurrency)
				);
				NewRow.ExchangeRate = ?(
					ContractCurrencyRateRepetition.ExchangeRate = 0,
					1,
					ContractCurrencyRateRepetition.ExchangeRate
				);
				NewRow.Multiplicity = ?(
					ContractCurrencyRateRepetition.Multiplicity = 0,
					1,
					ContractCurrencyRateRepetition.Multiplicity
				);
				NewRow.PaymentAmount = NewDocument.DocumentAmount;
				NewRow.AdvanceFlag = True;
				NewRow.SettlementsAmount = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
					NewRow.PaymentAmount,
					DocumentCurrencyCourseRepetition.ExchangeRate,
					NewRow.ExchangeRate,
					DocumentCurrencyCourseRepetition.Multiplicity,
					NewRow.Multiplicity
				);
				NewRow.VATRate = GetVATRateDefault(NewDocument.VATTaxation);
				NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((NewRow.VATRate.Rate + 100) / 100);
			Else
				NewDocument = Documents.SupplierInvoice.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsSupplierInvoice.ReceiptFromVendor;
				NewDocument.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT;
				If ValueIsFilled(String.Contract) Then
					NewDocument.Contract = String.Contract;
				Else
					NewDocument.Contract = String.Counterparty.ContractByDefault;
				EndIf;
				NewDocument.DocumentCurrency = NewDocument.Contract.SettlementsCurrency;
				DocumentCurrencyCourseRepetition = InformationRegisters.CurrencyRates.GetLast(
					Date,
					New Structure("Currency", NewDocument.DocumentCurrency)
				);
				NewDocument.ExchangeRate = ?(
					DocumentCurrencyCourseRepetition.ExchangeRate = 0,
					1,
					DocumentCurrencyCourseRepetition.ExchangeRate
				);
				NewDocument.Multiplicity = ?(
					DocumentCurrencyCourseRepetition.Multiplicity = 0,
					1,
					DocumentCurrencyCourseRepetition.Multiplicity
				);
				NewDocument.StructuralUnit = Catalogs.StructuralUnits.MainWarehouse;
			EndIf;
			NewDocument.Date = Date;
			NewDocument.Company = Company;
			NewDocument.Counterparty = String.Counterparty;
			
			StringComment = NStr("en='It is generated automatically by the ""Entering the opening balances"" document No.%Number% from %Date%'");
			StringComment = StrReplace(StringComment, "%Number%", String(Number));
			StringComment = StrReplace(StringComment, "%Date%", String(Date));
			NewDocument.Comment = StringComment;
			
			NewDocument.Write();
			
			String.Document = NewDocument.Ref;
			WereMadeChanges = True;
		EndIf;
	EndDo;
	
	// Generating the documents for the AdvanceHolderPayments tabular section.
	For Each String IN AdvanceHolderPayments Do
		If Not ValueIsFilled(String.Document) Then
			If String.Overrun Then
				NewDocument = Documents.ExpenseReport.CreateDocument();
				NewDocument.Employee = String.Employee;
				NewDocument.DocumentCurrency = String.Currency;
			Else
				NewDocument = Documents.CashPayment.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCashPayment.ToAdvanceHolder;
				NewDocument.Item = Catalogs.CashFlowItems.PaymentToVendor;
				NewDocument.PettyCash = Company.PettyCashByDefault;
				NewDocument.AdvanceHolder = String.Employee;
				NewDocument.CashCurrency = String.Currency;
				NewDocument.DocumentAmount = String.AmountCur;
			EndIf;
			NewDocument.Date = Date;
			NewDocument.Company = Company;
			
			StringComment = NStr("en='It is generated automatically by the ""Entering the opening balances"" document No.%Number% from %Date%'");
			StringComment = StrReplace(StringComment, "%Number%", String(Number));
			StringComment = StrReplace(StringComment, "%Date%", String(Date));
			NewDocument.Comment = StringComment;
			
			NewDocument.Write();
			
			String.Document = NewDocument.Ref;
			WereMadeChanges = True;
		EndIf;
	EndDo;
		
	If WereMadeChanges Then
		Write();
	EndIf;
	
EndProcedure // OnRecord()

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Autogeneration Then
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolderPayments.Document");
	EndIf;
	
	For Each TSRow IN OtherSections Do
		If TSRow.Account.Currency
		AND Not ValueIsFilled(TSRow.Currency) Then
			MessageText = NStr("en = 'The ""Currency"" column is not filled for currency account in row No.%LineNumber% of the ""Other sections"" list.'");
			MessageText = StrReplace(MessageText, "%LineNumber%", String(TSRow.LineNumber));
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"OtherSections",
				TSRow.LineNumber,
				"Currency",
				Cancel
			);
		EndIf;
		If TSRow.Account.Currency
		AND Not ValueIsFilled(TSRow.AmountCur) Then
			MessageText = NStr("en = 'Column ""Amount"" is not filled (cur.)"" for currency account in row No.%LineNumber% of the ""Other sections"" list.'");
			MessageText = StrReplace(MessageText, "%LineNumber%", String(TSRow.LineNumber));
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"OtherSections",
				TSRow.LineNumber,
				"AmountCur",
				Cancel
			);
		EndIf;
	EndDo;
	
	For Each TSRow IN AccountsReceivable Do
		If TSRow.Counterparty.DoOperationsByDocuments
		AND Not Autogeneration
		AND Not ValueIsFilled(TSRow.Document) Then
			MessageText = NStr("en = 'The ""Calculation"" column is not filled in row No.%LineNumber% of the ""Accounts receivable"" list.'");
			MessageText = StrReplace(MessageText, "%LineNumber%", String(TSRow.LineNumber));
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Payments",
				TSRow.LineNumber,
				"Document",
				Cancel
			);
		EndIf;
	EndDo;
	
	For Each TSRow IN AccountsPayable Do
		If TSRow.Counterparty.DoOperationsByDocuments
		AND Not Autogeneration
		AND Not ValueIsFilled(TSRow.Document) Then
			MessageText = NStr("en = 'The ""Calculation"" column is not filled in row No.%LineNumber% of the ""Accounts receivable"" list.'");
			MessageText = StrReplace(MessageText, "%LineNumber%", String(TSRow.LineNumber));
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Payments",
				TSRow.LineNumber,
				"Document",
				Cancel
			);
		EndIf;
	EndDo;
	
EndProcedure // FillCheckProcessing()

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.InventoryReconciliation") Then
		FillByInventoryReconciliation(FillingData);	
	ElsIf TypeOf(FillingData) = Type("Structure") Then
		FillPropertyValues(ThisObject, FillingData);
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.EnterOpeningBalance.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	If AdditionalProperties.TableForRegisterRecords.Property("TableInventoryInWarehouses") Then
		SmallBusinessServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableInventory") Then
		SmallBusinessServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableInventoryTransferred") Then
		SmallBusinessServer.ReflectInventoryTransferred(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableInventoryReceived") Then
		SmallBusinessServer.ReflectInventoryAccepted(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableInventoryByCCD") Then
		SmallBusinessServer.ReflectInventoryByCCD(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableCashAssets") Then
		SmallBusinessServer.ReflectCashAssets(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableAccountsReceivable") Then
		SmallBusinessServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
		SmallBusinessServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
		SmallBusinessServer.ReflectIncomeAndExpensesUndistributed(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableAccountsPayable") Then
		SmallBusinessServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
		SmallBusinessServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
		SmallBusinessServer.ReflectIncomeAndExpensesUndistributed(AdditionalProperties, RegisterRecords, Cancel);
		SmallBusinessServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableTaxAccounting") Then
		SmallBusinessServer.ReflectTaxesSettlements(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TablePayrollPayments") Then
		SmallBusinessServer.ReflectPayrollPayments(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableSettlementsWithAdvanceHolders") Then
		SmallBusinessServer.ReflectAdvanceHolderPayments(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableFixedAssetsStates") Then
		SmallBusinessServer.ReflectFixedAssetStatuses(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableFixedAssetsParameters") Then
		SmallBusinessServer.ReflectFixedAssetsParameters(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableFixedAssets") Then
		SmallBusinessServer.ReflectFixedAssets(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableFixedAssetsOutput") Then
		SmallBusinessServer.ReflectFixedAssetsOutput(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableInvoicesAndOrdersPayment") Then
		SmallBusinessServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
 
	If AdditionalProperties.TableForRegisterRecords.Property("TableManagerial") Then
		SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;

	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);

	// Control
	Documents.EnterOpeningBalance.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);

	// Control
	Documents.EnterOpeningBalance.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

#EndIf