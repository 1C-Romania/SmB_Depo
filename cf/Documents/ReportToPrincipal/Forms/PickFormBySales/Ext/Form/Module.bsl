
//////////////////////////////////////////////////////////////////////////////// 
// OVERALL PROCEDURES AND FUNCTIONS

// Procedure fills inventory table.
//
&AtServer
Procedure FillInventoryTable()
	
	Query = New Query();
	Query.SetParameter("Company",		FilterCompany);
	Query.SetParameter("Counterparty",			FilterCounterparty);
	Query.SetParameter("Contract",			SelectionContract);
	Query.SetParameter("SettlementsCurrency",		SelectionContract.SettlementsCurrency);
	Query.SetParameter("DocumentCurrency",	DocumentCurrency);
	Query.SetParameter("CounterpartyPriceKind",	CounterpartyPriceKind);
	Query.SetParameter("PriceKindCurrency",		CounterpartyPriceKind.PriceCurrency);
	Query.SetParameter("AccountingCurrency",		Constants.AccountingCurrency.Get());
	
	Query.SetParameter("BeginOfPeriod",		BegOfDay(FilterStartDate));
	Query.SetParameter("EndOfPeriod",		EndOfDay(FilterEndDate));
	
	Query.Text = 
	"SELECT
	|	SalesTurnovers.ProductsAndServices AS ProductsAndServices,
	|	SalesTurnovers.Characteristic AS Characteristic,
	|	SalesTurnovers.Batch AS Batch,
	|	SalesTurnovers.CustomerOrder,
	|	CASE
	|		WHEN VALUETYPE(SalesTurnovers.Document) = Type(Document.CustomerInvoice)
	|				OR VALUETYPE(SalesTurnovers.Document) = Type(Document.CustomerOrder)
	|			THEN SalesTurnovers.Document.Counterparty
	|	END AS Customer,
	|	CASE
	|		WHEN VALUETYPE(SalesTurnovers.Document) = Type(Document.CustomerInvoice)
	|			THEN SalesTurnovers.Document.Date
	|		WHEN VALUETYPE(SalesTurnovers.Document) = Type(Document.CustomerOrder)
	|			THEN SalesTurnovers.Document.Finish
	|	END AS DateOfSale,
	|	SalesTurnovers.QuantityTurnover AS Quantity,
	|	SalesTurnovers.QuantityTurnover AS Balance,
	|	CASE
	|		WHEN SalesTurnovers.QuantityTurnover > 0
	|			THEN CASE
	|					WHEN &DocumentCurrency = &AccountingCurrency
	|						THEN SalesTurnovers.AmountTurnover / SalesTurnovers.QuantityTurnover
	|					ELSE ISNULL(SalesTurnovers.AmountTurnover * AccountingCurrencyRate.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * AccountingCurrencyRate.Multiplicity), 0) / SalesTurnovers.QuantityTurnover
	|				END
	|		ELSE 0
	|	END AS Price,
	|	CASE
	|		WHEN SalesTurnovers.QuantityTurnover > 0
	|			THEN CASE
	|					WHEN &DocumentCurrency = &AccountingCurrency
	|						THEN SalesTurnovers.AmountTurnover
	|					ELSE ISNULL(SalesTurnovers.AmountTurnover * AccountingCurrencyRate.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * AccountingCurrencyRate.Multiplicity), 0)
	|				END
	|		ELSE 0
	|	END AS Amount,
	|	ISNULL(CASE
	|			WHEN &DocumentCurrency = &PriceKindCurrency
	|				THEN FixedReceiptPrices.Price
	|			ELSE FixedReceiptPrices.Price * PriceKindCurrencyRate.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * PriceKindCurrencyRate.Multiplicity)
	|		END, CASE
	|			WHEN InventoryReceivedBalances.QuantityBalance > 0
	|				THEN CASE
	|						WHEN &DocumentCurrency = &SettlementsCurrency
	|							THEN InventoryReceivedBalances.SettlementsAmountBalance / InventoryReceivedBalances.QuantityBalance
	|						ELSE ISNULL(InventoryReceivedBalances.SettlementsAmountBalance * SettlementsCurrencyRate.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * SettlementsCurrencyRate.Multiplicity), 0) / InventoryReceivedBalances.QuantityBalance
	|					END
	|			ELSE 0
	|		END) AS ReceiptPrice,
	|	InventoryReceivedBalances.Order AS PurchaseOrder
	|FROM
	|	AccumulationRegister.Sales.Turnovers(
	|			&BeginOfPeriod,
	|			&EndOfPeriod,
	|			,
	|			Company = &Company
	|				AND Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|				AND Batch.BatchOwner = &Counterparty) AS SalesTurnovers
	|		LEFT JOIN AccumulationRegister.InventoryReceived.Balance(
	|				&EndOfPeriod,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND Contract = &Contract
	|					AND ReceptionTransmissionType = VALUE(Enum.ProductsReceiptTransferTypes.ReceiptFromPrincipal)) AS InventoryReceivedBalances
	|		ON (InventoryReceivedBalances.ProductsAndServices = SalesTurnovers.ProductsAndServices)
	|			AND (InventoryReceivedBalances.Characteristic = SalesTurnovers.Characteristic)
	|			AND (InventoryReceivedBalances.Batch = SalesTurnovers.Batch)
	|		LEFT JOIN InformationRegister.CounterpartyProductsAndServicesPrices.SliceLast(
	|				&EndOfPeriod,
	|				CounterpartyPriceKind = &CounterpartyPriceKind
	|					AND Actuality) AS FixedReceiptPrices
	|		ON (FixedReceiptPrices.ProductsAndServices = SalesTurnovers.ProductsAndServices)
	|			AND (FixedReceiptPrices.Characteristic = SalesTurnovers.Characteristic)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&EndOfPeriod, Currency = &SettlementsCurrency) AS SettlementsCurrencyRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&EndOfPeriod, Currency = &DocumentCurrency) AS DocumentCurrencyRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&EndOfPeriod, Currency = &AccountingCurrency) AS AccountingCurrencyRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&EndOfPeriod, Currency = &PriceKindCurrency) AS PriceKindCurrencyRate
	|		ON (TRUE)
	|WHERE
	|	SalesTurnovers.QuantityTurnover > 0
	|
	|ORDER BY
	|	ProductsAndServices,
	|	Characteristic,
	|	Batch";
	
	InventoryTable.Load(Query.Execute().Unload());
	
EndProcedure // FillInventoryTable()

// Function places picking results into storage
//
&AtServer
Function PlaceInventoryToStorage()
	
	Inventory = InventoryTable.Unload(, "Selected, ProductsAndServices, Characteristic, Batch, CustomerOrder, PurchaseOrder, Customer, SaleDate, Quantity, Balance, Price, Amount, DeliveryPrice");
	
	RowToDeleteArray = New Array;
	For Each StringInventory IN Inventory Do
		
		If Not StringInventory.Selected Then
			RowToDeleteArray.Add(StringInventory);
		EndIf;
		
	EndDo;
	
	For Each LineNumber IN RowToDeleteArray Do
		Inventory.Delete(LineNumber);
	EndDo;
	
	InventoryAddressInStorage = PutToTempStorage(Inventory, UUID);
	
	Return InventoryAddressInStorage;
	
EndFunction // PlaceInventoryToStorage()

// Procedure fills the period table.
//
Procedure FillPeriodRetail()
	
	Query = New Query();
	Query.Text = 
	"SELECT TOP 1
	|	ReportToPrincipal.Date AS Date
	|FROM
	|	Document.ReportToPrincipal AS ReportToPrincipal
	|WHERE
	|	ReportToPrincipal.Posted
	|	AND ReportToPrincipal.Company = &Company
	|	AND ReportToPrincipal.Counterparty = &Counterparty
	|	AND ReportToPrincipal.Contract = &Contract
	|	AND ReportToPrincipal.Date < &DocumentDate
	|	AND ReportToPrincipal.Ref <> &Ref
	|
	|ORDER BY
	|	Date DESC";
	
	Query.SetParameter("Company",	Company);
	Query.SetParameter("Counterparty",		FilterCounterparty);
	Query.SetParameter("Contract",		SelectionContract);
	Query.SetParameter("Ref",			CurrentDocument);
	Query.SetParameter("DocumentDate",	EndOfDay(FilterEndDate));
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		FilterStartDate = Date('00010101');
	Else
		Selection = Result.Select();
		Selection.Next();
		FilterStartDate = Selection.Date;
	EndIf;
	
EndProcedure // FillSalePeriod()

//////////////////////////////////////////////////////////////////////////////// 
// COMMAND HANDLERS

// Procedure - handler of command SetInterval.
//
&AtClient
Procedure SetInterval(Command)
	
	Dialog = New StandardPeriodEditDialog();
	Dialog.Period.StartDate = FilterStartDate;
	Dialog.Period.EndDate = FilterEndDate;
	
	Dialog.Show(New NotifyDescription("SetIntervalEnd", ThisObject, New Structure("Dialog", Dialog)));
	
EndProcedure

&AtClient
Procedure SetIntervalEnd(Result, AdditionalParameters) Export
	
	Dialog = AdditionalParameters.Dialog;
	
	If ValueIsFilled(Result) Then
		FilterStartDate = Dialog.Period.StartDate;
		FilterEndDate = Dialog.Period.EndDate;
		FillInventoryTable();
	EndIf;
	
EndProcedure // SetInterval()

// Procedure - command handler SelectStrings.
//
&AtClient
Procedure ChooseStringsExecute()

	For Each TabularSectionRow IN InventoryTable Do
		
		TabularSectionRow.Selected = True;
		
	EndDo;
	
EndProcedure // SelectStringsExecute()

// Procedure - command handler ExcludeStrings.
//
&AtClient
Procedure ExcludeStringsExecute()

	For Each TabularSectionRow IN InventoryTable Do
		
		TabularSectionRow.Selected = False
		
	EndDo;
	
EndProcedure // ExcludeStringsExecute()

// Procedure - command handler ChooseSelected.
//
&AtClient
Procedure ChooseHighlightedLines(Command)
	
	RowArray = Items.InventoryTable.SelectedRows;
	For Each LineNumber IN RowArray Do
		
		TabularSectionRow = InventoryTable.FindByID(LineNumber);
		If TabularSectionRow <> Undefined Then
			TabularSectionRow.Selected = True;
		EndIf;
		
	EndDo;
	
EndProcedure // SelectHighlightedStrings()

// Procedure - command handler ExcludeSelected.
//
&AtClient
Procedure ExcludeSelectedRows(Command)
	
	RowArray = Items.InventoryTable.SelectedRows;
	For Each LineNumber IN RowArray Do
		
		TabularSectionRow = InventoryTable.FindByID(LineNumber);
		If TabularSectionRow <> Undefined Then
			TabularSectionRow.Selected = False;
		EndIf;
		
	EndDo;
	
EndProcedure // ExcludeSelectedRows()

// Procedure - command handler TransferToDocument.
//
&AtClient
Procedure MoveIntoDocumentExecute()
	
	InventoryAddressInStorage = PlaceInventoryToStorage();
	NotifyChoice(InventoryAddressInStorage);
	
EndProcedure // MoveIntoDocumentExecute()

//////////////////////////////////////////////////////////////////////////////// 
// FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FilterCompany	= Parameters.Counterparty;
	Company			= Parameters.Company;
	FilterCounterparty 	= Parameters.Counterparty;
	SelectionContract 		= Parameters.Contract;
	DocumentCurrency 	= Parameters.DocumentCurrency;
	CounterpartyPriceKind 	= Parameters.CounterpartyPriceKind;
	CurrentDocument 	= Parameters.CurrentDocument;
	FilterEndDate 	= Parameters.DocumentDate;
	
	FillPeriodRetail();
	
	FillInventoryTable();
	
EndProcedure // OnCreateAtServer()

//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS OF FORM ATTRIBUTES

// Procedure - event handler OnChange of the field FilterStartDate.
//
&AtClient
Procedure FilterBeginningDateOnChange(Item)
	
	FillInventoryTable();
	
EndProcedure // FilterStartDateOnChange()

// Procedure - event handler OnChange of the field FilterEndDate.
//
&AtClient
Procedure FilterEndingDateOnChange(Item)
	
	FillInventoryTable();
	
EndProcedure // FilterEndDateOnChange()

// Procedure - event handler Table part selection InventoryTable.
//
&AtClient
Procedure InventoryTableChoice(Item, SelectedRow, Field, StandardProcessing)
	
	If Items.InventoryTable.CurrentData <> Undefined Then
		If Field.Name = "InventoryTableCustomerOrder" Then
			ShowValue(Undefined, Items.InventoryTable.CurrentData.CustomerOrder);
		EndIf;
	EndIf;
	
EndProcedure // InventoryTableChoice()

// Procedure - event handler OnChange of field Quantity of tabular section InventoryTable.
//
&AtClient
Procedure InventoryTableQuantityOnChange(Item)
	
	TabularSectionRow = Items.InventoryTable.CurrentData;
	TabularSectionRow.Selected = (TabularSectionRow.Quantity <> 0);
	TabularSectionRow.Amount = TabularSectionRow.Price * TabularSectionRow.Quantity;
	
EndProcedure // InventoryTableQuantityOnChange()
