
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.ThisIsAdditionalInformation <> Undefined Then
		ThisIsAdditionalInformation = Parameters.ThisIsAdditionalInformation;
		
		CommonUseClientServer.SetFilterDynamicListItem(
			List, "ThisIsAdditionalInformation", ThisIsAdditionalInformation, , , True);
	EndIf;
	
	// Filter of items not marked for deletion.
	CommonUseClientServer.SetFilterDynamicListItem(
		List, "DeletionMark", False, , , True,
		DataCompositionSettingsItemViewMode.Normal);
	
	If Parameters.SelectionOfCommonProperty Then
		
		KindSelect = "SelectionOfCommonProperty";
		
		CommonUseClientServer.SetFilterDynamicListItem(
			List, "PropertySet", , DataCompositionComparisonType.NotFilled, , True);
		
		If ThisIsAdditionalInformation = True Then
			AutoTitle = False;
			Title = NStr("en='Common additional information selection';ru='Выбор общего дополнительного сведения'");
		ElsIf ThisIsAdditionalInformation = False Then
			AutoTitle = False;
			Title = NStr("en='Common additional attribute selection';ru='Выбор общего дополнительного реквизита'");
		EndIf;
		
	ElsIf Parameters.OwnersSelectionOfAdditionalValues Then
		
		KindSelect = "OwnersSelectionOfAdditionalValues";
		
		CommonUseClientServer.SetFilterDynamicListItem(
			List, "PropertySet", , DataCompositionComparisonType.Filled, , True);
		
		CommonUseClientServer.SetFilterDynamicListItem(
			List, "AdditionalValuesAreUsed", True, , , True);
		
		CommonUseClientServer.SetFilterDynamicListItem(
			List, "AdditionalValuesOwner", ,
			DataCompositionComparisonType.NotFilled, , True);
		
		AutoTitle = False;
		Title = NStr("en='Example choice';ru='Выбор образца'");
		
		Items.FormCreate.Visible = False;
		Items.FormCopy.Visible = False;
		Items.FormChange.Visible = False;
		Items.FormSetDeletionMark.Visible = False;
		
		Items.ListContextMenuCreate.Visible = False;
		Items.ListContextMenuCopy.Visible = False;
		Items.ListContextMenuChange.Visible = False;
		Items.ListContextMenuSetDeletionMark.Visible = False;
	EndIf;
	FillSelectedValues();
	
	CommonUseClientServer.SetDynamicListParameter(
		List,
		"PresentationGroupingOfCommonProperties",
		NStr("en='Common (for several sets)';ru='Общие (для нескольких наборов)'"),
		True);
	
	// Properties grouping by sets.
	DataGrouping = List.SettingsComposer.Settings.Structure.Add(Type("DataCompositionGroup"));
	DataGrouping.UserSettingID = "GroupPropertiesBySuite";
	DataGrouping.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	GroupFields = DataGrouping.GroupFields;
	
	DataGroupItem = GroupFields.Items.Add(Type("DataCompositionGroupField"));
	DataGroupItem.Field = New DataCompositionField("PropertySetGrouping");
	DataGroupItem.Use = True;
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersList

&AtClient
Procedure ValueChoiceList(Item, Value, StandardProcessing)
	
	If KindSelect = "SelectionOfCommonProperty" Then
		StandardProcessing = False;
		NotifyChoice(New Structure("CommonProperty", Value));
		
	ElsIf KindSelect = "OwnersSelectionOfAdditionalValues" Then
		StandardProcessing = False;
		NotifyChoice(New Structure("AdditionalValuesOwner", Value));
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy)
	
	Cancel = True;
	
	If Not Items.FormCreate.Visible Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ThisIsAdditionalInformation", ThisIsAdditionalInformation);
	
	If Copy Then
		FormParameters.Insert("CopyingValue", Item.CurrentRow);
	Else
		FillingValues = New Structure;
		FormParameters.Insert("FillingValues", FillingValues);
	EndIf;
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInformation.ObjectForm", FormParameters);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
	If Not Items.FormCreate.Visible Then
		Return;
	EndIf;
	
	If Item.CurrentData <> Undefined Then
		
		FormParameters = New Structure;
		FormParameters.Insert("Key", Item.CurrentRow);
		FormParameters.Insert("ThisIsAdditionalInformation", ThisIsAdditionalInformation);
		
		OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInformation.ObjectForm", FormParameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillSelectedValues()
	
	If Parameters.Property("SelectedValues")
	   AND TypeOf(Parameters.SelectedValues) = Type("Array") Then
		
		SelectedList.LoadValues(Parameters.SelectedValues);
	EndIf;
	
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	ItemColorsDesign = ConditionalAppearanceItem.Appearance.Items.Find("Font");
	ItemColorsDesign.Value = New Font(, , True);
	ItemColorsDesign.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("List.Ref");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.InList;
	DataFilterItem.RightValue = SelectedList;
	DataFilterItem.Use  = True;
	
	ItemProcessedFields = ConditionalAppearanceItem.Fields.Items.Add();
	ItemProcessedFields.Field = New DataCompositionField("Presentation");
	ItemProcessedFields.Use = True;
	
EndProcedure

#EndRegion














