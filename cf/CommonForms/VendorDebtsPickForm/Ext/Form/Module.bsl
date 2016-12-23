// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Period = Parameters.Date;
	SubsidiaryCompany = Parameters.SubsidiaryCompany;
	Counterparty = Parameters.Counterparty;
	CashCurrency = Parameters.CashCurrency;
	Ref = Parameters.Ref;
	OperationKind = Parameters.OperationKind;
	DocumentAmount = Parameters.DocumentAmount;
	
	Items.FilteredDebtsContract.Visible = Counterparty.DoOperationsByContracts;
	Items.FilteredDebtsDocument.Visible = Counterparty.DoOperationsByDocuments;
	Items.FilteredDebtsOrder.Visible = Counterparty.DoOperationsByOrders;
	
	Items.DebtsListContract.Visible = Counterparty.DoOperationsByContracts;
	Items.DebtsListDocument.Visible = Counterparty.DoOperationsByDocuments;
	Items.DebtsListOrder.Visible = Counterparty.DoOperationsByOrders;
	
	AccountingCurrency = Constants.AccountingCurrency.Get();
	CurrencyTransactionsAccounting = Constants.FunctionalCurrencyTransactionsAccounting.Get();
	
	AddressPaymentDetailsInStorage = Parameters.AddressPaymentDetailsInStorage;
	FilteredDebts.Load(GetFromTempStorage(AddressPaymentDetailsInStorage));
	
	// Removing the rows with no amount.
	RowToDeleteArray = New Array;
	For Each CurRow IN FilteredDebts Do
		If CurRow.SettlementsAmount = 0 Then
			RowToDeleteArray.Add(CurRow);
		EndIf;
	EndDo;
	
	For Each CurItem IN RowToDeleteArray Do
		FilteredDebts.Delete(CurItem);
	EndDo;
	
	FunctionalCurrencyTransactionsAccounting = Constants.FunctionalCurrencyTransactionsAccounting.Get();
	Items.DebtsListExchangeRate.Visible = FunctionalCurrencyTransactionsAccounting;
	Items.DebtsListMultiplicity.Visible = FunctionalCurrencyTransactionsAccounting;
	
	Items.Totals.Visible = Not CurrencyTransactionsAccounting;
	
	FillDebts();
	
EndProcedure // OnCreateAtServer()

// Procedure - OnCreateAtServer event handler.
//
&AtClient
Procedure OnOpen(Cancel)
	
	CalculateAmountTotal();
	
    //( elmi # 08.5 
	SmallBusinessClient.RenameTitleExchangeRateMultiplicity( ThisForm, "DebtsList");
	SmallBusinessClient.RenameTitleExchangeRateMultiplicity( ThisForm, "FilteredDebts");
    //) elmi

	
EndProcedure // OnOpen()

// Procedure calculates the total amount.
//
&AtClient
Procedure CalculateAmountTotal()
	
	AmountTotal = 0;
	
	For Each CurRow IN FilteredDebts Do
		AmountTotal = AmountTotal + CurRow.SettlementsAmount;
	EndDo;
	
EndProcedure // CalculateAmountTotal()

// Procedure - OK button click handler.
//
&AtClient
Procedure OKExecute()
	
	WritePickToStorage();
	Close(DialogReturnCode.OK);
	
EndProcedure

// The procedure places pick-up results in the storage.
//
&AtServer
Procedure WritePickToStorage() 
	
	TableFilteredDebts = FilteredDebts.Unload();
	PutToTempStorage(TableFilteredDebts, AddressPaymentDetailsInStorage);
	
EndProcedure

// Procedure puts selection results in the selection.
//
&AtClient
Procedure DebtsListValueChoice(Item, StandardProcessing, Value)
	
	StandardProcessing = False;
	CurrentRow = Item.CurrentData;
	
	SettlementsAmount = CurrentRow.SettlementsAmount;
	If AskAmount Then
		ShowInputNumber(New NotifyDescription("DebtsListValueChoiceEnd", ThisObject, New Structure("CurrentRow, SettlementsAmount.", CurrentRow, SettlementsAmount)), SettlementsAmount, "Enter the amount of settlements", , );
        Return;
	EndIf;
	
	DebtsListValueChoiceFragment(SettlementsAmount, CurrentRow);
EndProcedure

&AtClient
Procedure DebtsListValueChoiceEnd(Result, AdditionalParameters) Export
    
    CurrentRow = AdditionalParameters.CurrentRow;
    SettlementsAmount = ?(Result = Undefined, AdditionalParameters.SettlementsAmount, Result);
    
    
    If Not (Result <> Undefined) Then
        Return;
    EndIf;
    
    DebtsListValueChoiceFragment(SettlementsAmount, CurrentRow);

EndProcedure

&AtClient
Procedure DebtsListValueChoiceFragment(Val SettlementsAmount, Val CurrentRow)
    
    Var NewRow, Rows, SearchStructure;
    
    CurrentRow.SettlementsAmount = SettlementsAmount;
    
    SearchStructure = New Structure("Contract, Document, Order", CurrentRow.Contract, CurrentRow.Document, CurrentRow.Order);
    Rows = FilteredDebts.FindRows(SearchStructure);
    
    If Rows.Count() > 0 Then
        NewRow = Rows[0];
        NewRow.SettlementsAmount = NewRow.SettlementsAmount + SettlementsAmount;
    Else 
        NewRow = FilteredDebts.Add();
        FillPropertyValues(NewRow, CurrentRow);
    EndIf;
    
    Items.FilteredDebts.CurrentRow = NewRow.GetID();
    
    CalculateAmountTotal();
    FillDebts();

EndProcedure // DebtsListValueChoice()

// Procedure - DragStart of list DebtsList event handler.
//
&AtClient
Procedure DebtsListDragStart(Item, DragParameters, StandardProcessing)
	
	CurrentData = Item.CurrentData;
	Structure = New Structure;
	Structure.Insert("Document", CurrentData.Document);
	Structure.Insert("Order", CurrentData.Order);
	Structure.Insert("SettlementsAmount", CurrentData.SettlementsAmount);
	Structure.Insert("Contract", CurrentData.Contract);
	If CurrentData.Property("ExchangeRate") Then
		Structure.Insert("ExchangeRate", CurrentData.ExchangeRate);
	EndIf;
	If CurrentData.Property("Multiplicity") Then
		Structure.Insert("Multiplicity", CurrentData.Multiplicity);
	EndIf;
	
	DragParameters.Value = Structure;
	
	DragParameters.AllowedActions = DragAllowedActions.Copy;
	
EndProcedure // DebtsListDragStart()

// Procedure - DragChek of list FilteredDebts event handler.
//
&AtClient
Procedure FilteredDebtsDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	DragParameters.Action = DragAction.Copy;
	
EndProcedure // FilteredDebtsDragCheck()

// Procedure - DragChek of list FilteredDebts event handler.
//
&AtClient
Procedure FilteredDebtsDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
	ParametersStructure = DragParameters.Value;
	
	SettlementsAmount = ParametersStructure.SettlementsAmount;
	If AskAmount Then
		ShowInputNumber(New NotifyDescription("FilteredDebtsDragEnd", ThisObject, New Structure("StructureParameters,SettlementsAmount", ParametersStructure, SettlementsAmount)), SettlementsAmount, "Enter the amount of settlements", , );
        Return;
	EndIf;
	
	FilteredDebtsDragFragment(ParametersStructure, SettlementsAmount);
EndProcedure

&AtClient
Procedure FilteredDebtsDragEnd(Result, AdditionalParameters) Export
    
    ParametersStructure = AdditionalParameters.ParametersStructure;
    SettlementsAmount = ?(Result = Undefined, AdditionalParameters.SettlementsAmount, Result);
    
    
    If Not (Result <> Undefined) Then
        Return;
    EndIf;
    
    FilteredDebtsDragFragment(ParametersStructure, SettlementsAmount);

EndProcedure

&AtClient
Procedure FilteredDebtsDragFragment(Val ParametersStructure, Val SettlementsAmount)
    
    Var NewRow, Rows, SearchStructure;
    
    ParametersStructure.SettlementsAmount = SettlementsAmount;
    
    SearchStructure = New Structure("Contract, Document, Order", ParametersStructure.Contract, ParametersStructure.Document, ParametersStructure.Order);
    Rows = FilteredDebts.FindRows(SearchStructure);
    
    If Rows.Count() > 0 Then
        NewRow = Rows[0];
        NewRow.SettlementsAmount = NewRow.SettlementsAmount + SettlementsAmount;
    Else 
        NewRow = FilteredDebts.Add();
        FillPropertyValues(NewRow, ParametersStructure);
    EndIf;
    
    Items.FilteredDebts.CurrentRow = NewRow.GetID();
    
    CalculateAmountTotal();
    FillDebts();

EndProcedure // FilteredDebtsDrag()

// Procedure - handler of clicking the Refresh button.
//
&AtClient
Procedure Refresh(Command)
	
	FillDebts();
	
EndProcedure // Refresh()

// Procedure - handler of clicking the AskAmount button.
//
&AtClient
Procedure AskAmount(Command)
	
	AskAmount = Not AskAmount;
	Items.AskAmount.Check = AskAmount;
	
EndProcedure // AskAmount()

// Procedure - OnChange of list FilteredDebts event handler.
//
&AtClient
Procedure FilteredDebtsOnChange(Item)
	
	CalculateAmountTotal();
	FillDebts();
	
EndProcedure // FilteredDebtsOnChange()

// Procedure - OnStartEdit of list FilteredDebts event handler.
//
&AtClient
Procedure FilteredDebtsOnStartEdit(Item, NewRow, Copy)
	
	If Copy Then
		CalculateAmountTotal();
		FillDebts();
	EndIf;
	
EndProcedure // FilteredAdvancesOnStartEdit()

// Procedure is filling the payment details.
//
&AtServer
Procedure FillPaymentDetails()
	
	// Filling default payment details.
	Query = New Query;
	Query.Text =
	
	"SELECT
	|	AccountsPayableBalances.Company AS Company,
	|	AccountsPayableBalances.Contract AS Contract,
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.SettlementsType AS SettlementsType,
	|	SUM(AccountsPayableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsPayableBalances.AmountCurBalance) AS AmountCurBalance,
	|	AccountsPayableBalances.Document.Date AS DocumentDate,
	|	SUM(CAST(AccountsPayableBalances.AmountCurBalance * SettlementsCurrencyRates.ExchangeRate * CurrencyRatesOfDocument.Multiplicity / (CurrencyRatesOfDocument.ExchangeRate * SettlementsCurrencyRates.Multiplicity) AS NUMBER(15, 2))) AS AmountCurrDocument,
	|	CurrencyRatesOfDocument.ExchangeRate AS CashAssetsRate,
	|	CurrencyRatesOfDocument.Multiplicity AS CashMultiplicity,
	|	SettlementsCurrencyRates.ExchangeRate AS ExchangeRate,
	|	SettlementsCurrencyRates.Multiplicity AS Multiplicity
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.Company AS Company,
	|		AccountsPayableBalances.Contract AS Contract,
	|		AccountsPayableBalances.Document AS Document,
	|		AccountsPayableBalances.Order AS Order,
	|		AccountsPayableBalances.SettlementsType AS SettlementsType,
	|		ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AmountBalance,
	|		ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsPayable.Balance(
	|				,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					// TextOfContractSelection
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsVendorSettlements.Company,
	|		DocumentRegisterRecordsVendorSettlements.Contract,
	|		DocumentRegisterRecordsVendorSettlements.Document,
	|		DocumentRegisterRecordsVendorSettlements.Order,
	|		DocumentRegisterRecordsVendorSettlements.SettlementsType,
	|		CASE
	|			WHEN DocumentRegisterRecordsVendorSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsVendorSettlements.Amount, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsVendorSettlements.Amount, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsVendorSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsVendorSettlements.AmountCur, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsVendorSettlements.AmountCur, 0)
	|		END
	|	FROM
	|		AccumulationRegister.AccountsPayable AS DocumentRegisterRecordsVendorSettlements
	|	WHERE
	|		DocumentRegisterRecordsVendorSettlements.Recorder = &Ref
	|		AND DocumentRegisterRecordsVendorSettlements.Period <= &Period
	|		AND DocumentRegisterRecordsVendorSettlements.Company = &Company
	|		AND DocumentRegisterRecordsVendorSettlements.Counterparty = &Counterparty
	|		AND DocumentRegisterRecordsVendorSettlements.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalances
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Period, Currency = &Currency) AS CurrencyRatesOfDocument
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Period, ) AS SettlementsCurrencyRates
	|		ON AccountsPayableBalances.Contract.SettlementsCurrency = SettlementsCurrencyRates.Currency
	|WHERE
	|	AccountsPayableBalances.AmountCurBalance > 0
	|
	|GROUP BY
	|	AccountsPayableBalances.Company,
	|	AccountsPayableBalances.Contract,
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.SettlementsType,
	|	AccountsPayableBalances.Document.Date,
	|	CurrencyRatesOfDocument.ExchangeRate,
	|	CurrencyRatesOfDocument.Multiplicity,
	|	SettlementsCurrencyRates.ExchangeRate,
	|	SettlementsCurrencyRates.Multiplicity
	|
	|ORDER BY
	|	DocumentDate";
		
	Query.SetParameter("Company", Counterparty);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Period", Period);
	Query.SetParameter("Currency", CashCurrency);
	Query.SetParameter("Ref", Ref);
	
	NeedFilterByContracts = SmallBusinessReUse.CounterpartyContractsControlNeeded();
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractKindsListForDocument(Ref, OperationKind);
	If Counterparty.DoOperationsByContracts
	   AND NeedFilterByContracts Then
		Query.Text = StrReplace(Query.Text, "// TextOfContractSelection", "And Contract.ContractType IN (&ContractTypesList)");
		Query.SetParameter("ContractTypesList", ContractTypesList);
	EndIf;
	
	ContractByDefault = Catalogs.CounterpartyContracts.GetDefaultContractByCompanyContractKind(
		Counterparty,
		Counterparty,
		ContractTypesList
	);
	
	StructureContractCurrencyRateByDefault = InformationRegisters.CurrencyRates.GetLast(
		Period,
		New Structure("Currency", ContractByDefault.SettlementsCurrency)
	);
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	FilteredDebts.Clear();
	
	AmountLeftToDistribute = DocumentAmount;
	
	StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Period, New Structure("Currency", CashCurrency));
	
	ExchangeRate = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.ExchangeRate
	);
	Multiplicity = ?(
	    // (elmi
	    //StructureByCurrency.ExchangeRate = 0,
		StructureByCurrency.Multiplicity = 0,
		// )elmi
		1,
		StructureByCurrency.Multiplicity
	);
	
	While AmountLeftToDistribute > 0 Do
		
		NewRow = FilteredDebts.Add();
		
		If SelectionOfQueryResult.Next() Then
			
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			
			If SelectionOfQueryResult.AmountCurrDocument <= AmountLeftToDistribute Then // balance amount is less or equal than it is necessary to distribute
				
				NewRow.SettlementsAmount = SelectionOfQueryResult.AmountCurBalance;
				AmountLeftToDistribute = AmountLeftToDistribute - SelectionOfQueryResult.AmountCurrDocument;
				
			Else // Balance amount is greater than it is necessary to distribute
				
				NewRow.SettlementsAmount = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
					AmountLeftToDistribute,
					SelectionOfQueryResult.CashAssetsRate,
					SelectionOfQueryResult.ExchangeRate,
					SelectionOfQueryResult.CashMultiplicity,
					SelectionOfQueryResult.Multiplicity
				);
				AmountLeftToDistribute = 0;
				
			EndIf;
			
		Else
			
			NewRow.Contract = ContractByDefault;
			NewRow.ExchangeRate = ?(
				StructureContractCurrencyRateByDefault.ExchangeRate = 0,
				1,
				StructureContractCurrencyRateByDefault.ExchangeRate
			);
			NewRow.Multiplicity = ?(
				StructureContractCurrencyRateByDefault.Multiplicity = 0,
				1,
				StructureContractCurrencyRateByDefault.Multiplicity
			);
			NewRow.SettlementsAmount = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
				AmountLeftToDistribute,
				ExchangeRate,
				NewRow.ExchangeRate,
				Multiplicity,
				NewRow.Multiplicity
			);
			NewRow.AdvanceFlag = True;
			AmountLeftToDistribute = 0;
			
		EndIf;
		
	EndDo;
	
EndProcedure // FillPaymentDetails()

// Procedure - Handler of clicking the FillAutomatically button.
//
&AtClient
Procedure FillAutomatically(Command)
	
	FillPaymentDetails();
	CalculateAmountTotal();
	FillDebts();
	
EndProcedure // FillAutomatically()

// Procedure fills the debt list.
//
&AtServer
Procedure FillDebts()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	&Company,
	|	FilteredDebts.Contract,
	|	FilteredDebts.Document,
	|	CASE
	|		WHEN FilteredDebts.Order = UNDEFINED
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		ELSE FilteredDebts.Order
	|	END AS Order,
	|	FilteredDebts.SettlementsAmount
	|INTO TableFilteredDebts
	|FROM
	|	&TableFilteredDebts AS FilteredDebts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsPayableBalances.Company AS Company,
	|	AccountsPayableBalances.Contract AS Contract,
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	SUM(AccountsPayableBalances.AmountCurBalance) AS SettlementsAmount,
	|	AccountsPayableBalances.Document.Date AS DocumentDate,
	|	SettlementsCurrencyRates.ExchangeRate AS ExchangeRate,
	|	SettlementsCurrencyRates.Multiplicity AS Multiplicity
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.Company AS Company,
	|		AccountsPayableBalances.Contract AS Contract,
	|		AccountsPayableBalances.Document AS Document,
	|		AccountsPayableBalances.Order AS Order,
	|		ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsPayable.Balance(
	|				,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					// TextOfContractSelection
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		&Company,
	|		FilteredDebts.Contract,
	|		FilteredDebts.Document,
	|		FilteredDebts.Order,
	|		-FilteredDebts.SettlementsAmount
	|	FROM
	|		TableFilteredDebts AS FilteredDebts
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsVendorSettlements.Company,
	|		DocumentRegisterRecordsVendorSettlements.Contract,
	|		DocumentRegisterRecordsVendorSettlements.Document,
	|		DocumentRegisterRecordsVendorSettlements.Order,
	|		CASE
	|			WHEN DocumentRegisterRecordsVendorSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsVendorSettlements.AmountCur, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsVendorSettlements.AmountCur, 0)
	|		END
	|	FROM
	|		AccumulationRegister.AccountsPayable AS DocumentRegisterRecordsVendorSettlements
	|	WHERE
	|		DocumentRegisterRecordsVendorSettlements.Recorder = &Ref
	|		AND DocumentRegisterRecordsVendorSettlements.Period <= &Period
	|		AND DocumentRegisterRecordsVendorSettlements.Company = &Company
	|		AND DocumentRegisterRecordsVendorSettlements.Counterparty = &Counterparty
	|		AND DocumentRegisterRecordsVendorSettlements.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalances
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Period, ) AS SettlementsCurrencyRates
	|		ON AccountsPayableBalances.Contract.SettlementsCurrency = SettlementsCurrencyRates.Currency
	|
	|GROUP BY
	|	AccountsPayableBalances.Company,
	|	AccountsPayableBalances.Contract,
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.Document.Date,
	|	SettlementsCurrencyRates.ExchangeRate,
	|	SettlementsCurrencyRates.Multiplicity
	|
	|HAVING
	|	SUM(AccountsPayableBalances.AmountCurBalance) > 0
	|
	|ORDER BY
	|	DocumentDate";
	
	Query.SetParameter("Company", SubsidiaryCompany);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Period", Period);
	Query.SetParameter("Currency", CashCurrency);
	Query.SetParameter("TableFilteredDebts", FilteredDebts.Unload());
	Query.SetParameter("Ref", Ref);
	
	NeedFilterByContracts = SmallBusinessReUse.CounterpartyContractsControlNeeded();
	If Counterparty.DoOperationsByContracts
	   AND NeedFilterByContracts Then
		Query.Text = StrReplace(Query.Text, "// TextOfContractSelection", "And Contract.ContractType IN (&ContractTypesList)");
		Query.SetParameter("ContractTypesList", Catalogs.CounterpartyContracts.GetContractKindsListForDocument(Ref, OperationKind));
	EndIf;
	
	DebtsList.Load(Query.Execute().Unload());
	
EndProcedure // FillDebts()

// Procedure - BeforeStartAdding of list FilteredDebts event  handler.
//
&AtClient
Procedure FilteredDebtsBeforeAddingStart(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure // FilteredDebtsBeforeAddingStart()














