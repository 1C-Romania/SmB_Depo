
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	UseExternalUsers = GetFunctionalOption("UseExternalUsers");
	SwitchToWhomCopySettings = "SelectedUsers";
	SwitchCopiedSettings = "CopyAll";
	FormOpeningMode = Parameters.FormOpeningMode;
	
	UsersReceiversSettings = New Structure;
	If Parameters.User <> Undefined Then
		UserArray = New Array;
		UserArray.Add(Parameters.User);
		UsersReceiversSettings.Insert("UserArray", UserArray);
		Items.SelectUsers.Title = String(Parameters.User);
		UserCount = 1;
		TransferredUserType = TypeOf(Parameters.User);
		Items.GroupToWhomCopy.Enabled = False;
	Else
		UserRef = Users.CurrentUser();
	EndIf;
	
	If UserRef = Undefined Then
		Items.GroupCopiedSettings.Enabled = False;
	EndIf;
	
	ClearHistoryOfSelectSettings = True;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("CaseUser") Then
		UsersReceiversSettings = New Structure("UserArray", Parameter.UsersTarget);
		
		UserCount = Parameter.UsersTarget.Count();
		If UserCount = 1 Then
			Items.SelectUsers.Title = String(Parameter.UsersTarget[0]);
		ElsIf UserCount > 1 Then
			
			NumberInWords = NumberInWords(
				UserCount,
				"L=en_US",
				NStr("en = ',,,,,,,,0'"));
			SubjectAndNumberInWords = NumberInWords(
				UserCount,
				"L=en_US",
				NStr("en = 'user,of user,users,,,,,,0'"));
			NumberAndSubject = StrReplace(
				SubjectAndNumberInWords,
				NumberInWords,
				Format(UserCount, "NFD=0") + " ");
				
			Items.SelectUsers.Title = NumberAndSubject;
		EndIf;
		Items.SelectUsers.ToolTip = "";
		
	ElsIf Upper(EventName) = Upper("SettingsChoice") Then
		
		SelectedSettings = New Structure;
		SelectedSettings.Insert("ReportSettings", Parameter.ReportSettings);
		SelectedSettings.Insert("ExternalView", Parameter.ExternalView);
		SelectedSettings.Insert("OtherSettings", Parameter.OtherSettings);
		SelectedSettings.Insert("PersonalSettings", Parameter.PersonalSettings);
		SelectedSettings.Insert("ReportVariantsTable", Parameter.ReportVariantsTable);
		SelectedSettings.Insert("SelectedReportsVariants", Parameter.SelectedReportsVariants);
		SelectedSettings.Insert("OtherUserSettings",
			Parameter.OtherUserSettings);
		
		SettingsCount = Parameter.SettingsCount;
		
		If SettingsCount = 0 Then
			HeaderText = NStr("en='Select'");
		ElsIf SettingsCount = 1 Then
			SettingRepresentation = Parameter.SettingsPresentation[0];
			HeaderText = SettingRepresentation;
		Else
			NumberInWords = NumberInWords(
				SettingsCount,
				"L=en_US",
				NStr("en = ',,,,,,,,0'"));
			SubjectAndNumberInWords = NumberInWords(
				SettingsCount,
				"L=en_US",
				NStr("en = 'setting,settings,settings,,,,,,0'"));
			HeaderText = StrReplace(
				SubjectAndNumberInWords,
				NumberInWords,
				Format(SettingsCount, "NFD=0") + " ");
		EndIf;
		
		Items.ChooseSettings.Title = HeaderText;
		Items.ChooseSettings.ToolTip = "";
		
	ElsIf Upper(EventName) = Upper("CopySettingsActiveUsers") Then
		
		CopySettings(Parameter.Action);
		
	ElsIf Upper(EventName) = Upper("SettingsChoice_DataSaved") Then
		ClearHistoryOfSelectSettings = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure UserStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedUserType = Undefined;
	
	If UserCount <> 0 Then
		HiddenUsers = New ValueList;
		HiddenUsers.LoadValues(UsersReceiversSettings.UserArray);
	EndIf;
	
	FilterParameters = New Structure(
		"HideUsersWithoutIBUser, ChoiceMode, HiddenUsers",
		True, True, HiddenUsers);
	
	If TransferredUserType = Undefined Then
		
		If UseExternalUsers Then
			TypeChoiceUsers = New ValueList;
			TypeChoiceUsers.Add("ExternalUsers", NStr("en = 'External users'"));
			TypeChoiceUsers.Add("Users", NStr("en = 'Users'"));
			
			Notification = New NotifyDescription("UserStartChoiceEnd", ThisObject, FilterParameters);
			TypeChoiceUsers.ShowChooseItem(Notification);
			Return;
		Else
			SelectedUserType = "Users";
		EndIf;
		
	EndIf;
	
	OpenUsersChoiceForm(SelectedUserType, FilterParameters);
	
EndProcedure

&AtClient
Procedure UserStartChoiceEnd(SelectedVariant, FilterParameters) Export
	
	If SelectedVariant = Undefined Then
		Return;
	EndIf;
	SelectedUserType = SelectedVariant.Value;
	
	OpenUsersChoiceForm(SelectedUserType, FilterParameters);
	
EndProcedure

&AtClient
Procedure OpenUsersChoiceForm(SelectedUserType, FilterParameters)
	
	If SelectedUserType = "Users"
		Or TransferredUserType = Type("CatalogRef.Users") Then
		OpenForm("Catalog.Users.Form.ListForm", FilterParameters, Items.UserRef);
	ElsIf SelectedUserType = "ExternalUsers"
		Or TransferredUserType = Type("CatalogRef.ExternalUsers") Then
		OpenForm("Catalog.ExternalUsers.Form.ListForm", FilterParameters, Items.UserRef);
	EndIf;
	UserRefOld = UserRef;
	
EndProcedure

&AtClient
Procedure UserRefOnChange(Item)
	
	If UserRef <> Undefined
		AND UsersReceiversSettings.Property("UserArray") Then
		
		For Each UserTarget IN UsersReceiversSettings.UserArray Do
		
			If UserRef = UserTarget Then
				ShowMessageBox(,NStr("en = 'You can not copy the user
					|settings to yourself, select another user.'"));
				UserRef = UserRefOld;
				Return;
			EndIf;
		
		EndDo;
		
	EndIf;
	
	Items.GroupCopiedSettings.Enabled = UserRef <> Undefined;
	
	SelectedSettings = Undefined;
	SettingsCount = 0;
	Items.ChooseSettings.Title = NStr("en='Select'");
	
EndProcedure

&AtClient
Procedure ChooseSettings(Item)
	
	FormParameters = New Structure("User, ActionWithSettings, ClearHistoryOfSelectSettings",
		UserRef, "Copy", ClearHistoryOfSelectSettings);
	OpenForm("DataProcessor.UserSettings.Form.SettingsChoice", FormParameters);
	
EndProcedure

&AtClient
Procedure SelectUsers(Item)
	
	UserType = TypeOf(UserRef);
	
	SelectedUsers = Undefined;
	UsersReceiversSettings.Property("UserArray", SelectedUsers);
	
	FormParameters = New Structure("User, UserType, ActionType, SelectedUsers",
		UserRef, UserType, "Copy", SelectedUsers);
	OpenForm("DataProcessor.UserSettings.Form.UsersChoice", FormParameters);
	
EndProcedure

&AtClient
Procedure SwitchToWhomCopySettingsOnChange(Item)
	
	If SwitchToWhomCopySettings = "SelectedUsers" Then
		Items.SelectUsers.Enabled = True;
	Else
		Items.SelectUsers.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure SwitchCopiedSettingsOnChange(Item)
	
	If SwitchCopiedSettings = "CopySelected" Then
		Items.ChooseSettings.Enabled = True;
	Else
		Items.ChooseSettings.Enabled = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Copy(Command)
	
	ClearMessages();
	
	If UserRef = Undefined Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Select the user whose settings it is necessary to copy.'"), , "UserRef");
		Return;
	EndIf;
	
	If UserCount = 0 AND SwitchToWhomCopySettings <> "AllUsers" Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Select one or several users who need to copy the settings.'"), , "Receiver");
		Return;
	EndIf;
	
	If SwitchCopiedSettings = "CopySelected" AND SettingsCount = 0 Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Select the settings which are required to be copied.'"), , "SwitchCopiedSettings");
		Return;
	EndIf;
	
	// When setting copy of external type or all settings
	// by other users check they work with the application or not. If work - display message about it.
	CheckActiveUsers();
	If CheckResult = "IsActiveUsersReceivers" Then
		
		If SwitchCopiedSettings = "CopyAll" 
			Or (SwitchCopiedSettings = "CopySelected"
			AND SelectedSettings.ExternalView.Count() <> 0) Then
			
			FormParameters = New Structure("Action", Command.Name);
			OpenForm("DataProcessor.UserSettings.Form.WarningAboutSettingsCopying", FormParameters);
			Return;
			
		EndIf;
		
	EndIf;
	
	CopySettings(Command.Name);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure CopySettings(CommandName)
	
	Status(NStr("en = 'Settings are being copied'"));
	
	If SwitchToWhomCopySettings = "SelectedUsers" Then
		
		ExplanationToWhomSettingsAreCopied = UsersServiceClient.ExplanationUsers(
			UserCount, UsersReceiversSettings.UserArray[0]);
		
	Else
		ExplanationToWhomSettingsAreCopied = NStr("en = 'All users'");
	EndIf;
	
	If SwitchCopiedSettings = "CopySelected" Then
		
		Report = Undefined;
		CopySelectedSettings(Report);
		
		If Report <> Undefined Then
			QuestionText = NStr("en = 'Not all the report variants and settings have been copied.'");
			QuestionButtons = New ValueList;
			QuestionButtons.Add("Ok", NStr("en='OK'"));
			QuestionButtons.Add("ShowReport", NStr("en='Show report'"));
			
			Notification = New NotifyDescription("CopySettingsShowQuery", ThisObject, Report);
			ShowQueryBox(Notification, QuestionText, QuestionButtons,, QuestionButtons[0].Value);
			Return;
		EndIf;
			
		If Report = Undefined Then
			
			ExplanationText = UsersServiceClient.GeneratingExplanationOnCopying(
				SettingRepresentation, SettingsCount, ExplanationToWhomSettingsAreCopied);
			ShowUserNotification(NStr("en = 'Copying of settings'"), , ExplanationText, PictureLib.Information32);
			
		EndIf;
		
	Else
		
		SettingsCopied = CopyingAllSettings();
		If Not SettingsCopied Then
			
			WarningText = NStr("en = 'Settings weren''t copied as at the user ""%1"" any setting was not saved.'");
			WarningText = StringFunctionsClientServer.
				PlaceParametersIntoString(WarningText, String(UserRef));
			ShowMessageBox(,WarningText);
			
			Return;
		EndIf;
			
		ExplanationText = NStr("en = 'All the settings are copied %1'");
		ExplanationText = StringFunctionsClientServer.PlaceParametersIntoString(
			ExplanationText, ExplanationToWhomSettingsAreCopied);
		ShowUserNotification(
			NStr("en = 'Copying of settings'"), , ExplanationText, PictureLib.Information32);
	EndIf;
	
	// If setting copy from another user, inform about it form UserSettings.
	If FormOpeningMode = "CopyFrom" Then
		CommonUseClient.RefreshApplicationInterface();
		Notify("CopiedSettings", True);
	EndIf;
	
	If CommandName = "CopyAndClose" Then
		Close();
	EndIf;
	
	Return;
	
EndProcedure

&AtClient
Procedure CopySettingsShowQuery(Response, Report) Export
	
	If Response = "Ok" Then
		Return;
	Else
		Report.ShowGroups = True;
		Report.ShowGrid = False;
		Report.ShowHeaders = False;
		Report.Show();
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure CopySelectedSettings(Report)
	
	User = DataProcessors.UserSettings.IBUserName(UserRef);
	
	If SwitchToWhomCopySettings = "SelectedUsers" Then
		Receivers = UsersReceiversSettings.UserArray;
	ElsIf SwitchToWhomCopySettings = "AllUsers" Then
		Receivers = New Array;
		UsersTable = New ValueTable;
		UsersTable.Columns.Add("User");
		DataProcessors.UserSettings.UsersForCopying(UserRef, UsersTable,
			TypeOf(UserRef) = Type("CatalogRef.ExternalUsers"));
		
		For Each TableRow IN UsersTable Do
			Receivers.Add(TableRow.User);
		EndDo;
		
	EndIf;
	
	NotCopiedReportsSettings = New ValueTable;
	NotCopiedReportsSettings.Columns.Add("User");
	NotCopiedReportsSettings.Columns.Add("ReportList", New TypeDescription("ValueList"));
	
	If SelectedSettings.ReportSettings.Count() > 0 Then
		
		DataProcessors.UserSettings.CopyReportsSettingsAndPersonalSettings(ReportsUserSettingsStorage,
			User, Receivers, SelectedSettings.ReportSettings, NotCopiedReportsSettings);
		
		DataProcessors.UserSettings.CopyReportsVariants(
			SelectedSettings.SelectedReportsVariants, SelectedSettings.ReportVariantsTable, User, Receivers);
	EndIf;
		
	If SelectedSettings.ExternalView.Count() > 0 Then
		DataProcessors.UserSettings.CopyExternalViewSettings(User, Receivers, SelectedSettings.ExternalView);
	EndIf;
	
	If SelectedSettings.OtherSettings.Count() > 0 Then
		DataProcessors.UserSettings.CopyExternalViewSettings(User, Receivers, SelectedSettings.OtherSettings);
	EndIf;
	
	If SelectedSettings.PersonalSettings.Count() > 0 Then
		DataProcessors.UserSettings.CopyReportsSettingsAndPersonalSettings(CommonSettingsStorage,
			User, Receivers, SelectedSettings.PersonalSettings);
	EndIf;
		
	If SelectedSettings.OtherUserSettings.Count() > 0 Then
		
		For Each CatalogUser IN Receivers Do
			UserInfo = New Structure;
			UserInfo.Insert("UserRef", CatalogUser);
			UserInfo.Insert("InfobaseUserName", 
				DataProcessors.UserSettings.IBUserName(CatalogUser));
			UsersService.OnSaveOtherSetings(
				UserInfo, SelectedSettings.OtherUserSettings);
		EndDo;
		
	EndIf;
		
	If NotCopiedReportsSettings.Count() <> 0 Then
		Report = DataProcessors.UserSettings.CopyingReportGenerating(
			NotCopiedReportsSettings);
	EndIf;
	
EndProcedure

&AtServer
Function CopyingAllSettings()
	
	User = DataProcessors.UserSettings.IBUserName(UserRef);
	
	If SwitchToWhomCopySettings = "SelectedUsers" Then
		Receivers = UsersReceiversSettings.UserArray;
	Else
		Receivers = New Array;
		UsersTable = New ValueTable;
		UsersTable.Columns.Add("User");
		UsersTable = DataProcessors.UserSettings.UsersForCopying(UserRef, UsersTable, 
			TypeOf(UserRef) = Type("CatalogRef.ExternalUsers"));
		
		For Each TableRow IN UsersTable Do
			Receivers.Add(TableRow.User);
		EndDo;
		
	EndIf;
	
	CopiedSettings = New Array;
	CopiedSettings.Add("ReportSettings");
	CopiedSettings.Add("ExternalViewSettings");
	CopiedSettings.Add("PersonalSettings");
	CopiedSettings.Add("Favorites");
	CopiedSettings.Add("PrintSettings");
	CopiedSettings.Add("OtherUserSettings");
	
	SettingsCopied = DataProcessors.UserSettings.
		UserSettingsCopying(UserRef, Receivers, CopiedSettings);
		
	Return SettingsCopied;
	
EndFunction

&AtServer
Procedure CheckActiveUsers()
	
	CurrentUser = Users.CurrentUser();
	If UsersReceiversSettings.Property("UserArray") Then
		UserArray = UsersReceiversSettings.UserArray;
	EndIf;
	
	If SwitchToWhomCopySettings = "AllUsers" Then
		
		UserArray = New Array;
		UsersTable = New ValueTable;
		UsersTable.Columns.Add("User");
		UsersTable = DataProcessors.UserSettings.UsersForCopying(UserRef, UsersTable, 
			TypeOf(UserRef) = Type("CatalogRef.ExternalUsers"));
		
		For Each TableRow IN UsersTable Do
			UserArray.Add(TableRow.User);
		EndDo;
		
	EndIf;
	
	If UserArray.Count() = 1 
		AND UserArray[0] = CurrentUser Then
		
		CheckResult = "CurrentUserIsPayee";
		Return;
		
	EndIf;
		
	IsActiveUsersReceivers = False;
	Sessions = GetInfobaseSessions();
	For Each Recipient IN UserArray Do
		If Recipient = CurrentUser Then
			CheckResult = "AmongRecipientsOfCurrentUser";
			Return;
		EndIf;
		For Each Session IN Sessions Do
			If Recipient.InfobaseUserID = Session.User.UUID Then
				IsActiveUsersReceivers = True;
			EndIf;
		EndDo;
	EndDo;
	
	CheckResult = ?(IsActiveUsersReceivers, "IsActiveUsersReceivers", "");
	
EndProcedure

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
