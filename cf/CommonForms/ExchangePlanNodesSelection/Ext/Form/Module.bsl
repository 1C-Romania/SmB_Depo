////////////////////////////////////////////////////////////////////////////////
// Selection form for the fields of the "exchange plan node" type.
//  
////////////////////////////////////////////////////////////////////////////////

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Standard parameters data processor.
	If Parameters.CloseOnChoice = False Then
		PickMode = True;
		If Parameters.Property("Multiselect") AND Parameters.Multiselect = True Then
			Multiselect = True;
		EndIf;
	EndIf;
	
	// Preparation of the used exchange plans list.
	If TypeOf(Parameters.ExchangePlansForChoice) = Type("Array") Then
		For Each Item IN Parameters.ExchangePlansForChoice Do
			If TypeOf(Item) = Type("String") Then
				// Search exchange plan by name.
				AddUsedExchangePlan(Metadata.FindByFullName(Item));
				AddUsedExchangePlan(Metadata.FindByFullName("ExchangePlan." + Item));
				//
			ElsIf TypeOf(Item) = Type("Type") Then
				// Search exchange plan by the specified type.
				AddUsedExchangePlan(Metadata.FindByType(Item));
			Else
				// Search exchange plan by the specified node type.
				AddUsedExchangePlan(Metadata.FindByType(TypeOf(Item)));
			EndIf;
		EndDo;
	Else
		// All exchange plans participate in the selection.
		For Each MetadataObject IN Metadata.ExchangePlans Do
			AddUsedExchangePlan(MetadataObject);
		EndDo;
	EndIf;
	
	ExchangePlanNodes.Sort("ExchangePlanPresentation Asc");
	
	If PickMode Then
		Title = NStr("en='Picking nodes of exchange plans';ru='Подбор узлов планов обмена'");
	EndIf;
	If Multiselect Then
		Items.ExchangePlanNodes.SelectionMode = TableSelectionMode.MultiRow;
	EndIf;
	
	CurrentRow = Undefined;
	Parameters.Property("CurrentRow", CurrentRow);
	
	FoundStrings = ExchangePlanNodes.FindRows(New Structure("Node", CurrentRow));
	
	If FoundStrings.Count() > 0 Then
		Items.ExchangePlanNodes.CurrentRow = FoundStrings[0].GetID();
	EndIf;
	
EndProcedure

#EndRegion

#Region ExchangePlansNodesFormTableItemsEventsHandlers

&AtClient
Procedure ExchangePlanNodesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Multiselect Then
		ChoiceValue = New Array;
		ChoiceValue.Add(ExchangePlanNodes.FindByID(SelectedRow).Node);
		NotifyChoice(ChoiceValue);
	Else
		NotifyChoice(ExchangePlanNodes.FindByID(SelectedRow).Node);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Select(Command)
	
	If Multiselect Then
		ChoiceValue = New Array;
		For Each SelectedRow IN Items.ExchangePlanNodes.SelectedRows Do
			ChoiceValue.Add(ExchangePlanNodes.FindByID(SelectedRow).Node)
		EndDo;
		NotifyChoice(ChoiceValue);
	Else
		CurrentData = Items.ExchangePlanNodes.CurrentData;
		If CurrentData = Undefined Then
			ShowMessageBox(, NStr("en='Node is not selected';ru='Узел не выбран.'"));
		Else
			NotifyChoice(CurrentData.Node);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure AddUsedExchangePlan(MetadataObject)
	
	If MetadataObject = Undefined
		OR Not Metadata.ExchangePlans.Contains(MetadataObject) Then
		Return;
	EndIf;
	ExchangePlan = CommonUse.ObjectManagerByFullName(MetadataObject.FullName()).EmptyRef();
	ExchangePlanPresentation = MetadataObject.Synonym;
	
	// Filling nodes of the used exchange plans.
	If Parameters.ChooseAllNodes Then
		NewRow = ExchangePlanNodes.Add();
		NewRow.ExchangePlan              = ExchangePlan;
		NewRow.ExchangePlanPresentation = MetadataObject.Synonym;
		NewRow.Node                    = ExchangePlan;
		NewRow.NodePresentation       = NStr("en='<All infobases>';ru='<Все информационные базы>'");
	EndIf;
	
	Query = New Query;
	Query.SetParameter("ThisNode", ExchangePlans[MetadataObject.Name].ThisNode());
	Query.Text =
	"SELECT
	|	ExchangePlanTable.Ref,
	|	ExchangePlanTable.Presentation AS Presentation
	|FROM
	|	&ExchangePlanTable AS ExchangePlanTable
	|WHERE
	|	ExchangePlanTable.Ref <> &ThisNode
	|
	|ORDER BY
	|	Presentation";
	Query.Text = StrReplace(Query.Text, "&ExchangePlanTable", MetadataObject.FullName());
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		NewRow = ExchangePlanNodes.Add();
		NewRow.ExchangePlan              = ExchangePlan;
		NewRow.ExchangePlanPresentation = MetadataObject.Synonym;
		NewRow.Node                    = Selection.Ref;
		NewRow.NodePresentation       = Selection.Presentation;
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
