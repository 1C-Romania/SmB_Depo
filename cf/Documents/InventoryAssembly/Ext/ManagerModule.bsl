#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

///////////////////////////////////////////////////////////////////////////////
// OVERALL PROCEDURES AND FUNCTIONS

// Procedure generates  nodes content.
//
Procedure FillProductsTableByNodsStructure(StringProducts, TableProduction, NodesSpecificationStack)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	MIN(TableMaterials.LineNumber) AS StructureLineNumber,
	|	TableMaterials.ContentRowType AS ContentRowType,
	|	TableMaterials.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(CASE
	|			WHEN VALUETYPE(TableMaterials.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN TableMaterials.Quantity / TableMaterials.ProductsQuantity * &ProductsQuantity
	|			ELSE TableMaterials.Quantity * TableMaterials.MeasurementUnit.Factor / TableMaterials.ProductsQuantity * &ProductsQuantity
	|		END) AS ExpenseNorm,
	|	TableMaterials.Specification AS Specification
	|FROM
	|	Catalog.Specifications.Content AS TableMaterials,
	|	Constant.FunctionalOptionUseCharacteristics AS UseCharacteristics
	|WHERE
	|	TableMaterials.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|	AND TableMaterials.Ref = &Ref
	|
	|GROUP BY
	|	TableMaterials.ContentRowType,
	|	TableMaterials.ProductsAndServices,
	|	TableMaterials.CostPercentage,
	|	TableMaterials.Specification,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END
	|
	|ORDER BY
	|	StructureLineNumber";
	
	Query.SetParameter("Ref", StringProducts.TMSpecification);
	Query.SetParameter("ProductsQuantity", StringProducts.TMQuantity);
	
	NodesSpecificationStack.Add(StringProducts.TMSpecification);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If Selection.ContentRowType = Enums.SpecificationContentRowTypes.Node Then
			If Not NodesSpecificationStack.Find(Selection.Specification) = Undefined Then
				MessageText = NStr("en='Detected a recursive item occurrence';ru='Обнаружено рекурсивное вхождение элемента'")+" "+Selection.ProductsAndServices+" "+NStr("en='in specifications';ru='в спецификации'")+" "+StringProducts.SpecificationCorr+"
									|The operation failed.";
				Raise MessageText;
			EndIf;
			NodesSpecificationStack.Add(Selection.Specification);
			StringProducts.TMQuantity = Selection.ExpenseNorm;
			StringProducts.TMSpecification = Selection.Specification;
			FillProductsTableByNodsStructure(StringProducts, TableProduction, NodesSpecificationStack);
		Else
			NewRow = TableProduction.Add();
			FillPropertyValues(NewRow, StringProducts);
			NewRow.TMContentRowType = Selection.ContentRowType;
			NewRow.TMProductsAndServices = Selection.ProductsAndServices;
			NewRow.TMCharacteristic = Selection.Characteristic;
			NewRow.TMQuantity = Selection.ExpenseNorm;
			NewRow.TMSpecification = Selection.Specification;
		EndIf;
	EndDo;
	
	NodesSpecificationStack.Clear();
	
EndProcedure // FillProductsTableByNodsContent()

// Procedure distributes materials by the products specifications.
//
Procedure DistributeMaterialsAccordingToNorms(StringMaterials, BaseTable, MaterialsTable)
	
	StringMaterials.Distributed = True;
	
	DistributionBase = 0;
	For Each BaseRow IN BaseTable Do
		DistributionBase = DistributionBase + BaseRow.TMQuantity;
		BaseRow.Distributed = True;
	EndDo;
	
	DistributeTabularSectionStringMaterials(StringMaterials, BaseTable, MaterialsTable, DistributionBase, True);
	
EndProcedure // AllocateMaterialsByNorms()

// Procedure distributes materials in proportion to the products quantity.
//
Procedure DistributeMaterialsByQuantity(BaseTable, MaterialsTable, DistributionBase = 0)
	
	ExcDistributed = False;
	If DistributionBase = 0 Then
		ExcDistributed = True;
		For Each BaseRow IN BaseTable Do
			If Not BaseRow.Distributed Then
				DistributionBase = DistributionBase + BaseRow.CorrQuantity;
			EndIf;
		EndDo;
	EndIf;
	
	For n = 0 To MaterialsTable.Count() - 1 Do
		
		StringMaterials = MaterialsTable[n];
		
		If Not StringMaterials.Distributed Then
			DistributeTabularSectionStringMaterials(StringMaterials, BaseTable, MaterialsTable, DistributionBase, False, ExcDistributed);
		EndIf;
		
	EndDo;
	
EndProcedure // AllocateMaterialsByCount()

// Procedure allocates materials string.
//
Procedure DistributeTabularSectionStringMaterials(StringMaterials, BaseTable, MaterialsTable, DistributionBase, AccordingToNorms, ExcDistributed = False)
	
	InitQuantity = 0;
	InitReserve = 0;
	QuantityToWriteOff = StringMaterials.Quantity;
	ReserveToWriteOff = StringMaterials.Reserve;
	
	DistributionBaseQuantity = DistributionBase;
	DistributionBaseReserve = DistributionBase;
	
	For Each BasicTableRow IN BaseTable Do
		
		If ExcDistributed AND BasicTableRow.Distributed Then
			Continue;
		EndIf;
		
		If InitQuantity = QuantityToWriteOff Then
			Continue;
		EndIf;
		
		If ValueIsFilled(StringMaterials.ProductsAndServicesCorr) Then
			NewRow = MaterialsTable.Add();
			FillPropertyValues(NewRow, StringMaterials);
			FillPropertyValues(NewRow, BasicTableRow);
			StringMaterials = NewRow;
		Else
			FillPropertyValues(StringMaterials, BasicTableRow);
		EndIf;
		
		If AccordingToNorms Then
			BasicTableQuantity = BasicTableRow.TMQuantity;
		Else
			BasicTableQuantity = BasicTableRow.CorrQuantity
		EndIf;
		
		// Quantity.
		StringMaterials.Quantity = Round((QuantityToWriteOff - InitQuantity) * BasicTableQuantity / DistributionBaseQuantity, 3, 1);
		
		If (InitQuantity + StringMaterials.Quantity) > QuantityToWriteOff Then
			StringMaterials.Quantity = QuantityToWriteOff - InitQuantity;
			InitQuantity = QuantityToWriteOff;
		Else
			DistributionBaseQuantity = DistributionBaseQuantity - BasicTableQuantity;
			InitQuantity = InitQuantity + StringMaterials.Quantity;
		EndIf;
		
		// Reserve.
		If InitReserve = ReserveToWriteOff Then
			Continue;
		EndIf;
		
		StringMaterials.Reserve = Round((ReserveToWriteOff - InitReserve) * BasicTableQuantity / DistributionBaseReserve, 3, 1);
		
		If (InitReserve + StringMaterials.Reserve) > ReserveToWriteOff Then
			StringMaterials.Reserve = ReserveToWriteOff - InitReserve;
			InitReserve = ReserveToWriteOff;
		Else
			DistributionBaseReserve = DistributionBaseReserve - BasicTableQuantity;
			InitReserve = InitReserve + StringMaterials.Reserve;
		EndIf;
		
	EndDo;
	
	If InitQuantity < QuantityToWriteOff Then
		StringMaterials.Quantity = StringMaterials.Quantity + (QuantityToWriteOff - InitQuantity);
	EndIf;
	
	If InitReserve < ReserveToWriteOff Then
		StringMaterials.Reserve = StringMaterials.Reserve + (ReserveToWriteOff - InitReserve);
	EndIf;
	
EndProcedure // AllocateTabularSectionStringMaterials()

// Procedure distributes materials by the products specifications.
//
Procedure DistributeProductsAccordingToNorms(StringProducts, BaseTable, DistributionBase)
	
	DistributeTabularSectionStringProducts(StringProducts, BaseTable, DistributionBase, True);
	
EndProcedure // AllocateproductsByNorms()

// Procedure distributes materials in proportion to the products quantity.
//
Procedure DistributeProductsAccordingToQuantity(TableProduction, BaseTable, DistributionBase = 0, ExcDistributed = True)
	
	If ExcDistributed Then
		For Each StringMaterials IN BaseTable Do
			If Not StringMaterials.NewRow
				AND Not StringMaterials.Distributed Then
				DistributionBase = DistributionBase + StringMaterials.CostPercentage;
			EndIf;
		EndDo;
	EndIf;
	
	For Each StringProducts IN TableProduction Do
		
		If Not StringProducts.Distributed Then
			DistributeTabularSectionStringProducts(StringProducts, BaseTable, DistributionBase, False, ExcDistributed);
		EndIf;
		
	EndDo;
	
EndProcedure // AllocateProductsByCount()

// Procedure allocates production string.
//
Procedure DistributeTabularSectionStringProducts(ProductsRow, BaseTable, DistributionBase, AccordingToNorms, ExeptDistribution = False)
	
	InitQuantity = 0;
	InitReserve = 0;
	QuantityToWriteOff = ProductsRow.Quantity;
	ReserveToWriteOff = ProductsRow.Reserve;
	
	DistributionBaseQuantity = DistributionBase;
	DistributionBaseReserve = DistributionBase;
	
	DistributionRow = Undefined;
	For n = 0 To BaseTable.Count() - 1 Do
		
		StringMaterials = BaseTable[n];
		
		If InitQuantity = QuantityToWriteOff
			OR StringMaterials.NewRow Then
			StringMaterials.AccountExecuted = False;
			Continue;
		EndIf;
		
		If AccordingToNorms AND Not StringMaterials.AccountExecuted Then
			Continue;
		EndIf;
		
		StringMaterials.AccountExecuted = False;
		
		If Not AccordingToNorms AND ExeptDistribution
			AND StringMaterials.Distributed Then
			Continue;
		EndIf;
		
		If Not ValueIsFilled(StringMaterials.ProductsAndServices) Then
			Distributed = StringMaterials.Distributed;
			FillPropertyValues(StringMaterials, ProductsRow);
			DistributionRow = StringMaterials;
			DistributionRow.Distributed = Distributed;
		Else
			DistributionRow = BaseTable.Add();
			FillPropertyValues(DistributionRow, StringMaterials);
			FillPropertyValues(DistributionRow, ProductsRow);
			DistributionRow.NewRow = True;
		EndIf;
		
		// Quantity.
		DistributionRow.Quantity = Round((QuantityToWriteOff - InitQuantity) * StringMaterials.CostPercentage / ?(DistributionBaseQuantity = 0, 1, DistributionBaseQuantity),3,1);
		
		If DistributionRow.Quantity = 0 Then
			DistributionRow.Quantity = QuantityToWriteOff;
			InitQuantity = QuantityToWriteOff;
		Else
			DistributionBaseQuantity = DistributionBaseQuantity - StringMaterials.CostPercentage;
			InitQuantity = InitQuantity + DistributionRow.Quantity;
		EndIf;
		
		If InitQuantity > QuantityToWriteOff Then
			DistributionRow.Quantity = DistributionRow.Quantity - (InitQuantity - QuantityToWriteOff);
			InitQuantity = QuantityToWriteOff;
		EndIf;
		
		// Reserve.
		If InitReserve = ReserveToWriteOff Then
			Continue;
		EndIf;
		
		DistributionRow.Reserve = Round((ReserveToWriteOff - InitReserve) * StringMaterials.CostPercentage / ?(DistributionBaseReserve = 0, 1, DistributionBaseReserve),3,1);
		
		If DistributionRow.Reserve = 0 Then
			DistributionRow.Reserve = ReserveToWriteOff;
			InitReserve = ReserveToWriteOff;
		Else
			DistributionBaseReserve = DistributionBaseReserve - StringMaterials.CostPercentage;
			InitReserve = InitReserve + DistributionRow.Reserve;
		EndIf;
		
		If InitReserve > ReserveToWriteOff Then
			DistributionRow.Reserve = DistributionRow.Reserve - (InitReserve - ReserveToWriteOff);
			InitReserve = ReserveToWriteOff;
		EndIf;
		
	EndDo;
	
	If DistributionRow <> Undefined Then
		
		If InitQuantity < QuantityToWriteOff Then
			DistributionRow.Quantity = DistributionRow.Quantity + (QuantityToWriteOff - InitQuantity);
		EndIf;
		
		If InitReserve < ReserveToWriteOff Then
			DistributionRow.Reserve = DistributionRow.Reserve + (ReserveToWriteOff - InitReserve);
		EndIf;
		
	EndIf;
	
EndProcedure // AllocateTabularSectionStringProducts()

////////////////////////////////////////////////////////////////////////////////
// Disposals

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryDisposals(DocumentRefInventoryAssembly, StructureAdditionalProperties)
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDisposals.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDisposals[n];
		
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, RowTableInventory);
		
		// Reusable scraps autotransfer.
		If ValueIsFilled(RowTableInventory.DisposalsStructuralUnit) Then
			
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.RecordType = AccumulationRecordType.Expense;
			
			TableRowExpense.StructuralUnitCorr = RowTableInventory.DisposalsStructuralUnit;
			TableRowExpense.CorrGLAccount = RowTableInventory.GlAccountWaste;
			
			TableRowExpense.ProductsAndServicesCorr = RowTableInventory.ProductsAndServices;
			TableRowExpense.CharacteristicCorr = RowTableInventory.Characteristic;
			TableRowExpense.BatchCorr = RowTableInventory.Batch;
			TableRowExpense.CustomerCorrOrder = RowTableInventory.CustomerOrder;
			
			TableRowExpense.ContentOfAccountingRecord = NStr("en='Inventory transfer';ru='Перемещение запасов'");
            TableRowExpense.Content = NStr("en='Inventory transfer';ru='Перемещение запасов'");
			
			// Receipt.
			TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowReceipt, RowTableInventory);
			
			TableRowReceipt.StructuralUnit = RowTableInventory.DisposalsStructuralUnit;
			TableRowReceipt.GLAccount = RowTableInventory.GlAccountWaste;

			TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
			TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
			
			TableRowReceipt.ProductsAndServicesCorr = RowTableInventory.ProductsAndServices;
			TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
			TableRowReceipt.BatchCorr = RowTableInventory.Batch;
			TableRowReceipt.CustomerCorrOrder = RowTableInventory.CustomerOrder;
			
			TableRowReceipt.ContentOfAccountingRecord = NStr("en='Inventory transfer';ru='Перемещение запасов'");
			TableRowReceipt.Content = NStr("en='Inventory transfer';ru='Перемещение запасов'");
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryDisposals");
	
EndProcedure // GenerateTableInventoryDisposals()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DataInitializationByDisposals(DocumentRefInventoryAssembly, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	InventoryAssemblyWaste.LineNumber AS LineNumber,
	|	&Company AS Company,
	|	InventoryAssemblyWaste.Ref.Date AS Period,
	|	InventoryAssemblyWaste.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN InventoryAssemblyWaste.Ref.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	CASE
	|		WHEN InventoryAssemblyWaste.Ref.StructuralUnit = InventoryAssemblyWaste.Ref.DisposalsStructuralUnit
	|			THEN VALUE(Catalog.StructuralUnits.EmptyRef)
	|		ELSE InventoryAssemblyWaste.Ref.DisposalsStructuralUnit
	|	END AS DisposalsStructuralUnit,
	|	CASE
	|		WHEN InventoryAssemblyWaste.Batch.Status = VALUE(Enum.BatchStatuses.SafeCustody)
	|				OR InventoryAssemblyWaste.Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|				OR InventoryAssemblyWaste.Batch.Status = VALUE(Enum.BatchStatuses.CommissionMaterials)
	|			THEN InventoryAssemblyWaste.ProductsAndServices.InventoryGLAccount
	|		ELSE CASE
	|				WHEN InventoryAssemblyWaste.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|					THEN InventoryAssemblyWaste.ProductsAndServices.InventoryGLAccount
	|				ELSE InventoryAssemblyWaste.ProductsAndServices.ExpensesGLAccount
	|			END
	|	END AS GLAccount,
	|	CASE
	|		WHEN InventoryAssemblyWaste.Batch.Status = VALUE(Enum.BatchStatuses.SafeCustody)
	|				OR InventoryAssemblyWaste.Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|				OR InventoryAssemblyWaste.Batch.Status = VALUE(Enum.BatchStatuses.CommissionMaterials)
	|			THEN InventoryAssemblyWaste.ProductsAndServices.InventoryGLAccount
	|		ELSE CASE
	|				WHEN InventoryAssemblyWaste.Ref.DisposalsStructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|					THEN InventoryAssemblyWaste.ProductsAndServices.InventoryGLAccount
	|				ELSE InventoryAssemblyWaste.ProductsAndServices.ExpensesGLAccount
	|			END
	|	END AS GlAccountWaste,
	|	InventoryAssemblyWaste.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryAssemblyWaste.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryAssemblyWaste.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN InventoryAssemblyWaste.Batch.Status = VALUE(Enum.BatchStatuses.SafeCustody)
	|				OR InventoryAssemblyWaste.Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|				OR InventoryAssemblyWaste.Batch.Status = VALUE(Enum.BatchStatuses.CommissionMaterials)
	|			THEN InventoryAssemblyWaste.Ref.CustomerOrder
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END AS CustomerOrder,
	|	CASE
	|		WHEN VALUETYPE(InventoryAssemblyWaste.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN InventoryAssemblyWaste.Quantity
	|		ELSE InventoryAssemblyWaste.Quantity * InventoryAssemblyWaste.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	CAST(&ReturnWaste AS String(100)) AS ContentOfAccountingRecord,
	|	CAST(&ReturnWaste AS String(100)) AS Content
	|FROM
	|	Document.InventoryAssembly.Disposals AS InventoryAssemblyWaste
	|WHERE
	|	InventoryAssemblyWaste.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryAssemblyWaste.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	InventoryAssemblyWaste.Ref.Date AS Period,
	|	&Company AS Company,
	|	InventoryAssemblyWaste.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN InventoryAssemblyWaste.Ref.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	InventoryAssemblyWaste.Ref.DisposalsStructuralUnit AS DisposalsStructuralUnit,
	|	InventoryAssemblyWaste.Ref.StructuralUnit.OrderWarehouse AS OrderWarehouse,
	|	InventoryAssemblyWaste.Ref.DisposalsStructuralUnit.OrderWarehouse AS OrderWarehouseWaste,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN InventoryAssemblyWaste.Ref.DisposalsCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS DisposalsCell,
	|	InventoryAssemblyWaste.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryAssemblyWaste.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryAssemblyWaste.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(InventoryAssemblyWaste.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN InventoryAssemblyWaste.Quantity
	|		ELSE InventoryAssemblyWaste.Quantity * InventoryAssemblyWaste.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.InventoryAssembly.Disposals AS InventoryAssemblyWaste
	|WHERE
	|	InventoryAssemblyWaste.Ref = &Ref
	|	AND InventoryAssemblyWaste.Ref.Date < &UpdateDateToRelease_1_2_1
	|
	|UNION ALL
	|
	|SELECT
	|	InventoryAssemblyWaste.LineNumber,
	|	VALUE(AccumulationRecordType.Receipt),
	|	InventoryAssemblyWaste.Ref.Date,
	|	&Company,
	|	InventoryAssemblyWaste.Ref.StructuralUnit,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN InventoryAssemblyWaste.Ref.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END,
	|	InventoryAssemblyWaste.Ref.DisposalsStructuralUnit,
	|	InventoryAssemblyWaste.Ref.StructuralUnit.OrderWarehouse,
	|	InventoryAssemblyWaste.Ref.DisposalsStructuralUnit.OrderWarehouse,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN InventoryAssemblyWaste.Ref.DisposalsCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END,
	|	InventoryAssemblyWaste.ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryAssemblyWaste.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryAssemblyWaste.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END,
	|	CASE
	|		WHEN VALUETYPE(InventoryAssemblyWaste.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN InventoryAssemblyWaste.Quantity
	|		ELSE InventoryAssemblyWaste.Quantity * InventoryAssemblyWaste.MeasurementUnit.Factor
	|	END
	|FROM
	|	Document.InventoryAssembly.Disposals AS InventoryAssemblyWaste
	|WHERE
	|	InventoryAssemblyWaste.Ref = &Ref
	|	AND (NOT InventoryAssemblyWaste.Ref.StructuralUnit.OrderWarehouse)
	|	AND InventoryAssemblyWaste.Ref.Date >= &UpdateDateToRelease_1_2_1
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryAssemblyWaste.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	InventoryAssemblyWaste.Ref.Date AS Period,
	|	InventoryAssemblyWaste.Ref.StructuralUnit AS StructuralUnit,
	|	InventoryAssemblyWaste.Ref.Company AS Company,
	|	InventoryAssemblyWaste.ProductsAndServices AS ProductsAndServices,
	|	InventoryAssemblyWaste.Characteristic AS Characteristic,
	|	InventoryAssemblyWaste.Batch AS Batch,
	|	CASE
	|		WHEN VALUETYPE(InventoryAssemblyWaste.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN InventoryAssemblyWaste.Quantity
	|		ELSE InventoryAssemblyWaste.Quantity * InventoryAssemblyWaste.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.InventoryAssembly.Disposals AS InventoryAssemblyWaste
	|WHERE
	|	InventoryAssemblyWaste.Ref = &Ref
	|	AND InventoryAssemblyWaste.Ref.StructuralUnit.OrderWarehouse
	|	AND InventoryAssemblyWaste.Ref.Date >= &UpdateDateToRelease_1_2_1
	|
	|UNION ALL
	|
	|SELECT
	|	InventoryAssemblyWaste.LineNumber,
	|	VALUE(AccumulationRecordType.Expense),
	|	InventoryAssemblyWaste.Ref.Date,
	|	InventoryAssemblyWaste.Ref.DisposalsStructuralUnit,
	|	InventoryAssemblyWaste.Ref.Company,
	|	InventoryAssemblyWaste.ProductsAndServices,
	|	InventoryAssemblyWaste.Characteristic,
	|	InventoryAssemblyWaste.Batch,
	|	CASE
	|		WHEN VALUETYPE(InventoryAssemblyWaste.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN InventoryAssemblyWaste.Quantity
	|		ELSE InventoryAssemblyWaste.Quantity * InventoryAssemblyWaste.MeasurementUnit.Factor
	|	END
	|FROM
	|	Document.InventoryAssembly.Disposals AS InventoryAssemblyWaste
	|WHERE
	|	InventoryAssemblyWaste.Ref = &Ref
	|	AND InventoryAssemblyWaste.Ref.DisposalsStructuralUnit.OrderWarehouse
	|	AND InventoryAssemblyWaste.Ref.DisposalsStructuralUnit <> InventoryAssemblyWaste.Ref.StructuralUnit
	|
	|UNION ALL
	|
	|SELECT
	|	InventoryAssemblyWaste.LineNumber,
	|	VALUE(AccumulationRecordType.Receipt),
	|	InventoryAssemblyWaste.Ref.Date,
	|	InventoryAssemblyWaste.Ref.DisposalsStructuralUnit,
	|	InventoryAssemblyWaste.Ref.Company,
	|	InventoryAssemblyWaste.ProductsAndServices,
	|	InventoryAssemblyWaste.Characteristic,
	|	InventoryAssemblyWaste.Batch,
	|	CASE
	|		WHEN VALUETYPE(InventoryAssemblyWaste.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN InventoryAssemblyWaste.Quantity
	|		ELSE InventoryAssemblyWaste.Quantity * InventoryAssemblyWaste.MeasurementUnit.Factor
	|	END
	|FROM
	|	Document.InventoryAssembly.Disposals AS InventoryAssemblyWaste
	|WHERE
	|	InventoryAssemblyWaste.Ref = &Ref
	|	AND InventoryAssemblyWaste.Ref.DisposalsStructuralUnit.OrderWarehouse
	|	AND InventoryAssemblyWaste.Ref.Date < &UpdateDateToRelease_1_2_1
	|	AND InventoryAssemblyWaste.Ref.DisposalsStructuralUnit <> InventoryAssemblyWaste.Ref.StructuralUnit
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	InventoryAssemblyWaste.Ref.Date AS Period,
	|	InventoryAssemblyWaste.Ref.StructuralUnit AS StructuralUnit,
	|	InventoryAssemblyWaste.Ref.Company AS Company,
	|	InventoryAssemblyWaste.ProductsAndServices AS ProductsAndServices,
	|	InventoryAssemblyWaste.Characteristic AS Characteristic,
	|	InventoryAssemblyWaste.Batch AS Batch,
	|	CASE
	|		WHEN VALUETYPE(InventoryAssemblyWaste.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN InventoryAssemblyWaste.Quantity
	|		ELSE InventoryAssemblyWaste.Quantity * InventoryAssemblyWaste.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.InventoryAssembly.Disposals AS InventoryAssemblyWaste
	|WHERE
	|	InventoryAssemblyWaste.Ref = &Ref
	|	AND InventoryAssemblyWaste.Ref.StructuralUnit.OrderWarehouse
	|	AND InventoryAssemblyWaste.Ref.Date >= &UpdateDateToRelease_1_2_1
	|	AND InventoryAssemblyWaste.Ref.DisposalsStructuralUnit <> InventoryAssemblyWaste.Ref.StructuralUnit";
	
	Query.SetParameter("Ref", DocumentRefInventoryAssembly);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("AccountingByCells", StructureAdditionalProperties.AccountingPolicy.AccountingByCells);
	
	// Temporarily: change motions by the order warehouse.
	UpdateDateToRelease_1_2_1 = Constants.UpdateDateToRelease_1_2_1.Get();
	Query.SetParameter("UpdateDateToRelease_1_2_1", UpdateDateToRelease_1_2_1);
	
	Query.SetParameter("ReturnWaste", NStr("en='Return waste';ru='Возвратные отходы'"));
	
	ResultsArray = Query.ExecuteBatch();
	
	// Determine table for inventory accounting.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDisposals", ResultsArray[0].Unload());

	// Generate table for inventory accounting.
	GenerateTableInventoryDisposals(DocumentRefInventoryAssembly, StructureAdditionalProperties);

	// Expand table for inventory.
	ResultsSelection = ResultsArray[1].Select();
	
	While ResultsSelection.Next() Do
		
		TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
		FillPropertyValues(TableRowExpense, ResultsSelection);
		
		// Reusable scraps autotransfer (expand the TableInventoryInWarehouses table).
		If (ResultsSelection.DisposalsStructuralUnit = ResultsSelection.StructuralUnit
			AND ResultsSelection.DisposalsCell <> ResultsSelection.Cell)
			OR ResultsSelection.DisposalsStructuralUnit <> ResultsSelection.StructuralUnit Then
					
			// Expense.			
			If (ResultsSelection.Period < UpdateDateToRelease_1_2_1)
				OR (ResultsSelection.Period >= UpdateDateToRelease_1_2_1
				AND Not ResultsSelection.OrderWarehouse) Then	
				
				TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
				FillPropertyValues(TableRowExpense, ResultsSelection);
			
				TableRowExpense.RecordType = AccumulationRecordType.Expense;
				
			EndIf;	
			
			// Receipt.
			If (ResultsSelection.Period < UpdateDateToRelease_1_2_1)
				OR (ResultsSelection.Period >= UpdateDateToRelease_1_2_1
				AND Not ResultsSelection.OrderWarehouseWaste) Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
				FillPropertyValues(TableRowReceipt, ResultsSelection);
			
				TableRowReceipt.StructuralUnit = ResultsSelection.DisposalsStructuralUnit;
				TableRowReceipt.Cell = ResultsSelection.DisposalsCell;
				
			EndIf;	
			
		EndIf;
		
	EndDo;
	
	// Reusable scraps autotransfer (expand the TableInventoryForWarehouses table).
	ResultsSelection = ResultsArray[2].Select();
	While ResultsSelection.Next() Do
		
		TableRowExpenseReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryForWarehouses.Add();
		FillPropertyValues(TableRowExpenseReceipt, ResultsSelection);		
		
	EndDo;

	// Reusable scraps autotransfer (expand the TableInventoryForWarehousesExpense table).
	ResultsSelection = ResultsArray[3].Select();
	While ResultsSelection.Next() Do
		
		TableRowExpenseReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryForExpenseFromWarehouses.Add();
		FillPropertyValues(TableRowExpenseReceipt, ResultsSelection);		
		
	EndDo;
	
EndProcedure // InitializeDataByDisposals()

////////////////////////////////////////////////////////////////////////////////
// INVENTORY (BUILD)

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryProduction(DocumentRefInventoryAssembly, StructureAdditionalProperties, AssemblyAmount)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text = 
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.CustomerOrder AS CustomerOrder
	|FROM
	|	(SELECT
	|		TableInventory.Company AS Company,
	|		TableInventory.StructuralUnit AS StructuralUnit,
	|		TableInventory.GLAccount AS GLAccount,
	|		TableInventory.ProductsAndServices AS ProductsAndServices,
	|		TableInventory.Characteristic AS Characteristic,
	|		TableInventory.Batch AS Batch,
	|		TableInventory.CustomerOrder AS CustomerOrder
	|	FROM
	|		TemporaryTableInventory AS TableInventory
	|	WHERE
	|		TableInventory.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TableInventory.Company,
	|		TableInventory.StructuralUnit,
	|		TableInventory.GLAccount,
	|		TableInventory.ProductsAndServices,
	|		TableInventory.Characteristic,
	|		TableInventory.Batch,
	|		VALUE(Document.CustomerOrder.EmptyRef)
	|	FROM
	|		TemporaryTableInventory AS TableInventory) AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.CustomerOrder";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Inventory");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult in QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receiving inventory balances by cost.
	Query.Text = 	
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.CustomerOrder AS CustomerOrder,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.CustomerOrder AS CustomerOrder,
	|		SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|		SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) In
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.StructuralUnit,
	|						TableInventory.GLAccount,
	|						TableInventory.ProductsAndServices,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.CustomerOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory
	|					WHERE
	|						TableInventory.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef))) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.ProductsAndServices,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.CustomerOrder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.ProductsAndServices,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.CustomerOrder,
	|		SUM(InventoryBalances.QuantityBalance),
	|		SUM(InventoryBalances.AmountBalance)
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) In
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.StructuralUnit,
	|						TableInventory.GLAccount,
	|						TableInventory.ProductsAndServices,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						VALUE(Document.CustomerOrder.EmptyRef)
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.ProductsAndServices,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.CustomerOrder
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
	|		DocumentRegisterRecordsInventory.CustomerOrder,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.ProductsAndServices,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.CustomerOrder";
	
	Query.SetParameter("Ref", DocumentRefInventoryAssembly);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,ProductsAndServices,Characteristic,Batch,CustomerOrder");
	
	AmountForTransfer = 0;
	RowOfTableInventoryToBeTransferred = Undefined;
	TablesProductsToBeTransferred = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory.CopyColumns();
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", RowTableInventory.GLAccount);
		StructureForSearch.Insert("ProductsAndServices", RowTableInventory.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		
		QuantityRequiredReserve = RowTableInventory.Reserve;
		QuantityRequiredAvailableBalance = RowTableInventory.Quantity;
		
		If QuantityRequiredReserve > 0 Then
			
			QuantityRequiredAvailableBalance = QuantityRequiredAvailableBalance - QuantityRequiredReserve;
			
			StructureForSearch.Insert("CustomerOrder", RowTableInventory.CustomerOrder);
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredReserve Then

				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredReserve / QuantityBalance , 2, 1);

				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityRequiredReserve;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;

			ElsIf QuantityBalance = QuantityRequiredReserve Then

				AmountToBeWrittenOff = AmountBalance;

				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;

			Else
				AmountToBeWrittenOff = 0;	
			EndIf;
			
			AssemblyAmount = AssemblyAmount + AmountToBeWrittenOff;
	
			// Write inventory off the warehouse (production department).
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.ProductionExpenses = True;
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredReserve;
			
			// Assign written off stocks to either inventory cost in the warehouse, or to WIP costs.
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
					
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
				TableRowReceipt.CustomerOrder = RowTableInventory.CustomerCorrOrder;
					
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsAndServicesCorr = RowTableInventory.ProductsAndServices;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				TableRowReceipt.SpecificationCorr = RowTableInventory.Specification;
				TableRowReceipt.CustomerCorrOrder = RowTableInventory.CustomerOrder;
					
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = 0;
					
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				
				// Generate postings.
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
					FillPropertyValues(RowTableManagerial, TableRowReceipt);
				EndIf;
				
				// Inventory writeoff.
				AmountForTransfer = AmountForTransfer + AmountToBeWrittenOff;
				
			EndIf;
			
		EndIf;
		
		If QuantityRequiredAvailableBalance > 0 Then
			
			StructureForSearch.Insert("CustomerOrder", Documents.CustomerOrder.EmptyRef());
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredAvailableBalance Then

				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredAvailableBalance / QuantityBalance , 2, 1);

				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityRequiredAvailableBalance;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;

			ElsIf QuantityBalance = QuantityRequiredAvailableBalance Then

				AmountToBeWrittenOff = AmountBalance;

				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;

			Else
				AmountToBeWrittenOff = 0;	
			EndIf;
			
			AssemblyAmount = AssemblyAmount + AmountToBeWrittenOff;
	
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredAvailableBalance;
			TableRowExpense.ProductionExpenses = True;
			TableRowExpense.CustomerOrder = Documents.CustomerOrder.EmptyRef();
			
			// Receipt
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
					
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
				TableRowReceipt.CustomerOrder = RowTableInventory.CustomerCorrOrder;
					
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsAndServicesCorr = RowTableInventory.ProductsAndServices;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				TableRowReceipt.SpecificationCorr = RowTableInventory.Specification;
				TableRowReceipt.CustomerCorrOrder = Documents.CustomerOrder.EmptyRef();
					
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = 0;
					
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				
				// Generate postings.
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
					FillPropertyValues(RowTableManagerial, TableRowReceipt);
				EndIf;
				
				// Inventory writeoff.
				AmountForTransfer = AmountForTransfer + AmountToBeWrittenOff;
				
			EndIf;
			
		EndIf;
		
		// Inventory writeoff.
		RowOfTableInventoryToBeTransferred = RowTableInventory;
		
		If AmountForTransfer > 0 
			AND RowOfTableInventoryToBeTransferred <> Undefined 
			AND ValueIsFilled(RowOfTableInventoryToBeTransferred.ProductsStructuralUnit) Then
			
			NewRow = TablesProductsToBeTransferred.Add();
			FillPropertyValues(NewRow, RowOfTableInventoryToBeTransferred);
			NewRow.Amount = AmountForTransfer;
			
		EndIf;
		
		AmountForTransfer = 0;
		
	EndDo;
	
	If TablesProductsToBeTransferred.Count() > 1 Then
		TablesProductsToBeTransferred.GroupBy("Company,Period,PlanningPeriod,ProductsStructuralUnit,ProductionExpenses,CustomerCorrOrder,ProductsAndServicesCorr,BatchCorr,StructuralUnitCorr,CorrGLAccount,CharacteristicCorr,ProductsAccountDr,ProductsAccountCr,ProductsGLAccount","Amount");
	EndIf;
	
	// Inventory writeoff.
	For Each StringProductsToBeTransferred IN TablesProductsToBeTransferred Do
	
		// Expense.
		TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowExpense, StringProductsToBeTransferred);
		
		TableRowExpense.RecordType = AccumulationRecordType.Expense;
		
		TableRowExpense.StructuralUnit = StringProductsToBeTransferred.StructuralUnitCorr;
		TableRowExpense.GLAccount = StringProductsToBeTransferred.CorrGLAccount;
		TableRowExpense.ProductsAndServices = StringProductsToBeTransferred.ProductsAndServicesCorr;
		TableRowExpense.Characteristic = StringProductsToBeTransferred.CharacteristicCorr;
		TableRowExpense.Batch = StringProductsToBeTransferred.BatchCorr;
		TableRowExpense.Specification = Undefined;
		TableRowExpense.CustomerOrder = StringProductsToBeTransferred.CustomerCorrOrder;
		
		TableRowExpense.StructuralUnitCorr = StringProductsToBeTransferred.ProductsStructuralUnit;
		TableRowExpense.CorrGLAccount = StringProductsToBeTransferred.ProductsGLAccount;
		TableRowExpense.ProductsAndServicesCorr = StringProductsToBeTransferred.ProductsAndServicesCorr;
		TableRowExpense.CharacteristicCorr = StringProductsToBeTransferred.CharacteristicCorr;
		TableRowExpense.BatchCorr = StringProductsToBeTransferred.BatchCorr;
		TableRowExpense.SpecificationCorr = Undefined;
		TableRowExpense.CustomerCorrOrder = StringProductsToBeTransferred.CustomerCorrOrder;
		
		TableRowExpense.Amount = StringProductsToBeTransferred.Amount;
		TableRowExpense.Quantity = 0;
		
		// Receipt.
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, StringProductsToBeTransferred);
		
		TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
		
		TableRowReceipt.StructuralUnit = StringProductsToBeTransferred.ProductsStructuralUnit;
		TableRowReceipt.GLAccount = StringProductsToBeTransferred.ProductsGLAccount;
		TableRowReceipt.ProductsAndServices = StringProductsToBeTransferred.ProductsAndServicesCorr;
		TableRowReceipt.Characteristic = StringProductsToBeTransferred.CharacteristicCorr;
		TableRowReceipt.Batch = StringProductsToBeTransferred.BatchCorr;
		TableRowReceipt.Specification = Undefined;
		TableRowReceipt.CustomerOrder = StringProductsToBeTransferred.CustomerCorrOrder;
		
		TableRowReceipt.AccountDr = StringProductsToBeTransferred.ProductsAccountDr;
		TableRowReceipt.AccountCr = StringProductsToBeTransferred.ProductsAccountCr;
		
		TableRowReceipt.StructuralUnitCorr = StringProductsToBeTransferred.StructuralUnitCorr;
		TableRowReceipt.CorrGLAccount = StringProductsToBeTransferred.CorrGLAccount;
		TableRowReceipt.ProductsAndServicesCorr = StringProductsToBeTransferred.ProductsAndServicesCorr;
		TableRowReceipt.CharacteristicCorr = StringProductsToBeTransferred.CharacteristicCorr;
		TableRowReceipt.BatchCorr = StringProductsToBeTransferred.BatchCorr;
		TableRowReceipt.SpecificationCorr = Undefined;
		TableRowReceipt.CustomerCorrOrder = StringProductsToBeTransferred.CustomerCorrOrder;
		
		TableRowReceipt.Amount = StringProductsToBeTransferred.Amount;
		TableRowReceipt.Quantity = 0;
		
		TableRowReceipt.ContentOfAccountingRecord = NStr("en='Inventory transfer';ru='Перемещение запасов'");
		TableRowReceipt.Content = NStr("en='Inventory transfer';ru='Перемещение запасов'");
		
		// Generate postings.
		RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
		FillPropertyValues(RowTableManagerial, TableRowReceipt);
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryInventory");
	TablesProductsToBeTransferred = Undefined;
	
EndProcedure // GenerateInventoryTableBuild()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryProductionTransfer(DocumentRefInventoryAssembly, StructureAdditionalProperties, AssemblyAmount)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnit AS StructuralUnitCorr,
	|	TableInventory.InventoryGLAccount AS GLAccount,
	|	TableInventory.GLAccount AS CorrGLAccount,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.ProductsAndServices AS ProductsAndServicesCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Characteristic AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Batch AS BatchCorr,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.SpecificationCorr AS SpecificationCorr,
	|	TableInventory.CustomerOrder AS CustomerOrder,
	|	TableInventory.CustomerOrder AS CustomerCorrOrder,
	|	UNDEFINED AS SalesDocument,
	|	UNDEFINED AS OrderSales,
	|	UNDEFINED AS Department,
	|	UNDEFINED AS Responsible,
	|	TableInventory.GLAccount AS AccountDr,
	|	TableInventory.InventoryGLAccount AS AccountCr,
	|	&InventoryTransfer AS Content,
	|	&InventoryTransfer AS ContentOfAccountingRecord,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Reserve) AS Reserve,
	|	SUM(TableInventory.Amount) AS Amount,
	|	FALSE AS FixedCost
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PlanningPeriod,
	|	TableInventory.StructuralUnit,
	|	TableInventory.InventoryStructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.InventoryGLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Specification,
	|	TableInventory.SpecificationCorr,
	|	TableInventory.CustomerOrder,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.CustomerOrder,
	|	TableInventory.GLAccount,
	|	TableInventory.InventoryGLAccount";
	
	Query.SetParameter("InventoryTransfer", NStr("en='Inventory transfer';ru='Перемещение запасов'"));
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryMove", Query.Execute().Unload());
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text = 
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.CustomerOrder AS CustomerOrder
	|FROM
	|	(SELECT
	|		TableInventory.Company AS Company,
	|		TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|		TableInventory.InventoryGLAccount AS GLAccount,
	|		TableInventory.ProductsAndServices AS ProductsAndServices,
	|		TableInventory.Characteristic AS Characteristic,
	|		TableInventory.Batch AS Batch,
	|		TableInventory.CustomerOrder AS CustomerOrder
	|	FROM
	|		TemporaryTableInventory AS TableInventory
	|	WHERE
	|		TableInventory.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TableInventory.Company,
	|		TableInventory.InventoryStructuralUnit,
	|		TableInventory.InventoryGLAccount,
	|		TableInventory.ProductsAndServices,
	|		TableInventory.Characteristic,
	|		TableInventory.Batch,
	|		VALUE(Document.CustomerOrder.EmptyRef)
	|	FROM
	|		TemporaryTableInventory AS TableInventory) AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.CustomerOrder";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Inventory");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult in QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receiving inventory balances by cost.
	Query.Text = 	
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.CustomerOrder AS CustomerOrder,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.CustomerOrder AS CustomerOrder,
	|		SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|		SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) In
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|						TableInventory.InventoryGLAccount AS GLAccount,
	|						TableInventory.ProductsAndServices,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.CustomerOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory
	|					WHERE
	|						TableInventory.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef))) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.ProductsAndServices,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.CustomerOrder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.ProductsAndServices,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.CustomerOrder,
	|		SUM(InventoryBalances.QuantityBalance),
	|		SUM(InventoryBalances.AmountBalance)
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) In
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|						TableInventory.InventoryGLAccount AS GLAccount,
	|						TableInventory.ProductsAndServices,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						VALUE(Document.CustomerOrder.EmptyRef)
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.ProductsAndServices,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.CustomerOrder
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
	|		DocumentRegisterRecordsInventory.CustomerOrder,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.ProductsAndServices,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.CustomerOrder";
	
	Query.SetParameter("Ref", DocumentRefInventoryAssembly);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalancesMove = QueryResult.Unload();
	TableInventoryBalancesMove.Indexes.Add("Company,StructuralUnit,GLAccount,ProductsAndServices,Characteristic,Batch,CustomerOrder");
	
	TemporaryTableInventoryTransfer = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryMove.CopyColumns();
	
	IsEmptyStructuralUnit = Catalogs.StructuralUnits.EmptyRef();
	EmptyAccount = ChartsOfAccounts.Managerial.EmptyRef();
	EmptyProductsAndServices = Catalogs.ProductsAndServices.EmptyRef();
	EmptyCharacteristic = Catalogs.ProductsAndServicesCharacteristics.EmptyRef();
	EmptyBatch = Catalogs.ProductsAndServicesBatches.EmptyRef();
    EmptyCustomerOrder = Documents.CustomerOrder.EmptyRef();

	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryMove.Count() - 1 Do
		
		RowTableInventoryTransfer = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryMove[n];
		
		StructureForSearchTransfer = New Structure;
		StructureForSearchTransfer.Insert("Company", RowTableInventoryTransfer.Company);
		StructureForSearchTransfer.Insert("StructuralUnit", RowTableInventoryTransfer.StructuralUnit);
		StructureForSearchTransfer.Insert("GLAccount", RowTableInventoryTransfer.GLAccount);
		StructureForSearchTransfer.Insert("ProductsAndServices", RowTableInventoryTransfer.ProductsAndServices);
		StructureForSearchTransfer.Insert("Characteristic", RowTableInventoryTransfer.Characteristic);
		StructureForSearchTransfer.Insert("Batch", RowTableInventoryTransfer.Batch);
		
		QuantityRequiredReserveTransfer = RowTableInventoryTransfer.Reserve;
		QuantityRequiredAvailableBalanceTransfer = RowTableInventoryTransfer.Quantity;
		
		If QuantityRequiredReserveTransfer > 0 Then
			
			QuantityRequiredAvailableBalanceTransfer = QuantityRequiredAvailableBalanceTransfer - QuantityRequiredReserveTransfer;
			
			StructureForSearchTransfer.Insert("CustomerOrder", RowTableInventoryTransfer.CustomerOrder);
			
			BalanceRowsArrayDisplacement = TableInventoryBalancesMove.FindRows(StructureForSearchTransfer);
			
			QuantityBalanceDisplacement = 0;
			AmountBalanceMove = 0;
			
			If BalanceRowsArrayDisplacement.Count() > 0 Then
				QuantityBalanceDisplacement = BalanceRowsArrayDisplacement[0].QuantityBalance;
				AmountBalanceMove = BalanceRowsArrayDisplacement[0].AmountBalance;
			EndIf;
			
			If QuantityBalanceDisplacement > 0 AND QuantityBalanceDisplacement > QuantityRequiredReserveTransfer Then

				AmountToBeWrittenOffMove = Round(AmountBalanceMove * QuantityRequiredReserveTransfer / QuantityBalanceDisplacement , 2, 1);

				BalanceRowsArrayDisplacement[0].QuantityBalance = BalanceRowsArrayDisplacement[0].QuantityBalance - QuantityRequiredReserveTransfer;
				BalanceRowsArrayDisplacement[0].AmountBalance = BalanceRowsArrayDisplacement[0].AmountBalance - AmountToBeWrittenOffMove;

			ElsIf QuantityBalanceDisplacement = QuantityRequiredReserveTransfer Then

				AmountToBeWrittenOffMove = AmountBalanceMove;

				BalanceRowsArrayDisplacement[0].QuantityBalance = 0;
				BalanceRowsArrayDisplacement[0].AmountBalance = 0;

			Else
				AmountToBeWrittenOffMove = 0;	
			EndIf;
	
			// Expense.
			TableRowExpenseMove = TemporaryTableInventoryTransfer.Add();
			FillPropertyValues(TableRowExpenseMove, RowTableInventoryTransfer);
			
			TableRowExpenseMove.Specification = Undefined;
			TableRowExpenseMove.SpecificationCorr = Undefined;
			
			TableRowExpenseMove.Amount = AmountToBeWrittenOffMove;
			TableRowExpenseMove.Quantity = QuantityRequiredReserveTransfer;
												
			// Generate postings.
			If Round(AmountToBeWrittenOffMove, 2, 1) <> 0 Then
				RowTableManagerialMove = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
				FillPropertyValues(RowTableManagerialMove, RowTableInventoryTransfer);
				RowTableManagerialMove.Amount = AmountToBeWrittenOffMove;
			EndIf;
			
			// Receipt.
			If Round(AmountToBeWrittenOffMove, 2, 1) <> 0 OR QuantityRequiredReserveTransfer > 0 Then
									
				TableRowReceiptMove = TemporaryTableInventoryTransfer.Add();
				FillPropertyValues(TableRowReceiptMove, RowTableInventoryTransfer);
				
				TableRowReceiptMove.RecordType = AccumulationRecordType.Receipt;
				
				TableRowReceiptMove.Company = RowTableInventoryTransfer.Company;
				TableRowReceiptMove.StructuralUnit = RowTableInventoryTransfer.StructuralUnitCorr;
				TableRowReceiptMove.GLAccount = RowTableInventoryTransfer.CorrGLAccount;
				TableRowReceiptMove.ProductsAndServices = RowTableInventoryTransfer.ProductsAndServicesCorr;
				TableRowReceiptMove.Characteristic = RowTableInventoryTransfer.CharacteristicCorr;
				TableRowReceiptMove.Batch = RowTableInventoryTransfer.BatchCorr;
				TableRowReceiptMove.Specification = Undefined;
						
				TableRowReceiptMove.CustomerOrder = RowTableInventoryTransfer.CustomerCorrOrder;
								
				TableRowReceiptMove.StructuralUnitCorr = RowTableInventoryTransfer.StructuralUnit;
				TableRowReceiptMove.CorrGLAccount = RowTableInventoryTransfer.GLAccount;
				TableRowReceiptMove.ProductsAndServicesCorr = RowTableInventoryTransfer.ProductsAndServices;
				TableRowReceiptMove.CharacteristicCorr = RowTableInventoryTransfer.Characteristic;
				TableRowReceiptMove.BatchCorr = RowTableInventoryTransfer.Batch;
				TableRowReceiptMove.SpecificationCorr = Undefined;
				
				TableRowReceiptMove.CustomerCorrOrder = RowTableInventoryTransfer.CustomerOrder;
				
				TableRowReceiptMove.Amount = AmountToBeWrittenOffMove;
				
				TableRowReceiptMove.Quantity = QuantityRequiredReserveTransfer;
								
				TableRowReceiptMove.GLAccount = RowTableInventoryTransfer.CorrGLAccount;
				
			EndIf;
			
		EndIf;
		
		If QuantityRequiredAvailableBalanceTransfer > 0 Then
			
			StructureForSearchTransfer.Insert("CustomerOrder", EmptyCustomerOrder);
			
			BalanceRowsArrayDisplacement = TableInventoryBalancesMove.FindRows(StructureForSearchTransfer);
			
			QuantityBalanceDisplacement = 0;
			AmountBalanceMove = 0;
			
			If BalanceRowsArrayDisplacement.Count() > 0 Then
				QuantityBalanceDisplacement = BalanceRowsArrayDisplacement[0].QuantityBalance;
				AmountBalanceMove = BalanceRowsArrayDisplacement[0].AmountBalance;
			EndIf;
			
			If QuantityBalanceDisplacement > 0 AND QuantityBalanceDisplacement > QuantityRequiredAvailableBalanceTransfer Then

				AmountToBeWrittenOffMove = Round(AmountBalanceMove * QuantityRequiredAvailableBalanceTransfer / QuantityBalanceDisplacement , 2, 1);

				BalanceRowsArrayDisplacement[0].QuantityBalance = BalanceRowsArrayDisplacement[0].QuantityBalance - QuantityRequiredAvailableBalanceTransfer;
				BalanceRowsArrayDisplacement[0].AmountBalance = BalanceRowsArrayDisplacement[0].AmountBalance - AmountToBeWrittenOffMove;

			ElsIf QuantityBalanceDisplacement = QuantityRequiredAvailableBalanceTransfer Then

				AmountToBeWrittenOffMove = AmountBalanceMove;

				BalanceRowsArrayDisplacement[0].QuantityBalance = 0;
				BalanceRowsArrayDisplacement[0].AmountBalance = 0;

			Else
				AmountToBeWrittenOffMove = 0;	
			EndIf;
	
			// Expense.
			TableRowExpenseMove = TemporaryTableInventoryTransfer.Add();
			FillPropertyValues(TableRowExpenseMove, RowTableInventoryTransfer);
			
			TableRowExpenseMove.Amount = AmountToBeWrittenOffMove;
			TableRowExpenseMove.Quantity = QuantityRequiredAvailableBalanceTransfer;
			TableRowExpenseMove.CustomerOrder = EmptyCustomerOrder;
			TableRowExpenseMove.Specification = Undefined;
			TableRowExpenseMove.SpecificationCorr = Undefined;
			
			// Generate postings.
			If Round(AmountToBeWrittenOffMove, 2, 1) <> 0 Then
				RowTableManagerialMove = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
				FillPropertyValues(RowTableManagerialMove, RowTableInventoryTransfer);
				RowTableManagerialMove.Amount = AmountToBeWrittenOffMove;
			EndIf;
			
			// Receipt.
			If Round(AmountToBeWrittenOffMove, 2, 1) <> 0 OR QuantityRequiredAvailableBalanceTransfer > 0 Then
								
				TableRowReceiptMove = TemporaryTableInventoryTransfer.Add();
				FillPropertyValues(TableRowReceiptMove, RowTableInventoryTransfer);
				
				TableRowReceiptMove.RecordType = AccumulationRecordType.Receipt;
				
				TableRowReceiptMove.Company = RowTableInventoryTransfer.Company;
				TableRowReceiptMove.StructuralUnit = RowTableInventoryTransfer.StructuralUnitCorr;
				TableRowReceiptMove.GLAccount = RowTableInventoryTransfer.CorrGLAccount;
				TableRowReceiptMove.ProductsAndServices = RowTableInventoryTransfer.ProductsAndServicesCorr;
				TableRowReceiptMove.Characteristic = RowTableInventoryTransfer.CharacteristicCorr;
				TableRowReceiptMove.Batch = RowTableInventoryTransfer.BatchCorr;
				TableRowReceiptMove.Specification = Undefined;
				
				TableRowReceiptMove.CustomerOrder = RowTableInventoryTransfer.CustomerOrder;
								
				TableRowReceiptMove.StructuralUnitCorr = RowTableInventoryTransfer.StructuralUnit;
				TableRowReceiptMove.CorrGLAccount = RowTableInventoryTransfer.GLAccount;
				TableRowReceiptMove.ProductsAndServicesCorr = RowTableInventoryTransfer.ProductsAndServices;
				TableRowReceiptMove.CharacteristicCorr = RowTableInventoryTransfer.Characteristic;
				TableRowReceiptMove.BatchCorr = RowTableInventoryTransfer.Batch;
				TableRowReceiptMove.SpecificationCorr = Undefined;
				
				TableRowReceiptMove.CustomerCorrOrder = EmptyCustomerOrder;
				
				TableRowReceiptMove.Amount = AmountToBeWrittenOffMove;
				
				TableRowReceiptMove.Quantity = QuantityRequiredAvailableBalanceTransfer;
								
				TableRowReceiptMove.GLAccount = RowTableInventoryTransfer.CorrGLAccount;
						
			EndIf;
			
		EndIf;
					
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventoryMove = TemporaryTableInventoryTransfer;
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryMove.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryMove[n];
		
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, RowTableInventory);

	EndDo;	
	
	TemporaryTableInventoryTransfer.Indexes.Add("RecordType,Company,StructuralUnit,GLAccount,ProductsAndServices,Characteristic,Batch,CustomerOrder");
	
	AmountForTransfer = 0;
	RowOfTableInventoryToBeTransferred = Undefined;
	TablesProductsToBeTransferred = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory.CopyColumns();
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("RecordType", AccumulationRecordType.Receipt);
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", RowTableInventory.GLAccount);
		StructureForSearch.Insert("ProductsAndServices", RowTableInventory.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		
		QuantityRequiredReserve = RowTableInventory.Reserve;
		QuantityRequiredAvailableBalance = RowTableInventory.Quantity;
		
		If QuantityRequiredReserve > 0 Then
			
			QuantityRequiredAvailableBalance = QuantityRequiredAvailableBalance - QuantityRequiredReserve;
			
			StructureForSearch.Insert("CustomerOrder", RowTableInventory.CustomerOrder);
			
			ArrayQuantityBalance = 0;
			ArrayAmountBalance = 0;
			BalanceRowsArray = TemporaryTableInventoryTransfer.FindRows(StructureForSearch);
			For Each RowBalances IN BalanceRowsArray Do
				ArrayQuantityBalance = ArrayQuantityBalance + RowBalances.Quantity;
				ArrayAmountBalance = ArrayAmountBalance + RowBalances.Amount;
			EndDo;
			
			QuantityBalance = 0;
			AmountBalance = 0;
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].Quantity;
				AmountBalance = BalanceRowsArray[0].Amount;
				BalanceRowsArray[0].Quantity = ArrayQuantityBalance;
				BalanceRowsArray[0].Amount = ArrayAmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredReserve Then

				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredReserve / QuantityBalance , 2, 1);

				BalanceRowsArray[0].Quantity = BalanceRowsArray[0].Quantity - QuantityRequiredReserve;
				BalanceRowsArray[0].Amount = BalanceRowsArray[0].Amount - AmountToBeWrittenOff;

			ElsIf QuantityBalance = QuantityRequiredReserve Then

				AmountToBeWrittenOff = AmountBalance;

				BalanceRowsArray[0].Quantity = 0;
				BalanceRowsArray[0].Amount = 0;

			Else
				AmountToBeWrittenOff = 0;	
			EndIf;
			
			AssemblyAmount = AssemblyAmount + AmountToBeWrittenOff;
	
			// Write inventory off the warehouse (production department).
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.ProductionExpenses = True;
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredReserve;
			
			// Assign written off stocks to either inventory cost in the warehouse, or to WIP costs.
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
					
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.CustomerOrder = RowTableInventory.CustomerCorrOrder;
				TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
				
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsAndServicesCorr = RowTableInventory.ProductsAndServices;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				TableRowReceipt.CustomerCorrOrder = RowTableInventory.CustomerOrder;
				TableRowReceipt.SpecificationCorr = RowTableInventory.Specification;
				
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = 0;
					
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				
				// Generate postings.
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
					FillPropertyValues(RowTableManagerial, TableRowReceipt);
				EndIf;
				
				// Inventory writeoff.
				AmountForTransfer = AmountForTransfer + AmountToBeWrittenOff;
									
			EndIf;
			
		EndIf;
		
		If QuantityRequiredAvailableBalance > 0 Then
			
			StructureForSearch.Insert("CustomerOrder", RowTableInventory.CustomerOrder);
			
			ArrayQuantityBalance = 0;
			ArrayAmountBalance = 0;
			BalanceRowsArray = TemporaryTableInventoryTransfer.FindRows(StructureForSearch);
			For Each RowBalances IN BalanceRowsArray Do
				ArrayQuantityBalance = ArrayQuantityBalance + RowBalances.Quantity;
				ArrayAmountBalance = ArrayAmountBalance + RowBalances.Amount;
			EndDo;
			
			QuantityBalance = 0;
			AmountBalance = 0;
			If BalanceRowsArray.Count() > 0 Then
				BalanceRowsArray[0].Quantity = ArrayQuantityBalance;
				BalanceRowsArray[0].Amount = ArrayAmountBalance;
				QuantityBalance = BalanceRowsArray[0].Quantity;
				AmountBalance = BalanceRowsArray[0].Amount;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredAvailableBalance Then

				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredAvailableBalance / QuantityBalance , 2, 1);

				//// Changes
				BalanceRowsArray[0].Quantity = BalanceRowsArray[0].Quantity - QuantityRequiredAvailableBalance;
				BalanceRowsArray[0].Amount = BalanceRowsArray[0].Amount - AmountToBeWrittenOff;
				//// Changes
				
			ElsIf QuantityBalance = QuantityRequiredAvailableBalance Then

				AmountToBeWrittenOff = AmountBalance;

				BalanceRowsArray[0].Quantity = 0;
				BalanceRowsArray[0].Amount = 0;

			Else
				AmountToBeWrittenOff = 0;	
			EndIf;
			
			AssemblyAmount = AssemblyAmount + AmountToBeWrittenOff;
	
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredAvailableBalance;
			TableRowExpense.ProductionExpenses = True;
			TableRowExpense.CustomerOrder = RowTableInventory.CustomerOrder;
			
			// Receipt.
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
					
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.CustomerOrder = RowTableInventory.CustomerCorrOrder;
				TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
				
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsAndServicesCorr = RowTableInventory.ProductsAndServices;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				TableRowReceipt.CustomerCorrOrder = Documents.CustomerOrder.EmptyRef();
				TableRowReceipt.SpecificationCorr = RowTableInventory.Specification;
				
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = 0;
					
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				
				// Generate postings.
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
					FillPropertyValues(RowTableManagerial, TableRowReceipt);
				EndIf;
				
				// Inventory writeoff.
				AmountForTransfer = AmountForTransfer + AmountToBeWrittenOff;
				
			EndIf;
			
		EndIf;
		
		// Inventory writeoff.
		RowOfTableInventoryToBeTransferred = RowTableInventory;
		
		If AmountForTransfer > 0 
			AND RowOfTableInventoryToBeTransferred <> Undefined 
			AND ValueIsFilled(RowOfTableInventoryToBeTransferred.ProductsStructuralUnit) Then
			
			NewRow = TablesProductsToBeTransferred.Add();
			FillPropertyValues(NewRow, RowOfTableInventoryToBeTransferred);
			NewRow.Amount = AmountForTransfer;
			
		EndIf;
		
		AmountForTransfer = 0;
		
	EndDo;
	
	If TablesProductsToBeTransferred.Count() > 1 Then
		TablesProductsToBeTransferred.GroupBy("Company,Period,PlanningPeriod,ProductsStructuralUnit,ProductionExpenses,CustomerCorrOrder,ProductsAndServicesCorr,BatchCorr,StructuralUnitCorr,CorrGLAccount,CharacteristicCorr,ProductsAccountDr,ProductsAccountCr,ProductsGLAccount","Amount");
	EndIf;
	
	// Inventory writeoff.
	For Each StringProductsToBeTransferred IN TablesProductsToBeTransferred Do
	
		// Expense.
		TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowExpense, StringProductsToBeTransferred);
		
		TableRowExpense.RecordType = AccumulationRecordType.Expense;
		
		TableRowExpense.StructuralUnit = StringProductsToBeTransferred.StructuralUnitCorr;
		TableRowExpense.GLAccount = StringProductsToBeTransferred.CorrGLAccount;
		TableRowExpense.ProductsAndServices = StringProductsToBeTransferred.ProductsAndServicesCorr;
		TableRowExpense.Characteristic = StringProductsToBeTransferred.CharacteristicCorr;
		TableRowExpense.Batch = StringProductsToBeTransferred.BatchCorr;
		TableRowExpense.Specification = Undefined;
		TableRowExpense.CustomerOrder = StringProductsToBeTransferred.CustomerCorrOrder;
		
		TableRowExpense.StructuralUnitCorr = StringProductsToBeTransferred.ProductsStructuralUnit;
		TableRowExpense.CorrGLAccount = StringProductsToBeTransferred.ProductsGLAccount;
		TableRowExpense.ProductsAndServicesCorr = StringProductsToBeTransferred.ProductsAndServicesCorr;
		TableRowExpense.CharacteristicCorr = StringProductsToBeTransferred.CharacteristicCorr;
		TableRowExpense.BatchCorr = StringProductsToBeTransferred.BatchCorr;
		TableRowExpense.SpecificationCorr = Undefined;
		TableRowExpense.CustomerCorrOrder = StringProductsToBeTransferred.CustomerCorrOrder;
		
		TableRowExpense.Amount = StringProductsToBeTransferred.Amount;
		TableRowExpense.Quantity = 0;
		
		// Receipt.
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, StringProductsToBeTransferred);
		
		TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
		
		TableRowReceipt.StructuralUnit = StringProductsToBeTransferred.ProductsStructuralUnit;
		TableRowReceipt.GLAccount = StringProductsToBeTransferred.ProductsGLAccount;
		TableRowReceipt.ProductsAndServices = StringProductsToBeTransferred.ProductsAndServicesCorr;
		TableRowReceipt.Characteristic = StringProductsToBeTransferred.CharacteristicCorr;
		TableRowReceipt.Batch = StringProductsToBeTransferred.BatchCorr;
		TableRowReceipt.Specification = Undefined;
		TableRowReceipt.CustomerOrder = StringProductsToBeTransferred.CustomerCorrOrder;
		
		TableRowReceipt.AccountDr = StringProductsToBeTransferred.ProductsAccountDr;
		TableRowReceipt.AccountCr = StringProductsToBeTransferred.ProductsAccountCr;
		
		TableRowReceipt.StructuralUnitCorr = StringProductsToBeTransferred.StructuralUnitCorr;
		TableRowReceipt.CorrGLAccount = StringProductsToBeTransferred.CorrGLAccount;
		TableRowReceipt.ProductsAndServicesCorr = StringProductsToBeTransferred.ProductsAndServicesCorr;
		TableRowReceipt.CharacteristicCorr = StringProductsToBeTransferred.CharacteristicCorr;
		TableRowReceipt.BatchCorr = StringProductsToBeTransferred.BatchCorr;
		TableRowReceipt.SpecificationCorr = Undefined;
		TableRowReceipt.CustomerCorrOrder = StringProductsToBeTransferred.CustomerCorrOrder;
		
		TableRowReceipt.Amount = StringProductsToBeTransferred.Amount;
		TableRowReceipt.Quantity = 0;
		
		TableRowReceipt.ContentOfAccountingRecord = NStr("en='Inventory transfer';ru='Перемещение запасов'");
		TableRowReceipt.Content = NStr("en='Inventory transfer';ru='Перемещение запасов'");
		
		// Generate postings.
		RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
		FillPropertyValues(RowTableManagerial, TableRowReceipt);
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryInventory");
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryMove");
	TablesProductsToBeTransferred = Undefined;
	
EndProcedure // GenerateTableInventoryInventoryBuildTransfer()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryDemandAssembly(DocumentRefInventoryAssembly, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	TableInventoryDemand.Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	TableInventoryDemand.CustomerOrder AS CustomerOrder,
	|	TableInventoryDemand.ProductsAndServices AS ProductsAndServices,
	|	TableInventoryDemand.Characteristic AS Characteristic
	|FROM
	|	TemporaryTableInventory AS TableInventoryDemand";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.InventoryDemand");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult in QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Balance receipt
	Query.Text =
	"SELECT
	|	InventoryDemandBalances.Company AS Company,
	|	InventoryDemandBalances.CustomerOrder AS CustomerOrder,
	|	InventoryDemandBalances.ProductsAndServices AS ProductsAndServices,
	|	InventoryDemandBalances.Characteristic AS Characteristic,
	|	SUM(InventoryDemandBalances.Quantity) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryDemandBalances.Company AS Company,
	|		InventoryDemandBalances.CustomerOrder AS CustomerOrder,
	|		InventoryDemandBalances.ProductsAndServices AS ProductsAndServices,
	|		InventoryDemandBalances.Characteristic AS Characteristic,
	|		SUM(InventoryDemandBalances.QuantityBalance) AS Quantity
	|	FROM
	|		AccumulationRegister.InventoryDemand.Balance(
	|				&ControlTime,
	|				(Company, MovementType, CustomerOrder, ProductsAndServices, Characteristic) In
	|					(SELECT
	|						TemporaryTableInventory.Company AS Company,
	|						VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|						TemporaryTableInventory.CustomerOrder AS CustomerOrder,
	|						TemporaryTableInventory.ProductsAndServices AS ProductsAndServices,
	|						TemporaryTableInventory.Characteristic AS Characteristic
	|					FROM
	|						TemporaryTableInventory AS TemporaryTableInventory)) AS InventoryDemandBalances
	|	
	|	GROUP BY
	|		InventoryDemandBalances.Company,
	|		InventoryDemandBalances.CustomerOrder,
	|		InventoryDemandBalances.ProductsAndServices,
	|		InventoryDemandBalances.Characteristic
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventoryDemand.Company,
	|		DocumentRegisterRecordsInventoryDemand.CustomerOrder,
	|		DocumentRegisterRecordsInventoryDemand.ProductsAndServices,
	|		DocumentRegisterRecordsInventoryDemand.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventoryDemand.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.InventoryDemand AS DocumentRegisterRecordsInventoryDemand
	|	WHERE
	|		DocumentRegisterRecordsInventoryDemand.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventoryDemand.Period <= &ControlPeriod) AS InventoryDemandBalances
	|
	|GROUP BY
	|	InventoryDemandBalances.Company,
	|	InventoryDemandBalances.CustomerOrder,
	|	InventoryDemandBalances.ProductsAndServices,
	|	InventoryDemandBalances.Characteristic";
	
	Query.SetParameter("Ref", DocumentRefInventoryAssembly);
	
	If ValueIsFilled(DocumentRefInventoryAssembly.CustomerOrder) Then
		Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Else
		Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	EndIf;
	
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);
	
	QueryResult = Query.Execute();
	
	TableInventoryDemandBalance = QueryResult.Unload();
	TableInventoryDemandBalance.Indexes.Add("Company,CustomerOrder,ProductsAndServices,Characteristic");
	
	TemporaryTableInventoryDemand = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand.CopyColumns();
	
	For Each RowTablesForInventory IN StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", 		RowTablesForInventory.Company);
		StructureForSearch.Insert("CustomerOrder", 	RowTablesForInventory.CustomerOrder);
		StructureForSearch.Insert("ProductsAndServices", 	RowTablesForInventory.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", 	RowTablesForInventory.Characteristic);
		
		BalanceRowsArray = TableInventoryDemandBalance.FindRows(StructureForSearch);
		If BalanceRowsArray.Count() > 0 AND BalanceRowsArray[0].QuantityBalance > 0 Then
			
			If RowTablesForInventory.Quantity > BalanceRowsArray[0].QuantityBalance Then
				RowTablesForInventory.Quantity = BalanceRowsArray[0].QuantityBalance;
			EndIf;
			
			TableRowExpense = TemporaryTableInventoryDemand.Add();
			FillPropertyValues(TableRowExpense, RowTablesForInventory);
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand = TemporaryTableInventoryDemand;
	
EndProcedure // GenerateTableNeedForInventoryBuild()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateMaterialsDistributionTableAssembly(DocumentRefInventoryAssembly, StructureAdditionalProperties, TableProduction) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProduction.CorrLineNumber AS CorrLineNumber,
	|	TableProduction.ProductsAndServicesCorr AS ProductsAndServicesCorr,
	|	TableProduction.CharacteristicCorr AS CharacteristicCorr,
	|	TableProduction.BatchCorr AS BatchCorr,
	|	TableProduction.SpecificationCorr AS SpecificationCorr,
	|	TableProduction.CorrGLAccount AS CorrGLAccount,
	|	TableProduction.ProductsGLAccount AS ProductsGLAccount,
	|	TableProduction.AccountDr AS AccountDr,
	|	TableProduction.ProductsAccountDr AS ProductsAccountDr,
	|	TableProduction.ProductsAccountCr AS ProductsAccountCr,
	|	TableProduction.CorrQuantity AS CorrQuantity
	|INTO TemporaryTableVT
	|FROM
	|	&TableProduction AS TableProduction
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProductsContent.CorrLineNumber AS CorrLineNumber,
	|	TableProductsContent.ProductsAndServicesCorr AS ProductsAndServicesCorr,
	|	TableProductsContent.CharacteristicCorr AS CharacteristicCorr,
	|	TableProductsContent.BatchCorr AS BatchCorr,
	|	TableProductsContent.SpecificationCorr AS SpecificationCorr,
	|	TableProductsContent.CorrGLAccount AS CorrGLAccount,
	|	TableProductsContent.ProductsGLAccount AS ProductsGLAccount,
	|	TableProductsContent.AccountDr AS AccountDr,
	|	TableProductsContent.ProductsAccountDr AS ProductsAccountDr,
	|	TableProductsContent.ProductsAccountCr AS ProductsAccountCr,
	|	TableProductsContent.CorrQuantity AS CorrQuantity,
	|	CASE
	|		WHEN VALUETYPE(TableMaterials.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN CASE
	|					WHEN TableMaterials.Quantity = 0
	|						THEN 1
	|					ELSE TableMaterials.Quantity
	|				END / TableMaterials.ProductsQuantity * TableProductsContent.CorrQuantity
	|		ELSE CASE
	|				WHEN TableMaterials.Quantity = 0
	|					THEN 1
	|				ELSE TableMaterials.Quantity
	|			END * TableMaterials.MeasurementUnit.Factor / TableMaterials.ProductsQuantity * TableProductsContent.CorrQuantity
	|	END AS TMQuantity,
	|	TableMaterials.ContentRowType AS TMContentRowType,
	|	TableMaterials.ProductsAndServices AS TMProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS TMCharacteristic,
	|	TableMaterials.Specification AS TMSpecification,
	|	FALSE AS Distributed
	|FROM
	|	TemporaryTableVT AS TableProductsContent
	|		LEFT JOIN Catalog.Specifications.Content AS TableMaterials
	|		ON TableProductsContent.SpecificationCorr = TableMaterials.Ref
	|			AND (TableMaterials.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem))
	|
	|ORDER BY
	|	CorrLineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryAssemblyInventory.LineNumber AS LineNumber,
	|	InventoryAssemblyInventory.Ref.Date AS Period,
	|	InventoryAssemblyInventory.Ref.StructuralUnit AS StructuralUnit,
	|	InventoryAssemblyInventory.Ref.StructuralUnit.OrderWarehouse AS OrderWarehouse,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN InventoryAssemblyInventory.Ref.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	CASE
	|		WHEN InventoryAssemblyInventory.Ref.StructuralUnit = InventoryAssemblyInventory.Ref.InventoryStructuralUnit
	|			THEN VALUE(Catalog.StructuralUnits.EmptyRef)
	|		ELSE InventoryAssemblyInventory.Ref.InventoryStructuralUnit
	|	END AS InventoryStructuralUnit,
	|	InventoryAssemblyInventory.Ref.InventoryStructuralUnit AS StructuralUnitInventoryToWarehouse,
	|	InventoryAssemblyInventory.Ref.InventoryStructuralUnit.OrderWarehouse AS OrderWarehouseOfInventory,
	|	CASE
	|		WHEN InventoryAssemblyInventory.Ref.StructuralUnit = InventoryAssemblyInventory.Ref.ProductsStructuralUnit
	|			THEN VALUE(Catalog.StructuralUnits.EmptyRef)
	|		ELSE InventoryAssemblyInventory.Ref.ProductsStructuralUnit
	|	END AS ProductsStructuralUnit,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN InventoryAssemblyInventory.Ref.CellInventory
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS CellInventory,
	|	CASE
	|		WHEN InventoryAssemblyInventory.Batch.Status = VALUE(Enum.BatchStatuses.SafeCustody)
	|				OR InventoryAssemblyInventory.Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|				OR InventoryAssemblyInventory.Batch.Status = VALUE(Enum.BatchStatuses.CommissionMaterials)
	|			THEN InventoryAssemblyInventory.ProductsAndServices.InventoryGLAccount
	|		ELSE CASE
	|				WHEN InventoryAssemblyInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|					THEN InventoryAssemblyInventory.ProductsAndServices.InventoryGLAccount
	|				ELSE InventoryAssemblyInventory.ProductsAndServices.ExpensesGLAccount
	|			END
	|	END AS GLAccount,
	|	CASE
	|		WHEN InventoryAssemblyInventory.Batch.Status = VALUE(Enum.BatchStatuses.SafeCustody)
	|				OR InventoryAssemblyInventory.Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|				OR InventoryAssemblyInventory.Batch.Status = VALUE(Enum.BatchStatuses.CommissionMaterials)
	|			THEN InventoryAssemblyInventory.ProductsAndServices.InventoryGLAccount
	|		ELSE CASE
	|				WHEN InventoryAssemblyInventory.Ref.InventoryStructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|					THEN InventoryAssemblyInventory.ProductsAndServices.InventoryGLAccount
	|				ELSE InventoryAssemblyInventory.ProductsAndServices.ExpensesGLAccount
	|			END
	|	END AS InventoryGLAccount,
	|	VALUE(ChartOfAccounts.Managerial.EmptyRef) AS CorrGLAccount,
	|	VALUE(ChartOfAccounts.Managerial.EmptyRef) AS ProductsGLAccount,
	|	InventoryAssemblyInventory.ProductsAndServices AS ProductsAndServices,
	|	VALUE(Catalog.ProductsAndServices.EmptyRef) AS ProductsAndServicesCorr,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryAssemblyInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef) AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryAssemblyInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryAssemblyInventory.Batch.Status
	|		ELSE VALUE(Enum.BatchStatuses.EmptyRef)
	|	END AS BatchStatus,
	|	VALUE(Catalog.ProductsAndServicesBatches.EmptyRef) AS BatchCorr,
	|	VALUE(Catalog.Specifications.EmptyRef) AS SpecificationCorr,
	|	InventoryAssemblyInventory.Specification AS Specification,
	|	InventoryAssemblyInventory.Ref.CustomerOrder AS CustomerOrder,
	|	CASE
	|		WHEN VALUETYPE(InventoryAssemblyInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN InventoryAssemblyInventory.Quantity
	|		ELSE InventoryAssemblyInventory.Quantity * InventoryAssemblyInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CASE
	|		WHEN VALUETYPE(InventoryAssemblyInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN InventoryAssemblyInventory.Reserve
	|		ELSE InventoryAssemblyInventory.Reserve * InventoryAssemblyInventory.MeasurementUnit.Factor
	|	END AS Reserve,
	|	VALUE(ChartOfAccounts.Managerial.EmptyRef) AS AccountDr,
	|	VALUE(ChartOfAccounts.Managerial.EmptyRef) AS ProductsAccountDr,
	|	CASE
	|		WHEN InventoryAssemblyInventory.Batch.Status = VALUE(Enum.BatchStatuses.SafeCustody)
	|				OR InventoryAssemblyInventory.Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|				OR InventoryAssemblyInventory.Batch.Status = VALUE(Enum.BatchStatuses.CommissionMaterials)
	|			THEN InventoryAssemblyInventory.ProductsAndServices.InventoryGLAccount
	|		ELSE CASE
	|				WHEN InventoryAssemblyInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|					THEN InventoryAssemblyInventory.ProductsAndServices.InventoryGLAccount
	|				ELSE InventoryAssemblyInventory.ProductsAndServices.ExpensesGLAccount
	|			END
	|	END AS AccountCr,
	|	VALUE(ChartOfAccounts.Managerial.EmptyRef) AS ProductsAccountCr,
	|	FALSE AS Distributed
	|FROM
	|	Document.InventoryAssembly.Inventory AS InventoryAssemblyInventory
	|WHERE
	|	InventoryAssemblyInventory.Ref = &Ref
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("TableProduction", TableProduction);
	Query.SetParameter("Ref", DocumentRefInventoryAssembly);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("AccountingByCells", StructureAdditionalProperties.AccountingPolicy.AccountingByCells);
	
	ResultsArray = Query.ExecuteBatch();
	
	TableProductsContent = ResultsArray[1].Unload();
	MaterialsTable = ResultsArray[2].Unload();
	
	ProductsQuantity = TableProductsContent.Count();
	Ind = 0;
	While Ind < ProductsQuantity Do
		ProductsRow = TableProductsContent[Ind];
		If ProductsRow.TMContentRowType = Enums.SpecificationContentRowTypes.Node Then
			NodesSpecificationStack = New Array();
			FillProductsTableByNodsStructure(ProductsRow, TableProductsContent, NodesSpecificationStack);
			TableProductsContent.Delete(ProductsRow);
			If Ind + 1 = ProductsQuantity Then
				Break;
			EndIf;
		Else
			Ind = Ind + 1;
		EndIf;
	EndDo;
	TableProductsContent.GroupBy("ProductsAndServicesCorr,CharacteristicCorr,BatchCorr,SpecificationCorr,CorrGLAccount,ProductsGLAccount,AccountDr,ProductsAccountDr,ProductsAccountCr,CorrQuantity,TMProductsAndServices,TMCharacteristic,Distributed", "TMQuantity");
	TableProductsContent.Indexes.Add("TMProductsAndServices,TMCharacteristic");
	
	DistributedMaterials = 0;
	ProductsQuantity = TableProductsContent.Count();
	MaterialsAmount = MaterialsTable.Count();
	For n = 0 To MaterialsAmount - 1 Do
		
		StringMaterials = MaterialsTable[n];
		
		SearchStructure = New Structure;
		SearchStructure.Insert("TMProductsAndServices", StringMaterials.ProductsAndServices);
		SearchStructure.Insert("TMCharacteristic", StringMaterials.Characteristic);
		
		SearchResult = TableProductsContent.FindRows(SearchStructure);
		If SearchResult.Count() <> 0 Then
			DistributeMaterialsAccordingToNorms(StringMaterials, SearchResult, MaterialsTable);
			DistributedMaterials = DistributedMaterials + 1;
		EndIf;
		
	EndDo;
	
	DistributedProducts = 0;
	For Each ProductsContentRow IN TableProductsContent Do
		If ProductsContentRow.Distributed Then
			DistributedProducts = DistributedProducts + 1;
		EndIf;
	EndDo;
	
	If DistributedMaterials < MaterialsAmount Then
		If DistributedProducts = ProductsQuantity Then
			DistributionBase = TableProduction.Total("CorrQuantity");
			DistributeMaterialsByQuantity(TableProduction, MaterialsTable, DistributionBase);
		Else
			DistributeMaterialsByQuantity(TableProductsContent, MaterialsTable);
		EndIf;
	EndIf;
	
	TableProduction = Undefined;
	TableProductsContent = Undefined;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableMaterialsDistributionAssembly", MaterialsTable);
	MaterialsTable = Undefined;
	
EndProcedure // GenerateMaterialsAllocationTableBuild()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DataInitializationByProduction(DocumentRefInventoryAssembly, StructureAdditionalProperties, AssemblyAmount) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	InventoryAssemblyInventory.LineNumber AS LineNumber,
	|	InventoryAssemblyInventory.Period AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	InventoryAssemblyInventory.StructuralUnit AS StructuralUnit,
	|	InventoryAssemblyInventory.OrderWarehouse AS OrderWarehouse,
	|	InventoryAssemblyInventory.Cell AS Cell,
	|	InventoryAssemblyInventory.InventoryStructuralUnit AS InventoryStructuralUnit,
	|	InventoryAssemblyInventory.StructuralUnitInventoryToWarehouse AS StructuralUnitInventoryToWarehouse,
	|	InventoryAssemblyInventory.OrderWarehouseOfInventory AS OrderWarehouseOfInventory,
	|	InventoryAssemblyInventory.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	InventoryAssemblyInventory.CellInventory AS CellInventory,
	|	InventoryAssemblyInventory.GLAccount AS GLAccount,
	|	InventoryAssemblyInventory.InventoryGLAccount AS InventoryGLAccount,
	|	InventoryAssemblyInventory.CorrGLAccount AS CorrGLAccount,
	|	InventoryAssemblyInventory.ProductsGLAccount AS ProductsGLAccount,
	|	InventoryAssemblyInventory.ProductsAndServices AS ProductsAndServices,
	|	InventoryAssemblyInventory.ProductsAndServicesCorr AS ProductsAndServicesCorr,
	|	InventoryAssemblyInventory.Characteristic AS Characteristic,
	|	InventoryAssemblyInventory.CharacteristicCorr AS CharacteristicCorr,
	|	InventoryAssemblyInventory.Batch AS Batch,
	|	InventoryAssemblyInventory.BatchStatus AS BatchStatus,
	|	InventoryAssemblyInventory.BatchCorr AS BatchCorr,
	|	InventoryAssemblyInventory.Specification AS Specification,
	|	InventoryAssemblyInventory.SpecificationCorr AS SpecificationCorr,
	|	InventoryAssemblyInventory.CustomerOrder AS CustomerOrder,
	|	InventoryAssemblyInventory.Quantity AS Quantity,
	|	InventoryAssemblyInventory.Reserve AS Reserve,
	|	0 AS Amount,
	|	InventoryAssemblyInventory.AccountDr AS AccountDr,
	|	InventoryAssemblyInventory.ProductsAccountDr AS ProductsAccountDr,
	|	InventoryAssemblyInventory.AccountCr AS AccountCr,
	|	InventoryAssemblyInventory.ProductsAccountCr AS ProductsAccountCr,
	|	CAST(&InventoryDistribution AS String(100)) AS ContentOfAccountingRecord,
	|	CAST(&InventoryDistribution AS String(100)) AS Content,
	|	&UpdateDateToRelease_1_2_1 AS UpdateDateToRelease_1_2_1
	|INTO TemporaryTableInventory
	|FROM
	|	&TableMaterialsDistributionAssembly AS InventoryAssemblyInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnit AS StructuralUnitCorr,
	|	TableInventory.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.ProductsGLAccount AS ProductsGLAccount,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.ProductsAndServicesCorr AS ProductsAndServicesCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.SpecificationCorr AS SpecificationCorr,
	|	TableInventory.CustomerOrder AS CustomerOrder,
	|	TableInventory.CustomerOrder AS CustomerCorrOrder,
	|	TableInventory.AccountDr AS AccountDr,
	|	TableInventory.AccountCr AS AccountCr,
	|	TableInventory.ProductsAccountDr AS ProductsAccountDr,
	|	TableInventory.ProductsAccountCr AS ProductsAccountCr,
	|	TableInventory.ContentOfAccountingRecord AS Content,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS ProductionExpenses,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Reserve) AS Reserve,
	|	0 AS Amount
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PlanningPeriod,
	|	TableInventory.StructuralUnit,
	|	TableInventory.ProductsStructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.ProductsGLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.ProductsAndServicesCorr,
	|	TableInventory.Characteristic,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.Batch,
	|	TableInventory.BatchCorr,
	|	TableInventory.Specification,
	|	TableInventory.SpecificationCorr,
	|	TableInventory.CustomerOrder,
	|	TableInventory.AccountDr,
	|	TableInventory.AccountCr,
	|	TableInventory.ProductsAccountDr,
	|	TableInventory.ProductsAccountCr,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.StructuralUnit,
	|	TableInventory.CustomerOrder,
	|	TableInventory.ContentOfAccountingRecord
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnitInventoryToWarehouse AS InventoryStructuralUnit,
	|	TableInventory.CellInventory AS CellInventory,
	|	TableInventory.OrderWarehouse AS OrderWarehouse,
	|	TableInventory.OrderWarehouseOfInventory AS OrderWarehouseOfInventory,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Cell AS Cell,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.Period < TableInventory.UpdateDateToRelease_1_2_1
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitInventoryToWarehouse,
	|	TableInventory.CellInventory,
	|	TableInventory.OrderWarehouse,
	|	TableInventory.OrderWarehouseOfInventory,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Cell
	|
	|UNION ALL
	|
	|SELECT
	|	MIN(TableInventory.LineNumber),
	|	TableInventory.Period,
	|	VALUE(AccumulationRecordType.Expense),
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitInventoryToWarehouse,
	|	TableInventory.CellInventory,
	|	TableInventory.OrderWarehouse,
	|	TableInventory.OrderWarehouseOfInventory,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Cell,
	|	SUM(TableInventory.Quantity)
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	Not TableInventory.OrderWarehouse
	|	AND TableInventory.Period >= TableInventory.UpdateDateToRelease_1_2_1
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitInventoryToWarehouse,
	|	TableInventory.CellInventory,
	|	TableInventory.OrderWarehouse,
	|	TableInventory.OrderWarehouseOfInventory,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Cell
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.Period AS Period,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	CASE
	|		WHEN TableInventory.CustomerOrder = VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.CustomerOrder
	|	END AS Order,
	|	VALUE(Enum.ProductsReceiptTransferTypes.ReportByProcessing) AS ReceptionTransmissionType,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.BatchStatus = VALUE(Enum.BatchStatuses.CommissionMaterials)
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.Period,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	CASE
	|		WHEN TableInventory.CustomerOrder = VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.CustomerOrder
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	TableInventory.Company AS Company,
	|	TableInventory.CustomerOrder AS CustomerOrder,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.CustomerOrder,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnitInventoryToWarehouse AS StructuralUnit,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.OrderWarehouseOfInventory
	|	AND TableInventory.StructuralUnitInventoryToWarehouse <> TableInventory.StructuralUnit
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnitInventoryToWarehouse,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch
	|
	|UNION ALL
	|
	|SELECT
	|	MIN(TableInventory.LineNumber),
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	SUM(TableInventory.Quantity)
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.OrderWarehouse
	|	AND TableInventory.Period >= TableInventory.UpdateDateToRelease_1_2_1
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Company AS Company,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.OrderWarehouse
	|	AND TableInventory.StructuralUnitInventoryToWarehouse <> TableInventory.StructuralUnit
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.StructuralUnit,
	|	TableInventory.Company,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch
	|
	|UNION ALL
	|
	|SELECT
	|	MIN(TableInventory.LineNumber),
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableInventory.Period,
	|	TableInventory.StructuralUnit,
	|	TableInventory.Company,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	SUM(TableInventory.Quantity)
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.OrderWarehouse
	|	AND TableInventory.Period < TableInventory.UpdateDateToRelease_1_2_1
	|	AND TableInventory.StructuralUnitInventoryToWarehouse <> TableInventory.StructuralUnit
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.StructuralUnit,
	|	TableInventory.Company,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch";
	
	Query.SetParameter("Ref", DocumentRefInventoryAssembly);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("AccountingByCells", StructureAdditionalProperties.AccountingPolicy.AccountingByCells);
	Query.SetParameter("TableMaterialsDistributionAssembly", StructureAdditionalProperties.TableForRegisterRecords.TableMaterialsDistributionAssembly);
	
	// Temporarily: change motions by the order warehouse.
	UpdateDateToRelease_1_2_1 = Constants.UpdateDateToRelease_1_2_1.Get();
	Query.SetParameter("UpdateDateToRelease_1_2_1", UpdateDateToRelease_1_2_1);
	
	Query.SetParameter("InventoryDistribution", NStr("en='Inventory distribution';ru='Распределение запасов'"));
	
	ResultsArray = Query.ExecuteBatch();
	
	// Determine table for inventory accounting.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInventory", ResultsArray[1].Unload());

	// Generate table for inventory accounting.
	If ValueIsFilled(DocumentRefInventoryAssembly.InventoryStructuralUnit) 
		AND DocumentRefInventoryAssembly.InventoryStructuralUnit <> DocumentRefInventoryAssembly.StructuralUnit Then
		
		// Inventory autotransfer.
		GenerateTableInventoryProductionTransfer(DocumentRefInventoryAssembly, StructureAdditionalProperties, AssemblyAmount);
		
	Else
		
		GenerateTableInventoryProduction(DocumentRefInventoryAssembly, StructureAdditionalProperties, AssemblyAmount);
		
	EndIf;

	// Expand table for inventory.
	ResultsSelection = ResultsArray[2].Select();
	While ResultsSelection.Next() Do
		
		// Inventory autotransfer.
		If (ResultsSelection.InventoryStructuralUnit = ResultsSelection.StructuralUnit
			AND ResultsSelection.CellInventory <> ResultsSelection.Cell)
			OR ResultsSelection.InventoryStructuralUnit <> ResultsSelection.StructuralUnit Then
			
			// Expense.
			If (ResultsSelection.Period < UpdateDateToRelease_1_2_1)
				OR (ResultsSelection.Period >= UpdateDateToRelease_1_2_1
				AND Not ResultsSelection.OrderWarehouseOfInventory) Then
			
				TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
				FillPropertyValues(TableRowExpense, ResultsSelection);
			
				TableRowExpense.StructuralUnit = ResultsSelection.InventoryStructuralUnit;
				TableRowExpense.Cell = ResultsSelection.CellInventory;
				
			EndIf;
			
			// Receipt.
			If (ResultsSelection.Period < UpdateDateToRelease_1_2_1)
				OR (ResultsSelection.Period >= UpdateDateToRelease_1_2_1
				AND Not ResultsSelection.OrderWarehouse) Then
			
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
				FillPropertyValues(TableRowReceipt, ResultsSelection);
			
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
				
			EndIf;
			
		EndIf;
		
		TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
		FillPropertyValues(TableRowExpense, ResultsSelection);
		
	EndDo;
 
	// Determine a table of consumed raw material accepted for processing for which you will have to report in the future.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryReceived", ResultsArray[3].Unload());
	
	// Determine table for movement by the needs of dependent demand positions.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand", ResultsArray[4].Unload());
	GenerateTableInventoryDemandAssembly(DocumentRefInventoryAssembly, StructureAdditionalProperties);
	
	// Inventory autotransfer (expand the TableInventoryForWarehousesExpense table).
	ResultsSelection = ResultsArray[5].Select();
	While ResultsSelection.Next() Do
		
		TableRowExpenseReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryForExpenseFromWarehouses.Add();
		FillPropertyValues(TableRowExpenseReceipt, ResultsSelection);
		
	EndDo;
		
	// Inventory autotransfer (expand the TableInventoryForWarehouses table).
	ResultsSelection = ResultsArray[6].Select();
	While ResultsSelection.Next() Do
		
		TableRowExpenseReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryForWarehouses.Add();
		FillPropertyValues(TableRowExpenseReceipt, ResultsSelection);
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableMaterialsDistributionAssembly");
	
EndProcedure // InitializeDataByInventoryBuild()

////////////////////////////////////////////////////////////////////////////////
// PRODUCTION (BUILD)

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryProductsAssembly(DocumentRefInventoryAssembly, StructureAdditionalProperties, AssemblyAmount)
	
	StructureAdditionalProperties.TableForRegisterRecords.TableOrdersPlacement.Indexes.Add("RecordType,Company,ProductsAndServices,Characteristic");;
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Indexes.Add("RecordType,Company,ProductsAndServices,Characteristic,Batch,ProductsAndServicesCorr,CharacteristicCorr,BatchCorr,ProductionExpenses");;
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods.Count() - 1 Do
		
		RowTableInventoryProducts = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods[n];
		
		// Generate products release in terms of quantity. If customer order is specified - customer
		// customised if not - then for an empty order.
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, RowTableInventoryProducts);
		
		// Products autotransfer.
		GLAccountTransferring = Undefined;
		If ValueIsFilled(RowTableInventoryProducts.ProductsStructuralUnit) Then
			
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventoryProducts);
			
			TableRowExpense.RecordType = AccumulationRecordType.Expense;
			TableRowExpense.Specification = Undefined;
			
			TableRowExpense.StructuralUnitCorr = RowTableInventoryProducts.ProductsStructuralUnit;
			TableRowExpense.CorrGLAccount = RowTableInventoryProducts.ProductsGLAccount;
			
			TableRowExpense.ProductsAndServicesCorr = RowTableInventoryProducts.ProductsAndServices;
			TableRowExpense.CharacteristicCorr = RowTableInventoryProducts.Characteristic;
			TableRowExpense.BatchCorr = RowTableInventoryProducts.Batch;
			TableRowExpense.SpecificationCorr = Undefined;
			TableRowExpense.CustomerCorrOrder = RowTableInventoryProducts.CustomerOrder;
			
			TableRowExpense.ContentOfAccountingRecord = NStr("en='Inventory transfer';ru='Перемещение запасов'");
			TableRowExpense.Content = NStr("en='Inventory transfer';ru='Перемещение запасов'");
			
			// Receipt.
			TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowReceipt, RowTableInventoryProducts);
			
			TableRowReceipt.StructuralUnit = RowTableInventoryProducts.ProductsStructuralUnit;
			TableRowReceipt.GLAccount = RowTableInventoryProducts.ProductsGLAccount;
			TableRowReceipt.Specification = Undefined;
			
			GLAccountTransferring = TableRowReceipt.GLAccount;
			
			TableRowReceipt.StructuralUnitCorr = RowTableInventoryProducts.StructuralUnit;
			TableRowReceipt.CorrGLAccount = RowTableInventoryProducts.GLAccount;
			
			TableRowReceipt.ProductsAndServicesCorr = RowTableInventoryProducts.ProductsAndServices;
			TableRowReceipt.CharacteristicCorr = RowTableInventoryProducts.Characteristic;
			TableRowReceipt.BatchCorr = RowTableInventoryProducts.Batch;
			TableRowReceipt.SpecificationCorr = Undefined;
			TableRowReceipt.CustomerCorrOrder = RowTableInventoryProducts.CustomerOrder;
			
			TableRowReceipt.ContentOfAccountingRecord = NStr("en='Inventory transfer';ru='Перемещение запасов'");
			TableRowReceipt.Content = NStr("en='Inventory transfer';ru='Перемещение запасов'");
			
		EndIf;
		
		// If the production order is filled in and there is no
		// customer order, then check whether there are placed customers orders in the production order.
		If Not ValueIsFilled(RowTableInventoryProducts.CustomerOrder)
			AND ValueIsFilled(RowTableInventoryProducts.ProductionOrder) Then
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("RecordType", AccumulationRecordType.Expense);
			StructureForSearch.Insert("Company", RowTableInventoryProducts.Company);
			StructureForSearch.Insert("ProductsAndServices", RowTableInventoryProducts.ProductsAndServices);
			StructureForSearch.Insert("Characteristic", RowTableInventoryProducts.Characteristic);
			
			IndexOf = 0;
			OutputQuantity = RowTableInventoryProducts.Quantity;
			ArrayPropertiesProducts = StructureAdditionalProperties.TableForRegisterRecords.TableOrdersPlacement.FindRows(StructureForSearch);
			
			If ArrayPropertiesProducts.Count() = 0 Then
				Continue;
			EndIf;
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("RecordType", AccumulationRecordType.Receipt);
			StructureForSearch.Insert("Company", RowTableInventoryProducts.Company);
			StructureForSearch.Insert("ProductsAndServices", RowTableInventoryProducts.ProductsAndServices);
			StructureForSearch.Insert("Characteristic", RowTableInventoryProducts.Characteristic);
			StructureForSearch.Insert("Batch", RowTableInventoryProducts.Batch);
			StructureForSearch.Insert("ProductionExpenses", False);
			
			If ValueIsFilled(RowTableInventoryProducts.ProductsStructuralUnit) Then
				StructureForSearch.Insert("ProductsAndServicesCorr", RowTableInventoryProducts.ProductsAndServices);
				StructureForSearch.Insert("CharacteristicCorr", RowTableInventoryProducts.Characteristic);
				StructureForSearch.Insert("BatchCorr", RowTableInventoryProducts.Batch);
			EndIf;
			
			OutputCost = 0;
			ArrayCostOutputs = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.FindRows(StructureForSearch);
			For Each OutputRow IN ArrayCostOutputs Do
				OutputCost = OutputCost + OutputRow.Amount;
			EndDo;
			
			For Each StringAllocationArray IN ArrayPropertiesProducts Do
				
				OutputAmountToReserve = StringAllocationArray.Quantity;
				
				If OutputQuantity = OutputAmountToReserve Then
					OutputCostInReserve = OutputCost;
				Else
					OutputCostInReserve = Round(OutputCost * OutputAmountToReserve / OutputQuantity, 2, 1);
				EndIf;
				
				If OutputAmountToReserve > 0 Then
				
					TotalAmountToWriteOffByOrder = 0;
					
					AmountToBeWrittenOffByOrder = Round(OutputCostInReserve * StringAllocationArray.Quantity / OutputAmountToReserve, 2, 1);
					TotalAmountToWriteOffByOrder = TotalAmountToWriteOffByOrder + AmountToBeWrittenOffByOrder;
					
					If IndexOf = ArrayPropertiesProducts.Count() - 1 Then // It is the last string, it is required to correct amount.
						AmountToBeWrittenOffByOrder = AmountToBeWrittenOffByOrder + (OutputCostInReserve - TotalAmountToWriteOffByOrder);
					EndIf;
					
					TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowExpense, RowTableInventoryProducts);
					
					TableRowExpense.RecordType = AccumulationRecordType.Expense;
					
					If ValueIsFilled(RowTableInventoryProducts.ProductsStructuralUnit) Then
						TableRowExpense.StructuralUnit = RowTableInventoryProducts.ProductsStructuralUnit;
						TableRowExpense.StructuralUnitCorr = RowTableInventoryProducts.ProductsStructuralUnit;
						TableRowExpense.GLAccount = GLAccountTransferring;
						TableRowExpense.CorrGLAccount = GLAccountTransferring;
					Else
						TableRowExpense.StructuralUnit = RowTableInventoryProducts.StructuralUnit;
						TableRowExpense.StructuralUnitCorr = RowTableInventoryProducts.StructuralUnit;
						TableRowExpense.GLAccount = RowTableInventoryProducts.GLAccount;
						TableRowExpense.CorrGLAccount = RowTableInventoryProducts.GLAccount;
					EndIf;
					TableRowExpense.ProductsAndServicesCorr = RowTableInventoryProducts.ProductsAndServices;
					TableRowExpense.CharacteristicCorr = RowTableInventoryProducts.Characteristic;
					TableRowExpense.BatchCorr = RowTableInventoryProducts.Batch;
					TableRowExpense.SpecificationCorr = RowTableInventoryProducts.Specification;
					TableRowExpense.CustomerCorrOrder = StringAllocationArray.CustomerOrder;
					TableRowExpense.Quantity = StringAllocationArray.Quantity;
					TableRowExpense.Amount = AmountToBeWrittenOffByOrder;
					
					TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowReceipt, RowTableInventoryProducts);
					
					TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
					TableRowReceipt.CustomerOrder = StringAllocationArray.CustomerOrder;
					
					If ValueIsFilled(RowTableInventoryProducts.ProductsStructuralUnit) Then
						TableRowReceipt.StructuralUnit = RowTableInventoryProducts.ProductsStructuralUnit;
						TableRowReceipt.StructuralUnitCorr = RowTableInventoryProducts.ProductsStructuralUnit;
						TableRowReceipt.GLAccount = GLAccountTransferring;
						TableRowReceipt.CorrGLAccount = GLAccountTransferring;
					Else
						TableRowReceipt.StructuralUnit = RowTableInventoryProducts.StructuralUnit;
						TableRowReceipt.StructuralUnitCorr = RowTableInventoryProducts.StructuralUnit;
						TableRowReceipt.GLAccount = RowTableInventoryProducts.GLAccount;
						TableRowReceipt.CorrGLAccount = RowTableInventoryProducts.GLAccount;
					EndIf;
					TableRowReceipt.ProductsAndServicesCorr = RowTableInventoryProducts.ProductsAndServices;
					TableRowReceipt.CharacteristicCorr = RowTableInventoryProducts.Characteristic;
					TableRowReceipt.BatchCorr = RowTableInventoryProducts.Batch;
					TableRowReceipt.SpecificationCorr = RowTableInventoryProducts.Specification;
					TableRowReceipt.CustomerCorrOrder = RowTableInventoryProducts.CustomerOrder;
					TableRowReceipt.Quantity = StringAllocationArray.Quantity;
					TableRowReceipt.Amount = AmountToBeWrittenOffByOrder;
					
					IndexOf = IndexOf + 1;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryGoods");
	TableProductsAllocation = Undefined;
	
EndProcedure // GenerateTableInventoryProductionBuild()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableOrdersPlacementAssembly(DocumentRefInventoryAssembly, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Set exclusive lock of the controlled orders placement.
	Query.Text = 
	"SELECT
	|	TableProduction.Company AS Company,
	|	TableProduction.ProductsAndServices AS ProductsAndServices,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.SupplySource AS SupplySource
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.SupplySource <> UNDEFINED
	|
	|GROUP BY
	|	TableProduction.Company,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.SupplySource";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.OrdersPlacement");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult in QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receive balance.
	Query.Text = 	
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.Company AS Company,
	|	OrdersPlacementBalances.CustomerOrder AS CustomerOrder,
	|	TableProduction.ProductsAndServices AS ProductsAndServices,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.SupplySource AS SupplySource,
	|	CASE
	|		WHEN TableProduction.Quantity > ISNULL(OrdersPlacementBalances.Quantity, 0)
	|			THEN ISNULL(OrdersPlacementBalances.Quantity, 0)
	|		WHEN TableProduction.Quantity <= ISNULL(OrdersPlacementBalances.Quantity, 0)
	|			THEN TableProduction.Quantity
	|	END AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		LEFT JOIN (SELECT
	|			OrdersPlacementBalances.Company AS Company,
	|			OrdersPlacementBalances.ProductsAndServices AS ProductsAndServices,
	|			OrdersPlacementBalances.Characteristic AS Characteristic,
	|			OrdersPlacementBalances.CustomerOrder AS CustomerOrder,
	|			OrdersPlacementBalances.SupplySource AS SupplySource,
	|			SUM(OrdersPlacementBalances.QuantityBalance) AS Quantity
	|		FROM
	|			(SELECT
	|				OrdersPlacementBalances.Company AS Company,
	|				OrdersPlacementBalances.ProductsAndServices AS ProductsAndServices,
	|				OrdersPlacementBalances.Characteristic AS Characteristic,
	|				OrdersPlacementBalances.CustomerOrder AS CustomerOrder,
	|				OrdersPlacementBalances.SupplySource AS SupplySource,
	|				OrdersPlacementBalances.QuantityBalance AS QuantityBalance
	|			FROM
	|				AccumulationRegister.OrdersPlacement.Balance(
	|						&ControlTime,
	|						(Company, ProductsAndServices, Characteristic, SupplySource) In
	|							(SELECT
	|								TableProduction.Company AS Company,
	|								TableProduction.ProductsAndServices AS ProductsAndServices,
	|								TableProduction.Characteristic AS Characteristic,
	|								TableProduction.SupplySource AS SupplySource
	|							FROM
	|								TemporaryTableProduction AS TableProduction
	|							WHERE
	|								TableProduction.SupplySource <> UNDEFINED)) AS OrdersPlacementBalances
			
	|			UNION ALL
			
	|			SELECT
	|				DocumentRegisterRecordsOrdersPlacement.Company,
	|				DocumentRegisterRecordsOrdersPlacement.ProductsAndServices,
	|				DocumentRegisterRecordsOrdersPlacement.Characteristic,
	|				DocumentRegisterRecordsOrdersPlacement.CustomerOrder,
	|				DocumentRegisterRecordsOrdersPlacement.SupplySource,
	|				CASE
	|					WHEN DocumentRegisterRecordsOrdersPlacement.RecordType = VALUE(AccumulationRecordType.Expense)
	|						THEN ISNULL(DocumentRegisterRecordsOrdersPlacement.Quantity, 0)
	|					ELSE -ISNULL(DocumentRegisterRecordsOrdersPlacement.Quantity, 0)
	|				END
	|			FROM
	|				AccumulationRegister.OrdersPlacement AS DocumentRegisterRecordsOrdersPlacement
	|			WHERE
	|				DocumentRegisterRecordsOrdersPlacement.Recorder = &Ref
	|				AND DocumentRegisterRecordsOrdersPlacement.Period <= &ControlPeriod) AS OrdersPlacementBalances
		
	|		GROUP BY
	|			OrdersPlacementBalances.Company,
	|			OrdersPlacementBalances.ProductsAndServices,
	|			OrdersPlacementBalances.Characteristic,
	|			OrdersPlacementBalances.CustomerOrder,
	|			OrdersPlacementBalances.SupplySource) AS OrdersPlacementBalances
	|		ON TableProduction.Company = OrdersPlacementBalances.Company
	|			AND TableProduction.ProductsAndServices = OrdersPlacementBalances.ProductsAndServices
	|			AND TableProduction.Characteristic = OrdersPlacementBalances.Characteristic
	|			AND TableProduction.SupplySource = OrdersPlacementBalances.SupplySource
	|WHERE
	|	TableProduction.SupplySource <> UNDEFINED
	|	AND OrdersPlacementBalances.CustomerOrder IS Not NULL ";
	
	Query.SetParameter("Ref", DocumentRefInventoryAssembly);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);
	
	QueryResult = Query.Execute();

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableOrdersPlacement", QueryResult.Unload());
	
EndProcedure // GenerateTableOrdersPlacementBuild()

////////////////////////////////////////////////////////////////////////////////
// INVENTORY (DIASSEMBLY)

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInventoryDisassembly(DocumentRefInventoryAssembly, StructureAdditionalProperties, AssemblyAmount)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text =
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.CustomerOrder AS CustomerOrder
	|FROM
	|	(SELECT
	|		TableInventory.Company AS Company,
	|		TableInventory.StructuralUnit AS StructuralUnit,
	|		TableInventory.GLAccount AS GLAccount,
	|		TableInventory.ProductsAndServices AS ProductsAndServices,
	|		TableInventory.Characteristic AS Characteristic,
	|		TableInventory.Batch AS Batch,
	|		TableInventory.CustomerOrder AS CustomerOrder
	|	FROM
	|		TemporaryTableInventory AS TableInventory
	|	WHERE
	|		TableInventory.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TableInventory.Company,
	|		TableInventory.StructuralUnit,
	|		TableInventory.GLAccount,
	|		TableInventory.ProductsAndServices,
	|		TableInventory.Characteristic,
	|		TableInventory.Batch,
	|		VALUE(Document.CustomerOrder.EmptyRef)
	|	FROM
	|		TemporaryTableInventory AS TableInventory) AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.CustomerOrder";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Inventory");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult in QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receiving inventory balances by cost.
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.CustomerOrder AS CustomerOrder,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.CustomerOrder AS CustomerOrder,
	|		SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|		SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) In
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.StructuralUnit,
	|						TableInventory.GLAccount,
	|						TableInventory.ProductsAndServices,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.CustomerOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory
	|					WHERE
	|						TableInventory.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef))) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.ProductsAndServices,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.CustomerOrder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.ProductsAndServices,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.CustomerOrder,
	|		SUM(InventoryBalances.QuantityBalance),
	|		SUM(InventoryBalances.AmountBalance)
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) In
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.StructuralUnit,
	|						TableInventory.GLAccount,
	|						TableInventory.ProductsAndServices,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						VALUE(Document.CustomerOrder.EmptyRef)
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.ProductsAndServices,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.CustomerOrder
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
	|		DocumentRegisterRecordsInventory.CustomerOrder,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.ProductsAndServices,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.CustomerOrder";
	
	Query.SetParameter("Ref", DocumentRefInventoryAssembly);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,ProductsAndServices,Characteristic,Batch,CustomerOrder");
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", RowTableInventory.GLAccount);
		StructureForSearch.Insert("ProductsAndServices", RowTableInventory.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		
		ReserveRequired = RowTableInventory.Reserve;
		Required_Quantity = RowTableInventory.Quantity;
		
		If ReserveRequired > 0 Then
			
			Required_Quantity = Required_Quantity - ReserveRequired;
			
			StructureForSearch.Insert("CustomerOrder", RowTableInventory.CustomerOrder);
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
				
				AmountRequired = Round(BalanceRowsArray[0].AmountBalance * ReserveRequired / BalanceRowsArray[0].QuantityBalance,2,1);
				
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > ReserveRequired Then
				
				AmountToBeWrittenOff = Round(AmountBalance * ReserveRequired / QuantityBalance , 2, 1);
				
				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - ReserveRequired;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;
				
			ElsIf QuantityBalance = ReserveRequired Then
				
				AmountToBeWrittenOff = AmountBalance;
				
			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			AssemblyAmount = AssemblyAmount + AmountToBeWrittenOff;
			
			// Write inventory off the warehouse (production department).
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.ProductionExpenses = True;
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = ReserveRequired;
			
			// Assign written off stocks to either inventory cost in the warehouse, or to WIP costs.
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
				
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
				
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
				TableRowReceipt.CustomerOrder = RowTableInventory.CustomerCorrOrder;
				
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsAndServicesCorr = RowTableInventory.ProductsAndServices;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				TableRowReceipt.SpecificationCorr = RowTableInventory.Specification;
				TableRowReceipt.CustomerCorrOrder = RowTableInventory.CustomerOrder;
				
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = 0;
				
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				
				// Generate postings.
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
					FillPropertyValues(RowTableManagerial, TableRowReceipt);
				EndIf;
				
				// Inventory writeoff.
				If ValueIsFilled(RowTableInventory.ProductsStructuralUnit) Then
					
					// Expense.
					TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowExpense, RowTableInventory);
					
					TableRowExpense.StructuralUnit = RowTableInventory.StructuralUnitCorr;
					TableRowExpense.GLAccount = RowTableInventory.CorrGLAccount;
					TableRowExpense.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
					TableRowExpense.Characteristic = RowTableInventory.CharacteristicCorr;
					TableRowExpense.Batch = RowTableInventory.BatchCorr;
					TableRowExpense.Specification = Undefined;
					TableRowExpense.CustomerOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowExpense.StructuralUnitCorr = RowTableInventory.ProductsStructuralUnit;
					TableRowExpense.CorrGLAccount = RowTableInventory.ProductsGLAccount;
					TableRowExpense.ProductsAndServicesCorr = RowTableInventory.ProductsAndServicesCorr;
					TableRowExpense.CharacteristicCorr = RowTableInventory.CharacteristicCorr;
					TableRowExpense.BatchCorr = RowTableInventory.BatchCorr;
					TableRowExpense.SpecificationCorr = Undefined;
					TableRowExpense.CustomerCorrOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowExpense.Amount = AmountToBeWrittenOff;
					TableRowExpense.Quantity = 0;
					
					// Receipt.
					TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowReceipt, RowTableInventory);
					
					TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
					TableRowReceipt.StructuralUnit = RowTableInventory.ProductsStructuralUnit;
					TableRowReceipt.GLAccount = RowTableInventory.ProductsGLAccount;
					TableRowReceipt.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
					TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
					TableRowReceipt.Batch = RowTableInventory.BatchCorr;
					TableRowReceipt.Specification = Undefined;
					TableRowReceipt.CustomerOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowReceipt.AccountDr = RowTableInventory.ProductsAccountDr;
					
					TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnitCorr;
					TableRowReceipt.CorrGLAccount = RowTableInventory.CorrGLAccount;
					TableRowReceipt.ProductsAndServicesCorr = RowTableInventory.ProductsAndServicesCorr;
					TableRowReceipt.CharacteristicCorr = RowTableInventory.CharacteristicCorr;
					TableRowReceipt.BatchCorr = RowTableInventory.BatchCorr;
					TableRowReceipt.SpecificationCorr = Undefined;
					TableRowReceipt.CustomerCorrOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowReceipt.Amount = AmountToBeWrittenOff;
					TableRowReceipt.Quantity = 0;
					
					TableRowReceipt.ContentOfAccountingRecord = NStr("en='Inventory transfer';ru='Перемещение запасов'");
					TableRowReceipt.Content = NStr("en='Inventory transfer';ru='Перемещение запасов'");
					
					// Generate postings.
					If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
						RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
						FillPropertyValues(RowTableManagerial, TableRowReceipt);
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		If Required_Quantity > 0 Then
			
			StructureForSearch.Insert("CustomerOrder", Documents.CustomerOrder.EmptyRef());
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
				
				AmountRequired = Round(BalanceRowsArray[0].AmountBalance * Required_Quantity / BalanceRowsArray[0].QuantityBalance,2,1);
				
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > Required_Quantity Then
				
				AmountToBeWrittenOff = Round(AmountBalance * Required_Quantity / QuantityBalance , 2, 1);
				
				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - Required_Quantity;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;
				
			ElsIf QuantityBalance = Required_Quantity Then
				
				AmountToBeWrittenOff = AmountBalance;
				
			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			AssemblyAmount = AssemblyAmount + AmountToBeWrittenOff;
			
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = Required_Quantity;
			TableRowExpense.ProductionExpenses = True;
			TableRowExpense.CustomerOrder = Documents.CustomerOrder.EmptyRef();
			
			// Receipt
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
				
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
				
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
				TableRowReceipt.CustomerOrder = RowTableInventory.CustomerCorrOrder;
				
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsAndServicesCorr = RowTableInventory.ProductsAndServices;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				TableRowReceipt.SpecificationCorr = RowTableInventory.Specification;
				TableRowReceipt.CustomerCorrOrder = Documents.CustomerOrder.EmptyRef();
				
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = 0;
				
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				
				// Generate postings.
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
					FillPropertyValues(RowTableManagerial, TableRowReceipt);
				EndIf;
				
				// Inventory writeoff.
				If ValueIsFilled(RowTableInventory.ProductsStructuralUnit) Then
					
					// Expense.
					TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowExpense, RowTableInventory);
					
					TableRowExpense.StructuralUnit = RowTableInventory.StructuralUnitCorr;
					TableRowExpense.GLAccount = RowTableInventory.CorrGLAccount;
					TableRowExpense.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
					TableRowExpense.Characteristic = RowTableInventory.CharacteristicCorr;
					TableRowExpense.Batch = RowTableInventory.BatchCorr;
					TableRowExpense.Specification = Undefined;
					TableRowExpense.CustomerOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowExpense.StructuralUnitCorr = RowTableInventory.ProductsStructuralUnit;
					TableRowExpense.CorrGLAccount = RowTableInventory.ProductsGLAccount;
					TableRowExpense.ProductsAndServicesCorr = RowTableInventory.ProductsAndServicesCorr;
					TableRowExpense.CharacteristicCorr = RowTableInventory.CharacteristicCorr;
					TableRowExpense.BatchCorr = RowTableInventory.BatchCorr;
					TableRowExpense.SpecificationCorr = Undefined;
					TableRowExpense.CustomerCorrOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowExpense.Amount = AmountToBeWrittenOff;
					TableRowExpense.Quantity = 0;
					
					// Receipt.
					TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowReceipt, RowTableInventory);
					
					TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
					TableRowReceipt.StructuralUnit = RowTableInventory.ProductsStructuralUnit;
					TableRowReceipt.GLAccount = RowTableInventory.ProductsGLAccount;
					TableRowReceipt.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
					TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
					TableRowReceipt.Batch = RowTableInventory.BatchCorr;
					TableRowReceipt.Specification = Undefined;
					TableRowReceipt.CustomerOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowReceipt.AccountDr = RowTableInventory.ProductsAccountDr;
					
					TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnitCorr;
					TableRowReceipt.CorrGLAccount = RowTableInventory.CorrGLAccount;
					TableRowReceipt.ProductsAndServicesCorr = RowTableInventory.ProductsAndServicesCorr;
					TableRowReceipt.CharacteristicCorr = RowTableInventory.CharacteristicCorr;
					TableRowReceipt.BatchCorr = RowTableInventory.BatchCorr;
					TableRowReceipt.SpecificationCorr = Undefined;
					TableRowReceipt.CustomerCorrOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowReceipt.Amount = AmountToBeWrittenOff;
					TableRowReceipt.Quantity = 0;
					
					TableRowReceipt.ContentOfAccountingRecord = NStr("en='Inventory transfer';ru='Перемещение запасов'");
					TableRowReceipt.Content = NStr("en='Inventory transfer';ru='Перемещение запасов'");
					
					// Generate postings.
					If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
						RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
						FillPropertyValues(RowTableManagerial, TableRowReceipt);
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryInventory");
	
EndProcedure // GenerateTableInventoryInventoryDisassembly()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInventoryDisassemblyTransfer(DocumentRefInventoryAssembly, StructureAdditionalProperties, AssemblyAmount)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnit AS StructuralUnitCorr,
	|	TableInventory.InventoryGLAccount AS GLAccount,
	|	TableInventory.GLAccount AS CorrGLAccount,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.ProductsAndServices AS ProductsAndServicesCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Characteristic AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Batch AS BatchCorr,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.Specification AS SpecificationCorr,
	|	TableInventory.CustomerOrder AS CustomerOrder,
	|	TableInventory.CustomerOrder AS CustomerCorrOrder,
	|	UNDEFINED AS SalesDocument,
	|	UNDEFINED AS OrderSales,
	|	UNDEFINED AS Department,
	|	UNDEFINED AS Responsible,
	|	TableInventory.GLAccount AS AccountDr,
	|	TableInventory.InventoryGLAccount AS AccountCr,
	|	&InventoryTransfer AS Content,
	|	&InventoryTransfer AS ContentOfAccountingRecord,
	|	FALSE AS FixedCost,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Reserve) AS Reserve,
	|	TableInventory.Amount AS Amount
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.PlanningPeriod,
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.InventoryStructuralUnit,
	|	TableInventory.StructuralUnit,
	|	TableInventory.InventoryGLAccount,
	|	TableInventory.GLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Batch,
	|	TableInventory.Specification,
	|	TableInventory.Specification,
	|	TableInventory.CustomerOrder,
	|	TableInventory.CustomerOrder,
	|	TableInventory.GLAccount,
	|	TableInventory.InventoryGLAccount,
	|	TableInventory.Amount";
	
	Query.SetParameter("InventoryTransfer", NStr("en='Inventory transfer';ru='Перемещение запасов'"));
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryMove", Query.Execute().Unload());
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text = 
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.CustomerOrder AS CustomerOrder
	|FROM
	|	(SELECT
	|		TableInventory.Company AS Company,
	|		TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|		TableInventory.InventoryGLAccount AS GLAccount,
	|		TableInventory.ProductsAndServices AS ProductsAndServices,
	|		TableInventory.Characteristic AS Characteristic,
	|		TableInventory.Batch AS Batch,
	|		TableInventory.CustomerOrder AS CustomerOrder
	|	FROM
	|		TemporaryTableInventory AS TableInventory
	|	WHERE
	|		TableInventory.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TableInventory.Company,
	|		TableInventory.InventoryStructuralUnit,
	|		TableInventory.InventoryGLAccount,
	|		TableInventory.ProductsAndServices,
	|		TableInventory.Characteristic,
	|		TableInventory.Batch,
	|		VALUE(Document.CustomerOrder.EmptyRef)
	|	FROM
	|		TemporaryTableInventory AS TableInventory) AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.CustomerOrder";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Inventory");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult in QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receiving inventory balances by cost.
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.CustomerOrder AS CustomerOrder,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.CustomerOrder AS CustomerOrder,
	|		SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|		SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) In
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|						TableInventory.InventoryGLAccount AS GLAccount,
	|						TableInventory.ProductsAndServices,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.CustomerOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory
	|					WHERE
	|						TableInventory.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef))) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.ProductsAndServices,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.CustomerOrder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.ProductsAndServices,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.CustomerOrder,
	|		SUM(InventoryBalances.QuantityBalance),
	|		SUM(InventoryBalances.AmountBalance)
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, ProductsAndServices, Characteristic, Batch, CustomerOrder) In
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|						TableInventory.InventoryGLAccount AS GLAccount,
	|						TableInventory.ProductsAndServices,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						VALUE(Document.CustomerOrder.EmptyRef)
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.ProductsAndServices,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.CustomerOrder
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
	|		DocumentRegisterRecordsInventory.CustomerOrder,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.ProductsAndServices,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.CustomerOrder";
	
	Query.SetParameter("Ref", DocumentRefInventoryAssembly);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalancesMove = QueryResult.Unload();
	TableInventoryBalancesMove.Indexes.Add("Company,StructuralUnit,GLAccount,ProductsAndServices,Characteristic,Batch,CustomerOrder");
	
	TemporaryTableInventoryTransfer = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryMove.CopyColumns();
	
	IsEmptyStructuralUnit = Catalogs.StructuralUnits.EmptyRef();
	EmptyAccount = ChartsOfAccounts.Managerial.EmptyRef();
	EmptyProductsAndServices = Catalogs.ProductsAndServices.EmptyRef();
	EmptyCharacteristic = Catalogs.ProductsAndServicesCharacteristics.EmptyRef();
	EmptyBatch = Catalogs.ProductsAndServicesBatches.EmptyRef();
	EmptyCustomerOrder = Documents.CustomerOrder.EmptyRef();
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryMove.Count() - 1 Do
		
		RowTableInventoryTransfer = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryMove[n];
		
		StructureForSearchTransfer = New Structure;
		StructureForSearchTransfer.Insert("Company", RowTableInventoryTransfer.Company);
		StructureForSearchTransfer.Insert("StructuralUnit", RowTableInventoryTransfer.StructuralUnit);
		StructureForSearchTransfer.Insert("GLAccount", RowTableInventoryTransfer.GLAccount);
		StructureForSearchTransfer.Insert("ProductsAndServices", RowTableInventoryTransfer.ProductsAndServices);
		StructureForSearchTransfer.Insert("Characteristic", RowTableInventoryTransfer.Characteristic);
		StructureForSearchTransfer.Insert("Batch", RowTableInventoryTransfer.Batch);
		
		QuantityRequiredReserveTransfer = RowTableInventoryTransfer.Reserve;
		QuantityRequiredAvailableBalanceTransfer = RowTableInventoryTransfer.Quantity;
		
		If QuantityRequiredReserveTransfer > 0 Then
			
			QuantityRequiredAvailableBalanceTransfer = QuantityRequiredAvailableBalanceTransfer - QuantityRequiredReserveTransfer;
			
			StructureForSearchTransfer.Insert("CustomerOrder", RowTableInventoryTransfer.CustomerOrder);
			
			BalanceRowsArrayDisplacement = TableInventoryBalancesMove.FindRows(StructureForSearchTransfer);
			
			QuantityBalanceDisplacement = 0;
			AmountBalanceMove = 0;
			
			If BalanceRowsArrayDisplacement.Count() > 0 Then
				QuantityBalanceDisplacement = BalanceRowsArrayDisplacement[0].QuantityBalance;
				AmountBalanceMove = BalanceRowsArrayDisplacement[0].AmountBalance;
			EndIf;
			
			If QuantityBalanceDisplacement > 0 AND QuantityBalanceDisplacement > QuantityRequiredReserveTransfer Then
				
				AmountToBeWrittenOffMove = Round(AmountBalanceMove * QuantityRequiredReserveTransfer / QuantityBalanceDisplacement , 2, 1);
				
				BalanceRowsArrayDisplacement[0].QuantityBalance = BalanceRowsArrayDisplacement[0].QuantityBalance - QuantityRequiredReserveTransfer;
				BalanceRowsArrayDisplacement[0].AmountBalance = BalanceRowsArrayDisplacement[0].AmountBalance - AmountToBeWrittenOffMove;
				
			ElsIf QuantityBalanceDisplacement = QuantityRequiredReserveTransfer Then
				
				AmountToBeWrittenOffMove = AmountBalanceMove;
				
				BalanceRowsArrayDisplacement[0].QuantityBalance = 0;
				BalanceRowsArrayDisplacement[0].AmountBalance = 0;
				
			Else
				AmountToBeWrittenOffMove = 0;
			EndIf;
			
			// Expense.
			TableRowExpenseMove = TemporaryTableInventoryTransfer.Add();
			FillPropertyValues(TableRowExpenseMove, RowTableInventoryTransfer);
			
			TableRowExpenseMove.Specification = Undefined;
			TableRowExpenseMove.SpecificationCorr = Undefined;
			
			TableRowExpenseMove.Amount = AmountToBeWrittenOffMove;
			TableRowExpenseMove.Quantity = QuantityRequiredReserveTransfer;
			
			// Generate postings.
			If Round(AmountToBeWrittenOffMove, 2, 1) <> 0 Then
				RowTableManagerialMove = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
				FillPropertyValues(RowTableManagerialMove, RowTableInventoryTransfer);
				RowTableManagerialMove.Amount = AmountToBeWrittenOffMove;
			EndIf;
			
			// Receipt.
			If Round(AmountToBeWrittenOffMove, 2, 1) <> 0 OR QuantityRequiredReserveTransfer > 0 Then
				
				TableRowReceiptMove = TemporaryTableInventoryTransfer.Add();
				FillPropertyValues(TableRowReceiptMove, RowTableInventoryTransfer);
				
				TableRowReceiptMove.RecordType = AccumulationRecordType.Receipt;
				
				TableRowReceiptMove.Company = RowTableInventoryTransfer.Company;
				TableRowReceiptMove.StructuralUnit = RowTableInventoryTransfer.StructuralUnitCorr;
				TableRowReceiptMove.GLAccount = RowTableInventoryTransfer.CorrGLAccount;
				TableRowReceiptMove.ProductsAndServices = RowTableInventoryTransfer.ProductsAndServicesCorr;
				TableRowReceiptMove.Characteristic = RowTableInventoryTransfer.CharacteristicCorr;
				TableRowReceiptMove.Batch = RowTableInventoryTransfer.BatchCorr;
				TableRowReceiptMove.Specification = Undefined;
				
				TableRowReceiptMove.CustomerOrder = RowTableInventoryTransfer.CustomerCorrOrder;
				
				TableRowReceiptMove.StructuralUnitCorr = RowTableInventoryTransfer.StructuralUnit;
				TableRowReceiptMove.CorrGLAccount = RowTableInventoryTransfer.GLAccount;
				TableRowReceiptMove.ProductsAndServicesCorr = RowTableInventoryTransfer.ProductsAndServices;
				TableRowReceiptMove.CharacteristicCorr = RowTableInventoryTransfer.Characteristic;
				TableRowReceiptMove.BatchCorr = RowTableInventoryTransfer.Batch;
				TableRowReceiptMove.SpecificationCorr = Undefined;
				TableRowReceiptMove.CustomerCorrOrder = RowTableInventoryTransfer.CustomerOrder;
				
				TableRowReceiptMove.Amount = AmountToBeWrittenOffMove;
				
				TableRowReceiptMove.Quantity = QuantityRequiredReserveTransfer;
				
				TableRowReceiptMove.GLAccount = RowTableInventoryTransfer.CorrGLAccount;
				
			EndIf;
			
		EndIf;
		
		If QuantityRequiredAvailableBalanceTransfer > 0 Then
			
			StructureForSearchTransfer.Insert("CustomerOrder", EmptyCustomerOrder);
			
			BalanceRowsArrayDisplacement = TableInventoryBalancesMove.FindRows(StructureForSearchTransfer);
			
			QuantityBalanceDisplacement = 0;
			AmountBalanceMove = 0;
			
			If BalanceRowsArrayDisplacement.Count() > 0 Then
				QuantityBalanceDisplacement = BalanceRowsArrayDisplacement[0].QuantityBalance;
				AmountBalanceMove = BalanceRowsArrayDisplacement[0].AmountBalance;
			EndIf;
			
			If QuantityBalanceDisplacement > 0 AND QuantityBalanceDisplacement > QuantityRequiredAvailableBalanceTransfer Then
				
				AmountToBeWrittenOffMove = Round(AmountBalanceMove * QuantityRequiredAvailableBalanceTransfer / QuantityBalanceDisplacement , 2, 1);
				
				BalanceRowsArrayDisplacement[0].QuantityBalance = BalanceRowsArrayDisplacement[0].QuantityBalance - QuantityRequiredAvailableBalanceTransfer;
				BalanceRowsArrayDisplacement[0].AmountBalance = BalanceRowsArrayDisplacement[0].AmountBalance - AmountToBeWrittenOffMove;
				
			ElsIf QuantityBalanceDisplacement = QuantityRequiredAvailableBalanceTransfer Then
				
				AmountToBeWrittenOffMove = AmountBalanceMove;
				
				BalanceRowsArrayDisplacement[0].QuantityBalance = 0;
				BalanceRowsArrayDisplacement[0].AmountBalance = 0;
				
			Else
				AmountToBeWrittenOffMove = 0;
			EndIf;
			
			// Expense.
			TableRowExpenseMove = TemporaryTableInventoryTransfer.Add();
			FillPropertyValues(TableRowExpenseMove, RowTableInventoryTransfer);
			
			TableRowExpenseMove.Specification = Undefined;
			TableRowExpenseMove.SpecificationCorr = Undefined;
			
			TableRowExpenseMove.Amount = AmountToBeWrittenOffMove;
			TableRowExpenseMove.Quantity = QuantityRequiredAvailableBalanceTransfer;
			TableRowExpenseMove.CustomerOrder = EmptyCustomerOrder;
			
			// Generate postings.
			If Round(AmountToBeWrittenOffMove, 2, 1) <> 0 Then
				RowTableManagerialMove = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
				FillPropertyValues(RowTableManagerialMove, RowTableInventoryTransfer);
				RowTableManagerialMove.Amount = AmountToBeWrittenOffMove;
			EndIf;
			
			// Receipt
			If Round(AmountToBeWrittenOffMove, 2, 1) <> 0 OR QuantityRequiredAvailableBalanceTransfer > 0 Then
				
				TableRowReceiptMove = TemporaryTableInventoryTransfer.Add();
				FillPropertyValues(TableRowReceiptMove, RowTableInventoryTransfer);
				
				TableRowReceiptMove.RecordType = AccumulationRecordType.Receipt;
				
				TableRowReceiptMove.Company = RowTableInventoryTransfer.Company;
				TableRowReceiptMove.StructuralUnit = RowTableInventoryTransfer.StructuralUnitCorr;
				TableRowReceiptMove.GLAccount = RowTableInventoryTransfer.CorrGLAccount;
				TableRowReceiptMove.ProductsAndServices = RowTableInventoryTransfer.ProductsAndServicesCorr;
				TableRowReceiptMove.Characteristic = RowTableInventoryTransfer.CharacteristicCorr;
				TableRowReceiptMove.Batch = RowTableInventoryTransfer.BatchCorr;
				TableRowReceiptMove.Specification = Undefined;
				
				TableRowReceiptMove.CustomerOrder = RowTableInventoryTransfer.CustomerOrder;
				
				TableRowReceiptMove.StructuralUnitCorr = RowTableInventoryTransfer.StructuralUnit;
				TableRowReceiptMove.CorrGLAccount = RowTableInventoryTransfer.GLAccount;
				TableRowReceiptMove.ProductsAndServicesCorr = RowTableInventoryTransfer.ProductsAndServices;
				TableRowReceiptMove.CharacteristicCorr = RowTableInventoryTransfer.Characteristic;
				TableRowReceiptMove.BatchCorr = RowTableInventoryTransfer.Batch;
				TableRowReceiptMove.SpecificationCorr = Undefined;
				TableRowReceiptMove.CustomerCorrOrder = EmptyCustomerOrder;
				
				TableRowReceiptMove.Amount = AmountToBeWrittenOffMove;
				
				TableRowReceiptMove.Quantity = QuantityRequiredAvailableBalanceTransfer;
				
				TableRowReceiptMove.GLAccount = RowTableInventoryTransfer.CorrGLAccount;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventoryMove = TemporaryTableInventoryTransfer;
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryMove.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryMove[n];
		
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, RowTableInventory);
		
	EndDo;
	
	TemporaryTableInventoryTransfer.Indexes.Add("RecordType,Company,StructuralUnit,GLAccount,ProductsAndServices,Characteristic,Batch,CustomerOrder");
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("RecordType", AccumulationRecordType.Receipt);
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", RowTableInventory.GLAccount);
		StructureForSearch.Insert("ProductsAndServices", RowTableInventory.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		
		ReserveRequired = RowTableInventory.Reserve;
		Required_Quantity = RowTableInventory.Quantity;
		
		If ReserveRequired > 0 Then
			
			Required_Quantity = Required_Quantity - ReserveRequired;
			
			StructureForSearch.Insert("CustomerOrder", RowTableInventory.CustomerOrder);
			
			ArrayQuantityBalance = 0;
			ArrayAmountBalance = 0;
			BalanceRowsArray = TemporaryTableInventoryTransfer.FindRows(StructureForSearch);
			For Each RowBalances IN BalanceRowsArray Do
				ArrayQuantityBalance = ArrayQuantityBalance + RowBalances.Quantity;
				ArrayAmountBalance = ArrayAmountBalance + RowBalances.Amount;
			EndDo;
			
			QuantityBalance = 0;
			AmountBalance = 0;
			If BalanceRowsArray.Count() > 0 Then
				
				BalanceRowsArray[0].Quantity = ArrayQuantityBalance;
				BalanceRowsArray[0].Amount = ArrayAmountBalance;
				QuantityBalance = BalanceRowsArray[0].Quantity;
				AmountBalance = BalanceRowsArray[0].Amount;
				
				AmountRequired = Round(BalanceRowsArray[0].Amount * ReserveRequired / BalanceRowsArray[0].Quantity,2,1);
				
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > ReserveRequired Then
				
				AmountToBeWrittenOff = Round(AmountBalance * ReserveRequired / QuantityBalance , 2, 1);
				
				BalanceRowsArray[0].Quantity = BalanceRowsArray[0].Quantity - ReserveRequired;
				BalanceRowsArray[0].Amount = BalanceRowsArray[0].Amount - AmountToBeWrittenOff;
				
			ElsIf QuantityBalance = ReserveRequired Then
				
				AmountToBeWrittenOff = AmountBalance;
				
			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			AssemblyAmount = AssemblyAmount + AmountToBeWrittenOff;
			
			// Write inventory off the warehouse (production department).
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.ProductionExpenses = True;
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = ReserveRequired;
			
			// Assign written off stocks to either inventory cost in the warehouse, or to WIP costs.
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
				
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
				
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.CustomerOrder = RowTableInventory.CustomerCorrOrder;
				
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsAndServicesCorr = RowTableInventory.ProductsAndServices;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				TableRowReceipt.CustomerCorrOrder = RowTableInventory.CustomerOrder;
				
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = 0;
				
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				
				// Generate postings.
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
					FillPropertyValues(RowTableManagerial, TableRowReceipt);
				EndIf;
				
				// Inventory writeoff.
				If ValueIsFilled(RowTableInventory.ProductsStructuralUnit) Then
					
					// Expense.
					TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowExpense, RowTableInventory);
					
					TableRowExpense.StructuralUnit = RowTableInventory.StructuralUnitCorr;
					TableRowExpense.GLAccount = RowTableInventory.CorrGLAccount;
					TableRowExpense.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
					TableRowExpense.Characteristic = RowTableInventory.CharacteristicCorr;
					TableRowExpense.Batch = RowTableInventory.BatchCorr;
					TableRowExpense.Specification = Undefined;
					TableRowExpense.CustomerOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowExpense.StructuralUnitCorr = RowTableInventory.ProductsStructuralUnit;
					TableRowExpense.CorrGLAccount = RowTableInventory.ProductsGLAccount;
					TableRowExpense.ProductsAndServicesCorr = RowTableInventory.ProductsAndServicesCorr;
					TableRowExpense.CharacteristicCorr = RowTableInventory.CharacteristicCorr;
					TableRowExpense.BatchCorr = RowTableInventory.BatchCorr;
					TableRowExpense.SpecificationCorr = Undefined;
					TableRowExpense.CustomerCorrOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowExpense.Amount = AmountToBeWrittenOff;
					TableRowExpense.Quantity = 0;
					
					// Receipt.
					TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowReceipt, RowTableInventory);
					
					TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
					TableRowReceipt.StructuralUnit = RowTableInventory.ProductsStructuralUnit;
					TableRowReceipt.GLAccount = RowTableInventory.ProductsGLAccount;
					TableRowReceipt.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
					TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
					TableRowReceipt.Batch = RowTableInventory.BatchCorr;
					TableRowReceipt.Specification = Undefined;
					TableRowReceipt.CustomerOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowReceipt.AccountDr = RowTableInventory.ProductsAccountDr;
					
					TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnitCorr;
					TableRowReceipt.CorrGLAccount = RowTableInventory.CorrGLAccount;
					TableRowReceipt.ProductsAndServicesCorr = RowTableInventory.ProductsAndServicesCorr;
					TableRowReceipt.CharacteristicCorr = RowTableInventory.CharacteristicCorr;
					TableRowReceipt.BatchCorr = RowTableInventory.BatchCorr;
					TableRowReceipt.SpecificationCorr = Undefined;
					TableRowReceipt.CustomerCorrOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowReceipt.Amount = AmountToBeWrittenOff;
					TableRowReceipt.Quantity = 0;
					
					TableRowReceipt.ContentOfAccountingRecord = NStr("en='Inventory transfer';ru='Перемещение запасов'");
					TableRowReceipt.Content = NStr("en='Inventory transfer';ru='Перемещение запасов'");
					
					// Generate postings.
					If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
						RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
						FillPropertyValues(RowTableManagerial, TableRowReceipt);
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		If Required_Quantity > 0 Then
			
			StructureForSearch.Insert("CustomerOrder", RowTableInventory.CustomerOrder);
			
			ArrayQuantityBalance = 0;
			ArrayAmountBalance = 0;
			BalanceRowsArray = TemporaryTableInventoryTransfer.FindRows(StructureForSearch);
			For Each RowBalances IN BalanceRowsArray Do
				ArrayQuantityBalance = ArrayQuantityBalance + RowBalances.Quantity;
				ArrayAmountBalance = ArrayAmountBalance + RowBalances.Amount;
			EndDo;
			
			QuantityBalance = 0;
			AmountBalance = 0;
			If BalanceRowsArray.Count() > 0 Then
				
				BalanceRowsArray[0].Quantity = ArrayQuantityBalance;
				BalanceRowsArray[0].Amount = ArrayAmountBalance;
				QuantityBalance = BalanceRowsArray[0].Quantity;
				AmountBalance = BalanceRowsArray[0].Amount;
				
				AmountRequired = Round(BalanceRowsArray[0].Amount * Required_Quantity / BalanceRowsArray[0].Quantity,2,1);
				
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > Required_Quantity Then
				
				AmountToBeWrittenOff = Round(AmountBalance * Required_Quantity / QuantityBalance , 2, 1);
				
				BalanceRowsArray[0].Quantity = BalanceRowsArray[0].Quantity - Required_Quantity;
				BalanceRowsArray[0].Amount = BalanceRowsArray[0].Amount - AmountToBeWrittenOff;
				
			ElsIf QuantityBalance = Required_Quantity Then
				
				AmountToBeWrittenOff = AmountBalance;
				
			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			AssemblyAmount = AssemblyAmount + AmountToBeWrittenOff;
			
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = Required_Quantity;
			TableRowExpense.ProductionExpenses = True;
			TableRowExpense.CustomerOrder = RowTableInventory.CustomerOrder;
			
			// Receipt
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
				
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
				
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.CustomerOrder = RowTableInventory.CustomerCorrOrder;
				
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsAndServicesCorr = RowTableInventory.ProductsAndServices;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				TableRowReceipt.CustomerCorrOrder = Documents.CustomerOrder.EmptyRef();
				
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = 0;
				
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				
				// Generate postings.
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
					FillPropertyValues(RowTableManagerial, TableRowReceipt);
				EndIf;
				
				// Inventory writeoff.
				If ValueIsFilled(RowTableInventory.ProductsStructuralUnit) Then
					
					// Expense.
					TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowExpense, RowTableInventory);
					
					TableRowExpense.StructuralUnit = RowTableInventory.StructuralUnitCorr;
					TableRowExpense.GLAccount = RowTableInventory.CorrGLAccount;
					TableRowExpense.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
					TableRowExpense.Characteristic = RowTableInventory.CharacteristicCorr;
					TableRowExpense.Batch = RowTableInventory.BatchCorr;
					TableRowExpense.Specification = Undefined;
					TableRowExpense.CustomerOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowExpense.StructuralUnitCorr = RowTableInventory.ProductsStructuralUnit;
					TableRowExpense.CorrGLAccount = RowTableInventory.ProductsGLAccount;
					TableRowExpense.ProductsAndServicesCorr = RowTableInventory.ProductsAndServicesCorr;
					TableRowExpense.CharacteristicCorr = RowTableInventory.CharacteristicCorr;
					TableRowExpense.BatchCorr = RowTableInventory.BatchCorr;
					TableRowExpense.SpecificationCorr = Undefined;
					TableRowExpense.CustomerCorrOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowExpense.Amount = AmountToBeWrittenOff;
					TableRowExpense.Quantity = 0;
					
					// Receipt.
					TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowReceipt, RowTableInventory);
					
					TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
					TableRowReceipt.StructuralUnit = RowTableInventory.ProductsStructuralUnit;
					TableRowReceipt.GLAccount = RowTableInventory.ProductsGLAccount;
					TableRowReceipt.ProductsAndServices = RowTableInventory.ProductsAndServicesCorr;
					TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
					TableRowReceipt.Batch = RowTableInventory.BatchCorr;
					TableRowReceipt.Specification = Undefined;
					TableRowReceipt.CustomerOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowReceipt.AccountDr = RowTableInventory.ProductsAccountDr;
					TableRowReceipt.AccountCr = RowTableInventory.ProductsAccountCr;
					
					TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnitCorr;
					TableRowReceipt.CorrGLAccount = RowTableInventory.CorrGLAccount;
					TableRowReceipt.ProductsAndServicesCorr = RowTableInventory.ProductsAndServicesCorr;
					TableRowReceipt.CharacteristicCorr = RowTableInventory.CharacteristicCorr;
					TableRowReceipt.BatchCorr = RowTableInventory.BatchCorr;
					TableRowReceipt.SpecificationCorr = Undefined;
					TableRowReceipt.CustomerCorrOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowReceipt.Amount = AmountToBeWrittenOff;
					TableRowReceipt.Quantity = 0;
					
					TableRowReceipt.ContentOfAccountingRecord = NStr("en='Inventory transfer';ru='Перемещение запасов'");
					TableRowReceipt.Content = NStr("en='Inventory transfer';ru='Перемещение запасов'");
					
					// Generate postings.
					If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
						RowTableManagerial = StructureAdditionalProperties.TableForRegisterRecords.TableManagerial.Add();
						FillPropertyValues(RowTableManagerial, TableRowReceipt);
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryInventory");
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryMove");
	
EndProcedure // GenerateTableInventoryInventoryDisassemblyTransfer()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryDemandDisassembly(DocumentRefInventoryAssembly, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	TableInventoryDemand.Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	TableInventoryDemand.CustomerOrder AS CustomerOrder,
	|	TableInventoryDemand.ProductsAndServices AS ProductsAndServices,
	|	TableInventoryDemand.Characteristic AS Characteristic
	|FROM
	|	TemporaryTableInventory AS TableInventoryDemand";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.InventoryDemand");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult in QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();

	// Receive balance.
	Query.Text = 	
	"SELECT
	|	InventoryDemandBalances.Company AS Company,
	|	InventoryDemandBalances.CustomerOrder AS CustomerOrder,
	|	InventoryDemandBalances.ProductsAndServices AS ProductsAndServices,
	|	InventoryDemandBalances.Characteristic AS Characteristic,
	|	SUM(InventoryDemandBalances.Quantity) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryDemandBalances.Company AS Company,
	|		InventoryDemandBalances.CustomerOrder AS CustomerOrder,
	|		InventoryDemandBalances.ProductsAndServices AS ProductsAndServices,
	|		InventoryDemandBalances.Characteristic AS Characteristic,
	|		SUM(InventoryDemandBalances.QuantityBalance) AS Quantity
	|	FROM
	|		AccumulationRegister.InventoryDemand.Balance(
	|				&ControlTime,
	|				(Company, MovementType, CustomerOrder, ProductsAndServices, Characteristic) In
	|					(SELECT
	|						TemporaryTableInventory.Company AS Company,
	|						VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|						TemporaryTableInventory.CustomerOrder AS CustomerOrder,
	|						TemporaryTableInventory.ProductsAndServices AS ProductsAndServices,
	|						TemporaryTableInventory.Characteristic AS Characteristic
	|					FROM
	|						TemporaryTableInventory AS TemporaryTableInventory)) AS InventoryDemandBalances
	|	
	|	GROUP BY
	|		InventoryDemandBalances.Company,
	|		InventoryDemandBalances.CustomerOrder,
	|		InventoryDemandBalances.ProductsAndServices,
	|		InventoryDemandBalances.Characteristic
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventoryDemand.Company,
	|		DocumentRegisterRecordsInventoryDemand.CustomerOrder,
	|		DocumentRegisterRecordsInventoryDemand.ProductsAndServices,
	|		DocumentRegisterRecordsInventoryDemand.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventoryDemand.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.InventoryDemand AS DocumentRegisterRecordsInventoryDemand
	|	WHERE
	|		DocumentRegisterRecordsInventoryDemand.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventoryDemand.Period <= &ControlPeriod) AS InventoryDemandBalances
	|
	|GROUP BY
	|	InventoryDemandBalances.Company,
	|	InventoryDemandBalances.CustomerOrder,
	|	InventoryDemandBalances.ProductsAndServices,
	|	InventoryDemandBalances.Characteristic";
	
	Query.SetParameter("Ref", DocumentRefInventoryAssembly);
	
	If ValueIsFilled(DocumentRefInventoryAssembly.CustomerOrder) Then
		Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Else
		Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	EndIf;
	
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);
	
	QueryResult = Query.Execute();
	
	TableInventoryDemandBalance = QueryResult.Unload();
	TableInventoryDemandBalance.Indexes.Add("Company,CustomerOrder,ProductsAndServices,Characteristic");
	
	TemporaryTableInventoryDemand = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand.CopyColumns();
	
	For Each RowTablesForInventory IN StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", 		RowTablesForInventory.Company);
		StructureForSearch.Insert("CustomerOrder", 	RowTablesForInventory.CustomerOrder);
		StructureForSearch.Insert("ProductsAndServices", 	RowTablesForInventory.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", 	RowTablesForInventory.Characteristic);
		
		BalanceRowsArray = TableInventoryDemandBalance.FindRows(StructureForSearch);
		If BalanceRowsArray.Count() > 0 AND BalanceRowsArray[0].QuantityBalance > 0 Then
			
			If RowTablesForInventory.Quantity > BalanceRowsArray[0].QuantityBalance Then
				RowTablesForInventory.Quantity = BalanceRowsArray[0].QuantityBalance;
			EndIf;
			
			TableRowExpense = TemporaryTableInventoryDemand.Add();
			FillPropertyValues(TableRowExpense, RowTablesForInventory);
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand = TemporaryTableInventoryDemand;
	
EndProcedure // GenerateTableNeedForInventoryDisassembly()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateMaterialsDistributionTableDisassembly(DocumentRefInventoryAssembly, StructureAdditionalProperties, TableProduction) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProduction.ProductsAndServices AS ProductsAndServices,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.BatchStatus AS BatchStatus,
	|	TableProduction.Specification AS Specification,
	|	TableProduction.GLAccount AS GLAccount,
	|	TableProduction.InventoryGLAccount AS InventoryGLAccount,
	|	TableProduction.AccountCr AS AccountCr,
	|	TableProduction.Quantity AS Quantity,
	|	TableProduction.Reserve AS Reserve
	|INTO TemporaryTableVT
	|FROM
	|	&TableProduction AS TableProduction
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProductsContent.ProductsAndServices AS ProductsAndServices,
	|	TableProductsContent.Characteristic AS Characteristic,
	|	TableProductsContent.Batch AS Batch,
	|	TableProductsContent.BatchStatus AS BatchStatus,
	|	TableProductsContent.Specification AS Specification,
	|	TableProductsContent.GLAccount AS GLAccount,
	|	TableProductsContent.InventoryGLAccount AS InventoryGLAccount,
	|	TableProductsContent.AccountCr AS AccountCr,
	|	TableProductsContent.Quantity AS Quantity,
	|	TableProductsContent.Reserve AS Reserve,
	|	TableMaterials.ContentRowType AS TMContentRowType,
	|	1 AS CorrQuantity,
	|	1 AS TMQuantity,
	|	TableMaterials.ProductsAndServices AS TMProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS TMCharacteristic,
	|	TableMaterials.Specification AS TMSpecification
	|FROM
	|	TemporaryTableVT AS TableProductsContent
	|		LEFT JOIN Catalog.Specifications.Content AS TableMaterials
	|		ON TableProductsContent.Specification = TableMaterials.Ref
	|			AND (TableMaterials.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryAssemblyInventory.LineNumber AS LineNumber,
	|	InventoryAssemblyInventory.Ref.Date AS Period,
	|	InventoryAssemblyInventory.Ref.StructuralUnit AS StructuralUnit,
	|	InventoryAssemblyInventory.Ref.StructuralUnit.OrderWarehouse AS OrderWarehouse,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN InventoryAssemblyInventory.Ref.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	CASE
	|		WHEN InventoryAssemblyInventory.Ref.StructuralUnit = InventoryAssemblyInventory.Ref.InventoryStructuralUnit
	|			THEN VALUE(Catalog.StructuralUnits.EmptyRef)
	|		ELSE InventoryAssemblyInventory.Ref.InventoryStructuralUnit
	|	END AS InventoryStructuralUnit,
	|	InventoryAssemblyInventory.Ref.InventoryStructuralUnit AS StructuralUnitInventoryToWarehouse,
	|	InventoryAssemblyInventory.Ref.InventoryStructuralUnit.OrderWarehouse AS OrderWarehouseOfInventory,
	|	CASE
	|		WHEN InventoryAssemblyInventory.Ref.StructuralUnit = InventoryAssemblyInventory.Ref.ProductsStructuralUnit
	|			THEN VALUE(Catalog.StructuralUnits.EmptyRef)
	|		ELSE InventoryAssemblyInventory.Ref.ProductsStructuralUnit
	|	END AS ProductsStructuralUnit,
	|	InventoryAssemblyInventory.Ref.ProductsStructuralUnit.OrderWarehouse AS OrderWarehouseOfProducts,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN InventoryAssemblyInventory.Ref.CellInventory
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS CellInventory,
	|	VALUE(ChartOfAccounts.Managerial.EmptyRef) AS GLAccount,
	|	VALUE(ChartOfAccounts.Managerial.EmptyRef) AS InventoryGLAccount,
	|	CASE
	|		WHEN InventoryAssemblyInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|			THEN InventoryAssemblyInventory.ProductsAndServices.InventoryGLAccount
	|		ELSE InventoryAssemblyInventory.ProductsAndServices.ExpensesGLAccount
	|	END AS CorrGLAccount,
	|	CASE
	|		WHEN InventoryAssemblyInventory.Ref.ProductsStructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|			THEN InventoryAssemblyInventory.ProductsAndServices.InventoryGLAccount
	|		ELSE InventoryAssemblyInventory.ProductsAndServices.ExpensesGLAccount
	|	END AS ProductsGLAccount,
	|	VALUE(Catalog.ProductsAndServices.EmptyRef) AS ProductsAndServices,
	|	InventoryAssemblyInventory.ProductsAndServices AS ProductsAndServicesCorr,
	|	VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef) AS Characteristic,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryAssemblyInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS CharacteristicCorr,
	|	VALUE(Catalog.ProductsAndServicesBatches.EmptyRef) AS Batch,
	|	VALUE(Enum.BatchStatuses.EmptyRef) AS BatchStatus,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryAssemblyInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS BatchCorr,
	|	VALUE(Catalog.Specifications.EmptyRef) AS Specification,
	|	InventoryAssemblyInventory.Specification AS SpecificationCorr,
	|	InventoryAssemblyInventory.Ref.CustomerOrder AS CustomerOrder,
	|	0 AS Quantity,
	|	0 AS Reserve,
	|	0 AS Amount,
	|	CASE
	|		WHEN InventoryAssemblyInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|			THEN InventoryAssemblyInventory.ProductsAndServices.InventoryGLAccount
	|		ELSE InventoryAssemblyInventory.ProductsAndServices.ExpensesGLAccount
	|	END AS AccountDr,
	|	CASE
	|		WHEN InventoryAssemblyInventory.Ref.ProductsStructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|			THEN InventoryAssemblyInventory.ProductsAndServices.InventoryGLAccount
	|		ELSE InventoryAssemblyInventory.ProductsAndServices.ExpensesGLAccount
	|	END AS ProductsAccountDr,
	|	VALUE(ChartOfAccounts.Managerial.EmptyRef) AS AccountCr,
	|	CASE
	|		WHEN InventoryAssemblyInventory.Batch.Status = VALUE(Enum.BatchStatuses.SafeCustody)
	|				OR InventoryAssemblyInventory.Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|				OR InventoryAssemblyInventory.Batch.Status = VALUE(Enum.BatchStatuses.CommissionMaterials)
	|			THEN InventoryAssemblyInventory.ProductsAndServices.InventoryGLAccount
	|		ELSE CASE
	|				WHEN InventoryAssemblyInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|					THEN InventoryAssemblyInventory.ProductsAndServices.InventoryGLAccount
	|				ELSE InventoryAssemblyInventory.ProductsAndServices.ExpensesGLAccount
	|			END
	|	END AS ProductsAccountCr,
	|	InventoryAssemblyInventory.CostPercentage AS CostPercentage,
	|	FALSE AS NewRow,
	|	FALSE AS AccountExecuted,
	|	FALSE AS Distributed
	|FROM
	|	Document.InventoryAssembly.Inventory AS InventoryAssemblyInventory
	|WHERE
	|	InventoryAssemblyInventory.Ref = &Ref
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("TableProduction", TableProduction);
	Query.SetParameter("Ref", DocumentRefInventoryAssembly);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("AccountingByCells", StructureAdditionalProperties.AccountingPolicy.AccountingByCells);
	
	ResultsArray = Query.ExecuteBatch();
	
	TableProductsContent = ResultsArray[1].Unload();
	MaterialsTable = ResultsArray[2].Unload();
	
	ProductsQuantity = TableProductsContent.Count();
	Ind = 0;
	While Ind < ProductsQuantity Do
		ProductsRow = TableProductsContent[Ind];
		If ProductsRow.TMContentRowType = Enums.SpecificationContentRowTypes.Node Then
			NodesSpecificationStack = New Array();
			FillProductsTableByNodsStructure(ProductsRow, TableProductsContent, NodesSpecificationStack);
			TableProductsContent.Delete(ProductsRow);
			If Ind + 1 = ProductsQuantity Then
				Break;
			EndIf;
		Else
			Ind = Ind + 1;
		EndIf;
	EndDo;
	
	TableProductsContent.GroupBy("ProductsAndServices,Characteristic,Batch,BatchStatus,Specification,GLAccount,InventoryGLAccount,AccountCr,Quantity,Reserve,TMProductsAndServices,TMCharacteristic");
	TableProductsContent.Indexes.Add("ProductsAndServices,Characteristic,Batch,Specification");
	
	MaterialsTable.Indexes.Add("ProductsAndServicesCorr,CharacteristicCorr");
	
	DistributedProducts = 0;
	MaterialsAmount = MaterialsTable.Count();
	ProductsQuantity = TableProductsContent.Count();
	For Each StringProducts IN TableProduction Do
		
		SearchStructureProducts = New Structure;
		SearchStructureProducts.Insert("ProductsAndServices", StringProducts.ProductsAndServices);
		SearchStructureProducts.Insert("Characteristic", StringProducts.Characteristic);
		SearchStructureProducts.Insert("Batch", StringProducts.Batch);
		SearchStructureProducts.Insert("Specification", StringProducts.Specification);
		
		BaseCostPercentage = 0;
		SearchResultProducts = TableProductsContent.FindRows(SearchStructureProducts);
		For Each RowSearchProducts IN SearchResultProducts Do
			
			SearchStructureMaterials = New Structure;
			SearchStructureMaterials.Insert("NewRow", False);
			SearchStructureMaterials.Insert("ProductsAndServicesCorr", RowSearchProducts.TMProductsAndServices);
			SearchStructureMaterials.Insert("CharacteristicCorr", RowSearchProducts.TMCharacteristic);
			
			SearchResultMaterials = MaterialsTable.FindRows(SearchStructureMaterials);
			QuantityContentMaterials = SearchResultMaterials.Count();
			For Each RowSearchMaterials IN SearchResultMaterials Do
				StringProducts.Distributed = True;
				RowSearchMaterials.Distributed = True;
				RowSearchMaterials.AccountExecuted = True;
				BaseCostPercentage = BaseCostPercentage + RowSearchMaterials.CostPercentage;
			EndDo;
			
		EndDo;
		
		If BaseCostPercentage > 0 Then
			DistributeProductsAccordingToNorms(StringProducts, MaterialsTable, BaseCostPercentage);
		EndIf;
		
		If StringProducts.Distributed Then
			DistributedProducts = DistributedProducts + 1;
		EndIf;
		
	EndDo;
	
	DistributedMaterials = 0;
	For Each StringMaterials IN MaterialsTable Do
		If StringMaterials.Distributed AND Not StringMaterials.NewRow Then
			DistributedMaterials = DistributedMaterials + 1;
		EndIf;
	EndDo;
	
	If DistributedProducts < TableProduction.Count() Then
		If DistributedMaterials = MaterialsAmount Then
			BaseCostPercentage = MaterialsTable.Total("CostPercentage");
			DistributeProductsAccordingToQuantity(TableProduction, MaterialsTable, BaseCostPercentage, False);
		Else
			DistributeProductsAccordingToQuantity(TableProduction, MaterialsTable);
		EndIf;
	EndIf;
	
	TableProduction = Undefined;
	TableProductsContent = Undefined;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableOfMaterialsDistributionDisassembling", MaterialsTable);
	MaterialsTable = Undefined;
	
EndProcedure // GenerateMaterialsAllocationTableDisassembly()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DataInitializationByInventoryDisassembly(DocumentRefInventoryAssembly, StructureAdditionalProperties, AssemblyAmount) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	InventoryAssemblyInventory.LineNumber AS LineNumber,
	|	InventoryAssemblyInventory.Period AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	InventoryAssemblyInventory.StructuralUnit AS StructuralUnit,
	|	InventoryAssemblyInventory.OrderWarehouse AS OrderWarehouse,
	|	InventoryAssemblyInventory.Cell AS Cell,
	|	InventoryAssemblyInventory.InventoryStructuralUnit AS InventoryStructuralUnit,
	|	InventoryAssemblyInventory.StructuralUnitInventoryToWarehouse AS StructuralUnitInventoryToWarehouse,
	|	InventoryAssemblyInventory.OrderWarehouseOfInventory AS OrderWarehouseOfInventory,
	|	InventoryAssemblyInventory.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	InventoryAssemblyInventory.OrderWarehouseOfProducts AS OrderWarehouseOfProducts,
	|	InventoryAssemblyInventory.CellInventory AS CellInventory,
	|	InventoryAssemblyInventory.GLAccount AS GLAccount,
	|	InventoryAssemblyInventory.InventoryGLAccount AS InventoryGLAccount,
	|	InventoryAssemblyInventory.CorrGLAccount AS CorrGLAccount,
	|	InventoryAssemblyInventory.ProductsGLAccount AS ProductsGLAccount,
	|	InventoryAssemblyInventory.ProductsAndServices AS ProductsAndServices,
	|	InventoryAssemblyInventory.ProductsAndServicesCorr AS ProductsAndServicesCorr,
	|	InventoryAssemblyInventory.Characteristic AS Characteristic,
	|	InventoryAssemblyInventory.CharacteristicCorr AS CharacteristicCorr,
	|	InventoryAssemblyInventory.Batch AS Batch,
	|	InventoryAssemblyInventory.BatchStatus AS BatchStatus,
	|	InventoryAssemblyInventory.BatchCorr AS BatchCorr,
	|	InventoryAssemblyInventory.Specification AS Specification,
	|	InventoryAssemblyInventory.SpecificationCorr AS SpecificationCorr,
	|	InventoryAssemblyInventory.CustomerOrder AS CustomerOrder,
	|	InventoryAssemblyInventory.Quantity AS Quantity,
	|	InventoryAssemblyInventory.Reserve AS Reserve,
	|	0 AS Amount,
	|	InventoryAssemblyInventory.AccountDr AS AccountDr,
	|	InventoryAssemblyInventory.ProductsAccountDr AS ProductsAccountDr,
	|	InventoryAssemblyInventory.AccountCr AS AccountCr,
	|	InventoryAssemblyInventory.ProductsAccountCr AS ProductsAccountCr,
	|	InventoryAssemblyInventory.CostPercentage AS CostPercentage,
	|	CAST(&InventoryDistribution AS String(100)) AS ContentOfAccountingRecord,
	|	CAST(&InventoryDistribution AS String(100)) AS Content,
	|	&UpdateDateToRelease_1_2_1 AS UpdateDateToRelease_1_2_1
	|INTO TemporaryTableInventory
	|FROM
	|	&TableOfMaterialsDistributionDisassembling AS InventoryAssemblyInventory
	|WHERE
	|	InventoryAssemblyInventory.ProductsAndServices <> VALUE(Catalog.ProductsAndServices.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnit AS StructuralUnitCorr,
	|	TableInventory.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.ProductsGLAccount AS ProductsGLAccount,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.ProductsAndServicesCorr AS ProductsAndServicesCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.SpecificationCorr AS SpecificationCorr,
	|	TableInventory.CustomerOrder AS CustomerOrder,
	|	TableInventory.CustomerOrder AS CustomerCorrOrder,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS ProductionExpenses,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Reserve) AS Reserve,
	|	0 AS Amount,
	|	TableInventory.AccountDr AS AccountDr,
	|	TableInventory.AccountCr AS AccountCr,
	|	TableInventory.ProductsAccountDr AS ProductsAccountDr,
	|	TableInventory.ProductsAccountCr AS ProductsAccountCr,
	|	TableInventory.ContentOfAccountingRecord AS Content,
	|	TableInventory.CostPercentage AS CostPercentage
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PlanningPeriod,
	|	TableInventory.StructuralUnit,
	|	TableInventory.ProductsStructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.ProductsGLAccount,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.ProductsAndServicesCorr,
	|	TableInventory.Characteristic,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.Batch,
	|	TableInventory.BatchCorr,
	|	TableInventory.Specification,
	|	TableInventory.SpecificationCorr,
	|	TableInventory.CustomerOrder,
	|	TableInventory.AccountDr,
	|	TableInventory.AccountCr,
	|	TableInventory.ProductsAccountDr,
	|	TableInventory.ProductsAccountCr,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.CostPercentage,
	|	TableInventory.StructuralUnit,
	|	TableInventory.CustomerOrder,
	|	TableInventory.ContentOfAccountingRecord
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnitInventoryToWarehouse AS InventoryStructuralUnit,
	|	TableInventory.CellInventory AS CellInventory,
	|	TableInventory.OrderWarehouseOfProducts AS OrderWarehouseOfProducts,
	|	TableInventory.OrderWarehouse AS OrderWarehouse,
	|	TableInventory.OrderWarehouseOfInventory AS OrderWarehouseOfInventory,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Cell AS Cell,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.Period < TableInventory.UpdateDateToRelease_1_2_1
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitInventoryToWarehouse,
	|	TableInventory.CellInventory,
	|	TableInventory.OrderWarehouseOfProducts,
	|	TableInventory.OrderWarehouse,
	|	TableInventory.OrderWarehouseOfInventory,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Cell
	|
	|UNION ALL
	|
	|SELECT
	|	MIN(TableInventory.LineNumber),
	|	TableInventory.Period,
	|	VALUE(AccumulationRecordType.Expense),
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitInventoryToWarehouse,
	|	TableInventory.CellInventory,
	|	TableInventory.OrderWarehouseOfProducts,
	|	TableInventory.OrderWarehouse,
	|	TableInventory.OrderWarehouseOfInventory,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Cell,
	|	SUM(TableInventory.Quantity)
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	Not TableInventory.OrderWarehouse
	|	AND TableInventory.Period >= TableInventory.UpdateDateToRelease_1_2_1
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitInventoryToWarehouse,
	|	TableInventory.CellInventory,
	|	TableInventory.OrderWarehouseOfProducts,
	|	TableInventory.OrderWarehouse,
	|	TableInventory.OrderWarehouseOfInventory,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Cell
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.Period AS Period,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	CASE
	|		WHEN TableInventory.CustomerOrder = VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.CustomerOrder
	|	END AS Order,
	|	VALUE(Enum.ProductsReceiptTransferTypes.ReportByProcessing) AS ReceptionTransmissionType,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.BatchStatus = VALUE(Enum.BatchStatuses.CommissionMaterials)
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.Period,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	CASE
	|		WHEN TableInventory.CustomerOrder = VALUE(Document.CustomerOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.CustomerOrder
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	TableInventory.Company AS Company,
	|	TableInventory.CustomerOrder AS CustomerOrder,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.CustomerOrder,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnitInventoryToWarehouse AS StructuralUnit,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.OrderWarehouseOfInventory
	|	AND TableInventory.StructuralUnitInventoryToWarehouse <> TableInventory.StructuralUnit
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnitInventoryToWarehouse,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	SUM(TableInventory.Quantity)
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.OrderWarehouse
	|	AND TableInventory.Period >= TableInventory.UpdateDateToRelease_1_2_1
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Company AS Company,
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.OrderWarehouse
	|	AND TableInventory.StructuralUnitInventoryToWarehouse <> TableInventory.StructuralUnit
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.StructuralUnit,
	|	TableInventory.Company,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableInventory.Period,
	|	TableInventory.StructuralUnit,
	|	TableInventory.Company,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	SUM(TableInventory.Quantity)
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.OrderWarehouse
	|	AND TableInventory.Period < TableInventory.UpdateDateToRelease_1_2_1
	|	AND TableInventory.StructuralUnitInventoryToWarehouse <> TableInventory.StructuralUnit
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.StructuralUnit,
	|	TableInventory.Company,
	|	TableInventory.ProductsAndServices,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch";
	
	Query.SetParameter("Ref", DocumentRefInventoryAssembly);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("AccountingByCells", StructureAdditionalProperties.AccountingPolicy.AccountingByCells);
	Query.SetParameter("TableOfMaterialsDistributionDisassembling", StructureAdditionalProperties.TableForRegisterRecords.TableOfMaterialsDistributionDisassembling);
	
	// Temporarily: change motions by the order warehouse.
	UpdateDateToRelease_1_2_1 = Constants.UpdateDateToRelease_1_2_1.Get();
	Query.SetParameter("UpdateDateToRelease_1_2_1", UpdateDateToRelease_1_2_1);
	
	Query.SetParameter("InventoryDistribution", NStr("en='Inventory distribution';ru='Распределение запасов'"));
	Query.SetParameter("InventoryTransfer", NStr("en='Inventory transfer';ru='Перемещение запасов'"));
	
	ResultsArray = Query.ExecuteBatch();
	
	// Determine table for inventory accounting.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInventory", ResultsArray[1].Unload());
	
	// Generate table for inventory accounting.
	If ValueIsFilled(DocumentRefInventoryAssembly.InventoryStructuralUnit) 
		AND DocumentRefInventoryAssembly.InventoryStructuralUnit <> DocumentRefInventoryAssembly.StructuralUnit Then
		
		// Inventory autotransfer.
		GenerateTableInventoryInventoryDisassemblyTransfer(DocumentRefInventoryAssembly, StructureAdditionalProperties, AssemblyAmount);
		
	Else
		
		GenerateTableInventoryInventoryDisassembly(DocumentRefInventoryAssembly, StructureAdditionalProperties, AssemblyAmount);
		
	EndIf;
	
	// Expand table for inventory.
	ResultsSelection = ResultsArray[2].Select();
	While ResultsSelection.Next() Do
		
		// Inventory autotransfer.
		If (ResultsSelection.InventoryStructuralUnit = ResultsSelection.StructuralUnit
			AND ResultsSelection.CellInventory <> ResultsSelection.Cell)
			OR ResultsSelection.InventoryStructuralUnit <> ResultsSelection.StructuralUnit Then
			
			// Expense.
			If (ResultsSelection.Period < UpdateDateToRelease_1_2_1)
				OR (ResultsSelection.Period >= UpdateDateToRelease_1_2_1
				AND Not ResultsSelection.OrderWarehouseOfInventory) Then
				
				TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
				FillPropertyValues(TableRowExpense, ResultsSelection);
				
				TableRowExpense.StructuralUnit = ResultsSelection.InventoryStructuralUnit;
				TableRowExpense.Cell = ResultsSelection.CellInventory;
				
			EndIf;
			
			// Receipt.
			If (ResultsSelection.Period < UpdateDateToRelease_1_2_1)
				OR (ResultsSelection.Period >= UpdateDateToRelease_1_2_1
				AND Not ResultsSelection.OrderWarehouse) Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
				FillPropertyValues(TableRowReceipt, ResultsSelection);
				
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
				
			EndIf;
			
		EndIf;
		
		TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
		FillPropertyValues(TableRowExpense, ResultsSelection);
		
	EndDo;
	
	// Determine a table of consumed raw material accepted for processing for which you will have to report in the future.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryReceived", ResultsArray[3].Unload());
	
	// Determine table for movement by the needs of dependent demand positions.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand", ResultsArray[4].Unload());
	GenerateTableInventoryDemandDisassembly(DocumentRefInventoryAssembly, StructureAdditionalProperties);
	
	// Inventory autotransfer (expand the TableInventoryForWarehousesExpense table).
	ResultsSelection = ResultsArray[5].Select();
	While ResultsSelection.Next() Do
		
		TableRowExpenseReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryForExpenseFromWarehouses.Add();
		FillPropertyValues(TableRowExpenseReceipt, ResultsSelection);
		
	EndDo;
	
	// Inventory autotransfer (expand the TableInventoryForWarehouses table).
	ResultsSelection = ResultsArray[6].Select();
	While ResultsSelection.Next() Do
		
		TableRowExpenseReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryForWarehouses.Add();
		FillPropertyValues(TableRowExpenseReceipt, ResultsSelection);
		
	EndDo;
	
EndProcedure // InitializeDataByInventoryDisassembly()

////////////////////////////////////////////////////////////////////////////////
// PRODUCTION (DIASSEMBLY)

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryProductsDisassembly(DocumentRefInventoryAssembly, StructureAdditionalProperties, AssemblyAmount)
	
	StructureAdditionalProperties.TableForRegisterRecords.TableOrdersPlacement.Indexes.Add("RecordType,Company,ProductsAndServices,Characteristic");;
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Indexes.Add("RecordType,Company,ProductsAndServices,Characteristic,Batch,ProductsAndServicesCorr,CharacteristicCorr,BatchCorr,ProductionExpenses");;
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods.Count() - 1 Do
		
		RowTableInventoryProducts = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods[n];
		
		// Generate products release in terms of quantity. If customer order is specified - customer
		// customised if not - then for an empty order.
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, RowTableInventoryProducts);
		
		// Products autotransfer.
		GLAccountTransferring = Undefined;
		If ValueIsFilled(RowTableInventoryProducts.ProductsStructuralUnit) Then
			
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventoryProducts);
			
			TableRowExpense.RecordType = AccumulationRecordType.Expense;
			TableRowExpense.Specification = Undefined;
			
			TableRowExpense.StructuralUnitCorr = RowTableInventoryProducts.ProductsStructuralUnit;
			TableRowExpense.CorrGLAccount = RowTableInventoryProducts.ProductsGLAccount;
			
			TableRowExpense.ProductsAndServicesCorr = RowTableInventoryProducts.ProductsAndServices;
			TableRowExpense.CharacteristicCorr = RowTableInventoryProducts.Characteristic;
			TableRowExpense.BatchCorr = RowTableInventoryProducts.Batch;
			TableRowExpense.SpecificationCorr = Undefined;
			TableRowExpense.CustomerCorrOrder = RowTableInventoryProducts.CustomerOrder;
			
			TableRowExpense.ContentOfAccountingRecord = NStr("en='Inventory transfer';ru='Перемещение запасов'");
			TableRowExpense.Content = NStr("en='Inventory transfer';ru='Перемещение запасов'");
			
			// Receipt.
			TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowReceipt, RowTableInventoryProducts);
			
			TableRowReceipt.StructuralUnit = RowTableInventoryProducts.ProductsStructuralUnit;
			TableRowReceipt.GLAccount = RowTableInventoryProducts.ProductsGLAccount;
			TableRowReceipt.Specification = Undefined;
			
			GLAccountTransferring = TableRowReceipt.GLAccount;
			
			TableRowReceipt.StructuralUnitCorr = RowTableInventoryProducts.StructuralUnit;
			TableRowReceipt.CorrGLAccount = RowTableInventoryProducts.GLAccount;
			
			TableRowReceipt.ProductsAndServicesCorr = RowTableInventoryProducts.ProductsAndServices;
			TableRowReceipt.CharacteristicCorr = RowTableInventoryProducts.Characteristic;
			TableRowReceipt.BatchCorr = RowTableInventoryProducts.Batch;
			TableRowReceipt.SpecificationCorr = Undefined;
			TableRowReceipt.CustomerCorrOrder = RowTableInventoryProducts.CustomerOrder;
			
			TableRowReceipt.ContentOfAccountingRecord = NStr("en='Inventory transfer';ru='Перемещение запасов'");
			TableRowReceipt.Content = NStr("en='Inventory transfer';ru='Перемещение запасов'");
			
		EndIf;
		
		// If the production order is filled in and there is no
		// customer order, then check whether there are placed customers orders in the production order.
		If Not ValueIsFilled(RowTableInventoryProducts.CustomerOrder)
			AND ValueIsFilled(RowTableInventoryProducts.ProductionOrder) Then
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("RecordType", AccumulationRecordType.Expense);
			StructureForSearch.Insert("Company", RowTableInventoryProducts.Company);
			StructureForSearch.Insert("ProductsAndServices", RowTableInventoryProducts.ProductsAndServices);
			StructureForSearch.Insert("Characteristic", RowTableInventoryProducts.Characteristic);
			
			IndexOf = 0;
			OutputQuantity = RowTableInventoryProducts.Quantity;
			ArrayPropertiesProducts = StructureAdditionalProperties.TableForRegisterRecords.TableOrdersPlacement.FindRows(StructureForSearch);
			
			If ArrayPropertiesProducts.Count() = 0 Then
				Continue;
			EndIf;
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("RecordType", AccumulationRecordType.Receipt);
			StructureForSearch.Insert("Company", RowTableInventoryProducts.Company);
			StructureForSearch.Insert("ProductsAndServices", RowTableInventoryProducts.ProductsAndServices);
			StructureForSearch.Insert("Characteristic", RowTableInventoryProducts.Characteristic);
			StructureForSearch.Insert("Batch", RowTableInventoryProducts.Batch);
			StructureForSearch.Insert("ProductionExpenses", False);
			
			If ValueIsFilled(RowTableInventoryProducts.ProductsStructuralUnit) Then
				StructureForSearch.Insert("ProductsAndServicesCorr", RowTableInventoryProducts.ProductsAndServices);
				StructureForSearch.Insert("CharacteristicCorr", RowTableInventoryProducts.Characteristic);
				StructureForSearch.Insert("BatchCorr", RowTableInventoryProducts.Batch);
			EndIf;
			
			OutputCost = 0;
			ArrayCostOutputs = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.FindRows(StructureForSearch);
			For Each OutputRow IN ArrayCostOutputs Do
				OutputCost = OutputCost + OutputRow.Amount;
			EndDo;
			
			For Each StringAllocationArray IN ArrayPropertiesProducts Do
				
				OutputAmountToReserve = StringAllocationArray.Quantity;
				
				If OutputQuantity = OutputAmountToReserve Then
					OutputCostInReserve = OutputCost;
				Else
					OutputCostInReserve = Round(OutputCost * OutputAmountToReserve / OutputQuantity, 2, 1);
				EndIf;
				
				If OutputAmountToReserve > 0 Then
				
					TotalAmountToWriteOffByOrder = 0;
					
					AmountToBeWrittenOffByOrder = Round(OutputCostInReserve * StringAllocationArray.Quantity / OutputAmountToReserve, 2, 1);
					TotalAmountToWriteOffByOrder = TotalAmountToWriteOffByOrder + AmountToBeWrittenOffByOrder;
					
					If IndexOf = ArrayPropertiesProducts.Count() - 1 Then // It is the last string, it is required to correct amount.
						AmountToBeWrittenOffByOrder = AmountToBeWrittenOffByOrder + (OutputCostInReserve - TotalAmountToWriteOffByOrder);
					EndIf;
					
					TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowExpense, RowTableInventoryProducts);
					
					TableRowExpense.RecordType = AccumulationRecordType.Expense;
					
					If ValueIsFilled(RowTableInventoryProducts.ProductsStructuralUnit) Then
						TableRowExpense.StructuralUnit = RowTableInventoryProducts.ProductsStructuralUnit;
						TableRowExpense.StructuralUnitCorr = RowTableInventoryProducts.ProductsStructuralUnit;
						TableRowExpense.GLAccount = GLAccountTransferring;
						TableRowExpense.CorrGLAccount = GLAccountTransferring;
					Else
						TableRowExpense.StructuralUnit = RowTableInventoryProducts.StructuralUnit;
						TableRowExpense.StructuralUnitCorr = RowTableInventoryProducts.StructuralUnit;
						TableRowExpense.GLAccount = RowTableInventoryProducts.GLAccount;
						TableRowExpense.CorrGLAccount = RowTableInventoryProducts.GLAccount;
					EndIf;
					TableRowExpense.ProductsAndServicesCorr = RowTableInventoryProducts.ProductsAndServices;
					TableRowExpense.CharacteristicCorr = RowTableInventoryProducts.Characteristic;
					TableRowExpense.BatchCorr = RowTableInventoryProducts.Batch;
					TableRowExpense.SpecificationCorr = RowTableInventoryProducts.Specification;
					TableRowExpense.CustomerCorrOrder = StringAllocationArray.CustomerOrder;
					TableRowExpense.Quantity = StringAllocationArray.Quantity;
					TableRowExpense.Amount = AmountToBeWrittenOffByOrder;
					
					TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowReceipt, RowTableInventoryProducts);
					
					TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
					TableRowReceipt.CustomerOrder = StringAllocationArray.CustomerOrder;
					
					If ValueIsFilled(RowTableInventoryProducts.ProductsStructuralUnit) Then
						TableRowReceipt.StructuralUnit = RowTableInventoryProducts.ProductsStructuralUnit;
						TableRowReceipt.StructuralUnitCorr = RowTableInventoryProducts.ProductsStructuralUnit;
						TableRowReceipt.GLAccount = GLAccountTransferring;
						TableRowReceipt.CorrGLAccount = GLAccountTransferring;
					Else
						TableRowReceipt.StructuralUnit = RowTableInventoryProducts.StructuralUnit;
						TableRowReceipt.StructuralUnitCorr = RowTableInventoryProducts.StructuralUnit;
						TableRowReceipt.GLAccount = RowTableInventoryProducts.GLAccount;
						TableRowReceipt.CorrGLAccount = RowTableInventoryProducts.GLAccount;
					EndIf;
					TableRowReceipt.ProductsAndServicesCorr = RowTableInventoryProducts.ProductsAndServices;
					TableRowReceipt.CharacteristicCorr = RowTableInventoryProducts.Characteristic;
					TableRowReceipt.BatchCorr = RowTableInventoryProducts.Batch;
					TableRowReceipt.SpecificationCorr = RowTableInventoryProducts.Specification;
					TableRowReceipt.CustomerCorrOrder = RowTableInventoryProducts.CustomerOrder;
					TableRowReceipt.Quantity = StringAllocationArray.Quantity;
					TableRowReceipt.Amount = AmountToBeWrittenOffByOrder;
					
					IndexOf = IndexOf + 1;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryGoods");
	TableProductsAllocation = Undefined;
	
EndProcedure // GenerateTableInventoryProductionDisassembly()

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableOrdersPlacementDisassembly(DocumentRefInventoryAssembly, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Set exclusive lock of the controlled orders placement.
	Query.Text = 
	"SELECT
	|	TableProduction.Company AS Company,
	|	TableProduction.ProductsAndServices AS ProductsAndServices,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.SupplySource AS SupplySource
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.SupplySource <> UNDEFINED
	|
	|GROUP BY
	|	TableProduction.Company,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.SupplySource";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.OrdersPlacement");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult in QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receive balance.
	Query.Text = 	
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.Company AS Company,
	|	OrdersPlacementBalances.CustomerOrder AS CustomerOrder,
	|	TableProduction.ProductsAndServices AS ProductsAndServices,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.SupplySource AS SupplySource,
	|	CASE
	|		WHEN TableProduction.Quantity > ISNULL(OrdersPlacementBalances.Quantity, 0)
	|			THEN ISNULL(OrdersPlacementBalances.Quantity, 0)
	|		WHEN TableProduction.Quantity <= ISNULL(OrdersPlacementBalances.Quantity, 0)
	|			THEN TableProduction.Quantity
	|	END AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		LEFT JOIN (SELECT
	|			OrdersPlacementBalances.Company AS Company,
	|			OrdersPlacementBalances.ProductsAndServices AS ProductsAndServices,
	|			OrdersPlacementBalances.Characteristic AS Characteristic,
	|			OrdersPlacementBalances.CustomerOrder AS CustomerOrder,
	|			OrdersPlacementBalances.SupplySource AS SupplySource,
	|			SUM(OrdersPlacementBalances.QuantityBalance) AS Quantity
	|		FROM
	|			(SELECT
	|				OrdersPlacementBalances.Company AS Company,
	|				OrdersPlacementBalances.ProductsAndServices AS ProductsAndServices,
	|				OrdersPlacementBalances.Characteristic AS Characteristic,
	|				OrdersPlacementBalances.CustomerOrder AS CustomerOrder,
	|				OrdersPlacementBalances.SupplySource AS SupplySource,
	|				OrdersPlacementBalances.QuantityBalance AS QuantityBalance
	|			FROM
	|				AccumulationRegister.OrdersPlacement.Balance(
	|						&ControlTime,
	|						(Company, ProductsAndServices, Characteristic, SupplySource) In
	|							(SELECT
	|								TableProduction.Company AS Company,
	|								TableProduction.ProductsAndServices AS ProductsAndServices,
	|								TableProduction.Characteristic AS Characteristic,
	|								TableProduction.SupplySource AS SupplySource
	|							FROM
	|								TemporaryTableProduction AS TableProduction
	|							WHERE
	|								TableProduction.SupplySource <> UNDEFINED)) AS OrdersPlacementBalances
			
	|			UNION ALL
			
	|			SELECT
	|				DocumentRegisterRecordsOrdersPlacement.Company,
	|				DocumentRegisterRecordsOrdersPlacement.ProductsAndServices,
	|				DocumentRegisterRecordsOrdersPlacement.Characteristic,
	|				DocumentRegisterRecordsOrdersPlacement.CustomerOrder,
	|				DocumentRegisterRecordsOrdersPlacement.SupplySource,
	|				CASE
	|					WHEN DocumentRegisterRecordsOrdersPlacement.RecordType = VALUE(AccumulationRecordType.Expense)
	|						THEN ISNULL(DocumentRegisterRecordsOrdersPlacement.Quantity, 0)
	|					ELSE -ISNULL(DocumentRegisterRecordsOrdersPlacement.Quantity, 0)
	|				END
	|			FROM
	|				AccumulationRegister.OrdersPlacement AS DocumentRegisterRecordsOrdersPlacement
	|			WHERE
	|				DocumentRegisterRecordsOrdersPlacement.Recorder = &Ref
	|				AND DocumentRegisterRecordsOrdersPlacement.Period <= &ControlPeriod) AS OrdersPlacementBalances
		
	|		GROUP BY
	|			OrdersPlacementBalances.Company,
	|			OrdersPlacementBalances.ProductsAndServices,
	|			OrdersPlacementBalances.Characteristic,
	|			OrdersPlacementBalances.CustomerOrder,
	|			OrdersPlacementBalances.SupplySource) AS OrdersPlacementBalances
	|		ON TableProduction.Company = OrdersPlacementBalances.Company
	|			AND TableProduction.ProductsAndServices = OrdersPlacementBalances.ProductsAndServices
	|			AND TableProduction.Characteristic = OrdersPlacementBalances.Characteristic
	|			AND TableProduction.SupplySource = OrdersPlacementBalances.SupplySource
	|WHERE
	|	TableProduction.SupplySource <> UNDEFINED
	|	AND OrdersPlacementBalances.CustomerOrder IS Not NULL ";
	
	Query.SetParameter("Ref", DocumentRefInventoryAssembly);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);
	
	QueryResult = Query.Execute();

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableOrdersPlacement", QueryResult.Unload());
	
EndProcedure // GenerateTableProductsPlacementDisassembly()

////////////////////////////////////////////////////////////////////////////////
// DATA INITIALIZATION

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataAssembly(DocumentRefInventoryAssembly, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	InventoryAssemblyProducts.LineNumber AS LineNumber,
	|	InventoryAssemblyProducts.Ref.Date AS Period,
	|	&Company AS Company,
	|	InventoryAssemblyProducts.Ref.StructuralUnit AS StructuralUnit,
	|	InventoryAssemblyProducts.Ref.StructuralUnit.OrderWarehouse AS OrderWarehouse,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN InventoryAssemblyProducts.Ref.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	CASE
	|		WHEN InventoryAssemblyProducts.Ref.StructuralUnit = InventoryAssemblyProducts.Ref.ProductsStructuralUnit
	|			THEN VALUE(Catalog.StructuralUnits.EmptyRef)
	|		ELSE InventoryAssemblyProducts.Ref.ProductsStructuralUnit
	|	END AS ProductsStructuralUnit,
	|	InventoryAssemblyProducts.Ref.ProductsStructuralUnit AS ProductsStructuralUnitToWarehouse,
	|	InventoryAssemblyProducts.Ref.ProductsStructuralUnit.OrderWarehouse AS OrderWarehouseOfProducts,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN InventoryAssemblyProducts.Ref.ProductsCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS ProductsCell,
	|	InventoryAssemblyProducts.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryAssemblyProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryAssemblyProducts.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	InventoryAssemblyProducts.Specification AS Specification,
	|	CASE
	|		WHEN InventoryAssemblyProducts.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|			THEN InventoryAssemblyProducts.ProductsAndServices.InventoryGLAccount
	|		ELSE InventoryAssemblyProducts.ProductsAndServices.ExpensesGLAccount
	|	END AS GLAccount,
	|	CASE
	|		WHEN InventoryAssemblyProducts.Ref.ProductsStructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|			THEN InventoryAssemblyProducts.ProductsAndServices.InventoryGLAccount
	|		ELSE InventoryAssemblyProducts.ProductsAndServices.ExpensesGLAccount
	|	END AS ProductsGLAccount,
	|	CASE
	|		WHEN InventoryAssemblyProducts.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|			THEN InventoryAssemblyProducts.ProductsAndServices.InventoryGLAccount
	|		ELSE InventoryAssemblyProducts.ProductsAndServices.ExpensesGLAccount
	|	END AS AccountDr,
	|	CASE
	|		WHEN InventoryAssemblyProducts.Ref.ProductsStructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|			THEN InventoryAssemblyProducts.ProductsAndServices.InventoryGLAccount
	|		ELSE InventoryAssemblyProducts.ProductsAndServices.ExpensesGLAccount
	|	END AS ProductsAccountDr,
	|	CASE
	|		WHEN InventoryAssemblyProducts.Batch.Status = VALUE(Enum.BatchStatuses.SafeCustody)
	|				OR InventoryAssemblyProducts.Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|				OR InventoryAssemblyProducts.Batch.Status = VALUE(Enum.BatchStatuses.CommissionMaterials)
	|			THEN InventoryAssemblyProducts.ProductsAndServices.InventoryGLAccount
	|		ELSE CASE
	|				WHEN InventoryAssemblyProducts.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|					THEN InventoryAssemblyProducts.ProductsAndServices.InventoryGLAccount
	|				ELSE InventoryAssemblyProducts.ProductsAndServices.ExpensesGLAccount
	|			END
	|	END AS ProductsAccountCr,
	|	InventoryAssemblyProducts.Ref.CustomerOrder AS CustomerOrder,
	|	VALUE(Document.CustomerOrder.EmptyRef) AS CustomerCorrOrder,
	|	InventoryAssemblyProducts.Ref.BasisDocument AS ProductionOrder,
	|	CASE
	|		WHEN InventoryAssemblyProducts.Ref.BasisDocument = VALUE(Document.ProductionOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE InventoryAssemblyProducts.Ref.BasisDocument
	|	END AS SupplySource,
	|	CASE
	|		WHEN VALUETYPE(InventoryAssemblyProducts.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN InventoryAssemblyProducts.Quantity
	|		ELSE InventoryAssemblyProducts.Quantity * InventoryAssemblyProducts.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	CAST(&InventoryAssembly AS String(100)) AS ContentOfAccountingRecord,
	|	CAST(&InventoryAssembly AS String(100)) AS Content,
	|	&UpdateDateToRelease_1_2_1 AS UpdateDateToRelease_1_2_1
	|INTO TemporaryTableProduction
	|FROM
	|	Document.InventoryAssembly.Products AS InventoryAssemblyProducts
	|WHERE
	|	InventoryAssemblyProducts.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableProduction.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.Company AS Company,
	|	UNDEFINED AS PlanningPeriod,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	UNDEFINED AS StructuralUnitCorr,
	|	TableProduction.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	TableProduction.GLAccount AS GLAccount,
	|	TableProduction.ProductsGLAccount AS ProductsGLAccount,
	|	UNDEFINED AS CorrGLAccount,
	|	TableProduction.ProductsAndServices AS ProductsAndServices,
	|	UNDEFINED AS ProductsAndServicesCorr,
	|	TableProduction.Characteristic AS Characteristic,
	|	UNDEFINED AS CharacteristicCorr,
	|	TableProduction.Batch AS Batch,
	|	UNDEFINED AS BatchCorr,
	|	TableProduction.Specification AS Specification,
	|	UNDEFINED AS SpecificationCorr,
	|	TableProduction.CustomerOrder AS CustomerOrder,
	|	TableProduction.ProductionOrder AS ProductionOrder,
	|	TableProduction.CustomerCorrOrder AS CustomerCorrOrder,
	|	UNDEFINED AS AccountDr,
	|	UNDEFINED AS AccountCr,
	|	UNDEFINED AS Content,
	|	TableProduction.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS ProductionExpenses,
	|	SUM(TableProduction.Quantity) AS Quantity,
	|	SUM(TableProduction.Amount) AS Amount,
	|	FALSE AS FixedCost
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.Company,
	|	TableProduction.StructuralUnit,
	|	TableProduction.ProductsStructuralUnit,
	|	TableProduction.GLAccount,
	|	TableProduction.ProductsGLAccount,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	TableProduction.Specification,
	|	TableProduction.CustomerOrder,
	|	TableProduction.ProductionOrder,
	|	TableProduction.CustomerCorrOrder,
	|	TableProduction.ContentOfAccountingRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	TableProduction.Cell AS Cell,
	|	TableProduction.ProductsStructuralUnitToWarehouse AS ProductsStructuralUnit,
	|	TableProduction.OrderWarehouse AS OrderWarehouse,
	|	TableProduction.OrderWarehouseOfProducts AS OrderWarehouseOfProducts,
	|	TableProduction.ProductsCell AS ProductsCell,
	|	TableProduction.ProductsAndServices AS ProductsAndServices,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.Period < TableProduction.UpdateDateToRelease_1_2_1
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.StructuralUnit,
	|	TableProduction.Cell,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.OrderWarehouse,
	|	TableProduction.OrderWarehouseOfProducts,
	|	TableProduction.ProductsCell,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableProduction.Period,
	|	&Company,
	|	TableProduction.StructuralUnit,
	|	TableProduction.Cell,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.OrderWarehouse,
	|	TableProduction.OrderWarehouseOfProducts,
	|	TableProduction.ProductsCell,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	SUM(TableProduction.Quantity)
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	Not TableProduction.OrderWarehouse
	|	AND TableProduction.Period >= TableProduction.UpdateDateToRelease_1_2_1
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.StructuralUnit,
	|	TableProduction.Cell,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.OrderWarehouse,
	|	TableProduction.OrderWarehouseOfProducts,
	|	TableProduction.ProductsCell,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableProduction.Period,
	|	&Company,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.ProductsCell,
	|	TableProduction.StructuralUnit,
	|	TableProduction.OrderWarehouse,
	|	TableProduction.OrderWarehouseOfProducts,
	|	TableProduction.Cell,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	SUM(TableProduction.Quantity)
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.OrderWarehouse
	|	AND Not TableProduction.OrderWarehouseOfProducts
	|	AND TableProduction.Period >= TableProduction.UpdateDateToRelease_1_2_1
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.ProductsCell,
	|	TableProduction.StructuralUnit,
	|	TableProduction.OrderWarehouse,
	|	TableProduction.OrderWarehouseOfProducts,
	|	TableProduction.Cell,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	TableProduction.CustomerOrder AS CustomerOrder,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	TableProduction.ProductsAndServices AS ProductsAndServices,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.Specification AS Specification,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.CustomerOrder,
	|	TableProduction.StructuralUnit,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	TableProduction.Specification
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	TableProduction.ProductionOrder AS ProductionOrder,
	|	TableProduction.ProductsAndServices AS ProductsAndServices,
	|	TableProduction.Characteristic AS Characteristic,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.ProductionOrder <> VALUE(Document.ProductionOrder.EmptyRef)
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.ProductionOrder,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	TableProduction.Company AS Company,
	|	TableProduction.ProductsAndServices AS ProductsAndServices,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.OrderWarehouse
	|	AND TableProduction.Period >= TableProduction.UpdateDateToRelease_1_2_1
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.StructuralUnit,
	|	TableProduction.Company,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	TableProduction.Period,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.Company,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	SUM(TableProduction.Quantity)
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.OrderWarehouseOfProducts
	|	AND TableProduction.ProductsStructuralUnitToWarehouse <> TableProduction.StructuralUnit
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.Company,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableProduction.Period,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.Company,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	SUM(TableProduction.Quantity)
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.OrderWarehouseOfProducts
	|	AND TableProduction.Period < TableProduction.UpdateDateToRelease_1_2_1
	|	AND TableProduction.ProductsStructuralUnitToWarehouse <> TableProduction.StructuralUnit
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.Company,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	TableProduction.Company AS Company,
	|	TableProduction.ProductsAndServices AS ProductsAndServices,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.OrderWarehouse
	|	AND TableProduction.Period >= TableProduction.UpdateDateToRelease_1_2_1
	|	AND TableProduction.ProductsStructuralUnitToWarehouse <> TableProduction.StructuralUnit
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.StructuralUnit,
	|	TableProduction.Company,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableProduction.LineNumber) AS CorrLineNumber,
	|	TableProduction.ProductsAndServices AS ProductsAndServicesCorr,
	|	TableProduction.Characteristic AS CharacteristicCorr,
	|	TableProduction.Batch AS BatchCorr,
	|	TableProduction.Specification AS SpecificationCorr,
	|	TableProduction.GLAccount AS CorrGLAccount,
	|	TableProduction.ProductsGLAccount AS ProductsGLAccount,
	|	TableProduction.AccountDr AS AccountDr,
	|	TableProduction.ProductsAccountDr AS ProductsAccountDr,
	|	TableProduction.ProductsAccountCr AS ProductsAccountCr,
	|	SUM(TableProduction.Quantity) AS CorrQuantity,
	|	FALSE AS Distributed
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	TableProduction.Specification,
	|	TableProduction.GLAccount,
	|	TableProduction.ProductsGLAccount,
	|	TableProduction.AccountDr,
	|	TableProduction.ProductsAccountDr,
	|	TableProduction.ProductsAccountCr
	|
	|ORDER BY
	|	CorrLineNumber";
	
	Query.SetParameter("Ref", DocumentRefInventoryAssembly);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",  StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("AccountingByCells",  StructureAdditionalProperties.AccountingPolicy.AccountingByCells);
	Query.SetParameter("UseTechOperations",  StructureAdditionalProperties.AccountingPolicy.UseTechOperations);
	
	// Temporarily: change motions by the order warehouse.
	UpdateDateToRelease_1_2_1 = Constants.UpdateDateToRelease_1_2_1.Get();
	Query.SetParameter("UpdateDateToRelease_1_2_1", UpdateDateToRelease_1_2_1);
	
	Query.SetParameter("InventoryAssembly", NStr("en='Production';ru='Производство'"));

	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryGoods", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods.CopyColumns());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductRelease", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductionOrders", ResultsArray[4].Unload());
	
	// Products autotransfer (expand the TableInventoryInWarehouses table).
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Count() - 1 Do
		
		RowTableInventoryInWarehouses = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses[n];
		
		If (RowTableInventoryInWarehouses.ProductsStructuralUnit = RowTableInventoryInWarehouses.StructuralUnit
			AND RowTableInventoryInWarehouses.ProductsCell <> RowTableInventoryInWarehouses.Cell)
			OR RowTableInventoryInWarehouses.ProductsStructuralUnit <> RowTableInventoryInWarehouses.StructuralUnit Then
			
			// Expense.
			If (RowTableInventoryInWarehouses.Period < UpdateDateToRelease_1_2_1)
				OR (RowTableInventoryInWarehouses.Period >= UpdateDateToRelease_1_2_1
				AND Not RowTableInventoryInWarehouses.OrderWarehouse) Then
				
				TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
				FillPropertyValues(TableRowExpense, RowTableInventoryInWarehouses);
				
				TableRowExpense.RecordType = AccumulationRecordType.Expense;
				
			EndIf;
			
			// Receipt.
			If (RowTableInventoryInWarehouses.Period < UpdateDateToRelease_1_2_1)
				OR (RowTableInventoryInWarehouses.Period >= UpdateDateToRelease_1_2_1
				AND Not RowTableInventoryInWarehouses.OrderWarehouseOfProducts
				AND Not RowTableInventoryInWarehouses.OrderWarehouse) Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventoryInWarehouses);
				
				TableRowReceipt.StructuralUnit = RowTableInventoryInWarehouses.ProductsStructuralUnit;
				TableRowReceipt.Cell = RowTableInventoryInWarehouses.ProductsCell;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// Products autotransfer (generate the TableInventoryForWarehouses table).
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryForWarehouses", ResultsArray[5].Unload());
	
	// Products autotransfer (generate the TableInventoryForWarehousesExpense table).
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryForExpenseFromWarehouses", ResultsArray[6].Unload());
	
	// Generate documents posting table structure.
	SmallBusinessServer.GenerateTransactionsTable(DocumentRefInventoryAssembly, StructureAdditionalProperties);
	
	// Generate table by orders placement.
	GenerateTableOrdersPlacementAssembly(DocumentRefInventoryAssembly, StructureAdditionalProperties);
	
	// Generate materials allocation table.
	TableProduction = ResultsArray[7].Unload();
	GenerateMaterialsDistributionTableAssembly(DocumentRefInventoryAssembly, StructureAdditionalProperties, TableProduction);
	
	// Inventory.
	AssemblyAmount = 0;
	DataInitializationByProduction(DocumentRefInventoryAssembly, StructureAdditionalProperties, AssemblyAmount);
	
	// Products.
	GenerateTableInventoryProductsAssembly(DocumentRefInventoryAssembly, StructureAdditionalProperties, AssemblyAmount);
	
	// Disposals.
	DataInitializationByDisposals(DocumentRefInventoryAssembly, StructureAdditionalProperties);
	
EndProcedure // InitializeDocumentDataBuild()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataDisassembly(DocumentRefInventoryAssembly, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	InventoryAssemblyInventory.LineNumber AS LineNumber,
	|	InventoryAssemblyInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	InventoryAssemblyInventory.Ref.StructuralUnit AS StructuralUnit,
	|	InventoryAssemblyInventory.Ref.StructuralUnit.OrderWarehouse AS OrderWarehouse,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN InventoryAssemblyInventory.Ref.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	CASE
	|		WHEN InventoryAssemblyInventory.Ref.StructuralUnit = InventoryAssemblyInventory.Ref.ProductsStructuralUnit
	|			THEN VALUE(Catalog.StructuralUnits.EmptyRef)
	|		ELSE InventoryAssemblyInventory.Ref.ProductsStructuralUnit
	|	END AS ProductsStructuralUnit,
	|	InventoryAssemblyInventory.Ref.ProductsStructuralUnit AS ProductsStructuralUnitToWarehouse,
	|	InventoryAssemblyInventory.Ref.ProductsStructuralUnit.OrderWarehouse AS OrderWarehouseOfProducts,
	|	CASE
	|		WHEN &AccountingByCells
	|			THEN InventoryAssemblyInventory.Ref.ProductsCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS ProductsCell,
	|	InventoryAssemblyInventory.Specification AS Specification,
	|	CASE
	|		WHEN InventoryAssemblyInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|			THEN InventoryAssemblyInventory.ProductsAndServices.InventoryGLAccount
	|		ELSE InventoryAssemblyInventory.ProductsAndServices.ExpensesGLAccount
	|	END AS GLAccount,
	|	CASE
	|		WHEN InventoryAssemblyInventory.Ref.ProductsStructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|			THEN InventoryAssemblyInventory.ProductsAndServices.InventoryGLAccount
	|		ELSE InventoryAssemblyInventory.ProductsAndServices.ExpensesGLAccount
	|	END AS ProductsGLAccount,
	|	InventoryAssemblyInventory.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryAssemblyInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryAssemblyInventory.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	InventoryAssemblyInventory.Ref.CustomerOrder AS CustomerOrder,
	|	VALUE(Document.CustomerOrder.EmptyRef) AS CustomerCorrOrder,
	|	InventoryAssemblyInventory.Ref.BasisDocument AS ProductionOrder,
	|	CASE
	|		WHEN InventoryAssemblyInventory.Ref.BasisDocument = VALUE(Document.ProductionOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE InventoryAssemblyInventory.Ref.BasisDocument
	|	END AS SupplySource,
	|	CASE
	|		WHEN VALUETYPE(InventoryAssemblyInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN InventoryAssemblyInventory.Quantity
	|		ELSE InventoryAssemblyInventory.Quantity * InventoryAssemblyInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	CAST(&InventoryAssembly AS String(100)) AS ContentOfAccountingRecord,
	|	CAST(&InventoryAssembly AS String(100)) AS Content,
	|	&UpdateDateToRelease_1_2_1 AS UpdateDateToRelease_1_2_1
	|INTO TemporaryTableProduction
	|FROM
	|	Document.InventoryAssembly.Inventory AS InventoryAssemblyInventory
	|WHERE
	|	InventoryAssemblyInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableProduction.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.Company AS Company,
	|	UNDEFINED AS PlanningPeriod,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	UNDEFINED AS StructuralUnitCorr,
	|	TableProduction.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	TableProduction.GLAccount AS GLAccount,
	|	TableProduction.ProductsGLAccount AS ProductsGLAccount,
	|	UNDEFINED AS CorrGLAccount,
	|	TableProduction.ProductsAndServices AS ProductsAndServices,
	|	UNDEFINED AS ProductsAndServicesCorr,
	|	TableProduction.Characteristic AS Characteristic,
	|	UNDEFINED AS CharacteristicCorr,
	|	TableProduction.Batch AS Batch,
	|	UNDEFINED AS BatchCorr,
	|	TableProduction.Specification AS Specification,
	|	UNDEFINED AS SpecificationCorr,
	|	TableProduction.CustomerOrder AS CustomerOrder,
	|	TableProduction.ProductionOrder AS ProductionOrder,
	|	TableProduction.CustomerCorrOrder AS CustomerCorrOrder,
	|	UNDEFINED AS AccountDr,
	|	UNDEFINED AS AccountCr,
	|	UNDEFINED AS Content,
	|	TableProduction.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS ProductionExpenses,
	|	SUM(TableProduction.Quantity) AS Quantity,
	|	SUM(TableProduction.Amount) AS Amount,
	|	FALSE AS FixedCost
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.Company,
	|	TableProduction.StructuralUnit,
	|	TableProduction.ProductsStructuralUnit,
	|	TableProduction.GLAccount,
	|	TableProduction.ProductsGLAccount,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	TableProduction.Specification,
	|	TableProduction.CustomerOrder,
	|	TableProduction.ProductionOrder,
	|	TableProduction.CustomerCorrOrder,
	|	TableProduction.ContentOfAccountingRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	TableProduction.ProductsStructuralUnitToWarehouse AS ProductsStructuralUnit,
	|	TableProduction.Cell AS Cell,
	|	TableProduction.ProductsCell AS ProductsCell,
	|	TableProduction.OrderWarehouse AS OrderWarehouse,
	|	TableProduction.OrderWarehouseOfProducts AS OrderWarehouseOfProducts,
	|	TableProduction.ProductsAndServices AS ProductsAndServices,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.Period < TableProduction.UpdateDateToRelease_1_2_1
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.StructuralUnit,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.Cell,
	|	TableProduction.ProductsCell,
	|	TableProduction.OrderWarehouse,
	|	TableProduction.OrderWarehouseOfProducts,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableProduction.Period,
	|	&Company,
	|	TableProduction.StructuralUnit,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.Cell,
	|	TableProduction.ProductsCell,
	|	TableProduction.OrderWarehouse,
	|	TableProduction.OrderWarehouseOfProducts,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	SUM(TableProduction.Quantity)
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	Not TableProduction.OrderWarehouse
	|	AND TableProduction.Period >= TableProduction.UpdateDateToRelease_1_2_1
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.StructuralUnit,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.Cell,
	|	TableProduction.ProductsCell,
	|	TableProduction.OrderWarehouse,
	|	TableProduction.OrderWarehouseOfProducts,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableProduction.Period,
	|	&Company,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.StructuralUnit,
	|	TableProduction.ProductsCell,
	|	TableProduction.Cell,
	|	TableProduction.OrderWarehouse,
	|	TableProduction.OrderWarehouseOfProducts,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	SUM(TableProduction.Quantity)
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.OrderWarehouse
	|	AND Not TableProduction.OrderWarehouseOfProducts
	|	AND TableProduction.Period >= TableProduction.UpdateDateToRelease_1_2_1
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.StructuralUnit,
	|	TableProduction.ProductsCell,
	|	TableProduction.Cell,
	|	TableProduction.OrderWarehouse,
	|	TableProduction.OrderWarehouseOfProducts,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	TableProduction.CustomerOrder AS CustomerOrder,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	TableProduction.ProductsAndServices AS ProductsAndServices,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.Specification AS Specification,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.CustomerOrder,
	|	TableProduction.StructuralUnit,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	TableProduction.Specification
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	TableProduction.ProductionOrder AS ProductionOrder,
	|	TableProduction.ProductsAndServices AS ProductsAndServices,
	|	TableProduction.Characteristic AS Characteristic,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.ProductionOrder <> VALUE(Document.ProductionOrder.EmptyRef)
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.ProductionOrder,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	TableProduction.Company AS Company,
	|	TableProduction.ProductsAndServices AS ProductsAndServices,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.OrderWarehouse
	|	AND TableProduction.Period >= TableProduction.UpdateDateToRelease_1_2_1
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.StructuralUnit,
	|	TableProduction.Company,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	TableProduction.Period,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.Company,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	SUM(TableProduction.Quantity)
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.OrderWarehouseOfProducts
	|	AND TableProduction.ProductsStructuralUnitToWarehouse <> TableProduction.StructuralUnit
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.Company,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableProduction.Period,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.Company,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	SUM(TableProduction.Quantity)
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.OrderWarehouseOfProducts
	|	AND TableProduction.Period < TableProduction.UpdateDateToRelease_1_2_1
	|	AND TableProduction.ProductsStructuralUnitToWarehouse <> TableProduction.StructuralUnit
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.Company,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	TableProduction.Company AS Company,
	|	TableProduction.ProductsAndServices AS ProductsAndServices,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.OrderWarehouse
	|	AND TableProduction.Period >= TableProduction.UpdateDateToRelease_1_2_1
	|	AND TableProduction.ProductsStructuralUnitToWarehouse <> TableProduction.StructuralUnit
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.StructuralUnit,
	|	TableProduction.Company,
	|	TableProduction.ProductsAndServices,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(InventoryAssemblyProducts.LineNumber) AS LineNumber,
	|	InventoryAssemblyProducts.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryAssemblyProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryAssemblyProducts.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryAssemblyProducts.Batch.Status
	|		ELSE VALUE(Enum.BatchStatuses.EmptyRef)
	|	END AS BatchStatus,
	|	CASE
	|		WHEN InventoryAssemblyProducts.Batch.Status = VALUE(Enum.BatchStatuses.SafeCustody)
	|				OR InventoryAssemblyProducts.Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|				OR InventoryAssemblyProducts.Batch.Status = VALUE(Enum.BatchStatuses.CommissionMaterials)
	|			THEN InventoryAssemblyProducts.ProductsAndServices.InventoryGLAccount
	|		ELSE CASE
	|				WHEN InventoryAssemblyProducts.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|					THEN InventoryAssemblyProducts.ProductsAndServices.InventoryGLAccount
	|				ELSE InventoryAssemblyProducts.ProductsAndServices.ExpensesGLAccount
	|			END
	|	END AS GLAccount,
	|	CASE
	|		WHEN InventoryAssemblyProducts.Batch.Status = VALUE(Enum.BatchStatuses.SafeCustody)
	|				OR InventoryAssemblyProducts.Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|				OR InventoryAssemblyProducts.Batch.Status = VALUE(Enum.BatchStatuses.CommissionMaterials)
	|			THEN InventoryAssemblyProducts.ProductsAndServices.InventoryGLAccount
	|		ELSE CASE
	|				WHEN InventoryAssemblyProducts.Ref.InventoryStructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|					THEN InventoryAssemblyProducts.ProductsAndServices.InventoryGLAccount
	|				ELSE InventoryAssemblyProducts.ProductsAndServices.ExpensesGLAccount
	|			END
	|	END AS InventoryGLAccount,
	|	InventoryAssemblyProducts.Specification AS Specification,
	|	SUM(CASE
	|			WHEN VALUETYPE(InventoryAssemblyProducts.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN InventoryAssemblyProducts.Quantity
	|			ELSE InventoryAssemblyProducts.Quantity * InventoryAssemblyProducts.MeasurementUnit.Factor
	|		END) AS Quantity,
	|	SUM(CASE
	|			WHEN VALUETYPE(InventoryAssemblyProducts.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN InventoryAssemblyProducts.Reserve
	|			ELSE InventoryAssemblyProducts.Reserve * InventoryAssemblyProducts.MeasurementUnit.Factor
	|		END) AS Reserve,
	|	CASE
	|		WHEN InventoryAssemblyProducts.Batch.Status = VALUE(Enum.BatchStatuses.SafeCustody)
	|				OR InventoryAssemblyProducts.Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|				OR InventoryAssemblyProducts.Batch.Status = VALUE(Enum.BatchStatuses.CommissionMaterials)
	|			THEN InventoryAssemblyProducts.ProductsAndServices.InventoryGLAccount
	|		ELSE CASE
	|				WHEN InventoryAssemblyProducts.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|					THEN InventoryAssemblyProducts.ProductsAndServices.InventoryGLAccount
	|				ELSE InventoryAssemblyProducts.ProductsAndServices.ExpensesGLAccount
	|			END
	|	END AS AccountCr,
	|	FALSE AS Distributed
	|FROM
	|	Document.InventoryAssembly.Products AS InventoryAssemblyProducts
	|WHERE
	|	InventoryAssemblyProducts.Ref = &Ref
	|
	|GROUP BY
	|	InventoryAssemblyProducts.ProductsAndServices,
	|	InventoryAssemblyProducts.Specification,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryAssemblyProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryAssemblyProducts.Batch
	|		ELSE VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryAssemblyProducts.Batch.Status
	|		ELSE VALUE(Enum.BatchStatuses.EmptyRef)
	|	END,
	|	CASE
	|		WHEN InventoryAssemblyProducts.Batch.Status = VALUE(Enum.BatchStatuses.SafeCustody)
	|				OR InventoryAssemblyProducts.Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|				OR InventoryAssemblyProducts.Batch.Status = VALUE(Enum.BatchStatuses.CommissionMaterials)
	|			THEN InventoryAssemblyProducts.ProductsAndServices.InventoryGLAccount
	|		ELSE CASE
	|				WHEN InventoryAssemblyProducts.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|					THEN InventoryAssemblyProducts.ProductsAndServices.InventoryGLAccount
	|				ELSE InventoryAssemblyProducts.ProductsAndServices.ExpensesGLAccount
	|			END
	|	END,
	|	CASE
	|		WHEN InventoryAssemblyProducts.Batch.Status = VALUE(Enum.BatchStatuses.SafeCustody)
	|				OR InventoryAssemblyProducts.Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|				OR InventoryAssemblyProducts.Batch.Status = VALUE(Enum.BatchStatuses.CommissionMaterials)
	|			THEN InventoryAssemblyProducts.ProductsAndServices.InventoryGLAccount
	|		ELSE CASE
	|				WHEN InventoryAssemblyProducts.Ref.InventoryStructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|					THEN InventoryAssemblyProducts.ProductsAndServices.InventoryGLAccount
	|				ELSE InventoryAssemblyProducts.ProductsAndServices.ExpensesGLAccount
	|			END
	|	END,
	|	CASE
	|		WHEN InventoryAssemblyProducts.Batch.Status = VALUE(Enum.BatchStatuses.SafeCustody)
	|				OR InventoryAssemblyProducts.Batch.Status = VALUE(Enum.BatchStatuses.ProductsOnCommission)
	|				OR InventoryAssemblyProducts.Batch.Status = VALUE(Enum.BatchStatuses.CommissionMaterials)
	|			THEN InventoryAssemblyProducts.ProductsAndServices.InventoryGLAccount
	|		ELSE CASE
	|				WHEN InventoryAssemblyProducts.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|					THEN InventoryAssemblyProducts.ProductsAndServices.InventoryGLAccount
	|				ELSE InventoryAssemblyProducts.ProductsAndServices.ExpensesGLAccount
	|			END
	|	END";
	
	Query.SetParameter("Ref", DocumentRefInventoryAssembly);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",  StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("AccountingByCells",  StructureAdditionalProperties.AccountingPolicy.AccountingByCells);
	Query.SetParameter("UseTechOperations",  StructureAdditionalProperties.AccountingPolicy.UseTechOperations);
	
	// Temporarily: change motions by the order warehouse.
	UpdateDateToRelease_1_2_1 = Constants.UpdateDateToRelease_1_2_1.Get();
	Query.SetParameter("UpdateDateToRelease_1_2_1", UpdateDateToRelease_1_2_1);
	
	Query.SetParameter("InventoryAssembly", NStr("en='Production';ru='Производство'"));

	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryGoods", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods.CopyColumns());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductRelease", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductionOrders", ResultsArray[4].Unload());
	
	// Products autotransfer (expand the TableInventoryInWarehouses table).
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Count() - 1 Do
		
		RowTableInventoryInWarehouses = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses[n];
		
		If (RowTableInventoryInWarehouses.ProductsStructuralUnit = RowTableInventoryInWarehouses.StructuralUnit
			AND RowTableInventoryInWarehouses.ProductsCell <> RowTableInventoryInWarehouses.Cell)
			OR RowTableInventoryInWarehouses.ProductsStructuralUnit <> RowTableInventoryInWarehouses.StructuralUnit Then
			
			// Expense.
			If (RowTableInventoryInWarehouses.Period < UpdateDateToRelease_1_2_1)
				OR (RowTableInventoryInWarehouses.Period >= UpdateDateToRelease_1_2_1
				AND Not RowTableInventoryInWarehouses.OrderWarehouse) Then
				
				TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
				FillPropertyValues(TableRowExpense, RowTableInventoryInWarehouses);
				
				TableRowExpense.RecordType = AccumulationRecordType.Expense;
				
			EndIf;
			
			// Receipt.
			If (RowTableInventoryInWarehouses.Period < UpdateDateToRelease_1_2_1)
				OR (RowTableInventoryInWarehouses.Period >= UpdateDateToRelease_1_2_1
				AND Not RowTableInventoryInWarehouses.OrderWarehouseOfProducts
				AND Not RowTableInventoryInWarehouses.OrderWarehouse) Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventoryInWarehouses);
				
				TableRowReceipt.StructuralUnit = RowTableInventoryInWarehouses.ProductsStructuralUnit;
				TableRowReceipt.Cell = RowTableInventoryInWarehouses.ProductsCell;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// Products autotransfer (generate the TableInventoryForWarehouses table).
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryForWarehouses", ResultsArray[5].Unload());
	
	// Products autotransfer (generate the TableInventoryForWarehousesExpense table).
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryForExpenseFromWarehouses", ResultsArray[6].Unload());
	
	// Creation of document postings.
	SmallBusinessServer.GenerateTransactionsTable(DocumentRefInventoryAssembly, StructureAdditionalProperties);
	
	// Generate table by orders placement.
	GenerateTableOrdersPlacementDisassembly(DocumentRefInventoryAssembly, StructureAdditionalProperties);
	
	// Generate materials allocation table.
	TableProduction = ResultsArray[7].Unload();
	GenerateMaterialsDistributionTableDisassembly(DocumentRefInventoryAssembly, StructureAdditionalProperties, TableProduction);
	
	// Inventory.
	AssemblyAmount = 0;
	DataInitializationByInventoryDisassembly(DocumentRefInventoryAssembly, StructureAdditionalProperties, AssemblyAmount);
	
	// Products.
	GenerateTableInventoryProductsDisassembly(DocumentRefInventoryAssembly, StructureAdditionalProperties, AssemblyAmount);
	
	// Disposals.
	DataInitializationByDisposals(DocumentRefInventoryAssembly, StructureAdditionalProperties);
	
EndProcedure // InitializeDocumentDataDisassembly()

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefInventoryAssembly, StructureAdditionalProperties) Export
	
	If DocumentRefInventoryAssembly.OperationKind = Enums.OperationKindsInventoryAssembly.Assembly Then
		
		InitializeDocumentDataAssembly(DocumentRefInventoryAssembly, StructureAdditionalProperties)
		
	Else
		
		InitializeDocumentDataDisassembly(DocumentRefInventoryAssembly, StructureAdditionalProperties)
		
	EndIf;	
	
EndProcedure // DocumentDataInitialization()

////////////////////////////////////////////////////////////////////////////////
// BALANCE CONTROL

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefInventoryAssembly, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not SmallBusinessServer.RunBalanceControl() Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If the temporary tables
	// "RegisterRecordsProductionOrdersChange" "RegisterRecordsOrdersPlacementChange"
	// "RegisterRecordsInventoryChange" contain records, control goods implementation.
	
	If StructureTemporaryTables.RegisterRecordsProductionOrdersChange
		OR StructureTemporaryTables.RegisterRecordsOrdersPlacementChange
		OR StructureTemporaryTables.RegisterRecordsInventoryChange
		OR StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		OR StructureTemporaryTables.RegisterRecordsInventoryReceivedChange Then
		
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
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsInventoryReceivedChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.ReceptionTransmissionType) AS ReceptionTransmissionTypePresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryReceivedChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(InventoryReceivedBalances.ProductsAndServices.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryReceivedChange.QuantityChange, 0) + ISNULL(InventoryReceivedBalances.QuantityBalance, 0) AS BalanceInventoryReceived,
		|	ISNULL(InventoryReceivedBalances.QuantityBalance, 0) AS QuantityBalanceInventoryReceived,
		|	0 AS SettlementsAmountBalanceInventoryReceived
		|FROM
		|	RegisterRecordsInventoryReceivedChange AS RegisterRecordsInventoryReceivedChange
		|		LEFT JOIN AccumulationRegister.InventoryReceived.Balance(
		|				&ControlTime,
		|				(Company, ReceptionTransmissionType, ProductsAndServices, Characteristic, Batch, Order) In
		|					(SELECT
		|						RegisterRecordsInventoryReceivedChange.Company AS Company,
		|						VALUE(Enum.ProductsReceiptTransferTypes.ReportByProcessing) AS ReceptionTransmissionType,
		|						RegisterRecordsInventoryReceivedChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsInventoryReceivedChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryReceivedChange.Batch AS Batch,
		|						UNDEFINED AS Order
		|					FROM
		|						RegisterRecordsInventoryReceivedChange AS RegisterRecordsInventoryReceivedChange)) AS InventoryReceivedBalances
		|		ON RegisterRecordsInventoryReceivedChange.Company = InventoryReceivedBalances.Company
		|			AND RegisterRecordsInventoryReceivedChange.ReceptionTransmissionType = InventoryReceivedBalances.ReceptionTransmissionType
		|			AND RegisterRecordsInventoryReceivedChange.ProductsAndServices = InventoryReceivedBalances.ProductsAndServices
		|			AND RegisterRecordsInventoryReceivedChange.Characteristic = InventoryReceivedBalances.Characteristic
		|			AND RegisterRecordsInventoryReceivedChange.Batch = InventoryReceivedBalances.Batch
		|			AND RegisterRecordsInventoryReceivedChange.Order = InventoryReceivedBalances.Order
		|WHERE
		|	ISNULL(InventoryReceivedBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsProductionOrdersChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsProductionOrdersChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsProductionOrdersChange.ProductionOrder) AS ProductionOrderPresentation,
		|	REFPRESENTATION(RegisterRecordsProductionOrdersChange.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	REFPRESENTATION(RegisterRecordsProductionOrdersChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(ProductionOrdersBalances.ProductsAndServices.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsProductionOrdersChange.QuantityChange, 0) + ISNULL(ProductionOrdersBalances.QuantityBalance, 0) AS BalanceProductionOrders,
		|	ISNULL(ProductionOrdersBalances.QuantityBalance, 0) AS QuantityBalanceProductionOrders
		|FROM
		|	RegisterRecordsProductionOrdersChange AS RegisterRecordsProductionOrdersChange
		|		LEFT JOIN AccumulationRegister.ProductionOrders.Balance(
		|				&ControlTime,
		|				(Company, ProductionOrder, ProductsAndServices, Characteristic) In
		|					(SELECT
		|						RegisterRecordsProductionOrdersChange.Company AS Company,
		|						RegisterRecordsProductionOrdersChange.ProductionOrder AS ProductionOrder,
		|						RegisterRecordsProductionOrdersChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsProductionOrdersChange.Characteristic AS Characteristic
		|					FROM
		|						RegisterRecordsProductionOrdersChange AS RegisterRecordsProductionOrdersChange)) AS ProductionOrdersBalances
		|		ON RegisterRecordsProductionOrdersChange.Company = ProductionOrdersBalances.Company
		|			AND RegisterRecordsProductionOrdersChange.ProductionOrder = ProductionOrdersBalances.ProductionOrder
		|			AND RegisterRecordsProductionOrdersChange.ProductsAndServices = ProductionOrdersBalances.ProductsAndServices
		|			AND RegisterRecordsProductionOrdersChange.Characteristic = ProductionOrdersBalances.Characteristic
		|WHERE
		|	ISNULL(ProductionOrdersBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsOrdersPlacementChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsOrdersPlacementChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsOrdersPlacementChange.CustomerOrder) AS CustomerOrderPresentation,
		|	REFPRESENTATION(RegisterRecordsOrdersPlacementChange.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	REFPRESENTATION(RegisterRecordsOrdersPlacementChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsOrdersPlacementChange.SupplySource) AS SupplySourcePresentation,
		|	REFPRESENTATION(OrdersPlacementBalances.ProductsAndServices.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsOrdersPlacementChange.QuantityChange, 0) + ISNULL(OrdersPlacementBalances.QuantityBalance, 0) AS BalanceOrdersPlacement,
		|	ISNULL(OrdersPlacementBalances.QuantityBalance, 0) AS QuantityBalanceOrdersPlacement
		|FROM
		|	RegisterRecordsOrdersPlacementChange AS RegisterRecordsOrdersPlacementChange
		|		LEFT JOIN AccumulationRegister.OrdersPlacement.Balance(
		|				&ControlTime,
		|				(Company, CustomerOrder, ProductsAndServices, Characteristic, SupplySource) In
		|					(SELECT
		|						RegisterRecordsOrdersPlacementChange.Company AS Company,
		|						RegisterRecordsOrdersPlacementChange.CustomerOrder AS CustomerOrder,
		|						RegisterRecordsOrdersPlacementChange.ProductsAndServices AS ProductsAndServices,
		|						RegisterRecordsOrdersPlacementChange.Characteristic AS Characteristic,
		|						RegisterRecordsOrdersPlacementChange.SupplySource AS SupplySource
		|					FROM
		|						RegisterRecordsOrdersPlacementChange AS RegisterRecordsOrdersPlacementChange)) AS OrdersPlacementBalances
		|		ON RegisterRecordsOrdersPlacementChange.Company = OrdersPlacementBalances.Company
		|			AND RegisterRecordsOrdersPlacementChange.CustomerOrder = OrdersPlacementBalances.CustomerOrder
		|			AND RegisterRecordsOrdersPlacementChange.ProductsAndServices = OrdersPlacementBalances.ProductsAndServices
		|			AND RegisterRecordsOrdersPlacementChange.Characteristic = OrdersPlacementBalances.Characteristic
		|			AND RegisterRecordsOrdersPlacementChange.SupplySource = OrdersPlacementBalances.SupplySource
		|WHERE
		|	ISNULL(OrdersPlacementBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty()
			OR Not ResultsArray[3].IsEmpty()
			OR Not ResultsArray[4].IsEmpty() Then
			DocumentObjectInventoryAssembly = DocumentRefInventoryAssembly.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectInventoryAssembly, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectInventoryAssembly, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory received.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			SmallBusinessServer.ShowMessageAboutPostingToInventoryReceivedRegisterErrors(DocumentObjectInventoryAssembly, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance by production orders.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			SmallBusinessServer.ShowMessageAboutPostingToProductionOrdersRegisterErrors(DocumentObjectInventoryAssembly, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on the inventories placement.
		If Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			SmallBusinessServer.ShowMessageAboutPostingToOrdersPlacementRegisterErrors(DocumentObjectInventoryAssembly, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure // RunControl()

#Region PrintInterface

// Function checks if the document is posted and calls the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_InventoryAssemblyAssembly";
	
	FirstDocument = True;
	
	For Each CurrentDocument IN ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		If TemplateName = "M11" Then
			
			Query = New Query();
			Query.SetParameter("CurrentDocument", CurrentDocument);
			
			If CurrentDocument.OperationKind = Enums.OperationKindsInventoryAssembly.Assembly Then
			
				Query.Text =
				"SELECT
				|	InventoryAssembly.Date AS DocumentDate,
				|	InventoryAssembly.Company AS Company,
				|	InventoryAssembly.Number AS Number,
				|	InventoryAssembly.Company.Prefix AS Prefix,
				|	InventoryAssembly.InventoryStructuralUnit AS Sender,
				|	InventoryAssembly.StructuralUnit AS Recipient,
				|	InventoryAssembly.Inventory.(
				|		LineNumber AS LineNumber,
				|		ProductsAndServices.DescriptionFull AS InventoryItem,
				|		ProductsAndServices.SKU AS SKU,
				|		Quantity AS Quantity,
				|		Reserve AS Reserve,
				|		Ref.CustomerOrder AS CustomerOrder,
				|		Characteristic,
				|		MeasurementUnit.Description,
				|		MeasurementUnit.Code,
				|		ProductsAndServices.InventoryGLAccount.Code AS Account,
				|		ProductsAndServices.Code AS ProductsAndServicesNumber
				|	)
				|FROM
				|	Document.InventoryAssembly AS InventoryAssembly
				|WHERE
				|	InventoryAssembly.Ref = &CurrentDocument
				|
				|ORDER BY
				|	LineNumber";
				
				Header = Query.Execute().Select();
				Header.Next();
				
				LinesSelectionInventory = Header.Inventory.Select();
			
			Else
			
				Query.Text =
				"SELECT
				|	InventoryAssembly.Date AS DocumentDate,
				|	InventoryAssembly.Company AS Company,
				|	InventoryAssembly.Number AS Number,
				|	InventoryAssembly.Company.Prefix AS Prefix,
				|	InventoryAssembly.InventoryStructuralUnit AS Sender,
				|	InventoryAssembly.StructuralUnit AS Recipient,
				|	InventoryAssembly.Products.(
				|		LineNumber AS LineNumber,
				|		ProductsAndServices.DescriptionFull AS InventoryItem,
				|		ProductsAndServices.SKU AS SKU,
				|		Quantity AS Quantity,
				|		Reserve AS Reserve,
				|		Ref.CustomerOrder AS CustomerOrder,
				|		Characteristic,
				|		MeasurementUnit.Description,
				|		MeasurementUnit.Code,
				|		ProductsAndServices.InventoryGLAccount.Code AS Account,
				|		ProductsAndServices.Code AS ProductsAndServicesNumber
				|	)
				|FROM
				|	Document.InventoryAssembly AS InventoryAssembly
				|WHERE
				|	InventoryAssembly.Ref = &CurrentDocument
				|
				|ORDER BY
				|	LineNumber";
				
				Header = Query.Execute().Select();
				Header.Next();
				
				LinesSelectionInventory = Header.Products.Select();
				
			EndIf;
			
			SpreadsheetDocument.PrintParametersName = "PARAMETERS_PRINT_InventoryAssembly_InventoryAssembly_M11";
			
			Template = PrintManagement.PrintedFormsTemplate("Document.InventoryAssembly.PF_MXL_M11");
			
			InfoAboutCompany = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate);
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;
			
			TemplateArea = Template.GetArea("Header");
			TemplateArea.Parameters.Title       = "REQUISITION-INVOICE No "
													+ DocumentNumber
													+ " from "
													+ Format(Header.DocumentDate, "DLF=DD");
			TemplateArea.Parameters.Fill(Header);
			TemplateArea.Parameters.CompanyPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany);
			TemplateArea.Parameters.CompilationDate          = Format(Header.DocumentDate, "DF=dd.MM.yy");
			
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("String");
			
			While LinesSelectionInventory.Next() Do
			
				TemplateArea.Parameters.Fill(LinesSelectionInventory);
				TemplateArea.Parameters.InventoryItem = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(LinesSelectionInventory.InventoryItem, LinesSelectionInventory.Characteristic, LinesSelectionInventory.SKU);
				
				SpreadsheetDocument.Put(TemplateArea);
				
			EndDo;
			
			TemplateArea = Template.GetArea("Footer");
			
			SpreadsheetDocument.Put(TemplateArea);
			
		ElsIf TemplateName = "MX18" Then
			
			Query = New Query();
			Query.SetParameter("CurrentDocument", CurrentDocument);
			
			If CurrentDocument.OperationKind = Enums.OperationKindsInventoryAssembly.Assembly Then
			
				Query.Text =
				"SELECT
				|	InventoryAssembly.Date AS DocumentDate,
				|	InventoryAssembly.Company AS Company,
				|	InventoryAssembly.Number AS Number,
				|	InventoryAssembly.Company.Prefix AS Prefix,
				|	InventoryAssembly.StructuralUnit AS Sender,
				|	InventoryAssembly.ProductsStructuralUnit AS Recipient,
				|	InventoryAssembly.Products.(
				|		LineNumber,
				|		ProductsAndServices.DescriptionFull AS InventoryItem,
				|		ProductsAndServices.SKU AS SKU,
				|		Quantity AS PlacesQuantity,
				|		Reserve AS Reserve,
				|		Ref.CustomerOrder AS CustomerOrder,
				|		Characteristic,
				|		MeasurementUnit.Description AS PackagingKind,
				|		ProductsAndServices.InventoryGLAccount.Code AS Account,
				|		ProductsAndServices.Code AS ProductCode,
				|		ProductsAndServices.MeasurementUnit AS MeasurementUnitDescription,
				|		ProductsAndServices.MeasurementUnit.Code AS MeasurementUnitCodeByOKEI,
				|		CASE
				|			WHEN InventoryAssembly.Products.MeasurementUnit REFS Catalog.UOM
				|				THEN InventoryAssembly.Products.MeasurementUnit.Factor
				|			ELSE 1
				|		END AS QuantityInOnePlace
				|	)
				|FROM
				|	Document.InventoryAssembly AS InventoryAssembly
				|WHERE
				|	InventoryAssembly.Ref = &CurrentDocument";
				
				Header = Query.Execute().Select();
				Header.Next();
				
				LinesSelectionInventory = Header.Products.Unload();
				
			Else
				
				Query.Text =
				"SELECT
				|	InventoryAssembly.Date AS DocumentDate,
				|	InventoryAssembly.Company AS Company,
				|	InventoryAssembly.Number AS Number,
				|	InventoryAssembly.Company.Prefix AS Prefix,
				|	InventoryAssembly.StructuralUnit AS Sender,
				|	InventoryAssembly.ProductsStructuralUnit AS Recipient,
				|	InventoryAssembly.Inventory.(
				|		LineNumber,
				|		ProductsAndServices.DescriptionFull AS InventoryItem,
				|		ProductsAndServices.SKU AS SKU,
				|		Quantity AS PlacesQuantity,
				|		Reserve AS Reserve,
				|		Ref.CustomerOrder AS CustomerOrder,
				|		Characteristic,
				|		MeasurementUnit.Description AS PackagingKind,
				|		ProductsAndServices.InventoryGLAccount.Code AS Account,
				|		ProductsAndServices.Code AS ProductCode,
				|		ProductsAndServices.MeasurementUnit AS MeasurementUnitDescription,
				|		ProductsAndServices.MeasurementUnit.Code AS MeasurementUnitCodeByOKEI,
				|		CASE
				|			WHEN InventoryAssembly.Inventory.MeasurementUnit REFS Catalog.UOM
				|				THEN InventoryAssembly.Inventory.MeasurementUnit.Factor
				|			ELSE 1
				|		END AS QuantityInOnePlace
				|	)
				|FROM
				|	Document.InventoryAssembly AS InventoryAssembly
				|WHERE
				|	InventoryAssembly.Ref = &CurrentDocument";
				
				Header = Query.Execute().Select();
				Header.Next();
				
				LinesSelectionInventory = Header.Inventory.Unload();
				
			EndIf;
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_InventoryAssemblyAssembly_MH18";
			
			Template = PrintManagement.PrintedFormsTemplate("Document.InventoryAssembly.PF_MXL_MX18");
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;
			
			// Displaying general header attributes
			InfoAboutCompany = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate);
			TemplateArea         = Template.GetArea("Header");
			TemplateArea.Parameters.Fill(Header);
			TemplateArea.Parameters.CompanyPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany);
			TemplateArea.Parameters.DocumentNumber           = DocumentNumber;
			TemplateArea.Parameters.DocumentDate            = Header.DocumentDate;
			SpreadsheetDocument.Put(TemplateArea);
			
			RowsPerPage = 23;
			RowsCaps      = 10;
			RowsOfBasement    = 9;
			PageNumber   = 1;
			
			// Displaying table title
			TableTitle = Template.GetArea("TableTitle");
			TableTitle.Parameters.PageNumber = "Page " + PageNumber; 
			SpreadsheetDocument.Put(TableTitle);
			
			LineCount = LinesSelectionInventory.Count();
			
			If LineCount = 1 Then
				WrapLastRow = 0;
			Else
				EntirePagesWithBasement     = Int((RowsCaps + LineCount + RowsOfBasement) / RowsPerPage);
				EntirePagesWithoutBasement    = Int((RowsCaps + LineCount - 1) / RowsPerPage);
				WrapLastRow = EntirePagesWithBasement - EntirePagesWithoutBasement;
			EndIf;
			
			// initializing totals on the page
			TotalPlacesCountByPage = 0;
			
			// initializing totals on the document
			TotalQuantity  = 0;
			
			Num = 0;
			
			// Displaying multiline part of the document
			TotalsAreaByPage = Template.GetArea("TotalsByPage");
			
			TemplateArea = Template.GetArea("String");
			For Each StringInventory IN LinesSelectionInventory Do
			
				Num = Num + 1;
				//Start a new page if the previous string is
				//the last one on the page or it is time to transfer the last string to the last page with footer.
				AWholePage = (RowsCaps + Num - 1) / RowsPerPage;
				
				If (AWholePage = Int(AWholePage))
					OR ((WrapLastRow = 1) and (Num = LineCount)) Then
					
					TotalsAreaByPage.Parameters.TotalPlacesOnPage = TotalPlacesCountByPage;
					
					SpreadsheetDocument.Put(TotalsAreaByPage);
					
					// initializing totals on the page
					TotalPlacesCountByPage = 0;
					
					PageNumber = PageNumber + 1;
					SpreadsheetDocument.PutHorizontalPageBreak();
					TableTitle.Parameters.PageNumber = "Page " + PageNumber;
					SpreadsheetDocument.Put(TableTitle);
					
				EndIf;
				
				TemplateArea.Parameters.Fill(StringInventory);
				PlacesQuantity = StringInventory.PlacesQuantity;
				TemplateArea.Parameters.ProductDescription = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(StringInventory.InventoryItem, StringInventory.Characteristic, StringInventory.SKU);
				SpreadsheetDocument.Put(TemplateArea);
				
				// Update totals by page
				TotalPlacesCountByPage = TotalPlacesCountByPage + PlacesQuantity;
				
				// Update totals by document
				TotalQuantity  = TotalQuantity  + PlacesQuantity;
				
			EndDo;
			
			TotalsAreaByPage.Parameters.TotalPlacesOnPage = TotalPlacesCountByPage;
			
			SpreadsheetDocument.Put(TotalsAreaByPage);
			
			// Display totals on the full document
			TemplateArea = Template.GetArea("Total");
			TemplateArea.Parameters.TotalPlaces = TotalQuantity;
			
			SpreadsheetDocument.Put(TemplateArea);
			
			// Display the footer of the document
			TemplateArea = Template.GetArea("Footer");
			TemplateArea.Parameters.Fill(Header);
			SpreadsheetDocument.Put(TemplateArea);
			
			// Set the layout parameters
			SpreadsheetDocument.TopMargin = 0;
			SpreadsheetDocument.LeftMargin  = 0;
			SpreadsheetDocument.BottomMargin  = 0;
			SpreadsheetDocument.RightMargin = 0;
			SpreadsheetDocument.PageOrientation = PageOrientation.Landscape;
			
		ElsIf TemplateName = "MerchandiseFillingForm" Then
			
			Query = New Query();
			Query.SetParameter("CurrentDocument", CurrentDocument);
			
			If CurrentDocument.OperationKind = Enums.OperationKindsInventoryAssembly.Assembly Then
				
				Query.Text =
				"SELECT
				|	InventoryAssembly.Date AS DocumentDate,
				|	InventoryAssembly.StructuralUnit AS WarehousePresentation,
				|	InventoryAssembly.Cell AS CellPresentation,
				|	InventoryAssembly.Number AS Number,
				|	InventoryAssembly.Company.Prefix AS Prefix,
				|	InventoryAssembly.Inventory.(
				|		LineNumber AS LineNumber,
				|		ProductsAndServices.Warehouse AS Warehouse,
				|		ProductsAndServices.Cell AS Cell,
				|		CASE
				|			WHEN (CAST(InventoryAssembly.Inventory.ProductsAndServices.DescriptionFull AS String(100))) = """"
				|				THEN InventoryAssembly.Inventory.ProductsAndServices.Description
				|			ELSE InventoryAssembly.Inventory.ProductsAndServices.DescriptionFull
				|		END AS InventoryItem,
				|		ProductsAndServices.SKU AS SKU,
				|		ProductsAndServices.Code AS Code,
				|		MeasurementUnit.Description AS MeasurementUnit,
				|		Quantity AS Quantity,
				|		Characteristic,
				|		ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType
				|	)
				|FROM
				|	Document.InventoryAssembly AS InventoryAssembly
				|WHERE
				|	InventoryAssembly.Ref = &CurrentDocument
				|
				|ORDER BY
				|	LineNumber";
				
				Header = Query.Execute().Select();
				Header.Next();
				
				LinesSelectionInventory = Header.Inventory.Select();
				
			Else
				
				Query.Text = 
				"SELECT
				|	InventoryAssembly.Date AS DocumentDate,
				|	InventoryAssembly.StructuralUnit AS WarehousePresentation,
				|	InventoryAssembly.Cell AS CellPresentation,
				|	InventoryAssembly.Number AS Number,
				|	InventoryAssembly.Company.Prefix AS Prefix,
				|	InventoryAssembly.Products.(
				|		LineNumber AS LineNumber,
				|		ProductsAndServices.Warehouse AS Warehouse,
				|		ProductsAndServices.Cell AS Cell,
				|		CASE
				|			WHEN (CAST(InventoryAssembly.Products.ProductsAndServices.DescriptionFull AS String(100))) = """"
				|				THEN InventoryAssembly.Products.ProductsAndServices.Description
				|			ELSE InventoryAssembly.Products.ProductsAndServices.DescriptionFull
				|		END AS InventoryItem,
				|		ProductsAndServices.SKU AS SKU,
				|		ProductsAndServices.Code AS Code,
				|		MeasurementUnit.Description AS MeasurementUnit,
				|		Quantity AS Quantity,
				|		Characteristic AS Characteristic,
				|		ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType
				|	)
				|FROM
				|	Document.InventoryAssembly AS InventoryAssembly
				|WHERE
				|	InventoryAssembly.Ref = &CurrentDocument";
				
				Header = Query.Execute().Select();
				Header.Next();
				
				LinesSelectionInventory = Header.Products.Select();
				
			EndIf;
			
			SpreadsheetDocument.PrintParametersName = "PARAMETERS_PRINT_InventoryAssembly_MerchandiseFillingForm";
			
			Template = PrintManagement.PrintedFormsTemplate("Document.InventoryAssembly.PF_MXL_MerchandiseFillingForm");
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;
			
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText = "Production No "
													+ DocumentNumber
													+ " from "
													+ Format(Header.DocumentDate, "DLF=DD");
													
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("Warehouse");
			TemplateArea.Parameters.WarehousePresentation = Header.WarehousePresentation;
			SpreadsheetDocument.Put(TemplateArea);
			
			If Constants.FunctionalOptionAccountingByCells.Get() Then
				
				TemplateArea = Template.GetArea("Cell");
				TemplateArea.Parameters.CellPresentation = Header.CellPresentation;
				SpreadsheetDocument.Put(TemplateArea);
				
			EndIf;
			
			TemplateArea = Template.GetArea("PrintingTime");
			TemplateArea.Parameters.PrintingTime = "Date and time of printing: "
												 	+ CurrentDate()
													+ ". User: "
													+ Users.CurrentUser();
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("TableHeader");
			SpreadsheetDocument.Put(TemplateArea);
			TemplateArea = Template.GetArea("String");
			
			While LinesSelectionInventory.Next() Do

				If Not LinesSelectionInventory.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem Then
					Continue;
				EndIf;
				
				TemplateArea.Parameters.Fill(LinesSelectionInventory);
				TemplateArea.Parameters.InventoryItem = SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(LinesSelectionInventory.InventoryItem, 
																		LinesSelectionInventory.Characteristic, LinesSelectionInventory.SKU);
					
				SpreadsheetDocument.Put(TemplateArea);
				
			EndDo;
			
			TemplateArea = Template.GetArea("Total");
			SpreadsheetDocument.Put(TemplateArea);	
			
		EndIf;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction // PrintForm()

// Generate objects printing forms.
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "M11") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "M11", "M-11", PrintForm(ObjectsArray, PrintObjects, "M11"));
		
	EndIf;
			
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "MX18") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "MX18", "MX-18", PrintForm(ObjectsArray, PrintObjects, "MX18"));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "MerchandiseFillingForm") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "MerchandiseFillingForm", "Merchandise filling form", PrintForm(ObjectsArray, PrintObjects, "MerchandiseFillingForm"));
		
	EndIf;
	
	// parameters of sending printing forms by email
	SmallBusinessServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure // Print()

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "M11,MX18";
	PrintCommand.Presentation = NStr("en='Custom kit of documents';ru='Настраиваемый комплект документов'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "M11";
	PrintCommand.Presentation = NStr("en='M11 (Shipment request)';ru='М11 (Требование-накладная)'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 4;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "MX18";
	PrintCommand.Presentation = NStr("en='MH18 (Finished products customer invoice)';ru='МХ18 (Накладная на передачу готовой продукции)'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 7;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "MerchandiseFillingForm";
	PrintCommand.Presentation = NStr("en='Merchandise filling form';ru='Бланк товарного наполнения'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 10;
	
EndProcedure

#EndRegion

#EndIf