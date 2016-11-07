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
	|	InventoryReceived.LineNumber AS LineNumber,
	|	InventoryReceived.Company AS Company,
	|	InventoryReceived.ProductsAndServices AS ProductsAndServices,
	|	InventoryReceived.Characteristic AS Characteristic,
	|	InventoryReceived.Batch AS Batch,
	|	InventoryReceived.Counterparty AS Counterparty,
	|	InventoryReceived.Contract AS Contract,
	|	InventoryReceived.Order AS Order,
	|	InventoryReceived.ReceptionTransmissionType AS ReceptionTransmissionType,
	|	InventoryReceived.Quantity AS QuantityBeforeWrite,
	|	InventoryReceived.Quantity AS QuantityChange,
	|	InventoryReceived.Quantity AS QuantityOnWrite,
	|	InventoryReceived.SettlementsAmount AS AmountSettlementsBeforeWrite,
	|	InventoryReceived.SettlementsAmount AS SettlementsAmountChange,
	|	InventoryReceived.SettlementsAmount AS SettlementsAmountOnWrite
	|INTO RegisterRecordsInventoryReceivedChange
	|FROM
	|	AccumulationRegister.InventoryReceived AS InventoryReceived");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsInventoryReceivedChange", False);
	
EndProcedure // CreateEmptyTemporaryTableChange()

#EndRegion

#EndIf