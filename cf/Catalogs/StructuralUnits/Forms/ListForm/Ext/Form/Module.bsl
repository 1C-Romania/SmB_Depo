////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF SAVING SETTINGS

&AtServer
// Procedure saves the selected item in settings.
//
Procedure SetMainItem(SelectedItem, SettingName)
	
	If SettingName = "MainWarehouse" 
	   AND SelectedItem.StructuralUnitType = Enums.StructuralUnitsTypes.Division Then
		Message = New UserMessage();
		Message.Text = NStr("en='You can not choose division as the main warehouse!';ru='В качестве основного склада нельзя выбирать Подразделение!'");
		Message.Message();
		Return;
	EndIf;
	If SettingName = "MainDivision"
	   AND SelectedItem.StructuralUnitType <> Enums.StructuralUnitsTypes.Division Then
		Message = New UserMessage();
		Message.Text = NStr("en='You must choose division as main division!';ru='В качестве основного подразделения необходимо выбрать Подразделение!'");
		Message.Message();
		Return;
	EndIf; 
	If SelectedItem <> SmallBusinessReUse.GetValueOfSetting(SettingName) Then
		SmallBusinessServer.SetUserSetting(SelectedItem, SettingName);
		SmallBusinessServer.MarkMainItemWithBold(SelectedItem, List, SettingName);
	EndIf;
		
EndProcedure

&AtClient
// Procedure - command execution handler CommandSetMainDivision.
//
Procedure CommandSetMainDivision(Command)
	
	SelectedItem = Items.List.CurrentRow;
	If ValueIsFilled(SelectedItem) Then
		SetMainItem(SelectedItem, "MainDivision");
	EndIf;
	
EndProcedure

&AtClient
// Procedure - command execution handler CommandSetMainWarehouse.
//
Procedure CommandSetMainWarehouse(Command)
	
	SelectedItem = Items.List.CurrentRow;
	If ValueIsFilled(SelectedItem) Then
		SetMainItem(SelectedItem, "MainWarehouse");
	EndIf;
	
EndProcedure

&AtServer
// Function of checking the types hierarchy of structural units.
//
Function CheckTypeHierarchy()
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	StructuralUnits.Ref
	|FROM
	|	Catalog.StructuralUnits AS StructuralUnits
	|WHERE
	|	StructuralUnits.Parent <> VALUE(Catalog.StructuralUnits.EmptyRef)
	|	AND StructuralUnits.StructuralUnitType <> StructuralUnits.Parent.StructuralUnitType";
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return False;
	Else
		Return True;
	EndIf;
	
EndFunction // CheckTypeHierarchy()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Selection of main item
	If Parameters.Filter.Property("StructuralUnitType") Then
		
		ShowWarehouse = False;
		ShowDivision = False;
		If TypeOf(Parameters.Filter.StructuralUnitType) = Type("FixedArray") Then
			For Each ArrayElement IN Parameters.Filter.StructuralUnitType Do
				If ArrayElement = Enums.StructuralUnitsTypes.Division Then
					ShowDivision = True;
				Else
					ShowWarehouse = True;
				EndIf;
			EndDo;
		Else
			If Parameters.Filter.StructuralUnitType = Enums.StructuralUnitsTypes.Division Then
				ShowDivision = True;
			Else
				ShowWarehouse = True;
			EndIf;
		EndIf; 
		
		CommonUseClientServer.SetFormItemProperty(Items, "CommandSetMainDivision", "Visible", ShowDivision);
		CommonUseClientServer.SetFormItemProperty(Items, "CommandSetMainWarehouse", "Visible", ShowWarehouse);
		If Not ShowWarehouse Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "OrderWarehouse", "Visible", False);
			
		EndIf;
		
	Else
		
		ShowWarehouse = True;
		ShowDivision = True;
		
	EndIf;
	
	SmallBusinessServer.MarkMainItemWithBold(SmallBusinessReUse.GetValueOfSetting("MainWarehouse"), List, "MainWarehouse");
	SmallBusinessServer.MarkMainItemWithBold(SmallBusinessReUse.GetValueOfSetting("MainDivision"), List, "MainDivision");
	
	If Not GetFunctionalOption("UseDataSynchronization") Then
		Items.Company.Visible = False;
	EndIf;
	
	TypesHierarchy = False;
	If Not (ShowWarehouse AND ShowDivision) Then
		TypesHierarchy = CheckTypeHierarchy();
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
EndProcedure // OnCreateAtServer()

&AtClient
// Procedure - OnOpen form event handler
//
Procedure OnOpen(Cancel)
	
	If TypesHierarchy Then
		Items.List.Representation = TableRepresentation.List;
	EndIf;
	
EndProcedure // OnOpen()


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
