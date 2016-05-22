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
	|	InventoryTransferred.LineNumber AS LineNumber,
	|	InventoryTransferred.Company AS Company,
	|	InventoryTransferred.ProductsAndServices AS ProductsAndServices,
	|	InventoryTransferred.Characteristic AS Characteristic,
	|	InventoryTransferred.Batch AS Batch,
	|	InventoryTransferred.Counterparty AS Counterparty,
	|	InventoryTransferred.Contract AS Contract,
	|	InventoryTransferred.Order AS Order,
	|	InventoryTransferred.ReceptionTransmissionType AS ReceptionTransmissionType,
	|	InventoryTransferred.Quantity AS QuantityBeforeWrite,
	|	InventoryTransferred.Quantity AS QuantityChange,
	|	InventoryTransferred.Quantity AS QuantityOnWrite,
	|	InventoryTransferred.SettlementsAmount AS AmountSettlementsBeforeWrite,
	|	InventoryTransferred.SettlementsAmount AS SettlementsAmountChange,
	|	InventoryTransferred.SettlementsAmount AS SettlementsAmountOnWrite
	|INTO RegisterRecordsInventoryTransferredChange
	|FROM
	|	AccumulationRegister.InventoryTransferred AS InventoryTransferred");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsInventoryTransferredChange", False);
	
EndProcedure // CreateEmptyTemporaryTableChange()

#EndRegion

#EndIf