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
	|	ProductionOrders.LineNumber AS LineNumber,
	|	ProductionOrders.Company AS Company,
	|	ProductionOrders.ProductionOrder AS ProductionOrder,
	|	ProductionOrders.ProductsAndServices AS ProductsAndServices,
	|	ProductionOrders.Characteristic AS Characteristic,
	|	ProductionOrders.Quantity AS QuantityBeforeWrite,
	|	ProductionOrders.Quantity AS QuantityChange,
	|	ProductionOrders.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsProductionOrdersChange
	|FROM
	|	AccumulationRegister.ProductionOrders AS ProductionOrders");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsProductionOrdersChange", False);
	
EndProcedure // CreateEmptyTemporaryTableChange()

#EndRegion

#EndIf