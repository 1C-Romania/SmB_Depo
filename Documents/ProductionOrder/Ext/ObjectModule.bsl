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
				MessageText = NStr("en='During filling in of the Specification materials"
"tabular section a recursive item occurrence was found';ru='При попытке заполнить табличную"
"часть Материалы по спецификации, обнаружено рекурсивное вхождение элемента'")+" "+Selection.ProductsAndServices+" "+NStr("en='in specifications';ru='в спецификации'")+" "+Selection.ProductionSpecification+"
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
	Inventory.GroupBy("ProductsAndServices, Characteristic, MeasurementUnit, Specification", "Quantity, Reserve");
	
EndProcedure // FillTabularSectionBySpecification()

// Procedure fills the Quantity column by free balances at warehouse.
//
Procedure FillColumnReserveByBalances() Export
	
	Inventory.LoadColumn(New Array(Inventory.Count()), "Reserve");
	
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
	
	Query.SetParameter("TableInventory", Inventory.Unload());
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
	|						CASE
	|							WHEN &StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division)
	|								THEN TableInventory.ProductsAndServices.ExpensesGLAccount
	|							ELSE TableInventory.ProductsAndServices.InventoryGLAccount
	|						END,
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
	Query.SetParameter("StructuralUnitType", StructuralUnitReserve.StructuralUnitType);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("ProductsAndServices", Selection.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		
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
	
EndProcedure // FillColumnReserveByBalances()

// Procedure for filling the document basing on Production order.
//
Procedure FillByProductionOrder(FillingData) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ProductionOrder.Start AS Start,
	|	ProductionOrder.Start AS Finish,
	|	ProductionOrder.OperationKind AS OperationKind,
	|	ProductionOrder.Ref AS BasisDocument,
	|	CASE
	|		WHEN FunctionalOptionInventoryReservation.Value
	|			THEN ProductionOrder.CustomerOrder
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END AS CustomerOrder,
	|	ProductionOrder.Company AS Company,
	|	ProductionOrder.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN ProductionOrder.StructuralUnitReserve = VALUE(Catalog.StructuralUnits.EmptyRef)
	|				AND (ProductionOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|					OR ProductionOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division))
	|			THEN ProductionOrder.StructuralUnit.TransferSource
	|		ELSE ProductionOrder.StructuralUnitReserve
	|	END AS StructuralUnitReserve,
	|	ProductionOrder.Inventory.(
	|		ProductsAndServices AS ProductsAndServices,
	|		Characteristic AS Characteristic,
	|		MeasurementUnit AS MeasurementUnit,
	|		Quantity AS Quantity,
	|		Specification AS Specification,
	|		ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType
	|	)
	|FROM
	|	Document.ProductionOrder AS ProductionOrder,
	|	Constant.FunctionalOptionInventoryReservation AS FunctionalOptionInventoryReservation
	|WHERE
	|	ProductionOrder.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Products.Clear();
	Inventory.Clear();
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		QueryResultSelection = QueryResult.Select();
		QueryResultSelection.Next();
		FillPropertyValues(ThisObject, QueryResultSelection);
		
		For Each StringInventory IN QueryResultSelection.Inventory.Unload() Do
			If ValueIsFilled(StringInventory.ProductsAndServices) Then
				NewRow = Products.Add();
				FillPropertyValues(NewRow, StringInventory);
			EndIf;
		EndDo;
		
		If Products.Count() > 0 Then
			NodesSpecificationStack = New Array;
			FillTabularSectionBySpecification(NodesSpecificationStack);
		EndIf;
		
	EndIf;
	
EndProcedure // FillByProductionOrder()

// Procedure for filling the document basing on Customer order.
//
Procedure FillUsingCustomerOrder(FillingData) Export
	
	If OperationKind = Enums.OperationKindsProductionOrder.Disassembly Then
		TabularSectionName = "Inventory";
	Else
		TabularSectionName = "Products";
	EndIf;
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT
	|	CustomerOrder.Ref AS BasisRef,
	|	CustomerOrder.Posted AS BasisPosted,
	|	CustomerOrder.Closed AS BasisClosed,
	|	CustomerOrder.OrderState AS BasisState,
	|	CustomerOrder.OperationKind AS BasisOperationKind,
	|	CASE
	|		WHEN FunctionalOptionInventoryReservation.Value
	|			THEN CustomerOrder.Ref
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END AS CustomerOrder,
	|	CustomerOrder.Company AS Company,
	|	CASE
	|		WHEN CustomerOrder.SalesStructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division)
	|			THEN CustomerOrder.SalesStructuralUnit
	|		ELSE VALUE(Catalog.StructuralUnits.EmptyRef)
	|	END AS StructuralUnit,
	|	CASE
	|		WHEN CustomerOrder.SalesStructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division)
	|				AND CustomerOrder.StructuralUnitReserve = VALUE(Catalog.StructuralUnits.EmptyRef)
	|				AND (CustomerOrder.SalesStructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Warehouse)
	|					OR CustomerOrder.SalesStructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Division))
	|			THEN CustomerOrder.SalesStructuralUnit.TransferSource
	|		ELSE CustomerOrder.StructuralUnitReserve
	|	END AS StructuralUnitReserve,
	|	CASE
	|		WHEN CustomerOrder.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
	|			THEN CustomerOrder.Start
	|		ELSE BEGINOFPERIOD(CustomerOrder.ShipmentDate, Day)
	|	END AS Start,
	|	CASE
	|		WHEN CustomerOrder.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
	|			THEN CustomerOrder.Finish
	|		ELSE ENDOFPERIOD(CustomerOrder.ShipmentDate, Day)
	|	END AS Finish
	|FROM
	|	Document.CustomerOrder AS CustomerOrder,
	|	Constant.FunctionalOptionInventoryReservation AS FunctionalOptionInventoryReservation
	|WHERE
	|	CustomerOrder.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		VerifiedAttributesValues = New Structure("OperationKind, OrderStatus, Closed, Posted", Selection.BasisOperationKind, Selection.BasisState, Selection.BasisClosed, Selection.BasisPosted);
		Documents.CustomerOrder.CheckAbilityOfEnteringByCustomerOrder(Selection.BasisRef, VerifiedAttributesValues);
	EndIf;
	
	FillPropertyValues(ThisObject, Selection);
	
	If Not ValueIsFilled(StructuralUnit) Then
		SettingValue = SmallBusinessReUse.GetValueOfSetting("MainDivision");
		If Not ValueIsFilled(SettingValue) Then
			StructuralUnit = Catalogs.StructuralUnits.MainDivision;
		EndIf;
	EndIf;
	
	BasisOperationKind = Selection.BasisOperationKind;
	
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
	|		AccumulationRegister.CustomerOrders.Balance(, CustomerOrder = &BasisDocument) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InventoryBalances.ProductsAndServices,
	|		InventoryBalances.Characteristic,
	|		-InventoryBalances.QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(, CustomerOrder = &BasisDocument) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		PlacementBalances.ProductsAndServices,
	|		PlacementBalances.Characteristic,
	|		-PlacementBalances.QuantityBalance
	|	FROM
	|		AccumulationRegister.OrdersPlacement.Balance(, CustomerOrder = &BasisDocument) AS PlacementBalances
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
	|	CustomerOrderInventory.Specification AS Specification,
	|	CustomerOrderInventory.ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
	|	SUM(CustomerOrderInventory.Quantity) AS Quantity
	|FROM
	|	Document.CustomerOrder.Inventory AS CustomerOrderInventory
	|WHERE
	|	CustomerOrderInventory.Ref = &BasisDocument
	|
	|GROUP BY
	|	CustomerOrderInventory.ProductsAndServices,
	|	CustomerOrderInventory.Characteristic,
	|	CustomerOrderInventory.MeasurementUnit,
	|	CustomerOrderInventory.ProductsAndServices.ProductsAndServicesType,
	|	CASE
	|		WHEN VALUETYPE(CustomerOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE CustomerOrderInventory.MeasurementUnit.Factor
	|	END,
	|	CustomerOrderInventory.Specification
	|
	|ORDER BY
	|	LineNumber";
	
	If BasisOperationKind = Enums.OperationKindsCustomerOrder.JobOrder Then
		
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
		|	CustomerOrderMaterials.ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
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
		|	CustomerOrderMaterials.ProductsAndServices.ProductsAndServicesType,
		|	CASE
		|		WHEN VALUETYPE(CustomerOrderMaterials.MeasurementUnit) = Type(Catalog.UOMClassifier)
		|			THEN 1
		|		ELSE CustomerOrderMaterials.MeasurementUnit.Factor
		|	END
		|
		|ORDER BY
		|	LineNumber";
		
	EndIf;
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("ProductsAndServices,Characteristic");
	
	Products.Clear();
	Inventory.Clear();
	If BalanceTable.Count() > 0 Then
		
		Selection = ResultsArray[1].Select();
		While Selection.Next() Do
			
			If TabularSectionName = "Inventory"
				AND Selection.ProductsAndServicesType <> Enums.ProductsAndServicesTypes.InventoryItem Then
				Continue;
			EndIf;
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("ProductsAndServices", Selection.ProductsAndServices);
			StructureForSearch.Insert("Characteristic", Selection.Characteristic);
			
			BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
			If BalanceRowsArray.Count() = 0 Then
				Continue;
			EndIf;
			
			NewRow = ThisObject[TabularSectionName].Add();
			FillPropertyValues(NewRow, Selection);
			
			If Not ValueIsFilled(NewRow.Specification) Then
				NewRow.Specification = SmallBusinessServer.GetDefaultSpecification(NewRow.ProductsAndServices, NewRow.Characteristic);
			EndIf;
			
			QuantityToWriteOff = Selection.Quantity * Selection.Factor;
			BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityToWriteOff;
			If BalanceRowsArray[0].QuantityBalance < 0 Then
				
				NewRow.Quantity = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / Selection.Factor;
				
			EndIf;
			
			If BalanceRowsArray[0].QuantityBalance <= 0 Then
				BalanceTable.Delete(BalanceRowsArray[0]);
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If BasisOperationKind = Enums.OperationKindsCustomerOrder.JobOrder Then
		
		ResultsArray = Query.ExecuteBatch();
		BalanceTable = ResultsArray[2].Unload();
		BalanceTable.Indexes.Add("ProductsAndServices,Characteristic");
		
		Selection = ResultsArray[3].Select();
		While Selection.Next() Do
			
			If TabularSectionName = "Inventory"
				AND Selection.ProductsAndServicesType <> Enums.ProductsAndServicesTypes.InventoryItem Then
				Continue;
			EndIf;
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("ProductsAndServices", Selection.ProductsAndServices);
			StructureForSearch.Insert("Characteristic", Selection.Characteristic);
			
			BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
			If BalanceRowsArray.Count() = 0 Then
				
				NewRow = ThisObject[TabularSectionName].Add();
				FillPropertyValues(NewRow, Selection);
				
				NewRow.Specification = SmallBusinessServer.GetDefaultSpecification(NewRow.ProductsAndServices, NewRow.Characteristic);
				
			ElsIf (BalanceRowsArray[0].QuantityBalance / Selection.Factor) = Selection.Quantity Then
				
				Continue;
				
			ElsIf (BalanceRowsArray[0].QuantityBalance / Selection.Factor) > Selection.Quantity Then
				
				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - Selection.Quantity * Selection.Factor;
				Continue;
				
			ElsIf (BalanceRowsArray[0].QuantityBalance / Selection.Factor) < Selection.Quantity Then
				
				QuantityToWriteOff = -1 * (BalanceRowsArray[0].QuantityBalance / Selection.Factor - Selection.Quantity);
				BalanceRowsArray[0].QuantityBalance = 0;
				
				NewRow = ThisObject[TabularSectionName].Add();
				FillPropertyValues(NewRow, Selection);
				
				NewRow.Quantity = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / Selection.Factor;
				
				NewRow.Specification = SmallBusinessServer.GetDefaultSpecification(NewRow.ProductsAndServices, NewRow.Characteristic);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If Products.Count() > 0 Then
		NodesSpecificationStack = New Array;
		FillTabularSectionBySpecification(NodesSpecificationStack);
	EndIf;
	
EndProcedure // FillByCustomerOrder()

// Procedure fills document when copying.
//
Procedure FillOnCopy()
	
	If Constants.UseProductionOrderStates.Get() Then
		User = Users.CurrentUser();
		SettingValue = SmallBusinessReUse.GetValueByDefaultUser(User, "StatusOfNewProductionOrder");
		If ValueIsFilled(SettingValue) Then
			If OrderState <> SettingValue Then
				OrderState = SettingValue;
			EndIf;
		Else
			OrderState = Catalogs.ProductionOrderStates.Open;
		EndIf;
	Else
		OrderState = Constants.ProductionOrdersInProgressStatus.Get();
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
	
	If TypeOf(FillingData) = Type("Structure")
		AND FillingData.Property("DemandPlanning") Then
		NodesSpecificationStack = New Array;
		FillTabularSectionBySpecification(NodesSpecificationStack);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CustomerOrder") Then
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
	
	ResourcesList = "";
	For Each RowResource IN EnterpriseResources Do
		ResourcesList = ResourcesList + ?(ResourcesList = "","","; " + Chars.LF) + TrimAll(RowResource.EnterpriseResource);
	EndDo;
	
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
	
	If (Inventory.Total("Reserve") > 0 OR Products.Total("Reserve") > 0)
		AND Not ValueIsFilled(StructuralUnitReserve) Then
		
		MessageText = NStr("en='Reserve warehouse is not specified!';ru='Не указан склад резерва!'");
		SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText,,, "StructuralUnitReserve", Cancel);
		
	EndIf;
	
	If Constants.FunctionalOptionInventoryReservation.Get() Then
		
		If OperationKind = Enums.OperationKindsProductionOrder.Assembly Then
			
			For Each StringInventory IN Inventory Do
				
				If StringInventory.Reserve > StringInventory.Quantity Then
					
					MessageText = NStr("en='In string No.%Number% of tablular section ""Materials"" quantity of reserved positions exceeds the total materials.';ru='В строке №%Номер% табл. части ""Материалы"" количество резервируемых позиций превышает общее количество материалов.'");
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
					
					MessageText = NStr("en='In string No.%Number% of tabular section ""Products"" quantity of the reserved positions exceeds the total products.';ru='В строке №%Номер% табл. части ""Материалы"" количество резервируемых позиций превышает общее количество материалов.'");
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
	
	If Inventory.Count() > 0 Then
		
		FilterStructure = New Structure("ProductsAndServicesType", Enums.ProductsAndServicesTypes.Service);
		ArrayOfStringsServices = Products.FindRows(FilterStructure);
		If Products.Count() = ArrayOfStringsServices.Count() Then
			
			MessageText = NStr("en='Demand for materials is not planned for services!"
"Services only are indicated in the tabular section ""Products"". It is necessary to clear the tabular section ""Materials"".';ru='Планирование потребностей в материалах не выполняется для услуг!"
"В табличной части ""Продукция"" указаны только услуги. Необходимо очистить табличную часть ""Материалы"".'");
			SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText,,,, Cancel);
			
		EndIf;
		
	EndIf;
	
	If Not Constants.UseProductionOrderStates.Get() Then
		
		If Not ValueIsFilled(OrderState) Then
			MessageText = NStr("en='Field ""Order state"" is not filled. IN the accounting parameters settings it is necessary to install the statuses values.';ru='Поле ""Состояние заказа"" не заполнено. В настройках параметров учета необходимо установить значения состояний.'");
			SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText, , , "OrderState", Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure // FillCheckProcessing()

// Procedure - event handler FillingProcessor object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.ProductionOrder.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	SmallBusinessServer.ReflectInventoryTransferSchedule(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectProductionOrders(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectOrdersPlacement(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectProductRelease(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.ProductionOrder.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	Documents.ProductionOrder.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure // UndoPosting()

#EndIf