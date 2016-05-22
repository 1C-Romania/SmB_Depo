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
	|	InventoryByCCD.LineNumber AS LineNumber,
	|	InventoryByCCD.Company AS Company,
	|	InventoryByCCD.ProductsAndServices AS ProductsAndServices,
	|	InventoryByCCD.CCDNo AS CCDNo,
	|	InventoryByCCD.Batch AS Batch,
	|	InventoryByCCD.Characteristic AS Characteristic,
	|	InventoryByCCD.CountryOfOrigin AS CountryOfOrigin,
	|	InventoryByCCD.Quantity AS QuantityBeforeWrite,
	|	InventoryByCCD.Quantity AS QuantityChange,
	|	InventoryByCCD.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsInventoryByCCDChange
	|FROM
	|	AccumulationRegister.InventoryByCCD AS InventoryByCCD");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsInventoryByCCDChange", False);
	
EndProcedure // CreateEmptyTemporaryTableChange()

#EndRegion

#EndIf