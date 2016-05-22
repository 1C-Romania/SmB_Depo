
&AtClient
Procedure ListChange(Command)
	
	StandardProcessing = False;
	OpenParameters = New Structure;
	OpenParameters.Insert("Key", Items.List.CurrentRow);
	OpenParameters.Insert("AvailabilityAllResources", False);
	OpenForm("InformationRegister.EnterpriseResourcesKinds.RecordForm", OpenParameters);
	
EndProcedure

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	OpenParameters = New Structure;
	OpenParameters.Insert("Key", Items.List.CurrentRow);
	OpenParameters.Insert("AvailabilityAllResources", False);
	OpenForm("InformationRegister.EnterpriseResourcesKinds.RecordForm", OpenParameters);
	
EndProcedure

&AtClient
Procedure ListBeforeDelete(Item, Cancel)
	
	CurrentListRow = Items.List.CurrentData;
	If CurrentListRow <> Undefined Then
		If CurrentListRow.EnterpriseResourceKind = PredefinedValue("Catalog.EnterpriseResourcesKinds.AllResources") Then
			MessageText = NStr("en = 'Object is not deleted as the enterprise resource should be included into the ""All resources"" kind.'");
			SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText, , , , Cancel);
		EndIf;
	EndIf;
	
EndProcedure
