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
	|	Inventory.LineNumber AS LineNumber,
	|	Inventory.Company AS Company,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.GLAccount AS GLAccount,
	|	Inventory.ProductsAndServices AS ProductsAndServices,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.CustomerOrder AS CustomerOrder,
	|	Inventory.Quantity AS QuantityBeforeWrite,
	|	Inventory.Quantity AS QuantityChange,
	|	Inventory.Quantity AS QuantityOnWrite,
	|	Inventory.Amount AS SumBeforeWrite,
	|	Inventory.Amount AS AmountChange,
	|	Inventory.Amount AS AmountOnWrite
	|INTO RegisterRecordsInventoryChange
	|FROM
	|	AccumulationRegister.Inventory AS Inventory");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsInventoryChange", False);
	
EndProcedure // CreateEmptyTemporaryTableChange()

#EndRegion

#EndIf