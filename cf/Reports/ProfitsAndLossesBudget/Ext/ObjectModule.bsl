#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	ReportSettings = SettingsComposer.GetSettings();
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);
	
	DataCompositionParameter = CompositionTemplate.ParameterValues.Find("EndOfPeriod");
	If Not DataCompositionParameter = Undefined Then
		
		If TypeOf(DataCompositionParameter.Value) = Type("Date")
			AND DataCompositionParameter.Value = Date(1,1,1) THEN 
		
			DataCompositionParameter.Value = Date(3999,12,31,23,59,59);
			
		Else
			
			DataCompositionParameter.Value = EndOfDay(DataCompositionParameter.Value);
			
		EndIf;
	
	EndIf;
	
	DataCompositionParameter = CompositionTemplate.ParameterValues.Find("EmptyDateEnd");
	If Not DataCompositionParameter = Undefined Then
		
		If TypeOf(DataCompositionParameter.Value) = Type("Date")
			AND DataCompositionParameter.Value = Date(1,1,1) THEN 
		
			DataCompositionParameter.Value = Date(3999,12,31,23,59,59);
			
		Else
			
			DataCompositionParameter.Value = EndOfDay(DataCompositionParameter.Value);
			
		EndIf;
	
	EndIf;
	
EndProcedure

#EndIf