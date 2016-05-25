
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ObjectAttributesCollection = ObjectAttributes.GetItems();
	
	AllAttributesSelected = Parameters.Filter.Count() = 0 Or Parameters.Filter[0] = "*";
	MetadataObject = Parameters.Ref.Metadata();
	For Each AttributeFullName IN MetadataObject.Attributes Do
		Attribute = ObjectAttributesCollection.Add();
		FillPropertyValues(Attribute, AttributeFullName);
		Attribute.Check = AllAttributesSelected Or Parameters.Filter.Find(AttributeFullName.Name) <> Undefined;
		If IsBlankString(Attribute.Synonym) Then 
			Attribute.Synonym = Attribute.Name;
		EndIf;
	EndDo;
	
	For Each TabularSectionDescription IN MetadataObject.TabularSections Do
		TabularSection = ObjectAttributesCollection.Add();
		FillPropertyValues(TabularSection, TabularSectionDescription);
		WholeTabularSectionSelected = AllAttributesSelected Or Parameters.Filter.Find(TabularSectionDescription.Name + ".*") <> Undefined;
		HasSelectedItems = WholeTabularSectionSelected;
		For Each AttributeFullName IN TabularSectionDescription.Attributes Do
			Attribute = TabularSection.GetItems().Add();
			FillPropertyValues(Attribute, AttributeFullName);
			Attribute.Check = AllAttributesSelected Or WholeTabularSectionSelected Or Parameters.Filter.Find(TabularSectionDescription.Name + "." + AttributeFullName.Name) <> Undefined;
			HasSelectedItems = HasSelectedItems Or Attribute.Check;
		EndDo;
		TabularSection.Check = HasSelectedItems + ?(HasSelectedItems, (NOT WholeTabularSectionSelected), HasSelectedItems);
	EndDo;
	
EndProcedure

#EndRegion

#Region ObjectAttributesFormTableItemsEventsHandler

&AtClient
Procedure ObjectAttributesMarkOnChange(Item)
	
	WhenChangingCheckBox(Items.ObjectAttributes, "Mark");
	SetSelectionButtonAvailability();

EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CheckAll(Command)
	SetResetFlags(True);
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	SetResetFlags(False);
EndProcedure

&AtClient
Procedure Select(Command)
	Result = New Structure;
	Result.Insert("SelectedAttributes", SelectedAttributes(ObjectAttributes.GetItems()));
	Result.Insert("SelectedPresentation", SelectedAttributesPresentation());

	Close(Result);
EndProcedure

&AtClient
#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure SetResetFlags(Mark)
	For Each Attribute IN ObjectAttributes.GetItems() Do 
		Attribute.Check = Mark;
		For Each SubordinatedAttribute IN Attribute.GetItems() Do
			SubordinatedAttribute.Check = Mark;
		EndDo;
	EndDo;
	SetSelectionButtonAvailability();
EndProcedure

&AtClient
Function SelectedAttributes(CollectionDetails)
	Result = New Array;
	AllAttributesSelected = True;
	
	For Each Attribute IN CollectionDetails Do
		SubordinateAttributes = Attribute.GetItems();
		If SubordinateAttributes.Count() > 0 Then
			SelectedList = SelectedAttributes(SubordinateAttributes);
			AllAttributesSelected = AllAttributesSelected AND SelectedList.Count() = 1 AND SelectedList[0] = "*";
			For Each SubordinatedAttribute IN SelectedList Do
				Result.Add(Attribute.Name + "." + SubordinatedAttribute);
			EndDo;
		Else
			AllAttributesSelected = AllAttributesSelected AND Attribute.Check;
			If Attribute.Check Then
				Result.Add(Attribute.Name);
			EndIf;
		EndIf;
	EndDo;
	
	If AllAttributesSelected Then
		Result.Clear();
		Result.Add("*");
	EndIf;
	
	Return Result;
EndFunction

&AtClient
Function SelectedAttributesPresentation()
	Result = StringFunctionsClientServer.RowFromArraySubrows(SelectedAttributesSynonyms(), ", ");
	If Result = "*" Then
		Result = NStr("en = 'All attributes'");
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Function SelectedAttributesSynonyms()
	Result = New Array;
	
	CollectionDetails = FormAttributeToValue("ObjectAttributes");
	
	SelectedAttributes = CollectionDetails.Rows.FindRows(New Structure("Mark", 1));
	If SelectedAttributes.Count() = CollectionDetails.Rows.Count() Then
		Result.Add(NStr("en = 'All'"));
		Return Result;
	EndIf;
	
	For Each Attribute IN SelectedAttributes Do
		Result.Add(Attribute.Synonym);
	EndDo;
	
	SelectedAttributes = CollectionDetails.Rows.FindRows(New Structure("Mark", 2));
	For Each Attribute IN SelectedAttributes Do
		SubordinateAttributes = Attribute.Rows;
		For Each SubordinatedAttribute IN SubordinateAttributes Do
			If SubordinatedAttribute.Check Then
				Result.Add(Attribute.Synonym + "." + SubordinatedAttribute.Synonym);
			EndIf;
		EndDo;
	EndDo;
	
	Return Result;
EndFunction


// Sets linked check boxes.
&AtClient
Procedure WhenChangingCheckBox(FormTree, FlagName)
	
	CurrentData = FormTree.CurrentData;
	
	If CurrentData[FlagName] = 2 Then
		CurrentData[FlagName] = 0;
	EndIf;
	
	Mark = CurrentData[FlagName];
	
	// Update of the subordinate check boxes.
	For Each SubordinatedAttribute IN CurrentData.GetItems() Do
		SubordinatedAttribute[FlagName] = Mark;
	EndDo;
	
	// Update a parent check box.
	Parent = CurrentData.GetParent();
	If Parent <> Undefined Then
		HasSelectedItems = False;
		AllItemsAreSelected = True;
		For Each Item IN Parent.GetItems() Do
			HasSelectedItems = HasSelectedItems Or Item[FlagName];
			AllItemsAreSelected = AllItemsAreSelected AND Item[FlagName];
		EndDo;
		Parent[FlagName] = HasSelectedItems + ?(HasSelectedItems, (NOT AllItemsAreSelected), HasSelectedItems);
	EndIf;

EndProcedure

&AtClient
Procedure SetSelectionButtonAvailability()
	Items.ObjectAttributesChoose.Enabled = SelectedAttributes(ObjectAttributes.GetItems()).Count() > 0
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
