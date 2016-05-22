
////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtServerNoContext
// Returns the data structure by received price kind
//
Function GetRetailPriceKindData(RetailPriceKind)
	
	DataStructure	 = New Structure;
	
	DataStructure.Insert("PriceKindDescription",	RetailPriceKind.Description);
	DataStructure.Insert("NationalCurrency",	Constants.NationalCurrency.Get());
	DataStructure.Insert("PriceCurrency", 			RetailPriceKind.PriceCurrency);
	
	Return DataStructure;
	
EndFunction //GetRetailPriceKindData()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	TypeOfStructuralUnitRetail = Enums.StructuralUnitsTypes.Retail;
	TypeOfStructuralUnitRetailAmmountAccounting = Enums.StructuralUnitsTypes.RetailAccrualAccounting;
	TypeOfStructuralUnitWarehouse = Enums.StructuralUnitsTypes.Warehouse;
	
	Items.OrderWarehouse.Enabled = Object.StructuralUnitType = TypeOfStructuralUnitWarehouse;
	Items.RetailPriceKind.Visible = (
		Object.StructuralUnitType = TypeOfStructuralUnitRetail
		OR Object.StructuralUnitType = TypeOfStructuralUnitWarehouse
		OR Object.StructuralUnitType = TypeOfStructuralUnitRetailAmmountAccounting
	);
	
	If Constants.FunctionalOptionAccountingByMultipleWarehouses.Get()
	 OR Object.StructuralUnitType = Enums.StructuralUnitsTypes.Warehouse Then
		Items.StructuralUnitType.ChoiceList.Add(Enums.StructuralUnitsTypes.Warehouse);
		If Constants.FunctionalOptionAccountingRetail.Get() 
			OR Object.StructuralUnitType = Enums.StructuralUnitsTypes.Retail 
			OR Object.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting Then
			Items.StructuralUnitType.ChoiceList.Add(Enums.StructuralUnitsTypes.Retail);
			Items.StructuralUnitType.ChoiceList.Add(Enums.StructuralUnitsTypes.RetailAccrualAccounting);
		EndIf;
	EndIf;
	
	If Constants.FunctionalOptionAccountingByMultipleDivisions.Get()
		OR Object.StructuralUnitType = Enums.StructuralUnitsTypes.Division Then
		Items.StructuralUnitType.ChoiceList.Add(Enums.StructuralUnitsTypes.Division);
	EndIf;
	
	If Not ValueIsFilled(Object.Ref)
		  AND Items.StructuralUnitType.ChoiceList.Count() = 1 Then
		Object.StructuralUnitType = Items.StructuralUnitType.ChoiceList[0].Value;
	EndIf;
	
	If Not GetFunctionalOption("UseDataSynchronization") Then
		Items.Company.Visible = False;
	EndIf;
	
	Items.RetailPriceKind.Enabled = Not Object.OrderWarehouse;
	Items.RetailPriceKind.AutoMarkIncomplete = (
		Object.StructuralUnitType = TypeOfStructuralUnitRetail
		OR Object.StructuralUnitType = TypeOfStructuralUnitRetailAmmountAccounting
	);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectsAttributesEditProhibition
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	// End StandardSubsystems.ObjectsAttributesEditProhibition
	
	// StandardSubsystems.ContactInformation
	ContactInformationManagement.OnCreateAtServer(ThisForm, Object, "PageContactInformation", FormItemTitleLocation.Left);
	// End StandardSubsystems.ContactInformation
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributesPage");
	// End StandardSubsystems.Properties
	
EndProcedure // OnCreateAtServer()

&AtServer
// Event handler procedure OnReadAtServer
//
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.ContactInformation
	ContactInformationManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.ContactInformation
	
EndProcedure // OnReadAtServer()

&AtClient
// Procedure-handler of the NotificationProcessing event.
//
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Mechanism handler "Properties".
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	
	If EventName = "AccountsChangedStructuralUnits" Then
		Object.GLAccountInRetail = Parameter.GLAccountInRetail;
		Object.MarkupGLAccount = Parameter.MarkupGLAccount;
		Modified = True;
	EndIf;
	
EndProcedure // NotificationProcessing()

&AtServer
// Procedure-handler of the BeforeWriteAtServer event.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
		
	// Mechanism handler "Properties".
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	
	// StandardSubsystems.ContactInformation
	ContactInformationManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.ContactInformation
	
EndProcedure // BeforeWriteAtServer()

&AtServer
// Procedure-handler of the FillCheckProcessingAtServer event.
//
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.ContactInformation
	ContactInformationManagement.FillCheckProcessingAtServer(ThisForm, Object, Cancel);
	// End StandardSubsystems.ContactInformation
	
EndProcedure // FillCheckProcessingAtServer()

&AtServer
// Procedure-handler  of the AfterWriteOnServer event.
//
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// Handler of the subsystem prohibiting the object attribute editing.
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	
EndProcedure // AfterWriteOnServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

&AtClient
// Procedure - event handler OnChange field StructuralUnitType.
//
Procedure StructuralUnitTypeOnChange(Item)
	
	If ValueIsFilled(Object.StructuralUnitType) Then
		
		If Object.StructuralUnitType = TypeOfStructuralUnitWarehouse Then
			Items.OrderWarehouse.Enabled = True;
		Else
			Items.OrderWarehouse.Enabled = False;
			Object.OrderWarehouse = False;
		EndIf;
		
		Items.RetailPriceKind.Visible = (
			Object.StructuralUnitType = TypeOfStructuralUnitRetail
			OR Object.StructuralUnitType = TypeOfStructuralUnitWarehouse
			OR Object.StructuralUnitType = TypeOfStructuralUnitRetailAmmountAccounting
		);
		
		Items.RetailPriceKind.MarkIncomplete = (
			Object.StructuralUnitType = TypeOfStructuralUnitRetail
			OR Object.StructuralUnitType = TypeOfStructuralUnitRetailAmmountAccounting
		);
		
	Else
		
		Items.OrderWarehouse.Enabled = False;
		Object.OrderWarehouse = False;
		
	EndIf;
	
EndProcedure // StructuralUnitTypeOnChange()

&AtClient
// Procedure - event handler Click field InventoryAutoTransfer.
//
Procedure InventoryAutotransferClick(Item)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("TransferSource", Object.TransferSource);
	ParametersStructure.Insert("TransferRecipient", Object.TransferRecipient);
	ParametersStructure.Insert("RecipientOfWastes", Object.RecipientOfWastes);
	ParametersStructure.Insert("WriteOffToExpensesSource", Object.WriteOffToExpensesSource);
	ParametersStructure.Insert("WriteOffToExpensesRecipient", Object.WriteOffToExpensesRecipient);
	ParametersStructure.Insert("PassToOperationSource", Object.PassToOperationSource);
	ParametersStructure.Insert("PassToOperationRecipient", Object.PassToOperationRecipient);
	ParametersStructure.Insert("ReturnFromOperationSource", Object.ReturnFromOperationSource);
	ParametersStructure.Insert("ReturnFromOperationRecipient", Object.ReturnFromOperationRecipient);
	
	ParametersStructure.Insert("TransferSourceCell", Object.TransferSourceCell);
	ParametersStructure.Insert("TransferRecipientCell", Object.TransferRecipientCell);
	ParametersStructure.Insert("DisposalsRecipientCell", Object.DisposalsRecipientCell);
	ParametersStructure.Insert("WriteOffToExpensesSourceCell", Object.WriteOffToExpensesSourceCell);
	ParametersStructure.Insert("WriteOffToExpensesRecipientCell", Object.WriteOffToExpensesRecipientCell);
	ParametersStructure.Insert("PassToOperationSourceCell", Object.PassToOperationSourceCell);
	ParametersStructure.Insert("PassToOperationRecipientCell", Object.PassToOperationRecipientCell);
	ParametersStructure.Insert("ReturnFromOperationSourceCell", Object.ReturnFromOperationSourceCell);
	ParametersStructure.Insert("ReturnFromOperationRecipientCell", Object.ReturnFromOperationRecipientCell);
	
	ParametersStructure.Insert("StructuralUnitType", Object.StructuralUnitType);
	
	Notification = New NotifyDescription("AutomovementocksEndClick",ThisForm);
	OpenForm("CommonForm.AutoTransferInventoryForm", ParametersStructure,,,,,Notification);
	
	
EndProcedure // InventoryAutotransferClick()

&AtClient
Procedure AutomovementocksEndClick(FillingParameters,Parameters) Export
	
	If TypeOf(FillingParameters) = Type("Structure") Then
		
		FillPropertyValues(Object, FillingParameters);
		
		If Not Modified 
			AND FillingParameters.Modified Then
			
			Modified = True;
			
		EndIf;
		
	EndIf;

	
EndProcedure

&AtClient
// Procedure - event handler Click field RetailPriceKind.
//
Procedure RetailPriceKindOnChange(Item)
	
	If Not ValueIsFilled(Object.RetailPriceKind) Then
		Return;
	EndIf;
	
	DataStructure = GetRetailPriceKindData(Object.RetailPriceKind);
	
	If Not DataStructure.PriceCurrency = DataStructure.NationalCurrency Then
		
		MessageText = NStr("en = 'In the price kind ""%PricesKind%"", for retail structural unit, national currency (%NatCurrency%) must be specified.'");
		MessageText = StrReplace(MessageText, "%PriceKind%", DataStructure.PriceKindDescription);
		MessageText = StrReplace(MessageText, "%NatCurrency%", DataStructure.NationalCurrency);
		
		CommonUseClientServer.MessageToUser(MessageText, , "Object.RetailPriceKind");
		
		Object.RetailPriceKind = Undefined;
		
	EndIf;
	
EndProcedure //RetailPriceKindOnChange()

&AtClient
Procedure OrderWarehouseOnChange(Item)
	
	Items.RetailPriceKind.Enabled = Not Object.OrderWarehouse;
	
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
	
	ObjectsAttributesEditProhibitionClient.AuthorizeObjectDetailsEditing(ThisObject);
	
EndProcedure // Connected_AllowObjectAttributeEdit()
// End

// StandardSubsystems.ContactInformation
&AtClient
Procedure Attachable_ContactInformationOnChange(Item)
	
	ContactInformationManagementClient.PresentationOnChange(ThisForm, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationStartChoice(Item, ChoiceData, StandardProcessing)
	
	Result = ContactInformationManagementClient.PresentationStartChoice(ThisForm, Item, , StandardProcessing);
	RefreshContactInformation(Result);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationClearing(Item, StandardProcessing)
	
	Result = ContactInformationManagementClient.ClearingPresentation(ThisForm, Item.Name);
	RefreshContactInformation(Result);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationExecuteCommand(Command)
	
	Result = ContactInformationManagementClient.LinkCommand(ThisForm, Command.Name);
	RefreshContactInformation(Result);
	ContactInformationManagementClient.OpenAddressEntryForm(ThisForm, Result);
	
EndProcedure

&AtServer
Function RefreshContactInformation(Result = Undefined)
	
	Return ContactInformationManagement.RefreshContactInformation(ThisForm, Object, Result);
	
EndFunction
// End StandardSubsystems.ContactInformation

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure // Attachable_EditPropertyContent()

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure // UpdateAdditionalAttributeItems()
// End StandardSubsystems.Properties

#EndRegion


