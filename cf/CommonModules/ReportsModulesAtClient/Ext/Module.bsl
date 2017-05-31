Function GetReportPeriodDescription(SettingsComposer,LanguageCode = "", SkipBlankPeriods = True) Export
		
	// period values
	PeriodParameterValue = ReportsModulesAtClientAtServer.GetSettingsParameter(SettingsComposer.Settings,"Period");
	BeginPeriodParameterValue =  ReportsModulesAtClientAtServer.GetSettingsParameter(SettingsComposer.Settings,"BeginOfPeriod");
	EndPeriodParameterValue =  ReportsModulesAtClientAtServer.GetSettingsParameter(SettingsComposer.Settings,"EndOfPeriod");
	
	If BeginPeriodParameterValue <> Undefined 
	   AND EndPeriodParameterValue <> Undefined Then
		BeginPeriod = BeginPeriodParameterValue.Value;
		If TypeOf(BeginPeriod) = Type("StandardBeginningDate") Then
			BeginPeriod = BeginPeriod.Date;
		EndIf;	
		EndPeriod = EndPeriodParameterValue.Value;
		If TypeOf(EndPeriod) = Type("StandardBeginningDate") Then
			EndPeriod = EndPeriod.Date;
		EndIf;	
		If BeginPeriod = '00010101' AND EndPeriod = '00010101' Then
			If SkipBlankPeriods Then
				PeriodDescription = "";
			Else	
				PeriodDescription = NStr("en='Period does not set';pl='Okres nie jest określony';ru='Период не указан'");
			EndIf;	
		ElsIf BeginPeriod = '00010101' OR EndPeriod = '00010101' Then
			PeriodDescription = Format(BeginPeriod, "DLF = D; DE = ...") + " - " + Format(EndPeriod, "DLF = D; DE = ...");
		ElsIf BegOfDay(BeginPeriod) = BegOfMonth(BeginPeriod) AND EndOfDay(EndPeriod) = EndOfMonth(EndPeriod) Then
			PeriodDescription = PeriodPresentation(BegOfDay(BeginPeriod), EndOfDay(EndPeriod), "FP = True"+?(NOT IsBlankString(LanguageCode),"; L ="+LanguageCode,""));
		ElsIf BeginPeriod <= EndPeriod Then
			PeriodDescription = Format(BegOfDay(BeginPeriod), "DLF = D; DE = ...") + " - " + Format(EndOfDay(EndPeriod), "DLF = D; DE = ...");
		Else
			PeriodDescription = NStr("en='Wrong period!';pl='Niepoprawny okres!';ru='Недопустимый период!'");
		EndIf;
	ElsIf PeriodParameterValue <> Undefined Then
		Period = PeriodParameterValue.Value;
		If Period = '00010101' Then
			PeriodDescription = NStr("en='on ';pl='na '") + Format(CurrentDate(), "DLF = D; DE = ...");
		Else
			PeriodDescription = NStr("en='on end of day ';pl='na koniec dnia '") + Format(Period, "DLF = D; DE = ...");
		EndIf;
	Else
		PeriodDescription = "";
	EndIf;
	
	// financial year values
	FinancialYearParameter = ReportsModulesAtClientAtServer.GetSettingsParameter(SettingsComposer.Settings,"FinancialYear");
	If FinancialYearParameter<>Undefined Then
		PeriodDescription = PeriodDescription + Nstr("en = 'Financial year: '; pl = 'Rok finansowy: '") + String(FinancialYearParameter.Value);
	EndIf;	
	
	Return PeriodDescription;
	
EndFunction	
