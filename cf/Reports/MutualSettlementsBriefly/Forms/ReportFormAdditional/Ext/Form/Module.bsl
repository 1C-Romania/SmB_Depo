////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Procedure writes the user setting parameter at server
//
// ParameterName - text parameter identifier 
// ParameterValue - parameter value for record
//
&AtServer
Procedure SetParameterAtServer(ParameterName, ParameterValue)
	
	CompositionSetup	= Report.SettingsComposer.Settings;
	FoundSetting	= CompositionSetup.DataParameters.Items.Find(ParameterName);
	
	If Not FoundSetting = Undefined Then
		
		UserSettingsItem = Report.SettingsComposer.UserSettings.Items.Find(FoundSetting.UserSettingID);
		UserSettingsItem.Use = True;
		UserSettingsItem.Value = ParameterValue;
		
	EndIf;
		
EndProcedure // SetParameterAtServer()

// Procedure sets new filter item value user settings of data composition
//
// CompositionFilterCorrespondence - compliance, contains setting filter items of data composition
// and its identifiers FilterItemFromParameters - form parameter structure item, contains key and
// value filter items UserSettingFilter - item collection of
// user setting filter FilterValue - filter
// value CompositionComparisonKind - comparsion kind
// of data composition Usage - filter use value of data composition
//
&AtServer
Procedure SetDataCompositionFilterItemAtServer(CompositionFilterCorrespondence, FilterItemFromParameters, UserSettingsFilter, FilterValue, CompositionComparisonType, Use)
	
	CompositionFilterNewField	= New DataCompositionField(FilterItemFromParameters.Key);
	UserSettingIdentifyer	= CompositionFilterCorrespondence.Get(CompositionFilterNewField);
	
	If Not UserSettingIdentifyer = Undefined Then
		
		UserSettingsItem = UserSettingsFilter.Items.Find(UserSettingIdentifyer);
		
		If Not UserSettingsItem = Undefined Then
			
			UserSettingsItem.Use = Use;
			UserSettingsItem.ComparisonType = CompositionComparisonType;
			UserSettingsItem.RightValue = FilterValue;
			
		EndIf;
		
	EndIf;
	
EndProcedure // SetDataCompositionFilterItemAtServer()

// Function creates, fills and returns setting filter item compliance of data composition and its identifiers
//
&AtServer
Function GetCompositionSettingsFilterItemsCorrespondenceAtServer()
	
	CompositionFilterCorrespondence = New Map();
	
	CompositionFilter	= Report.SettingsComposer.Settings.Filter;
	For Each CompositionFilterItem IN CompositionFilter.Items Do
		
		CompositionFilterCorrespondence.Insert(CompositionFilterItem.LeftValue, CompositionFilterItem.UserSettingID);
		
	EndDo;
	
	Return CompositionFilterCorrespondence;
	
EndFunction // GetCompositionSettingsFilterItemsCorrespondenceAtServer()

//
//
&AtServer
Function GetNeededGrouping(DCSStructure, GroupingName)
	
	SearchedGrouping			= Undefined;
	
	For GroupingCounter = 0 To DCSStructure.Count() - 1 Do
		
		GroupingStructure = DCSStructure[GroupingCounter];
		
		If GroupingStructure.Name = GroupingName Then
			
			Return GroupingStructure;
			
		ElsIf GroupingStructure.Structure.Count() > 0 Then
			
			SearchedGrouping = GetNeededGrouping(GroupingStructure.Structure, GroupingName);
			If Not SearchedGrouping = Undefined Then
				
				Return SearchedGrouping;
				
			EndIf;
			
		EndIf;
		
	EndDo;
		
	Return SearchedGrouping;
	
EndFunction //GetNeededGrouping()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR CONTROL OF THE FORM APPEARANCE

// Procedure sets the external period button kind on the form
//
// NameButtons - text button identifier which is to be set to the "Enabled" state.
// 				other buttons will change their state to "Disabled".
// 				If the button is not found, all buttons will change their state to "Disabled".
//
&AtClient
Procedure EnableButtonAtClient(NameButtons)
	
	If Not ValueIsFilled(NameButtons) Then
		
		SwitchingPeriods = "";
		
	Else
		
		SwitchingPeriods = NameButtons;
		
	EndIf;
	
EndProcedure // EnableButtonAtClient()

// Procedure sets the compositing data parameters and period label
// on the form by received parameters
//
// Data composition changeable parameters:
// Begin of period - date, report generation beginning of the period
// End of period - date, report generation end of the period
//
&AtServer
Procedure SetPeriod(PeriodName, Direction)
	
	BeginOfPeriodValue 		= BegOfDay(CurrentDate());
	ValueEndPeriod	= EndOfDay(CurrentDate());
	
	If PeriodName = "Week" Then
		
		EndOfPeriod = ?(EndOfPeriod = Date(1,1,1), CurrentDate(), EndOfPeriod);
		
		BeginOfPeriodValue 		= BegOfWeek(EndOfPeriod + (86400 * 7 * Direction));
		ValueEndPeriod	= EndOfWeek(EndOfPeriod + (86400 * 7 * Direction));
		
	ElsIf PeriodName = "Month" Then
		
		EndOfPeriod = ?(EndOfPeriod = Date(1,1,1), CurrentDate(), EndOfPeriod);
		
		BeginOfPeriodValue 		= BegOfMonth(AddMonth(EndOfPeriod, (1 * Direction)));
		ValueEndPeriod	= EndOfMonth(AddMonth(EndOfPeriod, (1 * Direction)));
		
	ElsIf PeriodName = "Quarter" Then
		
		EndOfPeriod = ?(EndOfPeriod = Date(1,1,1), CurrentDate(), EndOfPeriod);
		
		BeginOfPeriodValue 		= BegOfQuarter(AddMonth(EndOfPeriod, (3 * Direction)));
		ValueEndPeriod	= EndOfQuarter(AddMonth(EndOfPeriod, (3 * Direction)));
		
	ElsIf PeriodName = "Year" Then
		
		EndOfPeriod = ?(EndOfPeriod = Date(1,1,1), CurrentDate(), EndOfPeriod);
		
		BeginOfPeriodValue 		= BegOfYear(AddMonth(EndOfPeriod, (12 * Direction)));
		ValueEndPeriod	= EndOfYear(AddMonth(EndOfPeriod, (12 * Direction)));
		
	EndIf;
		
	SetParameterAtServer("BeginOfPeriod", BeginOfPeriodValue);
	SetParameterAtServer("EndOfPeriod", ValueEndPeriod);
	
	BeginOfPeriod = BeginOfPeriodValue;
	EndOfPeriod = ValueEndPeriod;
	
	Result.Clear();
	
	//Indicate to user that it is necessary to generate (update) the report
	Result.Area(2,2,2,2).Text 		= NStr("en='Report is not generated. Click Create to generate the report.';ru='Отчет не сформирован. Нажмите ""Сформировать"" для получения отчета.'");
	Result.Area(2,2,2,2).TextColor 	= New Color(138,138,138);
	Result.Area(2,2,2,2).Font 		= New Font(Result.Area(2,2,2,2).Font, ,12);
	
EndProcedure // SetPeriod()

// Procedure generates and updates period label on the form
//
&AtClient
Procedure SetPeriodLabel()
	
	//If no button is enabled - Arbitrary period
	If IsBlankString(SwitchingPeriods) Then
		
		PeriodPresentation = "Arbitrary period";
		
	ElsIf Month(BeginOfPeriod) = Month(EndOfPeriod) Then
		
		DayOfScheduleBegin = Format(BeginOfPeriod, "DF=dd");
		DayOfScheduleEnd = Format(EndOfPeriod, "DF=dd");
		MonthOfScheduleEnd = Format(EndOfPeriod, "DF=MMM");
		YearOfSchedule = Format(Year(EndOfPeriod), "NG=0");
		
		PeriodPresentation = DayOfScheduleBegin + " - " + DayOfScheduleEnd + " " + MonthOfScheduleEnd + ", " + YearOfSchedule;
		
	Else
		
		DayOfScheduleBegin = Format(BeginOfPeriod, "DF=dd");
		MonthOfScheduleBegin = Format(BeginOfPeriod, "DF=MMM");
		DayOfScheduleEnd = Format(EndOfPeriod, "DF=dd");
		MonthOfScheduleEnd = Format(EndOfPeriod, "DF=MMM");
		
		If Year(BeginOfPeriod) = Year(EndOfPeriod) Then
			YearOfSchedule = Format(Year(EndOfPeriod), "NG=0");
			PeriodPresentation = DayOfScheduleBegin + " " + MonthOfScheduleBegin + " - " + DayOfScheduleEnd + " " + MonthOfScheduleEnd + ", " + YearOfSchedule;
			
		Else
			YearOfScheduleBegin = Format(Year(BeginOfPeriod), "NG=0");
			YearOfScheduleEnd = Format(Year(EndOfPeriod), "NG=0");
			PeriodPresentation = DayOfScheduleBegin + " " + MonthOfScheduleBegin + " " + YearOfScheduleBegin + " - " + DayOfScheduleEnd + " " + MonthOfScheduleEnd + " " + YearOfScheduleEnd;
			
		EndIf;
		
	EndIf;
	
EndProcedure // SetPeriodLabel()


////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	StandardProcessing = False;
	
	//	Buttons and parameters 
	If Parameters.Property("Period") Then
		
		If Not Parameters.Period = Undefined Then
			
			SwitchingPeriods = TrimAll(Parameters.Period);
			
			BeginOfPeriod = Parameters["BeginOfPeriod"];
			EndOfPeriod  = Parameters["EndOfPeriod"];
			
			SetParameterAtServer("BeginOfPeriod", BeginOfPeriod);
			SetParameterAtServer("EndOfPeriod", EndOfPeriod);
			
		EndIf;
		
	Else
		
		SwitchingPeriods = "WeekPeriod";
		
		BeginOfPeriod = BegOfWeek(CurrentDate());
		EndOfPeriod  = EndOfWeek(CurrentDate());
		
		SetParameterAtServer("BeginOfPeriod", BeginOfPeriod);
		SetParameterAtServer("EndOfPeriod", EndOfPeriod);
		
	EndIf;
	
	Items.SettingsComposerUserSettings.Visible = False;
	
	//Indicate to user that it is necessary to generate the report
	Result.Area(2,2,2,2).Text 		= NStr("en='Report is not generated. Click Generate to get the report.';ru='Отчет не сформирован. Нажмите ""Сформировать"" для получения отчета.'");
	Result.Area(2,2,2,2).TextColor 	= New Color(138,138,138);
	Result.Area(2,2,2,2).Font 		= New Font(Result.Area(2,2,2,2).Font, ,12);
	
	// Set data composition filters
	If TypeOf(Parameters.Filter) = Type("Structure") Then
		
		For Each FilterItemFromParameters IN Parameters.Filter Do
		
			SetDataCompositionFilterItemAtServer(GetCompositionSettingsFilterItemsCorrespondenceAtServer(), 
					FilterItemFromParameters, 
					Report.SettingsComposer.UserSettings, 
					FilterItemFromParameters.Value, 
					DataCompositionComparisonType.Equal,
					True);
			
		EndDo;
				
	EndIf;
	
	DCSStructure = Report.SettingsComposer.Settings.Structure;
	
EndProcedure // OnCreateAtServer()

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	SetPeriodLabel();
	
EndProcedure // OnOpen()

// Procedure - event handler OnChange field "Setting composer user settings".
// IN procedure situation is defined when change user date setting "Period start" or "Period end" period label on report form changes
//
&AtClient
Procedure SettingsComposerUserSettingsOnChange(Item)
	
	//Data composition ID
	DataCompositionID = Item.CurrentRow;
	DataCompositionObject = Report.SettingsComposer.UserSettings.GetObjectByID(DataCompositionID);
	
	If Not DataCompositionObject = Undefined
		AND TypeOf(DataCompositionObject) = Type("DataCompositionSettingsParameterValue") Then
		
		DisablePeriodButtons = False;
		
		If DataCompositionObject.Parameter = New DataCompositionParameter("BeginOfPeriod") Then
			
			BeginOfPeriod 			= Date(DataCompositionObject.Value);
			DisablePeriodButtons = True;
			
		EndIf;
		
		If DataCompositionObject.Parameter = New DataCompositionParameter("EndOfPeriod") Then
			
			EndOfPeriod 			= Date(DataCompositionObject.Value);
			DisablePeriodButtons = True;
			
		EndIf;
		
		If DisablePeriodButtons Then
			
			EnableButtonAtClient(Undefined);
			
		EndIf;
		
	EndIf;
	
	SetPeriodLabel();
	
EndProcedure // SettingsComposerUserSettingsOnChange()

&AtClient
Procedure SwitchingPeriodsOnChange(Item)
	
	If SwitchingPeriods = "WeekPeriod" Then
		
		WeekPeriod("");
		
	ElsIf SwitchingPeriods = "MonthPeriod" Then
		
		MonthPeriod("");
		
	ElsIf SwitchingPeriods = "QuarterPeriod" Then
		
		QuarterPeriod("");
		
	ElsIf SwitchingPeriods = "YearPeriod" Then
		
		YearPeriod("");
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM COMMAND HANDLERS

// Procedure is called when clicking "Year" on the report form
// 
&AtClient
Procedure YearPeriod(Command)
	
	EnableButtonAtClient("YearPeriod");
	SetPeriod("Year", 0);
	SetPeriodLabel();
	
EndProcedure // YearPeriod()

// Procedure is called when clicking "Quarter" on the report form
// 
&AtClient
Procedure QuarterPeriod(Command)
	
	EnableButtonAtClient("QuarterPeriod");
	SetPeriod("Quarter", 0);
	SetPeriodLabel();
	
EndProcedure // QuarterPeriod()

// Procedure is called when clicking "Month" on the report form
// 
&AtClient
Procedure MonthPeriod(Command)
	
	EnableButtonAtClient("MonthPeriod");
	SetPeriod("Month", 0);
	SetPeriodLabel();
	
EndProcedure // MonthPeriod()

// Procedure is called when clicking "Week" on the report form
// 
&AtClient
Procedure WeekPeriod(Command)
	
	EnableButtonAtClient("WeekPeriod");
	SetPeriod("Week", 0);
	SetPeriodLabel();
	
EndProcedure // WeekPeriod()

// Procedure is called when clicking "Increase period" button on the report form
// 
&AtClient
Procedure ExtendPeriod(Command)
	
	If SwitchingPeriods = "WeekPeriod" Then
		
		SetPeriod("Week", 1);
		
	ElsIf SwitchingPeriods = "MonthPeriod" Then
		
		SetPeriod("Month", 1);
		
	ElsIf SwitchingPeriods = "QuarterPeriod" Then
		
		SetPeriod("Quarter", 1);
		
	ElsIf SwitchingPeriods = "YearPeriod" Then
		
		SetPeriod("Year", 1);
		
	EndIf;
	
	SetPeriodLabel();
	
EndProcedure // ExtendPeriod()

// Procedure is called when clicking "Shortened period" button on the report form
// 
&AtClient
Procedure ShortenPeriod(Command)
	
	If SwitchingPeriods = "WeekPeriod" Then
		
		SetPeriod("Week", -1);
		
	ElsIf SwitchingPeriods = "MonthPeriod" Then
		
		SetPeriod("Month", -1);
		
	ElsIf SwitchingPeriods = "QuarterPeriod" Then
		
		SetPeriod("Quarter", -1);
		
	ElsIf SwitchingPeriods = "YearPeriod" Then
		
		SetPeriod("Year", -1);
		
	EndIf;
	
	SetPeriodLabel();
	
EndProcedure //ShortenPeriod()

// Procedure is called when clicking "Setting" on the report form
// 
&AtClient
Procedure Setting(Command)
	
	Items.Setting.Check 										= Not Items.Setting.Check;
	Items.SettingsComposerUserSettings.Visible = Items.Setting.Check;
	
EndProcedure // Setting()














