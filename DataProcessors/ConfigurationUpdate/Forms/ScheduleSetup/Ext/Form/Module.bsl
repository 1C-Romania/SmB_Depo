
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ConfigurationUpdateOptions = ConfigurationUpdate.GetSettingsStructureOfAssistant();
	FillPropertyValues(Object, ConfigurationUpdateOptions);
	Object.ScheduleOfUpdateExistsCheck = CommonUseClientServer.StructureIntoSchedule(Object.ScheduleOfUpdateExistsCheck);
	
	SetScheduleVisible(ThisObject);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure CheckUpdateExistsOnStartOnChange(Item)
	
	SetScheduleVisible(ThisObject);
	
EndProcedure

&AtClient
Procedure LabelOpenScheduleClick(Item)
	
	If Object.ScheduleOfUpdateExistsCheck = Undefined Then
		Object.ScheduleOfUpdateExistsCheck = New JobSchedule;
	EndIf;
	Dialog = New ScheduledJobDialog(Object.ScheduleOfUpdateExistsCheck);
	NotifyDescription = New NotifyDescription("LabelOpenScheduleClickEnd", ThisObject);
	Dialog.Show(NOTifyDescription);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CommandOK(Command)
	
	ClearMessages();
	SettingsChanged = (Parameters.CheckUpdateExistsOnStart <> Object.CheckUpdateExistsOnStart
		AND (Parameters.CheckUpdateExistsOnStart = 1 OR Object.CheckUpdateExistsOnStart = 1))
		OR String(Parameters.ScheduleOfUpdateExistsCheck) <> String(Object.ScheduleOfUpdateExistsCheck);
		
	If SettingsChanged Then
		RepeatPeriodInDay = Object.ScheduleOfUpdateExistsCheck.RepeatPeriodInDay;
		If RepeatPeriodInDay > 0 AND RepeatPeriodInDay < 60 * 5 Then
			CommonUseClientServer.MessageToUser(NStr("en = 'Checking interval can not be less then 5 minutes.'"));
			Return;
		EndIf;
		
		ConfigurationUpdateOptions = ApplicationParameters["StandardSubsystems.ConfigurationUpdateOptions"];
		ConfigurationUpdateOptions.CheckUpdateExistsOnStart = Object.CheckUpdateExistsOnStart;
		ConfigurationUpdateOptions.UpdateServerUserCode = Object.UpdateServerUserCode;
		ConfigurationUpdateOptions.UpdatesServerPassword = ?(Object.SaveUpdatesServerPassword, Object.UpdatesServerPassword, "");
		ConfigurationUpdateOptions.SaveUpdatesServerPassword = Object.SaveUpdatesServerPassword;
		ConfigurationUpdateOptions.ScheduleOfUpdateExistsCheck = CommonUseClientServer.ScheduleIntoStructure(Object.ScheduleOfUpdateExistsCheck);
		
		WriteSettings(ConfigurationUpdateOptions);
		ConfigurationUpdateClient.EnableDisableCheckOnSchedule(Object.CheckUpdateExistsOnStart = 1 AND
			Object.ScheduleOfUpdateExistsCheck <> Undefined);
		
	EndIf;
	
	Close();
	
EndProcedure

&AtClient
Procedure GetUserCodeAndPassword(Command)
	
	GotoURL(
		ConfigurationUpdateClient.GetUpdateParameters().InfoAboutObtainingAccessToUserSitePageAddress);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClientAtServerNoContext
Procedure SetScheduleVisible(Form)
	
	LabelOpenSchedule = Form.Items.LabelOpenSchedule;
	LabelOpenSchedule.Title = LabelTextOpenSchedule(Form);
	
	If Form.Object.CheckUpdateExistsOnStart = 1 Then
		LabelOpenSchedule.Enabled = True;
	Else
		LabelOpenSchedule.Enabled = False;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function LabelTextOpenSchedule(Form)
	
	StringPresentationSchedule = String(Form.Object.ScheduleOfUpdateExistsCheck);
	Return ?(NOT IsBlankString(StringPresentationSchedule),
		StringPresentationSchedule, NStr("en = 'Not defined'"));
		
EndFunction

&AtClientAtServerNoContext
Function WriteSettings(ConfigurationUpdateOptions)
	
	ConfigurationUpdateServerCall.WriteStructureOfAssistantSettings(ConfigurationUpdateOptions);
	RefreshReusableValues(); // Reset the cache to apply settings.
	
EndFunction

&AtClient
Procedure LabelOpenScheduleClickEnd(Schedule, AdditionalParameters) Export
	
	If Schedule <> Undefined Then
		Object.ScheduleOfUpdateExistsCheck = Schedule;
	EndIf;
	
	Items.LabelOpenSchedule.Title = LabelTextOpenSchedule(ThisObject);
	
EndProcedure

&AtClient
Procedure OnClose()
	
	Notify("ConfigurationUpdateSettingFormIsClosed");
	
EndProcedure

#EndRegion
