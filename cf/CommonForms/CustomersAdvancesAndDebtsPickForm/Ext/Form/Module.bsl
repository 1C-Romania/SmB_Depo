
&AtClient
Procedure AddAndCalculateAdvanceRow(SettlementsAmount, CurrentRow)
	
	SearchStructure = New Structure("Document, Order", CurrentRow.Document, CurrentRow.Order);
	Rows = ListFilteredAdvancesAndDebts.FindRows(SearchStructure);
	
	If Rows.Count() > 0 Then
		NewRow = Rows[0];
		SettlementsAmount = SettlementsAmount + NewRow.SettlementsAmount;
	Else
		NewRow = ListFilteredAdvancesAndDebts.Add();
	EndIf;
	
	FillPropertyValues(NewRow, CurrentRow);
	
	NewRow.SettlementsAmount = SettlementsAmount;
	
	NewRow.ExchangeRate = ?(NewRow.ExchangeRate = 0, 1, NewRow.ExchangeRate);
	NewRow.Multiplicity = ?(NewRow.Multiplicity = 0, 1, NewRow.Multiplicity);
	
	NewRow.ExchangeRate = ?(
		NewRow.SettlementsAmount = 0,
		1,
		CurrentRow.AccountingAmount / CurrentRow.SettlementsAmount * RateAccountingCurrency
	);
	
	If Not CurrencyTransactionsAccounting Then
		NewRow.AccountingAmount = CurrentRow.SettlementsAmount;
	ElsIf AskAmount OR Rows.Count() > 0 Then
		NewRow.AccountingAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
			NewRow.SettlementsAmount,
			NewRow.ExchangeRate,
			RateAccountingCurrency,
			NewRow.Multiplicity,
			AccountingCurrencyMultiplicity
		);
	EndIf;
	
	Items.ListFilteredAdvancesAndDebts.CurrentRow = NewRow.GetID();
	
	CalculateAmountsTotal();
	
	FillAdvancesAndDebts();
	
EndProcedure

// Procedure checks the correctness of the form attributes filling.
//
&AtClient
Procedure CheckFillOfFormAttributes(Cancel)
	
	// Attributes filling check.
	LineNumber = 0;
		
	For Each RowListFilteredAdvancesAndDebts IN ListFilteredAdvancesAndDebts Do
		LineNumber = LineNumber + 1;
		If CurrencyTransactionsAccounting
		AND Not ValueIsFilled(RowListFilteredAdvancesAndDebts.ExchangeRate) Then
			Message = New UserMessage();
			Message.Text = NStr("en='Column ""Exchange rate"" is not filled in the row. ';ru='Не заполнена колонка ""Курс"" в строке '")
				+ String(LineNumber)
				+ NStr("en=' ""Filtered Advances and debts"" list.';ru=' списка ""Отобранные авансы и долги"".'");
			Message.Field = "Document";
			Message.Message();
			Cancel = True;
		EndIf;
		If CurrencyTransactionsAccounting
		AND Not ValueIsFilled(RowListFilteredAdvancesAndDebts.Multiplicity) Then
			Message = New UserMessage();
			Message.Text = NStr("en='Column ""Multiplicity"" is not filled in the row. ';ru='Не заполнена колонка ""Кратность"" в строке '")
				+ String(LineNumber)
				+ NStr("en=' ""Filtered Advances and debts"" list.';ru=' списка ""Отобранные авансы и долги"".'");
			Message.Field = "Document";
			Message.Message();
			Cancel = True;
		EndIf;
		If Not ValueIsFilled(RowListFilteredAdvancesAndDebts.SettlementsAmount) Then
			Message = New UserMessage();
			Message.Text = NStr("en='Field ""Settlements amount"" is not filled in row ';ru='Не заполнена колонка ""Сумма расчетов"" в строке '")
				+ String(LineNumber)
				+ NStr("en=' ""Filtered Advances and debts"" list.';ru=' списка ""Отобранные авансы и долги"".'");
			Message.Field = "Document";
			Message.Message();
			Cancel = True;
		EndIf;
		If CurrencyTransactionsAccounting
		AND Not ValueIsFilled(RowListFilteredAdvancesAndDebts.AccountingAmount) Then
			Message = New UserMessage();
			Message.Text = NStr("en='No filled column ""Accounting Amount"" in row. ';ru='Не заполнена колонка ""Сумма учета"" в строке '")
				+ String(LineNumber)
				+ NStr("en=' ""Filtered advances and debts"" list.';ru=' списка ""Отобранные авансы и долги"".'");
			Message.Field = "Document";
			Message.Message();
			Cancel = True;
		EndIf;
	EndDo;
	
EndProcedure // CheckFillFormAttributes()

// Procedure calculates the total amounts.
//
&AtClient
Procedure CalculateAmountsTotal()
	
	AccountingAmountTotal = 0;
	
	For Each CurRow IN ListFilteredAdvancesAndDebts Do
		AccountingAmountTotal = AccountingAmountTotal + CurRow.AccountingAmount;
	EndDo;
	
EndProcedure // CalculateAmountsTotal()

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Company			= Parameters.Company;
	Counterparty	= Parameters.Counterparty;
	Date			= Parameters.Date;
	Ref				= Parameters.Ref;
	CurrencyTransactionsAccounting = Constants.FunctionalCurrencyTransactionsAccounting.Get();
	
	Items.AdvancesDebtsListDocument.Visible = Counterparty.DoOperationsByDocuments;
	Items.AdvancesDebtsListOrder.Visible = Counterparty.DoOperationsByOrders;
	Items.AdvancesDebtsListContract.Visible = Counterparty.DoOperationsByContracts;
	Items.ListFilteredAdvancesAndDebtsDocument.Visible = Counterparty.DoOperationsByDocuments;
	Items.ListFilteredAdvancesAndDebtsOrder.Visible = Counterparty.DoOperationsByOrders;
	Items.ListFilteredAdvancesAndDebtsContract.Visible = Counterparty.DoOperationsByContracts;
	
	AddressListFilteredAdvancesAndDebtsInStorage = Parameters.AddressDebitorInStorage;
	
	AccountingCurrency = Constants.AccountingCurrency.Get();
	StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", AccountingCurrency));
	RateAccountingCurrency = StructureByCurrency.ExchangeRate;
	AccountingCurrencyMultiplicity = StructureByCurrency.Multiplicity;
	
	RowOfColumns =
		"Contract,
		|Document,
		|Order,
		|AccountingAmount,
		|ExchangeRate,
		|Multiplicity,
		|SettlementsAmount,
		|AdvanceFlag";
	
	ListFilteredAdvancesAndDebts.Load(GetFromTempStorage(AddressListFilteredAdvancesAndDebtsInStorage));
	
	Items.AdvancesDebtsListAccountingAmount.Visible = CurrencyTransactionsAccounting;
	
	FillAdvancesAndDebts();
	
EndProcedure // OnCreateAtServer()

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	CalculateAmountsTotal();
	
EndProcedure // OnOpen()

// Procedure - OK button click handler.
//
&AtClient
Procedure OK(Command)
	
	Cancel = False;
	
	CheckFillOfFormAttributes(Cancel);
	
	If Not Cancel Then
		WritePickToStorage();
		Close(DialogReturnCode.OK);
	EndIf;
	
EndProcedure // Ok()

// Procedure - handler of clicking the Refresh button.
//
&AtClient
Procedure Refresh(Command)
	
	FillAdvancesAndDebts();
	
EndProcedure // Refresh()

// Procedure - handler of clicking the AskAmount button.
//
&AtClient
Procedure AskAmount(Command)
	
	AskAmount = Not AskAmount;
	Items.AskAmount.Check = AskAmount;
	
EndProcedure // AskAmount()

// The procedure places pick-up results in the storage.
//
&AtServer
Procedure WritePickToStorage()
	
	ListFilteredAdvancesAndDebtsInStorage = ListFilteredAdvancesAndDebts.Unload(, RowOfColumns);
	PutToTempStorage(ListFilteredAdvancesAndDebtsInStorage, AddressListFilteredAdvancesAndDebtsInStorage);
	
EndProcedure // WritePickToStorage()

// It receives data set from the server for the ListFilteredAdvancesAndDebtsDocumentOnChange procedure.
//
&AtServerNoContext
Function GetDataDocumentOnChange(Document)
	
	StructureData = New Structure();
	
	StructureData.Insert("SettlementsAmount", Document.PaymentDetails.Total("SettlementsAmount"));
	
	Return StructureData;
	
EndFunction // GetDataDocumentOntChange()

// Adds a row into filtered.
//
&AtClient
Procedure AddRowIntoFiltered(CurrentRow)
	
	SettlementsAmount = CurrentRow.SettlementsAmount;
	If AskAmount Then
		
		NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, New Structure("CurrentRow, SettlementsAmount.", CurrentRow, SettlementsAmount));
		ShowInputNumber(NOTifyDescription, SettlementsAmount, NStr("en='Enter settlements amount';ru='Введите сумму расчетов'"));
		
	Else
		
		AddAndCalculateAdvanceRow(SettlementsAmount, CurrentRow);
		
	EndIf;
	
EndProcedure // AddRowIntoFiltered()

// The procedure places selection results into pick
//
&AtClient
Procedure AdvancesListValueChoice(Item, StandardProcessing, Value)
	
	StandardProcessing = False;
	CurrentRow = Item.CurrentData;
	AddRowIntoFiltered(CurrentRow);
	
EndProcedure // AdvancesListValueChoice()

// Procedure - handler of event OnStartEdit of the ListFilteredAdvancesAndDebts tabular section.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsOnStartEdit(Item, NewRow, Copy)
	
	If Copy Then
		CalculateAmountsTotal();
		FillAdvancesAndDebts();
	EndIf;
	
EndProcedure // ListFilteredAdvancesAndDebtsOnStartEdit()

// Procedure - OnChange of input field SettlementsAmount of the
// ListFilteredAdvancesAndDebts part table event handler. Calculates the amount of the payment.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsAccountsAmountOnChange(Item)
	
	TabularSectionRow = Items.ListFilteredAdvancesAndDebts.CurrentData;
	CalculateAccountingSUM(TabularSectionRow);
	
EndProcedure // ListFilteredAdvancesAndDebtsSettlementsAmountOnChange()

// Procedure - OnChange of input field Rate of
// the ListFilteredAdvancesAndDebts tabular section event handler. Calculates the amount of the payment.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsRateOnChange(Item)
	
	TabularSectionRow = Items.ListFilteredAdvancesAndDebts.CurrentData;
	CalculateAccountingSUM(TabularSectionRow);
	
EndProcedure // ListFilteredAdvancesAndDebtsRateOnChange()

// Procedure - OnChange of input field Repetition of
// the ListFilteredAdvancesAndDebts tabular section event handler. Calculates the amount of the payment.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsMultiplicityOnChange(Item)
	
	TabularSectionRow = Items.ListFilteredAdvancesAndDebts.CurrentData;
	CalculateAccountingSUM(TabularSectionRow);
	
EndProcedure // ListFilteredAdvancesAndDebtsRepetitionOnChange()

// Procedure - OnChange of input field AccountingAmount of the
// ListFilteredAdvancesAndDebts tabular section event handler. Calculates the rate and multiplicity.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsAccountingAmountOnChange(Item)
	
	TabularSectionRow = Items.ListFilteredAdvancesAndDebts.CurrentData;
	
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.ExchangeRate = 0,
		1,
		TabularSectionRow.ExchangeRate
	);
	
	TabularSectionRow.Multiplicity = 1;
	
	TabularSectionRow.ExchangeRate =
		?(TabularSectionRow.SettlementsAmount = 0,
			1,
			TabularSectionRow.AccountingAmount
		  / TabularSectionRow.SettlementsAmount
		  * RateAccountingCurrency
	);
	
EndProcedure // ListFilteredAdvancesAndDebtsPaymentAmountOnChange()

// Procedure - OnChange of input field Document of
// the ListFilteredAdvancesAndDebts tabular section event handler.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsDocumentOnChange(Item)
	
	TabularSectionRow = Items.ListFilteredAdvancesAndDebts.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashReceipt")
	 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentReceipt") Then
		TabularSectionRow.AdvanceFlag = True;
	Else
		TabularSectionRow.AdvanceFlag = False;
	EndIf;
	
	If ValueIsFilled(TabularSectionRow.Document) Then
		StructureData = GetDataDocumentOnChange(TabularSectionRow.Document);
		TabularSectionRow.SettlementsAmount = StructureData.SettlementsAmount;
		CalculateAccountingSUM(TabularSectionRow);
	EndIf;
	
EndProcedure // ListFilteredAdvancesAndDebtsDocumentOnChange()

// Procedure - handler of event StartDrag of list AdvancesList.
//
&AtClient
Procedure AdvancesListDragStart(Item, DragParameters, StandardProcessing)
	
	CurrentData = Item.CurrentData;
	Structure = New Structure;
	Structure.Insert("Contract", CurrentData.Contract);
	Structure.Insert("Document", CurrentData.Document);
	Structure.Insert("Order", CurrentData.Order);
	Structure.Insert("SettlementsAmount", CurrentData.SettlementsAmount);
	Structure.Insert("AdvanceFlag", CurrentData.AdvanceFlag);
	
	If CurrentData.Property("AccountingAmount") Then
		Structure.Insert("AccountingAmount", CurrentData.AccountingAmount);
	EndIf;
	
	DragParameters.Value = Structure;
	
	DragParameters.AllowedActions = DragAllowedActions.Copy;
	
EndProcedure // AdvancesListDragStart()

// Procedure - handler of event DragCheck of list ListFilteredAdvancesAndDebts.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	DragParameters.Action = DragAction.Copy;
	
EndProcedure // ListFilteredAdvancesAndDebtsDragCheck()

// Procedure - handler of event Drag of list ListFilteredAdvancesAndDebts.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	CurrentRow = DragParameters.Value;
	AddRowIntoFiltered(CurrentRow);
	FillAdvancesAndDebts();
	
EndProcedure // ListFilteredAdvancesAndDebtsDrag()

// Procedure - handler of event OnChange of list ListFilteredAdvancesAndDebts.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsOnChange(Item)
	
	CalculateAmountsTotal();
	FillAdvancesAndDebts();
	
EndProcedure // ListFilteredAdvancesAndDebtsOnChange()

// Procedure - handler of event OnChange of list ListFilteredAdvancesAndDebtsContract.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsContractOnChange(Item)
	
	TabularSectionRow = Items.ListFilteredAdvancesAndDebts.CurrentData;
	
	StructureData = GetDataContractOnChange(
		Date,
		TabularSectionRow.Contract
	);
	
	If ValueIsFilled(TabularSectionRow.Contract) Then 
		TabularSectionRow.ExchangeRate      = ?(StructureData.CurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.CurrencyRateRepetition.ExchangeRate);
		TabularSectionRow.Multiplicity = ?(StructureData.CurrencyRateRepetition.Multiplicity = 0, 1, StructureData.CurrencyRateRepetition.Multiplicity);
	EndIf;
	
	CalculateAccountingSUM(TabularSectionRow);
	
EndProcedure // ListFilteredAdvancesAndDebtsContractOnChange()

// Procedure calculates the accounting amount.
//
&AtClient
Procedure CalculateAccountingSUM(TabularSectionRow)
	
	TabularSectionRow.ExchangeRate      = ?(TabularSectionRow.ExchangeRate      = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.AccountingAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		TabularSectionRow.ExchangeRate,
		RateAccountingCurrency,
		TabularSectionRow.Multiplicity,
		AccountingCurrencyMultiplicity
	);
	
EndProcedure // CalculateAccountingAmount()

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

// Procedure fills the advance list.
//
&AtServer
Procedure FillAdvancesAndDebts()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	FilteredAdvancesAndDebts.AdvanceFlag,
	|	FilteredAdvancesAndDebts.Contract,
	|	FilteredAdvancesAndDebts.Document,
	|	CASE
	|		WHEN FilteredAdvancesAndDebts.Order = UNDEFINED
	|			THEN VALUE(Document.CustomerOrder.EmptyRef)
	|		ELSE FilteredAdvancesAndDebts.Order
	|	END AS Order,
	|	FilteredAdvancesAndDebts.SettlementsAmount,
	|	FilteredAdvancesAndDebts.AccountingAmount
	|INTO TableFilteredAdvancesAndDebts
	|FROM
	|	&TableFilteredAdvancesAndDebts AS FilteredAdvancesAndDebts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Contract AS Contract,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.AdvanceFlag AS AdvanceFlag,
	|	SUM(AccountsReceivableBalances.AmountBalance) AS AccountingAmount,
	|	SUM(AccountsReceivableBalances.AmountCurBalance) AS SettlementsAmount,
	|	AccountsReceivableBalances.Document.Date AS DocumentDate,
	|	SettlementsCurrencyRates.ExchangeRate AS ExchangeRate,
	|	SettlementsCurrencyRates.Multiplicity AS Multiplicity
	|FROM
	|	(SELECT
	|		AccountsReceivableBalances.Contract AS Contract,
	|		AccountsReceivableBalances.Document AS Document,
	|		AccountsReceivableBalances.Order AS Order,
	|		CASE
	|			WHEN AccountsReceivableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|				THEN TRUE
	|			ELSE FALSE
	|		END AS AdvanceFlag,
	|		CASE
	|			WHEN AccountsReceivableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|				THEN -AccountsReceivableBalances.AmountBalance
	|			ELSE AccountsReceivableBalances.AmountBalance
	|		END AS AmountBalance,
	|		CASE
	|			WHEN AccountsReceivableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|				THEN -AccountsReceivableBalances.AmountCurBalance
	|			ELSE AccountsReceivableBalances.AmountCurBalance
	|		END AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsReceivable.Balance(
	|				,
	|				Company = &Company
	|					AND Counterparty = &Counterparty) AS AccountsReceivableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		FilteredAdvancesAndDebts.Contract,
	|		FilteredAdvancesAndDebts.Document,
	|		FilteredAdvancesAndDebts.Order,
	|		FilteredAdvancesAndDebts.AdvanceFlag,
	|		-FilteredAdvancesAndDebts.AccountingAmount,
	|		-FilteredAdvancesAndDebts.SettlementsAmount
	|	FROM
	|		TableFilteredAdvancesAndDebts AS FilteredAdvancesAndDebts
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsAccountsReceivable.Contract,
	|		DocumentRegisterRecordsAccountsReceivable.Document,
	|		DocumentRegisterRecordsAccountsReceivable.Order,
	|		CASE
	|			WHEN DocumentRegisterRecordsAccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|				THEN TRUE
	|			ELSE FALSE
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsAccountsReceivable.Amount, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsAccountsReceivable.Amount, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsAccountsReceivable.AmountCur, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsAccountsReceivable.AmountCur, 0)
	|		END
	|	FROM
	|		AccumulationRegister.AccountsReceivable AS DocumentRegisterRecordsAccountsReceivable
	|	WHERE
	|		DocumentRegisterRecordsAccountsReceivable.Recorder = &Ref
	|		AND DocumentRegisterRecordsAccountsReceivable.Period <= &Period
	|		AND DocumentRegisterRecordsAccountsReceivable.Company = &Company
	|		AND DocumentRegisterRecordsAccountsReceivable.Counterparty = &Counterparty) AS AccountsReceivableBalances
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Period, ) AS SettlementsCurrencyRates
	|		ON AccountsReceivableBalances.Contract.SettlementsCurrency = SettlementsCurrencyRates.Currency
	|
	|GROUP BY
	|	AccountsReceivableBalances.Document,
	|	AccountsReceivableBalances.Contract,
	|	AccountsReceivableBalances.Order,
	|	AccountsReceivableBalances.AdvanceFlag,
	|	AccountsReceivableBalances.Document.Date,
	|	SettlementsCurrencyRates.ExchangeRate,
	|	SettlementsCurrencyRates.Multiplicity
	|
	|HAVING
	|	(SUM(AccountsReceivableBalances.AmountBalance) > 0
	|		OR SUM(AccountsReceivableBalances.AmountCurBalance) > 0)
	|
	|ORDER BY
	|	DocumentDate";
	
	Query.SetParameter("Company", Company);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("TableFilteredAdvancesAndDebts", ListFilteredAdvancesAndDebts.Unload());
	
	AdvancesDebtsList.Load(Query.Execute().Unload());
	
EndProcedure // FillAdvancesAndDebts()

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the result of entering the supplier advance offset amount.
//
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = Undefined Then
		
		Return;
		
	EndIf;
	
	SettlementsAmount = ClosingResult;
	CurrentRow = AdditionalParameters.CurrentRow;
	
	AddAndCalculateAdvanceRow(SettlementsAmount, CurrentRow);
	
EndProcedure // OpenPricesAndCurrencyFormEnd()

#EndRegion