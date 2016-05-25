#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF FILLING THE DOCUMENT

// Procedure for filling the document basing on Customer order.
//
Procedure FillUsingCustomerOrder(FillingData) Export
	
	// Header filling.
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData, New Structure("Company, Ref, OperationKind, Start, ShipmentDate, OrderState, Closed, Posted"));
	
	Documents.CustomerOrder.CheckAbilityOfEnteringByCustomerOrder(FillingData, AttributeValues);
	
	Company = AttributeValues.Company;
	CustomerOrder = AttributeValues.Ref;
	If AttributeValues.OperationKind = Enums.OperationKindsCustomerOrder.JobOrder Then
		ReceiptDate = AttributeValues.Start;
	Else
		ReceiptDate = AttributeValues.ShipmentDate;
	EndIf;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	OrdersBalance.ProductsAndServices AS ProductsAndServices,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		OrdersBalance.ProductsAndServices AS ProductsAndServices,
	|		OrdersBalance.Characteristic AS Characteristic,
	|		OrdersBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.CustomerOrders.Balance(
	|				,
	|				CustomerOrder = &BasisDocument
	|					AND ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InventoryBalances.ProductsAndServices,
	|		InventoryBalances.Characteristic,
	|		-InventoryBalances.QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				CustomerOrder = &BasisDocument
	|					AND ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		PlacementBalances.ProductsAndServices,
	|		PlacementBalances.Characteristic,
	|		-PlacementBalances.QuantityBalance
	|	FROM
	|		AccumulationRegister.OrdersPlacement.Balance(
	|				,
	|				CustomerOrder = &BasisDocument
	|					AND ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)) AS PlacementBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsOrdersPlacement.ProductsAndServices,
	|		DocumentRegisterRecordsOrdersPlacement.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsOrdersPlacement.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN -ISNULL(DocumentRegisterRecordsOrdersPlacement.Quantity, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsOrdersPlacement.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.OrdersPlacement AS DocumentRegisterRecordsOrdersPlacement
	|	WHERE
	|		DocumentRegisterRecordsOrdersPlacement.Recorder = &Ref
	|		AND DocumentRegisterRecordsOrdersPlacement.CustomerOrder = &BasisDocument) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.ProductsAndServices,
	|	OrdersBalance.Characteristic
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(CustomerOrderInventory.LineNumber) AS LineNumber,
	|	CustomerOrderInventory.ProductsAndServices AS ProductsAndServices,
	|	CustomerOrderInventory.Characteristic AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(CustomerOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE CustomerOrderInventory.MeasurementUnit.Factor
	|	END AS Factor,
	|	CustomerOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN CustomerOrderInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
	|			THEN CustomerOrderInventory.Ref.Start
	|		ELSE CustomerOrderInventory.ShipmentDate
	|	END AS InventoryReceiptDate,
	|	CustomerOrderInventory.VATRate,
	|	SUM(CustomerOrderInventory.Quantity) AS Quantity
	|FROM
	|	Document.CustomerOrder.Inventory AS CustomerOrderInventory
	|WHERE
	|	CustomerOrderInventory.Ref = &BasisDocument
	|	AND CustomerOrderInventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|
	|GROUP BY
	|	CustomerOrderInventory.ProductsAndServices,
	|	CustomerOrderInventory.Characteristic,
	|	CustomerOrderInventory.MeasurementUnit,
	|	CustomerOrderInventory.VATRate,
	|	CASE
	|		WHEN VALUETYPE(CustomerOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE CustomerOrderInventory.MeasurementUnit.Factor
	|	END,
	|	CASE
	|		WHEN CustomerOrderInventory.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
	|			THEN CustomerOrderInventory.Ref.Start
	|		ELSE CustomerOrderInventory.ShipmentDate
	|	END
	|
	|ORDER BY
	|	LineNumber";
	
	If AttributeValues.OperationKind = Enums.OperationKindsCustomerOrder.JobOrder Then
		
		Query.Text = Query.Text + "; " +
		"SELECT
		|	OrdersBalance.ProductsAndServices AS ProductsAndServices,
		|	OrdersBalance.Characteristic AS Characteristic,
		|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
		|FROM
		|	(SELECT
		|		InventoryBalances.ProductsAndServices AS ProductsAndServices,
		|		InventoryBalances.Characteristic AS Characteristic,
		|		InventoryBalances.QuantityBalance AS QuantityBalance
		|	FROM
		|		AccumulationRegister.Inventory.Balance(
		|				,
		|				CustomerOrder = &BasisDocument
		|					AND ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)) AS InventoryBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		PlacementBalances.ProductsAndServices,
		|		PlacementBalances.Characteristic,
		|		PlacementBalances.QuantityBalance
		|	FROM
		|		AccumulationRegister.OrdersPlacement.Balance(
		|				,
		|				CustomerOrder = &BasisDocument
		|					AND ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)) AS PlacementBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecordsOrdersPlacement.ProductsAndServices,
		|		DocumentRegisterRecordsOrdersPlacement.Characteristic,
		|		CASE
		|			WHEN DocumentRegisterRecordsOrdersPlacement.RecordType = VALUE(AccumulationRecordType.Expense)
		|				THEN ISNULL(DocumentRegisterRecordsOrdersPlacement.Quantity, 0)
		|			ELSE -ISNULL(DocumentRegisterRecordsOrdersPlacement.Quantity, 0)
		|		END
		|	FROM
		|		AccumulationRegister.OrdersPlacement AS DocumentRegisterRecordsOrdersPlacement
		|	WHERE
		|		DocumentRegisterRecordsOrdersPlacement.Recorder = &Ref
		|		AND DocumentRegisterRecordsOrdersPlacement.CustomerOrder = &BasisDocument) AS OrdersBalance
		|
		|GROUP BY
		|	OrdersBalance.ProductsAndServices,
		|	OrdersBalance.Characteristic
		|
		|HAVING
		|	SUM(OrdersBalance.QuantityBalance) > 0
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	MIN(CustomerOrderMaterials.LineNumber) AS LineNumber,
		|	CustomerOrderMaterials.ProductsAndServices AS ProductsAndServices,
		|	CustomerOrderMaterials.Characteristic AS Characteristic,
		|	CustomerOrderMaterials.Batch AS Batch,
		|	CASE
		|		WHEN VALUETYPE(CustomerOrderMaterials.MeasurementUnit) = Type(Catalog.UOMClassifier)
		|			THEN 1
		|		ELSE CustomerOrderMaterials.MeasurementUnit.Factor
		|	END AS Factor,
		|	CustomerOrderMaterials.MeasurementUnit AS MeasurementUnit,
		|	CASE
		|		WHEN CustomerOrderMaterials.ProductsAndServices.VATRate = VALUE(Catalog.VATRates.EmptyRef)
		|			THEN CustomerOrderMaterials.Ref.Company.DefaultVATRate
		|		ELSE CustomerOrderMaterials.ProductsAndServices.VATRate
		|	END AS VATRate,
		|	CustomerOrderMaterials.Ref.Start AS InventoryReceiptDate,
		|	SUM(CustomerOrderMaterials.Quantity) AS Quantity
		|FROM
		|	Document.CustomerOrder.Materials AS CustomerOrderMaterials
		|WHERE
		|	CustomerOrderMaterials.Ref = &BasisDocument
		|
		|GROUP BY
		|	CustomerOrderMaterials.ProductsAndServices,
		|	CustomerOrderMaterials.Characteristic,
		|	CustomerOrderMaterials.Batch,
		|	CustomerOrderMaterials.MeasurementUnit,
		|	CustomerOrderMaterials.Ref,
		|	CASE
		|		WHEN CustomerOrderMaterials.ProductsAndServices.VATRate = VALUE(Catalog.VATRates.EmptyRef)
		|			THEN CustomerOrderMaterials.Ref.Company.DefaultVATRate
		|		ELSE CustomerOrderMaterials.ProductsAndServices.VATRate
		|	END,
		|	CASE
		|		WHEN VALUETYPE(CustomerOrderMaterials.MeasurementUnit) = Type(Catalog.UOMClassifier)
		|			THEN 1
		|		ELSE CustomerOrderMaterials.MeasurementUnit.Factor
		|	END,
		|	CustomerOrderMaterials.Ref.Start
		|
		|ORDER BY
		|	LineNumber";
		
	EndIf;
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("ProductsAndServices,Characteristic");
	
	Inventory.Clear();
	If BalanceTable.Count() > 0 Then
		
		Selection = ResultsArray[1].Select();
		While Selection.Next() Do
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("ProductsAndServices", Selection.ProductsAndServices);
			StructureForSearch.Insert("Characteristic", Selection.Characteristic);
			
			BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
			If BalanceRowsArray.Count() = 0 Then
				Continue;
			EndIf;
			
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
			
			QuantityToWriteOff = Selection.Quantity * Selection.Factor;
			BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityToWriteOff;
			If BalanceRowsArray[0].QuantityBalance < 0 Then
				
				NewRow.Quantity = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / Selection.Factor;
				
			EndIf;
			
			NewRow.ReceiptDate = Selection.InventoryReceiptDate;
			If ReceiptDate <> NewRow.ReceiptDate Then
				ReceiptDatePositionAtHeader = False;
			EndIf;
			
			If BalanceRowsArray[0].QuantityBalance <= 0 Then
				BalanceTable.Delete(BalanceRowsArray[0]);
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If AttributeValues.OperationKind = Enums.OperationKindsCustomerOrder.JobOrder Then
		
		ResultsArray = Query.ExecuteBatch();
		BalanceTable = ResultsArray[2].Unload();
		BalanceTable.Indexes.Add("ProductsAndServices,Characteristic");
		
		Selection = ResultsArray[3].Select();
		While Selection.Next() Do
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("ProductsAndServices", Selection.ProductsAndServices);
			StructureForSearch.Insert("Characteristic", Selection.Characteristic);
			
			BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
			If BalanceRowsArray.Count() = 0 Then
				
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, Selection);
				
			ElsIf (BalanceRowsArray[0].QuantityBalance / Selection.Factor) = Selection.Quantity Then
				
				Continue;
				
			ElsIf (BalanceRowsArray[0].QuantityBalance / Selection.Factor) > Selection.Quantity Then
				
				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - Selection.Quantity * Selection.Factor;
				Continue;
				
			ElsIf (BalanceRowsArray[0].QuantityBalance / Selection.Factor) < Selection.Quantity Then
				
				QuantityToWriteOff = -1 * (BalanceRowsArray[0].QuantityBalance / Selection.Factor - Selection.Quantity);
				BalanceRowsArray[0].QuantityBalance = 0;
				
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, Selection);
				
				NewRow.Quantity = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / Selection.Factor;
				
			EndIf;
			
			NewRow.ReceiptDate = Selection.InventoryReceiptDate;
			If ReceiptDate <> NewRow.ReceiptDate Then
				ReceiptDatePositionAtHeader = False;
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure // FillByCustomerOrder()

// Procedure of cancellation of posting of subordinate invoice note (supplier)
//
Procedure SubordinatedInvoiceControl()
	
	InvoiceStructure = SmallBusinessServer.GetSubordinateInvoice(Ref, True);
	If Not InvoiceStructure = Undefined Then
		
		CustomerInvoiceNote	 = InvoiceStructure.Ref;
		If CustomerInvoiceNote.Posted Then
			
			MessageText = NStr("en = 'Due to the absence of the turnovers by the %CurrentDocumentPresentation% document, undo the posting of %InvoicePresentation%.'");
			MessageText = StrReplace(MessageText, "%CurrentDocumentPresentation%", """Order vendor # " + Number + " dated " + Format(Date, "DF=dd.MM.yyyy") + """");
			MessageText = StrReplace(MessageText, "%InvoicePresentation%", """Invoice Note (Supplier) # " + InvoiceStructure.Number + " dated " + InvoiceStructure.Date + """");
			
			CommonUseClientServer.MessageToUser(MessageText);
			
			InvoiceObject = CustomerInvoiceNote.GetObject();
			InvoiceObject.Write(DocumentWriteMode.UndoPosting);
			
		EndIf;
		
	EndIf;
	
EndProcedure //SubordinateInvoiceControl()

// Procedure fills the Quantity column by free balances at warehouse.
//
Procedure FillColumnReserveByBalances() Export
	
	Materials.LoadColumn(New Array(Materials.Count()), "Reserve");
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	VALUE(Catalog.ProductsAndServicesBatches.EmptyRef) AS Batch
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory";
	
	Query.SetParameter("TableInventory", Materials.Unload());
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) In
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.ProductsAndServices.InventoryGLAccount,
	|						TableInventory.ProductsAndServices,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						VALUE(Document.CustomerOrder.EmptyRef) AS CustomerOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.ProductsAndServices,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &Period
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.ProductsAndServices,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnitReserve);
	
	TableOfPeriods = New ValueTable();
	TableOfPeriods.Columns.Add("ShipmentDate");
	TableOfPeriods.Columns.Add("StringInventory");
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("ProductsAndServices", Selection.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		
		ArrayOfRowsInventory = Materials.FindRows(StructureForSearch);
		For Each StringInventory IN ArrayOfRowsInventory Do
			NewRow = TableOfPeriods.Add();
			NewRow.ShipmentDate = StringInventory.ShipmentDate;
			NewRow.StringInventory = StringInventory;
		EndDo;
		
		TotalBalance = Selection.QuantityBalance;
		TableOfPeriods.Sort("ShipmentDate");
		For Each TableOfPeriodsRow IN TableOfPeriods Do
			StringInventory = TableOfPeriodsRow.StringInventory;
			TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance / StringInventory.MeasurementUnit.Factor);
			If StringInventory.Quantity >= TotalBalance Then
				StringInventory.Reserve = TotalBalance;
				TotalBalance = 0;
			Else
				StringInventory.Reserve = StringInventory.Quantity;
				TotalBalance = TotalBalance - StringInventory.Quantity;
				TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance * StringInventory.MeasurementUnit.Factor);
			EndIf;
		EndDo;
		
		TableOfPeriods.Clear();
		
	EndDo;

	
EndProcedure // FillColumnReserveByBalances()

// Procedure fills document when copying.
//
Procedure FillOnCopy()
	
	If Constants.UsePurchaseOrderStates.Get() Then
		User = Users.CurrentUser();
		SettingValue = SmallBusinessReUse.GetValueByDefaultUser(User, "StatusOfNewPurchaseOrder");
		If ValueIsFilled(SettingValue) Then
			If OrderState <> SettingValue Then
				OrderState = SettingValue;
			EndIf;
		Else
			OrderState = Catalogs.PurchaseOrderStates.Open;
		EndIf;
	Else
		OrderState = Constants.PurchaseOrdersInProgressStatus.Get();
	EndIf;
	
	Closed = False;
	
EndProcedure // FillOnCopy()

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - event handler of the OnCopy object.
//
Procedure OnCopy(CopiedObject)
	
	SmallBusinessManagementElectronicDocumentsServer.ClearIncomingDocumentDateNumber(ThisObject);
	
	FillOnCopy();
	
EndProcedure // OnCopy()

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If TypeOf(FillingData) = Type("CatalogRef.Counterparties") Then
		
		If FillingData.IsFolder Then
			Raise NStr("en = 'Unable to select counterparty group.'");
		EndIf;
		
		Counterparty = FillingData;
		Contract = FillingData.ContractByDefault;
		CounterpartyPriceKind = FillingData.ContractByDefault.CounterpartyPriceKind;
		
		DocumentCurrency = Contract.SettlementsCurrency;
		StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
		ExchangeRate = StructureByCurrency.ExchangeRate;
		Multiplicity = StructureByCurrency.Multiplicity;
		
		Return;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.Event") Then
	
		Event = FillingData.Ref;
		If FillingData.Parties.Count() > 0 AND TypeOf(FillingData.Parties[0].Contact) = Type("CatalogRef.Counterparties") Then
			Counterparty = FillingData.Parties[0].Contact;
			Contract = Counterparty.ContractByDefault;
			CounterpartyPriceKind = Contract.CounterpartyPriceKind;
			
			DocumentCurrency = Contract.SettlementsCurrency;
			StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
			ExchangeRate = StructureByCurrency.ExchangeRate;
			Multiplicity = StructureByCurrency.Multiplicity;
		EndIf;
		
		Return;
		
	ElsIf TypeOf(FillingData) = Type("Structure") Then
		
		FillPropertyValues(ThisObject, FillingData);
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CustomerOrder") Then
		
		FillUsingCustomerOrder(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ProductionOrder") Then
		
		If FillingData.OperationKind = Enums.OperationKindsProductionOrder.Assembly Then
		
			Query = New Query(
			"SELECT
			|	ProductionOrder.Ref AS Order,
			|	ProductionOrder.Company AS Company,
			|	ProductionOrder.CustomerOrder,
			|	ProductionOrder.Start AS ReceiptDate,
			|	ProductionOrder.Inventory.(
			|		Ref.Start AS ReceiptDate,
			|		ProductsAndServices,
			|		Characteristic,
			|		MeasurementUnit,
			|		Quantity,
			|		ProductsAndServices.VATRate AS VATRate
			|	) AS Inventory
			|FROM
			|	Document.ProductionOrder AS ProductionOrder
			|WHERE
			|	ProductionOrder.Ref = &BasisDocument");
			
		ElsIf FillingData.OperationKind = Enums.OperationKindsProductionOrder.Disassembly Then
		
			Query = New Query(
			"SELECT
			|	ProductionOrder.Ref AS Order,
			|	ProductionOrder.Company AS Company,
			|	ProductionOrder.CustomerOrder,
			|	ProductionOrder.Start AS ReceiptDate,
			|	ProductionOrder.Products.(
			|		Ref.Start AS ReceiptDate,
			|		ProductsAndServices,
			|		Characteristic,
			|		MeasurementUnit,
			|		Quantity,
			|		ProductsAndServices.VATRate AS VATRate
			|	) AS Inventory
			|FROM
			|	Document.ProductionOrder AS ProductionOrder
			|WHERE
			|	ProductionOrder.Ref = &BasisDocument");
			
		Else
			
			Return;
			
		EndIf;
		
		Query.SetParameter("BasisDocument", FillingData);
		
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			VATRate = Undefined;
			VATTaxationFromProductsAndServices = False;
			If VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
				If VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then
					VATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
				Else
					VATRate = SmallBusinessReUse.GetVATRateZero();
				EndIf;
			Else
				VATTaxationFromProductsAndServices = True;
				VATRate = Company.DefaultVATRate;
			EndIf;
			
			Inventory.Load(QueryResultSelection.Inventory.Unload());
			
			For Each StringInventory IN Inventory Do
				If VATTaxationFromProductsAndServices Then
					If Not ValueIsFilled(StringInventory.VATRate) Then
						StringInventory.VATRate = VATRate;
					EndIf;
				Else
					StringInventory.VATRate = VATRate;
				EndIf;
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ReceiptDatePosition = Enums.AttributePositionOnForm.InHeader Then
		For Each TabularSectionRow IN Inventory Do
			If TabularSectionRow.ReceiptDate <> ReceiptDate Then
				TabularSectionRow.ReceiptDate = ReceiptDate;
			EndIf;
		EndDo;
	EndIf;
	
	If ReceiptDatePosition = Enums.AttributePositionOnForm.InTabularSection Then
		If Inventory.Count() > 0 Then
			ReceiptDate = Inventory[0].ReceiptDate;
		EndIf;
	EndIf;
	
	If ValueIsFilled(Counterparty)
	AND Not Counterparty.DoOperationsByContracts
	AND Not ValueIsFilled(Contract) Then
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
	DocumentAmount = Inventory.Total("Total");
	
EndProcedure // BeforeWrite()

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Counterparty.DoOperationsByContracts Then
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	If Materials.Total("Reserve") > 0 Then
		
		For Each StringMaterials in Materials Do
		
			If StringMaterials.Reserve > 0 AND Not ValueIsFilled(StructuralUnitReserve) Then
				
				MessageText = NStr("en = 'The reserve warehouse is not filled.'");
				SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText, , , "StructuralUnitReserve", Cancel);
				
			EndIf;
		
		EndDo;
	
	EndIf;
	
	If SchedulePayment
	   AND CashAssetsType = Enums.CashAssetTypes.Noncash Then
	   
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PettyCash");
		
	ElsIf SchedulePayment
	   AND CashAssetsType = Enums.CashAssetTypes.Cash Then
	   
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankAccount");
		
	Else
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PettyCash");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankAccount");
		
	EndIf;
	
	If SchedulePayment
	   AND PaymentCalendar.Count() = 1
	   AND Not ValueIsFilled(PaymentCalendar[0].PayDate) Then
		
		MessageText = NStr("en = 'Field ""Payment date"" is required.'");
		SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText, , , "PayDate", Cancel);
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentCalendar.PaymentDate");
		
	EndIf;
	
	If Constants.FunctionalOptionInventoryReservation.Get()
		AND OperationKind = Enums.OperationKindsPurchaseOrder.OrderForProcessing Then
		
		For Each StringMaterials IN Materials Do
			
			If StringMaterials.Reserve > StringMaterials.Quantity Then
				
				MessageText = NStr("en = 'In string No.%Number% of tabular section ""Recycling materials"" quantity of the write-off positions from reserve exceeds the total materials.'");
				MessageText = StrReplace(MessageText, "%Number%", StringMaterials.LineNumber);
				SmallBusinessServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Materials",
					StringMaterials.LineNumber,
					"Reserve",
					Cancel
				);
				
			EndIf;	
			
		EndDo;		
		
	EndIf;
	
	If Not Constants.UsePurchaseOrderStates.Get() Then
		
		If Not ValueIsFilled(OrderState) Then
			MessageText = NStr("en = 'Field ""Order state"" is not filled. IN the accounting parameters settings it is necessary to install the statuses values.'");
			SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText, , , "OrderState", Cancel);
		EndIf;
		
	EndIf;
	
	If ReceiptDatePosition = Enums.AttributePositionOnForm.InTabularSection Then
		CheckedAttributes.Delete(CheckedAttributes.Find("ReceiptDate"));
	Else
		CheckedAttributes.Delete(CheckedAttributes.Find("Inventory.ReceiptDate"));
	EndIf;
	
EndProcedure // FillCheckProcessing()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.PurchaseOrder.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	SmallBusinessServer.ReflectInventoryTransferSchedule(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectPurchaseOrders(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectOrdersPlacement(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);

	// Control
	Documents.PurchaseOrder.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.PurchaseOrder.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	// Subordinate invoice note (supplier)
	If Not Cancel Then
		
		SubordinatedInvoiceControl();
		
	EndIf;
	
EndProcedure

#EndIf