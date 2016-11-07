#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure event handler "OnResultComposition" object
//
Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	
	ThisObject.ReportNumber = ThisObject.ReportNumber + 1;

	//Check period parameters
	If Not StartDate = Date(1,1,1)
		AND Not EndDate = Date(1,1,1)
		AND StartDate > EndDate Then
		
		Message	 		= New UserMessage;
		Message.Text	 	= "Begin of the period can not be greater than end of period";
		Message.Message();
		
		Return;
		
	EndIf;
	
	ResultDocument.Put(GenerateReportTORG29(
		StartDate,
		EndDate,
		StructuralUnit,
		Company,
		ReportNumber
	));
	
EndProcedure // OnResultComposition()

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns the last item of structure - grouping
Function GetLastStructureItem(SettingsStructureItem, Rows = True)
	
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

// Returns grouping - detailed records of the setting composer
Function GetStructureItemDetailRecords(SettingsComposer)
	
	LastStructureItem = GetLastStructureItem(SettingsComposer, True);
	If TypeOf(LastStructureItem) = Type("DataCompositionGroup")
	 OR TypeOf(LastStructureItem) = Type("DataCompositionTableGroup")
	 OR TypeOf(LastStructureItem) = Type("DataCompositionChartGroup") Then
		If LastStructureItem.GroupFields.Items.Count() = 0 Then
			Return LastStructureItem;
		EndIf;
	EndIf;
	
EndFunction

// Adds grouping to the settings composer on the lowest structure level if the field is not specified - detailed fields
Function AddGrouping(SettingsComposer, Val Field = Undefined, Rows = True)
	
	StructureItem = GetLastStructureItem(SettingsComposer, Rows);
	If StructureItem = Undefined 
	 OR GetStructureItemDetailRecords(SettingsComposer) <> Undefined 
	   AND Field = Undefined Then
		Return Undefined;
	EndIf;
	
	If TypeOf(Field) = Type("String") Then
		Field = New DataCompositionField(Field);
	EndIf;
	
	If TypeOf(StructureItem) = Type("DataCompositionTableGroup") 
	 OR TypeOf(StructureItem) = Type("DataCompositionChartGroup") Then
		NewGroup = StructureItem.Structure.Add();
	ElsIf TypeOf(StructureItem) = Type("DataCompositionTableStructureItemCollection")
			OR TypeOf(StructureItem) = Type("DataCompositionChartStructureItemCollection") Then
		NewGroup = StructureItem.Add();
	Else
		NewGroup = StructureItem.Structure.Add(Type("DataCompositionGroup"));
	EndIf;
	
	NewGroup.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	NewGroup.Order.Items.Add(Type("DataCompositionAutoOrderItem"));
	If Field <> Undefined Then
		GroupingField = NewGroup.GroupFields.Items.Add(Type("DataCompositionGroupField"));
		GroupingField.Field = Field;
	EndIf;
	Return NewGroup;
	
EndFunction

Function SetParameter(Settings, Parameter, Value, Use = true)
	
	ParameterValue = Undefined;
	FieldParameter = ?(TypeOf(Parameter) = Type("String"), New DataCompositionParameter(Parameter), Parameter);
	
	If TypeOf(Settings) = Type("DataCompositionSettings") Then
		ParameterValue = Settings.DataParameters.FindParameterValue(FieldParameter);
	ElsIf TypeOf(Settings) = Type("DataCompositionUserSettings") Then
		For Each SettingItem in Settings.Items Do
			If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue") and SettingItem.Parameter = FieldParameter Then
				ParameterValue = SettingItem;
				Break;
			EndIf;
		EndDo;
	ElsIf TypeOf(Settings) = Type("DataCompositionSettingsComposer") Then
		For Each SettingItem in Settings.UserSettings.Items Do
			If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue") and SettingItem.Parameter = FieldParameter Then
				ParameterValue = SettingItem;
				Break;
			EndIf;
		EndDo;
		If ParameterValue = Undefined Then
			ParameterValue = Settings.Settings.DataParameters.FindParameterValue(FieldParameter);
		EndIf;
	EndIf;
	
	ParameterValue.Value = Value;
	ParameterValue.Use = Use;
	
	Return ParameterValue;
EndFunction

// Sets output parameter of setting composer
Function SetOutputParameter(SettingsComposerGroup, ParameterName, Value)
	
	If TypeOf(SettingsComposerGroup) = Type("DataCompositionSettingsComposer") Then
		ParameterValue = SettingsComposerGroup.Settings.OutputParameters.FindParameterValue(New DataCompositionParameter(ParameterName));
	Else
		ParameterValue = SettingsComposerGroup.OutputParameters.FindParameterValue(New DataCompositionParameter(ParameterName));
	EndIf;
	If ParameterValue = Undefined Then
		Return Undefined;
	Else
		ParameterValue.Use = True;
		ParameterValue.Value = Value;
		Return ParameterValue;
	EndIf;
	
EndFunction

// Adds filter in composer filter set or filter groups
Function AddFilter(StructureItem, Val Field, Value, ComparisonType = Undefined, Use = True)
	
	If TypeOf(Field) = Type("String") Then
		Field = New DataCompositionField(Field);
	EndIf;
	
	If TypeOf(StructureItem) = Type("DataCompositionSettingsComposer") Then
		Filter = StructureItem.Settings.Filter;
	ElsIf TypeOf(StructureItem) = Type("DataCompositionSettings") Then
		Filter = StructureItem.Filter;
	Else
		Filter = StructureItem;
	EndIf;
	
	If ComparisonType = Undefined Then
		ComparisonType = DataCompositionComparisonType.Equal;
	EndIf;
	
	NewItem = Filter.Items.Add(Type("DataCompositionFilterItem"));
	NewItem.Use  = Use;
	NewItem.LeftValue  = Field;
	NewItem.ComparisonType   = ComparisonType;
	NewItem.RightValue = Value;
	Return NewItem;
	
EndFunction

// Standard for this configuration function of amounts formatting
//
// Parameters: 
//  Amount   - number that we want to format,
//  Currency - reference to the item of currencies catalog if set, then
//             currency presentation will be added to the resulting string
//  NZ       - String that represents the zero value of the number, 
//  NGS      - character-separator of groups of number integral part.
//
// Returns:
//  Properly formatted string representation of the amount.
//
Function AmountsFormat(Amount, Currency = Undefined, NZ = "", NGS = "")

	FormatString = "ND=15;NFD=2" +
					?(NOT ValueIsFilled(NZ), "", ";" + "NZ=" + NZ) +
					?(NOT ValueIsFilled(NGS),"", ";" + "NGS=" + NGS);
	ResultString = TrimL(Format(Amount, FormatString));
	
	If ValueIsFilled(Currency) Then
		ResultString = ResultString + " " + TrimR(Currency);
	EndIf;

	Return ResultString;

EndFunction // AmountsFormat()

// Function performs tabular document formation of report Torg-29.
//
// Parameters: 
//  Amount   - number that we want to format, 
//  Currency - reference to the item of currencies catalog if set, then
//            currency presentation will be added to the resulting string
//  NZ       - String that represents the zero value of the number,
//  NGS      - character-separator of groups of number integral part.
//
// Returns:
//  Properly formatted string representation of the amount.
//
Function GenerateReportTORG29(StartDate, EndDate, StructuralUnit, Company, ReportNumber)
	
	Spreadsheet = New SpreadsheetDocument;
	
	Template = GetTemplate("Template");
	
	// Display title.
	InfoAboutCustomer = SmallBusinessServer.InfoAboutLegalEntityIndividual(Company, EndDate, ,);
	
	TemplateArea = Template.GetArea("Title");
	TemplateArea.Parameters.CompanyPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCustomer);
	TemplateArea.Parameters.StructuralUnitPresentation = StructuralUnit.Description;
	TemplateArea.Parameters.CompilationDate = CurrentDate();
	TemplateArea.Parameters.StartDate = StartDate;
	TemplateArea.Parameters.EndDate = EndDate;
	TemplateArea.Parameters.CompanyByOKPO = InfoAboutCustomer.CodeByOKPO;
	FRPName = StructuralUnit.FRP.Description;
	TemplateArea.Parameters.FRP = ?(ValueIsFilled(FRPName), FRPName, "");
	
	Query = New Query();
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	Employees.Code AS ICEmployeeCode
	|FROM
	|	Catalog.Employees AS Employees
	|WHERE
	|	Employees.Ind = &Ind";
	Query.SetParameter("Ind", StructuralUnit.FRP);
	SelectionOfQueryResult = Query.Execute().Select();
	
	If SelectionOfQueryResult.Next() Then
		TemplateArea.Parameters.ICEmployeeCode = ?(ValueIsFilled(SelectionOfQueryResult.ICEmployeeCode), SelectionOfQueryResult.ICEmployeeCode, "");
	EndIf;
	
	TemplateArea.Parameters.Number = ReportNumber;
	
	Spreadsheet.Put(TemplateArea);
	
	TemplateArea = Template.GetArea("Header");
	Spreadsheet.Put(TemplateArea);
	
	// Recurrence header
	RepeatOnRowPrint = Spreadsheet.Area(1 + TemplateArea.TableHeight, ,2 + TemplateArea.TableHeight);
	
	DataCompositionSchema = GetTemplate("MainDataCompositionSchema");
	
	// Preparation layout composer of data configuration.
	Composer = New DataCompositionSettingsComposer;
	Composer.Initialize(New DataCompositionAvailableSettingsSource(DataCompositionSchema));
	Composer.LoadSettings(DataCompositionSchema.DefaultSettings);
	
	// Selected fields.
	MandatoryFields = New Array;
	MandatoryFields.Add("SecondPeriod");
	MandatoryFields.Add("Recorder");
	MandatoryFields.Add("AmountOpeningBalance");
	MandatoryFields.Add("AmountReceipt");
	MandatoryFields.Add("AmountExpense");
	MandatoryFields.Add("AmountClosingBalance");
	Composer.Settings.Selection.Items.Clear();
	For Each MandatoryField IN MandatoryFields Do
		DCSField = DataProcessors.PrintLabelsAndTags.FindDCSFieldByDescriptionFull(Composer.Settings.Selection.SelectionAvailableFields.Items, MandatoryField);
		If DCSField <> Undefined Then
			SelectedField = Composer.Settings.Selection.Items.Add(Type("DataCompositionSelectedField"));
			SelectedField.Field = DCSField.Field;
		EndIf;
	EndDo;
	
	// Groups.
	Composer.Settings.Structure.Clear();
	AddGrouping(Composer, "SecondPeriod");
	AddGrouping(Composer, "Recorder");
	
	// TotalDisconnection.
	SetOutputParameter(Composer,"VerticalOverallPlacement", DataCompositionTotalPlacement.None);
	SetOutputParameter(Composer,"HorizontalOverallPlacement", DataCompositionTotalPlacement.None);
	
	// Filters.
	AddFilter(Composer, "StructuralUnit", StructuralUnit);
	
	// Setting parameter "Price kinds"
	ParameterPriceKind = New DataCompositionParameter("PriceKind");
	ParameterValuePriceKind = Composer.Settings.DataParameters.FindParameterValue(ParameterPriceKind);
	If ParameterValuePriceKind <> Undefined Then
		ParameterValuePriceKind.Value = StructuralUnit.RetailPriceKind;
		ParameterValuePriceKind.Use = True;
	EndIf;
	
	Period = New StandardPeriod;
	Period.StartDate    = BegOfDay(StartDate);
	Period.EndDate = EndOfDay(EndDate);
	SetParameter(Composer.Settings, "PeriodOfReport", Period);
	
	
	// Layout configuration of data configuration.
	TemplateComposer = New DataCompositionTemplateComposer;
	DataCompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, Composer.Settings,,,Type("DataCompositionValueCollectionTemplateGenerator"));
	
	// Build a value table.
	Processor = New DataCompositionProcessor;
	Processor.Initialize(DataCompositionTemplate);
	OutputProcessor = New DataCompositionResultValueCollectionOutputProcessor();
	SourceData = New ValueTable;
	OutputProcessor.SetObject(SourceData);
	OutputProcessor.Output(Processor);
	
	Query = New Query(
	"SELECT ALLOWED DISTINCT
	|	Table.SecondPeriod AS SecondPeriod,
	|	IsNULL(Table.Recorder, UNDEFINED) AS Recorder,
	|	Table.AmountOpeningBalance AS BegBal,
	|	Table.AmountReceipt AS Receipt,
	|	Table.AmountExpense AS Expense,
	|	Table.AmountClosingBalance AS EndBal
	|INTO TableSourceData
	|FROM
	|	&SourceData AS Table
	|WHERE Not Table.Recorder = Undefined
	|	AND Table.SecondPeriod >= &BeginOfPeriod
	|	AND Table.SecondPeriod <= &EndOfPeriod
	|;
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Table.SecondPeriod AS SecondPeriod,
	|	Table.Recorder AS Recorder,
	|	Table.Recorder.Date AS RecorderDate,
	|	Table.Recorder.Number AS RecorderNumber,
	|	Table.BegBal AS BegBal,
	|	Table.Receipt AS Receipt,
	|	Table.Expense AS Expense,
	|	Table.EndBal AS EndBal
	|INTO DocumentsTable
	|FROM
	|	TableSourceData AS Table
	|;
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CASE
	|		WHEN DocumentsTable.Recorder REFS Document.ReceiptCR
	|				OR DocumentsTable.Recorder REFS Document.ReceiptCRReturn
	|			THEN DocumentsTable.Recorder.CashCRSession
	|		ELSE DocumentsTable.Recorder
	|	END AS Document,
	|	CASE
	|		WHEN DocumentsTable.Recorder REFS Document.ReceiptCR
	|				OR DocumentsTable.Recorder REFS Document.ReceiptCRReturn
	|			THEN DocumentsTable.Recorder.CashCRSession.Date
	|		ELSE 
	|			CASE 
	|				WHEN DocumentsTable.RecorderDate <> DATETIME(1,1,1,0,0,0) 
	|					THEN DocumentsTable.RecorderDate
	|				ELSE DocumentsTable.SecondPeriod
	|			END
	|	END AS DocDate,
	|	CASE
	|		WHEN DocumentsTable.Recorder REFS Document.ReceiptCR
	|				OR DocumentsTable.Recorder REFS Document.ReceiptCRReturn
	|			THEN DocumentsTable.Recorder.CashCRSession.Number
	|		ELSE DocumentsTable.RecorderNumber
	|	END AS DocNo,
	|	SUM(DocumentsTable.Receipt) AS Receipt,
	|	SUM(DocumentsTable.Expense) AS Expense
	|FROM
	|	DocumentsTable AS DocumentsTable
	|
	|GROUP BY
	|	CASE
	|		WHEN DocumentsTable.Recorder REFS Document.ReceiptCR
	|				OR DocumentsTable.Recorder REFS Document.ReceiptCRReturn
	|			THEN DocumentsTable.Recorder.CashCRSession
	|		ELSE DocumentsTable.Recorder
	|	END,
	|	CASE
	|		WHEN DocumentsTable.Recorder REFS Document.ReceiptCR
	|				OR DocumentsTable.Recorder REFS Document.ReceiptCRReturn
	|			THEN DocumentsTable.Recorder.CashCRSession.Date
	|		ELSE 
	|			CASE 
	|				WHEN DocumentsTable.RecorderDate <> DATETIME(1,1,1,0,0,0) 
	|					THEN DocumentsTable.RecorderDate
	|				ELSE DocumentsTable.SecondPeriod
	|			END
	|	END,
	|	CASE
	|		WHEN DocumentsTable.Recorder REFS Document.ReceiptCR
	|				OR DocumentsTable.Recorder REFS Document.ReceiptCRReturn
	|			THEN DocumentsTable.Recorder.CashCRSession.Number
	|		ELSE DocumentsTable.RecorderNumber
	|	END
	|
	|ORDER BY
	|	DocDate,
	|	Document
	|");
	
	Query.SetParameter("SourceData", 	SourceData);
	
	Query.SetParameter("BeginOfPeriod", 		BegOfDay(StartDate));
	Query.SetParameter("EndOfPeriod",	EndOfDay(EndDate));
	
	QueryResult = Query.Execute().Unload();
	
	If SourceData.Count() = 0 Then
		
		BegBal = 0;
		EndBal = 0;
		
	Else
		
		If SourceData[0].AmountOpeningBalance = NULL Then
			BegBal = 0;
		Else
			
			If SourceData.Count() > 1 Then
				
				If SourceData[0].Recorder = Undefined AND SourceData[1].Recorder <> Undefined Then
					BegBal = SourceData[1].AmountOpeningBalance;
				Else
					BegBal = SourceData[0].AmountOpeningBalance;
				EndIf;
				
			Else
				BegBal = SourceData[0].AmountOpeningBalance;
			EndIf;
			
		EndIf;
		
		If SourceData[SourceData.Count()-1].AmountClosingBalance = NULL Then
			EndBal = 0;
		Else
			EndBal = SourceData[SourceData.Count()-1].AmountClosingBalance;
		EndIf;
		
	EndIf;
	
	TemplateArea = Template.GetArea("BalanceBeginning");
	TemplateArea.Parameters.StartDate = "Balance on " + Format(StartDate, "DLF=D");
	TemplateArea.Parameters.BegCostTotal = AmountsFormat(BegBal);
	Spreadsheet.Put(TemplateArea);
	
	TemplateArea = Template.GetArea("Receipt");
	Spreadsheet.Put(TemplateArea);
	
	TemplateArea = Template.GetArea("String");
	For Each VTRow IN QueryResult Do
		
		If VTRow.Receipt = 0 Then
			Continue;
		EndIf;
		
		TemplateArea.Parameters.doc = VTRow.Document;
		TemplateArea.Parameters.Details = VTRow.Document;
		TemplateArea.Parameters.DocumentDate = VTRow.DocDate;
		TemplateArea.Parameters.DocumentNumber = Format(VTRow.DocNo,"ND=11; NLZ=; NG=0");
		TemplateArea.Parameters.ProductAmount = AmountsFormat(VTRow.Receipt);
		TemplateArea.Parameters.SumPackaging = AmountsFormat(0);
		Spreadsheet.Put(TemplateArea);
		
	EndDo;
	
	Receipt = QueryResult.Total("Receipt");
	
	TemplateArea = Template.GetArea("TotalReceipt");
	TemplateArea.Parameters.CostShipmentNo = AmountsFormat(Receipt);
	Spreadsheet.Put(TemplateArea);
	
	TemplateArea = Template.GetArea("TotalAmountReceipt");
	TemplateArea.Parameters.ReceiptWithBalance = AmountsFormat(Receipt + BegBal);
	Spreadsheet.Put(TemplateArea);
	
	Spreadsheet.PutHorizontalPageBreak();
	
	TemplateArea = Template.GetArea("Expense");
	Spreadsheet.Put(TemplateArea);
	
	TemplateArea = Template.GetArea("String");
	For Each VTRow IN QueryResult Do
		
		If VTRow.Expense = 0 Then
			Continue;
		EndIf;
		
		TemplateArea.Parameters.doc = VTRow.Document;
		TemplateArea.Parameters.Details = VTRow.Document;
		TemplateArea.Parameters.DocumentDate = VTRow.DocDate;
		TemplateArea.Parameters.DocumentNumber = Format(VTRow.DocNo,"ND=11; NLZ=; NG=0");
		TemplateArea.Parameters.ProductAmount = AmountsFormat(VTRow.Expense);
		TemplateArea.Parameters.SumPackaging = AmountsFormat(0);
		Spreadsheet.Put(TemplateArea);
		
	EndDo;
	
	Expense = QueryResult.Total("Expense");
	
	TemplateArea = Template.GetArea("TotalAmountExpense");
	TemplateArea.Parameters.ShipAndInvoiceTotalCost = AmountsFormat(Expense);
	Spreadsheet.Put(TemplateArea);
	
	TemplateArea = Template.GetArea("BalanceEnd");
	TemplateArea.Parameters.EndDate = "Balance on " + Format(EndDate, "DLF=D");
	TemplateArea.Parameters.EndCostTotal = AmountsFormat(EndBal);
	Spreadsheet.Put(TemplateArea);
	
	TemplateArea = Template.GetArea("Footer");
	//TemplateArea.Parameters.FRP = ?(ValueIsFilled(SelFRP), SelFRP, "");
	Spreadsheet.Put(TemplateArea);
	
	Spreadsheet.RepeatOnRowPrint = RepeatOnRowPrint;
	
	Return Spreadsheet;
	
EndFunction // GenerateReportTORG29()

#EndRegion

#EndIf