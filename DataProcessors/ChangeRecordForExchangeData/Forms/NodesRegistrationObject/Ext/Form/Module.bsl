
#Region FormEventsHandlers
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	CurrentObject = ThisObject();
	CurrentObject.ReadSettings();
	CurrentObject.ReadSSLSupportFlags();
	ThisObject(CurrentObject);
	
	RegistrationObject = Parameters.RegistrationObject;
	Details       = "";
	
	If TypeOf(RegistrationObject) = Type("Structure") Then
		TableRegistration = Parameters.TableRegistration;
		ObjectAsString = TableRegistration;
		For Each KeyValue IN RegistrationObject Do
			Details = Details + "," + KeyValue.Value;
		EndDo;
		Details = " (" + Mid(Details,2) + ")";
	Else		
		TableRegistration = "";
		ObjectAsString = RegistrationObject;
	EndIf;
	Title = "Registration " + CurrentObject.REFPRESENTATION(ObjectAsString) + Details;
	
	ReadExchangeNodes();
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	ExpandAllNodes();
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersTreeNodesExchange
//

&AtClient
Procedure TreeNodesExchangeCase(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	If Field = Items.TreeNodesExchangeDescription Or Field = Items.TreeNodesExchangeCode Then
		OpenFormEditingOtherObjects();
		Return;
	ElsIf Field <> Items.TreeNodesExchangeMessageNo Then
		Return;
	EndIf;
	
	CurrentData = Items.TreeNodesExchange.CurrentData;
	Notification = New NotifyDescription("TreeNodesExchangeSelectionEnd", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("Node", CurrentData.Ref);
	
	ToolTip = NStr("en = 'Sent Number'"); 
	ShowInputNumber(Notification, CurrentData.MessageNo, ToolTip);
EndProcedure

&AtClient
Procedure TreeNodesExchangeCheckOnChange(Item)
	MarkChange(Items.TreeNodesExchange.CurrentRow);
EndProcedure

#EndRegion

#Region FormCommandsHandlers
//

&AtClient
Procedure RereadTreeNodes(Command)
	CurrentNode = CurrentSelectedNode();
	ReadExchangeNodes();
	ExpandAllNodes(CurrentNode);
EndProcedure

&AtClient
Procedure OpenFormEditingOfNode(Command)
	OpenFormEditingOtherObjects();
EndProcedure

&AtClient
Procedure MarkAllNodes(Command)
	For Each PlanString IN TreeNodesExchange.GetItems() Do
		PlanString.Check = True;
		MarkChange(PlanString.GetID())
	EndDo;
EndProcedure

&AtClient
Procedure UnMarkAllNodes(Command)
	For Each PlanString IN TreeNodesExchange.GetItems() Do
		PlanString.Check = False;
		MarkChange(PlanString.GetID())
	EndDo;
EndProcedure

&AtClient
Procedure InvertMarkAllNodes(Command)
	For Each PlanString IN TreeNodesExchange.GetItems() Do
		For Each NodeString IN PlanString.GetItems() Do
			NodeString.Check = Not NodeString.Check;
			MarkChange(NodeString.GetID())
		EndDo;
	EndDo;
EndProcedure

&AtClient
Procedure ChangeRegistration(Command)
	
	QuestionTitle = NStr("en = 'Confirmation'");
	Text = NStr("en = 'Do you
	             |want to change registration ""%1"" on nodes?'");
	
	Text = StrReplace(Text, "%1", RegistrationObject);
	
	Notification = New NotifyDescription("ChangeRegistrationEnd", ThisObject);
	
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , ,QuestionTitle);
EndProcedure

&AtClient
Procedure ChangeRegistrationEnd(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	Quantity = UpdateRegistrationSites(TreeNodesExchange);
	If Quantity > 0 Then
		Text = NStr("en = 'Registration %1 has been changed on %2 nodes'");
		NotificationTitle = NStr("en = 'Update registration:'");
		
		Text = StrReplace(Text, "%1", RegistrationObject);
		Text = StrReplace(Text, "%2", Quantity);
		
		ShowUserNotification(NotificationTitle,
			GetURL(RegistrationObject),
			Text,
			Items.HiddenPictureInformation32.Picture);
		
		If Parameters.NotifyAboutChanges Then
			Notify("UpdateRegistrationExchangeDataObject",
				New Structure("RegistrationObject, TableRegistration", RegistrationObject, TableRegistration),
				ThisObject);
		EndIf;
	EndIf;
	
	CurrentNode = CurrentSelectedNode();
	ReadExchangeNodes(True);
	ExpandAllNodes(CurrentNode);
EndProcedure

&AtClient
Procedure OpenFormSettings(Command)
	OpenFormSettingsDataProcessors();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TreeNodesExchangeMessageNo.Name);

	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.OrGroup;

	FilterElement = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("ExchangeNodeTree.Ref");
	FilterElement.ComparisonType = DataCompositionComparisonType.NotFilled;

	FilterElement = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("TreeNodesExchange.Check");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = 0;

	Item.Appearance.SetParameterValue("Text", NStr("en = 'TreeNodesExchangeMessageNo'"));
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Not exported'"));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TreeNodesExchangeCode.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TreeNodesExchangeAutoRecord.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TreeNodesExchangeMessageNo.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("ExchangeNodeTree.Ref");
	FilterElement.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);

EndProcedure
//

&AtClient
Procedure TreeNodesExchangeSelectionEnd(Val Number, Val AdditionalParameters) Export
	If Number = Undefined Then 
		// Refusal to enter
		Return;
	EndIf;
	
	ChangeMessageNoAtServer(AdditionalParameters.Node, Number, RegistrationObject, TableRegistration);
	
	CurrentNode = CurrentSelectedNode();
	ReadExchangeNodes(True);
	ExpandAllNodes(CurrentNode);
	
	If Parameters.NotifyAboutChanges Then
		Notify("UpdateRegistrationExchangeDataObject",
			New Structure("RegistrationObject, TableRegistration", RegistrationObject, TableRegistration),
			ThisObject);
	EndIf;
EndProcedure

&AtClient
Function CurrentSelectedNode()
	CurrentData = Items.TreeNodesExchange.CurrentData;
	If CurrentData = Undefined Then
		Return Undefined;
	EndIf;
	Return New Structure("Description, Refs", CurrentData.Description, CurrentData.Ref);
EndFunction

&AtClient
Procedure OpenFormSettingsDataProcessors()
	CurFormName = GetFormName() + "Form.Settings";
	OpenForm(CurFormName, , ThisObject);
EndProcedure

&AtClient
Procedure OpenFormEditingOtherObjects()
	CurFormName = GetFormName() + "Form.Form";
	Data = Items.TreeNodesExchange.CurrentData;
	If Data <> Undefined AND Data.Ref <> Undefined Then
		CurParameters = New Structure("ExchangeNode, CommandID, DestinationObjects", Data.Ref);
		OpenForm(CurFormName, CurParameters, ThisObject);
	EndIf;
EndProcedure

&AtClient
Procedure ExpandAllNodes(FocalNode = Undefined)
	FoundNode = Undefined;
	
	For Each String IN TreeNodesExchange.GetItems() Do
		ID = String.GetID();
		Items.TreeNodesExchange.Expand(ID, True);
		
		If FocalNode <> Undefined AND FoundNode = Undefined Then
			If String.Description = FocalNode.Description AND String.Ref = FocalNode.Ref Then
				FoundNode = ID;
			Else
				For Each Substring IN String.GetItems() Do
					If Substring.Description = FocalNode.Description AND Substring.Ref = FocalNode.Ref Then
						FoundNode = Substring.GetID();
					EndIf;
				EndDo;
			EndIf;
		EndIf;
		
	EndDo;
	
	If FocalNode <> Undefined AND FoundNode <> Undefined Then
		Items.TreeNodesExchange.CurrentRow = FoundNode;
	EndIf;
	
EndProcedure

&AtServer
Function UpdateRegistrationSites(Val Data)
	CurrentObject = ThisObject();
	NodesNumber = 0;
	For Each String IN Data.GetItems() Do
		If String.Ref <> Undefined Then
			AlreadyRegistered = CurrentObject.ObjectIsRegisteredAtNod(String.Ref, RegistrationObject, TableRegistration);
			If String.Check = 0 AND AlreadyRegistered Then
				Result = CurrentObject.ChangeRegistrationAtServer(False, True, String.Ref, RegistrationObject, TableRegistration);
				NodesNumber = NodesNumber + Result.Successfully;
			ElsIf String.Check = 1 AND (NOT AlreadyRegistered) Then
				Result = CurrentObject.ChangeRegistrationAtServer(True, True, String.Ref, RegistrationObject, TableRegistration);
				NodesNumber = NodesNumber + Result.Successfully;
			EndIf;
		EndIf;
		NodesNumber = NodesNumber + UpdateRegistrationSites(String);
	EndDo;
	Return NodesNumber;
EndFunction

&AtServer
Function ChangeMessageNoAtServer(Node, MessageNo, Data, TableName = Undefined)
	Return ThisObject().ChangeRegistrationAtServer(MessageNo, True, Node, Data, TableName);
EndFunction

&AtServer
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
Procedure MarkChange(String)
	DataItem = TreeNodesExchange.FindByID(String);
	ThisObject().MarkChange(DataItem);
EndProcedure

&AtServer
Procedure ReadExchangeNodes(OnlyRefresh = False)
	CurrentObject = ThisObject();
	Tree = CurrentObject.SetNodTree(RegistrationObject, TableRegistration);
	
	If OnlyRefresh Then
		// Update some fields with the current data.
		For Each PlanString IN TreeNodesExchange.GetItems() Do
			For Each NodeString IN PlanString.GetItems() Do
				TreeRow = Tree.Rows.Find(NodeString.Ref, "Ref", True);
				If TreeRow <> Undefined Then
					FillPropertyValues(NodeString, TreeRow, "Check, InitialCheck, MessageNo, NotExported");
				EndIf;
			EndDo;
		EndDo;
	Else
		// Reform completely
		ValueToFormAttribute(Tree, "TreeNodesExchange");
	EndIf;
	
	For Each PlanString IN TreeNodesExchange.GetItems() Do
		For Each NodeString IN PlanString.GetItems() Do
			CurrentObject.MarkChange(NodeString);
		EndDo;
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
