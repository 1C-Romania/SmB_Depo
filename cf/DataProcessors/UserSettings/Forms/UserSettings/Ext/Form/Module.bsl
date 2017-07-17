
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	CurrentUserRef = Users.CurrentUser();
	CurrentInfobaseUser = DataProcessors.UserSettings.IBUserName(CurrentUserRef);
	
	If Parameters.User <> Undefined Then
		
		InfobaseUserID = CommonUse.ObjectAttributeValue(Parameters.User, "InfobaseUserID");
		SetPrivilegedMode(True);
		IBUser = InfobaseUsers.FindByUUID(InfobaseUserID);
		SetPrivilegedMode(False);
		If IBUser = Undefined Then
			Items.ReportOtWarning.CurrentPage = Items.RepresentWarning;
			Return;
		EndIf;
		
		UserRef = Parameters.User;
		Items.UserRef.Visible = False;
		Title = NStr("en='User settings';ru='Пользовательские настройки'");
		InfobaseUser = DataProcessors.UserSettings.IBUserName(UserRef);
	Else
		UserRef = Users.CurrentUser();
		InfobaseUser = DataProcessors.UserSettings.IBUserName(UserRef);
	EndIf;
	
	UseExternalUsers = GetFunctionalOption("UseExternalUsers");
	
	FormNamePersonalSettings = CommonUse.GeneralBasicFunctionalityParameters(
		).FormNamePersonalSettings;
	
	SelectedSettingsPage = Items.KindsSettings.CurrentPage.Name;
	FillListsSettings();
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	SearchChoiceList = Settings.Get("SearchChoiceList");
	If TypeOf(SearchChoiceList) = Type("Array") Then
		Items.Search.ChoiceList.LoadValues(SearchChoiceList);
	EndIf;
	Search = "";
	
EndProcedure

&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)
	
	Settings.Insert("SearchChoiceList", Items.Search.ChoiceList.UnloadValues());
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	NotificationProcessingParameters = New Structure("EventName, Parameter", EventName, Parameter);
	AttachIdleHandler("Attachable_ExecuteNotifyProcessing", 0.1, True);
	
EndProcedure

&AtClient
Procedure UserRefOnChange(Item)
	Items.CommandBar.Enabled = Not IsBlankString(Item.SelectedText);
	
	GetUserNameAndUpdate();
	ExpandValueTree();
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure OnCurrentPageChange(Item, CurrentPage)
	
	SelectedSettingsPage = CurrentPage.Name;
	
EndProcedure

&AtClient
Procedure SearchOnChange(Item)
	
	If ValueIsFilled(Search) Then
		ChoiceList = Items.Search.ChoiceList;
		ItemOfList = ChoiceList.FindByValue(Search);
		If ItemOfList = Undefined Then
			ChoiceList.Insert(0, Search);
			If ChoiceList.Count() > 10 Then
				ChoiceList.Delete(10);
			EndIf;
		Else
			IndexOf = ChoiceList.IndexOf(ItemOfList);
			If IndexOf <> 0 Then
				ChoiceList.Move(IndexOf, -IndexOf);
			EndIf;
		EndIf;
		CurrentItem = Items.Search;
	EndIf;
	
	FillListsSettings();
	ExpandValueTree();
	
EndProcedure

&AtClient
Procedure UserRefStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	FilterParameters = New Structure("HideUsersWithoutInfobaseUser, ChoiceMode", True, True);
	
	If UseExternalUsers Then
		TypeChoiceUsers = New ValueList;
		TypeChoiceUsers.Add("ExternalUsers", NStr("en='External users';ru='Внешние пользователи'"));
		TypeChoiceUsers.Add("Users", NStr("en='Users';ru='Пользователи'"));
		
		Notification = New NotifyDescription("UserRefToStartChoiceEnd", ThisObject, FilterParameters);
		TypeChoiceUsers.ShowChooseItem(Notification);
	Else
		OpenForm("Catalog.Users.Form.ListForm", FilterParameters, Items.UserRef);
	EndIf;
	
EndProcedure

&AtClient
Procedure UserRefToStartChoiceEnd(SelectedVariant, FilterParameters) Export
	
	If SelectedVariant = Undefined Then
		Return;
	EndIf;
	
	If SelectedVariant.Value = "Users" Then
		OpenForm("Catalog.Users.Form.ListForm", FilterParameters, Items.UserRef);
	ElsIf SelectedVariant.Value = "ExternalUsers" Then
		OpenForm("Catalog.ExternalUsers.Form.ListForm", FilterParameters, Items.UserRef);
	EndIf;
	
EndProcedure

&AtClient
Procedure ReportsSettingsAndAppearanceBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Not Copy Then
		Cancel = True;
		Return;
	EndIf;
	
	CopySettings();
	
EndProcedure

&AtClient
Procedure SettingsBeforeDelete(Item, Cancel)
	
	Cancel = True;
	QuestionText = NStr("en='Clear the selected settings?';ru='Очистить выделенные настройки?'");
	Notification = New NotifyDescription("SettingsBeforeDeleteEnd", ThisObject, Item);
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo,, DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure SettingsTreeChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	UsersServiceClient.OpenReportOrForm(
		CurrentItem, InfobaseUser, CurrentInfobaseUser, FormNamePersonalSettings);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Refresh(Command)
	
	FillListsSettings();
	ExpandValueTree();
	
EndProcedure

&AtClient
Procedure CopyOther(Command)
	
	CopySettings();
	
EndProcedure

&AtClient
Procedure CopyAllSettings(Command)
	
	UserType = TypeOf(UserRef);
	CopiedSettings.Clear();
	CopiedSettings.Add("ReportsSettings", NStr("en='Report settings';ru='Настройки отчета'"));
	CopiedSettings.Add("ExternalViewSettings", NStr("en='Appearance settings';ru='Настройки внешнего вида'"));
	CopiedSettings.Add("FormsData", NStr("en='Form data';ru='Данные форм'"));
	CopiedSettings.Add("PersonalSettings", NStr("en='Personal settings';ru='Персональные настройки'"));
	CopiedSettings.Add("Favorites", NStr("en='Favorites';ru='Избранное'"));
	CopiedSettings.Add("PrintSettings", NStr("en='Print settings';ru='Настройки печати'"));
	CopiedSettings.Add(
		"OtherUserSettings", NStr("en='Settings of additional reports and data processors';ru='Настройки дополнительных отчетов и обработок'"));
	
	FormParameters = New Structure("User, UserType, ActionType", 
										UserRef, UserType, "CopyAll");
	OpenForm("DataProcessor.UserSettings.Form.UsersChoice", FormParameters);
	
EndProcedure

&AtClient
Procedure CopyReportsSettings(Command)
	
	UserType = TypeOf(UserRef);
	CopiedSettings.Clear();
	CopiedSettings.Add("ReportsSettings", NStr("en='Report settings';ru='Настройки отчета'"));
	
	FormParameters = New Structure("User, UserType, ActionType", 
										UserRef, UserType, "CopyAll");
	OpenForm("DataProcessor.UserSettings.Form.UsersChoice", FormParameters);
	
EndProcedure

&AtClient
Procedure CopyExternalViewSettings(Command)
	
	UserType = TypeOf(UserRef);
	CopiedSettings.Clear();
	CopiedSettings.Add("ExternalViewSettings", NStr("en='Appearance settings';ru='Настройки внешнего вида'"));
	
	FormParameters = New Structure("User, UserType, ActionType", 
										UserRef, UserType, "CopyAll");
	OpenForm("DataProcessor.UserSettings.Form.UsersChoice", FormParameters);
	
EndProcedure

&AtClient
Procedure CopyReportsSettingsAndExternalType(Command)
	
	UserType = TypeOf(UserRef);
	CopiedSettings.Clear();
	CopiedSettings.Add("ReportsSettings", NStr("en='Report settings';ru='Настройки отчета'"));
	CopiedSettings.Add("ExternalViewSettings", NStr("en='Appearance settings';ru='Настройки внешнего вида'"));
	
	FormParameters = New Structure("User, UserType, ActionType", 
										UserRef, UserType, "CopyAll");
	OpenForm("DataProcessor.UserSettings.Form.UsersChoice", FormParameters);
	
EndProcedure

&AtClient
Procedure Clear(Command)
	
	SettingsTree = SelectedSettingsPageFormTable();
	SelectedRows = SettingsTree.SelectedRows;
	If SelectedRows.Count() = 0 Then
		
		ShowMessageBox(,NStr("en='Select settings to delete.';ru='Необходимо выбрать настройки, которые требуется удалить.'"));
		Return;
		
	EndIf;
	
	Notification = New NotifyDescription("ClearEnd", ThisObject, SettingsTree);
	QuestionText = NStr("en='Clear the selected settings?';ru='Очистить выделенные настройки?'");
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo,, DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure ClearSelectedUserSettings(Command)
	
	SettingsTree = SelectedSettingsPageFormTable();
	SelectedRows = SettingsTree.SelectedRows;
	If SelectedRows.Count() = 0 Then
		
		ShowMessageBox(,NStr("en='Select settings to delete.';ru='Необходимо выбрать настройки, которые требуется удалить.'"));
		Return;
		
	EndIf;
	
	QuestionText = NStr("en='Clear the selected settings? It will open the user selection window whose settings should be cleared.';ru='Очистить выделенные настройки? Откроется окно выбора пользователей, которым необходимо очистить настройки.'");
	Notification = New NotifyDescription("ClearSelectedUserSettingsEnd", ThisObject);
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo,, DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure ClearAllSettings(Command)
	
	QuestionText = NStr("en='Clear all settings of user ""%1""?';ru='Очистить все настройки у пользователя ""%1""?'");
	QuestionText = StringFunctionsClientServer.SubstituteParametersInString(QuestionText, UserRef);
	QuestionButtons = New ValueList;
	QuestionButtons.Add("Clear", NStr("en='Clear';ru='Очистить'"));
	QuestionButtons.Add("Cancel", NStr("en='Cancel';ru='Отменить'"));
	
	Notification = New NotifyDescription("ClearAllSettingsEnd", ThisObject);
	ShowQueryBox(Notification, QuestionText, QuestionButtons,, QuestionButtons[1].Value);
	
EndProcedure

&AtClient
Procedure ClearReportsAndAppearanceSettings(Command)
	
	QuestionText = NStr("en='Clear all settings of reports and appearance of user ""%1""?';ru='Очистить все настройки отчетов и внешнего вида у пользователя ""%1""?'");
	QuestionText = StringFunctionsClientServer.SubstituteParametersInString(QuestionText, UserRef);
	QuestionButtons = New ValueList;
	QuestionButtons.Add("Clear", NStr("en='Clear';ru='Очистить'"));
	QuestionButtons.Add("Cancel", NStr("en='Cancel';ru='Отменить'"));
	
	Notification = New NotifyDescription("ClearReportsAndAppearanceSettingsEnd", ThisObject);
	ShowQueryBox(Notification, QuestionText, QuestionButtons,, QuestionButtons[1].Value);
	
EndProcedure

&AtClient
Procedure OpenSetting(Command)
	
	UsersServiceClient.OpenReportOrForm(
		CurrentItem, InfobaseUser, CurrentInfobaseUser, FormNamePersonalSettings);
	
EndProcedure

&AtClient
Procedure ClearAllUserSettings(Command)
	
	QuestionText = NStr("en='All user settings will be cleared.
		|Continue?';ru='Сейчас будут очищены все настройки всех пользователей.
		|Продолжить?'");
	QuestionText = StringFunctionsClientServer.SubstituteParametersInString(QuestionText, UserRef);
	QuestionButtons = New ValueList;
	QuestionButtons.Add("ClearAll", NStr("en='Clear all';ru='Очистить все'"));
	QuestionButtons.Add("Cancel", NStr("en='Cancel';ru='Отменить'"));
	
	Notification = New NotifyDescription("ClearAllUserSettingsEnd", ThisObject);
	ShowQueryBox(Notification, QuestionText, QuestionButtons,, QuestionButtons[1].Value);
	
EndProcedure

&AtClient
Procedure CopyFrom(Command)
	
	FormParameters = New Structure("User, FormOpeningMode", UserRef, "CopyFrom");
	OpenForm("DataProcessor.UserSettings.Form.UserSettingsCopying", FormParameters);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for setting list output.

&AtServer
Procedure FillListsSettings()
	
	DataProcessors.UserSettings.FillListsSettings(ThisObject);
	CalculateSettingsCount();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for calculation of setting counts.

&AtServer
Procedure CalculateSettingsCount()
	
	SettingsList = ReportsSettings.GetItems();
	
	SettingsCount = CountSettingsInTreeView(SettingsList);
	
	If SettingsCount <> 0 Then
		Items.ReportsSettingsPage.Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Report settings (%1)';ru='Настройки отчетов (%1)'"), SettingsCount);
	Else
		Items.ReportsSettingsPage.Title = NStr("en='Report settings';ru='Настройки отчета'");
	EndIf;
	
	ReportsSettingsAmount = SettingsCount;
	SettingsList = ExternalView.GetItems();
	SettingsCount = CountSettingsInTreeView(SettingsList);
	
	If SettingsCount <> 0 Then
		Items.AppearancePage.Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Appearance (%1)';ru='Внешний вид (%1)'"), SettingsCount);
	Else
		Items.AppearancePage.Title = NStr("en='Appearance';ru='Оформление'");
	EndIf;
	
	AppearanceSettingsAmount = SettingsCount;
	SettingsList = OtherSettings.GetItems();
	SettingsCount = CountSettingsInTreeView(SettingsList);
	
	If SettingsCount <> 0 Then
		Items.OtherSettingsPage.Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Other settings (%1)';ru='Прочие настройки (%1)'"), SettingsCount);
	Else
		Items.OtherSettingsPage.Title = NStr("en='Other settings';ru='Прочие настройки'");
	EndIf;
	
	OtherSettingsAmount = SettingsCount;
	SettingsInTotal = OtherSettingsAmount + ReportsSettingsAmount;
	
EndProcedure

&AtServer
Function CountSettingsInTreeView(SettingsList)
	
	SettingsCount = 0;
	For Each Setting IN SettingsList Do
		
		SubordinateSettingsCount = Setting.GetItems().Count();
		If SubordinateSettingsCount = 0 Then
			SettingsCount = SettingsCount + 1;
		Else
			SettingsCount = SettingsCount + SubordinateSettingsCount;
		EndIf;
		
	EndDo;
	
	Return SettingsCount;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions that you can use to copy, delete and clear settings.

&AtServer
Procedure CopyAtServer(UsersTarget, PersonalReportsSettings, Report)
	
	Result = SelectedSettings();
	SelectedReportsVariantsTable = New ValueTable;
	SelectedReportsVariantsTable.Columns.Add("Presentation");
	SelectedReportsVariantsTable.Columns.Add("StandardProcessing");
	
	If SelectedSettingsPage = "ReportsSettingsPage" Then
		
		For Each Setting IN Result.SettingsArray Do
			
			For Each Item IN Setting Do
				
				If Item.Check Then
					PersonalReportsSettings = PersonalReportsSettings + 1;
					ReportKey = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Item.Value, "/");
					FilterParameter = New Structure("ObjectKey", ReportKey[0]);
					RowArray = UserVariantsReportsTable.FindRows(FilterParameter);
					If RowArray.Count() <> 0 Then
						TableRow = SelectedReportsVariantsTable.Add();
						TableRow.Presentation = RowArray[0].Presentation;
						TableRow.StandardProcessing = True;
					EndIf;
					
				EndIf;
				
			EndDo;
			
		EndDo;
		
		NotCopiedReportsSettings = New ValueTable;
		NotCopiedReportsSettings.Columns.Add("User");
		NotCopiedReportsSettings.Columns.Add("ReportList", New TypeDescription("ValueList"));
		
		DataProcessors.UserSettings.CopyReportsSettingsAndPersonalSettings(ReportsUserSettingsStorage,
			InfobaseUser, UsersTarget, Result.SettingsArray, NotCopiedReportsSettings);
		// Report variants copy.
		DataProcessors.UserSettings.CopyReportsVariants(Result.OptionsArrayReports,
			UserVariantsReportsTable, InfobaseUser, UsersTarget);
			
		If NotCopiedReportsSettings.Count() <> 0
			Or UserVariantsReportsTable.Count() <> 0 Then
			Report = DataProcessors.UserSettings.CopyingReportGenerating(
				NotCopiedReportsSettings, SelectedReportsVariantsTable);
		EndIf;
		
	ElsIf SelectedSettingsPage = "AppearancePage" Then
		DataProcessors.UserSettings.CopyExternalViewSettings(InfobaseUser, UsersTarget, Result.SettingsArray);
	Else
		
		If Result.PersonalSettingsArray.Count() <> 0 Then
			DataProcessors.UserSettings.CopyReportsSettingsAndPersonalSettings(CommonSettingsStorage,
				InfobaseUser, UsersTarget, Result.PersonalSettingsArray);
		EndIf;
			
		If Result.UserSettingsArray.Count() <> 0 Then
			For Each OtherUserSettings IN Result.UserSettingsArray Do
				For Each UserTarget IN UsersTarget Do
					UserInfo = New Structure;
					UserInfo.Insert("UserRef", UserTarget);
					UserInfo.Insert("InfobaseUserName",
						DataProcessors.UserSettings.IBUserName(UserTarget));
					
					UsersService.OnSaveOtherSetings(
						UserInfo, OtherUserSettings);
				EndDo;
			EndDo;
		EndIf;
		
		DataProcessors.UserSettings.CopyExternalViewSettings(
			InfobaseUser, UsersTarget, Result.SettingsArray);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CopyAllSettingsAtServer(User, UsersTarget, SettingsArray, Report)
	
	NotCopiedReportsSettings = New ValueTable;
	NotCopiedReportsSettings.Columns.Add("User");
	NotCopiedReportsSettings.Columns.Add("ReportList", New TypeDescription("ValueList"));
	DataProcessors.UserSettings.UserSettingsCopying(
		UserRef, UsersTarget, SettingsArray, NotCopiedReportsSettings);
		
	If NotCopiedReportsSettings.Count() <> 0
		Or UserVariantsReportsTable.Count() <> 0 Then
		Report = DataProcessors.UserSettings.CopyingReportGenerating(
			NotCopiedReportsSettings, UserVariantsReportsTable);
	EndIf;
	
EndProcedure

&AtServer
Procedure ClearAtServer(Users = Undefined, SelectedUsers = False)
	
	Result = SelectedSettings();
	NameStore = SettingsStorageForSelectedPage();
	
	If SelectedUsers Then
		
		DataProcessors.UserSettings.DeleteSelectedUserSettings(Users, Result.SettingsArray, NameStore);
		If Result.PersonalSettingsArray.Count() <> 0 Then
			DataProcessors.UserSettings.DeleteSelectedUserSettings(Users,
				Result.PersonalSettingsArray, "CommonSettingsStorage");
		EndIf;
		
		Return;
	EndIf;
	
	// Clear settings
	DataProcessors.UserSettings.DeleteSelectedSettings(InfobaseUser, Result.SettingsArray, NameStore);
	If Result.PersonalSettingsArray.Count() <> 0 Then
		DataProcessors.UserSettings.DeleteSelectedSettings(
			InfobaseUser, Result.PersonalSettingsArray, "CommonSettingsStorage");
	EndIf;
	
	If Result.UserSettingsArray.Count() <> 0 Then
		For Each OtherUserSettings IN Result.UserSettingsArray Do
			UserInfo = New Structure;
			UserInfo.Insert("UserRef", UserRef);
			UserInfo.Insert("InfobaseUserName", InfobaseUser);
			UsersService.OnDeleteOtherSettings(
				UserInfo, OtherUserSettings);
		EndDo;
	EndIf;
	
	// Clearing of reports variants
	If SelectedSettingsPage = "ReportsSettingsPage" Then
		
		DataProcessors.UserSettings.DeleteReportsVariants(
			Result.OptionsArrayReports, UserVariantsReportsTable, InfobaseUser);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ClearAllSettingsAtServer(ClearedSettings)
	
	UserArray = New Array;
	UserArray.Add(UserRef);
	DataProcessors.UserSettings.DeleteUserSettings(
		ClearedSettings, UserArray, UserVariantsReportsTable);
	
	FillListsSettings();
	
EndProcedure

&AtServer
Procedure ClearSettingsOfAllUsersAtServer()
	
	ClearedSettings = New Array;
	ClearedSettings.Add("ReportsSettings");
	ClearedSettings.Add("ExternalViewSettings");
	ClearedSettings.Add("PersonalSettings");
	ClearedSettings.Add("FormsData");
	ClearedSettings.Add("Favorites");
	ClearedSettings.Add("PrintSettings");
	
	UserArray = New Array;
	UsersTable = New ValueTable;
	UsersTable.Columns.Add("User");
	UsersTable = DataProcessors.UserSettings.UsersForCopying("", UsersTable, UseExternalUsers);
	
	For Each TableRow IN UsersTable Do
		UserArray.Add(TableRow.User);
	EndDo;
	
	DataProcessors.UserSettings.DeleteUserSettings(ClearedSettings, UserArray, UserVariantsReportsTable);
	
EndProcedure

&AtClient
Procedure DeleteSettingsFromValueTree(SelectedRows)
	
	For Each SelectedRow IN SelectedRows Do
		
		If SelectedSettingsPage = "ReportsSettingsPage" Then
			DeleteSettingsRow(ReportsSettings, SelectedRow);
		ElsIf SelectedSettingsPage = "AppearancePage" Then
			DeleteSettingsRow(ExternalView, SelectedRow);
		Else
			DeleteSettingsRow(OtherSettings, SelectedRow);
		EndIf;
		
	EndDo;
	
	CalculateSettingsCount();
EndProcedure

&AtClient
Procedure ClearEnd(Response, SettingsTree) Export
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	SelectedRows = SettingsTree.SelectedRows;
	SettingsCount = CountOfCopiedOrRemoteSettings(SettingsTree);
	
	ClearAtServer();
	CommonUseClient.RefreshApplicationInterface();
	
	If SettingsCount = 1 Then
		
		SettingName = SettingsTree.CurrentData.Setting;
		If StrLen(SettingName) > 24 Then
			SettingName = Left(SettingName, 24) + "...";
		EndIf;
		
	EndIf;
	
	DeleteSettingsFromValueTree(SelectedRows);
	
	NotifyAboutDeleting(SettingsCount, SettingName);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

&AtClient
Procedure Attachable_ExecuteNotifyProcessing()
	
	EventName = NotificationProcessingParameters.EventName;
	Parameter   = NotificationProcessingParameters.Parameter;
	
	If Upper(EventName) = Upper("CaseUser") Then
		
		UsersTarget = Parameter.UsersTarget;
		UserCount = UsersTarget.Count();
		
		ExplanationToWhomSettingsAreCopied = UsersServiceClient.ExplanationUsers(
			UserCount, UsersTarget[0]);
		
		If Parameter.CopyAll Then
			
			SettingsArray = New Array;
			SettingsNames = "";
			For Each Setting IN CopiedSettings Do 
				
				SettingsNames = SettingsNames + Lower(Setting.Presentation) + ", ";
				SettingsArray.Add(Setting.Value);
				
			EndDo;
				
			SettingsNames = Left(SettingsNames, StrLen(SettingsNames)-2);
			
			If SettingsArray.Count() = 7 Then
				ExplanationText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='All settings copied %1';ru='Скопированы все настройки %1'"), ExplanationToWhomSettingsAreCopied);
			Else
				ExplanationText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='%1 are copied %2';ru='%1 скопированы %2'"), SettingsNames, ExplanationToWhomSettingsAreCopied);
			EndIf;
				
			Status(NStr("en='Copying settings';ru='Выполняется копирование настроек'"));
			
			Report = Undefined;
			CopyAllSettingsAtServer(InfobaseUser, UsersTarget, SettingsArray, Report);
			
			If Report <> Undefined Then
				QuestionText = NStr("en='Not all report variants and settings were copied.';ru='Не все варианты отчетов и настройки были скопированы.'");
				QuestionButtons = New ValueList;
				QuestionButtons.Add("Ok", NStr("en='OK';ru='Ок'"));
				QuestionButtons.Add("ShowReport", NStr("en='Show report';ru='Показать отчет'"));
				
				Notification = New NotifyDescription("NotificationProcessingShowQueryBox", ThisObject, Report);
				ShowQueryBox(Notification, QuestionText, QuestionButtons,, QuestionButtons[0].Value);
				
				Return;
			EndIf;
				
			ShowUserNotification(
				NStr("en='Copy settings';ru='Копирование настроек'"), , ExplanationText, PictureLib.Information32);
			
			Return;
		EndIf;
		
		If Parameter.ClearingSettings Then
			
			SettingsTree = SelectedSettingsPageFormTable();
			SettingsCount = CountOfCopiedOrRemoteSettings(SettingsTree);
			
			ClearAtServer(UsersTarget, True);
			
			If SettingsCount = 1 Then
				
				SettingName = SettingsTree.CurrentData.Setting;
				If StrLen(SettingName) > 24 Then
					SettingName = Left(SettingName, 24) + "...";
				EndIf;
				
			EndIf;
			
			UserCount = Parameter.UsersTarget.Count();
			NotifyAboutDeleting(SettingsCount, SettingName, UserCount);
			
			Return;
		EndIf;
		
		SettingsTree = SelectedSettingsPageFormTable();
		SettingsCount = CountOfCopiedOrRemoteSettings(SettingsTree);
		
		PersonalReportsSettings = 0;
		Report = Undefined;
		CopyAtServer(UsersTarget, PersonalReportsSettings, Report);
		
		If Report <> Undefined Then
			QuestionText = NStr("en='Not all report variants and settings were copied.';ru='Не все варианты отчетов и настройки были скопированы.'");
			QuestionButtons = New ValueList;
			QuestionButtons.Add("Ok", NStr("en='OK';ru='Ок'"));
			QuestionButtons.Add("ShowReport", NStr("en='Show report';ru='Показать отчет'"));
			
			Notification = New NotifyDescription("NotificationProcessingShowQueryBox", ThisObject, Report);
			ShowQueryBox(Notification, QuestionText, QuestionButtons,, QuestionButtons[0].Value);
			
			Return;
		Else
			
			If SettingsCount = 1 Then
				SettingRepresentation = SettingsTree.CurrentData.Setting;
			EndIf;
			
			ExplanationText = UsersServiceClient.GeneratingExplanationOnCopying(
				SettingRepresentation, SettingsCount, ExplanationToWhomSettingsAreCopied);
			ShowUserNotification(
				NStr("en='Copy settings';ru='Копирование настроек'"), , ExplanationText, PictureLib.Information32);
			
		EndIf;
		
	ElsIf Upper(EventName) = Upper("CopiedSettings") Then
		FillListsSettings();
		ExpandValueTree();
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearSelectedUserSettingsEnd(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	UserType = TypeOf(UserRef);
	FormParameters = New Structure("User, UserType, ActionType",
		UserRef, UserType, "Clearing");
	OpenForm("DataProcessor.UserSettings.Form.UsersChoice", FormParameters);
	
EndProcedure

&AtClient
Procedure ClearAllUserSettingsEnd(Response, AdditionalParameters) Export
	
	If Response = "Cancel" Then
		Return;
	EndIf;
	
	ClearSettingsOfAllUsersAtServer();
	CommonUseClient.RefreshApplicationInterface();
	
	ShowUserNotification(NStr("en='Clear settings';ru='Очистить настройки'"), ,
		NStr("en='All settings of all users are cleaned up';ru='Очищены все настройки всех пользователя'"), PictureLib.Information32);
	
EndProcedure

&AtClient
Procedure ClearAllSettingsEnd(Response, AdditionalParameters) Export
	
	If Response = "Cancel" Then
		Return;
	EndIf;
	
	ClearedSettings = New Array;
	ClearedSettings.Add("ReportsSettings");
	ClearedSettings.Add("ExternalViewSettings");
	ClearedSettings.Add("FormsData");
	ClearedSettings.Add("PersonalSettings");
	ClearedSettings.Add("Favorites");
	ClearedSettings.Add("PrintSettings");
	ClearedSettings.Add("OtherUserSettings");
	
	ClearAllSettingsAtServer(ClearedSettings);
	CommonUseClient.RefreshApplicationInterface();
	
	ExplanationText = NStr("en='All settings of user ""%1"" are cleaned up';ru='Очищены все настройки пользователя ""%1""'");
	ExplanationText = StringFunctionsClientServer.SubstituteParametersInString(ExplanationText, UserRef);
	ShowUserNotification(
		NStr("en='Clear settings';ru='Очистить настройки'"), , ExplanationText, PictureLib.Information32);
	
EndProcedure

&AtClient
Procedure ClearReportsAndAppearanceSettingsEnd(Response, AdditionalParameters) Export
	
	If Response = "Cancel" Then
		Return;
	EndIf;
	
	ClearedSettings = New Array;
	ClearedSettings.Add("ReportsSettings");
	ClearedSettings.Add("ExternalViewSettings");
	ClearedSettings.Add("FormsData");
	
	ClearAllSettingsAtServer(ClearedSettings);
	CommonUseClient.RefreshApplicationInterface();
	
	ExplanationText = NStr("en='All settings of reports and appearance of user ""%1"" are cleaned up';ru='Очищены все настройки отчетов и внешнего вида у пользователя ""%1""'");
	ExplanationText = StringFunctionsClientServer.SubstituteParametersInString(ExplanationText, UserRef);
	ShowUserNotification(
		NStr("en='Clear settings';ru='Очистить настройки'"), , ExplanationText, PictureLib.Information32);
	
EndProcedure

&AtClient
Procedure SettingsBeforeDeleteEnd(Response, Item) Export
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	ClearAtServer();
	CommonUseClient.RefreshApplicationInterface();
	
	SelectedRows = Item.SelectedRows;
	SettingsCount = CountOfCopiedOrRemoteSettings(Item);
	
	If SettingsCount = 1 Then
		
		SettingsTree = SelectedSettingsPageFormTable();
		SettingName = SettingsTree.CurrentData.Setting;
		
		If StrLen(SettingName) > 24 Then
			SettingName = Left(SettingName, 24) + "...";
		EndIf;
		
	EndIf;
	
	DeleteSettingsFromValueTree(SelectedRows);
	
	NotifyAboutDeleting(SettingsCount, SettingName);
	
EndProcedure

&AtClient
Procedure NotificationProcessingShowQueryBox(Response, Report) Export
	
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

&AtClient
Procedure ExpandValueTree()
	
	Rows = ReportsSettings.GetItems();
	For Each String IN Rows Do
		Items.ReportsSettingsTree.Expand(String.GetID(), True);
	EndDo;
	
	Rows = ExternalView.GetItems();
	For Each String IN Rows Do
		Items.ExternalView.Expand(String.GetID(), True);
	EndDo;
	
EndProcedure

&AtClient
Function SelectedSettingsPageFormTable()
	
	If SelectedSettingsPage = "ReportsSettingsPage" Then
		Return Items.ReportsSettingsTree;
	ElsIf SelectedSettingsPage = "AppearancePage" Then
		Return Items.ExternalView;
	Else
		Return Items.OtherSettings;
	EndIf;
	
EndFunction

&AtClient
Function CountOfCopiedOrRemoteSettings(SettingsTree)
	
	SelectedRows = SettingsTree.SelectedRows;
	// Move array of selected row in the value list to sort selected rows.
	SelectedRowsList = New ValueList;
	For Each Item IN SelectedRows Do
		SelectedRowsList.Add(Item);
	EndDo;
	
	SelectedRowsList.SortByValue();
	If SelectedSettingsPage = "ReportsSettingsPage" Then
		CurrentValueTree = ReportsSettings;
	ElsIf SelectedSettingsPage = "AppearancePage" Then
		CurrentValueTree = ExternalView;
	Else
		CurrentValueTree = OtherSettings;
	EndIf;
	
	SettingsCount = 0;
	For Each SelectedRow IN SelectedRowsList Do
		TreeItem = CurrentValueTree.FindByID(SelectedRow.Value);
		CountItemsSubordinate = TreeItem.GetItems().Count();
		ItemParent = TreeItem.GetParent();
		
		If CountItemsSubordinate <> 0 Then
			SettingsCount = SettingsCount + CountItemsSubordinate;
			TopLevelItem = TreeItem;
		ElsIf CountItemsSubordinate = 0
			AND ItemParent = Undefined Then
			SettingsCount = SettingsCount + 1;
		Else
			
			If ItemParent <> TopLevelItem Then
				SettingsCount = SettingsCount + 1;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return SettingsCount;
EndFunction

&AtClient
Procedure DeleteSettingsRow(SettingsTree, SelectedRow)
	
	SettingsItem = SettingsTree.FindByID(SelectedRow);
	If SettingsItem = Undefined Then
		Return;
	EndIf;
	
	SettingsItemParent = SettingsItem.GetParent();
	If SettingsItemParent <> Undefined Then
		
		SubordinateRowsCount = SettingsItemParent.GetItems().Count();
		If SubordinateRowsCount = 1 Then
			
			If SettingsItemParent.Type <> "PersonalVariant" Then
				SettingsTree.GetItems().Delete(SettingsItemParent);
			EndIf;
			
		Else
			SettingsItemParent.GetItems().Delete(SettingsItem);
		EndIf;
		
	Else
		SettingsTree.GetItems().Delete(SettingsItem);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotifyAboutDeleting(SettingsCount, SettingName = Undefined, UserCount = Undefined)
	
	SubjectInWords = UsersServiceClient.GeneratingSettingsCountString(SettingsCount);
	If SettingsCount = 1
		AND UserCount = Undefined Then
		ExplanationText = NStr("en='""%1"" is cleared for user ""%2""';ru='""%1"" очищена пользователю ""%2""'");
		ExplanationText = StringFunctionsClientServer.SubstituteParametersInString(
			ExplanationText, SettingName, String(UserRef));
	ElsIf UserCount = Undefined Then
		ExplanationText = NStr("en='""%1"" is cleared for user ""%2""';ru='""%1"" очищена пользователю ""%2""'");
		ExplanationText = StringFunctionsClientServer.SubstituteParametersInString(
			ExplanationText, SubjectInWords, String(UserRef));
	EndIf;
	
	ExplanationWhomSettingsCleared = UsersServiceClient.ExplanationUsers(
		UserCount, String(UserRef));
	
	If UserCount <> Undefined Then
		
		If SettingsCount = 1 Then
			ExplanationText = NStr("en='""%1"" cleared %2';ru='""%1"" очищена %2'");
			ExplanationText = StringFunctionsClientServer.SubstituteParametersInString(
				ExplanationText, SettingName, ExplanationWhomSettingsCleared);
		Else
			ExplanationText = NStr("en='Cleared %1 %2';ru='Очищено %1 %2'");
			ExplanationText = StringFunctionsClientServer.SubstituteParametersInString(
				ExplanationText, SubjectInWords, ExplanationWhomSettingsCleared);
		EndIf;
		
	EndIf;
	
	ShowUserNotification(
		NStr("en='Clear settings';ru='Очистить настройки'"), , ExplanationText, PictureLib.Information32);
	
EndProcedure

&AtClient
Procedure CopySettings()
	
	SettingsTree = SelectedSettingsPageFormTable();
	If SettingsTree.SelectedRows.Count() = 0 Then
		ShowMessageBox(,NStr("en='Select settings to copy.';ru='Необходимо выбрать настройки, которые требуется скопировать.'"));
		Return;
	ElsIf SettingsTree.SelectedRows.Count() = 1 Then
		
		If SettingsTree.CurrentData.Type = "PersonalVariant" Then
			ShowMessageBox(,NStr("en='Impossible to copy the personal report variant.
		|If you want to make personal report variant to be
		|available to other users, then you need to resave it with the ""Only for author"" mark removed.';ru='Невозможно скопировать личный вариант отчета.
		|Для того чтобы личный вариант отчета стал доступен
		|другим пользователям, необходимо его пересохранить со снятой пометкой ""Только для автора"".'"));
			Return;
		ElsIf SettingsTree.CurrentData.Type = "SettingPersonal" Then
			ShowMessageBox(,NStr("en='Impossible to copy setting of the personal report variant.
		|Copying of the individual report variant settings is not provided.';ru='Невозможно скопировать настройку личного варианта отчета.
		|Копирование настроек личных вариантов отчетов не предусмотрено.'"));
			Return;
		EndIf;
		
	EndIf;
	
	UserType = TypeOf(UserRef);
	FormParameters = New Structure("User, UserType, ActionType", 
										UserRef, UserType, "");
	OpenForm("DataProcessor.UserSettings.Form.UsersChoice", FormParameters);
	
EndProcedure

&AtServer
Procedure GetUserNameAndUpdate()
	
	If Not ValueIsFilled(UserRef) Then
		UserRef = Catalogs.Users.EmptyRef();
		InfobaseUser = "";
	Else
		InfobaseUser = DataProcessors.UserSettings.IBUserName(UserRef);
	EndIf;
	FillListsSettings();
	
EndProcedure

&AtServer
Function SelectedPageValueTree()
	
	If SelectedSettingsPage = "ReportsSettingsPage" Then
		Return ReportsSettings;
	ElsIf SelectedSettingsPage = "AppearancePage" Then
		Return ExternalView;
	Else
		Return OtherSettings;
	EndIf;
	
EndFunction

&AtServer
Function SettingsStorageForSelectedPage()
	
	If SelectedSettingsPage = "ReportsSettingsPage" Then
		Return "ReportsUserSettingsStorage";
	ElsIf SelectedSettingsPage = "AppearancePage"
		Or SelectedSettingsPage = "OtherSettingsPage" Then
		Return "SystemSettingsStorage";
	EndIf;
	
EndFunction

&AtServer
Function SelectedSettingsItems()
	
	If SelectedSettingsPage = "ReportsSettingsPage" Then
		Return Items.ReportsSettingsTree.SelectedRows;
	ElsIf SelectedSettingsPage = "AppearancePage" Then
		Return Items.ExternalView.SelectedRows;
	Else
		Return Items.OtherSettings.SelectedRows;
	EndIf;
	
EndFunction

&AtServer
Function SelectedSettings()
	
	SettingsTree = SelectedPageValueTree();
	SettingsArray = New Array;
	PersonalSettingsArray = New Array;
	OptionsArrayReports = New Array;
	UserSettingsArray = New Array;
	CurrentReportVariant = Undefined;
	
	SelectedItems = SelectedSettingsItems();
	
	For Each SelectedItem IN SelectedItems Do
		SelectedSetting = SettingsTree.FindByID(SelectedItem);
		
		// Filling of personal settings array.
		If SelectedSetting.Type = "PersonalSettings" Then
			PersonalSettingsArray.Add(SelectedSetting.Keys);
			Continue;
		EndIf;
		
		// Filling array of other user settings.
		If SelectedSetting.Type = "OtherUserSetting" Then
			OtherUserSettings = New Structure;
			OtherUserSettings.Insert("SettingID", SelectedSetting.RowType);
			OtherUserSettings.Insert("SettingValue", SelectedSetting.Keys);
			UserSettingsArray.Add(OtherUserSettings);
			Continue;
		EndIf;
		
		// For personal settings make a mark in the key list.
		If SelectedSetting.Type = "PersonalVariant" Then
			
			For Each Item IN SelectedSetting.Keys Do
				Item.Check = True;
			EndDo;
			CurrentReportVariant = SelectedSetting.Keys.Copy();
			// Filling array of personal report variants.
			OptionsArrayReports.Add(SelectedSetting.Keys);
			
		ElsIf SelectedSetting.Type = "StandardPersonalVariant" Then
			OptionsArrayReports.Add(SelectedSetting.Keys);
		EndIf;
		
		If SelectedSetting.Type = "SettingPersonal" Then
			
			If CurrentReportVariant <> Undefined
				AND CurrentReportVariant.FindByValue(SelectedSetting.Keys[0].Value) <> Undefined Then
				Continue;
			Else
				SelectedSetting.Keys[0].Check = True;
				SettingsArray.Add(SelectedSetting.Keys);
				Continue;
			EndIf;
			
		EndIf;
		
		SettingsArray.Add(SelectedSetting.Keys);
		
	EndDo;
	
	Return New Structure("SettingsArray, PersonalSettingsArray, OptionsArrayReports, UserSettingsArray",
			SettingsArray, PersonalSettingsArray, OptionsArrayReports, UserSettingsArray);
EndFunction

#EndRegion
