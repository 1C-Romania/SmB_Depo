
////////////////////////////////////////////////////////////////////////////////
// MODULE VARIABLES

&AtClient
Var WhenChangingStart;

&AtClient
Var WhenChangingFinish;

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsAndServicesOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	StructureData.Insert("Specification", SmallBusinessServer.GetDefaultSpecification(StructureData.ProductsAndServices));
	
	StructureData.Insert("ProductsAndServicesType", StructureData.ProductsAndServices.ProductsAndServicesType);
	
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData)
	
	StructureData.Insert("Specification", SmallBusinessServer.GetDefaultSpecification(StructureData.ProductsAndServices, StructureData.Characteristic));
	
	Return StructureData;
	
EndFunction // GetDataCharacteristicOnChange()

// Gets data set from server.
//
&AtServerNoContext
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("SubsidiaryCompany", SmallBusinessServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction // GetCompanyDataOnChange()

// Procedure is forming the mapping of operation kinds.
//
&AtServer
Procedure GetOperationKindsStructure()
	
	Structure = New Structure;
	
	Structure.Insert("Assembly", Enums.OperationKindsProductionOrder.Assembly);
	Structure.Insert("Disassembly", Enums.OperationKindsProductionOrder.Disassembly);
	
	OperationKinds = Structure;
	
EndProcedure // GetOperationKindsStructure()

// Procedure sets availability of the form items.
//
// Parameters:
//  No.
//
&AtServer
Procedure SetVisibleAndEnabled()
	
	If Object.OperationKind = Enums.OperationKindsProductionOrder.Disassembly Then
		
		// Products and services type.
		NewParameter = New ChoiceParameter("Filter.ProductsAndServicesType", Enums.ProductsAndServicesTypes.InventoryItem);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.ProductsProductsAndServices.ChoiceParameters = NewParameters;
		
	Else
		
		// Products and services type.
		NewArray = New Array();
		NewArray.Add(Enums.ProductsAndServicesTypes.InventoryItem);
		NewArray.Add(Enums.ProductsAndServicesTypes.Work);
		NewArray.Add(Enums.ProductsAndServicesTypes.Service);
		ArrayInventoryWork = New FixedArray(NewArray);
		NewParameter = New ChoiceParameter("Filter.ProductsAndServicesType", ArrayInventoryWork);
		NewParameter2 = New ChoiceParameter("Additionally.TypeRestriction", ArrayInventoryWork);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewArray.Add(NewParameter2);
		NewParameters = New FixedArray(NewArray);
		Items.ProductsProductsAndServices.ChoiceParameters = NewParameters;
		
	EndIf;
	
EndProcedure // SetVisibleAndEnabled()

////////////////////////////////////////////////////////////////////////////////
// CALENDAR (RESOURCES UPLOAD)

/// The procedure generates the period of work schedule.
//
&AtClient
Procedure GenerateScheduledWorksPeriod()
	
	CalendarDateBegin = BegOfDay(CalendarDate);
	CalendarDateEnd = EndOfDay(CalendarDate);
	
	DayOfSchedule = Format(CalendarDateBegin, "DF=dd");
	MonthOfSchedule = Format(CalendarDateBegin, "DF=MMM");
	YearOfSchedule = Format(Year(CalendarDateBegin), "NG=0");
	WeekDayOfSchedule = SmallBusinessClient.GetPresentationOfWeekDay(CalendarDateBegin);
	
	PeriodPresentation = WeekDayOfSchedule + " " + DayOfSchedule + " " + MonthOfSchedule + " " + YearOfSchedule;
	
EndProcedure // GenerateWorkSchedulePeriod()

// The function returns the list of resources by resource kind.
//
&AtServer
Function GetListOfResourcesByResourceKind()
	
	ListResourcesKinds = New ValueList;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EnterpriseResourcesKinds.EnterpriseResource AS EnterpriseResource
	|FROM
	|	InformationRegister.EnterpriseResourcesKinds AS EnterpriseResourcesKinds
	|WHERE
	|	EnterpriseResourcesKinds.EnterpriseResourceKind = &EnterpriseResourceKind";
	
	Query.SetParameter("EnterpriseResourceKind", FilterResourceKind);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return ListResourcesKinds;
	EndIf;
	
	Selection = Result.Select();
	While Selection.Next() Do
		ListResourcesKinds.Add(Selection.EnterpriseResource);
	EndDo;
	
	Return ListResourcesKinds;
	
EndFunction // GetResourcesListByResourceKind()

// The function returns the list of resources for fast selection.
//
&AtServer
Function GetListOfResourcesForFilter()
	
	If ValueIsFilled(FilterKeyResource) Then
		ListResourcesKinds = New ValueList;
		ListResourcesKinds.Add(FilterKeyResource);
	ElsIf ValueIsFilled(FilterResourceKind) Then
		ListResourcesKinds = GetListOfResourcesByResourceKind();
	Else
		ListResourcesKinds = Undefined;
	EndIf;
	
	Return ListResourcesKinds;
	
EndFunction // GetResourcesListForFilter()

// Procedure fills the common calendar parameters.
//
&AtServer
Procedure FillCalendarParametersOnCreateAtServer()
	
	If ValueIsFilled(Parameters.Key) Then
		TimeLimitFrom = Parameters.TimeLimitFrom;
		TimeLimitTo = Parameters.TimeLimitTo;
		RepetitionFactorOFDay = Parameters.RepetitionFactorOFDay;
		If Parameters.Property("CalendarDate") Then
			CalendarDate = Parameters.CalendarDate;
		EndIf;
	ElsIf Parameters.Property("Details") Then
		TimeLimitFrom = Parameters.TimeLimitFrom;
		TimeLimitTo = Parameters.TimeLimitTo;
		RepetitionFactorOFDay = Parameters.RepetitionFactorOFDay;
		FilterKeyResource = Parameters.FilterKeyResource;
		FilterResourceKind = Parameters.FilterResourceKind;
		CalendarDetails = Parameters.Details;
		If CalendarDetails.Count() > 0 Then
			StructureInterval = CalendarDetails[0];
			If StructureInterval.Property("EnterpriseResource") Then
				CalendarDate = CurrentDate();
				FillTableOfResourcesInUseOnCreateAtServer(CalendarDetails);
			Else
				CalendarDate = StructureInterval.Interval;
			EndIf;
		Else
			CalendarDate = CurrentDate();
		EndIf;
	ElsIf Parameters.Property("DayOnly") Then
		TimeLimitFrom = Parameters.TimeLimitFrom;
		TimeLimitTo = Parameters.TimeLimitTo;
		RepetitionFactorOFDay = Parameters.RepetitionFactorOFDay;
		FilterKeyResource = Parameters.FilterKeyResource;
		FilterResourceKind = Parameters.FilterResourceKind;
		CalendarDate =  Parameters.DayOnly;
		Details = Undefined;
	Else
		TimeLimitFrom = '00010101090000';
		TimeLimitTo = '00010101210000';
		RepetitionFactorOFDay = 30;
		CalendarDate = CurrentDate();
		Details = Undefined;
	EndIf;
	
EndProcedure // FillCalendarParametersOnCreateAtServer()

// Procedure creates the resources table for request.
//
&AtServer
Procedure FillTableOfResourcesInUseOnCreateAtServer(CalendarDetails)
	
	ResourcesTable = New ValueTable;
	ResourcesTable.Columns.Add("EnterpriseResource");
	ResourcesTable.Columns.Add("EnterpriseResourceDescription");
	ResourcesTable.Columns.Add("Interval");
	For Each DetailsItm IN CalendarDetails Do
		NewRow = ResourcesTable.Add();
		NewRow.EnterpriseResource = DetailsItm.EnterpriseResource;
		NewRow.EnterpriseResourceDescription = DetailsItm.EnterpriseResource.Description;
		NewRow.Interval = DetailsItm.Interval;
	EndDo;
	
	NewRow = Undefined;
	Resource = Undefined;
	IndexOf = 1;
	FirstStart = '00010101';
	LastFinish = '00010101';
	ResourcesTable.Sort("EnterpriseResourceDescription,Period");
	For Each ResourcesRow IN ResourcesTable Do
		If IndexOf = 1 Then
			CalendarDate = ResourcesRow.Interval;
		EndIf;
		If Resource = ResourcesRow.EnterpriseResource Then
			If NewRow <> Undefined Then
				PreviousFinish = NewRow.Finish;
				NextFinish = ResourcesRow.Interval + RepetitionFactorOFDay * 60;
				If BegOfDay(PreviousFinish) = BegOfDay(NextFinish) Then
					NewRow.Finish = ResourcesRow.Interval + RepetitionFactorOFDay * 60;
					If FirstStart > NewRow.Start OR FirstStart = '00010101' Then
						FirstStart = NewRow.Start;
					EndIf;
					If LastFinish < NewRow.Finish OR LastFinish = '00010101' Then
						LastFinish = NewRow.Finish;
					EndIf;
				Else
					NewRow.Finish = PreviousFinish;
					NewRow = Object.EnterpriseResources.Add();
					NewRow.EnterpriseResource = ResourcesRow.EnterpriseResource;
					NewRow.Capacity = 1;
					NewRow.Start = NextFinish - RepetitionFactorOFDay * 60;
					NewRow.Finish = NextFinish;
					If FirstStart > NewRow.Start OR FirstStart = '00010101' Then
						FirstStart = NewRow.Start;
					EndIf;
					If LastFinish < NewRow.Finish OR LastFinish = '00010101' Then
						LastFinish = NewRow.Finish;
					EndIf;
				EndIf;
				DurationInSeconds = NewRow.Finish - NewRow.Start;
				Hours = Int(DurationInSeconds / 3600);
				Minutes = (DurationInSeconds - Hours * 3600) / 60;
				NewRow.Duration = Date(0001, 01, 01, Hours, Minutes, 0);
			EndIf;
		Else
			NewRow = Object.EnterpriseResources.Add();
			NewRow.EnterpriseResource = ResourcesRow.EnterpriseResource;
			NewRow.Capacity = 1;
			NewRow.Start = ResourcesRow.Interval;
			NewRow.Finish = ResourcesRow.Interval + RepetitionFactorOFDay * 60;
			DurationInSeconds = NewRow.Finish - NewRow.Start;
			Hours = Int(DurationInSeconds / 3600);
			Minutes = (DurationInSeconds - Hours * 3600) / 60;
			NewRow.Duration = Date(0001, 01, 01, Hours, Minutes, 0);
			Resource = ResourcesRow.EnterpriseResource;
			If FirstStart > NewRow.Start OR FirstStart = '00010101' Then
				FirstStart = NewRow.Start;
			EndIf;
			If LastFinish < NewRow.Finish OR LastFinish = '00010101' Then
				LastFinish = NewRow.Finish;
			EndIf;
		EndIf;
		IndexOf = IndexOf + 1;
	EndDo;
	
	Object.Start = FirstStart;
	Object.Finish = LastFinish;
	
	WhenChangingStart = Object.Start;
	WhenChangingFinish = Object.Finish;
	
EndProcedure // FillInvolvedResourcesTableOnCreateAtServer()

// Function receives the involved resources table of current order.
//
&AtClient
Function GetTableOfResourcesInUse()
	
	StructureResourcesTS = New Structure;
	ArrayOfResourcesInUse = New Array;
	For Each TSRow IN Object.EnterpriseResources Do
		StringStructure = New Structure;
		StringStructure.Insert("EnterpriseResource", TSRow.EnterpriseResource);
		StringStructure.Insert("Capacity", TSRow.Capacity);
		StringStructure.Insert("Duration", TSRow.Duration);
		StringStructure.Insert("Start", TSRow.Start);
		StringStructure.Insert("Finish", TSRow.Finish);
		ArrayOfResourcesInUse.Add(StringStructure);
	EndDo;
	StructureResourcesTS.Insert("Ref", Object.Ref);
	StructureResourcesTS.Insert("TabularSection", ArrayOfResourcesInUse);
	
	Return StructureResourcesTS;
	
EndFunction // GetResourcesInUseTable()

// The procedure generates the schedule of resources import.
//
&AtServer
Procedure UpdateCalendar(StructureResourcesTS)
	
	Spreadsheet = ResourcesImport;
	Spreadsheet.Clear();
	
	ResourcesList = GetListOfResourcesForFilter();
	UpdateCalendarDayPeriod(Spreadsheet, StructureResourcesTS, ResourcesList);
	
	Spreadsheet.FixedTop = 4;
	Spreadsheet.FixedLeft = 5;
	
	Spreadsheet.ShowGrid = False;
	Spreadsheet.Protection = False;
	Spreadsheet.ReadOnly = True;
	
EndProcedure // UpdateCalendar()

// The procedure generates the schedule of resources import - period day.
//
&AtServer
Procedure UpdateCalendarDayPeriod(Spreadsheet, StructureResourcesTS, ResourcesList)
	
	ScaleTemplate = DataProcessors.Scheduler.GetTemplate("DayScale");
	
	// Displaying the scale.
	Indent = 1;
	ScaleStep = 3;
	ScaleBegin = 6;
	ShiftByScale = 1;
	ScaleSeparatorBottom = 3;
	ScaleSeparatorTop = 2;
	
	If ValueIsFilled(TimeLimitFrom) Then
		HourC = Hour(TimeLimitFrom);
		MinuteFrom = Minute(TimeLimitFrom);
	Else
		HourC = 0;
		MinuteFrom = 0;
	EndIf;
	If ValueIsFilled(TimeLimitTo) Then
		HourTo = Hour(TimeLimitTo);
		MinuteOn = Minute(TimeLimitTo);
	Else
		HourTo = 24;
		MinuteOn = 0;
	EndIf;
	
	ResourcesListArea = ScaleTemplate.Area("Scale60|ResourcesList");
	Spreadsheet.InsertArea(ResourcesListArea, Spreadsheet.Area(ResourcesListArea.Name));
	If RepetitionFactorOFDay = 60 Then
		If HourC = HourTo Then
			HourTo = HourC + ShiftByScale;
		ElsIf MinuteOn <> 0 Then
			HourTo = HourTo + ShiftByScale;
		EndIf;
		TotalMinutesFrom =  HourC * 60;
		TotalMinutesTo = HourTo * 60;
		ColumnNumberFrom = ScaleBegin + ?(HourC-Int(HourC/2)*2 = 1, (HourC - ShiftByScale), HourC) / 2 * ScaleStep;
		MultipleRestrictionFrom = Date('00010101') + (?(HourC-Int(HourC/2)*2 = 1, (HourC - ShiftByScale), HourC)) * 60 * 60;
		ColumnNumberTo = ScaleBegin + ?(HourTo-Int(HourTo/2)*2 = 1, (HourTo + ShiftByScale), HourTo) / 2 * ScaleStep - ShiftByScale;
		MultipleRestrictionTo = Date('00010101') + (?(HourTo-Int(HourTo/2)*2 = 1, (HourTo + ShiftByScale), HourTo)) * 60 * 60;
		ScaleArea = ScaleTemplate.Area("Scale60|Repetition60");
	ElsIf RepetitionFactorOFDay = 15 Then
		TotalMinutesFrom = HourC * 60 + MinuteFrom;
		TotalMinutesTo = HourTo * 60 + MinuteOn;
		If TotalMinutesFrom = TotalMinutesTo Then
			TotalMinutesTo = TotalMinutesFrom + 60;
		EndIf;
		ColumnNumberFrom = ScaleBegin + Int(TotalMinutesFrom / 30) * ScaleStep;
		MultipleRestrictionFrom = Date('00010101') + (?(Int(TotalMinutesFrom / 30) = (TotalMinutesFrom / 30), TotalMinutesFrom, Int(TotalMinutesFrom / 30) * 30)) * 60;
		ColumnNumberTo = ScaleBegin + ?(Int(TotalMinutesTo / 30) = (TotalMinutesTo / 30), (TotalMinutesTo / 30), Int(TotalMinutesTo / 30) + 1) * ScaleStep - ShiftByScale;
		MultipleRestrictionTo = Date('00010101') + (?(Int(TotalMinutesTo / 30) = (TotalMinutesTo / 30), TotalMinutesTo, Int(TotalMinutesTo / 30) * 30 + 30)) * 60;
		ScaleArea = ScaleTemplate.Area("Scale15|Repetition15");
	ElsIf RepetitionFactorOFDay = 10 Then
		TotalMinutesFrom = HourC * 60 + MinuteFrom;
		TotalMinutesTo = HourTo * 60 + MinuteOn;
		If TotalMinutesFrom = TotalMinutesTo Then
			TotalMinutesTo = TotalMinutesFrom + 60;
		EndIf;
		ColumnNumberFrom = ScaleBegin + Int(TotalMinutesFrom / 20) * ScaleStep;
		MultipleRestrictionFrom = Date('00010101') + (?(Int(TotalMinutesFrom / 20) = (TotalMinutesFrom / 20), TotalMinutesFrom, Int(TotalMinutesFrom / 20) * 20)) * 60;
		ColumnNumberTo = ScaleBegin + ?(Int(TotalMinutesTo / 20) = (TotalMinutesTo / 20), (TotalMinutesTo / 20), Int(TotalMinutesTo / 20) + 1) * ScaleStep - ShiftByScale;
		MultipleRestrictionTo = Date('00010101') + (?(Int(TotalMinutesTo / 20) = (TotalMinutesTo / 20), TotalMinutesTo, Int(TotalMinutesTo / 20) * 20 + 20)) * 60;
		ScaleArea = ScaleTemplate.Area("Scale10|Repetition10");
	ElsIf RepetitionFactorOFDay = 5 Then
		TotalMinutesFrom = HourC * 60 + MinuteFrom;
		TotalMinutesTo = HourTo * 60 + MinuteOn;
		If TotalMinutesFrom = TotalMinutesTo Then
			TotalMinutesTo = TotalMinutesFrom + 60;
		EndIf;
		ColumnNumberFrom = ScaleBegin + Int(TotalMinutesFrom / 10) * ScaleStep;
		MultipleRestrictionFrom = Date('00010101') + (?(Int(TotalMinutesFrom / 10) = (TotalMinutesFrom / 10), TotalMinutesFrom, Int(TotalMinutesFrom / 10) * 10)) * 60;
		ColumnNumberTo = ScaleBegin + ?(Int(TotalMinutesTo / 10) = (TotalMinutesTo / 10), (TotalMinutesTo / 10), Int(TotalMinutesTo / 10) + 1) * ScaleStep - ShiftByScale;
		MultipleRestrictionTo = Date('00010101') + (?(Int(TotalMinutesTo / 10) = (TotalMinutesTo / 10), TotalMinutesTo, Int(TotalMinutesTo / 10) * 10 + 10)) * 60;
		ScaleArea = ScaleTemplate.Area("Scale5|Repetition5");
	Else // 30 min
		If HourC = HourTo Then
			HourTo = HourC + ShiftByScale;
		ElsIf MinuteOn <> 0 Then
			HourTo = HourTo + ShiftByScale;
		EndIf;
		TotalMinutesFrom =  HourC * 60;
		TotalMinutesTo = HourTo * 60;
		ColumnNumberFrom = ScaleBegin + HourC * ScaleStep;
		MultipleRestrictionFrom = Date('00010101') + (?(Int(TotalMinutesFrom / 60) = (TotalMinutesFrom / 60), TotalMinutesFrom, TotalMinutesFrom - 30)) * 60;
		ColumnNumberTo = ScaleBegin + HourTo * ScaleStep - ShiftByScale;
		MultipleRestrictionTo = Date('00010101') + (?(Int(TotalMinutesTo / 60) = (TotalMinutesTo / 60), TotalMinutesTo, TotalMinutesTo + 30)) * 60;
		ScaleArea = ScaleTemplate.Area("Scale30|Repetition30");
	EndIf;
	TemplateArea = ScaleTemplate.Area("R" + ScaleArea.Top + "C"+ ColumnNumberFrom +":R"+ ScaleArea.Bottom +"C" + ColumnNumberTo);
	SpreadsheetArea = Spreadsheet.Area("R" + ShiftByScale + "C" + ScaleBegin + ":R"+ (ScaleStep + 1) +"C" + (ScaleBegin + ColumnNumberTo - ColumnNumberFrom));
	Spreadsheet.InsertArea(TemplateArea, SpreadsheetArea);
	
	// Initialization of days array.
	DaysArray = New Array;
	DaysArray.Add(CalendarDateBegin);
	
	// First column format.
	FirstColumnCoordinates = "R" + ShiftByScale + "C" + (ScaleBegin + ShiftByScale) + ":R" + ShiftByScale + "C" + (ScaleBegin + ShiftByScale);
	Spreadsheet.Area(FirstColumnCoordinates).Text = Format(CalendarDateBegin, "DF=""dd MMMM yyyy dddd""");
	Spreadsheet.Area("R" + ScaleSeparatorTop + "C" + (ScaleBegin + ShiftByScale) + ":R" + ScaleSeparatorBottom + "C" + (ScaleBegin + ShiftByScale)).LeftBorder = New Line(SpreadsheetDocumentCellLineType.None);
	
	// Last column format.
	LastColumnCoordinates = "R" + ShiftByScale + "C" + (ScaleBegin + ColumnNumberTo - ColumnNumberFrom) + ":R" + (ScaleStep + 1) + "C" + (ScaleBegin + ColumnNumberTo - ColumnNumberFrom);
	Spreadsheet.Area(LastColumnCoordinates).RightBorder = New Line(SpreadsheetDocumentCellLineType.Solid);
	Spreadsheet.Area(LastColumnCoordinates).BorderColor = StyleColors.BorderColor;
	
	CoordinatesForUnion = "R" + ShiftByScale + "C" + (ScaleBegin + ShiftByScale) + ":R" + ShiftByScale + "C" + (ScaleBegin + ColumnNumberTo - ColumnNumberFrom);
	UnionArea = Spreadsheet.Area(CoordinatesForUnion);
	UnionArea.Merge();
	
	// Coordinates of day end.
	EndOfDayCoordinates = LastColumnCoordinates;
	
	// Day-off format.
	If Weekday(CalendarDateBegin) = 6 
		OR Weekday(CalendarDateBegin) = 7 Then
		DayOffCoordinates = "R" + (ShiftByScale + 1) + "C" + ScaleBegin + ":R"+ (ScaleStep + 1) +"C" + (ScaleBegin + ColumnNumberTo - ColumnNumberFrom);
		Spreadsheet.Area(DayOffCoordinates).BackColor = StyleColors.NonWorkingTimeDayOff;
	EndIf;
	
	// Initialization of scale sizes.
	Spreadsheet.Area(1,,1,).RowHeight = 16;
	Spreadsheet.Area(2,,2,).RowHeight = 6;
	Spreadsheet.Area(3,,3,).RowHeight = 5;
	Spreadsheet.Area(4,,4,).RowHeight = 5;
	
	Spreadsheet.Area(,1,,1).ColumnWidth = 16;
	Spreadsheet.Area(,2,,2).ColumnWidth = 1;
	Spreadsheet.Area(,3,,3).ColumnWidth = 3;
	Spreadsheet.Area(,4,,4).ColumnWidth = 1;
	Spreadsheet.Area(,5,,5).ColumnWidth = 3;
	
	ColumnNumber = ScaleBegin;
	LastColumnNumber = Spreadsheet.TableWidth;
	While ColumnNumber <= LastColumnNumber Do
		
		Spreadsheet.Area(,ColumnNumber,,ColumnNumber).ColumnWidth = 0.8;
		Spreadsheet.Area(,ColumnNumber + 1,,ColumnNumber + 1).ColumnWidth = 6;
		Spreadsheet.Area(,ColumnNumber + 2,,ColumnNumber + 2).ColumnWidth = 6;
		ColumnNumber = ColumnNumber + 3;
		
	EndDo;
	
	// Displaying the schedule of resources import.
	BusyResourceCellColor = StyleColors.BusyResource;
	AvailableResourceCellColor =  StyleColors.WorktimeCompletelyBusy;
	ResourceIsNotEditableCellColor = StyleColors.WorktimeFreeAvailable;
	CellBorderColor = StyleColors.CellBorder;
	EditingCellColor = StyleColors.CurrentTimeInterval;
	
	ResourcesListBegin = ResourcesListArea.Bottom + Indent;
	FirstColumnNumber = Spreadsheet.Area(FirstColumnCoordinates).Left - 1;
	NumberOfLasfColumnOfDay = Spreadsheet.Area(EndOfDayCoordinates).Right;
	
	// Resourse import.
	IntervalsTable = New ValueTable();
	IntervalsTable.Columns.Add("Interval");
	IntervalsTable.Columns.Add("IntervalIsImported");
	IntervalsTable.Columns.Add("IntervalEdited");
	IntervalsTable.Columns.Add("Import");
	IntervalsTable.Indexes.Add("Interval");
	
	QueryResult = GetResourcesWorkImportSchedule(StructureResourcesTS, ResourcesList, DaysArray);
	
	// Resource import (on schedule, on deviations).
	SelectionResource = QueryResult[2].Select(QueryResultIteration.ByGroups, "EnterpriseResource");
	LineNumber = 1;
	While SelectionResource.Next() Do
		
		// List of resources.
		R = ResourcesListBegin + LineNumber;
		Spreadsheet.Area(R, 1).Text = SelectionResource.EnterpriseResource;
		Spreadsheet.Area(R, 1).VerticalAlign = VerticalAlign.Center;
		Spreadsheet.Area(R, 1).Details = SelectionResource.EnterpriseResource;
		
		UnionArea = Spreadsheet.Area(R,1,R,ScaleBegin-1);
		UnionArea.Merge();
		
		ResourceCapacity = ?(SelectionResource.Capacity = 1, 0, SelectionResource.Capacity);
		
		// Resourse import.
		IntervalsTable.Clear();
		
		WorkBySchedule = False;
		Selection = SelectionResource.Select();
		While Selection.Next() Do
			
			// There is a deviation for the current day.
			If Selection.RejectionsNotABusinessDay
				AND ValueIsFilled(Selection.RejectionsBeginTime) AND ValueIsFilled(Selection.RejectionsEndTime) Then
				
				CalculateIntervals(IntervalsTable, MultipleRestrictionFrom, MultipleRestrictionTo, Selection.RejectionsBeginTime, Selection.RejectionsEndTime);
				
			EndIf;
			
			// There is a shedule for the current day.
			If Not Selection.RejectionsNotABusinessDay
				AND ValueIsFilled(Selection.BeginTime) AND ValueIsFilled(Selection.EndTime) Then
				
				CalculateIntervals(IntervalsTable, MultipleRestrictionFrom, MultipleRestrictionTo, Selection.BeginTime, Selection.EndTime);
				
			EndIf;
			
			// Work on schedule.
			If ValueIsFilled(Selection.WorkSchedule) Then
				WorkBySchedule = True;
			EndIf;
			
		EndDo;
		
		// Output of calendar import.
		Interval = 0;
		MultipleTimeFrom = MultipleRestrictionFrom;
		NextFirstColumn = FirstColumnNumber;
		NextLastColumn = NumberOfLasfColumnOfDay;
		While NextFirstColumn <= NextLastColumn Do
			
			// Cell 1.
			Spreadsheet.Area(R, NextFirstColumn + Indent).TextPlacement = SpreadsheetDocumentTextPlacementType.Cut;
			Spreadsheet.Area(R, NextFirstColumn + Indent).VerticalAlign = VerticalAlign.Center;
			Spreadsheet.Area(R, NextFirstColumn + Indent).HorizontalAlign = HorizontalAlign.Center;
			Spreadsheet.Area(R, NextFirstColumn + Indent).Font = New Font(, 8, True, , , );
			Spreadsheet.Area(R, NextFirstColumn + Indent).RightBorder = New Line(SpreadsheetDocumentCellLineType.Solid, 2);
			Spreadsheet.Area(R, NextFirstColumn + Indent).BorderColor = CellBorderColor;
			
			SearchInterval = CalendarDateBegin + Hour(MultipleTimeFrom) * 60 * 60 + Minute(MultipleTimeFrom) * 60;
			SearchStructure = New Structure("Interval", SearchInterval);
			SearchResult = IntervalsTable.FindRows(SearchStructure);
			If SearchResult.Count() = 0 AND Not WorkBySchedule Then
				
				Spreadsheet.Area(R, NextFirstColumn + Indent).BackColor = AvailableResourceCellColor;
				Spreadsheet.Area(R, NextFirstColumn + Indent).Text = ResourceCapacity;
				Spreadsheet.Area(R, NextFirstColumn + Indent).TextColor = CellBorderColor;
				Spreadsheet.Area(R, NextFirstColumn + Indent).Details = GetCellDetails(SelectionResource.EnterpriseResource, SearchInterval, ResourceCapacity);
				
			ElsIf SearchResult.Count() = 0 AND WorkBySchedule Then
				
				Spreadsheet.Area(R, NextFirstColumn + Indent).BackColor = ResourceIsNotEditableCellColor;
				Spreadsheet.Area(R, NextFirstColumn + Indent).Text = ResourceCapacity;
				Spreadsheet.Area(R, NextFirstColumn + Indent).TextColor = CellBorderColor;
				Spreadsheet.Area(R, NextFirstColumn + Indent).Details = GetCellDetails(SelectionResource.EnterpriseResource, SearchInterval, ResourceCapacity);
				
			Else
				
				Spreadsheet.Area(R, NextFirstColumn + Indent).BackColor = AvailableResourceCellColor;
				Spreadsheet.Area(R, NextFirstColumn + Indent).Text = ResourceCapacity;
				Spreadsheet.Area(R, NextFirstColumn + Indent).TextColor = CellBorderColor;
				Spreadsheet.Area(R, NextFirstColumn + Indent).Details = GetCellDetails(SelectionResource.EnterpriseResource, SearchInterval, ResourceCapacity);
				
			EndIf;
			
			// Cell 2.
			Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).TextPlacement = SpreadsheetDocumentTextPlacementType.Cut;
			Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).VerticalAlign = VerticalAlign.Center;
			Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).HorizontalAlign = HorizontalAlign.Center;
			Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Font = New Font(, 8, True, , , );
			
			MultipleTimeFrom = MultipleTimeFrom + RepetitionFactorOFDay * 60;
			SearchInterval = CalendarDateBegin + Hour(MultipleTimeFrom) * 60 * 60 + Minute(MultipleTimeFrom) * 60;
			SearchStructure = New Structure("Interval", SearchInterval);
			SearchResult = IntervalsTable.FindRows(SearchStructure);
			If SearchResult.Count() = 0 AND Not WorkBySchedule Then
				
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).BackColor = AvailableResourceCellColor;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Text = ResourceCapacity;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).TextColor = CellBorderColor;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Details = GetCellDetails(SelectionResource.EnterpriseResource, SearchInterval, ResourceCapacity);
				
			ElsIf SearchResult.Count() = 0 AND WorkBySchedule Then
				
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).BackColor = ResourceIsNotEditableCellColor;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Text = ResourceCapacity;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).TextColor = CellBorderColor;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Details = GetCellDetails(SelectionResource.EnterpriseResource, SearchInterval, ResourceCapacity);
				
			Else
				
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).BackColor = AvailableResourceCellColor;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Text = ResourceCapacity;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).TextColor = CellBorderColor;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Details = GetCellDetails(SelectionResource.EnterpriseResource, SearchInterval, ResourceCapacity);
				
			EndIf;
			
			MultipleTimeFrom = MultipleTimeFrom + RepetitionFactorOFDay * 60;
			NextFirstColumn = NextFirstColumn + 3;
			Interval = Interval + 3;
			
		EndDo;
		
		// Initialization of line sizes.
		R = ScaleStep + LineNumber + ShiftByScale;
		Spreadsheet.Area(R, 1).RowHeight = 5;
		Spreadsheet.Area(R + Indent, 1).RowHeight = 18;
		
		LineNumber = LineNumber + 2;
		
	EndDo;
	
	// Resourse import (on orders).
	SelectionResource = QueryResult[3].Select(QueryResultIteration.ByGroups, "EnterpriseResource");
	LineNumber = 1;
	While SelectionResource.Next() Do
		
		// List of resources.
		R = ResourcesListBegin + LineNumber;
		ResourceCapacity = ?(SelectionResource.Capacity = 1, 0, SelectionResource.Capacity);
		
		// Resourse import.
		IntervalsTable.Clear();
		
		Selection = SelectionResource.Select();
		While Selection.Next() Do
			
			// There is an order for the current day.
			If ValueIsFilled(Selection.BeginTime) AND ValueIsFilled(Selection.EndTime) Then
				
				CalculateIntervals(IntervalsTable, MultipleRestrictionFrom, MultipleRestrictionTo, Selection.BeginTime, Selection.EndTime, Selection.Import, Selection.Edit);
				
			EndIf;
			
		EndDo;
		
		// Output of calendar import.
		Interval = 0;
		MultipleTimeFrom = MultipleRestrictionFrom;
		NextFirstColumn = FirstColumnNumber;
		NextLastColumn = NumberOfLasfColumnOfDay;
		While NextFirstColumn <= NextLastColumn Do
			
			// Cell 1.
			SearchInterval = CalendarDateBegin + Hour(MultipleTimeFrom) * 60 * 60 + Minute(MultipleTimeFrom) * 60;
			SearchStructure = New Structure("Interval", SearchInterval);
			SearchResult = IntervalsTable.FindRows(SearchStructure);
			Import = 0;
			IntervalEdited = False;
			For Each SearchString IN SearchResult Do
				
				If SearchString.IntervalIsImported Then
					
					If SearchString.IntervalEdited Then
						IntervalEdited = True;
					EndIf;
					Import = Import + SearchString.Import;
					
				EndIf;
					
			EndDo;
				
			If Import <> 0 Then
				
				TotalImport = Import;
				If ResourceCapacity = 0 Then
					Import = 0;
				Else
					Import = ResourceCapacity - Import;
				EndIf;
					
				If Import = 0 Then
					Spreadsheet.Area(R, NextFirstColumn + Indent).BackColor = BusyResourceCellColor;
					Spreadsheet.Area(R, NextFirstColumn + Indent).Text = Import;
					Spreadsheet.Area(R, NextFirstColumn + Indent).TextColor = CellBorderColor;
				ElsIf Import < 0 Then
					Spreadsheet.Area(R, NextFirstColumn + Indent).BackColor = BusyResourceCellColor;
					Spreadsheet.Area(R, NextFirstColumn + Indent).Text = Import * (-1);
					Spreadsheet.Area(R, NextFirstColumn + Indent).TextColor = CellBorderColor;
				Else
					Spreadsheet.Area(R, NextFirstColumn + Indent).BackColor = AvailableResourceCellColor;
					Spreadsheet.Area(R, NextFirstColumn + Indent).Text = Import;
					Spreadsheet.Area(R, NextFirstColumn + Indent).TextColor = CellBorderColor;
				EndIf;
					
				If IntervalEdited Then
					Spreadsheet.Area(R, NextFirstColumn + Indent).BackColor = EditingCellColor;
					If Import < 0 Then
						Spreadsheet.Area(R, NextFirstColumn + Indent).TextColor = BusyResourceCellColor;
					EndIf;
				EndIf;
				
				Spreadsheet.Area(R, NextFirstColumn + Indent).Details = GetCellDetails(SelectionResource.EnterpriseResource, SearchInterval, ResourceCapacity, TotalImport);
				
			EndIf;
			
			// Cell 2.
			MultipleTimeFrom = MultipleTimeFrom + RepetitionFactorOFDay * 60;
			SearchInterval = CalendarDateBegin + Hour(MultipleTimeFrom) * 60 * 60 + Minute(MultipleTimeFrom) * 60;
			SearchStructure = New Structure("Interval", SearchInterval);
			SearchResult = IntervalsTable.FindRows(SearchStructure);
			Import = 0;
			IntervalEdited = False;
			For Each SearchString IN SearchResult Do
				
				If SearchString.IntervalIsImported Then
					
					If SearchString.IntervalEdited Then
						IntervalEdited = True;
					EndIf;
					Import = Import + SearchString.Import;
					
				EndIf;
				
			EndDo;
				
			If Import <> 0 Then
				
				TotalImport = Import;
				If ResourceCapacity = 0 Then
					Import = 0;
				Else
					Import = ResourceCapacity - Import;
				EndIf;
				
				If Import = 0 Then
					Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).BackColor = BusyResourceCellColor;
					Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Text = Import;
					Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).TextColor = CellBorderColor;
				ElsIf Import < 0 Then
					Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).BackColor = BusyResourceCellColor;
					Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Text = Import * (-1);
					Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).TextColor = CellBorderColor;
				Else
					Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).BackColor = AvailableResourceCellColor;
					Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Text = Import;
					Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).TextColor = CellBorderColor;
				EndIf;
				
				If IntervalEdited Then
					Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).BackColor = EditingCellColor;
					If Import < 0 Then
						Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).TextColor = BusyResourceCellColor;
					EndIf;
				EndIf;
				
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Details = GetCellDetails(SelectionResource.EnterpriseResource, SearchInterval, ResourceCapacity, TotalImport);
				
			EndIf;
			
			MultipleTimeFrom = MultipleTimeFrom + RepetitionFactorOFDay * 60;
			NextFirstColumn = NextFirstColumn + 3;
			Interval = Interval + 3;
			
		EndDo;
		
		LineNumber = LineNumber + 2;
		
	EndDo;
	
EndProcedure // UpdateCalendarDayPeriod()

// Procedure updates the calendar cell according to the details parameters.
//
&AtClient
Procedure UpdateCalendarCell(CellCoordinates, Details)
	
	TotalImport = Details.Import + 1;
	If Details.Capacity = 0 Then
		Import = 0;
	Else
		Import = Details.Capacity - Details.Import - 1;
	EndIf;
	
	ResourcesImport.Area(CellCoordinates).BackColor = ColorEditing;
	If Import < 0 Then
		ResourcesImport.Area(CellCoordinates).Text = Import *(-1);
		ResourcesImport.Area(CellCoordinates).TextColor = ColorBusyResource;
	Else
		ResourcesImport.Area(CellCoordinates).Text = Import;
	EndIf;
	
	Details.Import = TotalImport;
	
EndProcedure // UpdateCalendarCell()

// The procedure calculates the planning intervals for calendar scale.
//
&AtServer
Procedure CalculateIntervals(IntervalsTable, TimeFrom, TimeTo, BeginTime, EndTime, Import = 0, Edit = Undefined)
	
	MultipleTimeRestrictionFrom = BegOfDay(BeginTime) + Hour(TimeFrom) * 60 * 60 + Minute(TimeFrom) * 60;
	MultipleTimeRestrictionTo = BegOfDay(BeginTime) + Hour(TimeTo) * 60 * 60 + Minute(TimeTo) * 60;
	
	// If 24 hours.
	If MultipleTimeRestrictionFrom >= MultipleTimeRestrictionTo Then
		MultipleTimeRestrictionTo = MultipleTimeRestrictionTo + 24 * 60 * 60;
	EndIf;
	
	If RepetitionFactorOFDay = 60 Then
		
		HourBeginTime = Hour(BeginTime);
		MultipleStartTime = BegOfDay(BeginTime) + HourBeginTime * 60 * 60;
		EndTimeHour = ?(Minute(EndTime) <> 0, Hour(EndTime) + 1, Hour(EndTime));
		MultipleEndTime = BegOfDay(EndTime) + EndTimeHour * 60 * 60;
		
		While MultipleStartTime < MultipleEndTime Do
			If Hour(MultipleStartTime) >= Hour(MultipleTimeRestrictionFrom) AND Hour(MultipleStartTime) <= Hour(MultipleTimeRestrictionTo) Then
				NewRow = IntervalsTable.Add();
				NewRow.Interval = MultipleStartTime;
				NewRow.Import = Import;
				If Edit = Undefined Then
					NewRow.IntervalIsImported = False;
					NewRow.IntervalEdited = False;
				Else
					NewRow.IntervalIsImported = True;
					NewRow.IntervalEdited = Edit;
					NewRow.Import = Import;
				EndIf;
			EndIf;
			MultipleStartTime = MultipleStartTime + RepetitionFactorOFDay * 60;
		EndDo;
		
	ElsIf RepetitionFactorOFDay = 15 Then
		
		MinutesBeginTime = Int(Minute(BeginTime) / 15) * 15;
		MultipleStartTime = BegOfDay(BeginTime) + Hour(BeginTime) * 60 * 60 + MinutesBeginTime * 60;
		
		MinutesEndTime = ?(Int(Minute(EndTime) / 15) = Minute(EndTime) / 15, Minute(EndTime), Int(Minute(EndTime) / 15) * 15 + 15);
		MultipleEndTime = BegOfDay(EndTime) + Hour(EndTime) * 60 * 60 + MinutesEndTime * 60;
		
		While MultipleStartTime < MultipleEndTime Do
			If MultipleStartTime >= MultipleTimeRestrictionFrom AND MultipleStartTime <= MultipleTimeRestrictionTo Then
				NewRow = IntervalsTable.Add();
				NewRow.Interval = MultipleStartTime;
				NewRow.Import = Import;
				If Edit = Undefined Then
					NewRow.IntervalIsImported = False;
					NewRow.IntervalEdited = False;
				Else
					NewRow.IntervalIsImported = True;
					NewRow.IntervalEdited = Edit;
					NewRow.Import = Import;
				EndIf;
			EndIf;
			MultipleStartTime = MultipleStartTime + RepetitionFactorOFDay * 60;
		EndDo;
		
	ElsIf RepetitionFactorOFDay = 10 Then
		
		MinutesBeginTime = Int(Minute(BeginTime) / 10) * 10;
		MultipleStartTime = BegOfDay(BeginTime) + Hour(BeginTime) * 60 * 60 + MinutesBeginTime * 60;
		
		MinutesEndTime = ?(Int(Minute(EndTime) / 10) = Minute(EndTime) / 10, Minute(EndTime), Int(Minute(EndTime) / 10) * 10 + 10);
		MultipleEndTime = BegOfDay(EndTime) + Hour(EndTime) * 60 * 60 + MinutesEndTime * 60;
		
		While MultipleStartTime < MultipleEndTime Do
			If MultipleStartTime >= MultipleTimeRestrictionFrom AND MultipleStartTime <= MultipleTimeRestrictionTo Then
				NewRow = IntervalsTable.Add();
				NewRow.Interval = MultipleStartTime;
				NewRow.Import = Import;
				If Edit = Undefined Then
					NewRow.IntervalIsImported = False;
					NewRow.IntervalEdited = False;
				Else
					NewRow.IntervalIsImported = True;
					NewRow.IntervalEdited = Edit;
					NewRow.Import = Import;
				EndIf;
			EndIf;
			MultipleStartTime = MultipleStartTime + RepetitionFactorOFDay * 60;
		EndDo;
		
	ElsIf RepetitionFactorOFDay = 5 Then
		
		MinutesBeginTime = Int(Minute(BeginTime) / 5) * 5;
		MultipleStartTime = BegOfDay(BeginTime) + Hour(BeginTime) * 60 * 60 + MinutesBeginTime * 60;
		
		MinutesEndTime = ?(Int(Minute(EndTime) / 5) = Minute(EndTime) / 5, Minute(EndTime), Int(Minute(EndTime) / 5) * 5 + 5);
		MultipleEndTime = BegOfDay(EndTime) + Hour(EndTime) * 60 * 60 + MinutesEndTime * 60;
		
		While MultipleStartTime < MultipleEndTime Do
			If MultipleStartTime >= MultipleTimeRestrictionFrom AND MultipleStartTime <= MultipleTimeRestrictionTo Then
				NewRow = IntervalsTable.Add();
				NewRow.Interval = MultipleStartTime;
				NewRow.Import = Import;
				If Edit = Undefined Then
					NewRow.IntervalIsImported = False;
					NewRow.IntervalEdited = False;
				Else
					NewRow.IntervalIsImported = True;
					NewRow.IntervalEdited = Edit;
					NewRow.Import = Import;
				EndIf;
			EndIf;
			MultipleStartTime = MultipleStartTime + RepetitionFactorOFDay * 60;
		EndDo;
		
		TimeFrom = MultipleTimeRestrictionFrom;
		
	Else // Multiplicity = 30
		
		MinutesBeginTime = ?(Minute(BeginTime) < 30, Hour(BeginTime) * 60, Hour(BeginTime) * 60 + 30);
		MultipleStartTime = BegOfDay(BeginTime) + MinutesBeginTime * 60;
		If Minute(EndTime) <= 30 Then
			MinutesEndTime = ?(Minute(EndTime) = 0, Hour(EndTime) * 60, Hour(EndTime) * 60 + 30);
		Else
			MinutesEndTime = (Hour(EndTime) + 1) * 60;
		EndIf;
		MultipleEndTime = BegOfDay(EndTime) + MinutesEndTime * 60;
		
		While MultipleStartTime < MultipleEndTime Do
			If MultipleStartTime >= MultipleTimeRestrictionFrom AND MultipleStartTime <= MultipleTimeRestrictionTo Then
				NewRow = IntervalsTable.Add();
				NewRow.Interval = MultipleStartTime;
				NewRow.Import = Import;
				If Edit = Undefined Then
					NewRow.IntervalIsImported = False;
					NewRow.IntervalEdited = False;
				Else
					NewRow.IntervalIsImported = True;
					NewRow.IntervalEdited = Edit;
					NewRow.Import = Import;
				EndIf;
			EndIf;
			MultipleStartTime = MultipleStartTime + RepetitionFactorOFDay * 60;
		EndDo;
		
	EndIf;
	
EndProcedure // CalculateIntervals()

// The function returns the schedule of resources import.
//
&AtServer
Function GetResourcesWorkImportSchedule(StructureResourcesTS, ResourcesList, DaysArray)
	
	ResourcesTable = New ValueTable;
	
	Array = New Array;
	Array.Add(Type("CatalogRef.KeyResources"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ResourcesTable.Columns.Add("EnterpriseResource", TypeDescription);
	
	Array = New Array;
	Array.Add(Type("Date"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ResourcesTable.Columns.Add("Start", TypeDescription);
	ResourcesTable.Columns.Add("Finish", TypeDescription);
	
	Array = New Array;
	Array.Add(Type("Number"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ResourcesTable.Columns.Add("Capacity", TypeDescription);
	
	For Each ResourceRow IN StructureResourcesTS.TabularSection Do
		NewRow = ResourcesTable.Add();
		FillPropertyValues(NewRow, ResourceRow);
	EndDo;
	CurrentDocument = StructureResourcesTS.Ref;
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	KeyResources.Ref AS EnterpriseResource,
	|	KeyResources.Capacity AS Capacity,
	|	KeyResources.Description AS ResourceDescription
	|INTO EnterpriseResourceTempTable
	|FROM
	|	Catalog.KeyResources AS KeyResources
	|WHERE
	|	(&FilterByKeyResource
	|			OR KeyResources.Ref IN (&FilterKeyResourcesList))
	|	AND (NOT KeyResources.DeletionMark)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ResourcesTable.EnterpriseResource AS EnterpriseResource,
	|	ResourcesTable.Start AS Start,
	|	ResourcesTable.Finish AS Finish,
	|	ResourcesTable.Capacity AS Capacity
	|INTO TemporaryTableRequest
	|FROM
	|	&ResourcesTable AS ResourcesTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	EnterpriseResourceTempTable.EnterpriseResource AS EnterpriseResource,
	|	EnterpriseResourceTempTable.Capacity AS Capacity,
	|	TableOfSchedules.WorkSchedule AS WorkSchedule,
	|	WorkSchedules.BeginTime AS BeginTime,
	|	WorkSchedules.EndTime AS EndTime,
	|	DeviationFromResourcesWorkSchedules.BeginTime AS RejectionsBeginTime,
	|	DeviationFromResourcesWorkSchedules.EndTime AS RejectionsEndTime,
	|	ISNULL(DeviationFromResourcesWorkSchedules.NotABusinessDay, FALSE) AS RejectionsNotABusinessDay
	|FROM
	|	EnterpriseResourceTempTable AS EnterpriseResourceTempTable
	|		LEFT JOIN InformationRegister.ResourcesWorkSchedules.SliceLast(&StartDate, ) AS TableOfSchedules
	|		ON EnterpriseResourceTempTable.EnterpriseResource = TableOfSchedules.EnterpriseResource
	|		LEFT JOIN InformationRegister.WorkSchedules AS WorkSchedules
	|		ON (TableOfSchedules.WorkSchedule = WorkSchedules.WorkSchedule)
	|			AND (WorkSchedules.BeginTime between &StartDate AND &EndDate)
	|			AND (WorkSchedules.EndTime between &StartDate AND &EndDate)
	|		LEFT JOIN InformationRegister.DeviationFromResourcesWorkSchedules AS DeviationFromResourcesWorkSchedules
	|		ON EnterpriseResourceTempTable.EnterpriseResource = DeviationFromResourcesWorkSchedules.EnterpriseResource
	|			AND (DeviationFromResourcesWorkSchedules.BeginTime between &StartDate AND &EndDate)
	|			AND (DeviationFromResourcesWorkSchedules.EndTime between &StartDate AND &EndDate)
	|
	|ORDER BY
	|	EnterpriseResourceTempTable.ResourceDescription,
	|	BeginTime,
	|	EndTime
	|TOTALS
	|	MIN(Capacity)
	|BY
	|	EnterpriseResource
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	EnterpriseResourceTempTable.EnterpriseResource AS EnterpriseResource,
	|	EnterpriseResourceTempTable.Capacity AS Capacity,
	|	NestedSelect.Edit AS Edit,
	|	NestedSelect.Start AS BeginTime,
	|	NestedSelect.Finish AS EndTime,
	|	NestedSelect.Capacity AS Import
	|FROM
	|	EnterpriseResourceTempTable AS EnterpriseResourceTempTable
	|		LEFT JOIN (SELECT
	|			FALSE AS Edit,
	|			ProductionOrderEnterpriseResources.EnterpriseResource AS EnterpriseResource,
	|			ProductionOrderEnterpriseResources.Capacity AS Capacity,
	|			ProductionOrderEnterpriseResources.Start AS Start,
	|			ProductionOrderEnterpriseResources.Finish AS Finish
	|		FROM
	|			Document.ProductionOrder.EnterpriseResources AS ProductionOrderEnterpriseResources
	|		WHERE
	|			(NOT ProductionOrderEnterpriseResources.EnterpriseResource.DeletionMark)
	|			AND ProductionOrderEnterpriseResources.Ref.Posted
	|			AND ((NOT ProductionOrderEnterpriseResources.Ref.Closed)
	|					OR ProductionOrderEnterpriseResources.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|			AND ProductionOrderEnterpriseResources.Ref <> &CurrentDocument
	|			AND ProductionOrderEnterpriseResources.Start between &StartDate AND &EndDate
	|			AND ProductionOrderEnterpriseResources.Finish between &StartDate AND &EndDate
	|			AND (&FilterByKeyResource
	|					OR ProductionOrderEnterpriseResources.EnterpriseResource IN (&FilterKeyResourcesList))
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			FALSE,
	|			CustomerOrderEnterpriseResources.EnterpriseResource,
	|			CustomerOrderEnterpriseResources.Capacity,
	|			CustomerOrderEnterpriseResources.Start,
	|			CustomerOrderEnterpriseResources.Finish
	|		FROM
	|			Document.CustomerOrder.EnterpriseResources AS CustomerOrderEnterpriseResources
	|		WHERE
	|			CustomerOrderEnterpriseResources.Ref.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
	|			AND (NOT CustomerOrderEnterpriseResources.EnterpriseResource.DeletionMark)
	|			AND CustomerOrderEnterpriseResources.Ref.Posted
	|			AND ((NOT CustomerOrderEnterpriseResources.Ref.Closed)
	|					OR CustomerOrderEnterpriseResources.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|			AND CustomerOrderEnterpriseResources.Start between &StartDate AND &EndDate
	|			AND CustomerOrderEnterpriseResources.Finish between &StartDate AND &EndDate
	|			AND (&FilterByKeyResource
	|					OR CustomerOrderEnterpriseResources.EnterpriseResource IN (&FilterKeyResourcesList))
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			TRUE,
	|			ResourcesTable.EnterpriseResource,
	|			ResourcesTable.Capacity,
	|			ResourcesTable.Start,
	|			ResourcesTable.Finish
	|		FROM
	|			TemporaryTableRequest AS ResourcesTable
	|		WHERE
	|			ResourcesTable.Start between &StartDate AND &EndDate
	|			AND ResourcesTable.Finish between &StartDate AND &EndDate
	|			AND (&FilterByKeyResource
	|					OR ResourcesTable.EnterpriseResource IN (&FilterKeyResourcesList))) AS NestedSelect
	|		ON EnterpriseResourceTempTable.EnterpriseResource = NestedSelect.EnterpriseResource
	|
	|ORDER BY
	|	EnterpriseResourceTempTable.ResourceDescription,
	|	BeginTime,
	|	EndTime
	|TOTALS
	|	MIN(Capacity)
	|BY
	|	EnterpriseResource";
	
	Query.SetParameter("StartDate", CalendarDateBegin);
	Query.SetParameter("EndDate", CalendarDateEnd);
	Query.SetParameter("FilterByKeyResource", ResourcesList = Undefined);
	Query.SetParameter("FilterKeyResourcesList", ResourcesList);
	Query.SetParameter("ResourcesTable", ResourcesTable);
	Query.SetParameter("CurrentDocument", CurrentDocument);
	
	Return Query.ExecuteBatch();
	
EndFunction // GetResourcesUpoadSchedule()

// The function returns the value of cell decryption.
//
&AtServer
Function GetCellDetails(EnterpriseResource, Interval, Capacity, Import = 0, Edit = False)
	
	DetailsStructure = New Structure;
	DetailsStructure.Insert("EnterpriseResource", EnterpriseResource);
	DetailsStructure.Insert("Interval", Interval);
	DetailsStructure.Insert("Capacity", Capacity);
	DetailsStructure.Insert("Import", Import);
	DetailsStructure.Insert("Edit", False);
	
	Return DetailsStructure;
	
EndFunction // GetCellDecryption()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SmallBusinessServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues
	);
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	SubsidiaryCompany = SmallBusinessServer.GetCompany(Object.Company);
	
	GetOperationKindsStructure();
	SetVisibleAndEnabled();
	
	If ValueIsFilled(Object.Ref) Then
		NotifyWorkCalendar = False;
	Else
		NotifyWorkCalendar = True;
	EndIf; 
	DocumentModified = False;
	
	If Not Constants.FunctionalOptionAccountingByMultipleDepartments.Get()
		AND Not Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
		
		Items.StructuralUnit.ListChoiceMode = True;
		Items.StructuralUnit.ChoiceList.Add(Catalogs.StructuralUnits.MainDepartment);
		Items.StructuralUnit.ChoiceList.Add(Catalogs.StructuralUnits.MainWarehouse);
		
	EndIf;
	
	// Setting calendar period.
	CalendarDate = Object.Start;
	FillCalendarParametersOnCreateAtServer();
	CalendarDateBegin = BegOfDay(CalendarDate);
	CalendarDateEnd = EndOfDay(CalendarDate);
	
	ColorBusyResource = StyleColors.BusyResource;
	ColorEditing = StyleColors.CurrentTimeInterval;
	
	// Resources table (structure) filling.
	StructureResourcesTS = New Structure;
	ArrayOfResourcesInUse = New Array;
	For Each TSRow IN Object.EnterpriseResources Do
		StringStructure = New Structure;
		StringStructure.Insert("EnterpriseResource", TSRow.EnterpriseResource);
		StringStructure.Insert("Capacity", TSRow.Capacity);
		StringStructure.Insert("Duration", TSRow.Duration);
		StringStructure.Insert("Start", TSRow.Start);
		StringStructure.Insert("Finish", TSRow.Finish);
		ArrayOfResourcesInUse.Add(StringStructure);
	EndDo;
	StructureResourcesTS.Insert("Ref", Object.Ref);
	StructureResourcesTS.Insert("TabularSection", ArrayOfResourcesInUse);
	
	UpdateCalendar(StructureResourcesTS);
	
	If Not Constants.UseProductionOrderStates.Get() Then
		
		Items.GroupState.Visible = False;
		
		InProcessStatus = Constants.ProductionOrdersInProgressStatus.Get();
		CompletedStatus = Constants.ProductionOrdersCompletedStatus.Get();
		
		Items.Status.ChoiceList.Add("In process", "In process");
		Items.Status.ChoiceList.Add("Completed", "Completed");
		Items.Status.ChoiceList.Add("Canceled", "Canceled");
		
		If Object.OrderState.OrderStatus = Enums.OrderStatuses.InProcess AND Not Object.Closed Then
			Status = "In process";
		ElsIf Object.OrderState.OrderStatus = Enums.OrderStatuses.Completed Then
			Status = "Completed";
		Else
			Status = "Canceled";
		EndIf;
		
	Else
		
		Items.GroupStatuses.Visible = False;
		
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// Mechanism handler "ObjectVersioning".
	ObjectVersioning.OnCreateAtServer(ThisForm);
	
EndProcedure // OnCreateAtServer()

// Procedure - OnOpen form event handler
//
&AtClient
Procedure OnOpen(Cancel)
	
	GenerateScheduledWorksPeriod();
	
	WhenChangingStart = Object.Start;
	WhenChangingFinish = Object.Finish;
	
EndProcedure // OnOpen()

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ChangeProhibitionDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
EndProcedure // OnReadAtServer()

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	If DocumentModified Then
		NotifyWorkCalendar = True;
		DocumentModified = False;
	EndIf;
	
EndProcedure // AfterWrite()

// Procedure-handler of the BeforeWriteAtServer event.
// Performs initial attributes forms filling.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Modified Then
		DocumentModified = True;
	EndIf;
	
EndProcedure // BeforeWriteAtServer()

// Procedure - event handler BeforeClose form.
//
&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If NotifyWorkCalendar Then
		Notify("ChangedProductionOrder", Object.Responsible);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// COMMAND ACTIONS OF THE ORDER STATES PANEL

// Procedure - event handler OnChange input field Status.
//
&AtClient
Procedure StatusOnChange(Item)
	
	If Status = "In process" Then
		Object.OrderState = InProcessStatus;
		Object.Closed = False;
	ElsIf Status = "Completed" Then
		Object.OrderState = CompletedStatus;
		Object.Closed = True;
	ElsIf Status = "Canceled" Then
		Object.OrderState = InProcessStatus;
		Object.Closed = True;
	EndIf;
	
	Modified = True;
	
EndProcedure // StatusOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF HEADER ATTRIBUTES

// Procedure - event handler OnChange of the Company input field.
// The procedure is used to
// clear the document number and set the parameters of the form functional options.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	SubsidiaryCompany = StructureData.SubsidiaryCompany;
	
EndProcedure // CompanyOnChange()

// Procedure - handler of the ChoiceProcessing of the OperationKind input field.
//
&AtClient
Procedure OperationKindChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If ValueSelected = OperationKinds.Disassembly Then
		
		For Each StringProducts IN Object.Products Do
			
			If Not StringProducts.ProductsAndServicesTypeInventory Then
				
				MessageText = NStr("en='Disassembling operation is invalid for works and services!
		|The %ProductsAndServicesPresentation% products and services could be a work(service) in the %Number% string of the tabular section ""Products""';ru='Операция разборки не выполняется для работ и услуг!
		|В строке №%Номер% табличной части ""Продукция"" номенклатура ""%НоменклатураПредставление%"" является работой (услугой)'");
				MessageText = StrReplace(MessageText, "%Number%", StringProducts.LineNumber);
				MessageText = StrReplace(MessageText, "%ProductsAndServicesPresentation%", String(StringProducts.ProductsAndServices));
				
				SmallBusinessClient.ShowMessageAboutError(Object, MessageText);
				StandardProcessing = False;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure // OperationKindChoiceProcessing()

// Procedure - event handler OnChange of the OperationKind input field.
//
&AtClient
Procedure OperationKindOnChange(Item)
	
	SetVisibleAndEnabled();
	
EndProcedure // OperationKindOnChange()

// Procedure - event handler Field opening StructuralUnit.
//
&AtClient
Procedure StructuralUnitOpening(Item, StandardProcessing)
	
	If Items.StructuralUnit.ListChoiceMode
		AND Not ValueIsFilled(Object.StructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure // StructuralUnitOpening()

// Procedure - OnChange event handler of Resource input field.
//
&AtClient
Procedure FilterKeyResourceOnChange(Item)
	
	StructureResourcesTS = GetTableOfResourcesInUse();
	UpdateCalendar(StructureResourcesTS);
	
EndProcedure // FilterKeyResourceOnChange()

// Procedure - OnChange event handler of ResourceKind input field.
//
&AtClient
Procedure FilterResourceKindOnChange(Item)
	
	StructureResourcesTS = GetTableOfResourcesInUse();
	UpdateCalendar(StructureResourcesTS);
	
EndProcedure // FilterResourceKindOnChange()

// Procedure - handler of Calendar command.
//
&AtClient
Procedure PeriodPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	ParametersStructure = New Structure("CalendarDate", CalendarDate);
	CalendarDateBegin = Undefined;

	OpenForm("CommonForm.CalendarForm", ParametersStructure,,,,, New NotifyDescription("PeriodPresentationStartChoiceEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure PeriodPresentationStartChoiceEnd(Result, AdditionalParameters) Export
	
	If ValueIsFilled(Result) Then
		
		CalendarDateBegin = Result;
		
		CalendarDate = EndOfDay(CalendarDateBegin);
		GenerateScheduledWorksPeriod();
		
		StructureResourcesTS = GetTableOfResourcesInUse();
		UpdateCalendar(StructureResourcesTS);
		
	EndIf;
	
EndProcedure // PeriodPresentationStartChoice()

// Procedure - handler of ShortenPeriod command.
//
&AtClient
Procedure ShortenPeriod(Command)
	
	CalendarDate = EndOfDay(CalendarDate - 60 * 60 * 24);
	GenerateScheduledWorksPeriod();
	
	StructureResourcesTS = GetTableOfResourcesInUse();
	UpdateCalendar(StructureResourcesTS);
	
EndProcedure // ShortenPeriod()

// Procedure - handler of ExtendPeriod command.
//
&AtClient
Procedure ExtendPeriod(Command)
	
	CalendarDate = EndOfDay(CalendarDate + 60 * 60 * 24);
	GenerateScheduledWorksPeriod();
	
	StructureResourcesTS = GetTableOfResourcesInUse();
	UpdateCalendar(StructureResourcesTS);
	
EndProcedure // ExtendPeriod()

// Procedure - Refresh command handler.
//
&AtClient
Procedure Refresh(Command)
	
	StructureResourcesTS = GetTableOfResourcesInUse();
	UpdateCalendar(StructureResourcesTS);
	
EndProcedure // Refresh()

// Procedure - event handler OnChange input field Start.
//
&AtClient
Procedure StartOnChange(Item)
	
	If Object.Start > Object.Finish Then
		Object.Start = WhenChangingStart;
		Message(NStr("en='Start date can not be later than the end date.';ru='Дата старта не может быть больше даты финиша.'"));
	Else
		WhenChangingStart = Object.Start;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange input field Finish.
//
&AtClient
Procedure FinishOnChange(Item)
	
	If Hour(Object.Finish) = 0 AND Minute(Object.Finish) = 0 Then
		Object.Finish = EndOfDay(Object.Finish);
	EndIf;
	
	If Object.Finish < Object.Start Then
		Object.Finish = WhenChangingFinish;
		Message(NStr("en='Finish date can not be less than the start date.';ru='Дата финиша не может быть меньше даты старта.'"));
	Else
		WhenChangingFinish = Object.Finish;
	EndIf;
	
EndProcedure // FinishOnChange()


////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF THE PRODUCTS TABULAR SECTION ATTRIBUTES

// Procedure - event handler OnChange of the ProductsAndServices input field.
//
&AtClient
Procedure ProductsProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Specification = StructureData.Specification;
	
	TabularSectionRow.ProductsAndServicesType = StructureData.ProductsAndServicesType;
	
EndProcedure // ProductsProductsAndServicesOnChange()

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure ProductsCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure // ProductsCharacteristicOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENTS HANDLERS OF THE ENTERPRISE RESOURCES TABULAR SECTION ATTRIBUTES

// Procedure calculates start and finish values.
//
&AtClient
Procedure CalculateStartAndFinishOfRequest()
	
	MinStart = '00010101';
	MaxFinish = '00010101';
	For Each RowResource IN Object.EnterpriseResources Do
		If MinStart > RowResource.Start OR MinStart = '00010101' Then
			MinStart = RowResource.Start;
		EndIf;
		If MaxFinish < RowResource.Finish OR MaxFinish = '00010101' Then
			MaxFinish = RowResource.Finish;
		EndIf;
	EndDo;
	
	Object.Start = MinStart;
	Object.Finish = MaxFinish;
	
	WhenChangingStart = Object.Start;
	WhenChangingFinish = Object.Finish;
	
EndProcedure // CalculateRequestStartAndFinish()

// Procedure calculates the operation duration.
//
// Parameters:
//  No.
//
&AtClient
Function CalculateDuration(CurrentRow)
	
	DurationInSeconds = CurrentRow.Finish - CurrentRow.Start;
	Hours = Int(DurationInSeconds / 3600);
	Minutes = (DurationInSeconds - Hours * 3600) / 60;
	Duration = Date(0001, 01, 01, Hours, Minutes, 0);
	
	Return Duration;
	
EndFunction // CalculateDuration()

// It receives data set from the server for the EnterpriseResourcesOnStartEdit procedure.
//
&AtClient
Function GetDataEnterpriseResourcesOnStartEdit(DataStructure)
	
	DataStructure.Start = Object.Start - Second(Object.Start);
	DataStructure.Finish = Object.Finish - Second(Object.Finish);
	
	If ValueIsFilled(DataStructure.Start) AND ValueIsFilled(DataStructure.Finish) Then
		If BegOfDay(DataStructure.Start) <> BegOfDay(DataStructure.Finish) Then
			DataStructure.Finish = EndOfDay(DataStructure.Start) - 59;
		EndIf;
		If DataStructure.Start >= DataStructure.Finish Then
			DataStructure.Finish = DataStructure.Start + 1800;
			If BegOfDay(DataStructure.Finish) <> BegOfDay(DataStructure.Start) Then
				If EndOfDay(DataStructure.Start) = DataStructure.Start Then
					DataStructure.Start = DataStructure.Start - 29 * 60;
				EndIf;
				DataStructure.Finish = EndOfDay(DataStructure.Start) - 59;
			EndIf;
		EndIf;
	ElsIf ValueIsFilled(DataStructure.Start) Then
		DataStructure.Start = DataStructure.Start;
		DataStructure.Finish = EndOfDay(DataStructure.Start) - 59;
		If DataStructure.Finish = DataStructure.Start Then
			DataStructure.Start = BegOfDay(DataStructure.Start);
		EndIf;
	ElsIf ValueIsFilled(DataStructure.Finish) Then
		DataStructure.Start = BegOfDay(DataStructure.Finish);
		DataStructure.Finish = DataStructure.Finish;
		If DataStructure.Finish = DataStructure.Start Then
			DataStructure.Finish = EndOfDay(DataStructure.Finish) - 59;
		EndIf;
	Else
		DataStructure.Start = BegOfDay(CurrentDate());
		DataStructure.Finish = EndOfDay(CurrentDate()) - 59;
	EndIf;
	
	DurationInSeconds = DataStructure.Finish - DataStructure.Start;
	Hours = Int(DurationInSeconds / 3600);
	Minutes = (DurationInSeconds - Hours * 3600) / 60;
	Duration = Date(0001, 01, 01, Hours, Minutes, 0);
	DataStructure.Duration = Duration;
	
	Return DataStructure;
	
EndFunction // GetDataEnterpriseResourcesOnStartEdit()

// Procedure - event handler OnStartEdit tabular section EnterpriseResources.
//
&AtClient
Procedure EnterpriseResourcesOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		
		TabularSectionRow = Items.EnterpriseResources.CurrentData;
		
		DataStructure = New Structure;
		DataStructure.Insert("Start", '00010101');
		DataStructure.Insert("Finish", '00010101');
		DataStructure.Insert("Duration", '00010101');
		
		DataStructure = GetDataEnterpriseResourcesOnStartEdit(DataStructure);
		TabularSectionRow.Start = DataStructure.Start;
		TabularSectionRow.Finish = DataStructure.Finish;
		TabularSectionRow.Duration = DataStructure.Duration;
		
		CalculateStartAndFinishOfRequest();
		
	EndIf;
	
EndProcedure // EnterpriseResourcesOnStartEdit()

// Procedure - handler of event AfterDelete of the EnterpriseResources tabular section.
//
&AtClient
Procedure EnterpriseResourcesAfterDeleteRow(Item)
	
	CalculateStartAndFinishOfRequest();
	
EndProcedure // EnterpriseResourcesAfterDeleteRow

// Procedure - event handler OnChange input field EnterpriseResource.
//
&AtClient
Procedure EnterpriseResourcesEnterpriseResourceOnChange(Item)
	
	TabularSectionRow = Items.EnterpriseResources.CurrentData;
	TabularSectionRow.Capacity = 1;
	
EndProcedure // EnterpriseResourcesEnterpriseResourceOnChange()

// Procedure - event handler OnChange input field Day.
//
&AtClient
Procedure EnterpriseResourcesDayOnChange(Item)
	
	CurrentRow = Items.EnterpriseResources.CurrentData;
	
	If CurrentRow.Start = '00010101' Then
		CurrentRow.Start = CurrentDate();
	EndIf;
	
	FinishInSeconds = Hour(CurrentRow.Finish) * 3600 + Minute(CurrentRow.Finish) * 60;
	DurationInSeconds = Hour(CurrentRow.Duration) * 3600 + Minute(CurrentRow.Duration) * 60;
	CurrentRow.Finish = BegOfDay(CurrentRow.Start) + FinishInSeconds;
	CurrentRow.Start = CurrentRow.Finish - DurationInSeconds;
	
	CalculateStartAndFinishOfRequest();
	
EndProcedure // EnterpriseResourcesDayOnChange()

// Procedure - event handler OnChange input field Duration.
//
&AtClient
Procedure EnterpriseResourcesDurationOnChange(Item)
	
	CurrentRow = Items.EnterpriseResources.CurrentData;
	DurationInSeconds = Hour(CurrentRow.Duration) * 3600 + Minute(CurrentRow.Duration) * 60;
	If DurationInSeconds = 0 Then
		CurrentRow.Finish = CurrentRow.Start + 1800;
	Else
		CurrentRow.Finish = CurrentRow.Start + DurationInSeconds;
	EndIf;
	If BegOfDay(CurrentRow.Start) <> BegOfDay(CurrentRow.Finish) Then
		CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
	EndIf;
	If CurrentRow.Start >= CurrentRow.Finish Then
		CurrentRow.Finish = CurrentRow.Start + 1800;
		If BegOfDay(CurrentRow.Finish) <> BegOfDay(CurrentRow.Start) Then
			If EndOfDay(CurrentRow.Start) = CurrentRow.Start Then
				CurrentRow.Start = CurrentRow.Start - 29 * 60;
			EndIf;
			CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
		EndIf;
	EndIf;
	
	CurrentRow.Duration = CalculateDuration(CurrentRow);
	
	CalculateStartAndFinishOfRequest();
	
EndProcedure // EnterpriseResourcesDurationOnChange()

// Procedure - event handler OnChange input field Start.
//
&AtClient
Procedure EnterpriseResourcesStartOnChange(Item)
	
	CurrentRow = Items.EnterpriseResources.CurrentData;
	
	If CurrentRow.Start = '00010101' Then
		CurrentRow.Start = BegOfDay(CurrentRow.Finish);
	EndIf;
	
	If CurrentRow.Start >= CurrentRow.Finish Then
		CurrentRow.Finish = CurrentRow.Start + 1800;
		If BegOfDay(CurrentRow.Finish) <> BegOfDay(CurrentRow.Start) Then
			If EndOfDay(CurrentRow.Start) = CurrentRow.Start Then
				CurrentRow.Start = CurrentRow.Start - 29 * 60;
			EndIf;
			CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
		EndIf;
	EndIf;
	
	CurrentRow.Duration = CalculateDuration(CurrentRow);
	
	CalculateStartAndFinishOfRequest();
	
EndProcedure // EnterpriseResourcesStartOnChange()

// Procedure - event handler OnChange input field Finish.
//
&AtClient
Procedure EnterpriseResourcesFinishOnChange(Item)
	
	CurrentRow = Items.EnterpriseResources.CurrentData;
	
	If Hour(CurrentRow.Finish) = 0 AND Minute(CurrentRow.Finish) = 0 Then
		CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
	EndIf;
	If CurrentRow.Start >= CurrentRow.Finish Then
		CurrentRow.Finish = CurrentRow.Start + 1800;
		If BegOfDay(CurrentRow.Finish) <> BegOfDay(CurrentRow.Start) Then
			If EndOfDay(CurrentRow.Start) = CurrentRow.Start Then
				CurrentRow.Start = CurrentRow.Start - 29 * 60;
			EndIf;
			CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
		EndIf;
	EndIf;
	
	CurrentRow.Duration = CalculateDuration(CurrentRow);
	
	CalculateStartAndFinishOfRequest();
	
EndProcedure // EnterpriseResourcesFinishOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF TABULAR DOCUMENT

// Procedure - DecryptionProcessor event handler.
//
&AtClient
Procedure ResourcesImportDetailProcessing(Item, Details, StandardProcessing)
	
	If TypeOf(Details) = Type("Structure") Then
		
		StandardProcessing = False;
		
		MatchFound = False;
		SearchStructure = New Structure;
		SearchStructure.Insert("EnterpriseResource", Details.EnterpriseResource);
		RowArray = Object.EnterpriseResources.FindRows(SearchStructure);
		For Each RowsArrayItm IN RowArray Do
			If RowsArrayItm.Start = Details.Interval
				AND RowsArrayItm.Finish = Details.Interval + RepetitionFactorOFDay * 60 
				AND Not MatchFound Then
				RowsArrayItm.Capacity = RowsArrayItm.Capacity + 1;
				MatchFound = True;
			EndIf;
		EndDo;
		
		If Not MatchFound Then
			NewRow = Object.EnterpriseResources.Add();
			NewRow.EnterpriseResource = Details.EnterpriseResource;
			NewRow.Capacity = 1;
			NewRow.Start = Details.Interval;
			NewRow.Finish = Details.Interval + RepetitionFactorOFDay * 60;
			NewRow.Duration = CalculateDuration(NewRow);
			CalculateStartAndFinishOfRequest();
		EndIf;
		
		UpdateCalendarCell(Item.CurrentArea.Name, Details);
		ThisForm.Modified = True;
		
	EndIf;
	
EndProcedure // ResourcesImportDecryptionProcessor()

// Procedure - handler of the UseResource command.
//
&AtClient
Procedure UseResource(Command)
	
	ResourcesListChanged = False;
	CurrentCalendarArea = Items.ResourcesImport.CurrentArea;
	FirstRow = CurrentCalendarArea.Top;
	LastRow = CurrentCalendarArea.Bottom;
	LastColumn = CurrentCalendarArea.Right;
	While FirstRow <= LastRow Do
		
		PickupStructure = New Structure;
		PickupStructure.Insert("EnterpriseResource");
		PickupStructure.Insert("Capacity");
		PickupStructure.Insert("Start");
		PickupStructure.Insert("Finish");
		PickupStructure.Insert("Duration");
		
		NewInterval = False;
		FirstStart = True;
		FirstColumn = CurrentCalendarArea.Left;
		While FirstColumn <= LastColumn Do
			CellDetails = ResourcesImport.Area(FirstRow, FirstColumn).Details;
			If TypeOf(CellDetails) = Type("Structure") Then
				
				If FirstStart Then
					NewInterval = True;
					PickupStructure.EnterpriseResource = CellDetails.EnterpriseResource;
					PickupStructure.Capacity = 1;
					PickupStructure.Start = CellDetails.Interval;
					
					FirstStart = False;
					ResourcesListChanged = True;
				EndIf;
				
				If NewInterval <> Undefined Then
					PickupStructure.Finish = CellDetails.Interval + RepetitionFactorOFDay * 60;
				EndIf;
				
				CurrentAreaName = "R" + FirstRow + "C" + FirstColumn;
				UpdateCalendarCell(CurrentAreaName, CellDetails);
				
			EndIf;
			FirstColumn = FirstColumn + 1;
		EndDo;
		
		If NewInterval Then
			
			MatchFound = False;
			SearchStructure = New Structure;
			SearchStructure.Insert("EnterpriseResource", PickupStructure.EnterpriseResource);
			RowArray = Object.EnterpriseResources.FindRows(SearchStructure);
			For Each RowsArrayItm IN RowArray Do
				If RowsArrayItm.Start = PickupStructure.Start
					AND RowsArrayItm.Finish = PickupStructure.Finish
					AND Not MatchFound Then
					RowsArrayItm.Capacity = RowsArrayItm.Capacity + 1;
					MatchFound = True;
				EndIf;
			EndDo;
			
			If Not MatchFound Then
				NewRow = Object.EnterpriseResources.Add();
				NewRow.EnterpriseResource = PickupStructure.EnterpriseResource;
				NewRow.Capacity = PickupStructure.Capacity;
				NewRow.Start = PickupStructure.Start;
				NewRow.Finish = PickupStructure.Finish;
				NewRow.Duration = CalculateDuration(NewRow);
				CalculateStartAndFinishOfRequest();
			EndIf;
			
		EndIf;
		
		FirstRow = FirstRow + 1;
	EndDo;
	
	If ResourcesListChanged Then
		CalculateStartAndFinishOfRequest();
		ThisForm.Modified = True;
	EndIf;
	
EndProcedure // UseResource()

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

// StandardSubsystems.AdditionalReportsAndDataProcessors

&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

// End StandardSubsystems.AdditionalReportsAndDataProcessors

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

// StandardSubsystems.AdditionalReportsAndDataProcessors

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure

// End StandardSubsystems.AdditionalReportsAndDataProcessors














