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
	|	PurchaseOrders.LineNumber AS LineNumber,
	|	PurchaseOrders.Company AS Company,
	|	PurchaseOrders.PurchaseOrder AS PurchaseOrder,
	|	PurchaseOrders.ProductsAndServices AS ProductsAndServices,
	|	PurchaseOrders.Characteristic AS Characteristic,
	|	PurchaseOrders.Quantity AS QuantityBeforeWrite,
	|	PurchaseOrders.Quantity AS QuantityChange,
	|	PurchaseOrders.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsPurchaseOrdersChange
	|FROM
	|	AccumulationRegister.PurchaseOrders AS PurchaseOrders");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsPurchaseOrdersChange", False);
	
EndProcedure // CreateEmptyTemporaryTableChange()

#EndRegion

#EndIf