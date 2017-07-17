
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	UseExternalUsers = GetFunctionalOption("UseExternalUsers");
	UsersWhomSettingsClearing = New Structure;
	
	SwitchWhomSettingsCleared = "SelectedUsers";
	SwitchClearedSettings   = "ClearAll";
	ClearHistoryOfSelectSettings     = True;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("CaseUser") Then
		
		If UsersWhomSettingsClearing <> Undefined Then
			Items.ChooseSettings.Title = NStr("en='Select';ru='Выбрать'");
			SelectedSettings = Undefined;
			SettingsCount = Undefined;
		EndIf;
			
		UsersWhomSettingsClearing = New Structure("UserArray", Parameter.UsersTarget);
		
		UserCount = Parameter.UsersTarget.Count();
		If UserCount = 1 Then
			Items.SelectUsers.Title = String(Parameter.UsersTarget[0]);
			Items.GroupClearedSettings.Enabled = True;
		ElsIf UserCount > 1 Then
			
			NumberInWords = NumberInWords(
				UserCount,
				"L=en_US",
				NStr("en=',,,,,,,,0';ru=',,,,,,,,0'"));
			SubjectAndNumberInWords = NumberInWords(
				UserCount,
				"L=en_US",
				NStr("en='user,of user,users,,,,,,0';ru='user,of user,users,,,,,,0'"));
			NumberAndSubject = StrReplace(
				SubjectAndNumberInWords,
				NumberInWords,
				Format(UserCount, "NFD=0") + " ");
				
			Items.SelectUsers.Title = NumberAndSubject;
			SwitchClearedSettings = "ClearAll";
		EndIf;
		Items.SelectUsers.ToolTip = "";
		
	ElsIf Upper(EventName) = Upper("SettingsChoice") Then
		SelectedSettings = New Structure;
		SelectedSettings.Insert("ReportSettings", Parameter.ReportsSettings);
		SelectedSettings.Insert("ExternalView", Parameter.ExternalView);
		SelectedSettings.Insert("OtherSettings", Parameter.OtherSettings);
		SelectedSettings.Insert("PersonalSettings", Parameter.PersonalSettings);
		SelectedSettings.Insert("ReportVariantsTable", Parameter.ReportVariantsTable);
		SelectedSettings.Insert("SelectedReportsVariants", Parameter.SelectedReportsVariants);
		SelectedSettings.Insert("OtherUserSettings",
			Parameter.OtherUserSettings);
			
		SettingsCount = Parameter.SettingsCount;
		
		If SettingsCount = 0 Then
			HeaderText = NStr("en='Select';ru='Выбрать'");
		ElsIf SettingsCount = 1 Then
			SettingRepresentation = Parameter.SettingsPresentation[0];
			HeaderText = SettingRepresentation;
		Else
			NumberInWords = NumberInWords(
				SettingsCount,
				"L=en_US",
				NStr("en=',,,,,,,,0';ru=',,,,,,,,0'"));
			SubjectAndNumberInWords = NumberInWords(
				SettingsCount,
				"L=en_US",
				NStr("en='setting,settings,settings,,,,,,0';ru='setting,settings,settings,,,,,,0'"));
			HeaderText = StrReplace(
				SubjectAndNumberInWords,
				NumberInWords,
				Format(SettingsCount, "NFD=0") + " ");
		EndIf;
		
		Items.ChooseSettings.Title = HeaderText;
		Items.ChooseSettings.ToolTip = "";
		
	ElsIf Upper(EventName) = Upper("SettingsChoice_DataSaved") Then
		ClearHistoryOfSelectSettings = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure SwitchToWhomClearSettingsOnChange(Item)
	
	If SwitchClearedSettings = "SelectedUsers"
		AND UserCount > 1
		Or SwitchWhomSettingsCleared = "AllUsers" Then
		SwitchClearedSettings = "ClearAll";
	EndIf;
	
	If SwitchWhomSettingsCleared = "SelectedUsers"
		AND UserCount = 1
		Or SwitchWhomSettingsCleared = "AllUsers" Then
		Items.GroupClearedSettings.Enabled = True;
	Else
		Items.GroupClearedSettings.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure SwitchClearedSettingsOnChange(Item)
	
	If SwitchWhomSettingsCleared = "SelectedUsers"
		AND UserCount > 1 
		Or SwitchWhomSettingsCleared = "AllUsers" Then
		SwitchClearedSettings = "ClearAll";
		Items.ChooseSettings.Enabled = False;
		ShowMessageBox(,NStr("en='Cleanup of separate settings is available only when one user is selected.';ru='Очистка отдельных настроек доступна только при выборе одного пользователя.'"));
	ElsIf SwitchClearedSettings = "ClearAll" Then
		Items.ChooseSettings.Enabled = False;
	Else
		Items.ChooseSettings.Enabled = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChooseUsersClick(Item)
	
	If UseExternalUsers Then
		TypeChoiceUsers = New ValueList;
		TypeChoiceUsers.Add("ExternalUsers", NStr("en='External users';ru='Внешние пользователи'"));
		TypeChoiceUsers.Add("Users", NStr("en='Users';ru='Пользователи'"));
		
		Notification = New NotifyDescription("SelectUsersClickSelectItem", ThisObject);
		TypeChoiceUsers.ShowChooseItem(Notification);
		Return;
	Else
		UserType = Type("CatalogRef.Users");
	EndIf;
	
	OpenUsersChoiceForm(UserType);
	
EndProcedure

&AtClient
Procedure ChooseSettings(Item)
	
	If UserCount = 1 Then
		UserRef = UsersWhomSettingsClearing.UserArray[0];
		FormParameters = New Structure("User, ActionWithSettings, ClearHistoryOfSelectSettings",
			UserRef, "Clearing", ClearHistoryOfSelectSettings);
		OpenForm("DataProcessor.UserSettings.Form.SettingsChoice", FormParameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Clear(Command)
	
	ClearMessages();
	ClearingSettings();
	
EndProcedure

&AtClient
Procedure ClearAndClose(Command)
	
	ClearMessages();
	SettingsCleared = ClearingSettings();
	If SettingsCleared Then
		CommonUseClient.RefreshApplicationInterface();
		Close();
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure SelectUsersClickSelectItem(SelectedVariant, AdditionalParameters) Export
	
	If SelectedVariant = Undefined Then
		Return;
	EndIf;
	
	If SelectedVariant.Value = "Users" Then
		UserType = Type("CatalogRef.Users");
	ElsIf SelectedVariant.Value = "ExternalUsers" Then
		UserType = Type("CatalogRef.ExternalUsers");
	EndIf;
	
	OpenUsersChoiceForm(UserType);
	
EndProcedure

&AtClient
Procedure OpenUsersChoiceForm(UserType)
	
	SelectedUsers = Undefined;
	UsersWhomSettingsClearing.Property("UserArray", SelectedUsers);
	
	FormParameters = New Structure("User, UserType, ActionType, SelectedUsers",
		"", UserType, "Clearing", SelectedUsers);
	OpenForm("DataProcessor.UserSettings.Form.UsersChoice", FormParameters);
	
EndProcedure

&AtClient
Function ClearingSettings()
	
	If SwitchWhomSettingsCleared = "SelectedUsers"
		AND UserCount = 0 Then
		CommonUseClientServer.MessageToUser(
			NStr("en='Select the user
		|or users whom it is necessary to clear the settings for.';ru='Выберите
		|пользователя или пользователей, которым необходимо очистить настройки.'"), , "Source");
		Return False;
	EndIf;
	
	If SwitchWhomSettingsCleared = "SelectedUsers" Then
			
		If UserCount = 1 Then
			ExplanationWhoHasClearedSettings = NStr("en='user ""%1""';ru='пользователя ""%1""'");
			ExplanationWhoHasClearedSettings = StringFunctionsClientServer.SubstituteParametersInString(
				ExplanationWhoHasClearedSettings, UsersWhomSettingsClearing.UserArray[0]);
		Else
			ExplanationWhoHasClearedSettings = NStr("en='%1 users';ru='%1 пользователям'");
			ExplanationWhoHasClearedSettings = StringFunctionsClientServer.SubstituteParametersInString(
				ExplanationWhoHasClearedSettings, UserCount);
		EndIf;
		
	Else
		ExplanationWhoHasClearedSettings = NStr("en='All users';ru='Все пользователи'");
	EndIf;
	
	If SwitchClearedSettings = "SomeSettings"
		AND SettingsCount = 0 Then
		CommonUseClientServer.MessageToUser(
			NStr("en='Select settings to be cleared.';ru='Выберите настройки, которые необходимо очистить.'"), , "SwitchClearedSettings");
		Return False;
	EndIf;
	
	If SwitchClearedSettings = "SomeSettings" Then
		ClearSelectedSettings();
		
		If SettingsCount = 1 Then
			
			If StrLen(SettingRepresentation) > 24 Then
				SettingRepresentation = Left(SettingRepresentation, 24) + "...";
			EndIf;
			
			ExplanationText = NStr("en='""%1"" is cleared for %2';ru='""%1"" очищена у %2'");
			ExplanationText = StringFunctionsClientServer.SubstituteParametersInString(
				ExplanationText, SettingRepresentation, ExplanationWhoHasClearedSettings);
			
		Else
			
			NumberInWords = NumberInWords(
				SettingsCount,
				"L=en_US",
				NStr("en=',,,,,,,,0';ru=',,,,,,,,0'"));
			SubjectAndNumberInWords = NumberInWords(
				SettingsCount,
				"L=en_US",
				NStr("en='setting,settings,settings,,,,,,0';ru='setting,settings,settings,,,,,,0'"));
			SubjectInWords = StrReplace(
				SubjectAndNumberInWords,
				NumberInWords,
				Format(SettingsCount, "NFD=0") + " ");
			
			ExplanationText = NStr("en='%1 is cleaned up for %2';ru='Очищено %1 у %2'");
			ExplanationText = StringFunctionsClientServer.SubstituteParametersInString(
				ExplanationText, SubjectInWords, ExplanationWhoHasClearedSettings);
		EndIf;
		
		ShowUserNotification(
			NStr("en='Clear settings';ru='Очистить настройки'"), , ExplanationText, PictureLib.Information32);
	ElsIf SwitchClearedSettings = "ClearAll" Then
		ClearAllSettings();
		
		ExplanationText = NStr("en='All settings %1 are cleaned up';ru='Очищены все настройки %1'");
		ExplanationText = StringFunctionsClientServer.SubstituteParametersInString(
			ExplanationText, ExplanationWhoHasClearedSettings);
		ShowUserNotification(
			NStr("en='Clear settings';ru='Очистить настройки'"), , ExplanationText, PictureLib.Information32);
	EndIf;
	
	SettingsCount = 0;
	Items.ChooseSettings.Title = NStr("en='Select';ru='Выбрать'");
	Return True;
	
EndFunction

&AtServer
Procedure ClearSelectedSettings()
	
	Source = UsersWhomSettingsClearing.UserArray[0];
	User = DataProcessors.UserSettings.IBUserName(Source);
	
	If SelectedSettings.ReportSettings.Count() > 0 Then
		DataProcessors.UserSettings.DeleteSelectedSettings(
			User, SelectedSettings.ReportSettings, "ReportsUserSettingsStorage");
		
		DataProcessors.UserSettings.DeleteReportsVariants(
			SelectedSettings.SelectedReportsVariants, SelectedSettings.ReportVariantsTable, User);
	EndIf;
	
	If SelectedSettings.ExternalView.Count() > 0 Then
		DataProcessors.UserSettings.DeleteSelectedSettings(
			User, SelectedSettings.ExternalView, "SystemSettingsStorage");
	EndIf;
	
	If SelectedSettings.OtherSettings.Count() > 0 Then
		DataProcessors.UserSettings.DeleteSelectedSettings(
			User, SelectedSettings.OtherSettings, "SystemSettingsStorage");
	EndIf;
	
	If SelectedSettings.PersonalSettings.Count() > 0 Then
		DataProcessors.UserSettings.DeleteSelectedSettings(
			User, SelectedSettings.PersonalSettings, "CommonSettingsStorage");
	EndIf;
	
	If SelectedSettings.OtherUserSettings.Count() > 0 Then
		UserInfo = New Structure;
		UserInfo.Insert("UserRef", Source);
		UserInfo.Insert("InfobaseUserName", User);
		UsersService.OnDeleteOtherSettings(
			UserInfo, SelectedSettings.OtherUserSettings);
	EndIf;
	
EndProcedure

&AtServer
Procedure ClearAllSettings()
	
	SettingsArray = New Array;
	SettingsArray.Add("ReportSettings");
	SettingsArray.Add("ExternalViewSettings");
	SettingsArray.Add("PersonalSettings");
	SettingsArray.Add("FormsData");
	SettingsArray.Add("Favorites");
	SettingsArray.Add("PrintSettings");
	SettingsArray.Add("OtherUserSettings");
	
	If SwitchWhomSettingsCleared = "SelectedUsers" Then
		Sources = UsersWhomSettingsClearing.UserArray;
	Else
		Sources = New Array;
		UsersTable = New ValueTable;
		UsersTable.Columns.Add("User");
		// Get a list of all the users.
		UsersTable = DataProcessors.UserSettings.UsersForCopying("", UsersTable, False, True);
		
		For Each TableRow IN UsersTable Do
			Sources.Add(TableRow.User);
		EndDo;
		
	EndIf;
	
	DataProcessors.UserSettings.DeleteUserSettings(SettingsArray, Sources);
	
EndProcedure

#EndRegion
