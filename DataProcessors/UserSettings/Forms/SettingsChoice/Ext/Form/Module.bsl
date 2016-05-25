
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	UserRef = Parameters.User;
	ActionWithSettings = Parameters.ActionWithSettings;
	InfobaseUser = DataProcessors.UserSettings.IBUserName(UserRef);
	CurrentUserRef = Users.CurrentUser();
	CurrentUser = DataProcessors.UserSettings.IBUserName(CurrentUserRef);
	
	SelectedSettingsPage = Items.KindsSettings.CurrentPage.Name;
	
	FormNamePersonalSettings = CommonUse.GeneralBasicFunctionalityParameters(
		).FormNamePersonalSettings;
	
	FillListsSettings(False);
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If DataSavedToSettingsStorage Then
		Notify("SettingsChoice_DataSaved");
	EndIf;
	
EndProcedure

&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)
	
	Settings.Insert("SearchChoiceList", Items.Search.ChoiceList.UnloadValues());
	
	Settings.Delete("ExternalView");
	Settings.Delete("ReportsSettings");
	Settings.Delete("OtherSettings");
	
	ReportsSettingsTree = FormAttributeToValue("ReportsSettings");
	AppearanceTree = FormAttributeToValue("ExternalView");
	OtherSettingsTree = FormAttributeToValue("OtherSettings");
	
	MarkedReportSettings = MarkedSettings(ReportsSettingsTree);
	AppearanceMarkedSettings = MarkedSettings(AppearanceTree);
	MarkedOtherSettings = MarkedSettings(OtherSettingsTree);
	
	Settings.Insert("MarkedReportSettings", MarkedReportSettings);
	Settings.Insert("AppearanceMarkedSettings", AppearanceMarkedSettings);
	Settings.Insert("MarkedOtherSettings", MarkedOtherSettings);
	
	DataSavedToSettingsStorage = True;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If Parameters.ClearHistoryOfSelectSettings Then
		Settings.Clear();
		Return;
	EndIf;
	
	SearchChoiceList = Settings.Get("SearchChoiceList");
	If TypeOf(SearchChoiceList) = Type("Array") Then
		Items.Search.ChoiceList.LoadValues(SearchChoiceList);
	EndIf;
	Search = "";
	
	MarkedReportSettings = Settings.Get("MarkedReportSettings");
	AppearanceMarkedSettings = Settings.Get("AppearanceMarkedSettings");
	MarkedOtherSettings = Settings.Get("MarkedOtherSettings");
	
	ImportMarksValues(ReportsSettings, MarkedReportSettings, "ReportsSettings");
	ImportMarksValues(ExternalView, AppearanceMarkedSettings, "ExternalView");
	ImportMarksValues(OtherSettings, MarkedOtherSettings, "OtherSettings");
	
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
	
	FillListsSettings(True);
	ExpandValueTree();
	
EndProcedure

&AtClient
Procedure SettingsTreeChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	UsersServiceClient.OpenReportOrForm(
		CurrentItem, InfobaseUser, CurrentUser, FormNamePersonalSettings);
	
EndProcedure

&AtClient
Procedure CheckOnChange(Item)
	
	ChangeMark(Item);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Refresh(Command)
	
	FillListsSettings(False);
	ExpandValueTree();
	
EndProcedure

&AtClient
Procedure OpenSetting(Command)
	
	UsersServiceClient.OpenReportOrForm(
		CurrentItem, InfobaseUser, CurrentUser, FormNamePersonalSettings);
	
EndProcedure

&AtClient
Procedure CheckAll(Command)
	
	If SelectedSettingsPage = "ReportsSettingsPage" Then
		SettingsTree = ReportsSettings.GetItems();
		MarkTreeItems(SettingsTree, True);
	ElsIf SelectedSettingsPage = "AppearancePage" Then
		SettingsTree = ExternalView.GetItems();
		MarkTreeItems(SettingsTree, True);
	Else
		SettingsTree = OtherSettings.GetItems();
		MarkTreeItems(SettingsTree, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	If SelectedSettingsPage = "ReportsSettingsPage" Then
		SettingsTree = ReportsSettings.GetItems();
		MarkTreeItems(SettingsTree, False);
	ElsIf SelectedSettingsPage = "AppearancePage" Then
		SettingsTree = ExternalView.GetItems();
		MarkTreeItems(SettingsTree, False);
	Else
		SettingsTree = OtherSettings.GetItems();
		MarkTreeItems(SettingsTree, False);
	EndIf;
	
EndProcedure

&AtClient
Procedure Select(Command)
	
	Result = New Structure();
	SelectedReportsSettings = SelectedSettings(ReportsSettings);
	AppearanceSelectedSettings = SelectedSettings(ExternalView);
	OtherSettingsStructure = SelectedSettings(OtherSettings);
	SettingsCount = SelectedReportsSettings.SettingsCount +
		AppearanceSelectedSettings.SettingsCount + OtherSettingsStructure.SettingsCount;
		
	If SelectedReportsSettings.SettingsCount = 1 Then
		SettingsPresentation = SelectedReportsSettings.SettingsPresentation;
	ElsIf AppearanceSelectedSettings.SettingsCount = 1 Then
		SettingsPresentation = AppearanceSelectedSettings.SettingsPresentation;
	ElsIf  OtherSettingsStructure.SettingsCount = 1 Then
		SettingsPresentation = OtherSettingsStructure.SettingsPresentation;
	EndIf;
	
	Result.Insert("ReportsSettings", SelectedReportsSettings.SettingsArray);
	Result.Insert("ExternalView", AppearanceSelectedSettings.SettingsArray);
	Result.Insert("OtherSettings", OtherSettingsStructure.SettingsArray);
	Result.Insert("SettingsPresentation", SettingsPresentation);
	Result.Insert("PersonalSettings", OtherSettingsStructure.PersonalSettingsArray);
	Result.Insert("SettingsCount", SettingsCount);
	Result.Insert("ReportVariantsTable", UserVariantsReportsTable);
	Result.Insert("SelectedReportsVariants", SelectedReportsSettings.ReportVariants);
	Result.Insert("OtherUserSettings",
		OtherSettingsStructure.OtherUserSettings);
	
	Notify("SettingsChoice", Result);
	Close();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used to show the settings to the user.

&AtServer
Procedure FillListsSettings(SettingsSearch)
	
	If SettingsSearch Then
		
		MarkedTreeItems();
		
	EndIf;
	
	DataProcessors.UserSettings.FillListsSettings(ThisObject);
	
	If SettingsSearch Then
		
		ImportMarksValues(ReportsSettings, AllSelectedSettings.MarkedReportSettings, "ReportsSettings");
		ImportMarksValues(ExternalView, AllSelectedSettings.AppearanceMarkedSettings, "ExternalView");
		ImportMarksValues(OtherSettings, AllSelectedSettings.MarkedOtherSettings, "OtherSettings");
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

&AtClient
Procedure ChangeMark(Item)
	
	MarkedItem = Item.Parent.Parent.CurrentData;
	ValueMark = MarkedItem.Check;
	
	If ValueMark = 2 Then
		ValueMark = 0;
		MarkedItem.Check = ValueMark;
	EndIf;
	
	ItemParent = MarkedItem.GetParent();
	ChildItems = MarkedItem.GetItems();
	SettingsCount = 0;
	
	If ItemParent = Undefined Then
		
		For Each ChildItem IN ChildItems Do
			
			If ChildItem.Check <> ValueMark Then
				SettingsCount = SettingsCount + 1
			EndIf;
			
			ChildItem.Check = ValueMark;
		EndDo;
		
		If ChildItems.Count() = 0 Then
			SettingsCount = SettingsCount + 1;
		EndIf;
		
	Else
		CheckChildItemsMarksAndMarkParent(ItemParent, ValueMark);
		SettingsCount = SettingsCount + 1;
	EndIf;
	
	SettingsCount = ?(ValueMark, SettingsCount, -SettingsCount);
	// Update of the settings page header.
	UpdatePageTitle(SettingsCount);
	
EndProcedure

&AtClient
Procedure UpdatePageTitle(SettingsCount)
	
	If SelectedSettingsPage = "ReportsSettingsPage" Then
		
		ReportsSettingsAmount = ReportsSettingsAmount + SettingsCount;
		HeaderText = ?(ReportsSettingsAmount = 0, NStr("en='Report settings'"), NStr("en='Reports settings (%1)'"));
		
		Items.ReportsSettingsPage.Title = StringFunctionsClientServer.PlaceParametersIntoString(
			HeaderText, ReportsSettingsAmount);
		
	ElsIf SelectedSettingsPage = "AppearancePage" Then
		
		AppearanceSettingsAmount = AppearanceSettingsAmount + SettingsCount;
		HeaderText = ?(AppearanceSettingsAmount = 0, NStr("en='Appearance'"), NStr("en='Appearance (%1)'"));
		
		Items.AppearancePage.Title = StringFunctionsClientServer.PlaceParametersIntoString(
			HeaderText, AppearanceSettingsAmount);
		
	ElsIf SelectedSettingsPage = "OtherSettingsPage" Then
		
		OtherSettingsAmount = OtherSettingsAmount + SettingsCount;
		HeaderText = ?(OtherSettingsAmount = 0, NStr("en='Other settings'"), NStr("en='Other settings (%1)'"));
		
		Items.OtherSettingsPage.Title = StringFunctionsClientServer.PlaceParametersIntoString(
			HeaderText, OtherSettingsAmount);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckChildItemsMarksAndMarkParent(TreeItem, ValueMark)
	
	ThereAreUnmarked = False;
	AreMarked = False;
	
	ChildItems = TreeItem.GetItems();
	If ChildItems = Undefined Then
		TreeItem.Check = ValueMark;
	Else
		
		For Each ChildItem IN ChildItems Do
			
			If ChildItem.Check = 0 Then
				ThereAreUnmarked = True;
			ElsIf ChildItem.Check = 1 Then
				AreMarked = True;
			EndIf;
			
		EndDo;
		
		If ThereAreUnmarked 
			AND AreMarked Then
			TreeItem.Check = 2;
		ElsIf AreMarked Then
			TreeItem.Check = 1;
		Else
			TreeItem.Check = 0;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure MarkTreeItems(SettingsTree, ValueMark)
	
	SettingsCount = 0;
	For Each TreeItem IN SettingsTree Do
		ChildItems = TreeItem.GetItems();
		
		For Each ChildItem IN ChildItems Do
			
			ChildItem.Check = ValueMark;
			SettingsCount = SettingsCount + 1;
			
		EndDo;
		
		If ChildItems.Count() = 0 Then
			SettingsCount = SettingsCount + 1;
		EndIf;
		
		TreeItem.Check = ValueMark;
	EndDo;
	
	SettingsCount = ?(ValueMark, SettingsCount, 0);
	
	If SelectedSettingsPage = "ReportsSettingsPage" Then
		ReportsSettingsAmount = SettingsCount;
	ElsIf SelectedSettingsPage = "AppearancePage" Then
		AppearanceSettingsAmount = SettingsCount;
	ElsIf SelectedSettingsPage = "OtherSettingsPage" Then
		OtherSettingsAmount = SettingsCount;
	EndIf;
	
	UpdatePageTitle(0);
	
EndProcedure

&AtClient
Function SelectedSettings(SettingsTree)
	
	SettingsArray = New Array;
	PersonalSettingsArray = New Array;
	SettingsPresentation = New Array;
	OptionsArrayReports = New Array;
	OtherUserSettings = New Structure;
	SettingsCount = 0;
	
	For Each Setting IN SettingsTree.GetItems() Do
		
		If Setting.Check = 1 Then
			
			If Setting.Type = "PersonalSettings" Then
				PersonalSettingsArray.Add(Setting.Keys);
			ElsIf Setting.Type = "OtherUserSetting" Then
				OtherUserSettings.Insert("SettingID", Setting.RowType);
				OtherUserSettings.Insert("SettingValue", Setting.Keys);
			Else
				SettingsArray.Add(Setting.Keys);
				
				If Setting.Type = "PersonalVariant" Then
					OptionsArrayReports.Add(Setting.Keys);
				EndIf;
				
			EndIf;
			ChildCount = Setting.GetItems().Count();
			SettingsCount = SettingsCount + ?(ChildCount=0,1,ChildCount);
			
			If ChildCount = 1 Then
				
				ASubsidiaryOfSetting = Setting.GetItems()[0];
				SettingsPresentation.Add(Setting.Setting + " - " + ASubsidiaryOfSetting.Setting);
				
			ElsIf ChildCount = 0 Then
				SettingsPresentation.Add(Setting.Setting);
			EndIf;
			
		Else
			ChildSettings = Setting.GetItems();
			
			For Each ASubsidiaryOfSetting IN ChildSettings Do
				
				If ASubsidiaryOfSetting.Check = 1 Then
					SettingsArray.Add(ASubsidiaryOfSetting.Keys);
					SettingsPresentation.Add(Setting.Setting + " - " + ASubsidiaryOfSetting.Setting);
					SettingsCount = SettingsCount + 1;
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	SettingsStructure = New Structure;
	
	SettingsStructure.Insert("SettingsArray", SettingsArray);
	SettingsStructure.Insert("PersonalSettingsArray", PersonalSettingsArray);
	SettingsStructure.Insert("OtherUserSettings", OtherUserSettings);
	SettingsStructure.Insert("ReportsVariants", OptionsArrayReports);
	SettingsStructure.Insert("SettingsPresentation", SettingsPresentation);
	SettingsStructure.Insert("SettingsCount", SettingsCount);
	
	Return SettingsStructure;
	
EndFunction

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

&AtServer
Function MarkedTreeItems()
	
	ReportsSettingsTree = FormAttributeToValue("ReportsSettings");
	AppearanceTree = FormAttributeToValue("ExternalView");
	OtherSettingsTree = FormAttributeToValue("OtherSettings");
	
	MarkedReportSettings = MarkedSettings(ReportsSettingsTree);
	AppearanceMarkedSettings = MarkedSettings(AppearanceTree);
	MarkedOtherSettings = MarkedSettings(OtherSettingsTree);
	
	If AllSelectedSettings = Undefined Then
		
		AllSelectedSettings = New Structure;
		AllSelectedSettings.Insert("MarkedReportSettings", MarkedReportSettings);
		AllSelectedSettings.Insert("AppearanceMarkedSettings", AppearanceMarkedSettings);
		AllSelectedSettings.Insert("MarkedOtherSettings", MarkedOtherSettings);
		
	Else
		
		AllSelectedSettings.MarkedReportSettings = 
			MarkedAfterComparingSettings(MarkedReportSettings, ReportsSettingsTree, "ReportsSettings");
		AllSelectedSettings.AppearanceMarkedSettings = 
			MarkedAfterComparingSettings(AppearanceMarkedSettings, AppearanceTree, "ExternalView");
		AllSelectedSettings.MarkedOtherSettings = 
			MarkedAfterComparingSettings(MarkedOtherSettings, OtherSettingsTree, "OtherSettings");
		
	EndIf;
	
EndFunction

&AtServer
Function MarkedSettings(SettingsTree)
	
	ListOfMarked = New ValueList;
	FilterOfMarked = New Structure("Check", 1);
	FilterOfUndefined = New Structure("Check", 2);
	
	MarkedArray = SettingsTree.Rows.FindRows(FilterOfMarked, True);
	For Each ArrayRow IN MarkedArray Do
		ListOfMarked.Add(ArrayRow.RowType, , True);
	EndDo;
	
	ArrayOfUndefined = SettingsTree.Rows.FindRows(FilterOfUndefined, True);
	For Each ArrayRow IN ArrayOfUndefined Do
		ListOfMarked.Add(ArrayRow.RowType);
	EndDo;
	
	Return ListOfMarked;
	
EndFunction

&AtServer
Function MarkedAfterComparingSettings(MarkedSettings, SettingsTree, SettingsType)
	
	If SettingsType = "ReportsSettings" Then
		InitialListOfMarked = AllSelectedSettings.MarkedReportSettings;
	ElsIf SettingsType = "ExternalView" Then
		InitialListOfMarked = AllSelectedSettings.AppearanceMarkedSettings;
	ElsIf SettingsType = "OtherSettings" Then
		InitialListOfMarked = AllSelectedSettings.MarkedOtherSettings;
	EndIf;
	
	For Each Item IN InitialListOfMarked Do
		
		FoundSetting = MarkedSettings.FindByValue(Item.Value);
		If FoundSetting = Undefined Then
			
			FilterParameters = New Structure("RowType", Item.Value);
			SettingIsFoundInTree = SettingsTree.Rows.FindRows(FilterParameters, True);
			If SettingIsFoundInTree.Count() = 0 Then
				MarkedSettings.Add(Item.Value, , Item.Check);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return MarkedSettings;
EndFunction

&AtServer
Procedure ImportMarksValues(ValueTree, MarkedSettings, KindSettings)
	
	If MarkedSettings = Undefined Then
		Return;
	EndIf;
	MarkedCount = 0;
	
	For Each RowMarkedSettings IN MarkedSettings Do
		
		MarkedSetting = RowMarkedSettings.Value;
		
		For Each TreeRow IN ValueTree.GetItems() Do
			
			ChildItems = TreeRow.GetItems();
			
			If TreeRow.RowType = MarkedSetting Then
				
				If RowMarkedSettings.Check Then
					TreeRow.Check = 1;
					
					If ChildItems.Count() = 0 Then
						MarkedCount = MarkedCount + 1;
					EndIf;
					
				Else
					TreeRow.Check = 2;
				EndIf;
				
			Else
				
				For Each ChildItem IN ChildItems Do
					
					If ChildItem.RowType = MarkedSetting Then
						ChildItem.Check = 1;
						MarkedCount = MarkedCount + 1;
					EndIf;
					
				EndDo;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	If MarkedCount > 0 Then
		
		If KindSettings = "ReportsSettings" Then
			ReportsSettingsAmount = MarkedCount;
			Items.ReportsSettingsPage.Title = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Reports settings (%1)'"), MarkedCount);
		ElsIf KindSettings = "ExternalView" Then
			AppearanceSettingsAmount = MarkedCount;
			Items.AppearancePage.Title = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Appearance (%1)'"), MarkedCount);
		ElsIf KindSettings = "OtherSettings" Then
			OtherSettingsAmount = MarkedCount;
			Items.OtherSettingsPage.Title = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Other settings (%1)'"), MarkedCount);
		EndIf;
		
	EndIf;
	
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
