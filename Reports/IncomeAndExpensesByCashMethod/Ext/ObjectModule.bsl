#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)

	StandardProcessing = False;
	UserSettingsModified = False;
	
	SmallBusinessReports.ChangeGroupsValues(SettingsComposer, UserSettingsModified);
	
	ReportSettings = SettingsComposer.GetSettings();
	
	ReportParameters = PrepareReportParameters(ReportSettings);
	
	SmallBusinessReports.SetReportAppearanceTemplate(ReportSettings);
	SmallBusinessReports.OutputReportTitle(ReportParameters, ResultDocument);
	SmallBusinessReports.CustomizeDynamicPeriod(DataCompositionSchema, ReportParameters);
	
	//Setting horizontal group name by period for layout
	AvailableResources = New Array;
	For Each Item IN ReportSettings.Selection.SelectionAvailableFields.Items Do
		If Item.Resource Then
			AvailableResources.Add(Item.Field);
		EndIf;
	EndDo;
	
	SelectedResources = New Array;
	For Each Item IN ReportSettings.Selection.Items Do
		If TypeOf(Item) = Type("DataCompositionAutoSelectedField") Then
			Continue;
		EndIf;
		If Item.Use AND AvailableResources.Find(Item.Field) <> Undefined Then
			SelectedResources.Add(Item.Field);
		EndIf;
	EndDo;
	
	If SelectedResources.Count() = 1 Then
		For Each StructureItem IN ReportSettings.Structure Do
			If TypeOf(StructureItem) = Type("DataCompositionTable") Then
				If ReportSettings.Structure[1].Selection.Items.Count() = 0 Then
					For Each Column IN StructureItem.Columns Do
						If Column.Use Then
							If Column.GroupFields.Items[0].Use
								AND Column.GroupFields.Items[0].Field = New DataCompositionField("DynamicPeriod") Then
								Column.Name = "DynamicPeriodAcross";
							EndIf;
						EndIf;
					EndDo;
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);

	//Create and initialize a composition processor
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, , DetailsData, True);

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
	TitleOutput = False;
	Title = "Income and expenses (by payment)";
	
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
	ReportParameters.Insert("BeginOfPeriod"  , BeginOfPeriod);
	ReportParameters.Insert("EndOfPeriod"    , EndOfPeriod);
	ReportParameters.Insert("Periodicity"    , Periodicity);
	ReportParameters.Insert("TitleOutput"    , TitleOutput);
	ReportParameters.Insert("Title"          , Title);
	ReportParameters.Insert("ReportId"       , "IncomeAndExpensesByCashMethod");
	ReportParameters.Insert("ReportSettings" , ReportSettings);
		
	Return ReportParameters;
	
EndFunction

#EndIf