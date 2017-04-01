////////////////////////////////////////////////////////////////////////////////
// Subsystem "Access management".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Servicing tables AccessKinds and AccessValues in edit forms.

////////////////////////////////////////////////////////////////////////////////
// Event handlers of form table AccessValues.

// Only for internal use.
Procedure AccessValuesOnChange(Form, Item) Export
	
	Items = Form.Items;
	Parameters = AllowedValuesEditFormParameters(Form);
	
	If Item.CurrentData <> Undefined
	   AND Item.CurrentData.AccessKind = Undefined Then
		
		Filter = AccessManagementServiceClientServer.FilterInAllowedValuesEditFormTables(
			Form, Form.CurrentAccessType);
		
		FillPropertyValues(Item.CurrentData, Filter);
		
		Item.CurrentData.LineNumberByKind = Parameters.AccessValues.FindRows(Filter).Count();
	EndIf;
	
	AccessManagementServiceClientServer.FillInAccessValuesByKindLineNumbers(
		Form, Items.AccessKinds.CurrentData);
	
	AccessManagementServiceClientServer.FillInAllAllowedPresentation(
		Form, Items.AccessKinds.CurrentData);
	
EndProcedure

// Only for internal use.
Procedure AccessValuesOnStartEdit(Form, Item, NewRow, Copy) Export
	
	Items = Form.Items;
	
	If Item.CurrentData.AccessValue = Undefined Then
		Item.CurrentData.AccessValue = Form.SelectedValuesCurrentTypes[0].Value;
	EndIf;
	
	Items.AccessValuesAccessValue.ClearButton
		= Form.SelectedValuesCurrentType <> Undefined
		AND Form.SelectedValuesCurrentTypes.Count() > 1;
	
EndProcedure

// Only for internal use.
Procedure AccessValueStartChoice(Form, Item, ChoiceData, StandardProcessing) Export
	
	StandardProcessing = False;
	
	If Form.SelectedValuesCurrentType <> Undefined Then
		
		AccessValueStartChoiceEnd(Form);
		Return;
		
	ElsIf Form.SelectedValuesCurrentTypes.Count() = 1 Then
		
		Form.SelectedValuesCurrentType = Form.SelectedValuesCurrentTypes[0].Value;
		
		AccessValueStartChoiceEnd(Form);
		Return;
		
	ElsIf Form.SelectedValuesCurrentTypes.Count() > 0 Then
		
		If Form.SelectedValuesCurrentTypes.Count() = 2 Then
		
			If Form.SelectedValuesCurrentTypes.FindByValue(PredefinedValue(
			         "Catalog.Users.EmptyRef")) <> Undefined
			     
			   AND Form.SelectedValuesCurrentTypes.FindByValue(PredefinedValue(
			         "Catalog.UsersGroups.EmptyRef")) <> Undefined Then
				
				Form.SelectedValuesCurrentType = PredefinedValue(
					"Catalog.Users.EmptyRef");
				
				AccessValueStartChoiceEnd(Form);
				Return;
			EndIf;
			
			If Form.SelectedValuesCurrentTypes.FindByValue(PredefinedValue(
			         "Catalog.ExternalUsers.EmptyRef")) <> Undefined
			     
			   AND Form.SelectedValuesCurrentTypes.FindByValue(PredefinedValue(
			         "Catalog.ExternalUsersGroups.EmptyRef")) <> Undefined Then
				
				Form.SelectedValuesCurrentType = PredefinedValue(
					"Catalog.ExternalUsers.EmptyRef");
				
				AccessValueStartChoiceEnd(Form);
				Return;
			EndIf;
		EndIf;
		
		Form.SelectedValuesCurrentTypes.ShowChooseItem(
			New NotifyDescription("AccessValueSelectionStartContinuation", ThisObject, Form),
			NStr("en='Data type choice';ru='Выбор типа данных'"),
			Form.SelectedValuesCurrentTypes[0]);
	EndIf;
	
EndProcedure

// Only for internal use.
Procedure AccessValueChoiceProcessing(Form, Item, ValueSelected, StandardProcessing) Export
	
	CurrentData = Form.Items.AccessValues.CurrentData;
	
	If ValueSelected = Type("CatalogRef.Users") OR
	     ValueSelected = Type("CatalogRef.UsersGroups") Then
	
		StandardProcessing = False;
		
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		FormParameters.Insert("CurrentRow", CurrentData.AccessValue);
		FormParameters.Insert("UserGroupChoice", True);
		
		OpenForm("Catalog.Users.ChoiceForm", FormParameters, Item);
		
	ElsIf ValueSelected = Type("CatalogRef.ExternalUsers") OR
	          ValueSelected = Type("CatalogRef.ExternalUsersGroups") Then
	
		StandardProcessing = False;
		
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		FormParameters.Insert("CurrentRow", CurrentData.AccessValue);
		FormParameters.Insert("ExternalUserGroupChoice", True);
		
		OpenForm("Catalog.ExternalUsers.ChoiceForm", FormParameters, Item);
	EndIf;
	
EndProcedure

// Only for internal use.
Procedure AccessValuesOnEditEnd(Form, Item, NewRow, CancelEdit) Export
	
	If Form.CurrentAccessType = Undefined Then
		Parameters = AllowedValuesEditFormParameters(Form);
		
		Filter = New Structure("AccessKind", Undefined);
		
		FoundStrings = Parameters.AccessValues.FindRows(Filter);
		
		For Each String IN FoundStrings Do
			Parameters.AccessValues.Delete(String);
		EndDo;
		
		CancelEdit = True;
	EndIf;
	
	If CancelEdit Then
		AccessManagementServiceClientServer.OnChangeCurrentAccessKind(Form);
	EndIf;
	
EndProcedure

// Only for internal use.
Procedure AccessValueClearing(Form, Item, StandardProcessing) Export
	
	Items = Form.Items;
	
	StandardProcessing = False;
	SelectedValuesCurrentType = Undefined;
	
	Items.AccessValues.CurrentData.AccessValue = Form.SelectedValuesCurrentTypes[0].Value;
	Items.AccessValuesAccessValue.ClearButton = False;
	
EndProcedure

// Only for internal use.
Procedure AccessValueAutoComplete(Form, Item, Text, ChoiceData, Wait, StandardProcessing) Export
	
	FormDataOfAccessValueChoice(Form, Text, ChoiceData, StandardProcessing);
	
EndProcedure

// Only for internal use.
Procedure AccessValueTextEditEnd(Form, Item, Text, ChoiceData, StandardProcessing) Export
	
	FormDataOfAccessValueChoice(Form, Text, ChoiceData, StandardProcessing);
	
EndProcedure

// Continuation of event handler AccessValueSelectionStart.
Procedure AccessValueSelectionStartContinuation(SelectedItem, Form) Export
	
	If SelectedItem <> Undefined Then
		Form.SelectedValuesCurrentType = SelectedItem.Value;
		AccessValueStartChoiceEnd(Form);
	EndIf;
	
EndProcedure

// End of event handler AccessValueSelectionStart.
Procedure AccessValueStartChoiceEnd(Form) Export
	
	Items = Form.Items;
	Item  = Items.AccessValuesAccessValue;
	CurrentData = Items.AccessValues.CurrentData;
	
	If Not ValueIsFilled(CurrentData.AccessValue)
	   AND CurrentData.AccessValue <> Form.SelectedValuesCurrentType Then
		
		CurrentData.AccessValue = Form.SelectedValuesCurrentType;
	EndIf;
	
	Items.AccessValuesAccessValue.ClearButton
		= Form.SelectedValuesCurrentType <> Undefined
		AND Form.SelectedValuesCurrentTypes.Count() > 1;
	
	If Form.SelectedValuesCurrentType
	     = PredefinedValue("Catalog.Users.EmptyRef")
	 OR Form.SelectedValuesCurrentType
	     = PredefinedValue("Catalog.UsersGroups.EmptyRef") Then
		
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		FormParameters.Insert("CurrentRow", CurrentData.AccessValue);
		FormParameters.Insert("UserGroupChoice", True);
		
		OpenForm("Catalog.Users.ChoiceForm", FormParameters, Item);
		Return;
		
	ElsIf Form.SelectedValuesCurrentType
	          = PredefinedValue("Catalog.ExternalUsers.EmptyRef")
	          
	      OR Form.SelectedValuesCurrentType
	          = PredefinedValue("Catalog.ExternalUsersGroups.EmptyRef") Then
		
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		FormParameters.Insert("CurrentRow", CurrentData.AccessValue);
		FormParameters.Insert("ExternalUserGroupChoice", True);
		
		OpenForm("Catalog.ExternalUsers.ChoiceForm", FormParameters, Item);
		Return;
	EndIf;
	
	Filter = New Structure("ValuesType", Form.SelectedValuesCurrentType);
	FoundStrings = Form.AllSelectedValuesTypes.FindRows(Filter);
	
	If FoundStrings.Count() = 0 Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CurrentRow", CurrentData.AccessValue);
	
	OpenForm(FoundStrings[0].TableName + ".ChoiceForm", FormParameters, Item);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of form table AccessKinds.

// Only for internal use.
Procedure AccessKindsOnActivateRow(Form, Item) Export
	
	AccessManagementServiceClientServer.OnChangeCurrentAccessKind(Form);
	
EndProcedure

// Only for internal use.
Procedure AccessKindsOnActivateCell(Form, Item) Export
	
	If Form.ThisIsAccessGroupsProfile Then
		Return;
	EndIf;
	
	Items = Form.Items;
	
	If Items.AccessKinds.CurrentItem <> Items.AccessKindsAllAllowedPresentation Then
		Items.AccessKinds.CurrentItem = Items.AccessKindsAllAllowedPresentation;
	EndIf;
	
EndProcedure

// Only for internal use.
Procedure AccessKindsBeforeAddRow(Form, Item, Cancel, Copy, Parent, Group) Export
	
	If Copy Then
		Cancel = True;
	EndIf;
	
EndProcedure

// Only for internal use.
Procedure AccessKindsBeforeDeleteRow(Form, Item, Cancel) Export
	
	CurrentAccessType = Undefined;
	
EndProcedure

// Only for internal use.
Procedure AccessKindsOnStartEdit(Form, Item, NewRow, Copy) Export
	
	CurrentData = Form.Items.AccessKinds.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If NewRow Then
		CurrentData.Used = True;
	EndIf;
	
	AccessManagementServiceClientServer.FillInAllAllowedPresentation(Form, CurrentData, False);
	
EndProcedure

// Only for internal use.
Procedure AccessKindsOnEditEnd(Form, Item, NewRow, CancelEdit) Export
	
	AccessManagementServiceClientServer.OnChangeCurrentAccessKind(Form);
	
EndProcedure

// Only for internal use.
Procedure AccessKindsAccessKindPresentationOnChange(Form, Item) Export
	
	CurrentData = Form.Items.AccessKinds.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.AccessKindPresentation = "" Then
		CurrentData.AccessKind   = Undefined;
		CurrentData.Used = True;
	EndIf;
	
	AccessManagementServiceClientServer.FillAccessKindsPropertiesInForm(Form);
	AccessManagementServiceClientServer.OnChangeCurrentAccessKind(Form);
	
EndProcedure

// Only for internal use.
Procedure AccessKindsAccessKindPresentationChoiceProcessing(Form, Item, ValueSelected, StandardProcessing) Export
	
	CurrentData = Form.Items.AccessKinds.CurrentData;
	If CurrentData = Undefined Then
		StandardProcessing = False;
		Return;
	EndIf;
	
	Parameters = AllowedValuesEditFormParameters(Form);
	
	Filter = New Structure("AccessKindPresentation", ValueSelected);
	Rows = Parameters.AccessKinds.FindRows(Filter);
	
	If Rows.Count() > 0
	   AND Rows[0].GetID() <> Form.Items.AccessKinds.CurrentRow Then
	   
	   //  AlekS    need attention !
		ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Access kind ""%1"" is already selected.
		|Choose another.';ru='Вид доступа ""%1"" уже выбран.
		|Выберите другой.'"),
			ValueSelected));
		
		StandardProcessing = False;
		Return;
	EndIf;
	
	Filter = New Structure("Presentation", ValueSelected);
	CurrentData.AccessKind = Form.AllAccessKinds.FindRows(Filter)[0].Ref;
	
EndProcedure

// Only for internal use.
Procedure AccessKindsAllAllowedPresentationOnChange(Form, Item) Export
	
	CurrentData = Form.Items.AccessKinds.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.AllAllowedPresentation = "" Then
		CurrentData.AllAllowed = False;
		If Form.ThisIsAccessGroupsProfile Then
			CurrentData.Preset = False;
		EndIf;
	EndIf;
	
	If Form.ThisIsAccessGroupsProfile Then
		AccessManagementServiceClientServer.OnChangeCurrentAccessKind(Form);
		AccessManagementServiceClientServer.FillInAllAllowedPresentation(Form, CurrentData, False);
	Else
		Form.Items.AccessKinds.EndEditRow(False);
		AccessManagementServiceClientServer.FillInAllAllowedPresentation(Form, CurrentData);
	EndIf;
	
EndProcedure

// Only for internal use.
Procedure AccessKindsAllAllowedPresentationChoiceProcessing(Form, Item, ValueSelected, StandardProcessing) Export
	
	CurrentData = Form.Items.AccessKinds.CurrentData;
	If CurrentData = Undefined Then
		StandardProcessing = False;
		Return;
	EndIf;
	
	Filter = New Structure("Presentation", ValueSelected);
	Name = Form.PresentationsAllAllowed.FindRows(Filter)[0].Name;
	
	If Form.ThisIsAccessGroupsProfile Then
		CurrentData.Preset = (Name = "AllAllowed" OR Name = "AllProhibited");
	EndIf;
	
	CurrentData.AllAllowed = (Name = "InitiallyAllAllowed" OR Name = "AllAllowed");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

// Servicing tables AccessKinds and AccessValues in edit forms.

Function AllowedValuesEditFormParameters(Form, CurrentObject = Undefined)
	
	Return AccessManagementServiceClientServer.AllowedValuesEditFormParameters(
		Form, CurrentObject);
	
EndFunction

Procedure FormDataOfAccessValueChoice(Form, Text, ChoiceData, StandardProcessing)
	
	If ValueIsFilled(Text) Then
		StandardProcessing = False;
		
		If Form.CurrentAccessType = Form.AccessKindExternalUsers
		 OR Form.CurrentAccessType = Form.AccessTypeUsers Then
			
			ChoiceData = AccessManagementServiceServerCall.FormDataOfUserChoice(
				Text,
				,
				Form.CurrentAccessType = Form.AccessKindExternalUsers,
				Form.CurrentAccessType <> Form.AccessTypeUsers);
		Else
			ChoiceData = AccessManagementServiceServerCall.FormDataOfAccessValueChoice(
				Text, Form.CurrentAccessType, False);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion
