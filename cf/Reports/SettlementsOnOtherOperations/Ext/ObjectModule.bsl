#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)

	StandardProcessing = False;
	
	ReportSettings = SettingsComposer.GetSettings();
	
	ReportParameters = PrepareReportParameters(ReportSettings);
	
	SmallBusinessReports.SetReportAppearanceTemplate(ReportSettings);
	SmallBusinessReports.OutputReportTitle(ReportParameters, ResultDocument);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);

	DataCompositionParameterValue = CompositionTemplate.ParameterValues.Find("EndOfPeriod");
	If DataCompositionParameterValue = Undefined Then
		NewParameterValue = CompositionTemplate.ParameterValues.Add();
		NewParameterValue.Name = "EndOfPeriod";
		NewParameterValue.Value = Date(3999,12,31,23,59,59);
	EndIf;
	
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

Function PrepareReportParameters(ReportSettings)
	
	BeginOfPeriod = Date(1,1,1);
	EndOfPeriod  = Date(1,1,1);
	Period = Date(1,1,1);
	TitleOutput = False;
	Title = NStr("ru = 'Расчеты по прочим операциям'; en = 'Settlements on other operations'");
	
	VariantBalance = False;
	
	ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("EndOfPeriod"));
	If ParameterPeriod <> Undefined AND ParameterPeriod.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess Then
		VariantBalance = True;
		If ParameterPeriod.Use Then
			If TypeOf(ParameterPeriod.Value) = Type("StandardBeginningDate") Then
				ParameterPeriod.Value.Date = EndOfDay(ParameterPeriod.Value.Date);
				Period = Format(ParameterPeriod.Value.Date, "DF=dd.MM.yyyy");
			Else
				ParameterPeriod.Value = EndOfDay(ParameterPeriod.Value);
				Period = Format(ParameterPeriod.Value, "DF=dd.MM.yyyy");
			EndIf;
		EndIf;
	EndIf;
	
	If Not VariantBalance Then
		ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("Period"));
		If ParameterPeriod <> Undefined AND ParameterPeriod.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess Then
			If ParameterPeriod.Use
				AND ValueIsFilled(ParameterPeriod.Value) Then
				
				BeginOfPeriod = ParameterPeriod.Value.StartDate;
				EndOfPeriod  = ParameterPeriod.Value.EndDate;
			EndIf;
		EndIf;
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
	If VariantBalance Then
		ReportParameters.Insert("Period", Period);
	Else
		ReportParameters.Insert("BeginOfPeriod",	BeginOfPeriod);
		ReportParameters.Insert("EndOfPeriod",		EndOfPeriod);
	EndIf;
	ReportParameters.Insert("TitleOutput",		TitleOutput);
	ReportParameters.Insert("Title",			Title);
	ReportParameters.Insert("ReportId",			"SettlementsOnOtherOperations");
	ReportParameters.Insert("ReportSettings",	ReportSettings);
		
	Return ReportParameters;
	
EndFunction

#EndIf