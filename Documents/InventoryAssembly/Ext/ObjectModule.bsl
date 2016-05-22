#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF FILLING THE DOCUMENT

// Procedure fills tabular section according to specification.
//
Procedure FillTabularSectionBySpecification(NodesSpecificationStack, NodesTable = Undefined) Export
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProduction.LineNumber AS LineNumber,
	|	TableProduction.Quantity AS Quantity,
	|	TableProduction.Factor AS Factor,
	|	TableProduction.Specification AS Specification
	|INTO TemporaryTableProduction
	|FROM
	|	&TableProduction AS TableProduction
	|WHERE
	|	TableProduction.Specification <> VALUE(Catalog.Specifications.EmptyRef)";
	
	If NodesTable = Undefined Then
		Inventory.Clear();
		TableProduction = Products.Unload();
		Array = New Array();
		Array.Add(Type("Number"));
		TypeDescriptionC = New TypeDescription(Array, , ,New NumberQualifiers(10,3));
		TableProduction.Columns.Add("Factor", TypeDescriptionC);
		For Each StringProducts IN TableProduction Do
			If ValueIsFilled(StringProducts.MeasurementUnit)
				AND TypeOf(StringProducts.MeasurementUnit) = Type("CatalogRef.UOM") Then
				StringProducts.Factor = StringProducts.MeasurementUnit.Factor;
			Else
				StringProducts.Factor = 1;
			EndIf;
		EndDo;
		NodesTable = TableProduction.CopyColumns("LineNumber,Quantity,Factor,Specification");
		Query.SetParameter("TableProduction", TableProduction);
	Else
		Query.SetParameter("TableProduction", NodesTable);
	EndIf;
	
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	MIN(TableProduction.LineNumber) AS ProductionLineNumber,
	|	TableProduction.Specification AS ProductionSpecification,
	|	MIN(TableMaterials.LineNumber) AS StructureLineNumber,
	|	TableMaterials.ContentRowType AS ContentRowType,
	|	TableMaterials.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(TableMaterials.Quantity / TableMaterials.ProductsQuantity * TableProduction.Factor * TableProduction.Quantity) AS Quantity,
	|	TableMaterials.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN TableMaterials.ContentRowType = VALUE(Enum.SpecificationContentRowTypes.Node)
	|				AND VALUETYPE(TableMaterials.MeasurementUnit) = Type(Catalog.UOM)
	|				AND TableMaterials.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
	|			THEN TableMaterials.MeasurementUnit.Factor
	|		ELSE 1
	|	END AS Factor,
	|	TableMaterials.CostPercentage AS CostPercentage,
	|	TableMaterials.Specification AS Specification
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		LEFT JOIN Catalog.Specifications.Content AS TableMaterials
	|		ON TableProduction.Specification = TableMaterials.Ref,
	|	Constant.FunctionalOptionUseCharacteristics AS UseCharacteristics
	|WHERE
	|	TableMaterials.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|
	|GROUP BY
	|	TableProduction.Specification,
	|	TableMaterials.ContentRowType,
	|	TableMaterials.ProductsAndServices,
	|	TableMaterials.MeasurementUnit,
	|	CASE
	|		WHEN TableMaterials.ContentRowType = VALUE(Enum.SpecificationContentRowTypes.Node)
	|				AND VALUETYPE(TableMaterials.MeasurementUnit) = Type(Catalog.UOM)
	|				AND TableMaterials.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
	|			THEN TableMaterials.MeasurementUnit.Factor
	|		ELSE 1
	|	END,
	|	TableMaterials.CostPercentage,
	|	TableMaterials.Specification,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END
	|
	|ORDER BY
	|	ProductionLineNumber,
	|	StructureLineNumber";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If Selection.ContentRowType = Enums.SpecificationContentRowTypes.Node Then
			NodesTable.Clear();
			If Not NodesSpecificationStack.Find(Selection.Specification) = Undefined Then
				MessageText = NStr("en = 'During filling in of the Specification materials
									|tabular section a recursive item occurrence was found'")+" "+Selection.ProductsAndServices+" "+NStr("en = 'in specifications'")+" "+Selection.ProductionSpecification+"
									|The operation failed.";
				Raise MessageText;
			EndIf;
			NodesSpecificationStack.Add(Selection.Specification);
			NewRow = NodesTable.Add();
			FillPropertyValues(NewRow, Selection);
			FillTabularSectionBySpecification(NodesSpecificationStack, NodesTable);
		Else
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
		EndIf;
	EndDo;
	
	NodesSpecificationStack.Clear();
	Inventory.GroupBy("ProductsAndServices, Characteristic, Batch, MeasurementUnit, Specification, CostPercentage", "Quantity, Reserve");
	
EndProcedure // FillTabularSectionBySpecification()

// Procedure fills out the Quantity column according to reserves to be ordered.
//
Procedure FillColumnReserveByReserves() Export
	
	Inventory.LoadColumn(New Array(Inventory.Count()), "Reserve");
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.ProductsAndServices AS ProductsAndServices,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	&Order AS CustomerOrder
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory";
	
	Query.SetParameter("TableInventory", Inventory.Unload());
	Query.SetParameter("Order", ?(ValueIsFilled(CustomerOrder), CustomerOrder, Documents.CustomerOrder.EmptyRef()));
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.CustomerOrder AS CustomerOrder,
	|	InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.CustomerOrder AS CustomerOrder,
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
	|						CASE
	|							WHEN &StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division)
	|								THEN TableInventory.ProductsAndServices.ExpensesGLAccount
	|							ELSE TableInventory.ProductsAndServices.InventoryGLAccount
	|						END,
	|						TableInventory.ProductsAndServices,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.CustomerOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory
	|					WHERE
	|						TableInventory.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef))) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.CustomerOrder,
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
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|		AND DocumentRegisterRecordsInventory.CustomerOrder <> VALUE(Document.CustomerOrder.EmptyRef)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.CustomerOrder,
	|	InventoryBalances.ProductsAndServices,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", InventoryStructuralUnit);
	Query.SetParameter("StructuralUnitType", InventoryStructuralUnit.StructuralUnitType);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("ProductsAndServices", Selection.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		TotalBalance = Selection.QuantityBalance;
		ArrayOfRowsInventory = Inventory.FindRows(StructureForSearch);
		For Each StringInventory IN ArrayOfRowsInventory Do
			
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
		
	EndDo;
	
EndProcedure // FillColumnReserveByReserves()

// Procedure for filling the document basing on Production order.
//
Procedure FillByProductionOrder(FillingData) Export
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT
	|	ProductionOrder.Ref AS BasisRef,
	|	ProductionOrder.Posted AS BasisPosted,
	|	ProductionOrder.Closed AS Closed,
	|	ProductionOrder.OrderState AS OrderState,
	|	CASE
	|		WHEN ProductionOrder.OperationKind = VALUE(Enum.OperationKindsProductionOrder.Assembly)
	|			THEN VALUE(Enum.OperationKindsInventoryAssembly.Assembly)
	|		ELSE VALUE(Enum.OperationKindsInventoryAssembly.Disassembly)
	|	END AS OperationKind,
	|	ProductionOrder.Start AS Start,
	|	ProductionOrder.Finish AS Finish,
	|	ProductionOrder.Ref AS BasisDocument,
	|	ProductionOrder.CustomerOrder AS CustomerOrder,
	|	ProductionOrder.Company AS Company,
	|	ProductionOrder.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN ProductionOrder.StructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|				OR ProductionOrder.StructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division)
	|			THEN ProductionOrder.StructuralUnit.TransferRecipient
	|		ELSE VALUE(Catalog.StructuralUnits.EmptyRef)
	|	END AS ProductsStructuralUnit,
	|	CASE
	|		WHEN ProductionOrder.StructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|				OR ProductionOrder.StructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division)
	|			THEN ProductionOrder.StructuralUnit.TransferRecipientCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS ProductsCell,
	|	CASE
	|		WHEN ProductionOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|				OR ProductionOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division)
	|			THEN ProductionOrder.StructuralUnit.TransferSource
	|		ELSE VALUE(Catalog.StructuralUnits.EmptyRef)
	|	END AS InventoryStructuralUnit,
	|	CASE
	|		WHEN ProductionOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|				OR ProductionOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division)
	|			THEN ProductionOrder.StructuralUnit.TransferSourceCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS CellInventory,
	|	ProductionOrder.StructuralUnit.RecipientOfWastes AS DisposalsStructuralUnit,
	|	ProductionOrder.StructuralUnit.DisposalsRecipientCell AS DisposalsCell
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|WHERE
	|	ProductionOrder.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		VerifiedAttributesValues = New Structure("OrderState, Closed, Posted", Selection.OrderState, Selection.Closed, Selection.BasisPosted);
		Documents.ProductionOrder.VerifyEnteringAbilityByProductionOrder(Selection.BasisRef, VerifiedAttributesValues);
	EndDo;
	
	IntermediateStructuralUnit = StructuralUnit;
	FillPropertyValues(ThisObject, Selection);
	
	If ValueIsFilled(StructuralUnit) Then
			
		If Not ValueIsFilled(ProductsStructuralUnit) Then
			ProductsStructuralUnit = StructuralUnit;
		EndIf;
		
		If Not ValueIsFilled(InventoryStructuralUnit) Then
			InventoryStructuralUnit = StructuralUnit;
		EndIf;
		
		If Not ValueIsFilled(DisposalsStructuralUnit) Then
			DisposalsStructuralUnit = StructuralUnit;
		EndIf;
		
	EndIf;
	
	If IntermediateStructuralUnit <> StructuralUnit Then
		Cell = Undefined;
	EndIf;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	OrdersBalance.ProductionOrder AS ProductionOrder,
	|	OrdersBalance.ProductsAndServices AS ProductsAndServices,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		OrdersBalance.ProductionOrder AS ProductionOrder,
	|		OrdersBalance.ProductsAndServices AS ProductsAndServices,
	|		OrdersBalance.Characteristic AS Characteristic,
	|		OrdersBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.ProductionOrders.Balance(
	|				,
	|				ProductionOrder = &BasisDocument
	|					AND ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsProductionOrders.ProductionOrder,
	|		DocumentRegisterRecordsProductionOrders.ProductsAndServices,
	|		DocumentRegisterRecordsProductionOrders.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsProductionOrders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsProductionOrders.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsProductionOrders.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.ProductionOrders AS DocumentRegisterRecordsProductionOrders
	|	WHERE
	|		DocumentRegisterRecordsProductionOrders.Recorder = &Ref) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.ProductionOrder,
	|	OrdersBalance.ProductsAndServices,
	|	OrdersBalance.Characteristic
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionOrder.Products.(
	|		ProductsAndServices AS ProductsAndServices,
	|		ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
	|		Characteristic AS Characteristic,
	|		Quantity AS Quantity,
	|		CASE
	|			WHEN VALUETYPE(ProductionOrder.Products.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN 1
	|			ELSE ProductionOrder.Products.MeasurementUnit.Factor
	|		END AS Factor,
	|		MeasurementUnit AS MeasurementUnit,
	|		Specification AS Specification
	|	),
	|	ProductionOrder.Inventory.(
	|		ProductsAndServices AS ProductsAndServices,
	|		ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
	|		Characteristic AS Characteristic,
	|		Quantity AS Quantity,
	|		CASE
	|			WHEN VALUETYPE(ProductionOrder.Inventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN 1
	|			ELSE ProductionOrder.Inventory.MeasurementUnit.Factor
	|		END AS Factor,
	|		MeasurementUnit AS MeasurementUnit,
	|		Specification AS Specification,
	|		1 AS CostPercentage
	|	)
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|WHERE
	|	ProductionOrder.Ref = &BasisDocument";
	
	Query.Text = Query.Text + ";";
	
	If FillingData.OperationKind = Enums.OperationKindsProductionOrder.Disassembly Then
		
		TabularSectionName = "Inventory";
		Query.Text = Query.Text +
		"SELECT
		|	OrdersBalance.ProductsAndServices AS ProductsAndServices,
		|	OrdersBalance.Characteristic AS Characteristic,
		|	OrdersBalance.MeasurementUnit AS MeasurementUnit,
		|	OrdersBalance.Specification AS Specification,
		|	SUM(OrdersBalance.Reserve) AS Reserve,
		|	SUM(OrdersBalance.Quantity) AS Quantity
		|FROM
		|	(SELECT
		|		OrderForProductsProduction.ProductsAndServices AS ProductsAndServices,
		|		OrderForProductsProduction.Characteristic AS Characteristic,
		|		OrderForProductsProduction.MeasurementUnit AS MeasurementUnit,
		|		OrderForProductsProduction.Specification AS Specification,
		|		OrderForProductsProduction.Reserve AS Reserve,
		|		OrderForProductsProduction.Quantity AS Quantity
		|	FROM
		|		Document.ProductionOrder.Products AS OrderForProductsProduction
		|	WHERE
		|		OrderForProductsProduction.Ref = &BasisDocument
		|		AND OrderForProductsProduction.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		InventoryAssemblyProducts.ProductsAndServices,
		|		InventoryAssemblyProducts.Characteristic,
		|		InventoryAssemblyProducts.MeasurementUnit,
		|		InventoryAssemblyProducts.Specification,
		|		-InventoryAssemblyProducts.Reserve,
		|		-InventoryAssemblyProducts.Quantity
		|	FROM
		|		Document.InventoryAssembly.Products AS InventoryAssemblyProducts
		|	WHERE
		|		InventoryAssemblyProducts.Ref.Posted
		|		AND InventoryAssemblyProducts.Ref.BasisDocument = &BasisDocument
		|		AND Not InventoryAssemblyProducts.Ref = &Ref) AS OrdersBalance
		|
		|GROUP BY
		|	OrdersBalance.ProductsAndServices,
		|	OrdersBalance.Characteristic,
		|	OrdersBalance.MeasurementUnit,
		|	OrdersBalance.Specification
		|
		|HAVING
		|	SUM(OrdersBalance.Quantity) > 0";
		
	Else
		
		TabularSectionName = "Products";
		Query.Text = Query.Text +
		"SELECT
		|	OrdersBalance.ProductsAndServices AS ProductsAndServices,
		|	OrdersBalance.Characteristic AS Characteristic,
		|	OrdersBalance.MeasurementUnit AS MeasurementUnit,
		|	OrdersBalance.Specification AS Specification,
		|	SUM(OrdersBalance.Quantity) AS Quantity
		|FROM
		|	(SELECT
		|		ProductionOrderInventory.ProductsAndServices AS ProductsAndServices,
		|		ProductionOrderInventory.Characteristic AS Characteristic,
		|		ProductionOrderInventory.MeasurementUnit AS MeasurementUnit,
		|		ProductionOrderInventory.Specification AS Specification,
		|		ProductionOrderInventory.Quantity AS Quantity
		|	FROM
		|		Document.ProductionOrder.Inventory AS ProductionOrderInventory
		|	WHERE
		|		ProductionOrderInventory.Ref = &BasisDocument
		|		AND ProductionOrderInventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		InventoryAssemblyInventory.ProductsAndServices,
		|		InventoryAssemblyInventory.Characteristic,
		|		InventoryAssemblyInventory.MeasurementUnit,
		|		InventoryAssemblyInventory.Specification,
		|		-InventoryAssemblyInventory.Quantity
		|	FROM
		|		Document.InventoryAssembly.Inventory AS InventoryAssemblyInventory
		|	WHERE
		|		InventoryAssemblyInventory.Ref.Posted
		|		AND InventoryAssemblyInventory.Ref.BasisDocument = &BasisDocument
		|		AND Not InventoryAssemblyInventory.Ref = &Ref) AS OrdersBalance
		|
		|GROUP BY
		|	OrdersBalance.ProductsAndServices,
		|	OrdersBalance.Characteristic,
		|	OrdersBalance.MeasurementUnit,
		|	OrdersBalance.Specification
		|
		|HAVING
		|	SUM(OrdersBalance.Quantity) > 0";
		
	EndIf;
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("ProductionOrder,ProductsAndServices,Characteristic");
	
	Products.Clear();
	Inventory.Clear();
	Disposals.Clear();
	If BalanceTable.Count() > 0 Then
		
		Selection = ResultsArray[1].Select();
		Selection.Next();
		For Each SelectionProducts IN Selection[TabularSectionName].Unload() Do
			
			If SelectionProducts.ProductsAndServicesType <> Enums.ProductsAndServicesTypes.InventoryItem Then
				Continue;
			EndIf;
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("ProductionOrder", FillingData);
			StructureForSearch.Insert("ProductsAndServices", SelectionProducts.ProductsAndServices);
			StructureForSearch.Insert("Characteristic", SelectionProducts.Characteristic);
			
			BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
			If BalanceRowsArray.Count() = 0 Then
				Continue;
			EndIf;
			
			NewRow = ThisObject[TabularSectionName].Add();
			FillPropertyValues(NewRow, SelectionProducts);
			
			QuantityToWriteOff = SelectionProducts.Quantity * SelectionProducts.Factor;
			BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityToWriteOff;
			If BalanceRowsArray[0].QuantityBalance < 0 Then
				
				NewRow.Quantity = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / SelectionProducts.Factor;
				
			EndIf;
			
			If BalanceRowsArray[0].QuantityBalance <= 0 Then
				BalanceTable.Delete(BalanceRowsArray[0]);
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If Products.Count() > 0 Then
		Selection = ResultsArray[2].Select();
		While Selection.Next() Do
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
	ElsIf Inventory.Count() > 0 Then
		Selection = ResultsArray[2].Select();
		While Selection.Next() Do
			NewRow = Products.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
	EndIf;
	
	// Fill out according to specification.
	If Products.Count() > 0 AND FillingData.Inventory.Count() = 0 Then
		NodesSpecificationStack = New Array;
		FillTabularSectionBySpecification(NodesSpecificationStack);
	EndIf;
	
	// Filling out reserves.
	If TabularSectionName = "Products" AND Inventory.Count() > 0
		AND Constants.FunctionalOptionInventoryReservation.Get()
		AND ValueIsFilled(InventoryStructuralUnit) Then
		FillColumnReserveByReserves();
	EndIf;
	
EndProcedure // FillByProductionOrder()

// Procedure for filling the document basing on Customer order.
//
Procedure FillUsingCustomerOrder(FillingData) Export
	
	If OperationKind = Enums.OperationKindsInventoryAssembly.Disassembly Then
		TabularSectionName = "Inventory";
	Else
		TabularSectionName = "Products";
	EndIf;
	
	Query = New Query( 
	"SELECT
	|	CustomerOrderInventory.Ref AS CustomerOrder,
	|	DATEADD(CustomerOrderInventory.ShipmentDate, Day, -CustomerOrderInventory.ProductsAndServices.ReplenishmentDeadline) AS Start,
	|	CustomerOrderInventory.ShipmentDate AS Finish,
	|	CustomerOrderInventory.Ref.Company AS Company,
	|	CustomerOrderInventory.Ref.SalesStructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN CustomerOrderInventory.Ref.SalesStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|				OR CustomerOrderInventory.Ref.SalesStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division)
	|			THEN CustomerOrderInventory.Ref.SalesStructuralUnit.TransferRecipient
	|		ELSE VALUE(Catalog.StructuralUnits.EmptyRef)
	|	END AS ProductsStructuralUnit,
	|	CASE
	|		WHEN CustomerOrderInventory.Ref.SalesStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|				OR CustomerOrderInventory.Ref.SalesStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division)
	|			THEN CustomerOrderInventory.Ref.SalesStructuralUnit.TransferRecipientCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS ProductsCell,
	|	CASE
	|		WHEN CustomerOrderInventory.Ref.SalesStructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|				OR CustomerOrderInventory.Ref.SalesStructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division)
	|			THEN CustomerOrderInventory.Ref.SalesStructuralUnit.TransferSource
	|		ELSE VALUE(Catalog.StructuralUnits.EmptyRef)
	|	END AS InventoryStructuralUnit,
	|	CASE
	|		WHEN CustomerOrderInventory.Ref.SalesStructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|				OR CustomerOrderInventory.Ref.SalesStructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division)
	|			THEN CustomerOrderInventory.Ref.SalesStructuralUnit.TransferSourceCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS CellInventory,
	|	CustomerOrderInventory.Ref.SalesStructuralUnit.RecipientOfWastes AS DisposalsStructuralUnit,
	|	CustomerOrderInventory.Ref.SalesStructuralUnit.DisposalsRecipientCell AS DisposalsCell,
	|	CustomerOrderInventory.ProductsAndServices AS ProductsAndServices,
	|	CustomerOrderInventory.ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
	|	CustomerOrderInventory.Characteristic AS Characteristic,
	|	CustomerOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	CustomerOrderInventory.Quantity AS Quantity,
	|	CustomerOrderInventory.Reserve AS Reserve,
	|	CustomerOrderInventory.Specification AS Specification
	|FROM
	|	Document.CustomerOrder.Inventory AS CustomerOrderInventory
	|WHERE
	|	CustomerOrderInventory.Ref = &BasisDocument");
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Products.Clear();
	Inventory.Clear();
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		QueryResultSelection = QueryResult.Select();
		QueryResultSelection.Next();
		FillPropertyValues(ThisObject, QueryResultSelection);
		
		If ValueIsFilled(StructuralUnit) Then
			
			If Not ValueIsFilled(ProductsStructuralUnit) Then
				ProductsStructuralUnit = StructuralUnit;
			EndIf;
			
			If Not ValueIsFilled(InventoryStructuralUnit) Then
				InventoryStructuralUnit = StructuralUnit;
			EndIf;
			
			If Not ValueIsFilled(DisposalsStructuralUnit) Then
				DisposalsStructuralUnit = StructuralUnit;
			EndIf;
			
		EndIf;
		
		QueryResultSelection.Reset();
		While QueryResultSelection.Next() Do
		
			If ValueIsFilled(QueryResultSelection.ProductsAndServices) Then
			
				If QueryResultSelection.ProductsAndServicesType <> Enums.ProductsAndServicesTypes.InventoryItem Then
					Continue;
				EndIf;
				
				NewRow = ThisObject[TabularSectionName].Add();
				FillPropertyValues(NewRow, QueryResultSelection);
				
				If Not ValueIsFilled(NewRow.Specification) Then
					NewRow.Specification = SmallBusinessServer.GetDefaultSpecification(NewRow.ProductsAndServices, NewRow.Characteristic);
				EndIf;
				
			EndIf;
		
		EndDo;
		
		If Products.Count() > 0 Then
			NodesSpecificationStack = New Array;
			FillTabularSectionBySpecification(NodesSpecificationStack);
		EndIf;
		
	EndIf;
	
EndProcedure // FillByCustomerOrder()

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.CustomerOrder") Then
		FillUsingCustomerOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ProductionOrder") Then
		FillByProductionOrder(FillingData);
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - BeforeWrite event handler.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	ProductsAndServicesList = "";
	FOUseCharacteristics = Constants.FunctionalOptionUseCharacteristics.Get();
	For Each StringProducts IN Products Do
		
		If Not ValueIsFilled(StringProducts.ProductsAndServices) Then
			Continue;
		EndIf;
		
		CharacteristicPresentation = "";
		If FOUseCharacteristics AND ValueIsFilled(StringProducts.Characteristic) Then
			CharacteristicPresentation = " (" + TrimAll(StringProducts.Characteristic) + ")";
		EndIf;
		
		If ValueIsFilled(ProductsAndServicesList) Then
			ProductsAndServicesList = ProductsAndServicesList + Chars.LF;
		EndIf;
		ProductsAndServicesList = ProductsAndServicesList + TrimAll(StringProducts.ProductsAndServices) + CharacteristicPresentation + ", " + StringProducts.Quantity + " " + TrimAll(StringProducts.MeasurementUnit);
		
	EndDo;
	
EndProcedure // BeforeWrite()

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Inventory.Total("Reserve") > 0 Then
		
		If Not ValueIsFilled(CustomerOrder) Then
			
			MessageText = NStr("en = 'Customer order is not specified - reserve source!'");
			SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText,,,"CustomerOrder",Cancel);
			
		EndIf;
		
	EndIf;
	
	If Constants.FunctionalOptionInventoryReservation.Get() Then
		
		If OperationKind = Enums.OperationKindsInventoryAssembly.Assembly Then
			
			For Each StringInventory IN Inventory Do
				
				If StringInventory.Reserve > StringInventory.Quantity Then
					
					MessageText = NStr("en = 'In row No.%Number% of the ""Inventory"" tabular section, the number of items for write-off from reserve exceeds the total inventory quantity.'");
					MessageText = StrReplace(MessageText, "%Number%", StringInventory.LineNumber);
					SmallBusinessServer.ShowMessageAboutError(
						ThisObject,
						MessageText,
						"Inventory",
						StringInventory.LineNumber,
						"Reserve",
						Cancel
					);
					
				EndIf;
				
			EndDo;
			
		Else
			
			For Each StringProducts IN Products Do
				
				If StringProducts.Reserve > StringProducts.Quantity Then
					
					MessageText = NStr("en = 'In row No.%Number% of the ""Products"" tabular section the number of items for write-off from reserve exceeds the total inventory quantity.'");
					MessageText = StrReplace(MessageText, "%Number%", StringProducts.LineNumber);
					SmallBusinessServer.ShowMessageAboutError(
						ThisObject,
						MessageText,
						"Products",
						StringProducts.LineNumber,
						"Reserve",
						Cancel
					);
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure // FillCheckProcessing()

// Procedure - event handler FillingProcessor object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.InventoryAssembly.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	SmallBusinessServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryForWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryForExpenseFromWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectProductRelease(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryAccepted(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectProductionOrders(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectOrdersPlacement(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.InventoryAssembly.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure // Posting()

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.InventoryAssembly.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure // UndoPosting()

#EndIf