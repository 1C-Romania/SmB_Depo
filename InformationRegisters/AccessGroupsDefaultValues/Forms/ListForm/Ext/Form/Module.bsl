
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	SetConditionalAppearance();
	
	ReadOnly = True;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure EnableEditingAbility(Command)
	
	ReadOnly = False;
	
EndProcedure

&AtClient
Procedure RefreshDataRegister(Command)
	
	HasChanges = False;
	
	RegisterDataUpdateOnServer(HasChanges);
	
	If HasChanges Then
		Text = NStr("en='Updated successfully.';ru='Обновление выполнено успешно.'");
	Else
		Text = NStr("en='No need to update.';ru='Обновление не требуется.'");
	EndIf;
	
	ShowMessageBox(, Text);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure RegisterDataUpdateOnServer(HasChanges)
	
	SetPrivilegedMode(True);
	
	InformationRegisters.AccessGroupsValues.RefreshDataRegister(, HasChanges);
	
	Items.List.Refresh();
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	AccessValuesTypes = Metadata.DefinedTypes.AccessValue.Type.Types();
	
	For Each Type IN AccessValuesTypes Do
		
		Types = New Array;
		Types.Add(Type);
		DescriptionOfType = New TypeDescription(Types);
		TypeEmptyRef = DescriptionOfType.AdjustValue(Undefined);
		
		// Design.
		ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
		
		ItemColorsDesign = ConditionalAppearanceItem.Appearance.Items.Find("Text");
		ItemColorsDesign.Value = String(Type);
		ItemColorsDesign.Use = True;
		
		DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		DataFilterItem.LeftValue  = New DataCompositionField("List.AccessValuesType");
		DataFilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
		DataFilterItem.RightValue = TypeEmptyRef;
		DataFilterItem.Use  = True;
		
		ItemProcessedFields = ConditionalAppearanceItem.Fields.Items.Add();
		ItemProcessedFields.Field = New DataCompositionField(Items.ListAccessValuesType.Name);
		ItemProcessedFields.Use = True;
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
