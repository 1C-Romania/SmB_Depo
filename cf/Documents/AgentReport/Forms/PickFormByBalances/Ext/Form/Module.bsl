
//////////////////////////////////////////////////////////////////////////////// 
// OVERALL PROCEDURES AND FUNCTIONS

// Procedure fills inventory table.
//
&AtServer
Procedure FillInventoryTable()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	InventoryTransferredBalances.ProductsAndServices AS ProductsAndServices,
	|	CAST(InventoryTransferredBalances.ProductsAndServices.Description AS String(50)) AS ProductsAndServicesDescription,
	|	InventoryTransferredBalances.Characteristic AS Characteristic,
	|	InventoryTransferredBalances.Batch AS Batch,
	|	InventoryTransferredBalances.Order AS CustomerOrder,
	|	SUM(InventoryTransferredBalances.QuantityBalance) AS Quantity,
	|	SUM(InventoryTransferredBalances.QuantityBalance) AS Balance,
	|	SUM(CASE
	|			WHEN &DocumentCurrency = &SettlementsCurrency
	|				THEN InventoryTransferredBalances.SettlementsAmountBalance
	|			ELSE ISNULL(InventoryTransferredBalances.SettlementsAmountBalance * SettlementsCurrencyRate.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * SettlementsCurrencyRate.Multiplicity), 0)
	|		END) AS SettlementsAmount
	|FROM
	|	AccumulationRegister.InventoryTransferred.Balance(
	|			,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND Contract = &Contract
	|				AND ReceptionTransmissionType = VALUE(Enum.ProductsReceiptTransferTypes.TransferToAgent)) AS InventoryTransferredBalances,
	|	InformationRegister.CurrencyRates.SliceLast(&ProcessingDate, Currency = &SettlementsCurrency) AS SettlementsCurrencyRate,
	|	InformationRegister.CurrencyRates.SliceLast(&ProcessingDate, Currency = &DocumentCurrency) AS DocumentCurrencyRate
	|
	|GROUP BY
	|	InventoryTransferredBalances.Order,
	|	InventoryTransferredBalances.ProductsAndServices,
	|	InventoryTransferredBalances.Characteristic,
	|	InventoryTransferredBalances.Batch,
	|	CAST(InventoryTransferredBalances.ProductsAndServices.Description AS String(50))
	|
	|ORDER BY
	|	ProductsAndServicesDescription";
	
	Query.SetParameter("Company", FilterCompany);
	Query.SetParameter("Counterparty", FilterCounterparty);
	Query.SetParameter("Contract", SelectionContract);
	Query.SetParameter("SettlementsCurrency", SelectionContract.SettlementsCurrency);
	Query.SetParameter("DocumentCurrency", DocumentCurrency);
	Query.SetParameter("ProcessingDate", DocumentDate);
	
	InventoryTable.Load(Query.Execute().Unload());
	
EndProcedure // FillInventoryTable()

// Function places picking results into storage
//
&AtServer
Function PlaceInventoryToStorage()
	
	Inventory = InventoryTable.Unload(, "ItisSelected, ProductsAndServices, Characteristic, Batch, CustomerOrder, Quantity, Balance, SettlementsAmount");
	
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

//////////////////////////////////////////////////////////////////////////////// 
// COMMAND HANDLERS

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
	
	FilterCompany = Parameters.Company;
	FilterCounterparty = Parameters.Counterparty;
	SelectionContract = Parameters.Contract;
	DocumentCurrency = Parameters.DocumentCurrency;
	DocumentDate = Parameters.DocumentDate;
	
	FillInventoryTable();
	
EndProcedure // OnCreateAtServer()

//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS OF FORM ATTRIBUTES

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
	
EndProcedure // InventoryTableQuantityOnChange()














