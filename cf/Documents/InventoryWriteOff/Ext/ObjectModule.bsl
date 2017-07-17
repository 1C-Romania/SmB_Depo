#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// IN the event handler of the FillingProcessor document
// - document filling by inventory reconciliation in the warehouse.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.InventoryReconciliation") AND ValueIsFilled(FillingData) Then
		
		ThisObject.BasisDocument = FillingData.Ref;
		Company = FillingData.Company;
		StructuralUnit = FillingData.StructuralUnit;
		Cell = FillingData.Cell;
		
		Query = New Query(
		"SELECT
		|	MIN(InventoryReconciliation.LineNumber) AS LineNumber,
		|	InventoryReconciliation.ProductsAndServices AS ProductsAndServices,
		|	InventoryReconciliation.Characteristic AS Characteristic,
		|	InventoryReconciliation.Batch AS Batch,
		|	InventoryReconciliation.MeasurementUnit AS MeasurementUnit,
		|	MAX(InventoryReconciliation.QuantityAccounting - InventoryReconciliation.Quantity) AS QuantityRejection,
		|	SUM(CASE
		|			WHEN InventoryWriteOff.Quantity IS NULL 
		|				THEN 0
		|			ELSE InventoryWriteOff.Quantity
		|		END) AS WrittenOffQuantity
		|FROM
		|	Document.InventoryReconciliation.Inventory AS InventoryReconciliation
		|		LEFT JOIN Document.InventoryWriteOff.Inventory AS InventoryWriteOff
		|		ON InventoryReconciliation.ProductsAndServices = InventoryWriteOff.ProductsAndServices
		|			AND InventoryReconciliation.Characteristic = InventoryWriteOff.Characteristic
		|			AND InventoryReconciliation.Batch = InventoryWriteOff.Batch
		|			AND InventoryReconciliation.Ref = InventoryWriteOff.Ref.BasisDocument
		|			AND (InventoryWriteOff.Ref <> &DocumentRef)
		|			AND (InventoryWriteOff.Ref.Posted)
		|WHERE
		|	InventoryReconciliation.Ref = &BasisDocument
		|	AND InventoryReconciliation.QuantityAccounting - InventoryReconciliation.Quantity > 0
		|	AND CASE
		|			WHEN InventoryReconciliation.Batch <> VALUE(Catalog.ProductsAndServicesBatches.EmptyRef)
		|				THEN InventoryReconciliation.Batch.Status = VALUE(Enum.BatchStatuses.OwnInventory)
		|			ELSE TRUE
		|		END
		|
		|GROUP BY
		|	InventoryReconciliation.ProductsAndServices,
		|	InventoryReconciliation.Characteristic,
		|	InventoryReconciliation.Batch,
		|	InventoryReconciliation.MeasurementUnit
		|
		|ORDER BY
		|	LineNumber");
		
		Query.SetParameter("BasisDocument", FillingData);
		Query.SetParameter("DocumentRef", Ref);
		
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			
			Selection = QueryResult.Select();
			
			// Filling document tabular section.
			Inventory.Clear();
			
			While Selection.Next() Do
				
				CountWriteOff = Selection.QuantityRejection - Selection.WrittenOffQuantity;
				
				If CountWriteOff <= 0 Then
					Continue;
				EndIf;
				
				TabularSectionRow = Inventory.Add();
				TabularSectionRow.ProductsAndServices		= Selection.ProductsAndServices;
				TabularSectionRow.Characteristic		= Selection.Characteristic;
				TabularSectionRow.Batch				= Selection.Batch;
				TabularSectionRow.MeasurementUnit	= Selection.MeasurementUnit;
				TabularSectionRow.Quantity			= CountWriteOff;
				
			EndDo;
			
		EndIf;
		
		If Inventory.Count() = 0 Then
			
			Message = New UserMessage();
			Raise NStr("en='No data to register write-off.';ru='Нет данных для оформления списания!'");
			Message.Message();
			
			StandardProcessing = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Serial numbers
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.InventoryWriteOff.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	SmallBusinessServer.ReflectInventoryForExpenseFromWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);

	// SerialNumbers
	SmallBusinessServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);

	// Control
	Documents.InventoryWriteOff.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	Documents.InventoryWriteOff.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

#EndRegion

#EndIf