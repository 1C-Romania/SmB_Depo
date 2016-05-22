// Procedure checks the correctness of the form attributes filling.
//
&AtClient
Procedure CheckFillOfFormAttributes(Cancel)
	
	// Attributes filling check.
	LineNumber = 0;
	For Each RowPrepayment IN Prepayment Do
		LineNumber = LineNumber + 1;
		If CurrencyTransactionsAccounting
		AND Not ValueIsFilled(RowPrepayment.ExchangeRate) Then
			Message = New UserMessage();
			Message.Text = NStr("en = 'Column ""Exchange rate"" is not filled in the row. '")
				+ String(LineNumber)
				+ NStr("en = ' of ""Accounts"").'");
			Message.Field = "Document";
			Message.Message();
			Cancel = True;
		EndIf;
		If CurrencyTransactionsAccounting
		AND Not ValueIsFilled(RowPrepayment.Multiplicity) Then
			Message = New UserMessage();
			Message.Text = NStr("en = 'Column ""Multiplicity"" is not filled in the row. '")
				+ String(LineNumber)
				+ NStr("en = ' of ""Accounts"").'");
			Message.Field = "Document";
			Message.Message();
			Cancel = True;
		EndIf;
		If Not ValueIsFilled(RowPrepayment.SettlementsAmount) Then
			Message = New UserMessage();
			Message.Text = NStr("en = 'Field ""Settlements amount"" is not filled in row '")
				+ String(LineNumber)
				+ NStr("en = ' of ""Accounts"").'");
			Message.Field = "Document";
			Message.Message();
			Cancel = True;
		EndIf;
		If CurrencyTransactionsAccounting
		AND Not ValueIsFilled(RowPrepayment.PaymentAmount) Then
			Message = New UserMessage();
			Message.Text = NStr("en = 'Field ""Payment amount"" is required (row # '")
				+ String(LineNumber)
				+ NStr("en = ' of ""Accounts"").'");
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
	
	PaymentAmountTotal = 0;
	SettlementsAmountTotal = 0;
	
	For Each CurRow IN Prepayment Do
		PaymentAmountTotal = PaymentAmountTotal + CurRow.PaymentAmount;
		SettlementsAmountTotal = SettlementsAmountTotal + CurRow.SettlementsAmount;
	EndDo;
	
EndProcedure // CalculateAmountsTotal()

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Counterparty = Parameters.Counterparty;
	Counterparty = Parameters.Counterparty;
	Contract = Parameters.Contract;
	ExchangeRate = Parameters.ExchangeRate;
	Multiplicity = Parameters.Multiplicity;
	DocumentCurrency = Parameters.DocumentCurrency;
	SettlementsCurrency = Parameters.Contract.SettlementsCurrency;
	IsOrder = Parameters.IsOrder;
	OrderInHeader = Parameters.OrderInHeader;
	Ref = Parameters.Ref;
	Date = Parameters.Date;
	DocumentAmount = Parameters.DocumentAmount;
	CurrencyTransactionsAccounting = Constants.FunctionalCurrencyTransactionsAccounting.Get();
	AddressPrepaymentInStorage = Parameters.AddressPrepaymentInStorage;
	ThisSelection = Parameters.Pick;
	
	Items.PrepaymentDocument.Visible = Counterparty.DoOperationsByDocuments;
	Items.PrepaymentOrder.Visible = Counterparty.DoOperationsByOrders;
	Items.AdvancesListDocument.Visible = Counterparty.DoOperationsByDocuments;
	Items.AdvancesListOrder.Visible = Counterparty.DoOperationsByOrders;
	
	If OrderInHeader AND Counterparty.DoOperationsByOrders Then // order in header
		Order = Parameters.Order;
		Items.PrepaymentOrder.Visible = False;
		NewRow = OrdersList.Add();
		NewRow.Order = Parameters.Order;
		NewRow.Total = Parameters.DocumentAmount;
		NewRow.TotalCalc = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
			Parameters.DocumentAmount,
			?(SettlementsCurrency = DocumentCurrency, ExchangeRate, 1),
			ExchangeRate,
			?(SettlementsCurrency = DocumentCurrency, Multiplicity, 1),
			Multiplicity
		);
	ElsIf IsOrder AND Counterparty.DoOperationsByOrders Then // order in tabular section
		Order = Documents.PurchaseOrder.EmptyRef();
		If Parameters.Property("Order")
		   AND TypeOf(Parameters.Order) = Type("Array") Then
			OrdersTable = OrdersList.Unload();
			For Each ArrayElement IN Parameters.Order Do
				OrdersRow = OrdersTable.Add();
				OrdersRow.Order = ArrayElement.Order;
				OrdersRow.Total = ArrayElement.Total;
				OrdersRow.TotalCalc = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
					ArrayElement.Total,
					?(SettlementsCurrency = DocumentCurrency, ExchangeRate, 1),
					ExchangeRate,
					?(SettlementsCurrency = DocumentCurrency, Multiplicity, 1),
					Multiplicity
				);
			EndDo;
			OrdersTable.GroupBy("Order", "Total, TotalCalc");
			OrdersTable.Sort("Order Asc");
			OrdersList.Load(OrdersTable);
		EndIf;
	Else // no order
		Order = Documents.PurchaseOrder.EmptyRef();
		NewRow = OrdersList.Add();
		NewRow.Order = Documents.PurchaseOrder.EmptyRef();
		NewRow.Total = Parameters.DocumentAmount;
		NewRow.TotalCalc = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
			Parameters.DocumentAmount,
			?(SettlementsCurrency = DocumentCurrency, ExchangeRate, 1),
			ExchangeRate,
			?(SettlementsCurrency = DocumentCurrency, Multiplicity, 1),
			Multiplicity
		);
	EndIf;
	
	If Not Parameters.Pick Then
		Items.Header.Visible = False;
		Items.Advances.Visible = False;
		Items.PrepaymentAutoFill.Visible = False;
		Title = "Prepayment recovery";
	EndIf;
	
	Items.PrepaymentDocument.ReadOnly = Parameters.Pick;
	Items.PrepaymentOrder.ReadOnly = Parameters.Pick;
	
	Items.PrepaymentAdd.Visible = Not Parameters.Pick;
	Items.PrepaymentCopy.Visible = Not Parameters.Pick;
	
	Items.PrepaymentDocument.TypeRestriction = Ref.Metadata().TabularSections.Prepayment.Attributes.Document.Type;
	
	If IsOrder Then
		Items.PrepaymentOrder.TypeRestriction = Ref.Metadata().TabularSections.Prepayment.Attributes.Order.Type;
	EndIf;
	
	NationalCurrency = Constants.NationalCurrency.Get();
	StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", NationalCurrency));
	RateNationalCurrency = StructureByCurrency.ExchangeRate;
	RepetitionNationalCurrency = StructureByCurrency.Multiplicity;
	
	AccountingCurrency = Constants.AccountingCurrency.Get();
	StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", AccountingCurrency));
	RateAccountingCurrency = StructureByCurrency.ExchangeRate;
	AccountingCurrencyMultiplicity = StructureByCurrency.Multiplicity;
	
	If IsOrder Then
		RowOfColumns = "
			|Document,
			|Order,
			|PaymentAmount,
			|ExchangeRate,
			|Multiplicity,
			|SettlementsAmount";
	Else
		RowOfColumns = "
			|Document, 
			|PaymentAmount,
			|ExchangeRate,
			|Multiplicity,
			|SettlementsAmount";
		Items.Prepayment.ChildItems.PrepaymentOrder.Visible = False;
	EndIf;
	
	For Each CurRow IN Prepayment Do // for correct dragging
		If Not ValueIsFilled(CurRow.Order) Then
			CurRow.Order = Documents.PurchaseOrder.EmptyRef();
		EndIf;
	EndDo;
	
	Prepayment.Load(GetFromTempStorage(AddressPrepaymentInStorage));
	
	FillAdvances();
	
EndProcedure

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
	
	FillAdvances();
	
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
	
	PrepaymentInStorage = Prepayment.Unload(, RowOfColumns);
	PutToTempStorage(PrepaymentInStorage, AddressPrepaymentInStorage);
	
EndProcedure

// Receives data set from server for procedure PrepaymentDocumentOnChange.
//
&AtServerNoContext
Function GetDataDocumentOnChange(Document)
	
	StructureData = New Structure();
	
	If TypeOf(Document) = Type("DocumentRef.ExpenseReport") Then
		StructureData.Insert("SettlementsAmount", Document.Payments.Total("SettlementsAmount"));
	Else
		StructureData.Insert("SettlementsAmount", Document.PaymentDetails.Total("SettlementsAmount"));
	EndIf;
	
	Return StructureData;
	
EndFunction // GetDataDocumentOntChange()

// Fills to offset by advance string.
//
&AtClient
Procedure ChoiceAdvance(CurrentRow)
	
	SettlementsAmount = CurrentRow.SettlementsAmount;
	If AskAmount Then
		ShowInputNumber(New NotifyDescription("AdvanceChoiceEnd", ThisObject, New Structure("CurrentRow, SettlementsAmount.", CurrentRow, SettlementsAmount)), SettlementsAmount, "Enter the amount of settlements", , );
        Return;
	EndIf;
	
	AdvanceChoiceFragment(SettlementsAmount, CurrentRow);
EndProcedure

&AtClient
Procedure AdvanceChoiceEnd(Result, AdditionalParameters) Export
    
    CurrentRow = AdditionalParameters.CurrentRow;
    SettlementsAmount = ?(Result = Undefined, AdditionalParameters.SettlementsAmount, Result);
    
    
    If Not (Result <> Undefined) Then
        Return;
    EndIf;
    
    AdvanceChoiceFragment(SettlementsAmount, CurrentRow);

EndProcedure

&AtClient
Procedure AdvanceChoiceFragment(SettlementsAmount, Val CurrentRow)
    
    Var NewRow, Rows, SearchStructure;
    
    SearchStructure = New Structure("Document, Order", CurrentRow.Document, CurrentRow.Order);
    Rows = Prepayment.FindRows(SearchStructure);
    
    If Rows.Count() > 0 Then
        NewRow = Rows[0];
        SettlementsAmount = SettlementsAmount + NewRow.SettlementsAmount;
    Else
        NewRow = Prepayment.Add();
    EndIf;
    
    NewRow.Document = CurrentRow.Document;
    NewRow.Order = CurrentRow.Order;
    NewRow.SettlementsAmount = SettlementsAmount;
    
    NewRow.ExchangeRate = ?(NewRow.ExchangeRate = 0, CurrentRow.ExchangeRate, NewRow.ExchangeRate);
    NewRow.Multiplicity = ?(NewRow.Multiplicity = 0, CurrentRow.Multiplicity, NewRow.Multiplicity);
    
    If Not CurrencyTransactionsAccounting Then
        NewRow.PaymentAmount = CurrentRow.SettlementsAmount;
    Else
        If SettlementsAmount = CurrentRow.SettlementsAmount
            AND DocumentCurrency = AccountingCurrency Then
            NewRow.PaymentAmount = CurrentRow.PaymentAmount;
        Else
            NewRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
            NewRow.SettlementsAmount,
            NewRow.ExchangeRate,
            ?(DocumentCurrency = NationalCurrency, RateNationalCurrency, ExchangeRate),
            NewRow.Multiplicity,
            ?(DocumentCurrency = NationalCurrency, RepetitionNationalCurrency, Multiplicity)
            );
        EndIf;
    EndIf;
    
    Items.Prepayment.CurrentRow = NewRow.GetID();
    
    CalculateAmountsTotal();
    FillAdvances();

EndProcedure

// The procedure places selection results into pick
//
&AtClient
Procedure AdvancesListValueChoice(Item, StandardProcessing, Value)
	
	StandardProcessing = False;
	CurrentRow = Item.CurrentData;
	ChoiceAdvance(CurrentRow);
	
EndProcedure // AdvancesListValueChoice()

// Procedure - handler of event OnStartEdit of tablular section Prepayment.
//
&AtClient
Procedure PrepaymentOnStartEdit(Item, NewRow, Copy)
	
	If NewRow
	   AND OrderInHeader
	   AND ValueIsFilled(Order) Then
		Item.CurrentData.Order = Order;
	EndIf;
	
	If Copy Then
		CalculateAmountsTotal();
		FillAdvances();
	EndIf;
	
EndProcedure // PrepaymentOnStartEdit()

// Procedure - handler of event OnChange of tabular section
// Prepayment input field SettlementsAmount. Calculates the amount of the payment.
//
&AtClient
Procedure PrepaymentAccountsAmountOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	TabularSectionRow.ExchangeRate =
		?(TabularSectionRow.ExchangeRate = 0,
			?(ExchangeRate = 0,
			1,
			ExchangeRate),
		TabularSectionRow.ExchangeRate);
			
	TabularSectionRow.Multiplicity =
		?(TabularSectionRow.Multiplicity = 0,
			?(Multiplicity = 0,
			1,
			Multiplicity),
		TabularSectionRow.Multiplicity);
	
	TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		TabularSectionRow.ExchangeRate,
		?(DocumentCurrency = NationalCurrency, RateNationalCurrency, ExchangeRate),
		TabularSectionRow.Multiplicity,
		?(DocumentCurrency = NationalCurrency,RepetitionNationalCurrency, Multiplicity)
	);
	
EndProcedure

// Procedure - handler of event OnChange of tabular section
// Prepayment input field ExchangeRate. Calculates the amount of the payment.
//
&AtClient
Procedure PrepaymentRateOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	TabularSectionRow.ExchangeRate      = ?(TabularSectionRow.ExchangeRate      = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		TabularSectionRow.ExchangeRate,
		?(DocumentCurrency = NationalCurrency, RateNationalCurrency, ExchangeRate),
		TabularSectionRow.Multiplicity,
		?(DocumentCurrency = NationalCurrency,RepetitionNationalCurrency, Multiplicity)
	);
	
EndProcedure

// Procedure - handler of event OnChange of tabular section
// Prepayment input field Multiplicity. Calculates the amount of the payment.
//
&AtClient
Procedure PrepaymentRepetitionOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	TabularSectionRow.ExchangeRate      = ?(TabularSectionRow.ExchangeRate      = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		TabularSectionRow.ExchangeRate,
		?(DocumentCurrency = NationalCurrency, RateNationalCurrency, ExchangeRate),
		TabularSectionRow.Multiplicity,
		?(DocumentCurrency = NationalCurrency,RepetitionNationalCurrency, Multiplicity)
	);
	
EndProcedure

// Procedure - handler of event OnChange of tabular section
// Prepayment input field PaymentAmount. Calculates the rate and multiplicity.
//
&AtClient
Procedure PrepaymentPaymentAmountOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;

	TabularSectionRow.ExchangeRate      = ?(TabularSectionRow.ExchangeRate      = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);

	TabularSectionRow.Multiplicity = 1;

	TabularSectionRow.ExchangeRate =
		?(TabularSectionRow.SettlementsAmount = 0,
			1,
			TabularSectionRow.PaymentAmount
		  / TabularSectionRow.SettlementsAmount
		  * ?(DocumentCurrency = NationalCurrency,
			RateNationalCurrency,
		ExchangeRate));   

EndProcedure

// Procedure - handler of event OnChange of tabular section
// Prepayment input field Document.
//
&AtClient
Procedure PrepaymentDocumentOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	If ValueIsFilled(TabularSectionRow.Document) Then
		StructureData = GetDataDocumentOnChange(TabularSectionRow.Document);
		
		TabularSectionRow.SettlementsAmount = StructureData.SettlementsAmount;
		
		TabularSectionRow.ExchangeRate = 
			?(TabularSectionRow.ExchangeRate = 0,
				?(ExchangeRate = 0,
				1,
				ExchangeRate),
			TabularSectionRow.ExchangeRate);
			
		TabularSectionRow.Multiplicity =
			?(TabularSectionRow.Multiplicity = 0,
				?(Multiplicity = 0,
				1,
				Multiplicity),
			TabularSectionRow.Multiplicity);
										
		TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
			TabularSectionRow.SettlementsAmount,
			TabularSectionRow.ExchangeRate,
			?(DocumentCurrency = NationalCurrency, RateNationalCurrency, ExchangeRate),
  			TabularSectionRow.Multiplicity,
			?(DocumentCurrency = NationalCurrency,RepetitionNationalCurrency, Multiplicity));  
		
	EndIf;
	
EndProcedure // PrepaymentDocumentOnChange()

// Procedure - handler of event StartDrag of list AdvancesList.
//
&AtClient
Procedure AdvancesListDragStart(Item, DragParameters, StandardProcessing)
	
	CurrentData = Item.CurrentData;
	Structure = New Structure;
	Structure.Insert("Document", CurrentData.Document);
	Structure.Insert("Order", CurrentData.Order);
	Structure.Insert("SettlementsAmount", CurrentData.SettlementsAmount);
	Structure.Insert("ExchangeRate", CurrentData.ExchangeRate);
	Structure.Insert("Multiplicity", CurrentData.Multiplicity);
	
	DragParameters.Value = Structure;
	
	DragParameters.AllowedActions = DragAllowedActions.Copy;
	
EndProcedure // AdvancesListDragStart()

// Procedure - handler of list Prepayment event DragCheck.
//
&AtClient
Procedure PrepaymentDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	DragParameters.Action = DragAction.Copy;
	
EndProcedure // PrepaymentDragCheck()

// Procedure - handler of list Prepayment event Drag.
//
&AtClient
Procedure PrepaymentDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	CurrentRow = DragParameters.Value;
	ChoiceAdvance(CurrentRow);
	
EndProcedure // PrepaymentDrag()

// Procedure - handler of list Prepayment event OnChange.
//
&AtClient
Procedure PrepaymentOnChange(Item)
	
	CalculateAmountsTotal();
	FillAdvances();
	
EndProcedure // PrepaymentOnChange()

// Procedure fills prepayment.
//
&AtServer
Procedure FillPrepayment()
	
	OrdersTable = OrdersList.Unload();
	
	// Filling of prepayment.
	Query = New Query;
	QueryText =
	"SELECT ALLOWED
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.DocumentDate AS DocumentDate,
	|	AccountsPayableBalances.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	SUM(AccountsPayableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsPayableBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableAccountsPayableBalances
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.Contract AS Contract,
	|		AccountsPayableBalances.Document AS Document,
	|		AccountsPayableBalances.Document.Date AS DocumentDate,
	|		AccountsPayableBalances.Order AS Order,
	|		ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AmountBalance,
	|		ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsPayable.Balance(
	|				,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND Contract = &Contract
	|					// TextOrderInHeader
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsPayableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsVendorSettlements.Contract,
	|		DocumentRegisterRecordsVendorSettlements.Document,
	|		DocumentRegisterRecordsVendorSettlements.Document.Date,
	|		DocumentRegisterRecordsVendorSettlements.Order,
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
	|		AND DocumentRegisterRecordsVendorSettlements.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsPayableBalances
	|
	|GROUP BY
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.DocumentDate,
	|	AccountsPayableBalances.Contract.SettlementsCurrency
	|
	|HAVING
	|	SUM(AccountsPayableBalances.AmountCurBalance) < 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.DocumentDate AS DocumentDate,
	|	AccountsPayableBalances.SettlementsCurrency AS SettlementsCurrency,
	|	-SUM(AccountsPayableBalances.AccountingAmount) AS AccountingAmount,
	|	-SUM(AccountsPayableBalances.SettlementsAmount) AS SettlementsAmount,
	|	-SUM(AccountsPayableBalances.PaymentAmount) AS PaymentAmount,
	|	SUM(AccountsPayableBalances.AccountingAmount / CASE
	|			WHEN ISNULL(AccountsPayableBalances.SettlementsAmount, 0) <> 0
	|				THEN AccountsPayableBalances.SettlementsAmount
	|			ELSE 1
	|		END) * (SettlementsCurrencyCurrencyRatesRate / SettlementsCurrencyCurrencyRatesMultiplicity) AS ExchangeRate,
	|	1 AS Multiplicity,
	|	AccountsPayableBalances.DocumentCurrencyCurrencyRatesRate AS DocumentCurrencyCurrencyRatesRate,
	|	AccountsPayableBalances.DocumentCurrencyCurrencyRatesMultiplicity AS DocumentCurrencyCurrencyRatesMultiplicity
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.SettlementsCurrency AS SettlementsCurrency,
	|		AccountsPayableBalances.Document AS Document,
	|		AccountsPayableBalances.DocumentDate AS DocumentDate,
	|		AccountsPayableBalances.Order AS Order,
	|		ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AccountingAmount,
	|		ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS SettlementsAmount,
	|		ISNULL(AccountsPayableBalances.AmountBalance, 0) * SettlementsCurrencyCurrencyRates.ExchangeRate * &MultiplicityOfDocumentCurrency / (&DocumentCurrencyRate * SettlementsCurrencyCurrencyRates.Multiplicity) AS PaymentAmount,
	|		SettlementsCurrencyCurrencyRates.ExchangeRate AS SettlementsCurrencyCurrencyRatesRate,
	|		SettlementsCurrencyCurrencyRates.Multiplicity AS SettlementsCurrencyCurrencyRatesMultiplicity,
	|		&DocumentCurrencyRate AS DocumentCurrencyCurrencyRatesRate,
	|		&MultiplicityOfDocumentCurrency AS DocumentCurrencyCurrencyRatesMultiplicity
	|	FROM
	|		TemporaryTableAccountsPayableBalances AS AccountsPayableBalances
	|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Period, Currency = &AccountingCurrency) AS SettlementsCurrencyCurrencyRates
	|			ON (TRUE)) AS AccountsPayableBalances
	|
	|GROUP BY
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.DocumentDate,
	|	AccountsPayableBalances.SettlementsCurrency,
	|	SettlementsCurrencyCurrencyRatesRate,
	|	SettlementsCurrencyCurrencyRatesMultiplicity,
	|	AccountsPayableBalances.DocumentCurrencyCurrencyRatesRate,
	|	AccountsPayableBalances.DocumentCurrencyCurrencyRatesMultiplicity
	|
	|HAVING
	|	-SUM(AccountsPayableBalances.SettlementsAmount) > 0
	|
	|ORDER BY
	|	DocumentDate";
	
	If Not Counterparty.DoOperationsByOrders Then
		QueryText = StrReplace(QueryText, "// TextOrderInHeader", "And Order = &Order");
		Query.SetParameter("Order", Documents.CustomerOrder.EmptyRef());
	ElsIf OrderInHeader
	   OR Not IsOrder Then
		QueryText = StrReplace(QueryText, "// TextOrderInHeader", "And Order = &Order");
		Query.SetParameter("Order", Order);
	Else
		QueryText = StrReplace(QueryText, "// TextOrderInHeader", "And Order IN (&OrdersArray)");
		Query.SetParameter("OrdersArray", OrdersList.Unload().UnloadColumn("Order"));
	EndIf;
	
	Query.SetParameter("Company", Counterparty);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Contract", Contract);
	Query.SetParameter("Period", Date);
	Query.SetParameter("DocumentCurrency", DocumentCurrency);
	Query.SetParameter("AccountingCurrency", AccountingCurrency);
	
	If SettlementsCurrency = DocumentCurrency Then
		Query.SetParameter("DocumentCurrencyRate", ExchangeRate);
		Query.SetParameter("MultiplicityOfDocumentCurrency", Multiplicity);
	Else
		Query.SetParameter("DocumentCurrencyRate", 1);
		Query.SetParameter("MultiplicityOfDocumentCurrency", 1);
	EndIf;
	
	Query.SetParameter("Ref", Ref);
	
	Query.Text = QueryText;
	
	Prepayment.Clear();
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	While SelectionOfQueryResult.Next() Do
		
		FoundString = OrdersTable.Find(SelectionOfQueryResult.Order, "Order");
		
		If FoundString = Undefined
		 OR FoundString.TotalCalc = 0 Then
			Continue;
		EndIf;
		
		If SelectionOfQueryResult.SettlementsAmount <= FoundString.TotalCalc Then // balance amount is less or equal than it is necessary to distribute
			
			NewRow = Prepayment.Add();
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			FoundString.TotalCalc = FoundString.TotalCalc - SelectionOfQueryResult.SettlementsAmount;
			
		Else // Balance amount is greater than it is necessary to distribute
			
			NewRow = Prepayment.Add();
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			
			NewRow.SettlementsAmount = FoundString.TotalCalc;
			NewRow.PaymentAmount = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
				NewRow.SettlementsAmount,
				SelectionOfQueryResult.ExchangeRate,
				SelectionOfQueryResult.DocumentCurrencyCurrencyRatesRate,
				SelectionOfQueryResult.Multiplicity,
				SelectionOfQueryResult.DocumentCurrencyCurrencyRatesMultiplicity
			);
			
			FoundString.TotalCalc = 0;
			
		EndIf;
		
	EndDo;
	
EndProcedure // FillPrepayment()

// Procedure - Handler of clicking the FillAutomatically button.
//
&AtClient
Procedure FillAutomatically(Command)
	
	FillPrepayment();
	CalculateAmountsTotal();
	FillAdvances();
	
EndProcedure // FillAutomatically()

// Procedure fills the advance list.
//
&AtServer
Procedure FillAdvances()
	
	Query = New Query;
	QueryText =
	"SELECT
	|	FilteredAdvances.Document AS Document,
	|	CASE
	|		WHEN Not &IsOrder
	|			THEN &Order
	|		WHEN FilteredAdvances.Order = UNDEFINED
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		ELSE FilteredAdvances.Order
	|	END AS Order,
	|	&SettlementsCurrency AS SettlementsCurrency,
	|	FilteredAdvances.SettlementsAmount AS SettlementsAmount,
	|	FilteredAdvances.PaymentAmount AS PaymentAmount
	|INTO TableFilteredAdvances
	|FROM
	|	&TableFilteredAdvances AS FilteredAdvances
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.DocumentDate AS DocumentDate,
	|	AccountsPayableBalances.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	SUM(AccountsPayableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsPayableBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableAccountsPayableBalances
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.Contract AS Contract,
	|		AccountsPayableBalances.Document AS Document,
	|		AccountsPayableBalances.Document.Date AS DocumentDate,
	|		AccountsPayableBalances.Order AS Order,
	|		ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AmountBalance,
	|		ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsPayable.Balance(
	|				,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND Contract = &Contract
	|					// TextOrderInHeader
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsPayableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsVendorSettlements.Contract,
	|		DocumentRegisterRecordsVendorSettlements.Document,
	|		DocumentRegisterRecordsVendorSettlements.Document.Date,
	|		DocumentRegisterRecordsVendorSettlements.Order,
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
	|		AND DocumentRegisterRecordsVendorSettlements.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsPayableBalances
	|
	|GROUP BY
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.DocumentDate,
	|	AccountsPayableBalances.Contract.SettlementsCurrency
	|
	|HAVING
	|	SUM(AccountsPayableBalances.AmountCurBalance) < 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.DocumentDate AS DocumentDate,
	|	AccountsPayableBalances.SettlementsCurrency AS SettlementsCurrency,
	|	-SUM(AccountsPayableBalances.AccountingAmount) AS AccountingAmount,
	|	-SUM(AccountsPayableBalances.SettlementsAmount) AS SettlementsAmount,
	|	-SUM(AccountsPayableBalances.PaymentAmount) AS PaymentAmount,
	|	SUM(AccountsPayableBalances.AccountingAmount / CASE
	|			WHEN ISNULL(AccountsPayableBalances.SettlementsAmount, 0) <> 0
	|				THEN AccountsPayableBalances.SettlementsAmount
	|			ELSE 1
	|		END) * (SettlementsCurrencyCurrencyRates.ExchangeRate / SettlementsCurrencyCurrencyRates.Multiplicity) AS ExchangeRate,
	|	1 AS Multiplicity
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.SettlementsCurrency AS SettlementsCurrency,
	|		AccountsPayableBalances.Document AS Document,
	|		AccountsPayableBalances.DocumentDate AS DocumentDate,
	|		AccountsPayableBalances.Order AS Order,
	|		ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AccountingAmount,
	|		ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS SettlementsAmount,
	|		ISNULL(AccountsPayableBalances.AmountBalance, 0) * SettlementsCurrencyCurrencyRates.ExchangeRate * DocumentCurrencyCurrencyRates.Multiplicity / (DocumentCurrencyCurrencyRates.ExchangeRate * SettlementsCurrencyCurrencyRates.Multiplicity) AS PaymentAmount
	|	FROM
	|		TemporaryTableAccountsPayableBalances AS AccountsPayableBalances
	|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Period, Currency = &DocumentCurrency) AS DocumentCurrencyCurrencyRates
	|			ON (TRUE)
	|			LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Period, Currency = &AccountingCurrency) AS SettlementsCurrencyCurrencyRates
	|			ON (TRUE)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		FilteredAdvances.SettlementsCurrency,
	|		FilteredAdvances.Document,
	|		FilteredAdvances.Document.Date,
	|		FilteredAdvances.Order,
	|		0,
	|		FilteredAdvances.SettlementsAmount,
	|		FilteredAdvances.PaymentAmount
	|	FROM
	|		TableFilteredAdvances AS FilteredAdvances) AS AccountsPayableBalances
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&Period, Currency = &AccountingCurrency) AS SettlementsCurrencyCurrencyRates
	|		ON (TRUE)
	|
	|GROUP BY
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.DocumentDate,
	|	AccountsPayableBalances.SettlementsCurrency,
	|	SettlementsCurrencyCurrencyRates.ExchangeRate,
	|	SettlementsCurrencyCurrencyRates.Multiplicity
	|
	|HAVING
	|	-SUM(AccountsPayableBalances.SettlementsAmount) > 0
	|
	|ORDER BY
	|	DocumentDate";
	
	Query.SetParameter("IsOrder", IsOrder);
	
	If Not Counterparty.DoOperationsByOrders Then
		QueryText = StrReplace(QueryText, "// TextOrderInHeader", "And Order = &Order");
		Query.SetParameter("Order", Documents.PurchaseOrder.EmptyRef());
	ElsIf OrderInHeader
	   OR Not IsOrder Then
		QueryText = StrReplace(QueryText, "// TextOrderInHeader", "And Order = &Order");
		Query.SetParameter("Order", Order);
	Else
		Query.SetParameter("Order", Documents.PurchaseOrder.EmptyRef());
		QueryText = StrReplace(QueryText, "// TextOrderInHeader", "And Order IN (&OrdersArray)");
		Query.SetParameter("OrdersArray",  OrdersList.Unload().UnloadColumn("Order"));
	EndIf;
	
	Query.Text = QueryText;
	
	Query.SetParameter("Company", Counterparty);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Contract", Contract);
	Query.SetParameter("Period", Date);
	Query.SetParameter("SettlementsCurrency", SettlementsCurrency);
	Query.SetParameter("DocumentCurrency", DocumentCurrency);
	Query.SetParameter("AccountingCurrency", AccountingCurrency);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("TableFilteredAdvances", Prepayment.Unload());
	
	QueryResult = Query.Execute();
	
	AdvancesList.Load(QueryResult.Unload());
	
EndProcedure // FillAdvances()

// Procedure prohibits to add rows if manual selection is not allowed.
//
&AtClient
Procedure PrepaymentBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If ThisSelection Then
		Cancel = True;
	EndIf;
	
EndProcedure // PrepaymentBeforeAddRow()
