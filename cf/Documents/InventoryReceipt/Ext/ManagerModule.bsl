#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefInventoryReceipt, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	InventoryReceiptInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	InventoryReceiptInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	InventoryReceiptInventory.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN InventoryReceiptInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|				OR InventoryReceiptInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Retail)
	|			THEN InventoryReceiptInventory.ProductsAndServices.InventoryGLAccount
	|		ELSE InventoryReceiptInventory.ProductsAndServices.ExpensesGLAccount
	|	END AS GLAccount,
	|	InventoryReceiptInventory.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryReceiptInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryReceiptInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(InventoryReceiptInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN InventoryReceiptInventory.Quantity
	|		ELSE InventoryReceiptInventory.Quantity * InventoryReceiptInventory.MeasurementUnit.Factor
	|	END AS Count,
	|	TRUE AS FixedCost,
	|	InventoryReceiptInventory.Amount AS Amount,
	|	VALUE(AccountingRecordType.Debit) AS RecordKindManagerial,
	|	&InventoryReceipt AS ContentOfAccountingRecord
	|FROM
	|	Document.InventoryReceipt.Inventory AS InventoryReceiptInventory
	|WHERE
	|	InventoryReceiptInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryReceiptInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	InventoryReceiptInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	InventoryReceiptInventory.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN InventoryReceiptInventory.Ref.Cell
	|		ELSE UNDEFINED
	|	END AS Cell,
	|	InventoryReceiptInventory.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryReceiptInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryReceiptInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(InventoryReceiptInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN InventoryReceiptInventory.Quantity
	|		ELSE InventoryReceiptInventory.Quantity * InventoryReceiptInventory.MeasurementUnit.Factor
	|	END AS Count
	|FROM
	|	Document.InventoryReceipt.Inventory AS InventoryReceiptInventory
	|WHERE
	|	InventoryReceiptInventory.Ref = &Ref
	|	AND InventoryReceiptInventory.Ref.StructuralUnit.OrderWarehouse = FALSE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryReceiptInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	InventoryReceiptInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	InventoryReceiptInventory.Ref.StructuralUnit AS StructuralUnit,
	|	InventoryReceiptInventory.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryReceiptInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryReceiptInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(InventoryReceiptInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN InventoryReceiptInventory.Quantity
	|		ELSE InventoryReceiptInventory.Quantity * InventoryReceiptInventory.MeasurementUnit.Factor
	|	END AS Count
	|FROM
	|	Document.InventoryReceipt.Inventory AS InventoryReceiptInventory
	|WHERE
	|	InventoryReceiptInventory.Ref = &Ref
	|	AND InventoryReceiptInventory.Ref.StructuralUnit.OrderWarehouse = TRUE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryReceiptInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.BusinessActivities.Other) AS BusinessActivity,
	|	SUM(InventoryReceiptInventory.Amount) AS AmountIncome,
	|	SUM(InventoryReceiptInventory.Amount) AS Amount,
	|	InventoryReceiptInventory.Ref.Correspondence AS GLAccount,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindManagerial,
	|	&RevenueIncomes AS ContentOfAccountingRecord
	|FROM
	|	Document.InventoryReceipt.Inventory AS InventoryReceiptInventory
	|WHERE
	|	InventoryReceiptInventory.Ref = &Ref
	|	AND InventoryReceiptInventory.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|	AND InventoryReceiptInventory.Amount > 0
	|
	|GROUP BY
	|	InventoryReceiptInventory.Ref,
	|	InventoryReceiptInventory.Ref.Date,
	|	InventoryReceiptInventory.Ref.Correspondence
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryReceiptInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN InventoryReceiptInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|				OR InventoryReceiptInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Retail)
	|			THEN InventoryReceiptInventory.ProductsAndServices.InventoryGLAccount
	|		ELSE InventoryReceiptInventory.ProductsAndServices.ExpensesGLAccount
	|	END AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	InventoryReceiptInventory.Ref.Correspondence AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	SUM(InventoryReceiptInventory.Amount) AS Amount,
	|	&InventoryReceipt AS Content
	|FROM
	|	Document.InventoryReceipt.Inventory AS InventoryReceiptInventory
	|WHERE
	|	InventoryReceiptInventory.Ref = &Ref
	|	AND InventoryReceiptInventory.Amount > 0
	|
	|GROUP BY
	|	InventoryReceiptInventory.Ref.Date,
	|	CASE
	|		WHEN InventoryReceiptInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|				OR InventoryReceiptInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Retail)
	|			THEN InventoryReceiptInventory.ProductsAndServices.InventoryGLAccount
	|		ELSE InventoryReceiptInventory.ProductsAndServices.ExpensesGLAccount
	|	END,
	|	InventoryReceiptInventory.Ref.Correspondence");
	
	Query.SetParameter("Ref", DocumentRefInventoryReceipt);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("AccountingByCells", StructureAdditionalProperties.AccountingPolicy.AccountingByCells);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	
	Query.SetParameter("InventoryReceipt", NStr("en='Inventory receiving';ru='Прием запасов'"));
	Query.SetParameter("RevenueIncomes", NStr("en='Receipt of other income';ru='Поступление прочих доходов'"));
	Query.SetParameter("OtherIncome", NStr("en='Other inventory receipt';ru='Прочее оприходование запасов'"));
	
	ResultsArray = Query.ExecuteBatch();
	
    StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryForWarehouses", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", ResultsArray[4].Unload());
	
EndProcedure // DocumentDataInitialization()

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefInventoryReceipt, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not SmallBusinessServer.RunBalanceControl() Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If the "InventoryTransferAtWarehouseChange", "RegisterRecordsInventoryChange"
	// temporary tables contain records, it is necessary to control the sales of goods.
	
	If StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		OR StructureTemporaryTables.RegisterRecordsInventoryChange Then

		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryInWarehousesChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Cell) AS PresentationCell,
		|	InventoryInWarehousesOfBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	REFPRESENTATION(InventoryInWarehousesOfBalance.ProductsAndServices.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryInWarehousesChange.QuantityChange, 0) + ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS BalanceInventoryInWarehouses,
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS QuantityBalanceInventoryInWarehouses
		|FROM
		|	RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange
		|		LEFT JOIN AccumulationRegister.InventoryInWarehouses.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, ProductsAndServices, Characteristic, Batch, Cell) In
		|					(SELECT
		|						RegisterRecordsInventoryInWarehousesChange.Company AS Company,
		|						RegisterRecordsInventoryInWarehousesChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryInWarehousesChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsInventoryInWarehousesChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryInWarehousesChange.Batch AS Batch,
		|						RegisterRecordsInventoryInWarehousesChange.Cell AS Cell
		|					FROM
		|						RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange)) AS InventoryInWarehousesOfBalance
		|		ON RegisterRecordsInventoryInWarehousesChange.Company = InventoryInWarehousesOfBalance.Company
		|			AND RegisterRecordsInventoryInWarehousesChange.StructuralUnit = InventoryInWarehousesOfBalance.StructuralUnit
		|			AND RegisterRecordsInventoryInWarehousesChange.ProductsAndServices = InventoryInWarehousesOfBalance.ProductsAndServices
		|			AND RegisterRecordsInventoryInWarehousesChange.Characteristic = InventoryInWarehousesOfBalance.Characteristic
		|			AND RegisterRecordsInventoryInWarehousesChange.Batch = InventoryInWarehousesOfBalance.Batch
		|			AND RegisterRecordsInventoryInWarehousesChange.Cell = InventoryInWarehousesOfBalance.Cell
		|WHERE
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.GLAccount) AS GLAccountPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.CustomerOrder) AS CustomerOrderPresentation,
		|	InventoryBalances.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	REFPRESENTATION(InventoryBalances.ProductsAndServices.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryChange.QuantityChange, 0) + ISNULL(InventoryBalances.QuantityBalance, 0) AS BalanceInventory,
		|	ISNULL(InventoryBalances.QuantityBalance, 0) AS QuantityBalanceInventory,
		|	ISNULL(InventoryBalances.AmountBalance, 0) AS AmountBalanceInventory
		|FROM
		|	RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange
		|		LEFT JOIN AccumulationRegister.Inventory.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) In
		|					(SELECT
		|						RegisterRecordsInventoryChange.Company AS Company,
		|						RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryChange.GLAccount AS GLAccount,
		|						RegisterRecordsInventoryChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsInventoryChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryChange.Batch AS Batch,
		|						RegisterRecordsInventoryChange.CustomerOrder AS CustomerOrder
		|					FROM
		|						RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange)) AS InventoryBalances
		|		ON RegisterRecordsInventoryChange.Company = InventoryBalances.Company
		|			AND RegisterRecordsInventoryChange.StructuralUnit = InventoryBalances.StructuralUnit
		|			AND RegisterRecordsInventoryChange.GLAccount = InventoryBalances.GLAccount
		|			AND RegisterRecordsInventoryChange.ProductsAndServices = InventoryBalances.ProductsAndServices
		|			AND RegisterRecordsInventoryChange.Characteristic = InventoryBalances.Characteristic
		|			AND RegisterRecordsInventoryChange.Batch = InventoryBalances.Batch
		|			AND RegisterRecordsInventoryChange.CustomerOrder = InventoryBalances.CustomerOrder
		|WHERE
		|	ISNULL(InventoryBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber");

		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();

		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty() Then
			DocumentObjectInventoryReceipt = DocumentRefInventoryReceipt.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectInventoryReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory and cost accounting.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectInventoryReceipt, QueryResultSelection, Cancel);
		EndIf;

	EndIf;

EndProcedure // RunControl()

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#EndIf