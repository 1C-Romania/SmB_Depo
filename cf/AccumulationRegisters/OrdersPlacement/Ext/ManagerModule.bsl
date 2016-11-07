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
	|	OrdersPlacement.LineNumber AS LineNumber,
	|	OrdersPlacement.Company AS Company,
	|	OrdersPlacement.CustomerOrder AS CustomerOrder,
	|	OrdersPlacement.ProductsAndServices AS ProductsAndServices,
	|	OrdersPlacement.Characteristic AS Characteristic,
	|	OrdersPlacement.SupplySource AS SupplySource,
	|	OrdersPlacement.Quantity AS QuantityBeforeWrite,
	|	OrdersPlacement.Quantity AS QuantityChange,
	|	OrdersPlacement.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsOrdersPlacementChange
	|FROM
	|	AccumulationRegister.OrdersPlacement AS OrdersPlacement");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsOrdersPlacementChange", False);
	
EndProcedure // CreateEmptyTemporaryTableChange()

#EndRegion

#EndIf