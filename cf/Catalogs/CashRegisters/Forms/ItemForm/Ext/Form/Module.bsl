
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Function generates a bank account description.
//
&AtClient
Function MakeAutoDescription()
	
	Items.Description.ChoiceList.Clear();
	
	DescriptionString = "" + Object.CashCRType + " (" + Object.StructuralUnit + ")";
	
	Items.Description.ChoiceList.Add(DescriptionString);
	
	Return DescriptionString;

EndFunction // MakeAutoDescription()

// Procedure - form event handler "OnCreateAtServer".
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ValueIsFilled(Object.CashCurrency) Then
		Object.CashCurrency = Constants.NationalCurrency.Get();
	EndIf;
	
	If Not ValueIsFilled(Object.Ref)
	   AND Not Parameters.FillingValues.Property("Owner")
	   AND Not ValueIsFilled(Parameters.CopyingValue) Then
		SettingValue = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
		If ValueIsFilled(SettingValue) Then
			Object.Owner = SettingValue;
		Else
			Object.Owner = Catalogs.Companies.MainCompany;
		EndIf;
		If Not Constants.FunctionalOptionUsePeripherals.Get() Then
			Object.UseWithoutEquipmentConnection = True;
		EndIf;
	EndIf;
	
	CashCRTypeOnChangeAtServer();
	
	If Object.UseWithoutEquipmentConnection
	AND Not Constants.FunctionalOptionUsePeripherals.Get() Then
		Items.UseWithoutEquipmentConnection.Enabled = False;
	EndIf;
	
	Items.Peripherals.Enabled = Not Object.UseWithoutEquipmentConnection;
	
	If GetFunctionalOption("UseExchangeWithPeripheralsOffline") Then
		Items.CashCRType.ChoiceList.Add(Enums.CashCRTypes.CashRegistersOffline);
	EndIf;
	
	Items.Owner.Visible = GetFunctionalOption("MultipleCompaniesAccounting");
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectsAttributesEditProhibition
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	// End StandardSubsystems.ObjectsAttributesEditProhibition
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

// Procedure - form event handler "AfterWriteAtServer".
//
&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// editing prohibition subsystem of key object attributes	
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	
EndProcedure // AfterWriteOnServer()

&AtServer
Procedure CashCRTypeOnChangeAtServer()
	
	If Object.CashCRType = Enums.CashCRTypes.FiscalRegister Then
		
		Items.UseWithoutEquipmentConnection.Visible = True;
		Items.Peripherals.Visible = True;
		
		VarChoiceParameters = New Array;
		VarChoiceParameters .Add(New ChoiceParameter("Filter.EquipmentType", Enums.PeripheralTypes.FiscalRegister));
		VarChoiceParameters.Add(New ChoiceParameter("Filter.DeviceIsInUse", True));
		VarChoiceParameters.Add(New ChoiceParameter("Filter.DeletionMark", False));
		
		Items.Peripherals.ChoiceParameters = New FixedArray(VarChoiceParameters);
		
		If Object.Peripherals.EquipmentType <> Enums.PeripheralTypes.FiscalRegister Then
			Object.Peripherals = Undefined;
		EndIf;
		
	ElsIf Object.CashCRType = Enums.CashCRTypes.CashRegistersOffline Then
		
		Items.UseWithoutEquipmentConnection.Visible = False;
		Items.Peripherals.Visible = True;
		
		VarChoiceParameters = New Array;
		VarChoiceParameters.Add(New ChoiceParameter("Filter.EquipmentType", Enums.PeripheralTypes.CashRegistersOffline));
		VarChoiceParameters.Add(New ChoiceParameter("Filter.DeviceIsInUse", True));
		VarChoiceParameters.Add(New ChoiceParameter("Filter.DeletionMark", False));
		
		Items.Peripherals.ChoiceParameters = New FixedArray(VarChoiceParameters);
		
		If Object.Peripherals.EquipmentType <> Enums.PeripheralTypes.CashRegistersOffline Then
			Object.Peripherals = Undefined;
		EndIf;
		
	Else
		
		Items.UseWithoutEquipmentConnection.Visible = False;
		Items.Peripherals.Visible = False;
		
	EndIf;
	
EndProcedure // PettyCashCRTypeOnChangeAtServer()

&AtClient
Procedure CashCRTypeOnChange(Item)
	
	CashCRTypeOnChangeAtServer();
	MakeAutoDescription();
	
EndProcedure // CashCRTypeOnChange()

&AtClient
Procedure PeripheralsOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	OpenForm("Catalog.Peripherals.ObjectForm", New Structure("Key", Object.Peripherals));
	
EndProcedure

&AtClient
Procedure UseWithoutEquipmentConnectionOnChange(Item)
	
	Items.Peripherals.Enabled = Not Object.UseWithoutEquipmentConnection;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	MakeAutoDescription();
	
EndProcedure

&AtClient
Procedure StructuralUnitOnChange(Item)
	
	MakeAutoDescription();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "CashRegisterAccountsChanged" Then
		Object.GLAccount = Parameter.GLAccount;
		Modified = True;
	EndIf;
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.ObjectsAttributesEditProhibition
&AtClient
Procedure Attachable_AuthorizeObjectDetailsEditing(Command)
	
	If Not Object.Ref.IsEmpty() Then
		Notification = New NotifyDescription("Attachable_AllowEditingDetailsOfObjectEnd",ThisForm);
		OpenForm("Catalog.CashRegisters.Form.WorkingWithKeyAttributesForm",,,,,,Notification);
	EndIf;
	
EndProcedure // Attachable_AllowObjectAttributeEditing()

&AtClient
Procedure Attachable_AllowObjectAttributeEditingEnd(Result,Parameters) Export
	
	If TypeOf(Result) = Type("Array") AND Result.Count() > 0 Then
		ObjectsAttributesEditProhibitionClient.SetEnabledOfFormItems(ThisForm, Result);
	EndIf;
	
EndProcedure
// End StandardSubsystems.ObjectsAttributesEditProhibition

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion















