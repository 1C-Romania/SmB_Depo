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
	|	InventoryFromWarehouses.LineNumber AS LineNumber,
	|	InventoryFromWarehouses.Company AS Company,
	|	InventoryFromWarehouses.StructuralUnit AS StructuralUnit,
	|	InventoryFromWarehouses.ProductsAndServices AS ProductsAndServices,
	|	InventoryFromWarehouses.Characteristic AS Characteristic,
	|	InventoryFromWarehouses.Batch AS Batch,
	|	InventoryFromWarehouses.Quantity AS QuantityBeforeWrite,
	|	InventoryFromWarehouses.Quantity AS QuantityChange,
	|	InventoryFromWarehouses.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsInventoryFromWarehousesChange
	|FROM
	|	AccumulationRegister.InventoryFromWarehouses AS InventoryFromWarehouses");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsInventoryFromWarehousesChange", False);
	
EndProcedure // CreateEmptyTemporaryTableChange()

#EndRegion

#EndIf