
Procedure SetFilterByPeriod(FilterList, StartDate, EndDate, FieldFilterName = "Date") Export
	
	// Filter by period
	GroupFilterByPeriod = CommonUseClientServer.CreateGroupOfFilterItems(
		FilterList.Items,
		"Period",
		DataCompositionFilterItemsGroupType.AndGroup);
	
	CommonUseClientServer.AddCompositionItem(
		GroupFilterByPeriod,
		FieldFilterName,
		DataCompositionComparisonType.GreaterOrEqual,
		StartDate,
		"StartDate",
		ValueIsFilled(StartDate));
	
	CommonUseClientServer.AddCompositionItem(
		GroupFilterByPeriod,
		FieldFilterName,
		DataCompositionComparisonType.LessOrEqual,
		EndDate,
		"EndDate",
		ValueIsFilled(EndDate));
		
EndProcedure
	
Function RefreshPeriodPresentation(Period) Export
	
	If Not ValueIsFilled(Period) Or (Not ValueIsFilled(Period.StartDate) And Not ValueIsFilled(Period.EndDate)) Then
		PeriodPresentation = NStr("ru = 'Период: за все время'; en = 'Period: during all this time'");
	Else
		EndDate = ?(ValueIsFilled(Period.EndDate), EndOfDay(Period.EndDate), Period.EndDate);
		If EndDate < Period.StartDate Then
			#If Client Then
			SmallBusinessClient.ShowMessageAboutError(Undefined, NStr("ru = 'Выбрана дата окончания периода, которая меньше даты начала!'; en = 'Selected date end of the period, which is less than the start date!'"));
			#EndIf
			PeriodPresentation = NStr("ru = 'с '; en = 'from '")+Format(Period.StartDate,"DF=dd.MM.yyyy");
		Else
			PeriodPresentation = NStr("ru = 'за '; en = 'for '")+Lower(PeriodPresentation(Period.StartDate, EndDate));
		EndIf; 
	EndIf;
	
	Return PeriodPresentation;
	
EndFunction

