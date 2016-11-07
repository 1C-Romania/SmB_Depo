#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF FILLING THE DOCUMENT

// Procedure of document filling based on customer order.
//
// Parameters:
//  BasisDocument - DocumentRef.SupplierInvoice - supplier invoice 
//  FillingData - Structure - Document filling data
//	
Procedure FillByCustomerOrderNewPlace(FillingData)
	
	// Header filling.
	CustomerOrder = FillingData;
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData, New Structure("Company, OperationKind, OrderState, Closed, Posted"));
	
	Documents.CustomerOrder.CheckAbilityOfEnteringByCustomerOrder(FillingData, AttributeValues);
	Company = AttributeValues.Company;
	
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
	|		DocumentRegisterRecordsInventory.ProductsAndServices,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.CustomerOrder = &BasisDocument
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
	|	SUM(OrdersBalance.QuantityBalance) > 0";
	
	If AttributeValues.OperationKind = Enums.OperationKindsCustomerOrder.JobOrder Then
		
		Query.Text = Query.Text + "; " +
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
		|		AccumulationRegister.InventoryDemand.Balance(
		|				,
		|				CustomerOrder = &BasisDocument
		|					AND MovementType = VALUE(Enum.InventoryMovementTypes.Shipment)) AS OrdersBalance
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
		|		DocumentRegisterRecordsInventory.ProductsAndServices,
		|		DocumentRegisterRecordsInventory.Characteristic,
		|		CASE
		|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
		|				THEN -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
		|			ELSE ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
		|		END
		|	FROM
		|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
		|	WHERE
		|		DocumentRegisterRecordsInventory.Recorder = &Ref
		|		AND DocumentRegisterRecordsInventory.CustomerOrder = &BasisDocument
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
		|	SUM(OrdersBalance.QuantityBalance) > 0";
		
	EndIf;
	
	Query.Text = Query.Text + "; " +
	"SELECT
	|	CustomerOrder.Inventory.(
	|		ProductsAndServices AS ProductsAndServices,
	|		ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
	|		Characteristic AS Characteristic,
	|		Batch AS Batch,
	|		MeasurementUnit AS MeasurementUnit,
	|		CASE
	|			WHEN VALUETYPE(CustomerOrder.Inventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN 1
	|			ELSE CustomerOrder.Inventory.MeasurementUnit.Factor
	|		END AS Factor,
	|		Quantity AS Quantity,
	|		StructuralUnitReserve AS NewReservePlace
	|	),
	|	CustomerOrder.Materials.(
	|		ProductsAndServices AS ProductsAndServices,
	|		ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
	|		Characteristic AS Characteristic,
	|		Batch AS Batch,
	|		MeasurementUnit AS MeasurementUnit,
	|		CASE
	|			WHEN VALUETYPE(CustomerOrder.Materials.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN 1
	|			ELSE CustomerOrder.Materials.MeasurementUnit.Factor
	|		END AS Factor,
	|		Quantity AS Quantity,
	|		StructuralUnitReserve AS NewReservePlace
	|	)
	|FROM
	|	Document.CustomerOrder AS CustomerOrder
	|WHERE
	|	CustomerOrder.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("ProductsAndServices,Characteristic");
	
	Inventory.Clear();
	If AttributeValues.OperationKind = Enums.OperationKindsCustomerOrder.JobOrder Then
		
		Selection = ResultsArray[2].Select();
		Selection.Next();
		If BalanceTable.Count() > 0 Then
			FillInventoryByCustomerOrderNewPlace(Selection, BalanceTable, "Inventory");
		EndIf;
		
		BalanceTable = ResultsArray[1].Unload();
		BalanceTable.Indexes.Add("ProductsAndServices,Characteristic");
		If BalanceTable.Count() > 0 Then
			FillInventoryByCustomerOrderNewPlace(Selection, BalanceTable, "Materials");
		EndIf;
		
	Else
		
		Selection = ResultsArray[1].Select();
		Selection.Next();
		If BalanceTable.Count() > 0 Then
			FillInventoryByCustomerOrderNewPlace(Selection, BalanceTable, "Inventory");
		EndIf;
		
	EndIf;
	
EndProcedure // FillByCustomerOrderNewPlace()

// Procedure of document filling based on customer order.
//
// Parameters:
//  BasisDocument - DocumentRef.SupplierInvoice - supplier invoice 
//  FillingData - Structure - Document filling data
//	
Procedure FillByCustomerOrderOriginalPlace(FillingData)
	
	// Header filling.
	CustomerOrder = FillingData;
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData, New Structure("Company, OrderState, Closed, Posted"));
	
	Documents.CustomerOrder.CheckAbilityOfEnteringByCustomerOrder(FillingData, AttributeValues);
	Company = AttributeValues.Company;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	OrdersBalance.OriginalPlace AS OriginalReservePlace,
	|	OrdersBalance.ProductsAndServices AS ProductsAndServices,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	OrdersBalance.Batch AS Batch,
	|	OrdersBalance.MeasurementUnit AS MeasurementUnit,
	|	SUM(OrdersBalance.QuantityBalance) AS Quantity
	|FROM
	|	(SELECT
	|		InventoryBalances.StructuralUnit AS OriginalPlace,
	|		InventoryBalances.ProductsAndServices AS ProductsAndServices,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.ProductsAndServices.MeasurementUnit AS MeasurementUnit,
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
	|		PlacementBalances.SupplySource,
	|		PlacementBalances.ProductsAndServices,
	|		PlacementBalances.Characteristic,
	|		VALUE(Catalog.ProductsAndServicesBatches.EmptyRef),
	|		PlacementBalances.ProductsAndServices.MeasurementUnit,
	|		PlacementBalances.QuantityBalance
	|	FROM
	|		AccumulationRegister.OrdersPlacement.Balance(
	|				,
	|				CustomerOrder = &BasisDocument
	|					AND ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)) AS PlacementBalances) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.OriginalPlace,
	|	OrdersBalance.ProductsAndServices,
	|	OrdersBalance.Characteristic,
	|	OrdersBalance.Batch,
	|	OrdersBalance.MeasurementUnit
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CustomerOrder.OperationKind AS OperationKind,
	|	CustomerOrder.Inventory.(
	|		ProductsAndServices AS ProductsAndServices,
	|		ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
	|		Characteristic AS Characteristic,
	|		Batch AS Batch,
	|		MeasurementUnit AS MeasurementUnit,
	|		CASE
	|			WHEN VALUETYPE(CustomerOrder.Inventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN 1
	|			ELSE CustomerOrder.Inventory.MeasurementUnit.Factor
	|		END AS Factor
	|	),
	|	CustomerOrder.Materials.(
	|		ProductsAndServices AS ProductsAndServices,
	|		ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
	|		Characteristic AS Characteristic,
	|		Batch AS Batch,
	|		MeasurementUnit AS MeasurementUnit,
	|		CASE
	|			WHEN VALUETYPE(CustomerOrder.Materials.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN 1
	|			ELSE CustomerOrder.Materials.MeasurementUnit.Factor
	|		END AS Factor
	|	)
	|FROM
	|	Document.CustomerOrder AS CustomerOrder
	|WHERE
	|	CustomerOrder.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("ProductsAndServices,Characteristic");
	
	Inventory.Clear();
	Selection = ResultsArray[1].Select();
	Selection.Next();
	If BalanceTable.Count() > 0 Then
		FillInventoryByCustomerOrderOriginalPlace(Selection, BalanceTable, "Inventory");
		If Selection.OperationKind = Enums.OperationKindsCustomerOrder.JobOrder Then
			FillInventoryByCustomerOrderOriginalPlace(Selection, BalanceTable, "Materials");
		EndIf;
		For Each RowBalances IN BalanceTable Do
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, RowBalances);
			NewRow.MeasurementUnit = RowBalances.MeasurementUnit;
		EndDo;
	EndIf;
	
EndProcedure // FillByCustomerOrderOriginalPlace()

// Procedure for filling the row of the "Inventory based on customer order" tabular section.
//
Procedure FillInventoryByCustomerOrderNewPlace(Selection, BalanceTable, TabularSectionName)
	
	For Each TSRow IN Selection[TabularSectionName].Unload() Do
		
		If TSRow.ProductsAndServicesType <> Enums.ProductsAndServicesTypes.InventoryItem Then
			Continue;
		EndIf;
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("ProductsAndServices", TSRow.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", TSRow.Characteristic);
		
		BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
		If BalanceRowsArray.Count() = 0 Then
			Continue;
		EndIf;
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, TSRow);
		
		QuantityToWriteOff = TSRow.Quantity * TSRow.Factor;
		BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityToWriteOff;
		If BalanceRowsArray[0].QuantityBalance < 0 Then
			
			NewRow.Quantity = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / TSRow.Factor;
			
		EndIf;
		
		If BalanceRowsArray[0].QuantityBalance <= 0 Then
			BalanceTable.Delete(BalanceRowsArray[0]);
		EndIf;
		
	EndDo;
	
EndProcedure // FillInventoryByCustomerOrderNewPlace()

// Procedure for filling the row of the "Inventory based on customer order" tabular section.
//
Procedure FillInventoryByCustomerOrderOriginalPlace(Selection, BalanceTable, TabularSectionName)
	
	For Each TSRow IN Selection[TabularSectionName].Unload() Do
		
		If TSRow.ProductsAndServicesType <> Enums.ProductsAndServicesTypes.InventoryItem Then
			Continue;
		EndIf;
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("ProductsAndServices", TSRow.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", TSRow.Characteristic);
		
		BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
		For Each RowBalances IN BalanceRowsArray Do
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, RowBalances);
			NewRow.Quantity = RowBalances.Quantity / TSRow.Factor;
			NewRow.MeasurementUnit = TSRow.MeasurementUnit;
			BalanceTable.Delete(RowBalances);
		EndDo;
		
	EndDo;
	
EndProcedure // FillInventoryByCustomerOrderOriginalPlace()

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If TypeOf(FillingData) = Type("DocumentRef.CustomerOrder") Then
		
		FillByCustomerOrderNewPlace(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("Structure")
		AND TypeOf(FillingData.FillDocument) = Type("DocumentRef.CustomerOrder")
		AND FillingData.RemoveReser Then
		
		FillByCustomerOrderOriginalPlace(FillingData.FillDocument);
		
	EndIf;
	
EndProcedure

// IN handler of document event FillCheckProcessing,
// checked attributes are being copied and reset
// to exclude a standard platform fill check and subsequent check by embedded language tools.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)

	For Each InventoryTableRow IN Inventory Do
		
		If Not ValueIsFilled(InventoryTableRow.OriginalReservePlace)
		   AND Not ValueIsFilled(InventoryTableRow.NewReservePlace) Then
		   
		   SmallBusinessServer.ShowMessageAboutError(ThisObject, 
		   "Initial place of reserve is not specified.",
		   "Inventory",
		   InventoryTableRow.LineNumber,
		   "OriginalReservePlace",
		   Cancel);
		   
		   SmallBusinessServer.ShowMessageAboutError(ThisObject, 
		   "New place of reserve is not specified.",
		   "Inventory",
		   InventoryTableRow.LineNumber,
		   "NewReservePlace",
		   Cancel);
		   
		EndIf;
		
	EndDo;	
	
EndProcedure // FillCheckProcessing()

// The event handler PostingProcessor of a document includes:
// - deletion of document register records,
// - header structure of required attribute document is formed,
// - temporary table is formed by tabular section Products,
// - product receipt in storage places,
// - free balances receipt of products in storage places,
// - product cost receipt in storage places,
// - document posting creation.
//
Procedure Posting(Cancel, PostingMode)
	
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.InventoryReservation.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	SmallBusinessServer.ReflectOrdersPlacement(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);

	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);

	// Control
	Documents.InventoryReservation.RunControl(Ref, AdditionalProperties, Cancel);

	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure // Posting()

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.InventoryReservation.RunControl(Ref, AdditionalProperties, Cancel, True);

EndProcedure

#EndIf
