#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF FILLING THE DOCUMENT

// Checks the possibility of input on the basis.
//
Procedure CheckInputBasedOnPossibility(FillingData, AttributeValues)
	
	If AttributeValues.Property("OperationKind") Then
		If ValueIsFilled(AttributeValues.OperationKind)
			AND Not FillingData.OperationKind = Enums.OperationKindsCustomerOrder.JobOrder Then
				ErrorMessage = NStr("en = 'Sales invoice receipt can be entered only on the basis of the job order!'");
				Raise ErrorMessage;
		EndIf;
	EndIf;
	
	Cancel = False;
	If AttributeValues.Property("StructuralUnit") Then
		If ValueIsFilled(AttributeValues.StructuralUnit)
			AND Not AttributeValues.StructuralUnit.OrderWarehouse Then
			Cancel = True;
		EndIf;
	ElsIf AttributeValues.Property("StructuralUnitReserve") Then
		If ValueIsFilled(AttributeValues.StructuralUnitReserve)
			AND Not AttributeValues.StructuralUnitReserve.OrderWarehouse Then
			Cancel = True;
		EndIf;
	EndIf;
	
	If Cancel Then
		ErrorMessage = NStr("en = 'The ""Expense from order warehouse"" operation can not be entered.
								|Document ""%DocumentRef"" has no order warehouse!'");
		ErrorMessage = StrReplace(ErrorMessage, "%DocumentRef", FillingData.Ref);
		Raise ErrorMessage;
	EndIf;
	
EndProcedure // CheckInputBasedOnPossibility()

// Procedure of document filling based on processing report.
//
Procedure FillByProcessingReport(FillingData)
	
	// Header filling.
	ThisObject.BasisDocument = FillingData;
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData, New Structure("Company, StructuralUnit, Cell"));
	
	CheckInputBasedOnPossibility(FillingData, AttributeValues);
	
	FillPropertyValues(ThisObject, AttributeValues);
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	MIN(ProcessingReport.LineNumber) AS LineNumber,
	|	ProcessingReport.ProductsAndServices AS ProductsAndServices,
	|	ProcessingReport.Characteristic AS Characteristic,
	|	ProcessingReport.Batch AS Batch,
	|	ProcessingReport.MeasurementUnit AS MeasurementUnit,
	|	SUM(ProcessingReport.Quantity) AS Quantity
	|FROM
	|	(SELECT
	|		ProcessingReportProducts.LineNumber AS LineNumber,
	|		ProcessingReportProducts.ProductsAndServices AS ProductsAndServices,
	|		ProcessingReportProducts.Characteristic AS Characteristic,
	|		ProcessingReportProducts.Batch AS Batch,
	|		ProcessingReportProducts.MeasurementUnit AS MeasurementUnit,
	|		ProcessingReportProducts.Quantity AS Quantity
	|	FROM
	|		Document.ProcessingReport.Products AS ProcessingReportProducts
	|	WHERE
	|		ProcessingReportProducts.Ref = &BasisDocument
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		ProcessingReportDisposals.LineNumber,
	|		ProcessingReportDisposals.ProductsAndServices,
	|		ProcessingReportDisposals.Characteristic,
	|		ProcessingReportDisposals.Batch,
	|		ProcessingReportDisposals.MeasurementUnit,
	|		ProcessingReportDisposals.Quantity
	|	FROM
	|		Document.ProcessingReport.Disposals AS ProcessingReportDisposals
	|	WHERE
	|		ProcessingReportDisposals.Ref = &BasisDocument) AS ProcessingReport
	|
	|GROUP BY
	|	ProcessingReport.ProductsAndServices,
	|	ProcessingReport.Characteristic,
	|	ProcessingReport.Batch,
	|	ProcessingReport.MeasurementUnit
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Inventory.Clear();
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		While Selection.Next() Do
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
	EndIf;
	
EndProcedure // FillByProcessingReport()

// Procedure of the document filling based on the customer invoice.
//
Procedure FillBySalesInvoice(FillingData)
	
	// Header filling.
	ThisObject.BasisDocument = FillingData;
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData, New Structure("Company, StructuralUnit, Cell"));
	
	CheckInputBasedOnPossibility(FillingData, AttributeValues);
	
	FillPropertyValues(ThisObject, AttributeValues);
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	MIN(CustomerInvoiceInventory.LineNumber) AS LineNumber,
	|	CustomerInvoiceInventory.ProductsAndServices AS ProductsAndServices,
	|	CustomerInvoiceInventory.Characteristic AS Characteristic,
	|	CustomerInvoiceInventory.Batch AS Batch,
	|	CustomerInvoiceInventory.MeasurementUnit AS MeasurementUnit,
	|	SUM(CustomerInvoiceInventory.Quantity) AS Quantity
	|FROM
	|	Document.CustomerInvoice.Inventory AS CustomerInvoiceInventory
	|WHERE
	|	CustomerInvoiceInventory.Ref = &BasisDocument
	|	AND CustomerInvoiceInventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|
	|GROUP BY
	|	CustomerInvoiceInventory.ProductsAndServices,
	|	CustomerInvoiceInventory.Characteristic,
	|	CustomerInvoiceInventory.Batch,
	|	CustomerInvoiceInventory.MeasurementUnit
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Inventory.Clear();
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		While Selection.Next() Do
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
	EndIf;
	
EndProcedure // FillBySalesInvoice()

// Procedure of document filling based on customer order.
//
Procedure FillByCustomerOrder(FillingData)
	
	// Header filling.
	ThisObject.BasisDocument = FillingData;
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData, New Structure("Company, OperationKind, StructuralUnitReserve, Cell"));
	
	CheckInputBasedOnPossibility(FillingData, AttributeValues);
	
	FillPropertyValues(ThisObject, AttributeValues);
	StructuralUnit = AttributeValues.StructuralUnitReserve;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	MIN(CustomerOrderInventory.LineNumber) AS LineNumber,
	|	CustomerOrderInventory.ProductsAndServices AS ProductsAndServices,
	|	CustomerOrderInventory.ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
	|	CustomerOrderInventory.Characteristic AS Characteristic,
	|	CustomerOrderInventory.Batch AS Batch,
	|	CustomerOrderInventory.MeasurementUnit AS MeasurementUnit,
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
	|	CustomerOrderInventory.Batch,
	|	CustomerOrderInventory.MeasurementUnit,
	|	CustomerOrderInventory.ProductsAndServices.ProductsAndServicesType
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Inventory.Clear();
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		While Selection.Next() Do
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
	EndIf;
	
EndProcedure // FillByCustomerOrder()

// Procedure of document filling based on inventory write off.
//
Procedure FillByInventoryWriteOff(FillingData)
	
	// Header filling.
	ThisObject.BasisDocument = FillingData;
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData, New Structure("Company, StructuralUnit, Cell"));
	
	CheckInputBasedOnPossibility(FillingData, AttributeValues);
	
	FillPropertyValues(ThisObject, AttributeValues);
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	MIN(InventoryWriteOffInventory.LineNumber) AS LineNumber,
	|	InventoryWriteOffInventory.ProductsAndServices AS ProductsAndServices,
	|	InventoryWriteOffInventory.Characteristic AS Characteristic,
	|	InventoryWriteOffInventory.Batch AS Batch,
	|	InventoryWriteOffInventory.MeasurementUnit AS MeasurementUnit,
	|	SUM(InventoryWriteOffInventory.Quantity) AS Quantity
	|FROM
	|	Document.InventoryWriteOff.Inventory AS InventoryWriteOffInventory
	|WHERE
	|	InventoryWriteOffInventory.Ref = &BasisDocument
	|
	|GROUP BY
	|	InventoryWriteOffInventory.ProductsAndServices,
	|	InventoryWriteOffInventory.Characteristic,
	|	InventoryWriteOffInventory.Batch,
	|	InventoryWriteOffInventory.MeasurementUnit
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Inventory.Clear();
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		While Selection.Next() Do
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
	EndIf;
	
EndProcedure // FillByInventoryWriteOff()

// Procedure of document filling based on inventory transfer.
//
Procedure FillByInventoryTransfer(FillingData)
	
	// Header filling.
	ThisObject.BasisDocument = FillingData;
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData, New Structure("Company, StructuralUnit, Cell"));
	
	CheckInputBasedOnPossibility(FillingData, AttributeValues);
	
	FillPropertyValues(ThisObject, AttributeValues);
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	MIN(InventoryTransferInventory.LineNumber) AS LineNumber,
	|	InventoryTransferInventory.ProductsAndServices AS ProductsAndServices,
	|	InventoryTransferInventory.Characteristic AS Characteristic,
	|	InventoryTransferInventory.Batch AS Batch,
	|	InventoryTransferInventory.MeasurementUnit AS MeasurementUnit,
	|	SUM(InventoryTransferInventory.Quantity) AS Quantity
	|FROM
	|	Document.InventoryTransfer.Inventory AS InventoryTransferInventory
	|WHERE
	|	InventoryTransferInventory.Ref = &BasisDocument
	|
	|GROUP BY
	|	InventoryTransferInventory.ProductsAndServices,
	|	InventoryTransferInventory.Characteristic,
	|	InventoryTransferInventory.Batch,
	|	InventoryTransferInventory.MeasurementUnit
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Inventory.Clear();
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		While Selection.Next() Do
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
	EndIf;
	
EndProcedure // FillByInventoryTransfer()

// Procedure of document filling on the basis of the goods receipt.
//
Procedure FillByGoodsReceipt(FillingData)
	
	// Header filling.
	ThisObject.BasisDocument = FillingData;
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData, New Structure("Company, StructuralUnit, Cell"));
	
	CheckInputBasedOnPossibility(FillingData, AttributeValues);
	
	FillPropertyValues(ThisObject, AttributeValues);
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	MIN(GoodsReceiptInventory.LineNumber) AS LineNumber,
	|	GoodsReceiptInventory.ProductsAndServices AS ProductsAndServices,
	|	GoodsReceiptInventory.Characteristic AS Characteristic,
	|	GoodsReceiptInventory.Batch AS Batch,
	|	GoodsReceiptInventory.MeasurementUnit AS MeasurementUnit,
	|	SUM(GoodsReceiptInventory.Quantity) AS Quantity
	|FROM
	|	Document.GoodsReceipt.Inventory AS GoodsReceiptInventory
	|WHERE
	|	GoodsReceiptInventory.Ref = &BasisDocument
	|
	|GROUP BY
	|	GoodsReceiptInventory.ProductsAndServices,
	|	GoodsReceiptInventory.Characteristic,
	|	GoodsReceiptInventory.Batch,
	|	GoodsReceiptInventory.MeasurementUnit
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Inventory.Clear();
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		While Selection.Next() Do
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
	EndIf;
	
EndProcedure // FillByGoodsReceipt()

// Procedure of document filling based on fixed assets enter.
//
Procedure FillByFixedAssetsEnter(FillingData)
	
	// Header filling.
	ThisObject.BasisDocument = FillingData;
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData, New Structure("Company, StructuralUnit, Cell"));
	
	CheckInputBasedOnPossibility(FillingData, AttributeValues);
	
	FillPropertyValues(ThisObject, AttributeValues);
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	FixedAssetsEnter.ProductsAndServices AS ProductsAndServices,
	|	FixedAssetsEnter.Batch AS Batch,
	|	FixedAssetsEnter.MeasurementUnit AS MeasurementUnit,
	|	FixedAssetsEnter.Quantity AS Quantity
	|FROM
	|	Document.FixedAssetsEnter AS FixedAssetsEnter
	|WHERE
	|	FixedAssetsEnter.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Inventory.Clear();
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		While Selection.Next() Do
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
	EndIf;
	
EndProcedure // FillByFixedAssetsEnter()

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing) Export
		
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If TypeOf(FillingData) = Type("DocumentRef.ProcessingReport") Then
		FillByProcessingReport(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CustomerInvoice") Then
		FillBySalesInvoice(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CustomerOrder") Then
		FillByCustomerOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.InventoryWriteOff") Then
		FillByInventoryWriteOff(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.InventoryTransfer") Then
		FillByInventoryTransfer(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.GoodsReceipt") Then
		FillByGoodsReceipt(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.FixedAssetsEnter") Then
		FillByFixedAssetsEnter(FillingData);
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.GoodsExpense.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	SmallBusinessServer.ReflectInventoryForExpenseFromWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);

	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);

	// Control
	Documents.GoodsExpense.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

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
	Documents.GoodsExpense.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

#EndIf