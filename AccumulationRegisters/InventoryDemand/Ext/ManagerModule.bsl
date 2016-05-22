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
	|	InventoryDemand.LineNumber AS LineNumber,
	|	InventoryDemand.Company AS Company,
	|	InventoryDemand.MovementType AS MovementType,
	|	InventoryDemand.CustomerOrder AS CustomerOrder,
	|	InventoryDemand.ProductsAndServices AS ProductsAndServices,
	|	InventoryDemand.Characteristic AS Characteristic,
	|	InventoryDemand.Quantity AS QuantityBeforeWrite,
	|	InventoryDemand.Quantity AS QuantityChange,
	|	InventoryDemand.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsInventoryDemandChange
	|FROM
	|	AccumulationRegister.InventoryDemand AS InventoryDemand");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsInventoryDemandChange", False);
	
EndProcedure // CreateEmptyTemporaryTableChange()

#EndRegion

#EndIf