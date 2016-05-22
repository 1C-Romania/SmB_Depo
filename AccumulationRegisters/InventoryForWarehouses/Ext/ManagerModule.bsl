#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Procedure creates an empty temporary table of records change.
//
Procedure CreateEmptyTemporaryTableChange(AdditionalProperties) Export
	
	If Not AdditionalProperties.Property("ForPosting")
	 OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	Query = New Query(
	"SELECT TOP 0
	|	InventoryForWarehouses.LineNumber AS LineNumber,
	|	InventoryForWarehouses.Company AS Company,
	|	InventoryForWarehouses.StructuralUnit AS StructuralUnit,
	|	InventoryForWarehouses.ProductsAndServices AS ProductsAndServices,
	|	InventoryForWarehouses.Characteristic AS Characteristic,
	|	InventoryForWarehouses.Batch AS Batch,
	|	InventoryForWarehouses.Quantity AS QuantityBeforeWrite,
	|	InventoryForWarehouses.Quantity AS QuantityChange,
	|	InventoryForWarehouses.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsInventoryForWarehousesChange
	|FROM
	|	AccumulationRegister.InventoryForWarehouses AS InventoryForWarehouses");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsInventoryForWarehousesChange", False);
	
EndProcedure // CreateEmptyTemporaryTableChange()

#EndRegion

#EndIf