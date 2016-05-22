#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Copies items from one collection to another
Procedure CopyFilterItems(ReceiverValues, ValueSource) 
	
	ReceiverElements = ReceiverValues.Items;
	SourceElements = ValueSource.Items;
	ReceiverElements.Clear();
	
	For Each ItemSource IN SourceElements Do
		
		ItemReceiver = ReceiverElements.Add(TypeOf(ItemSource));
		FillPropertyValues(ItemReceiver, ItemSource);
		
	EndDo;
	
EndProcedure

Procedure FillParameters(ReceiverValues, BeginOfPeriod, EndOfPeriod)
	
	ItemReceiver = ReceiverValues.FindParameterValue(New DataCompositionParameter("BeginOfPeriod"));
	If ItemReceiver <> Undefined Then
		ItemReceiver.Value = BeginOfPeriod;
	EndIf;	
	
	ItemReceiver = ReceiverValues.FindParameterValue(New DataCompositionParameter("EndOfPeriod"));
	If ItemReceiver <> Undefined Then
		ItemReceiver.Value = EndOfPeriod;
	EndIf;	
	
EndProcedure

// Adds grouping to the settings composer on the lowest structure level if the field is not specified - detailed fields
Function AddGrouping(SettingsComposer, Val Field = Undefined, Rows = True)
	
	StructureItem = GetLastStructureItem(SettingsComposer, Rows);
	Field = New DataCompositionField(Field);
	NewGroup = StructureItem.Structure.Add(Type("DataCompositionGroup"));
	
	NewGroup.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	NewGroup.Order.Items.Add(Type("DataCompositionAutoOrderItem"));
	GroupingField = NewGroup.GroupFields.Items.Add(Type("DataCompositionGroupField"));
	GroupingField.Field = Field;
	
	Return NewGroup;
	
EndFunction

// Returns the last item of structure - grouping
Function GetLastStructureItem(SettingsStructureItem, Rows = True) Export
	
	If TypeOf(SettingsStructureItem) = Type("DataCompositionSettingsComposer") Then
		Settings = SettingsStructureItem.Settings;
	ElsIf TypeOf(SettingsStructureItem) = Type("DataCompositionSettings") Then
		Settings = SettingsStructureItem;
	Else
		Return Undefined;
	EndIf;
	
	Structure = Settings.Structure;
	If Structure.Count() = 0 Then
		Return Settings;
	EndIf;
	
	If Rows Then
		NameStructureTable = "Rows";
		NameStructureChart = "Series";
	Else
		NameStructureTable = "Columns";
		NameStructureChart = "Points";
	EndIf;
	
	While True Do
		StructureItem = Structure[0];
		If TypeOf(StructureItem) = Type("DataCompositionTable") AND StructureItem[NameStructureTable].Count() > 0 Then
			If StructureItem[NameStructureTable][0].Structure.Count() = 0 Then
				Structure = StructureItem[NameStructureTable];
				Break;
			EndIf;
			Structure = StructureItem[NameStructureTable][0].Structure;
		ElsIf TypeOf(StructureItem) = Type("DataCompositionChart") AND StructureItem[NameStructureChart].Count() > 0 Then
			If StructureItem[NameStructureChart][0].Structure.Count() = 0 Then
				Structure = StructureItem[NameStructureChart];
				Break;
			EndIf;
			Structure = StructureItem[NameStructureChart][0].Structure;
		ElsIf TypeOf(StructureItem) = Type("DataCompositionGroup")
			  OR TypeOf(StructureItem) = Type("DataCompositionTableGroup")
			  OR TypeOf(StructureItem) = Type("DataCompositionChartGroup") Then
			If StructureItem.Structure.Count() = 0 Then
				Break;
			EndIf;
			Structure = StructureItem.Structure;
		ElsIf TypeOf(StructureItem) = Type("DataCompositionTable") Then
			Return StructureItem[NameStructureTable];
		ElsIf TypeOf(StructureItem) = Type("DataCompositionChart")	Then
			Return StructureItem[NameStructureChart];
		Else
			Return StructureItem;
		EndIf;
	EndDo;
	
	Return Structure[0];
	
EndFunction

// Adds grouping to the settings composer on the lowest structure level if the field is not specified - detailed fields
//
Procedure AddSelectedFieldDCS(DataCompositionGroup, Field)
	
	SelectedField               = DataCompositionGroup.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field          = New DataCompositionField(Field);
	SelectedField.Use = True;
	
EndProcedure // AddSelectedFieldDCS()

// Copies table in table with certain column types
// 
Function GenerateTableParameter(Table)
	
	TableParameter = New ValueTable;
	Array = New Array;
	
	Array.Add(Type("Number"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();	
	TableParameter.Columns.Add("QuantityOpeningBalance", TypeDescription);
	TableParameter.Columns.Add("QuantityClosingBalance", TypeDescription);
	
	Array.Add(Type("CatalogRef.ProductsAndServices"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	TableParameter.Columns.Add("ProductsAndServices", TypeDescription);
	
	Array.Add(Type("CatalogRef.Companies"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	TableParameter.Columns.Add("Company", TypeDescription);
	
	Array.Add(Type("CatalogRef.ProductsAndServicesBatches"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	TableParameter.Columns.Add("Batch", TypeDescription);
	
	Array.Add(Type("Date"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();	
	TableParameter.Columns.Add("Period", TypeDescription);
	
	Array.Add(Type("CatalogRef.StructuralUnits"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	TableParameter.Columns.Add("StructuralUnit", TypeDescription);
	
	Array.Add(Type("ChartOfAccountsRef.Managerial"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	TableParameter.Columns.Add("GLAccount", TypeDescription);
	
	Array.Add(Type("CatalogRef.ProductsAndServicesCharacteristics"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	TableParameter.Columns.Add("Characteristic", TypeDescription);
	
	For Each TableRow IN Table Do
		NewRow = TableParameter.Add();
		FillPropertyValues(NewRow, TableRow);
	EndDo;
	
	Return TableParameter
	
EndFunction

Function PrepareReportParameters(ReportSettings)
	
	BeginOfPeriod = Date(1,1,1);
	EndOfPeriod  = Date(1,1,1);
	Periodicity = Enums.Periodicity.Month;
	TitleOutput = False;
	Title = "Inventory turnover";
	
	ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("ItmPeriod"));
	If ParameterPeriod <> Undefined AND ParameterPeriod.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess Then
		If ParameterPeriod.Use
			AND ValueIsFilled(ParameterPeriod.Value) Then
			
			BeginOfPeriod = ParameterPeriod.Value.StartDate;
			EndOfPeriod  = ParameterPeriod.Value.EndDate;
		EndIf;
	EndIf;
	
	ParameterPeriodicity = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("Periodicity"));
	If ParameterPeriodicity <> Undefined
		AND ParameterPeriodicity.Use
		AND ValueIsFilled(ParameterPeriodicity.Value) Then
		
		Periodicity = ParameterPeriodicity.Value;
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
	ReportParameters.Insert("BeginOfPeriod" , BeginOfPeriod);
	ReportParameters.Insert("EndOfPeriod"   , EndOfPeriod);
	ReportParameters.Insert("Periodicity"   , Periodicity);
	ReportParameters.Insert("TitleOutput"   , TitleOutput);
	ReportParameters.Insert("Title"         , Title);
	ReportParameters.Insert("ReportId"      , "InventoryTurnover");
	ReportParameters.Insert("ReportSettings", ReportSettings);
	
	
	Return ReportParameters;
	
EndFunction

#EndRegion

#Region EventsHandlers

// Event handler OnResultCompose
//
Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)

	StandardProcessing = False;
		
	ReportSettings = SettingsComposer.GetSettings();
	ReportParameters = PrepareReportParameters(ReportSettings);
	
	SmallBusinessReports.SetReportAppearanceTemplate(ReportSettings);
	SmallBusinessReports.OutputReportTitle(ReportParameters, ResultDocument);
	
	// Find set parameters in settings 
	For Each Item IN ReportSettings.DataParameters.Items Do
		
		If Item.Parameter = New DataCompositionParameter("ItmPeriod") Then
			
			If Item.Use AND ValueIsFilled(Item.Value) Then
				
				BeginOfPeriod = Item.Value.StartDate;
				EndOfPeriod  = Item.Value.EndDate;
				
			Else
				
				BeginOfPeriod = '00010101';
				EndOfPeriod = EndOfDay(CurrentDate());
				
			EndIf;
			
		ElsIf Item.Parameter = New DataCompositionParameter("Periodicity") Then
			
			If Item.Use AND ValueIsFilled(Item.Value) Then
				Periodicity = Item.Value;
			Else
				Periodicity = "Month";
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// Get the table with volumes
	DCS = GetTemplate("SchemaAverageVolume");
	DCS.DataSets.DataSetMiddleVolume.Query = StrReplace(DCS.DataSets.DataSetMiddleVolume.Query, "MONTH", Periodicity);
	DataSettingsComposer = New DataCompositionSettingsComposer;
	DataSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DCS));
	DataSettingsComposer.LoadSettings(DCS.DefaultSettings);
	
	DataSettingsComposer.Settings.Structure.Clear();
	Group = AddGrouping(DataSettingsComposer, "");
	
	AddSelectedFieldDCS(Group, "Company");
	AddSelectedFieldDCS(Group, "StructuralUnit");
	AddSelectedFieldDCS(Group, "GLAccount");
	AddSelectedFieldDCS(Group, "ProductsAndServices");
	AddSelectedFieldDCS(Group, "Characteristic");
	AddSelectedFieldDCS(Group, "Batch");
	AddSelectedFieldDCS(Group, "Period");
	AddSelectedFieldDCS(Group, "QuantityOpeningBalance");
	AddSelectedFieldDCS(Group, "QuantityClosingBalance");
	
	CopyFilterItems(DataSettingsComposer.Settings.Filter, ReportSettings.Filter);
	FillParameters(DataSettingsComposer.Settings.DataParameters, BeginOfPeriod, EndOfPeriod);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DCS, DataSettingsComposer.GetSettings(), , , Type("DataCompositionValueCollectionTemplateGenerator"), , );
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, , , True);	
	Table = New ValueTable;	
	
	OutputProcessor = New DataCompositionResultValueCollectionOutputProcessor;
	OutputProcessor.SetObject(Table);	
	OutputProcessor.Output(CompositionProcessor, True);	
	
	// Calculate the average volume	
	Query = New Query(
	"SELECT
	|	InventoryBalanceAndTurnovers.Company AS Company,
	|	InventoryBalanceAndTurnovers.StructuralUnit AS StructuralUnit,
	|	InventoryBalanceAndTurnovers.GLAccount AS GLAccount,
	|	InventoryBalanceAndTurnovers.ProductsAndServices AS ProductsAndServices,
	|	InventoryBalanceAndTurnovers.Characteristic AS Characteristic,
	|	InventoryBalanceAndTurnovers.Batch AS Batch,
	|	BEGINOFPERIOD(InventoryBalanceAndTurnovers.Period, &PeriodicityText) AS Period,
	|	InventoryBalanceAndTurnovers.QuantityOpeningBalance AS QuantityOpeningBalance,
	|	InventoryBalanceAndTurnovers.QuantityClosingBalance AS QuantityClosingBalance
	|INTO TableAverageVolume
	|FROM
	|	&TableAverageVolume AS InventoryBalanceAndTurnovers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryBalanceAndTurnovers.Company AS Company,
	|	InventoryBalanceAndTurnovers.StructuralUnit AS StructuralUnit,
	|	InventoryBalanceAndTurnovers.GLAccount AS GLAccount,
	|	InventoryBalanceAndTurnovers.ProductsAndServices AS ProductsAndServices,
	|	InventoryBalanceAndTurnovers.Characteristic AS Characteristic,
	|	InventoryBalanceAndTurnovers.Batch AS Batch,
	|	InventoryBalanceAndTurnovers.Period AS Period,
	|	InventoryBalanceAndTurnovers.QuantityOpeningBalance AS QuantityOpeningBalance,
	|	InventoryBalanceAndTurnovers.QuantityClosingBalance AS QuantityClosingBalance
	|FROM
	|	TableAverageVolume AS InventoryBalanceAndTurnovers
	|
	|ORDER BY
	|	Company,
	|	StructuralUnit,
	|	GLAccount,
	|	ProductsAndServices,
	|	Characteristic,
	|	Batch,
	|	Period
	|TOTALS
	|	SUM(QuantityOpeningBalance),
	|	SUM(QuantityClosingBalance)
	|BY
	|	Company,
	|	StructuralUnit,
	|	GLAccount,
	|	ProductsAndServices,
	|	Characteristic,
	|	Batch,
	|	Period PERIODS(&PeriodicityText, &BeginOfPeriod, &EndOfPeriod)");
	
	Query.Text = StrReplace(Query.Text, "&PeriodicityText", Periodicity);
	Query.SetParameter("BeginOfPeriod", BeginOfPeriod);
	Query.SetParameter("EndOfPeriod", EndOfPeriod);
	Query.SetParameter("TableAverageVolume", GenerateTableParameter(Table));
	
	ResultsArray = Query.ExecuteBatch();
	QueryResult = ResultsArray[1];
	
	ResultTable = QueryResult.Unload();
	SourceTable = ResultTable.CopyColumns();
	Array = New Array;
	Array.Add(Type("Number"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	SourceTable.Columns.Add("AverageVolume", TypeDescription);
	SourceTable.Columns.Add("NumberOfPeriodDays", TypeDescription);
	SourceTable.Columns.Delete("QuantityOpeningBalance");
	SourceTable.Columns.Delete("QuantityClosingBalance");
	
	NumberOfPeriodDays = (EndOfPeriod + 1 - BeginOfPeriod)/(60*60*24);
	
	SelectionCompany = QueryResult.Select(QueryResultIteration.ByGroups, "Company");
	While SelectionCompany.Next() Do
		SelectionStructuralUnit = SelectionCompany.Select(QueryResultIteration.ByGroups, "StructuralUnit");
		While SelectionStructuralUnit.Next() Do
			SelectionGlAccount = SelectionStructuralUnit.Select(QueryResultIteration.ByGroups, "GLAccount");
			While SelectionGlAccount.Next() Do
				SelectionProductsAndServices = SelectionGlAccount.Select(QueryResultIteration.ByGroups, "ProductsAndServices");
				While SelectionProductsAndServices.Next() Do
					SelectionCharacteristic = SelectionProductsAndServices.Select(QueryResultIteration.ByGroups, "Characteristic");
					While SelectionCharacteristic.Next() Do
						SelectionBatch = SelectionCharacteristic.Select(QueryResultIteration.ByGroups, "Batch");
						While SelectionBatch.Next() Do
							
							Counter = 0;
							Amount = 0;
							QuantityOpeningBalance = 0;
							QuantityClosingBalance = 0;
							
							NewRow = SourceTable.Add();
							FillPropertyValues(NewRow, SelectionBatch);
							
							SelectionPeriod = SelectionBatch.Select(QueryResultIteration.ByGroups, "Period", "ALL");
							While SelectionPeriod.Next() Do
								
								If SelectionPeriod.QuantityOpeningBalance <> NULL Then
									QuantityOpeningBalance = SelectionPeriod.QuantityOpeningBalance;
									QuantityClosingBalance = SelectionPeriod.QuantityClosingBalance;
								EndIf; 
								
								Counter = Counter + 1;
								Amount = Amount + ?(Counter = 1, QuantityOpeningBalance, 0) + QuantityClosingBalance;
									
							EndDo;
							
							If Counter = 0 Then
								NewRow.AverageVolume = 0;
							Else
							    NewRow.AverageVolume = Amount / (Counter + 1);
							EndIf;
							
							NewRow.NumberOfPeriodDays = NumberOfPeriodDays;
							
						EndDo;
					EndDo;	
				EndDo;
			EndDo;
		EndDo;	
	EndDo; 
	
	ParameterStructure = New Structure("TableAverageVolume", SourceTable);
	
	ArrayHeaderResources = New Array; 
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);
	
	//Create and initialize a composition processor
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ParameterStructure, DetailsData, True);

	//Create and initialize the result output processor
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	
	//Indicate the output begin
	OutputProcessor.BeginOutput();
	TableFixed = False;

	ResultDocument.FixedTop = 0;
	//Main cycle of the report output
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

EndProcedure

#EndRegion

#EndIf