#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)

	StandardProcessing = False;
	
	ReportSettings = SettingsComposer.GetSettings();
	
	// For platform 8.2.15.289 or higher, the parameters calculation is changed.
	DataCompositionParameter = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("EndOfPeriod"));
	If DataCompositionParameter <> Undefined Then
		
		If Not DataCompositionParameter.Use
			OR Not ValueIsFilled(DataCompositionParameter.Value) Then 
			DataCompositionParameter.Value = Date(3999,12,31,23,59,59);
		Else
			DataCompositionParameter.Value = EndOfDay(DataCompositionParameter.Value);
		EndIf;
		
	EndIf;
	
	DataCompositionParameter = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("Period"));
	If DataCompositionParameter <> Undefined Then
		
		If Not DataCompositionParameter.Use
			OR Not ValueIsFilled(DataCompositionParameter.Value) Then 
			DataCompositionParameter.Value = Date(3999,12,31,23,59,59);
		Else
			DataCompositionParameter.Value = EndOfDay(DataCompositionParameter.Value);
		EndIf;
		
	EndIf;
	
	DataCompositionParameter = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("FilterByOrders"));
	If DataCompositionParameter <> Undefined Then
		
		DataCompositionParameter.Value = FilterByOrderStatuses;
		DataCompositionParameter.Use = True;
		
	EndIf;
	
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

Function PrepareReportParameters(ReportSettings)
	
	TitleOutput = False;
	Title = "Order fulfillment";
	ParametersToBeIncludedInSelectionText = New Array;
	
	ParameterFilterByOrders = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("FilterByOrders"));
	If ParameterFilterByOrders <> Undefined
		AND ParameterFilterByOrders.Use Then
		
		ParametersToBeIncludedInSelectionText.Add(ParameterFilterByOrders);
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
	ReportParameters.Insert("TitleOutput"              , TitleOutput);
	ReportParameters.Insert("Title"                      , Title);
	ReportParameters.Insert("ParametersToBeIncludedInSelectionText", ParametersToBeIncludedInSelectionText);
	ReportParameters.Insert("ReportId"            , "CustomerOrdersAnalysis");
	ReportParameters.Insert("ReportSettings"	              , ReportSettings);
		
	Return ReportParameters;
	
EndFunction

#EndIf