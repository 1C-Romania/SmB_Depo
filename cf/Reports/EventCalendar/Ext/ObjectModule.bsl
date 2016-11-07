#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	
	DataParameters = SettingsComposer.Settings.DataParameters;
	
	SettingsParameterValue = DataParameters.FindParameterValue(New DataCompositionParameter("CurrentDate"));
	If SettingsParameterValue <> Undefined Then
		SettingsParameterValue.Value = CurrentDate();
		SettingsParameterValue.Use = True;
	EndIf;
	
	SettingsParameterValue = DataParameters.FindParameterValue(New DataCompositionParameter("EndOfPeriod"));
	If SettingsParameterValue <> Undefined Then
		SettingsParameterValue.Value = EndDateOfPeriodOf(PeriodOfFormation);
		SettingsParameterValue.Use = True;
	EndIf;
	
	ReportSettings = SettingsComposer.GetSettings();
	ReportParameters = PrepareReportParameters(ReportSettings);
	
	SmallBusinessReports.SetReportAppearanceTemplate(ReportSettings);
	SmallBusinessReports.OutputReportTitle(ReportParameters, ResultDocument);
	
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

Function EndDateOfPeriodOf(PeriodOfFormation)

	SecondsInDay = 24*60*60;
	
	If PeriodOfFormation = "Today" Then
		
		Return BegOfDay(CurrentDate() + SecondsInDay);
		
	ElsIf PeriodOfFormation = "For 3 days ahead" Then
		
		Return BegOfDay(CurrentDate() + 3 * SecondsInDay);
		
	ElsIf PeriodOfFormation = "For the week ahead" Then
		
		Return BegOfDay(CurrentDate() + 7 * SecondsInDay);
		
	ElsIf PeriodOfFormation = "For the month ahead" Then
		
		Return BegOfDay(AddMonth(CurrentDate(),1) + SecondsInDay);
		
	ElsIf PeriodOfFormation = "For three months ahead" Then
		
		Return BegOfDay(AddMonth(CurrentDate(),3) + SecondsInDay);
		
	ElsIf PeriodOfFormation = "For the half-year ahead" Then
		
		Return BegOfDay(AddMonth(CurrentDate(),6) + SecondsInDay);
		
	ElsIf PeriodOfFormation = "For the year ahead" Then
		
		Return BegOfDay(AddMonth(CurrentDate(),12) + SecondsInDay);
		
	EndIf;
	
	Return Date(1,1,1);

EndFunction

Function PrepareReportParameters(ReportSettings)
	
	Period  = Date(1,1,1);
	TitleOutput = False;
	Title = "Event calendar";
	
	ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("EndOfPeriod"));
	If ParameterPeriod <> Undefined
		AND ParameterPeriod.Use
		AND ValueIsFilled(ParameterPeriod.Value) Then
		
		Period  = ParameterPeriod.Value;
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
	ReportParameters.Insert("Period"             , Period);
	ReportParameters.Insert("TitleOutput"        , TitleOutput);
	ReportParameters.Insert("Title"              , Title);
	ReportParameters.Insert("ReportId"           , "EventCalendar");
	ReportParameters.Insert("ReportSettings"	   , ReportSettings);
		
	Return ReportParameters;
	
EndFunction

#EndIf