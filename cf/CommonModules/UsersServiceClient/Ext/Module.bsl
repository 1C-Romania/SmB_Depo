////////////////////////////////////////////////////////////////////////////////
// Subsystem "Users".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

////////////////////////////////////////////////////////////////////////////////
// For role interface work in managed form.

// Only for internal use.
//
Procedure ExpandRolesSubsystems(Form, Unconditionally = True) Export
	
	Items = Form.Items;
	
	If Not Unconditionally
	   AND Not Items.RolesShowSelectedRolesOnly.Check Then
		
		Return;
	EndIf;
	
	// Unroll all.
	For Each String IN Form.Roles.GetItems() Do
		Items.Roles.Expand(String.GetID(), True);
	EndDo;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Verifies authorization of the user and notifies of an error.
Procedure BeforeStart(Parameters) Export
	
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	
	// SB. Creating first administrator for undivided base
	If ClientParameters.Property("FirstApplicationAdministratorAdded") Then
		
		Parameters.Cancel = True;
		Parameters.Restart = True;
		
	EndIf;
	// SB End
	
	If Not ClientParameters.Property("AuthorizationError") Then
		Return;
	EndIf;
	
	Parameters.Cancel = True;
	Parameters.InteractiveDataProcessor = New NotifyDescription(
		"OnlineDataProcessorAtVerifyingUserAuthorization", ThisObject);
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Notification handlers.

// Notifies about a user authentification error.
Procedure OnlineDataProcessorAtVerifyingUserAuthorization(Parameters, NotSpecified) Export
	
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	
	StandardSubsystemsClient.ShowWarningAndContinue(
		Parameters, ClientParameters.AuthorizationError);
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Procedures and functions of the "UsersSettings" data processor.

// Opens the passed report or form.
//
// Parameters:
//  CurrentItem               - FormTable - selected row of the value tree.
//  User                 - String - infobase user
//  name, CurrentUser          - String - name of the infobase user, to
//                                 open the form, it shall match the value of the "User" parameter.
//  FormNamePersonalSettings - String - path for opening a personal settings form.
//                                 of the "CommonForm.FormName" kind
Procedure OpenReportOrForm(CurrentItem, User, CurrentUser, FormNamePersonalSettings) Export
	
	ValueTreeItem = CurrentItem;
	If ValueTreeItem.CurrentData = Undefined Then
		Return;
	EndIf;
	
	If User <> CurrentUser Then
		WarningText = NStr("en='To view settings of other user, run the application on behalf of this user and open the needed report or form.';ru='Для просмотра настроек другого пользователя необходимо запустить программу от его имени и открыть нужный отчет или форму.'");
		ShowMessageBox(,WarningText);
		Return;
	EndIf;
	
	If ValueTreeItem.Name = "ReportsSettingsTree" Then
		
		ObjectKey = ValueTreeItem.CurrentData.Keys[0].Value;
		ObjectKeyRowsArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(ObjectKey, "/");
		VariantKey = ObjectKeyRowsArray[1];
		ReportParameters = New Structure("VariantKey, UserSettingsKey", VariantKey, "");
		
		If ValueTreeItem.CurrentData.Type = "ReportSetting" Then
			UserSettingsKey = ValueTreeItem.CurrentData.Keys[0].Presentation;
			ReportParameters.Insert("UserSettingsKey", UserSettingsKey);
		EndIf;
		
		OpenForm(ObjectKeyRowsArray[0] + ".Form", ReportParameters);
		Return;
		
	ElsIf ValueTreeItem.Name = "ExternalView" Then
		
		For Each ObjectKey IN ValueTreeItem.CurrentData.Keys Do
			
			If ObjectKey.Check = True Then
				
				OpenForm(ObjectKey.Value);
				Return;
			Else
				ItemParent = ValueTreeItem.CurrentData.GetParent();
				
				If ValueTreeItem.CurrentData.RowType = "DesktopSettings" Then
					ShowMessageBox(,NStr("en='To view desktop settings, go to the ""Desktop"" section
		|in the command interface of the application.';ru='Для просмотра настроек рабочего стола перейдите
		|к разделу ""Рабочий стол"" в командном интерфейсе программы.'"));
					Return;
				EndIf;
				
				If ValueTreeItem.CurrentData.RowType = "CommandInterfaceSettings" Then
					ShowMessageBox(,NStr("en='To view command interface settings, select the
		|required section of the command interface of the application.';ru='Для просмотра настроек командного интерфейса
		|выберите нужный раздел командного интерфейса программы.'"));
					Return;
				EndIf;
				
				If ItemParent <> Undefined Then
					WarningText = NStr("en='To  view this setting, open ""%1"" and go to form ""%2"".';ru='Для просмотра данной настройки необходимо открыть ""%1"" и затем перейти к форме ""%2"".'");
					WarningText = StringFunctionsClientServer.SubstituteParametersInString(WarningText,
						ItemParent.Setting, ValueTreeItem.CurrentData.Setting);
					ShowMessageBox(,WarningText);
					Return;
				EndIf;
				
			EndIf;
			
		EndDo;
		
		ShowMessageBox(,NStr("en='This setting is impossible to view.';ru='Данную настройку невозможно просмотреть.'"));
		Return;
		
	ElsIf ValueTreeItem.Name = "OtherSettings" Then
		
		If ValueTreeItem.CurrentData.Type = "PersonalSettings"
			AND FormNamePersonalSettings <> "" Then
			OpenForm(FormNamePersonalSettings);
			Return;
		EndIf;
		
		ShowMessageBox(,NStr("en='This setting is impossible to view.';ru='Данную настройку невозможно просмотреть.'"));
		Return;
		
	EndIf;
	
	ShowMessageBox(,NStr("en='Select the setting for viewing.';ru='Выберите настройку для просмотра.'"));
	
EndProcedure

// Generates the ending for the "setting" word.
//
// Parameters:
//  SettingsCount - Number - number of settings.
//
// Returns:
//  String - of the "xx settings" kind with a correct ending.
//
Function GeneratingSettingsCountString(SettingsCount) Export
	
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
		
	Return SubjectInWords;
EndFunction

// Generates an explanation string at copying settings.
//
// Parameters:
//  SettingRepresentation            - String - setting name. It is used if a single setting is copied.
//  SettingsCount                - Number  - number of settings. It is used if two or more settings are used.
//  ExplanationToWhomSettingsAreCopied - String - for whom the settings are copied.
//
// Returns:
//  String - explanatory text for setting copying.
//
Function GeneratingExplanationOnCopying(SettingRepresentation, SettingsCount, ExplanationToWhomSettingsAreCopied) Export
	
	If SettingsCount = 1 Then
		
		If StrLen(SettingRepresentation) > 24 Then
			SettingRepresentation = Left(SettingRepresentation, 24) + "...";
		EndIf;
		
		ExplanationText = NStr("en='""%1"" copied %2';ru='""%1"" скопирована %2'");
		ExplanationText = StringFunctionsClientServer.SubstituteParametersInString(
			ExplanationText, SettingRepresentation, ExplanationToWhomSettingsAreCopied);
	Else
		SubjectInWords = GeneratingSettingsCountString(SettingsCount);
		ExplanationText = NStr("en='Copied %1 %2';ru='Скопировано %1 %2'");
		ExplanationText = StringFunctionsClientServer.SubstituteParametersInString(
			ExplanationText, SubjectInWords, ExplanationToWhomSettingsAreCopied);
	EndIf;
	
	Return ExplanationText;
EndFunction

// Generates a string that describes the setting target.
//
// Parameters:
//  UserCount - Number  - it is used if the value is greater than 1.
//  User            - String - user name. It is used,
//                            if the number of users is equal to 1.
//
// Returns:
//  String - explains, to whom the setting is copied.
//
Function ExplanationUsers(UserCount, User) Export
	
	If UserCount = 1 Then
		ExplanationToWhomSettingsAreCopied = NStr("en='to user ""%1""';ru='пользователю ""%1""'");
		ExplanationToWhomSettingsAreCopied = StringFunctionsClientServer.SubstituteParametersInString(
			ExplanationToWhomSettingsAreCopied, User);
	Else
		ExplanationToWhomSettingsAreCopied = NStr("en='%1 to users';ru='%1 пользователям'");
		ExplanationToWhomSettingsAreCopied = StringFunctionsClientServer.SubstituteParametersInString(
			ExplanationToWhomSettingsAreCopied, UserCount);
	EndIf;
	
	Return ExplanationToWhomSettingsAreCopied;
EndFunction

#EndRegion
