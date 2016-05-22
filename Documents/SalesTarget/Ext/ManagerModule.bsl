#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefPlanSales, StructureAdditionalProperties) Export

	Query = New Query;
	Query.Text =
	"SELECT
	|	PlanSalesInventory.PlanningDate AS Period,
	|	&Company AS Company,
	|	PlanSalesInventory.Ref.PlanningPeriod AS PlanningPeriod,
	|	PlanSalesInventory.Ref.StructuralUnit AS StructuralUnit,
	|	PlanSalesInventory.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN PlanSalesInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	PlanSalesInventory.CustomerOrder AS CustomerOrder,
	|	PlanSalesInventory.Ref AS PlanningDocument,
	|	CASE
	|		WHEN VALUETYPE(PlanSalesInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN PlanSalesInventory.Quantity
	|		ELSE PlanSalesInventory.Quantity * PlanSalesInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CAST(PlanSalesInventory.VATAmount * CurrencyRatesOfDocument.ExchangeRate * AccountingCurrencyRate.Multiplicity / (AccountingCurrencyRate.ExchangeRate * CurrencyRatesOfDocument.Multiplicity) AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(PlanSalesInventory.Total * CurrencyRatesOfDocument.ExchangeRate * AccountingCurrencyRate.Multiplicity / (AccountingCurrencyRate.ExchangeRate * CurrencyRatesOfDocument.Multiplicity) AS NUMBER(15, 2)) AS Amount
	|FROM
	|	Document.SalesTarget.Inventory AS PlanSalesInventory
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS CurrencyRatesOfDocument
	|		ON PlanSalesInventory.Ref.DocumentCurrency = CurrencyRatesOfDocument.Currency
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						Constants.AccountingCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingCurrencyRate
	|		ON (TRUE)
	|WHERE
	|	PlanSalesInventory.Ref = &Ref
	|
	|ORDER BY
	|	PlanSalesInventory.LineNumber";
	
	Query.SetParameter("Ref", DocumentRefPlanSales);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	
	Result = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSalesTargets", Result);
	
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