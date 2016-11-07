#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)

	StandardProcessing = False;
	
	ReportSettings = SettingsComposer.GetSettings();
	ReportParameters = PrepareReportParameters(ReportSettings);
	
	SmallBusinessReports.SetReportAppearanceTemplate(ReportSettings);
	SmallBusinessReports.OutputReportTitle(ReportParameters, ResultDocument);
	SmallBusinessReports.CustomizeDynamicPeriod(DataCompositionSchema, ReportParameters, False);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);
	
	ExternalDataSets = GetExternalDataSets(ReportParameters, CompositionTemplate);
	
	//Create and initialize a composition processor
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, DetailsData, True);

	//Create and initialize the result output processor
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);

	//Indicate the output begin
	OutputProcessor.BeginOutput();
	TableFixed = False;

	ResultDocument.FixedTop = 0;
	
	//Main cycle of the report output
	AreasForDeletion = New Array;
	ChartsQuantity = 0;
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
			
			If ResultDocument.Drawings.Count() > ChartsQuantity Then
				
				ChartsQuantity = ResultDocument.Drawings.Count();
				CurrentPicture = ResultDocument.Drawings[ChartsQuantity-1];
				If TypeOf(CurrentPicture.Object) = Type("Chart") Then
					
					SmallBusinessReports.SetReportChartSize(CurrentPicture);
					
					CurrentLineNumber = ResultDocument.TableHeight;
					Area = ResultDocument.Area(CurrentLineNumber - 6,,CurrentLineNumber);
					AreasForDeletion.Add(Area);
				EndIf;
			EndIf;
			
		EndIf;
	EndDo;

	OutputProcessor.EndOutput();
	
	For Each Area IN AreasForDeletion Do
		ResultDocument.DeleteArea(Area, SpreadsheetDocumentShiftType.Vertical);
	EndDo;
	
	SmallBusinessReports.ProcessReportCharts(ReportParameters, ResultDocument);
	
EndProcedure

Function PrepareReportParameters(ReportSettings)
	
	BeginOfPeriod = Date(1,1,1);
	EndOfPeriod  = Date(1,1,1);
	Periodicity = Enums.Periodicity.Auto;
	ChartTypeReport = Undefined;
	TitleOutput = False;
	Title = "Accounts receivable dynamics";
	
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
	ReportParameters.Insert("BeginOfPeriod"        , BeginOfPeriod);
	ReportParameters.Insert("EndOfPeriod"         , EndOfPeriod);
	ReportParameters.Insert("Periodicity"            , Periodicity);
	ReportParameters.Insert("ChartType"             , ChartTypeReport);
	ReportParameters.Insert("TitleOutput"        , TitleOutput);
	ReportParameters.Insert("Title"                , Title);
	ReportParameters.Insert("ReportId"      , "AccountsReceivableDynamics");
	ReportParameters.Insert("ReportSettings", ReportSettings);
		
	Return ReportParameters;
	
EndFunction

Function GetExternalDataSets(ReportParameters, CompositionTemplate) Export
	
	TableDebt = New ValueTable;
	TableDebt.Columns.Add("Period");
	TableDebt.Columns.Add("Company");
	TableDebt.Columns.Add("Counterparty");
	TableDebt.Columns.Add("Contract");
	TableDebt.Columns.Add("Debt");
	TableDebt.Columns.Add("OverdueDebt");
	
	BeginOfPeriod = BegOfDay(ReportParameters.BeginOfPeriod);
	EndOfPeriod  = ?(ValueIsFilled(ReportParameters.EndOfPeriod), EndOfDay(ReportParameters.EndOfPeriod), ReportParameters.EndOfPeriod);
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	MIN(AccountsPayable.Period) AS BeginOfPeriod,
	|	MAX(AccountsPayable.Period) AS EndOfPeriod
	|FROM
	|	AccumulationRegister.AccountsPayable AS AccountsPayable";
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		Selection = Result.Select();
		Selection.Next();
		//BeginOfPeriod = Max(BeginOfPeriod, Selection.BeginOfPeriod);
		BeginOfPeriod = Max(BeginOfPeriod, ?(Selection.BeginOfPeriod=NULL,'00010101',Selection.BeginOfPeriod));
		If Not ValueIsFilled(EndOfPeriod) Then
			//EndOfPeriod = Selection.EndOfPeriod; //RISE Temnikov
			EndOfPeriod= Selection.EndOfPeriod;
		Else
			//EndOfPeriod = min(EndOfPeriod, Selection.EndOfPeriod); //RISE Temnikov
			EndOfPeriod = Min(EndOfPeriod, ?(Selection.EndOfPeriod = NULL,'00010101',Selection.EndOfPeriod));
		EndIf;
	EndIf;
	
	PeriodsTable = New ValueTable;
	PeriodsTable.Columns.Add("BeginOfPeriod");
	PeriodsTable.Columns.Add("EndOfPeriod");
	
	If ReportParameters.Periodicity <> Enums.Periodicity.Auto Then
		Periodicity = ReportParameters.Periodicity;
	Else
		Periodicity = SmallBusinessReports.GetPeriodicityValue(ReportParameters.BeginOfPeriod, ReportParameters.EndOfPeriod);
	EndIf;
		
	CurrentDate = BeginOfPeriod;
	
	While CurrentDate <= EndOfPeriod Do
		NewRow = PeriodsTable.Add();
		If Periodicity = Enums.Periodicity.Day Then // Day
			NewRow.BeginOfPeriod = BegOfDay(CurrentDate);
			NewRow.EndOfPeriod  = EndOfDay(CurrentDate);
			
			CurrentDate = CurrentDate + 86400;
		ElsIf Periodicity = Enums.Periodicity.Week Then // Week
			NewRow.BeginOfPeriod = BegOfWeek(CurrentDate);
			NewRow.EndOfPeriod  = EndOfWeek(CurrentDate);
			
			CurrentDate = EndOfWeek(CurrentDate) + 86400 * 7;
		ElsIf Periodicity = Enums.Periodicity.Month Then // Month
			NewRow.BeginOfPeriod = BegOfMonth(CurrentDate);
			NewRow.EndOfPeriod  = EndOfMonth(CurrentDate);
			
			CurrentDate = AddMonth(BegOfMonth(CurrentDate), 1);
		ElsIf Periodicity = Enums.Periodicity.Quarter Then // Quarter
			NewRow.BeginOfPeriod = BegOfQuarter(CurrentDate);
			NewRow.EndOfPeriod  = EndOfQuarter(CurrentDate);
			
			CurrentDate = AddMonth(BegOfQuarter(CurrentDate), 3);
		ElsIf Periodicity = Enums.Periodicity.HalfYear Then // HalfYear
			If Month(CurrentDate) > 6 Then
				NewRow.BeginOfPeriod = BegOfDay(Date(Year(CurrentDate), 7, 1));
				NewRow.EndOfPeriod  = EndOfYear(CurrentDate);
			Else
				NewRow.BeginOfPeriod = BegOfDay(Date(Year(CurrentDate), 1, 1));
				NewRow.EndOfPeriod  = EndOfMonth(Date(Year(CurrentDate), 6, 1));
			EndIf;
			
			CurrentDate = AddMonth(CurrentDate, 6);
		ElsIf Periodicity = Enums.Periodicity.Year Then // Year
			NewRow.BeginOfPeriod = BegOfYear(CurrentDate);
			NewRow.EndOfPeriod  = EndOfYear(CurrentDate);
			
			CurrentDate = AddMonth(BegOfYear(CurrentDate), 12);
		EndIf;
	EndDo;
	
	For Each Period IN PeriodsTable Do
			TemporaryTable = GetDebt(ReportParameters, Period.EndOfPeriod);
			For Each TableRow IN TemporaryTable Do
				NewRow = TableDebt.Add();
				FillPropertyValues(NewRow, TableRow);
				NewRow.Period = Period.BeginOfPeriod;
			EndDo;
	EndDo;
	
	ExternalDataSets = New Structure("TableDebt", TableDebt);
	Return ExternalDataSets;
	
EndFunction

Function GetDebt(ReportParameters, EndDate)
		
	Query = New Query;
	Query.SetParameter("Period", EndOfDay(EndDate));
	
	Query.Text = 
	"SELECT ALLOWED
	|	AccountsPayableBalances.Company,
	|	AccountsPayableBalances.Counterparty,
	|	AccountsPayableBalances.Contract,
	|	AccountsPayableBalances.Document.Date AS DateAccountingDocument,
	|	CASE
	|		WHEN AccountsPayableBalances.Contract.VendorPaymentDueDate > 0
	|			THEN AccountsPayableBalances.Contract.VendorPaymentDueDate
	|		WHEN VendorPaymentDueDate.Value > 0
	|			THEN VendorPaymentDueDate.Value
	|		ELSE 0
	|	END AS VendorPaymentDueDate,
	|	AccountsPayableBalances.AmountBalance
	|INTO Tu_AccountsPayable
	|FROM
	|	AccumulationRegister.AccountsPayable.Balance AS AccountsPayableBalances,
	|	Constant.VendorPaymentDueDate AS VendorPaymentDueDate
	|WHERE
	|	AccountsPayableBalances.Document <> UNDEFINED
	|	AND AccountsPayableBalances.AmountBalance > 0
	|	AND AccountsPayableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|	AND DATEDIFF(AccountsPayableBalances.Document.Date, &Period, Day) >= 0
	|	AND AccountsPayableBalances.AmountCurBalance > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsPayable.Company,
	|	AccountsPayable.Counterparty,
	|	AccountsPayable.Contract,
	|	AccountsPayable.AmountBalance AS Debt,
	|	CASE
	|		WHEN AccountsPayable.VendorPaymentDueDate > 0
	|				AND DATEDIFF(AccountsPayable.DateAccountingDocument, &Period, Day) > AccountsPayable.VendorPaymentDueDate
	|			THEN AccountsPayable.AmountBalance
	|		ELSE 0
	|	END AS OverdueDebt
	|FROM
	|	Tu_AccountsPayable AS AccountsPayable";
	
	Return Query.Execute().Unload();
	
EndFunction

#EndIf