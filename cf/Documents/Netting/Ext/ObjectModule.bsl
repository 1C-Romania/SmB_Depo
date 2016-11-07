#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF DOCUMENT FILLING

//Procedure of document filling based on the settlement reconciliation
//
Procedure FillBySettlementsReconciliation(DocumentSettlementsReconciliation)
	
	ThisObject.BasisDocument 	= DocumentSettlementsReconciliation;
	ThisObject.Company			= DocumentSettlementsReconciliation.Company;
	For Each CounterpartyContractString IN DocumentSettlementsReconciliation.CounterpartyContracts Do
		
		If CounterpartyContractString.Select Then
			
			CounterpartyContract = CounterpartyContractString.Contract;
			Break;
			
		EndIf;
		
	EndDo;
	
	If ValueIsFilled(CounterpartyContract) Then
		
		If CounterpartyContract.ContractKind = Enums.ContractKinds.WithCustomer 
			OR CounterpartyContract.ContractKind = Enums.ContractKinds.WithAgent Then
			
			ThisObject.OperationKind			= Enums.OperationKindsNetting.CustomerDebtAdjustment;
			ThisObject.CounterpartySource	= DocumentSettlementsReconciliation.Counterparty;
			
		ElsIf CounterpartyContract.ContractKind = Enums.ContractKinds.WithVendor 
			OR CounterpartyContract.ContractKind = Enums.ContractKinds.FromPrincipal Then
			
			ThisObject.OperationKind			= Enums.OperationKindsNetting.VendorDebtAdjustment;
			ThisObject.Counterparty			= DocumentSettlementsReconciliation.Counterparty;
			
		EndIf;
		
		BalanceByCompanyData	= DocumentSettlementsReconciliation.CompanyData.Total("ClientDebtAmount") - DocumentSettlementsReconciliation.CompanyData.Total("CompanyDebtAmount");
		BalanceByCounterpartyData	= DocumentSettlementsReconciliation.CounterpartyData.Total("CompanyDebtAmount") - DocumentSettlementsReconciliation.CounterpartyData.Total("ClientDebtAmount");
		Discrepancy					= BalanceByCompanyData - BalanceByCounterpartyData;
		
		Correspondence = ?(Discrepancy < 0, ChartsOfAccounts.Managerial.OtherIncome, ChartsOfAccounts.Managerial.OtherExpenses);
		
	EndIf;
	
EndProcedure //FillBySettlementsReconciliation()

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(AccountsDocument) Then
		AccountsDocument = Undefined;
	EndIf;
	
	For Each CurRow IN Debitor Do
		If Not ValueIsFilled(CurRow.Document) Then
			CurRow.Document = Undefined;
		EndIf;
	EndDo;
	
	For Each CurRow IN Creditor Do
		If Not ValueIsFilled(CurRow.Document) Then
			CurRow.Document = Undefined;
		EndIf;
	EndDo;
	
	If Not ValueIsFilled(Order) Then
		If OperationKind = Enums.OperationKindsNetting.CustomerDebtAssignment Then
			Order = Documents.CustomerOrder.EmptyRef();
		ElsIf OperationKind = Enums.OperationKindsNetting.DebtAssignmentToVendor Then
			Order = Documents.PurchaseOrder.EmptyRef();
		EndIf;
	EndIf;
	
EndProcedure // BeforeWrite()

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If OperationKind = Enums.OperationKindsNetting.Netting Then
		
		DebitorSumOfAccounting = Debitor.Total("AccountingAmount");
		CreditorAccountingSum = Creditor.Total("AccountingAmount");
		
		If DebitorSumOfAccounting <> CreditorAccountingSum Then
			MessageText = NStr("en='Account amount of the tabular section ""Accounts receivable"" is not equal to account amount in the tabular section ""Accounts payable""!';ru='Сумма учета табличной части ""Расчеты с покупателем"", не равна сумме учета по табличной части ""Расчеты с поставщиком""!'");
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Debitor",
				1,
				"AccountingAmount",
				Cancel
			);
		EndIf;
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "SettlementsAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		
		If Not CounterpartySource.DoOperationsByContracts Then
			SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.Contract");
			For Each TSRow IN Debitor Do
				TSRow.Contract = CounterpartySource.ContractByDefault;
			EndDo;
		EndIf;
		
		If Not CounterpartySource.DoOperationsByDocuments Then
			SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.Document");
		EndIf;
		
		If Not Counterparty.DoOperationsByContracts Then
			SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.Contract");
			For Each TSRow IN Creditor Do
				TSRow.Contract = Counterparty.ContractByDefault;
			EndDo;
		EndIf;
		
		If Not Counterparty.DoOperationsByDocuments Then
			SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.Document");
		EndIf;
		
	ElsIf OperationKind = Enums.OperationKindsNetting.CustomerDebtAssignment Then
		
		DebitorSumOfAccounting = Debitor.Total("AccountingAmount");
		MessageText = NStr("en='Account amount is not equal to amount in the tabular section ""Accounts receivable""!';ru='Сумма учета, не равна сумме учета табличной части ""Расчеты с покупателем""!'");
		
		If DebitorSumOfAccounting <> AccountingAmount Then
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				Undefined,
				1,
				"AccountingAmount",
				Cancel
			);
		EndIf;
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		
		If Not CounterpartySource.DoOperationsByContracts Then
			SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.Contract");
			For Each TSRow IN Debitor Do
				TSRow.Contract = CounterpartySource.ContractByDefault;
			EndDo;
		EndIf;
		
		If Not CounterpartySource.DoOperationsByDocuments Then
			SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.Document");
		EndIf;
		
		If Not Counterparty.DoOperationsByContracts Then
			SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
			Contract = Counterparty.ContractByDefault;
		EndIf;
		
		If Not Counterparty.DoOperationsByDocuments Then
			SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		EndIf;

	ElsIf OperationKind = Enums.OperationKindsNetting.DebtAssignmentToVendor Then
		
		CreditorAccountingSum = Creditor.Total("AccountingAmount");
		
		If CreditorAccountingSum <> AccountingAmount Then
			MessageText = NStr("en='Account amount is not equal to amount in the tabular section ""Accounts payable""!';ru='Сумма учета, не равна сумме учета табличной части ""Расчеты с поставщиком""!'");
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				Undefined,
				1,
				"AccountingAmount",
				Cancel
			);
		EndIf;
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		
		If Not CounterpartySource.DoOperationsByContracts Then
			SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.Contract");
			For Each TSRow IN Creditor Do
				TSRow.Contract = CounterpartySource.ContractByDefault;
			EndDo;
		EndIf;
		
		If Not CounterpartySource.DoOperationsByDocuments Then
			SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.Document");
		EndIf;
		
		If Not Counterparty.DoOperationsByContracts Then
			SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
			Contract = Counterparty.ContractByDefault;
		EndIf;
		
		If Not Counterparty.DoOperationsByDocuments Then
			SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		EndIf;
		
	ElsIf OperationKind = Enums.OperationKindsNetting.CustomerDebtAdjustment Then
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "SettlementsAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		
		If Not CounterpartySource.DoOperationsByContracts Then
			SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.Contract");
			For Each TSRow IN Debitor Do
				TSRow.Contract = CounterpartySource.ContractByDefault;
			EndDo;
		EndIf;
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.Document");
		
	ElsIf OperationKind = Enums.OperationKindsNetting.VendorDebtAdjustment Then
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "CounterpartySource");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "SettlementsAmount");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		
		If Not Counterparty.DoOperationsByContracts Then
			SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.Contract");
			For Each TSRow IN Creditor Do
				TSRow.Contract = Counterparty.ContractByDefault;
			EndDo;
		EndIf;
			
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.Document");
		
	EndIf
	
EndProcedure // FillCheckProcessing()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.Netting.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	SmallBusinessServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesUndistributed(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.Netting.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure // Posting()

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo the posting of a document.
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record of the records sets.
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.Netting.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure // UndoPosting()

//Procedure - handler of item event Filling
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.SettlementsReconciliation") Then
		
		FillBySettlementsReconciliation(FillingData);
		
	EndIf;
	
EndProcedure

#EndIf