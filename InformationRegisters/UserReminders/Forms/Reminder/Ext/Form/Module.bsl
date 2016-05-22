
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Object.User = Users.CurrentUser();
	
	If Parameters.Property("Source") Then 
		Object.Source = Parameters.Source;
		Object.Definition = CommonUse.SubjectString(Object.Source);
	EndIf;
	
	If Parameters.Property("Key") Then
		InitialParameters = New Structure("User,EventTime,Source");
		FillPropertyValues(InitialParameters, Parameters.Key);
		InitialParameters = New FixedStructure(InitialParameters);
	EndIf;
	
	If ValueIsFilled(Object.Source) Then
		FillAttributesListSource();
	EndIf;
	
	FillInOptionsForFrequency();
	DefineSelectionFrequency();	
	
	IsNew = Not ValueIsFilled(Object.SourceRecordKey);
	Items.Delete.Visible = Not IsNew;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	Schedule = CurrentObject.Schedule.Get();
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If CurrentObject.ReminderTimeSettingVariant = Enums.ReminderTimeSettingVariants.RelativelyToCurrentTime Then
		CurrentObject.EventTime = CurrentSessionDate() + Object.ReminderInterval;
		CurrentObject.ReminderPeriod = CurrentObject.EventTime;
		CurrentObject.ReminderTimeSettingVariant = Enums.ReminderTimeSettingVariants.InSpecifiedTime;
	ElsIf CurrentObject.ReminderTimeSettingVariant = Enums.ReminderTimeSettingVariants.RelativelyToSubjectTime Then
		DateSource = UserRemindersService.GetItemAttributeValue(Object.Source, Object.SourceAttributeName);
		If ValueIsFilled(DateSource) Then
			DateSource = CalculateNextDate(DateSource);
			CurrentObject.EventTime = DateSource;
			CurrentObject.ReminderPeriod = DateSource - Object.ReminderInterval;
		EndIf;
	ElsIf CurrentObject.ReminderTimeSettingVariant = Enums.ReminderTimeSettingVariants.InSpecifiedTime Then
		CurrentObject.ReminderPeriod = Object.EventTime;
	ElsIf CurrentObject.ReminderTimeSettingVariant = Enums.ReminderTimeSettingVariants.Periodically Then
		NextTimeReminders = UserRemindersService.GetTheClosestEventDateOnSchedule(Schedule);
		If NextTimeReminders = Undefined Then
			NextTimeReminders = CurrentSessionDate();
		EndIf;
		CurrentObject.EventTime = NextTimeReminders;
		CurrentObject.ReminderPeriod = CurrentObject.EventTime;
	EndIf;
	
	If CurrentObject.ReminderTimeSettingVariant <> Enums.ReminderTimeSettingVariants.Periodically Then
		Schedule = Undefined;
	EndIf;
	
	CurrentObject.Schedule = New ValueStorage(Schedule, New Deflation(9));
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// if this is new record
	If Not ValueIsFilled(Object.SourceRecordKey) Then
		If Items.SourceAttributeName.ChoiceList.Count() > 0 Then
			Object.SourceAttributeName = Items.SourceAttributeName.ChoiceList[0].Value;
			Object.ReminderTimeSettingVariant = PredefinedValue("Enum.ReminderTimeSettingVariants.RelativelyToSubjectTime");
		EndIf;
		Object.EventTime = CommonUseClient.SessionDate();
	EndIf;
	
	FillListTime();
	
	FillOptionsAlerts();
	If Items.SourceAttributeName.ChoiceList.Count() = 0 Then
		Items.ReminderTimeSettingVariant.ChoiceList.Delete(Items.ReminderTimeSettingVariant.ChoiceList.FindByValue(GetKeyByValueInAccordance(GetPredefinedWaysNotifications(),PredefinedValue("Enum.ReminderTimeSettingVariants.RelativelyToSubjectTime"))));
	EndIf;		
		
	If Object.ReminderInterval > 0 Then
		TimeIntervalAsString = UserRemindersClientServer.TimePresentation(Object.ReminderInterval);
	EndIf;
	
	PredefinedAlertMethods = GetPredefinedWaysNotifications();
	SelectedMethod = GetKeyByValueInAccordance(PredefinedAlertMethods, Object.ReminderTimeSettingVariant);
	
	If Object.ReminderTimeSettingVariant = PredefinedValue("Enum.ReminderTimeSettingVariants.RelativelyToCurrentTime") Then
		ReminderTimeSettingVariant = NStr("en = 'through'") + " " + UserRemindersClientServer.TimePresentation(Object.ReminderInterval);
	Else
		ReminderTimeSettingVariant = SelectedMethod;
	EndIf;
	
	SetVisible();
	
	UpdateEstimatedTimeReminders();
	AttachIdleHandler("UpdateEstimatedTimeReminders", 1);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	// for update cache
	ParametersStructure = UserRemindersClientServer.GetReminderStructure(Object, True);
	ParametersStructure.Insert("PictureIndex", 2);
	
	UserRemindersClient.UpdateRecordInNotificationsCache(ParametersStructure);
	
	UserRemindersClient.ResetTimerOnCurrentNotificationsCheck();
	
	If ValueIsFilled(Object.Source) Then 
		NotifyChanged(Object.Source);
	EndIf;
	
	Notify("Record_UserReminders", New Structure, ThisObject);
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	If InitialParameters <> Undefined Then 
		UserRemindersClient.DeleteRecordFromNotificationCache(InitialParameters);
	EndIf;
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ReminderTimeSettingVariantOnChange(Item)
	ClearMessages();
	
	TimeInterval = UserRemindersClientServer.GetTimeIntervalFromString(ReminderTimeSettingVariant);
	If TimeInterval > 0 Then
		TimeIntervalAsString = UserRemindersClientServer.TimePresentation(TimeInterval);
		ReminderTimeSettingVariant = NStr("en = 'through'") + " " + TimeIntervalAsString;
	Else
		If Items.ReminderTimeSettingVariant.ChoiceList.FindByValue(ReminderTimeSettingVariant) = Undefined Then
			CommonUseClientServer.MessageToUser(NStr("en = 'Time interval is not defined.'"), , "ReminderTimeSettingVariant");
		EndIf;
	EndIf;
	
	PredefinedAlertMethods = GetPredefinedWaysNotifications();
	SelectedMethod = PredefinedAlertMethods.Get(ReminderTimeSettingVariant);
	
	If SelectedMethod = Undefined Then
		Object.ReminderTimeSettingVariant = PredefinedValue("Enum.ReminderTimeSettingVariants.RelativelyToCurrentTime");
	Else
		Object.ReminderTimeSettingVariant = SelectedMethod;
	EndIf;
	
	Object.ReminderInterval = TimeInterval;
	
	SetVisible();		
EndProcedure

&AtClient
Procedure TimeIntervalOnChange(Item)
	Object.ReminderInterval = UserRemindersClientServer.GetTimeIntervalFromString(TimeIntervalAsString);
	If Object.ReminderInterval > 0 Then
		TimeIntervalAsString = UserRemindersClientServer.TimePresentation(Object.ReminderInterval);
	Else
		CommonUseClientServer.MessageToUser(NStr("en = 'Time interval is not determined'"), , "TimeIntervalAsString");
	EndIf;
EndProcedure

&AtClient
Procedure VariantFrequencyOnChange(Item)
	OnChangeCalendar();
EndProcedure

&AtClient
Procedure PeriodicityVariantOpenning(Item, StandardProcessing)
	StandardProcessing = False;
	OnChangeCalendar();
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	FillListTime();
EndProcedure

&AtClient
Procedure TimeOnChange(Item)
	Object.EventTime = BegOfMinute(Object.EventTime);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Delete(Command)
	
	DialogButtons = New ValueList;
	DialogButtons.Add(DialogReturnCode.Yes, NStr("en = 'Delete'"));
	DialogButtons.Add(DialogReturnCode.Cancel, NStr("en = 'Don''t delete'"));
	
	NotifyDescription = New NotifyDescription("DeleteReminder", ThisObject);
	ShowQueryBox(NOTifyDescription, NStr("en = 'Delete reminder?'"), DialogButtons);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure DeleteReminder(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		ThisObject.Modified = False;
		If InitialParameters <> Undefined Then 
			DisableReminder();
			UserRemindersClient.DeleteRecordFromNotificationCache(InitialParameters);
			Notify("Record_UserReminders", New Structure, Object.SourceRecordKey);
			NotifyChanged(Type("InformationRegisterRecordKey.UserReminders"));
		EndIf;
		If ThisObject.IsOpen() Then
			Close();
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure DisableReminder()
	UserRemindersService.DisableReminder(InitialParameters, False);
EndProcedure

&AtServerNoContext
Function AttributeSourceExistAndContainsTypeDate(SourceMetadata, AttributeName, VerifyDate = False)
	Result = False;
	If SourceMetadata.Attributes.Find(AttributeName) <> Undefined
		AND SourceMetadata.Attributes[AttributeName].Type.ContainsType(Type("Date")) Then
			Result = True;
	EndIf;
	Return Result;
EndFunction

&AtClientAtServerNoContext
Function GetKeyByValueInAccordance(Map, Value)
	Result = Undefined;
	For Each KeyAndValue IN Map Do
		If TypeOf(Value) = Type("JobSchedule") Then
			If CommonUseClientServer.SchedulesAreEqual(KeyAndValue.Value, Value) Then
		    	Return KeyAndValue.Key;
			EndIf;
		Else
			If KeyAndValue.Value = Value Then
				Return KeyAndValue.Key;
			EndIf;
		EndIf;
	EndDo;
	Return Result;	
EndFunction

&AtClient
Function GetPredefinedWaysNotifications()
	Result = New Map;
	Result.Insert(NStr("en = 'relatively to subject'"), PredefinedValue("Enum.ReminderTimeSettingVariants.RelativelyToSubjectTime"));
	Result.Insert(NStr("en = 'in specified time'"), PredefinedValue("Enum.ReminderTimeSettingVariants.InSpecifiedTime"));
	Result.Insert(NStr("en = 'Periodically'"), PredefinedValue("Enum.ReminderTimeSettingVariants.Periodically"));
	Return Result;
EndFunction
           
&AtClient
Procedure FillOptionsAlerts()
	OptionsAlerts = Items.ReminderTimeSettingVariant.ChoiceList;
	OptionsAlerts.Clear();
	For Each Method IN GetPredefinedWaysNotifications() Do
		OptionsAlerts.Add(Method.Key);
	EndDo;	
	
	Items.TimeIntervalRelativelyToSource.ChoiceList.Clear();
	IntervalsTime = UserRemindersClientServer.GetStandardAlertsIntervals();
	For Each Interval IN IntervalsTime Do
		OptionsAlerts.Add(NStr("en = 'through'") + " " + Interval);
		Items.TimeIntervalRelativelyToSource.ChoiceList.Add(Interval);
	EndDo;
EndProcedure

&AtClient
Procedure FillListTime()
	Items.Time.ChoiceList.Clear();
	For Hour = 0 To 23 Do 
		For Period = 0 To 1 Do
			Time = Hour*60*60 + Period*30*60;
			Items.Time.ChoiceList.Add(BegOfDay(Object.EventTime) + Time, "" + Hour + ":" + Format(Period*30,"ND=2; NZ=00"));		
		EndDo;
	EndDo;
EndProcedure

&AtServer
Procedure FillAttributesListSource()
	
	AttributeArray = New Array;
	
	// Fill in by default
	SourceMetadata = Object.Source.Metadata();	
	For Each Attribute IN SourceMetadata.Attributes Do
		If AttributeSourceExistAndContainsTypeDate(SourceMetadata, Attribute.Name) Then
			AttributeArray.Add(Attribute.Name);
		EndIf;
	EndDo;
	
	// Receive override attribute array.
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.UserReminders\OnFillSourceAttributeListWithReminderDates");
	For Each Handler IN EventHandlers Do
		Handler.Module.OnFillSourceAttributeListWithReminderDates(Object.Source, AttributeArray);
	EndDo;
	UserRemindersClientServerOverridable.OnFillSourceAttributeListWithReminderDates(Object.Source, AttributeArray);
		
	Items.SourceAttributeName.ChoiceList.Clear();
	
	For Each AttributeName IN AttributeArray Do
		If AttributeSourceExistAndContainsTypeDate(SourceMetadata, AttributeName) Then
			If TypeOf(Object.Source[AttributeName]) = Type("Date") AND Object.Source[AttributeName] > CurrentSessionDate() Then
				Attribute = SourceMetadata.Attributes.Find(AttributeName);
				AttributePresentation = ?(IsBlankString(Attribute.Synonym),Attribute.Name, Attribute.Synonym);
				If Items.SourceAttributeName.ChoiceList.FindByValue(AttributeName) = Undefined Then
					Items.SourceAttributeName.ChoiceList.Add(AttributeName, AttributePresentation);
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure FillInOptionsForFrequency()
	Items.FrequencyVariant.ChoiceList.Clear();
	ListOfSchedules = UserRemindersService.GetStandardSchedulesToRemind();
	For Each StandardSchedule IN ListOfSchedules Do
		Items.FrequencyVariant.ChoiceList.Add(StandardSchedule.Key, StandardSchedule.Key);
	EndDo;
	Items.FrequencyVariant.ChoiceList.Add("", NStr("en = 'according to set schedule...'"));	
EndProcedure

&AtClient
Procedure SetVisible()
	
	PredefinedAlertMethods = GetPredefinedWaysNotifications();
	SelectedMethod = PredefinedAlertMethods.Get(ReminderTimeSettingVariant);
	
	If SelectedMethod <> Undefined Then
		If SelectedMethod = PredefinedValue("Enum.ReminderTimeSettingVariants.InSpecifiedTime") Then
			Items.DetailedSettingsPanel.CurrentPage = Items.DateTime;
		ElsIf SelectedMethod = PredefinedValue("Enum.ReminderTimeSettingVariants.RelativelyToSubjectTime") Then
			Items.DetailedSettingsPanel.CurrentPage = Items.SourceSetting;
		ElsIf SelectedMethod = PredefinedValue("Enum.ReminderTimeSettingVariants.Periodically") Then
			Items.DetailedSettingsPanel.CurrentPage = Items.PeriodicitySetting;
		EndIf;			
	Else
		Items.DetailedSettingsPanel.CurrentPage = Items.WithoutDelatization;
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenScheduleSettingsDialogBox()
	If Schedule = Undefined Then 
		Schedule = New JobSchedule;
		Schedule.DaysRepeatPeriod = 1;
	EndIf;
	ScheduleDialog = New ScheduledJobDialog(Schedule);
	NotifyDescription = New NotifyDescription("OpenDialogScheduleSettingsEnd", ThisObject);
	ScheduleDialog.Show(NOTifyDescription);
EndProcedure

&AtClient
Procedure OpenDialogScheduleSettingsEnd(SelectedSchedule, AdditionalParameters) Export
	If SelectedSchedule = Undefined Then
		Return;
	EndIf;
	Schedule = SelectedSchedule;
	If Not ScheduleMeetsRequirements(Schedule) Then 
		ShowMessageBox(, NStr("en = 'Periodicity throughout the day is not supported, corresponding settings have been cleared.'"));
	EndIf;
	NormalizeSchedule(Schedule);
	DefineSelectionFrequency();
EndProcedure

&AtClient
Function ScheduleMeetsRequirements(TestSchedule)
	If TestSchedule.RepeatPeriodInDay > 0 Then
		Return False;
	EndIf;
	
	For Each DailySchedule IN TestSchedule.DetailedDailySchedules Do
		If DailySchedule.RepeatPeriodInDay > 0 Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
EndFunction

&AtClient
Procedure NormalizeSchedule(ScheduleYouWantToNormalize);
	ScheduleYouWantToNormalize.EndTime = '000101010000';
	ScheduleYouWantToNormalize.CompletionTime =  ScheduleYouWantToNormalize.EndTime;
	ScheduleYouWantToNormalize.RepeatPeriodInDay = 0;
	ScheduleYouWantToNormalize.RepeatPause = 0;
	ScheduleYouWantToNormalize.CompletionInterval = 0;
	For Each DailySchedule IN ScheduleYouWantToNormalize.DetailedDailySchedules Do
		DailySchedule.EndTime = '000101010000';
		DailySchedule.CompletionTime =  DailySchedule.EndTime;
		DailySchedule.RepeatPeriodInDay = 0;
		DailySchedule.RepeatPause = 0;
		DailySchedule.CompletionInterval = 0;
	EndDo;
EndProcedure

&AtServer
Procedure DefineSelectionFrequency()
	StandardTimetable = UserRemindersService.GetStandardSchedulesToRemind();
	
	If Schedule = Undefined Then
		FrequencyVariant = Items.FrequencyVariant.ChoiceList.Get(0).Value;
		Schedule = StandardTimetable[FrequencyVariant];
	Else
		FrequencyVariant = GetKeyByValueInAccordance(StandardTimetable, Schedule);
	EndIf;
	
	Items.FrequencyVariant.OpenButton = IsBlankString(FrequencyVariant);
	Items.FrequencyVariant.ToolTip = Schedule;
EndProcedure

&AtClient
Procedure OnChangeCalendar()
	UserSetting = IsBlankString(FrequencyVariant);
	If UserSetting Then
		OpenScheduleSettingsDialogBox();
	Else
		StandardTimetable = Undefined;
		GetStandardSchedule(StandardTimetable);
		Schedule = StandardTimetable[FrequencyVariant];
	EndIf;
	DefineSelectionFrequency();
EndProcedure

&AtServer
Procedure GetStandardSchedule(StandardTimetable)
	
	StandardTimetable = UserRemindersService.GetStandardSchedulesToRemind();
	
EndProcedure

&AtServer
Function CalculateNextDate(OriginalDate)
	Result = OriginalDate;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	CASE
	|		WHEN &OriginalDate > &CurrentDate
	|			THEN &OriginalDate
	|		ELSE DATEADD(&OriginalDate, YEAR, DATEDIFF(&OriginalDate, &CurrentDate, YEAR))
	|	END AS FutureDate";
	
	Query.SetParameter("OriginalDate", OriginalDate);
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then 
		Result = Selection.FutureDate;
	EndIf;
	
	Return Result;
EndFunction

&AtClient
Function EstimatedTimeLine()
	
	CurrentDate = CommonUseClient.SessionDate();
	ReminderCalculatingTime = CurrentDate + Object.ReminderInterval;
	
	OutputDate = Day(ReminderCalculatingTime) <> Day(CurrentDate);
	
	DateString = Format(ReminderCalculatingTime,"DLF=DD");
	TimeAsString = Format(ReminderCalculatingTime,"DF=H:mm");
	
	Return "(" + ?(OutputDate, DateString + " ", "") +  TimeAsString + ")";
	
EndFunction

&AtClient
Procedure UpdateEstimatedTimeReminders()
	Items.ReminderCalculatingTime.Title = EstimatedTimeLine();
EndProcedure

#EndRegion
