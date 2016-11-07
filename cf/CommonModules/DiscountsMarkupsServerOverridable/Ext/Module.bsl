////////////////////////////////////////////////////////////////////////////////
// DiscountsMarkupsServerOverriding:
// contains a number of functions and procedures used for calculation of discounts and processing of objects related to discounts
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Generates a list of values for possible recipients of discounts
//
// Parameters
// List = Filled list
//
// Returns:
//   ValueList
//
Function GetValuesListDiscountProvisionWays(ListToBeFilled = Undefined) Export

	If ListToBeFilled = Undefined Then
		ListToBeFilled = New ValueList;
	EndIf;
	
	ListToBeFilled.Add(Enums.DiscountsMarkupsProvidingWays.Percent);
	ListToBeFilled.Add(Enums.DiscountsMarkupsProvidingWays.Amount);
	
	Return ListToBeFilled;

EndFunction // GetDiscountProvisionWaysValuesList()

// Generates a list of values for possible discounts conditions
//
// Parameters
// List = Filled list
//
// Returns:
//   ValueList
//
Function GetDiscountProvidingConditionsValuesList(ListToBeFilled = Undefined) Export

	If ListToBeFilled = Undefined Then
		ListToBeFilled = New ValueList;
	EndIf;
	
	ListToBeFilled.Add(Enums.DiscountsMarkupsProvidingConditions.ForOneTimeSalesVolume);
	ListToBeFilled.Add(Enums.DiscountsMarkupsProvidingConditions.ForKitPurchase);
	
	Return ListToBeFilled;

EndFunction // GetDiscountConditionsValuesList()

#EndRegion

#Region DiscountCalculationProceduresAndFunctions

// The procedure calculates discounts by the document.
// Appears from document forms.
//
Function Calculate(Object, InputParameters) Export
	
	If TypeOf(Object.Ref) = Type("DocumentRef.ReceiptCR") OR
		TypeOf(Object.Ref) = Type("DocumentRef.ReceiptCRReturn")
	Then
		
		DiscountsTree = CalculateByCRCheck(Object, InputParameters);
		
	ElsIf TypeOf(Object.Ref) = Type("DocumentRef.CustomerInvoice") Then
		
		DiscountsTree = CalculateByGoodsSales(Object, InputParameters);
		
	ElsIf TypeOf(Object.Ref) = Type("DocumentRef.InvoiceForPayment") Then
		
		DiscountsTree = CalculateByInvoiceForPayment(Object, InputParameters);
		
	ElsIf TypeOf(Object.Ref) = Type("DocumentRef.AcceptanceCertificate") Then
		
		DiscountsTree = CalculateByWorkCompletionCertificate(Object, InputParameters);
		
	ElsIf TypeOf(Object.Ref) = Type("DocumentRef.CustomerOrder") Then
		
		If Object.OperationKind = Enums.OperationKindsCustomerOrder.JobOrder Then
			DiscountsTree = CalculateByJobOrder(Object, InputParameters);
		Else
			DiscountsTree = CalculateByCustomerOrder(Object, InputParameters);
		EndIf;
		
	ElsIf TypeOf(Object.Ref) = Type("DocumentRef.ProcessingReport") Then
		
		DiscountsTree = CalculateByReportOnRecycling(Object, InputParameters);
		
	EndIf;
	If InputParameters.Property("InformationAboutDocument") Then
		DiscountsTree.Insert("InformationAboutDocument", InputParameters.InformationAboutDocument);
	EndIf;
	
	Return DiscountsTree;
	
EndFunction // Calculate()

#EndRegion

#Region ProceduresForDiscountsMarkupsCalculationByDocuments

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
	|	Currency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CurrencyRates.Currency    AS Currency,
	|	CurrencyRates.ExchangeRate      AS ExchangeRate,
	|	CurrencyRates.Multiplicity AS Multiplicity
	|FROM
	|	CurrencyRates
	|";
	
	QueryText = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	Return New Structure("QueryText, TablesCount, ResultTableNumber, TableName", QueryText, 2, 2, "CurrencyRates");
	
EndFunction

#EndRegion

#Region DiscountRepresentation

// Updates the spreadsheet Parts discounts
//
// Parameters:
//  Object - CR receipt or
//  Sales of goods SPName - Spreadsheet
//  part name MainSPName - Tabular section name
//
Procedure UpdateDiscountDisplay(Object, MainSPName = "Products", TSName = "DiscountsMarkups") Export

	MainTable = Object[MainSPName].Unload();
	
	For Each RowDiscountsMarkups IN Object[TSName] Do
		
		ConnectionKey = RowDiscountsMarkups.ConnectionKey;
		
		MainTableRow = MainTable.Find(ConnectionKey, "ConnectionKey");
		
		If Not MainTableRow = Undefined Then
			
			RowDiscountsMarkups.ProductsAndServices               = MainTableRow.ProductsAndServices;
			RowDiscountsMarkups.Characteristic             = MainTableRow.Characteristic;
			RowDiscountsMarkups.BasisTableLineNumber  = MainTableRow.LineNumber;
			RowDiscountsMarkups.CharacteristicsAreUsed = MainTableRow.ProductsAndServices.UseCharacteristics;
			
		EndIf;
		
		RowDiscountsMarkups.DiscountBannedFromView = Not CheckAccessToAttribute(RowDiscountsMarkups, "DiscountMarkup", "Catalog.AutomaticDiscounts");
		
	EndDo;
	

EndProcedure // UpdateDiscountDisplay()

// Checking of access to the object attribute
//
Function CheckAccessToAttribute(Object, AttributeName, TableValuesName) Export
	
	SetPrivilegedMode(True);
	
	If Not ValueIsFilled(Object[AttributeName]) Then
		Return True;
	EndIf;
	
	SetPrivilegedMode(False);
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	AvailableAttributeValues.Ref
	|FROM
	|	" + TableValuesName + " AS AvailableAttributeValues";
	
	Result = Query.Execute();
	AllowedAttributeValuesArray = Result.Unload().UnloadColumn("Ref");
	
	SetPrivilegedMode(True);
	AttributeValue = Object[AttributeName];
	
	Return AllowedAttributeValuesArray.Find(AttributeValue) <> Undefined;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// The function returns the table of active discounts (markups)
//
// Returns:
// ValueTable - Details of discounts.
//
Function GetDiscountsMarkupsTableForRetail(Object, StructuralUnit, InputParameters)
	
	CurrentDate = Object.Date;
	
	// We need to get a list of all automatic discounts that shall be calculated.
	// 1. Get all the discounts that fit by validity.
	// 2. We will receive all discounts that fit by recipients by equality of discount recipient and counterparty  selected in the document.
	// 3. We will separately process the discounts which have groups as discount recipients.
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED DISTINCT
	|	AutomaticDiscountsTimeByWeekDays.Ref AS Ref,
	|	AutomaticDiscountsTimeByWeekDays.Ref.IsRestrictionByRecipientsWarehouses
	|INTO TU_DiscountsAfterFilteringByWeekDays
	|FROM
	|	Catalog.AutomaticDiscounts.TimeByDaysOfWeek AS AutomaticDiscountsTimeByWeekDays
	|WHERE
	|	AutomaticDiscountsTimeByWeekDays.Ref.ThereIsSchedule
	|	AND AutomaticDiscountsTimeByWeekDays.WeekDay = &WeekDay
	|	AND AutomaticDiscountsTimeByWeekDays.BeginTime <= &CurrentTime
	|	AND AutomaticDiscountsTimeByWeekDays.EndTime >= &CurrentTime
	|	AND (AutomaticDiscountsTimeByWeekDays.Ref.Acts
	|				AND AutomaticDiscountsTimeByWeekDays.Ref.Purpose = &Retail
	|			OR AutomaticDiscountsTimeByWeekDays.Ref.Purpose = &Everywhere)
	|	AND Not AutomaticDiscountsTimeByWeekDays.Ref.DeletionMark
	|	AND AutomaticDiscountsTimeByWeekDays.Selected
	|	AND AutomaticDiscountsTimeByWeekDays.Ref.Acts
	|
	|UNION ALL
	|
	|SELECT
	|	AutomaticDiscounts.Ref,
	|	AutomaticDiscounts.IsRestrictionByRecipientsWarehouses
	|FROM
	|	Catalog.AutomaticDiscounts AS AutomaticDiscounts
	|WHERE
	|	Not AutomaticDiscounts.ThereIsSchedule
	|	AND AutomaticDiscounts.Acts
	|	AND (AutomaticDiscounts.Ref.Purpose = &Retail
	|			OR AutomaticDiscounts.Ref.Purpose = &Everywhere)
	|	AND Not AutomaticDiscounts.DeletionMark
	|
	|INDEX BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AutomaticDiscountsDiscountRecipients.Ref AS DiscountMarkup,
	|	AutomaticDiscountsDiscountRecipients.Recipient
	|INTO TU_DiscountsByRecipientEquality
	|FROM
	|	Catalog.AutomaticDiscounts.DiscountRecipientsWarehouses AS AutomaticDiscountsDiscountRecipients
	|		INNER JOIN TU_DiscountsAfterFilteringByWeekDays AS TU_DiscountsAfterFilteringByWeekDays
	|		ON AutomaticDiscountsDiscountRecipients.Ref = TU_DiscountsAfterFilteringByWeekDays.Ref
	|			AND (AutomaticDiscountsDiscountRecipients.Recipient = &StructuralUnit)
	|WHERE
	|	(AutomaticDiscountsDiscountRecipients.Ref.Purpose = &Retail
	|			OR AutomaticDiscountsDiscountRecipients.Ref.Purpose = &Everywhere)
	|	AND AutomaticDiscountsDiscountRecipients.Ref.Acts
	|	AND AutomaticDiscountsDiscountRecipients.Ref.IsRestrictionByRecipientsWarehouses
	|
	|GROUP BY
	|	AutomaticDiscountsDiscountRecipients.Ref,
	|	AutomaticDiscountsDiscountRecipients.Recipient
	|
	|UNION ALL
	|
	|SELECT
	|	TU_DiscountsAfterFilteringByWeekDays.Ref,
	|	NULL
	|FROM
	|	TU_DiscountsAfterFilteringByWeekDays AS TU_DiscountsAfterFilteringByWeekDays
	|WHERE
	|	Not TU_DiscountsAfterFilteringByWeekDays.IsRestrictionByRecipientsWarehouses
	|
	|INDEX BY
	|	DiscountMarkup
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TU_DiscountsAfterFilteringByWeekDays.Ref
	|INTO TU_DiscountsNotFilteredByRecipient
	|FROM
	|	TU_DiscountsAfterFilteringByWeekDays AS TU_DiscountsAfterFilteringByWeekDays
	|		LEFT JOIN TU_DiscountsByRecipientEquality AS TU_DiscountsByRecipientEquality
	|		ON TU_DiscountsAfterFilteringByWeekDays.Ref = TU_DiscountsByRecipientEquality.DiscountMarkup
	|WHERE
	|	TU_DiscountsAfterFilteringByWeekDays.IsRestrictionByRecipientsWarehouses
	|	AND TU_DiscountsByRecipientEquality.DiscountMarkup IS NULL 
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TU_DiscountsByRecipientEquality.DiscountMarkup
	|FROM
	|	TU_DiscountsByRecipientEquality AS TU_DiscountsByRecipientEquality";
	
	Query.SetParameter("StructuralUnit", StructuralUnit);
	Query.SetParameter("Retail", Enums.AssignAutomaticDiscounts.Retail);
	Query.SetParameter("Everywhere", Enums.AssignAutomaticDiscounts.Everywhere);
	// For the discount "For the period of sales".
	Query.SetParameter("WeekDay",   Enums.WeekDays.Get(WeekDay(CurrentDate) - 1));
	Query.SetParameter("CurrentTime", GetObjectCurrentTime(Object));
	
	MResults = Query.ExecuteBatch();
	
	DiscountsVT = MResults[3].Unload();
	
	Return DiscountsVT;
	
EndFunction // GetDiscountsMarkupsTableForRetail()

// The function returns the table of active discounts (markups)
//
// Returns:
// ValueTable - Details of discounts.
//
Function GetDiscountsMarkupsTableForWholesale(Object, StructuralUnit, InputParameters)
	
	CurrentDate = Object.Date;
	
	// We need to get a list of all automatic discounts that shall be calculated.
	// 1. Get all the discounts that fit by validity.
	// 2. We will receive all discounts that fit by recipients by equality of discount recipient and counterparty  selected in the document.
	// 3. We will separately process the discounts which have groups as discount recipients.
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED DISTINCT
	|	AutomaticDiscountsTimeByWeekDays.Ref AS Ref,
	|	AutomaticDiscountsTimeByWeekDays.Ref.IsRestrictionOnRecipientsCounterparties
	|INTO TU_DiscountsAfterFilteringByWeekDays
	|FROM
	|	Catalog.AutomaticDiscounts.TimeByDaysOfWeek AS AutomaticDiscountsTimeByWeekDays
	|WHERE
	|	AutomaticDiscountsTimeByWeekDays.Ref.ThereIsSchedule
	|	AND AutomaticDiscountsTimeByWeekDays.WeekDay = &WeekDay
	|	AND AutomaticDiscountsTimeByWeekDays.BeginTime <= &CurrentTime
	|	AND AutomaticDiscountsTimeByWeekDays.EndTime >= &CurrentTime
	|	AND (AutomaticDiscountsTimeByWeekDays.Ref.Acts
	|				AND AutomaticDiscountsTimeByWeekDays.Ref.Purpose = &Wholesale
	|			OR AutomaticDiscountsTimeByWeekDays.Ref.Purpose = &Everywhere)
	|	AND Not AutomaticDiscountsTimeByWeekDays.Ref.DeletionMark
	|	AND AutomaticDiscountsTimeByWeekDays.Selected
	|	AND AutomaticDiscountsTimeByWeekDays.Ref.Acts
	|
	|UNION ALL
	|
	|SELECT
	|	AutomaticDiscounts.Ref,
	|	AutomaticDiscounts.IsRestrictionOnRecipientsCounterparties
	|FROM
	|	Catalog.AutomaticDiscounts AS AutomaticDiscounts
	|WHERE
	|	Not AutomaticDiscounts.ThereIsSchedule
	|	AND AutomaticDiscounts.Acts
	|	AND (AutomaticDiscounts.Ref.Purpose = &Wholesale
	|			OR AutomaticDiscounts.Ref.Purpose = &Everywhere)
	|	AND Not AutomaticDiscounts.DeletionMark
	|
	|INDEX BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AutomaticDiscountsDiscountRecipients.Ref AS DiscountMarkup,
	|	AutomaticDiscountsDiscountRecipients.Recipient
	|INTO TU_DiscountsByRecipientEquality
	|FROM
	|	Catalog.AutomaticDiscounts.DiscountRecipientsCounterparties AS AutomaticDiscountsDiscountRecipients
	|		INNER JOIN TU_DiscountsAfterFilteringByWeekDays AS TU_DiscountsAfterFilteringByWeekDays
	|		ON AutomaticDiscountsDiscountRecipients.Ref = TU_DiscountsAfterFilteringByWeekDays.Ref
	|			AND (AutomaticDiscountsDiscountRecipients.Recipient = &StructuralUnit)
	|WHERE
	|	(AutomaticDiscountsDiscountRecipients.Ref.Purpose = &Wholesale
	|			OR AutomaticDiscountsDiscountRecipients.Ref.Purpose = &Everywhere)
	|	AND AutomaticDiscountsDiscountRecipients.Ref.Acts
	|	AND AutomaticDiscountsDiscountRecipients.Ref.IsRestrictionOnRecipientsCounterparties
	|
	|GROUP BY
	|	AutomaticDiscountsDiscountRecipients.Ref,
	|	AutomaticDiscountsDiscountRecipients.Recipient
	|
	|UNION ALL
	|
	|SELECT
	|	TU_DiscountsAfterFilteringByWeekDays.Ref,
	|	NULL
	|FROM
	|	TU_DiscountsAfterFilteringByWeekDays AS TU_DiscountsAfterFilteringByWeekDays
	|WHERE
	|	Not TU_DiscountsAfterFilteringByWeekDays.IsRestrictionOnRecipientsCounterparties
	|
	|INDEX BY
	|	DiscountMarkup
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TU_DiscountsAfterFilteringByWeekDays.Ref
	|INTO TU_DiscountsNotFilteredByRecipient
	|FROM
	|	TU_DiscountsAfterFilteringByWeekDays AS TU_DiscountsAfterFilteringByWeekDays
	|		LEFT JOIN TU_DiscountsByRecipientEquality AS TU_DiscountsByRecipientEquality
	|		ON TU_DiscountsAfterFilteringByWeekDays.Ref = TU_DiscountsByRecipientEquality.DiscountMarkup
	|WHERE
	|	TU_DiscountsAfterFilteringByWeekDays.IsRestrictionOnRecipientsCounterparties
	|	AND TU_DiscountsByRecipientEquality.DiscountMarkup IS NULL 
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TU_DiscountsByRecipientEquality.DiscountMarkup
	|FROM
	|	TU_DiscountsByRecipientEquality AS TU_DiscountsByRecipientEquality
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	AutomaticDiscountsDiscountRecipients.Ref
	|FROM
	|	Catalog.AutomaticDiscounts.DiscountRecipientsCounterparties AS AutomaticDiscountsDiscountRecipients
	|		INNER JOIN TU_DiscountsNotFilteredByRecipient AS TU_DiscountsNotFilteredByRecipient
	|		ON AutomaticDiscountsDiscountRecipients.Ref = TU_DiscountsNotFilteredByRecipient.Ref
	|WHERE
	|	AutomaticDiscountsDiscountRecipients.Recipient.IsFolder";
	
	Query.SetParameter("StructuralUnit", StructuralUnit);
	Query.SetParameter("Wholesale", Enums.AssignAutomaticDiscounts.Wholesale);
	Query.SetParameter("Everywhere", Enums.AssignAutomaticDiscounts.Everywhere);
	// For the discount "For the period of sales".
	Query.SetParameter("WeekDay",   Enums.WeekDays.Get(WeekDay(CurrentDate) - 1));
	Query.SetParameter("CurrentTime", GetObjectCurrentTime(Object));	
	
	MResults = Query.ExecuteBatch();
	
	DiscountsVT = MResults[3].Unload();
	
	If Not MResults[4].IsEmpty() Then
		QueryTextPattern = "SELECT
		                      |	AutomaticDiscountsDiscountRecipients.Recipient AS Recipient,
		                      |	AutomaticDiscountsDiscountRecipients.Ref
		                      |INTO TU_DiscountRecipients
		                      |FROM
		                      |	Catalog.AutomaticDiscounts.DiscountRecipientsCounterparties AS AutomaticDiscountsDiscountRecipients
		                      |WHERE
		                      |	AutomaticDiscountsDiscountRecipients.Ref = &RefAutoDiscount
		                      |	AND AutomaticDiscountsDiscountRecipients.Recipient.IsFolder
		                      |
		                      |INDEX BY
		                      |	Recipient
		                      |;
		                      |
		                      |////////////////////////////////////////////////////////////////////////////////
		                      |SELECT
		                      |	&RefAutoDiscount AS DiscountMarkup
		                      |WHERE
		                      |	&RefCounterparty IN HIERARCHY
		                      |			(SELECT
		                      |				TU_DiscountRecipients.Recipient
		                      |			IN
		                      |				TU_DiscountRecipients AS TU_DiscountRecipients)
		                      |;
		                      |
		                      |////////////////////////////////////////////////////////////////////////////////
		                      |DROP TU_DiscountRecipients";
	
		CtQueries = 0;
		QueryText = "";
		Query = New Query;
		Query.SetParameter("RefCounterparty", StructuralUnit);
		DiscountsSelectionForAdditionalProcessing = MResults[4].Select();
		While DiscountsSelectionForAdditionalProcessing.Next() Do
			CtQueries = CtQueries + 1;
			CurDiscount = DiscountsSelectionForAdditionalProcessing.Ref;
			
			Query.Text = Query.Text + StrReplace(QueryTextPattern, "&RefAutoDiscount", "&RefAutoDiscount"+CtQueries)+Chars.LF+"
				|;
				|
				|////////////////////////////////////////////////////////////////////////////////
				|";
			Query.SetParameter("RefAutoDiscount"+CtQueries, CurDiscount);
		EndDo;
		
		MDiscountsResults = Query.ExecuteBatch();
		
		CtQueries = 1;
		While CtQueries < MDiscountsResults.Count() Do
			If Not MDiscountsResults[CtQueries].IsEmpty() Then
				DiscountsStr = DiscountsVT.Add();
				DiscountsStr.DiscountMarkup = MDiscountsResults[CtQueries].Unload()[0].DiscountMarkup;
			EndIf;
			CtQueries = CtQueries + 3;
		EndDo;
	EndIf;
	
	Return DiscountsVT;
	
EndFunction // GetDiscountsMarkupsTableForWholesale()

// The function calculates discounts by customer order.
//
Function CalculateByCustomerOrder(Object, InputParameters)
	Var Workplace;
	
	DiscountsMarkupsServer.FillLinkingKeysInSpreadsheetPartProducts(Object, "Inventory");
	
	// Processing of spreadsheet part "Inventory".
	Products = Object.Inventory.Unload(
		,
		"ConnectionKey,
		|ProductsAndServices,
		|Characteristic,
		|MeasurementUnit,
		|Quantity,
		|Price"
	);
	
	ObjectCurrentDate = DiscountsMarkupsServer.GetObjectCurrentDate(Object);
	
	CalculationParameters = New Structure;
	CalculationParameters.Insert("DiscountsMarkups", GetDiscountsMarkupsTableForWholesale(Object, Object.Counterparty, InputParameters));
	CalculationParameters.Insert("Recorder"  , Object.Ref);
	CalculationParameters.Insert("Shop"      , Object.StructuralUnitReserve);
	
	CalculationParameters.Insert("SalesWarehouse"            , Object.SalesStructuralUnit);
	//CalculationParameters.Insert("MinimumSalesPricesKind", ShopDetails.MinimumSalesPricesKind);
	
	CalculationParameters.Insert("Products",            Products);
	CalculationParameters.Insert("DocumentCurrency",   Object.DocumentCurrency);
	CalculationParameters.Insert("ManagementAccountingCurrency",   Constants.AccountingCurrency.Get());
	CalculationParameters.Insert("User",      Undefined);
	CalculationParameters.Insert("CurrentDate",       ObjectCurrentDate);
	CalculationParameters.Insert("SharedUsageVariant", Constants.DiscountsMarkupsSharedUsageOptions.Get());
	
	DiscountsMarkupsApplied = DiscountsMarkupsServer.CalculateDiscountsMarkupsTree(CalculationParameters, InputParameters);
	
	If InputParameters.ApplyToObject Then
		DiscountsMarkupsServer.ApplyDiscountCalculationResultToObject(Object, "Inventory", DiscountsMarkupsApplied.TableDiscountsMarkups);
	EndIf;
	
	Return DiscountsMarkupsApplied;
	
EndFunction // CalculateByCustomerOrder()

// The function calculates discounts by customer order.
//
Function CalculateByJobOrder(Object, InputParameters)
	Var Workplace;
	
	DiscountsMarkupsServer.FillLinkingKeysInSpreadsheetPartProducts(Object, "Inventory", "Works");
	
	// Processing of spreadsheet part "Inventory".
	Products = Object.Inventory.Unload(
		,
		"ConnectionKey,
		|ProductsAndServices,
		|Characteristic,
		|MeasurementUnit,
		|Quantity,
		|Price"
	);
	
	For Each CurrentRow IN Object.Works Do
		NewRow = Products.Add();
		FillPropertyValues(NewRow, CurrentRow);
		NewRow.ConnectionKey = CurrentRow.ConnectionKeyForMarkupsDiscounts;
	EndDo;
	
	ObjectCurrentDate = DiscountsMarkupsServer.GetObjectCurrentDate(Object);
	
	CalculationParameters = New Structure;
	CalculationParameters.Insert("DiscountsMarkups", GetDiscountsMarkupsTableForWholesale(Object, Object.Counterparty, InputParameters));
	CalculationParameters.Insert("Recorder"  , Object.Ref);
	CalculationParameters.Insert("Shop"      , Object.StructuralUnitReserve);
	
	CalculationParameters.Insert("SalesWarehouse"            , Object.SalesStructuralUnit);
	//CalculationParameters.Insert("MinimumSalesPricesKind", ShopDetails.MinimumSalesPricesKind);
	
	CalculationParameters.Insert("Products",            Products);
	CalculationParameters.Insert("DocumentCurrency",   Object.DocumentCurrency);
	CalculationParameters.Insert("ManagementAccountingCurrency",   Constants.AccountingCurrency.Get());
	CalculationParameters.Insert("User",      Undefined);
	CalculationParameters.Insert("CurrentDate",       ObjectCurrentDate);
	CalculationParameters.Insert("SharedUsageVariant", Constants.DiscountsMarkupsSharedUsageOptions.Get());
	
	DiscountsMarkupsApplied = DiscountsMarkupsServer.CalculateDiscountsMarkupsTree(CalculationParameters, InputParameters);
	
	If InputParameters.ApplyToObject Then
		DiscountsMarkupsServer.ApplyDiscountCalculationResultToObject(Object, "Inventory", DiscountsMarkupsApplied.TableDiscountsMarkups, , , "Works");
	EndIf;
	
	Return DiscountsMarkupsApplied;
	
EndFunction // CalculateByCustomerOrder()

// The function receives current time of the object
//
// Parameters
//  Object  - DocumentObject - object for which you need to get the current time
//
// Returns:
//   Date   - Current time of the object
//
Function GetObjectCurrentTime(Object)
	
	CurrentDate = ?(ValueIsFilled(Object.Ref), Object.Date, CurrentDate());
	CurrentTime = '00010101' + (CurrentDate - BegOfDay(CurrentDate));
	
	Return CurrentTime;
	
EndFunction // GetObjectCurrentTime()

// The function calculates discounts by CR receipt.
//
Function CalculateByCRCheck(Object, InputParameters)
	Var Workplace;
	
	DiscountsMarkupsServer.FillLinkingKeysInSpreadsheetPartProducts(Object, "Inventory");
	
	// Processing of spreadsheet part "Inventory".
	Products = Object.Inventory.Unload(
		,
		"ConnectionKey,
		|ProductsAndServices,
		|Characteristic,
		|MeasurementUnit,
		|Quantity,
		|Price"
	);
	
	ObjectCurrentDate = DiscountsMarkupsServer.GetObjectCurrentDate(Object);
	
	CalculationParameters = New Structure;
	CalculationParameters.Insert("DiscountsMarkups", GetDiscountsMarkupsTableForRetail(Object, Object.StructuralUnit, InputParameters));
	CalculationParameters.Insert("Recorder"  , Object.Ref);
	CalculationParameters.Insert("Shop"      , Object.StructuralUnit);
	
	CalculationParameters.Insert("SalesWarehouse"            , Object.Division);
	//CalculationParameters.Insert("MinimumSalesPricesKind", ShopDetails.MinimumSalesPricesKind);
	
	CalculationParameters.Insert("Products",            Products);
	CalculationParameters.Insert("DocumentCurrency",   Object.DocumentCurrency);
	CalculationParameters.Insert("ManagementAccountingCurrency",   Constants.AccountingCurrency.Get());
	CalculationParameters.Insert("User",      Undefined);
	CalculationParameters.Insert("CurrentDate",       ObjectCurrentDate);
	CalculationParameters.Insert("SharedUsageVariant", Constants.DiscountsMarkupsSharedUsageOptions.Get());
	
	DiscountsMarkupsApplied = DiscountsMarkupsServer.CalculateDiscountsMarkupsTree(CalculationParameters, InputParameters);
	
	If InputParameters.ApplyToObject Then
		DiscountsMarkupsServer.ApplyDiscountCalculationResultToObject(Object, "Inventory", DiscountsMarkupsApplied.TableDiscountsMarkups);
	EndIf;
	
	Return DiscountsMarkupsApplied;
	
EndFunction // CalculateByCRCheck()

// The function calculates discounts by goods sales.
//
Function CalculateByGoodsSales(Object, InputParameters)
	Var Workplace;
	
	DiscountsMarkupsServer.FillLinkingKeysInSpreadsheetPartProducts(Object, "Inventory");
	
	If InputParameters.Property("SalesExceedingOrder") Then
		SalesExceedingOrder = InputParameters.SalesExceedingOrder;
	Else
		SalesExceedingOrder = False;
	EndIf;
	
	// Processing of spreadsheet part "Inventory".
	Products = Object.Inventory.Unload(
		,
		"ConnectionKey,
		|ProductsAndServices,
		|Characteristic,
		|MeasurementUnit,
		|Quantity,
		|Price,
		|Order"
	);
	
	If SalesExceedingOrder Then
		GoodsBeyondOrder = Products.CopyColumns();
		
		For Each CurrentRow IN Products Do
			If Not ValueIsFilled(CurrentRow.Order) Then
				NewRow = GoodsBeyondOrder.Add();
				FillPropertyValues(NewRow, CurrentRow);
			EndIf;
		EndDo;
	Else
		GoodsBeyondOrder = "";
	EndIf;
	
	ObjectCurrentDate = DiscountsMarkupsServer.GetObjectCurrentDate(Object);
	
	CalculationParameters = New Structure;
	CalculationParameters.Insert("DiscountsMarkups", GetDiscountsMarkupsTableForWholesale(Object, Object.Counterparty, InputParameters));
	CalculationParameters.Insert("Recorder"  , Object.Ref);
	CalculationParameters.Insert("Shop"      , Object.StructuralUnit);
	
	CalculationParameters.Insert("SalesWarehouse"            , Object.Division);
	//CalculationParameters.Insert("MinimumSalesPricesKind", ShopDetails.MinimumSalesPricesKind);
	
	CalculationParameters.Insert("Products",            Products);
	CalculationParameters.Insert("DocumentCurrency",   Object.DocumentCurrency);
	CalculationParameters.Insert("ManagementAccountingCurrency",   Constants.AccountingCurrency.Get());
	CalculationParameters.Insert("User",      Undefined);
	CalculationParameters.Insert("CurrentDate",       ObjectCurrentDate);
	CalculationParameters.Insert("SharedUsageVariant", Constants.DiscountsMarkupsSharedUsageOptions.Get());
	
	DiscountsMarkupsApplied = DiscountsMarkupsServer.CalculateDiscountsMarkupsTree(CalculationParameters, InputParameters);
	
	If InputParameters.ApplyToObject Then
		DiscountsMarkupsServer.ApplyDiscountCalculationResultToObject(Object, "Inventory", DiscountsMarkupsApplied.TableDiscountsMarkups, SalesExceedingOrder, GoodsBeyondOrder);
	EndIf;
	
	Return DiscountsMarkupsApplied;
	
EndFunction // CalculateByGoodsSales()

// The function calculates discounts by processing report.
//
Function CalculateByReportOnRecycling(Object, InputParameters)
	Var Workplace;
	
	DiscountsMarkupsServer.FillLinkingKeysInSpreadsheetPartProducts(Object, "Products");
	
	If InputParameters.Property("SalesExceedingOrder") Then
		SalesExceedingOrder = InputParameters.SalesExceedingOrder;
	Else
		SalesExceedingOrder = False;
	EndIf;
	
	// Processing of spreadsheet part "Goods".
	Products = Object.Products.Unload(
		,
		"ConnectionKey,
		|ProductsAndServices,
		|Characteristic,
		|MeasurementUnit,
		|Quantity,
		|Price"
	);
	
	ObjectCurrentDate = DiscountsMarkupsServer.GetObjectCurrentDate(Object);
	
	CalculationParameters = New Structure;
	CalculationParameters.Insert("DiscountsMarkups", GetDiscountsMarkupsTableForWholesale(Object, Object.Counterparty, InputParameters));
	CalculationParameters.Insert("Recorder"  , Object.Ref);
	CalculationParameters.Insert("Shop"      , Object.StructuralUnit);
	
	CalculationParameters.Insert("SalesWarehouse"            , Object.Division);
	//CalculationParameters.Insert("MinimumSalesPricesKind", ShopDetails.MinimumSalesPricesKind);
	
	CalculationParameters.Insert("Products",            Products);
	CalculationParameters.Insert("DocumentCurrency",   Object.DocumentCurrency);
	CalculationParameters.Insert("ManagementAccountingCurrency",   Constants.AccountingCurrency.Get());
	CalculationParameters.Insert("User",      Undefined);
	CalculationParameters.Insert("CurrentDate",       ObjectCurrentDate);
	CalculationParameters.Insert("SharedUsageVariant", Constants.DiscountsMarkupsSharedUsageOptions.Get());
	
	DiscountsMarkupsApplied = DiscountsMarkupsServer.CalculateDiscountsMarkupsTree(CalculationParameters, InputParameters);
	
	If InputParameters.ApplyToObject Then
		DiscountsMarkupsServer.ApplyDiscountCalculationResultToObject(Object, "Products", DiscountsMarkupsApplied.TableDiscountsMarkups);
	EndIf;
	
	Return DiscountsMarkupsApplied;
	
EndFunction // CalculateByGoodsSales()

// The function calculates discounts by goods sales.
//
Function CalculateByInvoiceForPayment(Object, InputParameters)
	Var Workplace;
	
	DiscountsMarkupsServer.FillLinkingKeysInSpreadsheetPartProducts(Object, "Inventory");
	
	// Processing of spreadsheet part "Inventory".
	Products = Object.Inventory.Unload(
		,
		"ConnectionKey,
		|ProductsAndServices,
		|Characteristic,
		|MeasurementUnit,
		|Quantity,
		|Price"
	);
	
	ObjectCurrentDate = DiscountsMarkupsServer.GetObjectCurrentDate(Object);
	
	CalculationParameters = New Structure;
	CalculationParameters.Insert("DiscountsMarkups", GetDiscountsMarkupsTableForWholesale(Object, Object.Counterparty, InputParameters));
	CalculationParameters.Insert("Recorder"  , Object.Ref);
	CalculationParameters.Insert("Shop"      , Catalogs.StructuralUnits.EmptyRef());
	
	CalculationParameters.Insert("SalesWarehouse"            , Object.Division);
	//CalculationParameters.Insert("MinimumSalesPricesKind", ShopDetails.MinimumSalesPricesKind);
	
	CalculationParameters.Insert("Products",            Products);
	CalculationParameters.Insert("DocumentCurrency",   Object.DocumentCurrency);
	CalculationParameters.Insert("ManagementAccountingCurrency",   Constants.AccountingCurrency.Get());
	CalculationParameters.Insert("User",      Undefined);
	CalculationParameters.Insert("CurrentDate",       ObjectCurrentDate);
	CalculationParameters.Insert("SharedUsageVariant", Constants.DiscountsMarkupsSharedUsageOptions.Get());
	
	DiscountsMarkupsApplied = DiscountsMarkupsServer.CalculateDiscountsMarkupsTree(CalculationParameters, InputParameters);
	
	If InputParameters.ApplyToObject Then
		DiscountsMarkupsServer.ApplyDiscountCalculationResultToObject(Object, "Inventory", DiscountsMarkupsApplied.TableDiscountsMarkups);
	EndIf;
	
	Return DiscountsMarkupsApplied;
	
EndFunction // CalculateByGoodsSales()

// The function calculates discounts by goods sales.
//
Function CalculateByWorkCompletionCertificate(Object, InputParameters)
	Var Workplace;
	
	DiscountsMarkupsServer.FillLinkingKeysInSpreadsheetPartProducts(Object, "WorksAndServices");
	
	If InputParameters.Property("SalesExceedingOrder") Then
		SalesExceedingOrder = InputParameters.SalesExceedingOrder;
	Else
		SalesExceedingOrder = False;
	EndIf;
	
	// Processing of spreadsheet part "JobsAndServices".
	Products = Object.WorksAndServices.Unload(
		,
		"ConnectionKey,
		|ProductsAndServices,
		|Characteristic,
		|MeasurementUnit,
		|Quantity,
		|Price,
		|CustomerOrder"
	);
	
	If SalesExceedingOrder Then
		GoodsBeyondOrder = Products.CopyColumns();
		
		For Each CurrentRow IN Products Do
			If Not ValueIsFilled(CurrentRow.CustomerOrder) Then
				NewRow = GoodsBeyondOrder.Add();
				FillPropertyValues(NewRow, CurrentRow);
			EndIf;
		EndDo;
	Else
		GoodsBeyondOrder = "";
	EndIf;
	
	ObjectCurrentDate = DiscountsMarkupsServer.GetObjectCurrentDate(Object);
	
	CalculationParameters = New Structure;
	CalculationParameters.Insert("DiscountsMarkups", GetDiscountsMarkupsTableForWholesale(Object, Object.Counterparty, InputParameters));
	CalculationParameters.Insert("Recorder"  , Object.Ref);
	CalculationParameters.Insert("Shop"      , Object.Division);
	
	CalculationParameters.Insert("SalesWarehouse"            , Object.Division);
	//CalculationParameters.Insert("MinimumSalesPricesKind", ShopDetails.MinimumSalesPricesKind);
	
	CalculationParameters.Insert("Products",            Products);
	CalculationParameters.Insert("DocumentCurrency",   Object.DocumentCurrency);
	CalculationParameters.Insert("ManagementAccountingCurrency",   Constants.AccountingCurrency.Get());
	CalculationParameters.Insert("User",      Undefined);
	CalculationParameters.Insert("CurrentDate",       ObjectCurrentDate);
	CalculationParameters.Insert("SharedUsageVariant", Constants.DiscountsMarkupsSharedUsageOptions.Get());
	
	DiscountsMarkupsApplied = DiscountsMarkupsServer.CalculateDiscountsMarkupsTree(CalculationParameters, InputParameters);
	
	If InputParameters.ApplyToObject Then
		DiscountsMarkupsServer.ApplyDiscountCalculationResultToObject(Object, "WorksAndServices", DiscountsMarkupsApplied.TableDiscountsMarkups, SalesExceedingOrder, GoodsBeyondOrder);
	EndIf;
	
	Return DiscountsMarkupsApplied;
	
EndFunction // CalculateByGoodsSales()

#EndRegion
