
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Read = True;
	ReadOnly = True;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure EnableEditingAbility(Command)
	
	ReadOnly = False;
	
EndProcedure

&AtClient
Procedure UpdateAuxiliaryRegisterData(Command)
	
	HasChanges = False;
	
	UpdateAuxilaryRegisterDataAtServer(HasChanges);
	
	If HasChanges Then
		Text = NStr("en = 'Updated successfully.'");
	Else
		Text = NStr("en = 'No need to update.'");
	EndIf;
	
	ShowMessageBox(, Text);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ListTable.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("List.Table");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = Catalogs.MetadataObjectIDs.EmptyRef();

	Item.Appearance.SetParameterValue("Text", NStr("en = 'For all tables except the specified ones.'"));

EndProcedure

&AtServer
Procedure UpdateAuxilaryRegisterDataAtServer(HasChanges)
	
	SetPrivilegedMode(True);
	
	InformationRegisters.ObjectRightsSettings.UpdateAuxiliaryRegisterData(HasChanges);
	
	Items.List.Refresh();
	
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
