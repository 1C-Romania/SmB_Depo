
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.ChoiceMode Then
		StandardSubsystemsServer.SetFormPurposeKey(ThisObject, "PickupSelection");
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	EndIf;
	
	If Parameters.Filter.Property("Owner") Then
		Property = Parameters.Filter.Owner;
		Parameters.Filter.Delete("Owner");
	EndIf;
	
	If Not ValueIsFilled(Property) Then
		Items.Property.Visible = True;
		CustomizeOrderValuesOnProperties(List);
	EndIf;
	
	If Parameters.ChoiceMode Then
		CommonUseClientServer.SetFilterDynamicListItem(
			List, "DeletionMark", False, , , True,
			DataCompositionSettingsItemViewMode.Normal);
	Else
		Items.List.ChoiceMode = False;
	EndIf;
	
	SetTitle();
	
	OnChangeProperties();
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Writing_AdditionalAttributesAndInformation"
	   AND Source = Property Then
		
		AttachIdleHandler("IdleHandlerOnChangeProperties", 0.1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure PropertyOnChange(Item)
	
	OnChangeProperties();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersList

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Not Copy
	   AND Items.List.Representation = TableRepresentation.List Then
		
		Parent = Undefined;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure CustomizeOrderValuesOnProperties(List)
	
	Var Order;
	
	// Order.
	Order = List.SettingsComposer.Settings.Order;
	Order.UserSettingID = "DefaultOrder";
	
	Order.Items.Clear();
	
	OrderingItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderingItem.Field = New DataCompositionField("Owner");
	OrderingItem.OrderType = DataCompositionSortDirection.Asc;
	OrderingItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderingItem.Use = True;
	
	OrderingItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderingItem.Field = New DataCompositionField("Description");
	OrderingItem.OrderType = DataCompositionSortDirection.Asc;
	OrderingItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderingItem.Use = True;
	
EndProcedure

&AtServer
Procedure SetTitle()
	
	TitleString = "";
	
	If ValueIsFilled(Property) Then
		TitleString = CommonUse.ObjectAttributeValue(
			Property, "ValueChoiceFormHeader");
	EndIf;
	
	If IsBlankString(TitleString) Then
		
		If ValueIsFilled(Property) Then
			If Not Parameters.ChoiceMode Then
				TitleString = NStr("en = 'Property value %1'");
			Else
				TitleString = NStr("en = 'Select the %1 property value'");
			EndIf;
			
			TitleString = StringFunctionsClientServer.PlaceParametersIntoString(
				TitleString, String(Property));
		
		ElsIf Parameters.ChoiceMode Then
			TitleString = NStr("en = 'Choose property value'");
		EndIf;
	EndIf;
	
	If Not IsBlankString(TitleString) Then
		AutoTitle = False;
		Title = TitleString;
	EndIf;
	
EndProcedure

&AtClient
Procedure IdleHandlerOnChangeProperties()
	
	OnChangeProperties();
	
EndProcedure

&AtServer
Procedure OnChangeProperties()
	
	If ValueIsFilled(Property) Then
		
		AdditionalValuesOwner = CommonUse.ObjectAttributeValue(
			Property, "AdditionalValuesOwner");
		
		If ValueIsFilled(AdditionalValuesOwner) Then
			ReadOnly = True;
			
			ValueType = CommonUse.ObjectAttributeValue(
				AdditionalValuesOwner, "ValueType");
			
			CommonUseClientServer.SetFilterDynamicListItem(
				List, "Owner", AdditionalValuesOwner);
			
			AdditionalValuesWithWeight = CommonUse.ObjectAttributeValue(
				AdditionalValuesOwner, "AdditionalValuesWithWeight");
		Else
			ReadOnly = False;
			ValueType = CommonUse.ObjectAttributeValue(Property, "ValueType");
			
			CommonUseClientServer.SetFilterDynamicListItem(
				List, "Owner", Property);
			
			AdditionalValuesWithWeight = CommonUse.ObjectAttributeValue(
				Property, "AdditionalValuesWithWeight");
		EndIf;
		
		If TypeOf(ValueType) = Type("TypeDescription")
		   AND ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
			
			Items.List.ChangeRowSet = True;
		Else
			Items.List.ChangeRowSet = False;
		EndIf;
		
		Items.List.Representation = TableRepresentation.HierarchicalList;
		Items.Owner.Visible = False;
		Items.Weight.Visible = AdditionalValuesWithWeight;
	Else
		CommonUseClientServer.DeleteGroupsSelectionDynamicListItems(
			List, "Owner");
		
		Items.List.Representation = TableRepresentation.List;
		Items.List.ChangeRowSet = False;
		Items.Owner.Visible = True;
		Items.Weight.Visible = False;
	EndIf;
	
	Items.List.Header = Items.Owner.Visible Or Items.Weight.Visible;
	
EndProcedure

#EndRegion
