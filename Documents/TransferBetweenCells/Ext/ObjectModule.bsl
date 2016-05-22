#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByPurchaseInvoice(FillingData)
	
	// Header filling.
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData, New Structure("Company, StructuralUnit, Cell"));
	
	FillPropertyValues(ThisObject, AttributeValues);
	ThisObject.BasisDocument = FillingData;
	OperationKind = Enums.OperationKindsTransferBetweenCells.FromOneToSeveral;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	SupplierInvoiceInventory.ProductsAndServices AS ProductsAndServices,
	|	SupplierInvoiceInventory.Characteristic AS Characteristic,
	|	SupplierInvoiceInventory.Batch AS Batch,
	|	SupplierInvoiceInventory.MeasurementUnit AS MeasurementUnit,
	|	SUM(SupplierInvoiceInventory.Quantity) AS Quantity
	|FROM
	|	Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|WHERE
	|	SupplierInvoiceInventory.Ref = &BasisDocument
	|
	|GROUP BY
	|	SupplierInvoiceInventory.ProductsAndServices,
	|	SupplierInvoiceInventory.Characteristic,
	|	SupplierInvoiceInventory.Batch,
	|	SupplierInvoiceInventory.MeasurementUnit";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Inventory.Load(Query.Execute().Unload());
	
EndProcedure // FillBySupplierInvoice()

#EndRegion

#Region EventsHandlers

// IN the FillingProcessor event handler the document is being processed.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.SupplierInvoice") Then
		
		FillByPurchaseInvoice(FillingData);
		
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.TransferBetweenCells.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	SmallBusinessServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);

	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);

	// Control
	Documents.TransferBetweenCells.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	Documents.TransferBetweenCells.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

#EndRegion

#EndIf