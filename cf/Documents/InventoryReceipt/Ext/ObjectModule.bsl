#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Interface

// Handler filling based on document GoodsReceipt.
//
// Parameters:
//  DocumentRefGoodsReceipt - DocumentRef.GoodsReceipt
//
Procedure FillInReceptionAndTransmissionRepair(DocumentRefReceptionAndTransmissionRepair) Export
	
	Company = DocumentRefReceptionAndTransmissionRepair.Company;
	StructuralUnit = DocumentRefReceptionAndTransmissionRepair.StructuralUnit;
	
	NewRow = Inventory.Add();
	FillPropertyValues(NewRow, DocumentRefReceptionAndTransmissionRepair);
	NewRow.ConnectionKey = 1;
	NewRow.Count = 1;
	NewRow.MeasurementUnit = CommonUse.ObjectAttributeValue(NewRow.ProductsAndServices, "MeasurementUnit");
	
	If ValueIsFilled(DocumentRefReceptionAndTransmissionRepair.SerialNumber) Then
		NewRowSN = SerialNumbers.Add();
		NewRowSN.SerialNumber = DocumentRefReceptionAndTransmissionRepair.SerialNumber;
		NewRowSN.ConnectionKey = NewRow.ConnectionKey;
		
		NewRow.SerialNumbers = WorkWithSerialNumbersClientServer.StringPresentationOfSerialNumbersOfLine(SerialNumbers, NewRowSN.ConnectionKey);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure checks the existence of retail price.
//
Procedure CheckExistenceOfRetailPrice(Cancel)
	
	If StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.Retail
	 OR StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting Then
	 
		Query = New Query;
		Query.SetParameter("Date", Date);
		Query.SetParameter("DocumentTable", Inventory);
		Query.SetParameter("RetailPriceKind", StructuralUnit.RetailPriceKind);
		Query.SetParameter("ListProductsAndServices", Inventory.UnloadColumn("ProductsAndServices"));
		Query.SetParameter("ListCharacteristic", Inventory.UnloadColumn("Characteristic"));
		
		Query.Text =
		"SELECT
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.ProductsAndServices AS ProductsAndServices,
		|	DocumentTable.Characteristic AS Characteristic,
		|	DocumentTable.Batch AS Batch
		|INTO InventoryTransferInventory
		|FROM
		|	&DocumentTable AS DocumentTable
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	InventoryTransferInventory.LineNumber AS LineNumber,
		|	PRESENTATION(InventoryTransferInventory.ProductsAndServices) AS ProductsAndServicesPresentation,
		|	PRESENTATION(InventoryTransferInventory.Characteristic) AS CharacteristicPresentation,
		|	PRESENTATION(InventoryTransferInventory.Batch) AS BatchPresentation
		|FROM
		|	InventoryTransferInventory AS InventoryTransferInventory
		|		LEFT JOIN InformationRegister.ProductsAndServicesPrices.SliceLast(
		|				&Date,
		|				PriceKind = &RetailPriceKind
		|					AND ProductsAndServices IN (&ListProductsAndServices)
		|					AND Characteristic IN (&ListCharacteristic)) AS ProductsAndServicesPricesSliceLast
		|		ON InventoryTransferInventory.ProductsAndServices = ProductsAndServicesPricesSliceLast.ProductsAndServices
		|			AND InventoryTransferInventory.Characteristic = ProductsAndServicesPricesSliceLast.Characteristic
		|WHERE
		|	ISNULL(ProductsAndServicesPricesSliceLast.Price, 0) = 0";
		
		SelectionOfQueryResult = Query.Execute().Select();
		
		While SelectionOfQueryResult.Next() Do
			
			MessageText = NStr("ru = 'Для номенклатуры %ПредставлениеНоменклатуры% в строке %НомерСтроки% списка ""Запасы"" не установлена розничная цена!'; en = 'For products and services %ProductsAndServicesPresentation% in string %LineNumber% of the ""Inventory"" list the retail price is not set!'");
			MessageText = StrReplace(MessageText, "%LineNumber%", String(SelectionOfQueryResult.LineNumber));
			MessageText = StrReplace(MessageText, "%ProductsAndServicesPresentation%",  SmallBusinessServer.PresentationOfProductsAndServices(SelectionOfQueryResult.ProductsAndServicesPresentation, SelectionOfQueryResult.CharacteristicPresentation, SelectionOfQueryResult.BatchPresentation));
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Inventory",
				SelectionOfQueryResult.LineNumber,
				"ProductsAndServices",
				Cancel
			);
			
		EndDo;
		
	EndIf;
	
EndProcedure // CheckRetailPriceExistence()

#EndRegion

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
		
		// FO Use Production subsystem.
		If Not Constants.FunctionalOptionUseSubsystemProduction.Get()
			AND StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.Department Then
			Raise NStr("ru = 'Нельзя ввести Оприходование запасов на основании инвентеризации запасов, т.к. недоступен вид деятельности Производство!'; en = 'You can not enter Inventory receipt basing on the inventory reconciliation, as the Production activity kind is not available!'");
		EndIf;
		
		Query = New Query(
		"SELECT
		|	MIN(InventoryReconciliation.LineNumber) AS LineNumber,
		|	InventoryReconciliation.ProductsAndServices AS ProductsAndServices,
		|	InventoryReconciliation.Characteristic AS Characteristic,
		|	InventoryReconciliation.Batch AS Batch,
		|	InventoryReconciliation.MeasurementUnit AS MeasurementUnit,
		|	MAX(InventoryReconciliation.Quantity - InventoryReconciliation.QuantityAccounting) AS QuantityInventorytakingRejection,
		|	SUM(CASE
		|			WHEN InventoryReceipt.Quantity IS NULL
		|				THEN 0
		|			ELSE InventoryReceipt.Quantity
		|		END) AS QuantityDebited,
		|	InventoryReconciliation.Price
		|FROM
		|	Document.InventoryReconciliation.Inventory AS InventoryReconciliation
		|		LEFT JOIN Document.InventoryReceipt.Inventory AS InventoryReceipt
		|		ON InventoryReconciliation.ProductsAndServices = InventoryReceipt.ProductsAndServices
		|			AND InventoryReconciliation.Characteristic = InventoryReceipt.Characteristic
		|			AND InventoryReconciliation.Batch = InventoryReceipt.Batch
		|			AND InventoryReconciliation.Ref = InventoryReceipt.Ref.BasisDocument
		|			AND (InventoryReceipt.Ref <> &DocumentRef)
		|			AND (InventoryReceipt.Ref.Posted)
		|WHERE
		|	InventoryReconciliation.Ref = &BasisDocument
		|	AND InventoryReconciliation.Quantity - InventoryReconciliation.QuantityAccounting > 0
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
		|	InventoryReconciliation.MeasurementUnit,
		|	InventoryReconciliation.Price
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
				
				QuantityToReceive = Selection.QuantityInventorytakingRejection - Selection.QuantityDebited;
				If QuantityToReceive <= 0 Then
					Continue;
				EndIf;
				
				TabularSectionRow = Inventory.Add();
				TabularSectionRow.ProductsAndServices		= Selection.ProductsAndServices;
				TabularSectionRow.Characteristic		= Selection.Characteristic;
				TabularSectionRow.Batch				= Selection.Batch;
				TabularSectionRow.MeasurementUnit	= Selection.MeasurementUnit;
				TabularSectionRow.Quantity			= QuantityToReceive;
				TabularSectionRow.Price				= Selection.Price;
				TabularSectionRow.Amount				= TabularSectionRow.Quantity * TabularSectionRow.Price;
			
			EndDo;
			
		EndIf;
		
		If Inventory.Count() = 0 Then
			
			Raise NStr("ru = 'Нет данных для оформления оприходования!'; en = 'No data for posting registration!'");
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.GoodsReceipt") Then	
		
		Company = FillingData.Company;
		StructuralUnit = FillingData.StructuralUnit;
		Cell = FillingData.Cell;
		
		For Each CurStringInventory IN FillingData.Inventory Do
			
			NewRow = Inventory.Add();
			NewRow.MeasurementUnit = CurStringInventory.MeasurementUnit;
			NewRow.Quantity = CurStringInventory.Quantity;
			NewRow.ProductsAndServices = CurStringInventory.ProductsAndServices;
			NewRow.Batch = CurStringInventory.Batch;
			NewRow.Characteristic = CurStringInventory.Characteristic;
			
		EndDo;
		
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Check existence of retail prices.
	CheckExistenceOfRetailPrice(Cancel);
	
	// Serial numbers
	If NOT CommonUse.ObjectAttributeValue(StructuralUnit, "OrderWarehouse") = True Then
		WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
	EndIf;
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	DocumentAmount = Inventory.Total("Amount");
	
EndProcedure // BeforeWrite()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.InventoryReceipt.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	SmallBusinessServer.ReflectInventoryForWarehouses(AdditionalProperties, RegisterRecords, Cancel);
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
	Documents.InventoryReceipt.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	Documents.InventoryReceipt.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

#EndRegion

#EndIf