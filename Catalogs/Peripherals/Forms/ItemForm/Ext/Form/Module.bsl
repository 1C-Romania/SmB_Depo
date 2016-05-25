
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	DisableDriverChanges = (Object.Ref <> Catalogs.Peripherals.EmptyRef());
	// Protection from device type change if type is clearly set or copy is already created.
	Items.EquipmentType.ReadOnly = DisableDriverChanges;
	// Protection from driver handler change of already created equipment copy.
	Items.HardwareDriver.ReadOnly = DisableDriverChanges;
	Items.SetForm.Enabled = ValueIsFilled(Object.Ref); 

	// Import and install available data processor list.
	ListOfDrivers = GetDriversList(Object.EquipmentType, Not DisableDriverChanges);
	Items.HardwareDriver.ChoiceList.Clear();
	For Each ListRow IN ListOfDrivers Do
		Items.HardwareDriver.ChoiceList.Add(ListRow.Value, ListRow.Presentation);
	EndDo;

	// Standard type enum.
	For Each EnumerationName IN Metadata.Enums.PeripheralTypes.EnumValues Do
		EquipmentTypesCompliance.Add(EnumerationName.Synonym, EnumerationName.Comment);
	EndDo;
	
	EquipmentManagerServerCallOverridable.EquipmentInstanceOnCreateAtServer(Object, ThisObject, Cancel, Parameters, StandardProcessing);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	EquipmentManagerClientOverridable.EquipmentInstanceOnOpen(Object, ThisObject, Cancel);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	EquipmentManagerClientOverridable.EquipmentInstanceBeforeClose(Object, ThisObject, Cancel, StandardProcessing);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	Items.SetForm.Enabled = ValueIsFilled(Object.Ref); 
	
	EquipmentManagerServerCallOverridable.EquipmentInstanceOnReadAtServer(CurrentObject,ThisObject);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Not Cancel AND Modified Then
		RefreshReusableValues();
	EndIf;
	
	EquipmentManagerClientOverridable.EquipmentInstanceBeforeWrite(Object, ThisObject, Cancel, WriteParameters);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	EquipmentManagerServerCallOverridable.EquipmentInstanceBeforeWriteAtServer(Cancel, CurrentObject, WriteParameters);
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	EquipmentManagerServerCallOverridable.EquipmentInstanceOnWriteAtServer(Cancel, CurrentObject, WriteParameters);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	EquipmentManagerServerCallOverridable.EquipmentInstanceAfterWriteAtServer(CurrentObject, WriteParameters);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	EquipmentManagerClientOverridable.EquipmentInstanceAfterWrite(Object, ThisObject, WriteParameters);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	EquipmentManagerServerCallOverridable.EquipmentInstanceFillCheckProcessingAtServer(Object, ThisObject, Cancel, CheckedAttributes);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure EquipmentTypeChoiceProcessing(Item, ValueSelected, StandardProcessing)

	If Object.EquipmentType <> ValueSelected Then
		Object.EquipmentType = ValueSelected;
		Modified = True;

		// Import and install available data processor list.
		ListOfDrivers = GetDriversList(Object.EquipmentType, Not DisableDriverChanges);
		Items.HardwareDriver.ChoiceList.Clear();
		For Each ListRow IN ListOfDrivers Do
			Items.HardwareDriver.ChoiceList.Add(ListRow.Value, ListRow.Presentation);
		EndDo;
		
		Object.HardwareDriver = PredefinedValue("Catalog.HardwareDrivers.EmptyRef");
		Object.Description = "";
		
	EndIf;

	StandardProcessing = False;
	
	EquipmentManagerClientOverridable.EquipmentInstanceEquipmentTypeSelection(Object, ThisForm, ThisObject, Item, ValueSelected);
	
EndProcedure

&AtClient
Procedure HardwareDriverChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If ValueSelected <> Object.HardwareDriver Then
		ProcessChoiceHandler(ValueSelected, StandardProcessing);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ProcessChoiceHandler(SelectedHandler, StandardProcessing = True)

	Object.Description = "'" + String(SelectedHandler) + "'"
						+ ?(IsBlankString(String(Object.Workplace)),
							"",
							" " + NStr("en='on'") + " " + String(Object.Workplace));

EndProcedure

&AtClient
Procedure Configure(Command)
	
	ClearMessages();
	
	ConfigurePeripherals();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ConfigurePeripherals()
	
	ErrorInfo = "";
	SettingsChanged = False;
	
	Write();
	
	Close();
	
	EquipmentManagerClient.ExecuteEquipmentSetup(Object.Ref);
	   
	
EndProcedure

&AtServer
Function GetDriversList(EquipmentType, OnlyAvailable)
	
	ListOfDrivers = New ValueList();
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	HardwareDrivers.Ref,
		|	HardwareDrivers.Description,
		|	HardwareDrivers.EquipmentType
		|FROM
		|	Catalog.HardwareDrivers AS HardwareDrivers
		|WHERE
		|	(HardwareDrivers.EquipmentType = &EquipmentType)
		|	%Condition%
		|ORDER BY HardwareDrivers.Description";
		
	If OnlyAvailable Then
		Query.Text = StrReplace(Query.Text, "%Condition%", "And NOT HardwareDrivers.DeletionMark");
	Else
		Query.Text = StrReplace(Query.Text, "%Condition%", "");
	EndIf;
	
	Query.SetParameter("EquipmentType", EquipmentType);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		ListOfDrivers.Add(SelectionDetailRecords.Ref, SelectionDetailRecords.Description);
	EndDo;
	
	Return ListOfDrivers;

EndFunction

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
