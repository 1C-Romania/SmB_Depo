#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Function receives locked attributes of the object.
//
Function GetObjectAttributesBeingLocked() Export
	
	Result = New Array;
	Result.Add("CashCurrency");
	Result.Add("Owner");
	Result.Add("StructuralUnit");
	Result.Add("Department");
	Result.Add("CashCRType");
	
	Return Result;
	
EndFunction // GetLockedObjectAttributes()

// Function defines the default cash.
//
// Returns cash register if one cash is found.
// Returns Undefined if cash is not found or there are cashes more than one.
//
// Returns:
//  CatalogRef.CashRegisters - Found cash register
//
Function GetCashCRByDefault() Export
	
	Query = New Query(
	"SELECT TOP 2
	|	CashRegisters.Ref AS CashCR
	|FROM
	|	Catalog.CashRegisters AS CashRegisters
	|WHERE
	|	(NOT CashRegisters.DeletionMark)");
	
	Selection = Query.Execute().Select();
	If Selection.Count() = 1 
	   AND Selection.Next()
	Then
		CashCR = Selection.CashCR;
	Else
		CashCR = Undefined;
	EndIf;
	
	Return CashCR;

EndFunction // GetCashDefault()

// Function determines the selected cash register currency.
//
// Parameters:
//  CashCR - CatalogRef.CashRegisters - Ref on cash register
//
// Returns:
//  Structure - Company and Currency of selected cash register
//
Function GetCashRegisterAttributes(CashCR) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CashRegisters.StructuralUnit AS StructuralUnit,
	|	CashRegisters.Department AS Department,
	|	CashRegisters.Owner AS Company,
	|	CashRegisters.StructuralUnit.RetailPriceKind AS PriceKind,
	|	CashRegisters.StructuralUnit.RetailPriceKind.PriceIncludesVAT AS AmountIncludesVAT,
	|	CashRegisters.CashCurrency AS DocumentCurrency,
	|	CashRegisters.CashCRType AS CashCRType
	|FROM
	|	Catalog.CashRegisters AS CashRegisters
	|WHERE
	|	CashRegisters.Ref = &CashCR";
	
	Query.SetParameter("CashCR", CashCR);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		StructuralUnit = Selection.StructuralUnit;
		Department = Selection.Department;
		Company = Selection.Company;
		PriceKind = Selection.PriceKind;
		AmountIncludesVAT = Selection.AmountIncludesVAT;
		DocumentCurrency = Selection.DocumentCurrency;
		CashCRType = Selection.CashCRType;
	Else
		StructuralUnit = Undefined;
		Department = Undefined;
		Company = Undefined;
		PriceKind = Undefined;
		AmountIncludesVAT = Undefined;
		DocumentCurrency = Undefined;
		CashCRType = Undefined;
	EndIf;
	
	AttributesStructure = New Structure("StructuralUnit, Department, Company, PriceKind, AmountIncludesVAT, DocumentCurrency, CashCRType",
		StructuralUnit,
		Department,
		Company,
		PriceKind,
		AmountIncludesVAT,
		DocumentCurrency,
		CashCRType
	);
	
	Return AttributesStructure;

EndFunction // GetCashRegisterAttributes()

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see the fields content in the PrintManagement.CreatePrintCommandsCollection function
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#EndIf