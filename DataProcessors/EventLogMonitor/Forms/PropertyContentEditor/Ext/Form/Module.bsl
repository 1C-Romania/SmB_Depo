
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ListToEdit = Parameters.ListToEdit;
	ParametersToSelect = Parameters.ParametersToSelect;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetEditorParameters(ListToEdit, ParametersToSelect);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure CheckOnChange(Item)
	CheckTreeItem(Items.List.CurrentData, Items.List.CurrentData.Check);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ChooseFilterContent(Command)
	
	Notify("EventLogMonitorFilterItemValueChoice",
	           GetEditedList(),
	           FormOwner);
	Close();
	
EndProcedure

&AtClient
Procedure CheckAllFlags()
	SetupOfMarks(True);
EndProcedure

&AtClient
Procedure UnmarkAll()
	SetupOfMarks(False);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure SetEditorParameters(ListToEdit, ParametersToSelect)
	FilterParameterStructure = GetEventLogFilterValuesByColumn(ParametersToSelect);
	FilterValues = FilterParameterStructure[ParametersToSelect];
	// Get presentations list of the events.
	If ParametersToSelect = "Event" Or ParametersToSelect = "Event" Then
		
		For Each MapItem IN FilterValues Do
			EventsPresentationString = EventsPresentation.Add();
			EventsPresentationString.Presentation = MapItem.Value;
		EndDo;
		
	EndIf;
	
	If TypeOf(FilterValues) = Type("Array") Then
		ListItems = List.GetItems();
		For Each ArrayElement IN FilterValues Do
			NewItem = ListItems.Add();
			NewItem.Check = False;
			NewItem.Value = ArrayElement;
			NewItem.Presentation = ArrayElement;
		EndDo;
	ElsIf TypeOf(FilterValues) = Type("Map") Then
		
		If ParametersToSelect = "Event" Or ParametersToSelect = "Event" Or
			 ParametersToSelect = "Metadata" Or ParametersToSelect = "Metadata" Then 
			// Ship like a tree
			For Each MapItem IN FilterValues Do
				EventsFilterParameters = New Structure("Presentation", MapItem.Value);
				
				If MapItem.Key = MapItem.Value
					AND EventsPresentation.FindRows(EventsFilterParameters).Count() > 1 Then
					UserEvents.Add(MapItem.Key, MapItem.Value);
					Continue;
				EndIf;
				
				NewItem = GetTreeBranch(MapItem.Value);
				NewItem.Check = False;
				If IsBlankString(NewItem.Value) Then
					NewItem.Value = MapItem.Key;
				Else
					NewItem.Value = NewItem.Value + Chars.LF + MapItem.Key;
				EndIf;
				NewItem.FullPresentation = MapItem.Value;
			EndDo;
			
		Else 
			// Ship as flat list
			ListItems = List.GetItems();
			For Each MapItem IN FilterValues Do
				NewItem = ListItems.Add();
				NewItem.Check = False;
				NewItem.Value = MapItem.Key;
				
				If (ParametersToSelect = "User" Or ParametersToSelect = "User") Then
					// For users the name serves as the key.
					NewItem.Value = MapItem.Value;
					NewItem.Presentation = MapItem.Value;
					NewItem.FullPresentation = MapItem.Value;
					
					If NewItem.Value = "" Then
						// Case for the default user.
						NewItem.Value = "";
						NewItem.FullPresentation = UnspecifiedUserFullName();
						NewItem.Presentation = UnspecifiedUserFullName();
					Else
						// Case for the service user.
						PresentationOfServiceUser = FullNameOfServiceUser(MapItem.Key);
						If Not IsBlankString(PresentationOfServiceUser) Then
							
							NewItem.FullPresentation = PresentationOfServiceUser;
							NewItem.Presentation = PresentationOfServiceUser;
							
						EndIf;
					EndIf;
					
				Else
					NewItem.Presentation = MapItem.Value;
					NewItem.FullPresentation = MapItem.Value;
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
	// Mark the tree items if they have match in the ListToEdit.
	CheckFoundItems(List.GetItems(), ListToEdit);
	
	// Check the list for the existence of subordinated
	// items if they are not, transfer EC to the List mode.
	IsTree = False;
	For Each TreeItem IN List.GetItems() Do
		If TreeItem.GetItems().Count() > 0 Then 
			IsTree = True;
			Break;
		EndIf;
	EndDo;
	If Not IsTree Then
		Items.List.Representation = TableRepresentation.List;
	EndIf;
	
	PerformTreeSorting();
	
EndProcedure

&AtClient
Function GetEditedList()
	
	ListToEdit = New ValueList;
	
	ListToEdit.Clear();
	HasUnmarked = False;
	GetSubtreeList(ListToEdit, List.GetItems(), HasUnmarked);
	AddUserEvents();
	
	Return ListToEdit;
	
EndFunction

&AtClient
Procedure AddUserEvents()
	
	For Each Event IN UserEvents Do
		ListToEdit.Add(Event.Value, Event.Presentation);
	EndDo;
	
EndProcedure

&AtClient
Function GetTreeBranch(Presentation)
	PathStrings = SortStringByPoints(Presentation);
	If PathStrings.Count() = 1 Then
		TreeItems = List.GetItems();
		BranchName = PathStrings[0];
	Else
		// Collect the path to the parent branch of the path fragments.
		ParentPathPresentation = "";
		For Ct = 0 To PathStrings.Count() - 2 Do
			If Not IsBlankString(ParentPathPresentation) Then
				ParentPathPresentation = ParentPathPresentation + ".";
			EndIf;
			ParentPathPresentation = ParentPathPresentation + PathStrings[Ct];
		EndDo;
		TreeItems = GetTreeBranch(ParentPathPresentation).GetItems();
		BranchName = PathStrings[PathStrings.Count() - 1];
	EndIf;
	
	For Each TreeItem IN TreeItems Do
		If TreeItem.Presentation = BranchName Then
			Return TreeItem;
		EndIf;
	EndDo;
	// Did not find, have to create.
	TreeItem = TreeItems.Add();
	TreeItem.Presentation = BranchName;
	TreeItem.Check = False;
	Return TreeItem;
EndFunction

// Function parses the string to the array of strings using the dot as a delimiter.
&AtClient
Function SortStringByPoints(Val Presentation)
	Fragments = New Array;
	While True Do
		Presentation = TrimAll(Presentation);
		DotPosition = Find(Presentation, ".");
		If DotPosition > 0 Then
			Fragment = TrimAll(Left(Presentation, DotPosition - 1));
			Fragments.Add(Fragment);
			Presentation = Mid(Presentation, DotPosition + 1);
		Else
			Fragments.Add(TrimAll(Presentation));
			Break;
		EndIf;
	EndDo;
	Return Fragments;
EndFunction

&AtServer
Function GetEventLogFilterValuesByColumn(ParametersToSelect)
	Return GetEventLogFilterValues(ParametersToSelect);
EndFunction

&AtClient
Procedure GetSubtreeList(ListToEdit, TreeItems, HasUnmarked)
	For Each TreeItem IN TreeItems Do
		If TreeItem.GetItems().Count() <> 0 Then
			GetSubtreeList(ListToEdit, TreeItem.GetItems(), HasUnmarked);
		Else
			If TreeItem.Check Then
				NewListItem = ListToEdit.Add();
				NewListItem.Value      = TreeItem.Value;
				NewListItem.Presentation = TreeItem.FullPresentation;
			Else
				HasUnmarked = True;
			EndIf;
		EndIf;
	EndDo;
EndProcedure

&AtClient
Procedure CheckFoundItems(TreeItems, ListToEdit)
	
	For Each TreeItem IN TreeItems Do
		
		If TreeItem.GetItems().Count() <> 0 Then 
			CheckFoundItems(TreeItem.GetItems(), ListToEdit);
		Else
			
			For Each ItemOfList IN ListToEdit Do
				
				If TreeItem.FullPresentation = ItemOfList.Presentation Then
					CheckTreeItem(TreeItem, True);
					Break;
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure CheckTreeItem(TreeItem, Check, CheckParentState = True)
	TreeItem.Check = Check;
	// Cancel all subordinate tree items.
	For Each TreeChildItem IN TreeItem.GetItems() Do
		CheckTreeItem(TreeChildItem, Check, False);
	EndDo;
	// Check whether the parent state must change.
	If CheckParentState Then
		CheckBranchCheckState(TreeItem.GetParent());
	EndIf;
EndProcedure

&AtClient
Procedure CheckBranchCheckState(Branch)
	If Branch = Undefined Then 
		Return;
	EndIf;
	ChildBranches = Branch.GetItems();
	If ChildBranches.Count() = 0 Then
		Return;
	EndIf;
	
	HasTrue = False;
	HasFalse = False;
	For Each ChildBranch IN ChildBranches Do
		If ChildBranch.Check Then
			HasTrue = True;
			If HasFalse Then
				Break;
			EndIf;
		Else
			HasFalse = True;
			If HasTrue Then
				Break;
			EndIf;
		EndIf;
	EndDo;
	
	If HasTrue Then
		If HasFalse Then
			// There are marked and unmarked items if it is necessary, set as unmarked, and check the parent.
			If Branch.Check Then
				Branch.Check = False;
				CheckBranchCheckState(Branch.GetParent());
			EndIf;
		Else
			// All subordinate items are marked
			If Not Branch.Check Then
				Branch.Check = True;
				CheckBranchCheckState(Branch.GetParent());
			EndIf;
		EndIf;
	Else
		// All subordinate items are not marked.
		If Branch.Check Then
			Branch.Check = False;
			CheckBranchCheckState(Branch.GetParent());
		EndIf;
	EndIf;
EndProcedure

&AtClient
Function AssemblePresentation(TreeItem)
	If TreeItem = Undefined Then 
		Return "";
	EndIf;
	If TreeItem.GetParent() = Undefined Then
		Return TreeItem.Presentation;
	EndIf;
	Return AssemblePresentation(TreeItem.GetParent()) + "." + TreeItem.Presentation;
EndFunction

&AtClient
Procedure SetupOfMarks(Value)
	For Each TreeItem IN List.GetItems() Do
		CheckTreeItem(TreeItem, Value, False);
	EndDo;
EndProcedure

&AtServer
Procedure PerformTreeSorting()
	
	ListTree = FormAttributeToValue("List");
	ListTree.Rows.Sort("Presentation Asc", True);
	ValueToFormAttribute(ListTree, "List");
	
EndProcedure

&AtServerNoContext
Function UnspecifiedUserFullName()
	
	Return Users.UnspecifiedUserFullName();
	
EndFunction

&AtServerNoContext
Function FullNameOfServiceUser(InfobaseUserID)
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS") Then
		
		ModuleSaaSOperations = CommonUse.CommonModule("SaaSOperations");
		Return ModuleSaaSOperations.InfobaseUserAlias(InfobaseUserID);
		
	EndIf;
	
EndFunction

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
