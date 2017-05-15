#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Procedure creates an empty temporary table of records change.
//
Procedure CreateEmptyTemporaryTableChange(AdditionalProperties) Export
	
	If NOT AdditionalProperties.Property("ForPosting")
	 OR NOT AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	Query = New Query(
	"SELECT TOP 0
	|	SerialNumbers.LineNumber AS LineNumber,
	|	SerialNumbers.ProductsAndServices AS ProductsAndServices,
	|	SerialNumbers.Characteristic AS Characteristic,
	|	SerialNumbers.Batch AS Batch,
	|	SerialNumbers.SerialNumber AS SerialNumber,
	|	SerialNumbers.StructuralUnit AS StructuralUnit,
	|	SerialNumbers.Cell AS Cell,
	|	SerialNumbers.Quantity AS QuantityBeforeWrite,
	|	SerialNumbers.Quantity AS QuantityChange,
	|	SerialNumbers.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsSerialNumbersChange
	|FROM
	|	AccumulationRegister.SerialNumbers AS SerialNumbers");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsSerialNumbersChange", False);
	
EndProcedure

#EndRegion

#EndIf