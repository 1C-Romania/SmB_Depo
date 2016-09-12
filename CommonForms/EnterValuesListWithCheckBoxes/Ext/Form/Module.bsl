&AtClient
Var ClientVariables;

////////////////////////////////////////////////////////////////////////////////
// FORM EVENTS

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Parameters.Property("Presentation", FieldPresentation);
	Parameters.Property("LimitChoiceWithSpecifiedValues", LimitChoiceWithSpecifiedValues);
	TypeInformation = ReportsClientServer.TypesAnalysis(Parameters.TypeDescription, True);
	ValuesForSelection = CommonUseClientServer.StructureProperty(Parameters, "ValuesForSelection");
	marked = CommonUseClientServer.StructureProperty(Parameters, "marked");
	
	Title = NStr("en='List of selected';ru='Список выбранных'") + " (" + FieldPresentation + ")";
	
	If TypeInformation.TypeCount = 0 Then
		LimitChoiceWithSpecifiedValues = True;
	ElsIf Not TypeInformation.ContainsObjectTypes Then
		Items.ListPick.Visible     = False;
		Items.ListPickMenu.Visible = False;
		Items.ListAdd.OnlyInAllActions = False;
	EndIf;
	
	List.ValueType = TypeInformation.TypeDescriptionForForm;
	If TypeOf(ValuesForSelection) = Type("ValueList") Then
		ValuesForSelection.FillMarks(False);
		ReportsClientServer.ExpandList(List, ValuesForSelection, True);
	EndIf;
	If TypeOf(marked) = Type("ValueList") Then
		marked.FillMarks(True);
		ReportsClientServer.ExpandList(List, marked, True);
	EndIf;
	
	If LimitChoiceWithSpecifiedValues Then
		Items.ListValue.ReadOnly = True;
		Items.List.ChangeRowSet    = False;
		
		Items.ListAddDelete.Visible     = False;
		Items.ListAddDeleteMenu.Visible = False;
		
		Items.ListSorting.Visible     = False;
		Items.ListSortingMenu.Visible = False;
		
		Items.ListTransfer.Visible     = False;
		Items.ListTransferMenu.Visible = False;
	EndIf;
	
	ChoiceParameters = CommonUseClientServer.StructureProperty(Parameters, "ChoiceParameters");
	If TypeOf(ChoiceParameters) = Type("Array") Then
		Items.ListValue.ChoiceParameters = New FixedArray(ChoiceParameters);
	EndIf;
	
	WindowOptionsKey = CommonUseClientServer.StructureProperty(Parameters, "UniqueKey");
	If IsBlankString(WindowOptionsKey) Then
		WindowOptionsKey = String(List.ValueType);
	EndIf;
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.DataLoadFromFile") Then
		Items.ListInsertFromClipboard.Visible = False;
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	ClientVariables = New Structure;
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// TABLE EVENTS List

#Region FormTableItemsEventsHandlersList

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	RowIdentifier = Item.CurrentRow;
	If RowIdentifier = Undefined Then
		Return;
	EndIf;
	
	ValuesListInForm = ThisObject[Item.Name];
	ListItemInForm = ValuesListInForm.FindByID(RowIdentifier);
	
	CurrentRow = Item.CurrentData;
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	ListItemPriorToChange = New Structure("Identifier, Mark, Value, Presentation");
	FillPropertyValues(ListItemPriorToChange, ListItemInForm);
	ListItemPriorToChange.ID = RowIdentifier;
	ClientVariables.Insert("ListItemPriorToChange", ListItemPriorToChange);
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group, Parameter)
	If LimitChoiceWithSpecifiedValues Then
		Cancel = True;
	EndIf;
EndProcedure

&AtClient
Procedure ListBeforeDelete(Item, Cancel)
	If LimitChoiceWithSpecifiedValues Then
		Cancel = True;
	EndIf;
EndProcedure

&AtClient
Procedure ListBeforeEditingCompletion(Item, NewRow, CancelStartEditing, CancelEndEditing)
	If CancelStartEditing Then
		Return;
	EndIf;
	
	RowIdentifier = Item.CurrentRow;
	If RowIdentifier = Undefined Then
		Return;
	EndIf;
	ValuesListInForm = ThisObject[Item.Name];
	ListItemInForm = ValuesListInForm.FindByID(RowIdentifier);
	
	Value = ListItemInForm.Value;
	If Value = Undefined
		Or Value = Type("Undefined")
		Or Value = New TypeDescription("Undefined")
		Or Not ValueIsFilled(Value) Then
		CancelEndEditing = True; // Prevent null values.
	Else
		For Each ListItemDoubleInForm IN ValuesListInForm Do
			If ListItemDoubleInForm.Value = Value AND ListItemDoubleInForm <> ListItemInForm Then
				Status(NStr("en='Found duplicate records. Editing canceled.';ru='Обнаружены дублирующиеся записи. Редактирование отменено.'"));
				CancelEndEditing = True; // Deny duplicates.
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	ListItemPriorToChange = CommonUseClientServer.StructureProperty(ClientVariables, "ListItemPriorToChange");
	HasInformation = (ListItemPriorToChange <> Undefined AND ListItemPriorToChange.ID = RowIdentifier);
	If Not CancelEndEditing AND HasInformation AND ListItemPriorToChange.Value <> Value Then
		If LimitChoiceWithSpecifiedValues Then
			CancelEndEditing = True;
		Else
			ListItemInForm.Presentation = ""; // AutoFill of presentation.
			ListItemInForm.Check = True; // Select check box.
		EndIf;
	EndIf;
	
	If CancelEndEditing Then
		// Values rollback.
		If HasInformation Then
			FillPropertyValues(ListItemInForm, ListItemPriorToChange);
		EndIf;
		// Restart the BeforeEditingEnd event with CancelEditingBegin = True.
		Item.EndEditRow(True);
	Else
		If NewRow Then
			ListItemInForm.Check = True; // Select check box.
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure ListChoiceProcessing(Item, ChoiceResult, StandardProcessing)
	StandardProcessing = False;
	// Add selected items with uniqueness control.
	If TypeOf(ChoiceResult) = Type("Array") Then
		For Each Value IN ChoiceResult Do
			ReportsClientServer.AddUniqueValueInList(List, Value, Undefined, True);
		EndDo;
	Else
		ReportsClientServer.AddUniqueValueInList(List, ChoiceResult, Undefined, True);
	EndIf;
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// BUTTONS EVENTS

#Region FormCommandsHandlers

&AtClient
Procedure FinishEdit(Command)
	If ModalMode
		Or WindowOpeningMode = FormWindowOpeningMode.LockWholeInterface
		Or FormOwner = Undefined Then
		Close(List);
	Else
		NotifyChoice(List);
	EndIf;
EndProcedure

&AtClient
Procedure InsertFromClipboard(Command)
	SearchParameters = New Structure;
	SearchParameters.Insert("TypeDescription", List.ValueType);
	SearchParameters.Insert("ChoiceParameters", Items.ListValue.ChoiceParameters);
	SearchParameters.Insert("FieldPresentation", FieldPresentation);
	SearchParameters.Insert("Script", "SearchRefs");
	
	ExecuteParameters = New Structure;
	Handler = New NotifyDescription("InsertFromClipboardEnd", ThisObject, ExecuteParameters);
	
	ModuleDataLoadFromFileClient = CommonUseClient.CommonModule("DataLoadFromFileClient");
	ModuleDataLoadFromFileClient.ShowRefsFillingForm(SearchParameters, Handler);
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// HELPER PROCEDURE AND FUNCTIONS

#Region ServiceProceduresAndFunctions

&AtClient
Procedure InsertFromClipboardEnd(FoundObjects, ExecuteParameters) Export
	If FoundObjects = Undefined Then
		Return;
	EndIf;
	For Each Value IN FoundObjects Do
		ReportsClientServer.AddUniqueValueInList(List, Value, Undefined, True);
	EndDo;
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
