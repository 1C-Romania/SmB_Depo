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
	|	InventoryInWarehouses.LineNumber AS LineNumber,
	|	InventoryInWarehouses.Company AS Company,
	|	InventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|	InventoryInWarehouses.ProductsAndServices AS ProductsAndServices,
	|	InventoryInWarehouses.Characteristic AS Characteristic,
	|	InventoryInWarehouses.Batch AS Batch,
	|	InventoryInWarehouses.Cell AS Cell,
	|	InventoryInWarehouses.Quantity AS QuantityBeforeWrite,
	|	InventoryInWarehouses.Quantity AS QuantityChange,
	|	InventoryInWarehouses.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsInventoryInWarehousesChange
	|FROM
	|	AccumulationRegister.InventoryInWarehouses AS InventoryInWarehouses");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsInventoryInWarehousesChange", False);
	
EndProcedure // CreateEmptyTemporaryTableChange()

#EndRegion

#EndIf