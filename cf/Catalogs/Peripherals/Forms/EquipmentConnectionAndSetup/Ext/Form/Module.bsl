
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	UpdateUserInterfase();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "CurrentSessionWorkplaceChanged" Then
		RefreshWorkingPlaceParameters();
	ElsIf EventName = "ToChangeAvailableTypesOfPeripheral" Then
		UpdateUserInterfase();
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If Modified Then
		RefreshReusableValues();
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure RadioButtonPagesOnChange(Item)
	
	DeviceList.Filter.Items[0].RightValue = PeripheralTypesRadioButton;
	
EndProcedure

&AtClient
Procedure DeviceListChoice(Item, SelectedRow, Field, StandardProcessing)
	
	If TypeOf(SelectedRow) <> Type("CatalogRef.Peripherals") Then
		If Items.DeviceList.Expanded(SelectedRow) Then
			Items.DeviceList.Collapse(SelectedRow);
		Else
			Items.DeviceList.Expand(SelectedRow);
		EndIf;

		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure AllTypesOfEquipmentOnChange(Item)
	
	DeviceList.Filter.Items[0].Use = (NOT AllTypesOfEquipment);
	
	Items.PeripheralTypesRadioButton.Enabled = (NOT AllTypesOfEquipment);
	DeviceList.Group.Items[1].Use = AllTypesOfEquipment; // Group by hardware type.
	
	If Items.DeviceList.CurrentRow <> Undefined Then
		Items.DeviceList.Expand(Items.DeviceList.CurrentRow, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure AllWorkplacesOnChange(Item)
	
	Items.GroupByWorkplace.Enabled = AllWorkplaces;
	DeviceList.Group.Items[0].Use = AllWorkplaces AND GroupByWorkplace;
	
	If Items.DeviceList.CurrentRow <> Undefined Then
		Items.DeviceList.Expand(Items.DeviceList.CurrentRow, True);
	EndIf;
	
	DeviceList.Filter.Items[1].Use = (NOT AllWorkplaces);
	
	If Not AllWorkplaces Then
		GroupByWorkplace = False;
		GroupByWorkplaceOnChange(Item);
	EndIf;
	
EndProcedure

&AtClient
Procedure GroupByWorkplaceOnChange(Item)
	
	DeviceList.Group.Items[0].Use = GroupByWorkplace;
	
	If Items.DeviceList.CurrentRow <> Undefined Then
		Items.DeviceList.Expand(Items.DeviceList.CurrentRow, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventsHandlers

&AtClient
Procedure DeviceListNewWriteProcessing(NewObject, Source, StandardProcessing)
	
	RefreshWorkingPlaceParameters();
	
	#If Not WebClient Then 
	Source.Read();
	#EndIf 
	
EndProcedure

&AtClient
Procedure DeviceListAfterDeleteRow(Item)
	
	RefreshWorkingPlaceParameters();
	
EndProcedure

&AtClient
Procedure DeviceListOnActivateRow(Item)
	
	If Items.Find("Configure") <> Undefined Then
		Items.Configure.Enabled = (TypeOf(Item.CurrentRow) = Type("CatalogRef.Peripherals"));
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WorkplaceSelectionEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Structure") AND Result.Property("Workplace") Then 
		EquipmentManagerClient.SetWorkplace(Result.Workplace);
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceOfWorkplace(Command)
	
	Notification = New NotifyDescription("WorkplaceSelectionEnd", ThisObject);
	EquipmentManagerClient.OfferWorkplaceSelection(Notification);
	
EndProcedure

&AtClient
Procedure ConfigureExecute()
	
	ClearMessages();
	ErrorInfo = "";
	SettingsChanged = False;
	
	If Items.DeviceList.CurrentData = Undefined Then
		Return;
	EndIf;
	
	EquipmentManagerClient.ExecuteEquipmentSetup(Items.DeviceList.CurrentData.Ref);
	
EndProcedure

&AtClient
Procedure ListOfWorkplaces(Command)
	
	Mode = FormWindowOpeningMode.LockWholeInterface;
	OpenForm("Catalog.Workplaces.ListForm",,,,,,, Mode);
	
EndProcedure

&AtClient
Procedure HardwareDrivers(Command)
	
	OpenForm("Catalog.HardwareDrivers.ListForm");
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure UpdateUserInterfase()
	
	CurrentWorksPlace = SessionParameters.ClientWorkplace;
	EquipmentList = EquipmentManagerServerCallOverridable.GetAvailableEquipmentTypes();

	Items.PeripheralTypesRadioButton.ChoiceList.Clear();
	
	While Items.PeripheralsPicturesGroup.ChildItems.Count() > 0  Do
		Items.Delete(Items.PeripheralsPicturesGroup.ChildItems[0]);
	EndDo;
	
	For Each EEType IN EquipmentList Do
		Items.PeripheralTypesRadioButton.ChoiceList.Add(EEType);
		NewPicture = Items.Add("Picture" + XMLString(EEType), Type("FormDecoration"), Items.PeripheralsPicturesGroup);
    	NewPicture.Type = FormDecorationType.Picture;
		NewPicture.Picture = PictureLib["Peripherals" + XMLString(EEType) + "32"];
		NewPicture.Width = 5;
		NewPicture.Height = 2;
	EndDo;
	
	PeripheralTypesRadioButton = EquipmentList[0];
	
	// Preset settings which the user should not see and modify.
	
	GroupItem = DeviceList.Group.Items.Add(Type("DataCompositionGroupField"));
	GroupItem.Field = New DataCompositionField("Workplace");
	GroupItem.Use = False;
	
	GroupItem = DeviceList.Group.Items.Add(Type("DataCompositionGroupField"));
	GroupItem.Field = New DataCompositionField("EquipmentType");
	GroupItem.Use = False;
	
	FilterItem = DeviceList.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("EquipmentType");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = PeripheralTypesRadioButton;
	FilterItem.Use = True;
	
	FilterItem = DeviceList.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("Workplace");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = Undefined;
	FilterItem.Use = True;
	
	RefreshWorkingPlaceParameters();
	
EndProcedure

&AtServer
Procedure RefreshWorkingPlaceParameters()
	
	If CurrentWorksPlace = Catalogs.Workplaces.EmptyRef()
	 Or CurrentWorksPlace <> SessionParameters.ClientWorkplace Then
		CurrentWorksPlace = SessionParameters.ClientWorkplace;
		Title = "";
	EndIf;
	
	If IsBlankString(Title) Then
		Title = NStr("en='Connect and set equipment for workplace';ru='Подключение и настройка оборудования для РМ'") + " """
		          + String(CurrentWorksPlace) + """";
		DeviceList.Filter.Items[1].RightValue = CurrentWorksPlace;
	EndIf;
	
EndProcedure

#EndRegion













