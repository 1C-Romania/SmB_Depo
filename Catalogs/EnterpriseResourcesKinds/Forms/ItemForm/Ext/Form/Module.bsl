
////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ResourcesList.Parameters.SetParameterValue("EnterpriseResourceKind", Object.Ref);
	
	// Delete prohibition from the All resources kind content.
	If Object.Ref = Catalogs.EnterpriseResourcesKinds.AllResources Then
		Items.ResourcesListCommandPanel.ChildItems.ResourcesListDelete.Enabled = False;
		Items.ResourcesListContextMenu.ChildItems.ResourcesListContextMenuDelete.Enabled = False;
	EndIf;
	
EndProcedure // OnCreateAtServer()

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_EnterpriseResourcesKinds" Then
		
		ResourcesList.Parameters.SetParameterValue("EnterpriseResourceKind", Object.Ref);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENTS HANDLER OF LIST FORM

// Procedure - Change event handler of the ResourcesList form list.
//
&AtClient
Procedure ListChange(Command)
	
	If Not ValueIsFilled(Object.Ref) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Data is still not recorded.'");
		Message.Message();
	Else
		OpenParameters = New Structure;
		OpenParameters.Insert("Key", Items.ResourcesList.CurrentRow);
		OpenParameters.Insert("AvailabilityOfKind", False);
		If Items.ResourcesList.CurrentRow = Undefined Then
			OpenParameters.Insert("ValueEnterpriseResourceKind", Object.Ref);
		EndIf;
		OpenForm("InformationRegister.EnterpriseResourcesKinds.RecordForm", OpenParameters);
		
	EndIf;
	
EndProcedure // ListChange()

// Procedure - BeforeAddingBegin event handler of the ResourcesList form list.
//
&AtClient
Procedure ResourcesListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	If Not ValueIsFilled(Object.Ref) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Data is still not recorded.'");
		Message.Message();
	Else
		OpenParameters = New Structure;
		OpenParameters.Insert("AvailabilityOfKind", False);
		OpenParameters.Insert("ValueEnterpriseResourceKind", Object.Ref);
		OpenForm("InformationRegister.EnterpriseResourcesKinds.RecordForm", OpenParameters, Item);
	EndIf;
	
EndProcedure // ResourcesListBeforeAddRow()

// Procedure - Selection event handler of the ResourcesList form list.
//
&AtClient
Procedure ResourcesListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	OpenParameters = New Structure;
	OpenParameters.Insert("Key", Items.ResourcesList.CurrentRow);
	OpenParameters.Insert("AvailabilityOfKind", False);
	OpenForm("InformationRegister.EnterpriseResourcesKinds.RecordForm", OpenParameters);
	
EndProcedure // ResourcesListSelection()

// Procedure - BeforeDelete event handler of the ResourcesList form list.
//
&AtClient
Procedure ResourcesListBeforeDeleteRow(Item, Cancel)
	
	If Object.Ref = PredefinedValue("Catalog.EnterpriseResourcesKinds.AllResources") Then
		MessageText = NStr("en = 'Object is not deleted as the enterprise resource should be included into the ""All resources"" kind.'");
		SmallBusinessClient.ShowMessageAboutError(Object, MessageText, , , , Cancel);
	EndIf;
	
EndProcedure // ResourcesListBeforeDeleteRow()

// Procedure - AfterDeletion event handler of the ResourcesList form list.
//
&AtClient
Procedure ResourcesListAfterDeleteRow(Item)
	
	Notify("Record_EnterpriseResourcesKinds");
	
EndProcedure // ResourcesListAfterDeleteRow()



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
