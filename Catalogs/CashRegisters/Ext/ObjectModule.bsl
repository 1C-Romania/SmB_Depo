#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure Filling(FillingData, StandardProcessing)
	
	If IsNew() Then
		
		Query = New Query;
		Query.Text = 
		"SELECT TOP 2
		|	StructuralUnits.Ref AS StructuralUnit
		|FROM
		|	Catalog.StructuralUnits AS StructuralUnits
		|WHERE
		|	StructuralUnits.StructuralUnitType = &StructuralUnitType
		|	AND (NOT StructuralUnits.DeletionMark)";
		
		Query.SetParameter("StructuralUnitType", Enums.StructuralUnitsTypes.Retail);
		
		Result = Query.Execute();
		Selection = Result.Select();
		
		If Selection.Count() = 1 Then
			Selection.Next();
			StructuralUnit = Selection.StructuralUnit;
		EndIf;
		
		Query.Text = 
		"SELECT TOP 2
		|	Companies.Ref AS Company
		|FROM
		|	Catalog.Companies AS Companies
		|WHERE
		|	(NOT Companies.DeletionMark)";
		
		Result = Query.Execute();
		Selection = Result.Select();
		
		If Selection.Count() = 1 Then
			Selection.Next();
			Owner = Selection.Company;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If CashCRType = Enums.CashCRTypes.AutonomousCashRegister
	OR (CashCRType = Enums.CashCRTypes.FiscalRegister AND UseWithoutEquipmentConnection) Then
		
		AttributeToBeDeleted = CheckedAttributes.Find("Peripherals");
		If AttributeToBeDeleted <> Undefined Then
			CheckedAttributes.Delete(CheckedAttributes.Find("Peripherals"));
		EndIf;
		
	EndIf;
	
EndProcedure // FillCheckProcessing()

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If CashCRType = Enums.CashCRTypes.AutonomousCashRegister Then
		UseWithoutEquipmentConnection = False;
		Peripherals = Undefined;
	EndIf;
	
	If UseWithoutEquipmentConnection Then
		Peripherals = Undefined;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf