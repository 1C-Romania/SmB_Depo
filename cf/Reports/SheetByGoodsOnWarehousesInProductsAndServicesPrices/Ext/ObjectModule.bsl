#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	
	// From attribute to the composer
	ParameterKindOfPrice							= New DataCompositionParameter("PriceKind");
	ValueOfParameterPriceKind 				= SettingsComposer.Settings.DataParameters.FindParameterValue(ParameterKindOfPrice);
	If Not ValueOfParameterPriceKind = Undefined Then
		
		ValueOfParameterPriceKind.Value 		= PriceKind;
		ValueOfParameterPriceKind.Use 	= True;
		
	EndIf;
	
	ReportSettings = SettingsComposer.GetSettings();
	ReportParameters = PrepareReportParameters(ReportSettings);
	
	SmallBusinessReports.SetReportAppearanceTemplate(ReportSettings);
	SmallBusinessReports.OutputReportTitle(ReportParameters, ResultDocument);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);
	
	BeginOfPeriod = Date(1,1,1);
	EndOfPeriod = Date(1,1,1);
	
	ParameterBeginOfPeriod = CompositionTemplate.ParameterValues.Find("BeginOfPeriod");
	If Not ParameterBeginOfPeriod = Undefined Then
		BeginOfPeriod = ParameterBeginOfPeriod.Value;
	EndIf;
	
	ParameterEndOfPeriod = CompositionTemplate.ParameterValues.Find("EndOfPeriod");
	If Not ParameterEndOfPeriod = Undefined Then
		EndOfPeriod = ParameterEndOfPeriod.Value;
	EndIf;
	
	// Create and initialize the processor layout and precheck parameters
	If Not BeginOfPeriod = Date(1,1,1)
		AND Not EndOfPeriod = Date(1,1,1)
		AND BeginOfPeriod > EndOfPeriod Then
		
		MessageText	 	= NStr("en='Period start cannot be greater than period end';ru='Дата начала периода не должна превышать дату окончания.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
		Return;
		
	EndIf;
	
	If Not ValueIsFilled(PriceKind)
		OR CompositionTemplate.ParameterValues["PriceKind"].Value = Catalogs.PriceKinds.EmptyRef() Then
		
		MessageText	 	= NStr("en='The price kind for report generation is not selected.';ru='Не выбран вид цены для формирования отчета.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
		Return;
		
	EndIf;
	
	CalculationTable 			= GetCalculationTable(BeginOfPeriod, EndOfPeriod);
	ExternalDataSets 		= New Structure("CalculationTable", CalculationTable);
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, DetailsData, True);

	// Create and initialize the result output processor
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);

	// Indicate the output begin
	OutputProcessor.BeginOutput();
	TableFixed = False;

	ResultDocument.FixedTop = 0;
	// Main cycle of the report output
	While True Do
		//Get the next item of a composition result
		ResultItem = CompositionProcessor.Next();

		If ResultItem = Undefined Then
			//The next item is not received - end the output cycle
			Break;
		Else
			// Fix header
			If  Not TableFixed 
				  AND ResultItem.ParameterValues.Count() > 0 
				  AND TypeOf(SettingsComposer.Settings.Structure[0]) <> Type("DataCompositionChart") Then

				TableFixed = True;
				ResultDocument.FixedTop = ResultDocument.TableHeight;

			EndIf;
			//Item is received - output it using an output processor
			OutputProcessor.OutputItem(ResultItem);
		EndIf;
	EndDo;

	OutputProcessor.EndOutput();
	
EndProcedure // OnResultComposition()

// Generate a table of balances and register records 
//
Function GetCalculationTable(BeginOfPeriod, EndOfPeriod)
	
	//T.k. in the base there are documents that were
	//registered by one time, add extra bypass cycle with arrangement of the documents order.
	Query							= New Query;
	Query.Text					= 
	"SELECT ALLOWED
	|	InventoryInWarehouses.SecondPeriod AS SecondPeriod,
	|	InventoryInWarehouses.Recorder AS Recorder,
	|	InventoryInWarehouses.ProductsAndServices AS ProductsAndServices,
	|	InventoryInWarehouses.Characteristic AS Characteristic,
	|	InventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|	ISNULL(InventoryInWarehouses.QuantityOpeningBalance, 0) AS QuantityOpeningBalance,
	|	ISNULL(InventoryInWarehouses.QuantityReceipt, 0) AS QuantityReceipt,
	|	ISNULL(InventoryInWarehouses.QuantityExpense, 0) AS QuantityExpense,
	|	ISNULL(InventoryInWarehouses.QuantityClosingBalance, 0) AS QuantityClosingBalance,
	|	InventoryInWarehouses.Recorder.PointInTime AS RecorderPointInTime,
	|	0 AS Order
	|FROM
	|	AccumulationRegister.InventoryInWarehouses.BalanceAndTurnovers(&BeginOfPeriod, &EndOfPeriod, AUTO, , ) AS InventoryInWarehouses
	|
	|ORDER BY
	|	RecorderPointInTime";
	
	Query.SetParameter("BeginOfPeriod",	BeginOfPeriod);
	Query.SetParameter("EndOfPeriod",	EndOfPeriod);
	
	InventoryRegisterRecordsTable = Query.Execute().Unload();
	
	For Each InventoryItemRegisterRecord IN InventoryRegisterRecordsTable Do
		
		InventoryItemRegisterRecord.Order = InventoryRegisterRecordsTable.IndexOf(InventoryItemRegisterRecord) + 1;
		
	EndDo;
	
	Query.Text					= 
	"SELECT
	|	InventoryInWarehouses.SecondPeriod AS Period,
	|	InventoryInWarehouses.Recorder AS Recorder,
	|	InventoryInWarehouses.ProductsAndServices AS ProductsAndServices,
	|	InventoryInWarehouses.Characteristic AS Characteristic,
	|	InventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|	InventoryInWarehouses.QuantityOpeningBalance,
	|	InventoryInWarehouses.QuantityReceipt,
	|	InventoryInWarehouses.QuantityExpense,
	|	InventoryInWarehouses.QuantityClosingBalance,
	|	InventoryInWarehouses.Order
	|INTO BalanceAndTurnovers
	|FROM
	|	&BalanceAndTurnovers AS InventoryInWarehouses
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	BEGINOFPERIOD(PricesTable.Period, Day) AS Period,
	|	PricesTable.Recorder,
	|	PricesTable.ProductsAndServices,
	|	PricesTable.Characteristic,
	|	ProductsAndServicesPricesActual.Price,
	|	ISNULL(ProductsAndServicesPricesPrevious.Price, 0) AS OldPrice,
	|	ProductsAndServicesPricesActual.Price - ISNULL(ProductsAndServicesPricesPrevious.Price, 0) AS Delta
	|INTO PriceChanges
	|FROM
	|	(SELECT
	|		ActualPrices.Period AS Period,
	|		MAX(PricesBeforeChanges.Period) AS LastChangeDate,
	|		""Change of the price"" AS Recorder,
	|		ActualPrices.PriceKind AS PriceKind,
	|		ActualPrices.ProductsAndServices AS ProductsAndServices,
	|		ActualPrices.Characteristic AS Characteristic
	|	FROM
	|		InformationRegister.ProductsAndServicesPrices AS ActualPrices
	|			LEFT JOIN InformationRegister.ProductsAndServicesPrices AS PricesBeforeChanges
	|			ON ActualPrices.ProductsAndServices = PricesBeforeChanges.ProductsAndServices
	|				AND ActualPrices.Characteristic = PricesBeforeChanges.Characteristic
	|				AND (PricesBeforeChanges.PriceKind = &PriceKind)
	|				AND ActualPrices.Period > PricesBeforeChanges.Period
	|	WHERE
	|		ActualPrices.PriceKind = &PriceKind
	|	
	|	GROUP BY
	|		ActualPrices.PriceKind,
	|		ActualPrices.ProductsAndServices,
	|		ActualPrices.Characteristic,
	|		ActualPrices.Period) AS PricesTable
	|		LEFT JOIN InformationRegister.ProductsAndServicesPrices AS ProductsAndServicesPricesActual
	|		ON PricesTable.Period = ProductsAndServicesPricesActual.Period
	|			AND PricesTable.PriceKind = ProductsAndServicesPricesActual.PriceKind
	|			AND PricesTable.ProductsAndServices = ProductsAndServicesPricesActual.ProductsAndServices
	|			AND PricesTable.Characteristic = ProductsAndServicesPricesActual.Characteristic
	|		LEFT JOIN InformationRegister.ProductsAndServicesPrices AS ProductsAndServicesPricesPrevious
	|		ON PricesTable.LastChangeDate = ProductsAndServicesPricesPrevious.Period
	|			AND PricesTable.PriceKind = ProductsAndServicesPricesPrevious.PriceKind
	|			AND PricesTable.ProductsAndServices = ProductsAndServicesPricesPrevious.ProductsAndServices
	|			AND PricesTable.Characteristic = ProductsAndServicesPricesPrevious.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PriceKinds.PriceCurrency AS Currency,
	|	TableInventoryInWarehousesMaximumPeriod.RegisterRecordPeriod AS SecondPeriod,
	|	BEGINOFPERIOD(TableInventoryInWarehousesMaximumPeriod.RegisterRecordPeriod, MINUTE) AS MinutePeriod,
	|	BEGINOFPERIOD(TableInventoryInWarehousesMaximumPeriod.RegisterRecordPeriod, hour) AS HourPeriod,
	|	BEGINOFPERIOD(TableInventoryInWarehousesMaximumPeriod.RegisterRecordPeriod, Day) AS DayPeriod,
	|	BEGINOFPERIOD(TableInventoryInWarehousesMaximumPeriod.RegisterRecordPeriod, WEEK) AS WeekPeriod,
	|	BEGINOFPERIOD(TableInventoryInWarehousesMaximumPeriod.RegisterRecordPeriod, MONTH) AS MonthPeriod,
	|	BEGINOFPERIOD(TableInventoryInWarehousesMaximumPeriod.RegisterRecordPeriod, QUARTER) AS QuarterPeriod,
	|	BEGINOFPERIOD(TableInventoryInWarehousesMaximumPeriod.RegisterRecordPeriod, YEAR) AS YearPeriod,
	|	TableInventoryInWarehousesMaximumPeriod.Recorder,
	|	TableInventoryInWarehousesMaximumPeriod.StructuralUnit,
	|	TableInventoryInWarehousesMaximumPeriod.ProductsAndServices,
	|	TableInventoryInWarehousesMaximumPeriod.Characteristic,
	|	TableInventoryInWarehousesMaximumPeriod.QuantityOpeningBalance AS QuantityOpeningBalance,
	|	TableInventoryInWarehousesMaximumPeriod.QuantityReceipt AS QuantityReceipt,
	|	TableInventoryInWarehousesMaximumPeriod.QuantityExpense AS QuantityExpense,
	|	TableInventoryInWarehousesMaximumPeriod.QuantityClosingBalance AS QuantityClosingBalance,
	|	TableInventoryInWarehousesMaximumPeriod.QuantityOpeningBalance * ProductsAndServicesPrices.Price AS AmountOpeningBalance,
	|	TableInventoryInWarehousesMaximumPeriod.QuantityReceipt * ProductsAndServicesPrices.Price AS AmountReceipt,
	|	TableInventoryInWarehousesMaximumPeriod.QuantityExpense * ProductsAndServicesPrices.Price AS AmountExpense,
	|	TableInventoryInWarehousesMaximumPeriod.QuantityClosingBalance * ProductsAndServicesPrices.Price AS AmountClosingBalance,
	|	TableInventoryInWarehousesMaximumPeriod.Order AS Order,
	|	TableInventoryInWarehousesMaximumPeriod.RegisterRecordPeriod AS RegistrationDate,
	|	ProductsAndServicesPrices.Price AS CurrentPrice
	|FROM
	|	(SELECT
	|		InventoryInWarehouses.Period AS RegisterRecordPeriod,
	|		InventoryInWarehouses.Recorder AS Recorder,
	|		InventoryInWarehouses.ProductsAndServices AS ProductsAndServices,
	|		InventoryInWarehouses.Characteristic AS Characteristic,
	|		InventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|		InventoryInWarehouses.QuantityOpeningBalance AS QuantityOpeningBalance,
	|		InventoryInWarehouses.QuantityReceipt AS QuantityReceipt,
	|		InventoryInWarehouses.QuantityExpense AS QuantityExpense,
	|		InventoryInWarehouses.QuantityClosingBalance AS QuantityClosingBalance,
	|		InventoryInWarehouses.Order AS Order,
	|		MAX(ProductsAndServicesPrices.Period) AS PeriodMaximum
	|	FROM
	|		BalanceAndTurnovers AS InventoryInWarehouses
	|			LEFT JOIN PriceChanges AS ProductsAndServicesPrices
	|			ON InventoryInWarehouses.ProductsAndServices = ProductsAndServicesPrices.ProductsAndServices
	|				AND InventoryInWarehouses.Characteristic = ProductsAndServicesPrices.Characteristic
	|				AND InventoryInWarehouses.Period >= ProductsAndServicesPrices.Period
	|	{WHERE
	|		InventoryInWarehouses.ProductsAndServices,
	|		InventoryInWarehouses.Characteristic}
	|	
	|	GROUP BY
	|		InventoryInWarehouses.Period,
	|		InventoryInWarehouses.Recorder,
	|		InventoryInWarehouses.ProductsAndServices,
	|		InventoryInWarehouses.Characteristic,
	|		InventoryInWarehouses.StructuralUnit,
	|		InventoryInWarehouses.QuantityOpeningBalance,
	|		InventoryInWarehouses.QuantityReceipt,
	|		InventoryInWarehouses.QuantityExpense,
	|		InventoryInWarehouses.QuantityClosingBalance,
	|		InventoryInWarehouses.Order) AS TableInventoryInWarehousesMaximumPeriod
	|		LEFT JOIN PriceChanges AS ProductsAndServicesPrices
	|		ON TableInventoryInWarehousesMaximumPeriod.ProductsAndServices = ProductsAndServicesPrices.ProductsAndServices
	|			AND TableInventoryInWarehousesMaximumPeriod.Characteristic = ProductsAndServicesPrices.Characteristic
	|			AND TableInventoryInWarehousesMaximumPeriod.PeriodMaximum = ProductsAndServicesPrices.Period
	|		LEFT JOIN Catalog.PriceKinds AS PriceKinds
	|		ON (PriceKinds.Ref = &PriceKind)
	|
	|UNION ALL
	|
	|SELECT
	|	PriceKinds.PriceCurrency,
	|	ClosestBalancesByProductsAndServices.Period,
	|	BEGINOFPERIOD(ClosestBalancesByProductsAndServices.Period, MINUTE),
	|	BEGINOFPERIOD(ClosestBalancesByProductsAndServices.Period, hour),
	|	BEGINOFPERIOD(ClosestBalancesByProductsAndServices.Period, Day),
	|	BEGINOFPERIOD(ClosestBalancesByProductsAndServices.Period, WEEK),
	|	BEGINOFPERIOD(ClosestBalancesByProductsAndServices.Period, MONTH),
	|	BEGINOFPERIOD(ClosestBalancesByProductsAndServices.Period, QUARTER),
	|	BEGINOFPERIOD(ClosestBalancesByProductsAndServices.Period, YEAR),
	|	ClosestBalancesByProductsAndServices.Recorder,
	|	ClosestBalancesByProductsAndServices.StructuralUnit,
	|	ClosestBalancesByProductsAndServices.ProductsAndServices,
	|	ClosestBalancesByProductsAndServices.Characteristic,
	|	ISNULL(InventoryInWarehousesBalanceAndTurnovers.QuantityClosingBalance, 0),
	|	0,
	|	0,
	|	ISNULL(InventoryInWarehousesBalanceAndTurnovers.QuantityClosingBalance, 0),
	|	ISNULL(InventoryInWarehousesBalanceAndTurnovers.QuantityClosingBalance * ClosestBalancesByProductsAndServices.OldPrice, 0),
	|	CASE
	|		WHEN ClosestBalancesByProductsAndServices.Delta > 0
	|			THEN ISNULL(InventoryInWarehousesBalanceAndTurnovers.QuantityClosingBalance * ClosestBalancesByProductsAndServices.Delta, 0)
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN ClosestBalancesByProductsAndServices.Delta < 0
	|			THEN ISNULL(-InventoryInWarehousesBalanceAndTurnovers.QuantityClosingBalance * ClosestBalancesByProductsAndServices.Delta, 0)
	|		ELSE 0
	|	END,
	|	ISNULL(InventoryInWarehousesBalanceAndTurnovers.QuantityClosingBalance * ClosestBalancesByProductsAndServices.Price, 0),
	|	ClosestBalancesByProductsAndServices.Order,
	|	ClosestBalancesByProductsAndServices.Period,
	|	ClosestBalancesByProductsAndServices.Price
	|FROM
	|	(SELECT
	|		PriceChanges.Period AS Period,
	|		PriceChanges.Delta AS Delta,
	|		PriceChanges.Price AS Price,
	|		PriceChanges.OldPrice AS OldPrice,
	|		PriceChanges.ProductsAndServices AS ProductsAndServices,
	|		PriceChanges.Characteristic AS Characteristic,
	|		InventoryInWarehousesBalanceAndTurnovers.StructuralUnit AS StructuralUnit,
	|		MAX(InventoryInWarehousesBalanceAndTurnovers.Order) AS Order,
	|		PriceChanges.Recorder AS Recorder
	|	FROM
	|		PriceChanges AS PriceChanges
	|			LEFT JOIN BalanceAndTurnovers AS InventoryInWarehousesBalanceAndTurnovers
	|			ON PriceChanges.ProductsAndServices = InventoryInWarehousesBalanceAndTurnovers.ProductsAndServices
	|				AND PriceChanges.Characteristic = InventoryInWarehousesBalanceAndTurnovers.Characteristic
	|				AND PriceChanges.Period > InventoryInWarehousesBalanceAndTurnovers.Period
	|	WHERE
	|		PriceChanges.Period <= &EndOfPeriod
	|	{WHERE
	|		PriceChanges.ProductsAndServices.*,
	|		PriceChanges.Characteristic.*}
	|	
	|	GROUP BY
	|		PriceChanges.ProductsAndServices,
	|		InventoryInWarehousesBalanceAndTurnovers.StructuralUnit,
	|		PriceChanges.Characteristic,
	|		PriceChanges.Delta,
	|		PriceChanges.Price,
	|		PriceChanges.OldPrice,
	|		PriceChanges.Period,
	|		PriceChanges.Recorder) AS ClosestBalancesByProductsAndServices
	|		LEFT JOIN BalanceAndTurnovers AS InventoryInWarehousesBalanceAndTurnovers
	|		ON ClosestBalancesByProductsAndServices.ProductsAndServices = InventoryInWarehousesBalanceAndTurnovers.ProductsAndServices
	|			AND ClosestBalancesByProductsAndServices.Characteristic = InventoryInWarehousesBalanceAndTurnovers.Characteristic
	|			AND ClosestBalancesByProductsAndServices.StructuralUnit = InventoryInWarehousesBalanceAndTurnovers.StructuralUnit
	|			AND ClosestBalancesByProductsAndServices.Order = InventoryInWarehousesBalanceAndTurnovers.Order
	|		LEFT JOIN Catalog.PriceKinds AS PriceKinds
	|		ON (PriceKinds.Ref = &PriceKind)
	|WHERE
	|	ClosestBalancesByProductsAndServices.Order > 0
	|	AND InventoryInWarehousesBalanceAndTurnovers.Order > 0
	|
	|ORDER BY
	|	Order";
	
	
	Query.SetParameter("BalanceAndTurnovers", 	InventoryRegisterRecordsTable);
	Query.SetParameter("PriceKind", 			PriceKind);
	
	//See above
	//
	//Query.SetParameter("BeginOfPeriod", 		ReportObject.BeginOfPeriod);
	//Query.SetParameter("EndOfPeriod", 		ReportObject.EndOfPeriod);
	
	CalculationTable = Query.Execute().Unload();
	
	Return CalculationTable;
	
EndFunction //GetCalculationTable()

Function PrepareReportParameters(ReportSettings)
	
	BeginOfPeriod = Date(1,1,1);
	EndOfPeriod  = Date(1,1,1);
	TitleOutput = False;
	Title = "Goods in products and services prices";
	ParametersToBeIncludedInSelectionText = New Array;
	
	ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("BeginOfPeriod"));
	If ParameterPeriod <> Undefined
		AND ParameterPeriod.Use Then
		
		If TypeOf(ParameterPeriod.Value) = Type("StandardBeginningDate") Then
			BeginOfPeriod = ParameterPeriod.Value.Date;
		Else
			BeginOfPeriod = ParameterPeriod.Value;
		EndIf;
	EndIf;
	
	ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("EndOfPeriod"));
	If ParameterPeriod <> Undefined
		AND ParameterPeriod.Use Then
		
		If TypeOf(ParameterPeriod.Value) = Type("StandardBeginningDate") Then
			EndOfPeriod = ParameterPeriod.Value.Date;
		Else
			EndOfPeriod = ParameterPeriod.Value;
		EndIf;
	EndIf;
	
	ParameterKindOfPrice = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("PriceKind"));
	If ParameterKindOfPrice <> Undefined
		AND ParameterKindOfPrice.Use Then
		
		ParameterKindOfPrice.UserSettingPresentation = NStr("en='Price kind';ru='Вид цены'");
		ParametersToBeIncludedInSelectionText.Add(ParameterKindOfPrice);
	EndIf;
	
	ParameterOutputTitle = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("TitleOutput"));
	If ParameterOutputTitle <> Undefined
		AND ParameterOutputTitle.Use Then
		
		TitleOutput = ParameterOutputTitle.Value;
	EndIf;
	
	OutputParameter = ReportSettings.OutputParameters.FindParameterValue(New DataCompositionParameter("Title"));
	If OutputParameter <> Undefined
		AND OutputParameter.Use Then
		Title = OutputParameter.Value;
	EndIf;
	
	ReportParameters = New Structure;
	ReportParameters.Insert("BeginOfPeriod"                  , BeginOfPeriod);
	ReportParameters.Insert("EndOfPeriod"                   , EndOfPeriod);
	ReportParameters.Insert("TitleOutput"              , TitleOutput);
	ReportParameters.Insert("Title"                      , Title);
	ReportParameters.Insert("ParametersToBeIncludedInSelectionText", ParametersToBeIncludedInSelectionText);
	ReportParameters.Insert("ReportId"            , "SheetByGoodsOnWarehousesInProductsAndServicesPrices");
	ReportParameters.Insert("ReportSettings"	              , ReportSettings);
		
	Return ReportParameters;
	
EndFunction

#EndIf