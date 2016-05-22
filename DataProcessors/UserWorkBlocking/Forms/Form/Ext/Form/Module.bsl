&AtClient
Var AdministrationParameters, LockCurrentValue;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ThisIsFileBase = CommonUse.FileInfobase();
	ThisIsSystemAdministrator = Users.InfobaseUserWithFullAccess(, True);
	SessionWithoutSeparator = CommonUseReUse.SessionWithoutSeparator();
	
	If ThisIsFileBase Or Not ThisIsSystemAdministrator Then
		Items.DisableScheduledJobsGroup.Visible = False;
	EndIf;
	
	If CommonUseReUse.DataSeparationEnabled() Or Not Users.RolesAvailable("FullRights") Then
		Items.UnlockCode.Visible = False;
	EndIf;
	
	GetBlockParameters();
	InstallStarterStatusBanUsers();
	RefreshSettingsPage();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ClientConnectedViaWebServer = CommonUseClient.ClientConnectedViaWebServer();
	If InfobaseConnectionsClient.SessionTerminationInProgress() Then
		Items.ModeGroup.CurrentPage = Items.LockStatePage;
		RefreshStatePage(ThisObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	InformationAboutLockingSessions = InfobaseConnections.InformationAboutLockingSessions(NStr("en = 'Blocking is not set.'"));
	
	If InformationAboutLockingSessions.LockSessionsPresent Then
		Raise InformationAboutLockingSessions.MessageText;
	EndIf;
	
	NumberOfSessions = InformationAboutLockingSessions.NumberOfSessions;
	
	// Checking of the blocking setting possibility.
	If Object.LockBegin > Object.LockEnding 
		AND ValueIsFilled(Object.LockEnding) Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'End date of locking can not be less than start date of lock. Blocking is not set.'"),,
			"Object.LockEnding",,Cancel);
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.LockBegin) Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Start date of locking is not specified.'"),,	"Object.LockBegin",,Cancel);
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "UserSessions" Then
		NumberOfSessions = Parameter.NumberOfSessions;
		UpdateLockState(ThisObject);
		If Parameter.Status = "Done" Then
			Close();
		ElsIf Parameter.Status = "Error" Then
			ShowMessageBox(,NStr("en = 'Cannot terminate sessions of all active users.
				|Look for details in event log.'"), 30);
			Close();
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ActiveUsers(Command)
	
	OpenForm("DataProcessor.ActiveUsers.Form",, ThisObject);
	
EndProcedure

&AtClient
Procedure Apply(Command)
	
	ClearMessages();
	
	Object.ProhibitUserWorkTemporarily = Not InitialUsersWorkProhibitionStatusValue;
	If Object.ProhibitUserWorkTemporarily Then
		
		NumberOfSessions = 1;
		Try
			If Not CheckBlockPreconditions() Then
				Return;
			EndIf;
		Except
			CommonUseClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()));
			Return;
		EndTry;
		
		QuestionTitle = NStr("en = 'User work locking'");
		If NumberOfSessions > 1 AND Object.LockBegin < CommonUseClient.SessionDate() + 5 * 60 Then
			QuestionText = NStr("en = 'Too early start time of blocking is set, users may not have enough time to save all their data and terminate their sessions.
				|It is recommended to set start time 5 minutes later than the current time.'");
			Buttons = New ValueList;
			Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Block in 5 minutes'"));
			Buttons.Add(DialogReturnCode.No, NStr("en = 'Lock now'"));
			Buttons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel'"));
			Notification = New NotifyDescription("ApplyEnd", ThisObject, "TooCloseLockTime");
			ShowQueryBox(Notification, QuestionText, Buttons,,, QuestionTitle);
		ElsIf Object.LockBegin > CommonUseClient.SessionDate() + 60 * 60 Then
			QuestionText = NStr("en = 'Stat time of blocking is too late (more than in a hour).
				|Do you want to schedule the locking for the specified time?'");
			Buttons = New ValueList;
			Buttons.Add(DialogReturnCode.No, NStr("en = 'Schedule'"));
			Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Lock now'"));
			Buttons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel'"));
			Notification = New NotifyDescription("ApplyEnd", ThisObject, "TooMuchLockTime");
			ShowQueryBox(Notification, QuestionText, Buttons,,, QuestionTitle);
		Else
			If Object.LockBegin - CommonUseClient.SessionDate() > 15*60 Then
				QuestionText = NStr("en = 'Sessions of all active users will be terminated during the period from %1 to %2.
					|Continue?'");
			Else
				QuestionText = NStr("en = 'Sessions of all active users will be terminated by %2.
					|Continue?'");
			EndIf;
			Notification = New NotifyDescription("ApplyEnd", ThisObject, "Confirmation");
			QuestionText = StringFunctionsClientServer.PlaceParametersIntoString(
			QuestionText, Object.LockBegin - 900, Object.LockBegin);
			ShowQueryBox(Notification, QuestionText, QuestionDialogMode.OKCancel,,, QuestionTitle);
		EndIf;
		
	Else
		
		Notification = New NotifyDescription("ApplyEnd", ThisObject, "Confirmation");
		ExecuteNotifyProcessing(Notification, DialogReturnCode.OK);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ApplyEnd(Response, Variant) Export
	
	If Variant = "TooCloseLockTime" Then
		If Response = DialogReturnCode.Yes Then
			Object.LockBegin = CommonUseClient.SessionDate() + 5 * 60;
		ElsIf Response <> DialogReturnCode.No Then
			Return;
		EndIf;
	ElsIf Variant = "TooMuchLockTime" Then
		If Response = DialogReturnCode.Yes Then
			Object.LockBegin = CommonUseClient.SessionDate() + 5 * 60;
		ElsIf Response <> DialogReturnCode.No Then
			Return;
		EndIf;
	ElsIf Variant = "Confirmation" Then
		If Response <> DialogReturnCode.OK Then
			Return;
		EndIf;
	EndIf;
	
	If EnteredCorrectAdministrationParameters AND ThisIsSystemAdministrator AND Not ThisIsFileBase
		AND LockCurrentValue <> Object.DisableScheduledJobs Then
		
		Try
			
			If ClientConnectedViaWebServer Then
				SetSheduledJobLockAtServer(AdministrationParameters);
			Else
				ClusterAdministrationClientServer.LockInfobaseSheduledJobs(
					AdministrationParameters,, Object.DisableScheduledJobs);
			EndIf;
			
		Except
			EventLogMonitorClient.AddMessageForEventLogMonitor(InfobaseConnectionsClientServer.EventLogMonitorEvent(), "Error",
				DetailErrorDescription(ErrorInfo()),, True);
			Items.ErrorGroup.Visible = True;
			Items.ErrorText.Title = ErrorShortInfo(ErrorDescription());
			Return;
		EndTry;
		
	EndIf;
	
	If Not ThisIsFileBase AND Not EnteredCorrectAdministrationParameters AND SessionWithoutSeparator Then
		
		NotifyDescription = New NotifyDescription("AfterAdministrationParametersGettingOnBlocking", ThisObject);
		FormTitle = NStr("en = 'Management of session blocking'");
		ExplanatoryInscription = NStr("en = 'For session lock management it
			|is necessary to enter administration parameters of server cluster and infobases'");
		InfobaseConnectionsClient.ShowAdministrationParameters(NOTifyDescription, True,
			True, AdministrationParameters, FormTitle, ExplanatoryInscription);
		
	Else
		
		AfterAdministrationParametersGettingOnBlocking(True, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Stop(Command)
	
	If Not ThisIsFileBase AND Not EnteredCorrectAdministrationParameters AND SessionWithoutSeparator Then
		
		NotifyDescription = New NotifyDescription("AfterAdministrationParametersGettingWhenLockCanceling", ThisObject);
		FormTitle = NStr("en = 'Management of session blocking'");
		ExplanatoryInscription = NStr("en = 'For session lock management it
			|is necessary to enter administration parameters of server cluster and infobases'");
		InfobaseConnectionsClient.ShowAdministrationParameters(NOTifyDescription, True,
			True, AdministrationParameters, FormTitle, ExplanatoryInscription);
		
	Else
		
		AfterAdministrationParametersGettingWhenLockCanceling(True, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AdministrationParameters(Command)
	
	NotifyDescription = New NotifyDescription("AfterAdministrationParametersReceiving", ThisObject);
	FormTitle = NStr("en = 'Management of the scheduled job blocking'");
	ExplanatoryInscription = NStr("en = 'For management of scheduled jobs
		|locking it is necessary to enter administration parameters of server cluster and infobases'");
	InfobaseConnectionsClient.ShowAdministrationParameters(NOTifyDescription, True,
		True, AdministrationParameters, FormTitle, ExplanatoryInscription);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.InitialUserWorkProhibitionState.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("UsersWorkProhibitionStatus");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = NStr("en = 'Prohibited'");

	Item.Appearance.SetParameterValue("TextColor", StyleColors.ExplanationTextError);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.InitialUserWorkProhibitionState.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("UsersWorkProhibitionStatus");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = NStr("en = 'Planned'");

	Item.Appearance.SetParameterValue("TextColor", StyleColors.ExplanationTextError);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.InitialUserWorkProhibitionState.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("UsersWorkProhibitionStatus");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = NStr("en = 'Timed Out'");

	Item.Appearance.SetParameterValue("TextColor", StyleColors.BlockedAttributeColor);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.InitialUserWorkProhibitionState.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("UsersWorkProhibitionStatus");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = NStr("en = 'Allowed'");

	Item.Appearance.SetParameterValue("TextColor", StyleColors.FormTextColor);

EndProcedure

&AtServer
Function CheckBlockPreconditions()
	
	Return CheckFilling();

EndFunction

&AtServer
Function SetRemoveLock()
	
	Try
		FormAttributeToValue("Object").RunSetup();
		Items.ErrorGroup.Visible = False;
	Except
		WriteLogEvent(InfobaseConnectionsClientServer.EventLogMonitorEvent(),
			EventLogLevel.Error,,, 
			DetailErrorDescription(ErrorInfo()));
		If ThisIsSystemAdministrator Then
			Items.ErrorGroup.Visible = True;
			Items.ErrorText.Title = ErrorShortInfo(ErrorDescription());
		EndIf;
		Return False;
	EndTry;
	
	InstallStarterStatusBanUsers();
	NumberOfSessions = InfobaseConnections.InfobaseSessionCount();
	Return True;
	
EndFunction

&AtServer
Function Unlock()
	
	Try
		FormAttributeToValue("Object").Unlock();
	Except
		WriteLogEvent(InfobaseConnectionsClientServer.EventLogMonitorEvent(),
			EventLogLevel.Error,,, 
			DetailErrorDescription(ErrorInfo()));
		If ThisIsSystemAdministrator Then
			Items.ErrorGroup.Visible = True;
			Items.ErrorText.Title = ErrorShortInfo(ErrorDescription());
		EndIf;
		Return False;
	EndTry;
	InstallStarterStatusBanUsers();
	Items.ModeGroup.CurrentPage = Items.SettingsPage;
	RefreshSettingsPage();
	Return True;
	
EndFunction

&AtServer
Procedure RefreshSettingsPage()
	
	Items.DisableScheduledJobsGroup.Enabled = True;
	Items.ApplyCommand.Visible = True;
	Items.ApplyCommand.DefaultButton = True;
	Items.StopCommand.Visible = False;
	Items.ApplyCommand.Title = ?(Object.ProhibitUserWorkTemporarily,
		NStr("en='Remove lock'"), NStr("en='Set lock'"));
	Items.DisableScheduledJobs.Title = ?(Object.DisableScheduledJobs,
		NStr("en='Leave the scheduled jobs locking'"), NStr("en='Also to prohibit the scheduled jobs work'"));
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshStatePage(Form)
	
	Form.Items.DisableScheduledJobsGroup.Enabled = False;
	Form.Items.StopCommand.Visible = True;
	Form.Items.ApplyCommand.Visible = False;
	Form.Items.CloseCommand.DefaultButton = True;
	UpdateLockState(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateLockState(Form)
	
	Form.Items.State.Title = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='Please wait...
			|User operation is terminated. Active sessions left: %1'"),
			Form.NumberOfSessions);
	
EndProcedure

&AtServer
Procedure GetBlockParameters()
	DataProcessor = FormAttributeToValue("Object");
	Try
		DataProcessor.GetBlockParameters();
		Items.ErrorGroup.Visible = False;
	Except
		WriteLogEvent(InfobaseConnectionsClientServer.EventLogMonitorEvent(),
			EventLogLevel.Error,,, 
			DetailErrorDescription(ErrorInfo()));
		If ThisIsSystemAdministrator Then
			Items.ErrorGroup.Visible = True;
			Items.ErrorText.Title = ErrorShortInfo(ErrorDescription());
		EndIf;
	EndTry;
	
	ValueToFormAttribute(DataProcessor, "Object");
	
EndProcedure

&AtServer
Function ErrorShortInfo(ErrorDescription)
	ErrorText = ErrorDescription;
	Position = Find(ErrorText, "}:");
	If Position > 0 Then
		ErrorText = TrimAll(Mid(ErrorText, Position + 2, StrLen(ErrorText)));
	EndIf;
	Return ErrorText;
EndFunction	

&AtServer
Procedure InstallStarterStatusBanUsers()
	
	InitialUsersWorkProhibitionStatusValue = Object.ProhibitUserWorkTemporarily;
	If Object.ProhibitUserWorkTemporarily Then
		If CurrentSessionDate() < Object.LockBegin Then
			InitialUserWorkProhibitionState = NStr("en = 'The users work in the application will be prohibited at the specified time'");
			UsersWorkProhibitionStatus = "Planned";
		ElsIf CurrentSessionDate() > Object.LockEnding AND Object.LockEnding <> '00010101' Then
			InitialUserWorkProhibitionState = NStr("en = 'Work of the users in the application is permitted (prohibition period expired)'");;
			UsersWorkProhibitionStatus = "Timed Out";
		Else
			InitialUserWorkProhibitionState = NStr("en = 'Users are not allowed to work in the application'");
			UsersWorkProhibitionStatus = "Prohibited";
		EndIf;
	Else
		InitialUserWorkProhibitionState = NStr("en = 'Users are allowed to work in the application'");
		UsersWorkProhibitionStatus = "Allowed";
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterAdministrationParametersReceiving(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		AdministrationParameters = Result;
		EnteredCorrectAdministrationParameters = True;
		
		Try
			If ClientConnectedViaWebServer Then
				Object.DisableScheduledJobs = InfobaseScheduledJobsLockingAtServer(AdministrationParameters);
			Else
				Object.DisableScheduledJobs = ClusterAdministrationClientServer.InfobaseScheduledJobsLocking(AdministrationParameters);
			EndIf;
			LockCurrentValue = Object.DisableScheduledJobs;
		Except;
			EnteredCorrectAdministrationParameters = False;
			Raise;
		EndTry;
		
		Items.DisableScheduledJobsGroup.CurrentPage = Items.GroupScheduledJobsManagement;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterAdministrationParametersGettingOnBlocking(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	ElsIf TypeOf(Result) = Type("Structure") Then
		AdministrationParameters = Result;
		EnteredCorrectAdministrationParameters = True;
		EnableScheduledJobLockManagement();
		InfobaseConnectionsClient.SaveAdministrationParameters(AdministrationParameters);
	ElsIf TypeOf(Result) = Type("Boolean") AND EnteredCorrectAdministrationParameters Then
		InfobaseConnectionsClient.SaveAdministrationParameters(AdministrationParameters);
	EndIf;
	
	If Not SetRemoveLock() Then
		Return;
	EndIf;
	
	ShowUserNotification(NStr("en = 'User work locking'"),
		"e1cib/app/DataProcessor.UserWorkBlocking",
		?(Object.ProhibitUserWorkTemporarily, NStr("en = 'The lock is established.'"), NStr("en = 'Unlocked.'")),
		PictureLib.Information32);
	InfobaseConnectionsClient.SetIdleHandlerOfUserSessionsTermination(	Object.ProhibitUserWorkTemporarily);
	
	If Object.ProhibitUserWorkTemporarily Then
		RefreshStatePage(ThisObject);
	Else
		RefreshSettingsPage();
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterAdministrationParametersGettingWhenLockCanceling(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	ElsIf TypeOf(Result) = Type("Structure") Then
		AdministrationParameters = Result;
		EnteredCorrectAdministrationParameters = True;
		EnableScheduledJobLockManagement();
		InfobaseConnectionsClient.SaveAdministrationParameters(AdministrationParameters);
	ElsIf TypeOf(Result) = Type("Boolean") AND EnteredCorrectAdministrationParameters Then
		InfobaseConnectionsClient.SaveAdministrationParameters(AdministrationParameters);
	EndIf;
	
	If Not Unlock() Then
		Return;
	EndIf;
	
	InfobaseConnectionsClient.SetIdleHandlerOfUserSessionsTermination(False);
	ShowMessageBox(,NStr("en = 'Termination of active user sessions has been canceled. 
		|New users can not log on to the application.'"));
	
EndProcedure

&AtClient
Procedure EnableScheduledJobLockManagement()
	
	If ClientConnectedViaWebServer Then
		Object.DisableScheduledJobs = InfobaseScheduledJobsLockingAtServer(AdministrationParameters);
	Else
		Object.DisableScheduledJobs = ClusterAdministrationClientServer.InfobaseScheduledJobsLocking(AdministrationParameters);
	EndIf;
	LockCurrentValue = Object.DisableScheduledJobs;
	Items.DisableScheduledJobsGroup.CurrentPage = Items.GroupScheduledJobsManagement;
	
EndProcedure

&AtServer
Procedure SetSheduledJobLockAtServer(AdministrationParameters)
	
	ClusterAdministrationClientServer.LockInfobaseSheduledJobs(
		AdministrationParameters,, Object.DisableScheduledJobs);
	
EndProcedure
	
&AtServer
Function InfobaseScheduledJobsLockingAtServer(AdministrationParameters)
	
	Return ClusterAdministrationClientServer.InfobaseScheduledJobsLocking(AdministrationParameters);
	
EndFunction

#EndRegion