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
	|	CustomerOrders.LineNumber AS LineNumber,
	|	CustomerOrders.Company AS Company,
	|	CustomerOrders.CustomerOrder AS CustomerOrder,
	|	CustomerOrders.ProductsAndServices AS ProductsAndServices,
	|	CustomerOrders.Characteristic AS Characteristic,
	|	CustomerOrders.Quantity AS QuantityBeforeWrite,
	|	CustomerOrders.Quantity AS QuantityChange,
	|	CustomerOrders.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsCustomerOrdersChange
	|FROM
	|	AccumulationRegister.CustomerOrders AS CustomerOrders");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsCustomerOrdersChange", False);
	
EndProcedure // CreateEmptyTemporaryTableChange()

#EndRegion

#EndIf