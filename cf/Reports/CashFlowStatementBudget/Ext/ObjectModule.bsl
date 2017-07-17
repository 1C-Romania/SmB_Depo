#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	ReportSettings = SettingsComposer.GetSettings();
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);
	
	ParameterPlanningPeriod = CompositionTemplate.ParameterValues.Find("PlanningPeriodUser");
	If ParameterPlanningPeriod = Undefined
		OR Not ValueIsFilled(ParameterPlanningPeriod.Value) Then
		
		Message 			= New UserMessage;
		Message.Text	 	= NStr("en='Before generating the report, fill in the ""Planning period"" parameter value.';ru='Перед формированием отчета значение параметра ""Период планирования"" должно быть заполнено.'");
		Message.Message();
		
		StandardProcessing = False;
		
	EndIf;
	
	ParameterEndOfPeriod = CompositionTemplate.ParameterValues.Find("EndOfPeriod");
	If Not ParameterEndOfPeriod = Undefined Then
		
		If TypeOf(ParameterEndOfPeriod.Value) = Type("Date")
			AND ParameterEndOfPeriod.Value = Date(1,1,1) THEN 
		
			ParameterEndOfPeriod.Value = Date(3999,12,31,23,59,59);
			
		Else
			
			ParameterEndOfPeriod.Value = EndOfDay(ParameterEndOfPeriod.Value);
			
		EndIf;
	
	EndIf;
	
EndProcedure

#EndIf