
#Region FormEventsHandlers
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Multiselect = False;
	ReadTreeNodesExchange();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	CurParameters = SetFormParameters();
	ExpandNodes(CurParameters.marked);
	Items.TreeNodesExchange.CurrentRow = CurParameters.CurrentRow;
EndProcedure

&AtClient
Procedure OnReopen()
	CurParameters = SetFormParameters();
	ExpandNodes(CurParameters.marked);
	Items.TreeNodesExchange.CurrentRow = CurParameters.CurrentRow;
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersNodeTree
//

&AtClient
Procedure TreeNodesExchangeCase(Item, SelectedRow, Field, StandardProcessing)
	MakeNodesChoice(False);
EndProcedure

&AtClient
Procedure TreeNodesExchangeCheckOnChange(Item)
	MarkChange(Items.TreeNodesExchange.CurrentRow);
EndProcedure

#EndRegion

#Region FormCommandsHandlers
//

// Selects the node and passes the selected values to the calling form.
&AtClient
Procedure SelectNode(Command)
	MakeNodesChoice(Multiselect);
EndProcedure

// Opens the node form specified in configuration.
&AtClient
Procedure ChangeNode(Command)
	KeyRef = Items.TreeNodesExchange.CurrentData.Ref;
	If KeyRef <> Undefined Then
		OpenForm(GetFormName(KeyRef) + "ObjectForm", New Structure("Key", KeyRef));
	EndIf;
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TreeNodesExchangeCode.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("ExchangeNodeTree.Ref");
	FilterElement.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);

EndProcedure
//

&AtClient
Procedure ExpandNodes(marked) 
	If marked <> Undefined Then
		For Each CurId IN marked Do
			CurRow = TreeNodesExchange.FindByID(CurId);
			CurParent = CurRow.GetParent();
			If CurParent <> Undefined Then
				Items.TreeNodesExchange.Expand(CurParent.GetID());
			EndIf;
		EndDo;
	EndIf;
EndProcedure	

&AtClient
Procedure MakeNodesChoice(ThisIsMultiselect)
	
	If ThisIsMultiselect Then
		Data = SelectedNodes();
		If Data.Count() > 0 Then
			NotifyChoice(Data);
		EndIf;
		Return;
	EndIf;
	
	Data = Items.TreeNodesExchange.CurrentData;
	If Data <> Undefined AND Data.Ref <> Undefined Then
		NotifyChoice(Data.Ref);
	EndIf;
	
EndProcedure

&AtServer
Function SelectedNodes(NewData = Undefined)
	
	If NewData <> Undefined Then
		// Setting
		marked = New Array;
		IntSetSelectedNodes(ThisObject(), TreeNodesExchange, NewData, marked);
		Return marked;
	EndIf;
	
	// Get
	Result = New Array;
	For Each TechPlan IN TreeNodesExchange.GetItems() Do
		For Each CurRow IN TechPlan.GetItems() Do
			If CurRow.Check AND CurRow.Ref <> Undefined Then
				Result.Add(CurRow.Ref);
			EndIf;
		EndDo;
	EndDo;
	
	Return Result;
EndFunction

&AtServer
Procedure IntSetSelectedNodes(CurrentObject, Data, NewData, marked)
	For Each CurRow IN Data.GetItems() Do
		If NewData.Find(CurRow.Ref) <> Undefined Then
			CurRow.Check = True;
			CurrentObject.SetMarksUp(CurRow);
			marked.Add(CurRow.GetID());
		EndIf;
		IntSetSelectedNodes(CurrentObject, CurRow, NewData, marked);
	EndDo;
EndProcedure

Function ThisObject(CurrentObject = Undefined) 
	If CurrentObject = Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(CurrentObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Function GetFormName(CurrentObject = Undefined)
	Return ThisObject().GetFormName(CurrentObject);
EndFunction	

&AtServer
Procedure ReadTreeNodesExchange()
	Tree = ThisObject().SetNodTree();
	ValueToFormAttribute(Tree,  "TreeNodesExchange");
EndProcedure

&AtServer
Procedure MarkChange(DataRow)
	DataItem = TreeNodesExchange.FindByID(DataRow);
	ThisObject().MarkChange(DataItem);
EndProcedure

&AtServer
Function SetFormParameters()
	
	Result = New Structure("CurrentRow, Marked");
	
	// Multiple choice
	Items.TreeNodesExchangeCheck.Visible = Parameters.Multiselect;
	// Delete the mark only if choice has changed.
	If Parameters.Multiselect <> Multiselect Then
		CurrentObject = ThisObject();
		For Each CurRow IN TreeNodesExchange.GetItems() Do
			CurRow.Check = False;
			CurrentObject.SetMarksDown(CurRow);
		EndDo;
	EndIf;
	Multiselect = Parameters.Multiselect;
	
	// Positioning
	If Multiselect AND TypeOf(Parameters.ChoiceInitialValue) = Type("Array") Then 
		marked = SelectedNodes(Parameters.ChoiceInitialValue);
		Result.marked = marked;
		If marked.Count() > 0 Then
			Result.CurrentRow = marked[0];
		EndIf;
			
	ElsIf Parameters.ChoiceInitialValue <> Undefined Then
		// Single variant
		Result.CurrentRow = RowIdOnSite(TreeNodesExchange, Parameters.ChoiceInitialValue);
		
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Function RowIdOnSite(Data, Ref)
	For Each CurRow IN Data.GetItems() Do
		If CurRow.Ref = Ref Then
			Return CurRow.GetID();
		EndIf;
		Result = RowIdOnSite(CurRow, Ref);
		If Result <> Undefined Then 
			Return Result;
		EndIf;
	EndDo;
	Return Undefined;
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
