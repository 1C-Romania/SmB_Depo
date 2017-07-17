&AtServer
Var OutputToDosAndSections;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not CommonUse.OnCreateAtServer(ThisObject, Cancel, StandardProcessing) Then
		Return;
	EndIf;
	
	TaxiInterface = (ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Taxi);
	
	LaunchBackgroundJobOnServer(ExecutionAbortedOnStartup);
	
	ImportAutoUpdateSettings();
	
	Items.SetForm.Enabled = False;
	If Not ExecutionAbortedOnStartup Then
		Items.FormRefresh.Enabled  = False;
	EndIf;
	
	If Not AccessRight("SaveUserData", Metadata) Then
		Items.SetForm.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	AttachIdleHandler("Attachable_CheckJobExecution", 2);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "CurrentWorks_AutoUpdateEnabled" Then
		ImportAutoUpdateSettings();
		UpdatePeriod = AutoUpdateSettings.AutoUpdatePeriod * 60;
		AttachIdleHandler("AutomaticallyUpdateCurrentWorks", UpdatePeriod);
	ElsIf EventName = "CurrentWorks_AutoUpdateDisabled" Then
		DetachIdleHandler("AutomaticallyUpdateCurrentWorks");
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	ActionOnClosingCurrentWorksPanel();
EndProcedure

#EndRegion

#Region FormManagementItemsEventsHandlers

&AtClient
Procedure Attachable_HandleClickOnHyperlink(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ClosingAlert = New NotifyDescription("HandleClickOnHyperlinkEnd", ThisObject);
	
	FilterParameters = New Structure();
	FilterParameters.Insert("ID", Item.Name);
	ToDoParameters = WorkParameters.FindRows(FilterParameters)[0];
	
	OpenForm(ToDoParameters.Form, ToDoParameters.FormParameters, ,,,, ClosingAlert);
	
EndProcedure

&AtClient
Procedure Attachable_NavigationRefClickProcessor(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	
	ClosingAlert = New NotifyDescription("HandleClickOnHyperlinkEnd", ThisObject);
	
	FilterParameters = New Structure();
	FilterParameters.Insert("ID", URL);
	ToDoParameters = WorkParameters.FindRows(FilterParameters)[0];
	
	OpenForm(ToDoParameters.Form, ToDoParameters.FormParameters ,,,,, ClosingAlert);
	
EndProcedure

&AtClient
Procedure Attachable_ProcessPictureClick(Item)
	SwitchPicture(Item.Name);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Configure(Command)
	
	ResultHandler = New NotifyDescription("ApplyToDosPanelSettings", ThisObject);
	
	FormParameters = New Structure;
	FormParameters.Insert("CurrentWorks", CurrentWorksInStorage);
	OpenForm("DataProcessor.CurrentWorks.Form.PanelSettings", FormParameters,,,,,ResultHandler);
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	LaunchToDoListUpdate();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions of forming a list of user works.

&AtClient
Procedure AutomaticallyUpdateCurrentWorks()
	LaunchToDoListUpdate(True);
EndProcedure

&AtServer
Procedure UpdateToDoList(CurrentWorks)
	
	CurrentWorks.Sort("ThisIsSection Desc, PresentationOfSection Asc, Important Desc");
	
	SectionsWithImportantWork = New Structure;
	SavedDisplaySettings = CurrentWorksService.SavedDisplaySettings();
	If SavedDisplaySettings = Undefined Then
		JobsSectionsVisible = New Map;
		SpecifiedToDosVisibile      = New Map;
	Else
		JobsSectionsVisible = SavedDisplaySettings.SectionsVisible;
		SpecifiedToDosVisibile      = SavedDisplaySettings.WorkVisible;
	EndIf;
	CollapsedSections = CollapsedSections();
	
	CurrentSection = "";
	For Each Work IN CurrentWorks Do
		
		If Work.ThisIsSection Then
			// Reset the result visible. It is set from the to-do.
			SectionName = "CommonGroup" + Work.IDOwner;
			GroupCollapsePictureName = "Picture" + Work.IDOwner;
			If SectionName <> CurrentSection Then
				ParentItem = Items.Find(SectionName);
				If ParentItem = Undefined Then
					Continue;
				EndIf;
				ParentItem.Visible = False;
				// Reset value of the indicator of important works.
				If Items[GroupCollapsePictureName].Picture = PictureLib.RightArrowRed Then
					Items[GroupCollapsePictureName].Picture = PictureLib.RightArrow;
				EndIf;
			EndIf;
			// To-do update.
			UpdateToDo(Work, ParentItem, JobsSectionsVisible, SpecifiedToDosVisibile);
			
			// Enable indicator of important works.
			If Work.ThereIsWork
				AND Work.Important
				AND SpecifiedToDosVisibile[Work.ID] <> False Then
				SectionsWithImportantWork.Insert(Work.IDOwner, CollapsedSections[Work.IDOwner]);
			EndIf;
			
			CurrentSection = SectionName;
		Else
			// Subordinate works are created once again.
			CreateChildTree(Work);
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure UpdateToDo(Work, ToDoParent, JobsSectionsVisible, SpecifiedToDosVisibile)
	
	SectionVisibleEnabled = JobsSectionsVisible[Work.IDOwner];
	If SectionVisibleEnabled = Undefined Then
		SectionVisibleEnabled = True;
	EndIf;
	ToDosVisibleEnabled = SpecifiedToDosVisibile[Work.ID];
	If ToDosVisibleEnabled = Undefined Then
		ToDosVisibleEnabled = True;
	EndIf;
	
	Item = Items.Find(Work.ID);
	If Item = Undefined Then
		// There is no to-do in the list, it might
		// have appeared after enabling the functional option. IN this case, add it.
		CreateToDo(Work, ToDoParent, ToDosVisibleEnabled);
		FillToDoParameters(Work);
		Return;
	EndIf;
	
	ToDoTitle = Work.Presentation + ?(Work.Count <> 0," (" + Work.Count + ")", "");
	Item.Title = ToDoTitle;
	If Work.Important Then
		Item.TextColor = StyleColors.OverdueDataColor;
	EndIf;
	Item.Visible = Work.ThereIsWork AND ToDosVisibleEnabled;
	// Reset subordinate works if there are any. Their update will be further.
	Item.ExtendedTooltip.Title = "";
	
	// Set a tooltip if it is specified.
	If ValueIsFilled(Work.ToolTip) Then
		ToolTip                    = New FormattedString(Work.ToolTip);
		Item.ToolTip            = ToolTip;
		Item.ToolTipRepresentation = ToolTipRepresentation.Button;
	EndIf;
	
	// Set the visible of section.
	If Item.Visible AND SectionVisibleEnabled Then
		SectionTitle = StrReplace(ToDoParent.Name, "CommonGroup", "SectionTitle");
		ToDoParent.Visible = True;
		OutputToDosAndSections.Insert(SectionTitle);
	EndIf;
	
EndProcedure

&AtServer
Procedure GenerateToDoList(CurrentWorks)
	
	SectionsWithImportantWork = New Structure;
	SavedDisplaySettings = CurrentWorksService.SavedDisplaySettings();
	If SavedDisplaySettings = Undefined Then
		JobsSectionsVisible = New Map;
		SpecifiedToDosVisibile      = New Map;
	Else
		SavedDisplaySettings.Property("SectionsVisible", JobsSectionsVisible);
		SavedDisplaySettings.Property("WorkVisible", SpecifiedToDosVisibile);
	EndIf;
	
	CollapsedSections = CollapsedSections();
	
	CurrentWorks.Sort("ThisIsSection Desc, PresentationOfSection Asc, Important Desc");
	
	// If a user did not set sections position in
	// the works list, then they are sorted according to an order defined in the OnDefineCommandInterfaceSectionsOrder procedure.
	If SavedDisplaySettings = Undefined Then
		SetInitialSectionsOrder(CurrentWorks);
	EndIf;
	
	CurrentGroup = "";
	CurrentCommonGroup = "";
	For Each Work IN CurrentWorks Do
		
		If Work.ThisIsSection Then
			
			// Create a common section group.
			CommonGroupName = "CommonGroup" + Work.IDOwner;
			If CurrentCommonGroup <> CommonGroupName Then
				
				SectionCollapsed = CollapsedSections[Work.IDOwner];
				If SectionCollapsed = Undefined Then
					If SavedDisplaySettings = Undefined
						AND CurrentCommonGroup <> "" Then
						// The first group does not collapse.
						CollapsedSections.Insert(Work.IDOwner, True);
						SectionCollapsed = True;
					Else
						CollapsedSections.Insert(Work.IDOwner, False);
					EndIf;
					
				EndIf;
				
				SectionVisibleEnabled = JobsSectionsVisible[Work.IDOwner];
				If SectionVisibleEnabled = Undefined Then
					SectionVisibleEnabled = True;
				EndIf;
				
				// Create a common group containing all items for displaying the section and the works included in it.
				CommonGroup = Group(CommonGroupName,, "CommonGroup");
				CommonGroup.Visible = False;
				// Create a group of section title.
				TitleGroupName = "SectionTitle" + Work.IDOwner;
				GroupHeader    = Group(TitleGroupName, CommonGroup, "SectionTitle");
				// Create a section title.
				CreateTitle(Work, GroupHeader, SectionCollapsed);
				
				CurrentCommonGroup = CommonGroupName;
			EndIf;
			
			// Create works group.
			GroupName = "Group" + Work.IDOwner;
			If CurrentGroup <> GroupName Then
				CurrentGroup = GroupName;
				NewGroup        = Group(GroupName, CommonGroup);
				If TaxiInterface Then
					NewGroup.Representation = UsualGroupRepresentation.StrongSeparation;
				EndIf;
				
				If SectionCollapsed = True Then
					NewGroup.Visible = False;
				EndIf;
			EndIf;
			
			ToDosVisibleEnabled = SpecifiedToDosVisibile[Work.ID];
			If ToDosVisibleEnabled = Undefined Then
				ToDosVisibleEnabled = True;
			EndIf;
			
			If SectionVisibleEnabled AND ToDosVisibleEnabled AND Work.ThereIsWork Then
				OutputToDosAndSections.Insert(TitleGroupName);
				CommonGroup.Visible = True;
			EndIf;
			
			CreateToDo(Work, NewGroup, ToDosVisibleEnabled);
			
			// Enable indicator of important works.
			If Work.ThereIsWork
				AND Work.Important
				AND ToDosVisibleEnabled Then
				
				SectionsWithImportantWork.Insert(Work.IDOwner, CollapsedSections[Work.IDOwner]);
			EndIf;
			
		Else
			CreateChildTree(Work);
		EndIf;
		
		FillToDoParameters(Work);
		
	EndDo;
	
	SaveCollapsedSections(CollapsedSections);
	
EndProcedure

&AtServer
Procedure OrderToDoList()
	
	SavedDisplaySettings = CurrentWorksService.SavedDisplaySettings();
	If SavedDisplaySettings = Undefined Then
		Return;
	EndIf;
	
	SavedToDosTree = SavedDisplaySettings.WorkTree;
	IsFirstSection = True;
	For Each RowSection IN SavedToDosTree.Rows Do
		If Not IsFirstSection Then
			TransferSection(RowSection);
		EndIf;
		IsFirstSection = False;
		IsFirstToDo   = True;
		For Each RowToDo IN RowSection.Rows Do
			If Not IsFirstToDo Then
				TransferToDo(RowToDo);
			EndIf;
			IsFirstToDo = False;
		EndDo;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Background update

&AtServer
Procedure LaunchBackgroundJobOnServer(ExecutionBroken = False)
	
	If ExclusiveMode() Then
		ExecutionBroken = True;
		Return;
	EndIf;
	
	LongActions.CancelJobExecution(JobID);
	JobID = Undefined;
	
	If CurrentWorksInStorage = "" Then
		CurrentWorksInStorage = PutToTempStorage(Undefined, UUID);
	EndIf;
	
	If CommonUseClientServer.DebugMode() Then
		CurrentWorksService.UserToDoList(CurrentWorksInStorage);
	Else
		ProcedureParameters = New Array;
		ProcedureParameters.Add(CurrentWorksInStorage);
		ProcedureParameters.Add(SessionParameters.ClientParametersOnServer);
		
		JobParameters = New Array;
		JobParameters.Add("CurrentWorksService.UserToDoList");
		JobParameters.Add(ProcedureParameters);
		
		JobDescription = NStr("en='Update current to-dos';ru='Обновление списка текущих дел'");
		
		Task = BackgroundJobs.Execute("WorkInSafeMode.ExecuteConfigurationMethod", JobParameters,, JobDescription);
		
		JobID = Task.UUID;
	EndIf;
	
EndProcedure

&AtServer
Procedure ImportCurrentWorks()
	
	CurrentWorks = GetFromTempStorage(CurrentWorksInStorage);
	OutputToDosAndSections = New Structure;
	If OnlyWorkUpdate Then
		FillCollapsedGroups();
		UpdateToDoList(CurrentWorks);
	Else
		GenerateToDoList(CurrentWorks);
	EndIf;
	
	// If there are collapsed sections with important works - they are highlighted.
	SetSectionsPictureWithImportantToDos();
	
	If OutputToDosAndSections.Count() = 0 Then
		Items.NoCurrentWorksPage.Visible = True;
	Else
		Items.NoCurrentWorksPage.Visible = False;
		// If works are output only from one section - hide its title.
		If OutputToDosAndSections.Count() = 1 Then
			DisplaySection = False;
		Else
			DisplaySection = True;
		EndIf;
		For Each SectionTitleItem IN OutputToDosAndSections Do
			SectionTitle = SectionTitleItem.Key;
			Items[SectionTitle].Visible = DisplaySection;
			
			If Not DisplaySection Then
				ToDosGroupName = StrReplace(SectionTitle, "SectionTitle", "Group");
				Items[ToDosGroupName].Visible = True;
			EndIf;
		EndDo;
	EndIf;
	
	OrderToDoList();
	
EndProcedure

&AtServer
Function JobCompleted(JobID)
	
	If CommonUseClientServer.DebugMode() Then
		JobCompleteSuccessfully = True;
	Else
		JobCompleteSuccessfully = LongActions.JobCompleted(JobID);
	EndIf;
	
	If JobCompleteSuccessfully = True Then
		ImportCurrentWorks();
	EndIf;
	Return JobCompleteSuccessfully;
	
EndFunction

&AtClient
Procedure Attachable_CheckJobExecution()
	
	JobCompleteSuccessfully = False;
	Try
		If JobCompleted(JobID) Then
			JobCompleteSuccessfully = True;
			Items.WorkPage.Visible = True;
			Items.PageLongOperation.Visible = False;
			Items.SetForm.Enabled = True;
			Items.FormRefresh.Enabled  = True;
			DetachIdleHandler("Attachable_CheckJobExecution");
		EndIf;
	Except
		DetachIdleHandler("Attachable_CheckJobExecution");
		Items.WorkPage.Visible = True;
		Items.PageLongOperation.Visible = False;
		Items.FormRefresh.Enabled = True;
		If Not ExecutionAbortedOnStartup Then
			Raise;
		EndIf;
	EndTry;
	
	If JobCompleteSuccessfully Then
		If AutoUpdateSettings.Property("AutoupdateOn")
			AND AutoUpdateSettings.AutoupdateOn Then
			UpdatePeriod = AutoUpdateSettings.AutoUpdatePeriod * 60;
			AttachIdleHandler("AutomaticallyUpdateCurrentWorks", UpdatePeriod);
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

&AtClient
Procedure LaunchToDoListUpdate(AutoUpdate = False, RefreshDiscreetly = False)
	
	// If the update is initiated manually - handler of the automatic works update is disabled.
	// It will be connected once again after finishing the manual update.
	If Not AutoUpdate Then
		DetachIdleHandler("AutomaticallyUpdateCurrentWorks");
	EndIf;
	
	OnlyWorkUpdate = Not ExecutionAbortedOnStartup;
	
	ExecutionBroken = False;
	LaunchBackgroundJobOnServer(ExecutionBroken);
	If ExecutionBroken Then
		Return;
	EndIf;
	ExecutionAbortedOnStartup = False;
	
	If Not RefreshDiscreetly Then
		Items.WorkPage.Visible = False;
		Items.PageLongOperation.Visible = True;
		Items.SetForm.Enabled = False;
		Items.FormRefresh.Enabled  = False;
		Items.NoCurrentWorksPage.Visible = False;
	EndIf;
	AttachIdleHandler("Attachable_CheckJobExecution", 2);
	
EndProcedure

&AtServer
Function Group(GroupName, Parent = Undefined, GroupType = "")
	
	If Parent = Undefined Then
		Parent = Items.WorkPage;
	EndIf;
	
	NewGroup = Items.Add(GroupName, Type("FormGroup"), Parent);
	NewGroup.Type = FormGroupType.UsualGroup;
	NewGroup.Representation = UsualGroupRepresentation.None;
	
	If GroupType = "SectionTitle" Then
		NewGroup.Group = ChildFormItemsGroup.Horizontal;
	Else
		NewGroup.Group = ChildFormItemsGroup.Vertical;
	EndIf;
	
	NewGroup.ShowTitle = False;
	
	Return NewGroup;
	
EndFunction

&AtServer
Procedure CreateToDo(Work, Group, ToDosVisibleEnabled)
	
	ToDoTitle = Work.Presentation + ?(Work.Count <> 0," (" + Work.Count + ")", "");
	
	Item = Items.Add(Work.ID, Type("FormDecoration"), Group);
	Item.Type = FormDecorationType.Label;
	Item.HorizontalAlign = ItemHorizontalLocation.Left;
	Item.Title = ToDoTitle;
	Item.Visible = (ToDosVisibleEnabled AND Work.ThereIsWork);
	Item.Hyperlink = ValueIsFilled(Work.Form);
	Item.SetAction("Click", "Attachable_HandleClickOnHyperlink");
	
	If Work.Important Then
		Item.TextColor = StyleColors.OverdueDataColor;
	EndIf;
	
	If ValueIsFilled(Work.ToolTip) Then
		ToolTip                    = New FormattedString(Work.ToolTip);
		Item.ToolTip            = ToolTip;
		Item.ToolTipRepresentation = ToolTipRepresentation.Button;
	EndIf;
	
EndProcedure

&AtServer
Procedure CreateTitle(Work, Group, SectionCollapsed)
	
	// Create a picture of collapsing/expanding a section.
	Item = Items.Add("Picture" + Work.IDOwner, Type("FormDecoration"), Group);
	Item.Type = FormDecorationType.Picture;
	Item.Hyperlink = True;
	
	If SectionCollapsed = True Then
		If Work.ThereIsWork AND Work.Important Then
			Item.Picture = PictureLib.RightArrowRed;
		Else
			Item.Picture = PictureLib.RightArrow;
		EndIf;
	Else
		Item.Picture = PictureLib.DownArrow;
	EndIf;
	
	Item.PictureSize = PictureSize.AutoSize;
	Item.Width      = 2;
	Item.Height      = 1;
	Item.SetAction("Click", "Attachable_ProcessClickOnPicture");
	Item.ToolTip = NStr("en='Expand/collapse section';ru='Развернуть/свернуть раздел'");
	
	// Create a section title.
	Item = Items.Add("Title" + Work.IDOwner, Type("FormDecoration"), Group);
	Item.Type = FormDecorationType.Label;
	Item.HorizontalAlign = ItemHorizontalLocation.Left;
	Item.Title  = Work.PresentationOfSection;
	If TaxiInterface Then
		Item.Font = New Font("DefaultGUIFont", 12);
	Else
		Item.Font = New Font(,, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure CreateChildTree(Work)
	
	If Not Work.ThereIsWork Then
		Return;
	EndIf;
	
	ItemToDoOwner = Items.Find(Work.IDOwner);
	If ItemToDoOwner = Undefined Then
		Return;
	EndIf;
	ItemToDoOwner.ToolTipRepresentation           = ToolTipRepresentation.ShowBottom;
	ItemToDoOwner.ExtendedTooltip.Font     = New Font(, 8);
	ItemToDoOwner.ExtendedTooltip.HorizontalStretch = True;
	
	SubordinateJobTitle = SubordinateJobTitle(ItemToDoOwner.ExtendedTooltip.Title, Work);
	
	ItemToDoOwner.ExtendedTooltip.Title = SubordinateJobTitle;
	ItemToDoOwner.ExtendedTooltip.SetAction("URLProcessing", "Attachable_NavigationRefClickProcessor");
	
	// Enable indicator of important works.
	If Work.ThereIsWork
		AND Work.Important
		AND ItemToDoOwner.Visible Then
		
		SectionID = StrReplace(ItemToDoOwner.Parent.Name, "Group", "");
		SectionsWithImportantWork.Insert(SectionID, Not ItemToDoOwner.Parent.Visible);
	EndIf;
	
EndProcedure

&AtServer
Function SubordinateJobTitle(CurrentTitle, Work)
	
	CurrentTitleEmpty = Not ValueIsFilled(CurrentTitle);
	ToDoTitle = Work.Presentation + ?(Work.Count <> 0," (" + Work.Count + ")", "");
	ToDoTitleRow    = ToDoTitle;
	If Work.Important Then
		ToDoColor        = StyleColors.OverdueDataColor;
	Else
		ToDoColor        = StyleColors.CaseTitleColor;
	EndIf;
	
	FormattedStringBreak = New FormattedString(Chars.LF);
	GeneratedRowIndent  = New FormattedString(Chars.NBSp+Chars.NBSp+Chars.NBSp);
	
	If Work.Important Then
		If ValueIsFilled(Work.Form) Then
			FormattedToDoTitleRow = New FormattedString(
			                                           ToDoTitleRow,,
			                                           ToDoColor,,
			                                           Work.ID);
		Else
			FormattedToDoTitleRow = New FormattedString(
			                                           ToDoTitleRow,,
			                                           ToDoColor);
		EndIf;
	Else
		If ValueIsFilled(Work.Form) Then
			FormattedToDoTitleRow = New FormattedString(
			                                           ToDoTitleRow,,,,
			                                           Work.ID);
		Else
			FormattedToDoTitleRow = New FormattedString(ToDoTitleRow,,ToDoColor);
		EndIf;
	EndIf;
	
	If CurrentTitleEmpty Then
		Return New FormattedString(GeneratedRowIndent, FormattedToDoTitleRow);
	Else
		Return New FormattedString(CurrentTitle, FormattedStringBreak, GeneratedRowIndent, FormattedToDoTitleRow);
	EndIf;
	
EndFunction

&AtServer
Procedure FillToDoParameters(Work)
	
	RowToDo = WorkParameters.Add();
	RowToDo.ID = Work.ID;
	RowToDo.Form = Work.Form;
	RowToDo.FormParameters = Work.FormParameters;
	
EndProcedure

&AtServer
Procedure ImportAutoUpdateSettings()
	
	AutoUpdateSettings = CommonUse.CommonSettingsStorageImport("CurrentWorks", "AutoUpdateSettings");
	
	If AutoUpdateSettings = Undefined Then
		AutoUpdateSettings = New Structure;
	EndIf;
	
EndProcedure

&AtClient
Procedure ApplyToDosPanelSettings(ApplySettings, AdditionalParameters) Export
	If ApplySettings = True Then
		LaunchToDoListUpdate();
	EndIf;
EndProcedure

&AtServer
Procedure TransferSection(RowSection)
	
	ItemName = "CommonGroup" + RowSection.ID;
	ItemToMove = Items.Find(ItemName);
	If ItemToMove = Undefined Then
		Return;
	EndIf;
	Items.Move(ItemToMove, ItemToMove.Parent);
	
EndProcedure

&AtServer
Procedure TransferToDo(RowToDo)
	
	ItemToMove = Items.Find(RowToDo.ID);
	If ItemToMove = Undefined Then
		Return;
	EndIf;
	Items.Move(ItemToMove, ItemToMove.Parent);
	
EndProcedure

&AtServer
Procedure SaveCollapsedSections(CollapsedSections)
	
	DisplaySettings = CommonUse.CommonSettingsStorageImport("CurrentWorks", "DisplaySettings");
	
	If TypeOf(DisplaySettings) <> Type("Structure") Then
		DisplaySettings = New Structure;
	EndIf;
	
	DisplaySettings.Insert("CollapsedSections", CollapsedSections);
	CommonUse.CommonSettingsStorageSave("CurrentWorks", "DisplaySettings", DisplaySettings);
	
EndProcedure

&AtServer
Function CollapsedSections()
	
	DisplaySettings = CommonUse.CommonSettingsStorageImport("CurrentWorks", "DisplaySettings");
	If DisplaySettings <> Undefined AND DisplaySettings.Property("CollapsedSections") Then
		CollapsedSections = DisplaySettings.CollapsedSections;
	Else
		CollapsedSections = New Map;
	EndIf;
	
	Return CollapsedSections;
	
EndFunction

&AtServer
Procedure ActionOnClosingCurrentWorksPanel()
	
	FillCollapsedGroups();
	LongActions.CancelJobExecution(JobID);
	
EndProcedure

&AtServer
Procedure FillCollapsedGroups()
	
	DisplaySettings = CommonUse.CommonSettingsStorageImport("CurrentWorks", "DisplaySettings");
	If DisplaySettings = Undefined Or Not DisplaySettings.Property("CollapsedSections") Then
		Return;
	EndIf;
	
	CollapsedSections = New Map;
	For Each MapRow IN DisplaySettings.CollapsedSections Do
		
		FormItem = Items.Find("Picture" + MapRow.Key);
		If FormItem = Undefined Then
			Continue;
		EndIf;
		
		If FormItem.Picture = PictureLib.RightArrow
			Or FormItem.Picture = PictureLib.RightArrowRed Then
			CollapsedSections.Insert(MapRow.Key, True);
		Else
			CollapsedSections.Insert(MapRow.Key, False);
		EndIf;
		
	EndDo;
	
	If CollapsedSections.Count() = 0 Then
		Return;
	EndIf;
	
	SaveCollapsedSections(CollapsedSections);
	
EndProcedure

&AtServer
Procedure SetInitialSectionsOrder(CurrentWorks)
	
	CommandInterfaceSectionsOrder = New Array;
	CurrentWorksOverridable.AtDeterminingCommandInterfaceSectionsOrder(CommandInterfaceSectionsOrder);
	
	IndexOf = 0;
	For Each CommandInterfaceSection IN CommandInterfaceSectionsOrder Do
		CommandInterfaceSection = StrReplace(CommandInterfaceSection.FullName(), ".", "");
		RowFilter = New Structure;
		RowFilter.Insert("IDOwner", CommandInterfaceSection);
		
		FoundStrings = CurrentWorks.FindRows(RowFilter);
		For Each FoundString IN FoundStrings Do
			RowIndexInTable = CurrentWorks.IndexOf(FoundString);
			If RowIndexInTable = IndexOf Then
				IndexOf = IndexOf + 1;
				Continue;
			EndIf;
			
			CurrentWorks.Move(RowIndexInTable, (IndexOf - RowIndexInTable));
			IndexOf = IndexOf + 1;
		EndDo;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SwitchPicture(ItemName)
	
	SectionGroupName = StrReplace(ItemName, "Picture", "");
	Item = Items[ItemName];
	
	If Item.Picture = PictureLib.DownArrow Then
		If SectionsWithImportantWork.Property(SectionGroupName) Then
			Item.Picture = PictureLib.RightArrowRed;
		Else
			Item.Picture = PictureLib.RightArrow;
		EndIf;
		Items["Group" + SectionGroupName].Visible = False;
	Else
		Item.Picture = PictureLib.DownArrow;
		Items["Group" + SectionGroupName].Visible = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetSectionsPictureWithImportantToDos()
	
	For Each SectionWithImportantToDos IN SectionsWithImportantWork Do
		If SectionWithImportantToDos.Value <> True Then
			Continue; // Section is not collapsed
		EndIf;
		IconName = "Picture" + SectionWithImportantToDos.Key;
		ItemPicture = Items[IconName];
		ItemPicture.Picture = PictureLib.RightArrowRed;
	EndDo;
	
EndProcedure

&AtClient
Procedure HandleClickOnHyperlinkEnd(Result, AdditionalParameters) Export
	LaunchToDoListUpdate(, True);
EndProcedure

#EndRegion














