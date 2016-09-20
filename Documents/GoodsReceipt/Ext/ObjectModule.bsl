#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF FILLING THE DOCUMENT

// Checks the possibility of input on the basis.
//
Procedure CheckInputBasedOnPossibility(FillingData, AttributeValues)
	
	Cancel = False;
	If AttributeValues.Property("StructuralUnit") Then
		If ValueIsFilled(AttributeValues.StructuralUnit)
			AND Not AttributeValues.StructuralUnit.OrderWarehouse Then
			Cancel = True;
		EndIf;
	ElsIf AttributeValues.Property("StructuralUnitPayee") Then
		If ValueIsFilled(AttributeValues.StructuralUnitPayee)
			AND Not AttributeValues.StructuralUnitPayee.OrderWarehouse Then
			Cancel = True;
		EndIf;
	EndIf;
	
	If Cancel Then
		ErrorMessage = NStr("en='You can not enter the ""Receipt to order warehouse"" operation.
		|Document ""%DocumentRef"" has no order warehouse!';ru='Невозможен ввод операции ""Поступления на ордерный склад"".
		|Документ ""%ДокументСсылка"" не имеет ордерного склада!'");
		ErrorMessage = StrReplace(ErrorMessage, "%DocumentRef", FillingData.Ref);
		Raise ErrorMessage;
	EndIf;
	
EndProcedure // CheckInputBasedOnPossibility()

// Procedure of document filling based on goods expense.
//
Procedure FillByGoodsExpense(FillingData)
	
	// Header filling.
	ThisObject.BasisDocument = FillingData;
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData, New Structure("Company, StructuralUnit, Cell"));
	
	FillPropertyValues(ThisObject, AttributeValues);
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	MIN(GoodsExpenseInventory.LineNumber) AS LineNumber,
	|	GoodsExpenseInventory.ProductsAndServices AS ProductsAndServices,
	|	GoodsExpenseInventory.Characteristic AS Characteristic,
	|	GoodsExpenseInventory.Batch AS Batch,
	|	GoodsExpenseInventory.MeasurementUnit AS MeasurementUnit,
	|	SUM(GoodsExpenseInventory.Quantity) AS Quantity
	|FROM
	|	Document.GoodsExpense.Inventory AS GoodsExpenseInventory
	|WHERE
	|	GoodsExpenseInventory.Ref = &BasisDocument
	|
	|GROUP BY
	|	GoodsExpenseInventory.ProductsAndServices,
	|	GoodsExpenseInventory.Characteristic,
	|	GoodsExpenseInventory.Batch,
	|	GoodsExpenseInventory.MeasurementUnit
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
	
EndProcedure // FillByInvoiceForPayment()

// Procedure of filling the document on the basis of the supplier invoice.
//
Procedure FillByPurchaseInvoice(FillingData)
	
	// Header filling.
	ThisObject.BasisDocument = FillingData;
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData, New Structure("Company, StructuralUnit, Cell"));
	
	CheckInputBasedOnPossibility(FillingData, AttributeValues);
	
	FillPropertyValues(ThisObject, AttributeValues);
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	MIN(SupplierInvoiceInventory.LineNumber) AS LineNumber,
	|	SupplierInvoiceInventory.ProductsAndServices AS ProductsAndServices,
	|	SupplierInvoiceInventory.Characteristic AS Characteristic,
	|	SupplierInvoiceInventory.Batch AS Batch,
	|	SupplierInvoiceInventory.MeasurementUnit AS MeasurementUnit,
	|	SUM(SupplierInvoiceInventory.Quantity) AS Quantity
	|FROM
	|	Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|WHERE
	|	SupplierInvoiceInventory.Ref = &BasisDocument
	|	AND SupplierInvoiceInventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|
	|GROUP BY
	|	SupplierInvoiceInventory.ProductsAndServices,
	|	SupplierInvoiceInventory.Characteristic,
	|	SupplierInvoiceInventory.Batch,
	|	SupplierInvoiceInventory.MeasurementUnit
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
	
EndProcedure // FillBySupplierInvoice()

// Procedure of document filling based on inventory receipt.
//
Procedure FillByInventoryReceipt(FillingData)
	
	// Header filling.
	ThisObject.BasisDocument = FillingData;
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData, New Structure("Company, StructuralUnit, Cell"));
	
	CheckInputBasedOnPossibility(FillingData, AttributeValues);
	
	FillPropertyValues(ThisObject, AttributeValues);
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	MIN(InventoryReceiptInventory.LineNumber) AS LineNumber,
	|	InventoryReceiptInventory.ProductsAndServices AS ProductsAndServices,
	|	InventoryReceiptInventory.Characteristic AS Characteristic,
	|	InventoryReceiptInventory.Batch AS Batch,
	|	InventoryReceiptInventory.MeasurementUnit AS MeasurementUnit,
	|	SUM(InventoryReceiptInventory.Quantity) AS Quantity
	|FROM
	|	Document.InventoryReceipt.Inventory AS InventoryReceiptInventory
	|WHERE
	|	InventoryReceiptInventory.Ref = &BasisDocument
	|
	|GROUP BY
	|	InventoryReceiptInventory.ProductsAndServices,
	|	InventoryReceiptInventory.Characteristic,
	|	InventoryReceiptInventory.Batch,
	|	InventoryReceiptInventory.MeasurementUnit
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
	
EndProcedure // FillByInventoryReceipt()

// Procedure of document filling based on inventory transfer.
//
Procedure FillByInventoryTransfer(FillingData)
	
	// Header filling.
	ThisObject.BasisDocument = FillingData;
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData, New Structure("Company, StructuralUnitPayee, Cell"));
	
	CheckInputBasedOnPossibility(FillingData, AttributeValues);
	
	FillPropertyValues(ThisObject, AttributeValues);
	StructuralUnit = AttributeValues.StructuralUnitPayee;
	
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

// Procedure of document filling based on subcontractor report.
//
Procedure FillBySubcontractorReport(FillingData)
	
	// Header filling.
	ThisObject.BasisDocument = FillingData;
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData, New Structure("Company, StructuralUnit, Cell"));
	
	CheckInputBasedOnPossibility(FillingData, AttributeValues);
	
	FillPropertyValues(ThisObject, AttributeValues);
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	MIN(SubcontractorReport.LineNumber) AS LineNumber,
	|	SubcontractorReport.ProductsAndServices AS ProductsAndServices,
	|	SubcontractorReport.Characteristic AS Characteristic,
	|	SubcontractorReport.Batch AS Batch,
	|	SubcontractorReport.MeasurementUnit AS MeasurementUnit,
	|	SUM(SubcontractorReport.Quantity) AS Quantity
	|FROM
	|	(SELECT
	|		0 AS LineNumber,
	|		SubcontractorReport.ProductsAndServices AS ProductsAndServices,
	|		SubcontractorReport.Characteristic AS Characteristic,
	|		SubcontractorReport.Batch AS Batch,
	|		SubcontractorReport.MeasurementUnit AS MeasurementUnit,
	|		SubcontractorReport.Quantity AS Quantity
	|	FROM
	|		Document.SubcontractorReport AS SubcontractorReport
	|	WHERE
	|		SubcontractorReport.Ref = &BasisDocument
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		SubcontractorReportDisposals.LineNumber,
	|		SubcontractorReportDisposals.ProductsAndServices,
	|		SubcontractorReportDisposals.Characteristic,
	|		SubcontractorReportDisposals.Batch,
	|		SubcontractorReportDisposals.MeasurementUnit,
	|		SubcontractorReportDisposals.Quantity
	|	FROM
	|		Document.SubcontractorReport.Disposals AS SubcontractorReportDisposals
	|	WHERE
	|		SubcontractorReportDisposals.Ref = &BasisDocument) AS SubcontractorReport
	|
	|GROUP BY
	|	SubcontractorReport.ProductsAndServices,
	|	SubcontractorReport.Characteristic,
	|	SubcontractorReport.Batch,
	|	SubcontractorReport.MeasurementUnit
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
	
EndProcedure // FillBySubcontractorReport()

// Procedure of document filling based on purchase order.
//
Procedure FillByPurchaseOrder(FillingData)
	
	// Header filling.
	ThisObject.BasisDocument = FillingData;
	Company = FillingData.Company;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	MIN(PurchaseOrderInventory.LineNumber) AS LineNumber,
	|	PurchaseOrderInventory.ProductsAndServices AS ProductsAndServices,
	|	PurchaseOrderInventory.Characteristic AS Characteristic,
	|	PurchaseOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	SUM(PurchaseOrderInventory.Quantity) AS Quantity
	|FROM
	|	Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|WHERE
	|	PurchaseOrderInventory.Ref = &BasisDocument
	|	AND PurchaseOrderInventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|
	|GROUP BY
	|	PurchaseOrderInventory.ProductsAndServices,
	|	PurchaseOrderInventory.Characteristic,
	|	PurchaseOrderInventory.MeasurementUnit
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
	
EndProcedure // FillByPurchaseOrder()

// Procedure of document filling based on production.
//
Procedure FillByInventoryAssembly(FillingData)
	
	// Header filling.
	ThisObject.BasisDocument = FillingData;
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData,
			New Structure("Company, OperationKind, StructuralUnit, Cell, ProductsStructuralUnit, ProductsCell, DisposalsStructuralUnit, DisposalsCell"));
		
	Company = AttributeValues.Company;
	
	ArrayTSOrder = New Array;
	If AttributeValues.StructuralUnit.OrderWarehouse Then
		
		If AttributeValues.OperationKind = Enums.OperationKindsInventoryAssembly.Disassembly Then
			ArrayTSOrder.Add("Inventory");
			ArrayTSOrder.Add("Disposals");
		Else
			ArrayTSOrder.Add("Products");
			ArrayTSOrder.Add("Disposals");
		EndIf;
		
		StructuralUnit = AttributeValues.StructuralUnit;
		Cell = AttributeValues.Cell;
		
	Else
		
		If AttributeValues.DisposalsStructuralUnit.OrderWarehouse Then
			ArrayTSOrder.Add("Disposals");
			
			StructuralUnit = AttributeValues.DisposalsStructuralUnit;
			Cell = AttributeValues.DisposalsCell;
			
		EndIf;
		
		If AttributeValues.ProductsStructuralUnit.OrderWarehouse Then
			
			If AttributeValues.OperationKind = Enums.OperationKindsInventoryAssembly.Disassembly Then
				ArrayTSOrder.Add("Inventory");
			Else
				ArrayTSOrder.Add("Products");
			EndIf;
			
			StructuralUnit = AttributeValues.ProductsStructuralUnit;
			Cell = AttributeValues.ProductsCell;
			
		EndIf;
		
	EndIf;
	
	If ArrayTSOrder.Count() = 0 Then
		ErrorMessage = NStr("en='You can not enter the ""Receipt to order warehouse"" operation.
		|Document ""%DocumentRef"" has no order warehouse!';ru='Невозможен ввод операции ""Поступления на ордерный склад"".
		|Документ ""%ДокументСсылка"" не имеет ордерного склада!'");
		ErrorMessage = StrReplace(ErrorMessage, "%DocumentRef", FillingData.Ref);
		Raise ErrorMessage;
	EndIf;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	InventoryAssembly.Products.(
	|		ProductsAndServices,
	|		Characteristic,
	|		Batch,
	|		Quantity,
	|		MeasurementUnit
	|	),
	|	InventoryAssembly.Inventory.(
	|		ProductsAndServices,
	|		Characteristic,
	|		Batch,
	|		Quantity,
	|		MeasurementUnit
	|	),
	|	InventoryAssembly.Disposals.(
	|		ProductsAndServices,
	|		Characteristic,
	|		Batch,
	|		Quantity,
	|		MeasurementUnit
	|	)
	|FROM
	|	Document.InventoryAssembly AS InventoryAssembly
	|WHERE
	|	InventoryAssembly.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Inventory.Clear();
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		Selection.Next();
		For Each TabularSectionName IN ArrayTSOrder Do
			For Each TableRow IN Selection[TabularSectionName].Unload() Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, TableRow);
			EndDo;
		EndDo;
	EndIf;
	
EndProcedure // FillByInventoryAssembly()

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing) Export
		
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If TypeOf(FillingData) = Type("DocumentRef.GoodsExpense") Then
		FillByGoodsExpense(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SupplierInvoice") Then
		FillByPurchaseInvoice(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.InventoryReceipt") Then
		FillByInventoryReceipt(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.InventoryTransfer") Then
		FillByInventoryTransfer(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SubcontractorReport") Then
		FillBySubcontractorReport(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.PurchaseOrder") Then
		FillByPurchaseOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.InventoryAssembly") Then
		FillByInventoryAssembly(FillingData);
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.GoodsReceipt.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	SmallBusinessServer.ReflectInventoryForWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);

	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);

	// Control
	Documents.GoodsReceipt.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	Documents.GoodsReceipt.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

#EndIf
