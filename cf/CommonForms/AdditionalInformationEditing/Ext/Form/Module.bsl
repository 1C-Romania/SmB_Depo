
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not Users.RolesAvailable("AdditionalInformationChange") Then
		Items.FormWrite.Visible = False;
		Items.FormWriteAndClose.Visible = False;
		Items.ChangeContentOfAdditionalInformation.Visible = False;
	EndIf;
	
	If Parameters.FormNavigationPanel
	   AND AccessRight("Edit", Metadata.InformationRegisters.AdditionalInformation) Then
		
		Items.FormWriteAndClose.Visible = False;
		Items.FormWrite.DefaultButton = True;
		Items.FormWrite.Representation = ButtonRepresentation.PictureAndText;
	EndIf;
	
	ObjectReference = Parameters.Ref;
	
	// Getting the list of available properties sets.
	PropertiesSets = PropertiesManagementService.GetObjectPropertiesSets(Parameters.Ref);
	For Each String IN PropertiesSets Do
		AvailableSetsOfProperties.Add(String.Set);
	EndDo;
	
	// Filling the property values table.
	FillValuesPropertiesTable(True);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	Notification = New NotifyDescription("WriteAndCloseEnd", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Writing_AdditionalAttributesAndInformationSets" Then
		
		If AvailableSetsOfProperties.FindByValue(Source) <> Undefined Then
			FillValuesPropertiesTable(False);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersPropertyValuesTable

&AtClient
Procedure PropertyValuesTableOnChange(Item)
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure PropertyValuesTableBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure PropertyValuesTableBeforeDelete(Item, Cancel)
	
	If Item.CurrentData.PictureNumber = -1 Then
		Cancel = True;
		Item.CurrentData.Value = Item.CurrentData.ValueType.AdjustValue(Undefined);
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure PropertyValuesTableOnStartEdit(Item, NewRow, Copy)
	
	Item.ChildItems.PropertyValuesTableValue.TypeRestriction
		= Item.CurrentData.ValueType;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Write(Command)
	
	WritePropertyValues();
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	WriteAndCloseEnd();
	
EndProcedure

&AtClient
Procedure ChangeContentOfAdditionalInformation(Command)
	
	If AvailableSetsOfProperties.Count() = 0
	 OR Not ValueIsFilled(AvailableSetsOfProperties[0].Value) Then
		
		ShowMessageBox(,
			NStr("en='Failed to get the additional information sets of the object.
		|
		|Perhaps, the necessary attributes have not been filled for the document.';ru='Не удалось получить наборы дополнительных сведений объекта.
		|
		|Возможно у объекта не заполнены необходимые реквизиты.'"));
	Else
		FormParameters = New Structure;
		FormParameters.Insert("ShowAdditionalAttributes");
		
		OpenForm("Catalog.AdditionalAttributesAndInformationSets.ListForm", FormParameters);
		
		ParametersOfTransition = New Structure;
		ParametersOfTransition.Insert("Set", AvailableSetsOfProperties[0].Value);
		ParametersOfTransition.Insert("Property", Undefined);
		ParametersOfTransition.Insert("ThisIsAdditionalInformation", True);
		
		If Items.PropertyValuesTable.CurrentData <> Undefined Then
			ParametersOfTransition.Insert("Set", Items.PropertyValuesTable.CurrentData.Set);
			ParametersOfTransition.Insert("Property", Items.PropertyValuesTable.CurrentData.Property);
		EndIf;
		
		Notify("Transition_SetsOfAdditionalDetailsAndInformation", ParametersOfTransition);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure WriteAndCloseEnd(Result = Undefined, AdditionalParameters = Undefined) Export
	
	WritePropertyValues();
	Modified = False;
	Close();
	
EndProcedure

&AtServer
Procedure FillValuesPropertiesTable(FromHandlerOnCreate)
	
	// Filling the tree with property values.
	If FromHandlerOnCreate Then
		PropertyValues = ReadPropertiesValuesFromInformationRegister();
	Else
		PropertyValues = GetCurrentPropertiesValues();
		PropertyValuesTable.Clear();
	EndIf;
	
	Table = PropertiesManagementService.GetPropertiesValuesTable(
		PropertyValues, AvailableSetsOfProperties, True);
	
	For Each String IN Table Do
		NewRow = PropertyValuesTable.Add();
		FillPropertyValues(NewRow, String);
		NewRow.PictureNumber = ?(String.Deleted, 0, -1);
		
		If String.Value = Undefined AND 
			CommonUse.TypeDescriptionFullConsistsOfType(String.ValueType, Type("Boolean")) Then
			NewRow.Value = False;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure WritePropertyValues()
	
	// Writing the property values to the information register.
	PropertyValues = New Array;
	
	For Each String IN PropertyValuesTable Do
		
		If ValueIsFilled(String.Value)
		  AND (String.Value <> False) Then
			
			Value = New Structure("Property, Value", String.Property, String.Value);
			PropertyValues.Add(Value);
		EndIf;
	EndDo;
	
	WriteSetPropertiesToRegister(ObjectReference, PropertyValues);
	
	Modified = False;
	
EndProcedure

&AtServerNoContext
Procedure WriteSetPropertiesToRegister(Val Ref, Val PropertyValues)
	
	Set = InformationRegisters.AdditionalInformation.CreateRecordSet();
	Set.Filter.Object.Set(Ref);
	
	For Each String IN PropertyValues Do
		Record = Set.Add();
		Record.Property = String.Property;
		Record.Value = String.Value;
		Record.Object   = Ref;
	EndDo;
	
	Set.Write();
	
EndProcedure

&AtServer
Function ReadPropertiesValuesFromInformationRegister()
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	AdditionalInformation.Property,
	|	AdditionalInformation.Value
	|FROM
	|	InformationRegister.AdditionalInformation AS AdditionalInformation
	|WHERE
	|	AdditionalInformation.Object = &Object";
	Query.SetParameter("Object", Parameters.Ref);
	
	Return Query.Execute().Unload();
	
EndFunction

&AtServer
Function GetCurrentPropertiesValues()
	
	PropertyValues = New ValueTable;
	PropertyValues.Columns.Add("Property");
	PropertyValues.Columns.Add("Value");
	
	For Each String IN PropertyValuesTable Do
		
		If ValueIsFilled(String.Value) AND (String.Value <> False) Then
			NewRow = PropertyValues.Add();
			NewRow.Property = String.Property;
			NewRow.Value = String.Value;
		EndIf;
	EndDo;
	
	Return PropertyValues;
	
EndFunction

#EndRegion














