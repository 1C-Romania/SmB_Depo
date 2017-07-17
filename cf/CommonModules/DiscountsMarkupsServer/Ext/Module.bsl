#Region ServiceProceduresAndFunctions

// The function returns the picture index depending on value of the SharedUsageVariant field of the analyzed group
Function GetPictureIndexForGroup(TreeRow) Export
	
	IndexOf = 0;
	If TreeRow.SharedUsageVariant = Enums.DiscountsMarkupsSharedUsageOptions.Max Then
		IndexOf = 8
	ElsIf TreeRow.SharedUsageVariant = Enums.DiscountsMarkupsSharedUsageOptions.Minimum Then
		IndexOf = 16
	ElsIf TreeRow.SharedUsageVariant = Enums.DiscountsMarkupsSharedUsageOptions.Addition Then
		IndexOf = 0
	ElsIf TreeRow.SharedUsageVariant = Enums.DiscountsMarkupsSharedUsageOptions.Multiplication Then
		IndexOf = 4
	ElsIf TreeRow.SharedUsageVariant = Enums.DiscountsMarkupsSharedUsageOptions.Exclusion Then
		IndexOf = 12
	EndIf;
	
	If TreeRow.DeletionMark Then
		IndexOf = IndexOf + 3;
	EndIf;
	
	Return IndexOf;
	
EndFunction

// The function returns an image index depending on the value of the AssignmentMethod and DeletionMark fields of the analyzed discount
Function GetPictureIndexForDiscount(TreeRow) Export
	
	IndexOf = 0;
	If TreeRow.AssignmentMethod = Enums.DiscountsMarkupsProvidingWays.Percent Then
		If TreeRow.DiscountMarkupValue < 0 Then
			IndexOf = 32;
		Else
			IndexOf = 28;
		EndIf;
	ElsIf TreeRow.AssignmentMethod = Enums.DiscountsMarkupsProvidingWays.Amount Then
		If TreeRow.DiscountMarkupValue < 0 Then
			IndexOf = 40;
		Else
			IndexOf = 44;
		EndIf;
	EndIf;
	
	If TreeRow.DeletionMark Then
		IndexOf = IndexOf + 3;
	EndIf;
	
	Return IndexOf;
	
EndFunction

// The function creates a table of values.
//
// Returns:
// ValueTable
//
Function GetEmptyDiscountsTableWithDetails(Parameters)
	
	If Parameters.EmptyDiscountsTableWithDetails = Undefined Then
		Table = New ValueTable;
		Table.Columns.Add("ConnectionKey",   New TypeDescription("Number"));
		Table.Columns.Add("Details", New TypeDescription("ValueTable"));
		Table.Columns.Add("Amount",       New TypeDescription("Number"));
		Table.Columns.Add("Acts",   New TypeDescription("Boolean"));
		Parameters.EmptyDiscountsTableWithDetails = Table;
	Else
		Return Parameters.EmptyDiscountsTableWithDetails.CopyColumns();
	EndIf;
	
	Return Table;
	
EndFunction // GetEmptyDiscountsTableWithDetails()

// The function unites subordinate data tables.
//
// Returns:
// DataTable - united data table.
//
Function UniteSubordinateRowsDataTables(TreeRow)
	
	DataTable = New ValueTable;
	DataTable.Columns.Add("ConnectionKey",                 New TypeDescription("Number"));
	DataTable.Columns.Add("Amount",                     New TypeDescription("Number"));
	DataTable.Columns.Add("Details",               New TypeDescription("ValueTable"));
	DataTable.Columns.Add("AdditionalOrderingAttribute", New TypeDescription("Number"));
	
	For Each SubordinatedRow IN TreeRow.Rows Do
		
		If Not SubordinatedRow.IsFolder Then // This is discount, not a group
			
			If Not SubordinatedRow.ConditionsParameters.ConditionsFulfilled Then
				Continue;
			EndIf;
			
		EndIf;
		
		AdditionalOrderingAttribute = SubordinatedRow.AdditionalOrderingAttribute;
		
		For Each TableRow IN SubordinatedRow.DataTable Do
			If SubordinatedRow.IsFolder Then
				NewRow = DataTable.Add();
				FillPropertyValues(NewRow, TableRow);
				NewRow.AdditionalOrderingAttribute = AdditionalOrderingAttribute;
			Else
				If TableRow.Acts Then
					NewRow = DataTable.Add();
					FillPropertyValues(NewRow, TableRow);
					NewRow.AdditionalOrderingAttribute = AdditionalOrderingAttribute;
				EndIf;
			EndIf;
		EndDo;
		
	EndDo;
	
	Return DataTable;
	
EndFunction // UniteSubordinateRowsDataTables()

// The function creates a table of values with discount details and adds the sent values to it.
//
// Returns:
// ValueTable - Details of discounts.
//
Function GetDiscountDetails(TreeRow, Amount, Parameters)
	
	Details = Parameters.EmptyTableDecryption.CopyColumns();
	
	RowOfDetails = Details.Add();
	RowOfDetails.DiscountMarkup = TreeRow.DiscountMarkup;
	RowOfDetails.Amount         = Amount;
	
	Return Details;
	
EndFunction // GetDiscountDetails()

// The function fills the connection keys in spreadsheet parts "Products" of the document.
//
Procedure FillLinkingKeysInSpreadsheetPartProducts(Object, TSName, NameSP2 = Undefined) Export
	
	IndexOf = 0;
	For Each TSRow IN Object[TSName] Do
		IndexOf = IndexOf + 1;
		TSRow.ConnectionKey = IndexOf;
	EndDo;
	
	If Not NameSP2 = Undefined Then
		For Each TSRow IN Object[NameSP2] Do
			IndexOf = IndexOf + 1;
			TSRow.ConnectionKeyForMarkupsDiscounts = IndexOf;
		EndDo;
	EndIf;
	
EndProcedure // FillConnectionKeysInSpreadsheetPartProducts()

// The function receives current time of the object
//
// Parameters
//  Object  - DocumentObject - object for which you need to get the current time
//
// Returns:
//   Date   - Current time of the object
//
Function GetObjectCurrentTime(Object) Export
	
	CurrentDate = ?(ValueIsFilled(Object.Ref), Object.Date, CurrentSessionDate());
	CurrentTime = '00010101' + (CurrentDate - BegOfDay(CurrentDate));
	
	Return CurrentTime;
	
EndFunction // GetObjectCurrentTime()

// The function gets current date object time
//
// Parameters
//  Object  - DocumentObject - object for which you need to get the current time
//
// Returns:
//   Date   - Current time of the object
//
Function GetObjectCurrentDate(Object) Export
	
	CurrentDate = ?(ValueIsFilled(Object.Ref), Object.Date, CurrentSessionDate());
	
	Return CurrentDate;
	
EndFunction // GetObjectCurrentDate()

// The function checks if recalculation of automatic discounts is necessary depending on the action that led to the function call.
//
Function CheckNeedToRecalculateAutomaticDiscounts(Action, ColumnTS) Export
	
	AutomaticDiscountsRecalculationIsRequired = True;
	
	// If the sum or price has changed and there is no discount which
	// depends on the price, then there is no need to recalculate automatic discounts.
	If Find(Action, "Date") > 0 Then
		RecordManager = InformationRegisters.ServiceAutomaticDiscounts.CreateRecordManager();
		RecordManager.Read();
		If RecordManager.ScheduleDiscountsAvailable Then
			AutomaticDiscountsRecalculationIsRequired = True;
		Else
			AutomaticDiscountsRecalculationIsRequired = False;
		EndIf;
	// If counterparty was changed and there are no discounts that depend
	// on recipient-counterparty, then there is no need to recalculate automatic discounts.
	ElsIf Find(Action, "Counterparty") > 0 Then
		RecordManager = InformationRegisters.ServiceAutomaticDiscounts.CreateRecordManager();
		RecordManager.Read();
		If RecordManager.CounterpartyRecipientDiscountsAvailable Then
			AutomaticDiscountsRecalculationIsRequired = True;
		Else
			AutomaticDiscountsRecalculationIsRequired = False;
		EndIf;
	// If counterparty has changed and there are no discounts that depend
	// on the recipient warehouse, then there is no need to recalculate the automatic discounts.
	ElsIf Find(Action, "Warehouse") > 0 Then
		RecordManager = InformationRegisters.ServiceAutomaticDiscounts.CreateRecordManager();
		RecordManager.Read();
		If RecordManager.WarehouseRecipientDiscountsAvailable Then
			AutomaticDiscountsRecalculationIsRequired = True;
		Else
			AutomaticDiscountsRecalculationIsRequired = False;
		EndIf;
	Else
		AutomaticDiscountsRecalculationIsRequired = True;
	EndIf;
	
	Return AutomaticDiscountsRecalculationIsRequired;
	
EndFunction

// Function clears checkbox "DiscountsAreCalculated" if it is necessary and returns True if it is required to recalculate discounts.
//
Function ResetFlagDiscountsAreCalculated(Form, Action, SPColumn, CWT = "Inventory", SP2 = Undefined) Export
	
	Object = Form.Object;
	Items = Form.Items;
	
	AutomaticDiscountsRecalculationIsRequired = True;
	
	If Object[CWT].Count() = 0 AND (SP2 = Undefined OR Object[SP2].Count() = 0) Then
		Form.InstalledGrayColor = True;
		Items[CWT+"CalculateDiscountsMarkups"].Picture = PictureLib.UpdateGray;
		If SP2 <> Undefined Then
			Items[SP2+"CalculateDiscountsMarkups"].Picture = PictureLib.UpdateGray;
		EndIf;
		AutomaticDiscountsRecalculationIsRequired = False;
	Else
		AutomaticDiscountsRecalculationIsRequired = CheckNeedToRecalculateAutomaticDiscounts(Action, SPColumn);
		
		If AutomaticDiscountsRecalculationIsRequired Then
			Items[CWT+"CalculateDiscountsMarkups"].Picture = PictureLib.UpdateRed;
			
			If SP2 <> Undefined Then
				Items[SP2+"CalculateDiscountsMarkups"].Picture = PictureLib.UpdateRed;
			EndIf;
			
			Form.InstalledGrayColor = False;
		EndIf;
	EndIf;
	
	If AutomaticDiscountsRecalculationIsRequired AND Object.DiscountsAreCalculated Then
		Object.DiscountsAreCalculated = False;
	EndIf;
	Return AutomaticDiscountsRecalculationIsRequired;
	
EndFunction

#EndRegion

#Region ServiceQueries

// The function generates query text for table of discounts (markups) values by price groups.
//
// Returns:
// Structure - Query text
//
Function QueryTextTableCurrencyRates() Export
	
	QueryText =
	"SELECT
	|	CurrencyRatesSliceLast.Currency    AS Currency,
	|	CurrencyRatesSliceLast.ExchangeRate      AS ExchangeRate,
	|	CurrencyRatesSliceLast.Multiplicity AS Multiplicity
	|INTO CurrencyRates
	|FROM
	|	InformationRegister.CurrencyRates.SliceLast(&CurrentDate, ) AS CurrencyRatesSliceLast
	|
	|INDEX BY
	|	Currency";
	
	QueryText = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	Return New Structure("QueryText, TablesCount, ResultTableNumber, TableName", QueryText, 1, 1, "CurrencyRates");
	
EndFunction // QueryTextDiscountsMarkupsValueTableByPriceGroups()

// The function generates text of the query for the table of existing discounts (markups).
//
// Returns:
// Structure - Query text
//
Function QueryTextDiscountsMarkupsTable(OnlyPreliminaryCalculation)
	
	QueryText =
	"SELECT ALLOWED
	|	DiscountsMarkups.DiscountMarkup AS Ref
	|INTO TemporaryTable
	|FROM
	|	&DiscountsMarkups AS DiscountsMarkups
	|
	|INDEX BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	DiscountsMarkups.Ref AS Ref,
	|	DiscountsMarkups.SharedUsageVariant AS SharedUsageVariant,
	|	DiscountsMarkups.AdditionalOrderingAttribute AS AdditionalOrderingAttribute,
	|	DiscountsMarkups.AssignmentArea AS AssignmentArea,
	|	DiscountsMarkups.AssignmentMethod AS AssignmentMethod,
	|	CASE
	|		WHEN DiscountsMarkups.AssignmentMethod = VALUE(Enum.DiscountsMarkupsProvidingWays.Amount)
	|			THEN DiscountsMarkups.DiscountMarkupValue * ISNULL(CurrencyRatesProvisions.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1) / (ISNULL(CurrencyRatesOfDocument.ExchangeRate, 1) * ISNULL(CurrencyRatesProvisions.Multiplicity, 1))
	|		ELSE DiscountsMarkups.DiscountMarkupValue
	|	END AS DiscountMarkupValue,
	|	DiscountsMarkups.AssignmentCurrency AS AssignmentCurrency
	|INTO TemporaryDiscountMarkupTable
	|FROM
	|	TemporaryTable AS TemporaryDiscountTable
	|		INNER JOIN Catalog.AutomaticDiscounts AS DiscountsMarkups
	|		ON TemporaryDiscountTable.Ref = DiscountsMarkups.Ref
	|		LEFT JOIN CurrencyRates AS CurrencyRatesProvisions
	|		ON (CurrencyRatesProvisions.Currency = DiscountsMarkups.AssignmentCurrency)
	|		LEFT JOIN CurrencyRates AS CurrencyRatesOfDocument
	|		ON (CurrencyRatesOfDocument.Currency = &DocumentCurrency)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TemporaryDiscountMarkupTable.Ref AS DiscountMarkup,
	|	TemporaryDiscountMarkupTable.AssignmentMethod AS AssignmentMethod,
	|	TemporaryDiscountMarkupTable.AssignmentArea AS AssignmentArea,
	|	TemporaryDiscountMarkupTable.DiscountMarkupValue AS DiscountMarkupValue
	|FROM
	|	TemporaryDiscountMarkupTable AS TemporaryDiscountMarkupTable
	|		INNER JOIN Catalog.AutomaticDiscounts AS DiscountsMarkups
	|		ON TemporaryDiscountMarkupTable.Ref = DiscountsMarkups.Ref";
	
	QueryText = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	Return New Structure("QueryText, TablesCount, ResultTableNumber, TableName", QueryText, 3, 3, "DiscountsMarkups");
	
EndFunction // QueryTextDiscountsMarkupsTable

// The function generates text of the query for the table of existing discounts (markups).
//
// Returns:
// Structure - Query text
//
Function QueryTextTableAssignmentCondition()
	
	// IN the query all DISTINCT are selected as Different discounts may have same conditions.
	// Later this table is used to define the fullfilled conditions with the help of an internal connection.
	// There shall be no duplicates in this table!
	//
	QueryText =
	"SELECT ALLOWED DISTINCT
	|	Conditions.AssignmentCondition AS Ref,
	|	Conditions.AssignmentCondition.AssignmentCondition AS AssignmentCondition,
	|	Conditions.AssignmentCondition.ComparisonType AS ComparisonType,
	|	Conditions.AssignmentCondition.RestrictionCurrency AS RestrictionCurrency,
	|	Conditions.AssignmentCondition.UseRestrictionCriterionForSalesVolume AS UseRestrictionCriterionForSalesVolume,
	|	Conditions.AssignmentCondition.RestrictionArea AS RestrictionArea,
	|	CASE
	|		WHEN Conditions.AssignmentCondition.AssignmentCondition = VALUE(Enum.DiscountsMarkupsProvidingConditions.ForOneTimeSalesVolume)
	|				AND Conditions.AssignmentCondition.UseRestrictionCriterionForSalesVolume = VALUE(Enum.DiscountMarkupUseLimitCriteriaForSalesVolume.Amount)
	|			THEN Conditions.AssignmentCondition.RestrictionConditionValue * ISNULL(CurrencyRatesRestriction.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1) / (ISNULL(CurrencyRatesOfDocument.ExchangeRate, 1) * ISNULL(CurrencyRatesRestriction.Multiplicity, 1))
	|		ELSE Conditions.AssignmentCondition.RestrictionConditionValue
	|	END AS RestrictionConditionValue,
	|	Conditions.AssignmentCondition.TakeIntoAccountSaleOfOnlyParticularProductsAndServicesList AS ThereIsFilterByProductsAndServices
	|INTO ConditionsOfAssignment
	|FROM
	|	TemporaryTable AS DiscountsMarkups
	|		INNER JOIN Catalog.AutomaticDiscounts.ConditionsOfAssignment AS Conditions
	|		ON DiscountsMarkups.Ref = Conditions.Ref
	|		LEFT JOIN CurrencyRates AS CurrencyRatesRestriction
	|		ON (CurrencyRatesRestriction.Currency = Conditions.AssignmentCondition.RestrictionCurrency)
	|		LEFT JOIN CurrencyRates AS CurrencyRatesOfDocument
	|		ON (CurrencyRatesOfDocument.Currency = &DocumentCurrency)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ConditionsOfAssignment.Ref AS Ref,
	|	ConditionsOfAssignment.AssignmentCondition AS AssignmentCondition,
	|	ConditionsOfAssignment.RestrictionCurrency AS RestrictionCurrency,
	|	ConditionsOfAssignment.ComparisonType AS ComparisonType,
	|	ConditionsOfAssignment.UseRestrictionCriterionForSalesVolume AS UseRestrictionCriterionForSalesVolume,
	|	ConditionsOfAssignment.RestrictionArea AS RestrictionArea,
	|	ConditionsOfAssignment.RestrictionConditionValue AS RestrictionConditionValue,
	|	ConditionsOfAssignment.ThereIsFilterByProductsAndServices
	|FROM
	|	ConditionsOfAssignment AS ConditionsOfAssignment";
	
	QueryText = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	Return New Structure("QueryText, TablesCount, ResultTableNumber, TableName", QueryText, 2, 2, "ConditionsOfAssignment");
	
EndFunction

// The function generates query text for table of discounts (markups) values by price groups.
//
// Returns:
// Structure - Query text
//
Function QueryTextDiscountMarkupTableByPriceGroups()
	
	QueryText =
	"SELECT ALLOWED
	|	PriceGroups.Ref AS DiscountMarkup,
	|	PriceGroups.ValueClarification AS ValueClarification,
	|	CASE
	|		WHEN DiscountsMarkups.AssignmentMethod = VALUE(Enum.DiscountsMarkupsProvidingWays.Amount)
	|			THEN PriceGroups.DiscountMarkupValue * ISNULL(CurrencyRatesProvisions.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1) / (ISNULL(CurrencyRatesOfDocument.ExchangeRate, 1) * ISNULL(CurrencyRatesProvisions.Multiplicity, 1))
	|		ELSE PriceGroups.DiscountMarkupValue
	|	END AS DiscountMarkupValue
	|FROM
	|	TemporaryDiscountMarkupTable AS DiscountsMarkups
	|		LEFT JOIN CurrencyRates AS CurrencyRatesProvisions
	|		ON (CurrencyRatesProvisions.Currency = DiscountsMarkups.AssignmentCurrency)
	|		LEFT JOIN CurrencyRates AS CurrencyRatesOfDocument
	|		ON (CurrencyRatesOfDocument.Currency = &DocumentCurrency)
	|		INNER JOIN Catalog.AutomaticDiscounts.ProductsAndServicesGroupsPriceGroups AS PriceGroups
	|		ON DiscountsMarkups.Ref = PriceGroups.Ref
	|			AND (PriceGroups.Ref.IsClarificationByPriceGroups)
	|WHERE
	|	PriceGroups.Ref.RestrictionByProductsAndServicesVariant = VALUE(Enum.DiscountRestrictionVariantsByProductsAndServices.ByPriceGroups)";
	
	QueryText = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	Return New Structure("QueryText, TablesCount, ResultTableNumber, TableName", QueryText, 1, 1, "DiscountsMarkupsByPriceGroups");
	
EndFunction // QueryTextDiscountsMarkupsValueTableByPriceGroups()

// The function generates a text of query for the table of discount (markup) values by products and services groups.
//
// Returns:
// Structure - Query text
//
Function QueryTextDiscountsMarkupsTableByProductsAndServicesGroups()
	
	QueryText =
	"SELECT ALLOWED
	|	ProductsAndServicesCategories.Ref AS DiscountMarkup,
	|	ProductsAndServicesCategories.ValueClarification AS ValueClarification,
	|	CASE
	|		WHEN DiscountsMarkups.AssignmentMethod = VALUE(Enum.DiscountsMarkupsProvidingWays.Amount)
	|			THEN ProductsAndServicesCategories.DiscountMarkupValue * ISNULL(CurrencyRatesProvisions.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1) / (ISNULL(CurrencyRatesOfDocument.ExchangeRate, 1) * ISNULL(CurrencyRatesProvisions.Multiplicity, 1))
	|		ELSE ProductsAndServicesCategories.DiscountMarkupValue
	|	END AS DiscountMarkupValue
	|FROM
	|	TemporaryDiscountMarkupTable AS DiscountsMarkups
	|		LEFT JOIN CurrencyRates AS CurrencyRatesProvisions
	|		ON (CurrencyRatesProvisions.Currency = DiscountsMarkups.AssignmentCurrency)
	|		LEFT JOIN CurrencyRates AS CurrencyRatesOfDocument
	|		ON (CurrencyRatesOfDocument.Currency = &DocumentCurrency)
	|		INNER JOIN Catalog.AutomaticDiscounts.ProductsAndServicesGroupsPriceGroups AS ProductsAndServicesCategories
	|		ON DiscountsMarkups.Ref = ProductsAndServicesCategories.Ref
	|			AND (ProductsAndServicesCategories.Ref.IsClarificationByProductsAndServicesCategories)
	|WHERE
	|	ProductsAndServicesCategories.Ref.RestrictionByProductsAndServicesVariant = VALUE(Enum.DiscountRestrictionVariantsByProductsAndServices.ByProductsAndServicesCategories)";
	
	QueryText = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	Return New Structure("QueryText, TablesCount, ResultTableNumber, TableName", QueryText, 1, 1, "DiscountsMarkupsByProductsAndServicesGroups");
	
EndFunction // QueryTextDiscountsMarkupsValueTableByPriceGroups()

// The function generates text of the query for the table of discounts (markups) values by products and services.
//
// Returns:
// Structure - Query text
//
Function QueryTextTableDiscountsMarkupsByProductsAndServices()
	
	QueryText =
	"SELECT ALLOWED
	|	ProductsAndServices.Ref AS DiscountMarkup,
	|	ProductsAndServices.ValueClarification AS ValueClarification,
	|	CASE
	|		WHEN DiscountsMarkups.AssignmentMethod = VALUE(Enum.DiscountsMarkupsProvidingWays.Amount)
	|			THEN ProductsAndServices.DiscountMarkupValue * ISNULL(CurrencyRatesProvisions.ExchangeRate, 1) * ISNULL(CurrencyRatesOfDocument.Multiplicity, 1) / (ISNULL(CurrencyRatesOfDocument.ExchangeRate, 1) * ISNULL(CurrencyRatesProvisions.Multiplicity, 1))
	|		ELSE ProductsAndServices.DiscountMarkupValue
	|	END AS DiscountMarkupValue,
	|	ProductsAndServices.ValueClarification.IsFolder AS IsFolder,
	|	ProductsAndServices.Characteristic
	|FROM
	|	TemporaryDiscountMarkupTable AS DiscountsMarkups
	|		LEFT JOIN CurrencyRates AS CurrencyRatesProvisions
	|		ON (CurrencyRatesProvisions.Currency = DiscountsMarkups.AssignmentCurrency)
	|		LEFT JOIN CurrencyRates AS CurrencyRatesOfDocument
	|		ON (CurrencyRatesOfDocument.Currency = &DocumentCurrency)
	|		INNER JOIN Catalog.AutomaticDiscounts.ProductsAndServicesGroupsPriceGroups AS ProductsAndServices
	|		ON DiscountsMarkups.Ref = ProductsAndServices.Ref
	|			AND (ProductsAndServices.Ref.IsClarificationByProductsAndServices)
	|WHERE
	|	ProductsAndServices.Ref.RestrictionByProductsAndServicesVariant = VALUE(Enum.DiscountRestrictionVariantsByProductsAndServices.ByProductsAndServices)";
	
	QueryText = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	Return New Structure("QueryText, TablesCount, ResultTableNumber, TableName", QueryText, 1, 1, "DiscountsMarkupsByProductsAndServices");
	
EndFunction // QueryTextDiscountsMarkupsValueTableByPriceGroups()

#EndRegion

#Region RequestPartsByDiscountsAssignmentCondition

// The function generates parameter name by the link to provision condition.
//
// Returns:
// String - ParameterName
//
Function GetQueryParameterFromRef(RefOnAssignmentCondition)
	
	Return StrReplace("P"+RefOnAssignmentCondition.UUID(), "-", "_");
	
EndFunction // GetQueryParameterFromRef()

// The function generates text of query to search discounts for a one-time sale which fit to the condition of provision.
//
// Returns:
// String - Query text
//
Function QueryTextDiscountForOneTimeSaleWithConditionByLine(QueryBatch, RefOnAssignmentCondition)
	
	QueryText =
	"SELECT
	|	DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.ProductsAndServices AS ProductsAndServices
	|INTO SalesByProductsAndServicesFilterGroups
	|FROM
	|	Catalog.DiscountsMarkupsProvidingConditions.SalesFilterByProductsAndServices AS DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices
	|WHERE
	|	DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.Ref = &ParameterName
	|	AND DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.ProductsAndServices.IsFolder
	|
	|INDEX BY
	|	ProductsAndServices
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.ProductsAndServices AS ProductsAndServices,
	|	DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.Characteristic
	|INTO SalesFilterByProductsAndServices
	|FROM
	|	Catalog.DiscountsMarkupsProvidingConditions.SalesFilterByProductsAndServices AS DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices
	|WHERE
	|	DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.Ref = &ParameterName
	|	AND Not DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.ProductsAndServices.IsFolder
	|	AND DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.Characteristic = VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|
	|INDEX BY
	|	ProductsAndServices
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.ProductsAndServices AS ProductsAndServices,
	|	DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.Characteristic AS Characteristic
	|INTO FilterSalesByProductsAndServicesWithCharacteristics
	|FROM
	|	Catalog.DiscountsMarkupsProvidingConditions.SalesFilterByProductsAndServices AS DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices
	|WHERE
	|	DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.Ref = &ParameterName
	|	AND Not DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.ProductsAndServices.IsFolder
	|	AND DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.Characteristic <> VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|
	|INDEX BY
	|	ProductsAndServices,
	|	Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	ConditionsOfAssignment.Ref AS Ref,
	|	Products.ConnectionKey AS ConnectionKey
	|FROM
	|	ConditionsOfAssignment AS ConditionsOfAssignment
	|		INNER JOIN TemporaryTableProducts AS Products
	|		ON (ConditionsOfAssignment.Ref = &ParameterName)
	|WHERE
	|	CASE
	|			WHEN ConditionsOfAssignment.UseRestrictionCriterionForSalesVolume = VALUE(Enum.DiscountMarkupUseLimitCriteriaForSalesVolume.Amount)
	|				THEN CASE
	|						WHEN ConditionsOfAssignment.ComparisonType = VALUE(Enum.DiscountMarkupValuesComparisonTypes.GreaterOrEqual)
	|							THEN Products.Amount >= ConditionsOfAssignment.RestrictionConditionValue
	|						WHEN ConditionsOfAssignment.ComparisonType = VALUE(Enum.DiscountMarkupValuesComparisonTypes.Greater)
	|							THEN Products.Amount > ConditionsOfAssignment.RestrictionConditionValue
	|						WHEN ConditionsOfAssignment.ComparisonType = VALUE(Enum.DiscountMarkupValuesComparisonTypes.LessOrEqual)
	|							THEN Products.Amount <= ConditionsOfAssignment.RestrictionConditionValue
	|						ELSE Products.Amount < ConditionsOfAssignment.RestrictionConditionValue
	|					END
	|			WHEN ConditionsOfAssignment.UseRestrictionCriterionForSalesVolume = VALUE(Enum.DiscountMarkupUseLimitCriteriaForSalesVolume.Quantity)
	|				THEN CASE
	|						WHEN ConditionsOfAssignment.ComparisonType = VALUE(Enum.DiscountMarkupValuesComparisonTypes.GreaterOrEqual)
	|							THEN Products.Quantity >= ConditionsOfAssignment.RestrictionConditionValue
	|						WHEN ConditionsOfAssignment.ComparisonType = VALUE(Enum.DiscountMarkupValuesComparisonTypes.Greater)
	|							THEN Products.Quantity > ConditionsOfAssignment.RestrictionConditionValue
	|						WHEN ConditionsOfAssignment.ComparisonType = VALUE(Enum.DiscountMarkupValuesComparisonTypes.LessOrEqual)
	|							THEN Products.Quantity <= ConditionsOfAssignment.RestrictionConditionValue
	|						ELSE Products.Quantity < ConditionsOfAssignment.RestrictionConditionValue
	|					END
	|			ELSE FALSE
	|		END
	|	AND (NOT ConditionsOfAssignment.ThereIsFilterByProductsAndServices
	|			OR Products.ProductsAndServices IN HIERARCHY
	|				(SELECT DISTINCT
	|					SalesByProductsAndServicesFilterGroups.ProductsAndServices
	|				FROM
	|					SalesByProductsAndServicesFilterGroups AS SalesByProductsAndServicesFilterGroups)
	|			OR Products.ProductsAndServices IN
	|				(SELECT DISTINCT
	|					SalesFilterByProductsAndServices.ProductsAndServices
	|				FROM
	|					SalesFilterByProductsAndServices AS SalesFilterByProductsAndServices)
	|			OR (Products.ProductsAndServices, Products.Characteristic) IN
	|				(SELECT DISTINCT
	|					FilterSalesByProductsAndServicesWithCharacteristics.ProductsAndServices,
	|					FilterSalesByProductsAndServicesWithCharacteristics.Characteristic
	|				FROM
	|					FilterSalesByProductsAndServicesWithCharacteristics AS FilterSalesByProductsAndServicesWithCharacteristics))
	|
	|ORDER BY
	|	Ref,
	|	ConnectionKey
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP SalesFilterByProductsAndServices
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP SalesByProductsAndServicesFilterGroups
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP FilterSalesByProductsAndServicesWithCharacteristics";
	
	ParameterName = GetQueryParameterFromRef(RefOnAssignmentCondition);
	QueryText = StrReplace(QueryText, "ParameterName", ParameterName);
	QueryBatch.Query.SetParameter(ParameterName, RefOnAssignmentCondition);
	
	QueryText = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	Return New Structure(
		"QueryText,
		|TablesCount,
		|ResultTableNumber,
		|TableName",
		QueryText,
		7,
		4,
		"DiscountForOneTimeSaleWithConditionByLine" + ParameterName
	);
	
EndFunction // QueryTextDiscountForOneTimeSaleWithConditionByLine

// The function generates text of a query for the table of calculated discounts for one-time sale.
//
// Returns:
// String - Query text
//
Function QueryTextDiscountForOneTimeSaleWithConditionByDocument(QueryBatch, RefOnAssignmentCondition)

	QueryText =
	"SELECT
	|	DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.ProductsAndServices AS ProductsAndServices
	|INTO SalesByProductsAndServicesFilterGroups
	|FROM
	|	Catalog.DiscountsMarkupsProvidingConditions.SalesFilterByProductsAndServices AS DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices
	|WHERE
	|	DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.Ref = &ParameterName
	|	AND DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.ProductsAndServices.IsFolder
	|
	|INDEX BY
	|	ProductsAndServices
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.ProductsAndServices AS ProductsAndServices,
	|	DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.Characteristic
	|INTO SalesFilterByProductsAndServices
	|FROM
	|	Catalog.DiscountsMarkupsProvidingConditions.SalesFilterByProductsAndServices AS DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices
	|WHERE
	|	DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.Ref = &ParameterName
	|	AND Not DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.ProductsAndServices.IsFolder
	|	AND DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.Characteristic = VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|
	|INDEX BY
	|	ProductsAndServices
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.ProductsAndServices AS ProductsAndServices,
	|	DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.Characteristic AS Characteristic
	|INTO FilterSalesByProductsAndServicesWithCharacteristics
	|FROM
	|	Catalog.DiscountsMarkupsProvidingConditions.SalesFilterByProductsAndServices AS DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices
	|WHERE
	|	DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.Ref = &ParameterName
	|	AND Not DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.ProductsAndServices.IsFolder
	|	AND DiscountsMarkupsProvidingConditionsSalesFilterByProductsAndServices.Characteristic <> VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|
	|INDEX BY
	|	ProductsAndServices,
	|	Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ConditionsOfAssignment.Ref,
	|	ConditionsOfAssignment.UseRestrictionCriterionForSalesVolume,
	|	ConditionsOfAssignment.ComparisonType,
	|	ConditionsOfAssignment.RestrictionConditionValue,
	|	SUM(Products.Quantity) AS Quantity,
	|	SUM(Products.Amount) AS Amount
	|INTO ResultsByDocument
	|FROM
	|	ConditionsOfAssignment AS ConditionsOfAssignment
	|		INNER JOIN TemporaryTableProducts AS Products
	|		ON (ConditionsOfAssignment.Ref = &ParameterName)
	|			AND (NOT ConditionsOfAssignment.ThereIsFilterByProductsAndServices
	|				OR Products.ProductsAndServices IN HIERARCHY
	|					(SELECT DISTINCT
	|						SalesByProductsAndServicesFilterGroups.ProductsAndServices
	|					FROM
	|						SalesByProductsAndServicesFilterGroups AS SalesByProductsAndServicesFilterGroups)
	|				OR Products.ProductsAndServices IN
	|					(SELECT DISTINCT
	|						SalesFilterByProductsAndServices.ProductsAndServices
	|					FROM
	|						SalesFilterByProductsAndServices AS SalesFilterByProductsAndServices)
	|				OR (Products.ProductsAndServices, Products.Characteristic) IN
	|					(SELECT DISTINCT
	|						FilterSalesByProductsAndServicesWithCharacteristics.ProductsAndServices,
	|						FilterSalesByProductsAndServicesWithCharacteristics.Characteristic
	|					FROM
	|						FilterSalesByProductsAndServicesWithCharacteristics AS FilterSalesByProductsAndServicesWithCharacteristics))
	|
	|GROUP BY
	|	ConditionsOfAssignment.UseRestrictionCriterionForSalesVolume,
	|	ConditionsOfAssignment.Ref,
	|	ConditionsOfAssignment.RestrictionConditionValue,
	|	ConditionsOfAssignment.ComparisonType
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	ResultsByDocument.Ref AS Ref,
	|	-1 AS ConnectionKey
	|FROM
	|	ResultsByDocument AS ResultsByDocument
	|WHERE
	|	CASE
	|			WHEN ResultsByDocument.UseRestrictionCriterionForSalesVolume = VALUE(Enum.DiscountMarkupUseLimitCriteriaForSalesVolume.Amount)
	|				THEN CASE
	|						WHEN ResultsByDocument.ComparisonType = VALUE(Enum.DiscountMarkupValuesComparisonTypes.GreaterOrEqual)
	|							THEN ResultsByDocument.Amount >= ResultsByDocument.RestrictionConditionValue
	|						WHEN ResultsByDocument.ComparisonType = VALUE(Enum.DiscountMarkupValuesComparisonTypes.Greater)
	|							THEN ResultsByDocument.Amount > ResultsByDocument.RestrictionConditionValue
	|						WHEN ResultsByDocument.ComparisonType = VALUE(Enum.DiscountMarkupValuesComparisonTypes.LessOrEqual)
	|							THEN ResultsByDocument.Amount <= ResultsByDocument.RestrictionConditionValue
	|						ELSE ResultsByDocument.Amount < ResultsByDocument.RestrictionConditionValue
	|					END
	|			WHEN ResultsByDocument.UseRestrictionCriterionForSalesVolume = VALUE(Enum.DiscountMarkupUseLimitCriteriaForSalesVolume.Quantity)
	|				THEN CASE
	|						WHEN ResultsByDocument.ComparisonType = VALUE(Enum.DiscountMarkupValuesComparisonTypes.GreaterOrEqual)
	|							THEN ResultsByDocument.Quantity >= ResultsByDocument.RestrictionConditionValue
	|						WHEN ResultsByDocument.ComparisonType = VALUE(Enum.DiscountMarkupValuesComparisonTypes.Greater)
	|							THEN ResultsByDocument.Quantity > ResultsByDocument.RestrictionConditionValue
	|						WHEN ResultsByDocument.ComparisonType = VALUE(Enum.DiscountMarkupValuesComparisonTypes.LessOrEqual)
	|							THEN ResultsByDocument.Quantity <= ResultsByDocument.RestrictionConditionValue
	|						ELSE ResultsByDocument.Quantity < ResultsByDocument.RestrictionConditionValue
	|					END
	|			ELSE FALSE
	|		END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP ResultsByDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP SalesByProductsAndServicesFilterGroups
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP SalesFilterByProductsAndServices
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP FilterSalesByProductsAndServicesWithCharacteristics";
	
	ParameterName = GetQueryParameterFromRef(RefOnAssignmentCondition);
	QueryText = StrReplace(QueryText, "ParameterName", ParameterName);
	QueryBatch.Query.SetParameter(ParameterName, RefOnAssignmentCondition);
	
	QueryText = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	Return New Structure(
		"QueryText,
		|TablesCount,
		|ResultTableNumber,
		|TableName",
		QueryText,
		9,
		5,
		"DiscountForOneTimeSaleWithConditionByDocument" + ParameterName
	);
	
EndFunction // QueryTextDiscountForOneTimeSaleWithConditionByDocument

// The function generates a text of query for the products table by segments.
//
// Returns:
// Structure - Query text
//
Function QueryTextTableProducts() 
	
	QueryText =
	"SELECT ALLOWED
	|	Products.ConnectionKey AS ConnectionKey,
	|	CAST(Products.ProductsAndServices AS Catalog.ProductsAndServices) AS ProductsAndServices,
	|	Products.Characteristic AS Characteristic,
	|	Products.MeasurementUnit AS MeasurementUnit,
	|	Products.Quantity AS Quantity,
	|	Products.Price AS PricePerPack,
	|	Products.Quantity * Products.Price AS Amount
	|INTO TemporaryTableProducts
	|FROM
	|	&Products AS Products
	|
	|INDEX BY
	|	ProductsAndServices,
	|	Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableProducts.ConnectionKey,
	|	TemporaryTableProducts.ProductsAndServices,
	|	TemporaryTableProducts.Characteristic,
	|	TemporaryTableProducts.MeasurementUnit,
	|	TemporaryTableProducts.Quantity,
	|	TemporaryTableProducts.PricePerPack,
	|	TemporaryTableProducts.Amount,
	|	TemporaryTableProducts.ProductsAndServices.PriceGroup AS PriceGroup,
	|	TemporaryTableProducts.ProductsAndServices.ProductsAndServicesCategory AS ProductsAndServicesCategory
	|FROM
	|	TemporaryTableProducts AS TemporaryTableProducts";
	
	
	QueryText = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	Return New Structure("QueryText, TablesCount, ResultTableNumber, TableName", QueryText, 2, 2, "Products");
	
EndFunction // QueryTextTableProducts()

// The function generates text of a query for the table of calculated discounts for one-time sale.
//
// Returns:
// String - Query text
//
Function QueryTextDiscountForPurchaseKit(QueryBatch, RefOnAssignmentCondition)

	QueryText =
	"SELECT
	|	Products.ProductsAndServices AS ProductsAndServices,
	|	Products.Characteristic AS Characteristic,
	|	SUM(Products.Quantity) AS Quantity
	|INTO GoodsQuantity
	|FROM
	|	TemporaryTableProducts AS Products
	|
	|GROUP BY
	|	Products.ProductsAndServices,
	|	Products.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DiscountsMarkupsProvidingConditionsPurchaseKit.ProductsAndServices,
	|	DiscountsMarkupsProvidingConditionsPurchaseKit.Characteristic,
	|	SUM(DiscountsMarkupsProvidingConditionsPurchaseKit.Quantity) AS Quantity
	|INTO PurchaseKit
	|FROM
	|	Catalog.DiscountsMarkupsProvidingConditions.PurchaseKit AS DiscountsMarkupsProvidingConditionsPurchaseKit
	|WHERE
	|	DiscountsMarkupsProvidingConditionsPurchaseKit.Ref = &ParameterName
	|
	|GROUP BY
	|	DiscountsMarkupsProvidingConditionsPurchaseKit.ProductsAndServices,
	|	DiscountsMarkupsProvidingConditionsPurchaseKit.Characteristic
	|
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseKit.ProductsAndServices,
	|	PurchaseKit.Characteristic,
	|	CASE
	|		WHEN ISNULL(GoodsQuantity.Quantity, 0) = 0
	|				OR ISNULL(PurchaseKit.Quantity, 0) = 0
	|			THEN 0
	|		ELSE CASE
	|				WHEN (CAST(GoodsQuantity.Quantity / PurchaseKit.Quantity AS NUMBER(15, 0))) = (CAST(GoodsQuantity.Quantity / PurchaseKit.Quantity AS NUMBER(15, 3)))
	|					THEN CAST(GoodsQuantity.Quantity / PurchaseKit.Quantity AS NUMBER(15, 0))
	|				ELSE CASE
	|						WHEN (CAST(GoodsQuantity.Quantity / PurchaseKit.Quantity AS NUMBER(15, 0))) * PurchaseKit.Quantity - GoodsQuantity.Quantity >= 0
	|							THEN (CAST(GoodsQuantity.Quantity / PurchaseKit.Quantity AS NUMBER(15, 0))) - 1
	|						ELSE CAST(GoodsQuantity.Quantity / PurchaseKit.Quantity AS NUMBER(15, 0))
	|					END
	|			END
	|	END AS SetsNumber
	|INTO SetsTable
	|FROM
	|	PurchaseKit AS PurchaseKit
	|		LEFT JOIN GoodsQuantity AS GoodsQuantity
	|		ON PurchaseKit.ProductsAndServices = GoodsQuantity.ProductsAndServices
	|			AND PurchaseKit.Characteristic = GoodsQuantity.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(SetsTable.SetsNumber) AS SetsNumber,
	|	-1 AS ConnectionKey,
	|	&ParameterName AS Ref
	|INTO MinimumSetsNumberTable
	|FROM
	|	SetsTable AS SetsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MinimumSetsNumberTable.SetsNumber AS SetsNumber,
	|	MinimumSetsNumberTable.ConnectionKey AS ConnectionKey,
	|	MinimumSetsNumberTable.Ref AS Ref
	|FROM
	|	MinimumSetsNumberTable AS MinimumSetsNumberTable
	|WHERE
	|	MinimumSetsNumberTable.SetsNumber >= 1
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP GoodsQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP PurchaseKit
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP SetsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP MinimumSetsNumberTable";
	
	ParameterName = GetQueryParameterFromRef(RefOnAssignmentCondition);
	QueryText = StrReplace(QueryText, "ParameterName", ParameterName);
	QueryBatch.Query.SetParameter(ParameterName, RefOnAssignmentCondition);
	
	QueryText = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	Return New Structure(
		"QueryText,
		|TablesCount,
		|ResultTableNumber,
		|TableName",
		QueryText,
		9,
		5,
		"DiscountForForPurchaseKit" + ParameterName
	);
	
EndFunction // QueryTextDiscountForPurchaseKit

#EndRegion

#Region QueryBatchFunctions

// Function creates a package of queries.
//
// Returns:
// Structure - package of queries.
//
Function QueryBatchCreate()
	
	QueryBatch = New Structure;
	QueryBatch.Insert("CommonTablesCount", 0);
	QueryBatch.Insert("StructureQueryNameAndResultTableNumber", New Structure);
	QueryBatch.Insert("Query", New Query);
	QueryBatch.Insert("QueryResult", Undefined);
	QueryBatch.Insert("QueryNamesArray", New Array);
	
	Return QueryBatch;
	
EndFunction // QueryBatchCreate()

// UniteSubordinateRowsDataTables adds a query to a package of queries.
//
// Returns:
// No
//
Procedure QueryBatchInsertQueryIntoPackage(QueryParameters, QueryBatch, Add = False)
	
	// Check for queries duplicate.
	If QueryBatch.QueryNamesArray.Find(QueryParameters.TableName) <> Undefined Then
		Return;
	EndIf;
	
	QueryBatch.CommonTablesCount = QueryBatch.CommonTablesCount + QueryParameters.TablesCount;
	SpreadsheetNumber = QueryBatch.CommonTablesCount - QueryParameters.TablesCount + QueryParameters.ResultTableNumber;
	QueryBatch.Query.Text = QueryBatch.Query.Text +
	"// Result table number: "+SpreadsheetNumber + "
	|";
	QueryBatch.Query.Text = QueryBatch.Query.Text + QueryParameters.QueryText;
	
	If Add Then
		
		QueryBatch.StructureQueryNameAndResultTableNumber.Insert(QueryParameters.TableName, SpreadsheetNumber);
		
	EndIf;
	
	QueryBatch.QueryNamesArray.Add(QueryParameters.TableName);
	
EndProcedure // QueryBatchInsertQueryIntoPackage()

// The function executes a package of queries.
//
// Returns:
// Boolean - True if the request was completed successfully.
//
Function QueryBatchExecute(QueryBatch)
	
	If ValueIsFilled(QueryBatch.Query.Text) Then
		QueryBatch.QueryResult = QueryBatch.Query.ExecuteBatch();
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction // QueryBatchExecute()

// The function gets the query result from queries package by query name.
//
// Returns:
// QueryResult - Result of the query included in the package.
//
Function QueryBatchGetQueryResultByTableName(QueryName, QueryBatch)
	
	Return QueryBatch.QueryResult[QueryBatch.StructureQueryNameAndResultTableNumber[QueryName] - 1];
	
EndFunction // QueryBatchGetQueryResultByTableName()

// The function unites all results of package queries in one table.
//
// Returns:
// QueryResult - Result of the query included in the package.
//
Function QueryBatchUniteResults(QueryBatch)
	
	VT = New ValueTable;
	VT.Columns.Add("Ref", New TypeDescription("CatalogRef.DiscountsMarkupsProvidingConditions"));
	VT.Columns.Add("ConnectionKey", New TypeDescription("Number"));
	VT.Columns.Add("SetsNumber", New TypeDescription("Number"));
	
	For Each KeyAndValue IN QueryBatch.StructureQueryNameAndResultTableNumber Do
		
		Selection = QueryBatch.QueryResult[KeyAndValue.Value-1].Select();
		While Selection.Next() Do
			FillPropertyValues(VT.Add(), Selection);
		EndDo;
		
	EndDo;
	
	Return VT;
	
EndFunction // QueryBatchUniteResults()

#EndRegion

#Region DiscountsMarkupsCalculationFunctionsByDiscountsMarkupsTree

Procedure ProcessDiscountsTree(DiscountsTree)
	
	For Each TreeRow IN DiscountsTree.Rows Do
		
		If TreeRow.IsFolder Then
			
			ProcessDiscountsTree(TreeRow);
			
		Else
			
			LineCount = TreeRow.Rows.Count();
			If LineCount > 1 Then
				Raise NStr("en='An error occurred while generating discount tree';ru='Ошибка генерации дерева скидок'");
			EndIf;
			If LineCount > 0 Then
				FillPropertyValues(TreeRow, TreeRow.Rows[0]);
				//
				TreeRow.Rows.Delete(TreeRow.Rows[0]);
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// The function gets the tree of applied discounts.
//
// Returns:
// ValueTree - tree of applied discounts.
//
Function GetDiscountsTree(DiscountsArray) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	DiscountsMarkups.Ref                       AS DiscountMarkup,
	|	DiscountsMarkups.AdditionalOrderingAttribute    AS AdditionalOrderingAttribute,
	|	DiscountsMarkups.SharedUsageVariant AS SharedUsageVariant,
	|	DiscountsMarkups.RestrictionByProductsAndServicesVariant AS RestrictionByProductsAndServicesVariant,
	|	DiscountsMarkups.IsClarificationByProductsAndServices AS IsClarificationByProductsAndServices,
	|	DiscountsMarkups.IsClarificationByProductsAndServicesCategories AS IsClarificationByProductsAndServicesCategories,
	|	DiscountsMarkups.IsClarificationByPriceGroups AS IsClarificationByPriceGroups,
	|	DiscountsMarkups.ThereAreFoldersToBeClarifiedByProductsAndServices AS ThereAreFoldersToBeClarifiedByProductsAndServices,
	|
	// Required for display icons
	|	DiscountsMarkups.DeletionMark              AS DeletionMark,
	|	DiscountsMarkups.AssignmentMethod         AS AssignmentMethod,
	|	DiscountsMarkups.DiscountMarkupValue        AS DiscountMarkupValue,
	|	
	|	DiscountsMarkups.IsFolder                    AS IsFolder,
	|	
	|	DiscountsMarkups.ConditionsOfAssignment.(
	|		AssignmentCondition                    AS AssignmentCondition,
	|		AssignmentCondition.RestrictionArea AS RestrictionArea
	|	) AS ConditionsOfAssignment
	|FROM
	|	Catalog.AutomaticDiscounts AS DiscountsMarkups
	|WHERE
	|	DiscountsMarkups.Ref IN(&DiscountsArray)
	|	AND DiscountsMarkups.Acts
	|
	|ORDER BY
	|	DiscountsMarkups.AdditionalOrderingAttribute
	|Totals BY
	|	DiscountMarkup HIERARCHY";
	
	Query.SetParameter("DiscountsArray", DiscountsArray);
	Query.SetParameter("SharedUsageVariant", Constants.DiscountsMarkupsSharedUsageOptions.Get());
	
	DiscountsTree = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
	
	ProcessDiscountsTree(DiscountsTree);
	
	Return DiscountsTree;
	
EndFunction // GetDiscountsTree()

// The procedure calculates the discount by the shared usage group.
//
// Returns:
// No.
//
Procedure CalculateDiscountsByJointApplicationGroup(TreeRow, Parameters, TopLevel = False, FinalDataTable = Undefined)
	
	DataTable = UniteSubordinateRowsDataTables(TreeRow);
	
	Addition = False;
	If TopLevel Then
		SharedUsageVariant = Constants.DiscountsMarkupsSharedUsageOptions.Get();
	Else 
		// This option is required if during implementation it will be necessary to adjust the mechanism to indicate the shared usage option in groups.
		SharedUsageVariant = TreeRow.SharedUsageVariant;
	EndIf;
	
	If SharedUsageVariant = Enums.DiscountsMarkupsSharedUsageOptions.Exclusion Then
		DataTable.Sort("ConnectionKey, AdditionalOrderingAttribute");
	ElsIf SharedUsageVariant = Enums.DiscountsMarkupsSharedUsageOptions.Max Then
		DataTable.Sort("ConnectionKey, Amount Desc, AdditionalOrderingAttribute");
	ElsIf SharedUsageVariant = Enums.DiscountsMarkupsSharedUsageOptions.Minimum Then
		DataTable.Sort("ConnectionKey, Amount Asc, AdditionalOrderingAttribute");
	ElsIf SharedUsageVariant = Enums.DiscountsMarkupsSharedUsageOptions.Addition
		OR SharedUsageVariant = Enums.DiscountsMarkupsSharedUsageOptions.Multiplication Then
		DataTable.Sort("ConnectionKey");
		Addition = True;
	Else
		DataTable.Sort("ConnectionKey");
		Addition = True;
	EndIf;
	
	VT = GetEmptyDiscountsTableWithDetails(Parameters);
	
	ConnectionKey = -1;
	For Each TableRow IN DataTable Do
		
		If TableRow.ConnectionKey <> ConnectionKey Then
			
			NewRowVT = VT.Add();
			NewRowVT.ConnectionKey = TableRow.ConnectionKey;
			NewRowVT.Amount = TableRow.Amount;
			NewRowVT.Acts = True;
			
			// Discount details.
			NewRowVT.Details = Parameters.EmptyTableDecryption.CopyColumns();
			For Each RowOfDetails IN TableRow.Details Do
				FillPropertyValues(NewRowVT.Details.Add(), RowOfDetails);
			EndDo;
			
			ConnectionKey = TableRow.ConnectionKey;
			
		Else
			
			If Addition Then
				NewRowVT.Amount = NewRowVT.Amount + TableRow.Amount;
				For Each RowOfDetails IN TableRow.Details Do
					FillPropertyValues(NewRowVT.Details.Add(), RowOfDetails);
				EndDo;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If TopLevel Then
		FinalDataTable = VT;
	Else
		TreeRow.DataTable = VT;
	EndIf;
	
EndProcedure // CalculateDiscountsByJointApplicationGroup()

// The procedure calculates the discount of the discount tree.
//
// Returns:
// No.
//
Procedure CalculateDiscount(TreeRow, Parameters)
	
	If Not TreeRow.ConditionsParameters.ConditionsFulfilled Then
		Return;
	EndIf;
	
	DiscountParameters = Parameters.DiscountsMarkups.Find(TreeRow.DiscountMarkup, "DiscountMarkup");
	
	Products = TreeRow.ProductsTable;
	
	DiscountsMarkupsByPriceGroups = Parameters.DiscountsMarkupsByPriceGroups.FindRows(New Structure("DiscountMarkup", TreeRow.DiscountMarkup));
	DiscountsMarkupsByProductsAndServicesGroups = Parameters.DiscountsMarkupsByProductsAndServicesGroups.FindRows(New Structure("DiscountMarkup", TreeRow.DiscountMarkup));
	DiscountsMarkupsByProductsAndServices = Parameters.DiscountsMarkupsByProductsAndServices.FindRows(New Structure("DiscountMarkup", TreeRow.DiscountMarkup));
	
	If TreeRow.Parent = Undefined Then
		ThisIsMultiplication = Constants.DiscountsMarkupsSharedUsageOptions.Get() = Enums.DiscountsMarkupsSharedUsageOptions.Multiplication;
	Else
		ThisIsMultiplication = TreeRow.Parent.SharedUsageVariant = Enums.DiscountsMarkupsSharedUsageOptions.Multiplication;
	EndIf;
	
	DataTable = GetEmptyDiscountsTableWithDetails(Parameters);
	
	AppliedUnconditionally = TreeRow.ConditionsParameters.ConditionsFulfilled AND TreeRow.ConditionsParameters.TableConditions.Count() = 0;
	
	If DiscountParameters.AssignmentMethod = Enums.DiscountsMarkupsProvidingWays.Percent Then
		
		For Each Product IN Products Do
			
			NewRow           = DataTable.Add();
			NewRow.ConnectionKey = Product.ConnectionKey;
			NewRow.Acts = True;
			
			// If the discount is not valid for the given row - skip.
			If Not AppliedUnconditionally Then
				If TreeRow.ConditionsParameters.TableConditions.FindRows(New Structure("RestrictionArea", Enums.DiscountMarkupRestrictionAreasVariants.AtRow)).Count() > 0 Then
					If TreeRow.ConditionsParameters.LinesCodes.Find(Product.ConnectionKey) = Undefined Then
						NewRow.Acts = False;
					EndIf;
				EndIf;
			EndIf;
			
			Amount = Product.Amount;

			DiscountMarkupValue = DiscountParameters.DiscountMarkupValue;
			
			// Search of discount (markup) values for price group
			If TreeRow.IsClarificationByPriceGroups Then
				For Each TSRow IN DiscountsMarkupsByPriceGroups Do
					If TSRow.ValueClarification = Product.PriceGroup Then
						DiscountMarkupValue = TSRow.DiscountMarkupValue;
						Break;
					EndIf;
				EndDo;
			// Search for discount (markup) value for products and services group
			ElsIf TreeRow.IsClarificationByProductsAndServicesCategories Then
				For Each TSRow IN DiscountsMarkupsByProductsAndServicesGroups Do
					If TSRow.ValueClarification = Product.ProductsAndServicesCategory Then
						DiscountMarkupValue = TSRow.DiscountMarkupValue;
						Break;
					EndIf;
				EndDo;
			// Search of discount (markup) value for products and services
			ElsIf TreeRow.IsClarificationByProductsAndServices Then
				If Not TreeRow.ThereAreFoldersToBeClarifiedByProductsAndServices Then
					If Product.Characteristic.IsEmpty() Then
						For Each TSRow IN DiscountsMarkupsByProductsAndServices Do
							If TSRow.ValueClarification = Product.ProductsAndServices AND TSRow.Characteristic.IsEmpty() Then
								DiscountMarkupValue = TSRow.DiscountMarkupValue;
								Break;
							EndIf;
						EndDo;
					Else
						ThereIsValueForCharacteristic = False;
						ValueForCharacteristics = 0;
						For Each TSRow IN DiscountsMarkupsByProductsAndServices Do
							If TSRow.ValueClarification = Product.ProductsAndServices AND TSRow.Characteristic = Product.Characteristic Then
								DiscountMarkupValue = TSRow.DiscountMarkupValue;
								ThereIsValueForCharacteristic = True;
								ValueForCharacteristics = DiscountMarkupValue;
								Break;
							ElsIf TSRow.ValueClarification = Product.ProductsAndServices AND TSRow.Characteristic.IsEmpty() Then
								DiscountMarkupValue = TSRow.DiscountMarkupValue;
							EndIf;
						EndDo;
						
						If ThereIsValueForCharacteristic Then
							DiscountMarkupValue = ValueForCharacteristics;
						EndIf;
					EndIf;
				Else
					// Search including the hierarchy.
					CurAdjustmentValue = GetClarificationValueIncludingHierarchy(DiscountsMarkupsByProductsAndServices, Product.ProductsAndServices, Product.Characteristic);
					If CurAdjustmentValue <> Undefined Then
						DiscountMarkupValue = CurAdjustmentValue;
					EndIf;
				EndIf;
			EndIf;
		    
			DiscountAmount = Round((DiscountMarkupValue / 100) * Amount, 2);
			
			NewRow.Amount = DiscountAmount;
			
			NewRow.Details = GetDiscountDetails(TreeRow, NewRow.Amount, Parameters);
			
		EndDo;
		
	ElsIf DiscountParameters.AssignmentMethod = Enums.DiscountsMarkupsProvidingWays.Amount Then
		
		DiscountAmountForDistribution = DiscountParameters.DiscountMarkupValue;
		
		If DiscountParameters.AssignmentArea = Enums.DiscountMarkupRestrictionAreasVariants.InDocument Then
			
			// Calculation of segment products total amount.
			SegmentProductsTotalAmount = 0;
			For Each Product IN Products Do
				SegmentProductsTotalAmount = SegmentProductsTotalAmount + Product.Amount;
			EndDo;
			
			DiscountRowForDistribution = Undefined;
			MaximumAmountInDistribution = 0;
			// Distribution of discount by segment products.
			For Each Product IN Products Do
				
				NewRow           = DataTable.Add();
				NewRow.ConnectionKey = Product.ConnectionKey;
				NewRow.Acts = True;
				
				Amount = Product.Amount;
				
				If Amount > MaximumAmountInDistribution Then
					MaximumAmountInDistribution = Amount;
					DiscountRowForDistribution = NewRow;
				EndIf;
				
				If SegmentProductsTotalAmount <> 0 Then
					NewRow.Amount = Round(Amount * (DiscountAmountForDistribution / SegmentProductsTotalAmount), 2);
				Else
					NewRow.Amount = 0;
				EndIf;
				
				DiscountAmountForDistribution = DiscountAmountForDistribution - NewRow.Amount;
				SegmentProductsTotalAmount = SegmentProductsTotalAmount - Amount;

				NewRow.Details = GetDiscountDetails(TreeRow, NewRow.Amount, Parameters);
				
			EndDo;
			
			If DiscountAmountForDistribution <> 0 AND DiscountRowForDistribution <> Undefined Then
				DiscountRowForDistribution.Amount = DiscountRowForDistribution.Amount + DiscountAmountForDistribution;
			EndIf;
			
		ElsIf DiscountParameters.AssignmentArea = Enums.DiscountMarkupRestrictionAreasVariants.AtRow Then
			
			ThereAreConditionsByLine = TreeRow.ConditionsParameters.TableConditions.FindRows(New Structure("RestrictionArea", Enums.DiscountMarkupRestrictionAreasVariants.AtRow)).Count() > 0;
			
			For Each Product IN Products Do
				
				DiscountMarkupValue = DiscountParameters.DiscountMarkupValue;
				
				// Search of discount (markup) values for price group
				If TreeRow.IsClarificationByPriceGroups Then
					For Each TSRow IN DiscountsMarkupsByPriceGroups Do
						If TSRow.ValueClarification = Product.PriceGroup Then
							DiscountMarkupValue = TSRow.DiscountMarkupValue;
							Break;
						EndIf;
					EndDo;
				// Search for discount (markup) value for products and services group
				ElsIf TreeRow.IsClarificationByProductsAndServicesCategories Then
					For Each TSRow IN DiscountsMarkupsByProductsAndServicesGroups Do
						If TSRow.ValueClarification = Product.ProductsAndServicesCategory Then
							DiscountMarkupValue = TSRow.DiscountMarkupValue;
						EndIf;
					EndDo;
				// Search of discount (markup) value for products and services
				ElsIf TreeRow.IsClarificationByProductsAndServices Then
					If Not TreeRow.ThereAreFoldersToBeClarifiedByProductsAndServices Then
						If Product.Characteristic.IsEmpty() Then
							For Each TSRow IN DiscountsMarkupsByProductsAndServices Do
								If TSRow.ValueClarification = Product.ProductsAndServices AND TSRow.Characteristic.IsEmpty() Then
									DiscountMarkupValue = TSRow.DiscountMarkupValue;
									Break;
								EndIf;
							EndDo;
						Else
							ThereIsValueForCharacteristic = False;
							ValueForCharacteristics = 0;
							For Each TSRow IN DiscountsMarkupsByProductsAndServices Do
								If TSRow.ValueClarification = Product.ProductsAndServices AND TSRow.Characteristic = Product.Characteristic Then
									DiscountMarkupValue = TSRow.DiscountMarkupValue;
									ThereIsValueForCharacteristic = True;
									ValueForCharacteristics = DiscountMarkupValue;
									Break;
								ElsIf TSRow.ValueClarification = Product.ProductsAndServices AND TSRow.Characteristic.IsEmpty() Then
									DiscountMarkupValue = TSRow.DiscountMarkupValue;
								EndIf;
							EndDo;
							
							If ThereIsValueForCharacteristic Then
								DiscountMarkupValue = ValueForCharacteristics;
							EndIf;
						EndIf;
					Else
						// Search including the hierarchy.
						CurAdjustmentValue = GetClarificationValueIncludingHierarchy(DiscountsMarkupsByProductsAndServices, Product.ProductsAndServices, Product.Characteristic);
						If CurAdjustmentValue <> Undefined Then
							DiscountMarkupValue = CurAdjustmentValue;
						EndIf;
					EndIf;
				EndIf;
			    				
				NewRow = DataTable.Add();
				
				If Not ThereAreConditionsByLine OR AppliedUnconditionally OR TreeRow.ConditionsParameters.LinesCodes.Find(Product.ConnectionKey) <> Undefined Then
					NewRow.Acts = True;
				EndIf;
				
				NewRow.ConnectionKey   = Product.ConnectionKey;
				NewRow.Amount       = DiscountMarkupValue;
				NewRow.Details = GetDiscountDetails(TreeRow, NewRow.Amount, Parameters);
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
	TreeRow.DataTable   = DataTable;
	
	
EndProcedure // CalculateDiscount()

// The function returns the value (adjustment) of automatic discount (markup) for specified position of products and services with regard to the characteristic and hierarchy
//
Function GetClarificationValueIncludingHierarchy(DiscountsMarkupsByProductsAndServices, ProductsAndServices, Characteristic)
	
	// Example. IN SP Product0 is selected, Product1 (10%), Product2 (20%) and Group1 (15%) are selected in the adjustment.
	// Product0 can be equal to Product1 or Product2 or can be in the hierarchy of Group1.
	
	QueryTextPattern = "SELECT
	                      |	&DiscountMarkupValue AS DiscountMarkupValue
	                      |FROM
	                      |	Catalog.ProductsAndServices AS ProductsAndServices
	                      |WHERE
	                      |	ProductsAndServices.Ref = &Ref
	                      |	AND ProductsAndServices.Ref IN HIERARCHY(&ValueClarification)";

	CtQueries = 0;
	QueryText = "";
	Query = New Query;
	Query.SetParameter("Ref", ProductsAndServices);
	
	ThereIsValueWithoutCharacteristic = False;
	ValueWithoutCharacteristic = 0;
	For Each CurAdjustment IN DiscountsMarkupsByProductsAndServices Do
		If Not CurAdjustment.IsFolder AND Characteristic.IsEmpty() Then
			If CurAdjustment.ValueClarification = ProductsAndServices AND CurAdjustment.Characteristic.IsEmpty() Then
				Return CurAdjustment.DiscountMarkupValue;
			EndIf;
		ElsIf Not CurAdjustment.IsFolder Then
			If CurAdjustment.ValueClarification = ProductsAndServices AND CurAdjustment.Characteristic = Characteristic Then
				Return CurAdjustment.DiscountMarkupValue;
			ElsIf CurAdjustment.ValueClarification = ProductsAndServices AND CurAdjustment.Characteristic.IsEmpty() Then
				ThereIsValueWithoutCharacteristic = True;
				ValueWithoutCharacteristic = CurAdjustment.DiscountMarkupValue;
			EndIf;
		ElsIf CurAdjustment.IsFolder Then
			CtQueries = CtQueries + 1;
			
			TemplateProcessedText = StrReplace(QueryTextPattern, "&ValueClarification", "&ValueClarification"+CtQueries);
			TemplateProcessedText = StrReplace(TemplateProcessedText, "&DiscountMarkupValue", "&DiscountMarkupValue"+CtQueries);
			
			Query.SetParameter("ValueClarification"+CtQueries, CurAdjustment.ValueClarification);
			Query.SetParameter("DiscountMarkupValue"+CtQueries, CurAdjustment.DiscountMarkupValue);
			
			Query.Text = Query.Text + TemplateProcessedText+Chars.LF+"
				|;
				|
				|////////////////////////////////////////////////////////////////////////////////
				|";
		EndIf;
	EndDo;
	
	If ThereIsValueWithoutCharacteristic Then
		Return ValueWithoutCharacteristic;
	EndIf;
	
	If CtQueries > 0 Then
	
		MClarificationResults = Query.ExecuteBatch();
		
		CtQueries = 0;
		While CtQueries < MClarificationResults.Count() Do
			If Not MClarificationResults[CtQueries].IsEmpty() Then
				Return MClarificationResults[CtQueries].Unload()[0].DiscountMarkupValue;
			EndIf;
			CtQueries = CtQueries + 1;
		EndDo;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

// The procedure recursively avoids the
// tree and calculates discounts bottom-up: from subordinate tree item to the parent.
//
// Returns:
// No.
//
Procedure CalculateDiscountsRecursively(DiscountsTree, Parameters)
	
	For Each TreeRow IN DiscountsTree.Rows Do
		
		If TreeRow.Parent = Undefined Then
			// this is the top level
			NQ = New NumberQualifiers(15,2);
			Array = New Array;
			Array.Add(Type("Number"));
			TypeDescriptionNumber = New TypeDescription(Array, , ,NQ);
			TreeRow.ProductsTable = Parameters.Products.Copy();
			//TreeRow.ProductsTable.Columns.Add("DiscountAmount", TypeDescriptionNumber);
		Else
			TreeRow.ProductsTable = TreeRow.Parent.ProductsTable.Copy();
		EndIf;
		
		If TreeRow.IsFolder Then
			
			CalculateDiscountsRecursively(TreeRow, Parameters);
			
			// Discounts by subordinate elements are calculated.
			// Calculation of discounts by shared usage group (parent).
			CalculateDiscountsByJointApplicationGroup(TreeRow, Parameters);
			
			If TreeRow.Parent <> Undefined
				AND TreeRow.Parent.SharedUsageVariant = Enums.DiscountsMarkupsSharedUsageOptions.Multiplication Then
				// You should reduce the amount in the parent row of the products
				// table by the current amount of the discounts as subsequent usage of the groups also assumes that all subsequent discounts will be calculated from the amount with inclusion of already provided discounts of this group
				For Each ParentProductRow IN TreeRow.Parent.ProductsTable Do
					SearchStructure = New Structure;
					SearchStructure.Insert("ConnectionKey", ParentProductRow.ConnectionKey);
					SearchStructure.Insert("Acts", True);
					CalculatedDiscountsRows = TreeRow.DataTable.FindRows(SearchStructure);
					For Each FoundString IN CalculatedDiscountsRows Do
						ParentProductRow.Amount = ParentProductRow.Amount - FoundString.Amount;
						ParentProductRow.DiscountAmount = ParentProductRow.DiscountAmount + FoundString.Amount;
					EndDo;
				EndDo;
			ElsIf TreeRow.Parent = Undefined
				AND Constants.DiscountsMarkupsSharedUsageOptions.Get() = Enums.DiscountsMarkupsSharedUsageOptions.Multiplication Then
				// You should reduce the amount in the parent row of the products
				// table by the current amount of the discounts as consistent application assumes that all
				// subsequent discounts will be calculated from the amount inclusive of already provided discounts of this group
				For Each ParentProductRow IN Parameters.Products Do
					SearchStructure = New Structure;
					SearchStructure.Insert("ConnectionKey", ParentProductRow.ConnectionKey);
					SearchStructure.Insert("Acts", True);
					CalculatedDiscountsRows = TreeRow.DataTable.FindRows(SearchStructure);
					For Each FoundString IN CalculatedDiscountsRows Do
						ParentProductRow.Amount = ParentProductRow.Amount - FoundString.Amount;
						ParentProductRow.DiscountAmount = ParentProductRow.DiscountAmount + FoundString.Amount;
					EndDo;
				EndDo;
			EndIf;
			
		Else
			
			CalculateDiscount(TreeRow, Parameters);
			
			If TreeRow.Parent <> Undefined
				AND TreeRow.Parent.SharedUsageVariant = Enums.DiscountsMarkupsSharedUsageOptions.Multiplication
				AND TreeRow.ConditionsParameters.ConditionsFulfilled Then
				// You should reduce the amount in the parent row of the products
				// table by the current amount of the discounts as consistent application assumes that all
				// subsequent discounts will be calculated from the amount inclusive of already provided discounts of this group
				For Each ParentProductRow IN TreeRow.Parent.ProductsTable Do
					SearchStructure = New Structure;
					SearchStructure.Insert("ConnectionKey", ParentProductRow.ConnectionKey);
					SearchStructure.Insert("Acts", True);
					CalculatedDiscountsRows = TreeRow.DataTable.FindRows(SearchStructure);
					For Each FoundString IN CalculatedDiscountsRows Do
						ParentProductRow.Amount = ParentProductRow.Amount - FoundString.Amount;
						ParentProductRow.DiscountAmount = ParentProductRow.DiscountAmount + FoundString.Amount;
					EndDo;
				EndDo;
			ElsIf TreeRow.Parent = Undefined
				AND Constants.DiscountsMarkupsSharedUsageOptions.Get() = Enums.DiscountsMarkupsSharedUsageOptions.Multiplication
				AND TreeRow.ConditionsParameters.ConditionsFulfilled Then
				// You should reduce the amount in the parent row of the products
				// table by the current amount of the discounts as consistent application assumes that all
				// subsequent discounts will be calculated from the amount inclusive of already provided discounts of this group
				For Each ParentProductRow IN Parameters.Products Do
					SearchStructure = New Structure;
					SearchStructure.Insert("ConnectionKey", ParentProductRow.ConnectionKey);
					SearchStructure.Insert("Acts", True);
					CalculatedDiscountsRows = TreeRow.DataTable.FindRows(SearchStructure);
					For Each FoundString IN CalculatedDiscountsRows Do
						ParentProductRow.Amount = ParentProductRow.Amount - FoundString.Amount;
						ParentProductRow.DiscountAmount = ParentProductRow.DiscountAmount + FoundString.Amount;
					EndDo;
				EndDo;
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure // CalculateDiscountsRecursively()

// The function makes a complete calculation of discounts in the tree.
//
// Returns:
// ValueTable - Table with calculated discounts.
//
Function CalculatedDiscountsStructure(DiscountsTree, Parameters)
	
	ReturnedData = New Structure;
	
	NQ = New NumberQualifiers(15,2);
	Array = New Array;
	Array.Add(Type("Number"));
	TypeDescriptionNumber = New TypeDescription(Array, , ,NQ);
	Parameters.Products.Columns.Add("DiscountAmount", TypeDescriptionNumber);
	CalculateDiscountsRecursively(DiscountsTree, Parameters);
	
	// On top level...
	DataTable = Undefined;
	CalculateDiscountsByJointApplicationGroup(DiscountsTree, Parameters, True, DataTable);
	
	VT = New ValueTable;
	VT.Columns.Add("ConnectionKey",					New TypeDescription("Number"));
	VT.Columns.Add("DiscountMarkup",				New TypeDescription("CatalogRef.AutomaticDiscounts"));
	VT.Columns.Add("Amount",						New TypeDescription("Number"));
	VT.Columns.Add("LimitedByMinimumPrice",	New TypeDescription("Boolean"));
	
	For Each TableRow IN DataTable Do
		If Not TableRow.ConnectionKey = 0  Then
			For Each RowDiscountsMarkups IN TableRow.Details Do
				NewRow								= VT.Add();
				NewRow.ConnectionKey					= TableRow.ConnectionKey;
				NewRow.DiscountMarkup				= RowDiscountsMarkups.DiscountMarkup;
				NewRow.Amount						= RowDiscountsMarkups.Amount;
				NewRow.LimitedByMinimumPrice	= RowDiscountsMarkups.LimitedByMinimumPrice;
			EndDo;
		Else
			For Each RowDiscountsMarkups IN TableRow.Details Do
				SearchStructure = New Structure;
				SearchStructure.Insert("DiscountMarkup", RowDiscountsMarkups.DiscountMarkup);
			EndDo;
		EndIf;
	EndDo;
	
	VT.GroupBy("ConnectionKey, DiscountMarkup, LimitedByMinimumPrice", "Amount");
	
	ReturnedData.Insert("DiscountsTree", 		DiscountsTree);
	ReturnedData.Insert("TableDiscountsMarkups", VT);
	
	Return ReturnedData;
	
EndFunction

#EndRegion

#Region CheckProceduresForDiscountsMarkupsConditions

// The function checks the fullfillment of discount conditions.
//
Function CheckConditions(TreeRow, FullfilledConditions)
	
	TreeRow.ConditionsParameters.Insert("ConditionsFulfilled", True);
	TreeRow.ConditionsParameters.Insert("LinesCodes",        New Array);
	TreeRow.ConditionsParameters.Insert("ConditionsByLine",  New Structure);
	TreeRow.ConditionsParameters.Insert("TableConditions",   New ValueTable);
	
	// Service table for temporary storage of results of provision terms check
	TreeRow.ConditionsParameters.TableConditions.Columns.Add("AssignmentCondition", New TypeDescription("CatalogRef.DiscountsMarkupsProvidingConditions"));
	TreeRow.ConditionsParameters.TableConditions.Columns.Add("RestrictionArea",    New TypeDescription("EnumRef.DiscountMarkupRestrictionAreasVariants"));
	TreeRow.ConditionsParameters.TableConditions.Columns.Add("Completed");
	
	// The table is applied to check fullfillment of the conditions by the line.
	// If a discount has conditions by the line, then a new column will be created in the table for these conditions
	TreeRow.ConditionsParameters.ConditionsByLine.Insert("ConditionsCheckingTable", New ValueTable);
	TreeRow.ConditionsParameters.ConditionsByLine.ConditionsCheckingTable.Columns.Add("ConnectionKey");
	TreeRow.ConditionsParameters.ConditionsByLine.ConditionsCheckingTable.Indexes.Add("ConnectionKey");
	
	TreeRow.ConditionsParameters.ConditionsByLine.Insert("MatchConditionTableColumnsWithConditionsCheckingTable", New Map);
	
	// Service parameters
	ConditionsCheckingTableIsUsed      = False;
	ThisIsFirstConditionForConditionsCheckTable  = True;
	ConditionsCheckTableColumnsNumber = 0;
	
	// We bypass all conditions of one discount.
	For Each Condition IN TreeRow.ConditionsOfAssignment Do
		
		RowConditionsTable = TreeRow.ConditionsParameters.TableConditions.Add();
		RowConditionsTable.AssignmentCondition = Condition.AssignmentCondition;
		RowConditionsTable.RestrictionArea    = Condition.RestrictionArea;
		
		FoundStrings = FullfilledConditions.FindRows(New Structure("Ref", Condition.AssignmentCondition));
		
		If FoundStrings.Count() = 0 Then
			
			// Condition is not completed.
			RowConditionsTable.Completed = False;
			
			TreeRow.ConditionsParameters.ConditionsFulfilled = False;
			
		ElsIf FoundStrings.Count() = 1 AND FoundStrings[0].ConnectionKey = -1 Then
			
			RowConditionsTable.Completed = True;
			// The condition is fullfilled. The condition does not depend on specific lines.
			
		Else
			
			RowConditionsTable.Completed = True;
			// The condition is fullfilled. Several rows were found which passed conditions check.
			
			ConditionsCheckTableColumnsNumber = ConditionsCheckTableColumnsNumber + 1;
			ColumnsTitle = "Condition" + ConditionsCheckTableColumnsNumber;
			
			TreeRow.ConditionsParameters.ConditionsByLine.MatchConditionTableColumnsWithConditionsCheckingTable.Insert(Condition.AssignmentCondition, ColumnsTitle);
			TreeRow.ConditionsParameters.ConditionsByLine.ConditionsCheckingTable.Columns.Add(ColumnsTitle, New TypeDescription("Boolean"));
			
			For Each FoundString IN FoundStrings Do
				
				ConditionsCheckingTableIsUsed = True;
				
				FoundConditionsCheckingTableRows = TreeRow.ConditionsParameters.ConditionsByLine.ConditionsCheckingTable.Find(FoundString.ConnectionKey, "ConnectionKey");
				If FoundConditionsCheckingTableRows <> Undefined Then
					FoundConditionsCheckingTableRows[ColumnsTitle] = True;
				Else
					If ThisIsFirstConditionForConditionsCheckTable Then
						NewRow1 = TreeRow.ConditionsParameters.ConditionsByLine.ConditionsCheckingTable.Add();
						NewRow1.ConnectionKey = FoundString.ConnectionKey;
						NewRow1[ColumnsTitle] = True;
					EndIf;
				EndIf;
				
			EndDo;
			
		EndIf;
		
		If ConditionsCheckingTableIsUsed Then
			ThisIsFirstConditionForConditionsCheckTable = False;
		EndIf;
		
	EndDo;
	
	// We will fill codes lines...
	If TreeRow.ConditionsParameters.ConditionsFulfilled Then
		
		If TreeRow.ConditionsParameters.ConditionsByLine.MatchConditionTableColumnsWithConditionsCheckingTable.Count() > 0 Then
			
			Filter = New Structure;
			For Each KeyAndValue IN TreeRow.ConditionsParameters.ConditionsByLine.MatchConditionTableColumnsWithConditionsCheckingTable Do
				Filter.Insert(KeyAndValue.Value, True);
			EndDo;
			
			FoundStrings = TreeRow.ConditionsParameters.ConditionsByLine.ConditionsCheckingTable.FindRows(Filter);
			For Each VTRow IN FoundStrings Do
				TreeRow.ConditionsParameters.LinesCodes.Add(VTRow.ConnectionKey);
			EndDo;
			
		EndIf;
		
	EndIf;

EndFunction // CheckConditions()

// The function fills service attribultes in rows of discounts tree.
//
Procedure CheckConditionsRecursively(DiscountsTree, FullfilledConditions)
	
	For Each TreeRow IN DiscountsTree.Rows Do
		
		If TreeRow.IsFolder Then
			
			CheckConditionsRecursively(TreeRow, FullfilledConditions);
			
		Else
			
			CheckConditions(TreeRow, FullfilledConditions);
			
		EndIf;
		
	EndDo;
	
EndProcedure // CheckConditionsRecursively()

#EndRegion

#Region ProceduresForDiscountsMarkupsCalculationByDocuments

// The function calculats discounts (markups) by sent parameters.
//
Function CalculateDiscountsMarkupsTree(CalculationParameters, InputParameters) Export
	
	FirstQueryBatch = QueryBatchCreate();
	SecondQueryBatch = QueryBatchCreate();
	
	For Each PackageParameter IN CalculationParameters Do
		FirstQueryBatch.Query.SetParameter(PackageParameter.Key, PackageParameter.Value);
		SecondQueryBatch.Query.SetParameter(PackageParameter.Key, PackageParameter.Value);
	EndDo;
	
	TempTablesManager = New TempTablesManager;
	FirstQueryBatch.Query.TempTablesManager = TempTablesManager;
	SecondQueryBatch.Query.TempTablesManager = TempTablesManager;
	
	// Preparation and execution of the first package.
	QueryBatchInsertQueryIntoPackage(DiscountsMarkupsServerOverridable.QueryTextTableCurrencyRates(),				FirstQueryBatch);
	QueryBatchInsertQueryIntoPackage(QueryTextDiscountsMarkupsTable(InputParameters.OnlyPreliminaryCalculation), 	FirstQueryBatch, True);
	QueryBatchInsertQueryIntoPackage(QueryTextTableAssignmentCondition(),         								FirstQueryBatch, True);
	QueryBatchInsertQueryIntoPackage(QueryTextDiscountMarkupTableByPriceGroups(), 								FirstQueryBatch, True);
	QueryBatchInsertQueryIntoPackage(QueryTextDiscountsMarkupsTableByProductsAndServicesGroups(), 						FirstQueryBatch, True);
	QueryBatchInsertQueryIntoPackage(QueryTextTableDiscountsMarkupsByProductsAndServices(), 						FirstQueryBatch, True);
	QueryBatchInsertQueryIntoPackage(QueryTextTableProducts(),											FirstQueryBatch, True);
	
	QueryBatchExecute(FirstQueryBatch);
	
	// Preparation and execution of the second package.
	// IN the second package values of provision conditions are calculated.
	// A separate package request is formed for each condition of provision.
	SelectionAssignmentConditions = QueryBatchGetQueryResultByTableName("ConditionsOfAssignment", FirstQueryBatch).Select();
	While SelectionAssignmentConditions.Next() Do
		If SelectionAssignmentConditions.AssignmentCondition = Enums.DiscountsMarkupsProvidingConditions.ForOneTimeSalesVolume Then
			If SelectionAssignmentConditions.RestrictionArea = Enums.DiscountMarkupRestrictionAreasVariants.AtRow Then
				QueryParameters = QueryTextDiscountForOneTimeSaleWithConditionByLine(SecondQueryBatch, SelectionAssignmentConditions.Ref);
				QueryBatchInsertQueryIntoPackage(QueryParameters, SecondQueryBatch, True);
			Else
				QueryParameters = QueryTextDiscountForOneTimeSaleWithConditionByDocument(SecondQueryBatch, SelectionAssignmentConditions.Ref);
				QueryBatchInsertQueryIntoPackage(QueryParameters, SecondQueryBatch, True);
			EndIf;
		EndIf;
		
		If SelectionAssignmentConditions.AssignmentCondition = Enums.DiscountsMarkupsProvidingConditions.ForKitPurchase Then
			QueryParameters = QueryTextDiscountForPurchaseKit(SecondQueryBatch, SelectionAssignmentConditions.Ref);
			QueryBatchInsertQueryIntoPackage(QueryParameters, SecondQueryBatch, True);
		EndIf;
	EndDo;
	
	QueryBatchExecute(SecondQueryBatch);
	
	
	TableFullfilledConditions = QueryBatchUniteResults(SecondQueryBatch);
	
	TableDiscountsMarkups      = QueryBatchGetQueryResultByTableName("DiscountsMarkups", FirstQueryBatch).Unload();
	
	DiscountsTree = GetDiscountsTree(TableDiscountsMarkups.UnloadColumn("DiscountMarkup"));
	DiscountsTree.Columns.Add("DataTable"    , New TypeDescription("ValueTable"));
	DiscountsTree.Columns.Add("ProductsTable"	 , New TypeDescription("ValueTable"));
	DiscountsTree.Columns.Add("ConditionsParameters" , New TypeDescription("Structure"));
	
	CheckConditionsRecursively(DiscountsTree, TableFullfilledConditions);
	DiscountsTree.Columns.Delete(DiscountsTree.Columns.ConditionsOfAssignment);
	
	If InputParameters.OnlyPreliminaryCalculation Then
		
		VT = New ValueTable;
		VT.Columns.Add("ConnectionKey",     New TypeDescription("Number"));
		VT.Columns.Add("DiscountMarkup", New TypeDescription("CatalogRef.DiscountsMarkups"));
		VT.Columns.Add("Amount",         New TypeDescription("Number"));
		
		ReturnedData = New Structure;
		ReturnedData.Insert("DiscountsTree", DiscountsTree);
		ReturnedData.Insert("TableDiscountsMarkups", VT);
		
		Return ReturnedData;
		
	EndIf;
	
	
	// Preparation of parameters for discounts calculation.
	Parameters = New Structure;
	// Adjustment of discount amount by price group, products and services group or products and services. By products and services - with account of the hierarchy.
	Parameters.Insert("DiscountsMarkupsByPriceGroups", QueryBatchGetQueryResultByTableName("DiscountsMarkupsByPriceGroups", FirstQueryBatch).Unload());
	Parameters.Insert("DiscountsMarkupsByProductsAndServicesGroups", QueryBatchGetQueryResultByTableName("DiscountsMarkupsByProductsAndServicesGroups", FirstQueryBatch).Unload());
	Parameters.Insert("DiscountsMarkupsByProductsAndServices", QueryBatchGetQueryResultByTableName("DiscountsMarkupsByProductsAndServices", FirstQueryBatch).Unload());
	Parameters.Insert("Products"            , QueryBatchGetQueryResultByTableName("Products"            , FirstQueryBatch).Unload());
	Parameters.Insert("DiscountsMarkups"                , TableDiscountsMarkups);
	
	Details = New ValueTable;
	Details.Columns.Add("DiscountMarkup",				New TypeDescription("CatalogRef.AutomaticDiscounts"));
	Details.Columns.Add("Amount",				        New TypeDescription("Number"));
	Details.Columns.Add("LimitedByMinimumPrice",	New TypeDescription("Boolean"));
	
	// Empty spreadsheets.
	Parameters.Insert("EmptyDiscountsTableWithDetails", Undefined);
	Parameters.Insert("EmptyTableDecryption"        , Details);
	
	Parameters.Insert("CurrentDate", CalculationParameters.CurrentDate);
	
	// Tables indexing
	Parameters.DiscountsMarkups.Indexes.Add("DiscountMarkup");
	
	DiscountsStructure = CalculatedDiscountsStructure(DiscountsTree, Parameters);
	
	Return DiscountsStructure;
	
EndFunction

// The procedure applies the result of discounts (markups) calculation to an object.
// Appears from document forms.
//
Procedure ApplyDiscountCalculationResultToObject(Object, TSName, DiscountsMarkupsCalculationResult, SalesExceedingOrder = False, GoodsBeyondOrder = Undefined, NameSP2 = Undefined) Export
	
	If SalesExceedingOrder AND ValueIsFilled(GoodsBeyondOrder) Then
		For Each CurrentDiscountMarkup IN DiscountsMarkupsCalculationResult Do
			If GoodsBeyondOrder.Find(CurrentDiscountMarkup.ConnectionKey) <> Undefined Then
				NewRowDiscountsMarkups = Object.DiscountsMarkups.Add();
				FillPropertyValues(NewRowDiscountsMarkups, CurrentDiscountMarkup);
			EndIf;
		EndDo;
	Else
		If TypeOf(Object.DiscountsMarkups) = Type("ValueTable") Then
			Object.DiscountsMarkups = DiscountsMarkupsCalculationResult.Copy();
		Else
			Object.DiscountsMarkups.Load(DiscountsMarkupsCalculationResult);
		EndIf;
	EndIf;
	AutomaticDiscountsMarkups = DiscountsMarkupsCalculationResult.Copy();
	
	// Filling of discounts in spreadshet part "Products"
	AutomaticDiscountsMarkups.GroupBy("ConnectionKey", "Amount");
	AutomaticDiscountsMarkups.Indexes.Add("ConnectionKey");
	
	FillDiscountAmount = False;
	If TypeOf(Object.Ref) = Type("DocumentRef.ReceiptCR") Then
		FillDiscountAmount = True;
	EndIf;
	AttributeSPOrder = "Order";
	If TypeOf(Object.Ref) = Type("DocumentRef.AcceptanceCertificate") Then
		AttributeSPOrder = "CustomerOrder";
	EndIf;
	
	SPConformity = New Map;
	SPConformity.Insert(TSName, "ConnectionKey");
	If Not NameSP2 = Undefined Then // For purchase order which has 2 SP: "Works" and "Inventory".
		SPConformity.Insert(NameSP2, "ConnectionKeyForMarkupsDiscounts");
	EndIf;
	ThereIsAttributeDiscountPercentByDiscountCard = Not (Object.Ref.Metadata().Attributes.Find("DiscountPercentByDiscountCard") = Undefined);
	
	For Each CurCorrespondenceItem IN SPConformity Do
		AttributeConnectionKey = CurCorrespondenceItem.Value;
		For Each TSRow IN Object[CurCorrespondenceItem.Key] Do
			
			If SalesExceedingOrder AND ValueIsFilled(TSRow[AttributeSPOrder]) Then
				Continue;
			EndIf;
			
			TableRow = AutomaticDiscountsMarkups.Find(TSRow[AttributeConnectionKey], "ConnectionKey");
			If TableRow = Undefined Then
				TSRow.AutomaticDiscountAmount = 0;
				AutomaticDiscountAmount          = 0; // For precise calculation of automatic discount percent
			Else
				TSRow.AutomaticDiscountAmount = TableRow.Amount;
				AutomaticDiscountAmount          = TableRow.Amount; // For precise calculation of automatic discount percent
			EndIf;
			
			// Application of automatic discount.
			AmountWithoutDiscount = TSRow.Quantity * TSRow.Price;
			
			// Discounts.
			If AmountWithoutDiscount <> 0 Then
				If TSRow.DiscountMarkupPercent = 100 Then
					AmountAfterManualDiscountsMarkupsApplication = 0;
				ElsIf (TSRow.DiscountMarkupPercent <> 0 OR (ThereIsAttributeDiscountPercentByDiscountCard AND Object.DiscountPercentByDiscountCard) <> 0) AND TSRow.Quantity <> 0 Then
					AmountAfterManualDiscountsMarkupsApplication = AmountWithoutDiscount * (1 - (TSRow.DiscountMarkupPercent) / 100);
				Else
					AmountAfterManualDiscountsMarkupsApplication = AmountWithoutDiscount;
				EndIf;
			Else
				AmountAfterManualDiscountsMarkupsApplication = AmountWithoutDiscount;
			EndIf;
			
			If FillDiscountAmount Then
				ManualDiscountAmount = TSRow.AmountDiscountsMarkups;
			Else
				ManualDiscountAmount = AmountWithoutDiscount - AmountAfterManualDiscountsMarkupsApplication;
			EndIf;
			
			DiscountAmount = AutomaticDiscountAmount + ManualDiscountAmount;
			
			TSRow.AutomaticDiscountsPercent = ?(AmountWithoutDiscount = 0, 0 , 100 * AutomaticDiscountAmount / AmountWithoutDiscount);
			
			TSRow.Amount    = AmountWithoutDiscount - ?(DiscountAmount > AmountWithoutDiscount, AmountWithoutDiscount, DiscountAmount);
			
			// VAT amount.
			VATRate = SmallBusinessreuse.GetVATRateValue(TSRow.VATRate);
		
			TSRow.VATAmount = ?(Object.AmountIncludesVAT, 
											  TSRow.Amount - (TSRow.Amount) / ((VATRate + 100) / 100),
											  TSRow.Amount * VATRate / 100);

			// Total.
			TSRow.Total = TSRow.Amount + ?(Object.AmountIncludesVAT, 0, TSRow.VATAmount);

			If FillDiscountAmount Then
				TSRow.DiscountAmount = AmountWithoutDiscount - TSRow.Amount;
				TSRow.AmountDiscountsMarkups = ManualDiscountAmount;
			EndIf;
			
		EndDo;
	EndDo;
	
	Object.DiscountsAreCalculated = True;
	
EndProcedure // CalculateByObject()

#EndRegion