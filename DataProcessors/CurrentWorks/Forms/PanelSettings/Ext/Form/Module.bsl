#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	DisplaySettings = CurrentWorksService.SavedDisplaySettings();
	FillToDosTree(DisplaySettings);
	SetSectionsOrder(DisplaySettings);
	
	AutoUpdateSettings = CommonUse.CommonSettingsStorageImport("CurrentWorks", "AutoUpdateSettings");
	If TypeOf(AutoUpdateSettings) = Type("Structure") Then
		AutoUpdateSettings.Property("AutoupdateOn", UseAutoupdate);
		AutoUpdateSettings.Property("AutoUpdatePeriod", UpdatePeriod);
	Else
		UpdatePeriod = 5;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormManagementItemsEventsHandlers

&AtClient
Procedure DisplayedWorkTreeOnChange(Item)
	
	Modified = True;
	If Item.CurrentData.ThisIsSection Then
		For Each Work IN Item.CurrentData.GetItems() Do
			Work.Check = Item.CurrentData.Check;
		EndDo;
	ElsIf Item.CurrentData.Check Then
		Item.CurrentData.GetParent().Check = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OKButton(Command)
	
	SaveSettings();
	
	If AutoupdateOn Then
		Notify("CurrentWorks_AutoUpdateEnabled");
	ElsIf AutoupdateOff Then
		Notify("CurrentWorks_AutoUpdateDisabled");
	EndIf;
	
	Close(Modified);
	
EndProcedure

&AtClient
Procedure ButtonCancel(Command)
	Close(False);
EndProcedure

&AtClient
Procedure MoveUp(Command)
	
	Modified = True;
	// Transfer the current row 1 position higher.
	CurrentTreeRow = Items.DisplayedWorkTree.CurrentData;
	
	If CurrentTreeRow.ThisIsSection Then
		TreeSections = DisplayedWorkTree.GetItems();
	Else
		ToDoParent = CurrentTreeRow.GetParent();
		TreeSections= ToDoParent.GetItems();
	EndIf;
	
	IndexOfCurrentRow = CurrentTreeRow.IndexOf;
	If IndexOfCurrentRow = 0 Then
		Return; // The current row at the top of the list, do not transfer.
	EndIf;
	TreeSections.Move(CurrentTreeRow.IndexOf, -1);
	CurrentTreeRow.IndexOf = IndexOfCurrentRow - 1;
	// Change the index of previous row.
	PreviousRow = TreeSections.Get(IndexOfCurrentRow);
	PreviousRow.IndexOf = IndexOfCurrentRow;
	
EndProcedure

&AtClient
Procedure MoveDown(Command)
	
	Modified = True;
	// Transfer the current row 1 position lower.
	CurrentTreeRow = Items.DisplayedWorkTree.CurrentData;
	
	If CurrentTreeRow.ThisIsSection Then
		TreeSections = DisplayedWorkTree.GetItems();
	Else
		ToDoParent = CurrentTreeRow.GetParent();
		TreeSections= ToDoParent.GetItems();
	EndIf;
	
	IndexOfCurrentRow = CurrentTreeRow.IndexOf;
	If IndexOfCurrentRow = (TreeSections.Count() -1) Then
		Return; // The current row at the bottom of the list, do not transfer.
	EndIf;
	TreeSections.Move(CurrentTreeRow.IndexOf, 1);
	CurrentTreeRow.IndexOf = IndexOfCurrentRow + 1;
	// Change the index of current row.
	NextString = TreeSections.Get(IndexOfCurrentRow);
	NextString.IndexOf = IndexOfCurrentRow;
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	Modified = True;
	For Each SectionRow IN DisplayedWorkTree.GetItems() Do
		SectionRow.Check = False;
		For Each ToDoRow IN SectionRow.GetItems() Do
			ToDoRow.Check = False;
		EndDo;
	EndDo;
	
EndProcedure

&AtClient
Procedure CheckAll(Command)
	
	Modified = True;
	For Each SectionRow IN DisplayedWorkTree.GetItems() Do
		SectionRow.Check = True;
		For Each ToDoRow IN SectionRow.GetItems() Do
			ToDoRow.Check = True;
		EndDo;
	EndDo;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillToDosTree(DisplaySettings)
	
	CurrentWorks   = GetFromTempStorage(Parameters.CurrentWorks);
	WorkTree     = FormAttributeToValue("DisplayedWorkTree");
	CurrentSection = "";
	IndexOf        = 0;
	ToDoIndex    = 0;
	
	If DisplaySettings = Undefined Then
		SetInitialSectionsOrder(CurrentWorks);
	EndIf;
	
	For Each Work IN CurrentWorks Do
		
		If Work.ThisIsSection
			AND CurrentSection <> Work.IDOwner Then
			TreeRow = WorkTree.Rows.Add();
			TreeRow.Presentation = Work.PresentationOfSection;
			TreeRow.ID = Work.IDOwner;
			TreeRow.ThisIsSection     = True;
			TreeRow.Check       = True;
			TreeRow.IndexOf        = IndexOf;
			
			If DisplaySettings <> Undefined Then
				SectionVisible = DisplaySettings.SectionsVisible[TreeRow.ID];
				If SectionVisible <> Undefined Then
					TreeRow.Check = SectionVisible;
				EndIf;
			EndIf;
			IndexOf     = IndexOf + 1;
			ToDoIndex = 0;
			
		ElsIf Not Work.ThisIsSection Then
			ToDoParent = WorkTree.Rows.Find(Work.IDOwner, "ID", True);
			If ToDoParent = Undefined Then
				Continue;
			EndIf;
			ToDoParent.WorkDetails = ToDoParent.WorkDetails + ?(IsBlankString(ToDoParent.WorkDetails), "", Chars.LF) + Work.Presentation;
			Continue;
		EndIf;
		
		ToDoRow = TreeRow.Rows.Add();
		ToDoRow.Presentation = Work.Presentation;
		ToDoRow.ID = Work.ID;
		ToDoRow.ThisIsSection     = False;
		ToDoRow.Check       = True;
		ToDoRow.IndexOf        = ToDoIndex;
		
		If DisplaySettings <> Undefined Then
			ToDoVisible = DisplaySettings.WorkVisible[ToDoRow.ID];
			If ToDoVisible <> Undefined Then
				ToDoRow.Check = ToDoVisible;
			EndIf;
		EndIf;
		ToDoIndex = ToDoIndex + 1;
		
		CurrentSection = Work.IDOwner;
		
	EndDo;
	
	ValueToFormAttribute(WorkTree, "DisplayedWorkTree");
	
EndProcedure

&AtServer
Procedure SaveSettings()
	
	DisplayOldSettings = CommonUse.CommonSettingsStorageImport("CurrentWorks", "DisplaySettings");
	CollapsedSections = Undefined;
	If TypeOf(DisplayOldSettings) = Type("Structure") Then
		DisplayOldSettings.Property("CollapsedSections", CollapsedSections);
	EndIf;
	
	If CollapsedSections = Undefined Then
		CollapsedSections = New Map;
	EndIf;
	
	// Save location and visible of sections.
	SectionsVisible = New Map;
	WorkVisible      = New Map;
	
	WorkTree = FormAttributeToValue("DisplayedWorkTree");
	For Each Section IN WorkTree.Rows Do
		SectionsVisible.Insert(Section.ID, Section.Mark);
		For Each Work IN Section.Rows Do
			WorkVisible.Insert(Work.ID, Work.Mark);
		EndDo;
	EndDo;
	
	Result = New Structure;
	Result.Insert("WorkTree", WorkTree);
	Result.Insert("SectionsVisible", SectionsVisible);
	Result.Insert("WorkVisible", WorkVisible);
	Result.Insert("CollapsedSections", CollapsedSections);
	
	CommonUse.CommonSettingsStorageSave("CurrentWorks", "DisplaySettings", Result);
	
	// Save settings of the update.
	AutoUpdateSettings = CommonUse.CommonSettingsStorageImport("CurrentWorks", "AutoUpdateSettings");
	
	If AutoUpdateSettings = Undefined Then
		AutoUpdateSettings = New Structure;
	Else
		If UseAutoupdate Then
			AutoupdateOn = AutoUpdateSettings.AutoupdateOn <> UseAutoupdate;
		Else
			AutoupdateOff = AutoUpdateSettings.AutoupdateOn <> UseAutoupdate;
		EndIf;
	EndIf;
	
	AutoUpdateSettings.Insert("AutoupdateOn", UseAutoupdate);
	AutoUpdateSettings.Insert("AutoUpdatePeriod", UpdatePeriod);
	
	CommonUse.CommonSettingsStorageSave("CurrentWorks", "AutoUpdateSettings", AutoUpdateSettings);
	
EndProcedure

&AtServer
Procedure SetSectionsOrder(DisplaySettings)
	
	If DisplaySettings = Undefined Then
		Return;
	EndIf;
	
	WorkTree = FormAttributeToValue("DisplayedWorkTree");
	Sections   = WorkTree.Rows;
	SavedToDosTree = DisplaySettings.WorkTree;
	For Each SectionRow IN Sections Do
		SavedSection = SavedToDosTree.Rows.Find(SectionRow.ID, "ID");
		If SavedSection = Undefined Then
			Continue;
		EndIf;
		SectionRow.IndexOf = SavedSection.IndexOf;
		Works = SectionRow.Rows;
		LastToDoIndex = Works.Count() - 1;
		For Each RowToDo IN Works Do
			SavedToDo = SavedSection.Rows.Find(RowToDo.ID, "ID");
			If SavedToDo = Undefined Then
				RowToDo.IndexOf = LastToDoIndex;
				LastToDoIndex = LastToDoIndex - 1;
				Continue;
			EndIf;
			RowToDo.IndexOf = SavedToDo.IndexOf;
		EndDo;
		Works.Sort("Code asc");
	EndDo;
	
	Sections.Sort("Code asc");
	ValueToFormAttribute(WorkTree, "DisplayedWorkTree");
	
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

#EndRegion