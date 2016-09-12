#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)

	ReportSettings = SettingsComposer.GetSettings();
	
	ParameterBeginOfPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("BeginOfPeriod"));
	ParameterEndOfPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("EndOfPeriod"));
	
	If ParameterBeginOfPeriod <> Undefined AND ParameterBeginOfPeriod.Use
		AND ParameterEndOfPeriod <> Undefined AND ParameterEndOfPeriod.Use
		AND TypeOf(ParameterBeginOfPeriod.Value) = Type("StandardBeginningDate")
		AND TypeOf(ParameterEndOfPeriod.Value) = Type("StandardBeginningDate")
		AND ParameterBeginOfPeriod.Value.Date <> Date(1,1,1)
		AND ParameterEndOfPeriod.Value.Date <> Date(1,1,1)
		AND ParameterBeginOfPeriod.Value.Date > ParameterEndOfPeriod.Value.Date Then
		
		Message = New UserMessage;
		Message.Text	 = NStr("en='Start period date must not exceed the end date!';ru='Дата начала периода не должна превышать дату окончания!'");
		Message.Message();
		
		StandardProcessing = False;
		Return;
		
	EndIf;
	
	DCTitle = ThisObject.SettingsComposer.Settings.OutputParameters.Items.Find("Title");
	DCTitle.Value = "Month closing report from " + Format(ParameterEndOfPeriod.Value, "DF='MMMM yyyy'") + " g.";
	
EndProcedure

#EndIf