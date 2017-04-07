#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	List.QueryText = StrReplace(List.QueryText, "%Predefined%", NStr("en='It is provided with the configuration';ru='Поставляемый в составе конфигурации'"));
	List.QueryText = StrReplace(List.QueryText, "%Attachable%", NStr("en='Connected according to the standard """"1C:Compatible""""';ru='Подключаемый по стандарту """"1С:Совместимо""""'"));
	
	PossibilityToAddNewDrivers = EquipmentManagerServerCallOverridable.PossibilityToAddNewDrivers(); 
	Items.ListCreate.Visible = PossibilityToAddNewDrivers;
	Items.ListCopy.Visible = PossibilityToAddNewDrivers;
	Items.ListContextMenuCreate.Visible = PossibilityToAddNewDrivers;
	Items.ListContextMenuCopy.Visible = PossibilityToAddNewDrivers;
	Items.AddNewDriverFromFile.Visible = PossibilityToAddNewDrivers;
	
	GroupItem = List.Group.Items.Add(Type("DataCompositionGroupField"));
	GroupItem.Field = New DataCompositionField("TypeDriver");
	GroupItem.Use = True;
	
	GroupItem = List.Group.Items.Add(Type("DataCompositionGroupField"));
	GroupItem.Field = New DataCompositionField("EquipmentType");
	GroupItem.Use = True;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure DriverFileChoiceEnd(FullFileName, Parameters) Export
	
	If Not IsBlankString(FullFileName) Then
		FormParameters = New Structure("FullFileName", FullFileName);
		OpenForm("Catalog.HardwareDrivers.ObjectForm", FormParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure AddNewDriverFromFile(Command)
	
	#If WebClient Then
		ShowMessageBox(, NStr("en='This functionality is available only in thin and thick client mode.';ru='Данный функционал доступен только в режиме тонкого и толстого клиента.'"));
		Return;
	#EndIf
	
	Notification = New NotifyDescription("DriverFileChoiceEnd", ThisObject);
	EquipmentManagerClient.StartDriverFileSelection(Notification);
	
EndProcedure

#EndRegion
