#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefOperation, StructureAdditionalProperties) Export
	
	Query = New Query(
	"SELECT
	|	Managerial.LineNumber AS LineNumber,
	|	Managerial.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	Managerial.AccountDr AS AccountDr,
	|	CASE
	|		WHEN Managerial.AccountDr.Currency
	|			THEN Managerial.CurrencyDr
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN Managerial.AccountDr.Currency
	|			THEN Managerial.AmountCurDr
	|		ELSE 0
	|	END AS AmountCurDr,
	|	Managerial.AccountCr AS AccountCr,
	|	CASE
	|		WHEN Managerial.AccountCr.Currency
	|			THEN Managerial.CurrencyCr
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN Managerial.AccountCr.Currency
	|			THEN Managerial.AmountCurCr
	|		ELSE 0
	|	END AS AmountCurCr,
	|	Managerial.Amount AS Amount,
	|	Managerial.Content AS Content
	|FROM
	|	Document.Operation.AccountingRecords AS Managerial
	|WHERE
	|	Managerial.Ref = &Ref");
	
	Query.SetParameter("Ref", DocumentRefOperation);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", QueryResult.Unload());
	
EndProcedure // DocumentDataInitialization()

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#EndIf